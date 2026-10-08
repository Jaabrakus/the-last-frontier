shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://shaders/bend_fx/fx_common.gdshaderinc"
instance uniform float t = 0.0;
instance uniform float seed = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform vec4 tint2 : source_color = vec4(1.0);
uniform float ink = 0.0;
void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy)) { discard; }
	ALBEDO = mix(tint.rgb, tint2.rgb, 0.16 * (1.0 - t)) * fx_gain;
	ALPHA = (1.0 - smoothstep(0.22, 1.0, t)) * 0.76;
}
