// Shared by the space_vista sky shader and the space_window spatial shader: uniforms and
// functions for stars, nebula, galactic band, the sun and the ray-traced planets.
uniform vec3 deep_color : source_color = vec3(0.004, 0.006, 0.02);
uniform vec3 nebula_a : source_color = vec3(0.42, 0.1, 0.5);
uniform vec3 nebula_b : source_color = vec3(0.06, 0.2, 0.5);
uniform vec3 nebula_c : source_color = vec3(0.9, 0.35, 0.3);
uniform float nebula_strength = 1.0;
uniform vec3 band_axis = vec3(0.25, 1.0, 0.3);
uniform vec3 band_color : source_color = vec3(0.55, 0.5, 0.62);
uniform float star_density = 1.0;
uniform float brightness = 1.0;
// Angular size of one screen pixel: sets edge anti-aliasing and star size.
uniform float pixel_angle = 0.0009;

uniform vec3 sun_dir = vec3(0.1, 0.35, -0.93);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.75);
uniform float sun_radius = 0.012;

uniform bool giant_on = true;
uniform vec3 giant_dir = vec3(-0.22, 0.12, -0.97);
uniform float giant_radius = 0.1;
uniform vec3 giant_pole = vec3(0.25, 1.0, 0.1);
uniform vec3 giant_light = vec3(0.55, 0.45, 0.7);
uniform vec3 giant_dark : source_color = vec3(0.32, 0.14, 0.08);
uniform vec3 giant_mid : source_color = vec3(0.72, 0.44, 0.24);
uniform vec3 giant_pale : source_color = vec3(0.97, 0.84, 0.62);
uniform vec3 ring_normal = vec3(0.3, 0.9, 0.3);
uniform vec2 ring_span = vec2(1.3, 2.25);
uniform vec3 ring_color : source_color = vec3(0.7, 0.6, 0.48);

uniform bool world_on = true;
uniform vec3 world_dir = vec3(0.39, -0.54, -0.74);
uniform float world_radius = 0.43;
uniform vec3 world_pole = vec3(0.2, 1.0, 0.35);
uniform vec3 world_light = vec3(-0.3, 0.7, 0.65);
uniform vec3 ocean_color : source_color = vec3(0.012, 0.06, 0.2);
uniform vec3 land_color : source_color = vec3(0.14, 0.22, 0.11);
uniform vec3 desert_color : source_color = vec3(0.45, 0.36, 0.22);
uniform vec3 atmosphere_color : source_color = vec3(0.35, 0.65, 1.0);

uniform bool moon_on = true;
uniform vec3 moon_dir = vec3(0.49, 0.2, -0.84);
uniform float moon_radius = 0.042;
uniform vec3 moon_light = vec3(-0.4, 0.5, 0.75);
uniform vec3 moon_color : source_color = vec3(0.62, 0.26, 0.2);

// --- noise ------------------------------------------------------------------------------

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x),
				mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
				mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p, int octaves) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < octaves; i++) {
		v += a * noise3(p);
		p = p * 2.02 + vec3(1.7, 9.2, 4.1);
		a *= 0.5;
	}
	return v;
}

// --- sky layers -------------------------------------------------------------------------

// One star layer: a jittered point per cell with a gaussian profile a pixel or two wide.
vec3 star_layer(vec3 dir, float scale, float keep, float size) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	vec3 h = hash33(cell);
	if (h.x > keep) {
		return vec3(0.0);
	}
	vec3 centre = cell + 0.2 + h * 0.6;
	float d = length(p - centre) / (pixel_angle * scale);
	float r = size * (0.6 + h.y * 0.9);
	float glow = exp(-d * d / (r * r));
	// Colour temperature: mostly white, some blue, some amber.
	vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.85, 0.65), h.z);
	return tint * glow * (0.35 + h.y * h.y * 1.6);
}

vec3 nebula(vec3 dir) {
	vec3 p = dir * 2.3;
	vec3 q = vec3(fbm(p, 4), fbm(p + vec3(5.2, 1.3, 2.8), 4), fbm(p + vec3(1.7, 9.2, 3.1), 4));
	float n = fbm(p + q * 2.2, 5);
	float dust = fbm(dir * 9.0 + q * 3.0, 4);
	vec3 col = mix(nebula_b, nebula_a, smoothstep(0.35, 0.7, q.x));
	col = mix(col, nebula_c, smoothstep(0.62, 0.82, q.y) * 0.55);
	float density = smoothstep(0.38, 0.85, n);
	density *= 1.0 - smoothstep(0.45, 0.72, dust) * 0.75;
	// Bright filament edges.
	float filament = smoothstep(0.02, 0.0, abs(n - 0.6)) * 0.35;
	return col * (density * density * 1.5 + filament * density) * nebula_strength;
}

