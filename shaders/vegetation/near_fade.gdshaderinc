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
// The crown round the climber too (user 2026-09-28: "when we are on a tree the branchs should fade so we can see the
// ground"): leaves and limbs within veg_clear_c.w metres of veg_clear_c.xyz (the climber) dither out with the line,
// so the ground below shows through the tree they are in; trunks keep to the line alone.
// Up a tree the tree climbed keeps its crown and the OTHER trees fade instead (user 2026-10-03: "also when we keep climbing
// up trees fade the other ones not the tree we are climbing up"): veg_clear_d.x / .z is the climbed tree's base (the
// layout position its drawn instances stand on, MODEL_MATRIX's origin in vertex(): frontier_climbed()), veg_clear_d.w 1
// while a tree is climbed (0: none, and everything clears as above), veg_clear_d.y 0..1 how far the climber looks down.
// The trees' material (tree.gdshader) asks frontier_tree_clear(), which while a tree is climbed clears
//   the tree climbed   its leaves and limbs only in the line of sight (the line above, and the way from the camera to the
//                      climber's whole body: frontier_body_distance()), no crown round the climber; as the climber looks
//                      down, its crown under their feet within veg_clear_c.w across (the ground shows); its trunk only
//                      right by the camera, as before
//   the other trees    their leaves and limbs in the line of sight and round the climber, and their trunks anywhere on
//                      the way from the camera to the climber (not on along the aim: a trunk there stops the shot)
global uniform vec4 veg_clear_a;
global uniform vec4 veg_clear_b;
global uniform vec4 veg_clear_c;
global uniform vec4 veg_clear_d;

float frontier_segment_distance(vec3 world_pos, vec3 a, vec3 b) {
	vec3 ab = b - a;
	float t = clamp(dot(world_pos - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
	return length(world_pos - (a + ab * t));
}

float frontier_line_distance(vec3 world_pos) {
	return frontier_segment_distance(world_pos, veg_clear_a.xyz, veg_clear_b.xyz);
}

bool frontier_clear_test(float k, vec2 frag_xy) {
	float dither = fract(52.9829189 * fract(dot(frag_xy, vec2(0.06711056, 0.00583715))));
	return mix(1.0, k, veg_clear_b.w) <= dither;
}

bool frontier_line_clear(vec3 world_pos, vec2 frag_xy) {
	if (veg_clear_b.w <= 0.0) {
		return false;
	}
	float r = veg_clear_a.w;
	float k = smoothstep(r * 0.5, r, frontier_line_distance(world_pos));
	float rc = veg_clear_c.w;
	if (rc > 0.0) {
		k = min(k, smoothstep(rc * 0.55, rc, length(world_pos - veg_clear_c.xyz)));
	}
	return frontier_clear_test(k, frag_xy);
}

bool frontier_line_clear_near(vec3 world_pos, vec2 frag_xy, float near) {
	if (veg_clear_b.w <= 0.0 || length(world_pos - veg_clear_a.xyz) > near) {
		return false;
	}
	float r = veg_clear_a.w;
	return frontier_clear_test(smoothstep(r * 0.5, r, frontier_line_distance(world_pos)), frag_xy);
}

// 1.0 when the tree standing at `base` (MODEL_MATRIX[3].xyz in vertex(): a MultiMesh instance's origin is its tree's layout
// position) is the one being climbed, else 0.0.
float frontier_climbed(vec3 base) {
	return (veg_clear_d.w > 0.5 && abs(base.x - veg_clear_d.x) < 0.05 && abs(base.z - veg_clear_d.z) < 0.05) ? 1.0 : 0.0;
}

// The way from the camera to the climber's whole body: the nearer of the segments from veg_clear_a.xyz (the camera) to their
// head and to their middle (veg_clear_c.xyz is 1 m over their feet).
float frontier_body_distance(vec3 world_pos) {
	vec3 c = veg_clear_c.xyz;
	return min(frontier_segment_distance(world_pos, veg_clear_a.xyz, c + vec3(0.0, 0.45, 0.0)),
			frontier_segment_distance(world_pos, veg_clear_a.xyz, c - vec3(0.0, 0.5, 0.0)));
}

// True when a tree's fragment at `world_pos` is cleared for a climber: `foliage` its leaves, needles and limbs (else its
// trunk or stem), `climbed` frontier_climbed() of its tree (a varying from vertex()).
bool frontier_tree_clear(vec3 world_pos, vec2 frag_xy, bool foliage, float climbed) {
	if (veg_clear_b.w <= 0.0) {
		return false;
	}
	if (veg_clear_d.w <= 0.5 || (climbed > 0.5 && !foliage)) {
		// no tree climbed (a rock, a giant), or the climbed tree's trunk: as before
		return foliage ? frontier_line_clear(world_pos, frag_xy) : frontier_line_clear_near(world_pos, frag_xy, 2.2);
	}
	float r = veg_clear_a.w;
	if (!foliage) {
		// another tree's trunk: between the camera and the climber (not on along the aim: a trunk there stops the shot)
		float d = frontier_body_distance(world_pos);
		if (length(world_pos - veg_clear_a.xyz) <= 2.2) {
			d = min(d, frontier_line_distance(world_pos));
		}
		return frontier_clear_test(smoothstep(r * 0.5, r, d), frag_xy);
	}
	// leaves and limbs: the line of sight (on along the aim) and the way to the climber's whole body
	float k = smoothstep(r * 0.5, r, min(frontier_line_distance(world_pos), frontier_body_distance(world_pos)));
	float rc = veg_clear_c.w;
	if (rc > 0.0) {
		if (climbed > 0.5) {
			// the tree climbed keeps its crown round the climber; looking down, the crown under their feet clears
			float g = veg_clear_d.y * smoothstep(0.8, 1.6, veg_clear_c.y - world_pos.y);
			k = min(k, mix(1.0, smoothstep(rc * 0.55, rc, length(world_pos.xz - veg_clear_c.xz)), g));
		} else {
			// the other trees' crowns round the climber
			k = min(k, smoothstep(rc * 0.55, rc, length(world_pos - veg_clear_c.xyz)));
		}
	}
	return frontier_clear_test(k, frag_xy);
}
