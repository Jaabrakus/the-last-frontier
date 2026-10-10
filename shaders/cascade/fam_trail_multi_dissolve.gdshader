// Spellbreak (Proletariat) MercilessLunge_Trail_MultiDissolve_Emissive_FxM family: Cloudburst / Ascension
// ribbon trails (46 ribbon emitters, 68 instances: MercilessLunge, ArcaneCurse, DeathlyDescent, HolyLight,
// SwamOfDarkness, OxidizedMissile, RebelliousSpirit, ...). Root:
//   /Game/VFX/Cosmetics/CloudBurst/MercilessLunge/MercilessLunge_Trail_MultiDissolve_Emissive_FxM
//   BLEND_Translucent, MSM_Unlit, two-sided, used with sprites / beam-trails / mesh particles.
//
// SOURCE (cooked parameter nodes, switches, function shells; values filled per instance by the JSON):
//   textures "Erosion Texture" + "EmissiveTexture" (group "Masked Emissive"); channel masks
//   "Erosion Channel", "Base Alpha Channel", "EmissiveErosion Channel" (UE default = R);
//   dissolve: "Dissolve Contrast", "Dissolve Tilin U/V", "U/V Panner", "FPS", "Erocion Influence",
//   switch "Invert Erocion Pattern"; border: "Border Scale", "Border Contrast", "Border Pow",
//   "Border Scale Fade Multiplier", switch "Border Emissive Erode"; masked emissive: "Emissive Text
//   Intencity", "Dissolve Emissive Texture/Min/Contrast/Pow", "EmissivePanU/V", "EmissiveTextureTileU/V";
//   trail gradient (LinearGradient x2): "Base Fade Length/Contrast/Scale", "Tail Back Mask Length/Scale/
//   Contrast", "Tail Back Min Alpha", "Tail Base Min Alpha", "Tail/Base Gradient Pow", "Trail Mask Alpha
//   Influence", "Trail Mask Dissolve Influence", switches "Invert Gradient", "UV1", "Mutiply by Base Alpha";
//   two-colour curves: switch "Use Curves for Doble Color" + CurveAtlasRowParameter "Color Inner" /
//   "Color Outter" (fixed atlas MercilessLunge_FxCA rows MercilessLunge_Trail_Inner_FxCC / _Outter_FxCC,
//   keys baked below from the decoded curve assets); WorldPositionOffset pin connected + " Motion
//   Influence", "Base/Tail Motion Influence", "Base/Tail Motion Wave Frequence", "Wave Speed", "Min",
//   "Max", switches "Offset", "DynamicParameter affects Motion Influence"; "Camera Fade Start/Length"
//   (CameraDepthFade), "FadeDistance" (cm); DynamicParameter names 0 "Scale/MotionInfluence",
//   1 "Opacity", 2 "Fade In", 3 "Lifetime" (emitters: Scale / Opacity / Fade In / Lifetime|Dissolve Out).
// TEXTURE EVIDENCE (PNGs viewed per channel): the trail strips run along U. Typical packing (e.g.
//   MercilessLunge_MainTrail_FxT, T_ArcaneCurse_*): R = cellular web pattern already masked to the trail
//   band, G = soft band cross-section, B = full tileable voronoi; Willowy smoke / dots / FracNoise are grey.
//   MainTrail_B instances pick Erosion = B, Base Alpha = G: shape (G) eroded by the pattern (B).
//   17 of the 22 referenced textures are cooked SRGB=false; five have no SRGB=false (UE default sRGB,
//   decoded on sample): RainbowTrail02_FXT, T_ArcaneCurse_Gradient, T_WizenedSage_Willowy_Smoke,
//   UncannyAura/Textures/B, T_FracNoise_02. The library has no per-texture sRGB flag, so ALL are sampled
//   raw (no source_color): those five read brighter here than in UE (library gap, see notes).
// UE RIBBON UV SETS (UE4 Cascade FDynamicRibbonEmitterData): TexCoord0 = (U 0 head -> 1 tail over the
//   whole trail, V across); TexCoord1 = the 2nd UV set, U tiled by TypeDataRibbon TilingDistance
//   ("the (estimated) covered distance to tile the 2nd UV set at"; 0 = same as TexCoord0). cascade.gd
//   passes TexCoord0 as (UV2.y = point index / count, UV.y) and TexCoord1 as UV (UV.x = distance /
//   TilingDistance, or 0..1 by distance when TilingDistance = 0). Sprites/meshes: both = the quad UV.
//   Consistency check: all 10 UV1-on instances pan U by only 0 .. -0.2 (a world-anchored, distance-
//   tiled set needs no scroll), all 58 UV1-off ones by -0.3 .. -1.5 (pattern streams head -> tail);
//   e.g. MI_DeathlyDescent_SoftTrail_AG (UV1, -0.1) vs _CB (-0.7) with identical tiling.
// EVIDENCE for the dynamic params (46 emitters' curves): "Fade In" starts 0..1, drops, then climbs to
//   0.5..1.0 at death (BallTrail: 0 -> 1 with constant opacity/alpha) => it is the dissolve threshold
//   (1 = gone). "Scale" is 50 on the Hard trails whose colour is only ~0.05..0.26, 3 on most, 0->2 on
//   centre rays => read as an emissive multiplier (switch "DynamicParameter affects Motion Influence"
//   would reroute it to motion; off on every instance). "Lifetime" is linear 0->1 except on the three
//   BallTrail emitters (ease-out), whose two instances are the only "Use Curves for Doble Color" ones
//   => it is the curve-atlas InputTime. Only those two instances tune the Border params => border =
//   the band that takes the Outer colour.
//
// AUTHORED (graph stripped; every one is a guess consistent with the names/values above):
//   * MF_BR_Dissolver_Partikel: mask = smoothstep(d, d + soft, field), soft = 1 - Dissolve Contrast;
//     field = mix(BaseAlpha channel, Erosion channel (optionally inverted), Erocion Influence).
//   * Border: second dissolve at d + Border Scale * mix(1, Border Scale Fade Multiplier, d); ring = outer
//     - inner, then pow(Border Pow) * Border Contrast.
//   * Masked emissive: dissolve of the panned EmissiveTexture channel at threshold
//     max(d * Dissolve Emissive Texture, Dissolve Emissive Min), softness 1 - Dissolve Emissive Contrast,
//     ^Dissolve Emissive Pow, * Emissive Text Intencity; added as colour * (1 + em). "Border Emissive
//     Erode" on = emissive only inside the border ring, off = over the whole body.
//   * Trail gradient g = TexCoord0.x (0 head -> 1 tail, whole trail; LinearGradient "Uses UV Channel 0")
//     ^ Tail/Base Gradient Pow, inverted by "Invert Gradient". Base fade ramp = saturate(g * Contrast /
//     Length), strength Base Fade Scale, floor Tail Base Min Alpha; tail mask = saturate((1-g) * Contrast
//     / Length), strength Tail Back Mask Scale, floor Tail Back Min Alpha. Alpha influence multiplies
//     opacity, dissolve influence raises d. The "UV1" switch is assumed NOT to move the gradient.
//   * Both textures use TexCoord0 (0..1 over the whole trail, so "Dissolve Tilin U" / "EmissiveTexture
//     TileU" = repeats per trail) unless "UV1" is on, then TexCoord1 (TilingDistance-tiled 2nd set).
//     MF_BR_UV_Controller ("Random Noisy Shape") reduced to uv * Tiling + Panner * FPS-stepped time;
//     its "dfbhsnhsw" / "ghjklt,h" scalars are not used.
//   * WPO only when "Offset" is on: world-Y sine wave, amplitude clamp(mix(Base, Tail Motion Influence, g),
//     Min, Max) cm * " Motion Influence", frequency mix(Base, Tail Wave Frequence, g) waves per trail,
//     phase speed Wave Speed (1/s). Axis is a guess ("Warp_Y (B)" is off everywhere).
//   * "Doble Color": colour = mix(Outer(t), Inner(t), inner/body) * particle colour * Scale, t = Lifetime.
//   * Opacity = body * trail mask * dyn Opacity * particle alpha (* Base Alpha if "Mutiply by Base Alpha")
//     * CameraDepthFade * DepthFade(FadeDistance).
//   * MF_DropTrailRibbonFade (fades the local player's own drop trail near the camera) is NOT applied:
//     its graph is stripped and in this lab it would only hide the effect.
// KNOWN LIBRARY GAPS (see family notes): ribbons get no dynamic parameters from cascade.gd (v_dyn = 1),
//   so for trails the shader uses PROXIES built from the 46 source emitters' own curves, sampled at the
//   vertex's relative time, per emitter group the material can tell apart (11-point tables below):
//   G_CURVES = "Use Curves for Doble Color" instances (only the 3 BallTrail emitters #292 x2 / #505 use
//   them and their curves are identical: Scale 1, Opacity 1, Fade In, ease-out Lifetime -> exact);
//   G_DOUT = slot 3 named "Dissolve Out" (dyn_lifetime = -1: the 7 Magic / Ghostly Fire trails; Scale 1,
//   median Opacity / Fade In); G_LIFE = the other 36 (median Opacity / Fade In, Scale 3 = median, so the
//   six Scale-50 Hard/Bright trails read 17x too dim; Lifetime = relative time, exact for all 36).
//   This is a lab stand-in, not source behaviour; trail_dyn_proxy = false uses the real v_dyn once the
//   library passes it. Channel-mask vectors are stored as {ParameterValue: [..]} which fx_materials.gd
//   cannot read yet, so every instance currently gets the UE default channel R. No per-texture sRGB
//   flag (see TEXTURE EVIDENCE). LAB: local-space ribbons with a constant (or no) StartLocation and no
//   velocity (40 of 46) collapse to zero length in cascade.gd and the 5 world-space ones draw nothing;
//   with "Offset" on (16 of the collapsed ones), the WPO below stretches a collapsed strip into a thin
//   vertical band (an artifact of the collapse, not the trail surface). Only #292's two MagatamaTrail
//   emitters show this material as a real trail in the lab.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/cascade/common.gdshaderinc"
#include "res://shaders/cascade/particle.gdshaderinc"

