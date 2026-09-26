class_name ModelKit
extends RefCounted
## Builders for chunk-tech diorama models from primitives: toon-lit hulls,
## emissive accents and additive glow parts. Keeps model scripts declarative.

const GLOW_BILLBOARD_SHADER := preload("res://art/shaders/additive_glow_billboard.gdshader")
const GLOW_SHADER := preload("res://art/shaders/additive_glow.gdshader")
const FRESNEL_SHADER := preload("res://art/shaders/fresnel_shell.gdshader")

enum GlowShape { RADIAL, STREAK, RING, FLAME }


const OUTLINE_META := &"outline_thickness"

static var _outline_material: StandardMaterial3D


## Marks a material so every mesh built with it gets a dark outline shell.
static func with_outline(mat: Material, thickness: float = ArtStyle.OUTLINE_THICK) -> Material:
	mat.set_meta(OUTLINE_META, thickness)
	return mat


## Toon hull with an outline shell.
static func hull(color: Color, thickness: float = ArtStyle.OUTLINE_THICK, rim: float = 0.55) -> StandardMaterial3D:
	return with_outline(toon(color, rim, 0.5, 0.15), thickness) as StandardMaterial3D


static func toon(color: Color, rim: float = 0.5, roughness: float = 0.55, metallic: float = 0.1) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = roughness
	m.metallic = metallic
	m.rim_enabled = rim > 0.0
	m.rim = rim
	m.rim_tint = 0.75
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


## Camera-facing glow (3D views): always faces the camera whatever the angle.
static func glow_billboard(color: Color, energy: float = 1.5, shape: GlowShape = GlowShape.RADIAL) -> ShaderMaterial:
	var m := glow(color, energy, shape)
	m.shader = GLOW_BILLBOARD_SHADER
	return m


## Additive rim-lit shell (energy bubble, glass highlight): clear face-on, bright at the edges.
static func fresnel_shell(color: Color, energy: float = 1.0, power: float = 2.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FRESNEL_SHADER
	m.set_shader_parameter(&"tint", color)
	m.set_shader_parameter(&"energy", energy)
	m.set_shader_parameter(&"power", power)
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


## Cone along +X (tip forward) — noses and prongs. `sides` 6 gives a faceted, beveled read.
static func cone_x(parent: Node3D, radius: float, length: float, pos: Vector3, mat: Material, sides: int = 6, flip: bool = false) -> MeshInstance3D:
	return cylinder(parent, 0.0, radius, length, pos, mat, Vector3(0, 0, 90 if flip else -90), sides)


## Faceted rod along X — fuselages, nacelles, pipes.
static func hex_x(parent: Node3D, radius: float, length: float, pos: Vector3, mat: Material, sides: int = 6, taper: float = 1.0) -> MeshInstance3D:
	return cylinder(parent, radius * taper, radius, length, pos, mat, Vector3(0, 0, -90), sides)


## Empty grouping node (model part), so parts can be animated or broken off together.
static func group(parent: Node3D, part_name: String, pos := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = part_name
	node.position = pos
	parent.add_child(node)
	return node


static func sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material, scale := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
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
	if mat and mat.has_meta(OUTLINE_META):
		_add_outline_shell(node, float(mat.get_meta(OUTLINE_META)))
	return node


## Inverted-hull outline: a dark copy scaled out by `thickness` on every axis, drawing only
## its back faces, so it shows as a rim around the silhouette and never covers the hull.
## (Normal-grow shells vanish on flat box faces seen head-on by the ortho camera.)
static func _add_outline_shell(node: MeshInstance3D, thickness: float) -> void:
	if _outline_material == null:
		_outline_material = StandardMaterial3D.new()
		_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline_material.albedo_color = ArtStyle.OUTLINE_COLOR
		_outline_material.cull_mode = BaseMaterial3D.CULL_FRONT
	var size := node.mesh.get_aabb().size
	var shell := MeshInstance3D.new()
	shell.name = "Outline"
	shell.mesh = node.mesh
	shell.material_override = _outline_material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.scale = Vector3(
		(size.x + thickness * 2.0) / maxf(size.x, 0.001),
		(size.y + thickness * 2.0) / maxf(size.y, 0.001),
		(size.z + thickness * 2.0) / maxf(size.z, 0.001))
	node.add_child(shell)
