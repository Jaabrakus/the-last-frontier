// Light thrown back off the tank's water onto its walls and the deck's plinth (RingDressing): quads on the stone just
// above the water. UV.x runs along the wall in metres, UV.y the height over the water in metres. A moving net of bright
// cells (two layers of cellular noise), strongest at the waterline and gone a metre up; added over the stone. `strength`
// and `tint` follow the light (RingLook: crisp at noon, warm and faint at golden hour, nearly none at night).
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float strength = 0.6;
uniform vec3 tint : source_color = vec3(0.75, 0.95, 1.0);
uniform float reach_m = 0.9;

vec2 h22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// the distance to the nearest cell edge (F2 - F1)
float cells(vec2 p, float t) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = h22(i + g);
			o = 0.5 + 0.45 * sin(t + 6.2831 * o);
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return d2 - d1;
}

void fragment() {
	vec2 p = vec2(UV.x, UV.y * 1.6);
	float t = TIME * 0.9;
	// two nets of light drifting against each other; only where both are bright does a clean blob of light show
	float c1 = 1.0 - smoothstep(0.0, 0.16, cells(p * 1.1 + vec2(t * 0.12, 0.0), t));
	float c2 = 1.0 - smoothstep(0.0, 0.2, cells(p * 1.7 - vec2(t * 0.07, 0.0), t * 1.3));
	float c = c1 * c2 * 1.4 + c1 * 0.25;
	c = smoothstep(0.3, 0.6, c);
	float fade = 1.0 - smoothstep(0.0, reach_m, UV.y);
	fade *= fade;
	fade *= smoothstep(0.0, 0.05, UV.y);
	ALBEDO = tint * c * fade * strength;
}
