extends SceneTree
## Stills of the trap line for its look (TrapStation, TrapCatch, BuildGeometry._trap): each trap set and sprung with
## a catch in it, on the level's ground at the wood's edge (the real lighting, TAA as in the game): steel traps (set;
## a marten; a fox), spring-pole snares (set; a hare), deadfalls (set; a raccoon), and the new things' icons (the
## pelts, small game). Windowed:
##   Godot --path . -s tools/survival/trap_shots.gd -- survival=on out=<dir> [at=x,z] [hour=11]

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var view
var p: FrontierPlayer
var b: SurvivalBridge
var out := "user://trap_shots"
var at := Vector3(-40.0, 0.0, 28.0)
var hour := 11.0
var imgs: Array[Image] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("at="):
			var xz := a.substr(3).split(",")
			at = Vector3(float(xz[0]), 0.0, float(xz[1]))
		elif a.begins_with("hour="):
			hour = float(a.substr(5))
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var lvl := current_scene
	p = lvl.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	if p.get("hud"):
		p.hud.visible = false
	var rig := lvl.get_node("EnvironmentRig") as EnvironmentRig
	rig.clock_driver.clock.running = false
	rig.clock_driver.clock.set_time(hour)
	b = SurvivalBridge.find(self)
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(960, 540))
	root.disable_3d = true
	view.camera.fov = 45.0
	# the player off to one side, out of the shots
	var pp := at + Vector3(0.0, 0.0, 12.0)
	pp.y = FrontierTerrain.height_at(pp.x, pp.z) + 0.05
	p.global_position = pp
	for i in 60:
		await process_frame
	var world := BuildWorld.of(self)
	var rows := [
		[["trap_steel", ""], ["trap_steel", "marten"], ["trap_steel", "fox"]],
		[["trap_snare", ""], ["trap_snare", "small"]],
		[["trap_deadfall", ""], ["trap_deadfall", "raccoon"]],
	]
	var gap := {"trap_steel": 1.1, "trap_snare": 2.2, "trap_deadfall": 2.4}
	var z := at.z
	var placed: Array = []
	for row: Array in rows:
		var x := at.x
		var first := String(row[0][0])
		var set_: Array = []
		for e: Array in row:
			var q := Vector3(x, 0.0, z)
			q.y = FrontierTerrain.height_at(q.x, q.z)
			var pc := world.add_piece(String(e[0]), Transform3D(Basis(), q), true, -1)
			var ts := pc.get_node_or_null("Trap") as TrapStation
			await process_frame
			ts.trap_id = SurvivalTrapLine.add_trap(b.core, String(TrapStation.TYPE[e[0]]), TrapStation.cell_at(q), "fair", 1.0)
			if String(e[1]) != "":
				var r := ts.record()
				r["state"] = "holding"
				r["catch"] = String(e[1])
			ts.refresh_look()
			set_.append(q)
			x += float(gap[first])
		placed.append(set_)
		z -= 4.0
	for i in 20:
		await process_frame
	# steel traps: close, from the front and above
	var s0: Vector3 = placed[0][0]
	var s2: Vector3 = placed[0][2]
	var mid := (s0 + s2) * 0.5
	await _shot(mid + Vector3(0.2, 1.1, 2.2), mid + Vector3(0.0, 0.05, -0.1))
	await _shot(placed[0][1] + Vector3(0.9, 0.7, 0.9), placed[0][1] + Vector3(0.0, 0.08, 0.0))
	# snares: from the side, the bent pole and the sprung one with the hare
	var n0: Vector3 = placed[1][0]
	var n1: Vector3 = placed[1][1]
	var nm := (n0 + n1) * 0.5
	await _shot(nm + Vector3(0.3, 1.3, 4.6), nm + Vector3(0.0, 0.8, -0.8))
	await _shot(n1 + Vector3(1.4, 1.5, 0.6), n1 + Vector3(0.0, 1.25, -1.15))
	# deadfalls
	var d0: Vector3 = placed[2][0]
	var d1: Vector3 = placed[2][1]
	var dm := (d0 + d1) * 0.5
	await _shot(dm + Vector3(0.0, 1.4, 3.4), dm + Vector3(0.0, 0.15, 0.0))
	await _shot(d1 + Vector3(0.9, 0.8, 1.3), d1 + Vector3(0.0, 0.1, 0.1))
	var sheet := Image.create(960 * 2, 540 * 3, false, Image.FORMAT_RGB8)
	for i in imgs.size():
		sheet.blit_rect(imgs[i], Rect2i(0, 0, 960, 540), Vector2i((i % 2) * 960, (i / 2) * 540))
	sheet.save_jpg(out.path_join("traps.jpg"), 0.88)
	await _icons()
	print("TRAP SHOTS DONE")
	quit()


func _shot(from: Vector3, look: Vector3) -> void:
	view.camera.global_transform = Transform3D(Basis.looking_at(look - from, Vector3.UP), from)
	for i in 12:
		await process_frame
	var img: Image = view.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	imgs.append(img)


## The new things' inventory icons in a row (ItemIcons, as the pack shows them).
func _icons() -> void:
	var kinds := ["marten_pelt", "mink_pelt", "fisher_pelt", "raccoon_pelt", "dried_marten_pelt", "small_game",
			"roast_small_game", "charred_small_game"]
	var icons := ItemIcons.shared(self)
	for k in kinds:
		icons.get_icon(k)
	var got := {}
	for i in 600:
		await process_frame
		for k in kinds:
			if not got.has(k):
				var t := icons.get_icon(k)
				if t:
					got[k] = t.get_image()
		if got.size() == kinds.size():
			break
	var sz := 128
	var sheet := Image.create(sz * kinds.size(), sz, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.16, 0.15, 0.13))
	for i in kinds.size():
		if got.has(kinds[i]):
			var im: Image = got[kinds[i]]
			im.convert(Image.FORMAT_RGBA8)
			im.resize(sz, sz)
			sheet.blend_rect(im, Rect2i(0, 0, sz, sz), Vector2i(i * sz, 0))
	sheet.save_png(out.path_join("trap_icons.png"))
