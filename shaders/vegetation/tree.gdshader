// Trees, saplings and shrubs (package C): bark tubes and alpha-tested foliage cards in one
// surface, wind from the shared globals, baked AO, translucent leaves. See tree_common.gdshaderinc.
// Forest light (canopy.gdshaderinc, 2026-09-26): under the canopy (the crown cover over the tree's base,
// up to ~20 m) the sky light is taken and the leaves' scattered light added; thin outer leaves seen
// against the sun (or the moon) glow with the light they let through (leaf_glow; Godot's BACKLIGHT is
// shadowed by the crown's own shadow proxies, so it never lit them).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/vegetation/tree_common.gdshaderinc"
#include "res://shaders/common/canopy.gdshaderinc"
#include "res://shaders/vegetation/lod_fade.gdshaderinc"
#include "res://shaders/common/snow.gdshaderinc"
#include "res://shaders/vegetation/leaf_season.gdshaderinc"

/// Forward-scatter glow of thin leaves against the key light (x leaf_glow).
uniform float leaf_glow_strength = 1.0;

varying float v_canopy;
varying vec2 v_lod;
varying float v_leaf_s;

void vertex() {
	v_col = COLOR;
	v_custom = INSTANCE_CUSTOM;
	v_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - MODEL_MATRIX[3].y;
	VERTEX += tree_wind(VERTEX, MODEL_MATRIX, COLOR, UV2);
	v_canopy = canopy_cover(MODEL_MATRIX[3].xz);
	v_leaf_s = leaf_season_at(MODEL_MATRIX[3].xyz, leaf_early);
	// the LOD's share of this tree (lod_fade.gdshaderinc); none: the instance collapses to a point, no pixels
	v_lod = frontier_lod_cover(distance(CAMERA_POSITION_WORLD, MODEL_MATRIX[3].xyz));
	if (v_lod.x <= 0.0 || v_lod.y <= 0.0) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	// the LOD hand-over: this LOD's share of the tree's pixels (before any texture fetch)
	if (!IN_SHADOW_PASS && frontier_lod_dither(FRAGCOORD.xy, v_lod)) {
		discard;
	}
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	// Foliage cards and limbs (UV2.x > 0: metres along a branch) near the camera fade out, before any
	// texture fetch (cheap to reject); trunks (UV2.x = 0) stay solid. near_fade.gdshaderinc.
	if ((v_col.a > 0.5 || UV2.x > 0.0) && !IN_SHADOW_PASS && frontier_near_fade(VERTEX, FRAGCOORD.xy, near_fade_begin, near_fade_end)) {
		discard;
	}
	// the line of sight from a tree perch: foliage and limbs on it, trunks only right by the camera
	if (!IN_SHADOW_PASS && veg_clear_b.w > 0.0) {
		vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		if ((v_col.a > 0.5 || UV2.x > 0.0) ? frontier_line_clear(wp, FRAGCOORD.xy) : frontier_line_clear_near(wp, FRAGCOORD.xy, 2.2)) {
			discard;
		}
	}
	TreeSurface s = tree_surface(UV, dx, dy, v_col, v_custom, v_height);
	if (s.alpha < alpha_cut) {
		discard;
	}
	// the broadleaves' year (leaf_season.gdshaderinc): autumn's colours, the fall, spring's buds
	if (s.leaf && !season_leaf(s.albedo, v_col.b, leaf_fall, autumn_a, autumn_b, v_leaf_s)) {
		discard;
	}
	// snow on the crown's tops and the limbs (snow.gdshaderinc)
	s.albedo = snow_on_tree(s.albedo, normalize((INV_VIEW_MATRIX * vec4(FRONT_FACING ? NORMAL : -NORMAL, 0.0)).xyz), s.leaf,
			v_col.g, v_col.b);
	ALBEDO = s.albedo;
	ALPHA = s.alpha;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	NORMAL_MAP = s.normal_map;
	NORMAL_MAP_DEPTH = s.normal_depth;
	ROUGHNESS = s.roughness;
	SPECULAR = s.specular;
	// under the canopy: the trunks and the lower crown (a sapling or a shrub all of it), the outer leaves less
	float under = push_whole > 0.5 ? 1.0 : canopy_under(v_height) * (s.leaf ? 1.0 - 0.5 * v_col.g : 1.0);
	AO = s.ao * canopy_sky_factor(v_canopy, under);
	EMISSION = s.albedo * canopy_scatter(v_canopy, under, 0.6) * s.ao;
	AO_LIGHT_AFFECT = s.leaf ? ao_light_affect : 0.15;
	if (s.leaf && leaf_glow.r + leaf_glow.g + leaf_glow.b > 0.0) {
		// thin (outer, unoccluded) leaves between the eye and the key light glow; dimmed deep under other crowns
		vec3 to_eye = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		float thin = v_col.g * v_col.r * (1.0 - 0.7 * v_canopy * under);
		EMISSION += s.albedo * leaf_glow.rgb * (canopy_leaf_phase(to_eye, sun_direction) * thin * leaf_glow_strength);
	}
	if (s.leaf) {
		// Keep the crown normal on the back faces of the cards (Godot flips it for two-sided
		// materials): the crown shades as one volume.
		if (!FRONT_FACING) {
			NORMAL = -NORMAL;
		}
		BACKLIGHT = s.albedo * backlight_strength;
	}
}
