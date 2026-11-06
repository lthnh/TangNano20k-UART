`timescale 1ns/1ps

module rx_case #(parameter uart_pkg::parity_bit_e MODE = uart_pkg::NONE)
  (output logic done = 0);
  import uart_pkg::*;
  uart_if bus();
  uart_rx #(.PARITY_BIT(MODE)) dut(._if(bus));
  initial bus.rx_clk = 0;
  always #5 bus.rx_clk = ~bus.rx_clk;

  task automatic ticks(input integer count);
    repeat (count) @(negedge bus.rx_clk);
  endtask

  task automatic send_frame(input logic [7:0] value,
                            input logic bad_parity = 0,
                            input logic bad_stop = 0);
    bus.rx = 0;
    #160;
    for (int i = 0; i < 8; i++) begin
      bus.rx = value[i];
      #160;
    end
    if (MODE != NONE) begin
      bus.rx = calc_parity(MODE, value) ^ bad_parity;
      #160;
    end
    bus.rx = !bad_stop;
    #160;
    bus.rx = 1;
  endtask

  task automatic accept(input logic [7:0] value, input logic expected_error = 0);
    wait (bus.rx_finish === 1'b1);
    if (bus.rx_data !== value || bus.rx_err !== expected_error)
      $fatal(1, "mode %0d: got %h/error %b expected %h/error %b",
             MODE, bus.rx_data, bus.rx_err, value, expected_error);
    @(negedge bus.rx_clk);
    bus.rx_ack = 1;
    wait (bus.rx_finish === 1'b0);
    @(negedge bus.rx_clk);
    bus.rx_ack = 0;
    ticks(4);
  endtask

  initial begin
    bus.rst_n = 0;
    bus.rx_en = 0;
    bus.rx_ack = 0;
    bus.rx = 1;
    ticks(4);
    bus.rst_n = 1;
    bus.rx_en = 1;
    ticks(5);

    // Different arrival phases must all align to the detected start.
    for (int phase = 0; phase < 10; phase++) begin
      #(phase + 0.25);
      send_frame(8'h96 ^ phase);
      accept(8'h96 ^ phase);
      ticks(20);
    end

    // A short low pulse must not leave sampling permanently active.
    bus.rx = 0;
    ticks(3);
    bus.rx = 1;
    ticks(40);
    if (bus.rx_finish) $fatal(1, "glitch generated a frame");
    send_frame(8'h27);
    accept(8'h27);

    // Consecutive frames, with acknowledgment running alongside reception.
    fork
      begin
        send_frame(8'h31);
        send_frame(8'h82);
      end
      begin
        accept(8'h31);
        accept(8'h82);
      end
    join

    // Pending data must remain stable; drop the newest frame on overrun.
    send_frame(8'hA6);
    wait (bus.rx_finish);
    send_frame(8'h59);
    ticks(8);
    if (!bus.rx_overrun || bus.rx_data !== 8'hA6)
      $fatal(1, "overrun overwrote the pending result or was not reported");
    accept(8'hA6);
    send_frame(8'hC3);
    accept(8'hC3);

    if (MODE != NONE) begin
      send_frame(8'h07, 1, 0);
      accept(8'h07, 1);
      send_frame(8'hE1);
      accept(8'hE1);
    end
    send_frame(8'h52, 0, 1);
    accept(8'h52, 1);
    ticks(20);
    send_frame(8'hD2);
    accept(8'hD2);

    // Disable during a frame, then verify rearming and status clearing.
    bus.rx = 0;
    ticks(24);
    bus.rx_en = 0;
    ticks(4);
    if (bus.rx_finish || bus.rx_err || bus.rx_overrun || dut.sampling_active)
      $fatal(1, "disable did not clear receiver state");
    bus.rx = 1;
    ticks(20);
    bus.rx_en = 1;
    ticks(4);
    send_frame(8'h69);
    accept(8'h69);
    done = 1;
  end
endmodule

module tb_uart_rx;
  wire none_done, even_done, odd_done;
  rx_case #(.MODE(uart_pkg::NONE)) n(none_done);
  rx_case #(.MODE(uart_pkg::EVEN)) e(even_done);
  rx_case #(.MODE(uart_pkg::ODD)) o(odd_done);
  initial begin
    wait (none_done && even_done && odd_done);
    $display("PASS: RX alignment, voting, mailbox, overrun, parity/framing recovery");
    $finish;
  end
  initial begin
    #200000;
    $fatal(1, "RX timeout");
  end
endmodule
