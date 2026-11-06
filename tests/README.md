Run the self-checking simulations with Icarus Verilog and `vvp` on PATH:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run.ps1
```

The RX test covers whole-bit voting at different start phases, false starts,
consecutive frames, none/even/odd parity, parity and framing error recovery,
disable during reception, acknowledgment, and receive overrun. The loop test
checks complete serial echoes, rejects a framing error, and detects repeated
transmissions after the input becomes idle.

RX uses a single-result mailbox. `rx_finish` indicates an available result,
including an invalid frame whose `rx_err` is high. The receiver holds data and
status until the loop raises `rx_ack`. RX then lowers `rx_finish`; the loop
lowers `rx_ack` after observing that change. RX waits for acknowledgment to
return low before publishing another result. The control signals are
synchronized into their receiving clock domains.

Reception continues while a result is pending. If another frame completes
before the mailbox is free, RX preserves the older result, drops the newest
frame, and raises `rx_overrun`. This flag remains high until RX is disabled or
reset. The top-level `err` records frame errors and overruns until reset or
disable. This is bounded buffering, not a FIFO or sender flow control.

These simulations check RTL behavior; FPGA synthesis, timing constraints, and
hardware operation require separate validation.

The runner includes `tb_uart_review.sv`, which checks 64-frame consecutive
streams at nominal and approximately +/-2% bit periods, different start phases,
seven/eight-bit payloads, none/even/odd parity, and one/two stop bits. A separate
TX check ensures unused high data bits do not affect seven-bit parity.

The same file provides the `tb_uart_clk_review` top. The runner checks 9600,
300, and 110 baud, power-of-two divider periods requiring counters wider than
16 bits, the minimum supported pulse period, and rejection of zero baud or
an oversampling divider shorter than two system-clock cycles. These rejection
cases deliberately print a fatal diagnostic; the runner verifies that the
expected rejection occurred and reports PASS.
