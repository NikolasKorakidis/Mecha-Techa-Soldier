class_name WarshipModel
extends Node3D
## The enemy capital ship VX-07 as one hero model: a lofted dagger hull (flat dorsal deck, sloped
## armour belts, keel), command tower, gun batteries, radar, midship fins, engine block with
## blue plumes, hangar glow and thousands of lit windows (MultiMesh). Authored along +X with
## the bow at x = +LENGTH/2 and the dorsal deck at y = 0; scale the node to fit each use:
## Stage 1 backdrop (small, far), Stage 3 (the hull you ride on) and the ending (it blows apart).
## The hull is split into SECTIONS so destroy() can break it into drifting pieces.

signal destroyed

const LENGTH := 1000.0
const SECTION_BOUNDS: Array[float] = [-500.0, -240.0, 20.0, 260.0, 500.0]
## Hull stations: [x, half beam, depth].
const STATIONS := [
	[-500.0, 78.0, 58.0], [-470.0, 94.0, 68.0], [-380.0, 104.0, 72.0], [-200.0, 108.0, 68.0],
	[0.0, 98.0, 60.0], [150.0, 80.0, 50.0], [300.0, 52.0, 38.0], [420.0, 24.0, 22.0], [500.0, 4.0, 7.0],
]

@export var hull_color: Color = Color("18213a")
@export var deck_color: Color = Color("192238")
@export var keel_color: Color = Color("121a2c")
@export var window_color: Color = Color("ffc46b")
@export var engine_color: Color = Color("5fc4ff")
## Fewer props/windows (distant backdrop copies).
@export var low_detail: bool = false
## Keep |z| below this free of dorsal props (Stage 3 races down the centreline).
@export var clear_lane: float = 0.0
## Base size of destroy() blasts in local units (raise it when the camera watches from far away).
@export var explosion_scale: float = 8.0

var sections: Array[Node3D] = []

var _blinkers: Array[StandardMaterial3D] = []
var _dishes: Array[Node3D] = []
var _turrets: Array[Node3D] = []
var _plumes: Array[MeshInstance3D] = []
var _fires: Array[Node3D] = []
var _time: float = 0.0
var _destroying: bool = false
var _drift: Array[Vector3] = []
var _spin: Array[Vector3] = []
var _destroy_time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _hull_mat: StandardMaterial3D
var _deck_mat: StandardMaterial3D
var _keel_mat: StandardMaterial3D
var _dark_mat: StandardMaterial3D
var _trim_mat: StandardMaterial3D
var _window_mat: StandardMaterial3D
var _cool_mat: StandardMaterial3D
## White toon material tinted per instance (MultiMesh colours) for varied plating.
var _tint_mat: StandardMaterial3D
const PLATE_TONES: Array[Color] = [Color("222c47"), Color("1b2339"), Color("2b3757"), Color("141b2d"), Color("323f60")]


func _ready() -> void:
	_rng.seed = 707
	_hull_mat = _mat(hull_color, 0.35)
	_deck_mat = _mat(deck_color, 0.3)
	_keel_mat = _mat(keel_color, 0.25)
	_dark_mat = _mat(hull_color.darkened(0.35), 0.25)
	_trim_mat = _mat(deck_color.lightened(0.18), 0.45)
	_window_mat = ModelKit.emissive(window_color, 1.6)
	_cool_mat = ModelKit.emissive(Color("9fe4ff"), 1.8)
	_tint_mat = _mat(Color.WHITE, 0.3)
	_tint_mat.vertex_color_use_as_albedo = true
	for i in SECTION_BOUNDS.size() - 1:
		var section := ModelKit.group(self, "Section%d" % i)
		sections.append(section)
		_build_hull(section, SECTION_BOUNDS[i], SECTION_BOUNDS[i + 1])
	_build_deck_detail()
	_build_windows()
	# Asymmetric islands off the centreline (a runway stays open down the spine).
	_build_tower(_section_at(-380.0), Vector3(-380.0, 0, 42.0))
	_build_tower(_section_at(-90.0), Vector3(-90.0, 0, -50.0), 0.6)
	_build_city()
	_build_batteries()
	_build_fins()
	_build_engines()
	_build_hangars()
	_build_running_lights()


# --- Queries -------------------------------------------------------------------------------

