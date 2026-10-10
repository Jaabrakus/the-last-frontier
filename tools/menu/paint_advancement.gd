extends SceneTree
## Paints the Character Advancement window's four backdrops, one per element, from our own Tidebreak ring
## (scenes/ring.tscn: its deck, tank, stands and sky, RingLook's moods) and our own element effects (FormRaised and
## FormModels' stone, BendZone, BendLooks and ToonFx's flame and wind materials, the ring's own water-curtain shader), run
## twice through shaders/ui/oil_paint.gdshader as tools/menu/paint_views.gd does (broad masses, then the strokes, the
## canvas and the varnish). Composed like the owner's reference window: one strong focal image in the centre gap (FOCUS_X,
## where the window's two trees leave room), quieter, darker ground left and right where the trees and the rail sit.
##   earth   a ring of raised slabs round a stone column, boulders lifted round its head, at golden hour
##   water   a geyser thrown up out of the dark tank water at night, under the moon
##   fire    a blaze at dusk, two lines of fire running in to it along the deck, embers rising, the sun set behind
##   air     a whirling funnel of wind, dust, stones and torn cloth over the deck at noon
## No fighters, no third-party art (nothing Spellbreak-derived is loaded: only the game's own scripts, meshes and shaders).
## Windowed (it draws; the render itself is off-window, tools/environment/offscreen_view.gd):
##
##   Godot --path . --resolution 1600x900 --always-on-top -s tools/menu/paint_advancement.gd -- [out=<abs dir>]
##         [only=earth,water] [raw] [probe]
##   Godot --path . --resolution 1600x900 --always-on-top -s tools/menu/paint_advancement.gd -- sheet [out=<abs png>]
##
## Writes backdrop_<element>.jpg (1920x1080, from a 2560x1440 render) to `out` (default assets/ui/advancement/), and
## backdrop_<element>_raw.png (the render before the paint) with `raw`. `probe` writes small views of the deck from eight
## headings in each mood instead (probe_<mood>_<deg>.png) and prints the sun's and the moon's bearings. `sheet` loads no
## level: it lays out the window's art (assets/ui/advancement/art.json: the four backdrops, the frame pieces, marks, glyphs
## and emblems at the sizes the window draws them, every node's icon) and writes the contact sheet (default
## artifacts/ui_audit/advancement/art_sheet.png). Its SVGs are drawn from the files themselves (no import needed).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const OUT := "res://assets/ui/advancement/"
const RENDER := Vector2i(2560, 1440)
const SHIP := Vector2i(1920, 1080)
## Where the window's centre gap puts the focal object, as a fraction of the frame's width (plan: x 580-900 of 1520).
const FOCUS_X := 0.465
const CURTAIN := "res://shaders/ring/ring_curtain.gdshader"

## Per element:
##   mood           RingLook's mood
##   sun / moon     where to put it (bearing deg, 0 = +X, 90 = +Z; elevation deg): the clock's date and hour that come
##                  closest (_sky_to)
##   at             the focal point (world); bearing, dist, eye_h, look_h, fov: the camera (_place)
##   grow           frames for the effect to grow before the last burst; snap: frames from the burst to the still
##   grade          the pre-paint grade: contrast, saturation, gain (RGB), top and bottom (darkening toward them)
const SCENES := {
	"earth": {"mood": "golden", "sun": Vector2(140.0, 5.5), "at": Vector3(9.0, 0.0, 0.0), "bearing": 12.0, "dist": 13.5,
			"eye_h": 0.8, "look_h": 4.1, "fov": 52.0, "grow": 150, "snap": 14,
			"grade": {"contrast": 1.16, "saturation": 1.4, "gain": Color(1.12, 0.95, 0.76), "top": 0.24, "bottom": 0.2}},
	"water": {"mood": "night", "moon": Vector2(97.0, 24.0), "at": Vector3(0.6, -1.4, 10.0), "bearing": 92.0, "dist": 16.5,
			"eye_h": 4.2, "look_h": 6.6, "fov": 50.0, "grow": 60, "snap": 12,
			"grade": {"contrast": 1.12, "saturation": 1.3, "gain": Color(0.86, 0.98, 1.16), "top": 0.0, "bottom": 0.35}},
	"fire": {"mood": "golden", "sun": Vector2(172.0, -4.5), "at": Vector3(-9.0, 0.0, 0.0), "bearing": 178.0, "dist": 14.0,
			"eye_h": 1.1, "look_h": 3.2, "fov": 50.0, "grow": 80, "snap": 10,
			"grade": {"contrast": 1.14, "saturation": 1.3, "gain": Color(1.03, 0.9, 1.04), "top": 0.1, "bottom": 0.45}},
	"air": {"mood": "noon", "at": Vector3(9.0, 0.0, 0.0), "bearing": 6.0, "dist": 16.5, "eye_h": 1.0, "look_h": 5.0,
			"fov": 58.0, "grow": 90, "snap": 12,
			"grade": {"contrast": 1.16, "saturation": 1.5, "gain": Color(0.9, 1.0, 1.12), "top": 0.3, "bottom": 0.25}},
}
## The side shade baked under the paint (multiplied; the window adds its own, tunable): the trees' thirds quieter.
const SHADE := [[0.0, 0.56], [0.18, 0.66], [0.32, 0.88], [0.39, 1.0], [0.56, 1.0], [0.64, 0.88], [0.8, 0.68], [1.0, 0.56]]
## The varnish for these (bolder than the menu's: the window's own shade and frame sit over them).
const VARNISH := {"umber": Color(0.045, 0.034, 0.028), "ivory": Color(1.0, 0.96, 0.87), "vignette": 0.28, "lift": 0.93,
		"stroke_amt": 0.2, "canvas_amt": 0.07}
