class_name GameplayCamera
extends Camera3D
## Orthographic side-view camera. Defines the gameplay rectangle on the Z = 0 plane.
## The rect uses a fixed 16:9 aspect (project stretch aspect is "keep"), so gameplay
## never depends on window size.

const GROUP := &"gameplay_camera"
const ASPECT := 16.0 / 9.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	keep_aspect = KEEP_HEIGHT


## Visible gameplay area on the Z = 0 plane, in world units.
func get_play_rect() -> Rect2:
	var half := Vector2(size * 0.5 * ASPECT, size * 0.5)
	var center := Vector2(global_position.x, global_position.y)
	return Rect2(center - half, half * 2.0)


static func find(tree: SceneTree) -> GameplayCamera:
	return tree.get_first_node_in_group(GROUP) as GameplayCamera
