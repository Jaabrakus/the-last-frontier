shader_type spatial;
// Cel facets (ToonFx): each face flat (its normal from the screen), lit by the cel sun in three hard tones, a light rim where
// it turns away, and for ice a glint that sweeps across now and then. Ice shards and crystals, rock chunks and debris (as
// meshes or particles).
// Round 4 (LOOKS): `range_on` (instance, a bolt's core: the rock, the ice crystal) grows it about its origin with its
// distance from the camera (fx_common range_scale); thinned near the camera (near_cut).
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"

uniform vec3 c_light : source_color = vec3(0.92, 0.98, 1.0);
uniform vec3 c_mid : source_color = vec3(0.55, 0.82, 0.98);
uniform vec3 c_dark : source_color = vec3(0.18, 0.45, 0.78);
uniform vec3 c_rim : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 c_ink : source_color = vec3(0.04, 0.12, 0.25);
uniform float ink = 0.0;
uniform float rim = 0.62;
uniform float rim_on = 1.0;
uniform float glint = 1.0;
uniform float glow = 1.0;
instance uniform float range_on = 0.0;

varying vec3 v_wpos;

void vertex() {
	if (range_on > 0.5) {
		VERTEX *= range_scale(length(CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz));
	}
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy)) {
		discard;
	}
	vec3 N = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(N, VIEW) < 0.0) {
		N = -N;
	}
	float d = dot(N, cel_light(VIEW_MATRIX));
	vec3 col = c_dark;
	col = mix(col, c_mid, aastep(0.05, d));
	col = mix(col, c_light, aastep(0.62, d));
	float fres = 1.0 - clamp(dot(N, VIEW), 0.0, 1.0);
	col = mix(col, c_rim, rim_on * aastep(rim, fres));
	if (glint > 0.0) {
		float s = fract(dot(v_wpos, vec3(0.55, 0.9, 0.35)) * 0.7 - TIME * 0.9);
		col = mix(col, vec3(2.2), glint * (1.0 - aastep(0.05, s)) * aastep(0.0, d + 0.2));
	}
	col = mix(col, c_ink, ink * aastep(0.8, fres));
	ALBEDO = (col * glow) * fx_gain;
}
