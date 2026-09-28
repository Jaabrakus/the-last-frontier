// Horse eye (revision 4): a wet, very dark brown eyeball that reads as an eye in any light.
// A dark iris towards the front with a slightly lighter brown ring, a clear wet coat, and a
// small catchlight (a highlight from a fixed direction in view space, as a soft window
// reflection), so the eye never reads as an empty socket in shade or against a dark sky.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 iris : source_color = vec3(0.20, 0.11, 0.06);
uniform vec3 pupil : source_color = vec3(0.03, 0.02, 0.018);
uniform vec3 sclera_shadow : source_color = vec3(0.10, 0.07, 0.06);
uniform float catchlight = 0.9;

varying vec3 obj_n;

void vertex() {
	obj_n = NORMAL;
}

void fragment() {
	// the eyeball's outward axis is its lateral axis (+x left eye, -x right eye; model space)
	float front = abs(obj_n.x);
	vec3 c = mix(sclera_shadow, iris, smoothstep(0.35, 0.6, front));
	c = mix(c, pupil, smoothstep(0.78, 0.9, front) * smoothstep(0.55, 0.2, abs(obj_n.y)));
	ALBEDO = c;
	ROUGHNESS = 0.04;
	SPECULAR = 0.8;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.02;
	vec3 l = normalize(vec3(-0.35, 0.55, 0.75));
	float h = pow(max(dot(normalize(NORMAL), l), 0.0), 90.0);
	EMISSION = vec3(0.9, 0.88, 0.84) * h * catchlight;
}
