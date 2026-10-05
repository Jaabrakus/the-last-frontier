shader_type spatial;
// Cel water (ToonFx): a deep blue body under a cel sun (lit and shade), a pale rim where it turns away (fresnel, in a hard
// band), white foam where a flowing noise crests, a hard highlight, see-through enough to show what it holds.
//   mode 0  a mesh (a bolt's head, a bubble, a wall, a splash crown); `wobble` m of vertex swell
//   mode 1  a strip along a line (ToonRibbon) shaded as a round tube (the stream behind a water bolt)
// `flow` scrolls the foam (UV per s); `fade` (instance) eats it away from its thin places.
render_mode unshaded, blend_mix, depth_draw_always, cull_back, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"

uniform int mode = 0;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform vec4 c_shade : source_color = vec4(0.07, 0.34, 0.80, 0.86);
uniform vec4 c_body : source_color = vec4(0.12, 0.52, 0.96, 0.80);
uniform vec4 c_rim : source_color = vec4(0.55, 0.88, 1.0, 0.92);
uniform vec4 c_foam : source_color = vec4(0.94, 0.99, 1.0, 1.0);
uniform vec3 c_ink : source_color = vec3(0.02, 0.10, 0.25);
uniform float ink = 0.0;
uniform vec2 flow = vec2(0.0, -0.9);
uniform vec2 nscale = vec2(2.0, 1.4);
uniform float foam = 0.66;
uniform float rim = 0.52;
uniform float wobble = 0.0;
uniform float alpha_mul = 1.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

varying vec3 v_side;
varying vec3 v_wpos;

void vertex() {
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 w;
	if (mode == 0) {
		vec3 nv = VERTEX;
		if (wobble > 0.0) {
			float s = textureLod(noise, UV * 1.5 + vec2(TIME * 0.21, TIME * 0.13) + seed, 0.0).r;
			nv += NORMAL * (s - 0.5) * 2.0 * wobble;
		}
		w = (MODEL_MATRIX * vec4(nv, 1.0)).xyz;
		NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		v_side = vec3(0.0);
	} else {
		vec3 c = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 along = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
		w = strip_point(c, along, UV2.x, UV.y, cam);
		v_side = normalize((VIEW_MATRIX * vec4(w - c + vec3(1e-6), 0.0)).xyz);
		NORMAL = vec3(0.0, 0.0, 1.0);
	}
	v_wpos = w;
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
}

void fragment() {
	vec3 N = NORMAL;
	if (mode == 1) {
		float a = UV.y * 2.0 - 1.0;
		N = normalize(v_side * a + vec3(0.0, 0.0, 1.0) * sqrt(max(1.0 - a * a, 0.0)));
	}
	vec2 fuv = UV * nscale + flow * TIME + vec2(seed);
	float n = texture(noise, fuv).r;
	float n2 = texture(noise, fuv * 2.3 + vec2(0.5, 0.1) - flow * TIME * 0.4).r;
	float fres = 1.0 - clamp(dot(N, VIEW), 0.0, 1.0);
	vec3 L = cel_light(VIEW_MATRIX);
	float d = dot(N, L) + (n - 0.5) * 0.3;
	vec4 col = c_shade;
	col = mix(col, c_body, aastep(-0.05, d));
	col = mix(col, c_rim, aastep(rim, fres + (n2 - 0.5) * 0.25));
	float fm = n * 0.75 + n2 * 0.45;
	if (mode == 1) {
		fm += UV.x * 0.35;                               // the stream breaks to foam toward its tail
	}
	col = mix(col, c_foam, aastep(foam, fm));
	vec3 H = normalize(L + VIEW);
	col = mix(col, vec4(1.0), aastep(0.93, dot(N, H)));
	col.rgb = mix(col.rgb, c_ink, ink * aastep(0.86, fres));
	float keep = fm + 0.35 - (1.0 - fade) * 1.4;
	if (mode == 1) {
		keep -= smoothstep(0.55, 1.0, UV.x) * 0.9;
	}
	float a = aastep(0.0, keep);
	if (a <= 0.01) {
		discard;
	}
	ALBEDO = (col.rgb) * fx_gain;
	ALPHA = col.a * alpha_mul * a;
}
