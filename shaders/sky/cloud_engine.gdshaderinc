// Frontier cloud engine (2026-09-26; user: "i want a cloud engine thats makes it look like real life cloud or move
// like real clouds like we can see a storm coming in"). Included by frontier_sky_dynamic.gdshader.
//
// Clouds at their real heights over a curved Earth: the view ray is intersected with spherical shells around the
// planet (radius CE_R), so the cloud deck bends down to the horizon 100-200 km away instead of hanging as a low flat
// dome, and far clouds pile up and fade into the haze as real ones do. Cloud types by weather:
//   cumulus        fair weather: flat bases at cu_base (the condensation level), rounded tops at cu_top,
//                  cells of Perlin-Worley noise, coverage in patches tens of km across
//   stratocumulus  the overcast deck (sc_*): lumpy, low, nearly continuous
//   cumulonimbus   a storm front (front, front_shape): a line of towers from 900 m to 11.5 km with dark flat bases,
//                  an anvil spreading ahead of it at 8.5-11 km, a trailing nimbostratus rain deck, rain shafts
//                  (virga where the rain is light) and lightning inside the towers and to the ground
//   cirrus         thin streaks at cirrus_height (2D), a cirrostratus veil with the 22-degree halo; the storm's
//                  anvil shield thickens it ahead of the front
// Raymarched volume (half resolution): density = the weather's envelope (height profile x coverage) remapping a
// 64^3 tileable Perlin-Worley texture (assets/environment/sky/cloud_noise_3d.png), eroded at the edges by a Worley
// detail octave. Lighting: a short cone march toward the sun or moon (Beer's law with multiple-scattering octaves,
// the powder effect, a two-lobe phase: silver linings toward the sun), sky light dimmed by the cloud above each
// point (dark storm bases), light bounced from the ground, sunset: the key light is taken at 1.5 and 9 km
// (cloud_light_color / cloud_light_high) so the tops stay lit after the bases fall into the Earth's shadow.
// Haze between the camera and the clouds from an aerosol (1.5 km scale height) and Rayleigh column.
// Motion: the clouds drift with the wind (sky_cloud_offset.xy, metres), rise and change shape (cloud_evolve), the
// cirrus moves with the faster wind aloft (sky_cloud_offset.zw); the weather (WeatherSystem) moves the fronts.
// The CPU mirror of ce_front / ce_patches / ce_density (sun shade, rain at the player) is
// scripts/world/env/cloud_field.gd: keep the two in step.

uniform sampler3D cloud_noise : filter_linear_mipmap, repeat_enable, hint_default_black;
uniform float cu_cover = 0.3;              // fair-weather cumulus coverage 0..1
uniform float cu_base = 1500.0;            // m above the ground
uniform float cu_top = 3000.0;
uniform float sc_cover = 0.0;              // stratocumulus / overcast deck 0..1
uniform float sc_base = 1100.0;
uniform float sc_top = 2300.0;
// Storm front: xy the unit world xz direction it moves toward, z the leading edge's position along it (m, world),
// w its strength 0..1 (0: no storm).
uniform vec4 front = vec4(1.0, 0.0, -1e7, 0.0);
// x width of the convective line (m), y width of the trailing rain deck, z how far the anvil reaches ahead, w cell
// spacing along the line.
uniform vec4 front_shape = vec4(16000.0, 45000.0, 75000.0, 13000.0);
uniform float cloud_ceiling = 4500.0;      // top of the march (m): 11500 with a storm on the map
uniform float cloud_extinction = 0.04;     // per metre at density 1
uniform float cloud_evolve = 0.0;          // m: the noise rises through the clouds (they build and dissolve)
uniform int cloud_steps = 28;              // raymarch steps toward the horizon (fewer overhead)
uniform int cloud_light_steps = 3;
uniform float cloud_jitter_anim = 1.0;     // 1: the step jitter changes every frame (TAA / temporal upscalers)
uniform vec3 cloud_light_high = vec3(7.0, 5.6, 4.0);   // key light at 9 km
uniform vec3 cloud_ground = vec3(0.02, 0.022, 0.018);  // light bounced from the ground onto the bases
uniform float haze_km = 30.0;              // aerosol extinction length at the ground
uniform vec2 patch_offset = vec2(0.0);     // m the coverage patches have drifted (unwrapped, unlike sky_cloud_offset)
uniform float veil = 0.0;                  // cirrostratus veil 0..1 (the 22-degree halo)
uniform vec4 flash = vec4(0.0, 4000.0, 0.0, 0.0);      // lightning inside a cloud: world x, altitude, world z; power
uniform vec4 bolt = vec4(0.0, 0.0, 0.0, 0.0);          // a stroke to the ground: world x, z, seed; brightness
uniform int cloud_debug = 0;               // 1: the half-res pass outputs the clouds' transmittance (tests); 2: light depth / density / height of the first lit sample

