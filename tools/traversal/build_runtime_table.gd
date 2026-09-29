extends SceneTree
## Builds data/traversal/traversal_runtime.json from
##   data/traversal/traversal_moves.json   (hand-authored move catalogue, statuses)
##   data/traversal/graph_traversal.json   (graph chains, records, hub requests)
##   data/traversal/clip_geometry.json     (clip survey: reconstructed align paths + anchors)
## and the real Actor_B rig (characters/Actor_B.tscn, library actor_b).
##
##   Godot --headless --path . -s tools/traversal/build_runtime_table.gd -- [check] [report] [only=a,b]
##
## Per move it resolves the graph chain (state -> clip per mode), samples the clips at
## TRACK_HZ on the rig (TravClipSampler), rebuilds the reference path of the skeleton origin
## (the align, which was not exported) at that rate by pinning the survey's anchor limb between
## its key samples (the survey's odometry at 10-30 Hz, refined), finds the contact windows of
## hands, feet and knees (world speed below settings.contact_speed) and classifies them by
## surface (support / top / landing / wall / hang). The runtime MotionWarper maps these onto the
## detected obstacle (design 8.1-8.4).
##
## Frame of every track: the move frame at t = 0 (the character's start): +Z fwd, +X left, +Y up.
## Provenance: native_asset_id and original_name are copied unchanged per part.

const RIG := "res://characters/Actor_B.tscn"
const LIB := &"actor_b"
const LIBRARY_RES := "res://animations/Actor_B.res"
const MOVES := "res://data/traversal/traversal_moves.json"
const GEOM := "res://data/traversal/clip_geometry.json"
## Survey of extra clips the source-only traversal plays (landings; catalog_extra.json).
const GEOM_EXTRA := "res://data/traversal/clip_geometry_extra.json"
const GRAPH := "res://data/traversal/graph_traversal.json"
const OUT := "res://data/traversal/traversal_runtime.json"
const JsonW := preload("res://tools/traversal/measure_traversal_clips.gd")
const G := 9.81
const SEAM_POP_M := 0.03
const GRIP_CLASSES := ["hang_climb", "chest", "tall_vault"]
const GRIP_EDGE_M := 0.02
const JOIN_EASE_S := 0.25
## A sample this close to a part's start time belongs to that part (seam fix 2026-09-24): the
## clips' lengths are float32 (0.30000001 s), so their sums land a hair after the sample grid and
## a 1e-9 test sampled the OLD part at the join's grid time. The runtime (TravWarpedPath.part_at,
## which reads the start times rounded to 4 decimals) switches with the same slack, so the clip
## switches on the same frame as the table's root step.
const PART_EPS := 1e-4
const SEAM_FADE_S := 0.1
const POSE_POINTS := ["l_hand", "r_hand", "l_foot", "r_foot", "l_knee", "r_knee", "head_top", "l_elbow", "r_elbow"]
const LIMBS := ["l_hand", "r_hand", "l_foot", "r_foot", "l_knee", "r_knee"]
const TRACK_POINTS := ["l_hand", "r_hand", "l_foot", "r_foot", "l_knee", "r_knee", "pelvis", "head_top",
		"l_heel", "r_heel", "l_ball", "r_ball", "l_elbow", "r_elbow"]
## Ladder moves also carry the closed fists' holes (TravClipSampler l/r_grip, TraversalIK.GRIP_OFFSET):
## the lane puts the rungs there and the held hand carries their align (contact pass 2026-09-25).
const GRIP_POINTS := ["l_grip", "r_grip"]
const GRIP_TRACK_CLASSES := ["ladder", "ladder_cycle", "hub"]
## Each ladder move's own fist holes (tools/traversal/measure_ladder_grips.gd).
const GRIPS := "res://data/traversal/ladder_grips.json"

