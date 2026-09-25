class_name HullRider
extends CharacterBody3D
## Kestrel in bike form on the warship's top hull, seen from behind (3D chase view).
## Rides forward (+X) on its own; steer across the deck (Z), jump / double jump, boost (Dash:
## speed + i-frames + ram, with a sidestep roll when steering), hold-to-fire twin cannons
## with light aim assist, SUPER beam down the track. Echo weapons carry over:
## BURST = 5-way fan, ARC = strong homing, GUARD = heavy twin bolts.
## The camera is driven by the director, not by the rider.

signal died
signal respawned
signal super_fired
signal echo_collected(echo_id: StringName)

enum State { RIDE, AIR, BOOST, SUPER, DISABLED, CINEMATIC }

const GROUP := Players.GROUP
const TARGET_GROUP := &"run_enemies"
const TRACK_GROUP := &"hull_track"

@export var tuning: HullRiderTuning
@export var model: BikeModel
@export var health: HealthComponent
@export var hurtbox: HurtboxComponent
@export var flash: FlashComponent
@export var muzzle: Node3D
@export var ram: HitboxComponent
@export var death_effect_size: float = 2.2
@export var read_devices: bool = true
@export var kill_y: float = 20.0

var state: State = State.RIDE
var facing: float = 1.0
var aim_offset: Vector3 = Vector3(0, 0.9, 0)
var cruise_speed: float = 0.0
var double_jumps: int = 0
var boosts: int = 0
var shots_fired: int = 0

var _coyote: float = 0.0
var _buffer: float = 0.0
var _air_jumps: int = 0
var _jump_cut_done: bool = true
var _boost_left: float = 0.0
var _boost_cooldown: float = 0.0
var _invulnerable_left: float = 0.0
var _slow: float = 1.0
var _super_left: float = 0.0
var _fire_cooldown: float = 0.0
var _gun_side: float = 1.0
var _roll: float = 0.0
var _roll_spin: float = 0.0
var _last_safe: Vector3 = Vector3.ZERO
var _lock_target: Node3D
var _reticle: MeshInstance3D
var _muzzle_flash: MeshInstance3D
var _flash_energy: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"debug_telemetry")
	collision_layer = PhysicsLayers.ACTOR
	collision_mask = PhysicsLayers.WORLD
	floor_snap_length = 0.5
	cruise_speed = tuning.start_speed
	health.health_changed.connect(func(current: int, _m: int) -> void: RunSession.set_health(current))
	health.damaged.connect(_on_damaged)
	health.depleted.connect(_on_depleted)
	var start_health := RunSession.health if RunSession.health > 0 else RunSession.max_health
	health.setup(RunSession.max_health, start_health)
	ram.payload = DamagePayload.create(tuning.ram_damage, Teams.Team.PLAYER)
	ram.single_hit = false
	ram.continuous = true
	ram.set_physics_process(true)
	ram.set_deferred(&"monitoring", false)
	_last_safe = global_position
	# Muzzle flash and a lock-on reticle that frames the enemy the guns are bending toward.
	_muzzle_flash = MeshInstance3D.new()
	_muzzle_flash.mesh = QuadMesh.new()
	_muzzle_flash.material_override = ModelKit.glow_billboard(Palette.PLAYER_ENERGY.lerp(Color.WHITE, 0.4), 0.0)
	_muzzle_flash.scale = Vector3.ONE * 1.6
	muzzle.add_child(_muzzle_flash)
	_reticle = MeshInstance3D.new()
	_reticle.mesh = QuadMesh.new()
	_reticle.material_override = ModelKit.glow_billboard(Palette.UI_GOLD, 0.0, ModelKit.GlowShape.RING)
	_reticle.top_level = true
	_reticle.scale = Vector3.ONE * 4.5
	add_child(_reticle)


func _physics_process(delta: float) -> void:
	if read_devices:
		tick(delta, MechInput.from_devices())