## Half beam and depth of the hull at local x.
static func profile(x: float) -> Vector2:
	for i in STATIONS.size() - 1:
		var a: Array = STATIONS[i]
		var b: Array = STATIONS[i + 1]
		if x <= b[0]:
			var t := clampf((x - a[0]) / (b[0] - a[0]), 0.0, 1.0)
			return Vector2(lerpf(a[1], b[1], t), lerpf(a[2], b[2], t))
	return Vector2(STATIONS[-1][1], STATIONS[-1][2])


## Random point on the hull surface (local), for explosions and fires.
func random_surface_point(x_min: float = -480.0, x_max: float = 480.0) -> Vector3:
	var x := _rng.randf_range(x_min, x_max)
	var p := profile(x)
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	match _rng.randi() % 3:
		0:
			return Vector3(x, 0.5, _rng.randf_range(-0.7, 0.7) * p.x)
		1:
			return Vector3(x, -0.28 * p.y, side * p.x)
		_:
			return Vector3(x, -0.6 * p.y, side * p.x * 0.74)


# --- Destruction ---------------------------------------------------------------------------

## Adds a burning hull breach (glow + embers) at a local point. Cheap; used while it is dying.
func add_fire(local: Vector3, size: float = 1.0) -> void:
	var section := _section_at(local.x)
	var fire := Node3D.new()
	fire.position = local - section.position
	section.add_child(fire)
	var glow := MeshInstance3D.new()
	glow.mesh = QuadMesh.new()
	glow.material_override = ModelKit.glow_billboard(Color(1.0, 0.45, 0.15), 2.4)
	glow.scale = Vector3.ONE * 18.0 * size
	fire.add_child(glow)
	var core := MeshInstance3D.new()
	core.mesh = QuadMesh.new()
	core.material_override = ModelKit.glow_billboard(Color(1.0, 0.85, 0.5), 2.0)
	core.scale = Vector3.ONE * 5.0 * size
	fire.add_child(core)
	_fires.append(fire)


## Chain explosions stern to bow, the sections tear apart and drift, a final core flash.
## Explosions spawn into the level's vfx root in world space, so this needs a live level.
func destroy(duration: float = 5.0) -> void:
	if _destroying:
		return
	_destroying = true
	_destroy_time = 0.0
	for i in sections.size():
		var outward := (float(i) - 1.5) * 8.0
		_drift.append(Vector3(outward + _rng.randf_range(-4, 4), _rng.randf_range(-22, -8) - i * 3.0, _rng.randf_range(-16, 16)))
		_spin.append(Vector3(_rng.randf_range(-0.08, 0.08), _rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.1, 0.1)))
	var world_scale := global_transform.basis.get_scale().x
	var steps := int(duration / 0.06)
	for n in steps:
		if not is_inside_tree():
			return
		var t := float(n) / float(steps)
		var x := lerpf(-480.0, 480.0, t) + _rng.randf_range(-60.0, 60.0)
		var local := random_surface_point(clampf(x - 40.0, -490.0, 490.0), clampf(x + 40.0, -490.0, 490.0))
		Explosion3D.spawn(get_tree(), to_global(local), _rng.randf_range(explosion_scale * 0.6, explosion_scale * 1.2) * world_scale, 0.0)
		if n % 4 == 0:
			add_fire(local, _rng.randf_range(0.6, 1.4))
		await get_tree().create_timer(0.06, false).timeout
	if not is_inside_tree():
		return
	for i in sections.size():
		var mid := (SECTION_BOUNDS[i] + SECTION_BOUNDS[i + 1]) * 0.5
		Explosion3D.spawn(get_tree(), to_global(Vector3(mid, -20.0, 0.0)), explosion_scale * 3.0 * world_scale, 0.3)
	destroyed.emit()


# --- Hull ----------------------------------------------------------------------------------

