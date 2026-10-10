class_name RingMenu
extends CanvasLayer
## Tidebreak's Esc menu in the ring (RingMode; the owner, 2026-10-04: the ring sport Tidebreak, "1v1 first"), in the broadcast look
## the owner chose (BroadcastUI, 2026-10-10): the game stops under a softened, dimmed copy of the ring, the numbered rows at the
## left, a score bug across the top, the panel of the row opened at the right. No Save or Load: a match is not a saved game.
## Every word in data/ring/rules.json "words".
##   Resume             (Esc again)
##   Restart match      the score nil, game (round) 1, with the match setup's choices (RingMode.restart)
##   Match setup        its rows in the panel at the right (the UI audit, 2026-10-09: sixteen rows in one column ran off the
##                      screen; now every row is in view at 1280 x 720), each from the next restart:
##     Element: Earth     the player's, in turn (MatchSetup.element)
##     Opponent: Water    the bot's, in turn, Any among them (MatchSetup.foes)
##     Difficulty: normal easy, normal, hard in turn (MatchSetup.difficulty)
##     Rules: Lives       round 3: the rule set in turn, "Lives" (the % ring) or "Zones" (never the ids; MatchSetup.rules_choice),
##                        kept; its line tells the chosen rule set only
##     Games: 1           round 3: 1 or best of 3 (MatchSetup.games_n), kept
##   Practice           round 3, in a % ring practice only: its rows (its %, your %, what it does, its steering, Throw me
##                      off, speed, fresh moves), each at once and kept (RingPractice applies them; practice.json words)
##   Options            its rows in the panel at the right, each at once and kept:
##     Aim help: light    how much the casts are helped onto a fighter near the crosshair, in turn
##     Key hints: on      the control scheme's keys at the top left until each is used (FirstHints; GameSettings' hints
##                        section); on, they show in the match under way
##     Camera: High       round 4 (READ): where the camera sits behind you, in turn (RingCamera: High, Close, Shoulder, High
##                        shoulder; camera.json's words; GameSettings ring.camera)
##     Screen jolt: On    round 4: the view's jolt when a hit lands on or off (IMPACT's GameSettings ring.jolt; the aim never
##                        moves either way)
##     Character look     Classic or Soft (SoftLook; the owner's choice Soft the default): at once on both fighters, kept
##     Replays, Callouts, Photo   round 4 VIRAL (the % ring's only): the Splash Cam's replays, the callouts, photo mode
##   Controls           the element in play's buttons (round 2 of the skills, KitWords: its passive and guard, LMB jab,
##                      E guard, 1-5 with their plain names; in the % ring first the one line of practice.json
##                      menu.controls_line), the four rules, and the row "Other ways to pick moves:
##                      Keys" (MatchSetup.set_scheme in turn: keys, first moves only, direction, the wheel; at once, kept;
##                      cycle_scheme)
##   Class & talents    the Character Advancement window over this menu (AdvancementWindow, for the element in play; its own layer
##                      above this one, Esc closes it alone); what it changes applies from the next restart (the row's line)
##   Settings           the main menu's (GameSettings)
##   Main menu          back to the title (nothing is saved in a match)
##   Quit
## The Match setup and Options rows show their values as chips (BroadcastUI.OptionRow: the value in force lit): a press steps to
## the next, Left and Right (and a click on a chip) choose. The rows sit in a scroll that follows the focus (a window smaller
## still keeps every row reachable). Esc in a panel closes it and gives the focus back to its row. While the menu is open the HUD
## and the hints under it are put away (MenuUI.cover_hud) and come back as it closes.
## The score bug across the top: your side and theirs with the lives left as diamonds, the games between them, and under it the
## game, the time left and the rule ("Game 2  ·  1:42 left"; in a practice what the dummy does: no clock, no score). note_text()
## is the same in one line ("Game 2  ·  1:42 left  ·  You 1 : 0 Tide"). It keeps out of the way while something else holds the
## game (the inspect view pauses it) or another screen has the mouse (the Tab screen).

const MENU_SCENE := "res://scenes/main_menu.tscn"

