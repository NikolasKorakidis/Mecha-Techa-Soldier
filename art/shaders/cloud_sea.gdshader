// Endless cloud sea seen from above at sunset (Stage 1 boss zone). World-space noise so the
// plane can stay under the camera while clouds stream past; lit from the low sun side.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

#include "res://art/shaders/noise.gdshaderinc"

uniform vec3 lit : source_color = vec3(1.0, 0.62, 0.35);
uniform vec3 shade : source_color = vec3(0.35, 0.12, 0.2);
uniform vec3 haze : source_color = vec3(0.95, 0.5, 0.3);
uniform float scale = 0.012;
uniform float fade_distance = 900.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * scale;
	float c = fbm(p) * 0.65 + fbm(p * 2.7 + vec2(TIME * 0.02, 0.0)) * 0.35;
	float puff = smoothstep(0.35, 0.75, c);
	vec3 col = mix(shade, lit, puff);
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	col = mix(col, haze, clamp(dist / fade_distance, 0.0, 1.0));
	ALBEDO = col;
}
