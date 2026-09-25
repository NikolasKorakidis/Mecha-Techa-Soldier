class_name RetroEnemy
extends Sprite2D
## Stage 4 enemies (one class, behaviour by kind):
##   drone     sine-wave formation flyer          dart      fast, homes on your line once
##   pod       flies in, parks, fires aimed shots heavy     slow gunship, 3-way volleys
##   turret    fixed to the fortress terrain      rock      asteroid; big ones split in two
## `carrier` enemies flash; destroying a whole carrier wave drops a power-up capsule.

enum Kind { DRONE, DART, POD, HEAVY, TURRET, ROCK_BIG, ROCK_SMALL }

const STATS := {
	Kind.DRONE: {"sheet": &"enemy_drone", "hp": 1, "score": 100, "rect": Rect2(-5, -4, 10, 8)},
	Kind.DART: {"sheet": &"enemy_dart", "hp": 1, "score": 150, "rect": Rect2(-7, -3, 14, 6)},
	Kind.POD: {"sheet": &"enemy_pod", "hp": 4, "score": 300, "rect": Rect2(-7, -6, 14, 12)},
	Kind.HEAVY: {"sheet": &"enemy_heavy", "hp": 12, "score": 800, "rect": Rect2(-11, -6, 22, 12)},
	Kind.TURRET: {"sheet": &"enemy_turret", "hp": 3, "score": 300, "rect": Rect2(-7, -5, 14, 10)},
	Kind.ROCK_BIG: {"sheet": &"asteroid_big", "hp": 5, "score": 200, "rect": Rect2(-10, -10, 20, 20)},
	Kind.ROCK_SMALL: {"sheet": &"asteroid_small", "hp": 1, "score": 50, "rect": Rect2(-5, -5, 10, 10)},
}

var kind: Kind = Kind.DRONE
var hp: int = 1
var score: int = 100
var wave_id: int = -1
var carrier: bool = false
var velocity: Vector2 = Vector2(-60, 0)
var hit_rect: Rect2
## Turrets on the ceiling hang upside down.
var ceiling: bool = false

var _time: float = 0.0
var _base_y: float = 0.0
var _phase: float = 0.0
var _fire_left: float = 1.0
var _homed: bool = false
var _flash: float = 0.0


static func create(k: Kind, at: Vector2, phase: float = 0.0) -> RetroEnemy:
	var e := RetroEnemy.new()
	e.kind = k
	var stats: Dictionary = STATS[k]
	e.texture = RetroArt.texture(stats["sheet"])
	e.hframes = RetroArt.FRAMES.get(stats["sheet"], 1)
	e.hp = stats["hp"]
	e.score = stats["score"]
	e.hit_rect = stats["rect"]
	e.position = at
	e._base_y = at.y
	e._phase = phase
	e._fire_left = 0.8 + fmod(phase * 7.3, 1.2)
	match k:
		Kind.DART:
			e.velocity = Vector2(-150, 0)
		Kind.POD:
			e.velocity = Vector2(-70, 0)
		Kind.HEAVY:
			e.velocity = Vector2(-22, 0)
		Kind.TURRET:
			e.velocity = Vector2.ZERO
		Kind.ROCK_BIG, Kind.ROCK_SMALL:
			e.velocity = Vector2(-40 - fmod(phase * 13.0, 25.0), fmod(phase * 17.0, 24.0) - 12.0)
	return e


## Moves one tick; returns enemy shots as [position, velocity] pairs.
func tick(delta: float, player_pos: Vector2, scroll_speed: float) -> Array:
	_time += delta
	_flash = maxf(0.0, _flash - delta)
	if hframes > 1:
		frame = int(_time * 8.0) % 2 if not carrier else int(_time * 12.0) % 2
	modulate = Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	var shots: Array = []
	match kind:
		Kind.DRONE:
			position.x += velocity.x * delta
			position.y = _base_y + sin(_time * 3.2 + _phase) * 26.0
		Kind.DART:
			if not _homed and _time > 0.5:
				_homed = true
				velocity.y = clampf((player_pos.y - position.y) * 1.6, -80.0, 80.0)
			position += velocity * delta
		Kind.POD:
			if _time < 1.6:
				position.x += velocity.x * delta
			elif _time > 6.5:
				position.x += velocity.x * 1.4 * delta
			_fire_left -= delta
			if _fire_left <= 0.0 and _time > 1.0:
				_fire_left = 1.3
				shots.append([position, (player_pos - position).normalized() * 90.0])
		Kind.HEAVY:
			position.x += velocity.x * delta
			position.y = _base_y + sin(_time * 1.1) * 12.0
			_fire_left -= delta
			if _fire_left <= 0.0:
				_fire_left = 1.6
				var aim := (player_pos - position).normalized()
				for a: float in [-0.3, 0.0, 0.3]:
					shots.append([position + Vector2(-10, 0), aim.rotated(a) * 80.0])
		Kind.TURRET:
			position.x -= scroll_speed * delta
			_fire_left -= delta
			var on_screen := position.x < RetroArt.SCREEN.x - 8.0 and position.x > 16.0
			if _fire_left <= 0.0 and on_screen:
				_fire_left = 1.7
				shots.append([position + Vector2(0, 5.0 if ceiling else -5.0), (player_pos - position).normalized() * 85.0])
		Kind.ROCK_BIG, Kind.ROCK_SMALL:
			position += velocity * delta
			if position.y < RetroArt.HUD_H + 8.0 or position.y > RetroArt.SCREEN.y - 8.0:
				velocity.y = -velocity.y
	return shots


func world_hit_rect() -> Rect2:
	return Rect2(position + hit_rect.position, hit_rect.size)


## Returns true when destroyed.
func damage(amount: int) -> bool:
	hp -= amount
	_flash = 0.06
	return hp <= 0


func offscreen() -> bool:
	return position.x < -32.0 or position.x > RetroArt.SCREEN.x + 96.0 or position.y < -32.0 or position.y > RetroArt.SCREEN.y + 32.0
