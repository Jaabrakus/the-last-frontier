class_name AdvancementLayout
extends RefCounted
## Where the Character Advancement window puts each node of a tree (artifacts/ui_audit/advancement/plan.md section 2).
## Ring mode reads the pins of data/ui/advancement_layout.json (written by tools/ui/advancement_layout.py, then tuned by
## eye); any id with no pin falls back to the algorithm's place with a warning (tests/ui/test_advancement.gd fails on it).
## Since 2026-10-10 the pins are the tool's DIAMOND LATTICE (its lattice(): every other row offset half a column, each pick
## diagonally under the one before it, the lines packed tight, as the owner's reference packs its talents): ring mode then
## uses layout.lattice's icon and pitch limits, draws the lattice's mesh (_lattice_decor: every two diagonal neighbours) and
## puts the first-win gate on the top row; the lessons gate's picks are mixed among open ones on a lattice, so each wears
## the gate's padlock and number (AdvancementNode.gate_num) and no row line is drawn for it (its entry stays in `gates`).
## World mode (Phase C) uses the algorithm alone. The algorithm here is the tool's, step for step (the test holds the two
## to the same numbers): see the tool's header for the rules (lines, tiers, choices, bands, places, links).
##
##   place(el, side, mode) -> {
##     items:   [{key, type ("root" | "node" | "choice"), id (a node's id; "" for roots), ids (a choice's members in
##               data order; [id] for a node; [] for a root), chip, move, mode, passive (a passive line's root: the
##               element passive's id), line, tier, band, col, row (slot grid), pos (Vector2: the slot's centre in the
##               zone's own pixels)}],
##     links:   [{from, to, a, b}]  (item keys; a and b the two centres: draw from a's bottom edge to b's top edge)
##     bands:   [{index, lines, rows, top_y, twist_y (-1 none), x0, x1}]  (zone pixels)
##     gates:   [{type ("first_win" | "full"), band, y, x0, x1}]  where a gate line goes (the window draws the one
##              AdvancementData.gate_state calls for: the first-win gate on the first row, the lessons gate on the twist
##              row of the first band, or of every band when switches.gate_every_band)
##     decor:   [{from, to, a, b}]  the lattice's cross links (a node to a node of the next row in a neighbouring line, running
##              down to the right on a band's even rows and to the left on its odd ones, so none cross; and the last row of a
##              band to the nearest of the next band's first): drawn only, thin and dim; they hold no rule (the real
##              prerequisites are `links`, `requires` in the tree's data)
##     zone (Rect2, authored pixels), size (Vector2: the content's size), pitch (Vector2), icon (float),
##     unpinned (keys that had no pin), by_id ({node id: item key}), by_key ({item key: item index})}
## The pixels: the grid is centred in the zone and its pitch fills the zone (layout.fill_margin [side, top, bottom] of
## it stay clear) between layout.min_pitch_* and layout.max_pitch_*, so a tree of a few rows is spread, not huddled.
##   algorithm(el, side, mode) -> {places: {key: Vector2(col, row)}, items, links: [[a, b]], bands, width}
##   pins(el, side) / generated(el, side) -> {key: Vector2(col, row)} from the file

const PATH := "res://data/ui/advancement_layout.json"

static var _file := {}


static func reload_data() -> void:
	_file = {}


static func file_data() -> Dictionary:
	if _file.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_file = d if d is Dictionary else {"pins": {}, "generated": {}}
	return _file


static func _grid(block: String, el: String, side: String) -> Dictionary:
	var out := {}
	var e: Variant = (file_data().get(block, {}) as Dictionary).get(el, {})
	var s: Variant = (e as Dictionary).get(side, {}) if e is Dictionary else {}
	if s is Dictionary:
		for k: String in s:
			var p: Variant = s[k]
			if p is Array and (p as Array).size() >= 2:
				out[k] = Vector2(float(p[0]), float(p[1]))
	return out


## The hand-tuned pins of one tree: {node id or root key: Vector2(col, row)}.
static func pins(el: String, side: String) -> Dictionary:
	return _grid("pins", el, side)


## The tool's own places (untouched by hand), for the parity test.
static func generated(el: String, side: String) -> Dictionary:
	return _grid("generated", el, side)


# --- the algorithm (tools/ui/advancement_layout.py, step for step) ------------------------------------------------------

