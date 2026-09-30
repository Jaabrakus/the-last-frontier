// Stylized, hand-painted skin (body.glb Body "skin" in the creator's Face style "Stylized"; the
// realistic one is skin.gdshader). The same skin model and uniforms as skin.gdshader (tone,
// undertone, blood, flush, weathering, creator styles and marks, hide mask), painted:
//
//   paint_head (head and upper neck, head UV space: lib/paint.py): R the painted value (light and
//     shade of the forms, 0.5 = the skin's own value), G the warm zone (cheeks, nose, ears, lids),
//     B the cool zone (jaw, chin, upper lip, temples), A the painted highlights
//   paint_lines: R painted expression lines, G their lit edge (`lines`, the Complexion row), B where
//     the realistic cavity occlusion (COLOR_0.b) applies (not round the eyes outside the lids)
//   UV2.y: the painted value of the rest of the skin per vertex (1 - value; neck, hands)
//
// The paint is a modulation of the person's own skin colour, in Oklab: lightness scaled by the
// painted value (the same relative change on every tone), shadows turning warmer and more
// saturated, lights a little cooler and paler, the zones shifting the hue by a share of the
// skin's own chroma. So every skin tone and every people is painted by the same rules; the
// tone itself (melanin, undertone, blood) is exactly the realistic one.
//
// No pores or micro relief (the painted look has none); a broad soft specular, SSS a little
// stronger than the realistic skin so the terminator stays soft (painted, not flat: the game's
// lights and shadows still model the forms).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert_wrap, specular_schlick_ggx, sss_mode_skin;

uniform uvec2 hide_mask = uvec2(0u, 0u);
uniform float melanin : hint_range(0.0, 1.0) = 0.3;
uniform vec2 undertone = vec2(0.0, 0.0);
uniform float haemoglobin : hint_range(0.0, 1.0) = 0.5;
uniform float weathering : hint_range(0.0, 1.0) = 0.3;
uniform float stubble : hint_range(0.0, 1.0) = 0.0;
uniform float freckles : hint_range(0.0, 1.0) = 0.0;
uniform vec3 hair_color : source_color = vec3(0.23, 0.15, 0.10);
uniform float roughness_base : hint_range(0.0, 1.0) = 0.62;
uniform float sss_strength : hint_range(0.0, 1.0) = 0.55;
uniform float albedo_scale : hint_range(0.5, 1.2) = 0.9;
uniform int debug_view = 0;
uniform vec4 beard_style = vec4(0.0);
uniform float beard_density : hint_range(0.0, 1.0) = 1.0;
uniform int mark_scar = 0;
uniform float mark_pox : hint_range(0.0, 1.0) = 0.0;
uniform float mark_paint : hint_range(0.0, 1.0) = 0.0;
uniform vec3 paint_color : source_color = vec3(0.80, 0.16, 0.10);
uniform float parting : hint_range(0.0, 1.0) = 0.0;
// the painted maps and how strongly they are laid on
uniform sampler2D paint_head : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D paint_lines : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec4 paint_rect = vec4(-0.251327, 0.251327, 1.335, 1.605);   // u0, u1, h0, h1 (lib/paint.py)
uniform float value_contrast : hint_range(0.0, 3.0) = 1.35;          // painted light and shade
uniform float zone_strength : hint_range(0.0, 2.0) = 1.0;            // warm and cool zones
uniform float highlight : hint_range(0.0, 2.0) = 1.0;                // painted highlights
uniform float lines : hint_range(0.0, 1.0) = 0.0;                    // expression lines (Complexion)
uniform float cool_male : hint_range(0.0, 1.0) = 0.0;                // the lower third cooler (body type 1)
// the mouth line's height in the head UV (the stomion, lib/face.mouth_landmarks): upper lip above
const float MOUTH_H = 1.4221;

#include "res://assets/character/shaders/face_detail.gdshaderinc"

varying flat uint v_region;
varying flat uint v_zone;
varying float v_body_value;

#include "res://assets/character/shaders/skin_common.gdshaderinc"

void vertex() {
	uint code = uint(UV2.x + 0.5);
	v_region = code & 63u;
	v_zone = code >> 6u;
	v_body_value = 1.0 - UV2.y;
	if (region_hidden(v_region)) {
		VERTEX = vec3(0.0);
	}
}

