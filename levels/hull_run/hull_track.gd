class_name HullTrack
extends Node3D
## Stage 3 course on the warship's top hull, authored as a fixed sequence (no procedural
## generation). Forward is +X, the deck top is y = DECK_Y and spans Z ±DECK_HALF.
## Sections: warm-up → blast field → TRENCH RUN (walls + turrets) → burning deck with pads →
## pursuit gunship → the bow, where the bike launches into space.
## Bike reference at ~34 u/s: single jump ≈ 20 wide, double ≈ 32, pads clear ≈ 40.

const GROUP := &"hull_track"
const DECK_Y := 30.0
const DECK_HALF := 9.0
const K := HullObstacle.Kind

@export var enemy_root: Node3D
@export var start_x: float = 300.0
@export var finish_x: float = 2700.0

## Deck spans [x_start, x_end]; gaps between are open to the burning interior.
const DECKS := [
	[300.0, 700.0], [712.0, 980.0], [994.0, 1400.0], [1414.0, 1560.0], [1574.0, 1760.0], [1790.0, 2760.0],
]
const TRENCH := Vector2(1000.0, 1380.0)
const TRENCH_HEIGHT := 12.0

## [kind, x, z, size] — size only for BLOCK (x, y, z) and FENCE (gap z in .z).
const OBSTACLES := [
	# A — warm-up.
	[K.BLOCK, 430.0, -4.5, Vector3(4, 2.4, 7)], [K.BLOCK, 480.0, 4.5, Vector3(4, 2.4, 7)], [K.WALL, 530.0, 0.0],
	[K.VENT, 575.0, -4.0], [K.VENT, 590.0, 4.0], [K.FENCE, 640.0, 0.0, Vector3(0, 0, 5.0)],
	[K.BLOCK, 680.0, -5.5, Vector3(4, 2.4, 6)], [K.BLOCK, 680.0, 5.5, Vector3(4, 2.4, 6)],
	# B — blast field.
	[K.WALL, 760.0, 0.0], [K.BLAST, 805.0, 0.0], [K.BLAST, 835.0, -5.0], [K.BLAST, 850.0, 5.0],
	[K.FENCE, 900.0, 0.0, Vector3(0, 0, -5.0)], [K.VENT, 945.0, -6.0], [K.VENT, 945.0, 0.0], [K.VENT, 945.0, 6.0],
	# C — trench run.
	[K.BLOCK, 1060.0, 4.0, Vector3(4, 2.8, 9)], [K.BLOCK, 1120.0, -4.0, Vector3(4, 2.8, 9)], [K.BLOCK, 1180.0, 4.0, Vector3(4, 2.8, 9)],
	[K.FENCE, 1250.0, 0.0, Vector3(0, 0, 0.0)], [K.WALL, 1330.0, 0.0], [K.FENCE, 1370.0, 0.0, Vector3(0, 0, 5.5)],
	# D — burning deck.
	[K.BLAST, 1440.0, -4.0], [K.BLAST, 1455.0, 4.0], [K.VENT, 1500.0, 0.0], [K.BLOCK, 1530.0, -5.0, Vector3(4, 2.4, 7)],
	[K.PAD, 1552.0, 0.0], [K.REPAIR, 1610.0, 0.0], [K.BLAST, 1660.0, 0.0], [K.BLOCK, 1700.0, 5.0, Vector3(4, 2.4, 7)],
	[K.PAD, 1754.0, 0.0],
	# E — gunship chase.
	[K.BLOCK, 1900.0, -5.0, Vector3(4, 2.4, 7)], [K.BLOCK, 2050.0, 5.0, Vector3(4, 2.4, 7)], [K.WALL, 2120.0, 0.0],
	[K.BLOCK, 2200.0, 0.0, Vector3(4, 2.4, 6)], [K.WALL, 2300.0, 0.0], [K.REPAIR, 2350.0, 0.0],
	[K.FENCE, 2420.0, 0.0, Vector3(0, 0, -5.0)], [K.FENCE, 2480.0, 0.0, Vector3(0, 0, 5.0)],
	[K.BLAST, 2560.0, -4.0], [K.BLAST, 2580.0, 4.0],
]

