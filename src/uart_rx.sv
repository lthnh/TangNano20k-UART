module uart_rx
#(
  parameter int unsigned DATA_WIDTH = uart_pkg::DATA_WIDTH,
  parameter uart_pkg::parity_bit_e PARITY_BIT = uart_pkg::PARITY_BIT,
  parameter int unsigned STOP_WIDTH = uart_pkg::STOP_WIDTH
)
(
  uart_if.rx_mp _if
);
  import uart_pkg::*;

  rx_state_e curr_state;
  logic [7:0] bit_recv_cnt;
  logic [7:0] data;
  logic parity_result;

  assign parity_result = calc_parity(data);

  always_ff @(posedge _if.rx_clk or negedge _if.rst_n) begin
    if (!_if.rst_n) begin
      curr_state <= RX_IDLE;
      bit_recv_cnt <= '0;
      data <= '0;
      _if.rx_data <= '0;
      _if.rx_err <= '0;
      _if.rx_finish <= '0;
    end

    if (_if.rst_n && _if.rx_clk && _if.rx_start)
      case (curr_state)
        RX_IDLE: begin
          _if.rx_finish <= '0;
          if (_if.rx == START_SIG)
            curr_state <= RX_START;
        end
        RX_START: begin
          data <= '0;
          bit_recv_cnt <= '0;
          _if.rx_err <= '0;
          curr_state <= RX_DATA;
        end
        RX_DATA:
          if (bit_recv_cnt < DATA_WIDTH) begin
            data <= data << 1;
            data[0] <= _if.rx;
            bit_recv_cnt <= bit_recv_cnt + 1;
          end else begin
            curr_state <= RX_PARITY;
          end
        RX_PARITY: begin
          case (PARITY_BIT)
            NONE: ;
            ODD: if (parity_result != '1) _if.rx_err <= '1;
            EVEN: if (parity_result != '0) _if.rx_err <= '1;
            default: ;
          endcase
          curr_state <= RX_STOP;
          bit_recv_cnt <= '0;
        end
        RX_STOP: begin
          if (bit_recv_cnt < STOP_WIDTH) begin
            if (_if.rx == '1) begin
              bit_recv_cnt <= bit_recv_cnt + 1;
            end else begin
              _if.rx_err <= '1;
              curr_state <= RX_IDLE;
            end
          end
          else begin
            _if.rx_data <= data;
            curr_state <= RX_IDLE;
            _if.rx_finish <= '1;
          end
        end
        default: curr_state <= RX_IDLE;
      endcase
  end
endmodule
