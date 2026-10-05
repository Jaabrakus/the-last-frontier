class_name MainMenu
extends Control
## The main menu (user 2026-09-27: "a main menu hud for new game continue game multiple ? settings and campaigns"):
## the game's first scene (scenes/main_menu.tscn).
##
## Behind it pictures of the game itself (MenuPaintings.all(); user 2026-09-28: "have our game pictures instead of
## the paintings"), one after another, each drifting slowly nearer and crossfading to the next; the title and the menu
## at the left over a soft shade; the picture's title and caption at the lower left.
##
## The ring sport first (the owner, 2026-10-04: an elemental ring sport as the playable core now, the open world converted
## later; the sport is called Tidebreak; "1v1 first", the teams kept for a 3 v 3 later; no words from the show on the
## screen: every element and sport word comes from data/ring/elements.json through MatchSetup):
##   Tidebreak     the match's panel (_open_match): your element (the four side by side; below them the focused or
##                 chosen one's style in a line, its passive, what its guard does and its buttons with their plain names:
##                 KitWords), the opponent's (or Any: drawn by lot), the format (1 v 1; 3 v 3 teams coming), the
##                 difficulty, the rounds and the light, Controls (_open_controls: the buttons, the four rules and "Other
##                 ways to pick moves", MatchSetup.set_scheme; round 2: no four-way choice before a match); Begin into the ring
##                 (RING_SCENE; the open land's duel stands in until the ring's scene exists) through the
##                 LoadingScreen with MatchSetup filled and kept (MatchSetup.save: GameSettings' "match"). The first press
##                 with no look saved yet offers the character creator first (never over the ring's countdown:
##                 PlayerAppearance asks MatchSetup.active())
##   Quick match   the last setup at once with the opponent's element drawn at random (MatchSetup.quick_match; its line
##                 under it: "Fire against a random opponent  ·  normal  ·  best of 3"; the kept opponent left as it was)
##   Practice      a dummy to practise on (_open_practice: your element with its passive, guard and buttons, the dummy's
##                 element and way: stand, block or throw, Controls; MatchSetup.set_practice), into the ring with no clock,
##                 rounds or score (RingMode practice); its
##                 Lessons row the same practice with the lessons' cards (RingLessons.ask: your element's dummy, a card at
##                 a time, each done by doing it; its line says where they resume)
##   Your look     the character creator on the saved look (CharacterCreator; Accept keeps it)
##   Open world    the valley of 1765 as it was, in a sub-panel (its rows and their handlers unchanged; Esc from a screen
##                 opened there comes back to it):
##       Continue      the latest save (its date and hour under it); only when there is one
##       New game      the start's switches (the story, a start with nothing, a spouse) and Begin: the level fresh, the
##                     character creator first (PlayerAppearance); no background to pick (everyone the default newcomer)
##       Load game     the saves (quick, auto), each with its date and when it was saved
##       Museum        the history of the time and the place (user 2026-09-28: "those paintings we put in a museum about
##                     the history around that day and age"): the period's paintings (MenuPaintings.museum()),
##                     one at a time over the whole screen with their stories; the arrows or Previous / Next go through
##                     them, Esc or Back leaves
##       Co-op         host a game or join one (NetSession)
##       Duel (test)   the earlier 1 v 1 on the open land (DuelMode; the user, 2026-10-04: "lets build a test game where it
##                     is 1v1 npc can find cover aim and etc"): the level as a duel, no story, no needs, no save
##       Campaigns     not yet (greyed, "coming")
##   Settings      volume, the mouse, invert, full screen, vsync (GameSettings)
##   Credits       the copyright and no-AI-training notice (NOTICE.txt), CREDITS.md as the project keeps it, and the
##                 licence in full (EULA.txt)
##   Quit
## The sub-screens open at the right; Esc (or the mouse's back) closes them. Keys and a gamepad move through the rows.
## Into the game through the LoadingScreen. Continue and Load hand the save to the level through SaveGame.pending (the
## level applies it when it is built); a new game sets SaveGame's launch as done, so no save is continued. A test sets
## launch_hook to see where Begin would go without loading the ring (match_path()).
## `background_id` and `new_game` are read by the level (the background: the survival rules' start,
## SurvivalBridge.start_background(); the new game: the creator offered).

