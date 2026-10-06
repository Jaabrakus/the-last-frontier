extends SceneTree
## Every Thủy Vân kit piece as the engine draws it (ThuyVanKit: the ROCK, VILLAGE and PAINT vegetation kits with their
## imported materials), one panel per group on a neutral painted ground (PAINT's terrain array, the grass slice at 8 m)
## under bright noon (palettes.json "bright_saturated_noon": its painted sky, ambient, fog and grade LUT), with the
## lineup's own sun from the front-left at 40° (style_guide.md 11). Each panel is shot, captioned with every piece's
## name and LOD0 triangles, and the panels are stitched into one sheet. A 1.75 m porter stands beside the people-sized
## groups. Needs a window:
##
##   Godot --path . --resolution 1280x720 -s tools/thuyvan_look/kit_lineup.gd -- out=FILE.png [only=houses,plants]
##       [panels=DIR]
##
## The sheet goes to `out`; `panels` also keeps each panel's PNG.

const Kit := preload("res://scripts/thuyvan/look/thuyvan_kit.gd")
const PALETTES := "res://docs/thuyvan/plan/look/palettes.json"
const DIRECTION := "bright_saturated_noon"
const SKY := "res://assets/thuyvan/paint/sky/tv_sky_bright_saturated_noon.png"
const LUT := "res://assets/thuyvan/paint/grade/tv_grade_bright_saturated_noon_64.png"
const TERRAIN := "res://assets/thuyvan/paint/terrain/tv_terrain_albedo_array.webp"
const SKY_SHADER := "res://shaders/thuyvan/tv_sky.gdshader"
const W := 1280
const H := 720
const COLS := 2
## [id, caption, [[kit, piece, variant], ...], porter beside]
const PANELS := [
	["karst_hero", "ROCK R01 karst hero towers (110-240 m)", [["rock", "karst_hero_a"], ["rock", "karst_hero_b"],
			["rock", "karst_hero_c"], ["rock", "karst_hero_d"], ["rock", "karst_hero_e"]], false],
	["karst_far", "ROCK R02 karst backdrop towers (200 m, scaled to the K heights in the vista)", [["rock", "karst_far_a"],
			["rock", "karst_far_b"], ["rock", "karst_far_c"], ["rock", "karst_far_d"], ["rock", "karst_far_e"],
			["rock", "karst_far_f"]], false],
	["walls", "ROCK R03 gorge-wall modules (40 m wide) and R07 the bridge needle", [["rock", "cliff_straight_30"],
			["rock", "cliff_straight_60"], ["rock", "cliff_straight_75"], ["rock", "cliff_convex_60"],
			["rock", "cliff_concave_75"], ["rock", "cliff_notch_75"], ["rock", "cliff_ledge_30"], ["rock", "bridge_needle"]],
			false],
	["two_heights", "ROCK R06 the Two Heights bridge and its two stone heads", [["rock", "two_heights_head_s"],
			["rock", "two_heights_bridge"], ["rock", "two_heights_head_n"]], false],
	["stones", "ROCK R04 boulders, R05 the white stones of Đá Trắng, R08 burial cairns", [["rock", "boulder_a"],
			["rock", "boulder_b"], ["rock", "boulder_c"], ["rock", "boulder_d"], ["rock", "boulder_e"], ["rock", "boulder_f"],
			["rock", "white_stones"], ["rock", "cairn_a"], ["rock", "cairn_b"], ["rock", "cairn_c"], ["rock", "cairn_d"],
			["rock", "cairn_e"]], true],
	["houses", "VILLAGE V01-V04 stilt houses, cliff house, clan house, gate tower and pavilion",
			[["village", "stilt_house_small"], ["village", "stilt_house_large"], ["village", "cliff_house"],
			["village", "clan_house"], ["village", "gate_tower"], ["village", "gate_pavilion"]], true],
	["bridge", "VILLAGE V05 the R1 rope bridge (143 m, two spans on the needle platform) and its modules",
			[["village", "rope_bridge_r1"]], false],
	["bridge_parts", "VILLAGE V05 rope-bridge modules: anchor, needle platform, 30 / 63 / 73 m spans",
			[["village", "rope_bridge_anchor"], ["village", "rope_bridge_needle_platform"], ["village", "rope_bridge_span_30m"],
			["village", "rope_bridge_span_63m"], ["village", "rope_bridge_span_73m"]], true],
	["marks", "VILLAGE V06-V09 clan waystone, banners, prayer flags, lanterns and the bridge lamp",
			[["village", "clan_waystone"], ["village", "banner_indigo"], ["village", "banner_ochre"], ["village", "banner_jade"],
			["village", "prayer_flags_4m"], ["village", "prayer_flags_8m"], ["village", "lantern_post"],
			["village", "lantern_round"], ["village", "lantern_barrel"], ["village", "bridge_lamp"]], true],
	["clutter", "VILLAGE V10-V15 terraces, fences, clutter, sampan, survey camp and the porters",
			[["village", "terrace_wall_straight_4m"], ["village", "terrace_wall_curve_in_4m"],
			["village", "terrace_wall_curve_out_4m"], ["village", "paddy_bund_4m"], ["village", "fence_bamboo_3m"],
			["village", "fence_wattle_2m"], ["village", "drying_rack"], ["village", "firewood_pile"], ["village", "basket_set"],
			["village", "water_jars"], ["village", "sampan"], ["village", "survey_camp"], ["village", "porter_pole"],
			["village", "porter_walking"]], true],
	["trees", "PAINT vegetation: broadleaf, karst pine, bamboo, banana (painted cards on puff meshes)",
			[["veg", "tv_broadleaf", 0], ["veg", "tv_broadleaf", 1], ["veg", "tv_broadleaf", 2], ["veg", "tv_karst_pine", 0],
			["veg", "tv_karst_pine", 1], ["veg", "tv_karst_pine", 2], ["veg", "tv_bamboo", 0], ["veg", "tv_bamboo", 1],
			["veg", "tv_banana", 0]], true],
	["plants", "PAINT vegetation: ferns and shrubs", [["veg", "tv_fern", 0], ["veg", "tv_fern", 1], ["veg", "tv_fern", 2],
			["veg", "tv_shrub", 0], ["veg", "tv_shrub", 1], ["veg", "tv_shrub", 2]], true],
]

