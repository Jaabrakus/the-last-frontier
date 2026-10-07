class_name MatchScreen
extends CanvasLayer
## Tidebreak's match-end screen (the plan's T13): when the match is decided (RingMode phase DONE), in the pause menu's look
## (MenuUI: a dark veil, the rows at the left), the ring still behind it. The game is not paused under it: the player is held
## (RingMode._done) and the mouse is free while it stands.
##   Victory / Defeat / A drawn match          the result, and the line under it ("The Tide takes the match")
##   You 2  :  1 Tide                          the score
##   Round 1  ·  yours  ·  into the water at 1:12   a line for each round (RingMode.history: who took it, how, when)
##   The match  ·  your casts 31  ·  catches 4  ·  knock-backs 9
##   Rematch                                   the same setup, the score nil (RingMode.restart)
##   Your element:  Earth                      steps through the elements: for the rematch, nothing restarts until then
##   Opponent:  Tide                           steps through the elements and Any: for the rematch
##   Main menu                                 back to the title
## Every word from data/ring/screens.json "match" (MatchSetup.screens). Esc still opens the ring's menu over it.
##   MatchScreen.install(parent, mode); lines() -> {head, line, score, rounds [..], totals}; rematch(), cycle_element(),
##   cycle_opponent(), to_menu(); is_open()
## Round 4 (IMPACT): it waits for the ring-out moment (RingMoment.busy(): the slow beat on a game's last fall) before it
## opens.

const LAYER := 80
const MENU_SCENE := "res://scenes/main_menu.tscn"

var match_mode: Node
var _root: Control
var _head: Label
var _line: Label
var _score: Label
var _rounds: VBoxContainer
var _totals: Label
var _items: VBoxContainer
var _rematch: Button
var _elem: Button
var _foe: Button
## Round 4: DONE came while the ring-out moment ran: opened when it ends.
var _waiting := false


static func install(parent: Node, m: Node) -> MatchScreen:
	var ms := MatchScreen.new()
	ms.name = "MatchScreen"
	ms.match_mode = m
	parent.add_child(ms)
	return ms


## A match word (screens.json match.<key>).
static func w(key: String) -> String:
	return String((MatchSetup.screens().get("match", {}) as Dictionary).get(key, key))


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.015, 0.01, 0.45)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(veil)
	var shade := MenuUI.left_shade(0.88)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.anchor_right = 0.62
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.offset_left = 88
	left.offset_top = 80
	left.offset_right = 88 + 640
	_root.add_child(left)
	_head = MenuUI.label("", 52, MenuUI.INK)
	left.add_child(_head)
	_line = MenuUI.label("", 20, MenuUI.DIM)
	left.add_child(_line)
	_score = MenuUI.label("", 30, MenuUI.GOLD)
	left.add_child(_score)
	left.add_child(_gap(10))
	_rounds = VBoxContainer.new()
	_rounds.add_theme_constant_override("separation", 2)
	left.add_child(_rounds)
	left.add_child(_gap(6))
	_totals = MenuUI.label("", 17, MenuUI.INK.lerp(MenuUI.GOLD, 0.3), true)
	left.add_child(_totals)
	left.add_child(_gap(22))
	_items = VBoxContainer.new()
	_items.add_theme_constant_override("separation", 2)
	left.add_child(_items)
	_rematch = _row(w("rematch"), rematch, w("rematch_line"))
	_rematch.name = "Rematch"
	_elem = _row("", cycle_element, w("element_line"))
	_elem.name = "Element"
	_foe = _row("", cycle_opponent, w("opponent_line"))
	_foe.name = "Opponent"
	var mm := _row(w("main_menu"), to_menu, w("main_menu_line"))
	mm.name = "MainMenu"
	if match_mode != null and match_mode.has_signal(&"phase_changed"):
		match_mode.connect(&"phase_changed", _on_phase)


static func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	return g


func _row(text: String, what: Callable, sub_line := "") -> Button:
	var b := MenuUI.item(text, 28, sub_line)
	b.pressed.connect(what)
	_items.add_child(b)
	return b


func is_open() -> bool:
	return _root != null and _root.visible


func _on_phase(ph: String) -> void:
	_waiting = false
	if ph == "DONE" and not bool(match_mode.get(&"practice")):
		if RingMoment.busy():
			_waiting = true
		else:
			open()
	elif _root.visible:
		close()


func open() -> void:
	_paint()
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rematch.grab_focus.call_deferred()


func close() -> void:
	_root.visible = false


## The mouse kept free while it stands (the ring's Esc menu takes it back as it closes).
func _process(_dt: float) -> void:
	if _waiting and not RingMoment.busy():
		_waiting = false
		if String(match_mode.get(&"phase")) == "DONE":
			open()
	if not _root.visible or get_tree().paused:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ---------------------------------------------------------------- the rows
## The same setup again (with the element and opponent chosen here), the score nil, round 1.
func rematch() -> void:
	close()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	MatchSetup.save()
	if match_mode != null and match_mode.has_method(&"restart"):
		match_mode.call(&"restart")


## The player's next element for the rematch (nothing restarts until Rematch).
func cycle_element() -> void:
	var list := Bending.ELEMENTS
	MatchSetup.element = String(list[(list.find(MatchSetup.element) + 1) % list.size()])
	_paint_rows()


## The opponent's next element for the rematch, Any among them.
func cycle_opponent() -> void:
	var list: Array = Bending.ELEMENTS.duplicate()
	list.append(MatchSetup.ANY)
	MatchSetup.foes = [String(list[(list.find(MatchSetup.foe()) + 1) % list.size()])]
	MatchSetup.quick = false                 # (chosen here: the kept setup may take it)
	_paint_rows()


