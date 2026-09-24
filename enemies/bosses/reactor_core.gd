class_name ReactorCore
extends BossBase
## Stage 2 boss: the warship's reactor. Its shield plates close while it attacks and open
## between attacks — that is the damage window (time the SUPER beam for it).
## Tests the mech verbs: jump the low sweep, stay low under the high sweep, read falling rain,
## hop through ring gaps, clear summoned drones.

@export var weapon: WeaponComponent
@export var summon_scene: PackedScene
## Floor height of the arena (beam lanes are measured from it).
@export var floor_y: float = 0.0

var _plates: Array[Node3D] = []
var _core_glow: MeshInstance3D
var _core_mat: StandardMaterial3D
var _open: float = 0.0
var _spin: float = 0.0
var _fired: int = 0
var _rain_x: Array[float] = []
var _markers: Array[MeshInstance3D] = []


func _ready() -> void:
	_build_model()
	super._ready()


func _core_exposed() -> bool:
	return current_attack == &""


func _phase_attacks(phase: int) -> Array[StringName]:
	match phase:
		1:
			return [&"low_sweep", &"ring", &"high_sweep", &"rain"]
		2:
			return [&"double_sweep", &"rain", &"drones", &"ring", &"low_sweep"]
		3:
			return [&"double_sweep", &"rain", &"ring", &"high_sweep", &"drones"]
	return []


func _attack_duration(attack: StringName, first_use: bool) -> float:
	var slow := 1.3 if first_use else 1.0
	match attack:
		&"low_sweep", &"high_sweep":
			return 2.2 * slow
		&"double_sweep":
			return 3.0 * slow
		&"ring":
			return 2.2
		&"rain":
			return 3.0 * slow
		&"drones":
			return 1.4
	return 2.0


func _attack_begin(attack: StringName, first_use: bool) -> void:
	_fired = 0
	var warn := 1.25 if first_use else 1.0
	match attack:
		&"low_sweep":
			_spawn_beam(floor_y + 0.8, warn, 0.6, Palette.RESONANCE_VIOLET, 1.1)
		&"high_sweep":
			_spawn_beam(floor_y + 3.6, warn, 0.7, Palette.RESONANCE_VIOLET, 1.8)
		&"double_sweep":
			_spawn_beam(floor_y + 0.8, warn, 0.55, Palette.RESONANCE_VIOLET, 1.1)
			_spawn_beam(floor_y + 3.6, warn + 1.0, 0.6, Color(1.0, 0.55, 0.25), 1.8)
		&"rain":
			_start_rain(5 if phase_number() == 1 else 7)
		&"drones":
			if summon_scene and summon_root:
				for dy: float in [2.5, 5.5]:
					var drone := summon_scene.instantiate() as Node3D
					drone.position = Vector3(global_position.x - 3.0, floor_y + dy, 0)
					summon_root.add_child(drone)


func _attack_update(attack: StringName, time: float, _delta: float) -> void:
	match attack:
		&"ring":
			var rings := 2 if phase_number() < 3 else 3
			var due := mini(rings, 1 + int(time / 0.7))
			while _fired < due:
				var gap := atan2(_aim_at_player(global_position).y, _aim_at_player(global_position).x) + _fired * 0.5
				for i in 16:
					var a := TAU * i / 16.0
					if absf(wrapf(a - gap, -PI, PI)) < 0.5:
						continue
					weapon.fire_at(Vector3(cos(a), sin(a), 0), 0.65)
				_fired += 1
		&"rain":
			var drop_at := 1.1 if _current_first_use else 0.85
			if time >= drop_at and _fired == 0:
				_fired = 1
				var camera := GameplayCamera.find(get_tree())
				var top := camera.get_play_rect().end.y if camera else floor_y + 12.0
				for x in _rain_x:
					weapon.global_position = Vector3(x, top - 0.5, 0)
					weapon.fire_at(Vector3.DOWN, 1.1)
				weapon.position = Vector3(-1.6, 0, 0)
				for m in _markers:
					m.queue_free()
				_markers.clear()


## Telegraphed rain: glowing floor markers first, then shots fall on exactly those columns.
func _start_rain(count: int) -> void:
	_rain_x.clear()
	var camera := GameplayCamera.find(get_tree())
	var rect := camera.get_play_rect() if camera else Rect2(global_position.x - 14, floor_y, 28, 14)
	var player_x := _player_position().x
	for i in count:
		var x := lerpf(rect.position.x + 1.5, rect.end.x - 7.0, float(i) / float(count - 1))
		if i == count / 2:
			x = player_x
		_rain_x.append(x)
		var marker := ModelKit.quad(get_parent(), Vector2(1.2, 12.0), Vector3(x, floor_y + 6.0, -0.5), ModelKit.glow(Palette.HOSTILE_PROJECTILE, 0.6))
		_markers.append(marker)


func _on_state_entered(_new_state: State) -> void:
	for m in _markers:
		m.queue_free()
	_markers.clear()


func _animate(delta: float) -> void:
	var target := 1.0 if (_core_exposed() and is_attackable()) else 0.0
	_open = lerpf(_open, target, clampf(delta * 6.0, 0.0, 1.0))
	_spin += delta * (0.6 + phase_number() * 0.4) * (1.0 - _open * 0.7)
	for i in _plates.size():
		var a := _spin + TAU * i / _plates.size()
		var r := lerpf(1.7, 2.9, _open)
		_plates[i].position = Vector3(cos(a) * r, sin(a) * r, 0.6)
		_plates[i].rotation.z = a + PI * 0.5
	# Health invulnerability follows the shield every tick.
	health.invulnerable = not is_attackable() or not _core_exposed()
	if _core_mat:
		_core_mat.emission_energy_multiplier = lerpf(0.8, 3.5, _open) + 0.4 * sin(_state_time * 8.0)
	(_core_glow.material_override as ShaderMaterial).set_shader_parameter(&"energy", lerpf(0.3, 1.8, _open))


func _build_model() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	var frame := ModelKit.hull(Color("2e3a58"))
	var dark := ModelKit.hull(Color("151e33"), ArtStyle.OUTLINE_THIN)
	var coral := ModelKit.hull(Palette.ENEMY_CORAL)
	# Conduits to floor and ceiling.
	ModelKit.box(model, Vector3(1.2, 14.0, 1.4), Vector3(0, 0, -1.2), dark)
	for y: float in [-3.4, 3.4]:
		ModelKit.box(model, Vector3(3.4, 0.7, 1.8), Vector3(0, y, -0.6), frame)
		LevelKit.stripes(model, -1.7, y - 0.1, 3.4)
	ModelKit.cylinder(model, 2.2, 2.2, 0.8, Vector3(0, 0, -0.5), frame, Vector3(90, 0, 0), 10)
	_core_mat = ModelKit.emissive(Color("ffe9a8"), 1.0)
	ModelKit.sphere(model, 1.3, Vector3(0, 0, 0.1), _core_mat)
	_core_glow = ModelKit.quad(model, Vector2.ONE * 5.0, Vector3(0, 0, 1.2), ModelKit.glow(Color("ffd08a"), 0.5))
	for i in 4:
		var plate := ModelKit.group(model, "Plate%d" % i)
		ModelKit.box(plate, Vector3(2.2, 0.55, 0.6), Vector3.ZERO, coral)
		ModelKit.box(plate, Vector3(2.0, 0.12, 0.62), Vector3(0, -0.2, 0), dark)
		_plates.append(plate)