func _build_hull(section: Node3D, x0: float, x1: float) -> void:
	var xs: Array[float] = [x0]
	for s: Array in STATIONS:
		if s[0] > x0 and s[0] < x1:
			xs.append(s[0])
	xs.append(x1)
	# Extra rings so the loft follows the profile smoothly.
	var dense: Array[float] = []
	for i in xs.size() - 1:
		var steps := maxi(1, int((xs[i + 1] - xs[i]) / 40.0))
		for k in steps:
			dense.append(lerpf(xs[i], xs[i + 1], float(k) / steps))
	dense.append(x1)
	var rings: Array[PackedVector3Array] = []
	for x in dense:
		rings.append(_ring(x))
	# Surfaces: 0 = deck (edge 0), 1-3 and 5-7 = armour sides, 4 = keel.
	var deck := SurfaceTool.new()
	var sides := SurfaceTool.new()
	var keel := SurfaceTool.new()
	for st: SurfaceTool in [deck, sides, keel]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)
	for i in rings.size() - 1:
		var a := rings[i]
		var b := rings[i + 1]
		for j in 8:
			var k := (j + 1) % 8
			var st := deck if j == 0 else (keel if j == 4 else sides)
			_quad(st, a[j], a[k], b[k], b[j])
	# Caps at the ends of the whole hull.
	if is_equal_approx(x0, SECTION_BOUNDS[0]):
		_cap(sides, rings[0], true)
	if is_equal_approx(x1, SECTION_BOUNDS[-1]):
		_cap(sides, rings[-1], false)
	var mesh := ArrayMesh.new()
	for pair: Array in [[deck, _deck_mat], [sides, _hull_mat], [keel, _keel_mat]]:
		var st: SurfaceTool = pair[0]
		st.generate_normals()
		st.set_material(pair[1])
		st.commit(mesh)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	section.add_child(inst)
	# Armour belt ridge along the widest line, plus a darker lower belt.
	var mid := (x0 + x1) * 0.5
	var len := x1 - x0
	var p := profile(mid)
	for side: float in [-1.0, 1.0]:
		var belt := ModelKit.box(section, Vector3(len, 3.0, 2.0), Vector3(mid, -0.28 * p.y, side * p.x), _trim_mat)
		belt.rotation.y = -side * atan2(profile(x1).x - profile(x0).x, len)
		ModelKit.box(section, Vector3(len * 0.96, 1.2, 1.4), Vector3(mid, -0.62 * p.y + 3.0, side * p.x * 0.74), _dark_mat).rotation.y = belt.rotation.y


func _ring(x: float) -> PackedVector3Array:
	var p := profile(x)
	var w := p.x
	var d := p.y
	return PackedVector3Array([
		Vector3(x, 0.0, -0.78 * w), Vector3(x, 0.0, 0.78 * w), Vector3(x, -0.28 * d, w), Vector3(x, -0.62 * d, 0.72 * w),
		Vector3(x, -d, 0.3 * w), Vector3(x, -d, -0.3 * w), Vector3(x, -0.62 * d, -0.72 * w), Vector3(x, -0.28 * d, -w),
	])


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# Godot front faces wind clockwise seen from outside.
	for v in [a, c, b, a, d, c]:
		st.add_vertex(v)


func _cap(st: SurfaceTool, ring: PackedVector3Array, stern: bool) -> void:
	var center := Vector3.ZERO
	for v in ring:
		center += v
	center /= ring.size()
	for j in ring.size():
		var k := (j + 1) % ring.size()
		if stern:
			for v in [center, ring[j], ring[k]]:
				st.add_vertex(v)
		else:
			for v in [center, ring[k], ring[j]]:
				st.add_vertex(v)


# --- Detail --------------------------------------------------------------------------------

## Deck plating: raised panels, vents and trenches in a seeded pattern (MultiMesh per section).
func _build_deck_detail() -> void:
	var count := 300 if low_detail else 1400
	var panels: Array = []
	var tones: Array = []
	for i in sections.size():
		panels.append([])
		tones.append(PackedColorArray())
	for n in count:
		var x := _rng.randf_range(-470.0, 470.0)
		var w := profile(x).x * 0.74
		var z := _rng.randf_range(-w, w)
		var size := Vector3(_rng.randf_range(8.0, 30.0), _rng.randf_range(0.4, 2.2), _rng.randf_range(4.0, 14.0))
		if absf(z) + size.z * 0.5 > w:
			continue
		if absf(z) - size.z * 0.5 < clear_lane:
			size.y = minf(size.y, 0.3)
		panels[_section_index(x)].append(Transform3D(Basis.from_scale(size), Vector3(x, size.y * 0.5, z)))
		tones[_section_index(x)].append(PLATE_TONES[_rng.randi() % PLATE_TONES.size()])
	for i in sections.size():
		_multimesh(sections[i], panels[i], _tint_mat, BoxMesh.new(), tones[i])
	# Long dorsal trenches (the kind you race down) with lights.
	for side: float in [-1.0, 1.0]:
		for i in sections.size():
			var x0 := SECTION_BOUNDS[i] + 10.0
			var x1 := SECTION_BOUNDS[i + 1] - 10.0
			var z := side * profile((x0 + x1) * 0.5).x * 0.42
			ModelKit.box(sections[i], Vector3(x1 - x0, 0.6, 3.0), Vector3((x0 + x1) * 0.5, 0.3, z), _keel_mat)


