"""Second SFX pass: punchier, louder core effects and the missing ones (bike engine loop,
crash, footsteps, wall kick, whoosh, boss roar). Every effect is loudness-matched with
_loud() so nothing gets buried under the music. Overrides same-named entries in sfx.SFX."""
from synth import *  # noqa: F401,F403
import sfx
from sfx import explosion


def _env(n: int, decay: float) -> np.ndarray:
    return np.exp(-t_axis(n) / decay)


def _sine(f: np.ndarray) -> np.ndarray:
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def _loud(x: np.ndarray, rms_db: float = -13.0, peak: float = 0.97) -> np.ndarray:
    """Match loudness (RMS over the audible part), soft-clip, keep the peak below `peak`."""
    x = highpass(x, 25)
    active = np.abs(x) > 0.02 * (float(np.max(np.abs(x))) or 1.0)
    rms = float(np.sqrt(np.mean(x[active] ** 2))) if active.any() else 1.0
    x = x * (10 ** (rms_db / 20) / (rms or 1.0))
    x = np.tanh(x * 1.3) / np.tanh(1.3)
    return x * min(1.0, peak / (float(np.max(np.abs(x))) or 1.0))


def _mix(*parts: tuple[np.ndarray, float]) -> np.ndarray:
    n = max(len(p) + int(o * SR) for p, o in parts)
    out = np.zeros(n)
    for p, o in parts:
        i = int(o * SR)
        out[i:i + len(p)] += p
    return out


def _click(n: int = 160) -> np.ndarray:
    return highpass(noise(n), 3000) * _env(n, 0.002)


def _thump(f0: float, f1: float, dur: float, decay: float) -> np.ndarray:
    n = int(dur * SR)
    t = t_axis(n)
    return _sine(f1 + (f0 - f1) * np.exp(-t / 0.025)) * _env(n, decay)


def _clank(f: float, dur: float = 0.25) -> np.ndarray:
    """Metallic ring: inharmonic partials with fast decay."""
    n = int(dur * SR)
    t = t_axis(n)
    x = np.zeros(n)
    for k, (ratio, amp) in enumerate([(1.0, 1.0), (2.76, 0.6), (5.4, 0.35), (8.9, 0.2)]):
        x += np.sin(2 * np.pi * f * ratio * t) * _env(n, 0.09 / (1 + k * 0.6)) * amp
    return x


# --- Shots -------------------------------------------------------------------------------

def shot_player() -> np.ndarray:
    n = int(0.13 * SR)
    t = t_axis(n)
    zap = pulse(2600 * np.exp(-t / 0.028) + 420, 0.3) * _env(n, 0.04)
    body = _sine(260 * np.exp(-t / 0.03) + 90) * _env(n, 0.05)
    return _loud(lowpass(zap, 7000) * 0.7 + body * 0.8 + np.pad(_click(), (0, n - 160)) * 0.6, -14)


def laser() -> np.ndarray:
    n = int(0.16 * SR)
    t = t_axis(n)
    beam = saw(3200 * np.exp(-t / 0.04) + 700) * _env(n, 0.055)
    ring = _sine(1400 * np.exp(-t / 0.06) + 500) * _env(n, 0.07)
    return _loud(lowpass(beam, 8000) * 0.6 + ring * 0.5 + np.pad(_click(), (0, n - 160)) * 0.5, -15)


def shot_enemy() -> np.ndarray:
    n = int(0.2 * SR)
    t = t_axis(n)
    x = tri(900 * np.exp(-t / 0.07) + 220) * _env(n, 0.08) + pulse(450 * np.exp(-t / 0.05) + 150, 0.5) * _env(n, 0.05) * 0.4
    return _loud(lowpass(x, 5000), -17)


# --- Movement -----------------------------------------------------------------------------

def jump() -> np.ndarray:
    """Mech servo kick + thruster puff + rising blip."""
    n = int(0.24 * SR)
    t = t_axis(n)
    puff = sweep_filter(noise(n), np.exp(-t / 0.08), 400, 5000) * _env(n, 0.09)
    blip = pulse(320 + 900 * (t / t[-1]) ** 0.7, 0.4) * _env(n, 0.07)
    kick = _thump(160, 70, 0.1, 0.04)
    return _loud(_mix((puff * 0.8, 0), (lowpass(blip, 4000) * 0.45, 0), (kick, 0)), -13)


