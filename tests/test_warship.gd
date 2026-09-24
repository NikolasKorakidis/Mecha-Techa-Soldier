extends TestCase
## Stage 2 (standalone warship level): drop-zone start, checkpoints, boss gate, respawn,
## Reactor Core damage window.

const DT := 1.0 / 60.0


func _warship() -> Node:
	var level := (load("res://levels/warship/warship_level.tscn") as PackedScene).instantiate()
	add_autofree(level)
	await wait_physics_frames(2)
	return level


func test_warship_starts_on_the_roof_deck_with_checkpoints_and_enemies() -> void:
	var level: Node = await _warship()
	var director := level.get_node("Segment/PlatformerDirector") as PlatformerDirector
	var mech := Players.find(get_tree())
	assert_true(mech is MechPlayer, "the player is the mech")
	assert_true(mech.global_position.y > 29.0, "starts on the roof deck (drop zone)")
	assert_true(get_tree().get_nodes_in_group(&"checkpoints").size() >= 4, "checkpoints placed")
	assert_true(level.get_node("Segment/Enemies").get_child_count() >= 10, "enemies placed")
	assert_false(level.get_node("Segment/BossGate").visible, "arena gate open before the fight")
	assert_eq(director.camera.follow_target, mech, "camera follows the mech")


func test_hatch_leads_down_into_the_bay() -> void:
	await _warship()
	var mech := Players.find(get_tree()) as MechPlayer
	mech.read_devices = false
	mech.teleport(Vector3(WarshipLayout.HATCH_X + WarshipLayout.HATCH_WIDTH * 0.5, 31.0, 0))
	for i in 150:
		mech.tick(DT, MechInput.new())
		await get_tree().physics_frame
	assert_true(mech.global_position.y < 1.0 and mech.is_on_floor(), "fell through the hatch onto the bay floor")


func test_boss_gate_lock_and_escape() -> void:
	var level: Node = await _warship()
	var director := level.get_node("Segment/PlatformerDirector") as PlatformerDirector
	director.warning_time = 0.1
	director.intro_time = 0.0
	await wait_physics_frames(2)
	var mech := Players.find(get_tree()) as MechPlayer
	mech.teleport(Vector3(director.boss_trigger_x + 1.0, 0.5, 0))
	await wait_physics_frames(3)
	assert_eq(director.state, PlatformerDirector.State.BOSS_WARNING, "crossing the trigger starts the boss")
	assert_true(director.camera.is_locked(), "camera locked to the arena")
	assert_true(level.get_node("Segment/BossGate").visible, "gate sealed")
	await wait_physics_frames(12)
	assert_true(director.boss is ReactorCore, "reactor core spawned")
	director.boss.defeated.emit()
	assert_eq(director.state, PlatformerDirector.State.ESCAPE, "standalone: boss down → escape")


func test_death_respawns_at_last_checkpoint() -> void:
	var level: Node = await _warship()
	var director := level.get_node("Segment/PlatformerDirector") as PlatformerDirector
	director.respawn_delay = 0.05
	var cp := get_tree().get_nodes_in_group(&"checkpoints")[1] as Checkpoint
	cp.activate()
	var mech := Players.find(get_tree()) as MechPlayer
	mech.health.apply_damage(DamagePayload.create(99, Teams.Team.ENEMY), self)
	assert_eq(mech.state, MechPlayer.State.DISABLED, "dead")
	await wait_physics_frames(8)
	assert_false(mech.health.is_depleted(), "respawned")
	assert_near(mech.global_position.x, cp.global_position.x, 0.6, "at the checkpoint")


func test_blast_roof_opens_for_the_escape() -> void:
	var level: Node = await _warship()
	var layout := level.get_node("Segment/Layout") as WarshipLayout
	assert_true(is_instance_valid(layout.blast_roof), "arena roof intact")
	layout.blast_open()
	await wait_process_frames(2)
	assert_false(is_instance_valid(layout.blast_roof), "roof blown open")


func test_reactor_core_only_takes_damage_between_attacks() -> void:
	LevelScaffold.build(self)
	var boss := (load("res://enemies/bosses/reactor_core.tscn") as PackedScene).instantiate() as ReactorCore
	add_autofree(boss)
	boss.set_physics_process(false)
	boss.debug_advance_phase()  # INTRO → PHASE_1
	boss.current_attack = &"low_sweep"
	boss._animate(DT)
	assert_false(boss.hurtbox.receive_hit(DamagePayload.create(5, Teams.Team.PLAYER), self), "shielded while attacking")
	boss.current_attack = &""
	boss._animate(DT)
	assert_true(boss.hurtbox.receive_hit(DamagePayload.create(5, Teams.Team.PLAYER), self), "open between attacks")
