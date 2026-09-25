class_name MechPlayer
extends CharacterBody3D
## Kestrel in mech form: Mega Man X-style platforming on the Z = 0 plane.
## Run, variable jump, double jump, coyote + buffer, ground/air dash (dash-jump keeps speed),
## wall slide + wall jump, hold-to-fire with a charge shot on release (echo weapons carry
## over), SUPER beam at full energy.
## Health mirrors RunSession like the ship; falling into a pit costs 1 HP and returns you to
## the last safe ground.

signal died
signal respawned
signal super_fired
signal echo_collected(echo_id: StringName)

## Run distance between footfall sounds.
const STRIDE := 1.9

enum State { GROUND, AIR, DASH, WALL, HIT, SUPER, DISABLED, CINEMATIC }

const GROUP := Players.GROUP
const COLLECT_EFFECT := preload("res://vfx/collect_burst.tscn")

@export var tuning: MechTuning
@export var model: MechModel
@export var arsenal: ShipArsenal
@export var health: HealthComponent
@export var hurtbox: HurtboxComponent
@export var flash: FlashComponent
@export var muzzle: Node3D
@export var death_effect: PackedScene
@export var jump_effect: PackedScene
@export var read_devices: bool = true
## Falling below this Y counts as a pit.
@export var kill_y: float = -30.0

var state: State = State.AIR
var _stride: float = 0.0
var facing: float = 1.0
## Enemies aim at the chest, not the feet.
var aim_offset: Vector3 = Vector3(0, 1.2, 0)

var _coyote: float = 0.0
var _buffer: float = 0.0
var _air_jumps: int = 0
## Lifetime double-jump count (tutorial + telemetry).
var double_jumps: int = 0
var _air_dash_ready: bool = true
var _dash_left: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_carry: bool = false
var _wall_lock: float = 0.0
var _wall_normal_x: float = 0.0
var _wall_coyote: float = 0.0
var _jump_cut_done: bool = true
var _invulnerable_left: float = 0.0
var _hit_left: float = 0.0
var _super_left: float = 0.0
var _last_safe: Vector3 = Vector3.ZERO
var _safe_timer: float = 0.0
var _muzzle_x: float = 1.0
var _arsenal_x: float = 1.0
var _clock: float = 0.0
var _charge_time: float = 0.0
var _charge_level: int = 0
## Lifetime charge shots fired (tests + telemetry).
var charge_shots: int = 0

# Telemetry.
var _jump_apex: float = 0.0
var _jump_start_y: float = 0.0
var _last_apex: float = 0.0
var _coyote_jumps: int = 0
var _buffered_jumps: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"debug_telemetry")
	collision_layer = PhysicsLayers.ACTOR
	collision_mask = PhysicsLayers.WORLD
	floor_snap_length = 0.35
	health.health_changed.connect(func(current: int, _m: int) -> void: RunSession.set_health(current))
	health.damaged.connect(_on_damaged)
	health.depleted.connect(_on_depleted)
	var start_health := RunSession.health if RunSession.health > 0 else RunSession.max_health
	health.setup(RunSession.max_health, start_health)
	_last_safe = global_position
	_muzzle_x = absf(muzzle.position.x)
	_arsenal_x = absf(arsenal.position.x)
	arsenal.fired.connect(_on_arsenal_fired)


func _physics_process(delta: float) -> void:
	if read_devices:
		tick(delta, MechInput.from_devices())


