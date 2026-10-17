shader_type spatial;
// Cel wind (ToonFx): translucent white bands torn into streaks that run along them, a pale blue lower band at their thin
// edges. The air made visible as a 2D effect draws it: swirls, crescents, speed lines.
//   mode 0  a band mesh (ToonFx.band_mesh: UV.x round, UV.y across), turning `spin` rad/s round its local Y (a shield's
//           rings, a tornado's, an air ball's swirl)
//   mode 1  a strip along a line (ToonRibbon: UV.x along, UV.y across): speed lines
//   mode 2  a flat crescent mesh (UV.x along the arc, UV.y across): an air slice
//   mode 3  a drawn stroke along a line (ToonRibbon, as mode 1): a clean body with an ink line down each edge, tapered to
//           its tail, torn only a little (the anime air, 2026-10-16: swirl lines drawn as bold curved strokes)
//   mode 4  a sphere shell (ToonFx.sphere): a translucent pale ball with a bright rim, curved streak lines wrapping it from pole to
//           pole (the show's compressed air: the gather ball, the flying ball)
// `fade` (instance) eats it away.
// Round 2 (2026-10-17, the anime air): `ink_px` > 0 draws the outline that many pixels wide at any distance (a thin light grey,
// never black) instead of a share of the shape; `min_px` > 0 keeps a strip (mode 1, 3) at least that many pixels across at any
// distance; the shapes change at `step_hz` a second (drawn on twos) while what carries them moves smoothly.
// Round 4 (LOOKS): `band_w` (instance) draws a band that share as wide about its middle, its silhouette edge kept (your own
// Wind Guard, seen from your own camera: 0.6); `range_on` (instance, a bolt's core) grows it with its distance from the
// camera (fx_common range_scale); thinned near the camera (near_cut).
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
uniform float ink_px = 0.0;
uniform float min_px = 0.0;
uniform float step_hz = 12.0;
uniform float lines = 7.0;
uniform float twist = 1.6;
uniform float line_w = 0.07;
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
uniform float band_w = 1.0;  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform float band_w = 1.0;
#endif
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float range_on = 0.0;  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform float range_on = 0.0;
#endif

varying vec3 v_n;

// the time the drawing is at: held for 1 / step_hz s, then the next drawing (the shapes step on twos)
float drawn_time() {
	return floor(TIME * step_hz) / step_hz;
}

void vertex() {
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 w;
	v_n = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(NORMAL, 0.0))).xyz);
	if (mode == 1 || mode == 3) {
		vec3 c = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float hw = UV2.x;
		if (min_px > 0.0) {
			// (never under min_px pixels across: a metre is fewer pixels the further off it is)
			float px = length(cam - c) * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
			hw = max(hw, px * 0.5 * min_px);
		}
		w = strip_point(c, (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz, hw, UV.y, cam);
	} else {
		vec3 v = VERTEX;
		if (mode == 0) {
			float a = drawn_time() * spin + seed * 6.2831;
			v = vec3(v.x * cos(a) - v.z * sin(a), v.y, v.x * sin(a) + v.z * cos(a));
		}
		if (range_on > 0.5) {
			v *= range_scale(length(cam - MODEL_MATRIX[3].xyz));
		}
		w = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
	}
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

// 1 inside `px` pixels of the edge of a shape whose field `v` is 0 at the edge and grows inward, 0 beyond
float edge_px(float v, float px) {
	float d = v / max(fwidth(v), 1e-4);
	return 1.0 - smoothstep(px - 0.6, px + 0.4, d);
}

void fragment() {
	if (mode == 4) {
		float T = drawn_time();
		float fr = 1.0 - abs(v_n.z);                     // 0 face-on, 1 at the silhouette
		float x = UV.x * lines + (UV.y - 0.5) * twist - T * spin * 0.15 + seed;
		float dd = 0.5 - abs(fract(x) - 0.5);            // how far (in x) from the nearest line
		float pole = pow(clamp(sin(3.14159 * UV.y), 0.0, 1.0), 0.6);
		float lw = max(line_w * pole * fade, 1.6 * fwidth(x));   // its half width, never under about 2 px
		float ln = 1.0 - smoothstep(lw * 0.7, lw, dd);
		float lcore = 1.0 - smoothstep(lw * 0.25, lw * 0.55, dd);
		float rim = edge_px(1.0 - fr, max(ink_px, 1.0));
		vec3 col = mix(c_edge.rgb, c_main.rgb, 1.0 - fr);
		col = mix(col, c_ink, ink * rim);
		col = mix(col, mix(c_ink, c_main.rgb, lcore), ln);
		float body = (0.16 + 0.5 * fr * fr) * fade;
		float al = clamp(max(max(body, ln), rim * ink), 0.0, 1.0);
		ALBEDO = col * glow * fx_gain;
		ALPHA = al * near_fade(length(VERTEX)) * own_fade;
		return;
	}
	float along = UV.x;
	float across = (UV.y - 0.5) / max(band_w, 0.05) + 0.5;
	if (across < 0.0 || across > 1.0) {
		discard;
	}
	float n = texture(noise, vec2(along * nscale.x - drawn_time() * speed * (mode == 0 ? 0.0 : 1.0) + seed, across * nscale.y + seed * 0.7)).r;
	float mid = 1.0 - abs(across * 2.0 - 1.0);
	float v = n * 1.1 + mid * 0.75 - streak - (1.0 - fade) * 1.3;
	if (mode == 1) {
		v -= along * 0.9;                                   // a speed line thins to its tail
	} else if (mode == 2) {
		v -= pow(abs(along * 2.0 - 1.0), 3.0) * 0.9;           // a crescent thins to its horns
	} else if (mode == 3) {
		// a stroke: its body from its middle out (the noise only ruffles its edge), thinned to its tail, eaten by the fade
		v = mid * 1.25 - streak + (n - 0.5) * 0.3 - along * along * 1.05 - (1.0 - fade) * 1.3;
	}
	float a = aastep(0.0, v);
	if (a <= 0.01) {
		discard;
	}
	float core = aastep(mode == 3 ? 0.3 : 0.28, v);
	vec4 col = mix(c_edge, c_main, core);
	float rim_k = ink_px > 0.0 ? edge_px(v, ink_px) : 1.0 - aastep(mode == 3 ? 0.09 : 0.07, v);
	col.rgb = mix(col.rgb, c_ink, ink * rim_k);
	ALBEDO = (col.rgb * glow) * fx_gain;
	// (blended: the near fade is its alpha; your own Wind Guard's bands, band_w < 1, see-through inside their edge)
	float inside = mix(1.0, band_w, core);
	ALPHA = col.a * a * inside * near_fade(length(VERTEX)) * own_fade;
}
