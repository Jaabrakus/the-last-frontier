// Rings on the water (FishLife): where a fish took an insect off the top, leapt, or bolted through the shallows. Each a
// flat quad on the surface, scaled out as its rings spread; three rings following one another out, fading as they go.
// Per ring (the MultiMesh's custom data): x its age (0 new .. 1 gone), y how strong (0..1), z the daylight (dim at night).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

varying vec4 cu;

void vertex() {
	cu = INSTANCE_CUSTOM;
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float age = cu.x;
	float a = 0.0;
	for (int i = 0; i < 3; i++) {
		float ri = 0.9 - float(i) * 0.26;
		float w = 0.03 + 0.035 * age;
		a += smoothstep(w, 0.0, abs(r - ri)) * (1.0 - float(i) * 0.3);
	}
	ALBEDO = vec3(0.86, 0.9, 0.92) * mix(0.25, 1.0, cu.z);
	ALPHA = clamp(a, 0.0, 1.0) * cu.y * (1.0 - age) * (1.0 - age) * 0.5;
}
