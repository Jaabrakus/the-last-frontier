// Shared helpers for the fireball lab shaders.
// Sprite instances (MultiMesh): transform basis scale = size (m), origin = centre;
// INSTANCE_CUSTOM = (rotation turns, sub-image, flip bits, relative time).
// Mesh instances: INSTANCE_CUSTOM = (dynamic param 0, 1, 2, relative time).

uniform sampler2D _scene_depth : hint_depth_texture, filter_nearest;


// UE CameraDepthFade: saturate((PixelDepth - Offset) / Length)
float camera_depth_fade(float depth_m, float offset_m, float length_m) {
	return clamp((depth_m - offset_m) / max(length_m, 1e-4), 0.0, 1.0);
}

// UE DepthFade: soft intersection with opaque geometry over fade_m
float depth_fade(vec2 screen_uv, vec3 vertex_view, mat4 inv_proj, float fade_m) {
	float d = texture(_scene_depth, screen_uv).r;
	vec4 ndc = vec4(screen_uv * 2.0 - 1.0, d, 1.0);
	vec4 view = inv_proj * ndc;
	view.xyz /= view.w;
	return clamp((vertex_view.z - view.z) / max(fade_m, 1e-4), 0.0, 1.0);
}

// UE CheapContrast
float cheap_contrast(float x, float c) {
	return clamp(mix(-c, 1.0 + c, x), 0.0, 1.0);
}

vec2 rotate_uv(vec2 uv, float turns, vec2 centre) {
	float a = turns * 6.28318530718;
	vec2 d = uv - centre;
	return vec2(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a)) + centre;
}

vec2 atlas_uv(vec2 quv, float image, vec2 grid) {
	float i = floor(image + 0.5);
	vec2 cell = vec2(mod(i, grid.x), floor(i / grid.x));
	return (cell + quv) / grid;
}

float stepped(float t, float fps) {
	return floor(t * fps) / fps;
}
