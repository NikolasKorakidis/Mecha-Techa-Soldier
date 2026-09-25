class_name RunGunship
extends RunEnemy
## Pursuit gunship (hull-run mini boss): flies ahead of the bike at a fixed lead, sways across
## the deck, fires aimed triple volleys, drops blast mines onto the deck ahead and calls in
## interceptor pairs. Has three engine pods; the core takes damage from any hit.

signal health_changed(current: int, maximum: int)

@export var lead_distance: float = 48.0
@export var altitude: float = 7.5
@export var mine_interval: float = 3.2
@export var call_interval: float = 7.0

var boss_name: String = "PURSUIT GUNSHIP"

var _mine_left: float = 2.0
var _call_left: float = 4.0
var _engines: Array[MeshInstance3D] = []


func _ready() -> void:
	max_health = 90
	score_value = 8000
	fire_interval = 1.3
	hurt_size = Vector3(7.0, 3.5, 9.0)
	fire_range = Vector2(10.0, 200.0)
	death_size = 5.0
	AudioService.play(&"boss_roar")
	super._ready()
	health.health_changed.connect(func(c: int, m: int) -> void: health_changed.emit(c, m))


func _build_model() -> void:
	var hull := ModelKit.hull(Color("5a2438"), ArtStyle.OUTLINE_THICK)
	var dark := ModelKit.hull(Color("22101a"), ArtStyle.OUTLINE_THIN)
	var trim := ModelKit.hull(Color("8a3a4e"), ArtStyle.OUTLINE_THIN)
	ModelKit.box(model, Vector3(7.0, 2.0, 4.0), Vector3.ZERO, hull)
	ModelKit.prism(model, Vector3(2.0, 2.6, 4.0), Vector3(-4.3, -0.1, 0), hull, Vector3(0, 0, 90))
	ModelKit.box(model, Vector3(3.0, 1.2, 2.4), Vector3(0.8, 1.5, 0), trim)
	ModelKit.box(model, Vector3(1.2, 0.3, 2.0), Vector3(-0.8, 1.6, 0), ModelKit.emissive(Color(1.0, 0.75, 0.3), 2.2))
	for side: float in [-1.0, 1.0]:
		ModelKit.box(model, Vector3(4.0, 0.5, 3.6), Vector3(0.5, -0.3, side * 3.6), dark, Vector3(side * 8, 0, 0))
		var pod := ModelKit.group(model, "Pod", Vector3(2.2, -0.2, side * 5.2))
		ModelKit.hex_x(pod, 0.8, 3.0, Vector3.ZERO, trim, 8)
		var burn := MeshInstance3D.new()
		burn.mesh = QuadMesh.new()
		burn.material_override = ModelKit.glow_billboard(Color(1.0, 0.4, 0.3), 2.2)
		burn.position = Vector3(1.8, 0, 0)
		burn.scale = Vector3.ONE * 2.6
		pod.add_child(burn)
		_engines.append(burn)
	ModelKit.sphere(model, 0.7, Vector3(-3.2, -0.7, 0), ModelKit.emissive(Palette.DANGER, 3.0))


func _move(delta: float, player: Node3D) -> void:
	if player == null:
		return
	var goal := Vector3(player.global_position.x + lead_distance, player.global_position.y + altitude + sin(_time * 0.9) * 1.5, sin(_time * 0.6) * 5.5)
	global_position = global_position.lerp(goal, clampf(delta * 2.5, 0.0, 1.0))
	model.rotation.x = -cos(_time * 0.6) * 0.25
	_mine_left -= delta
	if _mine_left <= 0.0:
		_mine_left = mine_interval
		_drop_mine()
	_call_left -= delta
	if _call_left <= 0.0:
		_call_left = call_interval
		_call_fighters(player)


func _update_fire(delta: float, player: Node3D) -> void:
	super._update_fire(delta, player)


func _physics_process(delta: float) -> void:
	# Never culled behind the bike: it keeps pace.
	_time += delta
	var player := Players.find(get_tree())
	_move(delta, player)
	if player:
		_update_fire(delta, player)
	_flash_left = maxf(0.0, _flash_left - delta)
	model.scale = Vector3.ONE * (1.05 if _flash_left > 0.0 else 1.0)


func _fire(player: Node3D) -> void:
	var from := global_position + _muzzle_offset()
	for k in 3:
		var target := Players.aim_point(player) + Vector3(0, 0, (k - 1) * 2.5)
		Bolt3D.fire(get_tree(), Teams.Team.ENEMY, 1, from, (target - from).normalized() * bolt_speed, BOLT_COLOR, 0.5)


func _drop_mine() -> void:
	var mine := HullObstacle.new()
	mine.kind = HullObstacle.Kind.BLAST
	var root := get_parent()
	root.add_child(mine)
	mine.global_position = Vector3(global_position.x + 10.0, 30.0, clampf(global_position.z, -7.0, 7.0))


func _call_fighters(player: Node3D) -> void:
	for side: float in [-1.0, 1.0]:
		var f := RunFighter.new()
		f.position = Vector3(player.global_position.x + 140.0, 36.0, side * 5.0) - (get_parent() as Node3D).global_position
		get_parent().add_child(f)


func _muzzle_offset() -> Vector3:
	return Vector3(-4.5, -0.6, 0)