var match_mode: RingMode
var _root: Control
## The menu's own screen (the rows, the panel, the score bug and the keys, in the design space) and the shade at its left: put
## away while the advancement window is over it.
var _layout: Control
var _shade: Control
var _items: VBoxContainer
var _panel: VBoxContainer
var _panel_plate: Control
var _panel_scroll: ScrollContainer
var _rows_scroll: ScrollContainer
var _bug: Control
var _note: Label
var _elem: Button
var _foe: Button
var _diff: Button
var _scheme: Button
## Round 4 SIMPLE: the Controls preset's row (Basic / Full), laid into the Controls panel with the scheme's.
var _preset: Button
var _aim: Button
var _hints: Button
var _camera: Button
var _jolt: Button
## Round 4 VIRAL: the Splash Cam's replays, the callouts and photo mode (the % ring's only).
var _replays: Button
var _callouts: Button
var _look: Button
var _photo: Button
var _rules: Button
var _games: Button
var _practice: Button
## The column's rows that open the Match setup and Options panels, and those panels' rows (kept in the right-hand panel,
## hidden while another one is open); the panel open now ("" none, "setup", "options", "practice", "controls", "settings")
## and the row that opened it (Esc gives the focus back to it).
var _setup_row: Button
var _options_row: Button
var _class_row: Button
var _setup: VBoxContainer
var _options: VBoxContainer
var _kind := ""
var _from: Button
var _open := false
## The column's rows in order (Row), numbered as they stand in view.
var _rows: Array = []


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
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	# the ring under the menu softened and dimmed (live: the screen texture's own mip levels), the rundown's side darker
	BroadcastUI.backdrop_blur(_root, 2.4, 0.36)
	var shade := Control.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	BroadcastUI.grad(shade, [[0.0, Color(BroadcastUI.NAVY0, 0.92)], [0.40, Color(BroadcastUI.NAVY0, 0.74)], [0.64, Color(BroadcastUI.NAVY0, 0.18)]],
			Vector2(0, 0.5), Vector2(1, 0.5))
	var L := BroadcastUI.layout(_root)
	_layout = L
	_shade = shade
	var el := match_mode.element if match_mode != null else MatchSetup.element
	# the title: the sport's tag and PAUSED
	var tl := BroadcastUI.group(L, Vector2(0, 0), Vector2(84, 40), Vector2(640, 160))
	BroadcastUI.put(tl, BroadcastUI.tag(w("menu_title"), 18, BroadcastUI.INK, BroadcastUI.TEAL, 3), Rect2(0, 0, 0, 0))
	var paused := BroadcastUI.lab("Paused", BroadcastUI.head(true, 3), 108, BroadcastUI.WHITE)
	paused.uppercase = true
	paused.name = "Title"
	BroadcastUI.put(tl, paused, Rect2(-4, 14, 620, 118))
	_note = BroadcastUI.lab("", BroadcastUI.body(true), 18, BroadcastUI.TEAL)
	_note.name = "Note"
	BroadcastUI.put(tl, _note, Rect2(2, 132, 620, 26))
	# the rows in a scroll that follows the focus: all in view at 1280 x 720, reachable in a smaller window too
	_rows_scroll = ScrollContainer.new()
	_rows_scroll.name = "Rows"
	_rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows_scroll.follow_focus = true
	_rows_scroll.anchor_bottom = 1.0
	_rows_scroll.offset_left = 62
	_rows_scroll.offset_right = 62 + 668
	_rows_scroll.offset_top = 196
	_rows_scroll.offset_bottom = -44
	L.add_child(_rows_scroll)
	# (a margin in the scroll so that the open row's plate, which leans out to the left of its number, is not cut by the scroll)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 22)
	pad.add_theme_constant_override("margin_right", 8)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_scroll.add_child(pad)
	_items = VBoxContainer.new()
	_items.add_theme_constant_override("separation", 2)
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(_items)
	_row(w("resume"), close)
	var rs := _row(w("restart"), restart, _restart_line())
	rs.name = "Restart"
	_setup_row = _row(w("match_setup"), setup_rows, _setup_line())
	_setup_row.name = "MatchSetup"
	_practice = _row(MatchSetup.pword("practice"), practice_rows, MatchSetup.pword("practice_line"))
	_practice.name = "Practice"
	_practice.visible = false
	_options_row = _row(w("options"), option_rows, w("options_line"))
	_options_row.name = "Options"
	var ctl := _row(KitWords.w("controls", "Controls"), _controls, KitWords.w("controls_line"))
	ctl.name = "Controls"
	# (your class and talents: the advancement window over this menu; what it changes applies from the next restart)
	_class_row = _row("Class & talents", class_talents, "changes apply from the next restart")
	_class_row.name = "ClassTalents"
	# (the other ways to pick moves: a row of the Controls panel, round 2; kept here, laid into the panel as it opens)
	_scheme = BroadcastUI.item(KitWords.other_ways_row(), 24, KitWords.other_ways_line())
	_scheme.name = "Scheme"
	_scheme.pressed.connect(cycle_scheme)
	_preset = BroadcastUI.item(MatchSetup.controls_row(), 24, MatchSetup.controls_row_line())
	_preset.name = "ControlsPreset"
	_preset.pressed.connect(cycle_controls)
	var st := _row(w("settings"), _settings)
	st.name = "Settings"
	_row(w("main_menu"), to_menu)
	_row(w("quit"), _quit)
	# the panel at the right in a plate, and the score bug across the top
	_panel_plate = Control.new()
	_panel_plate.name = "PanelPlate"
	_panel_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_plate.anchor_left = 1.0
	_panel_plate.anchor_right = 1.0
	_panel_plate.anchor_bottom = 1.0
	_panel_plate.offset_left = -800
	_panel_plate.offset_right = -70
	_panel_plate.offset_top = 170
	_panel_plate.offset_bottom = -76
	_panel_plate.visible = false
	L.add_child(_panel_plate)
	var pp := Panel.new()
	pp.add_theme_stylebox_override("panel", BroadcastUI.box(Color(BroadcastUI.NAVY1, 0.95), 0.0))
	pp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_plate.add_child(pp)
	pp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rule := ColorRect.new()
	rule.color = BroadcastUI.TEAL
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_plate.add_child(rule)
	rule.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rule.offset_bottom = 4
	_panel_scroll = ScrollContainer.new()
	_panel_scroll.name = "PanelScroll"
	_panel_scroll.anchor_left = 1.0
	_panel_scroll.anchor_right = 1.0
	_panel_scroll.anchor_bottom = 1.0
	_panel_scroll.offset_left = -774
	_panel_scroll.offset_right = -92
	_panel_scroll.offset_top = 184
	_panel_scroll.offset_bottom = -90
	_panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel_scroll.follow_focus = true
	L.add_child(_panel_scroll)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 14)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_scroll.add_child(_panel)
	_bug = BroadcastUI.group(L, Vector2(0.5, 0), Vector2(-360, 34), Vector2(720, 112))
	_bug.name = "ScoreBug"
	var hints := BroadcastUI.group(L, Vector2(1, 1), Vector2(-760, -58), Vector2(700, 36))
	var hh := BroadcastUI.hbox(26)
	hh.alignment = BoxContainer.ALIGNMENT_END
	hh.add_child(BroadcastUI.key_hint("ESC", "Resume"))
	hh.add_child(BroadcastUI.key_hint("ENTER", "Select"))
	hh.add_child(BroadcastUI.key_hint("← →", "Change"))
	BroadcastUI.put(hints, hh, Rect2(0, 0, 700, 36))
	# the Match setup panel's rows and the Options panel's, each under its heading (in the panel, hidden until opened)
	_setup = _sub_panel("Setup", w("match_setup"))
	var els: Array = Bending.ELEMENTS
	var el_opts: Array = []
	for e: String in els:
		el_opts.append({"text": MatchSetup.label(e), "color": BroadcastUI.plate_c(e), "glyph": e})
	_elem = _opt_row(_setup, "Element", "Element", el_opts, cycle_element, func(i: int) -> void:
		MatchSetup.element = String(els[i])
		_picked(_elem_text()))
	var foes: Array = Bending.ELEMENTS + [MatchSetup.ANY]
	var foe_opts: Array = []
	for e: String in foes:
		foe_opts.append({"text": MatchSetup.label(e), "color": BroadcastUI.plate_c(e) if e != MatchSetup.ANY else BroadcastUI.ec(MatchSetup.ANY),
				"glyph": e})
	_foe = _opt_row(_setup, "Opponent", "Opponent", foe_opts, cycle_opponent, func(i: int) -> void:
		MatchSetup.foes = [String(foes[i])]
		_picked(_foe_text()))
	_diff = _opt_row(_setup, "Difficulty", "Difficulty", _cap_words(MatchSetup.DIFFICULTIES), cycle_difficulty, func(i: int) -> void:
		MatchSetup.difficulty = String(MatchSetup.DIFFICULTIES[i])
		_picked(_diff_text()))
	_rules = _opt_row(_setup, "Rules", "Rules", [MatchSetup.rule_label("stock"), MatchSetup.rule_label("classic")], cycle_rules, func(i: int) -> void:
		MatchSetup.rules_choice = String(MatchSetup.RULE_SETS[i])
		MatchSetup.save()
		_picked(_rules_text()))
	_games = _opt_row(_setup, "Games", "Games", [MatchSetup.games_label(1), MatchSetup.games_label(3)], cycle_games, func(i: int) -> void:
		MatchSetup.games_n = int(MatchSetup.GAMES[i])
		MatchSetup.save()
		_picked(_games_text()))
	_options = _sub_panel("OptionRows", w("options"))
	_aim = _opt_row(_options, "AimHelp", "Aim help", _cap_words(MatchSetup.AIM_ORDER), cycle_aim, func(i: int) -> void:
		MatchSetup.set_aim_help(String(MatchSetup.AIM_ORDER[i]))
		_paint())
	_hints = _opt_row(_options, "KeyHints", "Key hints", ["On", "Off"], toggle_hints, func(i: int) -> void:
		if (i == 0) != FirstHints.on():
			toggle_hints())
	var cam_keys: Array = ["close", "shoulder", "high", "high_shoulder"]
	var cam_vars: Dictionary = RingCamera.data().get("variants", {})
	var cam_opts: Array = []
	for k: String in cam_keys:
		cam_opts.append(String((cam_vars.get(k, {}) as Dictionary).get("label", k)))
	_camera = _opt_row(_options, "Camera", "Camera", cam_opts, cycle_camera, func(i: int) -> void:
		RingCamera.set_key(String(cam_keys[i]))
		_paint())
	_jolt = _opt_row(_options, "ScreenJolt", "Screen jolt", [RingCamera.word("jolt_on"), RingCamera.word("jolt_off")], toggle_jolt, func(i: int) -> void:
		if (i == 0) != RingCamera.jolt_on():
			toggle_jolt())
	var rep_keys: Array = ["every", "last", "off"]
	var rep_opts: Array = []
	for k: String in rep_keys:
		rep_opts.append(RingReplay.word("row", k, k))
	_replays = _opt_row(_options, "Replays", "Replays", rep_opts, cycle_replays, func(i: int) -> void:
		RingReplay.set_setting(String(rep_keys[i]))
		_paint())
	_callouts = _opt_row(_options, "Callouts", "Callouts", ["On", "Off"], toggle_callouts, func(i: int) -> void:
		if (i == 0) != Callouts.on():
			toggle_callouts())
	# (the Character look, SoftLook: Classic or Soft, at once on both fighters, kept)
	_look = _opt_row(_options, "CharacterLook", "Character look", ["Classic", "Soft"], cycle_look, func(i: int) -> void:
		if String(SoftLook.MODES[i]) != SoftLook.mode():
			cycle_look())
	_photo = _sub_row(_options, "Photo", PhotoMode.row_text(), photo_mode, PhotoMode.row_line())
	_paint()


