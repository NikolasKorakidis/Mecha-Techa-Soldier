class_name TestRoom
extends Node3D
## Developer room: places the player at the spawn marker and respawns it after death.

@export var player: ShipPlayer
@export var spawn: Marker3D
@export var respawn_delay: float = 1.5

var _respawn_timer: Timer


func _ready() -> void:
	var title := get_node_or_null(^"Title") as Label3D
	if title:
		title.visible = title.visible and Settings.show_debug_labels
	if player == null or spawn == null:
		push_error("TestRoom '%s': player and spawn must be assigned." % name)
		return
	player.global_position = spawn.global_position
	player.died.connect(_on_player_died)
	_respawn_timer = Timer.new()
	_respawn_timer.one_shot = true
	_respawn_timer.wait_time = respawn_delay
	_respawn_timer.timeout.connect(_on_respawn_timeout)
	add_child(_respawn_timer)


func _on_player_died() -> void:
	_respawn_timer.start()


func _on_respawn_timeout() -> void:
	player.respawn(spawn.global_position)
