// Ground plants from Poly Haven (fern_02; package C): alpha-tested, two-sided, wind and player
// trampling from the shared globals, translucent. Normals of the fronds are bent upward so the
// plant is lit like the ground under it (no dark card faces). Under the forest canopy
// (canopy.gdshaderinc, per plant): less sky light, the light the leaves scatter down.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;

#include "res://shaders/common/wind.gdshaderinc"
#include "res://shaders/vegetation/near_fade.gdshaderinc"
#include "res://shaders/common/canopy.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D arm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 variation : source_color = vec3(1.1, 1.05, 0.75);
uniform float alpha_cut = 0.45;
uniform float flex = 0.6;
uniform float up_bend = 0.45;
uniform float backlight_strength = 0.5;
uniform float normal_depth = 0.8;
/// Near-camera fade (near_fade.gdshaderinc): fronds closer than near_fade_end (m) are dithered
/// out, completely from near_fade_begin in. 0 / 0 = off.
uniform float near_fade_begin = 1.0;
uniform float near_fade_end = 1.5;

varying vec4 v_custom;
varying float v_h;
varying float v_canopy;

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(wp.y - base.y, 0.0);
	v_h = h;
	vec3 off = frontier_wind(wp, h, flex, frontier_hash(base.xz) * 6.2832) + frontier_trample(base, h) * 0.6;
	float s2 = max(dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz), 1e-4);
	VERTEX += (transpose(mat3(MODEL_MATRIX)) * off) / s2;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), up_bend));
	v_custom = INSTANCE_CUSTOM;
	v_canopy = canopy_cover(base.xz);
}

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	if (!IN_SHADOW_PASS && (frontier_near_fade(VERTEX, FRAGCOORD.xy, near_fade_begin, near_fade_end)
			|| frontier_line_clear((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, FRAGCOORD.xy))) {
		discard;
	}
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	vec3 col = a.rgb * tint * mix(vec3(1.0), variation, v_custom.x);
	// Darker, cooler at the base of the plant.
	col *= mix(0.65, 1.0, smoothstep(0.0, 0.35, v_h));
	ALBEDO = col;
	vec3 arm = texture(arm_tex, UV).rgb;
	AO = arm.r * canopy_sky_factor(v_canopy, 1.0);
	EMISSION = col * canopy_scatter(v_canopy, 1.0, 0.7) * arm.r;
	ROUGHNESS = clamp(arm.g, 0.5, 1.0);
	SPECULAR = 0.3;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	BACKLIGHT = col * backlight_strength;
}
