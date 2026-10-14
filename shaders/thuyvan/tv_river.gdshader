// Thủy Vân river (style_guide.md 5.2 "Water" and 7 "The river"; PAINT's P11: assets/thuyvan/paint/water/
// tv_river_ramp.png, tv_river_flow.png, tv_river_foam.png, water.json). A Thủy Vân copy of the frontier's river
// (shaders/water/river.gdshader, which stays as it is), repainted: no photographic ripples or refraction, the water a
// painted jade glaze over the white stones.
//   mesh      the frontier's: RiverWater.ribbon (UV2 = the flow's direction in world xz, COLOR.r = rapids), or any
//             ribbon or sheet at the water's level; COLOR.g marks white water by hand (the falls' feet, steps)
//   depth     the ground behind the pixel from the depth buffer: the water's depth there picks the colour from the ramp
//             (x = 0-4 m: pale jade over the stones -> jade-teal -> deep blue-green; the ramp's top half running, its
//             bottom half the still state's clearer one) and the alpha (0.5 at the edge's first `edge_fade` m .. 0.92 at
//             3 m), so the white stones show through the shallows
//   flow      the painted flow streaks (tv_river_flow) carried downstream in two half-cycle phases cross-faded (flow
//             mapping, as the frontier's), plus a slow second layer; their alpha also tilts the normal a little for a
//             soft sun glint
//   foam      tv_river_foam where the water is under `foam_depth` m (the banks, rocks breaking the surface), at rapids
//             (COLOR.r) and where COLOR.g says (the falls' feet), drifting with the flow
//   light     lit: roughness 0.15, one soft sun glint, a fresnel sky tint (0.3); refraction off
//   still     `flow_scale` (1 running, 0 still: the S1 state sets it) scales the flow's speed, and as it falls the
//             streaks and foam fade out and the water turns glassy and clearer (the ramp's still half); `still_band` is
//             the frontier's (RiverWater from WorldRiver.still_band: z from, z to, ease m, amount), so a still reach
//             along z works as it does today. Nothing moves in still water; the white stones stay visible under it.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, shadows_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D ramp : source_color, filter_linear, repeat_disable;     // tv_river_ramp: x depth 0-4 m; top day, bottom still
uniform sampler2D flow_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_tex : source_color, filter_linear_mipmap, repeat_enable;

uniform float ramp_depth_m = 4.0;
uniform vec3 ramp_tint : source_color = vec3(1.0);   // per direction (water.json shallow_tint / deep_color stand in)
/// the painted ramp is already "lit": scaled down so the sun does not bleach it
uniform float albedo_scale : hint_range(0.0, 1.5) = 0.7;
uniform float water_specular : hint_range(0.0, 1.0) = 0.3;
uniform vec2 alpha_by_depth = vec2(0.5, 0.92);      // at 0 m .. at alpha_depth_m
uniform float alpha_depth_m = 3.0;
uniform float edge_fade = 0.15;                     // m of water over which the very edge fades in
uniform float flow_scale : hint_range(0.0, 1.0) = 1.0;
uniform float flow_speed = 0.6;                     // m/s
uniform float cycle_s = 3.0;
uniform float flow_tile_m = 10.0;
uniform float flow_strength : hint_range(0.0, 1.0) = 0.45;
uniform float foam_tile_m = 6.0;
uniform float foam_depth = 0.25;
uniform float foam_strength : hint_range(0.0, 1.0) = 0.85;
uniform float rapid_speed = 2.4;
uniform vec3 foam_color : source_color = vec3(0.93, 0.95, 0.94);
uniform float glint_normal : hint_range(0.0, 1.0) = 0.25;
uniform vec3 sky_tint : source_color = vec3(0.7, 0.85, 0.95);
uniform float fresnel_sky : hint_range(0.0, 1.0) = 0.3;
uniform float water_roughness : hint_range(0.0, 1.0) = 0.15;
uniform float still_roughness : hint_range(0.0, 1.0) = 0.05;
uniform vec4 still_band = vec4(0.0);                // z from, z to, ease (m), amount 0..1 (0: none)
uniform int debug_view = 0;                         // tools: 1 the depth under the surface (0-8 m) as grey

varying vec2 v_flow;
varying vec3 v_world;
varying vec2 v_mark;   // r: rapids, g: white water by hand