var _args := {}
var _sampler: TravClipSampler
var _lib: AnimationLibrary
var _geom: Dictionary
var _graph: Dictionary
var _moves: Dictionary
var _hz := 60.0
var _vcontact := 0.4
var _errors: Array[String] = []
var _warnings: Array[String] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if "=" in s:
			_args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1)
		else:
			_args[s] = true
	await process_frame
	var t0 := Time.get_ticks_msec()
	var data := build(root)
	for w in _warnings:
		print("  warn " + w)
	if not _errors.is_empty():
		for e in _errors:
			printerr("build_runtime_table: " + e)
		print("TRAVERSAL RUNTIME TABLE FAILED (%d error(s))" % _errors.size())
		quit(1)
		return
	if _args.has("report"):
		_report(data)
	var text := JsonW.to_json(data) + "\n"
	var out: String = _args.get("out", OUT)
	if _args.has("check"):
		var old := FileAccess.get_file_as_string(out) if FileAccess.file_exists(out) else ""
		if JsonW._strip_stamp(old) != JsonW._strip_stamp(text):
			print("build_runtime_table: %s is %s" % [out, "missing" if old == "" else "stale"])
			print("TRAVERSAL RUNTIME TABLE FAILED (stale)")
			quit(1)
			return
		print("TRAVERSAL RUNTIME TABLE OK (current)")
		quit(0)
		return
	if _args.has("only") and not _args.has("out"):
		print("TRAVERSAL RUNTIME TABLE OK (only=, not written)")
		quit(0)
		return
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		printerr("cannot write " + out)
		quit(1)
		return
	f.store_string(text)
	f.close()
	print("build_runtime_table: wrote %s (%d moves, %d bytes) in %.1f s" % [out, (data.moves as Dictionary).size(),
			text.to_utf8_buffer().size(), (Time.get_ticks_msec() - t0) / 1000.0])
	print("TRAVERSAL RUNTIME TABLE OK")
	quit(0)


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func build(parent: Node) -> Dictionary:
	var scene := load(RIG) as PackedScene
	var inst := scene.instantiate() as Node3D
	parent.add_child(inst)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	ap.stop()
	var rest := BindRest.ensure(sk, ap, LIB)
	if not bool(rest.get("ok", false)):
		_errors.append("rig rest is not the null-add bind pose: %s" % rest.get("reason", "?"))
		return {}
	_lib = ap.get_animation_library(LIB)
	_sampler = TravClipSampler.from_skeleton(sk)
	_moves = _read_json(MOVES)
	_geom = _read_json(GEOM)
	_graph = _read_json(GRAPH)
	if _moves == null or _geom == null or _graph == null:
		_errors.append("cannot read %s / %s / %s" % [MOVES, GEOM, GRAPH])
		return {}
	# settings.clip_interpolation "cubic": the clips are sampled (and played, TravPreviewActor /
	# the player integration) with cubic interpolation through their keys (see
	# TravInertializer.smooth_clip_tracks), so the references match what is shown.
	if str((_moves.settings as Dictionary).get("clip_interpolation", "linear")) == "cubic":
		# (Every clip of the library: the moves' parts are resolved from the graph later. This
		# only changes how this process samples them; nothing is saved.)
		var names := PackedStringArray()
		for an in _lib.get_animation_list():
			names.append(str(an))
		print("build_runtime_table: cubic clip interpolation, %d tracks" % TravInertializer.smooth_library_clips(_lib, names))
	var extra: Variant = _read_json(GEOM_EXTRA)
	if extra is Dictionary:
		for k: String in (extra as Dictionary).get("clips", {}):
			if not (_geom.clips as Dictionary).has(k):
				_geom.clips[k] = extra.clips[k]
	_hz = float(_moves.settings.get("track_hz", 60))
	_vcontact = float(_moves.settings.get("contact_speed", 0.4))
	var only: PackedStringArray = str(_args.get("only", "")).split(",", false)
	var out_moves := {}
	var names: Array = (_moves.moves as Dictionary).keys()
	names.sort()
	for mid: String in names:
		if not only.is_empty() and not only.has(mid):
			continue
		var m: Dictionary = _moves.moves[mid]
		var parts := _resolve_parts(mid, m)
		if parts.is_empty():
			_errors.append("move %s: no playable parts" % mid)
			continue
		# Hero annotation: parts whose survey path is replaced (the jump's flight is ballistic).
		for zi in m.get("align_zero_parts", []):
			if int(zi) < parts.size():
				parts[int(zi)]["align"] = "zero"
		# Hero annotation: a planted limb carries the align over a window of a part (the survey's
		# odometry drifted there), {"<part>": {"limb", "t": [t0, t1]}} in clip time.
		var aa: Dictionary = m.get("align_anchor_parts", {})
		for zk: String in aa:
			if int(zk) < parts.size():
				parts[int(zk)]["align_anchor"] = aa[zk]
		out_moves[mid] = _build_move(mid, m, parts)
	var loco := {}
	for k: String in _moves.loco:
		if _moves.loco[k] is Dictionary:
			var d: Dictionary = (_moves.loco[k] as Dictionary).duplicate()
			var a := _lib.get_animation(d.clip) if _lib.has_animation(d.clip) else null
			if a == null:
				_errors.append("loco clip missing: %s" % d.clip)
				continue
			d["length"] = a.length
			d["native_asset_id"] = str(a.get_meta("native_asset_id", ""))
			d["original_name"] = str(a.get_meta("original_name", d.clip))
			loco[k] = d
	parent.remove_child(inst)
	inst.free()
	return {
		"meta": {
			"schema": 1,
			"generator": "tools/traversal/build_runtime_table.gd",
			"godot_version": Engine.get_version_info().string,
			"inputs_sha256": {
				"traversal_moves.json": FileAccess.get_sha256(MOVES),
				"graph_traversal.json": FileAccess.get_sha256(GRAPH),
				"clip_geometry.json": FileAccess.get_sha256(GEOM),
				"clip_geometry_extra.json": FileAccess.get_sha256(GEOM_EXTRA),
				"contact_probes.json": FileAccess.get_sha256(TravContactProbes.PATH),
				"Actor_B.res": FileAccess.get_sha256(LIBRARY_RES),
			},
			"track_hz": _hz,
			"frame": "move frame at t = 0 (the character's start pose): +Z fwd, +X left, +Y up; tracks are clip time at rate 1",
			"points": "l/r_hand, l/r_foot, l/r_knee = the RENDERED palm / shoe sole / kneecap: lowest of the mesh-calibrated probe vertices (data/traversal/contact_probes.json), xz = soft-min centre; pelvis, head_top = headb + 0.13 m, l/r_heel, l/r_ball, l/r_elbow = bone origins (clearance); world = align + skeleton point",
			"align": "reference path of the skeleton origin: the clip survey's align samples (clip_geometry.json series), refined to track_hz by pinning the survey's anchor limb between its samples (a flight step is ballistic between its end samples); parts join with pelvis continuity",
			"contacts": "limb windows whose world speed stays below contact_speed (m/s) for >= 3 samples (gaps <= 2 samples merged); surface: support (feet before the first top contact at the start height), top (on the obstacle / ledge top), landing (feet after the last top release), wall (other feet: braced on a face), hang (hands on a lip, hang moves)",
		},
		"settings": _moves.settings,
		"moves": out_moves,
		"loco": loco,
		"transitions": _moves.transitions,
		"not_used": _moves.get("not_used", {}),
		"reason_codes": _moves.reason_codes,
	}


# --------------------------------------------------------------------------------------------------
# Chain resolution
# --------------------------------------------------------------------------------------------------

