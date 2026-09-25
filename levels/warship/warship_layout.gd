class_name WarshipLayout
extends Node3D
## Stage 2 geometry, hazards, enemies and pickups, built from compact tables so the whole
## level reads top to bottom. Floor baseline is y = 0; jump reference: single ≈ 3 high / 6 wide,
## double ≈ 5.3 high / 10 wide, dash-jump ≈ 12 wide.
## Must sit before the PlatformerDirector in the tree so the gate exists when it is wired.

const WALKER := preload("res://enemies/ground/walker.tscn")
const HOPPER := preload("res://enemies/ground/hopper.tscn")
const TURRET := preload("res://enemies/ground/turret.tscn")
const FLYER := preload("res://enemies/ground/flyer.tscn")
const ELITE := preload("res://enemies/ground/elite_walker.tscn")
const SHIELD := preload("res://enemies/ground/shield_guard.tscn")
const SWOOPER := preload("res://enemies/ground/swooper.tscn")

@export var enemy_root: Node3D
@export var pickup_root: Node3D
@export var boss_gate: Node3D

## [x, top, width, height] — walkable blocks.
const SOLIDS := [
	# Exterior hull (the drop zone): stern mass + roof deck with the entry hatch at x 0..8.
	# The roof also seals the level so wall-climbs cannot skip sections.
	[-130.0, 30.0, 112.0, 50.0], [-18.0, 30.0, 18.0, 8.0], [8.0, 30.0, 144.0, 8.0], [152.0, 30.0, 7.0, 4.0], [159.0, 30.0, 157.0, 8.0], [330.0, 30.0, 16.0, 8.0],
	# Bulkhead tower right of the hatch: the only way on is down.
	[8.0, 90.0, 4.0, 60.0, false],
	# Docking gantry over the hatch: caps any wall-climb up the bulkhead.
	[-12.0, 44.0, 24.0, 2.0, false],
	# 1. Landing bay
	[-16.0, 0.0, 48.0, 8.0], [-18.0, 16.0, 3.0, 24.0],
	# 2. Pit run: appearing blocks over the molten pit (see TIMED), a last pillar.
	[55.0, 1.0, 2.6, 9.0],
	[58.0, 0.0, 34.0, 8.0], [77.0, 2.5, 6.0, 2.5],
	# 3. Electric corridor (low ceiling)
	[92.0, 0.0, 34.0, 8.0], [92.0, 24.0, 34.0, 17.5, false],
	# 4. Tower climb (the middle step crumbles, see CRUMBLES) and high walkway
	[126.0, 2.5, 6.0, 10.5], [140.0, 9.0, 27.0, 17.5],
	# 4b. Secret: wall-kick up the narrow shaft between two hanging blocks to the roof
	# pocket (Heart Tank). Both blocks clear the walkway by 3.5 so the main path is untouched.
	[150.5, 21.0, 1.5, 8.5, false], [154.6, 21.0, 4.4, 8.5],
	# 5. Moving platforms over the reactor pit (landing ledge)
	[190.0, 4.5, 10.0, 12.5],
	# 6. Crusher hall: conveyor strips (see CONVEYORS) drag you back under the crushers.
	[200.0, 0.0, 46.0, 8.0], [200.0, 24.0, 46.0, 16.5, false],
	# 7. Sentinel mid-boss room (246..270, sealed by MidBossZone), dash-jump gap, approach
	[246.0, 0.0, 24.0, 8.0], [279.0, 0.0, 22.0, 8.0],
	# 8. Boss arena
	[301.0, 0.0, 30.0, 8.0], [312.0, 3.8, 5.0, 0.6], [329.0, 16.0, 4.0, 24.0],
]

