extends TestCase
## Stage 3 (3D hull run): chase camera, riding, steering limits, jumps, walls, gaps, enemies,
## gunship and finish.

const DT := 1.0 / 60.0

var level: Node
var rider: HullRider
var director: HullRunDirector


func _setup() -> void:
	level = (load("res://levels/hull_run/hull_run_level.tscn") as PackedScene).instantiate()
	add_autofree(level)
	await wait_physics_frames(2)
	rider = level.get_node("HullRider") as HullRider
	director = level.get_node("Segment/HullRunDirector") as HullRunDirector
	director.restart_level = ""
	rider.read_devices = false
	rider.set_physics_process(false)
	rider.set_cinematic(false)


func _ride(seconds: float, input: MechInput) -> void:
	for i in int(round(seconds / DT)):
		rider.tick(DT, input)
		await get_tree().physics_frame


func test_chase_camera_sits_behind_the_bike_in_perspective() -> void:
	await _setup()
	var camera := director.camera
	assert_eq(camera.projection, Camera3D.PROJECTION_PERSPECTIVE, "3D perspective view")
	await wait_physics_frames(2)
	assert_true(camera.global_position.x < rider.global_position.x - 4.0, "camera behind the bike")
	assert_true(camera.global_position.y > rider.global_position.y + 2.0, "and above it")
	var forward := -camera.global_transform.basis.z
	assert_true(forward.x > 0.8, "looking down the track (+X)")


func test_rides_forward_and_steers_within_the_deck() -> void:
	await _setup()
	var x0 := rider.global_position.x
	await _ride(1.0, MechInput.new())
	assert_true(rider.global_position.x - x0 > 10.0, "auto-rides forward")
	await _ride(2.0, MechInput.make(1.0))
	assert_true(rider.global_position.z > 5.0, "steers right (+Z)")
	assert_true(rider.global_position.z <= rider.tuning.lane_half_width + 0.3, "stays on the deck")


func test_wall_hurts_unless_jumped() -> void:
	await _setup()
	var wall := HullObstacle.new()
	wall.kind = HullObstacle.Kind.WALL
	wall.position = Vector3(rider.global_position.x + 30.0, HullTrack.DECK_Y, 0)
	level.add_child(wall)
	await wait_physics_frames(1)
	var hp := rider.health.current
	await _ride(1.6, MechInput.new())
	assert_eq(rider.health.current, hp - 1, "riding into the wall costs 1 HP")
	var wall2 := HullObstacle.new()
	wall2.kind = HullObstacle.Kind.WALL
	wall2.position = Vector3(rider.global_position.x + 30.0, HullTrack.DECK_Y, 0)
	level.add_child(wall2)
	rider.grant_invulnerability(0.0)
	await wait_physics_frames(1)
	hp = rider.health.current
	var jumped := false
	for i in 100:
		var press := not jumped and wall2.global_position.x - rider.global_position.x < 11.0
		jumped = jumped or press
		rider.tick(DT, MechInput.make(0, press, true))
		await get_tree().physics_frame
	assert_true(jumped, "jumped")
	assert_eq(rider.health.current, hp, "a jump clears the wall")


func test_gap_fall_recovers_on_the_next_deck() -> void:
	await _setup()
	var hp := rider.health.current
	rider.global_position = Vector3(705.0, HullTrack.DECK_Y - 12.0, 3.0)
	rider.tick(DT, MechInput.new())
	assert_eq(rider.health.current, hp - 1, "gap costs one HP")
	assert_true(rider.global_position.x >= 712.0 and rider.global_position.y > HullTrack.DECK_Y, "placed on the next deck")


func test_bolts_destroy_fighters() -> void:
	await _setup()
	var fighter := RunFighter.new()
	fighter.speed = 0.0
	fighter.position = rider.global_position + Vector3(40.0, 1.0, 0.0)
	director.enemy_root.add_child(fighter)
	await wait_physics_frames(2)
	var score := RunSession.score
	await _ride(2.0, MechInput.make(0, false, false, true))
	assert_false(is_instance_valid(fighter) and fighter.is_alive(), "fighter shot down")
	assert_true(RunSession.score > score, "kill scored")


func test_gunship_appears_and_finish_hands_over() -> void:
	await _setup()
	director.intro_time = 0.0
	await wait_physics_frames(2)
	rider.teleport(Vector3(director.gunship_x + 1.0, HullTrack.DECK_Y + 0.6, 0))
	await wait_physics_frames(2)
	assert_true(director.gunship is RunGunship, "pursuit gunship spawned")
	rider.teleport(Vector3(director.track.finish_x + 1.0, HullTrack.DECK_Y + 0.6, 0))
	await wait_physics_frames(2)
	assert_eq(director.state, HullRunDirector.State.FINISH, "finish reached")


func test_track_gaps_are_clearable() -> void:
	var decks: Array = HullTrack.DECKS
	for i in range(1, decks.size()):
		var gap: float = decks[i][0] - decks[i - 1][1]
		var has_pad := false
		for o: Array in HullTrack.OBSTACLES:
			if o[0] == HullObstacle.Kind.PAD and o[1] < decks[i - 1][1] and o[1] > decks[i - 1][1] - 12.0:
				has_pad = true
		assert_true(gap <= 20.0 or has_pad, "gap at x=%.0f (%.0f wide) is clearable" % [decks[i - 1][1], gap])
