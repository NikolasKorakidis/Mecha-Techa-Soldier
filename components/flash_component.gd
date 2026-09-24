class_name FlashComponent
extends Node
## Blinks a visual node while an actor is invulnerable after a hit.

@export var target: Node3D
@export var interval: float = 0.07

var _time_left: float = 0.0
var _toggle_left: float = 0.0


func flash(duration: float) -> void:
	_time_left = duration
	_toggle_left = interval


func stop() -> void:
	_time_left = 0.0
	if target:
		target.visible = true


func is_flashing() -> bool:
	return _time_left > 0.0


func _process(delta: float) -> void:
	if _time_left <= 0.0 or target == null:
		return
	_time_left -= delta
	_toggle_left -= delta
	if _toggle_left <= 0.0:
		_toggle_left = interval
		target.visible = not target.visible
	if _time_left <= 0.0:
		target.visible = true
