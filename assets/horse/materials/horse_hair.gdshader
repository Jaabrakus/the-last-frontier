// Mane, forelock, tail and feathering cards (tools/horse/hair.py). The strand texture:
// R strand brightness, G depth in the lock, B per-strand random, A coverage. UV.y is 0 at
// the root and 1 at the tip. Two-sided, alpha scissor, highlight stretched across the
// strands (anisotropy along them), some translucency against the low sun.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D strands : hint_default_white, filter_linear_mipmap_anisotropic;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.42;
uniform float anisotropy_amount : hint_range(0.0, 1.0) = 0.6;

instance uniform vec4 hair_color : source_color = vec4(0.070, 0.050, 0.045, 1.0);
instance uniform vec4 hair_tip : source_color = vec4(0.160, 0.100, 0.070, 1.0);
instance uniform float hair_var = 0.35;

void fragment() {
	vec4 s = texture(strands, UV);
	vec3 c = mix(hair_color.rgb, hair_tip.rgb, smoothstep(0.25, 1.0, UV.y));
	c *= mix(0.6, 1.2, s.r) * mix(0.72, 1.0, s.g);
	c *= 1.0 + hair_var * (s.b - 0.5);
	ALBEDO = c;
	ALPHA = s.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.55;
	SPECULAR = 0.3;
	ANISOTROPY = anisotropy_amount;
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
	AO = mix(0.55, 1.0, s.g);
	BACKLIGHT = c * 0.3;
}
