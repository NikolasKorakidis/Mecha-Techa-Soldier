class_name SpaceRocks
extends RefCounted
## Smooth, lumpy asteroid meshes (noise-displaced spheres with craters, seamless normals) and
## one shared rock material. Meshes are generated once per variant and cached.

const VARIANTS := 5

static var _meshes: Array[ArrayMesh] = []
static var _material: StandardMaterial3D


static func mesh(variant: int) -> ArrayMesh:
	if _meshes.is_empty():
		for k in VARIANTS:
			_meshes.append(_build(k))
	return _meshes[posmod(variant, VARIANTS)]


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		# Shade is authored in sRGB; keeps crater contrast identical on Forward+ and Compatibility.
		_material.vertex_color_is_srgb = true
		_material.albedo_color = Color(0.3, 0.28, 0.3)
		_material.roughness = 0.95
		_material.metallic_specular = 0.2
		var noise := FastNoiseLite.new()
		noise.frequency = 0.02
		noise.fractal_octaves = 5
		var detail := NoiseTexture2D.new()
		detail.width = 256
		detail.height = 256
		detail.seamless = true
		detail.noise = noise
		detail.as_normal_map = true
		detail.bump_strength = 6.0
		_material.normal_enabled = true
		_material.normal_texture = detail
		_material.normal_scale = 0.8
		_material.uv1_triplanar = true
		_material.uv1_scale = Vector3.ONE * 0.35
		_material.rim_enabled = true
		_material.rim = 0.2
		_material.rim_tint = 0.6
	return _material


static func _build(variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + variant * 37
	var noise := FastNoiseLite.new()
	noise.seed = 311 + variant
	noise.frequency = 0.9
	noise.fractal_octaves = 4
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 40
	sphere.rings = 20
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var squash := Vector3(rng.randf_range(0.9, 1.3), rng.randf_range(0.6, 0.9), rng.randf_range(0.7, 1.0))
	var craters: Array[Vector3] = []
	for c in rng.randi_range(3, 6):
		craters.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized())
	var colors := PackedColorArray()
	colors.resize(verts.size())
	for i in verts.size():
		var v := verts[i].normalized()
		var r := 1.0 + noise.get_noise_3dv(v * 1.6) * 0.35 + noise.get_noise_3dv(v * 5.0) * 0.06
		var shade := 0.85 + noise.get_noise_3dv(v * 3.0 + Vector3(9, 9, 9)) * 0.3
		for c in craters:
			var d := v.distance_to(c)
			if d < 0.45:
				var k := d / 0.45
				# Bowl with a slightly raised rim.
				r -= (1.0 - k * k) * 0.14
				r += smoothstep(0.7, 1.0, k) * (1.0 - smoothstep(1.0, 1.1, k)) * 0.03
				shade *= lerpf(0.7, 1.0, k)
		verts[i] = v * r * squash
		colors[i] = Color(shade, shade * 0.97, shade * 0.94)
	# Smooth normals, merged across the sphere's UV seam by position.
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		var n := (verts[b] - verts[a]).cross(verts[c] - verts[a])
		normals[a] += n
		normals[b] += n
		normals[c] += n
	var merged := {}
	for i in verts.size():
		var key := Vector3i((verts[i] * 1000.0).round())
		merged[key] = (merged.get(key, Vector3.ZERO) as Vector3) + normals[i]
	for i in verts.size():
		var key := Vector3i((verts[i] * 1000.0).round())
		# SphereMesh winds triangles so the cross product points inward.
		normals[i] = -(merged[key] as Vector3).normalized()
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
