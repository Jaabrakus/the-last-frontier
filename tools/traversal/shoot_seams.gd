extends SceneTree
## Screenshot strips of the worst content seams of a route (seam fix pass 2026-09-24; windowed,
## the window appears on screen): side view and three-quarter view, one row per seam, FRAMES
## frames STEP physics frames apart around the switch (the first frame of the new content is
## marked with a red bar on top). The seams are picked from a reference seam report (default the
## "before" report, so a before / after pair shows the same seams): its worst seams per route by
## the largest one-frame jump of the pelvis, palms, feet and capsule, matched in this run by the
## seam's keys with their serial numbers masked and by occurrence. The camera is fixed per row
## (a pop shows as a jump between neighbouring frames). The route runs on
## scenes/traversal_course.tscn with the live preview; every frame is recorded (the final pose
## after TraversalIK) and the chosen frames are replayed onto the rig with the IK and the
## inertializer off (they are already in the record) and rendered by two cameras.
##
##   Godot --path . --fixed-fps 120 -s tools/traversal/shoot_seams.gd -- routes=a,b [out=dir]
##         [ref=path/to/seam_continuity_before.json] [pick=3] [frames=10] [step=2] [label=after]
##         [extra=route@where|label,...]   (extra rows: a frame index, start=<key text>#<n>+<frames>,
##                                          or capy=<m>; see _extra_frames)
## Output: <out>/<route>_side.png, <out>/<route>_34.png and <out>/index.json.