func tick(delta: float, input: MechInput) -> void:
	_invulnerable_left = maxf(0.0, _invulnerable_left - delta)
	_boost_cooldown = maxf(0.0, _boost_cooldown - delta)
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_slow = move_toward(_slow, 1.0, delta / tuning.hit_recovery)
	match state:
		State.DISABLED:
			_update_invulnerability()
			return
		State.CINEMATIC:
			velocity.y -= tuning.gravity_down * delta
			velocity.z = move_toward(velocity.z, 0.0, tuning.lateral_accel * delta)
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
		_last_safe = global_position
	else:
		_coyote = maxf(0.0, _coyote - delta)
	_buffer = tuning.jump_buffer if input.jump_pressed else maxf(0.0, _buffer - delta)

	# Forward: cruise ramps up; throttle, boost and hits scale it.
	cruise_speed = minf(tuning.max_speed, cruise_speed + tuning.speed_ramp * delta)
	var throttle := 0.0
	if input.down:
		throttle = -1.0
	var target := cruise_speed * (1.0 + throttle * tuning.throttle) * _slow
	if _boost_left > 0.0:
		_boost_left -= delta
		target = cruise_speed * tuning.boost_multiplier
		if _boost_left <= 0.0:
			ram.set_deferred(&"monitoring", false)
			if state == State.BOOST:
				state = State.RIDE
	velocity.x = move_toward(velocity.x, target, tuning.acceleration * (3.0 if _boost_left > 0.0 else 1.0) * delta)

	# Steering across the deck.
	var lateral_target := input.move_x * tuning.lateral_speed
	velocity.z = move_toward(velocity.z, lateral_target, tuning.lateral_accel * delta)
	if absf(global_position.z) > tuning.lane_half_width and signf(velocity.z) == signf(global_position.z):
		velocity.z = 0.0
		global_position.z = clampf(global_position.z, -tuning.lane_half_width, tuning.lane_half_width)

	# Jumps.
	if _buffer > 0.0 and state != State.SUPER:
		if on_floor or _coyote > 0.0:
			_jump(tuning.jump_velocity)
			AudioService.play(&"jump")
		elif _air_jumps > 0:
			_air_jumps -= 1
			double_jumps += 1
			_jump(tuning.double_jump_velocity)
			AudioService.play(&"double_jump")
			Explosion3D.spawn(get_tree(), global_position, 0.35)
	if not input.jump_held and velocity.y > 0.0 and not _jump_cut_done:
		velocity.y *= tuning.jump_cut
		_jump_cut_done = true
	var g := tuning.gravity_up if velocity.y > 0.0 and input.jump_held else tuning.gravity_down
	velocity.y = maxf(velocity.y - g * delta, -tuning.max_fall_speed)

	# Boost (+ sidestep roll when steering).
	if input.dash_pressed and _boost_cooldown <= 0.0 and state != State.SUPER:
		_boost_left = tuning.boost_duration
		_boost_cooldown = tuning.boost_duration + tuning.boost_cooldown
		_invulnerable_left = maxf(_invulnerable_left, tuning.boost_duration + 0.1)
		ram.set_deferred(&"monitoring", true)
		state = State.BOOST
		boosts += 1
		AudioService.play(&"boost")
		if absf(input.move_x) > 0.3:
			velocity.z = signf(input.move_x) * tuning.roll_impulse
			_roll_spin = signf(input.move_x) * TAU
		var camera := GameplayCamera.find(get_tree())
		if camera:
			camera.add_trauma(0.15)

	if input.special_pressed and RunSession.super_ready() and state != State.SUPER:
		_fire_super()
	if input.fire and _fire_cooldown <= 0.0 and state != State.SUPER:
		_fire()

	_move()
	if state != State.BOOST and state != State.SUPER:
		state = State.RIDE if is_on_floor() else State.AIR
	if global_position.y < kill_y:
		_fall_into_gap()
	_update_invulnerability()
	_update_visuals(delta)
	_update_lock(delta)


## Jump pads call this.
func launch(vertical_speed: float) -> void:
	velocity.y = vertical_speed
	_jump_cut_done = true
	_air_jumps = tuning.air_jumps
	Explosion3D.spawn(get_tree(), global_position, 0.6)


func _jump(speed: float) -> void:
	velocity.y = speed
	_buffer = 0.0
	_coyote = 0.0
	_jump_cut_done = false


func _move() -> void:
	move_and_slide()


