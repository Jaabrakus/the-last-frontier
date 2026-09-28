shader_type spatial;
// Outline of the interaction highlight (next_pass of highlight.gdshader): the target's back faces pushed out
// along their normals by about the same number of pixels at any distance, so thin things (a musket barrel,
// an arrow) read from the third-person camera.
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform vec4 glow_color : source_color = vec4(1.0, 0.72, 0.28, 1.0);
uniform float width = 0.006;   // m at 1 m from the camera

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	VERTEX += NORMAL * width * clamp(-VERTEX.z, 0.5, 30.0);
}

void fragment() {
	float pulse = 0.8 + 0.2 * sin(TIME * 4.0);
	ALBEDO = glow_color.rgb * pulse;
}
