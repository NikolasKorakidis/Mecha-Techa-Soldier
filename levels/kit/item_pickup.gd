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
	ModelKit.quad(_visual, Vector2.ONE * (2.6 if kind in [Kind.HEART, Kind.TANK] else 1.6), Vector3(0, 0, -0.2), ModelKit.glow(color, 1.0))
	if kind == Kind.HEART:
		# Heart Tank: gold-framed capsule with a glowing heart core.
		var gold := ModelKit.glossy(Palette.PLAYER_GOLD)
		ModelKit.with_outline(gold, ArtStyle.OUTLINE_THIN)
		ModelKit.box(_visual, Vector3(0.8, 1.0, 0.6), Vector3.ZERO, gold)
		ModelKit.sphere(_visual, 0.26, Vector3(-0.1, 0.08, 0.32), ModelKit.emissive(color, 3.0))
		ModelKit.sphere(_visual, 0.26, Vector3(0.1, 0.08, 0.32), ModelKit.emissive(color, 3.0))
		ModelKit.prism(_visual, Vector3(0.52, 0.34, 0.2), Vector3(0, -0.14, 0.32), ModelKit.emissive(color, 3.0), Vector3(0, 0, 180))
	elif kind == Kind.TANK:
		ModelKit.hex_x(_visual, 0.42, 0.9, Vector3.ZERO, ModelKit.hull(Palette.PLAYER_SECONDARY, ArtStyle.OUTLINE_THIN), 8)
		ModelKit.box(_visual, Vector3(0.5, 0.5, 0.9), Vector3.ZERO, ModelKit.emissive(color, 3.0))
		var label := Label3D.new()
		label.text = "E"
		label.font_size = 64
		label.pixel_size = 0.01
		label.position = Vector3(0, 0, 0.5)
		_visual.add_child(label)
	elif kind == Kind.HEALTH:
		ModelKit.hex_x(_visual, 0.26, 0.8, Vector3.ZERO, ModelKit.hull(Palette.PLAYER_PRIMARY, ArtStyle.OUTLINE_THIN), 8)
		ModelKit.box(_visual, Vector3(0.34, 0.12, 0.6), Vector3(0, 0, 0.1), ModelKit.emissive(color, 2.2))
		ModelKit.box(_visual, Vector3(0.12, 0.34, 0.6), Vector3(0, 0, 0.1), ModelKit.emissive(color, 2.2))
	else:
		ModelKit.box(_visual, Vector3.ONE * 0.5, Vector3.ZERO, ModelKit.emissive(color, 2.4), Vector3(45, 0, 45))


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
