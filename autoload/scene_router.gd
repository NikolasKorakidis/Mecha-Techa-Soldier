extends Node
## Swaps the level under Main's CurrentLevel node. Only this service changes levels.

signal level_changed(level: Node)

var current_level: Node
var current_path: String = ""

var _level_root: Node


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
