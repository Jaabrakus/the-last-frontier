// Facial hair volume of the character creator (FaceExtras): stacked shells over the head's
// beard area, copies of the body.glb head triangles (same skin weights and face shapes).
// UV2.y = shell height h = k / n (1..n); the vertex shader pushes shell h out along the
// skinned normal by h * length (longer on the chin for long styles) and lets it droop by
// h^2. The fragment keeps the pixels of the style's regions (face_detail.gdshaderinc:
// moustache, chin, jaw / cheeks, side whiskers; `style` weights) and cuts strands from the
// head UVs; beyond ~1 px per strand it falls back to a dithered coverage that the game's
// temporal AA averages (as fur_shell.gdshader). Every 2nd shell is dropped beyond lod_far.
// `stylized` 1 (the creator's Stylized face style, FaceExtras sets it with fewer, chunkier
// strands): painted clumps, dark at the roots and lit at the tips.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, alpha_to_coverage;

#include "res://assets/character/shaders/face_detail.gdshaderinc"

uniform vec4 style = vec4(0.0);
uniform float length_m : hint_range(0.0, 0.05) = 0.008;
uniform float density : hint_range(0.0, 1.0) = 1.0;
uniform float droop : hint_range(0.0, 1.0) = 0.45;
uniform float chin_extra : hint_range(0.0, 2.0) = 0.6;     // share longer on the chin (long styles)
uniform vec3 hair_color : source_color = vec3(0.23, 0.15, 0.10);
uniform float grey : hint_range(0.0, 1.0) = 0.0;
uniform float strands : hint_range(500.0, 4000.0) = 1900.0;  // per metre
uniform int shells = 6;
uniform float lod_far = 5.0;
uniform uvec2 hide_mask = uvec2(0u, 0u);     // body regions covered by clothing (UV2.x & 63)
uniform int stylized = 0;

varying float v_h;

void vertex() {
	v_h = UV2.y;
	vec2 fc = face_coords(UV);
	vec4 reg = beard_regions(fc, COLOR.a, COLOR.g);
	float m = beard_mask(fc, reg, style);
	float len = length_m * (1.0 + chin_extra * reg.y * style.y * smoothstep(0.01, 0.02, length_m));
	// side whiskers stay short
	len *= mix(1.0, 0.45, reg.w * (1.0 - max(max(reg.x, reg.y), reg.z)));
	vec3 n = normalize(NORMAL);
	vec3 down = normalize((inverse(MODEL_MATRIX) * vec4(0.0, -1.0, 0.0, 0.0)).xyz);
	VERTEX += n * (0.0002 + v_h * len * m) + down * (droop * v_h * v_h * len * m);
	// the head's distance (the same for the whole shell: no triangle is cut in half) and the
	// region (the same for every vertex of a triangle: no triangle crosses a region border)
	float dist = length((MODELVIEW_MATRIX * vec4(0.0, 1.45, 0.0, 1.0)).xyz);
	int k = int(round(v_h * float(shells)));
	uint r = uint(UV2.x + 0.5) & 63u;
	uint bits = r < 32u ? (hide_mask.x >> r) : (hide_mask.y >> (r - 32u));
	if ((dist > lod_far && k % 2 == 1) || (bits & 1u) != 0u) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	vec2 fc = face_coords(UV);
	vec4 reg = beard_regions(fc, COLOR.a, COLOR.g);
	float m = beard_mask(fc, reg, style);
	vec2 g = fc * vec2(1.45, 1.0) * strands * vec2(1.0, 0.55);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float r1 = fd_hash(cell);
	float present = step(r1 * 0.999, density * smoothstep(0.05, 0.6, m));
	vec2 c = vec2(0.2 + 0.6 * fd_hash(cell + 17.3), 0.2 + 0.6 * fd_hash(cell + 41.1));
	float cl = fd_noise(fc * 260.0);
	// strand length: random, clumped, shorter at the style's soft edge
	float slen = mix(0.45, 1.0, fd_hash(cell + 3.1)) * mix(0.7, 1.15, cl) * smoothstep(0.0, 0.7, m);
	float t = v_h / max(slen, 1e-3);
	float rad = 0.55 * (1.0 - 0.7 * t * t);
	float near_a = (t < 1.0) ? present * (1.0 - smoothstep(rad * 0.6, rad, length(f - c))) : 0.0;
	float px = length(fwidth(g));
	float cover = clamp(1.2 * density * smoothstep(0.05, 0.7, m) * (1.0 - v_h / (0.6 + 0.4 * cl)), 0.0, 1.0);
	float fr = floor(TIME * 60.0);
	float ign = fd_hash(FRAGCOORD.xy + vec2(fract(fr * 0.618034) * 173.0, fract(fr * 0.754878) * 311.0));
	float far_a = step(ign, cover);
	float a = mix(near_a, far_a, smoothstep(0.7, 1.4, px));
	vec3 col = hair_color * (0.8 + 0.4 * fd_hash(cell + 7.7)) * mix(0.85, 1.1, cl);
	float g_on = step(fd_hash(cell + 23.9), grey);
	col = mix(col, vec3(0.58, 0.58, 0.56) * (0.85 + 0.3 * r1), g_on);
	col *= mix(0.45, 1.0, smoothstep(0.0, 0.8, v_h));
	if (stylized == 1) {
		col = hair_color * mix(0.55, 1.25, smoothstep(0.0, 1.0, v_h)) * mix(0.85, 1.1, cl);
		col = mix(col, vec3(0.62, 0.62, 0.60) * mix(0.6, 1.1, v_h), g_on);
	}
	ALBEDO = col;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.3;
	ROUGHNESS = 0.62;
	SPECULAR = 0.3;
	BACKLIGHT = col * 0.3;
}
