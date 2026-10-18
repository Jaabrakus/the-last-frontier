shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// Authored reference-lab lighting. Source albedo/UVs remain the converted inputs;
// this does not recreate the source game's renderer or its original shaders.
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform bool use_vertex_color = false;
uniform bool vertex_color_srgb = false;
uniform bool use_uv2 = false;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;
uniform float alpha_hash_scale : hint_range(0.0, 2.0) = 1.0;
uniform float band_softness : hint_range(0.001, 0.15) = 0.04;
uniform vec4 shadow_tint : source_color = vec4(0.76, 0.83, 0.96, 1.0);

vec3 srgb_to_linear(vec3 color) {
	return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), color));
}

void fragment() {
	vec2 source_uv = (use_uv2 ? UV2 : UV) * uv_scale.xy + uv_offset.xy;
	vec4 sampled_albedo = tint;
	if (use_texture) {
		sampled_albedo *= texture(albedo_texture, source_uv);
	}
	if (use_vertex_color) {
		sampled_albedo *= vec4(vertex_color_srgb ? srgb_to_linear(COLOR.rgb) : COLOR.rgb, COLOR.a);
	}
	// REFERENCE_ALPHA_MODE
	ALBEDO = sampled_albedo.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float facing = max(dot(normalize(NORMAL), normalize(LIGHT)), 0.0);
	float bands = 0.24
		+ 0.36 * smoothstep(0.18 - band_softness, 0.18 + band_softness, facing)
		+ 0.40 * smoothstep(0.62 - band_softness, 0.62 + band_softness, facing);
	vec3 hue = mix(shadow_tint.rgb, vec3(1.0), bands);
	DIFFUSE_LIGHT += hue * bands * ATTENUATION * LIGHT_COLOR / PI;
}
