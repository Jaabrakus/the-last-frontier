shader_type spatial;
// A struck fighter's flash (round 4 IMPACT, BendLooks.hit_flash; testers 2026-10-13: "the hits feel like they have no
// impact"): laid over his own materials (material_overlay) for the hit-stop and a beat after it, a white fill with a
// brighter rim, faded out by the instance's `flash` (1 at the hit, 0 gone). Drawn added on top: his own look never changes.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 flash_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform float fill = 0.55;
uniform float rim_strength = 0.9;
uniform float rim_power = 2.0;
instance uniform float flash = 0.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO = flash_color.rgb * (fill + rim_strength * rim) * flash;
}
