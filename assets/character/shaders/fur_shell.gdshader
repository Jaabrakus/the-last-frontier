// Fur of the customizer garments (surface "<id>_fur"; built by tools/character/garments/frontier,
// see _frontier_common.py and design §9): one surface, two zones.
//   zone 0  shells: stacked copies of the garment's outer surface at the bind position; the
//           vertex shader pushes shell h (UV2.y = 1 - h, h = k / n) out along the skinned
//           normal by h * fur_length * COLOR.a, leans it along the comb (world-down on the
//           surface) and lets it droop by h^2. The fragment cuts strands procedurally from
//           UV (metres, grain aligned): one strand per cell of 1 / density metres, random
//           length, clumped; beyond ~1 px per strand it falls back to soft clumps.
//   zone 1  guard-hair cards: strips rooted on the surface (UV.x across in metres, UV.y
//           along; h = root 0 .. tip 1), drawn as 2-3 tapering hairs each.
// COLOR.a = static length factor (edges, contact with the arm / body). CUSTOM0.x = distance
// (m) to the waist-belt line, CUSTOM0.y = to the shoulder-strap lines: the pile flattens
// there when belt_flatten / strap_flatten are set (belts and straps sit on flattened fur).
// UV2.x = region + 64 * zone: regions in hide_mask collapse (covered by an outer layer).
// Colour: root -> band -> tip ramp per fur (catalog "fur" presets: bear, beaver, wolf...).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, alpha_to_coverage;

uniform uvec2 hide_mask = uvec2(0u, 0u);
uniform vec3 root_color : source_color = vec3(0.48, 0.35, 0.25);
uniform vec3 band_color : source_color = vec3(0.35, 0.23, 0.145);
uniform vec3 tip_color : source_color = vec3(0.29, 0.18, 0.11);
uniform float band_pos : hint_range(0.0, 1.0) = 0.45;      // where the band colour is reached
uniform float tip_pos : hint_range(0.0, 1.0) = 0.8;        // where the tip colour starts
uniform float fur_length : hint_range(0.0, 0.1) = 0.02;    // m, shells
uniform float guard_length : hint_range(0.0, 1.5) = 1.0;   // share of the baked guard-card length
uniform float guard_amount : hint_range(0.0, 1.0) = 1.0;   // share of the guard cards drawn
uniform float density : hint_range(200.0, 4000.0) = 1600.0; // strands per metre
uniform float clump : hint_range(0.0, 1.0) = 0.45;
uniform float clump_size : hint_range(0.002, 0.05) = 0.012; // m
uniform float droop : hint_range(0.0, 1.0) = 0.35;
uniform float comb : hint_range(0.0, 1.0) = 0.5;
uniform float gloss : hint_range(0.0, 1.0) = 0.3;
uniform float root_ao : hint_range(0.0, 1.0) = 0.4;
uniform float strand_aspect : hint_range(0.1, 1.0) = 0.4;  // cell height / width: combed streaks
uniform float variation : hint_range(0.0, 1.0) = 0.5;     // per-strand and per-clump brightness
uniform float belt_flatten : hint_range(0.0, 1.0) = 0.0;
uniform float strap_flatten : hint_range(0.0, 1.0) = 0.0;
uniform float inflate = 0.0;       // m out along the normal: a wrap worn over a coat (PlayerOutfit)
uniform int shell_count = 12;      // the surface's shells (catalog fur.stats.shells)
uniform int shell_stride = 0;      // draw every n-th shell; 0 = by distance (lod_dist)
uniform float lod_dist = 3.0;      // m: half the shells beyond this (the gameplay camera is ~4 m off)
uniform int debug_view = 0;

varying flat uint v_region;
varying flat uint v_zone;
varying float v_h;
varying float v_len;
varying flat int v_stride;

