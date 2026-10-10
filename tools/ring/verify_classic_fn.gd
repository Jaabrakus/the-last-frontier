extends SceneTree
## VERIFY (read-only reviewer probe, loadouts B1+B2): Classic reads exactly what HEAD's code read, function by function.
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/ring/verify_classic_fn.gd -- head_poses=<file> head_npc=<file>
## head_poses / head_npc: `git show HEAD:scripts/bending/bend_poses.gd` and `...npc/npc_bending.gd` with nothing changed (the probe
## strips their class_name and loads them as separate scripts: the oracle of what Classic read before the change).
## Compares, for every move and mode in the data, every element, a body with no meta, a body with a style meta while the master
## switch is off, and a body styled for another element:
##   BendPoses.pick / stance / guard_hold / animation / library_of (new) vs the HEAD copy
##   BendLoadout.spec / lock / wall_numbers: the very same dictionary / number the old reads gave
##   NpcBending.lock_for with and without `who` vs the HEAD copy
## Prints VCLASSIC lines; ends "VCLASSIC FN PASSED" or "... FAILED" (exit 0 only on a pass).

var checks := 0
var fails: Array[String] = []
var head_poses: GDScript


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL " + what)


func _load_copy(path: String, cn: String) -> GDScript:
	var src := FileAccess.get_file_as_string(path)
	if src == "":
		print("VCLASSIC cannot read %s" % path)
		return null
	src = src.replace("class_name %s\n" % cn, "")
	var s := GDScript.new()
	s.source_code = src
	var err := s.reload()
	if err != OK:
		print("VCLASSIC cannot compile the HEAD copy of %s (%d)" % [cn, err])
		return null
	return s


func _initialize() -> void:
	var hp := ""
	var hn := ""
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		match kv.get_slice("=", 0):
			"head_poses":
				hp = kv.get_slice("=", 1)
			"head_npc":
				hn = kv.get_slice("=", 1)
	head_poses = _load_copy(hp, "BendPoses")
	hn = hn                                  # (the HEAD NpcBending copy cannot compile on its own: its lock_for is copied below)
	_run.call_deferred()


func _sj(v: Variant) -> String:
	return JSON.stringify(v, "", true)


