// Sky for the Stage 1 perspective backdrop: a gradient sky (zenith / horizon / below) with a
// sun disc and a star field whose strength fades in for space. Zone changes lerp the uniforms.
shader_type sky;

uniform vec3 zenith : source_color = vec3(0.01, 0.015, 0.05);
uniform vec3 horizon : source_color = vec3(0.05, 0.08, 0.2);
uniform vec3 below : source_color = vec3(0.0, 0.0, 0.02);
uniform vec3 sun_color : source_color = vec3(1.0, 0.85, 0.6);
uniform vec3 sun_dir = vec3(0.6, 0.15, -0.8);
uniform float sun_size = 0.03;
uniform float stars = 1.0;
uniform float nebula = 0.5;
uniform vec3 nebula_color : source_color = vec3(0.25, 0.1, 0.35);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = h > 0.0 ? mix(horizon, zenith, pow(clamp(h, 0.0, 1.0), 0.55)) : mix(horizon, below, pow(clamp(-h, 0.0, 1.0), 0.4));
	float n = noise(d * 3.0) * 0.6 + noise(d * 7.0) * 0.4;
	col += nebula_color * pow(n, 3.0) * nebula * 2.0;
	vec3 cell = floor(d * 220.0);
	float s = hash(cell);
	col += vec3(0.9, 0.95, 1.0) * step(0.992, s) * (s - 0.992) * 125.0 * stars;
	float sd = dot(d, normalize(sun_dir));
	col += sun_color * (smoothstep(1.0 - sun_size, 1.0 - sun_size * 0.6, sd) * 3.0 + pow(max(sd, 0.0), 24.0) * 0.6 + pow(max(sd, 0.0), 4.0) * 0.15);
	COLOR = col;
}
