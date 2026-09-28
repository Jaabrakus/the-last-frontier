// Wool bunting flag that streams downwind and ripples (look-dev spec, section 8.1). Owner: D.
// The mesh (StructureGeometry.flag_mesh) is a grid in the flag's local XY plane: x = 0 at the
// hoist (the pole) .. flag_length at the fly, y = -flag_height/2 .. +flag_height/2. The node
// sits at the pole with an identity basis; the shader turns the flag about the pole (local Y)
// toward the global wind_direction and waves it with wind_strength (res://shaders/common).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/common/wind.gdshaderinc"

uniform sampler2D cloth_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cloth_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 cloth_color : source_color = vec3(0.58, 0.13, 0.10);
uniform float flag_length = 1.8;
uniform float flag_height = 1.1;
uniform float wave_amp = 0.13;
uniform vec2 weave_scale = vec2(5.0, 3.0);

void vertex() {
	float x = VERTEX.x;
	float t = clamp(x / flag_length, 0.0, 1.0);
	vec2 wd = normalize(wind_direction + vec2(1e-5));
	float ws = clamp(wind_strength, 0.0, 1.0);
	float g = frontier_gust(MODEL_MATRIX[3].xz);
	float speed = 2.6 + 5.0 * ws;
	float ph = TIME * speed;
	float amp = wave_amp * (0.45 + 1.2 * ws) * (0.7 + 0.5 * g);
	float k1 = 5.2;
	float k2 = 10.7;
	float a1 = x * k1 - ph + VERTEX.y * 0.8;
	float a2 = x * k2 - ph * 1.41 + VERTEX.y * 2.3;
	float w = sin(a1) + 0.3 * sin(a2);
	float z = amp * t * w;
	// Weak wind: the fly droops and the flag hangs closer to the pole.
	float lift = clamp(ws * 2.4 + g * 0.3, 0.0, 1.0);
	float droop = (1.0 - lift) * 0.55 * t * t;
	VERTEX = vec3(x * (1.0 - 0.18 * (1.0 - lift) * t) - abs(z) * 0.15, VERTEX.y - droop, z);
	float dzdx = amp * (t * (k1 * cos(a1) + 0.3 * k2 * cos(a2)) + w / flag_length);
	float dzdy = amp * t * (0.8 * cos(a1) + 0.3 * 2.3 * cos(a2));
	vec3 n = normalize(vec3(-dzdx, -dzdy, 1.0));
	// Turn about the pole: local +X streams toward the wind direction (world XZ).
	vec3 cx = vec3(wd.x, 0.0, wd.y);
	mat3 r = mat3(cx, vec3(0.0, 1.0, 0.0), cross(cx, vec3(0.0, 1.0, 0.0)));
	VERTEX = r * VERTEX;
	NORMAL = r * n;
	TANGENT = r * normalize(vec3(1.0, 0.0, dzdx));
	BINORMAL = r * normalize(vec3(0.0, 1.0, dzdy));
}

void fragment() {
	vec2 uv = UV * weave_scale;
	vec3 c = texture(cloth_tex, uv).rgb * cloth_color;
	// Faded, frayed fly end and a slightly darker hoist (the sleeve).
	c *= mix(0.82, 1.0, smoothstep(0.0, 0.06, UV.x));
	c = mix(c, c * vec3(1.08, 1.12, 1.12) + vec3(0.02), smoothstep(0.6, 1.0, UV.x) * 0.35);
	ALBEDO = c;
	ROUGHNESS = 0.93;
	SPECULAR = 0.25;
	NORMAL_MAP = texture(cloth_normal, uv).rgb;
	NORMAL_MAP_DEPTH = 0.6;
	BACKLIGHT = c * 0.55;
}
