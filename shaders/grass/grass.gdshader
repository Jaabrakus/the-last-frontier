// Frontier grass tufts (look-dev spec, section 5.5). Package B. Used by FrontierGrass
// (scripts/world/terrain/grass.gd): MultiMesh cells of a fixed jittered pattern; this shader
// derives everything else per tuft from the terrain maps and world-position hashes.
//
// Per tuft (vertex): ground height (same triangle split as the terrain), local density
// (meadow 1, forest floor 0.3, bare dirt / mud / rock 0), grass height, variant (photo tufts,
// seed heads, dry blades, short mowed tufts, woodland sedge), size, yaw, mirror, dry/green tint,
// distance falloff (instances ranked by INSTANCE_ID: rank < density keeps them; they grow in
// over a small margin so camera movement never pops them), then wind (frontier_wind) and
// trampling round the player (frontier_trample). Hidden tufts collapse to a point.
// Shading: alpha-scissored atlas (alpha kept up in the mips), normals bent to the ground's so
// grass lights like the ground under it, darker and cooler at the root, translucent
// (BACKLIGHT, stronger toward the sun via frontier_backlight). No shadows cast (node setting).
// Under the forest canopy (canopy.gdshaderinc, per tuft): less sky light, the light the leaves scatter down.
// Under snow (snow.gdshaderinc): a tuft no taller than the snow's depth is buried (hidden); a taller one stands out of
// the snow, its root at the snow's surface.

shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_disabled, world_vertex_coords;

#include "res://shaders/common/wind.gdshaderinc"
#include "res://shaders/common/canopy.gdshaderinc"
#include "res://shaders/common/snow.gdshaderinc"

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D height_map : filter_nearest, repeat_disable;
uniform sampler2D splat0 : filter_linear, repeat_disable;
uniform sampler2D splat1 : filter_linear, repeat_disable;
uniform sampler2D terrain_normal : filter_linear, repeat_disable;
uniform sampler2D core_map : filter_linear, repeat_disable;
// Grass blocker map (FrontierGrass.blocker_map): 1 under solid footprints (structures, trunks,
// stumps, logs, rocks), so no tuft grows through them. Black (no blocking) until it is set.
uniform sampler2D blocker_map : hint_default_black, filter_nearest, repeat_disable;
uniform vec4 blocker_rect = vec4(-400.0, -400.0, 800.0, 800.0);

uniform float grid_half = 416.0;
uniform float grid_size = 833.0;
uniform vec2 square_origin = vec2(0.0);   // this material's square's middle (FrontierTerrain: squares of ground side by side)
uniform vec4 core_rect = vec4(-32.0, -184.0, 64.0, 216.0);
uniform float grass_h_scale = 0.8;
uniform float grass_distance = 55.0;
uniform float full_density_dist = 12.0;
uniform float density_scale = 1.0;
uniform float pattern_n = 625.0;
uniform vec4 variant_rects[16];
uniform float variant_aspects[16];
/// The herbs and wildflowers (tools/environment/terrain/make_herb_atlas.py): their atlas and cells; herb_chance scales
/// how many tufts become one (0: none).
uniform sampler2D herb_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 herb_rects[16];
uniform float herb_aspects[16];
uniform float herb_chance = 1.0;
// Late-summer colouring (multiplies the atlas).
uniform vec3 green_tint = vec3(1.0, 1.0, 0.72);    // linear multipliers
uniform vec3 dry_tint = vec3(1.7, 1.18, 0.45);
uniform float width_scale = 0.6;
uniform float meadow_density = 0.75;  // fraction of the 9.8 / m2 pattern used on open meadow

varying vec2 v_uv;
varying float v_y;
varying vec3 v_tint;
varying vec3 v_world;
varying float v_root;     // how dark the root gets (tall grass more than mowed turf)
varying float v_canopy;   // crown cover over the tuft (canopy.gdshaderinc)
varying float v_straw;    // 0 the grass's own colour .. 1 cured straw (the season, the snow)
varying flat int v_herb;  // 1: a herb or wildflower card (herb_atlas), 0: a grass tuft

