class_name Checkpoint
extends Area3D
## Touch to set the respawn point. The beacon turns from dim gold to live cyan.

signal reached(checkpoint: Checkpoint)

var active: bool = false

var _lamp: StandardMaterial3D
var _beam: MeshInstance3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.HURTBOX
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 5.0, 2.0)
	shape.shape = box
	shape.position = Vector3(0, 2.5, 0)
	add_child(shape)
	ModelKit.box(self, Vector3(0.9, 0.3, 1.2), Vector3(0, 0.15, -0.6), LevelKit.material(&"trim"))
	ModelKit.box(self, Vector3(0.2, 2.6, 0.2), Vector3(0, 1.4, -0.6), LevelKit.material(&"hull_dark"))
	_lamp = ModelKit.emissive(Palette.UI_GOLD, 1.0)
	ModelKit.sphere(self, 0.28, Vector3(0, 2.8, -0.6), _lamp)
	_beam = ModelKit.quad(self, Vector2(0.6, 6.0), Vector3(0, 3.0, -0.8), ModelKit.glow(Palette.PLAYER_ENERGY, 0.0))
	area_entered.connect(_on_area_entered)


func activate() -> void:
	if active:
		return
	active = true
	AudioService.play(&"checkpoint")
	_lamp.albedo_color = Palette.PLAYER_ENERGY
	_lamp.emission = Palette.PLAYER_ENERGY
	_lamp.emission_energy_multiplier = 3.0
	(_beam.material_override as ShaderMaterial).set_shader_parameter(&"energy", 0.8)
	Vfx.spawn(get_tree(), preload("res://vfx/collect_burst.tscn"), global_position + Vector3(0, 2.8, 0), 1.2, {&"color": Palette.PLAYER_ENERGY})
	reached.emit(self)


func _on_area_entered(area: Area3D) -> void:
	if area.get_parent() != null and area.get_parent().is_in_group(Players.GROUP):
		activate()
