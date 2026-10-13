shader_type spatial;
// Breath's smoke as a lit volume (round 4 LOOKS; ToonFx "puff_smoke", the smoke kind only): each puff a ball under the
// effects' cel sun in four lit bands blended softly into each other, its edge eroded softly as it thins (never a hard
// dissolve cut), turning slowly and rising and growing over its life, its own grey-brown tint, a warm under-glow from the
// flame while `warm` (instance, the zone's first warm_s) lasts, soft where it meets the deck and near the camera. Blended
// (the emitter sorts its puffs by depth). The ramp's alpha is how full a puff is.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"

uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 c_a : source_color = vec3(0.66, 0.64, 0.6);       // the lit side
uniform vec3 c_b : source_color = vec3(0.5, 0.48, 0.45);
uniform vec3 c_c : source_color = vec3(0.36, 0.34, 0.32);
uniform vec3 c_d : source_color = vec3(0.22, 0.21, 0.2);       // the deep shade
uniform vec3 c_tint : source_color = vec3(0.62, 0.5, 0.38);    // the brown a puff leans to
uniform vec3 c_warm : source_color = vec3(1.0, 0.45, 0.12);
uniform float tint_k = 0.55;
uniform float wobble = 0.45;
uniform float nfreq = 0.55;
uniform float curl = 1.6;
uniform vec2 grow_k = vec2(0.85, 1.35);
uniform float deck_fade_m = 0.6;
uniform float opacity = 0.92;
uniform float ink = 0.0;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float warm = 0.0;  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform float warm = 0.0;
#endif

varying float v_seed;
varying float v_age;
varying vec2 v_q;

void vertex() {
	v_seed = float(INSTANCE_ID) * 0.754877 + INSTANCE_CUSTOM.x * 0.1;
	v_age = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	vec3 c = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float s = length(MODEL_MATRIX[0].xyz) * mix(grow_k.x, grow_k.y, v_age);
	float turn = (fract(v_seed * 7.13) < 0.5 ? -1.0 : 1.0) * curl * v_age;
	float an = INSTANCE_CUSTOM.x + turn;
	vec2 q = VERTEX.xy * s;
	q = vec2(q.x * cos(an) - q.y * sin(an), q.x * sin(an) + q.y * cos(an));
	v_q = q / max(s, 1e-4);
	VERTEX = c + vec3(q, 0.0);
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float n = texture(noise, UV * nfreq + vec2(v_seed, v_seed * 1.73)).r;
	float n2 = texture(noise, UV * nfreq * 2.7 + vec2(v_seed * 2.1, 0.3)).r;
	float fill = clamp(COLOR.a, 0.0, 1.0);
	float cut = 1.0 - fill;
	float v = (1.0 - r) + (n - 0.5) * wobble - cut * (0.75 + (n2 - 0.5) * 1.2);
	float alpha = smoothstep(-0.05, 0.1, v);                      // a soft erosion
	// lit: a ball in view space (v_q: the quad's own offset, upright), its light the effects' cel sun
	float qr = length(v_q);
	vec3 nv = normalize(vec3(v_q.x, v_q.y, sqrt(max(1.0 - qr * qr, 0.0)) + 0.2));
	float d = dot(nv, cel_light(VIEW_MATRIX)) + (n - 0.5) * 0.45 + (n2 - 0.5) * 0.2;
	float bw = 0.09;
	vec3 col = c_d;
	col = mix(col, c_c, smoothstep(-0.5 - bw, -0.5 + bw, d));
	col = mix(col, c_b, smoothstep(-0.08 - bw, -0.08 + bw, d));
	col = mix(col, c_a, smoothstep(0.36 - bw, 0.36 + bw, d));
	float h = fract(sin(v_seed * 91.7 + 3.1) * 437.58);
	col *= mix(vec3(1.0), c_tint / max(max(c_tint.r, c_tint.g), c_tint.b), h * tint_k);
	col *= COLOR.rgb;
	float under = smoothstep(0.3, -0.8, v_q.y);
	col += c_warm * warm * under * (0.6 + 0.4 * n);
	alpha *= near_fade(length(VERTEX)) * own_fade;
	alpha *= deck_soft(texture(depth_tex, SCREEN_UV).r, SCREEN_UV, INV_PROJECTION_MATRIX, VERTEX, deck_fade_m);
	ALBEDO = col * fx_gain;
	ALPHA = clamp(alpha * opacity, 0.0, 1.0);
}
