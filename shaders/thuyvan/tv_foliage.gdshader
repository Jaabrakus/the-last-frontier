// Thủy Vân foliage (style_guide.md 5.2 "Foliage", section 6): PAINT's trees, pines, bamboo, banana, ferns and shrubs
// (assets/thuyvan/vegetation/*.glb, tools/thuyvan_art/blender/build_foliage.py). One surface per plant, in the frontier
// tree format: COLOR r = baked AO, g = outer crown, b = random, a = 1 foliage / 0 bark; UV = the leaf card's atlas rect
// or the bark's tiling UVs; UV2 = wind (x metres from the trunk, y phase). The atlas already holds the crown's light
// (lighter on top, darker beneath); the mesh normals are bent to each puff's sphere, so a crown shades as a few soft
// balls. Lit with Lambert wrap and a warm back-light; never the banded painted_light.gdshaderinc (rejected toon band).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://shaders/common/wind.gdshaderinc"

uniform sampler2D leaf_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D bark_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.85;
/// warm yellow-green light through the leaves (style guide: back-light transmission 0.25)
uniform vec3 backlight_tint : source_color = vec3(0.83, 0.88, 0.45);
uniform float backlight_strength : hint_range(0.0, 1.0) = 0.25;
uniform float leaf_rough : hint_range(0.0, 1.0) = 0.9;
uniform float bark_rough : hint_range(0.0, 1.0) = 0.95;
uniform float spec : hint_range(0.0, 1.0) = 0.15;
/// sway (m per metre from the trunk at full wind); flutter of the outer leaves (m)
uniform float sway = 0.012;
uniform float flutter = 0.04;

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	float ph = UV2.y * 6.2831853 + frontier_hash(base.xz) * 6.2831853;
	float ws = clamp(wind_strength, 0.0, 1.0);
	float g = frontier_gust(base.xz);
	vec2 d = normalize(wind_direction + vec2(1e-5));
	float reach = max(UV2.x, 0.0);
	float lean = reach * sway * (0.35 + ws) * (0.6 + 0.4 * g) * (0.7 + 0.3 * sin(TIME * 0.9 + ph));
	vec3 off = vec3(d.x, 0.0, d.y) * lean;
	if (COLOR.a > 0.5) {
		off += vec3(sin(TIME * 3.1 + ph * 3.0), 0.5 * sin(TIME * 2.3 + ph * 5.0), cos(TIME * 2.7 + ph * 2.0))
				* flutter * COLOR.g * (0.3 + ws);
	}
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
}

void fragment() {
	bool leaf = COLOR.a > 0.5;
	vec4 c = leaf ? texture(leaf_atlas, UV) : texture(bark_tex, UV);
	if (leaf && c.a < alpha_cut) {
		discard;
	}
	vec3 alb = c.rgb * mix(1.0, COLOR.r, ao_strength);
	ALBEDO = alb;
	ROUGHNESS = leaf ? leaf_rough : bark_rough;
	SPECULAR = spec;
	if (leaf) {
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_cut;
		ALPHA_ANTIALIASING_EDGE = 0.3;
		ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(leaf_atlas, 0));
		// keep the crown normal on the cards' back faces: the crown shades as one volume
		if (!FRONT_FACING) {
			NORMAL = -NORMAL;
		}
		BACKLIGHT = alb * backlight_tint * backlight_strength;
	}
}
