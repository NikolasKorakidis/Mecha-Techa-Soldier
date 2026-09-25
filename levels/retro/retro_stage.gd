class_name RetroStage
extends Node
## Stage 4 — PIXEL RIPTIDE: an 8-bit rearrangement of Stage 1 in a completely different style.
## Everything renders into a 256x224 SubViewport (the NES frame) shown full screen with
## nearest-neighbour scaling on a canvas layer above the modern HUD. Open space → asteroid belt
## → fortress corridor with terrain and turrets → CORE BREAKER boss.
## Shares RunSession (health, score, SUPER energy); the SUPER becomes a screen-clearing bomb.
## The stage owns its entities and runs collisions itself (classic fixed-screen shooter loop).

signal cleared

const SCROLL := 40.0
const LAYER := 12

@export var auto_start: bool = false
## Standalone: go to this scene after the clear. Campaign: leave empty and listen to `cleared`.
@export_file("*.tscn") var next_level: String = ""
@export var read_devices: bool = true

var active: bool = false
var time: float = 0.0
var boss: RetroBoss
var player: RetroPlayer
var enemies: Array[RetroEnemy] = []
var finished: bool = false

var _layer: CanvasLayer
var _viewport: SubViewport
var _world: Node2D
var _playfield: Node2D
var _stars_far: Sprite2D
var _stars_near: Sprite2D
var _planet: Sprite2D
var _terrain: Node2D
var _terrain_heights: Array = []
var _hud: Node2D
var _score_text: RetroText
var _power_text: RetroText
var _hearts: Node2D
var _super_bar: ColorRect
var _banner: RetroText
var _banner_sub: RetroText
var _banner_left: float = 0.0
var _flash: ColorRect
var _player_shots: Array[Sprite2D] = []
var _enemy_shots: Array[Sprite2D] = []
var _pickups: Array[Sprite2D] = []
var _effects: Array[Sprite2D] = []
var _event_index: int = 0
var _wave_counter: int = 0
var _wave_alive: Dictionary = {}
var _respawn_left: float = -1.0
var _warning_left: float = 0.0
var _outro_left: float = -1.0
var _boss_explode_left: float = 0.0
var _move_override: Vector2 = Vector2.ZERO
var _fire_override: bool = false


func _ready() -> void:
	add_to_group(&"retro_stage")
	_build_screen()
	_layer.visible = false
	set_physics_process(false)
	if auto_start:
		begin.call_deferred()


func _exit_tree() -> void:
	if active:
		get_viewport().disable_3d = false


## Starts the stage (shows the 8-bit screen, hides the 3D world underneath).
func begin() -> void:
	if active:
		return
	active = true
	add_to_group(&"pausable_stage")
	_layer.visible = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_viewport().disable_3d = true
	player = RetroPlayer.new()
	player.position = Vector2(48, 120)
	_playfield.add_child(player)
	if RunSession.health <= 0:
		RunSession.set_health(RunSession.max_health)
	if RunSession.checkpoint_id != &"STAGE 4":
		RunSession.save_checkpoint(&"STAGE 4")
	AudioService.play_music(&"stage4", 0.2)
	_show_banner("STAGE 4", "PIXEL RIPTIDE", 2.6)
	set_physics_process(true)


## Scripted input for tests and bots.
func set_input(move: Vector2, fire: bool) -> void:
	_move_override = move
	_fire_override = fire


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	time += delta
	_scroll_backdrop(delta)
	_run_timeline()
	var move := _move_override
	var fire := _fire_override
	var special := false
	if read_devices:
		move = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		fire = Input.is_action_pressed(&"fire")
		special = Input.is_action_just_pressed(&"special")
	for s: Array in player.tick(delta, move, fire):
		_spawn_shot(_player_shots, &"shot_spread" if player.weapon >= 3 and absf(s[1].y) > 1.0 else &"shot_player", s[0], s[1])
		AudioService.play(&"retro_shot")
	if special and player.alive and RunSession.super_ready():
		_bomb()
	_update_enemies(delta)
	_update_boss(delta)
	_move_shots(_player_shots, delta)
	_move_shots(_enemy_shots, delta)
	_update_pickups(delta)
	_update_effects(delta)
	_collide()
	_update_respawn(delta)
	_update_hud(delta)
	_update_outro(delta)


