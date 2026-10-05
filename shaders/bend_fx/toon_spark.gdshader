shader_type spatial;
// Cel sparks for particles (ToonFx): hard bright shapes with a white core and a coloured rim.
//   mode 0  streak: a lens drawn along the particle's flight (the process material's align_y: its Y is its velocity),
//           `stretch` times as long as it is wide (embers, speed lines, electric sparks)
//   mode 1  star: a four-pointed glint facing the camera that twinkles (ice sparkles, a flash)
// The ramp's alpha thins it to nothing; its colour is the rim.
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"

uniform int mode = 0;
uniform vec3 c_core : source_color = vec3(1.0, 1.0, 0.92);
uniform float glow = 2.0;
uniform float rim_glow = 1.3;
uniform float stretch = 5.0;
uniform float twinkle = 1.0;

varying float v_seed;

void vertex() {
	v_seed = float(INSTANCE_ID) * 0.754877;
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 w;
	if (mode == 0) {
		vec3 ax = MODEL_MATRIX[1].xyz;
		ax = length(ax) > 1e-5 ? normalize(ax) : vec3(0.0, 1.0, 0.0);
		w = axis_billboard(vec3(VERTEX.x, VERTEX.y, 0.0), c, ax * s * stretch, s, vec3(1.0, 0.0, 0.0), cam);
	} else {
		float tw = mix(1.0, 0.55 + 0.6 * sin(TIME * 23.0 + v_seed * 17.0), twinkle);
		vec3 r = INV_VIEW_MATRIX[0].xyz;
		vec3 u = INV_VIEW_MATRIX[1].xyz;
		w = c + (r * VERTEX.x + u * VERTEX.y) * s * max(tw, 0.0);
	}
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float fill = clamp(COLOR.a, 0.0, 1.0);
	float v;
	if (mode == 0) {
		float wy = 1.0 - p.y * p.y;
		v = (1.0 - abs(p.x) / max(wy * (0.35 + 0.65 * fill), 1e-3)) * step(abs(p.y), 1.0);
	} else {
		vec2 a = abs(p);
		v = 1.0 - (sqrt(a.x) + sqrt(a.y)) / (0.55 + 0.45 * fill);
	}
	if (aastep(0.0, v) < 0.5 || fill <= 0.02) {
		discard;
	}
	ALBEDO = (mix(COLOR.rgb * rim_glow, c_core * glow, aastep(0.62, v))) * fx_gain;
}
