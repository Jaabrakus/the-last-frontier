// Shared wind, player interaction and hashing for the Frontier environment shaders (grass,
// ferns, shrubs, saplings, tree branches and leaves). Owner: package A. Frozen API: see the
// look-dev spec (graph_analysis/visual/lookdev_spec.md, section 11). Include it from a spatial
// shader and call the functions from vertex():
//
//   #include "res://shaders/common/wind.gdshaderinc"
//   void vertex() {
//       vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
//       vec3 base = MODEL_MATRIX[3].xyz;                 // plant origin (instance position)
//       float h = VERTEX.y;                              // metres above the plant base
//       vec3 off = frontier_wind(wp, h, 1.0, frontier_hash(base.xz) * 6.2832)
//                + frontier_trample(base, h);            // grass only
//       VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
//   }
//
// The globals are declared in project.godot [shader_globals] and driven by EnvironmentRig.

global uniform vec2 wind_direction;   // XZ unit vector the wind blows TOWARD
global uniform float wind_strength;   // 0 calm .. 1 strong (default 0.3: late-afternoon breeze)
global uniform vec3 player_position;  // feet of the player, updated every frame
global uniform vec3 sun_direction;    // unit vector toward the sun (world space)

float frontier_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Gust field 0..1: broad gust fronts rolling downwind at about 4 m/s.
float frontier_gust(vec2 xz) {
	vec2 d = normalize(wind_direction + vec2(1e-5));
	float along = dot(xz, d);
	float across = dot(xz, vec2(-d.y, d.x));
	float g = 0.5 + 0.5 * sin(along * 0.08 - TIME * 0.32);
	g *= 0.7 + 0.3 * sin(across * 0.045 + along * 0.02 - TIME * 0.4);
	return clamp(g, 0.0, 1.0);
}

// World-space sway offset (m) of a vertex at world position wp, h metres above the plant base.
// flex: grass 1.0, fern 0.6, shrub 0.35, sapling 0.2, broadleaf twig/leaf 0.12,
//       conifer branch 0.06, trunk 0.015.  phase: 0..2pi per plant (de-syncs neighbours).
// Tip offset ~ wind_strength * flex * h^1.5 * 0.9 at full gust (grass 0.5 m: ~0.1 m at 0.3).
vec3 frontier_wind(vec3 wp, float h, float flex, float phase) {
	vec2 d = normalize(wind_direction + vec2(1e-5));
	float hh = max(h, 0.0);
	float s = wind_strength * (0.35 + 0.65 * frontier_gust(wp.xz));
	float sway = sin(TIME * (1.2 + 0.8 * flex) + phase);
	float bend = s * flex * pow(hh, 1.5) * 0.9;
	vec3 lean = vec3(d.x, 0.0, d.y) * bend * (0.75 + 0.25 * sway)
			+ vec3(-d.y, 0.0, d.x) * bend * 0.2 * sin(TIME * 0.9 + phase * 1.7);
	float flutter = sin(TIME * 7.0 + phase * 3.1 + wp.x * 1.9 + wp.z * 1.3) * 0.025 * s * flex * hh;
	lean += vec3(flutter, 0.0, -flutter * 0.6);
	// Keep the stem length roughly constant: the tip drops as it leans.
	lean.y = -dot(lean.xz, lean.xz) / max(2.0 * hh, 0.05);
	return lean;
}

// Grass pushed aside and flattened around the player's feet (radius ~1.1 m).
vec3 frontier_trample(vec3 base_wp, float h) {
	vec3 to = base_wp - player_position;
	float dist = length(to.xz);
	float k = (1.0 - smoothstep(0.25, 1.1, dist)) * (1.0 - step(1.5, abs(to.y)));
	vec2 dir = dist > 1e-3 ? to.xz / dist : vec2(0.0, 1.0);
	return vec3(dir.x, -0.7, dir.y) * k * max(h, 0.0) * 0.8;
}

// Soft translucency term for thin foliage lit from behind (use in light() or as an emission
// boost): 0 when the view looks away from the sun, 1 looking straight into it.
float frontier_backlight(vec3 view_dir_world) {
	return pow(clamp(dot(-view_dir_world, sun_direction), 0.0, 1.0), 4.0);
}
