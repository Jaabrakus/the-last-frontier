class_name MatchScreen
extends CanvasLayer
## Tidebreak's match-end screen (the plan's T13): when the match is decided (RingMode phase DONE), the results board in the
## broadcast look the owner chose (BroadcastUI, 2026-10-10), the ring still behind it softened and dimmed. The game is not paused
## under it: the player is held (RingMode._done) and the mouse is free while it stands.
##   FINAL  Victory / Defeat / A drawn match   the result, and the line under it ("The Tide takes the match")
##   the scoreboard   you and the other side in their elements' colours (your fighter's bust, the other's mark) and the games
##                    between them (2 : 1), and under it the lives left in the last game
##   Game by game     a line for each game (or round): who took it and how it ended (RingMode.history)
##   Every fall       the last game's falls: when, who went into the water at what %, the move that took the life
##   The numbers      you against them with a bar each: falls dealt, % dealt, the highest % survived, the longest string, catches,
##                    perfect guards, edge saves (the % ring: RingMode.stock_tally for each side; a number that is not kept for
##                    the other side shows only yours); the zone rules' casts, catches and knock-backs
##   Highlights       the match's best plays at the right, each with Watch (HighlightCards)
##   Rematch                                   the same setup, the score nil (RingMode.restart)
##   Your element:  Earth                      steps through the elements: for the rematch, nothing restarts until then
##   Opponent:  Tide                           steps through the elements and Any: for the rematch
##   Main menu                                 back to the title
## Every word from data/ring/screens.json "match" (MatchSetup.screens) and the short captions of the board. Esc still opens the
## ring's menu over it.
##   MatchScreen.install(parent, mode); lines() -> {head, line, score, rounds [..], totals}; board() -> the numbers the board
##   draws; rematch(), cycle_element(), cycle_opponent(), to_menu(); is_open()
## Round 4 (IMPACT): it waits for the ring-out moment (RingMoment.busy(): the slow beat on a game's last fall) before it
## opens. While it stands, the HUD and the hints under it are put away (MenuUI.cover_hud: no plates, clock or strip under
## its rows) and come back as it closes.

const LAYER := 80
const MENU_SCENE := "res://scenes/main_menu.tscn"
## The space kept free under the board at the screen's bottom.
const FOOT_PX := 24.0

var match_mode: Node
var _root: Control
var _board: Control
## The four actions along the foot (Rematch, Your element, Opponent, Main menu).
var _items: HBoxContainer
var _rematch: Button
var _elem: Button
var _foe: Button
## Round 4 VIRAL: the match's best plays at the right, each with Watch (HighlightCards).
var _cards: HighlightCards
## Round 4: DONE came while the ring-out moment ran: opened when it ends.
var _waiting := false
## Your fighter's bust on the scoreboard (FighterWorld: made when the board first opens; a window only).
var _fw: FighterWorld
var _bust: SubViewport
var _bust_holder: Control
var _bust_mark: Control


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
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	BroadcastUI.backdrop_blur(_root, 2.2, 0.5)
	var L := BroadcastUI.layout(_root)
	BroadcastUI.stripes(L, Rect2(0, 0, 4000, 280), Color(Color.WHITE, 0.025), 16, 3, 1.0)
	_board = Control.new()
	_board.name = "Board"
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.add_child(_board)
	# the actions along the foot
	var foot := Control.new()
	foot.name = "Foot"
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.anchor_right = 1.0
	foot.offset_left = 84
	foot.offset_right = -84
	foot.offset_top = -146
	foot.offset_bottom = -72
	L.add_child(foot)
	_items = HBoxContainer.new()
	_items.add_theme_constant_override("separation", 0)
	foot.add_child(_items)
	var el := MatchSetup.element
	_rematch = _action("Rematch", w("rematch"), w("rematch_line"), el, 330.0, rematch)
	_rematch.name = "Rematch"
	_elem = _action("Your element", "", w("element_line"), el, 400.0, cycle_element, el)
	_elem.name = "Element"
	_foe = _action("Opponent", "", w("opponent_line"), el, 380.0, cycle_opponent, MatchSetup.foe())
	_foe.name = "Opponent"
	var mm := _action("Main menu", w("main_menu"), w("main_menu_line"), el, 300.0, to_menu)
	mm.name = "MainMenu"
	var hints := BroadcastUI.group(L, Vector2(1, 1), Vector2(-760, -58), Vector2(700, 36))
	var hh := BroadcastUI.hbox(26)
	hh.alignment = BoxContainer.ALIGNMENT_END
	hh.add_child(BroadcastUI.key_hint("ENTER", "Select"))
	hh.add_child(BroadcastUI.key_hint("ESC", "Ring menu"))
	BroadcastUI.put(hints, hh, Rect2(0, 0, 700, 36))
	_cards = HighlightCards.make(match_mode)
	L.add_child(_cards)
	if match_mode != null and match_mode.has_signal(&"phase_changed"):
		match_mode.connect(&"phase_changed", _on_phase)


