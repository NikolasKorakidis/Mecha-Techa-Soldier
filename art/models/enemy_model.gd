@tool
class_name EnemyModel
extends Node3D
## Foundry enemy family (all face -X). Shared language: coral hulls, dark armor,
## glowing orange core. Elites swap the core for a gold-white one with a pulsing ring.

enum Kind { DRONE, NEEDLE, LANCER, GUNPOD, RAMMER, GUNSHIP, TESLA, WARDEN }

const CORAL := Color("ff5a4e")
const CORAL_DEEP := Color("c93a3a")
const ARMOR := Color("3b1726")
const METAL := Color("4a3a48")
const CORE := Color("ff8a1f")
const ELITE_CORE := Color("ffe08a")
const ARC_VIOLET := Color("a77bff")

@export var kind: Kind = Kind.DRONE:
	set(value):
		kind = value
		if is_inside_tree():
			_build()

var _core_material: StandardMaterial3D
var _elite_ring: MeshInstance3D
var _barrel_pivot: Node3D
var _time: float = 0.0
var _recoil: float = 0.0


func _ready() -> void:
	_build()


func is_elite_kind() -> bool:
	return kind in [Kind.GUNSHIP, Kind.TESLA, Kind.WARDEN]


## Kick the model back on each volley.
func recoil() -> void:
	_recoil = 1.0


