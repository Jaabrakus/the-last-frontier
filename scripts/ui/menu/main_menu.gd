class_name MainMenu
extends Control
## The main menu (user 2026-09-27: "a main menu hud for new game continue game multiple ? settings and campaigns"):
## the game's first scene (scenes/main_menu.tscn).
##
## Behind it pictures of the game itself (MenuPaintings.all(); user 2026-09-28: "have our game pictures instead of
## the paintings"), one after another, each drifting slowly nearer and crossfading to the next; the title and the menu
## at the left over a soft shade; the picture's title and caption at the lower left.
##   Continue      the latest save (its date and hour under it); only when there is one
##   New game      the start's switches (the story, a start with nothing, a spouse) and Begin: the level fresh, the
##                 character creator first (PlayerAppearance); no background to pick (everyone the default newcomer)
##   Load game     the saves (quick, auto), each with its date and when it was saved
##   Museum        the history of the time and the place (user 2026-09-28: "those paintings we put in a museum about
##                 the history around that day and age"): the period's paintings (MenuPaintings.museum()),
##                 one at a time over the whole screen with their stories; the arrows or Previous / Next go through
##                 them, Esc or Back leaves
##   Co-op, Campaigns   not yet (greyed, "coming")
##   Settings      volume, the mouse, invert, full screen, vsync (GameSettings)
##   Credits       the copyright and no-AI-training notice (NOTICE.txt), CREDITS.md as the project keeps it, and the
##                 licence in full (EULA.txt)
##   Quit
## The sub-screens open at the right; Esc (or the mouse's back) closes them. Keys and a gamepad move through the rows.
## Into the game through the LoadingScreen. Continue and Load hand the save to the level through SaveGame.pending (the
## level applies it when it is built); a new game sets SaveGame's launch as done, so no save is continued.
## `background_id` and `new_game` are read by the level (the background: the survival rules' start,
## SurvivalBridge.start_background(); the new game: the creator offered).

const GAME_SCENE := "res://scenes/main.tscn"
const SHOW_S := 16.0         ## s a painting shows before the next
const XFADE_S := 2.5
const DRIFT := 0.07

## Set by New game for the level: the chosen background (the survival rules' id) and that the creator is offered.
static var background_id := ""
static var new_game := false
## Set by New game's "Start with nothing": no tool, weapon, clothes or food (SurvivalBridge.start_bare(), taken once).
static var bare_start := false
## Whether this new game has a spouse (the New game screen's switch; taken once by the household).
static var spouse_start := true

var _a: TextureRect
var _b: TextureRect
var _cap_title: Label
var _cap_text: Label
var _items: VBoxContainer
var _panel: VBoxContainer
var _panel_scroll: ScrollContainer
var _t := 0.0
var _fade := -1.0
var _chosen_bg := ""
var _bare := false
var _story := true
var _squad := 1
var _spouse := true
var _museum: Control
var _museum_pic: TextureRect
var _museum_room: Label
var _museum_title: Label
var _museum_text: Label
var _museum_i := 0


