class_name RetroBoss
extends Sprite2D
## Stage 4 boss, CORE BREAKER: an armoured battle core (8-bit cousin of the Choir Engine).
## Rhythm: shutters CLOSED (gun ports rake straight lines, darts launch) → OPEN (the core glows
## and fires aimed fans; only now can it be hurt). Below half health it cycles faster and adds
## 12-shot rings. The stage runs collisions; this reports shots and dart launches.

enum State { ENTER, CLOSED, OPEN, DYING }

const MAX_HP := 70
const HOME_X := 196.0

var hp: int = MAX_HP
var state: State = State.ENTER
## Core hitbox (damage) and the armour above/below it (absorbs shots), relative to the sprite
## centre. The prow channel in the middle leads straight to the core.
var core_rect := Rect2(-12, -10, 24, 20)
var hull_rect := Rect2(-36, -34, 76, 68)
var armour_rects: Array[Rect2] = [Rect2(-30, -34, 70, 23), Rect2(-30, 11, 70, 23)]

var _time: float = 0.0
var _state_time: float = 0.0
var _fire_left: float = 0.6
var _flash: float = 0.0
var _dart_left: float = 1.2


func _init() -> void:
	texture = RetroArt.texture(&"boss")
	hframes = 2
	position = Vector2(RetroArt.SCREEN.x + 50.0, 120.0)


func core_open() -> bool:
	return state == State.OPEN


func enraged() -> bool:
	return hp <= MAX_HP / 2


## Returns [shots, darts]: shots as [position, velocity], darts as spawn positions.
func tick(delta: float, player_pos: Vector2) -> Array:
	_time += delta
	_state_time += delta
	_flash = maxf(0.0, _flash - delta)
	modulate = Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	frame = 1 if state == State.OPEN else 0
	var shots: Array = []
	var darts: Array = []
	if state == State.DYING:
		position += Vector2(randf_range(-1, 1), randf_range(-1, 1))
		return [shots, darts]
	var target_y := 120.0 + sin(_time * 0.7) * 58.0
	if state == State.ENTER:
		position.x = move_toward(position.x, HOME_X, 40.0 * delta)
		if position.x <= HOME_X + 0.5:
			_set_state(State.CLOSED)
		return [shots, darts]
	position.y = move_toward(position.y, target_y, 40.0 * delta)
	var speed := 1.5 if enraged() else 1.0
	_fire_left -= delta * speed
	match state:
		State.CLOSED:
			if _fire_left <= 0.0:
				_fire_left = 0.55
				for gy: float in [-26.0, 26.0]:
					shots.append([position + Vector2(-36, gy), Vector2(-120, 0)])
			_dart_left -= delta * speed
			if _dart_left <= 0.0:
				_dart_left = 2.4
				darts.append(position + Vector2(-20, -40))
				darts.append(position + Vector2(-20, 40))
			if _state_time > (2.0 if enraged() else 2.8):
				_set_state(State.OPEN)
		State.OPEN:
			if _fire_left <= 0.0:
				_fire_left = 0.7
				var aim := (player_pos - position).normalized()
				var fan := [-0.4, -0.2, 0.0, 0.2, 0.4] if enraged() else [-0.25, 0.0, 0.25]
				for a: float in fan:
					shots.append([position + Vector2(-6, 0), aim.rotated(a) * 85.0])
				if enraged() and int(_state_time * 2.0) % 2 == 0:
					for k in 12:
						shots.append([position, Vector2.RIGHT.rotated(TAU * k / 12.0 + _time) * 60.0])
			if _state_time > 2.2:
				_set_state(State.CLOSED)
	return [shots, darts]


## Returns true when this hit destroyed it.
func damage(amount: int) -> bool:
	if state != State.OPEN:
		return false
	hp = maxi(0, hp - amount)
	_flash = 0.05
	if hp == 0:
		_set_state(State.DYING)
		return true
	return false


func world_rect(local: Rect2) -> Rect2:
	return Rect2(position + local.position, local.size)


func _set_state(next: State) -> void:
	state = next
	_state_time = 0.0
	_fire_left = 0.4
