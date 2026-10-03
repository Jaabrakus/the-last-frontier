// The wonder sky (user 2026-10-02: "can we do a treasure planet look actually? what it might feel like if that world was
// real"): the frontier's own sky with the heavens of a world among the stars laid over it. Off unless `wonder` > 0
// (WonderLook, scripts/world/env/wonder_look.gd, launch arg look=wonder); at 0 it costs one branch.
//   - a ringed giant: a banded gas world 14 deg across near the celestial pole (circumpolar at the valley's latitude: it
//     wheels round the pole star with the stars and never sets), lit by the sun with a soft terminator and a lit rim,
//     its rings an open ellipse that pass in front of it below and behind it above;
//   - two moons: an icy one and a rust one, lit by the sun (their phases);
//   - the etherium: nebula clouds in violet, teal and gold across the sky, strong at night, a faint tint by day (the
//     sky's own light hides most of it, as it does the stars).
// Everything is on the celestial sphere (`celestial`: world -> equatorial), so it turns with the stars, and it is added
// behind the air (x the sky's transmittance `tr`) and behind the clouds (the clouds composite over it).

uniform float wonder = 0.0;
uniform vec3 wonder_planet_eq = vec3(0.21, 0.33, 0.92);   // the giant's direction (equatorial; normalised in use)
uniform float wonder_planet_deg = 26.0;                    // its drawn diameter
uniform float wonder_planet_bright = 2.2;                  // its lit side's radiance (sky units, before the air)
uniform vec3 wonder_ring_axis = vec3(0.28, 0.9, 0.34);     // the rings' pole in the disc's frame (x right, y up, z to us)
uniform float wonder_nebula_night = 0.014;                // the etherium's radiance at night
uniform float wonder_nebula_day = 0.18;                    // its tint on the day sky (fraction)
uniform float wonder_day_solid = 0.8;                      // how much the giant hides the day sky behind it (artistic: a
                                                           // world so near it outshines the blue; physically 0)
uniform vec3 wonder_cloud_glow = vec3(0.0035, 0.0028, 0.0065);   // the etherium's light on the clouds at night
uniform vec3 wonder_moon1_eq = vec3(-0.62, 0.55, 0.56);
uniform vec3 wonder_moon2_eq = vec3(0.70, -0.38, 0.60);

vec3 wonder_frame_q(vec3 d, vec3 pd, float rad, out vec3 ee, out vec3 nn) {
	vec3 north = transpose(celestial) * vec3(0.0, 0.0, 1.0);
	vec3 up = abs(dot(north, pd)) > 0.98 ? vec3(0.0, 1.0, 0.0) : north;
	nn = normalize(up - pd * dot(up, pd));
	ee = cross(pd, nn);
	vec3 off = d - pd * dot(d, pd);
	return vec3(dot(off, ee) / rad, dot(off, nn) / rad, dot(d, pd));
}

// A small lit moon: premultiplied radiance and coverage.
vec4 wonder_moon(vec3 d, vec3 eq, float deg, vec3 albedo, float px) {
	vec3 pd = normalize(transpose(celestial) * normalize(eq));
	float rad = radians(deg) * 0.5;
	vec3 ee, nn;
	vec3 q = wonder_frame_q(d, pd, rad, ee, nn);
	float r = length(q.xy);
	if (q.z < 0.0 || r > 1.0 + 3.0 * px / rad) {
		return vec4(0.0);
	}
	float cover = 1.0 - smoothstep(1.0 - px / rad, 1.0 + px / rad, r);
	vec2 qc = q.xy / max(r, 1.0);
	float z = sqrt(max(1.0 - dot(qc, qc), 0.0));
	vec3 n = ee * qc.x + nn * qc.y - pd * z;
	float lit = smoothstep(-0.05, 0.25, dot(n, sun_dir));
	float mott = 0.75 + 0.25 * textureLod(sky_noise, qc * 0.35 + eq.xy, 0.0).r;
	return vec4(albedo * mott * (lit + 0.03) * cover, cover);
}