uniform sampler2D erosion_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D emissive_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 erosion_channel = vec4(1.0, 0.0, 0.0, 0.0);          // "Erosion Channel"
uniform vec4 base_alpha_channel = vec4(1.0, 0.0, 0.0, 0.0);       // "Base Alpha Channel"
uniform vec4 emissive_erosion_channel = vec4(1.0, 0.0, 0.0, 0.0); // "EmissiveErosion Channel"

uniform float dissolve_contrast = 0.5;          // "Dissolve Contrast"
uniform vec2 dissolve_tiling = vec2(1.0, 1.0);  // "Dissolve Tilin U/V"
uniform vec2 panner = vec2(-1.0, 0.1);          // "U Panner" / "V Panner"
uniform float fps = 60.0;                       // "FPS"
uniform float erosion_influence = 1.0;          // "Erocion Influence"
uniform bool invert_erosion = false;            // "Invert Erocion Pattern"

uniform float border_scale = 0.6;               // "Border Scale"
uniform float border_contrast = 1.0;            // "Border Contrast"
uniform float border_pow = 1.0;                 // "Border Pow"
uniform float border_fade_mult = 0.5;           // "Border Scale Fade Multiplier"
uniform bool border_emissive_erode = false;     // "Border Emissive Erode"

uniform float emissive_intensity = 2.5;         // "Emissive Text Intencity"
uniform float dissolve_emissive_texture = 1.0;  // "Dissolve Emissive Texture"
uniform float dissolve_emissive_min = 0.05;     // "Dissolve Emissive Min"
uniform float dissolve_emissive_contrast = 0.0; // "Dissolve Emissive Contrast"
uniform float dissolve_emissive_pow = 1.5;      // "Dissolve Emissive Pow"
uniform vec2 emissive_pan = vec2(-1.0, 0.02);   // "EmissivePanU/V"
uniform vec2 emissive_tile = vec2(1.0, 1.0);    // "EmissiveTextureTileU/V"

