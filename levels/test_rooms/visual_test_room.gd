extends TestRoom
## Visual validation room (debug builds only). Shows every visual variant and exposes debug
## controls for effects, layers and accessibility modes.
## Debug-only exception to the "input actions only" rule: raw keys, chosen to avoid gameplay bindings.

const ENEMIES: Array[String] = ["needle", "space_drone", "lancer", "gunpod", "rammer", "gunship", "tesla", "warden"]
const HELP := """VISUAL TEST ROOM  (debug)
1-8  spawn enemy   0  clear   9  toggle lineup
Z  damage player   X  refill health   C  refill energy   V  cycle echo
B  explosion   N  impact sparks   M  lightning lane   P  projectile samples   Y  big explosion
U  pickups
G  glow   R  reduced flash   T  reduced shake   H  debug labels
F1..F5  toggle background layer 1-5   Esc  pause"""

@export var enemy_root: Node3D

var _lineup: Node3D
var _overlay: Label
var _stats: Label


func _ready() -> void:
	Settings.show_debug_labels = true
	super._ready()
	_build_overlay()
	_build_lineup()


func _process(_delta: float) -> void:
	var particles := 0
	for node in get_tree().root.find_children("*", "CPUParticles3D", true, false):
		if (node as CPUParticles3D).emitting:
			particles += 1
	_stats.text = "FPS %d   emitters %d   nodes %d\nglow %s   reduced flash %s   reduced shake %s   labels %s" % [
		Engine.get_frames_per_second(), particles, get_tree().get_node_count(),
		_on_off(Settings.glow_enabled), _on_off(Settings.reduced_flash),
		_on_off(Settings.reduced_shake), _on_off(Settings.show_debug_labels)]


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code := key.physical_keycode
	if code >= KEY_1 and code <= KEY_8:
		_spawn_enemy(ENEMIES[code - KEY_1])
	elif code >= KEY_F1 and code <= KEY_F5:
		_toggle_layer(code - KEY_F1)
	else:
		match code:
			KEY_0:
				for e in enemy_root.get_children():
					e.queue_free()
			KEY_9:
				_lineup.visible = not _lineup.visible
			KEY_Z:
				player.hurtbox.receive_hit(DamagePayload.create(1, Teams.Team.ENEMY), self)
			KEY_X:
				if player.health.is_depleted():
					player.respawn(spawn.global_position)
				player.health.heal(player.health.max_health)
			KEY_C:
				RunSession.add_energy(RunSession.MAX_ENERGY)
			KEY_V:
				_cycle_echo()
			KEY_B:
				Vfx.spawn(get_tree(), load("res://vfx/explosion.tscn"), Vector3(2, 0, 0), 1.0)
			KEY_Y:
				Vfx.spawn(get_tree(), load("res://vfx/explosion.tscn"), Vector3(2, 0, 0), 2.6)
			KEY_N:
				for i in 3:
					Vfx.spawn(get_tree(), load("res://vfx/impact_spark.tscn"), Vector3(0, -3 + i * 3, 0))
			KEY_M:
				Projectile.find_root(get_tree()).add_child(BeamHazard.create(-4.0, 1.0, 0.5, Palette.RESONANCE_VIOLET, 1.2))
			KEY_P:
				_spawn_projectile_samples()
			KEY_U:
				_spawn_pickups()
			KEY_G:
				Settings.set_option(&"glow_enabled", not Settings.glow_enabled)
			KEY_R:
				Settings.set_option(&"reduced_flash", not Settings.reduced_flash)
			KEY_T:
				Settings.set_option(&"reduced_shake", not Settings.reduced_shake)
			KEY_H:
				Settings.set_option(&"show_debug_labels", not Settings.show_debug_labels)
			_:
				return
	get_viewport().set_input_as_handled()


func _spawn_enemy(scene_name: String) -> void:
	var enemy := (load("res://enemies/space/%s.tscn" % scene_name) as PackedScene).instantiate() as SpaceEnemy
	enemy.position = Vector3(19, randf_range(-6, 6), 0)
	enemy_root.add_child(enemy)


