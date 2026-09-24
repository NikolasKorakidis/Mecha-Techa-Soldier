class_name ForgeDreadnought
extends BossBase
## Stage 2 boss: a foundry warship. Destroy both turrets to open the core armor.
##  P1 Armored:  turrets fire aimed bursts; broadside walls with a gap; rammer escorts
##  P2 Exposed:  core open — lightning lane sweeps, radial bursts, broadsides
##  P3 Meltdown: faster, dense mixes; everything the fight has taught

@export var weapon: WeaponComponent
@export var turrets: Array[BossTurret] = []
@export var summon_scene: PackedScene

var _shutters: Array[Node3D] = []
var _core_glow: MeshInstance3D
var _hull: Node3D
var _time: float = 0.0
var _fired_steps: int = 0
var _sweep_lanes: Array[float] = []


func _ready() -> void:
	_build_model()
	super._ready()
	for turret in turrets:
		turret.destroyed.connect(func(_t: BossTurret) -> void: _apply_state_rules())


func _core_exposed() -> bool:
	return state != State.PHASE_1


func _phase_complete() -> bool:
	if state == State.PHASE_1:
		for turret in turrets:
			if turret.is_alive():
				return false
		return true
	return super._phase_complete()


func _phase_attacks(phase: int) -> Array[StringName]:
	match phase:
		1:
			return [&"broadside", &"summon", &"broadside", &"radial"]
		2:
			return [&"sweep", &"broadside", &"radial", &"sweep", &"summon"]
		3:
			return [&"sweep", &"radial", &"broadside", &"spiral", &"sweep"]
	return []


func _attack_duration(attack: StringName, first_use: bool) -> float:
	var slow := 1.3 if first_use else 1.0
	match attack:
		&"broadside":
			return 2.2 * slow
		&"summon":
			return 1.0
		&"radial":
			return 2.0
		&"sweep":
			return 3.4 * slow
		&"spiral":
			return 2.6
	return 2.0


func _attack_begin(attack: StringName, first_use: bool) -> void:
	_fired_steps = 0
	match attack:
		&"summon":
			if summon_scene and summon_root:
				for y: float in [6.0, 0.0, -6.0]:
					var rammer := summon_scene.instantiate() as SpaceEnemy
					rammer.position = Vector3(global_position.x + 4.0, y, 0)
					summon_root.add_child(rammer)
		&"sweep":
			# Lanes march from the top down (or bottom up); each warns before striking.
			var down := randf() < 0.5
			_sweep_lanes.clear()
			for i in 4:
				var y := 6.0 - i * 4.0
				_sweep_lanes.append(y if down else -y)
			var warn := 1.1 if first_use else 0.85
			for i in _sweep_lanes.size():
				_spawn_beam(_sweep_lanes[i], warn + i * 0.45, 0.45, Color(1.0, 0.55, 0.25), 1.2)


func _attack_update(attack: StringName, time: float, _delta: float) -> void:
	var slow := 1.3 if _current_first_use else 1.0
	match attack:
		&"broadside":
			# Two vertical walls of shots, each with a gap on the player's lane.
			var due := int(time >= 0.6 * slow) + int(time >= 1.4 * slow)
			while _fired_steps < due:
				var gap_y := clampf(_player_position().y + (2.0 if _fired_steps == 1 else 0.0), -6.5, 6.5)
				for i in 15:
					var y := -8.0 + i * (16.0 / 14.0)
					if absf(y - gap_y) < 1.7:
						continue
					weapon.global_position = Vector3(global_position.x - 3.5, y, 0)
					weapon.fire_at(Vector3.LEFT, 0.8)
				_fired_steps += 1
			weapon.position = Vector3(-3.2, 0, 0)
		&"radial":
			var rings := 2 if phase_number() < 3 else 3
			var due := mini(rings, int(time / 0.6) + 1)
			while _fired_steps < due:
				for i in 18:
					var a := TAU * i / 18.0 + _fired_steps * 0.17
					weapon.fire_at(Vector3(cos(a), sin(a), 0), 0.75)
				_fired_steps += 1
		&"spiral":
			while _fired_steps * 0.06 <= time and time < 2.4:
				for arm in 4:
					var a := _time * 2.2 + TAU * arm / 4.0
					weapon.fire_at(Vector3(cos(a), sin(a), 0), 0.8)
				_fired_steps += 1