uniform bool use_uv1 = false;                   // "UV1": textures on TexCoord1 (TilingDistance-tiled)
uniform bool invert_gradient = false;           // "Invert Gradient"
uniform float gradient_pow = 1.0;               // "Tail/Base Gradient Pow"
uniform float base_fade_length = 2.5;           // "Base Fade Length"
uniform float base_fade_contrast = 150.0;       // "Base Fade Contrast"
uniform float base_fade_scale = 1.0;            // "Base Fade Scale"
uniform float tail_back_length = 10.0;          // "Tail Back Mask Length"
uniform float tail_back_scale = 0.0;            // "Tail Back Mask Scale"
uniform float tail_back_contrast = 1.13;        // "Tail Back Mask Contrast"
uniform float tail_back_min_alpha = 1.0;        // "Tail Back Min Alpha"
uniform float tail_base_min_alpha = 1.0;        // "Tail Base Min Alpha"
uniform float trail_mask_alpha = 1.0;           // "Trail Mask Alpha Influence"
uniform float trail_mask_dissolve = 0.0;        // "Trail Mask Dissolve Influence"
uniform bool mul_base_alpha = false;            // "Mutiply by Base Alpha"
uniform bool use_curves = false;                // "Use Curves for Doble Color"

uniform bool offset_wpo = false;                // "Offset"
uniform bool dyn_motion = false;                // "DynamicParameter affects Motion Influence"
uniform float motion_influence = 1.0;           // " Motion Influence"
uniform float base_motion = 0.0;                // "Base Motion Influence" (cm -> m)
uniform float tail_motion = 0.5;                // "Tail Motion Influence" (cm -> m)
uniform float base_wave_freq = 1.0;             // "Base Motion Wave Frequence"
uniform float tail_wave_freq = 1.0;             // "Tail Motion Wave Frequence"
uniform float wave_speed = -1.0;                // "Wave Speed"
uniform float motion_min = 0.0;                 // "Min" (cm -> m)
uniform float motion_max = 0.5;                 // "Max" (cm -> m)

