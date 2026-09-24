extends TestCase

const GAMEPLAY_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"fire", &"jump", &"dash", &"echo", &"special", &"pause",
]


func test_every_gameplay_action_has_keyboard_and_controller_bindings() -> void:
	for action in GAMEPLAY_ACTIONS:
		assert_true(InputMap.has_action(action), "action '%s' exists" % action)
		if not InputMap.has_action(action):
			continue
		var has_key := false
		var has_pad := false
		for event in InputMap.action_get_events(action):
			has_key = has_key or event is InputEventKey
			has_pad = has_pad or event is InputEventJoypadButton or event is InputEventJoypadMotion
		assert_true(has_key, "'%s' has a keyboard binding" % action)
		assert_true(has_pad, "'%s' has a controller binding" % action)


func test_bindings_accept_any_device() -> void:
	for action in GAMEPLAY_ACTIONS:
		for event in InputMap.action_get_events(action):
			assert_eq(event.device, -1, "'%s' event listens to all devices" % action)
