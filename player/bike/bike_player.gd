class_name BikePlayer
extends CharacterBody3D
## Kestrel in bike form: auto-runner on the Z = 0 plane. Cruise speed ramps up over time;
## forward/back throttles it. Jump + double jump, duck (hold down) under beams, boost (dash)
## rams through crates and drones with i-frames, hold-to-fire, SUPER beam at full energy.
## Falling into a gap costs 1 HP and puts you back on the last safe ground.

signal died
signal respawned
signal super_fired
signal echo_collected(echo_id: StringName)

enum State { RIDE, AIR, BOOST, SUPER, DISABLED, CINEMATIC }

const GROUP := Players.GROUP
const COLLECT_EFFECT := preload("res://vfx/collect_burst.tscn")

@export var tuning: BikeTuning
@export var model: BikeModel
@export var arsenal: ShipArsenal
@export var health: HealthComponent
@export var hurtbox: HurtboxComponent
@export var flash: FlashComponent
@export var muzzle: Node3D
@export var body_shape: CollisionShape3D
@export var ram: HitboxComponent
@export var death_effect: PackedScene
@export var jump_effect: PackedScene
@export var read_devices: bool = true
@export var kill_y: float = -12.0

var state: State = State.RIDE
var facing: float = 1.0
var aim_offset: Vector3 = Vector3(0, 0.9, 0)
var cruise_speed: float = 0.0
var ducking: bool = false
var double_jumps: int = 0
var boosts: int = 0

var _coyote: float = 0.0
var _buffer: float = 0.0
var _air_jumps: int = 0
var _jump_cut_done: bool = true
var _boost_left: float = 0.0
var _boost_cooldown: float = 0.0
var _invulnerable_left: float = 0.0
var _slow: float = 1.0
var _super_left: float = 0.0
var _last_safe: Vector3 = Vector3.ZERO
var _safe_timer: float = 0.0
var _body_box: BoxShape3D
var _hurt_shape: CollisionShape3D
var _hurt_box: BoxShape3D


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"debug_telemetry")
	collision_layer = PhysicsLayers.ACTOR
	collision_mask = PhysicsLayers.WORLD
	floor_snap_length = 0.4
	cruise_speed = tuning.start_speed
	health.health_changed.connect(func(current: int, _m: int) -> void: RunSession.set_health(current))
	health.damaged.connect(_on_damaged)
	health.depleted.connect(_on_depleted)
	var start_health := RunSession.health if RunSession.health > 0 else RunSession.max_health
	health.setup(RunSession.max_health, start_health)
	_last_safe = global_position
	# Own copies so ducking never edits a shared resource.
	_body_box = (body_shape.shape as BoxShape3D).duplicate()
	body_shape.shape = _body_box
	_hurt_shape = hurtbox.get_child(0) as CollisionShape3D
	_hurt_box = (_hurt_shape.shape as BoxShape3D).duplicate()
	_hurt_shape.shape = _hurt_box
	ram.payload = DamagePayload.create(tuning.ram_damage, Teams.Team.PLAYER)
	ram.single_hit = false
	ram.continuous = true
	ram.set_physics_process(true)
	ram.set_deferred(&"monitoring", false)
	arsenal.fired.connect(model.shoot_kick)
	_apply_height(tuning.stand_height)


func _physics_process(delta: float) -> void:
	if read_devices:
		tick(delta, MechInput.from_devices())