var _out := ""
var _panels_dir := ""
var _only: Array = []
var _world: Node3D
var _cam: Camera3D
var _ui: CanvasLayer
var _dir := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
		elif a.begins_with("panels="):
			_panels_dir = a.substr(7)
		elif a.begins_with("only="):
			_only = Array(a.substr(5).split(","))
	if _out.is_empty() or DisplayServer.get_name() == "headless":
		push_error("kit_lineup: needs out=FILE.png and a window")
		quit(1)
		return
	if not _panels_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_panels_dir)
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var pal: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALETTES))
	_dir = pal["directions"][DIRECTION] if pal is Dictionary else {}
	root.size = Vector2i(W, H)
	_run.call_deferred()


func _run() -> void:
	_stage()
	var shots: Array[Image] = []
	for p: Array in PANELS:
		if not _only.is_empty() and not (p[0] in _only):
			continue
		var img := await _panel(p)
		if img:
			shots.append(img)
			if not _panels_dir.is_empty():
				img.save_png("%s/%s.png" % [_panels_dir, p[0]])
	var rows := ceili(float(shots.size()) / COLS)
	var sheet := Image.create(W * mini(COLS, shots.size()), H * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.93, 0.91, 0.86))
	for i in shots.size():
		shots[i].convert(Image.FORMAT_RGB8)
		sheet.blit_rect(shots[i], Rect2i(0, 0, W, H), Vector2i((i % COLS) * W, (i / COLS) * H))
	sheet.save_png(_out)
	print("KIT LINEUP %d panels -> %s" % [shots.size(), _out])
	quit(0)


## The light, sky, fog and grade of bright noon, the painted ground and the camera.
func _stage() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	var sun := DirectionalLight3D.new()
	var s: Dictionary = _dir.get("sun", {})
	sun.light_color = Color(String(s.get("color", "#fff3d9")))
	sun.light_energy = 1.6
	sun.light_angular_distance = float(s.get("angular_deg", 0.8))
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 1500.0
	_world.add_child(sun)
	# the lineup's sun (style guide 11): elevation 40° from the front-left, the camera looking north (-Z)
	var el := deg_to_rad(40.0)
	var to_sun := Vector3(-0.55, 0.0, 0.84).normalized() * cos(el) + Vector3.UP * sin(el)
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	var env := Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SKY_SHADER)
	sky_mat.set_shader_parameter("panorama", load(SKY))
	var fog: Dictionary = _dir.get("fog", {})
	sky_mat.set_shader_parameter("ground_tint", Color(String(fog.get("color", "#b5d3ec"))))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	var amb: Dictionary = _dir.get("ambient", {})
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(String(amb.get("color", "#9ec3e6")))
	env.ambient_light_sky_contribution = float(amb.get("sky_contribution", 0.5))
	env.ambient_light_energy = float(amb.get("energy", 1.25))
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_agx_contrast = float(_dir.get("grade", {}).get("contrast", 1.15))
	env.fog_enabled = true
	env.fog_light_color = Color(String(fog.get("color", "#b5d3ec")))
	env.fog_density = float(fog.get("density", 0.00035))
	env.fog_aerial_perspective = float(fog.get("aerial_perspective", 0.4))
	env.fog_sun_scatter = float(fog.get("sun_scatter", 0.05))
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 0.6
	env.glow_enabled = true
	env.glow_hdr_threshold = 0.9
	env.glow_intensity = 0.4
	env.glow_bloom = 0.05
	var lut := load(LUT) as Texture3D
	if lut:
		env.adjustment_enabled = true
		env.adjustment_color_correction = lut
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	# the neutral painted ground: PAINT's grass slice (terrain_slices.json slice 0) at its 8 m tile
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6000, 6000)
	ground.mesh = plane
	var gm := ShaderMaterial.new()
	var gs := Shader.new()
	gs.code = """shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;
uniform sampler2DArray slices : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_m = 8.0;
uniform float slice = 0.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 a = texture(slices, vec3(wp.xz / tile_m, slice)).rgb;
	vec3 b = texture(slices, vec3(wp.zx / (tile_m * 2.7) + 0.37, slice)).rgb;
	float m = 0.5 + 0.5 * sin(wp.x * 0.021) * sin(wp.z * 0.017);
	ALBEDO = mix(a, b, 0.35 * m);
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
"""
	gm.shader = gs
	gm.set_shader_parameter("slices", load(TERRAIN))
	ground.material_override = gm
	_world.add_child(ground)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.far = 20000.0
	_world.add_child(_cam)
	_cam.make_current()
	_ui = CanvasLayer.new()
	root.add_child(_ui)