## The two passes' brushes (Kuwahara radius, px at the 2560 render): broad masses, then the strokes. (Smaller than the menu's:
## the focal forms keep their edges; the finish below then brings the render's own edge detail back into the centre.)
const BRUSH := Vector2i(7, 3)
## The finish: how much of the render's edge detail returns in the centre gap and at the sides (the trees' zones stay calm
## paint), and the level the highlights are held under (a blown white reads as a smear, not a form).
const DETAIL := {"centre": 0.55, "side": 0.0, "cap": 0.84, "focus_x": 0.465, "reach": 0.2}
## The finish shader: the painted image plus the graded render's high-pass detail, weighted by the distance from the focal
## column, its highlights held under `cap` by a soft shoulder.
const FINISH_SHADER := """
shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D detail : filter_linear;
uniform float centre = 0.5;
uniform float side = 0.0;
uniform float cap = 0.85;
uniform float focus_x = 0.465;
uniform float reach = 0.2;
void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE;
	vec3 p = texture(TEXTURE, UV).rgb;
	vec3 d = texture(detail, UV).rgb;
	vec3 b = vec3(0.0);
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			b += texture(detail, UV + vec2(float(i), float(j)) * ps * 1.6).rgb;
		}
	}
	b /= 25.0;
	float w = 1.0 - smoothstep(reach, reach * 2.2, abs(UV.x - focus_x));
	float amt = mix(side, centre, w);
	vec3 col = p + (d - b) * amt * 2.0;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	if (l > cap) {
		col *= (cap + (l - cap) * 0.3) / l;
	}
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
"""
## The pre-paint grade (contrast and saturation round mid grey, a gain, the side shade, a darkening toward the top).
const GRADE_SHADER := """
shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D shade : filter_linear;
uniform float contrast = 1.0;
uniform float saturation = 1.0;
uniform vec3 gain = vec3(1.0);
uniform float top = 0.0;
uniform float bottom = 0.0;
void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.45) * contrast + 0.45;
	c *= gain;
	c *= texture(shade, vec2(UV.x, 0.5)).r;
	c *= 1.0 - top * smoothstep(0.42, 0.0, UV.y);
	c *= 1.0 - bottom * smoothstep(0.66, 1.0, UV.y);
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
"""

var out := ""
var only: Array = []
var keep_raw := false
var probe := false
var sheet := false
var lvl: RingLevel
var view
var noises: Array = []
var made: Array[Node] = []
var by: Node3D
## The camera's eye for the scene being staged (the flames face it).
var eye := Vector3.ZERO


func _initialize() -> void:
	out = ProjectSettings.globalize_path(OUT)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("only="):
			only = Array(a.get_slice("=", 1).split(","))
		elif a == "raw":
			keep_raw = true
		elif a == "probe":
			probe = true
		elif a == "sheet":
			sheet = true
	if sheet:
		_contact_sheet.call_deferred()
		return
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)      # the desk's keys stay out of it
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(5)
	lvl = current_scene as RingLevel
	if lvl == null:
		push_error("paint_advancement: the ring did not load")
		quit(1)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if lvl.player != null:
		lvl.player.visible = false                # no fighters in the paintings
		lvl.player.global_position = Vector3(0.0, -30.0, 60.0)
		lvl.player.process_mode = Node.PROCESS_MODE_DISABLED
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, RENDER if not probe else Vector2i(960, 540))
	root.disable_3d = true
	view.camera.far = 1500.0
	if lvl.environment_rig != null:
		lvl.environment_rig.follow_camera = view.camera
		if lvl.environment_rig.get_camera_attributes():
			lvl.environment_rig.get_camera_attributes().auto_exposure_speed = 30.0
	for i in 3:
		var fn := FastNoiseLite.new()
		fn.seed = 23 + i * 7
		fn.frequency = 0.02 if i < 2 else 0.09
		var nt := NoiseTexture2D.new()
		nt.width = 256
		nt.height = 256
		nt.seamless = true
		nt.noise = fn
		noises.append(nt)
	by = Node3D.new()
	by.name = "PainterHand"
	current_scene.add_child(by)
	by.global_position = Vector3(0.0, 0.0, -30.0)
	await _frames(60)
	if probe:
		await _probe()
		print("PAINT ADVANCEMENT PROBE DONE")
		quit(0)
		return
	for el: String in SCENES:
		if not only.is_empty() and not (el in only):
			continue
		await _scene(el)
	print("PAINT ADVANCEMENT DONE")
	quit(0)


# ------------------------------------------------------------------------------------------------------------- light
func _clock() -> WorldClock:
	var rig := lvl.environment_rig
	return rig.clock_driver.clock if rig != null and rig.clock_driver else null


## The bearing (deg, 0 = +X, 90 = +Z) and elevation of the sun and the moon, and the clock's time.
func _sky_bearings() -> Dictionary:
	var outd := {}
	var clock := _clock()
	if clock == null:
		return outd
	for k: String in ["sun", "moon"]:
		var d: Vector3 = clock.sun_direction() if k == "sun" else clock.moon_direction()
		outd[k] = Vector2(rad_to_deg(atan2(d.z, d.x)), rad_to_deg(asin(clampf(d.y, -1.0, 1.0)))).round()
	outd["time"] = clock.time_string()
	return outd


static func _bearing_el(d: Vector3) -> Vector2:
	return Vector2(rad_to_deg(atan2(d.z, d.x)), rad_to_deg(asin(clampf(d.y, -1.0, 1.0))))


## The clock set (stopped) to the date and hour that put `body` ("sun" or "moon") nearest `want` (bearing, elevation):
## a moon only on a dark night (the sun 14 deg down or more) and at least half lit.
func _sky_to(body: String, want: Vector2) -> void:
	var clock := _clock()
	if clock == null:
		return
	var best := INF
	var pick := Vector2(-1.0, -1.0)
	for doy in range(1, 366, 2):
		clock.set_date(float(doy))
		for k in 288:
			var h := float(k) / 12.0
			clock.set_time(h)
			if body == "moon":
				if clock.sun_elevation_deg() > -14.0 or clock.moon_illumination() < 0.5:
					continue
			var be := _bearing_el(clock.sun_direction() if body == "sun" else clock.moon_direction())
			var db := absf(wrapf(be.x - want.x, -180.0, 180.0))
			var score := db * 0.5 + absf(be.y - want.y) * 3.0
			if score < best:
				best = score
				pick = Vector2(doy, h)
	if pick.x > 0.0:
		clock.set_date(pick.x)
		clock.set_time(pick.y)
		clock.running = false


