// The animals' hair (tools/wildlife/animal_hair.py: strand cards grown on each smoothed animal; user 2026-10-02, "lets add
// hairs likes our hair for the humans"): the human hair's strand atlas (assets/character/hair/tex/hair_atlas.png: RGB the
// strand's brightness, 0.5 the median strand; A the coverage; the root at v 0), coloured by the card's vertex colour (the
// skin's colour at its root, linear), a little darker at the root. Cut out (alpha scissor: no sorting among the cards),
// double-sided, lit with the skin's normal so the coat shades as the body does.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D strands : hint_default_white, filter_linear_mipmap_anisotropic;
uniform float brightness : hint_range(0.3, 2.0) = 1.0;
uniform float root_dark : hint_range(0.0, 1.0) = 0.72;
uniform float cut : hint_range(0.05, 0.95) = 0.42;

void fragment() {
	vec4 t = texture(strands, UV);
	float rel = t.r * 2.0;
	vec3 c = COLOR.rgb * mix(0.7, 1.0, clamp(rel, 0.0, 1.0)) * mix(1.0, 1.15, clamp(rel - 1.0, 0.0, 1.0));
	c *= mix(root_dark, 1.0, smoothstep(0.0, 0.6, UV.y));
	ALBEDO = c * brightness;
	// the strip's edges and its tip thinned (UV2.y 0 / 1 at the edges), so no card ends in a straight line
	float edge = smoothstep(0.0, 0.22, min(UV2.y, 1.0 - UV2.y));
	ALPHA = t.a * mix(0.6, 1.0, edge);
	ALPHA_SCISSOR_THRESHOLD = cut;
	ROUGHNESS = 0.78;
	SPECULAR = 0.3;
}