## Appearing blocks: [centre x, top y, width, offset] — on 1.8 s / off 1.4 s, staggered.
const TIMED := [
	[35.5, 0.5, 3.0, 0.0], [41.0, 2.0, 3.0, 0.8], [46.5, 3.2, 3.0, 1.6], [52.0, 2.0, 3.0, 2.4],
]
## Conveyor strips: [x start, width, speed] (floor top y = 0).
const CONVEYORS := [[206.0, 12.0, -3.2], [226.0, 14.0, -3.2]]
## Crumbling ledges: [centre x, top y, width].
const CRUMBLES := [[136.0, 6.0, 4.0]]

## [x, y, travel_x, travel_y, period, width]
const PLATFORMS := [
	[171.0, 7.0, 7.0, 0.0, 3.6, 3.5],
	[184.0, 4.0, 0.0, 4.0, 3.0, 3.5],
]

## [kind, x, y, width, offset]
const HAZARDS := [
	[Hazard.Kind.ELECTRIC, 99.0, 0.0, 4.0, 0.0],
	[Hazard.Kind.ELECTRIC, 108.0, 0.0, 4.0, 1.2],
	[Hazard.Kind.ELECTRIC, 117.0, 0.0, 4.0, 2.4],
	[Hazard.Kind.SPIKES, 71.0, 0.0, 3.0, 0.0],
	[Hazard.Kind.CRUSHER, 211.0, 6.2, 3.0, 0.0],
	[Hazard.Kind.CRUSHER, 222.0, 6.2, 3.0, 1.1],
	[Hazard.Kind.CRUSHER, 233.0, 6.2, 3.0, 2.2],
]

## [scene, x, y]
const ENEMIES := [
	[WALKER, 18.0, 0.2], [SHIELD, 28.0, 0.2],
	[HOPPER, 65.0, 0.2], [TURRET, 80.0, 2.7], [WALKER, 88.0, 0.2],
	[SWOOPER, 103.5, 5.4], [FLYER, 112.0, 5.0], [SWOOPER, 121.0, 5.4],
	[TURRET, 158.0, 9.2], [SHIELD, 146.0, 9.2], [FLYER, 178.0, 10.0],
	[FLYER, 275.0, 6.0], [ELITE, 287.0, 0.2], [SHIELD, 296.0, 0.2],
]

## [kind, x, y]
const ITEMS := [
	[ItemPickup.Kind.HEALTH, 46.5, 4.8],
	[ItemPickup.Kind.ENERGY, 123.0, 1.2],
	[ItemPickup.Kind.HEALTH, 136.0, 7.6],
	[ItemPickup.Kind.TANK, 186.0, 11.0],
	[ItemPickup.Kind.HEART, 156.5, 22.4],
	[ItemPickup.Kind.ENERGY, 195.0, 5.7],
	[ItemPickup.Kind.HEALTH, 267.0, 1.2],
	[ItemPickup.Kind.ENERGY, 296.0, 1.2],
]

const CHECKPOINTS := [[14.0, 0.0], [128.0, 2.5], [203.0, 0.0], [240.0, 0.0], [284.0, 0.0]]
## Sentinel room: [left gate x, right gate x, trigger x, camera center].
const MID_BOSS := [245.5, 270.5, 250.0, Vector2(258.0, 6.0)]

## Roof section over the reactor arena; blown open for the escape.
const BLAST_ROOF := [316.0, 30.0, 14.0, 8.0]
const HATCH_X := 0.0
const HATCH_WIDTH := 8.0

## Ambience in world space: [kind, x, y] — steam vents, spark showers, light pools.
const AMBIENCE := [
	[&"steam", 20.0, 0.0], [&"sparks", 40.0, 13.0], [&"steam", 64.0, 0.0], [&"sparks", 104.0, 6.3],
	[&"steam", 122.0, 0.0], [&"sparks", 160.0, 16.0], [&"steam", 206.0, 0.0], [&"sparks", 216.0, 7.3],
	[&"sparks", 238.0, 7.3], [&"steam", 256.0, 0.0], [&"steam", 290.0, 0.0], [&"sparks", 310.0, 21.5],
]
## [x, y, color, range]
const LIGHTS := [
	[4.0, 6.0, Color(1.0, 0.65, 0.3), 14.0], [108.0, 4.5, Color(0.7, 0.45, 1.0), 16.0],
	[180.0, 11.0, Color(0.3, 0.8, 1.0), 16.0], [222.0, 5.0, Color(1.0, 0.25, 0.2), 18.0],
	[315.0, 8.0, Color(0.55, 0.4, 1.0), 20.0], [-60.0, 36.0, Color(0.6, 0.8, 1.0), 22.0],
	[156.5, 23.5, Color(0.4, 1.0, 0.6), 6.0],
]

