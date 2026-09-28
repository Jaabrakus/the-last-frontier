// Fireflies (scripts/wildlife/fireflies.gd): a camera-facing glow per particle that flashes like the eastern firefly
// (Photinus: a short J-shaped flash, ~0.45 s, every few seconds, each on its own rhythm), additive and bright enough
// to bloom in the glow pass. `presence` fades the swarm in at dusk and out at dawn.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 glow_color : source_color = vec3(0.78, 1.0, 0.32);
uniform float energy = 4.0;
uniform float presence = 1.0;

varying float v_flash;

float h11(float x) {
	return fract(sin(x * 127.1 + 311.7) * 43758.5453);
}

void vertex() {
	// face the camera (the particle's own position, the view's axes)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	float seed = h11(float(INSTANCE_ID));
	float period = 3.2 + seed * 3.4;
	float t = fract(TIME / period + seed * 7.0);
	v_flash = smoothstep(0.0, 0.03, t) * (1.0 - smoothstep(0.07, 0.16, t));
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float fall = 1.0 - smoothstep(0.5, 1.0, d);                     // round: nothing reaches the quad's edge
	float core = (exp(-d * d * 12.0) + 0.12 * exp(-d * d * 3.0)) * fall;  // a bright point and a faint halo
	ALBEDO = glow_color * energy * core;
	ALPHA = clamp(v_flash * presence, 0.0, 1.0) * fall;
}
