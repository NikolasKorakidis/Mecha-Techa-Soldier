// The campaign's deep-space sky, drawn per pixel (no meshes, no polygon edges):
//   round, colour-graded stars in three layers plus a dense galactic band with dust lanes,
//   a domain-warped nebula, the sun (disc, corona, soft rays),
//   and the star system's planets ray-traced as perfect spheres at infinity —
//   a banded gas giant with a shadowed ring, an ocean world (continents, clouds, city lights,
//   atmosphere halo) and a cratered red moon.
// Directions are world-space unit vectors; radii are angular (radians). SpacePlanets sets the
// uniforms per layout. Pure math (no textures), static in time so the radiance map is built once.
shader_type sky;

#include "res://art/shaders/space_vista.gdshaderinc"

void sky() {
	vec3 d = normalize(EYEDIR);
	if (AT_CUBEMAP_PASS) {
		// Radiance / ambient only: the average tone of the sky is enough.
		COLOR = deep_color + nebula_b * 0.08 + sun_color * pow(max(dot(d, normalize(sun_dir)), 0.0), 8.0) * 0.3;
	} else {
		COLOR = space_color(d) * brightness;
	}
}