// The year's grass (leaf_season, scripts/snow/season_leaves.gd; user 2026-09-28: the seasons as "a world thing"): it
// cures to straw through the autumn, stands dead and tan all winter (out of the snow), and greens again after the buds.
global uniform float leaf_season;
const vec3 STRAW = vec3(0.3, 0.215, 0.1);

// Herbs and wildflowers (user 2026-09-28: "add a procdure grass thing right that will save us cpu and gpu? with chance
// for herbs and etc"): some of the tufts the pattern already draws are a plant instead, by chance and in drifts, with no
// placement on the CPU and no instances of their own: under the trees fern beds, wood sorrel, mayapples and the spring's
// trilliums and violets; in the open meadow drifts of black-eyed Susans and wild bergamot in the summer, asters and
// goldenrod from August into October. Each in its days of the year (season_day), each plant a day or so early or late.
global uniform float season_day;

bool herb_in(float d, float a, float b, float r) {
	return d > a + r && d < b - (1.0 - r);
}

/// The herb at xz (a herb_atlas cell) or -1 for a grass tuft; `size` its height (m), `turned` a fern's autumn colour.
int pick_herb(vec2 xz, float forest, float meadow_h, out float size, out float turned) {
	size = 0.0;
	turned = 0.0;
	if (herb_chance <= 0.0) {
		return -1;
	}
	float d = season_day;
	float roll = frontier_hash(xz * 2.31 + vec2(7.7, 1.9)) / herb_chance;
	float kind = frontier_hash(xz * 0.913 - vec2(4.4, 8.1));
	float own = frontier_hash(xz * 1.37 + vec2(2.2, -6.3));
	float bed = smoothstep(0.4, 0.72, snow_vnoise(xz / 9.0 + 5.0));
	float drift = smoothstep(0.42, 0.75, snow_vnoise(xz / 23.0 - 3.0));
	int two = int(fract(kind * 7.3) * 1.999);
	if (forest > 0.5) {
		if (roll < 0.7 * bed) {
			// a fern bed: up from late April, golden then russet in the autumn, died back by late November
			float s = leaf_season;
			float up = s < 1.0 ? 1.0 : (s < 2.0 ? 1.0 - smoothstep(1.2, 1.85, s + (own - 0.5) * 0.3) : smoothstep(2.15, 2.65, s + (own - 0.5) * 0.3));
			if (up < 0.05) {
				return -1;
			}
			size = mix(0.35, 0.7, kind) * up;
			turned = s < 1.0 ? smoothstep(0.35, 1.0, s + (own - 0.5) * 0.3) * 0.7 : (s < 2.0 ? 1.0 : 0.0);
			return int(kind * 3.999);
		}
		if (roll < 0.7 * bed + 0.25 * drift) {
			if (kind < 0.4) {
				size = 0.11;
				return herb_in(d, 11.0, 31.0, own) ? 4 : -1;       // wood sorrel
			}
			if (kind < 0.65) {
				size = 0.4;
				return herb_in(d, 10.5, 22.0, own) ? 5 : -1;       // mayapple
			}
			if (kind < 0.85) {
				size = 0.28;
				return herb_in(d, 10.0, 13.5, own) ? 6 : -1;       // trillium
			}
			size = 0.12;
			return herb_in(d, 10.0, 14.5, own) ? 7 : -1;           // violets
		}
		return -1;
	}
	if (meadow_h < 0.24 || roll > 0.28 * drift) {
		return -1;   // (not on the mowed turf)
	}
	// (a wildflower holds its head just over the meadow's grass)
	float over = meadow_h * (1.3 + 0.3 * own);
	if (kind < 0.25) {
		size = max(0.6, over);
		return herb_in(d, 16.0, 25.5, own) ? 12 + two : -1;         // black-eyed Susans
	}
	if (kind < 0.5) {
		size = max(0.7, over);
		return herb_in(d, 18.0, 23.5, own) ? 14 + two : -1;         // wild bergamot
	}
	if (kind < 0.75) {
		size = max(0.7, over);
		return herb_in(d, 22.0, 29.5, own) ? 8 + two : -1;          // asters
	}
	size = max(0.9, over * 1.1);
	return herb_in(d, 21.0, 28.5, own) ? 10 + two : -1;             // goldenrod
}

