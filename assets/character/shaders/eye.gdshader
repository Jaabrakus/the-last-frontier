// Eyes (body.glb Face surface "eye"): a sclera sphere with the corneal bulge. UV = metres in
// the front plane relative to the eye's centre (the eye looks along -Z in Blender, +Z in
// Godot), so the radial distance draws the pupil, the iris (radial fibres, crypts, a lighter
// collarette, the limbal ring) and the sclera. The cornea is glossy (clear coat) over the
// iris. The upper lid's shadow on the eyeball (the lids are skin, not in this mesh) is
// approximated by darkening the top of the eyeball; `lid_shadow` sets how much.
// Same hide mask convention as skin.gdshader (the head is never hidden).
//
// `stylized` 1 (the creator's Stylized face style): a painted eye: a slightly larger iris with a
// clean radial gradient (a dark rim, the lower half lighter where the light enters), few fibres,
// a crisp dark limbal ring, a painted catch light at the upper outer side, a cleaner sclera
// under a stronger painted lid shadow. The eyeball itself is scaled with the stylized eye region
// (body.glb `style` shape).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform uvec2 hide_mask = uvec2(0u, 0u);
uniform vec3 iris_color : source_color = vec3(0.29, 0.18, 0.10);
// the sclera is not paper white: a warm grey-white, about 30-40 % reflectance (it glowed against dark
// skin in the game's evening light)
uniform vec3 sclera_color : source_color = vec3(0.66, 0.62, 0.57);
uniform float pupil_radius = 0.0021;
uniform float iris_radius = 0.0058;
uniform float lid_shadow : hint_range(0.0, 1.0) = 0.6;
uniform int stylized = 0;
// Reflective eyes (Thủy Vân: Dragon-Sea, Riverborn; BodyMaterials.eye_material from the look's `reflect_eye`): at night
// (`tv_night` 1, set by the environment from the sun's energy) the pupil and iris give back light in the people's
// tapetum colour, strongest looking straight in; by day only the iris's rim brightens a little.
uniform float reflect_eye : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tapetum_color : source_color = vec3(0.62, 0.82, 0.54);
uniform float tv_night : hint_range(0.0, 1.0) = 0.0;

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

void vertex() {
	uint code = uint(UV2.x + 0.5);
	uint r = code & 63u;
	uint bits = r < 32u ? (hide_mask.x >> r) : (hide_mask.y >> (r - 32u));
	if ((bits & 1u) != 0u) {
		VERTEX = vec3(0.0);
	}
}

// The stylized eye's colour at p (front-plane metres; d = |p|, ang = its angle).
vec3 painted_eye(vec2 p, float d, float ang) {
	float ir = iris_radius * 1.07;
	float pr = pupil_radius * 1.05;
	float t = clamp((d - pr) / (ir - pr), 0.0, 1.0);
	// iris: the colour lightened toward the lower half and the pupil's rim, a dark outer ring
	float lower = smoothstep(0.004, -0.004, p.y);
	vec3 iris = iris_color * mix(0.8, 1.45, lower * (1.0 - t * 0.5));
	iris = mix(iris, iris_color * vec3(1.6, 1.4, 1.1) + vec3(0.03, 0.02, 0.0), exp(-pow((t - 0.25) / 0.14, 2.0)) * 0.45);
	float fib = vnoise(vec2(ang * 14.0, d * 260.0));
	iris *= 0.9 + 0.2 * fib;
	iris = mix(iris, iris_color * 0.18, smoothstep(0.72, 0.98, t));
	// sclera: clean, warm at the corners, a painted shadow under the upper lid
	vec3 scl = sclera_color * 1.05 * mix(vec3(1.0), vec3(0.95, 0.84, 0.80), smoothstep(0.007, 0.0125, abs(p.x)));
	vec3 col = mix(iris, scl, smoothstep(ir, ir + 0.00035, d));
	col = mix(vec3(0.01), col, smoothstep(pr - 0.0001, pr + 0.0001, d));
	float shade = 1.0 - lid_shadow * smoothstep(0.0005, 0.0062, p.y) * 0.85;
	shade *= 1.0 - 0.3 * smoothstep(0.0075, 0.0115, abs(p.x));
	col *= shade;
	// the painted catch light: upper left of the iris in both eyes (one light, as a painter
	// places it)
	vec2 cl = vec2(-0.0017, 0.0021);
	col = mix(col, vec3(0.95), 1.0 - smoothstep(0.00055, 0.0008, length(p - cl)));
	return col;
}

void fragment() {
	vec2 p = vec2(UV.x, 1.0 - UV.y);          // (the exporter wrote v as 1 - v)
	float d = length(p);
	float ang = atan(p.y, p.x);
	// sclera: warm white, pinker and darker toward the corners, faint vessels
	float edge = smoothstep(0.006, 0.0125, d);
	vec3 scl = sclera_color * mix(vec3(1.0), vec3(0.93, 0.80, 0.76), edge);
	float vess = smoothstep(0.78, 0.92, vnoise(vec2(ang * 9.0, d * 900.0))) * edge;
	scl = mix(scl, vec3(0.62, 0.22, 0.20), vess * 0.35);
	// iris: radial fibres, crypts, a lighter collarette, darker rim
	float t = clamp((d - pupil_radius) / (iris_radius - pupil_radius), 0.0, 1.0);
	float fib = vnoise(vec2(ang * 36.0, d * 520.0));
	float crypt = smoothstep(0.60, 0.82, vnoise(vec2(ang * 13.0, d * 1500.0)));
	vec3 iris = iris_color * (0.72 + 0.55 * fib);
	float collar = exp(-pow((t - 0.28) / 0.12, 2.0));
	iris = mix(iris, iris_color * vec3(1.55, 1.35, 1.05) + vec3(0.04, 0.025, 0.0), collar * 0.55);
	iris *= 1.0 - 0.35 * crypt;
	iris = mix(iris, iris_color * 0.28, smoothstep(0.78, 1.0, t));            // limbal ring
	vec3 col = mix(iris, scl, smoothstep(iris_radius, iris_radius + 0.0007, d));
	col = mix(vec3(0.012), col, smoothstep(pupil_radius - 0.00015, pupil_radius + 0.00015, d));
	// the upper lid's shadow and the lid margins' occlusion
	float shade = 1.0 - lid_shadow * smoothstep(0.0015, 0.0068, p.y) * 0.8;
	// the corners sit deep in the socket, under the lids
	shade *= 1.0 - 0.45 * smoothstep(0.0065, 0.0115, abs(p.x));
	col *= shade;
	if (stylized == 1) {
		col = painted_eye(p, d, ang);
	}
	ALBEDO = col;
	float on_iris = 1.0 - smoothstep(iris_radius, iris_radius + 0.0006, d);
	if (reflect_eye > 0.0) {
		ALBEDO *= 1.0 + 0.10 * reflect_eye * (1.0 - tv_night) * on_iris * smoothstep(0.6, 1.0, d / iris_radius);
		EMISSION = tapetum_color * reflect_eye * tv_night * pow(max(dot(NORMAL, VIEW), 0.0), 6.0) * on_iris * 2.5;
	}
	if (stylized == 1) {
		// painted: the catch light is painted, so the cornea is a soft satin rather than a mirror
		// (the game's bright sky in a mirror cornea washed every iris out to a pale grey-blue)
		ROUGHNESS = 0.45;
		SPECULAR = 0.2;
	} else {
		ROUGHNESS = mix(0.14, 0.05, on_iris);
		SPECULAR = 0.5;
		CLEARCOAT = on_iris;
		CLEARCOAT_ROUGHNESS = 0.02;
	}
}
