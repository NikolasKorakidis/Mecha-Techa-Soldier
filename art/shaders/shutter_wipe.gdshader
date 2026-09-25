// Mecha shutter wipe for scene changes: slanted armour plates sweep across the screen (one
// plate after another), meet, then keep sweeping off the far side. Each plate has a glowing
// leading edge; every third one carries a gold accent. `phase`: 0 open → 1 covered → 2 open.
shader_type canvas_item;

uniform float phase : hint_range(0.0, 2.0) = 0.0;
uniform float bands = 9.0;
uniform float slant = 0.18;
uniform vec4 fill : source_color = vec4(0.018, 0.03, 0.062, 1.0);
uniform vec4 plate_light : source_color = vec4(0.05, 0.08, 0.15, 1.0);
uniform vec4 edge : source_color = vec4(0.37, 0.83, 1.0, 1.0);
uniform vec4 accent : source_color = vec4(1.0, 0.76, 0.3, 1.0);

void fragment() {
	vec2 uv = UV;
	float band_coord = (uv.y + uv.x * slant) * bands;
	float band = floor(band_coord);
	float within = fract(band_coord);
	// Plates start one after another (top first) and cover left → right.
	float delay = clamp(band / bands, 0.0, 1.0) * 0.4;
	float sweep = uv.x * 0.86 + (1.0 - within) * 0.14;
	float covered;
	float front;
	if (phase <= 1.0) {
		float p = clamp((phase - delay) / 0.6, 0.0, 1.0);
		p = p * p * (3.0 - 2.0 * p);
		front = p * 1.04;
		covered = step(sweep, front);
	} else {
		float p = clamp((phase - 1.0 - delay) / 0.6, 0.0, 1.0);
		p = p * p * (3.0 - 2.0 * p);
		front = p * 1.04;
		covered = step(front, sweep);
	}
	// Plate shading: a lit top bevel, a dark seam between plates.
	vec3 col = mix(fill.rgb, plate_light.rgb, smoothstep(0.75, 1.0, within) * 0.8);
	col *= mix(0.55, 1.0, smoothstep(0.0, 0.06, within));
	// Glowing leading edge while the plate is moving.
	float moving = step(0.001, front) * step(front, 1.03);
	float glow = smoothstep(0.02, 0.0, abs(sweep - front)) * moving;
	vec3 glow_col = mod(band, 3.0) == 1.0 ? accent.rgb : edge.rgb;
	col += glow_col * glow * 1.4;
	COLOR = vec4(col, covered);
}
