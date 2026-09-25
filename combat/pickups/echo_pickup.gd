class_name EchoPickup
extends Area3D
## Weapon core dropped by an elite. Drifts left, pulls toward a nearby player, and
## installs its echo weapon on contact.

const ROOT_GROUP := &"pickup_root"

@export var echo_id: StringName = EchoModules.BURST
@export var drift_speed: float = 2.2
@export var magnet_radius: float = 4.5
@export var magnet_speed: float = 14.0
@export var lifetime: float = 14.0

var _time: float = 0.0
var _visual: Node3D
var _collected: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.HURTBOX
	monitoring = true
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	shape.shape = sphere
	add_child(shape)
	area_entered.connect(_on_area_entered)
	_build_visual()


func _build_visual() -> void:
	var data := EchoModules.get_data(echo_id)
	var color := data.module_color if data else Color.WHITE
	_visual = Node3D.new()
	add_child(_visual)
	ModelKit.quad(_visual, Vector2.ONE * 2.6, Vector3(0, 0, -0.2), ModelKit.glow(color, 1.2))
	ModelKit.quad(_visual, Vector2.ONE * 2.2, Vector3(0, 0, 0.1), ModelKit.glow(Color("ffe08a"), 1.6, ModelKit.GlowShape.RING))
	var gem := ModelKit.box(_visual, Vector3.ONE * 0.6, Vector3.ZERO, ModelKit.emissive(color, 2.5), Vector3(45, 45, 0))
	gem.name = "Gem"
	var label := Label3D.new()
	label.text = (data.display_name if data else "?").substr(0, 1)
	label.font_size = 96
	label.pixel_size = 0.007
	label.outline_size = 16
	label.position = Vector3(0, 0, 0.6)
	_visual.add_child(label)


func _physics_process(delta: float) -> void:
	_time += delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var player := Players.find(get_tree())
	var to_player := (player.global_position - global_position) if player and player.visible else Vector3.INF
	if to_player != Vector3.INF and to_player.length() < magnet_radius:
		# Arc in: a sideways component that fades as the core closes in.
		var dir := to_player.normalized()
		var side := Vector3(-dir.y, dir.x, 0.0) * clampf(to_player.length() / magnet_radius, 0.0, 1.0) * 0.8
		global_position += (dir + side).normalized() * magnet_speed * delta
	else:
		position.x -= drift_speed * delta
		position.y += sin(_time * 3.0) * 0.8 * delta
	if _visual:
		_visual.get_node(^"Gem").rotation.y += delta * 3.0
		# Blink out during the last two seconds.
		_visual.visible = lifetime > 2.0 or fmod(lifetime, 0.2) > 0.1


func _on_area_entered(area: Area3D) -> void:
	if _collected:
		return
	var player := area.get_parent()
	if player == null or not player.is_in_group(Players.GROUP) or not player.call(&"can_collect"):
		return
	_collected = true
	player.collect_echo(echo_id)
	AudioService.play(&"weapon_get")
	queue_free()
