@tool
class_name MechModel
extends Node3D
## Kestrel in mech form (faces +X, feet at y = 0, ~2.5 units tall). The wing blocks became
## shoulders, the rear engines a thruster pack, the nose an arm cannon — same palette and motifs.
## Poses are procedural so the controller only reports its state.

enum Pose { IDLE, RUN, AIR, DASH, WALL, HIT, SUPER }

const PART_NAMES: Array[String] = ["LegBack", "LegFront", "Pelvis", "Torso", "ShoulderBack", "ShoulderFront", "Head", "Pack", "ArmCannon"]

var pose: Pose = Pose.IDLE
var run_ratio: float = 0.0

var _legs: Array[Node3D] = []
var _shins: Array[Node3D] = []
var _torso: Node3D
var _cannon: Node3D
var _arm_back: Node3D
var _head: Node3D
var _pack_flames: Array[MeshInstance3D] = []
var _core_glow: MeshInstance3D
var _phase: float = 0.0
var _kick: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	ModelKit.clear(self)
	_legs.clear()
	_shins.clear()
	_pack_flames.clear()
	var white := ModelKit.hull(Palette.PLAYER_PRIMARY)
	var white_thin := ModelKit.hull(Palette.PLAYER_PRIMARY, ArtStyle.OUTLINE_THIN)
	var blue := ModelKit.hull(Palette.PLAYER_SECONDARY)
	var blue_thin := ModelKit.hull(Palette.PLAYER_SECONDARY, ArtStyle.OUTLINE_THIN)
	var dark := ModelKit.hull(Palette.PLAYER_SHADOW.darkened(0.2), ArtStyle.OUTLINE_THIN, 0.3)
	var metal := ModelKit.hull(Color("2b3550"), ArtStyle.OUTLINE_THIN, 0.35)
	var joint := ModelKit.hull(Color("1a2033"), ArtStyle.OUTLINE_THIN, 0.3)
	var gold := ModelKit.glossy(Palette.PLAYER_GOLD)
	ModelKit.with_outline(gold, ArtStyle.OUTLINE_THIN)
	var energy := ModelKit.emissive(Palette.PLAYER_ENERGY, 2.6)
	var visor := ModelKit.emissive(Palette.PLAYER_ENERGY.lerp(Color.WHITE, 0.3), 3.2)

	# Legs (back leg first so the front one draws over it): thigh armour, knee cap,
	# shin with vents and an energy line, articulated foot.
	for i in 2:
		var front := i == 1
		var z := 0.22 if front else -0.22
		var hip := ModelKit.group(self, "LegFront" if front else "LegBack", Vector3(0.0, 1.05, z))
		ModelKit.sphere(hip, 0.17, Vector3.ZERO, joint)
		ModelKit.box(hip, Vector3(0.34, 0.52, 0.32), Vector3(0, -0.26, 0), metal)
		ModelKit.box(hip, Vector3(0.3, 0.42, 0.36), Vector3(0.06, -0.24, 0), blue_thin if front else dark)
		ModelKit.box(hip, Vector3(0.08, 0.3, 0.37), Vector3(0.2, -0.26, 0), white_thin if front else metal)
		var knee := ModelKit.group(hip, "Knee", Vector3(0, -0.52, 0))
		ModelKit.sphere(knee, 0.15, Vector3.ZERO, joint)
		ModelKit.box(knee, Vector3(0.4, 0.52, 0.38), Vector3(0, -0.24, 0), white if front else metal)
		ModelKit.prism(knee, Vector3(0.22, 0.22, 0.4), Vector3(0.16, 0.03, 0), gold, Vector3(0, 0, -90))
		for k in 3:
			ModelKit.box(knee, Vector3(0.12, 0.04, 0.39), Vector3(-0.1, -0.16 - k * 0.08, 0), joint)
		ModelKit.box(knee, Vector3(0.04, 0.3, 0.02), Vector3(0.16, -0.26, 0.2 * signf(z)), energy)
		# Foot: ankle block, sole, toe cap, heel spur.
		ModelKit.box(knee, Vector3(0.28, 0.12, 0.3), Vector3(0, -0.46, 0), joint)
		ModelKit.box(knee, Vector3(0.66, 0.16, 0.42), Vector3(0.1, -0.54, 0), dark)
		ModelKit.prism(knee, Vector3(0.3, 0.22, 0.4), Vector3(0.42, -0.52, 0), blue_thin if front else metal, Vector3(0, 0, -90))
		ModelKit.box(knee, Vector3(0.14, 0.14, 0.3), Vector3(-0.24, -0.5, 0), metal)
		_legs.append(hip)
		_shins.append(knee)

	# Pelvis: hip skirt plates and belt light.
	var pelvis := ModelKit.group(self, "Pelvis", Vector3(0, 1.1, 0))
	ModelKit.box(pelvis, Vector3(0.6, 0.28, 0.7), Vector3.ZERO, dark)
	ModelKit.box(pelvis, Vector3(0.28, 0.32, 0.3), Vector3(0.22, -0.06, 0), white_thin)
	for side: float in [1.0, -1.0]:
		ModelKit.box(pelvis, Vector3(0.36, 0.34, 0.08), Vector3(0.02, -0.12, 0.38 * side), blue_thin, Vector3(0, 0, 6))
	ModelKit.box(pelvis, Vector3(0.1, 0.08, 0.72), Vector3(0.3, 0.08, 0), energy)

	# Torso: chest plates, abdomen segments, collar, vents, chest core.
	_torso = ModelKit.group(self, "Torso", Vector3(0, 1.55, 0))
	ModelKit.box(_torso, Vector3(0.44, 0.26, 0.56), Vector3(0, -0.36, 0), joint)
	for k in 2:
		ModelKit.box(_torso, Vector3(0.46, 0.08, 0.6), Vector3(0.02, -0.29 - k * 0.1, 0), metal)
	ModelKit.box(_torso, Vector3(0.8, 0.62, 0.72), Vector3(0, 0.04, 0), white)
	ModelKit.box(_torso, Vector3(0.84, 0.16, 0.76), Vector3(0, -0.24, 0), blue)
	ModelKit.prism(_torso, Vector3(0.5, 0.3, 0.74), Vector3(0.28, 0.14, 0), white, Vector3(0, 0, -90))
	ModelKit.box(_torso, Vector3(0.34, 0.05, 0.02), Vector3(0.12, 0.26, 0.37), joint)
	for k in 3:
		ModelKit.box(_torso, Vector3(0.22, 0.04, 0.02), Vector3(-0.2, 0.12 - k * 0.08, 0.37), joint)
	ModelKit.box(_torso, Vector3(0.62, 0.14, 0.6), Vector3(-0.02, 0.38, 0), dark)
	ModelKit.cylinder(_torso, 0.17, 0.17, 0.06, Vector3(0.18, 0.02, 0.37), metal, Vector3(90, 0, 0), 10)
	ModelKit.sphere(_torso, 0.13, Vector3(0.18, 0.02, 0.4), ModelKit.emissive(Palette.PLAYER_ENERGY.lerp(Palette.RESONANCE_VIOLET, 0.35), 3.0))
	_core_glow = ModelKit.quad(_torso, Vector2.ONE * 0.8, Vector3(0.18, 0.02, 0.48), ModelKit.glow(Palette.PLAYER_ENERGY, 1.0))

	# Thruster pack (ex-engines) with stabiliser fins.
	var pack := ModelKit.group(_torso, "Pack", Vector3(-0.5, 0.05, 0))
	ModelKit.box(pack, Vector3(0.3, 0.6, 0.62), Vector3(0.05, 0.02, 0), dark)
	for side: float in [1.0, -1.0]:
		ModelKit.hex_x(pack, 0.17, 0.5, Vector3(-0.05, 0.12 * side, 0.18 * side), metal, 8)
		ModelKit.hex_x(pack, 0.19, 0.08, Vector3(-0.3, 0.12 * side, 0.18 * side), energy, 8)
		var flame := ModelKit.quad(pack, Vector2(0.9, 0.3), Vector3(-0.3, 0.12 * side - 0.4, 0.18 * side),
				ModelKit.glow(Palette.PLAYER_ENERGY, 2.0, ModelKit.GlowShape.STREAK), Vector3(0, 0, 90))
		flame.visible = false
		_pack_flames.append(flame)
	ModelKit.prism(pack, Vector3(0.2, 0.6, 0.1), Vector3(-0.2, 0.5, 0), blue_thin, Vector3(0, 0, 30))

	# Back shoulder + arm with forearm and fist.
	var shoulder_b := ModelKit.group(_torso, "ShoulderBack", Vector3(-0.05, 0.3, -0.5))
	ModelKit.box(shoulder_b, Vector3(0.62, 0.42, 0.42), Vector3.ZERO, dark)
	ModelKit.box(shoulder_b, Vector3(0.64, 0.08, 0.44), Vector3(0, 0.2, 0), metal)
	_arm_back = ModelKit.group(shoulder_b, "Arm", Vector3(0, -0.2, 0))
	ModelKit.box(_arm_back, Vector3(0.22, 0.34, 0.22), Vector3(0, -0.17, 0), joint)
	ModelKit.box(_arm_back, Vector3(0.28, 0.36, 0.28), Vector3(0.02, -0.48, 0), metal)
	ModelKit.box(_arm_back, Vector3(0.24, 0.2, 0.26), Vector3(0.04, -0.72, 0), dark)

	# Head: helmet, faceplate, glowing visor, ear pods, twin antennae, crest.
	_head = ModelKit.group(_torso, "Head", Vector3(0.08, 0.55, 0))
	ModelKit.box(_head, Vector3(0.3, 0.14, 0.3), Vector3(-0.02, -0.2, 0), joint)
	ModelKit.box(_head, Vector3(0.46, 0.4, 0.46), Vector3.ZERO, white)
	ModelKit.box(_head, Vector3(0.18, 0.2, 0.4), Vector3(0.2, -0.08, 0), metal)
	ModelKit.box(_head, Vector3(0.14, 0.1, 0.48), Vector3(0.2, 0.05, 0), gold)
	ModelKit.box(_head, Vector3(0.05, 0.06, 0.44), Vector3(0.28, 0.05, 0), visor)
	for side: float in [1.0, -1.0]:
		ModelKit.cylinder(_head, 0.1, 0.1, 0.08, Vector3(-0.04, 0.0, 0.25 * side), blue_thin, Vector3(90, 0, 0), 8)
		ModelKit.box(_head, Vector3(0.03, 0.34, 0.03), Vector3(-0.1, 0.3, 0.2 * side), metal, Vector3(0, 0, 18))
	ModelKit.prism(_head, Vector3(0.14, 0.36, 0.1), Vector3(-0.05, 0.3, 0), blue, Vector3(0, 0, 25))

	# Front shoulder (ex-wing block): layered pauldron, white strip, cyan edge, running light.
	var shoulder_f := ModelKit.group(_torso, "ShoulderFront", Vector3(-0.05, 0.32, 0.5))
	ModelKit.box(shoulder_f, Vector3(0.78, 0.5, 0.5), Vector3.ZERO, blue)
	ModelKit.box(shoulder_f, Vector3(0.8, 0.08, 0.52), Vector3(0, 0.27, 0), white)
	ModelKit.box(shoulder_f, Vector3(0.66, 0.16, 0.54), Vector3(0.02, -0.2, 0), dark)
	ModelKit.box(shoulder_f, Vector3(0.6, 0.05, 0.06), Vector3(0.05, 0, 0.27), energy)
	ModelKit.sphere(shoulder_f, 0.05, Vector3(0.38, 0.14, 0.26), ModelKit.emissive(Palette.PLAYER_GOLD, 3.0))
	ModelKit.prism(shoulder_f, Vector3(0.3, 0.2, 0.3), Vector3(-0.38, 0.1, 0), blue_thin, Vector3(0, 0, 90))

	# Arm cannon (ex-nose): forearm armour, barrel with rings, heat vents, charge coil.
	_cannon = ModelKit.group(_torso, "ArmCannon", Vector3(0.0, 0.05, 0.52))
	ModelKit.box(_cannon, Vector3(0.24, 0.34, 0.24), Vector3(0, -0.12, 0), joint)
	ModelKit.hex_x(_cannon, 0.2, 0.75, Vector3(0.3, -0.15, 0), white, 6, 0.9)
	ModelKit.box(_cannon, Vector3(0.44, 0.1, 0.3), Vector3(0.22, 0.03, 0), blue_thin)
	for k in 3:
		ModelKit.box(_cannon, Vector3(0.04, 0.06, 0.32), Vector3(0.1 + k * 0.1, 0.1, 0), joint)
	ModelKit.hex_x(_cannon, 0.21, 0.12, Vector3(0.7, -0.15, 0), blue, 6)
	ModelKit.hex_x(_cannon, 0.23, 0.05, Vector3(0.52, -0.15, 0), gold, 6)
	ModelKit.cylinder(_cannon, 0.13, 0.13, 0.04, Vector3(0.77, -0.15, 0), energy, Vector3(0, 0, 90), 8)
	ModelKit.box(_cannon, Vector3(0.3, 0.03, 0.02), Vector3(0.36, -0.15, 0.21), energy)


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
	match pose:
		Pose.IDLE:
			bob = sin(_time * 3.0) * 0.02
		Pose.RUN:
			leg_swing = sin(_phase) * 0.75 * clampf(speed_ratio, 0.3, 1.0)
			knee_bend = [maxf(0.0, -sin(_phase)) * 0.9, maxf(0.0, sin(_phase)) * 0.9]
			lean = -0.12
			bob = absf(sin(_phase)) * 0.06
		Pose.AIR:
			leg_swing = 0.35
			knee_bend = [0.9, 0.5]
		Pose.DASH:
			leg_swing = -0.7
			knee_bend = [0.2, 0.6]
			lean = -0.35
		Pose.WALL:
			leg_swing = 0.2
			knee_bend = [0.6, 0.3]
			lean = 0.15
		Pose.HIT:
			lean = 0.3
			knee_bend = [0.3, 0.3]
		Pose.SUPER:
			leg_swing = 0.25
			knee_bend = [0.5, 0.2]
			lean = -0.1
	_legs[0].rotation.z = leg_swing
	_legs[1].rotation.z = -leg_swing
	_shins[0].rotation.z = -knee_bend[0]
	_shins[1].rotation.z = -knee_bend[1]
	_torso.rotation.z = lean
	_torso.position.y = 1.55 + bob
	_cannon.rotation.z = -_kick * 0.25
	_cannon.position.x = -_kick * 0.12
	_arm_back.rotation.z = -leg_swing * 0.8
	var thrust := pose in [Pose.DASH, Pose.AIR, Pose.SUPER]
	for flame in _pack_flames:
		flame.visible = thrust
		flame.scale = Vector3(1.6 if pose == Pose.DASH else 0.8 + 0.2 * sin(_time * 40.0), 1, 1)
	(_core_glow.material_override as ShaderMaterial).set_shader_parameter(
			&"energy", (2.6 if pose == Pose.SUPER else 1.0) + 0.3 * sin(_time * 5.0))


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
