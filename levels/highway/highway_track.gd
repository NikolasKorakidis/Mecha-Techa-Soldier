class_name HighwayTrack
extends Node3D
## Stage 3 course, authored as a fixed sequence (no procedural generation). Road top is y = 0
## unless a raised deck says otherwise. Bike reference at ~18 u/s: single jump ≈ 12 wide (and 2.6 high, so decks rise by 2),
## double ≈ 22 wide, pads clear ≈ 30. Must sit before the RunnerDirector in the tree.

const GROUP := &"runner_track"
const FLYER := preload("res://enemies/ground/flyer.tscn")
const K := TrackObstacle.Kind

@export var enemy_root: Node3D
@export var finish_x: float = 1040.0

## Road decks: [x_start, x_end, top]. Gaps between decks are pits.
const ROAD := [
	[-40.0, 128.0, 0.0],
	[134.0, 162.0, 0.0], [170.0, 198.0, 0.0], [204.0, 380.0, 0.0],
	[394.0, 428.0, 0.0], [442.0, 588.0, 0.0], [598.0, 640.0, 0.0],
	[640.0, 700.0, 2.0], [708.0, 760.0, 2.0], [760.0, 800.0, 0.0],
	[812.0, 870.0, 0.0], [870.0, 905.0, 2.0], [915.0, 1100.0, 0.0],
]

## [kind, x, y, gate_offset]
const OBSTACLES := [
	# Intro: learn jump, then duck, then boost.
	[K.BARRIER, 50.0, 0.0], [K.BARRIER, 78.0, 0.0], [K.BEAM, 100.0, 0.0], [K.CRATE, 118.0, 0.0],
	# Gaps + mines.
	[K.MINE, 186.0, 0.0], [K.MINE, 222.0, 0.0], [K.MINE, 228.0, 0.0], [K.BEAM, 246.0, 0.0],
	# Duck/jump rhythm and a crate wall.
	[K.BEAM, 280.0, 0.0], [K.BARRIER, 298.0, 0.0], [K.BEAM, 316.0, 0.0],
	[K.CRATE, 340.0, 0.0], [K.CRATE, 341.6, 0.0], [K.CRATE, 341.6, 1.5],
	[K.BARRIER, 366.0, 0.0],
	# Pad over the long gap.
	[K.PAD, 425.0, 0.0],
	# Laser gates.
	[K.GATE, 478.0, 0.0, 0.0], [K.GATE, 506.0, 0.0, 1.0], [K.MINE, 520.0, 0.0],
	[K.CRATE, 548.0, 0.0], [K.CRATE, 551.0, 0.0], [K.CRATE, 554.0, 0.0], [K.BEAM, 572.0, 0.0],
	# Raised decks.
	[K.BARRIER, 618.0, 0.0], [K.BEAM, 668.0, 2.0], [K.MINE, 690.0, 2.0], [K.CRATE, 735.0, 2.0],
	[K.BEAM, 780.0, 0.0],
	# Finale gauntlet.
	[K.GATE, 830.0, 0.0, 0.4], [K.BARRIER, 850.0, 0.0], [K.BEAM, 888.0, 2.0],
	[K.MINE, 930.0, 0.0], [K.BEAM, 946.0, 0.0], [K.BARRIER, 962.0, 0.0], [K.CRATE, 980.0, 0.0],
	[K.GATE, 1000.0, 0.0, 0.8], [K.BARRIER, 1018.0, 0.0],
]

## Orb arcs: [x_start, y_base, count, arc_height]
const ORB_ARCS := [
	[30.0, 1.0, 5, 0.0], [126.0, 2.0, 5, 3.0], [163.0, 2.0, 5, 3.0], [260.0, 1.0, 6, 0.0],
	[378.0, 2.0, 6, 4.0], [424.0, 4.0, 8, 7.0], [586.0, 2.0, 5, 3.0], [648.0, 3.2, 5, 0.0],
	[700.0, 4.0, 5, 3.0], [800.0, 2.0, 6, 4.0], [905.0, 4.0, 5, 3.0],
]

## Drones: [x, y]
const DRONES := [[360.0, 6.0], [540.0, 6.5], [575.0, 5.5], [725.0, 8.5], [860.0, 6.0], [990.0, 6.0]]


func _enter_tree() -> void:
	add_to_group(GROUP)


## Where to put the bike back after it falls at `x`: a little way onto the next deck ahead.
func recovery_point(x: float) -> Vector3:
	for r: Array in ROAD:
		if x < r[1] - 4.0:
			var at := maxf(x, r[0] + 3.0)
			return Vector3(at, r[2] + 0.5, 0)
	return Vector3(x, 0.5, 0)


func _ready() -> void:
	if enemy_root == null:
		push_error("HighwayTrack: enemy_root must be assigned.")
		return
	var world := ModelKit.group(self, "Road")
	for r: Array in ROAD:
		var deck := LevelKit.solid(world, r[0], r[2], r[1] - r[0], 6.0 + r[2])
		_lane_marks(deck, r[1] - r[0], (6.0 + r[2]) * 0.5)
	for o: Array in OBSTACLES:
		var obstacle := TrackObstacle.new()
		obstacle.kind = o[0]
		obstacle.position = Vector3(o[1], o[2], 0)
		if o.size() > 3:
			obstacle.offset = o[3]
		add_child(obstacle)
	for a: Array in ORB_ARCS:
		for i in int(a[2]):
			var t := float(i) / maxf(1.0, float(a[2]) - 1.0)
			var orb := TrackObstacle.new()
			orb.kind = K.ORB
			orb.position = Vector3(a[0] + i * 2.2, a[1] + sin(t * PI) * a[3], 0)
			add_child(orb)
	for d: Array in DRONES:
		var drone := FLYER.instantiate() as Node3D
		drone.position = Vector3(d[0], d[1], 0)
		enemy_root.add_child(drone)
	_build_finish()


## Dashed lane line along the front face of the deck.
func _lane_marks(deck: Node3D, width: float, half_height: float) -> void:
	var mat := LevelKit.material(&"stripe")
	var x := -width * 0.5 + 1.0
	while x < width * 0.5 - 1.0:
		ModelKit.box(deck, Vector3(1.4, 0.06, 0.05), Vector3(x, half_height - 0.02, 0.9), mat)
		x += 3.5


func _build_finish() -> void:
	var arch := ModelKit.group(self, "FinishArch", Vector3(finish_x, 0, 0))
	var metal := ModelKit.hull(Color("3d4a66"))
	ModelKit.box(arch, Vector3(0.8, 9.0, 0.8), Vector3(0, 4.5, -1.6), metal)
	ModelKit.box(arch, Vector3(0.8, 9.0, 0.8), Vector3(0, 4.5, 1.8), metal)
	ModelKit.box(arch, Vector3(1.0, 1.2, 4.4), Vector3(0, 9.2, 0.1), metal)
	for i in 8:
		var mat := ModelKit.emissive(Color.WHITE if i % 2 == 0 else Palette.PLAYER_ENERGY, 2.0)
		ModelKit.box(arch, Vector3(1.04, 0.5, 0.5), Vector3(0, 9.2, -1.6 + i * 0.48), mat)
	ModelKit.quad(arch, Vector2(3.0, 9.0), Vector3(0, 4.5, 0.4), ModelKit.glow(Palette.PLAYER_ENERGY, 0.5, ModelKit.GlowShape.STREAK), Vector3(0, 0, 90))
