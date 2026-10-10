class_name AdvancementTip
extends Control
## The window's tooltip: a stone plate with a gold edge that follows the node under the pointer (or the focus) and stays on
## the window. Text is drawn and measured here (not Labels), so its size is known the moment it is set and it can be
## placed in the same frame. A node's tip comes in two sizes: the SHORT one (the default, 2026-10-10 repair of "long
## tooltips": the name; "Twist · 2 points · Boulder" with " · Plays in matches" in green when it does; ONE line of effect,
## the first sentence in gold; ONE line of numbers, "+ plus" green then "- minus" red; then the action: "Click to wear"
## (green), "Right click to take off" (grey) or the reason it cannot be worn (red). Every line keeps its one size (pass 2: a
## line shrunk to fit read as a bug beside its neighbours): the effect wraps to two lines before it is cut with an ellipsis,
## the numbers go on two lines (plus, then minus) when one is too short; the rank is on the plate) and the FULL one (node_lines(..., true): the rank, the
## whole effect, the help line, "How he answers it", the set, "Not with" and "Needs"), which the window shows while Shift is
## held or after the pointer or focus has stayed layout.tip_full_s (1.6 s).
##
##   show_lines(lines, anchor, bounds, width, avoid)    lines from node_lines / choice_lines / root_lines / trait_lines;
##       the tip stands beside the anchor where it covers none of the `avoid` rects (the trees' plates), else where it covers
##       the least (pass 2: tips hid the capstone below or the next plate's badge)
##   hide_tip()

const WIDTH := 440.0
const WIDTH_SHORT := 372.0
const PAD := 16.0
## The longest effect sentence the short tip shows (characters; the full tip has the rest).
const SHORT_EFFECT := 92
## The longest effect text the full tip shows (the sentences that fit; a skill set's draft runs to a paragraph).
const FULL_EFFECT := 520

var _lines: Array = []
var _box := StyleBoxTexture.new()
var _content := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 100
	_box = AdvancementTheme.stone(Color(0.085, 0.095, 0.12, 0.98), Color(0.055, 0.062, 0.08, 0.98))


## A line: {text, col, kind (a font kind), px, gap (space above)}. `one`: kept to one line (cut with an ellipsis to fit).
static func line(text: String, col: Color, kind := "body", px := AdvancementTheme.S_BODY, gap := 5.0, one := false) -> Dictionary:
	return {"text": text, "col": col, "kind": kind, "px": px, "gap": gap, "one": one}


## A line wrapped to at most `n` lines, cut with an ellipsis past them.
static func lines_max(text: String, col: Color, n: int, kind := "body", px := AdvancementTheme.S_BODY, gap := 5.0) -> Dictionary:
	return {"text": text, "col": col, "kind": kind, "px": px, "gap": gap, "one": false, "max_lines": n}


## `text` cut (whole words, then an ellipsis) so it wraps to at most `n` lines of `w` pixels.
static func fit_lines(f: Font, text: String, w: float, px: int, n: int) -> String:
	var limit := f.get_height(px) * float(n) + 1.0
	if f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, px).y <= limit:
		return text
	var words := text.split(" ")
	while words.size() > 1:
		words.remove_at(words.size() - 1)
		var t := " ".join(words).trim_suffix(",").trim_suffix(";").trim_suffix(".") + "…"
		if f.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, w, px).y <= limit:
			return t
	return fit_text(f, text, w, px)


## One line made of coloured parts ([[text, colour], ...]), kept to one line: the longest part is cut first. `text` is the
## parts joined (what a test reads).
static func parts_line(parts: Array, kind := "body", px := AdvancementTheme.S_BODY, gap := 5.0) -> Dictionary:
	var t := ""
	for p: Array in parts:
		t += String(p[0])
	return {"text": t, "parts": parts, "col": AdvancementTheme.INK, "kind": kind, "px": px, "gap": gap, "one": true}


