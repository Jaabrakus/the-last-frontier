// Family: m_f_lightingToonErosion (Spellbreak, Proletariat; UE4.22 Cascade, converted for this lab).
// 4 instances (MI_f_lightningBranchingBolt, _Thin, A_Lbolt_FXMI, A_Lbolt2_FXMI), all BLEND_Translucent /
// MSM_Unlit / two-sided -> one fixed render mode. Used by ~37 mesh emitters (SM_ZapNado* / A_Zap* /
// BuffBolt* / BrkTrp* folded-strip bolt meshes: UV.y runs along the bolt, UV.x across a 3-vertex
// V-shaped strip whose fold sits at u ~0.46-0.51), PSA_Velocity aligned.
//
// SOURCE (cooked root graph, stripped to parameter nodes + function shells):
//   textures "Lightning Bolt" (T_f_GenericLighting_F: one vertical strip u 0.44-0.56, flat toon
//   plateaus, TC_Alpha, linear), "Particle Mask" (T_f_MaskSquareSoft, sRGB), "Noise 1"/"Noise 2"
//   (root sampler SAMPLERTYPE_LinearGrayscale; cloud noise, linear T_f_SmokeHeight_Greyscale_Uncompressed
//   on MI_f_lightningBranchingBolt, the same image as sRGB T_f_SmokeHeightB on the other 3 instances),
//   "Displacement Texture" (T_f_CubeHeight, faceted cube height, LinearGrayscale, linear);
//   scalars Emissive Strength, FPS, noise strength, Noise Size Multiplier, NOISE1/NOISE2
//   Hor/Vert Panner Speed, Lightning Horizontal/Vertical Panner, Contrast, Edge Softness, DepthFade,
//   Camera Fade Start/Length, Return to Center, Max Center; vectors Lightning Pan Speed, Displacement
//   speed; static switch "Add Camera FAde"; DynamicParameter [Param1, Param2, Displacement, Opacity];
//   functions MF_TransluscentToonErosion ("Erodes alpha mask instead of fade out."), CheapContrast,
//   CameraDepthFade, LinearGradient, SmoothStep; root export keeps a WorldPositionOffset input.
//   Emitters drive dyn "Displacement" 0 -> 1..200 (cm of the bolt MESH: a constant 7-16 % of the
//   mesh asset's own length, independent of particle size) and dyn "Opacity" 1 -> 0 over life,
//   colour HDR 10..200, alpha 1 -> 0. The root's WPO input survives only as a constant (link stripped).
//
// AUTHORED (graph wiring is not in the data) -- see families/toon_mesh_lightning.json notes:
//  * Displacement (vertex): WPO along the vertex normal = (CubeHeight - 0.5) * dyn Displacement (mesh
//    cm, model space -> scales with the particle size like the mesh), CubeHeight sampled at UV +
//    Displacement speed * FPS-stepped time; the bolt ends are anchored by SmoothStep(0, Return to
//    Center, LinearGradient distance-to-end) * Max Center.
//  * Bolt UV = UV + (Noise1, Noise2) * noise strength (Noise 2 at UV * Noise Size Multiplier, each
//    with its own Hor/Vert pan) + Lightning Pan Speed.xy * (Horizontal, Vertical Panner) * t; all
//    pans FPS-stepped (Spellbreak FPS-stepped panners).
//  * Toon erosion: mask = CheapContrast(Bolt * ParticleMask, Contrast); opacity =
//    saturate((mask - (1 - alpha * dynOpacity)) / max(Edge Softness, 0.002)) -> hard edges.
//  * Emissive = particle colour (HDR) * Emissive Strength * mask.
//  * Param1/Param2 are constant 1 in every emitter -> no visible role; not used.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/cascade/common.gdshaderinc"
#include "res://shaders/cascade/particle.gdshaderinc"

