shader_type spatial;
// The dark drawn line round a cel rock (ToonFx "rock_outline"; earth in the show's cel style, 2026-10-16): the same mesh drawn
// again pushed out along its (smooth) normals and with its front faces culled, so only a rim of it shows round the shape: an
// inverted hull. `width` m, grown with the distance from the camera so the line stays about as thick on the screen near and
// far, and `line_k` (instance) its share for small rocks (a pebble's line is thinner than a boulder's). `range_on` (instance,
// a bolt's core) grows it with the core at range, as toon_facet does. Unshaded, no shadow; thinned near the camera.
render_mode unshaded, cull_front, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"

uniform vec3 c_ink : source_color = vec3(0.09, 0.06, 0.04);
uniform float width = 0.028;
uniform float far_k = 0.16;
uniform float ink = 0.0;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float range_on = 0.0;  // (the web build: a plain uniform, each object its own material; FxParams)
uniform float line_k = 1.0;
uniform float fade = 1.0;
#else
instance uniform float range_on = 0.0;
instance uniform float line_k = 1.0;
// (your own wall seen through, OwnFade: `fade` in a screen-door as the rock's own)
instance uniform float fade = 1.0;
#endif

void vertex() {
	vec3 p = VERTEX;
	if (range_on > 0.5) {
		p *= range_scale(length(CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz));
	}
	vec3 v = (MODELVIEW_MATRIX * vec4(p, 1.0)).xyz;
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float d = length(v);
	float w = width * line_k * clamp(0.5 + d * far_k, 0.5, 4.0);
	VERTEX = v + n * w;
	NORMAL = n;
}

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy) || dither_cut(fade, FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = c_ink * fx_gain;
}
