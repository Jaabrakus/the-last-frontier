extends SceneTree
## Screenshot strips of every traversal move family (windowed; the window appears on screen):
## side view and three-quarter view, one row per move played on the route, FRAMES evenly spaced
## over the move. The route runs on scenes/traversal_course.tscn with the live preview; every
## frame is recorded (the final pose after TraversalIK) and the chosen frames are replayed onto
## the rig (bone poses set from the record, the body modifier re-applied) and rendered by two
## cameras that share the course's world.
##
##   Godot --path . --fixed-fps 120 -s tools/traversal/shoot_moves.gd -- [routes=a,b] [out=dir] [frames=8]
## Output: <out>/<route>_side.png, <out>/<route>_34.png and <out>/index.json (frame times).

const W := 300
const H := 340

var _args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		_args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	change_scene_to_file("res://scenes/traversal_course.tscn")
	while current_scene == null or not current_scene.has_method("run_route"):
		await process_frame
	var course: Node = current_scene
	while not course.ready_done:
		await physics_frame
	course._debug_draw(false)
	# Station labels float in the course (one sits in front of the squeeze camera).
	for lb: Node in course.find_children("*", "Label3D", true, false):
		(lb as Label3D).visible = false
	var out_dir := str(_args.get("out", "user://traversal_shots"))
	DirAccess.make_dir_recursive_absolute(out_dir if out_dir.begins_with("/") else ProjectSettings.globalize_path(out_dir))
	var n_frames := int(_args.get("frames", "8"))
	var only := str(_args.get("routes", "")).split(",", false)
	var util := TravTestUtil.new(course)
	util.attach()
	# Two cameras on the course's world.
	var views := {}
	for vname in ["side", "34"]:
		var vp := SubViewport.new()
		vp.size = Vector2i(W, H)
		vp.world_3d = course.get_viewport().world_3d
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var cam := Camera3D.new()
		cam.fov = 45.0
		cam.far = 300.0
		vp.add_child(cam)
		cam.current = true
		views[vname] = {"vp": vp, "cam": cam}
	var index := {}
	for r: Dictionary in TravTestUtil.routes():
		if not only.is_empty() and not only.has(str(r.name)):
			continue
		var res: Dictionary = await util.run(r)
		var frames: Array = util.frames.duplicate()
		# Move spans from the events: a new start closes the open span, the ladder lane (CLIMB
		# mode: hub and cycles) is a span of its own, and the segment chains of one family
		# (beam / crawl / shimmy enter-loops-exit) merge into one row; at most 6 rows.
		var spans := []
		var open := {}
		for e: Dictionary in util.events:
			var fr := int(e.frame)
			if e.kind == "start" or (e.kind == "mode" and str(e.to) == "CLIMB"):
				if not open.is_empty():
					open["f1"] = fr
					spans.append(open)
				open = {"move": e.move if e.kind == "start" else "ladder_climb", "f0": fr}
			elif (e.kind in ["finish", "cancel"] or (e.kind == "mode" and str(e.to) == "OFF")) and not open.is_empty():
				open["f1"] = fr
				spans.append(open)
				open = {}
		if not open.is_empty():
			open["f1"] = frames.size() - 1
			spans.append(open)
		var merged := []
		for sp: Dictionary in spans:
			var fam := str(sp.move).get_slice("_", 0)
			if not merged.is_empty() and fam in ["beam", "crawl", "shimmy"]:
				var last: Dictionary = merged[merged.size() - 1]
				if str(last.move).get_slice("_", 0) == fam and int(last.f1) >= int(sp.f0) - 2:
					last["f1"] = sp.f1
					last["label"] = fam + " chain"
					continue
			merged.append(sp.duplicate())
		spans = merged.filter(func(sp): return int(sp.f1) > int(sp.f0) + 3)
		if spans.size() > 6:
			spans = spans.slice(0, 6)
		if spans.is_empty():
			print("route %s: no move to shoot (%s)" % [r.name, res.why])
			continue
		var strips := {}
		for vname in views:
			var img := Image.create(W * n_frames, H * spans.size(), false, Image.FORMAT_RGBA8)
			img.fill(Color(0.1, 0.1, 0.1))
			strips[vname] = img
		var tree: AnimationTree = course.actor.tree
		tree.active = false
		# The runner and the preview would put the live pose back every tick: hold them.
		course.runner.set_physics_process(false)
		course.set_physics_process(false)
		var ik: TraversalIK = course.actor.ik
		var saved_rec := ik.recorder
		ik.recorder = Callable()
		var rows := []
		for si in spans.size():
			var sp: Dictionary = spans[si]
			var f0 := int(sp.f0)
			var f1 := mini(int(sp.f1), frames.size() - 1)
			var row := {"move": sp.get("label", sp.move), "frames": []}
			# A fixed camera per row: the move's direction from the first to the last pelvis.
			var p0 := _pelvis(course, frames[f0])
			var p1 := _pelvis(course, frames[f1])
			var dir := Vector3(p1.x - p0.x, 0, p1.z - p0.z)
			if dir.length() < 0.3:
				var sk0: Transform3D = frames[f0].sk
				dir = sk0.basis.z
				dir.y = 0.0
			dir = dir.normalized()
			var right := Vector3.UP.cross(dir).normalized()
			var mid := (p0 + p1) * 0.5
			var span_len := maxf(p0.distance_to(p1), 1.0)
			for k in n_frames:
				var fi := f0 + int(round((f1 - f0) * k / float(maxi(n_frames - 1, 1))))
				var f: Dictionary = frames[fi]
				_apply(course, f)
				ik.pins = []
				ik.guards = []
				var focus := _pelvis(course, f)
				var look := Vector3(mid.x, focus.y, mid.z).lerp(focus, 0.6)
				# The camera side with the clearest line of sight (a deep block or a wall beside the
				# route would otherwise fill the frame), pulled in before a hit.
				var cs: Camera3D = views.side.cam
				cs.global_position = _clear_cam(course, look, [right, -right, (-dir + Vector3.UP * 0.3).normalized(), (dir + Vector3.UP * 0.3).normalized()],
						2.6 + span_len * 0.35, 0.25)
				cs.look_at(look, Vector3.UP)
				var c3: Camera3D = views["34"].cam
				c3.global_position = _clear_cam(course, look, [(right * 0.8 - dir * 0.9).normalized(), (-right * 0.8 - dir * 0.9).normalized(),
						(right * 0.8 + dir * 0.9).normalized(), (-dir + Vector3.UP * 0.3).normalized(), (dir + Vector3.UP * 0.3).normalized()], 3.0 + span_len * 0.3, 1.3)
				c3.look_at(look, Vector3.UP)
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				for vname in views:
					var vimg: Image = (views[vname].vp as SubViewport).get_texture().get_image()
					vimg.convert(Image.FORMAT_RGBA8)
					(strips[vname] as Image).blit_rect(vimg, Rect2i(0, 0, W, H), Vector2i(k * W, si * H))
				(row.frames as Array).append({"frame": fi, "t_move": float(f.get("t_move", 0.0)), "clip": str(f.clip)})
			rows.append(row)
		tree.active = true
		course.runner.set_physics_process(true)
		course.set_physics_process(true)
		ik.recorder = saved_rec
		for vname in views:
			var path := "%s/%s_%s.png" % [out_dir, r.name, vname]
			(strips[vname] as Image).save_png(path)
			print("saved ", path)
		index[r.name] = {"rows": rows, "why": res.why}
	var f := FileAccess.open("%s/index.json" % out_dir, FileAccess.WRITE)
	f.store_string(JSON.stringify(index, " ", false))
	f.close()
	print("SHOTS DONE")
	quit(0)


