class_name RoundScreen
extends CanvasLayer
## Tidebreak's round-end screen (the plan's T13; the owner, 2026-10-05: "games not bad", "it is fun"): over the ring while a
## round's pause runs (RingMode phase OVER), a band across the upper middle, the ring still to be seen around it. No replay:
##   Round 2  ·  yours                                   who took the round (yours, the Tide's, drawn)
##   Into the water: you knocked the Tide off the end    and why: into the water, winded in the last zone, ground held at
##                                                       the bell, stronger at the bell, level at the bell, a knockout
##   You 1  :  0 Tide                                    the score
##   You  ·  casts 9  ·  catches 2  ·  knock-backs 3     the round's tally (RingMode.history's last line), the player's
##   The Tide  ·  casts 7  ·  catches 0  ·  knock-backs 1   and the other side's, dimmer
##   next round in 5  ·  Space: now                      (or "the match is decided" before the match screen)
## Every word from data/ring/screens.json "round" (MatchSetup.screens). It takes no input (Space is RingMode's) and draws
## nothing on or over anyone (the owner's rule: no target cues).
##   RoundScreen.install(parent, mode); lines() -> {head, why, score, yours, theirs, next} (the tests)
## Round 4 (IMPACT): it waits for the ring-out moment (RingMoment.busy(): the slow beat on a game's last fall) before it
## shows; RingMode's OVER pause runs on meanwhile.

const LAYER := 70

var match_mode: Node
var _root: Control
var _head: Label
var _why: Label
var _score: Label
var _yours: Label
var _theirs: Label
var _next: Label
## Round 4: the phase said OVER while the ring-out moment ran: shown when it ends.
var _waiting := false


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
	var band := ColorRect.new()
	band.color = Color(0.02, 0.015, 0.01, 0.62)
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 0.16
	band.anchor_bottom = 0.16
	band.offset_bottom = 300.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(band)
	var box := VBoxContainer.new()
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 0.16
	box.anchor_bottom = 0.16
	box.offset_top = 22.0
	box.offset_bottom = 290.0
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_head = _line(box, 46, MenuUI.INK)
	_why = _line(box, 22, MenuUI.INK.lerp(MenuUI.GOLD, 0.35))
	_score = _line(box, 30, MenuUI.GOLD)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	box.add_child(gap)
	_yours = _line(box, 21, MenuUI.INK)
	_theirs = _line(box, 18, MenuUI.INK.lerp(MenuUI.DIM, 0.5))
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 6)
	box.add_child(gap2)
	_next = _line(box, 17, MenuUI.DIM)
	if match_mode != null and match_mode.has_signal(&"phase_changed"):
		match_mode.connect(&"phase_changed", _on_phase)


func _line(box: VBoxContainer, size: int, color: Color) -> Label:
	var l := MenuUI.label("", size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return l


func is_open() -> bool:
	return _root != null and _root.visible


func _on_phase(ph: String) -> void:
	var show := ph == "OVER" and not bool(match_mode.get(&"practice")) and not (_stock() and bool(match_mode.call(&"decided")))
	_waiting = show and RingMoment.busy()
	_root.visible = show and not _waiting
	if _root.visible:
		_paint()


func _process(_dt: float) -> void:
	if _waiting and not RingMoment.busy():
		_waiting = false
		_root.visible = String(match_mode.get(&"phase")) == "OVER"
		if _root.visible:
			_paint()
	if _root.visible:
		_next.text = lines().next


func _paint() -> void:
	var l := lines()
	_head.text = String(l.head)
	_why.text = String(l.why)
	_score.text = String(l.score)
	_yours.text = String(l.yours)
	_theirs.text = String(l.theirs)
	_next.text = String(l.next)


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
