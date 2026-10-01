extends SceneTree
## Runs the mocap downgrader (mocap_downgrade.gd) over the graph's looping body cycles and wires the results
## (user 2026-09-30: "that looks good apply it to all of them"): the walks, the sprints and the crouch walks, forward, backward and to
## the sides. The jogs get it in author_locomotion.gd (their starts and stops are built from them). Left alone: the weapon aim and hold
## cycles (they carry the aim), the idles and turns, and every one-shot (vaults, swings, climbs: a stiffened action lands its hands
## elsewhere). The legs, hips and timing are the graph's own, so its metrics (plant phases, travel) stand.
##   Godot --headless --path . -s tools/anim_author/mocap_downgrade_all.gd
## writes animations_extra/Frontier_Downgraded.res and data/anim_author/downgraded_clips.json (read by AnimGraphData.apply_downgraded_clips).

const Downgrade := preload("res://tools/anim_author/mocap_downgrade.gd")
const LEVEL := "stiff"
const NATIVE := "res://animations/Actor_B.res"
const GRAPH := "res://animations/actor_b_graph.json"
const METRICS := "res://animations/actor_b_clip_metrics.json"
const OUT_LIB := "res://animations_extra/Frontier_Downgraded.res"
const WIRED := "res://data/anim_author/downgraded_clips.json"
const LOCO := "res://data/anim_author/locomotion_clips.json"
## Cycles the metrics flag as no loop for a foot's seam only (the upper body closes): the walk to the right, r_ball 0.12 rad.
const FORCE_LOOP := ["actor_b-p-walk-fw-rt"]
const PATTERN := "^actor_b-p-(walk|sprint|crouch-walk)-(fw|bw)(-lt|-rt)?$"


func _initialize() -> void:
	var lib := load(NATIVE) as AnimationLibrary
	var graph: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GRAPH))
	var metrics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(METRICS)).clips
	var own: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LOCO)).clips
	var re := RegEx.create_from_string(PATTERN)
	var out := AnimationLibrary.new()
	var wired := {}
	var names: Array = graph.clips.keys()
	names.sort()
	for name: String in names:
		if re.search(name) == null or own.has(name) or not lib.has_animation(name):
			continue
		var c: Dictionary = graph.clips[name]
		if bool(c.get("additive", false)) or not (bool(metrics.get(name, {}).get("loop", false)) or FORCE_LOOP.has(name)):
			continue
		var src := lib.get_animation(name)
		if src.length < 0.5:
			continue
		var a: Animation = Downgrade.downgrade(src, LEVEL, true)
		out.add_animation(StringName(name), a)
		wired[name] = {"lib": "frontier_downgraded", "clip": name, "length": snappedf(a.length, 0.000001)}
		print("  ", name, " ", snappedf(a.length, 0.001), " s")
	print(ResourceSaver.save(out, OUT_LIB, ResourceSaver.FLAG_COMPRESS), " ", wired.size(), " clips")
	var f := FileAccess.open(WIRED, FileAccess.WRITE)
	f.store_string(JSON.stringify({"about": "Looping body cycles with the upper body stiffened and loosened (tools/anim_author/mocap_downgrade_all.gd, level " + LEVEL + "): graph clip name -> the library and clip played instead (AnimGraphData.apply_downgraded_clips). Same length and legs as the graph's own.", "clips": wired}, "\t") + "\n")
	f.close()
	quit()
