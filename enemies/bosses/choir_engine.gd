class_name ChoirEngine
extends BossBase
## Stage 1 boss: a circular foundry guardian with three rotating masks (Burst, Arc, Guard).
## Tests positioning, dash timing and target priority.
##  P1 Listen:       fan volley, rotating spiral (safe lanes), drone summon
##  P2 Answer:       + telegraphed lightning lanes, aimed bursts
##  P3 Counterpoint: faster; Null Chorus (3-step telegraph → radial rings with a gap)

const MASK_COLORS: Array[Color] = [Color("ff6a4e"), Color("a77bff"), Color("ffc543")]

@export var weapon: WeaponComponent
@export var summon_scene: PackedScene

var _masks: Node3D
var _ring: Node3D
var _core_glow: MeshInstance3D
var _charge_ring: MeshInstance3D
var _spin: float = 0.0
var _spiral_angle: float = 0.0
var _fired_steps: int = 0


func _ready() -> void:
	_build_model()
	super._ready()


func _phase_attacks(phase: int) -> Array[StringName]:
	match phase:
		1:
			return [&"fan", &"spiral", &"fan", &"summon"]
		2:
			return [&"lightning", &"fan", &"aimed_burst", &"spiral", &"lightning", &"summon"]
		3:
			return [&"null_chorus", &"spiral", &"lightning", &"aimed_burst", &"fan"]
	return []


func _attack_duration(attack: StringName, first_use: bool) -> float:
	var slow := 1.3 if first_use else 1.0
	match attack:
		&"fan":
			return 1.6 * slow
		&"spiral":
			return 3.0
		&"summon":
			return 1.2
		&"lightning":
			return 2.4 * slow
		&"aimed_burst":
			return 1.4
		&"null_chorus":
			return 4.2 * slow
	return 2.0


func _attack_begin(attack: StringName, first_use: bool) -> void:
	_fired_steps = 0
	match attack:
		&"lightning":
			# One lane on the player, one elsewhere — always leaves a safe band.
			var player_y := clampf(_player_position().y, -7.0, 7.0)
			var other_y := player_y - 7.0 if player_y > 0.0 else player_y + 7.0
			var warn := 1.3 if first_use else 1.0
			_spawn_beam(player_y, warn, 0.55, MASK_COLORS[1], 1.3)
			_spawn_beam(other_y, warn + 0.35, 0.55, MASK_COLORS[1], 1.3)
		&"summon":
			_summon()
		&"null_chorus":
			_charge_ring.visible = true


func _attack_update(attack: StringName, time: float, _delta: float) -> void:
	var slow := 1.3 if _current_first_use else 1.0
	match attack:
		&"fan":
			# Two fans: a telegraph pause, then volleys at 0.5 s and 1.1 s.
			var shots_due := int(time >= 0.5 * slow) + int(time >= 1.1 * slow)
			while _fired_steps < shots_due:
				_fan(9 if phase_number() > 1 else 7, 70.0, _fired_steps % 2 == 1)
				_fired_steps += 1
		&"spiral":
			var rate := 0.07 if phase_number() < 3 else 0.055
			while _fired_steps * rate <= time and time < 2.8:
				var arms := 2 if phase_number() == 1 else 3
				for arm in arms:
					var a := _spiral_angle + TAU * arm / arms
					weapon.fire_at(Vector3(cos(a), sin(a), 0), 0.75)
				_spiral_angle += 0.23
				_fired_steps += 1
		&"aimed_burst":
			var due := mini(6, int(time / 0.12))
			while _fired_steps < due:
				weapon.fire_at(_aim_at_player(weapon.global_position), 1.25)
				_fired_steps += 1
		&"null_chorus":
			_update_null_chorus(time)


func _fan(count: int, arc_degrees: float, offset: bool) -> void:
	var aim := _aim_at_player(weapon.global_position)
	var base := atan2(aim.y, aim.x) + (deg_to_rad(arc_degrees / (count - 1)) * 0.5 if offset else 0.0)
	for i in count:
		var a := base + deg_to_rad(arc_degrees) * (float(i) / float(count - 1) - 0.5)
		weapon.fire_at(Vector3(cos(a), sin(a), 0), 0.9)


func _summon() -> void:
	if summon_scene == null or summon_root == null:
		return
	for y: float in [5.5, -5.5]:
		var drone := summon_scene.instantiate() as SpaceEnemy
		drone.position = Vector3(global_position.x + 3.0, y, 0)
		summon_root.add_child(drone)