const W := 240
const H := 300
const REF := "res://data/traversal/reports/seam_continuity_before.json"

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
	if course.has_method("_debug_draw"):
		course._debug_draw(false)
	for lb: Node in course.find_children("*", "Label3D", true, false):
		(lb as Label3D).visible = false
	var out_dir := str(_args.get("out", "user://traversal_seam_shots"))
	var out_abs := out_dir if out_dir.begins_with("/") else ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(out_abs)
	var n_frames := int(_args.get("frames", "10"))
	var step := int(_args.get("step", "2"))
	var pick := int(_args.get("pick", "3"))
	var only := str(_args.get("routes", "")).split(",", false)
	var ref_path := str(_args.get("ref", REF))
	var ref := {}
	var rf := FileAccess.open(ref_path, FileAccess.READ)
	if rf:
		ref = JSON.parse_string(rf.get_as_text())
		rf.close()
	else:
		push_error("no reference seam report at " + ref_path)
	var util := TravTestUtil.new(course)
	util.attach()
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
	var index := {"meta": {"label": str(_args.get("label", "")), "ref": ref_path, "frames": n_frames, "step": step,
			"note": "one row per seam; the red bar marks the first frame of the new content"}, "routes": {}}
	for r: Dictionary in TravTestUtil.routes():
		if not only.is_empty() and not only.has(str(r.name)):
			continue
		var wanted := _worst_ref_seams(ref, str(r.name), pick)
		var extra := _extra_frames(str(r.name))
		if wanted.is_empty() and extra.is_empty():
			print("route %s: no reference seams" % r.name)
			continue
		await util.run(r)
		var frames: Array = util.frames.duplicate()
		var found := _match(frames, wanted)
		# Extra rows (extra=route@frame|label,...): moments that are no content switch (the step
		# onto the fallen log's end, a teleport of the old step assist).
		for ex: Dictionary in extra:
			var fi0 := clampi(_resolve_frame(frames, str(ex.frame)), 12, frames.size() - 1)
			found.append({"frame": fi0, "from": str(frames[fi0 - 1].key), "to": str(ex.label), "score": 0.0})
		found.sort_custom(func(x, y): return int(x.frame) < int(y.frame))
		if found.is_empty():
			print("route %s: none of the reference seams occurred" % r.name)
			continue
		var strips := {}
		for vname in views:
			var img := Image.create(W * n_frames, H * found.size(), false, Image.FORMAT_RGBA8)
			img.fill(Color(0.1, 0.1, 0.1))
			strips[vname] = img
		var tree: AnimationTree = course.actor.tree
		tree.active = false
		course.runner.set_physics_process(false)
		course.set_physics_process(false)
		var ik: TraversalIK = course.actor.ik
		var saved_rec := ik.recorder
		ik.recorder = Callable()
		ik.active = false
		var inert: Variant = course.actor.get("inert")
		if inert is SkeletonModifier3D:
			(inert as SkeletonModifier3D).active = false
		var rows := []
		for si in found.size():
			var sm: Dictionary = found[si]
			var fs := int(sm.frame)
			var fa := clampi(fs - (n_frames / 2 - 1) * step - step, 0, frames.size() - 1)
			var fb := clampi(fa + (n_frames - 1) * step, 0, frames.size() - 1)
			var p0 := _pelvis(course, frames[fa])
			var p1 := _pelvis(course, frames[fb])
			var ps := _pelvis(course, frames[fs])
			var dir := Vector3(p1.x - p0.x, 0, p1.z - p0.z)
			if dir.length() < 0.15:
				var skx: Transform3D = frames[fs].sk
				dir = skx.basis.z
				dir.y = 0.0
			dir = dir.normalized()
			var right := Vector3.UP.cross(dir).normalized()
			var look := ps
			var cs: Camera3D = views.side.cam
			cs.global_position = _clear_cam(course, look, [right, -right, (-dir + Vector3.UP * 0.3).normalized()], 2.4, 0.2)
			cs.look_at(look, Vector3.UP)
			var c3: Camera3D = views["34"].cam
			c3.global_position = _clear_cam(course, look, [(right * 0.8 - dir * 0.9).normalized(), (-right * 0.8 - dir * 0.9).normalized(),
					(right * 0.8 + dir * 0.9).normalized(), (-dir + Vector3.UP * 0.3).normalized()], 2.6, 1.0)
			c3.look_at(look, Vector3.UP)
			var row := {"seam": "%s -> %s" % [sm.from, sm.to], "frame": fs, "ref_score": sm.score, "frames": []}
			var marked := false
			for k in n_frames:
				var fi := clampi(fa + k * step, 0, frames.size() - 1)
				_apply(course, frames[fi])
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				for vname in views:
					var vimg: Image = (views[vname].vp as SubViewport).get_texture().get_image()
					vimg.convert(Image.FORMAT_RGBA8)
					var img: Image = strips[vname]
					img.blit_rect(vimg, Rect2i(0, 0, W, H), Vector2i(k * W, si * H))
					if not marked and fi >= fs:
						img.fill_rect(Rect2i(k * W, si * H, W, 6), Color(0.9, 0.1, 0.1))
					# Frame separators.
					img.fill_rect(Rect2i(k * W, si * H, 1, H), Color(0, 0, 0))
				if fi >= fs:
					marked = true
				(row.frames as Array).append({"frame": fi, "key": str(frames[fi].key)})
			rows.append(row)
		tree.active = true
		course.runner.set_physics_process(true)
		course.set_physics_process(true)
		ik.recorder = saved_rec
		ik.active = true
		if inert is SkeletonModifier3D:
			(inert as SkeletonModifier3D).active = true
		for vname in views:
			var path := "%s/%s_%s.png" % [out_abs, r.name, vname]
			(strips[vname] as Image).save_png(path)
			print("saved ", path)
		index.routes[r.name] = rows
	var f := FileAccess.open("%s/index.json" % out_abs, FileAccess.WRITE)
	f.store_string(JSON.stringify(index, " ", false))
	f.close()
	print("SEAM SHOTS DONE")
	quit(0)


## extra=route@where|label,... with `where`:
##   <frame>                   a frame index of this run of the route;
##   start=<text>#<n>+<k>      k frames after the n-th start of a content whose key contains text;
##   capy=<h>                  the first frame whose capsule is h m above where the route began.
## (Frame indices differ between runs of different route sets; the anchors do not.)
func _extra_frames(route: String) -> Array:
	var out := []
	for item in str(_args.get("extra", "")).split(",", false):
		var rs := item.get_slice("@", 0)
		if rs != route:
			continue
		var rest := item.get_slice("@", 1)
		out.append({"frame": rest.get_slice("|", 0), "label": rest.get_slice("|", 1) if "|" in rest else "extra"})
	return out


