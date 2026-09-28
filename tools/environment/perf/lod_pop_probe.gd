extends SceneTree
## The trees' LOD swaps seen by a camera moving slowly into the forest (user 2026-09-28: "it jitters between the low res
## one and the high res"): frames of a dolly from outside the impostor range to among the trees, rendered off-window,
## and how much each frame differs from the one before (a swap shows as a spike above the steady change of the move).
## Windowed; wrap it in a time limit:
##
##   Godot --path . --resolution 640x360 --fixed-fps 30 -s tools/environment/perf/lod_pop_probe.gd -- out=<dir> \
##       [size=1280x720] [secs=12] [from=-150,0] [to=-25,0] [look=-1,0] [hour=10.5] [taa=1]
##   <dir>/frames/f00000.jpg ..., <dir>/pops.txt (per frame: the change, and the frames that stand out)
##
## The camera keeps 2.4 m over the ground, like the game's, and looks along the move (look=: the direction, flat).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var out := ""
var px := Vector2i(1280, 720)
var secs := 12.0
var from := Vector2(-150.0, 0.0)
var to := Vector2(-25.0, 0.0)
var look := Vector2(-1.0, 0.0)
var hour := 10.5
var taa := false       ## taa=1: the view as the medium preset renders off Apple (TAA at 0.75, scaled up), not MetalFX


func _v2(s: String) -> Vector2:
	return Vector2(float(s.get_slice(",", 0)), float(s.get_slice(",", 1)))


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var k := a.get_slice("=", 0)
		var v := a.substr(a.find("=") + 1)
		match k:
			"out": out = v
			"size": px = Vector2i(int(v.get_slice("x", 0)), int(v.get_slice("x", 1)))
			"secs": secs = float(v)
			"from": from = _v2(v)
			"to": to = _v2(v)
			"look": look = _v2(v).normalized()
			"hour": hour = float(v)
			"taa": taa = v == "1"
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	DirAccess.make_dir_recursive_absolute(out.path_join("frames"))
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _ground(p: Vector2) -> float:
	return FrontierTerrain.height_at(p.x, p.y)


func _run() -> void:
	for i in 5:
		await process_frame
	var level := current_scene
	var player := level.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3(from.x, _ground(from) - 30.0, from.y)     # (out of the picture)
	for c in root.find_children("*", "CharacterCreator", true, false):
		c.queue_free()
	var rig := level.get_node_or_null("EnvironmentRig") as EnvironmentRig
	if rig and rig.clock_driver:
		rig.clock_driver.clock.running = false
		rig.clock_driver.clock.set_time(hour)
	var view := OffscreenView.new()
	root.add_child(view)
	view.setup(root, px)
	root.disable_3d = true
	for n in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	if taa:
		view.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		view.use_taa = true
	print("LOD POP view: scaling %d x%.2f taa %s (root %d)" % [view.scaling_3d_mode, view.scaling_3d_scale, view.use_taa, root.scaling_3d_mode])
	var cam := view.camera
	cam.fov = 60.0
	var n := int(round(secs * 30.0))
	var prev: Image = null
	var diffs := PackedFloat32Array()
	var place := func(t: float) -> void:
		var p := from.lerp(to, t)
		cam.global_position = Vector3(p.x, _ground(p) + 2.4, p.y)
		cam.look_at(cam.global_position + Vector3(look.x, -0.05, look.y), Vector3.UP)
	place.call(0.0)
	var attr := rig.get_camera_attributes() if rig else null
	if attr:
		attr.auto_exposure_speed = 30.0
	for i in 150:
		await process_frame
	for f in n:
		place.call(float(f) / float(n - 1))
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
		var img := view.get_texture().get_image()
		img.save_jpg(out.path_join("frames/f%05d.jpg" % f), 0.9)
		var small := img.duplicate() as Image
		small.resize(160, 90, Image.INTERPOLATE_BILINEAR)
		small.convert(Image.FORMAT_RGB8)
		if prev != null:
			var d := 0.0
			var a := small.get_data()
			var b := prev.get_data()
			for k in range(0, a.size(), 3):
				d += absf(float(a[k]) - float(b[k])) + absf(float(a[k + 1]) - float(b[k + 1])) + absf(float(a[k + 2]) - float(b[k + 2]))
			diffs.append(d / (a.size() / 3) / 3.0)
		prev = small
	# spikes: a frame's change well above the median of its neighbours
	var lines := PackedStringArray()
	var spikes := 0
	for i in diffs.size():
		var win := PackedFloat32Array()
		for j in range(maxi(0, i - 6), mini(diffs.size(), i + 7)):
			if j != i:
				win.append(diffs[j])
		win.sort()
		var med := win[win.size() / 2] if not win.is_empty() else 0.0
		var spike := diffs[i] > med * 1.8 + 0.4
		spikes += 1 if spike else 0
		lines.append("%d %.3f %.3f%s" % [i + 1, diffs[i], med, "  SPIKE" if spike else ""])
	var fa := FileAccess.open(out.path_join("pops.txt"), FileAccess.WRITE)
	fa.store_string("\n".join(lines))
	fa.close()
	var sum := 0.0
	for d in diffs:
		sum += d
	print("LOD POP PROBE frames=%d spikes=%d mean_change=%.3f" % [n, spikes, sum / maxf(diffs.size(), 1.0)])
	quit()
