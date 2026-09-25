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
		&"bolt":
			m = ModelKit.toon(Color("8a9bc2"), 0.5, 0.35, 0.7)
		&"vent":
			m = ModelKit.toon(Color("0b1020"), 0.2, 0.9, 0.2)
		&"status":
			m = ModelKit.emissive(Color("52e07a"), 1.8)
		&"red_light":
			m = ModelKit.emissive(Color("ff3b30"), 2.0)
		_:
			m = ModelKit.toon(Color.MAGENTA)
	_materials[kind] = m
	return m


## Solid block from its top-left corner (x, top) with width/height, facing up (y is up).
## `trim` adds a lit top edge so walkable surfaces read at a glance. `hull_mat` / `light_mat`
## override the body and edge-light materials (per-zone palettes).
static func solid(parent: Node3D, x: float, top: float, width: float, height: float, trim: bool = true,
		hull_mat: Material = null, light_mat: Material = null, trim_mat: Material = null) -> StaticBody3D:
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
	var body_mat := hull_mat if hull_mat else material(&"hull" if trim else &"hull_dark")
	var edge_light := light_mat if light_mat else material(&"light")
	ModelKit.box(body, Vector3(width, height, DEPTH * 0.6), Vector3.ZERO, body_mat)
	if trim:
		ModelKit.box(body, Vector3(width, 0.22, DEPTH * 0.62), Vector3(0, height * 0.5 - 0.11, 0), trim_mat if trim_mat else material(&"trim"))
		ModelKit.box(body, Vector3(width - 0.2, 0.06, 0.05), Vector3(0, height * 0.5 - 0.24, DEPTH * 0.31), edge_light)
	# Panel seams every few units on the camera face (only ~6 units of the face are ever seen:
	# the top of floors, the bottom of ceilings).
	var seam_h := minf(maxf(0.2, height - 0.5), 6.0)
	var seam_y := height * 0.5 - 0.3 - seam_h * 0.5 if trim else -height * 0.5 + 0.3 + seam_h * 0.5
	var seams := int(width / 3.0)
	for i in range(1, seams + 1):
		var sx := -width * 0.5 + i * (width / (seams + 1))
		_detail(ModelKit.box(body, Vector3(0.08, seam_h, 0.04), Vector3(sx, seam_y, DEPTH * 0.31), material(&"hull_dark")))
	if not trim:
		# Ceiling underside: light strips, a pipe run and support brackets.
		var bottom := -height * 0.5
		ModelKit.box(body, Vector3(width, 0.35, DEPTH * 0.64), Vector3(0, bottom + 0.17, 0), material(&"trim"))
		ModelKit.hex_x(body, 0.2, width, Vector3(0, bottom + 1.0, DEPTH * 0.34), material(&"bolt"), 8)
		var lamps := int(width / 4.0)
		for i in lamps:
			var lx := -width * 0.5 + 2.0 + i * 4.0
			_detail(ModelKit.box(body, Vector3(1.4, 0.12, 0.5), Vector3(lx, bottom - 0.02, 0.6), light_mat if light_mat else material(&"warm_light")))
			_detail(ModelKit.box(body, Vector3(0.25, 1.6, 0.1), Vector3(lx + 1.2, bottom + 0.9, DEPTH * 0.33), material(&"hull")))
	if trim:
		# Recessed lip under the walkable edge, bolts along the trim, vent grilles.
		ModelKit.box(body, Vector3(width, 0.3, 0.06), Vector3(0, height * 0.5 - 0.5, DEPTH * 0.31), material(&"hull_dark"))
		if width <= 80.0:
			var bolts := int(width / 1.6)
			for i in bolts:
				_detail(ModelKit.box(body, Vector3(0.12, 0.12, 0.05), Vector3(-width * 0.5 + 0.8 + i * 1.6, height * 0.5 - 0.11, DEPTH * 0.32), material(&"bolt")))
			if height >= 2.5:
				var vents := int(width / 7.0)
				for v in vents:
					var vx := -width * 0.5 + 3.5 + v * 7.0
					for k in 3:
						_detail(ModelKit.box(body, Vector3(1.4, 0.08, 0.05), Vector3(vx, height * 0.5 - 1.2 - k * 0.22, DEPTH * 0.32), material(&"vent")))
					_detail(ModelKit.box(body, Vector3(0.18, 0.18, 0.05), Vector3(vx + 1.0, height * 0.5 - 1.42, DEPTH * 0.32), material(&"status")))
	return body


## Small decorative meshes fade out when the camera is far (keeps big levels cheap).
static func _detail(mesh: MeshInstance3D) -> void:
	mesh.visibility_range_end = 75.0


## Hazard stripe band on the camera face of a block (pit edges, crusher bays).
## Rising steam column (vents, broken pipes).
static func steam(parent: Node3D, at: Vector3, strength: float = 1.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = at
	p.amount = int(14 * strength)
	p.lifetime = 1.8
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 1.5 * strength
	p.initial_velocity_max = 2.8 * strength
	p.gravity = Vector3(0.3, 0.4, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.scale_amount_curve = _grow_curve()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := ModelKit.glow(Color(0.7, 0.8, 0.95), 0.35)
	mat.set_shader_parameter(&"energy", 0.35)
	quad.material = mat
	p.mesh = quad
	p.visibility_aabb = AABB(Vector3(-3, -1, -2), Vector3(6, 7, 4))
	parent.add_child(p)
	return p


## Sparks raining from a damaged conduit.
static func sparks(parent: Node3D, at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = at
	p.amount = 18
	p.lifetime = 0.9
	p.explosiveness = 0.6
	p.direction = Vector3(0.2, -1, 0)
	p.spread = 35.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -18, 0)
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.16
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = ModelKit.emissive(Color(1.0, 0.8, 0.4), 4.0)
	p.mesh = quad
	p.visibility_aabb = AABB(Vector3(-3, -8, -2), Vector3(6, 9, 4))
	parent.add_child(p)
	return p


static func _grow_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 0.3))
	c.add_point(Vector2(1, 1.0))
	return c


static func stripes(parent: Node3D, x: float, y: float, width: float) -> void:
	var count := int(width / 0.7)
	for i in count:
		ModelKit.box(parent, Vector3(0.32, 0.3, 0.05), Vector3(x + 0.35 + i * 0.7, y, DEPTH * 0.32), material(&"stripe"), Vector3(0, 0, 35))