var blast_roof: StaticBody3D
var _mat_cache: Dictionary = {}
var mid_boss_zone: MidBossZone


func _ready() -> void:
	# The level's pickup root lives outside this sub-scene: find it by its group.
	if pickup_root == null:
		pickup_root = get_tree().get_first_node_in_group(EchoPickup.ROOT_GROUP) as Node3D
	if enemy_root == null or pickup_root == null or boss_gate == null:
		push_error("WarshipLayout: enemy_root, pickup_root and boss_gate must be assigned.")
		return
	var world := ModelKit.group(self, "World")
	for s: Array in SOLIDS:
		var trim: bool = s[4] if s.size() > 4 else true
		var mats := _zone_mats(s[0] + s[2] * 0.5, trim, s[1] > 25.0)
		LevelKit.solid(world, s[0], s[1], s[2], s[3], trim, mats[0], mats[1], mats[2])
	LevelKit.stripes(world, 29.0, 0.02, 3.0)
	LevelKit.stripes(world, 267.0, 0.02, 3.0)
	for p: Array in PLATFORMS:
		var platform := MovingPlatform.new()
		platform.width = p[5]
		platform.travel = Vector3(p[2], p[3], 0)
		platform.period = p[4]
		platform.position = Vector3(p[0], p[1], 0)
		world.add_child(platform)
	for t: Array in TIMED:
		var block := TimedBlock.new()
		block.width = t[2]
		block.offset = t[3]
		block.color = WarshipZones.accent_at(t[0])
		block.position = Vector3(t[0], t[1] - 0.5, 0)
		block.add_to_group(&"unsafe_ground")
		world.add_child(block)
	for c: Array in CONVEYORS:
		var belt := ConveyorBelt.new()
		belt.width = c[1]
		belt.speed = c[2]
		belt.position = Vector3(c[0] + c[1] * 0.5, 0.0, 0)
		world.add_child(belt)
	for c: Array in CRUMBLES:
		var ledge := CrumblePlatform.new()
		ledge.width = c[2]
		ledge.position = Vector3(c[0], c[1] - 0.3, 0)
		ledge.add_to_group(&"unsafe_ground")
		world.add_child(ledge)
	for h: Array in HAZARDS:
		var hazard := Hazard.new()
		hazard.kind = h[0]
		hazard.width = h[3]
		hazard.offset = h[4]
		hazard.drop = h[2] - 0.6
		hazard.position = Vector3(h[1], h[2], 0)
		add_child(hazard)
	for e: Array in ENEMIES:
		var enemy := (e[0] as PackedScene).instantiate() as Node3D
		enemy.position = Vector3(e[1], e[2], 0)
		enemy_root.add_child(enemy)
	for i: Array in ITEMS:
		var item := ItemPickup.new()
		item.kind = i[0]
		item.amount = 2 if i[0] == ItemPickup.Kind.HEALTH else 1
		item.position = Vector3(i[1], i[2], 0)
		pickup_root.add_child(item)
	for c: Array in CHECKPOINTS:
		var checkpoint := Checkpoint.new()
		checkpoint.position = Vector3(c[0], c[1], 0)
		checkpoint.add_to_group(&"checkpoints")
		add_child(checkpoint)
	blast_roof = LevelKit.solid(world, BLAST_ROOF[0], BLAST_ROOF[1], BLAST_ROOF[2], BLAST_ROOF[3])
	LevelKit.stripes(blast_roof, -BLAST_ROOF[2] * 0.5, BLAST_ROOF[3] * 0.5 - 0.7, BLAST_ROOF[2])
	_build_gate()
	mid_boss_zone = MidBossZone.new()
	mid_boss_zone.left_x = MID_BOSS[0]
	mid_boss_zone.right_x = MID_BOSS[1]
	mid_boss_zone.trigger_x = MID_BOSS[2]
	mid_boss_zone.camera_center = MID_BOSS[3]
	mid_boss_zone.enemy_root = enemy_root
	mid_boss_zone.pickup_root = pickup_root
	add_child(mid_boss_zone)
	_build_reactor_housing()
	_build_hatch()
	_build_exterior_deck()
	_build_ambience()


