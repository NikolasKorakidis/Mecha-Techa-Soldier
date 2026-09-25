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

## Runtime (`autoload/audio_service.gd`)
- Buses `Music` (−7 dB base), `SFX`, `UI`; Options → Music / Effects volume sliders (saved in settings).
- `AudioService.play(id)` — 24-voice pool, per-effect minimum gap (rapid fire, explosion spam), per-effect trim,
  slight pitch variation.
- `play_music(id, fade)` crossfades (same id = no restart), `stop_music`, `play_jingle` ducks the loop.
- `play_explosion(size)` picks small/large/huge; 3D explosions far from the camera stay silent.
- Headless runs (tests, CI, boot check) track state but never start voices (no audio device).

## Where sounds fire
Weapons (`WeaponComponent`, `Bolt3D`, arc), hits/armor pings/player hurt (`HurtboxComponent`), explosions,
jumps/double jumps/dash/landing/boost/death/SUPER (players), pickups, checkpoints, WARNING, gates,
transformations and heavy landing (campaign), UI focus/confirm. Directors choose music per stage/boss.

## Replacing with produced audio later
Drop same-named files into `assets/audio/` (e.g. `stage1.ogg` → update `MUSIC_DIR` extension) — gameplay only
refers to ids.
