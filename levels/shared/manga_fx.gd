class_name MangaFx
extends CanvasLayer
## Manga / super-robot anime overlays: radial speed lines streaming toward the edges and
## impact frames (white fill, black speed lines, for a couple of frames). Below the letterbox.

const SHADER := """
shader_type canvas_item;
uniform float intensity = 0.0;
uniform float impact = 0.0;
uniform float seed = 0.0;
uniform vec2 focus = vec2(0.5, 0.5);
float hash(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	vec2 p = UV - focus;
	p.x *= 1.7778;
	float ang = atan(p.y, p.x);
	float r = length(p);
	float bucket = floor((ang + 3.14159) * 70.0);
	float pick = hash(bucket * 1.37 + floor(seed));
	float width = hash(bucket * 7.1 + floor(seed) * 3.0);
	float line = step(0.55, pick) * smoothstep(0.12 + width * 0.25, 0.75, r);
	float a = line * intensity;
	vec3 line_col = mix(vec3(1.0), vec3(0.0), impact);
	vec3 base = vec3(1.0);
	COLOR = mix(vec4(line_col, a * 0.8), vec4(mix(base, line_col, line), 1.0), impact);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var _seed: float = 0.0
var _impact_left: float = 0.0


func _init() -> void:
	layer = 7
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_rect.material = _mat
	add_child(_rect)
	set_intensity(0.0)


func set_intensity(value: float) -> void:
	_mat.set_shader_parameter(&"intensity", value)
	_rect.visible = value > 0.001 or _impact_left > 0.0


func set_focus(uv: Vector2) -> void:
	_mat.set_shader_parameter(&"focus", uv)


## White impact frame with black speed lines for `seconds` (reduced-flash: a softer frame).
func impact(seconds: float = 0.1) -> void:
	_impact_left = seconds
	_rect.visible = true
	_mat.set_shader_parameter(&"impact", lerpf(0.35, 1.0, ArtStyle.flash_scale()))


func _process(delta: float) -> void:
	# The line pattern re-rolls a dozen times a second, like hand-drawn animation.
	_seed += delta * 14.0
	_mat.set_shader_parameter(&"seed", _seed)
	if _impact_left > 0.0:
		_impact_left -= delta
		if _impact_left <= 0.0:
			_mat.set_shader_parameter(&"impact", 0.0)
			_rect.visible = float(_mat.get_shader_parameter(&"intensity")) > 0.001
