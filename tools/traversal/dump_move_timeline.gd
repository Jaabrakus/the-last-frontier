extends SceneTree
## Prints a move's reference timeline from data/traversal/traversal_runtime.json (for the hero
## contact annotations in traversal_moves.json, design 8.4): per sample the part, the align
## height, the pelvis and each contact limb's height and speed (world, reference path), and the
## skeleton-space pose distance at every part seam (the same measure as tests/traversal/
## test_move_seams.gd).
##
##   Godot --headless --path . -s tools/traversal/dump_move_timeline.gd -- moves=a,b [hz=20]

const TABLE := "res://data/traversal/traversal_runtime.json"
const LIMBS := ["l_hand", "r_hand", "l_foot", "r_foot", "l_knee", "r_knee"]


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	var hz := float(args.get("hz", "20"))
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate()
	root.add_child(inst)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	BindRest.ensure(sk, ap)
	var sampler := TravClipSampler.from_skeleton(sk)
	var lib := ap.get_animation_library(&"actor_b")
	for mid in str(args.get("moves", "")).split(",", false):
		var m: Dictionary = table.moves[mid]
		var tr: Dictionary = m.track
		var n := int(tr.n)
		var thz := float(tr.hz)
		print("== %s  %.2f s  top_h %s" % [mid, float(m.duration), str(m.anchor.get("top_h"))])
		var parts: Array = m.parts
		for k in range(1, parts.size()):
			var a0 := lib.get_animation(str(parts[k - 1].clip))
			var a1 := lib.get_animation(str(parts[k].clip))
			var p0 := sampler.points(a0, a0.length)
			var p1 := sampler.points(a1, 0.0)
			var worst := 0.0
			var at := ""
			for nm in ["l_hand", "r_hand", "l_foot", "r_foot", "l_knee", "r_knee", "head_top", "l_elbow", "r_elbow"]:
				var d := ((p0[nm] as Vector3) - (p0.pelvis as Vector3)).distance_to((p1[nm] as Vector3) - (p1.pelvis as Vector3))
				if d > worst:
					worst = d
					at = nm
			print("   seam %d (%s -> %s) fade %.2f: pose distance %.3f m (%s)" % [k, str(parts[k - 1].clip).trim_prefix("actor_b-"),
					str(parts[k].clip).trim_prefix("actor_b-"), float(parts[k].get("fade_s", 0.0)), worst, at])
		var line := "   t     pt  align_y pelv_y "
		for l in LIMBS:
			line += " %-12s" % l
		print(line)
		var step := maxi(1, int(round(thz / hz)))
		var i := 0
		while i < n:
			var t := i / thz
			var pk := 0
			while pk < parts.size() - 1 and t >= float(parts[pk + 1].t0) - 1e-9:
				pk += 1
			var s := "   %.2f  %d  %6.2f  %6.2f " % [t, pk, float(tr.align[3 * i + 1]), float(tr.pelvis[3 * i + 1])]
			for l in LIMBS:
				var arr: Array = tr[l]
				var y := float(arr[3 * i + 1])
				var j0 := maxi(0, i - 1)
				var j1 := mini(n - 1, i + 1)
				var dp := Vector3(float(arr[3 * j1]) - float(arr[3 * j0]), float(arr[3 * j1 + 1]) - float(arr[3 * j0 + 1]),
						float(arr[3 * j1 + 2]) - float(arr[3 * j0 + 2])) / maxf((j1 - j0) / thz, 1e-6)
				s += " %5.2f/%-5.2f" % [y, dp.length()]
			print(s)
			i += step
	quit(0)
