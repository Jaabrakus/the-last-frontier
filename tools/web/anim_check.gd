extends SceneTree
## The web build's animation libraries against the repo's originals: every clip the web copy holds, sampled along its length (every
## 1/hz s and at its end), each rotation, position, scale and blend shape track compared with the original's. Run it on the
## finished snapshot (tools/web/build_web.sh leaves it in ~/Library/Caches/Tidebreak/web_snapshot), from an empty project (a folder
## holding only a project.godot with config_version=5) so no project cache is touched:
##   GODOT_BIN=<any 4.7 editor> zsh tools/loop/godot_run.sh --headless --path <empty project> -s <repo>/tools/web/anim_check.gd -- \
##       orig=<repo>/animations_extra/ web=<snapshot>/animations_extra/
##       orig=<repo>/animations/Actor_B.res web=<snapshot>/animations/Actor_B.res
## (a folder: every .res file both hold; a .res file: that one library). Options: libs=A,B (names without .res; folders only), hz=120,
## deg=2, mm=10, top=25 and pack=<a .pck>, mounted first to check the libraries of the FINISHED web build (join its parts with
## `cat <build>/index.pck.0* > joined.pck`; give web=res://animations_extra/ or res://animations/Actor_B.res; the export strips some
## clip metadata, so a pack is not compared on it).
## The measure and its limits are tools/web/anim_error.gd's, the compress step's own: a rotation more than `deg` degrees off, a
## position more than `mm` millimetres, a scale or blend shape more than 0.01 / 0.02, or the clip's tracks, length, loop mode or
## metadata not the same. Exit 0: no clip beyond the limits; 1: some clip is; 2: a library missing or unreadable, or a clip missing
## from the web copy.
## (Animation.compress() at its default page size left 1 clip in 13 with a bone far from the original for 50-500 ms, some of
## them a root 100-800 mm off: the Shift movement spells, the fire Kick, the backward walks. See tools/web/compress_anims.gd.)

const AnimError := preload("anim_error.gd")

var step_hz := AnimError.HZ
var max_deg := AnimError.MAX_ROT_DEG
var max_mm := AnimError.MAX_POS_MM
var top := 25
var with_meta := true


