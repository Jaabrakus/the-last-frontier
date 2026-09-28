// Shared code of the tree / sapling / shrub material (package C). Included by tree.gdshader
// (the in-game material) and tree_bake.gdshader (impostor capture, unshaded). One surface per
// mesh: COLOR.a tells foliage cards (1) from bark (0). Vertex data written by
// tools/environment/vegetation/build_trees.py:
//   COLOR  r = baked AO, g = outer-crown factor, b = per-card random, a = foliage flag
//   UV     bark: tiling bark UV; foliage: rect in the foliage atlas
//   UV2    x = metres from the limb's attachment (branch wind), y = limb phase 0..1
//   NORMAL foliage normals are bent toward the crown's ellipsoid normal (volume shading)
// Per instance (MultiMesh custom data): x = colour variation 0..1, y = dryness 0..1,
// z = random 0..1, w = unused.

#include "res://shaders/common/wind.gdshaderinc"
#include "res://shaders/vegetation/near_fade.gdshaderinc"

uniform sampler2D bark_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D leaf_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;

uniform vec3 bark_tint : source_color = vec3(1.0);
/// Birch: darken the fissured base of the trunk up to this height (m); 0 = off.
uniform float bark_base_dark_height = 0.0;
uniform vec3 leaf_tint : source_color = vec3(1.0);
/// Per-instance variation: colour at custom.x = 1 (multiplied), and the dry / sun-scorched tint.
uniform vec3 leaf_variation : source_color = vec3(0.9, 0.95, 0.8);
uniform vec3 leaf_dry : source_color = vec3(1.15, 1.05, 0.7);
uniform float leaf_outer_boost = 0.18;
uniform float leaf_roughness = 0.72;
uniform float leaf_specular = 0.3;
uniform float leaf_normal_depth = 0.6;
uniform float backlight_strength = 0.55;
uniform float ao_strength = 0.9;
uniform float ao_light_affect = 0.35;
uniform float alpha_cut = 0.42;
/// Mip-level coverage compensation: alpha *= 1 + boost * max(lod - 1, 0), so thin needles keep
/// their coverage in the lower mips (otherwise distant crowns thin out under the alpha test).
uniform float alpha_mip_boost = 0.28;
/// Wind: whole-tree sway (flex for frontier_wind with h = height above the base), limbs
/// (h = metres along the limb) and foliage flutter.
uniform float trunk_flex = 0.015;
uniform float branch_flex = 0.02;
uniform float leaf_flex = 0.035;
/// Pushed aside (2026-09-25, "allow horses to go through shrubs"; no collision): near the player --
/// or the horse the player rides, whose root player_position then is -- saplings and shrubs
/// (push_whole = 1) lean away from it from their base up, and the limbs and foliage of trees within
/// push_radius (m, horizontally) and below push_height bend away. push_strength 0 = off (the
/// impostor bake).
uniform float push_strength = 1.0;
uniform float push_whole = 0.0;
uniform float push_radius = 1.5;
uniform float push_height = 2.9;

/// Near-camera foliage fade (user-approved, 2026-09-25; near_fade.gdshaderinc): leaf and needle
/// cards and the limbs / twigs (UV2.x > 0) closer to the camera than near_fade_end (m) are dithered
/// out, completely from near_fade_begin in; trunks and stems (UV2.x = 0) stay solid. Clears the
/// view when the camera is inside a crown, a sapling or a shrub. Not in shadow passes (the shadows
/// do not change). 0 / 0 = off.
uniform float near_fade_begin = 1.0;
uniform float near_fade_end = 1.5;

varying vec4 v_col;
varying vec4 v_custom;
varying float v_height;