const float CE_R = 6371e3;
const float CE_BASE_TILE = 7200.0;         // m per tile of the base noise (cells ~1.8 km)
const float CE_DETAIL_TILE = 1200.0;
const float CE_VSCALE = 1.5;               // the noise is 1.5x finer vertically
const float CE_CB_BASE = 900.0;
const float CE_NS_TOP = 5500.0;

float ce_hg(float c, float g) {
	float g2 = g * g;
	return 0.0795775 * (1.0 - g2) / pow(max(1.0 + g2 - 2.0 * g * c, 1e-4), 1.5);
}

// Distance from radius r0 (inside) along a ray with vertical cosine mu to the sphere of radius R.
float ce_sphere(float r0, float mu, float R) {
	float b = r0 * mu;
	return -b + sqrt(max(b * b - r0 * r0 + R * R, 0.0));
}

// Height profile of a cloud column: flat base, tops rounding off from round_from (0..1 of the column).
float ce_column(float h, float base, float top, float round_from) {
	float hf = (h - base) / max(top - base, 1.0);
	return smoothstep(0.0, 0.07, hf) * (1.0 - smoothstep(round_from, 1.0, hf));
}

// Fair-weather coverage patches (clear and cloudier stretches tens of km across), 0..1, drifting with the wind.
float ce_patches(vec2 xz) {
	vec2 q = xz * 1.3e-4;
	float v = sin(q.x * 1.7 + 1.3) * sin(q.y * 1.3 + 0.4) + 0.5 * sin(q.x * 0.9 - q.y * 2.3 + 2.1);
	return clamp(0.5 + 0.4 * v, 0.0, 1.0);
}

// The storm front at world xz: x cumulonimbus cells (round towers along the line), y the trailing nimbostratus
// rain deck, z anvil shield, w rain rate; all 0..1 and scaled by the front's strength. line: the band of the
// convective line (the towers' lumpy lower mass and shelf).
vec4 ce_front(vec2 xz, out float line) {
	line = 0.0;
	if (front.w <= 0.0) {
		return vec4(0.0);
	}
	vec2 dir = front.xy;
	float a = dot(xz, vec2(-dir.y, dir.x));
	float u = dot(xz, dir) - front.z + 5000.0 * sin(a * 2.2e-5 + 0.7);   // m ahead of the leading edge (bowed)
	float cw = front_shape.x;
	float tw = front_shape.y;
	// the cells: one round tower per cell spacing along the line, each its own strength, staggered, drifting
	float k = a / front_shape.w + front.z * 3e-6;
	float ci = floor(k + 0.5);
	float kf = k - ci;
	float strength = 0.55 + 0.45 * sin(ci * 2.39996 + 0.5);
	float uc = u + 0.45 * cw + 0.12 * cw * sin(ci * 1.7);
	float cb = exp(-kf * kf * 9.0 - uc * uc / (0.09 * cw * cw)) * strength;
	float ul = u + 0.45 * cw;
	line = exp(-ul * ul / (0.16 * cw * cw)) * front.w;
	float deck = smoothstep(-cw - tw, -cw - 0.55 * tw, u) * (1.0 - smoothstep(-0.8 * cw, -0.35 * cw, u));
	float anvil = exp(-max(u, 0.0) / (0.3 * front_shape.z)) * smoothstep(-cw - 0.4 * tw, -0.9 * cw, u);
	float rain = min(max(smoothstep(0.2, 0.6, cb), line * 0.55) + deck * 0.3, 1.0);
	return vec4(cb, deck, anvil, rain) * front.w;
}

