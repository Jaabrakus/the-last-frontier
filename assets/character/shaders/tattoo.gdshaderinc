// Tattoos on the skin (Tattoos, data/customizer/tattoos.json; skin.gdshader includes this before its stubble).
//
// Each tattoo is a design of the atlas (assets/character/tattoos/tattoo_atlas.png: a 4 x 4 grid of ink coverage),
// drawn where the skin's region is one of its place's and the design's square covers the fragment. The square is
// laid in the place's coordinates, which follow the skin through every pose and body shape:
//   space 0  the metre UVs (u, height): limbs, hands, neck (lib/uv.py: cylinders round each limb, planes on the hands)
//   space 1  the torso's front: (arc length along the body's horizontal ring from the front centre, height)
//   space 2  the torso's back: the same from the back centre (the arc map `tattoo_arc`: R front, G back; the torso's
//            metre-UV cylinder sits far in front of the spine, so u alone pinched a chest design at the sternum)
//   space 3  MakeHuman's UVs (CUSTOM0): the face, where the metre UVs' cylinder also covers the mouth's inner skin
// With d the step from the place's centre (wrapped round a limb: `wrap` is its UV circumference), the design's square
// coordinates are q = M d + b (Tattoos: the place's measured frame, the tattoo's offset, size and turn), |q| < 0.5.
// A repeating design (bands, dots) tiles round the limb instead: q.x from the fraction of the way round.
// `side` (hands: the planar UVs cover the palm too): the sign of the UV frame's handedness on the back of the hand;
// fragments of the other sign (the palm) draw nothing.
// The ink lies under the epidermis: where it covers, the skin takes the pigment's own hue as the epidermis shows it
// (the black heals blue-grey), darker under a darker skin's melanin (a dark skin shows it less) and never lighter
// than the skin; spread and lightened with age (`fade`, set by Tattoos: the coverage's least mip level, the density and a
// green-blue drift). `ink` returns the coverage: skin.gdshader scatters less light under it (the pigment absorbs
// what the dermis would scatter, and the screen-space scattering had washed the lines pink).
// Covered skin collapses (hide_mask), so a tattoo under a sleeve is never drawn.
uniform int tat_count = 0;
uniform vec4 tat_m[8];      // M: (m00, m01, m10, m11), q = M d + b
uniform vec4 tat_b[8];      // (b.x, b.y, centre.x, centre.y)
uniform vec4 tat_p[8];      // (space, wrap, regions 0-15 bits, regions 16-31 bits)
uniform vec4 tat_s[8];      // (atlas cell, side, repeat tiles round the limb (0: none), repeat crop)
uniform vec4 tat_ink[8];    // (the pigment's hue rgb, density)
uniform vec4 tat_e[8];      // (the ink's spread: the least mip level, -, -, -)
uniform sampler2D tattoo_atlas : hint_default_black, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D tattoo_arc : hint_default_black, filter_linear, repeat_enable;
uniform vec4 tattoo_arc_rect = vec4(-0.408407, 0.816814, 0.93, 1.26);   // u0, u span, height 0, height 1
uniform vec2 tattoo_arc_n = vec2(96.0, 41.0);

const float TAT_GRID = 4.0;

