class_name RunEnemy
extends Node3D
## Base for hull-run enemies (3D chase view): health + hurtbox on the damage contract,
## hit flash, telegraphed volleys of Bolt3D, score/charge on death, 3D explosion, and
## cleanup once the bike has passed. Subclasses build a model and move.

signal defeated(enemy: RunEnemy)

const GROUP := &"run_enemies"
const BOLT_COLOR := Color(1.0, 0.25, 0.5)

@export var max_health: int = 2
@export var score_value: int = 250
@export var hurt_size: Vector3 = Vector3(3.0, 2.0, 3.0)
@export var fire_interval: float = 1.6
@export var bolt_speed: float = 55.0
@export var fire_range: Vector2 = Vector2(22.0, 120.0)
@export var death_size: float = 1.6

var health: HealthComponent
var hurtbox: HurtboxComponent
var model: Node3D

var _fire_left: float = 1.0
var _telegraph_left: float = -1.0
var _telegraph: MeshInstance3D
var _flash_left: float = 0.0
var _time: float = 0.0
var _materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SpaceEnemy.GROUP)
	health = HealthComponent.new()
	health.max_health = max_health
	add_child(health)
	hurtbox = HurtboxComponent.new()
	hurtbox.team = Teams.Team.ENEMY
	hurtbox.health = health
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = hurt_size
	shape.shape = box
	hurtbox.add_child(shape)
	add_child(hurtbox)
	health.damaged.connect(func(_p: DamagePayload, _s: Node) -> void: _flash_left = 0.07)
	health.depleted.connect(_on_depleted)
	model = ModelKit.group(self, "Model")
	_build_model()
	_telegraph = MeshInstance3D.new()
	_telegraph.mesh = QuadMesh.new()
	_telegraph.material_override = ModelKit.glow_billboard(BOLT_COLOR, 0.0)
	_telegraph.scale = Vector3.ONE * 2.5
	_telegraph.position = _muzzle_offset()
	add_child(_telegraph)
	_fire_left = randf_range(0.4, fire_interval)


func is_alive() -> bool:
	return health != null and not health.is_depleted()


func _physics_process(delta: float) -> void:
	_time += delta
	var player := Players.find(get_tree())
	_move(delta, player)
	if player:
		_update_fire(delta, player)
		if global_position.x < player.global_position.x - 25.0:
			queue_free()
	_flash_left = maxf(0.0, _flash_left - delta)
	model.scale = Vector3.ONE * (1.12 if _flash_left > 0.0 else 1.0)


func _update_fire(delta: float, player: Node3D) -> void:
	var dx := global_position.x - player.global_position.x
	if dx < fire_range.x or dx > fire_range.y:
		(_telegraph.material_override as ShaderMaterial).set_shader_parameter(&"energy", 0.0)
		return
	if _telegraph_left >= 0.0:
		_telegraph_left -= delta
		(_telegraph.material_override as ShaderMaterial).set_shader_parameter(&"energy", 2.5 * (1.0 - _telegraph_left / 0.45))
		if _telegraph_left < 0.0:
			(_telegraph.material_override as ShaderMaterial).set_shader_parameter(&"energy", 0.0)
			_fire(player)
		return
	_fire_left -= delta
	if _fire_left <= 0.0:
		_fire_left = fire_interval
		_telegraph_left = 0.45


## Default volley: one bolt leading the bike a little.
func _fire(player: Node3D) -> void:
	var from := global_position + _muzzle_offset()
	var target := Players.aim_point(player) + Vector3(player.get(&"velocity").x * 0.35 if &"velocity" in player else 0.0, 0, 0)
	Bolt3D.fire(get_tree(), Teams.Team.ENEMY, 1, from, (target - from).normalized() * bolt_speed, BOLT_COLOR, 0.4)


func _muzzle_offset() -> Vector3:
	return Vector3(-1.6, 0, 0)


func _build_model() -> void:
	pass


func _move(_delta: float, _player: Node3D) -> void:
	pass


func _on_depleted(_source: Node) -> void:
	RunSession.add_score(score_value)
	RunSession.add_charge(score_value)
	Explosion3D.spawn(get_tree(), global_position, death_size, 0.12)
	defeated.emit(self)
	queue_free()