## `list`'s words as the chips show them ("easy", "light").
static func _cap_words(list: Array) -> Array:
	var out: Array = []
	for x in list:
		out.append(String(x).capitalize() if String(x) != "" else "")
	return out


## A value picked from a chip or with Left and Right: kept as the next restart's, and said.
func _picked(said: String) -> void:
	_paint()
	_note.text = w("applies") % said


## A panel's rows under its heading, kept in the right-hand panel and hidden until its row opens it.
func _sub_panel(nm: String, head: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = nm
	v.add_theme_constant_override("separation", 10)
	v.visible = false
	v.add_child(BroadcastUI.heading(head))
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 4)
	v.add_child(rows)
	_panel.add_child(v)
	return v


## A row of a panel that opens something of its own (Photo): its words, a chevron and its line.
func _sub_row(into: VBoxContainer, nm: String, text: String, what: Callable, sub_line := "") -> Button:
	var b := BroadcastUI.link_row(text, sub_line)
	b.name = nm
	b.pressed.connect(what)
	into.get_node(^"Rows").add_child(b)
	return b


## A row of a panel that holds a choice: its name and its values as chips (an OptionRow), `what` the press's step to the next,
## `pick` a chip's or Left and Right's choice of a value (an index).
func _opt_row(into: VBoxContainer, nm: String, title: String, options: Array, what: Callable, pick: Callable) -> Button:
	var b := BroadcastUI.option_row(title, options)
	b.name = nm
	b.pressed.connect(what)
	b.picker = pick
	into.get_node(^"Rows").add_child(b)
	return b


