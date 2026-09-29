// Frontier ground (look-dev spec, section 5.4). Package B.
//
// One material for every terrain chunk. The chunk meshes are flat shared grids (1/2/4/8 m
// spacing); vertex() lifts each vertex to the baked height field (texelFetch of the same RF
// data the collision and FrontierTerrain.height_at use, same triangle diagonal), and skirt
// vertices (mesh y = -1) drop skirt_depth below it to hide LOD cracks.
//
// fragment(): per-pixel splat of six ground layers from the baked control maps (1 m), refined
// by a 0.25 m detail map over the fort and range (ruts, worn paths, crisp dirt edges), with
//   * height-blended transitions (layer height in the albedo alpha)
//   * anti-tiling on grass, dirt and forest floor (second rotated sample at 2.7x the tile,
//     mixed by macro noise), detail normals fading out by detail_fade_end
//   * macro variation (+-8 % value, +-4 deg hue over ~200 m)
//   * triplanar rock on slopes over 35 deg
//   * canopy darkening under the forest for the presets without GI
//   * the forest canopy's light (canopy.gdshaderinc): less sky light under the crowns, and the light the
//     leaves scatter down (one fetch of the canopy map)
// Texture budget per pixel: 6 control fetches (splat x2, normal, detail, macro x2) + ~4-8 layer
// fetches in single-layer areas, up to ~14 in blends near the camera, ~3-5 far.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/common/canopy.gdshaderinc"
#include "res://shaders/common/snow.gdshaderinc"

// The broadleaves' year (scripts/snow/season_leaves.gd; shaders/vegetation/leaf_season.gdshaderinc): the forest floor's
// ground cover and fallen leaves follow it.
global uniform float leaf_season;

// How green the forest floor's ground cover is at leaf_season `s` (user 2026-09-28: "after the buds we need to make the
// forest floor not dirt maybe green"): full through the summer, a little faded in the autumn, dying back as the leaves
// come down on it, none in winter, greening again once the buds break.
float forest_green(float s) {
	if (s < 1.0) {
		return 1.0 - 0.25 * s;
	}
	if (s < 2.0) {
		return 0.75 * (1.0 - smoothstep(1.0, 1.7, s));
	}
	return smoothstep(2.1, 2.6, s);
}

// How cured the open ground's grass is at `s` (grass.gdshader grass_cure): the meadows tan through the autumn and the
// winter, green again after the buds.
float ground_cure(float s) {
	if (s < 1.0) {
		return 0.45 * smoothstep(0.2, 1.0, s);
	}
	if (s < 2.0) {
		return mix(0.45, 1.0, smoothstep(1.0, 1.8, s));
	}
	return 1.0 - smoothstep(2.1, 2.6, s);
}

uniform sampler2D height_map : filter_nearest, repeat_disable;
uniform sampler2D splat0 : filter_linear_mipmap, repeat_disable;         // grass, dry, dirt, mud
uniform sampler2D splat1 : filter_linear_mipmap, repeat_disable;         // forest, rock, density, grass h
uniform sampler2D terrain_normal : filter_linear_mipmap, repeat_disable; // n.x, n.z, AO, litter
uniform sampler2D core_map : filter_linear_mipmap, repeat_disable;       // mud, wear, dirt, grass h
uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2DArray albedo_array : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray nrm_array : filter_linear_mipmap, repeat_enable;   // no aniso: fades by 60 m

uniform float grid_half = 416.0;
uniform float grid_size = 833.0;
uniform vec2 square_origin = vec2(0.0);   // this material's square's middle (FrontierTerrain: squares of ground side by side)
uniform vec4 core_rect = vec4(-32.0, -184.0, 64.0, 216.0);   // x0, z0, width, depth (m)
uniform float skirt_depth = 1.5;
uniform bool detail = true;                  // WorldSettings.terrain_detail
uniform float detail_fade_end = 60.0;        // detail normals / anti-tiling gone by here (m)
uniform float canopy_darkening = 0.0;        // 0.25 on the presets without GI
uniform float blend_depth = 0.18;            // height-blend sharpness (smaller = crisper)
// Linear albedo multipliers per layer (look tuning without re-encoding the arrays). The grass
// ground is pulled toward the grass cards' colour so the grass fade-out is invisible.
uniform vec3 grass_ground_tint = vec3(0.60, 0.84, 0.66);
uniform vec3 dry_ground_tint = vec3(0.86, 0.76, 0.74);
uniform vec3 dirt_tint = vec3(0.90, 0.95, 1.0);
uniform vec3 mud_tint = vec3(1.35, 1.3, 1.25);
uniform vec3 needle_tint = vec3(0.80, 0.64, 0.50);   // rust-brown conifer needle litter
uniform float path_wear = 0.55;                      // wear on dirt outside the detail map

