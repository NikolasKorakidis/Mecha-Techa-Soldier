class_name CampaignDirector
extends Node
## The whole run in one continuous world — no scene changes between stages:
##   SHOOTER    Stage 1 in open space (static side-view camera far left of the warship)
##   DROP       the Kestrel breaks off, races to the enemy warship, transforms over its roof
##              and the mech drops onto the hull (in-engine cinematic, letterboxed)
##   PLATFORMER Stage 2 on/inside the warship
##   ESCAPE     core destroyed: slow motion, the arena roof blows out, the mech thrusts up to
##              the top hull, transforms into the bike and the camera swings from side view to
##              a chase view behind it (ortho → matched-FOV perspective → orbit)
##   HULL_RUN   Stage 3, 3D behind view along the top of the burning warship
##   ENDING     the bike launches off the bow, the warship explodes, MISSION COMPLETE → title
## Restarting a stage reloads this scene and resumes at that stage's phase (RunSession checkpoint).

signal phase_changed(phase: Phase)

enum Phase { SHOOTER, DROP, PLATFORMER, ESCAPE, HULL_RUN, ENDING, DONE }

@export var camera: GameplayCamera
@export var stage_ui: StageUI
@export var sky: CameraFollower
@export var space_backdrop: SpaceBackdrop
@export var ship: ShipPlayer
@export var shooter_director: LevelDirector
@export var warship_director: PlatformerDirector
@export var warship_layout: WarshipLayout
@export var warship_exterior: Node3D
@export var warship_spawn: Marker3D
@export var hull_director: HullRunDirector
@export var hull_backdrop: HullRunBackdrop
@export var hull_spawn: Marker3D
@export var player_root: Node3D
@export var mech_scene: PackedScene
@export var rider_scene: PackedScene
@export_file("*.tscn") var title_scene: String = "res://ui/title/title_screen.tscn"

## Stage 1 camera origin (far from the warship so the flight there is a real journey).
@export var shooter_camera: Vector3 = Vector3(-700.0, 0.0, 30.0)
## Where the Kestrel transforms, above the landing ring on the roof deck.
@export var drop_point: Vector3 = Vector3(-62.0, 44.0, 0.0)
@export var flight_time: float = 6.0
## Where the mech lands on the top hull after the escape, and the bike starts.
@export var escape_point: Vector3 = Vector3(321.0, 30.6, 0.0)

var phase: Phase = Phase.SHOOTER
var mech: MechPlayer
var rider: HullRider

var _time: float = 0.0
var _cam_update: Callable
var _ending_t: float = 0.0


func _ready() -> void:
	var checkpoint := String(RunSession.checkpoint_id)
	if checkpoint.begins_with("STAGE 3"):
		_start_hull_run_direct.call_deferred()
	elif checkpoint.begins_with("STAGE 2"):
		_start_platformer_direct.call_deferred()
	else:
		_start_shooter.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	if _cam_update.is_valid():
		_cam_update.call(delta)


func get_debug_lines() -> PackedStringArray:
	return PackedStringArray(["CAMPAIGN %s" % Phase.keys()[phase]])


# --- Stage 1 -------------------------------------------------------------------------

func _start_shooter() -> void:
	add_to_group(&"debug_telemetry")
	camera.global_position = shooter_camera
	camera.size = 18.0
	ship.global_position = shooter_camera + Vector3(-12.0, 0.0, -shooter_camera.z)
	shooter_director.stage_cleared.connect(_on_shooter_cleared, CONNECT_ONE_SHOT)
	shooter_director.begin()
	_set_phase(Phase.SHOOTER)


func _on_shooter_cleared() -> void:
	_run_drop()


# --- Transition: flight + ship → mech drop -----------------------------------------

