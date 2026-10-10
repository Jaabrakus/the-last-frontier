class_name AdvancementTree
extends Control
## One of the window's two lattices: the nodes of AdvancementLayout.place(element, side) as AdvancementNodes, the links
## between them (a gold line when both ends are worn, grey otherwise, an arrowhead at the child), the gate stubs (an orange
## number, a padlock and a short orange line at the row a gate holds shut) and the pop-out of a choice.
##
## The window owns the picks: it keeps two AdvancementLoadouts, `work` (what the player is editing) and `saved` (the slot as
## it was last saved), hands both to every tree and calls refresh() after each change. A node's state is read from them:
##   in both worn | in work only pending_on | in saved only pending_off | neither: available (why_not = "") or blocked.
## The tree only asks: wear_requested(id) / take_off_requested(id); the window answers with the loadout and a refresh.

signal tip_wanted(node: AdvancementNode, on: bool)
signal wear_requested(id: String)
signal take_off_requested(id: String)

const POP_PAD := 10.0

var element := ""
var side := "left"
var work: AdvancementLoadout
var saved: AdvancementLoadout
var plan := {}
var nodes: Array = []            ## AdvancementNode, in item order
var _by_key := {}
var _gate := {}
var _matches: Variant = null     ## null (no search) or the ids that match
var _pop: Control
var _pop_owner: AdvancementNode
var _pop_nodes: Array = []


func setup(el: String, sd: String, w: AdvancementLoadout, s: AdvancementLoadout) -> void:
	element = el
	side = sd
	work = w
	saved = s
	plan = AdvancementLayout.place(el, sd)
	var zone: Rect2 = plan.zone
	position = zone.position
	size = zone.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var px := float(plan.icon)
	var shapes: Dictionary = AdvancementData.tree_cfg().get("shapes", {})
	for it: Dictionary in plan.items:
		var n := AdvancementNode.new()
		var typ := String(it.type)
		var shape := "root" if typ == "root" else ("octagon" if typ == "choice" else String(shapes.get(String(AdvancementData.node(String(it.ids[0])).get("kind", "")), "circle")))
		n.setup(it, el, px, shape)
		n.name = String(it.key).replace(":", "_").replace("/", "_").replace(".", "_")
		n.home = (it.pos as Vector2) - Vector2(px, px) * 0.5
		n.position = n.home
		if typ == "root":
			n.badge = AdvancementData.key_badge(String(it.chip))
		n.wear.connect(_on_wear)
		n.take_off.connect(_on_take_off)
		n.tip.connect(_on_tip)
		add_child(n)
		nodes.append(n)
		_by_key[String(it.key)] = n
	refresh()
	_wire_focus()


func node_for_id(id: String) -> AdvancementNode:
	for n: AdvancementNode in nodes:
		if id in n.ids:
			return n
	return null


## The ids of the other options of the choice `id` is in ([] for a plain node).
func rivals(id: String) -> Array:
	var n := node_for_id(id)
	if n == null or not n.is_choice():
		return []
	var out: Array = []
	for o: String in n.ids:
		if o != id:
			out.append(o)
	return out


# --- states ----------------------------------------------------------------------------------------------------------------

func state_of(id: String) -> String:
	var n := AdvancementData.node(id)
	if bool(n.get("held", false)):
		return "held"
	var w := work.has(id)
	var s := saved.has(id)
	if w and s:
		return "worn"
	if w:
		return "pending_on"
	if s:
		return "pending_off"
	return "available" if work.why_not(id) == "" else "blocked"


## One state for a group (a choice): the strongest of its members'.
func group_state(group: Array) -> Dictionary:
	var best := ""
	var best_id := ""
	# a choice some of whose options are held and the rest blocked reads held (dashed with '?'), as a held node does
	var rank := {"pending_on": 6, "worn": 5, "pending_off": 4, "available": 3, "held": 2, "blocked": 1}
	for id: String in group:
		var st := state_of(id)
		if best == "" or int(rank[st]) > int(rank[best]):
			best = st
			best_id = id
	return {"state": best, "id": best_id}


func refresh() -> void:
	_gate = AdvancementData.gate_state(element)
	for n: AdvancementNode in nodes:
		_refresh_node(n)
	if _pop != null:
		for pn: AdvancementNode in _pop_nodes:
			_refresh_node(pn)
	apply_search(_matches)
	queue_redraw()