// Tile sizes (m) per layer.
const float TILE_GRASS_MACRO = 15.0;
const float TILE_DETAIL = 2.5;
const float TILE_DIRT = 3.0;
const float TILE_MUD = 3.0;
const float TILE_FOREST = 3.0;
const float TILE_ROCK = 4.0;
const float TILE_LEAVES = 2.5;

const float L_GRASS = 0.0;
const float L_DRY = 1.0;
const float L_DIRT = 2.0;
const float L_MUD = 3.0;
const float L_FOREST = 4.0;
const float L_ROCK = 5.0;
const float L_LEAVES = 6.0;

varying vec3 v_world;

void vertex() {
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
}

void sample_layer(float layer, vec2 p, float tile, bool anti, float m, bool near,
		out vec4 alb, out vec4 nrm) {
	// Anti-tiling: two decorrelated projections (tile, and 2.7x tile rotated 37 deg) chosen by
	// macro noise; both are fetched only inside a narrow transition band, elsewhere just one.
	float k = anti ? smoothstep(0.44, 0.56, m) : 0.0;
	const mat2 R = mat2(vec2(0.7986, 0.6018), vec2(-0.6018, 0.7986));
	vec2 uv1 = p / tile;
	vec2 uv2 = (R * p) / (tile * 2.7) + vec2(0.31, 0.17);
	if (k < 0.999) {
		alb = texture(albedo_array, vec3(uv1, layer));
		nrm = near ? texture(nrm_array, vec3(uv1, layer)) : vec4(0.5, 0.5, 0.8, 1.0);
	}
	if (k > 0.001) {
		vec4 a2 = texture(albedo_array, vec3(uv2, layer));
		vec4 n2 = vec4(0.5, 0.5, 0.8, 1.0);
		if (near) {
			n2 = texture(nrm_array, vec3(uv2, layer));
			vec2 d2 = transpose(R) * (n2.rg * 2.0 - 1.0);   // back into the world tangent frame
			n2.rg = d2 * 0.5 + 0.5;
		}
		if (k >= 0.999) {
			alb = a2;
			nrm = n2;
		} else {
			// Height-aware mix keeps contrast instead of averaging two images to mush.
			float hk = clamp(k + (a2.a - alb.a) * 0.5 * (1.0 - abs(2.0 * k - 1.0)), 0.0, 1.0);
			alb = mix(alb, a2, hk);
			nrm = mix(nrm, n2, hk);
		}
	}
}

