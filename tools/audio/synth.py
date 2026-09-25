"""SHIFT//WING offline synthesizer.

Renders every music track and sound effect in the game from code, so all audio is original
and license-clean. SNES-era palette (32 kHz, echo, driven guitars, slap bass, brass, bells,
punchy drums) in the spirit of 16-bit mecha action soundtracks.

Usage:  python3 tools/audio/synth.py            (writes assets/audio/music + assets/audio/sfx)
Needs:  numpy, scipy
"""
from __future__ import annotations

import math
import os
import wave

import numpy as np
from scipy.signal import lfilter

SR = 32000
RNG = np.random.default_rng(1987)
NOTE_INDEX = {"C": 0, "C#": 1, "DB": 1, "D": 2, "D#": 3, "EB": 3, "E": 4, "F": 5, "F#": 6, "GB": 6,
              "G": 7, "G#": 8, "AB": 8, "A": 9, "A#": 10, "BB": 10, "B": 11}


# --- Basics ------------------------------------------------------------------------------

def midi(name: str) -> int:
    name = name.upper()
    octave = int(name[-1])
    return 12 * (octave + 1) + NOTE_INDEX[name[:-1]]


def freq(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def t_axis(n: int) -> np.ndarray:
    return np.arange(n) / SR


def adsr(n: int, a: float, d: float, s: float, r: float, hold: int) -> np.ndarray:
    """Envelope over n samples; the note is held for `hold` samples, then releases."""
    env = np.zeros(n)
    ai, di, ri = max(1, int(a * SR)), max(1, int(d * SR)), max(1, int(r * SR))
    hold = min(hold, n)
    seg = np.arange(hold)
    env[:hold] = np.where(seg < ai, seg / ai, np.where(seg < ai + di, 1.0 - (1.0 - s) * (seg - ai) / di, s))
    level = env[hold - 1] if hold > 0 else 0.0
    tail = np.arange(n - hold)
    env[hold:] = level * np.clip(1.0 - tail / ri, 0.0, 1.0) ** 2
    return env


def poly_blep(t: np.ndarray, dt: np.ndarray) -> np.ndarray:
    out = np.zeros_like(t)
    m = t < dt
    x = t[m] / dt[m]
    out[m] = x + x - x * x - 1.0
    m2 = t > 1.0 - dt
    x = (t[m2] - 1.0) / dt[m2]
    out[m2] = x * x + x + x + 1.0
    return out


def phase_of(f: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    dt = f / SR
    return np.cumsum(dt) % 1.0, dt


def saw(f: np.ndarray) -> np.ndarray:
    p, dt = phase_of(f)
    return 2.0 * p - 1.0 - poly_blep(p, dt)


def pulse(f: np.ndarray, duty: np.ndarray | float) -> np.ndarray:
    p, dt = phase_of(f)
    duty = np.broadcast_to(duty, p.shape)
    s = np.where(p < duty, 1.0, -1.0)
    s += poly_blep(p, dt)
    s -= poly_blep((p - duty) % 1.0, dt)
    return s


def tri(f: np.ndarray) -> np.ndarray:
    p, _ = phase_of(f)
    return 4.0 * np.abs(p - 0.5) - 1.0


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """Two cascaded one-pole low-passes (12 dB/oct)."""
    a = math.exp(-2.0 * math.pi * cutoff / SR)
    y = lfilter([1 - a], [1, -a], x)
    return lfilter([1 - a], [1, -a], y)


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


def sweep_filter(x: np.ndarray, env: np.ndarray, lo: float, hi: float) -> np.ndarray:
    """Cheap time-varying low-pass: crossfade a dark and a bright version by the envelope."""
    dark, bright = lowpass(x, lo), lowpass(x, hi)
    return dark + (bright - dark) * np.clip(env, 0.0, 1.0)


def vibrato(n: int, f0: float, depth_semi: float = 0.25, rate: float = 5.5, delay: float = 0.18) -> np.ndarray:
    t = t_axis(n)
    ramp = np.clip((t - delay) / 0.25, 0.0, 1.0)
    return f0 * 2.0 ** (depth_semi * ramp * np.sin(2 * np.pi * rate * t) / 12.0)


def noise(n: int) -> np.ndarray:
    return RNG.uniform(-1.0, 1.0, n)


# --- Instruments (return mono sample arrays) ----------------------------------------------

def inst_lead(m: float, dur: float, vel: float) -> np.ndarray:
    n = int((dur + 0.25) * SR)
    f = vibrato(n, freq(m), 0.22, 5.8, 0.15)
    duty = 0.25 + 0.12 * np.sin(2 * np.pi * 0.7 * t_axis(n))
    x = 0.7 * pulse(f, duty) + 0.3 * saw(f * 1.003)
    x = lowpass(x, 4200)
    return x * adsr(n, 0.006, 0.12, 0.72, 0.18, int(dur * SR)) * vel


def inst_guitar(m: float, dur: float, vel: float, power: bool = False) -> np.ndarray:
    """Driven guitar (MMX-style lead / power chords)."""
    n = int((dur + 0.2) * SR)
    f0 = freq(m)
    f = vibrato(n, f0, 0.35 if not power else 0.0, 6.2, 0.22)
    x = saw(f * 0.996) + saw(f * 1.004) + 0.5 * pulse(f * 0.5, 0.5)
    if power:
        x += saw(f * 1.4983) * 0.9 + saw(f * 2.0) * 0.5
    x = np.tanh(x * 3.2)
    x = lowpass(highpass(x, 180), 3000 if power else 3600)
    return x * adsr(n, 0.004, 0.09, 0.8, 0.09, int(dur * SR)) * vel * 0.55


def inst_bass(m: float, dur: float, vel: float) -> np.ndarray:
    """Slap/pick bass with a snappy filter envelope."""
    n = int((dur + 0.12) * SR)
    f = np.full(n, freq(m))
    x = 0.65 * saw(f) + 0.35 * pulse(f, 0.5)
    fenv = np.exp(-t_axis(n) / 0.07)
    x = sweep_filter(x, fenv, 380, 2600)
    return np.tanh(1.4 * x) * adsr(n, 0.003, 0.18, 0.55, 0.06, int(dur * SR)) * vel


def inst_brass(m: float, dur: float, vel: float) -> np.ndarray:
    n = int((dur + 0.3) * SR)
    f = vibrato(n, freq(m), 0.15, 5.0, 0.3)
    x = saw(f) + saw(f * 1.006) + saw(f * 0.994)
    env = adsr(n, 0.05, 0.25, 0.75, 0.25, int(dur * SR))
    x = sweep_filter(x, env * 0.9, 600, 3200)
    return x * env * vel * 0.4


def inst_pad(m: float, dur: float, vel: float) -> np.ndarray:
    n = int((dur + 0.9) * SR)
    f = np.full(n, freq(m))
    x = sum(saw(f * (1.0 + d)) for d in (-0.009, -0.003, 0.004, 0.011))
    x = lowpass(x, 1700)
    return x * adsr(n, 0.45, 0.4, 0.8, 0.85, int(dur * SR)) * vel * 0.18


def inst_strings(m: float, dur: float, vel: float) -> np.ndarray:
    n = int((dur + 0.7) * SR)
    f = vibrato(n, freq(m), 0.08, 4.6, 0.1)
    x = sum(saw(f * (1.0 + d)) for d in (-0.006, 0.0, 0.007))
    x = lowpass(x, 2400)
    return x * adsr(n, 0.2, 0.3, 0.85, 0.6, int(dur * SR)) * vel * 0.2


def inst_bell(m: float, dur: float, vel: float) -> np.ndarray:
    n = int((dur + 0.8) * SR)
    t = t_axis(n)
    fc = freq(m)
    mod_env = np.exp(-t / 0.25)
    x = np.sin(2 * np.pi * fc * t + 2.2 * mod_env * np.sin(2 * np.pi * fc * 3.5 * t))
    return x * np.exp(-t / 0.55) * vel * 0.55


def inst_arp(m: float, dur: float, vel: float) -> np.ndarray:
    n = int((dur + 0.15) * SR)
    f = np.full(n, freq(m))
    x = pulse(f, 0.125)
    x = lowpass(x, 5000)
    return x * adsr(n, 0.002, 0.08, 0.3, 0.08, int(dur * SR)) * vel * 0.5


def inst_choir(m: float, dur: float, vel: float) -> np.ndarray:
    n = int((dur + 0.8) * SR)
    f = vibrato(n, freq(m), 0.1, 5.0, 0.0)
    x = sum(pulse(f * (1.0 + d), 0.4) for d in (-0.005, 0.005))
    x = lowpass(x, 1200)
    return x * adsr(n, 0.35, 0.3, 0.8, 0.7, int(dur * SR)) * vel * 0.18


def drum_kick(vel: float = 1.0) -> np.ndarray:
    n = int(0.35 * SR)
    t = t_axis(n)
    f = 45 + 120 * np.exp(-t / 0.03)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.16)
    click = noise(n) * np.exp(-t / 0.004) * 0.4
    return np.tanh(2.0 * (x + click)) * vel


def drum_snare(vel: float = 1.0) -> np.ndarray:
    n = int(0.3 * SR)
    t = t_axis(n)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.05)
    nz = highpass(lowpass(noise(n), 7000), 900) * np.exp(-t / 0.11)
    return np.tanh(1.6 * (0.55 * tone + 1.1 * nz)) * vel * 0.85


