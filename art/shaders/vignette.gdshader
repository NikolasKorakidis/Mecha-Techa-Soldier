// Screen-space vignette drawn under the HUD.
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform vec3 tint : source_color = vec3(0.0, 0.02, 0.05);

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.25, 1.0);
	float v = smoothstep(0.35, 0.95, length(p) * 1.3);
	COLOR = vec4(tint, v * strength);
}
