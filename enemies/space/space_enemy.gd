class_name SpaceEnemy
extends Node3D
## Configurable space enemy: one movement pattern + one fire pattern, set per scene.
## Every volley is preceded by a telegraph flare. Elites drop their echo weapon on death.

signal defeated(enemy: SpaceEnemy)

enum Movement { STRAIGHT, SINE, SWOOP, HOLD, CHARGE }
enum FirePattern { NONE, STRAIGHT, AIMED, AIMED_BURST, DIAGONAL_PAIR, SPREAD_FAN, RADIAL_RING }
enum MovePhase { ENTER, HOLDING, EXIT, CHARGE_WINDUP, CHARGING }

const GROUP := &"enemies"

@export_group("Wiring")
@export var health: HealthComponent
@export var hurtbox: HurtboxComponent
@export var weapon: WeaponComponent
@export var flash: FlashComponent
@export var telegraph: Node3D
@export var model: Node3D
@export var death_effect: PackedScene
@export var pickup_scene: PackedScene
## Elites implode their core first (visual only; the kill is already counted).
@export var collapse_effect: PackedScene = preload("res://vfx/core_collapse.tscn")
@export var muzzle_effect: PackedScene = preload("res://vfx/muzzle_flash.tscn")

@export_group("Movement")
@export var movement: Movement = Movement.SINE
@export var speed: float = 4.0
@export var bob_amplitude: float = 1.2
@export var bob_frequency: float = 0.5
## SWOOP: how far toward the screen center the path bends.
@export var swoop_depth: float = 0.6
## HOLD: X position (relative to the camera) where the enemy parks.
@export var hold_x: float = 9.0
@export var hold_time: float = 6.0
## CHARGE: approach time before locking on, windup, then dash speed.
@export var charge_delay: float = 1.4
@export var charge_windup: float = 0.55
@export var charge_speed: float = 17.0

@export_group("Firing")
@export var fire_pattern: FirePattern = FirePattern.STRAIGHT
@export var first_shot_delay: float = 1.0
@export var fire_interval: float = 2.2
## One clean flash before every volley (art bible: enemy warning).
@export var telegraph_time: float = 0.35
@export var burst_count: int = 3
@export var burst_spacing: float = 0.12
@export var spread_count: int = 5
@export var spread_angle: float = 44.0
@export var ring_count: int = 10

@export_group("Reward")
@export var score_value: int = 100
@export var death_size: float = 1.0
## Elite carriers drop this echo weapon as a pickup.
@export var drop_echo: StringName = &""

## Wave modifier applied by the level director.
var speed_scale: float = 1.0
var phase: MovePhase = MovePhase.ENTER

var _time: float = 0.0
var _phase_time: float = 0.0
var _base_y: float = 0.0
var _start_x: float = 0.0
var _fire_left: float = 0.0
var _telegraph_left: float = -1.0
var _burst_left: int = 0
var _burst_timer: float = 0.0
var _burst_aim: Vector3 = Vector3.LEFT
var _ring_offset: float = 0.0
var _charge_direction: Vector3 = Vector3.LEFT
var _camera: GameplayCamera


func _ready() -> void:
	add_to_group(GROUP)
	_base_y = position.y
	_start_x = position.x
	_fire_left = first_shot_delay
	_camera = GameplayCamera.find(get_tree())
	if telegraph:
		telegraph.visible = false
	health.damaged.connect(_on_damaged)
	health.depleted.connect(_on_depleted)


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	_time += delta
	_phase_time += delta
	_move(delta)
	_update_firing(delta)
	if model and &"targetable" in model:
		model.targetable = _is_on_screen()


func is_alive() -> bool:
	return not health.is_depleted()


func is_elite() -> bool:
	return drop_echo != &""


func muzzle_position() -> Vector3:
	return weapon.global_position if weapon else global_position


# --- Movement -----------------------------------------------------------------

func _move(delta: float) -> void:
	var s := speed * speed_scale
	match movement:
		Movement.STRAIGHT:
			position.x -= s * delta
		Movement.SINE:
			position.x -= s * delta
			position.y = _base_y + sin(_time * TAU * bob_frequency) * bob_amplitude
		Movement.SWOOP:
			position.x -= s * delta
			var progress := clampf((_start_x - position.x) / 30.0, 0.0, 1.0)
			position.y = lerpf(_base_y, _base_y * (1.0 - swoop_depth * 2.0), sin(progress * PI))
		Movement.HOLD:
			_move_hold(delta, s)
		Movement.CHARGE:
			_move_charge(delta, s)


func _move_hold(delta: float, s: float) -> void:
	var park_x := hold_x + (_camera.global_position.x if _camera else 0.0)
	match phase:
		MovePhase.ENTER:
			# Ease into the parking spot.
			var remaining := position.x - park_x
			position.x -= maxf(s * 0.4, minf(s * 1.5, remaining * 2.5)) * delta
			if position.x <= park_x + 0.05:
				_set_phase(MovePhase.HOLDING)
		MovePhase.HOLDING:
			position.y = _base_y + sin(_phase_time * TAU * bob_frequency) * bob_amplitude * 0.5
			if _phase_time >= hold_time:
				_set_phase(MovePhase.EXIT)
		MovePhase.EXIT:
			position.x -= s * 1.6 * delta


