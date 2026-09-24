@tool
class_name BikeModel
extends Node3D
## Kestrel in bike form (faces +X, wheel contact at y = 0, ~1.7 units tall, ~3.2 long).
## The arm cannon became the front fairing gun, the shoulders side fins, the pack the exhaust,
## the head a low canopy — same palette so it reads as the same machine.

enum Pose { RIDE, AIR, DUCK, BOOST, HIT }

const PART_NAMES: Array[String] = ["WheelBack", "WheelFront", "Frame", "Fairing", "Canopy", "Fin", "Exhaust"]
const WHEEL_RADIUS := 0.5

var pose: Pose = Pose.RIDE

var _wheels: Array[Node3D] = []
var _body: Node3D
var _fairing: Node3D
var _flames: Array[MeshInstance3D] = []
var _rear_glows: Array[MeshInstance3D] = []
var _core_glow: MeshInstance3D
var _time: float = 0.0
var _kick: float = 0.0
var _tilt: float = 0.0
var _squash: float = 0.0


func _ready() -> void:
	ModelKit.clear(self)
	_wheels.clear()
	_flames.clear()
	_rear_glows.clear()
	var white := ModelKit.hull(Palette.PLAYER_PRIMARY)
	var blue := ModelKit.hull(Palette.PLAYER_SECONDARY)
	var dark := ModelKit.hull(Palette.PLAYER_SHADOW.darkened(0.2), ArtStyle.OUTLINE_THIN, 0.3)
	var metal := ModelKit.hull(Color("2b3550"), ArtStyle.OUTLINE_THIN, 0.35)
	var tire := ModelKit.hull(Color("151a26"), ArtStyle.OUTLINE_THIN, 0.2)
	var gold := ModelKit.glossy(Palette.PLAYER_GOLD)
	ModelKit.with_outline(gold, ArtStyle.OUTLINE_THIN)
	var energy := ModelKit.emissive(Palette.PLAYER_ENERGY, 2.6)

	# Wheels: chunky tire, glowing hub ring, spokes that visibly spin.
	for i in 2:
		var front := i == 1
		var wheel := ModelKit.group(self, "WheelFront" if front else "WheelBack", Vector3(1.15 if front else -1.1, WHEEL_RADIUS, 0))
		ModelKit.cylinder(wheel, WHEEL_RADIUS, WHEEL_RADIUS, 0.42, Vector3.ZERO, tire, Vector3(90, 0, 0), 12)
		ModelKit.cylinder(wheel, 0.3, 0.3, 0.46, Vector3.ZERO, metal, Vector3(90, 0, 0), 8)
		ModelKit.cylinder(wheel, 0.12, 0.12, 0.5, Vector3.ZERO, energy, Vector3(90, 0, 0), 8)
		for s in 3:
			ModelKit.box(wheel, Vector3(0.08, 0.56, 0.05), Vector3(0, 0, 0.24), gold, Vector3(0, 0, s * 60))
		_wheels.append(wheel)

	_body = ModelKit.group(self, "Frame", Vector3(0, 0.85, 0))
	# Chassis spine and swingarm.
	ModelKit.box(_body, Vector3(2.0, 0.34, 0.5), Vector3(0.0, 0.0, 0), dark)
	ModelKit.box(_body, Vector3(0.9, 0.16, 0.3), Vector3(-0.75, -0.3, 0), metal, Vector3(0, 0, 18))
	ModelKit.box(_body, Vector3(0.7, 0.16, 0.3), Vector3(0.85, -0.25, 0), metal, Vector3(0, 0, -30))
	# Tank / core housing with chest core.
	ModelKit.box(_body, Vector3(1.1, 0.42, 0.62), Vector3(0.1, 0.3, 0), white)
	ModelKit.box(_body, Vector3(1.14, 0.12, 0.66), Vector3(0.1, 0.08, 0), blue)
	ModelKit.sphere(_body, 0.13, Vector3(0.15, 0.3, 0.34), ModelKit.emissive(Palette.PLAYER_ENERGY.lerp(Palette.RESONANCE_VIOLET, 0.35), 3.0))
	_core_glow = ModelKit.quad(_body, Vector2.ONE * 0.8, Vector3(0.15, 0.3, 0.42), ModelKit.glow(Palette.PLAYER_ENERGY, 1.0))

	# Canopy (ex-head) low over the tank, gold visor.
	var canopy := ModelKit.group(_body, "Canopy", Vector3(-0.35, 0.58, 0))
	ModelKit.box(canopy, Vector3(0.6, 0.26, 0.46), Vector3.ZERO, white)
	ModelKit.prism(canopy, Vector3(0.28, 0.4, 0.44), Vector3(0.38, -0.02, 0), gold, Vector3(0, 0, -90))
	ModelKit.prism(canopy, Vector3(0.12, 0.34, 0.1), Vector3(-0.3, 0.14, 0), blue, Vector3(0, 0, 60))

	# Fairing + nose gun (ex-arm cannon).
	_fairing = ModelKit.group(_body, "Fairing", Vector3(0.85, 0.2, 0))
	ModelKit.prism(_fairing, Vector3(0.5, 0.7, 0.6), Vector3(0.2, 0.05, 0), blue, Vector3(0, 0, -90))
	ModelKit.hex_x(_fairing, 0.14, 0.6, Vector3(0.45, -0.18, 0.2), white, 6, 0.9)
	ModelKit.cylinder(_fairing, 0.09, 0.09, 0.04, Vector3(0.76, -0.18, 0.2), energy, Vector3(0, 0, 90), 8)
	ModelKit.box(_fairing, Vector3(0.1, 0.08, 0.62), Vector3(0.42, 0.25, 0), energy)

	# Side fin (ex-shoulder block) with a cyan edge strip.
	for side: float in [1.0, -1.0]:
		var fin := ModelKit.group(_body, "Fin", Vector3(-0.35, 0.05, 0.4 * side))
		ModelKit.box(fin, Vector3(0.9, 0.36, 0.2), Vector3.ZERO, blue, Vector3(0, 0, -8))
		ModelKit.box(fin, Vector3(0.8, 0.05, 0.05), Vector3(0.0, 0.0, 0.11 * side), energy, Vector3(0, 0, -8))

	# Exhaust (ex-thruster pack).
	var exhaust := ModelKit.group(_body, "Exhaust", Vector3(-1.05, 0.12, 0))
	for side: float in [1.0, -1.0]:
		ModelKit.hex_x(exhaust, 0.13, 0.45, Vector3(0, 0, 0.18 * side), metal, 8)
		var flame := ModelKit.quad(exhaust, Vector2(1.0, 0.3), Vector3(-0.55, 0, 0.18 * side),
				ModelKit.glow(Palette.PLAYER_ENERGY, 1.8, ModelKit.GlowShape.STREAK))
		_flames.append(flame)
		# Camera-facing burn so the exhaust reads from the chase camera behind.
		var rear := MeshInstance3D.new()
		rear.mesh = QuadMesh.new()
		rear.material_override = ModelKit.glow_billboard(Palette.PLAYER_ENERGY, 1.6)
		rear.position = Vector3(-0.35, 0, 0.18 * side)
		rear.scale = Vector3.ONE * 0.8
		exhaust.add_child(rear)
		_rear_glows.append(rear)
	# Tail light bar and under-glow.
	ModelKit.box(exhaust, Vector3(0.06, 0.1, 0.5), Vector3(0.1, 0.28, 0), ModelKit.emissive(Palette.DANGER, 2.5))


