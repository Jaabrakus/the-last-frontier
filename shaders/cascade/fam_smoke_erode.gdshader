// Spellbreak (Proletariat) SmokeErodeBase01_FxM family: toon smoke / mist puffs (sprites only:
// 4x2 SmokeTransBaseSubUV01 atlas, 1x1 SmokeTransBase01, 2x2 DarkStormcloud_Clouds).
// Root: /Game/VFX/Materials/Smoke/SmokeErodeBase01_FxM, BLEND_Translucent, MSM_Unlit, one-sided.
//
// SOURCE (cooked parameter nodes / switches / function shells, values filled per instance):
//   Opacity Mask (group "Erosion"), NoiseTexture (group "Noise"; default SmokeErosionTile01_FxT),
//   InnerColor / OuterColor, static switch "2 Color Mask", static bool "Has NoiseRotatorSpeed",
//   NoisePanSpeedU/V, NoiseTextureScaleU/V, NoiseRotatorSpeed, FPS  -> MF_PannerRotatorFPS
//     ("Global Panner (With Rotator)"),
//   EdgeSoftness -> MF_TransluscentToonErosion ("Erodes alpha mask instead of fade out."),
//   MaskContrast -> CheapContrast, DepthMin/DepthMax -> SmoothStep, PixelDepthFade (cm),
//   CameraFadeOffset/CameraFadeLength (cm) -> CameraDepthFade,
//   DynamicParameter names: 0 "Opacity", 1-3 unused ("Param2..4").
// TEXTURE EVIDENCE (looked at the PNGs): Opacity Mask R = hard silhouette, G = hard inner region
//   (the second colour), B = soft shaded relief of the puff (lit bumps); the 2-tone storm cloud
//   texture has R/G only (B = 0). NoiseTexture = tileable erosion pattern. All are sRGB textures
//   (no SRGB=false, TC_Default / TC_Grayscale) so UE samples them linearised -> source_color here.
// EVIDENCE for noise UVs: instances pair NoiseTextureScale (1, 0.5) with the 4x2 atlas and
//   (0.25, 0.25) with the 1x1 texture, i.e. 0.25 x 0.25 of the noise tile per quad in both cases,
//   which only holds when the noise is driven by the atlas TexCoord0 -> noise uv = atlas uv * scale.
//
// AUTHORED (graph stripped; marked guesses):
//   * erosion field = noise (panned/rotated at FPS), CheapContrast(MaskContrast); particle alpha is
//     the erosion threshold (alpha 1 = whole silhouette, alpha 0 = gone), EdgeSoftness = edge width;
//     the eroded value cuts the hard R silhouette. Particle alpha does not fade opacity.
//   * "2 Color Mask" on: colour = lerp(OuterColor, InnerColor, G) (hard two-tone);
//     off: lerp(OuterColor, InnerColor, B) (soft relief shading). Times particle colour (HDR).
//   * dynamic param "Opacity" multiplies the final opacity.
//   * SmoothStep(DepthMin, DepthMax) applied to the PixelDepthFade soft-intersection term.
//   * NoiseRotatorSpeed read as radians / s (UE Rotator convention), rotation about the tile centre.
//   * cull_disabled (sprites are camera-facing; source is one-sided, so this only avoids winding issues).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/cascade/common.gdshaderinc"
#include "res://shaders/cascade/particle.gdshaderinc"

uniform sampler2D mask_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D noise_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 inner_color = vec3(1.0);            // root default InnerColor
uniform vec3 outer_color = vec3(0.5);            // root default OuterColor
uniform bool two_color_mask = true;              // root default "2 Color Mask"
uniform bool has_noise_rotator = true;           // root default "Has NoiseRotatorSpeed"
uniform vec2 noise_pan = vec2(0.05, 0.05);       // NoisePanSpeedU/V (uv / s)
uniform vec2 noise_scale = vec2(0.25, 0.25);     // NoiseTextureScaleU/V
uniform float noise_rotator_speed = 0.01;        // NoiseRotatorSpeed
uniform float fps = 15.0;                        // FPS (stepped panner time)
uniform float edge_softness = 0.015;             // EdgeSoftness
uniform float mask_contrast = 0.01;              // MaskContrast
uniform float depth_min = 0.0;                   // DepthMin
uniform float depth_max = 1.0;                   // DepthMax
uniform float pixel_depth_fade = 0.5;            // PixelDepthFade 50 cm
uniform float camera_fade_offset = 1.0;          // CameraFadeOffset 100 cm
uniform float camera_fade_length = 1.0;          // CameraFadeLength 100 cm (0 = hard cut, as UE x/0)
uniform int dyn_opacity = 0;                     // dynamic param "Opacity" (-1 = none)

void vertex() {
	vec4 _e; vec4 _d;
	particle_vertex(VERTEX, UV, INSTANCE_CUSTOM, INSTANCE_ID, UV2, _e, _d);
	v_extra = _e; v_dyn = _d; v_color = COLOR; v_quv = UV;
}

float dyn_value(int i) {
	return i == 0 ? v_dyn.x : i == 1 ? v_dyn.y : i == 2 ? v_dyn.z : i == 3 ? v_dyn.w : 1.0;
}

void fragment() {
	// UE TexCoord0 of a sub-UV sprite = the current atlas cell's uv
	vec2 auv = particle_atlas(clamp(v_quv, 0.001, 0.999));
	vec4 m = texture(mask_tex, auv);

	// MF_PannerRotatorFPS: FPS-stepped time, scale, optional rotation, pan (AUTHORED order)
	float t = fps > 0.0 ? stepped(TIME, fps) : TIME;
	vec2 nuv = auv * noise_scale;
	if (has_noise_rotator) {
		nuv = rotate_uv(nuv, noise_rotator_speed * t / 6.28318530718, vec2(0.5));
	}
	nuv += noise_pan * t;
	float e = cheap_contrast(texture(noise_tex, nuv).r, mask_contrast);

	// MF_TransluscentToonErosion (AUTHORED): particle alpha sets the erosion threshold.
	float soft = max(edge_softness, 0.002);
	float thr = (1.0 - clamp(v_color.a, 0.0, 1.0)) * (1.0 + soft) - soft;
	float ero = smoothstep(thr, thr + soft, e);

	float tone = two_color_mask ? m.g : m.b;
	vec3 col = mix(outer_color, inner_color, clamp(tone, 0.0, 1.0)) * v_color.rgb;

	float op = m.r * ero;
	if (dyn_opacity >= 0) { op *= dyn_value(dyn_opacity); }
	op *= camera_depth_fade(-VERTEX.z, camera_fade_offset, camera_fade_length);
	op *= smoothstep(depth_min, depth_max,
		depth_fade(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, pixel_depth_fade));
	ALBEDO = col;
	ALPHA = clamp(op, 0.0, 1.0);
}
