shader_type spatial;
// The matter a Form cast raises (FormMatter; FormModels' meshes: the Earth Wall, the Pillar, Stone Form's spike and ball, the
// rubble a stone wall falls into; the user, 2026-10-03: "it should be earth wall where if the terrain is mud its a mud wall if
// its a tree i can make a tree wall you know", "we need to work on the textures"). Our own procedural surfaces, no textures:
// 3D noise in the mesh's own space (the pattern rides on the thing as it rises, rolls or is hurled), its relief given to the
// light by the noise's screen-space slope (no normal map). One material per look (FormMatter.material, the colours and
// numbers from data/sway/moves.json earth_wall.wall.materials), each thing its own `seed` (an instance uniform). `look`:
//   0 rock    weathered fieldstone: mottled greys, a fine grain of crystals, hairline fractures, lichen on the old faces;
//             freshly broken faces (the mesh's vertex alpha) lighter and clean. `stones` > 0: grey fieldstones packed together
//             with dark earth in the joints (the stone wall). `top_k`: the ground's matter (col_foot: snow) on its tops
//   1 earth   rammed earth in courses with fieldstones set in it, the foot darker and damp, turf on the top (`top_k`)
//   2 mud     wet dark mud, smoothed and slumping: drying paler in patches, streaks run down it, a wet sheen (`wet`), grit
//   3 snow    packed snow over the earth: blue-white, its packed blocks' seams faint, sparkling a little; the earth's foot
//   4 wood    split and hewn wood: pale, its grain along the log (the bark is the tree's own texture, not this)
// The vertex colour's rgb darkens (the meshes' hollows), its alpha is how fresh a face is. The foot (`foot_h` m over the
// ground, the mesh's y 0) takes the ground's stain. Under the trees it takes the forest's light as the terrain does
// (shaders/common/canopy.gdshaderinc: the sky light the crowns take away, the green-gold they scatter down; neutral where
// there is no ForestLight). Cheap: a few octaves of value noise and one cell noise a pixel.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/common/canopy.gdshaderinc"

uniform int look = 0;
uniform vec3 col_a : source_color = vec3(0.45, 0.44, 0.42);     // the main tone
uniform vec3 col_b : source_color = vec3(0.58, 0.57, 0.54);     // its mottle
uniform vec3 col_c : source_color = vec3(0.17, 0.15, 0.13);     // creases, joints, the dark of the wet
uniform vec3 col_d : source_color = vec3(0.52, 0.54, 0.40);     // lichen / turf / grit / the snow's blue / the grain's dark
uniform vec3 col_fresh : source_color = vec3(0.74, 0.72, 0.68); // a freshly broken face (rock), a fresh cut (wood)
uniform vec3 col_foot : source_color = vec3(0.27, 0.21, 0.15);  // the ground's stain at the foot
uniform float foot_h = 0.3;
uniform float scale = 1.0;
uniform float rough = 0.9;
uniform float bump = 1.0;
uniform float wet = 0.0;
uniform float stones = 0.0;
uniform float top_k = 0.0;
instance uniform float seed = 0.0;

varying vec3 v_obj;
varying vec3 v_onrm;
varying vec3 v_world;
varying float v_wny;

float h13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 h33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = p - i;
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h13(i), h13(i + vec3(1.0, 0.0, 0.0)), u.x), mix(h13(i + vec3(0.0, 1.0, 0.0)), h13(i + vec3(1.0, 1.0, 0.0)), u.x), u.y);
	float b = mix(mix(h13(i + vec3(0.0, 0.0, 1.0)), h13(i + vec3(1.0, 0.0, 1.0)), u.x), mix(h13(i + vec3(0.0, 1.0, 1.0)), h13(i + vec3(1.0, 1.0, 1.0)), u.x), u.y);
	return mix(a, b, u.z);
}

float fbm3(vec3 p) {
	return vnoise(p) * 0.5 + vnoise(p * 2.03 + vec3(17.1, 3.7, 9.2)) * 0.3 + vnoise(p * 4.11 + vec3(5.3, 11.9, 2.1)) * 0.2;
}

