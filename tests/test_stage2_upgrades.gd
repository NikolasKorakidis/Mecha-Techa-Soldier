extends TestCase
## Stage 2 Mega Man / Metroid layer: Heart + Energy Tanks, the charge shot, shield guards,
## swoopers, the secret wall-kick shaft and the sealed Sentinel mid-boss room.

const DT := 1.0 / 60.0


func _mech_on_floor() -> MechPlayer:
	LevelScaffold.build(self)
	var world := Node3D.new()
	add_autofree(world)
	LevelKit.solid(world, -40.0, 0.0, 80.0, 4.0)
	var mech := (load("res://player/mech/mech_player.tscn") as PackedScene).instantiate() as MechPlayer
	mech.read_devices = false
	add_autofree(mech)
	mech.global_position = Vector3(0, 0.05, 0)
	await wait_physics_frames(2)
	for i in 20:
		mech.tick(DT, MechInput.new())
	return mech


func _warship() -> Node:
	var level := (load("res://levels/warship/warship_level.tscn") as PackedScene).instantiate()
	add_autofree(level)
	await wait_physics_frames(2)
	return level


func test_heart_tank_raises_max_health_and_energy_tank_fills_super() -> void:
	RunSession.reset_run()
	var mech: MechPlayer = await _mech_on_floor()
	mech.health.apply_damage(DamagePayload.create(2, Teams.Team.ENEMY), self)
	var heart := ItemPickup.new()
	heart.kind = ItemPickup.Kind.HEART
	heart.position = mech.global_position + Vector3(0, 1, 0)
	add_autofree(heart)
	await wait_physics_frames(4)
	assert_eq(RunSession.max_health, RunSession.DEFAULT_MAX_HEALTH + 1, "heart tank adds a health segment")
	assert_eq(mech.health.max_health, RunSession.max_health, "player health component follows")
	assert_eq(mech.health.current, RunSession.max_health, "and refills")
	var tank := ItemPickup.new()
	tank.kind = ItemPickup.Kind.TANK
	tank.position = mech.global_position + Vector3(0, 1, 0)
	add_autofree(tank)
	await wait_physics_frames(4)
	assert_true(RunSession.super_ready(), "energy tank fills SUPER")
	RunSession.reset_run()
	assert_eq(RunSession.max_health, RunSession.DEFAULT_MAX_HEALTH, "a new run resets max health")


func test_holding_fire_charges_and_release_fires_a_piercing_shot() -> void:
	RunSession.reset_run()
	var mech: MechPlayer = await _mech_on_floor()
	for i in int(0.4 / DT):
		mech.tick(DT, MechInput.make(0, false, false, true))
	mech.tick(DT, MechInput.new())
	assert_eq(mech.charge_shots, 0, "a short tap is just the rapid-fire buster")
	for i in int(1.8 / DT):
		mech.tick(DT, MechInput.make(0, false, false, true))
	mech.tick(DT, MechInput.new())
	assert_eq(mech.charge_shots, 1, "release after a full charge fires a charge shot")
	var shot: ChargeShot = null
	for child in get_tree().get_first_node_in_group(Projectile.ROOT_GROUP).get_children():
		if child is ChargeShot:
			shot = child
	assert_true(shot != null, "charge shot spawned")
	# Two walkers in a row: the shot passes through both.
	var hurt_count := [0]
	for x: float in [4.0, 7.0]:
		var walker := (load("res://enemies/ground/walker.tscn") as PackedScene).instantiate() as GroundEnemy
		walker.position = Vector3(x, 0.1, 0)
		walker.set_physics_process(false)
		add_autofree(walker)
		walker.health.damaged.connect(func(_p: DamagePayload, _s: Node) -> void: hurt_count[0] += 1)
	await wait_physics_frames(30)
	assert_eq(hurt_count[0], 2, "the charge shot pierces every enemy in its path")


func test_shield_guard_blocks_from_the_front_but_not_from_behind() -> void:
	RunSession.reset_run()
	var mech: MechPlayer = await _mech_on_floor()
	var guard := (load("res://enemies/ground/shield_guard.tscn") as PackedScene).instantiate() as GroundEnemy
	guard.position = Vector3(6, 0.1, 0)
	guard.set_physics_process(false)
	add_autofree(guard)
	await wait_physics_frames(2)
	guard.facing = -1.0
	guard.fire_interval = 99.0
	guard.tick(DT)
	assert_true(guard.health.invulnerable, "shield up toward a player in front")
	mech.teleport(Vector3(10, 0.1, 0))
	guard.tick(DT)
	assert_false(guard.health.invulnerable, "back exposed right after the player gets behind")
	for i in int(1.0 / DT):
		guard.tick(DT)
	assert_eq(guard.facing, 1.0, "turns around after its delay")


