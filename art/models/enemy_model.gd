@tool
class_name EnemyModel
extends Node3D
## Enemy family (all face -X). Ground kinds (walker, trooper, hopper, sentry, flybot, diver) are
## robots with animated legs, rotors and wings. Space kinds are real ships — nose, canopy light, swept wings or
## pylons, glowing rear thrusters — in coral armour over dark-red undersides with chunky outlines. Echo carriers (elites) add a gold-white core,
## orbiting gold fragments, a slow pulsing ring and a faint vertical beacon — never color alone.

enum Kind { DRONE, NEEDLE, LANCER, GUNPOD, RAMMER, GUNSHIP, TESLA, WARDEN, WALKER, HOPPER, SENTRY, FLYBOT, DIVER, TROOPER }

const SENSOR := Color("ffc36a")
const METAL := Color("3d2f45")
const ENGINE := Color("ff6a3c")
const GROUND_KINDS: Array[Kind] = [Kind.WALKER, Kind.HOPPER, Kind.SENTRY, Kind.FLYBOT, Kind.DIVER, Kind.TROOPER]
const GROUND_YAW := 0.45
const GROUND_ARMOR := Color("c8323c")
const GROUND_FRAME := Color("30354a")
const GROUND_STEEL := Color("5a6078")

@export var kind: Kind = Kind.DRONE:
	set(value):
		kind = value
		if is_inside_tree():
			_build()

## Any kind can be dressed as an echo carrier (e.g. an elite walker).
@export var elite_override: bool = false

## Set by the enemy: brightens the beacon while the carrier is on screen and targetable.
var targetable: bool = true

var _core_material: StandardMaterial3D
var _elite_ring: MeshInstance3D
var _beacon: MeshInstance3D
var _fragments: Node3D
var _shield_rim: MeshInstance3D
var _barrel_pivot: Node3D
var _body: Node3D
var _time: float = 0.0
var _recoil: float = 0.0
var _charge: float = 0.0
var _flames: Array[MeshInstance3D] = []
var _legs: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _wing_nodes: Array[Node3D] = []
var _last_x: float = 0.0
var _stride: float = 0.0


func _ready() -> void:
	_build()


func is_elite_kind() -> bool:
	return elite_override or kind in [Kind.GUNSHIP, Kind.TESLA, Kind.WARDEN]


## Kick the model back on each volley.
func recoil() -> void:
	_recoil = 1.0


## Pre-fire anticipation, 0..1 while the telegraph charges.
func set_charge(amount: float) -> void:
	_charge = amount


## World-space copies of the biggest hull pieces for the destruction burst.
func make_fragments(max_pieces: int = 5) -> Array[Node3D]:
	var meshes: Array[MeshInstance3D] = []
	for node in _body.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m.name == &"Outline" or m.mesh is QuadMesh or m.mesh is SphereMesh:
			continue
		meshes.append(m)
	meshes.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool:
		return a.mesh.get_aabb().get_volume() > b.mesh.get_aabb().get_volume())
	var pieces: Array[Node3D] = []
	for m in meshes.slice(0, max_pieces):
		var copy := m.duplicate() as Node3D
		copy.transform = m.global_transform
		pieces.append(copy)
	return pieces


