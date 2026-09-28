// Facial hair styles and face markings of the character creator, shared by skin.gdshader
// (painted: the short hair and the skin under a beard, scars, pox, paint) and
// beard_shell.gdshader (the beard's volume).
//
// Coordinates: the head's UVs (body.glb "UVMap", lib/uv.py: a cylinder about the vertical axis
// through headb, radius 0.08 m) give u = UV.x = arc length (m) around the head, 0 at the face
// front, + toward the character's left, and h = 1 - UV.y = height (m) of the bind pose. They
// are attached to the skin, so the styles and marks follow every face shape. On the face
// front the arc is about 0.67 of the true width (the face lies outside the 0.08 m cylinder).
// Landmarks of the v2 head (measured on its body.glb; the v3 head is warped onto them, below): lip vermilion h 1.411-1.430 at
// |u| < 0.0125, nose base h 1.442, chin h 1.345-1.41, ear u 0.105-0.15 at h 1.433-1.545,
// cheek centre (+-0.032, 1.452), eye centre (+-0.023, 1.483), brow about h 1.50-1.51.
// COLOR.a is the body's beard mask (jaw, chin, upper lip and under the jaw, not the lips or
// the high cheeks), COLOR.g the mucosa (lip vermilion).

// The head v3 (2026-09-27, the MakeHuman head): the regions and marks below were drawn on the v2
// head's landmarks; face_coords() warps the v3 head's coordinates onto them, piecewise linear
// between matching landmarks (body.json face.warp, set by BodyMaterials.set_face_warp): h knots
// menton, lower lip border, stomion, upper lip border, subnasale, eye centre, brow, forehead;
// |u| knots mouth corner, cheek centre, ear front, far side. The defaults are the v2 head's own
// (no warp).
uniform vec4 fd_h0 = vec4(1.3733, 1.4113, 1.42045, 1.4296);
uniform vec4 fd_h1 = vec4(1.442, 1.4838, 1.5238, 1.5838);
uniform vec4 fd_u = vec4(0.0206, 0.032, 0.105, 0.25);

float fd_warp_h(float h) {
	float k[8] = float[8](fd_h0.x, fd_h0.y, fd_h0.z, fd_h0.w, fd_h1.x, fd_h1.y, fd_h1.z, fd_h1.w);
	float t[8] = float[8](1.3733, 1.4113, 1.42045, 1.4296, 1.442, 1.4838, 1.5238, 1.5838);
	if (h <= k[0]) {
		return t[0] + (h - k[0]);
	}
	for (int i = 1; i < 8; i++) {
		if (h <= k[i]) {
			return mix(t[i - 1], t[i], (h - k[i - 1]) / max(k[i] - k[i - 1], 1e-6));
		}
	}
	return t[7] + (h - k[7]);
}

float fd_warp_u(float au) {
	float k[5] = float[5](0.0, fd_u.x, fd_u.y, fd_u.z, fd_u.w);
	float t[5] = float[5](0.0, 0.0206, 0.032, 0.105, 0.25);
	for (int i = 1; i < 5; i++) {
		if (au <= k[i]) {
			return mix(t[i - 1], t[i], (au - k[i - 1]) / max(k[i] - k[i - 1], 1e-6));
		}
	}
	return t[4] + (au - k[4]);
}

vec2 face_coords(vec2 uv) {
	vec2 fc = vec2(uv.x, 1.0 - uv.y);
	return vec2(sign(fc.x) * fd_warp_u(abs(fc.x)), fd_warp_h(fc.y));
}

// 1 inside [a, b], feathered by f
float fd_band(float x, float a, float b, float f) {
	return smoothstep(a - f, a + f, x) * (1.0 - smoothstep(b - f, b + f, x));
}

// The four regions of a facial hair style (weights 0..1): x moustache (upper lip, drooping
// to the mouth corners), y chin (below the lower lip, under the chin), z jaw and cheeks (the
// beard mask raised toward the ears; it covers the lip and chin too, see beard_mask), w side
// whiskers (in front of the ears).
vec4 beard_regions(vec2 fc, float beard_a, float mucosa) {
	float au = abs(fc.x);
	float h = fc.y;
	float lip_top = 1.4296 - 18.0 * au * au;             // vermilion border, 1.427 at |u| 0.012
	float lip_bottom = 1.4113 + 25.0 * au * au;
	float mo = fd_band(au, -1.0, 0.0165, 0.0025) * fd_band(h, lip_top + 0.0012, 1.4412, 0.0011);
	mo = max(mo, fd_band(au, 0.0115, 0.0205, 0.0022) * fd_band(h, 1.4165, 1.437, 0.0022));
	float not_lip = 1.0 - smoothstep(0.15, 0.6, mucosa);
	mo *= not_lip;
	float ch = fd_band(au, -1.0, 0.021, 0.004) * fd_band(h, 1.338, lip_bottom - 0.0016, 0.0018) * not_lip;
	// the cheeks up to the side whiskers: the beard mask, raised toward the ears
	float line = 1.438 + 0.32 * max(au - 0.03, 0.0);
	float cheek = fd_band(au, 0.03, 0.112, 0.006) * (1.0 - smoothstep(line - 0.003, line + 0.003, h)) * step(1.40, h);
	float jaw = max(beard_a, cheek) * not_lip;
	float sb = fd_band(au, 0.083, 0.109, 0.0035) * fd_band(h, 1.434, 1.506, 0.004);
	return vec4(mo, ch, jaw, sb);
}

