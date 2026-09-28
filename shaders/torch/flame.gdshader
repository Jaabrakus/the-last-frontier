// Torch flame (TorchFire, push n01b): a camera-facing, upright teardrop of fire whose tongues are
// noise-distorted and rise, bent by the wind (the shared wind globals) and by the torch's own motion
// (`lean`). Used by the flame's core card and, per particle, by its tongues (COLOR = the particle's
// colour ramp, INSTANCE_CUSTOM.y = its age). Additive, unshaded; its brightness goes into the glow.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

global uniform vec2 wind_direction;
global uniform float wind_strength;

uniform float strength : hint_range(0.0, 1.0) = 1.0;   // the fire's size and brightness
uniform float intensity = 2.3;                           // HDR brightness at full fire
uniform vec3 lean = vec3(0.0);                           // world-space lean of the tip (m per m of height)
uniform float seed = 0.0;
uniform bool particle = false;                           // a tongue (particle) rather than the core

varying float v_age;

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

void vertex() {
	// upright billboard: the card turns about world Y to face the camera; its top bends with the lean and wind
	vec3 cam_right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z) + vec3(1e-4, 0.0, 0.0));
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	float h = VERTEX.y * sy + 0.5 * sy;          // 0 at the base, sy at the top (the card's origin is its middle)
	vec2 wd = normalize(wind_direction + vec2(1e-5));
	vec3 bend = lean + vec3(wd.x, 0.0, wd.y) * wind_strength * 0.35;
	vec3 wp = origin + cam_right * VERTEX.x * sx + vec3(0.0, VERTEX.y * sy, 0.0) + bend * h * h / max(sy, 0.01);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
	v_age = particle ? INSTANCE_CUSTOM.y : 0.0;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * 2.3 + seed;
	// rising noise: the tongues and the ragged top
	float n = vnoise(vec2(uv.x * 4.0 + seed, uv.y * 3.0 + t * 1.7)) * 0.6
			+ vnoise(vec2(uv.x * 9.0 - seed, uv.y * 7.0 + t * 3.1)) * 0.4;
	vec2 p = uv - vec2(0.5, 0.78);
	p.x += (n - 0.5) * 0.35 * (1.0 - uv.y);
	// teardrop: wide and round low, drawn to a point at the top
	float w = mix(0.12, 0.36, smoothstep(0.0, 0.85, uv.y));
	float body = 1.0 - smoothstep(0.0, 1.0, length(vec2(p.x / w, p.y * 1.25 / (0.8 + 0.4 * n))));
	body *= smoothstep(1.0, 0.82, uv.y);
	float core = 1.0 - smoothstep(0.0, 0.6, length(vec2(p.x / (w * 0.55), (uv.y - 0.72) * 3.2)));
	vec3 col;
	float a;
	if (particle) {
		col = COLOR.rgb;
		a = COLOR.a * body;
	} else {
		col = mix(vec3(1.0, 0.32, 0.06), vec3(1.0, 0.62, 0.26), smoothstep(0.1, 0.7, body));
		col = mix(col, vec3(1.0, 0.86, 0.6), core * 0.7);
		a = body;
	}
	ALBEDO = col * a * intensity * strength;
	ALPHA = 1.0;
}
