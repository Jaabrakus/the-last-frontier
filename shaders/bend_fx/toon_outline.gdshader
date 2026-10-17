shader_type spatial;
// The dark drawn line round a cel rock (ToonFx "rock_outline"; earth in the show's cel style, 2026-10-16): the same mesh
// drawn again pushed out along its (smooth) normals and with its front faces culled, so only a rim of it shows round the
// shape: an inverted hull. `width` m, grown with the distance from the camera so the line stays about as thick on the
// screen near and far. Unshaded, no shadow; thinned near the camera (fx_common near_cut).
render_mode unshaded, cull_front, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"

uniform vec3 c_ink : source_color = vec3(0.09, 0.06, 0.04);
uniform float width = 0.022;
uniform float far_k = 0.16;
uniform float ink = 0.0;
void vertex() {
	vec3 v = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float d = length(v);
	float w = width * clamp(0.5 + d * far_k, 0.5, 4.0);
	VERTEX = v + n * w;
	NORMAL = n;
}

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = c_ink * fx_gain;
}
