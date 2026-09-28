// Dappled crown blobs (forest lighting, 2026-09-26). The LOD4 crown hulls of the trees near the camera, rendered only
// into the shadow maps in place of the LOD3 alpha-card proxies (vegetation.gd: TreeDapple_* MultiMeshes, cast_shadow
// SHADOWS_ONLY, the same instances and scaling as the far TreeShadow4_* blobs), with round holes cut where the cellular noise of the sky's noise texture
// (sky_noise.png G: inverted Worley F1, ~8 cells a tile) peaks: a closed canopy now shades the floor, with sunflecks
// where its crowns leave gaps (the LOD3 alpha-card proxies let about two thirds of a high sun through a closed canopy:
// the forest floor at noon looked like a clearing with blotches; the hulls are cheaper too). The holes shiver with the wind (sunflecks
// move) and vary in size across the forest (the texture's fractal B channel at a quarter of the frequency). The same
// everywhere the trees cast shade (user 2026-09-28: "is there a player vision a line for the player that effects world
// shade", "a mixture of" sunflecks everywhere and an evenly shaded forest): no longer closing toward solid crowns away
// from the player, which made the sunlit floor a ring that walked with the player; fewer holes (gap) for a mostly even
// shade. Trunks (the blob's 4-sided trunk tube) never get holes. Two texture fetches per shadow-map fragment.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

#include "res://shaders/common/wind.gdshaderinc"

uniform sampler2D dapple_noise : filter_linear_mipmap, repeat_enable;   // res://assets/environment/sky/sky_noise.png
/// Share of a crown's hull left open (sunflecks): 0.08, a mostly even shade with scattered sunflecks (0.12, the first
/// look, let through about what the hulls at 0.25 with the cards under them did; the overlapping crowns of a closed
/// canopy close most of the holes).
uniform float gap = 0.08;
/// World size (m) of one noise tile (~8 cells: holes up to about a sixteenth of it across).
uniform float tile = 7.0;

varying vec3 v_wp;
varying vec2 v_seed;
varying float v_trunk;

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_seed = vec2(frontier_hash(MODEL_MATRIX[3].xz), frontier_hash(MODEL_MATRIX[3].zx + 7.1));
	// the trunk tube: vertices near the axis with a horizontal normal (the hull's apexes have vertical normals)
	v_trunk = (length(VERTEX.xz) < 0.8 && abs(NORMAL.y) < 0.5) ? 1.0 : 0.0;
}

void fragment() {
	float g = gap;
	if (g > 0.002 && v_trunk < 0.5) {
		vec2 wd = normalize(wind_direction + vec2(1e-5));
		float sway = sin(TIME * 1.9 + v_seed.x * 6.2832) * (0.05 + 0.25 * wind_strength);
		// sheared by height, so the side faces a low sun meets get holes too; one tile offset per tree
		vec2 p = v_wp.xz + wd * sway + v_wp.y * vec2(0.37, -0.21);
		vec2 uv = p / tile + v_seed;
		float n = texture(dapple_noise, uv).g;
		// the open share wanders across the forest (x0.6 .. x1.4)
		g *= 0.6 + 0.8 * texture(dapple_noise, uv * 0.25 + 0.5).b;
		// the G channel's (1 - g) quantile (a quadratic fit of its histogram, max error 0.011)
		float t = (0.6397 * g - 0.9245) * g + 0.9404;
		if (n > t) {
			discard;
		}
	}
	ALBEDO = vec3(0.2, 0.25, 0.15);
}
