// The river's water (RiverWater; user 2026-09-27: "i know theres some realistic peformance based water tech right?"):
// the cheap tricks real-time rivers are made of, no fluid simulation:
//   flow      ripples (two tiling noise normal maps) carried along the river's own course (UV2: downstream), in two
//             phases half a cycle apart and cross-faded, so the pattern slides without ever stretching or snapping back
//             (flow mapping: Vlachos, Valve, 2010)
//   depth     the water in front of the bed read from the depth buffer: colour and cloudiness by how much water the
//             eye looks through (Beer-Lambert), clear and pebbly at the edges, dark green in the channel
//   refract   the bed seen through it, bent by the ripples (the screen texture, offset only where it lands under water)
//   reflect   the engine's own: a smooth, non-metal surface catches the sky at grazing angles (Fresnel), the sky from
//             RiverWater's sky-only reflection probe (not the global illumination's blocky voxels)
//   foam      where it meets the banks, drifting with it; the very edge faded out (no hard line on the ground)
//   rapids    white water where RiverWater marks it (vertex colour red: WorldRiver.rapid_at): the flow faster; about
//             each boulder (wake_map, baked from the boulders:
//             tools/environment/water/bake_wake.py) the water piling white on its upstream face and ringing it, and a
//             fainter white V trailing it, torn by the churning water (user 2026-09-28: the rapids "hard to see and doesnt make it look good"; "the rocks
//             white looks good but remove the ripples or the waves", "remove those white lines", "keep the v trail
//             make it less powerfull": no standing waves, no streaks)
//   ice       in the cold (user 2026-09-28: snow "procedure beacuse we have the great planes as well as the water";
//             water_ice, SnowCover from the month's mean temperature: the depth of water the ice covers): shelf ice grows
//             out from the banks over the shallows first, dark and clear where it is new, grey-white where it has
//             thickened; in deep winter the slow water freezes across; the rapids stay open; snow lies on it in wind-swept
//             patches (snow.gdshaderinc)
shader_type spatial;
// (seen from under it too; no shadows on it: the far terrain casts them from its coarse 8 m mesh, blocky on the water)
render_mode blend_mix, depth_draw_always, cull_disabled, shadows_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D ripple_a : filter_linear_mipmap, repeat_enable;    // noise normal maps (0..1 encoded)
uniform sampler2D ripple_b : filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;

#include "res://shaders/common/snow.gdshaderinc"
global uniform float water_ice;
const vec3 ICE_NEW = vec3(0.05, 0.075, 0.085);
const vec3 ICE_OLD = vec3(0.5, 0.57, 0.62);

uniform vec3 shallow_tint : source_color = vec3(0.78, 0.86, 0.72);
uniform vec3 deep_color : source_color = vec3(0.035, 0.085, 0.075);
uniform float absorb = 1.1;               // per metre of water looked through
uniform float flow_speed = 0.6;           // m/s
uniform float cycle_s = 3.0;              // a flow phase
uniform float tile_a = 4.5;               // m a ripple tile
uniform float tile_b = 13.0;
uniform float ripple_strength = 0.36;
uniform float refraction = 0.04;
uniform float foam_depth = 0.1;           // m of water at the banks where foam shows
uniform float edge_fade = 0.1;            // m of water over which its very edge fades in (soft: the ground's 1 m facets)
uniform float water_roughness = 0.035;
uniform int debug_view = 0;               // 1: no bed seen through it, 2: only the bed through it (tools)

uniform float rapid_speed = 2.4;          // how much faster the flow at a rapid (x)
uniform float rapid_chop = 1.0;           // how much stronger its ripples (x)
uniform float rapid_roughness = 0.09;     // its surface, broken up (less of a mirror)
uniform sampler2D wake_map : filter_linear, repeat_disable;   // the boulders' white water (0..1)
uniform vec4 wake_box = vec4(0.0);        // its box: x0, z0, 1 / width, 1 / depth (z 0: none)

varying vec2 v_flow;
varying vec3 v_world;
varying float v_rapid;

