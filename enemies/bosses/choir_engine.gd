class_name ChoirEngine
extends BossBase
## Stage 1 boss, the CHOIR COLOSSUS: a giant war mecha angled three-quarters toward the camera —
## V-horned helmet with a red visor, crimson armour over gunmetal, glowing chest core (the weak
## point), beam rifle and shield, blade wings with a rotating halo, and three funnel drones
## (Burst, Arc, Guard) orbiting it; one funnel is destroyed at each break.
## Tests positioning, dash timing and target priority.
##  P1 Listen:       fan volley, rotating spiral (safe lanes), drone summon
##  P2 Answer:       + telegraphed lightning lanes, aimed bursts
##  P3 Counterpoint: faster; Null Chorus (3-step telegraph → radial rings with a gap)

const MASK_COLORS: Array[Color] = [Color("ff6a4e"), Color("a77bff"), Color("ffc543")]

@export var weapon: WeaponComponent
@export var summon_scene: PackedScene

var _masks: Node3D
var _ring: Node3D
var _frame: Node3D
var _head: Node3D
var _rifle_arm: Node3D
var _shield_arm: Node3D
var _wings: Array[Node3D] = []
var _eye: StandardMaterial3D
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
		# Funnels orbit the colossus on a tilted ellipse.
		_masks.rotation.z = _spin
		for mask in _masks.get_children():
			(mask as Node3D).rotation.z = -_spin
	if _ring:
		_ring.rotation.z += delta * 0.8
	if _frame:
		_frame.position.y = sin(_state_time * 1.3) * 0.25
		var aim := _aim_at_player(global_position)
		_head.rotation.z = lerp_angle(_head.rotation.z, clampf(-aim.y * 0.4, -0.3, 0.3), 0.08)
		var firing := current_attack != &""
		_rifle_arm.rotation.z = lerp_angle(_rifle_arm.rotation.z, (atan2(-aim.y, -aim.x) * 0.6 if firing else -0.25), 0.1)
		_shield_arm.rotation.z = lerp_angle(_shield_arm.rotation.z, 0.35 if firing else 0.1, 0.06)
		for i in _wings.size():
			_wings[i].rotation.x = (0.35 + 0.08 * sin(_spin * 2.0 + i)) * (1.0 if i % 2 == 0 else -1.0)
		_eye.emission_energy_multiplier = 3.5 if firing else 2.0
	if _core_glow:
		var vulnerable := is_attackable()
		(_core_glow.material_override as ShaderMaterial).set_shader_parameter(
				&"energy", (1.4 + 0.5 * sin(_state_time * 8.0)) if vulnerable else 0.5)