// Cloud density 0..1 at world position wp = (x, h, z), h metres above the ground. amb: the share of the sky light
// that reaches the point through the cloud above it (less deep inside, more near a cloud's surface); gnd: how lit
// the ground under the point is (dark under a storm); env: the weather's envelope there (0: clear air).
float ce_density(vec3 wp, float lod, bool detail, out float amb, out float gnd, out float env) {
	float h = wp.y;
	float line;
	vec4 f = ce_front(wp.xz, line);
	float cu = min(cu_cover * (0.5 + 1.0 * ce_patches(wp.xz - patch_offset)), 1.0);
	// storm towers: a point is inside when its cell is strong enough for its height (columns that round off at
	// the top; the strongest reach the tropopause at ~10.5 km)
	float hf_cb = clamp((h - CE_CB_BASE) / 10100.0, 0.0, 1.0);
	float req = 0.95 * hf_cb * hf_cb * sqrt(hf_cb);
	float e_cb = f.x > 0.0 ? smoothstep(0.0, 0.03, hf_cb) * smoothstep(max(req - 0.05, 0.0), req + 0.45, f.x) : 0.0;
	float cb_top = CE_CB_BASE + pow(clamp(f.x / 0.95, 0.0, 1.0), 0.4) * 10100.0;
	float e_cu = ce_column(h, cu_base, cu_top, 0.35) * cu;
	float e_sc = ce_column(h, sc_base, sc_top, 0.65) * sc_cover;
	float e_ns = max(ce_column(h, 1000.0, CE_NS_TOP, 0.75) * f.y * 0.95, ce_column(h, CE_CB_BASE, 3200.0, 0.5) * line * 0.7);
	float an = f.z * f.z;   // the thick anvil near the towers (its thin shield far ahead is ce_cirrus's veil)
	float e_an = smoothstep(8200.0, 8900.0, h) * (1.0 - smoothstep(10600.0, 11400.0, h)) * an * 0.8;
	float e = max(max(e_cu, e_sc), max(max(e_cb, e_ns), e_an));
	env = e;
	// density per cloud type: cumulus and storm towers optically thick, the stratocumulus deck thinner (its
	// brightness varies), the rain deck in between, the anvil a thin fibrous sheet
	float ew = 1.0 / max(e_cu + e_sc + e_cb + e_ns + e_an, 1e-4);
	float dscale = (e_cu * 1.0 + e_sc * 0.55 + e_cb * 1.0 + e_ns * 0.55 + e_an * 0.035) * ew;
	// how quickly the density rises inside the edge: crisp cumulus and towers, softer decks
	float sharp = (e_cu * 3.0 + e_sc * 1.2 + e_cb * 2.5 + e_ns * 1.5 + e_an * 1.0) * ew;
	if (e < 0.02) {
		amb = 1.0;
		gnd = 1.0;
		return 0.0;
	}
	float storm = max(cb_top - h, 0.0) * min(f.x * 1.5, 1.0) * 1.3 + max(CE_NS_TOP - h, 0.0) * f.y * 0.55 + max(3200.0 - h, 0.0) * line * 0.4
			+ (h < 8500.0 ? 2500.0 * an * 0.035 : 0.0);
	float above = max(cu_top - h, 0.0) * min(cu * 1.6, 1.0) + max(sc_top - h, 0.0) * sc_cover * 0.8 + storm;
	amb = exp(-above * 3.5e-4 * (0.35 + 0.65 * e));
	gnd = exp(-storm * 3.5e-4);
	vec3 q = vec3(wp.x - sky_cloud_offset.x, h * CE_VSCALE - cloud_evolve, wp.z - sky_cloud_offset.y);
	float n = textureLod(cloud_noise, q / CE_BASE_TILE, lod).r;
	float c = clamp((n - (1.0 - e)) / max(e, 0.05) * sharp, 0.0, 1.0) * dscale;
	if (detail && c > 0.0 && c < 0.5 * dscale) {
		vec3 qd = vec3(q.x, h * CE_VSCALE - cloud_evolve * 1.5, q.z) / CE_DETAIL_TILE;
		float dn = textureLod(cloud_noise, qd, lod).g;
		float hf = clamp((h - cu_base) / max(cu_top - cu_base, 1.0), 0.0, 1.0);
		dn = mix(1.0 - dn, dn, smoothstep(0.05, 0.4, hf));   // wisps at the base, billows above
		c = clamp((c - dn * 0.4 * dscale) / (1.0 - dn * 0.4), 0.0, 1.0);
	}
	return c;
}

