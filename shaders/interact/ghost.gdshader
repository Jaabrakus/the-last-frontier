shader_type spatial;
// Where a placed weapon will go (the interaction's placement preview): a translucent, softly lit copy.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 ghost_color : source_color = vec4(0.85, 0.95, 1.0, 0.28);

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	ALBEDO = ghost_color.rgb;
	ALPHA = ghost_color.a * (0.5 + 0.8 * rim);
}
