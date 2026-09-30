// Hair v3 (2026-09-28): the strand strips of every hair style (tools/character/hair/_recipe.py and
// _strands.py), textured with the project's own strand atlas (assets/character/hair/tex/hair_atlas.png,
// tools/character/hair_atlas.py: RGB the strands' relative brightness, 0.5 = the median strand; A the
// coverage), coloured with the hair colour model of hair_common.gdshaderinc (eumelanin, pheomelanin,
// grey, powder). Double-sided, alpha blended with an opaque depth pre-pass (the dense strands write
// depth and hide what is behind them; the thin strand ends, the strips' feathered edges and the
// hairline fade out softly over the skin), an anisotropic sheen along the strands (none on coily hair).
// Hidden regions (hats) collapse as in hair.gdshader.
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/common/canopy.gdshaderinc"

#include "res://assets/character/shaders/hair_common.gdshaderinc"

uniform sampler2D strands : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;   // the atlas's coily and braid slots tile along v
uniform float brightness : hint_range(0.3, 2.0) = 1.0;
uniform int debug_solid = 0;       // 1: every strip opaque (build checks)
// hair v3: the position across the strip (UV2.y, 0 and 1 at its edges): the edges feathered, so no
// strip ends in a straight line
uniform float edge_feather : hint_range(0.0, 0.5) = 0.0;
varying float v_across;

void vertex() {
	uint code = uint(UV2.x + 0.5);
	v_region = code & 63u;
	v_zone = code >> 6u;
	v_h = 0.0;
	v_across = UV2.y;
	if (hair_hidden(v_region)) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	vec4 t = texture(strands, UV);
	// the strand's brightness around the hair's own colour: 0.5 = the median strand
	float rel = t.r * 2.0;
	float id = h_hash12(floor(UV * vec2(900.0, 30.0)));
	vec3 c = melanin_albedo(eumelanin * (0.9 + 0.2 * id), pheomelanin * (0.9 + 0.2 * h_hash12(vec2(id, 3.0))));
	// the strands a little lighter and darker round the hair's colour (a strong contrast read as grain)
	c *= mix(0.68, 1.0, clamp(rel, 0.0, 1.0)) * mix(1.0, 1.18, clamp(rel - 1.0, 0.0, 1.0)) * brightness;
	// single strands: a fine variation across them, so no strip reads as one smooth sheet
	float strand = h_noise(vec2(UV.x * 2600.0, UV.y * 9.0));
	c *= 0.9 + 0.16 * strand;
	// grey: a share of the strands white (salt and pepper)
	float g = step(h_hash12(floor(UV * vec2(1400.0, 18.0)) + 11.0), grey);
	c = mix(c, vec3(0.58, 0.58, 0.56) * (0.8 + 0.4 * rel), g);
	// powder: an off-white (starch and flour), the strands still reading through it
	c = mix(c, vec3(0.72, 0.71, 0.68) * (0.9 + 0.2 * rel), powder);
	ALBEDO = c;
	// thinner strand ends: the coverage broken up along the strands
	ALPHA = smoothstep(0.02, 0.9, t.a) * mix(1.0, 0.55 + 0.45 * strand, 1.0 - t.a * t.a);
	if (edge_feather > 0.0) {
		float e = min(v_across, 1.0 - v_across) / edge_feather;
		ALPHA *= smoothstep(0.0, 1.0, e * (0.7 + 0.6 * h_noise(vec2(UV.x * 1300.0, UV.y * 40.0))));
	}
	// the sheen of hair: a band stretched across the strands, broken strand by strand (not the even
	// gloss of plastic, not the matte of paint)
	ROUGHNESS = 0.5 + 0.16 * strand;
	// coily hair (hair_texture 2) has no band of sheen: the coils scatter it, a soft matte gloss
	float coil = hair_texture == 2 ? 1.0 : 0.0;
	ROUGHNESS = mix(ROUGHNESS, 0.78, coil);
	// less at grazing angles (a mass of strands shadows its own sheen; the sky's reflection read as grey
	// patches along the silhouette)
	SPECULAR = mix(0.26, 0.18, coil) * smoothstep(0.06, 0.45, abs(dot(NORMAL, VIEW)));
	// the strands run along v: the tangent frame from the UV's screen derivatives (the imported tangents
	// were broken on some strips and their sheen flared into white sparkles)
	vec3 dpx = dFdx(VERTEX);
	vec3 dpy = dFdy(VERTEX);
	vec2 dux = dFdx(UV);
	vec2 duy = dFdy(UV);
	vec3 r1 = cross(dpy, NORMAL);
	vec3 r2 = cross(NORMAL, dpx);
	vec3 along = r1 * dux.y + r2 * duy.y;
	vec3 across = r1 * dux.x + r2 * duy.x;
	float la = length(along);
	float lc = length(across);
	float aniso = mix(0.7, 0.0, coil);
	if (la > 1e-14 && lc > 1e-14) {
		BINORMAL = along / la;
		TANGENT = across / lc;
	} else {
		aniso = 0.0;
	}
	ANISOTROPY = aniso;
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
	BACKLIGHT = c * 0.35;
	if (debug_view == 1) {
		ALBEDO = hair_region_color(v_region);
	}
	if (debug_solid == 1) {
		ALPHA = 1.0;
		ALBEDO = vec3(fract(UV.x * 8.0), fract(UV.y), 0.3);
	}
	// Under the forest canopy the same shade as the floor it stands on (canopy.gdshaderinc: the crowns take part of the sky
	// light and scatter some of the sun down; neutral without the forest light). Without it a body kept the open sky's
	// light under the trees and stood out lit in the shade (user 2026-09-30).
	float canopy_c = canopy_cover((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz);
	AO *= canopy_sky_factor(canopy_c, 1.0);
	EMISSION += ALBEDO * canopy_scatter(canopy_c, 1.0, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y) * AO;
}
