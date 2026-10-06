extends SceneTree
## Still against running water for the owner (plan phase 1, T5): the mood frames' camera at the still reach
## (shot_util.gd), S0 (running) beside S1 (still), at dawn, at noon and in the rain, today's look. Writes
## <time>_running.png, <time>_still.png and still_vs_running.png (a row per time: running left, still right) to out=.
##
##   zsh PLAN/bin/godot_run.sh --path <lane> --resolution 1600x900 -s tools/thuyvan_shots/still_vs_running.gd -- \
##       out=PLAN/review/T5

const U := preload("res://tools/thuyvan_shots/shot_util.gd")
## [name, hour, weather]: dawn just after sunrise at 21 N in mid-May (local solar time), noon, a rain shower's core
## overhead in the morning.
const TIMES := [["dawn", 5.6, "fair"], ["noon", 12.0, "fair"], ["rain", 9.5, "storm_here"]]


func _initialize() -> void:
	var dir := U.out_dir()
	var lv: Node = await U.load_level(self)
	if lv == null:
		print("STILL no level")
		quit(1)
		return
	U.reach_camera(lv)
	var shots: Array = []
	for t: Array in TIMES:
		U.set_sky(lv, float(t[1]), String(t[2]))
		for s: String in ["S0", "S1"]:
			lv.call("set_state", s, true)
			# (the running water's ripples and the rain need their frames; the sky snaps on the hour)
			await U.settle(self, 90)
			shots.append(await U.grab(self, dir, "%s_%s" % [t[0], "running" if s == "S0" else "still"]))
	U.sheet(shots, 2).save_png(dir.path_join("still_vs_running.png"))
	print("STILL wrote ", dir.path_join("still_vs_running.png"))
	quit(0)