func tick(delta: float, input: MechInput) -> void:
	_invulnerable_left = maxf(0.0, _invulnerable_left - delta)
	_boost_cooldown = maxf(0.0, _boost_cooldown - delta)
	_slow = move_toward(_slow, 1.0, delta / tuning.hit_recovery)
	match state:
		State.DISABLED:
			_update_invulnerability()
			return
		State.CINEMATIC:
			velocity.x = move_toward(velocity.x, 0.0, tuning.acceleration * delta)
			velocity.y -= tuning.gravity_down * delta
			_move()
			_update_visuals(delta)
			return
		State.SUPER:
			_super_left -= delta
			if _super_left <= 0.0:
				state = State.RIDE

	var on_floor := is_on_floor()
	if on_floor:
		_coyote = tuning.coyote_time
		_air_jumps = tuning.air_jumps
		_track_safe_ground(delta)
	else:
		_coyote = maxf(0.0, _coyote - delta)
	_buffer = tuning.jump_buffer if input.jump_pressed else maxf(0.0, _buffer - delta)

	# Speed: cruise ramps up; throttle and boost scale it.
	cruise_speed = minf(tuning.max_speed, cruise_speed + tuning.speed_ramp * delta)
	var target := cruise_speed * (1.0 + input.move_x * tuning.throttle) * _slow
	if _boost_left > 0.0:
		_boost_left -= delta
		target = cruise_speed * tuning.boost_multiplier
		if _boost_left <= 0.0:
			ram.set_deferred(&"monitoring", false)
			if state == State.BOOST:
				state = State.RIDE
	velocity.x = move_toward(velocity.x, target, tuning.acceleration * (3.0 if _boost_left > 0.0 else 1.0) * delta)

	# Jumps.
	if _buffer > 0.0 and state != State.SUPER:
		if on_floor or _coyote > 0.0:
			_jump(tuning.jump_velocity)
		elif _air_jumps > 0:
			_air_jumps -= 1
			double_jumps += 1
			_jump(tuning.double_jump_velocity)
			Vfx.spawn(get_tree(), jump_effect, global_position + Vector3(0, 0.2, 0), 0.8, {&"color": Palette.PLAYER_ENERGY})
	if not input.jump_held and velocity.y > 0.0 and not _jump_cut_done:
		velocity.y *= tuning.jump_cut
		_jump_cut_done = true
	var g := tuning.gravity_up if velocity.y > 0.0 and input.jump_held else tuning.gravity_down
	if input.down and not on_floor:
		g *= 1.6  # fast-fall
	velocity.y = maxf(velocity.y - g * delta, -tuning.max_fall_speed)

	# Duck (ground only).
	var want_duck := input.down and on_floor
	if want_duck != ducking:
		ducking = want_duck
		_apply_height(tuning.duck_height if ducking else tuning.stand_height)

	# Boost.
	if input.dash_pressed and _boost_cooldown <= 0.0 and state != State.SUPER:
		_boost_left = tuning.boost_duration
		_boost_cooldown = tuning.boost_duration + tuning.boost_cooldown
		_invulnerable_left = maxf(_invulnerable_left, tuning.boost_duration + 0.1)
		ram.set_deferred(&"monitoring", true)
		state = State.BOOST
		boosts += 1
		var camera := GameplayCamera.find(get_tree())
		if camera:
			camera.add_trauma(0.12)

	if input.special_pressed and RunSession.super_ready() and state != State.SUPER:
		_fire_super()

	arsenal.facing = 1.0
	arsenal.tick(delta, input.fire)

	_move()
	if state != State.BOOST and state != State.SUPER:
		state = State.RIDE if is_on_floor() else State.AIR
	if global_position.y < kill_y:
		_fall_into_gap()
	_update_invulnerability()
	_update_visuals(delta)


## Boost/jump pads call this.
func launch(vertical_speed: float) -> void:
	velocity.y = vertical_speed
	_jump_cut_done = true
	_air_jumps = tuning.air_jumps
	Vfx.spawn(get_tree(), jump_effect, global_position, 1.2, {&"color": Palette.INTERACTABLE})


func _jump(speed: float) -> void:
	velocity.y = speed
	_buffer = 0.0
	_coyote = 0.0
	_jump_cut_done = false
	if ducking:
		ducking = false
		_apply_height(tuning.stand_height)


func _apply_height(height: float) -> void:
	_body_box.size.y = height
	body_shape.position.y = height * 0.5
	_hurt_box.size.y = height - 0.2
	_hurt_shape.position.y = height * 0.5


func _move() -> void:
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0


func _track_safe_ground(delta: float) -> void:
	_safe_timer += delta
	if _safe_timer > 0.3:
		_last_safe = global_position
		_safe_timer = 0.0


func _fall_into_gap() -> void:
	health.invulnerable = false
	var payload := DamagePayload.create(1, Teams.Team.NEUTRAL)
	payload.damage_type = &"pit"
	health.apply_damage(payload, self)
	if not health.is_depleted():
		teleport(safe_position())
		_invulnerable_left = tuning.hit_invulnerability


func teleport(to: Vector3) -> void:
	global_position = Vector3(to.x, to.y, 0.0)
	velocity = Vector3(cruise_speed * 0.5, 0, 0)
	_boost_left = 0.0
	var camera := GameplayCamera.find(get_tree())
	if camera and camera.follow_target == self:
		camera.snap_to_target()


func _fire_super() -> void:
	RunSession.spend_energy(RunSession.MAX_ENERGY)
	state = State.SUPER
	_super_left = tuning.super_duration
	_invulnerable_left = maxf(_invulnerable_left, tuning.super_duration + 0.2)
	var root := get_tree().get_first_node_in_group(Vfx.ROOT_GROUP)
	if root:
		root.add_child(PlayerBeam.create(muzzle, 1.0, tuning.super_duration))
	super_fired.emit()


