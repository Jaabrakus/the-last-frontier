// Frontier dynamic sky (package A sky system). Owner: package A.
//
// A physically based single-scattering atmosphere (Rayleigh + Mie + ozone absorption, analytic
// Chapman optical depths, a cheap isotropic multiple-scattering term) lit by the sun and, at
// night, by the moon; an analytic limb-darkened sun disc; the moon's near side with its phase (lit
// hemisphere facing the sun), earthshine and a halo; stars and a faint Milky Way on the celestial
// sphere (they turn with sidereal time and fade by themselves because the sky's own radiance hides them by day);
// the cloud engine (cloud_engine.gdshaderinc: volumetric cumulus, stratocumulus and storm towers at
// their real heights over the curved Earth, rain shafts, lightning, cirrus) whose weather comes from
// WeatherSystem. The numpy reference is tools/environment/lighting/atmosphere.py; the CPU side
// (sun / moon light colour, irradiance, fog colour) is scripts/world/env/sky_model.gd, the clouds'
// CPU mirror scripts/world/env/cloud_field.gd.
//
// Passes (Godot sky subpasses):
//   quarter-res  the atmosphere (the expensive integral, smooth everywhere)
//   half-res     the clouds (raymarched), composited premultiplied (colour * alpha, alpha)
//   full-res     atmosphere + stars + moon + sun disc, then the clouds on top (they pass in front of the sun and
//                the moon), then lightning strokes. The discs' sizes are artistic (scripts/world/env/sky_bodies.gd:
//                SUN_DISC_SCALE, MOON_DISC_SCALE), their positions astronomical (WorldClock).
//   cubemap      (radiance / ambient / reflections / fog colour) atmosphere + an analytic, noise-free
//                cloud cover; no sun disc (the DirectionalLight gives the direct light and its
//                specular), no stars or moon disc.
// Cloud drift and star twinkle come from the global uniforms sky_time and sky_cloud_offset. The
// radiance map is re-rendered every frame (Sky.PROCESS_MODE_REALTIME, 256), so its cloud term is
// kept to one analytic sample per texel.

shader_type sky;
render_mode use_half_res_pass, use_quarter_res_pass;

global uniform float sky_time;          // seconds, wraps every hour (twinkle)
global uniform vec4 sky_cloud_offset;   // metres the clouds have drifted with the wind: xy low / mid clouds, zw cirrus

// --- Atmosphere (set by EnvironmentRig from WorldClock / weather) --------------------------------
uniform vec3 sun_dir = vec3(-0.6384, 0.3272, 0.6967);   // toward the sun (may be below the horizon)
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);           // toward the moon
uniform float sun_intensity = 11.4;       // top-of-atmosphere sun irradiance (panorama units)
uniform float moon_sky_intensity = 0.0;   // moonlight scattered by the atmosphere (artistic, x phase)
uniform float mie_density = 4.0;          // aerosol haze (x a clear standard atmosphere)
uniform float mie_g = 0.75;
uniform float ms_factor = 1.0;            // multiple-scattering approximation
uniform float sky_saturation = 0.85;      // < 1: hazier, whiter sky
uniform vec3 night_glow = vec3(0.00035, 0.0005, 0.0009);   // airglow / scattered starlight floor
uniform float overcast = 0.0;             // 0..1: grey the whole sky under a cloud deck
uniform vec3 overcast_color = vec3(0.5, 0.52, 0.55);       // radiance of a full deck (rig: from irradiance)
uniform vec3 ground_radiance = vec3(0.1, 0.1, 0.07);       // below the horizon (albedo x irradiance / pi): lighting
// The ground as drawn below the horizon (seen past the terrain's edge from high ground), following the light (DayNight);
// the radiance map keeps ground_radiance above, which the level's lighting is tuned with.
uniform vec3 ground_view_radiance = vec3(0.1, 0.1, 0.07);
uniform float ground_blend_deg = 3.0;

