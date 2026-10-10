shader_type canvas_item;
// The Character Advancement window's painting (scripts/ui/advancement/advancement_window.gd): behind the two trees and the
// class rail the picture is softened (a small blur), drained of most of its colour and darkened, with a wide soft edge, so
// the node plates read on calm ground; the centre gap keeps the painting crisp and in full colour. Our own shader.
// The rects are in the picture's UV (x, y, w, h); `feather` is the soft edge in UV of the picture's width (scaled for y).

uniform vec4 zone_a = vec4(0.0);
uniform vec4 zone_b = vec4(0.0);
uniform vec4 zone_c = vec4(0.0);
uniform float feather = 0.04;
uniform float aspect = 1.7778;
uniform float dark : hint_range(0.0, 1.0) = 0.5;
uniform float desat : hint_range(0.0, 1.0) = 0.55;
uniform float blur_px = 3.0;

float rect_mask(vec2 uv, vec4 r) {
	if (r.z <= 0.0) {
		return 0.0;
	}
	vec2 c = r.xy + r.zw * 0.5;
	vec2 d = max(abs(uv - c) - r.zw * 0.5, vec2(0.0));
	d.y /= aspect;
	return 1.0 - smoothstep(0.0, feather, length(d));
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float m = max(rect_mask(UV, zone_a), max(rect_mask(UV, zone_b), rect_mask(UV, zone_c)));
	if (m > 0.001) {
		vec2 px = TEXTURE_PIXEL_SIZE * blur_px;
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
		soft *= 1.0 - dark * m;
		col.rgb = soft;
	}
	COLOR = col;
}
