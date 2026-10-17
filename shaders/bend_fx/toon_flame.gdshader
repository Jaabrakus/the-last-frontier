shader_type spatial;
// A cel flame (ToonFx): banded white-yellow core, yellow, orange and a red rim, its tongues licking, swaying and splitting
// (flame_field: two octaves of noise through a domain warp, each tongue its own phase), the tips breaking into embers.
// Round 4 (LOOKS; the owner: flames "not blocky sprites"): the stylized bands kept, every edge soft and anti-aliased (alpha
// over at least `soft` of the field, never a hard cut, never a discard of the body), faded where it meets the deck
// (deck_fade_m over the scene's depth) and thinned near the camera (fx_common near_cut).
//   mode 0  a quad turned round its own axis to face the camera (local Y the flame's length from its base, local X its
//           width): a fire wall's flames, a fireball's tongues, the Kick's rows (one MultiMesh each; an instance's colour
//           red is its heat: 1 a crest, lower a cooler trail)
//   mode 1  a strip along a line (ToonRibbon: UV.x 0 at the head .. 1 at the tail, UV.y across, UV2.x the half width)
//   mode 2  a lip: a strip along a line (ToonRibbon laid across: UV.x m along it) burning on both sides of its middle
//   mode 3  an orb: a ball of fire facing the camera, banded from a white heart, its edge boiling and soft (a fireball's
//           core; `range_on`, instance, grows it at range: fx_common range_scale)
// Blended, so its near-camera fade is its alpha (near_fade, own_fade), not a screen-door: nothing more to sort.
// `grow` (instance) raises it from nothing; `ink` draws a dark outline round it.
// THE CEL LOOK (2026-10-16, the owner: the elements "as close to anime style Avatar: The Last Airbender as possible": flat
// cel colours, bold hand-drawn shapes, 2D-animation timing, not particle soup): `cel` on, the field's time runs on twos
// (cel_fps steps a second, so the flame boils like drawings, not like smoke), its tongues are thick and pointed and split
// into `lobes` tips with V notches cut toward the tip (no wisps), the bands are flat and hard (soft at a pixel, never a
// gradient: a pale core over most of the body, a yellow band, an orange-red rim) and a dark outline `ink_w` thick is drawn
// round the whole shape (the inner bands keep no line, as the show draws them). The orb boils in the same steps.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"
#include "res://shaders/bend_fx/flame_field.gdshaderinc"

uniform int mode = 0;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 c_core : source_color = vec3(1.0, 0.97, 0.78);
uniform vec3 c_hot : source_color = vec3(1.0, 0.80, 0.16);
uniform vec3 c_mid : source_color = vec3(1.0, 0.40, 0.03);
uniform vec3 c_edge : source_color = vec3(0.80, 0.10, 0.03);
uniform vec3 c_ink : source_color = vec3(0.16, 0.02, 0.02);
uniform float ink = 0.0;
uniform float glow = 2.2;
uniform float speed = 2.4;
uniform float turb = 0.95;
uniform vec2 nscale = vec2(1.1, 1.3);
uniform float taper = 0.18;
uniform float soft = 0.07;
uniform float warp = 0.45;
uniform float embers = 1.0;
uniform float deck_fade_m = 0.3;
// The cel look (see the header): on, the drawings' rate, the outline's width (in the field), the tips a tongue splits into,
// how deep the notches between them cut, and how much of the noise is kept (less: bolder lobes).
uniform float cel = 1.0;
uniform float cel_fps = 12.0;
uniform float ink_w = 0.08;
uniform float lobes = 2.5;
uniform float notch = 0.32;
uniform float cel_noise = 0.7;
// 1: an instance's colour red is its heat (the Kick's rows, a MultiMesh with colours); 0: every tongue whole heat.
uniform float heat_on = 0.0;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float seed = 0.0;  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform float seed = 0.0;
#endif
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float grow = 1.0;  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform float grow = 1.0;
#endif
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float range_on = 0.0;  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform float range_on = 0.0;
#endif

varying float v_seed;
varying float v_heat;

