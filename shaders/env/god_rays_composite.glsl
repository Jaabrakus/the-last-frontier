#[compute]
#version 450

// God rays, laid on the frame (GodRays, scripts/world/env/god_rays.gd): the half-resolution rays (god_rays.glsl)
// upsampled and added to the HDR colour, tinted by the sun's light and scaled by its strength. Only on geometry and
// on the sky away from the sun: the open sky already has its own light, so it takes the rays at `sky_share`.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D rays_buffer;    // linear
layout(set = 0, binding = 1) uniform sampler2D depth_buffer;   // nearest
layout(rgba16f, set = 0, binding = 2) uniform restrict image2D color_image;

layout(push_constant, std430) uniform Params {
	vec4 tint;        // rgb: the sun's colour times the strength
	vec2 size;        // the colour's size in pixels
	float sky_depth;
	float sky_share;
} params;

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	if (any(greaterThanEqual(pos, ivec2(params.size)))) {
		return;
	}
	vec2 uv = (vec2(pos) + 0.5) / params.size;
	vec3 rays = textureLod(rays_buffer, uv, 0.0).rgb * params.tint.rgb;
	if (texelFetch(depth_buffer, pos, 0).r == params.sky_depth) {
		rays *= params.sky_share;
	}
	vec4 c = imageLoad(color_image, pos);
	if (params.tint.a > 0.0) {   // debug: the rays alone
		c.rgb = vec3(0.0);
	}
	imageStore(color_image, pos, vec4(c.rgb + rays, c.a));
}