// Painted modulation of a linear skin colour: `v` painted value offset (-0.5..0.5), warm and cool
// zone weights, highlight. Same relative change for every tone.
vec3 paint_skin(vec3 c, float v, float warm, float cool, float high) {
	vec3 lab = lin_to_oklab(c);
	float chroma = max(length(lab.yz), 0.02);
	// value: a relative change of lightness
	lab.x *= 1.0 + v * 0.62;
	// shadows a little richer and rosier (never toward yellow), lights a little paler
	float sh = clamp(-v * 2.0, 0.0, 1.0);
	float li = clamp(v * 2.0, 0.0, 1.0);
	lab.yz *= 1.0 + 0.10 * sh - 0.10 * li;
	lab.yz += vec2(0.22, -0.02) * chroma * sh * 0.3;
	// zones: the warm middle rosier (toward red, not orange), the cool third a touch toward blue-grey
	// (a share of the skin's own chroma, so every tone shifts alike)
	lab.yz += vec2(0.55, -0.05) * chroma * warm * 0.30 * zone_strength;
	lab.yz += vec2(-0.30, -0.40) * chroma * cool * 0.22 * zone_strength;
	lab.x *= 1.0 - 0.03 * cool * zone_strength;
	// painted highlight: lighter, a touch less saturated
	lab.x *= 1.0 + 0.10 * high * highlight;
	lab.yz *= 1.0 - 0.12 * high * highlight;
	return oklab_to_lin(lab);
}

