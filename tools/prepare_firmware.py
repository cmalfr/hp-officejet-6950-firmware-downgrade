#!/usr/bin/env python3
import argparse
from pathlib import Path

DEFAULT_TERMINATOR = b"S705401D8954C0"

def main():
    ap = argparse.ArgumentParser(description="Split an unpacked HP OfficeJet reflash stream into stage1, F command and payload.")
    ap.add_argument("input", type=Path, help="Unpacked firstStage.bin")
    ap.add_argument("--out", type=Path, default=Path("prepared"), help="Output directory")
    ap.add_argument("--terminator", default=DEFAULT_TERMINATOR.decode(), help="ASCII S-record terminator marker")
    args = ap.parse_args()

    data = args.input.read_bytes()
    term = args.terminator.encode("ascii")

    pos = data.find(term)
    if pos < 0:
        raise SystemExit(f"Terminator not found: {args.terminator}")

    line_end = data.find(b"\n", pos)
    if line_end < 0:
        raise SystemExit("Terminator line has no LF")
    stage1_end = line_end + 1

    if stage1_end >= len(data) or data[stage1_end:stage1_end+1] != b"F":
        raise SystemExit("Expected F<size> command immediately after stage1")

    f_end = data.find(b"\n", stage1_end)
    if f_end < 0:
        raise SystemExit("F command has no LF")
    f_end += 1

    f_command = data[stage1_end:f_end]
    try:
        announced = int(f_command[1:-1], 16)
    except Exception as e:
        raise SystemExit(f"Invalid F command {f_command!r}: {e}")

    payload = data[f_end:]
    if len(payload) != announced:
        raise SystemExit(
            f"Payload size mismatch: announced 0x{announced:X}, actual 0x{len(payload):X}"
        )

    stage1 = data[:stage1_end]

    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "stage1.srec").write_bytes(stage1)
    (args.out / "f-command.bin").write_bytes(f_command)
    (args.out / "payload.bin").write_bytes(payload)

    print(f"stage1 : {len(stage1)} bytes (0x{len(stage1):X})")
    print(f"F cmd  : {f_command!r}")
    print(f"payload : {len(payload)} bytes (0x{len(payload):X})")
    print(f"output  : {args.out.resolve()}")

if __name__ == "__main__":
    main()
