extends TestCase
## Bike auto-runner: cruise, jump, duck, boost-ram, gap recovery.

const DT := 1.0 / 60.0

var bike: BikePlayer


func _setup(floor_end: float = 400.0) -> void:
	LevelScaffold.build(self)
	var world := Node3D.new()
	add_autofree(world)
	LevelKit.solid(world, -20.0, 0.0, floor_end + 20.0, 4.0)
	bike = (load("res://player/bike/bike_player.tscn") as PackedScene).instantiate() as BikePlayer
	bike.read_devices = false
	add_autofree(bike)
	bike.global_position = Vector3(0, 0.05, 0)
	await wait_physics_frames(2)


func _run(seconds: float, input: MechInput) -> void:
	for i in int(round(seconds / DT)):
		bike.tick(DT, input)


func _obstacle(kind: TrackObstacle.Kind, x: float) -> TrackObstacle:
	var o := TrackObstacle.new()
	o.kind = kind
	o.position = Vector3(x, 0, 0)
	add_autofree(o)
	return o


func test_rides_forward_without_input_and_speeds_up() -> void:
	await _setup()
	_run(1.0, MechInput.new())
	assert_true(bike.velocity.x > bike.tuning.start_speed * 0.9, "auto-runs at cruise speed")
	var cruise := bike.cruise_speed
	_run(3.0, MechInput.new())
	assert_true(bike.cruise_speed > cruise, "cruise speed ramps up")
	assert_true(bike.cruise_speed <= bike.tuning.max_speed, "capped at max speed")


func test_duck_shrinks_the_hurtbox_and_jump_restores_it() -> void:
	await _setup()
	_run(0.2, MechInput.new())
	var standing: float = (bike.hurtbox.get_child(0) as CollisionShape3D).shape.size.y
	_run(0.1, MechInput.make(0, false, false, false, false, false, true))
	assert_true(bike.ducking, "ducking while holding down on the ground")
	assert_true((bike.hurtbox.get_child(0) as CollisionShape3D).shape.size.y < standing * 0.6, "hurtbox lowered")
	bike.tick(DT, MechInput.make(0, true, true))
	assert_false(bike.ducking, "jumping stands back up")


func test_barrier_hurts_unless_jumped() -> void:
	await _setup()
	_obstacle(TrackObstacle.Kind.BARRIER, 20.0)
	await wait_physics_frames(1)
	var hp := bike.health.current
	for i in 150:
		bike.tick(DT, MechInput.new())
		await get_tree().physics_frame
	assert_eq(bike.health.current, hp - 1, "riding into a barrier costs 1 HP")


func test_jumping_clears_a_barrier() -> void:
	await _setup()
	_obstacle(TrackObstacle.Kind.BARRIER, 20.0)
	await wait_physics_frames(1)
	var hp := bike.health.current
	var jumped := false
	for i in 150:
		var press := not jumped and bike.global_position.x > 14.0
		jumped = jumped or press
		bike.tick(DT, MechInput.make(0, press, true))
		await get_tree().physics_frame
	assert_eq(bike.health.current, hp, "jump clears the barrier")


func test_boost_smashes_crates() -> void:
	await _setup()
	_run(1.0, MechInput.new())
	var crate := _obstacle(TrackObstacle.Kind.CRATE, bike.global_position.x + 7.0)
	await wait_physics_frames(1)
	var hp := bike.health.current
	var score := RunSession.score
	bike.tick(DT, MechInput.make(0, false, false, false, true))
	assert_eq(bike.state, BikePlayer.State.BOOST, "boosting")
	for i in 40:
		bike.tick(DT, MechInput.new())
		await get_tree().physics_frame
	assert_false(is_instance_valid(crate) and not crate.is_queued_for_deletion(), "crate destroyed by the ram")
	assert_eq(bike.health.current, hp, "no damage while boosting")
	assert_true(RunSession.score > score, "crate awards score")


func test_gap_fall_recovers_on_the_next_deck() -> void:
	LevelScaffold.build(self)
	var level := (load("res://levels/highway/highway_level.tscn") as PackedScene).instantiate()
	add_autofree(level)
	await wait_physics_frames(2)
	bike = level.get_node("BikePlayer") as BikePlayer
	var hp := bike.health.current
	bike.global_position = Vector3(131.0, -13.0, 0)  # inside the first gap (128..134), below kill_y
	bike.read_devices = false
	bike.set_cinematic(false)
	bike.tick(DT, MechInput.new())
	assert_eq(bike.health.current, hp - 1, "gap costs one HP")
	assert_true(bike.global_position.x >= 134.0 and bike.global_position.y > -0.5, "placed on the deck past the gap")


func test_highway_gaps_are_clearable() -> void:
	# Double jump ≈ 22 units at cruise speed; wider gaps need a pad right before them.
	var road: Array = HighwayTrack.ROAD
	for i in range(1, road.size()):
		var gap: float = road[i][0] - road[i - 1][1]
		if gap <= 0.0:
			continue
		var has_pad := false
		for o: Array in HighwayTrack.OBSTACLES:
			if o[0] == TrackObstacle.Kind.PAD and o[1] < road[i - 1][1] and o[1] > road[i - 1][1] - 12.0:
				has_pad = true
		assert_true(gap <= 20.0 or has_pad, "gap at x=%.0f (%.0f wide) is clearable" % [road[i - 1][1], gap])
		var rise: float = road[i][2] - road[i - 1][2]
		assert_true(rise <= 2.2, "deck at x=%.0f rises by at most a single jump" % road[i][0])