// Wind offset of a vertex (model space). Varyings are written by the caller (vertex()).
vec3 tree_wind(vec3 vertex, mat4 model, vec4 color, vec2 uv2) {
	vec3 base = model[3].xyz;
	vec3 wp = (model * vec4(vertex, 1.0)).xyz;
	float h = max(wp.y - base.y, 0.0);
	float phase = frontier_hash(base.xz) * 6.2832;
	vec3 off = frontier_wind(wp, h, trunk_flex, phase);
	if (push_strength > 0.0 && push_whole > 0.5) {
		// the whole plant leans away from the rider, bending from its base (less right over it, so the
		// lean does not flip as the rider passes the stem)
		vec3 to = base - player_position;
		float d = length(to.xz);
		float k = (1.0 - smoothstep(push_radius * 0.5, push_radius + 0.4, d)) * smoothstep(0.0, 0.4, d)
				* (1.0 - step(1.6, abs(to.y)));
		vec2 dir = d > 1e-3 ? to.xz / d : vec2(0.0, 1.0);
		vec3 lean = vec3(dir.x, 0.0, dir.y) * (k * smoothstep(0.05, 1.8, h) * 0.9 * push_strength);
		lean.y = -dot(lean.xz, lean.xz) / max(2.0 * h, 0.1);
		off += lean;
	}
	if (uv2.x > 0.0) {
		float flex = color.a > 0.5 ? leaf_flex : branch_flex;
		off += frontier_wind(wp, min(uv2.x, 8.0), flex, phase + uv2.y * 6.2832);
		if (push_strength > 0.0 && push_whole < 0.5) {
			vec3 to = wp - player_position;
			float d = length(to.xz);
			float k = (1.0 - smoothstep(push_radius * 0.45, push_radius, d))
					* smoothstep(0.1, 0.35, to.y) * (1.0 - smoothstep(push_height - 0.5, push_height, to.y));
			vec2 dir = d > 1e-3 ? to.xz / d : vec2(0.0, 1.0);
			off += vec3(dir.x, -0.12, dir.y) * (k * 0.45 * push_strength);
		}
	}
	// World offset back to model space (uniform scale + rotation).
	float s2 = max(dot(model[0].xyz, model[0].xyz), 1e-4);
	return (transpose(mat3(model)) * off) / s2;
}

// Albedo, alpha and material terms for the current fragment. Returns alpha.
struct TreeSurface {
	vec3 albedo;
	float alpha;
	vec3 normal_map;
	float normal_depth;
	float roughness;
	float specular;
	float ao;
	bool leaf;
};

TreeSurface tree_surface(vec2 uv, vec2 duvdx, vec2 duvdy, vec4 col4, vec4 custom, float height) {
	TreeSurface s;
	s.leaf = col4.a > 0.5;
	if (s.leaf) {
		vec4 a = textureGrad(leaf_albedo, uv, duvdx, duvdy);
		vec2 ts = vec2(textureSize(leaf_albedo, 0));
		vec2 dx = duvdx * ts;
		vec2 dy = duvdy * ts;
		float lod = 0.5 * log2(max(max(dot(dx, dx), dot(dy, dy)), 1e-8));
		s.alpha = a.a * (1.0 + alpha_mip_boost * max(lod - 1.0, 0.0));
		if (s.alpha < alpha_cut) {
			return s;
		}
		vec3 col = a.rgb * leaf_tint;
		col *= mix(vec3(1.0), leaf_variation, custom.x);
		col *= mix(vec3(1.0), leaf_dry, custom.y * (0.4 + 0.6 * col4.g));
		col *= 1.0 + leaf_outer_boost * col4.g;
		col *= 0.9 + 0.2 * col4.b;
		s.albedo = col;
		s.normal_map = textureGrad(leaf_normal, uv, duvdx, duvdy).rgb;
		s.normal_depth = leaf_normal_depth;
		s.roughness = leaf_roughness;
		s.specular = leaf_specular;
		s.ao = mix(1.0, col4.r, ao_strength);
	} else {
		vec3 col = textureGrad(bark_albedo, uv, duvdx, duvdy).rgb * bark_tint;
		vec3 arm = textureGrad(bark_arm, uv, duvdx, duvdy).rgb;
		if (bark_base_dark_height > 0.0) {
			float k = 1.0 - smoothstep(0.15, bark_base_dark_height, height);
			col = mix(col, col * vec3(0.22, 0.2, 0.19), k);
		}
		col *= 0.93 + 0.14 * col4.b;
		s.albedo = col;
		s.alpha = 1.0;
		s.normal_map = textureGrad(bark_normal, uv, duvdx, duvdy).rgb;
		s.normal_depth = 1.0;
		s.roughness = clamp(arm.g, 0.55, 1.0);
		s.specular = 0.35;
		s.ao = mix(1.0, col4.r * arm.r, ao_strength);
	}
	return s;
}
