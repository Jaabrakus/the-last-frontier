// PREVIEW ONLY (tools/character/garments/frontier/frontier_preview.gd): a stand-in for the
// fabric workstream's cloth.gdshader until it exists. Up to 4 zones (UV2.x >> 6), each
// with an approved Poly Haven kit sampled at UV / tile (UV in metres) and tinted by its
// luminance only (design §8.2: albedo = tint * (1 + s * (2 * detail - 1))), metals flat.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform uvec2 hide_mask = uvec2(0u, 0u);
uniform sampler2D tex0 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex1 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex2 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex3 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm0 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm3 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 tint0 : source_color = vec4(0.7, 0.6, 0.5, 1.0);
uniform vec4 tint1 : source_color = vec4(0.7, 0.6, 0.5, 1.0);
uniform vec4 tint2 : source_color = vec4(0.7, 0.6, 0.5, 1.0);
uniform vec4 tint3 : source_color = vec4(0.7, 0.6, 0.5, 1.0);
uniform vec4 tile = vec4(0.27);            // m per zone
uniform vec4 has_tex = vec4(1.0);
uniform vec4 metal = vec4(0.0);
uniform vec4 rough = vec4(0.85);
uniform vec4 detail_strength = vec4(0.7);
uniform vec4 normal_strength = vec4(0.6);
// bands from CUSTOM0.x (distance from the hem, m): rows of band_color
uniform vec4 band_color : source_color = vec4(0.12, 0.17, 0.29, 1.0);
uniform vec4 band_rows = vec4(0.0);       // (count, first offset m, width m, gap m) for zone 0

varying flat uint v_region;
varying flat uint v_zone;
varying vec2 v_edge;

void vertex() {
	uint code = uint(UV2.x + 0.5);
	v_region = code & 63u;
	v_zone = min(code >> 6u, 3u);
	v_edge = CUSTOM0.xy;
	uint bits = v_region < 32u ? (hide_mask.x >> v_region) : (hide_mask.y >> (v_region - 32u));
	if ((bits & 1u) != 0u) {
		VERTEX = vec3(0.0);
	}
}

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

void fragment() {
	int z = int(v_zone);
	vec4 tn = z == 0 ? tint0 : (z == 1 ? tint1 : (z == 2 ? tint2 : tint3));
	vec2 uv = UV / max(tile[z], 1e-3);
	vec3 d;
	vec3 mn;
	vec3 nm;
	if (z == 0) { d = texture(tex0, uv).rgb; mn = textureLod(tex0, vec2(0.5), 12.0).rgb; nm = texture(nrm0, uv).rgb; }
	else if (z == 1) { d = texture(tex1, uv).rgb; mn = textureLod(tex1, vec2(0.5), 12.0).rgb; nm = texture(nrm1, uv).rgb; }
	else if (z == 2) { d = texture(tex2, uv).rgb; mn = textureLod(tex2, vec2(0.5), 12.0).rgb; nm = texture(nrm2, uv).rgb; }
	else { d = texture(tex3, uv).rgb; mn = textureLod(tex3, vec2(0.5), 12.0).rgb; nm = texture(nrm3, uv).rgb; }
	float r = has_tex[z] > 0.5 ? lum(d) / max(lum(mn), 1e-3) : 1.0;
	vec3 col = tn.rgb * clamp(1.0 + detail_strength[z] * (r - 1.0), 0.2, 2.0);
	if (z == 0 && band_rows.x > 0.5) {
		for (int i = 0; i < 3; i++) {
			if (float(i) < band_rows.x) {
				float o = band_rows.y + float(i) * (band_rows.z + band_rows.w);
				if (v_edge.x > o && v_edge.x < o + band_rows.z) {
					col = band_color.rgb * clamp(1.0 + detail_strength[z] * (r - 1.0), 0.2, 2.0);
				}
			}
		}
	}
	ALBEDO = col * COLOR.rgb;
	METALLIC = metal[z];
	ROUGHNESS = rough[z];
	if (has_tex[z] > 0.5) {
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), nm, normal_strength[z]);
	}
}
