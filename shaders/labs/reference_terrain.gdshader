shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// Lab-authored tile placement/blending; albedo inputs are retained source PNGs.
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_grass = false;
uniform bool use_dirt = false;
uniform bool use_stone = false;
uniform bool stone_only = false;
uniform float tiles_per_metre = 0.5;
uniform vec4 grass_fallback : source_color = vec4(0.31, 0.57, 0.21, 1.0);
uniform vec4 dirt_fallback : source_color = vec4(0.40, 0.33, 0.22, 1.0);
uniform vec4 stone_fallback : source_color = vec4(0.40, 0.42, 0.35, 1.0);
varying vec3 world_point;
varying vec3 world_normal;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec3 projected_albedo(sampler2D albedo, vec3 point, vec3 weights) {
	return texture(albedo, point.yz).rgb * weights.x
		+ texture(albedo, point.xz).rgb * weights.y
		+ texture(albedo, point.xy).rgb * weights.z;
}

void fragment() {
	vec3 normal = normalize(world_normal);
	vec3 weights = pow(abs(normal), vec3(4.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	vec3 point = world_point * tiles_per_metre;
	vec3 grass = use_grass ? projected_albedo(grass_albedo, point, weights) : grass_fallback.rgb;
	vec3 dirt = use_dirt ? projected_albedo(dirt_albedo, point, weights) : dirt_fallback.rgb;
	vec3 stone = use_stone ? projected_albedo(stone_albedo, point, weights) : stone_fallback.rgb;
	float slope = 1.0 - abs(normal.y);
	float rock_share = smoothstep(0.20, 0.48, slope);
	rock_share = max(rock_share, smoothstep(4.7, 6.0, world_point.y) * 0.25);
	float soil_share = smoothstep(0.06, 0.30, slope) * 0.40;
	soil_share = max(soil_share, (1.0 - smoothstep(0.15, 0.9, world_point.y)) * 0.16);
	ALBEDO = stone_only ? stone : mix(mix(grass, dirt, soil_share), stone, rock_share);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float facing = max(dot(normalize(NORMAL), normalize(LIGHT)), 0.0);
	float bands = 0.24 + 0.36 * smoothstep(0.14, 0.22, facing) + 0.40 * smoothstep(0.58, 0.66, facing);
	DIFFUSE_LIGHT += bands * ATTENUATION * LIGHT_COLOR / PI;
}
