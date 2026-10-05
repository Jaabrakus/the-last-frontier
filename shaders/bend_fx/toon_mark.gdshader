shader_type spatial;
// A mark left on the ground (ToonFxPool.mark), on a flat quad laid just over it: `t` (instance) its age 0 -> 1 (it fades
// over the last part), `seed` its own shape.
//   mode 0  scorch: a black heart in banded browns, embers glowing in it at first
//   mode 1  cracks: dark forks run out from a crushed middle, a light lip along them
//   mode 2  frost: a pale crystalline sheet, its lines white
//   mode 3  wet: a dark splash, bluish
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"

uniform int mode = 0;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform float ink = 0.0;
instance uniform float t = 0.0;
instance uniform float seed = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	vec2 suv = UV * 0.9 + vec2(seed, seed * 0.77);
	float n = texture(noise, suv).r;
	float n2 = texture(noise, suv * 3.1).r;
	float life = 1.0 - smoothstep(0.55, 1.0, t);
	vec4 col = vec4(0.0);
	if (mode == 0) {
		float v = 1.0 - r * 1.25 + (n - 0.5) * 0.7;
		col = vec4(0.30, 0.15, 0.07, 0.55);
		col = mix(col, vec4(0.13, 0.06, 0.03, 0.85), aastep(0.22, v));
		col = mix(col, vec4(0.04, 0.025, 0.02, 0.95), aastep(0.48, v));
		float ember = aastep(0.74, n2) * aastep(0.3, v) * (1.0 - smoothstep(0.0, 0.35, t));
		col = mix(col, vec4(2.4, 0.8, 0.1, 1.0), ember);
		col.a *= aastep(0.0, v);
	} else if (mode == 1) {
		float k = 7.0;
		float a = ang / 6.28318 * k + n * 1.6 + seed * 5.0;
		float f = abs(fract(a) - 0.5) * 2.0;                        // 0 on a crack's line
		float reach = 0.45 + 0.55 * texture(noise, vec2(floor(a) * 0.37 + seed, 0.5)).r;
		float wd = 0.16 * (1.0 - r / reach) + 0.02;
		float line = (1.0 - aastep(wd, f)) * (1.0 - aastep(reach, r));
		float lip = (1.0 - aastep(wd * 2.2, f)) * (1.0 - aastep(reach * 0.96, r)) - line;
		float heart = 1.0 - aastep(0.22 + n2 * 0.1, r + (n - 0.5) * 0.15);
		col = vec4(0.62, 0.55, 0.45, 0.6) * clamp(lip, 0.0, 1.0);
		col = mix(col, vec4(0.07, 0.05, 0.04, 0.95), max(line, heart * 0.9));
		col = mix(col, vec4(0.3, 0.25, 0.2, 0.9), heart * aastep(0.55, n2));
	} else if (mode == 2) {
		float v = 1.0 - r * 1.15 + (n - 0.5) * 0.5;
		float lines = 1.0 - aastep(0.045, abs(n2 - 0.5));
		col = vec4(0.70, 0.88, 1.0, 0.55);
		col = mix(col, vec4(0.95, 1.0, 1.0, 0.95), lines);
		col.a *= aastep(0.0, v);
	} else {
		float v = 1.0 - r * 1.3 + (n - 0.5) * 0.8;
		col = vec4(0.05, 0.12, 0.2, 0.42);
		col = mix(col, vec4(0.03, 0.08, 0.15, 0.55), aastep(0.35, v));
		col.a *= aastep(0.0, v);
	}
	if (col.a * life <= 0.01) {
		discard;
	}
	ALBEDO = col.rgb;
	ALPHA = clamp(col.a, 0.0, 1.0) * life;
}
