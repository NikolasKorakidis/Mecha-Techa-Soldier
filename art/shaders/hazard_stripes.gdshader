// Scrolling diagonal hazard stripes (WARNING bands), with soft ends so the band fades out.
shader_type canvas_item;

uniform vec4 stripe : source_color = vec4(0.86, 0.12, 0.16, 1.0);
uniform vec4 gap : source_color = vec4(0.05, 0.02, 0.03, 0.85);
uniform float density = 26.0;
uniform float speed = 0.35;
uniform float direction = 1.0;

void fragment() {
	float x = UV.x * density + UV.y * 1.2 * (1080.0 / 1920.0) * density * 0.35 - TIME * speed * direction * density * 0.2;
	float s = step(0.5, fract(x));
	vec4 col = mix(gap, stripe, s);
	float ends = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	COLOR = vec4(col.rgb, col.a * ends);
}
