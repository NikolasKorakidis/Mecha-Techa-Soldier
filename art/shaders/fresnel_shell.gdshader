// Additive fresnel shell: clear face-on, bright at grazing angles. Energy bubbles and glass
// highlights around pickups without transparency sorting. Capped like additive_glow so HDR
// bloom stays tight on desktop.
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.5, 0.9, 1.0, 1.0);
uniform float energy = 1.0;
uniform float power = 2.5;
uniform float max_brightness = 1.3;

void fragment() {
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), power);
	vec3 c = tint.rgb * energy * edge * tint.a;
	float peak = max(max(c.r, c.g), max(c.b, 1e-4));
	ALBEDO = c * min(1.0, max_brightness / peak);
}
