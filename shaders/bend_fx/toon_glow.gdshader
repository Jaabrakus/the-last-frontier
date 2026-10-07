shader_type spatial;
// The soft glow under a flame cluster (round 4 LOOKS, ToonFx "flame_glow"): a radial quad facing the camera, added to what
// is behind it, no hard edge anywhere: a fireball's, a fire wall's, the Kick's. Drawn first among the effects (its
// material's render_priority) and set back a little from its cluster so it lies behind it. Soft where it meets the deck,
// thinned near the camera, a slow flicker. Its scale's X and Y its width and height (a wall's glow is long and low).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 c_glow : source_color = vec3(1.0, 0.42, 0.1);
uniform float strength = 0.55;
uniform float flicker = 0.14;
uniform float back_m = 0.25;
uniform float deck_fade_m = 0.5;
instance uniform float seed = 0.0;
instance uniform float glow_k = 1.0;

void vertex() {
	vec3 c = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	c += normalize(c) * min(sx, sy) * back_m;
	VERTEX = c + vec3(VERTEX.x * sx, VERTEX.y * sy, 0.0);
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float g = 1.0 - smoothstep(0.0, 1.0, r);
	g *= g;
	float f = 1.0 + flicker * (sin(TIME * 7.3 + seed * 11.0) * 0.6 + sin(TIME * 12.9 + seed * 5.0) * 0.4);
	g *= near_fade(length(VERTEX)) * own_fade;
	g *= deck_soft(texture(depth_tex, SCREEN_UV).r, SCREEN_UV, INV_PROJECTION_MATRIX, VERTEX, deck_fade_m);
	ALBEDO = c_glow * strength * f * glow_k * fx_gain * clamp(g, 0.0, 1.0);
	ALPHA = 1.0;
}