uniform float camera_fade_start = 1.0;          // "Camera Fade Start" 100 cm
uniform float camera_fade_length = 3.0;         // "Camera Fade Length" 300 cm
uniform float fade_distance = 2.5;              // "FadeDistance" 250 cm (DepthFade)

uniform int dyn_scale = 0;                      // emitter slot named "Scale"
uniform int dyn_opacity = 1;                    // "Opacity"
uniform int dyn_fade_in = 2;                    // "Fade In"
uniform int dyn_lifetime = 3;                   // "Lifetime" (-1 when the slot is "Dissolve Out")
uniform bool trail_dyn_proxy = true;            // ribbons carry no dynamic params yet (cascade.gd)

varying vec2 v_uv0;   // UE TexCoord0: trail = (0 head -> 1 tail over the whole trail, V); sprite = UV
                      // (UE TexCoord1 = v_quv: trail UV tiled by TilingDistance; sprite = UV)
varying float v_rt;   // relative time of the trail point

// Trail proxies (see header): the source emitters' dynamic-param curves at relative time 0, 0.1 .. 1.
// G_LIFE: median of the 36 "Lifetime"-slot emitters (Scale 3 = their median).
const float FI_LIFE[11] = float[](0.5, 0.016, 0.054, 0.14, 0.172, 0.181, 0.214, 0.286, 0.357, 0.429, 0.5);
const float OP_LIFE[11] = float[](0.5, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.971, 0.667, 0.0);
// G_DOUT: median of the 7 "Dissolve Out"-slot emitters (Magic / Ghostly Fire; Scale 1 on all 7).
const float FI_DOUT[11] = float[](0.25, 0.127, 0.297, 0.417, 0.455, 0.544, 0.621, 0.687, 0.76, 0.859, 1.0);
const float OP_DOUT[11] = float[](0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.991, 0.5, 0.0);
// G_CURVES: the 3 BallTrail emitters' identical curves (Scale 1, Opacity 1).
const float FI_CURV[11] = float[](0.0, 0.092, 0.346, 0.431, 0.512, 0.594, 0.675, 0.756, 0.837, 0.919, 1.0);
const float LT_CURV[11] = float[](0.0, 0.158, 0.431, 0.645, 0.81, 0.924, 0.984, 1.0, 1.0, 1.0, 1.0);

