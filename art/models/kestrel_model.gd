@tool
class_name KestrelModel
extends Node3D
## Kestrel interceptor, built from primitives (faces +X). Broad white-and-blue body,
## gold canopy, oversized wing blocks, cyan echo core and twin engine flames.

const HULL := Color("eef2fb")
const BLUE := Color("2f63e0")
const BLUE_DARK := Color("1d2f6b")
const GOLD := Color("ffc543")
const METAL := Color("3a4152")
const CORE := Color("40c8ff")

var _flames: Array[MeshInstance3D] = []
var _dash_streak: MeshInstance3D
var _thrust: float = 0.6
var _time: float = 0.0


func _ready() -> void:
	ModelKit.clear(self)
	_flames.clear()
	var hull := ModelKit.toon(HULL, 0.45)
	var blue := ModelKit.toon(BLUE, 0.6, 0.45, 0.2)
	var blue_dark := ModelKit.toon(BLUE_DARK, 0.5)
	var gold := ModelKit.glossy(GOLD)
	var metal := ModelKit.toon(METAL, 0.3, 0.4, 0.5)
	var core := ModelKit.emissive(CORE, 3.0)

	# Fuselage and nose.
	ModelKit.box(self, Vector3(1.7, 0.52, 0.72), Vector3(0.0, 0.0, 0.0), hull)
	ModelKit.box(self, Vector3(1.2, 0.2, 0.76), Vector3(0.1, -0.2, 0.0), metal)
	ModelKit.prism(self, Vector3(0.52, 0.8, 0.66), Vector3(1.25, 0.0, 0.0), blue, Vector3(0, 0, -90))
	ModelKit.box(self, Vector3(0.18, 0.1, 0.7), Vector3(0.9, 0.0, 0.0), gold)
	ModelKit.sphere(self, 0.3, Vector3(0.35, 0.3, 0.05), gold, Vector3(1.7, 0.7, 0.95))

	# Oversized wing blocks (they become the mech's shoulders later).
	for side: float in [1.0, -1.0]:
		var y := 0.56 * side
		ModelKit.box(self, Vector3(1.25, 0.36, 1.15), Vector3(-0.35, y, 0.0), blue)
		ModelKit.box(self, Vector3(1.3, 0.08, 1.18), Vector3(-0.35, y + 0.2 * side, 0.0), hull)
		ModelKit.box(self, Vector3(0.22, 0.38, 1.18), Vector3(0.05, y, 0.0), gold)
		ModelKit.prism(self, Vector3(0.36, 0.5, 1.0), Vector3(0.5, y, 0.0), blue_dark, Vector3(0, 0, -90))
		ModelKit.box(self, Vector3(0.5, 0.12, 0.2), Vector3(-0.6, y, 0.62), blue_dark)
		# Engine nacelle, nozzle ring and flame.
		var ey := 0.24 * side
		ModelKit.cylinder(self, 0.19, 0.22, 0.62, Vector3(-1.0, ey, 0.0), metal, Vector3(0, 0, 90))
		ModelKit.cylinder(self, 0.2, 0.2, 0.06, Vector3(-1.33, ey, 0.0), core, Vector3(0, 0, 90))
		var flame := ModelKit.quad(self, Vector2(1.0, 0.34), Vector3(-1.85, ey, 0.05),
				ModelKit.glow(Color(0.45, 0.85, 1.0), 2.2, ModelKit.GlowShape.STREAK))
		_flames.append(flame)

	# Echo core on the camera-facing side: the part that moves into the mech arm.
	ModelKit.sphere(self, 0.17, Vector3(-0.45, 0.0, 0.38), core)
	ModelKit.quad(self, Vector2(0.9, 0.9), Vector3(-0.45, 0.0, 0.45), ModelKit.glow(CORE, 0.9))

	# Tapered afterimage shown only while dashing.
	_dash_streak = ModelKit.quad(self, Vector2(4.0, 1.4), Vector3(-2.4, 0.0, -0.3),
			ModelKit.glow(Color(0.35, 0.75, 1.0), 1.4, ModelKit.GlowShape.STREAK))
	_dash_streak.visible = false


func set_dashing(dashing: bool) -> void:
	if _dash_streak:
		_dash_streak.visible = dashing


## 0 = idle, 1 = cruising forward, >1 = dash burst.
func set_thrust(value: float) -> void:
	_thrust = value


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	for i in _flames.size():
		var flicker := 0.85 + 0.15 * sin(_time * 55.0 + i * 1.7)
		var length := (0.55 + _thrust * 0.75) * flicker
		var flame := _flames[i]
		flame.scale = Vector3(length, 0.8 + 0.2 * flicker, 1.0)
		flame.position.x = -1.36 - length * 0.5
