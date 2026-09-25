class_name Explosion
extends Node3D
## One-shot explosion: core flash, a procedural fireball cooling into rolling smoke, sparks,
## tumbling debris, a shockwave and a light flash on nearby hulls.
## Built in code so `size` scales every layer; frees itself when done.

@export var size: float = 1.0
@export var fire_color: Color = Color(1.0, 0.55, 0.15)
@export var spark_color: Color = Color(1.0, 0.85, 0.5)
@export var debris_color: Color = Color("3b1726")
## Camera trauma on spawn; negative = derive from size (see docs/art-direction.md).
@export var trauma: float = -1.0
@export var lifetime: float = 2.6


func _ready() -> void:
	AudioService.play_explosion(size)
	_flash()
	_fireball()
	Fireball.light_flash(self, size)
	_sparks()
	_debris()
	_shockwave()
	var camera := GameplayCamera.find(get_tree())
	var impulse := trauma if trauma >= 0.0 else _trauma_for_size(size)
	if camera and impulse > 0.0:
		camera.add_trauma(impulse)
	get_tree().create_timer(lifetime, false).timeout.connect(queue_free)


static func _trauma_for_size(s: float) -> float:
	if s <= 1.3:
		return ArtStyle.SHAKE_ENEMY_DEATH
	if s <= 2.3:
		return ArtStyle.SHAKE_ELITE_DEATH
	if s < 3.5:
		return ArtStyle.SHAKE_MAJOR
	return ArtStyle.SHAKE_BOSS_DEATH


func _flash() -> void:
	var flash := ModelKit.quad(self, Vector2.ONE * 4.0 * size, Vector3(0, 0, 0.5),
			ModelKit.glow(Color(1.0, 0.9, 0.7), 3.5 * ArtStyle.flash_scale()))
	flash.scale = Vector3.ONE * 0.5
	var tween := create_tween().set_parallel()
	tween.tween_property(flash, "scale", Vector3.ONE * 1.4, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash.material_override, "shader_parameter/energy", 0.0, 0.3)


func _fireball() -> void:
	Fireball.emitter(self, Fireball.fire_material(), 12, 0.95, 4.5 * size, Vector2(1.1, 2.0) * size, 0.6, 0.25 * size)
	Fireball.emitter(self, Fireball.smoke_material(), 8, 2.0, 2.2 * size, Vector2(1.6, 2.8) * size, 1.4, 0.4 * size)


func _sparks() -> void:
	var p := _emitter(26, 0.45, ModelKit.glow(Color.WHITE, 2.0, ModelKit.GlowShape.STREAK))
	(p.mesh as QuadMesh).size = Vector2(0.08, 0.7) * size
	p.particle_flag_align_y = true
	p.initial_velocity_min = 7.0 * size
	p.initial_velocity_max = 16.0 * size
	p.damping_min = 8.0
	p.damping_max = 12.0
	p.color_ramp = _gradient([spark_color, Color(spark_color, 0.0)])


func _debris() -> void:
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, 0.16, 0.18) * size
	mesh.material = ModelKit.toon(debris_color, 0.6)
	p.mesh = mesh
	p.amount = 7
	p.lifetime = 1.3
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector3(0, -5, 0)
	p.initial_velocity_min = 3.0 * size
	p.initial_velocity_max = 7.0 * size
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	add_child(p)
	p.emitting = true


func _shockwave() -> void:
	var material := ModelKit.glow(fire_color, 1.6, ModelKit.GlowShape.RING)
	var ring := ModelKit.quad(self, Vector2.ONE * 2.0 * size, Vector3(0, 0, 0.3), material)
	ring.scale = Vector3.ONE * 0.3
	var tween := create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE * 2.4, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(material, "shader_parameter/energy", 0.0, 0.4)


func _emitter(amount: int, particle_lifetime: float, material: Material) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var mesh := QuadMesh.new()
	mesh.material = material
	p.mesh = mesh
	p.amount = Settings.particle_amount(amount)
	p.lifetime = particle_lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.lifetime_randomness = 0.4
	add_child(p)
	p.emitting = true
	return p


static func _curve(points: Array[Vector2]) -> Curve:
	var curve := Curve.new()
	for point in points:
		curve.add_point(point)
	return curve


static func _gradient(colors: Array[Color]) -> Gradient:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / float(colors.size() - 1))
	gradient.offsets = offsets
	gradient.colors = PackedColorArray(colors)
	return gradient
