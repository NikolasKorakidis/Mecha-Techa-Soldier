class_name CollectBurst
extends Node3D
## Weapon-core pickup confirmation: an expanding ring and a rising glyph glow at the ship.

@export var size: float = 1.0
@export var color: Color = Palette.ECHO_GOLD


func _ready() -> void:
	var ring := ModelKit.quad(self, Vector2.ONE * 2.0 * size, Vector3(0, 0, 0.8), ModelKit.glow(color, ArtStyle.GLOW_HOT * ArtStyle.flash_scale(), ModelKit.GlowShape.RING))
	var core := ModelKit.quad(self, Vector2.ONE * 1.6 * size, Vector3(0, 0, 0.7), ModelKit.glow(color.lerp(Color.WHITE, 0.4), ArtStyle.GLOW_STANDARD * ArtStyle.flash_scale()))
	ring.scale = Vector3.ONE * 0.3
	var tween := create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE * 2.2, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring.material_override, "shader_parameter/energy", 0.0, 0.35)
	tween.tween_property(core.material_override, "shader_parameter/energy", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)
