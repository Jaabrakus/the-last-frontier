// Thủy Vân cloth (style_guide.md 5.2 "Village kit": cloth waves in the shared wind, as the ring's banner shader does):
// the village kit's banners, prayer flags, rags and awnings (materials tvv_cloth_*, tvv_banner_*, tvv_flags;
// tools/thuyvan_art/village). The kit's vertex colour: RGB = baked occlusion x top light (linear, multiplied into the
// painted albedo), A = the pin weight (0 at the pole or rope, 1 at the free hem), so the pinned edge stays put and the
// hem billows most along the cloth's own normal. Lit with Lambert wrap, both faces alike; no banded light.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://shaders/common/wind.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform float rough : hint_range(0.0, 1.0) = 1.0;
uniform float spec : hint_range(0.0, 1.0) = 0.1;
/// m of billow at the free hem at full wind; waves per metre along the cloth; speed
uniform float wave_amp = 0.12;
uniform float wave_k = 2.2;
uniform float wave_speed = 2.4;

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	float ph = frontier_hash(base.xz) * 6.2831853;
	float ws = clamp(wind_strength, 0.0, 1.0);
	float g = frontier_gust(base.xz + VERTEX.xz * 0.05);
	float s = dot(VERTEX, vec3(0.8, -0.9, 0.6)) * wave_k;
	float w = sin(s - TIME * wave_speed + ph) + 0.4 * sin(s * 2.3 - TIME * wave_speed * 1.7 + ph * 1.3);
	VERTEX += NORMAL * w * wave_amp * (0.5 + 0.9 * ws) * (0.8 + 0.4 * g) * clamp(COLOR.a, 0.0, 1.0);
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * mix(vec3(1.0), COLOR.rgb, ao_strength);
	ROUGHNESS = rough;
	SPECULAR = spec;
}
