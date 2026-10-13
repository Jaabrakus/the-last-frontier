class_name RoundScreen
extends CanvasLayer
## Tidebreak's round-end screen (the plan's T13; the owner, 2026-10-05: "games not bad", "it is fun"), in the broadcast look the owner
## chose (BroadcastUI, 2026-10-10): over the ring while a round's pause runs (RingMode phase OVER), one leaning plate across the upper
## middle, the ring still to be seen around it. No replay:
##   GAME 1  TIDEBREAK · LIVES · BEST OF 3    the tags above the plate (Round 1 for the zones' rounds)
##   YOURS                                    who took the game, big, in that side's element colour (THE TIDE'S, DRAWN)
##   Into the water: the Tide has no lives..  and why: into the water, winded in the last zone, ground held at the bell, stronger
##                                            at the bell, level at the bell, a knockout
##   [YOU] 1 : 0 [TIDE]                       the score, the two sides in their elements' colours
##   YOU   3 falls dealt  39% dealt  0 catches       the game's tally (RingMode.history's last line, or the % ring's tally), yours
##   TIDE  0 falls dealt  9% dealt  0 catches        and the other side's, dimmer
##   NEXT GAME IN 6  [SPACE] NOW                (or "the match is decided" before the match screen)
## Every word from data/ring/screens.json "round" (MatchSetup.screens). It takes no input (Space is RingMode's) and draws nothing on
## or over anyone (the owner's rule: no target cues); the fight HUD gains nothing from it (its plates are put away while it shows).
##   RoundScreen.install(parent, mode); lines() -> {head, why, score, yours, theirs, next} (the tests)
## Round 4 (IMPACT): it waits for the ring-out moment (RingMoment.busy(): the slow beat on a game's last fall) before it
## shows; RingMode's OVER pause runs on meanwhile. While it shows, the HUD and the hints under it are put away
## (MenuUI.cover_hud: no plates, strip or key hints under the plate) and come back as it goes.

const LAYER := 70
## The plate's design size (BroadcastUI.DESIGN's 1600 x 900), and where it hangs from the top.
const PLATE := Vector2(1240.0, 366.0)
const TOP := 112.0
## s the plate takes to come up.
const APPEAR_S := 0.3
const SEP := "  ·  "

var match_mode: Node
var _root: Control
var _body: Control
var _next_l: Label
var _count: Label
var _bar: ColorRect
## Round 4: the phase said OVER while the ring-out moment ran: shown when it ends.
var _waiting := false
var _appear := 1.0
static var _digits := RegEx.create_from_string("\\d+")


static func install(parent: Node, m: Node) -> RoundScreen:
	var rs := RoundScreen.new()
	rs.name = "RoundScreen"
	rs.match_mode = m
	parent.add_child(rs)
	return rs


## A round word (screens.json round.<key>).
static func w(key: String) -> String:
	return String((MatchSetup.screens().get("round", {}) as Dictionary).get(key, key))


func _ready() -> void:
	layer = LAYER
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	# a soft shade across the upper middle, so the plate sits on the ring and not on the sky's glare
	BroadcastUI.grad(_root, [[0.0, Color(BroadcastUI.NAVY0, 0.0)], [0.5, Color(BroadcastUI.NAVY0, 0.42)], [1.0, Color(BroadcastUI.NAVY0, 0.0)]],
			Vector2(0.5, 0.0), Vector2(0.5, 1.0), Rect2(0.0, 0.04, 1.0, 0.56))
	var L := BroadcastUI.layout(_root)
	_body = BroadcastUI.group(L, Vector2(0.5, 0.0), Vector2(-PLATE.x * 0.5, TOP), PLATE + Vector2(0.0, 80.0))
	_body.name = "Body"
	if match_mode != null and match_mode.has_signal(&"phase_changed"):
		match_mode.connect(&"phase_changed", _on_phase)


func is_open() -> bool:
	return _root != null and _root.visible


func _on_phase(ph: String) -> void:
	var show := ph == "OVER" and not bool(match_mode.get(&"practice")) and not (_stock() and bool(match_mode.call(&"decided")))
	_waiting = show and (RingMoment.busy() or RingReplay.holding())
	_set_shown(show and not _waiting)
	if _root.visible:
		_paint()


func _process(dt: float) -> void:
	if _waiting and not RingMoment.busy() and not RingReplay.holding():
		_waiting = false
		_set_shown(String(match_mode.get(&"phase")) == "OVER")
		if _root.visible:
			_paint()
	if not _root.visible:
		return
	if _appear < 1.0:
		_appear = 1.0 if get_tree().paused else minf(_appear + dt / APPEAR_S, 1.0)
		_root.modulate.a = ease(_appear, 0.4)
	_tick()


