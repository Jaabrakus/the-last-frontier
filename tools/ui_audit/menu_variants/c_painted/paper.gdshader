shader_type canvas_item;
// Menu variant C ("Painted river"): a sheet or slip of rice paper (paper_tile.png, painted by make_ink.py) with a torn,
// deckled edge, the edge browned a little, as a hand-cut slip. One material per panel (rect_size, seed).

uniform sampler2D paper : repeat_enable, filter_linear_mipmap;
uniform sampler2D edge_noise : repeat_enable, filter_linear;
uniform vec2 rect_size = vec2(400.0, 300.0);
uniform float tile_px = 512.0;
uniform float deckle = 6.0;          // how far the torn edge eats in (px)
uniform float age = 0.35;            // how brown the edge is
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 seed = vec2(0.0);

void fragment() {
	vec2 p = UV * rect_size;
	vec3 c = texture(paper, (p + seed * 512.0) / tile_px).rgb * tint.rgb;
	float d = min(min(p.x, p.y), min(rect_size.x - p.x, rect_size.y - p.y));
	float n = texture(edge_noise, (p + seed * 777.0) / 140.0).r * 0.65 + texture(edge_noise, (p + seed * 333.0) / 31.0).r * 0.35;
	float e = d - deckle * n;
	float a = smoothstep(0.0, 1.4, e);
	float brown = (1.0 - smoothstep(0.0, 10.0 + deckle * 2.0, e)) * age;
	c = mix(c, c * vec3(0.80, 0.66, 0.50), brown);
	// a slight light falloff toward the bottom, as a sheet hung in lamplight
	c *= 1.0 - 0.06 * UV.y;
	COLOR = vec4(c, a * tint.a);
}