func _run_drop() -> void:
	_set_phase(Phase.DROP)
	stage_ui.letterbox(true)
	ship.set_cinematic(true)
	await _wait(1.6)
	space_backdrop.set_battle_layers_visible(false)
	AudioService.play_music(&"title", 2.5)
	AudioService.play(&"boost")
	stage_ui.show_banner("ENEMY WARSHIP VX-07", "BOARDING RUN — GET ON THAT HULL", 3.4)
	var p0 := ship.global_position
	var p1 := p0 + Vector3(140.0, 4.0, 0.0)
	var p2 := drop_point + Vector3(-190.0, 26.0, 0.0)
	var p3 := drop_point
	var t := 0.0
	var last := p0
	camera.rig_override = true
	var size_tween := create_tween()
	size_tween.tween_property(camera, "size", 26.0, flight_time * 0.5).set_trans(Tween.TRANS_SINE)
	size_tween.tween_property(camera, "size", 16.0, flight_time * 0.5).set_trans(Tween.TRANS_SINE)
	_cam_update = func(delta: float) -> void:
		var goal := ship.global_position + Vector3(8.0, 2.0, 0.0) if is_instance_valid(ship) else camera.global_position
		var c := camera.global_position
		camera.global_position = Vector3(lerpf(c.x, goal.x, clampf(delta * 3.0, 0, 1)), lerpf(c.y, goal.y, clampf(delta * 3.0, 0, 1)), 30.0)
	while t < 1.0:
		await get_tree().process_frame
		t = minf(1.0, t + get_process_delta_time() / flight_time)
		var e := t * t * (3.0 - 2.0 * t)
		var pos := _bezier(p0, p1, p2, p3, e)
		ship.global_position = pos
		var vel := (pos - last) / maxf(get_process_delta_time(), 0.001)
		last = pos
		ship.model.rotation.z = clampf(vel.y * 0.02, -0.5, 0.5)
		ship.model.set_thrust(1.4)
	ship.model.rotation.z = 0.0
	await _wait(0.25)
	_transform_ship_into_mech()
	# Fall onto the deck.
	_cam_update = func(delta: float) -> void:
		if not is_instance_valid(mech):
			return
		var goal := mech.global_position + Vector3(3.0, 4.0, 0.0)
		var c := camera.global_position
		camera.global_position = Vector3(lerpf(c.x, goal.x, clampf(delta * 4.0, 0, 1)), lerpf(c.y, goal.y, clampf(delta * 4.0, 0, 1)), 30.0)
	create_tween().tween_property(camera, "size", 15.0, 0.8)
	var guard := 0.0
	while not mech.is_on_floor() and guard < 4.0:
		await get_tree().physics_frame
		guard += get_physics_process_delta_time()
	# Heavy landing.
	AudioService.play(&"heavy_land")
	camera.add_trauma(ArtStyle.SHAKE_MAJOR)
	for k in 6:
		Vfx.spawn(get_tree(), preload("res://vfx/impact_spark.tscn"), mech.global_position + Vector3(randf_range(-1.2, 1.2), 0.1, 1.0), 1.4,
				{&"direction": Vector3(randf_range(-1, 1), 0.6, 0).normalized()})
	LevelKit.steam(get_tree().get_first_node_in_group(Vfx.ROOT_GROUP), mech.global_position + Vector3(0, 0, 1.2), 1.5).one_shot = true
	await _wait(0.9)
	stage_ui.letterbox(false)
	_cam_update = Callable()
	mech.set_cinematic(false)
	_begin_platformer(false)


func _transform_ship_into_mech() -> void:
	AudioService.play(&"transform")
	var at := ship.global_position
	stage_ui.flash(0.85, 0.7)
	camera.add_trauma(ArtStyle.SHAKE_MAJOR)
	var root := get_tree().get_first_node_in_group(Vfx.ROOT_GROUP)
	if root:
		root.add_child(FragmentBurst.create(ship.model.make_fragments(), at, 3.0))
	Vfx.spawn(get_tree(), preload("res://vfx/collect_burst.tscn"), at + Vector3(0, 0, 1), 3.0, {&"color": Palette.PLAYER_ENERGY})
	ship.remove_from_group(Players.GROUP)
	ship.queue_free()
	mech = mech_scene.instantiate() as MechPlayer
	mech.position = at - Vector3(0.0, 1.25, 0.0) - player_root.global_position
	player_root.add_child(mech)
	mech.set_cinematic(true)
	stage_ui.show_banner("MECH MODE", "", 1.8)


# --- Stage 2 -------------------------------------------------------------------------

func _start_platformer_direct() -> void:
	add_to_group(&"debug_telemetry")
	space_backdrop.set_battle_layers_visible(false)
	_free_ship()
	mech = mech_scene.instantiate() as MechPlayer
	mech.position = warship_spawn.global_position - player_root.global_position
	player_root.add_child(mech)
	_begin_platformer(true)


func _begin_platformer(place: bool) -> void:
	warship_director.player = mech
	warship_director.stage_cleared.connect(_on_core_destroyed, CONNECT_ONE_SHOT)
	warship_director.begin(place)
	_set_phase(Phase.PLATFORMER)


func _on_core_destroyed() -> void:
	_run_escape()


# --- Transition: escape + mech → bike + camera swing ------------------------------------

