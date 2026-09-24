class_name Palette
extends RefCounted
## Gameplay color language (docs/art-direction.md). Colors never change between levels.
## Backgrounds stay dark and desaturated so gameplay colors dominate.

# Background
const BG_DEEP_NAVY := Color("050a1e")
const BG_BLUE := Color("081b33")
const BG_VIOLET := Color("24114a")

# Player
const PLAYER_PRIMARY := Color("eef5ff")
const PLAYER_SECONDARY := Color("268dff")
const PLAYER_ENERGY := Color("33e2ff")
const PLAYER_GOLD := Color("f6c84a")

# Enemies
const ENEMY_CORAL := Color("ed6570")
const ENEMY_DARK_RED := Color("6d233d")
const ECHO_GOLD := Color("ffe36a")

# Projectiles and energy
const HOSTILE_PROJECTILE := Color("ff3ca6")
const RESONANCE_VIOLET := Color("9d5cff")

# UI
const HEALTH_GREEN := Color("52e686")
const UI_DARK_PANEL := Color("081326")
const UI_MUTED_TEXT := Color("afc5d8")
const UI_GOLD := Color("f6c84a")

# Derived / supporting
const SHADOW := Color("02040d")
const ENEMY_SHADOW := Color("3a1024")
const PLAYER_SHADOW := Color("123a78")
const DANGER := Color("ff3b4a")
const EMPTY_SEGMENT := Color(0.69, 0.77, 0.85, 0.16)

# Legacy aliases (kept so existing references stay valid).
const FRIENDLY := PLAYER_ENERGY
const ENEMY := ENEMY_CORAL
const ECHO_CARRIER := ECHO_GOLD
const ENEMY_PROJECTILE := HOSTILE_PROJECTILE
const FRIENDLY_PROJECTILE := Color("bff6ff")
const INTERACTABLE := Color("ffd23f")
const HEALTH := HEALTH_GREEN
const ENERGY := RESONANCE_VIOLET
const SPACE_BACKGROUND := BG_DEEP_NAVY
const SPACE_SHADOW := BG_VIOLET