## Camera position around `look`: the first of `dirs` with a clear line of sight over `dist`
## (plus `up`), else the one with the longest clearance, pulled in 0.2 m before the hit.
func _clear_cam(course: Node, look: Vector3, dirs: Array, dist: float, up: float) -> Vector3:
	var space := (course as Node3D).get_world_3d().direct_space_state
	var best := Vector3.ZERO
	var best_d := -1.0
	for dv: Vector3 in dirs:
		var to := look + dv * dist + Vector3.UP * up
		var q := PhysicsRayQueryParameters3D.create(look, to)
		q.exclude = [course.runner.get_rid()]
		var h := space.intersect_ray(q)
		if h.is_empty():
			return to
		var d := look.distance_to(h.position) - 0.2
		if d > best_d:
			best_d = d
			best = look + (to - look).normalized() * maxf(d, 0.6)
	return best


func _pelvis(course: Node, f: Dictionary) -> Vector3:
	var sk: Skeleton3D = course.actor.skeleton
	return (f.sk as Transform3D) * ((f.globals[sk.find_bone("pelvis")] as Transform3D).origin)


## Puts a recorded final pose on the rig (local poses from the recorded globals).
func _apply(course: Node, f: Dictionary) -> void:
	var sk: Skeleton3D = course.actor.skeleton
	var rig: Node3D = course.actor.rig
	var skx: Transform3D = f.sk
	rig.global_transform = skx * sk.transform.affine_inverse()
	var g: Array = f.globals
	for b in sk.get_bone_count():
		var p := sk.get_bone_parent(b)
		var local: Transform3D = (g[b] as Transform3D) if p < 0 else (g[p] as Transform3D).affine_inverse() * (g[b] as Transform3D)
		sk.set_bone_pose_position(b, local.origin)
		sk.set_bone_pose_rotation(b, local.basis.get_rotation_quaternion())
		sk.set_bone_pose_scale(b, local.basis.get_scale())
