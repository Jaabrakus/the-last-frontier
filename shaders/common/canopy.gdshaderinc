// The forest canopy's light (forest lighting, 2026-09-26). Included by the terrain, the grass, the ferns, the trees and
// the tree impostors. The globals (project.godot [shader_globals]):
//   canopy_map   crown cover 0..1 per square metre of the level (scripts/world/vegetation/canopy_map.gd; its mips are
//                the cover averaged over 2..16 m): R every crown, G the evergreens' alone
//   canopy_leaves how leafy the broadleaves are now, 1 summer .. 0 bare (SeasonLeaves): the cover is G + (R - G) x it
//   canopy_rect  x0, z0, 1 / width, 1 / depth (m) of the map
//   canopy_light rgb: the light a closed canopy scatters down (leaves transmit and reflect the sun: green-gold), as
//                emission per unit albedo; a: the share of the sky light (ambient and its reflections) a closed canopy
//                takes from what stands under it (ForestLight, scripts/world/env/forest_light.gd, sets both per frame)
//   leaf_glow    rgb: the key light seen through thin leaves (forward scatter), as emission per unit albedo; a: the
//                phase sharpness (the glow's width round the sun)
// All zero (no ForestLight: other scenes, tests) and every term is neutral.
//
//   #include "res://shaders/common/canopy.gdshaderinc"
//   float c = canopy_cover(world_xz);                  // sky cover over a point (8-16 m average)
//   AO *= canopy_sky_factor(c, under);                 // under: 1 below the crowns, 0 in the open air above them
//   EMISSION += ALBEDO * canopy_scatter(c, under, world_normal_y) * ao;

global uniform sampler2D canopy_map : filter_linear_mipmap, repeat_disable;
global uniform vec4 canopy_rect;
global uniform float canopy_leaves;
global uniform vec4 canopy_light;
global uniform vec4 leaf_glow;

// Crown cover of the sky seen from a point under it at world xz, 0 open .. 1 closed: the map averaged over ~8-16 m
// (a point on the floor sees a wide cone of sky), x CANOPY_SKY_VIEW (the map is the crowns' vertical cover; the sky
// seen from under a forest is mostly its zenith, the oblique views go through more crowns and trunks: a 60 % cover
// hides ~all of it). One fetch. scripts/world/env/forest_light.gd reads the map the same way on the CPU.
const float CANOPY_SKY_VIEW = 1.7;

float canopy_cover(vec2 xz) {
	vec2 c = textureLod(canopy_map, (xz - canopy_rect.xy) * canopy_rect.zw, 3.5).rg;
	return min((c.g + (c.r - c.g) * canopy_leaves) * CANOPY_SKY_VIEW, 1.0);
}

// Multiplier of the sky light under the canopy.
float canopy_sky_factor(float cover, float under) {
	return 1.0 - canopy_light.a * cover * under;
}

// Emission (per unit albedo) of the light scattered down through the canopy; `up` = the surface normal's world y.
vec3 canopy_scatter(float cover, float under, float up) {
	return canopy_light.rgb * (cover * under * (0.55 + 0.45 * clamp(up, 0.0, 1.0)));
}

// How far below the crowns a point `h` metres above the ground is (the canopy's crowns sit 4-20 m up).
float canopy_under(float h) {
	return 1.0 - smoothstep(7.0, 20.0, h);
}

// Forward scatter of the key light through a thin leaf toward the eye: 0 looking away from the light, 1 into it.
// view_to_eye_world: unit vector from the surface toward the camera; light_dir: toward the key light (both world).
float canopy_leaf_phase(vec3 view_to_eye_world, vec3 light_dir) {
	float mu = clamp(dot(-view_to_eye_world, light_dir), 0.0, 1.0);
	return pow(mu, max(leaf_glow.a, 1.0));
}
