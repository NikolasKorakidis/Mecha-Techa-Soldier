extends TestCase
## Ship feel and damage behavior, driven deterministically through tick().

const DT := 1.0 / 60.0

var ship: ShipPlayer
var camera: GameplayCamera


func _setup_ship() -> void:
	camera = GameplayCamera.new()
	camera.size = 18.0
	camera.position = Vector3(0, 0, 30)
	add_autofree(camera)
	var projectiles := Node3D.new()
	projectiles.add_to_group(Projectile.ROOT_GROUP)
	add_autofree(projectiles)
	ship = (load("res://player/ship/ship_player.tscn") as PackedScene).instantiate() as ShipPlayer
	ship.read_devices = false
	add_autofree(ship)
	ship.global_position = Vector3.ZERO


func _run(seconds: float, input: ShipInput) -> void:
	for i in int(round(seconds / DT)):
		ship.tick(DT, input)


func test_accelerates_quickly_but_not_instantly() -> void:
	_setup_ship()
	ship.tick(DT, ShipInput.make(Vector2.RIGHT))
	var max_speed := ship.tuning.max_speed
	assert_true(ship.movement.velocity.x < max_speed * 0.5, "first tick is below half speed (not instant)")
	_run(0.2, ShipInput.make(Vector2.RIGHT))
	assert_near(ship.movement.velocity.x, max_speed, 0.01, "reaches max speed within 0.2 s")


func test_release_eases_out() -> void:
	_setup_ship()
	_run(0.3, ShipInput.make(Vector2.RIGHT))
	ship.tick(DT, ShipInput.make(Vector2.ZERO))
	assert_true(ship.movement.velocity.x > 0.0, "still drifting one tick after release")
	_run(0.3, ShipInput.make(Vector2.ZERO))
	assert_near(ship.movement.velocity.length(), 0.0, 0.001, "stopped after ease-out")


func test_ship_stays_inside_play_rect_and_on_plane() -> void:
	_setup_ship()
	var rect := camera.get_play_rect()
	_run(3.0, ShipInput.make(Vector2(1, 1)))
	assert_true(ship.global_position.x <= rect.end.x - ship.tuning.boundary_margin.x + 0.001, "right edge respected")
	var top_limit := rect.end.y - ship.tuning.boundary_margin.y - ship.tuning.hud_top_inset
	assert_true(ship.global_position.y <= top_limit + 0.001, "top edge (below HUD band) respected")
	assert_true(ship.global_position.x > rect.end.x - ship.tuning.boundary_margin.x - 0.1, "soft edge still lets ship reach the boundary")
	_run(0.5, ShipInput.make(Vector2.ZERO, false, true))
	assert_true(ship.global_position.x <= rect.end.x - ship.tuning.boundary_margin.x + 0.001, "dash cannot leave the rect")
	_run(4.0, ShipInput.make(Vector2(-1, -1)))
	assert_true(ship.global_position.x >= rect.position.x + ship.tuning.boundary_margin.x - 0.001, "left edge respected")
	assert_true(ship.global_position.y >= rect.position.y + ship.tuning.boundary_margin.y - 0.001, "bottom edge respected")
	assert_eq(ship.global_position.z, 0.0, "ship stays on the Z = 0 plane")


func test_dash_grants_short_invulnerability_then_cooldown() -> void:
	_setup_ship()
	ship.tick(DT, ShipInput.make(Vector2.UP, false, true))
	assert_eq(ship.state, ShipPlayer.State.DASH, "dash starts")
	assert_true(ship.is_invulnerable(), "invulnerable at dash start")
	_run(ship.tuning.dash_invulnerability + DT, ShipInput.make(Vector2.UP))
	assert_false(ship.is_invulnerable(), "invulnerability window is shorter than the dash")
	_run(ship.tuning.dash_duration, ShipInput.make(Vector2.UP))
	assert_eq(ship.state, ShipPlayer.State.CONTROL, "dash ends")
	ship.tick(DT, ShipInput.make(Vector2.UP, false, true))
	assert_eq(ship.state, ShipPlayer.State.CONTROL, "cannot dash again during cooldown")
	_run(ship.tuning.dash_cooldown, ShipInput.make(Vector2.ZERO))
	ship.tick(DT, ShipInput.make(Vector2.ZERO, false, true))
	assert_eq(ship.state, ShipPlayer.State.DASH, "dash available after cooldown")


