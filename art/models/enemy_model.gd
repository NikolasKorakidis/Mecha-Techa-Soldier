@tool
class_name EnemyModel
extends Node3D
## Foundry enemy family (all face -X). Coral armor over dark-red undersides, a readable sensor
## "face" on the camera side, chunky outlines. Echo carriers (elites) add a gold-white core,
## orbiting gold fragments, a slow pulsing ring and a faint vertical beacon — never color alone.

enum Kind { DRONE, NEEDLE, LANCER, GUNPOD, RAMMER, GUNSHIP, TESLA, WARDEN, WALKER, HOPPER }

const SENSOR := Color("ffc36a")
const METAL := Color("3d2f45")

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
			# Narrow arrowhead, two small fins, sensor near the tip.
			ModelKit.cone_x(_body, 0.26, 1.5, Vector3(-0.35, 0.02, 0.0), coral, 4, true)
			ModelKit.box(_body, Vector3(0.7, 0.2, 0.38), Vector3(0.6, 0.02, 0.0), coral)
			ModelKit.box(_body, Vector3(1.3, 0.1, 0.34), Vector3(0.05, -0.16, 0.0), under)
			for side: float in [1.0, -1.0]:
				ModelKit.prism(_body, Vector3(0.26, 0.5, 0.16), Vector3(0.78, 0.24 * side, 0.0), under,
						Vector3(0, 0, -135.0 if side > 0 else -45.0))
			core_pos = Vector3(-0.35, 0.05, 0.22)
			core_radius = 0.1
		Kind.DRONE:
			ModelKit.prism(_body, Vector3(1.0, 1.3, 0.7), Vector3(-0.1, 0.05, 0), coral, Vector3(0, 0, 90))
			ModelKit.box(_body, Vector3(0.55, 0.85, 0.8), Vector3(0.45, 0, 0), armor)
			ModelKit.box(_body, Vector3(0.9, 0.18, 0.72), Vector3(0.05, -0.42, 0), under)
			for side: float in [1.0, -1.0]:
				ModelKit.prism(_body, Vector3(0.45, 0.8, 0.28), Vector3(0.6, 0.55 * side, 0), coral,
						Vector3(0, 0, -150.0 if side > 0 else -30.0))
		Kind.LANCER:
			ModelKit.box(_body, Vector3(0.9, 0.7, 0.7), Vector3(0.3, 0, 0), armor)
			ModelKit.prism(_body, Vector3(0.7, 0.7, 0.72), Vector3(-0.35, 0, 0), coral, Vector3(0, 0, 90))
			for side: float in [1.0, -1.0]:
				ModelKit.box(_body, Vector3(1.6, 0.16, 0.3), Vector3(-0.35, 0.5 * side, 0), under)
				ModelKit.cone_x(_body, 0.14, 0.5, Vector3(-1.4, 0.5 * side, 0), coral, 4, true)
			core_pos = Vector3(0.3, 0, 0.38)
		Kind.GUNPOD:
			ModelKit.sphere(_body, 0.75, Vector3(0.1, 0, 0), ModelKit.hull(Palette.ENEMY_DARK_RED, line, 0.4), Vector3(1.0, 0.85, 0.9))
			ModelKit.box(_body, Vector3(1.3, 0.35, 1.1), Vector3(0.2, -0.55, 0), under)
			ModelKit.box(_body, Vector3(1.0, 0.25, 1.0), Vector3(0.2, 0.62, 0), coral)
			_barrel_pivot = ModelKit.group(_body, "Barrel", Vector3(-0.1, 0, 0.3))
			ModelKit.hex_x(_barrel_pivot, 0.16, 1.0, Vector3(-0.55, 0, 0), metal, 6, 0.8)
			ModelKit.hex_x(_barrel_pivot, 0.19, 0.12, Vector3(-1.05, 0, 0), coral, 6)
			core_pos = Vector3(0.35, 0.1, 0.62)
			core_radius = 0.18
		Kind.RAMMER:
			ModelKit.cone_x(_body, 0.55, 1.1, Vector3(-0.55, 0, 0), metal, 5, true)
			ModelKit.box(_body, Vector3(0.9, 0.9, 0.8), Vector3(0.35, 0, 0), coral)
			ModelKit.box(_body, Vector3(0.9, 0.2, 0.82), Vector3(0.35, -0.45, 0), under)
			for side: float in [1.0, -1.0]:
				ModelKit.prism(_body, Vector3(0.35, 0.8, 0.3), Vector3(-0.3, 0.55 * side, 0), armor,
						Vector3(0, 0, 120.0 if side > 0 else 60.0))
			ModelKit.quad(_body, Vector2(1.2, 0.7), Vector3(1.2, 0, 0), ModelKit.glow(SENSOR, ArtStyle.GLOW_STANDARD, ModelKit.GlowShape.STREAK), Vector3(0, 0, 180))
			core_pos = Vector3(0.4, 0.05, 0.42)
		Kind.GUNSHIP:
			ModelKit.box(_body, Vector3(2.6, 1.1, 1.2), Vector3(0.3, 0.05, 0), coral)
			ModelKit.cone_x(_body, 0.62, 1.2, Vector3(-1.55, 0.05, 0), coral, 6, true)
			ModelKit.box(_body, Vector3(2.8, 0.25, 1.3), Vector3(0.3, 0.64, 0), armor)
			ModelKit.box(_body, Vector3(2.8, 0.3, 1.3), Vector3(0.3, -0.6, 0), under)
			for y: float in [0.35, 0.0, -0.35]:
				ModelKit.hex_x(_body, 0.11, 0.9, Vector3(-2.1, y, 0.25), metal, 6)
			for side: float in [1.0, -1.0]:
				ModelKit.prism(_body, Vector3(0.9, 1.2, 0.4), Vector3(1.1, 1.0 * side, 0), coral,
						Vector3(0, 0, -150.0 if side > 0 else -30.0))
				ModelKit.hex_x(_body, 0.3, 0.5, Vector3(1.75, 0.35 * side, 0), metal, 8)
			core_pos = Vector3(0.3, 0.05, 0.68)
			core_radius = 0.34
		Kind.TESLA:
			ModelKit.sphere(_body, 0.85, Vector3(0.1, 0, 0), ModelKit.hull(Palette.ENEMY_DARK_RED, line, 0.4), Vector3(1, 1, 0.9))
			ModelKit.box(_body, Vector3(1.0, 2.4, 0.5), Vector3(0.45, 0, -0.1), coral)
			for side: float in [1.0, -1.0]:
				ModelKit.hex_x(_body, 0.2, 1.3, Vector3(-0.6, 0.85 * side, 0), metal, 6, 0.7)
				for i in 3:
					ModelKit.cylinder(_body, 0.25, 0.25, 0.08, Vector3(-0.3 - i * 0.35, 0.85 * side, 0),
							ModelKit.emissive(Palette.RESONANCE_VIOLET, 2.0), Vector3(0, 0, 90))
				ModelKit.quad(_body, Vector2(1.0, 1.0), Vector3(-1.3, 0.85 * side, 0.3), ModelKit.glow(Palette.RESONANCE_VIOLET, ArtStyle.GLOW_STANDARD * 0.8))
			core_pos = Vector3(0.1, 0, 0.8)
			core_radius = 0.32
		Kind.WARDEN:
			# Wide shield silhouette with heavy side plates.
			ModelKit.box(_body, Vector3(1.4, 1.7, 1.0), Vector3(0.55, 0, 0), coral)
			ModelKit.box(_body, Vector3(1.4, 0.3, 1.02), Vector3(0.55, -0.72, 0), under)
			ModelKit.cylinder(_body, 1.3, 1.3, 0.32, Vector3(-0.45, 0, 0), metal, Vector3(0, 0, 90), 6)
			ModelKit.cylinder(_body, 0.95, 0.95, 0.36, Vector3(-0.47, 0, 0), ModelKit.hull(Palette.PLAYER_GOLD.darkened(0.15), ArtStyle.OUTLINE_THIN), Vector3(0, 0, 90), 6)
			for side: float in [1.0, -1.0]:
				ModelKit.box(_body, Vector3(1.1, 0.42, 1.1), Vector3(0.9, 0.95 * side, 0), armor)
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
