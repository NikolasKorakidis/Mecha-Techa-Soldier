class_name BossBase
extends Node3D
## Shared boss flow. Explicit states only:
##   INTRO → PHASE_1 → BREAK_1 → PHASE_2 → BREAK_2 → PHASE_3 → DEFEATED
## Transitions cannot skip or repeat (health floors hold each phase until its break).
## Breaks: boss invulnerable, hostile bullets cleared, player granted invulnerability.
## Each phase draws attacks from a small legal list with no back-to-back repeats; the
## first use of any attack is slower. Subclasses implement the attacks.

signal health_changed(current: int, maximum: int)
signal state_changed(state: State, reason: String)
signal defeated

enum State { INTRO, PHASE_1, BREAK_1, PHASE_2, BREAK_2, PHASE_3, DEFEATED }

const GROUP := &"bosses"

@export var boss_name: String = "GUARDIAN"
@export var max_health: int = 300
## Health ratios that end phase 1 and phase 2.
@export var phase_thresholds: Vector2 = Vector2(0.66, 0.33)
@export var intro_time: float = 2.6
@export var break_time: float = 1.8
@export var rest_time: Vector2 = Vector2(0.9, 0.6)
@export var home_position: Vector3 = Vector3(10, 0, 0)
@export var intro_offset: float = 14.0
@export var health: HealthComponent
## Main weak point; also what Arc lightning targets.
@export var hurtbox: HurtboxComponent
@export var death_effect: PackedScene
@export var defeat_score: int = 20000

var state: State = State.INTRO
## Where summoned minions go (set by the level director).
var summon_root: Node3D
var current_attack: StringName = &""
var last_transition_reason: String = ""

var _state_time: float = 0.0
var _attack_time: float = 0.0
var _rest_left: float = 0.0
var _attack_index: Dictionary = {}
var _used_attacks: Dictionary = {}
var _current_first_use: bool = false
var _defeat_time: float = 0.0
var _defeat_finished: bool = false
var _camera: GameplayCamera
var _flash: FlashComponent


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SpaceEnemy.GROUP)
	add_to_group(&"debug_telemetry")
	_camera = GameplayCamera.find(get_tree())
	health.max_health = max_health
	health.setup(max_health, max_health)
	health.health_changed.connect(_on_health_changed)
	health.depleted.connect(_on_depleted)
	global_position = _home() + Vector3(intro_offset, 0, 0)
	_flash = FlashComponent.new()
	_flash.mode = FlashComponent.Mode.OVERLAY
	_flash.target = get_node_or_null(^"Model") as Node3D
	add_child(_flash)
	health.damaged.connect(func(_p: DamagePayload, _s: Node) -> void: _flash.flash(0.05))
	_apply_state_rules()


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	_state_time += delta
	match state:
		State.INTRO:
			var t := clampf(_state_time / intro_time, 0.0, 1.0)
			global_position = _home() + Vector3(intro_offset * pow(1.0 - t, 3.0), 0, 0)
			if _state_time >= intro_time:
				_transition(State.PHASE_1, "intro finished")
		State.BREAK_1:
			if _state_time >= break_time:
				_transition(State.PHASE_2, "break finished")
		State.BREAK_2:
			if _state_time >= break_time:
				_transition(State.PHASE_3, "break finished")
		State.PHASE_1, State.PHASE_2, State.PHASE_3:
			_update_attacks(delta)
			if _phase_complete():
				_transition(State.BREAK_1 if state == State.PHASE_1 else State.BREAK_2, "phase objective met")
		State.DEFEATED:
			_update_defeat(delta)
	_animate(delta)


func phase_number() -> int:
	match state:
		State.PHASE_1, State.BREAK_1:
			return 1
		State.PHASE_2, State.BREAK_2:
			return 2
		State.PHASE_3, State.DEFEATED:
			return 3
	return 0


func is_alive() -> bool:
	return state != State.DEFEATED


func is_attackable() -> bool:
	return state in [State.PHASE_1, State.PHASE_2, State.PHASE_3]


## Debug: jump to the next legal state (skips waiting, never skips a state).
func debug_advance_phase() -> void:
	match state:
		State.INTRO:
			_transition(State.PHASE_1, "debug")
		State.PHASE_1:
			_transition(State.BREAK_1, "debug")
		State.BREAK_1:
			_transition(State.PHASE_2, "debug")
		State.PHASE_2:
			_transition(State.BREAK_2, "debug")
		State.BREAK_2:
			_transition(State.PHASE_3, "debug")
		State.PHASE_3:
			health.floor_health = 0
			health.invulnerable = false
			health.apply_damage(DamagePayload.create(health.current, Teams.Team.PLAYER), self)


func get_debug_lines() -> PackedStringArray:
	return PackedStringArray([
		"BOSS %s  %s  hp %d/%d  attack %s" % [boss_name, State.keys()[state], health.current, max_health,
				current_attack if current_attack != &"" else "-"],
		"  last transition: %s" % last_transition_reason,
	])


static func clear_hostile_projectiles(tree: SceneTree) -> void:
	var root := tree.get_first_node_in_group(Projectile.ROOT_GROUP)
	if root:
		for child in root.get_children():
			var projectile := child as Projectile
			if projectile and projectile.hitbox and projectile.hitbox.payload \
					and projectile.hitbox.payload.team == Teams.Team.ENEMY:
				projectile.queue_free()
	for hazard in tree.get_nodes_in_group(BeamHazard.GROUP):
		hazard.queue_free()