# --- Screen ----------------------------------------------------------------------------------

func _build_screen() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(black)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(RetroArt.SCREEN)
	_viewport.disable_3d = true
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.snap_2d_transforms_to_pixel = true
	_viewport.snap_2d_vertices_to_pixel = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var screen := TextureRect.new()
	screen.texture = _viewport.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(screen)
	_world = Node2D.new()
	_viewport.add_child(_world)
	var sky := ColorRect.new()
	sky.color = Color.BLACK
	sky.size = RetroArt.SCREEN
	_world.add_child(sky)
	_stars_far = _repeating_layer(&"stars_far")
	_planet = Sprite2D.new()
	_planet.texture = RetroArt.texture(&"planet")
	_planet.position = Vector2(200, 150)
	_world.add_child(_planet)
	_stars_near = _repeating_layer(&"stars_near")
	_terrain = Node2D.new()
	_terrain.visible = false
	_world.add_child(_terrain)
	_playfield = Node2D.new()
	_world.add_child(_playfield)
	_build_hud()
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.size = RetroArt.SCREEN
	_world.add_child(_flash)


func _repeating_layer(sheet: StringName) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = RetroArt.texture(sheet)
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, RetroArt.SCREEN)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_world.add_child(s)
	return s


func _build_hud() -> void:
	_hud = Node2D.new()
	_world.add_child(_hud)
	var band := ColorRect.new()
	band.color = Color.BLACK
	band.size = Vector2(RetroArt.SCREEN.x, RetroArt.HUD_H)
	_hud.add_child(band)
	var rule := ColorRect.new()
	rule.color = Color("0058f8")
	rule.position = Vector2(0, RetroArt.HUD_H - 1)
	rule.size = Vector2(RetroArt.SCREEN.x, 1)
	_hud.add_child(rule)
	_score_text = _text(Vector2(6, 4), "1P 000000", Color("fcfcfc"))
	_hearts = Node2D.new()
	_hearts.position = Vector2(96, 4)
	_hud.add_child(_hearts)
	_power_text = _text(Vector2(164, 4), "PWR 1", Color("f8b800"))
	var frame := ColorRect.new()
	frame.color = Color("7c7c7c")
	frame.position = Vector2(206, 5)
	frame.size = Vector2(44, 6)
	_hud.add_child(frame)
	var hole := ColorRect.new()
	hole.color = Color.BLACK
	hole.position = Vector2(207, 6)
	hole.size = Vector2(42, 4)
	_hud.add_child(hole)
	_super_bar = ColorRect.new()
	_super_bar.color = Color("d800cc")
	_super_bar.position = Vector2(207, 6)
	_super_bar.size = Vector2(0, 4)
	_hud.add_child(_super_bar)
	_banner = _text(Vector2(RetroArt.SCREEN.x * 0.5, 92), "", Color("fcfcfc"))
	_banner.centered = true
	_banner.scale = Vector2(2, 2)
	_banner.position.x = RetroArt.SCREEN.x * 0.5
	_banner_sub = _text(Vector2(RetroArt.SCREEN.x * 0.5, 116), "", Color("f8b800"))
	_banner_sub.centered = true


func _text(at: Vector2, value: String, color: Color) -> RetroText:
	var t := RetroText.new()
	t.position = at
	t.text = value
	t.color = color
	_hud.add_child(t)
	return t


func _show_banner(title: String, sub: String, seconds: float) -> void:
	_banner.text = title
	_banner_sub.text = sub
	_banner_left = seconds


