// Thủy Vân ground (style_guide.md 3.3 and 5.2 "Terrain"; vista_spec.md 4 "Splat, painted slices"). A Thủy Vân copy of
// the frontier's ground shader (shaders/terrain/terrain.gdshader, which stays as it is), cut down to what painted
// ground needs:
//   slices    PAINT's painted array (assets/thuyvan/paint/terrain/tv_terrain_albedo_array.webp, terrain_slices.json):
//             RGB = albedo with the light and occlusion painted in, A = blend height; 12 slices, all tiled at 8 m
//             except the cliff face (slice 10) at 16 m
//   splat     three RGBA weight maps over `splat_rect` (slices 0-3, 4-7, 8-11), a vista's own derived splat (vista_spec 4);
//             weights need not sum to 1 (they are normalised); outside the rect, `fallback_slice`
//   rock      triplanar cliff face over `rock_slope_deg` (38), strata horizontal, faded in over a few degrees; built
//             ground (terrace rice, laterite banks, paddy mud) keeps its own slice on its risers
//   blend     height-blended by the array's A (depth `blend_depth`, 0.25: soft painted edges, never mush)
//   tiling    anti-tiling kept at 2.7x rotated 37 deg, chosen by a large-scale noise; macro variation +-12 % value and
//             +-8 deg hue over 60-250 m (procedural value noise: no texture to ship)
//   light     flat: no normal array, the mesh's own normal (or, on the frontier's chunk meshes, the baked normal map);
//             roughness 0.95, low specular, Lambert wrap; the paint carries the light
// Two ways to draw ground:
//   a mesh    (use_height_map false) any ground mesh at its real heights: the vista's stitched bake cells, a look scene
//   chunks    (use_height_map true) the frontier's flat chunk grids lifted by `height_map` exactly as terrain.gdshader
//             does (grid_half, grid_size, square_origin, skirt_depth), the normal from `terrain_normal`
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2DArray albedo_array : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D splat0 : filter_linear, repeat_disable;   // slices 0-3: grass, terrace rice, forest floor, dirt path
uniform sampler2D splat1 : filter_linear, repeat_disable;   // slices 4-7: laterite, paddy mud, karst rock, white stone
uniform sampler2D splat2 : filter_linear, repeat_disable;   // slices 8-11: moss/fern, river bank, cliff face, meadow
uniform vec4 splat_rect = vec4(-512.0, -512.0, 1024.0, 1024.0);   // x0, z0, width, depth (m)
uniform int fallback_slice = 0;

uniform float tile_m = 8.0;
uniform float cliff_tile_m = 16.0;
uniform int cliff_slice = 10;
uniform float rock_slope_deg = 38.0;
uniform float rock_slope_soft_deg = 6.0;
uniform float rock_blend_sharp = 6.0;
uniform float blend_depth = 0.25;
uniform float anti_tiling = 2.7;
uniform float macro_value : hint_range(0.0, 0.3) = 0.12;
uniform float macro_hue_deg : hint_range(0.0, 20.0) = 8.0;
uniform float roughness_ground : hint_range(0.0, 1.0) = 0.95;
uniform float specular_ground : hint_range(0.0, 1.0) = 0.1;
/// linear multiplier on every slice (look tuning without repainting)
uniform vec3 tint : source_color = vec3(1.0);
/// linear multiplier on the cliff face alone (R1 warms its gorge walls toward the sheets' warm grey limestone)
uniform vec3 cliff_tint = vec3(1.0);
/// the cliff face's tile stretched this much along the wall (1: square): wide plates read as level strata
uniform float cliff_stretch = 1.0;

uniform bool use_height_map = false;
uniform sampler2D height_map : filter_nearest, repeat_disable;
uniform sampler2D terrain_normal : filter_linear_mipmap, repeat_disable;   // n.x, n.z (0..1), as the frontier's
uniform float grid_half = 416.0;
uniform float grid_size = 833.0;
uniform vec2 square_origin = vec2(0.0);
uniform float skirt_depth = 1.5;

varying vec3 v_world;
varying vec3 v_wn;

