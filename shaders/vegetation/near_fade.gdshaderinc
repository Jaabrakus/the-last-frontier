// Near-camera foliage fade (forest performance pass, user-approved 2026-09-25). Included by
// tree_common.gdshaderinc (leaf / needle cards of trees, saplings, shrubs) and plant.gdshader (ferns).
//
// frontier_near_fade(VERTEX, FRAGCOORD.xy, begin, end) in fragment() is true when the fragment is
// faded out: the coverage smoothsteps from 0 at `begin` to 1 at `end` metres from the camera and is
// tested against screen-space interleaved gradient noise (the impostor's view-blend dither). The
// pattern is fixed per pixel, so it does not shimmer under TAA, and the depth prepass and the colour
// pass agree. Callers skip it in shadow passes (IN_SHADOW_PASS), so shadows never change, and call it
// before their texture fetches, so a rejected fragment costs almost nothing.
// Measured 2026-09-25 (tools/environment/perf/forest_cost.gd, variant near_fade_off): no change on
// the walk / run / turn poses and the u10 views (nothing within 1.5 m); with the camera inside a
// sapling or shrub the frame costs ~1.3 ms MORE on average, because the depth prepass already made
// the near cards' overdraw cheap and clearing them reveals the forest behind. It is a view-clearing
// feature, not a performance one.

bool frontier_near_fade(vec3 view_pos, vec2 frag_xy, float begin, float end) {
	float d = length(view_pos);
	if (d >= end) {
		return false;
	}
	float k = smoothstep(begin, end, d);
	float dither = fract(52.9829189 * fract(dot(frag_xy, vec2(0.06711056, 0.00583715))));
	return k <= dither;
}

// A clear line of sight while climbing and perched in a tree (user 2026-09-27: "i want players to be able to throw
// weapons and shoot from there so we need the brances to fade as well"; PlayerGrip drives it): leaves, needles and limbs
// within veg_clear_a.w metres of the segment from veg_clear_a.xyz (the camera) to veg_clear_b.xyz (past the player along
// the aim) dither out, as the near fade does; veg_clear_b.w (0..1) fades the whole thing in and out (0: off, nothing
// changes). frontier_line_clear_near() is the same for trunks, only within `near` metres of the camera (a camera
// that swings round behind the trunk the player is perched on).
global uniform vec4 veg_clear_a;
global uniform vec4 veg_clear_b;

float frontier_line_distance(vec3 world_pos) {
	vec3 a = veg_clear_a.xyz;
	vec3 ab = veg_clear_b.xyz - a;
	float t = clamp(dot(world_pos - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
	return length(world_pos - (a + ab * t));
}

bool frontier_line_clear(vec3 world_pos, vec2 frag_xy) {
	if (veg_clear_b.w <= 0.0) {
		return false;
	}
	float r = veg_clear_a.w;
	float k = mix(1.0, smoothstep(r * 0.5, r, frontier_line_distance(world_pos)), veg_clear_b.w);
	float dither = fract(52.9829189 * fract(dot(frag_xy, vec2(0.06711056, 0.00583715))));
	return k <= dither;
}

bool frontier_line_clear_near(vec3 world_pos, vec2 frag_xy, float near) {
	if (veg_clear_b.w <= 0.0 || length(world_pos - veg_clear_a.xyz) > near) {
		return false;
	}
	return frontier_line_clear(world_pos, frag_xy);
}