float grass_cure(float s) {
	if (s < 1.0) {
		return 0.45 * smoothstep(0.2, 1.0, s);
	}
	if (s < 2.0) {
		return mix(0.45, 1.0, smoothstep(1.0, 1.8, s));
	}
	return 1.0 - smoothstep(2.1, 2.6, s);
}

float ground_height(vec2 xz) {
	vec2 f = clamp(xz - square_origin + grid_half, vec2(0.0), vec2(grid_size - 1.001));
	ivec2 i = ivec2(floor(f));
	vec2 u = f - vec2(i);
	float h00 = texelFetch(height_map, i, 0).r;
	float h10 = texelFetch(height_map, i + ivec2(1, 0), 0).r;
	float h01 = texelFetch(height_map, i + ivec2(0, 1), 0).r;
	if (u.x + u.y <= 1.0) {
		return h00 + (h10 - h00) * u.x + (h01 - h00) * u.y;
	}
	float h11 = texelFetch(height_map, i + ivec2(1, 1), 0).r;
	return h11 + (h01 - h11) * (1.0 - u.x) + (h10 - h11) * (1.0 - u.y);
}

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	vec2 xz = base.xz;
	// Distance falloff first: most instances of far cells stop here, before any fetch.
	float dist = length(xz - CAMERA_POSITION_WORLD.xz);
	float d1 = max(grass_distance * 0.8, full_density_dist + 1.0);
	float dens = mix(1.0, 0.25, clamp((dist - full_density_dist) / (d1 - full_density_dist), 0.0, 1.0));
	float fade = 1.0 - smoothstep(d1, grass_distance, dist);
	float rank = (float(INSTANCE_ID) + 0.5) / pattern_n;
	float keep = dens * density_scale;
	float grow = 0.0;
	float gh = 0.0, dry_share = 0.0, forest_share = 0.0;
	float sd = 0.0;   // the snow's depth over the tuft (m)
	int hk = -1;      // a herb (herb_atlas cell) in place of the tuft, or -1
	float h_size = 0.0, h_turned = 0.0;
	vec2 uv = (xz - square_origin + grid_half + 0.5) / grid_size;
	if (rank < keep && fade > 0.0) {
		// Ground under the tuft.
		vec4 s0 = textureLod(splat0, uv, 0.0);
		vec4 s1 = textureLod(splat1, uv, 0.0);
		gh = s1.a;
		float dirt = s0.b;
		float mud = s0.a;
		vec2 cuv = (xz - core_rect.xy) / core_rect.zw;
		if (cuv.x > 0.0 && cuv.y > 0.0 && cuv.x < 1.0 && cuv.y < 1.0) {
			vec4 c = textureLod(core_map, cuv, 0.0);
			vec2 e = min(cuv, 1.0 - cuv) * core_rect.zw;
			float k = clamp(min(e.x, e.y) * 0.5, 0.0, 1.0);
			gh = mix(gh, c.a, k);
			dirt = mix(dirt, c.b, k);
			mud = mix(mud, c.r, k);
		}
		float meadow = s0.r + s0.g;
		forest_share = s1.r / max(meadow + s1.r, 1e-3);
		dry_share = s0.g / max(meadow, 1e-3);
		// the woods' herb layer (user 2026-09-28: the forest floor "not dirt maybe green", "more foliage"): woodland
		// grasses, sedges and herbs in patches under the trees, green (not the meadows' dry share)
		float herb = forest_share * smoothstep(0.35, 0.65, snow_vnoise(xz / 7.0 + 11.0));
		gh = max(gh, herb * 0.26 / grass_h_scale);
		dry_share *= 1.0 - 0.85 * forest_share;
		float bare = clamp(dirt + mud + s1.g, 0.0, 1.0);
		// Mowed turf (under 0.24 m) is a closed carpet: full pattern density there.
		float open_density = mix(1.0, meadow_density, smoothstep(0.2, 0.3, gh * grass_h_scale));
		float loc = clamp(1.0 - bare * 1.25, 0.0, 1.0) * mix(open_density, mix(0.3, 0.65, herb), forest_share);
		grow = clamp((keep * loc - rank) * 14.0, 0.0, 1.0) * smoothstep(0.03, 0.07, gh * grass_h_scale) * fade;
		hk = pick_herb(xz, forest_share, gh * grass_h_scale, h_size, h_turned);
		if (hk >= 0) {
			// (its own density: a fern bed or a flower drift whatever the grass there)
			grow = clamp((keep * clamp(1.0 - bare * 1.25, 0.0, 1.0) * 0.55 - rank) * 14.0, 0.0, 1.0) * fade;
		}
		if (textureLod(blocker_map, (xz - blocker_rect.xy) / blocker_rect.zw, 0.0).r > 0.5) {
			grow = 0.0;
		}
		sd = snow_cover * SNOW_FULL_M * (1.0 - 0.5 * forest_share);
		if (sd > 0.0) {
			// the land's snow here (snow_depth_k): the wind-scoured rises let the tall straw through, a drift buries it
			vec2 tb = textureLod(terrain_normal, uv, 0.0).rg * 2.0 - 1.0;
			vec3 tnw = vec3(tb.x, sqrt(max(1.0 - dot(tb, tb), 0.0)), tb.y);
			vec3 rg = snow_region_at(xz);
			sd *= snow_depth_k(xz, tnw, rg, snow_exposure(rg.y, 1.0 - s1.b));
		}
		if (sd > 0.0 && (hk >= 0 ? h_size : gh * grass_h_scale) < sd + 0.05) {
			grow = 0.0;   // buried
		}
	}
	// Beyond 10 m two crossed cards read the same as three: drop the third plane.
	if (COLOR.r > 0.5 && dist > 10.0) {
		grow = 0.0;
	}
	if (grow <= 0.0) {
		// Hidden: collapse the tuft to a point (no fragments).
		VERTEX = base;
		v_uv = vec2(0.0);
		v_y = 0.0;
		v_tint = vec3(0.0);
		v_straw = 0.0;
		v_herb = 0;
		v_world = base;
		v_root = 1.0;
		v_canopy = 0.0;
	} else {
		float r0 = frontier_hash(xz);
		float r1 = frontier_hash(xz + vec2(17.31, -4.7));
		float r2 = frontier_hash(xz * 1.713 + vec2(3.1, 9.4));
		float r3 = frontier_hash(xz * 0.731 - vec2(9.2, 1.3));
		float hm = gh * grass_h_scale;
		// Variant.
		int variant;
		if (forest_share > 0.55 && r2 < 0.75) {
			variant = 13 + int(r3 * 2.999);
		} else if (hm < 0.24) {
			// Mowed turf: mostly the dense, wide photographed tufts, some short blades.
			const int TURF[3] = int[3](0, 1, 3);
			variant = r2 < 0.75 ? TURF[int(r3 * 2.999)] : 11 + int(r3 * 1.999);
		} else {
			float p_dry = 0.10 + 0.40 * dry_share;
			float p_seed = 0.12 + 0.10 * dry_share;
			if (r2 < p_dry) {
				variant = 8 + int(r3 * 2.999);
			} else if (r2 < p_dry + p_seed) {
				variant = 5 + int(r3 * 2.999);
			} else {
				variant = int(r3 * 4.999);
			}
		}
		vec4 rect = variant_rects[variant];
		float aspect = variant_aspects[variant];
		float height = max(hm * (0.7 + 0.6 * r1) * grow - sd, 0.0);
		if (hk >= 0) {
			rect = herb_rects[hk];
			aspect = herb_aspects[hk];
			height = max(h_size * (0.75 + 0.5 * r1) * grow - sd, 0.0);
		}
		float turf = 1.0 - smoothstep(0.2, 0.3, hm);
		float width = height * aspect * width_scale * (1.0 + 0.5 * turf);
		if (hk >= 0) {
			width = height * aspect * 0.8;   // (a plant's card at its own proportions)
			turf = 0.4;
		}

		float yaw = r0 * 6.2832;
		float a = COLOR.r * 3.14159 + yaw;
		vec3 across = vec3(cos(a), 0.0, sin(a));
		float u = r3 > 0.5 ? 1.0 - UV.x : UV.x;
		float y = 1.0 - UV.y;
		float g = ground_height(xz) + sd;
		vec3 root = vec3(xz.x, g, xz.y);
		vec3 wp = root + across * (UV.x - 0.5) * width + vec3(0.0, y * height, 0.0);
		float hh = y * height;
		wp += frontier_wind(wp, hh, 1.0, r1 * 6.2832) + frontier_trample(root, hh);
		VERTEX = wp;

		vec2 bn = textureLod(terrain_normal, uv, 0.0).rg * 2.0 - 1.0;
		vec3 N = vec3(bn.x, sqrt(max(1.0 - dot(bn, bn), 0.0)), bn.y);
		NORMAL = normalize(N + vec3(-across.z, 0.0, across.x) * 0.12);

		v_uv = mix(rect.xy, rect.zw, vec2(u, UV.y));
		v_y = y;
		float dryness = clamp(dry_share * 0.55 + (r1 - 0.5) * 0.35 + (variant >= 8 && variant <= 10 ? 0.25 : 0.0), 0.0, 1.0);
		v_tint = mix(green_tint, dry_tint, dryness * 0.6) * (0.9 + 0.2 * r2);
		// the season's straw, each tuft a little ahead or behind; in the snow what stands out of it is dead straw
		v_straw = clamp(max(grass_cure(leaf_season) * (0.8 + 0.4 * r2), snow_cover * 2.0), 0.0, 1.0);
		v_herb = hk >= 0 ? 1 : 0;
		if (hk >= 0) {
			v_tint = vec3(0.9 + 0.2 * r2);
			v_straw = h_turned;
		}
		v_world = wp;
		v_root = mix(1.0, 0.45, turf);
		v_canopy = canopy_cover(xz);
	}
}

