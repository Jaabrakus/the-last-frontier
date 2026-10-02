// An animal's eye as the horse's (assets/horse/materials/horse_eye.gdshader, user 2026-10-02: "for the mammoth eyes we
// need it similar to how we did the horses eyes"): a matte, very dark brown ball, the iris and the pupil towards its front,
// a small catchlight for the wet. The eyeball's own frame comes in its UV (tools/wildlife/animal_hair.py: x how far a
// point faces out of the head, 1 at the front; y its height on the ball, -1..1), as the skinned animals' model space
// is not the head's.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 iris : source_color = vec3(0.19, 0.105, 0.05);
uniform vec3 pupil : source_color = vec3(0.025, 0.018, 0.014);
uniform vec3 sclera_shadow : source_color = vec3(0.06, 0.04, 0.03);
uniform float catchlight = 0.55;

void fragment() {
	float front = UV.x;
	vec3 c = mix(sclera_shadow, iris, smoothstep(0.35, 0.6, front));
	c = mix(c, pupil, smoothstep(0.78, 0.9, front) * smoothstep(0.55, 0.2, abs(UV.y)));
	ALBEDO = c;
	ROUGHNESS = 0.55;
	SPECULAR = 0.12;
	vec3 l = normalize(vec3(-0.35, 0.55, 0.75));
	float h = pow(max(dot(normalize(NORMAL), l), 0.0), 160.0);
	EMISSION = vec3(0.9, 0.88, 0.84) * h * catchlight;
}
