// Snow (scripts/snow/: SnowCover sets these globals every frame from the survival core's snow on the ground; SnowPrints
// keeps the trail map of the prints round the player). project.godot declares them.
//   snow_cover       0 bare .. 1 deep snow (the core's depth over SnowCover.FULL_M, eased)
//   snow_fresh       0 old, crusted snow .. 1 falling or new (whiter, softer)
//   snow_total       snowfall so far, tenths of a cm (a print fills in with what falls after it)
//   snow_trail       the prints round the player: RG8, a texel the snowfall total when a foot pressed it (+1; 0 none)
//   snow_trail_rect  x0, z0, width, depth (m) of snow_trail
//   snow_shelter     where a roof or a floor above keeps the snow off: RG8, a texel the height (cm + 10000) of the
//                    lowest cover over it (0 none); snow_shelter_rect its x0, z0, width, depth (SnowCover builds it
//                    from the level's colliders: the cabins', blockhouses' and built roofs, the firing step)
//   snow_region      the snow over the land, square by square (scripts/snow/snow_land.gd, data/snow/snow.json): RGBA8,
//                    r the square type's hold / 2, g its wind exposure, b its slopes' shedding; snow_region_rect its
//                    x0, z0, 1 / width, 1 / depth; snow_wind the world xz the winter wind blows toward
// snow_amount(): how much a surface holds (flat ground and tops take it, steep sides shed it, thin snow lies in patches);
// snow_land(): the same for the ground, by its region (user 2026-09-28: "we need to make it procedure beacuse we have
// the great planes as well as the water"): the open plains wind-scoured on the rises and the slopes facing the wind,
// drifted deep in their lee, streaked bare along the wind and rippled across it; the woods deep and even; the cliffs'
// faces bare (snow_depth_k, mirrored on the CPU by SnowLand.depth_k for SnowCover.depth_at);
// snow_pressed(): how far the snow is pressed down at a point (1 a fresh print .. 0 untouched or filled in).

global uniform float snow_cover;
global uniform float snow_fresh;
global uniform float snow_total;
global uniform sampler2D snow_trail : filter_nearest, repeat_disable;
global uniform vec4 snow_trail_rect;
global uniform sampler2D snow_shelter : filter_nearest, repeat_disable;
global uniform vec4 snow_shelter_rect;
global uniform sampler2D snow_region : filter_linear, repeat_disable;
global uniform vec4 snow_region_rect;
global uniform vec2 snow_wind;

/// snow_cover 1 is this deep (m): SnowCover.FULL_M.
const float SNOW_FULL_M = 0.35;
const vec3 SNOW_ALBEDO = vec3(0.84, 0.87, 0.92);
const vec3 SNOW_SHADE = vec3(0.60, 0.66, 0.76);   // the blue of a pressed print's sides
/// Tenths of a cm of new snow that fill a print.
const float SNOW_FILL_UNITS = 60.0;

