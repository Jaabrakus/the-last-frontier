// Thủy Vân painted rock (style_guide.md 5.2 "Rock and karst"; tools/thuyvan_art/rock). The ROCK kit's karst towers,
// cliff walls, the Two Heights, the needle, boulders and white stones: a triplanar of one painted tiling texture
// (rock_tex, `tile_m` metres a tile), multiplied by the kit's vertex colour RGB (baked occlusion x top light, 0.5-1.0,
// linear), and a moss texture blended in by vertex colour A (the moss mask) on up-facing faces. Lit, never unshaded:
// Lambert wrap diffuse, low specular, rough. No normal map (the paint carries the light), no banded light.
//   world space (object_space false): karst, cliffs, the needle; pieces placed side by side share one continuous paint
//   object space (object_space true): ashlar courses and white stones keep their pattern when the piece is turned;
//     the piece's scale is applied, so the texel density holds on scaled instances
// Faces the kit keyed "moss" use this shader too, with the moss texture as rock_tex and moss_amount 0.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_m = 16.0;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float moss_tile_m = 4.0;
uniform float moss_amount : hint_range(0.0, 1.5) = 1.0;
uniform vec2 moss_slope = vec2(0.55, 0.8);        // world normal y: no moss below .x, full above .y
uniform bool object_space = false;
uniform float blend_sharp = 6.0;                  // triplanar blend exponent: crisp seams between planes
uniform vec3 tint : source_color = vec3(1.0);
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform float macro_var : hint_range(0.0, 0.3) = 0.08;   // low-frequency value breathing over 60-250 m (+-)
uniform float rough : hint_range(0.0, 1.0) = 0.92;
uniform float spec : hint_range(0.0, 1.0) = 0.15;

varying vec3 v_p;      // projection position (world, or object x scale)
varying vec3 v_pn;     // projection normal (same space as v_p)
varying vec3 v_wp;     // world position (macro variation)
varying vec3 v_wn;     // world normal (moss)
varying vec4 v_col;

void vertex() {
	v_col = COLOR;
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (object_space) {
		vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		v_p = VERTEX * sc;
		v_pn = NORMAL;
	} else {
		v_p = v_wp;
		v_pn = v_wn;
	}
}

// The painted textures' top (-V) is "up": on a wall V runs down the world's -Y.
vec3 tri(sampler2D t, vec3 p, vec3 n, float tile) {
	vec3 w = pow(abs(n), vec3(blend_sharp));
	w /= max(w.x + w.y + w.z, 1e-5);
	vec3 cx = texture(t, vec2(p.z * sign(n.x), -p.y) / tile).rgb;
	vec3 cy = texture(t, p.xz / tile).rgb;
	vec3 cz = texture(t, vec2(-p.x * sign(n.z), -p.y) / tile).rgb;
	return cx * w.x + cy * w.y + cz * w.z;
}

void fragment() {
	vec3 pn = normalize(v_pn);
	vec3 rock = tri(rock_tex, v_p, pn, tile_m) * tint;
	vec3 alb = rock;
	if (moss_amount > 0.0) {
		vec3 moss = tri(moss_tex, v_p, pn, moss_tile_m);
		float m = clamp(v_col.a * moss_amount, 0.0, 1.0) * smoothstep(moss_slope.x, moss_slope.y, normalize(v_wn).y);
		// the moss edge breaks along the rock's paint (clumps on the rock's darker strokes first), never a soft fade
		float lum = dot(rock, vec3(0.299, 0.587, 0.114));
		m = smoothstep(0.42, 0.58, m + (0.45 - lum) * 0.5);
		alb = mix(rock, moss, m);
	}
	float mv = 0.6 * sin(v_wp.x * 0.031 + 1.7) * sin(v_wp.z * 0.027 + 0.4) + 0.4 * sin((v_wp.x - v_wp.z) * 0.012 + 2.1);
	alb *= 1.0 + macro_var * mv;
	alb *= mix(vec3(1.0), v_col.rgb, ao_strength);
	ALBEDO = alb;
	ROUGHNESS = rough;
	SPECULAR = spec;
	METALLIC = 0.0;
}
