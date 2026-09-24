extends Label
## Debug telemetry overlay (F3). Polls nodes in the "debug_telemetry" group for
## get_debug_lines() so feel tuning stays traceable.

const GROUP := &"debug_telemetry"
const REFRESH_SECONDS := 0.1

var _refresh_left := 0.0


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle_panel"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = REFRESH_SECONDS
	var lines := PackedStringArray(["FPS %d" % Engine.get_frames_per_second()])
	for node in get_tree().get_nodes_in_group(GROUP):
		if node.has_method(&"get_debug_lines"):
			lines.append_array(node.get_debug_lines())
	text = "\n".join(lines)
