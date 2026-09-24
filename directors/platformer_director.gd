class_name PlatformerDirector
extends Node
## Runs a platformer stage: intro banner → play (checkpoints, respawn after death) → boss gate
## locks the arena → boss → "CORE DESTROYED — ESCAPE" → next level. F6 jumps to the boss gate.

signal state_changed(state: State)
signal boss_spawned(boss: BossBase)
signal stage_cleared

enum State { INTRO, PLAY, BOSS_WARNING, BOSS, ESCAPE, DONE }

@export var stage_name: String = "STAGE 2"
@export var subtitle: String = ""
@export var player: Node3D
@export var camera: GameplayCamera
@export var stage_ui: StageUI
@export var enemy_root: Node3D
@export var boss_scene: PackedScene
@export var spawn: Marker3D
## Camera center while the boss arena is locked, and the gate that seals it.
@export var arena_center: Vector2 = Vector2.ZERO
@export var arena_floor_y: float = 0.0
@export var boss_gate: Node3D
@export var boss_trigger_x: float = 1e9
@export var camera_limits: Rect2 = Rect2()
@export var kill_y: float = -10.0
@export var respawn_delay: float = 1.4
@export var intro_time: float = 2.4
@export var warning_time: float = 2.8
@export var escape_time: float = 4.0
@export var clear_bonus: int = 20000
@export_file("*.tscn") var next_level: String = ""
@export var clear_title: String = "CORE DESTROYED"
@export var clear_subtitle: String = "ESCAPE THE WARSHIP!"

var state: State = State.INTRO
var boss: BossBase
var checkpoint_position: Vector3

var _state_time: float = 0.0
var _respawn_timer: Timer


func _ready() -> void:
	add_to_group(&"debug_telemetry")
	checkpoint_position = spawn.global_position
	player.global_position = spawn.global_position
	player.set(&"kill_y", kill_y)
	player.died.connect(_on_player_died)
	camera.follow_target = player
	camera.limits = camera_limits
	camera.snap_to_target.call_deferred()
	_respawn_timer = Timer.new()
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(func() -> void: player.respawn(checkpoint_position))
	add_child(_respawn_timer)
	if boss_gate:
		_set_gate(false)
	for cp in get_tree().get_nodes_in_group(&"checkpoints"):
		(cp as Checkpoint).reached.connect(_on_checkpoint)
	stage_ui.show_banner(stage_name, subtitle, intro_time + 0.4)
	if RunSession.checkpoint_id != StringName(stage_name):
		RunSession.save_checkpoint(StringName(stage_name))


func _physics_process(delta: float) -> void:
	_state_time += delta
	match state:
		State.INTRO:
			if _state_time >= intro_time:
				_set_state(State.PLAY)
		State.PLAY:
			if player.global_position.x >= boss_trigger_x:
				start_boss()
		State.BOSS_WARNING:
			if _state_time >= warning_time:
				_spawn_boss()
		State.ESCAPE:
			if fmod(_state_time, 0.35) < delta:
				var r := camera.get_play_rect()
				Vfx.spawn(get_tree(), preload("res://vfx/explosion.tscn"),
						Vector3(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y), -3), randf_range(1.0, 2.2))
			if _state_time >= escape_time:
				_leave()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_skip_to_boss") and state in [State.INTRO, State.PLAY]:
		player.call(&"teleport", Vector3(boss_trigger_x - 6.0, arena_floor_y + 1.0, 0))
	elif event.is_action_pressed(&"debug_boss_phase") and is_instance_valid(boss):
		boss.debug_advance_phase()


func start_boss() -> void:
	if state != State.PLAY and state != State.INTRO:
		return
	camera.lock_to(arena_center)
	if boss_gate:
		_set_gate(true)
	checkpoint_position = Vector3(boss_trigger_x + 1.5, arena_floor_y + 0.5, 0)
	stage_ui.show_warning(warning_time)
	_set_state(State.BOSS_WARNING)


func get_debug_lines() -> PackedStringArray:
	return PackedStringArray(["PLATFORMER %s  checkpoint (%.0f, %.0f)" % [State.keys()[state], checkpoint_position.x, checkpoint_position.y]])


func _spawn_boss() -> void:
	boss = boss_scene.instantiate() as BossBase
	boss.summon_root = enemy_root
	get_parent().add_child(boss)
	boss.defeated.connect(_on_boss_defeated)
	stage_ui.track_boss(boss)
	_set_state(State.BOSS)
	boss_spawned.emit(boss)


func _on_boss_defeated() -> void:
	RunSession.add_score(clear_bonus)
	for enemy in enemy_root.get_children():
		enemy.queue_free()
	BossBase.clear_hostile_projectiles(get_tree())
	player.call(&"grant_invulnerability", escape_time + 1.0)
	stage_ui.show_banner(clear_title, clear_subtitle, escape_time)
	camera.add_trauma(ArtStyle.SHAKE_BOSS_DEATH)
	_set_state(State.ESCAPE)
	stage_cleared.emit()


func _leave() -> void:
	_set_state(State.DONE)
	if not next_level.is_empty():
		SceneRouter.go_to(next_level)


func _on_checkpoint(cp: Checkpoint) -> void:
	checkpoint_position = cp.global_position + Vector3(0, 0.5, 0)
	stage_ui.show_prompt("CHECKPOINT")


func _on_player_died() -> void:
	_respawn_timer.start(respawn_delay)


func _set_gate(closed: bool) -> void:
	boss_gate.visible = closed
	for child in boss_gate.find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).set_deferred(&"disabled", not closed)


func _set_state(next: State) -> void:
	state = next
	_state_time = 0.0
	state_changed.emit(state)
