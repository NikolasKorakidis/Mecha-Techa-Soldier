extends TestCase
## Shared combat contract: team filtering, single depletion, dead actors, cleanup, physics hits.


func _make_actor(team: Teams.Team, hp: int) -> HurtboxComponent:
	var actor := Node3D.new()
	var health := HealthComponent.new()
	health.name = "Health"
	health.max_health = hp
	actor.add_child(health)
	var hurtbox := HurtboxComponent.new()
	hurtbox.team = team
	hurtbox.health = health
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 1, 1)
	shape.shape = box
	hurtbox.add_child(shape)
	actor.add_child(hurtbox)
	add_autofree(actor)
	return hurtbox


func _make_level_scaffold() -> void:
	var camera := GameplayCamera.new()
	camera.size = 18.0
	camera.position = Vector3(0, 0, 30)
	add_autofree(camera)
	var projectiles := Node3D.new()
	projectiles.add_to_group(Projectile.ROOT_GROUP)
	add_autofree(projectiles)
	var effects := Node3D.new()
	effects.add_to_group(Vfx.ROOT_GROUP)
	add_autofree(effects)


func test_friendly_fire_is_rejected() -> void:
	var hurtbox := _make_actor(Teams.Team.PLAYER, 3)
	var spy := SignalSpy.new(hurtbox.health.damaged)
	assert_false(hurtbox.receive_hit(DamagePayload.create(1, Teams.Team.PLAYER), self), "player shot rejected by player")
	assert_eq(hurtbox.health.current, 3, "health unchanged")
	assert_eq(spy.count(), 0, "no damaged signal")


func test_opposing_team_and_neutral_hazards_damage() -> void:
	var hurtbox := _make_actor(Teams.Team.ENEMY, 3)
	assert_true(hurtbox.receive_hit(DamagePayload.create(1, Teams.Team.PLAYER), self), "player shot hits enemy")
	assert_true(hurtbox.receive_hit(DamagePayload.create(1, Teams.Team.NEUTRAL), self), "neutral hazard hits enemy")
	assert_eq(hurtbox.health.current, 1, "two damage applied")


func test_depleted_emits_once_and_dead_actor_ignores_damage() -> void:
	var hurtbox := _make_actor(Teams.Team.ENEMY, 2)
	var depleted := SignalSpy.new(hurtbox.health.depleted)
	var damaged := SignalSpy.new(hurtbox.health.damaged)
	var hit := DamagePayload.create(5, Teams.Team.PLAYER)
	assert_true(hurtbox.receive_hit(hit, self), "lethal hit lands")
	assert_false(hurtbox.receive_hit(hit, self), "second hit on dead actor rejected")
	assert_false(hurtbox.receive_hit(hit, self), "third hit on dead actor rejected")
	assert_eq(depleted.count(), 1, "depleted emitted exactly once")
	assert_eq(damaged.count(), 1, "damaged emitted once")
	assert_eq(hurtbox.health.current, 0, "health floored at 0")


func test_invulnerable_and_zero_damage_are_ignored() -> void:
	var hurtbox := _make_actor(Teams.Team.PLAYER, 3)
	hurtbox.health.invulnerable = true
	assert_false(hurtbox.receive_hit(DamagePayload.create(1, Teams.Team.ENEMY), self), "invulnerable rejects")
	hurtbox.health.invulnerable = false
	assert_false(hurtbox.receive_hit(DamagePayload.create(0, Teams.Team.ENEMY), self), "zero damage rejects")
	assert_eq(hurtbox.health.current, 3, "health unchanged")


func test_revive_allows_damage_again() -> void:
	var hurtbox := _make_actor(Teams.Team.ENEMY, 1)
	hurtbox.receive_hit(DamagePayload.create(1, Teams.Team.PLAYER), self)
	hurtbox.health.revive()
	assert_eq(hurtbox.health.current, 1, "revived to max")
	assert_true(hurtbox.receive_hit(DamagePayload.create(1, Teams.Team.PLAYER), self), "can be hit after revive")


func test_heal_is_capped_and_ignored_when_dead() -> void:
	var hurtbox := _make_actor(Teams.Team.PLAYER, 4)
	hurtbox.receive_hit(DamagePayload.create(2, Teams.Team.ENEMY), self)
	hurtbox.health.heal(10)
	assert_eq(hurtbox.health.current, 4, "heal capped at max")
	hurtbox.receive_hit(DamagePayload.create(4, Teams.Team.ENEMY), self)
	hurtbox.health.heal(2)
	assert_eq(hurtbox.health.current, 0, "dead actor cannot be healed")