// Coverage of a style (region weights 0 or 1 in `style`): the strongest of its regions. The
// jaw region leaves out the upper lip when the style has no moustache and the chin when it has
// no chin beard (a beard without moustache, side whiskers into the jaw).
float beard_mask(vec2 fc, vec4 regions, vec4 style) {
	float au = abs(fc.x);
	float lip_bottom = 1.4113 + 25.0 * au * au;
	float mo_zone = fd_band(au, -1.0, 0.024, 0.003) * fd_band(fc.y, 1.414, 1.446, 0.002);
	float ch_zone = fd_band(au, -1.0, 0.025, 0.004) * fd_band(fc.y, 1.30, lip_bottom, 0.002);
	float jaw = regions.z * (1.0 - mo_zone * (1.0 - style.x)) * (1.0 - ch_zone * (1.0 - style.y));
	vec4 r = vec4(regions.x, regions.y, jaw, regions.w) * style;
	return max(max(r.x, r.y), max(r.z, r.w));
}

// Face marks. Returns (albedo multiplier rgb, relief in a): scars `scar` 1 through the left
// brow, 2 across the right cheek, 3 through the upper lip, left of centre; `pox` pitting over
// the face; `paint` a round vermilion spot on each cheek (mixed toward `paint_col`).
float fd_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float fd_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 w = f * f * (3.0 - 2.0 * f);
	return mix(mix(fd_hash(i), fd_hash(i + vec2(1.0, 0.0)), w.x), mix(fd_hash(i + vec2(0.0, 1.0)), fd_hash(i + vec2(1.0, 1.0)), w.x), w.y);
}

// distance (m, true width on the face front) from p to the segment a-b
float fd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 k = vec2(1.45, 1.0);
	vec2 pa = (p - a) * k;
	vec2 ba = (b - a) * k;
	float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * t);
}

// .x scar amount (0..1: the scar's middle; its margin is where 0 < x < 0.5), .y pox pit
// profile (1 at a pit's centre, falling to 0 at its rim), .z paint (0..1)
vec3 face_marks(vec2 fc, int scar, float pox, float paint) {
	vec3 m = vec3(0.0);
	if (scar > 0) {
		vec2 a = scar == 1 ? vec2(0.017, 1.524) : (scar == 2 ? vec2(-0.029, 1.471) : vec2(0.0055, 1.4435));
		vec2 b = scar == 1 ? vec2(0.028, 1.488) : (scar == 2 ? vec2(-0.047, 1.436) : vec2(0.0035, 1.4155));
		float w = scar == 2 ? 0.0028 : 0.0022;
		float d = fd_segment(fc, a, b);
		// an irregular edge and a narrower, fading end
		float t = clamp(dot((fc - a) * vec2(1.45, 1.0), (b - a) * vec2(1.45, 1.0)) / dot((b - a) * vec2(1.45, 1.0), (b - a) * vec2(1.45, 1.0)), 0.0, 1.0);
		// (smoothstep needs edge0 < edge1: a reversed one is undefined in GLSL and gave 0 on Metal)
		w *= (0.75 + 0.5 * fd_noise(fc * 900.0)) * (1.0 - 0.6 * smoothstep(0.7, 1.0, t)) * (0.5 + 0.5 * smoothstep(0.0, 0.25, t));
		m.x = 1.0 - smoothstep(w * 0.55, w, d);
	}
	if (pox > 0.001) {
		// pits about 1-2 mm across on a 4.5 mm grid, denser on the cheeks and forehead
		vec2 q = fc * vec2(1.45, 1.0) / 0.0045;
		vec2 c = floor(q);
		float best = 1.0;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 cell = c + vec2(float(i), float(j));
				if (fd_hash(cell + 17.0) > 0.55) {
					continue;
				}
				vec2 o = cell + vec2(fd_hash(cell), fd_hash(cell + 5.3));
				float r = 0.2 + 0.22 * fd_hash(cell + 9.1);
				best = min(best, length(q - o) / r);
			}
		}
		float face = fd_band(abs(fc.x), -1.0, 0.075, 0.01) * fd_band(fc.y, 1.39, 1.56, 0.01);
		m.y = (1.0 - smoothstep(0.3, 1.0, best)) * face * pox;
	}
	if (paint > 0.001) {
		vec2 d = (vec2(abs(fc.x), fc.y) - vec2(0.031, 1.452)) * vec2(1.45, 1.0);
		float r = 0.0085 * (0.92 + 0.16 * fd_noise(fc * 600.0));
		m.z = (1.0 - smoothstep(r * 0.8, r, length(d))) * paint;
	}
	return m;
}
