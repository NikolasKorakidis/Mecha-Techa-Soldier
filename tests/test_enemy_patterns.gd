extends TestCase
## Movement and fire patterns of the enemy roster.

const DT := 1.0 / 60.0


func _run(enemy: SpaceEnemy, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		enemy.tick(DT)


func test_aimed_burst_fires_toward_the_player() -> void:
	LevelScaffold.build(self)
	LevelScaffold.ship(self, Vector3(-8, -5, 0))
	var pod := LevelScaffold.enemy(self, "gunpod", Vector3(8, 3, 0))
	pod.movement = SpaceEnemy.Movement.STRAIGHT
	pod.speed = 0.0
	var shots: Array[Projectile] = []
	pod.weapon.fired.connect(func(p: Projectile) -> void: shots.append(p))
	_run(pod, pod.first_shot_delay + pod.telegraph_time + pod.burst_spacing * pod.burst_count + 0.1)
	assert_eq(shots.size(), pod.burst_count, "full burst fired")
	if shots.is_empty():
		return
	var v := shots[0].velocity.normalized()
	var expected := (Vector3(-8, -5, 0) - pod.muzzle_position()).normalized()
	assert_true(v.dot(expected) > 0.98, "burst aimed at the player")


func test_spread_fan_fires_configured_count() -> void:
	LevelScaffold.build(self)
	LevelScaffold.ship(self)
	var ship := LevelScaffold.enemy(self, "gunship", Vector3(8, 0, 0))
	ship.movement = SpaceEnemy.Movement.STRAIGHT
	ship.speed = 0.0
	var count := [0]
	ship.weapon.fired.connect(func(_p: Projectile) -> void: count[0] += 1)
	_run(ship, ship.first_shot_delay + ship.telegraph_time + 0.05)
	assert_eq(count[0], ship.spread_count, "one fan volley")


func test_hold_enemy_parks_then_leaves() -> void:
	LevelScaffold.build(self)
	var pod := LevelScaffold.enemy(self, "gunpod", Vector3(19, 0, 0))
	pod.fire_pattern = SpaceEnemy.FirePattern.NONE
	_run(pod, 5.0)
	assert_eq(pod.phase, SpaceEnemy.MovePhase.HOLDING, "parked")
	assert_near(pod.position.x, pod.hold_x, 0.1, "at its parking spot")
	_run(pod, pod.hold_time + 0.5)
	assert_eq(pod.phase, SpaceEnemy.MovePhase.EXIT, "leaves after hold time")
	assert_true(pod.position.x < pod.hold_x, "moving off to the left")


func test_rammer_telegraphs_then_charges_at_locked_position() -> void:
	LevelScaffold.build(self)
	LevelScaffold.ship(self, Vector3(-8, -4, 0))
	var rammer := LevelScaffold.enemy(self, "rammer", Vector3(10, 4, 0))
	_run(rammer, rammer.charge_delay + DT)
	assert_eq(rammer.phase, SpaceEnemy.MovePhase.CHARGE_WINDUP, "winding up")
	assert_true(rammer.telegraph.visible, "telegraph shown before the charge")
	_run(rammer, rammer.charge_windup + DT)
	assert_eq(rammer.phase, SpaceEnemy.MovePhase.CHARGING, "charging")
	var start := rammer.global_position
	_run(rammer, 0.2)
	var dir := (rammer.global_position - start).normalized()
	var expected := (Vector3(-8, -4, 0) - start).normalized()
	assert_true(dir.dot(expected) > 0.95, "charges along the locked direction")


func test_every_enemy_scene_loads_with_wiring() -> void:
	LevelScaffold.build(self)
	for scene_name in ["space_drone", "needle", "lancer", "gunpod", "rammer", "gunship", "tesla", "warden"]:
		var e := LevelScaffold.enemy(self, scene_name, Vector3(0, 0, 0))
		assert_true(e.health != null and e.hurtbox != null and e.weapon != null, "%s wired" % scene_name)
		assert_true(e.health.max_health > 0, "%s has health" % scene_name)
		assert_eq(e.is_elite(), scene_name in ["gunship", "tesla", "warden"], "%s elite flag" % scene_name)
