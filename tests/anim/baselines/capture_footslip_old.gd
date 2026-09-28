extends SceneTree
## Captures tests/anim/baselines/footslip_old.json: planted-foot slip of the OLD hand-built
## AnimationTree (scripts/player/player_anim.gd before WP6) on the real level, for the plan's
## section 10 cases (W / A / S / D / W+A for walk / run / crouch; W / W+A / W+D for sprint), per
## weapon. The method and protocol are FootSlip.measure() (tests/anim/lib/foot_slip.gd), the same
## code the new tree's test_locomotion_feet uses, so the numbers compare directly: every repeat
## starts from a freshly loaded level, repeat 0 goes straight into the case, repeats 1-4 first
## play a fixed pre-roll history; median_mps is the median of the repeat medians, min/max the
## spread. Results do not depend on the order cases run in.
##
##   Godot --headless --fixed-fps 120 --path . -s tests/anim/baselines/capture_footslip_old.gd -- --no-capture
##   Godot --headless --path . -s tests/anim/baselines/capture_footslip_old.gd -- --no-capture realtime=1 weapons=musket
## The first run fills "cases" (fixed step, bit-reproducible); the second adds a real-time
## "realtime" cross-check (fresh repeat only unless repeats=<n>) to the same file.
## Options: weapons=musket,bow,pistol  repeats=<n>  out=<path>  force=1.
##
## Every entry also gets the ideal-playback floor of its case (FootSlip.ideal_floor(): what the
## same measurement reads for perfect, graph-faithful playback at the section 6.6 rate): ideal_mps
## (median over start phases), ideal_min_mps / ideal_max_mps, ideal_godot_mps for blended cases
## (the same bank blended the Godot BlendSpace1D way), and the details under "ideal". The floor
## does not depend on the tree, so
##   Godot --headless --path . -s tests/anim/baselines/capture_footslip_old.gd -- --no-capture ideal_only=1
## (re)computes only these fields in the existing file, with any tree in place (with or without
## --fixed-fps), and leaves the measured values alone.
##
## It refuses to run when PlayerAnim no longer has the old nodes (upper_mix, relax_layer), so the
## baseline is never overwritten with new-tree numbers. A file written by an older protocol is
## replaced, not merged.

