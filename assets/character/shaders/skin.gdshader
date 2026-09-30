// Character skin (body.glb: Body "skin").
//
// Tone. `melanin` (0..1) runs along 12 anchors in linear light ("Tone 1-12" in the UI;
// never named after an ancestry), `undertone` is an Oklab a/b offset (cool / neutral / warm
// / olive, body.json "skin"). The anchors are skin at average blood; `haemoglobin` (0..1,
// 0.5 = average) and the baked flush (COLOR.r: cheeks, nose, ears, lids, knuckles, knees)
// add or remove the absorption of blood in the dermis, seen through the epidermis: melanin
// screens it, so a flush shows less on darker skin (a two-layer absorption model, reduced
// to three bands; the flush keeps the brightness and shifts the hue). Weathering darkens and reddens the regions that are usually exposed.
//
// Detail. COLOR.g marks the mucosa (lip vermilion, inner lid rims): thin epidermis, less
// melanin, more visible blood, glossier. COLOR.b is a cavity occlusion baked from the head's
// SDF (nostrils, mouth seam, lid pockets, ears). COLOR.a is the beard mask for `stubble`.
// Pores and fine mottling come from the metre UVs and fade out with distance; `freckles`
// adds pheomelanin spots on the face.
//
// Creator styles (face_detail.gdshaderinc, head and upper neck only): `beard_style` (region
// weights: moustache, chin, jaw / cheeks, side whiskers) paints the short hair of a facial
// hair style and the skin under its shells (beard_shell.gdshader), `beard_density` thins it;
// `mark_scar` (1 brow, 2 cheek, 3 lip), `mark_pox` and `mark_paint` (vermilion cheek spots)
// are the Markings row.
//
// Hiding: UV2.x = region + 64 * zone. A vertex whose region bit is set in `hide_mask`
// (x: regions 0..31, y: 32..63) collapses to the origin in every pass (colour, depth,
// shadow): covered skin is never drawn and casts no shadow. `debug_view` 1 shows the
// regions, 2 the zones, 3 the COLOR channels (r flush, g mucosa, b occlusion).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, sss_mode_skin;
#include "res://shaders/common/canopy.gdshaderinc"