func _resolve_parts(mid: String, m: Dictionary) -> Array:
	var parts := []
	if m.has("parts"):
		for p: Dictionary in m.parts:
			var q := p.duplicate()
			q["status"] = str(m.get("status", "graph"))
			parts.append(q)
	elif m.has("graph"):
		var g: Dictionary = m.graph
		var chains: Dictionary = _graph.chains
		if not chains.has(g.entry):
			_errors.append("move %s: graph chain %s missing" % [mid, g.entry])
			return []
		var paths: Dictionary = chains[g.entry].paths
		var path: Array = paths.get(g.get("path", "run"), paths.values()[0])
		var incoming := {"request": null, "fade_s": 0.0, "record": null, "gate": null}
		for step: Dictionary in path:
			var clips: Variant = step.get("clips")
			if clips == null:
				break
			var cs := str((clips as Dictionary).get(g.get("mode", "run"), ""))
			if cs.begins_with("ladder overlay:"):
				if bool(g.get("stop_at_hub", false)):
					break
				cs = cs.trim_prefix("ladder overlay:").strip_edges()
			var clip := cs.get_slice(" (", 0).strip_edges()
			if clip.begins_with("MISSING"):
				if bool(g.get("skip_missing", false)):
					incoming = {"request": step.get("request"), "fade_s": float(step.get("fade_s", 0.0)),
							"record": step.get("record"), "gate": step.get("gate"), "skipped": str(step.state)}
					continue
				_errors.append("move %s: state %s has no Actor_B clip (%s)" % [mid, step.state, clip])
				return []
			parts.append({"clip": clip, "state": str(step.state), "request": incoming.request,
					"fade_s": float(incoming.fade_s) if parts.size() > 0 else 0.0, "record": incoming.record,
					"gate": incoming.gate, "status": "graph", "align": str(g.get("align", "survey"))})
			incoming = {"request": step.get("request"), "fade_s": float(step.get("fade_s", 0.0)),
					"record": step.get("record"), "gate": step.get("gate")}
			if step.get("to") == null:
				break
		if not parts.is_empty():
			var last: Dictionary = parts[parts.size() - 1]
			last["exit_record"] = {"to": null, "request": incoming.request, "fade_s": incoming.fade_s,
					"record": incoming.record, "gate": incoming.gate}
			for step: Dictionary in path:
				if str(step.get("state", "")) == str(last.state):
					last.exit_record["to"] = step.get("to")
	for p: Dictionary in parts:
		if not _lib.has_animation(p.clip):
			_errors.append("move %s: clip %s missing from the library" % [mid, p.clip])
			return []
	return parts


func _hub_records() -> Array:
	var out := []
	var st: Dictionary = _graph.states.get("ledge-grab", {})
	for r: Dictionary in st.get("transitions", []):
		var conds := []
		for c: Dictionary in r.get("conditions", []):
			conds.append({"mode": c.get("mode"), "min": c.get("min"), "max": c.get("max"), "variable": c.get("variable")})
		out.append({"record": r.record, "order": r.order, "request": r.request, "target": r.target,
				"fade_s": r.fade_s, "conditions": conds, "status": "graph"})
	return out


# --------------------------------------------------------------------------------------------------
# Tracks
# --------------------------------------------------------------------------------------------------

## Part-local align at time tau (clip time, forward playback) from the survey series.
func _series_align(clip: String, a: Animation, tau: float) -> Vector3:
	var c: Dictionary = _geom.clips.get(clip, {})
	var ser: Dictionary = c.get("series", {})
	var ts: Array = ser.get("t", [])
	if ts.size() < 2:
		return Vector3.ZERO
	var n := ts.size()
	var A := func(k: int) -> Vector3:
		return Vector3(float(ser.align_side[k]), float(ser.align_up[k]), float(ser.align_fwd[k]))
	if tau <= float(ts[0]):
		return A.call(0)
	var k := 0
	while k < n - 2 and tau > float(ts[k + 1]):
		k += 1
	var tk := float(ts[k])
	var tk1 := float(ts[k + 1])
	if tau > tk1:
		# Past the last sample (clip length beyond the series): hold the last align.
		return A.call(n - 1)
	var u := (tau - tk) / maxf(tk1 - tk, 1e-6)
	var ak: Vector3 = A.call(k)
	var ak1: Vector3 = A.call(k + 1)
	var anchors: Array = ser.get("anchor", [])
	var an := str(anchors[k]) if k < anchors.size() else "air"
	if an in LIMBS:
		var p: Vector3 = _sampler.points(a, tau)[an]
		var pk: Vector3 = _sampler.points(a, tk)[an]
		var pk1: Vector3 = _sampler.points(a, tk1)[an]
		var base := ak - (p - pk)
		var resid := ak1 - (ak - (pk1 - pk))
		return base + resid * u
	var lin := ak.lerp(ak1, u)
	lin.y += 0.5 * G * (tau - tk) * (tk1 - tau)
	return lin


