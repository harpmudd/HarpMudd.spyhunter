"""
rebuild_hex.py - Slice spyhunter.rom into .hex files for Quartus $readmemh.

Pre-initializes Z80 sound ROM (and any other ROM regions) directly into
BRAMs at FPGA configuration time. Bypasses the data_loader path, so byte 0
(Z80 reset vector) is guaranteed correct regardless of any data_loader
quirks. Tapper pattern.

Run after pack_rom.py whenever the .rom changes.
"""

import os

PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
ROM_PATH = os.path.join(PROJECT_ROOT, "dist", "Assets", "spyhunter", "common", "spyhunter.rom")
HEX_DIR  = os.path.join(PROJECT_ROOT, "src", "fpga")


def write_hex(path, data):
    with open(path, "w") as f:
        for b in data:
            f.write(f"{b:02x}\n")
    print(f"  {os.path.relpath(path, PROJECT_ROOT):40s}  {len(data):6d} bytes")


def main():
    if not os.path.exists(ROM_PATH):
        print(f"ERROR: {ROM_PATH} not found. Run pack_rom.py first.")
        return 1

    rom = open(ROM_PATH, "rb").read()
    print(f"Source: {ROM_PATH}  ({len(rom)} bytes)")
    print()

    # Sound ROM (SSIO Z80) -- 8 KB at 0x0E000-0x0FFFF
    write_hex(os.path.join(HEX_DIR, "snd_rom.hex"), rom[0x0E000:0x10000])

    print("\nDone. Recompile to pick up the new .hex pre-init data.")
    return 0


if __name__ == "__main__":
    exit(main())
