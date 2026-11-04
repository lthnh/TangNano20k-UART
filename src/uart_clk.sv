module uart_clk
(
  uart_if.clk_mp _if
);
  import uart_pkg::*;

  localparam int unsigned BIT_PERIOD =
    uart_pkg::XTAL_FREQ / uart_pkg::BAUD_RATE;
  localparam int unsigned OVERSAMPLING_BIT_PERIOD = BIT_PERIOD / OVERSAMPLING_RATE;
  logic [15:0] tx_counter;
  logic [15:0] rx_counter;

  always_ff @(posedge _if.sys_clk or negedge _if.rst_n) begin
    if (!_if.rst_n) begin
      tx_counter <= '0;
      rx_counter <= '0;
      _if.tx_clk <= '0;
      _if.rx_clk <= '0;
    end else begin
      if (tx_counter + 1 < BIT_PERIOD) begin
        tx_counter <= tx_counter + 1;
        _if.tx_clk <= '0;
      end else begin
        tx_counter <= '0;
        _if.tx_clk <= '1;
      end
      if (rx_counter + 1 < OVERSAMPLING_BIT_PERIOD) begin
        rx_counter <= rx_counter + 1;
        _if.rx_clk <= '0;
      end else begin
        rx_counter <= '0;
        _if.rx_clk <= '1;
      end
    end
  end
endmodule
