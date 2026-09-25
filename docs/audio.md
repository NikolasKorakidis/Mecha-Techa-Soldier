# SHIFT//WING — Audio

All music and sound effects are **generated from code** (`tools/audio/`), so every note is original and
license-clean for Steam/commercial use. Style target: serious mecha epic in a 16-bit (SNES, 32 kHz) palette —
driven guitars, slap bass, brass, bell arpeggios, punchy drums and SNES-style echo — in the spirit of
Mega Man X2/X3-era soundtracks (style reference only; no melodies are copied).

## Regenerate
```bash
pip install numpy scipy
python3 tools/audio/build.py            # everything
python3 tools/audio/build.py stage2 jump   # only some tracks/effects
```
Output: `assets/audio/music/*.wav`, `assets/audio/sfx/*.wav` (mono, 32 kHz, 16-bit). Godot imports them as
QOA-compressed streams; music `.import` files set `edit/loop_mode=2` (forward loop). Loops are seamless:
the renderer folds echo/reverb tails back onto the start.

## Tracks
| Id | Title | Key / tempo | Used for |
|---|---|---|---|
| `title` | Echoes of Kharon | D minor, 80 bpm | Title screen, boarding-run flight |
| `stage1` | Orbital Riptide | E minor, 138 bpm | Stage 1 |
| `boss` | Guardian | C minor, 162 bpm | Choir Engine, Reactor Core |
| `stage2` | Warship Infiltration | A minor, 150 bpm | Stage 2 |
| `stage3` | Hull Run | B minor, 178 bpm | Escape + Stage 3 |
| `stage_clear` | — | D major | Jingle after each boss (music ducks) |
| `mission_complete` | — | D major, 88 bpm | Ending |
| `stage4` | Pixel Riptide | E minor, 150 bpm | Stage 4 (8-bit): the Stage 1 theme on 2 pulses + triangle + noise |
| `boss8` | Core Breaker | C minor, 168 bpm | Stage 4 boss |
| `clear8` | — | E major | Stage 4 clear jingle |

Stage 4 voices live in `tools/audio/nes.py`: 12.5/25/50 % pulses, a 4-bit stepped triangle and LFSR
noise, 16-level quantized envelopes, no echo or reverb. Effects: `retro_shot`, `retro_boom`, `retro_hit`,
`retro_power`, `retro_1up`.

## Runtime (`autoload/audio_service.gd`)
- Buses `Music` (−7 dB base), `SFX`, `UI`, defined in `default_bus_layout.tres` (the web build's sample
  playback only routes buses from the project layout; buses added in code play silently there); Options → Music / Effects volume sliders (saved in settings).
- `AudioService.play(id)` — 24-voice pool, per-effect minimum gap (rapid fire, explosion spam), per-effect trim,
  slight pitch variation.
- `play_music(id, fade)` crossfades (same id = no restart), `stop_music`, `play_jingle` ducks the loop.
- `start_loop(id)` / `stop_loop(player)` — held loops on their own player (ids in `LOOPS`, e.g. the bike
  engine, whose pitch and volume the rider drives from speed, boost and airtime).
- `play_explosion(size)` picks small/large/huge; 3D explosions far from the camera stay silent.
- Headless runs (tests, CI, boot check) track state but never start voices (no audio device).

## Effects pass 2 (`tools/audio/sfx_v2.py`)
Overrides the first-pass effects with layered, loudness-matched designs (`_loud()` targets an RMS per
effect so nothing sits under the music) and adds: `wall_jump`, `mech_step`, `whoosh`, `bike_engine`
(seamless 1 s loop: every partial completes whole cycles), `bike_crash`, `bike_land`, `boss_roar`,
`boss_break`.

## Where sounds fire
- Stage 1: ship shots/lasers, enemy shots, hits, explosions, dash, hurt, death, pickups; boss roar on entry,
  a heavy crash at each phase break and on defeat; the boarding dive whooshes.
- Stage 2: mech footsteps, jump / double jump / wall kick, dash, landing, charge shot, hits, pickups,
  checkpoints, doors, boss roar and breaks.
- Stage 3: bike engine loop (pitch follows speed, revs on boost and in the air), jump, boost, landing thud,
  crash on every hit, crash + death on wreck, gunship roar.
- Stage 4: its own 8-bit set. Everywhere: UI focus/confirm, WARNING, transformations.
Directors choose music per stage/boss (music is untouched by the effects pass).

## Replacing with produced audio later
Drop same-named files into `assets/audio/` (e.g. `stage1.ogg` → update `MUSIC_DIR` extension) — gameplay only
refers to ids.