// The ringed giant: premultiplied radiance and coverage (its disc; the rings add light without hiding much).
vec4 wonder_planet(vec3 d, float px) {
	vec3 pd = normalize(transpose(celestial) * normalize(wonder_planet_eq));
	float rad = radians(wonder_planet_deg) * 0.5;
	vec3 ee, nn;
	vec3 q = wonder_frame_q(d, pd, rad, ee, nn);
	if (q.z < 0.0 || length(q.xy) > 2.6) {
		return vec4(0.0);
	}
	vec3 axis = normalize(wonder_ring_axis);             // in (ee, nn, toward us)
	vec3 axis_w = normalize(ee * axis.x + nn * axis.y - pd * axis.z);
	float r = length(q.xy);
	float edge = px / rad;
	float cover = 1.0 - smoothstep(1.0 - edge, 1.0 + edge, r);
	vec3 L = vec3(0.0);
	float zs = sqrt(max(1.0 - r * r, 0.0));              // the near surface's depth toward us (disc radii)
	if (r < 1.0 + edge) {
		vec2 qc = q.xy / max(r, 1.0);
		float z = sqrt(max(1.0 - dot(qc, qc), 0.0));
		vec3 n = ee * qc.x + nn * qc.y - pd * z;
		float mu = dot(n, sun_dir);
		float lit = smoothstep(-0.12, 0.35, mu);
		// bands along the planet's latitude (the ring axis is its pole), warped by the noise
		float lat = dot(n, axis_w);
		vec2 nuv = vec2(dot(n, ee), lat) * 0.6;
		float warp = textureLod(sky_noise, nuv + vec2(0.13, 0.71), 0.0).r - 0.5;
		float b = lat * 9.0 + warp * 1.6;
		float band = 0.5 + 0.5 * sin(b);
		float fine = 0.5 + 0.5 * sin(b * 3.7 + warp * 4.0);
		vec3 c1 = vec3(0.98, 0.72, 0.38);   // amber
		vec3 c2 = vec3(0.62, 0.22, 0.10);   // deep rust
		vec3 c3 = vec3(0.20, 0.55, 0.68);   // teal, near the poles
		vec3 alb = mix(c2, c1, band);
		alb = mix(alb, alb * 0.65, fine * 0.6);
		alb = mix(alb, c3, smoothstep(0.55, 0.9, abs(lat)));
		// a storm eye
		vec2 eye = vec2(dot(n, ee) - 0.25, lat + 0.32);
		alb = mix(alb, vec3(0.92, 0.5, 0.32), 0.6 * (1.0 - smoothstep(0.04, 0.12, length(eye * vec2(1.0, 2.2)))));
		// the lit rim (its air) and the night side's faint glow
		float rim = pow(1.0 - z, 3.0);
		L = alb * wonder_planet_bright * lit * (0.85 + 0.15 * z) + vec3(0.55, 0.75, 1.0) * rim * lit * wonder_planet_bright * 0.6;
		L += alb * 0.02 * wonder_planet_bright;
		L *= cover;
	}
	// the rings: where the pixel's line crosses the ring plane (P . axis = 0) between 1.35 and 2.45 radii
	if (abs(axis.z) > 1e-3) {
		float zr = -(q.x * axis.x + q.y * axis.y) / axis.z;
		float rr = length(vec3(q.xy, zr));
		if (rr > 1.35 && rr < 2.45) {
			bool hidden = r < 1.0 && zr < zs;                // behind the planet's near side
			if (!hidden) {
				float t = (rr - 1.35) / 1.1;
				float rings = 0.55 + 0.45 * sin(t * 40.0) * sin(t * 13.0 + 1.3);
				rings *= smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.92, 1.0, t)) * (1.0 - 0.7 * smoothstep(0.42, 0.47, t) * (1.0 - smoothstep(0.5, 0.55, t)));
				// the planet's shadow on the rings: the ring point behind the planet seen from the sun
				vec3 pw = ee * q.x + nn * q.y - pd * zr;     // the ring point (disc radii, from the planet's centre)
				vec3 s = sun_dir;
				float along = dot(pw, s);
				float shadow = (along < 0.0 && length(pw - s * along) < 1.0) ? 0.15 : 1.0;
				float lit = 0.35 + 0.65 * abs(dot(axis_w, sun_dir));
				vec3 rc = mix(vec3(0.85, 0.74, 0.58), vec3(0.62, 0.66, 0.72), t);
				L += rc * rings * lit * shadow * wonder_planet_bright * 0.75;
			}
		}
	}
	return vec4(L, cover);
}