void fragment() {
	float flush = COLOR.r;
	float mucosa = COLOR.g;
	float cavity = COLOR.b;
	vec3 skin = tone_at(melanin) * albedo_scale;
	skin *= blood(haemoglobin, melanin);
	float fl = flush * mix(1.0, 0.35, clamp(melanin, 0.0, 1.0));
	skin *= mix(vec3(1.0), vec3(1.06, 0.89, 0.91), fl * 0.6);
	float w = v_region < 38u ? WEATHER[v_region] : 0.0;
	skin *= mix(vec3(1.0), vec3(0.86, 0.78, 0.74), clamp(w * weathering, 0.0, 1.0));
	// the paint
	float value = v_body_value;
	vec4 P = vec4(0.5, 0.0, 0.0, 0.0);
	vec2 Lm = vec2(0.0);
	float cav_mask = 1.0;
	vec2 fc = face_coords(UV);
	if (v_region <= 1u) {
		vec2 tc = vec2((fc.x - paint_rect.x) / (paint_rect.y - paint_rect.x), (paint_rect.w - fc.y) / (paint_rect.w - paint_rect.z));
		P = texture(paint_head, tc);
		vec3 pl = texture(paint_lines, tc).rgb;
		Lm = pl.rg * lines;
		cav_mask = pl.b;
		value = P.r;
	}
	float v = (value - 0.5) * value_contrast - 0.30 * Lm.x;
	// the cool lower third: a whisper for body type 2, more for body type 1 (in the game's warm grade a
	// strong one read as dirt)
	float cool = P.b * mix(0.12, 0.55, cool_male);
	vec3 albedo = paint_skin(skin, v, P.g, cool, clamp(P.a + 0.7 * Lm.y, 0.0, 1.0));
	// freckles: fewer, larger, soft painted dots
	if (freckles > 0.001 && v_region == 0u) {
		float f = smoothstep(0.62, 0.78, vnoise(UV * 360.0)) * smoothstep(0.30, 0.65, vnoise(UV * 45.0 + 7.0));
		albedo = mix(albedo, albedo * vec3(0.80, 0.66, 0.54), f * freckles * 0.75);
	}
	float rough = roughness_base - 0.05 * flush;
	// stubble (beard mask in COLOR.a): a painted shadow of the hair colour, no dots
	float beard = COLOR.a * stubble;
	if (beard > 0.001) {
		albedo = mix(albedo, hair_color * 0.6, beard * 0.42);
		rough += 0.1 * beard;
	}
	// creator styles on the head: the style's short hair painted as a soft tone, scars as a painted
	// pale stroke with a darker edge, pox as soft dots, paint
	if (v_region <= 1u && (dot(beard_style, vec4(1.0)) > 0.0 || mark_scar > 0 || mark_pox > 0.001 || mark_paint > 0.001)) {
		float bm = beard_mask(fc, beard_regions(fc, COLOR.a, mucosa), beard_style) * beard_density;
		if (bm > 0.001) {
			albedo = mix(albedo, hair_color * 0.55, bm * 0.62);
			rough += 0.15 * bm;
		}
		vec3 mk = face_marks(fc, mark_scar, mark_pox, mark_paint);
		float margin = mk.x * (1.0 - mk.x) * 4.0;
		albedo *= 1.0 - 0.45 * margin;
		vec3 scar_col = paint_skin(tone_at(melanin * 0.72) * albedo_scale, 0.08, 0.0, 0.0, 0.3);
		float scar_l = dot(scar_col, vec3(0.2126, 0.7152, 0.0722));
		scar_col = mix(vec3(scar_l), scar_col, 0.45) * mix(vec3(1.12, 0.86, 0.88), vec3(1.0), clamp(melanin * 2.5, 0.0, 1.0));
		albedo = mix(albedo, scar_col, smoothstep(0.35, 1.0, mk.x) * 0.85);
		float rim = mk.y * (1.0 - mk.y) * 4.0;
		albedo *= (1.0 - 0.22 * rim) * (1.0 + 0.06 * smoothstep(0.7, 1.0, mk.y));
		albedo = mix(albedo, paint_color, mk.z * 0.85);
		rough = mix(rough, 0.75, mk.z);
	}
	float hair_cover = 0.0;
	if (parting > 0.0 && v_region == 0u) {
		float top = max(smoothstep(1.539, 1.543, fc.y) * (1.0 - smoothstep(0.003, 0.005, abs(fc.x))),
				smoothstep(1.542, 1.552, fc.y) * (1.0 - smoothstep(0.02, 0.03, abs(fc.x))));
		float line = (1.0 - smoothstep(0.0003, 0.0007, abs(fc.x))) * smoothstep(1.536, 1.548, fc.y);
		albedo = mix(albedo, hair_color * 0.55, top * (1.0 - line) * parting);
		albedo *= 1.0 - 0.45 * top * line * parting;
		// the scalp in the groove takes no sheen (it read as a pale bar down the parting)
		hair_cover = top * parting;
	}
	// lips: the realistic mucosa colour, painted with the same value and a soft highlight
	if (mucosa > 0.001) {
		vec3 lip = tone_at(melanin * 0.82 + 0.02) * albedo_scale * blood(0.5 + 0.55 + 0.25 * haemoglobin, melanin * 0.8);
		lip *= mix(vec3(1.0), vec3(0.92, 0.84, 0.90), clamp(melanin * 1.2 - 0.3, 0.0, 1.0));
		// painted lips: a clear rosy tone a little deeper than the skin (the same relative change
		// for every tone), the upper lip (facing down) a shade darker than the lower one
		lip *= vec3(0.94, 0.80, 0.82);
		lip *= fc.y > MOUTH_H ? 0.86 : 1.04;
		lip = paint_skin(lip, v, 0.0, 0.0, P.a);
		albedo = mix(albedo, lip, mucosa);
		rough = mix(rough, 0.5, mucosa);
	}
	// cavities (nostrils, the mouth seam, the lid pockets): painted dark, softer than realistic;
	// only the small, deep creases (the cavity is baked on the realistic head, whose broad hollows under
	// the eyes and on the cheeks the stylized head smooths away: no painted blotches there)
	float cav = mix(1.0, smoothstep(0.10, 0.45, cavity), cav_mask);
	albedo *= mix(0.55, 1.0, cav);
	if (debug_view == 1) {
		albedo = region_color(v_region);
	} else if (debug_view == 2) {
		albedo = vec3(value);
	} else if (debug_view == 3) {
		albedo = P.rgb;
	}
	// the grazing-view guard of skin.gdshader (creases of combined shapes)
	float nv = dot(NORMAL, VIEW);
	float spec_occ = smoothstep(0.0, 0.35, nv);
	if (nv < 0.2) {
		NORMAL = normalize(NORMAL + VIEW * (0.2 - nv));
	}
	ALBEDO = albedo;
	ROUGHNESS = clamp(rough, 0.0, 1.0);
	SPECULAR = 0.28 * mix(0.3, 1.0, cav) * spec_occ * (0.75 + 0.5 * P.a) * (1.0 - hair_cover);
	AO = mix(0.45, 1.0, cav);
	AO_LIGHT_AFFECT = 0.3;
	SSS_STRENGTH = debug_view == 0 ? sss_strength : 0.0;
}
