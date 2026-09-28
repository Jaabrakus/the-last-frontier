// A fish (FishMesh; FishLife draws them in one MultiMesh a species): its skin, and its swimming: the body waved from
// side to side, the wave running from head to tail and wider toward it (an eel's all along), bent into its turns.
// Per fish (the MultiMesh's custom data): x its wave's phase (0..1), y tail beats a second, z how hard it swims (0
// still .. 1 cruising .. 2 a burst), w its bend (turning: + to its right). Alone (a fish held, the bake's previews)
// the custom data is zero: still.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float roughness_v = 0.4;
uniform float specular_v = 0.5;
uniform float wave_k = 0.85;       // waves along the body
uniform float amp_head = 0.012;    // side to side at the head, fractions of its length
uniform float amp_tail = 0.11;     // at the tail
uniform vec3 tint : source_color = vec3(1.0);   // a roast's browning (FishModels), over the skin by tint_amount
uniform float tint_amount = 0.0;

void vertex() {
	float u = clamp(VERTEX.z + 0.5, 0.0, 1.2);
	vec4 cu = INSTANCE_CUSTOM;
	float amp = mix(amp_head, amp_tail, u * u) * cu.z;
	float ph = 6.2831853 * (wave_k * u - TIME * cu.y + cu.x);
	float bend = cu.w * 0.3;
	VERTEX.x += amp * sin(ph) + bend * u * u;
	// the surface turned with the body's curve (its slope along z)
	float s = amp * 6.2831853 * wave_k * cos(ph) + 2.0 * bend * u + (amp_tail - amp_head) * cu.z * 2.0 * u * sin(ph);
	NORMAL = normalize(vec3(NORMAL.x + NORMAL.z * s, NORMAL.y, NORMAL.z - NORMAL.x * s));
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	ALBEDO = mix(c, tint * (0.6 + 0.4 * dot(c, vec3(0.333))), tint_amount);
	ROUGHNESS = roughness_v;
	SPECULAR = specular_v;
}
