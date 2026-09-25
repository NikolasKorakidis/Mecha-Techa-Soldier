extends Node
## Swaps the level under Main's CurrentLevel node. Only this service changes levels.
## change_level() plays the shutter wipe (cover → prepare → swap → reveal); go_to() swaps now.

signal level_changed(level: Node)

var current_level: Node
var current_path: String = ""
## Animated level changes. Off without a display (tests, CI, boot check): there is nothing to
## see, and callers there expect the swap to be immediate.
var transitions_enabled: bool = DisplayServer.get_name() != "headless"
var transition: ScreenTransition

var _level_root: Node
var _changing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	transition = ScreenTransition.new()
	add_child(transition)


func is_changing() -> bool:
	return _changing


## Level change behind the shutter wipe. `prepare` runs at the moment of the swap (e.g. reset the
## run) so the outgoing level never sees half-reset state. Ignored while a change is running.
func change_level(path: String, prepare: Callable = Callable()) -> void:
	if _changing:
		return
	if not transitions_enabled:
		if prepare.is_valid():
			prepare.call()
		go_to(path)
		return
	_changing = true
	AudioService.play(&"whoosh", -8.0)
	await transition.cover()
	if prepare.is_valid():
		prepare.call()
	go_to(path)
	# Let the new level build and settle a frame behind the plates.
	await get_tree().process_frame
	await get_tree().process_frame
	_changing = false
	await transition.reveal()


func register_level_root(root: Node) -> void:
	_level_root = root


func go_to(path: String) -> Node:
	if not is_instance_valid(_level_root):
		push_error("SceneRouter: no level root registered; Main must call register_level_root().")
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("SceneRouter: cannot load level scene '%s'." % path)
		return null
	if is_instance_valid(current_level):
		_level_root.remove_child(current_level)
		current_level.queue_free()
	current_level = packed.instantiate()
	current_path = path
	_level_root.add_child(current_level)
	level_changed.emit(current_level)
	return current_level


func reload_current() -> Node:
	if current_path.is_empty():
		push_error("SceneRouter: nothing to reload.")
		return null
	return go_to(current_path)
