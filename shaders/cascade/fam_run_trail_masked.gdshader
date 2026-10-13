// Spellbreak (Proletariat) RunTrailMultiMasked01_FxM -- cosmetic run / drop trail ribbons.
// Roots: /Game/VFX/Cosmetics/Afterglow/Materials/RunTrailMultiMasked01_FxM and the identical copy
// /Game/VFX/Cosmetics/CloudBurst/Conduit/RunTrailMultiMasked01_FxM (same 49 exports, same parameters,
// same switch defaults, same compiled uniform-expression set).
//
// SOURCE (cooked data): every parameter value, both textures, switches, the DynamicParameter slot 0
// "Opacity", unlit / translucent / two-sided, and these facts read from the inline shader map's
// uniform-expression set (roots + 82 instance permutations; UE registers a uniform when generated
// code first reads it, so the list order is the compile order: Emissive first, then Opacity):
//   * MaskTexture and NoiseTexture are SAMPLERTYPE_LinearGrayscale -> one channel each.
//   * Panners: UV * float2(TileU, TileV), FPS-stepped pan, rotator speed only when "Has ...RotatorSpeed".
//     The noise panner is MF_PannerRotatorFPSUV1 (UV channel 1 = the ribbon's distance-tiled UV).
//   * CheapContrast(x, C) = lerp(0 - C, C + 1, x) for RootMaskContrast, TipMaskContrast, NoiseContrast;
//     the texture is compiled inside each contrast (between the 0-C and C+1 registrations).
//   * EMISSIVE: the SelectionColor RGB swizzle (read when UE adds it to the finished Emissive) is the
//     2nd vector in all 84 permutations, so Emissive reads no mask / noise / tile / contrast vector.
//     Brightness is scalar #0 in all 84. Controls: DiffuseAlphaErodeTrailBase01_FxM (emissive texture
//     scale BEFORE the swizzle) and Peacock_Trail_PreMultiplied01_FxM (premultiplied sibling with this
//     exact scalar order: every mask / contrast vector BEFORE the swizzle). => Emissive = colour x
//     Brightness (the root SmoothStep's two scalars follow Brightness and could belong to either
//     property; they are kept in opacity, where the same Root/Tip block sits in every sibling).
//   * OPACITY order: RootSS, CC(mask, RootMaskContrast), TipSS, CC(mask, TipMaskContrast),
//     [EdgeGradientMax, EdgeGradientMin, 1-EdgeGradientMin], clamp(Edge Softness, 0.01, 1),
//     Camera Fade Start/Length, max(Depth Fade, 1e-5), GradientMasksBrightness (after Depth Fade 84/84),
//     [NoiseContrast, panner, NoiseBrightness] (after GMB 72/72), DropTrail* params.
//     Same order in the siblings RunTrailFlowMap, StoneDropT_FXM, DragonMajesty_Trail01_FxM,
//     Energy_Ring01_FxM (Top/Bottom), Trail_Erode_Noise01_FxM (no GMB / Depth Fade in its
//     permutation); the "Add Noise / Multiply Noise" switch never changes the order (same set for
//     true and false permutations here and in DragonMajesty / Peacock siblings); M_InskyPannedTexture has
//     "Opacity Boost" in GMB's slot, ArmorRegen_ReverseDepthMesh02 "MaskBrightness" right after its
//     erosion softness.
//   * "Use Noise" off removes every Noise* parameter; NoiseRotatorSpeed only with "Has NoiseRotatorSpeed".
// AUTHORED (graph stripped): how the pieces combine -- see the comments in fragment().
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/cascade/common.gdshaderinc"
#include "res://shaders/cascade/particle.gdshaderinc"

