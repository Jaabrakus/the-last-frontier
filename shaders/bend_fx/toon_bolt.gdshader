shader_type spatial;
// Cel lightning (ToonFx): strips along the forks (ToonFx.lightning builds them: UV.x along, UV.y across, UV2.x the half
// width, UV2.y how thick a fork is 0..1), a white-hot core in a hard electric-blue sheath, a thin dark-violet edge with ink.
// `fade` (instance) thins it out; it is rebuilt a few times while it lasts (the flicker).
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"

uniform vec3 c_core : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 c_sheath : source_color = vec3(0.28, 0.48, 1.0);
uniform vec3 c_ink : source_color = vec3(0.16, 0.08, 0.38);
uniform float ink = 0.0;
uniform float glow = 5.0;
uniform float sheath_glow = 1.25;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float fade = 1.0;  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform float fade = 1.0;
#endif

void vertex() {
	vec3 c = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 w = strip_point(c, (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz, UV2.x, UV.y, CAMERA_POSITION_WORLD);
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy)) {
		discard;
	}
	float a = abs(UV.y * 2.0 - 1.0);
	float v = 1.0 - a - (1.0 - fade) * 0.9;
	if (aastep(0.0, v) < 0.5) {
		discard;
	}
	vec3 col = mix(c_sheath * sheath_glow, c_core * glow, aastep(0.56 + (1.0 - UV2.y) * 0.1, v));
	col = mix(col, c_ink, ink * (1.0 - aastep(0.12, v)));
	ALBEDO = (col) * fx_gain;
}
