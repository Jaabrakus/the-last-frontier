extends SceneTree
## Calibrates the traversal contact points to the RENDERED body (design 8.4; user fix 2026-09-24:
## "hands and feet miss the ledge"). Output: data/traversal/contact_probes.json (TravContactProbes).
##
##   Godot --headless --path . -s tools/traversal/calibrate_contact_probes.gd -- [hz=30] [check]
##
## For every full-body traversal clip (traversal_catalog.json, the families the source-only
## traversal plays), the locomotion loops and the landing clips, the tool poses the real Actor_B
## rig (TravClipSampler, the pose the AnimationPlayer plays), drives the body's helper bones
## (CharacterBodyMesh._drive, as in game) and CPU-skins the hands, shoes and knees
## (TravMeshContacts). The vertices that carry the lowest point of a limb in any frame (within
## 4 mm) plus the limb's bind-pose extremes in 124 directions become the probe set. Probe
## vertices with skin weight on the driven helper bones are left out (they are only driven after
## TraversalIK). The report compares the probe set's lowest point with the full skinned limb
## over every sampled frame, and the old bone-origin contact points with the mesh.
##
## Provenance: body mesh: tools/character/build_body.py. Nothing is written to the clips or the
## rig.

const RIG := "res://characters/Actor_B.tscn"
const CATALOG := "res://data/traversal/traversal_catalog.json"
const OUT := "res://data/traversal/contact_probes.json"
const FAMILIES := ["vault", "climb_up", "ledge_hang", "wall_shimmy", "ladder", "drop", "gap_jump", "beam",
		"crouch_under", "squeeze", "edge_warn"]
const EXTRA := ["actor_b-p-sprint-fw", "actor_b-p-run-fw", "actor_b-p-walk-fw", "actor_b-p-relax-idle", "actor_b-p-fall",
		"actor_b-p-land-med^run", "actor_b-p-land-med^idle", "actor_b-p-land-soft^run", "actor_b-p-land-soft^idle",
		"actor_b-p-land-hard^run", "actor_b-p-land-hard^idle", "actor_b-p-land-med^sprint"]
const TIE := 0.004
const HELPER_MAX := 0.02
const MAX_PER_LIMB := 140
const GUARD_VOXEL := 0.02

