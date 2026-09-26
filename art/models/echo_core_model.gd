class_name EchoCoreModel
extends Node3D
## Echo weapon core pickup: a faceted energy crystal in a fresnel energy shell, two gold gyro
## rings precessing around it, orbiting sparks and the module's initial in front.
## Visual only; EchoPickup owns behaviour.

const RING_RADIUS := 0.78

var _crystal: MeshInstance3D
var _crystal_mat: StandardMaterial3D
## Pivot (precesses around Y) -> ring (spins in its own plane), per gyro.
var _pivots: Array[Node3D] = []
var _rings: Array[Node3D] = []
var _orbit: Node3D
var _time: float = 0.0


func setup(color: Color, letter: String) -> void:
	ModelKit.clear(self)
	_pivots.clear()
	_rings.clear()
	ModelKit.quad(self, Vector2.ONE * 2.8, Vector3(0, 0, -0.8), ModelKit.glow(color, 0.9))
	_crystal_mat = StandardMaterial3D.new()
	_crystal_mat.albedo_color = color.lerp(Color.WHITE, 0.35)
	_crystal_mat.metallic = 0.25
	_crystal_mat.roughness = 0.12
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = color
	_crystal_mat.emission_energy_multiplier = 1.1
	_crystal_mat.rim_enabled = true
	_crystal_mat.rim = 0.6
	_crystal_mat.rim_tint = 0.3
	_crystal = ModelKit._add(self, _bipyramid(0.34, 0.52, 6), Vector3.ZERO, _crystal_mat, Vector3.ZERO)
	var shell := ModelKit.sphere(self, 0.62, Vector3.ZERO, ModelKit.fresnel_shell(color.lerp(Color.WHITE, 0.3), 1.2, 2.2))
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gold := ModelKit.glossy(Palette.PLAYER_GOLD)
	var nub := ModelKit.emissive(color, 2.4)
	for k in 2:
		var radius := RING_RADIUS - k * 0.12
		var pivot := ModelKit.group(self, "Gyro%d" % k)
		pivot.rotation = Vector3(deg_to_rad([64.0, -50.0][k]), k * PI * 0.5, deg_to_rad([16.0, -28.0][k]))
		var ring := ModelKit.group(pivot, "Ring")
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.05
		torus.outer_radius = radius
		torus.rings = 40
		torus.ring_segments = 8
		ModelKit._add(ring, torus, Vector3.ZERO, gold, Vector3.ZERO)
		for side: float in [-1.0, 1.0]:
			ModelKit.sphere(ring, 0.065, Vector3(side * (radius - 0.025), 0, 0), nub)
		_pivots.append(pivot)
		_rings.append(ring)
	_orbit = ModelKit.group(self, "Orbit")
	_orbit.rotation.x = deg_to_rad(-20.0)
	for k in 3:
		var a := TAU * k / 3.0
		ModelKit.quad(_orbit, Vector2.ONE * 0.34, Vector3(cos(a), sin(a), 0) * 1.0, ModelKit.glow(color.lerp(Color.WHITE, 0.5), 1.6))
	var label := Label3D.new()
	label.text = letter
	label.font = UiStyle.DISPLAY_FONT
	label.font_size = 88
	label.pixel_size = 0.0055
	label.outline_size = 22
	label.outline_modulate = Color(0.02, 0.04, 0.1)
	label.position = Vector3(0, 0, 0.72)
	add_child(label)


func _process(delta: float) -> void:
	if _crystal == null:
		return
	_time += delta
	_crystal.rotation.y += delta * 1.6
	_crystal_mat.emission_energy_multiplier = 1.1 + 0.3 * sin(_time * 5.0)
	for k in _pivots.size():
		_pivots[k].rotation.y += delta * [1.3, -0.9][k]
		_rings[k].rotation.y += delta * [3.0, -2.2][k]
	_orbit.rotation.z += delta * 2.4


## Faceted double pyramid (flat-shaded gem), `sides` around, points on ±Y.
static func _bipyramid(radius: float, half_height: float, sides: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tips: Array[Vector3] = [Vector3(0, half_height, 0), Vector3(0, -half_height, 0)]
	for k in sides:
		var a := Vector3(cos(TAU * k / sides), 0, sin(TAU * k / sides)) * radius
		var b := Vector3(cos(TAU * (k + 1) / sides), 0, sin(TAU * (k + 1) / sides)) * radius
		for tip in tips:
			var tri := [tip, a, b]
			var n: Vector3 = (b - tip).cross(a - tip).normalized()
			if n.dot(tip + a + b) < 0.0:
				# Reorder so the face is clockwise seen from outside (Godot's front face).
				tri = [tip, b, a]
				n = -n
			for v: Vector3 in tri:
				st.set_normal(n)
				st.add_vertex(v)
	return st.commit()
