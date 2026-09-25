class_name ConveyorBelt
extends Area3D
## Belt strip laid on top of a continuous floor: grounded bodies standing on it are dragged at
## `speed` (negative = toward -X) through move_and_collide, so walls still stop them. The floor
## stays one collider (no seams to snag on); chevrons scroll to show the direction.

@export var width: float = 10.0
@export var speed: float = -3.0

var _chevrons: Array[Node3D] = []
var _phase: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.ACTOR
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.6, LevelKit.DEPTH)
	shape.shape = box
	shape.position = Vector3(0, 0.3, 0)
	add_child(shape)
	ModelKit.box(self, Vector3(width, 0.06, 2.6), Vector3(0, 0.0, 0), ModelKit.toon(Color("1a1d27"), 0.3, 0.8, 0.3))
	for side: float in [-1.0, 1.0]:
		ModelKit.cylinder(self, 0.16, 0.16, 2.7, Vector3(side * width * 0.5, -0.1, 0), LevelKit.material(&"bolt"), Vector3(90, 0, 0), 10)
	var arrow := ModelKit.emissive(Palette.INTERACTABLE, 1.4)
	var count := int(width / 1.6)
	for i in count:
		var chevron := ModelKit.group(self, "Chevron", Vector3(-width * 0.5 + 0.8 + i * 1.6, 0.04, 0))
		ModelKit.prism(chevron, Vector3(0.5, 0.02, 0.9), Vector3(0, 0, 0.6), arrow, Vector3(0, 90 if speed < 0.0 else -90, 0))
		_chevrons.append(chevron)


func _physics_process(delta: float) -> void:
	_phase = fposmod(_phase + speed * delta, 1.6)
	for i in _chevrons.size():
		_chevrons[i].position.x = fposmod(i * 1.6 + _phase, width - 0.4) - width * 0.5 + 0.2
	for body in get_overlapping_bodies():
		var mover := body as CharacterBody3D
		if mover and mover.is_on_floor():
			mover.move_and_collide(Vector3(speed * delta, 0, 0))