uniform sampler2D mask_tex : repeat_enable, filter_linear_mipmap;    // MaskTexture (grey)
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;   // NoiseTexture (grey trail art)
// defaults = root material defaults
uniform float fps = 24.0;
uniform vec2 mask_pan = vec2(0.5, 0.5);
uniform vec2 mask_tile = vec2(1.0, 1.0);
uniform bool has_mask_rotator = true;
uniform float mask_rotator_speed = 0.0;      // rad / s (UE Rotator convention -- AUTHORED unit guess)
uniform bool use_noise = false;
uniform bool noise_switch = true;            // "Add Noise / Multiply Noise"; AUTHORED: true = multiply, false = add (inside the alpha)
uniform vec2 noise_pan = vec2(-0.5, -0.5);
uniform vec2 noise_tile = vec2(1.0, 1.0);
uniform bool has_noise_rotator = true;
uniform float noise_rotator_speed = 0.0;
uniform float noise_contrast = 1.0;
uniform float noise_brightness = 1.0;
uniform float root_min = 0.0;
uniform float root_max = 1.0;
uniform float root_contrast = 0.0;
uniform float tip_min = 1.0;
uniform float tip_max = 0.0;
uniform float tip_contrast = 0.0;
uniform bool use_edge = false;
uniform float edge_min = 0.25;
uniform float edge_max = 0.0;
uniform float gradient_brightness = 1.0;     // GradientMasksBrightness
uniform float brightness = 1.0;
uniform float edge_softness = 1.0;
uniform float camera_fade_start = 1.0;       // m (100 cm)
uniform float camera_fade_length = 2.0;      // m (200 cm)
uniform float depth_fade_m = 0.25;           // m (25 cm)
// MF_DropTrailRibbonFade (sky-drop camera fade; 2 SmoothSteps + VectorLength). Graph stripped; AUTHORED
// approximation, OFF in the lab because the lab camera sits inside its 9-12 m fade radius.
uniform bool drop_trail_fade = false;
uniform float drop_radius = 12.0;            // DropTrailFadeRadius (m)
uniform float drop_inner = 0.75;             // DropTrailNormalizedInnerRadius
uniform float drop_min_dot = 0.0;
uniform float drop_max_dot = 0.2;
uniform float drop_min_fade = 0.0;
uniform float drop_offset = -4.0;            // ParticleOffset (m)

varying vec2 v_trail;   // UV2 of ribbons: x = relative time, y = 0 at the head .. 1 at the tail

void vertex() {
	vec4 _e; vec4 _d;
	particle_vertex(VERTEX, UV, INSTANCE_CUSTOM, INSTANCE_ID, UV2, _e, _d);
	v_extra = _e; v_dyn = _d; v_color = COLOR; v_quv = UV;
	v_trail = UV2;
}