// Optical depth toward the key light from planet-frame point p (camera at (0, r0, 0)).
float ce_light_depth(vec3 p, vec3 cam, vec3 L, float lod) {
	float tau = 0.0;
	float s = 0.0;
	float ds = 110.0;
	int steps = cloud_light_steps + (front.w > 0.0 ? 1 : 0);   // through a storm tower: out to ~10 km
	float grow = front.w > 0.0 ? 3.2 : 2.3;
	for (int i = 0; i < steps; i++) {
		vec3 q = p + L * (s + 0.5 * ds);
		float a;
		float g;
		float e;
		tau += ce_density(vec3(cam.x + q.x, length(q) - CE_R, cam.z + q.z), lod + 0.7, false, a, g, e) * ds;
		s += ds;
		ds *= grow;
	}
	return tau * cloud_extinction;
}

// Transmittance of the haze between the camera and a point t metres along a ray with vertical cosine mu.
float ce_haze(float t, float mu) {
	float me = max(mu + t / (2.0 * CE_R), 1e-4);
	float aer = 1500.0 / me * (1.0 - exp(-me * t / 1500.0));
	float ray = 8000.0 / me * (1.0 - exp(-me * t / 8000.0));
	return exp(-aer / (haze_km * 1000.0) - ray * 1.1e-5);
}

// Rain shafts under the storm (and virga where the rain dries up before the ground), premultiplied, hazed toward
// atm (the sky behind) like the clouds: far shafts fade into the horizon haze instead of showing as a dark band.
vec4 ce_rain(vec3 d, vec3 cam, vec3 atm, float r0, float jitter) {
	if (front.w <= 0.0 || d.y < -0.02) {
		return vec4(0.0);
	}
	float mu = max(d.y, 0.0);
	float tmax = min(ce_sphere(r0, mu, CE_R + CE_CB_BASE + 100.0), 90000.0);
	const int N = 10;
	float dt = tmax / float(N);
	float t = dt * jitter;
	vec3 acc = vec3(0.0);
	float T = 1.0;
	float cosl = dot(d, cloud_light_dir);
	vec3 lit = cloud_ambient * 0.22 + cloud_light_color * 0.05 * ce_hg(cosl, 0.6);
	for (int i = 0; i < N; i++) {
		vec3 p = vec3(0.0, r0, 0.0) + d * t;
		float h = length(p) - CE_R;
		vec2 xz = cam.xz + p.xz;
		float ln;
		float r = ce_front(xz, ln).w;
		if (r > 0.01) {
			vec3 q = vec3(xz.x - sky_cloud_offset.x - h * 0.35 * front.x, h * 0.12, xz.y - sky_cloud_offset.y - h * 0.35 * front.y);
			// one noise tile per CE_BASE_TILE: the drift (sky_cloud_offset.xy) wraps there without a jump
			float curtain = smoothstep(0.3, 0.75, textureLod(cloud_noise, q / CE_BASE_TILE, 1.0).b);
			float virga = smoothstep((1.0 - min(r * 2.0, 1.0)) * 700.0, (1.0 - min(r * 2.0, 1.0)) * 700.0 + 250.0, h);
			float sig = r * (0.25 + 0.75 * curtain) * virga * (1.0 - smoothstep(CE_CB_BASE - 50.0, CE_CB_BASE + 100.0, h)) * 4.5e-4;
			float ext = exp(-sig * dt);
			float ha = ce_haze(t, mu);
			acc += T * (1.0 - ext) * (lit * ha + atm * (1.0 - ha));
			T *= ext;
		}
		t += dt;
	}
	return vec4(acc, 1.0 - T);
}

