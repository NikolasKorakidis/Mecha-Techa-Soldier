"""SHIFT//WING effects, studio pass: 48 kHz stereo, clean synthesis, real stereo space.

Design rules (vs the earlier passes):
  * No hard saturation: dynamics come from envelopes, layering and a soft limiter only on peaks.
  * Tamed top end: every layer is band-limited; harsh 2-5 kHz content is kept brief.
  * A generated stereo room/hall impulse (decorrelated noise, darkening tail) gives each effect
    a place to live instead of a dry beep.
  * Softer loudness targets (RMS of the audible part, dBFS): effects sit under the music and
    never fatigue; the mix balance is authored here, not with runtime trims.
  * Frequent effects render several variants (name.wav, name_2.wav ...) so repeats never
    sound like a machine gun of identical samples.
Render: python3 tools/audio/build.py (the build merges SFX_HQ over the older sets).
"""
import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt

SR = 48000
RNG = np.random.default_rng(2049)


# --- Core DSP -------------------------------------------------------------------------------

def t_axis(n: int) -> np.ndarray:
    return np.arange(n) / SR


def samples(seconds: float) -> int:
    return max(1, int(seconds * SR))


def env_exp(n: int, decay: float) -> np.ndarray:
    return np.exp(-t_axis(n) / max(decay, 1e-4))


def env_ad(n: int, attack: float, decay: float) -> np.ndarray:
    t = t_axis(n)
    return np.clip(t / max(attack, 1e-4), 0.0, 1.0) * np.exp(-np.maximum(t - attack, 0.0) / max(decay, 1e-4))


def _sos(kind: str, freq, order: int = 2):
    nyq = SR * 0.5
    if isinstance(freq, (list, tuple)):
        wn = [min(max(f / nyq, 1e-4), 0.999) for f in freq]
    else:
        wn = min(max(freq / nyq, 1e-4), 0.999)
    return butter(order, wn, btype=kind, output="sos")


def lowpass(x: np.ndarray, freq: float, order: int = 2) -> np.ndarray:
    return sosfilt(_sos("lowpass", freq, order), x, axis=0)


def highpass(x: np.ndarray, freq: float, order: int = 2) -> np.ndarray:
    return sosfilt(_sos("highpass", freq, order), x, axis=0)


