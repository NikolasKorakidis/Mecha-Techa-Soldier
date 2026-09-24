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


func test_pause_toggles_tree_and_hud() -> void:
	var main: Node = (load("res://main/main.tscn") as PackedScene).instantiate()
	add_autofree(main)
	await wait_process_frames(1)
	main.set_paused(true)
	assert_true(get_tree().paused, "tree paused")
	assert_true(main.get_node("%HUD").get_node("%PauseLabel").visible, "pause label shown")
	main.set_paused(false)
	assert_false(get_tree().paused, "tree unpaused")