func _run() -> void:
	_expect(head_poses != null, "the HEAD BendPoses copy compiles")
	if head_poses == null:
		return _finish()
	# ---- the moves and modes in the data
	var ids: Array = SwayMoves.ids()
	var combos: Array = []
	var pd: Dictionary = BendPoses.data()
	for id: String in ids:
		var d := SwayMoves.move(id)
		var modes := {"": true}
		var bend0: Variant = d.get("bend", {})
		if bend0 is Dictionary:
			for k: Variant in (bend0 as Dictionary):
				modes[String(k)] = true
		for k: Variant in (d.get("mode_lock_s", {}) as Dictionary):
			modes[String(k)] = true
		for k: Variant in (d.get("modes", []) as Array):
			modes[String(k)] = true
		var pm: Variant = (pd.get("moves", {}) as Dictionary).get(id, {})
		if pm is Dictionary:
			for k: Variant in (pm as Dictionary):
				modes[String(k)] = true
		for m: String in modes:
			combos.append([id, m])
	print("VCLASSIC moves=%d move/mode pairs=%d" % [ids.size(), combos.size()])

	# ---- bodies
	var plain := Node3D.new()
	var styled_off := Node3D.new()
	styled_off.set_meta(BendLoadout.STYLE_META, "boxing")
	var styled := Node3D.new()
	styled.set_meta(BendLoadout.STYLE_META, "boxing")
	var cap := Node3D.new()
	cap.set_meta(BendLoadout.STYLE_META, "capoeira")
	root.add_child(plain)
	root.add_child(styled_off)
	root.add_child(styled)
	root.add_child(cap)
	var els: Array = ["", "earth", "water", "fire", "air"]

	# ---- BendPoses.pick: HEAD vs now (switch ON, nothing worn; and OFF with a style meta on the body)
	var diffs := 0
	var nonempty := 0
	for pair: Array in combos:
		for el: String in els:
			var want: Variant = head_poses.call(&"pick", pair[0], pair[1], el)
			var ws := _sj(want)
			if not (want as Dictionary).is_empty():
				nonempty += 1
			for body: Variant in [null, plain, cap]:
				var got: Variant = BendPoses.pick(pair[0], pair[1], el, body)
				if _sj(got) != ws:
					diffs += 1
					print("  DIFF pick %s/%s %s body=%s" % [pair[0], pair[1], el, body])
			# a styled body: for any element but fire, or with the master switch off, the element's own
			if el != "fire":
				if _sj(BendPoses.pick(pair[0], pair[1], el, styled)) != ws:
					diffs += 1
					print("  DIFF pick (styled, not fire) %s/%s %s" % [pair[0], pair[1], el])
	_expect(diffs == 0, "ON, nothing worn: BendPoses.pick == HEAD for %d pairs x %d elements (%d non-empty picks), %d diffs" % [combos.size(), els.size(), nonempty, diffs])
	print("VCLASSIC pick: %d non-empty picks compared, %d diffs (switch on, no style)" % [nonempty, diffs])
	BendLoadout.config_override = {"enabled": false}
	var d2 := 0
	for pair: Array in combos:
		for el: String in els:
			var ws2 := _sj(head_poses.call(&"pick", pair[0], pair[1], el))
			if _sj(BendPoses.pick(pair[0], pair[1], el, styled_off)) != ws2 or _sj(BendPoses.pick(pair[0], pair[1], el, styled)) != ws2:
				d2 += 1
				print("  DIFF pick (switch off) %s/%s %s" % [pair[0], pair[1], el])
	_expect(d2 == 0, "switch OFF, style meta on the body: BendPoses.pick == HEAD (%d diffs)" % d2)
	print("VCLASSIC pick (switch off, styled body): %d diffs" % d2)
	# stance and guard hold
	var d3 := 0
	for el: String in els:
		var st_head: Variant = (head_poses.call(&"data").get("stance", {}) as Dictionary).get(el, "")
		var gh: Variant = head_poses.call(&"data").get("guard_hold", {})
		var gh_head: Variant = (gh as Dictionary).get(el, "") if gh is Dictionary else ""
		for body: Variant in [null, plain, styled_off, styled]:
			if _sj(BendPoses.stance_pose(el, body)) != _sj(st_head) or _sj(BendPoses.guard_hold_pose(el, body)) != _sj(gh_head):
				d3 += 1
				print("  DIFF stance/guard %s body=%s" % [el, body])
		_expect(SwayPose.stance_name(el) == SwayPose.stance_name(el, plain), "stance_name(%s) same with a plain body" % el)
	_expect(d3 == 0, "stance_pose / guard_hold_pose == HEAD's table read (%d diffs, switch off)" % d3)
	BendLoadout.config_override = {}
	var d4 := 0
	for el: String in els:
		var st_head2: Variant = (head_poses.call(&"data").get("stance", {}) as Dictionary).get(el, "")
		for body: Variant in [null, plain, cap]:
			if _sj(BendPoses.stance_pose(el, body)) != _sj(st_head2):
				d4 += 1
	_expect(d4 == 0, "stance_pose == HEAD's table read (switch on, no style): %d diffs" % d4)
	# animation / library_of / all_clips
	var clips_head: Array = head_poses.call(&"all_clips")
	var clips_new: Array = BendPoses.all_clips()
	_expect(_sj(clips_head) == _sj(clips_new), "BendPoses.all_clips() == HEAD's (%d clips)" % clips_new.size())
	var d5 := 0
	var names: Array = []
	for c0: Variant in clips_head:
		names.append(String(c0))
	names.append_array(["", "nope", "own-bend-nothing-here"])
	for nm: Variant in names:
		var ah: Variant = head_poses.call(&"animation", String(nm))
		var an: Variant = BendPoses.animation(String(nm))
		if (ah == null) != (an == null) or (ah != null and ah.length != an.length):
			d5 += 1
		if String(head_poses.call(&"library_of", String(nm))) != BendPoses.library_of(String(nm)):
			d5 += 1
		if bool(head_poses.call(&"usable", String(nm))) != BendPoses.usable(String(nm)):
			d5 += 1
	_expect(d5 == 0, "animation / library_of / usable == HEAD's for every clip name (%d diffs)" % d5)
	_expect(not BendPoses._libs.has("res://animations_extra/Frontier_Style_Boxing.res"), "none of the Classic reads loaded the Boxing library")

	# ---- BendLoadout seams: identity for a body that wears nothing, switch on and off
	var fm := preload("res://scripts/sway/form_matter.gd")
	for sw: Array in [[{}, "ON"], [{"enabled": false}, "OFF"]]:
		BendLoadout.config_override = sw[0]
		var bad := 0
		var n := 0
		for id: String in ids:
			var d := SwayMoves.move(id)
			var bend: Variant = d.get("bend", {})
			if bend is Dictionary:
				for mode: Variant in (bend as Dictionary):
					var base: Variant = (bend as Dictionary)[mode]
					if not (base is Dictionary):
						continue
					n += 1
					for body: Variant in [null, plain, styled]:
						if not is_same(BendLoadout.spec(body, id, String(mode), base), base):
							bad += 1
							print("  DIFF spec identity %s/%s" % [id, mode])
			var mlk: Dictionary = d.get("mode_lock_s", {})
			var lock_modes: Array = mlk.keys()
			lock_modes.append("")
			for mode: Variant in lock_modes:
				for body: Variant in [null, plain, styled]:
					if BendLoadout.lock(body, id, String(mode), 0.1234) != 0.1234:
						bad += 1
		var wd: Dictionary = SwayMoves.move("earth_wall").get("wall", {})
		for matter: String in ["earth", "mud", "stone", "snow", "wood", "nonsense"]:
			for kind: String in ["wall", "ice"]:
				for body: Variant in [null, plain, styled]:
					if _sj(BendLoadout.wall_numbers(body, kind, wd, matter)) != _sj(fm.numbers(wd, fm.entry("earth_wall", matter), matter)):
						bad += 1
						print("  DIFF wall_numbers %s %s" % [kind, matter])
		_expect(bad == 0, "switch %s, nothing worn: spec is the same dictionary (%d specs), lock the same number, wall numbers FormMatter's (%d diffs)" % [sw[1], n, bad])
		print("VCLASSIC seams (%s): %d specs, %d diffs" % [sw[1], n, bad])
	BendLoadout.config_override = {}

	# ---- NpcBending.lock_for: HEAD's copy vs now
	if true:
		var d6 := 0
		var cnt := 0
		for pair: Array in combos:
			if SwayMoves.move(pair[0]).is_empty():
				continue
			for pr: String in ["easy", "normal", "hard", "nonexistent"]:
				for dist: float in [0.0, 2.5, 7.0, 15.0, 40.0]:
					cnt += 1
					var want_l: float = _head_lock_for(pair[0], pair[1], pr, dist)
					for who: Variant in [null, plain, styled]:
						var got_l: float = NpcBending.lock_for(pair[0], pair[1], pr, dist, who)
						if not is_equal_approx(got_l, want_l) or got_l != want_l:
							d6 += 1
							print("  DIFF lock_for %s/%s %s %.1f: %f vs HEAD %f" % [pair[0], pair[1], pr, dist, got_l, want_l])
		_expect(d6 == 0, "NpcBending.lock_for (with and without a body) == HEAD's, bit for bit, over %d cases (%d diffs)" % [cnt, d6])
		print("VCLASSIC lock_for: %d cases, %d diffs" % [cnt, d6])
	# ---- cost: Classic's hot reads, now against HEAD's
	var iters := 100000
	var t0 := Time.get_ticks_usec()
	for i in iters:
		_head_lock_for("air_blast", "ball", "normal", 3.0)
	var t_head := Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for i in iters:
		NpcBending.lock_for("air_blast", "ball", "normal", 3.0, plain)
	var t_new := Time.get_ticks_usec() - t0
	print("VCLASSIC cost lock_for x%d: HEAD %.1f ms, now %.1f ms (%.2f us extra per call)" % [iters, t_head / 1000.0, t_new / 1000.0, float(t_new - t_head) / iters])
	var it2 := 20000
	t0 = Time.get_ticks_usec()
	for i in it2:
		head_poses.call(&"pick", "fire_jab", "embers", "fire")
	t_head = Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for i in it2:
		BendPoses.pick("fire_jab", "embers", "fire", plain)
	t_new = Time.get_ticks_usec() - t0
	print("VCLASSIC cost pick x%d: HEAD %.1f ms, now %.1f ms (%.2f us extra per call)" % [it2, t_head / 1000.0, t_new / 1000.0, float(t_new - t_head) / it2])
	t0 = Time.get_ticks_usec()
	for i in it2:
		BendPoses.style_of(plain, "fire")
	print("VCLASSIC cost style_of(no meta) x%d: %.2f ms" % [it2, (Time.get_ticks_usec() - t0) / 1000.0])
	_finish()


