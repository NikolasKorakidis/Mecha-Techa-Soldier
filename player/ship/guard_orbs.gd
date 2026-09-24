class_name GuardOrbs
extends Node3D
## GUARD echo: two orbs circle the ship, cancel hostile projectiles they touch, and
## fire alongside the main gun.

signal projectile_blocked

@export var orbit_radius: float = 1.7
@export var orbit_speed: float = 3.2
@export var orb_color: Color = Color(1.0, 0.85, 0.35)

var active: bool = false:
	set(value):
		active = value
		visible = value
		for orb in _orbs:
			orb.set_deferred(&"monitoring", value)

var _orbs: Array[Area3D] = []
var _angle: float = 0.0


func _ready() -> void:
	for i in 2:
		var orb := Area3D.new()
		orb.collision_layer = 0
		orb.collision_mask = PhysicsLayers.HITBOX
		orb.monitorable = false
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.55
		shape.shape = sphere
		orb.add_child(shape)
		ModelKit.sphere(orb, 0.26, Vector3.ZERO, ModelKit.emissive(orb_color, 2.5))
		ModelKit.quad(orb, Vector2.ONE * 1.4, Vector3(0, 0, 0.1), ModelKit.glow(orb_color, 1.2))
		ModelKit.quad(orb, Vector2.ONE * 1.2, Vector3(0, 0, 0.12), ModelKit.glow(orb_color, 0.9, ModelKit.GlowShape.RING))
		orb.area_entered.connect(_on_orb_area_entered)
		add_child(orb)
		_orbs.append(orb)
	active = false


func _physics_process(delta: float) -> void:
	if not active:
		return
	_angle += orbit_speed * delta
	for i in _orbs.size():
		var a := _angle + PI * i
		_orbs[i].position = Vector3(cos(a) * orbit_radius * 0.8, sin(a) * orbit_radius, 0.2)


func orb_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for orb in _orbs:
		result.append(orb.global_position)
	return result


func _on_orb_area_entered(area: Area3D) -> void:
	var hitbox := area as HitboxComponent
	if hitbox == null or hitbox.payload == null or hitbox.payload.team != Teams.Team.ENEMY:
		return
	var projectile := hitbox.get_parent() as Projectile
	if projectile == null:
		return
	projectile.queue_free()
	projectile_blocked.emit()