func _fire() -> void:
	var echo := RunSession.selected_echo
	var interval := tuning.fire_interval
	var from := muzzle.global_position + Vector3(0, 0, 0.35 * _gun_side)
	_gun_side = -_gun_side
	var aim := _assist_direction(from, tuning.assist_angle * (2.2 if echo == EchoModules.ARC else 1.0))
	# Bolts inherit the bike's speed so they always pull away from it.
	var carry := Vector3(velocity.x, 0, 0)
	match echo:
		EchoModules.BURST:
			for k in 5:
				var spread := deg_to_rad((k - 2) * 7.0)
				Bolt3D.fire(get_tree(), Teams.Team.PLAYER, 1, from, aim.rotated(Vector3.UP, spread) * tuning.bolt_speed + carry, Color("ffb454"), 0.3)
			interval *= 2.2
			RunSession.consume_echo_ammo(1)
		EchoModules.ARC:
			Bolt3D.fire(get_tree(), Teams.Team.PLAYER, 2, from, aim * tuning.bolt_speed * 1.2 + carry, Color("9f8bff"), 0.35)
			RunSession.consume_echo_ammo(1)
		EchoModules.GUARD:
			for side: float in [-1.0, 1.0]:
				Bolt3D.fire(get_tree(), Teams.Team.PLAYER, 2, from + Vector3(0, 0, 0.6 * side), aim * tuning.bolt_speed + carry, Color("7dffb2"), 0.5)
			interval *= 1.4
			RunSession.consume_echo_ammo(1)
		_:
			Bolt3D.fire(get_tree(), Teams.Team.PLAYER, 1, from, aim * tuning.bolt_speed + carry, Palette.PLAYER_ENERGY, 0.3)
	shots_fired += 1
	_flash_energy = 2.4
	_fire_cooldown = interval
	model.shoot_kick()


## Forward, bent toward the nearest enemy inside the assist cone.
func _assist_direction(from: Vector3, angle_deg: float) -> Vector3:
	var best := Vector3.RIGHT
	var best_d := tuning.assist_range
	var cos_limit := cos(deg_to_rad(angle_deg))
	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		var enemy := node as Node3D
		if enemy == null or not enemy.has_method(&"is_alive") or not enemy.call(&"is_alive"):
			continue
		var to := enemy.global_position - from
		var d := to.length()
		if d < 4.0 or d > best_d:
			continue
		var dir := to / d
		if dir.dot(Vector3.RIGHT) >= cos_limit:
			best = dir
			best_d = d
			_lock_target = enemy
	return best


func _fall_into_gap() -> void:
	health.invulnerable = false
	var payload := DamagePayload.create(1, Teams.Team.NEUTRAL)
	payload.damage_type = &"pit"
	health.apply_damage(payload, self)
	if not health.is_depleted():
		teleport(safe_position())
		_invulnerable_left = tuning.hit_invulnerability


## Recovery point after a fall or death (the track knows where the next safe deck is).
func safe_position() -> Vector3:
	var track := get_tree().get_first_node_in_group(TRACK_GROUP)
	if track and track.has_method(&"recovery_point"):
		return track.call(&"recovery_point", global_position.x, global_position.z)
	return _last_safe + Vector3(0, 0.5, 0)


func teleport(to: Vector3) -> void:
	global_position = to
	velocity = Vector3(cruise_speed * 0.6, 0, 0)
	_boost_left = 0.0


func _fire_super() -> void:
	AudioService.play(&"charge")
	RunSession.spend_energy(RunSession.MAX_ENERGY)
	state = State.SUPER
	_super_left = tuning.super_duration
	_invulnerable_left = maxf(_invulnerable_left, tuning.super_duration + 0.2)
	var root := get_tree().get_first_node_in_group(Vfx.ROOT_GROUP)
	if root:
		root.add_child(ForwardBeam.create(muzzle, tuning.super_duration))
	super_fired.emit()


func respawn(at: Vector3) -> void:
	visible = true
	state = State.RIDE
	health.revive()
	hurtbox.set_deferred(&"monitorable", true)
	cruise_speed = maxf(tuning.start_speed, cruise_speed * 0.9)
	teleport(at)
	_invulnerable_left = tuning.respawn_invulnerability
	flash.flash(tuning.respawn_invulnerability)
	respawned.emit()