## The level asks at its start: offer the creator for this new game (once).
static func take_new_game() -> bool:
	var v := new_game
	new_game = false
	return v


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSettings.apply_global()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.022, 0.014)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_a = _picture()
	_b = _picture()
	_b.modulate.a = 0.0
	var shade := MenuUI.left_shade(0.86)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.anchor_right = 0.58
	add_child(shade)
	var right := MenuUI.left_shade(0.8)
	right.set_anchors_preset(Control.PRESET_FULL_RECT)
	right.anchor_left = 0.5
	right.flip_h = true
	right.name = "RightShade"
	right.visible = false
	add_child(right)
	# the title and the menu
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.offset_left = 88
	left.offset_top = 90
	left.offset_right = 88 + 560
	add_child(left)
	var title := MenuUI.label("FRONTIER", 76, MenuUI.INK)
	var fv := FontVariation.new()
	fv.base_font = FrontierHUD.serif()
	fv.spacing_glyph = 10
	title.add_theme_font_override("font", fv)
	left.add_child(title)
	left.add_child(MenuUI.label("Cosby's Manor, on the Mohawk  ·  1765", 22, MenuUI.GOLD))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 34)
	left.add_child(gap)
	_items = VBoxContainer.new()
	_items.add_theme_constant_override("separation", 3)
	left.add_child(_items)
	_build_items()
	# the painting's caption at the lower left
	var cap := VBoxContainer.new()
	cap.add_theme_constant_override("separation", 6)
	cap.anchor_top = 1.0
	cap.anchor_bottom = 1.0
	cap.offset_left = 88
	cap.offset_right = 88 + 560
	cap.offset_top = -56
	cap.offset_bottom = -56
	cap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(cap)
	_cap_title = MenuUI.label("", 20, MenuUI.GOLD)
	cap.add_child(_cap_title)
	_cap_text = MenuUI.label("", 16, MenuUI.DIM, true)
	cap.add_child(_cap_text)
	# the sub-screens at the right
	_panel_scroll = ScrollContainer.new()
	_panel_scroll.anchor_left = 0.52
	_panel_scroll.anchor_right = 1.0
	_panel_scroll.anchor_bottom = 1.0
	_panel_scroll.offset_left = 20
	_panel_scroll.offset_right = -88
	_panel_scroll.offset_top = 110
	_panel_scroll.offset_bottom = -80
	_panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel_scroll.visible = false
	add_child(_panel_scroll)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 16)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_scroll.add_child(_panel)
	_show(MenuPaintings.next(), _a)
	_first_focus()


func _picture() -> TextureRect:
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _show(e: Dictionary, on: TextureRect) -> void:
	if e.is_empty():
		return
	on.texture = MenuPaintings.texture(e)
	on.stretch_mode = MenuPaintings.stretch(e)
	on.anchor_left = 0.34 if bool(e.get("whole", false)) else 0.0      # a portrait beside the menu, not under it
	on.pivot_offset = get_viewport_rect().size * Vector2(randf_range(0.35, 0.65), randf_range(0.35, 0.65))
	on.scale = Vector2.ONE
	on.set_meta(&"t", 0.0)
	_cap_title.text = MenuPaintings.title_line(e)
	_cap_text.text = String(e.caption)


func _process(delta: float) -> void:
	_t += delta
	for r: TextureRect in [_a, _b]:
		var t := float(r.get_meta(&"t", 0.0)) + delta
		r.set_meta(&"t", t)
		var s := 1.0 + DRIFT * clampf(t / (SHOW_S + XFADE_S), 0.0, 1.0)
		r.scale = Vector2(s, s)
	if _fade < 0.0 and _t >= SHOW_S:
		_fade = 0.0
		_show(MenuPaintings.next(), _b)
	if _fade >= 0.0:
		_fade += delta
		var u := clampf(_fade / XFADE_S, 0.0, 1.0)
		_b.modulate.a = u
		_a.modulate.a = 1.0 - u
		if u >= 1.0:
			var old := _a
			_a = _b
			_b = old
			_b.modulate.a = 0.0
			move_child(_a, 1)
			move_child(_b, 2)
			_fade = -1.0
			_t = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if _museum and _museum.visible:
		if event.is_action_pressed(&"ui_cancel"):
			_close_museum()
		elif event.is_action_pressed(&"ui_left"):
			_museum_show(_museum_i - 1)
		elif event.is_action_pressed(&"ui_right"):
			_museum_show(_museum_i + 1)
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel") and _panel_scroll.visible:
		_close_panel()
		get_viewport().set_input_as_handled()


# --- The menu -----------------------------------------------------------------------------------------------

