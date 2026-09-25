@tool
class_name MechModel
extends Node3D
## Kestrel in mech form (faces +X, feet at y = 0, ~2.6 units tall). Mega Man X-style build read
## in pure side profile: helmet with crest fin, visor and ear discs on a neck; V chest with a
## glowing core; big rounded shoulder pauldrons; the front arm is the buster cannon; slim waist;
## thighs over chunky armoured boots; a twin-nozzle thruster pack. Deep blue / white / gold.
## Poses are procedural so the controller only reports its state.

enum Pose { IDLE, RUN, AIR, DASH, WALL, HIT, SUPER }

const PART_NAMES: Array[String] = ["LegBack", "LegFront", "Pelvis", "Torso", "ShoulderBack", "ShoulderFront", "Head", "Pack", "ArmCannon"]

const ARMOR_WHITE := Color("e4ebf6")
const ARMOR_BLUE := Color("2a5fe0")
const ARMOR_DEEP := Color("16296b")
const JOINT := Color("171c2e")
const METAL := Color("323c58")

var pose: Pose = Pose.IDLE
var run_ratio: float = 0.0

var _legs: Array[Node3D] = []
var _shins: Array[Node3D] = []
var _torso: Node3D
var _cannon: Node3D
var _arm_back: Node3D
var _forearm_back: Node3D
var _head: Node3D
var _pack_flames: Array[MeshInstance3D] = []
var _core_glow: MeshInstance3D
var _phase: float = 0.0
var _kick: float = 0.0
var _time: float = 0.0
var _charge_glow: MeshInstance3D
var _charge_mat: ShaderMaterial
var _visor_mat: StandardMaterial3D