## Orb lines: [x_start, z, count, arc_height]
const ORBS := [
	[360.0, 0.0, 6, 0.0], [505.0, 0.0, 5, 3.0], [700.0, 0.0, 6, 4.0], [870.0, -5.0, 5, 0.0],
	[1020.0, -4.0, 6, 0.0], [1200.0, 0.0, 6, 0.0], [1400.0, 0.0, 6, 4.0], [1560.0, 0.0, 6, 5.0],
	[1760.0, 0.0, 8, 7.0], [2150.0, 0.0, 6, 0.0], [2620.0, 0.0, 8, 0.0],
]

## Turrets: [x, z, y_offset]
const TURRETS := [
	[1040.0, -7.6, 5.0], [1100.0, 7.6, 5.0], [1160.0, -7.6, 5.0], [1230.0, 7.6, 5.0], [1300.0, -7.6, 5.0],
	[1480.0, -8.0, 1.0], [1640.0, 8.0, 1.0], [2250.0, -8.0, 1.0],
]

var _chase_lights: Array[StandardMaterial3D] = []
var _time: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if enemy_root == null:
		push_error("HullTrack: enemy_root must be assigned.")
		return
	for k in 4:
		_chase_lights.append(ModelKit.emissive(Palette.PLAYER_ENERGY, 1.0))
	for d: Array in DECKS:
		_build_deck(d[0], d[1])
	_build_trench()
	_build_bow()
	for o: Array in OBSTACLES:
		var obstacle := HullObstacle.new()
		obstacle.kind = o[0]
		obstacle.position = Vector3(o[1], DECK_Y, o[2])
		obstacle.deck_half_width = DECK_HALF
		if o.size() > 3:
			obstacle.size = o[3]
		add_child(obstacle)
	for line: Array in ORBS:
		for i in int(line[2]):
			var t := float(i) / maxf(1.0, float(line[2]) - 1.0)
			var orb := HullObstacle.new()
			orb.kind = K.ORB
			orb.position = Vector3(line[0] + i * 3.0, DECK_Y + 1.2 + sin(t * PI) * line[3], line[1])
			add_child(orb)
	for t: Array in TURRETS:
		var turret := RunTurret.new()
		turret.position = Vector3(t[0], DECK_Y + t[2], t[1]) - enemy_root.global_position
		enemy_root.add_child(turret)


## Where the bike goes back after a fall at x: a little way onto the next deck ahead.
func recovery_point(x: float, _z: float = 0.0) -> Vector3:
	for d: Array in DECKS:
		if x < d[1] - 12.0:
			return Vector3(maxf(x, d[0] + 6.0), DECK_Y + 0.6, 0.0)
	return Vector3(x, DECK_Y + 0.6, 0.0)


func deck_at(x: float) -> bool:
	for d: Array in DECKS:
		if x >= d[0] and x <= d[1]:
			return true
	return false


