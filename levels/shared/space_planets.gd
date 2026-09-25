class_name SpacePlanets
extends RefCounted
## The campaign's star system — ringed gas giant, red moon, the blue ocean world, the sun —
## drawn by the space_vista sky shader (ray-traced spheres at infinity, no meshes). Stage 1
## (ORBIT) and Stage 3 (HULL_RUN) see the same system from different angles; `view` rotates a
## layout for a camera looking another way (the boarding dive looks along +X).

enum Layout { HULL_RUN, ORBIT }

const SHADER := preload("res://art/shaders/space_vista.gdshader")

## Per layout: body positions in the layout's own frame (they become directions), radii,
## ring orientation (Euler degrees of the ring plane) and the artistic light per body.
const LAYOUTS := {
	Layout.ORBIT: {
		# Stage 1 looks along -Z: giant high on the left, rings tipped steeply, the ocean
		# world's horizon filling the lower right, the moon to the right, the sun high up.
		"giant": [Vector3(-560, 300, -2400), 240.0], "ring": Vector3(62, 10, -28),
		"giant_light": Vector3(0.6, 0.4, 0.7), "giant_pole": Vector3(0.35, 1.0, 0.15),
		"moon": [Vector3(1000, 420, -1700), 85.0], "moon_light": Vector3(-0.5, 0.45, 0.75),
		"world": [Vector3(900, -1250, -1700), 950.0], "world_light": Vector3(-0.8, 0.55, 0.2),
		"world_pole": Vector3(0.25, 1.0, 0.3),
		"sun": Vector3(300, 1100, -3200),
	},
	Layout.HULL_RUN: {
		# Stage 3 races along +X: giant ahead-left, the ocean world below-right, sun ahead.
		"giant": [Vector3(1400, 120, 700), 260.0], "ring": Vector3(12, 0, 18),
		"giant_light": Vector3(-0.6, 0.5, -0.6), "giant_pole": Vector3(0.1, 1.0, 0.25),
		"moon": [Vector3(1300, 330, -900), 70.0], "moon_light": Vector3(-0.3, 0.5, -0.8),
		"world": [Vector3(600, -950, -500), 700.0], "world_light": Vector3(-0.7, 0.6, -0.3),
		"world_pole": Vector3(0.3, 1.0, -0.2),
		"sun": Vector3(1800, 500, -1100),
	},
}


## A Sky using the space_vista shader set up for `layout`.
static func make_sky(layout: Layout, view: Basis = Basis.IDENTITY) -> Sky:
	var sky := Sky.new()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	apply(mat, layout, view)
	sky.sky_material = mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	return sky


static func apply(mat: ShaderMaterial, layout: Layout, view: Basis = Basis.IDENTITY) -> void:
	var data: Dictionary = LAYOUTS[layout]
	for body: String in ["giant", "moon", "world"]:
		var pos: Vector3 = data[body][0]
		var radius: float = data[body][1]
		mat.set_shader_parameter(StringName(body + "_dir"), (view * pos).normalized())
		mat.set_shader_parameter(StringName(body + "_radius"), asin(radius / pos.length()))
		mat.set_shader_parameter(StringName(body + "_light"), (view * (data[body + "_light"] as Vector3)).normalized())
	mat.set_shader_parameter(&"giant_pole", view * (data["giant_pole"] as Vector3))
	mat.set_shader_parameter(&"world_pole", view * (data["world_pole"] as Vector3))
	var ring_rot: Vector3 = data["ring"]
	var ring_basis := Basis.from_euler(Vector3(deg_to_rad(ring_rot.x), deg_to_rad(ring_rot.y), deg_to_rad(ring_rot.z)))
	mat.set_shader_parameter(&"ring_normal", view * (ring_basis * Vector3.UP))
	mat.set_shader_parameter(&"sun_dir", (view * (data["sun"] as Vector3)).normalized())
