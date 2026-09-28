extends SceneTree
## Bakes the results of the vegetation layout's clipping clean-up pass
## (scripts/world/vegetation/veg_layout.gd, "Clipping clean-up") into
## assets/environment/vegetation/layout_fixes.json, so a level load applies them in a few ms
## instead of running the ~0.5 s pass. Headless:
##
##   Godot --headless --path . -s tools/environment/vegetation/bake_layout_fixes.gd
##
## Rerun after anything the pass reads changes (terrain, trees.json, props.json, low_foliage.json,
## the layout rules) or after bumping VegLayout.FIX_VERSION; a stale entry is harmless (the pass
## then runs live and prints a note) and tools/environment/check_clipping.gd reports it.
## One "colliders" entry (trees, stumps, logs, rocks: every preset) and one "clutter:<density>"
## entry per preset clutter density (WorldSettings low / medium / high).

const Layout := preload("res://scripts/world/vegetation/veg_layout.gd")


func _initialize() -> void:
	var out := {"version": Layout.FIX_VERSION}
	var densities := {}
	for q in ["low", "medium", "high"]:
		densities[snappedf(WorldSettings.preset(q).clutter_density, 0.01)] = q
	for d: float in densities:
		var t0 := Time.get_ticks_msec()
		var L := Layout.new(1776, EnvironmentRig.sun_direction())
		L.use_fix_cache = false
		L.build(true, d)
		for part: String in L.fix_entries:
			out[part] = L.fix_entries[part]
		print("BAKE clutter %.2f (%s): %d ms, trees %d props %d plants %d, %s" % [d, densities[d], Time.get_ticks_msec() - t0,
				L.tree_pos.size(), L.prop_pos.size(), L.plant_pos.size(), JSON.stringify(L.stats.get("clip_fix", {}))])
	var f := FileAccess.open(Layout.FIX_CACHE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "", true, true))
	f.close()
	var parts := PackedStringArray()
	for k: String in out:
		if k != "version":
			parts.append("%s (%d trees, %d props, %d plants changed)" % [k, out[k].trees.size(), out[k].props.size(), out[k].plants.size()])
	print("LAYOUT FIXES BAKED %s: %s" % [Layout.FIX_CACHE_PATH, ", ".join(parts)])
	quit()