## Three-step telegraph: inward ring (0–1.2 s), white core flare (1.2–1.8 s),
## then three radial rings with a rotating gap.
func _update_null_chorus(time: float) -> void:
	var slow := 1.3 if _current_first_use else 1.0
	var flare_at := 1.2 * slow
	var fire_at := 1.8 * slow
	if time < flare_at:
		var t := time / flare_at
		_charge_ring.scale = Vector3.ONE * lerpf(4.0, 0.6, t)
	elif time < fire_at:
		_charge_ring.visible = false
		_core_glow.scale = Vector3.ONE * (1.0 + 2.0 * (time - flare_at) / (fire_at - flare_at))
	else:
		_core_glow.scale = Vector3.ONE
		var due := mini(3, 1 + int((time - fire_at) / 0.55))
		while _fired_steps < due:
			var gap_center := atan2(_aim_at_player(global_position).y, _aim_at_player(global_position).x) + 0.9 * _fired_steps
			for i in 22:
				var a := TAU * i / 22.0
				if absf(wrapf(a - gap_center, -PI, PI)) < 0.42:
					continue
				weapon.fire_at(Vector3(cos(a), sin(a), 0), 0.8)
			_fired_steps += 1
			if _camera:
				_camera.add_trauma(ArtStyle.SHAKE_MAJOR * 0.6)


func _on_state_entered(new_state: State) -> void:
	_charge_ring.visible = false
	_core_glow.scale = Vector3.ONE
	if new_state == State.BREAK_1 or new_state == State.BREAK_2:
		# Shatter one mask per break.
		var index := 0 if new_state == State.BREAK_1 else 1
		var mask := _masks.get_child(index) as Node3D
		if mask:
			Vfx.spawn(get_tree(), death_effect, mask.global_position, 1.6)
			mask.visible = false


func _animate(delta: float) -> void:
	var speed := 0.7 + 0.5 * phase_number()
	_spin += delta * speed
	if _masks:
		_masks.rotation.z = _spin
		for mask in _masks.get_children():
			(mask as Node3D).rotation.z = -_spin
	if _ring:
		_ring.rotation.z = -_spin * 0.4
	if _core_glow:
		var vulnerable := is_attackable()
		(_core_glow.material_override as ShaderMaterial).set_shader_parameter(
				&"energy", (1.4 + 0.5 * sin(_state_time * 8.0)) if vulnerable else 0.5)


func _build_model() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	var hull := ModelKit.toon(Color("3a2436"), 0.6, 0.45, 0.5)
	var plate := ModelKit.toon(Color("c93a3a"), 0.55, 0.5, 0.2)
	var core := ModelKit.emissive(Color("e8fbff"), 3.0)
	# Outer ring of segments.
	_ring = Node3D.new()
	model.add_child(_ring)
	for i in 12:
		var a := TAU * i / 12.0
		var seg := ModelKit.box(_ring, Vector3(1.3, 0.6, 1.0), Vector3(cos(a), sin(a), 0) * 3.5, hull if i % 2 else plate,
				Vector3(0, 0, rad_to_deg(a) + 90.0))
		if i % 3 == 0:
			ModelKit.box(seg, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.35, 0.4), ModelKit.emissive(Color("ff8a1f"), 2.0))
	# Core housing.
	ModelKit.sphere(model, 1.5, Vector3.ZERO, hull, Vector3(1, 1, 0.8))
	ModelKit.sphere(model, 0.75, Vector3(0, 0, 0.9), core)
	_core_glow = ModelKit.quad(model, Vector2.ONE * 3.6, Vector3(0, 0, 1.4), ModelKit.glow(Color("bff4ff"), 1.4))
	_charge_ring = ModelKit.quad(model, Vector2.ONE * 3.0, Vector3(0, 0, 1.5), ModelKit.glow(Color.WHITE, 2.2, ModelKit.GlowShape.RING))
	_charge_ring.visible = false
	# Three masks orbiting the core.
	_masks = Node3D.new()
	model.add_child(_masks)
	for i in 3:
		var a := TAU * i / 3.0
		var mask := Node3D.new()
		mask.position = Vector3(cos(a), sin(a), 0) * 2.35
		_masks.add_child(mask)
		var mat := ModelKit.toon(MASK_COLORS[i], 0.7, 0.35, 0.3)
		ModelKit.prism(mask, Vector3(1.3, 1.1, 0.7), Vector3.ZERO, mat, Vector3(0, 0, 90))
		ModelKit.box(mask, Vector3(0.5, 0.9, 0.6), Vector3(0.45, 0, 0), hull)
		ModelKit.quad(mask, Vector2.ONE * 1.4, Vector3(-0.1, 0, 0.5), ModelKit.glow(MASK_COLORS[i], 0.9))