func _build_model() -> void:
	var model := Node3D.new()
	model.name = "Model"
	model.scale = Vector3.ONE * 1.25
	add_child(model)
	var metal := ModelKit.hull(Color("2b2638"), ArtStyle.OUTLINE_THICK, 0.5)
	var metal_thin := ModelKit.hull(Color("2b2638"), ArtStyle.OUTLINE_THIN, 0.5)
	var dark := ModelKit.hull(Color("171421"), ArtStyle.OUTLINE_THIN, 0.3)
	var crimson := ModelKit.hull(Color("a82c32"), ArtStyle.OUTLINE_THICK, 0.4)
	var crimson_thin := ModelKit.hull(Color("a82c32"), ArtStyle.OUTLINE_THIN, 0.4)
	var gold := ModelKit.glossy(Palette.PLAYER_GOLD.darkened(0.1))
	ModelKit.with_outline(gold, ArtStyle.OUTLINE_THIN)
	var core := ModelKit.emissive(Color("e8fbff"), 3.0)
	_eye = ModelKit.emissive(Color("ff3b30"), 2.0)
	# The whole mecha faces -X in local space and is turned three-quarters toward the camera.
	_frame = ModelKit.group(model, "Frame")
	var body := ModelKit.group(_frame, "Body")
	body.rotation_degrees = Vector3(0, 38, 0)
	# Torso: gunmetal chest, crimson V armour, gold collar, waist and pelvis skirt.
	ModelKit.box(body, Vector3(2.4, 2.4, 2.8), Vector3(0.1, 0.3, 0), metal)
	ModelKit.prism(body, Vector3(1.2, 2.6, 3.0), Vector3(-0.9, 0.5, 0), crimson, Vector3(0, 0, 90))
	ModelKit.box(body, Vector3(2.6, 0.35, 3.0), Vector3(0.1, 1.6, 0), gold)
	ModelKit.box(body, Vector3(1.4, 0.9, 1.8), Vector3(0.2, -1.3, 0), dark)
	ModelKit.box(body, Vector3(1.8, 0.8, 2.6), Vector3(0.1, -2.0, 0), crimson_thin)
	for z: float in [-0.9, 0.9]:
		ModelKit.prism(body, Vector3(0.9, 1.2, 0.6), Vector3(-0.3, -2.6, z), crimson_thin, Vector3(0, 0, 180))
	# Chest core (weak point) with its glow and the null-chorus charge ring.
	ModelKit.sphere(body, 0.7, Vector3(-1.25, 0.35, 0), core)
	ModelKit.cylinder(body, 0.95, 0.95, 0.2, Vector3(-1.2, 0.35, 0), gold, Vector3(0, 0, 90), 10)
	_core_glow = ModelKit.quad(model, Vector2.ONE * 3.6, Vector3(-1.0, 0.35, 1.6), ModelKit.glow(Color("bff4ff"), 1.4))
	_charge_ring = ModelKit.quad(model, Vector2.ONE * 3.0, Vector3(-1.0, 0.35, 1.7), ModelKit.glow(Color.WHITE, 2.2, ModelKit.GlowShape.RING))
	_charge_ring.visible = false
	# Head: helmet, face plate, red visor, gold V horns, crest blade, cheek vents.
	_head = ModelKit.group(body, "Head", Vector3(-0.1, 2.3, 0))
	ModelKit.box(_head, Vector3(1.1, 1.0, 1.1), Vector3(0, 0.3, 0), metal)
	ModelKit.box(_head, Vector3(0.5, 0.6, 0.9), Vector3(-0.55, 0.15, 0), crimson_thin)
	ModelKit.box(_head, Vector3(0.15, 0.18, 0.95), Vector3(-0.82, 0.35, 0), _eye)
	ModelKit.quad(_head, Vector2(1.6, 0.8), Vector3(-0.95, 0.35, 0.3), ModelKit.glow(Color("ff3b30"), 1.0))
	for z: float in [-0.35, 0.35]:
		ModelKit.prism(_head, Vector3(0.2, 1.4, 0.15), Vector3(-0.55, 1.0, z), gold, Vector3(0, 0, -30.0 + z * 20.0))
	ModelKit.prism(_head, Vector3(1.2, 0.5, 0.2), Vector3(0.35, 0.95, 0), crimson_thin, Vector3(0, 0, -20))
	# Shoulders: huge crimson pauldrons with gold studs.
	for z: float in [-1.9, 1.9]:
		var pad := ModelKit.group(body, "Pauldron", Vector3(0.1, 1.4, z))
		ModelKit.sphere(pad, 1.05, Vector3.ZERO, crimson, Vector3(1.2, 0.95, 0.9))
		ModelKit.box(pad, Vector3(1.9, 0.3, 1.2), Vector3(0, -0.75, 0), gold)
		ModelKit.box(pad, Vector3(0.6, 1.2, 0.2), Vector3(0.4, 0.4, signf(z) * 0.95), metal_thin)
	# Rifle arm (near side): upper arm, forearm, long beam rifle aimed at the player.
	_rifle_arm = ModelKit.group(body, "RifleArm", Vector3(0.1, 0.9, 2.1))
	ModelKit.box(_rifle_arm, Vector3(0.7, 1.6, 0.7), Vector3(0, -0.8, 0), metal)
	ModelKit.box(_rifle_arm, Vector3(1.6, 0.8, 0.9), Vector3(-0.6, -1.7, 0), crimson_thin)
	ModelKit.box(_rifle_arm, Vector3(2.8, 0.45, 0.45), Vector3(-2.0, -1.6, 0.1), dark)
	ModelKit.hex_x(_rifle_arm, 0.18, 1.6, Vector3(-4.0, -1.55, 0.1), metal_thin, 8)
	ModelKit.box(_rifle_arm, Vector3(0.5, 0.7, 0.25), Vector3(-1.4, -2.1, 0.1), dark)
	ModelKit.sphere(_rifle_arm, 0.16, Vector3(-4.85, -1.55, 0.1), ModelKit.emissive(Color("ff6a4e"), 3.0))
	# Shield arm (far side).
	_shield_arm = ModelKit.group(body, "ShieldArm", Vector3(0.1, 0.9, -2.1))
	ModelKit.box(_shield_arm, Vector3(0.7, 1.6, 0.7), Vector3(0, -0.8, 0), metal)
	ModelKit.box(_shield_arm, Vector3(1.4, 3.6, 0.35), Vector3(-0.8, -1.4, -0.5), crimson)
	ModelKit.box(_shield_arm, Vector3(0.9, 2.6, 0.38), Vector3(-0.8, -1.4, -0.52), gold)
	# Legs folded back in flight, calf thrusters firing.
	for z: float in [-0.8, 0.8]:
		var leg := ModelKit.group(body, "Leg", Vector3(0.2, -2.3, z))
		ModelKit.box(leg, Vector3(0.9, 1.7, 0.9), Vector3(0.2, -0.8, 0), metal, Vector3(0, 0, -25))
		var shin := ModelKit.group(leg, "Shin", Vector3(0.55, -1.6, 0))
		ModelKit.box(shin, Vector3(1.1, 2.0, 1.1), Vector3(0.35, -0.8, 0), crimson, Vector3(0, 0, 35))
		ModelKit.box(shin, Vector3(1.3, 0.45, 1.0), Vector3(1.0, -1.7, 0), dark, Vector3(0, 0, 35))
		ModelKit.quad(shin, Vector2(2.4, 0.7), Vector3(2.2, -2.1, 0.5), ModelKit.glow(Color("7fd8ff"), 1.4, ModelKit.GlowShape.STREAK), Vector3(0, 0, 215))
	# Back: blade wings and the rotating halo of the choir.
	var back := ModelKit.group(body, "Back", Vector3(1.4, 1.0, 0))
	ModelKit.box(back, Vector3(0.8, 1.6, 1.6), Vector3.ZERO, dark)
	for i in 4:
		var wing := ModelKit.group(back, "Wing", Vector3(0.2, 0.3 - (i / 2) * 0.9, 0))
		var side := 1.0 if i % 2 == 0 else -1.0
		ModelKit.prism(wing, Vector3(0.4, 3.6 - (i / 2) * 1.0, 0.25), Vector3(0.6, 1.4, 0), crimson_thin if i < 2 else metal_thin, Vector3(0, 0, -35.0 - (i / 2) * 25.0))
		wing.rotation.x = 0.35 * side
		_wings.append(wing)
	_ring = ModelKit.group(model, "Halo", Vector3(1.4, 1.8, -1.6))
	for i in 12:
		var a := TAU * i / 12.0
		ModelKit.box(_ring, Vector3(1.0, 0.25, 0.3), Vector3(cos(a), sin(a), 0) * 3.4, gold if i % 2 else crimson_thin, Vector3(0, 0, rad_to_deg(a) + 90.0))
		if i % 2 == 0:
			ModelKit.sphere(_ring, 0.2, Vector3(cos(a), sin(a), 0.1) * 3.4, ModelKit.emissive(Color("ff8a1f"), 2.4))
	# Three funnel drones (Burst, Arc, Guard) orbiting the colossus.
	_masks = Node3D.new()
	model.add_child(_masks)
	for i in 3:
		var a := TAU * i / 3.0
		var funnel := Node3D.new()
		funnel.position = Vector3(cos(a), sin(a), 0) * 4.6
		_masks.add_child(funnel)
		var mat := ModelKit.hull(MASK_COLORS[i], ArtStyle.OUTLINE_THIN, 0.6)
		ModelKit.cone_x(funnel, 0.45, 1.3, Vector3(-0.3, 0, 0), mat, 6, true)
		ModelKit.hex_x(funnel, 0.4, 0.7, Vector3(0.55, 0, 0), dark, 6)
		ModelKit.quad(funnel, Vector2(1.4, 0.5), Vector3(1.4, 0, 0.1), ModelKit.glow(MASK_COLORS[i], 1.2, ModelKit.GlowShape.STREAK), Vector3(0, 0, 180))
		ModelKit.quad(funnel, Vector2.ONE * 1.4, Vector3(-0.3, 0, 0.5), ModelKit.glow(MASK_COLORS[i], 0.9))
