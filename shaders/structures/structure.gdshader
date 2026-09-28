// PBR material for every generated fort mesh: palisade logs, hewn and board timber, shingles,
// fieldstone, straw (look-dev spec, section 8). Owner: package D.
//
// One shader, several ShaderMaterials (StructureMaterials): each material binds its own
// albedo / normal (OpenGL, hint_normal) / ARM (AO, roughness, metal) set and weathering
// strengths. Meshes come from StructureMeshKit with this vertex layout:
//   UV     texture coordinates in tiles (the mesh generator does the physical scaling)
//   UV2.x  surface kind: 0 textured, 1 clay chinking, 2 wrought iron, 3 end grain
//          (UV = offset from the pith in metres), 4 void (loopholes, gaps)
//   UV2.y  edge factor 0..1 (edge wear)
//   COLOR  rgb per-part tint, a baked ambient occlusion
// MultiMesh palisade: use_instance_custom = true and INSTANCE_CUSTOM =
//   (u offset, v offset, tint -1..1, extra moss 0..1).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/structures/weathering.gdshaderinc"

global uniform vec3 sun_direction;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

group_uniforms surface;
uniform vec3 tint : source_color = vec3(1.0);
uniform float normal_strength = 1.0;
uniform float roughness_offset = 0.0;
uniform float specular_level = 0.4;
uniform float texture_ao = 1.0;
/** How much the baked vertex AO darkens direct light as well (crevices read in sunlight). */
uniform float vertex_ao_diffuse = 0.4;
uniform bool use_instance_custom = false;
uniform float instance_tint = 0.06;

group_uniforms weathering;
uniform float ground_y = 0.0;
uniform float dirt_height = 0.4;
uniform float dirt_strength = 0.5;
uniform vec3 dirt_tint : source_color = vec3(0.56, 0.48, 0.39);
uniform float streak_strength = 0.22;
uniform float streak_top_y = 100.0;
uniform float moss_strength = 0.35;
uniform float roof_moss = 0.0;
uniform vec3 moss_color : source_color = vec3(0.30, 0.34, 0.17);
uniform float lichen = 0.35;
uniform float bleach_strength = 0.3;
uniform float edge_wear = 0.5;
uniform float soot_y = 1000.0;

group_uniforms procedural;
uniform vec3 clay_color : source_color = vec3(0.64, 0.61, 0.55);
uniform vec3 iron_color : source_color = vec3(0.085, 0.08, 0.075);
uniform vec3 rust_color : source_color = vec3(0.36, 0.19, 0.09);
uniform vec3 endgrain_color : source_color = vec3(0.55, 0.50, 0.43);

varying vec3 v_wp;
varying vec3 v_wn;
varying float v_moss;
varying float v_tint;

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_tint = 1.0;
	v_moss = 0.0;
	if (use_instance_custom) {
		UV += INSTANCE_CUSTOM.xy;
		v_tint = 1.0 + INSTANCE_CUSTOM.z * instance_tint;
		v_moss = INSTANCE_CUSTOM.w;
	}
}

void fragment() {
	vec3 wn = normalize(v_wn);
	int kind = int(UV2.x + 0.5);
	float edge = UV2.y;
	vec3 alb;
	float rough;
	float ao = 1.0;
	float metal = 0.0;
	vec3 nmap = vec3(0.5, 0.5, 1.0);
	float spec = specular_level;
	if (kind == 0) {
		alb = texture(albedo_tex, UV).rgb;
		nmap = texture(normal_tex, UV).rgb;
		vec3 arm = texture(arm_tex, UV).rgb;
		rough = arm.g;
		ao = mix(1.0, arm.r, texture_ao);
		metal = arm.b;
	} else if (kind == 1) {
		vec2 fuv = frontier_face_uv(v_wp, wn);
		float n = texture(noise_tex, fuv * 1.7).g;
		float a = texture(noise_tex, fuv * 7.0).a;
		alb = clay_color * (0.82 + 0.3 * n) * (0.9 + 0.2 * a);
		rough = 0.96;
		ao = 0.8;
		spec = 0.3;
	} else if (kind == 2) {
		float n = texture(noise_tex, v_wp.xz * 2.7 + vec2(v_wp.y * 1.9, 0.0)).g;
		float r = smoothstep(0.5, 0.72, n);
		alb = mix(iron_color, rust_color, r * 0.75);
		metal = mix(0.65, 0.1, r);
		rough = mix(0.5, 0.85, r);
		spec = 0.5;
	} else if (kind == 3) {
		float d = length(UV);
		float n = texture(noise_tex, UV * 0.9 + vec2(0.37, 0.11)).g;
		float rings = fract(d * 36.0 + n * 2.5);
		float ring_line = smoothstep(0.72, 1.0, rings) * 0.3;
		float ang = atan(UV.y, UV.x);
		float crack = smoothstep(0.9, 1.0, texture(noise_tex, vec2(ang * 0.9, 0.3)).a) * smoothstep(0.02, 0.06, d);
		alb = endgrain_color * (1.0 - ring_line) * (1.0 - 0.65 * crack) * (0.88 + 0.24 * n);
		rough = 0.92;
		ao = 1.0 - 0.4 * crack;
	} else {
		alb = vec3(0.012);
		rough = 1.0;
		ao = 0.0;
		spec = 0.0;
	}
	alb *= tint * COLOR.rgb * v_tint;
	if (kind != 4) {
		float grain = texture(noise_tex, UV * 3.0).a;
		if (kind != 2) {
			frontier_sun_bleach(alb, rough, wn, sun_direction, bleach_strength);
			frontier_edge_wear(alb, rough, edge, edge_wear, grain);
			frontier_moss(alb, rough, v_wp, wn, ground_y, moss_strength * (1.0 + v_moss), roof_moss,
					moss_color, lichen, noise_tex);
		}
		frontier_rain_streaks(alb, v_wp, wn, streak_strength, streak_top_y, noise_tex);
		frontier_ground_dirt(alb, rough, v_wp, wn, ground_y, dirt_height, dirt_strength, dirt_tint, noise_tex);
		if (soot_y < 999.0) {
			frontier_soot(alb, v_wp, wn, soot_y, noise_tex);
		}
	}
	float vao = COLOR.a;
	ALBEDO = alb * mix(1.0, vao, vertex_ao_diffuse);
	ROUGHNESS = clamp(rough + roughness_offset, 0.05, 1.0);
	METALLIC = metal;
	SPECULAR = spec;
	AO = min(ao, vao);
	AO_LIGHT_AFFECT = 0.15;
	NORMAL_MAP = nmap;
	NORMAL_MAP_DEPTH = normal_strength;
}