## Lexicographic order of two arrays of numbers (Python's tuple order).
static func _less(a: Array, b: Array) -> bool:
	for i in mini(a.size(), b.size()):
		if a[i] < b[i]:
			return true
		if a[i] > b[i]:
			return false
	return a.size() < b.size()


static func _mode_index(move: String, md: String) -> int:
	var m := SwayMoves.move(move)
	var ms: Array = m.get("modes", []) if m.get("modes") is Array else []
	if md in ms:
		return ms.find(md)
	var wm: Array = m.get("world_modes", []) if m.get("world_modes") is Array else []
	if md in wm:
		return 50 + wm.find(md)
	return 99


## Lines, tiers and entries of one tree: [{chip, move, mode, entries: {tier: [entry]}, width}] in line order. An entry:
## {key, type, ids, move?, mode?, passive?}.
static func structure(el: String, side: String, mode := "ring") -> Array:
	var tc := AdvancementData.tree_cfg()
	var tiers: Dictionary = tc.get("tiers", {})
	var choice_kinds: Array = tc.get("choice_kinds", [])
	var chip_order: Array = AdvancementData.chip_order()
	var nodes := AdvancementData.tree_nodes(el, side, mode)
	var lines := {}            # line key "chip|move|mode" -> [nodes]
	var later: Array = []
	for n: Dictionary in nodes:
		var lk := _line_of(n)
		if not lk[0] in ["set", "passive"] and lk[1] != "slot" and lk[2] == "":
			later.append(n)
			continue
		var k := "|".join(PackedStringArray(lk))
		if not lines.has(k):
			lines[k] = []
		(lines[k] as Array).append(n)
	var sort_key := func(k: String) -> Array:
		var p := k.split("|")
		var chip := p[0]
		var ci := chip_order.find(chip)
		if ci < 0:
			ci = chip_order.size()
		var first := 1 << 30
		for n: Dictionary in lines[k]:
			first = mini(first, int(n.order))
		if chip == "set" or chip == "passive":
			return [ci, 0, 0, 0, first]
		if p[1] == "slot":
			return [ci, 1, 0, 0, first]
		var km := AdvancementData.key_moves(el, chip)
		var mi := km.find(p[1])
		if mi < 0:
			mi = 9
		return [ci, 0, mi, _mode_index(p[1], p[2]) if p[2] != "" else 0, first]
	for n: Dictionary in later:
		var lk := _line_of(n)
		var cands: Array = []
		for k: String in lines:
			var p := k.split("|")
			if p[0] == lk[0] and p[1] == lk[1] and p[1] != "slot":
				cands.append(k)
		cands.sort_custom(func(a: String, b: String) -> bool: return _less(sort_key.call(a), sort_key.call(b)))
		var k := String(cands[0]) if not cands.is_empty() else "|".join(PackedStringArray(lk))
		if not lines.has(k):
			lines[k] = []
		(lines[k] as Array).append(n)
	var keys: Array = lines.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return _less(sort_key.call(a), sort_key.call(b)))
	var passive_id := String(((AdvancementData.tree().get("elements", {}) as Dictionary).get(el, {}) as Dictionary).get("passive", ""))
	var out: Array = []
	for k: String in keys:
		var p := k.split("|")
		var chip := p[0]
		var move := p[1]
		var md := p[2]
		var ns: Array = (lines[k] as Array).duplicate()
		ns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.order) < int(b.order))
		var by_tier := {}
		for n: Dictionary in ns:
			var t := int(tiers.get(String(n.kind), 1))
			if not by_tier.has(t):
				by_tier[t] = []
			(by_tier[t] as Array).append(n)
		var entries := {}
		if chip == "passive":
			entries[0] = [{"key": "root:passive/" + passive_id, "type": "root", "ids": [], "move": "", "mode": "", "passive": passive_id}]
		elif chip != "set" and move != "slot":
			entries[0] = [{"key": "root:%s/%s" % [move, md], "type": "root", "ids": [], "move": move, "mode": md, "passive": ""}]
		var ts: Array = by_tier.keys()
		ts.sort()
		for t: int in ts:
			if t == 0 and entries.has(0):
				push_warning("AdvancementLayout: a node at tier 0 under a root: %s" % String(by_tier[t][0].id))
			entries[t] = _entries_of(by_tier[t], choice_kinds)
		var width := 0
		for t: int in entries:
			width = maxi(width, (entries[t] as Array).size())
		out.append({"chip": chip, "move": move, "mode": md, "entries": entries, "width": width})
	return out