// The etherium: violet, teal and gold clouds of light on the celestial sphere (0..1 mask and colour).
vec3 wonder_nebula(vec3 d) {
	vec3 c = normalize(celestial * d);
	// triplanar samples of the noise (no stretched streaks where one projection runs edge-on)
	vec3 w = pow(abs(c), vec3(4.0));
	w /= w.x + w.y + w.z;
	float a = textureLod(sky_noise, c.yz * 0.55 + 0.1, 0.0).r * w.x + textureLod(sky_noise, c.zx * 0.55 + 0.3, 0.0).r * w.y
			+ textureLod(sky_noise, c.xy * 0.55 + 0.5, 0.0).r * w.z;
	float b = textureLod(sky_noise, c.yz * 1.1 + 0.6, 0.0).g * w.x + textureLod(sky_noise, c.zx * 1.1 + 0.2, 0.0).g * w.y
			+ textureLod(sky_noise, c.xy * 1.1 + 0.8, 0.0).g * w.z;
	float e = textureLod(sky_noise, c.yz * 2.3 + 0.4, 0.0).b * w.x + textureLod(sky_noise, c.zx * 2.3 + 0.9, 0.0).b * w.y
			+ textureLod(sky_noise, c.xy * 2.3 + 0.15, 0.0).b * w.z;
	// a broad band (a different plane from the Milky Way's), clumped by the noise
	vec3 plane = normalize(vec3(0.42, -0.71, 0.56));
	float band = exp(-pow(dot(c, plane), 2.0) * 4.0);
	float m = smoothstep(0.38, 0.78, a * 0.65 + b * 0.55) * (0.3 + 0.7 * band);
	float wisps = smoothstep(0.5, 0.8, e * 0.6 + a * 0.4) * band;
	vec3 violet = vec3(0.55, 0.32, 1.0);
	vec3 teal = vec3(0.22, 0.85, 0.95);
	vec3 gold = vec3(1.0, 0.62, 0.32);
	vec3 col = mix(violet, teal, smoothstep(0.35, 0.65, b));
	col = mix(col, gold, smoothstep(0.62, 0.85, a) * 0.75);
	return col * (m + 0.5 * wisps);
}

