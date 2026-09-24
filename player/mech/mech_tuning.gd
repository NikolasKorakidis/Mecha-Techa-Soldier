class_name MechTuning
extends Resource
## Mech feel values (Mega Man X-style: snappy run, crisp arcs, dash, wall jump).
## Change one family per tuning pass.

@export_group("Run")
@export var run_speed: float = 9.0
@export var acceleration: float = 90.0
@export var deceleration: float = 110.0
## Air control as a fraction of ground acceleration.
@export var air_control: float = 0.85

@export_group("Jump")
@export var jump_velocity: float = 15.5
@export var double_jump_velocity: float = 13.5
@export var air_jumps: int = 1
@export var gravity_up: float = 40.0
@export var gravity_down: float = 58.0
@export var max_fall_speed: float = 24.0
## Releasing jump while rising multiplies upward speed by this (variable height).
@export var jump_cut: float = 0.45
@export var coyote_time: float = 0.1
@export var jump_buffer: float = 0.12

@export_group("Dash")
@export var dash_speed: float = 20.0
@export var dash_duration: float = 0.22
@export var dash_cooldown: float = 0.28
@export var dash_invulnerability: float = 0.1
## Jumping out of a ground dash keeps this share of dash speed in the air.
@export var dash_jump_carry: float = 0.8

@export_group("Wall")
@export var wall_slide_speed: float = 4.0
@export var wall_jump_velocity: float = 14.5
@export var wall_jump_push: float = 10.0
## Input ignored briefly after a wall jump so the kick-off reads.
@export var wall_jump_lock: float = 0.14

@export_group("Damage")
@export var hit_invulnerability: float = 1.3
@export var hit_stun: float = 0.25
@export var respawn_invulnerability: float = 2.0
@export var knockback: Vector2 = Vector2(7.0, 6.0)

@export_group("Super")
@export var super_duration: float = 1.35
