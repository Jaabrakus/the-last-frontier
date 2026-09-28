// Tree impostors (package C): one quad per tree, turned about Y to face the camera, showing the
// nearest two of the 8 azimuth views baked by tools/environment/vegetation/bake_impostors.gd
// (albedo with AO, view-space normal) blended by angle, and lit with the baked normals so the
// impostors take the same sun as the real trees. MultiMesh instance data:
//   transform: position of the tree base, yaw, uniform scale (the same as the mesh LODs)
//   custom:    x = atlas row (species / variant), y = colour variation, z = dryness, w = unused
// Forest light (canopy.gdshaderinc, 2026-09-26): the same canopy terms as the mesh LODs (tree.gdshader), per
// billboard height, so the switch at 100 m does not change the brightness.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, world_vertex_coords;

#include "res://shaders/common/wind.gdshaderinc"
#include "res://shaders/common/canopy.gdshaderinc"
#include "res://shaders/vegetation/lod_fade.gdshaderinc"

uniform sampler2D imp_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D imp_normal : filter_linear_mipmap_anisotropic, repeat_disable;
/// Per atlas row: x = frame width (m), y = frame height (m), z = frame bottom (m, relative to
/// the tree base), w = unused.
uniform vec4 rows[16];
uniform float frames = 8.0;
uniform float row_count = 10.0;
uniform vec3 leaf_variation : source_color = vec3(0.9, 0.95, 0.8);
uniform vec3 leaf_dry : source_color = vec3(1.15, 1.05, 0.7);
uniform float alpha_cut = 0.3;
uniform float alpha_mip_boost = 0.2;
uniform float backlight_strength = 0.25;
uniform float roughness = 0.8;
/// Brightness match against the lit mesh LODs (the impostor normals are flatter).
uniform float albedo_scale = 0.92;

varying vec2 v_uv0;
varying vec2 v_uv1;
varying float v_blend;
varying vec3 v_right;
varying vec3 v_back;
varying vec4 v_custom;
varying float v_canopy;
varying float v_h;
varying vec2 v_lod;

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	float scale = length(MODEL_MATRIX[0].xyz);
	int row = int(INSTANCE_CUSTOM.x + 0.5);
	vec4 info = rows[row];
	vec3 to_cam = CAMERA_POSITION_WORLD - base;
	to_cam.y = 0.0;
	float len = length(to_cam);
	vec3 back = len > 1e-3 ? to_cam / len : vec3(0.0, 0.0, 1.0);
	vec3 right = vec3(back.z, 0.0, -back.x);
	// The template quad spans x -0.5..0.5, y 0..1 (UV from the top left).
	vec2 q = vec2(UV.x - 0.5, 1.0 - UV.y);
	VERTEX = base + right * (q.x * info.x * scale) + vec3(0.0, 1.0, 0.0) * ((q.y * info.y + info.z) * scale);
	NORMAL = back;
	// Which baked views: camera azimuth in the tree's own frame.
	float yaw = atan(MODEL_MATRIX[2].x, MODEL_MATRIX[2].z);
	float az = atan(back.x, back.z) - yaw;
	float f = fract(az / 6.2831853) * frames;
	float f0 = floor(f);
	v_blend = f - f0;
	float f1 = mod(f0 + 1.0, frames);
	vec2 cuv = vec2(q.x + 0.5, 1.0 - q.y);
	v_uv0 = (vec2(f0, float(row)) + cuv) / vec2(frames, row_count);
	v_uv1 = (vec2(f1, float(row)) + cuv) / vec2(frames, row_count);
	v_right = right;
	v_back = back;
	v_custom = INSTANCE_CUSTOM;
	v_canopy = canopy_cover(base.xz);
	v_h = (q.y * info.y + info.z) * scale;
	// the hand-over from the mesh LOD2 (lod_fade.gdshaderinc): nearer than its band, no quad at all
	v_lod = frontier_lod_cover(distance(CAMERA_POSITION_WORLD, base));
	if (v_lod.x <= 0.0 || v_lod.y <= 0.0) {
		VERTEX = base;
	}
}

void fragment() {
	// the hand-over from the mesh LOD2: the impostor's share of the tree's pixels
	if (frontier_lod_dither(FRAGCOORD.xy, v_lod)) {
		discard;
	}
	// One baked view per fragment: the nearer of the two, dithered across the blend (TAA smooths
	// it), so each fragment fetches one albedo and, if it survives the alpha test, one normal.
	float dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	vec2 uv = v_blend > dither ? v_uv1 : v_uv0;
	// Explicit gradients: the dithered choice of view makes neighbouring pixels sample frames a
	// whole cell apart, which would push implicit derivatives to the smallest mip.
	vec2 gx = dFdx(v_uv0);
	vec2 gy = dFdy(v_uv0);
	vec4 a = textureGrad(imp_albedo, uv, gx, gy);
	vec2 ts = vec2(textureSize(imp_albedo, 0));
	vec2 dx = gx * ts;
	vec2 dy = gy * ts;
	float lod = 0.5 * log2(max(max(dot(dx, dx), dot(dy, dy)), 1e-8));
	float alpha = a.a * (1.0 + alpha_mip_boost * max(lod - 1.0, 0.0));
	if (alpha < alpha_cut) {
		discard;
	}
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	vec3 col = a.rgb * albedo_scale;
	col *= mix(vec3(1.0), leaf_variation, v_custom.y);
	col *= mix(vec3(1.0), leaf_dry, v_custom.z * 0.6);
	ALBEDO = col;
	vec3 n = textureGrad(imp_normal, uv, gx, gy).rgb * 2.0 - 1.0;
	vec3 nw = normalize(v_right * n.x + vec3(0.0, 1.0, 0.0) * n.y + v_back * n.z);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ROUGHNESS = roughness;
	SPECULAR = 0.25;
	BACKLIGHT = col * backlight_strength;
	float under = canopy_under(v_h) * 0.75;
	AO = canopy_sky_factor(v_canopy, under);
	EMISSION = col * canopy_scatter(v_canopy, under, 0.6);
	if (leaf_glow.r + leaf_glow.g + leaf_glow.b > 0.0) {
		// thin leaves against the key light (tree.gdshader): the mesh LODs' outer-crown share, on average
		vec3 to_eye = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		EMISSION += col * leaf_glow.rgb * (canopy_leaf_phase(to_eye, sun_direction) * 0.3 * (1.0 - 0.7 * v_canopy * under));
	}
}