// --- Sun and moon discs (set every frame by scripts/world/env/sky_bodies.gd) ---------------------
uniform vec3 sun_disc_color = vec3(60.0, 48.0, 34.0);     // disc radiance (already x transmittance)
uniform float sun_size_deg = 1.066;                        // drawn diameter (the real 0.533 x SUN_DISC_SCALE)
uniform float sun_limb_darkening = 0.55;                   // at the limb, green (red less, blue more)
uniform vec3 sun_glow_color = vec3(1.0, 0.8, 0.57);        // small glow around the disc (x transmittance)
uniform float sun_glow_width_deg = 0.8;                    // its e-folding width beyond the limb
// The glare: within glare_radius_deg of the sun the sky's radiance above glare_knee is rolled off (toward twice the
// knee), as the eye adapts locally to the bright sky round the sun; the knee follows the exposure (just under the
// tonemapper's white), so a low sun's disc is not lost in a white blowout. Background only (the radiance map,
// ambient and fog keep the full sky).
uniform float glare_knee = 1e6;
uniform float glare_radius_deg = 25.0;
uniform vec3 moon_color = vec3(0.2, 0.194, 0.184);         // radiance of the full moon's highlands (x transmittance)
uniform float moon_size_deg = 1.3;                         // drawn diameter (the real ~0.52 x MOON_DISC_SCALE)
uniform vec3 moon_north = vec3(0.0, 1.0, 0.0);             // world direction of the moon's north pole
uniform float earthshine = 0.05;                           // the dark side at new moon (x moon_color)
uniform vec3 moon_halo = vec3(0.0);                        // the halo's radiance at the limb (night)
uniform float moon_glare = 0.0;                            // 0..1: how much its glare hides the stars next to it
// The near side (tools/environment/sky/make_moon_map.py): north up, selenographic east (Crisium) to the right.
uniform sampler2D moon_albedo : filter_linear_mipmap, hint_default_white;

// --- Stars --------------------------------------------------------------------------------------
uniform mat3 celestial = mat3(1.0);        // world direction -> equatorial (RA/Dec) unit vector
uniform float star_intensity = 0.06;
uniform float star_size = 0.0009;
// The real sky (Yale Bright Star Catalog, tools/environment/sky/bake_star_map.py): equirectangular in RA / Dec
// (J2000), sqrt-encoded flux (V = 0 -> 1).
uniform sampler2D star_map : filter_linear, repeat_enable, hint_default_black;
uniform float star_map_intensity = 1.0;          // angular radius (rad) of a star's glow: about a pixel at 1080p
uniform float milky_way = 0.0012;

// --- Clouds (the cloud engine's own uniforms are in cloud_engine.gdshaderinc) ------------------
uniform sampler2D sky_noise : filter_linear_mipmap, repeat_enable, hint_default_black;
uniform float cirrus_coverage = 0.0;   // no cirrus streaks (user 2026-09-26); WeatherSystem keeps it 0
uniform float cirrus_height = 9000.0;
uniform float cirrus_tile_m = 26000.0;
uniform vec3 cloud_light_dir = vec3(-0.6384, 0.3272, 0.6967);   // key light (sun or moon)
uniform vec3 cloud_light_color = vec3(7.0, 5.6, 4.0);             // its radiance at the low clouds (1.5 km)
uniform vec3 cloud_ambient = vec3(0.35, 0.4, 0.5);                // sky light on the clouds
uniform float lightning = 0.0;            // sky-wide flash of nearby lightning 0..1

const float R_G = 6360e3;
const float R_T = 6460e3;
const float H_R = 8000.0;
const float H_M = 1200.0;
const vec3 BETA_R = vec3(5.802e-6, 13.558e-6, 33.1e-6);
const float BETA_M = 3.996e-6;
const vec3 BETA_O = vec3(0.650e-6, 1.881e-6, 0.085e-6);
const float OZONE_COLUMN = 15000.0;
const float OZONE_R = 6385e3;
const float CAM_ALT = 200.0;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

// Schueler 2012: Chapman grazing-incidence function x exp(-h), h and X in scale heights.
float chapman(float X, float h, float mu) {
	float c = sqrt(X + h);
	if (mu >= 0.0) {
		return c / (c * mu + 1.0) * exp(-h);
	}
	float x0 = sqrt(max(1.0 - mu * mu, 0.0)) * (X + h);
	float c0 = sqrt(x0);
	return 2.0 * c0 * exp(min(X - x0, 60.0)) - c / (1.0 - c * mu) * exp(-h);
}

// RGB optical depth from altitude alt toward zenith cosine mu, out of the atmosphere.
vec3 depth_to_space(float alt, float mu) {
	float r = R_G + alt;
	float tr = H_R * chapman(R_G / H_R, alt / H_R, mu);
	float tm = H_M * chapman(R_G / H_M, alt / H_M, mu);
	float sin2 = (r / OZONE_R) * (r / OZONE_R) * (1.0 - mu * mu);
	float slant = inversesqrt(max(1.0 - sin2, 0.02));
	float grazing = mu >= -sqrt(max(1.0 - (R_G / r) * (R_G / r), 0.0)) ? 1.0 : 2.0;
	return BETA_R * tr + vec3(BETA_M * 1.11 * mie_density) * tm + BETA_O * (OZONE_COLUMN * slant * grazing);
}