static func _line_of(n: Dictionary) -> Array:
	var k := String(n.kind)
	if k == "skill_set":
		return ["set", "", ""]
	if k == "passive":
		return ["passive", "", ""]
	if k == "new_skill":
		return [String(n.slot_chip), "slot", ""]
	return [String(n.slot_chip), String(n.move), String(n.mode)]


## One tier's entries: the choice kinds and excludes pairs joined (union-find, each group's root its first member).
static func _entries_of(ns: Array, choice_kinds: Array) -> Array:
	var parent := {}
	var order := {}
	for n: Dictionary in ns:
		parent[n.id] = n.id
		order[n.id] = int(n.order)
	var find := func(a: String) -> String:
		while parent[a] != a:
			a = parent[a]
		return a
	var union := func(a: String, b: String) -> void:
		var ra: String = find.call(a)
		var rb: String = find.call(b)
		if ra == rb:
			return
		if int(order[ra]) <= int(order[rb]):
			parent[rb] = ra
		else:
			parent[ra] = rb
	for ck: String in choice_kinds:
		var same: Array = []
		for n: Dictionary in ns:
			if String(n.kind) == ck:
				same.append(n.id)
		for i in range(1, same.size()):
			union.call(same[0], same[i])
	for n: Dictionary in ns:
		for x: String in n.excludes:
			if parent.has(x):
				union.call(n.id, x)
	var groups := {}
	for n: Dictionary in ns:
		var r: String = find.call(n.id)
		if not groups.has(r):
			groups[r] = []
		(groups[r] as Array).append(n.id)
	var roots: Array = groups.keys()
	var first_of := func(r: String) -> int:
		var m := 1 << 30
		for id: String in groups[r]:
			m = mini(m, int(order[id]))
		return m
	roots.sort_custom(func(a: String, b: String) -> bool: return first_of.call(a) < first_of.call(b))
	var out: Array = []
	for r: String in roots:
		var mem: Array = (groups[r] as Array).duplicate()
		mem.sort_custom(func(a: String, b: String) -> bool: return int(order[a]) < int(order[b]))
		if mem.size() == 1:
			out.append({"key": mem[0], "type": "node", "ids": mem})
		else:
			out.append({"key": "choice:" + String(mem[0]), "type": "choice", "ids": mem})
	return out


## Every split of n lines into b contiguous bands: the break indices, in lexicographic order (the tool's partitions()).
static func _partitions(n: int, b: int) -> Array:
	var out: Array = []
	if b == 1:
		out.append([])
		return out
	_rec(1, b - 1, n, [], out)
	return out


static func _rec(start: int, left: int, n: int, acc: Array, out: Array) -> void:
	if left == 0:
		out.append(acc.duplicate())
		return
	for i in range(start, n - left + 1):
		acc.append(i)
		_rec(i + 1, left - 1, n, acc, out)
		acc.pop_back()


## The bands (lists of line indices): the tool's bands_of, scored the same way with the same operations.
static func _bands_of(lines: Array, W: int, zone: Rect2) -> Array:
	var n := lines.size()
	if n == 0:
		return []
	var L := AdvancementData.layout()
	var gap := float(L.get("band_gap", 0.6))
	var icon := float(L.get("icon", 46))
	var px := float(L.get("pitch_x", 64))
	var py := float(L.get("pitch_y", 70))
	var zw := zone.size.x
	var zh := zone.size.y - float(L.get("top_pad", 0))
	var best: Array = []
	var best_score: Array = []
	for b in range(1, n + 1):
		for br: Array in _partitions(n, b):
			var cuts: Array = [0]
			cuts.append_array(br)
			cuts.append(n)
			var groups: Array = []
			for i in b:
				groups.append(range(int(cuts[i]), int(cuts[i + 1])))
			var ok := true
			var rows := 0
			var widest := 0
			var lone := 0
			for g: Array in groups:
				var w := 0
				for i: int in g:
					w += int(lines[i].width)
				if w > W and g.size() > 1:
					ok = false
					break
				var ts := {}
				for i: int in g:
					for t: int in lines[i].entries:
						ts[t] = true
				rows += ts.size()
				widest = maxi(widest, w)
				if g.size() == 1 and b > 1:
					lone += 1
			if not ok:
				continue
			var span := float(rows) - 1.0 + gap * float(b - 1)
			var cw := float(widest - 1) * px + icon
			var ch := span * py + icon
			var score: Array
			if ch <= zh + 1e-6:
				score = [0, lone, absf(log((cw / ch) / (zw / zh))), b]
			else:
				score = [1, 0, span, b]
			if best_score.is_empty() or _less(score, best_score):
				best = groups
				best_score = score
	return best


