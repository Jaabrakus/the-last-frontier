// Torch smoke (TorchFire, push n01b): soft, dark, rolling puffs of pine soot. Particle billboards; the colour
// ramp (COLOR) fades them in and out. Unshaded (lit by the torch's own light, 20 cm below, the puffs glowed as an
// orange halo over the flame): a dim fire-lit orange close over the flame (fire_pos), near black away from it (a
// tint by age left the puffs a running torch leaves behind as orange balls in the air); no shadows, no depth
// writes.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

uniform vec3 fire_pos = vec3(0.0);   // the middle of the flame (world; TorchFire sets it every frame)

varying float v_seed;
varying float v_lit;

void vertex() {
	mat4 mw = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float a = INSTANCE_CUSTOM.x;
	mw = mw * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mw;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	v_seed = INSTANCE_CUSTOM.x;
	v_lit = 1.0 - smoothstep(0.08, 0.45, distance(MODEL_MATRIX[3].xyz, fire_pos));
}

void fragment() {
	vec2 p = UV - 0.5;
	float n = vnoise(UV * 3.0 + v_seed * 3.7) * 0.6 + vnoise(UV * 7.0 - v_seed) * 0.4;
	float d = length(p) * 2.0 + (n - 0.5) * 0.5;
	float a = (1.0 - smoothstep(0.35, 1.0, d)) * COLOR.a;
	// soot: lit orange from below by the fire just over it, near black away from it (unlit grey puffs read as fog
	// against the night sky)
	ALBEDO = mix(vec3(0.006, 0.005, 0.005), vec3(0.16, 0.065, 0.02), v_lit);
	ALPHA = clamp(a, 0.0, 1.0);
}
