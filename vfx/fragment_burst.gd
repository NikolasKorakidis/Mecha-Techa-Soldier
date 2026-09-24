class_name FragmentBurst
extends Node3D
## Throws a few recognizable model pieces outward, spinning, then shrinks them away.

const LIFETIME := 1.4

var _pieces: Array[Node3D] = []
var _velocities: Array[Vector3] = []
var _spins: Array[Vector3] = []
var _age: float = 0.0


static func create(pieces: Array[Node3D], origin: Vector3, force: float = 7.0) -> FragmentBurst:
	var burst := FragmentBurst.new()
	for piece in pieces:
		burst._pieces.append(piece)
		var away := piece.transform.origin - origin
		away.z = 0.0
		var dir := away.normalized() if away.length() > 0.05 else Vector3(randf_range(-1, 1), randf_range(-1, 1), 0).normalized()
		burst._velocities.append(dir * force * randf_range(0.7, 1.2) + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0))
		burst._spins.append(Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-9, 9)))
	return burst


func _ready() -> void:
	for piece in _pieces:
		add_child(piece)


func _process(delta: float) -> void:
	_age += delta
	var shrink := clampf(1.0 - (_age - LIFETIME * 0.6) / (LIFETIME * 0.4), 0.0, 1.0)
	for i in _pieces.size():
		var piece := _pieces[i]
		_velocities[i] *= 1.0 - 1.8 * delta
		piece.position += _velocities[i] * delta
		piece.rotation += _spins[i] * delta
		piece.scale = Vector3.ONE * shrink
	if _age >= LIFETIME:
		queue_free()
