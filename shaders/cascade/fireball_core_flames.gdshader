// Fireball_CoreFlames01_FxMI (parent PowerSurge_Glow01_FxM), 2x2 FlameCore02 atlas.
// SOURCE VALUES: normal-map pan/scale, distortion strength, FPS, edge softness, contrast, fades.
// AUTHORED: toon erosion driven by particle alpha; mask tone scales brightness.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/cascade/common.gdshaderinc"
#include "res://shaders/cascade/particle.gdshaderinc"

uniform sampler2D mask_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D distortion_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float distortion_strength = 0.1;
uniform vec2 normal_pan = vec2(0.45, 0.4);
uniform vec2 normal_scale = vec2(0.3, 0.3);
uniform float fps = 12.0;
uniform float edge_softness = 0.3;
uniform float mask_contrast = 0.5;
uniform float camera_fade_offset = 1.0;   // 100 cm
uniform float camera_fade_length = 0.2;   // 20 cm
uniform float pixel_depth_fade = 0.35;    // 35 cm

void vertex() {
	vec4 _e; vec4 _d;
	particle_vertex(VERTEX, UV, INSTANCE_CUSTOM, INSTANCE_ID, UV2, _e, _d);
	v_extra = _e; v_dyn = _d; v_color = COLOR; v_quv = UV;
}

void fragment() {
	float t = stepped(TIME, fps);
	vec2 n = texture(distortion_normal, v_quv * normal_scale + normal_pan * t).xy * 2.0 - 1.0;
	vec2 quv = clamp(v_quv + n * distortion_strength, 0.001, 0.999);
	float m = texture(mask_tex, particle_atlas(quv)).r;
	float shaped = cheap_contrast(m, mask_contrast);
	float thr = 1.0 - v_color.a;
	float o = smoothstep(thr, thr + edge_softness, shaped);
	ALBEDO = v_color.rgb * m;
	ALPHA = o * step(0.01, m)
		* camera_depth_fade(-VERTEX.z, camera_fade_offset, camera_fade_length)
		* depth_fade(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, pixel_depth_fade);
}