func _on_state_entered(new_state: State) -> void:
	for turret in turrets:
		turret.active = new_state in [State.PHASE_1, State.PHASE_2, State.PHASE_3]
	if new_state == State.BREAK_1:
		_open_shutters()


func _animate(delta: float) -> void:
	_time += delta
	if _hull:
		_hull.position.y = sin(_time * 0.8) * 0.25
	if _core_glow:
		var open := _core_exposed() and is_attackable()
		(_core_glow.material_override as ShaderMaterial).set_shader_parameter(
				&"energy", (1.6 + 0.6 * sin(_time * 9.0)) if open else 0.25)


func _open_shutters() -> void:
	for i in _shutters.size():
		var shutter := _shutters[i]
		var tween := create_tween()
		tween.tween_property(shutter, "position:y", shutter.position.y + (1.6 if i == 0 else -1.6), 0.6) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_model() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	_hull = model
	var hull := ModelKit.toon(Color("2e2233"), 0.6, 0.5, 0.5)
	var plate := ModelKit.toon(Color("c93a3a"), 0.55, 0.5, 0.2)
	var trim := ModelKit.toon(Color("ffc543"), 0.6, 0.3, 0.5)
	var lights := ModelKit.emissive(Color("ff8a1f"), 2.2)
	ModelKit.box(model, Vector3(8.0, 4.2, 2.4), Vector3(1.5, 0, -0.4), hull)
	ModelKit.prism(model, Vector3(4.2, 2.2, 2.2), Vector3(-3.4, 0, -0.4), plate, Vector3(0, 0, 90))
	ModelKit.box(model, Vector3(8.4, 0.5, 2.6), Vector3(1.5, 2.3, -0.4), plate)
	ModelKit.box(model, Vector3(8.4, 0.5, 2.6), Vector3(1.5, -2.3, -0.4), plate)
	ModelKit.box(model, Vector3(0.3, 4.6, 2.7), Vector3(-1.0, 0, -0.4), trim)
	for i in 6:
		ModelKit.box(model, Vector3(0.35, 0.35, 0.3), Vector3(0.2 + i * 1.0, 2.6, 0.9), lights)
		ModelKit.box(model, Vector3(0.35, 0.35, 0.3), Vector3(0.2 + i * 1.0, -2.6, 0.9), lights)
	for side: float in [1.0, -1.0]:
		ModelKit.cylinder(model, 0.7, 0.9, 1.4, Vector3(5.8, 1.3 * side, -0.4), ModelKit.toon(Color("4a3a48"), 0.4, 0.35, 0.6), Vector3(0, 0, 90))
		ModelKit.quad(model, Vector2(3.0, 1.2), Vector3(7.8, 1.3 * side, 0.2), ModelKit.glow(Color(1.0, 0.6, 0.3), 1.8, ModelKit.GlowShape.STREAK), Vector3(0, 0, 180))
	# Core behind two armor shutters.
	ModelKit.sphere(model, 0.9, Vector3(-2.4, 0, 0.6), ModelKit.emissive(Color("fff0c8"), 3.0))
	_core_glow = ModelKit.quad(model, Vector2.ONE * 3.4, Vector3(-2.4, 0, 1.2), ModelKit.glow(Color("ffd08a"), 1.6))
	for side: float in [1.0, -1.0]:
		var shutter := ModelKit.box(model, Vector3(1.6, 1.0, 0.5), Vector3(-2.4, 0.52 * side, 1.4), trim)
		_shutters.append(shutter)
