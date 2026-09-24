class_name OffscreenCleanup
extends Node
## Frees its parent once it leaves the gameplay rect (plus margin).
## require_entered: only cull after the parent has been on screen once, so enemies can
## spawn off-screen and fly in.

@export var margin: float = 2.0
@export var require_entered: bool = false

var _camera: GameplayCamera
var _has_entered: bool = false


func _ready() -> void:
	_camera = GameplayCamera.find(get_tree())
	if _camera == null:
		push_error("OffscreenCleanup: no GameplayCamera in scene; '%s' will rely on lifetime only." % get_parent().name)
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	var parent := get_parent() as Node3D
	if parent == null:
		return
	var p := Vector2(parent.global_position.x, parent.global_position.y)
	var rect := _camera.get_play_rect()
	if rect.has_point(p):
		_has_entered = true
		return
	if require_entered and not _has_entered:
		return
	if not rect.grow(margin).has_point(p):
		parent.queue_free()
