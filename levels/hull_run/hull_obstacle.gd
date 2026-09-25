class_name HullObstacle
extends Node3D
## Deck hazards for the 3D hull run (all ENEMY-team contact hitboxes; they hurt the bike only).
## BLOCK: machinery block across part of the deck — steer around it.
## WALL: low barrier across the whole deck — jump it.
## VENT: flame column cycling off → warn → fire — time it.
## FENCE: laser fence across the deck with one open gap — steer through (or boost).
## BLAST: marked zone that erupts when the bike gets close — get out of the ring.
## PAD: launches the bike.  ORB: score + SUPER charge.  REPAIR: +1 health.

enum Kind { BLOCK, WALL, VENT, FENCE, BLAST, PAD, ORB, REPAIR }

@export var kind: Kind = Kind.BLOCK
## BLOCK size (x length, y height, z width); FENCE gap centre (z) in size.z.
@export var size: Vector3 = Vector3(3, 3, 4)
@export var offset: float = 0.0
@export var deck_half_width: float = 9.0

const ORB_SCORE := 60
const ORB_CHARGE := 160

var live: bool = true

var _hitbox: HitboxComponent
var _trigger: Area3D
var _visual: Node3D
var _glow: MeshInstance3D
var _lamp: StandardMaterial3D
var _flame: CPUParticles3D
var _time: float = 0.0
var _armed: bool = false
var _used: bool = false


