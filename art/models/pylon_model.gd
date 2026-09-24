@tool
class_name PylonModel
extends Node3D
## Armored target pylon for test rooms.

func _ready() -> void:
	ModelKit.clear(self)
	var coral := ModelKit.toon(Color("ff5a4e"), 0.5)
	var armor := ModelKit.toon(Color("3b1726"), 0.4, 0.4, 0.4)
	var core := ModelKit.emissive(Color("ff8a1f"), 2.5)
	ModelKit.box(self, Vector3(1.2, 1.7, 0.9), Vector3.ZERO, coral)
	ModelKit.prism(self, Vector3(1.2, 0.55, 0.9), Vector3(0, 1.12, 0), coral)
	ModelKit.box(self, Vector3(1.5, 0.25, 1.0), Vector3(0, -0.95, 0), armor)
	ModelKit.box(self, Vector3(0.3, 1.4, 1.0), Vector3(-0.6, 0, 0), armor)
	ModelKit.box(self, Vector3(0.3, 1.4, 1.0), Vector3(0.6, 0, 0), armor)
	ModelKit.sphere(self, 0.28, Vector3(0, 0.1, 0.45), core)
	ModelKit.quad(self, Vector2(1.1, 1.1), Vector3(0, 0.1, 0.55), ModelKit.glow(Color("ff8a1f"), 0.7))
