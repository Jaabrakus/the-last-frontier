// The glow round a lit lantern or brazier (RingDressing, a MultiMesh of camera-facing cards, the instance colour its
// colour and strength): a soft disc added over the scene, so the lights read warm at night without volumetric fog.
// `strength` 0 by day. Pulled toward the camera a little so it is not cut by the lantern it sits on.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float strength = 1.0;
uniform float flicker = 0.12;

varying vec4 v_col;

void vertex() {
	v_col = COLOR;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 r = INV_VIEW_MATRIX[0].xyz;
	vec3 u = INV_VIEW_MATRIX[1].xyz;
	vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - origin);
	vec3 wp = origin + to_cam * s * 0.35 + (r * VERTEX.x + u * VERTEX.y) * s;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
	float ph = origin.x * 1.3 + origin.z * 0.7;
	v_col.a *= 1.0 - flicker + flicker * sin(TIME * 9.0 + ph) * sin(TIME * 5.3 + ph * 2.0);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float g = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
	ALBEDO = v_col.rgb * g * v_col.a * strength;
}
