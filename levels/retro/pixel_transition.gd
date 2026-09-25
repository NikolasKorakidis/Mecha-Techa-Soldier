class_name PixelTransition
extends CanvasLayer
## Full-screen "de-rez": pixelates and posterizes whatever is on screen (screen texture), used
## to dissolve the 3D campaign into the 8-bit stage and to sharpen the 8-bit frame back in.
## Sits above the 8-bit stage layer and below the pause menu.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float block = 1.0;
uniform float posterize = 0.0;
void fragment() {
	vec2 px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 cell = (floor(px / block) * block + block * 0.5) * SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, cell).rgb;
	vec3 q = floor(c * 3.0 + 0.5) / 3.0;
	COLOR = vec4(mix(c, q, posterize), 1.0);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial


func _init() -> void:
	layer = 13
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


## Tween the effect from (block, posterize) to (block, posterize) over `seconds`.
func play(from_block: float, to_block: float, from_post: float, to_post: float, seconds: float) -> void:
	_rect.visible = true
	var tween := create_tween().set_parallel()
	tween.tween_method(func(v: float) -> void: _mat.set_shader_parameter(&"block", v), from_block, to_block, seconds)
	tween.tween_method(func(v: float) -> void: _mat.set_shader_parameter(&"posterize", v), from_post, to_post, seconds)
	await tween.finished


func clear() -> void:
	_rect.visible = false
