shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_disabled;

// Project procedural trees retain their shape, normals, branch wind and bark UVs.
// Existing 4x4 atlas cards are remapped to two upper leafy source atlas islands.
#include "res://shaders/vegetation/tree_common.gdshaderinc"
uniform sampler2D project_leaf_mask : filter_linear_mipmap_anisotropic, repeat_disable;

void vertex() {
	v_col = COLOR;
	v_custom = INSTANCE_CUSTOM;
	v_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - MODEL_MATRIX[3].y;
	VERTEX += tree_wind(VERTEX, MODEL_MATRIX, COLOR, UV2);
}

void fragment() {
	bool leaf = v_col.a > 0.5;
	vec2 sampled_uv = UV;
	if (leaf) {
		vec2 card_uv = fract(UV * 4.0);
		vec4 island = v_col.b > 0.5 ? vec4(0.52, 0.0, 0.44, 0.38) : vec4(0.0, 0.0, 0.52, 0.38);
		sampled_uv = island.xy + card_uv * island.zw;
	}
	vec4 sampled_albedo = leaf ? texture(leaf_albedo, sampled_uv) : texture(bark_albedo, sampled_uv);
	// Source islands and project spray silhouettes differ. Retain the current
	// project's card mask rather than applying a mismatched source alpha layout.
	float alpha = leaf ? texture(project_leaf_mask, UV).a : 1.0;
	if (leaf && alpha < 0.34) {
		discard;
	}
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = 0.34;
	ALBEDO = sampled_albedo.rgb;
	AO = mix(1.0, v_col.r, 0.65);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

void light() {
	float facing = max(dot(normalize(NORMAL), normalize(LIGHT)), 0.0);
	float bands = 0.24 + 0.36 * smoothstep(0.14, 0.22, facing) + 0.40 * smoothstep(0.58, 0.66, facing);
	DIFFUSE_LIGHT += bands * ATTENUATION * LIGHT_COLOR / PI;
}
