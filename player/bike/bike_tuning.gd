class_name BikeTuning
extends Resource
## Bike feel values (auto-runner). Change one family per tuning pass.

@export_group("Speed")
@export var start_speed: float = 14.0
@export var max_speed: float = 22.0
## Cruise speed gained per second of riding.
@export var speed_ramp: float = 0.18
## Holding forward/back scales cruise speed by ± this fraction.
@export var throttle: float = 0.25
@export var acceleration: float = 22.0

@export_group("Jump")
@export var jump_velocity: float = 15.0
@export var double_jump_velocity: float = 13.0
@export var air_jumps: int = 1
@export var gravity_up: float = 42.0
@export var gravity_down: float = 60.0
@export var max_fall_speed: float = 26.0
@export var jump_cut: float = 0.45
@export var coyote_time: float = 0.12
@export var jump_buffer: float = 0.14
@export var pad_velocity: float = 30.0

@export_group("Boost")
@export var boost_multiplier: float = 1.7
@export var boost_duration: float = 0.5
@export var boost_cooldown: float = 1.3
@export var ram_damage: int = 8

@export_group("Body")
@export var stand_height: float = 1.6
@export var duck_height: float = 0.8

@export_group("Damage")
@export var hit_invulnerability: float = 1.4
## Speed multiplier applied right after a hit (recovers over hit_recovery seconds).
@export var hit_slowdown: float = 0.55
@export var hit_recovery: float = 0.8
@export var respawn_invulnerability: float = 2.0
@export var super_duration: float = 1.2
