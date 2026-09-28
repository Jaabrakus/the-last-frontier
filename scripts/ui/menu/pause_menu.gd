class_name PauseMenu
extends CanvasLayer
## The pause menu (Esc in the game; user 2026-09-27, with the main menu): the game stops under a dark veil and the
## menu stands at the left in the main menu's lettering.
##   Resume     (Esc again)
##   Save       the quick save (F5's slot), and says so
##   Load       the saves (the main menu's list), the level rebuilt under the loading screen
##   Settings   the main menu's (GameSettings), the look's changes at once
##   Main menu  back to the title (the game autosaves first)
##   Quit       to the desktop (the game autosaves on quit)
## Installed by the level (FrontierLevel) after the player, so Esc reaches it before the player's own use of it (the
## mouse let go); it keeps out of the way while something else holds the game (the character creator pauses it) or
## the mouse is free for another screen (the Tab screen).

const MENU_SCENE := "res://scenes/main_menu.tscn"

var player: Node
var _root: Control
var _items: VBoxContainer
var _panel: VBoxContainer
var _note: Label
var _open := false


static func install(level: Node, p: Node) -> PauseMenu:
	var m := PauseMenu.new()
	m.name = "PauseMenu"
	m.player = p
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
	left.offset_right = 88 + 520
	_root.add_child(left)
	left.add_child(MenuUI.label("Paused", 44, MenuUI.INK))
	_note = MenuUI.label("", 18, MenuUI.GOLD)
	left.add_child(_note)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	left.add_child(gap)
	_items = VBoxContainer.new()
	_items.add_theme_constant_override("separation", 4)
	left.add_child(_items)
	for e: Array in [["Resume", close], ["Save", _save], ["Load", _load], ["Settings", _settings],
			["Main menu", _to_menu], ["Quit", _quit]]:
		var b := MenuUI.item(String(e[0]), 30)
		b.pressed.connect(e[1])
		_items.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.5
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 20
	scroll.offset_right = -88
	scroll.offset_top = 130
	scroll.offset_bottom = -80
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.name = "Scroll"
	_root.add_child(scroll)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 16)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_panel)


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


## Not while something else holds the game (the creator pauses it), or another screen has the mouse (the Tab
## screen, the equip wheel), or the player is dead.
func _can_open() -> bool:
	var tree := get_tree()
	if tree.paused:
		return false
	if player and bool(player.get("is_dead")):
		return false
	if player and player.get("_inv_screen") != null and is_instance_valid(player.get("_inv_screen")):
		return false
	return true


func open() -> void:
	_open = true
	_note.text = ""
	_clear_panel()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_items.get_child(0) as Button).grab_focus()


func close() -> void:
	_open = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _clear_panel() -> void:
	for c in _panel.get_children():
		_panel.remove_child(c)
		c.queue_free()


func _save() -> void:
	var sg := SaveGame.find(get_tree())
	if sg == null:
		_note.text = "Saving is off in this run."
		return
	var err := sg.save_game("quick")
	_note.text = "Saved." if err == OK else "Could not save now."


func _load() -> void:
	_clear_panel()
	_panel.add_child(MenuUI.heading("Load game"))
	var any := false
	for slot: String in SaveGame.SLOTS:
		if SaveGame.read_slot(slot).is_empty():
			continue
		any = true
		var line := MainMenu._save_line(slot)
		var b := MenuUI.item(line.get_slice("  ·  ", 0), 26, line.get_slice("  ·  ", 1) + "  ·  " + line.get_slice("  ·  ", 2))
		b.pressed.connect(func() -> void:
			var doc := SaveGame.read_slot(slot)
			if doc.is_empty():
				return
			SaveGame.pending = doc
			SaveGame.pending_slot = slot
			get_tree().paused = false
			LoadingScreen.go(get_tree(), get_tree().current_scene.scene_file_path, true))
		_panel.add_child(b)
	if not any:
		_panel.add_child(MenuUI.label("No saves yet.", 19, MenuUI.DIM))


func _settings() -> void:
	_clear_panel()
	_panel.add_child(MenuUI.heading("Settings"))
	_panel.add_child(GameSettings.rows(player))


func _to_menu() -> void:
	var sg := SaveGame.find(get_tree())
	if sg:
		sg.save_game("auto")
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _quit() -> void:
	get_tree().paused = false
	get_tree().quit()
