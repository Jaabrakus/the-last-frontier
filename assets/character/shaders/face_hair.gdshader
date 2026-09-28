// Brows and lashes (body.glb Face surface "face_hair"): cards on the skin and along the lid
// margins, drawn as strands with alpha scissor. UV2.x = region + 64 * zone: zone 0 brows,
// zone 1 lashes. UV: brows u = 0 at the inner end .. 1 at the tail, v = 0 bottom .. 1 top
// of the card; lashes u = along the margin (0 medial .. 1 lateral), v = root (0) .. tip (1).
// (The exporter wrote v as 1 - v.) Alpha blended over the skin (2026-09-28; alpha scissor before).
//
// Brow shape per person: `brow_thickness` (height), `brow_arch` (lift of the arch toward
// the tail), `brow_density`. Close up the brows are strands (the inner hairs point up, the
// rest sweep toward the tail); at a distance the strands fade into their average coverage,
// so the brows never sparkle.
//
// `stylized` 1 (the creator's Stylized face style): painted brows and lashes: the brow one clean
// bold shape (the same thickness, arch and density) with a softer head, a dark body and a lighter
// tail; the upper lashes a short painted band hugging the lid, fuller toward the outer corner
// (COLOR_0.g = 1); the lower lashes (COLOR_0.g = 0) are not drawn (the skin paints the lid line).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform uvec2 hide_mask = uvec2(0u, 0u);
uniform vec3 brow_color : source_color = vec3(0.12, 0.08, 0.05);
uniform vec3 lash_color : source_color = vec3(0.04, 0.03, 0.025);
uniform float brow_thickness : hint_range(0.2, 1.4) = 0.7;
uniform float brow_arch : hint_range(0.0, 1.0) = 0.5;
uniform float brow_density : hint_range(0.2, 1.0) = 0.8;
uniform float lash_length : hint_range(0.5, 1.2) = 0.85;
uniform int stylized = 0;

varying flat uint v_zone;
varying float v_upper;          // 1 on the upper lashes, 0 on the lower (COLOR_0.g)

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	uint code = uint(UV2.x + 0.5);
	uint r = code & 63u;
	v_zone = code >> 6u;
	v_upper = COLOR.g;
	if (stylized == 1 && v_zone == 0u) {
		// the painted brow a little off the skin: the stylized brow ridge must not show through it
		VERTEX += NORMAL * 0.0005;
	}
	uint bits = r < 32u ? (hide_mask.x >> r) : (hide_mask.y >> (r - 32u));
	if ((bits & 1u) != 0u) {
		VERTEX = vec3(0.0);
	}
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 w = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), w.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), w.x), w.y);
}

// A brow as hair on skin (2026-09-28; the thin strands before averaged to a flat painted shape at
// any distance the creator shows): a soft body, feathered most along its top edge and at its head,
// thinner toward the tail; the hairs streaks about half a millimetre apart that turn from up (the
// head) to along the brow, fading into their average where a pixel covers several.
float brow_alpha(vec2 uv) {
	float u = uv.x;
	float v = uv.y;
	// centre line and half height along the brow (head, body, tapering tail)
	float vc = 0.46 + (brow_arch - 0.5) * 0.30 * sin(3.14159 * clamp(u / 0.75, 0.0, 1.0) * 0.5) - 0.10 * smoothstep(0.7, 1.0, u);
	float h = brow_thickness * mix(0.52, 0.17, smoothstep(0.15, 1.0, u)) * smoothstep(-0.06, 0.10, u) * (1.0 - smoothstep(0.9, 1.0, u));
	float d = (v - vc) / max(h, 1e-4);
	float body = 1.0 - smoothstep(0.4, 1.15, abs(d) * (d > 0.0 ? 1.15 : 1.0));
	body *= smoothstep(-0.02, 0.14, u);
	// the hairs
	float ang = mix(1.25, 0.22, smoothstep(0.0, 0.32, u)) + 0.25 * (d > 0.0 ? -1.0 : 1.0) * smoothstep(0.2, 1.0, abs(d)) * step(0.3, u);
	vec2 q = vec2(u * 9.0, v * 2.2);
	vec2 dir = vec2(cos(ang), sin(ang));
	vec2 perp = vec2(-dir.y, dir.x);
	vec2 hq = vec2(dot(q, perp) * 18.0, dot(q, dir) * 1.8);
	float hairs = smoothstep(0.38, 0.72, vnoise(hq) * 0.75 + vnoise(hq * vec2(2.3, 1.7) + 5.0) * 0.25);
	float far = smoothstep(0.5, 1.6, length(fwidth(hq)));
	float tex = mix(hairs, 0.6, far);
	float dens = brow_density * mix(0.6, 1.0, smoothstep(0.02, 0.22, u)) * mix(1.0, 0.75, smoothstep(0.65, 1.0, u));
	// uneven density: patches a few millimetres across
	dens *= 0.8 + 0.4 * vnoise(q * 3.0 + 11.0);
	return clamp(body * mix(0.5, 1.0, tex) * dens * 1.3, 0.0, 1.0);
}

