"""8-bit (Famicom/NES-style) voices, tracks and sound effects for Stage 4.

Four-channel discipline like the 2A03: two pulse voices (12.5 / 25 / 50 % duty), a stepped
4-bit triangle for bass, and a noise channel for drums. Volume envelopes are quantized to 16
levels and nothing gets echo or reverb, so it sounds like a cartridge, not a synth.
All compositions are original (the Stage 4 theme is an 8-bit rearrangement of this game's own
Stage 1 melody).
"""
from synth import *  # noqa: F401,F403


def _steps(env: np.ndarray, levels: int = 15) -> np.ndarray:
    return np.round(env * levels) / levels


def nes_pulse(m: float, dur: float, vel: float, duty: float = 0.25, decay: float = 0.0, vib: bool = True) -> np.ndarray:
    n = int((dur + 0.02) * SR)
    f = np.full(n, freq(m))
    if vib and dur > 0.25:
        f = vibrato(n, freq(m), 0.18, 6.0, 0.2)
    ph = np.cumsum(f / SR) % 1.0
    x = np.where(ph < duty, 1.0, -1.0)
    env = np.ones(n)
    if decay > 0.0:
        env = np.maximum(0.25, np.exp(-t_axis(n) / decay))
    env[int(dur * SR):] = 0.0
    return x * _steps(env * vel) * 0.28


def nes_tri(m: float, dur: float, vel: float) -> np.ndarray:
    n = int((dur + 0.01) * SR)
    ph = np.cumsum(np.full(n, freq(m)) / SR) % 1.0
    tri_wave = 1.0 - 4.0 * np.abs(ph - 0.5)
    x = np.round(tri_wave * 7.5) / 7.5  # 4-bit staircase
    x[int(dur * SR):] = 0.0
    return x * 0.42