func _update_hud(delta: float) -> void:
	_score_text.text = "1P %06d" % mini(RunSession.score, 999999)
	_power_text.text = "PWR %d" % player.weapon
	var hearts := _hearts.get_child_count()
	if hearts != RunSession.max_health:
		for c in _hearts.get_children():
			c.queue_free()
		for i in RunSession.max_health:
			var h := RetroArt.sprite(&"heart")
			h.centered = false
			h.position = Vector2(i * 9, 0)
			_hearts.add_child(h)
	for i in _hearts.get_child_count():
		(_hearts.get_child(i) as Sprite2D).visible = i < RunSession.health
	var charge := float(RunSession.energy) / float(RunSession.MAX_ENERGY)
	_super_bar.size.x = 42.0 * charge
	_super_bar.color = Color("f878f8") if RunSession.super_ready() and fmod(time, 0.4) < 0.2 else Color("d800cc")
	if _banner_left > 0.0:
		_banner_left -= delta
		var blink := _warning_left > 0.0 and fmod(_banner_left, 0.5) < 0.2
		_banner.visible = not blink
		_banner_sub.visible = true
		if _banner_left <= 0.0:
			_banner.text = ""
			_banner_sub.text = ""
	_warning_left = maxf(0.0, _warning_left - delta)
	_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 3.0)


# --- Backdrop and terrain -------------------------------------------------------------------------

func _scroll_backdrop(delta: float) -> void:
	_stars_far.region_rect.position.x += SCROLL * 0.25 * delta
	_stars_near.region_rect.position.x += SCROLL * 1.2 * delta
	_planet.position.x -= SCROLL * 0.06 * delta
	if _terrain.visible:
		_terrain.position.x -= SCROLL * delta


func _start_terrain() -> void:
	_terrain.visible = true
	_terrain.position = Vector2(RetroArt.SCREEN.x, 0)
	var tile_tex := RetroArt.texture(&"tiles")
	var columns := mini(RetroTimeline.CEILING.length(), RetroTimeline.FLOOR.length())
	_terrain_heights.clear()
	for c in columns:
		var top := int(RetroTimeline.CEILING[c])
		var bottom := int(RetroTimeline.FLOOR[c])
		_terrain_heights.append(Vector2i(top, bottom))
		for k in top:
			_tile(tile_tex, c, RetroArt.HUD_H + k * RetroTimeline.TILE, 1 if k == top - 1 else (2 if (c + k) % 5 == 0 else 0), k == top - 1)
		for k in bottom:
			var y := RetroArt.SCREEN.y - (k + 1) * RetroTimeline.TILE
			_tile(tile_tex, c, y, 1 if k == bottom - 1 else (4 if (c * 3 + k) % 7 == 0 else (3 if k == 0 else 0)), false)
	for t: Array in RetroTimeline.TURRETS:
		var col: int = t[0]
		if col >= columns:
			continue
		var h: Vector2i = _terrain_heights[col]
		var on_ceiling: bool = t[1]
		var y := RetroArt.HUD_H + h.x * RetroTimeline.TILE + 5.0 if on_ceiling else RetroArt.SCREEN.y - h.y * RetroTimeline.TILE - 5.0
		var turret := RetroEnemy.create(RetroEnemy.Kind.TURRET, Vector2(RetroArt.SCREEN.x + col * RetroTimeline.TILE + 8.0, y), col)
		turret.ceiling = on_ceiling
		turret.flip_v = on_ceiling
		_add_enemy(turret)


func _tile(tex: Texture2D, column: int, y: float, index: int, flip: bool) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = 6
	s.frame = index
	s.centered = false
	s.flip_v = flip
	s.position = Vector2(column * RetroTimeline.TILE, y)
	_terrain.add_child(s)


## Solid terrain rects near screen x (world space), for collision.
func _terrain_rects_near(x0: float, x1: float) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if not _terrain.visible:
		return rects
	var c0 := int(floor((x0 - _terrain.position.x) / RetroTimeline.TILE))
	var c1 := int(floor((x1 - _terrain.position.x) / RetroTimeline.TILE))
	for c in range(maxi(c0, 0), mini(c1 + 1, _terrain_heights.size())):
		var h: Vector2i = _terrain_heights[c]
		var x := _terrain.position.x + c * RetroTimeline.TILE
		if h.x > 0:
			rects.append(Rect2(x, RetroArt.HUD_H, RetroTimeline.TILE, h.x * RetroTimeline.TILE))
		if h.y > 0:
			rects.append(Rect2(x, RetroArt.SCREEN.y - h.y * RetroTimeline.TILE, RetroTimeline.TILE, h.y * RetroTimeline.TILE))
	return rects


