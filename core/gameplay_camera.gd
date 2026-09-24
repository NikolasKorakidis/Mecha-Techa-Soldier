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

## Follow mode (platformer / runner). With no target the camera stays put (shooter).
@export var follow_target: Node3D
## Where the target sits relative to the view center (world units).
@export var follow_offset: Vector2 = Vector2(0.0, 1.5)
## Extra lead in the facing/moving direction.
@export var lookahead: float = 3.0
## Vertical dead zone: the camera only moves when the target leaves this band.
@export var vertical_deadzone: float = 2.0
@export var follow_smoothing: float = 8.0
## Camera center is clamped to this rect (world units). Zero size = unlimited.
@export var limits: Rect2 = Rect2()

var _locked: bool = false
var _lock_center: Vector2 = Vector2.ZERO
var _lead: float = 0.0

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


## Fix the view on an arena (boss rooms). unlock() resumes following.
func lock_to(center: Vector2) -> void:
	_locked = true
	_lock_center = center


func unlock() -> void:
	_locked = false


func is_locked() -> bool:
	return _locked


## Jump straight to the target (level start, respawn).
func snap_to_target() -> void:
	if follow_target:
		var goal := _goal(0.0)
		global_position = Vector3(goal.x, goal.y, global_position.z)


func _physics_process(delta: float) -> void:
	if follow_target == null and not _locked:
		return
	var goal := _lock_center if _locked else _goal(delta)
	var t := clampf(follow_smoothing * delta, 0.0, 1.0)
	var pos := Vector2(global_position.x, global_position.y).lerp(goal, t)
	global_position = Vector3(pos.x, pos.y, global_position.z)


func _goal(delta: float) -> Vector2:
	if not is_instance_valid(follow_target):
		return Vector2(global_position.x, global_position.y)
	var p := Vector2(follow_target.global_position.x, follow_target.global_position.y)
	var facing := 1.0
	if &"facing" in follow_target:
		facing = float(follow_target.get(&"facing"))
	_lead = lerpf(_lead, facing * lookahead, clampf(3.0 * delta, 0.0, 1.0)) if delta > 0.0 else facing * lookahead
	var goal := Vector2(p.x + follow_offset.x + _lead, global_position.y)
	var target_y := p.y + follow_offset.y
	if delta == 0.0:
		goal.y = target_y
	elif target_y > goal.y + vertical_deadzone:
		goal.y = target_y - vertical_deadzone
	elif target_y < goal.y - vertical_deadzone:
		goal.y = target_y + vertical_deadzone
	if limits.size != Vector2.ZERO:
		goal.x = clampf(goal.x, limits.position.x, limits.end.x)
		goal.y = clampf(goal.y, limits.position.y, limits.end.y)
	return goal


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
