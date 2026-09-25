class_name LevelDirector
extends Node
## Runs a StageData: spawns waves on stage time, then WARNING → boss → STAGE CLEAR →
## next level. Debug: F6 skips to the boss, F8 advances the boss phase.

signal state_changed(state: State)
signal boss_spawned(boss: BossBase)
signal stage_cleared
## Emitted instead of routing when `hand_off` is set (seamless campaign).
signal finished

enum State { INTRO, WAVES, BOSS_WARNING, BOSS, CLEAR, DONE }

@export var stage: StageData
@export var enemy_root: Node3D
@export var stage_ui: StageUI
@export var intro_time: float = 2.5
@export var clear_time: float = 4.5
## Safety net: the boss arrives this long after the last wave even if stragglers remain.
@export var straggler_timeout: float = 12.0
## False: wait for begin() (the campaign starts stages when the camera arrives).
@export var auto_start: bool = true
## True: never change scenes; show STAGE CLEAR and emit `finished` for the campaign.
@export var hand_off: bool = false
@export var music: StringName = &"stage1"
@export var boss_music: StringName = &"boss"

var state: State = State.INTRO
var stage_time: float = 0.0
var boss: BossBase

var _state_time: float = 0.0
var _next_wave: int = 0
var _active_spawns: Array[Dictionary] = []
var _wave_stats: Dictionary = {}
var _all_spawned_at: float = -1.0


func _ready() -> void:
	add_to_group(&"debug_telemetry")
	if stage == null or enemy_root == null or stage_ui == null:
		push_error("LevelDirector: stage, enemy_root and stage_ui must be assigned.")
		set_physics_process(false)
		return
	if auto_start:
		begin()
	else:
		set_physics_process(false)
		set_process_unhandled_input(false)


func begin() -> void:
	AudioService.play_music(music)
	set_physics_process(true)
	set_process_unhandled_input(true)
	stage_ui.show_banner(stage.stage_name, stage.subtitle, intro_time + 0.5)
	if RunSession.checkpoint_id != StringName(stage.stage_name):
		RunSession.save_checkpoint(StringName(stage.stage_name))


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	_state_time += delta
	match state:
		State.INTRO:
			if _state_time >= intro_time:
				_set_state(State.WAVES)
		State.WAVES:
			stage_time += delta
			_update_waves()
			if _waves_finished():
				_set_state(State.BOSS_WARNING)
				stage_ui.show_warning(stage.boss_warning_time)
		State.BOSS_WARNING:
			if _state_time >= stage.boss_warning_time:
				_spawn_boss()
		State.CLEAR:
			if _state_time >= clear_time:
				_leave_stage()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_skip_to_boss"):
		skip_to_boss()
	elif event.is_action_pressed(&"debug_boss_phase") and is_instance_valid(boss):
		boss.debug_advance_phase()


func skip_to_boss() -> void:
	if state != State.INTRO and state != State.WAVES:
		return
	_next_wave = stage.waves.size()
	_active_spawns.clear()
	for enemy in enemy_root.get_children():
		enemy.queue_free()
	_set_state(State.BOSS_WARNING)
	stage_ui.show_warning(stage.boss_warning_time)


func get_debug_lines() -> PackedStringArray:
	return PackedStringArray([
		"STAGE %s  t=%.1fs  wave %d/%d  alive %d" % [State.keys()[state], stage_time, _next_wave,
				stage.waves.size(), _alive_enemies()],
	])


# --- Waves ----------------------------------------------------------------------

func _update_waves() -> void:
	while _next_wave < stage.waves.size() and stage.waves[_next_wave].start_time <= stage_time:
		var wave := stage.waves[_next_wave]
		_active_spawns.append({"wave": wave, "index": _next_wave, "spawned": 0, "next_time": wave.start_time})
		_wave_stats[_next_wave] = {"spawned": 0, "defeated": 0, "gone": 0, "wave": wave}
		if not wave.prompt.is_empty():
			stage_ui.show_prompt(wave.prompt)
		_next_wave += 1
	for spawn in _active_spawns.duplicate():
		var wave: WaveData = spawn["wave"]
		while spawn["spawned"] < wave.count and spawn["next_time"] <= stage_time:
			_spawn_unit(wave, spawn["index"], spawn["spawned"])
			spawn["spawned"] += 1
			spawn["next_time"] += wave.interval
		if spawn["spawned"] >= wave.count:
			_active_spawns.erase(spawn)
	if _all_spawned_at < 0.0 and _next_wave >= stage.waves.size() and _active_spawns.is_empty():
		_all_spawned_at = stage_time


