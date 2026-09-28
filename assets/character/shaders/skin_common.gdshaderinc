// Shared by skin.gdshader (realistic) and painted_skin.gdshader (stylized): the tone anchors, blood,
// exposure per region, Oklab, noise and the hide-mask test. Needs the uniforms `undertone` and
// `hide_mask` declared before the include.

const vec3 TONES[12] = vec3[12](
	vec3(0.8879, 0.6724, 0.5520), vec3(0.8148, 0.5457, 0.3968), vec3(0.7379, 0.4397, 0.2918),
	vec3(0.6376, 0.3419, 0.2016), vec3(0.5271, 0.2502, 0.1329), vec3(0.4125, 0.1845, 0.0887),
	vec3(0.3050, 0.1301, 0.0612), vec3(0.2086, 0.0887, 0.0437), vec3(0.1384, 0.0612, 0.0319),
	vec3(0.0908, 0.0409, 0.0222), vec3(0.0482, 0.0232, 0.0137), vec3(0.0262, 0.0137, 0.0086));

// Oklab lightness at which an undertone applies in full (the lightest tone's, about)
const float UNDERTONE_L = 0.87;

// Relative absorption of oxygenated blood in the R, G, B bands (linear sRGB).
const vec3 HB_ABS = vec3(0.07, 0.62, 0.46);

// Exposure per region id (lib/regions.py WEATHER).
const float WEATHER[38] = float[38](1.0, 0.85, 0.55, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
	0.0, 0.45, 0.6, 0.75, 0.85, 1.0, 0.0, 0.45, 0.6, 0.75, 0.85, 1.0,
	0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);

bool region_hidden(uint r) {
	uint bits = r < 32u ? (hide_mask.x >> r) : (hide_mask.y >> (r - 32u));
	return (bits & 1u) != 0u;
}

vec3 lin_to_oklab(vec3 c) {
	float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
	float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
	float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;
	l = pow(max(l, 0.0), 1.0 / 3.0); m = pow(max(m, 0.0), 1.0 / 3.0); s = pow(max(s, 0.0), 1.0 / 3.0);
	return vec3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
			1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
			0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
}

vec3 oklab_to_lin(vec3 c) {
	float l = c.x + 0.3963377774 * c.y + 0.2158037573 * c.z;
	float m = c.x - 0.1055613458 * c.y - 0.0638541728 * c.z;
	float s = c.x - 0.0894841775 * c.y - 1.2914855480 * c.z;
	l = l * l * l; m = m * m * m; s = s * s * s;
	return max(vec3(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
			-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
			-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s), vec3(0.0));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 tone_at(float mel) {
	float m = clamp(mel, 0.0, 1.0) * 11.0;
	int i = min(int(floor(m)), 10);
	vec3 c = mix(TONES[i], TONES[i + 1], m - float(i));
	vec3 lab = lin_to_oklab(c);
	// the undertone's hue shift in proportion to the tone's lightness (chroma scales with it), its
	// red-green part more so (a cool dark skin is ashier, not pinker): a fixed shift turned dark skin
	// maroon (BodyMaterials.tone_color does the same)
	float k = clamp(lab.x / UNDERTONE_L, 0.25, 1.0);
	lab.yz += undertone * vec2(k * k, k);
	return oklab_to_lin(lab);
}

// Blood absorption relative to the average (0.5), screened by the epidermis.
vec3 blood(float amount, float mel) {
	float screen = mix(1.0, 0.30, clamp(mel, 0.0, 1.0));
	return exp(-HB_ABS * (amount - 0.5) * 0.8 * screen);
}

vec3 region_color(uint r) {
	float h = fract(float(r) * 0.618034);
	vec3 k = clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return mix(vec3(1.0), k, 0.6) * 0.8;
}
