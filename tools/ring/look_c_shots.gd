extends SceneTree
## Look task C's lineup: the Tidebreak ring as it stands, then dressed (RingDressing) in each of RingLook's three moods,
## from the same cameras (an overview, the deck at a player's height, the near stand close, the far stand and its
## scoreboard, a gate). Measures each variant's frame cost on the deck view (GPU and CPU render time, draws, objects,
## primitives, lights) and logs it as LOOK_C_COST lines. Windowed (it draws):
##   Godot --path . -s tools/ring/look_c_shots.gd -- out=<dir> [variants=before,noon,golden,night,hidden] [shots=overview,deck]
## (hidden: the dressing built but out of sight, for its cost against the same warmed-up frame)
## Writes <dir>/<variant>_<shot>.png.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const W := 1280
const H := 720
const SHOTS := {
	"overview": [Vector3(-30.0, 15.0, 21.0), Vector3(0.0, -1.0, 0.0), 60.0],
	"deck": [Vector3(-15.5, 1.75, 1.2), Vector3(12.0, 1.4, -0.3), 62.0],
	"stands": [Vector3(9.5, 2.3, 11.6), Vector3(-1.5, 3.4, 19.5), 60.0],
	"tower": [Vector3(4.0, 3.6, 16.2), Vector3(0.0, 8.5, -24.0), 58.0],
	"gate": [Vector3(13.0, 2.6, 7.5), Vector3(27.8, 4.4, -0.5), 60.0],
}


func _initialize() -> void:
	var out := "user://look_c"
	var variants := ["before", "noon", "golden", "night", "hidden"]
	var shots: Array = SHOTS.keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("variants="):
			variants = Array(a.substr(9).split(","))
		elif a.begins_with("shots="):
			shots = Array(a.substr(6).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	await process_frame
	await process_frame
	var lvl := current_scene as RingLevel
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(W, H))
	root.disable_3d = true
	view.camera.far = 1500.0
	if lvl.environment_rig != null:
		lvl.environment_rig.follow_camera = view.camera
	var rid: RID = view.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for v: String in variants:
		var t0 := Time.get_ticks_msec()
		if v == "hidden":
			# the dressing out of sight and the noon light: the bare ring's cost in the same warmed-up run
			var dr := RingDressing.find_in(lvl)
			if dr != null:
				dr.visible = false
			RingLook.apply(lvl, "noon")
		elif v != "before":
			RingDressing.build(lvl, v)
			RingLook.apply(lvl, v)
		print("LOOK_C variant=%s build_ms=%d" % [v, Time.get_ticks_msec() - t0])
		for s: String in shots:
			var sh: Array = SHOTS[s]
			view.camera.fov = float(sh[2])
			view.camera.global_transform = Transform3D(Basis.looking_at((sh[1] as Vector3) - (sh[0] as Vector3), Vector3.UP), sh[0])
			for i in 70:
				await process_frame
			if s == "deck" or s == "overview":
				await _cost(rid, v, s, lvl)
			var img: Image = view.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_png(out.path_join("%s_%s.png" % [v, s]))
	print("LOOK_C DONE")
	quit()


func _cost(rid: RID, v: String, s: String, lvl: Node) -> void:
	# the frame's wall time with vsync off (the GPU-bound frame: the whole scene, the player too), and what was drawn
	var vs := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i in 10:
		await process_frame
	var n := 120
	var draws := 0
	var objs := 0
	var prims := 0
	var sdraws := 0
	var t0 := Time.get_ticks_usec()
	for i in n:
		await process_frame
	var frame_ms := float(Time.get_ticks_usec() - t0) / 1000.0 / float(n)
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(rid)
	draws = RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	objs = RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
	prims = RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	sdraws = RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	DisplayServer.window_set_vsync_mode(vs)
	var nl := 0
	var ns := 0
	for l: Node in lvl.find_children("*", "Light3D", true, false):
		if (l as Light3D).is_visible_in_tree():
			nl += 1
			if (l as Light3D).shadow_enabled:
				ns += 1
	var d := RingDressing.find_in(lvl)
	var fans := d.crowd.count if d != null and d.crowd != null else 0
	print("LOOK_C_COST variant=%s shot=%s frame_ms=%.2f render_cpu_ms=%.2f draws=%d shadow_draws=%d objects=%d prims=%d lights=%d shadowed=%d fans=%d" % [
			v, s, frame_ms, cpu, draws, sdraws, objs, prims, nl, ns, fans])
