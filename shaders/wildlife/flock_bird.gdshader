// Small flock birds (scripts/wildlife/bird_flock.gd): the wings beat in the vertex shader. COLOR.r marks the wing
// vertices that move (their distance out along x is the lever), each instance its own phase and a touch of its own rate.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 plumage : source_color = vec3(0.07, 0.065, 0.06);
uniform float beat_hz = 2.6;

float h11(float x) {
	return fract(sin(x * 91.7 + 17.3) * 43758.5453);
}

void vertex() {
	if (COLOR.r > 0.5) {
		float seed = h11(float(INSTANCE_ID));
		float a = sin(TIME * 6.2831 * beat_hz * (0.85 + 0.3 * seed) + seed * 40.0) * 0.95;
		float lever = abs(VERTEX.x);
		VERTEX.y += sin(a) * lever;
		VERTEX.x = sign(VERTEX.x) * cos(a) * lever;
	}
}

void fragment() {
	ALBEDO = plumage;
	ROUGHNESS = 0.8;
}
