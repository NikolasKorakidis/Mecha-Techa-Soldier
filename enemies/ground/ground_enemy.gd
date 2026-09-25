class_name GroundEnemy
extends CharacterBody3D
## Platformer enemy. WALKER patrols (turns at walls and ledges) and fires along its facing;
## HOPPER leaps at the player; TURRET sits still and fires aimed bursts; FLYER hovers on a
## sine path and fires aimed shots; SHIELD (Sniper Joe-style) holds a front shield that blocks
## shots and only drops it to fire, turning slowly so a jump over it opens its back; SWOOPER
## hangs from the ceiling and dives at the player. Every volley is telegraphed. Only acts near
## the screen.

signal defeated(enemy: GroundEnemy)

enum Behavior { WALKER, HOPPER, TURRET, FLYER, SHIELD, SWOOPER }
enum Swoop { PERCH, DIVE, RETURN }

## Shield guard: seconds before it turns to face a player who got behind it.
const SHIELD_TURN_DELAY := 0.9
## Shield guard: shield stays down this long after a volley.
const SHIELD_OPEN_AFTER_FIRE := 0.5

const GROUP := SpaceEnemy.GROUP

@export var behavior: Behavior = Behavior.WALKER
@export var health: HealthComponent
@export var hurtbox: HurtboxComponent
@export var weapon: WeaponComponent
@export var flash: FlashComponent
@export var telegraph: Node3D
@export var model: EnemyModel
## Parent of model, muzzle and telegraph; mirrored to face left/right.
@export var facing_root: Node3D
@export var death_effect: PackedScene
@export var pickup_scene: PackedScene
@export var speed: float = 2.4
@export var fire_interval: float = 2.2
@export var telegraph_time: float = 0.45
@export var burst_count: int = 1
@export var sight_range: float = 14.0
@export var hop_interval: float = 2.0
@export var hop_velocity: Vector2 = Vector2(6.0, 13.0)
@export var score_value: int = 300
@export var death_size: float = 1.0
@export var drop_echo: StringName = &""
## Chance a regular enemy drops a small health capsule.
@export var health_drop_chance: float = 0.18

var facing: float = -1.0

var _fire_left: float = 1.2
var _telegraph_left: float = -1.0
var _burst_left: int = 0
var _burst_timer: float = 0.0
var _aim: Vector3 = Vector3.LEFT
var _hop_left: float = 1.5
var _time: float = 0.0
var _home: Vector3
var _camera: GameplayCamera
var _shield: Node3D
var _behind_time: float = 0.0
var _open_left: float = 0.0
var _swoop: Swoop = Swoop.PERCH
var _swoop_target: Vector3
var _swoop_rest: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = PhysicsLayers.ACTOR
	collision_mask = PhysicsLayers.WORLD
	_home = global_position
	_camera = GameplayCamera.find(get_tree())
	if telegraph:
		telegraph.visible = false
	health.damaged.connect(func(_p: DamagePayload, _s: Node) -> void: flash.flash(0.08))
	health.depleted.connect(_on_depleted)
	if behavior == Behavior.SHIELD:
		_build_shield()


func is_alive() -> bool:
	return not health.is_depleted()


func is_elite() -> bool:
	return drop_echo != &""


func _physics_process(delta: float) -> void:
	if not _near_screen():
		return
	tick(delta)


func tick(delta: float) -> void:
	_time += delta
	match behavior:
		Behavior.WALKER:
			_walk(delta)
		Behavior.HOPPER:
			_hop(delta)
		Behavior.TURRET:
			_face_player()
		Behavior.FLYER:
			var player := Players.find_active(get_tree())
			if player:
				var target_x := player.global_position.x + 6.0 * signf(_home.x - player.global_position.x + 0.01)
				global_position.x = move_toward(global_position.x, target_x, 1.5 * delta)
			global_position.y = _home.y + sin(_time * 2.2) * 1.2
			_face_player()
		Behavior.SHIELD:
			_guard(delta)
		Behavior.SWOOPER:
			_swoop_update(delta)
	_update_firing(delta)
	if facing_root:
		facing_root.scale.x = -facing
	if model:
		model.targetable = true


