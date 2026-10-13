extends SceneTree
## Critic's probe (read-only on game files): the lattice of every element's two trees, in numbers. Per tree: node count,
## link count, node size, rows (distinct centre y within 6 px), the biggest vertical gap between neighbouring rows, how much of
## the zone's height the rows span, the zone width the nodes span, the nearest centre-to-centre distance, nodes per link,
## whether any node sits closer than its own size to another, and where the gate stubs fall. Headless, no window.
##   zsh tools/loop/godot_run.sh --headless --path . -s tools/ui_audit/critique_layout.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	AdvancementStore.path = "user://advancement_critique.json"
	AdvancementStore.reload_file()
	AdvancementData.reload_data()
	AdvancementLayout.reload_data()
	AdvancementData.gates_override = {"won": true, "full_left": 0, "first_win": true, "full_lessons": true}
	for el: String in AdvancementData.ELEMENTS:
		var w := AdvancementWindow.open(root, el)
		await process_frame
		await process_frame
		for side: String in ["left", "right"]:
			var t: AdvancementTree = w.tree(side)
			var plan: Dictionary = t.plan
			var zone: Rect2 = plan.zone
			var ys: Array = []
			var pts: Array = []
			for it: Dictionary in plan.items:
				var p: Vector2 = it.pos
				pts.append(p)
				ys.append(snappedf(p.y, 6.0))
			ys.sort()
			var rows: Array = []
			for y in ys:
				if rows.is_empty() or abs(float(y) - float(rows[-1])) > 6.0:
					rows.append(y)
			var biggest := 0.0
			var where := 0.0
			for i in range(1, rows.size()):
				var g := float(rows[i]) - float(rows[i - 1])
				if g > biggest:
					biggest = g
					where = float(rows[i - 1])
			var minx := 1e9
			var maxx := -1e9
			var miny := 1e9
			var maxy := -1e9
			var nearest := 1e9
			var tight := 0
			for i in pts.size():
				var p: Vector2 = pts[i]
				minx = minf(minx, p.x)
				maxx = maxf(maxx, p.x)
				miny = minf(miny, p.y)
				maxy = maxf(maxy, p.y)
				for j in range(i + 1, pts.size()):
					var d := p.distance_to(pts[j])
					nearest = minf(nearest, d)
					if d < float(plan.icon) * 1.0:
						tight += 1
			var link_len := 0.0
			var diag := 0
			for l: Dictionary in plan.links:
				var a: Vector2 = l.a
				var b: Vector2 = l.b
				link_len += a.distance_to(b)
				if absf(a.x - b.x) > 6.0 and absf(a.y - b.y) > 6.0:
					diag += 1
			var gates: Array = []
			for g: Dictionary in plan.gates:
				gates.append("%s@y%.0f x0=%.0f" % [String(g.type), float(g.y) + zone.position.y, float(g.x0) + zone.position.x])
			print("%-5s %-5s zone=%s icon=%d nodes=%d links=%d (diagonal %d, avg len %.0f) rows=%d  biggest_row_gap=%.0f after y=%.0f  span_y=%.0f of %.0f (%.0f%%)  span_x=%.0f of %.0f (%.0f%%)  nearest=%.0f tight_pairs=%d gates=%s" % [
				el, side, str(zone), int(plan.icon), pts.size(), plan.links.size(), diag, link_len / maxf(1.0, plan.links.size()),
				rows.size(), biggest, where, maxy - miny + float(plan.icon), zone.size.y, 100.0 * (maxy - miny + float(plan.icon)) / zone.size.y,
				maxx - minx + float(plan.icon), zone.size.x, 100.0 * (maxx - minx + float(plan.icon)) / zone.size.x, nearest, tight, str(gates)])
		w.free()
		await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://advancement_critique.json"))
	print("CRITIQUE LAYOUT DONE")
	quit(0)
