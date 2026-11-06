`timescale 1ns/1ps
module tb_uart_loop;
  localparam integer BIT_TIME = 15000; // 7500 sys_clk periods at 9600 baud.
  logic sys_clk = 0;
  logic rst_n = 1, en = 0, rx = 1;
  wire tx, err;
  integer received = 0;
  logic [7:0] value;
  uart_loop dut(.*);
  always #1 sys_clk = ~sys_clk;

  task automatic send_frame(input logic [7:0] data, input logic bad_stop = 0);
    rx = 0;
    #(BIT_TIME);
    for (int i = 0; i < 8; i++) begin
      rx = data[i];
      #(BIT_TIME);
    end
    rx = !bad_stop;
    #(BIT_TIME);
    rx = 1;
  endtask

  initial forever begin
    @(negedge tx);
    #(BIT_TIME / 2);
    if (tx !== 0) $fatal(1, "invalid TX start");
    for (int i = 0; i < 8; i++) begin
      #(BIT_TIME);
      value[i] = tx;
    end
    #(BIT_TIME);
    if (tx !== 1) $fatal(1, "invalid TX stop");
    if ((received == 0 && value !== 8'h96) ||
        (received == 1 && value !== 8'h27) || received > 1)
      $fatal(1, "unexpected or duplicated echo %h (index %0d)", value, received);
    received++;
  end

  initial begin
    #2;
    rst_n = 0;
    #10;
    rst_n = 1;
    en = 1;
    #(BIT_TIME * 5 + 7);
    send_frame(8'h96);
    wait (received == 1);
    #(BIT_TIME * 30);
    if (err || received != 1) $fatal(1, "unexpected error or duplicate echo");
    send_frame(8'h52, 1);
    #(BIT_TIME * 10);
    if (!err || received != 1) $fatal(1, "bad frame was not rejected");
    send_frame(8'h27);
    wait (received == 2);
    #(BIT_TIME * 30);
    $display("PASS: loop echoes exactly once and recovers after framing error");
    $finish;
  end
  initial begin
    #(BIT_TIME * 200);
    $fatal(1, "loop timeout");
  end
endmodule
