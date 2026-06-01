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

## Credits

- **Original arcade game:** Bally Midway (1983)
- **MiSTer Arcade-SpyHunter port:** Sorgelig
- **FPGA arcade core:** Dar (darfpga)
- **Analogue Pocket port:** HarpMudd

## About / Support

I'm into retro games and the Analogue Pocket, always cooking up something new.
I love being part of a community built on sharing and the love of games — so if
any of my projects bring you joy, grab me a coffee; it fuels the next thing.

☕ **[buymeacoffee.com/harpmudd](https://buymeacoffee.com/harpmudd)**
