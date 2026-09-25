class_name SpacePlanets
extends RefCounted
## The campaign's celestial set — ringed gas giant, red moon, the blue world, the sun — shared by
## the Stage 1 backdrop and the Stage 3 sky so both stages sit in the same star system, seen
## from different angles. Build under a node that follows the camera (planets "at infinity").

enum Layout { HULL_RUN, ORBIT }


static func build(parent: Node3D, layout: Layout) -> void:
	var giant_at := Vector3(1400, 120, 700)
	var giant_r := 260.0
	var ring_rot := Vector3(12, 0, 18)
	var moon_at := Vector3(1300, 330, -900)
	var world_at := Vector3(600, -950, -500)
	var world_r := 700.0
	var sun_at := Vector3(1800, 500, -1100)
	var giant_light := Vector3(-0.6, 0.5, -0.6)
	if layout == Layout.ORBIT:
		# Stage 1 looks the other way across the system: giant high on the left with its rings
		# tipped steeply, the blue world's horizon filling the lower right, the moon far right.
		giant_at = Vector3(-560, 300, -2400)
		giant_r = 240.0
		ring_rot = Vector3(62, 10, -28)
		giant_light = Vector3(0.55, 0.45, 0.7)
		moon_at = Vector3(1000, 420, -1700)
		world_at = Vector3(900, -1250, -1700)
		world_r = 950.0
		sun_at = Vector3(300, 1100, -3200)
	var giant_mat := ShaderMaterial.new()
	giant_mat.shader = preload("res://art/shaders/gas_giant.gdshader")
	giant_mat.set_shader_parameter(&"band_dark", Color(0.35, 0.16, 0.1))
	giant_mat.set_shader_parameter(&"band_mid", Color(0.7, 0.42, 0.22))
	giant_mat.set_shader_parameter(&"band_light", Color(0.95, 0.78, 0.5))
	giant_mat.set_shader_parameter(&"atmosphere", Color(1.0, 0.7, 0.4))
	giant_mat.set_shader_parameter(&"light_direction", giant_light)
	var giant := ModelKit.sphere(parent, giant_r, giant_at, giant_mat)
	(giant.mesh as SphereMesh).radial_segments = 64
	(giant.mesh as SphereMesh).rings = 32
	giant.rotation_degrees = Vector3(0, 0, 18)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = giant_r * 1.27
	torus.outer_radius = giant_r * 1.8
	torus.rings = 96
	torus.ring_segments = 3
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.85, 0.7, 0.5, 0.45)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = ring_mat
	ring.position = giant_at
	ring.scale = Vector3(1, 0.02, 1)
	ring.rotation_degrees = ring_rot
	parent.add_child(ring)
	var moon_mat := ShaderMaterial.new()
	moon_mat.shader = preload("res://art/shaders/gas_giant.gdshader")
	moon_mat.set_shader_parameter(&"band_dark", Color(0.25, 0.06, 0.06))
	moon_mat.set_shader_parameter(&"band_mid", Color(0.5, 0.15, 0.12))
	moon_mat.set_shader_parameter(&"band_light", Color(0.75, 0.35, 0.25))
	moon_mat.set_shader_parameter(&"atmosphere", Color(1.0, 0.4, 0.3))
	ModelKit.sphere(parent, 70.0 if layout == Layout.HULL_RUN else 85.0, moon_at, moon_mat)
	var world_mat := ShaderMaterial.new()
	world_mat.shader = preload("res://art/shaders/gas_giant.gdshader")
	var world := ModelKit.sphere(parent, world_r, world_at, world_mat)
	world.rotation_degrees = Vector3(0, 0, 70)
	(world.mesh as SphereMesh).radial_segments = 64
	(world.mesh as SphereMesh).rings = 32
	# Sun with a warm corona.
	ModelKit.sphere(parent, 30.0, sun_at, ModelKit.emissive(Color(1.0, 0.92, 0.8), 6.0))
	for k in 2:
		var corona := MeshInstance3D.new()
		corona.mesh = QuadMesh.new()
		corona.material_override = ModelKit.glow_billboard(Color(1.0, 0.75, 0.45), [1.2, 0.35][k])
		corona.position = sun_at
		corona.scale = Vector3.ONE * [260.0, 800.0][k]
		parent.add_child(corona)