float snow_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float snow_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(snow_hash(i), snow_hash(i + vec2(1.0, 0.0)), u.x),
			mix(snow_hash(i + vec2(0.0, 1.0)), snow_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

/// A hash of a lattice point without sine (the GPU's float32 and SnowLand's float64 agree): SnowLand.hash2.
float snow_hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

/// Value noise on snow_hash2's lattice, 0..1: SnowLand.vnoise.
float snow_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(snow_hash2(i), snow_hash2(i + vec2(1.0, 0.0)), u.x),
			mix(snow_hash2(i + vec2(0.0, 1.0)), snow_hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

/// The region at xz: x the hold (0..2), y the wind exposure, z the shedding; (1, 0, 0) without a map.
vec3 snow_region_at(vec2 xz) {
	if (snow_region_rect.z <= 0.0) {
		return vec3(1.0, 0.0, 0.0);
	}
	vec4 t = textureLod(snow_region, (xz - snow_region_rect.xy) * snow_region_rect.zw, 0.0);
	return vec3(t.r * 2.0, t.g, t.b);
}

/// How exposed to the wind a point is: its region's exposure opened up in a clearing, sheltered under trees (`open`
/// 0 a closed forest .. 1 open ground).
float snow_exposure(float wind, float open) {
	return mix(wind, 1.0, 0.35 * open) * (0.25 + 0.75 * open);
}

/// The snow's depth at xz over the core's, 0 scoured bare .. ~2 a deep drift: the region's hold `r`, the wind's scour
/// on the slopes facing it (`wn` the ground's world normal), its drifts in their lee, bare streaks along it.
float snow_depth_k(vec2 xz, vec3 wn, vec3 r, float e) {
	vec2 wd = snow_wind;
	float face = clamp(dot(wn.xz, -wd) * 6.0, -1.0, 1.0);
	vec2 aw = vec2(dot(xz, wd), dot(xz, vec2(-wd.y, wd.x)));
	float bend = snow_vnoise(aw * 0.012 + 3.1);
	float streak = snow_vnoise(vec2(aw.x * 0.02, aw.y * 0.09 + (bend - 0.5) * 3.0));
	float k = r.x * (1.0 - 0.6 * e * max(face, 0.0)) * (1.0 + 0.9 * e * max(-face, 0.0));
	k *= 1.0 - 0.55 * e * smoothstep(0.45, 0.85, streak);
	return max(k, 0.0);
}

/// The wind's ripples on exposed snow: crests across the wind about 1.2 m apart, wandering; their slope (world d/dx,
/// d/dz) x the exposure `e`, for the ground's normal.
vec2 snow_ripple_grad(vec2 xz, float e) {
	vec2 wd = snow_wind;
	vec2 aw = vec2(dot(xz, wd), dot(xz, vec2(-wd.y, wd.x)));
	float ph = aw.x * 5.2 + snow_vnoise(vec2(aw.x * 0.35, aw.y * 0.5)) * 6.0 + snow_vnoise(aw * 0.08) * 9.0;
	float amp = 0.07 * e * smoothstep(0.35, 0.6, snow_vnoise(aw * vec2(0.1, 0.04) + 7.0));
	return wd * cos(ph) * amp;
}

/// Whether a roof or a floor above keeps the snow off the point wp (the shelter map).
bool snow_sheltered(vec3 wp) {
	if (snow_shelter_rect.z <= 0.0) {
		return false;
	}
	vec2 uv = (wp.xz - snow_shelter_rect.xy) / snow_shelter_rect.zw;
	if (uv.x <= 0.0 || uv.y <= 0.0 || uv.x >= 1.0 || uv.y >= 1.0) {
		return false;
	}
	vec4 t = texelFetch(snow_shelter, ivec2(uv * vec2(textureSize(snow_shelter, 0))), 0);
	float cm = floor(t.r * 255.0 + 0.5) * 256.0 + floor(t.g * 255.0 + 0.5);
	return cm > 0.5 && wp.y < (cm - 10000.0) * 0.01 - 0.05;
}

/// How much snow a surface at wp (world) facing wn (world) holds, 0..1 (times snow_cover's reach).
float snow_amount(vec3 wp, vec3 wn) {
	if (snow_cover <= 0.001) {
		return 0.0;
	}
	if (snow_sheltered(wp)) {
		return 0.0;
	}
	float up = smoothstep(0.3, 0.8, wn.y);
	float patchy = snow_noise(wp.xz * 0.55) * 0.65 + snow_noise(wp.xz * 2.7) * 0.35;
	float cov = smoothstep(patchy - 0.15, patchy + 0.2, snow_cover * 1.6);
	return clamp(up * cov, 0.0, 1.0);
}

/// How much snow the ground at wp (world) facing wn holds, 0..1, by its region (snow_depth_k: `k` out); `open` 0 under
/// a closed forest .. 1 open ground, `e` out: its wind exposure (the ripples).
float snow_land(vec3 wp, vec3 wn, float open, out float k, out float e) {
	k = 0.0;
	e = 0.0;
	if (snow_cover <= 0.001 || snow_sheltered(wp)) {
		return 0.0;
	}
	vec3 r = snow_region_at(wp.xz);
	e = snow_exposure(r.y, open);
	k = snow_depth_k(wp.xz, wn, r, e);
	// the cliffs shed from gentler slopes
	float lo = 0.3 + 0.35 * r.z;
	float up = smoothstep(lo, lo + 0.5, wn.y);
	float patchy = snow_noise(wp.xz * 0.55) * 0.65 + snow_noise(wp.xz * 2.7) * 0.35;
	float cov = smoothstep(patchy - 0.15, patchy + 0.2, snow_cover * k * 1.6);
	return clamp(up * cov, 0.0, 1.0);
}

/// A trail texel: how pressed it is now (the print filling in with the snow fallen since).
float snow_decode(vec4 t) {
	float stamp = floor(t.r * 255.0 + 0.5) * 256.0 + floor(t.g * 255.0 + 0.5);
	if (stamp < 0.5) {
		return 0.0;
	}
	float since = mod(snow_total - (stamp - 1.0) + 65536.0, 65536.0);
	return clamp(1.0 - since / SNOW_FILL_UNITS, 0.0, 1.0);
}

/// How far the snow is pressed down at xz (bilinear over the trail's texels): 0 untouched .. 1 a fresh print.
float snow_pressed(vec2 xz) {
	if (snow_trail_rect.z <= 0.0 || snow_cover <= 0.001) {
		return 0.0;
	}
	vec2 uv = (xz - snow_trail_rect.xy) / snow_trail_rect.zw;
	if (uv.x <= 0.0 || uv.y <= 0.0 || uv.x >= 1.0 || uv.y >= 1.0) {
		return 0.0;
	}
	ivec2 sz = textureSize(snow_trail, 0);
	vec2 tc = uv * vec2(sz) - 0.5;
	ivec2 i0 = ivec2(floor(tc));
	vec2 f = fract(tc);
	ivec2 hi = sz - 1;
	float p00 = snow_decode(texelFetch(snow_trail, clamp(i0, ivec2(0), hi), 0));
	float p10 = snow_decode(texelFetch(snow_trail, clamp(i0 + ivec2(1, 0), ivec2(0), hi), 0));
	float p01 = snow_decode(texelFetch(snow_trail, clamp(i0 + ivec2(0, 1), ivec2(0), hi), 0));
	float p11 = snow_decode(texelFetch(snow_trail, clamp(i0 + ivec2(1, 1), ivec2(0), hi), 0));
	return mix(mix(p00, p10, f.x), mix(p01, p11, f.x), f.y);
}

/// The world-space slope (d/dx, d/dz) of a value v across the ground from screen derivatives (the prints' sides).
vec2 snow_ground_grad(float v, vec3 wp) {
	vec2 dx = dFdx(wp.xz);
	vec2 dy = dFdy(wp.xz);
	float det = dx.x * dy.y - dx.y * dy.x;
	if (abs(det) < 1e-9) {
		return vec2(0.0);
	}
	float dvx = dFdx(v);
	float dvy = dFdy(v);
	// [dvx, dvy] = [dx; dy] . g  ->  g = inverse([dx; dy]) . [dvx, dvy]
	return vec2(dy.y * dvx - dx.y * dvy, -dy.x * dvx + dx.x * dvy) / det;
}

/// The snow's colour at a point: white, a little bluer and duller where it is old, patchy grain.
vec3 snow_albedo(vec3 wp) {
	float g = snow_noise(wp.xz * 11.0) * 0.06 + snow_noise(wp.xz * 1.3) * 0.05;
	return SNOW_ALBEDO * mix(0.9, 1.04, snow_fresh) * (0.97 + g);
}

/// Snow on a tree (the tree and impostor shaders): foliage facing up takes it, the outer crown most, in clumps (a dab's
/// random value `rnd` against the cover); a limb or a trunk on its top. `wn` the world normal (a leaf's: the crown's).
vec3 snow_on_tree(vec3 col, vec3 wn, bool leaf, float outer, float rnd) {
	if (snow_cover <= 0.001) {
		return col;
	}
	float k;
	if (leaf) {
		k = smoothstep(0.05, 0.65, wn.y) * (0.35 + 0.65 * outer) * step(rnd, snow_cover * 1.3 + 0.08);
	} else {
		k = smoothstep(0.5, 0.9, wn.y) * 0.9;
	}
	return mix(col, SNOW_ALBEDO * mix(0.9, 1.02, snow_fresh), clamp(k * min(snow_cover * 2.5, 1.0), 0.0, 1.0));
}