func _build_move(mid: String, m: Dictionary, parts: Array) -> Dictionary:
	# A move's own clip_interpolation "cubic": its clips are sampled with cubic interpolation
	# through their keys (and must be played that way: TravPreviewActor); see
	# settings.clip_interpolation_note. Only clips no other move uses are marked so.
	if str(m.get("clip_interpolation", "")) == "cubic":
		var cn := PackedStringArray()
		for p0: Dictionary in parts:
			cn.append(str(p0.clip))
		TravInertializer.smooth_library_clips(_lib, cn)
	elif str(m.get("clip_interpolation", "")) == "hermite":
		# (A velocity-continuous resample of the move's clips, TravInertializer.resample_hermite:
		# sampled here as TravPreviewActor plays them.)
		var cn2 := PackedStringArray()
		for p0: Dictionary in parts:
			cn2.append(str(p0.clip))
		TravInertializer.resample_library_hermite(_lib, cn2)
	var track_points: Array = TRACK_POINTS + (GRIP_POINTS if str(m.get("class", "")) in GRIP_TRACK_CLASSES else [])
	# The move's own fist holes for its grip points (and a hand's anchored align).
	var grip_offs := {}
	var grip_tracks := {}
	var gd: Variant = _read_json(GRIPS) if str(m.get("class", "")) in GRIP_TRACK_CLASSES else null
	if gd is Dictionary and ((gd as Dictionary).get("moves", {}) as Dictionary).has(mid):
		var gm: Dictionary = gd.moves[mid]
		for limb: String in gm:
			var o: Array = (gm[limb] as Dictionary).offset
			grip_offs[limb] = Vector3(float(o[0]), float(o[1]), float(o[2]))
			if (gm[limb] as Dictionary).has("track"):
				grip_tracks[limb] = gm[limb].track
	_sampler.grip_offsets = grip_offs
	# Timeline.
	var t_start := 0.0
	var anims := []
	for p: Dictionary in parts:
		var a := _lib.get_animation(p.clip)
		anims.append(a)
		var hold := bool(p.get("hold", false))
		p["length"] = 0.0 if hold else a.length
		p["clip_length"] = a.length
		p["t0"] = t_start
		p["native_asset_id"] = str(a.get_meta("native_asset_id", ""))
		p["original_name"] = str(a.get_meta("original_name", p.clip))
		p["reverse"] = bool(p.get("reverse", false))
		t_start += float(p.length)
	var total := t_start
	var n := maxi(2, int(ceil(total * _hz - 1e-6)) + 1)
	if total <= 0.0:
		n = 1
	# Sample every part: skeleton points + part-local align; join parts with pelvis continuity.
	var align := PackedVector3Array()
	var pts := {}
	for nm in track_points:
		pts[nm] = []   # Array (reference type): a PackedVector3Array in a Dictionary is copied on access
	var offset := Vector3.ZERO
	var prev_part := -1
	var prev_end_world_pelvis := Vector3.ZERO
	var part_of := PackedInt32Array()
	for i in n:
		var t := minf(i / _hz, total)
		var pi := 0
		while pi < parts.size() - 1 and t >= float(parts[pi + 1].t0) - PART_EPS:
			pi += 1
		var p: Dictionary = parts[pi]
		var a: Animation = anims[pi]
		var lt := t - float(p.t0)
		if bool(p.get("hold", false)):
			lt = a.length
		var ct := (a.length - lt) if p.reverse else lt
		ct = clampf(ct, 0.0, a.length)
		var zero_align := bool(p.get("hold", false)) or str(p.get("align", "survey")) == "zero"
		var local_align := Vector3.ZERO if zero_align else _part_align(p, a, ct)
		if p.reverse and not zero_align:
			local_align = local_align - _series_align(p.clip, a, a.length)
		var sp := _sampler.points(a, ct)
		if pi != prev_part:
			# Part start: place the part so that its first pelvis continues the previous part's last.
			var start_align := Vector3.ZERO if (p.reverse or zero_align) else _series_align(p.clip, a, 0.0)
			if prev_part >= 0:
				offset = prev_end_world_pelvis - (start_align + (sp.pelvis as Vector3))
			prev_part = pi
		var al := offset + local_align
		align.append(al)
		part_of.append(pi)
		for nm in track_points:
			(pts[nm] as Array).append(al + (sp[nm] as Vector3))
		# Remember the last pelvis of this part (evaluated at its exact end).
		if pi < parts.size() - 1:
			var nt := minf((i + 1) / _hz, total)
			if nt >= float(parts[pi + 1].t0) - PART_EPS:
				var et := 0.0 if p.reverse else a.length
				var end_align := (_series_align(p.clip, a, et) - _series_align(p.clip, a, a.length)) if p.reverse else _part_align(p, a, et)
				if zero_align:
					end_align = Vector3.ZERO
				prev_end_world_pelvis = offset + end_align + (_sampler.points(a, et).pelvis as Vector3)
	# Part joins keep the pelvis position (above); the world pelvis velocity is made continuous
	# too: the next part's path gets the velocity difference as an offset that decays to zero
	# over JOIN_EASE_S (root inertialization of the reconstructed path; the parts' own align
	# paths were rebuilt separately, so their velocities disagree at the joins).
	for k in range(1, parts.size()):
		var is_ := int(ceil((float(parts[k].t0) - PART_EPS) * _hz))
		if is_ < 3 or is_ > n - 3:
			continue
		var pel: Array = pts.pelvis
		var v_prev: Vector3 = ((pel[is_ - 1] as Vector3) - (pel[is_ - 3] as Vector3)) * (_hz / 2.0)
		var v_next: Vector3 = ((pel[is_ + 2] as Vector3) - (pel[is_] as Vector3)) * (_hz / 2.0)
		var dv := v_prev - v_next
		if bool(parts[k].get("hold", false)):
			continue
		parts[k]["join_dv"] = snappedf(dv.length(), 0.001)
		for i in range(is_, n):
			var tau := (i - is_) / _hz
			if tau > JOIN_EASE_S:
				break
			var o := dv * tau * (1.0 - smoothstep(0.0, JOIN_EASE_S, tau))
			align[i] += o
			for nm in track_points:
				pts[nm][i] = (pts[nm][i] as Vector3) + o
	# Contacts.
	var times := PackedFloat32Array()
	for i in n:
		times.append(minf(i / _hz, total))
	for nm in track_points:
		pts[nm] = PackedVector3Array(pts[nm])
	var annotated := m.has("contacts_annotated")
	var windows := _annotated(m.contacts_annotated, pts, times) if annotated else _contacts(pts, times)
	var cls := _classify(mid, m, windows, pts, times, annotated)
	if m.has("flights_annotated"):
		cls.windows["flights"] = m.flights_annotated
	# Lip grips (design 8.4; user fix "hands miss the ledge"): for the moves that hang from or
	# pull up on a lip, the hand's own shape says where the lip's edge sits in it: the edge 2 cm
	# in front of the palm (toward the character), the top at the lowest hand point behind that
	# edge; fingers or a thumb curled down in front of it hang over the face. Stored per hand
	# contact as the contact point's offset from that edge (move frame): the warp puts the edge
	# on the real lip and the IK keeps it there.
	if str(m.get("class", "")) in GRIP_CLASSES:
		for c: Dictionary in cls.contacts:
			if c.kind != "hand" or not str(c.surface) in ["top", "hang"]:
				continue
			var im := int((int(c.i0) + int(c.i1)) / 2)
			var tm := times[im]
			var pk := 0
			while pk < parts.size() - 1 and tm >= float(parts[pk + 1].t0) - PART_EPS:
				pk += 1
			var pa: Dictionary = parts[pk]
			var an: Animation = anims[pk]
			var ct := clampf(tm - float(pa.t0), 0.0, an.length)
			if bool(pa.get("reverse", false)):
				ct = an.length - ct
			var g := _sampler.globals(an, ct)
			var probe := _sampler.probe_points(str(c.limb), g)
			if probe.is_empty():
				continue
			var palm: Vector3 = (g[_sampler.bone(str(c.limb).substr(0, 1) + "_palm")] as Transform3D).origin
			var ze := palm.z - GRIP_EDGE_M
			var ye := INF
			for v in probe:
				if v.z >= ze:
					ye = minf(ye, v.y)
			if ye == INF:
				continue
			var cpt: Vector3 = (pts[str(c.limb)] as PackedVector3Array)[im] - align[im]
			c["grip"] = {"dz": snappedf(cpt.z - ze, 0.0001), "dy": snappedf(cpt.y - ye, 0.0001)}
	# Part seams: skeleton-space pose distance (last pose of a part vs first pose of the next).
	# A seam the graph joins with a 0 s fade but whose poses differ by more than SEAM_POP_M gets a
	# short crossfade (override_seam_fade, labelled): the source would pop there.
	for k in range(1, parts.size()):
		var a0: Animation = anims[k - 1]
		var a1: Animation = anims[k]
		var e0 := a0.length if not bool(parts[k - 1].get("reverse", false)) else 0.0
		var d := _pose_distance(_sampler.points(a0, e0), _sampler.points(a1, a1.length if bool(parts[k].get("reverse", false)) else 0.0))
		parts[k]["seam_pose_distance"] = snappedf(d, 0.0001)
		if d > SEAM_POP_M and float(parts[k].get("fade_s", 0.0)) < SEAM_FADE_S:
			parts[k]["graph_fade_s"] = float(parts[k].get("fade_s", 0.0))
			parts[k]["fade_s"] = SEAM_FADE_S
			parts[k]["fade_status"] = "override (override_seam_fade: pose distance %.3f m at a 0 s graph seam)" % d
	# Speeds.
	var vin := _mean_vel(pts.pelvis, times, 0.0, 0.2)
	var vout := _mean_vel(pts.pelvis, times, maxf(0.0, total - 0.2), total)
	var track := {"hz": _hz, "n": n, "align": _flat(align)}
	for nm in track_points:
		track[nm] = _flat(pts[nm])
	var out := {
		"class": m.get("class", ""), "intent": m.get("intent", ""), "gait": m.get("gait", "any"),
		"stance": m.get("stance", "any"), "status": m.get("status", "graph"),
		"duration": total, "loop": bool(m.get("loop", false)), "hold": bool(m.get("hold_last_frame", false)),
		"parts": parts, "track": track, "contacts": cls.contacts, "anchor": cls.anchor, "windows": cls.windows,
		"entry_velocity": [vin.x, vin.y, vin.z], "exit_velocity": [vout.x, vout.y, vout.z],
		"entry_speed": Vector2(vin.x, vin.z).length(), "exit_speed": Vector2(vout.x, vout.z).length(),
		"end_align": [align[n - 1].x, align[n - 1].y, align[n - 1].z],
	}
	out["enabled"] = bool(m.get("enabled", true))
	if not grip_offs.is_empty():
		var go := {}
		for limb: String in grip_offs:
			var v: Vector3 = grip_offs[limb]
			go[limb] = [v.x, v.y, v.z]
		out["grip_offsets"] = go
	if not grip_tracks.is_empty():
		out["grip_tracks"] = grip_tracks
	_sampler.grip_offsets = {}
	# The authored obstacle height (traversal_moves.json authored_h / h_tol) sets the band and the
	# vertical warp limits relative to the reference top (design 7.1.2): the move only takes
	# obstacles within h_tol of the height its clip was made for.
	# h_tol_up (optional): a smaller upper tolerance for hand-planting moves, whose hand pops at
	# the plant above the authored height (user decision 2026-09-24: reject rather than pop). It
	# narrows the band (the obstacle's own height, at the foot of its face); the warp's vertical
	# limit dh keeps h_tol (on an upslope the top stands higher above the start than the obstacle
	# is tall).
	if m.has("authored_h") and cls.anchor.get("top_h") != null:
		var ah := float(m.authored_h)
		var tol := float(m.get("h_tol", 0.15))
		var tol_up := float(m.get("h_tol_up", tol))
		var th := float(cls.anchor.top_h) - float(cls.anchor.start_h)
		out["band"] = [ah - tol, ah + tol_up]
		out["dh"] = [ah - tol - th, ah + tol - th]
		out["authored_h"] = ah
		out["h_tol"] = tol
		if m.has("h_tol_up"):
			out["h_tol_up"] = tol_up
	# Locomotion phase matching (entry and exit pose continuity): the loop phase whose pose is
	# closest to the move's first / last pose, per loop. The preview syncs its loop phase to the
	# entry phase on the approach and starts the exit loop at the exit phase (hooks: LocoBrain).
	var a_first: Animation = anims[0]
	var a_last: Animation = anims[anims.size() - 1]
	var first_pose := _sampler.points(a_first, a_first.length if bool(parts[0].get("reverse", false)) else 0.0)
	var last_rev := bool(parts[parts.size() - 1].get("reverse", false))
	var last_pose := _sampler.points(a_last, 0.0 if last_rev else a_last.length)
	var lm := {"entry": {}, "exit": {}}
	for g: String in ["sprint", "run", "walk", "idle"]:
		var ld: Variant = (_moves.loco as Dictionary).get(g)
		if not ld is Dictionary or not _lib.has_animation(str(ld.clip)):
			continue
		var loop := _lib.get_animation(str(ld.clip))
		lm.entry[g] = _loop_match(loop, first_pose)
		lm.exit[g] = _loop_match(loop, last_pose)
	out["loco_match"] = lm
	# Standing exits (fix round 3, 2026-09-25): where the move's feet end against where the idle loop
	# (at its matched phase) has them, move frame xz. The capsule ends shifted by this, so the idle
	# pose's feet land where the move's are and the hand-back does not slide them (the standing
	# mantle's, the squeeze's, the shimmy's and the bottom dismount's end poses stand 7-8 cm in front
	# of their roots; the idle's feet are under it: a 4.5-5.7 cm skate of the standing feet).
	if str(m.get("exit", "")) == "idle" and lm.exit.has("idle"):
		var ld2: Dictionary = _moves.loco.get("idle", {})
		if _lib.has_animation(str(ld2.get("clip", ""))):
			var loop2 := _lib.get_animation(str(ld2.clip))
			var ip := _sampler.points(loop2, float(lm.exit.idle.phase) * loop2.length)
			var ic := ((ip.l_foot as Vector3) + (ip.r_foot as Vector3)) * 0.5
			var ec := ((last_pose.l_foot as Vector3) + (last_pose.r_foot as Vector3)) * 0.5
			out["exit_idle_shift"] = [snappedf(ec.x - ic.x, 0.0001), snappedf(ec.z - ic.z, 0.0001)]
	for k in ["authored_h_source", "annotation_note", "source", "contacts_annotated", "band", "band_moving_min", "dh", "depth_max", "deep_max", "hand_inset", "fade_in", "exit",
			"weapon_policy", "priority", "graph", "note", "gap_max", "landing_dh", "flight", "air_exit", "clip_interpolation",
			"limits_note", "band_note", "dh_note", "entry_rest", "entry_rest_note", "align_anchor_note", "clip_interpolation_note", "body_clear",
			"momentum"]:
		if m.has(k):
			out[k] = m[k]
	if m.has("air_exit"):
		var ae: Dictionary = (m.air_exit as Dictionary).duplicate()
		var aa := _lib.get_animation(str(ae.clip))
		if aa == null:
			_errors.append("move %s: air_exit clip %s missing" % [mid, ae.clip])
		else:
			ae["length"] = aa.length
			ae["native_asset_id"] = str(aa.get_meta("native_asset_id", ""))
			ae["original_name"] = str(aa.get_meta("original_name", ae.clip))
		out["air_exit"] = ae
	return out


