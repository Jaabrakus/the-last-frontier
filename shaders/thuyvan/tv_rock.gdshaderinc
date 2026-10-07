// The body of the Thủy Vân painted-rock shaders (tv_rock.gdshader; tv_rock_far.gdshader defines TV_RANK_FOG). See
// tv_rock.gdshader for what it does.

uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_m = 16.0;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float moss_tile_m = 4.0;
uniform float moss_amount : hint_range(0.0, 1.5) = 1.0;
uniform vec2 moss_slope = vec2(0.55, 0.8);        // world normal y: no moss below .x, full above .y
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_strength : hint_range(0.0, 0.35) = 0.0;
uniform bool object_space = false;
uniform float blend_sharp = 6.0;                  // triplanar blend exponent: crisp seams between planes
uniform vec3 tint : source_color = vec3(1.0);
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform float macro_var : hint_range(0.0, 0.3) = 0.08;   // low-frequency value breathing over 60-250 m (+-)
uniform float rough : hint_range(0.0, 1.0) = 0.92;
uniform float spec : hint_range(0.0, 1.0) = 0.15;
#ifdef TV_RANK_FOG
uniform vec3 rank_fog_color : source_color = vec3(0.74, 0.82, 0.86);
instance uniform float rank_fog : hint_range(0.0, 1.0) = 0.15;
#endif

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

vec3 tri_w(vec3 n) {
	vec3 w = pow(abs(n), vec3(blend_sharp));
	return w / max(w.x + w.y + w.z, 1e-5);
}

vec3 tri(sampler2D t, vec3 p, vec3 n, vec3 w, float tile) {
	vec3 cx = texture(t, vec2(p.z * sign(n.x), -p.y) / tile).rgb;
	vec3 cy = texture(t, p.xz / tile).rgb;
	vec3 cz = texture(t, vec2(-p.x * sign(n.z), -p.y) / tile).rgb;
	return cx * w.x + cy * w.y + cz * w.z;
}

// The stroke normal on each plane, into the projection space (OpenGL: green toward the image's top = up on walls).
vec3 tri_normal(vec3 p, vec3 n, vec3 w, float tile) {
	vec2 tx = texture(normal_tex, vec2(p.z * sign(n.x), -p.y) / tile).rg * 2.0 - 1.0;
	vec2 ty = texture(normal_tex, p.xz / tile).rg * 2.0 - 1.0;
	vec2 tz = texture(normal_tex, vec2(-p.x * sign(n.z), -p.y) / tile).rg * 2.0 - 1.0;
	vec3 dx = vec3(0.0, tx.y, tx.x * sign(n.x));
	vec3 dy = vec3(ty.x, 0.0, -ty.y);
	vec3 dz = vec3(-tz.x * sign(n.z), tz.y, 0.0);
	return dx * w.x + dy * w.y + dz * w.z;
}

void fragment() {
	vec3 pn = normalize(v_pn);
	vec3 tw = tri_w(pn);
	vec3 rock = tri(rock_tex, v_p, pn, tw, tile_m) * tint;
	vec3 alb = rock;
	if (moss_amount > 0.0) {
		vec3 moss = tri(moss_tex, v_p, pn, tw, moss_tile_m);
		float m = clamp(v_col.a * moss_amount, 0.0, 1.0) * smoothstep(moss_slope.x, moss_slope.y, normalize(v_wn).y);
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
	if (normal_strength > 0.001) {
		vec3 d = tri_normal(v_p, pn, tw, tile_m) * normal_strength;
		vec3 wn = normalize(v_wn);
		if (object_space) {
			d = normalize((MODEL_MATRIX * vec4(d, 0.0)).xyz) * length(d);
		}
		NORMAL = normalize((VIEW_MATRIX * vec4(normalize(wn + d - wn * dot(d, wn)), 0.0)).xyz);
	}
#ifdef TV_RANK_FOG
	FOG = vec4(rank_fog_color, rank_fog);
#endif
}