// --- planets ----------------------------------------------------------------------------

// Ray (from the origin along d) against a sphere at unit distance: returns coverage (0..1,
// anti-aliased limb) and the surface normal; h is the ray's angular miss distance.
float sphere(vec3 d, vec3 centre_dir, float radius, out vec3 normal, out float t, out float h) {
	vec3 c = normalize(centre_dir);
	float r = sin(radius);
	float b = dot(d, c);
	h = sqrt(max(0.0, 1.0 - b * b));
	float disc = b * b - (1.0 - r * r);
	t = b - sqrt(max(disc, 0.0));
	vec3 p = d * t;
	normal = normalize(p - c);
	if (b <= 0.0) {
		return 0.0;
	}
	return smoothstep(r + pixel_angle, r - pixel_angle, h);
}

// Latitude / longitude on a planet, with the longitude seam on the far side.
vec2 latlon(vec3 n, vec3 pole, vec3 centre_dir) {
	vec3 up = normalize(pole);
	vec3 front = normalize(-centre_dir - up * dot(-centre_dir, up));
	vec3 side = cross(up, front);
	return vec2(dot(n, up), atan(dot(n, side), dot(n, front)));
}

float lit(vec3 n, vec3 light, float soft) {
	return smoothstep(-soft, soft * 2.5, dot(n, normalize(light)));
}

vec3 shade_giant(vec3 n, vec3 d) {
	vec2 ll = latlon(n, giant_pole, giant_dir);
	float lat = ll.x;
	float lon = ll.y;
	float warp = fbm(vec3(lon * 3.0, lat * 12.0, 1.3), 4);
	float b = lat * 7.5 + warp * 1.4;
	float bands = sin(b * 3.14159) * 0.5 + 0.5;
	float fine = fbm(vec3(lon * 4.0, lat * 30.0 + warp * 3.0, 7.7), 4);
	vec3 col = mix(giant_dark, giant_mid, bands);
	col = mix(col, giant_pale, smoothstep(0.55, 0.85, fine) * 0.4);
	col *= 0.9 + fine * 0.2;
	// A great storm.
	vec2 storm = vec2((lon - 0.55) * 2.6, (lat + 0.28) * 7.0);
	float s = length(storm);
	col = mix(col, vec3(0.78, 0.36, 0.2), smoothstep(0.9, 0.4, s) * 0.8);
	col = mix(col, giant_pale, smoothstep(0.35, 0.0, s) * 0.5);
	float day = lit(n, giant_light, 0.12);
	float fres = pow(1.0 - clamp(dot(n, -d), 0.0, 1.0), 2.5);
	col *= 0.05 + 0.95 * day;
	col += giant_pale * fres * 0.25 * day;
	// Limb darkening.
	col *= 0.55 + 0.45 * pow(clamp(dot(n, -d), 0.0, 1.0), 0.4);
	return col;
}