func _exit_tree() -> void:
	if is_instance_valid(_scheme) and _scheme.get_parent() == null:
		_scheme.queue_free()                  # (the scheme's row out of the Controls panel: freed with the menu)
	if is_instance_valid(_preset) and _preset.get_parent() == null:
		_preset.queue_free()


func _row(text: String, what: Callable, sub_line := "") -> Button:
	var el := match_mode.element if match_mode != null else MatchSetup.element
	var n := _rows.size() + 1
	var b := BroadcastUI.row("%02d" % n, text, sub_line, el, {"name": text.replace(" ", ""), "w": 600.0})
	b.pressed.connect(what)
	b.focus_entered.connect(_unhold)
	_items.add_child(b)
	_rows.append(b)
	return b


func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _open:
		if _kind != "":
			var back := _from if is_instance_valid(_from) and _from.is_visible_in_tree() else _items.get_child(0) as Button
			_clear_panel()
			back.grab_focus()
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


## The note under the title: "Round 2 · 1:42 left · You 1 : 0 Tide" ("Game 2 ..." in the % ring); in a practice (no clock,
## no score) what the dummy does: "Practice · a Stone dummy that throws at you every few seconds".
func note_text() -> String:
	if match_mode == null:
		return ""
	if match_mode.practice:
		var way := match_mode.practice_ctl.dummy if match_mode.practice_ctl != null else MatchSetup.dummy
		return w("menu_note_practice") % [MatchSetup.competitor(match_mode.foe_element), MatchSetup.dummy_line(way)]
	var left := match_mode.round_left_s()
	return w("menu_note_game" if match_mode.stock() else "menu_note") % [match_mode.round, floori(left / 60.0),
			floori(fmod(left, 60.0)), match_mode.score_text()]