const GAME_SCENE := "res://scenes/main.tscn"
## The ring sport's light scene (RingLevel): the deck over the water, no open world loaded.
const RING_SCENE := "res://scenes/ring.tscn"
## The title over the menu and the line under it (constants for the name the owner gives the game).
const TITLE := "FRONTIER"
const SUBTITLE := "Cosby's Manor, on the Mohawk  ·  1765"
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
## A test's stand-in for the load into the ring: called with the scene's path instead of LoadingScreen.go (so a test sees
## where Begin goes, the setup filled, without loading the ring).
static var launch_hook := Callable()
## The creator offered once a run at the sport's first press (no look saved yet).
static var _look_offered := false

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
## The screen Esc goes back to (the Open world panel for the screens opened from it), else none: the panel closes.
var _return_to := Callable()
## The match panel's element rows (element -> Button) and its keys block.
var _element_rows := {}
var _keys_box: VBoxContainer


## The level asks at its start: offer the creator for this new game (once).
static func take_new_game() -> bool:
	var v := new_game
	new_game = false
	return v


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MatchSetup.leave()                      # (back at the menu: no match under way)
	if not SaveGame._is_script_run():
		MusicDirector.play_menu(self)       # the main theme (its bus made before the volumes are set)
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
	var title := MenuUI.label(TITLE, 76, MenuUI.INK)
	var fv := FontVariation.new()
	fv.base_font = FrontierHUD.serif()
	fv.spacing_glyph = 10
	title.add_theme_font_override("font", fv)
	left.add_child(title)
	left.add_child(MenuUI.label(SUBTITLE, 22, MenuUI.GOLD))
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
		_back()
		get_viewport().set_input_as_handled()


# --- The menu -----------------------------------------------------------------------------------------------

func _build_items() -> void:
	for c in _items.get_children():
		c.queue_free()
	MatchSetup.load()                     # (the last setup: the panel starts from it, Quick match plays it)
	var tb := MenuUI.item(MatchSetup.sport(), 32, MatchSetup.menu_line())
	tb.pressed.connect(_open_match)
	_items.add_child(tb)
	var qm := MenuUI.item("Quick match", 32, MatchSetup.quick_line())
	qm.pressed.connect(_quick_match)
	_items.add_child(qm)
	var pr := MenuUI.item("Practice", 32, _practice_line())
	pr.pressed.connect(_open_practice)
	_items.add_child(pr)
	var lk := MenuUI.item("Your look", 32, "the character creator: face, build and dress")
	lk.pressed.connect(_open_look)
	_items.add_child(lk)
	var ow := MenuUI.item("Open world", 32, "the valley, 1765: your saves, a new life, the museum, co-op")
	ow.pressed.connect(_open_world)
	_items.add_child(ow)
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
		if _panel_scroll.visible:
			_open_world()           # (the save gone: the Open world panel without it)
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


## The duel (test; DuelMode): the level as a duel, the story off, nothing continued or saved.
func _play_duel() -> void:
	SaveGame.pending = {}
	SaveGame._launched = true
	new_game = false
	bare_start = false
	spouse_start = false
	StoryDirector.incoming = ""
	background_id = ""
	MatchSetup.incoming = false
	DuelMode.incoming = true
	LoadingScreen.go(get_tree(), GAME_SCENE)


## Where the match panel's Begin goes: the ring's light scene.
static func match_path() -> String:
	return RING_SCENE


