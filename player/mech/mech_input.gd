class_name MechInput
extends RefCounted
## One physics tick of mech/bike input, from devices or scripted for tests.

var move_x: float = 0.0
var down: bool = false
var jump_pressed: bool = false
var jump_held: bool = false
var fire: bool = false
var dash_pressed: bool = false
var special_pressed: bool = false


static func from_devices() -> MechInput:
	var input := MechInput.new()
	input.move_x = Input.get_axis(&"move_left", &"move_right")
	input.down = Input.is_action_pressed(&"move_down")
	input.jump_pressed = Input.is_action_just_pressed(&"jump")
	input.jump_held = Input.is_action_pressed(&"jump")
	input.fire = Input.is_action_pressed(&"fire")
	input.dash_pressed = Input.is_action_just_pressed(&"dash")
	input.special_pressed = Input.is_action_just_pressed(&"special")
	return input


static func make(move := 0.0, jump_press := false, jump_hold := false, fire_held := false, dash := false, special := false, down_held := false) -> MechInput:
	var input := MechInput.new()
	input.move_x = move
	input.jump_pressed = jump_press
	input.jump_held = jump_hold or jump_press
	input.fire = fire_held
	input.dash_pressed = dash
	input.special_pressed = special
	input.down = down_held
	return input
