class_name RingMenu
extends CanvasLayer
## Tidebreak's Esc menu in the ring (RingMode; the owner, 2026-10-04: the ring sport Tidebreak, "1v1 first"), in the pause
## menu's and the duel menu's look (MenuUI, DuelMenu): the game stops under a dark veil, the rows at the left. No Save or
## Load: a match is not a saved game. Every word in data/ring/rules.json "words".
##   Resume             (Esc again)
##   Restart match      the score nil, round 1, with the choices below (RingMode.restart)
##   Element: Earth     the player's, in turn (MatchSetup.element): from the next restart, not at once
##   Opponent: Water    the bot's, in turn, Any among them (MatchSetup.foes): from the next restart
##   Difficulty: normal easy, normal, hard in turn (MatchSetup.difficulty): from the next restart
##   Rules: Lives      round 3: the rule set in turn, "Lives" (the % ring) or "Zones" (never the ids; MatchSetup.rules_choice):
##                      from the next restart, kept
##   Games: 1           round 3: 1 or best of 3 (MatchSetup.games_n): from the next restart, kept
##   Practice           round 3, in a % ring practice only: its rows (its %, your %, what it does, its steering, Throw me
##                      off, speed, fresh moves), each at once and kept (RingPractice applies them; practice.json words)
##   Aim help: light    how much the casts are helped onto a fighter near the crosshair, in turn: at once, kept
##   Key hints: on      the control scheme's keys at the top left until each is used (FirstHints; GameSettings' hints
##                      section): at once, kept; on, they show in the match under way
##   Camera: High       round 4 (READ): where the camera sits behind you, in turn (RingCamera: High, Close, Shoulder, High
##                      shoulder; camera.json's words): at once, kept (GameSettings ring.camera)
##   Screen jolt: On    round 4: the view's jolt when a hit lands on or off (IMPACT's GameSettings ring.jolt; the aim never
##                      moves either way): at once, kept
##   Controls           the element in play's buttons (round 2 of the skills, KitWords: its passive and guard, LMB jab,
##                      E guard, 1-5 with their plain names; in the % ring first the one line of practice.json
##                      menu.controls_line), the four rules, and the row "Other ways to pick moves:
##                      Keys" (MatchSetup.set_scheme in turn: keys, first moves only, direction, the wheel; at once, kept;
##                      cycle_scheme)
##   Settings           the main menu's (GameSettings)
##   Main menu          back to the title (nothing is saved in a match)
##   Quit
## The note under the title: "Round 2 · 1:42 left · You 1 : 0 Tide". It keeps out of the way while something else holds the
## game (the inspect view pauses it) or another screen has the mouse (the Tab screen).

const MENU_SCENE := "res://scenes/main_menu.tscn"

var match_mode: RingMode
var _root: Control
var _items: VBoxContainer
var _panel: VBoxContainer
var _note: Label
var _elem: Button
var _foe: Button
var _diff: Button
var _scheme: Button
var _aim: Button
var _hints: Button
var _camera: Button
var _jolt: Button
var _rules: Button
var _games: Button
var _practice: Button
var _open := false


static func install(parent: Node, m: RingMode) -> RingMenu:
	var menu := RingMenu.new()
	menu.name = "RingMenu"
	menu.match_mode = m
	parent.add_child(menu)
	return menu