# --- Timeline and spawning -------------------------------------------------------------------------

func _run_timeline() -> void:
	while _event_index < RetroTimeline.EVENTS.size() and time >= RetroTimeline.EVENTS[_event_index][0]:
		var ev: Array = RetroTimeline.EVENTS[_event_index]
		_event_index += 1
		_spawn_event(ev[1], ev[2])


func _spawn_event(event: StringName, p: Dictionary) -> void:
	var right := RetroArt.SCREEN.x + 12.0
	match event:
		&"drones":
			_wave_counter += 1
			var carrier: bool = p.get("carrier", false)
			for i in int(p["count"]):
				var e := RetroEnemy.create(RetroEnemy.Kind.DRONE, Vector2(right + i * 18.0, p["y"]), i * 0.6)
				if carrier:
					e.carrier = true
					e.wave_id = _wave_counter
					_wave_alive[_wave_counter] = _wave_alive.get(_wave_counter, 0) + 1
				_add_enemy(e)
		&"darts":
			for i in (p["ys"] as Array).size():
				_add_enemy(RetroEnemy.create(RetroEnemy.Kind.DART, Vector2(right + i * 14.0, p["ys"][i]), i))
		&"pod":
			_add_enemy(RetroEnemy.create(RetroEnemy.Kind.POD, Vector2(right, p["y"]), p["y"]))
		&"heavy":
			_add_enemy(RetroEnemy.create(RetroEnemy.Kind.HEAVY, Vector2(right + 12.0, p["y"]), p["y"]))
		&"rocks":
			for i in int(p["count"]):
				var y := 40.0 + fmod((time * 37.0 + i * 53.0), 160.0)
				_add_enemy(RetroEnemy.create(RetroEnemy.Kind.ROCK_BIG, Vector2(right + i * 30.0, y), time + i))
		&"banner":
			_show_banner(p["text"], "", 2.2)
		&"terrain":
			_start_terrain()
		&"warning":
			_warning_left = 2.6
			_show_banner("WARNING!!", "CORE BREAKER APPROACHING", 2.6)
			AudioService.stop_music(1.0)
		&"boss":
			boss = RetroBoss.new()
			_playfield.add_child(boss)
			AudioService.play_music(&"boss8", 0.2)


func _add_enemy(e: RetroEnemy) -> void:
	enemies.append(e)
	_playfield.add_child(e)


func _spawn_shot(list: Array[Sprite2D], sheet: StringName, at: Vector2, velocity: Vector2) -> void:
	var s := RetroArt.sprite(sheet)
	s.position = at
	s.set_meta(&"v", velocity)
	_playfield.add_child(s)
	list.append(s)


func _explode(at: Vector2, big: bool = false) -> void:
	var fx := RetroArt.sprite(&"explosion_big" if big else &"explosion")
	fx.position = at
	fx.set_meta(&"t", 0.0)
	_playfield.add_child(fx)
	_effects.append(fx)
	AudioService.play(&"retro_boom")


func _drop(sheet: StringName, at: Vector2) -> void:
	var p := RetroArt.sprite(sheet)
	p.position = at
	p.set_meta(&"kind", sheet)
	p.set_meta(&"t", 0.0)
	_playfield.add_child(p)
	_pickups.append(p)


# --- Updates ------------------------------------------------------------------------------------------

func _update_enemies(delta: float) -> void:
	var target := player.position if player.alive else Vector2(40, 120)
	for e in enemies.duplicate():
		for s: Array in e.tick(delta, target, SCROLL):
			_spawn_shot(_enemy_shots, &"shot_enemy", s[0], s[1])
		if e.offscreen():
			_remove_enemy(e, false)