float table11(float t, int which) {
	float x = clamp(t, 0.0, 1.0) * 10.0;
	int i = min(int(floor(x)), 9);
	float f = x - float(i);
	if (which == 0) { return mix(FI_LIFE[i], FI_LIFE[i + 1], f); }
	if (which == 1) { return mix(OP_LIFE[i], OP_LIFE[i + 1], f); }
	if (which == 2) { return mix(FI_DOUT[i], FI_DOUT[i + 1], f); }
	if (which == 3) { return mix(OP_DOUT[i], OP_DOUT[i + 1], f); }
	if (which == 4) { return mix(FI_CURV[i], FI_CURV[i + 1], f); }
	return mix(LT_CURV[i], LT_CURV[i + 1], f);
}

float dyn_value(int i, float fallback) {
	if (i < 0) { return fallback; }
	return i == 0 ? v_dyn.x : i == 1 ? v_dyn.y : i == 2 ? v_dyn.z : v_dyn.w;
}

// Linear piecewise curve (constant extrapolation), keys from the decoded CurveLinearColor assets.
vec3 curve_inner(float t) {   // MercilessLunge_Trail_Inner_FxCC
	const float T[5] = float[](0.008, 0.108, 0.292, 0.509, 0.736);
	const vec3 C[5] = vec3[](vec3(0.7, 0.0, 0.0), vec3(0.2, 0.003, 0.0), vec3(0.07, 0.004, 0.032),
		vec3(0.04, 0.008, 0.035), vec3(0.039, 0.01, 0.07));
	if (t <= T[0]) { return C[0]; }
	for (int i = 0; i < 4; i++) {
		if (t <= T[i + 1]) { return mix(C[i], C[i + 1], (t - T[i]) / (T[i + 1] - T[i])); }
	}
	return C[4];
}

vec3 curve_outer(float t) {   // MercilessLunge_Trail_Outter_FxCC
	const float T[3] = float[](-0.001, 0.139, 0.819);
	const vec3 C[3] = vec3[](vec3(0.4, 0.0, 0.02), vec3(0.07, 0.0, 0.012), vec3(0.02, 0.0, 0.012));
	if (t <= T[0]) { return C[0]; }
	for (int i = 0; i < 2; i++) {
		if (t <= T[i + 1]) { return mix(C[i], C[i + 1], (t - T[i]) / (T[i + 1] - T[i])); }
	}
	return C[2];
}

void vertex() {
	vec4 _e; vec4 _d;
	particle_vertex(VERTEX, UV, INSTANCE_CUSTOM, INSTANCE_ID, UV2, _e, _d);
	v_extra = _e; v_dyn = _d; v_color = COLOR; v_quv = UV;
	v_uv0 = is_trail ? vec2(UV2.y, UV.y) : UV;
	v_rt = is_trail ? UV2.x : _e.z;
	if (offset_wpo) {
		// AUTHORED: wave along the trail (TexCoord0), anchored at the head (see header).
		float g = v_uv0.x;
		float mi = motion_influence;
		if (dyn_motion && !(is_trail && trail_dyn_proxy)) { mi *= dyn_value(dyn_scale, 1.0); }
		float amp = clamp(mix(base_motion, tail_motion, g), motion_min, motion_max) * mi;
		float freq = mix(base_wave_freq, tail_wave_freq, g);
		VERTEX.y += amp * sin(6.28318530718 * (g * freq + TIME * wave_speed));
	}
}

