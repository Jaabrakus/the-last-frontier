// FireballProjectile_Trail01_FxMI -> RainbowSpiral_FXMI -> Fire_MaskedEmissive_RT_FxM (ribbon).
// SOURCE VALUES: colours, FPS 30, panners, distortion scale, edge softness, premultiply,
// texture rotation -0.25, textures (Campfire8 RGB/mask, Distortion_A erosion, DistortionE noise).
// AUTHORED: band colouring, alpha-driven erosion, noise UV distortion.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/cascade/common.gdshaderinc"
#include "res://shaders/cascade/particle.gdshaderinc"

uniform sampler2D rgb_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D erosion_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 core_color = vec3(1.0, 0.7456, 0.0);
uniform vec3 edge_color = vec3(1.0, 0.2483, 0.0104);
uniform float fps = 30.0;
uniform vec2 distortion_scale = vec2(1.0, 2.0);
uniform vec2 noise1_pan = vec2(1.0, 0.5);
uniform vec2 noise2_pan = vec2(0.0, 1.0);
uniform vec2 panner = vec2(-1.0, 0.1);
uniform float speed = 1.0;
uniform float texture_rotation = -0.25;
uniform float distortion_factor = 1.0;
uniform float outer_band = 0.25;        // AUTHORED guess: weight of the B band (outer halo); R = core, G = edge
uniform float edge_softness = 0.1;
uniform float premultiply = 2.0;
uniform float erosion = 1.0;
uniform float camera_fade_start = 1.0;   // 100 cm
uniform float camera_fade_length = 3.0;  // 300 cm
uniform float depth_fade_m = 0.5;        // 50 cm

void vertex() {
	vec4 _e; vec4 _d;
	particle_vertex(VERTEX, UV, INSTANCE_CUSTOM, INSTANCE_ID, UV2, _e, _d);
	v_extra = _e; v_dyn = _d; v_color = COLOR; v_quv = UV;
}

void fragment() {
	float t = stepped(TIME, fps);
	float n1 = texture(noise_tex, UV * distortion_scale + noise1_pan * t).r;
	float n2 = texture(noise_tex, UV * distortion_scale + noise2_pan * t).r;
	vec2 uv = rotate_uv(UV + panner * speed * t, texture_rotation, vec2(0.5));
	uv += (n1 * n2 - 0.25) * 0.2 * distortion_factor;
	uv.x = clamp(uv.x, 0.002, 0.998);
	vec4 tex = texture(rgb_tex, uv);
	float e = texture(erosion_tex, UV * vec2(1.0, 1.0) + panner * speed * t * 0.5).r;
	float thr = (1.0 - v_color.a) * erosion;
	float o = smoothstep(thr - edge_softness, thr + edge_softness, e);
	float shape = clamp(tex.r + tex.g + tex.b * outer_band, 0.0, 1.0) * tex.a;
	ALBEDO = (core_color * tex.r + edge_color * (tex.g + tex.b * outer_band)) * v_color.rgb;
	ALPHA = clamp(shape * o * premultiply, 0.0, 1.0)
		* camera_depth_fade(-VERTEX.z, camera_fade_start, camera_fade_length)
		* depth_fade(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, depth_fade_m);
}
