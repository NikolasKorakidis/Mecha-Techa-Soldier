class_name CrumblePlatform
extends StaticBody3D
## Ledge that gives way: stand on it and it shakes for `delay` seconds, then drops out of the
## level; it rebuilds after `respawn` seconds.

@export var width: float = 3.0
@export var delay: float = 0.55
@export var respawn: float = 3.0

enum State { READY, SHAKING, GONE }

var state: State = State.READY

var _shape: CollisionShape3D
var _visual: Node3D
var _sensor: Area3D
var _timer: float = 0.0
var _home: Vector3


func _ready() -> void:
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	_home = position
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.6, LevelKit.DEPTH)
	_shape.shape = box
	add_child(_shape)
	_visual = ModelKit.group(self, "Visual")
	var slab := ModelKit.hull(Color("4a3a36"), ArtStyle.OUTLINE_THIN)
	ModelKit.box(_visual, Vector3(width, 0.6, 2.2), Vector3.ZERO, slab)
	ModelKit.box(_visual, Vector3(width, 0.12, 2.24), Vector3(0, 0.28, 0), LevelKit.material(&"stripe"))
	# Crack lines on the camera face.
	for k in 3:
		ModelKit.box(_visual, Vector3(0.06, 0.5, 0.05), Vector3(-width * 0.3 + k * width * 0.3, -0.02, 1.12), LevelKit.material(&"vent"), Vector3(0, 0, 18 - k * 20))
	_sensor = Area3D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = PhysicsLayers.ACTOR
	_sensor.monitorable = false
	var sense := CollisionShape3D.new()
	var sense_box := BoxShape3D.new()
	sense_box.size = Vector3(width - 0.2, 0.4, LevelKit.DEPTH)
	sense.shape = sense_box
	sense.position = Vector3(0, 0.45, 0)
	_sensor.add_child(sense)
	add_child(_sensor)
	_sensor.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if state == State.READY and body.is_in_group(Players.GROUP):
		state = State.SHAKING
		_timer = delay
		AudioService.play(&"hit")


func _physics_process(delta: float) -> void:
	match state:
		State.SHAKING:
			_timer -= delta
			_visual.position = Vector3(randf_range(-0.06, 0.06), randf_range(-0.04, 0.04), 0)
			if _timer <= 0.0:
				state = State.GONE
				_timer = respawn
				_shape.set_deferred(&"disabled", true)
				_sensor.set_deferred(&"monitoring", false)
		State.GONE:
			_timer -= delta
			_visual.position.y -= 14.0 * delta
			if _timer <= 0.0:
				state = State.READY
				_visual.position = Vector3.ZERO
				_shape.set_deferred(&"disabled", false)
				_sensor.set_deferred(&"monitoring", true)
