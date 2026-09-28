// Dust motes around the camera (look-dev spec 4.3, package A): particle process shader.
// Particles live in world space (the emitter is not local-coords) so they keep proper parallax
// while the player walks, and wrap around the emitter (which EnvironmentRig keeps on the camera)
// inside a box of +-box_half, so the camera is always surrounded by them without re-spawning.
shader_type particles;

global uniform vec2 wind_direction;
global uniform float wind_strength;

uniform vec3 box_half = vec3(8.0, 3.0, 8.0);
uniform float size_min = 0.004;
uniform float size_max = 0.011;
// Drift: a fraction of the breeze plus a slow per-mote wobble (m/s).
uniform float wind_follow = 0.18;
uniform float wobble = 0.05;

float hash1(uint n) {
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return float(n & 0x7fffffffu) / float(0x7fffffff);
}

void start() {
	uint s = NUMBER * 7u + RANDOM_SEED * 131u;
	vec3 r = vec3(hash1(s), hash1(s + 1u), hash1(s + 2u));
	float size = mix(size_min, size_max, hash1(s + 3u) * hash1(s + 4u));
	if (RESTART_POSITION) {
		TRANSFORM = mat4(vec4(size, 0.0, 0.0, 0.0), vec4(0.0, size, 0.0, 0.0), vec4(0.0, 0.0, size, 0.0),
				vec4(EMISSION_TRANSFORM[3].xyz + (r * 2.0 - 1.0) * box_half, 1.0));
	}
	CUSTOM = vec4(hash1(s + 5u) * 6.2831, hash1(s + 6u), 0.0, 0.0);
	VELOCITY = vec3(0.0);
}

void process() {
	float ph = CUSTOM.x;
	vec2 wd = normalize(wind_direction + vec2(1e-5));
	vec3 w = vec3(wd.x, 0.0, wd.y) * wind_strength * wind_follow;
	vec3 wob = vec3(sin(TIME * 0.37 + ph), 0.6 * sin(TIME * 0.23 + ph * 1.7), cos(TIME * 0.31 + ph * 2.3)) * wobble;
	VELOCITY = w + wob;
	// Wrap around the emitter (the camera).
	vec3 c = EMISSION_TRANSFORM[3].xyz;
	vec3 rel = TRANSFORM[3].xyz - c;
	rel = mod(rel + box_half, 2.0 * box_half) - box_half;
	TRANSFORM[3].xyz = c + rel;
}
