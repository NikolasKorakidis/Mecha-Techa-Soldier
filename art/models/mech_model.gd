@tool
class_name MechModel
extends Node3D
## Kestrel in mech form (faces +X, feet at y = 0, ~2.7 units tall). Mega Man X / Gundam build
## read in side profile: domed helmet with a gold V-fin, white mask, twin visor eyes and a red
## brow sensor; V chest plates over a glowing core; layered shoulder pauldron with red trim;
## the front arm is the ringed buster; banded waist and skirts; greaves over armoured boots with
## knee fins; a backpack with twin thrusters and wing binders that spread in the air.
## White / blue / gold with red accents.
## Poses are procedural so the controller only reports its state.

enum Pose { IDLE, RUN, AIR, DASH, WALL, HIT, SUPER }

const PART_NAMES: Array[String] = ["LegBack", "LegFront", "Pelvis", "Torso", "ShoulderBack", "ShoulderFront", "Head", "Pack", "ArmCannon"]

const ARMOR_WHITE := Color("e4ebf6")
const ARMOR_BLUE := Color("2a5fe0")
const ARMOR_DEEP := Color("16296b")
const JOINT := Color("171c2e")
const METAL := Color("323c58")
const ACCENT_RED := Color("e0344a")
## Rig yaw toward the camera (radians).
const YAW := 0.4

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
var _wings: Array[Node3D] = []
var _wing_open: float = 0.0


