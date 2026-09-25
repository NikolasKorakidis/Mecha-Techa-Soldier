class_name Explosion3D
extends Node3D
## Camera-facing explosion for the 3D chase view: white core flash, billowing fireball,
## streaking sparks, dark smoke and a shockwave ring. Every layer is billboarded so it reads
## from any angle (side-view Explosion uses flat quads). Frees itself.

@export var size: float = 1.0
@export var fire_color: Color = Color(1.0, 0.55, 0.15)
@export var trauma: float = 0.0

var _age: float = 0.0
var _flash: MeshInstance3D
var _ring: MeshInstance3D

static var _fire_mat: StandardMaterial3D
static var _smoke_mat: StandardMaterial3D
static var _spark_mat: StandardMaterial3D


static func spawn(tree: SceneTree, at: Vector3, s: float = 1.0, shake: float = 0.0) -> Explosion3D:
	var root := tree.get_first_node_in_group(Vfx.ROOT_GROUP)
	if root == null:
		push_error("Explosion3D: no vfx root in the level.")
		return null
	var e := Explosion3D.new()
	e.size = s
	e.trauma = shake
	e.position = at - (root as Node3D).global_position
	root.add_child(e)
	return e


func _ready() -> void:
	# Far-off battle explosions are felt, not heard: only nearby blasts make sound.
	var cam := GameplayCamera.find(get_tree())
	if size >= 0.5 and (cam == null or cam.global_position.distance_to(global_position) < 90.0 + size * 10.0):
		AudioService.play_explosion(size)
	_ensure_materials()
	var quad := QuadMesh.new()
	_flash = MeshInstance3D.new()
	_flash.mesh = quad
	_flash.material_override = ModelKit.glow_billboard(Color(1.0, 0.9, 0.7), 2.0 * ArtStyle.flash_scale())
	_flash.scale = Vector3.ONE * size * 3.0
	add_child(_flash)
	_ring = MeshInstance3D.new()
	_ring.mesh = quad
	_ring.material_override = ModelKit.glow_billboard(fire_color, 1.2, ModelKit.GlowShape.RING)
	_ring.scale = Vector3.ONE * size
	add_child(_ring)
	_burst(_fire_mat, 22, 0.9, 5.0 * size, Vector2(0.9, 2.2) * size, 0.0, 0.85)
	_burst(_smoke_mat, 10, 1.8, 2.5 * size, Vector2(1.2, 2.6) * size, 2.0, 0.4)
	_burst(_spark_mat, 18, 0.7, 16.0 * size, Vector2(0.12, 0.25) * size, -12.0, 1.0)
	var camera := GameplayCamera.find(get_tree())
	if camera and trauma > 0.0:
		camera.add_trauma(trauma)


func _burst(mat: Material, amount: int, life: float, speed: float, scale_range: Vector2, gravity_y: float, explosiveness: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = Settings.particle_amount(amount)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = explosiveness
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.6
	p.damping_max = speed * 1.2
	p.gravity = Vector3(0, gravity_y, 0)
	p.scale_amount_min = scale_range.x
	p.scale_amount_max = scale_range.y
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.material = mat
	p.mesh = quad
	p.emitting = true
	add_child(p)


static func _ensure_materials() -> void:
	if _fire_mat:
		return
	_fire_mat = _particle_material(Color(1.0, 0.6, 0.2), BaseMaterial3D.BLEND_MODE_ADD)
	_smoke_mat = _particle_material(Color(0.12, 0.1, 0.12, 0.7), BaseMaterial3D.BLEND_MODE_MIX)
	_spark_mat = _particle_material(Color(1.0, 0.9, 0.6), BaseMaterial3D.BLEND_MODE_ADD)


static func _particle_material(color: Color, blend: BaseMaterial3D.BlendMode) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = blend
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.albedo_texture = _soft_dot()
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


static var _dot: GradientTexture2D


static func _soft_dot() -> GradientTexture2D:
	if _dot:
		return _dot
	_dot = GradientTexture2D.new()
	_dot.fill = GradientTexture2D.FILL_RADIAL
	_dot.fill_from = Vector2(0.5, 0.5)
	_dot.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_dot.gradient = g
	_dot.width = 64
	_dot.height = 64
	return _dot


func _process(delta: float) -> void:
	_age += delta
	var f := clampf(_age / 0.35, 0.0, 1.0)
	(_flash.material_override as ShaderMaterial).set_shader_parameter(&"energy", 2.0 * (1.0 - f) * ArtStyle.flash_scale())
	_ring.scale = Vector3.ONE * size * (1.0 + _age * 5.0)
	(_ring.material_override as ShaderMaterial).set_shader_parameter(&"energy", maxf(0.0, 0.8 - _age * 2.6))
	if _age > 2.2:
		queue_free()