func _refresh_node(n: AdvancementNode) -> void:
	var it := n.item
	if String(it.type) == "root":
		n.kind = ""
		n.set_id = ""
		n.hue = Color.WHITE
		n.live = false
		var pic: Texture2D
		if String(it.chip) == "passive":
			pic = AdvancementTheme.passive_root_icon(element)
		else:
			pic = BendStrip.icon_texture(String(it.move), String(it.mode))
		n.show_as("root", pic)
		return
	var g := group_state(n.ids)
	var id := String(g.id)
	var st := String(g.state)
	var nd := AdvancementData.node(id)
	n.kind = String(nd.get("kind", ""))
	n.set_id = String(nd.get("set", ""))
	# a skill set's picks (and the set's own node) wear the set's hue, the rest the element's
	var hue_set := n.set_id if n.set_id != "" else (AdvancementData.set_of(element) if n.kind == "skill_set" else "")
	n.hue = AdvancementTheme.set_tint(hue_set) if hue_set != "" else Color.WHITE
	n.live = AdvancementData.is_live(id)
	var rank := ""
	if st == "held":
		rank = "?"
	elif st in ["worn", "pending_on"]:
		rank = "1/1"
	else:
		rank = "0/1"
	n.show_as(st, AdvancementTheme.node_icon(id), rank, id)


## Dim every node but the matches (`ids`); null = no search.
func apply_search(ids: Variant) -> void:
	_matches = ids
	var all: Array = nodes.duplicate()
	all.append_array(_pop_nodes)
	for n: AdvancementNode in all:
		if ids == null:
			n.set_dim(false)
			continue
		var hit := false
		for id: String in n.ids:
			if id in (ids as Array):
				hit = true
		if String(n.item.type) == "root":
			hit = false
		n.set_dim(not hit, hit)


# --- input from the nodes --------------------------------------------------------------------------------------------------

func _on_wear(n: AdvancementNode) -> void:
	if String(n.item.type) == "root":
		return
	if n.is_choice():
		if _pop_owner == n:
			close_pop()
		else:
			open_pop(n, true)
		return
	wear_requested.emit(n.first_id())


func _on_take_off(n: AdvancementNode) -> void:
	if String(n.item.type) == "root":
		return
	if n.is_choice():
		# the worn (or pending) option comes off; with none worn, nothing
		for id: String in n.ids:
			if work.has(id):
				take_off_requested.emit(id)
				return
		return
	take_off_requested.emit(n.first_id())


func _on_tip(n: AdvancementNode, on: bool) -> void:
	if n.is_choice() and on and n.is_hovered() and not n.popped and _pop_owner != n:
		open_pop(n, false)
		return
	tip_wanted.emit(n, on and not (n.is_choice() and n.popped))


## Shake the node holding `id` (it cannot be worn).
func deny(id: String) -> void:
	var n := node_for_id(id)
	if n != null:
		n.shake()
	for pn: AdvancementNode in _pop_nodes:
		if id in pn.ids:
			pn.shake()


# --- the pop-out of a choice --------------------------------------------------------------------------------------------------

func is_popped() -> bool:
	return _pop != null


func open_pop(owner_node: AdvancementNode, focus_first: bool) -> void:
	close_pop()
	_pop_owner = owner_node
	owner_node.popped = true
	var px := float(plan.icon)
	var cnt := owner_node.ids.size()
	var gap := 8.0
	var w := float(cnt) * px + float(cnt - 1) * gap + POP_PAD * 2.0
	var h := px + POP_PAD * 2.0
	_pop = Control.new()
	_pop.mouse_filter = Control.MOUSE_FILTER_STOP
	var plate := Panel.new()
	plate.add_theme_stylebox_override("panel", AdvancementTheme.stone(Color(0.07, 0.08, 0.1, 0.96), Color(0.05, 0.055, 0.07, 0.96)))
	plate.size = Vector2(w, h)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pop.add_child(plate)
	_pop.size = Vector2(w, h)
	var c := owner_node.position + Vector2(px, px) * 0.5
	var at := Vector2(c.x - w * 0.5, owner_node.position.y - h - 6.0)
	if at.y < -30.0:
		at.y = owner_node.position.y + px + 6.0
	_pop.position = at
	add_child(_pop)
	_pop_nodes.clear()
	var shapes: Dictionary = AdvancementData.tree_cfg().get("shapes", {})
	for i in cnt:
		var id := String(owner_node.ids[i])
		var n := AdvancementNode.new()
		var kind := String(AdvancementData.node(id).get("kind", ""))
		n.setup({"type": "node", "ids": [id], "key": id}, element, px, String(shapes.get(kind, "square")))
		n.position = Vector2(POP_PAD + float(i) * (px + gap), POP_PAD)
		n.home = n.position
		n.wear.connect(_on_pop_wear)
		n.take_off.connect(_on_pop_take_off)
		n.tip.connect(_on_pop_tip)
		_pop.add_child(n)
		_pop_nodes.append(n)
		_refresh_node(n)
	apply_search(_matches)
	for i in _pop_nodes.size():
		var n: AdvancementNode = _pop_nodes[i]
		if i > 0:
			n.focus_neighbor_left = n.get_path_to(_pop_nodes[i - 1])
		if i < _pop_nodes.size() - 1:
			n.focus_neighbor_right = n.get_path_to(_pop_nodes[i + 1])
		n.focus_neighbor_top = n.get_path_to(owner_node)
		n.focus_neighbor_bottom = n.get_path_to(owner_node)
	owner_node.queue_redraw()
	tip_wanted.emit(owner_node, false)
	set_process(true)
	if focus_first and not _pop_nodes.is_empty():
		(_pop_nodes[0] as AdvancementNode).grab_focus()