static func _r3(v: float) -> float:
	return snappedf(v, 0.001)


## The algorithm's places on the slot grid (see the class doc).
static func algorithm(el: String, side: String, mode := "ring") -> Dictionary:
	var L := AdvancementData.layout()
	var W := int(L.get("left_width" if side == "left" else "right_width", 7 if side == "left" else 5))
	var gap := float(L.get("band_gap", 0.6))
	var lines := structure(el, side, mode)
	var bands := _bands_of(lines, W, AdvancementData.zone(side))
	var places := {}
	var items: Array = []
	var links: Array = []
	var band_info: Array = []
	var top := 0.0
	for bi in bands.size():
		var g: Array = bands[bi]
		var tset := {}
		for i: int in g:
			for t: int in lines[i].entries:
				tset[t] = true
		var tiers: Array = tset.keys()
		tiers.sort()
		var bw := 0
		for i: int in g:
			bw += int(lines[i].width)
		var x := (float(W) - float(bw)) / 2.0
		for i: int in g:
			var ln: Dictionary = lines[i]
			var ts: Array = (ln.entries as Dictionary).keys()
			ts.sort()
			for t: int in ts:
				var ents: Array = ln.entries[t]
				for k in ents.size():
					var e: Dictionary = ents[k]
					var col := _r3(x + (float(ln.width) - float(ents.size())) / 2.0 + float(k))
					var row := _r3(top + float(tiers.find(t)))
					places[e.key] = Vector2(col, row)
					var it := e.duplicate(true)
					it["id"] = String(e.ids[0]) if String(e.type) == "node" else ""
					it["line"] = i
					it["tier"] = t
					it["band"] = bi
					it["chip"] = String(ln.chip)
					if not it.has("move"):
						var n0 := AdvancementData.node(String(e.ids[0]))
						it["move"] = String(n0.get("move", ""))
						it["mode"] = String(n0.get("mode", ""))
						it["passive"] = ""
					it["col"] = col
					it["row"] = row
					items.append(it)
			for j in range(ts.size() - 1):
				for ea: Dictionary in ln.entries[ts[j]]:
					for eb: Dictionary in ln.entries[ts[j + 1]]:
						links.append([ea.key, eb.key])
			x += float(ln.width)
		band_info.append({"lines": g, "top": _r3(top), "rows": tiers.size(), "tiers": tiers, "width": bw})
		top += float(tiers.size()) + gap
	return {"places": places, "items": items, "links": links, "bands": band_info, "width": W}


# --- the window's places -----------------------------------------------------------------------------------------------