vec3 hue_rotate(vec3 c, float a) {
	// Rotate chroma around the grey axis (YIQ-like), a in radians.
	const vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 xz = wp.xz;
	float dist = length(VERTEX);
	bool near = detail && dist < detail_fade_end;
	float near_k = detail ? 1.0 - smoothstep(detail_fade_end * 0.66, detail_fade_end, dist) : 0.0;

	vec2 uv = (xz - square_origin + grid_half + 0.5) / grid_size;
	vec4 s0 = texture(splat0, uv);
	vec4 s1 = texture(splat1, uv);
	vec4 tn = texture(terrain_normal, uv);
	float wear = path_wear;

	// 0.25 m detail over the fort and range: crisp dirt/mud and wear; the base map keeps the
	// grass / dry / forest / rock proportions of whatever is left.
	vec2 cuv = (xz - core_rect.xy) / core_rect.zw;
	if (cuv.x > 0.0 && cuv.y > 0.0 && cuv.x < 1.0 && cuv.y < 1.0) {
		vec4 c = texture(core_map, cuv);
		vec2 e = min(cuv, 1.0 - cuv) * core_rect.zw;
		float k = clamp(min(e.x, e.y) * 0.5, 0.0, 1.0);
		float dirt = mix(s0.b, c.b, k);
		float mud = mix(s0.a, c.r, k);
		float rest_base = s0.r + s0.g + s1.r + s1.g;
		float rest = max(1.0 - dirt - mud, 0.0);
		if (rest_base < 0.004) {
			s0.r = rest;
		} else {
			float sc = rest / rest_base;
			s0.r *= sc; s0.g *= sc; s1.r *= sc; s1.g *= sc;
		}
		s0.b = dirt;
		s0.a = mud;
		wear = c.g * k;
	}

	vec4 mn = texture(macro_noise, xz / 256.0);            // periods 128, 64, 16, 4 m
	vec4 mnb = texture(macro_noise, xz / 1024.0 + 0.37);   // periods 512, 256, 64, 16 m
	float anti_m = mn.b * 0.7 + mn.a * 0.3;

	// Terrain normal and tangent frame (tangent along world +X, bitangent toward -Z, matching
	// the OpenGL-convention nor_gl maps with uv = world xz / tile).
	vec2 bn = tn.rg * 2.0 - 1.0;
	vec3 N = normalize(vec3(bn.x, sqrt(max(1.0 - dot(bn, bn), 0.0)), bn.y));
	vec3 T = normalize(vec3(1.0, 0.0, 0.0) - N * N.x);
	vec3 B = cross(N, T);

	float w_grass = s0.r, w_dry = s0.g, w_dirt = s0.b, w_mud = s0.a;
	float w_forest = s1.r, w_rock = s1.g;
	float density = s1.b;

	vec3 acc_c = vec3(0.0);
	vec2 acc_n = vec2(0.0);
	float acc_r = 0.0, acc_ao = 0.0, acc_w = 0.0;
	// Pass 1: sample the layers present; keep (colour, normal, rough, ao, weight+height).
	vec4 ca[6];
	vec4 na[6];
	float wa[6];
	float hmax = -1.0;
	const float TH = 0.03;   // layers below 3 % never survive the height blend: skip their fetches

	// Shared close detail for grass and dry grass: forest_ground_04 at 2.5 m.
	vec4 det_a = vec4(0.5), det_n = vec4(0.5, 0.5, 0.8, 1.0);
	if (w_grass + w_dry > TH) {
		det_a = texture(albedo_array, vec3(xz / TILE_DETAIL, L_FOREST));
		if (near) det_n = texture(nrm_array, vec3(xz / TILE_DETAIL, L_FOREST));
	}
	float det_lum = dot(det_a.rgb, vec3(0.3, 0.55, 0.15));

	for (int i = 0; i < 6; i++) { wa[i] = 0.0; ca[i] = vec4(0.0); na[i] = vec4(0.5, 0.5, 0.8, 1.0); }

	if (w_grass > TH) {
		vec4 a, n;
		sample_layer(L_GRASS, xz, TILE_GRASS_MACRO, near, anti_m, false, a, n);
		a.rgb *= mix(1.0, 0.72 + 0.62 * det_lum, near_k * 0.8 + 0.2) * grass_ground_tint;
		a.rgb = mix(vec3(dot(a.rgb, vec3(0.2126, 0.7152, 0.0722))), a.rgb, 0.8);   // tame the lime patches
		a.rgb = mix(a.rgb, vec3(dot(a.rgb, vec3(0.2126, 0.7152, 0.0722))) * vec3(1.3, 1.0, 0.6), ground_cure(leaf_season) * 0.8);
		ca[0] = vec4(a.rgb, det_a.a);
		na[0] = vec4(det_n.rg, 0.9 * det_n.b + 0.1, det_n.a);
		wa[0] = w_grass;
	}
	if (w_dry > TH) {
		vec4 a, n;
		sample_layer(L_DRY, xz, TILE_GRASS_MACRO, near, anti_m, false, a, n);
		a.rgb *= mix(1.0, 0.72 + 0.62 * det_lum, near_k * 0.8 + 0.2) * dry_ground_tint;
		ca[1] = vec4(a.rgb, det_a.a);
		na[1] = vec4(det_n.rg, 0.95, det_n.a);
		wa[1] = w_dry;
	}
	if (w_dirt > TH) {
		vec4 a, n;
		sample_layer(L_DIRT, xz, TILE_DIRT, near, anti_m, near, a, n);
		// Worn paths: darker, compacted, a touch smoother.
		a.rgb *= dirt_tint * (1.0 - 0.34 * wear) * (1.0 - 0.1 * wear * (mn.a - 0.5));
		n.b = clamp(n.b - 0.12 * wear, 0.0, 1.0);
		ca[2] = a;
		na[2] = n;
		wa[2] = w_dirt;
	}
	if (w_mud > TH) {
		vec4 a, n;
		sample_layer(L_MUD, xz, TILE_MUD, false, anti_m, near, a, n);
		a.rgb *= mud_tint;
		n.b *= 0.62;   // damp: glossier than the dry earth around it
		ca[3] = vec4(a.rgb, a.a * 0.6);   // low blend height: mud pools in the dirt, no raised rim
		na[3] = n;
		wa[3] = w_mud;
	}
	if (w_forest > TH) {
		vec4 a, n;
		sample_layer(L_FOREST, xz, TILE_FOREST, near, anti_m, near, a, n);
		// Broadleaf share (terrain_normal.a): leaf litter in noisy 20-35 % patches under
		// broadleaf trees; rust-tinted needle litter (the base texture) under conifers.
		float broad = clamp(tn.a + (mnb.b - 0.5) * 0.4, 0.0, 1.0);
		a.rgb *= mix(needle_tint, vec3(0.92, 0.9, 0.86), broad);
		float litter = broad * (0.45 + 0.9 * (mn.b - 0.5) + 0.5 * (mn.a - 0.5));
		if (litter > 0.3) {
			vec2 luv = xz / TILE_LEAVES;
			vec4 la = texture(albedo_array, vec3(luv, L_LEAVES));
			float lk = smoothstep(0.35, 0.6, litter + (la.a - a.a) * 0.35);
			a = mix(a, la, lk);
			if (near) n = mix(n, texture(nrm_array, vec3(luv, L_LEAVES)), lk);
		}
		// Ground cover over the litter: moss, wood sorrel, herbs and seedlings in patches, thickest where the canopy
		// lets the light down, by the season (forest_green); under the broadleaves this autumn's fallen leaves, fresh
		// rust and orange as they come down, browning through the winter.
		float gs = forest_green(leaf_season);
		if (gs > 0.001) {
			float patch = smoothstep(0.3, 0.7, mn.g * 0.35 + mn.b * 0.4 + mn.a * 0.25 + (1.0 - density) * 0.2);
			float lum = dot(a.rgb, vec3(0.3, 0.59, 0.11));
			vec3 moss = mix(vec3(0.045, 0.085, 0.018), vec3(0.085, 0.125, 0.03), mn.r) * clamp(lum / 0.11, 0.75, 1.2);
			a.rgb = mix(a.rgb, moss, gs * mix(0.3, 0.95, patch));
		}
		float fallen = broad * smoothstep(1.0, 1.5, leaf_season) * (1.0 - smoothstep(2.0, 2.45, leaf_season));
		a.rgb = mix(a.rgb, a.rgb * vec3(1.45, 0.82, 0.42), fallen * 0.75);
		ca[4] = a;
		na[4] = n;
		wa[4] = w_forest;
	}
	if (w_rock > TH) {
		vec4 a, n;
		if (N.y < 0.82 && near) {
			// Triplanar on steep ground.
			vec3 bw = pow(abs(N), vec3(4.0));
			bw /= bw.x + bw.y + bw.z;
			vec4 ax = texture(albedo_array, vec3(wp.zy / TILE_ROCK, L_ROCK));
			vec4 ay = texture(albedo_array, vec3(wp.xz / TILE_ROCK, L_ROCK));
			vec4 az = texture(albedo_array, vec3(wp.xy / TILE_ROCK, L_ROCK));
			a = ax * bw.x + ay * bw.y + az * bw.z;
			n = vec4(0.5, 0.5, 0.8, 0.85);
			n.b = texture(nrm_array, vec3(wp.xz / TILE_ROCK, L_ROCK)).b;
		} else {
			sample_layer(L_ROCK, xz, TILE_ROCK, false, anti_m, near, a, n);
		}
		ca[5] = a;
		na[5] = n;
		wa[5] = w_rock;
	}

	// Height-based blend.
	for (int i = 0; i < 6; i++) {
		if (wa[i] > 0.0) hmax = max(hmax, wa[i] + ca[i].a * 0.35);
	}
	for (int i = 0; i < 6; i++) {
		if (wa[i] <= 0.0) continue;
		float b = max(wa[i] + ca[i].a * 0.35 - hmax + blend_depth, 0.0);
		acc_c += ca[i].rgb * b;
		acc_n += (na[i].rg * 2.0 - 1.0) * b;
		acc_r += na[i].b * b;
		acc_ao += na[i].a * b;
		acc_w += b;
	}
	acc_w = max(acc_w, 1e-4);
	vec3 albedo = acc_c / acc_w;
	vec2 dn = acc_n / acc_w;
	float rough = acc_r / acc_w;
	float ao = acc_ao / acc_w;

	// Macro variation: +-8 % value, +-4 deg hue.
	float mv = (mnb.g - 0.5) * 2.0;
	albedo *= 1.0 + 0.08 * mv + 0.04 * (mn.r - 0.5);
	albedo = max(hue_rotate(albedo, radians(4.0) * (mnb.r - 0.5) * 2.0), vec3(0.0));
	// Canopy darkening for the presets without GI.
	albedo *= 1.0 - canopy_darkening * density;
	rough = clamp(rough + canopy_darkening * density * 0.2, 0.3, 1.0);

	// Snow (snow.gdshaderinc; scripts/snow): over the ground by the core's depth, thinner under the crowns and on the
	// trodden dirt of the paths, pressed down where feet went (the trail map round the player): a print shows its
	// blue-shaded sides, and the ground through it where the snow is thin.
	// By the land's region (snow_land): the open plains scoured, drifted and rippled by the wind, the woods deep and even,
	// the cliffs' faces bare.
	float snow = 0.0;
	vec2 sgrad = vec2(0.0);
	vec2 rgrad = vec2(0.0);
	if (snow_cover > 0.001) {
		float sk, se;
		snow = snow_land(wp, N, 1.0 - density, sk, se) * (1.0 - 0.5 * density) * (1.0 - 0.6 * clamp(wear, 0.0, 1.0));
		if (snow > 0.001 && se > 0.05) {
			rgrad = snow_ripple_grad(xz, se) * smoothstep(0.3, 0.8, sk) * (near ? 1.0 : 0.4);
		}
		if (snow > 0.001) {
			float pressed = snow_pressed(xz);
			sgrad = near ? snow_ground_grad(pressed, wp) : vec2(0.0);
			vec3 sc = snow_albedo(wp);
			sc = mix(sc, sc * SNOW_SHADE, pressed * 0.55);
			float through = pressed * (1.0 - smoothstep(0.08, 0.45, snow_cover));
			albedo = mix(albedo, sc, snow * (1.0 - through * 0.7));
			rough = mix(rough, mix(0.62, 0.9, snow_fresh), snow);
			ao = mix(ao, 1.0, snow * 0.5);
		}
	}

	vec3 n_world = N;
	if (near) {
		dn *= near_k;
		n_world = normalize(N + T * dn.x + B * dn.y);
	}
	if (snow > 0.001) {
		// the snow smooths the ground's detail; a print's sides tilt (the surface is the print's depth lower in it)
		n_world = normalize(mix(n_world, N, snow * 0.8) + vec3(sgrad.x * 0.05 + rgrad.x, 0.0, sgrad.y * 0.05 + rgrad.y) * snow);
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	METALLIC = 0.0;
	float ao_all = clamp(ao * mix(1.0, tn.b, 0.85), 0.0, 1.0);
	// Under the forest canopy: the crowns take part of the sky light (and its reflections) and scatter
	// some of the sun down, green-gold (canopy.gdshaderinc; neutral without the forest light).
	float cc = canopy_cover(xz);
	AO = ao_all * canopy_sky_factor(cc, 1.0);
	EMISSION = albedo * canopy_scatter(cc, 1.0, n_world.y) * ao_all;
	AO_LIGHT_AFFECT = 0.15;
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
}