## The Restart row's line: the match's ("the score nil, game 1 ...") or the practice's.
func _restart_line() -> String:
	if match_mode != null and match_mode.practice:
		return w("restart_line_practice")
	return w("restart_line_game") if RingRules.stock_on() else w("restart_line")


## The Match setup row's line: what the next restart plays ("Earth vs Water  ·  normal  ·  Lives").
func _setup_line() -> String:
	return w("setup_line") % [MatchSetup.label(MatchSetup.element), MatchSetup.label(MatchSetup.foe()), MatchSetup.difficulty,
			MatchSetup.rule_label()]


## The Rules row's line: the chosen rule set's only (practice.json menu.rules_line_stock / rules_line_classic).
func _rules_line() -> String:
	var k := "rules_line_" + MatchSetup.rule_set()
	var t := MatchSetup.menu_word(k)
	return t if t != k else MatchSetup.menu_word("rules_line")


func open() -> void:
	_open = true
	_note.text = ""
	_clear_panel()
	_practice.visible = match_mode != null and match_mode.practice and RingRules.stock_on()
	# (round 4: the camera's variants and the jolt are the % ring's; the zone rules' ring is as it was)
	_camera.visible = RingRules.stock_on()
	_jolt.visible = RingRules.stock_on()
	# (round 4 VIRAL: the replays, the callouts and photo mode run only under the % rules)
	_replays.visible = RingRules.stock_on()
	_callouts.visible = RingRules.stock_on()
	_photo.visible = RingRules.stock_on() and PhotoMode.find(get_tree()) != null
	_renumber()
	var el := match_mode.element if match_mode != null else MatchSetup.element
	for r: BroadcastUI.Row in _rows:
		r.set_element(el)
	_paint()
	_paint_bug()
	_root.visible = true
	MenuUI.cover_hud(self, true)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_items.get_child(0) as Button).grab_focus()


## The column's rows numbered as they stand in view (the Practice row only in a practice).
func _renumber() -> void:
	var n := 0
	for r: BroadcastUI.Row in _rows:
		if r.visible:
			n += 1
			r.set_num("%02d" % n)


## The score bug across the top: your side and theirs with the lives left as diamonds, the games between them, and the strip
## under it (the game or round, the time left, the rule; in a practice what the dummy does).
func _paint_bug() -> void:
	for c in _bug.get_children():
		_bug.remove_child(c)
		c.queue_free()
	var m := match_mode
	if m == null or not is_instance_valid(m):
		return
	var strip := BroadcastUI.hbox(0)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	if m.practice:
		strip.add_child(BroadcastUI.tag(note_text(), 18, BroadcastUI.WHITE, Color(BroadcastUI.NAVY1, 0.96), 3))
		BroadcastUI.put(_bug, strip, Rect2(0, 20, 720, 30))
		return
	var stock := m.stock()
	var max_l := int(RingRules.stock_num("stocks", 3.0))
	var l_you := m.lives_of(m.player) if stock else 0
	var l_foe := m.lives_of(m.foe) if stock and is_instance_valid(m.foe) else 0
	_bug_side(Rect2(0, 0, 272, 66), m.element, w("you"), l_you, max_l, false)
	BroadcastUI.plate(_bug, Rect2(268, 0, 184, 66), Color(BroadcastUI.NAVY0, 0.97))
	BroadcastUI.put(_bug, BroadcastUI.lab(str(m.score.x), BroadcastUI.head(), 62, BroadcastUI.WHITE, HORIZONTAL_ALIGNMENT_CENTER), Rect2(284, 2, 60, 66))
	BroadcastUI.put(_bug, BroadcastUI.lab(str(m.score.y), BroadcastUI.head(), 62, BroadcastUI.WHITE, HORIZONTAL_ALIGNMENT_CENTER), Rect2(376, 2, 60, 66))
	BroadcastUI.rect(_bug, Rect2(359, 18, 2, 30), Color(BroadcastUI.FAINT, 0.7))
	_bug_side(Rect2(448, 0, 272, 66), m.foe_element, m.foe_name(), l_foe, max_l, true)
	var left := m.round_left_s()
	var now := "%s  ·  %d:%02d left" % [w("game" if stock else "round") % m.round, floori(left / 60.0), floori(fmod(left, 60.0))]
	strip.add_child(BroadcastUI.tag(MatchSetup.rule_label(), 17, BroadcastUI.INK, BroadcastUI.TEAL, 3))
	strip.add_child(BroadcastUI.tag(now, 17, BroadcastUI.WHITE, Color(BroadcastUI.NAVY1, 0.96), 3))
	BroadcastUI.put(_bug, strip, Rect2(0, 72, 720, 30))


