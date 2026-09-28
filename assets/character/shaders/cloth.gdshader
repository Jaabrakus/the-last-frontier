// Cloth of the player's outfit and of every customizer garment (customizer design 8.3): real
// fabric scans, tinted, with wear, dirt and sweat where clothes get them.
//
// Colours (tint0..3, band_color, dirt_color) are LINEAR vec4s: ClothMaterials.lin4() converts the
// palette's sRGB and passes a Vector4, which the engine never converts again.
// One surface, up to 4 zones (UV2.x = region + 64 * zone). Per zone: a fabric layer of the
// kit arrays (assets/character/fabrics: LIN WOOL TWILL KNIT SUEDE LEA FUR HES FLAT, made by
// tools/character/make_fabrics.py from CC0 Poly Haven scans), a tint (linear), the tile size
// in metres (UV is metres along the grain), detail / normal strength, roughness, metal flag,
// sheen and a wear mode. The scan's luminance only modulates the tint (design 8.2), so the
// cloth keeps its period colour at any distance.
// Attributes (tools/character/cloth_bake.py writes the last three into every character glb):
//   UV        metres along the grain            UV2.x  region + 64 * zone (hide_mask)
//   COLOR.rgb baked shading multiplier (lining, pleat valleys, hem bands)
//   CUSTOM0   x = distance to the hem, y = to the opening (m), z = dirt, w = wear (0..1)
//   CUSTOM1   x = sweat (0..1), y = push class of the legacy gear (0 none, 1..2 belt -> strap
//             along NORMAL, 3 rigid along TANGENT), moved out by push_m over a thicker coat,
//             z = distance to the sewn seams (m; 0.2 = none)
//   CUSTOM2   x = cavity (-1 ridge .. +1 fold valley), y = compression-fold zones (0..1)
// The normal map uses a derivative (cotangent) frame, so no tangents are needed; TANGENT carries
// the rigid gear's push direction instead.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform uvec2 hide_mask = uvec2(0u, 0u);
uniform sampler2DArray fabric_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray fabric_normal : filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 tint0 = vec4(0.21, 0.17, 0.13, 1.0);
uniform vec4 tint1 = vec4(0.21, 0.17, 0.13, 1.0);
uniform vec4 tint2 = vec4(0.21, 0.17, 0.13, 1.0);
uniform vec4 tint3 = vec4(0.21, 0.17, 0.13, 1.0);
uniform vec4 layer = vec4(1.0);              // fabric layer per zone
uniform vec4 tile_m = vec4(0.274);           // physical tile size (m) per zone
uniform vec4 detail_strength = vec4(0.7);
uniform vec4 normal_strength = vec4(0.5);
uniform vec4 roughness_mul = vec4(1.0);
uniform vec4 metal = vec4(0.0);
uniform vec4 sheen = vec4(0.2);              // rim fuzz (wool nap, felt, fur)
uniform vec4 wear_mode = vec4(0.0);          // 0 cloth, 1 leather, 2 metal, 3 fur base, 4 horn / wood
// hem stripes (capot, blanket): rows of band_color by the hem distance CUSTOM0.x, zone 0
uniform vec4 band_color = vec4(0.013, 0.024, 0.07, 1.0);
uniform vec4 band_rows = vec4(0.0);          // (count, first offset m, width m, gap m)
// age of the whole garment and the mask strengths
uniform float dirt_amount : hint_range(0.0, 2.0) = 1.2;
uniform float wear_amount : hint_range(0.0, 2.0) = 1.3;
uniform float sweat_amount : hint_range(0.0, 2.0) = 1.0;
uniform vec4 dirt_color = vec4(0.045, 0.031, 0.019, 1.0);  // linear (sRGB #3c3126, dry earth)
uniform float macro_var : hint_range(0.0, 0.3) = 0.14;    // large-scale fading / felting blotches
uniform float seed = 0.0;                    // per garment: its noise differs from the others'
uniform float hem_width = 0.018;             // m: the turned hem's stitch line (0 = none)
uniform float character = 1.0;               // strength of the fabric's mid-scale character (below)
uniform float fold_amount = 1.0;             // compression folds at the elbows, knees, waist
uniform float cavity_amount = 1.0;           // fold valleys shaded, ridges worn
uniform float dust_amount : hint_range(0.0, 1.0) = 0.35;  // dust on up-facing cloth
uniform vec4 push_m = vec4(0.0);             // legacy gear over a thicker coat: belt, strap, rigid
uniform float inflate = 0.0;                 // m out along the normal: a wrap worn over a coat
uniform int debug_view = 0;                  // 1 dirt/wear/sweat, 2 UV grid, 3 zones, 4 flat tint, 5 tint + normal map

