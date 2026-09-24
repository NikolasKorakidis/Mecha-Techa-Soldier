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

@export var enemy_root: Node3D
@export var pickup_root: Node3D
@export var boss_gate: Node3D

## [x, top, width, height] — walkable blocks.
const SOLIDS := [
	# Hull roof: seals the level so wall-climbs cannot skip sections.
	[-18.0, 30.0, 351.0, 8.0, false],
	# 1. Landing bay
	[-16.0, 0.0, 48.0, 8.0], [-18.0, 16.0, 3.0, 24.0],
	# 2. Pit run
	[35.0, 1.0, 4.0, 9.0], [43.0, 2.5, 4.0, 1.2], [51.0, 1.0, 4.0, 9.0],
	[58.0, 0.0, 34.0, 8.0], [77.0, 2.5, 6.0, 2.5],
	# 3. Electric corridor (low ceiling)
	[92.0, 0.0, 34.0, 8.0], [92.0, 24.0, 34.0, 17.5, false],
	# 4. Tower climb and high walkway
	[126.0, 2.5, 6.0, 10.5], [134.0, 6.0, 4.0, 1.2], [140.0, 9.0, 27.0, 17.5],
	# 5. Moving platforms over the reactor pit (landing ledge)
	[190.0, 4.5, 10.0, 12.5],
	# 6. Crusher hall
	[200.0, 0.0, 46.0, 8.0], [200.0, 24.0, 46.0, 16.5, false],
	# 7. Elite guard, dash-jump gap, approach
	[246.0, 0.0, 24.0, 8.0], [279.0, 0.0, 22.0, 8.0],
	# 8. Boss arena
	[301.0, 0.0, 30.0, 8.0], [312.0, 3.8, 5.0, 0.6], [329.0, 16.0, 4.0, 24.0],
]

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
	[WALKER, 18.0, 0.2], [WALKER, 26.0, 0.2],
	[HOPPER, 65.0, 0.2], [TURRET, 80.0, 2.7], [WALKER, 88.0, 0.2],
	[FLYER, 112.0, 5.0],
	[TURRET, 158.0, 9.2], [WALKER, 150.0, 9.2], [FLYER, 178.0, 10.0],
	[HOPPER, 241.0, 0.2],
	[ELITE, 260.0, 0.2], [FLYER, 275.0, 6.0], [WALKER, 292.0, 0.2],
]

## [kind, x, y]
const ITEMS := [
	[ItemPickup.Kind.HEALTH, 45.0, 4.0],
	[ItemPickup.Kind.ENERGY, 123.0, 1.2],
	[ItemPickup.Kind.HEALTH, 136.0, 7.6],
	[ItemPickup.Kind.ENERGY, 195.0, 5.7],
	[ItemPickup.Kind.HEALTH, 267.0, 1.2],
	[ItemPickup.Kind.ENERGY, 296.0, 1.2],
]

const CHECKPOINTS := [[128.0, 2.5], [203.0, 0.0], [284.0, 0.0]]


func _ready() -> void:
	if enemy_root == null or pickup_root == null or boss_gate == null:
		push_error("WarshipLayout: enemy_root, pickup_root and boss_gate must be assigned.")
		return
	var world := ModelKit.group(self, "World")
	for s: Array in SOLIDS:
		LevelKit.solid(world, s[0], s[1], s[2], s[3], s[4] if s.size() > 4 else true)
	LevelKit.stripes(world, 29.0, 0.02, 3.0)
	LevelKit.stripes(world, 267.0, 0.02, 3.0)
	for p: Array in PLATFORMS:
		var platform := MovingPlatform.new()
		platform.width = p[5]
		platform.travel = Vector3(p[2], p[3], 0)
		platform.period = p[4]
		platform.position = Vector3(p[0], p[1], 0)
		world.add_child(platform)
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
	_build_gate()
	_build_reactor_housing()


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