## One panel: its pieces in a row along X on the ground, the camera fitting them in a 3/4 view, captions, one shot.
func _panel(p: Array) -> Image:
	var holder := Node3D.new()
	_world.add_child(holder)
	var items: Array = []   # [node, name, tris, box]
	for e: Array in p[2]:
		var n: Node3D
		var label := String(e[1])
		match String(e[0]):
			"rock":
				n = Kit.rock(e[1], false)
			"village":
				n = Kit.village(e[1])
			"veg":
				n = Kit.plant(e[1], int(e[2]), 0)
				label = "%s v%d" % [e[1], int(e[2])]
		if n == null:
			push_error("kit_lineup: %s %s did not load" % [e[0], e[1]])
			continue
		holder.add_child(n)
		items.append([n, label, _tris(n), Kit.bounds(n)])
	if items.is_empty():
		holder.queue_free()
		return null
	# lay out left to right, a gap of a quarter of the bigger neighbour's width (min 0.6 m)
	var x := 0.0
	var span := AABB()
	for i in items.size():
		var n: Node3D = items[i][0]
		var box: AABB = items[i][3]
		var gap := maxf(0.6, 0.25 * box.size.x) if i > 0 else 0.0
		x += gap
		# pieces that hang from their origin (gorge walls from the lip, the bridges from the deck) stand on the ground
		var lift := -box.position.y if box.position.y < -0.5 * box.size.y else 0.0
		n.position += Vector3(x - box.position.x, lift, -box.get_center().z)
		x += box.size.x
		items[i][3] = Kit.bounds(n)
		span = items[i][3] if i == 0 else span.merge(items[i][3])
	if p[3]:
		var porter := Kit.village("porter_standing")
		if porter:
			holder.add_child(porter)
			porter.position = Vector3(span.position.x - 1.2, 0.0, span.get_center().z + span.size.z * 0.5 + 0.6)
			span = span.merge(Kit.bounds(porter))
	_frame(span)
	for i in 4:
		await process_frame
	var tags: Array[Control] = []
	tags.append(_tag(p[1], Vector2(14, 10), 20, true))
	for it: Array in items:
		var box: AABB = it[3]
		var foot := Vector3(box.get_center().x, 0.0, box.end.z)
		if _cam.is_position_behind(foot):
			continue
		var at := _cam.unproject_position(foot) + Vector2(-40, 8)
		tags.append(_tag("%s\n%d tris" % [it[1], it[2]], at.clamp(Vector2(4, 40), Vector2(W - 150, H - 44)), 13, false))
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	for t in tags:
		t.queue_free()
	holder.queue_free()
	await process_frame
	print("panel ", p[0], " ", items.size(), " pieces, span ", span.size)
	return img


## Camera on a 3/4 view from the front-right and a little above, far enough that the whole span fits.
func _frame(span: AABB) -> void:
	var c := span.get_center()
	var dir := Vector3(0.22, 0.22, 1.0).normalized()
	var vh := deg_to_rad(_cam.fov) * 0.5
	var hh := atan(tan(vh) * float(W) / H)
	var d := maxf(span.size.x * 0.5 / tan(hh), span.size.y * 0.5 / tan(vh)) * 1.12 + span.size.z * 0.5
	_cam.position = c + dir * d
	_cam.look_at(c + Vector3(0, -span.size.y * 0.04, 0), Vector3.UP)
	_cam.near = maxf(0.05, d * 0.002)


func _tag(text: String, at: Vector2, size: int, title: bool) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.12, 0.78) if not title else Color(0.95, 0.93, 0.87, 0.92)
	sb.set_content_margin_all(5)
	panel.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiFonts.sans(600 if title else 500))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92) if not title else Color(0.12, 0.12, 0.14))
	panel.add_child(l)
	panel.position = at
	_ui.add_child(panel)
	return panel


func _tris(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var m: Mesh = (n as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			t += (idx as PackedInt32Array).size() / 3 if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	for c in n.get_children():
		t += _tris(c)
	return t
