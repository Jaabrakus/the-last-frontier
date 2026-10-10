// Family: M_f_ParticleGeneric_Unlit (Spellbreak, Proletariat -- cooked game data from the
// community client backup; the owner reports a Proletariat licence, see animations/SOURCE.md).
// Generic unlit translucent sprite used for soft glows, lens flares, sparks, dust, bubbles,
// streak lines and clouds (21 instances, 109 enabled sprite emitters).
//
// SURVIVING SOURCE EVIDENCE (the cooked graph was stripped):
//   TextureSampleParameter2D "Opacity mask"  (no Coordinates input -> TexCoord0)
//   TextureSampleParameter2D "Texture 1"     (group "Alpha", Coordinates input connected)
//   TextureSampleParameter2D "AlphaErosion"
//   Scalars: Brightness, Depth Opacity, Fade Distance, Fade Length (default 10),
//            Fade Distance Offset, Texture Scale, Horizontal Pan, Vertical Pan,
//            Alpha Start (default 0.99; only changed on erosion instances: 1.0 and 100)
//   Static switches: Has Panner, Has Rotational Animation, Has Alpha Erosion
//   DynamicParameter names: Opacity, Param2, Param3, Param4
//   Functions: CameraDepthFade ("gradient of 0 near the camera to white at Fade Length"),
//              ScaleUVsByCenter, Luos_alphaErosion ("Erodes alpha mask instead of fade out")
//   Every instance: BLEND_Translucent, MSM_Unlit, one-sided. Every texture is greyscale.
// All parameter VALUES / textures / switches come from each instance (families/generic_unlit.json).
//
// AUTHORED (math is a reconstruction, marked below):
//   A1 colour = particle colour * Brightness * Opacity mask.r (the mask sits in parameter
//      group "Color"; Texture 1 sits in group "Alpha" and only shapes opacity). A flat colour
//      was tried first: with the source's HDR colours (10-30) it turned every soft glow /
//      lens-flare halo into a hard white disc.
//   A2 opacity = Opacity mask.r * Texture 1.r * (particle alpha | erosion) * dyn "Opacity"
//      * Depth Opacity * DepthFade(Fade Distance) * CameraDepthFade(Fade Length, Offset).
//   A3 Texture 1 UV = ScaleUVsByCenter(TexCoord0, Texture Scale) = (uv - 0.5) * scale + 0.5,
//      then Panner(Horizontal Pan, Vertical Pan) or Rotator (switches).
//   A4 Rotator speed/centre are not parameters -> UE Rotator defaults (0.25 rad/s, centre 0.5).
//   A5 Luos_alphaErosion: the particle alpha drives a threshold through the AlphaErosion
//      texture instead of fading; Alpha Start is read as the erosion edge sharpness
//      (edge width = 1 / Alpha Start; 0.99/1 = soft subtractive erosion, 100 = hard toon edge),
//      remapped so alpha 1 shows the whole mask and alpha 0 erodes it completely.
//   A6 Erosion texture sampled with TexCoord0 (same UV as the Opacity mask).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/cascade/common.gdshaderinc"
#include "res://shaders/cascade/particle.gdshaderinc"

uniform sampler2D mask_tex : hint_default_white, filter_linear_mipmap, repeat_disable;  // "Opacity mask"
uniform sampler2D tex1 : hint_default_white, filter_linear_mipmap, repeat_enable;      // "Texture 1"
uniform sampler2D erosion_tex : hint_default_white, filter_linear_mipmap, repeat_enable; // "AlphaErosion"
uniform float brightness = 1.0;      // "Brightness"
uniform float depth_opacity = 1.0;   // "Depth Opacity" (opacity input of the depth fade)
uniform float fade_distance = 0.0;   // "Fade Distance" cm -> m (depth fade; 0 = hard)
uniform float fade_length = 0.1;     // "Fade Length" cm -> m (camera depth fade)
uniform float fade_offset = 0.0;     // "Fade Distance Offset" cm -> m
uniform float texture_scale = 1.0;   // "Texture Scale" (ScaleUVsByCenter on Texture 1)
uniform vec2 pan = vec2(0.0);        // "Horizontal Pan", "Vertical Pan" (UV / s)
uniform float alpha_start = 0.99;    // "Alpha Start" (Luos_alphaErosion)
uniform bool has_panner = false;     // "Has Panner"
uniform bool has_rotation = false;   // "Has Rotational Animation"
uniform bool has_erosion = false;    // "Has Alpha Erosion"
uniform int dyn_opacity = -1;        // dynamic parameter named "Opacity"
uniform float rotator_speed = 0.25;  // AUTHORED (A4): UE Rotator default, rad / s

void vertex() {
	vec4 _e; vec4 _d;
	particle_vertex(VERTEX, UV, INSTANCE_CUSTOM, INSTANCE_ID, UV2, _e, _d);
	v_extra = _e; v_dyn = _d; v_color = COLOR; v_quv = UV;
}

float dyn_value(int i) {
	return i == 0 ? v_dyn.x : i == 1 ? v_dyn.y : i == 2 ? v_dyn.z : i == 3 ? v_dyn.w : 1.0;
}

void fragment() {
	// UE TexCoord[0] of a sub-UV sprite is already the current sub-image's UV.
	vec2 uv0 = particle_atlas(v_quv);
	float mask = texture(mask_tex, uv0).r;

	// A3/A4: Texture 1 coordinates.
	vec2 uv1 = (uv0 - 0.5) * texture_scale + 0.5;
	if (has_panner) {
		uv1 += pan * TIME;
	}
	if (has_rotation) {
		uv1 = rotate_uv(uv1, rotator_speed * TIME / TAU, vec2(0.5));
	}
	float t1 = texture(tex1, uv1).r;

	// A5: alpha erosion replaces the alpha fade when the switch is on.
	float a = v_color.a;
	float alpha_term = a;
	if (has_erosion) {
		float e = texture(erosion_tex, uv0).r;
		float w = 1.0 / max(alpha_start, 0.01);
		float thr = mix(-w, 1.0, clamp(1.0 - a, 0.0, 1.0));
		alpha_term = clamp((e - thr) / w, 0.0, 1.0);
	}

	// A2: opacity chain; UE clamps translucent opacity only at the output.
	float op = mask * t1 * alpha_term * dyn_value(dyn_opacity) * depth_opacity;
	op *= camera_depth_fade(-VERTEX.z, fade_offset, fade_length);
	if (fade_distance > 0.0) {
		op *= depth_fade(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, fade_distance);
	}
	ALBEDO = v_color.rgb * brightness * mask;   // A1 (HDR particle colour)
	ALPHA = clamp(op, 0.0, 1.0);
}
