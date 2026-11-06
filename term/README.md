# FPGA UART terminal

Run in a Windows terminal (PowerShell or Command Prompt):

```powershell
cd term
uv run main.py
```

Select a numbered COM port, then type ASCII characters to send them immediately
(no Enter required). The connection uses **9600 baud, 8 data bits, no parity,
1 stop bit**, matching `src/uart_pkg.sv`. Press **Ctrl+C** to exit.

Received bytes appear as `RX: b'A'`. Non-printable bytes are escaped (for example,
`b'\x00'`) so every received byte remains visible. Enter sends carriage return
(`\r`). The FPGA loopback should return the character you send.

If no ports appear, check the USB connection and serial driver. Close any other
application using the selected port before connecting.