def drum_hat(vel: float = 1.0, open_: bool = False) -> np.ndarray:
    n = int((0.35 if open_ else 0.06) * SR)
    t = t_axis(n)
    x = highpass(noise(n), 7000) * np.exp(-t / (0.12 if open_ else 0.018))
    return x * vel * 0.35


def drum_crash(vel: float = 1.0) -> np.ndarray:
    n = int(1.6 * SR)
    t = t_axis(n)
    x = highpass(noise(n), 4500) * np.exp(-t / 0.6)
    return x * vel * 0.4


def drum_tom(m: float, vel: float = 1.0, decay: float = 0.25) -> np.ndarray:
    n = int((decay * 2.5) * SR)
    t = t_axis(n)
    f0 = freq(m)
    f = f0 * (1.0 + 0.5 * np.exp(-t / 0.04))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / decay)
    x += lowpass(noise(n), 1500) * np.exp(-t / 0.03) * 0.3
    return np.tanh(1.5 * x) * vel


# --- Song building -------------------------------------------------------------------------

class Song:
    """Beat-based arrangement rendered into dry buses, then mixed with echo + reverb."""

    def __init__(self, bpm: float, bars: int, beats_per_bar: int = 4, tail: float = 3.0):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.bpb = beats_per_bar
        self.length = bars * beats_per_bar * self.beat
        self.n = int(self.length * SR)
        self.total = self.n + int(tail * SR)
        self.dry = np.zeros(self.total)
        self.send = np.zeros(self.total)  # echo/reverb send

    def at(self, beat: float) -> int:
        return int(round(beat * self.beat * SR))

    def place(self, sample: np.ndarray, beat: float, gain: float = 1.0, send: float = 0.0) -> None:
        i = self.at(beat)
        if i >= self.total:
            return
        j = min(self.total, i + len(sample))
        self.dry[i:j] += sample[: j - i] * gain
        if send > 0.0:
            self.send[i:j] += sample[: j - i] * gain * send

    def note(self, inst, m: float, beat: float, beats: float, vel: float = 1.0, gain: float = 1.0, send: float = 0.0, **kw):
        self.place(inst(m, beats * self.beat, vel, **kw) if kw else inst(m, beats * self.beat, vel), beat, gain, send)

    def line(self, inst, bar: int, text: str, step: float = 0.5, gain: float = 1.0, send: float = 0.0,
             transpose: int = 0, vel: float = 1.0, **kw) -> None:
        """Melody string: tokens per step ('.' rest, '-' hold previous)."""
        tokens = text.split()
        beat = bar * self.bpb
        i = 0
        while i < len(tokens):
            tok = tokens[i]
            if tok in (".", "-", "|"):
                i += 1
                continue
            length = 1
            while i + length < len(tokens) and tokens[i + length] == "-":
                length += 1
            self.note(inst, midi(tok) + transpose, beat + i * step, length * step * 0.98, vel, gain, send, **kw)
            i += length

    def drums(self, bar: int, bars: int, kick: str, snare: str, hat: str, gain: float = 1.0, step: float = 0.25,
              open_hat: str = "") -> None:
        for b in range(bars):
            base = (bar + b) * self.bpb
            for pattern, fn in ((kick, drum_kick), (snare, drum_snare), (hat, drum_hat)):
                p = pattern.replace(" ", "")
                for k, ch in enumerate(p):
                    if ch in "xX":
                        self.place(fn(1.0 if ch == "X" else 0.75), base + k * step, gain)
            for k, ch in enumerate(open_hat.replace(" ", "")):
                if ch == "o":
                    self.place(drum_hat(0.8, True), base + k * step, gain)

    def crash(self, bar: int, gain: float = 1.0) -> None:
        self.place(drum_crash(), bar * self.bpb, gain, 0.2)

    def render(self, echo_delay: float = 0.19, echo_fb: float = 0.38, echo_mix: float = 0.32,
               reverb_mix: float = 0.22, loop: bool = True) -> np.ndarray:
        wet = echo(self.send, echo_delay, echo_fb) * echo_mix + reverb(self.send + self.dry * 0.35) * reverb_mix
        mix = self.dry + wet
        if loop:
            # Fold the tail onto the start so echoes and releases wrap seamlessly.
            out = mix[: self.n].copy()
            tail = mix[self.n:]
            k = min(len(tail), self.n)
            out[:k] += tail[:k]
        else:
            out = mix
        return master(out)


