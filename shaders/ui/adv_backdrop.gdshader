shader_type canvas_item;
// The Character Advancement window's painting (scripts/ui/advancement/advancement_window.gd): the whole picture is calmed by
// one smooth elliptical falloff (2026-10-10 pass 2: the two calmed rectangles of the first repair left a crisp column with
// seams). Inside the ellipse round the centre art the painting keeps its colour and sharpness but its peak is dimmed a little
// (`centre_dark`), so the brightest thing on screen is a worn node, not the backdrop; outward, toward the trees and the rail,
// it is softened (a small blur), drained of most of its colour and darkened, with no edge anywhere. Our own shader.
// `centre` and `radii` are in the picture's UV; `inner` .. `outer` is the falloff in units of the ellipse's radii.

uniform vec2 centre = vec2(0.5, 0.5);
uniform vec2 radii = vec2(0.14, 0.5);
uniform float inner = 0.7;
uniform float outer = 1.9;
uniform float dark : hint_range(0.0, 1.0) = 0.5;
uniform float centre_dark : hint_range(0.0, 1.0) = 0.15;
uniform float desat : hint_range(0.0, 1.0) = 0.55;
uniform float blur_px = 3.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float e = length((UV - centre) / max(radii, vec2(0.0001)));
	float m = smoothstep(inner, outer, e);
	vec2 px = TEXTURE_PIXEL_SIZE * blur_px * m;
	vec3 acc = col.rgb * 0.2;
	acc += texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb * 0.1;
	acc += texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb * 0.1;
	acc += texture(TEXTURE, UV + vec2(0.0, px.y)).rgb * 0.1;
	acc += texture(TEXTURE, UV - vec2(0.0, px.y)).rgb * 0.1;
	acc += texture(TEXTURE, UV + px).rgb * 0.1;
	acc += texture(TEXTURE, UV - px).rgb * 0.1;
	acc += texture(TEXTURE, UV + vec2(px.x, -px.y)).rgb * 0.1;
	acc += texture(TEXTURE, UV + vec2(-px.x, px.y)).rgb * 0.1;
	vec3 soft = mix(col.rgb, acc, m);
	float lum = dot(soft, vec3(0.299, 0.587, 0.114));
	soft = mix(soft, vec3(lum) * vec3(0.92, 0.96, 1.05), desat * m);
	// the centre's peak dimmed (a soft knee: the brightest parts lose the most), the sides darkened
	float peak = smoothstep(0.55, 1.0, max(soft.r, max(soft.g, soft.b)));
	soft *= 1.0 - mix(centre_dark * (0.5 + 0.5 * peak), dark, m);
	COLOR = vec4(soft, col.a);
}
