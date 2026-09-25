class_name CampaignDirector
extends Node
## The whole run in one continuous world — no scene changes between stages:
##   SHOOTER    Stage 1 in open space (static side-view camera far left of the warship)
##   DROP       the camera swings behind the Kestrel, it dives at the warship far below (manga
##              speed lines), transforms half way down and the mech lands on the roof deck
##   PLATFORMER Stage 2 on/inside the warship
##   ESCAPE     core destroyed: slow motion, the arena roof blows out, the mech thrusts up to
##              the top hull, transforms into the bike and the camera swings from side view to
##              a chase view behind it (ortho → matched-FOV perspective → orbit)
##   HULL_RUN   Stage 3, 3D behind view along the top of the burning warship
##   ENDING     the bike launches off the bow, the warship explodes and the picture de-rezzes
##   RETRO      Stage 4, the 8-bit rearrangement (RetroStage), then MISSION COMPLETE → title
## Restarting a stage reloads this scene and resumes at that stage's phase (RunSession checkpoint).

signal phase_changed(phase: Phase)

enum Phase { SHOOTER, DROP, PLATFORMER, ESCAPE, HULL_RUN, ENDING, RETRO, DONE }

@export var camera: GameplayCamera
@export var stage_ui: StageUI
@export var sky: CameraFollower
@export var space_backdrop: SpaceBackdrop
@export var perspective_backdrop: PerspectiveBackdrop
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
## Where the mech touches down on the roof deck after the boarding dive.
@export var drop_point: Vector3 = Vector3(-62.0, 44.0, 0.0)
## Length of the whole boarding cinematic (pull-in, camera swing, dive).
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
	# The Stage 1 backdrop's real warship model replaces the flat side-view superstructure.
	warship_exterior.visible = false
	var checkpoint := String(RunSession.checkpoint_id)
	if checkpoint.begins_with("STAGE 4"):
		_start_retro_direct.call_deferred()
	elif checkpoint.begins_with("STAGE 3"):
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
	_cam_update = Callable()
	camera.rig_override = true
	AudioService.play_music(&"title", 2.5)
	var fx := MangaFx.new()
	add_child(fx)
	# Beat 1: the Kestrel eases to the middle of the side view.
	var beat := flight_time * 0.2
	var from := ship.global_position
	var mid := Vector3(camera.global_position.x - 3.0, camera.global_position.y + 1.0, 0.0)
	stage_ui.show_banner("ENEMY WARSHIP VX-07", "BOARDING RUN — GET ON THAT HULL", beat + flight_time * 0.3)
	await _tween_ship(from, mid, beat)
	# Beat 2: swap to the dive world under a flash and orbit the camera behind the ship.
	stage_ui.flash(0.6, 0.6)
	var saved_near := camera.near
	var saved_far := camera.far
	var cine := DropCinematic.new()
	add_child(cine)
	cine.setup(ship.global_position)
	_set_drop_world_visible(false)
	AudioService.play(&"boost")
	await _swing_behind_ship(flight_time * 0.37)
	# Beat 3: the dive. Speed lines build, the Kestrel transforms half way down, the mech keeps
	# falling head-first at the runway.
	var dive := flight_time * 0.43
	var start := ship.global_position
	var target := cine.landing_point(start)
	var dir := (target - start).normalized()
	var start_fov := camera.fov
	var body: Node3D = ship
	var close := 0.0
	var t := 0.0
	while t < 1.0:
		await get_tree().process_frame
		var delta := get_process_delta_time()
		t = minf(1.0, t + delta / dive)
		var u := t * t * 0.82
		var p := start.lerp(target, u)
		if t >= 0.45 and body == ship:
			fx.impact(0.12)
			_transform_ship_into_mech()
			mech.set_physics_process(false)
			body = mech
		body.global_position = p
		if body == ship:
			ship.model.set_thrust(1.8)
			ship.model.rotation.z = lerpf(ship.model.rotation.z, -0.75, clampf(delta * 5.0, 0, 1))
		else:
			mech.rotation.z = lerpf(mech.rotation.z, -0.9, clampf(delta * 6.0, 0, 1))
			mech.model.update_pose(MechModel.Pose.DASH, 1.0, delta)
		# After the transform the camera closes in on the falling mech.
		if body == mech:
			close = minf(1.0, close + delta * 3.0)
		fx.set_intensity(lerpf(0.25, 1.0, t))
		camera.fov = lerpf(start_fov, 78.0, t)
		var back := lerpf(lerpf(26.0, 17.0, t), 8.0, close)
		camera.global_position = p - dir * back + Vector3(0.0, lerpf(7.0, 2.5, close), lerpf(5.0, 2.0, close))
		camera.look_at(p + dir * 45.0, Vector3.UP)
		camera.add_trauma(delta * 0.5 * t)
	# Beat 4: impact frame hides the cut back to the side view over the Stage 2 roof.
	fx.impact(0.14)
	AudioService.play(&"explosion_large")
	cine.restore()
	_set_drop_world_visible(true)
	perspective_backdrop.set_boarding()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation = Vector3.ZERO
	camera.size = 15.0
	camera.near = saved_near
	camera.far = saved_far
	mech.rotation = Vector3.ZERO
	mech.global_position = drop_point + Vector3(0.0, 9.0, 0.0)
	mech.velocity = Vector3(0.0, -32.0, 0.0)
	mech.set_physics_process(true)
	camera.global_position = mech.global_position + Vector3(3.0, 2.0, 30.0)
	create_tween().tween_method(fx.set_intensity, 0.8, 0.0, 0.6)
	_cam_update = func(delta: float) -> void:
		if not is_instance_valid(mech):
			return
		var goal := mech.global_position + Vector3(3.0, 4.0, 0.0)
		var c := camera.global_position
		camera.global_position = Vector3(lerpf(c.x, goal.x, clampf(delta * 6.0, 0, 1)), lerpf(c.y, goal.y, clampf(delta * 6.0, 0, 1)), 30.0)
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
	fx.queue_free()
	stage_ui.letterbox(false)
	_cam_update = Callable()
	mech.set_cinematic(false)
	_begin_platformer(false)