func _build() -> void:
	ModelKit.clear(self)
	_elite_ring = null
	_barrel_pivot = null
	var coral := ModelKit.toon(CORAL, 0.55, 0.5, 0.15)
	var deep := ModelKit.toon(CORAL_DEEP, 0.5, 0.5, 0.15)
	var armor := ModelKit.toon(ARMOR, 0.4, 0.4, 0.4)
	var metal := ModelKit.toon(METAL, 0.4, 0.35, 0.6)
	var core_color := ELITE_CORE if is_elite_kind() else CORE
	_core_material = ModelKit.emissive(core_color, 3.0)
	var core_pos := Vector3(0.2, 0.0, 0.38)
	var core_radius := 0.2

	match kind:
		Kind.DRONE:
			ModelKit.prism(self, Vector3(1.0, 1.35, 0.7), Vector3(-0.1, 0, 0), coral, Vector3(0, 0, 90))
			ModelKit.box(self, Vector3(0.55, 0.9, 0.8), Vector3(0.45, 0, 0), armor)
			for side: float in [1.0, -1.0]:
				ModelKit.prism(self, Vector3(0.5, 0.9, 0.3), Vector3(0.55, 0.55 * side, 0), coral,
						Vector3(0, 0, -150.0 if side > 0 else -30.0))
				ModelKit.box(self, Vector3(0.7, 0.1, 0.9), Vector3(0.05, 0.36 * side, 0), armor, Vector3(0, 0, 18.0 * side))
		Kind.NEEDLE:
			ModelKit.prism(self, Vector3(0.42, 1.9, 0.45), Vector3(-0.2, 0, 0), coral, Vector3(0, 0, 90))
			ModelKit.box(self, Vector3(1.1, 0.12, 0.5), Vector3(0.35, 0, 0), armor)
			for side: float in [1.0, -1.0]:
				ModelKit.prism(self, Vector3(0.3, 0.6, 0.2), Vector3(0.7, 0.26 * side, 0), deep,
						Vector3(0, 0, -135.0 if side > 0 else -45.0))
			core_pos = Vector3(0.35, 0, 0.3)
			core_radius = 0.13
		Kind.LANCER:
			ModelKit.box(self, Vector3(0.9, 0.7, 0.7), Vector3(0.3, 0, 0), armor)
			ModelKit.prism(self, Vector3(0.7, 0.7, 0.72), Vector3(-0.35, 0, 0), coral, Vector3(0, 0, 90))
			for side: float in [1.0, -1.0]:
				ModelKit.box(self, Vector3(1.7, 0.16, 0.3), Vector3(-0.35, 0.5 * side, 0), deep)
				ModelKit.prism(self, Vector3(0.25, 0.5, 0.3), Vector3(-1.4, 0.5 * side, 0), coral, Vector3(0, 0, 90))
			core_pos = Vector3(0.3, 0, 0.38)
		Kind.GUNPOD:
			ModelKit.sphere(self, 0.75, Vector3(0.1, 0, 0), armor, Vector3(1.0, 0.85, 0.9))
			ModelKit.box(self, Vector3(1.3, 0.35, 1.1), Vector3(0.2, -0.55, 0), coral)
			ModelKit.box(self, Vector3(1.0, 0.25, 1.0), Vector3(0.2, 0.62, 0), coral)
			_barrel_pivot = Node3D.new()
			_barrel_pivot.position = Vector3(-0.1, 0, 0.3)
			add_child(_barrel_pivot)
			ModelKit.cylinder(_barrel_pivot, 0.13, 0.17, 1.0, Vector3(-0.55, 0, 0), metal, Vector3(0, 0, 90))
			ModelKit.cylinder(_barrel_pivot, 0.18, 0.18, 0.12, Vector3(-1.05, 0, 0), deep, Vector3(0, 0, 90))
			core_pos = Vector3(0.35, 0.1, 0.62)
			core_radius = 0.18
		Kind.RAMMER:
			ModelKit.prism(self, Vector3(1.1, 1.0, 0.9), Vector3(-0.55, 0, 0), metal, Vector3(0, 0, 90))
			ModelKit.box(self, Vector3(0.9, 0.9, 0.8), Vector3(0.35, 0, 0), coral)
			for side: float in [1.0, -1.0]:
				ModelKit.prism(self, Vector3(0.35, 0.8, 0.3), Vector3(-0.3, 0.55 * side, 0), armor,
						Vector3(0, 0, 120.0 if side > 0 else 60.0))
			ModelKit.quad(self, Vector2(1.2, 0.7), Vector3(1.2, 0, 0), ModelKit.glow(CORE, 1.6, ModelKit.GlowShape.STREAK), Vector3(0, 0, 180))
			core_pos = Vector3(0.4, 0, 0.42)
		Kind.GUNSHIP:
			ModelKit.box(self, Vector3(2.6, 1.1, 1.2), Vector3(0.3, 0, 0), coral)
			ModelKit.prism(self, Vector3(1.1, 1.0, 1.1), Vector3(-1.45, 0, 0), deep, Vector3(0, 0, 90))
			ModelKit.box(self, Vector3(2.8, 0.25, 1.3), Vector3(0.3, 0.62, 0), armor)
			ModelKit.box(self, Vector3(2.8, 0.25, 1.3), Vector3(0.3, -0.62, 0), armor)
			for y: float in [0.35, 0.0, -0.35]:
				ModelKit.cylinder(self, 0.09, 0.12, 0.9, Vector3(-2.1, y, 0.2), metal, Vector3(0, 0, 90))
			for side: float in [1.0, -1.0]:
				ModelKit.prism(self, Vector3(0.9, 1.2, 0.4), Vector3(1.1, 1.0 * side, 0), coral,
						Vector3(0, 0, -150.0 if side > 0 else -30.0))
				ModelKit.cylinder(self, 0.25, 0.3, 0.5, Vector3(1.75, 0.35 * side, 0), metal, Vector3(0, 0, 90))
			core_pos = Vector3(0.3, 0, 0.66)
			core_radius = 0.34
		Kind.TESLA:
			ModelKit.sphere(self, 0.85, Vector3(0.1, 0, 0), armor, Vector3(1, 1, 0.9))
			ModelKit.box(self, Vector3(1.0, 2.4, 0.5), Vector3(0.45, 0, -0.1), coral)
			for side: float in [1.0, -1.0]:
				ModelKit.cylinder(self, 0.14, 0.22, 1.3, Vector3(-0.6, 0.85 * side, 0), metal, Vector3(0, 0, 90))
				for i in 3:
					ModelKit.cylinder(self, 0.24, 0.24, 0.08, Vector3(-0.3 - i * 0.35, 0.85 * side, 0), ModelKit.emissive(ARC_VIOLET, 2.0), Vector3(0, 0, 90))
				ModelKit.quad(self, Vector2(1.0, 1.0), Vector3(-1.3, 0.85 * side, 0.3), ModelKit.glow(ARC_VIOLET, 1.4))
			core_pos = Vector3(0.1, 0, 0.8)
			core_radius = 0.32
		Kind.WARDEN:
			ModelKit.box(self, Vector3(1.4, 1.6, 1.0), Vector3(0.5, 0, 0), coral)
			# Hexagonal front shield plate.
			ModelKit.cylinder(self, 1.25, 1.25, 0.3, Vector3(-0.45, 0, 0), metal, Vector3(0, 0, 90), 6)
			ModelKit.cylinder(self, 0.9, 0.9, 0.34, Vector3(-0.47, 0, 0), ModelKit.toon(Color("ffc543"), 0.6, 0.3, 0.5), Vector3(0, 0, 90), 6)
			for side: float in [1.0, -1.0]:
				ModelKit.box(self, Vector3(0.9, 0.3, 0.9), Vector3(1.0, 0.85 * side, 0), armor)
			core_pos = Vector3(-0.6, 0, 0.1)
			core_radius = 0.3

	ModelKit.sphere(self, core_radius, core_pos, _core_material)
	ModelKit.quad(self, Vector2.ONE * core_radius * 4.5, core_pos + Vector3(0, 0, 0.1), ModelKit.glow(core_color, 0.9))
	if is_elite_kind():
		_elite_ring = ModelKit.quad(self, Vector2.ONE * core_radius * 7.0, core_pos + Vector3(0, 0, 0.15),
				ModelKit.glow(ELITE_CORE, 1.4, ModelKit.GlowShape.RING))


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _core_material == null:
		return
	_time += delta
	_core_material.emission_energy_multiplier = 2.2 + 1.3 * sin(_time * 6.0)
	if _elite_ring:
		var pulse := fmod(_time * 0.9, 1.0)
		_elite_ring.scale = Vector3.ONE * (0.6 + pulse * 0.8)
		(_elite_ring.material_override as ShaderMaterial).set_shader_parameter(&"energy", 1.6 * (1.0 - pulse))
	if _barrel_pivot:
		var player := get_tree().get_first_node_in_group(ShipPlayer.GROUP) as Node3D
		if player:
			var to_player := player.global_position - _barrel_pivot.global_position
			_barrel_pivot.rotation.z = lerp_angle(_barrel_pivot.rotation.z, atan2(-to_player.y, -to_player.x), 0.15)
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 6.0)
		position.x = _recoil * 0.25
