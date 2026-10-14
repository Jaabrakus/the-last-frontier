// The Thủy Vân peoples' marks in the skin (peoples_design 2.4; data/thuyvan_art/traits.json; built and previewed by
// tools/thuyvan_art/traits/). Included by people_trait.gdshaderinc, so skin.gdshader and painted_skin.gdshader both draw
// it; they call tv_trait_shade() right after trait_shade(), before the lips and cavities.
//   3 scales (Dragon-Sea): small arched scales in offset rows (9 x 7.5 mm on the body, 6 x 5 mm on the face) in
//     patches that grow with the amount (wrists -> temples and cheekbones -> shoulders and collarbones -> outer
//     forearms -> along the spine -> outer thighs), each with a darker rim and a thin-film sheen that turns teal ->
//     violet -> gold as the skin turns from the view; a patch's edge (0.15 of the amount wide) breaks up scale by
//     scale, so the patches read as scattered scales thickening inward, not painted shapes
//   4 plates (Stone Children): mineral plates (about 18 per metre, 34 on the face) with fine cool cracks, a lighter
//     rim inside each edge, a value jitter per plate and a pale quartz speck in one crack of twelve; 78 % of the tone
//     over the person's own skin, so every skin shows through; never the lips, lids, palms or inner elbows
//   5 river (Riverborn): broad wet patches (roughness to 0.38), small scale patches at the temples, collarbones and
//     outer forearms, and three painted gill slits a side behind the jaw (always, above amount 0.1); `tv_wet` widens
//     the slits a little at 0.5 Hz in water
// and, for anyone, the Ancestor-Bound rite's pale ash marks (a marking: `tv_ash` thumbprint, cheeks, hands).
// Where each mark appears first is an ORDER MAP in the body's MakeHuman UVs (CUSTOM0.xy: the one atlas whose islands
// never overlap): a texel is marked where its order < the amount. The maps are assets/thuyvan/character/traits/
// (trait_maps.py). The scales are drawn here from the metre UVs (UV), the same maths as trait_maps.scale_cell.
// Visual only: nothing here is a stat.

uniform sampler2D tv_trait_order : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D tv_trait_detail : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D tv_ash_marks : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform vec3 tv_ash = vec3(0.0);            // thumbprint, cheek fingers, backs of the hands (0..1 each)
uniform float tv_wet : hint_range(0.0, 1.0) = 0.0;

const vec2 TV_SCALE_CELL = vec2(0.009, 0.0075);
const vec2 TV_SCALE_CELL_FACE = vec2(0.0062, 0.0052);

// The metre UVs' v runs toward the trunk on the arms and legs: flip it there so every scale's free edge faces down
// the limb (regions: lib/regions.py; the hands and feet keep theirs).
float tv_v_sign(uint r) {
	bool arm = (r >= 14u && r <= 18u) || (r >= 20u && r <= 24u);
	bool leg = (r >= 26u && r <= 30u) || (r >= 32u && r <= 36u);
	return (arm || leg) ? -1.0 : 1.0;
}

// x: covered by a scale's body, y: toward its free rim (0..1), z: the scale's hash.
vec3 tv_scale_cell(vec2 uv, vec2 cell) {
	vec2 g = uv / cell;
	float best_row = -1e9;
	float best_d = 9.0;
	float best_h = 0.0;
	float row0 = floor(g.y);
	for (int dr = -1; dr <= 1; dr++) {
		float r = row0 + float(dr);
		float off = mod(r, 2.0) > 0.5 ? 0.5 : 0.0;
		float cx0 = floor(g.x - off);
		for (int dc = 0; dc <= 1; dc++) {
			float cx = cx0 + float(dc) + off;
			float d = length(vec2((g.x - cx) / 0.62, (g.y - (r + 0.15)) / 1.05));
			if (d < 1.0 && g.y >= r - 0.2 && r > best_row) {
				best_row = r;
				best_d = d;
				best_h = hash12(vec2(cx, r));
			}
		}
	}
	float cover = best_d < 1.0 ? 1.0 : 0.0;
	float rim = clamp((best_d - 0.62) / 0.38, 0.0, 1.0) * cover;
	// finer than a pixel: the cell's mean instead (no shimmer at a distance)
	float far = smoothstep(0.35, 0.9, length(fwidth(g)));
	return vec3(mix(cover, 0.85, far), mix(rim, 0.35, far), best_h);
}

// The thin film's colour as the skin turns from the view (1 - N.V): teal -> violet -> gold.
vec3 tv_film(float ndv) {
	float f = clamp(1.0 - ndv, 0.0, 1.0);
	vec3 teal = vec3(0.20, 0.72, 0.70);
	vec3 violet = vec3(0.52, 0.38, 0.86);
	vec3 gold = vec3(0.96, 0.78, 0.36);
	return f < 0.5 ? mix(teal, violet, f * 2.0) : mix(violet, gold, (f - 0.5) * 2.0);
}

