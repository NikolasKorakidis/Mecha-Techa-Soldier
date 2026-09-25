@tool
class_name EnemyModel
extends Node3D
## Enemy family (all face -X). Space kinds are real ships — nose, canopy light, swept wings or
## pylons, glowing rear thrusters — in coral armour over dark-red undersides with chunky outlines. Echo carriers (elites) add a gold-white core,
## orbiting gold fragments, a slow pulsing ring and a faint vertical beacon — never color alone.

enum Kind { DRONE, NEEDLE, LANCER, GUNPOD, RAMMER, GUNSHIP, TESLA, WARDEN, WALKER, HOPPER }

const SENSOR := Color("ffc36a")
const METAL := Color("3d2f45")
const ENGINE := Color("ff6a3c")

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
	var elite := is_elite_kind()
	var line := ArtStyle.OUTLINE_THICK if elite else ArtStyle.OUTLINE_THIN
	# Low rim keeps the coral saturated instead of washing toward pink.
	var coral := ModelKit.hull(Palette.ENEMY_CORAL, line, 0.18)
	var under := ModelKit.hull(Palette.ENEMY_DARK_RED, line, 0.15)
	var armor := ModelKit.hull(Palette.ENEMY_DARK_RED.darkened(0.35), line, 0.35)
	var metal := ModelKit.hull(METAL, ArtStyle.OUTLINE_THIN, 0.35)
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
			# Two-legged gun-bot, origin at its feet.
			ModelKit.box(_body, Vector3(1.1, 0.8, 0.9), Vector3(0.05, 1.45, 0), coral)
			ModelKit.box(_body, Vector3(1.12, 0.22, 0.92), Vector3(0.05, 1.08, 0), under)
			ModelKit.hex_x(_body, 0.16, 0.8, Vector3(-0.75, 1.4, 0.3), metal, 6)
			for side: float in [1.0, -1.0]:
				ModelKit.box(_body, Vector3(0.22, 0.75, 0.22), Vector3(0.1, 0.62, 0.3 * side), armor, Vector3(0, 0, -12))
				ModelKit.box(_body, Vector3(0.5, 0.16, 0.34), Vector3(-0.02, 0.1, 0.3 * side), under)
			core_pos = Vector3(-0.1, 1.5, 0.48)
		Kind.HOPPER:
			ModelKit.sphere(_body, 0.62, Vector3(0, 1.0, 0), coral, Vector3(1.15, 0.85, 0.9))
			ModelKit.box(_body, Vector3(1.0, 0.18, 0.95), Vector3(0, 0.62, 0), under)
			for side: float in [1.0, -1.0]:
				ModelKit.prism(_body, Vector3(0.3, 0.7, 0.3), Vector3(0.35 * side, 0.3, 0.2), armor, Vector3(0, 0, 180))
				ModelKit.prism(_body, Vector3(0.25, 0.4, 0.2), Vector3(0.2 * side, 1.55, 0.15), coral)
			core_pos = Vector3(-0.35, 1.05, 0.5)
			core_radius = 0.18

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
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 6.0)
	_body.position.x = _recoil * 0.25
	# Anticipation: swell slightly while charging a shot.
	_body.scale = Vector3.ONE * (1.0 + _charge * 0.08)