vec3 shade_world(vec3 n, vec3 d) {
	vec3 up = normalize(world_pole);
	float lat = dot(n, up);
	vec3 np = n * 2.1;
	vec3 w = vec3(fbm(np * 1.3, 3), fbm(np * 1.3 + 4.1, 3), fbm(np * 1.3 + 8.7, 3));
	float land = fbm(np + w * 1.2, 6);
	float is_land = smoothstep(0.545, 0.56, land);
	float coast = smoothstep(0.5, 0.545, land) * (1.0 - is_land);
	float dry = smoothstep(0.55, 0.75, fbm(n * 6.0 + 2.0, 4)) * (1.0 - abs(lat));
	vec3 ground = mix(land_color, desert_color, dry);
	ground *= 0.75 + 0.5 * fbm(n * 22.0, 4);
	float depth = fbm(n * 5.0 + 1.0, 3);
	vec3 sea = ocean_color * (0.7 + depth * 0.6);
	sea = mix(sea, ocean_color * 1.35 + vec3(0.0, 0.03, 0.03), coast * 0.6);
	vec3 col = mix(sea, ground, is_land);
	// Ice caps.
	float ice = smoothstep(0.88, 0.92, abs(lat) + (fbm(n * 8.0, 3) - 0.5) * 0.12);
	col = mix(col, vec3(0.9, 0.95, 1.0), ice);
	// Clouds: swirling fbm, stretched along the latitude lines.
	vec3 cp = vec3(n.x, n.y * 1.6, n.z) * 3.2 + w * 1.6;
	float clouds = smoothstep(0.56, 0.82, fbm(cp, 6));
	vec3 l = normalize(world_light);
	float day = lit(n, l, 0.08);
	vec3 v = -d;
	float spec = pow(max(dot(reflect(-l, n), v), 0.0), 60.0) * (1.0 - is_land) * (1.0 - clouds);
	col = mix(col, vec3(0.9, 0.93, 0.97), clouds * 0.8);
	col = col * (0.015 + 0.95 * day) + vec3(1.0, 0.95, 0.85) * spec * 0.6 * day;
	// City lights on the night side.
	float city = smoothstep(0.72, 0.9, noise3(n * 90.0)) * smoothstep(0.55, 0.7, fbm(n * 9.0, 3));
	col += vec3(1.0, 0.72, 0.35) * city * is_land * (1.0 - clouds) * (1.0 - day) * 0.9;
	// Atmosphere: blue fresnel, orange at the terminator.
	float mu = clamp(dot(n, v), 0.0, 1.0);
	float fres = pow(1.0 - mu, 3.0);
	float term = smoothstep(0.25, 0.0, abs(dot(n, l))) * day;
	col += atmosphere_color * fres * (0.15 + 0.9 * day);
	col += vec3(1.0, 0.45, 0.2) * term * 0.12;
	return col;
}

vec3 shade_moon(vec3 n, vec3 d) {
	float base = fbm(n * 4.0, 5);
	float craters = 0.0;
	for (int i = 0; i < 3; i++) {
		float sc = 5.0 + float(i) * 7.0;
		vec3 p = n * sc;
		vec3 cell = floor(p);
		vec3 centre = cell + hash33(cell);
		float dist = length(p - centre);
		float rad = 0.25 + hash13(cell) * 0.2;
		craters += (smoothstep(rad, rad * 0.7, dist) * 0.35 - smoothstep(rad * 1.15, rad, dist) * smoothstep(rad * 0.8, rad, dist) * 0.25);
	}
	vec3 col = moon_color * (0.6 + base * 0.7) * (1.0 - craters * 0.8);
	col = mix(col, moon_color * 0.45, smoothstep(0.55, 0.7, fbm(n * 2.0 + 3.0, 3)) * 0.6);
	float day = lit(n, moon_light, 0.05);
	col *= 0.02 + day;
	col += vec3(1.0, 0.5, 0.35) * pow(1.0 - clamp(dot(n, -d), 0.0, 1.0), 4.0) * 0.12 * day;
	return col;
}

// Atmosphere halo just outside a limb, brighter on the lit side.
vec3 halo(vec3 d, vec3 centre_dir, float radius, float h, vec3 light, vec3 color, float width) {
	float r = sin(radius);
	vec3 c = normalize(centre_dir);
	vec3 side = normalize(d - c * dot(d, c));
	float x = (h - r) / (r * width);
	float glow = step(0.0, x) * exp(-max(x, 0.0) * 3.0);
	float sunward = smoothstep(-0.4, 0.8, dot(side, normalize(light)));
	return color * glow * (0.12 + 0.8 * sunward) * step(0.0, dot(d, c));
}

