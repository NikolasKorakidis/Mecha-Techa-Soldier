extends TestCase
## Stage director and boss state machine.

const DT := 1.0 / 60.0


func _make_director(waves: Array[WaveData], boss_scene: PackedScene = null) -> LevelDirector:
	LevelScaffold.build(self)
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	add_autofree(enemies)
	var ui := StageUI.new()
	add_autofree(ui)
	var stage := StageData.new()
	stage.waves = waves
	stage.boss_scene = boss_scene
	stage.boss_warning_time = 0.5
	var director := LevelDirector.new()
	director.stage = stage
	director.enemy_root = enemies
	director.stage_ui = ui
	director.intro_time = 0.5
	director.clear_time = 0.3
	add_autofree(director)
	director.set_physics_process(false)
	return director


func _wave(t: float, count: int, interval: float, bonus: int = 0) -> WaveData:
	var w := WaveData.new()
	w.start_time = t
	w.enemy_scene = load("res://enemies/space/space_drone.tscn")
	w.count = count
	w.interval = interval
	w.completion_bonus = bonus
	return w


func _run(director: LevelDirector, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		director.tick(DT)


func test_waves_spawn_on_stage_time_not_frames() -> void:
	var director := _make_director([_wave(1.0, 3, 0.5)])
	_run(director, 0.55)  # intro
	assert_eq(director.state, LevelDirector.State.WAVES, "intro done")
	_run(director, 0.85)
	assert_eq(director.enemy_root.get_child_count(), 0, "nothing before start_time")
	_run(director, 0.2)
	assert_eq(director.enemy_root.get_child_count(), 1, "first unit at start_time")
	_run(director, 1.0)
	assert_eq(director.enemy_root.get_child_count(), 3, "remaining units at the interval")


func test_formation_bonus_only_when_all_destroyed() -> void:
	var director := _make_director([_wave(0.0, 2, 0.0, 500), _wave(0.0, 2, 0.0, 700)])
	_run(director, 0.6)
	var units := director.enemy_root.get_children()
	assert_eq(units.size(), 4, "both waves spawned")
	var kill_score := (units[0] as SpaceEnemy).score_value
	for unit in units.slice(0, 2):
		(unit as SpaceEnemy).health.apply_damage(DamagePayload.create(99, Teams.Team.PLAYER), self)
	await wait_process_frames(2)
	assert_eq(RunSession.score, kill_score * 2 + 500, "first wave: kills + formation bonus")
	(units[2] as SpaceEnemy).health.apply_damage(DamagePayload.create(99, Teams.Team.PLAYER), self)
	units[3].queue_free()  # escapes
	await wait_process_frames(2)
	assert_eq(RunSession.score, kill_score * 3 + 500, "second wave: an escapee voids its bonus")


func test_boss_warning_after_waves_then_boss_then_clear() -> void:
	var director := _make_director([_wave(0.0, 1, 0.0)], load("res://enemies/bosses/choir_engine.tscn"))
	_run(director, 0.6)
	director.enemy_root.get_child(0).queue_free()
	await wait_process_frames(1)
	_run(director, DT * 2)
	assert_eq(director.state, LevelDirector.State.BOSS_WARNING, "warning when waves are done")
	assert_true(director.stage_ui.is_warning_visible(), "WARNING shown")
	_run(director, 0.6)
	assert_eq(director.state, LevelDirector.State.BOSS, "boss spawned")
	assert_true(is_instance_valid(director.boss), "boss exists")


func test_skip_to_boss_clears_waves() -> void:
	var director := _make_director([_wave(0.0, 3, 0.0), _wave(30.0, 3, 0.0)])
	_run(director, 0.6)
	director.skip_to_boss()
	assert_eq(director.state, LevelDirector.State.BOSS_WARNING, "jumped to warning")
	await wait_process_frames(1)
	assert_eq(director.enemy_root.get_child_count(), 0, "enemies cleared")


func _spawn_boss(path: String) -> BossBase:
	LevelScaffold.build(self)
	LevelScaffold.ship(self)
	var boss := (load(path) as PackedScene).instantiate() as BossBase
	add_autofree(boss)
	boss.set_physics_process(false)
	return boss


func _tick_boss(boss: BossBase, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		boss.tick(DT)


func test_boss_states_follow_the_legal_order() -> void:
	var boss := _spawn_boss("res://enemies/bosses/choir_engine.tscn")
	var seen: Array[int] = []
	boss.state_changed.connect(func(s: BossBase.State, _r: String) -> void: seen.append(s))
	assert_false(boss.is_attackable(), "invulnerable during intro")
	_tick_boss(boss, boss.intro_time + DT)
	# A single massive hit cannot skip past phase 1.
	boss.health.apply_damage(DamagePayload.create(9999, Teams.Team.PLAYER), self)
	assert_true(boss.health.current > 0, "phase floor holds")
	_tick_boss(boss, DT)
	assert_eq(boss.state, BossBase.State.BREAK_1, "phase 1 ends at its threshold")
	assert_false(boss.is_attackable(), "invulnerable during break")
	_tick_boss(boss, boss.break_time + DT)
	boss.health.apply_damage(DamagePayload.create(9999, Teams.Team.PLAYER), self)
	_tick_boss(boss, DT)
	_tick_boss(boss, boss.break_time + DT)
	assert_eq(boss.state, BossBase.State.PHASE_3, "reached phase 3")
	var defeated := SignalSpy.new(boss.defeated)
	boss.health.apply_damage(DamagePayload.create(9999, Teams.Team.PLAYER), self)
	_tick_boss(boss, 2.5)
	assert_eq(seen, [BossBase.State.PHASE_1, BossBase.State.BREAK_1, BossBase.State.PHASE_2,
			BossBase.State.BREAK_2, BossBase.State.PHASE_3, BossBase.State.DEFEATED], "exact state order")
	assert_eq(defeated.count(), 1, "defeated emitted once")


func test_break_clears_hostile_bullets_and_protects_player() -> void:
	var boss := _spawn_boss("res://enemies/bosses/choir_engine.tscn")
	_tick_boss(boss, boss.intro_time + DT)
	for i in 5:
		boss.weapon.fire_at(Vector3.LEFT)
	assert_eq(LevelScaffold.hostile_projectiles(get_tree()), 5, "bullets in flight")
	boss.debug_advance_phase()
	assert_eq(boss.state, BossBase.State.BREAK_1, "in break")
	assert_eq(LevelScaffold.hostile_projectiles(get_tree()), 0, "break cleared bullets")
	var player := get_tree().get_first_node_in_group(ShipPlayer.GROUP) as ShipPlayer
	assert_true(player.is_invulnerable(), "player protected during the transition")


func test_attack_scheduler_never_repeats_back_to_back() -> void:
	var boss := _spawn_boss("res://enemies/bosses/choir_engine.tscn")
	_tick_boss(boss, boss.intro_time + DT)
	boss.health.invulnerable = true
	var attacks: Array[StringName] = []
	for i in 1200:
		var before := boss.current_attack
		boss.tick(DT)
		if boss.current_attack != &"" and boss.current_attack != before:
			attacks.append(boss.current_attack)
	assert_true(attacks.size() >= 4, "several attacks observed")
	for i in range(1, attacks.size()):
		assert_true(attacks[i] != attacks[i - 1], "no back-to-back repeat at %d" % i)


func test_dreadnought_core_armored_until_turrets_die() -> void:
	var boss := _spawn_boss("res://enemies/bosses/forge_dreadnought.tscn") as ForgeDreadnought
	_tick_boss(boss, boss.intro_time + DT)
	assert_false(boss.hurtbox.receive_hit(DamagePayload.create(5, Teams.Team.PLAYER), self), "core armored in phase 1")
	for turret in boss.turrets:
		turret.health.apply_damage(DamagePayload.create(999, Teams.Team.PLAYER), self)
	_tick_boss(boss, DT)
	assert_eq(boss.state, BossBase.State.BREAK_1, "turrets down ends phase 1")
	_tick_boss(boss, boss.break_time + DT)
	assert_true(boss.hurtbox.receive_hit(DamagePayload.create(5, Teams.Team.PLAYER), self), "core open in phase 2")


func test_real_stages_load_and_chain() -> void:
	var s1 := load("res://levels/orbital_riptide/stage_1.tres") as StageData
	var s2 := load("res://levels/foundry_descent/stage_2.tres") as StageData
	assert_true(s1.waves.size() > 10 and s2.waves.size() > 10, "stages have authored waves")
	assert_eq(s1.next_level, "res://levels/foundry_descent/foundry_descent.tscn", "stage 1 leads to stage 2")
	assert_true(s2.next_level.is_empty(), "stage 2 is final")
	assert_eq(s2.restart_level, "res://levels/orbital_riptide/orbital_riptide.tscn", "final stage restarts the run")
	for stage in [s1, s2]:
		var last := -1.0
		for wave in stage.waves:
			assert_true(wave.start_time >= last, "waves sorted by time in %s" % stage.stage_name)
			assert_true(wave.enemy_scene != null, "every wave has an enemy")
			last = wave.start_time
