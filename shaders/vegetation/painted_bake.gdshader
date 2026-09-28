// Impostor capture of a PAINTED tree (tools/environment/vegetation/bake_impostors.gd style=painted; user 2026-09-28:
// the farthest trees looked the same as before, "in the begining of the video they are both the same"): the albedo of
// painted_tree.gdshader (one flat dab of one of the species' greens per foliage card, the leaf alpha read blurrier and
// cut, the bark recoloured, toned toward the realistic trees as the painted LOD2 is), unshaded. bake_mode 0 writes
// the albedo (the baked AO folded in); 1 the view-space normal (the card's own, as the painted trees light it: no
// normal map), encoded n * 0.5 + 0.5, pre-linearised as tree_bake.gdshader does.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://shaders/vegetation/tree_common.gdshaderinc"

uniform int bake_mode = 0;
uniform float bake_ao = 0.8;
uniform vec3 leaf_a : source_color = vec3(0.25, 0.54, 0.2);
uniform vec3 leaf_b : source_color = vec3(0.44, 0.68, 0.24);
uniform vec3 bark_a : source_color = vec3(0.37, 0.30, 0.24);
uniform vec3 bark_b : source_color = vec3(0.23, 0.19, 0.15);
uniform float dab_blur = 1.6;
uniform float dab_cut = 0.42;
uniform float texture_keep = 0.15;
uniform vec3 top_warm : source_color = vec3(0.72, 0.8, 0.38);
uniform float top_warm_amount = 0.18;
uniform float tone_saturation = 0.72;
uniform vec3 tone_tint : source_color = vec3(0.96, 1.0, 1.05);

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	v_col = COLOR;
	v_custom = INSTANCE_CUSTOM;
	v_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - MODEL_MATRIX[3].y;
}

void fragment() {
	bool leaf = v_col.a > 0.5;
	vec2 gx = dFdx(UV);
	vec2 gy = dFdy(UV);
	vec3 n = NORMAL;
	if (leaf && !FRONT_FACING) {
		n = -n;
	}
	vec3 col;
	float ao;
	if (leaf) {
		vec2 ts = vec2(textureSize(leaf_albedo, 0));
		vec2 dx = gx * ts;
		vec2 dy = gy * ts;
		float lod = 0.5 * log2(max(max(dot(dx, dx), dot(dy, dy)), 1e-8));
		vec4 a = textureLod(leaf_albedo, UV, max(lod, 0.0) + dab_blur);
		if (a.a < dab_cut) {
			discard;
		}
		float pick = fract(v_col.b * 7.13 + v_custom.z * 3.1);
		col = mix(leaf_a, leaf_b, pick);
		float lum = dot(a.rgb, vec3(0.3, 0.59, 0.11));
		col *= mix(1.0, clamp(lum / 0.12, 0.6, 1.4), texture_keep);
		float top = v_col.g * clamp(n.y * 0.5 + 0.5, 0.0, 1.0);
		col = mix(col, top_warm * (col.g / max(top_warm.g, 0.01)), top * top_warm_amount);
		ao = mix(1.0, v_col.r, 0.75);
	} else {
		vec3 t = textureGrad(bark_albedo, UV, gx, gy).rgb;
		float lum = dot(t, vec3(0.3, 0.59, 0.11));
		col = mix(bark_b, bark_a, smoothstep(0.02, 0.3, lum));
		if (bark_base_dark_height > 0.0) {
			col = mix(col, bark_b, (1.0 - smoothstep(0.15, bark_base_dark_height, v_height)) * 0.7);
		}
		ao = mix(1.0, v_col.r, 0.8);
	}
	col = mix(vec3(dot(col, vec3(0.3, 0.59, 0.11))), col, tone_saturation) * tone_tint;
	ALPHA = 1.0;
	if (bake_mode == 0) {
		ALBEDO = col * mix(1.0, ao, bake_ao);
	} else {
		ALBEDO = srgb_to_linear(clamp(normalize(n) * 0.5 + 0.5, 0.0, 1.0));
	}
}
