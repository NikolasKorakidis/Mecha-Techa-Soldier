class_name MuzzleFlash
extends Node3D
## Short pop of light where a shot leaves a barrel.

@export var size: float = 1.0
@export var color: Color = Palette.HOSTILE_PROJECTILE


func _ready() -> void:
	var pop := ModelKit.quad(self, Vector2.ONE * 1.3 * size, Vector3(0, 0, 0.6), ModelKit.glow(color.lerp(Color.WHITE, 0.4), ArtStyle.GLOW_HOT * ArtStyle.flash_scale()))
	var tween := create_tween().set_parallel()
	tween.tween_property(pop, "scale", Vector3.ONE * 1.5, 0.07)
	tween.tween_property(pop.material_override, "shader_parameter/energy", 0.0, 0.09)
	tween.chain().tween_callback(queue_free)
