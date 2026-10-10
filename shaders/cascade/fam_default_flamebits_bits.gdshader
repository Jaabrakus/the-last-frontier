// Family: Flamebits_FXM (Spellbreak, Proletariat; UE4.22 Cascade -- cooked game data, the owner
// reports a Proletariat licence, see animations/SOURCE.md). A plain Material (no instances) used by
// 38 enabled sprite emitters: embers, flame bits, velocity-aligned streaks and spark bursts
// (DownWisp, DragonFire puddle, ManaRegen, PowerSurge, TPort, braziers/shrines, MacabreJar ...).
// Root: /Game/VFX/Character/Fire/Flamebits_FXM, BLEND_Masked, MSM_Unlit, one-sided.
//
// SURVIVING SOURCE EVIDENCE (cooked graph: 16 expression slots, 5 survived):
//   TextureSample  Flamebits4x4Erode_FXT (fixed, Coordinates input connected -> distorted UV)
//   TextureObject  NoiseFlame_FXTN (fixed, SamplerType Normal, SRGB=false) fed into
//   MaterialFunctionCall Luos_Mask_Distorter  "Distorts/Refracts the Texture"
//   MaterialFunctionCall Luos_alphaErosion    "Erodes alpha mask instead of fade out."
//   DynamicParameter  ParamNames [EmissiveScale, Param2, Param3, Param4], DefaultValue R = 2
//   BlendMode BLEND_Masked, no OpacityMaskClipValue override -> UE default 0.3333
//   TextureStreamingData: NoiseFlame_FXTN SamplingScale 1.5 on UV channel 0
// TEXTURE EVIDENCE (looked at the PNGs):
//   Flamebits4x4Erode_FXT (DXT5, sRGB): 4x4 atlas of flame-bit silhouettes. ALPHA is a stepped
//   erosion map: three flat bands ~0.77 (outer rim), ~0.87 (middle) and 1.0 (core) plus the
//   anti-aliased edge below 0.77. RGB is grey shading 0.65..1.0 (brighter core, darker rim),
//   correlated with the alpha bands (r = 0.70).
//   NoiseFlame_FXTN: tangent-space normal map of upward-licking flame streaks (RG = slope).
// EMITTER EVIDENCE: every emitter is a sprite with a 4x4 SubUV (PSUVIM_Random) and a
//   ParameterDynamic whose slot 0 is "EmissiveScale" (1 .. 15, sometimes a curve 15 -> 1);
//   ColorOverLife HDR colours (up to 25); AlphaOverLife holds 1.0 for ~60 % of life and then
//   falls to 0, i.e. alpha is the erosion driver, not a fade.
//
// AUTHORED (the graph wiring and the functions' internals are stripped; marked guesses):
//   A1 emissive = Flamebits RGB (sRGB decoded) * particle colour (HDR) * DynamicParameter.R
//      "EmissiveScale". The material reads slot 0 regardless of the emitter's labels; Cascade
//      feeds 1 when an emitter has no ParameterDynamic module.
//   A2 Luos_alphaErosion = saturate((texture alpha - (1 - particle alpha)) * erosion_sharpness),
//      then UE's masked clip at 0.3333; sharpness 10 puts the cut at texture alpha > 1 - a + 0.033.
//      So alpha 1 shows the whole silhouette and the bands erode at a < 0.26 (rim, 0.77),
//      a < 0.16 (middle, 0.87) and a < 0.03 (core): the bit is gone exactly when alpha reaches 0,
//      which is what "erodes alpha mask instead of fade out" needs. EVIDENCE for threshold 1 - a:
//      the shared AlphaOverLife curve (1 ... 0.99, 0.71, 0.47, 0.27, 0.12, 0.03, 0) puts one
//      sample just past each band edge (0.27 / 0.12 / 0.03 vs 0.23 / 0.13 / 0), and the
//      project's other toon erosions (MF_TransluscentToonErosion families) threshold at 1 - alpha.
//      Sharpness itself is a guess (the input is unwired; any value >= ~10 gives the same
//      silhouette because the atlas background alpha is exactly 0). Rejected variant, kept as
//      the uniform: sharpness 1 (literal subtract + 0.3333 clip) erodes at a < 0.56 / 0.46 / 0.33,
//      wastes the curves' 0.33 -> 0 tail and made embers visibly sparser in the renders
//      (captures/fam/default_flamebits_k1).
//   A3 Luos_Mask_Distorter: atlas UV += (normal.rg * 2 - 1) * distortion_strength, the normal
//      sampled at atlas UV * noise_tiling + noise_pan * time. noise_tiling 1.5 comes from the
//      cooked TextureStreamingData (evidence). Strength and pan are guesses (Flamebits exposes no
//      distortion parameter): sibling Spellbreak materials (LandingDust_FXM, WindScroll_FXM) feed
//      this same NoiseFlame_FXTN normal map into the same function with NormalMapStrength 0.05 and
//      NormalMapPanSpeed (0.1, 1.0) on full-quad textures; here 0.05 is applied per 4x4 sub-image
//      (0.0125 atlas UV). A literal 0.05 in atlas UV was tried and shreds the bits into vertical
//      strips (offset up to ~16 % of a cell), which reads as a glitch rather than a flame wobble.
//   A4 the distorted UV is not clamped to the sub-image (UE wraps / bleeds the same way).
//   A5 cull_disabled although the source is one-sided (sprites face the camera in UE; this
//      only avoids winding issues of pre-oriented sprites here).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/cascade/common.gdshaderinc"
#include "res://shaders/cascade/particle.gdshaderinc"

uniform sampler2D flame_tex : source_color, filter_linear_mipmap, repeat_enable;  // Flamebits4x4Erode_FXT
uniform sampler2D noise_normal : hint_normal, filter_linear_mipmap, repeat_enable; // NoiseFlame_FXTN
uniform float alpha_clip = 0.3333;            // UE default OpacityMaskClipValue (root keeps it)
uniform vec2 noise_tiling = vec2(1.5);        // TextureStreamingData SamplingScale 1.5 (A3)
uniform vec2 noise_pan = vec2(0.1, 1.0);      // AUTHORED (A3), UV / s
uniform float distortion_strength = 0.0125;   // AUTHORED (A3): 0.05 per sub-image = 0.0125 atlas UV
uniform float erosion_sharpness = 10.0;       // AUTHORED (A2): Luos_alphaErosion unwired input

void vertex() {
	vec4 _e; vec4 _d;
	particle_vertex(VERTEX, UV, INSTANCE_CUSTOM, INSTANCE_ID, UV2, _e, _d);
	v_extra = _e; v_dyn = _d; v_color = COLOR; v_quv = UV;
}

void fragment() {
	// UE TexCoord0 of a sub-UV sprite = the current atlas cell's UV.
	vec2 auv = particle_atlas(v_quv);

	// A3: Luos_Mask_Distorter -- panning normal map offsets the mask UV.
	vec2 n = texture(noise_normal, auv * noise_tiling + noise_pan * TIME).rg * 2.0 - 1.0;
	vec4 fb = texture(flame_tex, auv + n * distortion_strength);

	// A2: Luos_alphaErosion -- particle alpha erodes the banded alpha instead of fading.
	float op = clamp((fb.a - (1.0 - clamp(v_color.a, 0.0, 1.0))) * erosion_sharpness, 0.0, 1.0);

	// A1: emissive.
	ALBEDO = fb.rgb * v_color.rgb * v_dyn.x;
	ALPHA = op;
	ALPHA_SCISSOR_THRESHOLD = alpha_clip;
}