func test_swooper_dives_at_the_player_and_returns_to_its_perch() -> void:
	RunSession.reset_run()
	var mech: MechPlayer = await _mech_on_floor()
	var swooper := (load("res://enemies/ground/swooper.tscn") as PackedScene).instantiate() as GroundEnemy
	swooper.position = Vector3(3, 6, 0)
	swooper.set_physics_process(false)
	add_autofree(swooper)
	await wait_physics_frames(2)
	var lowest := 6.0
	for i in int(3.0 / DT):
		swooper.tick(DT)
		lowest = minf(lowest, swooper.global_position.y)
	assert_true(lowest < 2.0, "dove down at the player")
	for i in int(2.0 / DT):
		swooper.tick(DT)
	assert_true(swooper.global_position.y > 5.0, "climbed back to the ceiling")


func test_secret_shaft_wall_kicks_up_to_the_heart_tank() -> void:
	RunSession.reset_run()
	var level: Node = await _warship()
	for enemy in level.get_node("Segment/Enemies").get_children():
		enemy.queue_free()
	var mech := Players.find(get_tree()) as MechPlayer
	mech.read_devices = false
	mech.teleport(Vector3(153.8, 9.5, 0))
	for i in 20:
		mech.tick(DT, MechInput.new())
		await get_tree().physics_frame
	var hold := 0
	var used_double := false
	for f in int(6.0 / DT):
		var p := mech.global_position
		var press := false
		var move := 0.0
		if mech.is_on_floor():
			used_double = false
			press = f % 40 == 0
		elif mech.velocity.y < 0.0 and not used_double and p.y < 12.0:
			press = true
			used_double = true
		if p.y > 11.2:
			move = -1.0 if p.x < 153.3 else 1.0
			if absf(mech.velocity.x) > 2.0:
				move = signf(mech.velocity.x)
		if mech.state == MechPlayer.State.WALL:
			press = true
		if p.y > 19.5:
			move = 1.0
		if press:
			hold = 14
		hold -= 1
		mech.tick(DT, MechInput.make(move, press, hold > 0))
		await get_tree().physics_frame
		if RunSession.max_health > RunSession.DEFAULT_MAX_HEALTH:
			break
	assert_eq(RunSession.max_health, RunSession.DEFAULT_MAX_HEALTH + 1, "wall kicks reach the hidden Heart Tank")
	RunSession.reset_run()


func test_mid_boss_room_seals_resets_on_death_and_opens_on_victory() -> void:
	RunSession.reset_run()
	var level: Node = await _warship()
	var zone := (level.get_node("Segment/Layout") as WarshipLayout).mid_boss_zone
	var director := level.get_node("Segment/PlatformerDirector") as PlatformerDirector
	director.respawn_delay = 0.05
	var mech := Players.find(get_tree()) as MechPlayer
	assert_false(zone._gates[0].visible, "room open before the fight")
	mech.teleport(Vector3(zone.trigger_x + 1.0, 0.5, 0))
	await wait_physics_frames(3)
	assert_eq(zone.state, MidBossZone.State.WARNING, "walking in seals the room")
	assert_true(zone._gates[0].visible and zone._gates[1].visible, "both doors shut")
	assert_true(director.camera.is_locked(), "camera locked on the room")
	await wait_physics_frames(int(MidBossZone.WARNING_TIME / DT) + 4)
	assert_true(zone.boss is SentinelBoss, "sentinel dropped in")
	mech.health.apply_damage(DamagePayload.create(99, Teams.Team.ENEMY), self)
	await wait_physics_frames(3)
	assert_eq(zone.state, MidBossZone.State.ARMED, "death resets the room")
	assert_false(zone._gates[0].visible, "doors reopen")
	await wait_physics_frames(10)
	mech.teleport(Vector3(zone.trigger_x + 1.0, 0.5, 0))
	await wait_physics_frames(int(MidBossZone.WARNING_TIME / DT) + 8)
	assert_true(zone.boss is SentinelBoss, "fight restarts")
	var boss := zone.boss
	boss.defeated.emit()
	assert_eq(zone.state, MidBossZone.State.CLEARED, "victory clears the room")
	assert_false(zone._gates[1].visible, "way on is open")
	assert_false(director.camera.is_locked(), "camera follows again")
	boss.queue_free()
	RunSession.reset_run()
