// A brazier's fire for the Tidebreak ring (RingDressing): an upright camera-facing card with a toon flame on it. The card's
// origin is the base of the flame; its scale is the flame's size (x width, y height). One MultiMesh for every brazier: each
// flame's own seed comes from where it stands. Unshaded, its brightness into the glow through `intensity`.
// Round 4 (LOOKS; the ring's own fire matches the moves' fire, shaders/bend_fx/toon_flame + flame_field): the same banded
// palette (core, hot, mid, rim), the same field (two octaves through a domain warp, so its tongues lick and split), every
// edge soft (alpha over at least `soft`, never a hard cut), the tips breaking into embers, soft where it meets its bowl
// (the scene's depth), several tongues across the card each with its own phase.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform vec2 wind_direction;
global uniform float wind_strength;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float intensity = 3.0;
uniform float seed = 0.0;
uniform vec3 core : source_color = vec3(1.0, 0.93, 0.62);
uniform vec3 hot : source_color = vec3(1.0, 0.76, 0.2);
uniform vec3 mid : source_color = vec3(1.0, 0.48, 0.08);
uniform vec3 rim : source_color = vec3(0.86, 0.17, 0.05);
uniform float soft = 0.07;
uniform float warp = 0.45;
uniform float turb = 0.9;
uniform float speed = 2.1;
uniform float tongues = 3.0;
uniform float bowl_fade_m = 0.25;

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

// One tongue's field (the moves' flame_field with this card's value noise): `across` 0..1 over its width, `along` 0..1 up.
float tongue(float across, float along, float t, float sd, out float n2) {
	vec2 base = vec2(across * 1.1 + sd * 0.37, along * 1.3 + sd * 1.31);
	vec2 w = vec2(vnoise(base * 1.6 + vec2(0.0, -t * 0.55)), vnoise(base * 1.6 + vec2(5.3, 2.9 - t * 0.7))) - 0.5;
	vec2 q = base + w * warp * (0.4 + along);
	float n1 = vnoise(q * 2.4 + vec2(0.0, -t * 1.6));
	n2 = vnoise(q * vec2(5.0, 5.8) + vec2(4.1, -t * 2.9));
	float n = n1 * 0.62 + n2 * 0.38;
	float x = across * 2.0 - 1.0;
	x += (w.x * 1.2 + (n2 - 0.5) * 0.45) * along;
	float width = mix(1.0, 0.12, pow(along, 0.8));
	float body = 1.0 - abs(x) / width;
	return body * (1.15 - along) + (n - 0.5) * turb * (0.35 + along * 0.9) - along * 0.12;
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);                // y up
	float t = TIME * speed + v_seed;
	// the card's middle tongue, full height, and a shorter one either side, each its own phase
	float n2;
	float v = tongue(uv.x, uv.y, t, v_seed, n2);
	float k = clamp(tongues, 1.0, 3.0);
	if (k > 1.5) {
		float na;
		float l = tongue(clamp(uv.x * 1.9 + 0.08, 0.0, 1.0), clamp(uv.y / 0.72, 0.0, 1.0), t * 1.13, v_seed + 3.7, na) - step(0.72, uv.y);
		float r = tongue(clamp(uv.x * 1.9 - 0.98, 0.0, 1.0), clamp(uv.y / 0.66, 0.0, 1.0), t * 0.91, v_seed + 7.1, na) - step(0.66, uv.y);
		v = max(v, max(l, r) * 0.95);
	}
	v *= smoothstep(0.0, 0.08, uv.y) * 0.4 + 0.6;
	float o = 0.06;
	float w = max(min(fwidth(v), 0.12) * 1.2, soft);
	float a = smoothstep(o - w, o + w, v);
	// the tips break into embers rising faster than the flame
	float e = vnoise(vec2(uv.x * 9.0 + v_seed, uv.y * 7.0 - t * 3.2)) * 0.7 + vnoise(vec2(uv.x * 19.0, uv.y * 15.0 - t * 4.0)) * 0.45;
	float em = smoothstep(0.69, 0.76, e) * smoothstep(0.45, 0.8, uv.y) * smoothstep(-0.4, -0.06, v - o) * (1.0 - a);
	float bw = clamp(fwidth(v), 0.025, 0.1);
	vec3 col = rim;
	col = mix(col, mid, smoothstep(o + 0.12 - bw, o + 0.12 + bw, v));
	col = mix(col, hot, smoothstep(o + 0.3 - bw, o + 0.3 + bw, v));
	col = mix(col, core, smoothstep(o + 0.5 - bw, o + 0.5 + bw, v));
	col = mix(col, hot, em);
	float alpha = max(a, em);
	vec4 p = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).r, 1.0);
	alpha *= clamp((VERTEX.z - p.z / p.w) / max(bowl_fade_m, 1e-3), 0.0, 1.0);
	ALBEDO = col * intensity;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
