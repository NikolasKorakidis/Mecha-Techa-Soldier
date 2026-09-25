"""SHIFT//WING soundtrack — original compositions rendered with synth.py.

Serious mecha epic in a 16-bit (SNES) palette: minor keys, driving bass, driven guitars,
brass and bell arpeggios, SNES-style echo.
"""
from synth import *  # noqa: F401,F403

ROCK_K = "X...x...X.x.x..."
ROCK_S = "....X.......X..."
HATS8 = "x.x.x.x.x.x.x.x."
HATS16 = "xxxxxxxxxxxxxxxx"


def title() -> np.ndarray:
    """ECHOES OF KHARON — slow, heavy, noble. D minor, 80 bpm, 16 bars."""
    s = Song(80, 16, tail=4.0)
    prog = [("D", "m"), ("A#", "M"), ("F", "M"), ("C", "M"), ("D", "m"), ("A#", "M"), ("G", "m"), ("A", "M")]
    pad_chords(s, inst_strings, 0, prog + prog, octave=3, gain=1.0, send=0.35)
    pad_chords(s, inst_choir, 8, prog, octave=4, gain=0.9, send=0.4)
    arp_chords(s, inst_bell, 0, prog, octave=5, step=0.5, gain=0.35, send=0.6, pattern=(0, 1, 2, 3, 2, 1, 0, 2))
    for k, (root, _q) in enumerate(prog + prog):
        s.note(inst_bass, midi(root + "1") + 12, k * 4, 3.9, 0.7, 0.8)
    # Timpani on the downbeats of the second half, roll into bar 9.
    for bar in range(8, 16):
        s.place(drum_tom(midi("D2"), 0.9, 0.5), bar * 4, 0.9, 0.2)
    for k in range(8):
        s.place(drum_tom(midi("A1"), 0.4 + k * 0.07, 0.3), 7 * 4 + 2 + k * 0.25, 0.8)
    s.crash(8, 0.7)
    s.line(inst_brass, 8, "A4 - - - D5 - E5 - F5 - - - E5 - D5 - C5 - - - F5 - G5 - A5 - - - G5 - - -", gain=1.1, send=0.35)
    s.line(inst_brass, 12, "F5 - - - A5 - - - D6 - - - C6 - A#5 - A#5 - A5 - G5 - F5 - E5 - - - C#5 - - -", gain=1.1, send=0.35)
    s.line(inst_brass, 8, "A4 - - - D5 - E5 - F5 - - - E5 - D5 - C5 - - - F5 - G5 - A5 - - - G5 - - -", gain=0.5, send=0.3, transpose=-12)
    return s.render(echo_delay=0.28, echo_fb=0.42, reverb_mix=0.32)