static func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	return g


## An action along the foot: `title` its name, `words` the whole of it for what reads it (the Text label), `line` under it.
func _action(title: String, words: String, line: String, el: String, width: float, what: Callable, value_el := "") -> Button:
	var b := BroadcastUI.action(title, line, el, width, value_el)
	b.pressed.connect(what)
	_items.add_child(b)
	RingMenu._set_row(b, words)
	return b


func is_open() -> bool:
	return _root != null and _root.visible


func _on_phase(ph: String) -> void:
	_waiting = false
	if ph == "DONE" and not bool(match_mode.get(&"practice")):
		if RingMoment.busy() or RingReplay.holding():
			_waiting = true
		else:
			open()
	elif _root.visible:
		close()


func open() -> void:
	_paint()
	_root.visible = true
	MenuUI.cover_hud(self, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rematch.grab_focus.call_deferred()


func close() -> void:
	_root.visible = false
	MenuUI.cover_hud(self, false)


## The mouse kept free while it stands (the ring's Esc menu takes it back as it closes).
func _process(_dt: float) -> void:
	if _waiting and not RingMoment.busy() and not RingReplay.holding():
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
	_paint_rows()
	_rebuild_board(board())
	if _cards != null:
		_cards.refresh()


func _paint_rows() -> void:
	RingMenu._set_row(_elem, w("element") % MatchSetup.label(MatchSetup.element))
	RingMenu._set_row(_foe, w("opponent") % MatchSetup.label(MatchSetup.foe()))
	for a in _items.get_children():
		if a is BroadcastUI.Action:
			(a as BroadcastUI.Action).element = MatchSetup.element
	(_elem as BroadcastUI.Action).set_value(MatchSetup.element)
	(_foe as BroadcastUI.Action).set_value(MatchSetup.foe())


# ---------------------------------------------------------------- the board
## What the board draws for the match just decided, as plain data: {head, line, win (0 yours, 1 theirs, -1 drawn), tags,
## me {el, name}, foe {el, name}, score (Vector2i), stock, lives_line, games [{n, side, who, lives, how}], falls_head,
## falls [{when, who, mine, pct, how}], numbers [{label, a, b, show_b}]}.
func board() -> Dictionary:
	var out := {"head": "", "line": "", "win": -1, "tags": [], "me": {"el": MatchSetup.element, "name": "You"},
			"foe": {"el": MatchSetup.foe(), "name": ""}, "score": Vector2i.ZERO, "stock": false, "lives_line": "", "games": [],
			"falls_head": "", "falls": [], "numbers": [], "team": false, "roster": [], "format": "1 v 1"}
	var m := match_mode
	if m == null or not is_instance_valid(m):
		return out
	var l := lines()
	var team := team_game()
	var them := w("team_them") if team else String(m.call(&"foe_name"))
	out.team = team
	var stock: bool = m.has_method(&"stock") and bool(m.call(&"stock"))
	out.head = String(l.head)
	out.line = String(l.line)
	out.win = int(m.get(&"winner"))
	out.score = m.get(&"score")
	out.stock = stock
	out.me = {"el": String(m.get(&"element")), "name": w("team_you") if team else RingMode.words("you")}
	out.foe = {"el": String(m.get(&"foe_element")), "name": them}
	var to_win := int(m.get(&"to_win"))
	var length := (MatchSetup.rounds_label(2) if to_win > 1 else String(MatchSetup.screens().get("one_game", "one game"))) if stock \
			else MatchSetup.rounds_label(to_win)
	out.tags = [MatchSetup.sport(), MatchSetup.rule_label("stock" if stock else "classic"), length]
	var hist: Array = m.get(&"history")
	for h: Dictionary in hist:
		var res := String(h.get("result", "draw"))
		var how := w("how_" + String(h.get("why", "time")))
		var at := float(h.get("at_s", 0.0))
		if String(h.get("why", "")) in ["ringout", "winded", "knockout"]:
			how = w("round_at") % [how, "%d:%02d" % [floori(at / 60.0), floori(fmod(at, 60.0))]]
		out.games.append({"n": int(h.get("round", 0)), "side": 0 if res == "win" else (1 if res == "loss" else -1),
				"who": w("who_win") if res == "win" else ((w("who_loss_team") if team else w("who_loss") % them) if res == "loss" else w("who_draw")),
				"lives": h.get("lives", [0, 0]), "how": how})
	if not stock:
		var a: Dictionary = m.call(&"match_tally", 0)
		var b: Dictionary = m.call(&"match_tally", 1)
		for k: Array in [["Casts", "casts"], ["Catches", "catches"], ["Knock-backs", "knock_backs"]]:
			out.numbers.append({"label": String(k[0]), "a": int(a.get(k[1], 0)), "b": int(b.get(k[1], 0)), "show_b": true})
		return out
	if not hist.is_empty():
		var lv: Array = (hist.back() as Dictionary).get("lives", [0, 0])
		out.lives_line = w("lives_line_team") % [int(lv[0]), int(lv[1])] if team else w("lives_line") % [int(lv[0]), them, int(lv[1])]
	if team:
		# (a team format: every fighter with his own numbers, in place of every fall; RingMode.roster)
		out.format = String(((MatchSetup.data().get("formats", {}) as Dictionary).get(RingArena.format, {}) as Dictionary).get("label", RingArena.format))
		for e: Dictionary in m.call(&"roster"):
			var r := e.duplicate()
			r.erase("body")
			out.roster.append(r)
	# the last game's falls
	var player: Variant = m.get(&"player")
	var all: Array = m.get(&"falls")
	var last := 0
	for f: Dictionary in all:
		last = maxi(last, int(f.get("game", 1)))
	out.falls_head = "%s  ·  every fall" % (w("fall_game") % maxi(last, 1))
	for f: Dictionary in all:
		if int(f.get("game", 1)) == last:
			out.falls.append(fall_parts(f, them, f.get("who") == player))
	var t0: Dictionary = m.call(&"stock_tally", 0)
	var t1: Dictionary = m.call(&"stock_tally", 1)
	var rows := [["Falls dealt", "falls_dealt", true], ["% dealt", "pct_dealt", true], ["Highest % survived", "best_pct", true],
			["Longest string", "string_hits", true], ["Catches", "catches", false], ["Perfect guards", "perfect_guards", false],
			["Edge saves", "edge_saves", false]]
	for r: Array in rows:
		var key := String(r[1])
		out.numbers.append({"label": String(r[0]), "a": roundi(float(t0.get(key, 0.0))), "b": roundi(float(t1.get(key, 0.0))),
				"show_b": bool(r[2]) or _kept_for_foe(hist, key)})
	return out


## Whether the other side's number `key` is kept at all (RingRules tallies it only when something noted it for that side): a
## number that is not kept shows only yours.
static func _kept_for_foe(hist: Array, key: String) -> bool:
	for h: Dictionary in hist:
		if ((h.get("pct_tally", [{}, {}]) as Array)[1] as Dictionary).has(key) or ((h.get("tally", [{}, {}]) as Array)[1] as Dictionary).has(key):
			return true
	return false


## The board drawn: the head, the scoreboard, the game log, the numbers (the foot's actions and the cards are the screen's own).
func _rebuild_board(b: Dictionary) -> void:
	for c in _board.get_children():
		_board.remove_child(c)
		c.queue_free()
	var me := String((b.me as Dictionary).el)
	var fe := String((b.foe as Dictionary).el)
	var them := String((b.foe as Dictionary).name)
	var pc := BroadcastUI.plate_c(me)
	var fc := BroadcastUI.plate_c(fe)
	if bool(b.team):
		pc = RingSides.team_colour(0)              # (a team format: each side's own colour, not one fighter's element)
		fc = RingSides.team_colour(1)
	var win := int(b.win)
	# the head: the result and its line
	var hd := BroadcastUI.group(_board, Vector2(0, 0), Vector2(84, 40), Vector2(760, 250))
	hd.name = "Head"
	var t := BroadcastUI.hbox(0)
	t.add_child(BroadcastUI.tag("Final", 18, BroadcastUI.INK, BroadcastUI.TEAL, 4))
	t.add_child(BroadcastUI.tag("  ·  ".join(PackedStringArray(b.tags)), 18, BroadcastUI.WHITE, Color(BroadcastUI.NAVY1, 0.95), 3))
	BroadcastUI.put(hd, t, Rect2(0, 0, 0, 0))
	var head := BroadcastUI.lab(String(b.head), BroadcastUI.head(true, 4), 136, BroadcastUI.WHITE)
	head.name = "Result"
	head.uppercase = true
	var k := BroadcastUI.boost                      # (the type is raised in a small window: the room it needs with it)
	BroadcastUI.put(hd, head, Rect2(-6, 28, 760, 140.0 * k))
	BroadcastUI.fit_text(head, 740.0, 70)
	var ph := 142.0 * (float(head.get_meta(&"dsz", 136)) / 136.0) * k + 42.0
	BroadcastUI.plate(hd, Rect2(0, ph, 380, 6), pc if win == 0 else (fc if win == 1 else BroadcastUI.FAINT))
	BroadcastUI.put(hd, BroadcastUI.lab(String(b.line), BroadcastUI.body(true), 28, BroadcastUI.DIM), Rect2(2, ph + 12.0, 720, 40))
	# the scoreboard: the two sides, the games between them
	var sb := BroadcastUI.group(_board, Vector2(1, 0), Vector2(-820, 48), Vector2(740, 200))
	sb.name = "Scoreboard"
	var score: Vector2i = b.score
	var sub_me := String(b.format) if bool(b.team) else ""
	_team(sb, Rect2(0, 0, 280, 150), me, String((b.me as Dictionary).name), false, sub_me, pc if bool(b.team) else Color(0, 0, 0, 0))
	BroadcastUI.plate(sb, Rect2(276, 0, 188, 150), Color(BroadcastUI.NAVY0, 0.96))
	BroadcastUI.put(sb, BroadcastUI.lab(str(score.x), BroadcastUI.head(), 140, BroadcastUI.WHITE if score.x >= score.y else BroadcastUI.FAINT,
			HORIZONTAL_ALIGNMENT_CENTER), Rect2(282, -22, 80, 150))
	BroadcastUI.put(sb, BroadcastUI.lab(str(score.y), BroadcastUI.head(), 140, BroadcastUI.WHITE if score.y >= score.x else BroadcastUI.FAINT,
			HORIZONTAL_ALIGNMENT_CENTER), Rect2(380, -22, 80, 150))
	BroadcastUI.rect(sb, Rect2(369, 50, 3, 52), Color(BroadcastUI.FAINT, 0.8))
	_team(sb, Rect2(460, 0, 280, 150), fe, them, true, sub_me, fc if bool(b.team) else Color(0, 0, 0, 0))
	if String(b.lives_line) != "":
		var ll := BroadcastUI.hbox(0)
		ll.alignment = BoxContainer.ALIGNMENT_CENTER
		ll.add_child(BroadcastUI.tag("Games", 17, BroadcastUI.INK, BroadcastUI.TEAL, 3))
		ll.add_child(BroadcastUI.tag(String(b.lives_line), 17, BroadcastUI.WHITE, Color(BroadcastUI.NAVY1, 0.96), 3))
		BroadcastUI.put(sb, ll, Rect2(0, 158, 740, 30))
	# the game log
	var gl := BroadcastUI.group(_board, Vector2(0, 0), Vector2(84, 296), Vector2(470, 452))
	gl.name = "Games"
	BroadcastUI.section(gl, Vector2(0, 0), "Game by game" if bool(b.stock) else "Round by round", 470.0)
	var y := 36.0
	for g: Dictionary in b.games:
		var side := int(g.side)
		var col := pc if side == 0 else (fc if side == 1 else BroadcastUI.FAINT)
		BroadcastUI.plate(gl, Rect2(0, y, 470, 44), Color(BroadcastUI.NAVY1, 0.92))
		BroadcastUI.plate(gl, Rect2(0, y, 8, 44), col)
		var nm := (w("fall_game") % int(g.n)) if bool(b.stock) else ("Round %d" % int(g.n))
		BroadcastUI.put(gl, BroadcastUI.caps(nm, BroadcastUI.head(false, 2), 24, BroadcastUI.WHITE), Rect2(22, y, 120, 44))
		BroadcastUI.put(gl, BroadcastUI.caps(String(g.who), BroadcastUI.head(false, 2), 24, col if side != -1 else BroadcastUI.DIM), Rect2(136, y, 190, 44))
		var tail := ("Lives  %d : %d" % [int(g.lives[0]), int(g.lives[1])]) if bool(b.stock) else String(g.how)
		BroadcastUI.put(gl, BroadcastUI.caps(tail, BroadcastUI.head(false, 2), 20 if bool(b.stock) else 16, BroadcastUI.DIM, HORIZONTAL_ALIGNMENT_RIGHT),
				Rect2(250, y, 206, 44))
		y += 50.0
	if bool(b.team) and not (b.roster as Array).is_empty():
		_roster(gl, y + 10.0, b.roster as Array, pc, fc)
	elif bool(b.stock) and not (b.falls as Array).is_empty():
		y += 10.0
		BroadcastUI.put(gl, BroadcastUI.caps(String(b.falls_head), BroadcastUI.head(false, 4, 1), 16, BroadcastUI.FAINT), Rect2(0, y, 470, 22))
		y += 26.0
		var sc := ScrollContainer.new()
		sc.name = "Falls"
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		BroadcastUI.put(gl, sc, Rect2(0, y, 470, maxf(460.0 - y, 72.0)))
		var fl := VBoxContainer.new()
		fl.add_theme_constant_override("separation", 0)
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(fl)
		for f: Dictionary in b.falls:
			fl.add_child(_fall_row(f, pc, fc))
	# the numbers: you against them
	var ms := BroadcastUI.group(_board, Vector2(0.5, 0), Vector2(-212, 296), Vector2(460, 452))
	ms.name = "Numbers"
	BroadcastUI.section(ms, Vector2(0, 0), "The numbers", 460.0)
	var lh := BroadcastUI.hbox(8)
	lh.add_child(BroadcastUI.glyph(me, pc, 20.0))
	lh.add_child(BroadcastUI.caps(w("team_you_short") if bool(b.team) else "You", BroadcastUI.head(false, 3, 1), 20, pc))
	BroadcastUI.put(ms, lh, Rect2(0, 32, 200, 26))
	var rh := BroadcastUI.hbox(8)
	rh.alignment = BoxContainer.ALIGNMENT_END
	rh.add_child(BroadcastUI.caps(w("team_them_short") if bool(b.team) else them, BroadcastUI.head(false, 3, 1), 20, fc))
	rh.add_child(BroadcastUI.glyph(fe, fc, 20.0))
	BroadcastUI.put(ms, rh, Rect2(260, 32, 200, 26))
	var rows: Array = b.numbers
	var sy := 66.0
	var pitch := minf(52.0, 380.0 / maxf(float(rows.size()), 1.0))
	for r: Dictionary in rows:
		var a := float(r.a)
		var bb := float(r.b)
		var show_b := bool(r.show_b)
		var mx := maxf(a, bb if show_b else 0.0)
		BroadcastUI.put(ms, BroadcastUI.lab(str(int(a)), BroadcastUI.head(), 34, BroadcastUI.WHITE), Rect2(0, sy, 80, 36))
		if show_b:
			BroadcastUI.put(ms, BroadcastUI.lab(str(int(bb)), BroadcastUI.head(), 34, BroadcastUI.DIM, HORIZONTAL_ALIGNMENT_RIGHT), Rect2(380, sy, 80, 36))
		BroadcastUI.put(ms, BroadcastUI.caps(String(r.label), BroadcastUI.head(false, 3, 1), 17, BroadcastUI.FAINT, HORIZONTAL_ALIGNMENT_CENTER),
				Rect2(80, sy + 2, 300, 24))
		var bw := 170.0
		BroadcastUI.rect(ms, Rect2(60, sy + 32, bw, 6), Color(BroadcastUI.NAVY3, 0.9))
		if show_b:
			BroadcastUI.rect(ms, Rect2(230, sy + 32, bw, 6), Color(BroadcastUI.NAVY3, 0.9))
		if mx > 0.0:
			BroadcastUI.rect(ms, Rect2(60.0 + bw * (1.0 - a / mx), sy + 32, bw * a / mx, 6), pc)
			if show_b:
				BroadcastUI.rect(ms, Rect2(230, sy + 32, bw * bb / mx, 6), fc)
		sy += pitch


## A team format's roster under the game log (from `y`): every fighter with his own numbers, his side's colour at the left, the
## best of each side marked; in a scroll when it runs past the column's foot.
func _roster(gl: Control, y: float, roster: Array, pc: Color, fc: Color) -> void:
	BroadcastUI.put(gl, BroadcastUI.caps(w("roster_head"), BroadcastUI.head(false, 4, 1), 16, BroadcastUI.FAINT), Rect2(0, y, 200, 22))
	for c: Array in [[w("roster_falls"), 300.0], [w("roster_pct"), 362.0], [w("roster_lost"), 420.0]]:
		BroadcastUI.put(gl, BroadcastUI.caps(String(c[0]), BroadcastUI.head(false, 3, 1), 15, BroadcastUI.FAINT, HORIZONTAL_ALIGNMENT_RIGHT),
				Rect2(float(c[1]) - 10.0, y, 56, 22))
	y += 26.0
	var sc := ScrollContainer.new()
	sc.name = "Roster"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	BroadcastUI.put(gl, sc, Rect2(0, y, 470, maxf(460.0 - y, 96.0)))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	for e: Dictionary in roster:
		var mine := int(e.team) == 0
		var col := pc if mine else fc
		var h := Control.new()
		h.custom_minimum_size = Vector2(470, 32)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		BroadcastUI.plate(h, Rect2(0, 0, 470, 32), Color(BroadcastUI.NAVY1, 0.95 if bool(e.mine) else 0.82))
		BroadcastUI.plate(h, Rect2(0, 0, 6, 32), col)
		BroadcastUI.put(h, BroadcastUI.glyph(String(e.element), BroadcastUI.plate_c(String(e.element)), 20.0), Rect2(14, 6, 20, 20))
		var nm := BroadcastUI.caps(String(e.name), BroadcastUI.head(false, 2), 21, BroadcastUI.WHITE if bool(e.mine) else BroadcastUI.DIM)
		BroadcastUI.put(h, nm, Rect2(44, 0, 160, 32))
		if bool(e.mvp):
			BroadcastUI.put(h, BroadcastUI.tag(w("mvp"), 14, BroadcastUI.INK, col, 2), Rect2(196, 6, 0, 0))
		for c: Array in [[str(int(e.falls_dealt)), 300.0, BroadcastUI.WHITE], [str(int(e.pct_dealt)), 362.0, BroadcastUI.DIM],
				[str(int(e.falls_taken)), 420.0, BroadcastUI.FAINT]]:
			BroadcastUI.put(h, BroadcastUI.lab(String(c[0]), BroadcastUI.head(), 24, c[2] as Color, HORIZONTAL_ALIGNMENT_RIGHT),
					Rect2(float(c[1]) - 10.0, 0, 56, 32))
		vb.add_child(h)


## A team format's match (2v2, 4v4): your team and theirs, each fighter by his own name, the roster in place of every fall.
func team_game() -> bool:
	return match_mode != null and is_instance_valid(match_mode) and match_mode.has_method(&"team_n") \
			and int(match_mode.call(&"team_n")) > 1


## One of the last game's falls: when, a dot in the colour of who went in, "the Tide into the water at 104%", the move that did it.
func _fall_row(f: Dictionary, pc: Color, fc: Color) -> Control:
	var mine := bool(f.mine)
	var h := Control.new()
	h.custom_minimum_size = Vector2(470, 36)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	BroadcastUI.put(h, BroadcastUI.lab(String(f.when), BroadcastUI.head(), 26, BroadcastUI.WHITE), Rect2(0, 0, 62, 36))
	BroadcastUI.rect(h, Rect2(68, 13, 10, 10), pc if mine else fc)
	var who := w("fall_you") if mine else w("fall_them") % String((match_mode.call(&"foe_name") if match_mode != null else ""))
	BroadcastUI.put(h, BroadcastUI.lab("%s into the water at %d%%" % [who, int(f.pct)], BroadcastUI.body(true), 18, BroadcastUI.DIM), Rect2(88, 0, 270, 36))
	BroadcastUI.put(h, BroadcastUI.caps(String(f.how), BroadcastUI.head(false, 1), 22, fc if mine else pc, HORIZONTAL_ALIGNMENT_RIGHT),
			Rect2(340, 0, 126, 36))
	return h


## One side of the scoreboard: the side's colour with hatching, your bust or the other's mark, its name and its element.
func _team(p: Control, r: Rect2, el: String, who: String, right: bool, sub_text := "", col := Color(0, 0, 0, 0)) -> void:
	var pc := col if col.a > 0.0 else BroadcastUI.plate_c(el)
	var g := BroadcastUI.group(p, Vector2.ZERO, r.position, r.size)
	g.clip_contents = true
	BroadcastUI.grad(g, [[0.0, pc], [1.0, pc.darkened(0.35)]], Vector2(0.5, 0), Vector2(0.5, 1))
	BroadcastUI.stripes(g, Rect2(Vector2.ZERO, r.size), Color(Color.WHITE, 0.10), 12, 3, 1.0)
	# (your bust: the element's mark at once, the portrait over it as soon as the fighter is dressed, a frame or two after the
	# board is up: dressing takes a second, and the board must not wait for it)
	var mark := BroadcastUI.glyph(el, Color(BroadcastUI.INK, 0.5), 96.0, pc)
	BroadcastUI.put(g, mark, Rect2(Vector2(r.size.x - 128.0, 12.0) if right else Vector2(18.0, 12.0), Vector2(96, 96)))
	if not right and FighterWorld.available() and match_mode != null:
		_bust_mark = mark
		_bust_holder = Control.new()
		_bust_holder.name = "Bust"
		_bust_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		BroadcastUI.put(g, _bust_holder, Rect2(-6, -4, 170, 170))
		if is_instance_valid(_bust):
			_show_bust()
		else:
			_dress_bust.call_deferred()
	var name := BroadcastUI.caps(who, BroadcastUI.head(true, 2), 54, BroadcastUI.INK, HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT)
	BroadcastUI.fit_text(name, 136.0, 24)          # (a team's name, "Your team", in the width of an element's)
	var sub := BroadcastUI.caps(sub_text if sub_text != "" else MatchSetup.label(el), BroadcastUI.head(false, 4, 1), 18, Color(BroadcastUI.INK, 0.7),
			HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT)
	var k := BroadcastUI.boost
	var sub_y := 34.0 + 58.0 * k
	if right:
		BroadcastUI.put(g, name, Rect2(0, 34, 140, 60.0 * k))
		BroadcastUI.put(g, sub, Rect2(0, sub_y, 140, 24))
	else:
		BroadcastUI.put(g, name, Rect2(140, 34, 130, 60.0 * k))
		BroadcastUI.put(g, sub, Rect2(140, sub_y, 130, 24))


## Your fighter's bust: the saved look in the played element's ring dress (FighterWorld; none in a headless run), made a frame
## or two after the board is up and put into the scoreboard's plate then.
func _dress_bust() -> void:
	for i in 2:
		await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(_bust_holder) or match_mode == null:
		return
	if not is_instance_valid(_bust):
		if _fw == null:
			_fw = FighterWorld.make(self)
		var el := String(match_mode.get(&"element"))
		if not _fw.ensure(el):
			return
		_bust = _fw.view(el, "head", Vector2i(336, 336))
		_bust.name = "BustView"
		add_child(_bust)
	_show_bust()


func _show_bust() -> void:
	if not is_instance_valid(_bust_holder) or not is_instance_valid(_bust):
		return
	for c in _bust_holder.get_children():
		_bust_holder.remove_child(c)
		c.queue_free()
	if is_instance_valid(_bust_mark):
		_bust_mark.visible = false                 # (the portrait stands where the mark was)
	var tr := TextureRect.new()
	tr.texture = _bust.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bust_holder.add_child(tr)
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## What it says for the match just decided.
func lines() -> Dictionary:
	var out := {"head": "", "line": "", "score": "", "rounds": [], "totals": ""}
	var m := match_mode
	if m == null or not is_instance_valid(m):
		return out
	var team := team_game()
	var them := w("team_them") if team else String(m.call(&"foe_name"))
	var win := int(m.get(&"winner"))
	out.head = w("head_win") if win == 0 else (w("head_loss") if win == 1 else w("head_draw"))
	if team:
		out.line = w("line_win_team") if win == 0 else (w("line_loss_team") if win == 1 else w("line_draw"))
	else:
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
		rows.append(w("lives_line_team") % [int(lv[0]), int(lv[1])] if team_game() else w("lives_line") % [int(lv[0]), them, int(lv[1])])
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
	var p := fall_parts(f, them, mine)
	var when := String(p.when)
	if multi:
		when = (w("fall_game") % int(f.get("game", 1))) + "  ·  " + when
	return w("fall_line") % [when, p.who, p.pct, p.how]


## A fall's parts: {when ("1:12"), who ("you", "the Tide"), mine, pct, how (the move, or "own fall")}.
static func fall_parts(f: Dictionary, them: String, mine: bool) -> Dictionary:
	var s := float(f.get("at_s", 0.0))
	var who := w("fall_you") if mine else (RingMode.name_of(f.get("who")) if RingMode.name_of(f.get("who")) != "" else w("fall_them") % them)
	return {"when": "%d:%02d" % [floori(s / 60.0), floori(fmod(s, 60.0))], "who": who,
			"mine": mine, "pct": roundi(float(f.get("pct", 0.0))),
			"how": w("fall_self") if bool(f.get("self", false)) or f.get("by") == null else move_of(String(f.get("tag", "")))}


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