def bandpass(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    return sosfilt(_sos("bandpass", [lo, hi], order), x, axis=0)


def swept_lowpass(x: np.ndarray, cutoff: np.ndarray) -> np.ndarray:
    """Time-varying one-pole low-pass (cutoff array in Hz), run twice for 12 dB/oct."""
    y = np.empty_like(x)
    for _ in range(2):
        a = np.exp(-2.0 * np.pi * np.clip(cutoff, 20.0, SR * 0.45) / SR)
        state = 0.0
        src = x if _ == 0 else y.copy()
        for i in range(len(src)):
            state = (1.0 - a[i]) * src[i] + a[i] * state
            y[i] = state
    return y


def noise(n: int) -> np.ndarray:
    return RNG.uniform(-1.0, 1.0, n)


def pink(n: int) -> np.ndarray:
    white = RNG.standard_normal(n)
    spectrum = np.fft.rfft(white)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    spectrum[1:] /= np.sqrt(f[1:])
    spectrum[0] = 0.0
    x = np.fft.irfft(spectrum, n)
    return x / (np.max(np.abs(x)) or 1.0)


def phase(freq: np.ndarray | float, n: int) -> np.ndarray:
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    return 2.0 * np.pi * np.cumsum(f) / SR


def sine(freq, n: int) -> np.ndarray:
    return np.sin(phase(freq, n))


def saw(freq, n: int, harmonics: int = 24) -> np.ndarray:
    """Band-limited saw (additive; partials above 18 kHz dropped per sample)."""
    ph = phase(freq, n)
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    out = np.zeros(n)
    for k in range(1, harmonics + 1):
        mask = (f * k) < 18000.0
        out += mask * np.sin(ph * k) / k
    return out * (2.0 / np.pi)


def fm(carrier, ratio: float, index, n: int) -> np.ndarray:
    """Two-operator FM: metallic pings, bells, sparkle."""
    mod = sine(np.asarray(carrier) * ratio, n) * np.broadcast_to(np.asarray(index, dtype=float), (n,))
    return np.sin(phase(carrier, n) + mod)


def crackle(n: int, density: float, decay: float, lo: float = 1500.0, hi: float = 7000.0) -> np.ndarray:
    """Sparse random impulses through a band-pass: debris, sizzle, electric fizz."""
    x = np.zeros(n)
    hits = RNG.random(n) < density / SR
    x[hits] = RNG.uniform(-1.0, 1.0, hits.sum())
    x = bandpass(x, lo, hi)
    return x * env_exp(n, decay)


def mix(*layers: tuple[np.ndarray, float]) -> np.ndarray:
    """Sum (signal, start seconds) layers; mono or stereo signals."""
    stereo = any(layer.ndim == 2 for layer, _ in layers)
    n = max(len(layer) + int(at * SR) for layer, at in layers)
    out = np.zeros((n, 2)) if stereo else np.zeros(n)
    for layer, at in layers:
        i = int(at * SR)
        if stereo and layer.ndim == 1:
            layer = np.stack([layer, layer], axis=1)
        out[i:i + len(layer)] += layer
    return out


def pad(x: np.ndarray, seconds: float) -> np.ndarray:
    extra = samples(seconds)
    shape = (extra,) + x.shape[1:]
    return np.concatenate([x, np.zeros(shape)])


# --- Space ----------------------------------------------------------------------------------

_IR_CACHE: dict = {}


def room_ir(size: float, decay: float, brightness: float = 6000.0) -> np.ndarray:
    """Stereo impulse: a few early reflections, then decorrelated noise that darkens as it decays."""
    key = (round(size, 3), round(decay, 3), round(brightness))
    if key in _IR_CACHE:
        return _IR_CACHE[key]
    n = samples(decay * 3.2)
    t = t_axis(n)
    ir = np.zeros((n, 2))
    for ch in range(2):
        tail = RNG.standard_normal(n) * np.exp(-t / decay)
        # Darkening: blend a bright and a dark version as the tail ages.
        dark = lowpass(tail, brightness * 0.25)
        bright = lowpass(tail, brightness)
        w = np.clip(t / (decay * 1.5), 0.0, 1.0)
        ir[:, ch] = bright * (1 - w) + dark * w
        # Early reflections (different per ear).
        for k in range(6):
            d = int((0.004 + RNG.uniform(0.002, 0.02) * size) * SR)
            if d < n:
                ir[d, ch] += RNG.uniform(0.3, 0.7) * (0.8 ** k)
    ir /= np.sqrt(np.sum(ir ** 2, axis=0, keepdims=True))
    _IR_CACHE[key] = ir
    return ir


def to_stereo(x: np.ndarray, width: float = 0.0, pan: float = 0.0) -> np.ndarray:
    """Mono → stereo with optional width (short decorrelating delay on one side) and pan."""
    if x.ndim == 2:
        return x
    left = x.copy()
    right = x.copy()
    if width > 0.0:
        # A short (<= 2.5 ms) decorrelating delay blended with the direct sound: width without
        # comb-filter hollowness, and it still folds down to mono cleanly.
        d = max(1, int(width * 0.0025 * SR))
        delayed = np.concatenate([np.zeros(d), x])[: len(x)]
        right = x * (1.0 - 0.45 * width) + delayed * 0.45 * width
        left = x * (1.0 - 0.2 * width) + lowpass(delayed, 5000) * 0.2 * width
    gl = np.cos((pan + 1.0) * np.pi / 4.0) * np.sqrt(2.0)
    gr = np.sin((pan + 1.0) * np.pi / 4.0) * np.sqrt(2.0)
    return np.stack([left * gl, right * gr], axis=1)


def space(x: np.ndarray, wet: float, size: float = 0.5, decay: float = 0.35, brightness: float = 6000.0) -> np.ndarray:
    """Adds the stereo room; returns stereo with the tail appended."""
    dry = to_stereo(x)
    ir = room_ir(size, decay, brightness)
    dry = pad(dry, decay * 3.2)
    wet_sig = np.stack([fftconvolve(dry[:, c], ir[:, c])[: len(dry)] for c in range(2)], axis=1)
    return dry * (1.0 - wet * 0.5) + wet_sig * wet


def finish(x: np.ndarray, rms_db: float, fade_in: float = 0.0015, fade_out: float = 0.02) -> np.ndarray:
    """Stereo, DC-free, click-free edges, loudness-matched, gently limited, trimmed silence."""
    x = to_stereo(x)
    x = highpass(x, 28.0)
    n = len(x)
    fi = min(n, samples(fade_in))
    x[:fi] *= np.linspace(0.0, 1.0, fi)[:, None]
    # Trim the inaudible tail, then fade the end.
    level = np.max(np.abs(x), axis=1)
    peak = float(np.max(level)) or 1.0
    audible = np.nonzero(level > peak * 0.0015)[0]
    end = min(n, (audible[-1] + samples(0.01)) if len(audible) else n)
    x = x[:end]
    fo = min(len(x), samples(fade_out))
    x[len(x) - fo:] *= np.linspace(1.0, 0.0, fo)[:, None]
    mono = np.mean(x, axis=1)
    active = np.abs(mono) > 0.03 * (float(np.max(np.abs(mono))) or 1.0)
    rms = float(np.sqrt(np.mean(mono[active] ** 2))) if active.any() else 1.0
    x *= 10.0 ** (rms_db / 20.0) / (rms or 1.0)
    # Soft knee above -3 dBFS only; transients stay intact below it.
    knee = 0.7
    over = np.abs(x) > knee
    x[over] = np.sign(x[over]) * (knee + (1.0 - knee) * np.tanh((np.abs(x[over]) - knee) / (1.0 - knee)))
    peak = float(np.max(np.abs(x))) or 1.0
    return x * min(1.0, 0.89 / peak)


# --- Building blocks ------------------------------------------------------------------------

def thump(f0: float, f1: float, dur: float, decay: float) -> np.ndarray:
    n = samples(dur)
    t = t_axis(n)
    return sine(f1 + (f0 - f1) * np.exp(-t / 0.03), n) * env_ad(n, 0.002, decay)


def metal(f: float, dur: float, decay: float, brightness: float = 1.0) -> np.ndarray:
    """Struck metal: inharmonic modes with mode-dependent decay."""
    n = samples(dur)
    t = t_axis(n)
    out = np.zeros(n)
    for k, (ratio, amp) in enumerate([(1.0, 1.0), (2.32, 0.55), (4.25, 0.35 * brightness), (6.63, 0.2 * brightness), (9.38, 0.1 * brightness)]):
        if f * ratio < 16000:
            out += np.sin(2 * np.pi * f * ratio * t + RNG.uniform(0, 6.28)) * np.exp(-t / (decay / (1 + k * 0.7))) * amp
    return out * env_ad(n, 0.0008, 10.0)


def whoosh_noise(n: int, lo: float, hi: float, env: np.ndarray) -> np.ndarray:
    return swept_lowpass(pink(n), lo + (hi - lo) * env) * env


def click(dur: float = 0.004, cutoff: float = 6000.0) -> np.ndarray:
    n = samples(dur)
    return lowpass(noise(n), cutoff) * env_exp(n, dur * 0.3)


# --- Weapons --------------------------------------------------------------------------------

def shot_player(v: int = 0) -> np.ndarray:
    n = samples(0.11)
    t = t_axis(n)
    top = 1750 + v * 90
    body = fm(top * np.exp(-t / 0.026) + 520, 1.5, 1.2 * np.exp(-t / 0.02), n) * env_ad(n, 0.001, 0.035)
    sub = sine(240 * np.exp(-t / 0.03) + 110, n) * env_ad(n, 0.001, 0.04) * 0.55
    air = bandpass(noise(n), 3000, 9000) * env_exp(n, 0.008) * 0.25
    x = lowpass(body * 0.8 + sub + air, 9500)
    return finish(space(to_stereo(x, 0.4, (v - 1.5) * 0.08), 0.12, 0.3, 0.12), -22)


def laser(v: int = 0) -> np.ndarray:
    n = samples(0.15)
    t = t_axis(n)
    f = (1500 + v * 110) * np.exp(-t / 0.04) + 430
    zap = saw(f, n, 10) * env_ad(n, 0.001, 0.045)
    zap = swept_lowpass(zap, 5200 * np.exp(-t / 0.04) + 900)
    body = sine(f * 0.5, n) * env_ad(n, 0.001, 0.05) * 0.6
    x = zap * 0.55 + body
    return finish(space(to_stereo(lowpass(x, 7000), 0.4, (v - 1.5) * 0.1), 0.15, 0.35, 0.16), -23)


def shot_enemy(v: int = 0) -> np.ndarray:
    n = samples(0.2)
    t = t_axis(n)
    f = (820 - v * 40) * np.exp(-t / 0.07) + 210
    body = (sine(f, n) + 0.3 * sine(f * 2.01, n)) * env_ad(n, 0.002, 0.07)
    hiss = bandpass(noise(n), 1500, 5000) * env_exp(n, 0.02) * 0.18
    return finish(space(lowpass(body + hiss, 6000), 0.14, 0.35, 0.18), -24)


def shot_heavy() -> np.ndarray:
    n = samples(0.5)
    t = t_axis(n)
    boom = sine(170 * np.exp(-t / 0.08) + 55, n) * env_ad(n, 0.002, 0.18)
    plasma = saw(420 * np.exp(-t / 0.1) + 90, n, 16) * env_ad(n, 0.002, 0.12)
    plasma = swept_lowpass(plasma, 6000 * np.exp(-t / 0.08) + 400)
    crack = bandpass(noise(n), 2000, 8000) * env_exp(n, 0.012) * 0.5
    x = boom + plasma * 0.6 + crack
    return finish(space(to_stereo(x, 0.6), 0.25, 0.6, 0.45), -17)


def beam() -> np.ndarray:
    n = samples(1.6)
    t = t_axis(n)
    env = np.clip(t / 0.06, 0, 1) * np.clip((1.6 - t) / 0.35, 0, 1)
    chord = sum(saw(110 * r * (1 + d), n, 20) for r, d in [(1, 0), (1, 0.006), (1.5, -0.004), (2, 0.003)])
    chord = lowpass(chord, 3200) * (0.85 + 0.15 * np.sin(2 * np.pi * 24 * t))
    roar = bandpass(pink(n), 300, 4000) * 0.5
    x = (chord * 0.5 + roar) * env
    return finish(space(to_stereo(x, 0.8), 0.3, 0.8, 0.6), -15)


def charge() -> np.ndarray:
    n = samples(0.45)
    t = t_axis(n)
    rise = np.clip(t / 0.45, 0, 1)
    tone = fm(300 + 1500 * rise ** 1.6, 2.0, 1.5 * rise, n) * rise * 0.6
    shimmer = bandpass(noise(n), 4000, 11000) * rise * 0.15
    return finish(space(to_stereo(tone + shimmer, 0.6), 0.25, 0.4, 0.3), -22)


# --- Impacts and explosions ---------------------------------------------------------------

def hit(v: int = 0) -> np.ndarray:
    n = samples(0.12)
    tick = click(0.003, 7000) * 0.8
    knock = thump(360 + v * 30, 150, 0.1, 0.03) * 0.7
    ping = metal(1150 + v * 90, 0.12, 0.05, 0.6) * 0.3
    x = mix((tick, 0), (knock, 0), (ping, 0.001))
    return finish(space(x[:n], 0.1, 0.25, 0.1), -24)


def armor_ping() -> np.ndarray:
    x = mix((metal(1480, 0.5, 0.18, 0.8), 0), (click(0.003) * 0.5, 0))
    return finish(space(x, 0.25, 0.4, 0.35), -24)


def explosion(size: float = 1.0, v: int = 0) -> np.ndarray:
    dur = 0.7 + 1.1 * size
    n = samples(dur)
    t = t_axis(n)
    body_env = env_ad(n, 0.004, 0.16 * size + 0.08)
    body = swept_lowpass(pink(n), 2200 * np.exp(-t / (0.12 * size + 0.05)) + 180) * body_env
    sub = sine(62 * np.exp(-t / 0.3) + 32 - v * 2, n) * env_ad(n, 0.003, 0.22 * size + 0.08)
    crack = bandpass(noise(n), 1800, 8000) * env_exp(n, 0.015) * 0.6
    debris = crackle(n, 90 * size, 0.35 * size + 0.1, 900, 6000) * 0.6
    left = body + sub * 1.1 + crack
    right = swept_lowpass(pink(n), 2200 * np.exp(-t / (0.12 * size + 0.05)) + 180) * body_env + sub * 1.1 + crack
    x = np.stack([left + debris * 0.7, right + crackle(n, 90 * size, 0.35 * size + 0.1, 900, 6000) * 0.42], axis=1)
    target = -19 + min(size, 2.6) * 1.6
    return finish(space(x, 0.18 + 0.1 * size, 0.5 + 0.3 * size, 0.35 + 0.35 * size, 5000), target, fade_out=0.08)


def player_hurt() -> np.ndarray:
    n = samples(0.45)
    t = t_axis(n)
    impact = mix((thump(320, 90, 0.25, 0.07), 0), (click(0.004, 5000) * 0.6, 0))
    fizz = crackle(n, 900, 0.12, 2000, 8000) * 0.5
    alarm = (sine(np.where(t < 0.14, 740.0, 560.0), n) * 0.5 + sine(np.where(t < 0.14, 1480.0, 1120.0), n) * 0.15) * env_ad(n, 0.01, 0.2) * (t > 0.04)
    return finish(space(mix((impact, 0), (fizz, 0), (lowpass(alarm, 4000), 0)), 0.2, 0.4, 0.3), -19)


def player_death() -> np.ndarray:
    n = samples(1.4)
    t = t_axis(n)
    down = fm(900 * np.exp(-t / 0.4) + 60, 1.5, 1.0, n) * env_ad(n, 0.01, 0.5) * 0.35
    return finish(mix((explosion(2.0, 1), 0), (to_stereo(lowpass(down, 4000), 0.5), 0.02)), -15, fade_out=0.15)


def boss_break() -> np.ndarray:
    ring = to_stereo(mix((metal(210, 1.4, 0.5, 0.8) * 0.4, 0), (metal(318, 1.0, 0.35, 0.8) * 0.3, 0)), 0.7)
    return finish(mix((explosion(1.7, 2), 0), (space(ring, 0.3, 0.7, 0.6), 0.02)), -15, fade_out=0.15)


def boss_roar() -> np.ndarray:
    n = samples(2.0)
    t = t_axis(n)
    env = np.clip(t / 0.12, 0, 1) * np.clip((2.0 - t) / 0.6, 0, 1)
    f = 130 * np.exp(-t / 1.4) + 52
    growl = saw(f, n, 30) + saw(f * 1.012, n, 30) + 0.5 * saw(f * 0.5, n, 30)
    formant = swept_lowpass(growl, 2200 * np.exp(-t / 0.8) + 350) * env
    servo = sine(880 + 380 * np.sin(2 * np.pi * 1.3 * t), n) * 0.08 * env
    stomp = thump(95, 36, 0.8, 0.25)
    x = mix((to_stereo(formant * 0.6 + servo, 0.7), 0), (stomp, 0))
    return finish(space(x, 0.35, 0.9, 0.9, 4000), -15, fade_out=0.2)


# --- Movement ------------------------------------------------------------------------------

def jump(v: int = 0) -> np.ndarray:
    n = samples(0.26)
    t = t_axis(n)
    env = env_ad(n, 0.004, 0.08)
    puff = whoosh_noise(n, 500, 5500, np.exp(-t / 0.07)) * env
    servo = sine(420 + 700 * (t / t[-1]) ** 0.6 + v * 30, n) * env_ad(n, 0.003, 0.06) * 0.22
    kick = thump(150, 70, 0.1, 0.035) * 0.6
    return finish(space(mix((to_stereo(puff, 0.5), 0), (servo, 0), (kick, 0)), 0.14, 0.35, 0.2), -22)


def double_jump() -> np.ndarray:
    n = samples(0.32)
    t = t_axis(n)
    burst = whoosh_noise(n, 800, 8000, np.exp(-t / 0.1)) * env_ad(n, 0.003, 0.12)
    tone = fm(600 + 1300 * (t / t[-1]), 1.0, 0.6, n) * env_ad(n, 0.003, 0.08) * 0.18
    return finish(space(mix((to_stereo(burst, 0.6), 0), (tone, 0), (thump(200, 100, 0.08, 0.03) * 0.5, 0)), 0.18, 0.4, 0.25), -21)


def wall_jump() -> np.ndarray:
    kick = mix((metal(390, 0.25, 0.08, 0.7) * 0.4, 0), (thump(140, 62, 0.12, 0.04), 0))
    return finish(mix((space(kick, 0.15, 0.3, 0.15), 0), (double_jump() * 0.6, 0.015)), -20)


def dash() -> np.ndarray:
    n = samples(0.5)
    t = t_axis(n)
    env = np.clip(t / 0.02, 0, 1) * np.exp(-t / 0.2)
    jet = whoosh_noise(n, 400, 9000, env) * env
    thrust = lowpass(saw(85 + 50 * np.exp(-t / 0.12), n, 12), 900) * env_ad(n, 0.01, 0.16) * 0.5
    x = np.stack([jet + thrust, np.concatenate([np.zeros(samples(0.006)), jet])[:n] + thrust], axis=1)
    return finish(space(x, 0.15, 0.4, 0.2), -19)


def boost() -> np.ndarray:
    n = samples(0.7)
    t = t_axis(n)
    env = np.clip(t / 0.08, 0, 1) * np.exp(-t / 0.35)
    jet = whoosh_noise(n, 500, 8000, env) * env
    ignite = lowpass(saw(70 + 110 * np.exp(-t / 0.18), n, 12), 1200) * env_ad(n, 0.02, 0.25) * 0.6
    return finish(space(to_stereo(jet + ignite, 0.7), 0.2, 0.5, 0.3), -19)


def land(v: int = 0) -> np.ndarray:
    n = samples(0.2)
    thud = thump(125 + v * 8, 52, 0.2, 0.055)
    grit = lowpass(noise(n), 1800) * env_exp(n, 0.018) * 0.45
    clink = metal(230 + v * 25, 0.18, 0.05, 0.4) * 0.18
    return finish(space(mix((thud, 0), (grit, 0), (clink, 0.004)), 0.12, 0.35, 0.2), -22)


def heavy_land() -> np.ndarray:
    stomp = thump(105, 34, 0.7, 0.2)
    ring = metal(145, 0.8, 0.3, 0.6) * 0.3
    return finish(mix((space(mix((stomp, 0), (ring, 0.008)), 0.25, 0.7, 0.6), 0), (explosion(0.5, 3) * 0.35, 0)), -17)


def mech_step(v: int = 0) -> np.ndarray:
    n = samples(0.14)
    thud = thump(150 + v * 10, 68, 0.14, 0.03)
    clank = metal(250 + v * 22, 0.12, 0.035, 0.5) * 0.22
    servo = sine(620 + v * 40, n) * env_ad(n, 0.004, 0.02) * 0.05
    grit = lowpass(noise(n), 2400) * env_exp(n, 0.01) * 0.35
    return finish(space(mix((thud, 0), (clank, 0.003), (servo, 0), (grit, 0)), 0.1, 0.3, 0.15), -27)


def whoosh() -> np.ndarray:
    n = samples(1.0)
    t = t_axis(n)
    env = np.sin(np.pi * np.clip(t / 1.0, 0, 1)) ** 2
    air = whoosh_noise(n, 250, 6500, env) * env
    pan = np.clip(t / 1.0, 0, 1)
    x = np.stack([air * np.cos(pan * np.pi / 2) * 1.4, air * np.sin(pan * np.pi / 2) * 1.4], axis=1)
    return finish(space(x, 0.2, 0.6, 0.4), -20, fade_out=0.1)


def transform() -> np.ndarray:
    n = samples(1.5)
    t = t_axis(n)
    servo = fm(260 + 900 * (t / 1.5) ** 1.3, 1.0, 0.4, n) * np.clip(1.0 - (t - 0.95) / 0.1, 0, 1) * 0.25
    clanks = mix(*[(mix((metal(180 + k * 55, 0.3, 0.1, 0.7) * 0.5, 0), (thump(160, 70, 0.1, 0.03) * 0.5, 0)), 0.95 + k * 0.08) for k in range(4)])
    chime = mix(*[(fm(440.0 * 2 ** (m / 12), 3.5, 1.2 * env_exp(samples(0.8), 0.25), samples(0.8)) * env_exp(samples(0.8), 0.3) * 0.25, 1.02 + k * 0.05) for k, m in enumerate([0, 7, 12, 19])])
    x = mix((to_stereo(servo, 0.6), 0), (to_stereo(clanks, 0.4), 0), (to_stereo(chime, 0.8), 0))
    return finish(space(x, 0.3, 0.7, 0.6), -17)


def door() -> np.ndarray:
    n = samples(0.9)
    t = t_axis(n)
    hiss = bandpass(pink(n), 1500, 7000) * env_ad(n, 0.02, 0.15) * 0.35
    slide = lowpass(saw(np.full(n, 52.0), n, 16) + pink(n) * 0.3, 500) * np.clip(t / 0.05, 0, 1) * np.clip((0.55 - t) / 0.1, 0, 1)
    thunk = mix((thump(95, 40, 0.4, 0.12), 0), (metal(170, 0.5, 0.2, 0.5) * 0.3, 0))
    return finish(space(mix((hiss, 0), (slide * 0.7, 0), (thunk, 0.5)), 0.25, 0.7, 0.5), -18)


# --- Bike ----------------------------------------------------------------------------------

def bike_engine() -> np.ndarray:
    """Seamless 2 s loop. Every partial completes whole cycles in 2 s (frequencies in 0.5 Hz steps),
    the noise layer is circular, so the loop never clicks. Pitch is shifted at runtime by speed."""
    n = samples(2.0)
    t = t_axis(n)
    fire = 50.0
    ph = (t * fire) % 1.0
    pulses = np.exp(-ph / 0.22) * (1.0 + 0.25 * np.sin(2 * np.pi * 3.0 * t))
    growl = (np.sin(2 * np.pi * 100.0 * t) * 0.6 + np.sin(2 * np.pi * 150.0 * t) * 0.35 + np.sin(2 * np.pi * 200.0 * t) * 0.2
             + np.sin(2 * np.pi * 250.0 * t) * 0.1) * pulses
    sub = np.sin(2 * np.pi * 50.0 * t) * 0.45
    whine = np.sin(2 * np.pi * 1250.0 * t) * 0.035 + np.sin(2 * np.pi * 1875.0 * t) * 0.02
    # Circular noise: filter in the frequency domain so the loop wraps perfectly.
    spectrum = np.fft.rfft(RNG.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    spectrum *= ((f > 1800) & (f < 7000)) * 1.0
    hiss = np.fft.irfft(spectrum, n)
    hiss = hiss / (np.max(np.abs(hiss)) or 1.0) * 0.05
    left = growl + sub + whine + hiss
    right = np.roll(growl, samples(0.0015)) + sub + whine * 0.8 + np.roll(hiss, n // 3)
    x = np.stack([left, right], axis=1)
    # Loudness only (no fades or trimming: it must loop).
    mono = np.mean(x, axis=1)
    x *= 10 ** (-21 / 20) / (float(np.sqrt(np.mean(mono ** 2))) or 1.0)
    return x * min(1.0, 0.85 / (float(np.max(np.abs(x))) or 1.0))


def bike_crash() -> np.ndarray:
    n = samples(1.0)
    t = t_axis(n)
    smash = mix((thump(130, 45, 0.5, 0.12), 0), (bandpass(noise(n), 800, 6000) * env_exp(n, 0.06) * 0.7, 0))
    grind = bandpass(pink(n), 900, 5000) * (0.6 + 0.4 * np.sin(2 * np.pi * 31 * t)) * env_ad(n, 0.02, 0.3) * 0.45
    debris = mix(*[(metal(RNG.uniform(600, 1800), 0.2, 0.05, 0.6) * RNG.uniform(0.15, 0.35), RNG.uniform(0.06, 0.55)) for _ in range(8)])
    x = mix((to_stereo(smash, 0.3), 0), (to_stereo(grind, 0.6), 0.02), (to_stereo(debris, 0.8), 0))
    return finish(space(x, 0.2, 0.5, 0.35), -17)


def bike_land() -> np.ndarray:
    n = samples(0.3)
    t = t_axis(n)
    spring = sine(np.full(n, 92.0), n) * env_exp(n, 0.07) * (1 + 0.4 * np.sin(2 * np.pi * 17 * t)) * 0.35
    x = mix((thump(135, 48, 0.3, 0.08), 0), (spring, 0), (lowpass(noise(n), 1500) * env_exp(n, 0.025) * 0.4, 0))
    return finish(space(x, 0.12, 0.35, 0.2), -20)


# --- Pickups and UI ------------------------------------------------------------------------

def _bell(m: float, dur: float, index: float = 1.4) -> np.ndarray:
    n = samples(dur)
    f = 440.0 * 2 ** ((m - 69) / 12.0)
    return fm(f, 3.5, index * env_exp(n, dur * 0.3), n) * env_ad(n, 0.002, dur * 0.35)


def pickup() -> np.ndarray:
    x = mix(*[(_bell(m, 0.5, 0.9) * 0.4, k * 0.045) for k, m in enumerate([72, 76, 79, 84])])
    return finish(space(to_stereo(x, 0.6), 0.3, 0.5, 0.45), -22)


def weapon_get() -> np.ndarray:
    notes = mix(*[(_bell(m, 0.7, 1.0) * 0.35, k * 0.06) for k, m in enumerate([62, 66, 69, 74, 78, 81])])
    n = samples(0.9)
    t = t_axis(n)
    sweep = whoosh_noise(n, 1500, 9000, np.sin(np.pi * np.clip(t / 0.6, 0, 1)) ** 2) * 0.25
    return finish(space(mix((to_stereo(notes, 0.7), 0), (to_stereo(sweep, 0.8), 0)), 0.35, 0.7, 0.7), -19)


def checkpoint() -> np.ndarray:
    x = mix(*[(_bell(m, 1.0, 1.0) * 0.35, k * 0.09) for k, m in enumerate([69, 76, 81])])
    return finish(space(to_stereo(x, 0.6), 0.35, 0.7, 0.8), -21)


def ui_move() -> np.ndarray:
    n = samples(0.06)
    x = mix((sine(np.full(n, 1180.0), n) * env_ad(n, 0.001, 0.012) * 0.5, 0), (click(0.002, 5000) * 0.3, 0))
    return finish(space(x, 0.08, 0.2, 0.1), -28)


def ui_confirm() -> np.ndarray:
    x = mix((_bell(84, 0.3, 0.8) * 0.5, 0), (_bell(91, 0.35, 0.8) * 0.4, 0.05))
    return finish(space(to_stereo(x, 0.5), 0.2, 0.4, 0.3), -24)


def ui_back() -> np.ndarray:
    x = mix((_bell(86, 0.25, 0.6) * 0.5, 0), (_bell(79, 0.3, 0.6) * 0.4, 0.05))
    return finish(space(to_stereo(x, 0.5), 0.2, 0.4, 0.3), -25)


def warning() -> np.ndarray:
    n = samples(1.7)
    t = t_axis(n)
    f = np.where((t % 0.42) < 0.21, 820.0, 615.0)
    tone = (sine(f, n) * 0.6 + sine(f * 2.0, n) * 0.15 + sine(f * 0.5, n) * 0.25)
    gate = 0.55 + 0.45 * np.sin(2 * np.pi * 2.4 * t) ** 2
    x = lowpass(tone * gate, 4500) * np.clip(t / 0.03, 0, 1) * np.clip((1.7 - t) / 0.25, 0, 1)
    return finish(space(to_stereo(x, 0.6), 0.3, 0.8, 0.7), -18)


SFX_HQ = {
    "shot_heavy": shot_heavy, "beam": beam, "charge": charge,
    "armor_ping": armor_ping, "player_hurt": player_hurt, "player_death": player_death,
    "boss_break": boss_break, "boss_roar": boss_roar,
    "double_jump": double_jump, "wall_jump": wall_jump, "dash": dash, "boost": boost,
    "heavy_land": heavy_land, "whoosh": whoosh, "transform": transform, "door": door,
    "bike_engine": bike_engine, "bike_crash": bike_crash, "bike_land": bike_land,
    "pickup": pickup, "weapon_get": weapon_get, "checkpoint": checkpoint,
    "ui_move": ui_move, "ui_confirm": ui_confirm, "ui_back": ui_back, "warning": warning,
    "explosion_huge": lambda: explosion(2.6, 0),
}

## Frequent effects: id -> (builder(v), variant count). Variant 0 is id.wav, then id_2.wav ...
SFX_HQ_VARIANTS = {
    "shot_player": (shot_player, 4),
    "laser": (laser, 4),
    "shot_enemy": (shot_enemy, 3),
    "hit": (hit, 4),
    "mech_step": (mech_step, 4),
    "land": (land, 3),
    "jump": (jump, 2),
    "explosion_small": (lambda v: explosion(0.7, v), 3),
    "explosion_large": (lambda v: explosion(1.4, v), 3),
}


def write_stereo(path: str, x: np.ndarray) -> None:
    import os
    import wave
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (np.clip(x, -1.0, 1.0) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"wrote {path}  {len(x) / SR:5.2f}s")
