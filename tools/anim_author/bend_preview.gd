extends SceneTree
## Contact sheets of our own ring-sport clips (animations_extra/Frontier_Bend.res: tools/anim_author/install_bend.gd) for the
## owner to judge by eye before any more are authored (he rejected and deleted a stiff solver-authored gait library on
## 2026-10-01, so the first set waits on his look): Actor_B's textured body (assets/character/actor_b_body.glb on its own
## skeleton, skinned by CharacterBodyMesh as the game does, the helper bones driven: the bones the clips key are set from
## their tracks, nothing else is played) on a plain floor, each clip sampled
## at its moments (the start, the wind-up's hold_s, the strike's way in, strike_s, the follow-through, back_s, up_s, the end) and
## seen from the front three quarters and from the right side, a row each, labelled; one sheet a clip (clips_<name>.png) and a
## lineup of every clip at its hold and its strike (clips_lineup.png), and one an element (clips_lineup_<earth | water | fire |
## air | knock>.png: its stance, then each of its casts at its hold and its strike; the throws with earth's). A stance (a loop:
## meta loop) is sampled at eight even moments through its loop instead. Rendered through tools/environment/offscreen_view.gd
## (a covered macOS window is not drawn; the SubViewport is, when forced), so it needs a window (not --headless).
##   Godot --path . -s tools/anim_author/bend_preview.gd -- out=<dir> [clips=own-bend-earth-stomp,...] [lib=res://...]
##       [prefix=clips2_]   (the sheets' file names: <prefix><name>.png, <prefix>lineup.png, <prefix>lineup_<element>.png)

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const CELL := Vector2i(300, 400)
const GLB := "res://assets/character/actor_b_body.glb"
const CENTER := Vector3(0.0, 0.95, 0.15)
## (the character faces +Z, +X its left)
const VIEWS := {"front34": Vector3(-2.3, 0.35, 3.0), "side": Vector3(-3.7, 0.15, 0.15)}

var out := ""
var lib_path := "res://animations_extra/Frontier_Bend.res"
var only: PackedStringArray = []
var prefix := "clips_"
var view
var label: Label
var sk: Skeleton3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("clips="):
			only = a.get_slice("=", 1).split(",", false)
		elif a.begins_with("lib="):
			lib_path = a.get_slice("=", 1)
		elif a.begins_with("prefix="):
			prefix = a.get_slice("=", 1)
	_run.call_deferred()


func _run() -> void:
	if out == "":
		push_error("bend_preview: out=<dir>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var lib := load(lib_path) as AnimationLibrary
	_stage()
	var body := (load(GLB) as PackedScene).instantiate() as Node3D
	root.add_child(body)
	sk = body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for ap: AnimationPlayer in body.find_children("*", "AnimationPlayer", true, false):
		ap.stop()
		ap.active = false
	# the body as the game skins it: CharacterBodyMesh drives the twist, sleeve and coat helper bones from the pose (the
	# glb's own meshes would leave the sleeves at the rest); with no AnimationPlayer it binds with the glb's own binds
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		mi.visible = false
	CharacterBodyMesh.attach(sk, null, GLB)
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, CELL)
	view.camera.fov = 36.0
	root.disable_3d = true
	label = Label.new()
	label.position = Vector2(8, 6)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
	view.add_child(label)
	await process_frame
	await process_frame
	var lineup: Array[Image] = []
	var by_el := {}
	var names := lib.get_animation_list()
	# (each element's stance first in its lineup)
	names.sort_custom(func(x: StringName, y: StringName) -> bool:
		var sx := String(x).contains("-stance-")
		var sy := String(y).contains("-stance-")
		return sx and not sy if sx != sy else String(x) < String(y))
	for nm: StringName in names:
		if not only.is_empty() and not String(nm) in only:
			continue
		var a := lib.get_animation(nm)
		var times := _moments(a)
		var cells: Array[Image] = []
		for vn: String in VIEWS:
			for tm: Array in times:
				cells.append(await _snap(a, float(tm[0]), vn, "%s\n%s %.2f s (f%d)" % [String(nm).trim_prefix("own-bend-"), tm[1],
						float(tm[0]), int(round(float(tm[0]) * 30.0))]))
		_sheet(cells, times.size(), out.path_join("%s%s.png" % [prefix, String(nm).trim_prefix("own-bend-")]))
		var el := _element(String(nm))
		if not by_el.has(el):
			by_el[el] = [] as Array[Image]
		if a.has_meta(&"loop"):
			var im := await _snap(a, 0.0, "front34", "%s\nloop" % String(nm).trim_prefix("own-bend-"))
			lineup.append(im)
			(by_el[el] as Array[Image]).append(im)
		for key in ["hold_s", "strike_s"]:
			if a.has_meta(key):
				var im2 := await _snap(a, float(a.get_meta(key)), "front34", "%s\n%s" % [String(nm).trim_prefix("own-bend-"), key])
				lineup.append(im2)
				(by_el[el] as Array[Image]).append(im2)
	_sheet(lineup, 8, out.path_join("%slineup.png" % prefix))
	for el: String in by_el:
		_sheet(by_el[el], 7, out.path_join("%slineup_%s.png" % [prefix, el]))
	print("BEND PREVIEW -> ", out)
	quit()