def echo(x: np.ndarray, delay: float, fb: float) -> np.ndarray:
    d = int(delay * SR)
    a = np.zeros(d + 1)
    a[0] = 1.0
    a[d] = -fb
    y = lfilter([0.0] * d + [1.0], a, x)
    return lowpass(y, 3200)


def reverb(x: np.ndarray) -> np.ndarray:
    out = np.zeros_like(x)
    for delay, g in ((0.0297, 0.77), (0.0371, 0.74), (0.0411, 0.72), (0.0437, 0.7)):
        d = int(delay * SR)
        a = np.zeros(d + 1)
        a[0], a[d] = 1.0, -g
        out += lfilter([1.0], a, x)
    for delay, g in ((0.005, 0.7), (0.0017, 0.7)):
        d = int(delay * SR)
        b = np.zeros(d + 1)
        b[0], b[d] = -g, 1.0
        a = np.zeros(d + 1)
        a[0], a[d] = 1.0, -g
        out = lfilter(b, a, out)
    return lowpass(out * 0.25, 5000)


def master(x: np.ndarray, target_rms: float = 0.17) -> np.ndarray:
    x = highpass(x, 30)
    rms = float(np.sqrt(np.mean(x ** 2))) or 1.0
    x = x * (target_rms / rms)
    x = np.tanh(x * 1.1) / math.tanh(1.1)
    peak = float(np.max(np.abs(x))) or 1.0
    return x * min(1.0, 0.95 / peak)