func _run_escape() -> void:
	_set_phase(Phase.ESCAPE)
	stage_ui.letterbox(true)
	mech.set_cinematic(true)
	mech.grant_invulnerability(30.0)
	_slow_motion(0.3, 1.0)
	for k in 5:
		Vfx.spawn(get_tree(), preload("res://vfx/explosion.tscn"), mech.global_position + Vector3(randf_range(4, 14), randf_range(1, 9), -1.5), randf_range(1.5, 3.0))
		await _wait(0.25)
	camera.unlock()
	camera.follow_target = null
	camera.limits = Rect2()
	camera.rig_override = true
	warship_layout.blast_open()
	AudioService.play(&"explosion_huge")
	AudioService.play_music(&"stage3", 2.0)
	stage_ui.flash(0.5, 0.5, Color(1.0, 0.8, 0.6))
	await _wait(0.6)
	# Thrust up through the hole onto the top hull.
	var start := mech.global_position
	var apex := Vector3(escape_point.x, escape_point.y + 4.0, 0.0)
	mech.set_physics_process(false)
	mech.model.update_pose(MechModel.Pose.DASH, 1.0, 0.0)
	_cam_update = func(delta: float) -> void:
		if not is_instance_valid(mech):
			return
		var goal := mech.global_position + Vector3(0.0, 4.5, 0.0)
		var c := camera.global_position
		camera.global_position = Vector3(lerpf(c.x, goal.x, clampf(delta * 7.0, 0, 1)), lerpf(c.y, goal.y, clampf(delta * 7.0, 0, 1)), 30.0)
	var rise := create_tween()
	rise.tween_method(func(k: float) -> void:
		mech.global_position = start.lerp(apex, k) + Vector3(0, sin(k * PI) * 2.0, 0)
		mech.model.update_pose(MechModel.Pose.AIR, 0.0, 0.016), 0.0, 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await rise.finished
	mech.set_physics_process(true)
	var guard := 0.0
	while not mech.is_on_floor() and guard < 3.0:
		await get_tree().physics_frame
		guard += get_physics_process_delta_time()
	camera.add_trauma(ArtStyle.SHAKE_ELITE_DEATH)
	stage_ui.show_banner("THE WARSHIP IS GOING DOWN", "", 2.0)
	await _wait(0.8)
	_transform_mech_into_bike()
	await _swing_camera_behind(2.6)
	stage_ui.letterbox(false)
	_cam_update = Callable()
	_begin_hull_run(false)


func _transform_mech_into_bike() -> void:
	_cam_update = Callable()
	AudioService.play(&"transform")
	var at := mech.global_position
	stage_ui.flash(0.9, 0.8)
	camera.add_trauma(ArtStyle.SHAKE_MAJOR)
	var root := get_tree().get_first_node_in_group(Vfx.ROOT_GROUP)
	if root:
		root.add_child(FragmentBurst.create(mech.model.make_fragments(), at + Vector3(0, 1.2, 0), 3.0))
	mech.remove_from_group(Players.GROUP)
	mech.queue_free()
	rider = rider_scene.instantiate() as HullRider
	rider.position = Vector3(at.x, escape_point.y, 0.0) - player_root.global_position
	player_root.add_child(rider)
	rider.set_cinematic(true)
	stage_ui.show_banner("BIKE MODE", "", 1.8)
	# The 3D world takes over under the flash: sky, planets, battle.
	sky.visible = false
	warship_exterior.visible = false
	hull_backdrop.activate()


## Side-view ortho → identical-looking perspective → orbit to a chase view behind the bike.
func _swing_camera_behind(duration: float) -> void:
	var base := camera.global_position
	var target := rider.global_position
	var start_h := base.y - target.y
	var start_x := base.x - target.x
	var start_fov := GameplayCamera.fov_matching(camera.size, 30.0)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = start_fov
	camera.far = 2400.0
	var chase := hull_director.chase_offset
	var t := 0.0
	while t < 1.0:
		await get_tree().process_frame
		t = minf(1.0, t + get_process_delta_time() / duration)
		var e := t * t * (3.0 - 2.0 * t)
		var p := rider.global_position
		var angle := e * PI * 0.5
		var dist := lerpf(30.0, absf(chase.x), e)
		var h := lerpf(start_h, chase.y, e)
		var side_x := lerpf(start_x, 0.0, e)
		camera.global_position = Vector3(p.x + side_x - sin(angle) * dist, p.y + h, cos(angle) * dist)
		var look := Vector3(p.x + lerpf(side_x, hull_director.look_ahead, e), p.y + lerpf(start_h, 1.0, e), 0.0)
		camera.look_at(look, Vector3.UP)
		camera.fov = lerpf(start_fov, hull_director.chase_fov, e)


# --- Stage 3 -------------------------------------------------------------------------

func _start_hull_run_direct() -> void:
	add_to_group(&"debug_telemetry")
	_free_ship()
	sky.visible = false
	warship_exterior.visible = false
	rider = rider_scene.instantiate() as HullRider
	rider.position = hull_spawn.global_position - player_root.global_position
	player_root.add_child(rider)
	_begin_hull_run(true)


func _begin_hull_run(place: bool) -> void:
	hull_director.player = rider
	hull_director.finished.connect(_run_ending, CONNECT_ONE_SHOT)
	hull_director.begin(place)
	_set_phase(Phase.HULL_RUN)


# --- Ending ------------------------------------------------------------------------------

func _run_ending() -> void:
	_set_phase(Phase.ENDING)
	stage_ui.letterbox(true)
	rider.kill_y = -1e9
	rider.set_cinematic(true)
	rider.velocity.x = maxf(rider.velocity.x, 38.0)
	stage_ui.show_banner("LAUNCH!", "", 1.6)
	# Wait for the bow lip, then leap into space.
	var guard := 0.0
	while rider.global_position.x < 2735.0 and guard < 4.0:
		await get_tree().physics_frame
		guard += get_physics_process_delta_time()
	# Leap into space: the bike glides out along a rising arc toward the ringed giant.
	hull_director.camera_enabled = false
	rider.set_physics_process(false)
	rider.launch(0.0)
	var from := rider.global_position
	var glide := create_tween()
	glide.tween_method(func(k: float) -> void:
		if is_instance_valid(rider):
			rider.global_position = from + Vector3(k * 200.0, sin(minf(k, 0.5) * PI) * 9.0 + k * 5.0, k * 26.0)
			rider.model.rotation.z = lerpf(0.25, 0.05, k), 0.0, 1.0, 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Wide shot: the bow and the doomed warship on the left, the bike flying out on the right.
	var cam_from := camera.global_position
	var cam_to := Vector3(2808.0, HullTrack.DECK_Y + 8.0, 26.0)
	var look_from := rider.global_position + Vector3(16.0, 0, 0)
	_ending_t = 0.0
	_cam_update = func(delta: float) -> void:
		_ending_t = minf(1.0, _ending_t + delta / 2.2)
		var e := _ending_t * _ending_t * (3.0 - 2.0 * _ending_t)
		camera.global_position = cam_from.lerp(cam_to, e)
		var focus := Vector3(2640.0, HullTrack.DECK_Y + 4.0, 0.0)
		if is_instance_valid(rider) and _ending_t < 0.8:
			focus = focus.lerp(rider.global_position, 0.3 * (1.0 - _ending_t))
		camera.look_at(look_from.lerp(focus, e), Vector3.UP)
		camera.fov = lerpf(camera.fov, 58.0, clampf(delta * 2.0, 0.0, 1.0))
	await _wait(1.6)
	# The warship blows apart behind the bike, stern to bow.
	for n in 16:
		var x := 2380.0 + n * 24.0
		Explosion3D.spawn(get_tree(), Vector3(x, HullTrack.DECK_Y + randf_range(0.0, 10.0), randf_range(-16.0, 16.0)), randf_range(10.0, 18.0), 0.25 if n > 12 else 0.08)
		await _wait(0.11)
	stage_ui.flash(1.0, 1.6)
	camera.add_trauma(ArtStyle.SHAKE_MAX_TRAUMA)
	for n in 7:
		Explosion3D.spawn(get_tree(), Vector3(2720.0 - n * 60.0, HullTrack.DECK_Y + 4.0, 0.0), 26.0)
	await _wait(0.8)
	stage_ui.show_banner("MISSION COMPLETE", "SCORE  %08d" % RunSession.score, 6.0)
	AudioService.play_music(&"mission_complete", 1.0)
	await _wait(6.5)
	_set_phase(Phase.DONE)
	RunSession.reset_run()
	SceneRouter.go_to(title_scene)


# --- Helpers ---------------------------------------------------------------------------

func _free_ship() -> void:
	if is_instance_valid(ship):
		ship.remove_from_group(Players.GROUP)
		ship.queue_free()


func _slow_motion(scale: float, real_seconds: float) -> void:
	Engine.time_scale = scale
	get_tree().create_timer(real_seconds, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


static func _bezier(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t


func _set_phase(next: Phase) -> void:
	phase = next
	phase_changed.emit(phase)
