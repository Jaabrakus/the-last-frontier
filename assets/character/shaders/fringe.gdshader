// Fringe cards of the customizer garments (surface "<id>_fringe"; built by
// tools/character/garments/frontier: hunting-shirt cape and hem, buckskin legging seams).
// Each card is a strip of cut leather or ravelled cloth: UV.x across the strip (metres,
// every card offset at random), UV.y along the strands from the root; h = root 0 .. tip 1
// (UV2.y = 1 - h). Strands are cut procedurally (strand_period wide, ragged ends), drawn
// double-sided with alpha to coverage. UV2.x = region + 64 * zone: regions in hide_mask
// collapse. The colour is the garment's fringe zone colour (catalog zone role "fringe");
// the fabric kit's luminance (detail, tile metres) is optional.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, alpha_to_coverage;
#include "res://shaders/common/canopy.gdshaderinc"

uniform uvec2 hide_mask = uvec2(0u, 0u);
uniform vec3 fringe_color : source_color = vec3(0.63, 0.49, 0.33);
uniform sampler2D detail : source_color, filter_linear_mipmap, repeat_enable;
uniform float use_detail : hint_range(0.0, 1.0) = 0.0;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.6;
uniform float tile = 0.285;
uniform float strand_period = 0.0045;     // m, one strand plus its gap
uniform float strand_fill : hint_range(0.2, 0.95) = 0.62;
uniform float ragged : hint_range(0.0, 0.6) = 0.22;
uniform float roughness : hint_range(0.0, 1.0) = 0.78;

varying flat uint v_region;
varying float v_h;

float fr_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	v_region = uint(UV2.x + 0.5) & 63u;
	v_h = 1.0 - UV2.y;
	uint bits = v_region < 32u ? (hide_mask.x >> v_region) : (hide_mask.y >> (v_region - 32u));
	if ((bits & 1u) != 0u) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	float k = UV.x / strand_period;
	float id = floor(k);
	float fx = fract(k);
	float len = 1.0 - ragged * fr_hash(vec2(id, 1.7));
	float taper = 1.0 - 0.35 * smoothstep(0.55, 1.0, v_h / len);
	float half_w = 0.5 * strand_fill * taper;
	float a = v_h <= len ? 1.0 - smoothstep(half_w - 0.07, half_w, abs(fx - 0.5)) : 0.0;
	float shade = 0.82 + 0.3 * fr_hash(vec2(id, 9.1));
	vec3 col = fringe_color * shade;
	if (use_detail > 0.5) {
		vec3 d = texture(detail, UV / tile).rgb;
		vec3 m = textureLod(detail, vec2(0.5), 12.0).rgb;
		float r = dot(d, vec3(0.2126, 0.7152, 0.0722)) / max(dot(m, vec3(0.2126, 0.7152, 0.0722)), 1e-3);
		col *= 1.0 + detail_strength * (r - 1.0);
	}
	col *= mix(0.72, 1.0, smoothstep(0.0, 0.35, v_h));
	ALBEDO = col;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.3;
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
	// Under the forest canopy the same shade as the floor it stands on (canopy.gdshaderinc: the crowns take part of the sky
	// light and scatter some of the sun down; neutral without the forest light). Without it a body kept the open sky's
	// light under the trees and stood out lit in the shade (user 2026-09-30).
	float canopy_c = canopy_cover((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz);
	AO *= canopy_sky_factor(canopy_c, 1.0);
	EMISSION += ALBEDO * canopy_scatter(canopy_c, 1.0, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y) * AO;
}