func to_menu() -> void:
	close()
	get_tree().paused = false
	MatchSetup.leave()
	get_tree().change_scene_to_file(MENU_SCENE)


# ---------------------------------------------------------------- the words
func _paint() -> void:
	var l := lines()
	_head.text = String(l.head)
	_line.text = String(l.line)
	_score.text = String(l.score)
	for c in _rounds.get_children():
		_rounds.remove_child(c)
		c.queue_free()
	for r: String in l.rounds:
		_rounds.add_child(MenuUI.label(r, 18, MenuUI.INK))
	_totals.text = String(l.totals)
	_paint_rows()


func _paint_rows() -> void:
	RingMenu._set_row(_elem, w("element") % MatchSetup.label(MatchSetup.element))
	RingMenu._set_row(_foe, w("opponent") % MatchSetup.label(MatchSetup.foe()))


## What it says for the match just decided.
func lines() -> Dictionary:
	var out := {"head": "", "line": "", "score": "", "rounds": [], "totals": ""}
	var m := match_mode
	if m == null or not is_instance_valid(m):
		return out
	var them := String(m.call(&"foe_name"))
	var win := int(m.get(&"winner"))
	out.head = w("head_win") if win == 0 else (w("head_loss") if win == 1 else w("head_draw"))
	out.line = w("line_win") if win == 0 else (w("line_loss") % them if win == 1 else w("line_draw"))
	out.score = String(m.call(&"score_text"))
	var rows: Array = []
	if m.has_method(&"stock") and bool(m.call(&"stock")):
		return _stock_lines(m, them, out)
	for h: Dictionary in m.get(&"history"):
		rows.append(round_line(h, them))
	out.rounds = rows
	var t: Dictionary = m.call(&"match_tally", 0)
	out.totals = w("totals") % [int(t.get("casts", 0)), int(t.get("catches", 0)), int(t.get("knock_backs", 0))]
	return out


## The % match's screen (stock, spec §10.6): the lives left, a line per fall ("1:12  ·  the Tide into the water at 134%  ·
## Boulder"), and the tally: falls dealt and taken (own falls apart), % dealt, the highest % survived, the % healed, the
## longest string (hits and %), catches (clean), perfect guards, falls broken, edge saves.
func _stock_lines(m: Node, them: String, out: Dictionary) -> Dictionary:
	var rows: Array = []
	var hist: Array = m.get(&"history")
	if not hist.is_empty():
		var lv: Array = (hist.back() as Dictionary).get("lives", [0, 0])
		rows.append(w("lives_line") % [int(lv[0]), them, int(lv[1])])
	var multi := int(m.get(&"to_win")) > 1
	var player: Variant = m.get(&"player")
	for f: Dictionary in m.get(&"falls"):
		rows.append(fall_line(f, them, f.get("who") == player, multi))
	out.rounds = rows
	var t: Dictionary = m.call(&"stock_tally", 0)
	var lines := PackedStringArray()
	lines.append(w("tally_falls") % [int(t.get("falls_dealt", 0.0)), int(t.get("falls_taken", 0.0)), int(t.get("self_falls", 0.0))])
	lines.append(w("tally_pct") % [roundi(float(t.get("pct_dealt", 0.0))), roundi(float(t.get("best_pct", 0.0))),
			roundi(float(t.get("healed", 0.0)))])
	lines.append(w("tally_string") % [int(t.get("string_hits", 0)), roundi(float(t.get("string_pct", 0.0)))])
	lines.append(w("tally_guards") % [int(t.get("catches", 0.0)), int(t.get("clean_catches", 0.0)), int(t.get("perfect_guards", 0.0)),
			int(t.get("breaks", 0.0)), int(t.get("edge_saves", 0.0))])
	out.totals = "\n".join(lines)
	return out


## "1:12  ·  the Tide into the water at 134%  ·  Boulder" (a fall of the % match; `mine` the player's own; `multi` a best
## of 3: "Game 2  ·  " first).
static func fall_line(f: Dictionary, them: String, mine: bool, multi := false) -> String:
	var s := float(f.get("at_s", 0.0))
	var when := "%d:%02d" % [floori(s / 60.0), floori(fmod(s, 60.0))]
	if multi:
		when = (w("fall_game") % int(f.get("game", 1))) + "  ·  " + when
	var who := w("fall_you") if mine else w("fall_them") % them
	var how := w("fall_self") if bool(f.get("self", false)) or f.get("by") == null else move_of(String(f.get("tag", "")))
	return w("fall_line") % [when, who, roundi(float(f.get("pct", 0.0))), how]


## A move's plain name from its hit tag ("stone_form/cannonball" -> "Boulder"; ".grown" and ".return" read as the move's).
static func move_of(tag: String) -> String:
	if tag == "":
		return "-"
	var t := tag.trim_suffix(".return").trim_suffix(".grown")
	var id := t.get_slice("/", 0)
	var md := t.get_slice("/", 1) if t.contains("/") else ""
	var n := KitWords.move_name(id, md)
	return n if n != "" else t


## "Round 1  ·  yours  ·  into the water at 1:12" (a time-out's how needs no time: "ground held at the bell").
static func round_line(h: Dictionary, them: String) -> String:
	var res := String(h.get("result", "draw"))
	var who := w("who_win") if res == "win" else (w("who_loss") % them if res == "loss" else w("who_draw"))
	var why := String(h.get("why", "time"))
	var how := w("how_" + why)
	if why in ["ringout", "winded", "knockout"]:
		var s := float(h.get("at_s", 0.0))
		how = w("round_at") % [how, "%d:%02d" % [floori(s / 60.0), floori(fmod(s, 60.0))]]
	return w("round_line") % [int(h.get("round", 0)), who, how]
