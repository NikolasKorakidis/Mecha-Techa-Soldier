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


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_hud.set_paused(paused)


func next_dev_room() -> void:
	if dev_rooms.is_empty():
		return
	var index := (dev_rooms.find(SceneRouter.current_path) + 1) % dev_rooms.size()
	SceneRouter.go_to(dev_rooms[index])
