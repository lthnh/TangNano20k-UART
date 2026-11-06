package uart_pkg;
  typedef enum {NONE, ODD, EVEN} parity_bit_e;
  typedef enum {RX_IDLE, RX_DATA, RX_PARITY, RX_STOP} rx_state_e;
  typedef enum {TX_IDLE, TX_SEND} tx_state_e;
  typedef enum {LOOP_IDLE, LOOP_START, LOOP_RECEIVE,
                LOOP_TX_ACCEPT, LOOP_SEND} loop_state_e;
  localparam int unsigned DATA_WIDTH = 8;
  localparam parity_bit_e PARITY_BIT = NONE;
  localparam int unsigned STOP_WIDTH = 1;
  localparam int unsigned BAUD_RATE = 9600;
  localparam int unsigned XTAL_FREQ = 27_000_000;
  localparam int unsigned OVERSAMPLING_RATE = 16;
  localparam logic START_SIG = '0;
  localparam logic STOP_SIG = '1;
  localparam logic IDLE_SIG = '1;

  function automatic logic calc_parity
  (
    parity_bit_e PARITY_BIT_CFG,
    input logic [7:0] data
  );
    case (PARITY_BIT_CFG)
      NONE:    return 'Z;
      EVEN:    return ^data;
      ODD:     return ~^data;
      default: return 'Z;
    endcase
  endfunction
endpackage
