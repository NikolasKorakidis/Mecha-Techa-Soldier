class_name Projectile
extends Node3D
## Straight-line projectile. Moves on the gameplay plane, hits through its Hitbox,
## frees itself on hit, lifetime expiry or leaving the screen (OffscreenCleanup child).

const ROOT_GROUP := &"projectile_root"

@export var hitbox: HitboxComponent
@export var lifetime: float = 3.0

var velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	if hitbox == null:
		push_error("Projectile '%s' has no hitbox assigned." % name)
		return
	hitbox.hit_landed.connect(_on_hit_landed)


func setup(team: Teams.Team, damage: int, initial_velocity: Vector3) -> void:
	velocity = Vector3(initial_velocity.x, initial_velocity.y, 0.0)
	hitbox.payload = DamagePayload.create(damage, team)
	if velocity.length_squared() > 0.0:
		rotation.z = atan2(velocity.y, velocity.x)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_hit_landed(_hurtbox: HurtboxComponent) -> void:
	queue_free()


## The level node that owns live projectiles. Missing = broken level wiring.
static func find_root(tree: SceneTree) -> Node:
	var root := tree.get_first_node_in_group(ROOT_GROUP)
	if root == null:
		push_error("No node in group '%s'; add a Projectiles node to the level." % ROOT_GROUP)
	return root
