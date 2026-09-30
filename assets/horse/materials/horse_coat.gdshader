// Short-hair horse coat (tools/horse/coat.py bakes the textures; scripts/horse/horse_look.gd
// sets the per-instance coat colours of a variant: bay, brown, black, chestnut, grey, dun).
//   masks_tex   R points  G dapples  B countershade (0 belly, 0.5, 1 topline; > 0.86 dorsal stripe)  A white markings
//   detail_tex  R hair streaks  G ambient occlusion  B mealy / soft areas  A bare skin and horn
//   normal_tex  tangent space (OpenGL): anatomy detail, ribs, hair streaks
//   flow_tex    RG hair direction in tangent space (anisotropic sheen along the hair)
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/common/canopy.gdshaderinc"

uniform sampler2D masks_tex : hint_default_black, filter_linear_mipmap_anisotropic;
uniform sampler2D detail_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D flow_tex : hint_default_white, filter_linear_mipmap;
uniform float normal_strength = 1.0;
uniform float anisotropy_amount : hint_range(0.0, 1.0) = 0.16;
uniform float hair_contrast : hint_range(0.0, 0.5) = 0.16;
uniform float ao_albedo : hint_range(0.0, 1.0) = 0.22;
uniform float sheen : hint_range(0.0, 1.0) = 0.035;
uniform vec3 white_hair : source_color = vec3(0.86, 0.84, 0.79);
uniform vec3 pink_skin : source_color = vec3(0.62, 0.45, 0.42);

instance uniform vec4 coat_body : source_color = vec4(0.478, 0.271, 0.149, 1.0);
instance uniform vec4 coat_top : source_color = vec4(0.360, 0.190, 0.100, 1.0);
instance uniform vec4 coat_belly : source_color = vec4(0.600, 0.380, 0.220, 1.0);
instance uniform vec4 coat_points : source_color = vec4(0.090, 0.067, 0.055, 1.0);
instance uniform vec4 coat_mealy : source_color = vec4(0.630, 0.420, 0.260, 1.0);
instance uniform vec4 coat_skin : source_color = vec4(0.130, 0.100, 0.090, 1.0);
instance uniform vec4 coat_dapple : source_color = vec4(0.560, 0.330, 0.190, 1.0);
instance uniform float dapple_amount = 0.25;
instance uniform float points_amount = 1.0;
instance uniform float mealy_amount = 0.35;
instance uniform float stripe_amount = 0.0;
instance uniform float white_amount = 1.0;
instance uniform float coat_gloss = 0.0;

void fragment() {
	vec4 mk = texture(masks_tex, UV);
	vec4 dt = texture(detail_tex, UV);
	float shade = mk.b;
	vec3 c = coat_body.rgb;
	c = mix(c, coat_top.rgb, clamp((shade - 0.5) / 0.35, 0.0, 1.0));
	c = mix(c, coat_belly.rgb, clamp((0.5 - shade) / 0.45, 0.0, 1.0));
	c = mix(c, coat_dapple.rgb, mk.g * dapple_amount);
	c = mix(c, coat_mealy.rgb, dt.b * mealy_amount);
	c = mix(c, coat_points.rgb, mk.r * points_amount);
	c = mix(c, coat_points.rgb, smoothstep(0.86, 0.95, shade) * stripe_amount * 0.85);
	c *= 1.0 + hair_contrast * (dt.r - 0.5) * 2.0;
	float white = mk.a * white_amount;
	c = mix(c, white_hair * (0.92 + 0.16 * dt.r), white);
	float skin = dt.a;
	c = mix(c, mix(coat_skin.rgb, pink_skin, white), skin * 0.9);
	c *= mix(1.0, dt.g, ao_albedo);
	ALBEDO = c;
	AO = dt.g;
	AO_LIGHT_AFFECT = 0.25;
	// a short, dry summer coat: broad, soft highlights, no plastic sheen in the low sun
	// (revision 4: rougher, less specular, weaker anisotropy and rim)
	ROUGHNESS = clamp(0.74 + (dt.r - 0.5) * 0.14 - 0.14 * skin + coat_gloss, 0.12, 1.0);
	SPECULAR = 0.30;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	vec2 fl = texture(flow_tex, UV).rg * 2.0 - 1.0;
	float fl_len = length(fl);
	ANISOTROPY = anisotropy_amount * (1.0 - skin) * smoothstep(0.5, 0.9, fl_len);
	ANISOTROPY_FLOW = fl / max(fl_len, 1e-4);
	RIM = sheen * (1.0 - skin);
	RIM_TINT = 0.55;
	// Under the forest canopy the same shade as the floor it stands on (canopy.gdshaderinc: the crowns take part of the sky
	// light and scatter some of the sun down; neutral without the forest light). Without it a body kept the open sky's
	// light under the trees and stood out lit in the shade (user 2026-09-30).
	float canopy_c = canopy_cover((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz);
	AO *= canopy_sky_factor(canopy_c, 1.0);
	EMISSION += ALBEDO * canopy_scatter(canopy_c, 1.0, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y) * AO;
}