## A Tidebreak match with the setup as MatchSetup holds it (the panel's choices, or the last one for Quick match): kept for
## next time, then into the ring through the loading screen (launch_hook instead when a test set it). Nothing of the open
## world is continued or saved. Until the ring's scene exists (it is being built), the open land's duel with the chosen
## element and difficulty stands in.
func _play_match() -> void:
	SaveGame.pending = {}
	SaveGame._launched = true
	new_game = false
	bare_start = false
	spouse_start = false
	StoryDirector.incoming = ""
	background_id = ""
	DuelMode.incoming = false
	MatchSetup.incoming = true
	MatchSetup.save()
	var path := match_path()
	if launch_hook.is_valid():
		launch_hook.call(path)
		return
	if not ResourceLoader.exists(path):
		MatchSetup.incoming = false
		DuelMode.element = MatchSetup.element
		DuelMode.difficulty = MatchSetup.difficulty
		DuelMode.incoming = true
		path = GAME_SCENE
	LoadingScreen.go(get_tree(), path)


## Quick match: the last setup (GameSettings' "match"), the opponent's element drawn at random (MatchSetup.quick_match), at once.
func _quick_match() -> void:
	MatchSetup.quick_match()
	_play_match()


## The Practice row's line: "a Stone dummy that throws at you every few seconds" (the kept dummy).
static func _practice_line() -> String:
	var f := MatchSetup.foe()
	var who := "random" if f == MatchSetup.ANY else MatchSetup.competitor(f)
	return "a %s dummy that %s" % [who, MatchSetup.dummy_line(MatchSetup.dummy)]


## Practice (MatchSetup.set_practice; RingMode practice): your element, the dummy's element and its way (each press steps
## it; its line under it), and Begin into the ring with no clock, no rounds and no score. The keys there: R puts both back
## at their ends, B steps the dummy's way. Lessons (RingLessons.ask): the practice with the lessons' cards, against your
## element's lesson dummy (its line: how many, or where they resume, under the scheme and element chosen above).
func _open_practice() -> void:
	_open_panel()
	var box := VBoxContainer.new()
	box.name = "Practice"
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(box)
	box.add_child(MenuUI.heading("Practice"))
	var rule := MenuUI.label("A dummy at the far end: it stands, it blocks, or it throws at you. No clock, no rounds, no score.  "
			+ "In the ring R puts you both back at your ends and B changes what the dummy does.", 17, MenuUI.DIM, true)
	rule.custom_minimum_size = Vector2(520, 0)
	box.add_child(rule)
	box.add_child(_gap(6))
	var els: Array = Bending.ELEMENTS
	var mine := MenuUI.item("", 22, "-")
	mine.name = "Element"
	var lessons := MenuUI.item(RingLessons.word("menu_row"), 30, "-")
	lessons.name = "Lessons"
	var paint_lessons := func() -> void:
		_set_row(lessons, RingLessons.word("menu_row"), RingLessons.menu_line(MatchSetup.scheme(), MatchSetup.element))
	# (under your element: its passive, what its guard does and its buttons, as the Tidebreak panel shows them)
	var kit := VBoxContainer.new()
	kit.name = "Kit"
	kit.add_theme_constant_override("separation", 0)
	var paint_mine := func() -> void:
		var e := MatchSetup.element
		_set_row(mine, "Your element:  %s" % MatchSetup.label(e), "%s  ·  %s" % [MatchSetup.competitor(e), MatchSetup.style(e)])
		_fill_kit(kit, e, false)
		paint_lessons.call()
	paint_mine.call()
	mine.pressed.connect(func() -> void:
		MatchSetup.element = String(els[(els.find(MatchSetup.element) + 1) % els.size()])
		paint_mine.call())
	box.add_child(mine)
	box.add_child(kit)
	var foes: Array = Bending.ELEMENTS + [MatchSetup.ANY]
	var dum := MenuUI.item("", 22, "-")
	dum.name = "Dummy"
	var paint_dum := func() -> void:
		var f := MatchSetup.foe()
		_set_row(dum, "Dummy:  %s" % MatchSetup.label(f),
				MatchSetup.style(f) if f == MatchSetup.ANY else "%s  ·  %s" % [MatchSetup.competitor(f), MatchSetup.style(f)])
	paint_dum.call()
	dum.pressed.connect(func() -> void:
		MatchSetup.foes = [String(foes[(foes.find(MatchSetup.foe()) + 1) % foes.size()])]
		paint_dum.call())
	box.add_child(dum)
	var way := MenuUI.item("", 22, "-")
	way.name = "Way"
	var paint_way := func() -> void:
		_set_row(way, "What it does:  %s" % MatchSetup.dummy, "the dummy %s" % MatchSetup.dummy_line(MatchSetup.dummy))
	paint_way.call()
	way.pressed.connect(func() -> void:
		var ws := MatchSetup.DUMMIES
		MatchSetup.dummy = String(ws[(ws.find(MatchSetup.dummy) + 1) % ws.size()])
		paint_way.call())
	box.add_child(way)
	# (round 2: the other ways to pick moves under Controls, not here)
	box.add_child(_controls_row(_open_practice))
	box.add_child(_gap(4))
	var begin := MenuUI.item("Begin practice", 30)
	begin.name = "Begin"
	begin.pressed.connect(func() -> void:
		RingMode.lessons_asked = false
		MatchSetup.set_practice()
		_play_match())
	box.add_child(begin)
	# (the lessons: the same practice, its dummy the element's lesson dummy, the cards over it)
	var rule2 := MenuUI.label(RingLessons.word("panel_line"), 15, MenuUI.DIM, true)
	rule2.custom_minimum_size = Vector2(520, 0)
	box.add_child(rule2)
	lessons.pressed.connect(func() -> void:
		RingLessons.ask(MatchSetup.element)
		_play_match())
	box.add_child(lessons)
	begin.grab_focus.call_deferred()