func _update_boss(delta: float) -> void:
	if boss == null:
		return
	var out: Array = boss.tick(delta, player.position if player.alive else Vector2(40, 120))
	for s: Array in out[0]:
		_spawn_shot(_enemy_shots, &"shot_enemy", s[0], s[1])
	for d: Vector2 in out[1]:
		_add_enemy(RetroEnemy.create(RetroEnemy.Kind.DART, d, time))
	if boss.state == RetroBoss.State.DYING:
		_boss_explode_left -= delta
		if _boss_explode_left <= 0.0:
			_boss_explode_left = 0.12
			_explode(boss.position + Vector2(randf_range(-34, 34), randf_range(-30, 30)), randf() < 0.4)


func _move_shots(list: Array[Sprite2D], delta: float) -> void:
	for s in list.duplicate():
		s.position += s.get_meta(&"v") * delta
		if s.hframes > 1:
			s.frame = int(time * 12.0) % 2
		if s.position.x < -8 or s.position.x > RetroArt.SCREEN.x + 8 or s.position.y < RetroArt.HUD_H - 4 or s.position.y > RetroArt.SCREEN.y + 8:
			list.erase(s)
			s.queue_free()


func _update_pickups(delta: float) -> void:
	for p in _pickups.duplicate():
		var t: float = p.get_meta(&"t") + delta
		p.set_meta(&"t", t)
		p.position.x -= 22.0 * delta
		p.frame = int(t * 6.0) % 2
		if p.position.x < -10.0:
			_pickups.erase(p)
			p.queue_free()


func _update_effects(delta: float) -> void:
	for fx in _effects.duplicate():
		var t: float = fx.get_meta(&"t") + delta
		fx.set_meta(&"t", t)
		fx.position.x -= SCROLL * 0.5 * delta
		var f := int(t / 0.07)
		if f >= 4:
			_effects.erase(fx)
			fx.queue_free()
		else:
			fx.frame = f


# --- Collisions ---------------------------------------------------------------------------------------

func _collide() -> void:
	for s in _player_shots.duplicate():
		var r := Rect2(s.position - Vector2(3, 2), Vector2(6, 4))
		var spent := false
		for e in enemies.duplicate():
			if e.world_hit_rect().intersects(r):
				spent = true
				AudioService.play(&"retro_hit")
				if e.damage(1):
					_kill_enemy(e)
				break
		if not spent and boss and boss.state != RetroBoss.State.ENTER and boss.state != RetroBoss.State.DYING:
			if boss.world_rect(boss.core_rect).intersects(r):
				spent = true
				if boss.core_open():
					AudioService.play(&"retro_hit")
					RunSession.add_score(10)
					if boss.damage(1):
						_on_boss_destroyed()
			else:
				for armour in boss.armour_rects:
					if boss.world_rect(armour).intersects(r):
						spent = true
		if not spent:
			for t in _terrain_rects_near(r.position.x, r.end.x):
				if t.intersects(r):
					spent = true
					break
		if spent:
			_player_shots.erase(s)
			s.queue_free()
	if not player.vulnerable():
		_collect_pickups()
		return
	var body := player.world_hit_rect()
	for s in _enemy_shots.duplicate():
		if Rect2(s.position - Vector2(2, 2), Vector2(4, 4)).intersects(body):
			_enemy_shots.erase(s)
			s.queue_free()
			_hurt_player()
			return
	for e in enemies:
		if e.world_hit_rect().intersects(body):
			_hurt_player()
			return
	if boss and boss.state != RetroBoss.State.DYING and boss.world_rect(boss.hull_rect).grow(-6).intersects(body):
		_hurt_player()
		return
	for t in _terrain_rects_near(body.position.x, body.end.x):
		if t.intersects(body):
			_hurt_player()
			return
	_collect_pickups()


func _collect_pickups() -> void:
	if not player.alive:
		return
	var body := player.world_hit_rect().grow(4)
	for p in _pickups.duplicate():
		if Rect2(p.position - Vector2(5, 5), Vector2(10, 10)).intersects(body):
			_pickups.erase(p)
			var kind: StringName = p.get_meta(&"kind")
			p.queue_free()
			if kind == &"capsule":
				if player.weapon < 4:
					player.weapon += 1
					_show_banner("", "POWER UP!", 1.0)
				else:
					RunSession.add_score(1000)
					_show_banner("", "1000 PTS", 1.0)
				AudioService.play(&"retro_power")
			else:
				RunSession.set_health(RunSession.health + 1)
				AudioService.play(&"retro_1up")