uniform uvec2 hide_mask = uvec2(0u, 0u);
uniform float melanin : hint_range(0.0, 1.0) = 0.3;
uniform vec2 undertone = vec2(0.0, 0.0);
uniform float haemoglobin : hint_range(0.0, 1.0) = 0.5;
uniform float weathering : hint_range(0.0, 1.0) = 0.3;
uniform float stubble : hint_range(0.0, 1.0) = 0.0;
uniform float freckles : hint_range(0.0, 1.0) = 0.0;
uniform vec3 hair_color : source_color = vec3(0.23, 0.15, 0.10);
uniform float roughness_base : hint_range(0.0, 1.0) = 0.58;
uniform float sss_strength : hint_range(0.0, 1.0) = 0.45;
// light the chest and shoulders bounce up under the chin: the neck's front (and any part facing down) lies in the
// chin's shadow and read half as bright as the chest; this lifts it by this much of its own colour
uniform float neck_bounce : hint_range(0.0, 1.0) = 0.22;
// the light there is to bounce, 0..1 (DayNight: the key light against the day's; 1 where no sky sets it): the bounce is
// an emission, so without it the neck glowed on its own in the dark (user 2026-09-29: "at night time the neck lights up")
global uniform float skin_bounce;
uniform float detail_strength : hint_range(0.0, 2.0) = 1.0;
uniform float albedo_scale : hint_range(0.5, 1.2) = 0.9;
uniform int debug_view = 0;
uniform vec4 beard_style = vec4(0.0);
uniform float beard_density : hint_range(0.0, 1.0) = 1.0;
uniform int mark_scar = 0;
uniform float mark_pox : hint_range(0.0, 1.0) = 0.0;
uniform float mark_paint : hint_range(0.0, 1.0) = 0.0;
uniform vec3 paint_color : source_color = vec3(0.80, 0.16, 0.10);
// 1 under a hair style with a centre parting (hair json "part": "centre"): the scalp under the
// cap is shaded with the hair's root colour and only a thin parting line stays skin (the
// caps' parting groove showed a centimetre-wide strip of bare scalp)
uniform float parting : hint_range(0.0, 1.0) = 0.0;
// Hair v3 strand styles (2026-09-28): the scalp under the hair tinted with the hair's root colour, so
// the skin between the strand strips reads as dense roots, not bald skin. `scalp_mask` is the style's
// domain (where its hair grows: the hairline, round the ears, the nape; a shaved forehead or crown
// left out) baked into the head's MakeHuman UV rectangle (head_detail_rect) by the hair build
// (tools/character/hair/_strands.py scalp_mask), soft over the hairline's few millimetres.
uniform float scalp_tint : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D scalp_mask : hint_default_black, filter_linear_mipmap, repeat_disable;
// Pubic hair (2026-09-28): the skin under its strips (body_hair_f / _m.glb) in the hair's colour, as the
// scalp under a style; `body_hair_mask` holds the patterns over MakeHuman's whole UV atlas (R women,
// G men; tools/character/body/body_hair.py), `body_hair_male` picks one, `body_hair` 0 when none shows.
uniform float body_hair : hint_range(0.0, 1.0) = 0.0;
uniform float body_hair_male : hint_range(0.0, 1.0) = 0.0;
uniform vec3 body_hair_color : source_color = vec3(0.18, 0.12, 0.08);
uniform sampler2D body_hair_mask : hint_default_black, filter_linear_mipmap, repeat_disable;
// The v3 head (2026-09-28): photographed skin detail (assets/character/body/head_detail.png from the
// MakeHuman skin textures, CC0; tools/character/mh_skin_detail.py) through the head's MakeHuman UVs
// (CUSTOM0; (-1, -1) off the head): R young detail, G redness, B older detail (wrinkles, blended in
// by `weathering`). It replaces the procedural pores on the head; the relief is a bump from the
// detail's screen-space gradient.
uniform int has_head_detail = 0;
uniform sampler2D head_detail : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 head_detail_rect = vec4(0.6372, 0.1784, 0.9975, 0.9921);
uniform float head_detail_strength : hint_range(0.0, 1.5) = 1.0;
// Body v4 (2026-09-28): the same photographed detail over the whole MakeHuman body (body_detail.png:
// MakeHuman's whole UV atlas, the channels as head_detail's; A: the areolae (about 0.55) and nipples
// (1), drawn by tools/character/mh_skin_detail.py). The areolae take a darker, warmer shade of the
// person's own tone and the nipples a little relief.
uniform int has_body_detail = 0;
uniform sampler2D body_detail : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float body_detail_strength : hint_range(0.0, 2.0) = 1.2;
varying vec2 v_mh;
// Skin sheen and light (2026-09-28, "human like skin"): the broad sheen's reflectance (0.5 = 4 %),
// the oil's sharper sheen (CLEARCOAT) and its roughness, the head's scattering (times the body's)
uniform float skin_specular : hint_range(0.0, 1.0) = 0.24;
uniform float oil_sheen : hint_range(0.0, 1.0) = 0.05;
uniform float oil_roughness : hint_range(0.0, 1.0) = 0.45;
uniform float head_sss : hint_range(0.5, 3.0) = 1.8;

#include "res://assets/character/shaders/face_detail.gdshaderinc"

varying flat uint v_region;
varying flat uint v_zone;
varying float v_ny;     // the vertex normal's height component in model space (-1 faces down)
varying float v_nz;     // ... and its forward component (+1 faces the way the body faces)
varying float v_tube;   // 1 on the head piece's neck tube (above the seam plane by less than 3 cm, within 7 cm of the neck's axis), else 0
varying float v_dseam;  // distance (m) from the head/body seam plane (z = 1.367 - 0.35 * forward; body v4): the detail maps' UV islands meet there
varying float v_h;      // model-space height (the neck's tone and detail blend along it, not step at the region borders)

