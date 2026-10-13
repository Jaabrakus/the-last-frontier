// The effects' brightness under the scene's exposure (ToonFx.set_gain: RingLook's night opens the eye ~2x and these are
// unshaded, so they would blow out to white; the ring's light sets it per mood).
uniform float fx_gain = 1.0;

// Shared by the bent elements' cel effects (ToonFx, scripts/fx/toon_fx.gd): hard-edged steps that stay smooth over a
// pixel, the camera-facing ways a flat thing can stand (a particle billboard, a quad turned only round its own axis, a
// strip along a line), and a cel light from a fixed sun.
// Round 4 (LOOKS; the numbers from data/bending/fx_looks.json, set by ToonFx.mat): the near-camera fade (near_cut: an
// effect's pixels thin out in a screen-door from far_m to near_alpha at near_m from the camera, so nothing fills your view
// and nothing needs sorting; own_fade, an instance's own fade, for your own walls by the camera), a bolt's core grown with
// its distance from the camera (range_scale: never a few pixels at range; its hitbox unchanged), and the soft meeting of a
// flat effect with the deck (deck_soft: the scene's depth behind it).

#include "res://shaders/bend_fx/dither.gdshaderinc"

uniform float near_m = 2.5;
uniform float far_m = 4.0;
uniform float near_alpha = 0.25;
uniform float range_from_m = 14.0;
uniform float range_full_m = 25.0;
uniform float range_max = 2.2;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float own_fade = 1.0;  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform float own_fade = 1.0;
#endif

// 0 below `edge`, 1 above, blended over about a pixel (no stairs on the cut).
float aastep(float edge, float v) {
	float w = max(fwidth(v) * 0.75, 1e-4);
	return smoothstep(edge - w, edge + w, v);
}

// The same over at least `soft` (a soft edge, never sharper than a pixel). The pixel's share is capped: far off, a noisy
// field changes a lot from pixel to pixel and an uncapped blend would wash the whole shape see-through.
float softstep(float edge, float v, float soft) {
	float w = max(min(fwidth(v), 0.12) * 1.2, soft);
	return smoothstep(edge - w, edge + w, v);
}

// How much of an effect shows `d` m from the camera: near_alpha at near_m and nearer, whole from far_m.
float near_fade(float d) {
	return mix(near_alpha, 1.0, clamp((d - near_m) / max(far_m - near_m, 1e-3), 0.0, 1.0));
}

// Whether this pixel (view-space `vtx`, FRAGCOORD `fc`) is left out by the near fade and the instance's own fade.
bool near_cut(vec3 vtx, vec2 fc) {
	return dither_cut(min(near_fade(length(vtx)), own_fade), fc);
}

// A bolt's core scale `d` m from the camera: 1 to range_from_m, growing to range_max at range_full_m.
float range_scale(float d) {
	return 1.0 + (range_max - 1.0) * clamp((d - range_from_m) / max(range_full_m - range_from_m, 1e-3), 0.0, 1.0);
}

// 0 where a flat effect meets what stands behind it (the deck), 1 from `dist` m in front of it: the raw depth `raw` read at
// `suv` from the shader's depth texture, `vtx` the pixel's view-space position.
float deck_soft(float raw, vec2 suv, mat4 inv_proj, vec3 vtx, float dist) {
	vec4 p = inv_proj * vec4(suv * 2.0 - 1.0, raw, 1.0);
	float sz = p.z / p.w;
	return clamp((vtx.z - sz) / max(dist, 1e-3), 0.0, 1.0);
}

// A quad whose local Y is `axis_w` (world, its length the height) turned round that axis to face the camera; local X spans
// `width` (m). The point `c` is its base. Returns the world position of local `v` (x -0.5..0.5, y 0..1).
vec3 axis_billboard(vec3 v, vec3 c, vec3 axis_w, float width, vec3 fallback_side, vec3 cam) {
	vec3 ax = normalize(axis_w);
	vec3 side = cross(ax, normalize(cam - c));
	float l = length(side);
	side = l > 1e-3 ? side / l : fallback_side;
	return c + side * v.x * width + axis_w * v.y;
}

// A strip along a line: `v` the centre (world: the strip's MeshInstance at the origin), `along` the line's direction,
// `hw` the half width, `across` 0..1 from one edge to the other. Returns the edge point, turned to face the camera.
vec3 strip_point(vec3 v, vec3 along, float hw, float across, vec3 cam) {
	vec3 side = cross(normalize(along + vec3(1e-6)), normalize(cam - v));
	float l = length(side);
	side = l > 1e-4 ? side / l : vec3(0.0, 1.0, 0.0);
	return v + side * hw * (across * 2.0 - 1.0);
}

// The sun's way in view space (a fixed high sun from behind the left shoulder: the cel light of the effects).
vec3 cel_light(mat4 view) {
	return normalize((view * vec4(0.35, 0.85, 0.40, 0.0)).xyz);
}
