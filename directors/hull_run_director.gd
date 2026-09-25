class_name HullRunDirector
extends Node
## Runs the 3D hull run: chase camera behind the bike, fighter waves by distance, the pursuit
## gunship, respawns, and the finish at the bow. Standalone it shows MISSION COMPLETE and
## routes to the title; with `hand_off` the campaign plays the launch/explosion ending.
## F6 jumps to the gunship, F8 (with the gunship up) damages it heavily.

signal state_changed(state: State)
signal stage_cleared
signal finished

enum State { IDLE, INTRO, RIDE, FINISH, DONE }

const WAVE_DISTANCE := 150.0

@export var stage_name: String = "STAGE 3"
@export var subtitle: String = "HULL RUN — ESCAPE THE WARSHIP"
@export var player: Node3D
@export var camera: GameplayCamera
@export var stage_ui: StageUI
@export var enemy_root: Node3D
@export var track: HullTrack
@export var backdrop: HullRunBackdrop
@export var spawn: Marker3D
@export var auto_start: bool = true
@export var hand_off: bool = false
@export var music: StringName = &"stage3"
@export var intro_time: float = 2.0
@export var finish_time: float = 5.5
@export var respawn_delay: float = 1.3
@export var clear_bonus: int = 30000
@export var gunship_x: float = 1800.0
@export_file("*.tscn") var restart_level: String = ""

## Chase camera framing.
@export var chase_offset: Vector3 = Vector3(-9.5, 4.4, 0.0)
@export var look_ahead: float = 16.0
@export var chase_fov: float = 66.0

## [trigger_x, count, elite]
const WAVES := [
	[360.0, 2, false], [520.0, 3, false], [720.0, 2, true], [880.0, 3, false], [1080.0, 2, false],
	[1290.0, 3, false], [1470.0, 4, false], [1660.0, 2, true], [2480.0, 3, false], [2600.0, 2, true],
]

var state: State = State.IDLE
var gunship: RunGunship
var camera_enabled: bool = true

var _state_time: float = 0.0
var _next_wave: int = 0
var _respawn_timer: Timer
var _cam_z: float = 0.0
var _cam_roll: float = 0.0
var _gunship_done: bool = false


func _ready() -> void:
	add_to_group(&"debug_telemetry")
	_respawn_timer = Timer.new()
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(func() -> void: player.respawn(player.call(&"safe_position")))
	add_child(_respawn_timer)
	set_physics_process(false)
	if auto_start:
		begin(true)


## Starts the run. `place_player` = move the bike to the spawn (the campaign has already
## transformed the mech into the bike on the deck).
func begin(place_player: bool = true) -> void:
	_resolve_level_nodes()
	if player == null or camera == null or stage_ui == null or enemy_root == null or track == null:
		push_error("HullRunDirector: player, camera, stage_ui, enemy_root and track must be assigned.")
		return
	if place_player and spawn:
		player.global_position = spawn.global_position
	player.set(&"kill_y", HullTrack.DECK_Y - 10.0)
	if not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)
	if backdrop:
		backdrop.activate()
	camera.follow_target = null
	camera.rig_override = true
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = chase_fov
	camera.far = maxf(camera.far, 2400.0)
	_cam_z = player.global_position.z
	if place_player:
		_update_camera(1.0)
	stage_ui.show_banner(stage_name, subtitle, intro_time + 0.6)
	AudioService.play_music(music)
	if RunSession.checkpoint_id != StringName(stage_name):
		RunSession.save_checkpoint(StringName(stage_name))
	set_physics_process(true)
	_set_state(State.INTRO)
	player.call(&"set_cinematic", true)


## Camera, UI and player live outside the stage sub-scene: find them by group when not
## assigned (exported builds cannot resolve cross-instance NodePath overrides).
func _resolve_level_nodes() -> void:
	if camera == null:
		camera = GameplayCamera.find(get_tree())
	if stage_ui == null:
		stage_ui = StageUI.find(get_tree())
	if player == null:
		player = Players.find(get_tree())