func _build_windows() -> void:
	var count := 700 if low_detail else 3200
	var warm: Array = []
	var cool: Array = []
	for i in sections.size():
		warm.append([])
		cool.append([])
	for n in count:
		var x := _rng.randf_range(-490.0, 460.0)
		var p := profile(x)
		var side := -1.0 if n % 2 == 0 else 1.0
		# Rows between the belt and the lower chine, following the slope.
		var row := _rng.randi() % 6
		var t := 0.05 + row * 0.1
		var y := -lerpf(0.02, 0.26, t / 0.6) * p.y if row < 3 else -lerpf(0.33, 0.58, (t - 0.3) / 0.3) * p.y
		var z := side * (p.x * (lerpf(0.8, 1.0, clampf(-y / (0.28 * p.y), 0.0, 1.0)) if row < 3 else lerpf(1.0, 0.74, clampf((-y - 0.28 * p.y) / (0.34 * p.y), 0.0, 1.0))) + 0.25)
		var xf := Transform3D(Basis.from_scale(Vector3(_rng.randf_range(2.0, 6.0), 0.8, 0.3)), Vector3(x, y, z))
		(cool if _rng.randf() < 0.18 else warm)[_section_index(x)].append(xf)
	var box := BoxMesh.new()
	for i in sections.size():
		_multimesh(sections[i], warm[i], _window_mat, box)
		_multimesh(sections[i], cool[i], _cool_mat, box)


## Superstructure "city": blocks, domes and ridges clustered off the centreline, taller near
## the islands, so the dorsal skyline reads from any angle.
func _build_city() -> void:
	var count := 40 if low_detail else 150
	var blocks: Array = []
	var block_tones: Array = []
	var domes: Array = []
	for i in sections.size():
		blocks.append([])
		block_tones.append(PackedColorArray())
		domes.append([])
	var lane := maxf(clear_lane, 14.0)
	for n in count:
		var x := _rng.randf_range(-460.0, 380.0)
		var w := profile(x).x * 0.72
		if w < lane + 8.0:
			continue
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var z := side * _rng.randf_range(lane + 4.0, w)
		# Low near the spine so the view from it stays open; taller toward the flanks and islands.
		var reach := clampf((absf(z) - lane) / 40.0, 0.15, 1.0)
		var h := _rng.randf_range(2.0, 10.0) * reach * (1.8 if absf(x + 380.0) < 80.0 or absf(x + 90.0) < 60.0 else 1.0)
		var size := Vector3(_rng.randf_range(8.0, 26.0), h, _rng.randf_range(6.0, 18.0))
		if absf(z) + size.z * 0.5 > w:
			continue
		if _rng.randf() < 0.18:
			domes[_section_index(x)].append(Transform3D(Basis.from_scale(Vector3(size.z, size.z * 0.5, size.z)), Vector3(x, 0.0, z)))
		else:
			var tone := PLATE_TONES[_rng.randi() % PLATE_TONES.size()]
			blocks[_section_index(x)].append(Transform3D(Basis.from_scale(size), Vector3(x, h * 0.5, z)))
			block_tones[_section_index(x)].append(tone)
			# Cap slab per block.
			blocks[_section_index(x)].append(Transform3D(Basis.from_scale(Vector3(size.x + 1.0, 0.8, size.z + 1.0)), Vector3(x, h, z)))
			block_tones[_section_index(x)].append(tone.lightened(0.25))
	var sphere := SphereMesh.new()
	sphere.radial_segments = 12
	sphere.rings = 6
	for i in sections.size():
		_multimesh(sections[i], blocks[i], _tint_mat, BoxMesh.new(), block_tones[i])
		_multimesh(sections[i], domes[i], _trim_mat, sphere)


