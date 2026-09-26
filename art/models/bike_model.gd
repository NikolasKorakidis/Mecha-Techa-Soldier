@tool
class_name BikeModel
extends Node3D
## Kestrel in bike form (faces +X, wheel contact at y = 0, ~1.2 units tall, ~3.6 long): an
## enclosed light-cycle superbike. One narrow oval shell over the machine with fenders hugging
## hubless glowing wheels (tread blocks show the spin), full-length energy lines, a glass canopy
## (ex-head), a pointed nose with headlight and gun (ex-arm cannon), swept winglets
## (ex-shoulders), the chest core in a gold ring, and a tail with a wide red light bar and twin
## thrusters (ex-pack) that read from the chase camera. Same palette as ship and mech.

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
	var t := ArtStyle.OUTLINE_THIN
	var white := ModelKit.hull(Color("e8eef8"), t, 0.6)
	var blue := ModelKit.hull(Color("2a62e6"), t, 0.55)
	var deep := ModelKit.hull(Color("15296e"), t, 0.45)
	var metal := ModelKit.hull(Color("262e46"), t, 0.35)
	var tire := ModelKit.hull(Color("11141d"), t, 0.25)
	var gold := ModelKit.glossy(Palette.PLAYER_GOLD)
	ModelKit.with_outline(gold, t)
	var energy := ModelKit.emissive(Palette.PLAYER_ENERGY, 2.6)
	var tail_red := ModelKit.emissive(Color("ff3548"), 3.0)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.04, 0.1, 0.16)
	glass.metallic = 0.7
	glass.roughness = 0.08
	glass.emission_enabled = true
	# Cyan like the Kestrel canopy: a warm tint read as a bare head from the chase camera.
	glass.emission = Color(0.15, 0.45, 0.65)
	glass.emission_energy_multiplier = 0.45
	glass.rim_enabled = true
	glass.rim = 0.8
	glass.rim_tint = 0.2
	ModelKit.with_outline(glass, t)

	# Hubless wheels: slim tyre with tread blocks (so the spin reads), metal rim, glowing inner ring.
	for i in 2:
		var front := i == 1
		var wheel := ModelKit.group(self, "WheelFront" if front else "WheelBack", Vector3(1.2 if front else -1.15, WHEEL_RADIUS, 0))
		_torus(wheel, WHEEL_RADIUS - 0.11, WHEEL_RADIUS, 0.26, tire)
		_torus(wheel, WHEEL_RADIUS - 0.17, WHEEL_RADIUS - 0.1, 0.22, metal)
		_torus(wheel, WHEEL_RADIUS - 0.21, WHEEL_RADIUS - 0.17, 0.14, energy)
		for k in 14:
			var a := TAU * k / 14.0
			ModelKit.box(wheel, Vector3(0.09, 0.045, 0.27), Vector3(cos(a), sin(a), 0) * (WHEEL_RADIUS - 0.01), tire, Vector3(0, 0, rad_to_deg(a) + 90))
		_wheels.append(wheel)

	# Shell: one long oval body enclosing the machine, fenders over both wheels, energy lines.
	_body = ModelKit.group(self, "Frame", Vector3(0, 0.85, 0))
	var shell := ModelKit.hex_x(_body, 0.34, 2.3, Vector3(0.05, -0.08, 0), white, 16, 0.85)
	shell.scale = Vector3(1.0, 1.0, 0.62)
	var belly := ModelKit.hex_x(_body, 0.3, 2.1, Vector3(0.0, -0.2, 0), deep, 16, 0.9)
	belly.scale = Vector3(1.0, 0.7, 0.66)
	for side: float in [1.0, -1.0]:
		# Fenders hugging the top of each wheel.
		for wx: float in [1.2, -1.15]:
			var fender := ModelKit.sphere(_body, WHEEL_RADIUS + 0.06, Vector3(wx, -0.1, 0.0), blue, Vector3(1.0, 0.5, 0.3))
			fender.name = "Fender"
		# Full-length energy line and a lower accent.
		ModelKit.box(_body, Vector3(2.2, 0.035, 0.02), Vector3(0.05, 0.0, 0.215 * side), energy)
		ModelKit.box(_body, Vector3(1.2, 0.03, 0.02), Vector3(-0.1, -0.2, 0.2 * side), gold)
	# Chest core on the camera side, in a gold ring.
	ModelKit.sphere(_body, 0.1, Vector3(0.0, 0.08, 0.22), ModelKit.emissive(Palette.PLAYER_ENERGY.lerp(Palette.RESONANCE_VIOLET, 0.35), 3.0))
	ModelKit.cylinder(_body, 0.13, 0.13, 0.03, Vector3(0.0, 0.08, 0.2), gold, Vector3(90, 0, 0), 14)
	_core_glow = ModelKit.quad(_body, Vector2.ONE * 0.7, Vector3(0.0, 0.08, 0.3), ModelKit.glow(Palette.PLAYER_ENERGY, 1.0))

	# Canopy (ex-head): glass bubble set into the shell toward the front.
	var canopy := ModelKit.group(_body, "Canopy", Vector3(0.3, 0.22, 0))
	ModelKit.sphere(canopy, 0.22, Vector3.ZERO, glass, Vector3(2.4, 0.7, 0.85))
	ModelKit.box(canopy, Vector3(0.9, 0.04, 0.3), Vector3(-0.05, -0.1, 0), gold)
	# Frame spine over the glass so the dome reads as a cockpit from behind.
	ModelKit.box(canopy, Vector3(0.6, 0.03, 0.035), Vector3(0.0, 0.14, 0), gold)

	# Fairing: pointed nose, headlight, running lights and the nose gun (ex-arm cannon).
	_fairing = ModelKit.group(_body, "Fairing", Vector3(1.15, -0.05, 0))
	var nose := ModelKit.cone_x(_fairing, 0.3, 0.6, Vector3(0.35, 0.0, 0), white, 16)
	nose.scale = Vector3(1.0, 1.0, 0.62)
	ModelKit.box(_fairing, Vector3(0.05, 0.1, 0.22), Vector3(0.5, 0.02, 0), ModelKit.emissive(Color(0.85, 0.95, 1.0), 4.0))
	for side: float in [1.0, -1.0]:
		ModelKit.box(_fairing, Vector3(0.36, 0.025, 0.02), Vector3(0.3, 0.1, 0.16 * side), energy, Vector3(0, 0, -18))
	ModelKit.hex_x(_fairing, 0.07, 0.5, Vector3(0.3, -0.2, 0.17), metal, 10, 0.9)
	ModelKit.cylinder(_fairing, 0.05, 0.05, 0.03, Vector3(0.56, -0.2, 0.17), energy, Vector3(0, 0, 90), 10)

	# Winglet fins (ex-shoulders) sweeping back off the tail.
	for side: float in [1.0, -1.0]:
		var fin := ModelKit.group(_body, "Fin", Vector3(-0.85, 0.18, 0.16 * side))
		ModelKit.prism(fin, Vector3(0.5, 0.36, 0.05), Vector3.ZERO, blue, Vector3(20 * side, 0, 60))
		ModelKit.box(fin, Vector3(0.38, 0.03, 0.03), Vector3(0.02, 0.1, 0.03 * side), energy, Vector3(20 * side, 0, 60))

	# Tail: tapered cone, a wide red light bar high on the back, twin thrusters beneath.
	var exhaust := ModelKit.group(_body, "Exhaust", Vector3(-1.1, -0.04, 0))
	var tail := ModelKit.cone_x(exhaust, 0.3, 0.45, Vector3(-0.15, 0.0, 0), white, 16, true)
	tail.scale = Vector3(1.0, 1.0, 0.62)
	ModelKit.box(exhaust, Vector3(0.05, 0.05, 0.3), Vector3(-0.4, 0.02, 0), tail_red)
	ModelKit.box(exhaust, Vector3(0.05, 0.16, 0.05), Vector3(-0.4, 0.02, 0), tail_red)
	var tail_glow := MeshInstance3D.new()
	tail_glow.mesh = QuadMesh.new()
	tail_glow.material_override = ModelKit.glow_billboard(Color("ff3548"), 1.2)
	tail_glow.position = Vector3(-0.44, 0.02, 0)
	tail_glow.scale = Vector3.ONE * 0.55
	exhaust.add_child(tail_glow)
	for side: float in [1.0, -1.0]:
		ModelKit.hex_x(exhaust, 0.09, 0.4, Vector3(-0.05, -0.2, 0.12 * side), metal, 10, 1.15)
		ModelKit.cylinder(exhaust, 0.07, 0.07, 0.02, Vector3(-0.26, -0.2, 0.12 * side), energy, Vector3(0, 0, 90), 10)
		var flame := ModelKit.quad(exhaust, Vector2(1.0, 0.24), Vector3(-0.78, -0.2, 0.12 * side),
				ModelKit.glow(Palette.PLAYER_ENERGY, 1.8, ModelKit.GlowShape.STREAK))
		_flames.append(flame)
		# Camera-facing burn so the exhaust reads from the chase camera behind.
		var rear := MeshInstance3D.new()
		rear.mesh = QuadMesh.new()
		rear.material_override = ModelKit.glow_billboard(Palette.PLAYER_ENERGY, 1.4)
		rear.position = Vector3(-0.32, -0.2, 0.12 * side)
		rear.scale = Vector3.ONE * 0.5
		exhaust.add_child(rear)
		_rear_glows.append(rear)


## Tyre / rim ring in the wheel plane (XY), `depth` wide along Z.
func _torus(parent: Node3D, inner: float, outer: float, depth: float, mat: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 10
	var node := ModelKit._add(parent, mesh, Vector3.ZERO, mat, Vector3(90, 0, 0))
	node.scale = Vector3(1.0, depth / maxf(outer - inner, 0.01), 1.0)
	return node


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