float lash_alpha(vec2 uv) {
	float n = 90.0;
	float x = uv.x * n;
	float id = floor(x);
	float jitter = hash12(vec2(id, 1.0));
	float len = (0.65 + 0.35 * jitter) * lash_length;
	float w = 0.13 * (1.0 - 0.85 * uv.y / max(len, 0.01));
	float c = 0.5 + (jitter - 0.5) * 0.4 + uv.y * (hash12(vec2(id, 5.0)) - 0.5) * 0.8;
	float lash = step(abs(fract(x) - c), w) * step(uv.y, len);
	float fw = length(fwidth(vec2(x, uv.y * 6.0)));
	return mix(lash, 0.45 * (1.0 - uv.y), smoothstep(0.4, 1.5, fw));
}

// The painted brow: one clean, bold shape (the thickness, arch and density of the strand brows,
// drawn a little fuller: the painted brow frames the eye), its body full, its tail tapering; the
// upper edge waves very slightly (a sculpted edge, not a row of clumps).
float brow_alpha_painted(vec2 uv) {
	float u = uv.x;
	float v = uv.y;
	float vc = 0.46 + (brow_arch - 0.5) * 0.30 * sin(3.14159 * clamp(u / 0.75, 0.0, 1.0) * 0.5) - 0.10 * smoothstep(0.7, 1.0, u);
	float h = brow_thickness * 1.3 * mix(0.36, 0.13, smoothstep(0.15, 1.0, u)) * smoothstep(-0.04, 0.05, u) * (1.0 - smoothstep(0.92, 1.0, u));
	float wave = 1.0 + 0.05 * sin(u * 17.0 + 0.6);
	float inside = 1.0 - smoothstep(h * wave * 0.86, h * wave, abs(v - vc));
	// a rounded head (not a square end)
	float hu = max(0.09 - u, 0.0) / 0.09;
	float hv = (v - vc) / max(h, 1e-4);
	inside *= 1.0 - smoothstep(0.8, 1.0, hu * hu + hv * hv * step(0.0, 0.09 - u));
	return inside * mix(0.6, 1.0, brow_density);
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float a;
	vec3 col;
	if (stylized == 1 && v_zone == 0u) {
		a = brow_alpha_painted(uv);
		// painted: a softer head, a dark body, a lighter tail, a few long strokes along the brow and
		// a little light along its upper edge
		float strokes = sin(uv.y * 40.0 + sin(uv.x * 9.0) * 2.0) * 0.5 + 0.5;
		col = brow_color * mix(1.15, 0.9, smoothstep(0.05, 0.35, uv.x)) * mix(1.0, 1.2, smoothstep(0.6, 1.0, uv.x));
		col *= 0.92 + 0.12 * strokes;
		col *= 0.9 + 0.2 * smoothstep(0.35, 0.65, uv.y);
	} else if (stylized == 1) {
		// upper lashes: one painted dark band hugging the lid, thin at the inner corner, fuller toward
		// the outer corner with a short flick; the lower lashes are left to the painted lid line
		float t = uv.x;
		float len = lash_length * mix(0.16, 0.42, smoothstep(0.05, 0.8, t)) * (1.0 + 0.45 * smoothstep(0.82, 0.97, t));
		a = step(uv.y, len) * smoothstep(0.03, 0.08, t) * (1.0 - smoothstep(0.96, 1.0, t)) * step(0.5, v_upper);
		col = lash_color * 0.7;
	} else if (v_zone == 0u) {
		a = brow_alpha(uv);
		col = brow_color * (0.85 + 0.3 * vnoise(vec2(uv.x * 160.0, uv.y * 30.0)));
	} else {
		a = lash_alpha(uv);
		col = lash_color;
	}
	ALBEDO = col;
	// blended, not cut at a threshold: the strands and the brows' soft edges keep their coverage
	// (cut, a brow read as a drawn line)
	ALPHA = a;
	ROUGHNESS = 0.6;
	SPECULAR = 0.3;
}
