class_name RunnerDirector
extends Node
## Runs the bike stage: intro banner → ride (respawn at the last safe ground after death)
## → cross the finish line → MISSION COMPLETE → title. The warship explodes behind you the
## whole way (explosions at the left screen edge). F6 jumps close to the finish.

signal state_changed(state: State)
signal stage_cleared

enum State { INTRO, RIDE, FINISH, DONE }

@export var stage_name: String = "STAGE 3"
@export var subtitle: String = ""
@export var player: Node3D
@export var camera: GameplayCamera
@export var stage_ui: StageUI
@export var spawn: Marker3D
@export var finish_x: float = 1040.0
@export var camera_limits: Rect2 = Rect2()
@export var kill_y: float = -12.0
@export var respawn_delay: float = 1.2
@export var intro_time: float = 2.2
@export var finish_time: float = 5.0
@export var clear_bonus: int = 25000
@export_file("*.tscn") var restart_level: String = ""
@export var chase_interval: float = 0.55

var state: State = State.INTRO

var _state_time: float = 0.0
var _chase_left: float = 0.0
var _respawn_timer: Timer


func _ready() -> void:
	add_to_group(&"debug_telemetry")
	if player == null or camera == null or stage_ui == null or spawn == null:
		push_error("RunnerDirector: player, camera, stage_ui and spawn must be assigned.")
		set_physics_process(false)
		return
	player.global_position = spawn.global_position
	player.set(&"kill_y", kill_y)
	player.died.connect(_on_player_died)
	player.call(&"set_cinematic", true)
	camera.follow_target = player
	camera.limits = camera_limits
	camera.snap_to_target.call_deferred()
	_respawn_timer = Timer.new()
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(_respawn)
	add_child(_respawn_timer)
	stage_ui.show_banner(stage_name, subtitle, intro_time + 0.3)
	if RunSession.checkpoint_id != StringName(stage_name):
		RunSession.save_checkpoint(StringName(stage_name))


func _physics_process(delta: float) -> void:
	_state_time += delta
	match state:
		State.INTRO:
			if _state_time >= intro_time:
				player.call(&"set_cinematic", false)
				stage_ui.show_prompt("GO!")
				_set_state(State.RIDE)
		State.RIDE:
			_chase(delta)
			if player.global_position.x >= finish_x:
				_finish()
		State.FINISH:
			if _state_time >= finish_time:
				_leave()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_skip_to_boss") and state == State.RIDE:
		player.call(&"teleport", Vector3(finish_x - 60.0, 1.0, 0))


func progress() -> float:
	return clampf((player.global_position.x - spawn.global_position.x) / (finish_x - spawn.global_position.x), 0.0, 1.0)


func get_debug_lines() -> PackedStringArray:
	return PackedStringArray(["RUNNER %s  progress %d%%" % [State.keys()[state], int(progress() * 100.0)]])


func _chase(delta: float) -> void:
	_chase_left -= delta
	if _chase_left > 0.0:
		return
	_chase_left = chase_interval * randf_range(0.7, 1.3)
	var r := camera.get_play_rect()
	Vfx.spawn(get_tree(), preload("res://vfx/explosion.tscn"),
			Vector3(r.position.x + randf_range(-1.0, 1.5), randf_range(r.position.y + 1.0, r.end.y - 1.0), -2.0), randf_range(1.2, 2.4))


func _finish() -> void:
	RunSession.add_score(clear_bonus)
	player.call(&"set_cinematic", true)
	player.call(&"grant_invulnerability", finish_time + 1.0)
	BossBase.clear_hostile_projectiles(get_tree())
	stage_ui.show_banner("MISSION COMPLETE", "SCORE  %08d" % RunSession.score, finish_time)
	camera.add_trauma(ArtStyle.SHAKE_MAJOR)
	Vfx.spawn(get_tree(), preload("res://vfx/collect_burst.tscn"), player.global_position + Vector3(0, 1, 1), 4.0, {&"color": Palette.PLAYER_ENERGY})
	_set_state(State.FINISH)
	stage_cleared.emit()


func _leave() -> void:
	_set_state(State.DONE)
	if restart_level.is_empty():
		return
	RunSession.reset_run()
	SceneRouter.go_to(restart_level)


func _respawn() -> void:
	player.call(&"respawn", player.call(&"safe_position") as Vector3)


func _on_player_died() -> void:
	_respawn_timer.start(respawn_delay)


func _set_state(next: State) -> void:
	state = next
	_state_time = 0.0
	state_changed.emit(state)