func in_cinematic() -> bool:
	return state == State.CINEMATIC


func set_cinematic(enabled: bool) -> void:
	if state == State.DISABLED:
		return
	state = State.CINEMATIC if enabled else State.RIDE


func collect_echo(echo_id: StringName) -> void:
	var data := EchoModules.get_data(echo_id)
	if data == null:
		return
	RunSession.equip_echo(echo_id, data.ammo)
	echo_collected.emit(echo_id)


func can_collect() -> bool:
	return state != State.DISABLED


func tutorial_steps() -> Array[Dictionary]:
	return [
		{"id": "hull_steer", "text": "STEER ACROSS THE HULL", "key": "A D", "pad": "L-STICK", "hold": 0.5},
		{"id": "fire", "text": "HOLD TO FIRE", "key": "J", "pad": "RT", "hold": 1.0},
		{"id": "mech_jump", "text": "JUMP — PRESS AGAIN TO DOUBLE JUMP", "key": "SPACE", "pad": "A", "hold": 0.0},
		{"id": "hull_boost", "text": "BOOST — STEER + BOOST TO ROLL", "key": "K", "pad": "B", "hold": 0.0},
		{"id": "super", "text": "SUPER READY — UNLEASH IT", "key": "I", "pad": "RB", "hold": 0.0, "when": "super_ready"},
	]


func grant_invulnerability(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)
	_update_invulnerability()


func is_invulnerable() -> bool:
	return health.invulnerable


func is_boosting() -> bool:
	return _boost_left > 0.0


func get_debug_lines() -> PackedStringArray:
	return PackedStringArray([
		"HULL RIDER %s  vel (%.1f, %.1f, %.1f)  cruise %.1f  boost cd %.2f" % [State.keys()[state], velocity.x, velocity.y, velocity.z, cruise_speed, _boost_cooldown],
	])


func _update_invulnerability() -> void:
	health.invulnerable = _invulnerable_left > 0.0 or state in [State.DISABLED, State.CINEMATIC, State.SUPER]


func _update_lock(delta: float) -> void:
	_lock_target = null
	_assist_direction(muzzle.global_position, tuning.assist_angle)
	var mat := _reticle.material_override as ShaderMaterial
	if is_instance_valid(_lock_target):
		_reticle.global_position = _lock_target.global_position
		_reticle.rotation.z += delta * 3.0
		mat.set_shader_parameter(&"energy", 1.4)
	else:
		mat.set_shader_parameter(&"energy", 0.0)
	_flash_energy = maxf(0.0, _flash_energy - delta * 22.0)
	(_muzzle_flash.material_override as ShaderMaterial).set_shader_parameter(&"energy", _flash_energy)


func _update_visuals(delta: float) -> void:
	var pose := BikeModel.Pose.RIDE
	if state == State.BOOST:
		pose = BikeModel.Pose.BOOST
	elif not is_on_floor():
		pose = BikeModel.Pose.AIR
	elif _slow < 0.8:
		pose = BikeModel.Pose.HIT
	model.update_pose(pose, velocity.x, clampf(velocity.x / tuning.max_speed, 0.0, 1.0), delta)
	# Bank into turns; the boost roll spins a full turn.
	_roll = lerpf(_roll, -velocity.z / tuning.lateral_speed * 0.45, clampf(delta * 8.0, 0.0, 1.0))
	if absf(_roll_spin) > 0.01:
		var step := signf(_roll_spin) * minf(absf(_roll_spin), delta * 16.0)
		_roll_spin -= step
	model.rotation.x = _roll - _roll_spin


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
	AudioService.play(&"player_death")
	visible = false
	velocity = Vector3.ZERO
	flash.stop()
	RunSession.clear_echo()
	ram.set_deferred(&"monitoring", false)
	hurtbox.set_deferred(&"monitorable", false)
	_update_invulnerability()
	Explosion3D.spawn(get_tree(), global_position + Vector3(0, 0.8, 0), death_effect_size, ArtStyle.SHAKE_MAJOR)
	HitStop.trigger(get_tree(), 0.09)
	died.emit()
