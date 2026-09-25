class_name Bolt3D
extends Node3D
## Laser bolt for the 3D chase view: free 3D velocity, glowing head + streak aligned with its
## travel, damage through a HitboxComponent. Lives in the level's projectile root.

var velocity: Vector3 = Vector3.ZERO
var lifetime: float = 2.4
var hitbox: HitboxComponent


static func fire(tree: SceneTree, team: Teams.Team, damage: int, from: Vector3, vel: Vector3,
		color: Color, radius: float = 0.35) -> Bolt3D:
	var root := Projectile.find_root(tree)
	if root == null:
		return null
	var bolt := Bolt3D.new()
	bolt.velocity = vel
	root.add_child(bolt)
	bolt.global_position = from
	bolt._build(team, damage, color, radius)
	AudioService.play(&"laser" if team == Teams.Team.PLAYER else &"shot_enemy")
	return bolt


func _build(team: Teams.Team, damage: int, color: Color, radius: float) -> void:
	hitbox = HitboxComponent.new()
	hitbox.payload = DamagePayload.create(damage, team)
	hitbox.single_hit = true
	hitbox.source = self
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius * 1.6
	shape.shape = sphere
	hitbox.add_child(shape)
	add_child(hitbox)
	hitbox.hit_landed.connect(_on_hit)
	var head := MeshInstance3D.new()
	head.mesh = QuadMesh.new()
	head.material_override = ModelKit.glow_billboard(color, 2.4)
	head.scale = Vector3.ONE * radius * 5.0
	add_child(head)
	# Streak: a thin emissive box along local -Z, oriented to the velocity.
	var streak := MeshInstance3D.new()
	var box := BoxMesh.new()
	var length := clampf(velocity.length() * 0.05, 1.0, 5.0)
	box.size = Vector3(radius * 0.7, radius * 0.7, length)
	streak.mesh = box
	streak.material_override = ModelKit.emissive(color.lerp(Color.WHITE, 0.4), 3.0)
	streak.position = Vector3(0, 0, length * 0.5)
	add_child(streak)
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.95 else Vector3.RIGHT)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_hit(_hurtbox: HurtboxComponent) -> void:
	Explosion3D.spawn(get_tree(), global_position, 0.25)
	queue_free()
