// A brazier's fire for the Tidebreak ring (RingDressing): an upright camera-facing card with a toon flame on it, its
// tongues noise-cut and rising, in three hard bands (a pale core, orange, a red rim) so it reads clean beside cel
// shading. Opaque (alpha scissor), unshaded, its brightness into the glow through `intensity`. The card's origin is
// the base of the flame; its scale is the flame's size (x width, y height). One MultiMesh for every brazier: each
// flame's own seed comes from where it stands.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque, fog_disabled;

global uniform vec2 wind_direction;
global uniform float wind_strength;

uniform float intensity = 3.0;
uniform float seed = 0.0;
uniform vec3 core : source_color = vec3(1.0, 0.93, 0.62);
uniform vec3 mid : source_color = vec3(1.0, 0.56, 0.12);
uniform vec3 rim : source_color = vec3(0.86, 0.17, 0.05);

varying float v_seed;

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
	vec3 cam_right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z) + vec3(1e-4, 0.0, 0.0));
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_seed = seed + origin.x * 0.731 + origin.z * 1.317;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	float h = VERTEX.y * sy;                         // the card runs from y 0 (base) to 1 (tip)
	vec2 wd = normalize(wind_direction + vec2(1e-5));
	vec3 bend = vec3(wd.x, 0.0, wd.y) * wind_strength * 0.3;
	vec3 wp = origin + cam_right * VERTEX.x * sx + vec3(0.0, h, 0.0) + bend * h * h / max(sy, 0.01);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);                // y up
	float sd = v_seed;
	float t = TIME * 2.1 + sd;
	float n = vnoise(vec2(uv.x * 3.5 + sd, uv.y * 2.6 - t * 1.6)) * 0.62
			+ vnoise(vec2(uv.x * 8.0 - sd, uv.y * 6.0 - t * 2.9)) * 0.38;
	// a teardrop, wide at the base, pulled up into licking tongues
	float x = (uv.x - 0.5) * 2.0;
	x += (n - 0.5) * 0.7 * uv.y;
	float w = mix(0.95, 0.05, pow(uv.y, 0.8));
	float f = 1.0 - abs(x) / max(w, 0.02);
	f *= smoothstep(0.0, 0.12, uv.y);
	f -= (1.0 - n) * uv.y * 0.9;                     // the top torn into tongues
	if (f < 0.08) {
		discard;
	}
	vec3 col = f > 0.55 ? core : (f > 0.28 ? mid : rim);
	ALBEDO = col * intensity;
}
