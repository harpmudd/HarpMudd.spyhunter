# Spy Hunter — Analogue Pocket

An Analogue Pocket port of **Spy Hunter** (Bally Midway, 1983), built on the
openFPGA framework.

## The Game

Drive the G-6155 Interceptor down an endless highway, taking out enemy cars
with machine guns, missiles, oil slicks and smoke screens from the weapons
van. Hit the water and the car becomes a boat, all to the *Peter Gunn* theme.

## Hardware

| Part | Role |
|---|---|
| Zilog Z80 @ 5 MHz | Main CPU |
| Zilog Z80 + 2× AY-3-8910 (SSIO) | Sound effects |
| Motorola 68000 + DAC (Cheap Squeak Deluxe) | Music |
| Display | Vertical CRT, 480×480 |

## Controls

| Pocket | Action |
|---|---|
| **D-Pad ← / →** | Steer |
| **D-Pad ↑ / ↓** | Accelerate / slow down |
| **A** | Machine guns |
| **B** | Missiles |
| **X** | Smoke screen |
| **Y** | Oil slick |
| **L** | Gear shift (hold) |
| **Start** | Weapons van |
| **Select** | Insert coin (1 press = 1 credit) |

Buttons can be remapped from the Pocket's Controls screen. In the Dock,
steer with the controller's d-pad; the analog stick isn't used.

## Settings

**SFX Volume** and **Music Volume** (0–10) set the balance between the sound
effects and the music.

## Versions

Spy Hunter is at the top of the game list; the Playtronic release is in
`_alternatives`.

| Menu entry | Set |
|---|---|
| Spy Hunter | `spyhunt` |
| Spy Hunter (Playtronic) | `spyhuntp` |

## ROMs

ROMs are **not** included. Build each `.rom` from your own MAME romset with
the `.mra` recipe in `dist/Assets/spyhunter/common/` (e.g. `mra spyhunt.mra`),
and put it in `Assets/spyhunter/common/` on your SD card. The Playtronic set
also needs the parent `spyhunt.zip`.

## Credits

- **Original arcade game:** Bally Midway (1983)
- **MAME MCR3 and sound board drivers:** [Aaron Giles](https://github.com/aaronsgiles)
- **MAME AY-3-8910 model:** [Couriersud](https://github.com/couriersud)
- **FPGA arcade core:** Dar ([darfpga](https://darfpga.blogspot.fr))
- **MiSTer port:** [Sorgelig](https://github.com/Sorgelig)
- **Analogue Pocket port:** [HarpMudd](https://github.com/harpmudd)
- **Z80 CPU (T80):** [Daniel Wallner](https://opencores.org/projects/t80), [MikeJ](https://www.fpgaarcade.com), [Sean Riddle](http://seanriddle.com), [TobiFlex](https://github.com/TobiFlex), [Sorgelig](https://github.com/Sorgelig)
- **68000 CPU (FX68K):** [Jorge Cwik](https://github.com/ijor/fx68k)
- **6821 PIA:** John E. Kent
- **RAM modules:** [Peter Wendrich](https://www.syntiac.com)
- **YM2149 sound:** [MikeJ](https://www.fpgaarcade.com)
- **Data loader, I2S audio, sync FIFO:** [agg23](https://github.com/agg23)
- **openFPGA framework:** [Analogue](https://www.analogue.co)

## About / Support

I'm into retro games and the Analogue Pocket, always cooking up something new.
I love being part of a community built on sharing and the love of games — so if
any of my projects bring you joy, chip in below; it fuels the next thing.

💛 **[Support this project via PayPal](https://www.paypal.com/donate/?hosted_button_id=S22WV924XU2ME)**
