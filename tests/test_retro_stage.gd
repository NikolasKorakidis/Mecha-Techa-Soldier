extends TestCase
## Stage 4 (8-bit): pixel screen, player limits and weapons, kills and capsules, damage and
## respawn, terrain collision, the boss core rule, the clear, and campaign resume at STAGE 4.

const DT := 1.0 / 60.0

var stage: RetroStage


func _stage() -> RetroStage:
	RunSession.reset_run()
	stage = RetroStage.new()
	stage.read_devices = false
	add_autofree(stage)
	await wait_process_frames(1)
	stage.begin()
	await wait_process_frames(1)
	return stage


func _run(seconds: float, move := Vector2.ZERO, fire := false) -> void:
	stage.set_input(move, fire)
	for i in int(seconds / DT):
		stage.tick(DT)


func test_renders_into_an_nes_sized_screen() -> void:
	await _stage()
	assert_eq(stage._viewport.size, Vector2i(256, 224), "256x224 pixel frame")
	assert_eq(stage._viewport.canvas_item_default_texture_filter, Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST, "nearest filtering")
	assert_true(get_viewport().disable_3d, "the 3D world is switched off underneath")
	assert_eq(RunSession.checkpoint_id, &"STAGE 4", "stage checkpoint saved")
	stage.queue_free()
	await wait_process_frames(2)
	assert_false(get_viewport().disable_3d, "3D restored when the stage leaves")


func test_player_stays_in_the_playfield_and_fires_by_weapon_level() -> void:
	await _stage()
	stage.set_physics_process(false)
	_run(3.0, Vector2(-1, -1))
	assert_true(stage.player.position.x >= 10.0 and stage.player.position.y >= RetroArt.HUD_H + 7.0, "clamped to the playfield")
	var counts := []
	for level in [1, 2, 3, 4]:
		stage.player.weapon = level
		stage.player._cooldown = 0.0
		counts.append(stage.player.tick(DT, Vector2.ZERO, true).size())
	assert_eq(counts, [1, 2, 4, 5], "shots per volley by weapon level")


func test_carrier_wave_drops_a_capsule_that_powers_up() -> void:
	await _stage()
	stage.set_physics_process(false)
	stage._spawn_event(&"drones", {"count": 2, "y": 120.0, "carrier": true})
	for e in stage.enemies.duplicate():
		stage._kill_enemy(e)
	assert_eq(stage._pickups.size(), 1, "last carrier drops a capsule")
	stage._pickups[0].position = stage.player.position
	stage._collide()
	assert_eq(stage.player.weapon, 2, "capsule raises the weapon level")


func test_enemy_fire_hurts_and_death_respawns_with_full_health() -> void:
	await _stage()
	stage.set_physics_process(false)
	var before := RunSession.health
	stage._spawn_shot(stage._enemy_shots, &"shot_enemy", stage.player.position, Vector2.ZERO)
	stage._collide()
	assert_eq(RunSession.health, before - 1, "a bullet costs one heart")
	assert_true(stage.player.invulnerable_left > 0.0, "brief invulnerability")
	RunSession.set_health(1)
	stage.player.invulnerable_left = 0.0
	stage._hurt_player()
	assert_false(stage.player.alive, "last heart lost: ship destroyed")
	_run(2.0)
	assert_true(stage.player.alive, "respawned")
	assert_eq(RunSession.health, RunSession.max_health, "with full health")


func test_fortress_terrain_is_solid() -> void:
	await _stage()
	stage.set_physics_process(false)
	stage._start_terrain()
	stage._terrain.position.x = 0.0
	var rects := stage._terrain_rects_near(0.0, 256.0)
	assert_true(rects.size() > 4, "terrain columns on screen")
	var floor_rect: Rect2 = rects.filter(func(r: Rect2) -> bool: return r.position.y > 100.0)[0]
	stage.player.position = floor_rect.get_center()
	var before := RunSession.health
	stage._collide()
	assert_eq(RunSession.health, before - 1, "touching the fortress hurts")


func test_boss_core_only_takes_damage_when_open_and_clear_emits() -> void:
	await _stage()
	stage.set_physics_process(false)
	stage._spawn_event(&"boss", {})
	var boss := stage.boss
	boss.position = Vector2(RetroBoss.HOME_X, 120)
	boss.state = RetroBoss.State.CLOSED
	assert_false(boss.damage(1), "closed shutters shrug off hits")
	assert_eq(boss.hp, RetroBoss.MAX_HP, "no damage while closed")
	boss.state = RetroBoss.State.OPEN
	boss.damage(5)
	assert_eq(boss.hp, RetroBoss.MAX_HP - 5, "open core takes damage")
	var cleared := [false]
	stage.cleared.connect(func() -> void: cleared[0] = true)
	boss.hp = 1
	if boss.damage(1):
		stage._on_boss_destroyed()
	_run(8.0)
	assert_true(cleared[0], "boss down → STAGE CLEAR → cleared")


func test_campaign_resumes_in_the_8bit_stage() -> void:
	RunSession.reset_run()
	RunSession.save_checkpoint(&"STAGE 4")
	var campaign := (load("res://levels/campaign/campaign.tscn") as PackedScene).instantiate()
	add_autofree(campaign)
	var cd := campaign.get_node("CampaignDirector") as CampaignDirector
	await wait_process_frames(4)
	var t := 0.0
	while cd.phase != CampaignDirector.Phase.RETRO and t < 3.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	assert_eq(cd.phase, CampaignDirector.Phase.RETRO, "STAGE 4 checkpoint resumes in the 8-bit stage")
	var retro := campaign.get_node("RetroStage") as RetroStage
	assert_true(retro.active, "8-bit stage running")
	assert_true(Players.find(get_tree()) == null, "no 3D avatar left")
	campaign.queue_free()
	await wait_process_frames(2)
	RunSession.reset_run()