// One scale layer over `albedo` and `rough`: `order` its order map value, `amt` the amount, `share` of the tone.
void tv_scales(vec2 uv, uint region, float order, float amt, float share, vec2 cell, float ndv, float sheen_v,
		float mask, inout vec3 albedo, inout float rough) {
	float feather = clamp((amt - order) / 0.15, 0.0, 1.0) * mask;
	if (feather <= 0.0) {
		return;
	}
	vec3 s = tv_scale_cell(vec2(uv.x, uv.y * tv_v_sign(region)), cell);
	float show = s.x * step(s.z, feather * 1.08);
	vec3 body = mix(albedo, trait_color * 1.25, share);
	vec3 sc = body * (1.0 + 0.18 * (1.0 - s.y));
	sc *= 1.0 - 0.45 * smoothstep(0.55, 1.0, s.y);
	sc += tv_film(ndv) * 0.22 * (1.0 - 0.6 * s.y) * (0.6 + 0.4 * sheen_v) * trait_color * 1.6;
	float k = show * (0.55 + 0.45 * feather);
	albedo = mix(albedo, sc, k);
	rough = mix(rough, 0.30, k);
}

// The Thủy Vân marks. `uv` the metre UVs (UV), `mh` the MakeHuman UVs (CUSTOM0.xy), `mask` 0 on the lips, `ndv` the
// view's cosine (dot(NORMAL, VIEW)). Returns the glow to add to EMISSION (none today: these marks do not glow).
vec3 tv_trait_shade(vec2 uv, vec2 mh, uint region, float mask, float ndv, inout vec3 albedo, inout float rough) {
	if (mh.x < 0.0) {
		return vec3(0.0);
	}
	vec4 ord = texture(tv_trait_order, mh);
	vec4 det = texture(tv_trait_detail, mh);
	float a = trait_amount;
	bool face = region <= 1u;
	if (trait_kind == 3 && a > 0.001) {
		tv_scales(uv, region, ord.r, a, face ? 0.50 : 0.62, face ? TV_SCALE_CELL_FACE : TV_SCALE_CELL, ndv, det.a, mask, albedo, rough);
	} else if (trait_kind == 4 && a > 0.001) {
		float on = step(ord.g, a) * step(ord.g, 0.995) * mask;
		if (on > 0.0) {
			float e = det.r * 0.0255;                        // metres from the crack
			float fw = max(fwidth(e), 1e-5);
			vec3 plate = mix(albedo, trait_color, 0.82) * (1.0 + (det.g - 0.5) * 0.16);
			float rim = smoothstep(0.0045, 0.0015, e) * smoothstep(0.0007, 0.0016, e);
			plate *= 1.0 + 0.16 * rim;
			float crack = 1.0 - smoothstep(0.0006, max(0.0013, 0.0006 + 1.5 * fw), e);
			plate = mix(plate, trait_color * 0.22 + vec3(0.004, 0.006, 0.012), crack);
			float quartz = step(det.g, 0.083) * step(0.0013, e) * step(e, 0.0020) * step(0.74, det.a);
			plate = mix(plate, vec3(0.74, 0.79, 0.82), quartz);
			plate *= 0.92 + 0.12 * smoothstep(0.0, 0.012, e);
			albedo = mix(albedo, plate, on);
			rough = mix(rough, 0.80, on);
		}
	} else if (trait_kind == 5) {
		float wet = clamp((a - ord.b) / 0.12, 0.0, 1.0) * mask;
		albedo = mix(albedo, mix(albedo, vec3(0.69, 0.78, 0.78), 0.5), 0.18 * wet);
		rough = mix(rough, 0.38, wet);
		tv_scales(uv, region, ord.a, a, 0.38, TV_SCALE_CELL * 0.55, ndv, det.a, mask, albedo, rough);
		if (a > 0.1) {
			float g = det.b * (1.0 + 0.25 * tv_wet * (0.5 + 0.5 * sin(TIME * 3.14159)));
			float core = smoothstep(0.6, 0.95, g);
			float lip = smoothstep(0.15, 0.4, g) * (1.0 - core);
			albedo = mix(albedo, vec3(0.25, 0.066, 0.095) * 0.7 + albedo * 0.1, core);
			albedo *= 1.0 + 0.30 * lip;
		}
	}
	// the rite's ash (a marking anyone may wear)
	if (dot(tv_ash, vec3(1.0)) > 0.0) {
		vec4 am = texture(tv_ash_marks, mh);
		float ash = max(max(am.r * tv_ash.x, am.g * tv_ash.y), am.b * tv_ash.z) * 0.78;
		// pale ash on a deep skin, a grey ash on a light one (it reads on every tone)
		float lum = dot(albedo, vec3(0.2126, 0.7152, 0.0722));
		vec3 ash_col = mix(vec3(0.62, 0.59, 0.54), vec3(0.20, 0.19, 0.17), smoothstep(0.12, 0.45, lum));
		albedo = mix(albedo, ash_col * (0.85 + 0.25 * am.a), ash);
		rough = mix(rough, 0.92, ash);
	}
	return vec3(0.0);
}