uniform sampler2D bolt_tex : repeat_enable, filter_linear_mipmap;                   // "Lightning Bolt" (linear)
uniform sampler2D particle_mask_tex : source_color, repeat_enable, filter_linear_mipmap; // "Particle Mask" (sRGB)
// "Noise 1"/"Noise 2": sampled LINEAR family-wide = the root's SAMPLERTYPE_LinearGrayscale and the
// majority instance (MI_f_lightningBranchingBolt, 21/37 emitters: T_f_SmokeHeight_Greyscale_Uncompressed,
// SRGB False). Approximation: the 16 A_Lbolt/A_Lbolt2/_Thin emitters use the same image as sRGB
// T_f_SmokeHeightB, which UE hardware-decodes (noise mean 0.127 in game vs 0.336 here).
// OPEN: the majority instance's noise + displacement textures are TEXTUREGROUP_EffectsNotFiltered; that
// group's filter is in the game's DeviceProfiles config (not extracted) -> linear filtering here.
uniform sampler2D noise1_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise2_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D displacement_tex : repeat_enable, filter_linear_mipmap;           // "Displacement Texture" (linear)
uniform float emissive_strength = 6.0;
uniform float fps = 60.0;
uniform float noise_strength = 0.2;
uniform float noise_size = 1.0;                // Noise Size Multiplier
uniform vec2 noise1_pan = vec2(1.0);           // NOISE1_Hor/Vert_Panner Speed
uniform vec2 noise2_pan = vec2(1.0);           // NOISE2_Hor/Vert_Panner Speed
uniform vec2 lightning_panner = vec2(0.0);     // Lightning Horizontal / Vertical Panner
uniform vec2 lightning_pan_speed = vec2(0.0, 1.0);  // Lightning Pan Speed (all instances (0,1); root default (0,-0.4))
uniform vec2 displacement_speed = vec2(1.0, 0.0);   // Displacement speed (all instances (1,0); root default 0)
uniform float contrast = 0.1;
uniform float edge_softness = 1.0;
uniform float return_to_center = 0.0;
uniform float max_center = 1.0;
uniform bool add_camera_fade = false;          // static switch "Add Camera FAde"
uniform float camera_fade_start = 0.15;        // m
uniform float camera_fade_length = 1.5;        // m
uniform float depth_fade_m = 0.0;              // m (DepthFade)
uniform int dyn_displacement = -1;             // emitter dynamic param "Displacement" (-1 = default 1)
uniform int dyn_opacity = -1;                  // emitter dynamic param "Opacity" (-1 = default 1)

float dyn_at(int i, vec4 d, float def) {
	if (i < 0) { return def; }
	return i == 0 ? d.x : i == 1 ? d.y : i == 2 ? d.z : d.w;
}

void vertex() {
	vec4 _e; vec4 _d;
	particle_vertex(VERTEX, UV, INSTANCE_CUSTOM, INSTANCE_ID, UV2, _e, _d);
	v_extra = _e; v_dyn = _d; v_color = COLOR; v_quv = UV;
	if (!is_trail) {
		// AUTHORED: WPO displacement in the bolt MESH's own units, ends anchored. dyn "Displacement" is
		// mesh cm (glTF local metres = UE cm * 0.01 -> * 0.01), applied in model space so the offset
		// scales with the particle exactly like the mesh does (UE TransformVector local->world on a mesh
		// particle uses the particle transform incl. its size). Evidence: peak Displacement is a constant
		// 7-16 % of the local mesh length on every emitter (A_ZapTel* 8 cm / 0.6 m, SM_ZapNado* 100-200 cm
		// / 12.4-14 m, BuffBolt* 125 cm / 7.9-11.5 m) but 2 %..1050 % of the bolt's WORLD length (the same
		// 125 cm is reused on bolts shrunk by SizeScale 0.01). Model space also stays finite when
		// SizeMultiplyLife starts at 0 (#439/#824/#840), where inverse(MODEL_MATRIX) was singular.
		float t = stepped(TIME, max(fps, 1.0));
		float amount_m = dyn_at(dyn_displacement, _d, 1.0) * 0.01;
		float h = textureLod(displacement_tex, UV + displacement_speed * t, 0.0).r - 0.5;
		float g = min(UV.y, 1.0 - UV.y);                       // LinearGradient: 0 at the bolt ends
		float anchor = (return_to_center > 0.0 ? smoothstep(0.0, return_to_center, g) : 1.0) * max_center;
		VERTEX += normalize(NORMAL) * h * amount_m * anchor;
	}
}

void fragment() {
	float t = stepped(TIME, max(fps, 1.0));
	vec2 uv = v_quv;
	// Noise 1 / Noise 2 UV distortion (AUTHORED form; values from the source)
	float n1 = texture(noise1_tex, uv + noise1_pan * t).r;
	float n2 = texture(noise2_tex, uv * noise_size + noise2_pan * t).r;
	vec2 buv = uv + vec2(n1, n2) * noise_strength + lightning_pan_speed * lightning_panner * t;
	float bolt = texture(bolt_tex, buv).r;
	float pmask = texture(particle_mask_tex, uv).r;
	float m = cheap_contrast(bolt * pmask, contrast);
	// MF_TransluscentToonErosion: erode the mask by the particle opacity instead of fading
	float a = clamp(v_color.a * dyn_at(dyn_opacity, v_dyn, 1.0), 0.0, 1.0);
	float op = clamp((m - (1.0 - a)) / max(edge_softness, 0.002), 0.0, 1.0);
	if (add_camera_fade) { op *= camera_depth_fade(-VERTEX.z, camera_fade_start, camera_fade_length); }
	if (depth_fade_m > 0.0) { op *= depth_fade(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, depth_fade_m); }
	ALBEDO = v_color.rgb * emissive_strength * m;
	ALPHA = clamp(op, 0.0, 1.0);
}