static func w(key: String) -> String:
	return RingMode.words(key)


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.015, 0.01, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(veil)
	var shade := MenuUI.left_shade(0.85)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.anchor_right = 0.55
	_root.add_child(shade)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.offset_left = 88
	left.offset_top = 90
	left.offset_right = 88 + 560
	_root.add_child(left)
	left.add_child(MenuUI.label(w("menu_title"), 44, MenuUI.INK))
	_note = MenuUI.label("", 18, MenuUI.GOLD)
	left.add_child(_note)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	left.add_child(gap)
	_items = VBoxContainer.new()
	_items.add_theme_constant_override("separation", 2)
	left.add_child(_items)
	_row(w("resume"), close)
	_row(w("restart"), restart, w("restart_line"))
	_elem = _row(_elem_text(), cycle_element, w("element_line"))
	_foe = _row(_foe_text(), cycle_opponent, w("opponent_line"))
	_diff = _row(_diff_text(), cycle_difficulty, MatchSetup.difficulty_line(MatchSetup.difficulty))
	_rules = _row(_rules_text(), cycle_rules, MatchSetup.menu_word("rules_line"))
	_rules.name = "Rules"
	_games = _row(_games_text(), cycle_games, MatchSetup.menu_word("games_line"))
	_games.name = "Games"
	_practice = _row(MatchSetup.pword("practice"), practice_rows, MatchSetup.pword("practice_line"))
	_practice.name = "Practice"
	_practice.visible = false
	_aim = _row(MatchSetup.aim_row(), cycle_aim, MatchSetup.aim_row_line())
	_aim.name = "AimHelp"
	_hints = _row(FirstHints.row_text(), toggle_hints, FirstHints.row_line())
	_hints.name = "KeyHints"
	_camera = _row(RingCamera.row_text(), cycle_camera, RingCamera.row_line())
	_camera.name = "Camera"
	_jolt = _row(RingCamera.jolt_row_text(), toggle_jolt, RingCamera.word("jolt_line"))
	_jolt.name = "ScreenJolt"
	var ctl := _row(KitWords.w("controls", "Controls"), _controls, KitWords.w("controls_line"))
	ctl.name = "Controls"
	# (the other ways to pick moves: a row of the Controls panel, round 2; kept here, laid into the panel as it opens)
	_scheme = MenuUI.item(KitWords.other_ways_row(), 24, KitWords.other_ways_line())
	_scheme.name = "Scheme"
	_scheme.pressed.connect(cycle_scheme)
	_row(w("settings"), _settings)
	_row(w("main_menu"), to_menu)
	_row(w("quit"), _quit)
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.5
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 20
	scroll.offset_right = -88
	scroll.offset_top = 110
	scroll.offset_bottom = -80
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 14)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_panel)


func _exit_tree() -> void:
	if is_instance_valid(_scheme) and _scheme.get_parent() == null:
		_scheme.queue_free()                  # (the scheme's row out of the Controls panel: freed with the menu)


func _row(text: String, what: Callable, sub_line := "") -> Button:
	var b := MenuUI.item(text, 28, sub_line)
	b.pressed.connect(what)
	_items.add_child(b)
	return b


func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _open:
		if _panel.get_child_count() > 0:
			_clear_panel()
			(_items.get_child(0) as Button).grab_focus()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif _can_open():
		open()
		get_viewport().set_input_as_handled()


## Not while something else holds the game (the inspect view pauses it) or another screen has the mouse (the Tab screen).
func _can_open() -> bool:
	if get_tree().paused:
		return false
	var p := match_mode.player if match_mode != null else null
	return not (p != null and p.get("_inv_screen") != null and is_instance_valid(p.get("_inv_screen")))


## The note under the title: "Round 2 · 1:42 left · You 1 : 0 Tide".
func note_text() -> String:
	if match_mode == null:
		return ""
	var left := match_mode.round_left_s()
	return w("menu_note") % [match_mode.round, floori(left / 60.0), floori(fmod(left, 60.0)), match_mode.score_text()]


func open() -> void:
	_open = true
	_note.text = note_text()
	_clear_panel()
	_practice.visible = match_mode != null and match_mode.practice and RingRules.stock_on()
	# (round 4: the camera's variants and the jolt are the % ring's; the zone rules' ring is as it was)
	_camera.visible = RingRules.stock_on()
	_jolt.visible = RingRules.stock_on()
	_paint()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_items.get_child(0) as Button).grab_focus()


func close() -> void:
	_open = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The match from its start with the choices made here (the menu closed).
func restart() -> void:
	close()
	MatchSetup.save()
	if match_mode != null:
		match_mode.restart()


## The player's next element in turn (from the next restart).
func cycle_element() -> void:
	var list := Bending.ELEMENTS
	MatchSetup.element = String(list[(list.find(MatchSetup.element) + 1) % list.size()])
	_paint()
	_note.text = w("applies") % _elem_text()


## The bot's next element in turn, Any among them (from the next restart).
func cycle_opponent() -> void:
	var list: Array = Bending.ELEMENTS.duplicate()
	list.append(MatchSetup.ANY)
	MatchSetup.foes = [String(list[(list.find(MatchSetup.foe()) + 1) % list.size()])]
	_paint()
	_note.text = w("applies") % _foe_text()


## Round 3: the next rule set in turn, "Lives" or "Zones" (from the next restart), kept.
func cycle_rules() -> void:
	MatchSetup.rules_choice = String(MatchSetup.next_in(MatchSetup.RULE_SETS, MatchSetup.rule_set()))
	MatchSetup.save()
	_paint()
	_note.text = w("applies") % _rules_text()


## Round 3: the games of a match in turn, 1 or best of 3 (from the next restart), kept.
func cycle_games() -> void:
	MatchSetup.games_n = int(MatchSetup.next_in(MatchSetup.GAMES, MatchSetup.games()))
	MatchSetup.save()
	_paint()
	_note.text = w("applies") % _games_text()


func _rules_text() -> String:
	return MatchSetup.menu_word("rules") % MatchSetup.rule_label()


