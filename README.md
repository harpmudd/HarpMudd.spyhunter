# Spy Hunter — Analogue Pocket

An Analogue Pocket port of **Spy Hunter** (Bally Midway, 1983) by **HarpMudd**,
built on the openFPGA framework.

## The Game

Spy Hunter puts you behind the wheel of the G-6155 Interceptor, a weaponized
super-car barreling down an endless highway. Dodge and destroy a rogue's
gallery of enemy vehicles — the Switchblade, Enforcer, Bulletproof Bully, Mad
Bomber and Road Lord — using twin machine guns and special weapons (oil slicks,
smoke screens, missiles) collected from the weapons van. Hit the water and the
car becomes a boat. All of it set to a driving rendition of the *Peter Gunn*
theme. A genre-defining vertical-scrolling action classic.

## Hardware

Spy Hunter runs on Bally Midway's **MCR3** board — one of the more ambitious
arcade designs of its era, with three processors:

| Part | Role |
|---|---|
| Zilog Z80 | Main CPU — gameplay, video |
| Zilog Z80 (SSIO board) | Sound effects, driving dual AY-3-8910 PSGs |
| Motorola 68000 (Cheap Squeak Deluxe) | Music — the *Peter Gunn* theme |
| Display | Vertical CRT, 15 kHz, RGB |

## The Port

Built on the excellent MiSTer **Arcade-SpyHunter** core:

- **MiSTer port:** Sorgelig (2019)
- **FPGA arcade hardware implementation:** Dar — [darfpga](https://darfpga.blogspot.fr) (darfpga@aol.fr)

This Analogue Pocket build adapts that RTL to the openFPGA / APF framework —
all three CPUs running, SSIO + Cheap Squeak Deluxe audio, rendered at 480×480
31 kHz progressive in the original vertical orientation. Huge thanks to Sorgelig
and Dar; without their work this port wouldn't exist.

## Controls

| Pocket | Action |
|---|---|
| **D-Pad ←/→** | Steer |
| **D-Pad ↑** | Accelerate |
| **D-Pad ↓** | Brake |
| **A** | Machine guns |
| **B** | Missiles |
| **X** | Smoke screen |
| **Y** | Oil slick |
| **L (shoulder)** | Gear shift (Hi/Lo) |
| **Start** | Weapons van (pull alongside to re-arm) |
| **Select** | Insert coin (1 press = 1 credit) |

## Notes & Caveats

- **Audio tuning is in progress.** Both sound boards work — SSIO sound effects
  and the Cheap Squeak Deluxe *Peter Gunn* music both play — but the relative
  balance between them is still being optimized. A future update will refine it.

## ROMs

ROMs are **not** included and are never distributed with this core. Supply your
own Spy Hunter MAME romset and build the ROM image yourself. (A bundled `.mra`
build recipe — like the other HarpMudd cores ship — is planned for a future
update.)

## Credits

- **Original arcade game:** Bally Midway (1983)
- **MiSTer Arcade-SpyHunter port:** Sorgelig
- **FPGA arcade core:** Dar (darfpga)
- **Analogue Pocket port:** HarpMudd
- **Z80 CPU core (T80):**
  - **Daniel Wallner** — original author (2001–2002, OpenCores)
  - **Mike Johnson / MikeJ** (FPGAArcade) — DJNZ M1_n fix, clock enable, IM 2 fix
    and interrupt-ack fix (v0232–0240); project tidy-up, March 2005 (Ver 300)
  - **Sean Riddle** — parity flag for 8080 vs Z80 (Ver 301)
  - **TobiFlex** — undocumented DDCB / FDCB opcodes (Ver 303, 20 April 2010)
  - **Alexey Melnikov (Sorgelig)** — timing accuracy and ZEXDOC / ZEXALL /
    Z80Full / Z80memptr verification (Ver 350, 2018), and the `T80pa`
    pseudo-asynchronous top level
- **SDRAM controller, data loader, I2S audio, sync FIFO:** Adam Gastineau (agg23)
- **openFPGA framework (APF), bridge command handler, reference `core_top`:** Analogue
- **PLL and other megafunctions:** Intel/Altera (Quartus-generated)

## About / Support

I'm into retro games and the Analogue Pocket, always cooking up something new.
I love being part of a community built on sharing and the love of games — so if
any of my projects bring you joy, grab me a coffee; it fuels the next thing.

☕ **[buymeacoffee.com/harpmudd](https://buymeacoffee.com/harpmudd)**
