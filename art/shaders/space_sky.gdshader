// Procedural space sky for 3D views: three star layers, a galactic band and soft nebula
// clouds. Pure math (no textures) so it runs on the Compatibility renderer.
shader_type sky;

uniform vec3 deep_color : source_color = vec3(0.01, 0.015, 0.04);
uniform vec3 nebula_a : source_color = vec3(0.25, 0.08, 0.35);
uniform vec3 nebula_b : source_color = vec3(0.05, 0.18, 0.35);
uniform vec3 band_color : source_color = vec3(0.35, 0.3, 0.45);
uniform float star_density = 1.0;
uniform float brightness = 1.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

float stars(vec3 dir, float scale, float threshold) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	float h = hash(cell);
	if (h < threshold) {
		return 0.0;
	}
	vec3 center = cell + vec3(hash(cell + 1.3), hash(cell + 2.7), hash(cell + 4.1));
	float d = length(p - center);
	return smoothstep(0.35, 0.0, d) * (h - threshold) / (1.0 - threshold);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 col = deep_color;
	// Galactic band tilted across the sky.
	float band = exp(-pow(dot(dir, normalize(vec3(0.2, 1.0, 0.35))) * 3.2, 2.0));
	col += band_color * band * (0.35 + 0.65 * fbm(dir * 6.0)) * 0.6;
	// Nebula clouds.
	float n1 = fbm(dir * 2.2 + vec3(3.1, 0.0, 1.7));
	float n2 = fbm(dir * 3.4 + vec3(-2.0, 5.0, 0.3));
	col += nebula_a * pow(n1, 3.0) * 1.6;
	col += nebula_b * pow(n2, 3.0) * 1.4;
	// Stars: sparse bright, medium, dense faint (denser inside the band).
	float s = stars(dir, 90.0, 0.985) * 2.5 + stars(dir, 180.0, 0.975 - band * 0.02) * 1.2 + stars(dir, 360.0, 0.965 - band * 0.03) * 0.6;
	col += vec3(0.9, 0.95, 1.0) * s * star_density;
	COLOR = col * brightness;
}