## Stepped command tower with bridge windows, antenna array and radar dishes.
func _build_tower(section: Node3D, at: Vector3, s: float = 1.0) -> void:
	var tower := ModelKit.group(section, "Tower", at - section.position)
	tower.scale = Vector3.ONE * s
	var widths := [70.0, 54.0, 40.0, 30.0]
	var y := 0.0
	for k in widths.size():
		var w: float = widths[k]
		var h := 22.0 - k * 2.0
		ModelKit.box(tower, Vector3(w, h, 34.0 - k * 5.0), Vector3(-k * 4.0, y + h * 0.5, 0), _hull_mat if k % 2 == 0 else _dark_mat)
		ModelKit.box(tower, Vector3(w + 1.0, 1.2, 35.0 - k * 5.0), Vector3(-k * 4.0, y + h, 0), _trim_mat)
		if not low_detail:
			for side: float in [-1.0, 1.0]:
				ModelKit.box(tower, Vector3(w * 0.8, 1.0, 0.4), Vector3(-k * 4.0, y + h * 0.6, side * (17.0 - k * 2.5 + 0.2)), _window_mat)
		y += h
	# Bridge: wide wings with a cool window band.
	ModelKit.box(tower, Vector3(22.0, 7.0, 56.0), Vector3(-12.0, y + 3.5, 0), _dark_mat)
	ModelKit.box(tower, Vector3(22.4, 1.6, 56.4), Vector3(-12.0, y + 4.2, 0), _cool_mat)
	for az: float in [-10.0, 0.0, 8.0]:
		ModelKit.box(tower, Vector3(1.0, 30.0 + az, 1.0), Vector3(-16.0, y + 20.0 + az * 0.5, az), _trim_mat)
		var blink := ModelKit.emissive(Palette.DANGER, 2.0)
		_blinkers.append(blink)
		ModelKit.sphere(tower, 1.2, Vector3(-16.0, y + 35.0 + az, az), blink)
	for dz: float in [-24.0, 24.0]:
		var dish := ModelKit.group(tower, "Dish", Vector3(10.0, y, dz))
		ModelKit.box(dish, Vector3(2.0, 10.0, 2.0), Vector3(0, 5.0, 0), _trim_mat)
		var head := ModelKit.group(dish, "Head", Vector3(0, 11.0, 0))
		ModelKit.cylinder(head, 8.0, 2.5, 3.0, Vector3.ZERO, _hull_mat, Vector3(0, 0, 70), 16)
		_dishes.append(head)


## Twin-barrel batteries along both deck edges.
func _build_batteries() -> void:
	var xs := [-300.0, -220.0, -140.0, 40.0, 120.0, 200.0, 280.0]
	if low_detail:
		xs = [-220.0, 40.0, 200.0]
	for x: float in xs:
		for side: float in [-1.0, 1.0]:
			var section := _section_at(x)
			var z := side * profile(x).x * 0.62
			var turret := ModelKit.group(section, "Battery", Vector3(x, 0, z) - section.position)
			ModelKit.cylinder(turret, 7.0, 8.5, 4.0, Vector3(0, 2.0, 0), _dark_mat, Vector3.ZERO, 12)
			var head := ModelKit.group(turret, "Head", Vector3(0, 6.0, 0))
			ModelKit.box(head, Vector3(12.0, 5.0, 10.0), Vector3.ZERO, _hull_mat)
			ModelKit.box(head, Vector3(12.4, 0.8, 10.4), Vector3(0, 2.6, 0), _trim_mat)
			for bz: float in [-2.4, 2.4]:
				ModelKit.hex_x(head, 1.0, 18.0, Vector3(14.0, 0.6, bz), _trim_mat, 8)
			head.rotation.y = side * 0.3
			_turrets.append(head)


## Midship fins and a dorsal spine fin behind the tower.
func _build_fins() -> void:
	for side: float in [-1.0, 1.0]:
		var section := _section_at(-120.0)
		var fin := ModelKit.group(section, "Fin", Vector3(-120.0, -0.3 * profile(-120.0).y, side * profile(-120.0).x) - section.position)
		ModelKit.prism(fin, Vector3(140.0, 3.0, 50.0), Vector3(0, 0, side * 22.0), _hull_mat, Vector3(90, 0, 0) if side > 0 else Vector3(-90, 0, 0))
		ModelKit.box(fin, Vector3(120.0, 1.0, 1.2), Vector3(-10.0, 1.6, side * 30.0), _trim_mat)
		for k in 6:
			ModelKit.box(fin, Vector3(4.0, 0.6, 0.6), Vector3(-50.0 + k * 18.0, 1.8, side * 22.0), _window_mat)
	var spine := _section_at(-440.0)
	for fz: float in [-62.0, 62.0]:
		ModelKit.prism(spine, Vector3(60.0, 26.0, 3.0), Vector3(-460.0, 13.0, fz) - spine.position, _dark_mat, Vector3(0, 0, -12))


