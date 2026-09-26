class_name ItemPickup
extends Area3D
## Health capsule (+2 HP), energy cell (+1 SUPER segment), and the hidden upgrades:
## HEART (Heart Tank: +1 max health for the run) and TANK (Energy Tank: SUPER fully charged).

enum Kind { HEALTH, ENERGY, HEART, TANK }

@export var kind: Kind = Kind.HEALTH
@export var amount: int = 2

var _visual: Node3D
var _time: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.HURTBOX
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	shape.shape = sphere
	add_child(shape)
	area_entered.connect(_on_area_entered)
	_visual = ModelKit.group(self, "Visual")
	var color := Palette.HEALTH_GREEN if kind in [Kind.HEALTH, Kind.HEART] else Palette.RESONANCE_VIOLET
	var model := ItemCapsuleModel.new()
	_visual.add_child(model)
	match kind:
		Kind.HEALTH:
			model.build_medkit(color)
		Kind.ENERGY:
			model.build_cell(color)
		Kind.HEART:
			model.build_heart_tank(color)
		Kind.TANK:
			model.build_energy_tank(color)


func _physics_process(delta: float) -> void:
	_time += delta
	_visual.position.y = sin(_time * 3.0) * 0.15
	_visual.rotation.y += delta * 2.0


func _on_area_entered(area: Area3D) -> void:
	var player := area.get_parent()
	if player == null or not player.is_in_group(Players.GROUP):
		return
	var health := player.get(&"health") as HealthComponent
	match kind:
		Kind.HEALTH:
			health.heal(amount)
			AudioService.play(&"pickup")
		Kind.ENERGY:
			RunSession.add_energy(amount)
			AudioService.play(&"pickup")
		Kind.HEART:
			RunSession.increase_max_health(1)
			health.setup(RunSession.max_health, RunSession.max_health)
			AudioService.play(&"weapon_get")
			_announce("HEART TANK", "MAX HEALTH UP")
		Kind.TANK:
			RunSession.add_energy(RunSession.MAX_ENERGY)
			AudioService.play(&"weapon_get")
			_announce("ENERGY TANK", "SUPER FULLY CHARGED")
	Vfx.spawn(get_tree(), preload("res://vfx/collect_burst.tscn"), global_position, 0.8,
			{&"color": Palette.HEALTH_GREEN if kind == Kind.HEALTH else Palette.RESONANCE_VIOLET})
	queue_free()


func _announce(title: String, subtitle: String) -> void:
	var ui := StageUI.find(get_tree())
	if ui:
		ui.show_banner(title, subtitle, 2.2)
