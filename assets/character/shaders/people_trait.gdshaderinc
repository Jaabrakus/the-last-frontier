// A world people's mark in the skin (the owner 2026-10-03: the game's own peoples, "yea lets test it";
// data/customizer/world_peoples.json, docs/peoples_world.md; BodyMaterials.set_trait sets these):
//   1 keelstone flecks (the Keelfolk): patches of crystal-dusted skin (a cool sheen that reads at a distance) set with
//     fine crystal specks that catch the light and glow a little in the people's colour (up close); two sizes, each
//     speck its own brightness
//   2 Form veins (the Etched): thin branching lines that glow, gathered in patches over the body
// Drawn in the body's UV space so they ride the skin as it moves (an island's seam only breaks a vein where a break reads
// as natural). The body's UV runs about a metre of skin per unit everywhere, the head too (0.74-1.36 m by region,
// measured 2026-10-04), so the scales below are per metre of skin. Specks finer than a pixel fade to their mean (no
// shimmer at a distance); a vein keeps its width in skin, never thinner than a pixel.
// Included by skin.gdshader and painted_skin.gdshader; call trait_shade() before the lips and cavities, add its result
// to EMISSION.

uniform int trait_kind = 0;
uniform float trait_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 trait_color : source_color = vec3(0.56, 0.84, 1.0);
uniform float trait_glow : hint_range(0.0, 8.0) = 1.0;

// cells per UV unit (about per metre of skin): a speck every few millimetres, veins a couple of centimetres apart
const float TRAIT_FLECK_SCALE = 220.0;
const float TRAIT_VEIN_SCALE = 42.0;
// a vein's width in UV (about 0.7 mm of skin)
const float TRAIT_VEIN_WIDTH = 0.0007;

float trait_h21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float trait_vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(trait_h21(i), trait_h21(i + vec2(1.0, 0.0)), u.x),
			mix(trait_h21(i + vec2(0.0, 1.0)), trait_h21(i + vec2(1.0, 1.0)), u.x), u.y);
}

// One layer of specks: a speck in some cells of a grid of `sc` cells per UV unit, kept inside its cell.
float trait_speck_layer(vec2 uv, float sc, float keep_share, float rad_k, float seed) {
	vec2 g = uv * sc;
	vec2 c = floor(g);
	vec2 f = fract(g);
	float px = length(fwidth(g));                  // cells per pixel: past ~0.7 a speck is under a pixel
	float keep = step(1.0 - keep_share, trait_h21(c * 1.37 + seed));
	vec2 at = 0.25 + 0.5 * vec2(trait_h21(c + seed * 3.1), trait_h21(c + seed * 5.7 + 11.0));
	float rad = rad_k * (0.55 + 0.45 * trait_h21(c + seed + 3.3));
	float d = length(f - at);
	float aa = max(px * 0.5, 0.01);
	float speck = keep * (1.0 - smoothstep(rad - aa, rad + aa, d)) * (0.5 + 0.5 * trait_h21(c + seed + 7.7));
	// too fine to draw: its mean over the cell instead
	float mean = keep_share * 3.14159 * rad * rad * 0.75;
	return mix(speck, mean, smoothstep(0.35, 0.9, px));
}

// x: the specks, y: the patch they lie in (0..1); `least` the least patch (the face is always dusted a little)
vec2 trait_flecks(vec2 uv, float amount, float least) {
	// in patches (a hand-span across), bare skin between; more of the skin with more amount
	float patchy = max(smoothstep(0.42 - 0.16 * amount, 0.70 - 0.14 * amount, trait_vn(uv * 6.0 + 4.0)), least);
	float a = trait_speck_layer(uv, TRAIT_FLECK_SCALE, 0.30 + 0.30 * amount, 0.16, 1.0);
	float b = trait_speck_layer(uv, TRAIT_FLECK_SCALE * 2.3, 0.30 + 0.30 * amount, 0.18, 7.0);
	return vec2(clamp(max(a, b * 0.75) * patchy, 0.0, 1.0), patchy);
}

// A thin line where noise `n` crosses its middle: `w` its half-width in UV, never under a pixel.
float trait_line(float n, vec2 uv, float w) {
	float fn = fwidth(n);
	float per_uv = fn / max(length(fwidth(uv)), 1e-7);
	float lw = max(fn * 0.6, per_uv * w);
	return 1.0 - smoothstep(lw * 0.5, lw * 1.5, abs(n - 0.5));
}

float trait_veins(vec2 uv, float amount) {
	vec2 p = uv * TRAIT_VEIN_SCALE;
	vec2 w = vec2(trait_vn(p * 0.45 + 3.1), trait_vn(p * 0.45 + 8.7)) - 0.5;
	float n = trait_vn(p + w * 2.4) * 0.62 + trait_vn(p * 2.3 + w * 1.3 + 5.0) * 0.38;
	float line = trait_line(n, uv, TRAIT_VEIN_WIDTH);
	// finer, fainter branches off the main lines
	float n2 = trait_vn(p * 3.1 + w * 3.0 + 17.0);
	float branch = trait_line(n2, uv, TRAIT_VEIN_WIDTH * 0.6) * 0.6 * (1.0 - smoothstep(0.0, 0.12, abs(n - 0.5)));
	float lines = max(line, branch);
	// in patches (a hand-span across): the veins gather in some places and fade out between, more with more amount
	float patchy = smoothstep(0.72 - 0.26 * amount, 0.90 - 0.22 * amount, trait_vn(uv * 5.0 + 21.0));
	return lines * patchy;
}

// The mark on `albedo` and `rough` (where `mask` > 0: not on the lips); returns the glow to add to EMISSION.
vec3 trait_shade(vec2 uv, uint region, float mask, inout vec3 albedo, inout float rough) {
	// (kinds 3-5 are the Thủy Vân peoples': tv_trait_shade, below)
	if (trait_kind == 0 || trait_kind >= 3 || trait_amount <= 0.001 || mask <= 0.001) {
		return vec3(0.0);
	}
	float a = trait_amount;
	// (the face a little quieter than the body: it is seen closest)
	float face = region <= 1u ? 0.75 : 1.0;
	if (trait_kind == 1) {
		// (the face always dusted a little: it is where a people is known first)
		vec2 fp = trait_flecks(uv, a, region <= 1u ? 0.65 * a : 0.0) * mask;
		vec3 crystal = mix(vec3(0.80, 0.90, 0.97), trait_color, 0.55);
		// the patch: a cool, glossier sheen of crystal dust (what reads from afar)
		float sheen = fp.y * (0.25 + 0.45 * a);
		albedo = mix(albedo, albedo * vec3(0.86, 0.95, 1.08) + crystal * 0.07, sheen);
		rough = mix(rough, 0.32, sheen);
		// the specks: crystal, glossy, glowing a little
		albedo = mix(albedo, crystal, fp.x * 0.7);
		rough = mix(rough, 0.08, fp.x);
		return trait_color * (fp.x * (0.35 + 0.65 * a) + fp.y * 0.05 * a) * trait_glow;
	}
	float v = trait_veins(uv, a) * mask;
	albedo = mix(albedo, trait_color * 0.85, v * 0.5);
	rough = mix(rough, 0.35, v);
	return trait_color * v * trait_glow * (0.35 + 0.65 * a) * face;
}

// The Thủy Vân peoples' kinds 3 scales, 4 plates, 5 river and the rite's ash marks (the callers add
// tv_trait_shade(UV, CUSTOM0.xy, region, mask, dot(NORMAL, VIEW), albedo, rough) after trait_shade)
#include "res://assets/thuyvan/shaders/tv_traits.gdshaderinc"