def _lfsr_noise(n: int, rate: float) -> np.ndarray:
    hold = max(1, int(SR / rate))
    raw = np.sign(RNG.standard_normal(n // hold + 2))
    return np.repeat(raw, hold)[:n]


def nes_kick(vel: float = 1.0) -> np.ndarray:
    n = int(0.16 * SR)
    f = 180 * np.exp(-t_axis(n) / 0.03) + 45
    ph = np.cumsum(f / SR) % 1.0
    x = np.round((1.0 - 4.0 * np.abs(ph - 0.5)) * 7.5) / 7.5
    return x * _steps(np.exp(-t_axis(n) / 0.06)) * 0.6 * vel


def nes_snare(vel: float = 1.0) -> np.ndarray:
    n = int(0.14 * SR)
    return _lfsr_noise(n, 9000) * _steps(np.exp(-t_axis(n) / 0.045)) * 0.32 * vel


def nes_hat(vel: float = 1.0) -> np.ndarray:
    n = int(0.05 * SR)
    return _lfsr_noise(n, 22000) * _steps(np.exp(-t_axis(n) / 0.012)) * 0.16 * vel


def nes_drums(s: Song, bar: int, bars: int, kick: str, snare: str, hat: str, gain: float = 1.0) -> None:
    for b in range(bars):
        base = (bar + b) * s.bpb
        for pattern, fn in ((kick, nes_kick), (snare, nes_snare), (hat, nes_hat)):
            for k, ch in enumerate(pattern):
                if ch in "xX":
                    s.place(fn(1.0 if ch == "X" else 0.7), base + k * 0.25, gain)


def nes_arps(s: Song, bar: int, chords, octave: int = 4, duty: float = 0.125, gain: float = 0.8) -> None:
    for k, (root, q) in enumerate(chords):
        notes = chord(root, q, octave)
        for step in range(16):
            m = notes[step % 3] + (12 if step % 6 >= 3 else 0)
            s.note(nes_pulse, m, (bar + k) * s.bpb + step * 0.25, 0.22, 0.6, gain, 0.0, duty=duty, vib=False)


def nes_bass(s: Song, bar: int, chords, octave: int = 2, gain: float = 1.0) -> None:
    for k, (root, _q) in enumerate(chords):
        r = midi(root + str(octave))
        for step, off in enumerate([0, 12, 0, 12, 0, 12, 7, 12]):
            s.note(nes_tri, r + off, (bar + k) * s.bpb + step * 0.5, 0.45, 1.0, gain)


def _dry(s: Song) -> np.ndarray:
    return s.render(echo_mix=0.0, reverb_mix=0.0)


def stage4() -> np.ndarray:
    """PIXEL RIPTIDE — the Stage 1 theme on a Famicom. E minor, 150 bpm, 32 bars."""
    s = Song(150, 32, tail=0.5)
    a = [("E", "m"), ("C", "M"), ("D", "M"), ("B", "m")] * 2
    b = [("E", "m"), ("C", "M"), ("D", "M"), ("B", "m"), ("E", "m"), ("C", "M"), ("D", "M"), ("B", "M")]
    c = [("A", "m"), ("E", "m"), ("C", "M"), ("D", "M"), ("A", "m"), ("E", "m"), ("C", "M"), ("B", "M")]
    d = [("C", "M"), ("D", "M"), ("E", "m"), ("E", "m"), ("C", "M"), ("D", "M"), ("B", "M"), ("B", "M")]
    song = a + b + c + d
    nes_arps(s, 0, song, 4, 0.125, 0.55)
    nes_bass(s, 0, song)
    nes_drums(s, 0, 4, "X.......X.......", "........X.......", "x.x.x.x.x.x.x.x.")
    nes_drums(s, 4, 27, "X...x...X.x.x...", "....X.......X...", "x.x.x.x.x.x.x.x.")
    nes_drums(s, 31, 1, "X.x.X.x.X.X.X.X.", "..x.x.x.XxXxXXXX", "xxxxxxxxxxxxxxxx")
    intro = "E5 - - - B4 - E5 - G5 - - - F#5 - D5 - E5 - - - B4 - E5 - G5 - A5 - B5 - - -"
    s.line(nes_pulse, 4, intro, gain=1.0, duty=0.5, decay=0.6)
    s.line(nes_pulse, 6, intro, gain=1.0, duty=0.5, decay=0.6, transpose=-2)
    mel_b = ("E5 - - B4 E5 F#5 G5 - G5 - F#5 E5 D5 - E5 - F#5 - - D5 F#5 G5 A5 - B5 - - - A5 - F#5 - "
             "G5 - - E5 G5 A5 B5 - C6 - B5 A5 G5 - A5 - B5 - A5 G5 F#5 - D5 - D#5 - - - F#5 - B4 -")
    s.line(nes_pulse, 8, mel_b, gain=1.0, duty=0.25, decay=0.8)
    s.line(nes_pulse, 8, mel_b, gain=0.45, duty=0.125, decay=0.8, transpose=-12)
    mel_c = ("A5 - C6 - B5 A5 G5 - B5 - - G5 E5 - G5 - E6 - D6 C6 B5 - A5 - D6 - C6 B5 A5 - F#5 - "
             "A5 - - C6 B5 - A5 - G5 - B5 - E6 - - - E6 - D6 - C6 - B5 - B5 - - - D#6 - F#6 -")
    s.line(nes_pulse, 16, mel_c, gain=1.0, duty=0.5, decay=0.7)
    mel_d = ("G5 - A5 - B5 - - - A5 - B5 - C6 - - - B5 - - - E5 - G5 - B5 - A5 - G5 - F#5 - "
             "G5 - A5 - B5 - - - C6 - B5 - A5 - - - D#6 - - - B5 - - - F#5 - - - B4 - - -")
    s.line(nes_pulse, 24, mel_d, gain=1.0, duty=0.25, decay=0.8)
    s.line(nes_pulse, 24, mel_d, gain=0.5, duty=0.5, decay=0.8, transpose=-5)
    return _dry(s)


def boss8() -> np.ndarray:
    """CORE BREAKER — C minor, 168 bpm, 16 bars, relentless arps."""
    s = Song(168, 16, tail=0.5)
    prog = [("C", "m"), ("C", "m"), ("G#", "M"), ("G", "M"), ("C", "m"), ("A#", "M"), ("G#", "M"), ("G", "M")]
    nes_arps(s, 0, prog + prog, 4, 0.25, 0.5)
    for k, (root, _q) in enumerate(prog + prog):
        r = midi(root + "2")
        for step in range(16):
            s.note(nes_tri, r + (12 if step % 4 == 2 else 0), k * 4 + step * 0.25, 0.22, 1.0, 1.0)
    nes_drums(s, 0, 16, "X.x.X.x.X.x.X.x.", "....X.......X..X", "xxxxxxxxxxxxxxxx")
    lead = ("C6 - - - G5 - C6 - D#6 - - - D6 - C6 - G#5 - - - G5 - G#5 - B5 - - - G5 - - - "
            "C6 - - - G5 - C6 - D#6 - F6 - G6 - F6 - D#6 - - - D6 - C6 - D6 - - - B5 - - -")
    s.line(nes_pulse, 8, lead, gain=1.0, duty=0.5, decay=0.5)
    s.line(nes_pulse, 8, lead, gain=0.45, duty=0.125, decay=0.5, transpose=-12)
    return _dry(s)


def clear8() -> np.ndarray:
    """Stage-clear jingle, the classic rising fanfare shape."""
    s = Song(150, 3, tail=1.0)
    s.line(nes_pulse, 0, "E5 G5 B5 E6 - - D6 - E6 - - - - - - -", step=0.25, gain=1.0, duty=0.5)
    s.line(nes_pulse, 0, "B4 E5 G5 B5 - - A5 - B5 - - - - - - -", step=0.25, gain=0.6, duty=0.25)
    s.line(nes_pulse, 1, "C6 - D6 - E6 - - - F#6 - G6 - - - - -", step=0.25, gain=1.0, duty=0.5)
    s.line(nes_tri, 0, "E3 - - - - - - - C3 - - - D3 - - - E3 - - - - - - - - - - - - - - -", step=0.25)
    return s.render(echo_mix=0.0, reverb_mix=0.0, loop=False)


# --- Sound effects ------------------------------------------------------------------------

def _sweep_pulse(f0: float, f1: float, dur: float, duty: float, decay: float, vol: float = 0.5) -> np.ndarray:
    n = int(dur * SR)
    f = f0 * (f1 / f0) ** (t_axis(n) / dur)
    ph = np.cumsum(f / SR) % 1.0
    return np.where(ph < duty, 1.0, -1.0) * _steps(np.exp(-t_axis(n) / decay)) * vol


def retro_shot() -> np.ndarray:
    return _sweep_pulse(1800, 500, 0.08, 0.25, 0.04, 0.35)


def retro_boom() -> np.ndarray:
    n = int(0.55 * SR)
    rate = 5000 * np.exp(-t_axis(n) / 0.25) + 400
    x = np.zeros(n)
    pos = 0
    while pos < n:
        hold = max(1, int(SR / rate[pos]))
        x[pos:pos + hold] = 1.0 if RNG.random() < 0.5 else -1.0
        pos += hold
    return x * _steps(np.exp(-t_axis(n) / 0.18)) * 0.5


def retro_hit() -> np.ndarray:
    n = int(0.06 * SR)
    return _lfsr_noise(n, 14000) * _steps(np.exp(-t_axis(n) / 0.02)) * 0.4


def retro_power() -> np.ndarray:
    out = []
    for k, m in enumerate(["C5", "E5", "G5", "C6", "E6", "G6", "C7"]):
        out.append(nes_pulse(midi(m), 0.045, 0.9, 0.5, vib=False))
    return np.concatenate(out) * 1.4


def retro_1up() -> np.ndarray:
    out = []
    for m in ["E6", "G6", "E7", "C7", "D7", "G7"]:
        out.append(nes_pulse(midi(m), 0.07, 0.9, 0.25, vib=False))
    return np.concatenate(out) * 1.4


NES_TRACKS = {"stage4": stage4, "boss8": boss8, "clear8": clear8}
NES_SFX = {"retro_shot": retro_shot, "retro_boom": retro_boom, "retro_hit": retro_hit,
           "retro_power": retro_power, "retro_1up": retro_1up}