// Everything visible along the unit direction d (before brightness).
vec3 space_color(vec3 d) {
	vec3 col = deep_color;
	// Galactic band with dark dust lanes and its own star haze.
	float band_x = dot(d, normalize(band_axis));
	float band = exp(-band_x * band_x * 14.0);
	float lanes = smoothstep(0.42, 0.68, fbm(d * 11.0, 5)) * smoothstep(0.1, 0.0, abs(band_x + (fbm(d * 3.0, 3) - 0.5) * 0.15));
	col += band_color * band * (0.25 + 0.75 * fbm(d * 7.0, 4)) * 0.35 * (1.0 - lanes * 0.85);
	col += nebula(d);
	vec3 stars = star_layer(d, 70.0, 0.06, 1.1) * 1.6
			+ star_layer(d, 150.0, 0.1, 0.8)
			+ star_layer(d, 300.0, 0.08 + band * 0.25, 0.65) * 0.6;
	col += stars * star_density * (1.0 - lanes * 0.7);
	// Sun: disc, corona, broad glow and faint rays.
	vec3 sd = normalize(sun_dir);
	float cosang = dot(d, sd);
	float ang = acos(clamp(cosang, -1.0, 1.0));
	float disc = smoothstep(sun_radius + pixel_angle, sun_radius - pixel_angle, ang);
	vec3 perp = normalize(d - sd * cosang + vec3(1e-5));
	float rays = pow(abs(sin(atan(perp.y, perp.x + perp.z) * 6.0)), 12.0);
	vec3 sun = sun_color * (disc * 12.0 + exp(-ang / (sun_radius * 1.6)) * 1.6 + exp(-ang / (sun_radius * 8.0)) * 0.35 + exp(-ang * 4.0) * 0.06);
	sun += sun_color * rays * exp(-ang / (sun_radius * 5.0)) * 0.12;
	col += sun;

	// Planets, far to near: each one covers what is behind it.
	vec3 n;
	float t;
	float h;
	if (moon_on) {
		float cov = sphere(d, moon_dir, moon_radius, n, t, h);
		if (cov > 0.0) {
			col = mix(col, shade_moon(n, d), cov);
		}
	}
	if (world_on) {
		float cov = sphere(d, world_dir, world_radius, n, t, h);
		col += halo(d, world_dir, world_radius, h, world_light, atmosphere_color, 0.035) * (1.0 - cov);
		if (cov > 0.0) {
			col = mix(col, shade_world(n, d), cov);
		}
	}
	if (giant_on) {
		float cov = sphere(d, giant_dir, giant_radius, n, t, h);
		vec3 c = normalize(giant_dir);
		float r = sin(giant_radius);
		vec3 rn = normalize(ring_normal);
		// Ring plane hit.
		float denom = dot(d, rn);
		float tr = abs(denom) > 1e-4 ? dot(c, rn) / denom : -1.0;
		vec4 ring = vec4(0.0);
		if (tr > 0.0) {
			vec3 p = d * tr;
			float rr = length(p - c) / r;
			if (rr > ring_span.x && rr < ring_span.y) {
				float u = (rr - ring_span.x) / (ring_span.y - ring_span.x);
				float dens = 0.6 + 0.25 * sin(u * 70.0) * sin(u * 23.0 + 1.0) + 0.15 * sin(u * 9.0);
				dens *= smoothstep(0.0, 0.04, u) * smoothstep(1.0, 0.9, u);
				dens *= 1.0 - smoothstep(0.54, 0.56, u) * smoothstep(0.6, 0.58, u) * 0.9; // Cassini gap
				dens *= 0.75 + 0.5 * noise3(vec3(rr * 60.0, 0.0, 0.0));
				// The planet's shadow across the ring.
				vec3 l = normalize(giant_light);
				vec3 oc = p - c;
				float b2 = dot(oc, l);
				float c2 = dot(oc, oc) - r * r;
				float shadow = (b2 < 0.0 && b2 * b2 - c2 > 0.0) ? 0.15 : 1.0;
				vec3 rc = ring_color * mix(0.7, 1.15, u) * (0.35 + 0.65 * abs(dot(rn, l))) * shadow;
				ring = vec4(rc, clamp(dens, 0.0, 1.0) * 0.55);
			}
		}
		bool ring_front = tr > 0.0 && (cov <= 0.0 || tr < t);
		if (!ring_front) {
			col = mix(col, ring.rgb, ring.a);
		}
		col += halo(d, giant_dir, giant_radius, h, giant_light, giant_pale * 0.6, 0.03) * (1.0 - cov);
		if (cov > 0.0) {
			vec3 pc = shade_giant(n, d);
			// The ring's shadow on the cloud tops.
			vec3 l = normalize(giant_light);
			vec3 pp = d * t;
			float dl = dot(l, rn);
			if (abs(dl) > 1e-3) {
				float s = dot(c - pp, rn) / dl;
				if (s > 0.0) {
					float rq = length(pp + l * s - c) / r;
					float band_shadow = step(ring_span.x, rq) * step(rq, ring_span.y);
					pc *= 1.0 - band_shadow * 0.55;
				}
			}
			col = mix(col, pc, cov);
		}
		if (ring_front) {
			col = mix(col, ring.rgb, ring.a);
		}
	}
	return col;
}
