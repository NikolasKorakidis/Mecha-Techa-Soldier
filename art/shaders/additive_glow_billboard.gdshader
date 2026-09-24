// Camera-facing variant of additive_glow (3D chase view: explosions, muzzle flashes, lights).
// Vertex COLOR (particles) multiplies the tint, so one material serves many emitters.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float energy = 1.5;
// 0 = radial blob, 1 = streak (bright head at UV.x = 1), 2 = ring, 3 = flame cone (UV.y along length)
uniform int shape = 0;
uniform float ring_radius = 0.8;
uniform float ring_width = 0.12;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = 0.0;
	if (shape == 0) {
		a = pow(clamp(1.0 - length(p), 0.0, 1.0), 2.2);
	} else if (shape == 1) {
		a = pow(clamp(1.0 - abs(p.y), 0.0, 1.0), 2.0) * pow(UV.x, 1.5);
	} else if (shape == 2) {
		a = smoothstep(ring_width, 0.0, abs(length(p) - ring_radius));
	} else {
		a = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.6);
	}
	ALBEDO = tint.rgb * COLOR.rgb * energy * a * tint.a * COLOR.a;
}