varying flat uint v_zone;
varying vec4 v_c0;
varying vec4 v_c1;
varying vec2 v_c2;

float c_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float c_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(c_hash(i), c_hash(i + vec2(1.0, 0.0)), u.x), mix(c_hash(i + vec2(0.0, 1.0)), c_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float c_fbm(vec2 p) {
	return 0.55 * c_noise(p) + 0.3 * c_noise(p * 2.13 + 7.1) + 0.15 * c_noise(p * 4.7 + 1.3);
}

float lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec4 zone_tint(int z) {
	return z == 0 ? tint0 : (z == 1 ? tint1 : (z == 2 ? tint2 : tint3));
}

bool region_hidden(uint r) {
	uint bits = r < 32u ? (hide_mask.x >> r) : (hide_mask.y >> (r - 32u));
	return (bits & 1u) != 0u;
}

// Normal map in a frame from screen-space derivatives of the position and UV (Schueler).
vec3 perturb(vec3 n, vec3 p, vec2 uv, vec3 m) {
	vec3 dp1 = dFdx(p);
	vec3 dp2 = dFdy(p);
	vec2 duv1 = dFdx(uv);
	vec2 duv2 = dFdy(uv);
	vec3 dp2perp = cross(dp2, n);
	vec3 dp1perp = cross(n, dp1);
	vec3 t = dp2perp * duv1.x + dp1perp * duv2.x;
	vec3 b = dp2perp * duv1.y + dp1perp * duv2.y;
	float invmax = inversesqrt(max(max(dot(t, t), dot(b, b)), 1e-20));
	// texture +Y (OpenGL green) points toward decreasing UV.y
	return normalize(t * invmax * m.x - b * invmax * m.y + n * m.z);
}

// Bump from a scalar height (m) by screen-space derivatives (Mikkelsen).
vec3 bump(vec3 n, vec3 p, float h) {
	vec3 dpx = dFdx(p);
	vec3 dpy = dFdy(p);
	float dhx = dFdx(h);
	float dhy = dFdy(h);
	vec3 r1 = cross(dpy, n);
	vec3 r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * n - grad);
}

void vertex() {
	uint code = uint(UV2.x + 0.5);
	v_zone = min(code >> 6u, 3u);
	v_c0 = CUSTOM0;
	v_c1 = CUSTOM1;
	v_c2 = CUSTOM2.xy;
	VERTEX += normalize(NORMAL) * inflate;
	if (region_hidden(code & 63u)) {
		VERTEX = vec3(0.0);
	} else if (CUSTOM1.y > 0.5) {
		float cls = CUSTOM1.y;
		float amt = cls < 2.5 ? mix(push_m.x, push_m.y, clamp(cls - 1.0, 0.0, 1.0)) : push_m.z;
		vec3 dir = cls < 2.5 ? NORMAL : TANGENT;
		VERTEX += normalize(dir) * amt;
	}
}

