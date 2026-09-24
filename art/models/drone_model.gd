@tool
class_name DroneModel
extends Node3D
## Foundry drone (faces -X): angular coral hull, dark armor, pulsing orange core.

const CORAL := Color("ff5a4e")
const ARMOR := Color("3b1726")
const CORE := Color("ff8a1f")

var _core_material: StandardMaterial3D
var _time: float = 0.0


func _ready() -> void:
	ModelKit.clear(self)
	var coral := ModelKit.toon(CORAL, 0.55, 0.5, 0.15)
	var armor := ModelKit.toon(ARMOR, 0.4, 0.4, 0.4)
	_core_material = ModelKit.emissive(CORE, 3.0)

	ModelKit.prism(self, Vector3(1.0, 1.35, 0.7), Vector3(-0.1, 0.0, 0.0), coral, Vector3(0, 0, 90))
	ModelKit.box(self, Vector3(0.55, 0.9, 0.8), Vector3(0.45, 0.0, 0.0), armor)
	for side: float in [1.0, -1.0]:
		ModelKit.prism(self, Vector3(0.5, 0.9, 0.3), Vector3(0.55, 0.55 * side, 0.0), coral,
				Vector3(0, 0, -150.0 if side > 0 else -30.0))
		ModelKit.box(self, Vector3(0.7, 0.1, 0.9), Vector3(0.05, 0.36 * side, 0.0), armor, Vector3(0, 0, 18.0 * side))
	ModelKit.sphere(self, 0.2, Vector3(0.2, 0.0, 0.38), _core_material)
	ModelKit.quad(self, Vector2(0.8, 0.8), Vector3(0.2, 0.0, 0.45), ModelKit.glow(CORE, 0.8))


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _core_material == null:
		return
	_time += delta
	_core_material.emission_energy_multiplier = 2.2 + 1.3 * sin(_time * 6.0)
