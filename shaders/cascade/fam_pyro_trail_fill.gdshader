// Spellbreak (Proletariat) /Game/VFX/Cosmetics/CloudBurst/Pyromancer/Trail_Fill family:
// the root + 8 instances (Trail_Fill_Glow, MercilessLunge/DireMalady/GlitedReverence glows,
// MI_Trail_Fill_Darkness/_HolyLight, WingsGlow, GoldTrail). Every instance is
// BLEND_Translucent / MSM_DefaultLit / one-sided, so this is a fixed (non-template) shader.
// Used only by velocity-aligned mesh emitters ("Glow Outer mesh", "MeshBKeeP", "GlowHot",
// "Core Vert Glow") on FX_Oblong_A / _AZ / _B / _C: soft elongated glow volumes that trail a
// moving caster (afterglows, cloudbursts, the Spellstorm beacon).
//
// SURVIVING EVIDENCE (cooked graph stripped):
//   scalars  Emissive Intesity, Frenel Outer Edge, Edge Min, Edge Max, Erosion Scale,
//            erosion Contrast, erosion PreMultiply, U Pan, V Pan, Panner FPS, Rotate,
//            WPO Intensity, Camera Close Start/length, Depth Fade Distance
//   compiled the inline shader maps' FUniformExpressionSet (root + all 9 instance maps) reads
//            exactly those scalars plus RefractionDepthBias, with the folded forms
//            (0 - erosion Contrast), (erosion Contrast + 1) [CheapContrast lerp(-C, 1 + C, x)]
//            and max(Depth Fade Distance, 1e-5) [engine DepthFade]; Rotate only when Has Rotate.
//   dangling "Fill GlowIntensity" (ScalarParameter_2, default 0.1, never overridden) keeps its
//            node but is absent from every compiled map (root, all instances, and the sibling
//            copies StormE_Fill_FxM / M_DeathlyDescent_Trail_Fill). A UE4.22 parameter that reaches
//            an active output always compiles to a uniform expression, and Has Rotate is the only
//            static switch (no quality switch: CachedQualityLevelsUsed is the default), so the
//            node is unconnected or feeds only an inactive input: no in-game effect, NOT used here.
//   switch   Has Rotate (root true, every instance false; Rotate is 0 everywhere)
//   dynamic  [Erosion, Edge Softness, Fill Glow intensity, Param4], defaults (1, 0.05, 0.1, 1)
//   calls    MF_PannerRotatorFPS ("Global Panner (With Rotator)"), CheapContrast,
//            MF_TransluscentToonErosion ("Erodes alpha mask instead of fade out."),
//            SmoothStep, CameraDepthFade
//   texture  one fixed TextureSample: T_f_Distortion_A (grey veins, R=G=B, SRGB false)
//   outputs  the material keeps EmissiveColor + WorldPositionOffset input entries; there are
//            no colour/vector params, so colour = particle colour (HDR, up to 100 on the beacon).
//   siblings StormE_Fill_FxM (same param set + FresnelFrac, Fr2Edge Min/Max, switch Edge
//            Fresnel) and M_DeathlyDescent_Trail_Fill (Erosion Scale split into X/Y) are copies
//            of this graph; they fix how Edge Min/Max and Erosion Scale are read (see below).
// AUTHORED (math): every combination step; see the comments on each step below.
shader_type spatial;
// Source is DefaultLit translucent but has no base-colour parameter and drives EmissiveColor;
// AUTHORED: treated as emissive-only (unshaded), base colour assumed black.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
#include "res://shaders/cascade/common.gdshaderinc"
#include "res://shaders/cascade/particle.gdshaderinc"

uniform sampler2D erosion_tex : repeat_enable, filter_linear_mipmap;   // T_f_Distortion_A (linear)
uniform float emissive_intensity = 1.0;     // "Emissive Intesity"
uniform float fresnel_outer_edge = 1.0;     // "Frenel Outer Edge"
uniform float edge_min = 0.0;               // "Edge Min"  (SmoothStep min)
uniform float edge_max = 0.9;               // "Edge Max"  (SmoothStep max)
uniform float erosion_scale = 1.0;          // "Erosion Scale" (UV tiling of the erosion texture)
uniform float erosion_contrast = 0.0;       // "erosion Contrast" (CheapContrast)
uniform float erosion_premultiply = 1.3;    // "erosion PreMultiply"
uniform vec2 pan = vec2(0.0, 0.5);          // "U Pan", "V Pan"  (UV / s)
uniform float panner_fps = 12.0;            // "Panner FPS"
uniform bool has_rotate = true;             // "Has Rotate"
uniform float rotate = 0.0;                 // "Rotate" (rad / s)
uniform float wpo_m = 0.1;                  // "WPO Intensity" 10 cm
uniform float camera_close_start = 0.15;    // "Camera Close Start" 15 cm
uniform float camera_close_length = 1.0;    // "Camera Close length" 100 cm
uniform float depth_fade_m = 0.5;           // "Depth Fade Distance" 50 cm
uniform int dyn_erosion = 0;                // dynamic parameter "Erosion"
uniform int dyn_edge = 1;                   // dynamic parameter "Edge Softness"
uniform int dyn_fill = 2;                   // dynamic parameter "Fill Glow intensity"