func _ready() -> void:
	ModelKit.clear(self)
	_legs.clear()
	_shins.clear()
	_pack_flames.clear()
	var white := ModelKit.hull(ARMOR_WHITE)
	var white_thin := ModelKit.hull(ARMOR_WHITE, ArtStyle.OUTLINE_THIN)
	var blue := ModelKit.hull(ARMOR_BLUE)
	var blue_thin := ModelKit.hull(ARMOR_BLUE, ArtStyle.OUTLINE_THIN)
	var deep := ModelKit.hull(ARMOR_DEEP, ArtStyle.OUTLINE_THIN, 0.4)
	var metal := ModelKit.hull(METAL, ArtStyle.OUTLINE_THIN, 0.35)
	var joint := ModelKit.hull(JOINT, ArtStyle.OUTLINE_THIN, 0.3)
	var gold := ModelKit.glossy(Palette.PLAYER_GOLD)
	ModelKit.with_outline(gold, ArtStyle.OUTLINE_THIN)
	var energy := ModelKit.emissive(Palette.PLAYER_ENERGY, 2.6)
	_visor_mat = ModelKit.emissive(Palette.PLAYER_ENERGY.lerp(Color.WHITE, 0.35), 3.2)

	# Legs (back leg built first so the front one draws over it).
	for i in 2:
		var front := i == 1
		var z := 0.2 if front else -0.2
		var shell := blue_thin if front else deep
		var plate := white_thin if front else metal
		var hip := ModelKit.group(self, "LegFront" if front else "LegBack", Vector3(0.0, 1.08, z))
		ModelKit.sphere(hip, 0.15, Vector3.ZERO, joint)
		# Thigh: dark inner sleeve with a blue armour shell and a white front plate.
		ModelKit.box(hip, Vector3(0.26, 0.5, 0.26), Vector3(0, -0.25, 0), joint)
		ModelKit.box(hip, Vector3(0.3, 0.36, 0.3), Vector3(0.02, -0.22, 0), shell)
		ModelKit.box(hip, Vector3(0.08, 0.3, 0.31), Vector3(0.16, -0.22, 0), plate)
		var knee := ModelKit.group(hip, "Knee", Vector3(0, -0.5, 0))
		ModelKit.sphere(knee, 0.13, Vector3.ZERO, joint)
		# Knee cap: a pointed guard jutting forward.
		ModelKit.prism(knee, Vector3(0.24, 0.26, 0.3), Vector3(0.14, 0.02, 0), plate, Vector3(0, 0, -90))
		# Boot: wide armoured shin flaring toward the ankle, a blue cuff, vents and a light line.
		ModelKit.hex_x(knee, 0.2, 0.5, Vector3(0.0, -0.26, 0), plate, 6, 1.3).rotation_degrees = Vector3(0, 0, 90)
		ModelKit.box(knee, Vector3(0.44, 0.12, 0.42), Vector3(0.02, -0.03, 0), shell)
		for k in 3:
			ModelKit.box(knee, Vector3(0.03, 0.2, 0.34), Vector3(-0.2, -0.22 - k * 0.04, 0), joint)
		ModelKit.box(knee, Vector3(0.03, 0.26, 0.02), Vector3(0.18, -0.28, 0.21 * signf(z)), energy)
		# Foot: sole, toe cap, heel block with a thruster port.
		ModelKit.box(knee, Vector3(0.64, 0.14, 0.4), Vector3(0.08, -0.56, 0), shell)
		ModelKit.prism(knee, Vector3(0.18, 0.26, 0.38), Vector3(0.44, -0.55, 0), plate, Vector3(0, 0, -90))
		ModelKit.box(knee, Vector3(0.16, 0.18, 0.34), Vector3(-0.22, -0.5, 0), metal)
		ModelKit.cylinder(knee, 0.06, 0.06, 0.02, Vector3(-0.31, -0.5, 0), energy, Vector3(0, 0, 90), 8)
		_legs.append(hip)
		_shins.append(knee)

	# Pelvis: dark hips, white codpiece, blue side skirts, gold buckle.
	var pelvis := ModelKit.group(self, "Pelvis", Vector3(0, 1.12, 0))
	ModelKit.box(pelvis, Vector3(0.46, 0.24, 0.6), Vector3.ZERO, joint)
	ModelKit.box(pelvis, Vector3(0.2, 0.26, 0.3), Vector3(0.17, -0.05, 0), white_thin)
	for side: float in [1.0, -1.0]:
		ModelKit.box(pelvis, Vector3(0.3, 0.28, 0.06), Vector3(0.0, -0.1, 0.32 * side), blue_thin, Vector3(0, 0, 8))
	ModelKit.box(pelvis, Vector3(0.12, 0.1, 0.12), Vector3(0.26, 0.06, 0), gold)

	# Torso: slim waist, V chest with a white plate and the chest core, collar.
	_torso = ModelKit.group(self, "Torso", Vector3(0, 1.5, 0))
	ModelKit.box(_torso, Vector3(0.34, 0.24, 0.46), Vector3(0, -0.24, 0), joint)
	for k in 2:
		ModelKit.box(_torso, Vector3(0.36, 0.05, 0.5), Vector3(0.01, -0.2 - k * 0.08, 0), metal)
	ModelKit.box(_torso, Vector3(0.58, 0.44, 0.62), Vector3(-0.02, 0.1, 0), blue)
	ModelKit.prism(_torso, Vector3(0.4, 0.26, 0.64), Vector3(0.22, 0.12, 0), white, Vector3(0, 0, -90))
	ModelKit.box(_torso, Vector3(0.5, 0.1, 0.66), Vector3(-0.02, 0.33, 0), white_thin)
	ModelKit.box(_torso, Vector3(0.6, 0.06, 0.64), Vector3(-0.02, -0.11, 0), deep)
	# Chest core: a faceted gem on the chest side facing the camera, with a halo.
	var gem := ModelKit.group(_torso, "Core", Vector3(0.08, 0.1, 0.32))
	ModelKit.sphere(gem, 0.1, Vector3.ZERO, ModelKit.emissive(Palette.PLAYER_ENERGY, 3.0), Vector3(1, 1, 0.5))
	ModelKit.cylinder(gem, 0.14, 0.14, 0.03, Vector3(0, 0, -0.01), gold, Vector3(90, 0, 0), 8)
	_core_glow = ModelKit.quad(gem, Vector2.ONE * 0.6, Vector3(0, 0, 0.05), ModelKit.glow(Palette.PLAYER_ENERGY, 1.0))

	# Thruster pack: two angled nozzles with flames.
	var pack := ModelKit.group(_torso, "Pack", Vector3(-0.38, 0.08, 0))
	ModelKit.box(pack, Vector3(0.24, 0.46, 0.5), Vector3.ZERO, metal)
	ModelKit.box(pack, Vector3(0.1, 0.4, 0.54), Vector3(-0.12, 0.02, 0), deep)
	for side: float in [1.0, -1.0]:
		ModelKit.hex_x(pack, 0.09, 0.26, Vector3(-0.18, -0.26, 0.15 * side), joint, 8, 1.3).rotation_degrees = Vector3(0, 0, 60)
		var flame := ModelKit.quad(pack, Vector2(0.7, 0.24), Vector3(-0.44, -0.62, 0.15 * side + 0.02), ModelKit.glow(Palette.PLAYER_ENERGY, 1.6, ModelKit.GlowShape.STREAK), Vector3(0, 0, 240))
		flame.visible = false
		_pack_flames.append(flame)

	# Head on a short neck: helmet dome, crest fin, visor, face plate, ear discs.
	_head = ModelKit.group(_torso, "Head", Vector3(0.04, 0.62, 0))
	ModelKit.box(_head, Vector3(0.14, 0.16, 0.18), Vector3(0, -0.16, 0), joint)
	ModelKit.sphere(_head, 0.26, Vector3(-0.06, 0.05, 0), blue, Vector3(1.0, 0.95, 0.9))
	ModelKit.box(_head, Vector3(0.36, 0.1, 0.44), Vector3(-0.04, -0.1, 0), blue_thin)
	# Face: white face plate and chin under a helmet brim, visor band across the eyes.
	ModelKit.box(_head, Vector3(0.16, 0.2, 0.3), Vector3(0.18, -0.06, 0), white_thin)
	ModelKit.box(_head, Vector3(0.08, 0.06, 0.32), Vector3(0.25, 0.03, 0), _visor_mat)
	ModelKit.prism(_head, Vector3(0.14, 0.2, 0.46), Vector3(0.2, 0.15, 0), blue_thin, Vector3(0, 0, -90))
	# Crest: a gold blade sweeping up and back from the brow, plus a white top ridge.
	ModelKit.prism(_head, Vector3(0.12, 0.42, 0.06), Vector3(0.12, 0.26, 0), gold, Vector3(0, 0, -35))
	ModelKit.box(_head, Vector3(0.4, 0.06, 0.12), Vector3(-0.06, 0.24, 0), white_thin, Vector3(0, 0, -8))
	for side: float in [1.0, -1.0]:
		ModelKit.cylinder(_head, 0.1, 0.1, 0.08, Vector3(-0.04, 0.0, 0.23 * side), white_thin, Vector3(90, 0, 0), 10)
		ModelKit.cylinder(_head, 0.05, 0.05, 0.1, Vector3(-0.04, 0.0, 0.24 * side), energy, Vector3(90, 0, 0), 8)
		# Rear horn fins.
		ModelKit.prism(_head, Vector3(0.08, 0.26, 0.04), Vector3(-0.2, 0.12, 0.2 * side), blue_thin, Vector3(0, 0, 55))

	# Back shoulder and arm (behind the torso, darker).
	var shoulder_b := ModelKit.group(_torso, "ShoulderBack", Vector3(-0.04, 0.24, -0.4))
	ModelKit.sphere(shoulder_b, 0.2, Vector3.ZERO, deep, Vector3(1.1, 0.9, 0.8))
	_arm_back = ModelKit.group(shoulder_b, "Arm", Vector3(0, -0.08, 0))
	ModelKit.box(_arm_back, Vector3(0.16, 0.32, 0.16), Vector3(0, -0.16, 0), joint)
	_forearm_back = ModelKit.group(_arm_back, "Forearm", Vector3(0, -0.32, 0))
	ModelKit.box(_forearm_back, Vector3(0.2, 0.3, 0.2), Vector3(0.04, -0.12, 0), metal)
	ModelKit.box(_forearm_back, Vector3(0.18, 0.14, 0.2), Vector3(0.06, -0.32, 0), joint)

	# Front shoulder pauldron: big rounded white shell with a blue rim and a gold stud.
	var shoulder_f := ModelKit.group(_torso, "ShoulderFront", Vector3(-0.1, 0.26, 0.4))
	ModelKit.sphere(shoulder_f, 0.18, Vector3.ZERO, white, Vector3(1.2, 0.9, 0.85))
	ModelKit.box(shoulder_f, Vector3(0.42, 0.07, 0.26), Vector3(0, -0.1, 0.02), blue_thin)
	ModelKit.sphere(shoulder_f, 0.04, Vector3(0.0, 0.06, 0.15), gold)

	# Buster: the front arm held forward — upper arm, armoured forearm, ringed barrel.
	_cannon = ModelKit.group(_torso, "ArmCannon", Vector3(0.0, 0.08, 0.46))
	ModelKit.box(_cannon, Vector3(0.16, 0.26, 0.16), Vector3(0, -0.06, 0), joint)
	ModelKit.hex_x(_cannon, 0.17, 0.62, Vector3(0.32, -0.14, 0), white, 8, 0.92)
	ModelKit.box(_cannon, Vector3(0.36, 0.08, 0.26), Vector3(0.24, 0.0, 0), blue_thin)
	ModelKit.hex_x(_cannon, 0.18, 0.08, Vector3(0.52, -0.14, 0), gold, 8)
	ModelKit.hex_x(_cannon, 0.19, 0.12, Vector3(0.66, -0.14, 0), blue, 8)
	ModelKit.cylinder(_cannon, 0.11, 0.11, 0.03, Vector3(0.73, -0.14, 0), energy, Vector3(0, 0, 90), 10)
	ModelKit.box(_cannon, Vector3(0.26, 0.03, 0.02), Vector3(0.32, -0.14, 0.18), energy)
	_charge_mat = ModelKit.glow_billboard(Palette.PLAYER_ENERGY, 2.0)
	_charge_glow = ModelKit.quad(_cannon, Vector2.ONE, Vector3(0.82, -0.14, 0.1), _charge_mat)
	_charge_glow.visible = false


