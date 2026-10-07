extends SceneTree
## The crowd's review (round 4 SHOW; the round-2 review: "the crowd is flat cut-outs"): the stands from the player's
## camera and from the gate tower at noon and at night, the poses close up, a strip of the ripple after a fall, and the
## crowd's cost on the gate tower's view at noon (frame time with vsync off, the crowd shown and hidden; its draws, shadow
## draws and primitives as the difference). Windowed (it draws), through the lock:
##   Godot --path . -s tools/ring/crowd_shots.gd -- out=<dir> tag=<before|after> [shots=views,poses,react,cost]
## Writes <dir>/<tag>_<view>_<light>.png, <tag>_poses.png, <tag>_react_strip.png; prints
##   CROWD tag=.. fans=.. tris=.. tris_far=.. meshes=..
##   CROWD_COST tag=.. view=tower light=noon crowd=<on|off> frame_ms=.. draws=.. shadow_draws=.. prims=..

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const W := 1280
const H := 720

var out := "user://crowd_shots"
var tag := "after"
var lvl: RingLevel
var view
var rid: RID


func _initialize() -> void:
	var shots := ["views", "poses", "react", "cost"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("tag="):
			tag = a.substr(4)
		elif a.begins_with("shots="):
			shots = Array(a.substr(6).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	await process_frame
	await process_frame
	lvl = current_scene as RingLevel
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(W, H))
	root.disable_3d = true
	view.camera.far = 1500.0
	if lvl.environment_rig != null:
		lvl.environment_rig.follow_camera = view.camera
	rid = view.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	if lvl.player != null:
		lvl.player.visible = false
	var d := RingDressing.find_in(lvl)
	_census(d)
	if "cost" in shots:
		await _light("noon")
		await _cost(d)
	if "views" in shots:
		for light: String in ["noon", "night"]:
			await _light(light)
			for v: String in ["player", "tower", "stand"]:
				_aim(v)
				await _frames(40)
				_save("%s_%s_%s.png" % [tag, v, light])
	if "poses" in shots:
		await _light("noon")
		await _poses(d)
	if "react" in shots:
		await _light("noon")
		await _react(d)
	print("CROWD DONE")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _light(name: String) -> void:
	RingDressing.build(lvl, name)
	RingLook.apply(lvl, name)
	await _frames(20)


func _save(file: String) -> void:
	var img: Image = view.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out.path_join(file))


## The cameras: the player's (behind him at his spawn, over his shoulder toward the middle, as the level's build camera),
## the gate tower's (high over the +X gate, the whole bowl), the near stand's (along it, for the ripple).
func _aim(v: String) -> void:
	var ring := lvl.ring
	var d := RingDressing.find_in(lvl)
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	view.camera.fov = 62.0
	match v:
		"player":
			# (round 4's camera C: higher and centred, behind him at his spawn)
			var xf := ring.spawn(0)
			var fwd := -xf.basis.z
			from = xf.origin - fwd * 4.5 + Vector3.UP * 3.0
			to = xf.origin + fwd * 12.0 + Vector3.UP * 0.6
		"tower":
			from = d.to_global(Vector3(d.ox + 1.0, d.y0 + 15.0, 0.0))
			to = d.to_global(Vector3(-d.ox * 0.2, d.y0 - 2.0, 0.0))
			view.camera.fov = 66.0
		"stand":
			# (over the tank's curtain: from the deck the falling water hides the stands' lower tiers)
			from = d.to_global(Vector3(-d.ox * 0.2, d.y0 + 6.5, d.oz - 7.0))
			to = d.to_global(Vector3(d.ox * 0.2, d.y0 + 2.2, d.oz + 3.0))
			view.camera.fov = 58.0
		"across":
			# (high over the -X end, down the near stand's length: the ripple from that end runs away from the camera)
			from = d.to_global(Vector3(-d.ox - 1.0, d.y0 + 9.0, d.oz - 5.0))
			to = d.to_global(Vector3(d.ox * 0.2, d.y0 + 1.5, d.oz + 3.0))
			view.camera.fov = 55.0
	view.camera.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)