void fragment() {
	vec4 a = v_herb == 1 ? texture(herb_atlas, v_uv) : texture(atlas, v_uv);
	// Keep thin blades from dissolving in the smaller mips: boost alpha with the uv footprint.
	vec2 fw = fwidth(v_uv) * vec2(2048.0, 1024.0);
	ALPHA = a.a * (1.0 + clamp(log2(max(max(fw.x, fw.y), 1.0)), 0.0, 6.0) * 0.35);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// Darker, cooler root; lighter, drier tips.
	float root_k = smoothstep(0.0, 0.55, v_y);
	vec3 col = a.rgb * v_tint * mix(mix(vec3(1.0), vec3(0.62, 0.66, 0.7), v_root), vec3(1.0), root_k);
	if (v_straw > 0.001) {
		float lum = dot(col, vec3(0.3, 0.59, 0.11));
		col = mix(col, STRAW * clamp(lum / 0.16, 0.5, 1.05), v_straw);
	}
	ALBEDO = col;
	float ao = mix(1.0 - 0.45 * v_root, 1.0, root_k);
	AO = ao * canopy_sky_factor(v_canopy, 1.0);
	EMISSION = col * canopy_scatter(v_canopy, 1.0, 1.0) * ao;
	AO_LIGHT_AFFECT = 0.25;
	vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	BACKLIGHT = col * (0.3 + 0.6 * frontier_backlight(view_world));
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
