extends TestCase
## HUD presentation and the contextual tutorial card.


func test_hud_shows_echo_none_and_module_name() -> void:
	var hud := (load("res://ui/hud/hud.tscn") as PackedScene).instantiate()
	add_autofree(hud)
	await wait_process_frames(1)
	var echo_label := hud.find_child("*", true, false)
	var labels := hud.find_children("*", "Label", true, false)
	var texts := labels.map(func(l: Label) -> String: return l.text)
	assert_true(texts.has("ECHO: NONE"), "neutral echo label, no debug wording")
	assert_false(texts.has("WEAPON: BASIC"), "old debug label gone")
	RunSession.equip_echo(EchoModules.ARC, 50)
	texts = hud.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	assert_true(texts.has("ECHO: ARC"), "active echo name shown")
	assert_true(texts.has("×50"), "ammo shown")
	assert_true(echo_label != null, "hud built")


func test_last_health_segment_pulses_and_loss_animates() -> void:
	var hud := (load("res://ui/hud/hud.tscn") as PackedScene).instantiate()
	add_autofree(hud)
	await wait_process_frames(1)
	RunSession.set_health(1)
	var pips := hud.find_children("*", "SegmentPip", true, false).filter(func(p: SegmentPip) -> bool: return p.shape == SegmentPip.Shape.BAR)
	assert_eq(pips.size(), RunSession.max_health, "one pip per health point")
	assert_true((pips[0] as SegmentPip).pulse, "last remaining segment pulses")
	assert_false((pips[1] as SegmentPip).filled, "lost segments empty")


func test_tutorial_card_completes_on_action_and_remembers() -> void:
	LevelScaffold.build(self)
	LevelScaffold.ship(self)
	var card := TutorialCard.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_autofree(card)
	card._delay = 0.0
	await wait_process_frames(2)
	assert_eq(card.active_id, "move", "first card teaches movement")
	Input.action_press(&"move_right")
	await get_tree().create_timer(1.2).timeout
	Input.action_release(&"move_right")
	assert_true(Settings.tutorials_done.has("move"), "movement card completed by moving")
	assert_true(card.active_id != "move", "card dismissed")


func test_tutorials_can_be_disabled() -> void:
	LevelScaffold.build(self)
	LevelScaffold.ship(self)
	Settings.tutorials_enabled = false
	var card := TutorialCard.new()
	add_autofree(card)
	card._delay = 0.0
	await wait_process_frames(3)
	assert_eq(card.active_id, "", "no card when tutorials are off")
