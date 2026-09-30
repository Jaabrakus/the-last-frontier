// Hair style cards (loose strands, tufts): double-sided strips, strands drawn with alpha
// to coverage. UV.x = across the card (metres, 0 on its centre line), UV.y = along it
// from the root; h (root 0 .. tip 1) tapers the strands. See hair_common.gdshaderinc.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, alpha_to_coverage;
#include "res://shaders/common/canopy.gdshaderinc"

#include "res://assets/character/shaders/hair_common.gdshaderinc"

uniform float strand_density : hint_range(0.0, 1.0) = 0.55;

void vertex() {
	uint code = uint(UV2.x + 0.5);
	v_region = code & 63u;
	v_zone = code >> 6u;
	v_h = 1.0 - UV2.y;
	if (hair_hidden(v_region)) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	vec4 s = strand_albedo(UV);
	float lines = h_noise(vec2(UV.x * 1800.0, UV.y * 6.0));
	float taper = 1.0 - smoothstep(0.55, 1.0, v_h);
	float a = smoothstep(1.0 - strand_density * taper, 1.0 - strand_density * taper + 0.18, lines);
	if (stylized == 1) {
		// painted: a few broad tapered clumps per card instead of single strands
		float cl = h_noise(vec2(UV.x * 520.0, UV.y * 2.0));
		float wdt = 0.5 * taper + 0.1;
		a = smoothstep(1.0 - wdt, 1.0 - wdt + 0.12, cl);
		s.rgb = melanin_albedo(eumelanin, pheomelanin) * mix(0.6, 1.1, cl) * mix(1.0, 0.8, v_h);
		s.rgb = mix(s.rgb, vec3(0.86, 0.85, 0.83), powder);
	}
	ALBEDO = s.rgb;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.3;
	ROUGHNESS = 0.45;
	SPECULAR = 0.4;
	ANISOTROPY = 0.6;
	if (debug_view == 1) {
		ALBEDO = hair_region_color(v_region);
	}
	// Under the forest canopy the same shade as the floor it stands on (canopy.gdshaderinc: the crowns take part of the sky
	// light and scatter some of the sun down; neutral without the forest light). Without it a body kept the open sky's
	// light under the trees and stood out lit in the shade (user 2026-09-30).
	float canopy_c = canopy_cover((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz);
	AO *= canopy_sky_factor(canopy_c, 1.0);
	EMISSION += ALBEDO * canopy_scatter(canopy_c, 1.0, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y) * AO;
}