func _cycle_echo() -> void:
	var order: Array[StringName] = [RunSession.NO_ECHO]
	order.append_array(EchoModules.ALL)
	var next: StringName = order[(order.find(RunSession.selected_echo) + 1) % order.size()]
	var data := EchoModules.get_data(next)
	RunSession.equip_echo(next, data.ammo if data else 0)


func _toggle_layer(index: int) -> void:
	var backdrop := get_node_or_null(^"SpaceBackdrop")
	if backdrop and backdrop.has_method(&"toggle_layer"):
		backdrop.toggle_layer(index)


func _spawn_projectile_samples() -> void:
	var root := Projectile.find_root(get_tree())
	var samples := {
		"res://combat/projectiles/player_shot.tscn": Teams.Team.PLAYER,
		"res://combat/projectiles/burst_shot.tscn": Teams.Team.PLAYER,
		"res://combat/projectiles/orb_shot.tscn": Teams.Team.PLAYER,
		"res://combat/projectiles/enemy_shot.tscn": Teams.Team.ENEMY,
	}
	var y := 5.0
	for path: String in samples:
		var shot := (load(path) as PackedScene).instantiate() as Projectile
		shot.lifetime = 6.0
		root.add_child(shot)
		shot.global_position = Vector3(-2, y, 0)
		shot.setup(samples[path], 0, Vector3(1.2 if samples[path] == Teams.Team.PLAYER else -1.2, 0, 0))
		y -= 1.6


func _spawn_pickups() -> void:
	var root := get_tree().get_first_node_in_group(EchoPickup.ROOT_GROUP)
	var y := 4.0
	for id in EchoModules.ALL:
		var pickup := (load("res://combat/pickups/echo_pickup.tscn") as PackedScene).instantiate() as EchoPickup
		pickup.echo_id = id
		pickup.position = Vector3(14.5, y + 2.5, 0)
		root.add_child(pickup)
		y -= 4.0


## Frozen display of every enemy: regular row on top, echo carriers below.
func _build_lineup() -> void:
	_lineup = Node3D.new()
	_lineup.name = "Lineup"
	add_child(_lineup)
	for i in ENEMIES.size():
		var enemy := (load("res://enemies/space/%s.tscn" % ENEMIES[i]) as PackedScene).instantiate() as SpaceEnemy
		var elite := i >= 5
		enemy.position = Vector3(3.0 + (i - 5) * 5.0 if elite else -2.0 + i * 3.6, -4.5 if elite else 2.5, 0)
		enemy.fire_pattern = SpaceEnemy.FirePattern.NONE
		enemy.movement = SpaceEnemy.Movement.STRAIGHT
		enemy.speed = 0.0
		_lineup.add_child(enemy)
		# Frozen: no motion, no contact damage, no culling.
		enemy.set_physics_process(false)
		enemy.get_node(^"ContactHitbox").set_deferred(&"monitoring", false)
		enemy.get_node(^"OffscreenCleanup").set_physics_process(false)
		var label := Label3D.new()
		label.text = ENEMIES[i].to_upper().replace("SPACE_", "")
		label.position = Vector3(0, -1.9, 1)
		label.pixel_size = 0.006
		label.font_size = 40
		label.outline_size = 8
		enemy.add_child(label)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_overlay = Label.new()
	_overlay.text = HELP
	_overlay.position = Vector2(32, 700)
	_overlay.add_theme_font_size_override(&"font_size", 20)
	_overlay.add_theme_color_override(&"font_color", Palette.UI_MUTED_TEXT)
	_overlay.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_overlay.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_overlay)
	_stats = Label.new()
	_stats.position = Vector2(32, 620)
	_stats.add_theme_font_size_override(&"font_size", 20)
	_stats.add_theme_color_override(&"font_color", Palette.UI_GOLD)
	_stats.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_stats.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_stats)


static func _on_off(value: bool) -> String:
	return "ON" if value else "off"
