class_name HitboxComponent
extends Area3D
## Delivers its DamagePayload to overlapping hurtboxes.
## single_hit: stop after the first landed hit (projectiles).
## continuous: re-test overlaps every physics tick (contact damage), relying on the
## victim's invulnerability window to prevent spam.

signal hit_landed(hurtbox: HurtboxComponent)

@export var payload: DamagePayload
@export var single_hit: bool = true
@export var continuous: bool = false
## Reported as the damage source; defaults to the parent actor.
@export var source: Node

var _spent: bool = false


func _ready() -> void:
	collision_layer = PhysicsLayers.HITBOX
	collision_mask = PhysicsLayers.HURTBOX
	monitoring = true
	monitorable = false
	if source == null:
		source = get_parent()
	area_entered.connect(_on_area_entered)
	set_physics_process(continuous)


func _physics_process(_delta: float) -> void:
	for area in get_overlapping_areas():
		_try_hit(area)


func _on_area_entered(area: Area3D) -> void:
	_try_hit(area)


func _try_hit(area: Area3D) -> void:
	if _spent or payload == null:
		return
	var hurtbox := area as HurtboxComponent
	if hurtbox == null:
		return
	if hurtbox.receive_hit(payload, source):
		hit_landed.emit(hurtbox)
		if single_hit:
			_spent = true
			set_deferred(&"monitoring", false)