def stage1() -> np.ndarray:
    """ORBITAL RIPTIDE — driving space battle. E minor, 138 bpm, 32 bars."""
    s = Song(138, 32)
    a = [("E", "m"), ("C", "M"), ("D", "M"), ("B", "m")] * 2
    b = [("E", "m"), ("C", "M"), ("D", "M"), ("B", "m"), ("E", "m"), ("C", "M"), ("D", "M"), ("B", "M")]
    c = [("A", "m"), ("E", "m"), ("C", "M"), ("D", "M"), ("A", "m"), ("E", "m"), ("C", "M"), ("B", "M")]
    d = [("C", "M"), ("D", "M"), ("E", "m"), ("E", "m"), ("C", "M"), ("D", "M"), ("B", "M"), ("B", "M")]
    song = a + b + c + d
    pad_chords(s, inst_pad, 0, song, octave=3, gain=1.0, send=0.35)
    arp_chords(s, inst_arp, 0, a, octave=5, gain=0.6, send=0.5, pattern=(0, 1, 2, 3, 2, 1, 2, 1))
    arp_chords(s, inst_bell, 24, d, octave=5, gain=0.35, send=0.6, pattern=(0, 2, 1, 3))
    bass_line(s, 0, song, "8ths", gain=0.9)
    # Drums: half-time intro, full groove after.
    s.drums(0, 4, "X.......X.......", "........X.......", HATS8, 0.9)
    s.drums(4, 20, ROCK_K, ROCK_S, HATS8, 1.0, open_hat="..............o.")
    s.drums(24, 7, "X.x.X.x.X.x.X.x.", "....X.......X..x", HATS16, 1.0)
    s.drums(31, 1, "X.x.X.x.X.X.X.X.", "..x.x.x.XxXxXXXX", HATS16, 1.0)
    for bar in (4, 8, 16, 24):
        s.crash(bar, 0.8)
    mel_b = ("E5 - - B4 E5 F#5 G5 - G5 - F#5 E5 D5 - E5 - F#5 - - D5 F#5 G5 A5 - B5 - - - A5 - F#5 - "
             "G5 - - E5 G5 A5 B5 - C6 - B5 A5 G5 - A5 - B5 - A5 G5 F#5 - D5 - D#5 - - - F#5 - B4 -")
    s.line(inst_lead, 8, mel_b, gain=0.8, send=0.45)
    mel_c = ("A5 - C6 - B5 A5 G5 - B5 - - G5 E5 - G5 - E6 - D6 C6 B5 - A5 - D6 - C6 B5 A5 - F#5 - "
             "A5 - - C6 B5 - A5 - G5 - B5 - E6 - - - E6 - D6 - C6 - B5 - B5 - - - D#6 - F#6 -")
    s.line(inst_guitar, 16, mel_c, gain=0.75, send=0.35)
    s.line(inst_lead, 16, mel_c, gain=0.3, send=0.4, transpose=-12)
    for k, (root, q) in enumerate(d):
        for m in chord(root, q, 4):
            s.note(inst_brass, m, (24 + k) * 4, 0.4, 1.0, 0.8, 0.2)
            s.note(inst_brass, m, (24 + k) * 4 + 1.5, 0.4, 0.9, 0.7, 0.2)
    return s.render()


def boss() -> np.ndarray:
    """GUARDIAN — relentless, dissonant. C minor, 162 bpm, 24 bars."""
    s = Song(162, 24)
    prog = [("C", "m"), ("C", "m"), ("G#", "M"), ("A#", "M"), ("C", "m"), ("C#", "M"), ("A#", "M"), ("G", "M")]
    song = prog * 3
    bass_line(s, 0, song, "16ths", gain=0.85)
    pad_chords(s, inst_strings, 0, song, octave=3, gain=0.9, send=0.3)
    s.drums(0, 23, "X.x.X..xX.x.X..x", "....X.......X.x.", HATS16, 1.0)
    s.drums(23, 1, "X.X.X.X.XXXXXXXX", "..x.x.x.xxxxXXXX", HATS16, 1.0)
    for bar in (0, 8, 16):
        s.crash(bar, 0.9)
    for k, (root, q) in enumerate(song):
        for m in chord(root, q, 4):
            for off in (0.5, 1.5, 2.5, 3.25):
                s.note(inst_brass, m, k * 4 + off, 0.22, 0.95, 0.55, 0.15)
    mel = ("G5 - - G#5 G5 - F5 - D#5 - D5 - C5 - - - G#5 - - G5 F5 - D#5 - D5 - D#5 - F5 - D5 - "
           "G5 - C6 - A#5 - G#5 - C#6 - C6 - G#5 - F5 - A#5 - G#5 - G5 - F5 - B5 - - - D6 - G5 -")
    s.line(inst_lead, 0, mel, gain=0.75, send=0.35)
    s.line(inst_guitar, 8, mel, gain=0.7, send=0.3)
    arp_chords(s, inst_arp, 8, prog, octave=5, step=0.25, gain=0.45, send=0.4, pattern=(0, 1, 2, 3))
    s.line(inst_guitar, 16, mel, gain=0.7, send=0.3, transpose=12)
    s.line(inst_lead, 16, mel, gain=0.4, send=0.35)
    return s.render(echo_delay=0.14, echo_fb=0.3)


