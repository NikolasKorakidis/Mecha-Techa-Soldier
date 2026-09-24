class_name DamagePayload
extends Resource
## One hit's worth of damage, delivered Hitbox → Hurtbox → HealthComponent.

@export var amount: int = 1
@export var team: Teams.Team = Teams.Team.NEUTRAL
@export var damage_type: StringName = &"kinetic"
## Applied to the victim's velocity on the gameplay plane (Z ignored).
@export var knockback: Vector3 = Vector3.ZERO
## Guard can return projectiles marked with a white ring (M2+).
@export var can_be_reflected: bool = false


static func create(damage: int, from_team: Teams.Team) -> DamagePayload:
	var payload := DamagePayload.new()
	payload.amount = damage
	payload.team = from_team
	return payload
