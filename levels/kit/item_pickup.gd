class_name ItemPickup
extends Area3D
## Health capsule (+2 HP) or energy cell (+1 SUPER segment). Bobs in place.

enum Kind { HEALTH, ENERGY }

@export var kind: Kind = Kind.HEALTH
@export var amount: int = 2

var _visual: Node3D
var _time: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.HURTBOX
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	shape.shape = sphere
	add_child(shape)
	area_entered.connect(_on_area_entered)
	_visual = ModelKit.group(self, "Visual")
	var color := Palette.HEALTH_GREEN if kind == Kind.HEALTH else Palette.RESONANCE_VIOLET
	ModelKit.quad(_visual, Vector2.ONE * 1.6, Vector3(0, 0, -0.2), ModelKit.glow(color, 1.0))
	if kind == Kind.HEALTH:
		ModelKit.hex_x(_visual, 0.26, 0.8, Vector3.ZERO, ModelKit.hull(Palette.PLAYER_PRIMARY, ArtStyle.OUTLINE_THIN), 8)
		ModelKit.box(_visual, Vector3(0.34, 0.12, 0.6), Vector3(0, 0, 0.1), ModelKit.emissive(color, 2.2))
		ModelKit.box(_visual, Vector3(0.12, 0.34, 0.6), Vector3(0, 0, 0.1), ModelKit.emissive(color, 2.2))
	else:
		ModelKit.box(_visual, Vector3.ONE * 0.5, Vector3.ZERO, ModelKit.emissive(color, 2.4), Vector3(45, 0, 45))


func _physics_process(delta: float) -> void:
	_time += delta
	_visual.position.y = sin(_time * 3.0) * 0.15
	_visual.rotation.y += delta * 2.0


func _on_area_entered(area: Area3D) -> void:
	var player := area.get_parent()
	if player == null or not player.is_in_group(Players.GROUP):
		return
	if kind == Kind.HEALTH:
		(player.get(&"health") as HealthComponent).heal(amount)
	else:
		RunSession.add_energy(amount)
	Vfx.spawn(get_tree(), preload("res://vfx/collect_burst.tscn"), global_position, 0.8,
			{&"color": Palette.HEALTH_GREEN if kind == Kind.HEALTH else Palette.RESONANCE_VIOLET})
	queue_free()