## The band shown or not, the HUD under it put away while it shows; it comes up in APPEAR_S.
func _set_shown(v: bool) -> void:
	if v and not _root.visible:
		_appear = 0.0
		_root.modulate.a = 0.0
	_root.visible = v
	MenuUI.cover_hud(self, v)


# ---------------------------------------------------------------- the plate
## The plate drawn for the round just ended (its words are lines()'s; the sides' colours are the elements').
func _paint() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var l := lines()
	var m := match_mode
	var res := String(m.get(&"last_result")) if m != null and is_instance_valid(m) else "draw"
	var me := _element(&"element", MatchSetup.element)
	var fe := _element(&"foe_element", MatchSetup.foe())
	var mine := BroadcastUI.plate_c(me)
	var theirs := BroadcastUI.plate_c(fe)
	var them := String(m.call(&"foe_name")) if m != null and is_instance_valid(m) else ""
	var win := mine if res == "win" else (theirs if res == "loss" else BroadcastUI.DIM)
	# the plate, a teal rule along its top, the tags hanging over its left end
	var sb := BroadcastUI.box(Color(BroadcastUI.NAVY1, 0.95))
	sb.border_width_top = 5
	sb.border_color = BroadcastUI.TEAL
	var plate := Panel.new()
	plate.name = "Plate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", sb)
	# (the type is raised in a small window: the lower half of the plate moves down by what the big word and its line need more)
	var k := BroadcastUI.boost
	var dy := maxf(0.0, 48.0 + 186.0 * k + 8.0 - 238.0)
	BroadcastUI.put(_body, plate, Rect2(0.0, 40.0, PLATE.x, PLATE.y + dy - 40.0))
	var tags := BroadcastUI.hbox(0)
	var head_parts := String(l.head).split(SEP)
	var tag := BroadcastUI.tag(String(head_parts[0]), 22, BroadcastUI.INK, BroadcastUI.TEAL, 4)
	tag.name = "Tag"
	tags.add_child(tag)
	tags.add_child(BroadcastUI.tag(_tags(), 18, BroadcastUI.WHITE, Color(BroadcastUI.NAVY2, 0.95), 3))
	BroadcastUI.put(_body, tags, Rect2(46.0, 2.0, 0.0, 0.0))
	# who took it, big, in that side's colour; why under it
	var who := String(head_parts[1]) if head_parts.size() > 1 else ""
	var wl := BroadcastUI.caps(who, BroadcastUI.head(true, 3), 128, win)
	wl.name = "Who"
	BroadcastUI.fit_text(wl, 610.0, 72)
	BroadcastUI.put(_body, wl, Rect2(66.0, 48.0, 640.0, 150.0 * k))
	var why := BroadcastUI.para(String(l.why), BroadcastUI.body(true), 26, BroadcastUI.WHITE, 620.0)
	why.name = "Why"
	BroadcastUI.put(_body, why, Rect2(70.0, 48.0 + 150.0 * k, 620.0, 36.0 * k))
	# the score: the two sides' colours either side of the numbers
	var sc := Vector2i.ZERO
	if m != null and is_instance_valid(m) and m.get(&"score") is Vector2i:
		sc = m.get(&"score")
	var row := BroadcastUI.hbox(14)
	row.name = "Score"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_side(RingMode.words("you"), mine))
	row.add_child(BroadcastUI.lab(str(sc.x), BroadcastUI.head(true, 1), 104, BroadcastUI.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(BroadcastUI.lab(":", BroadcastUI.head(true, 1), 80, BroadcastUI.FAINT, HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(BroadcastUI.lab(str(sc.y), BroadcastUI.head(true, 1), 104, BroadcastUI.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(_side(them, theirs))
	BroadcastUI.put(_body, row, Rect2(700.0, 66.0, 500.0, 120.0))
	# the game's tally: yours, the other side's under it, and at their right the next game's count and the key that skips it
	BroadcastUI.rect(_body, Rect2(60.0, 238.0 + dy, PLATE.x - 120.0, 1.0), Color(BroadcastUI.LINE, 0.9))
	var y := 254.0 + dy
	for pair: Array in [[String(l.yours), mine, false], [String(l.theirs), theirs, true]]:
		var r := _tally(String(pair[0]), pair[1], bool(pair[2]))
		BroadcastUI.put(_body, r, Rect2(62.0, y, 880.0, 44.0))
		r.name = "Theirs" if bool(pair[2]) else "Yours"
		y += 50.0
	var nx := _next_block(String(l.next))
	BroadcastUI.put(_body, nx, Rect2(PLATE.x - 392.0, 248.0 + dy, 300.0, 100.0))
	_tick()


## The next game's count (its numeral big), the key that skips it and a line that runs out with the pause. The match decided: its
## words alone. The words are the data's ("next game in 5  ·  Space: now").
func _next_block(next_line: String) -> Control:
	var parts := next_line.split(SEP)
	var m := _digits.search(String(parts[0]))
	var box := BroadcastUI.vbox(4)
	box.name = "NextBlock"
	_count = null
	_bar = null
	_next_l = null
	if m == null:
		_next_l = BroadcastUI.caps(next_line, BroadcastUI.head(false, 3, 1), 26, BroadcastUI.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		_next_l.name = "Next"
		box.add_child(_next_l)
		return box
	var row := BroadcastUI.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_END
	var words := BroadcastUI.vbox(4)
	_next_l = BroadcastUI.caps(String(parts[0]).substr(0, m.get_start()).strip_edges(), BroadcastUI.head(false, 3, 1), 22, BroadcastUI.DIM)
	_next_l.name = "Next"
	words.add_child(_next_l)
	if parts.size() > 1:
		var what := String(parts[1])
		words.add_child(BroadcastUI.key_hint(what.get_slice(":", 0).strip_edges().to_upper(), what.get_slice(":", 1).strip_edges() if what.contains(":") else "", 22))
	row.add_child(words)
	_count = BroadcastUI.lab(m.get_string(), BroadcastUI.head(true, 1), 72, BroadcastUI.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_count.name = "Count"
	_count.custom_minimum_size = Vector2(56.0, 0.0)
	row.add_child(_count)
	box.add_child(row)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(BroadcastUI.LINE, 0.9)
	bar_bg.custom_minimum_size = Vector2(0.0, 5.0)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar_bg)
	_bar = ColorRect.new()
	_bar.color = BroadcastUI.TEAL
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(_bar)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return box


## A side's name on its element's colour, in the score.
static func _side(name_text: String, c: Color) -> Control:
	var l := BroadcastUI.caps(name_text, BroadcastUI.head(true, 3), 40, BroadcastUI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size = Vector2(88.0, 0.0)
	return BroadcastUI.chip(l, c, BroadcastUI.LEAN, Vector4(20.0, 8.0, 20.0, 4.0))


## A tally line as a row: the side's name on its colour, then each count as a chip (its number first, its words after).
## `dim` the other side's: a darker plate, quieter type.
static func _tally(line: String, c: Color, dim: bool) -> Control:
	var h := BroadcastUI.hbox(10)
	var parts := line.split(SEP)
	var nm := BroadcastUI.caps(String(parts[0]), BroadcastUI.head(true, 2), 22, BroadcastUI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	nm.custom_minimum_size = Vector2(150.0, 0.0)
	h.add_child(BroadcastUI.chip(nm, c if not dim else c.lerp(BroadcastUI.NAVY2, 0.35), BroadcastUI.LEAN, Vector4(14.0, 6.0, 14.0, 2.0)))
	var rx := RegEx.create_from_string("\\d+%?")
	for i in range(1, parts.size()):
		var text := String(parts[i])
		var m := rx.search(text)
		var cell := BroadcastUI.hbox(8)
		var label := text
		if m != null:
			cell.add_child(BroadcastUI.lab(m.get_string(), BroadcastUI.head(), 32, BroadcastUI.WHITE if not dim else BroadcastUI.DIM))
			label = (text.substr(0, m.get_start()) + text.substr(m.get_end())).strip_edges()
		cell.add_child(BroadcastUI.caps(label, BroadcastUI.head(false, 2, 1), 18, BroadcastUI.DIM if not dim else BroadcastUI.FAINT))
		h.add_child(BroadcastUI.chip(cell, Color(BroadcastUI.NAVY3, 0.92) if not dim else Color(BroadcastUI.NAVY2, 0.92), BroadcastUI.LEAN,
				Vector4(16.0, 3.0, 16.0, 1.0)))
	return h


## The tags' second line: the sport, the rules and the length of the match ("TIDEBREAK  ·  LIVES  ·  BEST OF 3").
func _tags() -> String:
	var m := match_mode
	if m == null or not is_instance_valid(m):
		return MatchSetup.sport()
	var stock := _stock()
	var to_win := int(m.get(&"to_win"))
	var length := (MatchSetup.rounds_label(2) if to_win > 1 else String(MatchSetup.screens().get("one_game", "one game"))) if stock \
			else MatchSetup.rounds_label(to_win)
	return SEP.join([MatchSetup.sport(), MatchSetup.rule_label("stock" if stock else "classic"), length])


## A side's element: the match's own (RingMode's element and foe_element once it is under way), else the kept setup's.
func _element(key: StringName, fallback: String) -> String:
	var v: Variant = match_mode.get(key) if match_mode != null and is_instance_valid(match_mode) else null
	return String(v) if v != null and String(v) in Bending.ELEMENTS else fallback


## The count and its bar, each frame while the plate stands.
func _tick() -> void:
	if match_mode == null or not is_instance_valid(match_mode):
		return
	if _count != null and is_instance_valid(_count):
		var m := _digits.search(String(lines().next))
		if m != null:
			_count.text = m.get_string()
	if _bar != null and is_instance_valid(_bar):
		var left := 1.0 - clampf(float(match_mode.get(&"phase_t")) / maxf(RingRules.num("pause_s", 6.0), 0.1), 0.0, 1.0)
		_bar.anchor_right = left


# ---------------------------------------------------------------- the words
## What it says for the round just ended (RingMode's last_* and its history's last line).
func lines() -> Dictionary:
	var out := {"head": "", "why": "", "score": "", "yours": "", "theirs": "", "next": ""}
	var m := match_mode
	if m == null or not is_instance_valid(m):
		return out
	var them := String(m.call(&"foe_name"))
	var res := String(m.get(&"last_result"))
	var why := String(m.get(&"last_why"))
	var rnd := int(m.get(&"round"))
	if _stock():
		return _stock_lines(m, them, res, why, rnd)
	match res:
		"win":
			out.head = w("head_win") % rnd
		"loss":
			out.head = w("head_loss") % [rnd, them]
		_:
			out.head = w("head_draw") % rnd
	var key := "why_%s_%s" % ["draw" if res == "draw" else res, why]
	if res == "draw":
		key = "why_draw_time"
	var t := w(key)
	out.why = (t % them if t.contains("%s") else t) if t != key else String(m.call(&"result_line"))
	out.score = String(m.call(&"score_text"))
	var hist: Array = m.get(&"history")
	var tally: Array = (hist.back() as Dictionary).get("tally", [{}, {}]) if not hist.is_empty() else [{}, {}]
	out.yours = w("yours") % _nums(tally[0])
	out.theirs = w("theirs") % ([them] + _nums(tally[1]))
	if bool(m.call(&"decided")):
		out.next = w("decided")
	else:
		var left := ceili(maxf(RingRules.num("pause_s", 6.0) - float(m.get(&"phase_t")), 0.0))
		out.next = w("next") % left
	return out


## The match is the % match (its rules' rule set "stock").
func _stock() -> bool:
	return match_mode != null and is_instance_valid(match_mode) and match_mode.has_method(&"stock") and bool(match_mode.call(&"stock"))


## The game screen of a best of 3 (stock): who took the game and how, the score, each side's falls dealt, % dealt and catches.
func _stock_lines(m: Node, them: String, res: String, why: String, rnd: int) -> Dictionary:
	var out := {"head": "", "why": "", "score": "", "yours": "", "theirs": "", "next": ""}
	match res:
		"win":
			out.head = w("head_game_win") % rnd
		"loss":
			out.head = w("head_game_loss") % [rnd, them]
		_:
			out.head = w("head_game_draw") % rnd
	var key := "why_%s_%s" % [res, why]
	var t := w(key)
	out.why = (t % them if t.contains("%s") else t) if t != key else String(m.call(&"result_line"))
	out.score = String(m.call(&"score_text"))
	var rr: Variant = m.get(&"rules")
	var tl: Array = (rr as RingRules).tally if rr is RingRules else [{}, {}]
	for s in 2:
		var d: Dictionary = tl[s]
		var nums := [int(d.get("falls_dealt", 0.0)), roundi(float(d.get("pct_dealt", 0.0))), int(d.get("catches", 0.0))]
		if s == 0:
			out.yours = w("yours_stock") % nums
		else:
			out.theirs = w("theirs_stock") % ([them] + nums)
	if bool(m.call(&"decided")):
		out.next = w("decided")
	else:
		out.next = w("next_game") % ceili(maxf(RingRules.num("pause_s", 6.0) - float(m.get(&"phase_t")), 0.0))
	return out


static func _nums(t: Variant) -> Array:
	var d: Dictionary = t if t is Dictionary else {}
	return [int(d.get("casts", 0)), int(d.get("catches", 0)), int(d.get("knock_backs", 0))]
