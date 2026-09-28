// Weathering for the Frontier fort structures (look-dev spec, section 8.2). Owner: package D.
// World-space, so it reads the same on every building, crate and log without per-object
// setup. Included by res://shaders/structures/structure.gdshader; call the functions from
// fragment() with the world position / geometric world normal passed from vertex().
//
//   noise: res://assets/environment/structures/textures/structure_noise_512.png
//          R broad fbm, G medium fbm, B vertical streaks, A fine grain (all tileable)
//
// Effects (strength 0 turns one off):
//   frontier_ground_dirt    splash / dirt darkening 0 .. dirt_height above the ground (y = 0 in
//                           the fort; structures stand on the flat zone)
//   frontier_rain_streaks   vertical run-off streaks on vertical faces, stronger under the tops
//   frontier_moss           moss low on north faces and on north-facing roof slopes, lichen dots
//   frontier_sun_bleach     south / west faces greyer, lighter and rougher (sun-bleached wood)
//   frontier_edge_wear      lighter, smoother worn edges (edge factor baked per vertex)

const vec3 FRONTIER_LUMA = vec3(0.2126, 0.7152, 0.0722);

// 2D coordinates on a surface for world-space noise: horizontal faces use XZ, vertical faces
// use (horizontal distance along the face, height), so streaks and splash run vertically.
vec2 frontier_face_uv(vec3 wp, vec3 wn) {
	vec2 t = normalize(vec2(-wn.z, wn.x) + vec2(1e-4, 0.0));
	vec2 side = vec2(dot(wp.xz, t), wp.y);
	return mix(side, wp.xz, step(0.7, abs(wn.y)));
}

void frontier_ground_dirt(inout vec3 albedo, inout float rough, vec3 wp, vec3 wn, float ground_y,
		float dirt_height, float strength, vec3 dirt_tint, sampler2D noise) {
	if (strength <= 0.0) {
		return;
	}
	vec2 fuv = frontier_face_uv(wp, wn);
	float n = texture(noise, fuv * vec2(0.9, 0.9)).g;
	float n2 = texture(noise, fuv * vec2(3.1, 1.4)).a;
	float h = wp.y - ground_y;
	float reach = dirt_height * (0.55 + 0.9 * n);
	float splash = 1.0 - smoothstep(reach * 0.35, reach, h + (n2 - 0.5) * 0.08);
	splash *= 1.0 - 0.6 * step(0.7, wn.y);         // tops of low things stay cleaner
	albedo = mix(albedo, albedo * dirt_tint, clamp(splash * strength, 0.0, 1.0));
	rough = mix(rough, min(rough + 0.08, 1.0), splash);
}

void frontier_rain_streaks(inout vec3 albedo, vec3 wp, vec3 wn, float strength, float top_y,
		sampler2D noise) {
	if (strength <= 0.0) {
		return;
	}
	float vertical = 1.0 - abs(wn.y);
	vec2 fuv = frontier_face_uv(wp, wn);
	float s = texture(noise, fuv * vec2(0.85, 0.11)).b;
	float streak = smoothstep(0.5, 0.78, s);
	// Stronger in the first ~1.5 m under a top edge (eaves, log tops, sills).
	float under_top = 1.0 - smoothstep(0.0, 1.6, top_y - wp.y);
	streak *= vertical * (0.45 + 0.55 * under_top);
	albedo *= 1.0 - strength * streak;
}

void frontier_moss(inout vec3 albedo, inout float rough, vec3 wp, vec3 wn, float ground_y,
		float strength, float roof_strength, vec3 moss_color, float lichen, sampler2D noise) {
	vec2 fuv = frontier_face_uv(wp, wn);
	float n = texture(noise, fuv * 0.55).r;
	float g = texture(noise, fuv * 2.3).g;
	float north = clamp(-wn.z, 0.0, 1.0);                       // north = -Z
	float low = 1.0 - smoothstep(0.1, 1.4, wp.y - ground_y);
	float wall = strength * north * low * (1.0 - abs(wn.y));
	// North-facing roof slopes: moss collects in the shade.
	float roof = roof_strength * smoothstep(0.35, 0.8, wn.y) * smoothstep(0.05, 0.4, -wn.z);
	float m = clamp(wall + roof, 0.0, 1.0) * smoothstep(0.35, 0.75, n * 0.7 + g * 0.5);
	albedo = mix(albedo, moss_color * (0.8 + 0.4 * g), m);
	rough = mix(rough, 0.97, m);
	// Lichen: sparse pale grey-green dots on weathered wood and stone.
	float l = smoothstep(0.78, 0.86, texture(noise, fuv * 4.7).a) * lichen;
	albedo = mix(albedo, vec3(0.46, 0.48, 0.41), l * 0.6);
}

void frontier_sun_bleach(inout vec3 albedo, inout float rough, vec3 wn, vec3 sun_dir, float strength) {
	if (strength <= 0.0) {
		return;
	}
	vec2 s = normalize(sun_dir.xz + vec2(1e-4));
	vec2 h = wn.xz;
	float facing = clamp(dot(normalize(h + vec2(1e-4)), s), 0.0, 1.0) * (1.0 - abs(wn.y)) * length(h);
	facing = max(facing, 0.6 * clamp(wn.y, 0.0, 1.0));         // tops weather as well
	float grey = dot(albedo, FRONTIER_LUMA);
	vec3 bleached = mix(albedo, vec3(grey) * vec3(1.02, 1.0, 0.97), 0.6) * 1.12;
	albedo = mix(albedo, bleached, facing * strength);
	rough = mix(rough, min(rough + 0.06, 1.0), facing * strength);
}

void frontier_edge_wear(inout vec3 albedo, inout float rough, float edge, float strength, float grain) {
	float e = clamp(edge * strength * (0.6 + 0.8 * grain), 0.0, 1.0);
	albedo = mix(albedo, albedo * 1.22 + vec3(0.015), e);
	rough = mix(rough, rough - 0.08, e);
}

// Soot above soot_y - 1 m (chimney tops).
void frontier_soot(inout vec3 albedo, vec3 wp, vec3 wn, float soot_y, sampler2D noise) {
	vec2 fuv = frontier_face_uv(wp, wn);
	float n = texture(noise, fuv * vec2(1.3, 0.5)).b;
	float s = smoothstep(soot_y - 1.1, soot_y - 0.1, wp.y + (n - 0.5) * 0.6);
	albedo *= 1.0 - 0.72 * s;
}