## Hull body + edge-light materials for a block at x: the zone's accent lights the edges and
## tints the plating. The exterior roof keeps the neutral hull colours.
func _zone_mats(x: float, trim: bool, exterior: bool) -> Array:
	if exterior:
		return [null, null, null]
	var zone := WarshipZones.index_at(x)
	var key := "%d_%s" % [zone, trim]
	if not _mat_cache.has(key):
		var accent := WarshipZones.accent_at(x)
		var base := Color("2a3656") if trim else Color("141b2e")
		var hull := ModelKit.toon(base.lerp(accent * Color(0.28, 0.28, 0.28), 0.6), 0.4, 0.65, 0.45)
		var trim_mat := ModelKit.toon(Color("6a7fae").lerp(accent, 0.45), 0.5, 0.45, 0.5)
		_mat_cache[key] = [hull, ModelKit.emissive(accent, 1.8), trim_mat]
	return _mat_cache[key]


## Blows the arena roof out (escape cinematic): debris burst, then the opening stays.
func blast_open() -> void:
	if not is_instance_valid(blast_roof):
		return
	var at := blast_roof.global_position
	for i in 6:
		Vfx.spawn(get_tree(), preload("res://vfx/explosion.tscn"), at + Vector3(randf_range(-6, 6), randf_range(-3, 3), 2.5), randf_range(1.8, 3.2))
	var root := get_tree().get_first_node_in_group(Vfx.ROOT_GROUP)
	if root:
		var pieces: Array[Node3D] = []
		for i in 8:
			var piece := Node3D.new()
			ModelKit.box(piece, Vector3(randf_range(1.0, 2.5), randf_range(0.6, 1.5), 1.2), Vector3.ZERO, LevelKit.material(&"hull"))
			piece.position = at + Vector3(randf_range(-6, 6), randf_range(-2, 3), 1)
			pieces.append(piece)
		root.add_child(FragmentBurst.create(pieces, at, 12.0))
	blast_roof.queue_free()