float phase_r(float c) {
	return 0.0596831 * (1.0 + c * c);
}

float phase_m(float c, float g) {
	float g2 = g * g;
	return 0.1193662 * (1.0 - g2) * (1.0 + c * c) / ((2.0 + g2) * pow(max(1.0 + g2 - 2.0 * g * c, 1e-4), 1.5));
}

// In-scattered radiance along d (horizon-clamped, unit) and the view transmittance to space.
vec3 atmosphere(vec3 d, int steps, out vec3 trans) {
	float r0 = R_G + CAM_ALT;
	float mu = d.y;
	float b = r0 * mu;
	float t_top = -b + sqrt(b * b - r0 * r0 + R_T * R_T);
	float cs = dot(d, sun_dir);
	float prs = phase_r(cs);
	float pms = phase_m(cs, mie_g);
	float cm = dot(d, moon_dir);
	float prm = phase_r(cm);
	float pmm = phase_m(cm, mie_g);
	bool moon_on = moon_sky_intensity > 0.0;
	vec3 tau = vec3(0.0);
	vec3 L = vec3(0.0);
	float prev = 0.0;
	float fs = float(steps);
	for (int i = 0; i < steps; i++) {
		float e1 = (exp(float(i + 1) / fs * 4.0) - 1.0) / 53.59815;
		float s1 = e1 * t_top;
		float ds = s1 - prev;
		float s = prev + 0.5 * ds;
		prev = s1;
		vec3 p = vec3(d.x * s, r0 + d.y * s, d.z * s);
		float r = length(p);
		float alt = max(r - R_G, 0.0);
		float rr = exp(-alt / H_R);
		float rm = exp(-alt / H_M) * mie_density;
		vec3 ext = BETA_R * rr + vec3(BETA_M * 1.11 * rm);
		tau += ext * (0.5 * ds);
		vec3 up = p / r;
		vec3 iso = (BETA_R * rr + vec3(BETA_M * rm)) * (ms_factor * 0.0795775);
		vec3 ts = depth_to_space(alt, dot(up, sun_dir));
		vec3 sca = BETA_R * (rr * prs) + vec3(BETA_M * rm * pms);
		L += (exp(-(tau + ts)) * sca + iso * exp(-(tau + 0.25 * ts))) * (sun_intensity * ds);
		if (moon_on) {
			vec3 tm = depth_to_space(alt, dot(up, moon_dir));
			vec3 scm = BETA_R * (rr * prm) + vec3(BETA_M * rm * pmm);
			L += (exp(-(tau + tm)) * scm + iso * exp(-(tau + 0.25 * tm))) * (moon_sky_intensity * ds);
		}
		tau += ext * (0.5 * ds);
	}
	trans = exp(-tau);
	float l = dot(L, LUMA);
	return vec3(l) + (L - vec3(l)) * sky_saturation;
}

