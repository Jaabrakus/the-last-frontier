shader_type canvas_item;
// The broadcast menus' backdrop (BroadcastUI.backdrop_blur): what is drawn under it, softened by mip level and drawn toward a
// navy tint, stronger at the left (where the rundown stands) than at the right. Our own shader; no third-party code.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur : hint_range(0.0, 6.0) = 2.6;
uniform float dim : hint_range(0.0, 1.0) = 0.45;
uniform float left_extra : hint_range(0.0, 1.0) = 0.35;
uniform vec4 tint : source_color = vec4(0.024, 0.047, 0.09, 1.0);

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur).rgb;
	float d = clamp(dim + left_extra * (1.0 - smoothstep(0.0, 0.65, UV.x)), 0.0, 1.0);
	COLOR = vec4(mix(c, tint.rgb, d), 1.0);
}
