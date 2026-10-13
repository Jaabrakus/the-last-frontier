extends "res://tools/anim_author/bend_preview.gd"
## Stills of a fighting style's own clips (animations_extra/Frontier_Style_<Style>.res: tools/anim_author/install_style.gd)
## for the owner to judge by eye (no films unless asked): the stage, the textured body and the offscreen render are
## bend_preview.gd's (Actor_B on its own skeleton, skinned by CharacterBodyMesh as the game does, the bones the clips key set
## from their tracks, nothing else played). One sheet a clip (<prefix><name>.png): its anticipation, its strike and its
## follow-through (the clip's metas antic_s, strike_s, follow_s; a clip with several hits names its own stills in the meta
## `stills`, "label:frame;label:frame"; a stance shows four even moments of its loop) as rows seen from the opponent's
## place, the front three quarters and the side; and one lineup of every clip at its strike from the front three quarters
## (<prefix>lineup.png) and from the opponent's place (<prefix>lineup_foe.png); and review sheets of REVIEW_ROWS clips each,
## a row a clip with its stills from the front three quarters (<prefix>review_<n>.png), the owner's quick look.
##   Godot --path . -s tools/anim_author/style_preview.gd -- out=<dir> [lib=res://animations_extra/Frontier_Style_Boxing.res]
##       [clips=own-style-boxing-jab,...] [prefix=boxing_]
##       [hands=1]   instead, close-ups of both hands at the guard (f0) and at the strike, a row a clip
##                   (<prefix>hands_<n>.png): whether the fists are closed
## Needs a window (not --headless), as bend_preview.gd does.

## The cameras (the character faces +Z, +X his left): the opponent's place a little to the left of straight ahead (an
## orthodox boxer turned side-on shows his chest there), the bend sheets' front three quarters and their side.
const STYLE_VIEWS := {"foe": Vector3(0.9, 0.3, 3.6), "front34": Vector3(-2.3, 0.35, 3.0), "side": Vector3(-3.7, 0.15, 0.15)}
const STYLE_VIEW_WORDS := {"foe": "opponent's view", "front34": "front 3/4", "side": "side"}
## Clips a review sheet (<prefix>review_<n>.png).
const REVIEW_ROWS := 5


func _run() -> void:
	if out == "":
		push_error("style_preview: out=<dir>")
		quit(1)
		return
	if lib_path == "res://animations_extra/Frontier_Bend.res":
		lib_path = "res://animations_extra/Frontier_Style_Boxing.res"
	if prefix == "clips_":
		prefix = "style_"
	DirAccess.make_dir_recursive_absolute(out)
	var lib := load(lib_path) as AnimationLibrary
	_stage()
	var body := (load(GLB) as PackedScene).instantiate() as Node3D
	root.add_child(body)
	sk = body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for ap: AnimationPlayer in body.find_children("*", "AnimationPlayer", true, false):
		ap.stop()
		ap.active = false
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
	var lineup_foe: Array[Image] = []
	# (the review sheets: a row a clip, its stills from the front three quarters, REVIEW_ROWS clips a sheet)
	var review_rows: Array = []
	var names := lib.get_animation_list()
	# (the stance first, then the clips in the order the generator typed them: its meta `order`)
	names.sort_custom(func(x: StringName, y: StringName) -> bool:
		return _order(lib.get_animation(x), String(x)) < _order(lib.get_animation(y), String(y)))
	if "hands=1" in OS.get_cmdline_user_args():
		await _hands(lib, names)
		print("STYLE PREVIEW -> ", out)
		quit()
		return
	for nm: StringName in names:
		if not only.is_empty() and not String(nm) in only:
			continue
		var a := lib.get_animation(nm)
		var short := _short(String(nm))
		var stills := _stills(a)
		var cells: Array[Image] = []
		var row: Array[Image] = []
		for vn: String in STYLE_VIEWS:
			for st: Array in stills:
				var im := await _shot(a, float(st[1]), vn, "%s: %s\n%s, f%d (%.2f s)" % [short, st[0], STYLE_VIEW_WORDS[vn],
						int(round(float(st[1]) * 30.0)), float(st[1])])
				cells.append(im)
				if vn == "front34":
					row.append(im)
		_sheet(cells, stills.size(), out.path_join("%s%s.png" % [prefix, short]))
		review_rows.append(row)
		var at := float(a.get_meta(&"strike_s", 0.0)) if not a.has_meta(&"loop") else 0.0
		lineup.append(await _shot(a, at, "front34", "%s\n%s" % [short, "loop" if a.has_meta(&"loop") else "strike"]))
		lineup_foe.append(await _shot(a, at, "foe", "%s\n%s" % [short, "loop" if a.has_meta(&"loop") else "strike"]))
	_sheet(lineup, 7, out.path_join("%slineup.png" % prefix))
	_sheet(lineup_foe, 7, out.path_join("%slineup_foe.png" % prefix))
	var page := 0
	for i in range(0, review_rows.size(), REVIEW_ROWS):
		page += 1
		_review(review_rows.slice(i, i + REVIEW_ROWS), out.path_join("%sreview_%d.png" % [prefix, page]))
	print("STYLE PREVIEW -> ", out)
	quit()