func _tween_ship(from: Vector3, to: Vector3, duration: float) -> void:
	var t := 0.0
	while t < 1.0:
		await get_tree().process_frame
		t = minf(1.0, t + get_process_delta_time() / maxf(duration, 0.01))
		ship.global_position = from.lerp(to, t * t * (3.0 - 2.0 * t))
		ship.model.set_thrust(1.2)


## The side-view layers and the Stage 2/3 geometry make no sense from the dive's angles.
func _set_drop_world_visible(on: bool) -> void:
	sky.visible = on
	(warship_director.get_parent() as Node3D).visible = on
	(hull_director.get_parent() as Node3D).visible = on
	space_backdrop.set_battle_layers_visible(false)


## Side-view ortho → matched perspective → orbit to behind and above the Kestrel, looking down
## past its nose at the warship below.
func _swing_behind_ship(duration: float) -> void:
	var p := ship.global_position
	var start_h := camera.global_position.y - p.y
	var start_x := camera.global_position.x - p.x
	var start_fov := GameplayCamera.fov_matching(camera.size, 30.0)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = start_fov
	camera.near = 0.4
	camera.far = 6000.0
	var t := 0.0
	while t < 1.0:
		await get_tree().process_frame
		t = minf(1.0, t + get_process_delta_time() / maxf(duration, 0.01))
		var e := t * t * (3.0 - 2.0 * t)
		var angle := e * PI * 0.5
		var dist := lerpf(30.0, 26.0, e)
		var side_x := lerpf(start_x, 0.0, e)
		camera.global_position = Vector3(p.x + side_x - sin(angle) * dist, p.y + lerpf(start_h, 7.0, e), cos(angle) * dist + 5.0 * e)
		# The look drops toward the warship ahead of the orbit, so it is in view early.
		var down := smoothstep(0.0, 0.6, t)
		camera.look_at(Vector3(p.x + lerpf(side_x, 45.0, e), p.y + lerpf(start_h, -30.0, down), 0.0), Vector3.UP)
		camera.fov = lerpf(start_fov, 55.0, e)
		# The nose tips down as the camera settles: the dive is coming.
		ship.model.rotation.z = lerpf(0.0, -0.3, smoothstep(0.5, 1.0, t))
		ship.model.set_thrust(1.2)


