class_name GameplayCamera
extends Camera3D
## Orthographic side-view camera. Defines the gameplay rectangle on the Z = 0 plane.
## The rect uses a fixed 16:9 aspect (project stretch aspect is "keep"), so gameplay
## never depends on window size.

const GROUP := &"gameplay_camera"
const ASPECT := 16.0 / 9.0

## Screen shake: trauma in [0, 1], offset grows with trauma². Offsets move the view only,
## never the play rect, so shake cannot change collision-space interpretation.
@export var max_shake_offset: Vector2 = Vector2(0.45, 0.3)
@export var trauma_decay: float = 1.8
## Accessibility scale: 0 disables shake entirely.
@export var shake_scale: float = 1.0

var trauma: float = 0.0

var _noise := FastNoiseLite.new()
var _noise_time: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	keep_aspect = KEEP_HEIGHT
	_noise.frequency = 0.9


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, ArtStyle.SHAKE_MAX_TRAUMA)


func _process(delta: float) -> void:
	if trauma <= 0.0:
		h_offset = 0.0
		v_offset = 0.0
		return
	trauma = maxf(0.0, trauma - trauma_decay * delta)
	_noise_time += delta * 40.0
	var amount := trauma * trauma * shake_scale * ArtStyle.shake_scale()
	h_offset = max_shake_offset.x * amount * _noise.get_noise_2d(_noise_time, 0.0)
	v_offset = max_shake_offset.y * amount * _noise.get_noise_2d(0.0, _noise_time)


## Visible gameplay area on the Z = 0 plane, in world units.
func get_play_rect() -> Rect2:
	var half := Vector2(size * 0.5 * ASPECT, size * 0.5)
	var center := Vector2(global_position.x, global_position.y)
	return Rect2(center - half, half * 2.0)


static func find(tree: SceneTree) -> GameplayCamera:
	return tree.get_first_node_in_group(GROUP) as GameplayCamera