void vertex() {
	v_seed = seed + float(INSTANCE_ID) * 0.618034;
	v_heat = heat_on > 0.5 ? COLOR.r : 1.0;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 w;
	if (mode == 3) {
		vec3 oc = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
		float s = length(MODEL_MATRIX[0].xyz);
		if (range_on > 0.5) {
			s *= range_scale(length(oc));
		}
		VERTEX = oc + vec3(VERTEX.xy * s, 0.0);
		POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
		NORMAL = vec3(0.0, 0.0, 1.0);
	} else {
	if (mode == 0) {
		vec3 c = MODEL_MATRIX[3].xyz;
		float wd = length(MODEL_MATRIX[0].xyz);
		w = axis_billboard(vec3(VERTEX.x, VERTEX.y * grow, 0.0), c, MODEL_MATRIX[1].xyz, wd, MODEL_MATRIX[0].xyz / max(wd, 1e-4), cam);
	} else {
		w = strip_point((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz, (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz, UV2.x, UV.y, cam);
	}
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	}
}

void fragment() {
	float tm = cel > 0.5 ? floor(TIME * cel_fps) / cel_fps : TIME;
	float t = tm * speed;
	float fade = near_fade(length(VERTEX)) * own_fade;
	float sft = cel > 0.5 ? min(soft, 0.022) : soft;
	if (mode == 3) {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		float ang = atan(p.y, p.x);
		float b = texture(noise, vec2(ang / 6.28318 * 2.0 + v_seed, tm * 0.9)).r;
		float b2 = texture(noise, UV * 1.3 + vec2(v_seed, -tm * 1.7)).r;
		float b3 = texture(noise, UV * 2.9 + vec2(-tm * 2.3, v_seed)).r;
		float ov;
		if (cel > 0.5) {
			// (a bold boil: a few fat lobes round the rim, stepped with the drawings, no fine grain)
			float lobe = 0.5 + 0.5 * cos(ang * 5.0 + b * 4.0 + v_seed * 7.0);
			ov = 1.0 - r * (0.82 + 0.3 * b) + (lobe - 0.5) * 0.16 + (b2 - 0.5) * 0.14;
		} else {
			ov = 1.0 - r * (0.85 + 0.45 * b) + (b2 - 0.5) * 0.3 + (b3 - 0.5) * 0.12;
		}
		float obw = clamp(fwidth(ov), cel > 0.5 ? 0.012 : 0.025, 0.1);
		vec3 ocol = c_edge;
		ocol = mix(ocol, c_mid, smoothstep(0.1 - obw, 0.1 + obw, ov));
		ocol = mix(ocol, c_hot, smoothstep(0.24 - obw, 0.24 + obw, ov));
		ocol = mix(ocol, c_core * glow, smoothstep(0.5 - obw, 0.5 + obw, ov));
		ocol = mix(ocol, c_ink, ink * (1.0 - smoothstep(ink_w - obw, ink_w + obw, ov)));
		ALBEDO = ocol * fx_gain;
		ALPHA = clamp(softstep(0.0, ov, sft) * fade, 0.0, 1.0);
	} else {
	float along;
	float across;
	float sd = v_seed;
	if (mode == 0) {
		along = 1.0 - UV.y;
		across = UV.x;
	} else if (mode == 1) {
		along = UV.x;
		across = UV.y;
	} else {
		along = 0.15 + abs(UV.y * 2.0 - 1.0) * 0.85;      // (a lip: hot along its middle, torn to both sides)
		across = 0.5;
		sd += UV.x * 0.9;
	}
	float n2 = 0.5;
	float v;
	if (cel > 0.5 && mode != 2) {
		v = cel_v(noise, across, along, t, sd, lobes, notch);
	} else {
		v = flame_v(noise, across, along, t, sd, nscale, turb, mode == 2 ? 1.0 : taper, warp, n2);
		if (mode == 2) {
			v = (1.0 - along) * 1.05 + (n2 - 0.5) * turb * 0.7 - 0.05;
		}
	}
	v -= (1.0 - clamp(v_heat, 0.0, 1.0)) * 0.22;        // a cooler row: its bands slide toward the rim
	float o = 0.03;
	float a = softstep(o, v, sft);
	float em = (cel > 0.5 ? 0.0 : embers) * ember_mask(noise, across, along, t, sd, v - o);
	float bw = clamp(fwidth(v), cel > 0.5 ? 0.012 : 0.025, 0.1);
	vec3 col = c_edge;
	if (cel > 0.5) {
		// (flat bands: the outline, an orange-red rim, a yellow band, the pale core over most of the body; the outline never
		// thinner than about two pixels, so it still reads from across the deck)
		float iw = max(ink_w, bw * 2.2);
		col = c_mid;
		col = mix(col, c_hot, smoothstep(o + iw + 0.2 - bw, o + iw + 0.2 + bw, v));
		col = mix(col, c_core * glow, smoothstep(o + iw + 0.66 - bw, o + iw + 0.66 + bw, v));
		col = mix(col, c_ink, ink * (1.0 - smoothstep(o + iw - bw, o + iw + bw, v)));
	} else {
		col = mix(col, c_mid, smoothstep(o + 0.14 - bw, o + 0.14 + bw, v));
		col = mix(col, c_hot, smoothstep(o + 0.33 - bw, o + 0.33 + bw, v));
		col = mix(col, c_core * glow, smoothstep(o + 0.56 - bw, o + 0.56 + bw, v));
		col = mix(col, c_ink, ink * (1.0 - smoothstep(o + 0.06 - bw, o + 0.06 + bw, v)));
	}
	col = mix(col, c_hot * glow * 0.8, em * (1.0 - a));
	float alpha = max(a, em);
	alpha *= fade;
	if (mode == 0 && deck_fade_m > 0.0) {
		alpha *= deck_soft(texture(depth_tex, SCREEN_UV).r, SCREEN_UV, INV_PROJECTION_MATRIX, VERTEX, deck_fade_m);
	}
	ALBEDO = col * fx_gain;
	ALPHA = clamp(alpha, 0.0, 1.0);
	}
}