const OUT := "res://tests/anim/baselines/footslip_old.json"
const PROTOCOL := "FootSlip.measure v2: fresh level per repeat; repeat 0 fresh, repeats 1-4 after prerolls(c)"
## Keys whose values are counts (JSON.parse_string returns every number as float).
const INT_KEYS := ["n", "updates", "frames_with_multiple_updates", "physics_hz", "anim_callback_mode_process",
		"cases", "realtime", "spawn_frames", "equip_frames"]

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0).trim_prefix("--")] = a.substr(a.find("=") + 1)
	var out_path: String = args.get("out", OUT)
	if args.get("ideal_only", "0") == "1":
		await process_frame
		quit(await _ideal_only(out_path))
		return
	var weapons := String(args.get("weapons", "musket,bow,pistol")).split(",")
	var realtime: bool = args.get("realtime", "0") == "1"
	var repeats := int(args.get("repeats", 1 if realtime else FootSlip.REPEATS))
	await process_frame
	var fast := await AnimTestContext.faster_than_realtime(self)
	if realtime == fast:
		printerr("FAIL: run %s --fixed-fps 120 (realtime=%s)" % ["without" if realtime else "with", realtime])
		quit(2)
		return

	var player := await FootSlip.fresh_player(self)
	if player == null:
		printerr("FAIL: level or player failed to load")
		quit(1)
		return
	var anim: AnimationTree = player.anim
	var old_tree: bool = anim.tree_root is AnimationNodeBlendTree and anim.tree_root.has_node("upper_mix") \
			and anim.tree_root.has_node("relax_layer")
	if not old_tree and args.get("force", "0") != "1":
		printerr("FAIL: PlayerAnim is not the old tree (no upper_mix / relax_layer); refusing to overwrite the baseline")
		quit(1)
		return
	var meta := _meta(anim, old_tree)

	var data := {}
	if FileAccess.file_exists(out_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(out_path))
		if parsed is Dictionary and parsed.get("meta", {}).get("protocol", "") == PROTOCOL:
			data = parsed
		else:
			print("replacing %s (older protocol)" % out_path)
	var section := "realtime" if realtime else "cases"
	if not data.has(section):
		data[section] = {}
	var errors := 0
	var t_start := Time.get_ticks_msec()
	# Control: standing still; planted feet should not move (checks the method, not the tree).
	var control := {"key": "control/idle", "mode": "run", "dir": "none", "actions": []}
	for w in weapons:
		for c in [control] + FootSlip.cases():
			var r := await FootSlip.measure(self, c, {"weapon": w, "repeats": repeats})
			var key := "%s/%s" % [w, c.key]
			if r.has("error"):
				errors += 1
				printerr("  %-18s ERROR %s" % [key, r.error])
				continue
			r.erase("key")
			r.merge(_ideal(current_scene.get_node_or_null("Player") if current_scene else null, c, w), true)
			data[section][key] = r
			print("  %-18s median %.3f  fresh %.3f  range %.3f..%.3f  p90 %.3f  n %5d  planted %.2f  body %.2f m/s  %s  ideal %s%s" % [
					key, r.median_mps, r.fresh_mps, r.min_mps, r.max_mps, r.p90_mps, r.n, r.planted_frac,
					r.body_speed_mps, "crouch" if r.crouched else ("sprint" if r.sprinting else ("walk" if r.walking else "run")),
					"%.3f" % r.ideal_mps if r.has("ideal_mps") else "-",
					("  WARNING " + r.warning) if r.has("warning") else ""])
	# Order independence: the first case again, after everything else ran.
	if not weapons.is_empty() and errors == 0:
		var first: Dictionary = FootSlip.cases()[0]
		var again := await FootSlip.measure(self, first, {"weapon": weapons[0], "repeats": repeats})
		var k0 := "%s/%s" % [weapons[0], first.key]
		var before: Dictionary = data[section][k0]
		var same: bool = again.get("median_mps") == before.median_mps and again.get("min_mps") == before.min_mps \
				and again.get("max_mps") == before.max_mps
		meta["order_check_" + section] = {"key": k0, "first": [before.median_mps, before.min_mps, before.max_mps],
				"again_last": [again.get("median_mps"), again.get("min_mps"), again.get("max_mps")], "identical": same}
		print("order check %s: first %.4f [%.4f..%.4f], again after all cases %.4f [%.4f..%.4f] -> %s" % [k0,
				before.median_mps, before.min_mps, before.max_mps, again.get("median_mps", NAN), again.get("min_mps", NAN),
				again.get("max_mps", NAN), "identical" if same else "DIFFERENT"])
		if not same and not realtime:
			errors += 1
	# Per-section entries of the other section survive a run of this one.
	var old_meta: Dictionary = data.get("meta", {})
	for k in old_meta:
		if String(k).begins_with("order_check_") and not meta.has(k):
			meta[k] = old_meta[k]
	meta["repeats_per_case"] = old_meta.get("repeats_per_case", {}).duplicate()
	meta.repeats_per_case[section] = repeats
	meta["ideal"] = _ideal_meta()
	data["meta"] = meta
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(_ints(data), " ", true) + "\n")
	f.close()
	print("wrote %s (%s: %d cases, %d errors, %.0f s)" % [out_path, section, data[section].size(), errors,
			(Time.get_ticks_msec() - t_start) / 1000.0])
	if realtime and data.has("cases"):
		var d := []
		for k in data.realtime:
			if data.cases.has(k):
				d.append(absf(float(data.realtime[k].fresh_mps) - float(data.cases[k].fresh_mps)))
		d.sort()
		if not d.is_empty():
			print("realtime vs fixed-step fresh-repeat median slip: |diff| median %.3f, max %.3f m/s over %d cases" % [
					d[d.size() / 2], d[-1], d.size()])
	print("FOOTSLIP BASELINE %s" % ("CAPTURED" if errors == 0 else "INCOMPLETE"))
	quit(0 if errors == 0 else 1)


