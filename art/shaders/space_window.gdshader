// A window onto space for side-view interiors: the space_vista sky seen through the glass with
// fake perspective (the view direction comes from the pixel's offset from the camera) and a
// slow drift as the camera travels, plus a faint glass sheen. SpacePlanets.apply sets the
// planets; `view_scale` is radians per world unit across the glass.
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled, cull_disabled;

#include "res://art/shaders/space_vista.gdshaderinc"

uniform float view_scale = 0.03;
uniform float drift = 0.0012;
uniform vec2 view_offset = vec2(0.0, -0.05);
uniform float glass = 0.06;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec2 rel = (world_pos.xy - cam.xy) * view_scale + cam.xy * drift + view_offset;
	vec3 d = normalize(vec3(rel, -1.0));
	vec3 col = space_color(d) * brightness;
	// Diagonal glass sheen.
	float sheen = smoothstep(0.0, 0.5, sin((world_pos.x + world_pos.y) * 0.9) - 0.6);
	col += vec3(0.6, 0.8, 1.0) * sheen * glass;
	ALBEDO = col;
}