void vertex() {
	v_flow = UV2;
	v_mark = COLOR.rg;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float still_at(float z) {
	if (still_band.w <= 0.0) {
		return 0.0;
	}
	float e = max(still_band.z, 0.001);
	return still_band.w * smoothstep(still_band.x, still_band.x + e, z) * (1.0 - smoothstep(still_band.y - e, still_band.y, z));
}

// Flow-mapped painted streaks: (colour, alpha) in the flow's frame (`along` downstream, `across`).
vec4 streaks(vec2 along_across, float run_m, float t) {
	float p0 = fract(t / cycle_s);
	float p1 = fract(t / cycle_s + 0.5);
	float k = abs(p0 - 0.5) * 2.0;
	vec2 uv = along_across / flow_tile_m;
	// the texture's streaks run along its U: U downstream
	vec4 a = texture(flow_tex, uv - vec2(run_m * p0 / flow_tile_m, 0.0));
	vec4 b = texture(flow_tex, uv - vec2(run_m * p1 / flow_tile_m, 0.0) + vec2(0.37, 0.61));
	return mix(a, b, k);
}

void fragment() {
	float still = max(1.0 - flow_scale, still_at(v_world.z));
	float moving = 1.0 - still;
	vec2 dir = normalize(v_flow + vec2(0.0, 1e-4));
	vec2 along = vec2(dot(v_world.xz, dir), dot(v_world.xz, vec2(-dir.y, dir.x)));
	float speed = flow_speed * (1.0 + (rapid_speed - 1.0) * v_mark.r) * moving;

	// depth of water under this pixel (straight down)
	float here = -VERTEX.z;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).r, 1.0);
	float behind = -(v.z / v.w);
	vec3 ray = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 0.0)).xyz);
	float deep = max(behind - here, 0.0) * abs(ray.y);

	// colour by depth: the ramp's running row, or its still row
	float dx = clamp(deep / ramp_depth_m, 0.0, 1.0);
	vec3 run_c = texture(ramp, vec2(dx, 0.25)).rgb;
	vec3 still_c = texture(ramp, vec2(dx, 0.75)).rgb;
	vec3 col = mix(run_c, still_c, still) * ramp_tint * albedo_scale;
	float alpha = mix(alpha_by_depth.x, alpha_by_depth.y, clamp(deep / alpha_depth_m, 0.0, 1.0));
	alpha = mix(alpha, alpha * 0.8, still);   // still water: clearer, the stones under it plainer

	// the flow's painted streaks (frozen and faded in still water)
	float t = TIME;
	vec4 st = streaks(along, speed * cycle_s, t);
	vec4 st2 = texture(flow_tex, (along * vec2(0.45, 0.8) - vec2(speed * 0.35 * t, 0.0)) / (flow_tile_m * 2.3) + 0.21);
	float streak = clamp(st.a * 0.7 + st2.a * 0.4, 0.0, 1.0) * flow_strength * moving * smoothstep(0.05, 0.6, deep);
	col = mix(col, st.rgb, streak);

	// foam: banks and stones (shallow), rapids, the falls' feet; drifting with the flow
	float fn = texture(foam_tex, (along - vec2(speed * TIME, 0.0)) / foam_tile_m).a;
	float fn2 = texture(foam_tex, (along * 1.7 - vec2(speed * 1.3 * TIME, 0.0)) / (foam_tile_m * 0.6) + 0.5).a;
	float shallow = smoothstep(foam_depth, foam_depth * 0.2, deep);
	float white = max(v_mark.r * 0.8, v_mark.g);
	float foam = clamp(max(shallow * 0.75, white) * (fn * 1.6 + fn2 * 0.9) + white * 0.35, 0.0, 1.0);
	foam *= foam_strength * moving;
	col = mix(col, foam_color, foam);
	alpha = max(alpha, foam);

	// a soft glint: the streaks tilt the normal a little (none in still water: glassy)
	vec3 nw = normalize(vec3(dir.x * (st.a - 0.2), 1.0, dir.y * (st.a - 0.2)) * vec3(glint_normal * moving, 1.0, glint_normal * moving));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 4.0);
	col = mix(col, sky_tint, fresnel_sky * fres * (1.0 - foam));

	ALBEDO = col;
	ROUGHNESS = mix(mix(water_roughness, still_roughness, still), 0.7, foam);
	SPECULAR = water_specular;
	METALLIC = 0.0;
	ALPHA = alpha * smoothstep(0.0, edge_fade, deep);
	if (debug_view == 1) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(clamp(deep / 8.0, 0.0, 1.0));
		ALPHA = 1.0;
	}
}
