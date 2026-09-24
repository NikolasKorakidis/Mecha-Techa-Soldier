class_name Starfield
extends MultiMeshInstance3D
## Parallax background: layered star quads scrolling left at independent speeds.
## Purely visual — scroll speed never drives enemy motion.

@export var star_count: int = 140
@export var layer_speeds: PackedFloat32Array = PackedFloat32Array([0.6, 2.0, 6.0])
@export var extents: Vector2 = Vector2(20.0, 10.0)
@export var depth: float = -12.0
@export var star_color: Color = Color(0.75, 0.95, 1.0)

var _positions: PackedVector2Array = []
var _layers: PackedInt32Array = []


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = star_color
	quad.material = material

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = star_count

	# Fixed seed keeps the background identical between runs.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_positions.resize(star_count)
	_layers.resize(star_count)
	for i in star_count:
		_positions[i] = Vector2(rng.randf_range(-extents.x, extents.x), rng.randf_range(-extents.y, extents.y))
		_layers[i] = rng.randi_range(0, layer_speeds.size() - 1)
	_update_transforms()


func _process(delta: float) -> void:
	for i in star_count:
		var p := _positions[i]
		p.x -= layer_speeds[_layers[i]] * delta
		if p.x < -extents.x:
			p.x += extents.x * 2.0
		_positions[i] = p
	_update_transforms()


func _update_transforms() -> void:
	for i in star_count:
		# Faster layers read as nearer: stretch them horizontally.
		var stretch := 1.0 + float(_layers[i]) * 1.5
		var basis := Basis.from_scale(Vector3(stretch, 1.0, 1.0))
		multimesh.set_instance_transform(i, Transform3D(basis, Vector3(_positions[i].x, _positions[i].y, depth)))