// Volumetric clouds along view direction d from camera position cam (world), premultiplied (colour * alpha, alpha),
// hazed toward atm (the sky behind). steps: the march's step count toward the horizon.
vec4 ce_clouds(vec3 d, vec3 cam, vec3 atm, float jitter, int steps) {
	if (d.y < 0.0) {
		return vec4(0.0);
	}
	float r0 = CE_R + max(cam.y, 0.0) + 2.0;
	float mu = d.y;
	float lo = min(min(cu_base, sc_base), front.w > 0.0 ? CE_CB_BASE : 1e5);
	float t0 = ce_sphere(r0, mu, CE_R + lo);
	float t1 = min(ce_sphere(r0, mu, CE_R + cloud_ceiling), t0 + 160000.0);
	// (1 - smoothstep(0.05, 0.5, mu), not smoothstep(0.5, 0.05, mu): reversed edges are undefined in GLSL / MSL)
	int n = int(mix(float(steps) * 0.55, float(steps), 1.0 - smoothstep(0.05, 0.5, mu)));
	// two segments when storm towers reach high: most steps in the low and mid clouds, the rest up to the anvils
	float ta = min(ce_sphere(r0, mu, CE_R + min(cloud_ceiling, 5000.0)), t1);
	int na = cloud_ceiling > 5000.0 ? int(float(n) * 0.65) : n;
	float dta = (ta - t0) / float(na);
	float dtb = (t1 - ta) / float(max(n - na, 1));
	float dt = dta;
	float lod = clamp(log2(dt / 220.0), 0.0, 4.0);
	vec3 L = cloud_light_dir;
	float cosl = dot(d, L);
	// two-lobe phase (forward silver lining, a little back-scatter) for three scattering octaves
	float ph0 = mix(ce_hg(cosl, 0.7), ce_hg(cosl, -0.25), 0.3);
	float ph1 = mix(ce_hg(cosl, 0.4), ce_hg(cosl, -0.12), 0.3);
	float ph2 = 0.0795775;
	float pw = 0.5 + 0.5 * clamp(-cosl, 0.0, 1.0);   // the powder effect shows with the light behind the viewer
	vec3 flash_col = vec3(0.75, 0.82, 1.0) * flash.w;
	float t = t0 + dt * jitter;
	vec3 acc = vec3(0.0);
	float T = 1.0;
	float tw = 0.0;
	float ws = 0.0;
	// half steps inside a cloud's envelope, whole steps through clear air; the high segment's longer steps above ta
	for (int i = 0; i < n * 2; i++) {
		if (t > t1) {
			break;
		}
		if (t > ta && dt != dtb) {
			dt = dtb;
			lod = clamp(log2(dt / 220.0), 0.0, 4.0);
		}
		vec3 p = vec3(0.0, r0, 0.0) + d * t;
		float h = length(p) - CE_R;
		vec3 wp = vec3(cam.x + p.x, h, cam.z + p.z);
		float amb;
		float gnd;
		float env;
		float c = ce_density(wp, lod, t < 30000.0, amb, gnd, env);   // no detail octave beyond 30 km
		float st = env > 0.02 ? dt * 0.5 : dt;
		if (c > 0.003) {
			// a step that would turn the ray opaque: find the cloud's surface (bisection back toward the previous
			// sample) and light four short steps from it, so the light is taken where the eye sees it and not deep
			// inside (the coarse far steps: towers seen from afar)
			bool refine = c * cloud_extinction * st > 1.5 && T > 0.2;
			int sub = refine ? 3 : 1;
			float sst = st;
			float t_in = t;
			if (refine) {
				float a0 = t - st;
				float a1 = t;
				for (int b = 0; b < 2; b++) {
					float am = 0.5 * (a0 + a1);
					vec3 pm = vec3(0.0, r0, 0.0) + d * am;
					float ga;
					float gg;
					float ge;
					if (ce_density(vec3(cam.x + pm.x, length(pm) - CE_R, cam.z + pm.z), lod, true, ga, gg, ge) > 0.003) {
						a1 = am;
					} else {
						a0 = am;
					}
				}
				t_in = mix(a0, a1, jitter);   // jittered inside the last interval: noise, not terraces
				sst = min(st, 3.0 / (c * cloud_extinction)) / 3.0;
			}
			for (int k = 0; k < sub; k++) {
				float ts = refine ? t_in + (float(k) + 0.5) * sst : t;
				vec3 ps = vec3(0.0, r0, 0.0) + d * ts;
				float hs = length(ps) - CE_R;
				vec3 wps = vec3(cam.x + ps.x, hs, cam.z + ps.z);
				float cs = c;
				if (sub > 1) {
					cs = ce_density(wps, lod, true, amb, gnd, env);
					if (cs <= 0.003) {
						continue;
					}
				}
				float sig = cs * cloud_extinction;
				float tl = ce_light_depth(ps, cam, L, lod);
				if (cloud_debug == 2) {
					return vec4(vec3(tl / 40.0, cs, hs / 12000.0), 1.0);
				}
				float beer = exp(-tl) * ph0 + 0.6 * exp(-tl * 0.35) * ph1 + 0.35 * exp(-tl * 0.1) * ph2;
				float powder = mix(1.0, 1.0 - exp(-cs * 7.0), pw);
				vec3 lc = mix(cloud_light_color, cloud_light_high, smoothstep(1500.0, 9000.0, hs));
				// sky light from above (less under the cloud above, less low in the column), ground light from below
				float hf = clamp((hs - cu_base) / max(cu_top - cu_base, 1.0), 0.0, 1.0);
				vec3 S = lc * (beer * powder * 10.0) + cloud_ambient * (amb * (0.3 + 0.7 * hf))
						+ cloud_ground * gnd * (1.0 - smoothstep(0.0, 2500.0, hs - lo));
				if (flash.w > 0.0) {
					S += flash_col * exp(-length(wps - flash.xyz) / 2200.0);
				}
				float ext = exp(-sig * sst);
				acc += T * (1.0 - ext) * S;
				tw += T * (1.0 - ext) * ts;
				ws += T * (1.0 - ext);
				T *= ext;
			}
			if (T < 0.015) {
				break;
			}
		}
		t += st;
	}
	float alpha = 1.0 - T;
	float ha = ce_haze(ws > 0.0 ? tw / ws : t0, mu);
	acc = acc * ha + atm * (1.0 - ha) * alpha;
	return vec4(acc, alpha);
}

