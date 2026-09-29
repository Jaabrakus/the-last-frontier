// Ground plants from Poly Haven (fern_02; package C): alpha-tested, two-sided, wind and player
// trampling from the shared globals, translucent. Normals of the fronds are bent upward so the
// plant is lit like the ground under it (no dark card faces). Under the forest canopy
// (canopy.gdshaderinc, per plant): less sky light, the light the leaves scatter down.
// The ferns' year (leaf_season, scripts/snow/season_leaves.gd; user 2026-09-28, "more foliage" on the forest floor):
// green all summer, golden then russet in the autumn, died back to nothing over the winter, unfurling again in the spring
// after the buds, each plant a little early or late.
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

global uniform float leaf_season;

varying vec4 v_custom;
varying float v_h;
varying float v_canopy;
varying float v_autumn;

/// A fern at leaf_season `s` (its own offset `r` 0..1): how much of it stands (0 died back .. 1 full) and how far it has
/// turned (0 green .. 1 russet).
vec2 fern_season(float s, float r) {
	float d = (r - 0.5) * 0.3;
	if (s < 1.0) {
		return vec2(1.0, smoothstep(0.35 + d, 1.0 + d, s) * 0.7);
	}
	if (s < 2.0) {
		return vec2(1.0 - smoothstep(1.2 + d, 1.85 + d, s), 0.7 + 0.3 * smoothstep(1.0, 1.5, s));
	}
	return vec2(smoothstep(2.15 + d, 2.65 + d * 0.3, s), 0.0);
}

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	// the season: a fern dying back shrinks into its root, one unfurling grows out of it
	vec2 fs = fern_season(leaf_season, frontier_hash(base.xz + 3.7));
	v_autumn = fs.y;
	VERTEX *= mix(0.25, 1.0, fs.x) * step(0.02, fs.x);
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
	// the autumn: golden, then russet
	if (v_autumn > 0.001) {
		float lum = dot(col, vec3(0.3, 0.59, 0.11));
		vec3 turned = mix(vec3(0.62, 0.45, 0.12), vec3(0.42, 0.2, 0.07), smoothstep(0.5, 1.0, v_autumn));
		col = mix(col, turned * clamp(lum / 0.2, 0.5, 1.3), smoothstep(0.0, 0.5, v_autumn));
	}
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