func _build_items() -> void:
	for c in _items.get_children():
		c.queue_free()
	var latest := SaveGame.latest_slot()
	if latest != "":
		var b := MenuUI.item("Continue", 32, _save_line(latest))
		b.pressed.connect(_play_save.bind(latest))
		_items.add_child(b)
	var ng := MenuUI.item("New game", 32)
	ng.pressed.connect(_open_new_game)
	_items.add_child(ng)
	var ld := MenuUI.item("Load game", 32, "", "" if latest != "" else "no saves yet")
	ld.pressed.connect(_open_load)
	_items.add_child(ld)
	var mu := MenuUI.item("Museum", 32)
	mu.pressed.connect(_open_museum)
	_items.add_child(mu)
	var co := MenuUI.item("Co-op", 32, "host a game or join a friend's")
	co.pressed.connect(_open_coop)
	_items.add_child(co)
	_items.add_child(MenuUI.item("Campaigns", 32, "", "coming"))
	var st := MenuUI.item("Settings", 32)
	st.pressed.connect(_open_settings)
	_items.add_child(st)
	var cr := MenuUI.item("Credits", 32)
	cr.pressed.connect(_open_credits)
	_items.add_child(cr)
	var q := MenuUI.item("Quit", 32)
	q.pressed.connect(func() -> void: get_tree().quit())
	_items.add_child(q)


func _first_focus() -> void:
	for c in _items.get_children():
		if c is Button and not (c as Button).disabled:
			(c as Button).grab_focus.call_deferred()
			return


## A save's line: "Autosave  ·  25 August 1765, 20:24  ·  3 minutes ago".
static func _save_line(slot: String) -> String:
	var d := SaveGame.read_slot(slot)
	var meta: Dictionary = d.get("meta", {})
	var parts: Array = ["Autosave" if slot == "auto" else ("Quick save" if slot == "quick" else slot.capitalize())]
	if meta.has("date"):
		parts.append("%s%s" % [String(meta.date), (", " + String(meta.time)) if meta.has("time") else ""])
	var ago := Time.get_unix_time_from_system() - float(meta.get("saved_unix", 0.0))
	if meta.has("saved_unix"):
		parts.append(_ago(ago))
	return "  ·  ".join(parts)


static func _ago(s: float) -> String:
	if s < 90.0:
		return "just now"
	if s < 3600.0:
		return "%d minutes ago" % roundi(s / 60.0)
	if s < 86400.0 * 1.5:
		var h := roundi(s / 3600.0)
		return "an hour ago" if h == 1 else "%d hours ago" % h
	return "%d days ago" % roundi(s / 86400.0)


# --- Into the game -----------------------------------------------------------------------------------------

func _play_save(slot: String) -> void:
	var doc := SaveGame.read_slot(slot)
	if doc.is_empty():
		_build_items()
		return
	SaveGame.pending = doc
	SaveGame.pending_slot = slot
	SaveGame._launched = true
	new_game = false
	bare_start = false
	spouse_start = true
	StoryDirector.incoming = ""     # (a save has its own story)
	background_id = ""              # (a save has its own)
	LoadingScreen.go(get_tree(), GAME_SCENE, true)


func _play_new() -> void:
	SaveGame.pending = {}
	SaveGame._launched = true         # (a new game: the latest save is not continued)
	background_id = _chosen_bg
	bare_start = _bare
	spouse_start = _spouse
	StoryDirector.incoming = "two_fires" if _story else ""
	new_game = true
	GameSettings.clear_run()          # (a new game takes the Iron Man toggle)
	LoadingScreen.go(get_tree(), GAME_SCENE)


# --- The sub-screens ---------------------------------------------------------------------------------------

func _open_panel() -> void:
	for c in _panel.get_children():
		_panel.remove_child(c)
		c.queue_free()
	_panel_scroll.visible = true
	_panel_scroll.scroll_vertical = 0
	(get_node("RightShade") as CanvasItem).visible = true
	for r: TextureRect in [_a, _b]:
		r.self_modulate = Color(0.4, 0.4, 0.4)       # the painting dimmed under the text


func _close_panel() -> void:
	_panel_scroll.visible = false
	(get_node("RightShade") as CanvasItem).visible = false
	for r: TextureRect in [_a, _b]:
		r.self_modulate = Color.WHITE
	_first_focus()