def write_wav(path: str, x: np.ndarray) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (np.clip(x, -1.0, 1.0) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"wrote {path}  {len(x) / SR:5.1f}s")


# --- Harmony helpers ----------------------------------------------------------------------

def chord(root: str, quality: str = "m", octave: int = 4) -> list[int]:
    r = midi(root + str(octave))
    shape = {"m": [0, 3, 7], "M": [0, 4, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10], "sus": [0, 5, 7],
             "dim": [0, 3, 6], "5": [0, 7, 12]}[quality]
    return [r + s for s in shape]


def pad_chords(song: Song, inst, start_bar: int, chords: list[tuple[str, str]], octave: int = 3,
               gain: float = 1.0, send: float = 0.3, bars_each: int = 1) -> None:
    for k, (root, q) in enumerate(chords):
        for m in chord(root, q, octave):
            song.note(inst, m, (start_bar + k * bars_each) * song.bpb, song.bpb * bars_each, 0.9, gain, send)


def arp_chords(song: Song, inst, start_bar: int, chords: list[tuple[str, str]], octave: int = 5,
               step: float = 0.25, gain: float = 1.0, send: float = 0.4, pattern: tuple = (0, 1, 2, 1)) -> None:
    for k, (root, q) in enumerate(chords):
        notes = chord(root, q, octave)
        steps = int(song.bpb / step)
        for s in range(steps):
            idx = pattern[s % len(pattern)]
            m = notes[idx % len(notes)] + 12 * (idx // len(notes))
            song.note(inst, m, (start_bar + k) * song.bpb + s * step, step * 0.9, 0.7 if s % 2 else 0.9, gain, send)


def bass_line(song: Song, start_bar: int, chords: list[tuple[str, str]], style: str = "8ths",
              octave: int = 2, gain: float = 1.0) -> None:
    for k, (root, _q) in enumerate(chords):
        r = midi(root + str(octave))
        base = (start_bar + k) * song.bpb
        if style == "8ths":
            seq = [0, 0, 12, 0, 0, 12, 0, 7]
            for s, off in enumerate(seq):
                song.note(inst_bass, r + off, base + s * 0.5, 0.45, 0.9 if s % 2 == 0 else 0.75, gain)
        elif style == "16ths":
            seq = [0, 0, 12, 0, 0, 0, 12, 0, 0, 12, 0, 0, 10, 0, 7, 12]
            for s, off in enumerate(seq):
                song.note(inst_bass, r + off, base + s * 0.25, 0.22, 0.9 if s % 4 == 0 else 0.7, gain)
        elif style == "slap":
            hits = [(0, 0, 0.4), (0.75, 12, 0.2), (1.5, 0, 0.3), (2.0, 0, 0.2), (2.5, 12, 0.2), (3.0, 7, 0.3), (3.5, 10, 0.2)]
            for b, off, d in hits:
                song.note(inst_bass, r + off, base + b, d, 1.0 if off == 0 else 0.85, gain)
        elif style == "whole":
            song.note(inst_bass, r, base, song.bpb * 0.95, 0.8, gain)
        elif style == "pulse":
            for s in range(4):
                song.note(inst_bass, r, base + s, 0.8, 0.85, gain)
