// Foam where the tank's water meets stone (RingDressing): a band laid on the water along the tank's walls and round
// the deck's plinth. UV.x runs along the band in metres, UV.y 0 at the stone .. 1 at the band's open edge. A crisp
// white line hugging the stone, broken lacy foam behind it, and rings of foam lapping outward and fading. Drawn after
// the water (render_priority), lit (it is not a light).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert, specular_disabled;

uniform vec3 foam_color : source_color = vec3(0.93, 0.97, 1.0);
uniform float opacity = 0.85;
uniform float speed = 0.22;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float t = TIME * speed;
	float x = UV.x;
	float y = UV.y;
	float n1 = vnoise(vec2(x * 1.7, y * 3.0 - t * 2.0));
	float n2 = vnoise(vec2(x * 5.3 + 11.0, y * 7.0 - t * 3.3));
	float n = n1 * 0.6 + n2 * 0.4;
	// the line against the stone, a little ragged
	float line_ = step(y, 0.1 + 0.08 * n2);
	// lacy foam behind it, thinning out
	float lace = step(0.52 + y * 0.55, n) ;
	// rings lapping outward
	float ring = fract(y * 2.2 - t * 1.4 + n1 * 0.5);
	float lap = step(ring, 0.16) * step(0.42, n2 + 0.2) * (1.0 - smoothstep(0.35, 0.95, y));
	float a = max(line_, max(lace, lap * 0.8));
	a *= 1.0 - smoothstep(0.75, 1.0, y);
	if (a < 0.02) {
		discard;
	}
	ALBEDO = foam_color;
	ALPHA = a * opacity;
	ROUGHNESS = 0.8;
}
