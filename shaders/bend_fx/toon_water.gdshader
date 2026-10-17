shader_type spatial;
// Cel water (ToonFx): a deep blue body under a cel sun (lit and shade), a pale rim where it turns away (fresnel, in a hard
// band), white foam where a flowing noise crests, a hard highlight, see-through enough to show what it holds.
//   mode 0  a mesh (a bolt's head, a bubble, a wall, a splash crown); `wobble` m of vertex swell
//   mode 1  a strip along a line (ToonRibbon) shaded as a round tube (the stream behind a water bolt)
//   mode 2  the water's ribbon (the anime pass, 2026-10-16: the show's water, drawn as a 2D animator draws it): a flat cel
//           band facing the camera, no tube: a dark edge, the body, a glossy pale streak along it (`gloss`: where across),
//           white flecks running down it (`flow.x` m/s), torn white foam at both edges and a drawn line round it
//           (`outline`). UV.x metres along it from the head, UV2.y its share head (0) to tail (1); its vertex colour's red tears
//           it away (ToonRibbon.fade: 1 whole).
//           The gather drawn from a grate to the hands (BendCharge), the Lash's body, a Turn's swing.
// `flow` scrolls the foam (UV per s); `fade` (instance) eats it away from its thin places.
// Round 4 (LOOKS): `range_on` (instance, a bolt's head) grows it with its distance from the camera (fx_common range_scale);
// thinned near the camera (near_cut).
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
uniform float outline = 0.0;
uniform float gloss = 0.64;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float fade = 1.0;  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform float fade = 1.0;
#endif
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float seed = 0.0;  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform float seed = 0.0;
#endif
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float range_on = 0.0;  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform float range_on = 0.0;
#endif

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
		if (range_on > 0.5) {
			nv *= range_scale(length(cam - MODEL_MATRIX[3].xyz));
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
	if (mode == 2) {
		float across = UV.y;
		float e = 1.0 - abs(across * 2.0 - 1.0);              // 0 at either edge, 1 along the middle
		float share = UV2.y;
		float along = UV.x;
		float n = texture(noise, vec2(along * nscale.x * 0.35 + seed, across * nscale.y * 0.5 + seed * 0.7)).r;
		float n2 = texture(noise, vec2(along * 0.9 + flow.x * TIME * 0.35 + seed * 1.7, across * 1.7 + seed)).r;   // (flecks run toward the head)
		// the shade along one edge, the body, the gloss streak
		vec4 col = c_shade;
		col = mix(col, c_body, aastep(0.3, across + (n - 0.5) * 0.16));
		col = mix(col, c_rim, 1.0 - aastep(0.08, abs(across - gloss + (n - 0.5) * 0.1)));
		// white flecks running down the lit half
		float fleck = aastep(0.66, n2) * aastep(0.42, across) * (1.0 - aastep(0.88, across));
		col = mix(col, c_foam, fleck);
		// the torn foam at both edges, and the drawn line outside it
		col = mix(col, c_foam, 1.0 - aastep(0.12 + (n - 0.5) * 0.1, e));
		col.rgb = mix(col.rgb, c_ink, outline * (1.0 - aastep(0.045, e)));
		// torn away as it is let go (fade), and ragged at its tail
		float keep = e * 0.5 + 0.5 - (1.0 - COLOR.r) * (1.0 + n * 0.8) - smoothstep(0.92, 1.0, share) * (0.4 + n * 0.5);
		float ar = aastep(0.0, keep);
		if (ar <= 0.01) {
			discard;
		}
		ALBEDO = col.rgb * fx_gain;
		ALPHA = col.a * alpha_mul * ar * near_fade(length(VERTEX)) * own_fade;
	} else {
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
	col.rgb = mix(col.rgb, c_ink, max(ink, outline) * aastep(0.8, fres));
	float keep = fm + 0.35 - (1.0 - fade) * 1.4;
	if (mode == 1) {
		keep -= smoothstep(0.55, 1.0, UV.x) * 0.9;
	}
	float a = aastep(0.0, keep);
	if (a <= 0.01) {
		discard;
	}
	ALBEDO = (col.rgb) * fx_gain;
	ALPHA = col.a * alpha_mul * a * near_fade(length(VERTEX)) * own_fade;      // (blended: the near fade is its alpha)
	}
}
