// MI_SimpleGlow_FireballCore (parent M_SimpleGlow): flat emissive ball.
// SOURCE VALUES: camera fade offset 600 cm, length 1 cm (hidden within 6 m of the camera).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/cascade/common.gdshaderinc"
#include "res://shaders/cascade/particle.gdshaderinc"
uniform float camera_fade_offset = 6.0;
uniform float camera_fade_length = 0.01;

void vertex() {
	vec4 _e; vec4 _d;
	particle_vertex(VERTEX, UV, INSTANCE_CUSTOM, INSTANCE_ID, UV2, _e, _d);
	v_extra = _e; v_dyn = _d; v_color = COLOR; v_quv = UV;
}