## HEAD's NpcBending.lock_for (git show HEAD:scripts/npc/npc_bending.gd, line 465), line for line; its helpers are the live class's own
## (self_cast, range_of, preset_of: unchanged by the change).
func _head_lock_for(id: String, md: String, preset_name := "hard", dist := 0.0) -> float:
	var d := SwayMoves.move(id)
	var base := float(d.get("lock_s", 1.0))
	var mlk: Dictionary = d.get("mode_lock_s", {})
	if id == "gust" and md == "lift":
		base = float((d.get("stone", {}) as Dictionary).get("lock_s", base))
	elif mlk.has(md):
		base = float(mlk[md])
	var stretch := 1.0
	if not NpcBending.self_cast(id, md):
		var r := NpcBending.range_of(id, md)
		stretch = lerpf(1.0, float(d.get("far_stretch", 1.0)), smoothstep(r * 0.5, r, dist))
	var lm: Array = (SwayMoves.data().get("mastery", {}) as Dictionary).get("lock_mult", [1.4, 1.0, 0.8])
	var tier := 2 if SwayCaster.free_use() else 1
	var tm := float(lm[clampi(tier, 0, lm.size() - 1)]) if not lm.is_empty() else 1.0
	var pr := NpcBending.preset_of(preset_name)
	var mult := float(pr.get("lock_mult", 1.0))
	if bool(pr.get("ai_factor", false)):
		mult *= float(d.get("ai_factor", 1.0))
	return maxf(base * stretch * tm * mult, 0.05)


func _finish() -> void:
	BendLoadout.config_override = {}
	print("VCLASSIC FN %s (%d checks, %d failed)" % ["PASSED" if fails.is_empty() and checks > 0 else "FAILED", checks, fails.size()])
	quit(0 if fails.is_empty() and checks > 0 else 1)
