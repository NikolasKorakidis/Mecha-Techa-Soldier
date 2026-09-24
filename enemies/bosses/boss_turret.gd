class_name BossTurret
extends Node3D
## Destructible gun module on a boss. Fires telegraphed aimed bursts while active.

signal destroyed(turret: BossTurret)

@export var max_health: int = 45
@export var fire_interval: float = 2.4
@export var burst_count: int = 3
@export var projectile_scene: PackedScene
@export var death_effect: PackedScene

var active: bool = false
var health: HealthComponent
var hurtbox: HurtboxComponent

var _weapon: WeaponComponent
var _telegraph: MeshInstance3D
var _barrel: Node3D
var _model: Node3D
var _flash: FlashComponent
var _fire_left: float = 1.2
var _telegraph_left: float = -1.0
var _burst_left: int = 0
var _burst_timer: float = 0.0
var _aim: Vector3 = Vector3.LEFT


func _ready() -> void:
	add_to_group(SpaceEnemy.GROUP)
	health = HealthComponent.new()
	health.max_health = max_health
	add_child(health)
	hurtbox = HurtboxComponent.new()
	hurtbox.team = Teams.Team.ENEMY
	hurtbox.health = health
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	hurtbox.add_child(shape)
	add_child(hurtbox)
	health.depleted.connect(_on_depleted)
	health.damaged.connect(func(_p: DamagePayload, _s: Node) -> void: _flash.flash(0.06))

	_model = Node3D.new()
	add_child(_model)
	ModelKit.cylinder(_model, 0.9, 1.1, 0.8, Vector3.ZERO, ModelKit.toon(Color("3b1726"), 0.5, 0.4, 0.5), Vector3(90, 0, 0), 8)
	ModelKit.sphere(_model, 0.6, Vector3(0, 0, 0.45), ModelKit.toon(Color("c93a3a"), 0.6), Vector3(1, 1, 0.7))
	_barrel = Node3D.new()
	_barrel.position = Vector3(0, 0, 0.6)
	_model.add_child(_barrel)
	ModelKit.cylinder(_barrel, 0.14, 0.2, 1.4, Vector3(-0.8, 0, 0), ModelKit.toon(Color("4a3a48"), 0.4, 0.35, 0.6), Vector3(0, 0, 90))
	ModelKit.sphere(_model, 0.22, Vector3(0.35, 0.25, 0.85), ModelKit.emissive(Color("ff8a1f"), 3.0))

	_weapon = WeaponComponent.new()
	_weapon.projectile_scene = projectile_scene
	_weapon.team = Teams.Team.ENEMY
	_weapon.projectile_speed = 12.0
	_weapon.position = Vector3(-1.4, 0, 0)
	add_child(_weapon)
	_telegraph = ModelKit.quad(self, Vector2.ONE * 1.5, Vector3(-1.4, 0, 1.2), ModelKit.glow(Color(1, 0.75, 0.95), 2.5))
	_telegraph.visible = false
	_flash = FlashComponent.new()
	_flash.mode = FlashComponent.Mode.OVERLAY
	_flash.target = _model
	add_child(_flash)


func is_alive() -> bool:
	return health != null and not health.is_depleted()


func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	var player := get_tree().get_first_node_in_group(ShipPlayer.GROUP) as Node3D
	if player:
		var d := player.global_position - global_position
		_barrel.rotation.z = lerp_angle(_barrel.rotation.z, atan2(-d.y, -d.x), 0.12)
	if not active:
		return
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_weapon.fire_at(_aim)
			_burst_left -= 1
			_burst_timer = 0.13
		return
	if _telegraph_left >= 0.0:
		_telegraph_left -= delta
		_telegraph.scale = Vector3.ONE * (0.4 + (1.0 - _telegraph_left / 0.4) * 0.9)
		if _telegraph_left <= 0.0:
			_telegraph.visible = false
			_telegraph_left = -1.0
			_fire_left = fire_interval
			if player:
				_aim = (player.global_position - _weapon.global_position)
				_aim.z = 0.0
				_aim = _aim.normalized()
			_burst_left = burst_count
			_burst_timer = 0.0
		return
	_fire_left -= delta
	if _fire_left <= 0.0:
		_telegraph.visible = true
		_telegraph_left = 0.4


func _on_depleted(_source: Node) -> void:
	RunSession.add_score(2500)
	Vfx.spawn(get_tree(), death_effect, global_position + Vector3(0, 0, 1), 1.8)
	_telegraph.visible = false
	_barrel.visible = false
	hurtbox.set_deferred(&"monitorable", false)
	destroyed.emit(self)