void vertex() {
	v_flow = UV2;
	v_rapid = COLOR.r;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 ripples(vec2 xz, vec2 dir, float t, float speed) {
	float p0 = fract(t / cycle_s);
	float p1 = fract(t / cycle_s + 0.5);
	float w = abs(p0 - 0.5) * 2.0;
	vec2 run = dir * speed * cycle_s;
	vec2 a0 = texture(ripple_a, (xz - run * p0) / tile_a).rg;
	vec2 a1 = texture(ripple_a, (xz - run * p1) / tile_a + vec2(0.37, 0.61)).rg;
	vec2 b = texture(ripple_b, (xz - dir * speed * 0.45 * t) / tile_b).rg;
	return (mix(a0, a1, w) * 0.65 + b * 0.35) * 2.0 - 1.0;
}

void fragment() {
	vec2 dir = normalize(v_flow + vec2(0.0, 1e-4));
	float speed = flow_speed * (1.0 + (rapid_speed - 1.0) * v_rapid);
	vec2 r = ripples(v_world.xz, dir, TIME, speed) * ripple_strength * (1.0 + (rapid_chop - 1.0) * v_rapid);
	vec2 along = vec2(dot(v_world.xz, dir), dot(v_world.xz, vec2(-dir.y, dir.x)));
	vec3 nw = normalize(vec3(r.x, 1.0, r.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	// the ground behind this pixel, and how much water the eye looks through to it
	float here = -VERTEX.z;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).r, 1.0);
	float behind = -(v.z / v.w);
	float thick = max(behind - here, 0.0);
	vec3 ray = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 0.0)).xyz);
	float deep = thick * abs(ray.y);                      // straight down: the water's depth there

	// the bed through it, bent by the ripples (only where the bent look still lands under the water)
	vec2 ruv = SCREEN_UV + r * refraction * clamp(deep * 2.0, 0.0, 1.0);
	vec4 v2 = INV_PROJECTION_MATRIX * vec4(ruv * 2.0 - 1.0, texture(depth_tex, ruv).r, 1.0);
	if (-(v2.z / v2.w) < here) {
		ruv = SCREEN_UV;
	}
	vec3 bed = textureLod(screen_tex, ruv, 0.0).rgb;

	float seen = exp(-thick * absorb);                    // light from the bed that gets through
	vec3 through = bed * mix(vec3(1.0), shallow_tint, clamp(thick * 0.8, 0.0, 1.0)) * seen;

	// foam at the banks, drifting with the flow
	float fn = texture(foam_noise, (v_world.xz - dir * speed * TIME) / 3.0).r;
	float fdep = foam_depth * (1.0 + 0.6 * v_rapid);
	// (soft all through: a gradient, no hard edge to follow the ground's facets)
	float foam = smoothstep(fdep, 0.0, deep) * smoothstep(0.2, 0.8, fn) * 0.45;
	// white water. Its texture: churning, swept down (broad and soft: user 2026-09-28 "more smooth instead of blockly")
	float churn = smoothstep(0.2, 0.8, texture(foam_noise, vec2(along.x - speed * 0.8 * TIME, along.y * 1.4) / 2.4).r);
	// about the boulders: the upstream pillow, the ring, the fainter V behind
	float wake = wake_box.z > 0.0 ? texture(wake_map, (v_world.xz - wake_box.xy) * wake_box.zw).r : 0.0;
	float rocks = wake * mix(0.55, 1.0, churn);
	foam = max(foam, rocks);

	ALBEDO = mix(deep_color * (1.0 - seen), vec3(0.72, 0.74, 0.7), foam);
	EMISSION = through * (1.0 - foam);
	ROUGHNESS = mix(mix(water_roughness, rapid_roughness, v_rapid), 0.6, foam);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ALPHA = smoothstep(0.0, edge_fade, deep);
	// ice: over the water shallower than the reach (the rapids none), its edge ragged
	float reach = water_ice * (1.0 - smoothstep(0.1, 0.5, v_rapid));
	if (reach > 0.005) {
		float rag = (texture(foam_noise, v_world.xz / 11.0).r - 0.5) * 0.35 + (texture(foam_noise, v_world.xz / 2.3).r - 0.5) * 0.08;
		float margin = reach - deep + rag * min(reach, 0.6);
		float ice = smoothstep(-0.01, 0.03, margin);
		if (ice > 0.001) {
			// new ice at its edge dark and clear (the water under it), thickening grey-white back toward the bank
			float thick = smoothstep(0.02, 0.35, margin);
			vec3 icec = mix(ICE_NEW, ICE_OLD, thick) * (0.92 + 0.16 * texture(foam_noise, v_world.xz / 1.3).r);
			// snow on the ice: wind-swept, in patches and drifts
			float sn = snow_cover > 0.001 ? smoothstep(0.35, 0.75, snow_vnoise(v_world.xz * 0.12) * 0.7
					+ snow_vnoise(v_world.xz * 0.9) * 0.3 + snow_cover * thick - 0.35) : 0.0;
			icec = mix(icec, snow_albedo(v_world), sn);
			ALBEDO = mix(ALBEDO, icec, ice);
			EMISSION = mix(EMISSION, through * 0.35 * (1.0 - thick), ice);
			ROUGHNESS = mix(ROUGHNESS, mix(0.12, 0.75, max(thick * 0.6, sn)), ice);
			NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, ice));
			ALPHA = max(ALPHA, ice * smoothstep(0.0, 0.03, deep + 0.03));
		}
	}
	if (debug_view == 1) {
		EMISSION = vec3(0.0);
	} else if (debug_view == 2) {
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		ROUGHNESS = 1.0;
	}
}