// --- The tear (the story's reveal, mission 11 "Two Fires": SkyTear, scripts/world/env/sky_tear.gd) -------------------
// Two sky ships' fight breaks the night sky like a pane: a jagged star of cracks runs out from tear_dir, each a gap with
// the wonder behind it (the etherium's own light glowing in it, the lips lit by that light, a dark rim on the sky just
// outside them: a break, not a bolt of lightning); through the gaps (then the shards that fall away from the centre
// outward) the wonder shows at full even while `wonder` is low; at tear_amount 1 the whole sky is open and the wonder
// (rising to 1 meanwhile: EnvironmentRig.reveal_wonder) takes over, the cracks fading as it does. Off (one branch) while
// tear_amount is 0. Held small (SkyTear's hold, tear_amount ~0.1: a star of cracks ~20 deg across) while the story watches
// something else (the cutter falling), then it runs on.
//   The cracks: an anisotropic Voronoi network in the tear's conformal log-polar frame (log tan(theta/2), azimuth; the
//   sphere as a cylinder with the tear at one pole), its shards long along the radius. The edges running out along the
//   radius are the cracks; the more across the radius an edge runs the thinner it is drawn, and right across not at all
//   (so a crack never floats loose of the star), but for a few cross cracks near the point struck. Each arm of the star
//   (the boundary between two columns of shards round the centre) has its own reach (half to 1.3x the front's) and a
//   quarter of them are not cracked at all: a star, not a sigil. Each crack's line is jagged by the fractal noise along
//   it, its gap widest near the point and tapering to its tip. The cracks reach out to a front ragged by azimuth and
//   widen as the tear goes on; the shards open from the centre outward behind them.
// impact_flash: a sky-wide brightening for a hit (strongest toward impact_flash_dir when one is given).
uniform float tear_amount = 0.0;                        // 0 none .. 1 the whole sky open
uniform vec3 tear_dir = vec3(0.6, 0.62, -0.5);          // toward the tear's centre (world; normalised in use)
uniform float tear_seed = 0.0;                          // another network
uniform vec3 tear_lip_color = vec3(0.36, 0.8, 1.0);    // the cracks' lips, lit from behind by the etherium: teal
uniform vec3 tear_lip_color2 = vec3(0.68, 0.48, 1.0);  // ... or violet (by crack)
uniform float tear_lip_bright = 0.1;                   // their radiance (sky units; the night's exposure is ~5x)
uniform vec3 tear_glow_color = vec3(0.5, 0.34, 1.0);   // the etherium's light: in the cracks, round the point struck
uniform float tear_glow_bright = 0.05;
uniform float tear_inner_bright = 0.07;                 // the etherium's own light pouring through a fresh crack
uniform float tear_rim_dark = 0.85;                     // the sky just outside the lips: this much darker
uniform float impact_flash = 0.0;                       // 0..1: a hit's flash over the sky (SkyTear.flash)
uniform vec3 impact_flash_dir = vec3(0.0);              // toward the hit (zero: the whole sky evenly)
uniform vec3 impact_flash_color = vec3(1.0, 0.84, 0.6);

const float TEAR_TAU = 6.2831853;
const float TEAR_M = 10.0;          // shards round the centre (whole: the network wraps in azimuth)
const float TEAR_S = 1.5;           // a shard's length along the radius over its width (each ring of shards 2.6x further
                                    // out than the one inside it: the log-polar frame)

// The tear's frame: theta from tear_dir, the azimuth round it, sin theta.
vec3 tear_polar(vec3 d) {
	vec3 td = normalize(tear_dir);
	vec3 up = abs(td.y) > 0.98 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 tn = normalize(up - td * dot(up, td));
	vec3 te = cross(td, tn);
	float ct = clamp(dot(d, td), -1.0, 1.0);
	return vec3(acos(ct), atan(dot(d, tn), dot(d, te)), sqrt(max(1.0 - ct * ct, 1e-8)));
}

// How far out the cracks reach (rad) toward azimuth ph: further in some directions (smooth in azimuth: a front ragged
// pixel by pixel cuts the cracks' light into radial slivers). ~10 deg at 0.1 (the hold), ~60 at 0.5, all the sky by 1.
float tear_reach(float ph) {
	float t = tear_amount;
	float ragged = textureLod(sky_noise, vec2(ph / TEAR_TAU * 2.0, 0.37 + 0.13 * tear_seed), 4.5).r;
	return radians(3.0 + 172.0 * pow(t, 1.4)) * (0.45 + 1.1 * ragged);
}

// How far out the shards have fallen away (rad): from 0.35 of the tear, about 10 deg at 0.5, 45 at 0.7, 120 at 0.9.
float tear_open_radius() {
	float x = max(tear_amount - 0.35, 0.0);
	return radians(160.0 * pow(x, 1.4) + 600.0 * pow(x, 4.0) - 1.0);
}

// A cell's feature point (offset in the cell) and its own random; m: cells round the centre (the azimuth wraps).
vec3 tear_cell(vec2 c, float m, float oct) {
	vec3 h = hash33(vec3(c.x, mod(c.y, m), tear_seed * 17.0 + oct * 5.3) + 0.5);
	return vec3(0.15 + 0.7 * h.xy, h.z);
}

