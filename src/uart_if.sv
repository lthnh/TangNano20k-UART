interface uart_if;
  logic sys_clk;
  logic rst_n;

  logic tx_clk;
  logic tx;
  logic [7:0] tx_data;
  logic tx_start;
  logic tx_finish;

  logic rx_clk;
  logic rx;
  logic rx_err;
  logic [7:0] rx_data;
  logic rx_start;
  logic rx_finish;

  modport clk_mp
  (
    input sys_clk,
    input rst_n,
    output tx_clk,
    output rx_clk
  );

  modport tx_mp
  (
    input tx_clk,
    input rst_n,
    input tx_start,
    input tx_data,
    output tx
  );

  modport rx_mp
  (
    input rx_clk,
    input rst_n,
    input rx_start,
    input rx,
    output rx_err,
    output rx_finish,
    output rx_data
  );
endinterface
