// Dust motes (look-dev spec 4.3, package A): draw pass. Tiny additive billboards lit only by the
// sun through a forward-scattering phase function, with shadows: they sparkle in sunbeams (most
// when the camera faces the sun) and vanish in shade. No ambient light, no fog, no shadow casting.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, ambient_light_disabled, specular_disabled, fog_disabled;

uniform vec3 mote_color : source_color = vec3(1.0, 0.93, 0.82);
uniform float intensity = 0.35;
// Henyey-Greenstein asymmetry: 0.6 = strongly forward (visible looking toward the sun).
uniform float anisotropy = 0.6;
// Faded in from near_fade and out toward far_fade (m from the camera) so the box edges never show.
uniform vec2 near_fade = vec2(0.25, 0.7);
uniform vec2 far_fade = vec2(5.0, 7.5);

varying float v_fade;

void vertex() {
	// Camera-facing billboard keeping the particle scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	float d = length((MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	v_fade = smoothstep(near_fade.x, near_fade.y, d) * (1.0 - smoothstep(far_fade.x, far_fade.y, d));
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float a = (1.0 - smoothstep(0.2, 1.0, r)) * v_fade;
	ALBEDO = mote_color * a;
}

void light() {
	// Scattering angle between the light's travel direction (-LIGHT) and the path to the eye (VIEW).
	float cos_t = dot(-LIGHT, VIEW);
	float g = anisotropy;
	float hg = (1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * cos_t, 1.5);
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR * hg * intensity / PI;
}