# --- The sub-screens ---------------------------------------------------------------------------------------

func _open_panel() -> void:
	for c in _panel.get_children():
		_panel.remove_child(c)
		c.queue_free()
	_return_to = Callable()
	_element_rows = {}
	_keys_box = null
	_panel_scroll.visible = true
	_panel_scroll.scroll_vertical = 0
	(get_node("RightShade") as CanvasItem).visible = true
	for r: TextureRect in [_a, _b]:
		r.self_modulate = Color(0.4, 0.4, 0.4)       # the painting dimmed under the text


func _close_panel() -> void:
	_return_to = Callable()
	_panel_scroll.visible = false
	(get_node("RightShade") as CanvasItem).visible = false
	for r: TextureRect in [_a, _b]:
		r.self_modulate = Color.WHITE
	_first_focus()


## Esc: back to the screen this one was opened from (the Open world panel), else the panel closed.
func _back() -> void:
	if _return_to.is_valid():
		var r := _return_to
		_return_to = Callable()
		r.call()
	else:
		_close_panel()


## A screen opened from the Open world panel: Esc (and the museum's Back) come back to that panel.
func _from_world(open: Callable) -> void:
	open.call()
	_return_to = _open_world


# --- Tidebreak: the match's panel --------------------------------------------------------------------------