func _build_deck(x0: float, x1: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.position = Vector3((x0 + x1) * 0.5, DECK_Y - 2.0, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, 4.0, DECK_HALF * 2.0 + 4.0)
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	var plate := ModelKit.toon(Color("2a3754"), 0.35, 0.65, 0.45)
	var plate_b := ModelKit.toon(Color("24304a"), 0.3, 0.7, 0.4)
	var seam := ModelKit.toon(Color("121a2b"), 0.2, 0.9, 0.2)
	var rail := ModelKit.hull(Color("3d4a66"), ArtStyle.OUTLINE_THIN, 0.4)
	var side := ModelKit.toon(Color("1b2438"), 0.3, 0.75, 0.35)
	var stripe := ModelKit.toon(Palette.INTERACTABLE.darkened(0.25), 0.3, 0.6, 0.2)
	var warm := ModelKit.emissive(Color("ffc46b"), 1.2)
	var chunk := 20.0
	var x := x0
	var index := 0
	while x < x1:
		var len := minf(chunk, x1 - x)
		var node := Node3D.new()
		node.position = Vector3(x + len * 0.5, DECK_Y, 0)
		add_child(node)
		# Plating in two tones with cross seams and dashed lane lines.
		_d(ModelKit.box(node, Vector3(len, 0.4, DECK_HALF * 2.0), Vector3(0, -0.2, 0), plate if index % 2 == 0 else plate_b))
		for sx in range(0, int(len), 4):
			_d(ModelKit.box(node, Vector3(0.08, 0.02, DECK_HALF * 2.0), Vector3(-len * 0.5 + sx, 0.01, 0), seam))
		for lz: float in [-3.0, 3.0]:
			_d(ModelKit.box(node, Vector3(len * 0.45, 0.02, 0.25), Vector3(0, 0.02, lz), stripe))
		# Edge rails with racing lights.
		for sgn: float in [-1.0, 1.0]:
			_d(ModelKit.box(node, Vector3(len, 0.6, 0.6), Vector3(0, 0.3, sgn * (DECK_HALF + 0.3)), rail))
			for li in 4:
				_d(ModelKit.box(node, Vector3(1.6, 0.12, 0.1), Vector3(-len * 0.5 + 2.5 + li * 5.0, 0.45, sgn * (DECK_HALF - 0.02)), _chase_lights[li]))
			# Sloped hull side falling away from the deck, with lit windows.
			_d(ModelKit.box(node, Vector3(len, 10.0, 0.8), Vector3(0, -4.0, sgn * (DECK_HALF + 3.6)), side, Vector3(sgn * 35.0, 0, 0)))
			if index % 2 == 0:
				for w in 4:
					_d(ModelKit.box(node, Vector3(1.2, 0.3, 0.1), Vector3(-len * 0.5 + 2.0 + w * 5.0, -3.0, sgn * (DECK_HALF + 3.0)), warm, Vector3(sgn * 35.0, 0, 0)))
		_superstructure(node, x, len, index)
		x += len
		index += 1
	# Gap glow: the burning interior shows through the break after this deck.
	var fire := ModelKit.group(self, "GapFire", Vector3(x1 + 7.0, DECK_Y - 5.0, 0))
	var glow := MeshInstance3D.new()
	glow.mesh = QuadMesh.new()
	glow.material_override = ModelKit.glow_billboard(Color(1.0, 0.45, 0.15), 1.4)
	glow.scale = Vector3(14.0, 6.0, 1.0)
	fire.add_child(glow)
	_embers(fire)


## Towers, domes, antennae and gun emplacements alongside the deck (some burning).
func _superstructure(node: Node3D, x: float, len: float, index: int) -> void:
	var hull := ModelKit.toon(Color("1f2940"), 0.35, 0.7, 0.4)
	var hull_b := ModelKit.toon(Color("161e31"), 0.3, 0.75, 0.35)
	var lights := ModelKit.emissive(Color("ff9f4a"), 1.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x) * 13 + 7
	for sgn: float in [-1.0, 1.0]:
		var kind := rng.randi() % 5
		var z := sgn * rng.randf_range(15.0, 26.0)
		var lx := rng.randf_range(-len * 0.3, len * 0.3)
		match kind:
			0:
				var h := rng.randf_range(6.0, 16.0)
				_d(ModelKit.box(node, Vector3(6.0, h, 6.0), Vector3(lx, h * 0.5 - 4.0, z), hull), 320.0)
				_d(ModelKit.box(node, Vector3(6.4, 0.5, 6.4), Vector3(lx, h - 4.0, z), hull_b), 320.0)
				for w in int(h / 2.0):
					_d(ModelKit.box(node, Vector3(0.1, 0.3, 4.0), Vector3(lx - 3.05, w * 2.0 - 3.0, z), lights), 320.0)
			1:
				_d(ModelKit.sphere(node, 4.0, Vector3(lx, -2.0, z), hull, Vector3(1, 0.6, 1)), 320.0)
			2:
				_d(ModelKit.box(node, Vector3(0.4, 14.0, 0.4), Vector3(lx, 3.0, z), hull_b), 320.0)
				_d(ModelKit.box(node, Vector3(3.0, 0.2, 0.3), Vector3(lx, 8.0, z), hull_b), 320.0)
				_d(ModelKit.sphere(node, 0.3, Vector3(lx, 10.2, z), LevelKit.material(&"red_light")), 320.0)
			3:
				_d(ModelKit.cylinder(node, 2.2, 2.6, 1.6, Vector3(lx, 0.0, z), hull_b, Vector3.ZERO, 10), 320.0)
				_d(ModelKit.hex_x(node, 0.35, 6.0, Vector3(lx - 3.0, 1.2, z), hull, 8), 320.0)
			_:
				pass
		if index % 3 == 1 and kind != 4:
			var smoke_at := Vector3(lx, 4.0, z)
			_embers(node, smoke_at)


func _build_trench() -> void:
	var wall := ModelKit.toon(Color("202b45"), 0.35, 0.7, 0.4)
	var inset := ModelKit.toon(Color("2a3858"), 0.4, 0.6, 0.45)
	var pipe := ModelKit.toon(Color("33415f"), 0.45, 0.5, 0.6)
	var x := TRENCH.x
	var index := 0
	while x < TRENCH.y:
		var len := minf(20.0, TRENCH.y - x)
		var node := Node3D.new()
		node.position = Vector3(x + len * 0.5, DECK_Y, 0)
		add_child(node)
		for sgn: float in [-1.0, 1.0]:
			var wz := sgn * (DECK_HALF + 0.8)
			var body := StaticBody3D.new()
			body.collision_layer = PhysicsLayers.WORLD
			body.position = Vector3(0, TRENCH_HEIGHT * 0.5, wz)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(len, TRENCH_HEIGHT, 1.2)
			shape.shape = box
			body.add_child(shape)
			node.add_child(body)
			_d(ModelKit.box(node, Vector3(len, TRENCH_HEIGHT, 1.2), Vector3(0, TRENCH_HEIGHT * 0.5, wz), wall))
			for py: float in [2.5, 6.5, 10.0]:
				_d(ModelKit.box(node, Vector3(len - 1.0, 2.6, 0.2), Vector3(0, py, wz - sgn * 0.7), inset))
			_d(ModelKit.hex_x(node, 0.3, len, Vector3(0, 4.5, wz - sgn * 0.9), pipe, 8))
			_d(ModelKit.hex_x(node, 0.22, len, Vector3(0, 8.6, wz - sgn * 0.9), pipe, 8))
			for li in 4:
				_d(ModelKit.box(node, Vector3(1.4, 0.2, 0.1), Vector3(-len * 0.5 + 2.5 + li * 5.0, 1.4, wz - sgn * 0.85), _chase_lights[(li + index) % 4]))
		x += len
		index += 1


func _build_bow() -> void:
	# The deck's end: a raised launch lip and a finish arch of lights.
	var metal := ModelKit.hull(Color("3d4a66"))
	var ramp := ModelKit.group(self, "Bow", Vector3(2745.0, DECK_Y, 0))
	_d(ModelKit.prism(ramp, Vector3(12.0, 2.0, DECK_HALF * 2.0), Vector3(0, 1.0, 0), metal), 400.0)
	var arch := ModelKit.group(self, "FinishArch", Vector3(finish_x, DECK_Y, 0))
	for sgn: float in [-1.0, 1.0]:
		_d(ModelKit.box(arch, Vector3(0.8, 10.0, 0.8), Vector3(0, 5.0, sgn * (DECK_HALF + 1.0)), metal), 400.0)
	_d(ModelKit.box(arch, Vector3(1.0, 1.0, DECK_HALF * 2.0 + 3.0), Vector3(0, 10.2, 0), metal), 400.0)
	for i in 10:
		_d(ModelKit.box(arch, Vector3(1.04, 0.6, 1.2), Vector3(0, 10.2, -DECK_HALF + i * 2.0), ModelKit.emissive(Color.WHITE if i % 2 == 0 else Palette.PLAYER_ENERGY, 2.4)), 400.0)


func _embers(parent: Node3D, at: Vector3 = Vector3.ZERO) -> void:
	var p := CPUParticles3D.new()
	p.position = at
	p.amount = 16
	p.lifetime = 2.2
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(-2.0, 1.0, 0)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.8
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.6, 0.2, 0.9))
	ramp.add_point(0.35, Color(0.35, 0.15, 0.1, 0.6))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.08, 0.07, 0.09, 0.0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.material = Explosion3D._particle_material(Color(1, 1, 1, 1), BaseMaterial3D.BLEND_MODE_MIX)
	p.mesh = quad
	p.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 20, 16))
	parent.add_child(p)


## Culls decoration beyond range so a 2.5 km deck stays cheap.
func _d(mesh: MeshInstance3D, range_end: float = 260.0) -> MeshInstance3D:
	mesh.visibility_range_end = range_end
	for child in mesh.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).visibility_range_end = range_end
	return mesh


func _process(delta: float) -> void:
	_time += delta
	# Lights race forward along the rails.
	for i in _chase_lights.size():
		var phase := fmod(_time * 6.0 - i, 4.0)
		_chase_lights[i].emission_energy_multiplier = 3.0 if phase < 1.0 else 0.35
