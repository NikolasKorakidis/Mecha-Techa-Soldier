class_name HurtboxComponent
extends Area3D
## Receives hits for its actor. Rejects friendly fire, then forwards to HealthComponent.

signal hurt(payload: DamagePayload, source: Node)

@export var team: Teams.Team = Teams.Team.NEUTRAL
@export var health: HealthComponent


func _ready() -> void:
	collision_layer = PhysicsLayers.HURTBOX
	collision_mask = 0
	monitoring = false
	monitorable = true
	if health == null:
		push_error("HurtboxComponent '%s' has no HealthComponent assigned." % get_path())


## NEUTRAL payloads (hazards) hit every team; otherwise a team never damages itself.
func accepts(payload: DamagePayload) -> bool:
	return payload.team == Teams.Team.NEUTRAL or payload.team != team


func receive_hit(payload: DamagePayload, source: Node) -> bool:
	if health == null or not accepts(payload):
		return false
	if not health.apply_damage(payload, source):
		if health.invulnerable and team == Teams.Team.ENEMY and payload.team == Teams.Team.PLAYER:
			AudioService.play(&"armor_ping")
		return false
	if team == Teams.Team.PLAYER:
		AudioService.play(&"player_hurt")
	else:
		AudioService.play(&"hit")
	hurt.emit(payload, source)
	return true