// The skin's colour under the tattoos at this fragment. `uv` the metre UVs (UV), `mh` MakeHuman's (CUSTOM0), `vtx` and
// `nrm` the view-space position and normal (the hand's side test); `ink` the ink's coverage here (0..1).
vec3 tattoo_skin(vec3 albedo, vec2 uv, vec2 mh, uint region, vec3 vtx, vec3 nrm, out float ink) {
	ink = 0.0;
	if (tat_count <= 0 || region >= 32u) {
		return albedo;
	}
	// only fragments of a tattooed region pay for the rest (a region is uniform over a triangle: the derivatives below
	// stay in uniform control flow)
	bool any_here = false;
	for (int i = 0; i < 8; i++) {
		if (i >= tat_count) {
			break;
		}
		uint bits = region < 16u ? (uint(tat_p[i].z) >> region) : (uint(tat_p[i].w) >> (region - 16u));
		any_here = any_here || (bits & 1u) != 0u;
	}
	if (!any_here) {
		return albedo;
	}
	vec2 raw = vec2(uv.x, 1.0 - uv.y);
	vec2 raw_dx = dFdx(raw);
	vec2 raw_dy = dFdy(raw);
	vec2 mh_dx = dFdx(mh);
	vec2 mh_dy = dFdy(mh);
	// the torso's arc coordinates (front, back), on the torso's regions only
	vec2 arc = vec2(0.0);
	vec2 arc_dx = vec2(0.0);
	vec2 arc_dy = vec2(0.0);
	if (region >= 2u && region <= 11u) {
		float span = tattoo_arc_rect.y;
		float uu = raw.x - span * round(raw.x / span);
		float ty = clamp((raw.y - tattoo_arc_rect.z) / (tattoo_arc_rect.w - tattoo_arc_rect.z), 0.0, 1.0);
		vec2 tc = vec2((uu - tattoo_arc_rect.x) / span, (ty * (tattoo_arc_n.y - 1.0) + 0.5) / tattoo_arc_n.y);
		arc = textureLod(tattoo_arc, tc, 0.0).rg;
		arc_dx = dFdx(arc);
		arc_dy = dFdy(arc);
	}
	// the metre UVs' handedness here (convention-free: the screen's orientation cancels out)
	float cell_px = float(textureSize(tattoo_atlas, 0).x) / TAT_GRID;
	float hand = sign((raw_dx.x * raw_dy.y - raw_dy.x * raw_dx.y) * dot(cross(dFdx(vtx), dFdy(vtx)), nrm));
	vec3 col = albedo;
	float lum = dot(albedo, vec3(0.2126, 0.7152, 0.0722));
	for (int i = 0; i < 8; i++) {
		if (i >= tat_count) {
			break;
		}
		vec4 p = tat_p[i];
		uint bits = region < 16u ? (uint(p.z) >> region) : (uint(p.w) >> (region - 16u));
		if ((bits & 1u) == 0u) {
			continue;
		}
		vec4 s = tat_s[i];
		if (s.y != 0.0 && hand != s.y) {
			continue;
		}
		int space = int(p.x + 0.5);
		vec2 c = space == 1 ? vec2(arc.x, raw.y) : (space == 2 ? vec2(arc.y, raw.y) : (space == 3 ? mh : raw));
		vec2 cdx = space == 1 ? vec2(arc_dx.x, raw_dx.y) : (space == 2 ? vec2(arc_dx.y, raw_dx.y) : (space == 3 ? mh_dx : raw_dx));
		vec2 cdy = space == 1 ? vec2(arc_dy.x, raw_dy.y) : (space == 2 ? vec2(arc_dy.y, raw_dy.y) : (space == 3 ? mh_dy : raw_dy));
		vec2 d = c - tat_b[i].zw;
		if (p.y > 0.0) {
			d.x -= p.y * round(d.x / p.y);
		}
		mat2 m = mat2(vec2(tat_m[i].x, tat_m[i].z), vec2(tat_m[i].y, tat_m[i].w));
		vec2 q = m * d + tat_b[i].xy;
		vec2 qdx = m * cdx;
		vec2 qdy = m * cdy;
		if (s.z > 0.0 && p.y > 0.0) {
			// round the limb: s.z whole tiles, each cropped to s.w of the design's width
			float k = s.z / p.y;
			q.x = (fract(d.x * k + 0.5) - 0.5) * s.w;
			qdx.x = cdx.x * k * s.w;
			qdy.x = cdy.x * k * s.w;
		}
		if (abs(q.x) >= 0.5 || abs(q.y) >= 0.5) {
			continue;
		}
		vec2 cell = vec2(mod(s.x, TAT_GRID), floor(s.x / TAT_GRID));
		vec2 auv = (cell + vec2(q.x + 0.5, 0.5 - q.y)) / TAT_GRID;
		// the mip level: the pixel's footprint in the cell, or the ink's spread under the skin when that is wider
		// (tat_e.x, in levels of the cell's texels), at most a 16 px cell (the margins hold the neighbours off)
		vec2 gx = qdx * cell_px;
		vec2 gy = qdy * cell_px;
		float lod = clamp(max(0.5 * log2(max(max(dot(gx, gx), dot(gy, gy)), 1e-8)), tat_e[i].x), 0.0, 4.0);
		float a = clamp(textureLod(tattoo_atlas, auv, lod).r * tat_ink[i].a, 0.0, 1.0);
		// (the pigment's hue at half strength under a light skin, darker with the skin's own melanin over it)
		vec3 seen = min(tat_ink[i].rgb * min(1.6 * lum + 0.02, 0.5), albedo);
		col = mix(col, seen, a);
		ink = max(ink, a);
	}
	return col;
}
