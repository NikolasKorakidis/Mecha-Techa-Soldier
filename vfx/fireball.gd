class_name Fireball
extends RefCounted
## Emitters for the procedural fireball shader (fire that cools into smoke, and smoke puffs),
## plus the short light flash that lights up nearby hulls. Shared by Explosion and Explosion3D.

static var _fire: ShaderMaterial
static var _smoke: ShaderMaterial


static func fire_material() -> ShaderMaterial:
	if _fire == null:
		_fire = ShaderMaterial.new()
		_fire.shader = preload("res://art/shaders/fireball.gdshader")
		_fire.set_shader_parameter(&"heat", 1.0)
	return _fire


static func smoke_material() -> ShaderMaterial:
	if _smoke == null:
		_smoke = ShaderMaterial.new()
		_smoke.shader = preload("res://art/shaders/fireball.gdshader")
		_smoke.set_shader_parameter(&"heat", 0.12)
	return _smoke


## One-shot puff emitter. Colour ramps encode age (red) and a per-particle random (green).
static func emitter(parent: Node3D, material: Material, amount: int, life: float, speed: float,
		scale_range: Vector2, rise: float, spread_box: float = 0.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.material = material
	p.mesh = quad
	p.amount = Settings.particle_amount(amount)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.92
	p.lifetime_randomness = 0.35
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0, rise, 0)
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.6
	p.scale_amount_min = scale_range.x
	p.scale_amount_max = scale_range.y
	if spread_box > 0.0:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = spread_box
	var age_ramp := Gradient.new()
	age_ramp.set_color(0, Color(0.0, 1.0, 1.0, 1.0))
	age_ramp.set_color(1, Color(1.0, 1.0, 1.0, 1.0))
	p.color_ramp = age_ramp
	var random_ramp := Gradient.new()
	random_ramp.set_color(0, Color(1.0, 0.0, 1.0, 1.0))
	random_ramp.set_color(1, Color(1.0, 1.0, 1.0, 1.0))
	p.color_initial_ramp = random_ramp
	parent.add_child(p)
	p.emitting = true
	return p


## Brief warm point light at the blast so nearby models light up.
static func light_flash(parent: Node3D, size: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 1.6 * ArtStyle.flash_scale()
	light.omni_range = 5.0 * size + 3.0
	light.shadow_enabled = false
	parent.add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
