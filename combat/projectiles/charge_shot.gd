class_name ChargeShot
extends Node3D
## Mega Man-style charged buster shot: a large plasma ball that pierces every enemy it
## touches (each hurtbox once) and keeps flying. Built in code; lives in the projectile root.

const SPEED := 34.0
const LIFETIME := 1.3

var velocity: Vector3 = Vector3.ZERO
var _lifetime: float = LIFETIME
var _core: Node3D
var _time: float = 0.0


## level 1 = partial charge, level 2 = full charge.
static func fire(tree: SceneTree, from: Vector3, facing: float, level: int, damage: int) -> ChargeShot:
	var root := Projectile.find_root(tree)
	if root == null:
		return null
	var shot := ChargeShot.new()
	shot.velocity = Vector3(facing * SPEED, 0, 0)
	root.add_child(shot)
	shot.global_position = Vector3(from.x, from.y, 0.0)
	shot._build(level, damage)
	AudioService.play(&"shot_heavy")
	return shot


func _build(level: int, damage: int) -> void:
	var full := level >= 2
	var radius := 0.85 if full else 0.45
	var color := Palette.PLAYER_ENERGY.lerp(Color.WHITE, 0.2) if full else Palette.PLAYER_ENERGY
	var hitbox := HitboxComponent.new()
	hitbox.payload = DamagePayload.create(damage, Teams.Team.PLAYER)
	hitbox.single_hit = false
	hitbox.source = self
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	hitbox.add_child(shape)
	add_child(hitbox)
	hitbox.hit_landed.connect(_on_hit)
	_core = ModelKit.group(self, "Core")
	ModelKit.quad(_core, Vector2.ONE * radius * 5.0, Vector3(0, 0, -0.1), ModelKit.glow(color, 2.2))
	ModelKit.sphere(_core, radius * 0.6, Vector3.ZERO, ModelKit.emissive(color.lerp(Color.WHITE, 0.5), 4.0))
	# Trailing tail stretched behind the ball.
	ModelKit.quad(self, Vector2(radius * 6.0, radius * 1.4), Vector3(-signf(velocity.x) * radius * 2.6, 0, -0.15),
			ModelKit.glow(color, 1.2, ModelKit.GlowShape.STREAK))


func _physics_process(delta: float) -> void:
	_time += delta
	position += velocity * delta
	_core.scale = Vector3.ONE * (1.0 + sin(_time * 40.0) * 0.12)
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()


func _on_hit(_hurtbox: HurtboxComponent) -> void:
	Explosion3D.spawn(get_tree(), global_position, 0.5)