## The match's setup (MatchSetup; its words from data/ring/elements.json): the four elements side by side (under each the
## name its competitors go by, in its colour; the chosen one says so), below them the focused element's style in a line
## and its five keys (else the chosen one's), then Opponent, Format, Difficulty and Rounds (each press steps it; its line
## under it), and Begin, all in view without a scroll at 1600 x 900. The first press in a run with no look saved yet opens
## the character creator first, then this panel.
func _open_match() -> void:
	if not _look_offered and PlayerAppearance.offer_creator():
		_look_offered = true
		_close_panel()
		var c := _creator(true)
		c.closed.connect(func(_ok: bool) -> void: _open_match.call_deferred())
		return
	_open_panel()
	var box := VBoxContainer.new()
	box.name = "Match"
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(box)
	box.add_child(MenuUI.heading(MatchSetup.sport()))
	var rule := MenuUI.label(MatchSetup.sport_line(), 17, MenuUI.DIM, true)
	rule.custom_minimum_size = Vector2(520, 0)
	box.add_child(rule)
	box.add_child(_gap(4))
	box.add_child(MenuUI.label("YOUR ELEMENT", 14, MenuUI.FAINT))
	# the four side by side (each with the name its competitors go by under it, in its colour), then the focused or
	# chosen one's style and keys
	var four := HBoxContainer.new()
	four.name = "Elements"
	four.add_theme_constant_override("separation", 10)
	box.add_child(four)
	for el: String in Bending.ELEMENTS:
		var r := MenuUI.item(MatchSetup.label(el), 28, MatchSetup.competitor(el))
		r.name = "Element_" + el
		r.set_meta(&"element", el)
		r.custom_minimum_size.x = 130
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sub := r.find_child("Sub", true, false) as Label
		if sub:
			sub.add_theme_color_override("font_color", MatchSetup.color(el).lerp(MenuUI.DIM, 0.35))
		r.pressed.connect(_choose_element.bind(el))
		r.focus_entered.connect(_show_keys.bind(el))
		r.focus_exited.connect(_show_keys.bind(""))
		_element_rows[el] = r
		four.add_child(r)
	_keys_box = VBoxContainer.new()
	_keys_box.name = "Keys"
	_keys_box.add_theme_constant_override("separation", 0)
	box.add_child(_keys_box)
	box.add_child(_gap(6))
	# the opponent's element (or Any: by lot), the format, the difficulty and the rounds: a press steps each
	var foes: Array = Bending.ELEMENTS + [MatchSetup.ANY]
	var opp := MenuUI.item("", 22, "-")
	opp.name = "Opponent"
	var paint_opp := func() -> void:
		var f := MatchSetup.foe()
		_set_row(opp, "Opponent:  %s" % MatchSetup.label(f),
				MatchSetup.style(f) if f == MatchSetup.ANY else "%s  ·  %s" % [MatchSetup.competitor(f), MatchSetup.style(f)])
	paint_opp.call()
	opp.pressed.connect(func() -> void:
		MatchSetup.foes = [String(foes[(foes.find(MatchSetup.foe()) + 1) % foes.size()])]
		paint_opp.call())
	box.add_child(opp)
	var fm: Dictionary = (MatchSetup.data().get("formats", {}) as Dictionary).get("1v1", {})
	var fmt := MenuUI.item("Format:  %s" % String(fm.get("label", "1 v 1")), 22, String(fm.get("line", "")))
	fmt.name = "Format"
	box.add_child(fmt)
	var dif := MenuUI.item("", 22, "-")
	dif.name = "Difficulty"
	var paint_dif := func() -> void:
		_set_row(dif, "Difficulty:  %s" % MatchSetup.difficulty, MatchSetup.difficulty_line(MatchSetup.difficulty))
	paint_dif.call()
	dif.pressed.connect(func() -> void:
		var ds := MatchSetup.DIFFICULTIES
		MatchSetup.difficulty = String(ds[(ds.find(MatchSetup.difficulty) + 1) % ds.size()])
		paint_dif.call())
	box.add_child(dif)
	# (Rounds and Light side by side, so the control scheme's row fits with Begin still in view at 1600 x 900)
	var pair := HBoxContainer.new()
	pair.name = "RoundsLight"
	pair.add_theme_constant_override("separation", 10)
	box.add_child(pair)
	var rnd := MenuUI.item("", 22, "-")
	rnd.name = "Rounds"
	rnd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var paint_rnd := func() -> void:
		var n := MatchSetup.rounds_to_win
		_set_row(rnd, "Rounds:  %s" % MatchSetup.rounds_label(n), "the first to %d round win%s takes the match" % [n, "" if n == 1 else "s"])
	paint_rnd.call()
	rnd.pressed.connect(func() -> void:
		var rs := MatchSetup.ROUNDS
		var i := rs.find(MatchSetup.rounds_to_win)
		MatchSetup.rounds_to_win = int(rs[(i + 1) % rs.size()])
		paint_rnd.call())
	pair.add_child(rnd)
	var lit := MenuUI.item("", 22, "-")
	lit.name = "Light"
	lit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var paint_lit := func() -> void:
		_set_row(lit, "Light:  %s" % MatchSetup.light, MatchSetup.light_line(MatchSetup.light))
	paint_lit.call()
	lit.pressed.connect(func() -> void:
		var ls := MatchSetup.LIGHTS
		MatchSetup.light = String(ls[(ls.find(MatchSetup.light) + 1) % ls.size()])
		paint_lit.call())
	pair.add_child(lit)
	# (round 2 of the skills: the keys by default; the other ways to pick moves under Controls, no four-way choice here)
	box.add_child(_controls_row(_open_match))
	box.add_child(_gap(4))
	var begin := MenuUI.item("Begin", 30)
	begin.name = "Begin"
	begin.pressed.connect(func() -> void:
		MatchSetup.set_match()                # (a match, after a practice or a Quick match)
		_play_match())
	box.add_child(begin)
	_mark_elements()
	_show_keys("")
	begin.grab_focus.call_deferred()


