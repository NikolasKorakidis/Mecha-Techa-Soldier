class_name TargetDummy
extends Node3D
## Stationary combat target for test rooms. Scores when destroyed, then rebuilds.
## While rebuilding its health is depleted, so shots pass through.

@export var health: HealthComponent
@export var flash: FlashComponent
@export var model: Node3D
@export var label: Label3D
@export var death_effect: PackedScene
@export var score_value: int = 50
@export var respawn_delay: float = 2.0

var _respawn_timer: Timer


func _ready() -> void:
	health.health_changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.depleted.connect(_on_depleted)
	_respawn_timer = Timer.new()
	_respawn_timer.one_shot = true
	_respawn_timer.wait_time = respawn_delay
	_respawn_timer.timeout.connect(_on_respawn_timeout)
	add_child(_respawn_timer)
	_on_health_changed(health.current, health.max_health)


func _on_health_changed(current: int, maximum: int) -> void:
	if label:
		label.text = "%d / %d" % [current, maximum]


func _on_damaged(_payload: DamagePayload, _source: Node) -> void:
	flash.flash(0.1)


func _on_depleted(_source: Node) -> void:
	RunSession.add_score(score_value)
	Vfx.spawn(get_tree(), death_effect, global_position, 1.4)
	flash.stop()
	model.visible = false
	_respawn_timer.start()


func _on_respawn_timeout() -> void:
	model.visible = true
	health.revive()
