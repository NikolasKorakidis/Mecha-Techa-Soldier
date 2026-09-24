class_name Hazard
extends Area3D
## Platformer hazards built on the damage contract (NEUTRAL hitbox).
## ELECTRIC: floor panel cycling off → warning flicker → live. SPIKES: always live.
## CRUSHER: ceiling piston with a floor shadow + lamp telegraph, slams and retracts.

enum Kind { ELECTRIC, SPIKES, CRUSHER }

@export var kind: Kind = Kind.ELECTRIC
@export var width: float = 4.0
@export var offset: float = 0.0
@export var off_time: float = 1.6
@export var warn_time: float = 0.7
@export var live_time: float = 1.1
## Crusher drop distance (from its resting height to the floor).
@export var drop: float = 5.0

var live: bool = false

var _hitbox: HitboxComponent
var _time: float = 0.0
var _glow: MeshInstance3D
var _piston: Node3D
var _shadow: MeshInstance3D
var _lamp: StandardMaterial3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	_time = offset
	_hitbox = HitboxComponent.new()
	_hitbox.payload = DamagePayload.create(1, Teams.Team.NEUTRAL)
	_hitbox.payload.knockback = Vector3(0, 6, 0)
	_hitbox.single_hit = false
	_hitbox.continuous = true
	_hitbox.source = self
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	match kind:
		Kind.ELECTRIC:
			box.size = Vector3(width, 0.5, 2.0)
			shape.position = Vector3(0, 0.25, 0)
			ModelKit.box(self, Vector3(width, 0.14, 2.4), Vector3(0, 0.02, 0), LevelKit.material(&"hull_dark"))
			for i in int(width / 0.8):
				ModelKit.box(self, Vector3(0.12, 0.1, 2.3), Vector3(-width * 0.5 + 0.4 + i * 0.8, 0.1, 0), LevelKit.material(&"trim"))
			_glow = ModelKit.quad(self, Vector2(width * 1.1, 1.3), Vector3(0, 0.45, 1.3), ModelKit.glow(Palette.RESONANCE_VIOLET.lerp(Color.WHITE, 0.3), 0.0))
		Kind.SPIKES:
			box.size = Vector3(width, 0.6, 2.0)
			shape.position = Vector3(0, 0.3, 0)
			var mat := ModelKit.hull(Color("c7cfdc"), ArtStyle.OUTLINE_THIN, 0.4)
			for i in int(width / 0.6):
				ModelKit.prism(self, Vector3(0.5, 0.7, 1.6), Vector3(-width * 0.5 + 0.3 + i * 0.6, 0.35, 0), mat)
			live = true
		Kind.CRUSHER:
			box.size = Vector3(width - 0.2, 1.2, 2.0)
			_piston = ModelKit.group(self, "Piston")
			ModelKit.box(_piston, Vector3(width, 1.2, 2.4), Vector3.ZERO, ModelKit.hull(Color("3d4a66")))
			LevelKit.stripes(_piston, -width * 0.5, -0.45, width)
			ModelKit.box(_piston, Vector3(0.6, 8.0, 0.8), Vector3(0, 4.6, 0), LevelKit.material(&"hull_dark"))
			_lamp = ModelKit.emissive(Palette.DANGER, 0.2)
			ModelKit.sphere(_piston, 0.22, Vector3(0, 0.75, 1.1), _lamp)
			_shadow = ModelKit.quad(self, Vector2(width * 1.1, 0.7), Vector3(0, -drop - 0.4, 1.3), ModelKit.glow(Palette.DANGER, 0.0))
			_piston.add_child(_hitbox)
	shape.shape = box
	_hitbox.add_child(shape)
	if kind != Kind.CRUSHER:
		add_child(_hitbox)
	_set_live(live)


func _physics_process(delta: float) -> void:
	if kind == Kind.SPIKES:
		return
	_time += delta
	var cycle := off_time + warn_time + live_time
	var t := fmod(_time, cycle)
	match kind:
		Kind.ELECTRIC:
			var warning := t >= off_time and t < off_time + warn_time
			_set_live(t >= off_time + warn_time)
			var energy := 0.0
			if warning:
				energy = 0.9 if fmod(t * 14.0, 1.0) < 0.5 else 0.2
			elif live:
				energy = 2.2 + 0.4 * sin(_time * 60.0)
			(_glow.material_override as ShaderMaterial).set_shader_parameter(&"energy", energy * lerpf(0.5, 1.0, ArtStyle.flash_scale()))
		Kind.CRUSHER:
			# off = raised, warn = lamp + growing floor shadow, live = slam, hold, then retract.
			var y := 0.0
			var shadow := 0.0
			if t < off_time:
				y = 0.0
			elif t < off_time + warn_time:
				shadow = (t - off_time) / warn_time
				_lamp.emission_energy_multiplier = 3.0 if fmod(t * 10.0, 1.0) < 0.5 else 0.3
			else:
				var k := (t - off_time - warn_time) / live_time
				y = -drop * (minf(1.0, k * 6.0) if k < 0.7 else 1.0 - (k - 0.7) / 0.3)
				shadow = 1.0
			if t < off_time:
				_lamp.emission_energy_multiplier = 0.2
			_piston.position.y = y
			_set_live(y < -drop * 0.5)
			(_shadow.material_override as ShaderMaterial).set_shader_parameter(&"energy", shadow * 1.4)


func _set_live(value: bool) -> void:
	if value == live and _hitbox.monitoring == value:
		return
	live = value
	_hitbox.set_deferred(&"monitoring", value)