static func _flat(a: PackedVector3Array) -> Array:
	var out := []
	for v in a:
		out.append(v.x)
		out.append(v.y)
		out.append(v.z)
	return out


static func _mean_vel(p: PackedVector3Array, t: PackedFloat32Array, t0: float, t1: float) -> Vector3:
	var i0 := 0
	var i1 := p.size() - 1
	for i in p.size():
		if t[i] <= t0 + 1e-6:
			i0 = i
		if t[i] <= t1 + 1e-6:
			i1 = i
	if i1 <= i0:
		return Vector3.ZERO
	return (p[i1] - p[i0]) / maxf(t[i1] - t[i0], 1e-6)


func _contacts(pts: Dictionary, times: PackedFloat32Array) -> Array:
	var out := []
	var n := times.size()
	for limb: String in LIMBS:
		var P: PackedVector3Array = pts[limb]
		var on := []
		for i in n:
			var i0 := maxi(0, i - 1)
			var i1 := mini(n - 1, i + 1)
			var dt := times[i1] - times[i0]
			var v := (P[i1] - P[i0]).length() / dt if dt > 1e-6 else 0.0
			on.append(v < _vcontact)
		# Merge gaps of <= 2 samples, drop runs shorter than 3 samples.
		var i := 0
		var runs := []
		while i < n:
			if not on[i]:
				i += 1
				continue
			var j := i
			while j + 1 < n and on[j + 1]:
				j += 1
			runs.append([i, j])
			i = j + 1
		var merged := []
		for r in runs:
			if not merged.is_empty() and r[0] - merged[merged.size() - 1][1] <= 3:
				merged[merged.size() - 1][1] = r[1]
			else:
				merged.append([r[0], r[1]])
		for r in merged:
			if r[1] - r[0] + 1 < 3:
				continue
			var ys := []
			var c := Vector3.ZERO
			for k in range(r[0], r[1] + 1):
				ys.append(P[k].y)
				c += P[k]
			c /= float(r[1] - r[0] + 1)
			ys.sort()
			var drift := 0.0
			for k in range(r[0], r[1] + 1):
				drift = maxf(drift, Vector2(P[k].x - P[r[0]].x, P[k].z - P[r[0]].z).length())
			out.append({"limb": limb, "kind": limb.substr(2), "i0": r[0], "i1": r[1], "t_on": times[r[0]], "t_off": times[r[1]],
					"pos": [c.x, ys[ys.size() / 2], c.z], "y_min": ys[0], "y_max": ys[ys.size() - 1], "slide": drift})
	out.sort_custom(func(x, y): return x.t_on < y.t_on or (x.t_on == y.t_on and str(x.limb) < str(y.limb)))
	return out


