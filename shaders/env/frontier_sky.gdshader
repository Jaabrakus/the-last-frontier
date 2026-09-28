// Frontier sky (look-dev spec 3.2, package A, focused lighting pass). Owner: package A.
//
// The Poly Haven HDRI qwantani_late_afternoon_puresky with its sun painted out
// (tools/environment/lighting/process_hdri.py -> assets/environment/sky/), rotated so its sun sits
// where the DirectionalLight "Sun" is, plus:
//   * a highlight roll-off of the photographed aureole: under AgX its raw radiance (up to ~29)
//     turned a third of the sky white and, through the fog's aerial perspective (which samples this
//     sky), laid a milky veil over everything seen toward the sun. Above `aureole_knee` the
//     radiance rolls off smoothly (asymptote 2 x knee) and takes on the sun's own colour, so the
//     sky near the sun reads warm (spec 2.2: #F4E4C2) instead of blown white;
//   * a small chroma gain on the upper hemisphere (AgX desaturates the hazy blue toward grey);
//   * an analytic sun disc (limb-darkened) and a small inner glow that follow LIGHT0, drawn only in
//     the background pass: the radiance cubemap (ambient light and reflections) never gets a second
//     sun, because the DirectionalLight already provides the direct light and its specular;
//   * a ground-bounce radiance below the horizon (warm earth, not the photo's mirrored sky), which
//     feeds ambient light from below;
//   * an optional horizon band tinted toward the fog colour so distant fogged terrain meets the sky.
// No TIME: the radiance map is only re-filtered when a parameter or the light changes.
// EnvironmentRig sets every uniform it tunes; the defaults are the high-preset look.
// Extending to a moving sun (time of day): everything that depends on the sun reads LIGHT0_*, so
// the disc, glow and aureole tint follow the light; only rotation_deg ties the photographed sky
// to one azimuth.

shader_type sky;

uniform sampler2D panorama : filter_linear, repeat_enable, hint_default_black;
// Multiplies the panorama (sky radiance at ambient/background energy 1).
uniform float panorama_energy = 1.0;
// World compass azimuth minus panorama azimuth, degrees (0 = north = -Z, 90 = east = +X).
uniform float rotation_deg = 6.37;

// Aureole roll-off: luminance above the knee is compressed (asymptote 2 x knee) and tinted toward
// the sun colour by aureole_warmth.
uniform float aureole_knee = 2.5;
uniform float aureole_warmth = 0.6;
// Chroma gain about luma for the sky above the horizon (1 = the photograph).
uniform float sky_saturation = 1.12;

// Linear radiance of the ground seen below the horizon (albedo x (sun + sky irradiance) / pi).
uniform vec3 ground_radiance = vec3(0.12, 0.11, 0.08);
// Below -ground_start_deg the sky fades into ground_radiance over ground_blend_deg.
uniform float ground_start_deg = 0.5;
uniform float ground_blend_deg = 6.0;

// Horizon band (|elevation| < horizon_band_deg) pulled toward horizon_color by horizon_amount.
uniform vec3 horizon_color = vec3(0.78, 0.8, 0.8);
uniform float horizon_amount = 0.0;
uniform float horizon_band_deg = 4.0;

// Sun disc radiance = LIGHT0 colour x energy x sun_disc_scale (blooms, clipped by the glow cap).
uniform float sun_disc_scale = 20.0;
// Disc diameter used when the light's angular distance is smaller (0 when PCSS is off).
uniform float sun_min_diameter_deg = 0.53;
uniform float sun_limb_darkening = 0.55;
// Inner glow = LIGHT0 colour x energy x sun_glow x exp(-angle / sun_glow_width_deg).
uniform float sun_glow = 1.0;
uniform float sun_glow_width_deg = 0.7;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);


vec3 panorama_radiance(vec3 d) {
	float az = atan(d.x, -d.z) - radians(rotation_deg);
	float u = fract(az / (2.0 * PI));
	float v = acos(clamp(d.y, -1.0, 1.0)) / PI;
	// Lod 0: the equirect seam would otherwise pick a tiny mip along u = 0.
	return textureLod(panorama, vec2(u, v), 0.0).rgb * panorama_energy;
}

vec3 sun_chroma() {
	vec3 c = LIGHT0_ENABLED ? LIGHT0_COLOR : vec3(1.0, 0.8, 0.57);
	return c / max(dot(c, LUMA), 1e-4);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float el = degrees(asin(clamp(d.y, -1.0, 1.0)));
	vec3 col = panorama_radiance(d);

	// Aureole roll-off and warmth.
	float l = dot(col, LUMA);
	if (l > aureole_knee) {
		float x = l - aureole_knee;
		float lo = aureole_knee + x / (1.0 + x / aureole_knee);
		float w = aureole_warmth * clamp(x / aureole_knee, 0.0, 1.0);
		col = mix(col / l, sun_chroma(), w) * lo;
	}
	// Chroma gain above the horizon.
	float ls = dot(col, LUMA);
	col = max(mix(vec3(ls), col, mix(1.0, sky_saturation, smoothstep(-1.0, 3.0, el))), vec3(0.0));

	float band = 1.0 - smoothstep(0.0, horizon_band_deg, abs(el));
	col = mix(col, horizon_color, horizon_amount * band);

	float g = smoothstep(-ground_start_deg, -ground_start_deg - ground_blend_deg, el);
	col = mix(col, ground_radiance, g);

	if (!AT_CUBEMAP_PASS && LIGHT0_ENABLED) {
		vec3 sun = LIGHT0_COLOR * LIGHT0_ENERGY;
		float radius = 0.5 * max(LIGHT0_SIZE, radians(sun_min_diameter_deg));
		// Angle from the sun centre, precise for tiny angles (acos(dot) is not).
		float ang = 2.0 * asin(clamp(0.5 * length(d - LIGHT0_DIRECTION), 0.0, 1.0));
		float r = ang / radius;
		float mu = sqrt(max(1.0 - r * r, 0.0));
		float limb = 1.0 - sun_limb_darkening * (1.0 - mu);
		float disc = 1.0 - smoothstep(0.9, 1.0, r);
		float above = smoothstep(-0.5, 0.2, el);      // The disc sets behind the terrain, not the horizon band.
		col += sun * (sun_disc_scale * limb * disc + sun_glow * exp(-degrees(ang) / sun_glow_width_deg)) * above;
	}
	COLOR = col;
}
