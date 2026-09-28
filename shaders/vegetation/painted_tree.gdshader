// Painted trees: the distant trees' look (user 2026-09-28: "the painted trees can be distant trees"; LOD2 on, the
// realistic LODs nearer: vegetation.gd, painted_look.gd; first a look test of 2026-09-26, branch part/style-trees): the
// realistic trees' own meshes (real limbs, clustered foliage cards with crown-bent normals) painted after Alariko's paintings
// (inspiration only). Each foliage card becomes one rounded dab of flat green: the leaf atlas alpha is read a few
// mips blurrier (the leaves of a clump merge into one shape) and cut; its colour is one of the species' greens, not
// the photo; the light is banded per dab (painted_light.gdshaderinc). Bark keeps only the photo's light and dark,
// recoloured. Wind, rider push, the near-camera fade: tree_common.gdshaderinc; the forest light: canopy.gdshaderinc.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://shaders/vegetation/tree_common.gdshaderinc"
#include "res://shaders/common/canopy.gdshaderinc"
#include "res://shaders/vegetation/painted_light.gdshaderinc"
#include "res://shaders/vegetation/lod_fade.gdshaderinc"

/// Toned toward the realistic trees near the player (user 2026-09-28: the distant trees painted, no bright band ahead
/// of the realistic ones): the colour's saturation kept (1: the look test's), and a tint (the photo foliage's cooler,
/// bluer green).
uniform float tone_saturation = 0.72;
uniform vec3 tone_tint : source_color = vec3(0.96, 1.0, 1.05);

/// The species' two greens (a dab takes one between them) and its bark (dark, light).
uniform vec3 leaf_a : source_color = vec3(0.25, 0.54, 0.2);
uniform vec3 leaf_b : source_color = vec3(0.44, 0.68, 0.24);
uniform vec3 bark_a : source_color = vec3(0.37, 0.30, 0.24);
uniform vec3 bark_b : source_color = vec3(0.23, 0.19, 0.15);
/// Mip bias of the leaf alpha (rounder, bigger dabs) and where it is cut.
uniform float dab_blur = 1.6;
uniform float dab_cut = 0.42;
/// How much of the photo's light and dark survives under the paint (leaves; the atlas mean is ~0.12 linear).
uniform float texture_keep = 0.15;
/// Warmer, yellower green on the outer crown facing up (the sky's warm light painted in).
uniform vec3 top_warm : source_color = vec3(0.72, 0.8, 0.38);
uniform float top_warm_amount = 0.18;

varying float v_canopy;
varying vec2 v_lod;

void vertex() {
	v_col = COLOR;
	v_custom = INSTANCE_CUSTOM;
	v_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - MODEL_MATRIX[3].y;
	VERTEX += tree_wind(VERTEX, MODEL_MATRIX, COLOR, UV2);
	v_canopy = canopy_cover(MODEL_MATRIX[3].xz);
	// the LOD's share of this tree (lod_fade.gdshaderinc); none: the instance collapses, no pixels
	v_lod = frontier_lod_cover(distance(CAMERA_POSITION_WORLD, MODEL_MATRIX[3].xyz));
	if (v_lod.x <= 0.0 || v_lod.y <= 0.0) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	// the hand-over from the realistic LOD1 (and to the impostors): this LOD's share of the pixels
	if (!IN_SHADOW_PASS && frontier_lod_dither(FRAGCOORD.xy, v_lod)) {
		discard;
	}
	bool leaf = v_col.a > 0.5;
	if ((leaf || UV2.x > 0.0) && !IN_SHADOW_PASS && frontier_near_fade(VERTEX, FRAGCOORD.xy, near_fade_begin, near_fade_end)) {
		discard;
	}
	vec2 gx = dFdx(UV);
	vec2 gy = dFdy(UV);
	vec3 col;
	if (leaf) {
		vec2 ts = vec2(textureSize(leaf_albedo, 0));
		vec2 dx = gx * ts;
		vec2 dy = gy * ts;
		float lod = 0.5 * log2(max(max(dot(dx, dx), dot(dy, dy)), 1e-8));
		vec4 a = textureLod(leaf_albedo, UV, max(lod, 0.0) + dab_blur);
		float alpha = a.a * (1.0 + alpha_mip_boost * max(lod - 1.0, 0.0));
		if (alpha < dab_cut) {
			discard;
		}
		ALPHA = alpha;
		ALPHA_SCISSOR_THRESHOLD = dab_cut;
		// one dab, one green
		float pick = fract(v_col.b * 7.13 + v_custom.z * 3.1);
		col = mix(leaf_a, leaf_b, pick);
		float lum = dot(a.rgb, vec3(0.3, 0.59, 0.11));
		col *= mix(1.0, clamp(lum / 0.12, 0.6, 1.4), texture_keep);
		col *= mix(vec3(0.95, 1.0, 1.03), vec3(1.05, 1.0, 0.92), v_custom.x);
		col = mix(col, col * vec3(1.2, 1.05, 0.6), v_custom.y * 0.5 * (0.4 + 0.6 * v_col.g));
		if (!FRONT_FACING) {
			// the crown normal on both sides of a card: the crown shades as one volume
			NORMAL = -NORMAL;
		}
		float top = v_col.g * clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0);
		col = mix(col, top_warm * (col.g / max(top_warm.g, 0.01)), top * top_warm_amount);
		// the terminator steps dab by dab
		v_stroke = v_col.b;
		AO = mix(1.0, v_col.r, 0.75);
		AO_LIGHT_AFFECT = 0.3;
	} else {
		vec3 t = textureGrad(bark_albedo, UV, gx, gy).rgb;
		float lum = dot(t, vec3(0.3, 0.59, 0.11));
		col = mix(bark_b, bark_a, smoothstep(0.02, 0.3, lum));
		if (bark_base_dark_height > 0.0) {
			col = mix(col, bark_b, (1.0 - smoothstep(0.15, bark_base_dark_height, v_height)) * 0.7);
		}
		v_stroke = 0.5 + (v_col.b - 0.5) * 0.4;
		AO = mix(1.0, v_col.r, 0.8);
		AO_LIGHT_AFFECT = 0.15;
	}
	// toned toward the realistic trees: less saturated, the cooler green
	col = mix(vec3(dot(col, vec3(0.3, 0.59, 0.11))), col, tone_saturation) * tone_tint;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float under = push_whole > 0.5 ? 1.0 : canopy_under(v_height) * (leaf ? 1.0 - 0.5 * v_col.g : 1.0);
	AO *= canopy_sky_factor(v_canopy, under);
	EMISSION = col * canopy_scatter(v_canopy, under, 0.6) * v_col.r;
}
