shader_type spatial;
// The interaction highlight (user 2026-09-25: "we need a item to highlight and we press e to know what we are
// interacting with"): a warm glow over the target's own material (material_overlay), gently pulsing, brightest
// at the silhouette. Its next_pass (highlight_outline.gdshader) draws the outline around it.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.72, 0.28, 1.0);
uniform float rim_power = 1.6;
uniform float strength = 1.4;
uniform float fill = 0.3;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float pulse = 0.8 + 0.2 * sin(TIME * 4.0);
	ALBEDO = glow_color.rgb * (rim * strength + fill) * pulse;
}