# --- The museum ----------------------------------------------------------------------------------------------

func _open_museum() -> void:
	_close_panel()
	if _museum == null:
		_build_museum()
	_museum.visible = true
	_museum_show(_museum_i)
	var nx := _museum.find_child("Next", true, false) as Button
	if nx:
		nx.grab_focus()


func _close_museum() -> void:
	if _museum:
		_museum.visible = false
	_first_focus()


func _build_museum() -> void:
	_museum = Control.new()
	_museum.name = "Museum"
	_museum.set_anchors_preset(Control.PRESET_FULL_RECT)
	_museum.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_museum)
	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.018, 0.012)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_museum.add_child(bg)
	_museum_pic = TextureRect.new()
	_museum_pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	_museum_pic.offset_left = 60
	_museum_pic.offset_right = -60
	_museum_pic.offset_top = 40
	_museum_pic.offset_bottom = -200
	_museum_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_museum_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_museum_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_museum.add_child(_museum_pic)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 6)
	text.anchor_top = 1.0
	text.anchor_bottom = 1.0
	text.offset_left = 88
	text.offset_right = 88 + 900
	text.offset_top = -176
	text.offset_bottom = -30
	_museum.add_child(text)
	_museum_room = MenuUI.label("", 15, MenuUI.FAINT)
	text.add_child(_museum_room)
	_museum_title = MenuUI.label("", 26, MenuUI.GOLD)
	text.add_child(_museum_title)
	_museum_text = MenuUI.label("", 18, MenuUI.DIM, true)
	_museum_text.custom_minimum_size = Vector2(880, 0)
	text.add_child(_museum_text)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 26)
	nav.anchor_left = 1.0
	nav.anchor_right = 1.0
	nav.anchor_top = 1.0
	nav.anchor_bottom = 1.0
	nav.offset_left = -560
	nav.offset_right = -88
	nav.offset_top = -120
	nav.offset_bottom = -60
	nav.alignment = BoxContainer.ALIGNMENT_END
	_museum.add_child(nav)
	for e: Array in [["Prev", "Previous", -1], ["Next", "Next", 1], ["Back", "Back", 0]]:
		var b := MenuUI.item(String(e[1]), 26)
		b.name = String(e[0])
		b.custom_minimum_size = Vector2(140, 44)
		var step: int = e[2]
		if step == 0:
			b.pressed.connect(_close_museum)
		else:
			b.pressed.connect(func() -> void: _museum_show(_museum_i + step))
		nav.add_child(b)


## The museum's picture `i` (wrapping round), its room, title and story.
func _museum_show(i: int) -> void:
	var list := MenuPaintings.museum()
	if list.is_empty() or _museum == null:
		return
	_museum_i = wrapi(i, 0, list.size())
	var e: Dictionary = list[_museum_i]
	_museum_pic.texture = MenuPaintings.texture(e)
	_museum_room.text = "THE MUSEUM  ·  %d of %d" % [_museum_i + 1, list.size()]
	_museum_title.text = MenuPaintings.title_line(e)
	_museum_text.text = " ".join(e.captions)


