extends Node3D
## Test-room spawner: sends enemies in from its X position on a fixed lane rotation.
## Deterministic on purpose; the real level uses data-authored waves (M3).

@export var enemy_scene: PackedScene
@export var container: Node3D
@export var interval: float = 2.5
@export var max_alive: int = 3
@export var lanes: PackedFloat32Array = PackedFloat32Array([4.0, -3.0, 1.0, -5.5, 6.0])
@export var first_spawn_delay: float = 1.0

var _time_left: float = 0.0
var _lane: int = 0


func _ready() -> void:
	_time_left = first_spawn_delay
	if enemy_scene == null or container == null:
		push_error("DroneSpawner '%s': enemy_scene and container must be assigned." % name)
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left > 0.0:
		return
	_time_left = interval
	if container.get_child_count() >= max_alive:
		return
	var enemy := enemy_scene.instantiate() as Node3D
	enemy.position = Vector3(global_position.x, lanes[_lane], 0.0)
	container.add_child(enemy)
	_lane = (_lane + 1) % lanes.size()
