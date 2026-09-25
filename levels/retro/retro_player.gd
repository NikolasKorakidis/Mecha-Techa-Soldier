class_name RetroPlayer
extends Sprite2D
## Stage 4 ship: the Kestrel as an 8-bit sprite. Moves in the playfield, fires by weapon level
## (1 single, 2 twin, 3 twin + diagonals, 4 five-way spread), blinks while invulnerable.
## The stage owns shots and collisions; this only reports what to spawn.

const SPEED := 96.0
const FIRE_INTERVAL := 0.11
const MARGIN := Vector2(10.0, 7.0)

var weapon: int = 1
var alive: bool = true
var invulnerable_left: float = 0.0
## Small hitbox around the cockpit (NES-fair).
var hit_rect := Rect2(-7, -3, 14, 6)

var _cooldown: float = 0.0
var _anim: float = 0.0


func _init() -> void:
	texture = RetroArt.texture(&"player")
	hframes = 2


## Returns the shots fired this tick as [position, velocity] pairs.
func tick(delta: float, move: Vector2, fire: bool) -> Array:
	_anim += delta
	frame = int(_anim * 12.0) % 2
	invulnerable_left = maxf(0.0, invulnerable_left - delta)
	visible = alive and (invulnerable_left <= 0.0 or fmod(invulnerable_left, 0.12) < 0.07)
	if not alive:
		return []
	position += move.limit_length(1.0) * SPEED * delta
	position.x = clampf(position.x, MARGIN.x, RetroArt.SCREEN.x - MARGIN.x)
	position.y = clampf(position.y, RetroArt.HUD_H + MARGIN.y, RetroArt.SCREEN.y - MARGIN.y)
	_cooldown = maxf(0.0, _cooldown - delta)
	if not fire or _cooldown > 0.0:
		return []
	_cooldown = FIRE_INTERVAL
	var nose := position + Vector2(10, 0)
	var shots: Array = []
	match weapon:
		1:
			shots.append([nose, Vector2(260, 0)])
		2:
			shots.append([nose + Vector2(0, -3), Vector2(260, 0)])
			shots.append([nose + Vector2(0, 3), Vector2(260, 0)])
		3:
			shots.append([nose + Vector2(0, -3), Vector2(260, 0)])
			shots.append([nose + Vector2(0, 3), Vector2(260, 0)])
			shots.append([nose, Vector2(230, -110)])
			shots.append([nose, Vector2(230, 110)])
		_:
			for angle: float in [-0.5, -0.25, 0.0, 0.25, 0.5]:
				shots.append([nose, Vector2(260, 0).rotated(angle)])
	return shots


func world_hit_rect() -> Rect2:
	return Rect2(position + hit_rect.position, hit_rect.size)


func vulnerable() -> bool:
	return alive and invulnerable_left <= 0.0