float dynp(int i, float def) {
	return i == 0 ? v_dyn.x : i == 1 ? v_dyn.y : i == 2 ? v_dyn.z : i == 3 ? v_dyn.w : def;
}

void vertex() {
	vec4 _e; vec4 _d;
	particle_vertex(VERTEX, UV, INSTANCE_CUSTOM, INSTANCE_ID, UV2, _e, _d);
	v_extra = _e; v_dyn = _d; v_color = COLOR; v_quv = UV;
	// WorldPositionOffset is connected and scaled by "WPO Intensity" (10-12).
	// AUTHORED guess: a constant world-space push of WPO Intensity cm toward the camera, the
	// usual trick for glow shells wrapped around a character (keeps them in front of the
	// body); a surface-noise offset was rejected because 10 cm would tear the 6 cm-thin
	// shells these emitters spawn (SizeMultiplyLife YZ starts at 0.2).
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w += normalize(CAMERA_POSITION_WORLD - w) * wpo_m;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}

void fragment() {
	// MF_PannerRotatorFPS: global time stepped at Panner FPS, pan (U Pan, V Pan) and, with
	// Has Rotate, rotation about the UV centre. Erosion Scale tiles TexCoord0 (AUTHORED: as
	// UV scale, as the sibling M_DeathlyDescent_Trail_Fill splits it into "Erosion Scale X/Y";
	// DireMalady's 0 gives one flat sample, which its PreMultiply 10 saturates).
	float t = stepped(TIME, max(panner_fps, 0.001));
	vec2 uv = UV * erosion_scale;
	if (has_rotate) {
		uv = rotate_uv(uv, rotate * t / 6.28318530718, vec2(0.5) * erosion_scale);
	}
	uv += pan * t;
	float e = cheap_contrast(texture(erosion_tex, uv).r, erosion_contrast);

	// Outer edge: UE Fresnel(exponent = "Frenel Outer Edge", base reflect fraction = UE default
	// 0.04) through SmoothStep(Edge Min, Edge Max). Evidence for this wiring: the copy
	// StormE_Fill_FxM adds a second fresnel as "FresnelFrac" + "Fr2Edge Min/Max", i.e. the
	// Edge Min/Max pair is the first fresnel's smoothstep; the compiled uniform order (Frenel
	// Outer Edge, then Edge Min, Edge Max) fits Fresnel -> SmoothStep(min, max, x). No
	// FresnelFrac param here, so the base reflect fraction is assumed to be the node default.
	// Exponent 0.1 (glows) = an almost flat shell, 1.0 (Trail_Fill) = a rim that is brightest at
	// the silhouette, 0.7 Darkness.
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fres = 0.04 + 0.96 * pow(max(1.0 - facing, 1e-4), max(fresnel_outer_edge, 0.01));
	float rim = smoothstep(edge_min, edge_max, fres);
	// Fill (AUTHORED): the inside of the shell glows at the dynamic "Fill Glow intensity" alone
	// (curves 0 -> 0.97 -> 0 on Trail_Fill_Glow/WingsGlow, 0 -> 0.2 -> 0 on the other glow MIs and
	// the root EmeraldPlunge/FrostBorn emitters, 0 -> 0.5 -> 0 on the root Toxic ones; default 0.1).
	// The scalar "Fill GlowIntensity" is a dangling node (see header) and adds nothing; the dyn
	// channel shares its 0.1 default, i.e. it is the per-particle replacement of that scalar.
	// The rim keeps full strength; the mix() combination itself is authored.
	float fill = clamp(dynp(dyn_fill, 0.1), 0.0, 1.0);
	float shape = mix(fill, 1.0, rim);

	// MF_TransluscentToonErosion ("Erodes alpha mask instead of fade out"): the alpha mask
	// (shape x panned veins x "erosion PreMultiply") is eroded by the dynamic "Erosion"
	// (threshold 1 - Erosion) with ramp width "Edge Softness" (1 on the glows = soft, 0.05 on
	// Trail_Fill = hard toon cut). Evidence: m_TornadoSimple (DynamicParameter "Erosion" + an
	// "Is particle" switch) compiles (1 - Texture Erosion) and clamp(Edge Softness, 0.01, 1);
	// every material feeding this function's softness from a scalar compiles the same clamp
	// (M_SphereErosion(_SoftEdge), ReaperScythe_FxM, TrailInk_FxM, CenserOfEenlightenment01_FxM).
	// The ramp form saturate((mask - (1 - Erosion)) / softness) is AUTHORED. Particle alpha stays
	// a plain opacity multiplier.
	float mask = clamp(shape * e * erosion_premultiply, 0.0, 1.0);
	float er = dynp(dyn_erosion, 1.0);
	float soft = clamp(dynp(dyn_edge, 0.05), 0.01, 1.0);
	float eroded = clamp((mask - (1.0 - er)) / soft, 0.0, 1.0);

	float op = eroded * v_color.a
		* camera_depth_fade(-VERTEX.z, camera_close_start, camera_close_length)
		* depth_fade(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, depth_fade_m);
	ALBEDO = v_color.rgb * emissive_intensity;
	ALPHA = clamp(op, 0.0, 1.0);
}