var _args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		_args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	var t0 := Time.get_ticks_msec()
	var ok: bool = await _run()
	print("CONTACT PROBES %s in %.1f s" % ["OK" if ok else "FAILED", (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0 if ok else 1)


func _run() -> bool:
	var inst := (load(RIG) as PackedScene).instantiate() as Node3D
	root.add_child(inst)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	ap.stop()
	ap.active = false
	BindRest.ensure(sk, ap)
	var body := CharacterBodyMesh.attach(sk, ap)
	if body == null:
		push_error("calibrate_contact_probes: no body mesh")
		return false
	await process_frame
	await process_frame
	var mc := TravMeshContacts.build(body)
	var sampler := TravClipSampler.from_skeleton(sk)
	var lib := ap.get_animation_library(&"actor_b")
	var hz := float(_args.get("hz", "30"))
	# Clips.
	var clips := PackedStringArray()
	var cat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	for name: String in cat.clips:
		var c: Dictionary = cat.clips[name]
		if not str(c.family) in FAMILIES:
			continue
		if str((c.variant as Dictionary).get("kind", "base")) != "base":
			continue
		if lib.has_animation(name):
			clips.append(name)
	for e in EXTRA:
		if lib.has_animation(e) and not clips.has(e):
			clips.append(e)
	print("calibrating on %d clips at %.0f Hz; limb vertices: %s" % [clips.size(), hz,
			", ".join(TravMeshContacts.LIMBS.map(func(l): return "%s %d" % [l, mc.count(l)]))])
	var hits := {}
	for limb in TravMeshContacts.LIMBS:
		var arr := PackedInt32Array()
		arr.resize(mc.count(limb))
		arr.fill(0)
		hits[limb] = arr
	var frames := 0
	var poses := []   # kept (subsampled) for the error report: [clip, t]
	for clip in clips:
		var a := lib.get_animation(clip)
		var n := maxi(1, int(ceil(a.length * hz)))
		for k in n + 1:
			var t := minf(k / hz, a.length)
			var pose := sampler.pose(a, t)
			var g := mc.full_globals(pose)
			frames += 1
			for limb in TravMeshContacts.LIMBS:
				var pts := mc.skin(limb, g)
				var ymin := INF
				for p in pts:
					ymin = minf(ymin, p.y)
				var H: PackedInt32Array = hits[limb]
				var hw: PackedFloat32Array = mc.limbs[limb].helper_w
				for i in pts.size():
					if pts[i].y <= ymin + TIE and hw[i] <= HELPER_MAX:
						H[i] += 1
				hits[limb] = H
			if k % 3 == 0:
				poses.append([clip, t])
	# Selection: the 60 most frequent lowest vertices, then bind-pose extremes (124 directions).
	var out_limbs := {}
	var report := {}
	var dirs := []
	for x in [-2, -1, 0, 1, 2]:
		for y in [-2, -1, 0, 1, 2]:
			for z in [-2, -1, 0, 1, 2]:
				if (x != 0 or y != 0 or z != 0) and maxi(maxi(absi(x), absi(y)), absi(z)) == 2 or (absi(x) <= 1 and absi(y) <= 1 and absi(z) <= 1 and (x != 0 or y != 0 or z != 0)):
					dirs.append(Vector3(x, y, z).normalized())
	var selected := {}
	for limb in TravMeshContacts.LIMBS:
		var H: PackedInt32Array = hits[limb]
		var hw: PackedFloat32Array = mc.limbs[limb].helper_w
		var bind: PackedVector3Array = mc.limbs[limb].bind
		var order := []
		for i in H.size():
			if H[i] > 0:
				order.append([H[i], i])
		order.sort_custom(func(p, q): return p[0] > q[0])
		var sel := {}
		for e: Array in order:
			if sel.size() >= 60:
				break
			sel[int(e[1])] = true
		for d: Vector3 in dirs:
			var best := -1
			var bv := -INF
			for i in bind.size():
				if hw[i] > HELPER_MAX:
					continue
				var v := bind[i].dot(d)
				if v > bv:
					bv = v
					best = i
			if best >= 0:
				sel[best] = true
		selected[limb] = sel.keys()
	# Error report: probe-set lowest vs full limb lowest; old bone-origin contact vs mesh.
	for limb in TravMeshContacts.LIMBS:
		report[limb] = {"frames": 0, "probe_err_max": 0.0, "probe_err_mean": 0.0, "bone_err_max": 0.0, "bone_err_mean": 0.0,
				"bone_err_min": INF, "probes": (selected[limb] as Array).size(), "vertices": mc.count(limb)}
	for pr: Array in poses:
		var a := lib.get_animation(str(pr[0]))
		var pose := sampler.pose(a, float(pr[1]))
		var g := mc.full_globals(pose)
		var pd := {}
		for i in pose.size():
			pd[i] = pose[i]
		var old := sampler.points_from_bones(pd)
		for limb in TravMeshContacts.LIMBS:
			var pts := mc.skin(limb, g)
			var ymin := INF
			for p in pts:
				ymin = minf(ymin, p.y)
			var ysel := INF
			for i: int in selected[limb]:
				ysel = minf(ysel, pts[i].y)
			var R: Dictionary = report[limb]
			R.frames = int(R.frames) + 1
			var e := ysel - ymin
			R.probe_err_max = maxf(float(R.probe_err_max), e)
			R.probe_err_mean = float(R.probe_err_mean) + e
			var eb: float = (old[limb] as Vector3).y - ymin
			R.bone_err_max = maxf(float(R.bone_err_max), eb)
			R.bone_err_min = minf(float(R.bone_err_min), eb)
			R.bone_err_mean = float(R.bone_err_mean) + eb
	for limb in TravMeshContacts.LIMBS:
		var R: Dictionary = report[limb]
		R.probe_err_mean = float(R.probe_err_mean) / maxf(1.0, float(R.frames))
		R.bone_err_mean = float(R.bone_err_mean) / maxf(1.0, float(R.frames))
		for k in R:
			if R[k] is float:
				R[k] = snappedf(float(R[k]), 0.0001)
		print("  %-7s vertices %4d probes %3d | probe lowest vs mesh: max %.4f mean %.4f m | old bone point vs mesh: %.3f .. %.3f (mean %.3f) m" % [
				limb, R.vertices, R.probes, R.probe_err_max, R.probe_err_mean, R.bone_err_min, R.bone_err_max, R.bone_err_mean])
	# Guard sets: every limb vertex, decimated on a GUARD_VOXEL grid (the IK's no-penetration
	# check needs the whole surface, not only the points that are ever lowest).
	var guard_sets := {}
	for limb in TravMeshContacts.LIMBS:
		var bind: PackedVector3Array = mc.limbs[limb].bind
		var hw: PackedFloat32Array = mc.limbs[limb].helper_w
		var cells := {}
		for i in bind.size():
			if hw[i] > HELPER_MAX:
				continue
			var key := Vector3i((bind[i] / GUARD_VOXEL).floor())
			if not cells.has(key):
				cells[key] = i
		guard_sets[limb] = cells.values()
		print("  %-7s guard set %d vertices" % [limb, (guard_sets[limb] as Array).size()])
	# Output.
	for limb in TravMeshContacts.LIMBS:
		var L: Dictionary = mc.limbs[limb]
		var verts := []
		for i: int in selected[limb]:
			var row := []
			var wsum := 0.0
			var names := []
			var ws := []
			var offs := []
			for k in 4:
				var j := 4 * i + k
				var bn := sk.get_bone_name((L.bones as PackedInt32Array)[j])
				var wk := float((L.weights as PackedFloat32Array)[j])
				var off: Vector3 = (L.offs as PackedVector3Array)[j]
				if bn.contains("forarm_twist"):
					# Forearm twist helpers are only driven after TraversalIK: the wrist stands in.
					var wrist := sk.find_bone(bn.substr(0, 1) + "_wrist")
					off = TravMeshContacts.inv_bind(L.skin, wrist) * (L.bind as PackedVector3Array)[i]
					bn = sk.get_bone_name(wrist)
				elif bn.contains("twist") or bn.contains("helper"):
					wk = 0.0
				names.append(bn)
				ws.append(wk)
				wsum += wk
				offs.append(off)
			for k in 4:
				row.append(names[k])
			for k in 4:
				row.append(snappedf(float(ws[k]) / maxf(wsum, 1e-6), 0.000001))
			for k in 4:
				var o: Vector3 = offs[k]
				row.append_array([snappedf(o.x, 0.000001), snappedf(o.y, 0.000001), snappedf(o.z, 0.000001)])
			verts.append(row)
		out_limbs[limb] = {"verts": verts, "vertex_ids": selected[limb], "limb_vertices": mc.count(limb)}
		var gverts := []
		for i: int in guard_sets[limb]:
			gverts.append(_row(sk, L, i))
		out_limbs[limb + "_guard"] = {"verts": gverts, "vertex_ids": guard_sets[limb], "limb_vertices": mc.count(limb)}
	var data := {
		"meta": {
			"schema": 1,
			"generator": "tools/traversal/calibrate_contact_probes.gd",
			"body": CharacterBodyMesh.DEFAULT_PATH,
			"body_sha256": FileAccess.get_sha256(CharacterBodyMesh.DEFAULT_PATH),
			"library_sha256": FileAccess.get_sha256("res://animations/Actor_B.res"),
			"clips": clips.size(), "frames": frames, "hz": hz,
			"row": "[bone0..3, weight0..3, offset0 xyz .. offset3 xyz]: p = sum w_k * G[bone_k] * offset_k (skeleton space)",
			"rule": "vertices within %.3f m of the limb's lowest in any frame of the traversal clips + bind extremes (124 dirs, so the guards see edges and toes); helper-weighted vertices (> %.2f) excluded" % [TIE, HELPER_MAX],
			"report": report,
		},
		"limbs": out_limbs,
	}
	var text := JSON.stringify(data, " ", false) + "\n"
	if _args.has("check"):
		print("check only, not written")
		return true
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + OUT)
		return false
	f.store_string(text)
	f.close()
	print("wrote %s (%d bytes)" % [OUT, text.length()])
	return true


static func _row(sk: Skeleton3D, L: Dictionary, i: int) -> Array:
	var names := []
	var ws := []
	var offs := []
	var wsum := 0.0
	for k in 4:
		var j := 4 * i + k
		var bn := sk.get_bone_name((L.bones as PackedInt32Array)[j])
		var wk := float((L.weights as PackedFloat32Array)[j])
		var off: Vector3 = (L.offs as PackedVector3Array)[j]
		if bn.contains("forarm_twist"):
			var wrist := sk.find_bone(bn.substr(0, 1) + "_wrist")
			off = TravMeshContacts.inv_bind(L.skin, wrist) * (L.bind as PackedVector3Array)[i]
			bn = sk.get_bone_name(wrist)
		elif bn.contains("twist") or bn.contains("helper"):
			wk = 0.0
		names.append(bn)
		ws.append(wk)
		wsum += wk
		offs.append(off)
	var row := []
	for k in 4:
		row.append(names[k])
	for k in 4:
		row.append(snappedf(float(ws[k]) / maxf(wsum, 1e-6), 0.000001))
	for k in 4:
		var o: Vector3 = offs[k]
		row.append_array([snappedf(o.x, 0.000001), snappedf(o.y, 0.000001), snappedf(o.z, 0.000001)])
	return row