func _spawn_unit(wave: WaveData, wave_index: int, unit: int) -> void:
	if wave.enemy_scene == null:
		push_error("LevelDirector: wave %d has no enemy scene." % wave_index)
		return
	var enemy := wave.enemy_scene.instantiate() as SpaceEnemy
	var camera := GameplayCamera.find(get_tree())
	var origin_x := camera.global_position.x if camera else 0.0
	var y := wave.spawn_y[unit % wave.spawn_y.size()] if not wave.spawn_y.is_empty() else 0.0
	enemy.position = Vector3(origin_x + wave.spawn_x, y, 0.0)
	enemy.speed_scale = wave.speed_scale
	if not wave.hold_x.is_empty():
		enemy.hold_x = wave.hold_x[unit % wave.hold_x.size()]
	enemy.defeated.connect(_on_unit_defeated.bind(wave_index))
	enemy.tree_exited.connect(_on_unit_gone.bind(wave_index))
	enemy_root.add_child(enemy)
	_wave_stats[wave_index]["spawned"] += 1


func _on_unit_defeated(_enemy: SpaceEnemy, wave_index: int) -> void:
	_wave_stats[wave_index]["defeated"] += 1


func _on_unit_gone(wave_index: int) -> void:
	if not _wave_stats.has(wave_index):
		return
	var stats: Dictionary = _wave_stats[wave_index]
	stats["gone"] += 1
	var wave: WaveData = stats["wave"]
	if stats["gone"] == wave.count and stats["defeated"] == wave.count and wave.completion_bonus > 0:
		RunSession.add_score(wave.completion_bonus)
		if is_instance_valid(stage_ui):
			stage_ui.show_prompt("FORMATION BONUS  +%d" % wave.completion_bonus)


func _waves_finished() -> bool:
	if _all_spawned_at < 0.0:
		return false
	return _alive_enemies() == 0 or stage_time - _all_spawned_at >= straggler_timeout


func _alive_enemies() -> int:
	var alive := 0
	for enemy in enemy_root.get_children():
		if not enemy.is_queued_for_deletion():
			alive += 1
	return alive


# --- Boss and exit -------------------------------------------------------------

func _spawn_boss() -> void:
	if stage.boss_scene == null:
		_on_boss_defeated()
		return
	boss = stage.boss_scene.instantiate() as BossBase
	boss.summon_root = enemy_root
	enemy_root.get_parent().add_child(boss)
	boss.defeated.connect(_on_boss_defeated)
	stage_ui.track_boss(boss)
	AudioService.play_music(boss_music, 0.6)
	_set_state(State.BOSS)
	boss_spawned.emit(boss)


func _on_boss_defeated() -> void:
	RunSession.add_score(stage.clear_bonus)
	_clear_hostiles()
	var final := stage.next_level.is_empty() and not hand_off
	if final:
		AudioService.play_music(&"mission_complete", 0.5)
	else:
		AudioService.stop_music(0.4)
		AudioService.play_jingle(&"stage_clear")
	stage_ui.show_banner("MISSION COMPLETE" if final else "STAGE CLEAR",
			"SCORE  %08d" % RunSession.score, clear_time)
	_set_state(State.CLEAR)
	stage_cleared.emit()


func _leave_stage() -> void:
	_set_state(State.DONE)
	if hand_off:
		finished.emit()
		return
	if stage.next_level.is_empty():
		if stage.restart_level.is_empty():
			return
		RunSession.reset_run()
		SceneRouter.go_to(stage.restart_level)
	else:
		SceneRouter.go_to(stage.next_level)


func _clear_hostiles() -> void:
	for enemy in enemy_root.get_children():
		enemy.queue_free()
	BossBase.clear_hostile_projectiles(get_tree())


func _set_state(next: State) -> void:
	state = next
	_state_time = 0.0
	state_changed.emit(state)
