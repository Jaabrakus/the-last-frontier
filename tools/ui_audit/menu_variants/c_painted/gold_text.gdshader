shader_type canvas_item;
// Menu variant C ("Painted river"): gold-leaf lettering. The label's own colour is white; everything drawn in white
// (the letters) turns to beaten gold, lit from above with a bright band and a leaf texture; the shadow and the outline
// (drawn in their own darker colours) are left as they are.

uniform sampler2D flake : repeat_enable, filter_linear;
uniform float top = 0.0;
uniform float height = 80.0;
uniform vec3 hi : source_color = vec3(1.0, 0.90, 0.62);
uniform vec3 mid : source_color = vec3(0.86, 0.66, 0.32);
uniform vec3 lo : source_color = vec3(0.55, 0.35, 0.13);
uniform float leaf = 0.30;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float w = min(COLOR.r, min(COLOR.g, COLOR.b));
	if (w > 0.9) {
		float t = clamp((lp.y - top) / height, 0.0, 1.0);
		vec3 g = t < 0.5 ? mix(hi, mid, t / 0.5) : mix(mid, lo, (t - 0.5) / 0.5);
		g += vec3(0.22, 0.18, 0.10) * exp(-pow((t - 0.30) * 8.0, 2.0));
		float f = texture(flake, lp / 70.0).r;
		float f2 = texture(flake, lp / 13.0 + vec2(0.3, 0.7)).r;
		g *= 1.0 - leaf * 0.5 + leaf * (0.7 * f + 0.3 * f2);
		COLOR.rgb = g;
	}
}
