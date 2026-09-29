// The falling rain and snow (WeatherFx's rain streaks, SnowFall's flakes; user 2026-09-28: "rain and snow still fall
// through roofs"): the draw pass of their particles, the StandardMaterial3D looks they had (unshaded, alpha, faded in
// from the lens), and a drop or a flake under a roof or a floor above is not drawn: the shelter map SnowCover builds
// from the level's colliders (snow.gdshaderinc snow_sheltered; the particle's own position, so one fetch a particle).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/common/snow.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D tex : source_color, hint_default_white, filter_linear_mipmap;
/// 0: facing the camera (the flakes, BILLBOARD_PARTICLES); 1: upright, turned to the camera (the rain's streaks,
/// BILLBOARD_FIXED_Y), the particle's scale kept in both.
uniform int billboard = 0;
/// Faded in from the lens: none nearer than fade_min (m), all from fade_max.
uniform float fade_min = 1.0;
uniform float fade_max = 3.0;

varying float v_keep;

void vertex() {
	vec3 at = MODEL_MATRIX[3].xyz;
	v_keep = snow_sheltered(at) ? 0.0 : 1.0;
	mat4 scale = mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	if (billboard == 1) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
				vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
				vec4(at, 1.0)) * scale;
	} else {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]),
				normalize(INV_VIEW_MATRIX[2]), vec4(at, 1.0)) * scale;
	}
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	if (v_keep < 0.5) {
		VERTEX = vec3(0.0);     // (under a roof: collapsed, nothing drawn)
	}
}

void fragment() {
	vec4 c = texture(tex, UV) * tint;
	ALBEDO = c.rgb;
	ALPHA = c.a * v_keep * smoothstep(fade_min, fade_max, length(VERTEX));
}
