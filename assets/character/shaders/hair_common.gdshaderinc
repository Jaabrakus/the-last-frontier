// Shared code of hair.gdshader (opaque cap, tails, braids, wraps) and hair_cards.gdshader
// (alpha strands). UV = metres, u across the strands, v along them (combing direction);
// UV2.x = region + 64 * zone (zone 0 hair, 1 accent: ribbon / wrap / cord / garter,
// 2 metal), UV2.y = 1 - h (cards: 0 at the root .. 1 at the tip).
//
// Colour: eumelanin (0..8) picks a colour along anchors from flaxen through browns to
// blue-black (linear light), pheomelanin (0..4) adds the red / orange of auburn and red
// hair (an absorption tint), with per-strand variation, `grey` (share of white strands)
// and `powder` (hair powder).
// Presets: assets/character/hair/hair_colors.json. The same model gives the brows'
// colour (BodyMaterials.hair_color()).
//
// `stylized` 1 (the creator's Stylized face style): painted hair (painted_hair()): chunky
// sculpted locks across the combing direction (about 2.2 cm, a little narrower for cropped hair;
// coily hair in rounded clumps), each lock shaded from its dark grooves to a lit crest with a
// few painted strands, a per-lock tint, and a painted sheen band where the hair faces up (the
// "halo" of a painted head of hair). The lock relief also bends the normal, so the game's
// lights model the locks; the silhouette is the style's own.

uniform uvec2 hide_mask = uvec2(0u, 0u);
uniform float eumelanin : hint_range(0.0, 8.0) = 4.0;
uniform float pheomelanin : hint_range(0.0, 4.0) = 0.4;
uniform float grey : hint_range(0.0, 1.0) = 0.0;
uniform float powder : hint_range(0.0, 1.0) = 0.0;
uniform vec3 accent_color : source_color = vec3(0.11, 0.105, 0.125);
uniform float accent_metal : hint_range(0.0, 1.0) = 0.0;
uniform vec3 metal_color : source_color = vec3(0.78, 0.79, 0.8);
uniform int hair_texture = 0;          // 0 straight, 1 cropped, 2 coily
uniform float strand_contrast : hint_range(0.0, 1.0) = 0.4;
uniform int debug_view = 0;            // 1 regions / hair zones
uniform int stylized = 0;              // 1 painted hair (painted_hair)
uniform float lock_width = 0.022;      // painted locks across the strands (m)

varying flat uint v_region;
varying flat uint v_zone;
varying float v_h;

