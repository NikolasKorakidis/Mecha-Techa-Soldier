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
Supplied tracks (`stage1`, `boss1`, `stage2`, `stage3`) are listed in `USER_TRACKS` in `build.py`, which never
overwrites them. Loops whose last sample did not meet the first got a 20 ms equal-power crossfade of
the tail into the head so they wrap without a click.

| Id | Title | Key / tempo | Used for |
|---|---|---|---|
| `title` | Echoes of Kharon | D minor, 80 bpm | Title screen, boarding-run flight |
| `stage1` | Space Music Loop 1 (supplied track, 57.6 s stereo seamless loop) | — | Stage 1 |
| `boss` | Guardian | C minor, 162 bpm | Reactor Core, Sentinel |
| `boss1` | Battle Music Loop 1 (supplied track, 52.3 s stereo loop, seam crossfaded) | — | Stage 1 boss (Choir Colossus) |
| `stage2` | Action Game Music Loop 1 (supplied track, 29.5 s stereo loop, seam crossfaded) | — | Stage 2 |
| `stage3` | Electronic Music Loop 2 (supplied track, 44.3 s stereo loop, seam crossfaded) | — | Escape + Stage 3 |
| `stage_clear` | — | D major | Jingle after each boss (music ducks) |
| `mission_complete` | — | D major, 88 bpm | Ending |
| `stage4` | Pixel Riptide | E minor, 150 bpm | Stage 4 (8-bit): the Stage 1 theme on 2 pulses + triangle + noise |
| `boss8` | Core Breaker | C minor, 168 bpm | Stage 4 boss |
| `clear8` | — | E major | Stage 4 clear jingle |

Stage 4 voices live in `tools/audio/nes.py`: 12.5/25/50 % pulses, a 4-bit stepped triangle and LFSR
noise, 16-level quantized envelopes, no echo or reverb. Effects: `retro_shot`, `retro_boom`, `retro_hit`,
`retro_power`, `retro_1up`.

## Runtime (`autoload/audio_service.gd`)
- Buses `Music` (−8 dB base), `SFX`, `UI`, defined in `default_bus_layout.tres` (the web build's sample
  playback only routes buses from the project layout; buses added in code play silently there); Options → Music / Effects volume sliders (saved in settings).
- `AudioService.play(id)` — 24-voice pool, per-effect minimum gap (rapid fire, explosion spam), per-effect trim,
  slight pitch variation.
- `play_music(id, fade)` crossfades (same id = no restart), `stop_music`, `play_jingle` ducks the loop.
- `start_loop(id)` / `stop_loop(player)` — held loops on their own player (ids in `LOOPS`, e.g. the bike
  engine, whose pitch and volume the rider drives from speed, boost and airtime).
- `play_explosion(size)` picks small/large/huge; 3D explosions far from the camera stay silent.
- Headless runs (tests, CI, boot check) track state but never start voices (no audio device).

## Effects: studio pass (`tools/audio/sfx_hq.py`)
48 kHz stereo, rendered from code with proper band-limited oscillators, Butterworth filters, FM for metal and
bells, and a generated stereo room impulse (early reflections + decorrelated tail that darkens as it decays)
convolved onto each effect. No hard saturation: a soft knee only above −3 dBFS. Loudness targets (RMS of the
audible part) are authored per effect and deliberately soft — shots −22, hits −24, footsteps −27, jumps −22,
explosions −18 … −15, UI −24 … −28 dBFS — so the mix balance lives in the files, not in runtime trims.
Frequent effects ship several takes (`id.wav`, `id_2.wav` …; `AudioService.VARIANTS`) and `play()` never
repeats the previous take. Width comes from a ≤ 2.5 ms decorrelating delay blended with the dry signal, so
everything folds to mono cleanly. The bike engine is a seamless 2 s loop (every partial completes whole
cycles; the noise layer is filtered circularly). Stage 4 keeps its lo-fi 32 kHz mono NES set (`nes.py`).

Buses (`default_bus_layout.tres`): Master has a hard limiter (−0.8 dBFS ceiling), SFX a gentle glue compressor.
The web build's sample playback ignores bus effects (the files are already levelled for that).

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
