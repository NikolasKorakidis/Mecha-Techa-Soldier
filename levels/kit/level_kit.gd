class_name LevelKit
extends RefCounted
## Builders for platformer geometry: solid hull blocks with collision and chunk-tech visuals.
## Solids span Z = -2..2 so bodies on the Z = 0 plane can never slip off.

const DEPTH := 4.0

static var _materials: Dictionary = {}


static func material(kind: StringName) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	var m: Material
	match kind:
		&"hull":
			m = ModelKit.toon(Color("2e3f63"), 0.4, 0.65, 0.45)
		&"hull_dark":
			m = ModelKit.toon(Color("151e33"), 0.3, 0.7, 0.4)
		&"trim":
			m = ModelKit.toon(Color("6a7fae"), 0.5, 0.45, 0.5)
		&"stripe":
			m = ModelKit.toon(Palette.INTERACTABLE.darkened(0.1), 0.3, 0.5, 0.2)
		&"light":
			m = ModelKit.emissive(Palette.PLAYER_ENERGY, 1.6)
		&"warm_light":
			m = ModelKit.emissive(Color("ff9f4a"), 1.4)
		_:
			m = ModelKit.toon(Color.MAGENTA)
	_materials[kind] = m
	return m


## Solid block from its top-left corner (x, top) with width/height, facing up (y is up).
## `trim` adds a lit top edge so walkable surfaces read at a glance.
static func solid(parent: Node3D, x: float, top: float, width: float, height: float, trim: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.position = Vector3(x + width * 0.5, top - height * 0.5, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, DEPTH)
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	ModelKit.box(body, Vector3(width, height, DEPTH * 0.6), Vector3.ZERO, material(&"hull" if trim else &"hull_dark"))
	if trim:
		ModelKit.box(body, Vector3(width, 0.22, DEPTH * 0.62), Vector3(0, height * 0.5 - 0.11, 0), material(&"trim"))
		ModelKit.box(body, Vector3(width - 0.2, 0.06, 0.05), Vector3(0, height * 0.5 - 0.24, DEPTH * 0.31), material(&"light"))
	# Panel seams every few units on the camera face.
	var seams := int(width / 3.0)
	for i in range(1, seams + 1):
		var sx := -width * 0.5 + i * (width / (seams + 1))
		ModelKit.box(body, Vector3(0.08, maxf(0.2, height - 0.5), 0.04), Vector3(sx, -0.1, DEPTH * 0.31), material(&"hull_dark"))
	return body


## Hazard stripe band on the camera face of a block (pit edges, crusher bays).
static func stripes(parent: Node3D, x: float, y: float, width: float) -> void:
	var count := int(width / 0.7)
	for i in count:
		ModelKit.box(parent, Vector3(0.32, 0.3, 0.05), Vector3(x + 0.35 + i * 0.7, y, DEPTH * 0.32), material(&"stripe"), Vector3(0, 0, 35))