## Open entry hatch in the roof deck: door leaves folded up, striped frame, beacons.
func _build_hatch() -> void:
	var hatch := ModelKit.group(self, "Hatch", Vector3(HATCH_X + HATCH_WIDTH * 0.5, 30.0, 0))
	var frame := ModelKit.hull(Color("3d4a66"))
	var dark := LevelKit.material(&"hull_dark")
	for side: float in [-1.0, 1.0]:
		var x := side * (HATCH_WIDTH * 0.5 + 0.2)
		ModelKit.box(hatch, Vector3(0.5, 0.5, 3.0), Vector3(x, 0.1, 0), frame)
		# Door leaf standing open.
		var leaf := ModelKit.group(hatch, "Leaf", Vector3(x + side * 0.3, 0.3, -1.2))
		ModelKit.box(leaf, Vector3(0.3, 3.6, 2.2), Vector3(0, 1.8, 0), frame, Vector3(0, 0, -side * 18))
		LevelKit.stripes(leaf, -0.2, 1.0, 0.5)
		var beacon := ModelKit.emissive(Palette.INTERACTABLE, 2.4)
		ModelKit.sphere(hatch, 0.22, Vector3(x, 0.6, 1.2), beacon)
		ModelKit.quad(hatch, Vector2.ONE * 1.6, Vector3(x, 0.6, 1.4), ModelKit.glow(Palette.INTERACTABLE, 0.8))
	LevelKit.stripes(hatch, -HATCH_WIDTH * 0.5, -0.4, HATCH_WIDTH)
	# Shaft walls down to the bay ceiling, lit from inside.
	for side: float in [-1.0, 1.0]:
		ModelKit.box(hatch, Vector3(0.3, 8.0, 3.0), Vector3(side * HATCH_WIDTH * 0.5, -4.0, -0.3), dark)
	ModelKit.quad(hatch, Vector2(HATCH_WIDTH, 8.0), Vector3(0, -4.0, -1.6), ModelKit.glow(Color(1.0, 0.7, 0.35), 0.35))
	var sign := Label3D.new()
	sign.text = "▼  ENTRY  ▼"
	sign.font_size = 64
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.modulate = Palette.INTERACTABLE
	sign.position = Vector3(0, 3.8, 0.5)
	hatch.add_child(sign)


## Exterior roof deck details around the drop zone: landing ring, deck markings, masts,
## turret domes and running lights along the hull edge.
func _build_exterior_deck() -> void:
	var deck := ModelKit.group(self, "ExteriorDeck")
	var metal := ModelKit.hull(Color("3d4a66"), ArtStyle.OUTLINE_THIN)
	var dark := LevelKit.material(&"hull_dark")
	# Landing target where the mech touches down.
	var ring := ModelKit.group(deck, "LandingRing", Vector3(-60, 30.03, 0))
	ModelKit.cylinder(ring, 2.4, 2.4, 0.05, Vector3.ZERO, ModelKit.emissive(Palette.INTERACTABLE, 0.9), Vector3.ZERO, 24)
	ModelKit.cylinder(ring, 2.0, 2.0, 0.07, Vector3.ZERO, dark, Vector3.ZERO, 24)
	# Deck arrows toward the hatch.
	for x in range(-48, -2, 8):
		ModelKit.prism(deck, Vector3(0.8, 1.4, 0.05), Vector3(x, 30.35, 2.02), LevelKit.material(&"stripe"), Vector3(0, 0, -90))
	# Masts, sensor domes and a deck turret behind the walkway.
	for x: float in [-110.0, -86.0, -34.0, 30.0, 70.0]:
		var mast := ModelKit.group(deck, "Mast", Vector3(x, 30, -2.6))
		ModelKit.box(mast, Vector3(0.4, 7.0, 0.4), Vector3(0, 3.5, 0), metal)
		ModelKit.box(mast, Vector3(2.6, 0.2, 0.3), Vector3(0, 5.6, 0), metal)
		ModelKit.box(mast, Vector3(1.6, 0.2, 0.3), Vector3(0, 6.4, 0), metal)
		ModelKit.sphere(mast, 0.18, Vector3(0, 7.1, 0), LevelKit.material(&"red_light"))
	for x: float in [-96.0, -20.0, 48.0, 120.0]:
		var dome := ModelKit.group(deck, "Dome", Vector3(x, 30, -3.2))
		ModelKit.sphere(dome, 2.2, Vector3.ZERO, metal, Vector3(1, 0.55, 1))
		ModelKit.box(dome, Vector3(3.2, 0.5, 0.5), Vector3(1.8, 0.9, 0.6), dark, Vector3(0, 0, 8))
		ModelKit.box(dome, Vector3(3.2, 0.5, 0.5), Vector3(1.8, 0.9, -0.6), dark, Vector3(0, 0, 8))
	# Running lights along the deck edge.
	for x in range(-128, 344, 6):
		ModelKit.box(deck, Vector3(0.5, 0.12, 0.1), Vector3(x, 29.75, 2.05), LevelKit.material(&"light"))
	# Hull side windows and markings on the stern mass.
	for row in 3:
		for x in range(-126, -22, 3):
			if (x + row * 7) % 5 == 0:
				continue
			ModelKit.box(deck, Vector3(1.2, 0.35, 0.05), Vector3(x, 25.0 - row * 3.5, 2.04), LevelKit.material(&"warm_light") if (x * 7 + row) % 3 else LevelKit.material(&"light"))
	var mark := Label3D.new()
	mark.text = "VX-07"
	mark.font_size = 256
	mark.pixel_size = 0.03
	mark.outline_size = 0
	mark.modulate = Color(0.55, 0.62, 0.78, 0.55)
	mark.position = Vector3(-78, 16.0, 2.05)
	deck.add_child(mark)
	LevelKit.stripes(deck, -130.0, 28.6, 112.0)
	# Bulkhead face: hazard bands, lamps and a sealed door outline.
	for y in range(31, 46, 3):
		LevelKit.stripes(deck, 8.0, float(y), 4.0)
	for y in range(32, 46, 4):
		ModelKit.sphere(deck, 0.2, Vector3(8.0, y, 2.2), LevelKit.material(&"red_light"))
	ModelKit.box(deck, Vector3(0.1, 5.0, 2.6), Vector3(7.95, 32.5, 0), LevelKit.material(&"hull_dark"))


