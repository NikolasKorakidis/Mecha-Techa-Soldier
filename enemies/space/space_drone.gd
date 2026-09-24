class_name SpaceDrone
extends Node3D
## Basic space enemy: drifts left on a sine path, flashes a telegraph, then fires a
## straight shot. Contact damage comes from its Hitbox child.

@export var health: HealthComponent
@export var weapon: WeaponComponent
@export var flash: FlashComponent
@export var telegraph: Node3D
@export var death_effect: PackedScene

@export var speed: float = 4.0
@export var bob_amplitude: float = 1.2
@export var bob_frequency: float = 0.5
@export var first_shot_delay: float = 1.0
@export var fire_interval: float = 2.2
## One clean flash before every shot (art bible: enemy warning).
@export var telegraph_time: float = 0.35
@export var score_value: int = 100

var _time: float = 0.0
var _base_y: float = 0.0
var _fire_left: float = 0.0
var _telegraph_left: float = -1.0
var _camera: GameplayCamera


func _ready() -> void:
	_base_y = position.y
	_fire_left = first_shot_delay
	_camera = GameplayCamera.find(get_tree())
	telegraph.visible = false
	health.damaged.connect(_on_damaged)
	health.depleted.connect(_on_depleted)


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	_time += delta
	position.x -= speed * delta
	position.y = _base_y + sin(_time * TAU * bob_frequency) * bob_amplitude

	if _telegraph_left >= 0.0:
		_telegraph_left -= delta
		# Flare swells toward the shot so the timing reads at a glance.
		var charge := 1.0 - clampf(_telegraph_left / telegraph_time, 0.0, 1.0)
		telegraph.scale = Vector3.ONE * (0.4 + charge * 0.9)
		if _telegraph_left <= 0.0:
			telegraph.visible = false
			_telegraph_left = -1.0
			_fire_left = fire_interval
			weapon.fire()
		return

	_fire_left -= delta
	if _fire_left <= 0.0 and _is_on_screen():
		telegraph.visible = true
		_telegraph_left = telegraph_time


func _is_on_screen() -> bool:
	return _camera != null and _camera.get_play_rect().has_point(Vector2(global_position.x, global_position.y))


func _on_damaged(_payload: DamagePayload, _source: Node) -> void:
	flash.flash(0.1)


func _on_depleted(_source: Node) -> void:
	RunSession.add_score(score_value)
	Vfx.spawn(get_tree(), death_effect, global_position)
	queue_free()