void fragment() {
	int z = int(v_zone);
	vec4 tn = zone_tint(z);
	float mode = wear_mode[z];
	vec2 uvm = UV;
	vec2 suv = uvm / max(tile_m[z], 1e-3) + vec2(seed * 0.37, seed * 0.61);
	vec4 d = texture(fabric_detail, vec3(suv, layer[z]));
	vec3 nm = texture(fabric_normal, vec3(suv, layer[z])).rgb * 2.0 - 1.0;
	float ratio = d.r * 2.0;
	// the scans' weave is under a pixel beyond arm's length; what reads at game distance is each
	// cloth's mid-scale character, drawn here from the UV (metres) and faded in by pixel size:
	// fulled wool's felting clouds, linen's slubs, buckskin's smoke-tan mottle, leather's grain.
	float lay = layer[z];
	float px_m = length(fwidth(uvm)) + 1e-6;         // metres per pixel on the cloth
	float chv = 0.0;
	if (lay < 0.5 || lay > 6.5 && lay < 7.5) {       // LIN, HES: slubs along both threads
		float sa = c_noise(vec2(uvm.x * 900.0, uvm.y * 14.0) + seed);
		float sb = c_noise(vec2(uvm.x * 14.0, uvm.y * 900.0) + seed * 1.3);
		float slub = smoothstep(0.62, 0.9, sa) - smoothstep(0.66, 0.92, sb) * 0.7;
		chv = slub * 0.16 * (1.0 - smoothstep(0.0008, 0.003, px_m)) + (c_fbm(uvm * 30.0 + seed) - 0.5) * 0.12;
	} else if (lay < 2.5) {                          // WOOL, TWILL: felting clouds and fuzz
		chv = (c_fbm(uvm * 55.0 + seed) - 0.5) * 0.3 + (c_fbm(uvm * 11.0 + seed * 0.7) - 0.5) * 0.2
				+ (c_noise(uvm * 420.0 + seed) - 0.5) * 0.08 * (1.0 - smoothstep(0.001, 0.004, px_m));
	} else if (lay < 3.5) {                          // KNIT: yarn thickness along the rows
		chv = (c_noise(vec2(uvm.x * 12.0, uvm.y * 260.0) + seed) - 0.5) * 0.14;
	} else if (lay < 4.5) {                          // SUEDE (buckskin): smoke-tan mottle
		chv = (c_fbm(uvm * 9.0 + seed) - 0.5) * 0.26 + (c_fbm(uvm * 45.0 + seed * 2.0) - 0.5) * 0.12;
	} else if (lay < 5.5) {                          // LEA: grain, creases, scuffs
		chv = (c_fbm(uvm * 30.0 + seed) - 0.5) * 0.18 + (c_noise(uvm * 160.0 + seed) - 0.5) * 0.1 * (1.0 - smoothstep(0.001, 0.004, px_m));
	} else if (lay < 6.5) {                          // FUR base
		chv = (c_fbm(uvm * 25.0 + seed) - 0.5) * 0.2;
	}
	vec3 col = tn.rgb * max(0.05, 1.0 + detail_strength[z] * (ratio - 1.0) + character * chv);
	float rough = clamp(mix(0.85, d.g, 0.7) * roughness_mul[z], 0.04, 1.0);
	// hem stripes (zone 0)
	if (z == 0 && band_rows.x > 0.5) {
		for (int i = 0; i < 3; i++) {
			if (float(i) < band_rows.x) {
				float o = band_rows.y + float(i) * (band_rows.z + band_rows.w);
				float e = fwidth(v_c0.x) + 1e-4;
				float inb = smoothstep(o - e, o + e, v_c0.x) * (1.0 - smoothstep(o + band_rows.z - e, o + band_rows.z + e, v_c0.x));
				col = mix(col, band_color.rgb * max(0.05, 1.0 + detail_strength[z] * (ratio - 1.0)), inb);
			}
		}
	}
	// large-scale colour variation: uneven dye, fading, felting (tiny hue drift toward warm grey)
	float mv = c_fbm(uvm * 2.6 + seed * 3.1);
	float mh = c_noise(uvm * 1.3 + seed * 5.7 + 11.0);
	float mc = c_fbm(uvm * 19.0 + seed * 7.3);                  // 3-6 cm felting clouds
	col *= 1.0 + macro_var * (mv - 0.5) * 2.0 + macro_var * 0.6 * (mc - 0.5) * 2.0;
	col = mix(col, col * vec3(1.03, 1.0, 0.95), macro_var * 2.0 * (mh - 0.5));
	// wear: rubbed nap, burnished leather, polished metal
	float n1 = c_noise(uvm * 17.0 + seed);
	float n2 = c_noise(uvm * 53.0 + seed * 2.0);
	float wear = clamp(v_c0.w * wear_amount * (0.45 + 0.8 * n1 + 0.3 * n2) - 0.15, 0.0, 1.0);
	if (mode < 0.5) {
		vec3 grey = vec3(lum(col));
		col = mix(col, mix(col, grey, 0.4) * 1.45 + 0.018, wear * 0.8);
		rough -= 0.1 * wear;
	} else if (mode < 1.5) {
		col *= 1.0 - 0.3 * wear;
		rough -= 0.3 * wear;
		float scuff = (1.0 - smoothstep(0.0, 0.004, min(v_c0.x, v_c0.y))) * step(0.55, n2);
		col = mix(col, col * 1.6 + 0.02, 0.5 * scuff * wear_amount);
	} else if (mode < 2.5) {
		// tarnish in the hollows, bright where handled
		float tarn = (1.0 - wear) * (0.5 + 0.5 * mv);
		col = mix(col, col * vec3(0.55, 0.52, 0.42), 0.55 * tarn);
		rough = mix(0.28, 0.55, tarn);
	} else if (mode < 3.5) {
		col *= 1.0 - 0.15 * wear;
	} else {
		// horn and wood: streaks along the grain
		float st = c_noise(vec2(uvm.x * 60.0, uvm.y * 4.0) + seed);
		col *= 0.8 + 0.4 * st;
		rough = mix(0.35, 0.6, st) - 0.15 * wear;
	}
	// sweat: darker, yellowed on light cloth, a soft tide line
	float sw = clamp(v_c1.x * sweat_amount * (0.6 + 0.6 * mv) - 0.1, 0.0, 1.0);
	if (mode < 1.5 || mode > 2.5) {
		float light = smoothstep(0.08, 0.35, lum(col));
		col *= mix(vec3(1.0), vec3(0.78, 0.74, 0.66), sw * 0.8);
		col *= mix(vec3(1.0), vec3(1.0, 0.95, 0.8), sw * light);
		rough -= 0.06 * sw;
	}
	// dirt: dust and mud that settle into the weave, in patches that grow with the mask
	float dn = 0.6 * c_fbm(uvm * 8.0 + seed * 1.7) + 0.4 * n2;
	float dirt = clamp((v_c0.z * dirt_amount - (1.0 - dn) * 0.55) * 2.2, 0.0, 1.0);
	dirt *= mix(1.0, ratio, 0.5);
	if (mode > 1.5 && mode < 2.5) {
		dirt *= 0.35;
	}
	col = mix(col, dirt_color.rgb * (0.8 + 0.4 * n1), clamp(dirt, 0.0, 1.0) * 0.7);
	rough = mix(rough, 0.95, dirt * 0.6);
	// sewn seams: a shadowed groove (its darkening keeps its average as it shrinks below a pixel),
	// the raised seam allowance either side and a little puckering
	float dsm = abs(v_c1.z);
	float spx = fwidth(dsm) + 1e-5;
	float seam_h = 0.0;
	if (dsm < 0.02 && (mode < 1.5 || mode > 2.5)) {
		float w = 0.0012;
		float groove = 1.0 - smoothstep(w * 0.5, w * 0.5 + spx, dsm);
		col *= 1.0 - 0.55 * groove * (w / (w + spx));
		col *= mix(0.9, 1.0, smoothstep(0.0, 0.007, dsm));
		seam_h = 0.0009 * smoothstep(0.0, 0.0015, dsm) * (1.0 - smoothstep(0.002, 0.007, dsm));
	}
	// dust settles on what faces up (shoulders, hat brim, the tops of feet and folds), in patches
	vec3 up_v = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float upf = smoothstep(0.25, 0.85, dot(NORMAL, up_v));
	float dust = upf * dust_amount * (0.35 + 0.65 * c_fbm(uvm * 6.0 + seed * 2.3));
	if (mode < 1.5 || mode > 2.5) {
		col = mix(col, dirt_color.rgb * 1.6, clamp(dust, 0.0, 1.0) * 0.35);
		rough = mix(rough, 1.0, dust * 0.4);
	}
	// cavity: fold valleys darker (the light does not reach into them), ridges rubbed
	float cav = v_c2.x * cavity_amount;
	col *= 1.0 - 0.5 * max(cav, 0.0);
	float ridge = max(-cav, 0.0);
	if (mode < 0.5) {
		col = mix(col, col * 1.18 + 0.006, ridge * 0.5 * wear_amount);
	}
	// compression folds: rings of soft folds across the limb axis (UV.y), wavy along the rim;
	// the relief fades once a fold is under ~6 px, its shading stays (averaged)
	float fold_h = 0.0;
	float fm = v_c2.y * fold_amount;
	if (fm > 0.01) {
		float lam = 0.034;
		float ph = uvm.y / lam + 2.2 * c_noise(vec2(uvm.x * 9.0, uvm.y * 4.0) + seed) + 0.8 * c_noise(uvm * 31.0);
		float wv = 0.5 + 0.5 * sin(6.2831853 * ph);
		float pix = lam / px_m;
		float relief = smoothstep(4.0, 8.0, pix);
		fold_h = 0.004 * fm * wv * relief;
		float valley = (1.0 - wv) * fm;
		col *= 1.0 - 0.3 * mix(0.5 * fm, valley, relief);
	}
	// hem: the stitch line of the turned hem (fades out beyond ~2 px per mm) and the fold
	float dh = min(v_c0.x, v_c0.y);
	float px = fwidth(dh) + 1e-6;
	float hem_h = 0.0;
	if (hem_width > 0.0 && (mode < 1.5 || mode > 2.5)) {
		float vis = 1.0 - smoothstep(0.0008, 0.003, px);
		float dash = step(0.35, fract((uvm.x + uvm.y) / 0.0045));
		float line = 1.0 - smoothstep(0.0004, 0.0009 + px, abs(dh - hem_width));
		col *= 1.0 - 0.45 * line * dash * vis;
		hem_h = 0.0012 * (1.0 - smoothstep(0.0, hem_width, dh));   // the doubled cloth of the hem
		col *= mix(0.82, 1.0, smoothstep(0.0, 0.0025, dh));        // rolled edge shadow
	}
	ALBEDO = clamp(col * COLOR.rgb, vec3(0.0), vec3(1.0));
	METALLIC = metal[z];
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	SPECULAR = metal[z] > 0.5 ? 0.5 : (mode > 0.5 && mode < 1.5 ? 0.5 : 0.45);
	AO = mix(1.0, d.b, 0.85) * (1.0 - 0.35 * max(cav, 0.0));
	AO_LIGHT_AFFECT = 0.15;
	// Godot's rim term is (1 - N.V)^((1 - roughness) * 16): on rough cloth it reaches far from the
	// silhouette, so it is kept albedo-tinted (a nap sheen, not a white glow)
	RIM = sheen[z];
	RIM_TINT = 1.0;
	vec3 n = NORMAL;
	// the weave's normals fade out once a pixel covers more than a few texels (beyond ~1.5 m: the
	// mipmaps have averaged them away, and what is left would only tilt whole triangles)
	float tpp = length(fwidth(suv)) * 1024.0;
	float ns = normal_strength[z] * (1.0 - smoothstep(3.0, 10.0, tpp));
	if (ns > 0.001) {
		vec3 m = normalize(vec3(nm.xy * ns, max(nm.z, 0.05)));
		n = perturb(n, VERTEX, UV, m);
	}
	if (hem_h + seam_h + fold_h > 0.0) {
		n = bump(n, VERTEX, hem_h + seam_h + fold_h);
	}
	// debug views (tools/character/outfit_shots.gd debug=N): 4 drops the normal map
	if (debug_view != 4) {
		NORMAL = n;
	}
	if (debug_view == 1) {
		ALBEDO = vec3(v_c0.z, v_c0.w, v_c1.x);
	} else if (debug_view == 2) {
		vec2 g = fract(uvm / 0.05);
		ALBEDO = vec3(step(0.9, g.x), step(0.9, g.y), 0.2);
	} else if (debug_view == 3) {
		ALBEDO = vec3(float(z == 0), float(z == 1), float(z >= 2));
	} else if (debug_view == 4 || debug_view == 5) {
		ALBEDO = tn.rgb * COLOR.rgb;
		RIM = 0.0;
		if (debug_view == 4) {
			AO = 1.0;
			ROUGHNESS = 0.9;
		}
	}
}
