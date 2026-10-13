shader_type spatial;
// A cel puff for particles (ToonFx): a round blob with a torn edge, facing the camera, turned by the particle's angle.
// Its colour ramp's alpha is how full it is: as it falls to 0 the blob is eaten from the edge and breaks into bits (a 2D
// effect's dissolve), never a soft fade.
//   mode 0  hot: banded from a bright core out (flame puffs, sparks of steam)
//   mode 1  lit: a ball under a cel sun, lit side, mid and shade (dust, smoke, steam, frost)
//   mode 2  drop: a droplet, lit, with a hard highlight (water spray)
// The ramp's colour tints it.
// Round 4 (LOOKS): thinned near the camera (fx_common near_cut); `occl` (instance: a struck body's middle and radius, w 0
// none) draws the puffs between the camera and that body at `half` (a screen-door), so a hit's burst never hides who was
// struck.
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"

uniform int mode = 0;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform vec3 c_a : source_color = vec3(1.0, 0.97, 0.78);
uniform vec3 c_b : source_color = vec3(1.0, 0.78, 0.15);
uniform vec3 c_c : source_color = vec3(1.0, 0.40, 0.03);
uniform vec3 c_d : source_color = vec3(0.78, 0.10, 0.03);
uniform vec3 c_ink : source_color = vec3(0.1, 0.05, 0.04);
uniform float ink = 0.0;
uniform float glow = 1.0;
uniform float wobble = 0.45;
uniform float nfreq = 0.55;
uniform float stretch = 1.0;
uniform float half_k = 0.5;
instance uniform vec4 occl = vec4(0.0);

varying float v_seed;
varying float v_half;

void vertex() {
	v_seed = float(INSTANCE_ID) * 0.754877 + INSTANCE_CUSTOM.x * 0.1;
	vec3 c = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	float an = INSTANCE_CUSTOM.x;
	vec2 q = VERTEX.xy * vec2(1.0, stretch) * s;
	q = vec2(q.x * cos(an) - q.y * sin(an), q.x * sin(an) + q.y * cos(an));
	VERTEX = c + vec3(q, 0.0);
	v_half = 0.0;
	if (occl.w > 0.0) {
		// (this puff between the camera and the struck body: along the camera's line to it, nearer, and within its width)
		vec3 cam = CAMERA_POSITION_WORLD;
		vec3 pc = MODEL_MATRIX[3].xyz;
		vec3 cb = occl.xyz - cam;
		float lb = max(length(cb), 1e-3);
		vec3 dir = cb / lb;
		float al = dot(pc - cam, dir);
		float perp = length((pc - cam) - dir * al);
		v_half = (al < lb - occl.w * 0.3 && perp < occl.w + s * 0.5) ? 1.0 : 0.0;
	}
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy) || (v_half > 0.5 && dither_cut(half_k, FRAGCOORD.xy))) {
		discard;
	}
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float n = texture(noise, UV * nfreq + vec2(v_seed, v_seed * 1.73)).r;
	float n2 = texture(noise, UV * nfreq * 2.7 + vec2(v_seed * 2.1, 0.3)).r;
	float fill = clamp(COLOR.a, 0.0, 1.0);
	float cut = (1.0 - fill);
	float v = (1.0 - r) + (n - 0.5) * wobble - cut * (0.75 + (n2 - 0.5) * 1.2);
	if (aastep(0.0, v) < 0.5) {
		discard;
	}
	float depth = v / max(1.0 - cut * 0.75, 0.1);
	vec3 col;
	if (mode == 0) {
		col = c_d;
		col = mix(col, c_c, aastep(0.12, depth));
		col = mix(col, c_b, aastep(0.30, depth));
		col = mix(col, c_a * glow, aastep(0.52, depth));
	} else {
		vec3 nv = normalize(vec3(p.x, -p.y, sqrt(max(1.0 - r * r, 0.0)) + 0.15));
		float d = dot(nv, cel_light(VIEW_MATRIX)) + (n - 0.5) * 0.35;
		col = c_c;
		col = mix(col, c_b, aastep(-0.15, d));
		col = mix(col, c_a, aastep(0.42, d));
		if (mode == 2) {
			float hl = length(p - vec2(-0.32, -0.34));
			col = mix(col, c_d, 1.0 - aastep(0.2, hl));
		}
	}
	col *= COLOR.rgb;
	col = mix(col, c_ink, ink * (1.0 - aastep(0.09, v)));
	ALBEDO = (col) * fx_gain;
}