func _open_new_game() -> void:
	_bare = false
	_spouse = true
	_story = true
	_open_panel()
	_panel.add_child(MenuUI.heading("A new life"))
	# (no background to choose: user 2026-10-01, "we shouldnt need to pick back country officers and etc"; you start as
	# the default newcomer, SurvivalBridge.BACKGROUND, and make your name in the game)
	_chosen_bg = ""
	var begin := MenuUI.item("Begin", 30)
	# the main story (scripts/story, docs/main_story.md), or free play
	var story_row := MenuUI.item("Story:  Two Fires", 22, "begins in the autumn of 1757 on open land by German Flatts; off: free play in 1765")
	story_row.pressed.connect(func() -> void:
		_story = not _story
		var t := story_row.find_child("Text", true, false) as Label
		if t:
			t.text = "Story:  %s" % ("Two Fires" if _story else "off (free play)"))
	_panel.add_child(story_row)
	# a start with nothing: no clothes, tools, weapons or food; everything made from what lies on the ground
	var bare_row := MenuUI.item("Start with nothing:  off", 22, "no clothes, tools or weapons: sticks, stones and chert from the ground, then the knapping stone")
	bare_row.pressed.connect(func() -> void:
		_bare = not _bare
		var t := bare_row.find_child("Text", true, false) as Label
		if t:
			t.text = "Start with nothing:  %s" % ("on" if _bare else "off"))
	_panel.add_child(bare_row)
	# a spouse at the start (a wife or husband who follows orders), or a life alone
	var spouse_row := MenuUI.item("Spouse:  on", 22, "a wife or husband beside you from the start who takes orders (gather, fell, carry); off: you begin alone")
	spouse_row.pressed.connect(func() -> void:
		_spouse = not _spouse
		var t := spouse_row.find_child("Text", true, false) as Label
		if t:
			t.text = "Spouse:  %s" % ("on" if _spouse else "off"))
	_panel.add_child(spouse_row)
	if SaveGame.latest_slot() != "":
		_panel.add_child(MenuUI.label("Your saves stay as they are; the autosave is written over as you play.", 16, MenuUI.FAINT, true))
	begin.pressed.connect(_play_new)
	_panel.add_child(begin)
	begin.grab_focus.call_deferred()


## Co-op (NetSession; docs/multiplayer_readiness.md): host this machine's game, or join one by its address. The game
## starts as Continue would (the latest save, else a new game) with the session asked for.
func _open_coop() -> void:
	_open_panel()
	_panel.add_child(MenuUI.heading("Co-op"))
	_panel.add_child(MenuUI.label("Play the valley together: your squad side by side, other squads to fight or to leave be.", 18, MenuUI.DIM, true))
	# the squad (Arc Raiders' way): the same squad is co-op, no friendly fire; another squad can be fought
	var sq := MenuUI.item("Squad:  %d" % _squad, 22, "friends on the same squad fight together; other squads can fight you")
	sq.pressed.connect(func() -> void:
		_squad = _squad % NetSession.SQUADS + 1
		var t := sq.find_child("Text", true, false) as Label
		if t:
			t.text = "Squad:  %d" % _squad)
	_panel.add_child(sq)
	var hb := MenuUI.item("Host a game", 26, "others join with this machine's address, port %d" % NetSession.PORT)
	hb.pressed.connect(func() -> void: _play_net({"mode": "host", "squad": _squad}))
	_panel.add_child(hb)
	var addr := LineEdit.new()
	addr.placeholder_text = "the host's address, e.g. 192.168.1.20"
	addr.text = "127.0.0.1"
	addr.custom_minimum_size = Vector2(420, 44)
	addr.add_theme_font_size_override("font_size", 20)
	_panel.add_child(addr)
	var jb := MenuUI.item("Join", 26, "the game at the address above")
	var note := MenuUI.label("", 17, MenuUI.DIM, true)
	jb.pressed.connect(func() -> void:
		# connect first, then the host's world comes and the game loads into it with your latest save's character
		var a := addr.text.strip_edges()
		note.text = "Joining %s ..." % a
		var n := NetSession.join_from_menu(get_tree(), a, _squad)
		if not n.multiplayer.connection_failed.is_connected(_join_failed):
			n.multiplayer.connection_failed.connect(_join_failed.bind(note)))
	_panel.add_child(jb)
	_panel.add_child(note)
	hb.grab_focus.call_deferred()


func _join_failed(note: Label) -> void:
	if is_instance_valid(note):
		note.text = "Could not reach the host. Check the address, and that the host's game is open."


func _play_net(mode: Dictionary) -> void:
	NetSession.incoming = mode
	var latest := SaveGame.latest_slot()
	if latest != "":
		_play_save(latest)
	else:
		_story = false
		_play_new()