func _census(d: RingDressing) -> void:
	if d == null or d.crowd == null:
		print("CROWD tag=%s fans=0" % tag)
		return
	var tris := 0
	var tris_far := 0
	var meshes := 0
	for mi: Node in d.crowd.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (mi as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null:
			continue
		meshes += 1
		var t := 0
		for s in mm.mesh.get_surface_count():
			var arr := mm.mesh.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			t += ((idx as PackedInt32Array).size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		if String(mi.name).ends_with("Far"):
			tris_far += t * mm.instance_count
		else:
			tris += t * mm.instance_count
	print("CROWD tag=%s fans=%d tris=%d tris_far=%d meshes=%d" % [tag, d.crowd.count, tris, tris_far, meshes])


## The gate tower at noon: the frame's wall time with vsync off, the crowd shown and hidden (the same warmed-up run).
func _cost(d: RingDressing) -> void:
	_aim("tower")
	await _frames(60)
	var vs := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var res := {}
	for pass_i in 2:
		for on: bool in [true, false]:
			if d != null and d.crowd != null:
				d.crowd.visible = on
			await _frames(30)
			var n := 240
			var t0 := Time.get_ticks_usec()
			var gpu := 0.0
			var cpu := 0.0
			for i in n:
				await process_frame
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
			var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / float(n)
			gpu /= float(n)
			cpu /= float(n)
			# (the window's own frame can be held to the display's 60 Hz whatever the vsync asked: the frames drawn
			# back to back with force_draw, no swap, are the GPU's own pace)
			var t1 := Time.get_ticks_usec()
			for i in n:
				RenderingServer.force_draw(false, 0.0)
			var fd := float(Time.get_ticks_usec() - t1) / 1000.0 / float(n)
			ms = fd if fd > 0.0 else ms
			var draws := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
					RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
			var sd := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
					RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
			var prims := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
					RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
			var sprims := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
					RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
			if pass_i == 1:
				res[on] = [ms, draws, sd, prims, sprims, gpu, cpu]
				print("CROWD_COST tag=%s view=tower light=noon crowd=%s frame_ms=%.2f gpu_ms=%.2f render_cpu_ms=%.2f draws=%d shadow_draws=%d prims=%d shadow_prims=%d" % [
						tag, "on" if on else "off", ms, gpu, cpu, draws, sd, prims, sprims])
	if res.size() == 2:
		print("CROWD_DELTA tag=%s frame_ms=%.2f gpu_ms=%.2f render_cpu_ms=%.2f draws=%d shadow_draws=%d prims=%d shadow_prims=%d" % [tag,
				res[true][0] - res[false][0], res[true][5] - res[false][5], res[true][6] - res[false][6],
				res[true][1] - res[false][1], res[true][2] - res[false][2], res[true][3] - res[false][3], res[true][4] - res[false][4]])
	if d != null and d.crowd != null:
		d.crowd.visible = true
	DisplayServer.window_set_vsync_mode(vs)


## Each pose's mesh once, side by side on a bench mid-deck, close up in the noon light (the crowd's own material).
func _poses(d: RingDressing) -> void:
	if d == null or d.crowd == null:
		return
	var holder := Node3D.new()
	holder.name = "PoseLineup"
	d.add_child(holder)
	var mis: Array = []
	for mi: Node in d.crowd.get_children():
		if mi is MultiMeshInstance3D and not String(mi.name).ends_with("Far"):
			mis.append(mi)
	var n := mis.size()
	var cols := [Color(0.62, 0.14, 0.1), Color(0.12, 0.34, 0.72), Color(0.16, 0.36, 0.22), Color(0.72, 0.52, 0.16),
			Color(0.88, 0.86, 0.8), Color(0.5, 0.3, 0.5)]
	var y := d.y0 + 0.45
	for k in n:
		var src := (mis[k] as MultiMeshInstance3D)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = src.multimesh.mesh
		mm.instance_count = 1
		var x := (float(k) - float(n - 1) * 0.5) * 1.05
		mm.set_instance_transform(0, Transform3D(Basis(Vector3.UP, PI), Vector3(x, y, 0.0)))
		mm.set_instance_color(0, cols[k % cols.size()])
		mm.set_instance_custom_data(0, Color(0.1 + 0.13 * k, 0.15 + 0.14 * k, 0.6, 0.2 + 0.15 * k))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = src.material_override
		mi.set_instance_shader_parameter(&"pose_id", src.get_instance_shader_parameter(&"pose_id"))
		holder.add_child(mi)
		var bench := CSGBox3D.new()
		bench.size = Vector3(0.9, 0.42, 0.5)
		bench.position = Vector3(x, y - 0.21, 0.1)
		holder.add_child(bench)
		var lab := Label3D.new()
		lab.text = String(src.name)
		lab.font_size = 28
		lab.pixel_size = 0.004
		lab.position = Vector3(x, y + 2.15, 0.0)
		lab.no_depth_test = true
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.outline_size = 6
		holder.add_child(lab)
	if d.crowd.has_method(&"set_cheer"):
		d.crowd.set_cheer(0.0, true)
	var from := d.to_global(Vector3(0.0, y + 1.1, -4.6))
	var to := d.to_global(Vector3(0.0, y + 0.75, 0.0))
	view.camera.fov = 52.0
	view.camera.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
	await _frames(40)
	_save("%s_poses.png" % tag)
	holder.queue_free()
	if d.crowd.has_method(&"set_cheer"):
		d.crowd.set_cheer(0.25, true)


## A fall at the -X end: 8 frames, 0.5 s apart, from over the water, the whole near stand (2 rows of 4, 640x360).
func _react(d: RingDressing) -> void:
	if d == null or not d.has_method(&"react"):
		print("CROWD react: none in this build")
		return
	_aim("across")
	await _frames(40)
	var strip := Image.create(640 * 4, 360 * 2, false, Image.FORMAT_RGB8)
	d.react("fall", 0, 1.0)
	for k in 8:
		var img: Image = view.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
		strip.blit_rect(img, Rect2i(0, 0, 640, 360), Vector2i((k % 4) * 640, (k / 4) * 360))
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 500:
			await process_frame
	strip.save_png(out.path_join("%s_react_strip.png" % tag))
