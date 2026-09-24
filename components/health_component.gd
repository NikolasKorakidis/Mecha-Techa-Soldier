class_name HealthComponent
extends Node
## Owns hit points for any damageable actor. Emits depleted exactly once; a depleted
## actor ignores further damage until revive().

signal health_changed(current: int, maximum: int)
signal damaged(payload: DamagePayload, source: Node)
signal depleted(source: Node)

@export var max_health: int = 3

## Set by the owner (dash frames, hit blink, phase transitions).
var invulnerable: bool = false
var current: int = 0

var _depleted: bool = false


func _ready() -> void:
	current = max_health


func setup(maximum: int, value: int) -> void:
	max_health = maxi(1, maximum)
	current = clampi(value, 0, max_health)
	_depleted = current == 0
	health_changed.emit(current, max_health)


## Returns true only if damage was actually applied.
func apply_damage(payload: DamagePayload, source: Node) -> bool:
	if _depleted or invulnerable or payload.amount <= 0:
		return false
	current = maxi(0, current - payload.amount)
	health_changed.emit(current, max_health)
	damaged.emit(payload, source)
	if current == 0:
		_depleted = true
		depleted.emit(source)
	return true


func heal(amount: int) -> void:
	if _depleted or amount <= 0:
		return
	var before := current
	current = mini(max_health, current + amount)
	if current != before:
		health_changed.emit(current, max_health)


func revive(value: int = -1) -> void:
	_depleted = false
	current = max_health if value < 0 else clampi(value, 1, max_health)
	health_changed.emit(current, max_health)


func is_depleted() -> bool:
	return _depleted