void fragment() {
	float scale; float opac; float d; float life;
	if (is_trail && trail_dyn_proxy) {   // lab stand-in for the missing ribbon dynamic params (header)
		if (use_curves) {                 // G_CURVES (exact for its 3 emitters)
			scale = 1.0; opac = 1.0; d = table11(v_rt, 4); life = table11(v_rt, 5);
		} else if (dyn_lifetime < 0) {    // G_DOUT
			scale = 1.0; opac = table11(v_rt, 3); d = table11(v_rt, 2); life = v_rt;
		} else {                          // G_LIFE
			scale = 3.0; opac = table11(v_rt, 1); d = table11(v_rt, 0); life = v_rt;
		}
	} else {
		scale = dyn_value(dyn_scale, 1.0);
		opac = dyn_value(dyn_opacity, 1.0);
		d = dyn_value(dyn_fade_in, 0.0);
		life = dyn_lifetime < 0 ? v_rt : dyn_value(dyn_lifetime, v_rt);
	}
	if (dyn_motion) { scale = 1.0; }
	d = clamp(d, 0.0, 1.0);

	// trail gradient masks (LinearGradient: "Uses UV Channel 0" = TexCoord0, whole trail)
	float g = clamp(v_uv0.x, 0.0, 1.0);
	if (invert_gradient) { g = 1.0 - g; }
	g = pow(max(g, 0.0), max(gradient_pow, 1e-3));
	float base_ramp = clamp(g * base_fade_contrast / max(base_fade_length, 1e-3), 0.0, 1.0);
	float base_m = max(clamp(1.0 - base_fade_scale * (1.0 - base_ramp), 0.0, 1.0), tail_base_min_alpha);
	float tail_ramp = clamp((1.0 - g) * tail_back_contrast / max(tail_back_length, 1e-3), 0.0, 1.0);
	float tail_m = max(clamp(1.0 - tail_back_scale * (1.0 - tail_ramp), 0.0, 1.0), tail_back_min_alpha);
	float trail_mask = clamp(base_m * tail_m, 0.0, 1.0);
	d = 1.0 - (1.0 - d) * mix(1.0, trail_mask, trail_mask_dissolve);

	// UVs: "UV1" off = TexCoord0 (0..1 over the whole trail), on = TexCoord1 (2nd set, tiled by the
	// ribbon's TilingDistance; cascade.gd UV). FPS-stepped panners.
	vec2 tuv = use_uv1 ? v_quv : v_uv0;
	float t = fps > 0.0 ? stepped(TIME, fps) : TIME;
	vec4 ero_s = texture(erosion_tex, tuv * dissolve_tiling + panner * t);
	float ero = dot(ero_s, erosion_channel);
	if (invert_erosion) { ero = 1.0 - ero; }
	float base_a = dot(ero_s, base_alpha_channel);
	float field = mix(base_a, ero, clamp(erosion_influence, 0.0, 1.0));

	// MF_BR_Dissolver_Partikel x2 (body + border core)
	float soft = max(1.0 - dissolve_contrast, 0.003);
	float body = smoothstep(d, d + soft, field);
	float bw = border_scale * mix(1.0, border_fade_mult, d);
	float inner = smoothstep(d + bw, d + bw + soft, field);
	float ring = clamp(body - inner, 0.0, 1.0);
	ring = clamp(pow(ring, max(border_pow, 1e-3)) * border_contrast, 0.0, 1.0);

	// masked emissive (third dissolver)
	vec4 em_s = texture(emissive_tex, tuv * emissive_tile + emissive_pan * t);
	float ev = dot(em_s, emissive_erosion_channel);
	float e_thr = clamp(max(d * dissolve_emissive_texture, dissolve_emissive_min), 0.0, 1.0);
	float e_soft = max(1.0 - dissolve_emissive_contrast, 0.003);
	float em = smoothstep(e_thr, e_thr + e_soft, ev);
	em = pow(max(em, 1e-5), max(dissolve_emissive_pow, 0.0)) * emissive_intensity;
	em *= border_emissive_erode ? ring : 1.0;

	vec3 pc = max(v_color.rgb, vec3(0.0)) * scale;
	vec3 col = pc;
	if (use_curves) {
		float k = clamp(inner / max(body, 1e-4), 0.0, 1.0);
		col = mix(curve_outer(life), curve_inner(life), k) * pc;
	}
	col *= 1.0 + em;

	float op = body * mix(1.0, trail_mask, trail_mask_alpha) * opac * clamp(v_color.a, 0.0, 1.0);
	if (mul_base_alpha) { op *= base_a; }
	op *= camera_depth_fade(-VERTEX.z, camera_fade_start, camera_fade_length);
	op *= depth_fade(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, fade_distance);
	ALBEDO = col;
	ALPHA = clamp(op, 0.0, 1.0);
}
