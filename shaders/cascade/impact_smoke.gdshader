// MI_SmokeFlow (parent M_FlowMapTest): lit translucent smoke puff with a flow map.
// SOURCE VALUES: speed 0.5, offset micro 0.5, erosion test 0.5456, opacity premultiply 1.1973,
// depth opacity 1.6946, fade distance 41.9 cm, fade offset 100 / length 200 cm; textures.
// AUTHORED: two-phase flow-map scroll; alpha erosion against the erosion texture.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://shaders/cascade/common.gdshaderinc"
#include "res://shaders/cascade/particle.gdshaderinc"

uniform sampler2D opacity_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D erosion_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D flow_tex : filter_linear_mipmap, repeat_enable;
uniform float speed = 0.5;
uniform float offset_micro = 0.5;
uniform float erosion_test = 0.5456;
uniform float opacity_premultiply = 1.1973;
uniform float depth_opacity = 1.6946;
uniform float fade_distance = 0.419;
uniform float fade_offset = 1.0;
uniform float fade_length = 2.0;

void vertex() {
	vec4 _e; vec4 _d;
	particle_vertex(VERTEX, UV, INSTANCE_CUSTOM, INSTANCE_ID, UV2, _e, _d);
	v_extra = _e; v_dyn = _d; v_color = COLOR; v_quv = UV;
}

void fragment() {
	vec2 flow = texture(flow_tex, v_quv).rg * 2.0 - 1.0;
	float ph = fract(TIME * speed);
	float ph2 = fract(TIME * speed + 0.5);
	vec2 uva = v_quv + flow * ph * offset_micro * 0.2;
	vec2 uvb = v_quv + flow * ph2 * offset_micro * 0.2;
	float w = abs(ph - 0.5) * 2.0;
	float op = mix(texture(opacity_tex, clamp(uva, 0.0, 1.0)).r, texture(opacity_tex, clamp(uvb, 0.0, 1.0)).r, w);
	float e = texture(erosion_tex, v_quv + flow * 0.05).r;
	float thr = (1.0 - v_color.a) * erosion_test * 2.0;
	float o = clamp(op * opacity_premultiply * smoothstep(thr - 0.1, thr + 0.1, e), 0.0, 1.0);
	ALBEDO = v_color.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = clamp(o * v_color.a * depth_opacity, 0.0, 1.0)
		* camera_depth_fade(-VERTEX.z, fade_offset, fade_length)
		* depth_fade(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, fade_distance);
}
