extends TestCase
## Stage 1 → ship→mech cutscene → warship (Reactor Core) → mech→bike cutscene → highway → title.

const DT := 1.0 / 60.0


func test_campaign_chain_is_wired() -> void:
	var s1 := load("res://levels/orbital_riptide/stage_1.tres") as StageData
	assert_eq(s1.next_level, "res://levels/transform/transform_to_mech.tscn", "stage 1 → mech cutscene")
	var to_mech := (load("res://levels/transform/transform_to_mech.tscn") as PackedScene).instantiate() as TransformCutscene
	assert_eq(to_mech.next_level, "res://levels/warship/warship_level.tscn", "mech cutscene → warship")
	to_mech.free()
	var warship := (load("res://levels/warship/warship_level.tscn") as PackedScene).instantiate()
	var director := warship.get_node("PlatformerDirector") as PlatformerDirector
	assert_eq(director.next_level, "res://levels/transform/transform_to_bike.tscn", "warship → bike cutscene")
	warship.free()
	var to_bike := (load("res://levels/transform/transform_to_bike.tscn") as PackedScene).instantiate() as TransformCutscene
	assert_eq(to_bike.next_level, "res://levels/highway/highway_level.tscn", "bike cutscene → highway")
	to_bike.free()
	var highway := (load("res://levels/highway/highway_level.tscn") as PackedScene).instantiate()
	assert_eq((highway.get_node("RunnerDirector") as RunnerDirector).restart_level, "res://ui/title/title_screen.tscn", "highway → title")
	highway.free()


func test_cutscene_runs_to_the_end_and_can_be_skipped() -> void:
	var cut := (load("res://levels/transform/transform_to_mech.tscn") as PackedScene).instantiate() as TransformCutscene
	cut.next_level = ""
	add_autofree(cut)
	cut.set_process(false)
	var spy := SignalSpy.new(cut.finished)
	for i in int(TransformCutscene.T_END / DT) + 2:
		cut.tick(DT)
	assert_eq(spy.count(), 1, "finished once at the end")
	cut.tick(DT)
	assert_eq(spy.count(), 1, "never twice")
	var cut2 := (load("res://levels/transform/transform_to_bike.tscn") as PackedScene).instantiate() as TransformCutscene
	cut2.next_level = ""
	add_autofree(cut2)
	cut2.set_process(false)
	cut2.tick(0.5)
	var ev := InputEventAction.new()
	ev.action = &"jump"
	ev.pressed = true
	cut2._unhandled_input(ev)
	assert_true(cut2.done, "jump skips the cutscene")


func _warship() -> Node:
	var level := (load("res://levels/warship/warship_level.tscn") as PackedScene).instantiate()
	add_autofree(level)
	await wait_physics_frames(2)
	return level


func test_warship_boots_with_mech_checkpoints_and_enemies() -> void:
	var level: Node = await _warship()
	var director := level.get_node("PlatformerDirector") as PlatformerDirector
	assert_true(Players.find(get_tree()) is MechPlayer, "the player is the mech")
	assert_true(get_tree().get_nodes_in_group(&"checkpoints").size() >= 3, "checkpoints placed")
	assert_true(level.get_node("Enemies").get_child_count() >= 10, "enemies placed")
	assert_false(level.get_node("BossGate").visible, "arena gate open before the fight")
	assert_eq(director.camera.follow_target, level.get_node("MechPlayer"), "camera follows the mech")


func test_warship_boss_gate_lock_and_escape() -> void:
	var level: Node = await _warship()
	var director := level.get_node("PlatformerDirector") as PlatformerDirector
	director.warning_time = 0.1
	director.intro_time = 0.0
	await wait_physics_frames(2)
	var mech := level.get_node("MechPlayer") as MechPlayer
	mech.teleport(Vector3(director.boss_trigger_x + 1.0, 0.5, 0))
	await wait_physics_frames(3)
	assert_eq(director.state, PlatformerDirector.State.BOSS_WARNING, "crossing the trigger starts the boss")
	assert_true(director.camera.is_locked(), "camera locked to the arena")
	assert_true(level.get_node("BossGate").visible, "gate sealed")
	await wait_physics_frames(12)
	assert_true(director.boss is ReactorCore, "reactor core spawned")
	director.boss.defeated.emit()
	assert_eq(director.state, PlatformerDirector.State.ESCAPE, "boss down → escape")


func test_death_respawns_at_last_checkpoint() -> void:
	var level: Node = await _warship()
	var director := level.get_node("PlatformerDirector") as PlatformerDirector
	director.respawn_delay = 0.05
	var cp := get_tree().get_nodes_in_group(&"checkpoints")[0] as Checkpoint
	cp.activate()
	var mech := level.get_node("MechPlayer") as MechPlayer
	mech.health.apply_damage(DamagePayload.create(99, Teams.Team.ENEMY), self)
	assert_eq(mech.state, MechPlayer.State.DISABLED, "dead")
	await wait_physics_frames(8)
	assert_false(mech.health.is_depleted(), "respawned")
	assert_near(mech.global_position.x, cp.global_position.x, 0.6, "at the checkpoint")


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


func test_highway_finish_line_completes_the_mission() -> void:
	var level := (load("res://levels/highway/highway_level.tscn") as PackedScene).instantiate()
	add_autofree(level)
	await wait_physics_frames(2)
	var director := level.get_node("RunnerDirector") as RunnerDirector
	director.restart_level = ""
	director.intro_time = 0.0
	assert_true(Players.find(get_tree()) is BikePlayer, "the player is the bike")
	await wait_physics_frames(2)
	assert_eq(director.state, RunnerDirector.State.RIDE, "riding")
	(level.get_node("BikePlayer") as BikePlayer).teleport(Vector3(director.finish_x + 1.0, 0.5, 0))
	await wait_physics_frames(2)
	assert_eq(director.state, RunnerDirector.State.FINISH, "finish line → mission complete")
