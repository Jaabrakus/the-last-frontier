// The tank's curtain of falling water (RingWater, the % ring's stage: smash_r3 spec v2 §5.1): a sheet spilling from the
// rim channel over the deck down to the tank all round. Our own procedural water: streaks running down at flow_mps, a
// glassy tint, white water where it leaves the lip and where it hits the tank, thin gaps that let the stone behind show.
// UV.x metres along the curtain, UV.y metres down from the lip; height the sheet's drop (m). Lit, two-sided.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.62, 0.82, 0.86);
uniform vec3 foam : source_color = vec3(0.92, 0.97, 1.0);
uniform float alpha = 0.82;
uniform float flow_mps = 5.5;
uniform float height = 9.0;
uniform float glow_k = 0.08;

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

void fragment() {
	float t = TIME * flow_mps;
	float x = UV.x;
	float y = UV.y;
	// long streaks running down, faster lower (the water speeds as it falls)
	float fall = y * (1.0 + y * 0.06);
	float s1 = vnoise(vec2(x * 3.1, (fall - t) * 0.35));
	float s2 = vnoise(vec2(x * 9.7 + 17.0, (fall - t * 1.2) * 0.8));
	float streak = s1 * 0.65 + s2 * 0.35;
	// white water: at the lip (a thin roll) and at the foot (spray)
	float lip = 1.0 - smoothstep(0.0, 0.35, y);
	float foot = smoothstep(height - 1.6, height, y);
	float white = clamp(max(lip * 0.85, foot) + smoothstep(0.62, 0.9, streak) * 0.55, 0.0, 1.0);
	vec3 col = mix(tint * (0.55 + 0.45 * streak), foam, white);
	ALBEDO = col;
	ROUGHNESS = mix(0.08, 0.5, white);
	// (a faint glow of its own white water, so the curtain still reads as water at night)
	EMISSION = foam * white * glow_k + tint * 0.25 * glow_k;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	// thin gaps in the sheet (the stone behind it shows a little), never at the lip or the foot
	float gap = smoothstep(0.18, 0.08, s2) * (1.0 - lip) * (1.0 - foot);
	ALPHA = clamp(alpha * (0.75 + 0.25 * streak) * (1.0 - gap * 0.6) + white * 0.15, 0.0, 1.0);
}
