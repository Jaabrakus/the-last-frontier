shader_type spatial;
// A crack in the deck (ToonCrack; earth's gather and casts in the show's cel style, 2026-10-16): a flat strip laid along a
// jagged line on the ground, its UV.x 0 at the start to 1 at the end, UV.y across. A dark ink line wanders down its middle
// (the noise), a pale lip of broken deck either side of it, torn in and out along it; `reveal` (instance) is how much of its
// length shows, so it races out from its start (the racing front a little paler and wider: a hot edge, no glow); `t`
// (instance) its age 0 -> 1 (it fades over the last part). Thinned near the camera (fx_common near_cut).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"

uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform vec3 c_ink : source_color = vec3(0.07, 0.045, 0.03);
uniform vec3 c_lip : source_color = vec3(0.80, 0.70, 0.54);
uniform vec3 c_head : source_color = vec3(0.98, 0.92, 0.78);
uniform float lip = 0.62;
uniform float core = 0.3;
uniform float wander = 0.5;
uniform float ink = 0.0;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float reveal = 1.0;  // (the web build: a plain uniform, each object its own material; FxParams)
uniform float t = 0.0;
uniform float seed = 0.0;
#else
instance uniform float reveal = 1.0;
instance uniform float t = 0.0;
instance uniform float seed = 0.0;
#endif

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy)) {
		discard;
	}
	float u = UV.x;
	if (u > reveal) {
		discard;
	}
	float v = UV.y * 2.0 - 1.0;
	float n = texture(noise, vec2(u * 5.0 + seed, 0.31 + seed * 0.4)).r - 0.5;
	float n2 = texture(noise, vec2(u * 13.0 + seed * 2.3, 0.71)).r - 0.5;
	float d = abs(v - n * wander);                                   // across, from the crack's own line
	float hw = core * (0.75 + n2 * 1.1);                             // the ink's half width, torn along it
	float head = (1.0 - aastep(reveal, u + 0.07)) * aastep(reveal - 0.14, u);     // the racing front
	float ink_k = 1.0 - aastep(hw + head * 0.12, d);
	float lip_k = (1.0 - aastep(hw + lip * (0.8 + n2 * 0.9), d)) * (1.0 - ink_k);
	float ends = aastep(0.0, min(u, 1.0 - u) * 7.0 - 0.1);          // tapered in and out
	float life = 1.0 - smoothstep(0.62, 1.0, t);
	vec4 col = vec4(c_lip, 0.62) * lip_k;
	col = mix(col, vec4(c_ink, 0.96), ink_k);
	col = mix(col, vec4(c_head, 1.0), head * ink_k);
	float a = clamp(col.a, 0.0, 1.0) * ends * life;
	if (a <= 0.02) {
		discard;
	}
	ALBEDO = col.rgb * fx_gain;
	ALPHA = a;
}
