class_name ShipMovement
extends Node
## Free-flight movement on the gameplay plane: acceleration, ease-out, dash, vertical
## burst and the soft camera boundary. Knows nothing about weapons or health.

signal dash_started(direction: Vector2)
signal dash_ended

var tuning: ShipTuning
var velocity: Vector2 = Vector2.ZERO
var is_dashing: bool = false
var dash_cooldown_left: float = 0.0

var _dash_time: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _burst_time_left: float = 0.0
var _burst_direction: float = 1.0
var _burst_cooldown_left: float = 0.0


func step(delta: float, move_dir: Vector2) -> void:
	dash_cooldown_left = maxf(0.0, dash_cooldown_left - delta)
	_burst_cooldown_left = maxf(0.0, _burst_cooldown_left - delta)

	if is_dashing:
		_dash_time += delta
		velocity = _dash_direction * tuning.dash_speed
		if _dash_time >= tuning.dash_duration:
			_end_dash()
		return

	var target := move_dir.limit_length(1.0) * tuning.max_speed
	var rate := tuning.acceleration if move_dir.length_squared() > 0.0 else tuning.deceleration
	velocity = velocity.move_toward(target, rate * delta)

	if _burst_time_left > 0.0:
		_burst_time_left -= delta
		velocity.y = _burst_direction * tuning.burst_speed


## Dashes toward the stick, or forward (+X) when the stick is neutral.
func try_dash(move_dir: Vector2) -> bool:
	if is_dashing or dash_cooldown_left > 0.0:
		return false
	_dash_direction = move_dir.normalized() if move_dir.length_squared() > 0.01 else Vector2.RIGHT
	_dash_time = 0.0
	is_dashing = true
	dash_cooldown_left = tuning.dash_cooldown
	_burst_time_left = 0.0
	dash_started.emit(_dash_direction)
	return true


## Short vertical dodge in the stick's vertical direction (up when neutral).
func try_burst(vertical: float) -> bool:
	if is_dashing or _burst_cooldown_left > 0.0:
		return false
	_burst_direction = -1.0 if vertical < -0.2 else 1.0
	_burst_time_left = tuning.burst_duration
	_burst_cooldown_left = tuning.burst_cooldown
	return true


func cancel_dash() -> void:
	if is_dashing:
		_end_dash()


func is_dash_invulnerable() -> bool:
	return is_dashing and _dash_time < tuning.dash_invulnerability


## 0 = ready, 1 = just used.
func dash_cooldown_ratio() -> float:
	return dash_cooldown_left / tuning.dash_cooldown if tuning.dash_cooldown > 0.0 else 0.0


## Fades outward velocity near the edges, integrates, and clamps inside `rect`.
func move_within(position: Vector2, rect: Rect2, delta: float) -> Vector2:
	# World Y is up, so the screen top is rect.end.y (Rect2's "bottom" argument).
	var m := tuning.boundary_margin
	var inner := rect.grow_individual(-m.x, -m.y, -m.x, -(m.y + tuning.hud_top_inset))
	if not is_dashing and tuning.soft_edge > 0.0:
		if velocity.x > 0.0:
			velocity.x *= clampf((inner.end.x - position.x) / tuning.soft_edge, 0.0, 1.0)
		elif velocity.x < 0.0:
			velocity.x *= clampf((position.x - inner.position.x) / tuning.soft_edge, 0.0, 1.0)
		if velocity.y > 0.0:
			velocity.y *= clampf((inner.end.y - position.y) / tuning.soft_edge, 0.0, 1.0)
		elif velocity.y < 0.0:
			velocity.y *= clampf((position.y - inner.position.y) / tuning.soft_edge, 0.0, 1.0)
	var next := position + velocity * delta
	var clamped := Vector2(clampf(next.x, inner.position.x, inner.end.x), clampf(next.y, inner.position.y, inner.end.y))
	if clamped.x != next.x:
		velocity.x = 0.0
	if clamped.y != next.y:
		velocity.y = 0.0
	return clamped


func reset() -> void:
	velocity = Vector2.ZERO
	is_dashing = false
	dash_cooldown_left = 0.0
	_burst_time_left = 0.0
	_burst_cooldown_left = 0.0


func _end_dash() -> void:
	is_dashing = false
	velocity = _dash_direction * tuning.max_speed
	dash_ended.emit()
