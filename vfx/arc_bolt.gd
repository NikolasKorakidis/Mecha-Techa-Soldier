class_name ArcBolt
extends MeshInstance3D
## Jagged lightning through a list of points; fades out in a blink.

const DURATION := 0.14

var _points: PackedVector3Array = []
var _age: float = 0.0
var _material: ShaderMaterial


static func create(points: PackedVector3Array, color: Color) -> ArcBolt:
	var bolt := ArcBolt.new()
	bolt._points = points
	bolt._material = ModelKit.glow(color, 2.6)
	return bolt


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rebuild()


func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		queue_free()
		return
	_material.set_shader_parameter(&"energy", 2.6 * (1.0 - _age / DURATION))


## Quads along each jittered segment; the glow shader's radial falloff softens them.
func _rebuild() -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	for i in _points.size() - 1:
		var a := _points[i]
		var b := _points[i + 1]
		var steps := maxi(3, int(a.distance_to(b) / 0.8))
		var prev := a
		for s in range(1, steps + 1):
			var t := float(s) / float(steps)
			var p := a.lerp(b, t)
			if s < steps:
				p += Vector3(randf_range(-0.35, 0.35), randf_range(-0.35, 0.35), 0)
			_segment(im, prev, p, 0.22)
			prev = p
	im.surface_end()
	mesh = im


func _segment(im: ImmediateMesh, a: Vector3, b: Vector3, width: float) -> void:
	var dir := (b - a)
	var n := Vector3(-dir.y, dir.x, 0).normalized() * width
	var uv := [Vector2(0.5, 0.0), Vector2(0.5, 1.0)]
	var verts := [a + n, a - n, b + n, b - n]
	var uvs := [uv[0], uv[1], uv[0], uv[1]]
	for idx in [0, 1, 2, 2, 1, 3]:
		im.surface_set_uv(uvs[idx])
		im.surface_add_vertex(verts[idx])
