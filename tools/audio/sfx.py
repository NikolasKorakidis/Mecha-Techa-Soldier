"""SHIFT//WING sound effects, synthesized (see synth.py)."""
from synth import *  # noqa: F401,F403


def _env(n: int, decay: float) -> np.ndarray:
    return np.exp(-t_axis(n) / decay)


def _norm(x: np.ndarray, peak: float = 0.9) -> np.ndarray:
    return x * (peak / (float(np.max(np.abs(x))) or 1.0))


def shot_player() -> np.ndarray:
    n = int(0.09 * SR)
    f = 1800 * np.exp(-t_axis(n) / 0.03) + 500
    return _norm(lowpass(pulse(f, 0.3), 6000) * _env(n, 0.035), 0.6)


def shot_enemy() -> np.ndarray:
    n = int(0.16 * SR)
    f = 700 * np.exp(-t_axis(n) / 0.06) + 260
    return _norm(tri(f) * 0.8 + 0.2 * pulse(f, 0.5) * _env(n, 0.05), 0.5) * _env(n, 0.07)


def shot_heavy() -> np.ndarray:
    n = int(0.3 * SR)
    f = 220 * np.exp(-t_axis(n) / 0.1) + 80
    x = np.tanh(3 * pulse(f, 0.5)) * _env(n, 0.12) + lowpass(noise(n), 1500) * _env(n, 0.05) * 0.5
    return _norm(lowpass(x, 3000), 0.7)


def laser() -> np.ndarray:
    n = int(0.12 * SR)
    f = 2400 * np.exp(-t_axis(n) / 0.05) + 900
    return _norm(saw(f) * _env(n, 0.05) + pulse(f * 0.5, 0.2) * _env(n, 0.03) * 0.5, 0.55)


def explosion(size: float = 1.0) -> np.ndarray:
    dur = 0.6 + 0.9 * size
    n = int(dur * SR)
    t = t_axis(n)
    nz = noise(n)
    body = lowpass(nz, 900 + 800 / size) * _env(n, 0.18 * size + 0.1)
    crack = highpass(nz, 2000) * _env(n, 0.03)
    boom = np.sin(2 * np.pi * np.cumsum(60 + 90 * np.exp(-t / 0.08)) / SR) * _env(n, 0.25 * size)
    x = np.tanh(2.5 * (body * 1.4 + crack * 0.6 + boom * 0.9))
    return _norm(x, 0.85 if size < 1.5 else 0.95)


def hit() -> np.ndarray:
    n = int(0.07 * SR)
    x = highpass(noise(n), 1500) * _env(n, 0.015) + pulse(np.full(n, 900.0), 0.5) * _env(n, 0.02) * 0.4
    return _norm(x, 0.45)


def armor_ping() -> np.ndarray:
    n = int(0.25 * SR)
    t = t_axis(n)
    x = np.sin(2 * np.pi * 1760 * t) * _env(n, 0.08) + np.sin(2 * np.pi * 2637 * t) * _env(n, 0.05) * 0.5
    return _norm(x, 0.4)


def player_hurt() -> np.ndarray:
    n = int(0.35 * SR)
    f = 600 * np.exp(-t_axis(n) / 0.15) + 120
    x = np.tanh(2 * pulse(f, 0.5)) * _env(n, 0.14) + lowpass(noise(n), 3000) * _env(n, 0.05) * 0.6
    return _norm(x, 0.75)


def player_death() -> np.ndarray:
    a = explosion(1.8)
    n = int(1.2 * SR)
    f = 900 * np.exp(-t_axis(n) / 0.4) + 60
    fall = pulse(f, 0.5) * _env(n, 0.4) * 0.4
    out = np.zeros(max(len(a), n))
    out[: len(a)] += a
    out[:n] += fall
    return _norm(out, 0.95)


def jump() -> np.ndarray:
    n = int(0.14 * SR)
    f = 300 + 700 * (t_axis(n) / (n / SR))
    return _norm(lowpass(pulse(f, 0.5), 3500) * _env(n, 0.07), 0.45)


def double_jump() -> np.ndarray:
    n = int(0.2 * SR)
    f = 500 + 1100 * (t_axis(n) / (n / SR))
    x = lowpass(pulse(f, 0.25), 5000) * _env(n, 0.09) + highpass(noise(n), 4000) * _env(n, 0.05) * 0.3
    return _norm(x, 0.45)


def dash() -> np.ndarray:
    n = int(0.25 * SR)
    t = t_axis(n)
    x = sweep_filter(noise(n), 1.0 - t / t[-1], 600, 6000) * _env(n, 0.12)
    x += saw(np.full(n, 110.0)) * _env(n, 0.06) * 0.3
    return _norm(x, 0.6)


def land() -> np.ndarray:
    n = int(0.18 * SR)
    t = t_axis(n)
    x = np.sin(2 * np.pi * np.cumsum(70 + 80 * np.exp(-t / 0.02)) / SR) * _env(n, 0.06)
    x += lowpass(noise(n), 1200) * _env(n, 0.03) * 0.6
    return _norm(x, 0.6)


def heavy_land() -> np.ndarray:
    a = land()
    b = explosion(0.6) * 0.5
    out = np.zeros(max(len(a), len(b)))
    out[: len(a)] += a
    out[: len(b)] += b
    return _norm(out, 0.9)


def pickup() -> np.ndarray:
    out = np.zeros(int(0.35 * SR))
    for k, m in enumerate([72, 76, 79, 84]):
        n = int(0.12 * SR)
        x = pulse(np.full(n, freq(m)), 0.25) * _env(n, 0.06)
        i = int(k * 0.05 * SR)
        out[i:i + n] += x
    return _norm(lowpass(out, 6000), 0.5)


