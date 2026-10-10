// MI_SimpleFresnelBall (parent M_SimpleFresnelBall): rim-lit range sphere.
// SOURCE VALUES: fresnel edge 1.2927, depth opacity 0.3368, fade distance 179.5 cm.
// AUTHORED: rim = pow(1 - N.V, fresnel_edge).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/cascade/common.gdshaderinc"
#include "res://shaders/cascade/particle.gdshaderinc"
uniform float fresnel_edge = 1.2927;
uniform float depth_opacity = 0.3368;
uniform float fade_distance = 1.795;

void vertex() {
	vec4 _e; vec4 _d;
	particle_vertex(VERTEX, UV, INSTANCE_CUSTOM, INSTANCE_ID, UV2, _e, _d);
	v_extra = _e; v_dyn = _d; v_color = COLOR; v_quv = UV;
}
