class_name SentinelBoss
extends BossBase
## Stage 2 mid-boss: a heavy security walker guarding the warship's inner bulkhead.
## Mega Man-style pattern boss in a sealed room: aimed VOLLEY (stand and dodge), LEAP onto the
## player with a floor SHOCKWAVE both ways (jump it), and a telegraphed wall-to-wall DASH (jump
## over it). Every attack is readable and the charge shot is the reward for patience.

const SHOCK_SPEED := 11.0
const DASH_SPEED := 22.0
const LEAP_TIME := 0.9
const LEAP_HEIGHT := 7.0

@export var weapon: WeaponComponent
@export var ground_weapon: WeaponComponent
@export var contact: HitboxComponent
## Arena walls (inner faces) and floor, set by the MidBossZone before the boss enters the tree.
@export var arena_left: float = 248.0
@export var arena_right: float = 268.0
@export var floor_y: float = 0.0

var facing: float = -1.0

var _model: Node3D
var _legs: Array[Node3D] = []
var _eye_mat: StandardMaterial3D
var _cannon: Node3D
var _fired: int = 0
var _leap_from: Vector3
var _leap_to: Vector3
var _landed: bool = false
var _dash_dir: float = -1.0
var _walk_phase: float = 0.0


func _ready() -> void:
	_build_model()
	super._ready()


func _home() -> Vector3:
	return Vector3(arena_right - 3.5, floor_y, 0.0)


func _phase_attacks(phase: int) -> Array[StringName]:
	match phase:
		1:
			return [&"volley", &"leap"]
		2:
			return [&"volley", &"dash", &"leap"]
		3:
			return [&"dash", &"leap", &"volley", &"leap"]
	return []


func _attack_duration(attack: StringName, first_use: bool) -> float:
	var slow := 1.25 if first_use else 1.0
	match attack:
		&"volley":
			return (1.8 if phase_number() < 3 else 1.5) * slow
		&"leap":
			return LEAP_TIME + 0.9
		&"dash":
			return 0.7 * slow + (arena_right - arena_left) / DASH_SPEED + 0.4
	return 2.0


func _attack_begin(attack: StringName, first_use: bool) -> void:
	_fired = 0
	_face_player()
	match attack:
		&"leap":
			_landed = false
			_leap_from = global_position
			var target_x := clampf(_player_position().x, arena_left + 1.5, arena_right - 1.5)
			_leap_to = Vector3(target_x, floor_y, 0)
			AudioService.play(&"jump")
		&"dash":
			_dash_dir = facing
			_eye_mat.emission_energy_multiplier = 6.0
			AudioService.play(&"charge")
	if first_use:
		_telegraph_flash()


func _attack_update(attack: StringName, time: float, delta: float) -> void:
	match attack:
		&"volley":
			_face_player()
			var shots := 3 if phase_number() == 1 else 5
			var start := 0.45
			var gap := 0.28 if phase_number() < 3 else 0.2
			if _fired < shots and time >= start + _fired * gap:
				_fired += 1
				weapon.fire_at(_aim_at_player(weapon.global_position))
				_cannon.position.x = 0.25
		&"leap":
			var t := clampf(time / LEAP_TIME, 0.0, 1.0)
			var pos := _leap_from.lerp(_leap_to, t)
			pos.y = floor_y + sin(t * PI) * LEAP_HEIGHT
			global_position = pos
			if t >= 1.0 and not _landed:
				_landed = true
				_land_shockwave()
		&"dash":
			var windup := 0.7 * (1.25 if _current_first_use else 1.0)
			if time < windup:
				# Rev in place: shake + glowing eye.
				_model.position.x = sin(time * 60.0) * 0.08
				return
			_model.position.x = 0.0
			global_position.x += _dash_dir * DASH_SPEED * delta
			if global_position.x <= arena_left + 1.2 or global_position.x >= arena_right - 1.2:
				global_position.x = clampf(global_position.x, arena_left + 1.2, arena_right - 1.2)
				if _eye_mat.emission_energy_multiplier > 3.0:
					_eye_mat.emission_energy_multiplier = 3.0
					_camera_shake(0.35)
					AudioService.play(&"heavy_land")
					facing = -_dash_dir


func _on_state_entered(new_state: State) -> void:
	if new_state == State.PHASE_1:
		_camera_shake(0.5)
		AudioService.play(&"heavy_land")
	if new_state == State.DEFEATED:
		contact.set_deferred(&"monitoring", false)