func test_projectile_hits_enemy_through_physics_and_frees() -> void:
	_make_level_scaffold()
	var target := _make_actor(Teams.Team.ENEMY, 3)
	(target.get_parent() as Node3D).global_position = Vector3(4, 0, 0)
	var shot := (load("res://combat/projectiles/player_shot.tscn") as PackedScene).instantiate() as Projectile
	Projectile.find_root(get_tree()).add_child(shot)
	shot.global_position = Vector3(0, 0, 0)
	shot.setup(Teams.Team.PLAYER, 1, Vector3(40, 0, 0))
	await wait_physics_frames(20)
	assert_eq(target.health.current, 2, "enemy took exactly one damage")
	assert_false(is_instance_valid(shot), "projectile freed on hit")


func test_projectile_passes_through_friendly_hurtbox() -> void:
	_make_level_scaffold()
	var ally := _make_actor(Teams.Team.PLAYER, 3)
	(ally.get_parent() as Node3D).global_position = Vector3(3, 0, 0)
	var shot := (load("res://combat/projectiles/player_shot.tscn") as PackedScene).instantiate() as Projectile
	Projectile.find_root(get_tree()).add_child(shot)
	shot.global_position = Vector3(0, 0, 0)
	shot.setup(Teams.Team.PLAYER, 1, Vector3(40, 0, 0))
	await wait_physics_frames(10)
	assert_eq(ally.health.current, 3, "ally untouched")
	assert_true(is_instance_valid(shot), "projectile keeps flying past ally")


func test_projectile_cleans_up_off_screen() -> void:
	_make_level_scaffold()
	var shot := (load("res://combat/projectiles/player_shot.tscn") as PackedScene).instantiate() as Projectile
	shot.lifetime = 60.0
	Projectile.find_root(get_tree()).add_child(shot)
	shot.global_position = Vector3(15.5, 0, 0)
	shot.setup(Teams.Team.PLAYER, 1, Vector3(40, 0, 0))
	await wait_physics_frames(10)
	assert_false(is_instance_valid(shot), "projectile freed after leaving the play rect")


func test_projectile_lifetime_expires() -> void:
	_make_level_scaffold()
	var shot := (load("res://combat/projectiles/player_shot.tscn") as PackedScene).instantiate() as Projectile
	shot.lifetime = 0.05
	Projectile.find_root(get_tree()).add_child(shot)
	shot.global_position = Vector3.ZERO
	shot.setup(Teams.Team.PLAYER, 1, Vector3.ZERO)
	await wait_physics_frames(8)
	assert_false(is_instance_valid(shot), "stationary projectile freed by lifetime")


func test_offscreen_enemy_survives_until_it_has_entered() -> void:
	_make_level_scaffold()
	var drone := (load("res://enemies/space/space_drone.tscn") as PackedScene).instantiate() as SpaceDrone
	drone.position = Vector3(19, 0, 0)
	add_autofree(drone)
	await wait_physics_frames(5)
	assert_true(is_instance_valid(drone), "drone spawned off-screen is not culled")
	drone.position = Vector3(-19, 0, 0)
	drone.speed = 0.0
	await wait_physics_frames(3)
	# It never entered the rect, so it still survives even on the far side.
	assert_true(is_instance_valid(drone), "require_entered holds until first entry")


func test_drone_telegraphs_before_firing_and_scores_on_death() -> void:
	_make_level_scaffold()
	var drone := (load("res://enemies/space/space_drone.tscn") as PackedScene).instantiate() as SpaceDrone
	drone.position = Vector3(8, 0, 0)
	drone.speed = 0.0
	drone.first_shot_delay = 0.1
	add_autofree(drone)
	drone.set_physics_process(false)
	var fired := SignalSpy.new(drone.weapon.fired)
	drone.tick(0.15)
	assert_true(drone.telegraph.visible, "telegraph shows before the shot")
	assert_eq(fired.count(), 0, "no shot during telegraph")
	drone.tick(drone.telegraph_time + 0.01)
	assert_eq(fired.count(), 1, "shot fires after telegraph")
	assert_false(drone.telegraph.visible, "telegraph hidden after firing")

	drone.health.apply_damage(DamagePayload.create(99, Teams.Team.PLAYER), self)
	assert_eq(RunSession.score, drone.score_value, "kill awards score through RunSession")
