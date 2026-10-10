class_name AdvancementTip
extends Control
## The window's tooltip: a stone plate with a gold edge that follows the node under the pointer (or the focus) and stays on
## the window. Text is drawn and measured here (not Labels), so its size is known the moment it is set and it can be
## placed in the same frame. A node's tip comes in two sizes: the SHORT one (the default, 2026-10-10 repair of "long
## tooltips": the name; "Twist · 2 points · Boulder" with " · Plays in matches" in green when it does; ONE line of effect,
## the first sentence in gold; ONE line of numbers, "+ plus" green then "- minus" red; then the action: "Click to wear"
## (green), "Right click to take off" (grey) or the reason it cannot be worn (red). A one-line line that does not fit tries a
## size smaller, then is cut with an ellipsis; the rank is on the plate) and the FULL one (node_lines(..., true): the rank, the
## whole effect, the help line, "How he answers it", the set, "Not with" and "Needs"), which the window shows while Shift is
## held or after the pointer or focus has stayed layout.tip_full_s (1.6 s).
##
##   show_lines(lines, anchor, bounds, width)    lines from node_lines / choice_lines / root_lines / trait_lines
##   hide_tip()

const WIDTH := 440.0
const WIDTH_SHORT := 420.0
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


func show_lines(lines: Array, anchor: Rect2, bounds: Rect2, width := WIDTH) -> void:
	_lines = lines
	var w := width - PAD * 2.0
	var y := PAD
	var widest := 0.0
	for l: Dictionary in _lines:
		var f := AdvancementTheme.font(String(l.kind))
		var px := int(l.px)
		var sz: Vector2
		# a one-line line that does not fit tries a size smaller before it is cut
		if bool(l.get("one", false)) and not l.has("px0"):
			l["px0"] = px
		if l.has("px0"):
			px = int(l.px0)
			var whole := 0.0
			if l.has("parts"):
				for p: Array in l.parts:
					whole += f.get_string_size(String(p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			else:
				whole = f.get_string_size(String(l.text), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			if whole > w:
				px -= 2
			l["px"] = px
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
	# right of the anchor, else left of it, kept inside the bounds
	var x := anchor.end.x + 14.0
	if x + size.x > bounds.end.x:
		x = anchor.position.x - 14.0 - size.x
	x = clampf(x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - size.x))
	var yy := clampf(anchor.position.y - 10.0, bounds.position.y, maxf(bounds.position.y, bounds.end.y - size.y))
	position = Vector2(x, yy)
	visible = true
	queue_redraw()


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
			out.append(line(AdvancementData.first_sentence(fx1, SHORT_EFFECT), _c("effect"), "body", AdvancementTheme.S_BODY, 8.0, true))
		var nums: Array = []
		if String(n.plus) != "":
			nums.append(["+ " + String(n.plus), _c("plus")])
		if String(n.minus) != "":
			nums.append([("   " if not nums.is_empty() else "") + "- " + String(n.minus), _c("minus")])
		if not nums.is_empty():
			out.append(parts_line(nums, "body2", AdvancementTheme.S_BODY, 3.0))
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
			out.append(line(AdvancementData.word("tip.answer") % String(n.answer), _c("text_dim"), "body", AdvancementTheme.S_BODY, 6.0))
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
