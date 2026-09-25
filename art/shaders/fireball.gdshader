// Procedural fireball / smoke puff for explosion particles (camera-facing).
// Each particle is a noise-eroded puff whose temperature falls with age: white-hot core →
// orange → deep red → alpha-blended dark smoke. Particle COLOR carries the data:
//   COLOR.r = age (0..1, from the colour ramp), COLOR.g = per-particle random (initial ramp).
// Hot parts are HDR (> 1) so they bloom; smoke genuinely darkens what is behind it.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// 1 = fire that cools into smoke, ~0 = smoke only.
uniform float heat = 1.0;
uniform vec3 smoke_color : source_color = vec3(0.1, 0.09, 0.1);
uniform float glow = 2.4;

varying float age;
varying float rnd;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	age = COLOR.r;
	rnd = COLOR.g;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float ang = rnd * 6.2831;
	p = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * p;
	float n = fbm(p * 2.2 + vec2(rnd * 17.0, age * 1.4));
	float n2 = fbm(p * 4.6 - vec2(age * 2.2, rnd * 9.0));
	float r = length(p) + (n - 0.5) * 0.6;
	float grow = mix(0.5, 0.95, sqrt(age));
	float shape = smoothstep(grow, grow * 0.5, r);
	float temp = clamp(heat * (1.25 - age * 1.7) - length(p) * 0.65 + (n2 - 0.5) * 0.55, 0.0, 1.0);
	vec3 fire = mix(vec3(0.75, 0.1, 0.03), vec3(1.0, 0.45, 0.08), smoothstep(0.2, 0.5, temp));
	fire = mix(fire, vec3(1.0, 0.88, 0.6), smoothstep(0.55, 0.9, temp));
	vec3 smoke = smoke_color * (0.6 + n * 0.8);
	float fire_amount = smoothstep(0.04, 0.32, temp);
	ALBEDO = mix(smoke, fire * glow * (0.55 + temp), fire_amount);
	float fade = 1.0 - smoothstep(0.55, 1.0, age);
	ALPHA = shape * fade * mix(0.8, 1.0, fire_amount);
}
