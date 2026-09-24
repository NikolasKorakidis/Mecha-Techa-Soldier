class_name ShipArsenal
extends Node3D
## Chooses what the ship fires: the base gun, or the active echo weapon while it has ammo.
## BURST = 5-way spread, ARC = chain lightning to nearby enemies, GUARD = shield orbs
## that block shots and fire with you. Each volley spends one shot of echo ammo.

signal fired

const BURST_ANGLES: Array[float] = [-16.0, -8.0, 0.0, 8.0, 16.0]

@export var base_weapon: WeaponComponent
@export var burst_weapon: WeaponComponent
@export var orb_weapon: WeaponComponent
@export var guard_orbs: GuardOrbs
@export var arc_range: float = 22.0
@export var arc_chain_range: float = 6.5
@export var arc_chain_count: int = 3

var _cooldown: float = 0.0
var _modules: Dictionary = {}


func _ready() -> void:
	for id in EchoModules.ALL:
		_modules[id] = EchoModules.get_data(id)
	base_weapon.fired.connect(func(_p: Projectile) -> void: fired.emit())


func tick(delta: float, trigger_held: bool) -> void:
	var echo := RunSession.selected_echo
	guard_orbs.active = echo == EchoModules.GUARD
	_cooldown = maxf(0.0, _cooldown - delta)
	if echo == RunSession.NO_ECHO:
		base_weapon.tick(delta, trigger_held)
		return
	if not trigger_held or _cooldown > 0.0:
		return
	var data: EchoModuleData = _modules[echo]
	_cooldown = data.fire_interval
	var spent := true
	match echo:
		EchoModules.BURST:
			_fire_burst(data)
		EchoModules.ARC:
			spent = _fire_arc(data)
		EchoModules.GUARD:
			_fire_guard(data)
	if spent:
		RunSession.consume_echo_ammo(1)
	fired.emit()


func reset() -> void:
	_cooldown = 0.0
	base_weapon.reset()


func _fire_burst(data: EchoModuleData) -> void:
	burst_weapon.damage = data.damage
	for angle in BURST_ANGLES:
		var a := deg_to_rad(angle)
		burst_weapon.fire_at(Vector3(cos(a), sin(a), 0))


## Returns false (no ammo spent) when nothing is in range; the base gun fires instead.
func _fire_arc(data: EchoModuleData) -> bool:
	var chain := _find_arc_chain()
	if chain.is_empty():
		base_weapon.fire()
		return false
	var points := PackedVector3Array([global_position])
	var payload := DamagePayload.create(data.damage, Teams.Team.PLAYER)
	payload.damage_type = &"arc"
	for enemy in chain:
		points.append(enemy.global_position)
		(enemy.get(&"hurtbox") as HurtboxComponent).receive_hit(payload, self)
	var root := get_tree().get_first_node_in_group(Vfx.ROOT_GROUP)
	if root:
		root.add_child(ArcBolt.create(points, data.module_color))
	return true


func _fire_guard(data: EchoModuleData) -> void:
	base_weapon.fire()
	orb_weapon.damage = data.damage
	for pos in guard_orbs.orb_positions():
		orb_weapon.global_position = pos
		orb_weapon.fire_at(Vector3.RIGHT)


func _find_arc_chain() -> Array[Node3D]:
	var chain: Array[Node3D] = []
	var candidates: Array[Node3D] = []
	var camera := GameplayCamera.find(get_tree())
	var rect := camera.get_play_rect() if camera else Rect2(-1e6, -1e6, 2e6, 2e6)
	for node in get_tree().get_nodes_in_group(SpaceEnemy.GROUP):
		var enemy := node as Node3D
		if enemy == null or not enemy.call(&"is_alive"):
			continue
		if enemy.get(&"hurtbox") == null:
			continue
		if not rect.has_point(Vector2(enemy.global_position.x, enemy.global_position.y)):
			continue
		candidates.append(enemy)
	var from := global_position
	var reach := arc_range
	for i in arc_chain_count:
		var best: Node3D = null
		var best_distance := reach
		for enemy in candidates:
			if chain.has(enemy):
				continue
			if i == 0 and enemy.global_position.x < global_position.x - 1.0:
				continue  # First link only reaches forward.
			var d := from.distance_to(enemy.global_position)
			if d < best_distance:
				best = enemy
				best_distance = d
		if best == null:
			break
		chain.append(best)
		from = best.global_position
		reach = arc_chain_range
	return chain