## One side of the score bug: the element's colour, its mark, its name and, under the rules of lives, the lives left as diamonds.
func _bug_side(r: Rect2, el: String, who: String, lives: int, max_lives: int, right: bool) -> void:
	var pc := BroadcastUI.plate_c(el)
	BroadcastUI.plate(_bug, r, pc)
	var gl := BroadcastUI.glyph(el, BroadcastUI.INK, 34.0, pc)
	var nm := BroadcastUI.caps(who, BroadcastUI.head(true, 2), 42, BroadcastUI.INK, HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT)
	var pips := BroadcastUI.hbox(5)
	if RingRules.stock_on():
		for i in max_lives:
			pips.add_child(BroadcastUI.glyph("diamond", BroadcastUI.INK if i < lives else Color(BroadcastUI.INK, 0.22), 14.0))
	if not right:
		BroadcastUI.put(_bug, gl, Rect2(r.position + Vector2(22, 16), Vector2(34, 34)))
		BroadcastUI.put(_bug, nm, Rect2(r.position + Vector2(66, 6), Vector2(120, 60)))
		BroadcastUI.put(_bug, pips, Rect2(r.position + Vector2(r.size.x - 82, 26), Vector2(60, 14)))
	else:
		BroadcastUI.put(_bug, pips, Rect2(r.position + Vector2(24, 26), Vector2(60, 14)))
		BroadcastUI.put(_bug, nm, Rect2(r.position + Vector2(r.size.x - 218, 6), Vector2(146, 60)))
		BroadcastUI.put(_bug, gl, Rect2(r.position + Vector2(r.size.x - 58, 16), Vector2(34, 34)))


func close() -> void:
	_open = false
	_root.visible = false
	MenuUI.cover_hud(self, false)
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


## The Match setup panel: Element, Opponent, Difficulty, Rules and Games, each from the next restart (the focus on its first).
func setup_rows() -> void:
	_show_sub(_setup, "setup", _setup_row)


## The Options panel: Aim help, Key hints, and in the % ring the camera, the jolt, the replays, the callouts and photo mode;
## each at once, kept.
func option_rows() -> void:
	_show_sub(_options, "options", _options_row)


func _show_sub(v: VBoxContainer, kind: String, from: Button) -> void:
	_clear_panel()
	_kind = kind
	_from = from
	_hold(from)
	_panel_plate.visible = true
	v.visible = true
	_paint()
	for b in v.get_node(^"Rows").get_children():
		if (b as Button).visible:
			(b as Button).grab_focus()
			break


## Round 3: the Practice rows (a % ring practice): each press steps its value, at once, kept.
func practice_rows() -> void:
	_clear_panel()
	_kind = "practice"
	_from = _practice
	_hold(_practice)
	_panel_plate.visible = true
	_panel.add_child(BroadcastUI.heading(MatchSetup.pword("practice")))
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
	var first := _panel.find_child("ForePct", false, false) as Button
	if first != null:
		first.grab_focus()


## "1", "1/2", "1/4".
static func speed_label(s: float) -> String:
	return "1" if s >= 0.99 else "1/%d" % roundi(1.0 / maxf(s, 0.01))


## One Practice row: its text now, its line, what a press does (then the text again, the setup kept).
func _prow(nm: String, text: Callable, sub: String, press: Callable) -> Button:
	var b := BroadcastUI.item(String(text.call()), 22, sub)
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
## The aim's help in turn (MatchSetup.AIM_ORDER: off, light, strong): at once, kept.
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
		if _open:
			MenuUI.cover_hud(self, false)      # (the hints just put up: away under the menu with the rest)
			MenuUI.cover_hud(self, true)
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