func _physics_process(delta: float) -> void:
	_state_time += delta
	match state:
		State.INTRO:
			if _state_time >= intro_time:
				player.call(&"set_cinematic", false)
				stage_ui.show_prompt("GO!")
				_set_state(State.RIDE)
		State.RIDE:
			_update_waves()
			if not _gunship_done and gunship == null and player.global_position.x >= gunship_x:
				_spawn_gunship()
			if player.global_position.x >= track.finish_x:
				_finish()
		State.FINISH:
			if not hand_off and _state_time >= finish_time:
				_leave()
	if camera_enabled:
		_update_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_skip_to_boss") and state == State.RIDE:
		player.call(&"teleport", Vector3(gunship_x - 20.0, HullTrack.DECK_Y + 0.6, 0))
	elif event.is_action_pressed(&"debug_boss_phase") and is_instance_valid(gunship):
		gunship.health.apply_damage(DamagePayload.create(30, Teams.Team.PLAYER), self)


func progress() -> float:
	return clampf((player.global_position.x - track.start_x) / (track.finish_x - track.start_x), 0.0, 1.0)


func get_debug_lines() -> PackedStringArray:
	return PackedStringArray(["HULL RUN %s  progress %d%%  wave %d/%d" % [State.keys()[state], int(progress() * 100.0), _next_wave, WAVES.size()]])


## Chase rig: behind and above the bike, lagging a little laterally, banking into turns.
func _update_camera(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var p := player.global_position
	var vz: float = player.get(&"velocity").z if &"velocity" in player else 0.0
	var t := clampf(delta * 6.0, 0.0, 1.0)
	_cam_z = lerpf(_cam_z, p.z * 0.75, t)
	_cam_roll = lerpf(_cam_roll, -vz * 0.012, t)
	var boosting: bool = player.has_method(&"is_boosting") and player.call(&"is_boosting")
	var target_fov := chase_fov + (8.0 if boosting else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, t)
	var pos := Vector3(p.x + chase_offset.x, maxf(p.y, HullTrack.DECK_Y) + chase_offset.y, _cam_z + chase_offset.z)
	camera.global_position = pos
	camera.look_at(Vector3(p.x + look_ahead, maxf(p.y, HullTrack.DECK_Y) + 1.0, p.z * 0.5), Vector3.UP)
	camera.rotate_object_local(Vector3.FORWARD, _cam_roll)


func _update_waves() -> void:
	while _next_wave < WAVES.size() and player.global_position.x >= float(WAVES[_next_wave][0]):
		var wave: Array = WAVES[_next_wave]
		var count: int = wave[1]
		for i in count:
			var f := RunFighter.new()
			f.elite = wave[2] and i == 0
			var z := (float(i) - (count - 1) * 0.5) * 5.0
			f.position = Vector3(player.global_position.x + WAVE_DISTANCE + i * 8.0, HullTrack.DECK_Y + 5.0 + (i % 2) * 2.5, z) - enemy_root.global_position
			enemy_root.add_child(f)
		_next_wave += 1


func _spawn_gunship() -> void:
	gunship = RunGunship.new()
	gunship.position = Vector3(player.global_position.x - 30.0, HullTrack.DECK_Y + 20.0, 0) - enemy_root.global_position
	enemy_root.add_child(gunship)
	gunship.defeated.connect(_on_gunship_defeated)
	stage_ui.show_warning(2.2)
	stage_ui.track_generic(gunship.boss_name, gunship.max_health, gunship.health_changed)
	camera.add_trauma(ArtStyle.SHAKE_MAJOR)


func _on_gunship_defeated(_e: RunEnemy) -> void:
	_gunship_done = true
	stage_ui.hide_generic()
	stage_ui.show_prompt("GUNSHIP DOWN  +8000")
	HitStop.trigger(get_tree(), 0.12)


func _finish() -> void:
	RunSession.add_score(clear_bonus)
	player.call(&"grant_invulnerability", finish_time + 3.0)
	for enemy in enemy_root.get_children():
		enemy.queue_free()
	BossBase.clear_hostile_projectiles(get_tree())
	if is_instance_valid(gunship):
		stage_ui.hide_generic()
	_set_state(State.FINISH)
	stage_cleared.emit()
	if hand_off:
		finished.emit()
	else:
		stage_ui.show_banner("MISSION COMPLETE", "SCORE  %08d" % RunSession.score, finish_time)
		AudioService.play_music(&"mission_complete", 0.8)


func _leave() -> void:
	_set_state(State.DONE)
	if restart_level.is_empty():
		return
	RunSession.reset_run()
	SceneRouter.go_to(restart_level)


func _on_player_died() -> void:
	if state == State.RIDE or state == State.INTRO:
		_respawn_timer.start(respawn_delay)


func _set_state(next: State) -> void:
	state = next
	_state_time = 0.0
	state_changed.emit(state)
