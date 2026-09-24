class_name CameraFollower
extends Node3D
## Keeps its children (sky layers, backdrops) glued to the gameplay camera's X/Y so a
## backdrop authored around the origin works anywhere in a large, continuous world.

## 1 = moves exactly with the camera (infinitely far away); lower values add parallax.
@export var factor: float = 1.0
@export var follow_y: bool = true
## > 0: scale X/Y with the orthographic camera size (reference size), so a backdrop framed for
## that size still fills the view when a cinematic zooms out.
@export var reference_size: float = 0.0

var _camera: GameplayCamera


func _process(_delta: float) -> void:
	if _camera == null:
		_camera = GameplayCamera.find(get_tree())
		if _camera == null:
			return
	var p := _camera.global_position
	global_position = Vector3(p.x * factor, p.y * factor if follow_y else global_position.y, global_position.z)
	if reference_size > 0.0 and _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		var k := _camera.size / reference_size
		scale = Vector3(k, k, 1.0)
