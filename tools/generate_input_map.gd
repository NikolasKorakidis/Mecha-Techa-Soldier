extends SceneTree
## Regenerates the default input map in project.godot.
## Run: $GODOT --headless --path . --script res://tools/generate_input_map.gd
## Gameplay code references these action names only, never physical keys.

const DEADZONE := 0.25
## Matches the editor default so any keyboard or controller triggers the action.
const ALL_DEVICES := -1


func _initialize() -> void:
	var actions := {
		&"move_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _button(JOY_BUTTON_DPAD_LEFT)],
		&"move_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _button(JOY_BUTTON_DPAD_RIGHT)],
		&"move_up": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _button(JOY_BUTTON_DPAD_UP)],
		&"move_down": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _button(JOY_BUTTON_DPAD_DOWN)],
		&"fire": [_key(KEY_J), _mouse(MOUSE_BUTTON_LEFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		&"jump": [_key(KEY_SPACE), _button(JOY_BUTTON_A)],
		&"dash": [_key(KEY_K), _key(KEY_SHIFT), _button(JOY_BUTTON_B)],
		&"echo": [_key(KEY_L), _mouse(MOUSE_BUTTON_RIGHT), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		&"special": [_key(KEY_I), _key(KEY_Q), _button(JOY_BUTTON_RIGHT_SHOULDER)],
		&"pause": [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)],
		&"debug_toggle_panel": [_key(KEY_F3)],
		&"debug_next_room": [_key(KEY_F2)],
		&"debug_skip_to_boss": [_key(KEY_F6)],
		&"debug_cycle_echo": [_key(KEY_F7)],
		&"debug_boss_phase": [_key(KEY_F8)],
	}
	for action_name: StringName in actions:
		for event: InputEvent in actions[action_name]:
			event.device = ALL_DEVICES
		ProjectSettings.set_setting("input/" + action_name, {
			"deadzone": DEADZONE,
			"events": actions[action_name],
		})
	var err := ProjectSettings.save()
	print("Input map saved: ", error_string(err))
	quit(0 if err == OK else 1)


func _key(physical: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	return event


func _button(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	return event


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _mouse(index: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	return event
