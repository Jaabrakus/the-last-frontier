// MI_f_Particle_ArcAtlas (parent M_f_ParticleBasicErodeDistort), 2x3 ArcAtlas.
// SOURCE VALUES: brightness 3, opacity control 10, distortion 0.01, mask FPS 12, fades.
// AUTHORED: hard alpha erosion of the arc mask.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/cascade/common.gdshaderinc"
#include "res://shaders/cascade/particle.gdshaderinc"

uniform sampler2D mask_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float brightness = 3.0;
uniform float opacity_control = 10.0;
uniform float distortion_strength = 0.01;
uniform float mask_fps = 12.0;
uniform float normal_pan_speed = 0.2;
uniform float depth_fade_m = 1.5;        // 150 cm
uniform float fade_offset = 2.0;         // 200 cm
uniform float fade_length = 6.0;         // 600 cm

void vertex() {
	vec4 _e; vec4 _d;
	particle_vertex(VERTEX, UV, INSTANCE_CUSTOM, INSTANCE_ID, UV2, _e, _d);
	v_extra = _e; v_dyn = _d; v_color = COLOR; v_quv = UV;
}

void fragment() {
	float t = stepped(TIME, mask_fps);
	vec2 n = texture(normal_tex, v_quv + vec2(normal_pan_speed) * t).xy * 2.0 - 1.0;
	vec2 quv = clamp(v_quv + n * distortion_strength, 0.001, 0.999);
	float m = texture(mask_tex, particle_atlas(quv)).r;
	float o = clamp((m - (1.0 - v_color.a)) * opacity_control, 0.0, 1.0);
	ALBEDO = v_color.rgb * brightness * m;
	ALPHA = o
		* camera_depth_fade(-VERTEX.z, fade_offset, fade_length)
		* depth_fade(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, depth_fade_m);
}
