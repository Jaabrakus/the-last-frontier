extends SceneTree
## Run the survival simulation harness from the command line and print (or save) its report.
##
##   Godot --headless --path . -s tests/survival/run_survival_sim.gd -- --policy trapper --days 36 --seed 3
##   options: --bg bg.backcountry_hunter | bg.provincial_ranger
##            --policy self_sufficient | barterer | apprentice (the v4 policies: no coin; barter; lessons and watching)
##                     | trapper | hunter | woodcutter (the old money path; the trapper plays the credit start variant)
##                     | careless | idle
##            --variant start.clear | start.outfitted_on_credit | start.sutler_tally | start.promise
##            --days N   --seed N   --start sep_early   --hour 7   --preset woodsman   --line 16   --backlog M3
##            --json user://sim_report.json   --verbose   --quiet (summary lines only)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var o := {"background": "bg.backcountry_hunter", "policy": "trapper", "days": 36, "seed": 1}
	var json_path := ""
	var quiet := false
	var i := 0
	while i < args.size():
		var a := str(args[i])
		var v := str(args[i + 1]) if i + 1 < args.size() else ""
		match a:
			"--bg":
				o["background"] = v
				i += 1
			"--policy":
				o["policy"] = v
				i += 1
			"--variant":
				o["start_variant"] = v
				i += 1
			"--days":
				o["days"] = v.to_int()
				i += 1
			"--seed":
				o["seed"] = v.to_int()
				i += 1
			"--start":
				o["start_day"] = v
				i += 1
			"--hour":
				o["start_hour"] = v.to_float()
				i += 1
			"--preset":
				o["preset"] = v
				i += 1
			"--line":
				o["line_size"] = v.to_int()
				i += 1
			"--backlog":
				o["backlog_milestones"] = Array(v.split(","))
				i += 1
			"--json":
				json_path = v
				i += 1
			"--verbose":
				o["verbose"] = true
			"--quiet":
				quiet = true
		i += 1
	var t0 := Time.get_ticks_msec()
	var rep := SurvivalSim.run(o)
	var text := SurvivalSim.format_report(rep)
	if quiet:
		var lines := text.split("\n")
		var keep := PackedStringArray([lines[0]])
		for l in lines:
			if not l.begins_with("  ") or l.begins_with("  skills") or l.begins_with("  income") or l.begins_with("  catches") \
					or l.begins_with("  settlements") or l.begins_with("  cold"):
				if l != lines[0] and not l.begins_with("  day") and not (l.length() > 5 and l.substr(2, 3).strip_edges().is_valid_int()):
					keep.append(l)
		text = "\n".join(keep)
	print(text)
	print("  (%d ms)" % (Time.get_ticks_msec() - t0))
	if json_path != "":
		var f := FileAccess.open(json_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(rep, "\t"))
			f.close()
			print("  report written to %s" % ProjectSettings.globalize_path(json_path))
	quit(0)