float tear_cell_id(vec2 c, float m) {
	return c.x * m + mod(c.y, m);
}

// The shard whose feature point is at `c` (squashed cell coordinates: x along the radius, y round the centre): open
// 0..1. A shard falls away once the opening has passed it, and only where the cracks have already reached.
float tear_shard_open(vec2 c, float h, float r_open) {
	float k = TEAR_M / TEAR_TAU;
	float th = 2.0 * atan(exp(c.x * TEAR_S / k));
	float r = min(r_open, tear_reach(c.y / k) * 0.9);
	return clamp((r - th * (0.8 + 0.4 * h)) / radians(5.0), 0.0, 1.0);
}

// The soft light of the tear (no detail): the radiance map's share (it lights the land) and the clouds'.
vec3 tear_lobe(vec3 d) {
	float th = acos(clamp(dot(d, normalize(tear_dir)), -1.0, 1.0));
	float fade = 1.0 - smoothstep(0.5, 1.0, wonder);
	float t = tear_amount;
	return tear_glow_color * tear_glow_bright * fade * min(t * 3.0, 1.0)
			* (0.25 * exp(-th / radians(25.0 + 60.0 * t)) + 0.1) * (1.0 + 1.5 * impact_flash);
}

// The impact flash toward d (radiance at impact_flash 1): a glow round the hit, a little over the whole sky.
vec3 tear_flash(vec3 d) {
	float shape = dot(impact_flash_dir, impact_flash_dir) > 0.25
			? 0.1 + pow(max(dot(d, normalize(impact_flash_dir)), 0.0), 12.0) : 0.3;
	return impact_flash_color * impact_flash * shape * 0.035;
}

// A crack's jag: its line's offset from the straight edge (cell units, +- ~0.5 x amp) at `s` along it (cell units);
// `row` picks the crack's own stretch of the fractal noise.
float tear_jag(float s, float row, float lod) {
	return textureLod(sky_noise, vec2(s * 0.37, row), lod).b - 0.5;
}