## speed_ratio 0..1 drives wheel spin and flame length.
func update_pose(new_pose: Pose, speed: float, speed_ratio: float, delta: float) -> void:
	pose = new_pose
	_time += delta
	_kick = maxf(0.0, _kick - delta * 8.0)
	for wheel in _wheels:
		wheel.rotation.z -= speed / WHEEL_RADIUS * delta
	var tilt_goal := 0.0
	var squash_goal := 0.0
	match pose:
		Pose.AIR:
			tilt_goal = 0.12
		Pose.DUCK:
			squash_goal = 1.0
		Pose.BOOST:
			tilt_goal = 0.08
		Pose.HIT:
			tilt_goal = -0.2
	_tilt = lerpf(_tilt, tilt_goal, clampf(delta * 10.0, 0.0, 1.0))
	_squash = lerpf(_squash, squash_goal, clampf(delta * 16.0, 0.0, 1.0))
	_body.rotation.z = _tilt
	_body.position.y = 0.85 - 0.3 * _squash + sin(_time * 30.0) * 0.012 * speed_ratio
	_body.scale = Vector3(1.0 + 0.1 * _squash, 1.0 - 0.3 * _squash, 1.0)
	_fairing.position.x = 0.85 - _kick * 0.1
	var length := (2.4 if pose == Pose.BOOST else 0.7 + 0.6 * speed_ratio) + 0.15 * sin(_time * 45.0)
	for flame in _flames:
		flame.scale = Vector3(length, 1, 1)
		flame.position.x = -0.5 * length
	for rear in _rear_glows:
		rear.scale = Vector3.ONE * (0.5 + 0.35 * length)
	(_core_glow.material_override as ShaderMaterial).set_shader_parameter(&"energy", 1.0 + 0.3 * sin(_time * 5.0))


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