## The element chosen (its row marked, its keys shown).
func _choose_element(el: String) -> void:
	MatchSetup.element = el
	_mark_elements()
	_show_keys(el)


## The chosen element's row says so under it ("Ember  ·  chosen").
func _mark_elements() -> void:
	for el: String in _element_rows:
		var b := _element_rows[el] as Button
		if is_instance_valid(b):
			_set_row(b, MatchSetup.label(el), MatchSetup.competitor(el) + ("  ·  chosen" if el == MatchSetup.element else ""))


## The block under the element rows: an element's style in a line (in its colour), its passive and what its guard does
## (KitWords.pick_lines: "Rooted: stand still and your locks fill faster ..."), then its buttons with their plain names
## ("1   STRIKE   Spike  ·  tap twice: Boulder"; KitWords.kit_lines under the scheme); `el` "" the chosen element's.
func _show_keys(el: String) -> void:
	if not is_instance_valid(_keys_box):
		return
	_fill_kit(_keys_box, el if el != "" else MatchSetup.element)


## Element `e`'s style, passive, guard and buttons laid into `box` (the Tidebreak panel's keys block, the Practice panel's).
static func _fill_kit(box: Control, e: String, with_style := true) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	box.add_child(_gap(6))
	if with_style:
		var style := MenuUI.label("%s  ·  %s" % [MatchSetup.competitor(e), MatchSetup.style(e)], 17,
				MatchSetup.color(e).lerp(MenuUI.INK, 0.35), true)
		style.custom_minimum_size = Vector2(520, 0)
		box.add_child(style)
	for line in KitWords.pick_lines(e):
		var l := MenuUI.label(String(line), 15, MenuUI.INK, true)
		l.custom_minimum_size = Vector2(520, 0)
		box.add_child(l)
	box.add_child(_gap(4))
	for line in KitWords.kit_lines(e):
		box.add_child(MenuUI.label(String(line), 15, MenuUI.DIM))


## An element's buttons as lines: "1   STRIKE   Spike  ·  tap twice: Boulder" (KitWords.kit_lines, the keys scheme).
static func key_lines(el: String) -> Array:
	return KitWords.kit_lines(el, "keys")


## The Controls row of the Tidebreak and Practice panels: its panel (_open_controls), Esc back to `back`.
func _controls_row(back: Callable) -> Button:
	var b := MenuUI.item(KitWords.w("controls", "Controls"), 22, KitWords.w("controls_line"))
	b.name = "Controls"
	b.pressed.connect(func() -> void:
		_open_controls()
		_return_to = back)
	return b