func test_neutral_dash_goes_forward() -> void:
	_setup_ship()
	var start_x := ship.global_position.x
	ship.tick(DT, ShipInput.make(Vector2.ZERO, false, true))
	_run(ship.tuning.dash_duration, ShipInput.make(Vector2.ZERO))
	assert_true(ship.global_position.x > start_x + 3.0, "neutral dash travels forward (+X)")


func test_held_fire_spawns_projectiles_without_mashing() -> void:
	_setup_ship()
	var fired := SignalSpy.new(ship.weapon.fired)
	_run(1.0, ShipInput.make(Vector2.ZERO, true))
	var expected := int(1.0 / ship.weapon.fire_interval)
	assert_true(absi(fired.count() - expected) <= 1, "held fire produces ~%d shots/s (got %d)" % [expected, fired.count()])


func test_damage_updates_run_session_and_grants_invulnerability() -> void:
	_setup_ship()
	var hud_spy := SignalSpy.new(RunSession.health_changed)
	var hit := DamagePayload.create(1, Teams.Team.ENEMY)
	assert_true(ship.hurtbox.receive_hit(hit, self), "enemy hit lands")
	assert_eq(RunSession.health, RunSession.max_health - 1, "RunSession mirrors player health")
	assert_eq(hud_spy.count(), 1, "HUD-facing signal emitted once")
	assert_eq(ship.state, ShipPlayer.State.HIT, "brief hit state")
	assert_false(ship.hurtbox.receive_hit(hit, self), "invulnerable right after a hit")
	_run(ship.tuning.hit_invulnerability + DT, ShipInput.make(Vector2.ZERO))
	assert_eq(ship.state, ShipPlayer.State.CONTROL, "control returns")
	assert_true(ship.hurtbox.receive_hit(hit, self), "vulnerable again after window")


func test_player_shots_cannot_hurt_player() -> void:
	_setup_ship()
	assert_false(ship.hurtbox.receive_hit(DamagePayload.create(1, Teams.Team.PLAYER), self), "friendly fire rejected")
	assert_eq(RunSession.health, RunSession.max_health, "health untouched")


func test_death_emits_once_disables_and_respawn_restores() -> void:
	_setup_ship()
	var died := SignalSpy.new(ship.died)
	var lethal := DamagePayload.create(99, Teams.Team.ENEMY)
	ship.hurtbox.receive_hit(lethal, self)
	ship.hurtbox.receive_hit(lethal, self)
	assert_eq(died.count(), 1, "died emitted exactly once")
	assert_eq(ship.state, ShipPlayer.State.DISABLED, "disabled while dead")
	assert_eq(RunSession.health, 0, "RunSession shows 0 health")
	var pos := ship.global_position
	_run(0.5, ShipInput.make(Vector2.RIGHT, true))
	assert_eq(ship.global_position, pos, "dead ship ignores input")

	ship.respawn(Vector3(-5, 1, 0))
	assert_eq(ship.state, ShipPlayer.State.CONTROL, "control after respawn")
	assert_eq(RunSession.health, RunSession.max_health, "health restored on respawn")
	assert_true(ship.is_invulnerable(), "respawn grants invulnerability")
	assert_eq(ship.global_position, Vector3(-5, 1, 0), "respawned at spawn point")


func test_room_respawns_player_after_delay() -> void:
	var room := (load("res://levels/test_rooms/graybox_room.tscn") as PackedScene).instantiate() as TestRoom
	room.respawn_delay = 0.1
	add_autofree(room)
	await wait_physics_frames(1)
	room.player.hurtbox.receive_hit(DamagePayload.create(99, Teams.Team.ENEMY), self)
	assert_eq(room.player.state, ShipPlayer.State.DISABLED, "player dead")
	await get_tree().create_timer(0.3).timeout
	assert_eq(room.player.state, ShipPlayer.State.CONTROL, "room respawned the player")
	assert_eq(room.player.global_position, room.spawn.global_position, "at the spawn marker")