def stage2() -> np.ndarray:
    """WARSHIP INFILTRATION — 16-bit mecha rock. A minor, 150 bpm, 32 bars."""
    s = Song(150, 32)
    a = [("A", "m"), ("F", "M"), ("G", "M"), ("E", "m"), ("A", "m"), ("F", "M"), ("G", "M"), ("E", "M")]
    b = [("D", "m"), ("A", "m"), ("F", "M"), ("G", "M"), ("D", "m"), ("A", "m"), ("E", "M"), ("E", "M")]
    song = a + a + b + a
    bass_line(s, 0, song, "slap", gain=0.95)
    # Palm-muted power-chord riff.
    riff = [0, 0.5, 1.0, 1.25, 1.75, 2.25, 2.5, 3.0, 3.5]
    for k, (root, _q) in enumerate(song):
        r = midi(root + "3")
        for off in riff:
            s.note(inst_guitar, r, k * 4 + off, 0.2, 0.9, 0.45, 0.05, power=True)
    s.drums(0, 31, ROCK_K.replace("X.x.x...", "X.x.x..x"), "....X.......X...", HATS8, 1.0, open_hat="......o.......o.")
    s.drums(31, 1, "X.X.X.X.X.X.X.X.", "....x.x.xxXxXXXX", HATS16, 1.0)
    for bar in (0, 8, 16, 24):
        s.crash(bar, 0.85)
    mel_a = ("A4 - C5 - E5 - D5 C5 C5 - - A4 C5 D5 E5 - D5 - B4 - G4 - B4 D5 E5 - - - G5 - E5 - "
             "A5 - G5 - E5 - C5 D5 E5 - F5 - E5 - C5 - D5 - E5 - G5 - B5 - G#5 - - - E5 - B4 -")
    s.line(inst_guitar, 0, mel_a, gain=0.8, send=0.35)
    s.line(inst_guitar, 8, mel_a, gain=0.75, send=0.35, transpose=12)
    s.line(inst_lead, 8, mel_a, gain=0.35, send=0.4)
    mel_b = ("F5 - - E5 D5 - A4 - C5 - - B4 A4 - E5 - F5 - E5 - C5 - A4 - B4 - D5 - G5 - F5 - "
             "A5 - - G5 F5 - D5 - E5 - - D5 C5 - A4 - B4 - - C5 D5 - E5 - G#5 - - - B5 - - -")
    s.line(inst_lead, 16, mel_b, gain=0.8, send=0.45)
    pad_chords(s, inst_strings, 16, b, octave=3, gain=0.8, send=0.3)
    arp_chords(s, inst_arp, 24, a, octave=5, gain=0.5, send=0.5, pattern=(0, 1, 2, 1, 0, 2, 1, 2))
    s.line(inst_guitar, 24, mel_a, gain=0.6, send=0.35)
    return s.render(echo_delay=0.17, echo_fb=0.35)


def stage3() -> np.ndarray:
    """HULL RUN — full throttle escape. B minor, 178 bpm, 32 bars."""
    s = Song(178, 32)
    a = [("B", "m"), ("G", "M"), ("D", "M"), ("A", "M"), ("E", "m"), ("G", "M"), ("F#", "M"), ("F#", "M")]
    song = a * 4
    bass_line(s, 0, song, "8ths", gain=0.9)
    arp_chords(s, inst_arp, 0, song, octave=5, step=0.25, gain=0.45, send=0.45, pattern=(0, 1, 2, 3, 2, 1, 2, 3))
    s.drums(0, 31, "X..xX.x..xX.x..x", "....X..x....X...", HATS16, 1.0)
    s.drums(31, 1, "X.X.X.X.XXXXXXXX", "xxxxXXXXxxxxXXXX", HATS16, 1.0)
    for bar in (0, 8, 16, 24):
        s.crash(bar, 0.9)
    mel = ("F#5 - - B5 A5 - F#5 - G5 - - F#5 E5 - D5 - F#5 - A5 - D6 - C#6 - C#6 - - - A5 - - - "
           "B5 - - A5 G5 - E5 - D5 - E5 - G5 - B5 - A#5 - - - C#6 - - - F#6 - - - E6 - C#6 -")
    s.line(inst_lead, 8, mel, gain=0.8, send=0.4)
    s.line(inst_guitar, 16, mel, gain=0.75, send=0.3)
    s.line(inst_guitar, 24, mel, gain=0.7, send=0.3, transpose=12)
    s.line(inst_lead, 24, mel, gain=0.4, send=0.4)
    pad_chords(s, inst_pad, 8, a * 3, octave=3, gain=0.9, send=0.3)
    for k, (root, q) in enumerate(song[16:], start=16):
        for m in chord(root, q, 4):
            s.note(inst_brass, m, k * 4 + 2.5, 0.3, 0.9, 0.5, 0.15)
    return s.render(echo_delay=0.12, echo_fb=0.28)


