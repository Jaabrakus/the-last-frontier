// MI_SphereShock (parent M_SphereErosion_SoftEdge): eroding fresnel shell.
// Dynamic params per particle (source curves): x = Opacity, y = Center Fresnel, z = Edge Fresnel.
// SOURCE VALUES: edge softness 0.01, soft edge 3, erosion scale 1, camera fade offset 200 /
// length 4000 cm, depth fade 50 cm, DistortionNoise_Large.
// AUTHORED: centre/edge fresnel blend and the erosion threshold from the Opacity param.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/cascade/common.gdshaderinc"
#include "res://shaders/cascade/particle.gdshaderinc"
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float edge_softness = 0.01;
uniform float soft_edge = 3.0;
uniform float erosion_scale = 1.0;
uniform float camera_fade_offset = 2.0;
uniform float camera_fade_length = 40.0;
uniform float depth_fade_m = 0.5;

void vertex() {
	vec4 _e; vec4 _d;
	particle_vertex(VERTEX, UV, INSTANCE_CUSTOM, INSTANCE_ID, UV2, _e, _d);
	v_extra = _e; v_dyn = _d; v_color = COLOR; v_quv = UV;
}

void fragment() {
	float f = clamp(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float centre = pow(1.0 - f, max(v_dyn.y, 0.01));
	float rim = pow(f, max(v_dyn.z, 0.01));
	float shell = clamp((centre * 0.0 + rim) * soft_edge, 0.0, 1.0);
	float n = texture(noise_tex, UV * erosion_scale).r;
	float thr = 1.0 - clamp(v_dyn.x * 2.0, 0.0, 1.0);
	float o = smoothstep(thr - edge_softness, thr + edge_softness, n) * shell * (1.0 - centre * 0.5);
	ALBEDO = v_color.rgb;
	ALPHA = clamp(o * v_color.a, 0.0, 1.0)
		* camera_depth_fade(-VERTEX.z, camera_fade_offset, camera_fade_length)
		* depth_fade(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, depth_fade_m);
}
