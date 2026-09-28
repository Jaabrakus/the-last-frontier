#[compute]
#version 450

// The sky's motion vectors for the temporal AA (stars blur push, 2026-09-26). Run by SkyMotionVectors
// (scripts/world/env/sky_motion_vectors.gd), a CompositorEffect, after the opaque pass and before the TAA resolve.
//
// Godot 4.7's native TAA reads a velocity of 0 wherever no geometry was drawn: on the sky every turn of the camera
// reprojects the history from the wrong place, and the stars (points a pixel or two wide) smear, ghost and are then
// clipped away by the neighbourhood clamp (dim, blocky trails; the Milky Way streaks). FSR 2 derives those vectors
// from the depth buffer (its GODOT_DERIVE_INVALID_MOTION_VECTORS option); this does the same for the TAA. The sky is at
// infinity, so its motion is the camera's rotation alone: the view direction through each sky pixel, turned into the
// previous frame's view and projected with the previous (unjittered) lens.
// Same convention as the engine's own vectors (scene_forward_clustered.glsl): previous uv - current uv, in the
// framebuffer's uv (y down), without the TAA jitter.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D depth_buffer;
layout(rg16f, set = 0, binding = 1) uniform restrict writeonly image2D velocity_buffer;

layout(push_constant, std430) uniform Params {
	vec4 rot_x;      // xyz: first column of R = previous view rotation * current camera rotation (current view -> previous view)
	vec4 rot_y;      // second column
	vec4 rot_z;      // third column
	vec4 lens;       // current 1 / P00, 1 / P11; previous P00, P11 (unjittered, symmetric perspective)
	vec2 size;       // internal (render) size in pixels
	float sky_depth; // the depth buffer's value where nothing was drawn (reverse Z: 0)
	float pad;
} params;

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	if (any(greaterThanEqual(pos, ivec2(params.size)))) {
		return;
	}
	if (texelFetch(depth_buffer, pos, 0).r != params.sky_depth) {
		return;   // geometry keeps the engine's own vectors
	}
	vec2 uv = (vec2(pos) + 0.5) / params.size;
	// the view direction through the pixel (OpenGL view space: -Z ahead, +Y up)
	vec3 d = vec3((uv.x * 2.0 - 1.0) * params.lens.x, (1.0 - uv.y * 2.0) * params.lens.y, -1.0);
	vec3 p = mat3(params.rot_x.xyz, params.rot_y.xyz, params.rot_z.xyz) * d;
	vec2 vel = vec2(-2.0);   // behind the previous view (a cut): off screen, the TAA drops the history
	if (p.z < -1e-4) {
		vec2 ndc = vec2(params.lens.z * p.x, params.lens.w * p.y) / -p.z;
		vec2 prev_uv = vec2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5);
		vel = prev_uv - uv;
	}
	imageStore(velocity_buffer, pos, vec4(vel, 0.0, 0.0));
}
