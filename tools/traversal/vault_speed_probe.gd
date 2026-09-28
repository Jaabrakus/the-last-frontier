extends SceneTree
## Speed profile of the player through vaults (VaultSpeedHarness, tests/traversal/vault_speed_harness.gd): every
## obstacle x gait, one summary line each and (verbose) the tick-by-tick profile from 1 s before the vault to
## 1.5 s after it. Writes the runs as JSON when out= is given.
##
##   Godot --headless --fixed-fps 120 --path . -s tools/traversal/vault_speed_probe.gd -- \
##       [obstacles=fence,wall70,wall90,log55] [gaits=walk,jog,run,sprint,stand] [verbose] [out=/abs/file.json]

var _args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		_args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	InputSetup.ensure()
	var obstacles := str(_args.get("obstacles", "fence,wall70,wall90,log55")).split(",")
	var gaits := str(_args.get("gaits", "walk,jog,run,sprint,stand")).split(",")
	var h := VaultSpeedHarness.new(self)
	var all := []
	print("VAULT SPEED  obstacle gait   move           steady entry  min_cap(t, at)          min_model(t, at)        exit   end    dur   slide")
	for o in obstacles:
		for g in gaits:
			var r: Dictionary = await h.run(o, g)
			var line := "  %-7s %-6s %-14s " % [o, g, str(r.get("move", "-"))]
			if bool(r.get("ok", false)):
				line += "%5.2f  %5.2f  %5.2f (%+5.2f %-12s) %5.2f (%+5.2f %-12s) %5.2f  %5.2f  %4.2f  %4.1f cm" % [
					float(r.steady), float(r.entry), float(r.min_cap), float(r.min_cap_t), str(r.min_cap_at).left(12),
					float(r.min_model), float(r.min_model_t), str(r.min_model_at).left(12), float(r.exit), float(r.end),
					float(r.duration), float(r.slide_max) * 100.0]
			else:
				line += "no move"
			print(line)
			if _args.has("entry") and bool(r.get("ok", false)):
				# every tick around the entry and the exit: capsule, rig root and pelvis forward speeds
				var b := int(r.w0)
				for i in range(b, int(r.w1)):
					var f: Dictionary = h.frames[i]
					var tr := float(f.t) - float(r.began)
					if not ((tr > -0.05 and tr < 0.15) or (float(f.t) - float(r.ended) > -0.05 and float(f.t) - float(r.ended) < 0.4)):
						continue
					var fp: Dictionary = h.frames[i - 1]
					var vr := -((f.rig as Vector3).z - (fp.rig as Vector3).z) * 120.0
					var dr := -((f.rig as Vector3).z - (f.pos as Vector3).z)
					var dp := -((f.pelvis as Vector3).z - (f.pos as Vector3).z)
					print("    e %+6.3f cap %5.2f rig %5.2f pel %5.2f  rig-body %+5.2f pel-body %+5.2f  %s %s tm %.3f r %.2f %s" % [tr, float(f.v_cap), vr, float(f.v_model), dr, dp, f.mode, f.move, float(f.t_move), float(f.rate), f.loco])
			if _args.has("verbose"):
				for l in VaultSpeedHarness.profile_lines(h.frames, r, int(_args.get("every", "6"))):
					print(l)
				print("    slides: ", r.get("slides", {}))
			var keep := r.duplicate()
			var prof := []
			if bool(r.get("ok", false)):
				for i in range(int(r.w0), int(r.w1)):
					var f: Dictionary = h.frames[i]
					prof.append([snappedf(float(f.t) - float(r.began), 0.0001), snappedf(float(f.v_cap), 0.001), snappedf(float(f.v_model_s), 0.001),
							snappedf(float(f.v_model), 0.001), str(f.mode), str(f.move), int(f.part), snappedf(float(f.rate), 0.001), str(f.loco)])
			keep["profile"] = prof
			all.append(keep)
	if _args.has("out"):
		var fa := FileAccess.open(str(_args.out), FileAccess.WRITE)
		fa.store_string(JSON.stringify(all, " "))
	quit(0)