## A review sheet: a row a clip (its stills, front three quarters), the rows' cells left-aligned on a grey ground.
func _review(rows: Array, path: String) -> void:
	var cols := 0
	for r: Array in rows:
		cols = maxi(cols, r.size())
	if cols == 0:
		return
	var sheet := Image.create(CELL.x * cols, CELL.y * rows.size(), false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.3, 0.3, 0.3))
	for ri in rows.size():
		var r: Array = rows[ri]
		for ci in r.size():
			var im: Image = r[ci]
			im.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(im, Rect2i(Vector2i.ZERO, CELL), Vector2i(ci * CELL.x, ri * CELL.y))
			sheet.fill_rect(Rect2i(ci * CELL.x, ri * CELL.y, 1, CELL.y), Color(0.2, 0.2, 0.22))
		sheet.fill_rect(Rect2i(0, ri * CELL.y, CELL.x * cols, 2), Color(0.2, 0.2, 0.22))
	sheet.save_png(path)
	print("STYLE REVIEW -> ", path)


## own-style-boxing-jab -> jab
func _short(nm: String) -> String:
	var rest := nm.trim_prefix("own-style-")
	return rest.substr(rest.find("-") + 1) if rest.contains("-") else rest


func _order(a: Animation, nm: String) -> String:
	return "%04d%s" % [int(a.get_meta(&"order", 999)), nm]


## The clip's stills: [label, time]: its own `stills` meta ("label:frame;..."), else a stance's four even moments, else its
## anticipation (antic_s, or hold_s), its strike (strike_s) and its follow-through (follow_s, or 40% of the way to back_s).
func _stills(a: Animation) -> Array:
	if a.has_meta(&"stills"):
		var res := []
		for part in String(a.get_meta(&"stills")).split(";", false):
			res.append([part.get_slice(":", 0), int(part.get_slice(":", 1)) / 30.0])
		return res
	if a.has_meta(&"loop"):
		return [["loop 0/4", 0.0], ["loop 1/4", a.length * 0.25], ["loop 2/4", a.length * 0.5], ["loop 3/4", a.length * 0.75]]
	var s := float(a.get_meta(&"strike_s", a.length * 0.5))
	var antic := float(a.get_meta(&"antic_s", a.get_meta(&"hold_s", s * 0.5)))
	var follow := float(a.get_meta(&"follow_s", s + (float(a.get_meta(&"back_s", a.length)) - s) * 0.4))
	return [["anticipation", antic], ["strike", s], ["follow-through", follow]]


## One cell: the clip at t seen from one of STYLE_VIEWS about the bend sheets' CENTER, labelled.
func _shot(a: Animation, t: float, vn: String, text: String) -> Image:
	_apply(a, t)
	label.text = text
	_ledge.visible = false
	_wall.visible = false
	view.camera.global_position = CENTER + (STYLE_VIEWS[vn] as Vector3)
	view.camera.look_at(CENTER)
	for f in 3:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	return (view.get_texture().get_image() as Image)


## Close-ups of both hands at the guard (f0) and at the strike, a row a clip, 4 clips a sheet (<prefix>hands_<n>.png).
func _hands(lib: AnimationLibrary, names: Array) -> void:
	var rows: Array = []
	for nm: StringName in names:
		if not only.is_empty() and not String(nm) in only:
			continue
		var a := lib.get_animation(nm)
		var short := _short(String(nm))
		var at := 0.0 if a.has_meta(&"loop") else float(a.get_meta(&"strike_s", 0.0))
		var row: Array[Image] = []
		for tm: Array in [[0.0, "guard"], [at, "strike"]]:
			for side: String in ["r", "l"]:
				row.append(await _hand_shot(a, float(tm[0]), side, "%s: %s\n%s hand, f%d" % [short, tm[1],
						"right" if side == "r" else "left", int(round(float(tm[0]) * 30.0))]))
		rows.append(row)
	var page := 0
	for i in range(0, rows.size(), 4):
		page += 1
		_review(rows.slice(i, i + 4), out.path_join("%shands_%d.png" % [prefix, page]))


## One close-up: the camera 0.5 m off the palm, ahead of it and to its own side, looking at it.
func _hand_shot(a: Animation, t: float, side: String, text: String) -> Image:
	_apply(a, t)
	label.text = text
	_ledge.visible = false
	_wall.visible = false
	var p := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(side + "_palm")).origin
	view.camera.global_position = p + Vector3(-0.3 if side == "r" else 0.3, 0.12, 0.42)
	view.camera.look_at(p)
	for f in 3:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	return (view.get_texture().get_image() as Image)