func _open_load() -> void:
	_open_panel()
	_panel.add_child(MenuUI.heading("Load game"))
	var any := false
	for slot: String in SaveGame.SLOTS:
		if SaveGame.read_slot(slot).is_empty():
			continue
		any = true
		var b := MenuUI.item("Autosave" if slot == "auto" else ("Quick save" if slot == "quick" else slot.capitalize()), 26,
				_save_line(slot).get_slice("  ·  ", 1) + "  ·  " + _save_line(slot).get_slice("  ·  ", 2))
		b.pressed.connect(_play_save.bind(slot))
		_panel.add_child(b)
	if not any:
		_panel.add_child(MenuUI.label("No saves yet.", 19, MenuUI.DIM))
	var first := _panel.get_child(1) if _panel.get_child_count() > 1 else null
	if first is Button:
		(first as Button).grab_focus.call_deferred()


func _open_settings() -> void:
	_open_panel()
	_panel.add_child(MenuUI.heading("Settings"))
	_panel.add_child(GameSettings.rows())


func _open_credits() -> void:
	_open_panel()
	_panel.add_child(MenuUI.heading("Credits"))
	# the copyright notice and the no-AI-training reservation first (NOTICE.txt)
	for para: String in paragraphs(text_file("res://NOTICE.txt")):
		var n := MenuUI.label(para, 16, MenuUI.DIM, true)
		n.custom_minimum_size = Vector2(560, 0)
		_panel.add_child(n)
	for block: Array in credits():
		if String(block[0]) != "":
			_panel.add_child(MenuUI.label(String(block[0]), 21, MenuUI.GOLD, true))
		for para: String in block[1]:
			var l := MenuUI.label(para, 16, MenuUI.INK, true)
			l.custom_minimum_size = Vector2(560, 0)
			_panel.add_child(l)
	# the licence in full (EULA.txt), its section heads in gold
	var eula := paragraphs(text_file("res://EULA.txt"))
	if not eula.is_empty():
		_panel.add_child(MenuUI.heading("Licence", 30))
		for para: String in eula:
			var head := para == para.to_upper() and para.length() < 60
			var e := MenuUI.label(para, 19 if head else 15, MenuUI.GOLD if head else MenuUI.INK, true)
			e.custom_minimum_size = Vector2(560, 0)
			_panel.add_child(e)


## A text file's contents ("" when it is not there: an export without its non-resource files).
static func text_file(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## Paragraphs of a plain-text file: blocks between blank lines, their lines kept (the licence's lettered items).
static func paragraphs(text: String) -> Array:
	var out: Array = []
	for block in text.replace("\r\n", "\n").split("\n\n"):
		var t := block.strip_edges()
		if t != "":
			out.append(t)
	return out


## CREDITS.md as [heading, [paragraphs]] with the markdown taken off (headings, bold, code, links' brackets).
static func credits() -> Array:
	var out: Array = []
	var f := FileAccess.open("res://CREDITS.md", FileAccess.READ)
	if f == null:
		return [["", ["Credits: see CREDITS.md."]]]
	var head := ""
	var paras: Array = []
	var cur := ""
	for line in f.get_as_text().split("\n") + PackedStringArray(["## "]):
		var t := line.strip_edges()
		if t.begins_with("# "):
			continue
		var ends := t == "" or t.begins_with("## ") or t.begins_with("- ")
		if ends and cur.strip_edges() != "":
			paras.append(cur.strip_edges())
			cur = ""
		if t.begins_with("## "):
			if head != "" or not paras.is_empty():
				out.append([head, paras])
			head = t.substr(3)
			paras = []
			continue
		if t == "":
			continue
		if t.begins_with("- "):
			t = "·  " + t.substr(2)
		cur += (" " if cur != "" else "") + t
	for block: Array in out:
		var clean: Array = []
		for p: String in block[1]:
			clean.append(p.replace("**", "").replace("`", "").replace("*", ""))
		block[1] = clean
	return out
