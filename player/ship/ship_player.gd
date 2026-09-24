class_name ShipPlayer
extends Node3D
## Kestrel in interceptor form. Coordinates movement, weapon, health and feedback;
## each concern lives in its own component. Health mirrors into RunSession.

signal died
signal respawned

enum State { CONTROL, DASH, HIT, DISABLED, CINEMATIC }

const GROUP := &"player"

@export var tuning: ShipTuning
@export var movement: ShipMovement
@export var weapon: WeaponComponent
@export var health: HealthComponent
@export var hurtbox: HurtboxComponent
@export var flash: FlashComponent
@export var model: KestrelModel
@export var dash_meter: MeshInstance3D
@export var muzzle_flash: Node3D
@export var death_effect: PackedScene

## When false, the ship ignores devices (tests and cinematics drive tick() directly).
@export var read_devices: bool = true

var state: State = State.CONTROL

var _camera: GameplayCamera
var _invulnerable_left: float = 0.0
var _hit_left: float = 0.0
var _dash_meter_material: StandardMaterial3D
var _muzzle_flash_left: float = 0.0

# Telemetry (F3 debug panel).
var _accel_timer: float = -1.0
var _last_accel_time: float = 0.0
var _dash_start: Vector2 = Vector2.ZERO
var _last_dash_distance: float = 0.0
var _last_hit: String = "none"
var _clock: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"debug_telemetry")
	movement.tuning = tuning
	_camera = GameplayCamera.find(get_tree())
	if _camera == null:
		push_error("ShipPlayer: no GameplayCamera in the level.")

	health.health_changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.depleted.connect(_on_depleted)
	var start_health := RunSession.health if RunSession.health > 0 else RunSession.max_health
	health.setup(RunSession.max_health, start_health)

	weapon.fired.connect(_on_weapon_fired)
	if muzzle_flash:
		muzzle_flash.visible = false
	if dash_meter:
		_dash_meter_material = dash_meter.get_active_material(0).duplicate() as StandardMaterial3D
		dash_meter.material_override = _dash_meter_material


func _physics_process(delta: float) -> void:
	if read_devices:
		tick(delta, ShipInput.from_devices())


func tick(delta: float, input: ShipInput) -> void:
	_clock += delta
	_invulnerable_left = maxf(0.0, _invulnerable_left - delta)

	if state == State.DISABLED or state == State.CINEMATIC:
		_update_invulnerability()
		return
	if state == State.HIT:
		_hit_left -= delta
		if _hit_left <= 0.0:
			state = State.CONTROL

	var controllable := state != State.HIT
	var move := input.move if controllable else Vector2.ZERO

	if controllable and input.dash_pressed and movement.try_dash(move):
		state = State.DASH
		_dash_start = _plane_position()
	if controllable and input.burst_pressed:
		movement.try_burst(move.y)

	movement.step(delta, move)
	if state == State.DASH and not movement.is_dashing:
		state = State.CONTROL
		_last_dash_distance = _plane_position().distance_to(_dash_start)

	if _camera:
		var next := movement.move_within(_plane_position(), _camera.get_play_rect(), delta)
		global_position = Vector3(next.x, next.y, 0.0)

	weapon.tick(delta, input.fire and controllable)
	_update_invulnerability()
	_update_visuals(delta)
	_update_accel_telemetry(delta, move)


func respawn(at: Vector3) -> void:
	global_position = Vector3(at.x, at.y, 0.0)
	visible = true
	movement.reset()
	weapon.reset()
	health.revive()
	hurtbox.set_deferred(&"monitorable", true)
	_invulnerable_left = tuning.respawn_invulnerability
	flash.flash(tuning.respawn_invulnerability)
	state = State.CONTROL
	_update_invulnerability()
	respawned.emit()


## Locks control for cinematics (transformation bridge, boss intros).
func set_cinematic(enabled: bool) -> void:
	if state == State.DISABLED:
		return
	state = State.CINEMATIC if enabled else State.CONTROL
	movement.reset()
	_update_invulnerability()


func is_invulnerable() -> bool:
	return health.invulnerable


func get_debug_lines() -> PackedStringArray:
	return PackedStringArray([
		"SHIP %s  speed %.1f  vel (%.1f, %.1f)" % [State.keys()[state], movement.velocity.length(), movement.velocity.x, movement.velocity.y],
		"  accel→95%% %.3fs  last dash %.2fu  dash cd %.2fs" % [_last_accel_time, _last_dash_distance, movement.dash_cooldown_left],
		"  invuln %.2fs  dash i-frames %s" % [_invulnerable_left, movement.is_dash_invulnerable()],
		"  last hit: %s" % _last_hit,
	])


func _plane_position() -> Vector2:
	return Vector2(global_position.x, global_position.y)


func _update_invulnerability() -> void:
	health.invulnerable = (
		_invulnerable_left > 0.0
		or movement.is_dash_invulnerable()
		or state == State.DISABLED
		or state == State.CINEMATIC
	)


func _update_visuals(delta: float) -> void:
	if model:
		# Bank into vertical motion; squash along the dash.
		model.rotation.x = -movement.velocity.y / tuning.max_speed * 0.45
		model.scale = Vector3(1.25, 0.8, 1.0) if movement.is_dashing else Vector3.ONE
		model.set_thrust(2.0 if movement.is_dashing else 0.6 + movement.velocity.x / tuning.max_speed * 0.5)
		model.set_dashing(movement.is_dashing)
	if muzzle_flash:
		_muzzle_flash_left -= delta
		muzzle_flash.visible = _muzzle_flash_left > 0.0
	if dash_meter:
		var ready := movement.dash_cooldown_left <= 0.0
		dash_meter.scale.x = maxf(0.05, 1.0 - movement.dash_cooldown_ratio())
		if _dash_meter_material:
			_dash_meter_material.albedo_color = Palette.FRIENDLY if ready else Palette.EMPTY_SEGMENT


func _update_accel_telemetry(delta: float, move: Vector2) -> void:
	if move.length_squared() < 0.01:
		_accel_timer = 0.0
		return
	if _accel_timer < 0.0:
		return
	_accel_timer += delta
	if movement.velocity.length() >= tuning.max_speed * 0.95:
		_last_accel_time = _accel_timer
		_accel_timer = -1.0


func _on_weapon_fired(_projectile: Projectile) -> void:
	if muzzle_flash:
		_muzzle_flash_left = 0.045
		muzzle_flash.scale = Vector3.ONE * randf_range(0.8, 1.2)


func _shake(amount: float) -> void:
	if _camera:
		_camera.add_trauma(amount)


func _on_health_changed(current: int, _maximum: int) -> void:
	RunSession.set_health(current)


func _on_damaged(payload: DamagePayload, source: Node) -> void:
	_last_hit = "%s (-%d) @ %.2fs" % [source.name if is_instance_valid(source) else "?", payload.amount, _clock]
	_invulnerable_left = tuning.hit_invulnerability
	flash.flash(tuning.hit_invulnerability)
	movement.cancel_dash()
	movement.velocity += Vector2(payload.knockback.x, payload.knockback.y)
	_shake(0.45)
	if not health.is_depleted():
		state = State.HIT
		_hit_left = tuning.hit_stun
	_update_invulnerability()


func _on_depleted(_source: Node) -> void:
	state = State.DISABLED
	visible = false
	flash.stop()
	movement.reset()
	weapon.reset()
	hurtbox.set_deferred(&"monitorable", false)
	_update_invulnerability()
	Vfx.spawn(get_tree(), death_effect, global_position, 1.8)
	died.emit()