// Cirrus streaks, the cirrostratus veil and the storm's anvil shield far ahead of it (2D at cirrus_height).
vec4 ce_cirrus(vec3 d, vec3 cam, vec3 atm, float r0) {
	if (d.y <= 0.0 || (cirrus_coverage <= 0.0 && veil <= 0.0 && front.w <= 0.0)) {
		return vec4(0.0);
	}
	float t = ce_sphere(r0, d.y, CE_R + cirrus_height);
	vec2 xz = cam.xz + d.xz * t;
	vec2 uv = (xz - sky_cloud_offset.zw) / cirrus_tile_m;
	float c = textureLod(sky_noise, uv, 0.0).a;
	float a = smoothstep(1.0 - cirrus_coverage, 1.0 - cirrus_coverage + 0.35, c) * 0.5;
	float ln;
	float v = max(veil, ce_front(xz, ln).z * 0.7);
	a = max(a, v * (0.45 + 0.35 * textureLod(sky_noise, uv * 0.37 + vec2(0.3, 0.1), 0.0).r));
	if (a <= 0.002) {
		return vec4(0.0);
	}
	float cosl = dot(d, cloud_light_dir);
	vec3 col = cloud_ambient * 0.8 + cloud_light_high * (0.25 + 2.2 * ce_hg(cosl, 0.6));
	// the 22-degree halo in the ice crystals of a cirrostratus veil (red inside, blue outside)
	float ang = degrees(acos(clamp(cosl, -1.0, 1.0)));
	vec3 halo = vec3(exp(-pow((ang - 21.7) / 0.55, 2.0)), exp(-pow((ang - 22.0) / 0.6, 2.0)), exp(-pow((ang - 22.4) / 0.7, 2.0)));
	col += cloud_light_high * halo * 0.35 * v;
	float ha = ce_haze(t, d.y);
	return vec4((col * ha + atm * (1.0 - ha)) * a, a);
}

