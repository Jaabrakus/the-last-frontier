extends SceneTree
## Every talent of the skill tree (data/sway/skill_tree.json) against what a match applies (BendLoadout; the owner, 2026-10-11: "we
## need to make sure all the talents work and they work in game right"), headless, no scene:
##   Godot --headless --path . -s tools/ring/talent_audit.gd -- [out=<file.json>]
## For each node with an id: its element, kind, name, ring_legal, held, ring_cost; live now (BendLoadout.why_not "" ) or why not;
## and whether its numbers resolve per wearer as they are (BendLoadout.resolve: ok, or the reason: the node needs new code).
## Prints one line a node and a summary; with out= also the table as JSON. Ends "TALENT AUDIT DONE".

var out_path := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_path = a.substr(4)
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/sway/skill_tree.json"))
	var nodes: Array = []
	_walk(d, nodes)
	var rows: Array = []
	var counts := {}
	for n: Dictionary in nodes:
		var id := String(n.id)
		var why := BendLoadout.why_not(id)
		var r := BendLoadout.resolve(id)
		var row := {"id": id, "kind": String(n.get("kind", "")), "name": String(n.get("name", "")),
				"ring_legal": bool(n.get("ring_legal", false)), "held": n.get("held") != null, "ring_cost": n.get("ring_cost"),
				"changes": (n.get("changes", []) as Array).size() if n.get("changes") is Array else 0,
				"live": why == "", "why_not": why, "resolves": bool(r.ok), "resolve_why": String(r.why)}
		rows.append(row)
		var key := "live" if why == "" else ("switched off" if why == "switched off" else
				("ring, resolves (not listed)" if row.ring_legal and not row.held and row.resolves else
				("ring, needs code: " + String(r.why).get_slice(":", 0) if row.ring_legal and not row.held else
				("held (owner question)" if row.held else "not ring-legal"))))
		counts[key] = int(counts.get(key, 0)) + 1
		print("TALENT %-34s %-11s %-6s %-28s %s" % [id, row.kind, "LIVE" if row.live else "-", row.name.left(28),
				"" if row.live else (why + ("" if row.resolves else "  [resolve: " + row.resolve_why + "]"))])
	print("TALENT SUMMARY %d nodes" % rows.size())
	var keys := counts.keys()
	keys.sort()
	for k: String in keys:
		print("TALENT SUMMARY  %4d  %s" % [counts[k], k])
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(rows, "\t"))
	print("TALENT AUDIT DONE")
	quit(0)


## The tree's nodes: every dictionary with a string id and a kind or changes (the element trees, the skill sets, the synergies).
func _walk(x: Variant, out: Array) -> void:
	if x is Dictionary:
		var dx := x as Dictionary
		if dx.get("id") is String and (dx.has("changes") or dx.has("kind")) and String(dx.id).contains("."):
			out.append(dx)
		for k: Variant in dx:
			_walk(dx[k], out)
	elif x is Array:
		for v: Variant in (x as Array):
			_walk(v, out)