func _build() -> void:
	ModelKit.clear(self)
	_elite_ring = null
	_beacon = null
	_fragments = null
	_shield_rim = null
	_barrel_pivot = null
	_flames.clear()
	_legs.clear()
	_spinners.clear()
	_wing_nodes.clear()
	var elite := is_elite_kind()
	var line := ArtStyle.OUTLINE_THICK if elite else ArtStyle.OUTLINE_THIN
	# Low rim keeps the coral saturated instead of washing toward pink.
	var coral := ModelKit.hull(Palette.ENEMY_CORAL, line, 0.18)
	var under := ModelKit.hull(Palette.ENEMY_DARK_RED, line, 0.15)
	var armor := ModelKit.hull(Palette.ENEMY_DARK_RED.darkened(0.35), line, 0.35)
	var metal := ModelKit.hull(METAL, ArtStyle.OUTLINE_THIN, 0.35)
	if kind in GROUND_KINDS:
		# Warship security robots: crimson armour over gunmetal frames.
		coral = ModelKit.hull(GROUND_ARMOR, line, 0.3)
		under = ModelKit.hull(GROUND_FRAME, line, 0.25)
		armor = ModelKit.hull(GROUND_STEEL, line, 0.4)
		metal = ModelKit.hull(GROUND_FRAME.darkened(0.3), ArtStyle.OUTLINE_THIN, 0.3)
	var core_color := Palette.ECHO_GOLD.lerp(Color.WHITE, 0.35) if elite else SENSOR
	_core_material = ModelKit.emissive(core_color, 3.0)
	var core_pos := Vector3(0.1, 0.05, 0.36)
	var core_radius := 0.16
	_body = ModelKit.group(self, "Body")

	match kind:
		Kind.NEEDLE:
			# STILETTO: long needle fighter, forward canards, dorsal fin, one big engine.
			ModelKit.hex_x(_body, 0.13, 1.2, Vector3(0.1, 0, 0), coral, 8)
			ModelKit.cone_x(_body, 0.13, 0.6, Vector3(-0.8, 0, 0), metal, 8, true)
			ModelKit.prism(_body, Vector3(0.5, 0.3, 0.06), Vector3(0.45, 0.2, 0), under, Vector3(0, 0, 90))
			for side: float in [1.0, -1.0]:
				ModelKit.box(_body, Vector3(0.32, 0.05, 0.1), Vector3(-0.35, 0.12 * side, 0), armor, Vector3(0, 0, -30.0 * side))
				ModelKit.box(_body, Vector3(0.5, 0.06, 0.12), Vector3(0.45, 0.14 * side, 0), coral, Vector3(0, 0, 38.0 * side))
			_engine(Vector3(0.72, 0, 0), 0.13, 1.2)
			core_pos = Vector3(-0.3, 0.1, 0.14)
			core_radius = 0.07
		Kind.DRONE:
			# HORNET: light interceptor — pointed nose, bubble canopy, swept wings, twin engines.
			ModelKit.hex_x(_body, 0.22, 0.9, Vector3(0.1, 0, 0), coral, 8, 1.1)
			ModelKit.cone_x(_body, 0.22, 0.45, Vector3(-0.56, 0, 0), coral, 8, true)
			ModelKit.box(_body, Vector3(0.95, 0.08, 0.46), Vector3(0.1, -0.18, 0), under)
			for side: float in [1.0, -1.0]:
				ModelKit.box(_body, Vector3(0.7, 0.1, 0.36), Vector3(0.32, 0.33 * side, 0), coral, Vector3(0, 0, 42.0 * side))
				ModelKit.box(_body, Vector3(0.22, 0.12, 0.38), Vector3(0.55, 0.58 * side, 0), armor, Vector3(0, 0, 42.0 * side))
				ModelKit.sphere(_body, 0.04, Vector3(0.62, 0.62 * side, 0.2), ModelKit.emissive(Color("ff5a3c") if side > 0 else Color("7dff8a"), 2.6))
				_engine(Vector3(0.58, 0.1 * side, 0), 0.08, 0.8)
			core_pos = Vector3(-0.2, 0.17, 0.12)
			core_radius = 0.13
		Kind.LANCER:
			# LANCER: armoured cockpit pod carrying two long lance cannons on pylons.
			ModelKit.box(_body, Vector3(0.9, 0.5, 0.6), Vector3(0.2, 0, 0), armor)
			ModelKit.prism(_body, Vector3(0.5, 0.5, 0.6), Vector3(-0.45, 0, 0), coral, Vector3(0, 0, 90))
			ModelKit.box(_body, Vector3(0.5, 0.12, 0.62), Vector3(0.2, 0.3, 0), coral)
			for side: float in [1.0, -1.0]:
				ModelKit.box(_body, Vector3(0.14, 0.34, 0.2), Vector3(0.1, 0.36 * side, 0), metal)
				ModelKit.hex_x(_body, 0.1, 1.5, Vector3(-0.35, 0.5 * side, 0), metal, 6)
				ModelKit.hex_x(_body, 0.14, 0.4, Vector3(0.25, 0.5 * side, 0), coral, 6)
				ModelKit.cone_x(_body, 0.1, 0.3, Vector3(-1.2, 0.5 * side, 0), coral, 6, true)
			_engine(Vector3(0.68, 0.12, 0), 0.12, 1.0)
			_engine(Vector3(0.68, -0.12, 0), 0.12, 1.0)
			core_pos = Vector3(-0.2, 0.12, 0.32)
		Kind.GUNPOD:
			# FRIGATE: stubby gunboat — slanted bow, keel, rotating turret on the back, engine block.
			ModelKit.box(_body, Vector3(1.1, 0.7, 0.8), Vector3(0.15, -0.05, 0), ModelKit.hull(Palette.ENEMY_DARK_RED, line, 0.4))
			ModelKit.prism(_body, Vector3(0.7, 0.4, 0.8), Vector3(-0.58, -0.05, 0), coral, Vector3(0, 0, 90))
			ModelKit.box(_body, Vector3(1.2, 0.18, 0.5), Vector3(0.1, -0.48, 0), under)
			ModelKit.box(_body, Vector3(0.7, 0.16, 0.82), Vector3(0.25, 0.34, 0), coral)
			ModelKit.sphere(_body, 0.3, Vector3(0.05, 0.42, 0), armor, Vector3(1.2, 0.7, 1.0))
			_barrel_pivot = ModelKit.group(_body, "Barrel", Vector3(0.0, 0.5, 0.25))
			ModelKit.hex_x(_barrel_pivot, 0.1, 0.9, Vector3(-0.5, 0, 0), metal, 6, 0.8)
			ModelKit.hex_x(_barrel_pivot, 0.13, 0.1, Vector3(-0.95, 0, 0), coral, 6)
			for y: float in [0.12, -0.22]:
				_engine(Vector3(0.75, y, 0), 0.13, 1.0)
			core_pos = Vector3(-0.3, 0.12, 0.42)
			core_radius = 0.12
		Kind.RAMMER:
			# RAM: armoured wedge prow, spiked cheeks, three heavy thrusters — built to collide.
			ModelKit.cone_x(_body, 0.5, 0.9, Vector3(-0.5, 0, 0), metal, 5, true)
			ModelKit.box(_body, Vector3(0.8, 0.8, 0.75), Vector3(0.3, 0, 0), coral)
			ModelKit.box(_body, Vector3(0.82, 0.18, 0.77), Vector3(0.3, -0.36, 0), under)
			for side: float in [1.0, -1.0]:
				ModelKit.prism(_body, Vector3(0.3, 0.6, 0.3), Vector3(-0.15, 0.5 * side, 0), armor,
						Vector3(0, 0, 120.0 if side > 0 else 60.0))
			for y: float in [0.24, 0.0, -0.24]:
				_engine(Vector3(0.75, y, 0), 0.1, 1.3)
			core_pos = Vector3(0.1, 0.12, 0.4)
		Kind.GUNSHIP:
			# DESTROYER: long hull with a bridge tower, triple bow cannons, dorsal fin, engine block.
			ModelKit.hex_x(_body, 0.62, 2.8, Vector3(0.3, 0, 0), coral, 8)
			ModelKit.cone_x(_body, 0.62, 1.0, Vector3(-1.6, 0, 0), coral, 8, true)
			ModelKit.box(_body, Vector3(3.2, 0.26, 1.0), Vector3(0.2, -0.62, 0), under)
			ModelKit.box(_body, Vector3(2.4, 0.2, 1.1), Vector3(0.4, 0.55, 0), armor)
			# Bridge tower with lit windows.
			ModelKit.box(_body, Vector3(0.8, 0.5, 0.7), Vector3(0.9, 0.85, 0), armor)
			ModelKit.box(_body, Vector3(0.5, 0.3, 0.6), Vector3(0.75, 1.2, 0), coral)
			ModelKit.box(_body, Vector3(0.46, 0.08, 0.02), Vector3(0.72, 1.2, 0.31), ModelKit.emissive(SENSOR, 2.0))
			ModelKit.prism(_body, Vector3(0.9, 0.5, 0.12), Vector3(1.5, 0.7, 0), under, Vector3(0, 0, 90))
			for y: float in [0.3, 0.0, -0.3]:
				ModelKit.hex_x(_body, 0.1, 0.9, Vector3(-2.2, y, 0.3), metal, 6)
			for y: float in [0.3, -0.3]:
				ModelKit.cylinder(_body, 0.18, 0.18, 0.2, Vector3(-0.2, y * 1.6, 0.55), metal, Vector3(90, 0, 0), 8)
			for y: float in [0.35, 0.0, -0.35]:
				_engine(Vector3(1.75, y, 0), 0.2, 1.6)
			for k in 5:
				ModelKit.box(_body, Vector3(0.14, 0.06, 0.02), Vector3(-0.8 + k * 0.38, 0.12, 0.63), ModelKit.emissive(SENSOR, 1.6))
			core_pos = Vector3(0.1, 0.1, 0.66)
			core_radius = 0.3
		Kind.TESLA:
			# ARC CRUISER: round hull with twin forward prongs wrapped in violet coils.
			ModelKit.sphere(_body, 0.75, Vector3(0.35, 0, 0), ModelKit.hull(Palette.ENEMY_DARK_RED, line, 0.4), Vector3(1.3, 0.9, 0.9))
			ModelKit.box(_body, Vector3(1.4, 0.3, 0.8), Vector3(0.45, -0.7, 0), under)
			ModelKit.box(_body, Vector3(0.6, 1.9, 0.4), Vector3(0.7, 0, -0.1), coral)
			for side: float in [1.0, -1.0]:
				ModelKit.hex_x(_body, 0.18, 1.4, Vector3(-0.55, 0.85 * side, 0), metal, 6, 0.7)
				for i in 3:
					ModelKit.cylinder(_body, 0.24, 0.24, 0.08, Vector3(-0.25 - i * 0.35, 0.85 * side, 0),
							ModelKit.emissive(Palette.RESONANCE_VIOLET, 2.0), Vector3(0, 0, 90))
				ModelKit.quad(_body, Vector2(1.0, 1.0), Vector3(-1.3, 0.85 * side, 0.3), ModelKit.glow(Palette.RESONANCE_VIOLET, ArtStyle.GLOW_STANDARD * 0.8))
				_engine(Vector3(1.25, 0.3 * side, 0), 0.16, 1.2)
			core_pos = Vector3(0.0, 0, 0.72)
			core_radius = 0.3
		Kind.WARDEN:
			# BULWARK: shield cruiser pushing a huge deflector dish ahead of its hull.
			ModelKit.hex_x(_body, 0.7, 1.6, Vector3(0.75, 0, 0), coral, 8)
			ModelKit.box(_body, Vector3(1.6, 0.3, 1.0), Vector3(0.75, -0.72, 0), under)
			ModelKit.cylinder(_body, 1.3, 1.3, 0.32, Vector3(-0.45, 0, 0), metal, Vector3(0, 0, 90), 6)
			ModelKit.cylinder(_body, 0.95, 0.95, 0.36, Vector3(-0.47, 0, 0), ModelKit.hull(Palette.PLAYER_GOLD.darkened(0.15), ArtStyle.OUTLINE_THIN), Vector3(0, 0, 90), 6)
			for side: float in [1.0, -1.0]:
				ModelKit.box(_body, Vector3(1.1, 0.42, 1.1), Vector3(0.9, 0.95 * side, 0), armor)
				_engine(Vector3(1.6, 0.4 * side, 0), 0.2, 1.4)
			_shield_rim = ModelKit.quad(_body, Vector2.ONE * 3.0, Vector3(-0.7, 0, 0.3), ModelKit.glow(Palette.ECHO_GOLD, ArtStyle.GLOW_SUBTLE, ModelKit.GlowShape.RING))
			core_pos = Vector3(-0.62, 0, 0.12)
			core_radius = 0.3

		Kind.WALKER:
			# Security walker, origin at its feet: angular torso, mono-eye visor, shoulder gun,
			# digitigrade legs (animated as it moves).
			var torso := ModelKit.group(_body, "Torso", Vector3(0.05, 1.45, 0))
			ModelKit.box(torso, Vector3(1.0, 0.72, 0.86), Vector3.ZERO, coral)
			ModelKit.prism(torso, Vector3(0.36, 0.6, 0.84), Vector3(-0.64, -0.02, 0), coral, Vector3(0, 0, 90))
			ModelKit.box(torso, Vector3(1.02, 0.18, 0.88), Vector3(0, -0.4, 0), under)
			ModelKit.box(torso, Vector3(0.14, 0.12, 0.7), Vector3(-0.72, 0.1, 0), metal)
			ModelKit.box(torso, Vector3(0.5, 0.36, 0.7), Vector3(0.55, 0.12, 0), armor)
			ModelKit.cylinder(torso, 0.02, 0.02, 0.6, Vector3(0.6, 0.6, -0.25), metal, Vector3(0, 0, 10), 6)
			ModelKit.sphere(torso, 0.05, Vector3(0.65, 0.9, -0.25), _core_material)
			ModelKit.hex_x(torso, 0.13, 0.85, Vector3(-0.75, -0.1, 0.5), metal, 8)
			ModelKit.hex_x(torso, 0.17, 0.14, Vector3(-1.18, -0.1, 0.5), armor, 8)
			ModelKit.box(torso, Vector3(0.4, 0.3, 0.2), Vector3(-0.2, -0.1, 0.48), armor)
			for side: float in [1.0, -1.0]:
				var leg := ModelKit.group(_body, "Leg", Vector3(0.1, 1.05, 0.28 * side))
				ModelKit.sphere(leg, 0.14, Vector3.ZERO, metal)
				ModelKit.box(leg, Vector3(0.26, 0.55, 0.24), Vector3(0.1, -0.25, 0), armor, Vector3(0, 0, -25))
				ModelKit.box(leg, Vector3(0.18, 0.55, 0.18), Vector3(0.12, -0.72, 0), metal, Vector3(0, 0, 18))
				ModelKit.box(leg, Vector3(0.56, 0.14, 0.32), Vector3(-0.05, -0.98, 0), under)
				ModelKit.prism(leg, Vector3(0.16, 0.2, 0.3), Vector3(-0.38, -0.98, 0), coral, Vector3(0, 0, 90))
				_legs.append(leg)
			core_pos = Vector3(-0.75, 1.55, 0.3)
			core_radius = 0.12
		Kind.TROOPER:
			# Shield trooper (Sniper Joe-style), origin at its feet: humanoid with a mono-eye
			# helmet and a rifle arm; the enemy adds the shield in front.
			ModelKit.box(_body, Vector3(0.62, 0.7, 0.6), Vector3(0.05, 1.35, 0), coral)
			ModelKit.box(_body, Vector3(0.66, 0.16, 0.64), Vector3(0.05, 1.0, 0), under)
			ModelKit.box(_body, Vector3(0.3, 0.5, 0.54), Vector3(0.4, 1.4, 0), armor)
			ModelKit.sphere(_body, 0.3, Vector3(0.0, 1.95, 0), coral, Vector3(1.0, 0.95, 1.0))
			ModelKit.box(_body, Vector3(0.5, 0.1, 0.62), Vector3(0.0, 2.05, 0), under)
			ModelKit.box(_body, Vector3(0.12, 0.1, 0.44), Vector3(-0.28, 1.93, 0), metal)
			ModelKit.hex_x(_body, 0.1, 0.8, Vector3(-0.5, 1.3, -0.38), metal, 8)
			ModelKit.sphere(_body, 0.2, Vector3(0.05, 1.62, -0.38), armor)
			for side: float in [1.0, -1.0]:
				var leg := ModelKit.group(_body, "Leg", Vector3(0.05, 0.95, 0.18 * side))
				ModelKit.box(leg, Vector3(0.24, 0.5, 0.22), Vector3(0, -0.25, 0), armor)
				ModelKit.box(leg, Vector3(0.26, 0.45, 0.24), Vector3(0.02, -0.68, 0), coral)
				ModelKit.box(leg, Vector3(0.44, 0.12, 0.28), Vector3(-0.06, -0.9, 0), under)
				_legs.append(leg)
			core_pos = Vector3(-0.3, 1.95, 0.12)
			core_radius = 0.1
		Kind.HOPPER:
			# Spring frog-bot: squat domed body, one big eye, folded piston hind legs.
			ModelKit.sphere(_body, 0.62, Vector3(0, 1.0, 0), coral, Vector3(1.15, 0.8, 0.95))
			ModelKit.sphere(_body, 0.42, Vector3(0.1, 1.35, 0), armor, Vector3(1.0, 0.6, 0.9))
			ModelKit.box(_body, Vector3(1.1, 0.16, 0.95), Vector3(0, 0.66, 0), under)
			ModelKit.cylinder(_body, 0.26, 0.26, 0.12, Vector3(-0.55, 1.05, 0.25), metal, Vector3(0, 0, 90), 12)
			for side: float in [1.0, -1.0]:
				var leg := ModelKit.group(_body, "Leg", Vector3(0.45, 0.8, 0.42 * side))
				ModelKit.box(leg, Vector3(0.62, 0.24, 0.2), Vector3(0.1, 0.1, 0), coral, Vector3(0, 0, -35))
				ModelKit.box(leg, Vector3(0.14, 0.6, 0.14), Vector3(0.28, -0.32, 0), metal, Vector3(0, 0, 25))
				ModelKit.cylinder(leg, 0.05, 0.05, 0.4, Vector3(0.12, -0.2, 0.1 * side), ModelKit.emissive(ENGINE, 2.0), Vector3(0, 0, 25), 6)
				ModelKit.box(leg, Vector3(0.5, 0.1, 0.3), Vector3(0.1, -0.68, 0), under)
				ModelKit.box(_body, Vector3(0.12, 0.45, 0.12), Vector3(-0.45, 0.35, 0.3 * side), metal, Vector3(0, 0, -15))
				_legs.append(leg)
			core_pos = Vector3(-0.6, 1.05, 0.33)
			core_radius = 0.17
		Kind.SENTRY:
			# Deck turret: armoured base, rotating dome and a twin cannon that tracks you.
			ModelKit.box(_body, Vector3(1.4, 0.3, 1.1), Vector3(0, -0.62, 0), metal)
			ModelKit.box(_body, Vector3(1.1, 0.25, 0.9), Vector3(0, -0.4, 0), under)
			LevelKit.stripes(_body, -0.7, -0.7, 1.4)
			ModelKit.sphere(_body, 0.55, Vector3(0, -0.1, 0), coral, Vector3(1.0, 0.8, 0.9))
			ModelKit.box(_body, Vector3(1.0, 0.12, 0.95), Vector3(0, -0.25, 0), armor)
			_barrel_pivot = ModelKit.group(_body, "Barrel", Vector3(0, 0.0, 0))
			for side: float in [1.0, -1.0]:
				ModelKit.hex_x(_barrel_pivot, 0.09, 0.9, Vector3(-0.7, 0, 0.16 * side), metal, 8)
				ModelKit.hex_x(_barrel_pivot, 0.12, 0.14, Vector3(-1.1, 0, 0.16 * side), armor, 8)
			ModelKit.box(_barrel_pivot, Vector3(0.5, 0.3, 0.5), Vector3(-0.3, 0, 0), armor)
			core_pos = Vector3(-0.3, 0.2, 0.4)
			core_radius = 0.12
		Kind.FLYBOT:
			# Hover drone: round armoured body, big mono-eye, two rotor pods, chin gun.
			ModelKit.sphere(_body, 0.5, Vector3.ZERO, coral, Vector3(1.1, 0.9, 0.95))
			ModelKit.cylinder(_body, 0.52, 0.52, 0.16, Vector3(0, -0.05, 0), under, Vector3.ZERO, 20)
			ModelKit.cylinder(_body, 0.28, 0.28, 0.1, Vector3(-0.5, 0.05, 0.1), metal, Vector3(0, 0, 90), 16)
			ModelKit.hex_x(_body, 0.07, 0.4, Vector3(-0.35, -0.45, 0), metal, 8)
			ModelKit.cylinder(_body, 0.015, 0.015, 0.5, Vector3(0.2, 0.6, 0), metal, Vector3(0, 0, -15), 6)
			for side: float in [1.0, -1.0]:
				ModelKit.box(_body, Vector3(0.12, 0.08, 0.5), Vector3(0.1, 0.2, 0.5 * side), armor)
				var pod := ModelKit.group(_body, "Rotor", Vector3(0.1, 0.3, 0.85 * side))
				ModelKit.cylinder(pod, 0.18, 0.2, 0.2, Vector3.ZERO, armor, Vector3.ZERO, 12)
				var disc := ModelKit.cylinder(pod, 0.48, 0.48, 0.02, Vector3(0, 0.14, 0), ModelKit.glow(Color(1.0, 0.7, 0.5), 0.35), Vector3.ZERO, 20)
				disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_spinners.append(pod)
			core_pos = Vector3(-0.55, 0.05, 0.16)
			core_radius = 0.17
		Kind.DIVER:
			# Bat drone: blade body, hooked beak, swept membrane wings that flap.
			ModelKit.hex_x(_body, 0.25, 1.1, Vector3(0.1, 0, 0), coral, 8, 0.6)
			ModelKit.cone_x(_body, 0.2, 0.5, Vector3(-0.7, -0.05, 0), armor, 6, true)
			ModelKit.prism(_body, Vector3(0.3, 0.4, 0.1), Vector3(0.45, 0.25, 0), under, Vector3(0, 0, -30))
			for side: float in [1.0, -1.0]:
				var wing := ModelKit.group(_body, "Wing", Vector3(0.0, 0.1, 0.2 * side))
				ModelKit.box(wing, Vector3(0.9, 0.06, 0.9), Vector3(0.25, 0, 0.45 * side), under, Vector3(0, 20 * side, 0))
				ModelKit.box(wing, Vector3(1.0, 0.08, 0.08), Vector3(0.1, 0.03, 0.85 * side), coral, Vector3(0, 30 * side, 0))
				ModelKit.prism(wing, Vector3(0.14, 0.3, 0.08), Vector3(0.5, -0.1, 0.95 * side), armor, Vector3(0, 0, 180))
				_wing_nodes.append(wing)
			core_pos = Vector3(-0.35, 0.1, 0.24)
			core_radius = 0.1

	# Ground robots turn three-quarters toward the camera so they read as solid machines
	# (stays correct when the enemy mirrors its facing root).
	if kind in GROUND_KINDS:
		_body.rotation.y = GROUND_YAW
		if _barrel_pivot:
			_barrel_pivot.rotation.y = -GROUND_YAW
	ModelKit.sphere(_body, core_radius, core_pos, _core_material)
	ModelKit.quad(_body, Vector2.ONE * core_radius * 3.2, core_pos + Vector3(0, 0, 0.1), ModelKit.glow(core_color, 0.6))
	if elite:
		_build_echo_marker(core_pos, core_radius)