// Sky radiance for any direction: atmosphere above the horizon, blended to the ground below,
// greyed toward an overcast deck.
vec3 sky_color(vec3 d, int steps, vec3 ground, out vec3 trans) {
	vec3 dh = normalize(vec3(d.x, max(d.y, 0.0), d.z));
	vec3 col = atmosphere(dh, steps, trans) + night_glow;
	float below = degrees(asin(clamp(-d.y, -1.0, 1.0)));
	col = mix(col, overcast_color * (0.75 + 0.35 * max(d.y, 0.0)), overcast);
	col = mix(col, ground, smoothstep(0.0, ground_blend_deg, below));
	trans *= step(0.0, d.y) * (1.0 - overcast);
	return col;
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// The galactic plane (north galactic pole RA 192.86, Dec 27.13 deg): 0..1 across the band.
float mw_band(vec3 c) {
	vec3 ngp = vec3(-0.8676, -0.1981, 0.4560);
	return exp(-pow(dot(c, ngp), 2.0) * 16.0);
}

vec3 star_field(vec3 d) {
	vec3 c = normalize(celestial * d);
	vec3 L = vec3(0.0);
	// the catalogued stars where they really are (the constellations, Polaris over the pole)
	float ra = atan(c.y, c.x);
	float dec = asin(clamp(c.z, -1.0, 1.0));
	vec2 suv = vec2(fract(ra / 6.2831853), 0.5 - dec / 3.1415927);
	vec3 cat = textureLod(star_map, suv, 0.0).rgb;
	L += cat * cat * star_map_intensity / max(star_intensity, 1e-4);
	// a dense faint field of stars too dim to catalog (strongest along the Milky Way)
	for (int k = 2; k < 3; k++) {
		float S = k == 0 ? 90.0 : (k == 1 ? 190.0 : 330.0);
		float density = (k == 0 ? 0.22 : (k == 1 ? 0.3 : 0.28)) * (1.0 + 1.6 * mw_band(c));
		vec3 cell = floor(c * S);
		vec3 h = hash33(cell + float(k) * 17.0);
		if (h.x < density) {
			vec3 sp = normalize(cell + 0.2 + 0.6 * hash33(cell + 5.7));
			float a = length(c - sp);
			float sigma = star_size;
			float core = exp(-a * a / (2.0 * sigma * sigma));
			float mag = pow(h.y, k == 0 ? 4.0 : (k == 1 ? 7.0 : 11.0));
			float twinkle = 0.8 + 0.2 * sin(sky_time * (2.0 + 5.0 * h.z) + h.x * 40.0);
			vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.86, 0.7), h.z);
			L += tint * core * mag * twinkle;
		}
	}
	// Milky Way: the galactic plane (north galactic pole RA 192.86, Dec 27.13 deg), dusty.
	vec3 ngp = vec3(-0.8676, -0.1981, 0.4560);
	float band = exp(-pow(dot(c, ngp), 2.0) * 16.0);
	float dust = textureLod(sky_noise, c.xy * 0.9 + c.z * 0.37, 0.0).b;
	float core = exp(-pow(dot(c, ngp), 2.0) * 60.0);
	float lanes = smoothstep(0.35, 0.75, textureLod(sky_noise, c.yz * 1.7 + c.x * 0.5, 0.0).g);
	vec3 mw_col = mix(vec3(0.62, 0.66, 1.0), vec3(1.0, 0.78, 0.92), core);   // blue-white band, pink-violet core
	L += mw_col * milky_way * band * (0.3 + 1.2 * dust * dust + 0.8 * core) * (1.0 - 0.6 * lanes * core) / max(star_intensity, 1e-4);
	return L * star_intensity;
}

// The moon's disc toward d: premultiplied radiance and coverage (the disc hides the stars behind it, its dark part
// too). px: the pixel's angular size (rad): a limb antialiased over about a pixel and the map's mip level.
// Mirrored on the CPU by SkyBodies.moon_frame() / moon_sample() (tests/env/test_sun_moon.gd): keep them in step.
vec4 moon_disc(vec3 d, float px) {
	float rad = radians(moon_size_deg) * 0.5;
	float c = dot(d, moon_dir);
	vec3 off = d - moon_dir * c;
	if (c < 0.0 || length(off) > rad + 2.0 * px) {
		return vec4(0.0);
	}
	// the disc's frame: the moon's north up, its east (Mare Crisium) to the observer's right
	vec3 nn = normalize(moon_north - moon_dir * dot(moon_north, moon_dir));
	vec3 ee = cross(moon_dir, nn);
	vec2 q = vec2(dot(off, ee), dot(off, nn)) / rad;
	float r = length(q);
	float cover = 1.0 - smoothstep(1.0 - px / rad, 1.0 + px / rad, r);
	vec2 qc = q / max(r, 1.0);
	float z = sqrt(max(1.0 - dot(qc, qc), 0.0));
	vec3 n = ee * qc.x + nn * qc.y - moon_dir * z;
	// Lommel-Seeliger (the regolith: the full moon is evenly bright out to its limb), 1 at full; a soft terminator
	float mu0 = dot(n, sun_dir);
	float ls = min(2.0 * max(mu0, 0.0) / (max(mu0, 0.0) + max(z, 0.05)), 1.3);
	float lit = ls * smoothstep(0.0, 0.05, mu0);
	// earthshine: the Earth lights the dark side, as "full" as the moon is new; bluish
	float k = 0.5 * (1.0 - dot(sun_dir, moon_dir));
	vec3 es = vec3(0.8, 0.9, 1.0) * earthshine * (1.0 - k) * (1.0 - k);
	float lod = log2(max(256.0 * px / rad, 1.0));
	vec3 alb = textureLod(moon_albedo, vec2(0.5 + 0.5 * qc.x, 0.5 - 0.5 * qc.y), lod).rgb;
	return vec4(moon_color * alb * (vec3(lit) + es) * cover, cover);
}

