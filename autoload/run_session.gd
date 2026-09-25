extends Node
## Cross-scene run state: health, score, Echo Energy, selected echo, difficulty and
## the checkpoint snapshot. UI reads these signals; gameplay writes through the setters.

signal health_changed(current: int, maximum: int)
signal score_changed(score: int)
signal energy_changed(segments: int)
signal echo_changed(echo_id: StringName)
signal echo_ammo_changed(ammo: int)
signal checkpoint_saved(checkpoint_id: StringName)
signal run_reset

enum Difficulty { STORY, ARCADE }

const MAX_ENERGY := 3
## Kill value (score points) that fills one energy segment.
const CHARGE_PER_SEGMENT := 600
const DEFAULT_MAX_HEALTH := 5
const NO_ECHO := &""

var max_health: int = DEFAULT_MAX_HEALTH
var health: int = DEFAULT_MAX_HEALTH
var score: int = 0
var energy: int = 0
var selected_echo: StringName = NO_ECHO
## Shots left on the active echo weapon; the echo is dropped when it reaches zero.
var echo_ammo: int = 0
var difficulty: Difficulty = Difficulty.ARCADE
var checkpoint_id: StringName = &""
var energy_charge: int = 0

var _checkpoint: Dictionary = {}


func reset_run() -> void:
	max_health = DEFAULT_MAX_HEALTH
	health = max_health
	score = 0
	energy = 0
	selected_echo = NO_ECHO
	echo_ammo = 0
	energy_charge = 0
	checkpoint_id = &""
	_checkpoint.clear()
	run_reset.emit()
	health_changed.emit(health, max_health)
	score_changed.emit(score)
	energy_changed.emit(energy)
	echo_changed.emit(selected_echo)
	echo_ammo_changed.emit(echo_ammo)


## Heart Tank: one more health segment for the rest of the run, fully refilled.
func increase_max_health(segments: int = 1) -> void:
	max_health += segments
	health = max_health
	health_changed.emit(health, max_health)


func set_health(value: int) -> void:
	var clamped := clampi(value, 0, max_health)
	if clamped == health:
		return
	health = clamped
	health_changed.emit(health, max_health)


func add_score(points: int) -> void:
	if points <= 0:
		return
	score += points
	score_changed.emit(score)


## Adds (or removes, if negative) energy segments. Returns the change actually applied.
func add_energy(segments: int) -> int:
	var before := energy
	energy = clampi(energy + segments, 0, MAX_ENERGY)
	if energy != before:
		energy_changed.emit(energy)
	return energy - before


## Kills charge the SUPER meter: every CHARGE_PER_SEGMENT points of kill value = one segment.
func add_charge(points: int) -> void:
	if points <= 0 or energy >= MAX_ENERGY:
		return
	energy_charge += points
	while energy_charge >= CHARGE_PER_SEGMENT and energy < MAX_ENERGY:
		energy_charge -= CHARGE_PER_SEGMENT
		add_energy(1)
	if energy >= MAX_ENERGY:
		energy_charge = 0


func super_ready() -> bool:
	return energy >= MAX_ENERGY


## Spends `cost` segments only if all of them are available.
func spend_energy(cost: int) -> bool:
	if cost <= 0 or energy < cost:
		return false
	add_energy(-cost)
	return true


func set_echo(echo_id: StringName) -> void:
	if echo_id == selected_echo:
		return
	selected_echo = echo_id
	echo_changed.emit(selected_echo)


## Installs an echo weapon with a shot budget, replacing any current one.
func equip_echo(echo_id: StringName, ammo: int) -> void:
	echo_ammo = maxi(0, ammo)
	set_echo(echo_id if echo_ammo > 0 else NO_ECHO)
	echo_ammo_changed.emit(echo_ammo)


## Spends shots from the active echo. Returns false if no echo is active.
func consume_echo_ammo(shots: int = 1) -> bool:
	if selected_echo == NO_ECHO or echo_ammo <= 0:
		return false
	echo_ammo = maxi(0, echo_ammo - shots)
	echo_ammo_changed.emit(echo_ammo)
	if echo_ammo == 0:
		set_echo(NO_ECHO)
	return true


func clear_echo() -> void:
	equip_echo(NO_ECHO, 0)


func save_checkpoint(id: StringName) -> void:
	checkpoint_id = id
	_checkpoint = {
		"id": id,
		"score": score,
		"energy": energy,
		"echo": selected_echo,
		"echo_ammo": echo_ammo,
	}
	checkpoint_saved.emit(id)


func has_checkpoint() -> bool:
	return not _checkpoint.is_empty()


## Checkpoint policy: base health restored, module and energy held at activation kept,
## score reset to the snapshot.
func restore_checkpoint() -> bool:
	if _checkpoint.is_empty():
		return false
	set_health(max_health)
	score = _checkpoint["score"]
	score_changed.emit(score)
	energy = _checkpoint["energy"]
	energy_changed.emit(energy)
	equip_echo(_checkpoint["echo"], _checkpoint["echo_ammo"])
	return true
