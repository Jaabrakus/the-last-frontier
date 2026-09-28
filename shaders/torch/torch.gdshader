// The hand torch (TorchModels, push n01b): a split pitch-pine stave, birch-bark bindings and a head of
// resin-soaked fat-pine splints that chars as it burns, with embers glowing in the cracks near the fire.
// Vertex colour: r = part (0 stave, 0.5 bark binding, 1 splints), g = 0 at the butt .. 1 at the top.
shader_type spatial;
render_mode cull_disabled;

uniform float glow : hint_range(0.0, 1.0) = 0.0;        // the fire on it (ember glow)
uniform float char_amount : hint_range(0.0, 1.0) = 0.0; // how far it has burnt down (charring creeps down)

varying vec3 lp;
varying float part;
varying float along;

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

void vertex() {
	lp = VERTEX;
	part = COLOR.r;
	along = COLOR.g;
}

void fragment() {
	float ang = atan(lp.y, lp.x);
	vec3 col;
	float rough;
	float spec = 0.4;
	vec3 emit = vec3(0.0);
	if (part < 0.25) {
		// split pitch pine: pale sapwood to resinous heart, grain along the stave, handled darker at the grip
		float grain = vnoise(vec2(ang * 9.0, lp.z * 90.0)) * 0.6 + vnoise(vec2(ang * 30.0, lp.z * 300.0)) * 0.4;
		col = mix(vec3(0.40, 0.29, 0.17), vec3(0.58, 0.44, 0.27), grain);
		float grip = 1.0 - smoothstep(0.03, 0.09, abs(lp.z));
		col *= 1.0 - 0.3 * grip;
		// soot and char creeping down from the head
		float soot = smoothstep(0.55, 0.7, along + char_amount * 0.15);
		col = mix(col, vec3(0.05, 0.035, 0.025), soot * 0.85);
		rough = mix(0.82, 0.6, grip);
	} else if (part < 0.75) {
		// birch bark: cream white with dark horizontal lenticels and scorch on the upper band
		float lent = step(0.82, vnoise(vec2(ang * 6.0, lp.z * 260.0)) * vnoise(vec2(ang * 22.0, lp.z * 40.0)) * 1.6);
		col = mix(vec3(0.80, 0.76, 0.66), vec3(0.16, 0.12, 0.09), lent);
		col *= 0.85 + 0.15 * vnoise(vec2(ang * 3.0, lp.z * 50.0));
		float scorch = smoothstep(0.6, 0.85, along + char_amount * 0.25);
		col = mix(col, vec3(0.06, 0.045, 0.035), scorch * 0.7);
		rough = 0.7;
	} else {
		// fat-pine splints: amber-brown and resin-glossy low down, charred black at the top; embers in the cracks
		float n1 = vnoise(vec2(ang * 7.0, lp.z * 60.0));
		float n2 = vnoise(vec2(ang * 23.0 + 3.0, lp.z * 180.0));
		float top = smoothstep(0.72, 0.95, along + char_amount * 0.12 + n1 * 0.08);
		col = mix(vec3(0.30, 0.17, 0.08), vec3(0.045, 0.03, 0.022), top);
		col *= 0.8 + 0.4 * n2;
		rough = mix(0.32, 0.75, top);
		spec = 0.55;
		float cracks = smoothstep(0.55, 0.9, n2 * 0.7 + n1 * 0.5);
		float flick = 0.75 + 0.25 * sin(TIME * 9.0 + n1 * 12.0);
		emit = vec3(1.0, 0.32, 0.06) * glow * top * cracks * flick * 3.0;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = emit;
}
