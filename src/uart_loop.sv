module uart_loop
(
  input logic sys_clk,
  input logic rx,
  output logic tx
);
  import uart_pkg::*;

  wire en = 1'b1;
  logic rst_n = 1'b1;
  logic reset_pending = 1'b1;
  logic err;

  // Assert reset on the first system-clock edge and release on the next.
  always_ff @(posedge sys_clk) begin
    rst_n <= !reset_pending;
    reset_pending <= 1'b0;
  end

  loop_state_e curr_state;
  logic finish_meta, finish_sync;
  logic overrun_meta, overrun_sync;

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

  // RX holds its payload until this clock domain acknowledges it. The
  // synchronized valid flag gives the bundled data/status time to settle.
  always_ff @(posedge _if.tx_clk or negedge rst_n) begin
    if (!rst_n) begin
      finish_meta <= 1'b0;
      finish_sync <= 1'b0;
      overrun_meta <= 1'b0;
      overrun_sync <= 1'b0;
    end else begin
      finish_meta <= _if.rx_finish;
      finish_sync <= finish_meta;
      overrun_meta <= _if.rx_overrun;
      overrun_sync <= overrun_meta;
    end
  end

  always_ff @(posedge _if.tx_clk or negedge rst_n) begin
    if (!rst_n) begin
      curr_state <= LOOP_IDLE;
      err <= '0;
      _if.rx_en <= '0;
      _if.tx_start <= '0;
      _if.tx_data <= '0;
      _if.rx_ack <= 1'b0;
    end else if (!en) begin
      curr_state <= LOOP_IDLE;
      err <= 1'b0;
      _if.rx_en <= 1'b0;
      _if.tx_start <= 1'b0;
      _if.tx_data <= '0;
      _if.rx_ack <= 1'b0;
    end else begin
      // Requests last one TX-clock cycle. Acknowledgment stays high until
      // RX withdraws its valid flag, completing the four-phase handshake.
      _if.tx_start <= 1'b0;
      if (!finish_sync) _if.rx_ack <= 1'b0;
      if (overrun_sync) err <= 1'b1;
      case (curr_state)
        LOOP_IDLE:
          if (en) curr_state <= LOOP_START;
        LOOP_START: begin
          _if.rx_en <= '1;
          curr_state <= LOOP_RECEIVE;
        end
        LOOP_RECEIVE: begin
          if (finish_sync && !_if.rx_ack) begin
            _if.rx_ack <= 1'b1;
            if (_if.rx_err) begin
              err <= 1'b1;
            end else begin
              _if.tx_data <= _if.rx_data;
              _if.tx_start <= 1'b1;
              curr_state <= LOOP_TX_ACCEPT;
            end
          end
        end
        // TX accepts the request on this edge and clears its old finish.
        LOOP_TX_ACCEPT: curr_state <= LOOP_SEND;
        LOOP_SEND:
          if (_if.tx_finish) curr_state <= LOOP_RECEIVE;
        default: curr_state <= LOOP_IDLE;
      endcase
    end
  end
endmodule
