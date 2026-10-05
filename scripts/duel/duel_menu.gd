class_name DuelMenu
extends CanvasLayer
## The duel's Esc menu (DuelMode; the user, 2026-10-04: "lets build a test game where it is 1v1 npc can find cover aim and
## etc"), in the pause menu's look (MenuUI, PauseMenu): the game stops under a dark veil, the rows at the left.
##   Resume              (Esc again)
##   Restart the duel    the score nil, round 1 (DuelMode.restart)
##   Difficulty: normal  easy, normal, hard in turn: the opponent's lock, aim and answers (data/npc/bend_ai.json presets;
##                       the marine's aim, NpcFighter.SKILLS), at once (DuelMode.set_difficulty)
##   Element: Earth      the player's element in turn: a new duel as it
##   Opponent: Earth     the opponent's element in turn (DuelMode.foe_element): a new duel against it
##   Settings            the main menu's (GameSettings)
##   Main menu           back to the title (nothing is saved in a duel)
##   Quit
## Installed by the duel in the pause menu's place (FrontierLevel); it keeps out of the way while something else holds the
## game (the inspect view pauses it) or another screen has the mouse (the Tab screen).

const MENU_SCENE := "res://scenes/main_menu.tscn"

var duel: DuelMode
var _root: Control
var _items: VBoxContainer
var _panel: VBoxContainer
var _note: Label
var _diff: Button
var _elem: Button
var _foe: Button
var _open := false


static func install(level: Node, d: DuelMode) -> DuelMenu:
	var m := DuelMenu.new()
	m.name = "DuelMenu"
	m.duel = d
	level.add_child(m)
	return m


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
	left.offset_top = 110
	left.offset_right = 88 + 560
	_root.add_child(left)
	left.add_child(MenuUI.label("The duel", 44, MenuUI.INK))
	_note = MenuUI.label("", 18, MenuUI.GOLD)
	left.add_child(_note)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	left.add_child(gap)
	_items = VBoxContainer.new()
	_items.add_theme_constant_override("separation", 4)
	left.add_child(_items)
	_row("Resume", close)
	_row("Restart the duel", restart)
	_diff = _row("Difficulty:  %s" % DuelMode.difficulty, cycle_difficulty, "the opponent's skill: how quick its locks, how close its aim")
	_elem = _row("Element:  %s" % DuelMode.element.capitalize(), cycle_element, "earth, water, fire, air: a new duel as it")
	_foe = _row("Opponent:  %s" % DuelMode.foe_element.capitalize(), cycle_foe, "the opponent's element: a new duel against it")
	_row("Settings", _settings)
	_row("Main menu", to_menu)
	_row("Quit", _quit)
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.5
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 20
	scroll.offset_right = -88
	scroll.offset_top = 130
	scroll.offset_bottom = -80
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 16)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_panel)


func _row(text: String, what: Callable, sub_line := "") -> Button:
	var b := MenuUI.item(text, 30, sub_line)
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
	var p := duel.player if duel != null else null
	return not (p != null and p.get("_inv_screen") != null and is_instance_valid(p.get("_inv_screen")))


func open() -> void:
	_open = true
	_note.text = duel.score_text() + "  ·  round %d" % duel.round if duel != null else ""
	_clear_panel()
	_paint_diff()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_items.get_child(0) as Button).grab_focus()


func close() -> void:
	_open = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The duel from its start (the menu closed).
func restart() -> void:
	close()
	if duel != null:
		duel.restart()


## The next difficulty in turn (easy, normal, hard), the marine's aim at once.
## The next element (Bending.ELEMENTS): the duel begun again with it.
func cycle_element() -> void:
	var list := Bending.ELEMENTS
	DuelMode.element = String(list[(list.find(DuelMode.element) + 1) % list.size()])
	if _elem != null:
		_elem.text = "Element:  %s" % DuelMode.element.capitalize()
	if duel != null:
		duel.choosing = false
		duel.lay_bar()
		duel.restart()


## The opponent's next element (Bending.ELEMENTS): the duel begun again against it.
func cycle_foe() -> void:
	var list := Bending.ELEMENTS
	var el := String(list[(list.find(DuelMode.foe_element) + 1) % list.size()])
	DuelMode.foe_element = el
	var t := _foe.find_child("Text", true, false) as Label if _foe != null else null
	if t:
		t.text = "Opponent:  %s" % el.capitalize()
	if duel != null:
		duel.set_foe(el)


func cycle_difficulty() -> void:
	var list := DuelMode.DIFFICULTIES
	var i := list.find(DuelMode.difficulty)
	var d: String = list[(i + 1) % list.size()]
	if duel != null:
		duel.set_difficulty(d)
	else:
		DuelMode.difficulty = d
	_paint_diff()
	_note.text = "The opponent's skill from now: %s" % d


func _paint_diff() -> void:
	if _diff == null:
		return
	var t := _diff.find_child("Text", true, false) as Label
	if t:
		t.text = "Difficulty:  %s" % DuelMode.difficulty


func _clear_panel() -> void:
	for c in _panel.get_children():
		_panel.remove_child(c)
		c.queue_free()


func _settings() -> void:
	_clear_panel()
	_panel.add_child(MenuUI.heading("Settings"))
	_panel.add_child(GameSettings.rows(duel.player if duel != null else null))


func to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _quit() -> void:
	get_tree().paused = false
	get_tree().quit()
