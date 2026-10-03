shader_type spatial;
// The Form circle (FormCircle; SwayCaster's lock drawn on the ground): our own circle-work, a surveyor's compass card more than
// anything else: a double outer ring, a band of compass ticks (32 points, the 8 long) turning slowly, an inner ring, the
// quartering lines and two squares (one on the points, one on the faces), a ring of eight small rounds turning the other way,
// and a small ring at the heart. It draws itself in that order as `fill` goes 0 -> 1 (each part sweeping round or growing out
// from the middle), glows blue-white, pulses when full, `flash` brightens it (the click, the release), `fade` takes it away.
// Unshaded, the lines blue-white with a bluer glow round them, on a flat quad laid on the ground (or a wall), pulled a little toward the camera so it sits over uneven
// ground without hiding behind it.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform, fog_disabled;

uniform float fill : hint_range(0.0, 1.0) = 0.0;
uniform float glow : hint_range(0.0, 2.0) = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float full = 0.0;
uniform vec3 color : source_color = vec3(0.66, 0.86, 1.0);
uniform float spin = 0.0;
uniform float pull_m = 0.12;
uniform float line_w = 0.011;

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length(VERTEX);
	VERTEX *= max(1.0 - pull_m / max(d, 0.001), 0.2);
}

// 0..1 of the way round from the top, clockwise (seen from above).
float round01(vec2 p) {
	return fract(0.25 - atan(p.y, p.x) / 6.2831853);
}

float line(float d, float w, float aa) {
	return 1.0 - smoothstep(w - aa, w + aa, d);
}

float halo(float d) {
	return exp(-d * 60.0) * 0.6;
}

float seg_d(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

vec2 rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float aa = fwidth(r) * 1.2 + 0.002;
	float a01 = round01(p);
	float w = line_w;
	float v = 0.0;
	float hv = 0.0;
	// 1. the outer double ring, sweeping round (fill 0 -> 0.3)
	float s1 = clamp(fill / 0.3, 0.0, 1.0);
	float on1 = step(a01, s1);
	float d1 = min(abs(r - 0.955), abs(r - 0.905));
	v += line(d1, w, aa) * on1;
	hv += halo(d1) * on1;
	// 2. the compass ticks between 0.78 and 0.88, turning (fill 0.18 -> 0.5)
	float s2 = clamp((fill - 0.18) / 0.32, 0.0, 1.0);
	vec2 pt = rot(p, spin * 0.12);
	float at = round01(pt) * 32.0;
	float k = floor(at + 0.5);
	float da = abs(at - k) / 32.0 * 6.2831853 * r;
	bool long_t = mod(k, 4.0) < 0.5;
	float r0 = long_t ? 0.74 : 0.8;
	float inband = step(r0, r) * step(r, 0.88);
	float dt = da + (1.0 - inband) * 1.0;
	v += line(dt, w * 0.8, aa) * step(a01, s2) * inband;
	// 3. the inner ring (fill 0.32 -> 0.52)
	float s3 = clamp((fill - 0.32) / 0.2, 0.0, 1.0);
	float d3 = abs(r - 0.62);
	v += line(d3, w, aa) * step(1.0 - a01, s3);
	hv += halo(d3) * step(1.0 - a01, s3);
	// 4. the quartering lines and the two squares, growing out from the middle (fill 0.5 -> 0.8)
	float s4 = clamp((fill - 0.5) / 0.3, 0.0, 1.0);
	float reach = s4 * 0.62;
	float d4 = min(abs(p.x), abs(p.y)) + step(reach, r) * 1.0;
	v += line(d4, w * 0.75, aa) * step(0.2, r);
	vec2 q = rot(p, 0.7853982);
	float sq_a = abs(max(abs(p.x), abs(p.y)) - 0.438);          // on the faces: its corners on the inner ring
	float sq_b = abs(max(abs(q.x), abs(q.y)) - 0.438);          // on the points
	float grow = smoothstep(0.0, 1.0, s4);
	float d5 = min(sq_a, sq_b) + step(grow * 0.62 + 0.001, r) * 1.0;
	v += line(d5, w * 0.9, aa);
	hv += halo(d5) * 0.6;
	// 5. the eight small rounds at 0.72, turning the other way, and the heart (fill 0.72 -> 0.95)
	float s5 = clamp((fill - 0.72) / 0.23, 0.0, 1.0);
	vec2 pr = rot(p, -spin * 0.2);
	float ar = round01(pr) * 8.0;
	float kr = floor(ar + 0.5);
	float ang = (0.25 - kr / 8.0) * 6.2831853;
	vec2 c8 = vec2(cos(ang), sin(ang)) * 0.70;
	float d6 = abs(length(pr - c8) - 0.045);
	v += line(d6, w * 0.8, aa) * step(kr / 8.0, s5 * 1.0001);
	hv += halo(d6) * 0.5 * step(kr / 8.0, s5 * 1.0001);
	float d7 = min(abs(r - 0.16), r < 0.035 ? 0.0 : 1.0);
	v += line(d7, w, aa) * s5;
	hv += halo(d7) * s5;
	// full: a slow pulse; the flash; the edge of the disc fades out. The line's core runs to white, its glow stays blue.
	float pulse = 1.0 + full * (0.25 + 0.25 * sin(TIME * 9.0));
	float edge = 1.0 - smoothstep(0.97, 1.0, r);
	float core = clamp(v, 0.0, 1.0);
	float hal = clamp(hv * 1.2 * pulse, 0.0, 0.6);
	float fl = flash * (1.0 - smoothstep(0.0, 1.0, r)) * 0.7;
	float a = clamp(max(core * 0.95, hal) + fl, 0.0, 1.0) * clamp(glow, 0.0, 1.0) * edge * fade;
	// (the glow a deeper blue, the line's core bright blue-white, over 1: it blooms where the scene glows)
	vec3 deep = color * vec3(0.6, 0.8, 1.0);
	vec3 hot = mix(color, vec3(1.0), 0.4 + 0.2 * full) * 1.5;
	float kc = clamp(core / max(core + hal * 0.6, 0.001), 0.0, 1.0);
	vec3 col = mix(deep, hot, kc);
	col = mix(col, vec3(1.6), clamp(flash * 0.6, 0.0, 1.0));
	ALBEDO = col * (1.0 + max(glow - 1.0, 0.0) * 0.6);
	ALPHA = a;
}
