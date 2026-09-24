extends TestCase
## The seamless campaign: one scene, stages chained by in-world cinematics, checkpoint resume.

const DT := 1.0 / 60.0

var campaign: Node
var cd: CampaignDirector


func _load(checkpoint: String = "") -> void:
	if not checkpoint.is_empty():
		RunSession.save_checkpoint(StringName(checkpoint))
	campaign = (load("res://levels/campaign/campaign.tscn") as PackedScene).instantiate()
	add_autofree(campaign)
	cd = campaign.get_node("CampaignDirector") as CampaignDirector
	await wait_process_frames(3)


func _wait_phase(phase: CampaignDirector.Phase, max_seconds: float) -> bool:
	var t := 0.0
	while cd.phase != phase and t < max_seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
	return cd.phase == phase


func test_campaign_is_the_start_stage() -> void:
	var main := (load("res://main/main.tscn") as PackedScene).instantiate()
	assert_eq(main.first_stage, "res://levels/campaign/campaign.tscn", "Start goes to the seamless campaign")
	main.free()


func test_starts_in_the_shooter() -> void:
	await _load()
	assert_eq(cd.phase, CampaignDirector.Phase.SHOOTER, "shooter phase")
	assert_true(Players.find(get_tree()) is ShipPlayer, "the ship flies")
	assert_eq(cd.shooter_director.state, LevelDirector.State.INTRO, "stage 1 running")
	assert_true(cd.shooter_director.hand_off, "stage 1 hands off instead of changing scenes")
	assert_near(cd.camera.global_position.x, cd.shooter_camera.x, 0.5, "camera at the stage 1 origin")


func test_drop_transforms_the_ship_and_lands_the_mech_on_the_hull() -> void:
	await _load()
	cd.flight_time = 0.6
	var level_before := SceneRouter.current_level
	cd.shooter_director.stage_cleared.emit()
	assert_true(await _wait_phase(CampaignDirector.Phase.PLATFORMER, 12.0), "reached the platformer")
	assert_true(Players.find(get_tree()) is MechPlayer, "the mech replaced the ship")
	assert_true(cd.mech.global_position.y > 29.0 and cd.mech.is_on_floor(), "landed on the roof deck")
	assert_eq(cd.warship_director.player, cd.mech, "stage 2 director drives the mech")
	assert_eq(SceneRouter.current_level, level_before, "no scene change")


func test_resume_at_stage_2_and_escape_into_the_hull_run() -> void:
	await _load("STAGE 2")
	assert_eq(cd.phase, CampaignDirector.Phase.PLATFORMER, "checkpoint resumes the platformer")
	assert_true(Players.find(get_tree()) is MechPlayer, "mech spawned")
	cd.warship_director.stage_cleared.emit()
	assert_true(await _wait_phase(CampaignDirector.Phase.HULL_RUN, 16.0), "escape → hull run")
	assert_true(Players.find(get_tree()) is HullRider, "the bike replaced the mech")
	assert_eq(cd.camera.projection, Camera3D.PROJECTION_PERSPECTIVE, "camera swung into the 3D chase view")
	assert_false(is_instance_valid(cd.warship_layout.blast_roof), "arena roof blown open")
	assert_true(cd.hull_backdrop.active, "3D sky and planets active")


func test_resume_at_stage_3_and_finish_plays_the_ending() -> void:
	await _load("STAGE 3")
	assert_eq(cd.phase, CampaignDirector.Phase.HULL_RUN, "checkpoint resumes the hull run")
	cd.hull_director.intro_time = 0.0
	await wait_physics_frames(3)
	cd.rider.teleport(Vector3(cd.hull_director.track.finish_x + 1.0, HullTrack.DECK_Y + 0.6, 0))
	assert_true(await _wait_phase(CampaignDirector.Phase.ENDING, 3.0), "finish → ending cinematic")
	assert_true(cd.rider.in_cinematic(), "control handed to the ending cinematic")
