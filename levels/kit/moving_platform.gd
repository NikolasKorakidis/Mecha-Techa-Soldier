class_name MovingPlatform
extends AnimatableBody3D
## Platform that loops between its start and `travel`, carrying whatever stands on it.

@export var width: float = 4.0
@export var travel: Vector3 = Vector3(6, 0, 0)
@export var period: float = 4.0

var _start: Vector3
var _time: float = 0.0


func _ready() -> void:
	sync_to_physics = true
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	_start = position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.6, LevelKit.DEPTH)
	shape.shape = box
	add_child(shape)
	ModelKit.box(self, Vector3(width, 0.6, 2.2), Vector3.ZERO, LevelKit.material(&"trim"))
	ModelKit.box(self, Vector3(width - 0.3, 0.08, 0.05), Vector3(0, 0.18, 1.12), LevelKit.material(&"light"))
	ModelKit.box(self, Vector3(width * 0.4, 0.4, 1.4), Vector3(0, -0.45, 0), LevelKit.material(&"hull_dark"))
	ModelKit.quad(self, Vector2(width * 0.5, 0.8), Vector3(0, -0.8, 0.6), ModelKit.glow(Palette.PLAYER_ENERGY, 1.0, ModelKit.GlowShape.STREAK), Vector3(0, 0, -90))


func _physics_process(delta: float) -> void:
	_time += delta
	# Smooth ping-pong: eases at each end so riders can read the turnaround.
	var t := 0.5 - 0.5 * cos(_time / period * TAU)
	position = _start + travel * t
