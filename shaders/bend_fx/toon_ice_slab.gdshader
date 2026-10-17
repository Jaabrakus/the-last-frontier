shader_type spatial;
// The Ice Wall's slab (the anime pass, round 2): pale blue crystal facets you can see through, each face flat under the cel sun in
// three light tones, a white line along every facet edge (2 pixels wide at any distance), a deep blue outline round its silhouette
// (never under 2 pixels) and white frost crackling over its foot where it meets the deck. The mesh is ToonFx.ice_slab_mesh:
// UV the face's coordinates (a quad's u, v; a triangle's two barycentric ones), UV2.x 0 for a quad, 1 for a triangle.
// Thinned near the camera (near_cut); `fade` (instance) is your own wall seen through, OwnFade: a screen-door, as form_matter's.
render_mode unshaded, blend_mix, depth_draw_always, cull_back, shadows_disabled, fog_disabled;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"

uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform vec3 c_light : source_color = vec3(0.86, 0.97, 1.0);
uniform vec3 c_mid : source_color = vec3(0.6, 0.86, 1.0);
uniform vec3 c_dark : source_color = vec3(0.3, 0.6, 0.94);
uniform vec3 c_edge : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 c_ink : source_color = vec3(0.05, 0.2, 0.5);
uniform float alpha = 0.55;
uniform float edge_px = 2.0;
uniform float outline_px = 2.5;
uniform float frost_h = 0.55;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float fade = 1.0;  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform float fade = 1.0;
#endif

varying vec3 v_wpos;
varying float v_foot;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_foot = MODEL_MATRIX[3].y;
}

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy) || dither_cut(fade, FRAGCOORD.xy)) {
		discard;
	}
	vec3 N = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(N, VIEW) < 0.0) {
		N = -N;
	}
	float d = dot(N, cel_light(VIEW_MATRIX));
	vec3 col = c_dark;
	col = mix(col, c_mid, aastep(0.0, d));
	col = mix(col, c_light, aastep(0.55, d));
	float a = alpha;
	// the facet's edges: a white line, edge_px wide
	float ed = UV2.x > 0.5 ? min(min(UV.x, UV.y), 1.0 - UV.x - UV.y) : min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float px = max(fwidth(ed), 1e-5);
	float edge = 1.0 - smoothstep(edge_px * 0.6 * px, edge_px * 1.1 * px, ed);
	col = mix(col, c_edge, edge);
	a = mix(a, 0.95, edge);
	// a glint sweeping over the faces
	float s = fract(dot(v_wpos, vec3(0.55, 0.9, 0.35)) * 0.6 - floor(TIME * 12.0) / 12.0 * 0.5);
	col = mix(col, vec3(1.0), (1.0 - aastep(0.04, s)) * aastep(0.0, d + 0.2));
	// white frost crackling over its foot, in veins and patches
	float hy = v_wpos.y - v_foot;
	float nz = texture(noise, vec2(v_wpos.x + v_wpos.z * 0.8, hy * 1.6 + v_wpos.z * 0.3) * 0.55).r;
	float nz2 = texture(noise, vec2(v_wpos.x * 1.7 - v_wpos.z, hy * 2.4) * 0.5 + 0.3).r;
	float low = 1.0 - smoothstep(0.0, frost_h, hy + (nz - 0.5) * 0.35);
	float patch_ = low * aastep(0.42, nz2);
	float vein = (1.0 - aastep(0.035, abs(nz - 0.5))) * (1.0 - smoothstep(0.0, frost_h * 1.5, hy));
	float frost = max(patch_, vein);
	col = mix(col, vec3(1.0), frost);
	a = mix(a, 0.95, frost);
	// a deep blue outline round the silhouette, never under outline_px pixels
	float fres = 1.0 - clamp(dot(N, VIEW), 0.0, 1.0);
	float ow = clamp(outline_px * fwidth(fres), 0.14, 0.5);
	float o = aastep(1.0 - ow, fres);
	col = mix(col, c_ink, o);
	a = mix(a, 1.0, o);
	ALBEDO = col * fx_gain;
	ALPHA = clamp(a, 0.0, 1.0);
}