## The element a clip's lineup is: own-bend-<earth | water | fire | air | knock>-..., a stance's own, the throws earth's.
func _element(nm: String) -> String:
	var rest := nm.trim_prefix("own-bend-").trim_prefix("stance-")
	var head := rest.get_slice("-", 0)
	return "earth" if head == "throw" else head


## The clip's moments: [time, what], in order, without near repeats (a stance: eight even moments through its loop).
func _moments(a: Animation) -> Array:
	if a.has_meta(&"loop"):
		var loop := []
		for i in 8:
			loop.append([a.length * i / 8.0, "loop %d/8" % i])
		return loop
	var m := {"start": 0.0, "end": a.length}
	for k in ["hold_s", "strike_s", "back_s", "up_s"]:
		if a.has_meta(k):
			m[k.trim_suffix("_s")] = float(a.get_meta(k))
	if a.has_meta("strike_s") and a.has_meta("hold_s") and float(a.get_meta("strike_s")) > float(a.get_meta("hold_s")):
		m["way in"] = (float(a.get_meta("hold_s")) + float(a.get_meta("strike_s"))) * 0.5
	if a.has_meta("strike_s"):
		var s := float(a.get_meta("strike_s"))
		var nxt := float(a.get_meta("back_s", a.length))
		if float(a.get_meta("hold_s", 0.0)) > s:
			m["hit+"] = s + (float(a.get_meta("hold_s")) - s) * 0.5
		m["follow"] = s + (nxt - s) * 0.4
	if a.has_meta("back_s"):
		m["recover"] = (float(a.get_meta("back_s")) + a.length) * 0.5
	# a long wind-up (the boulder's kick and stomp, the lightning's circles) shown on its way to the hold
	var h := float(a.get_meta("hold_s", 0.0))
	if h >= 0.4 and float(a.get_meta("strike_s", 0.0)) > h:
		for k: float in [0.47, 0.63, 0.79]:
			m["wind %d%%" % int(k * 100.0)] = h * k
	var arr := []
	for k: String in m:
		arr.append([float(m[k]), k])
	arr.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var res := []
	for e: Array in arr:
		if res.is_empty() or float(e[0]) - float(res[-1][0]) > 0.02:
			res.append(e)
	return res


func _apply(a: Animation, t: float) -> void:
	for i in a.get_track_count():
		var b := sk.find_bone(String(a.track_get_path(i).get_concatenated_subnames()))
		if b < 0:
			continue
		match a.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				sk.set_bone_pose_rotation(b, a.rotation_track_interpolate(i, t))
			Animation.TYPE_POSITION_3D:
				sk.set_bone_pose_position(b, a.position_track_interpolate(i, t))
	sk.force_update_all_bone_transforms()


func _snap(a: Animation, t: float, vn: String, text: String) -> Image:
	_apply(a, t)
	label.text = text
	view.camera.global_position = CENTER + VIEWS[vn]
	view.camera.look_at(CENTER)
	for f in 3:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	return (view.get_texture().get_image() as Image)


func _sheet(cells: Array[Image], cols: int, path: String) -> void:
	if cells.is_empty():
		return
	cols = maxi(1, mini(cols, cells.size()))
	var rows := int(ceil(cells.size() / float(cols)))
	var sheet := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.3, 0.3, 0.3))
	for i in cells.size():
		var im := cells[i]
		im.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(im, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
		# a thin line between the cells
		sheet.fill_rect(Rect2i((i % cols) * CELL.x, (i / cols) * CELL.y, 1, CELL.y), Color(0.2, 0.2, 0.22))
	sheet.save_png(path)
	print("BEND SHEET -> ", path)


## A plain lit floor with a sky colour (no level: the clips alone), a stone grid on the floor to read the feet's slide.
func _stage() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.72, 0.76, 0.8)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.78, 0.8)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	root.add_child(sun)
	for ix in range(-4, 4):
		for iz in range(-4, 4):
			var m := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.49, 0.04, 0.49)
			m.mesh = b
			var mat := StandardMaterial3D.new()
			var k := 0.5 + 0.06 * float((ix + iz) & 1)
			mat.albedo_color = Color(k, k * 0.97, k * 0.9)
			mat.roughness = 0.95
			m.material_override = mat
			m.position = Vector3(ix * 0.5 + 0.25, -0.02, iz * 0.5 + 0.25)
			root.add_child(m)
