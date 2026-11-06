module uart_tx
#(
  parameter int unsigned DATA_WIDTH = uart_pkg::DATA_WIDTH,
  parameter uart_pkg::parity_bit_e PARITY_BIT = uart_pkg::PARITY_BIT,
  parameter int unsigned STOP_WIDTH = uart_pkg::STOP_WIDTH
)
(
  uart_if.tx_mp _if
);
  import uart_pkg::*;

  localparam int unsigned DATA_FRAME_LEN =
    1 + DATA_WIDTH + (PARITY_BIT != NONE ? 1 : 0) + STOP_WIDTH;

  tx_state_e curr_state;
  logic [15:0] data_frame;
  logic [15:0] send_frame;
  logic parity_result;
  logic latched;
  logic [7:0] bit_sent_cnt;

  // Only transmitted payload bits participate in parity. The interface can
  // contain unrelated high bits when DATA_WIDTH is less than eight.
  assign parity_result = (PARITY_BIT == ODD)
    ? ~^_if.tx_data[DATA_WIDTH-1:0] : ^_if.tx_data[DATA_WIDTH-1:0];

  always_comb begin
    if (!_if.rst_n) data_frame = '0;

    if (PARITY_BIT != NONE)
      data_frame =
      16'({
        {STOP_WIDTH{STOP_SIG}},
        parity_result,
        _if.tx_data[DATA_WIDTH-1:0],
        START_SIG
      });
    else
      data_frame = 
      16'({
        {STOP_WIDTH{STOP_SIG}},
        _if.tx_data[DATA_WIDTH-1:0],
        START_SIG
      });
  end

  always_ff @(posedge _if.tx_clk or negedge _if.rst_n) begin
    if (!_if.rst_n) begin
      send_frame <= '0;
      latched <= '0;
      bit_sent_cnt <= '0;
      _if.tx <= IDLE_SIG;
      _if.tx_finish <= '0;
      curr_state <= TX_IDLE;
    end
    if (_if.rst_n && _if.tx_clk)
      case (curr_state)
        TX_IDLE:
          if (_if.tx_start) begin
            curr_state <= TX_SEND;
            _if.tx_finish <='0;
          end
        TX_SEND: begin
          if (!latched) begin
            send_frame <= data_frame;
            latched <= '1;
          end else if (bit_sent_cnt < DATA_FRAME_LEN) begin
            _if.tx <= send_frame[0];
            bit_sent_cnt <= bit_sent_cnt + 1;
            send_frame <= send_frame >> 1;
          end else begin
            latched <= '0;
            bit_sent_cnt <= '0;
            _if.tx_finish <= '1;
            curr_state <= TX_IDLE;
          end
        end
        default: curr_state <= TX_IDLE;
      endcase
  end
endmodule
