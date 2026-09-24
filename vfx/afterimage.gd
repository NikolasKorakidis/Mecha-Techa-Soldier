class_name Afterimage
extends Node3D
## Translucent cyan snapshot of a model that fades in place (dash afterimage).

const LIFETIME := 0.28

var _material: StandardMaterial3D
var _age: float = 0.0


static func from_model(model: Node3D, color: Color) -> Afterimage:
	var ghost := Afterimage.new()
	ghost._material = StandardMaterial3D.new()
	ghost._material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost._material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost._material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ghost._material.albedo_color = Color(color, 0.16)
	ghost.transform = model.global_transform
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var src := mesh as MeshInstance3D
		if not src.visible or src.mesh is QuadMesh or src.name == &"Outline":
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = src.mesh
		copy.material_override = ghost._material
		copy.transform = model.global_transform.affine_inverse() * src.global_transform
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(copy)
	return ghost


func _process(delta: float) -> void:
	_age += delta
	_material.albedo_color.a = 0.16 * (1.0 - _age / LIFETIME)
	if _age >= LIFETIME:
		queue_free()
