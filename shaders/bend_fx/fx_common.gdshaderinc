// Shared by the bent elements' cel effects (ToonFx, scripts/fx/toon_fx.gd): hard-edged steps that stay smooth over a
// pixel, the camera-facing ways a flat thing can stand (a particle billboard, a quad turned only round its own axis, a
// strip along a line), and a cel light from a fixed sun.

// 0 below `edge`, 1 above, blended over about a pixel (no stairs on the cut).
float aastep(float edge, float v) {
	float w = max(fwidth(v) * 0.75, 1e-4);
	return smoothstep(edge - w, edge + w, v);
}

// A quad whose local Y is `axis_w` (world, its length the height) turned round that axis to face the camera; local X spans
// `width` (m). The point `c` is its base. Returns the world position of local `v` (x -0.5..0.5, y 0..1).
vec3 axis_billboard(vec3 v, vec3 c, vec3 axis_w, float width, vec3 fallback_side, vec3 cam) {
	vec3 ax = normalize(axis_w);
	vec3 side = cross(ax, normalize(cam - c));
	float l = length(side);
	side = l > 1e-3 ? side / l : fallback_side;
	return c + side * v.x * width + axis_w * v.y;
}

// A strip along a line: `v` the centre (world: the strip's MeshInstance at the origin), `along` the line's direction,
// `hw` the half width, `across` 0..1 from one edge to the other. Returns the edge point, turned to face the camera.
vec3 strip_point(vec3 v, vec3 along, float hw, float across, vec3 cam) {
	vec3 side = cross(normalize(along + vec3(1e-6)), normalize(cam - v));
	float l = length(side);
	side = l > 1e-4 ? side / l : vec3(0.0, 1.0, 0.0);
	return v + side * hw * (across * 2.0 - 1.0);
}

// The sun's way in view space (a fixed high sun from behind the left shoulder: the cel light of the effects).
vec3 cel_light(mat4 view) {
	return normalize((view * vec4(0.35, 0.85, 0.40, 0.0)).xyz);
}
