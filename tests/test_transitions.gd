extends TestCase
## Shutter-wipe level changes: the swap happens behind closed plates, `prepare` runs at the swap,
## and the screen ends clear. (Headless runs normally swap instantly; this forces the animation.)


func test_change_level_wipes_prepares_and_reveals() -> void:
	var main: Node = (load("res://main/main.tscn") as PackedScene).instantiate()
	add_autofree(main)
	await wait_process_frames(2)
	var was_enabled := SceneRouter.transitions_enabled
	SceneRouter.transitions_enabled = true
	var prepared := [false]
	var path: String = main.first_stage
	var saw_old_level_when_prepared := [false]
	var old_level := SceneRouter.current_level
	SceneRouter.change_level(path, func() -> void:
		prepared[0] = true
		saw_old_level_when_prepared[0] = SceneRouter.current_level == old_level)
	assert_true(SceneRouter.is_changing(), "a change is running")
	assert_eq(SceneRouter.current_path, main.start_level, "the old level stays until the plates close")
	var t := 0.0
	while SceneRouter.is_changing() and t < 5.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	assert_true(prepared[0], "prepare ran")
	assert_true(saw_old_level_when_prepared[0], "prepare ran right before the swap")
	assert_eq(SceneRouter.current_path, path, "new level mounted")
	t = 0.0
	while (SceneRouter.transition.covered or SceneRouter.transition.get_child(0).visible) and t < 5.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	assert_false(SceneRouter.transition.covered, "plates opened again")
	SceneRouter.transitions_enabled = was_enabled
	SceneRouter.go_to(main.start_level)
	await wait_process_frames(2)


func test_change_level_ignores_requests_while_running() -> void:
	var main: Node = (load("res://main/main.tscn") as PackedScene).instantiate()
	add_autofree(main)
	await wait_process_frames(2)
	var was_enabled := SceneRouter.transitions_enabled
	SceneRouter.transitions_enabled = true
	SceneRouter.change_level(main.first_stage)
	SceneRouter.change_level(main.start_level)
	var t := 0.0
	while SceneRouter.is_changing() and t < 5.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	assert_eq(SceneRouter.current_path, main.first_stage, "the second request was ignored")
	await wait_process_frames(60)
	SceneRouter.transitions_enabled = was_enabled
	SceneRouter.go_to(main.start_level)
	await wait_process_frames(2)
