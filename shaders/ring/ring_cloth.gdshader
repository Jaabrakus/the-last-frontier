// The Tidebreak ring's cloth (RingDressing): hanging banners, the stands' awnings and the bunting's pennants, all
// waving in the shared wind. The mesh is a grid; UV (0,0) at the hoist / top-left, UV.y down the cloth, so the pinned
// edge (UV.y 0) stays put and the free end waves most.
//   mode 0  banner: `base` with a `trim` border, a swallowtail cut at the foot and the element's mark (glyph 0 earth,
//           1 water, 2 fire, 3 air) in a `mark` medallion
//   mode 1  awning: stripes across (`stripes` of them, base / trim) and a scalloped valance edge at the foot
//   mode 2  pennant: the instance colour (MultiMesh COLOR), a thin trim at the top
//   mode 3  plaque: the round medallion and its mark alone (wave_amp 0)
//   mode 4  frieze: a band of the base with trim lines and a running wave crest in the mark colour (wave_amp 0)
// The cloth billows along its own normal; UV2.x its phase (0..1) where several cloths share one mesh.
// Flat two-tone light (cel friendly): lit or shade, both sides of the cloth lit alike.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

#include "res://shaders/common/wind.gdshaderinc"

uniform int mode = 0;
uniform vec3 base : source_color = vec3(0.12, 0.32, 0.62);
uniform vec3 trim : source_color = vec3(0.92, 0.74, 0.32);
uniform vec3 mark : source_color = vec3(0.92, 0.94, 0.9);
uniform int glyph = 1;
uniform float aspect = 3.0;          // the cloth's height / width (the mark stays round)
uniform float stripes = 8.0;
uniform float wave_amp = 0.12;       // m at the free end
uniform float wave_k = 4.0;          // waves down the cloth
uniform float wave_speed = 2.2;
uniform float shade_floor : hint_range(0.0, 1.0) = 0.0;
uniform float across_k = 1.3;        // waves across the cloth (UV.x)

varying vec3 v_col;

void vertex() {
	v_col = COLOR.rgb;
	float free_ = UV.y;
	// the phase: the cloth's own (UV2.x, merged meshes) or the instance's (MultiMesh), and a little across it
	float ph = UV2.x * 6.2831853 + float(INSTANCE_ID) * 1.7 + MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.23;
	float g = frontier_gust(MODEL_MATRIX[3].xz + VERTEX.xz * 0.05);
	float ws = clamp(wind_strength, 0.0, 1.0);
	float amp = wave_amp * (0.55 + 0.9 * ws) * (0.8 + 0.4 * g);
	float w = sin(free_ * wave_k - TIME * wave_speed + ph + UV.x * across_k) + 0.4 * sin(free_ * wave_k * 2.3 - TIME * wave_speed * 1.7 + ph);
	// billows along the cloth's own facing (its normal), the pinned edge still
	VERTEX += NORMAL * w * amp * free_;
	if (mode == 2) {
		VERTEX.x += sin(TIME * 5.0 + ph * 3.0) * 0.05 * free_;
	}
}