// UE SmoothStep function (HLSL smoothstep, a custom node). Min > Max is used by the instances
// (e.g. TipGradientMin 1, TipGradientMax 0.6), so write it out instead of GLSL smoothstep.
float ue_smoothstep(float a, float b, float x) {
	float d = b - a;
	float t = clamp((x - a) / (abs(d) < 1e-5 ? (d < 0.0 ? -1e-5 : 1e-5) : d), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

// MF_PannerRotatorFPS / ...UV1 ("Global Panner (With Rotator)"): UV * tile, rotate, pan by stepped time.
// AUTHORED internals (rotation centre 0.5, pan added after the rotation).
vec2 panner_rotator(vec2 uv, vec2 tile, vec2 pan, float rot_speed, float t) {
	vec2 p = uv * tile;
	if (rot_speed != 0.0) {
		p = rotate_uv(p, rot_speed * t / 6.28318530718, vec2(0.5));
	}
	return p + pan * t;
}

void fragment() {
	float t = stepped(TIME, max(fps, 0.001));
	// UE ribbon UVs: UV0 = 0..1 along the whole trail (head -> tail) x 0..1 across;
	// UV1 = distance-tiled (TilingDistance). The lab gives UV.x = distance / tiling (or 0..1 when the
	// emitter has no tiling, as UE does), UV2.y = normalized along the trail. Sprites: quad UV for both.
	vec2 uv0 = is_trail ? vec2(v_trail.y, UV.y) : v_quv;
	vec2 uv1 = is_trail ? UV : v_quv;

	// Emissive (SOURCE: compile order, see header): flat particle colour (HDR) x Brightness.
	// The toon detail lives in the alpha silhouette, not in the colour.
	ALBEDO = v_color.rgb * brightness;

	// --- erosion field (everything registered before Edge Softness) ---
	float m = texture(mask_tex, panner_rotator(uv0, mask_tile, mask_pan, has_mask_rotator ? mask_rotator_speed : 0.0, t)).r;
	// AUTHORED wiring: SmoothStep X = LinearGradient U (Root/Tip Min/Max read as positions along the
	// trail: instance values root 0 -> 0.2 fade-in, tip 1 -> 0.6 fade-out). Each gradient is paired
	// with its own CheapContrast of the mask, in the compile order RootSS, CC(root), TipSS, CC(tip),
	// and the four are multiplied (the product is the simplest combination that matches that order).
	// The order does separate nestings: sibling M_TrailBase_Pattern registers RMC, 0-RMC, RootGradient
	// Min/Max, RMC+1 (SmoothStep INSIDE the contrast); here Min/Max come first, so the SmoothStep is
	// not inside the contrast and (for the tip block) the contrast is not the SmoothStep's X.
	float field = ue_smoothstep(root_min, root_max, uv0.x) * cheap_contrast(m, root_contrast)
			* ue_smoothstep(tip_min, tip_max, uv0.x) * cheap_contrast(m, tip_contrast);
	if (use_edge) {
		// AUTHORED: two SmoothSteps across the width, (EdgeGradientMax -> EdgeGradientMin) and
		// (1 -> 1 - EdgeGradientMin) (the source folds 1 - EdgeGradientMin; the constant 1 is a guess).
		field *= ue_smoothstep(edge_max, edge_min, uv0.y) * ue_smoothstep(1.0, 1.0 - edge_min, uv0.y);
	}
	// MF_TransluscentToonErosion ("Erodes alpha mask instead of fade out"): clamp(Edge Softness, 0.01, 1)
	// is SOURCE; the threshold form is AUTHORED. Particle opacity = vertex alpha x DynamicParameter
	// slot 0 "Opacity" (ribbons in this lab carry no dynamic params -> 1).
	float o = v_color.a * v_dyn.x;
	float op = clamp((clamp(field, 0.0, 1.0) - (1.0 - o)) / clamp(edge_softness, 0.01, 1.0), 0.0, 1.0);
	// --- after the erosion, in the compiled order (AUTHORED: each one multiplies the eroded alpha) ---
	op *= camera_depth_fade(-VERTEX.z, camera_fade_start, camera_fade_length);
	op *= depth_fade(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, max(depth_fade_m, 1e-5));
	op *= gradient_brightness;   // registered after Depth Fade -> outside the erosion
	if (use_noise) {
		// registered after GradientMasksBrightness -> combined with the scaled, eroded alpha.
		float n = texture(noise_tex, panner_rotator(uv1, noise_tile, noise_pan, has_noise_rotator ? noise_rotator_speed : 0.0, t)).r;
		n = cheap_contrast(n, noise_contrast) * noise_brightness;
		// AUTHORED polarity: the 63 "true" instances carry trail-art strips (flight lines, vines,
		// bolts, wedges on black) that only read as shapes when multiplied into the masked
		// silhouette (added, a line would sit inside a solid fractal band and run past the tapers).
		// AUTHORED add form: the 9 "false" instances (generic fractal / caustic / crack noise; e.g.
		// DragonMajesty NoiseContrast 50, NoiseBrightness 5, EdgeGradientMin 0.5) add the noise
		// INSIDE the eroded alpha, op + n * op. The uniform order cannot tell this from a bare
		// op + n (both read only cached chunks after the noise group), but a bare add ignores
		// every root/tip/edge mask of those instances and fills the raw ribbon strip with
		// hard-edged noise (straight cuts at the strip edges).
		op = noise_switch ? op * n : op * (1.0 + n);
	}
	if (drop_trail_fade) {
		// DropTrail* parameters are registered last -> applied to the final alpha.
		vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 ref = CAMERA_POSITION_WORLD + vec3(0.0, drop_offset, 0.0);
		float dist_f = ue_smoothstep(drop_inner * drop_radius, drop_radius, length(wp - ref));
		float dot_f = ue_smoothstep(drop_min_dot, drop_max_dot, 1.0 - abs(dot(normalize(wp - CAMERA_POSITION_WORLD), CAMERA_DIRECTION_WORLD)));
		op *= max(drop_min_fade, max(dist_f, dot_f));
	}
	ALPHA = clamp(op, 0.0, 1.0);
}