func _mood(s: Dictionary) -> void:
	RingLook.apply(lvl, String(s.mood))
	if s.has("sun"):
		_sky_to("sun", s.sun)
	if s.has("moon"):
		_sky_to("moon", s.moon)


func _probe() -> void:
	for mood: String in ["golden", "night", "noon"]:
		RingLook.apply(lvl, mood)
		await _frames(40)
		print("PROBE mood=%s sky=%s" % [mood, str(_sky_bearings())])
		for deg in range(0, 360, 45):
			_place(Vector3.ZERO, float(deg), 12.0, 1.2, 2.5, 50.0, false)
			await _frames(25)
			var img: Image = view.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_png(out.path_join("probe_%s_%03d.png" % [mood, deg]))


# ------------------------------------------------------------------------------------------------------------ camera
## The camera `dist` m back from `c` along bearing `deg` (0: it looks along +X), its eye `eye_h` over `c`, looking at
## `look_h` over `c`; turned so `c` falls at FOCUS_X across the frame.
func _place(c: Vector3, deg: float, dist: float, eye_h: float, look_h: float, fov: float, shift := true) -> void:
	var way := Vector3(cos(deg_to_rad(deg)), 0.0, sin(deg_to_rad(deg)))
	eye = c - way * dist + Vector3.UP * eye_h
	var at := c + Vector3.UP * look_h
	view.camera.fov = fov
	view.camera.global_transform = Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye)
	if shift:
		# (turning the camera right moves what it sees left: c to FOCUS_X)
		var aspect := float(view.size.x) / float(view.size.y)
		var half_w := tan(deg_to_rad(fov) * 0.5) * aspect
		var yaw := -atan((0.5 - FOCUS_X) * 2.0 * half_w)
		view.camera.global_transform.basis = Basis(Vector3.UP, yaw) * view.camera.global_transform.basis


# ------------------------------------------------------------------------------------------------------------ scenes
func _scene(el: String) -> void:
	var s: Dictionary = SCENES[el]
	_mood(s)
	var dr := RingDressing.find_in(lvl)
	if dr != null:
		dr.set_sides(el, el)                     # both ends' banners in the element's colours
	await _frames(20)
	print("PAINT %s sky=%s" % [el, str(_sky_bearings())])
	var c: Vector3 = s.at
	_place(c, float(s.bearing), float(s.dist), float(s.eye_h), float(s.look_h), float(s.fov))
	match el:
		"earth":
			await _stage_earth(c)
		"water":
			await _stage_water(c)
		"fire":
			await _stage_fire(c)
		"air":
			await _stage_air(c)
	await _frames(int(s.grow))
	_burst(el, c)
	await _frames(int(s.snap))
	await RenderingServer.frame_post_draw
	var img: Image = view.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if keep_raw:
		img.save_png(out.path_join("backdrop_%s_raw.png" % el))
	var graded := await _grade(img, s.grade)
	var painted := await _finish(await _paint(graded), graded)
	painted.resize(SHIP.x, SHIP.y, Image.INTERPOLATE_LANCZOS)
	painted.save_jpg(out.path_join("backdrop_%s.jpg" % el), 0.9)
	print("  painted ", el, " ", painted.get_size())
	await _clear()


func _keep(n: Node) -> Node:
	made.append(n)
	return n


func _clear() -> void:
	for z in get_nodes_in_group(BendZone.GROUP):
		(z as BendZone).queue_free()
	for w in get_nodes_in_group(FormRaised.GROUP):
		(w as Node).queue_free()
	for n in made:
		if is_instance_valid(n):
			n.queue_free()
	made.clear()
	await _frames(240)


func _add(n: Node3D, at: Vector3) -> Node3D:
	current_scene.add_child(n)
	n.global_position = at
	_keep(n)
	return n