float fbm2(vec3 p) {
	return vnoise(p) * 0.62 + vnoise(p * 2.17 + vec3(7.7, 1.3, 4.9)) * 0.38;
}

// The nearest two cell points' distances (F1, F2) and a hash of the nearest's cell.
vec3 cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = p - i;
	float d1 = 9.0;
	float d2 = 9.0;
	float id = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 r = g + h33(i + g) - f;
				float d = dot(r, r);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = h13(i + g + vec3(7.31, 2.17, 5.53));
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec3(sqrt(d1), sqrt(d2), id);
}

// A height field's relief on the normal (view space), from its screen-space slope (Mikkelsen's bump mapping).
vec3 bumped(vec3 n, vec3 pos, float h, float k) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	return normalize(abs(det) * n - k * grad);
}

void vertex() {
	v_obj = VERTEX;
	v_onrm = NORMAL;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wny = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	vec3 s3 = vec3(seed * 3.17, seed * 1.91, seed * 2.53);
	vec3 p = v_obj * scale + s3;
	// how fine a detail the pixel still holds (high frequencies fade with distance, no shimmer)
	float px = length(fwidth(v_obj)) * scale;
	float fine = clamp(1.0 - px * 9.0, 0.0, 1.0);
	float fresh = clamp(COLOR.a, 0.0, 1.0);
	float up = smoothstep(0.55, 0.85, normalize(v_onrm).y);
	vec3 alb = col_a;
	float h = 0.0;
	float rgh = rough;
	float spec = 0.5;
	if (look == 0) {
		// rock: mottled, stained broadly by the weather, a grain of dark and pale crystals
		float m = fbm3(p * 1.3);
		float big = fbm2(p * 0.45 + 7.0);
		alb = mix(col_a, col_b, smoothstep(0.28, 0.72, m)) * (0.7 + 0.5 * big);
		// its bedding: faint strata across it
		float bands = vnoise(vec3(p.x * 0.6, p.y * 6.0 + m * 1.6, p.z * 0.6));
		alb *= 0.86 + 0.24 * bands;
		float grain = vnoise(p * 31.0);
		float spk = vnoise(p * 71.0 + 3.0);
		alb *= mix(1.0, 0.76 + 0.48 * grain, fine);
		alb *= 1.0 - 0.45 * smoothstep(0.72, 0.9, spk) * fine;
		alb *= 1.0 + 0.3 * smoothstep(0.74, 0.92, 1.0 - spk) * fine;
		h = m * 0.016 + bands * 0.004 + grain * 0.003 * fine;
		if (stones > 0.0) {
			// fieldstones packed together: irregular (the cells' space warped), flatter than tall, each its own grey or
			// a warmer one, rounded, dark earth in the uneven joints
			vec3 w = vec3(fbm2(p * 1.9), fbm2(p * 1.9 + 5.0), fbm2(p * 1.9 + 9.0)) - 0.5;
			vec3 c = cells(vec3(p.x * 3.0, p.y * 4.3, p.z * 3.0) + w * 0.8);
			float edge = c.y - c.x;
			float jw = 0.04 + 0.07 * vnoise(p * 3.0 + 1.0);
			float joint = 1.0 - smoothstep(jw * 0.6, jw * 1.7, edge);
			float dome = 1.0 - pow(1.0 - smoothstep(0.0, 0.55, edge), 2.0);
			float ht = h13(vec3(c.z * 91.0, 3.0, 7.0));
			vec3 own = mix(col_a, col_b, c.z) * (0.72 + 0.5 * ht);
			own *= mix(vec3(1.0), vec3(1.07, 1.0, 0.88), step(0.72, fract(c.z * 7.0)));
			alb = mix(alb, own * (0.8 + 0.35 * m) * (0.85 + 0.3 * big), stones);
			alb = mix(alb, col_c * (0.75 + 0.5 * grain), joint * stones);
			h += (dome * 0.03 - joint * 0.016) * stones;
			rgh = mix(rgh, 1.0, joint * stones);
		} else {
			// fractures: long ones here and there, and a finer craze
			vec3 c = cells(p * 1.4);
			float crack = (1.0 - smoothstep(0.0, 0.03, c.y - c.x)) * smoothstep(0.48, 0.62, fbm2(p * 0.8 + 3.0));
			vec3 c2 = cells(p * 3.4 + 11.0);
			crack = max(crack, (1.0 - smoothstep(0.0, 0.025, c2.y - c2.x)) * smoothstep(0.55, 0.7, fbm2(p * 1.4 + 6.0)) * 0.7);
			alb = mix(alb, col_c, crack * 0.8);
			h -= crack * 0.01;
		}
		// lichen and old weathering on the faces that were not broken fresh
		float lich = smoothstep(0.62, 0.74, fbm2(p * 2.6 + 11.0)) * (1.0 - fresh) * 0.45;
		alb = mix(alb, col_d * (0.85 + 0.3 * grain), lich);
		float fr = fresh * (0.6 + 0.4 * vnoise(p * 6.0));
		alb = mix(alb, col_fresh * (0.88 + 0.24 * grain) * (0.9 + 0.2 * bands), fr * 0.55);
		rgh = mix(rgh, rgh - 0.06, fr);
		// the ground's matter caught on its tops (snow): the foot's colour
		alb = mix(alb, col_foot, up * top_k * smoothstep(0.35, 0.6, fbm2(p * 3.0 + 2.0) + up * 0.3));
	} else if (look == 1) {
		// rammed earth in courses, stained broadly, fieldstones set in it, turf on top
		float m = fbm3(p * 1.6);
		float big = fbm2(p * 0.5 + 3.0);
		alb = mix(col_a, col_b, smoothstep(0.3, 0.72, m)) * (0.82 + 0.32 * big);
		float course = vnoise(vec3(p.x * 0.9, v_obj.y * 9.0 + m * 2.5, p.z * 0.9));
		alb *= 0.9 + 0.16 * course;
		float grit = vnoise(p * 27.0);
		alb *= mix(1.0, 0.86 + 0.28 * grit, fine);
		h = m * 0.014 + course * 0.004 + grit * 0.002 * fine;
		// fieldstones set in it: ragged, of all sizes, stained by the earth they were packed in
		vec3 w = vec3(fbm2(p * 1.6), fbm2(p * 1.6 + 4.0), fbm2(p * 1.6 + 8.0)) - 0.5;
		vec3 c = cells(vec3(p.x * 1.9, p.y * 2.6, p.z * 1.9) + w * 0.9);
		float is_stone = step(1.0 - stones, c.z);
		float r = 0.2 + 0.16 * h13(vec3(c.z * 13.0, 1.0, 1.0));
		float cx = c.x + (vnoise(p * 7.0) - 0.5) * 0.09;
		float stone = (1.0 - smoothstep(r - 0.04, r, cx)) * is_stone;
		float rim = (smoothstep(r - 0.07, r - 0.01, cx) - smoothstep(r, r + 0.06, cx)) * is_stone;
		vec3 sc = mix(alb, col_c, 0.65) * (0.72 + 0.4 * h13(vec3(c.z * 57.0, 1.0, 2.0))) * (0.85 + 0.3 * grit);
		alb = mix(alb, sc, stone);
		alb *= 1.0 - 0.25 * rim;
		h += stone * 0.016 * (1.0 - cx / r) - rim * 0.004;
		rgh = mix(rgh, 0.9, stone);
		float turf = up * top_k * smoothstep(0.35, 0.55, fbm2(p * 3.0 + 5.0) + up * 0.25);
		alb = mix(alb, col_d * (0.7 + 0.55 * grit), turf);
		h += turf * grit * 0.006;
		rgh = mix(rgh, 0.98, turf);
	} else if (look == 2) {
		// wet mud: slumping, drier and matte up top and in patches, runs down it, smears across, clods, a little grit
		float m = fbm3(p * 1.1);
		float big = fbm2(p * 0.6 + 2.0);
		float dry = smoothstep(0.55, 0.78, fbm2(p * 1.3 + 4.0) + (v_obj.y - 0.9) * 0.22);
		alb = mix(col_a, col_b, dry * 0.8) * (0.85 + 0.3 * big);
		float run = vnoise(vec3(p.x * 5.0, p.y * 0.5 + m * 1.2, p.z * 5.0));
		alb = mix(alb, col_c, smoothstep(0.62, 0.9, run) * 0.3 * (1.0 - dry));
		float smear = vnoise(vec3(p.x * 1.3, p.y * 9.0 + m * 3.0, p.z * 1.3));
		alb *= 0.9 + 0.16 * smear;
		float clod = vnoise(p * 9.0);
		alb *= 0.88 + 0.24 * clod;
		float grit = vnoise(p * 34.0);
		alb = mix(alb, col_d, smoothstep(0.92, 0.98, grit) * fine * 0.25);
		h = m * 0.035 + run * 0.004 + smear * 0.005 + clod * 0.007;
		// (a soft sheen, not a mirror: the sun and sky in a glossier one, at a low look, washed the dark wall pale blue)
		float wetness = wet * (1.0 - dry) * smoothstep(0.38, 0.72, m + run * 0.3);
		rgh = mix(rough, 0.62, wetness);
		spec = 0.3;
		alb *= 1.0 - 0.15 * wetness;
	} else if (look == 3) {
		// packed snow: blocks pressed together, their seams faint, a little sparkle
		float m = fbm3(p * 1.4);
		alb = mix(col_a, col_b, smoothstep(0.35, 0.7, m));
		vec3 c = cells(vec3(p.x * 1.6, p.y * 2.4, p.z * 1.6) + (vec3(fbm2(p * 2.0), fbm2(p * 2.0 + 3.0), 0.0) - 0.5) * 0.6);
		float seam = 1.0 - smoothstep(0.01, 0.06, c.y - c.x);
		alb = mix(alb, col_d, seam * 0.22);
		alb *= 0.94 + 0.1 * vnoise(vec3(p.x * 1.0, v_obj.y * 7.0 + m, p.z * 1.0));
		float spark = step(0.985, h13(floor(v_obj * 160.0) + s3)) * fine;
		alb += vec3(spark * 0.35);
		h = m * 0.01 - seam * 0.006;
		rgh = rough - 0.08 * m;
	} else {
		// split, hewn wood: the grain along the log, a fresh cut paler
		float g = fbm3(vec3(p.x * 7.0, p.y * 0.45, p.z * 7.0));
		float line = 0.5 + 0.5 * sin(g * 38.0);
		alb = mix(col_a, col_b, smoothstep(0.25, 0.75, g));
		alb = mix(alb, col_d, smoothstep(0.7, 0.95, line) * 0.45 * fine);
		alb = mix(alb, col_fresh, fresh * 0.6);
		h = line * 0.002 * fine + g * 0.004;
	}
	// the ground's stain at the foot, its edge ragged
	if (foot_h > 0.0) {
		float edge = foot_h * (0.65 + 0.7 * vnoise(p * 2.2 + 9.0));
		float foot = 1.0 - smoothstep(edge * 0.4, edge, v_obj.y);
		alb = mix(alb, col_foot * (0.85 + 0.3 * vnoise(p * 9.0)), foot * (1.0 - fresh * 0.6));
		rgh = mix(rgh, min(rgh + 0.05, 1.0), foot);
	}
	ALBEDO = clamp(alb * COLOR.rgb, vec3(0.0), vec3(1.0));
	ROUGHNESS = clamp(rgh, 0.05, 1.0);
	SPECULAR = spec;
	NORMAL = bumped(NORMAL, VERTEX, h, bump);
	// the forest's light (the crowns' cover over it; a stone hurled high above them is in the open)
	float cc = canopy_cover(v_world.xz);
	AO = canopy_sky_factor(cc, 1.0);
	AO_LIGHT_AFFECT = 0.0;
	EMISSION = ALBEDO * canopy_scatter(cc, 1.0, v_wny);
}