func _walk(delta: float) -> void:
	velocity.y -= 40.0 * delta
	velocity.x = facing * speed
	move_and_slide()
	global_position.z = 0.0
	if is_on_floor() and (is_on_wall() or not _ground_ahead()):
		facing = -facing


func _hop(delta: float) -> void:
	velocity.y -= 40.0 * delta
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		_hop_left -= delta
		_face_player()
		if _hop_left <= 0.0 and _player_in_sight():
			_hop_left = hop_interval
			velocity = Vector3(facing * hop_velocity.x, hop_velocity.y, 0)
	move_and_slide()
	global_position.z = 0.0


func _build_shield() -> void:
	# Front is local -X (the facing root mirrors the model).
	_shield = ModelKit.group(facing_root, "Shield", Vector3(-0.85, 0.95, 0.2))
	var plate := ModelKit.hull(Color("56607a"), ArtStyle.OUTLINE_THIN, 0.5)
	ModelKit.box(_shield, Vector3(0.22, 1.7, 1.0), Vector3.ZERO, plate)
	ModelKit.box(_shield, Vector3(0.26, 0.2, 1.04), Vector3(0, 0.55, 0), ModelKit.glossy(Palette.ECHO_GOLD))
	ModelKit.box(_shield, Vector3(0.26, 0.9, 0.12), Vector3(0, -0.1, 0), ModelKit.emissive(EnemyModel.SENSOR, 2.0))


## Shield guard: creeps toward the player behind its shield; lowers it only to shoot.
func _guard(delta: float) -> void:
	velocity.y -= 40.0 * delta
	var player := Players.find_active(get_tree())
	if player:
		var side := signf(player.global_position.x - global_position.x)
		if side != facing and absf(player.global_position.x - global_position.x) > 0.3:
			_behind_time += delta
			if _behind_time >= SHIELD_TURN_DELAY:
				facing = side
				_behind_time = 0.0
		else:
			_behind_time = 0.0
		var distance := absf(player.global_position.x - global_position.x)
		var advancing := _open_left <= 0.0 and _telegraph_left < 0.0 and _burst_left == 0 and distance > 5.0 and distance < sight_range
		velocity.x = facing * speed if advancing and _ground_ahead() else 0.0
	else:
		velocity.x = 0.0
	move_and_slide()
	global_position.z = 0.0
	_open_left = maxf(0.0, _open_left - delta)
	var open := _open_left > 0.0 or _telegraph_left >= 0.0 or _burst_left > 0
	var shielded := not open and player != null and (player.global_position.x - global_position.x) * facing > 0.0
	health.invulnerable = shielded
	# Shield swings down while firing.
	_shield.rotation.z = lerpf(_shield.rotation.z, 0.0 if not open else -1.1, minf(1.0, delta * 14.0))
	_shield.position.y = lerpf(_shield.position.y, 0.95 if not open else 0.35, minf(1.0, delta * 14.0))


## Swooper: perches on the ceiling, dives at where the player stood, then climbs back.
func _swoop_update(delta: float) -> void:
	var player := Players.find_active(get_tree())
	match _swoop:
		Swoop.PERCH:
			_swoop_rest -= delta
			global_position = global_position.move_toward(_home, 6.0 * delta)
			if player and _swoop_rest <= 0.0:
				var dx := player.global_position.x - global_position.x
				if absf(dx) < 7.0 and player.global_position.y < global_position.y - 1.0:
					_swoop = Swoop.DIVE
					_swoop_target = player.global_position + Vector3(0, 0.8, 0)
					facing = signf(dx) if absf(dx) > 0.1 else facing
					AudioService.play(&"dash")
		Swoop.DIVE:
			global_position = global_position.move_toward(_swoop_target, 16.0 * delta)
			if global_position.distance_to(_swoop_target) < 0.2:
				_swoop = Swoop.RETURN
		Swoop.RETURN:
			global_position = global_position.move_toward(_home, 7.0 * delta)
			if global_position.distance_to(_home) < 0.1:
				_swoop = Swoop.PERCH
				_swoop_rest = 1.4
	global_position.z = 0.0
	if model:
		model.set_charge(1.0 if _swoop == Swoop.DIVE else 0.0)


