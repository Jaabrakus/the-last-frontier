extends SceneTree
## Measures where a rung sits in each closed fist of the ladder clips (contact pass 2026-09-25) and
## writes data/traversal/ladder_grips.json, which tools/traversal/build_runtime_table.gd reads:
##   per ladder move (runtime table class ladder / ladder_cycle / hub) and hand, the centre of the
##   fist's hole in the wrist bone's frame (median over the samples where the fist is closed, and
##   per sample: the lane puts the rung on the hole of the moment) and the hole's radius. The hole is the largest empty circle of the RENDERED hand (every vertex of
##   the body mesh's hand, CPU-skinned as CharacterBodyMesh draws it) projected along the rung's
##   axis (the skeleton's X: the ladder's rungs run across the character), searched near the
##   generic offset (TraversalIK.GRIP_OFFSET) and enclosed by the fingers on all sides.
##
##   Godot --headless --path . -s tools/traversal/measure_ladder_grips.gd -- [check] [report]

const OUT := "res://data/traversal/ladder_grips.json"
const CLASSES := ["ladder", "ladder_cycle", "hub"]
const HZ := 20.0
const CLOSED_R := 0.005          ## a hole at least this wide: a closed fist (the fingers squeeze to 0.6 cm on the fast cycles)
const SEARCH_M := 0.02           ## hole centres searched this far around the generic offset
const IDLE_MAX_S := 2.0          ## a looping hub clip is measured over its first seconds

var _args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		_args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	await process_frame
	var t0 := Time.get_ticks_msec()
	var rig := (load(TravPreviewActor.RIG) as PackedScene).instantiate() as Node3D
	root.add_child(rig)
	var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = rig.find_children("*", "AnimationPlayer", true, false)[0]
	ap.stop()
	BindRest.ensure(sk, ap, TravPreviewActor.LIB)
	var body := CharacterBodyMesh.attach(sk, ap)
	if body == null:
		printerr("measure_ladder_grips: no body mesh")
		quit(1)
		return
	var mc := TravMeshContacts.build(body)
	var sampler := TravClipSampler.from_skeleton(sk)
	var alib := ap.get_animation_library(TravPreviewActor.LIB)
	var lib := TravMoveLibrary.shared()
	var out := {}
	var ids: Array = lib.moves.keys()
	ids.sort()
	for id: String in ids:
		var m: Dictionary = lib.moves[id]
		if not str(m.get("class", "")) in CLASSES:
			continue
		var parts: Array = m.get("parts", [])
		if parts.size() != 1:
			continue
		var a := alib.get_animation(str((parts[0] as Dictionary).clip))
		if a == null:
			continue
		var entry := {}
		for side in ["l", "r"]:
			var limb: String = side + "_hand"
			var gen: Vector3 = TraversalIK.GRIP_OFFSET[limb]
			var xs := []
			var ys := []
			var zs := []
			var rs := []
			var track := []
			var n := int(ceil(minf(a.length, IDLE_MAX_S if bool(m.get("loop", false)) else a.length) * HZ)) + 1
			for i in n:
				var t := minf(i / HZ, a.length)
				var pose := sampler.pose(a, t)
				var g := mc.full_globals(pose)
				var pts := mc.skin(limb, g)
				var wr: Transform3D = pose[sk.find_bone(side + "_wrist")]
				var c0 := wr * gen
				var best := Vector2.ZERO
				var bestd := -1.0
				var q := PackedVector2Array()
				for v in pts:
					var d := Vector2(v.z - c0.z, v.y - c0.y)
					if d.length() < 0.07:
						q.append(d)
				# Coarse (2 mm) over the search square, then fine (0.5 mm) around the best.
				for pass_i in 2:
					var span := SEARCH_M if pass_i == 0 else 0.002
					var step := 0.002 if pass_i == 0 else 0.0005
					var cen := Vector2.ZERO if pass_i == 0 else best
					var cz := -span
					while cz <= span + 1e-6:
						var cy := -span
						while cy <= span + 1e-6:
							var c := cen + Vector2(cz, cy)
							var md := INF
							var seen := 0
							for d2: Vector2 in q:
								var dd := d2 - c
								var l := dd.length()
								md = minf(md, l)
								if l < 0.04:
									seen |= 1 << (int(floor((atan2(dd.y, dd.x) + PI) / (TAU / 8.0))) % 8)
							if seen == 255 and md > bestd:
								bestd = md
								best = c
							cy += step
						cz += step
				if bestd < CLOSED_R:
					continue
				var hole := Vector3(c0.x, c0.y + best.y, c0.z + best.x)
				var loc := wr.affine_inverse() * hole
				xs.append(loc.x)
				ys.append(loc.y)
				zs.append(loc.z)
				rs.append(bestd)
				track.append([snappedf(t, 0.001), snappedf(loc.x, 0.0001), snappedf(loc.y, 0.0001), snappedf(loc.z, 0.0001), snappedf(bestd, 0.0001)])
			if xs.is_empty():
				continue
			xs.sort()
			ys.sort()
			zs.sort()
			rs.sort()
			var k := xs.size() / 2
			entry[limb] = {"offset": [snappedf(xs[k], 0.0001), snappedf(ys[k], 0.0001), snappedf(zs[k], 0.0001)], "track": track,
					"hole_r_min": snappedf(rs[0], 0.0001), "hole_r_median": snappedf(rs[k], 0.0001), "samples": xs.size(),
					"spread_m": snappedf(Vector3(xs[xs.size() - 1] - xs[0], ys[ys.size() - 1] - ys[0], zs[zs.size() - 1] - zs[0]).length(), 0.0001)}
			if _args.has("report"):
				print("%-24s %s  offset %s  hole r %.4f..%.4f  spread %.4f (%d samples)" % [id, limb, str(entry[limb].offset), rs[0], rs[k], float(entry[limb].spread_m), xs.size()])
		if not entry.is_empty():
			out[id] = entry
	var data := {"meta": {"generator": "tools/traversal/measure_ladder_grips.gd", "hz": HZ, "closed_r": CLOSED_R,
			"frame": "offset: the fist hole's centre in the wrist bone's frame (skeleton units, m); median over the samples with a closed fist. track: [clip time, x, y, z, hole radius] per closed-fist sample (the centre moves up to 1 cm within a clip and the hole narrows to 0.6 cm where the fingers squeeze)",
			"body": CharacterBodyMesh.DEFAULT_PATH,
			"authorization": "owner-stated, see Player_Animation_Project/ASSET_AUTHORIZATION.md"},
			"moves": out}
	var text := JSON.stringify(data, " ", false) + "\n"
	if _args.has("check"):
		var old := FileAccess.get_file_as_string(OUT) if FileAccess.file_exists(OUT) else ""
		var same := old == text
		print("LADDER GRIPS %s" % ("OK (current)" if same else "FAILED (stale)"))
		quit(0 if same else 1)
		return
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("measure_ladder_grips: wrote %s (%d moves) in %.1f s" % [OUT, out.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	print("LADDER GRIPS OK")
	quit(0)