func _light(at: Vector3, col: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	_add(l, at)
	return l


## A boulder of our own stone (FormModels.chunk_mesh) hung at `at`, `r` m across, turned.
func _boulder(at: Vector3, r: float, seed: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = FormModels.chunk_mesh(r, seed, "stone")
	mi.material_override = FormModels.stone_material()
	_add(mi, at)
	mi.rotation = Vector3(seed * 0.7, seed * 1.3, seed * 0.4)
	return mi


## The last moment before the still: what flies (stones, spray, embers, grit) thrown up so it is in the air.
func _burst(el: String, c: Vector3) -> void:
	match el:
		"earth":
			BendLooks.burst(c + Vector3.UP * 0.3, "stone", 46, Vector3.UP, 75.0, 5.0, 0.32)
		"water":
			BendLooks.burst(c + Vector3.UP * 10.8, "water", 140, Vector3.UP, 85.0, 5.0, 0.42)
			BendLooks.burst(c + Vector3.UP * 9.8, "water", 90, Vector3.UP, 115.0, 3.4, 0.32)
			BendLooks.burst(c + Vector3.UP * 6.0, "water", 40, Vector3.UP, 120.0, 2.5, 0.26)
			BendLooks.burst(c + Vector3.UP * 0.4, "water", 40, Vector3.UP, 60.0, 4.0, 0.3)
		"fire":
			BendLooks.burst(c + Vector3.UP * 1.0, "fire", 40, Vector3.UP, 50.0, 6.0, 0.18)
		"air":
			BendLooks.burst(c + Vector3.UP * 0.4, "stone", 24, Vector3.UP, 60.0, 4.0, 0.18)


# ------------------------------------------------------------------------------------------------------------- earth
func _stage_earth(c: Vector3) -> void:
	# the column: a tall stone pillar risen at the middle
	var col := FormRaised.raise(current_scene, "pillar", Transform3D(Basis.IDENTITY, c),
			{"matter": "stone", "radius_m": 1.05, "height_m": 7.6, "rise_s": 0.05, "life_s": 900.0}, 11)
	col.hits_max = 999
	# the ring of slabs round it, open toward the camera, leaning out a little
	var n := 9
	var to_cam := Vector3(eye.x - c.x, 0.0, eye.z - c.z).normalized()
	for i in n:
		var a := TAU * float(i) / float(n) + 0.35
		var way := Vector3(cos(a), 0.0, sin(a))
		if way.dot(to_cam) > 0.55:
			continue                               # the gap the camera looks through
		var foot := c + way * 4.3
		var x := Vector3.UP.cross(way).normalized()
		var lean := Basis(x, deg_to_rad(-7.0 - 6.0 * float(i % 3)))
		var b := lean * Basis(x, Vector3.UP, way)
		var h := 2.5 + 1.7 * float((i * 5) % 4) / 3.0
		FormRaised.raise(current_scene, "wall", Transform3D(b, foot),
				{"matter": "stone", "width_m": 1.9, "height_m": h, "thick_m": 0.8, "rise_s": 0.05, "life_s": 900.0}, 20 + i)
	# boulders lifted round the column's head, and grit hanging in the low sun
	var rocks := [[Vector3(0.4, 8.9, -1.9), 0.78], [Vector3(-0.8, 9.8, 1.6), 0.56], [Vector3(0.2, 7.0, 2.7), 0.62],
			[Vector3(1.2, 10.9, 0.2), 0.44], [Vector3(-0.5, 7.7, -3.0), 0.48], [Vector3(-1.6, 5.8, 3.0), 0.4],
			[Vector3(0.8, 6.1, -3.4), 0.34], [Vector3(-1.0, 11.6, -1.2), 0.3]]
	for k in rocks.size():
		_boulder(c + (rocks[k][0] as Vector3), float(rocks[k][1]), 31 + k)
	await _frames(20)


# ------------------------------------------------------------------------------------------------------------- water
## An open cone of falling (flow > 0) or rising (flow < 0) water in the ring's own curtain shader: radius `r_foot` at
## its foot, `r_head` at its head, `h` tall, its foot at `at`.
func _sheet(at: Vector3, r_foot: float, r_head: float, h: float, flow: float, alpha := 0.86) -> MeshInstance3D:
	var segs := 28
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	var circ := TAU * (r_foot + r_head) * 0.5
	for i in segs + 1:
		var a := TAU * float(i) / float(segs)
		var n := Vector3(cos(a), (r_foot - r_head) / maxf(h, 0.01), sin(a)).normalized()
		verts.append(Vector3(cos(a) * r_head, h, sin(a) * r_head))
		verts.append(Vector3(cos(a) * r_foot, 0.0, sin(a) * r_foot))
		uvs.append(Vector2(circ * float(i) / float(segs), 0.0))
		uvs.append(Vector2(circ * float(i) / float(segs), h))
		normals.append(n)
		normals.append(n)
	for i in segs:
		var b := i * 2
		idx.append_array([b, b + 2, b + 1, b + 1, b + 2, b + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var cd := RingArena.block("curtain")
	var mat := ShaderMaterial.new()
	mat.shader = load(CURTAIN)
	mat.set_shader_parameter(&"tint", RingArena._tint(cd.get("tint"), Color(0.62, 0.82, 0.86)).lerp(Color(0.3, 0.58, 0.86), 0.6))
	mat.set_shader_parameter(&"foam", RingArena._tint(cd.get("foam"), Color(0.92, 0.97, 1.0)))
	mat.set_shader_parameter(&"alpha", alpha)
	mat.set_shader_parameter(&"flow_mps", flow)
	mat.set_shader_parameter(&"height", h)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(mi, at)
	return mi


func _stage_water(c: Vector3) -> void:
	await _basin(c, 3.3)
	# the geyser: a rising core and a shorter rising sleeve round its foot, white foam at its foot and its head
	_sheet(c, 1.0, 0.7, 11.0, -8.0, 0.92)
	_sheet(c, 1.8, 1.1, 4.8, -5.0, 0.6)
	_sheet(c + Vector3.UP * 9.4, 0.75, 1.9, 1.8, -3.0, 0.5)
	BendZone.make(by, "spray", c + Vector3.UP * 0.3, {"radius_m": 3.4, "life_s": 900.0})
	BendZone.make(by, "spray", c + Vector3.UP * 10.6, {"radius_m": 2.0, "life_s": 900.0})
	# the moon's cold light on it, and a pale glow in the water round its foot
	var to_cam := Vector3(eye.x - c.x, 0.0, eye.z - c.z).normalized()
	_light(c + Vector3.UP * 6.0 + to_cam * 3.0, Color(0.55, 0.78, 1.0), 2.4, 12.0)
	_light(c + Vector3.UP * 0.8 + to_cam * 1.5, Color(0.5, 0.88, 1.0), 1.8, 7.0)
	await _frames(10)


## A stone basin ringing the geyser's foot (a torus rim of the deck's own pale stone, a disc of lit teal water inside it and a
## teal light under the foam): the water's focal frame, as the earth's slabs are, so the picture has a crisp base to stand on.
func _basin(c: Vector3, r: float) -> void:
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.5
	tm.outer_radius = r + 0.5
	tm.rings = 48
	tm.ring_segments = 14
	rim.mesh = tm
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.7, 0.68, 0.62)
	stone.roughness = 0.92
	rim.material_override = stone
	_add(rim, c + Vector3(0.0, 1.0, 0.0))
	rim.scale = Vector3(1.0, 0.6, 1.0)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r - 0.35
	cm.bottom_radius = r - 0.35
	cm.height = 0.06
	disc.mesh = cm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.1, 0.55, 0.62)
	wm.emission_enabled = true
	wm.emission = Color(0.12, 0.62, 0.7)
	wm.emission_energy_multiplier = 0.9
	wm.roughness = 0.2
	disc.material_override = wm
	_add(disc, c + Vector3(0.0, 0.96, 0.0))
	_light(c + Vector3(0.0, 2.2, 0.0), Color(0.2, 0.85, 0.85), 2.2, 9.0)
	await _frames(2)


# -------------------------------------------------------------------------------------------------------------- fire
## A blaze of the game's own flame tongues (ToonFx "flame", as BendZone's fire wall draws them) heaped round `c`: tallest
## at the middle, `r` m round, `h` tall, facing the camera.
func _blaze(c: Vector3, r: float, h: float, n: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ToonFx.quad_base()
	var xs: Array[Transform3D] = []
	for i in n:
		var d := sqrt(rng.randf()) * r
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * d, 0.0, sin(a) * d * 0.6)
		var k := 1.0 - pow(d / r, 1.4) * 0.8
		var fh := h * k * rng.randf_range(0.6, 1.1)
		var fw := rng.randf_range(0.55, 0.95) * (0.35 + fh * 0.16)
		xs.append(Transform3D(Basis(Vector3.RIGHT * fw, Vector3.UP * fh, Vector3.BACK), p))
	xs.sort_custom(func(x0: Transform3D, x1: Transform3D) -> bool: return x0.origin.z < x1.origin.z)
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var holder := Node3D.new()
	_add(holder, c)
	var to_cam := Vector3(eye.x - c.x, 0.0, eye.z - c.z).normalized()
	holder.global_transform.basis = Basis(Vector3.UP.cross(to_cam).normalized(), Vector3.UP, to_cam)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = ToonFx.mat("flame")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 2.0
	mmi.set_instance_shader_parameter(&"seed", rng.randf() * 10.0)
	mmi.set_instance_shader_parameter(&"grow", 1.0)
	holder.add_child(mmi)
	var gl := MeshInstance3D.new()
	gl.mesh = ToonFx.quad()
	gl.material_override = ToonFx.mat("flame_glow")
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gl.scale = Vector3(r * 2.0, h * 1.15, 1.0)
	gl.position = Vector3(0.0, h * 0.45, 0.4)
	gl.set_instance_shader_parameter(&"seed", rng.randf() * 10.0)
	holder.add_child(gl)
	var em := BendLooks.emitter(holder, "embers", Vector3(r * 0.7, 0.4, r * 0.4), int(80 * r), 3.4, h * 2.6, 0.08)
	if em != null:
		em.position = Vector3.UP * h * 0.4


## A Fire Wall: a row of the game's own flame tongues standing along `pts` (world, on the deck), `h` tall, facing the
## camera, its ends lower.
func _flame_row(pts: PackedVector3Array, h: float, per_m: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var holder := Node3D.new()
	_add(holder, Vector3.ZERO)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ToonFx.quad_base()
	var xs: Array[Transform3D] = []
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var n := maxi(int(total * per_m), 4)
	for k in n:
		var t := (float(k) + rng.randf()) / float(n) * total
		var p := pts[0]
		var acc := 0.0
		for i in pts.size() - 1:
			var seg := pts[i].distance_to(pts[i + 1])
			if acc + seg >= t:
				p = pts[i].lerp(pts[i + 1], (t - acc) / seg)
				break
			acc += seg
		var u := t / total
		var fh := h * (0.55 + 0.45 * sin(u * PI)) * rng.randf_range(0.7, 1.12)
		var fw := rng.randf_range(0.75, 1.1) * (0.35 + fh * 0.17)
		var to_cam := Vector3(eye.x - p.x, 0.0, eye.z - p.z).normalized()
		var x := Vector3.UP.cross(to_cam).normalized()
		xs.append(Transform3D(Basis(x * fw, Vector3.UP * fh, to_cam), p))
	xs.sort_custom(func(x0: Transform3D, x1: Transform3D) -> bool:
		return x0.origin.distance_to(eye) > x1.origin.distance_to(eye))
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = ToonFx.mat("flame")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 4.0
	mmi.set_instance_shader_parameter(&"seed", rng.randf() * 10.0)
	mmi.set_instance_shader_parameter(&"grow", 1.0)
	holder.add_child(mmi)


func _stage_fire(c: Vector3) -> void:
	_blaze(c, 2.3, 7.6, 80, 7)
	# the Fire Wall: an arc of standing flame round the blaze's far side, open toward the camera
	var to_cam := Vector3(eye.x - c.x, 0.0, eye.z - c.z).normalized()
	var side := Vector3.UP.cross(to_cam).normalized()
	var arc := PackedVector3Array()
	for i in 13:
		var a := lerpf(-1.25, 1.25, float(i) / 12.0)
		arc.append(c - to_cam * cos(a) * 3.6 + side * sin(a) * 5.2)
	_flame_row(arc, 3.0, 3.6, 12)
	_light(c + Vector3.UP * 4.5 - to_cam * 0.5, Color(1.0, 0.5, 0.16), 2.2, 13.0)
	await _frames(10)


# --------------------------------------------------------------------------------------------------------------- air
## A strip of torn cloth (`l` m long, `w` wide) rippling along `along`, its face turned to `face`, in colour `col`.
func _cloth(at: Vector3, along: Vector3, face: Vector3, l: float, w: float, col: Color, seed: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 10
	var u := along.normalized()
	var v := face.cross(u).normalized()
	var f := u.cross(v).normalized()
	var rows: Array = []
	for i in n + 1:
		var t := float(i) / float(n)
		var wave := sin(t * 7.0 + float(seed)) * 0.18 * l * 0.25
		var twist := t * 1.6 + float(seed) * 0.4
		var vv := v * cos(twist) + f * sin(twist)
		var p := u * (t - 0.5) * l + f * wave
		var hw := w * 0.5 * (1.0 - t * 0.45)
		rows.append([p - vv * hw, p + vv * hw])
	for i in n:
		var a0: Vector3 = rows[i][0]
		var a1: Vector3 = rows[i][1]
		var b0: Vector3 = rows[i + 1][0]
		var b1: Vector3 = rows[i + 1][1]
		var nn := (b0 - a0).cross(a1 - a0).normalized()
		for p: Vector3 in [a0, b0, b1, a0, b1, a1]:
			st.set_normal(nn)
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	_add(mi, at)


func _stage_air(c: Vector3) -> void:
	# the funnel: the game's own wind bands stacked, narrow at the deck and flaring wide overhead, leaning a little
	var rings := 19
	var h := 11.0
	# (every other band laden with dust: the wind shader's own dust-strip colours, on a copy of its funnel material)
	var dusty := (ToonFx.mat("wind_funnel") as ShaderMaterial).duplicate() as ShaderMaterial
	dusty.set_shader_parameter(&"c_main", Color(0.86, 0.76, 0.6, 0.9))
	dusty.set_shader_parameter(&"c_edge", Color(0.62, 0.5, 0.38, 0.75))
	dusty.set_shader_parameter(&"c_ink", Color(0.25, 0.18, 0.1))
	dusty.set_shader_parameter(&"ink", 0.35)
	var mats := [dusty, ToonFx.mat("wind_band_fast"), dusty, ToonFx.mat("wind_funnel")]
	for i in rings:
		var f := float(i) / float(rings - 1)
		var r := lerpf(0.7, 4.6, pow(f, 1.3))
		var b := MeshInstance3D.new()
		b.mesh = ToonFx.band_mesh(1.0, 1.1, 0.62)
		b.material_override = mats[i % mats.size()]
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(b, c + Vector3(sin(i * 1.7) * 0.22 * f + f * f * 0.9, 0.1 + f * h, cos(i * 1.3) * 0.22 * f))
		b.scale = Vector3(r, 1.25 + f * 0.6, r)
		b.rotation = Vector3(0.1 * sin(i * 2.1), i * 0.9, 0.1 * cos(i * 1.4))
		b.set_instance_shader_parameter(&"seed", i * 0.29)
	# torn cloth and stones whirled up round it (cloth in the arena's own bunting colours)
	var cols := [Color(0.72, 0.18, 0.14), Color(0.93, 0.87, 0.74), Color(0.18, 0.45, 0.45), Color(0.82, 0.58, 0.2)]
	for k in 24:
		var a := float(k) * 2.1
		var y := 0.9 + float(k) * 0.42
		var f := y / h
		var r := lerpf(0.7, 4.6, pow(f, 1.3)) * 1.3 + 0.5
		var p := c + Vector3(cos(a) * r + f * f * 0.9, y, sin(a) * r)
		var tangent := Vector3(-sin(a), 0.35, cos(a))
		var radial := Vector3(cos(a), 0.0, sin(a))
		_cloth(p, tangent, radial, 2.4 + 0.7 * float(k % 3), 0.62, cols[k % cols.size()], k)
	for k in 14:
		var a := float(k) * 2.6 + 1.0
		var y := 0.5 + float(k) * 0.62
		var f := y / h
		var r := lerpf(0.7, 4.6, pow(f, 1.3)) * 1.2 + 0.3
		_boulder(c + Vector3(cos(a) * r + f * f * 0.9, y, sin(a) * r), 0.12 + 0.05 * float(k % 4), 50 + k)
	await _frames(10)


# ------------------------------------------------------------------------------------------------------------- paint
## The render graded (GRADE_SHADER with the scene's numbers and SHADE) before it is painted.
func _grade(img: Image, g: Dictionary) -> Image:
	var size := img.get_size()
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(img)
	rect.size = Vector2(size)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array(SHADE.map(func(k: Array) -> float: return float(k[0])))
	grad.colors = PackedColorArray(SHADE.map(func(k: Array) -> Color: return Color(float(k[1]), float(k[1]), float(k[1]))))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 512
	gt.height = 4
	var sh := Shader.new()
	sh.code = GRADE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("shade", gt)
	mat.set_shader_parameter("contrast", float(g.get("contrast", 1.0)))
	mat.set_shader_parameter("saturation", float(g.get("saturation", 1.0)))
	var gain: Color = g.get("gain", Color.WHITE)
	mat.set_shader_parameter("gain", Vector3(gain.r, gain.g, gain.b))
	mat.set_shader_parameter("top", float(g.get("top", 0.0)))
	mat.set_shader_parameter("bottom", float(g.get("bottom", 0.0)))
	rect.material = mat
	vp.add_child(rect)
	root.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var o := vp.get_texture().get_image()
	vp.queue_free()
	o.convert(Image.FORMAT_RGB8)
	return o


## The two passes (paint_views.gd's recipe at this size): broad masses, then the strokes, the canvas and the varnish.
func _paint(img: Image) -> Image:
	var first := await _pass(ImageTexture.create_from_image(img), img.get_size(), BRUSH.x, false)
	return await _pass(ImageTexture.create_from_image(first), img.get_size(), BRUSH.y, true)


## The painted image with the graded render's edge detail brought back (FINISH_SHADER, DETAIL): the focal forms read crisp, the
## sides stay calm, the highlights held down.
func _finish(painted: Image, graded: Image) -> Image:
	var size := painted.get_size()
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(painted)
	rect.size = Vector2(size)
	var sh := Shader.new()
	sh.code = FINISH_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("detail", ImageTexture.create_from_image(graded))
	mat.set_shader_parameter("centre", float(DETAIL.centre))
	mat.set_shader_parameter("side", float(DETAIL.side))
	mat.set_shader_parameter("cap", float(DETAIL.cap))
	mat.set_shader_parameter("focus_x", float(DETAIL.focus_x))
	mat.set_shader_parameter("reach", float(DETAIL.reach))
	rect.material = mat
	vp.add_child(rect)
	root.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var o := vp.get_texture().get_image()
	vp.queue_free()
	o.convert(Image.FORMAT_RGB8)
	return o


func _pass(tex: Texture2D, size: Vector2i, brush: int, finish: bool) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := TextureRect.new()
	rect.texture = tex
	rect.size = Vector2(size)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ui/oil_paint.gdshader")
	mat.set_shader_parameter("noise_a", noises[0])
	mat.set_shader_parameter("noise_b", noises[1])
	mat.set_shader_parameter("noise_c", noises[2])
	mat.set_shader_parameter("brush", brush)
	mat.set_shader_parameter("finish", finish)
	for k: String in VARNISH:
		var v: Variant = VARNISH[k]
		mat.set_shader_parameter(k, Vector3(v.r, v.g, v.b) if v is Color else v)
	rect.material = mat
	vp.add_child(rect)
	root.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var out_img := vp.get_texture().get_image()
	vp.queue_free()
	out_img.convert(Image.FORMAT_RGB8)
	return out_img



# ------------------------------------------------------------------------------------------------------- contact sheet
const SHEET_OUT := "res://artifacts/ui_audit/advancement/art_sheet.png"
const SHEET_W := 2400
const INK := Color(0.93, 0.89, 0.8)
var page: Control


## An SVG file drawn `px` high (its own width/height scaled), from the file (no import).
func _svg(path: String, px: float) -> ImageTexture:
	var text := FileAccess.get_file_as_string(path)
	var re := RegEx.new()
	re.compile('<svg[^>]*?height="([0-9.]+)"')
	var m := re.search(text)
	var nat := float(m.get_string(1)) if m != null else 128.0
	var img := Image.new()
	img.load_svg_from_string(text, px / nat)
	return ImageTexture.create_from_image(img)


func _put_tex(tex: Texture2D, at: Vector2, tint := Color.WHITE, flip := Vector2(1, 1)) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.position = at
	r.size = tex.get_size()
	r.modulate = tint
	r.flip_h = flip.x < 0.0
	r.flip_v = flip.y < 0.0
	page.add_child(r)
	return r


func _text(t: String, at: Vector2, px := 15, col := INK, w := 0.0) -> Label:
	var l := Label.new()
	l.text = t
	l.position = at
	l.add_theme_font_size_override(&"font_size", px)
	l.add_theme_color_override(&"font_color", col)
	if w > 0.0:
		l.size = Vector2(w, 0.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(l)
	return l


func _box(at: Vector2, size: Vector2, col: Color, border := Color(0, 0, 0, 0), bw := 0) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = border
	sb.set_border_width_all(bw)
	p.add_theme_stylebox_override(&"panel", sb)
	p.position = at
	p.size = size
	page.add_child(p)
	return p


## A node's plate: the element colour fading to dark (the window's AdvancementNode look), `px` square.
func _plate(at: Vector2, px: float, col: Color, edge: Color) -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([col, col.darkened(0.45), Color(0.04, 0.04, 0.05)])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.4, 0.35)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = int(px)
	gt.height = int(px)
	_box(at - Vector2(2, 2), Vector2(px + 4, px + 4), Color(0, 0, 0, 0), edge, 2)
	_put_tex(gt, at)


func _section(t: String, y: float) -> float:
	_text(t, Vector2(30, y), 22, Color(0.95, 0.82, 0.5))
	_box(Vector2(30, y + 32), Vector2(SHEET_W - 60, 2), Color(0.66, 0.52, 0.29, 0.7))
	return y + 46


func _contact_sheet() -> void:
	var outp := ProjectSettings.globalize_path(SHEET_OUT)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			outp = a.get_slice("=", 1)
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/advancement/art.json"))
	var vp := SubViewport.new()
	vp.size = Vector2i(SHEET_W, 3000)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	page = Control.new()
	page.size = Vector2(vp.size)
	vp.add_child(page)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.1)
	bg.size = Vector2(vp.size)
	page.add_child(bg)
	var els := ["earth", "water", "fire", "air"]
	var col := {}
	for el: String in els:
		col[el] = BendStrip.element_colour(el)
	_text("Character Advancement: the window's art (all our own: tools/menu/paint_advancement.gd, tools/ui/advancement_art.py,"
			+ " tools/ui/move_icons.py; assets/ui/advancement/SOURCE.md)", Vector2(30, 18), 24)
	# the backdrops, a quarter size, the centre gap the trees leave marked
	var y := _section("Backdrops (1920 x 1080 JPG, shown at 0.3): the trees sit over the darker thirds, the focal in the centre gap", 64.0)
	var what := {"earth": "earth - golden hour: raised slabs, the column, boulders lifted",
			"water": "water - night: a geyser out of the tank under the moon",
			"fire": "fire - dusk: the blaze and its Fire Wall, embers rising",
			"air": "air - noon: a whirling funnel of dust, stones and cloth"}
	for i in els.size():
		var el: String = els[i]
		var img := Image.load_from_file(ProjectSettings.globalize_path(String(art.backdrops[el])))
		img.resize(576, 324, Image.INTERPOLATE_LANCZOS)
		var x := 30.0 + i * 588.0
		_put_tex(ImageTexture.create_from_image(img), Vector2(x, y))
		for gx: float in [0.355, 0.566]:
			_box(Vector2(x + 576.0 * gx, y), Vector2(1, 324), Color(1, 0.85, 0.45, 0.35))
		_text(what[el], Vector2(x, y + 330), 15, INK, 576.0)
	y += 380.0
	# the frame pieces at the sizes the window draws them
	y = _section("Frame pieces, at the window's size (authored px at 1600 x 900)", y)
	var fr: Dictionary = art.frame
	_box(Vector2(30, y), Vector2(1100, 640), Color(0.07, 0.08, 0.11))
	_box(Vector2(60, y + 30), Vector2(560, 260), Color(0.1, 0.12, 0.16, 1.0))
	var corner := _svg(String(fr.frame_corner), 64)
	_put_tex(corner, Vector2(60, y + 30))
	_put_tex(corner, Vector2(556, y + 30), Color.WHITE, Vector2(-1, 1))
	_put_tex(corner, Vector2(60, y + 226), Color.WHITE, Vector2(1, -1))
	_put_tex(corner, Vector2(556, y + 226), Color.WHITE, Vector2(-1, -1))
	_text("frame_corner.svg 64 px, mirrored for each corner", Vector2(140, y + 140), 15)
	_put_tex(_svg(String(fr.rail_frame), 600), Vector2(660, y + 20))
	_text("rail_frame.svg\n80 x 600", Vector2(750, y + 20), 15)
	_put_tex(_svg(String(fr.rail_cap), 52), Vector2(760, y + 90))
	_text("rail_cap.svg 40 x 52", Vector2(810, y + 104), 15)
	_put_tex(_svg(String(fr.toast_frame), 64), Vector2(60, y + 320))
	_put_tex(_svg(String(art.node_icons["earth.boulder.avalanche"]) if art.node_icons.has("earth.boulder.avalanche")
			else String(art.node_icons.values()[0]), 30), Vector2(83, y + 337), Color(0.97, 0.92, 0.78))
	_text("New twist worn", Vector2(126, y + 334), 14, Color(1.0, 0.82, 0.25))
	_text("Avalanche", Vector2(126, y + 352), 15, Color(1, 1, 1))
	_text("toast_frame.svg 320 x 64", Vector2(400, y + 342), 15)
	_put_tex(_svg(String(fr.rank_plate), 20), Vector2(60, y + 410))
	_text("1/1", Vector2(70, y + 410), 13, Color(1.0, 0.86, 0.3), 24)
	_text("rank_plate.svg 44 x 20", Vector2(116, y + 410), 15)
	_put_tex(_svg(String(fr.choice_arrow), 24), Vector2(60, y + 456))
	_put_tex(_svg(String(fr.choice_arrow), 24), Vector2(84, y + 456), Color.WHITE, Vector2(-1, 1))
	_text("choice_arrow.svg 16 x 24 (both sides)", Vector2(116, y + 458), 15)
	_put_tex(_svg(String(fr.padlock), 24), Vector2(84, y + 504), Color(1.0, 0.55, 0.2))
	_text("1", Vector2(64, y + 503), 20, Color(1.0, 0.55, 0.2))
	_box(Vector2(112, y + 516), Vector2(160, 2), Color(1.0, 0.55, 0.2, 0.8))
	_text("padlock.svg 24 px, a gate line", Vector2(290, y + 506), 15)
	# kind marks and set marks
	var x0 := 1180.0
	_text("Kind marks (kind_<kind>.svg), tinted worn-gold, at 24 and 46 px", Vector2(x0, y), 17, Color(0.95, 0.82, 0.5))
	var kw := {"variation": "Twist", "mastery": "Technique", "new_skill": "New skill", "synergy": "Synergy",
			"skill_set": "Skill set", "passive": "Passive", "world_only": "World art"}
	var k := 0
	for kind: String in art.kinds:
		var kx := x0 + k * 156.0
		_plate(Vector2(kx, y + 34), 56.0, Color(0.25, 0.27, 0.32), Color(0.66, 0.52, 0.29))
		_put_tex(_svg(String(art.kinds[kind]), 46), Vector2(kx + 5, y + 39), Color(1.0, 0.82, 0.0))
		_put_tex(_svg(String(art.kinds[kind]), 24), Vector2(kx + 70, y + 50), Color(1.0, 0.82, 0.0))
		_text(kw.get(kind, kind), Vector2(kx, y + 96), 15, INK, 100.0)
		k += 1
	var sy := y + 140.0
	_text("Skill-set marks (set_<set>.svg), in their tints, at 24 and 46 px", Vector2(x0, sy), 17, Color(0.95, 0.82, 0.5))
	k = 0
	for st: String in art.sets:
		var sd: Dictionary = art.sets[st]
		var kx := x0 + k * 270.0
		_plate(Vector2(kx, sy + 34), 56.0, col[String(sd.element)], Color(0.66, 0.52, 0.29))
		_put_tex(_svg(String(sd.mark), 46), Vector2(kx + 5, sy + 39), Color(String(sd.tint)))
		_put_tex(_svg(String(sd.mark), 24), Vector2(kx + 70, sy + 50), Color(String(sd.tint)))
		_put_tex(_svg(String(sd.node_icon), 46), Vector2(kx + 110, sy + 39), Color(0.97, 0.92, 0.78))
		_text(st.capitalize() + "  (mark, node)", Vector2(kx, sy + 96), 15, INK, 200.0)
		k += 1
	# style glyphs and emblems
	var gy := sy + 150.0
	_text("Style glyphs (style_<style>.svg) at 46 and 24 px; class emblems (emblem_<element>_<style>.svg) at 76 (the portrait) and 46",
			Vector2(x0, gy), 17, Color(0.95, 0.82, 0.5))
	gy += 34.0
	for i in els.size():
		var el: String = els[i]
		var ry := gy + i * 96.0
		var j := 0
		for sid: String in art.emblems[el]:
			var gx := x0 + j * 230.0
			_put_tex(_svg(String(art.emblems[el][sid]), 76), Vector2(gx, ry), col[el])
			_put_tex(_svg(String(art.styles[sid].glyph), 46), Vector2(gx + 82, ry + 2), INK)
			_put_tex(_svg(String(art.styles[sid].glyph), 24), Vector2(gx + 134, ry + 14), INK)
			_text(String(art.styles[sid].label), Vector2(gx + 80, ry + 52), 14, INK, 140.0)
			j += 1
	y = maxf(y + 660.0, gy + 4 * 96.0 + 20.0)
	# every node's icon
	y = _section("Every node's icon (art.json node_icons, 133) at 46 px on its element's plate, and the passive line's root; gold edge = drawn for this window (37 new in assets/ui/icons)", y)
	var drawn: Array = art.drawn_for_window
	for el: String in els:
		var ids: Array = []
		for nid: String in art.node_icons:
			if nid.begins_with(el + "."):
				ids.append(nid)
		_text(el.capitalize(), Vector2(30, y + 14), 17, col[el])
		var x := 110.0
		var row_y := y
		var all := [String(art.passive_roots[el])]
		for nid: String in ids:
			all.append(String(art.node_icons[nid]))
		for pth: String in all:
			if x > SHEET_W - 80.0:
				x = 110.0
				row_y += 62.0
			var new := pth in drawn
			_plate(Vector2(x, row_y), 46.0, col[el], Color(1.0, 0.82, 0.0) if new else Color(0.2, 0.2, 0.22))
			_put_tex(_svg(pth, 46), Vector2(x, row_y), Color(0.97, 0.92, 0.78))
			x += 58.0
		y = row_y + 70.0
	var h := int(y + 20.0)
	vp.size = Vector2i(SHEET_W, h)
	page.size = Vector2(vp.size)
	bg.size = Vector2(vp.size)
	for i in 4:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute(outp.get_base_dir())
	img.save_png(outp)
	print("PAINT ADVANCEMENT SHEET ", outp, " ", img.get_size())
	quit(0)