func _games_text() -> String:
	return MatchSetup.menu_word("games") % MatchSetup.games_label()


## Round 3: the Practice rows (a % ring practice): each press steps its value, at once, kept.
func practice_rows() -> void:
	_clear_panel()
	_panel.add_child(MenuUI.heading(MatchSetup.pword("practice")))
	var pd := MatchSetup.practice_data()
	var pcts: Array = pd.get("pct", [0, 30, 60, 90, 120, 150, 200, -1])
	var ctl: RingPractice = match_mode.practice_ctl if match_mode != null else null
	_prow("ForePct", func() -> String: return MatchSetup.pword("row_foe_pct") % MatchSetup.pct_label(MatchSetup.foe_pct),
			MatchSetup.pword("row_pct_line"), func() -> void:
				MatchSetup.foe_pct = float(MatchSetup.next_in(pcts, MatchSetup.foe_pct))
				if ctl != null:
					ctl._apply_pct())
	_prow("MyPct", func() -> String: return MatchSetup.pword("row_my_pct") % MatchSetup.pct_label(MatchSetup.my_pct),
			MatchSetup.pword("row_pct_line"), func() -> void:
				MatchSetup.my_pct = float(MatchSetup.next_in(pcts, MatchSetup.my_pct))
				if ctl != null:
					ctl._apply_pct())
	_prow("Way", func() -> String: return MatchSetup.pword("row_way") % MatchSetup.dummy_line(ctl.dummy if ctl != null else MatchSetup.dummy),
			MatchSetup.pword("row_way_line"), func() -> void:
				if ctl != null:
					ctl.cycle_dummy())
	_prow("Steer", func() -> String: return MatchSetup.pword("row_steer") % String((pd.get("steer_lines", {}) as Dictionary).get(MatchSetup.steer, MatchSetup.steer)),
			MatchSetup.pword("row_steer_line"), func() -> void:
				MatchSetup.steer = String(MatchSetup.next_in(pd.get("steer", ["none", "in", "out", "random"]), MatchSetup.steer))
				if ctl != null:
					ctl._tell_way())
	_prow("ThrowMe", func() -> String: return MatchSetup.pword("row_throw_me") % MatchSetup.pword("on" if MatchSetup.throw_me else "off"),
			MatchSetup.pword("row_throw_me_line"), func() -> void:
				MatchSetup.throw_me = not MatchSetup.throw_me)
	_prow("Speed", func() -> String: return MatchSetup.pword("row_speed") % speed_label(MatchSetup.speed),
			MatchSetup.pword("row_speed_line"), func() -> void:
				MatchSetup.speed = float(MatchSetup.next_in(pd.get("speed", [1.0, 0.5, 0.25]), MatchSetup.speed)))
	_prow("Fresh", func() -> String: return MatchSetup.pword("row_fresh") % MatchSetup.pword("on" if MatchSetup.fresh else "off"),
			MatchSetup.pword("row_fresh_line"), func() -> void:
				MatchSetup.fresh = not MatchSetup.fresh
				var r := RingRules.current()
				if r != null:
					r.set(&"stale_off", MatchSetup.fresh))


## "1", "1/2", "1/4".
static func speed_label(s: float) -> String:
	return "1" if s >= 0.99 else "1/%d" % roundi(1.0 / maxf(s, 0.01))


## One Practice row: its text now, its line, what a press does (then the text again, the setup kept).
func _prow(nm: String, text: Callable, sub: String, press: Callable) -> Button:
	var b := MenuUI.item(String(text.call()), 22, sub)
	b.name = nm
	b.pressed.connect(func() -> void:
		press.call()
		MatchSetup.save()
		_set_row(b, String(text.call()), sub))
	_panel.add_child(b)
	return b


## The next difficulty in turn (from the next restart).
func cycle_difficulty() -> void:
	var list := MatchSetup.DIFFICULTIES
	MatchSetup.difficulty = String(list[(list.find(MatchSetup.difficulty) + 1) % list.size()])
	_paint()
	_note.text = w("applies") % _diff_text()


## The next control scheme in turn: at once (the match goes on with it), kept for the next time.
## The aim's help in turn (MatchSetup.AIMS: light, off, strong): at once, kept.
func cycle_aim() -> void:
	MatchSetup.set_aim_help(MatchSetup.next_aim_help())
	_paint()
	_note.text = "Aim help: %s" % MatchSetup.aim_help()


## The key hints on or off: at once (on: shown over the match under way; off: the ones up go), kept.
func toggle_hints() -> void:
	var now := not FirstHints.on()
	FirstHints.set_on(now)
	var h := FirstHints.find(get_tree())
	if now and match_mode != null:
		FirstHints.install(match_mode, true)
	elif h != null:
		h.close()
	_paint()
	_note.text = FirstHints.row_text()


