#[compute]
#version 450

// God rays, the light shafts (user 2026-10-02: "can we add god rays", a Three.js screen-space breakdown). Run by GodRays
// (scripts/world/env/god_rays.gd), a CompositorEffect, after the transparent pass on the HDR colour (before the
// tonemap). At half resolution, each pixel marches toward the sun's place on the screen and sums the open sky it
// crosses: the sky's own colour (clamped, so the sun's disc does not burn the frame) on the pixels where no geometry was
// drawn (depth at the cleared far value), faded with the distance from the sun. Trees, leaves, hills and roofs are
// geometry and block it, so the light streams out between them; clouds are darker sky and thin it. Each step is
// weighted by `decay` to the power of the steps taken (GPU Gems 3, 13: "Volumetric Light Scattering as a
// Post-Process"), and the march starts at a per-pixel noise offset so its steps do not band (the TAA / upscaler smooths it).

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D depth_buffer;   // nearest
layout(set = 0, binding = 1) uniform sampler2D color_buffer;   // linear
layout(rgba16f, set = 0, binding = 2) uniform restrict writeonly image2D rays_image;

layout(push_constant, std430) uniform Params {
	vec2 sun_uv;      // the sun on the screen (uv, y down); may be off screen
	vec2 size;        // the rays image's size in pixels
	float aspect;     // width / height of the frame
	float density;    // the fraction of the way to the sun the march covers
	float decay;      // the weight kept per step
	float radius;     // the sky's light fades to 0 at this distance from the sun (in screen heights)
	float cap;        // the sky colour's ceiling (HDR); the threshold (below which the sky streams nothing) is cap / 4
	float sky_depth;  // the depth buffer's value where nothing was drawn (reverse Z: 0)
	float steps;      // samples per pixel
	float halo;       // the light's own glow on the open sky round it (the moon's: the night sky is dark)
	float open_floor; // the rays' share where the way to the sun is broken once at most (a skyline over open land)
	float breaks_lo;  // from this many breaks (sky <-> geometry) on the way to the sun the shafts come in ...
	float breaks_hi;  // ... to full by this many (the gaps between trunks and leaves)
	float pad;
} params;

// Whether uv is open sky (on screen, nothing drawn there).
bool is_sky(vec2 uv) {
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return false;
	}
	return textureLod(depth_buffer, uv, 0.0).r == params.sky_depth;
}

vec3 open_sky(vec2 uv) {
	if (!is_sky(uv)) {
		return vec3(0.0);
	}
	vec2 d = (uv - params.sun_uv) * vec2(params.aspect, 1.0);
	float fall = 1.0 - smoothstep(0.0, params.radius, length(d));
	if (fall <= 0.0) {
		return vec3(0.0);
	}
	// only the sky brighter than the threshold streams (the glare round the light, not the whole sky: a uniform haze
	// over the frame otherwise)
	vec3 c = min(textureLod(color_buffer, uv, 0.0).rgb, vec3(params.cap));
	c = max(c - vec3(params.cap * 0.25), vec3(0.0)) * (4.0 / 3.0);
	return (c + vec3(params.halo * fall * fall)) * fall * fall;
}

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	if (any(greaterThanEqual(pos, ivec2(params.size)))) {
		return;
	}
	vec2 uv = (vec2(pos) + 0.5) / params.size;
	int n = int(params.steps);
	vec2 step_uv = (params.sun_uv - uv) * params.density / params.steps;
	// interleaved gradient noise: a different start each pixel
	float noise = fract(52.9829189 * fract(dot(vec2(pos), vec2(0.06711056, 0.00583715))));
	vec2 p = uv + step_uv * noise;
	float w = 1.0;
	float total = 0.0;
	vec3 sum = vec3(0.0);
	// shafts are light broken up on its way (user 2026-10-02: "the god rays are too strong in the open plains"): the
	// times the march passes between sky and geometry; over open land it crosses the skyline once and the whole sky
	// round the sun streamed at full strength, a wash over the frame, not rays
	float breaks = 0.0;
	bool was = is_sky(p);
	for (int i = 0; i < n; i++) {
		bool sky = is_sky(p);
		breaks += sky != was ? 1.0 : 0.0;
		was = sky;
		sum += open_sky(p) * w;
		total += w;
		w *= params.decay;
		p += step_uv;
	}
	float shafts = mix(params.open_floor, 1.0, smoothstep(params.breaks_lo, params.breaks_hi, breaks));
	imageStore(rays_image, pos, vec4(sum / max(total, 1e-4) * shafts, 1.0));
}