# --- Overridables ----------------------------------------------------------------

## Attack names legal in `phase` (1..3), in their preferred rotation order.
func _phase_attacks(_phase: int) -> Array[StringName]:
	return []


func _attack_duration(_attack: StringName, _first_use: bool) -> float:
	return 2.0


func _attack_begin(_attack: StringName, _first_use: bool) -> void:
	pass


func _attack_update(_attack: StringName, _time: float, _delta: float) -> void:
	pass


## Default objective: health threshold for the current phase.
func _phase_complete() -> bool:
	match state:
		State.PHASE_1:
			return health.current <= _threshold_value(phase_thresholds.x)
		State.PHASE_2:
			return health.current <= _threshold_value(phase_thresholds.y)
	return false


func _on_state_entered(_new_state: State) -> void:
	pass


func _animate(_delta: float) -> void:
	pass


# --- Internals -------------------------------------------------------------------

func _transition(next: State, reason: String) -> void:
	var previous := state
	state = next
	_state_time = 0.0
	last_transition_reason = "%s → %s (%s)" % [State.keys()[previous], State.keys()[next], reason]
	current_attack = &""
	_rest_left = 1.0
	_apply_state_rules()
	if next == State.BREAK_1 or next == State.BREAK_2:
		clear_hostile_projectiles(get_tree())
		var player := get_tree().get_first_node_in_group(ShipPlayer.GROUP) as ShipPlayer
		if player:
			player.grant_invulnerability(break_time + 0.5)
		Vfx.spawn(get_tree(), death_effect, global_position + Vector3(0, 0, 1), 2.0)
	_on_state_entered(next)
	state_changed.emit(state, reason)


## Whether the weak point can take damage right now (e.g. armor closed).
func _core_exposed() -> bool:
	return true


func _apply_state_rules() -> void:
	health.invulnerable = not is_attackable() or not _core_exposed()
	match state:
		State.PHASE_1:
			health.floor_health = _threshold_value(phase_thresholds.x)
		State.PHASE_2:
			health.floor_health = _threshold_value(phase_thresholds.y)
		State.PHASE_3:
			health.floor_health = 0


func _threshold_value(ratio: float) -> int:
	return int(ceil(max_health * ratio))


func _update_attacks(delta: float) -> void:
	if current_attack == &"":
		_rest_left -= delta
		if _rest_left <= 0.0:
			_start_next_attack()
		return
	_attack_time += delta
	_attack_update(current_attack, _attack_time, delta)
	if _attack_time >= _attack_duration(current_attack, _current_first_use):
		current_attack = &""
		_rest_left = rest_time.x if phase_number() < 3 else rest_time.y


func _start_next_attack() -> void:
	var attacks := _phase_attacks(phase_number())
	if attacks.is_empty():
		return
	var phase := phase_number()
	var index: int = _attack_index.get(phase, 0)
	var attack := attacks[index % attacks.size()]
	_attack_index[phase] = index + 1
	_current_first_use = not _used_attacks.has(attack)
	_used_attacks[attack] = true
	current_attack = attack
	_attack_time = 0.0
	_attack_begin(attack, _current_first_use)


func _on_health_changed(current: int, maximum: int) -> void:
	health_changed.emit(current, maximum)


func _on_depleted(_source: Node) -> void:
	if state != State.PHASE_3:
		push_error("BossBase: depleted outside PHASE_3 (%s)." % State.keys()[state])
	_transition(State.DEFEATED, "health depleted")
	clear_hostile_projectiles(get_tree())
	RunSession.add_score(defeat_score)


func _update_defeat(delta: float) -> void:
	if _defeat_finished:
		return
	_defeat_time += delta
	# Chain of explosions across the hull, then the finale.
	if fmod(_defeat_time, 0.18) < delta:
		var offset := Vector3(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5), 1.0)
		Vfx.spawn(get_tree(), death_effect, global_position + offset, randf_range(0.8, 1.6))
	global_position += Vector3(randf_range(-0.08, 0.08), randf_range(-0.08, 0.08), 0)
	if _defeat_time >= 2.2:
		# Several physics steps can run before queue_free lands; finish exactly once.
		_defeat_finished = true
		Vfx.spawn(get_tree(), death_effect, global_position + Vector3(0, 0, 1), 4.0)
		defeated.emit()
		queue_free()


func _home() -> Vector3:
	var origin := _camera.global_position if _camera else Vector3.ZERO
	return Vector3(origin.x + home_position.x, home_position.y, 0.0)


func _player_position() -> Vector3:
	var player := get_tree().get_first_node_in_group(ShipPlayer.GROUP) as Node3D
	return player.global_position if player and player.visible else global_position + Vector3.LEFT * 10.0


func _aim_at_player(from: Vector3) -> Vector3:
	var d := _player_position() - from
	d.z = 0.0
	return d.normalized() if d.length_squared() > 0.01 else Vector3.LEFT


func _spawn_beam(y: float, warn: float, active: float, color: Color, thickness: float = 1.0) -> void:
	var root := Projectile.find_root(get_tree())
	if root:
		root.add_child(BeamHazard.create(y, warn, active, color, thickness))
