// The broadleaf trees' year (user 2026-09-28: "for autumn we can have orange leaves ... the trees need to lose their
// green leaves, only pine trees keep their leaves ... and then spring it starts to grow again"). SeasonLeaves
// (scripts/snow/season_leaves.gd) sets leaf_season from the game's date:
//   0          summer: the leaves green
//   0 .. 1     autumn: card by card the leaves turn (each species its colours: autumn_a / autumn_b)
//   1 .. 2     November: they fall, card by card, browning as they go
//   2          winter: bare (the limbs, and the snow on them)
//   2 .. 3     spring: the buds break and the leaves come back, a fresh yellow-green
// Per material: leaf_fall 0 an evergreen (pine, hemlock: untouched), 1 a broadleaf.
// Tree by tree over the whole world (user 2026-09-28: "slowly all of them turn autumn colors until snow", "it should
// be a world thing to turn trees not just players eye distance"): leaf_season_at() runs each tree's year early or late
// by its species (leaf_early: the maples first, the oaks last), the stand it grows in (whole hillsides ahead of others),
// the ground's height (the high ground colder) and the tree itself, from its place in the world, the same at every
// distance and in every LOD (the meshes, the painted trees, the impostors, the dappled shadow crowns): the woods turn
// patch by patch and are all bare by the global value's 2.

global uniform float leaf_season;

uniform float leaf_fall = 0.0;
uniform vec3 autumn_a : source_color = vec3(0.72, 0.25, 0.1);
uniform vec3 autumn_b : source_color = vec3(0.88, 0.5, 0.16);
/// The species' timing, -1 late (the oaks) .. 1 early (the maples): VegAssets.LEAF_EARLY.
uniform float leaf_early = 0.0;

const vec3 LEAF_BROWN = vec3(0.16, 0.09, 0.04);
const vec3 LEAF_BUD = vec3(0.34, 0.5, 0.12);
/// A stand (the trees that turn together) is about this wide (m).
const float LEAF_STAND_M = 150.0;

float leaf_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float leaf_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(leaf_hash(i), leaf_hash(i + vec2(1.0, 0.0)), u.x),
			mix(leaf_hash(i + vec2(0.0, 1.0)), leaf_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

/// How early (> 0) or late (< 0) the tree standing at `base` (world) runs its year: its species' `early`, its stand,
/// its ground's height and its own.
float leaf_timing(vec3 base, float early) {
	float stand = leaf_vnoise(base.xz / LEAF_STAND_M + vec2(17.3, 5.1)) * 2.0 - 1.0;
	float own = leaf_hash(floor(base.xz * 4.0) * 0.25) * 2.0 - 1.0;
	return early * 0.45 + stand * 0.5 + own * 0.35;
}

/// The tree at `base`'s own leaf_season (see the top): autumn's 0 .. 2 and spring's 2 .. 3 each bent by exp2(-timing),
/// so an early tree runs ahead and a late one behind, and every tree is green at 0 and bare at 2.
float leaf_season_at(vec3 base, float early) {
	float s = leaf_season;
	if (s <= 0.0 || s >= 3.0) {
		return s;
	}
	float t = leaf_timing(base, early);
	float high = clamp((base.y - 4.0) / 30.0, -0.5, 1.0) * 0.3;
	if (s < 2.0) {
		return 2.0 * pow(s * 0.5, exp2(-clamp(t + high, -1.2, 1.2)));
	}
	return 2.0 + pow(s - 2.0, exp2(-clamp(t - high, -1.2, 1.2)));
}

/// How much of a broadleaf's crown is off at its season `s`: 0 in leaf .. 1 bare (the fall, then spring's leafing out).
float leaf_bare(float s) {
	if (s <= 1.0 || s >= 3.0) {
		return 0.0;
	}
	if (s < 2.0) {
		return clamp((s - 1.0) * 1.3, 0.0, 1.0);
	}
	return 1.0 - smoothstep(2.0, 2.8, s);
}

/// A broadleaf's leaf card at its tree's season `s` (leaf_season_at; `rnd` the card's own random 0..1; `fall` the
/// material's leaf_fall, or a row's): turns `col`; false when the card is off the tree now (discard it).
bool season_leaf(inout vec3 col, float rnd, float fall, vec3 aut_a, vec3 aut_b, float s) {
	if (fall <= 0.0 || s <= 0.0 || s >= 3.0) {
		return true;
	}
	float lum = max(dot(col, vec3(0.3, 0.59, 0.11)), 1e-3);
	vec3 autumn = mix(aut_a, aut_b, fract(rnd * 3.71));
	// keep the paint's light and shade: the autumn colour at the green's brightness, a little brighter
	autumn *= clamp(lum / max(dot(autumn, vec3(0.3, 0.59, 0.11)), 1e-3), 0.5, 1.25) * 1.1;
	if (s < 1.0) {
		float t = smoothstep(rnd * 0.65, rnd * 0.65 + 0.35, s);
		col = mix(col, autumn, t * fall);
		return true;
	}
	if (s < 2.0) {
		// the fall runs ahead of the calendar a little (most are down by mid November), the last ones brown
		float f = clamp((s - 1.0) * 1.3, 0.0, 1.0);
		col = mix(col, mix(autumn, LEAF_BROWN * clamp(lum / 0.1, 0.5, 1.6), f * 0.75), fall);
		return rnd >= f * fall;
	}
	float g = s - 2.0;
	if (rnd > g * 1.08 * fall + (1.0 - fall)) {
		return false;
	}
	col = mix(mix(col, LEAF_BUD * clamp(lum / 0.12, 0.5, 1.3), 0.6), col, smoothstep(0.5, 1.0, g));
	return true;
}

/// The same for an impostor's pixel (`s` its tree's season) (trunk and crown baked together, so it cannot lose its leaves card by card): the
/// autumn colours and spring's buds as the cards', and bare, most of the crown's pixels gone and the rest the grey-brown
/// of the limbs (the tree still stands there). False: discard the pixel.
bool season_impostor(inout vec3 col, float rnd, float fall, vec3 aut_a, vec3 aut_b, float s) {
	if (fall <= 0.0 || s <= 0.0 || s >= 3.0) {
		return true;
	}
	if (s < 1.0 || s > 2.6) {
		return season_leaf(col, rnd, fall, aut_a, aut_b, s);
	}
	float lum = max(dot(col, vec3(0.3, 0.59, 0.11)), 1e-3);
	float bare = s < 2.0 ? clamp((s - 1.0) * 1.3, 0.0, 1.0) : 1.0 - smoothstep(2.0, 2.6, s);
	// the crown's colour under the bareness: autumn's on the way down, the buds' on the way back
	vec3 leaf;
	if (s < 2.0) {
		vec3 autumn = mix(aut_a, aut_b, fract(rnd * 3.71));
		leaf = autumn * (lum / max(dot(autumn, vec3(0.3, 0.59, 0.11)), 1e-3));
	} else {
		leaf = mix(LEAF_BUD * clamp(lum / 0.12, 0.5, 1.3), col, 0.35);
	}
	col = mix(mix(col, leaf, fall), vec3(0.14, 0.12, 0.1) * clamp(lum / 0.1, 0.6, 1.4), bare * fall);
	return rnd >= bare * 0.72 * fall;
}