void vertex() {
	if (use_height_map) {
		vec3 w = (MODEL_MATRIX * vec4(VERTEX.x, 0.0, VERTEX.z, 1.0)).xyz;
		int n = int(grid_size);
		ivec2 t = clamp(ivec2(round(w.xz - square_origin + grid_half)), ivec2(0), ivec2(n - 1));
		float h = texelFetch(height_map, t, 0).r;
		float skirt = -VERTEX.y;
		VERTEX.y = h - skirt * skirt_depth - MODEL_MATRIX[3].y;
		vec2 uv = (w.xz - square_origin + grid_half + 0.5) / grid_size;
		vec2 nxz = textureLod(terrain_normal, uv, 0.0).rg * 2.0 - 1.0;
		NORMAL = vec3(nxz.x, sqrt(max(1.0 - dot(nxz, nxz), 0.0)), nxz.y);
		v_world = vec3(w.x, h, w.z);
		v_wn = NORMAL;
	} else {
		v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 hue_rotate(vec3 c, float a) {
	const vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

// One ground slice at xz: the tile, and where the large-scale noise says so the 2.7x tile turned 37 deg (both fetched
// only in the band between), mixed by blend height so the two keep their strokes.
vec4 slice_at(int s, vec2 xz, float tile, float m) {
	float k = smoothstep(0.42, 0.58, m);
	const mat2 R = mat2(vec2(0.7986, 0.6018), vec2(-0.6018, 0.7986));
	vec4 a = vec4(0.0);
	vec4 b = vec4(0.0);
	if (k < 0.999) {
		a = texture(albedo_array, vec3(xz / tile, float(s)));
	}
	if (k > 0.001) {
		b = texture(albedo_array, vec3((R * xz) / (tile * anti_tiling) + vec2(0.31, 0.17), float(s)));
	}
	if (k <= 0.001) {
		return a;
	}
	if (k >= 0.999) {
		return b;
	}
	float hk = clamp(k + (b.a - a.a) * 0.5 * (1.0 - abs(2.0 * k - 1.0)), 0.0, 1.0);
	return mix(a, b, hk);
}

// The cliff face slice, world triplanar; its top (-V) up, so the strata run level on every wall.
vec4 cliff_at(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(rock_blend_sharp));
	w /= max(w.x + w.y + w.z, 1e-5);
	float s = float(cliff_slice);
	vec4 c = vec4(0.0);
	vec2 st = vec2(cliff_tile_m * cliff_stretch, cliff_tile_m);
	if (w.x > 0.01) c += w.x * texture(albedo_array, vec3(vec2(p.z * sign(n.x), -p.y) / st, s));
	if (w.y > 0.01) c += w.y * texture(albedo_array, vec3(p.xz / cliff_tile_m, s));
	if (w.z > 0.01) c += w.z * texture(albedo_array, vec3(vec2(-p.x * sign(n.z), -p.y) / st, s));
	return c / max(w.x * step(0.01, w.x) + w.y * step(0.01, w.y) + w.z * step(0.01, w.z), 1e-4);
}

void fragment() {
	vec3 wp = v_world;
	vec2 xz = wp.xz;
	vec3 N = normalize(v_wn);

	float w[12];
	vec2 suv = (xz - splat_rect.xy) / splat_rect.zw;
	bool inside = suv.x >= 0.0 && suv.y >= 0.0 && suv.x <= 1.0 && suv.y <= 1.0;
	vec4 s0 = inside ? texture(splat0, suv) : vec4(0.0);
	vec4 s1 = inside ? texture(splat1, suv) : vec4(0.0);
	vec4 s2 = inside ? texture(splat2, suv) : vec4(0.0);
	w[0] = s0.r; w[1] = s0.g; w[2] = s0.b; w[3] = s0.a;
	w[4] = s1.r; w[5] = s1.g; w[6] = s1.b; w[7] = s1.a;
	w[8] = s2.r; w[9] = s2.g; w[10] = s2.b; w[11] = s2.a;
	float total = 0.0;
	for (int i = 0; i < 12; i++) total += w[i];
	if (total < 0.01) {
		for (int i = 0; i < 12; i++) w[i] = 0.0;
		w[clamp(fallback_slice, 0, 11)] = 1.0;
		total = 1.0;
	}

	// steep ground turns to the cliff face (built ground keeps its own slice on its risers)
	float slope = degrees(acos(clamp(N.y, -1.0, 1.0)));
	float rock = smoothstep(rock_slope_deg - rock_slope_soft_deg * 0.5, rock_slope_deg + rock_slope_soft_deg * 0.5, slope);
	rock *= 1.0 - clamp((w[1] + w[4] + w[5]) / total, 0.0, 1.0);

	float m_anti = vnoise(xz / 37.0) * 0.7 + vnoise(xz / 9.0) * 0.3;

	// pass 1: fetch the slices present (and the cliff face), keep the highest weight + height
	const float TH = 0.03;
	vec4 c[12];
	float hmax = -1.0;
	for (int i = 0; i < 12; i++) {
		c[i] = vec4(0.0);
		w[i] = w[i] / total * (1.0 - rock);
		if (w[i] > TH) {
			c[i] = slice_at(i, xz, i == cliff_slice ? cliff_tile_m : tile_m, m_anti);
			hmax = max(hmax, w[i] + c[i].a * 0.35);
		}
	}
	vec4 cr = vec4(0.0);
	if (rock > TH) {
		cr = cliff_at(wp, N);
		cr.rgb *= cliff_tint;
		hmax = max(hmax, rock + cr.a * 0.35);
	}
	// pass 2: height blend
	vec3 acc = vec3(0.0);
	float accw = 0.0;
	for (int i = 0; i < 12; i++) {
		if (w[i] > TH) {
			float b = max(w[i] + c[i].a * 0.35 - hmax + blend_depth, 0.0);
			acc += c[i].rgb * b;
			accw += b;
		}
	}
	if (rock > TH) {
		float b = max(rock + cr.a * 0.35 - hmax + blend_depth, 0.0);
		acc += cr.rgb * b;
		accw += b;
	}
	vec3 albedo = acc / max(accw, 1e-4);

	// macro variation: +-12 % value and +-8 deg hue over 60-250 m
	float mv = vnoise(xz / 250.0 + 3.7) * 0.6 + vnoise(xz / 90.0 + 11.3) * 0.4;
	float mh = vnoise(xz / 160.0 + 7.1) * 0.7 + vnoise(xz / 60.0 + 1.9) * 0.3;
	albedo *= 1.0 + macro_value * (mv - 0.5) * 2.0;
	albedo = max(hue_rotate(albedo, radians(macro_hue_deg) * (mh - 0.5) * 2.0), vec3(0.0));

	ALBEDO = albedo * tint;
	ROUGHNESS = roughness_ground;
	SPECULAR = specular_ground;
	METALLIC = 0.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(N, 0.0)).xyz);
}