## Controls (round 2 of the skills, skills_r2 spec §6): the chosen element's buttons, the four rules, and "Other ways to pick
## moves" (MatchSetup.set_scheme in turn: the keys by default, then first moves only, direction and the wheel; kept at
## once). The only place before a match where the scheme is chosen: no four-way choice in the Tidebreak panel.
func _open_controls() -> void:
	_open_panel()
	var box := VBoxContainer.new()
	box.name = "ControlsPanel"
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(box)
	box.add_child(MenuUI.heading(KitWords.w("controls", "Controls")))
	var kit := VBoxContainer.new()
	kit.name = "Kit"
	kit.add_theme_constant_override("separation", 0)
	box.add_child(kit)
	var rules := VBoxContainer.new()
	rules.name = "Rules"
	box.add_child(rules)
	var paint := func() -> void:
		_fill_kit(kit, MatchSetup.element)
		for c in rules.get_children():
			rules.remove_child(c)
			c.queue_free()
		rules.add_child(_gap(6))
		for line in KitWords.rule_lines():
			var l := MenuUI.label(String(line), 16, MenuUI.INK, true)
			l.custom_minimum_size = Vector2(520, 0)
			rules.add_child(l)
	paint.call()
	box.add_child(_gap(6))
	var sch := MenuUI.item("", 22, "-")
	sch.name = "Scheme"
	var paint_sch := func() -> void:
		_set_row(sch, KitWords.other_ways_row(), KitWords.other_ways_line())
	paint_sch.call()
	sch.pressed.connect(func() -> void:
		MatchSetup.set_scheme(MatchSetup.next_scheme())
		paint_sch.call()
		paint.call())
	box.add_child(sch)
	sch.grab_focus.call_deferred()


## A row's main line and (when given) the line under it rewritten.
static func _set_row(b: Button, text: String, sub := "") -> void:
	var t := b.find_child("Text", true, false) as Label
	if t:
		t.text = text
	var s := b.find_child("Sub", true, false) as Label
	if s and sub != "":
		s.text = sub


static func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


# --- Your look, and the open world -----------------------------------------------------------------------

## The character creator over the menu, on the saved look (else the default): Accept keeps it (AppearanceStore). Made as
## CharacterCreator.open does, but from the saved look rather than the default one (there is no player here).
static func _creator(first := false) -> CharacterCreator:
	var c := CharacterCreator.new()
	c.first_launch = first
	c.look = AppearanceStore.load_current()
	(Engine.get_main_loop() as SceneTree).root.add_child(c)
	return c


func _open_look() -> void:
	_close_panel()
	var c := _creator()
	c.closed.connect(func(_ok: bool) -> void: _first_focus())


## The open world's rows (the valley of 1765), as the menu had them: Continue (a save), New game, Load game, Museum, Co-op,
## the duel test and Campaigns (coming).
func _open_world() -> void:
	_open_panel()
	_panel.add_child(MenuUI.heading("Open world"))
	var latest := SaveGame.latest_slot()
	if latest != "":
		var b := MenuUI.item("Continue", 28, _save_line(latest))
		b.pressed.connect(_play_save.bind(latest))
		_panel.add_child(b)
	var ng := MenuUI.item("New game", 28)
	ng.pressed.connect(_from_world.bind(_open_new_game))
	_panel.add_child(ng)
	var ld := MenuUI.item("Load game", 28, "", "" if latest != "" else "no saves yet")
	ld.pressed.connect(_from_world.bind(_open_load))
	_panel.add_child(ld)
	var mu := MenuUI.item("Museum", 28)
	mu.pressed.connect(_from_world.bind(_open_museum))
	_panel.add_child(mu)
	var co := MenuUI.item("Co-op", 28, "host a game or join a friend's")
	co.pressed.connect(_from_world.bind(_open_coop))
	_panel.add_child(co)
	var du := MenuUI.item("Duel (test): 1 v 1", 28, "the earlier test duel on the open land; first to %d" % DuelMode.TO_WIN)
	du.pressed.connect(_play_duel)
	_panel.add_child(du)
	_panel.add_child(MenuUI.item("Campaigns", 28, "", "coming"))
	for c in _panel.get_children():
		if c is Button and not (c as Button).disabled:
			(c as Button).grab_focus.call_deferred()
			break


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
	if _return_to.is_valid():
		_back()                 # (opened from the Open world panel: back to it)
	else:
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
