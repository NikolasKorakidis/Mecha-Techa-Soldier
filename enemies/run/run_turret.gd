class_name RunTurret
extends RunEnemy
## Hull gun emplacement on the deck edge or a trench wall: tracks the bike and fires
## telegraphed three-round bursts while the bike approaches.

var _head: Node3D
var _burst_left: int = 0
var _burst_timer: float = 0.0


func _ready() -> void:
	max_health = 5
	score_value = 350
	fire_interval = 2.0
	hurt_size = Vector3(2.6, 2.6, 2.6)
	fire_range = Vector2(18.0, 95.0)
	super._ready()


func _build_model() -> void:
	var metal := ModelKit.hull(Color("4a3040"), ArtStyle.OUTLINE_THIN, 0.35)
	var dark := ModelKit.hull(Color("22151d"), ArtStyle.OUTLINE_THIN, 0.3)
	ModelKit.cylinder(model, 1.4, 1.7, 0.8, Vector3(0, -0.8, 0), dark, Vector3.ZERO, 10)
	_head = ModelKit.group(model, "Head", Vector3(0, 0.1, 0))
	ModelKit.sphere(_head, 1.0, Vector3.ZERO, metal, Vector3(1, 0.7, 1))
	for side: float in [-1.0, 1.0]:
		ModelKit.hex_x(_head, 0.16, 1.8, Vector3(-1.2, 0.1, side * 0.35), dark, 6, 0.9)
	ModelKit.sphere(_head, 0.2, Vector3(-0.8, 0.35, 0), ModelKit.emissive(Palette.DANGER, 3.0))


func _move(delta: float, player: Node3D) -> void:
	if player and _head:
		var to := player.global_position - global_position
		_head.rotation.y = lerp_angle(_head.rotation.y, atan2(to.z, -to.x), clampf(delta * 5.0, 0.0, 1.0))
	if _burst_left > 0 and player:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_timer = 0.14
			_burst_left -= 1
			super._fire(player)


func _fire(_player: Node3D) -> void:
	_burst_left = 3
	_burst_timer = 0.0


func _muzzle_offset() -> Vector3:
	return Vector3(-1.4, 0.3, 0)
