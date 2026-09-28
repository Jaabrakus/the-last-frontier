// Hoof horn (tools/horse/anatomy.py hoof_mesh_detail). Wall uv: u round the hoof (the
// right hind hoof, under the sock, has u + 2), v = 1 - UV.y from the ground (0) to the
// coronet (1); the underside has v < 0. Growth rings, vertical horn striations, a soft
// coronary band and a dusty sole.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

instance uniform vec4 hoof_dark : source_color = vec4(0.120, 0.105, 0.095, 1.0);
instance uniform vec4 hoof_light : source_color = vec4(0.620, 0.550, 0.440, 1.0);
instance uniform float white_amount = 1.0;

float hash(float x) { return fract(sin(x * 127.1) * 43758.5453); }
float vnoise(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(hash(i), hash(i + 1.0), f); }

void fragment() {
	float v = 1.0 - UV.y;
	float u = fract(UV.x);
	float light = step(1.5, UV.x) * white_amount;
	vec3 horn = mix(hoof_dark.rgb, hoof_light.rgb, light);
	float stri = vnoise(u * 140.0) * 0.6 + vnoise(u * 37.0) * 0.4;
	float rings = 0.5 + 0.5 * sin(v * 95.0 + vnoise(u * 12.0) * 3.0);
	vec3 c = horn * (0.82 + 0.25 * stri) * (0.95 + 0.07 * rings);
	c = mix(c, hoof_dark.rgb * 0.8, light * smoothstep(0.55, 0.85, stri) * 0.55);
	float band = smoothstep(0.86, 0.97, v);
	c = mix(c, c * 0.8 + vec3(0.03), band);
	float dust = smoothstep(0.25, 0.0, v) * 0.35;
	c = mix(c, vec3(0.34, 0.30, 0.25), dust);
	float rough = 0.55 - 0.12 * rings * (1.0 - dust) + 0.25 * dust;
	if (v < -0.02) {
		c = mix(vec3(0.30, 0.27, 0.23), vec3(0.22, 0.19, 0.16), smoothstep(-0.9, -0.6, v));
		rough = 0.92;
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.45;
	NORMAL_MAP = vec3(0.5 + (stri - 0.5) * 0.25, 0.5 + (rings - 0.5) * 0.06, 1.0);
}