float h_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float h_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h_hash12(i), h_hash12(i + vec2(1.0, 0.0)), u.x), mix(h_hash12(i + vec2(0.0, 1.0)), h_hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

const float EU_AT[7] = float[7](0.0, 1.0, 2.5, 4.0, 5.5, 7.0, 8.0);
const vec3 EU_COL[7] = vec3[7](vec3(0.8481, 0.6921, 0.4200), vec3(0.4770, 0.2957, 0.1329), vec3(0.1706, 0.0890, 0.0397),
	vec3(0.0550, 0.0272, 0.0134), vec3(0.0196, 0.0116, 0.0072), vec3(0.0072, 0.0060, 0.0054), vec3(0.0035, 0.0035, 0.0044));

vec3 melanin_albedo(float eu, float ph) {
	float e = clamp(eu, 0.0, 8.0);
	vec3 c = EU_COL[6];
	for (int i = 0; i < 6; i++) {
		if (e <= EU_AT[i + 1]) {
			c = mix(EU_COL[i], EU_COL[i + 1], (e - EU_AT[i]) / (EU_AT[i + 1] - EU_AT[i]));
			break;
		}
	}
	return c * exp(-max(ph, 0.0) * vec3(0.12, 0.45, 0.85));
}

bool hair_hidden(uint r) {
	uint bits = r < 32u ? (hide_mask.x >> r) : (hide_mask.y >> (r - 32u));
	return (bits & 1u) != 0u;
}

// Hair albedo of the strand at uv (metres); returns (albedo, strand mask 0..1 in .w).
vec4 strand_albedo(vec2 uv) {
	float across = hair_texture == 2 ? 2600.0 : 1900.0;
	float along = hair_texture == 1 ? 45.0 : (hair_texture == 2 ? 2600.0 : 14.0);
	// wisps: strand groups a few mm wide, individual strands inside them
	// coily hair has no long wisps: its variation is the same in every direction
	float wisp = hair_texture == 2 ? h_noise(uv * 260.0) : h_noise(vec2(uv.x * 260.0, uv.y * 3.0));
	float id = hair_texture == 2 ? floor(h_hash12(floor(uv * 650.0)) * 997.0) : floor(uv.x * across * 0.25 + wisp * 3.0);
	float r = h_hash12(vec2(id, 7.0));
	float n1 = h_noise(vec2(uv.x * across + wisp * 2.0, uv.y * along));
	float eu = eumelanin * (0.85 + 0.3 * r) * (0.9 + 0.2 * wisp);
	vec3 c = melanin_albedo(eu, pheomelanin * (0.85 + 0.3 * h_hash12(vec2(id, 3.0))));
	// grey: a share of the single strands are white (salt and pepper, not stripes)
	float g = step(h_hash12(vec2(floor(uv.x * across), floor(uv.y * 20.0) + 11.0)), grey);
	c = mix(c, vec3(0.58, 0.58, 0.56) * (0.85 + 0.3 * r), g);
	float shade = mix(1.0, 0.7 + 0.6 * n1, strand_contrast) * mix(1.0, 0.8 + 0.4 * wisp, strand_contrast);
	if (hair_texture == 2) {
		shade = mix(1.0, 0.5 + 1.0 * smoothstep(0.25, 0.8, n1), strand_contrast);
	}
	c *= shade;
	c = mix(c, vec3(0.86, 0.85, 0.83) * (0.92 + 0.08 * wisp), powder);
	return vec4(c, n1);
}

// Metres on the head across the strands per metre of u, from the screen derivatives of the view
// position and the UV. The caps' u is an azimuth (x 0.09 m) about the point their strands gather
// to, so it shrinks toward that point and its antipode (the crown whorl).
float hair_across_scale(vec2 uv, vec3 vpos) {
	vec3 px = dFdx(vpos);
	vec3 py = dFdy(vpos);
	vec2 ux = dFdx(uv);
	vec2 uy = dFdy(uv);
	float det = ux.x * uy.y - ux.y * uy.x;
	if (abs(det) < 1e-14) {
		return 1.0;
	}
	return clamp(length((px * uy.y - py * ux.y) / det), 0.02, 2.0);
}

// One painted lock at phase ph (the lock index in floor(ph)): its crest 0..1 (dark grooves between
// the locks, a few long painted strands inside), `slope` the relief across it.
float lock_crest(float ph, float along, out float slope, out float id) {
	id = floor(ph);
	float f = fract(ph);
	slope = cos(3.14159 * f);
	float st = h_noise(vec2(f * 7.0 + id * 13.0, along * 9.0));
	return pow(sin(3.14159 * f), 0.6) * (0.88 + 0.24 * st);
}

// Metres across the strands per metre of u on a cap (the caps' sphere_flow mapping, radius 0.09 m:
// u = azimuth x 0.09 about the point the strands gather to, v = the polar angle from its antipode x
// 0.09, stored as 1 - v by the exporter), so smooth over the cap: the screen-derivative estimate
// (hair_across_scale) is constant per triangle, and on the caps' irregular triangles the lock count
// jumped from one to the next (a shattered look where the strands leave the parting).
float cap_across_scale(vec2 uv) {
	return max(sin(clamp((1.0 - uv.y) / 0.09, 0.0, 3.14159)), 0.02);
}

// Painted hair at uv (metres) for a surface whose model-space normal faces up by `up` (-1..1), at
// the view position vpos. Returns (albedo, lock crest 0..1 in .w); `slope` gets the relief's slope
// across the lock (for the normal). `across`: metres across the strands per metre of u (<= 0: from
// the screen derivatives).
vec4 painted_hair(vec2 uv, float up, vec3 vpos, float across, out float slope) {
	vec3 base = melanin_albedo(eumelanin, pheomelanin);
	float crest;
	float id;
	if (hair_texture == 2) {
		// coily: soft rounded clumps about 1.3 cm across, lit on top, shadowed between
		vec2 q = uv / 0.013;
		vec2 c = floor(q);
		float best = 9.0;
		vec2 bo = vec2(0.0);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 cell = c + vec2(float(i), float(j));
				vec2 o = cell + 0.5 + 0.35 * (vec2(h_hash12(cell), h_hash12(cell + 3.7)) - 0.5);
				float dd = length(q - o);
				if (dd < best) {
					best = dd;
					bo = cell;
				}
			}
		}
		crest = 0.55 + 0.45 * (1.0 - smoothstep(0.2, 0.9, best));
		id = h_hash12(bo) * 97.0;
		slope = 0.0;
	} else {
		// locks about lock_width across. Around a ring of the cap (u spans 2 pi x 0.09 m) their count
		// is a power of two: where the strands gather it halves smoothly (a lock splits in two), so the
		// locks never thin into a star at the crown
		float w = hair_texture == 1 ? lock_width * 0.6 : lock_width;
		float n = 0.5655 * (across > 0.0 ? across : hair_across_scale(uv, vpos)) / w;
		float k = log2(max(n, 2.0));
		float k0 = floor(k);
		float t = smoothstep(0.2, 0.8, k - k0);
		float p0 = uv.x / 0.5655 * exp2(k0);
		float wob = 0.18 * sin(uv.y * 16.0 + floor(p0) * 1.7) + 0.10 * sin(uv.y * 41.0);
		float s0, s1, i0, i1;
		float c0 = lock_crest(p0 + wob, uv.y, s0, i0);
		float c1 = lock_crest(2.0 * (p0 + wob), uv.y, s1, i1);
		crest = mix(c0, c1, t);
		slope = mix(s0, s1, t);
		id = t < 0.5 ? i0 : i1 + 500.0;
		if (across > 0.0) {
			// a cap's strands leave one point (the antipode of their gather point: the front of a
			// parting, the crown whorl): within a few cm of it the locks fade into one smooth painted
			// tone and lose their relief (the mapping turns fast there; the relief read as shards)
			float fade = smoothstep(0.10, 0.45, (1.0 - uv.y) / 0.09);
			crest = mix(0.72, crest, fade);
			slope *= fade;
		}
	}
	float tint = 0.9 + 0.2 * h_hash12(vec2(id, 5.0));
	vec3 c = base * tint * mix(0.5, 1.15, crest);
	// the sheen band where the hair faces up, painted on the crests
	float halo = smoothstep(0.35, 0.7, up) * (1.0 - smoothstep(0.88, 0.99, up));
	vec3 lit = mix(base * 2.4 + vec3(0.05, 0.04, 0.03), vec3(0.62, 0.58, 0.52), 0.25);
	c = mix(c, lit, halo * crest * crest * 0.32);
	// grey: whole painted streaks rather than single strands
	float g = step(h_hash12(vec2(id, 11.0)), grey * 1.1) * (0.7 + 0.3 * crest);
	c = mix(c, vec3(0.62, 0.62, 0.60) * mix(0.6, 1.1, crest), clamp(g, 0.0, 1.0));
	c = mix(c, vec3(0.86, 0.85, 0.83) * (0.85 + 0.15 * crest), powder);
	return vec4(c, crest);
}

vec3 hair_region_color(uint r) {
	float h = fract(float(r) * 0.618034);
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0) * 0.8;
}