## Ideal-playback floor fields for case c with weapon w on player p (see the header).
func _ideal(p: Node, c: Dictionary, w: String) -> Dictionary:
	if p == null:
		return {"ideal_error": "no player"}
	var o := FootSlip.oracle_for(p)
	var speed := FootSlip.case_speed(p, c)
	var g := FootSlip.ideal_floor(o, c, speed, {"weapon": w})
	var out := FootSlip.ideal_fields(g)
	if g.has("weights") and Array(g.weights).filter(func(x): return x > 0.0).size() > 1:
		var gd := FootSlip.ideal_floor(o, c, speed, {"weapon": w, "semantics": "godot"})
		if gd.has("ideal_mps"):
			out["ideal_godot_mps"] = gd.ideal_mps
	return out


func _ideal_meta() -> Dictionary:
	var speeds := {}
	for k in FootSlip._travel:
		speeds[k] = FootSlip._travel[k]
	return {
		"function": "FootSlip.ideal_floor (tests/anim/lib/foot_slip.gd)",
		"method": "what FootSlip.result() reads for perfect, graph-faithful playback: the case's section 6.5 direction bank "
				+ "(graph roles of the weapon; hemisphere fw iff |deg| <= 90) blended by the graph slerp chain, every clip at one "
				+ "normalized phase advancing at the section 6.6 rate (ratio = speed / sum w_i v_i clamped to [%.2f, %.2f]), " % [FootSlip.RATIO_MIN, FootSlip.RATIO_MAX]
				+ "body at the case's target speed (player.gd speeds x weapon.speed_mult(), sprint without it) along the case "
				+ "direction; %d start phases of the %.1f s window, ideal_mps = their median. " % [FootSlip.IDEAL_PHASES, FootSlip.MEASURE_S]
				+ "ideal_godot_mps: the same with the bank blended the Godot BlendSpace1D way (rest-relative). "
				+ "lib/selftest/st_footslip_ideal checks that the in-game measurement of a perfect one-clip tree lands in [ideal_min, ideal_max] +- 0.02.",
		"clip_speed_source": "animations/actor_b_clip_metrics.json" if FileAccess.file_exists(FootSlip.METRICS_JSON)
				else "FootSlip.clip_travel (GA/vmm/bl/an.py method A at %.0f Hz, as the plan's section 2 speeds)" % FootSlip.TRAVEL_HZ,
		"clip_travel": speeds,
		"gate_note": "threshold_new_tree_mps (0.15, plan section 10) is below ideal_mps for several cases (run W/A/D/S at "
				+ "bow and pistol speed, sprint W, crouch D, the run and sprint diagonals), so perfect playback cannot pass it there. "
				+ "A reviewed gate relative to ideal_mps is an open orchestrator decision; see tests/anim/README.md.",
		"computed": Time.get_date_string_from_system(),
	}


## ideal_only=1: (re)computes the ideal-floor fields of every entry of the existing file. The
## measured values and the rest of meta stay as they are. Returns the exit code.
func _ideal_only(out_path: String) -> int:
	if not FileAccess.file_exists(out_path):
		printerr("FAIL: %s does not exist" % out_path)
		return 1
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(out_path))
	if not data is Dictionary or data.get("meta", {}).get("protocol", "") != PROTOCOL:
		printerr("FAIL: %s was not written by protocol %s" % [out_path, PROTOCOL])
		return 1
	var players := {}
	var errors := 0
	for section in ["cases", "realtime"]:
		for key: String in data.get(section, {}):
			var parts := key.split("/")
			var w := parts[0]
			var c := {"key": parts[1] + "/" + parts[2], "mode": parts[1], "dir": parts[2] if parts[1] != "control" else "none",
					"actions": FootSlip.DIRS.get(parts[2], [])}
			if not players.has(w):
				players.clear()
				players[w] = await FootSlip.fresh_player(self, w)
			var entry: Dictionary = data[section][key]
			for k in entry.keys():
				if String(k).begins_with("ideal"):
					entry.erase(k)
			var f := _ideal(players[w], c, w)
			if f.has("ideal_error"):
				errors += 1
				printerr("  %-18s ideal ERROR %s" % [key, f.ideal_error])
			entry.merge(f, true)
			if entry.has("ideal_mps"):
				print("  %-9s %-18s ideal %.3f [%.3f..%.3f]%s   measured median %.3f" % [section, key, entry.ideal_mps,
						entry.ideal_min_mps, entry.ideal_max_mps, "  godot-blend %.3f" % entry.ideal_godot_mps if entry.has("ideal_godot_mps") else "",
						entry.median_mps])
	data.meta["ideal"] = _ideal_meta()
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(_ints(data), " ", true) + "\n")
	file.close()
	if current_scene:
		unload_current_scene()
	print("wrote ideal floors into %s (%d errors)" % [out_path, errors])
	print("FOOTSLIP IDEAL %s" % ("DONE" if errors == 0 else "INCOMPLETE"))
	return 0 if errors == 0 else 1


