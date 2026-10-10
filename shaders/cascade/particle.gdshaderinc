// Per-particle inputs for the Cascade runtime (cascade.gd).
// Sprites/meshes (MultiMesh): COLOR = particle colour, INSTANCE_CUSTOM = dynamic params,
// extra_tex[INSTANCE_ID] = (sub-image, flip bits, relative time, random).
// Ribbons/beams (ImmediateMesh): COLOR, UV2.x = relative time; dynamic params = 1.
uniform sampler2D extra_tex : filter_nearest;
uniform bool is_trail = false;
uniform vec2 grid = vec2(1.0);          // SubImages_Horizontal / Vertical
uniform bool subuv_blend = false;
uniform vec2 pivot = vec2(0.0);

varying vec4 v_extra;
varying vec4 v_dyn;
varying vec4 v_color;
varying vec2 v_quv;

void particle_vertex(inout vec3 vtx, inout vec2 uv, vec4 custom, int instance_id, vec2 uv2, out vec4 extra, out vec4 dynv) {
	if (is_trail) {
		extra = vec4(0.0, 0.0, uv2.x, fract(uv2.y * 17.31));
		dynv = vec4(1.0);
	} else {
		extra = texelFetch(extra_tex, ivec2(instance_id, 0), 0);
		dynv = custom;
		vtx.xy += pivot;
		int flip = int(extra.y + 0.5);
		if ((flip & 1) != 0) { uv.x = 1.0 - uv.x; }
		if ((flip & 2) != 0) { uv.y = 1.0 - uv.y; }
	}
}

vec2 particle_atlas(vec2 quv) {
	if (grid.x * grid.y <= 1.0) { return quv; }
	float i = floor(v_extra.x);
	vec2 cell = vec2(mod(i, grid.x), floor(i / grid.x));
	return (cell + quv) / grid;
}
