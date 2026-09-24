class_name ImpactSpark
extends Node3D
## Small hit confirmation: a pop of light and a few sparks.

@export var size: float = 1.0
@export var color: Color = Color(0.6, 0.95, 1.0)
## Sparks spray along this direction (the projectile passes the reverse of its travel).
@export var direction: Vector3 = Vector3.LEFT


func _ready() -> void:
	var pop := ModelKit.quad(self, Vector2.ONE * 1.0 * size, Vector3(0, 0, 0.4), ModelKit.glow(color, 2.5 * ArtStyle.flash_scale()))
	var tween := create_tween().set_parallel()
	tween.tween_property(pop, "scale", Vector3.ONE * 1.6, 0.08)
	tween.tween_property(pop.material_override, "shader_parameter/energy", 0.0, 0.1)

	var p := CPUParticles3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.05, 0.35) * size
	mesh.material = ModelKit.glow(color, 2.0, ModelKit.GlowShape.STREAK)
	p.mesh = mesh
	p.amount = 6
	p.lifetime = 0.22
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 70.0
	p.direction = direction.normalized() if direction.length_squared() > 0.0 else Vector3.LEFT
	p.gravity = Vector3.ZERO
	p.particle_flag_align_y = true
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 10.0
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.35, false).timeout.connect(queue_free)
