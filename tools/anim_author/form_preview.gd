extends SceneTree
## A close look at our own Form casts in the game (tools/anim_author/install_form.gd): the real player on the level, each clip over
## the game's pose as FormCast plays it (ToolPose "full" standing), sampled at its moments and seen from the side and from the
## front three quarters, into one contact sheet (and, with frames=1, every frame to <out>/f00000.jpg ...).
##   Godot --path . --resolution 960x540 -s tools/anim_author/form_preview.gd -- out=<dir> [frames=1]

const AT := Vector3(-1.25, 0.0, -24.0)
const CELL := Vector2i(320, 300)
## [clip, [times (s) or metas]]
const SHOTS := [["own-form-clap-press", [0.0, "clap_s", 0.45, "press_s", 0.8]], ["own-form-release", [0.0, "push_s", 0.3, 0.45, 0.67]],
		["own-form-press-wall", ["clap_s", "hold_s", "push_s", 0.9]]]

var out := ""
var all_frames := false
var frame := 0
var player: FrontierPlayer
var cam: Camera3D
var lib: AnimationLibrary
var pose: ToolPose


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
		if a == "frames=1":
			all_frames = true
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	for i in 90:
		await physics_frame
	lib = load("res://animations_extra/Frontier_Form.res") as AnimationLibrary
	cam = Camera3D.new()
	cam.fov = 38.0
	current_scene.add_child(cam)
	cam.current = true
	pose = ToolPose.new()
	player.skeleton.add_child(pose)
	_place(AT)
	for i in 12:
		if player.hands_free:
			break
		if not player.is_switching():
			player.toggle_hands_free()
		for k in 8:
			await physics_frame
	for i in 30:
		await process_frame
	var cells: Array[Image] = []
	for view in ["side", "front"]:
		for shot: Array in SHOTS:
			var a := lib.get_animation(StringName(shot[0]))
			for tv: Variant in shot[1]:
				var t := float(a.get_meta(StringName(tv), 0.0)) if tv is String else float(tv)
				pose.layers = [{"anim": a, "time": minf(t, a.length), "weight": 1.0, "mask": "full"}]
				cells.append(await _snap(view, "%s %.2f" % [String(shot[0]).trim_prefix("own-form-"), t]))
	_sheet(cells, out.path_join("form_clips_sheet.png"))
	if all_frames:
		for shot: Array in SHOTS:
			var a := lib.get_animation(StringName(shot[0]))
			for i in int(round(a.length * 30.0)) + 1:
				pose.layers = [{"anim": a, "time": minf(i / 30.0, a.length), "weight": 1.0, "mask": "full"}]
				var img := await _snap("front", "")
				img.save_jpg(out.path_join("f%05d.jpg" % frame), 0.9)
				frame += 1
	print("FORM PREVIEW %d cells" % cells.size())
	quit()


func _place(at: Vector3) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO


func _snap(view: String, label: String) -> Image:
	for i in 3:
		await process_frame
	var sk := player.skeleton
	var fwd := sk.global_basis.z.normalized()
	var left := sk.global_basis.x.normalized()
	var c := player.global_position + Vector3.UP * 0.75
	if view == "side":
		cam.global_position = c - left * 3.0 + Vector3.UP * 0.25
	else:
		cam.global_position = c + fwd * 2.4 + left * 1.4 + Vector3.UP * 0.5
	cam.look_at(c + fwd * 0.2)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var s := img.get_size()
	var w := int(s.y * float(CELL.x) / CELL.y)
	img = img.get_region(Rect2i((s.x - w) / 2, 0, w, s.y))
	img.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
	if label != "":
		img.set_meta(&"label", label)
	return img


func _sheet(cells: Array[Image], path: String) -> void:
	var cols := 14 if cells.size() > 14 else cells.size()
	cols = mini(cols, 7)
	var rows := int(ceil(cells.size() / float(cols)))
	var sheet := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGB8)
	for i in cells.size():
		var im := cells[i]
		im.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(im, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
	sheet.save_png(path)
	print("FORM SHEET -> ", path)