func _build_ambience() -> void:
	var amb := ModelKit.group(self, "Ambience")
	for a: Array in AMBIENCE:
		if a[0] == &"steam":
			LevelKit.steam(amb, Vector3(a[1], a[2], -1.0))
		else:
			LevelKit.sparks(amb, Vector3(a[1], a[2], 1.0))
	for l: Array in LIGHTS:
		var light := OmniLight3D.new()
		light.position = Vector3(l[0], l[1], 4.0)
		light.light_color = l[2]
		light.omni_range = l[3]
		light.light_energy = 1.6
		light.omni_attenuation = 1.2
		amb.add_child(light)


## Blast door that seals the arena once the boss fight starts (director toggles it).
func _build_gate() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 16.0, LevelKit.DEPTH)
	shape.shape = box
	shape.position = Vector3(0, 8.0, 0)
	body.add_child(shape)
	ModelKit.box(body, Vector3(1.2, 16.0, 2.6), Vector3(0, 8.0, 0), ModelKit.hull(Color("3d4a66")))
	for y in range(1, 16, 3):
		LevelKit.stripes(body, -0.6, float(y), 1.2)
	ModelKit.box(body, Vector3(0.3, 16.0, 0.2), Vector3(0.62, 8.0, 1.2), LevelKit.material(&"warm_light"))
	boss_gate.add_child(body)


## Dark machinery frame behind the boss so the arena reads as the reactor chamber.
func _build_reactor_housing() -> void:
	var housing := ModelKit.group(self, "ReactorHousing", Vector3(323.5, 3.6, -4.0))
	var dark := LevelKit.material(&"hull_dark")
	var trim := LevelKit.material(&"trim")
	ModelKit.cylinder(housing, 4.2, 4.2, 1.0, Vector3.ZERO, dark, Vector3(90, 0, 0), 12)
	ModelKit.cylinder(housing, 3.2, 3.2, 1.2, Vector3(0, 0, 0.2), trim, Vector3(90, 0, 0), 12)
	for angle in range(0, 360, 45):
		var dir := Vector2.from_angle(deg_to_rad(angle))
		ModelKit.box(housing, Vector3(0.7, 3.0, 0.8), Vector3(dir.x * 5.2, dir.y * 5.2, 0), dark, Vector3(0, 0, angle - 90))
	ModelKit.box(housing, Vector3(2.0, 12.0, 1.0), Vector3(0, 10.0, -0.5), dark)
	ModelKit.box(housing, Vector3(2.0, 6.0, 1.0), Vector3(0, -7.0, -0.5), dark)