## Round 4 SIMPLE: Basic / Full in turn, at once (the match goes on with it), kept.
func cycle_controls() -> void:
	MatchSetup.set_controls(MatchSetup.next_controls())
	_paint()
	_note.text = String((MatchSetup.schemes_data().get("controls", {}) as Dictionary).get("changed", "Controls: %s")) \
			% MatchSetup.controls_label()
	if _kind == "controls":
		_controls()


## Round 4 VIRAL: the Splash Cam's replays in turn (Every fall, Last life only, Off): at once, kept.
func cycle_replays() -> void:
	RingReplay.cycle_setting()
	_paint()
	_note.text = RingReplay.row_text()


## The Character look (SoftLook) in turn, Classic and Soft: at once on every character, kept.
func cycle_look() -> void:
	SoftLook.set_mode(SoftLook.next_mode(), get_tree())
	_paint()
	_note.text = SoftLook.row_text()


## Round 4 VIRAL: the callouts on or off: at once, kept.
func toggle_callouts() -> void:
	Callouts.toggle()
	_paint()
	_note.text = Callouts.row_text()


## Round 4 VIRAL: photo mode (the menu closed first; Esc in it comes back to the match).
func photo_mode() -> void:
	var pm := PhotoMode.find(get_tree())
	if pm == null:
		return
	close()
	pm.enter()


func cycle_scheme() -> void:
	MatchSetup.set_scheme(MatchSetup.next_scheme())
	_paint()
	_note.text = String((MatchSetup.schemes_data().get("words", {}) as Dictionary).get("changed", "Control scheme: %s")) \
			% MatchSetup.scheme_label()
	if _kind == "controls":
		_controls()                           # (the Controls panel open: it follows)


func _elem_text() -> String:
	return w("element") % MatchSetup.label(MatchSetup.element)


func _foe_text() -> String:
	return w("opponent") % MatchSetup.label(MatchSetup.foe())


func _diff_text() -> String:
	return w("difficulty") % MatchSetup.difficulty


func _paint() -> void:
	_set_row(_setup_row, w("match_setup"), _setup_line())
	_set_row(_options_row, w("options"), w("options_line") if RingRules.stock_on() else w("options_line_zones"))
	var rs := _items.find_child("Restart", false, false) as Button
	_set_row(rs, w("restart"), _restart_line())
	var els: Array = Bending.ELEMENTS
	var foes: Array = Bending.ELEMENTS + [MatchSetup.ANY]
	_opt(_elem, _elem_text(), els.find(MatchSetup.element), KitWords.passive_line(MatchSetup.element))      # (the element's one passive, round 2)
	_opt(_foe, _foe_text(), foes.find(MatchSetup.foe()), w("opponent_line"))
	_opt(_diff, _diff_text(), MatchSetup.DIFFICULTIES.find(MatchSetup.difficulty), MatchSetup.difficulty_line(MatchSetup.difficulty))
	_opt(_rules, _rules_text(), MatchSetup.RULE_SETS.find(MatchSetup.rule_set()), _rules_line())
	_opt(_games, _games_text(), MatchSetup.GAMES.find(MatchSetup.games()), MatchSetup.menu_word("games_line"))
	_set_row(_scheme, KitWords.other_ways_row(), KitWords.other_ways_line())
	_set_row(_preset, MatchSetup.controls_row(), MatchSetup.controls_row_line())
	_opt(_aim, MatchSetup.aim_row(), MatchSetup.AIM_ORDER.find(MatchSetup.aim_help()), MatchSetup.aim_row_line())
	_opt(_hints, FirstHints.row_text(), 0 if FirstHints.on() else 1, FirstHints.row_line())
	var cam_keys: Array = ["close", "shoulder", "high", "high_shoulder"]
	_opt(_camera, RingCamera.row_text(), cam_keys.find(RingCamera.key()), RingCamera.row_line())
	_opt(_jolt, RingCamera.jolt_row_text(), 0 if RingCamera.jolt_on() else 1, RingCamera.word("jolt_line"))
	_opt(_replays, RingReplay.row_text(), ["every", "last", "off"].find(RingReplay.setting()), RingReplay.row_line())
	_opt(_callouts, Callouts.row_text(), 0 if Callouts.on() else 1, Callouts.row_line())
	_opt(_look, SoftLook.row_text(), SoftLook.MODES.find(SoftLook.mode()), SoftLook.row_line())


## An option row as its option stands now (an OptionRow: the words whole, the chip lit, the line).
static func _opt(b: Button, words: String, index: int, line: String) -> void:
	if b is BroadcastUI.OptionRow:
		(b as BroadcastUI.OptionRow).paint(words, index, line)
	else:
		_set_row(b, words, line)