func _ready() -> void:
	_time = offset
	_visual = ModelKit.group(self, "Visual")
	var metal := ModelKit.hull(Color("3d4a66"), ArtStyle.OUTLINE_THIN, 0.4)
	var dark := ModelKit.hull(Color("1d2539"), ArtStyle.OUTLINE_THIN, 0.3)
	var hazard := ModelKit.toon(Palette.INTERACTABLE.darkened(0.15), 0.3, 0.6, 0.2)
	var red := ModelKit.emissive(Palette.DANGER, 2.4)
	match kind:
		Kind.BLOCK:
			_hitbox = _make_hitbox(size, Vector3(0, size.y * 0.5, 0))
			ModelKit.box(_visual, size, Vector3(0, size.y * 0.5, 0), metal)
			ModelKit.box(_visual, Vector3(size.x + 0.1, 0.3, size.z + 0.1), Vector3(0, size.y - 0.15, 0), dark)
			# Front face (toward the bike): vents, hazard band, warning lights.
			for k in 3:
				ModelKit.box(_visual, Vector3(0.05, 0.12, size.z * 0.7), Vector3(-size.x * 0.5 - 0.03, size.y * 0.5 + k * 0.3 - 0.3, 0), dark)
			ModelKit.box(_visual, Vector3(0.06, 0.35, size.z), Vector3(-size.x * 0.5 - 0.04, 0.35, 0), hazard)
			for side: float in [-1.0, 1.0]:
				ModelKit.sphere(_visual, 0.18, Vector3(-size.x * 0.5 - 0.1, size.y - 0.4, side * (size.z * 0.5 - 0.3)), red)
			_glow = _billboard(Palette.DANGER, 0.6, Vector3(-size.x * 0.5 - 0.3, size.y - 0.4, 0), 2.0)
		Kind.WALL:
			_hitbox = _make_hitbox(Vector3(0.8, 1.2, deck_half_width * 2.0), Vector3(0, 0.6, 0))
			ModelKit.box(_visual, Vector3(0.8, 1.2, deck_half_width * 2.0), Vector3(0, 0.6, 0), metal)
			var stripes := int(deck_half_width * 2.0 / 1.2)
			for k in stripes:
				ModelKit.box(_visual, Vector3(0.05, 0.9, 0.5), Vector3(-0.43, 0.6, -deck_half_width + 0.6 + k * 1.2), hazard, Vector3(35, 0, 0))
			_lamp = ModelKit.emissive(Palette.DANGER, 2.0)
			ModelKit.box(_visual, Vector3(0.84, 0.12, deck_half_width * 2.0), Vector3(0, 1.26, 0), _lamp)
		Kind.VENT:
			_hitbox = _make_hitbox(Vector3(2.4, 7.0, 2.4), Vector3(0, 3.5, 0))
			ModelKit.cylinder(_visual, 1.3, 1.5, 0.4, Vector3(0, 0.2, 0), dark, Vector3.ZERO, 10)
			ModelKit.cylinder(_visual, 1.0, 1.0, 0.42, Vector3(0, 0.22, 0), ModelKit.toon(Color("0a0a0f")), Vector3.ZERO, 10)
			_lamp = ModelKit.emissive(Color(1.0, 0.5, 0.2), 0.3)
			ModelKit.cylinder(_visual, 1.05, 1.05, 0.05, Vector3(0, 0.44, 0), _lamp, Vector3.ZERO, 10)
			_flame = _fire_column()
			_set_live(false)
		Kind.FENCE:
			var gap_z := size.z
			var gap_half := 2.6
			# Two emitter posts per solid section and a laser sheet.
			for section: Vector2 in [Vector2(-deck_half_width, gap_z - gap_half), Vector2(gap_z + gap_half, deck_half_width)]:
				var w := section.y - section.x
				if w <= 0.2:
					continue
				var cz := (section.x + section.y) * 0.5
				var hb := _make_hitbox(Vector3(0.5, 3.0, w), Vector3(0, 1.5, cz))
				if _hitbox == null:
					_hitbox = hb
				for pz: float in [section.x, section.y]:
					ModelKit.box(_visual, Vector3(0.5, 3.4, 0.5), Vector3(0, 1.7, pz), metal)
					ModelKit.sphere(_visual, 0.2, Vector3(0, 3.5, pz), red)
				for k in 4:
					ModelKit.box(_visual, Vector3(0.06, 0.08, w), Vector3(0, 0.5 + k * 0.7, cz), ModelKit.emissive(Palette.DANGER, 3.0))
				var sheet := ModelKit.quad(_visual, Vector2(w, 3.0), Vector3(0, 1.5, cz), ModelKit.glow(Palette.DANGER, 0.5), Vector3(0, 90, 0))
				sheet.name = "Sheet"
			# Gap marker lights.
			for side: float in [-1.0, 1.0]:
				ModelKit.sphere(_visual, 0.25, Vector3(0, 0.3, gap_z + side * gap_half), ModelKit.emissive(Color("52e07a"), 3.0))
		Kind.BLAST:
			_hitbox = _make_hitbox(Vector3(6.0, 4.0, 6.0), Vector3(0, 2.0, 0))
			_set_live(false)
			_glow = ModelKit.quad(_visual, Vector2.ONE * 6.5, Vector3(0, 0.08, 0), ModelKit.glow(Palette.DANGER, 0.0, ModelKit.GlowShape.RING), Vector3(-90, 0, 0))
			ModelKit.cylinder(_visual, 1.2, 1.4, 0.3, Vector3(0, 0.15, 0), dark, Vector3.ZERO, 8)
			_lamp = ModelKit.emissive(Palette.DANGER, 0.3)
			ModelKit.sphere(_visual, 0.35, Vector3(0, 0.4, 0), _lamp)
		Kind.PAD:
			_trigger = _make_trigger(Vector3(3.0, 1.2, 4.0), Vector3(0, 0.6, 0))
			ModelKit.box(_visual, Vector3(3.2, 0.25, 4.4), Vector3(0, 0.12, 0), metal)
			_lamp = ModelKit.emissive(Palette.INTERACTABLE, 2.4)
			for k in 3:
				ModelKit.prism(_visual, Vector3(0.6, 0.3, 3.6), Vector3(-0.8 + k * 0.8, 0.32, 0), _lamp, Vector3(0, 0, -90))
			_glow = _billboard(Palette.INTERACTABLE, 0.8, Vector3(0, 1.0, 0), 3.5)
		Kind.ORB:
			_trigger = _make_trigger(Vector3(2.2, 2.2, 2.4), Vector3.ZERO)
			ModelKit.sphere(_visual, 0.35, Vector3.ZERO, ModelKit.emissive(Palette.RESONANCE_VIOLET.lerp(Color.WHITE, 0.3), 2.8))
			_glow = _billboard(Palette.RESONANCE_VIOLET, 1.1, Vector3.ZERO, 2.0)
		Kind.REPAIR:
			_trigger = _make_trigger(Vector3(2.2, 2.2, 2.4), Vector3.ZERO)
			var green := ModelKit.emissive(Palette.HEALTH_GREEN, 2.6)
			ModelKit.box(_visual, Vector3(0.3, 0.9, 0.3), Vector3.ZERO, green)
			ModelKit.box(_visual, Vector3(0.3, 0.3, 0.9), Vector3.ZERO, green)
			_glow = _billboard(Palette.HEALTH_GREEN, 1.0, Vector3.ZERO, 2.2)