## Rear thruster: dark nozzle, hot core disc and an exhaust flame streaming back (+X).
func _engine(at: Vector3, radius: float, flame: float) -> void:
	var nozzle := ModelKit.hull(METAL.darkened(0.3), ArtStyle.OUTLINE_THIN, 0.3)
	ModelKit.hex_x(_body, radius, radius * 1.6, at, nozzle, 8, 1.2)
	ModelKit.cylinder(_body, radius * 0.8, radius * 0.8, 0.02, at + Vector3(radius * 0.82, 0, 0), ModelKit.emissive(ENGINE, 3.0), Vector3(0, 0, 90), 8)
	var plume := ModelKit.quad(_body, Vector2(flame, radius * 2.4), at + Vector3(radius + flame * 0.5, 0, 0.02), ModelKit.glow(ENGINE, 1.4, ModelKit.GlowShape.STREAK), Vector3(0, 0, 180))
	_flames.append(plume)


## Echo carrier marker: pulsing ring, three orbiting gold fragments, faint vertical beacon.
func _build_echo_marker(core_pos: Vector3, core_radius: float) -> void:
	_elite_ring = ModelKit.quad(self, Vector2.ONE * core_radius * 7.0, core_pos + Vector3(0, 0, 0.15),
			ModelKit.glow(Palette.ECHO_GOLD, 1.4, ModelKit.GlowShape.RING))
	_fragments = ModelKit.group(self, "EchoFragments", core_pos + Vector3(0, 0, 0.1))
	var gold := ModelKit.hull(Palette.ECHO_GOLD, ArtStyle.OUTLINE_THIN, 0.6)
	for i in 3:
		var a := TAU * i / 3.0
		ModelKit.prism(_fragments, Vector3(0.22, 0.3, 0.16), Vector3(cos(a), sin(a), 0) * core_radius * 3.2, gold,
				Vector3(0, 0, rad_to_deg(a) - 90.0))
	_beacon = ModelKit.quad(self, Vector2(0.28, 9.0), Vector3(core_pos.x, 0, -0.6),
			ModelKit.glow(Palette.ECHO_GOLD, ArtStyle.GLOW_SUBTLE * 0.5, ModelKit.GlowShape.RADIAL))


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _core_material == null:
		return
	_time += delta
	for i in _flames.size():
		_flames[i].scale = Vector3(0.85 + 0.25 * sin(_time * 34.0 + i * 1.7), 1.0, 1.0)
	_core_material.emission_energy_multiplier = 2.2 + 1.3 * sin(_time * 6.0) + _charge * 2.0
	var flash := ArtStyle.flash_scale()
	if _elite_ring:
		var pulse := fmod(_time * 0.7, 1.0)
		_elite_ring.scale = Vector3.ONE * (0.6 + pulse * 0.8)
		(_elite_ring.material_override as ShaderMaterial).set_shader_parameter(&"energy", 1.6 * (1.0 - pulse) * lerpf(0.5, 1.0, flash))
	if _fragments:
		_fragments.rotation.z += delta * 1.6
		for frag in _fragments.get_children():
			(frag as Node3D).rotation.z -= delta * 1.6
	if _beacon:
		var target := (0.45 if targetable else 0.12) * (0.8 + 0.2 * sin(_time * 2.0))
		var mat := _beacon.material_override as ShaderMaterial
		mat.set_shader_parameter(&"energy", lerpf(float(mat.get_shader_parameter(&"energy")), target, 0.1))
	if _shield_rim:
		(_shield_rim.material_override as ShaderMaterial).set_shader_parameter(&"energy", 0.5 + 0.3 * sin(_time * 3.0))
	if _barrel_pivot:
		var player := Players.find(get_tree())
		if player:
			var to_player := player.global_position - _barrel_pivot.global_position
			_barrel_pivot.rotation.z = lerp_angle(_barrel_pivot.rotation.z, atan2(-to_player.y, -to_player.x), 0.15)
	# Walk cycle from real movement; rotors spin; wings flap.
	var moved := absf(global_position.x - _last_x)
	_last_x = global_position.x
	_stride += moved * 5.0
	var swing := sin(_stride) * clampf(moved / maxf(delta, 0.001) * 0.25, 0.0, 0.5)
	for i in _legs.size():
		_legs[i].rotation.z = swing * (1.0 if i % 2 == 0 else -1.0)
	for pod in _spinners:
		pod.rotation.y += delta * 30.0
	for i in _wing_nodes.size():
		_wing_nodes[i].rotation.x = sin(_time * 12.0) * 0.5 * (1.0 if i % 2 == 0 else -1.0)
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 6.0)
	_body.position.x = _recoil * 0.25
	# Anticipation: swell slightly while charging a shot.
	_body.scale = Vector3.ONE * (1.0 + _charge * 0.08)