func _move_charge(delta: float, s: float) -> void:
	match phase:
		MovePhase.ENTER:
			position.x -= s * delta
			position.y = _base_y + sin(_time * TAU * bob_frequency) * bob_amplitude * 0.4
			if _time >= charge_delay and _is_on_screen():
				_set_phase(MovePhase.CHARGE_WINDUP)
				_show_telegraph(true)
		MovePhase.CHARGE_WINDUP:
			# Lock on at the end of the windup so the player can read and dodge it.
			position.x += 1.5 * delta
			if _phase_time >= charge_windup:
				_charge_direction = _aim_at_player()
				_show_telegraph(false)
				_set_phase(MovePhase.CHARGING)
				rotation.z = atan2(-_charge_direction.y, -_charge_direction.x)
		MovePhase.CHARGING:
			position += _charge_direction * charge_speed * speed_scale * delta


func _set_phase(next: MovePhase) -> void:
	phase = next
	_phase_time = 0.0


# --- Firing -------------------------------------------------------------------

func _update_firing(delta: float) -> void:
	if fire_pattern == FirePattern.NONE or weapon == null:
		return
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			weapon.fire_at(_burst_aim)
			_burst_left -= 1
			_burst_timer = burst_spacing
		return
	if _telegraph_left >= 0.0:
		_telegraph_left -= delta
		var charge := 1.0 - clampf(_telegraph_left / telegraph_time, 0.0, 1.0)
		if telegraph:
			telegraph.scale = Vector3.ONE * (0.4 + charge * 0.9)
		if model and model.has_method(&"set_charge"):
			model.set_charge(charge)
		if _telegraph_left <= 0.0:
			_show_telegraph(false)
			_telegraph_left = -1.0
			_fire_left = fire_interval
			_fire_volley()
		return
	_fire_left -= delta
	if _fire_left <= 0.0 and _is_on_screen() and phase != MovePhase.EXIT:
		_show_telegraph(true)
		_telegraph_left = telegraph_time


func _fire_volley() -> void:
	match fire_pattern:
		FirePattern.STRAIGHT:
			weapon.fire_at(Vector3.LEFT)
		FirePattern.AIMED:
			weapon.fire_at(_aim_at_player())
		FirePattern.AIMED_BURST:
			_burst_aim = _aim_at_player()
			weapon.fire_at(_burst_aim)
			_burst_left = burst_count - 1
			_burst_timer = burst_spacing
		FirePattern.DIAGONAL_PAIR:
			weapon.fire_at(Vector3(-1, 0.45, 0))
			weapon.fire_at(Vector3(-1, -0.45, 0))
		FirePattern.SPREAD_FAN:
			var center := _aim_at_player()
			var base_angle := atan2(center.y, center.x)
			for i in spread_count:
				var t := 0.0 if spread_count == 1 else float(i) / float(spread_count - 1) - 0.5
				var a := base_angle + deg_to_rad(spread_angle) * t
				weapon.fire_at(Vector3(cos(a), sin(a), 0), 0.85)
		FirePattern.RADIAL_RING:
			# Alternate the ring offset so safe gaps move between volleys.
			for i in ring_count:
				var a := TAU * float(i) / float(ring_count) + _ring_offset
				weapon.fire_at(Vector3(cos(a), sin(a), 0), 0.7)
			_ring_offset = PI / float(ring_count) - _ring_offset
	if model and model.has_method(&"recoil"):
		model.recoil()
	if model and model.has_method(&"set_charge"):
		model.set_charge(0.0)
	Vfx.spawn(get_tree(), muzzle_effect, muzzle_position(), 1.0 if not is_elite() else 1.5)


func _aim_at_player() -> Vector3:
	var player := get_tree().get_first_node_in_group(ShipPlayer.GROUP) as Node3D
	if player == null or not player.visible:
		return Vector3.LEFT
	var to_player := player.global_position - global_position
	to_player.z = 0.0
	return to_player.normalized() if to_player.length_squared() > 0.01 else Vector3.LEFT


func _show_telegraph(shown: bool) -> void:
	if telegraph:
		telegraph.visible = shown
		telegraph.scale = Vector3.ONE * 0.4


func _is_on_screen() -> bool:
	return _camera != null and _camera.get_play_rect().has_point(Vector2(global_position.x, global_position.y))


# --- Damage -------------------------------------------------------------------

func _on_damaged(_payload: DamagePayload, _source: Node) -> void:
	flash.flash(0.08)


func _on_depleted(_source: Node) -> void:
	RunSession.add_score(score_value)
	if is_elite():
		Vfx.spawn(get_tree(), collapse_effect, global_position, death_size)
		HitStop.trigger(get_tree(), 0.06)
		_drop_pickup()
	else:
		Vfx.spawn(get_tree(), death_effect, global_position, death_size)
	_spawn_fragments()
	defeated.emit(self)
	queue_free()


func _spawn_fragments() -> void:
	var root := get_tree().get_first_node_in_group(Vfx.ROOT_GROUP)
	if root == null or model == null or not model.has_method(&"make_fragments"):
		return
	var pieces: Array[Node3D] = model.make_fragments(5 if is_elite() else 3)
	root.add_child(FragmentBurst.create(pieces, global_position, 6.0 if is_elite() else 5.0))


func _drop_pickup() -> void:
	if pickup_scene == null:
		push_error("Elite '%s' drops '%s' but has no pickup scene." % [name, drop_echo])
		return
	var root := get_tree().get_first_node_in_group(EchoPickup.ROOT_GROUP)
	if root == null:
		push_error("No node in group '%s'; add a Pickups node to the level." % EchoPickup.ROOT_GROUP)
		return
	var pickup := pickup_scene.instantiate() as EchoPickup
	pickup.echo_id = drop_echo
	pickup.position = global_position - (root as Node3D).global_position
	# Deferred: death happens inside a physics callback, where new areas can't be set up.
	root.add_child.call_deferred(pickup)