## Close the pop-out; true when one was open. `refocus` puts the focus back on its octagon.
func close_pop(refocus := false) -> bool:
	if _pop == null:
		return false
	var o := _pop_owner
	_pop.queue_free()
	_pop = null
	_pop_nodes.clear()
	_pop_owner = null
	set_process(false)
	if o != null and is_instance_valid(o):
		o.popped = false
		o.queue_redraw()
		if refocus:
			o.grab_focus()
	return true


func _process(_d: float) -> void:
	if _pop == null:
		set_process(false)
		return
	# the pop-out stays while the pointer is over it or over its octagon (a little slack between them)
	var m := get_local_mouse_position()
	var r := Rect2(_pop.position, _pop.size).grow(8.0)
	if _pop_owner != null:
		r = r.merge(Rect2(_pop_owner.position, _pop_owner.size).grow(6.0))
	var focused := false
	var fo := get_viewport().gui_get_focus_owner()
	if fo != null and (fo == _pop_owner or _pop.is_ancestor_of(fo)):
		focused = true
	if not r.has_point(m) and not focused:
		close_pop()


func _on_pop_wear(n: AdvancementNode) -> void:
	wear_requested.emit(n.first_id())
	close_pop(true)


func _on_pop_take_off(n: AdvancementNode) -> void:
	take_off_requested.emit(n.first_id())


func _on_pop_tip(n: AdvancementNode, on: bool) -> void:
	tip_wanted.emit(n, on)


# --- focus -----------------------------------------------------------------------------------------------------------------

## Left / right along a row, up / down to the nearest node below or above, Tab in reading order.
func _wire_focus() -> void:
	var py := float(plan.pitch.y)
	for a: AdvancementNode in nodes:
		var ac := a.position + a.size * 0.5
		var best := {"left": null, "right": null, "up": null, "down": null}
		var score := {"left": INF, "right": INF, "up": INF, "down": INF}
		for b: AdvancementNode in nodes:
			if a == b:
				continue
			var bc := b.position + b.size * 0.5
			var d := bc - ac
			var key := ""
			var s := INF
			if absf(d.y) < py * 0.45:
				key = "right" if d.x > 0.0 else "left"
				s = absf(d.x) + absf(d.y) * 2.0
			elif absf(d.x) <= absf(d.y) * 1.6 + 8.0:
				key = "down" if d.y > 0.0 else "up"
				s = absf(d.y) + absf(d.x) * 1.4
			if key != "" and s < float(score[key]):
				score[key] = s
				best[key] = b
		if best.left != null:
			a.focus_neighbor_left = a.get_path_to(best.left)
		if best.right != null:
			a.focus_neighbor_right = a.get_path_to(best.right)
		if best.up != null:
			a.focus_neighbor_top = a.get_path_to(best.up)
		if best.down != null:
			a.focus_neighbor_bottom = a.get_path_to(best.down)
	var order: Array = nodes.duplicate()
	order.sort_custom(func(p: AdvancementNode, q: AdvancementNode) -> bool:
		if absf(p.position.y - q.position.y) > 8.0:
			return p.position.y < q.position.y
		return p.position.x < q.position.x)
	for i in order.size():
		var n: AdvancementNode = order[i]
		n.focus_next = n.get_path_to(order[(i + 1) % order.size()])
		n.focus_previous = n.get_path_to(order[(i - 1 + order.size()) % order.size()])


## The node at the middle of the tree's left or right end, for the window to join the two trees' focus.
func end_node(right: bool, near_y: float) -> AdvancementNode:
	var best: AdvancementNode = null
	var bx := -INF if right else INF
	for n: AdvancementNode in nodes:
		var x := n.position.x
		if (right and x > bx + 4.0) or (not right and x < bx - 4.0):
			bx = x
			best = n
		elif absf(x - bx) <= 4.0 and best != null and absf(n.position.y - near_y) < absf(best.position.y - near_y):
			best = n
	return best


# --- drawing ---------------------------------------------------------------------------------------------------------------