func _animate(delta: float) -> void:
	if state == State.INTRO:
		# Drops in from above instead of sliding in.
		var t := clampf(_state_time / intro_time, 0.0, 1.0)
		global_position = _home() + Vector3(0, 16.0 * pow(1.0 - minf(1.0, t * 1.6), 2.0), 0)
	_model.scale.x = -facing
	_cannon.position.x = move_toward(_cannon.position.x, 0.0, delta * 1.5)
	var moving := current_attack == &"dash" and _model.position.x == 0.0
	_walk_phase += delta * (14.0 if moving else 2.0)
	for i in _legs.size():
		_legs[i].rotation.z = sin(_walk_phase + i * PI) * (0.5 if moving else 0.04)
	var hot := is_attackable() or state == State.INTRO
	if contact.monitoring != hot:
		contact.set_deferred(&"monitoring", hot)


func _land_shockwave() -> void:
	_camera_shake(0.45)
	AudioService.play(&"heavy_land")
	Vfx.spawn(get_tree(), preload("res://vfx/explosion.tscn"), global_position + Vector3(0, 0.3, 1), 1.2)
	for dir: float in [-1.0, 1.0]:
		ground_weapon.fire_at(Vector3(dir, 0, 0))
	if phase_number() == 3:
		weapon.fire_at(_aim_at_player(weapon.global_position))


func _face_player() -> void:
	var dx := _player_position().x - global_position.x
	if absf(dx) > 0.3:
		facing = signf(dx)


func _telegraph_flash() -> void:
	var tween := create_tween()
	_eye_mat.emission_energy_multiplier = 7.0
	tween.tween_property(_eye_mat, ^"emission_energy_multiplier", 3.0, 0.5)


func _camera_shake(amount: float) -> void:
	if _camera:
		_camera.add_trauma(amount)


