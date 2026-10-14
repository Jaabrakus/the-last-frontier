// Thủy Vân painted sky (style_guide.md 5.4 "Sky"; PAINT's assets/thuyvan/paint/sky/tv_sky_<direction>.png, sky.json):
// a 4096 x 2048 equirect panorama, its upper half painted (clouds, the sun's glow, far karst silhouettes) and its lower
// half the direction's fog colour. Read with the painter's own convention, so the painted sun sits where sky.json says:
//   u = fract(0.5 + atan(dir.x, -dir.z) / 2 pi)   (north, -Z, at u 0.5; east at 0.75)
//   v = acos(dir.y) / pi                           (zenith at the top)
// Below the horizon the panorama's fog half shows, blended to `ground_tint` (the fog colour) so the ground never ends in
// a seam. Never the frontier HDRI.
// The day cycle (owner_answers.md 7; ThuyVanLook): `panorama_b` is the next direction's panorama, mixed in by `blend` as
// the clock moves from one direction to the next, and `tint` darkens and cools the painted sky for the night after dusk.
shader_type sky;

uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D panorama_b : source_color, filter_linear_mipmap, repeat_enable;
uniform float blend : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float energy = 1.0;
uniform vec3 ground_tint : source_color = vec3(0.71, 0.83, 0.93);
uniform float ground_blend : hint_range(0.0, 1.0) = 0.6;

void sky() {
	vec3 d = normalize(EYEDIR);
	vec2 uv = vec2(fract(0.5 + atan(d.x, -d.z) / 6.2831853), acos(clamp(d.y, -1.0, 1.0)) / 3.14159265);
	vec3 c = textureLod(panorama, uv, 0.0).rgb;
	if (blend > 0.001) {
		c = mix(c, textureLod(panorama_b, uv, 0.0).rgb, blend);
	}
	c *= tint;
	if (d.y < 0.0) {
		c = mix(c, ground_tint, ground_blend * smoothstep(0.0, -0.15, d.y));
	}
	COLOR = c * energy;
}
