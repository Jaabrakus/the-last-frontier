shader_type canvas_item;
// Turns a view of the game into an old oil painting, for the menu and the loading screens (user 2026-09-27: "oil
// paintings of that age"; tools/menu/paint_views.gd paints each one once, offline):
//   paint    a Kuwahara filter (each pixel takes the calmest of the four patches round it: flat strokes that keep
//            the edges), `brush` px, run twice at two sizes by the tool (broad masses, then the smaller strokes)
//   strokes  a ribbed brush texture laid along the paint's own edges (across the light's gradient), lightly
//   canvas   the weave of the canvas showing through, most in the darks
//   varnish  the old varnish's warm cast: the blacks lifted to umber, the whites to ivory, a little less saturated
//   frame    darker toward the corners, as a lamp-lit canvas
// The texture is drawn once per pass into the painter's viewport (blend off).
render_mode blend_disabled;

uniform sampler2D noise_a : repeat_enable, filter_linear;   // tileable noises: the hand's wobble (a, b), the
uniform sampler2D noise_b : repeat_enable, filter_linear;   // canvas and the bristles (c)
uniform sampler2D noise_c : repeat_enable, filter_linear;
uniform int brush = 5;              // Kuwahara radius (px)
uniform float wobble_px = 2.0;
uniform float stroke_amt = 0.1;    // how much the brush's ribs show
uniform float canvas_amt = 0.05;
uniform bool finish = true;         // the last pass: strokes, canvas, varnish and the frame's shade
uniform vec3 umber = vec3(0.10, 0.07, 0.045);
uniform vec3 ivory = vec3(0.96, 0.91, 0.78);
uniform float vignette = 0.45;
uniform float sharp = 30.0;        // how strongly the calmest sector wins (higher: flatter, crisper strokes)
uniform float lift = 0.8;          // the midtones lifted (a power under 1) before the varnish: the darks read

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE;
	vec2 n = vec2(texture(noise_a, UV * 2.3).r, texture(noise_b, UV * 2.3).r) - 0.5;
	vec2 uv = UV + n * ps * wobble_px;

	// generalized Kuwahara: eight overlapping sectors of a disc of radius `brush`; each sector's mean, weighted by how
	// calm it is (1 / (1 + variance^q)): round, soft-edged strokes that keep the forms' edges, no square patches
	vec3 m[8];
	vec3 m2[8];
	float w[8];
	for (int k = 0; k < 8; k++) {
		m[k] = vec3(0.0);
		m2[k] = vec3(0.0);
		w[k] = 0.0;
	}
	float r = float(brush);
	for (int j = -brush; j <= brush; j++) {
		for (int i = -brush; i <= brush; i++) {
			vec2 o = vec2(float(i), float(j));
			float d = length(o);
			if (d > r + 0.5) {
				continue;
			}
			vec3 c = texture(TEXTURE, uv + o * ps).rgb;
			float fall = exp(-d * d / (r * r * 0.6));
			if (d < 0.5) {
				for (int k = 0; k < 8; k++) {
					m[k] += c * fall;
					m2[k] += c * c * fall;
					w[k] += fall;
				}
				continue;
			}
			float a = atan(o.y, o.x) / 6.2831853 * 8.0;
			a = a < 0.0 ? a + 8.0 : a;
			int k0 = int(floor(a)) % 8;
			int k1 = (k0 + 1) % 8;
			float t = fract(a);
			float w0 = fall * (1.0 - t);
			float w1 = fall * t;
			m[k0] += c * w0;
			m2[k0] += c * c * w0;
			w[k0] += w0;
			m[k1] += c * w1;
			m2[k1] += c * c * w1;
			w[k1] += w1;
		}
	}
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	for (int k = 0; k < 8; k++) {
		if (w[k] <= 0.0001) {
			continue;
		}
		vec3 mean = m[k] / w[k];
		vec3 v3 = abs(m2[k] / w[k] - mean * mean);
		float sd = sqrt(v3.r + v3.g + v3.b) * sharp;
		float calm = 1.0 / (1.0 + pow(sd, 8.0));
		acc += mean * calm;
		wsum += calm;
	}
	vec3 best = wsum > 0.0 ? acc / wsum : texture(TEXTURE, uv).rgb;
	vec3 col = best;
	if (finish) {
		// strokes: ribs across the light's gradient (the brush drawn along the edges)
		float gx = lum(texture(TEXTURE, UV + vec2(ps.x * 3.0, 0.0)).rgb) - lum(texture(TEXTURE, UV - vec2(ps.x * 3.0, 0.0)).rgb);
		float gy = lum(texture(TEXTURE, UV + vec2(0.0, ps.y * 3.0)).rgb) - lum(texture(TEXTURE, UV - vec2(0.0, ps.y * 3.0)).rgb);
		vec2 g = vec2(gx, gy);
		vec2 along = length(g) > 0.002 ? normalize(vec2(-g.y, g.x)) : normalize(vec2(0.8, 0.35) + n);
		vec2 across = vec2(-along.y, along.x);
		vec2 sp = UV / ps;
		float rib = texture(noise_c, vec2(dot(sp, across) * 0.09, dot(sp, along) * 0.006)).r;
		col *= 1.0 + (rib - 0.5) * 2.0 * stroke_amt;
		// the canvas: a fine weave, most in the darks
		float weave = sin(sp.x * 1.9) * sin(sp.y * 1.9) * 0.5 + 0.5;
		float grain = texture(noise_c, UV * 23.0).r;
		col *= 1.0 - canvas_amt * (1.0 - lum(col)) * (0.6 * weave + 0.8 * grain - 0.7);
		// varnish: umber darks, ivory lights, a little less saturated, a warm cast
		col = pow(max(col, vec3(0.0)), vec3(lift));
		float l = lum(col);
		col = mix(vec3(l), col, 0.82);
		col = mix(umber, ivory, col);
		col *= vec3(1.03, 1.0, 0.9);
		// the frame's shade
		vec2 c = UV - 0.5;
		float vg = smoothstep(0.85, 0.2, length(c * vec2(1.0, 1.25)));
		col *= mix(1.0 - vignette, 1.0, vg);
	}
	COLOR = vec4(col, 1.0);
}
