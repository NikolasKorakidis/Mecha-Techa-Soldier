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
	var blue := ModelKit.hull(Palette.PLAYER_SECONDARY)
	var dark := ModelKit.hull(Palette.PLAYER_SHADOW.darkened(0.2), ArtStyle.OUTLINE_THIN, 0.3)
	var metal := ModelKit.hull(Color("2b3550"), ArtStyle.OUTLINE_THIN, 0.35)
	var gold := ModelKit.glossy(Palette.PLAYER_GOLD)
	ModelKit.with_outline(gold, ArtStyle.OUTLINE_THIN)
	var energy := ModelKit.emissive(Palette.PLAYER_ENERGY, 2.6)

	# Legs (back leg first so the front one draws over it).
	for i in 2:
		var front := i == 1
		var z := 0.22 if front else -0.22
		var hip := ModelKit.group(self, "LegFront" if front else "LegBack", Vector3(0.0, 1.05, z))
		ModelKit.box(hip, Vector3(0.36, 0.55, 0.34), Vector3(0, -0.25, 0), blue if front else dark)
		var knee := ModelKit.group(hip, "Knee", Vector3(0, -0.52, 0))
		ModelKit.box(knee, Vector3(0.4, 0.5, 0.38), Vector3(0, -0.22, 0), white if front else metal)
		ModelKit.box(knee, Vector3(0.24, 0.16, 0.4), Vector3(0.13, 0.02, 0), gold)
		ModelKit.box(knee, Vector3(0.62, 0.18, 0.42), Vector3(0.1, -0.5, 0), dark)
		_legs.append(hip)
		_shins.append(knee)

	ModelKit.box(ModelKit.group(self, "Pelvis", Vector3(0, 1.1, 0)), Vector3(0.6, 0.28, 0.7), Vector3.ZERO, dark)

	# Torso with chest core and gold visor-plate.
	_torso = ModelKit.group(self, "Torso", Vector3(0, 1.55, 0))
	ModelKit.box(_torso, Vector3(0.8, 0.7, 0.72), Vector3.ZERO, white)
	ModelKit.box(_torso, Vector3(0.84, 0.18, 0.76), Vector3(0, -0.3, 0), blue)
	ModelKit.prism(_torso, Vector3(0.5, 0.3, 0.74), Vector3(0.28, 0.12, 0), white, Vector3(0, 0, -90))
	ModelKit.sphere(_torso, 0.13, Vector3(0.18, 0.02, 0.38), ModelKit.emissive(Palette.PLAYER_ENERGY.lerp(Palette.RESONANCE_VIOLET, 0.35), 3.0))
	_core_glow = ModelKit.quad(_torso, Vector2.ONE * 0.8, Vector3(0.18, 0.02, 0.46), ModelKit.glow(Palette.PLAYER_ENERGY, 1.0))

	# Thruster pack (ex-engines).
	var pack := ModelKit.group(_torso, "Pack", Vector3(-0.5, 0.05, 0))
	for side: float in [1.0, -1.0]:
		ModelKit.hex_x(pack, 0.17, 0.5, Vector3(-0.05, 0.12 * side, 0.18 * side), metal, 8)
		var flame := ModelKit.quad(pack, Vector2(0.9, 0.3), Vector3(-0.3, 0.12 * side - 0.4, 0.18 * side),
				ModelKit.glow(Palette.PLAYER_ENERGY, 2.0, ModelKit.GlowShape.STREAK), Vector3(0, 0, 90))
		flame.visible = false
		_pack_flames.append(flame)

	# Back shoulder + arm.
	var shoulder_b := ModelKit.group(_torso, "ShoulderBack", Vector3(-0.05, 0.3, -0.5))
	ModelKit.box(shoulder_b, Vector3(0.62, 0.42, 0.42), Vector3.ZERO, dark)
	_arm_back = ModelKit.group(shoulder_b, "Arm", Vector3(0, -0.2, 0))
	ModelKit.box(_arm_back, Vector3(0.24, 0.6, 0.24), Vector3(0, -0.3, 0), metal)

	# Head: compact helmet, gold visor band, blue crest.
	_head = ModelKit.group(_torso, "Head", Vector3(0.08, 0.55, 0))
	ModelKit.box(_head, Vector3(0.46, 0.4, 0.46), Vector3.ZERO, white)
	ModelKit.box(_head, Vector3(0.2, 0.12, 0.48), Vector3(0.16, 0.02, 0), gold)
	ModelKit.box(_head, Vector3(0.06, 0.06, 0.1), Vector3(0.27, 0.03, 0.18), energy)
	ModelKit.prism(_head, Vector3(0.14, 0.36, 0.1), Vector3(-0.05, 0.3, 0), blue, Vector3(0, 0, 25))

	# Front shoulder (ex-wing block): big, blue, white strip, cyan edge.
	var shoulder_f := ModelKit.group(_torso, "ShoulderFront", Vector3(-0.05, 0.32, 0.5))
	ModelKit.box(shoulder_f, Vector3(0.78, 0.5, 0.5), Vector3.ZERO, blue)
	ModelKit.box(shoulder_f, Vector3(0.8, 0.08, 0.52), Vector3(0, 0.27, 0), white)
	ModelKit.box(shoulder_f, Vector3(0.6, 0.05, 0.06), Vector3(0.05, 0, 0.27), energy)

	# Arm cannon (ex-nose), pivot at the shoulder so it can kick.
	_cannon = ModelKit.group(_torso, "ArmCannon", Vector3(0.0, 0.05, 0.52))
	ModelKit.hex_x(_cannon, 0.2, 0.75, Vector3(0.3, -0.15, 0), white, 6, 0.9)
	ModelKit.hex_x(_cannon, 0.21, 0.12, Vector3(0.7, -0.15, 0), blue, 6)
	ModelKit.cylinder(_cannon, 0.13, 0.13, 0.04, Vector3(0.77, -0.15, 0), energy, Vector3(0, 0, 90), 8)


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
