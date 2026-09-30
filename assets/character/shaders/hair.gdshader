// Hair styles (assets/character/hair/*.glb), opaque surface: cap, queue, club, braid,
// ribbon / wrap / cord (zone 1), silver (zone 2). See hair_common.gdshaderinc.
// Hats hide hair zones through hide_mask (regions 48 crown, 49 sides, 50 back, 51 queue,
// 52 lock).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/common/canopy.gdshaderinc"

#include "res://assets/character/shaders/hair_common.gdshaderinc"

varying float v_up;

void vertex() {
	v_up = normalize(NORMAL).y;
	uint code = uint(UV2.x + 0.5);
	v_region = code & 63u;
	v_zone = code >> 6u;
	v_h = 1.0 - UV2.y;
	if (hair_hidden(v_region)) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	if (v_zone == 0u && stylized == 1) {
		float slope;
		// the caps (crown, sides, back) have the sphere_flow mapping; tails and locks their own
		float across = v_region >= 48u && v_region <= 50u ? cap_across_scale(UV) : -1.0;
		vec4 s = painted_hair(UV, v_up, VERTEX, across, slope);
		ALBEDO = s.rgb;
		ROUGHNESS = mix(0.5, 0.85, powder);
		SPECULAR = 0.22;
		ANISOTROPY = hair_texture == 2 ? 0.0 : 0.4 * (1.0 - powder);
		// the lock relief in the normal (across the strands)
		NORMAL_MAP = normalize(vec3(-slope * 0.55, 0.0, 1.0)) * 0.5 + 0.5;
		AO = mix(0.55, 1.0, s.w);
		AO_LIGHT_AFFECT = 0.25;
	} else if (v_zone == 0u) {
		vec4 s = strand_albedo(UV);
		ALBEDO = s.rgb;
		ROUGHNESS = mix(hair_texture == 2 ? 0.7 : 0.55, 0.85, powder);
		SPECULAR = 0.3;
		ANISOTROPY = hair_texture == 2 ? 0.0 : 0.55 * (1.0 - powder);
		float fine = 1.0 - smoothstep(0.4, 1.5, length(fwidth(UV * 1900.0)));
		float nx = h_noise(vec2(UV.x * 1900.0 + 0.5, UV.y * 14.0)) - h_noise(vec2(UV.x * 1900.0 - 0.5, UV.y * 14.0));
		NORMAL_MAP = normalize(vec3(-nx * 0.35 * fine, 0.0, 1.0)) * 0.5 + 0.5;
	} else if (v_zone == 1u) {
		float weave = h_noise(UV * vec2(900.0, 900.0));
		ALBEDO = accent_color * (0.9 + 0.2 * weave);
		METALLIC = accent_metal;
		// ribbon, tape and cord: a soft sheen (silk and worsted are not patent leather)
		ROUGHNESS = mix(0.74, 0.3, accent_metal);
		SPECULAR = mix(0.24, 0.4, accent_metal);
	} else {
		ALBEDO = metal_color;
		METALLIC = 1.0;
		ROUGHNESS = 0.28;
	}
	if (debug_view == 1) {
		ALBEDO = hair_region_color(v_region);
		METALLIC = 0.0;
	}
	// Under the forest canopy the same shade as the floor it stands on (canopy.gdshaderinc: the crowns take part of the sky
	// light and scatter some of the sun down; neutral without the forest light). Without it a body kept the open sky's
	// light under the trees and stood out lit in the shade (user 2026-09-30).
	float canopy_c = canopy_cover((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz);
	AO *= canopy_sky_factor(canopy_c, 1.0);
	EMISSION += ALBEDO * canopy_scatter(canopy_c, 1.0, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y) * AO;
}