float f_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float f_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(f_hash(i), f_hash(i + vec2(1.0, 0.0)), u.x), mix(f_hash(i + vec2(0.0, 1.0)), f_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

bool fur_hidden(uint r) {
	uint bits = r < 32u ? (hide_mask.x >> r) : (hide_mask.y >> (r - 32u));
	return (bits & 1u) != 0u;
}

vec3 ramp(float t) {
	vec3 c = mix(root_color, band_color, smoothstep(0.0, max(band_pos, 1e-3), t));
	return mix(c, tip_color, smoothstep(tip_pos, 1.0, t));
}

void vertex() {
	uint code = uint(UV2.x + 0.5);
	v_region = code & 63u;
	v_zone = code >> 6u;
	v_h = 1.0 - UV2.y;
	v_len = 1.0;
	VERTEX += normalize(NORMAL) * inflate;
	// shell LOD: beyond lod_dist (the object's origin from the camera) every 2nd shell is drawn,
	// beyond 2.4x that every 3rd, 5x every 4th (one stride for the whole object: a per-vertex
	// choice would tear triangles); the kept shells cover for the missing ones (fragment)
	float od = length(NODE_POSITION_VIEW);
	int stride = shell_stride > 0 ? shell_stride : (od > lod_dist * 5.0 ? 4 : (od > lod_dist * 2.4 ? 3 : (od > lod_dist ? 2 : 1)));
	v_stride = stride;
	int shell_k = int(round(v_h * float(shell_count)));
	if (fur_hidden(v_region) || (v_zone == 0u && stride > 1 && shell_k % stride != 0)) {
		VERTEX = vec3(0.0);
	} else if (v_zone == 0u) {
		float flt = 1.0;
		flt *= mix(1.0, 0.15, belt_flatten * (1.0 - smoothstep(0.02, 0.032, CUSTOM0.x)));
		flt *= mix(1.0, 0.15, strap_flatten * (1.0 - smoothstep(0.011, 0.02, CUSTOM0.y)));
		float len = fur_length * clamp(COLOR.a, 0.0, 1.0) * flt;
		v_len = len;
		vec3 n = normalize(NORMAL);
		vec3 down = normalize((inverse(MODEL_MATRIX) * vec4(0.0, -1.0, 0.0, 0.0)).xyz);
		vec3 t = down - n * dot(down, n);
		float tl = length(t);
		t = tl > 1e-4 ? t / tl : vec3(0.0);
		float h = v_h;
		VERTEX += n * (h * len * (1.0 - 0.5 * comb)) + t * (comb * h * len) + down * (droop * h * h * len);
	}
}

void fragment() {
	float a = 1.0;
	float t = v_h;
	float var = 1.0;
	if (v_zone == 0u) {
		if (!FRONT_FACING) {
			discard;
		}
		vec2 g = UV * density * vec2(1.0, strand_aspect);   // strands lie along the grain (v = down)
		vec2 cell = floor(g);
		vec2 f = fract(g);
		float r1 = f_hash(cell);
		vec2 c = vec2(0.2 + 0.6 * f_hash(cell + 17.3), 0.2 + 0.6 * f_hash(cell + 41.1));
		float cl = f_noise(UV / clump_size);
		float slen = mix(0.5, 1.0, r1) * mix(1.0, 0.45 + 1.1 * cl, clump);
		t = v_h / max(slen, 1e-3);
		float rad = 0.55 * (1.0 - 0.75 * t * t);
		float near_a = (t < 1.0) ? 1.0 - smoothstep(rad * 0.65, rad, length(f - c)) : 0.0;
		// far (strands under a pixel): the expected coverage at this height, dithered so
		// the temporal AA resolves it to a soft pile instead of hard-edged clumps
		float px = length(fwidth(g));
		float lod = max(1.0, px * 0.35);
		float cf = f_noise(UV / (clump_size * lod) + 3.7);
		float cover = clamp(1.25 * (1.0 - v_h / (0.55 + 0.45 * mix(1.0, 0.4 + 1.2 * cf, clump))), 0.0, 1.0);
		cover = 1.0 - pow(1.0 - cover, float(max(v_stride, 1)));   // the shells skipped by the LOD
		// per-frame dither (the game runs temporal AA by default: it averages the pattern)
		float fr = floor(TIME * 60.0);
		float ign = f_hash(FRAGCOORD.xy + vec2(fract(fr * 0.618034) * 173.0, fract(fr * 0.754878) * 311.0));
		float far_a = step(ign, cover);
		a = mix(near_a, far_a, smoothstep(0.7, 1.4, px));
		if (v_len < 1e-4 && v_h > 0.12) {
			a = 0.0;
		}
		// from afar the eye sees mostly the outer, tip-coloured part of the pile
		t = mix(t, clamp(0.4 + 0.75 * v_h, 0.0, 1.0), smoothstep(0.7, 1.4, px));
		var = (1.0 - 0.35 * variation + 0.7 * variation * r1) * (1.0 - 0.25 * variation + 0.5 * variation * cl);
	} else {
		// guard hairs: 2-3 per card, tapering
		float k = UV.x * 420.0;
		float id = floor(k);
		float rr = f_hash(vec2(id, 5.0));
		float cut = guard_length * (0.7 + 0.3 * rr);
		float w = 0.36 * (1.0 - 0.8 * smoothstep(0.0, cut, v_h));
		a = (v_h < cut && rr < guard_amount * 1.02) ? 1.0 - smoothstep(w * 0.55, w, abs(fract(k) - 0.5)) : 0.0;
		t = clamp(v_h / max(cut, 1e-3), 0.0, 1.0) * 0.6 + 0.4;
		var = 0.9 + 0.2 * rr;
	}
	vec3 col = ramp(clamp(t, 0.0, 1.0)) * var;
	col *= mix(root_ao, 1.0, smoothstep(0.0, 0.7, v_h));
	ALBEDO = col;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.3;
	// from afar the pile is a matte mass (its glints average out): less gloss, or it reads as leather
	float gl = gloss * (v_zone == 0u ? mix(1.0, 0.45, smoothstep(0.7, 1.4, length(fwidth(UV * density)))) : 1.0);
	ROUGHNESS = mix(0.82, 0.42, gl);
	SPECULAR = mix(0.25, 0.5, gl);
	BACKLIGHT = col * 0.35;
	if (debug_view == 1) {
		ALBEDO = vec3(float(v_zone), v_h, COLOR.a);
	}
}
