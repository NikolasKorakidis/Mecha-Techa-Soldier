class_name ArtStyle
extends RefCounted
## Style tokens shared by models, VFX and UI (docs/art-direction.md). Tune here, not in scenes.

# --- Glow (additive shader energy) -------------------------------------------
## Background accents: barely there.
const GLOW_SUBTLE := 0.7
## Engines, cores, standard projectiles.
const GLOW_STANDARD := 1.6
## Echo cores, special attacks, explosions' first frames.
const GLOW_HOT := 2.6

# --- Projectiles -------------------------------------------------------------
## Core stays solid and brighter than its trail so the collision center is obvious.
const PROJECTILE_CORE_ENERGY := 2.4
const PROJECTILE_TRAIL_ENERGY := 1.4

# --- Outlines (inverted-hull shell thickness, world units) -------------------
const OUTLINE_THICK := 0.07
const OUTLINE_THIN := 0.045
const OUTLINE_COLOR := Color("02040d")

# --- UI ----------------------------------------------------------------------
const UI_CORNER := 8
const UI_PANEL_ALPHA := 0.78
const UI_EDGE := 3
const UI_SKEW := 0.22
const UI_MARGIN := 32
const FONT_CAPTION := 18
const FONT_BODY := 24
const FONT_VALUE := 40
const FONT_TITLE := 64
const FONT_BANNER := 92

# --- Animation timing (seconds) ----------------------------------------------
const T_FAST := 0.12
const T_MED := 0.25
const T_SLOW := 0.5

# --- Camera impulse (trauma, 0..1; offset grows with trauma²) ----------------
const SHAKE_ENEMY_DEATH := 0.06
const SHAKE_ELITE_DEATH := 0.22
const SHAKE_PLAYER_HIT := 0.4
const SHAKE_MAJOR := 0.45
const SHAKE_BOSS_DEATH := 0.6
## Hard cap on total trauma any single frame can accumulate to.
const SHAKE_MAX_TRAUMA := 0.8


## Scales flashes and high-intensity pulses (reduced-flash accessibility).
static func flash_scale() -> float:
	return 0.3 if Settings.reduced_flash else 1.0


## Scales camera impulses (reduced-shake accessibility).
static func shake_scale() -> float:
	return 0.15 if Settings.reduced_shake else 1.0
