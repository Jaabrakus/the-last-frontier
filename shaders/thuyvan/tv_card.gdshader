// Thủy Vân effect cards (style_guide.md 5.2 "Falls, foam, mist, lantern halos" and "Far skyline cards", 7; PAINT's
// P09/P10/P06: assets/thuyvan/paint/water/tv_fall_*, tv_mist_*, tv_pool_foam_ring, tv_smoke_wisps,
// sky/tv_skyline_karst_*): falls (body, streaks, edge foam), spray and mist puffs, mist bands, foam rings, smoke and far
// skyline cards. Unshaded and alpha-blended: the paint is the light, and its colour is multiplied by `light_tint`, the
// direction's sun x 0.6 + ambient x 0.4 (ThuyVanLook.light_tint(), kept current on every registered card material), so
// the cards track the mood.
//   scroll     `scroll` in UV per second (falls down V: body 0.8 m/s, streaks 1.4 m/s, divided by the card's metres per
//              UV; mist bands 0.5 m/s in U); `flow_scale` (0 still) stops it
//   fades      `proximity_fade` (m: soft where the card meets the ground or water), `near_fade` (m: gone right at the
//              camera, so the player never walks into a card edge), `end_fade` (0-0.5 of U at each end: no card's end seen)
//   uv         `uv_scale` repeats the texture across the card (UV itself runs 0-1, so end_fade sees the card's ends)
//   atlas      2 x 2 sheets (spray, puffs): `atlas_grid`, and the instance's `atlas_cell`
//   billboard  puffs and spray turn to face the camera (round the card's own Y when `billboard_y`)
//   fog_mix    far skyline cards lean toward `fog_color` by this much on top of the scene fog
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform sampler2D card_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 light_tint : source_color = vec3(1.0);
/// how much of light_tint applies (1 falls and foam; 0 mist bands, which carry the direction's mist colour as card_color)
uniform float light_tint_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec2 uv_scale = vec2(1.0);
uniform vec3 card_color : source_color = vec3(1.0);
uniform float strength = 1.0;
uniform float alpha_scale = 1.0;
uniform vec2 scroll = vec2(0.0);
uniform float flow_scale : hint_range(0.0, 1.0) = 1.0;
uniform float proximity_fade = 4.0;
uniform float near_fade = 6.0;
uniform float end_fade : hint_range(0.0, 0.5) = 0.0;
uniform vec2 atlas_grid = vec2(1.0);
uniform bool billboard = false;
uniform bool billboard_y = false;
uniform vec3 fog_color : source_color = vec3(0.8, 0.86, 0.88);
uniform float fog_mix : hint_range(0.0, 1.0) = 0.0;
instance uniform float atlas_cell = 0.0;
instance uniform float card_alpha = 1.0;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

void vertex() {
	if (billboard) {
		mat4 m = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		if (billboard_y) {
			m = mat4(normalize(vec4(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z, 0.0)), vec4(0.0, 1.0, 0.0, 0.0),
					normalize(vec4(INV_VIEW_MATRIX[2].x, 0.0, INV_VIEW_MATRIX[2].z, 0.0)), MODEL_MATRIX[3]);
		}
		m = m * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
				vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * m;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 cell = vec2(mod(atlas_cell, atlas_grid.x), floor(atlas_cell / atlas_grid.x));
	vec2 uv = UV * uv_scale + scroll * TIME * flow_scale;
	if (atlas_grid.x > 1.0 || atlas_grid.y > 1.0) {
		uv = (clamp(UV, 0.0, 1.0) + cell) / atlas_grid;
	}
	vec4 c = texture(card_tex, uv);
	vec3 col = c.rgb * card_color * mix(vec3(1.0), light_tint, light_tint_amount) * strength;
	col = mix(col, fog_color, fog_mix);
	float a = clamp(c.a * alpha_scale, 0.0, 1.0) * card_alpha;
	if (end_fade > 0.0) {
		a *= smoothstep(0.0, end_fade, UV.x) * smoothstep(1.0, 1.0 - end_fade, UV.x);
	}
	float here = -VERTEX.z;
	if (proximity_fade > 0.0) {
		vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).r, 1.0);
		float behind = -(v.z / v.w);
		a *= clamp((behind - here) / proximity_fade, 0.0, 1.0);
	}
	if (near_fade > 0.0) {
		a *= smoothstep(near_fade * 0.3, near_fade, here);
	}
	ALBEDO = col;
	ALPHA = a;
}
