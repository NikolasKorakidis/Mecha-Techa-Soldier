class_name HitStop
extends RefCounted
## Brief global slow-down on strong impacts only (elite kills, boss breaks, player death).
## Uses a real-time timer so the freeze length never depends on the slowed clock.

const SLOW_SCALE := 0.05

static var _active: bool = false


static func trigger(tree: SceneTree, duration: float = 0.06) -> void:
	if _active or tree == null or Engine.time_scale != 1.0:
		return
	_active = true
	Engine.time_scale = SLOW_SCALE
	tree.create_timer(duration, true, false, true).timeout.connect(_release)


static func _release() -> void:
	Engine.time_scale = 1.0
	_active = false