#include "res://shaders/sky/cloud_engine.gdshaderinc"

void sky() {
	vec3 d = normalize(EYEDIR);
	if (AT_CUBEMAP_PASS) {
		vec3 tr;
		vec3 col = sky_color(d, 10, ground_radiance, tr);
		vec4 cl = ce_clouds_cheap(d, POSITION, col);
		COLOR = col * (1.0 - cl.a) + cl.rgb + vec3(0.8, 0.85, 1.0) * lightning * 0.08;
	} else if (AT_QUARTER_RES_PASS) {
		vec3 tr;
		COLOR = sky_color(d, 12, ground_view_radiance, tr);
		ALPHA = dot(tr, vec3(0.3333));
	} else if (AT_HALF_RES_PASS) {
		// step jitter: interleaved gradient noise (Jimenez), its pattern shifted each frame for the temporal AA. White noise
		// per pixel came through MetalFX and the half-res upscale as static in the clouds (user 2026-10-01: "the clouds have
		// static points"); this one is low-discrepancy, so neighbours differ smoothly and the frames average out.
		float fr = cloud_jitter_anim * mod(floor(sky_time * 60.0), 64.0);
		vec2 q = FRAGCOORD.xy + 5.588238 * fr;
		float jit = fract(52.9829189 * fract(dot(q, vec2(0.06711056, 0.00583715))));
		vec4 cl = ce_sky_clouds(d, POSITION, QUARTER_RES_COLOR.rgb, jit);
		COLOR = cloud_debug == 1 ? vec3(1.0 - cl.a) : cl.rgb;
		ALPHA = cloud_debug == 1 ? 1.0 : cl.a;
	} else {
		vec3 col = QUARTER_RES_COLOR.rgb;
		float tr = QUARTER_RES_COLOR.a;
		// the pixel's angular size (rad): the discs' antialiased edges, the moon map's mip level
		float px = max(length(dFdx(d)), length(dFdy(d)));
		float ang = 2.0 * asin(clamp(0.5 * length(d - sun_dir), 0.0, 1.0));
		float l = dot(col, LUMA);
		if (l > glare_knee) {
			float x = (l - glare_knee) / glare_knee;
			col *= mix(1.0, glare_knee * (1.0 + x / (1.0 + x)) / l, exp(-degrees(ang) / glare_radius_deg));
		}
		if (d.y > -0.02) {
			float above = smoothstep(-0.004, 0.004, d.y) * (1.0 - overcast);
			// the moon: its disc hides the stars behind it, its glare the stars near it; a faint halo at night
			vec4 moon = moon_disc(d, px);
			float m_ang = 2.0 * asin(clamp(0.5 * length(d - moon_dir), 0.0, 1.0));
			float m_out = degrees(max(m_ang - radians(moon_size_deg) * 0.5, 0.0));
			vec3 extra = star_field(d) * tr * (1.0 - moon.a) * (1.0 - moon_glare * exp(-degrees(m_ang) / 12.0));
			extra += (moon.rgb + moon_halo * (0.7 * exp(-m_out / 1.2) + 0.3 * exp(-m_out / 6.0))) * above;   // the halo is in the air in front of the disc too
			// the sun: a limb-darkened disc (the limb redder) and a narrow glow beyond its limb (the aureole
			// further out is the atmosphere's Mie term)
			float rad = radians(sun_size_deg) * 0.5;
			float rr = ang / rad;
			float mu = sqrt(max(1.0 - rr * rr, 0.0));
			float disc = 1.0 - smoothstep(1.0 - px / rad, 1.0 + px / rad, rr);
			vec3 limb = 1.0 - sun_limb_darkening * vec3(0.85, 1.0, 1.15) * (1.0 - mu);
			extra += (sun_disc_color * limb * disc
					+ sun_glow_color * exp(-degrees(max(ang - rad, 0.0)) / sun_glow_width_deg)) * above;
			col += extra;
		}
		col += vec3(0.8, 0.85, 1.0) * lightning * 0.25 * (0.4 + 0.6 * max(d.y, 0.0));
		vec4 cl = HALF_RES_COLOR;
		COLOR = col * (1.0 - cl.a) + cl.rgb;
		COLOR += ce_bolt(d, POSITION);
		if (cloud_debug == 1) {
			COLOR = HALF_RES_COLOR.rgb;
		}
	}
}
