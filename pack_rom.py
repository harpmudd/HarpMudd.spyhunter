"""
pack_rom.py - Build a flat ROM image for the HarpMudd Spy Hunter Pocket core.

Spy Hunter (Bally Midway, 1983) - MCR3 board family. Triple-CPU:
  - Z80 main           (program ROMs 56 KB)
  - Z80 SSIO sound     (8 KB)
  - Motorola 68000     (Cheap Squeak Deluxe music/voice, 32 KB)
Plus 128 KB sprite ROMs, 32 KB BG ROMs, 4 KB alpha ROM = 264 KB total.

ROM image layout (0x41000 bytes, byte offset = dn_addr in FPGA):
  0x00000-0x0DFFF  Main Z80 program (cpu_pg0..pg5 = 5 x 8K + 1 x 16K = 56 KB)
  0x0E000-0x0FFFF  SSIO sound Z80 program (snd_0_sd + snd_1_sd = 8 KB)
  0x10000-0x17FFF  CSD m68k program (u17/u18/u7/u8 = 32 KB, byte-pair 16-bit)
  0x18000-0x37FFF  Sprite graphics (vid_0fg..vid_7fg = 128 KB, 4 byte-lanes x 32 KB)
  0x38000-0x3BFFF  BG ROMs 1 (cpu_bg0 + cpu_bg1 = 16 KB)
  0x3C000-0x3FFFF  BG ROMs 2 (cpu_bg2 + cpu_bg3 = 16 KB)
  0x40000-0x40FFF  CH/Alpha ROM (cpu_alpha-n = 4 KB)
Image ends at 0x41000. NO zero-padding.

Sprite section is 4 lanes of 32 KB each. Each lane = a contiguous pair from
the .mra order (lane 0 = video_1fg+video_0fg, lane 1 = video_3fg+video_2fg,
etc.). Tapper's bring-up established this layout for MCR3 sprite ROMs.

CSD region holds 32 KB of 68000 program. The .mra orders the 4 chips as
u17, u18, u7, u8 - pairs (u17,u18) and (u7,u8) form 16 KB each. Within each
pair, one chip is the LSB and one is the MSB of 16-bit words; the
byte-interleave is handled in core_top.v's CSD dpram instantiation, not here.

Usage:
  python pack_rom.py
"""

import sys
import zipfile
import zlib
import os

HERE = os.path.dirname(os.path.abspath(__file__))
# MAME romset .zip files. No machine-specific path is committed: set the
# HARPMUDD_ROMS env var, drop the .zip files next to this script, or keep a
# "Downloaded_Artifacts" folder beside the repo (dev convention).
DEFAULT_ZIP_DIR = next(
    (d for d in (os.environ.get("HARPMUDD_ROMS"),
                 os.path.join(os.path.dirname(HERE), "Downloaded_Artifacts"))
     if d and os.path.isdir(d)),
    HERE)
ASSETS_DIR      = os.path.join(HERE, "dist", "Assets", "spyhunter", "common")

ROM_IMAGE_SIZE = 0x41000  # 264 KB

