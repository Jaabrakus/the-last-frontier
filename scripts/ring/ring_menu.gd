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
##   Control scheme: Keys  how moves are chosen, in turn (MatchSetup.set_scheme: keys, direction, wheel, simple): at once,
##                      kept (data/bending/schemes.json)
##   Controls           the chosen element's keys 1-5, each key's two skills with their three variations (Bending.keys,
##                      moves.json's labels), and how a cast is made; under another scheme its own lines
##                      (MatchSetup.scheme_key_lines) and its line
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
	_scheme = _row(MatchSetup.scheme_row(), cycle_scheme, MatchSetup.scheme_row_line())
	_scheme.name = "Scheme"
	_row(w("controls"), _controls, w("controls_line"))
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


## The next difficulty in turn (from the next restart).
func cycle_difficulty() -> void:
	var list := MatchSetup.DIFFICULTIES
	MatchSetup.difficulty = String(list[(list.find(MatchSetup.difficulty) + 1) % list.size()])
	_paint()
	_note.text = w("applies") % _diff_text()


## The next control scheme in turn: at once (the match goes on with it), kept for the next time.
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
	_set_row(_elem, _elem_text())
	_set_row(_foe, _foe_text())
	_set_row(_diff, _diff_text(), MatchSetup.difficulty_line(MatchSetup.difficulty))
	_set_row(_scheme, MatchSetup.scheme_row(), MatchSetup.scheme_row_line())


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
		c.queue_free()


## The element in play's keys: each key's two skills, each with its variations; how a cast is made.
func _controls() -> void:
	_clear_panel()
	var el := match_mode.element if match_mode != null else MatchSetup.element
	_panel.add_child(MenuUI.heading(w("controls_head") % MatchSetup.label(el)))
	if MatchSetup.scheme() == "keys":
		_panel.add_child(MenuUI.label(w("controls_how"), 17, MenuUI.DIM, true))
		for line in control_lines(el):
			_panel.add_child(MenuUI.label(String(line), 18, MenuUI.INK, true))
		return
	# (another control scheme: its own line and its lines; the keys' skills and variations after them)
	_panel.add_child(MenuUI.label("%s: %s" % [MatchSetup.scheme_label(), MatchSetup.scheme_row_line()], 17, MenuUI.DIM, true))
	for line in MatchSetup.scheme_key_lines(el):
		_panel.add_child(MenuUI.label(String(line), 18, MenuUI.INK, true))
	if MatchSetup.scheme() != "simple":
		for line in control_lines(el):
			_panel.add_child(MenuUI.label(String(line), 16, MenuUI.DIM, true))


## "1   Stone Form: spike, boulder, disc  ·  Rock Jab: pebbles, kick-up, stomp" for each key of `el`, Mend's last.
static func control_lines(el: String) -> Array:
	var out: Array = []
	var keys := Bending.keys(el)
	for i in keys.size():
		var parts: Array = []
		for id in keys[i] as Array:
			var m := SwayMoves.move(String(id))
			var nm := String(m.get("label", String(id).capitalize()))
			var modes: Array = []
			for md in SwayCaster.modes_of(String(id)):
				modes.append(SwayCaster.mode_label(String(id), String(md)))
			parts.append(nm + (": " + ", ".join(PackedStringArray(modes)) if not modes.is_empty() else ""))
		out.append("%d   %s" % [i + 1, "  ·  ".join(PackedStringArray(parts))])
	return out


func _settings() -> void:
	_clear_panel()
	_panel.add_child(MenuUI.heading(w("settings")))
	_panel.add_child(GameSettings.rows(match_mode.player if match_mode != null else null))


func to_menu() -> void:
	get_tree().paused = false
	MatchSetup.leave()
	get_tree().change_scene_to_file(MENU_SCENE)


func _quit() -> void:
	get_tree().paused = false
	get_tree().quit()
