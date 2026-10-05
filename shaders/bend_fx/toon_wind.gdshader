shader_type spatial;
// Cel wind (ToonFx): translucent white bands torn into streaks that run along them, a pale blue lower band at their thin
// edges. The air made visible as a 2D effect draws it: swirls, crescents, speed lines.
//   mode 0  a band mesh (ToonFx.band_mesh: UV.x round, UV.y across), turning `spin` rad/s round its local Y (a shield's
//           rings, a tornado's, an air ball's swirl)
//   mode 1  a strip along a line (ToonRibbon: UV.x along, UV.y across): speed lines
//   mode 2  a flat crescent mesh (UV.x along the arc, UV.y across): an air slice
// `fade` (instance) eats it away.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"

uniform int mode = 0;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform vec4 c_main : source_color = vec4(1.0, 1.0, 1.0, 0.92);
uniform vec4 c_edge : source_color = vec4(0.62, 0.86, 1.0, 0.62);
uniform vec3 c_ink : source_color = vec3(0.25, 0.42, 0.6);
uniform float ink = 0.0;
uniform float spin = 4.0;
uniform float speed = 1.6;
uniform vec2 nscale = vec2(3.0, 0.6);
uniform float streak = 0.5;
uniform float glow = 1.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

void vertex() {
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 w;
	if (mode == 1) {
		vec3 c = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		w = strip_point(c, (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz, UV2.x, UV.y, cam);
	} else {
		vec3 v = VERTEX;
		if (mode == 0) {
			float a = TIME * spin + seed * 6.2831;
			v = vec3(v.x * cos(a) - v.z * sin(a), v.y, v.x * sin(a) + v.z * cos(a));
		}
		w = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
	}
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float along = UV.x;
	float across = UV.y;
	float n = texture(noise, vec2(along * nscale.x - TIME * speed * (mode == 0 ? 0.0 : 1.0) + seed, across * nscale.y + seed * 0.7)).r;
	float mid = 1.0 - abs(across * 2.0 - 1.0);
	float v = n * 1.1 + mid * 0.75 - streak - (1.0 - fade) * 1.3;
	if (mode == 1) {
		v -= along * 0.9;                                   // a speed line thins to its tail
	} else if (mode == 2) {
		v -= pow(abs(along * 2.0 - 1.0), 3.0) * 0.9;           // a crescent thins to its horns
	}
	float a = aastep(0.0, v);
	if (a <= 0.01) {
		discard;
	}
	float core = aastep(0.28, v);
	vec4 col = mix(c_edge, c_main, core);
	col.rgb = mix(col.rgb, c_ink, ink * (1.0 - aastep(0.07, v)));
	ALBEDO = (col.rgb * glow) * fx_gain;
	ALPHA = col.a * a;
}