def stage_clear() -> np.ndarray:
    """Short victory fanfare (not looped). D major."""
    s = Song(132, 4, tail=2.5)
    s.line(inst_brass, 0, "D5 A4 D5 F#5 A5 - - - G5 - F#5 - E5 - F#5 - A5 - - - B5 - C#6 - D6 - - - - - - -", step=0.5, gain=1.2, send=0.4)
    s.line(inst_lead, 0, "D5 A4 D5 F#5 A5 - - - G5 - F#5 - E5 - F#5 - A5 - - - B5 - C#6 - D6 - - - - - - -", step=0.5, gain=0.4, send=0.5, transpose=12)
    pad_chords(s, inst_strings, 0, [("D", "M"), ("G", "M"), ("A", "M"), ("D", "M")], octave=3, gain=1.0, send=0.3)
    s.drums(0, 3, "X.......X.......", "....X.......X...", "x.x.x.x.x.x.x.x.", 0.9)
    s.crash(3, 1.0)
    s.place(drum_tom(midi("D2"), 1.0, 0.6), 12, 1.0, 0.3)
    return s.render(loop=False, reverb_mix=0.3)


def mission_complete() -> np.ndarray:
    """Ending theme — the title theme in D major, triumphant. 16 bars, loops."""
    s = Song(88, 16, tail=4.0)
    prog = [("D", "M"), ("A#", "M"), ("F", "M"), ("C", "M"), ("D", "M"), ("G", "M"), ("A", "sus"), ("A", "M")]
    pad_chords(s, inst_strings, 0, prog + prog, octave=3, gain=1.0, send=0.35)
    arp_chords(s, inst_bell, 0, prog + prog, octave=5, step=0.5, gain=0.35, send=0.6, pattern=(0, 1, 2, 3, 2, 1, 0, 2))
    for k, (root, _q) in enumerate(prog + prog):
        s.note(inst_bass, midi(root + "2"), k * 4, 3.9, 0.7, 0.8)
    s.drums(0, 16, "X.......X.x.....", "....X.......X...", HATS8, 0.8)
    s.crash(0, 0.8)
    s.crash(8, 0.8)
    s.line(inst_brass, 0, "A4 - - - D5 - E5 - F#5 - - - E5 - D5 - C5 - - - F5 - G5 - A5 - - - G5 - - -", gain=1.1, send=0.35)
    s.line(inst_brass, 4, "F#5 - - - A5 - - - D6 - - - C#6 - B5 - B5 - A5 - G5 - F#5 - E5 - - - E5 - - -", gain=1.1, send=0.35)
    s.line(inst_guitar, 8, "A4 - - - D5 - E5 - F#5 - - - E5 - D5 - C5 - - - F5 - G5 - A5 - - - G5 - - -", gain=0.7, send=0.35, transpose=12)
    s.line(inst_guitar, 12, "F#5 - - - A5 - - - D6 - - - C#6 - B5 - B5 - A5 - G5 - F#5 - E5 - - - C#6 - - -", gain=0.7, send=0.35)
    return s.render(echo_delay=0.25, echo_fb=0.4, reverb_mix=0.3)


TRACKS = {
    "title": title,
    "stage1": stage1,
    "boss": boss,
    "stage2": stage2,
    "stage3": stage3,
    "stage_clear": stage_clear,
    "mission_complete": mission_complete,
}
