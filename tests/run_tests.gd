extends SceneTree
## Headless test runner.
## Run: $GODOT --headless --path . --script res://tests/run_tests.gd
## Optional filter: append `-- test_health` to run matching files only.
## Exit code is 0 only when every test passes.

const TEST_DIR := "res://tests/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		filter = args[0]

	var passed := 0
	var failed := 0
	for file in _test_files(filter):
		var script := load(TEST_DIR + file) as GDScript
		if script == null:
			printerr("FAIL %s: script failed to load" % file)
			failed += 1
			continue
		for method_name in _test_methods(script):
			var ok := await _run_one(script, method_name)
			if ok:
				passed += 1
				print("  ok   %s::%s" % [file, method_name])
			else:
				failed += 1

	print("\n%d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _run_one(script: GDScript, method_name: String) -> bool:
	# Autoload names are not compile-time identifiers inside a --script main loop.
	root.get_node(^"RunSession").reset_run()
	paused = false
	var test: TestCase = script.new()
	root.add_child(test)
	await Callable(test, method_name).call()
	var failures := test.failures.duplicate()
	test.queue_free()
	await process_frame
	for message in failures:
		printerr("  FAIL %s::%s — %s" % [script.resource_path.get_file(), method_name, message])
	return failures.is_empty()


func _test_files(filter: String) -> PackedStringArray:
	var files := PackedStringArray()
	for file in DirAccess.get_files_at(TEST_DIR):
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_case.gd":
			if filter.is_empty() or file.contains(filter):
				files.append(file)
	files.sort()
	return files


func _test_methods(script: GDScript) -> PackedStringArray:
	var names := PackedStringArray()
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	return names
