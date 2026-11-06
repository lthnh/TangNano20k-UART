"""Small Windows serial terminal for the FPGA UART (9600 baud, 8N1)."""

import msvcrt

import serial
from serial.tools import list_ports


def main():
    ports = sorted(list_ports.comports(), key=lambda port: port.device)
    if not ports:
        print("No COM ports found. Connect the FPGA and try again.")
        return

    for index, port in enumerate(ports, start=1):
        print(f"{index}: {port.device} - {port.description}")

    try:
        choice = int(input("Select port number: "))
        if not 1 <= choice <= len(ports):
            raise ValueError
    except ValueError:
        print("Invalid port number.")
        return

    with serial.Serial(
        ports[choice - 1].device,
        baudrate=9600,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=0.02,
        write_timeout=1,
    ) as uart:
        print(f"Connected to {uart.port} (9600 8N1). Type to send; Ctrl+C to quit.")
        while True:
            if msvcrt.kbhit():
                char = msvcrt.getwch()
                if char == "\x03":
                    raise KeyboardInterrupt
                if char in ("\x00", "\xe0"):
                    msvcrt.getwch()  # Discard arrow/function-key scan codes.
                elif char.isascii():
                    uart.write(char.encode("ascii"))
                else:
                    print("Only ASCII characters can be sent.")

            received = uart.read(uart.in_waiting or 1)
            if received:
                print(f"RX: {received!r}")


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, EOFError):
        print("\nDisconnected.")
    except serial.SerialException as exc:
        print(f"Serial error: {exc}")