## One tree laid out for the window (see the class doc).
static func place(el: String, side: String, mode := "ring") -> Dictionary:
	var alg := algorithm(el, side, mode)
	var pn := pins(el, side) if mode == "ring" else {}
	var unpinned: Array = []
	var grid := {}
	for it: Dictionary in alg.items:
		var key := String(it.key)
		var p: Variant = null
		if mode == "ring":
			var pk := key if String(it.type) == "root" else String(it.ids[0])
			if pn.has(pk):
				p = pn[pk]
			if String(it.type) == "choice":
				for id: String in it.ids:
					if not pn.has(id):
						unpinned.append(id)
			elif p == null:
				unpinned.append(pk)
		var at: Vector2 = alg.places[key] if p == null else p
		grid[key] = at
		it["col"] = at.x
		it["row"] = at.y
	if not unpinned.is_empty():
		push_warning("AdvancementLayout: %s %s has no pin for %s: run tools/ui/advancement_layout.py" % [el, side, ", ".join(PackedStringArray(unpinned))])
	var L := AdvancementData.layout()
	# ring mode's pins are the diamond lattice: its own pitch limits (layout.lattice), else the band grid's
	var lat: Dictionary = L.get("lattice", {}) if mode == "ring" and L.get("lattice") is Dictionary else {}
	var lim := func(k: String, def: float) -> float: return float(lat.get(k, L.get(k, def)))
	var zone := AdvancementData.zone(side)
	var icon: float = lim.call("icon", 46.0)
	var px := float(L.get("pitch_x", 64))
	var py := float(L.get("pitch_y", 70))
	var top_pad := float(L.get("top_pad", 0))
	var fm: Array = L.get("fill_margin", [0, 0, 0]) if L.get("fill_margin") is Array else [0, 0, 0]
	var m_side := float(fm[0]) if fm.size() > 0 else 0.0
	var m_top := float(fm[1]) if fm.size() > 1 else 0.0
	var m_bottom := float(fm[2]) if fm.size() > 2 else 0.0
	var size := Vector2.ZERO
	if not grid.is_empty():
		var c0 := INF
		var c1 := -INF
		var r0 := INF
		var r1 := -INF
		for k: String in grid:
			var g: Vector2 = grid[k]
			c0 = minf(c0, g.x)
			c1 = maxf(c1, g.x)
			r0 = minf(r0, g.y)
			r1 = maxf(r1, g.y)
		var avail_w := zone.size.x - m_side * 2.0
		var avail_h := zone.size.y - top_pad - m_top - m_bottom
		if r1 > r0:
			py = clampf((avail_h - icon) / (r1 - r0), lim.call("min_pitch_y", 54.0), lim.call("max_pitch_y", 1000.0))
		if c1 > c0:
			px = clampf((avail_w - icon) / (c1 - c0), lim.call("min_pitch_x", 52.0), lim.call("max_pitch_x", 1000.0))
			if r1 > r0:
				px = maxf(minf(px, py * lim.call("max_aspect", 1000.0)), lim.call("min_pitch_x", 52.0))
		size = Vector2((c1 - c0) * px + icon, (r1 - r0) * py + icon)
		var ox := (zone.size.x - size.x) / 2.0 + icon / 2.0 - c0 * px
		var oy := top_pad + m_top + (avail_h - size.y) / 2.0 + icon / 2.0 - r0 * py
		for it: Dictionary in alg.items:
			var g: Vector2 = grid[it.key]
			it["pos"] = Vector2(ox + g.x * px, oy + g.y * py)
	var by_key := {}
	var by_id := {}
	for i in (alg.items as Array).size():
		var it: Dictionary = alg.items[i]
		by_key[it.key] = i
		for id: String in it.ids:
			by_id[id] = it.key
	var links: Array = []
	for l: Array in alg.links:
		links.append({"from": l[0], "to": l[1], "a": alg.items[by_key[l[0]]].pos, "b": alg.items[by_key[l[1]]].pos})
	var diamond := not lat.is_empty()
	var decor: Array = _lattice_decor(alg, grid) if diamond else _decor(alg, grid)
	var bands: Array = []
	var gates: Array = []
	var every := bool(AdvancementData.switch("gate_every_band", false))
	for b: Dictionary in alg.bands:
		var bi := bands.size()
		var top_y := INF
		var twist_y := INF
		var x0 := INF
		var x1 := -INF
		for it: Dictionary in alg.items:
			if int(it.band) != bi:
				continue
			var p: Vector2 = it.pos
			top_y = minf(top_y, p.y)
			x0 = minf(x0, p.x - icon / 2.0)
			x1 = maxf(x1, p.x + icon / 2.0)
			if int(it.tier) >= 2:
				twist_y = minf(twist_y, p.y)
		var tw := twist_y if twist_y < INF else -1.0
		bands.append({"index": bi, "lines": b.lines, "rows": b.rows, "top_y": top_y, "twist_y": tw, "x0": x0, "x1": x1})
		if bi == 0:
			gates.append({"type": "first_win", "band": bi, "y": top_y, "x0": x0, "x1": x1})
		if tw >= 0.0 and (every or gates.size() < 2) and not diamond:
			gates.append({"type": "full", "band": bi, "y": tw, "x0": x0, "x1": x1})
	if diamond and not (alg.items as Array).is_empty():
		# the lattice mixes the rows: the first-win gate stands at the top row (it shuts everything), the lessons gate at the
		# first row holding a pick it shuts (each such pick also wears the gate's padlock: AdvancementNode.gate_num)
		var kinds: Array = AdvancementData.switch("full_lessons_kinds", [])
		var top_y := INF
		var gate_y := INF
		var gx0 := INF
		var gx1 := -INF
		for it: Dictionary in alg.items:
			var p: Vector2 = it.pos
			top_y = minf(top_y, p.y)
			gx0 = minf(gx0, p.x - icon / 2.0)
			gx1 = maxf(gx1, p.x + icon / 2.0)
			if String(it.type) != "root" and String(AdvancementData.node(String(it.ids[0])).get("kind", "")) in kinds:
				gate_y = minf(gate_y, p.y)
		gates = [{"type": "first_win", "band": 0, "y": top_y, "x0": gx0, "x1": gx1}]
		if gate_y < INF:
			gates.append({"type": "full", "band": 0, "y": gate_y, "x0": gx0, "x1": gx1})
	return {"element": el, "side": side, "mode": mode, "items": alg.items, "links": links, "decor": decor, "bands": bands, "gates": gates, "diamond": diamond,
			"zone": zone, "size": size, "pitch": Vector2(px, py), "icon": icon, "unpinned": unpinned,
			"by_id": by_id, "by_key": by_key}


