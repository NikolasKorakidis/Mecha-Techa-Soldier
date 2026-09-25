extends TestCase


func test_main_loads_start_level_and_switches_rooms() -> void:
	var main: Node = (load("res://main/main.tscn") as PackedScene).instantiate()
	add_autofree(main)
	await wait_process_frames(2)
	var first := SceneRouter.current_level
	assert_true(is_instance_valid(first), "start level loaded")
	assert_eq(SceneRouter.current_path, main.start_level, "router tracks start level path")
	assert_true(GameplayCamera.find(get_tree()) != null, "level provides a gameplay camera")

	main.next_dev_room()
	await wait_process_frames(2)
	assert_true(is_instance_valid(SceneRouter.current_level), "a room is loaded after switching")
	assert_eq(main.get_node("%CurrentLevel").get_child_count(), 1, "exactly one level is mounted")


func test_pause_opens_menu_and_freezes_the_tree() -> void:
	var main: Node = (load("res://main/main.tscn") as PackedScene).instantiate()
	add_autofree(main)
	await wait_process_frames(1)
	main.start_game()
	await wait_process_frames(2)
	main.set_paused(true)
	assert_true(get_tree().paused, "tree paused")
	assert_true(main.get_node("%PauseMenu").is_open, "pause menu open")
	var director := SceneRouter.current_level.get_node("Stage1/LevelDirector") as LevelDirector
	var t := director.stage_time
	await wait_physics_frames(20)
	assert_eq(director.stage_time, t, "stage time frozen while paused")
	main.set_paused(false)
	assert_false(get_tree().paused, "tree unpaused")
	assert_false(main.get_node("%PauseMenu").is_open, "menu closed")


func test_title_starts_game_and_quit_returns() -> void:
	var main: Node = (load("res://main/main.tscn") as PackedScene).instantiate()
	add_autofree(main)
	await wait_process_frames(1)
	assert_eq(SceneRouter.current_path, main.start_level, "boots to the title card")
	assert_false(main.get_node("%HUD").visible, "no HUD on the title card")
	main.start_game()
	await wait_process_frames(1)
	assert_eq(SceneRouter.current_path, main.first_stage, "start goes to stage 1")
	assert_true(main.get_node("%HUD").visible, "HUD in gameplay")
	RunSession.add_score(500)
	main.restart_stage()
	await wait_process_frames(1)
	assert_eq(RunSession.score, 0, "restart restores the stage-entry score")
	main.quit_to_title()
	await wait_process_frames(1)
	assert_eq(SceneRouter.current_path, main.start_level, "quit returns to the title")


func test_stage_select_starts_the_campaign_at_each_stage() -> void:
	var main: Node = (load("res://main/main.tscn") as PackedScene).instantiate()
	add_autofree(main)
	await wait_process_frames(1)
	assert_true(SceneRouter.current_level.has_signal(&"stage_requested"), "title offers stage select")
	var expected := {1: CampaignDirector.Phase.SHOOTER, 2: CampaignDirector.Phase.PLATFORMER, 3: CampaignDirector.Phase.HULL_RUN}
	for stage: int in [3, 2, 1]:
		main.start_at_stage(stage)
		await wait_process_frames(4)
		assert_eq(SceneRouter.current_path, main.first_stage, "stage %d loads the campaign" % stage)
		var cd := SceneRouter.current_level.get_node("CampaignDirector") as CampaignDirector
		assert_eq(cd.phase, expected[stage], "stage %d starts in the right phase" % stage)
		main.quit_to_title()
		await wait_process_frames(2)
