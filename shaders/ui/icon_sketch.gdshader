shader_type canvas_item;
// Turns an item's render (ItemIcons: the model lit in the studio, on a clear background) into a small painting with
// a sketcher's ink over it (user 2026-09-27: "making the items in paintings would be amazing like sketches"):
//   paint   the render through a Kuwahara filter (each pixel takes the calmest of the four patches round it: flat,
//           brushy strokes that keep the edges), warmed a little and not quite as saturated
//   ink     a loose pen line round the outline, gone over twice a little apart, and lighter lines where the paint's
//           light or colour changes
//   hatch   pen strokes in the deepest shadows
//   glow    a faint soft warm glow just outside, so the drawing reads on the dark cells and over the world
// Drawn once per item into the painter's viewport (blend off: the colour and alpha written as they are).
render_mode blend_disabled;

uniform sampler2D noise_a : repeat_enable, filter_linear;   // three tileable noises: the hand's wobble (a, b),
uniform sampler2D noise_b : repeat_enable, filter_linear;   // the canvas grain (c)
uniform sampler2D noise_c : repeat_enable, filter_linear;
uniform vec3 ink = vec3(0.12, 0.08, 0.05);
uniform vec3 glow = vec3(0.93, 0.85, 0.68);
uniform int brush = 3;              // Kuwahara radius (px of the render)
uniform float line_px = 1.8;        // ink line reach
uniform float hatch_px = 6.0;       // hatch spacing
uniform float hatch_w = 1.5;        // hatch stroke width

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

// straight colour (the render is premultiplied by its alpha at the edges)
vec3 straight(vec4 c) { return c.a > 0.001 ? c.rgb / c.a : vec3(0.0); }

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE;
	vec2 n = vec2(texture(noise_a, UV * 1.7).r, texture(noise_b, UV * 1.7).r) - 0.5;
	vec2 n2 = vec2(texture(noise_a, UV * 5.3 + 0.37).r, texture(noise_b, UV * 5.3 + 0.37).r) - 0.5;
	float grain = texture(noise_c, UV * 9.0).r;
	vec2 uv = UV + n * ps * 1.5;                     // the hand's wobble

	// paint: Kuwahara, the four quadrants round the pixel, the one with the least variance wins
	vec3 best = vec3(0.0);
	float best_var = 1e9;
	float cov = 0.0;
	for (int q = 0; q < 4; q++) {
		vec2 dir = vec2(q % 2 == 0 ? -1.0 : 1.0, q < 2 ? -1.0 : 1.0);
		vec3 m = vec3(0.0);
		vec3 m2 = vec3(0.0);
		float cnt = 0.0;
		float qa = 0.0;
		for (int j = 0; j <= brush; j++) {
			for (int i = 0; i <= brush; i++) {
				vec4 c = texture(TEXTURE, uv + vec2(float(i), float(j)) * dir * ps);
				vec3 sc = straight(c);
				m += sc * c.a;
				m2 += sc * sc * c.a;
				cnt += c.a;
				qa += c.a;
			}
		}
		float total = float((brush + 1) * (brush + 1));
		cov += qa / total;
		if (cnt > 0.5) {
			m /= cnt;
			vec3 var3 = m2 / cnt - m * m;
			float var = var3.r + var3.g + var3.b;
			if (var < best_var) {
				best_var = var;
				best = m;
			}
		}
	}
	cov /= 4.0;
	vec3 paint = mix(vec3(lum(best)), best, 0.85) * vec3(1.04, 0.99, 0.92);
	paint *= 0.93 + 0.14 * grain;                     // the canvas under the paint

	// ink: the outline (the alpha's edge), twice, and lighter lines inside
	float l[9];
	float al[9];
	int k = 0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec4 c = texture(TEXTURE, uv + vec2(float(i), float(j)) * ps * line_px);
			l[k] = lum(straight(c)) * c.a;
			al[k] = c.a;
			k++;
		}
	}
	float gx = -l[0] - 2.0 * l[3] - l[6] + l[2] + 2.0 * l[5] + l[8];
	float gy = -l[0] - 2.0 * l[1] - l[2] + l[6] + 2.0 * l[7] + l[8];
	float ax = -al[0] - 2.0 * al[3] - al[6] + al[2] + 2.0 * al[5] + al[8];
	float ay = -al[0] - 2.0 * al[1] - al[2] + al[6] + 2.0 * al[7] + al[8];
	float inner = smoothstep(0.2, 0.55, length(vec2(gx, gy))) * (0.45 + 0.4 * n2.x);
	float outline = smoothstep(0.3, 1.0, length(vec2(ax, ay)));
	vec2 o2 = UV + vec2(n2.y, -n2.x) * ps * 2.4;
	float a2x = texture(TEXTURE, o2 + vec2(ps.x * line_px, 0.0)).a - texture(TEXTURE, o2 - vec2(ps.x * line_px, 0.0)).a;
	float a2y = texture(TEXTURE, o2 + vec2(0.0, ps.y * line_px)).a - texture(TEXTURE, o2 - vec2(0.0, ps.y * line_px)).a;
	float outline2 = smoothstep(0.3, 0.8, length(vec2(a2x, a2y))) * 0.55;
	float line = clamp(max(max(inner, outline), outline2), 0.0, 1.0);

	// hatching in the deepest shadows
	float v = lum(best);
	vec2 fc = FRAGCOORD.xy + n * 3.0;
	float h1 = 1.0 - smoothstep(hatch_w * 0.5, hatch_w * 0.5 + 0.8, abs(fract((fc.x + fc.y) / hatch_px) - 0.5) * hatch_px);
	float h2 = 1.0 - smoothstep(hatch_w * 0.5, hatch_w * 0.5 + 0.8, abs(fract((fc.x - fc.y) / hatch_px) - 0.5) * hatch_px);
	float hatch = clamp(h1 * smoothstep(0.34, 0.16, v) + h2 * smoothstep(0.18, 0.06, v), 0.0, 1.0)
			* smoothstep(0.5, 0.9, cov) * 0.45;

	vec3 col = mix(paint, ink, max(line, hatch));
	float item_a = smoothstep(0.25, 0.6, cov);
	float a = max(item_a, line);

	// the soft glow outside
	float g = 0.0;
	for (int q = 0; q < 12; q++) {
		float ang = float(q) * 0.5236;
		g += texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * ps * 4.0).a;
	}
	g = clamp(g / 12.0 * 1.6, 0.0, 1.0) * 0.38;
	float outa = max(a, g);
	COLOR = vec4(mix(glow, col, a / max(outa, 0.001)), outa);
}
