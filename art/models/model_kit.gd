class_name ModelKit
extends RefCounted
## Builders for chunk-tech diorama models from primitives: toon-lit hulls,
## emissive accents and additive glow parts. Keeps model scripts declarative.

const GLOW_SHADER := preload("res://art/shaders/additive_glow.gdshader")

enum GlowShape { RADIAL, STREAK, RING, FLAME }


static func toon(color: Color, rim: float = 0.5, roughness: float = 0.55, metallic: float = 0.1) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = roughness
	m.metallic = metallic
	m.rim_enabled = rim > 0.0
	m.rim = rim
	m.rim_tint = 0.6
	return m


static func glossy(color: Color) -> StandardMaterial3D:
	var m := toon(color, 0.7, 0.2, 0.6)
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.1
	return m


static func emissive(color: Color, energy: float = 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func glow(color: Color, energy: float = 1.5, shape: GlowShape = GlowShape.RADIAL) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLOW_SHADER
	m.set_shader_parameter(&"tint", color)
	m.set_shader_parameter(&"energy", energy)
	m.set_shader_parameter(&"shape", shape)
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, mat, rot_deg)


## Wedge pointing along +Y before rotation (apex up).
static func prism(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, mat, rot_deg)


## Cylinder along +Y before rotation. Use rot_deg.z = ±90 to lay it along X.
static func cylinder(parent: Node3D, top_radius: float, bottom_radius: float, height: float, pos: Vector3,
		mat: Material, rot_deg := Vector3.ZERO, segments: int = 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return _add(parent, mesh, pos, mat, rot_deg)


static func sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material, scale := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var node := _add(parent, mesh, pos, mat, Vector3.ZERO)
	node.scale = scale
	return node


## Camera-facing quad (the gameplay camera never rotates, so XY quads always face it).
static func quad(parent: Node3D, size: Vector2, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var node := _add(parent, mesh, pos, mat, rot_deg)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot_deg: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.rotation_degrees = rot_deg
	parent.add_child(node)
	return node
