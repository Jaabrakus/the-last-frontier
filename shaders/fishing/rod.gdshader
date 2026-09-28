// A fishing rod (FishingGear, FishModels): ash, tapering; it bows toward what pulls it (user 2026-09-28: "where it can
// bend the pole", "the pole is curved"). `bend` 0..1 curves it in an arc toward `bend_dir` (the rod's own frame, square
// to its length: the pull's way, the fish's), stiff at the butt and loading from the tip (the curvature grows along it,
// TIP_ANGLE at the tip at full bend); the rod keeps its length. FishingGear.bent_point() is the same curve (the line's
// place at the tip).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 wood : source_color = vec3(0.58, 0.47, 0.32);
uniform float bend = 0.0;
uniform vec2 bend_dir = vec2(0.0, -1.0);
uniform float length_m = 3.8;

const float TIP_ANGLE = 1.45;
const int STEPS = 10;

void vertex() {
	float s = clamp(VERTEX.z, 0.0, length_m);
	// the curvature k(s) = K s / L: the turn along it th(s) = K s^2 / (2 L), th(L) = bend * TIP_ANGLE
	float K = 2.0 * bend * TIP_ANGLE / length_m;
	float ds = s / float(STEPS);
	vec2 c = vec2(0.0);
	for (int i = 0; i < STEPS; i++) {
		float sm = (float(i) + 0.5) * ds;
		float a = K * sm * sm / (2.0 * length_m);
		c += vec2(cos(a), sin(a)) * ds;
	}
	float th = K * s * s / (2.0 * length_m);
	vec3 z = vec3(0.0, 0.0, 1.0);
	vec3 n = length(bend_dir) > 1e-4 ? normalize(vec3(bend_dir, 0.0)) : vec3(0.0, -1.0, 0.0);
	vec3 o = vec3(VERTEX.xy, 0.0);
	float on = dot(o, n);
	vec3 n2 = cos(th) * n - sin(th) * z;
	vec3 z2 = cos(th) * z + sin(th) * n;
	VERTEX = z * c.x + n * c.y + (o - on * n) + on * n2;
	float nn = dot(NORMAL, n);
	float nz = NORMAL.z;
	NORMAL = normalize(NORMAL - nn * n - nz * z + nn * n2 + nz * z2);
}

void fragment() {
	// the grain: a little darker in streaks along it
	float g = 0.9 + 0.1 * sin(UV.y * 40.0 + sin(UV.x * 6.2831) * 2.0);
	ALBEDO = wood * g;
	ROUGHNESS = 0.6;
	SPECULAR = 0.35;
}