func _ground_ahead() -> bool:
	var from := global_position + Vector3(facing * 0.7, 0.5, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -1.4, 0), PhysicsLayers.WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _face_player() -> void:
	var player := Players.find_active(get_tree())
	if player:
		facing = signf(player.global_position.x - global_position.x) if absf(player.global_position.x - global_position.x) > 0.2 else facing


func _player_in_sight() -> bool:
	var player := Players.find_active(get_tree())
	return player != null and global_position.distance_to(player.global_position) < sight_range


func _update_firing(delta: float) -> void:
	if weapon == null or behavior in [Behavior.HOPPER, Behavior.SWOOPER]:
		return
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			weapon.fire_at(_aim)
			_burst_left -= 1
			_burst_timer = 0.13
		return
	if _telegraph_left >= 0.0:
		_telegraph_left -= delta
		if telegraph:
			telegraph.scale = Vector3.ONE * (0.4 + (1.0 - _telegraph_left / telegraph_time) * 0.9)
		if model:
			model.set_charge(1.0 - _telegraph_left / telegraph_time)
		if _telegraph_left <= 0.0:
			_telegraph_left = -1.0
			if telegraph:
				telegraph.visible = false
			if model:
				model.set_charge(0.0)
				model.recoil()
			if behavior == Behavior.SHIELD:
				_open_left = SHIELD_OPEN_AFTER_FIRE + burst_count * 0.13
			_fire_left = fire_interval
			_aim = _aim_direction()
			_burst_left = burst_count
			_burst_timer = 0.0
			Vfx.spawn(get_tree(), preload("res://vfx/muzzle_flash.tscn"), weapon.global_position)
		return
	_fire_left -= delta
	if _fire_left <= 0.0 and _player_in_sight() and _player_in_front():
		_telegraph_left = telegraph_time
		if telegraph:
			telegraph.visible = true


func _player_in_front() -> bool:
	if behavior not in [Behavior.WALKER, Behavior.SHIELD]:
		return true
	var player := Players.find_active(get_tree())
	return player != null and (player.global_position.x - global_position.x) * facing > 0.0


func _aim_direction() -> Vector3:
	if behavior in [Behavior.WALKER, Behavior.SHIELD]:
		return Vector3(facing, 0, 0)
	var player := Players.find_active(get_tree())
	if player == null:
		return Vector3(facing, 0, 0)
	var target := player.global_position + Vector3(0, 1.1, 0)
	var d := target - weapon.global_position
	d.z = 0.0
	return d.normalized()


func _near_screen() -> bool:
	if _camera == null:
		return true
	return _camera.get_play_rect().grow(4.0).has_point(Vector2(global_position.x, global_position.y))


func _on_depleted(_source: Node) -> void:
	RunSession.add_score(score_value)
	RunSession.add_charge(score_value)
	Vfx.spawn(get_tree(), preload("res://vfx/core_collapse.tscn") if is_elite() else death_effect, global_position + Vector3(0, 1.0, 0), death_size)
	var root := get_tree().get_first_node_in_group(Vfx.ROOT_GROUP)
	if root and model:
		root.add_child(FragmentBurst.create(model.make_fragments(3), global_position + Vector3(0, 1, 0), 5.0))
	var pickups := get_tree().get_first_node_in_group(EchoPickup.ROOT_GROUP)
	if pickups:
		if is_elite() and pickup_scene:
			var core := pickup_scene.instantiate() as EchoPickup
			core.echo_id = drop_echo
			core.drift_speed = 0.0
			core.position = global_position + Vector3(0, 1.4, 0) - (pickups as Node3D).global_position
			pickups.add_child.call_deferred(core)
		elif randf() < health_drop_chance:
			var capsule := ItemPickup.new()
			capsule.kind = ItemPickup.Kind.HEALTH
			capsule.amount = 1
			capsule.position = global_position + Vector3(0, 0.9, 0) - (pickups as Node3D).global_position
			pickups.add_child.call_deferred(capsule)
	defeated.emit(self)
	queue_free()
