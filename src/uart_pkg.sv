package uart_pkg;
  typedef enum {NONE, ODD, EVEN} parity_bit_e;
  typedef enum {RX_IDLE, RX_DATA, RX_PARITY, RX_STOP} rx_state_e;
  typedef enum {TX_IDLE, TX_SEND} tx_state_e;
  typedef enum {LOOP_IDLE, LOOP_START, LOOP_RECEIVE,
                LOOP_TX_ACCEPT, LOOP_SEND} loop_state_e;
  parameter int unsigned DATA_WIDTH = 8;
  parameter parity_bit_e PARITY_BIT = NONE;
  parameter int unsigned STOP_WIDTH = 1;
  parameter int unsigned BAUD_RATE = 9600;
  parameter int unsigned XTAL_FREQ = 72e6;
  parameter int unsigned OVERSAMPLING_RATE = 16;
  parameter logic START_SIG = '0;
  parameter logic STOP_SIG = '1;
  parameter logic IDLE_SIG = '1;

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