// The tear toward d: its own light (the lips, radiance before the air); in `open` how much of the wonder shows there at
// full (the gaps, the hole struck, the fallen shards); in `dark` how much darker the sky is there (the rims outside the
// lips); in `inner` how much of the etherium's own light pours through there (a fresh crack: the sky adds it, the
// nebula's colour, tear_inner_bright). px: the pixel's angular size (rad).
vec3 sky_tear(vec3 d, float px, out float open, out float dark, out float inner) {
	open = 0.0;
	dark = 0.0;
	inner = 0.0;
	float t = tear_amount;
	vec3 pol = tear_polar(d);
	float th = pol.x;
	float ph = pol.y;
	float sn = pol.z;
	float fade = 1.0 - smoothstep(0.5, 1.0, wonder);   // the wonder takes over: the cracks go
	float boost = 1.0 + 1.5 * impact_flash;              // a hit flares them
	float reach = tear_reach(ph);
	float r_open = tear_open_radius();
	float all_open = smoothstep(0.9, 1.0, t);
	float aa = max(px, radians(0.01));                    // a pixel (the edges' antialiasing)
	float rimw = 4.0 * aa;                                 // the dark rim's width
	// the point struck: the etherium's faint light round it while the break is young, and the hole the shot punched
	// (jagged, its lip lit, its rim dark)
	vec3 L = tear_glow_color * tear_glow_bright * exp(-th / radians(1.5 + 4.0 * t)) * (1.0 - smoothstep(0.15, 0.45, t));
	float rag = textureLod(sky_noise, vec2(ph / TEAR_TAU * 2.0, 0.61 + 0.13 * tear_seed), 4.0).r;
	float r_hole = radians(0.4 + 6.0 * min(t, 0.3)) * (0.7 + 0.6 * rag);   // (lumpy, not spiked; the shards take over)
	float hole = 1.0 - smoothstep(r_hole - 0.5 * aa, r_hole + 0.5 * aa, th);
	float hole_lip = exp(-abs(th - r_hole) / (0.7 * aa));
	float hole_rim = th > r_hole ? exp(-(th - r_hole) / rimw) : 0.0;
	if (th > reach * 1.2 && th > r_open + radians(10.0)) {
		open = all_open;
		return L * fade * boost;
	}
	// the conformal frame in cells: x along the radius, y round the centre (period TEAR_M); isotropic
	float k = TEAR_M / TEAR_TAU;
	float rho = log(max(sn / (1.0 + cos(th)), 1e-6));
	float unit = sn / k;                     // the angle (rad) one cell unit spans here
	float cell_px = unit / max(px, 1e-6);    // ... in pixels
	vec2 x = vec2(rho, ph) * k;
	// a gentle warp (the cracks bend; their jag is drawn along each below), its stretch kept under ~0.5 (a stronger one
	// smears the lines into streaks); periodic round the centre
	vec2 wq = x * (3.0 / TEAR_M) + vec2(0.17, 0.29) * tear_seed;
	float wlod = log2(max(512.0 * 3.0 / TEAR_M / max(cell_px, 1e-3), 1.0));
	vec2 warp = vec2(textureLod(sky_noise, wq, wlod).r, textureLod(sky_noise, wq + vec2(0.5, 0.31), wlod).r) - 0.5;
	x += warp * 0.08;
	float jlod = log2(max(512.0 * 0.37 / max(cell_px, 1e-3), 1.0));
	// the shards: the nearest feature point (in the squashed frame: long along the radius), then the edges round it
	vec2 p = vec2(x.x / TEAR_S, x.y);
	vec2 n = floor(p);
	vec2 f = p - n;
	float md = 8.0;
	vec2 mr = vec2(0.0);
	vec2 mg = vec2(0.0);
	float mh = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec3 o = tear_cell(n + g, TEAR_M, 0.0);
			vec2 r = g + o.xy - f;
			float dd = dot(r, r);
			if (dd < md) {
				md = dd;
				mr = r;
				mg = g;
				mh = o.z;
			}
		}
	}
	// the edges of that shard: the bisectors with its neighbours (the nearest is the shard's own border; the far
	// bisectors of cells that do not touch it are left out)
	vec4 nb[9];
	float dmin = 8.0;
	for (int q = 0; q < 9; q++) {
		vec2 g = mg + vec2(float(q % 3 - 1), float(q / 3 - 1));
		vec3 o = tear_cell(n + g, TEAR_M, 0.0);
		vec2 r = g + o.xy - f;
		vec2 e = r - mr;
		float db = 8.0;
		if (dot(e, e) > 1e-6) {
			vec2 nn = normalize(e);
			db = dot(0.5 * (mr + r), nn) / length(vec2(nn.x / TEAR_S, nn.y));   // in real cell units
		}
		nb[q] = vec4(db, r, o.z);
		dmin = min(dmin, db);
	}
	float ida = tear_cell_id(n + mg, TEAR_M);
	float oa = r_open > 0.0 ? max(tear_shard_open(p + mr, mh, r_open), all_open) : all_open;
	float wmax = radians(0.1 + 0.9 * t) * (1.0 + 1.5 * exp(-th / radians(4.0)));   // the gaps: wider with time, near the point
	float tip = max(reach * 0.12, radians(1.0));
	float gap = 0.0;
	float lip = 0.0;
	float rimd = 0.0;
	float hue = 0.0;
	for (int q = 0; q < 9; q++) {
		float db = nb[q].x;
		float near = 1.0 - smoothstep(0.0, 0.25, db - dmin);
		if (db > 7.0 || near <= 0.0) {
			continue;
		}
		vec2 g = mg + vec2(float(q % 3 - 1), float(q / 3 - 1));
		vec2 r = nb[q].yz;
		float ob = r_open > 0.0 ? max(tear_shard_open(p + r, nb[q].w, r_open), all_open) : all_open;
		float idb = tear_cell_id(n + g, TEAR_M);
		float eh = hash13(vec3(min(ida, idb), max(ida, idb), tear_seed * 7.0 + 3.0));
		// the arm of the star this edge is on (the boundary between two columns of shards round the centre)
		float ya = mod(n.y + mg.y, TEAR_M);
		float dy = mod(n.y + g.y - ya, TEAR_M);
		float arm = dy > TEAR_M - 1.5 ? mod(ya - 1.0, TEAR_M) : ya;
		float ah = hash13(vec3(arm, tear_seed * 3.1 + 1.7, 7.0));
		// the edge's normal in the real frame: along the azimuth for a crack running out along the radius
		vec2 e = r - mr;
		vec2 nr = normalize(vec2(e.x / TEAR_S, e.y));
		float wk = smoothstep(0.2, 0.7, nr.y * nr.y) * step(0.25, ah);   // across the radius thinner; a quarter of the arms whole
		wk = max(wk, step(eh, 0.45) * (1.0 - smoothstep(0.2, 0.4, th / max(reach, 1e-4))));   // a few cross cracks near the point
		float re = reach * mix(0.5, 1.3, fract(ah * 7.7)) * (0.92 + 0.16 * fract(eh * 3.7));   // each arm's own reach
		float reached = 1.0 - smoothstep(re - tip, re, th);
		float taper = pow(clamp(1.0 - th / re, 0.0, 1.0), 0.7);
		float crack = wk * reached * (1.0 - oa) * (1.0 - ob);
		float rim = abs(oa - ob);                              // the broken edge where a shard has fallen away
		float lit = max(crack, rim) * near;
		if (lit <= 0.0) {
			continue;
		}
		// the jag: the line off the straight edge by the fractal noise along it, the same seen from either shard (its
		// side and its direction by the two shards' ids)
		float sg = ida < idb ? 1.0 : -1.0;
		vec2 mid = 0.5 * (mr + r);
		float along = sg * dot(-vec2(mid.x * TEAR_S, mid.y), vec2(-nr.y, nr.x));
		float jag = 0.07 * tear_jag(along, fract(eh * 13.7), jlod);
		float dl = abs(db - sg * jag) * unit;                // to the crack's line (rad)
		float w = crack * wmax * (0.5 + fract(eh * 7.31)) * taper;   // this crack's gap (half-width)
		float wv = max(w, 0.5 * aa);                         // ... a hairline still a line a pixel wide
		float in_gap = (1.0 - smoothstep(wv - 0.5 * aa, wv + 0.5 * aa, dl)) * (w / wv) * lit;
		float lp = lit * exp(-abs(dl - wv) / (0.7 * aa)) * (0.5 + 0.5 * taper);
		if (lp > lip) {
			lip = lp;
			hue = fract(eh * 5.13);
		}
		gap = max(gap, in_gap);
		rimd = max(rimd, lit * (dl > wv ? exp(-(dl - wv) / rimw) : 0.0));
	}
	float fine = smoothstep(3.0, 8.0, cell_px);           // where the shards are a few pixels the network goes (the hole)
	gap *= fine;
	lip *= fine;
	rimd *= fine;
	open = max(max(oa, gap), hole);
	float young = 1.0 - 0.6 * t;
	inner = max(gap * young, hole * young) * fade;
	dark = clamp(max(rimd, hole_rim) * tear_rim_dark * (1.0 - open), 0.0, 1.0) * fade;
	float shim = 0.92 + 0.08 * sin(sky_time * 1.3 + hue * 40.0);   // a slow shimmer (no flicker: not lightning)
	L += mix(tear_lip_color, tear_lip_color2, step(0.5, hue)) * tear_lip_bright * max(lip, hole_lip * (1.0 - smoothstep(0.4, 0.6, t))) * shim;
	return L * fade * boost;   // the lips flare with a hit, as the light past them does (above: no seam in a flash)
}
