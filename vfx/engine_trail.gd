class_name EngineTrail
extends CPUParticles3D
## Exhaust trail: glowing motes left behind in world space so they stream past as the ship moves.

@export var trail_color: Color = Palette.PLAYER_ENERGY
@export var mote_size: float = 0.32


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * mote_size
	quad.material = ModelKit.glow(Color.WHITE, 1.3)
	mesh = quad
	local_coords = false
	amount = 28
	lifetime = 0.35
	direction = Vector3(-1, 0, 0)
	spread = 8.0
	gravity = Vector3.ZERO
	initial_velocity_min = 5.0
	initial_velocity_max = 8.0
	scale_amount_curve = Explosion._curve([Vector2(0, 1.0), Vector2(1, 0.1)])
	color_ramp = Explosion._gradient([trail_color, Color(0.25, 0.4, 1.0, 0.5), Color(0.1, 0.1, 0.4, 0.0)])
	emitting = true


## Stretches the exhaust with acceleration: faster, longer motes at high thrust.
func set_thrust(amount: float) -> void:
	var t := clampf(amount, 0.0, 2.0)
	initial_velocity_min = 4.0 + t * 3.0
	initial_velocity_max = 6.5 + t * 5.0
	scale_amount_min = 0.8 + t * 0.25
	scale_amount_max = scale_amount_min
