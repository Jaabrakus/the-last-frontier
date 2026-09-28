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

shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_disabled, world_vertex_coords;

#include "res://shaders/common/wind.gdshaderinc"
#include "res://shaders/common/canopy.gdshaderinc"

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
		float bare = clamp(dirt + mud + s1.g, 0.0, 1.0);
		// Mowed turf (under 0.24 m) is a closed carpet: full pattern density there.
		float open_density = mix(1.0, meadow_density, smoothstep(0.2, 0.3, gh * grass_h_scale));
		float loc = clamp(1.0 - bare * 1.25, 0.0, 1.0) * mix(open_density, 0.3, forest_share);
		grow = clamp((keep * loc - rank) * 14.0, 0.0, 1.0) * smoothstep(0.03, 0.07, gh * grass_h_scale) * fade;
		if (textureLod(blocker_map, (xz - blocker_rect.xy) / blocker_rect.zw, 0.0).r > 0.5) {
			grow = 0.0;
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
		float height = hm * (0.7 + 0.6 * r1) * grow;
		float turf = 1.0 - smoothstep(0.2, 0.3, hm);
		float width = height * aspect * width_scale * (1.0 + 0.5 * turf);

		float yaw = r0 * 6.2832;
		float a = COLOR.r * 3.14159 + yaw;
		vec3 across = vec3(cos(a), 0.0, sin(a));
		float u = r3 > 0.5 ? 1.0 - UV.x : UV.x;
		float y = 1.0 - UV.y;
		float g = ground_height(xz);
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
		v_world = wp;
		v_root = mix(1.0, 0.45, turf);
		v_canopy = canopy_cover(xz);
	}
}

void fragment() {
	vec4 a = texture(atlas, v_uv);
	// Keep thin blades from dissolving in the smaller mips: boost alpha with the uv footprint.
	vec2 fw = fwidth(v_uv) * vec2(2048.0, 1024.0);
	ALPHA = a.a * (1.0 + clamp(log2(max(max(fw.x, fw.y), 1.0)), 0.0, 6.0) * 0.35);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// Darker, cooler root; lighter, drier tips.
	float root_k = smoothstep(0.0, 0.55, v_y);
	vec3 col = a.rgb * v_tint * mix(mix(vec3(1.0), vec3(0.62, 0.66, 0.7), v_root), vec3(1.0), root_k);
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
