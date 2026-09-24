class_name CoreCollapse
extends Node3D
## Echo carrier death: the gold core implodes for a beat, then bursts.

@export var size: float = 1.0
@export var explosion: PackedScene

const DURATION := 0.28


func _ready() -> void:
	var core := ModelKit.sphere(self, 0.45 * size, Vector3(0, 0, 0.8), ModelKit.emissive(Palette.ECHO_GOLD.lerp(Color.WHITE, 0.5), 4.0))
	var ring := ModelKit.quad(self, Vector2.ONE * 4.0 * size, Vector3(0, 0, 0.9), ModelKit.glow(Palette.ECHO_GOLD, ArtStyle.GLOW_HOT, ModelKit.GlowShape.RING))
	var tween := create_tween().set_parallel()
	tween.tween_property(core, "scale", Vector3.ONE * 0.2, DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(ring, "scale", Vector3.ONE * 0.15, DURATION).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_burst)


func _burst() -> void:
	if explosion:
		Vfx.spawn(get_tree(), explosion, global_position, size)
	queue_free()
