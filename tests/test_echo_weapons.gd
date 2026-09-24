extends TestCase
## Weapon drops: elites drop cores, pickups install echo weapons with a shot budget.

const DT := 1.0 / 60.0


func test_equip_consume_and_revert_to_base() -> void:
	RunSession.equip_echo(EchoModules.BURST, 2)
	assert_eq(RunSession.selected_echo, EchoModules.BURST, "burst equipped")
	assert_true(RunSession.consume_echo_ammo(), "first shot spends ammo")
	assert_true(RunSession.consume_echo_ammo(), "second shot spends ammo")
	assert_eq(RunSession.echo_ammo, 0, "ammo empty")
	assert_eq(RunSession.selected_echo, RunSession.NO_ECHO, "reverts to base gun at zero")
	assert_false(RunSession.consume_echo_ammo(), "nothing to spend without an echo")


func test_new_pickup_replaces_current_echo() -> void:
	LevelScaffold.build(self)
	var player := LevelScaffold.ship(self)
	player.collect_echo(EchoModules.ARC)
	player.collect_echo(EchoModules.GUARD)
	assert_eq(RunSession.selected_echo, EchoModules.GUARD, "latest pickup wins")
	assert_eq(RunSession.echo_ammo, EchoModules.get_data(EchoModules.GUARD).ammo, "full ammo from pickup")


func test_dying_drops_the_echo_weapon() -> void:
	LevelScaffold.build(self)
	var player := LevelScaffold.ship(self)
	player.collect_echo(EchoModules.BURST)
	player.hurtbox.receive_hit(DamagePayload.create(99, Teams.Team.ENEMY), self)
	assert_eq(RunSession.selected_echo, RunSession.NO_ECHO, "echo lost on death")


func test_burst_fires_five_way_spread_per_shot() -> void:
	LevelScaffold.build(self)
	var player := LevelScaffold.ship(self)
	player.collect_echo(EchoModules.BURST)
	var spent_before := RunSession.echo_ammo
	player.tick(DT, ShipInput.make(Vector2.ZERO, true))
	var shots := get_tree().get_first_node_in_group(Projectile.ROOT_GROUP).get_child_count()
	assert_eq(shots, 5, "one volley = five projectiles")
	assert_eq(RunSession.echo_ammo, spent_before - 1, "one volley costs one shot")


func test_arc_chains_damage_and_spares_ammo_without_targets() -> void:
	LevelScaffold.build(self)
	var player := LevelScaffold.ship(self, Vector3(-8, 0, 0))
	player.collect_echo(EchoModules.ARC)
	var ammo := RunSession.echo_ammo
	player.tick(DT, ShipInput.make(Vector2.ZERO, true))
	assert_eq(RunSession.echo_ammo, ammo, "no target: base gun fires, no ammo spent")

	var a := LevelScaffold.enemy(self, "gunpod", Vector3(0, 0, 0))
	var b := LevelScaffold.enemy(self, "gunpod", Vector3(3, 3, 0))
	var far := LevelScaffold.enemy(self, "gunpod", Vector3(14, -7, 0))
	await wait_process_frames(1)
	player.tick(0.3, ShipInput.make(Vector2.ZERO))  # let the weapon cooldown expire
	player.tick(DT, ShipInput.make(Vector2.ZERO, true))
	assert_eq(RunSession.echo_ammo, ammo - 1, "arc strike spends one shot")
	assert_true(a.health.current < a.health.max_health, "first target hit")
	assert_true(b.health.current < b.health.max_health, "chained to the nearby enemy")
	assert_eq(far.health.current, far.health.max_health, "chain range limits the jump")


func test_guard_orbs_cancel_hostile_projectiles() -> void:
	LevelScaffold.build(self)
	var player := LevelScaffold.ship(self, Vector3(-8, 0, 0))
	player.collect_echo(EchoModules.GUARD)
	player.tick(DT, ShipInput.make(Vector2.ZERO))
	await wait_physics_frames(2)
	var orb_pos: Vector3 = player.arsenal.guard_orbs.orb_positions()[0]
	var shot := (load("res://combat/projectiles/enemy_shot.tscn") as PackedScene).instantiate() as Projectile
	get_tree().get_first_node_in_group(Projectile.ROOT_GROUP).add_child(shot)
	shot.global_position = orb_pos
	shot.setup(Teams.Team.ENEMY, 1, Vector3.ZERO)
	await wait_physics_frames(4)
	assert_false(is_instance_valid(shot), "orb destroyed the hostile shot")


func test_elite_drops_its_weapon_and_pickup_equips_it() -> void:
	LevelScaffold.build(self)
	var player := LevelScaffold.ship(self, Vector3(-8, 0, 0))
	var elite := LevelScaffold.enemy(self, "tesla", Vector3(-2, 0, 0))
	assert_true(elite.is_elite(), "tesla is an elite carrier")
	elite.health.apply_damage(DamagePayload.create(999, Teams.Team.PLAYER), self)
	await wait_process_frames(2)
	var pickups := get_tree().get_first_node_in_group(EchoPickup.ROOT_GROUP).get_children()
	assert_eq(pickups.size(), 1, "one weapon core dropped")
	if pickups.is_empty():
		return
	assert_eq((pickups[0] as EchoPickup).echo_id, EchoModules.ARC, "drops its own weapon")
	# The magnet pulls the core into the ship.
	await get_tree().create_timer(1.2).timeout
	assert_eq(RunSession.selected_echo, EchoModules.ARC, "collected and equipped")
	assert_true(player.visible, "player unaffected")


func test_regular_enemies_drop_nothing() -> void:
	LevelScaffold.build(self)
	var drone := LevelScaffold.enemy(self, "space_drone", Vector3(0, 0, 0))
	drone.health.apply_damage(DamagePayload.create(99, Teams.Team.PLAYER), self)
	await wait_process_frames(2)
	assert_eq(get_tree().get_first_node_in_group(EchoPickup.ROOT_GROUP).get_child_count(), 0, "no drop")
