class_name ShipTuning
extends Resource
## Tunable ship feel values. Starting points are playtest hypotheses (docs/game-design.md).
## Change one family per tuning pass.

@export_group("Visual")
## Ship model size on screen (the hurtbox stays the same, shmup-fair).
@export var model_scale: float = 1.2

@export_group("Movement")
@export var max_speed: float = 13.0
## Units/s² while steering toward the stick direction.
@export var acceleration: float = 110.0
## Units/s² when the stick is released (short ease-out).
@export var deceleration: float = 80.0
## Half-size of the ship kept inside the play rect.
@export var boundary_margin: Vector2 = Vector2(1.3, 0.85)
## Extra clearance under the top edge so the ship never hides beneath the HUD bar.
@export var hud_top_inset: float = 1.1
## Distance from the boundary where outward velocity starts fading (soft edge).
@export var soft_edge: float = 0.6

@export_group("Dash")
@export var dash_speed: float = 32.0
@export var dash_duration: float = 0.18
## Invulnerable for the first part of the dash only — deliberately small.
@export var dash_invulnerability: float = 0.12
@export var dash_cooldown: float = 0.75

@export_group("Vertical burst")
@export var burst_speed: float = 20.0
@export var burst_duration: float = 0.12
@export var burst_cooldown: float = 0.45

@export_group("Damage")
@export var hit_invulnerability: float = 1.2
## Brief input lock after a hit. Never chain stuns.
@export var hit_stun: float = 0.12
@export var respawn_invulnerability: float = 2.0