# (CRC32, expected_size, description, rom_image_offset, mirror_offset_or_None)
SPYHUNTER_ROM_DEFS = [
    # Main Z80 program (56 KB)
    (0x1721b88f,  8192, "cpu_pg0.6d  (Z80 main prog block 0)",      0x00000, None),
    (0x909d044f,  8192, "cpu_pg1.7d  (Z80 main prog block 1)",      0x02000, None),
    (0xafeeb8bd,  8192, "cpu_pg2.8d  (Z80 main prog block 2)",      0x04000, None),
    (0x5e744381,  8192, "cpu_pg3.9d  (Z80 main prog block 3)",      0x06000, None),
    (0xa3033c15,  8192, "cpu_pg4.10d (Z80 main prog block 4)",      0x08000, None),
    (0x88aa1e99, 16384, "cpu_pg5.11d (Z80 main prog block 5, 16K)", 0x0A000, None),

    # SSIO sound Z80 program (8 KB)
    # Z80 reset vector at 0x0000 (= image 0x0E000) needs DI/NOP/LD SP code.
    # CRC c95cf31e starts with F3 00 00 00 31 FF 83 ED = DI; NOPx3; LD SP,$83FF
    # -> this MUST be the low half. CRC 12aaa48e (starts 0A 0F 18 00) is high.
    (0xc95cf31e,  4096, "snd_0_sd (SSIO low,  reset vector here)",  0x0E000, None),
    (0x12aaa48e,  4096, "snd_1_sd (SSIO high)",                     0x0F000, None),

    # Cheap Squeak Deluxe m68k program (32 KB) -- .mra order u17/u18/u7/u8
    (0x0d9ddce6,  8192, "csd_u17b.u17 (CSD m68k prog)",             0x10000, None),
    (0x63d3f5b1,  8192, "csd_u18d.u18 (CSD m68k prog)",             0x12000, None),
    (0x6e689fe7,  8192, "csd_u7a.u7   (CSD m68k prog)",             0x14000, None),
    (0x35563cd0,  8192, "csd_u8c.u8   (CSD m68k prog)",             0x16000, None),

    # Sprite ROMs (128 KB) -- .mra pair order: 1fg+0fg, 3fg+2fg, 5fg+4fg, 7fg+6fg
    (0x9fe286ec, 16384, "vid_1fg.a7  (sprite lane 0a)",             0x18000, None),
    (0x292c5466, 16384, "vid_0fg.a8  (sprite lane 0b)",             0x1C000, None),
    (0xb894934d, 16384, "vid_3fg.a5  (sprite lane 1a)",             0x20000, None),
    (0x62c8bfa5, 16384, "vid_2fg.a6  (sprite lane 1b)",             0x24000, None),
    (0x2d9fbcec, 16384, "vid_5fg.a3  (sprite lane 2a)",             0x28000, None),
    (0x7ca4941b, 16384, "vid_4fg.a4  (sprite lane 2b)",             0x2C000, None),
    (0x940fe17e, 16384, "vid_7fg.a1  (sprite lane 3a)",             0x30000, None),
    (0x8cb8a066, 16384, "vid_6fg.a2  (sprite lane 3b)",             0x34000, None),

    # BG ROMs (32 KB total: 16 KB into bg_graphics_1, 16 KB into bg_graphics_2)
    (0xdea34fed,  8192, "cpu_bg0.3a  (BG graphics 1, low)",         0x38000, None),
    (0x8f64525f,  8192, "cpu_bg1.4a  (BG graphics 1, high)",        0x3A000, None),
    (0xba0fd626,  8192, "cpu_bg2.5a  (BG graphics 2, low)",         0x3C000, None),
    (0x7b482d61,  8192, "cpu_bg3.6a  (BG graphics 2, high)",        0x3E000, None),

    # Character / alpha layer (4 KB)
    (0x936dc87f,  4096, "cpu_alph.10g (character / alpha ROM)",     0x40000, None),
]

OUT_NAME = "spyhunter.rom"


def crc32_of(data):
    return zlib.crc32(data) & 0xFFFFFFFF


def load_zip_by_crc(zip_path):
    found = {}
    with zipfile.ZipFile(zip_path) as zf:
        for info in zf.infolist():
            data = zf.read(info.filename)
            found[crc32_of(data)] = data
    return found


def load_dir_by_crc(zip_dir):
    found = {}
    zips = sorted(f for f in os.listdir(zip_dir) if f.lower().endswith('.zip'))
    if not zips:
        print(f"  (no zip files found in {zip_dir})")
        return found
    for zname in zips:
        print(f"  scanning {zname}")
        try:
            found.update(load_zip_by_crc(os.path.join(zip_dir, zname)))
        except Exception as e:
            print(f"  WARNING: could not read {zname}: {e}")
    return found


def main():
    out_path = os.path.join(ASSETS_DIR, OUT_NAME)
    print("ROM packer - Spy Hunter (Bally Midway, 1983)")
    print(f"Output: {out_path}\n")
    print(f"Scanning all zips in: {DEFAULT_ZIP_DIR}")
    found = load_dir_by_crc(DEFAULT_ZIP_DIR)
    print()

    image = bytearray(ROM_IMAGE_SIZE)
    errors = []

    for (crc, size, d, offset, mirror) in SPYHUNTER_ROM_DEFS:
        if crc in found:
            data = found[crc]
            if len(data) != size:
                errors.append(f"  WRONG SIZE  {d}: expected {size}, got {len(data)}")
                continue
            image[offset:offset + size] = data
            if mirror is not None:
                image[mirror:mirror + size] = data
            print(f"  OK          {d}  @ 0x{offset:05X}")
        else:
            errors.append(f"  MISSING     {d}  (CRC {crc:08x})")

    print()
    if errors:
        print("MISSING OR INVALID ROMs:")
        for e in errors:
            print(e)
        sys.exit(1)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(image)

    print(f"\nSUCCESS: wrote {len(image)} bytes -> {out_path}")


if __name__ == "__main__":
    main()