## Heavy biped (~3.6 tall, faces -X): armoured crimson/gunmetal hull turned three-quarters to
## the camera, a hunched head with a mono-eye rail, a shoulder cannon, a shield pauldron, pistoned
## digitigrade legs with clawed feet, glowing vents and a reactor pack on its back.
func _build_model() -> void:
	_model = ModelKit.group(self, "Model")
	var rig := ModelKit.group(_model, "Rig")
	rig.rotation.y = 0.4
	var t := ArtStyle.OUTLINE_THIN
	var armor := ModelKit.hull(Color("b8323c"), ArtStyle.OUTLINE_THICK, 0.3)
	var armor_thin := ModelKit.hull(Color("b8323c"), t, 0.3)
	var steel := ModelKit.hull(Color("565c74"), t, 0.4)
	var dark := ModelKit.hull(Color("262a3a"), t, 0.3)
	var gold := ModelKit.glossy(Palette.ECHO_GOLD)
	ModelKit.with_outline(gold, t)
	var vent := ModelKit.emissive(Color("ff7a3a"), 2.4)
	_eye_mat = ModelKit.emissive(EnemyModel.SENSOR, 3.0)
	for i in 2:
		var z := 0.5 if i == 0 else -0.5
		var hip := ModelKit.group(rig, "Leg", Vector3(0.1, 1.85, z))
		ModelKit.sphere(hip, 0.28, Vector3.ZERO, dark)
		# Thigh angled back, knee forward, shin angled back to the ankle (digitigrade).
		ModelKit.box(hip, Vector3(0.6, 0.95, 0.5), Vector3(0.18, -0.42, 0), armor_thin, Vector3(0, 0, -22))
		ModelKit.box(hip, Vector3(0.1, 0.7, 0.52), Vector3(-0.1, -0.4, 0), gold, Vector3(0, 0, -22))
		ModelKit.sphere(hip, 0.22, Vector3(0.36, -0.88, 0), steel)
		ModelKit.box(hip, Vector3(0.42, 0.9, 0.42), Vector3(0.22, -1.28, 0), steel, Vector3(0, 0, 18))
		ModelKit.cylinder(hip, 0.06, 0.06, 0.9, Vector3(0.45, -1.25, 0.24 * signf(z)), dark, Vector3(0, 0, 18), 8)
		ModelKit.box(hip, Vector3(0.22, 0.5, 0.44), Vector3(0.42, -1.3, 0), armor_thin, Vector3(0, 0, 18))
		# Clawed foot.
		ModelKit.box(hip, Vector3(1.1, 0.22, 0.6), Vector3(-0.05, -1.73, 0), dark)
		for c in 2:
			ModelKit.prism(hip, Vector3(0.2, 0.36, 0.18), Vector3(-0.64, -1.74, (c - 0.5) * 0.3), steel, Vector3(0, 0, 90))
		_legs.append(hip)
	var torso := ModelKit.group(rig, "Torso", Vector3(0, 2.55, 0))
	ModelKit.box(torso, Vector3(1.9, 1.3, 1.5), Vector3(0.05, 0, 0), armor)
	ModelKit.prism(torso, Vector3(0.5, 1.1, 1.46), Vector3(-1.05, -0.05, 0), armor_thin, Vector3(0, 0, 90))
	ModelKit.box(torso, Vector3(1.94, 0.24, 1.54), Vector3(0.05, -0.6, 0), dark)
	ModelKit.box(torso, Vector3(1.2, 0.2, 1.56), Vector3(0.1, 0.7, 0), gold)
	for k in 4:
		ModelKit.box(torso, Vector3(0.06, 0.5, 0.05), Vector3(-0.3 + k * 0.2, -0.1, 0.77), vent)
	# Reactor pack on the back with exhaust stacks.
	ModelKit.box(torso, Vector3(0.7, 1.1, 1.1), Vector3(1.2, 0.1, 0), steel)
	for k in 2:
		ModelKit.cylinder(torso, 0.14, 0.16, 0.7, Vector3(1.35, 0.9, (k - 0.5) * 0.6), dark, Vector3.ZERO, 10)
		ModelKit.cylinder(torso, 0.1, 0.1, 0.02, Vector3(1.35, 1.26, (k - 0.5) * 0.6), vent, Vector3.ZERO, 10)
	# Hunched head: armoured brow over a sensor rail, jaw guard.
	var head := ModelKit.group(torso, "Head", Vector3(-0.8, 0.55, 0))
	ModelKit.box(head, Vector3(0.8, 0.5, 0.9), Vector3.ZERO, steel)
	ModelKit.prism(head, Vector3(0.3, 0.3, 0.92), Vector3(-0.5, 0.12, 0), armor_thin, Vector3(0, 0, 90))
	ModelKit.box(head, Vector3(0.12, 0.14, 0.8), Vector3(-0.45, -0.05, 0), dark)
	ModelKit.box(head, Vector3(0.1, 0.1, 0.7), Vector3(-0.5, -0.05, 0), _eye_mat)
	ModelKit.quad(head, Vector2.ONE * 1.3, Vector3(-0.55, -0.05, 0.55), ModelKit.glow(EnemyModel.SENSOR, 1.2))
	ModelKit.box(head, Vector3(0.5, 0.2, 0.7), Vector3(-0.15, -0.32, 0), armor_thin)
	# Shoulder cannon (camera side) on a turret mount; shield pauldron on the far side.
	ModelKit.sphere(torso, 0.42, Vector3(0.1, 0.6, 0.85), steel)
	_cannon = ModelKit.group(torso, "Cannon", Vector3(0, 0.6, 0.95))
	_cannon.rotation.y = -0.4
	ModelKit.box(_cannon, Vector3(0.9, 0.5, 0.5), Vector3(-0.1, 0, 0), armor_thin)
	ModelKit.hex_x(_cannon, 0.22, 1.6, Vector3(-0.9, 0.05, 0.08), steel, 10)
	ModelKit.hex_x(_cannon, 0.18, 1.6, Vector3(-0.9, -0.12, -0.12), dark, 10)
	ModelKit.hex_x(_cannon, 0.3, 0.22, Vector3(-1.7, 0.0, 0), gold, 10)
	ModelKit.cylinder(_cannon, 0.14, 0.14, 0.02, Vector3(-1.82, 0.0, 0), vent, Vector3(0, 0, 90), 10)
	ModelKit.box(torso, Vector3(1.2, 1.0, 0.25), Vector3(0.1, 0.25, -0.95), armor, Vector3(0, 0, -8))
	ModelKit.box(torso, Vector3(1.0, 0.1, 0.27), Vector3(0.1, -0.15, -0.96), gold, Vector3(0, 0, -8))