func _physics_process(delta: float) -> void:
	_time += delta
	match kind:
		Kind.VENT:
			var cycle := 3.0
			var t := fmod(_time, cycle)
			var warn := t >= 1.5 and t < 2.1
			_set_live(t >= 2.1)
			_lamp.emission_energy_multiplier = 3.5 if live else (2.5 if warn and fmod(t, 0.12) < 0.06 else 0.3)
			_flame.emitting = live
		Kind.BLAST:
			_update_blast(delta)
		Kind.ORB, Kind.REPAIR:
			_visual.position.y = sin(_time * 4.0 + position.x) * 0.2
			_visual.rotation.y += delta * 2.0
		Kind.WALL:
			_lamp.emission_energy_multiplier = 1.2 + 1.2 * absf(sin(_time * 5.0))


func _update_blast(_delta: float) -> void:
	var player := Players.find(get_tree())
	if not _armed:
		if player and global_position.x - player.global_position.x < 60.0 and global_position.x > player.global_position.x:
			_armed = true
			_time = 0.0
		return
	var energy := 0.0
	if _time < 1.1:
		energy = 0.6 + 1.2 * absf(sin(_time * 14.0))
		_lamp.emission_energy_multiplier = energy * 2.0
	elif not _used:
		_used = true
		_set_live(true)
		Explosion3D.spawn(get_tree(), global_position + Vector3(0, 1.2, 0), 2.4, 0.25)
		Explosion3D.spawn(get_tree(), global_position + Vector3(randf_range(-1.5, 1.5), 3.0, randf_range(-1.5, 1.5)), 1.4)
		get_tree().create_timer(0.3, false).timeout.connect(func() -> void: _set_live(false))
	(_glow.material_override as ShaderMaterial).set_shader_parameter(&"energy", energy if not _used else 0.0)


func _set_live(value: bool) -> void:
	live = value
	if _hitbox:
		_hitbox.set_deferred(&"monitoring", value)


func _make_hitbox(box: Vector3, at: Vector3) -> HitboxComponent:
	var hitbox := HitboxComponent.new()
	hitbox.payload = DamagePayload.create(1, Teams.Team.ENEMY)
	hitbox.single_hit = false
	hitbox.continuous = true
	hitbox.source = self
	hitbox.position = at
	hitbox.add_child(_box_shape(box))
	add_child(hitbox)
	return hitbox


func _make_trigger(box: Vector3, at: Vector3) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = PhysicsLayers.HURTBOX
	area.monitorable = false
	area.position = at
	area.add_child(_box_shape(box))
	area.area_entered.connect(_on_trigger)
	add_child(area)
	return area


func _box_shape(box: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = box
	shape.shape = b
	return shape


func _billboard(color: Color, energy: float, at: Vector3, scale_size: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = QuadMesh.new()
	m.material_override = ModelKit.glow_billboard(color, energy)
	m.position = at
	m.scale = Vector3.ONE * scale_size
	_visual.add_child(m)
	return m


func _fire_column() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.6
	p.direction = Vector3.UP
	p.spread = 8.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 14.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.9
	p.scale_amount_max = 1.8
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.5, 1))
	ramp.set_color(1, Color(1.0, 0.3, 0.1, 0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.material = Explosion3D._particle_material(Color(1, 0.6, 0.2), BaseMaterial3D.BLEND_MODE_ADD)
	p.mesh = quad
	p.position = Vector3(0, 0.4, 0)
	p.emitting = false
	add_child(p)
	return p


func _on_trigger(area: Area3D) -> void:
	var player := area.get_parent()
	if player == null or not player.is_in_group(Players.GROUP) or _used:
		return
	match kind:
		Kind.PAD:
			AudioService.play(&"boost")
			if player.has_method(&"launch"):
				player.call(&"launch", float(player.get(&"tuning").pad_velocity))
		Kind.ORB:
			_used = true
			AudioService.play(&"pickup")
			RunSession.add_score(ORB_SCORE)
			RunSession.add_charge(ORB_CHARGE)
			Explosion3D.spawn(get_tree(), global_position, 0.4)
			queue_free()
		Kind.REPAIR:
			_used = true
			var h := player.get(&"health") as HealthComponent
			if h:
				h.heal(1)
			AudioService.play(&"weapon_get")
			Explosion3D.spawn(get_tree(), global_position, 0.5)
			queue_free()