float sd_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// the element's mark in the medallion (p: -1..1)
float glyph_mask(vec2 p, int g) {
	if (g == 0) {
		// earth: a square set in a square (a cut stone)
		float a = step(sd_box(p, vec2(0.62)), 0.0) - step(sd_box(p, vec2(0.46)), 0.0);
		float b = step(sd_box(p, vec2(0.28)), 0.0);
		return clamp(a + b, 0.0, 1.0);
	} else if (g == 1) {
		// water: three waves
		float m = 0.0;
		for (int i = 0; i < 3; i++) {
			float y = -0.45 + float(i) * 0.45;
			float wy = y + 0.13 * sin(p.x * 5.2 + float(i));
			m += step(abs(p.y - wy), 0.075) * step(abs(p.x), 0.72);
		}
		return clamp(m, 0.0, 1.0);
	} else if (g == 2) {
		// fire: a flame with a hollow heart
		vec2 q = vec2(p.x, -p.y);
		float t = clamp((q.y + 0.25) / 1.1, 0.0, 1.0);
		float hw = 0.5 * (1.0 - t) * (1.0 - t * 0.2) + 0.08 * sin(q.y * 7.0) * t;
		float tip = step(abs(q.x + 0.12 * t * t), hw) * step(-0.25, q.y) * step(q.y, 0.85);
		float bowl = step(length(q - vec2(0.0, -0.25)), 0.5);
		float hole = step(length(q - vec2(0.0, -0.3)), 0.2);
		return clamp(max(tip, bowl) - hole, 0.0, 1.0);
	}
	// air: three arcs swirling round the centre
	float r = length(p);
	float a = atan(p.y, p.x);
	float m = 0.0;
	for (int i = 0; i < 3; i++) {
		float aa = a + float(i) * 2.0944;
		float rr = 0.22 + 0.42 * fract(aa / 6.2831853);
		m += step(abs(r - rr), 0.06) * step(0.18, r);
	}
	return clamp(m, 0.0, 1.0) * step(r, 0.72);
}

void fragment() {
	vec3 col = base;
	if (mode == 0) {
		// the swallowtail: a V cut up into the foot
		float cut = 0.86 + abs(UV.x - 0.5) * 0.28;
		if (UV.y > cut) {
			discard;
		}
		float bx = min(UV.x, 1.0 - UV.x);
		float by = min(UV.y * aspect, (cut - UV.y) * aspect);
		float border = min(bx, by);
		if (border < 0.07) {
			col = trim;
		} else if (border < 0.1) {
			col = base * 0.55;
		}
		// the medallion
		vec2 c = vec2(0.5, 0.3);
		vec2 p = vec2(UV.x - c.x, (UV.y - c.y) * aspect) / 0.36;
		float r = length(p);
		if (r < 1.0) {
			col = r > 0.88 ? trim : base * 0.6;
			if (glyph_mask(p * 1.12, glyph) > 0.5) {
				col = mark;
			}
		}
		// a band of the trim under it
		float yb = UV.y * aspect;
		if (abs(yb - (0.3 + 0.36 + 0.28) * aspect) < 0.05 && bx > 0.1) {
			col = trim;
		}
	} else if (mode == 1) {
		float s = floor(UV.x * stripes);
		col = mod(s, 2.0) < 0.5 ? base : trim;
		// the scalloped valance at the foot (the last 12 %)
		float sc = fract(UV.x * stripes);
		float edge = 0.9 + 0.1 * sqrt(max(0.0, 1.0 - pow(sc * 2.0 - 1.0, 2.0)));
		if (UV.y > edge) {
			discard;
		}
		if (UV.y > 0.86 && UV.y < 0.885) {
			col = mark;
		}
	} else if (mode == 2) {
		col = v_col;
		if (UV.y < 0.12) {
			col = trim;
		}
	} else if (mode == 3) {
		// a plaque: the medallion alone, round
		vec2 p = (UV - 0.5) * 2.0;
		float r = length(p);
		if (r > 1.0) {
			discard;
		}
		col = r > 0.86 ? trim : base;
		if (glyph_mask(p * 1.25, glyph) > 0.5) {
			col = mark;
		}
	} else {
		// a frieze: a band of the base with trim lines and a running wave crest (UV.x in metres)
		float y = UV.y;
		float crest = 0.5 + 0.22 * sin(UV.x * 6.2831853 / 1.1);
		float hook = 0.5 + 0.22 * sin((UV.x + 0.18) * 6.2831853 / 1.1);
		if (y < 0.1 || y > 0.9) {
			col = trim;
		} else if (abs(y - crest) < 0.07 || (abs(y - hook) < 0.05 && y > 0.5)) {
			col = mark;
		}
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
}

void light() {
	float nl = abs(dot(NORMAL, LIGHT));
	float lit = smoothstep(0.02, 0.12, nl) * ATTENUATION;
	DIFFUSE_LIGHT += max(lit, shade_floor) * LIGHT_COLOR / PI;
}
