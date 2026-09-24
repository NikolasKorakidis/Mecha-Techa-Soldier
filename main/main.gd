extends Node
## Root of the running game. Registers the level container with SceneRouter, owns pause,
## and cycles developer rooms (F2) until the real level flow exists.

@export_file("*.tscn") var start_level: String
@export_file("*.tscn") var dev_rooms: Array[String] = []

@onready var _level_root: Node = %CurrentLevel
@onready var _hud: CanvasLayer = %HUD


func _ready() -> void:
	RunSession.reset_run()
	SceneRouter.register_level_root(_level_root)
	SceneRouter.go_to(start_level)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"debug_next_room") and not get_tree().paused:
		next_dev_room()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"debug_cycle_echo") and not get_tree().paused:
		cycle_debug_echo()
		get_viewport().set_input_as_handled()


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_hud.set_paused(paused)


func next_dev_room() -> void:
	var rooms := available_dev_rooms()
	if rooms.is_empty():
		return
	var index := (rooms.find(SceneRouter.current_path) + 1) % rooms.size()
	SceneRouter.go_to(rooms[index])


## Test rooms are for debug builds only; release builds cycle real stages.
func available_dev_rooms() -> Array[String]:
	if OS.is_debug_build():
		return dev_rooms
	return dev_rooms.filter(func(path: String) -> bool: return not path.contains("/test_rooms/"))


## Debug (F7): none → Burst → Arc → Guard → none, with full ammo.
func cycle_debug_echo() -> void:
	var order: Array[StringName] = [RunSession.NO_ECHO]
	order.append_array(EchoModules.ALL)
	var next: StringName = order[(order.find(RunSession.selected_echo) + 1) % order.size()]
	var data := EchoModules.get_data(next)
	RunSession.equip_echo(next, data.ammo if data else 0)
