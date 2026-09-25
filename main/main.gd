extends Node
## Root of the running game. Registers the level container with SceneRouter, owns pause,
## and cycles developer rooms (F2) until the real level flow exists.

@export_file("*.tscn") var start_level: String
## First gameplay stage (Start on the title card, Quit to Title comes back to start_level).
@export_file("*.tscn") var first_stage: String
@export_file("*.tscn") var dev_rooms: Array[String] = []

@onready var _level_root: Node = %CurrentLevel
@onready var _hud: CanvasLayer = %HUD
@onready var _pause_menu: PauseMenu = %PauseMenu


func _ready() -> void:
	RunSession.reset_run()
	SceneRouter.register_level_root(_level_root)
	SceneRouter.level_changed.connect(_on_level_changed)
	# Deferred: scene changes must not free a node while it is still handling input.
	_pause_menu.resume_requested.connect(set_paused.bind(false), CONNECT_DEFERRED)
	_pause_menu.restart_requested.connect(restart_stage, CONNECT_DEFERRED)
	_pause_menu.quit_requested.connect(quit_to_title, CONNECT_DEFERRED)
	SceneRouter.go_to(start_level)


func start_game() -> void:
	set_paused(false)
	RunSession.reset_run()
	SceneRouter.go_to(first_stage)


## Stage select: starts the campaign at stage 1–3 (the campaign resumes from the checkpoint id).
func start_at_stage(stage: int) -> void:
	set_paused(false)
	RunSession.reset_run()
	if stage > 1:
		RunSession.save_checkpoint(StringName("STAGE %d" % stage))
	SceneRouter.go_to(first_stage)


## Restart the current stage from its entry snapshot (score, weapon, energy).
func restart_stage() -> void:
	set_paused(false)
	RunSession.restore_checkpoint()
	SceneRouter.reload_current()


func quit_to_title() -> void:
	set_paused(false)
	RunSession.reset_run()
	SceneRouter.go_to(start_level)


func is_in_gameplay() -> bool:
	if not is_instance_valid(SceneRouter.current_level):
		return false
	# The 8-bit stage has no 3D avatar; it registers itself while it runs.
	return Players.find(get_tree()) != null or get_tree().get_first_node_in_group(&"pausable_stage") != null


func _on_level_changed(level: Node) -> void:
	_hud.visible = Players.find(get_tree()) != null
	if level.has_signal(&"start_requested"):
		level.start_requested.connect(start_game, CONNECT_DEFERRED)
	if level.has_signal(&"stage_requested"):
		level.stage_requested.connect(start_at_stage, CONNECT_DEFERRED)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not get_tree().paused and is_in_gameplay():
		set_paused(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"debug_next_room") and not get_tree().paused:
		get_viewport().set_input_as_handled()
		# Deferred: never free the level while it is still handling this input event.
		next_dev_room.call_deferred()
	elif event.is_action_pressed(&"debug_cycle_echo") and not get_tree().paused:
		cycle_debug_echo()
		get_viewport().set_input_as_handled()


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	if paused:
		_pause_menu.open()
	else:
		_pause_menu.close()


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