## The align of a part at clip time ct: the survey's, or inside an align_anchor window the one
## that keeps the anchor limb fixed (world = align + skeleton space), continued by the survey's
## increments after the window. align_anchor is one window {limb, t: [t0, t1]} or a list of them
## in time order (each window starts from where the align was left).
func _part_align(p: Dictionary, a: Animation, ct: float) -> Vector3:
	var sa := _series_align(p.clip, a, ct)
	if p.reverse or not p.has("align_anchor"):
		return sa
	var wins: Array = p.align_anchor if p.align_anchor is Array else [p.align_anchor]
	var off := Vector3.ZERO      # the align = the survey's + off outside the windows
	for an: Dictionary in wins:
		var t0 := float(an.t[0])
		var t1 := minf(float(an.t[1]), a.length)
		var limb := str(an.limb)
		if ct <= t0:
			return sa + off
		var s0 := _series_align(p.clip, a, t0) + off
		var l0: Vector3 = _sampler.points(a, t0)[limb]
		if ct <= t1:
			return s0 + l0 - (_sampler.points(a, ct)[limb] as Vector3)
		var held1 := s0 + l0 - (_sampler.points(a, t1)[limb] as Vector3)
		off = held1 - _series_align(p.clip, a, t1)
	return sa + off


## Hero annotations (design 8.4): [{limb, surface, t: [t_on, t_off]}] -> contact windows with
## the positions measured on the track (move time).
func _annotated(ann: Array, pts: Dictionary, times: PackedFloat32Array) -> Array:
	var out := []
	var n := times.size()
	for a: Dictionary in ann:
		var limb := str(a.limb)
		var P: PackedVector3Array = pts[limb]
		var i0 := clampi(int(round(float(a.t[0]) * _hz)), 0, n - 1)
		var i1 := clampi(int(round(float(a.t[1]) * _hz)), i0, n - 1)
		var ys := []
		var c := Vector3.ZERO
		var drift := 0.0
		for k in range(i0, i1 + 1):
			ys.append(P[k].y)
			c += P[k]
			drift = maxf(drift, Vector2(P[k].x - P[i0].x, P[k].z - P[i0].z).length())
		c /= float(i1 - i0 + 1)
		ys.sort()
		out.append({"limb": limb, "kind": limb.substr(2), "i0": i0, "i1": i1, "t_on": times[i0], "t_off": times[i1],
				"pos": [c.x, ys[ys.size() / 2], c.z], "y_min": ys[0], "y_max": ys[ys.size() - 1], "slide": drift,
				"surface": str(a.surface), "annotated": true})
	out.sort_custom(func(x, y): return x.t_on < y.t_on or (x.t_on == y.t_on and str(x.limb) < str(y.limb)))
	return out