def weapon_get() -> np.ndarray:
    out = np.zeros(int(0.7 * SR))
    for k, m in enumerate([67, 71, 74, 79, 83, 86]):
        n = int(0.25 * SR)
        x = inst_bell(m, 0.2, 1.0)[:n]
        i = int(k * 0.06 * SR)
        out[i:i + n] += x
    return _norm(out, 0.6)


def checkpoint() -> np.ndarray:
    out = np.zeros(int(0.8 * SR))
    for k, m in enumerate([69, 76, 81]):
        x = inst_bell(m, 0.4, 1.0)
        i = int(k * 0.1 * SR)
        j = min(len(out), i + len(x))
        out[i:j] += x[: j - i]
    return _norm(out, 0.55)


def ui_move() -> np.ndarray:
    n = int(0.05 * SR)
    return _norm(pulse(np.full(n, 1320.0), 0.5) * _env(n, 0.015), 0.3)


def ui_confirm() -> np.ndarray:
    out = np.zeros(int(0.2 * SR))
    for k, f0 in enumerate([880.0, 1320.0]):
        n = int(0.09 * SR)
        i = int(k * 0.06 * SR)
        out[i:i + n] += pulse(np.full(n, f0), 0.25) * _env(n, 0.04)
    return _norm(out, 0.4)


def ui_back() -> np.ndarray:
    out = np.zeros(int(0.2 * SR))
    for k, f0 in enumerate([990.0, 660.0]):
        n = int(0.09 * SR)
        i = int(k * 0.06 * SR)
        out[i:i + n] += pulse(np.full(n, f0), 0.25) * _env(n, 0.04)
    return _norm(out, 0.35)


def warning() -> np.ndarray:
    n = int(1.6 * SR)
    t = t_axis(n)
    f = np.where((t % 0.4) < 0.2, 880.0, 660.0)
    x = lowpass(pulse(f, 0.5), 3000) * (0.6 + 0.4 * np.sin(2 * np.pi * 2.5 * t) ** 2)
    x *= np.clip(1.0 - (t - 1.4) / 0.2, 0.0, 1.0)
    return _norm(x, 0.55)


def charge() -> np.ndarray:
    n = int(0.3 * SR)
    f = 200 + 1600 * (t_axis(n) / (n / SR)) ** 2
    x = saw(f) * (t_axis(n) / (n / SR)) + highpass(noise(n), 5000) * 0.2
    return _norm(lowpass(x, 5000), 0.5)


def beam() -> np.ndarray:
    n = int(1.5 * SR)
    t = t_axis(n)
    f = np.full(n, 110.0)
    x = saw(f) + saw(f * 1.01) + saw(f * 2.0) * 0.5 + pulse(f * 4.0, 0.3) * 0.3
    x = np.tanh(2 * x) * (0.8 + 0.2 * np.sin(2 * np.pi * 30 * t))
    x += highpass(noise(n), 3000) * 0.3
    x = lowpass(x, 4000) * np.clip(t / 0.05, 0, 1) * np.clip((1.5 - t) / 0.3, 0, 1)
    return _norm(x, 0.8)


def transform() -> np.ndarray:
    n = int(1.4 * SR)
    t = t_axis(n)
    rise = saw(200 + 1200 * (t / t[-1]) ** 1.5) * np.clip(1.0 - (t - 0.9) / 0.1, 0, 1) * 0.5
    clanks = np.zeros(n)
    for k in range(5):
        i = int((0.9 + k * 0.08) * SR)
        m = int(0.12 * SR)
        if i + m <= n:
            clanks[i:i + m] += land()[:m] * 0.8
    shimmer = np.zeros(n)
    bell = inst_bell(84, 0.4, 1.0)
    i = int(0.95 * SR)
    shimmer[i:min(n, i + len(bell))] += bell[: n - i] * 0.6
    return _norm(lowpass(rise, 5000) + clanks + shimmer, 0.8)


def boost() -> np.ndarray:
    n = int(0.6 * SR)
    t = t_axis(n)
    x = sweep_filter(noise(n), np.clip(t / 0.15, 0, 1) * np.exp(-t / 0.4), 500, 7000)
    x += saw(80 + 120 * np.exp(-t / 0.2)) * _env(n, 0.3) * 0.5
    return _norm(x, 0.7)


def door() -> np.ndarray:
    n = int(0.6 * SR)
    t = t_axis(n)
    x = lowpass(saw(np.full(n, 55.0)) + noise(n) * 0.2, 600) * np.clip(t / 0.05, 0, 1) * _env(n, 0.3)
    thud = land()
    x[: len(thud)] += thud[:n] * 0.8
    return _norm(x, 0.8)


SFX = {
    "shot_player": shot_player,
    "shot_enemy": shot_enemy,
    "shot_heavy": shot_heavy,
    "laser": laser,
    "explosion_small": lambda: explosion(0.7),
    "explosion_large": lambda: explosion(1.4),
    "explosion_huge": lambda: explosion(2.6),
    "hit": hit,
    "armor_ping": armor_ping,
    "player_hurt": player_hurt,
    "player_death": player_death,
    "jump": jump,
    "double_jump": double_jump,
    "dash": dash,
    "land": land,
    "heavy_land": heavy_land,
    "pickup": pickup,
    "weapon_get": weapon_get,
    "checkpoint": checkpoint,
    "ui_move": ui_move,
    "ui_confirm": ui_confirm,
    "ui_back": ui_back,
    "warning": warning,
    "charge": charge,
    "beam": beam,
    "transform": transform,
    "boost": boost,
    "door": door,
}