## `text` cut to `w` pixels with an ellipsis (whole words first).
static func fit_text(f: Font, text: String, w: float, px: int) -> String:
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= w:
		return text
	var words := text.split(" ")
	while words.size() > 1:
		words.remove_at(words.size() - 1)
		var t := " ".join(words).trim_suffix(",").trim_suffix(";").trim_suffix(".") + "…"
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= w:
			return t
	var s := text
	while s.length() > 1 and f.get_string_size(s + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > w:
		s = s.substr(0, s.length() - 1)
	return s + "…"


## Cut a parts line to `w`: the longest part loses words until the whole fits.
static func _fit_parts(f: Font, parts: Array, w: float, px: int) -> Array:
	var out: Array = []
	for p: Array in parts:
		out.append([String(p[0]), p[1]])
	for _i in 12:
		var total := 0.0
		var longest := -1
		var lw := 0.0
		for i in out.size():
			var pw := f.get_string_size(String(out[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			total += pw
			if pw > lw:
				lw = pw
				longest = i
		if total <= w or longest < 0:
			break
		out[longest][0] = fit_text(f, String(out[longest][0]), maxf(lw - (total - w), 24.0), px)
	return out


func show_lines(lines: Array, anchor: Rect2, bounds: Rect2, width := WIDTH, avoid: Array = []) -> void:
	_lines = []
	var w := width - PAD * 2.0
	# a parts line too long for one line goes on one line per part (the numbers: plus, then minus), each at its own size
	for l: Dictionary in lines:
		if l.has("parts") and (l.parts as Array).size() > 1:
			var f0 := AdvancementTheme.font(String(l.kind))
			var whole := 0.0
			for p: Array in l.parts:
				whole += f0.get_string_size(String(p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(l.px)).x
			if whole > w and bool(l.get("split", false)):
				var first := true
				for p: Array in l.parts:
					_lines.append(parts_line([[String(p[0]).strip_edges(), p[1]]], String(l.kind), int(l.px), float(l.gap) if first else 1.0))
					first = false
				continue
		_lines.append(l)
	var y := PAD
	var widest := 0.0
	for l: Dictionary in _lines:
		var f := AdvancementTheme.font(String(l.kind))
		var px := int(l.px)
		var sz: Vector2
		if l.has("max_lines"):
			l["text"] = fit_lines(f, String(l.text), w, px, int(l.max_lines))
		if l.has("parts"):
			l["fit"] = _fit_parts(f, l.parts, w, px)
			var tw := 0.0
			for p: Array in l.fit:
				tw += f.get_string_size(String(p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			sz = Vector2(tw, f.get_height(px))
		elif bool(l.get("one", false)):
			l["shown"] = fit_text(f, String(l.text), w, px)
			sz = Vector2(f.get_string_size(String(l.shown), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x, f.get_height(px))
		else:
			sz = f.get_multiline_string_size(String(l.text), HORIZONTAL_ALIGNMENT_LEFT, w, px)
		l["y"] = y + (float(l.gap) if y > PAD else 0.0)
		l["h"] = sz.y
		y = float(l.y) + sz.y
		widest = maxf(widest, sz.x)
	_content = Vector2(clampf(widest + PAD * 2.0, 220.0, width), y + PAD)
	size = _content
	position = place(size, anchor, bounds, avoid)
	visible = true
	queue_redraw()


## Where a tip of `sz` stands: beside the anchor (right, left, then right or left rising from its bottom, then below, above)
## at the first place inside `bounds` that covers none of the `avoid` rects; else the place that covers the least.
static func place(sz: Vector2, anchor: Rect2, bounds: Rect2, avoid: Array = []) -> Vector2:
	var cands: Array = [
		Vector2(anchor.end.x + 14.0, anchor.position.y - 10.0),
		Vector2(anchor.position.x - 14.0 - sz.x, anchor.position.y - 10.0),
		Vector2(anchor.end.x + 14.0, anchor.end.y + 10.0 - sz.y),
		Vector2(anchor.position.x - 14.0 - sz.x, anchor.end.y + 10.0 - sz.y),
		Vector2(anchor.get_center().x - sz.x * 0.5, anchor.end.y + 12.0),
		Vector2(anchor.get_center().x - sz.x * 0.5, anchor.position.y - 12.0 - sz.y),
	]
	# and the first two slid along their row until they clear the plates beside the anchor (the gap between the trees)
	for k in 2:
		var c0: Vector2 = cands[k]
		var band := Rect2(Vector2(bounds.position.x, c0.y), Vector2(bounds.size.x, sz.y))
		var edge := anchor.end.x if k == 0 else anchor.position.x
		var grew := true
		var steps := 0
		while grew and steps < 8:
			grew = false
			steps += 1
			for a: Rect2 in avoid:
				if not a.intersects(band):
					continue
				if k == 0 and a.position.x < edge + 8.0 + sz.x and a.end.x > edge:
					edge = a.end.x
					grew = true
				elif k == 1 and a.end.x > edge - 8.0 - sz.x and a.position.x < edge:
					edge = a.position.x
					grew = true
		cands.append(Vector2(edge + 8.0, c0.y) if k == 0 else Vector2(edge - 8.0 - sz.x, c0.y))
	var best := Vector2.ZERO
	var best_cost := INF
	for i in cands.size():
		var c: Vector2 = cands[i]
		c.x = clampf(c.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - sz.x))
		c.y = clampf(c.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - sz.y))
		var r := Rect2(c, sz)
		if r.grow(-2.0).intersects(anchor):
			continue
		var cost := 0.0
		for a: Rect2 in avoid:
			if a.intersects(r):
				cost += r.intersection(a).get_area() + 400.0
		# (a little for each step down the list, so a free place nearer the anchor's right wins)
		cost += float(i) * 0.01
		if cost < best_cost:
			best_cost = cost
			best = c
	if best_cost == INF:
		best = Vector2(clampf(anchor.end.x + 14.0, bounds.position.x, maxf(bounds.position.x, bounds.end.x - sz.x)), clampf(anchor.position.y - 10.0, bounds.position.y, maxf(bounds.position.y, bounds.end.y - sz.y)))
	return best


func hide_tip() -> void:
	visible = false
	_lines = []


func _draw() -> void:
	if _lines.is_empty():
		return
	# a soft drop shadow, then the plate
	draw_rect(Rect2(Vector2(3, 5), size), Color(0, 0, 0, 0.35))
	draw_style_box(_box, Rect2(Vector2.ZERO, size))
	var w := size.x - PAD * 2.0
	for l: Dictionary in _lines:
		var f := AdvancementTheme.font(String(l.kind))
		var px := int(l.px)
		var at := Vector2(PAD, float(l.y) + f.get_ascent(px))
		if l.has("fit"):
			for p: Array in l.fit:
				f.draw_string(get_canvas_item(), at, String(p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, px, p[1])
				at.x += f.get_string_size(String(p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		elif l.has("shown"):
			f.draw_string(get_canvas_item(), at, String(l.shown), HORIZONTAL_ALIGNMENT_LEFT, -1, px, l.col)
		else:
			f.draw_multiline_string(get_canvas_item(), at, String(l.text), HORIZONTAL_ALIGNMENT_LEFT, w, px, -1, l.col)


# --- the lines of each kind of thing ---------------------------------------------------------------------------------------

static func _c(name: String) -> Color:
	return AdvancementData.color(name)


static func _kind_line(n: Dictionary) -> String:
	var cost := int(n.get("cost", 0))
	var kw := String(n.get("kind_word", ""))
	var t := kw
	if cost > 0:
		t = AdvancementData.word("tip.kind_cost_one" if cost == 1 else "tip.kind_cost_many") % [kw, cost]
	var ml := String(n.get("move_label", ""))
	if ml != "":
		t = AdvancementData.word("tip.on_move") % [t, ml]
	return t


## The lines of one node: `state` is AdvancementTree.state_of; `work` gives the reason it cannot be worn. `full` is the long
## tip (see the header); the short one is the default.
static func node_lines(id: String, state: String, work: AdvancementLoadout, full := false) -> Array:
	var n := AdvancementData.node(id)
	var out: Array = []
	if n.is_empty():
		return out
	out.append(line(String(n.name), AdvancementTheme.INK, "head", AdvancementTheme.S_TIP_TITLE, 0.0))
	if not full:
		# the short tip (the default): what it is, ONE line of what it does, ONE line of its numbers, then the action
		var head: Array = [[_kind_line(n), _c("text_dim")]]
		if AdvancementData.is_live(id):
			head.append([AdvancementData.word("status.sep", " · ") + AdvancementData.word("tip.live"), _c("live")])
		out.append(parts_line(head, "body", AdvancementTheme.S_BODY, 2.0))
		var fx1 := String(n.effect)
		if fx1 != "":
			out.append(lines_max(AdvancementData.first_sentence(fx1, SHORT_EFFECT), _c("effect"), 2, "body", AdvancementTheme.S_BODY, 8.0))
		var nums: Array = []
		if String(n.plus) != "":
			nums.append(["+ " + String(n.plus), _c("plus")])
		if String(n.minus) != "":
			nums.append([("   " if not nums.is_empty() else "") + "- " + String(n.minus), _c("minus")])
		if not nums.is_empty():
			var nl := parts_line(nums, "body2", AdvancementTheme.S_BODY, 3.0)
			nl["split"] = true
			out.append(nl)
		out.append_array(_action(id, state, work))
		return out
	out.append(line(_kind_line(n), _c("text_dim"), "body", AdvancementTheme.S_BODY, 2.0))
	if state != "held":
		var rk := 1 if state in ["worn", "pending_on"] else 0
		out.append(line(AdvancementData.word("tip.rank") % [rk, 1], _c("text"), "body", AdvancementTheme.S_BODY, 2.0))
	var fx := String(n.effect)
	if fx != "":
		out.append(line(AdvancementData.sentences_up_to(fx, FULL_EFFECT) if full else AdvancementData.first_sentence(fx, SHORT_EFFECT), _c("effect"), "body", AdvancementTheme.S_BODY, 8.0))
	if String(n.plus) != "":
		out.append(line("+ " + String(n.plus), _c("plus"), "body2", AdvancementTheme.S_BODY, 4.0))
	if String(n.minus) != "":
		out.append(line("- " + String(n.minus), _c("minus"), "body2", AdvancementTheme.S_BODY, 2.0))
	var kind := String(n.kind)
	if full:
		var help := String(n.help)
		if help != "" and not help.begins_with("Held:"):
			out.append(line(help, _c("text"), "body", AdvancementTheme.S_BODY, 8.0))
		if String(n.answer) != "" and kind in ["variation", "new_skill"]:
			# the counter-play under its own small heading, so the answer reads as one clause (pass 2: "How he answers it:
			# Unchanged for him: ..." ran two colons together)
			out.append(line(AdvancementData.word("tip.answer"), Color(_c("effect"), 0.8), "body2", AdvancementTheme.S_SMALL, 8.0))
			out.append(line(String(n.answer), _c("text_dim"), "body", AdvancementTheme.S_BODY, 1.0))
		if String(n.set) != "":
			out.append(line(AdvancementData.word("tip.set_twist") % AdvancementData.set_label(String(n.el)), AdvancementTheme.set_tint(String(n.set)), "body", AdvancementTheme.S_BODY, 6.0))
		var ex: Array = []
		for e: String in n.excludes:
			ex.append(AdvancementData.name_of(e))
		if not ex.is_empty():
			out.append(line(AdvancementData.word("tip.not_with") % ", ".join(PackedStringArray(ex)), _c("text_dim"), "body", AdvancementTheme.S_BODY, 6.0))
		var rq: Array = []
		for r: String in n.requires:
			rq.append(AdvancementData.name_of(r))
		if not rq.is_empty():
			out.append(line(AdvancementData.word("tip.needs") % ", ".join(PackedStringArray(rq)), _c("text_dim"), "body", AdvancementTheme.S_BODY, 2.0))
	if AdvancementData.is_live(id):
		out.append(line(AdvancementData.word("tip.live"), _c("live"), "body2", AdvancementTheme.S_BODY, 6.0))
	out.append_array(_action(id, state, work))
	return out


static func _action(id: String, state: String, work: AdvancementLoadout) -> Array:
	var out: Array = []
	var gap := 10.0
	match state:
		"pending_on":
			out.append(line(AdvancementData.word("tip.pending_on"), _c("pending_on"), "body2", AdvancementTheme.S_BODY, gap))
			out.append(line(AdvancementData.word("tip.take_off"), _c("blocked"), "body", AdvancementTheme.S_BODY, 2.0))
		"pending_off":
			out.append(line(AdvancementData.word("tip.pending_off"), _c("pending_off"), "body2", AdvancementTheme.S_BODY, gap))
			out.append(line(AdvancementData.word("tip.wear"), _c("available"), "body", AdvancementTheme.S_BODY, 2.0))
		"worn":
			out.append(line(AdvancementData.word("tip.take_off"), _c("blocked"), "body2", AdvancementTheme.S_BODY, gap))
		"available":
			out.append(line(AdvancementData.word("tip.wear"), _c("available"), "body2", AdvancementTheme.S_BODY, gap))
		"held":
			var why := work.why_not(id)
			out.append(line(why if why != "" else AdvancementData.word("tip.held"), _c("held"), "body2", AdvancementTheme.S_BODY, gap))
		_:
			var why2 := work.why_not(id)
			out.append(line(why2 if why2 != "" else AdvancementData.word("reasons.unknown"), _c("reason"), "body2", AdvancementTheme.S_BODY, gap))
	return out


## A choice: its options, each with its state, then how to choose.
static func choice_lines(ids: Array, states: Dictionary, work: AdvancementLoadout) -> Array:
	var out: Array = []
	out.append(line(AdvancementData.word("tip.choice"), AdvancementTheme.INK, "head", AdvancementTheme.S_TIP_TITLE, 0.0))
	var any_worn := false
	var first_reason := ""
	for id: String in ids:
		var n := AdvancementData.node(id)
		var st := String(states.get(id, "blocked"))
		var col := _c("text")
		match st:
			"worn", "pending_on":
				col = _c("worn")
				any_worn = true
			"available":
				col = _c("available")
			"held", "blocked", "pending_off":
				col = _c("blocked")
				if first_reason == "" and st != "pending_off":
					first_reason = work.why_not(id)
		# one line per option: its name in its state's colour, what it is after it
		var cost := int(n.get("cost", 0))
		var what := String(n.get("kind_word", ""))
		if cost > 0:
			what = AdvancementData.word("tip.kind_cost_one" if cost == 1 else "tip.kind_cost_many") % [what, cost]
		out.append(parts_line([[String(n.name), col], [AdvancementData.word("status.sep", " · ") + what, _c("text_dim")]], "body2", AdvancementTheme.S_BODY, 6.0))
	if any_worn:
		out.append(line(AdvancementData.word("tip.take_off"), _c("blocked"), "body", AdvancementTheme.S_BODY, 10.0))
	var can := false
	for id: String in ids:
		if String(states.get(id, "")) in ["available", "pending_off"]:
			can = true
	if can:
		out.append(line(AdvancementData.word("tip.choose"), _c("available"), "body2", AdvancementTheme.S_BODY, 2.0 if any_worn else 10.0))
	elif first_reason != "":
		out.append(line(first_reason, _c("reason"), "body2", AdvancementTheme.S_BODY, 10.0))
	return out


## A root: a move you already have (or the element's passive).
static func root_lines(item: Dictionary, el: String) -> Array:
	var out: Array = []
	var chip := String(item.get("chip", ""))
	var name := ""
	var line_text := AdvancementData.word("tip.root_line")
	if chip == "passive":
		name = String(AdvancementData.passive_of(el).get("label", ""))
		line_text = AdvancementData.word("tip.passive_root_line")
	else:
		name = AdvancementData.move_label(String(item.get("move", "")), String(item.get("mode", "")))
	out.append(line(name, AdvancementTheme.INK, "head", AdvancementTheme.S_TIP_TITLE, 0.0))
	var sub := AdvancementData.word("tip.root")
	if chip != "passive":
		sub = AdvancementData.word("tip.on_move") % [sub, AdvancementData.word("tip.root_key") % AdvancementData.key_badge(chip)]
	out.append(line(sub, _c("text_dim"), "body", AdvancementTheme.S_BODY, 2.0))
	out.append(line(line_text, _c("text"), "body", AdvancementTheme.S_BODY, 8.0))
	return out


## A class trait of the rail: granted, costing nothing.
static func trait_lines(tr: Dictionary) -> Array:
	var out: Array = []
	out.append(line(String(tr.get("label", "")), AdvancementTheme.INK, "head", AdvancementTheme.S_TIP_TITLE, 0.0))
	if String(tr.get("move_label", "")) != "":
		out.append(line(String(tr.move_label), _c("text_dim"), "body", AdvancementTheme.S_BODY, 2.0))
	if String(tr.get("line", "")) != "":
		out.append(line(String(tr.line), _c("text"), "body", AdvancementTheme.S_BODY, 8.0))
	if String(tr.get("perfect", "")) != "":
		out.append(line(AdvancementData.word("rail.perfect") % String(tr.perfect), _c("effect"), "body", AdvancementTheme.S_BODY, 6.0))
	out.append(line(AdvancementData.word("tip.class_trait"), _c("worn"), "body2", AdvancementTheme.S_BODY, 10.0))
	return out


## A plain few lines (a button's help, the points readout).
static func plain_lines(title: String, text := "") -> Array:
	var out: Array = [line(title, AdvancementTheme.INK, "head", AdvancementTheme.S_LABEL + 2, 0.0)]
	if text != "":
		out.append(line(text, _c("text"), "body", AdvancementTheme.S_BODY, 6.0))
	return out
