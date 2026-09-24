class_name TrackObstacle
extends Node3D
## Runner obstacles, all on the damage contract (ENEMY-team contact hitboxes hit the bike only).
## BARRIER: low wall — jump it.            BEAM: laser bar at head height — duck under it.
## MINE: blinking ground mine — jump it.   CRATE: breakable — shoot it or boost through it.
## GATE: full-height laser cycling off → warn → live — time it (or boost through).
## PAD: launches the bike high.            ORB: energy orb — score + SUPER charge.

enum Kind { BARRIER, BEAM, MINE, CRATE, GATE, PAD, ORB }

@export var kind: Kind = Kind.BARRIER
## GATE timing.
@export var offset: float = 0.0
@export var off_time: float = 1.2
@export var warn_time: float = 0.45
@export var live_time: float = 0.9

const ORB_SCORE := 50
const ORB_CHARGE := 150
const CRATE_SCORE := 150

var live: bool = true

var _hitbox: HitboxComponent
var _trigger: Area3D
var _glow: MeshInstance3D
var _lamp: StandardMaterial3D
var _visual: Node3D
var _time: float = 0.0
var _used: bool = false


func _ready() -> void:
	_time = offset
	_visual = ModelKit.group(self, "Visual")
	var danger := ModelKit.hull(Color("c43a3a"), ArtStyle.OUTLINE_THIN, 0.4)
	var metal := ModelKit.hull(Color("3d4a66"), ArtStyle.OUTLINE_THIN, 0.35)
	match kind:
		Kind.BARRIER:
			_hitbox = _make_hitbox(Vector3(0.6, 1.1, 1.6), Vector3(0, 0.55, 0))
			ModelKit.box(_visual, Vector3(0.7, 1.3, 2.6), Vector3(0, 0.65, 0), metal)
			LevelKit.stripes(_visual, -0.35, 1.0, 0.7)
			_lamp = ModelKit.emissive(Palette.DANGER, 2.0)
			ModelKit.box(_visual, Vector3(0.74, 0.14, 2.64), Vector3(0, 1.36, 0), _lamp)
		Kind.BEAM:
			# Bar from y 1.2 up; emitter housings above and on the road edge.
			_hitbox = _make_hitbox(Vector3(0.5, 5.8, 1.6), Vector3(0, 4.1, 0))
			ModelKit.box(_visual, Vector3(0.9, 5.0, 2.8), Vector3(0, 4.7, -0.1), metal)
			LevelKit.stripes(_visual, -0.45, 2.1, 0.9)
			ModelKit.box(_visual, Vector3(0.3, 0.3, 2.8), Vector3(0, 1.35, 0), ModelKit.emissive(Palette.DANGER, 2.5))
			_glow = ModelKit.quad(_visual, Vector2(1.4, 0.8), Vector3(0, 1.3, 1.5), ModelKit.glow(Palette.DANGER, 1.2, ModelKit.GlowShape.STREAK))
		Kind.MINE:
			_hitbox = _make_hitbox(Vector3(0.9, 0.6, 1.6), Vector3(0, 0.3, 0))
			_hitbox.single_hit = true
			_hitbox.hit_landed.connect(func(_h: HurtboxComponent) -> void: _explode())
			ModelKit.cylinder(_visual, 0.45, 0.55, 0.3, Vector3(0, 0.15, 0), metal, Vector3.ZERO, 8)
			_lamp = ModelKit.emissive(Palette.DANGER, 2.0)
			ModelKit.sphere(_visual, 0.16, Vector3(0, 0.35, 0), _lamp)
			_glow = ModelKit.quad(_visual, Vector2.ONE * 1.4, Vector3(0, 0.35, 0.6), ModelKit.glow(Palette.DANGER, 0.8))
		Kind.CRATE:
			_hitbox = _make_hitbox(Vector3(1.5, 1.5, 1.6), Vector3(0, 0.75, 0))
			var health := HealthComponent.new()
			health.max_health = 3
			add_child(health)
			var hurtbox := HurtboxComponent.new()
			hurtbox.team = Teams.Team.ENEMY
			hurtbox.health = health
			hurtbox.position = Vector3(0, 0.75, 0)
			hurtbox.add_child(_box_shape(Vector3(1.6, 1.6, 1.6)))
			add_child(hurtbox)
			health.damaged.connect(func(_p: DamagePayload, _s: Node) -> void: _visual.scale = Vector3.ONE * 0.9)
			health.depleted.connect(func(_s: Node) -> void: _break())
			var wood := ModelKit.hull(Palette.INTERACTABLE.darkened(0.25), ArtStyle.OUTLINE_THIN, 0.4)
			ModelKit.box(_visual, Vector3(1.5, 1.5, 1.5), Vector3(0, 0.75, 0), wood)
			ModelKit.box(_visual, Vector3(1.56, 0.2, 1.56), Vector3(0, 1.2, 0), metal)
			ModelKit.box(_visual, Vector3(1.56, 0.2, 1.56), Vector3(0, 0.3, 0), metal)
			ModelKit.box(_visual, Vector3(0.9, 0.12, 0.05), Vector3(0, 0.75, 0.78), metal, Vector3(0, 0, 45))
			ModelKit.box(_visual, Vector3(0.9, 0.12, 0.05), Vector3(0, 0.75, 0.78), metal, Vector3(0, 0, -45))
		Kind.GATE:
			_hitbox = _make_hitbox(Vector3(0.5, 8.0, 1.6), Vector3(0, 4.0, 0))
			for y: float in [0.0, 8.4]:
				ModelKit.box(_visual, Vector3(1.0, 0.8, 2.8), Vector3(0, y, 0), metal)
			_lamp = ModelKit.emissive(Palette.DANGER, 0.3)
			ModelKit.sphere(_visual, 0.2, Vector3(0, 0.6, 1.2), _lamp)
			_glow = ModelKit.quad(_visual, Vector2(1.0, 8.0), Vector3(0, 4.2, 0.2), ModelKit.glow(Palette.DANGER, 0.0, ModelKit.GlowShape.STREAK), Vector3(0, 0, 90))
			_set_live(false)
		Kind.PAD:
			_trigger = _make_trigger(Vector3(2.0, 1.0, 2.0), Vector3(0, 0.5, 0))
			ModelKit.box(_visual, Vector3(2.2, 0.25, 2.4), Vector3(0, 0.12, 0), metal)
			_lamp = ModelKit.emissive(Palette.INTERACTABLE, 2.2)
			for i in 3:
				ModelKit.prism(_visual, Vector3(0.5, 0.3, 1.8), Vector3(-0.6 + i * 0.6, 0.3, 0), _lamp)
			_glow = ModelKit.quad(_visual, Vector2(2.6, 2.0), Vector3(0, 1.0, 1.3), ModelKit.glow(Palette.INTERACTABLE, 0.7))
		Kind.ORB:
			_trigger = _make_trigger(Vector3(1.2, 1.2, 2.0), Vector3.ZERO)
			ModelKit.sphere(_visual, 0.3, Vector3.ZERO, ModelKit.emissive(Palette.RESONANCE_VIOLET.lerp(Color.WHITE, 0.3), 2.5))
			_glow = ModelKit.quad(_visual, Vector2.ONE * 1.5, Vector3(0, 0, -0.2), ModelKit.glow(Palette.RESONANCE_VIOLET, 1.0))