func _meta(anim: AnimationTree, old_tree: bool) -> Dictionary:
	return {
		"generator": "tests/anim/baselines/capture_footslip_old.gd (WPT)",
		"protocol": PROTOCOL,
		"tree": "old hand-built PlayerAnim AnimationTree (scripts/player/player_anim.gd before WP6)" if old_tree \
				else "NOT the old tree (force=1)",
		"player_anim_gd_sha256": FileAccess.get_sha256("res://scripts/player/player_anim.gd"),
		"player_gd_sha256": FileAccess.get_sha256("res://scripts/player/player.gd"),
		"library_sha256": FileAccess.get_sha256("res://animations/Actor_B.res"),
		"godot_version": Engine.get_version_info().string,
		"physics_hz": Engine.physics_ticks_per_second,
		"cases_stepping": "--fixed-fps 120: one process frame per physics tick, faster than real time",
		"realtime_stepping": "no --fixed-fps: real-time main loop (only in the 'realtime' section; fresh repeat only by default)",
		"anim_callback_mode_process": anim.callback_mode_process,
		"level": "res://scenes/main.tscn, reloaded for every repeat; flat range lane, travel toward -Z; corridor checked free of colliders",
		"method": "FootSlip (tests/anim/lib/foot_slip.gd): l/r heel and ball sampled at every pose update in Skeleton3D.skeleton_updated; "
				+ "foot world velocity = body velocity + d(foot offset from the body, world axes)/process delta (continuous-time slip); "
				+ "planted = world height within %.2f m of the point's minimum over the window, at both ends of the interval; " % FootSlip.PLANTED_TOL
				+ "stats over all four points.",
		"repeat_protocol": "each repeat: reload level, wait %d physics frames, switch_weapon, wait %d; " % [FootSlip.SPAWN_FRAMES, FootSlip.EQUIP_FRAMES]
				+ "repeat 0 runs the case directly (fresh_mps); repeat k>0 first runs FootSlip.prerolls(case)[k-1] "
				+ "(same mode 45 deg to one side 0.7 s, to the other side 1.3 s, the case itself 1.1 s then a stop, the next mode 0.9 s). "
				+ "median_mps = median of the repeat medians (plan section 10 metric); min_mps / max_mps / spread_mps = range over repeats.",
		"timing_s": {"idle": FootSlip.IDLE_S, "settle": FootSlip.SETTLE_S, "measure": FootSlip.MEASURE_S},
		"spawn_frames": FootSlip.SPAWN_FRAMES,
		"equip_frames": FootSlip.EQUIP_FRAMES,
		"keys": "<weapon>/<mode>/<dir>: mode walk (hold walk) / run / crouch (toggle) / sprint (hold sprint); dir W A S D WA WD. "
				+ "<weapon>/control/idle = standing still (after the pre-rolls for repeats 1-4), a check of the method (expected ~0).",
		"weapons_note": "Only the lower body matters here. Bow and pistol move at speed_mult 1.0, the musket at 0.92, "
				+ "so bow and pistol should agree and the musket differs only through its speed.",
		"threshold_new_tree_mps": 0.15,
		"captured": Time.get_date_string_from_system(),
		"authorization": "owner-stated; see Player_Animation_Project/ASSET_AUTHORIZATION.md; granting party and terms not on file",
	}


## Count fields back to int (JSON.parse_string turns every number into a float).
static func _ints(v: Variant, key := "") -> Variant:
	if v is Dictionary:
		var o := {}
		for k in v:
			o[k] = _ints(v[k], String(k))
		return o
	if v is Array:
		var o := []
		for x in v:
			o.append(_ints(x, key))
		return o
	if v is float and key in INT_KEYS and v == floorf(v):
		return int(v)
	return v
