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

	float diffuse = clamp(dot(NORMAL, normalize(light_direction)), 0.0, 1.0);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = col * (0.12 + 0.88 * diffuse) + atmosphere * fresnel * (0.25 + 0.75 * diffuse);
	ALBEDO = col;
}
