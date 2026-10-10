// Fireball_Head01_FxMI (parent M_f_FireBeam) on SM_EnergyMeshB.
// SOURCE VALUES: colours, intensity, FPS, speed, rotation, edge mask, fades, textures.
// AUTHORED (graph stripped by cooking): how bands/noise/fresnel combine.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/cascade/common.gdshaderinc"
#include "res://shaders/cascade/particle.gdshaderinc"

uniform sampler2D rgb_tex : repeat_enable, filter_linear_mipmap;      // RGB Texture + MaskTexture (A)
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;    // Noise Texture 1
uniform vec3 core_color = vec3(1.0, 0.7456, 0.0);
uniform vec3 edge_color = vec3(1.0, 0.2483, 0.0104);
uniform float emissive_intensity = 3.0;
uniform float fps = 12.0;
uniform float speed = 0.3;
uniform vec2 panner = vec2(0.2, 0.2);        // parent defaults U/V Panner
uniform float texture_rotation = 0.5;        // turns
uniform float distortion_factor = 1.0;
uniform float outer_band = 0.25;        // AUTHORED guess: weight of the B band (outer halo); R = core, G = edge
uniform float distortion_scale = 1.0;
uniform float fresnel_mask = 1.0;
uniform float edge_mask_min = 0.9;
uniform float edge_mask_max = 0.97;
uniform float fade_distance = 0.5;           // DepthFade, 50 cm
uniform float near_fade_offset = 1.0;        // 100 cm
uniform float near_fade_length = 0.5;        // 50 cm

void vertex() {
	vec4 _e; vec4 _d;
	particle_vertex(VERTEX, UV, INSTANCE_CUSTOM, INSTANCE_ID, UV2, _e, _d);
	v_extra = _e; v_dyn = _d; v_color = COLOR; v_quv = UV;
}

void fragment() {
	float t = stepped(TIME, fps) * speed;
	float dyn_factor = v_dyn.x, dyn_scale = v_dyn.y;
	float n = texture(noise_tex, UV * distortion_scale * dyn_scale + panner * t).r;
	vec2 uv = rotate_uv(UV, texture_rotation, vec2(0.5));
	uv.x += panner.x * t;                    // pan around the body only, keep bands in place
	uv += (n - 0.5) * 0.1 * distortion_factor * dyn_factor;
	uv.y = clamp(uv.y, 0.002, 0.998);
	vec4 tex = texture(rgb_tex, uv);
	vec3 emissive = (core_color * tex.r + edge_color * (tex.g + tex.b * outer_band)) * emissive_intensity * v_color.rgb;
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = 1.0 - smoothstep(edge_mask_min, edge_mask_max, 1.0 - facing) * fresnel_mask;
	float shape = clamp(tex.r + tex.g + tex.b * outer_band, 0.0, 1.0) * tex.a;
	float depth = -VERTEX.z;
	ALBEDO = emissive;
	ALPHA = clamp(shape * edge * v_color.a, 0.0, 1.0)
		* camera_depth_fade(depth, near_fade_offset, near_fade_length)
		* depth_fade(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, fade_distance);
}
