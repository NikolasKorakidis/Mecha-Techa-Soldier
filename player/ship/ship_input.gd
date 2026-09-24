class_name ShipInput
extends RefCounted
## One physics tick of ship input. Decouples the controller from devices so tests and
## future replays can drive the ship deterministically.

var move: Vector2 = Vector2.ZERO
var fire: bool = false
var dash_pressed: bool = false
var burst_pressed: bool = false
var special_pressed: bool = false


static func from_devices() -> ShipInput:
	var input := ShipInput.new()
	# Y is up in 3D, so "up" is positive.
	input.move = Input.get_vector(&"move_left", &"move_right", &"move_down", &"move_up")
	input.fire = Input.is_action_pressed(&"fire")
	input.dash_pressed = Input.is_action_just_pressed(&"dash")
	input.burst_pressed = Input.is_action_just_pressed(&"jump")
	input.special_pressed = Input.is_action_just_pressed(&"special")
	return input


static func make(move_dir: Vector2, fire_held := false, dash := false, burst := false) -> ShipInput:
	var input := ShipInput.new()
	input.move = move_dir
	input.fire = fire_held
	input.dash_pressed = dash
	input.burst_pressed = burst
	return input
