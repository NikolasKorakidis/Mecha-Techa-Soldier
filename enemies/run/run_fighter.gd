class_name RunFighter
extends RunEnemy
## "Talon" interceptor: dives in from far ahead, weaving, and strafes the bike on the way.
## Nose points -X (toward the bike). Flies at `speed` toward the bike while the bike closes in.

@export var speed: float = 16.0
@export var weave: Vector2 = Vector2(4.0, 1.5)
@export var elite: bool = false

var _base: Vector3
var _phase: float = 0.0


func _ready() -> void:
	if elite:
		max_health = 5
		score_value = 600
		fire_interval = 1.1
	super._ready()
	_base = position
	_phase = randf() * TAU


func _build_model() -> void:
	var coral := ModelKit.hull(Palette.ENEMY_CORAL if not elite else Color("ffb454"), ArtStyle.OUTLINE_THIN)
	var dark := ModelKit.hull(Color("2a1320"), ArtStyle.OUTLINE_THIN)
	var edge := ModelKit.emissive(Color(1.0, 0.3, 0.35), 2.6)
	# Cockpit pod with a glowing eye facing the bike.
	ModelKit.sphere(model, 0.8, Vector3.ZERO, dark, Vector3(1.3, 0.9, 0.9))
	ModelKit.sphere(model, 0.32, Vector3(-0.9, 0.05, 0), ModelKit.emissive(Color(1.0, 0.8, 0.3), 3.0))
	# Forward-swept blade wings above and below-ish (X-wing-free original silhouette).
	for side: float in [-1.0, 1.0]:
		var wing := ModelKit.group(model, "Wing", Vector3(0.2, 0, side * 0.7))
		ModelKit.box(wing, Vector3(1.8, 0.12, 2.2), Vector3(-0.3, 0, side * 1.0), coral, Vector3(0, side * -25, side * 8))
		ModelKit.box(wing, Vector3(1.9, 0.06, 0.08), Vector3(-0.35, 0.06, side * 2.0), edge, Vector3(0, side * -25, 0))
		ModelKit.box(wing, Vector3(0.5, 1.4, 0.12), Vector3(0.1, 0, side * 2.1), dark)
		ModelKit.hex_x(model, 0.22, 0.9, Vector3(0.9, 0, side * 0.5), dark, 6)
		var burn := MeshInstance3D.new()
		burn.mesh = QuadMesh.new()
		burn.material_override = ModelKit.glow_billboard(Color(1.0, 0.45, 0.3), 1.6)
		burn.position = Vector3(1.45, 0, side * 0.5)
		burn.scale = Vector3.ONE * 1.1
		model.add_child(burn)
	if elite:
		model.scale = Vector3.ONE * 1.3


func _move(delta: float, _player: Node3D) -> void:
	_phase += delta
	_base.x -= speed * delta
	position = Vector3(_base.x, _base.y + sin(_phase * 1.7) * weave.y, _base.z + sin(_phase * 1.1) * weave.x)
	model.rotation.x = cos(_phase * 1.1) * 0.6


func _fire(player: Node3D) -> void:
	super._fire(player)
	if elite:
		var from := global_position + _muzzle_offset()
		for side: float in [-1.0, 1.0]:
			var target := Players.aim_point(player) + Vector3(0, 0, side * 3.0)
			Bolt3D.fire(get_tree(), Teams.Team.ENEMY, 1, from, (target - from).normalized() * bolt_speed, BOLT_COLOR, 0.4)