def double_jump() -> np.ndarray:
    n = int(0.3 * SR)
    t = t_axis(n)
    burst = sweep_filter(noise(n), np.exp(-t / 0.12), 700, 8000) * _env(n, 0.13)
    tone = pulse(600 + 1500 * (t / t[-1]), 0.25) * _env(n, 0.09)
    return _loud(_mix((burst, 0), (lowpass(tone, 6000) * 0.4, 0), (_thump(220, 110, 0.08, 0.03) * 0.6, 0)), -13)


def wall_jump() -> np.ndarray:
    return _loud(_mix((_clank(380, 0.2) * 0.5, 0), (_thump(140, 60, 0.12, 0.04), 0), (double_jump() * 0.7, 0.02)), -12)


def dash() -> np.ndarray:
    """Jet burst: bright ignition crack, roaring noise sweep, low thrust."""
    n = int(0.42 * SR)
    t = t_axis(n)
    roar = sweep_filter(noise(n), np.clip(t / 0.03, 0, 1) * np.exp(-t / 0.18), 500, 9000) * _env(n, 0.2)
    thrust = np.tanh(3 * saw(90 + 60 * np.exp(-t / 0.1))) * _env(n, 0.14)
    return _loud(_mix((roar, 0), (lowpass(thrust, 1500) * 0.6, 0), (_click(240) * 0.8, 0)), -12)


def land() -> np.ndarray:
    return _loud(_mix((_thump(130, 55, 0.2, 0.06), 0), (lowpass(noise(int(0.08 * SR)), 1800) * _env(int(0.08 * SR), 0.02) * 0.7, 0),
            		(_clank(210, 0.18) * 0.25, 0.005)), -14)


def heavy_land() -> np.ndarray:
    return _loud(_mix((_thump(110, 38, 0.6, 0.18), 0), (explosion(0.6) * 0.45, 0), (_clank(150, 0.4) * 0.35, 0.01)), -11)


def mech_step() -> np.ndarray:
    n = int(0.12 * SR)
    return _loud(_mix((_thump(150, 70, 0.12, 0.035), 0), (_clank(260 + RNG.uniform(-20, 20), 0.12) * 0.3, 0.004),
            (lowpass(noise(n), 2500) * _env(n, 0.012) * 0.5, 0)), -18)


def whoosh() -> np.ndarray:
    n = int(0.9 * SR)
    t = t_axis(n)
    env = np.sin(np.pi * np.clip(t / 0.9, 0, 1)) ** 2
    return _loud(sweep_filter(noise(n), env, 300, 6000) * env, -14)


# --- Damage -------------------------------------------------------------------------------

def hit() -> np.ndarray:
    n = int(0.11 * SR)
    return _loud(_mix((_click(200), 0), (_thump(420, 160, 0.09, 0.025) * 0.8, 0), (_clank(1300, 0.1) * 0.35, 0),
            (highpass(noise(n), 2000) * _env(n, 0.012) * 0.5, 0)), -15)


def armor_ping() -> np.ndarray:
    return _loud(_mix((_clank(1650, 0.3), 0), (_clank(2480, 0.2) * 0.4, 0)), -18)


def player_hurt() -> np.ndarray:
    n = int(0.45 * SR)
    t = t_axis(n)
    crunch = np.tanh(3 * lowpass(noise(n), 3500)) * _env(n, 0.06)
    alarm = pulse(np.where(t < 0.12, 880.0, 620.0), 0.5) * _env(n, 0.2) * (t > 0.05)
    return _loud(_mix((crunch, 0), (_thump(300, 90, 0.2, 0.06), 0), (lowpass(alarm, 3000) * 0.35, 0)), -11)


def player_death() -> np.ndarray:
    n = int(1.3 * SR)
    t = t_axis(n)
    fall = pulse(1000 * np.exp(-t / 0.35) + 50, 0.5) * _env(n, 0.45)
    return _loud(_mix((explosion(2.0), 0), (lowpass(fall, 3000) * 0.45, 0), (_clank(180, 0.8) * 0.4, 0.02)), -10)


def bike_crash() -> np.ndarray:
    """Metal-on-metal smash, grinding skid and a debris clatter."""
    n = int(0.9 * SR)
    t = t_axis(n)
    smash = np.tanh(4 * noise(n)) * _env(n, 0.08)
    grind = lowpass(highpass(noise(n), 1200), 5000) * (0.6 + 0.4 * np.sin(2 * np.pi * 37 * t)) * _env(n, 0.35)
    debris = np.zeros(n)
    for k in range(7):
        i = int(RNG.uniform(0.08, 0.6) * SR)
        c = _clank(RNG.uniform(500, 1600), 0.15) * RNG.uniform(0.2, 0.5)
        debris[i:i + len(c)] += c[: n - i]
    return _loud(_mix((smash, 0), (grind * 0.5, 0.02), (debris, 0), (_thump(120, 45, 0.4, 0.12), 0)), -10)


