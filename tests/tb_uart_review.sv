`timescale 1ns/1ps

// Sustained streams must retain alignment across every frame boundary.
module review_stream #(
  parameter integer BIT_TIME = 160,
  parameter integer WIDTH = 8,
  parameter integer STOP_BITS = 1,
  parameter uart_pkg::parity_bit_e MODE = uart_pkg::NONE,
  parameter integer START_PHASE = 1
)
  (output logic done = 0, output logic failed = 0);
  uart_if bus();
  uart_rx #(.DATA_WIDTH(WIDTH), .PARITY_BIT(MODE), .STOP_WIDTH(STOP_BITS))
    dut(._if(bus));
  integer received = 0;
  initial bus.rx_clk = 0;
  always #5 bus.rx_clk = ~bus.rx_clk;

  task automatic send_frame(input logic [7:0] value);
    bus.rx = 0;
    #(BIT_TIME);
    for (int i = 0; i < WIDTH; i++) begin
      bus.rx = value[i];
      #(BIT_TIME);
    end
    if (MODE != uart_pkg::NONE) begin
      bus.rx = (MODE == uart_pkg::ODD) ? ~^value[WIDTH-1:0] : ^value[WIDTH-1:0];
      #(BIT_TIME);
    end
    bus.rx = 1;
    #(BIT_TIME * STOP_BITS);
  endtask

  initial forever begin
    @(posedge bus.rx_finish);
    #1;
    if (bus.rx_data !== ((8'h96 ^ 8'(received)) & (8'hFF >> (8 - WIDTH))) || bus.rx_err) begin
      $display("stream period=%0d: index=%0d data=%h error=%b",
               BIT_TIME, received, bus.rx_data, bus.rx_err);
      failed = 1;
    end
    received++;
    @(negedge bus.rx_clk);
    bus.rx_ack = 1;
    wait (!bus.rx_finish);
    @(negedge bus.rx_clk);
    bus.rx_ack = 0;
  end

  initial begin
    bus.rst_n = 0;
    bus.rx_en = 0;
    bus.rx_ack = 0;
    bus.rx = 1;
    #40;
    bus.rst_n = 1;
    bus.rx_en = 1;
    #(60 + START_PHASE);
    for (int i = 0; i < 64; i++) send_frame(8'h96 ^ 8'(i));
    #1000;
    if (received != 64 || bus.rx_overrun) failed = 1;
    $display("stream period=%0d width=%0d parity=%0d stop=%0d: received=%0d/64 failed=%b",
             BIT_TIME, WIDTH, MODE, STOP_BITS, received, failed);
    done = 1;
  end
endmodule

module tb_uart_clk_review #(
  parameter integer TEST_FREQ = uart_pkg::XTAL_FREQ,
  parameter integer TEST_BAUD = 300,
  parameter integer TEST_OS = uart_pkg::OVERSAMPLING_RATE
);
  uart_if bus();
  uart_clk #(.XTAL_FREQ(TEST_FREQ), .BAUD_RATE(TEST_BAUD),
             .OVERSAMPLING_RATE(TEST_OS)) dut(._if(bus));
  integer tx_ticks = 0;
  integer rx_ticks = 0;
  initial bus.sys_clk = 0;
  always #1 bus.sys_clk = ~bus.sys_clk;
  always @(posedge bus.tx_clk) if (bus.rst_n) tx_ticks++;
  always @(posedge bus.rx_clk) if (bus.rst_n) rx_ticks++;
  initial begin
    bus.rst_n = 0;
    #4;
    bus.rst_n = 1;
    repeat (2 * (TEST_FREQ / TEST_BAUD) + 2)
      @(negedge bus.sys_clk);
    if (tx_ticks != 2)
      $fatal(1, "baud=%0d: TX ticks=%0d expected=2", TEST_BAUD, tx_ticks);
    if (rx_ticks != (2 * (TEST_FREQ / TEST_BAUD) + 1) /
                    ((TEST_FREQ / TEST_BAUD) / TEST_OS))
      $fatal(1, "baud=%0d: unexpected RX ticks=%0d", TEST_BAUD, rx_ticks);
    $display("PASS: divider at frequency=%0d baud=%0d", TEST_FREQ, TEST_BAUD);
    $finish;
  end
endmodule

module review_tx_parity(output logic done = 0, output logic failed = 0);
  uart_if bus();
  uart_tx #(.DATA_WIDTH(7), .PARITY_BIT(uart_pkg::EVEN)) dut(._if(bus));
  initial bus.tx_clk = 0;
  always #5 bus.tx_clk = ~bus.tx_clk;
  initial begin
    bus.rst_n = 0;
    bus.tx_start = 0;
    // The upper bit is outside the selected seven-bit payload.
    bus.tx_data = 8'h81;
    #20;
    bus.rst_n = 1;
    #10;
    bus.tx_start = 1;
    #10;
    bus.tx_start = 0;
    wait (bus.tx === 1'b0);
    #85; // Center of parity after start + seven data bits.
    if (bus.tx !== 1'b1) failed = 1;
    $display("7E1 TX: parity=%b expected=1 failed=%b", bus.tx, failed);
    done = 1;
  end
endmodule

module tb_uart_review;
  wire [18:0] done, failed;
  for (genvar rate = 0; rate < 3; rate++) begin : rates
    for (genvar mode = 0; mode < 3; mode++) begin : modes
      for (genvar stop = 0; stop < 2; stop++) begin : stops
        localparam integer INDEX = rate * 6 + mode * 2 + stop;
        review_stream #(.BIT_TIME(157 + rate * 3),
                        .WIDTH(mode == 0 ? 8 : 7),
                        .MODE(mode == 0 ? uart_pkg::NONE :
                              mode == 1 ? uart_pkg::EVEN : uart_pkg::ODD),
                        .STOP_BITS(stop + 1), .START_PHASE(INDEX % 10))
          stream(done[INDEX], failed[INDEX]);
      end
    end
  end
  review_tx_parity parity(done[18], failed[18]);
  initial begin
    wait (&done);
    if (|failed)
      $fatal(1, "Additional review regressions found functional failures");
    $display("PASS: additional review regressions");
    $finish;
  end
  initial begin
    #200000;
    $fatal(1, "review timeout");
  end
endmodule
