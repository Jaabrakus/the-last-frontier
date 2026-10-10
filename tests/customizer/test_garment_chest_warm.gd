extends SceneTree
## GarmentChest's apex search a slice at a time (warm_step: the menus dress their fighters while the lobby is shown, and the search
## in one frame froze it for about 0.35 s) finds exactly what the one-call search finds, and does it in more than one slice with a
## small budget. Then a garment smoothed after the sliced search is the same mesh as after the one-call one. Headless:
##   Godot --headless --path . -s tests/customizer/test_garment_chest_warm.gd

const GarmentChest := preload("res://scripts/customizer/garment_chest.gd")

var checks := 0
var fails: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)


func _reset() -> void:
	GarmentChest._apexes = {}
	GarmentChest._searched = false
	GarmentChest._search = {}
	GarmentChest._done = {}


func _run() -> void:
	# the one-call search
	_reset()
	var t0 := Time.get_ticks_usec()
	var whole := {}
	whole[""] = GarmentChest.apexes("")
	var one_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var all_one: Dictionary = GarmentChest._apexes.duplicate(true)
	check(not (whole[""] as Array).is_empty(), "the body's two apexes are found (%s)" % str(whole[""]))
	check(all_one.size() > 1, "and one under each of the body's blend shapes (%d shapes)" % all_one.size())
	# the same search a slice at a time
	_reset()
	var slices := 0
	var longest := 0.0
	while true:
		var t := Time.get_ticks_usec()
		var done := GarmentChest.warm_step(4000)
		longest = maxf(longest, (Time.get_ticks_usec() - t) / 1000.0)
		slices += 1
		if done:
			break
		if slices > 10000:
			break
	var all_sliced: Dictionary = GarmentChest._apexes.duplicate(true)
	check(slices > 3, "a small budget takes several slices (%d)" % slices)
	check(all_sliced == all_one, "the sliced search finds the same apexes for every shape (%d against %d shapes)" % [all_sliced.size(), all_one.size()])
	check(GarmentChest.warm_step(), "once done, warm_step says so at once")
	check(GarmentChest.apexes("") == whole[""], "apexes() after the sliced search answers the same")
	print("  one call %.1f ms; sliced in %d slices, the longest %.1f ms" % [one_ms, slices, longest])
	# a garment over the chest smoothed after either search: the same vertices
	var tunic := PlayerOutfit.entry("ring_fire_top")
	var glb := String(tunic.get("glb", ""))
	if glb == "":
		for id: String in PlayerOutfit.catalog().keys():
			var e := PlayerOutfit.entry(id)
			if (e.get("occupies_regions", []) as Array).has("chest_front") and String(e.get("glb", "")) != "":
				glb = String(e.glb)
				break
	var sc := load(glb) as PackedScene if glb != "" and ResourceLoader.exists(glb) else null
	if sc == null:
		check(false, "a chest garment to smooth (%s)" % glb)
	else:
		var inst := sc.instantiate()
		var mesh: Mesh = null
		for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
			mesh = mi.mesh
			break
		inst.free()
		var a := GarmentChest.smoothed(mesh)               # (after the sliced search)
		var va: PackedVector3Array = a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		_reset()
		GarmentChest.apexes("")
		var b := GarmentChest.smoothed(mesh)               # (after the one-call search)
		var vb: PackedVector3Array = b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		check(va == vb, "%s smoothed the same after either search (%d points)" % [glb.get_file(), va.size()])
	if fails.is_empty():
		print("GARMENT CHEST WARM TEST PASSED %d" % checks)
	else:
		print("GARMENT CHEST WARM TEST FAILED %d/%d" % [fails.size(), checks])
		for f in fails:
			print("FAIL: ", f)
	quit(0 if fails.is_empty() else 1)
