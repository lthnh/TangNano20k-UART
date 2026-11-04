module uart_loop
(
  input logic sys_clk,
  input logic rst_n,
  input logic rx,
  input logic en,
  output logic tx
);
  import uart_pkg::*;

  loop_state_e curr_state;

  uart_if _if();

  assign _if.sys_clk = sys_clk;
  assign _if.rst_n = rst_n;
  assign _if.rx = rx;
  assign tx = _if.tx;

  uart_clk uart_clk
  (
    ._if(_if)
  );

  uart_rx
  #(
    .DATA_WIDTH(DATA_WIDTH /* default uart_pkg::DATA_WIDTH */),
    .PARITY_BIT(PARITY_BIT /* default uart_pkg::PARITY_BIT */),
    .STOP_WIDTH(STOP_WIDTH /* default uart_pkg::STOP_WIDTH */)
  ) uart_rx (
    ._if(_if)
  );

  uart_tx
  #(
    .DATA_WIDTH(DATA_WIDTH /* default uart_pkg::DATA_WIDTH */),
    .PARITY_BIT(PARITY_BIT /* default uart_pkg::PARITY_BIT */),
    .STOP_WIDTH(STOP_WIDTH /* default uart_pkg::STOP_WIDTH */)
  ) uart_tx (
    ._if(_if)
  );

  always_ff @(posedge _if.tx_clk or negedge rst_n) begin
    if (!rst_n) curr_state <= LOOP_IDLE;
    if (_if.tx_clk && rst_n)
      case (curr_state)
        LOOP_IDLE: begin
          if (en) curr_state <= LOOP_START;
        end
        default: curr_state <= LOOP_IDLE;
      endcase
  end
endmodule