func _resolve_frame(frames: Array, where: String) -> int:
	if where.is_valid_int():
		return int(where)
	if where.begins_with("capy="):
		var h := float(where.trim_prefix("capy="))
		var y0 := (frames[0].capsule as Vector3).y
		for i in frames.size():
			if (frames[i].capsule as Vector3).y - y0 > h:
				return i
		return frames.size() - 1
	if where.begins_with("start="):
		var spec := where.trim_prefix("start=")
		var k := int(spec.get_slice("+", 1)) if "+" in spec else 0
		spec = spec.get_slice("+", 0)
		var nth := int(spec.get_slice("#", 1)) if "#" in spec else 1
		var txt := spec.get_slice("#", 0)
		var seen := 0
		for i in range(1, frames.size()):
			if str(frames[i].key).contains(txt) and not str(frames[i - 1].key).contains(txt):
				seen += 1
				if seen == nth:
					return i + k
		return frames.size() - 1
	return 0


## A key with its serial numbers masked ("climb_hang_3m:12:1" -> "climb_hang_3m:#:1", "cyc:14" ->
## "cyc:#", "exit:run:3" -> "exit:run:#"): a move's key ends with its part index, the others with
## a serial.
static func _mask(key: String) -> String:
	var parts := key.split(":")
	# (The locomotion gait and the landing clip may differ between two runs: a walk or a run into
	# the same move, a medium or a soft landing; they are the same seam.)
	if parts.size() > 0 and parts[0] == "loco":
		return "loco"
	if parts.size() > 0 and parts[0].begins_with("land_"):
		parts[0] = "land"
	var keep_last := parts.size() == 3 and not (parts[0] in ["loco", "exit", "air"])
	for i in parts.size():
		if parts[i].is_valid_int() and not (keep_last and i == parts.size() - 1):
			parts[i] = "#"
	return ":".join(parts)


func _worst_ref_seams(ref: Dictionary, route: String, pick: int) -> Array:
	var rr: Dictionary = (ref.get("routes", {}) as Dictionary).get(route, {})
	var seams: Array = rr.get("seams", [])
	var occ := {}
	var scored := []
	for s: Dictionary in seams:
		var pair := "%s>%s" % [_mask(str(s.from)), _mask(str(s.to))]
		occ[pair] = int(occ.get(pair, 0)) + 1
		# Gait changes of the preview's locomotion are not traversal seams.
		if str(s.from).begins_with("loco:") and str(s.to).begins_with("loco:"):
			continue
		var sc := 0.0
		for k in ["pelvis", "l_palm", "r_palm", "l_foot", "r_foot", "capsule"]:
			sc = maxf(sc, float((s.get(k, {}) as Dictionary).get("d2", 0.0)))
		scored.append({"pair": pair, "occ": int(occ[pair]), "score": sc, "from": str(s.from), "to": str(s.to)})
	scored.sort_custom(func(a, b): return float(a.score) > float(b.score))
	return scored.slice(0, pick)


func _match(frames: Array, wanted: Array) -> Array:
	var occ := {}
	var hits := []
	for i in range(12, frames.size()):
		var a: Dictionary = frames[i - 1]
		var b: Dictionary = frames[i]
		if a.key == b.key and a.mode == b.mode:
			continue
		var pair := "%s>%s" % [_mask(str(a.key)), _mask(str(b.key))]
		occ[pair] = int(occ.get(pair, 0)) + 1
		for w: Dictionary in wanted:
			if str(w.pair) == pair and int(w.occ) == int(occ[pair]):
				hits.append({"frame": i, "from": str(a.key), "to": str(b.key), "score": w.score})
	hits.sort_custom(func(x, y): return int(x.frame) < int(y.frame))
	return hits


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
