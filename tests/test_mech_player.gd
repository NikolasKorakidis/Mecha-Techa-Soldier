extends TestCase
## Mech platforming feel, driven deterministically through tick() on real physics floors.

const DT := 1.0 / 60.0

var mech: MechPlayer
var world: Node3D


func _setup(at: Vector3 = Vector3(0, 0.05, 0)) -> void:
	LevelScaffold.build(self)
	world = Node3D.new()
	add_autofree(world)
	LevelKit.solid(world, -30.0, 0.0, 40.0, 4.0)     # floor x -30..10
	LevelKit.solid(world, 14.0, 0.0, 30.0, 4.0)      # floor x 14..44 (gap 10..14)
	LevelKit.solid(world, -34.0, 12.0, 4.0, 16.0)    # left wall
	mech = (load("res://player/mech/mech_player.tscn") as PackedScene).instantiate() as MechPlayer
	mech.read_devices = false
	add_autofree(mech)
	mech.global_position = at
	await wait_physics_frames(2)
	_run(0.3, MechInput.new())  # settle on the floor


func _run(seconds: float, input: MechInput) -> void:
	for i in int(round(seconds / DT)):
		mech.tick(DT, input)


func _apex_after(input_press: MechInput, hold: MechInput, seconds: float) -> float:
	var start := mech.global_position.y
	var apex := start
	mech.tick(DT, input_press)
	for i in int(round(seconds / DT)):
		mech.tick(DT, hold)
		apex = maxf(apex, mech.global_position.y)
	return apex - start


func test_held_jump_reaches_about_three_units_and_tap_is_lower() -> void:
	await _setup()
	assert_true(mech.is_on_floor(), "starts grounded")
	var held := _apex_after(MechInput.make(0, true, true), MechInput.make(0, false, true), 0.9)
	assert_near(held, 3.0, 0.35, "held jump apex ≈ 3")
	_run(0.5, MechInput.new())
	var tap := _apex_after(MechInput.make(0, true, true), MechInput.make(0, false, false), 0.9)
	assert_true(tap < held * 0.6, "tap jump is clearly lower (variable height)")


func test_double_jump_adds_height_once() -> void:
	await _setup()
	var start := mech.global_position.y
	mech.tick(DT, MechInput.make(0, true, true))
	_run(0.3, MechInput.make(0, false, true))
	mech.tick(DT, MechInput.make(0, true, true))
	var apex := mech.global_position.y
	for i in 40:
		mech.tick(DT, MechInput.make(0, false, true))
		apex = maxf(apex, mech.global_position.y)
	assert_true(apex - start > 4.5, "double jump reaches > 4.5 (got %.2f)" % (apex - start))
	assert_eq(mech.double_jumps, 1, "one double jump used")
	mech.tick(DT, MechInput.make(0, true, true))
	assert_eq(mech.double_jumps, 1, "no third jump")


func test_coyote_jump_after_leaving_ledge() -> void:
	await _setup(Vector3(8.0, 0.05, 0))
	# Run off the ledge at x = 10, then jump shortly after.
	var left_floor := false
	for i in 60:
		mech.tick(DT, MechInput.make(1.0))
		if not mech.is_on_floor():
			left_floor = true
			break
	assert_true(left_floor, "ran off the ledge")
	mech.tick(DT, MechInput.make(1.0, true, true))
	assert_true(mech.velocity.y > 10.0, "coyote jump fired after leaving the ledge")


func test_ground_dash_is_fast_and_covers_distance() -> void:
	await _setup(Vector3(-20, 0.05, 0))
	var x0 := mech.global_position.x
	mech.tick(DT, MechInput.make(0, false, false, false, true))
	assert_eq(mech.state, MechPlayer.State.DASH, "dash state")
	_run(mech.tuning.dash_duration, MechInput.new())
	var dist := mech.global_position.x - x0
	assert_near(dist, mech.tuning.dash_speed * mech.tuning.dash_duration, 1.0, "dash distance ≈ speed × duration")


func test_wall_jump_pushes_away_from_wall() -> void:
	await _setup(Vector3(-28.5, 11.0, 0))
	# Airborne, pressing into the left wall.
	for i in 20:
		mech.tick(DT, MechInput.make(-1.0))
	assert_eq(mech.state, MechPlayer.State.WALL, "wall slide against the wall")
	mech.tick(DT, MechInput.make(-1.0, true, true))
	assert_true(mech.velocity.x > 5.0 and mech.velocity.y > 10.0, "wall jump kicks up and away")


func test_super_needs_full_energy_then_fires_beam() -> void:
	await _setup()
	mech.tick(DT, MechInput.make(0, false, false, false, false, true))
	assert_true(mech.state != MechPlayer.State.SUPER, "no super without energy")
	RunSession.add_energy(3)
	var spy := SignalSpy.new(mech.super_fired)
	mech.tick(DT, MechInput.make(0, false, false, false, false, true))
	assert_eq(spy.count(), 1, "super fired")
	assert_eq(RunSession.energy, 0, "energy spent")
	var beams := get_tree().get_first_node_in_group(Vfx.ROOT_GROUP).get_children().filter(func(n: Node) -> bool: return n is PlayerBeam)
	assert_eq(beams.size(), 1, "beam spawned")
	assert_true(mech.is_invulnerable(), "invulnerable while firing")


func test_pit_costs_one_hp_and_returns_to_safe_ground() -> void:
	await _setup(Vector3(6.0, 0.05, 0))
	mech.kill_y = -6.0
	var hp := mech.health.current
	for i in 180:
		mech.tick(DT, MechInput.make(1.0))
		if mech.health.current < hp:
			break
	_run(0.5, MechInput.new())
	assert_eq(mech.health.current, hp - 1, "pit cost one HP")
	assert_true(mech.global_position.y > -1.0 and mech.global_position.x < 10.0, "back on the left floor")


func test_super_charge_fills_from_kills() -> void:
	RunSession.add_charge(RunSession.CHARGE_PER_SEGMENT * 3)
	assert_true(RunSession.super_ready(), "three segments of kill value fill the SUPER")