## The diamond lattice's mesh (ring mode's pins): every two slots that are diagonal neighbours (one row apart, half a column
## aside) and that no real link joins already, so the tree reads as one lattice, as the reference's does. Drawn only, thin and
## dim: they hold no rule.
static func _lattice_decor(alg: Dictionary, grid: Dictionary) -> Array:
	var out: Array = []
	var linked := {}
	for l: Array in alg.links:
		linked["%s>%s" % [l[0], l[1]]] = true
		linked["%s>%s" % [l[1], l[0]]] = true
	var items: Array = alg.items
	for a: Dictionary in items:
		var ga: Vector2 = grid[a.key]
		for b: Dictionary in items:
			var gb: Vector2 = grid[b.key]
			if absf(gb.y - ga.y - 1.0) > 0.01 or absf(absf(gb.x - ga.x) - 0.5) > 0.01:
				continue
			if linked.has("%s>%s" % [a.key, b.key]):
				continue
			out.append({"from": a.key, "to": b.key, "a": a.pos, "b": b.pos})
	return out


## The lattice's cross links (see the class doc): within a band, for every pair of items in two lines, one row apart and within
## a column and a half, the diagonal from the upper to the lower on the band's even rows when the lower is to the right and on
## its odd rows when it is to the left (so the diagonals zig-zag and never cross); and between two bands, from each item of the
## upper band's last row to its two nearest items of the lower band's first row (within two columns), so the bands read as one
## lattice, not islands.
static func _decor(alg: Dictionary, grid: Dictionary) -> Array:
	var out: Array = []
	var top_of := {}
	var first_row := {}
	var last_row := {}
	var items: Array = alg.items
	for bi in (alg.bands as Array).size():
		top_of[bi] = float(alg.bands[bi].top)
		first_row[bi] = INF
		last_row[bi] = -INF
	for it: Dictionary in items:
		var bi := int(it.band)
		var row := float((grid[it.key] as Vector2).y)
		first_row[bi] = minf(float(first_row[bi]), row)
		last_row[bi] = maxf(float(last_row[bi]), row)
	for a: Dictionary in items:
		for b: Dictionary in items:
			if int(a.band) != int(b.band) or int(a.line) == int(b.line):
				continue
			var ga: Vector2 = grid[a.key]
			var gb: Vector2 = grid[b.key]
			if absf(gb.y - ga.y - 1.0) > 0.01:
				continue
			var dc := gb.x - ga.x
			if absf(dc) < 0.4 or absf(dc) > 1.55:
				continue
			var even := int(roundf(ga.y - float(top_of.get(int(a.band), 0.0)))) % 2 == 0
			if even != (dc > 0.0):
				continue
			out.append({"from": a.key, "to": b.key, "a": a.pos, "b": b.pos})
	for bi in range(0, (alg.bands as Array).size() - 1):
		for a: Dictionary in items:
			if int(a.band) != bi or absf(float((grid[a.key] as Vector2).y) - float(last_row[bi])) > 0.01:
				continue
			var near: Array = []
			for b: Dictionary in items:
				if int(b.band) != bi + 1 or absf(float((grid[b.key] as Vector2).y) - float(first_row[bi + 1])) > 0.01:
					continue
				var dc := absf((grid[b.key] as Vector2).x - (grid[a.key] as Vector2).x)
				if dc <= 2.01:
					near.append([dc, b])
			near.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
			for k in mini(2, near.size()):
				var b: Dictionary = (near[k] as Array)[1]
				out.append({"from": a.key, "to": b.key, "a": a.pos, "b": b.pos})
	return out
