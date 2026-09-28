// Painted light (look test, 2026-09-26, branch part/style-trees): the light() of the painted materials
// (painted_tree.gdshader, painted_impostor.gdshader, painted_blob.gdshader). A banded light: a soft terminator that
// v_stroke moves per dab (so neighbouring leaf clumps fall on either side of it, as in a painting), a lighter top
// band, and a cool blue-green fill in the shade in proportion to the light's own colour, so shadows keep a hue
// instead of going black. The includer writes v_stroke (0..1) in fragment().

/// Warm tint of the lit side.
uniform vec3 lit_tint : source_color = vec3(1.0, 0.96, 0.84);
/// Cool fill of the shaded side, x the light's colour (a painter's blue-green shadow).
uniform vec3 shade_fill : source_color = vec3(0.22, 0.36, 0.46);
uniform float shade_fill_strength = 0.34;
/// Light wrap (0 Lambert .. 1 lit all round), terminator softness, how far v_stroke moves it.
uniform float wrap = 0.35;
uniform float band_soft = 0.08;
uniform float terminator_jitter = 0.28;

varying float v_stroke;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float w = (ndl + wrap) / (1.0 + wrap) + (v_stroke - 0.5) * terminator_jitter;
	float lit = smoothstep(0.5 - band_soft, 0.5 + band_soft, w);
	float high = smoothstep(0.8 - band_soft, 0.8 + band_soft, w) * 0.22;
	vec3 c = LIGHT_COLOR / PI;
	DIFFUSE_LIGHT += c * lit_tint * ((lit * 0.82 + high) * ATTENUATION);
	// the shaded side (and a cast shadow) of a sunlit tree takes a cool fill; a torch or a lamp only within its reach
	float reach = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	DIFFUSE_LIGHT += c * shade_fill * (shade_fill_strength * (1.0 - lit * ATTENUATION) * reach);
}