func _edge(centre: Vector2, dir: Vector2, half: float, square: bool) -> Vector2:
	if not square:
		return centre + dir * (half + 3.0)
	var m := maxf(absf(dir.x), absf(dir.y))
	return centre + dir * ((half + 3.0) / maxf(m, 0.01))


func _lit(n: AdvancementNode) -> bool:
	return n != null and n.state in ["worn", "pending_on", "root"]


func _draw() -> void:
	if plan.is_empty():
		return
	var half := float(plan.icon) * 0.5
	var worn_c := AdvancementData.color("link_worn")
	var grey := AdvancementData.color("link")
	# the lattice's cross links first: thin and dim, gold only when both ends are worn
	for l: Dictionary in plan.decor:
		var na: AdvancementNode = _by_key.get(String(l.from))
		var nb: AdvancementNode = _by_key.get(String(l.to))
		var a: Vector2 = l.a
		var b: Vector2 = l.b
		var dir := (b - a).normalized()
		var p0 := _edge(a, dir, half, na != null and na.shape in ["square", "root"])
		var p1 := _edge(b, -dir, half, nb != null and nb.shape in ["square", "root"])
		var both := _lit(na) and _lit(nb)
		draw_line(p0, p1, Color(0, 0, 0, 0.35), 3.4, true)
		draw_line(p0, p1, Color(worn_c, 0.62) if both else Color(grey, 0.34), 1.5, true)
	for l: Dictionary in plan.links:
		var na: AdvancementNode = _by_key.get(String(l.from))
		var nb: AdvancementNode = _by_key.get(String(l.to))
		var a: Vector2 = l.a
		var b: Vector2 = l.b
		var dir := (b - a).normalized()
		var p0 := _edge(a, dir, half, na != null and na.shape in ["square", "root"])
		var p1 := _edge(b, -dir, half, nb != null and nb.shape in ["square", "root"])
		var gold := _lit(na) and _lit(nb)
		var col := worn_c if gold else Color(grey, 0.6)
		draw_line(p0, p1 - dir * 4.0, Color(0, 0, 0, 0.55), 5.0, true)
		draw_line(p0, p1 - dir * 4.0, col, 2.4 if gold else 2.0, true)
		var perp := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([p1, p1 - dir * 10.0 + perp * 5.0, p1 - dir * 10.0 - perp * 5.0]), col)
	_draw_gates(half)


## The left edge of the nodes on the row at `y` (the band's own left edge when none is there).
func _row_left(y: float, half: float, def: float) -> float:
	var x := INF
	for it: Dictionary in plan.items:
		var p: Vector2 = it.pos
		if absf(p.y - y) < 8.0:
			x = minf(x, p.x - half)
	return x if x < INF else def


## A gate's stub, as the reference draws it: the number, a padlock and a thin line running to the row the gate holds shut, set on
## a soft shade of the painting (no plate).
func _draw_gates(half: float) -> void:
	var won := bool(_gate.get("won", true))
	var first := bool(_gate.get("first_win", false))
	var left := int(_gate.get("full_left", 0))
	for g: Dictionary in plan.gates:
		var num := 0
		var kind := String(g.type)
		if kind == "first_win":
			if first and not won:
				num = 1
		elif kind == "full" and bool(_gate.get("full_lessons", false)) and left > 0 and (won or not first):
			num = left
		if num <= 0:
			continue
		var y := float(g.y)
		var xs := float(g.x0)                          # the number and the padlock stand at the band's left edge...
		var xr := _row_left(y, half, xs)               # ...and the line runs on to the first node of the gated row
		var col := AdvancementData.color("gate").lightened(0.22)
		var lc := AdvancementData.color("gate_line").lightened(0.15)
		draw_texture_rect(AdvancementTheme.stub_tex(), Rect2(Vector2(xs - 140.0, y - 30.0), Vector2(150.0, 60.0)), false)
		var fnt := AdvancementTheme.font("head")
		draw_string_outline(fnt, Vector2(xs - 100.0, y + 10.0), str(num), HORIZONTAL_ALIGNMENT_RIGHT, 28.0, 30, 5, Color(0.02, 0.022, 0.03, 0.9))
		draw_string(fnt, Vector2(xs - 100.0, y + 10.0), str(num), HORIZONTAL_ALIGNMENT_RIGHT, 28.0, 30, col)
		var lock := AdvancementTheme.tex("res://assets/ui/advancement/padlock.svg")
		if lock != null:
			draw_texture_rect(lock, Rect2(Vector2(xs - 68.0, y - 10.0), Vector2(20, 20)), false, col)
		var x1 := maxf(xr - 4.0, xs - 4.0)
		draw_line(Vector2(xs - 44.0, y), Vector2(x1, y), Color(0, 0, 0, 0.5), 3.4, true)
		draw_line(Vector2(xs - 44.0, y), Vector2(x1, y), lc, 1.8, true)