func respawn(at: Vector3) -> void:
	visible = true
	state = State.RIDE
	health.revive()
	hurtbox.set_deferred(&"monitorable", true)
	cruise_speed = maxf(tuning.start_speed, cruise_speed * 0.85)
	teleport(at)
	_last_safe = at
	_invulnerable_left = tuning.respawn_invulnerability
	flash.flash(tuning.respawn_invulnerability)
	respawned.emit()


func set_cinematic(enabled: bool) -> void:
	if state == State.DISABLED:
		return
	state = State.CINEMATIC if enabled else State.RIDE


func collect_echo(echo_id: StringName) -> void:
	var data := EchoModules.get_data(echo_id)
	if data == null:
		return
	RunSession.equip_echo(echo_id, data.ammo)
	Vfx.spawn(get_tree(), COLLECT_EFFECT, global_position + Vector3(0, 1.0, 0), 1.0, {&"color": data.module_color})
	echo_collected.emit(echo_id)


func can_collect() -> bool:
	return state != State.DISABLED


func tutorial_steps() -> Array[Dictionary]:
	return [
		{"id": "mech_jump", "text": "JUMP — PRESS AGAIN TO DOUBLE JUMP", "key": "SPACE", "pad": "A", "hold": 0.0},
		{"id": "bike_duck", "text": "HOLD TO DUCK UNDER BEAMS", "key": "S", "pad": "DOWN", "hold": 0.3},
		{"id": "bike_boost", "text": "BOOST — SMASH THROUGH CRATES", "key": "K", "pad": "B", "hold": 0.0},
		{"id": "super", "text": "SUPER READY — UNLEASH IT", "key": "I", "pad": "RB", "hold": 0.0, "when": "super_ready"},
	]


func grant_invulnerability(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)
	_update_invulnerability()


func is_invulnerable() -> bool:
	return health.invulnerable


## Respawn point after a fall or death.
## Uses the track's recovery point (next deck past the gap) when a runner track exists.
func safe_position() -> Vector3:
	var track := get_tree().get_first_node_in_group(&"runner_track")
	if track and track.has_method(&"recovery_point"):
		return track.call(&"recovery_point", global_position.x)
	return _last_safe + Vector3(0, 0.5, 0)


func is_boosting() -> bool:
	return _boost_left > 0.0


func get_debug_lines() -> PackedStringArray:
	return PackedStringArray([
		"BIKE %s  vel (%.1f, %.1f)  cruise %.1f  duck %s  boost cd %.2f" % [State.keys()[state], velocity.x, velocity.y, cruise_speed, ducking, _boost_cooldown],
	])


func _update_invulnerability() -> void:
	health.invulnerable = _invulnerable_left > 0.0 or state in [State.DISABLED, State.CINEMATIC, State.SUPER]


func _update_visuals(delta: float) -> void:
	var pose := BikeModel.Pose.RIDE
	if state == State.BOOST:
		pose = BikeModel.Pose.BOOST
	elif ducking:
		pose = BikeModel.Pose.DUCK
	elif not is_on_floor():
		pose = BikeModel.Pose.AIR
	elif _slow < 0.8:
		pose = BikeModel.Pose.HIT
	model.update_pose(pose, velocity.x, clampf(velocity.x / tuning.max_speed, 0.0, 1.0), delta)


func _on_damaged(payload: DamagePayload, _source: Node) -> void:
	_invulnerable_left = tuning.hit_invulnerability
	flash.flash(tuning.hit_invulnerability)
	var camera := GameplayCamera.find(get_tree())
	if camera:
		camera.add_trauma(ArtStyle.SHAKE_PLAYER_HIT)
	if health.is_depleted() or payload.damage_type == &"pit":
		return
	_slow = tuning.hit_slowdown
	velocity.x *= tuning.hit_slowdown
	_update_invulnerability()


func _on_depleted(_source: Node) -> void:
	state = State.DISABLED
	visible = false
	velocity = Vector3.ZERO
	flash.stop()
	RunSession.clear_echo()
	ram.set_deferred(&"monitoring", false)
	hurtbox.set_deferred(&"monitorable", false)
	_update_invulnerability()
	Vfx.spawn(get_tree(), death_effect, global_position + Vector3(0, 1.0, 0), 1.8)
	var root := get_tree().get_first_node_in_group(Vfx.ROOT_GROUP)
	if root:
		root.add_child(FragmentBurst.create(model.make_fragments(), global_position + Vector3(0, 1.0, 0)))
	HitStop.trigger(get_tree(), 0.09)
	died.emit()