## Called by the controller every frame.
func update_pose(new_pose: Pose, speed_ratio: float, delta: float) -> void:
	pose = new_pose
	run_ratio = speed_ratio
	_time += delta
	_phase += delta * (4.0 + 9.0 * speed_ratio)
	_kick = maxf(0.0, _kick - delta * 8.0)
	var leg_swing := 0.0
	var knee_bend := [0.0, 0.0]
	var lean := 0.0
	var bob := 0.0
	var head_tilt := 0.0
	var arm_swing := 0.0
	match pose:
		Pose.IDLE:
			bob = sin(_time * 3.0) * 0.02
			knee_bend = [0.08, 0.08]
			arm_swing = sin(_time * 3.0) * 0.05
		Pose.RUN:
			leg_swing = sin(_phase) * 0.8 * clampf(speed_ratio, 0.3, 1.0)
			knee_bend = [maxf(0.0, -sin(_phase)) * 1.1 + 0.1, maxf(0.0, sin(_phase)) * 1.1 + 0.1]
			lean = -0.14
			bob = absf(sin(_phase)) * 0.07
			arm_swing = -sin(_phase) * 0.7
			head_tilt = 0.08
		Pose.AIR:
			leg_swing = 0.4
			knee_bend = [1.1, 0.4]
			arm_swing = -0.6
		Pose.DASH:
			leg_swing = -0.75
			knee_bend = [0.2, 0.7]
			lean = -0.38
			arm_swing = 0.9
			head_tilt = 0.25
		Pose.WALL:
			leg_swing = 0.25
			knee_bend = [0.7, 0.3]
			lean = 0.15
			arm_swing = 0.4
		Pose.HIT:
			lean = 0.32
			knee_bend = [0.35, 0.35]
			arm_swing = 0.8
			head_tilt = -0.3
		Pose.SUPER:
			leg_swing = 0.3
			knee_bend = [0.6, 0.2]
			lean = -0.1
			arm_swing = -0.4
	_legs[0].rotation.z = leg_swing
	_legs[1].rotation.z = -leg_swing
	_shins[0].rotation.z = -knee_bend[0]
	_shins[1].rotation.z = -knee_bend[1]
	_torso.rotation.z = lean
	_torso.position.y = 1.5 + bob
	_head.rotation.z = head_tilt - lean * 0.5
	_cannon.rotation.z = -_kick * 0.25
	_cannon.position.x = -_kick * 0.12
	_arm_back.rotation.z = arm_swing
	_forearm_back.rotation.z = absf(arm_swing) * 0.6 + 0.3
	var thrust := pose in [Pose.DASH, Pose.AIR, Pose.SUPER]
	for flame in _pack_flames:
		flame.visible = thrust
		flame.scale = Vector3(1.7 if pose == Pose.DASH else 0.8 + 0.2 * sin(_time * 40.0), 1, 1)
	(_core_glow.material_override as ShaderMaterial).set_shader_parameter(
			&"energy", (2.6 if pose == Pose.SUPER else 1.0) + 0.3 * sin(_time * 5.0))
	_visor_mat.emission_energy_multiplier = 3.2 + (1.5 if fmod(_time, 4.0) < 0.08 else 0.0)


## level 0 = idle, 1 = partial, 2 = full; `time` drives the pulse.
func set_charge(level: int, time: float) -> void:
	_charge_glow.visible = level > 0 or time > 0.25
	if not _charge_glow.visible:
		return
	var pulse := 0.5 + 0.5 * sin(time * (22.0 if level >= 2 else 14.0))
	var size := 0.5 + 0.25 * level + pulse * 0.25
	_charge_glow.scale = Vector3.ONE * size
	var color := Palette.PLAYER_ENERGY if level < 2 else Palette.PLAYER_ENERGY.lerp(Palette.PLAYER_GOLD, pulse)
	_charge_mat.set_shader_parameter(&"tint", color)


func shoot_kick() -> void:
	_kick = 1.0


func make_fragments() -> Array[Node3D]:
	var pieces: Array[Node3D] = []
	for part in find_children("*", "Node3D", true, false):
		if part.name in PART_NAMES and part.get_child_count() > 0:
			var copy := part.duplicate() as Node3D
			copy.transform = (part as Node3D).global_transform
			pieces.append(copy)
	return pieces
