// Far backdrop: drifting teal/violet nebula with sparse twinkling stars.
// Kept dark and desaturated so gameplay colors always win.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://art/shaders/noise.gdshaderinc"

uniform vec3 deep_color : source_color = vec3(0.012, 0.035, 0.07);
uniform vec3 teal_color : source_color = vec3(0.03, 0.2, 0.26);
uniform vec3 violet_color : source_color = vec3(0.16, 0.07, 0.26);
uniform vec3 warm_color : source_color = vec3(0.5, 0.22, 0.12);
uniform float scroll_speed = 0.006;
uniform float brightness = 1.0;

void fragment() {
	vec2 uv = UV * vec2(3.2, 1.8) + vec2(TIME * scroll_speed, 0.0);
	float warp = fbm(uv * 0.7);
	float n1 = fbm(uv + warp * 0.9);
	float n2 = fbm(uv * 1.6 + vec2(4.0, 2.0) - warp * 0.5);
	vec3 col = deep_color;
	col = mix(col, teal_color, smoothstep(0.38, 0.85, n1) * 0.85);
	col = mix(col, violet_color, smoothstep(0.45, 0.9, n2) * 0.75);
	col += warm_color * pow(smoothstep(0.55, 1.0, n1 * n2 * 1.7), 2.0) * 0.5;

	// Distant star dust: fixed grid cells, a few lit, slow twinkle.
	vec2 cell = floor((UV + vec2(TIME * scroll_speed * 0.3, 0.0)) * vec2(420.0, 236.0));
	float star = step(0.9975, hash21(cell));
	float twinkle = 0.6 + 0.4 * sin(TIME * 2.0 + hash21(cell + 3.0) * 40.0);
	col += vec3(0.7, 0.85, 1.0) * star * twinkle * 0.8;

	ALBEDO = col * brightness;
}
