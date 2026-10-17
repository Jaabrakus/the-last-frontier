shader_type spatial;
// Short-lived cel shapes the effects pool plays (ToonFxPool): `t` (instance) runs 0 -> 1 over its life, `tint` its colour.
//   mode 0  flash: a spiked star facing the camera, white at the heart (a launch, a hit)
//   mode 1  ring: a flat ring on its local XZ plane that runs out and thins (a shock ring, a ripple, a dust ring)
//   mode 2  crown: a band (ToonFx.band_mesh) whose torn top rises and drops (a splash crown)
//   mode 3  swirl: two crescents facing the camera that spin out (air)
//   mode 4  orb: a lasting ball of fire facing the camera, banded from a white heart, its edge boiling (a fireball's core)
//   mode 5  air heart: a flat white disc facing the camera, a pale shade crescent, an inked rim, a swirl drawn in it that turns
//           (the anime air, 2026-10-16: the heart of the ball of air)
// Round 4 (LOOKS): `range_on` (instance, a bolt's core orb) grows it with its distance from the camera (fx_common
// range_scale); thinned near the camera (near_cut).
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"

uniform int mode = 0;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform vec3 c_core : source_color = vec3(1.0, 1.0, 0.95);
uniform vec3 c_ink : source_color = vec3(0.08, 0.06, 0.06);
uniform float ink = 0.0;
uniform float glow = 2.5;
uniform float rays = 8.0;
// Round 2 (the anime air): `ink_px` > 0 draws the ink line that many pixels wide at any distance (a thin light grey); `t_steps` > 0
// steps a shape's own time in that many drawings over its life (drawn on twos); the swirl of a heart turns at 12 drawings a second.
uniform float ink_px = 0.0;
uniform float t_steps = 0.0;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float t = 0.0;  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform float t = 0.0;
#endif
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform vec4 tint : source_color = vec4(1.0, 0.6, 0.2, 1.0);  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform vec4 tint : source_color = vec4(1.0, 0.6, 0.2, 1.0);
#endif
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform vec4 tint2 : source_color = vec4(1.0, 0.9, 0.6, 1.0);  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform vec4 tint2 : source_color = vec4(1.0, 0.9, 0.6, 1.0);
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

void vertex() {
	if (mode == 0 || mode == 3 || mode == 4 || mode == 5) {
		vec3 c = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
		float s = length(MODEL_MATRIX[0].xyz);
		if (range_on > 0.5) {
			s *= range_scale(length(c));
		}
		VERTEX = c + vec3(VERTEX.xy * s, 0.0);
	} else {
		VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

float edge_px(float v, float px) {
	float d = v / max(fwidth(v), 1e-4);
	return 1.0 - smoothstep(px - 0.6, px + 0.4, d);
}

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy)) {
		discard;
	}
	float tt = t_steps > 0.0 ? floor(t * t_steps) / t_steps : t;
	float T12 = floor(TIME * 12.0) / 12.0;
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float n = texture(noise, UV * 0.8 + vec2(seed, seed * 1.3)).r;
	float v;
	vec3 col;
	if (mode == 0) {
		float k = pow(abs(cos(ang * rays * 0.5 + seed * 3.0)), 5.0) * (0.75 + 0.5 * n);
		float reach = (0.28 + 0.72 * k) * (0.6 + 0.4 * t);
		v = 1.0 - r / max(reach, 1e-3) - t * 0.55;
		col = mix(tint.rgb * 1.4, c_core * glow, aastep(0.42, v));
	} else if (mode == 1) {
		float e = 1.0 - pow(1.0 - tt, 2.2);
		float centre = mix(0.12, 0.92, e);
		float hw = mix(0.16, 0.015, tt) * (0.7 + 0.6 * n);
		v = hw - abs(r - centre);
		v /= max(hw, 1e-3);
		col = mix(tint.rgb, tint2.rgb, aastep(0.0, r - centre));
	} else if (mode == 2) {
		float n2 = texture(noise, vec2(UV.x * 5.0 + seed, 0.3)).r;
		float rise = sin(min(tt * 1.25, 1.0) * 3.14159);
		float top = (0.35 + 0.65 * n2) * rise;
		v = (top - UV.y) / max(top, 1e-3) - tt * 0.25;
		col = mix(tint.rgb, tint2.rgb, aastep(0.0, 0.32 - v));
	} else if (mode == 5) {
		v = 1.0 - r;
		float sh = dot(p, normalize(vec2(0.55, -0.85)));
		float spiral = fract(ang / 6.28318 * 2.0 + r * 1.7 - T12 * 0.9 + seed);
		float line = (1.0 - aastep(0.14, abs(spiral - 0.5) * 0.5 / max(r, 0.2) * 1.0)) * aastep(0.15, r) * (1.0 - aastep(0.85, r));
		col = c_core;
		col = mix(col, tint.rgb, aastep(0.28, sh));
		col = mix(col, tint.rgb * 0.9, line * 0.8);
		col = mix(col, c_ink, ink_px > 0.0 ? edge_px(v, ink_px) : 1.0 - aastep(0.07, v));     // (a thin inked rim)
	} else if (mode == 4) {
		float b = texture(noise, vec2(ang / 6.28318 * 2.0 + seed, TIME * 0.9)).r;
		float b2 = texture(noise, UV * 1.3 + vec2(seed, -TIME * 1.7)).r;
		v = 1.0 - r * (0.85 + 0.45 * b) + (b2 - 0.5) * 0.3;
		col = tint.rgb;
		col = mix(col, tint2.rgb, aastep(0.28, v));
		col = mix(col, c_core * glow, aastep(0.55, v));
	} else {
		float e = 1.0 - pow(1.0 - tt, 2.0);
		float centre = mix(0.25, 0.9, e);
		float hw = mix(0.13, 0.02, tt);
		float arc = fract(ang / 6.28318 * 2.0 + tt * 0.35 + seed);
		float tip = arc / 0.62;
		v = (hw * (1.0 - tip) - abs(r - centre)) / max(hw, 1e-3);
		v = arc > 0.62 ? -1.0 : v;
		col = mix(tint2.rgb, tint.rgb, aastep(0.45, v));
	}
	if (aastep(0.0, v) < 0.5) {
		discard;
	}
	float rim_k = ink_px > 0.0 ? edge_px(v, ink_px) : 1.0 - aastep(0.15, v);
	col = mix(col, c_ink, ink * rim_k);
	ALBEDO = (col) * fx_gain;
}