#include "res://assets/character/shaders/skin_common.gdshaderinc"

void vertex() {
	uint code = uint(UV2.x + 0.5);
	v_region = code & 63u;
	v_zone = code >> 6u;
	v_mh = CUSTOM0.xy;
	v_h = VERTEX.y;
	v_ny = NORMAL.y;
	v_nz = NORMAL.z;
	float dsig = VERTEX.y - (1.367 - 0.35 * VERTEX.z);
	v_dseam = abs(dsig);
	v_tube = (1.0 - smoothstep(0.02, 0.04, dsig)) * (1.0 - smoothstep(0.060, 0.075, length(vec2(VERTEX.x, VERTEX.z - 0.009))));
	if (region_hidden(v_region)) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	float flush = COLOR.r;
	float mucosa = COLOR.g;
	float cavity = COLOR.b;
	// the neck: the occlusion baked into it from the old head (a dark step just above the seam, pale below it: a collar
	// band round the neck) does not fit the new neck; the engine's own occlusion shades it; the jaw and the ears keep theirs
	float nzf = (v_region == 1u || v_region == 2u) ? 1.0 : (v_region == 0u ? v_tube : 0.0);
	cavity = mix(cavity, mix(1.0, cavity, smoothstep(1.395, 1.43, v_h)), nzf);
	vec3 albedo = tone_at(melanin) * albedo_scale;
	albedo *= blood(haemoglobin, melanin);
	// the baked flush (cheeks, nose, ears, lids): redder at about the same brightness (the
	// dermis scatters more red back), screened by melanin
	float fl = flush * mix(1.0, 0.35, clamp(melanin, 0.0, 1.0));
	albedo *= mix(vec3(1.0), vec3(1.06, 0.89, 0.91), fl * 0.6);
	float w = v_region < 38u ? WEATHER[v_region] : 0.0;
	// the neck: exposure and detail grow smoothly from the collar bones to the jaw (2026-09-28: hard steps at the
	// region borders read as a pale ring round the neck)
	float wn = v_region == 0u ? 1.0 : ((v_region == 1u || v_region == 2u) ? smoothstep(1.30, 1.40, v_h) : 0.0);
	if (v_region == 1u || v_region == 2u) {
		w = 0.85 * smoothstep(1.27, 1.40, v_h);
	} else if (v_region == 0u) {
		// the head piece's own neck tube (region 0) takes the neck's gradient, not the head's full exposure
		w = mix(w, 0.85 * smoothstep(1.27, 1.40, v_h), v_tube);
		wn = mix(wn, smoothstep(1.30, 1.40, v_h), v_tube);
	}
	albedo *= mix(vec3(1.0), vec3(0.86, 0.78, 0.74), clamp(w * weathering, 0.0, 1.0));
	// freckles: pheomelanin spots over the exposed face
	if (freckles > 0.001 && v_region == 0u) {
		float f = smoothstep(0.66, 0.80, vnoise(UV * 720.0)) * smoothstep(0.30, 0.65, vnoise(UV * 60.0 + 7.0));
		albedo = mix(albedo, albedo * vec3(0.80, 0.64, 0.50), f * freckles * 0.8);
	}
	float rough = roughness_base;
	// folds: where face shapes add up to a sharp crease (alar crease, mouth corners) the
	// interpolated normal turns edge-on or away from the camera and the grazing Fresnel
	// reflects the sky as white flecks; keep the shading normal in the camera's half-space
	// and let the specular fade out at grazing view (a crease is occluded anyway)
	float nv = dot(NORMAL, VIEW);
	float spec_occ = smoothstep(0.0, 0.35, nv);
	if (nv < 0.2) {
		NORMAL = normalize(NORMAL + VIEW * (0.2 - nv));
	}
	// the v3 head's photographed detail
	float proc = 1.0;
	float pore = 1.0;
	// the photographed detail: the head's own map (finer) on the head, the body's elsewhere
	bool on_head = v_region <= 1u;
	vec4 d = vec4(0.5, 0.5, 0.5, 0.0);
	bool have = false;
	vec4 dh = vec4(0.5, 0.5, 0.5, 0.0);
	vec4 db = vec4(0.5, 0.5, 0.5, 0.0);
	bool has_h = false;
	bool has_b = false;
	if (wn > 0.0 && has_head_detail == 1) {
		vec2 duv = (v_mh - head_detail_rect.xy) / (head_detail_rect.zw - head_detail_rect.xy);
		if (duv.x >= 0.0 && duv.y >= 0.0 && duv.x <= 1.0 && duv.y <= 1.0) {
			dh = texture(head_detail, duv);
			has_h = true;
		}
	}
	if (wn < 1.0 && has_body_detail == 1 && v_mh.x >= 0.0 && v_mh.y >= 0.0) {
		db = texture(body_detail, v_mh);
		has_b = true;
	}
	if (has_h && has_b) {
		d = mix(db, dh, wn);
		have = true;
	} else if (has_h) {
		d = dh;
		have = true;
	} else if (has_b) {
		d = db;
		have = true;
	}
	if (have && (v_region == 1u || v_region == 2u)) {
		// the head's and the body's islands of the detail maps meet along the seam: their edge texels (padding) show as a
		// hairline round the neck; a narrow band round the seam takes the neutral detail instead
		d = mix(vec4(0.5, 0.5, 0.5, 0.0), d, smoothstep(0.002, 0.012, v_dseam));
	}
	float areola = 0.0;
	if (have) {
		proc = 0.0;
		float age = clamp((weathering - 0.3) * 1.3, 0.0, 0.85);
		float det = mix(d.r, d.b, age) * 2.0;
		float k = mix(body_detail_strength, head_detail_strength, wn) * (1.0 - 0.5 * mucosa);
		if (on_head) {
			// the photograph's scalp has hair roots in it (a shaved or plucked head read as
			// sandpaper): little of it above the hairline (face coordinates, v2 layout)
			vec2 sz = face_coords(UV);
			float sau = abs(sz.x);
			float shl = sau < 0.045 ? mix(1.556, 1.545, sau / 0.045)
					: (sau < 0.09 ? mix(1.545, 1.50, (sau - 0.045) / 0.045)
					: (sau < 0.15 ? mix(1.50, 1.45, (sau - 0.09) / 0.06) : mix(1.45, 1.41, clamp((sau - 0.15) / 0.06, 0.0, 1.0))));
			k *= mix(1.0, 0.3, smoothstep(shl, shl + 0.02, sz.y));
		} else {
			areola = d.a;
		}
		albedo *= mix(1.0, det, k);
		// the photograph's redness (a light skin's): less of it on darker skin, where melanin
		// screens the blood (it read as maroon)
		albedo *= 1.0 + k * vec3(0.16, -0.05, -0.05) * (d.g * 2.0 - 1.0) * mix(1.0, 0.35, clamp(melanin, 0.0, 1.0));
		pore = det;
		// the areola: a deeper, warmer shade of the person's own tone; the nipple a little darker still
		float ar = smoothstep(0.08, 0.5, areola);
		float nip = smoothstep(0.6, 0.95, areola);
		vec3 ar_col = tone_at(clamp(melanin + 0.16, 0.0, 1.0)) * albedo_scale * vec3(1.06, 0.9, 0.9);
		albedo = mix(albedo, ar_col * (1.0 - 0.15 * nip), ar * 0.8);
		// relief: a bump from the detail's screen-space gradient (works in any UV layout), the nipple raised
		float hgt = (det - 1.0) * 0.0005 * k + nip * 0.0018 + ar * 0.0003;
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		vec3 r1 = cross(dpdy, NORMAL);
		vec3 r2 = cross(NORMAL, dpdx);
		float dt = dot(dpdx, r1);
		vec3 grad = sign(dt) * (dFdx(hgt) * r1 + dFdy(hgt) * r2);
		NORMAL = normalize(abs(dt) * NORMAL - grad);
		rough += (1.0 - det) * 0.12 + 0.03;
	}
	// micro detail: pores and fine mottling from the metre UVs, faded out where a pixel
	// covers more than about one pore (no speckle or streaks at a distance); off where the
	// head's photographed detail applies
	vec2 uv = UV * 1400.0;
	float fine = proc * detail_strength * (1.0 - smoothstep(0.35, 1.2, length(fwidth(uv)))) * (1.0 - mucosa);
	float n1 = vnoise(uv);
	float n2 = vnoise(UV * 180.0);
	albedo *= 1.0 + proc * detail_strength * 0.035 * (n2 - 0.5) - fine * 0.025 * (n1 - 0.5);
	float e = 0.5;
	float nx = vnoise(uv + vec2(e, 0.0)) - vnoise(uv - vec2(e, 0.0));
	float ny = vnoise(uv + vec2(0.0, e)) - vnoise(uv - vec2(0.0, e));
	// a light relief: stronger reads as orange peel in the customizer's close-up
	NORMAL_MAP = normalize(vec3(-nx * 0.11 * fine, -ny * 0.11 * fine, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	// oilier T-zone and cheeks (the flush map covers nose and cheeks), drier elsewhere
	rough -= 0.06 * flush;
	// stubble (beard mask in COLOR.a)
	float beard = COLOR.a * stubble;
	if (beard > 0.001) {
		float dots = smoothstep(0.55, 0.85, vnoise(UV * 2500.0));
		albedo = mix(albedo, hair_color * 0.55, beard * (0.30 + 0.5 * dots));
		rough += 0.12 * beard;
	}
	// Face zones (face coordinates, the v2 layout): the thin skin under the eyes darker and cooler
	// (the orbit's shadow and the veins show through it), the lids and sockets a little darker, the
	// forehead a little yellower. Oil: the T-zone, the chin and the flushed cheeks shine more (the
	// sharper of the skin's two sheens, CLEARCOAT below).
	float oil = 0.25 + 0.45 * flush;
	if (v_region <= 1u) {
		vec2 fz = face_coords(UV);
		float au = abs(fz.x);
		float under = fd_band(au, 0.013, 0.045, 0.007) * fd_band(fz.y, 1.461, 1.477, 0.005);
		float socket = fd_band(au, 0.011, 0.049, 0.006) * fd_band(fz.y, 1.487, 1.508, 0.005);
		float forehead = fd_band(au, -1.0, 0.05, 0.015) * fd_band(fz.y, 1.527, 1.575, 0.01);
		float nose = fd_band(au, -1.0, 0.013, 0.004) * fd_band(fz.y, 1.442, 1.522, 0.006);
		float chin = fd_band(au, -1.0, 0.02, 0.006) * fd_band(fz.y, 1.372, 1.404, 0.005);
		float dark = mix(1.0, 1.4, clamp(melanin, 0.0, 1.0));
		albedo *= mix(vec3(1.0), vec3(0.85, 0.83, 0.9), clamp(under * 0.75 * dark, 0.0, 1.0));
		albedo *= mix(vec3(1.0), vec3(0.92, 0.89, 0.91), socket * 0.7);
		albedo *= mix(vec3(1.0), vec3(1.02, 1.0, 0.93), forehead * 0.5);
		oil = max(oil, max(max(forehead * 0.7, nose), chin * 0.7));
	}
	// creator styles on the head: the style's short hair, scars, pox, paint
	if (v_region <= 1u && (dot(beard_style, vec4(1.0)) > 0.0 || mark_scar > 0 || mark_pox > 0.001 || mark_paint > 0.001)) {
		vec2 fc = face_coords(UV);
		float bm = beard_mask(fc, beard_regions(fc, COLOR.a, mucosa), beard_style) * beard_density;
		if (bm > 0.001) {
			float dots = smoothstep(0.45, 0.8, vnoise(UV * 2500.0));
			albedo = mix(albedo, hair_color * 0.5, bm * (0.45 + 0.4 * dots));
			rough += 0.15 * bm;
		}
		vec3 mk = face_marks(fc, mark_scar, mark_pox, mark_paint);
		// scar: a paler, greyer line (less melanin; pink only on light skin, where the blood
		// shows), a little glossy, with a darker margin (the healed edges); reads on every tone
		// without the saturated orange of paint
		float margin = mk.x * (1.0 - mk.x) * 4.0;
		albedo *= 1.0 - 0.4 * margin;
		vec3 scar_col = tone_at(melanin * 0.72) * albedo_scale;
		float scar_l = dot(scar_col, vec3(0.2126, 0.7152, 0.0722));
		scar_col = mix(vec3(scar_l), scar_col, 0.45) * mix(vec3(1.12, 0.86, 0.88), vec3(1.0), clamp(melanin * 2.5, 0.0, 1.0));
		albedo = mix(albedo, scar_col, smoothstep(0.35, 1.0, mk.x) * 0.85);
		rough -= 0.2 * mk.x;
		// pox: shallow round pits, a shadowed rim round a paler floor (no relief: the marks are
		// albedo and roughness)
		float rim = mk.y * (1.0 - mk.y) * 4.0;
		albedo *= (1.0 - 0.26 * rim) * (1.0 + 0.07 * smoothstep(0.7, 1.0, mk.y));
		rough += 0.1 * mk.y;
		// vermilion (mercuric sulphide) over the skin, matte
		albedo = mix(albedo, paint_color, mk.z * 0.85);
		rough = mix(rough, 0.75, mk.z);
	}
	float hair_cover = 0.0;
	if (parting > 0.0 && v_region == 0u) {
		vec2 pc = face_coords(UV);
		// the groove (about 4 mm wide) from the front hairline (h about 1.54 on the midline) back,
		// so it shows no bar of bare forehead skin, and the scalp under the parted cap from a
		// little behind it; the line: under a millimetre either side of the midline
		float top = max(smoothstep(1.539, 1.543, pc.y) * (1.0 - smoothstep(0.003, 0.005, abs(pc.x))),
				smoothstep(1.542, 1.552, pc.y) * (1.0 - smoothstep(0.02, 0.03, abs(pc.x))));
		float line = (1.0 - smoothstep(0.0003, 0.0007, abs(pc.x))) * smoothstep(1.536, 1.548, pc.y);
		albedo = mix(albedo, hair_color * 0.55, top * (1.0 - line) * parting);
		albedo *= 1.0 - 0.45 * top * line * parting;
		// the scalp in the groove takes no sheen (it read as a pale bar down the parting)
		hair_cover = top * parting;
	}
	if (scalp_tint > 0.0 && v_region <= 1u) {
		vec2 suv = (v_mh - head_detail_rect.xy) / (head_detail_rect.zw - head_detail_rect.xy);
		if (suv.x >= 0.0 && suv.y >= 0.0 && suv.x <= 1.0 && suv.y <= 1.0) {
			// the roots: the hairline's fade broken into specks (single hairs), not a painted edge
			float n = vnoise(UV * 2200.0);
			float m = clamp(texture(scalp_mask, suv).r * 1.5 - 0.5 * n, 0.0, 1.0) * scalp_tint;
			albedo = mix(albedo, hair_color * (0.5 + 0.3 * n), m);
			hair_cover = max(hair_cover, m);
		}
	}
	if (body_hair > 0.0 && !on_head && v_mh.x >= 0.0 && v_mh.y >= 0.0) {
		// the roots: specks thinning toward the pattern's edge, not a painted patch
		vec2 bm = texture(body_hair_mask, v_mh).rg;
		float n = vnoise(UV * 2200.0);
		float m = clamp(mix(bm.r, bm.g, body_hair_male) * 1.4 - 0.55 * n, 0.0, 1.0) * body_hair * 0.85;
		albedo = mix(albedo, body_hair_color * (0.5 + 0.3 * n), m);
		hair_cover = max(hair_cover, m);
	}
	float sss = sss_strength;
	// mucosa: less melanin, more blood, glossier; darker skin keeps more pigment in the lips
	if (mucosa > 0.001) {
		vec3 lip = tone_at(melanin * 0.82 + 0.02) * albedo_scale * blood(0.5 + 0.55 + 0.25 * haemoglobin, melanin * 0.8);
		lip *= mix(vec3(1.0), vec3(0.92, 0.84, 0.90), clamp(melanin * 1.2 - 0.3, 0.0, 1.0));
		albedo = mix(albedo, lip, mucosa);
		rough = mix(rough, 0.44, mucosa);
	}
	// cavities: occluded, less specular
	albedo *= mix(0.62, 1.0, cavity);
	if (debug_view == 1) {
		albedo = region_color(v_region);
	} else if (debug_view == 2) {
		albedo = region_color(v_zone * 7u);
	} else if (debug_view == 3) {
		albedo = COLOR.rgb;
	}
	ALBEDO = albedo;
	ROUGHNESS = clamp(rough, 0.0, 1.0);
	// skin, not plastic: a lower specular on the head, broken up by the photographed detail
	// two sheens, as skin has: the broad one (skin_specular: skin's reflectance at normal incidence
	// is about 2.8 %) and a sharper one from the skin's oil (CLEARCOAT), strongest on the T-zone, broken by
	// the pores; neither in cavities, under hair or at grazing folds
	float shine = mix(0.3, 1.0, cavity) * spec_occ * (1.0 - hair_cover);
	SPECULAR = skin_specular * shine;
	CLEARCOAT = clamp(oil * oil_sheen * shine * mix(0.35, 1.0, clamp(pore * 1.2 - 0.2, 0.0, 1.0)) * (1.0 - 0.6 * beard), 0.0, 1.0);
	CLEARCOAT_ROUGHNESS = oil_roughness;
	AO = mix(0.35, 1.0, cavity);
	// (the bounce from the chest and the ground lands under the chin and on the throat, never on the nape: facing back,
	// the neck had glowed at the back in the dark)
	EMISSION = albedo * (neck_bounce * skin_bounce * nzf * (1.0 - smoothstep(-0.2, 0.6, v_ny)) * smoothstep(1.27, 1.33, v_h)
			* smoothstep(-0.5, 0.0, v_nz));
	AO_LIGHT_AFFECT = 0.35;
	// (less under hair: the light the strips let through reddened the hairline into a glowing band)
	SSS_STRENGTH = debug_view == 0 ? sss * (v_region <= 1u ? head_sss : 1.0) * (1.0 - 0.75 * hair_cover) : 0.0;
	// light through the thin parts of the head (the ears, the nostrils' wings): red, as blood
	// colours the light that crosses the skin. Set on every fragment: the defaults elsewhere (a zero
	// depth) turned the whole body below the head black.
	SSS_TRANSMITTANCE_COLOR = vec4(0.0);
	SSS_TRANSMITTANCE_DEPTH = 0.012;
	SSS_TRANSMITTANCE_BOOST = 0.0;
	if (v_region <= 1u && debug_view == 0) {
		SSS_TRANSMITTANCE_COLOR = vec4(1.0, 0.3, 0.16, 1.0) * mix(1.0, 0.45, clamp(melanin, 0.0, 1.0));
		SSS_TRANSMITTANCE_DEPTH = 0.012;
		SSS_TRANSMITTANCE_BOOST = 0.15;
	}
	// Under the forest canopy the same shade as the floor it stands on (canopy.gdshaderinc: the crowns take part of the sky
	// light and scatter some of the sun down; neutral without the forest light). Without it a body kept the open sky's
	// light under the trees and stood out lit in the shade (user 2026-09-30).
	float canopy_c = canopy_cover((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz);
	AO *= canopy_sky_factor(canopy_c, 1.0);
	EMISSION += ALBEDO * canopy_scatter(canopy_c, 1.0, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y) * AO;
}