func _kill_enemy(e: RetroEnemy) -> void:
	RunSession.add_score(e.score)
	RunSession.add_charge(e.score)
	_explode(e.position, e.kind == RetroEnemy.Kind.HEAVY or e.kind == RetroEnemy.Kind.ROCK_BIG)
	if e.kind == RetroEnemy.Kind.ROCK_BIG:
		for dy: float in [-6.0, 6.0]:
			var rock := RetroEnemy.create(RetroEnemy.Kind.ROCK_SMALL, e.position + Vector2(0, dy), time + dy)
			rock.velocity = Vector2(-55, dy * 6.0)
			_add_enemy(rock)
	if e.kind == RetroEnemy.Kind.HEAVY:
		_drop(&"heart", e.position)
	elif e.kind == RetroEnemy.Kind.POD:
		_drop(&"capsule", e.position)
	_remove_enemy(e, true)


func _remove_enemy(e: RetroEnemy, killed: bool) -> void:
	enemies.erase(e)
	if e.wave_id >= 0:
		_wave_alive[e.wave_id] = _wave_alive.get(e.wave_id, 1) - 1
		# The last carrier of a wave drops the capsule when it is shot down.
		if killed and _wave_alive[e.wave_id] == 0:
			_drop(&"capsule", e.position)
	e.queue_free()


func _hurt_player() -> void:
	RunSession.set_health(RunSession.health - 1)
	AudioService.play(&"retro_boom")
	if RunSession.health <= 0:
		player.alive = false
		player.visible = false
		_explode(player.position, true)
		_respawn_left = 1.6
	else:
		player.invulnerable_left = 1.6
		_flash.color.a = 0.35


func _update_respawn(delta: float) -> void:
	if _respawn_left < 0.0:
		return
	_respawn_left -= delta
	if _respawn_left <= 0.0:
		_respawn_left = -1.0
		RunSession.set_health(RunSession.max_health)
		player.weapon = maxi(1, player.weapon - 1)
		player.position = Vector2(40, 120)
		player.alive = true
		player.invulnerable_left = 2.2


## SUPER as an 8-bit smart bomb: white flash, bullets erased, everything on screen hit hard.
func _bomb() -> void:
	RunSession.spend_energy(RunSession.MAX_ENERGY)
	_flash.color.a = 1.0
	AudioService.play(&"retro_boom")
	for s in _enemy_shots:
		s.queue_free()
	_enemy_shots.clear()
	for e in enemies.duplicate():
		if e.position.x < RetroArt.SCREEN.x and e.damage(8):
			_kill_enemy(e)
	if boss and boss.state != RetroBoss.State.ENTER:
		var was_open := boss.core_open()
		if not was_open:
			boss.state = RetroBoss.State.OPEN
		if boss.damage(8 if was_open else 5):
			_on_boss_destroyed()
		elif not was_open:
			boss.state = RetroBoss.State.CLOSED


func _on_boss_destroyed() -> void:
	RunSession.add_score(30000)
	for s in _enemy_shots:
		s.queue_free()
	_enemy_shots.clear()
	for e in enemies.duplicate():
		_kill_enemy(e)
	player.invulnerable_left = 99.0
	AudioService.stop_music(0.3)
	_outro_left = 2.4


func _update_outro(delta: float) -> void:
	if _outro_left < 0.0 or finished:
		return
	_outro_left -= delta
	if _outro_left <= 0.0:
		if boss:
			_explode(boss.position, true)
			boss.queue_free()
			boss = null
			_flash.color.a = 1.0
			AudioService.play_jingle(&"clear8")
			_show_banner("STAGE CLEAR", "SCORE %06d" % mini(RunSession.score, 999999), 5.0)
			_outro_left = 4.5
		else:
			finished = true
			cleared.emit()
			if not next_level.is_empty():
				SceneRouter.go_to(next_level)