func _ready() -> void:
	ModelKit.clear(self)
	_legs.clear()
	_shins.clear()
	_pack_flames.clear()
	_wings.clear()
	var t := ArtStyle.OUTLINE_THIN
	var white := ModelKit.hull(ARMOR_WHITE, t, 0.6)
	var blue := ModelKit.hull(ARMOR_BLUE, t, 0.6)
	var deep := ModelKit.hull(ARMOR_DEEP, t, 0.45)
	var metal := ModelKit.hull(METAL, t, 0.35)
	var joint := ModelKit.hull(JOINT, t, 0.3)
	var red := ModelKit.hull(ACCENT_RED, t, 0.5)
	var gold := ModelKit.glossy(Palette.PLAYER_GOLD)
	ModelKit.with_outline(gold, t)
	var energy := ModelKit.emissive(Palette.PLAYER_ENERGY, 2.6)
	_visor_mat = ModelKit.emissive(Palette.PLAYER_ENERGY.lerp(Color.WHITE, 0.35), 3.2)
	# Everything hangs off a rig turned three-quarters toward the camera (stays correct when the
	# controller mirrors the model with scale.x), so the chest, fin and armour layers read.
	var rig := ModelKit.group(self, "Rig")
	rig.rotation.y = -YAW

	# Legs (back leg built first so the front one draws over it).
	for i in 2:
		var front := i == 1
		var z := 0.2 if front else -0.2
		var side := signf(z)
		var shell := blue if front else deep
		var plate := white if front else metal
		var hip := ModelKit.group(rig, "LegFront" if front else "LegBack", Vector3(0.0, 1.08, z))
		ModelKit.sphere(hip, 0.15, Vector3.ZERO, joint)
		# Thigh: round inner frame, blue side armour with a light line, white front plate.
		ModelKit.cylinder(hip, 0.14, 0.12, 0.5, Vector3(0, -0.25, 0), joint, Vector3.ZERO, 12)
		ModelKit.box(hip, Vector3(0.3, 0.38, 0.3), Vector3(0.0, -0.22, 0), shell, Vector3(0, 0, -4))
		ModelKit.prism(hip, Vector3(0.12, 0.34, 0.31), Vector3(0.17, -0.22, 0), plate, Vector3(0, 0, -90))
		ModelKit.box(hip, Vector3(0.2, 0.025, 0.02), Vector3(0.0, -0.1, 0.16 * side), energy)
		var knee := ModelKit.group(hip, "Knee", Vector3(0, -0.5, 0))
		ModelKit.sphere(knee, 0.12, Vector3.ZERO, joint)
		# Knee guard: a pointed white cap with a red fin.
		ModelKit.prism(knee, Vector3(0.24, 0.3, 0.3), Vector3(0.15, 0.03, 0), plate, Vector3(0, 0, -90))
		ModelKit.prism(knee, Vector3(0.1, 0.12, 0.08), Vector3(0.26, 0.1, 0.12 * side), red, Vector3(0, 0, -90))
		# Shin: flared white greave, blue calf block with thruster vents, piston behind.
		ModelKit.hex_x(knee, 0.19, 0.52, Vector3(0.02, -0.28, 0), plate, 8, 1.35).rotation_degrees = Vector3(0, 0, 90)
		ModelKit.box(knee, Vector3(0.22, 0.34, 0.38), Vector3(-0.13, -0.26, 0), shell, Vector3(0, 0, 6))
		for k in 3:
			ModelKit.box(knee, Vector3(0.025, 0.18, 0.3), Vector3(-0.25, -0.18 - k * 0.06, 0), joint)
		ModelKit.cylinder(knee, 0.03, 0.03, 0.42, Vector3(-0.08, -0.24, 0.2 * side), metal, Vector3(0, 0, 8), 8)
		ModelKit.box(knee, Vector3(0.44, 0.1, 0.42), Vector3(0.02, -0.03, 0), shell)
		ModelKit.box(knee, Vector3(0.03, 0.28, 0.02), Vector3(0.17, -0.3, 0.2 * side), energy)
		# Foot: sole, white toe with a gold tip, heel block with a thruster port.
		ModelKit.box(knee, Vector3(0.62, 0.13, 0.4), Vector3(0.08, -0.57, 0), shell)
		ModelKit.prism(knee, Vector3(0.2, 0.26, 0.38), Vector3(0.44, -0.55, 0), plate, Vector3(0, 0, -90))
		ModelKit.box(knee, Vector3(0.06, 0.06, 0.3), Vector3(0.53, -0.59, 0), gold)
		ModelKit.box(knee, Vector3(0.18, 0.2, 0.34), Vector3(-0.22, -0.5, 0), metal)
		ModelKit.cylinder(knee, 0.06, 0.06, 0.02, Vector3(-0.32, -0.5, 0), energy, Vector3(0, 0, 90), 10)
		_legs.append(hip)
		_shins.append(knee)

	# Pelvis: dark hip block, white front skirt with a gold V, blue side skirts.
	var pelvis := ModelKit.group(rig, "Pelvis", Vector3(0, 1.12, 0))
	ModelKit.box(pelvis, Vector3(0.46, 0.24, 0.6), Vector3.ZERO, joint)
	ModelKit.prism(pelvis, Vector3(0.24, 0.3, 0.34), Vector3(0.2, -0.06, 0), white, Vector3(0, 0, -90))
	ModelKit.prism(pelvis, Vector3(0.1, 0.12, 0.36), Vector3(0.28, 0.02, 0), gold, Vector3(0, 0, 180))
	for side: float in [1.0, -1.0]:
		ModelKit.box(pelvis, Vector3(0.34, 0.3, 0.06), Vector3(0.0, -0.1, 0.32 * side), blue, Vector3(0, 0, 10))
		ModelKit.box(pelvis, Vector3(0.3, 0.03, 0.02), Vector3(0.0, -0.2, 0.36 * side), energy, Vector3(0, 0, 10))
	ModelKit.box(pelvis, Vector3(0.22, 0.26, 0.44), Vector3(-0.24, -0.04, 0), deep, Vector3(0, 0, -12))

	# Torso: banded waist, blue chest block, white V chest plates, gold vents, the core gem.
	_torso = ModelKit.group(rig, "Torso", Vector3(0, 1.5, 0))
	ModelKit.cylinder(_torso, 0.2, 0.17, 0.26, Vector3(0, -0.24, 0), joint, Vector3.ZERO, 12)
	for k in 2:
		ModelKit.cylinder(_torso, 0.21, 0.21, 0.04, Vector3(0, -0.19 - k * 0.08, 0), metal, Vector3.ZERO, 12)
	ModelKit.box(_torso, Vector3(0.58, 0.46, 0.62), Vector3(-0.02, 0.1, 0), blue)
	ModelKit.box(_torso, Vector3(0.3, 0.2, 0.5), Vector3(0.1, -0.1, 0), white, Vector3(0, 0, 8))
	for side: float in [1.0, -1.0]:
		# Chest plates tilt outwards into a V.
		ModelKit.box(_torso, Vector3(0.36, 0.3, 0.3), Vector3(0.14, 0.18, 0.16 * side), white, Vector3(12 * side, 0, -10))
	ModelKit.box(_torso, Vector3(0.52, 0.09, 0.68), Vector3(-0.02, 0.35, 0), white)
	ModelKit.box(_torso, Vector3(0.6, 0.05, 0.64), Vector3(-0.02, -0.12, 0), deep)
	for k in 3:
		ModelKit.box(_torso, Vector3(0.1, 0.025, 0.12), Vector3(0.25, 0.26 - k * 0.05, 0.3), gold)
	# Chest core: a faceted gem on the camera side, in a gold setting, with a halo.
	var gem := ModelKit.group(_torso, "Core", Vector3(0.12, 0.08, 0.33))
	ModelKit.sphere(gem, 0.1, Vector3.ZERO, ModelKit.emissive(Palette.PLAYER_ENERGY, 3.0), Vector3(1, 1, 0.5))
	ModelKit.cylinder(gem, 0.14, 0.14, 0.03, Vector3(0, 0, -0.01), gold, Vector3(90, 0, 0), 12)
	_core_glow = ModelKit.quad(gem, Vector2.ONE * 0.6, Vector3(0, 0, 0.05), ModelKit.glow(Palette.PLAYER_ENERGY, 1.0))

	# Backpack: armoured pack, two thruster nozzles and a pair of wing binders.
	var pack := ModelKit.group(_torso, "Pack", Vector3(-0.38, 0.08, 0))
	ModelKit.box(pack, Vector3(0.26, 0.5, 0.5), Vector3.ZERO, metal)
	ModelKit.box(pack, Vector3(0.1, 0.42, 0.54), Vector3(-0.13, 0.02, 0), deep)
	ModelKit.box(pack, Vector3(0.12, 0.08, 0.56), Vector3(-0.06, 0.22, 0), white)
	for side: float in [1.0, -1.0]:
		ModelKit.hex_x(pack, 0.09, 0.26, Vector3(-0.18, -0.28, 0.15 * side), joint, 10, 1.3).rotation_degrees = Vector3(0, 0, 60)
		ModelKit.cylinder(pack, 0.06, 0.06, 0.02, Vector3(-0.29, -0.46, 0.15 * side), energy, Vector3(0, 0, 60), 10)
		var flame := ModelKit.quad(pack, Vector2(0.7, 0.24), Vector3(-0.44, -0.62, 0.15 * side + 0.02), ModelKit.glow(Palette.PLAYER_ENERGY, 1.6, ModelKit.GlowShape.STREAK), Vector3(0, 0, 240))
		flame.visible = false
		_pack_flames.append(flame)
		# Wing binder: hinge plus two swept blades (white over blue) with an energy edge.
		var wing := ModelKit.group(pack, "Wing", Vector3(-0.08, 0.18, 0.2 * side))
		ModelKit.sphere(wing, 0.06, Vector3.ZERO, joint)
		var mat := blue if side > 0.0 else deep
		var face := white if side > 0.0 else metal
		ModelKit.box(wing, Vector3(0.62, 0.12, 0.05), Vector3(-0.3, 0.02, 0), face)
		ModelKit.box(wing, Vector3(0.5, 0.1, 0.05), Vector3(-0.28, -0.1, 0.01 * side), mat, Vector3(0, 0, -12))
		ModelKit.prism(wing, Vector3(0.12, 0.2, 0.05), Vector3(-0.66, 0.02, 0), face, Vector3(0, 0, 90))
		ModelKit.box(wing, Vector3(0.5, 0.02, 0.06), Vector3(-0.3, 0.085, 0), energy)
		_wings.append(wing)

	# Head on a short neck: dome helmet, white mask, twin visor eyes, gold V-fin, red sensor.
	_head = ModelKit.group(_torso, "Head", Vector3(0.04, 0.62, 0))
	ModelKit.cylinder(_head, 0.08, 0.09, 0.16, Vector3(0, -0.16, 0), joint, Vector3.ZERO, 10)
	ModelKit.sphere(_head, 0.26, Vector3(-0.06, 0.05, 0), blue, Vector3(1.0, 0.95, 0.9))
	ModelKit.box(_head, Vector3(0.36, 0.1, 0.44), Vector3(-0.04, -0.1, 0), blue)
	ModelKit.box(_head, Vector3(0.16, 0.2, 0.3), Vector3(0.18, -0.06, 0), white)
	ModelKit.prism(_head, Vector3(0.1, 0.1, 0.18), Vector3(0.26, -0.12, 0), white, Vector3(0, 0, -90))
	for side: float in [1.0, -1.0]:
		ModelKit.box(_head, Vector3(0.06, 0.045, 0.1), Vector3(0.26, 0.03, 0.07 * side), _visor_mat, Vector3(0, 0, -8))
	ModelKit.box(_head, Vector3(0.05, 0.02, 0.32), Vector3(0.27, -0.03, 0), joint)
	ModelKit.prism(_head, Vector3(0.14, 0.2, 0.46), Vector3(0.2, 0.15, 0), blue, Vector3(0, 0, -90))
	ModelKit.sphere(_head, 0.045, Vector3(0.27, 0.16, 0), ModelKit.emissive(ACCENT_RED, 2.5))
	for side: float in [1.0, -1.0]:
		# V-fin: two gold blades swept up and out from the forehead.
		ModelKit.prism(_head, Vector3(0.07, 0.38, 0.04), Vector3(0.18, 0.32, 0.1 * side), gold, Vector3(34 * side, 0, -34))
		ModelKit.cylinder(_head, 0.1, 0.1, 0.08, Vector3(-0.04, 0.0, 0.23 * side), white, Vector3(90, 0, 0), 12)
		ModelKit.cylinder(_head, 0.05, 0.05, 0.1, Vector3(-0.04, 0.0, 0.24 * side), energy, Vector3(90, 0, 0), 10)
		ModelKit.prism(_head, Vector3(0.08, 0.26, 0.04), Vector3(-0.2, 0.12, 0.2 * side), blue, Vector3(0, 0, 55))
	ModelKit.box(_head, Vector3(0.4, 0.06, 0.1), Vector3(-0.06, 0.26, 0), white, Vector3(0, 0, -8))

	# Back shoulder and arm (behind the torso, darker).
	var shoulder_b := ModelKit.group(_torso, "ShoulderBack", Vector3(-0.04, 0.24, -0.4))
	ModelKit.sphere(shoulder_b, 0.2, Vector3.ZERO, deep, Vector3(1.1, 0.9, 0.8))
	ModelKit.box(shoulder_b, Vector3(0.4, 0.07, 0.26), Vector3(0, 0.12, -0.02), metal, Vector3(0, 0, -6))
	_arm_back = ModelKit.group(shoulder_b, "Arm", Vector3(0, -0.08, 0))
	ModelKit.cylinder(_arm_back, 0.08, 0.07, 0.32, Vector3(0, -0.16, 0), joint, Vector3.ZERO, 10)
	_forearm_back = ModelKit.group(_arm_back, "Forearm", Vector3(0, -0.32, 0))
	ModelKit.box(_forearm_back, Vector3(0.2, 0.3, 0.2), Vector3(0.04, -0.12, 0), metal)
	ModelKit.box(_forearm_back, Vector3(0.18, 0.14, 0.2), Vector3(0.06, -0.32, 0), joint)

	# Front shoulder pauldron: rounded white shell, blue top plate, red trim, vent slats.
	var shoulder_f := ModelKit.group(_torso, "ShoulderFront", Vector3(-0.1, 0.26, 0.4))
	ModelKit.sphere(shoulder_f, 0.19, Vector3.ZERO, white, Vector3(1.25, 0.95, 0.85))
	ModelKit.box(shoulder_f, Vector3(0.46, 0.08, 0.28), Vector3(0, 0.13, 0.02), blue, Vector3(0, 0, -6))
	ModelKit.box(shoulder_f, Vector3(0.44, 0.06, 0.27), Vector3(0, -0.11, 0.02), red)
	for k in 3:
		ModelKit.box(shoulder_f, Vector3(0.025, 0.12, 0.02), Vector3(-0.08 + k * 0.06, 0.0, 0.17), joint)
	ModelKit.sphere(shoulder_f, 0.04, Vector3(0.14, 0.04, 0.15), gold)

	# Buster: upper arm, armoured forearm, ringed barrel, muzzle light.
	_cannon = ModelKit.group(_torso, "ArmCannon", Vector3(0.0, 0.08, 0.46))
	# Undo the rig's yaw so the buster points straight down the firing line.
	_cannon.rotation.y = YAW
	ModelKit.cylinder(_cannon, 0.08, 0.08, 0.26, Vector3(0, -0.06, 0), joint, Vector3.ZERO, 10)
	ModelKit.hex_x(_cannon, 0.17, 0.62, Vector3(0.32, -0.14, 0), white, 12, 0.92)
	ModelKit.box(_cannon, Vector3(0.38, 0.08, 0.28), Vector3(0.24, 0.0, 0), blue)
	ModelKit.box(_cannon, Vector3(0.16, 0.06, 0.2), Vector3(0.12, 0.06, 0), red)
	ModelKit.hex_x(_cannon, 0.18, 0.08, Vector3(0.52, -0.14, 0), gold, 12)
	ModelKit.hex_x(_cannon, 0.19, 0.12, Vector3(0.66, -0.14, 0), blue, 12)
	ModelKit.hex_x(_cannon, 0.13, 0.06, Vector3(0.75, -0.14, 0), metal, 12)
	ModelKit.cylinder(_cannon, 0.1, 0.1, 0.03, Vector3(0.78, -0.14, 0), energy, Vector3(0, 0, 90), 12)
	ModelKit.box(_cannon, Vector3(0.28, 0.03, 0.02), Vector3(0.32, -0.14, 0.18), energy)
	ModelKit.box(_cannon, Vector3(0.28, 0.03, 0.02), Vector3(0.32, -0.24, 0.16), energy)
	_charge_mat = ModelKit.glow_billboard(Palette.PLAYER_ENERGY, 2.0)
	_charge_glow = ModelKit.quad(_cannon, Vector2.ONE, Vector3(0.86, -0.14, 0.1), _charge_mat)
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
	# Wing binders fold down on the ground and spread up and back in the air / dashing.
	var wing_goal := 1.0 if pose in [Pose.DASH, Pose.SUPER] else (0.6 if pose == Pose.AIR else 0.0)
	_wing_open = lerpf(_wing_open, wing_goal, clampf(delta * 10.0, 0.0, 1.0))
	for k in _wings.size():
		_wings[k].rotation.z = lerpf(1.1, -0.3, _wing_open) + sin(_time * 2.0 + k) * 0.03
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
