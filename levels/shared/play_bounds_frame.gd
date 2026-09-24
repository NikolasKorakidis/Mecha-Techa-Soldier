extends Node3D
## Graybox helper: draws the gameplay camera's play rect so boundaries are visible while tuning.

@export var camera: GameplayCamera
@export var color: Color = Color(0.4, 0.9, 1.0, 0.35)
@export var thickness: float = 0.06


func _ready() -> void:
	if camera == null:
		push_error("PlayBoundsFrame: camera not assigned.")
		return
	var rect := camera.get_play_rect().grow(-thickness)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	var c := rect.get_center()
	_add_edge(Vector3(c.x, rect.end.y, -1), Vector3(rect.size.x, thickness, 0.01), material)
	_add_edge(Vector3(c.x, rect.position.y, -1), Vector3(rect.size.x, thickness, 0.01), material)
	_add_edge(Vector3(rect.position.x, c.y, -1), Vector3(thickness, rect.size.y, 0.01), material)
	_add_edge(Vector3(rect.end.x, c.y, -1), Vector3(thickness, rect.size.y, 0.01), material)


func _add_edge(center: Vector3, box_size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	add_child(instance)
