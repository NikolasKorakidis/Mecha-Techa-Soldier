class_name HullRiderTuning
extends Resource
## Bike feel values for the 3D hull run (chase camera, forward = +X, lateral = Z).

@export_group("Speed")
@export var start_speed: float = 56.0
@export var max_speed: float = 80.0
## Cruise speed gained per second.
@export var speed_ramp: float = 0.45
## Forward/back input scales cruise speed by ± this fraction.
@export var throttle: float = 0.2
@export var acceleration: float = 55.0

@export_group("Steering")
@export var lateral_speed: float = 22.0
@export var lateral_accel: float = 130.0
## Half width of the drivable deck (Z).
@export var lane_half_width: float = 8.0

@export_group("Jump")
@export var jump_velocity: float = 15.0
@export var double_jump_velocity: float = 13.5
@export var air_jumps: int = 1
@export var gravity_up: float = 40.0
@export var gravity_down: float = 64.0
@export var max_fall_speed: float = 40.0
@export var jump_cut: float = 0.5
@export var coyote_time: float = 0.12
@export var jump_buffer: float = 0.14
@export var pad_velocity: float = 28.0

@export_group("Boost")
@export var boost_multiplier: float = 1.3
@export var boost_duration: float = 0.6
@export var boost_cooldown: float = 1.4
@export var roll_impulse: float = 28.0
@export var ram_damage: int = 6

@export_group("Guns")
@export var fire_interval: float = 0.075
@export var bolt_speed: float = 180.0
## Shots bend toward an enemy inside this cone (degrees) and range.
@export var assist_angle: float = 18.0
@export var assist_range: float = 180.0

@export_group("Damage")
@export var hit_invulnerability: float = 1.4
@export var hit_slowdown: float = 0.6
@export var hit_recovery: float = 0.9
@export var respawn_invulnerability: float = 2.2
@export var super_duration: float = 1.5
