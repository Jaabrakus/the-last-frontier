shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://shaders/bend_fx/fx_common.gdshaderinc"
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float t = 0.0;  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform float t = 0.0;
#endif
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float seed = 0.0;  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform float seed = 0.0;
#endif
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform vec4 tint : source_color = vec4(1.0);  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform vec4 tint : source_color = vec4(1.0);
#endif
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform vec4 tint2 : source_color = vec4(1.0);  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform vec4 tint2 : source_color = vec4(1.0);
#endif
uniform float ink = 0.0;
void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy)) { discard; }
	ALBEDO = mix(tint.rgb, tint2.rgb, 0.16 * (1.0 - t)) * fx_gain;
	ALPHA = (1.0 - smoothstep(0.22, 1.0, t)) * 0.76;
}
