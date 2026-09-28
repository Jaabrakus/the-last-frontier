// Impostor capture of a tree (tools/environment/vegetation/bake_impostors.gd): the same surface
// code as tree.gdshader, unshaded. bake_mode 0 writes the albedo (with the baked AO folded in, as
// the impostor has no AO of its own); 1 writes the view-space normal encoded n * 0.5 + 0.5
// (pre-linearised so the sRGB output of the viewport stores it exactly).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://shaders/vegetation/tree_common.gdshaderinc"

uniform int bake_mode = 0;
uniform float bake_ao = 0.8;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	v_col = COLOR;
	v_custom = INSTANCE_CUSTOM;
	v_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - MODEL_MATRIX[3].y;
	VERTEX += tree_wind(VERTEX, MODEL_MATRIX, COLOR, UV2);
}

void fragment() {
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	TreeSurface s = tree_surface(UV, dx, dy, v_col, v_custom, v_height);
	ALPHA = s.alpha;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	if (bake_mode == 0) {
		ALBEDO = s.albedo * mix(1.0, s.ao, bake_ao);
	} else {
		vec3 n = NORMAL;
		if (s.leaf && !FRONT_FACING) {
			n = -n;
		}
		// Perturb by the normal map (tangent frame from the interpolated TANGENT / BINORMAL).
		vec3 nm = s.normal_map * 2.0 - 1.0;
		nm.z = sqrt(max(0.0, 1.0 - dot(nm.xy, nm.xy)));
		nm.xy *= s.normal_depth;
		n = normalize(TANGENT * nm.x + BINORMAL * nm.y + n * nm.z);
		ALBEDO = srgb_to_linear(clamp(n * 0.5 + 0.5, 0.0, 1.0));
	}
}
