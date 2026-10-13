shader_type canvas_item;
// Menu variant C ("Painted river"): the last pass over a view of the ring after the game's oil-paint shader
// (shaders/ui/oil_paint.gdshader). It keeps each colour's hue (the water and the night sky stay jade and indigo) and
// tones the painting like lacquer (sơn mài): the darks deepened into lacquer black with a red cast, the lights laid
// toward gold leaf, the warm colours (lanterns, lacquer, wood) a little richer; then the silk's grain and a lamp-lit
// falloff. `amount` 0 leaves the painting as it is.

render_mode blend_disabled;

uniform sampler2D grain : repeat_enable, filter_linear;
uniform float amount = 0.6;
uniform float contrast = 0.25;       // an S-curve on the light, 0..1
uniform float warm_sat = 0.25;       // extra saturation for the warm hues
uniform float vignette = 0.38;
uniform float darken = 0.0;          // 0..1: a dusk veil
uniform vec3 shadow_tint : source_color = vec3(1.0, 0.80, 0.74);
uniform vec3 light_tint : source_color = vec3(1.0, 0.93, 0.78);

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float l = lum(c);
	float l2 = mix(l, l * l * (3.0 - 2.0 * l), contrast);
	c *= l2 / max(l, 0.001);
	l = l2;
	float ws = (1.0 - smoothstep(0.0, 0.5, l)) * amount;
	float wh = smoothstep(0.45, 1.0, l) * amount;
	c *= mix(vec3(1.0), shadow_tint, ws);
	c = mix(c, c * light_tint * 1.04, wh);
	// richer warm hues
	float warm = clamp((c.r - max(c.g, c.b)) * 4.0, 0.0, 1.0);
	float g = lum(c);
	c = mix(vec3(g), c, 1.0 + warm_sat * warm);
	c = clamp(c, 0.0, 1.0);
	c *= 0.965 + 0.07 * texture(grain, UV * vec2(9.0, 5.0)).r;
	vec2 v = UV - 0.5;
	float vg = smoothstep(0.85, 0.25, length(v * vec2(1.0, 1.3)));
	c *= mix(1.0 - vignette, 1.0, vg);
	c *= 1.0 - darken;
	COLOR = vec4(c, 1.0);
}