func _initialize() -> void:
	var orig_arg := ""
	var web_arg := ""
	var only: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		var v := kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"orig": orig_arg = v
			"web": web_arg = v
			"libs": only = v.split(",", false)
			"hz": step_hz = maxf(float(v), 1.0)
			"deg": max_deg = float(v)
			"mm": max_mm = float(v)
			"top": top = int(v)
			"pack":
				if not ProjectSettings.load_resource_pack(v):
					print("CANNOT MOUNT THE PACK %s" % v)
					quit(2)
					return
				with_meta = false
	if orig_arg == "" or web_arg == "":
		print("usage: -- orig=<repo folder or .res> web=<snapshot folder or .res> [libs=A,B] [hz=120] [deg=2] [mm=10] [top=25]")
		quit(2)
		return
	print("ENGINE %s; limits: rotation %.1f deg, position %.1f mm, scale %.3f, blend shape %.3f; sampled every 1/%.0f s" % [
			Engine.get_version_info().string, max_deg, max_mm, AnimError.MAX_SCALE, AnimError.MAX_SHAPE, step_hz])
	var pairs: Array = []                                    # [name, original path, web path]
	if orig_arg.ends_with(".res"):
		pairs.append([orig_arg.get_file().get_basename(), orig_arg, web_arg])
	else:
		var names := PackedStringArray()
		for f in DirAccess.get_files_at(web_arg):
			f = f.trim_suffix(".remap")                          # (a pack lists an exported resource as <name>.res.remap)
			if f.ends_with(".res") and FileAccess.file_exists(orig_arg.path_join(f)) and (only.is_empty() or f.get_basename() in only):
				names.append(f.get_basename())
		names.sort()
		for n in names:
			pairs.append([n, orig_arg.path_join(n + ".res"), web_arg.path_join(n + ".res")])
	var rows: Array = []
	var missing := 0
	var unreadable := 0
	var per_lib: Array = []
	for pr: Array in pairs:
		var orig := ResourceLoader.load(pr[1], "", ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
		var web := ResourceLoader.load(pr[2], "", ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
		if orig == null or web == null:
			print("CANNOT LOAD %s (original %s, web copy %s)" % [pr[0], orig != null, web != null])
			unreadable += 1
			continue
		var n_clips := 0
		var n_comp := 0
		var n_over := 0
		for n: StringName in orig.get_animation_list():
			if not web.has_animation(n):
				print("NOT IN THE WEB COPY: %s/%s" % [pr[0], n])
				missing += 1
				continue
			var r := AnimError.measure(orig.get_animation(n), web.get_animation(n), step_hz, max_deg, with_meta)
			r.merge({"lib": String(pr[0]), "clip": String(n), "len": orig.get_animation(n).length,
					"over": AnimError.beyond(r, max_deg, max_mm)})
			rows.append(r)
			n_clips += 1
			n_comp += 1 if r.compressed else 0
			n_over += 1 if r.over else 0
		for n: StringName in web.get_animation_list():
			if not orig.has_animation(n):
				print("ONLY IN THE WEB COPY: %s/%s" % [pr[0], n])
		per_lib.append("%-26s %4d clips, %4d compressed, %d beyond the limits" % [pr[0], n_clips, n_comp, n_over])
	if rows.is_empty():
		print("no clips compared")
		quit(2)
		return
	for l in per_lib:
		print(l)
	_report(rows, missing)
	var over := rows.filter(func(r: Dictionary) -> bool: return r.over).size()
	print("ANIM CHECK DONE: %d clips, %d beyond the limits, %d missing from the web copy, %d libraries unreadable" % [rows.size(), over, missing, unreadable])
	quit(2 if (unreadable > 0 or missing > 0) else (1 if over > 0 else 0))


func _report(rows: Array, missing: int) -> void:
	var by_rot := rows.duplicate()
	by_rot.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.rot) > float(y.rot))
	print("--- the %d clips with the largest rotation error" % mini(top, by_rot.size()))
	for i in mini(top, by_rot.size()):
		print(_row(by_rot[i]))
	var by_pos := rows.duplicate()
	by_pos.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.pos_mm) > float(y.pos_mm))
	print("--- the 5 with the largest position error")
	for i in mini(5, by_pos.size()):
		print(_row(by_pos[i]))
	var bad := rows.filter(func(r: Dictionary) -> bool: return r.over)
	if not bad.is_empty():
		bad.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return String(x.lib + x.clip) < String(y.lib + y.clip))
		print("--- BEYOND THE LIMITS (%d)" % bad.size())
		for r: Dictionary in bad:
			print(_row(r))
	var rot: Array = rows.map(func(r: Dictionary) -> float: return float(r.rot))
	var pos: Array = rows.map(func(r: Dictionary) -> float: return float(r.pos_mm))
	rot.sort()
	pos.sort()
	var c := rows.size()
	var comp := rows.filter(func(r: Dictionary) -> bool: return r.compressed).size()
	print("--- summary: %d clips compared (%d compressed in the web copy, %d left as they are; %d missing from it)" % [c, comp, c - comp, missing])
	print("worst bone per clip (deg): median %.2f, 90th %.2f, 99th %.2f, max %.2f" % [rot[c / 2], rot[int(c * 0.9)], rot[mini(int(c * 0.99), c - 1)], rot[c - 1]])
	var line := "clips whose worst bone is off by more than"
	for lim in [0.5, 1.0, 2.0, 5.0, 10.0, 30.0]:
		line += "  %.1f deg: %d" % [lim, rot.filter(func(v: float) -> bool: return v > lim).size()]
	print(line)
	print("worst position per clip (mm): median %.2f, 90th %.2f, max %.2f; clips beyond 5 / 10 / 50 mm: %d / %d / %d" % [
			pos[c / 2], pos[int(c * 0.9)], pos[c - 1], pos.filter(func(v: float) -> bool: return v > 5.0).size(),
			pos.filter(func(v: float) -> bool: return v > 10.0).size(), pos.filter(func(v: float) -> bool: return v > 50.0).size()])
	print("worst scale %.5f, worst blend shape %.5f; clips whose tracks, length, loop mode or metadata differ: %d" % [
			rows.reduce(func(m: float, r: Dictionary) -> float: return maxf(m, float(r.scale)), 0.0),
			rows.reduce(func(m: float, r: Dictionary) -> float: return maxf(m, float(r.shape)), 0.0),
			rows.filter(func(r: Dictionary) -> bool: return not r.same_layout).size()])


func _row(r: Dictionary) -> String:
	return "%s%-22s %-40s %5.2fs %s  %s%s" % ["OVER " if r.over else "     ", String(r.lib).trim_prefix("Frontier_"), String(r.clip).left(40), r.len,
			"zip" if r.compressed else "raw", AnimError.describe(r), "  (%d samples over %.0f deg)" % [r.over_frames, max_deg] if r.over_frames > 0 else ""]
