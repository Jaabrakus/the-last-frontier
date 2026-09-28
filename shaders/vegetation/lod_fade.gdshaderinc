// A tree's LOD swaps dissolve instead of popping (user 2026-09-28: "it jitters between the low res one and the high
// res"; vegetation.gd gives each drawn LOD its own copy of the species' material with its bands in "lod_fade":
// FrontierVegetation._lod_material(); per-node instance uniforms overflowed the engine's buffer with the forest's
// thousands of MultiMeshes).
//
// Each drawn LOD of a tree (and the impostor) covers the tree from where the LOD before it hands over to where the
// next one takes it, and the hand-over is a band of a few metres around the switch distance, measured from the camera
// to THIS tree (not to its MultiMesh's cell). Across the band the two LODs share the tree's pixels by screen-space
// dither: the nearer LOD keeps the pixels whose noise is under its coverage, the farther one the others, so between
// them every pixel is drawn exactly once. Nothing is drawn twice and nothing goes to the transparent pass: the
// engine's visibility-range fade (FADE_SELF) put the band's trees in the transparent pass, with no depth prepass, no
// depth writes and no motion vectors, and the temporal upscaler (MetalFX at the medium preset) smeared them as the
// band swept over the forest. Outside its band a LOD's instance is collapsed in the vertex shader (no pixels at all),
// so its MultiMesh can stay visible over a wider range than its own trees need.
//
// lod_fade: x..y the band where this LOD comes in (0, 0: from the camera on), z..w the band where it goes out (0, 0:
// never). The default (all 0) draws everything: the materials' other users (saplings, shrubs, shadow proxies) are as
// before.

uniform vec4 lod_fade = vec4(0.0);
// 1 with a temporal anti-aliasing (TAA, MetalFX: the high and medium presets): the noise moves on each frame by the
// golden ratio, so the temporal pass averages the two LODs into a smooth dissolve instead of keeping a fixed dot
// pattern on the tree; 0 (FXAA, the low preset) keeps it still, where a moving one would sparkle.
uniform float lod_dither_anim = 0.0;

// (coverage coming in, coverage going out), 0..1 each, for a tree at distance d.
vec2 frontier_lod_cover(float d) {
	float cin = lod_fade.y > lod_fade.x ? clamp((d - lod_fade.x) / (lod_fade.y - lod_fade.x), 0.0, 1.0) : 1.0;
	float cout = lod_fade.w > lod_fade.z ? 1.0 - clamp((d - lod_fade.z) / (lod_fade.w - lod_fade.z), 0.0, 1.0) : 1.0;
	return vec2(cin, cout);
}

// True when this LOD does not draw the fragment. The coming-in test uses the noise inverted, so it takes exactly the
// pixels the going-out LOD leaves (the same noise: the impostors' view blend and the near-camera fade use it too).
bool frontier_lod_dither(vec2 frag_xy, vec2 cover) {
	if (cover.x >= 1.0 && cover.y >= 1.0) {
		return false;
	}
	float n = fract(52.9829189 * fract(dot(frag_xy, vec2(0.06711056, 0.00583715))));
	n = fract(n + lod_dither_anim * 0.61803398875 * floor(TIME * 60.0));
	return (1.0 - n) > cover.x || n > cover.y;
}