## Skeleton-space pose distance between two point sets (relative to the pelvis).
static func _pose_distance(p0: Dictionary, p1: Dictionary) -> float:
	var worst := 0.0
	for nm in POSE_POINTS:
		worst = maxf(worst, ((p0[nm] as Vector3) - (p0.pelvis as Vector3)).distance_to((p1[nm] as Vector3) - (p1.pelvis as Vector3)))
	return worst


## Best-matching phase (0..1) of a locomotion loop for a pose: {phase, distance}.
func _loop_match(loop: Animation, pose: Dictionary) -> Dictionary:
	var best := {"phase": 0.0, "distance": INF}
	for k in 60:
		var ph := k / 60.0
		var d := _pose_distance(_sampler.points(loop, ph * loop.length), pose)
		if d < float(best.distance):
			best = {"phase": ph, "distance": snappedf(d, 0.0001)}
	return best


## Surface classes and the move's anchors (design 8.2 windows). Rules (heights relative to the
## start support; top_h = the first supporting hand contact above the start, or for step_on the
## first foot on the top, or for hang moves the highest hand group):
##   hand  top / hang : within 0.35 m of top_h;  ground : at the start height
##   knee  top        : within 0.2 m of top_h (the joint on the surface; slow knees elsewhere are free)
##   foot  support    : before the first top contact, at the start height
##         top        : within 0.3 m of top_h (standing / crouching on the top)
##         landing    : after the last top-hand release, below the top (OVER moves)
##         wall       : otherwise (braced on the face below the top)
## drop_to_hang (reversed climb-up): the lip is the start surface, so hands at the start height
## are the hang grip and feet below it are on the wall. catch / hub: feet are free (in the air or
## on rungs the lane places).
func _classify(mid: String, m: Dictionary, windows: Array, pts: Dictionary, times: PackedFloat32Array, annotated := false) -> Dictionary:
	var cls := str(m.get("class", ""))
	var start_h := 0.0
	var feet0 := []
	for w: Dictionary in windows:
		if w.kind == "foot" and float(w.t_on) <= 1e-6:
			feet0.append(float(w.pos[1]))
	if not feet0.is_empty():
		feet0.sort()
		start_h = feet0[0]
	else:
		var fl: PackedVector3Array = pts.l_foot
		var fr: PackedVector3Array = pts.r_foot
		start_h = minf(fl[0].y, fr[0].y)
	var hang_like := cls in ["hang", "hang_climb", "drop_to_hang", "catch", "hub"]
	var no_top := cls in ["ladder", "ladder_cycle", "beam", "crawl", "drop", "gap", "gap_long", "landing", "shimmy", "squeeze"]
	var top_h: Variant = null
	if annotated:
		for w: Dictionary in windows:
			if str(w.surface) in ["top", "hang"] and (top_h == null or w.kind == "hand"):
				top_h = float(w.pos[1])
				if w.kind == "hand":
					break
	elif cls == "drop_to_hang":
		top_h = start_h
	elif cls == "step_on":
		for w: Dictionary in windows:
			if w.kind == "foot" and float(w.pos[1]) > start_h + 0.3:
				top_h = float(w.pos[1])
				break
	elif not no_top:
		var best := -INF
		# Hang-like moves: the lip is where the hands first hold (the highest of the grips that
		# start within 0.25 s of the first one); later hand rests after a climb-up are not lips.
		var t_min := INF
		for w: Dictionary in windows:
			if w.kind == "hand" and float(w.pos[1]) > start_h + 0.3 and float(w.t_off) - float(w.t_on) >= 0.04:
				t_min = minf(t_min, float(w.t_on))
		for w: Dictionary in windows:
			if w.kind == "hand" and float(w.pos[1]) > start_h + 0.3 and float(w.t_off) - float(w.t_on) >= 0.04:
				if hang_like:
					if float(w.t_on) <= t_min + 0.25:
						best = maxf(best, float(w.pos[1]))
				elif top_h == null:
					top_h = float(w.pos[1])
		if hang_like and best > -INF:
			top_h = best
	var out := []
	for w: Dictionary in windows:
		var q := w.duplicate()
		var y := float(w.pos[1])
		var surf := "free"
		if annotated:
			out.append(q)
			continue
		if top_h != null:
			var th := float(top_h)
			if w.kind == "hand":
				if cls == "drop_to_hang":
					if absf(y - th) < 0.2:
						surf = "hang"
				elif cls == "step_on":
					surf = "free"
				elif absf(y - th) <= 0.35 and y > start_h + 0.3:
					surf = "hang" if hang_like else "top"
				elif absf(y - start_h) < 0.15:
					surf = "ground"
			elif w.kind == "knee":
				# The kneecap surface (mesh probes): on the top only within a few cm of it.
				if absf(y - th) <= 0.06:
					surf = "top"
		elif w.kind == "hand" and absf(y - start_h) < 0.15:
			surf = "ground"
		q["surface"] = surf
		out.append(q)
	var t_first := INF
	var t_release := -INF
	for q: Dictionary in out:
		if q.surface in ["top", "hang"]:
			t_first = minf(t_first, float(q.t_on))
		if q.kind == "hand" and q.surface in ["top", "hang"]:
			t_release = maxf(t_release, float(q.t_off))
	for q: Dictionary in out:
		if q.kind != "foot" or annotated:
			continue
		var y := float(q.pos[1])
		if cls in ["catch", "hub"]:
			q.surface = "free"
		elif cls == "drop_to_hang":
			q.surface = "support" if absf(y - start_h) < 0.15 else ("wall" if y < start_h - 0.3 else "free")
		elif top_h != null and cls == "step_on" and absf(y - float(top_h)) < 0.15:
			q.surface = "top"
		elif top_h != null and not hang_like and y > start_h + 0.3 and absf(y - float(top_h)) < 0.1:
			q.surface = "top"
		elif (t_first == INF or float(q.t_on) < t_first) and absf(y - start_h) < 0.15:
			q.surface = "support"
		elif m.get("intent", "") == "over" and t_release > -INF and float(q.t_on) >= t_release - 1e-6:
			q.surface = "landing"
		elif cls in ["landing", "shimmy", "squeeze", "beam", "crawl", "drop"]:
			# Ground moves: every planted foot is on the ground (the reference may drift).
			q.surface = "support"
		elif no_top:
			q.surface = "support" if absf(y - start_h) < 0.15 else "landing"
		elif top_h != null and cls == "hang_climb" and absf(y - float(top_h)) < 0.1:
			q.surface = "top"
		else:
			q.surface = "wall"
	# Windows (design 8.2).
	var takeoff := 0.0
	var landing: Variant = null
	var end_h: Variant = null
	for q: Dictionary in out:
		if q.kind == "foot" and q.surface == "support" and (t_first == INF or float(q.t_on) < t_first):
			takeoff = maxf(takeoff, float(q.t_off))
		if q.kind == "foot" and q.surface == "landing" and landing == null:
			landing = float(q.t_on)
			end_h = float(q.pos[1])
	# Primary contact: the earliest hand on the top / lip; else the earliest knee or foot on the top.
	var primary: Variant = null
	for kinds in [["hand"], ["knee", "foot"]]:
		for q: Dictionary in out:
			if q.surface in ["top", "hang"] and q.kind in kinds:
				if primary == null or float(q.t_on) < float((primary as Dictionary).t_on):
					primary = q
		if primary != null:
			break
	var last_foot_h: Variant = null
	var last_t := -1.0
	for q: Dictionary in out:
		if q.kind == "foot" and float(q.t_off) >= last_t:
			last_t = float(q.t_off)
			last_foot_h = float(q.pos[1])
	var anchor := {"start_h": start_h, "top_h": top_h, "end_h": end_h if end_h != null else last_foot_h,
			"last_foot_h": last_foot_h}
	if primary != null:
		var p: Dictionary = primary
		anchor["primary"] = {"limb": p.limb, "t": p.t_on, "t_off": p.t_off, "pos": p.pos, "surface": p.surface}
	# Flights: contact-free spans of >= 0.1 s between a support / wall contact and the next contact.
	var flights := []
	var busy := []
	busy.resize(times.size())
	busy.fill(false)
	for q: Dictionary in out:
		for k in range(int(q.i0), int(q.i1) + 1):
			busy[k] = true
	var k0 := -1
	for k in times.size():
		if not busy[k] and k0 < 0:
			k0 = k
		elif busy[k] and k0 >= 0:
			if k0 > 0 and times[k] - times[k0 - 1] >= 0.1:
				flights.append([times[k0 - 1], times[k]])
			k0 = -1
	var win := {"takeoff": takeoff, "first_support": t_first if t_first != INF else null,
			"release": t_release if t_release > -INF else null, "landing": landing, "flights": flights}
	return {"contacts": out, "anchor": anchor, "windows": win}


func _report(data: Dictionary) -> void:
	for mid: String in data.moves:
		var mv: Dictionary = data.moves[mid]
		var chain := []
		for p: Dictionary in mv.parts:
			chain.append(str(p.clip).trim_prefix("actor_b-") + ("(rev)" if p.reverse else ""))
		print("== %s  %.2f s  [%s]" % [mid, mv.duration, " > ".join(chain)])
		print("   anchor %s" % JSON.stringify(mv.anchor))
		print("   windows %s  entry %.2f exit %.2f m/s" % [JSON.stringify(mv.windows), mv.entry_speed, mv.exit_speed])
		for c: Dictionary in mv.contacts:
			print("     %-7s %-8s t %.3f-%.3f  pos (%.2f %.2f %.2f) y %.2f..%.2f slide %.3f" % [c.limb, c.surface,
					c.t_on, c.t_off, c.pos[0], c.pos[1], c.pos[2], c.y_min, c.y_max, c.slide])
