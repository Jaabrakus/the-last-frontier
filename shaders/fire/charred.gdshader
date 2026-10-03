// Charred wood (scripts/fire: FireSpread, FireRuin): what a burning piece's mesh turns to once the fire has
// taken it (the charred material swap) and what is left of it as a ruin. Charcoal near black, crazed into
// blocks with grey ash on the tops, embers glowing in the cracks while it is hot (`glow`), and above `cut_y`
// (world height, ragged with noise) nothing: the ruin's burnt stubs. One material for every piece; what
// differs per piece is in instance uniforms (GeometryInstance3D.set_instance_shader_parameter), so the
// pieces share one shader and one material.
shader_type spatial;
render_mode cull_disabled;

instance uniform float cut_y = 100000.0;   // world height above which the wood has burnt away (ragged), at cut_at
instance uniform vec2 cut_slope = vec2(0.0); // the ground's rise per m along x and z under the piece: the cut follows it
instance uniform vec2 cut_at = vec2(0.0);    // where cut_y is (world xz)
instance uniform float glow = 0.0;         // 0..1: the embers in the cracks
instance uniform float seed = 0.0;
// The embers' brightness for the eye (FireSpread sets it: 1 / the exposure, Fx._fire_dim): on the screen at most
// about 1.4 at any hour (`hot` at most 1.8, x EMBER), under the glow's threshold of 4 (the night's exposure is 5.4).
uniform float dim = 1.0;
const float EMBER = 0.8;

varying vec3 v_world;
varying vec3 v_wnormal;

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
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// the ragged top of what is left
	float rag = vnoise(v_world.xz * 1.6 + seed) * 0.65 + vnoise(v_world.xz * 6.0 - seed) * 0.35;
	float top = cut_y + dot(cut_slope, v_world.xz - cut_at) + (rag - 0.5) * 0.7;
	if (v_world.y > top) {
		discard;
	}
	// alligatored charcoal: blocks along the grain with dark cracks between them
	vec2 q = vec2(v_world.x + v_world.z, v_world.y) * vec2(5.0, 9.0) + seed;
	float block = vnoise(q);
	float crack = 1.0 - smoothstep(0.04, 0.12, abs(fract(q.x * 0.5 + block * 0.6) - 0.5)) ;
	crack = max(crack, 1.0 - smoothstep(0.04, 0.12, abs(fract(q.y * 0.35 + block * 0.4) - 0.5)));
	vec3 coal = mix(vec3(0.03, 0.027, 0.025), vec3(0.085, 0.078, 0.07), block);
	coal *= 1.0 - 0.6 * crack;
	// grey-white ash settles on the tops and the cut ends
	float up = smoothstep(0.35, 0.9, v_wnormal.y);
	float ash = up * smoothstep(0.35, 0.75, vnoise(v_world.xz * 3.0 + seed * 1.7));
	ALBEDO = mix(coal, vec3(0.34, 0.33, 0.315), ash * 0.8);
	ROUGHNESS = mix(0.82, 0.95, ash);
	SPECULAR = 0.25;
	// embers: in the cracks and along the burnt edge, breathing slowly
	float edge = 1.0 - smoothstep(0.0, 0.4, top - v_world.y);
	float breathe = 0.65 + 0.35 * sin(TIME * 1.3 + rag * 9.0 + block * 4.0);
	float hot = (crack * (0.6 + 0.4 * block) + edge * 0.8) * breathe;
	EMISSION = vec3(1.0, 0.3, 0.05) * glow * glow * hot * EMBER * dim;
}