static func _set_row(b: Button, text: String, sub_line := "") -> void:
	if b == null:
		return
	var t := b.find_child("Text", true, false) as Label
	if t:
		t.text = text
	var s := b.find_child("Sub", true, false) as Label
	if s and sub_line != "":
		s.text = sub_line


## The row that opened the panel drawn open while the panel stands (as the mock-up has it), the others at rest.
func _hold(b: Button) -> void:
	for r: BroadcastUI.Row in _rows:
		r.hold(r == b)


## No row held: the focus is back in the column (or the panel is gone).
func _unhold() -> void:
	for r: BroadcastUI.Row in _rows:
		r.hold(false)


func _clear_panel() -> void:
	_kind = ""
	_unhold()
	if _panel_plate != null:
		_panel_plate.visible = false
	for c in _panel.get_children():
		if c == _setup or c == _options:
			(c as Control).visible = false     # (the Match setup and Options rows are kept, hidden)
			continue
		_panel.remove_child(c)
		if c != _scheme and c != _preset:
			c.queue_free()                    # (the scheme's row is kept: it is laid in again)


## The element in play's buttons (round 2 of the skills, KitWords): its passive and its guard, each button with its plain
## names under the scheme now, the four rules, and "Other ways to pick moves" (the scheme in turn, at once, kept).
func _controls() -> void:
	_clear_panel()
	_kind = "controls"
	_panel_plate.visible = true
	_from = _items.find_child("Controls", false, false) as Button
	_hold(_from)
	var el := match_mode.element if match_mode != null else MatchSetup.element
	_panel.add_child(BroadcastUI.heading(KitWords.w("controls_head", "%s: your buttons") % MatchSetup.label(el)))
	if RingRules.stock_on():
		# (round 3: the % ring's one line, in right-click terms)
		_panel.add_child(BroadcastUI.label(MatchSetup.menu_word("controls_line"), 18, BroadcastUI.TEAL, true))
	_panel.add_child(_preset)                   # (round 4: Basic / Full first)
	_panel.add_child(_scheme)                   # (the other ways first: in view without a scroll)
	_scheme.visible = not MatchSetup.basic()    # (the schemes are Full's)
	for line in KitWords.pick_lines(el):
		_panel.add_child(BroadcastUI.label(String(line), 17, BroadcastUI.DIM, true))
	for line in control_lines(el):
		_panel.add_child(BroadcastUI.label(String(line), 18, BroadcastUI.WHITE, true))
	for line in KitWords.rule_lines():
		_panel.add_child(BroadcastUI.label(String(line), 16, BroadcastUI.DIM, true))


## "1   STRIKE   Spike  ·  tap twice: Boulder" for each button of `el` under the scheme now (KitWords.kit_lines).
static func control_lines(el: String) -> Array:
	return KitWords.kit_lines(el)


func _settings() -> void:
	_clear_panel()
	_kind = "settings"
	_panel_plate.visible = true
	_from = _items.find_child("Settings", false, false) as Button
	_hold(_from)
	_panel.add_child(BroadcastUI.heading(w("settings")))
	_panel.add_child(GameSettings.rows(match_mode.player if match_mode != null else null, true))


## Class & talents: the Character Advancement window over this menu (its own layer above it, working over the paused game), for
## the element in play. What it changes applies from the next restart (the row says so). Esc closes it and not this menu with it;
## the focus comes back to the row. Its "Your look" tab closes it and says in the note where the look is changed (the creator is
## the main menu's, never over a match).
func class_talents() -> void:
	_clear_panel()
	var el := match_mode.element if match_mode != null else MatchSetup.element
	var win := AdvancementWindow.open(self, el)
	if not win.closed.is_connected(_after_window):
		win.closed.connect(_after_window)
		win.look_requested.connect(_look_from_window.bind(win))
		# (the window has the whole screen: the menu's rows, bug and keys put away under it, the softened ring left)
		_layout.visible = false
		_shade.visible = false


func _after_window() -> void:
	_layout.visible = true
	_shade.visible = true
	if is_instance_valid(_class_row) and _class_row.is_visible_in_tree():
		_class_row.grab_focus.call_deferred()


func _look_from_window(win: AdvancementWindow) -> void:
	if win.is_pending():
		win.request_close()
		return
	win.close()
	_note.text = "Your look is changed from the main menu."


func to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0                      # (a slowed practice's speed left behind)
	MatchSetup.leave()
	get_tree().change_scene_to_file(MENU_SCENE)


func _quit() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().quit()
