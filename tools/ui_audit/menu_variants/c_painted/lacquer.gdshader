shader_type canvas_item;
// Menu variant C ("Painted river"): a lacquer board (sơn mài): black-red lacquer with gold dust (lacquer_tile.png,
// painted by make_ink.py), a vermilion band round its edge, two gold-leaf hairlines, a soft sheen across it.
// One material per board (rect_size).

uniform sampler2D lacquer : repeat_enable, filter_linear_mipmap;
uniform sampler2D flake : repeat_enable, filter_linear;
uniform vec2 rect_size = vec2(400.0, 300.0);
uniform float radius = 5.0;
uniform float band = 8.0;            // the vermilion band (px); 0: none
uniform float gold_inset = 13.0;     // the inner gold line, from the edge (px); 0: none
uniform float gold_w = 1.4;
uniform vec3 band_col : source_color = vec3(0.56, 0.17, 0.12);
uniform vec3 gold_col : source_color = vec3(0.84, 0.66, 0.36);
uniform float sheen = 0.10;
uniform vec2 seed = vec2(0.0);
uniform vec3 base_col : source_color = vec3(0.50, 0.12, 0.08);   // a coloured lacquer (son: vermilion) over the black
uniform float base_mix = 0.0;

void fragment() {
	vec2 p = UV * rect_size;
	vec2 h = rect_size * 0.5;
	vec2 q = abs(p - h) - (h - vec2(radius));
	float sd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;      // < 0 inside
	float a = clamp(-sd + 0.5, 0.0, 1.0);
	vec3 c = texture(lacquer, (p + seed * 512.0) / 512.0).rgb;
	float f = texture(flake, p / 90.0).r;
	if (base_mix > 0.0) {
		// the coloured coat: the black's light and shade carried into it, the gold dust left showing
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		float gold_dust = smoothstep(0.25, 0.45, c.r - c.b * 0.6);
		vec3 coat = base_col * (0.75 + 2.2 * l) * (0.9 + 0.2 * f);
		c = mix(c, coat, base_mix * (1.0 - gold_dust));
	}
	if (band > 0.0) {
		float b = smoothstep(-band - 0.6, -band + 0.6, sd);
		vec3 red = band_col * (0.85 + 0.3 * f);
		c = mix(c, red, b);
	}
	float g = 0.0;
	if (band > 0.0) {
		g = max(g, 1.0 - smoothstep(gold_w * 0.5, gold_w * 0.5 + 0.9, abs(sd + band)));
	}
	if (gold_inset > 0.0) {
		g = max(g, 1.0 - smoothstep(gold_w * 0.5, gold_w * 0.5 + 0.9, abs(sd + gold_inset)));
	}
	vec3 gold = gold_col * (0.8 + 0.45 * f);
	c = mix(c, gold, g);
	// the sheen: a broad soft highlight from the upper left, and the lacquer's depth toward the lower right
	float s = exp(-pow(dot(UV - vec2(0.18, 0.12), normalize(vec2(1.0, 0.8))) * 2.6, 2.0));
	c += vec3(0.9, 0.75, 0.6) * sheen * s;
	c *= 1.0 - 0.18 * smoothstep(0.3, 1.2, length(UV - vec2(0.2, 0.15)));
	COLOR = vec4(c, a * COLOR.a);
}