def bike_land() -> np.ndarray:
    n = int(0.25 * SR)
    t = t_axis(n)
    spring = _sine(np.full(n, 95.0)) * _env(n, 0.07) * (1 + 0.5 * np.sin(2 * np.pi * 18 * t))
    return _loud(_mix((_thump(140, 50, 0.25, 0.08), 0), (spring * 0.4, 0), (lowpass(noise(n), 1500) * _env(n, 0.03) * 0.6, 0)), -13)


def bike_engine() -> np.ndarray:
    """Seamless 1.0 s loop: a sci-fi twin with a firing pulse train, sub rumble and turbine whine.
    Every partial completes whole cycles in the loop, so it repeats without a click; the game
    shifts pitch with speed."""
    n = SR
    t = t_axis(n)
    fire = 48.0
    ph = (t * fire) % 1.0
    pulses = np.exp(-ph / 0.18) * (1 + 0.35 * np.sin(2 * np.pi * 4 * t))
    growl = np.tanh(2.5 * (saw(np.full(n, fire * 2)) * 0.6 + saw(np.full(n, fire * 3)) * 0.3)) * pulses
    sub = np.sin(2 * np.pi * fire * t) * 0.6
    whine = np.sin(2 * np.pi * 1320 * t) * 0.08 + np.sin(2 * np.pi * 1980 * t) * 0.04
    hiss = lowpass(highpass(noise(n), 2500), 7000) * 0.08
    # Make the noise loop seamlessly by crossfading its end into its start.
    fade = np.linspace(0, 1, 2000)
    hiss[:2000] = hiss[:2000] * fade + hiss[-2000:] * (1 - fade)
    x = lowpass(growl, 2600) + sub + whine + hiss
    return _loud(x, -15, 0.9)


def boss_roar() -> np.ndarray:
    """Mechanical roar: detuned growl sweeping down through a formant, servo whine, a stomp."""
    n = int(1.8 * SR)
    t = t_axis(n)
    f = 140 * np.exp(-t / 1.2) + 55
    growl = np.tanh(3 * (saw(f) + saw(f * 1.013) + pulse(f * 0.5, 0.3) * 0.6))
    env = np.clip(t / 0.08, 0, 1) * np.clip((1.8 - t) / 0.5, 0, 1)
    formant = sweep_filter(growl, np.exp(-t / 0.7), 400, 2400)
    servo = _sine(900 + 500 * np.sin(2 * np.pi * 1.5 * t)) * 0.15 * env
    return _loud(_mix((formant * env, 0), (servo, 0), (heavy_land() * 0.6, 0)), -10)


def boss_break() -> np.ndarray:
    return _loud(_mix((explosion(1.6), 0), (_clank(220, 0.9) * 0.5, 0), (_clank(330, 0.7) * 0.4, 0.15)), -10)


SFX_V2 = {
    "shot_player": shot_player,
    "laser": laser,
    "shot_enemy": shot_enemy,
    "jump": jump,
    "double_jump": double_jump,
    "wall_jump": wall_jump,
    "dash": dash,
    "land": land,
    "heavy_land": heavy_land,
    "mech_step": mech_step,
    "whoosh": whoosh,
    "hit": hit,
    "armor_ping": armor_ping,
    "player_hurt": player_hurt,
    "player_death": player_death,
    "bike_crash": bike_crash,
    "bike_land": bike_land,
    "bike_engine": bike_engine,
    "boss_roar": boss_roar,
    "boss_break": boss_break,
    "boost": lambda: _loud(sfx.boost(), -11),
    "charge": lambda: _loud(sfx.charge(), -13),
    "pickup": lambda: _loud(sfx.pickup(), -12),
    "weapon_get": lambda: _loud(sfx.weapon_get(), -12),
    "checkpoint": lambda: _loud(sfx.checkpoint(), -13),
    "transform": lambda: _loud(sfx.transform(), -10),
    "door": lambda: _loud(sfx.door(), -11),
    "shot_heavy": lambda: _loud(sfx.shot_heavy(), -11),
    "explosion_small": lambda: _loud(explosion(0.7), -12),
    "explosion_large": lambda: _loud(explosion(1.4), -11),
    "explosion_huge": lambda: _loud(explosion(2.6), -10),
}
