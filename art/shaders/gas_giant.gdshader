// Banded gas giant with a bright atmospheric rim. Self-lit so it reads the same
// on Forward+ and the web Compatibility renderer.
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

#include "res://art/shaders/noise.gdshaderinc"

uniform vec3 band_dark : source_color = vec3(0.05, 0.13, 0.36);
uniform vec3 band_mid : source_color = vec3(0.12, 0.32, 0.66);
uniform vec3 band_light : source_color = vec3(0.36, 0.64, 0.86);
uniform vec3 atmosphere : source_color = vec3(0.45, 0.85, 1.0);
uniform vec3 light_direction = vec3(-0.55, 0.65, 0.55);
uniform float rotation_speed = 0.004;
uniform vec3 cloud_color : source_color = vec3(0.7, 0.88, 1.0);
uniform float cloud_strength = 0.35;
uniform vec3 night_color : source_color = vec3(0.01, 0.02, 0.06);

varying vec3 object_normal;

void vertex() {
	object_normal = NORMAL;
}

void fragment() {
	vec3 n = normalize(object_normal);
	float lon = atan(n.z, n.x) + TIME * rotation_speed;
	float lat = n.y;
	float turbulence = fbm(vec2(lon * 2.0, lat * 7.0)) * 0.3;
	float bands = sin((lat + turbulence) * 22.0) * 0.5 + 0.5;
	vec3 col = mix(band_dark, band_mid, bands);
	col = mix(col, band_light, smoothstep(0.62, 0.95, fbm(vec2(lon * 5.0, lat * 16.0))) * 0.7);

	// Two broad, slowly drifting cloud bands.
	float cloud_noise = fbm(vec2(lon * 3.0 + TIME * 0.01, lat * 5.0));
	float bands_mask = smoothstep(0.12, 0.0, abs(lat - 0.28 + cloud_noise * 0.08))
			+ smoothstep(0.08, 0.0, abs(lat + 0.12 + cloud_noise * 0.06)) * 0.7;
	col = mix(col, cloud_color, clamp(bands_mask, 0.0, 1.0) * cloud_strength);

	float diffuse = clamp(dot(NORMAL, normalize(light_direction)), 0.0, 1.0);
	float terminator = smoothstep(0.0, 0.35, diffuse);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = mix(night_color, col * (0.3 + 0.5 * diffuse), terminator);
	col += atmosphere * fresnel * (0.12 + 0.5 * diffuse);
	ALBEDO = col;
}