## Engine block: five big nozzles with glowing throats and long blue plumes.
func _build_engines() -> void:
	var section := sections[0]
	var nozzles := [Vector3(0, -12, 0), Vector3(0, -12, -20), Vector3(0, -12, 20), Vector3(0, -30, -10), Vector3(0, -30, 10)]
	for n: Vector3 in nozzles:
		var at := Vector3(-500.0, n.y, n.z) - section.position
		ModelKit.hex_x(section, 9.0, 14.0, at + Vector3(-4.0, 0, 0), _dark_mat, 12, 1.25)
		ModelKit.cylinder(section, 7.5, 7.5, 0.6, at + Vector3(-11.2, 0, 0), ModelKit.emissive(engine_color, 3.2), Vector3(0, 0, 90), 16)
		for rot: Vector3 in [Vector3.ZERO, Vector3(90, 0, 0)]:
			var plume := ModelKit.quad(section, Vector2(90.0, 16.0), at + Vector3(-55.0, 0, 0), ModelKit.glow(engine_color, 1.4, ModelKit.GlowShape.STREAK), rot + Vector3(0, 0, 180))
			_plumes.append(plume)
		var halo := MeshInstance3D.new()
		halo.mesh = QuadMesh.new()
		halo.material_override = ModelKit.glow_billboard(engine_color, 1.6)
		halo.scale = Vector3.ONE * 26.0
		halo.position = at + Vector3(-13.0, 0, 0)
		section.add_child(halo)


## Open hangar bays glowing on both flanks.
func _build_hangars() -> void:
	for side: float in [-1.0, 1.0]:
		for x: float in [-300.0, -150.0]:
			var section := _section_at(x)
			var p := profile(x)
			var at := Vector3(x, -0.45 * p.y, side * (p.x * 0.88 + 0.3)) - section.position
			ModelKit.box(section, Vector3(46.0, 10.0, 0.8), at, ModelKit.emissive(Color("ffb566"), 1.4))
			ModelKit.box(section, Vector3(50.0, 1.2, 1.2), at + Vector3(0, 5.6, 0), _trim_mat)
			var glow := ModelKit.quad(section, Vector2(70.0, 24.0), at + Vector3(0, 0, side * 1.0), ModelKit.glow(Color(1.0, 0.7, 0.4), 0.8), Vector3(0, 0 if side > 0 else 180, 0))
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_running_lights() -> void:
	for side: float in [-1.0, 1.0]:
		var color := Color("ff4a4a") if side < 0 else Color("4aff8a")
		for x: float in [-480.0, -200.0, 100.0, 380.0]:
			var p := profile(x)
			var blink := ModelKit.emissive(color, 2.0)
			_blinkers.append(blink)
			var section := _section_at(x)
			ModelKit.sphere(section, 1.6, Vector3(x, -0.28 * p.y, side * (p.x + 1.8)) - section.position, blink)
	for x in range(-460, 480, 60):
		var section := _section_at(x)
		ModelKit.sphere(section, 1.0, Vector3(x, -profile(x).y - 0.8, 0) - section.position, ModelKit.emissive(Color.WHITE, 1.8))


# --- Helpers -------------------------------------------------------------------------------

func _mat(color: Color, rim: float) -> StandardMaterial3D:
	var m := ModelKit.toon(color, rim, 0.6, 0.45)
	return m


func _section_index(x: float) -> int:
	for i in SECTION_BOUNDS.size() - 1:
		if x < SECTION_BOUNDS[i + 1]:
			return i
	return SECTION_BOUNDS.size() - 2


func _section_at(x: float) -> Node3D:
	return sections[_section_index(x)]


func _multimesh(parent: Node3D, transforms: Array, material: Material, mesh: Mesh, colors := PackedColorArray()) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = material
	parent.add_child(inst)


func _process(delta: float) -> void:
	_time += delta
	for i in _blinkers.size():
		_blinkers[i].emission_energy_multiplier = 3.0 if fmod(_time + i * 0.37, 1.6) < 0.18 else 0.25
	for d in _dishes:
		d.rotation.y += delta * 0.5
	for i in _turrets.size():
		_turrets[i].rotation.y = sin(_time * 0.25 + i * 1.3) * 0.6
	var flicker := 1.0 + sin(_time * 30.0) * 0.08
	for p in _plumes:
		p.scale = Vector3(flicker, 1.0, 1.0)
	for i in _fires.size():
		_fires[i].scale = Vector3.ONE * (1.0 + sin(_time * 9.0 + i) * 0.15)
	if _destroying:
		_destroy_time += delta
		var k := minf(1.0, _destroy_time / 6.0)
		for i in sections.size():
			sections[i].position += _drift[i] * delta * k
			sections[i].rotation += _spin[i] * delta * k