// Everything above the ground in one premultiplied layer: rain shafts, then the volumetric clouds, then cirrus.
vec4 ce_sky_clouds(vec3 d, vec3 cam, vec3 atm, float jitter) {
	float r0 = CE_R + max(cam.y, 0.0) + 2.0;
	vec4 acc = ce_rain(d, cam, atm, r0, jitter);
	if (acc.a < 0.985) {
		vec4 cl = ce_clouds(d, cam, atm, jitter, cloud_steps);
		acc += cl * (1.0 - acc.a);
		if (acc.a < 0.985) {
			acc += ce_cirrus(d, cam, atm, r0) * (1.0 - acc.a);
		}
	}
	return acc;
}

// The radiance cubemap's clouds (ambient light, reflections, fog colour): one analytic sample, no noise.
vec4 ce_clouds_cheap(vec3 d, vec3 cam, vec3 atm) {
	if (d.y <= 0.0) {
		return vec4(0.0);
	}
	float r0 = CE_R + 2.0;
	float t = ce_sphere(r0, d.y, CE_R + 1800.0);
	vec2 xz = cam.xz + d.xz * t;
	float ln;
	vec4 f = ce_front(xz, ln);
	float cu = min(cu_cover * (0.5 + 1.0 * ce_patches(xz - patch_offset)), 1.0) * 0.6;
	float cov = max(max(cu, sc_cover), max(max(f.x, max(f.y, ln * 0.7)), max(f.z * 0.5, veil * 0.3)));
	float a = smoothstep(0.02, 0.85, cov) * smoothstep(0.0, 0.04, d.y);
	float cosl = dot(d, cloud_light_dir);
	float thick = max(max(f.x, max(f.y, ln * 0.7)), sc_cover * 0.6);
	vec3 col = cloud_ambient * (1.1 - 0.7 * thick) + cloud_light_color * (1.0 - thick) * (1.0 - thick) * (0.25 + 2.0 * ce_hg(cosl, 0.6));
	col *= 1.0 - 0.85 * max(f.x, max(f.y, ln) * 0.8);
	float ha = ce_haze(t, d.y);
	return vec4((col * ha + atm * (1.0 - ha)) * a, a);
}

// A lightning stroke to the ground (full resolution): a jagged channel from the storm's base down to the ground.
vec3 ce_bolt(vec3 d, vec3 cam) {
	if (bolt.w <= 0.0) {
		return vec3(0.0);
	}
	vec2 rel = bolt.xy - cam.xz;
	float dist = length(rel);
	float drop = dist * dist / (2.0 * CE_R);        // the Earth's curve
	vec3 prev = vec3(rel.x, CE_CB_BASE + 50.0 - cam.y - drop, rel.y);
	float glow = 0.0;
	for (int k = 1; k <= 7; k++) {
		vec3 hsh = hash33(vec3(bolt.z, float(k), 3.7)) - 0.5;
		float f = float(k) / 7.0;
		vec3 cur = vec3(rel.x + hsh.x * 320.0 * (1.0 - f * 0.3), (CE_CB_BASE + 50.0) * (1.0 - f) - cam.y - drop, rel.y + hsh.z * 320.0);
		if (k == 7) {
			cur.xz = rel + hsh.xz * 60.0;
		}
		// closest approach of the view ray (origin 0, direction d) to the segment prev-cur
		vec3 e = cur - prev;
		float ee = dot(e, e);
		float de = dot(d, e);
		float dp = dot(d, prev);
		float ep = dot(e, prev);
		float den = ee - de * de;
		float s = den > 1e-6 ? clamp((de * dp - ep) / den, 0.0, 1.0) : 0.0;
		vec3 q = prev + e * s;
		float tq = max(dot(q, d), 1.0);
		float ang = length(q - d * tq) / tq;
		glow += exp(-ang / 0.00035) + 0.25 * exp(-ang / 0.004);
		prev = cur;
	}
	return vec3(0.85, 0.88, 1.0) * glow * bolt.w * ce_haze(dist, 0.01);
}