func _transform_ship_into_mech() -> void:
	AudioService.play(&"transform")
	var at := ship.global_position
	stage_ui.flash(0.45, 0.5)
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
	perspective_backdrop.set_boarding()
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
	perspective_backdrop.set_active(false)
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
	camera.near = 0.4
	camera.far = 4500.0
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
	perspective_backdrop.set_active(false)
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
	var finish := hull_director.track.finish_x
	while rider.global_position.x < hull_director.track.bow_x() - 10.0 and guard < 4.0:
		await get_tree().physics_frame
		guard += get_physics_process_delta_time()
	# Leap into space: the bike glides out along a long rising arc away from the ship.
	hull_director.camera_enabled = false
	rider.set_physics_process(false)
	rider.launch(0.0)
	var from := rider.global_position
	var glide := create_tween()
	glide.tween_method(func(k: float) -> void:
		if is_instance_valid(rider):
			rider.global_position = from + Vector3(k * 520.0, sin(minf(k, 0.5) * PI) * 14.0 + k * 90.0, k * 420.0)
			rider.model.rotation.z = lerpf(0.25, 0.05, k), 0.0, 1.0, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Beat 1: hold at the bow and watch the bike leap. Beat 2: pull far out to a wide
	# three-quarter view looking back, until the whole 3.6 km warship fills the frame.
	var ship := hull_backdrop.warship
	var ship_center := Vector3(HullRunBackdrop.WARSHIP_CENTER_X, HullTrack.DECK_Y - 70.0, 0.0)
	var cam_from := camera.global_position
	var cam_mid := Vector3(finish + 70.0, HullTrack.DECK_Y + 16.0, 40.0)
	var cam_to := Vector3(finish + 420.0, HullTrack.DECK_Y + 190.0, 820.0)
	camera.near = 2.0
	camera.far = 12000.0
	_ending_t = 0.0
	_cam_update = func(delta: float) -> void:
		_ending_t += delta
		var bike := rider.global_position if is_instance_valid(rider) else cam_mid
		if _ending_t < 1.4:
			var e := smoothstep(0.0, 1.4, _ending_t)
			camera.global_position = cam_from.lerp(cam_mid, e)
			camera.look_at(bike, Vector3.UP)
			camera.fov = lerpf(camera.fov, 62.0, clampf(delta * 2.0, 0.0, 1.0))
		else:
			var e := smoothstep(0.0, 1.0, minf(1.0, (_ending_t - 1.4) / 3.4))
			camera.global_position = cam_mid.lerp(cam_to, e) + Vector3(0, 0, sin(_ending_t * 0.3) * 20.0)
			camera.look_at(bike.lerp(ship_center, e), Vector3.UP)
			camera.fov = lerpf(camera.fov, 58.0, clampf(delta * 2.0, 0.0, 1.0))
	# The whole hull is burning by now.
	for n in 36:
		ship.add_fire(ship.random_surface_point(), randf_range(1.5, 3.5))
	await _wait(3.2)
	# The track details and hazards would float in front of the dying hull: drop them.
	hull_director.track.visible = false
	for enemy in get_tree().get_nodes_in_group(SpaceEnemy.GROUP):
		if enemy is Node3D and not (enemy as Node3D).is_queued_for_deletion():
			(enemy as Node3D).visible = false
	await _wait(1.6)
	# Beat 3: the warship tears itself apart stern to bow, the sections break away, core flash.
	AudioService.play(&"explosion_huge")
	camera.add_trauma(0.25)
	ship.explosion_scale = 34.0
	ship.destroy(4.0)
	await _wait(2.0)
	AudioService.play(&"explosion_huge")
	await ship.destroyed
	stage_ui.flash(1.0, 1.6)
	camera.add_trauma(ArtStyle.SHAKE_MAX_TRAUMA)
	AudioService.play(&"explosion_huge")
	for n in 5:
		Explosion3D.spawn(get_tree(), ship.to_global(Vector3(-400.0 + n * 200.0, -30.0, 0.0)), 160.0)
	await _wait(0.8)
	# The picture de-rezzes into 8 bits and Stage 4 begins.
	stage_ui.show_banner("VX-07 DESTROYED", "SCORE  %08d" % RunSession.score, 3.0)
	await _wait(3.2)
	stage_ui.letterbox(false)
	await _start_retro(true)


# --- Stage 4 (8-bit) ---------------------------------------------------------------------

func _start_retro_direct() -> void:
	add_to_group(&"debug_telemetry")
	_free_ship()
	await _start_retro(false)


func _start_retro(with_transition: bool) -> void:
	var retro := get_tree().get_first_node_in_group(&"retro_stage") as RetroStage
	if retro == null:
		push_error("CampaignDirector: no RetroStage in the campaign scene.")
		return
	var fx := PixelTransition.new()
	add_child(fx)
	if with_transition:
		AudioService.stop_music(1.0)
		await fx.play(1.0, 48.0, 0.0, 1.0, 1.3)
	else:
		fx.play(48.0, 48.0, 1.0, 1.0, 0.01)
	_cam_update = Callable()
	if is_instance_valid(rider):
		rider.remove_from_group(Players.GROUP)
		rider.queue_free()
	_set_phase(Phase.RETRO)
	retro.cleared.connect(_on_retro_cleared, CONNECT_ONE_SHOT)
	retro.begin()
	await fx.play(48.0, 1.0, 1.0, 0.0, 1.0)
	fx.queue_free()


func _on_retro_cleared() -> void:
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


func _set_phase(next: Phase) -> void:
	phase = next
	phase_changed.emit(phase)
