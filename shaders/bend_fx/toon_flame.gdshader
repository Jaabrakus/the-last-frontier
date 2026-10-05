shader_type spatial;
// A cel flame (ToonFx): banded white-yellow core, yellow, orange and a red rim, the outline torn into tongues by a noise
// that scrolls from the base to the tip (the licks). Cut hard (no soft alpha): a 2D-animated flame stood in 3D.
//   mode 0  a quad turned round its own axis to face the camera (local Y the flame's length from its base, local X its
//           width): a fire wall's flames (one MultiMesh), a fireball's trailing tongues
//   mode 1  a strip along a line (ToonRibbon: UV.x 0 at the head .. 1 at the tail, UV.y across, UV2.x the half width)
// `grow` (instance) raises it from nothing; `ink` draws a dark outline round it.
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"

uniform int mode = 0;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform vec3 c_core : source_color = vec3(1.0, 0.97, 0.78);
uniform vec3 c_hot : source_color = vec3(1.0, 0.80, 0.16);
uniform vec3 c_mid : source_color = vec3(1.0, 0.40, 0.03);
uniform vec3 c_edge : source_color = vec3(0.80, 0.10, 0.03);
uniform vec3 c_ink : source_color = vec3(0.16, 0.02, 0.02);
uniform float ink = 0.0;
uniform float glow = 2.2;
uniform float speed = 2.4;
uniform float turb = 0.95;
uniform vec2 nscale = vec2(1.1, 1.3);
uniform float taper = 0.18;
instance uniform float seed = 0.0;
instance uniform float grow = 1.0;

varying float v_seed;

void vertex() {
	v_seed = seed + float(INSTANCE_ID) * 0.618034;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 w;
	if (mode == 0) {
		vec3 c = MODEL_MATRIX[3].xyz;
		float wd = length(MODEL_MATRIX[0].xyz);
		w = axis_billboard(vec3(VERTEX.x, VERTEX.y * grow, 0.0), c, MODEL_MATRIX[1].xyz, wd, MODEL_MATRIX[0].xyz / max(wd, 1e-4), cam);
	} else {
		w = strip_point((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz, (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz, UV2.x, UV.y, cam);
	}
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float along = mode == 0 ? 1.0 - UV.y : UV.x;
	float x = mode == 0 ? UV.x * 2.0 - 1.0 : UV.y * 2.0 - 1.0;
	float across = mode == 0 ? UV.x : UV.y;
	vec2 nuv = vec2(across * nscale.x + v_seed * 0.37, along * nscale.y - TIME * speed + v_seed * 1.31);
	float n = texture(noise, nuv).r;
	float n2 = texture(noise, nuv * vec2(1.9, 2.3) + vec2(0.41, -TIME * speed * 0.7)).r;
	x += (n2 - 0.5) * 0.7 * along;                     // the tongues sway toward the tip
	float width = mix(1.0, taper, pow(along, 0.8));
	float body = 1.0 - abs(x) / width;
	float v = body * (1.15 - along) + (n - 0.5) * turb * (0.35 + along * 0.9) - along * 0.12;
	float o = 0.03;
	float a = aastep(o, v);
	if (a < 0.5) {
		discard;
	}
	vec3 col = c_edge;
	col = mix(col, c_mid, aastep(o + 0.14, v));
	col = mix(col, c_hot, aastep(o + 0.33, v));
	col = mix(col, c_core * glow, aastep(o + 0.56, v));
	col = mix(col, c_ink, ink * (1.0 - aastep(o + 0.06, v)));
	ALBEDO = (col) * fx_gain;
}
