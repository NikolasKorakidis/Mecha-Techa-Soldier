// Desktop screen finish under the HUD: lens chromatic aberration that grows toward the edges,
// fine animated film grain, a soft cool vignette, and a hurt pulse (extra aberration and a red
// edge) when the player takes damage. The web build uses the cheaper vignette.gdshader.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float vignette : hint_range(0.0, 1.0) = 0.5;
uniform vec3 vignette_tint : source_color = vec3(0.0, 0.02, 0.05);
uniform float aberration = 0.0016;
uniform float grain = 0.03;
uniform float pulse = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r2 = dot(d * vec2(1.6, 1.0), d * vec2(1.6, 1.0));
	float ca = (aberration + pulse * 0.007) * r2 * 4.0;
	vec3 col;
	col.r = texture(screen, uv + d * ca).r;
	col.g = texture(screen, uv).g;
	col.b = texture(screen, uv - d * ca).b;
	float n = fract(sin(dot(uv * 1000.0 + vec2(TIME * 37.0, TIME * 91.0), vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain;
	float v = smoothstep(0.35, 0.95, length(d * vec2(1.25, 1.0)) * 1.3);
	col = mix(col, vignette_tint, v * vignette);
	col = mix(col, vec3(0.65, 0.03, 0.06), v * pulse * 0.45);
	COLOR = vec4(col, 1.0);
}
