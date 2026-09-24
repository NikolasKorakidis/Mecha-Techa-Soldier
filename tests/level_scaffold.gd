class_name LevelScaffold
extends RefCounted
## Builds the minimum level wiring (camera, projectile/effect/pickup roots) for tests.

static func build(test: TestCase) -> GameplayCamera:
	var camera := GameplayCamera.new()
	camera.size = 18.0
	camera.position = Vector3(0, 0, 30)
	test.add_autofree(camera)
	for group: StringName in [Projectile.ROOT_GROUP, Vfx.ROOT_GROUP, EchoPickup.ROOT_GROUP]:
		var node := Node3D.new()
		node.add_to_group(group)
		test.add_autofree(node)
	return camera


static func ship(test: TestCase, at: Vector3 = Vector3(-8, 0, 0)) -> ShipPlayer:
	var player := (load("res://player/ship/ship_player.tscn") as PackedScene).instantiate() as ShipPlayer
	player.read_devices = false
	test.add_autofree(player)
	player.global_position = at
	return player


static func enemy(test: TestCase, scene_name: String, at: Vector3) -> SpaceEnemy:
	var e := (load("res://enemies/space/%s.tscn" % scene_name) as PackedScene).instantiate() as SpaceEnemy
	e.position = at
	test.add_autofree(e)
	e.set_physics_process(false)
	return e


static func hostile_projectiles(tree: SceneTree) -> int:
	var count := 0
	for child in tree.get_first_node_in_group(Projectile.ROOT_GROUP).get_children():
		var p := child as Projectile
		if p and not p.is_queued_for_deletion() and p.hitbox.payload and p.hitbox.payload.team == Teams.Team.ENEMY:
			count += 1
	return count