func tick(delta: float, input: MechInput) -> void:
	_clock += delta
	_invulnerable_left = maxf(0.0, _invulnerable_left - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_wall_lock = maxf(0.0, _wall_lock - delta)
	_wall_coyote = maxf(0.0, _wall_coyote - delta)
	match state:
		State.DISABLED:
			_update_invulnerability()
			return
		State.CINEMATIC:
			velocity = Vector3(0, velocity.y - tuning.gravity_down * delta, 0)
			_move()
			_update_visuals(delta, 0.0)
			return
		State.SUPER:
			_super_left -= delta
			velocity = Vector3.ZERO
			_move()
			if _super_left <= 0.0:
				state = State.GROUND if is_on_floor() else State.AIR
			_update_invulnerability()
			_update_visuals(delta, 0.0)
			return

	var on_floor := is_on_floor()
	if on_floor:
		_coyote = tuning.coyote_time
		_air_jumps = tuning.air_jumps
		_air_dash_ready = true
		_dash_carry = false
		_track_safe_ground(delta)
	else:
		_coyote = maxf(0.0, _coyote - delta)
	_buffer = tuning.jump_buffer if input.jump_pressed else maxf(0.0, _buffer - delta)

	var controllable := state != State.HIT
	if state == State.HIT:
		_hit_left -= delta
		if _hit_left <= 0.0:
			state = State.GROUND if on_floor else State.AIR

	# Horizontal.
	if _dash_left > 0.0:
		_dash_left -= delta
		velocity.x = facing * tuning.dash_speed
		velocity.y = maxf(velocity.y, 0.0) if not on_floor else velocity.y
		if _dash_left <= 0.0:
			state = State.GROUND if on_floor else State.AIR
	elif controllable and _wall_lock <= 0.0:
		var top := tuning.run_speed * (tuning.dash_jump_carry * tuning.dash_speed / tuning.run_speed if _dash_carry else 1.0)
		var target := input.move_x * top
		var rate := tuning.acceleration if absf(input.move_x) > 0.1 else tuning.deceleration
		if not on_floor:
			rate *= tuning.air_control
		velocity.x = move_toward(velocity.x, target, rate * delta)
		if absf(input.move_x) > 0.1:
			facing = signf(input.move_x)

	# Wall slide.
	var wall_contact := false
	if not on_floor and is_on_wall() and controllable:
		var n := get_wall_normal()
		if absf(n.x) > 0.5 and absf(input.move_x) > 0.1 and signf(input.move_x) == -signf(n.x):
			wall_contact = true
			_wall_normal_x = signf(n.x)
			_wall_coyote = 0.1
			_air_dash_ready = true
			if velocity.y < -tuning.wall_slide_speed:
				velocity.y = -tuning.wall_slide_speed

	# Jumps: ground/coyote → wall → air.
	if controllable and _buffer > 0.0:
		if on_floor or _coyote > 0.0:
			if not on_floor:
				_coyote_jumps += 1
			if not input.jump_pressed:
				_buffered_jumps += 1
			_jump(tuning.jump_velocity)
			AudioService.play(&"jump")
			if _dash_left > 0.0:
				_dash_carry = true
				_dash_left = 0.0
		elif _wall_coyote > 0.0:
			_jump(tuning.wall_jump_velocity)
			AudioService.play(&"wall_jump")
			velocity.x = _wall_normal_x * tuning.wall_jump_push
			facing = _wall_normal_x
			_wall_lock = tuning.wall_jump_lock
			_wall_coyote = 0.0
		elif _air_jumps > 0 and _dash_left <= 0.0:
			_air_jumps -= 1
			double_jumps += 1
			_jump(tuning.double_jump_velocity)
			AudioService.play(&"double_jump")
			Vfx.spawn(get_tree(), jump_effect, global_position + Vector3(0, 0.2, 0), 0.8, {&"color": Palette.PLAYER_ENERGY})

	# Variable height.
	if not input.jump_held and velocity.y > 0.0 and not _jump_cut_done:
		velocity.y *= tuning.jump_cut
		_jump_cut_done = true

	# Gravity (dash suspends it).
	if _dash_left <= 0.0:
		var g := tuning.gravity_up if velocity.y > 0.0 and input.jump_held else tuning.gravity_down
		velocity.y = maxf(velocity.y - g * delta, -tuning.max_fall_speed)

	# Dash.
	if controllable and input.dash_pressed and _dash_cooldown <= 0.0 and (on_floor or _air_dash_ready):
		_dash_left = tuning.dash_duration
		_dash_cooldown = tuning.dash_duration + tuning.dash_cooldown
		if not on_floor:
			_air_dash_ready = false
			velocity.y = 0.0
		_invulnerable_left = maxf(_invulnerable_left, tuning.dash_invulnerability)
		state = State.DASH
		AudioService.play(&"dash")

	# Super.
	if controllable and input.special_pressed and RunSession.super_ready():
		_fire_super()

	arsenal.facing = facing
	arsenal.position.x = _arsenal_x * facing
	muzzle.position.x = _muzzle_x * facing
	var firing := input.fire and controllable and state != State.SUPER
	arsenal.tick(delta, firing)
	_update_charge(delta, firing)

	var fall_speed := -velocity.y
	var was_airborne := not on_floor
	_move()
	on_floor = is_on_floor()
	if was_airborne and on_floor and fall_speed > 6.0:
		AudioService.play(&"land")
	# Footfalls while running (not dashing): one clank per stride.
	if on_floor and _dash_left <= 0.0 and absf(velocity.x) > 2.0:
		_stride += absf(velocity.x) * delta
		if _stride > STRIDE:
			_stride = 0.0
			AudioService.play(&"mech_step", 0.0, 0.08)
	else:
		_stride = STRIDE * 0.7
	if state != State.HIT and state != State.SUPER and _dash_left <= 0.0:
		state = State.GROUND if on_floor else (State.WALL if wall_contact else State.AIR)
	if global_position.y < kill_y:
		_fall_into_pit()
	_track_apex()
	_update_invulnerability()
	_update_visuals(delta, absf(velocity.x) / tuning.run_speed)


## The buster charges only while no echo weapon is equipped (echoes are their own power-up).
func _update_charge(delta: float, firing: bool) -> void:
	var can_charge := RunSession.selected_echo == RunSession.NO_ECHO
	if firing and can_charge:
		_charge_time += delta
		var level := 2 if _charge_time >= tuning.charge_level_2 else (1 if _charge_time >= tuning.charge_level_1 else 0)
		if level > _charge_level:
			_charge_level = level
			AudioService.play(&"charge")
	elif _charge_level > 0 and can_charge and state != State.DISABLED:
		var damage := tuning.charge_damage_2 if _charge_level >= 2 else tuning.charge_damage_1
		ChargeShot.fire(get_tree(), muzzle.global_position, facing, _charge_level, damage)
		charge_shots += 1
		model.shoot_kick()
		_reset_charge()
	else:
		_reset_charge()
	model.set_charge(_charge_level, _charge_time)


func _reset_charge() -> void:
	_charge_time = 0.0
	_charge_level = 0


func _jump(speed: float) -> void:
	velocity.y = speed
	_buffer = 0.0
	_coyote = 0.0
	_jump_cut_done = false
	_jump_start_y = global_position.y
	_jump_apex = global_position.y


func _move() -> void:
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0


func _track_safe_ground(delta: float) -> void:
	# Safe = on solid, non-moving ground for a moment.
	var collider := get_last_slide_collision().get_collider() if get_slide_collision_count() > 0 else null
	if collider is AnimatableBody3D or (collider is Node and (collider as Node).is_in_group(&"unsafe_ground")):
		_safe_timer = 0.0
		return
	_safe_timer += delta
	if _safe_timer > 0.25:
		_last_safe = global_position


func _track_apex() -> void:
	if not is_on_floor():
		_jump_apex = maxf(_jump_apex, global_position.y)
	elif _jump_apex > _jump_start_y:
		_last_apex = _jump_apex - _jump_start_y
		_jump_apex = global_position.y
		_jump_start_y = global_position.y


func _fall_into_pit() -> void:
	health.invulnerable = false
	var payload := DamagePayload.create(1, Teams.Team.NEUTRAL)
	payload.damage_type = &"pit"
	health.apply_damage(payload, self)
	if not health.is_depleted():
		teleport(_last_safe + Vector3(-facing * 1.5, 0.5, 0))
		_invulnerable_left = tuning.hit_invulnerability


## Instant reposition (respawns, pit recovery); resets motion and the camera.
func teleport(to: Vector3) -> void:
	global_position = Vector3(to.x, to.y, 0.0)
	velocity = Vector3.ZERO
	_dash_left = 0.0
	var camera := GameplayCamera.find(get_tree())
	if camera and camera.follow_target == self:
		camera.snap_to_target()


func _fire_super() -> void:
	AudioService.play(&"charge")
	RunSession.spend_energy(RunSession.MAX_ENERGY)
	state = State.SUPER
	_super_left = tuning.super_duration
	_invulnerable_left = maxf(_invulnerable_left, tuning.super_duration + 0.2)
	var root := get_tree().get_first_node_in_group(Vfx.ROOT_GROUP)
	if root:
		root.add_child(PlayerBeam.create(muzzle, facing, tuning.super_duration))
	super_fired.emit()


func respawn(at: Vector3) -> void:
	visible = true
	state = State.AIR
	health.revive()
	hurtbox.set_deferred(&"monitorable", true)
	teleport(at)
	_last_safe = at
	_invulnerable_left = tuning.respawn_invulnerability
	flash.flash(tuning.respawn_invulnerability)
	respawned.emit()


func in_cinematic() -> bool:
	return state == State.CINEMATIC


func set_cinematic(enabled: bool) -> void:
	if state == State.DISABLED:
		return
	state = State.CINEMATIC if enabled else State.AIR
	velocity.x = 0.0


func collect_echo(echo_id: StringName) -> void:
	var data := EchoModules.get_data(echo_id)
	if data == null:
		return
	RunSession.equip_echo(echo_id, data.ammo)
	Vfx.spawn(get_tree(), COLLECT_EFFECT, global_position + Vector3(0, 1.2, 0), 1.0, {&"color": data.module_color})
	echo_collected.emit(echo_id)


func tutorial_steps() -> Array[Dictionary]:
	return [
		{"id": "mech_move", "text": "RUN", "key": "A D", "pad": "L-STICK", "hold": 0.6},
		{"id": "mech_jump", "text": "JUMP — HOLD FOR HEIGHT", "key": "SPACE", "pad": "A", "hold": 0.0},
		{"id": "mech_double_jump", "text": "JUMP AGAIN IN THE AIR", "key": "SPACE", "pad": "A", "hold": 0.0},
		{"id": "mech_dash", "text": "DASH — DASH + JUMP GOES FARTHER", "key": "K", "pad": "B", "hold": 0.0},
		{"id": "fire", "text": "HOLD TO FIRE", "key": "J", "pad": "RT", "hold": 1.0},
		{"id": "super", "text": "SUPER READY — UNLEASH IT", "key": "I", "pad": "RB", "hold": 0.0, "when": "super_ready"},
	]


func can_collect() -> bool:
	return state != State.DISABLED


func grant_invulnerability(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)
	_update_invulnerability()


func is_invulnerable() -> bool:
	return health.invulnerable


func get_debug_lines() -> PackedStringArray:
	return PackedStringArray([
		"MECH %s  vel (%.1f, %.1f)  floor %s  facing %d" % [State.keys()[state], velocity.x, velocity.y, is_on_floor(), int(facing)],
		"  last apex %.2fu  air jumps %d  air dash %s  coyote jumps %d  buffered %d" % [_last_apex, _air_jumps, _air_dash_ready, _coyote_jumps, _buffered_jumps],
	])


func _update_invulnerability() -> void:
	health.invulnerable = _invulnerable_left > 0.0 or state in [State.DISABLED, State.CINEMATIC, State.SUPER]


func _update_visuals(delta: float, speed_ratio: float) -> void:
	model.scale.x = facing
	var pose := MechModel.Pose.IDLE
	match state:
		State.GROUND:
			pose = MechModel.Pose.RUN if speed_ratio > 0.1 else MechModel.Pose.IDLE
		State.AIR:
			pose = MechModel.Pose.AIR
		State.DASH:
			pose = MechModel.Pose.DASH
		State.WALL:
			pose = MechModel.Pose.WALL
		State.HIT:
			pose = MechModel.Pose.HIT
		State.SUPER:
			pose = MechModel.Pose.SUPER
	model.update_pose(pose, speed_ratio, delta)


func _on_damaged(payload: DamagePayload, _source: Node) -> void:
	_invulnerable_left = tuning.hit_invulnerability
	flash.flash(tuning.hit_invulnerability)
	var camera := GameplayCamera.find(get_tree())
	if camera:
		camera.add_trauma(ArtStyle.SHAKE_PLAYER_HIT)
	if health.is_depleted() or payload.damage_type == &"pit":
		return
	_dash_left = 0.0
	state = State.HIT
	_hit_left = tuning.hit_stun
	velocity = Vector3(-facing * tuning.knockback.x, tuning.knockback.y, 0)
	_update_invulnerability()


func _on_depleted(_source: Node) -> void:
	state = State.DISABLED
	_reset_charge()
	model.set_charge(0, 0.0)
	AudioService.play(&"player_death")
	visible = false
	flash.stop()
	RunSession.clear_echo()
	hurtbox.set_deferred(&"monitorable", false)
	_update_invulnerability()
	Vfx.spawn(get_tree(), death_effect, global_position + Vector3(0, 1.2, 0), 1.8)
	var root := get_tree().get_first_node_in_group(Vfx.ROOT_GROUP)
	if root:
		root.add_child(FragmentBurst.create(model.make_fragments(), global_position + Vector3(0, 1.2, 0)))
	HitStop.trigger(get_tree(), 0.09)
	died.emit()


func _on_arsenal_fired() -> void:
	model.shoot_kick()