## The camera's variant in turn (RingCamera): at once (the next frame's framing), kept.
func cycle_camera() -> void:
	RingCamera.set_key(RingCamera.next_key())
	_paint()
	_note.text = RingCamera.word("changed") % RingCamera.label()


## The screen's jolt on a hit on or off (GameSettings ring.jolt, IMPACT's): at once, kept.
func toggle_jolt() -> void:
	RingCamera.set_jolt(not RingCamera.jolt_on())
	_paint()
	_note.text = RingCamera.word("jolt_changed") % RingCamera.word("jolt_on" if RingCamera.jolt_on() else "jolt_off")


func cycle_scheme() -> void:
	MatchSetup.set_scheme(MatchSetup.next_scheme())
	_paint()
	_note.text = String((MatchSetup.schemes_data().get("words", {}) as Dictionary).get("changed", "Control scheme: %s")) \
			% MatchSetup.scheme_label()
	if _panel.get_child_count() > 0:
		_controls()                           # (the Controls panel open: it follows)


func _elem_text() -> String:
	return w("element") % MatchSetup.label(MatchSetup.element)


func _foe_text() -> String:
	return w("opponent") % MatchSetup.label(MatchSetup.foe())


func _diff_text() -> String:
	return w("difficulty") % MatchSetup.difficulty


func _paint() -> void:
	_set_row(_elem, _elem_text(), KitWords.passive_line(MatchSetup.element))      # (the element's one passive, round 2)
	_set_row(_foe, _foe_text())
	_set_row(_diff, _diff_text(), MatchSetup.difficulty_line(MatchSetup.difficulty))
	_set_row(_rules, _rules_text(), MatchSetup.menu_word("rules_line"))
	_set_row(_games, _games_text(), MatchSetup.menu_word("games_line"))
	_set_row(_scheme, KitWords.other_ways_row(), KitWords.other_ways_line())
	_set_row(_aim, MatchSetup.aim_row(), MatchSetup.aim_row_line())
	_set_row(_hints, FirstHints.row_text(), FirstHints.row_line())
	_set_row(_camera, RingCamera.row_text(), RingCamera.row_line())
	_set_row(_jolt, RingCamera.jolt_row_text(), RingCamera.word("jolt_line"))


static func _set_row(b: Button, text: String, sub_line := "") -> void:
	if b == null:
		return
	var t := b.find_child("Text", true, false) as Label
	if t:
		t.text = text
	var s := b.find_child("Sub", true, false) as Label
	if s and sub_line != "":
		s.text = sub_line


func _clear_panel() -> void:
	for c in _panel.get_children():
		_panel.remove_child(c)
		if c != _scheme:
			c.queue_free()                    # (the scheme's row is kept: it is laid in again)


## The element in play's buttons (round 2 of the skills, KitWords): its passive and its guard, each button with its plain
## names under the scheme now, the four rules, and "Other ways to pick moves" (the scheme in turn, at once, kept).
func _controls() -> void:
	_clear_panel()
	var el := match_mode.element if match_mode != null else MatchSetup.element
	_panel.add_child(MenuUI.heading(KitWords.w("controls_head", "%s: your buttons") % MatchSetup.label(el)))
	if RingRules.stock_on():
		# (round 3: the % ring's one line, in right-click terms)
		_panel.add_child(MenuUI.label(MatchSetup.menu_word("controls_line"), 18, MenuUI.GOLD, true))
	_panel.add_child(_scheme)                   # (the other ways first: in view without a scroll)
	for line in KitWords.pick_lines(el):
		_panel.add_child(MenuUI.label(String(line), 17, MenuUI.DIM, true))
	for line in control_lines(el):
		_panel.add_child(MenuUI.label(String(line), 18, MenuUI.INK, true))
	for line in KitWords.rule_lines():
		_panel.add_child(MenuUI.label(String(line), 16, MenuUI.DIM, true))


## "1   STRIKE   Spike  ·  tap twice: Boulder" for each button of `el` under the scheme now (KitWords.kit_lines).
static func control_lines(el: String) -> Array:
	return KitWords.kit_lines(el)


func _settings() -> void:
	_clear_panel()
	_panel.add_child(MenuUI.heading(w("settings")))
	_panel.add_child(GameSettings.rows(match_mode.player if match_mode != null else null))


func to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0                      # (a slowed practice's speed left behind)
	MatchSetup.leave()
	get_tree().change_scene_to_file(MENU_SCENE)


func _quit() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().quit()