func _physics_process(delta: float) -> void:
	_time += delta
	match kind:
		Kind.MINE:
			var on := fmod(_time, 0.6) < 0.2
			_lamp.emission_energy_multiplier = 3.0 if on else 0.4
		Kind.GATE:
			var cycle := off_time + warn_time + live_time
			var t := fmod(_time, cycle)
			var warn := t >= off_time and t < off_time + warn_time
			_set_live(t >= off_time + warn_time)
			_lamp.emission_energy_multiplier = 3.0 if live else (2.0 if warn and fmod(t, 0.12) < 0.06 else 0.3)
			(_glow.material_override as ShaderMaterial).set_shader_parameter(&"energy", 1.6 if live else (0.25 if warn else 0.0))
		Kind.ORB:
			_visual.position.y = sin(_time * 4.0 + position.x) * 0.15
			_visual.rotation.y += delta * 2.0
		Kind.CRATE:
			_visual.scale = _visual.scale.lerp(Vector3.ONE, clampf(delta * 12.0, 0.0, 1.0))


func _set_live(value: bool) -> void:
	live = value
	_hitbox.set_deferred(&"monitoring", value)


func _make_hitbox(size: Vector3, at: Vector3) -> HitboxComponent:
	var hitbox := HitboxComponent.new()
	hitbox.payload = DamagePayload.create(1, Teams.Team.ENEMY)
	hitbox.single_hit = false
	hitbox.continuous = true
	hitbox.source = self
	hitbox.position = at
	hitbox.add_child(_box_shape(size))
	add_child(hitbox)
	return hitbox


func _make_trigger(size: Vector3, at: Vector3) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = PhysicsLayers.HURTBOX
	area.monitorable = false
	area.position = at
	area.add_child(_box_shape(size))
	area.area_entered.connect(_on_trigger)
	add_child(area)
	return area


func _box_shape(size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	return shape


func _on_trigger(area: Area3D) -> void:
	var player := area.get_parent()
	if player == null or not player.is_in_group(Players.GROUP):
		return
	match kind:
		Kind.PAD:
			if player.has_method(&"launch"):
				player.call(&"launch", float(player.get(&"tuning").pad_velocity))
				_visual.scale = Vector3(1.2, 0.6, 1.2)
				create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.3)
		Kind.ORB:
			if _used:
				return
			_used = true
			RunSession.add_score(ORB_SCORE)
			RunSession.add_charge(ORB_CHARGE)
			Vfx.spawn(get_tree(), preload("res://vfx/collect_burst.tscn"), global_position, 0.7, {&"color": Palette.RESONANCE_VIOLET})
			queue_free()


func _explode() -> void:
	Vfx.spawn(get_tree(), preload("res://vfx/explosion.tscn"), global_position + Vector3(0, 0.4, 0.5), 1.0)
	queue_free()


func _break() -> void:
	RunSession.add_score(CRATE_SCORE)
	RunSession.add_charge(CRATE_SCORE)
	Vfx.spawn(get_tree(), preload("res://vfx/explosion.tscn"), global_position + Vector3(0, 0.8, 0.5), 1.1)
	var root := get_tree().get_first_node_in_group(Vfx.ROOT_GROUP)
	if root:
		var pieces: Array[Node3D] = []
		for i in 4:
			var piece := Node3D.new()
			ModelKit.box(piece, Vector3(0.6, 0.6, 0.6), Vector3.ZERO, ModelKit.hull(Palette.INTERACTABLE.darkened(0.25), ArtStyle.OUTLINE_THIN))
			piece.position = global_position + Vector3(randf_range(-0.5, 0.5), randf_range(0.3, 1.2), 0)
			pieces.append(piece)
		root.add_child(FragmentBurst.create(pieces, global_position + Vector3(0, 0.8, 0), 6.0))
	queue_free()
