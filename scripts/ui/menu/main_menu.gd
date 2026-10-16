class_name MainMenu
extends Control
## The main menu (user 2026-09-27: "a main menu hud for new game continue game multiple ? settings and campaigns"):
## the game's first scene (scenes/main_menu.tscn). Since 2026-10-10 a LOBBY in the broadcast look the owner chose
## (BroadcastUI: Barlow type, leaning plates in your element's colour, numbered rows with a clear focus state): your own
## fighter, the saved look in the chosen element's ring dress and stance, stands on the deck at the right (FighterWorld: a live
## figure in a small world of its own, drawn over a plate of the ring's own noon deck and gate, assets/ui/menu/lobby_<element>.jpg;
## no ring is loaded), the rundown at the left, the next match's bug at the top right, the "your fighter" lower third (the
## character's name, your class, your talent points, your passive) and a ticker of the game's captions along the foot.
##
## The ring sport first (the owner, 2026-10-04: an elemental ring sport as the playable core now, the open world converted
## later; the sport is called Tidebreak; "1v1 first", the teams kept for a 3 v 3 later; no words from the show on the
## screen: every element and sport word comes from data/ring/elements.json through MatchSetup):
##   01 Tidebreak  the match setup (_open_match; a screen of its own over the deck): your element as four fighter cards (the
##                 saved look in each element's dress; under them the focused or chosen one's style, its passive and its
##                 buttons with their plain names: KitWords), and at the right the match: the opponent's element (or Any: drawn
##                 by lot), the difficulty, the rules (Lives or Zones), the games (one or best of 3 under the lives; the rounds
##                 under the zones), the light, Controls (_open_controls: the buttons, the four rules and "Other ways to pick
##                 moves", MatchSetup.set_scheme) and Begin into the ring (RING_SCENE) through the LoadingScreen with MatchSetup
##                 filled and kept (MatchSetup.save: GameSettings' "match"). The first press with no look saved yet offers the
##                 character creator first (never over the ring's countdown: PlayerAppearance asks MatchSetup.active())
##   02 Start here    the beginner's choices (_offer_basics): lessons, or an easy match
##   03 Quick match   the last setup at once with the opponent's element drawn at random (MatchSetup.quick_match; its line
##                    under it: "Fire against a random opponent  ·  normal  ·  best of 3"; the kept opponent left as it was)
##   04 Practice      a dummy to practise on (_open_practice: your element with its passive, guard and buttons, the dummy's
##                    element and way: stand, block or throw (the % ring's ways under its rules), round 3's % rows (its % and
##                    yours: 0 to 200 or grows, MatchSetup.foe_pct / my_pct), Controls; MatchSetup.set_practice), into the ring
##                    with no clock, rounds or score (RingMode practice); its Lessons row the same practice with the lessons'
##                    cards (RingLessons.ask: your element's dummy, a card at a time, each done by doing it)
##   05 Play online   a 1 v 1 against another player (_open_online; RingNet, docs/tidebreak/ring_netcode.md): Host a match (this
##                    machine's addresses shown, the host's match settings played), or the host's address and Join; into the
##                    ring as Begin goes (MatchSetup 1 v 1, RingNet.incoming the session asked for)
##   06 Class & talents  the Character Advancement window (_open_advancement: AdvancementWindow.open over the menu, for the
##                    lobby's element; its "Your look" tab opens the creator; the match setup has the same in a small link)
##   07 Your look     the character creator on the saved look (CharacterCreator; Accept keeps it)
## The character comes first and its element after it (the owner, 2026-10-10: "we just need the char made and then the element that
## char chooses"): once the creator is accepted (the first press of Tidebreak offers it; or Your look), and the character has no
## element yet, the screen "Choose your element" follows (_open_element_step: the match setup's four fighter cards, one pick,
## Enter to confirm; kept in the look: AppearanceStore.set_element). That element is what the lobby's fighter, the match setup,
## Quick match and the advancement window start from (MatchSetup.load); a match may still play another.
##   08 Settings      volume, the mouse, invert, full screen, vsync (GameSettings)
##   09 Credits       the copyright and no-AI-training notice (NOTICE.txt), CREDITS.md as the project keeps it, and the
##                    licence in full (EULA.txt)
##   10 Quit
## Legacy only: the retained Open world panel is not linked from the Tidebreak demo menu. Its rows and handlers remain
## available to development tools and their regression checks (Continue, New game, Load game, Museum, Co-op, the duel test,
## Campaigns); Esc from a screen opened there comes back to it.
## The sub-screens open at the right (the match setup over the whole screen); Esc (or the mouse's back) closes them. Keys and a
## gamepad move through the rows. Into the game through the LoadingScreen. Continue and Load hand the save to the level through
## SaveGame.pending (the level applies it when it is built); a new game sets SaveGame's launch as done, so no save is continued.
## A test sets launch_hook to see where Begin would go without loading the ring (match_path()).
## `background_id` and `new_game` are read by the level (the background: the survival rules' start,
## SurvivalBridge.start_background(); the new game: the creator offered).

const GAME_SCENE := "res://scenes/main.tscn"
## The ring sport's light scene (RingLevel): the deck over the water, no open world loaded.
const RING_SCENE := "res://scenes/ring.tscn"
## The title over the menu and the line under it (constants for the name the owner gives the game).
const TITLE := "TIDEBREAK"
const SUBTITLE := "ELEMENTAL ARENA COMBAT"
const SHOW_S := 16.0         ## s a caption shows before the next
const LOBBY_DIR := "res://assets/ui/menu/"
## A row of the match card at least this high (its parts are laid by _lay_match from their real heights).
const ROW_H := 84.0
## In a row of the match card: its name this far under the row's rule, and its line's last descender at least this far above the
## next row's rule (design px; the 2026-10-10 critic: at 1280 x 720 the wrapped lines touched the next rule).
## (Their least, the first pass's, where a small window has no room to spare: the card's foot inside the window comes first.)
const ROW_TOP := 6.0
const ROW_AIR := 14.0
const ROW_TOP_MIN := 4.0
const ROW_AIR_MIN := 8.0
## Begin's breath under Controls (full and least), and the least room kept under the card at the window's foot.
const BEGIN_AIR := 10.0
const BEGIN_AIR_MIN := 0.0
const CARD_FOOT := 8.0
const PREBUILD_IDLE_MS := 3000   ## ms the menu is left alone before another figure is built behind it
const ADVANCEMENT_WINDOW := "res://scripts/ui/advancement/advancement_window.gd"
const ADVANCEMENT_STORE := "res://scripts/ui/advancement/advancement_store.gd"
const ADVANCEMENT_DATA := "res://scripts/ui/advancement/advancement_data.gd"

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
## Tests: a stand-in for the character creator (called with `first`, it returns an object with a closed(accepted) signal; the real
## one is never opened in a test), and whether the first-run offer is checked as in a normal run (a test run never offers it).
static var creator_hook := Callable()
static var offer_check_run := true
## The live fighter in the lobby and on the setup's cards (a window only; a headless run never draws it).
static var live_fighter := true
## Whether this run has built its first menu's figure yet (the first is built before the first frame, behind the boot splash).
static var _booted := false

var _cap_title: Label
var _cap_text: Label
var _items: VBoxContainer
var _util: HBoxContainer
var _panel: VBoxContainer
var _panel_scroll: ScrollContainer
var _panel_plate: Control
var _menu_layout: Control
var _art_layout: Control
var _lobby: Control
var _right_lobby: Control
var _backdrop: TextureRect
var _fighter: TextureRect
var _blur: ColorRect
var _slab: Control
var _note_label: Label
var _fw: FighterWorld
var _fview: SubViewport
var _fview_el := ""
var _card_views := {}
var _t := 0.0
var _chosen_bg := ""
var _bare := false
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
## The match panel's element cards (element -> Button) and its keys block.
var _element_rows := {}
var _keys_box: Control
## What the lobby shows is for this element (MatchSetup.element when it was last painted).
var _lobby_el := ""
var _opened_from: Control
## The control that opened the advancement window (its name: the focus goes back to it), and whether its "Your look" tab asked
## for the creator as it closed.
var _adv_from := &"ClassTalents"
var _look_next := false
## What the menu showed before the advancement window covered it (_window_cover).
var _cover_was := {}
## The lobby's rows are built again when the match setup closes (a window changed what they say while it was open).
var _lobby_dirty := false
## When the next of the other figures may be built (0: none left), and when the player last touched the menu.
var _prebuild_at := 0
var _last_input_ms := 0
## The element step: what to do after it (the match setup, the lobby), and the match element it found (given back on Esc).
var _step_then := Callable()
var _step_prev := ""


## The level asks at its start: offer the creator for this new game (once).
static func take_new_game() -> bool:
	var v := new_game
	new_game = false
	return v


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	UiSounds.install(get_tree())             # (every button and slider heard: the menus' own sounds)
	PadInput.install(get_tree())             # (a controller's buttons on the menus and the game: PadInput)
	# (the menus are drawn for 1280 x 720 and up: below it the wordmark runs into its subtitle and the foot's keys are cut)
	var win := get_window()
	if win != null and win == get_tree().root:
		win.min_size = BroadcastUI.MIN_WINDOW
	MatchSetup.leave()                      # (back at the menu: no match under way)
	if not SaveGame._is_script_run():
		MusicDirector.play_menu(self)       # the main theme (its bus made before the volumes are set)
	GameSettings.apply_global()
	MatchSetup.load()                       # (the last setup: the lobby shows it, Quick match plays it)
	var bg := ColorRect.new()
	bg.color = BroadcastUI.NAVY0
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# the deck: the ring's own noon plate behind, the colour's slab and the fighter over it, the shades over them
	_backdrop = TextureRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	add_to_group(SoftWorld.HOSTS)
	_art_layout = BroadcastUI.cover(self)
	_art_layout.name = "ArtLayout"
	_slab = Control.new()
	_slab.name = "Slab"
	_slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_layout.add_child(_slab)
	_fighter = TextureRect.new()
	_fighter.name = "Fighter"
	_fighter.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fighter.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fighter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fighter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fighter.modulate.a = 0.0
	add_child(_fighter)
	# the shade at the left for the rundown, the foot for the ticker
	var shade := Control.new()
	shade.name = "Shades"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	BroadcastUI.grad(shade, [[0.0, Color(BroadcastUI.NAVY0, 0.94)], [0.36, Color(BroadcastUI.NAVY0, 0.80)],
			[0.62, Color(BroadcastUI.NAVY0, 0.0)]], Vector2(0, 0.5), Vector2(1, 0.5))
	BroadcastUI.grad(shade, [[0.0, Color(BroadcastUI.NAVY0, 0.0)], [0.70, Color(BroadcastUI.NAVY0, 0.0)],
			[1.0, Color(BroadcastUI.NAVY0, 0.75)]], Vector2(0.5, 0), Vector2(0.5, 1))
	# behind a screen: what is under it softened and dimmed (the match setup, the sub-screens)
	_blur = BroadcastUI.backdrop_blur(self, 2.6, 0.45)
	_blur.visible = false
	# the authored menu and its hit targets, in the 1600 x 900 design space fitted to the window
	_menu_layout = BroadcastUI.layout(self)
	_menu_layout.name = "MenuLayout"
	_build_lobby(_menu_layout)
	_build_panel_host(_menu_layout)
	_paint_lobby()
	_show(MenuPaintings.next())
	_first_focus()
	if live_fighter and FighterWorld.available():
		_fw = FighterWorld.make(self)
		if not _booted:
			# the game's first menu: the figures are built before the first frame is drawn, behind the boot splash (its minimum display
			# time holds it up for 1.2 s anyway): the cold build is about 1 s in one frame, which on a shown menu would be a freeze.
			# All four of them (the other three about 15 ms each once the first is dressed): built later behind the shown lobby, the
			# first of them made the renderer compile pipelines for 0.1 to 0.35 s in one frame (tools/ui_audit/lobby_perf.gd)
			_booted = true
			_swap_figure(MatchSetup.element)
			for e: String in Bending.ELEMENTS:
				_fw.ensure(e)
			_fade_in_figure.call_deferred()
		else:
			# (a menu after a match: the actor, the body and the ring dresses load on the loader's threads, then the figure is built
			# in steps, the menu answering meanwhile)
			FighterWorld.preload_assets()
			_build_figure.call_deferred()
	if RingAssist.offer_basics():
		_offer_basics.call_deferred()      # (round 4 SIMPLE: the game's first launch offers the Basics once)


# --- The lobby ---------------------------------------------------------------------------------------------

## The lobby's parts in `L`: the title block, the rundown, the next match's bug, the lower third and the ticker.
func _build_lobby(L: Control) -> void:
	_lobby = Control.new()
	_lobby.name = "Lobby"
	_lobby.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lobby.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.add_child(_lobby)
	# the top left: the lobby's tag and the title
	var tl := BroadcastUI.group(_lobby, Vector2(0, 0), Vector2(84, 40), Vector2(700, 260))
	var top := BroadcastUI.hbox(12)
	top.add_child(BroadcastUI.tag("LOBBY", 18, BroadcastUI.INK, BroadcastUI.TEAL, 3))
	top.add_child(BroadcastUI.lab("EARLY PLAYABLE DEMO  ·  IN DEVELOPMENT", BroadcastUI.head(false, 3, 1), 18, BroadcastUI.DIM))
	BroadcastUI.put(tl, top, Rect2(0, 0, 640, 28))
	var title := BroadcastUI.lab(TITLE, BroadcastUI.head(true, 3), 118, BroadcastUI.WHITE)
	title.name = "GameTitle"
	BroadcastUI.put(tl, title, Rect2(-6, -1, 700, 140))
	var sub := BroadcastUI.tag(SUBTITLE, 22, BroadcastUI.INK, BroadcastUI.WHITE, 4, Vector4(14, 3, 16, 0))
	(sub.get_child(0) as Label).name = "GameSubtitle"
	BroadcastUI.put(tl, sub, Rect2(4, 148, 0, 0))
	# the rundown (the rows are Buttons; the sections and the small row of the foot are beside them)
	var rd := BroadcastUI.group(_lobby, Vector2(0, 0), Vector2(84, 252), Vector2(600, 600))
	rd.name = "Rundown"
	_items = VBoxContainer.new()
	_items.name = "Items"
	_items.add_theme_constant_override("separation", 0)
	rd.add_child(_items)
	_build_items()
	# the right: the next match as the kept setup has it, and your fighter as a lower third
	_right_lobby = Control.new()
	_right_lobby.name = "RightLobby"
	_right_lobby.set_anchors_preset(Control.PRESET_FULL_RECT)
	_right_lobby.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby.add_child(_right_lobby)
	_build_bug(_right_lobby)
	_build_third(_right_lobby)
	# the ticker along the foot: the game's captions, one after another, and the keys
	_build_ticker(_lobby)
	_note_label = BroadcastUI.lab("", BroadcastUI.body(true), 18, BroadcastUI.TEAL)
	_note_label.name = "Note"
	_note_label.modulate.a = 0.0
	BroadcastUI.put(rd, _note_label, Rect2(6, 560, 560, 28))


## The panel host at the right (the sub-screens' plate and scroll) and the same scroll over the whole screen for the match
## setup (_set_panel_mode): the sub-screens put their rows into `_panel`.
func _build_panel_host(L: Control) -> void:
	_panel_plate = Control.new()
	_panel_plate.name = "PanelPlate"
	_panel_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_plate.anchor_left = 0.5
	_panel_plate.anchor_right = 1.0
	_panel_plate.anchor_bottom = 1.0
	_panel_plate.offset_left = -110
	_panel_plate.offset_right = -64
	_panel_plate.offset_top = 40
	_panel_plate.offset_bottom = -72
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
	_panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel_scroll.follow_focus = true
	_panel_scroll.visible = false
	L.add_child(_panel_scroll)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 14)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_scroll.add_child(_panel)
	_set_panel_mode(false)


## The scroll at the right in a plate (the sub-screens), or over the whole screen with no plate (the match setup).
func _set_panel_mode(full: bool) -> void:
	var s := _panel_scroll
	if full:
		s.anchor_left = 0.0
		s.anchor_right = 1.0
		s.anchor_top = 0.0
		s.anchor_bottom = 1.0
		s.offset_left = 0
		s.offset_right = 0
		s.offset_top = 0
		s.offset_bottom = 0
	else:
		s.anchor_left = 0.5
		s.anchor_right = 1.0
		s.anchor_top = 0.0
		s.anchor_bottom = 1.0
		s.offset_left = -88
		s.offset_right = -86
		s.offset_top = 62
		s.offset_bottom = -92
	_panel_plate.visible = not full and s.visible


## The next match's bug at the top right: "NEXT MATCH" and the kept setup in a line.
func _build_bug(P: Control) -> void:
	var g := BroadcastUI.group(P, Vector2(1, 0), Vector2(-720, 40), Vector2(640, 40))
	g.name = "Bug"
	var nm := BroadcastUI.hbox(0)
	nm.alignment = BoxContainer.ALIGNMENT_END
	nm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nm.add_child(BroadcastUI.tag("NEXT MATCH", 18, BroadcastUI.INK, BroadcastUI.TEAL, 3))
	var line := BroadcastUI.tag("-", 18, BroadcastUI.WHITE, Color(BroadcastUI.NAVY1, 0.92), 3)
	(line.get_child(0) as Label).name = "BugLine"
	nm.add_child(line)
	g.add_child(nm)


## The next match in a line: "1 v 1  ·  Lives  ·  best of 3  ·  normal" (the kept setup).
static func setup_line() -> String:
	var fm: Dictionary = (MatchSetup.data().get("formats", {}) as Dictionary).get(MatchSetup.format, {})
	var length := MatchSetup.rounds_label(MatchSetup.rounds_to_win)
	if MatchSetup.rule_set() == "stock":
		length = MatchSetup.rounds_label(2) if MatchSetup.games() >= 3 else String(MatchSetup.screens().get("one_game", "one game"))
	return "%s  ·  %s  ·  %s  ·  %s" % [String(fm.get("label", "1 v 1")), MatchSetup.rule_label(), length, MatchSetup.difficulty]


## "Your fighter" at the lower right: the element's mark and the character's name, the class, the talent points and the
## passive, and the element's style in a line under them.
func _build_third(P: Control) -> void:
	var lt := BroadcastUI.group(P, Vector2(1, 1), Vector2(-950, -290), Vector2(886, 214))
	lt.name = "FighterCard"
	var tab := BroadcastUI.hbox(0)
	tab.add_child(BroadcastUI.tag("YOUR FIGHTER", 17, BroadcastUI.INK, BroadcastUI.TEAL, 3))
	var which := BroadcastUI.tag("-", 17, BroadcastUI.WHITE, BroadcastUI.NAVY0, 3)
	(which.get_child(0) as Label).name = "Which"
	tab.add_child(which)
	BroadcastUI.put(lt, tab, Rect2(10, 0, 0, 0))
	var plate := BroadcastUI.plate(lt, Rect2(0, 32, 886, 100), Color(BroadcastUI.NAVY1, 0.95))
	plate.name = "Plate"
	var ep := BroadcastUI.plate(lt, Rect2(0, 32, 124, 100), Color.WHITE)
	ep.name = "ElementPlate"
	var mark := Control.new()
	mark.name = "MarkHolder"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	BroadcastUI.put(lt, mark, Rect2(34, 56, 52, 52))
	var nm := BroadcastUI.lab("-", BroadcastUI.head(true, 2), 74, BroadcastUI.WHITE)
	nm.name = "FighterName"
	nm.uppercase = true
	BroadcastUI.put(lt, nm, Rect2(146, 38, 232, 88))
	var stats := BroadcastUI.hbox(8)
	stats.name = "Stats"
	stats.alignment = BoxContainer.ALIGNMENT_END
	BroadcastUI.put(lt, stats, Rect2(380, 44, 490, 76))
	for k: String in ["CLASS", "TALENTS", "PASSIVE"]:
		var v := BroadcastUI.vbox(0)
		v.add_child(BroadcastUI.lab(k, BroadcastUI.head(false, 3, 1), 16, BroadcastUI.FAINT, HORIZONTAL_ALIGNMENT_CENTER))
		var val := BroadcastUI.caps("-", BroadcastUI.head(false, 1), 24, BroadcastUI.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		val.name = "Stat_" + k.capitalize()
		v.add_child(val)
		stats.add_child(BroadcastUI.chip(v, Color(BroadcastUI.NAVY3, 0.9), BroadcastUI.LEAN, Vector4(12, 4, 12, 2)))
	BroadcastUI.plate(lt, Rect2(-14, 132, 862, 44), Color(BroadcastUI.NAVY0, 0.92))
	var line := BroadcastUI.hbox(10)
	BroadcastUI.put(lt, line, Rect2(18, 134, 820, 40))
	var nick := BroadcastUI.tag("-", 16, BroadcastUI.INK, BroadcastUI.TEAL, 3)
	(nick.get_child(0) as Label).name = "Nickname"
	nick.name = "NicknameTag"
	line.add_child(nick)
	var style := BroadcastUI.lab("-", BroadcastUI.body(), 19, BroadcastUI.DIM)
	style.name = "StyleLine"
	line.add_child(style)


## The foot: "ON THE DECK" and the picture's title and caption (MenuPaintings, one after another), the keys at the right.
func _build_ticker(P: Control) -> void:
	var g := Control.new()
	g.name = "Ticker"
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P.add_child(g)
	g.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	g.offset_top = -66
	BroadcastUI.rect(g, Rect2(0, 0, 4000, 66), Color(BroadcastUI.NAVY0, 0.96)).name = "Bar"
	BroadcastUI.rect(g, Rect2(0, 0, 4000, 2), BroadcastUI.TEAL)
	var tag := BroadcastUI.tag("ON THE DECK", 22, BroadcastUI.INK, BroadcastUI.TEAL, 3, Vector4(54, 12, 22, 9))
	BroadcastUI.put(g, tag, Rect2(-40, 2, 0, 0))
	_cap_title = BroadcastUI.caps("", BroadcastUI.head(false, 2, 1), 22, BroadcastUI.WHITE)
	_cap_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	BroadcastUI.put(g, _cap_title, Rect2(250, 4, 330, 60))
	_cap_text = BroadcastUI.para("", BroadcastUI.body(true), 18, BroadcastUI.DIM, 620.0)
	_cap_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cap_text.custom_minimum_size = Vector2(0, 0)
	BroadcastUI.put(g, _cap_text, Rect2(590, 5, 610, 58))
	var kr := BroadcastUI.group(g, Vector2(1, 0), Vector2(-398, 2), Vector2(398, 64))
	BroadcastUI.rect(kr, Rect2(0, 0, 4000, 64), BroadcastUI.NAVY0)
	var h := BroadcastUI.hbox(18)
	h.add_child(BroadcastUI.key_hint("ENTER", "Select", 17))
	h.add_child(BroadcastUI.key_hint("ESC", "Back", 17))
	h.add_child(BroadcastUI.key_hint("↑ ↓", "Move", 17))
	BroadcastUI.put(kr, h, Rect2(16, 14, 382, 36))


## The lobby's deck plate for `el`: the ring as the Look setting draws it (Soft: lobby_soft_<el>.jpg, the ring in the study's
## light and colours; Classic: lobby_<el>.jpg).
static func lobby_plate(el: String) -> Texture2D:
	for path: String in ([LOBBY_DIR + "lobby_soft_%s.jpg" % el] if SoftLook.on() else []) + [LOBBY_DIR + "lobby_%s.jpg" % el]:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


## The Look setting changed (SoftWorld.refresh): the deck plate as it says now.
func soft_world_sync() -> void:
	if _backdrop != null:
		_backdrop.texture = lobby_plate(MatchSetup.element)


## The lobby for MatchSetup.element: its deck plate, the colour's slab, your fighter's card, the bug, the rows' colour. Again
## after the setup changed the element (the screen back from the match setup).
func _paint_lobby() -> void:
	var el := MatchSetup.element
	var pc := BroadcastUI.plate_c(el)
	_backdrop.texture = lobby_plate(el)
	# the slab of your colour behind your fighter, a teal sweep beside it, a white edge; the hatching melts away down it
	for c in _slab.get_children():
		_slab.remove_child(c)
		c.queue_free()
	_slab.position = Vector2(800, 0)
	BroadcastUI.slab(_slab, 1035.0 - 800.0, 1215.0 - 800.0, 900.0, pc, 0.88, 0.0)
	BroadcastUI.slab(_slab, 1000.0 - 800.0, 1016.0 - 800.0, 900.0, BroadcastUI.TEAL, 0.95, 0.0)
	BroadcastUI.slab(_slab, 1234.0 - 800.0, 1242.0 - 800.0, 900.0, BroadcastUI.WHITE, 0.55, 0.0)
	BroadcastUI.stripes(_slab, Rect2(1050.0 - 800.0, 0, 300, 420), Color(BroadcastUI.INK, 0.10), 12, 3, 1.0)
	var fc := _lobby.find_child("FighterCard", true, false)
	if fc != null:
		var info := fighter_info(el)
		(fc.find_child("Which", true, false) as Label).text = "%s  ·  %s" % [MatchSetup.label(el), String(info.cls)]
		(fc.find_child("Which", true, false) as Label).uppercase = true
		var ep := fc.find_child("ElementPlate", true, false) as Panel
		ep.add_theme_stylebox_override("panel", BroadcastUI.box(pc))
		var holder := fc.find_child("MarkHolder", true, false) as Control
		for c in holder.get_children():
			holder.remove_child(c)
			c.queue_free()
		holder.add_child(BroadcastUI.glyph(el, BroadcastUI.INK, 52.0, pc))
		var nm := fc.find_child("FighterName", true, false) as Label
		nm.text = String(info.name)
		nm.set_meta(&"dsz", 74)
		BroadcastUI.fit_text(nm, 228.0, 40)
		(fc.find_child("Stat_Class", true, false) as Label).text = String(info.cls)
		(fc.find_child("Stat_Talents", true, false) as Label).text = String(info.talents)
		(fc.find_child("Stat_Passive", true, false) as Label).text = String(info.passive)
		for k: String in ["Class", "Talents", "Passive"]:
			((fc.find_child("Stat_" + k, true, false)) as Label).add_theme_color_override("font_color", pc if el != "air" else Color("7cc4e6"))
		(fc.find_child("Nickname", true, false) as Label).text = MatchSetup.competitor(el)
		var tagbox := fc.find_child("NicknameTag", true, false) as PanelContainer
		tagbox.add_theme_stylebox_override("panel", BroadcastUI.box(pc, BroadcastUI.LEAN, 0, Color.TRANSPARENT, Vector4(12, 2, 12, 0)))
		(fc.find_child("StyleLine", true, false) as Label).text = MatchSetup.style(el)
	var bug := _lobby.find_child("BugLine", true, false) as Label
	if bug != null:
		bug.text = setup_line()
	_lobby_el = el
	if _fw != null and _fview_el != el:
		_swap_figure(el)


## Your fighter for the lower third: {name (the character's, else "You"), cls (the class: the fighting style), talents
## ("10 pts"), passive}. The class and the points come from the advancement window's store when it is in the build.
static func fighter_info(el: String) -> Dictionary:
	var cls := String(MatchSetup.competitor(el))
	var points := 10
	var store := _script_of(ADVANCEMENT_STORE)
	var data := _script_of(ADVANCEMENT_DATA)
	if store != null and data != null:
		var st: Dictionary = data.call(&"style", String(store.call(&"style_of", el)))
		if not st.is_empty():
			cls = String(st.get("label", cls))
		var lo: Variant = store.call(&"worn_loadout", el)
		if lo is Object and (lo as Object).has_method(&"left"):
			points = int((lo as Object).call(&"left"))
	return {"name": FighterWorld.fighter_name(), "cls": cls, "talents": "%d pts" % points,
			"passive": String(KitWords.passive(el).get("name", ""))}


## A script of the build that the menu does not depend on (the advancement window's, written beside it), or null.
static func _script_of(path: String) -> Script:
	return load(path) as Script if ResourceLoader.exists(path) else null


## The lobby's figure: the saved look in `el`'s ring dress, drawn over the deck plate. Made after the menu's first frames and after
## the files it needs are in (asked of the loader's threads: FighterWorld.preload_assets), in steps a frame apart; the menu answers
## meanwhile. The view is drawn a few frames before it fades in (its first draw compiles the figure's shaders: that stall is not
## seen). The other three elements' figures, for the setup's cards, come after it (_prebuild_tick).
func _build_figure() -> void:
	for i in 2:
		await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	while is_inside_tree() and not FighterWorld.assets_ready() and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame
	if not is_inside_tree() or _fw == null:
		return
	var el := MatchSetup.element
	_fw.ensure_slowly(el)
	while is_inside_tree() and _fw != null and not _fw.figure_ready(el):
		await get_tree().process_frame
	if not is_inside_tree() or _fw == null:
		return
	_swap_figure(MatchSetup.element)
	await _fade_in_figure()


## The lobby figure's view is drawn for a few frames at no opacity, then fades in.
func _fade_in_figure() -> void:
	for i in 4:
		await get_tree().process_frame
	if not is_inside_tree() or _fw == null:
		return
	var tw := create_tween()
	tw.tween_property(_fighter, "modulate:a", 1.0, 0.45)
	_prebuild_at = Time.get_ticks_msec() + 4500


## The other figures built while the lobby is read: one at a time, in steps of a frame (about 80 ms in all, 15 to 40 ms a frame), only
## once the menu has been left alone for PREBUILD_IDLE_MS, and not while a screen is up over the lobby (the setup builds what it lacks
## itself, a card a few frames after the last).
func _prebuild_tick() -> void:
	if _fw == null or _prebuild_at == 0 or _panel_scroll.visible:
		return
	var now := Time.get_ticks_msec()
	if now < _prebuild_at or now - _last_input_ms < PREBUILD_IDLE_MS:
		return
	if _fw.building():
		return
	for el: String in Bending.ELEMENTS:
		if not _fw.figure_ready(el):
			_fw.ensure_slowly(el)
			_prebuild_at = now + 500
			return
	_prebuild_at = 0


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() < 1.0:
			return
	elif not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	_last_input_ms = Time.get_ticks_msec()


## The lobby view's size: the window's, in 16 : 9, between 1280 and 1920 wide (a smaller window draws no more than it shows).
func _lobby_px() -> Vector2i:
	var w := clampi(ceili(BroadcastUI.view_size(self).x), 1280, 1920)
	return Vector2i(w, roundi(float(w) * 9.0 / 16.0))


func _swap_figure(el: String) -> void:
	if _fw == null:
		return
	if is_instance_valid(_fview):
		_fview.queue_free()
	_fview = _fw.view(el, "lobby", _lobby_px())
	_fw.face(el, "lobby")
	_fview.name = "LobbyView"
	add_child(_fview)
	_fighter.texture = _fview.get_texture()
	_fview_el = el


## A one-line note under the rundown, gone after a few seconds.
func _note(text: String) -> void:
	_note_label.text = text
	_note_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_note_label, "modulate:a", 0.0, 0.8)


## The rundown: the sections (PLAY, FIGHTER) with their rows, then the small row of the foot. Built again (a save written, the
## element changed) from the kept setup.
func _build_items() -> void:
	for c in _items.get_children():
		_items.remove_child(c)
		c.queue_free()
	MatchSetup.load()                     # (the last setup: the panel starts from it, Quick match plays it)
	var el := MatchSetup.element
	_items.add_child(_section("PLAY"))
	var tb := BroadcastUI.row("01", MatchSetup.sport(), MatchSetup.menu_line(), el, {"name": "Sport"})
	tb.pressed.connect(_open_match)
	_items.add_child(tb)
	var start := BroadcastUI.row("02", "Start here", "learn at your own pace, or play an easy match", el, {"name": "StartHere"})
	start.pressed.connect(_offer_basics)
	_items.add_child(start)
	var qm := BroadcastUI.row("03", "Quick match", MatchSetup.quick_line(), el, {"name": "QuickMatch"})
	qm.pressed.connect(_quick_match)
	_items.add_child(qm)
	var pr := BroadcastUI.row("04", "Practice", _practice_line(), el, {"name": "Practice"})
	pr.pressed.connect(_open_practice)
	_items.add_child(pr)
	var ol := BroadcastUI.row("05", "Play online", "host a 1 v 1, or join a friend's by address", el, {"name": "Online"})
	ol.pressed.connect(_open_online)
	_items.add_child(ol)
	_items.add_child(BroadcastUI.gap(0, 8))         # (8, and 10 below: Play online's row fits over the caption at 1280 x 720)
	_items.add_child(_section("FIGHTER"))
	var ct := BroadcastUI.row("06", "Class & talents", _advancement_line(el), el, {"name": "ClassTalents", "badge": "NEW"})
	ct.pressed.connect(_open_advancement)
	_items.add_child(ct)
	if not OS.has_feature("public"):            # (the public web build packs no creator: the default looks)
		var lk := BroadcastUI.row("07", "Your look", "the character creator: face, build and dress", el, {"name": "YourLook"})
		lk.pressed.connect(_open_look)
		_items.add_child(lk)
	_items.add_child(BroadcastUI.gap(0, 10))
	_util = HBoxContainer.new()
	_util.name = "Util"
	_util.add_theme_constant_override("separation", 26)
	_items.add_child(_util)
	var st := BroadcastUI.util("08", "Settings")
	st.pressed.connect(_open_settings)
	_util.add_child(st)
	var cr := BroadcastUI.util("09", "Credits")
	cr.pressed.connect(_open_credits)
	_util.add_child(cr)
	if not OS.has_feature("web"):               # (a browser tab is closed by the browser)
		var q := BroadcastUI.util("10", "Quit")
		q.pressed.connect(func() -> void: get_tree().quit())
		_util.add_child(q)
	_chain_focus()
	_lobby_el = el


## A section's heading in the rundown: its word in the accent, a hairline after it.
func _section(text: String) -> Control:
	var c := Control.new()
	c.name = "Section_" + text.capitalize()
	c.custom_minimum_size = Vector2(560, 32)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	BroadcastUI.section(c, Vector2(0, 2), text, 540.0)
	return c


## The class row's line under it when it is chosen: the class and its loadout, from the advancement window's store.
func _advancement_line(el: String) -> String:
	var store := _script_of(ADVANCEMENT_STORE)
	if store != null:
		var l := String(store.call(&"menu_line", el))
		if l != "":
			return l
	return "your element's class and your ten talent points"


## The class and talents row (and the match setup's small link): the Character Advancement window over the menu, for the element
## the lobby shows (the character's once it is chosen). `from` is the control that asked: the focus goes back to it as the window
## closes. Its "Your look" tab opens the creator (the window closes first). A preview: nothing in play changes by it yet.
func _open_advancement(from: Control = null) -> void:
	_adv_from = from.name if from != null else &"ClassTalents"
	var w := AdvancementWindow.open(self, MatchSetup.element)
	if not w.closed.is_connected(_after_advancement):
		w.closed.connect(_after_advancement)
		w.look_requested.connect(_look_from_window.bind(w))
		w.element_requested.connect(_turn_class.bind(w))
		_window_cover(true)


## The class window's element chips (the owner, 2026-10-16: "we need to be able to change it in your class"): the fighter's element
## changed from the window: the character's own and the match's, as the element step's Enter does (AppearanceStore.set_element,
## MatchSetup.save), the setup's cards or the lobby's figure after it, and the window opened again for that element (one window is
## built for one element: the open one closes, _after_advancement puts the menu back meanwhile, then it opens anew from the same row).
func _turn_class(el: String, w: AdvancementWindow) -> void:
	if not el in Bending.ELEMENTS or not is_instance_valid(w):
		return
	AppearanceStore.set_element(el)
	MatchSetup.element = el
	MatchSetup.save()
	var from_name := _adv_from
	w.close()
	if is_instance_valid(_keys_box):
		_choose_element(el)                      # (the match setup behind it: its cards, keys and style row follow)
	elif _fw != null:
		_swap_figure(el)                         # (the lobby: its figure in the element's dress)
	_reopen_class.call_deferred(from_name)


func _reopen_class(from_name: StringName) -> void:
	if not is_inside_tree():
		return
	var back: Control = null
	if _panel_scroll.visible:
		back = _panel.find_child(String(from_name), true, false) as Control
	if back == null:
		back = _items.find_child(String(from_name), true, false) as Control
	_open_advancement(back)


## The menu behind the advancement window: its screens put away (the window has the whole screen: the lobby's foot or the setup's
## keys would show through its edges) and the deck softened and dimmed; as they were once it has closed.
func _window_cover(on: bool) -> void:
	var parts: Array = [_menu_layout, _art_layout, _fighter]
	if on:
		if not _cover_was.is_empty():
			return
		_cover_was = {"blur": _blur.visible}
		for c: Control in parts:
			_cover_was[c] = c.visible
			c.visible = false
		var m := _blur.material as ShaderMaterial
		if m != null:
			for k: String in ["blur", "dim", "left_extra"]:
				_cover_was["p_" + k] = m.get_shader_parameter(k)
			m.set_shader_parameter("blur", 3.4)
			m.set_shader_parameter("dim", 0.62)
			m.set_shader_parameter("left_extra", 0.0)
		_blur.visible = true
		return
	if _cover_was.is_empty():
		return
	for c: Control in parts:
		if is_instance_valid(c):
			c.visible = bool(_cover_was.get(c, true))
	_blur.visible = bool(_cover_was.get("blur", false))
	var mat := _blur.material as ShaderMaterial
	if mat != null:
		for k: String in ["blur", "dim", "left_extra"]:
			if _cover_was.get("p_" + k) != null:
				mat.set_shader_parameter(k, _cover_was["p_" + k])
	_cover_was = {}


## The window's "Your look" tab: the creator after the window (changes pending: the window asks first, and the creator is not
## opened then; the tab is pressed again once it has closed).
func _look_from_window(w: AdvancementWindow) -> void:
	if w.is_pending():
		w.request_close()
		return
	_look_next = not OS.has_feature("public")   # (no creator in the public web build: the tab only closes the window)
	w.close()


## The window closed: the rundown's lines and the lobby's lower third painted again from the store (at once, or when the match
## setup under it closes), the focus back on what opened it, then the creator if its tab asked.
func _after_advancement() -> void:
	if not is_inside_tree():
		return
	_window_cover(false)
	if _panel_scroll.visible:
		_lobby_dirty = true                     # (the lobby is behind the match setup: its rows are built when that closes)
	else:
		_build_items()
		_paint_lobby()
	var back: Control = null
	if _panel_scroll.visible:
		back = _panel.find_child(String(_adv_from), true, false) as Control
	if back == null:
		back = _items.find_child("ClassTalents", true, false) as Control
	if back != null and not _look_next:
		back.grab_focus.call_deferred()
	if _look_next:
		_look_next = false
		_open_look.call_deferred()


## The rows in a line for the keys: Up and Down through the rundown, the small row's Left and Right (a row beside the small ones'
## Left and Right does nothing: the engine would otherwise carry the focus to whatever lies to its side).
func _chain_focus() -> void:
	var rows: Array = []
	for c in _items.get_children():
		if c is Button:
			rows.append(c)
	var util_btns: Array = _util.get_children()
	if rows.is_empty() or util_btns.is_empty():
		return
	var last_row := rows.back() as Control
	for r: Control in rows:
		r.focus_neighbor_left = r.get_path_to(r)
		r.focus_neighbor_right = r.get_path_to(r)
	for i in util_btns.size():
		var u := util_btns[i] as Control
		u.focus_neighbor_top = u.get_path_to(last_row)
		u.focus_neighbor_bottom = u.get_path_to(u)
		u.focus_neighbor_left = u.get_path_to(util_btns[maxi(i - 1, 0)])
		u.focus_neighbor_right = u.get_path_to(util_btns[mini(i + 1, util_btns.size() - 1)])
	last_row.focus_neighbor_bottom = last_row.get_path_to(util_btns[0])
	(rows[0] as Control).focus_neighbor_top = (rows[0] as Control).get_path_to(rows[0])


func _show(e: Dictionary) -> void:
	if e.is_empty():
		return
	_cap_title.text = MenuPaintings.title_line(e)
	_cap_text.text = String(e.caption)


func _process(delta: float) -> void:
	_t += delta
	if _t >= SHOW_S:
		_t = 0.0
		_show(MenuPaintings.next())
	_prebuild_tick()


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
		return
	# the number keys choose the element in the match setup
	if event is InputEventKey and event.pressed and not event.echo and _panel_scroll.visible and not _element_rows.is_empty():
		var i := int(event.physical_keycode) - KEY_1
		if i >= 0 and i < Bending.ELEMENTS.size():
			var el := String(Bending.ELEMENTS[i])
			_choose_element(el)
			if _panel.find_child("ElementStep", true, false) != null and _element_rows.has(el):
				(_element_rows[el] as Control).grab_focus()       # (the element step: the focus goes with the pick)
			get_viewport().set_input_as_handled()


# --- The menu -----------------------------------------------------------------------------------------------

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
	StoryDirector.incoming = ""       # (no storyline: the Two Fires stages were retired, 2026-10-06; free play)
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


## Play online (RingNet; docs/tidebreak/ring_netcode.md): a 1 v 1 against another player. One machine hosts (its match
## settings are the match's: the joiner's ring takes them), the other joins by the host's address (kept for next time). The
## ring loads at once on both: the host fights a bot until a player joins, then the match begins again with him; the joiner
## reaches the host as his ring loads (the ring's banner says how it goes).
func _open_online() -> void:
	_open_panel()
	_panel.add_child(BroadcastUI.heading("Play online"))
	_panel.add_child(BroadcastUI.label("A 1 v 1 against another player: one of you hosts, the other joins with the host's address. On the same network that is all; over the internet the host forwards port %d on the router." % RingNet.PORT,
			18, BroadcastUI.DIM, true))
	var hb := BroadcastUI.item("Host a match", 26, "your match settings; this machine's address: %s" % RingNet.my_addresses())
	hb.name = "HostOnline"
	hb.pressed.connect(func() -> void: _play_online({"role": "host", "port": RingNet.PORT}))
	_panel.add_child(hb)
	var addr := LineEdit.new()
	addr.name = "OnlineAddress"
	addr.placeholder_text = "the host's address, e.g. 192.168.1.20"
	addr.text = RingNet.last_address()
	addr.custom_minimum_size = Vector2(420, 44)
	addr.add_theme_font_size_override("font_size", 20)
	_panel.add_child(addr)
	var jb := BroadcastUI.item("Join", 26, "the match at the address above")
	jb.name = "JoinOnline"
	jb.pressed.connect(func() -> void:
		var a := addr.text.strip_edges()
		if a == "":
			return
		RingNet.remember_address(a)
		_play_online({"role": "join", "address": a, "port": RingNet.PORT}))
	_panel.add_child(jb)
	hb.grab_focus.call_deferred()


## Into the ring online (`mode`: RingNet.incoming's host or join), as Begin goes: a 1 v 1 match.
func _play_online(mode: Dictionary) -> void:
	RingNet.incoming = mode
	MatchSetup.set_match()
	MatchSetup.format = "1v1"                  # (online is 1 v 1 for now: docs/tidebreak/ring_netcode.md R2 brings the teams)
	_play_match()


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
	box.add_child(BroadcastUI.heading("Practice"))
	var rule := BroadcastUI.label("A dummy at the far end: it stands, it blocks, or it throws at you. No clock, no rounds, no score.  "
			+ KitWords.keyed("In the ring {reset} puts you both back at your ends and {dummy} changes what the dummy does."), 17,
			BroadcastUI.DIM, true)
	rule.custom_minimum_size = Vector2(520, 0)
	box.add_child(rule)
	box.add_child(_gap(6))
	var els: Array = Bending.ELEMENTS
	var mine := BroadcastUI.item("", 22, "-")
	mine.name = "Element"
	var lessons := BroadcastUI.item(RingLessons.word("menu_row"), 30, "-")
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
	var dum := BroadcastUI.item("", 22, "-")
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
	var way := BroadcastUI.item("", 22, "-")
	way.name = "Way"
	var paint_way := func() -> void:
		_set_row(way, "What it does:  %s" % MatchSetup.dummy, "the dummy %s" % MatchSetup.dummy_line(MatchSetup.dummy))
	paint_way.call()
	way.pressed.connect(func() -> void:
		var ws := MatchSetup.dummy_ways()
		MatchSetup.dummy = String(ws[(ws.find(MatchSetup.dummy) + 1) % ws.size()])
		paint_way.call())
	box.add_child(way)
	# (round 3: the % rows, its % and yours, side by side so the panel and its Lessons row are in view at 1600 x 900; R and a
	# fall in the ring put them back to these)
	var pcts: Array = MatchSetup.practice_data().get("pct", [0, 30, 60, 90, 120, 150, 200, -1])
	var pair := HBoxContainer.new()
	pair.name = "Pcts"
	pair.add_theme_constant_override("separation", 10)
	box.add_child(pair)
	var fp := BroadcastUI.item("", 22, "-")
	fp.name = "FoePct"
	fp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var paint_fp := func() -> void:
		_set_row(fp, MatchSetup.pword("row_foe_pct") % MatchSetup.pct_label(MatchSetup.foe_pct), MatchSetup.pword("row_pct_line"))
	paint_fp.call()
	fp.pressed.connect(func() -> void:
		MatchSetup.foe_pct = float(MatchSetup.next_in(pcts, MatchSetup.foe_pct))
		paint_fp.call())
	pair.add_child(fp)
	var mp := BroadcastUI.item("", 22, "-")
	mp.name = "MyPct"
	mp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var paint_mp := func() -> void:
		_set_row(mp, MatchSetup.pword("row_my_pct") % MatchSetup.pct_label(MatchSetup.my_pct), MatchSetup.pword("row_pct_line"))
	paint_mp.call()
	mp.pressed.connect(func() -> void:
		MatchSetup.my_pct = float(MatchSetup.next_in(pcts, MatchSetup.my_pct))
		paint_mp.call())
	pair.add_child(mp)
	# (round 2: the other ways to pick moves under Controls, not here)
	box.add_child(_controls_row(_open_practice))
	box.add_child(_gap(4))
	var begin := BroadcastUI.item("Begin practice", 30)
	begin.name = "Begin"
	begin.pressed.connect(func() -> void:
		RingMode.lessons_asked = false
		MatchSetup.set_practice()
		_play_match())
	box.add_child(begin)
	# (the lessons: the same practice, its dummy the element's lesson dummy, the cards over it)
	var rule2 := BroadcastUI.label(RingLessons.word("panel_line"), 15, BroadcastUI.DIM, true)
	rule2.custom_minimum_size = Vector2(520, 0)
	box.add_child(rule2)
	lessons.pressed.connect(func() -> void:
		RingLessons.ask(MatchSetup.element)
		_play_match())
	box.add_child(lessons)
	begin.grab_focus.call_deferred()


# --- The sub-screens ---------------------------------------------------------------------------------------

## A screen opened over the lobby: the rows of `_panel` cleared, the lobby put back behind it (the fighter, the lower third and
## the bug away, the deck softened); at the right in a plate, or over the whole screen (`full`: the match setup).
func _open_panel(full := false) -> void:
	for c in _panel.get_children():
		_panel.remove_child(c)
		c.queue_free()
	var fo := get_viewport().gui_get_focus_owner()
	if fo != null and _items.is_ancestor_of(fo):
		_opened_from = fo
	_return_to = Callable()
	_element_rows = {}
	_keys_box = null
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if full else Control.SIZE_FILL
	_panel_scroll.visible = true
	_panel_scroll.scroll_vertical = 0
	_set_panel_mode(full)
	_lobby_cover(true, full)


## The lobby behind a screen: softened and dimmed, its fighter and plates away (`on`), or as it was.
func _lobby_cover(on: bool, full: bool) -> void:
	_blur.visible = on
	if on:
		var m := _blur.material as ShaderMaterial
		if m != null:
			m.set_shader_parameter("blur", 3.4 if full else 2.8)
			m.set_shader_parameter("dim", 0.62 if full else 0.5)
			m.set_shader_parameter("left_extra", 0.0 if full else 0.3)
	_fighter.visible = not on
	_art_layout.visible = not on
	_right_lobby.visible = not on
	_lobby.visible = not (on and full)


func _close_panel() -> void:
	_return_to = Callable()
	_drop_card_views()
	_panel_scroll.visible = false
	_panel_plate.visible = false
	_lobby_cover(false, false)
	if MatchSetup.element != _lobby_el or _lobby_dirty:
		_lobby_dirty = false
		_build_items()                          # (the rows in the new element's colour, or with what a window changed)
	_paint_lobby()
	if _fw != null and _fview_el == MatchSetup.element:
		_fw.face(MatchSetup.element, "lobby")
	var back: Node = _items.find_child(String(_opened_from.name), true, false) if is_instance_valid(_opened_from) else null
	if back is Button and (back as Button).is_visible_in_tree():
		(back as Button).grab_focus.call_deferred()
	else:
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


# --- Tidebreak: the match's setup ---------------------------------------------------------------------------

## The match's setup (MatchSetup; its words from data/ring/elements.json), a screen of its own over the deck, the same words
## and options as ever: at the left your element as four fighter cards (the saved look in each element's ring dress, the
## element's name, the name its competitors go by and its number key; the focused or chosen one's style, passive and five keys
## under them: KitWords), at the right the match: Opponent (an element, or Any: drawn by lot), Difficulty, Rules (Lives or
## Zones), Games (one or best of 3, under the lives; Rounds under the zones), Light, Controls and Begin. A choice is made by
## pressing its chip; the number keys 1 to 4 pick the element. The rule line over them is the rule set's own
## (MatchSetup.sport_line). The first press in a run with no look saved yet opens the character creator first, then this screen.
func _open_match() -> void:
	if not _look_offered and not OS.has_feature("public") and PlayerAppearance.offer_creator(offer_check_run):
		_look_offered = true
		_close_panel()
		# (the character first, then its element: the step after an Accept; Back keeps no look and the setup opens at once)
		var c := _make_creator(true)
		c.connect(&"closed", func(ok: bool) -> void:
			AppearanceStore.mark_offered()          # (made once, however it closed: Back keeps no look, the offer does not come back)
			_after_creator.call_deferred(ok, _open_match))
		return
	_open_panel(true)
	var box := Control.new()
	box.name = "Match"
	box.custom_minimum_size = BroadcastUI.DESIGN
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	# the head: the sport, the screen's name and the rule in a line
	var hd := BroadcastUI.group(box, Vector2(0, 0), Vector2(84, 34), Vector2(1440, 76))
	BroadcastUI.put(hd, BroadcastUI.tag(MatchSetup.sport(), 20, BroadcastUI.INK, BroadcastUI.TEAL, 4), Rect2(0, 16, 0, 0))
	var head_title := BroadcastUI.lab("MATCH SETUP", BroadcastUI.head(true, 2), 60, BroadcastUI.WHITE)
	head_title.name = "SetupTitle"
	BroadcastUI.put(hd, head_title, Rect2(176, 0, 380, 66))
	var rule := BroadcastUI.para(MatchSetup.sport_line(), BroadcastUI.body(true), 18, BroadcastUI.DIM, 560.0)
	rule.name = "SportLine"
	BroadcastUI.put(hd, rule, Rect2(590, 10, 560, 60))
	# your class and talents from here too (the same window as the lobby's row 05; its small link at the head's right)
	var class_link := BroadcastUI.Chip.new().setup("Class & talents", 20, BroadcastUI.TEAL, "next")
	class_link.name = "ClassLink"
	class_link.pressed.connect(_open_advancement.bind(class_link))
	BroadcastUI.put(hd, class_link, Rect2(1196, 18, 0, 0))
	# your element: the four fighters as cards
	var cards := BroadcastUI.group(box, Vector2(0, 0), Vector2(84, 128), Vector2(930, 700))
	cards.name = "Cards"
	BroadcastUI.section(cards, Vector2(0, 0), "YOUR ELEMENT", 900.0)
	# (the element step left by Esc ("later") never came back: the setup offers it for as long as the character has no element)
	if AppearanceStore.element() == "":
		var pick := BroadcastUI.Chip.new().setup("Choose your element", 18, BroadcastUI.TEAL, "diamond")
		pick.name = "ElementLink"
		pick.pressed.connect(func() -> void: _open_element_step(_open_match))
		BroadcastUI.put(cards, pick, Rect2(640, -8, 0, 0))
	var four := Control.new()
	four.name = "Elements"
	four.mouse_filter = Control.MOUSE_FILTER_IGNORE
	BroadcastUI.put(cards, four, Rect2(0, 36, 900, 452))
	for i in Bending.ELEMENTS.size():
		var el: String = Bending.ELEMENTS[i]
		var card := _card(el, i + 1)
		card.position = Vector2(float(i) * 228.0, 0.0)
		card.pressed.connect(_choose_element.bind(el))
		card.focus_entered.connect(_show_keys.bind(el))
		card.focus_exited.connect(_show_keys.bind(""))
		_element_rows[el] = card
		four.add_child(card)
	# the focused or chosen element's style, passive and keys under them
	_keys_box = VBoxContainer.new()
	_keys_box.name = "Keys"
	(_keys_box as VBoxContainer).add_theme_constant_override("separation", 6)
	BroadcastUI.put(cards, _keys_box, Rect2(0, 502, 920, 300))    # (the style row too, 2026-10-16: the cards group is 700 tall)
	# the match at the right
	var mc := BroadcastUI.group(box, Vector2(1, 0), Vector2(-574, 128), Vector2(494, 696))
	mc.name = "MatchCard"
	var back := BroadcastUI.plate(mc, Rect2(0, 0, 494, 696), Color(BroadcastUI.NAVY1, 0.94), 0.0)
	back.name = "CardBack"
	BroadcastUI.rect(mc, Rect2(0, 0, 494, 4), BroadcastUI.TEAL)
	BroadcastUI.put(mc, BroadcastUI.lab("THE MATCH", BroadcastUI.head(false, 5, 1), 19, BroadcastUI.TEAL), Rect2(24, 14, 300, 24))
	# the format in the head: 1 v 1, 2 v 2, 4 v 4 (the owner, 2026-10-10: team modes on decks big enough; a row would push the
	# card past a 720-high window), its line on each chip's tooltip
	var fmt_opts: Array = []
	for f: String in MatchSetup.FORMATS:
		fmt_opts.append({"text": String(((MatchSetup.data().get("formats", {}) as Dictionary).get(f, {}) as Dictionary).get("label", f)),
				"value": f, "name": "Format_" + f})
	var frm := BroadcastUI.segments(fmt_opts, maxi(MatchSetup.FORMATS.find(MatchSetup.format), 0), 20, 11.0)
	frm.name = "Format"
	for i in frm.chips.size():
		(frm.chips[i] as Control).tooltip_text = MatchSetup.menu_word("format_line_" + String(MatchSetup.FORMATS[i]))
	frm.picked.connect(func(i: int) -> void:
		MatchSetup.format = String(MatchSetup.FORMATS[i])
		_paint_setup())
	BroadcastUI.put(mc, frm, Rect2(196, 6, 278, 36))
	# you against them
	var vs := Control.new()
	vs.name = "Versus"
	vs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	BroadcastUI.put(mc, vs, Rect2(0, 42, 494, 52))
	BroadcastUI.put(mc, BroadcastUI.lab("VS", BroadcastUI.head(true, 2), 38, BroadcastUI.WHITE, HORIZONTAL_ALIGNMENT_CENTER), Rect2(222, 42, 52, 52))
	var y := 100.0
	# the opponent: the four elements and Any
	var foes: Array = Bending.ELEMENTS + [MatchSetup.ANY]
	var foe_opts: Array = []
	for e: String in foes:
		foe_opts.append({"text": MatchSetup.label(e), "color": BroadcastUI.plate_c(e) if e != MatchSetup.ANY else BroadcastUI.ec(MatchSetup.ANY),
				"glyph": e, "value": e, "name": "Opponent_" + e})
	var opp := _setting(mc, "Opponent", y, "OPPONENT", foe_opts, foes.find(MatchSetup.foe()), 18, 8.0)
	opp.picked.connect(func(i: int) -> void:
		MatchSetup.foes = [String(foes[i])]
		_paint_setup())
	y += ROW_H
	var dif := _setting(mc, "Difficulty", y, "DIFFICULTY", _words(MatchSetup.DIFFICULTIES), MatchSetup.DIFFICULTIES.find(MatchSetup.difficulty), 20)
	dif.picked.connect(func(i: int) -> void:
		MatchSetup.difficulty = String(MatchSetup.DIFFICULTIES[i])
		_paint_setup())
	y += ROW_H
	var rul := _setting(mc, "Rules", y, "RULES", [MatchSetup.rule_label("stock"), MatchSetup.rule_label("zones")],
			MatchSetup.RULE_SETS.find(MatchSetup.rule_set()), 20)
	rul.picked.connect(func(i: int) -> void:
		MatchSetup.rules_choice = String(MatchSetup.RULE_SETS[i])
		_paint_setup())
	y += ROW_H
	# (the rounds are the zones' only: the % ring with lives plays one game or best of 3, the Games row in their place)
	var rnd_opts: Array = []
	for n: int in MatchSetup.ROUNDS:
		rnd_opts.append(MatchSetup.rounds_label(n))
	var rnd := _setting(mc, "Rounds", y, "ROUNDS", rnd_opts, MatchSetup.ROUNDS.find(MatchSetup.rounds_to_win), 20)
	rnd.picked.connect(func(i: int) -> void:
		MatchSetup.rounds_to_win = int(MatchSetup.ROUNDS[i])
		_paint_setup())
	var gms := _setting(mc, "Games", y, "GAMES", [MatchSetup.games_label(1), MatchSetup.games_label(3)], MatchSetup.GAMES.find(MatchSetup.games()), 20)
	gms.picked.connect(func(i: int) -> void:
		MatchSetup.games_n = int(MatchSetup.GAMES[i])
		_paint_setup())
	y += ROW_H
	var lit := _setting(mc, "Light", y, "LIGHT", _words(MatchSetup.LIGHTS), MatchSetup.LIGHTS.find(MatchSetup.light), 20)
	lit.picked.connect(func(i: int) -> void:
		MatchSetup.light = String(MatchSetup.LIGHTS[i])
		_paint_setup())
	# the arena beside the light (the owner, 2026-10-16: the Blender-built ovals, Ruin and Crater; a row of its own would push
	# the card past a 720-high window): its chips at the row's right half, its line with the light's
	var arenas: Array = RingArena.arena_names()
	var ar_opts: Array = []
	for a: String in arenas:
		ar_opts.append({"text": MatchSetup.arena_label(a), "value": a, "name": "Arena_" + a})
	var lrow := mc.find_child("LightRow", false, false) as Control
	var ar_title := BroadcastUI.lab("ARENA", BroadcastUI.head(false, 4, 1), 16, BroadcastUI.FAINT)
	ar_title.name = "RowTitle2"
	BroadcastUI.put(lrow, ar_title, Rect2(262, 4, 200, 19))
	var arn := BroadcastUI.segments(ar_opts, maxi(arenas.find(MatchSetup.arena), 0), 20, 11.0)
	arn.name = "Arena"
	BroadcastUI.put(lrow, arn, Rect2(262, 23, 208, 36))
	arn.picked.connect(func(i: int) -> void:
		MatchSetup.arena = String(arenas[i])
		_paint_setup())
	y += ROW_H
	# Controls: the buttons, the rules and the other ways to pick moves
	BroadcastUI.rect(mc, Rect2(24, y, 446, 1), Color(BroadcastUI.LINE, 0.9)).name = "ControlsRule"
	var ctl := _controls_row(_open_match)
	ctl.custom_minimum_size = Vector2(446, 78)
	BroadcastUI.put(mc, ctl, Rect2(10, y + 4, 446, 78))
	y += 82.0
	# Begin
	var begin := _cta(mc, "Begin", Rect2(16, y, 462, 66), 330.0, func() -> void:
		MatchSetup.set_match()                # (a match, after a practice or a Quick match)
		_play_match())
	# the keys at the foot
	var kh := BroadcastUI.group(box, Vector2(0, 1), Vector2(84, -58), Vector2(700, 36))
	var hh := BroadcastUI.hbox(26)
	hh.add_child(BroadcastUI.key_hint("ENTER", "Begin"))
	hh.add_child(BroadcastUI.key_hint("ESC", "Back"))
	hh.add_child(BroadcastUI.key_hint("1 - 4", "Element"))
	BroadcastUI.put(kh, hh, Rect2(0, 0, 700, 36))
	mc.set_meta(&"on_retype", _lay_match)
	_paint_setup()
	_mark_elements()
	_show_keys("")
	_attach_card_views()
	_link_setup()
	begin.grab_focus.call_deferred()


## `list`'s words for the chips ("easy", "noon": as the data names them).
static func _words(list: Array) -> Array:
	var out: Array = []
	for w in list:
		out.append(String(w))
	return out


## One setting of the match card: a rule, its name, its chips and its line under them. Returns the chips (Segments, named `nm`).
## The parts are placed by _lay_match (the type is raised in a small window, the line may wrap).
func _setting(mc: Control, nm: String, y: float, title: String, opts: Array, chosen: int, px: int, pad_x := 14.0) -> BroadcastUI.Segments:
	var g := Control.new()
	g.name = nm + "Row"
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	BroadcastUI.put(mc, g, Rect2(0, y, 494, ROW_H))
	BroadcastUI.rect(g, Rect2(24, 0, 446, 1), Color(BroadcastUI.LINE, 0.9)).name = "Rule"
	var head := BroadcastUI.lab(title, BroadcastUI.head(false, 4, 1), 16, BroadcastUI.FAINT)
	head.name = "RowTitle"
	BroadcastUI.put(g, head, Rect2(24, 4, 200, 19))
	var seg := BroadcastUI.segments(opts, maxi(chosen, 0), px, pad_x)
	seg.name = nm
	BroadcastUI.put(g, seg, Rect2(26, 23, 444, 36))
	var line := BroadcastUI.lab("", BroadcastUI.body(), 16, BroadcastUI.DIM)
	line.name = "Line"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART     # (a long line wraps in a small window: _lay_match makes the room)
	line.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	BroadcastUI.put(g, line, Rect2(26, 62, 446, 20))
	return seg


## A fighter's card: the saved look in the element's ring dress cut out over its colour, the element's name (Text), the name its
## competitors go by (Sub) and its number key. Pressed, it chooses the element; the chosen one is lit and outlined in the accent
## and says YOU, the others are dimmed. The figure comes through a view of FighterWorld (a placeholder mark until it is there).
func _card(el: String, n: int) -> Button:
	var pc := BroadcastUI.plate_c(el)
	var b := Button.new()
	b.name = "Element_" + el
	b.set_meta(&"element", el)
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	b.custom_minimum_size = Vector2(214, 452)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(st, empty)
	var rest := Control.new()
	rest.name = "Rest"
	rest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(rest)
	rest.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	BroadcastUI.rect(rest, Rect2(0, 0, 214, 452), Color(BroadcastUI.NAVY2, 0.92))
	BroadcastUI.grad(rest, [[0.0, Color(pc, 0.30)], [0.6, Color(pc, 0.0)]], Vector2(0.5, 0), Vector2(0.5, 1))
	BroadcastUI.rect(rest, Rect2(0, 0, 214, 5), pc)
	var lit := Control.new()
	lit.name = "Lit"
	lit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lit.visible = false
	b.add_child(lit)
	lit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	BroadcastUI.grad(lit, [[0.0, pc.lightened(0.1)], [1.0, pc.darkened(0.55)]], Vector2(0.5, 0), Vector2(0.5, 1))
	BroadcastUI.stripes(lit, Rect2(0, 0, 214, 270), Color(Color.WHITE, 0.12), 12, 3, 1.0)
	var num := BroadcastUI.lab(str(n), BroadcastUI.head(true), 160, Color(pc, 0.07), HORIZONTAL_ALIGNMENT_RIGHT)
	num.name = "Number"
	BroadcastUI.put(b, num, Rect2(0, -18, 204, 180))
	var holder := Control.new()
	holder.name = "Portrait"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	BroadcastUI.put(b, holder, Rect2(0, 0, 214, 452))
	var mark := BroadcastUI.glyph(el, Color(pc, 0.35), 110.0, BroadcastUI.NAVY2)
	mark.name = "Placeholder"
	BroadcastUI.put(holder, mark, Rect2(52, 150, 110, 110))
	# the name at the foot
	BroadcastUI.grad(b, [[0.0, Color(BroadcastUI.NAVY0, 0.0)], [0.55, Color(BroadcastUI.NAVY0, 0.85)], [1.0, Color(BroadcastUI.NAVY0, 0.96)]],
			Vector2(0.5, 0), Vector2(0.5, 1), Rect2(0, 0.62, 1, 0.38))
	var nm := BroadcastUI.hbox(8)
	nm.add_child(BroadcastUI.glyph(el, pc, 28.0, BroadcastUI.NAVY0))
	var tl := BroadcastUI.caps(MatchSetup.label(el), BroadcastUI.head(true, 2), 44, BroadcastUI.WHITE)
	tl.name = "Text"
	nm.add_child(tl)
	BroadcastUI.put(b, nm, Rect2(14, 360, 196, 52))
	var sb := BroadcastUI.caps(MatchSetup.competitor(el), BroadcastUI.head(false, 5, 1), 19, pc)
	sb.name = "Sub"
	if el == "air":
		sb.add_theme_color_override("font_color", Color("9fd4ee"))
	BroadcastUI.put(b, sb, Rect2(16, 410, 150, 26))
	var cap := BroadcastUI.key_cap(str(n), 16)
	BroadcastUI.put(b, cap, Rect2(176, 410, 0, 0))
	var frame := Panel.new()
	frame.name = "Frame"
	var fsb := StyleBoxFlat.new()
	fsb.draw_center = false
	fsb.set_border_width_all(4)
	fsb.border_color = BroadcastUI.TEAL
	frame.add_theme_stylebox_override("panel", fsb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	BroadcastUI.put(b, frame, Rect2(0, 0, 214, 452))
	var you := BroadcastUI.tag("YOU", 18, BroadcastUI.INK, BroadcastUI.TEAL, 3)
	you.name = "YouTag"
	you.visible = false
	BroadcastUI.put(b, you, Rect2(10, 14, 0, 0))
	b.focus_entered.connect(_paint_card.bind(b))
	b.focus_exited.connect(_paint_card.bind(b))
	return b


## A card as its state is now: lit when it is the chosen element, outlined in white while focused.
func _paint_card(b: Button) -> void:
	var el := String(b.get_meta(&"element"))
	var chosen := el == MatchSetup.element
	(b.find_child("Lit", false, false) as Control).visible = chosen
	(b.find_child("Rest", false, false) as Control).visible = not chosen
	(b.find_child("YouTag", false, false) as Control).visible = chosen
	var frame := b.find_child("Frame", false, false) as Panel
	var fsb := frame.get_theme_stylebox("panel") as StyleBoxFlat
	frame.visible = chosen or b.has_focus()
	fsb.border_color = BroadcastUI.WHITE if b.has_focus() else BroadcastUI.TEAL
	(b.find_child("Number", false, false) as Label).add_theme_color_override("font_color",
			Color(BroadcastUI.INK, 0.12) if chosen else Color(BroadcastUI.plate_c(el), 0.07))
	var portrait := b.find_child("Portrait", false, false)
	if portrait != null:
		for c in portrait.get_children():
			if c is TextureRect:
				(c as TextureRect).modulate = Color.WHITE if chosen or b.has_focus() else Color(0.62, 0.66, 0.76)
	b.set_meta(&"chosen", chosen)


## The four cards' figures from FighterWorld (the ones it has; the rest are built in steps, each a few frames after the last: a build
## is about 80 ms, 15 to 40 ms a frame).
func _attach_card_views() -> void:
	if _fw == null:
		return
	var k := 0
	for el: String in Bending.ELEMENTS:
		if _fw.figure_ready(el):
			_attach_card(el)
		else:
			k += 1
			_attach_card_later.call_deferred(el, 3 + 4 * k)


func _attach_card_later(el: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
		if not is_inside_tree() or _fw == null:
			return
	if not _element_rows.has(el) or not is_instance_valid(_element_rows[el]):
		return
	_fw.ensure_slowly(el)                       # (in steps: a frame about 15 to 40 ms, not 80)
	while not _fw.figure_ready(el):
		await get_tree().process_frame
		if not is_inside_tree() or _fw == null or not _element_rows.has(el) or not is_instance_valid(_element_rows[el]):
			return
	_attach_card(el)


## The card views dropped as the setup goes (their render targets, about 15 MB each, stay allocated as long as the card does).
func _drop_card_views() -> void:
	for el: String in _element_rows:
		var b := _element_rows[el] as Control
		if is_instance_valid(b):
			for n: String in ["CardViewport", "CardView"]:
				var c := b.find_child(n, true, false)
				if c != null:
					c.queue_free()
			var ph := b.find_child("Placeholder", true, false)
			if ph != null:
				ph.visible = true


func _attach_card(el: String) -> void:
	var b := _element_rows.get(el) as Button
	if b == null or not is_instance_valid(b) or _fw == null:
		return
	var holder := b.find_child("Portrait", false, false)
	if holder == null or holder.find_child("CardView", false, false) != null:
		return
	var v := _fw.view(el, "card", Vector2i(428, 904))
	_fw.face(el, "card")
	v.name = "CardViewport"
	b.add_child(v)
	var tr := TextureRect.new()
	tr.name = "CardView"
	tr.texture = v.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tr)
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ph := holder.find_child("Placeholder", false, false)
	if ph != null:
		ph.visible = false
	_paint_card(b)


## The element chosen (its card lit, its keys shown, the match card's colours with it).
func _choose_element(el: String) -> void:
	MatchSetup.element = el
	_mark_elements()
	_show_keys(el)
	_paint_setup()
	_paint_step()


## The cards as the choice has them (the chosen one lit, with YOU on it).
func _mark_elements() -> void:
	for el: String in _element_rows:
		var b := _element_rows[el] as Button
		if is_instance_valid(b):
			_paint_card(b)


## The match card as the setup has it now: the chosen chips and their lines, you against them, the rule line over it all,
## Games or Rounds by the rule set, Begin in your colour. Called as a choice is made.
func _paint_setup() -> void:
	var mc := _panel.find_child("MatchCard", true, false)
	if mc == null:
		return
	var foes: Array = Bending.ELEMENTS + [MatchSetup.ANY]
	var f := MatchSetup.foe()
	var frm := mc.find_child("Format", true, false) as BroadcastUI.Segments
	if frm != null:
		frm.set_chosen(maxi(MatchSetup.FORMATS.find(MatchSetup.format), 0))
	(mc.find_child("Opponent", true, false) as BroadcastUI.Segments).set_chosen(maxi(foes.find(f), 0))
	# (the nickname and the style's head: "Gale  ·  movement and pushing"; the whole style is under the cards for your own element)
	_say(mc, "OpponentRow", MatchSetup.competitor(f) + "  ·  " + MatchSetup.style(f).get_slice(":", 0) if f != MatchSetup.ANY else MatchSetup.style(f))
	(mc.find_child("Difficulty", true, false) as BroadcastUI.Segments).set_chosen(maxi(MatchSetup.DIFFICULTIES.find(MatchSetup.difficulty), 0))
	_say(mc, "DifficultyRow", MatchSetup.difficulty_line(MatchSetup.difficulty))
	var rs := MatchSetup.rule_set()
	(mc.find_child("Rules", true, false) as BroadcastUI.Segments).set_chosen(maxi(MatchSetup.RULE_SETS.find(rs), 0))
	var rk := "rules_line_" + rs
	if MatchSetup.team_size() > 1 and MatchSetup.menu_word(rk + "_team") != rk + "_team":
		rk += "_team"                     # (a team format: 2 lives each)
	_say(mc, "RulesRow", MatchSetup.menu_word(rk) if MatchSetup.menu_word(rk) != rk else MatchSetup.menu_word("rules_line"))
	var stock := rs == "stock"
	(mc.find_child("RoundsRow", true, false) as Control).visible = not stock
	(mc.find_child("GamesRow", true, false) as Control).visible = stock
	(mc.find_child("Rounds", true, false) as BroadcastUI.Segments).set_chosen(maxi(MatchSetup.ROUNDS.find(MatchSetup.rounds_to_win), 0))
	_say(mc, "RoundsRow", "the first to %d round win%s takes the match" % [MatchSetup.rounds_to_win, "" if MatchSetup.rounds_to_win == 1 else "s"])
	(mc.find_child("Games", true, false) as BroadcastUI.Segments).set_chosen(maxi(MatchSetup.GAMES.find(MatchSetup.games()), 0))
	_say(mc, "GamesRow", MatchSetup.menu_word("games_line_menu"))
	(mc.find_child("Light", true, false) as BroadcastUI.Segments).set_chosen(maxi(MatchSetup.LIGHTS.find(MatchSetup.light), 0))
	var arn := mc.find_child("Arena", true, false) as BroadcastUI.Segments
	if arn != null:
		arn.set_chosen(maxi(RingArena.arena_names().find(MatchSetup.arena), 0))
	_say(mc, "LightRow", MatchSetup.light_line(MatchSetup.light) + ("  ·  " + MatchSetup.arena_line(MatchSetup.arena) if MatchSetup.arena != "classic" else ""))
	var sl := _panel.find_child("SportLine", true, false) as Label
	if sl != null:
		sl.text = MatchSetup.sport_line()
	_lay_match()
	_link_setup()
	# you against them
	var vs := mc.find_child("Versus", false, false) as Control
	for c in vs.get_children():
		vs.remove_child(c)
		c.queue_free()
	_versus_plate(vs, Rect2(24, 0, 196, 52), MatchSetup.element)
	_versus_plate(vs, Rect2(276, 0, 196, 52), f)
	_paint_begin()


## The match card's rows laid one under another, each from the real height of its parts: its name, its chips, its line (which wraps
## to as many lines as the words need: the data's words, and in a small window the type is raised), then a breath before the rule
## of the row under it. Controls and Begin follow, and the card's plate grows to hold them.
func _lay_match() -> void:
	var mc := _panel.find_child("MatchCard", true, false) as Control
	if mc == null or mc.find_child("Begin", false, false) == null:
		return
	# the rows at their least breath first; what the window has to spare under the card then opens them toward their full breath
	# (a 1280 x 720 window, its type raised, has little to spare: the card must still end inside it)
	var tight := _lay_rows(mc, 0.0)
	var room := (_menu_layout.size.y if is_instance_valid(_menu_layout) else BroadcastUI.DESIGN.y) - mc.offset_top - CARD_FOOT
	var full := _lay_rows(mc, 1.0)
	var k := clampf((room - tight) / maxf(full - tight, 0.01), 0.0, 1.0)
	_lay_rows(mc, k)
	# the offer of the element step under the rule line at the head (in a small window the line wraps to a third line, which sat on it)
	var link := _panel.find_child("ElementLink", true, false) as Control
	var sl := _panel.find_child("SportLine", true, false) as Label
	if link != null and sl != null:
		var sl_end := (sl.get_parent() as Control).position.y + sl.position.y + sl.get_minimum_size().y
		var cards_top := 36.0 - maxf(link.size.y, link.get_combined_minimum_size().y) - 2.0      # (the cards start 36 under the group's top)
		link.position.y = maxf(-8.0, minf(sl_end + 8.0 - (link.get_parent() as Control).position.y, cards_top))


## The match card's rows laid with their breath at `k` (0 the least, 1 the full: ROW_TOP / ROW_AIR / BEGIN_AIR); the card's height.
func _lay_rows(mc: Control, k: float) -> float:
	var top := lerpf(ROW_TOP_MIN, ROW_TOP, k)
	var air := lerpf(ROW_AIR_MIN, ROW_AIR, k)
	# (a hairline is at least a pixel on screen: at 1280 x 720 the layout is drawn at 0.8 and a 1 px rule could fall between rows of pixels)
	var hair := maxf(1.0, 1.0 / maxf(BroadcastUI.fit, 0.01))
	var y := 100.0
	for nm: String in ["Opponent", "Difficulty", "Rules", "Rounds", "Games", "Light"]:
		var g := mc.find_child(nm + "Row", false, false) as Control
		if g == null or not g.visible:
			continue
		var ttl := g.find_child("RowTitle", false, false) as Label
		var seg := g.find_child(nm, false, false) as Control
		var ln := g.find_child("Line", false, false) as Label
		(g.find_child("Rule", false, false) as Control).size.y = hair
		var th := ttl.get_minimum_size().y
		ttl.position = Vector2(24.0, top)
		ttl.size = Vector2(200.0, th)
		var sy := top + th
		var sh := 0.0
		for c in (seg as BroadcastUI.Segments).chips:
			sh = maxf(sh, (c as BroadcastUI.Chip).natural_h())
		seg.position = Vector2(26.0, sy)
		seg.size = Vector2(444.0, sh)
		var seg2 := g.find_child("Arena", false, false) as Control if nm == "Light" else null
		if seg2 != null:
			# (a second choice sharing the row, the Light row's Arena: its title and chips at the row's right half)
			var ttl2 := g.find_child("RowTitle2", false, false) as Control
			if ttl2 != null:
				ttl2.position = Vector2(262.0, top)
			seg2.position = Vector2(262.0, sy)
		var ly := sy + sh + 1.0 + k
		ln.size = Vector2(446.0, 10.0)
		var lh := float(ln.get_line_height())
		var lines := maxi(ln.get_line_count(), 1) if ln.text != "" else 1
		ln.position = Vector2(26.0, ly)
		ln.size = Vector2(446.0, lh * lines + 2.0)
		# (the line's last descender a clear breath above the next row's rule)
		var h := maxf(ly + lh * lines + air, ROW_H)
		g.position = Vector2(0.0, y)
		g.size = Vector2(494.0, h)
		y += h
	var rule := mc.find_child("ControlsRule", false, false) as Control
	rule.position.y = y
	rule.size.y = hair
	var ctl := mc.find_child("Controls", false, false) as Control
	ctl.position.y = y + 4.0
	# (Controls as tall as its words are now: a raised type in a small window makes its line taller; Begin a breath under it)
	var ch := 78.0
	var sub := ctl.find_child("Sub", false, false) as Label
	if sub != null:
		ch = maxf(ch, sub.position.y + sub.get_minimum_size().y + 4.0)
	ctl.size.y = ch
	y += 4.0 + ch + lerpf(BEGIN_AIR_MIN, BEGIN_AIR, k)
	(mc.find_child("Begin", false, false) as Control).position.y = y
	var hh := maxf(y + 66.0 + lerpf(12.0, 18.0, k), 696.0)
	mc.offset_bottom = mc.offset_top + hh
	(mc.find_child("CardBack", false, false) as Control).size = Vector2(494.0, hh)
	return hh


func _say(mc: Control, row: String, text: String) -> void:
	var l := mc.find_child(row, true, false).find_child("Line", true, false) as Label
	if l != null:
		l.text = text


## A side of the versus bar: the element's colour, its mark and its name.
func _versus_plate(parent: Control, r: Rect2, el: String) -> void:
	var pc := BroadcastUI.plate_c(el) if el != MatchSetup.ANY else BroadcastUI.ec(MatchSetup.ANY)
	BroadcastUI.plate(parent, r, pc)
	var h := BroadcastUI.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(BroadcastUI.glyph(el, BroadcastUI.INK, 30.0, pc))
	h.add_child(BroadcastUI.caps(MatchSetup.label(el), BroadcastUI.head(false, 2), 32, BroadcastUI.INK))
	BroadcastUI.put(parent, h, r)


## Begin in the colour of your element, outlined in white while it has the focus.
func _paint_begin() -> void:
	_paint_cta("Begin")


## The keys' way through the setup. Left and Right go along a row of chips (the first chip's Left to the chosen card, the last
## chip's Right nowhere), the last card's Right to the first row, Up and Down to the chip of the same place in the next row, then
## Controls, then Begin; the cards' Down is Begin. Linked again as the rows shown change (Games under the lives, Rounds under
## the zones).
func _link_setup() -> void:
	var mc := _panel.find_child("MatchCard", true, false)
	if mc == null or _element_rows.is_empty():
		return
	var chosen := _element_rows.get(MatchSetup.element) as Control
	var begin := mc.find_child("Begin", true, false) as Control
	var ctl := mc.find_child("Controls", false, false) as Control
	var cards: Array = []
	for el: String in Bending.ELEMENTS:
		cards.append(_element_rows[el])
	var rows: Array = []
	for nm: String in ["Format", "Opponent", "Difficulty", "Rules", "Rounds", "Games", "Light"]:
		var sg := mc.find_child(nm, true, false) as BroadcastUI.Segments
		if sg != null and sg.chips.size() > 0 and sg.get_parent().visible:
			rows.append(sg)
	if rows.is_empty() or begin == null:
		return
	# (the class link at the head's right: Up from the Opponent chips, Down back to the chosen one, Left to the chosen card)
	var link := _panel.find_child("ClassLink", true, false) as Control
	if link != null:
		var first := rows[0] as BroadcastUI.Segments
		link.focus_neighbor_bottom = link.get_path_to(first.chip(clampi(first.chosen, 0, first.chips.size() - 1)))
		link.focus_neighbor_left = link.get_path_to(chosen)
		link.focus_neighbor_right = link.get_path_to(link)
		link.focus_neighbor_top = link.get_path_to(link)
	# (the offer of the element step above the cards: Up to it from a card, Down back to the chosen one)
	var pick := _panel.find_child("ElementLink", true, false) as Control
	if pick != null:
		pick.focus_neighbor_top = pick.get_path_to(pick)
		pick.focus_neighbor_left = pick.get_path_to(pick)
		pick.focus_neighbor_right = pick.get_path_to(pick)
		pick.focus_neighbor_bottom = pick.get_path_to(chosen)
	for c: Control in cards:
		c.focus_neighbor_top = c.get_path_to(pick if pick != null else c)
		c.focus_neighbor_bottom = c.get_path_to(begin)
	(cards[0] as Control).focus_neighbor_left = (cards[0] as Control).get_path_to(cards[0])
	(cards.back() as Control).focus_neighbor_right = (cards.back() as Control).get_path_to((rows[0] as BroadcastUI.Segments).chip(0))
	for ri in rows.size():
		var sg := rows[ri] as BroadcastUI.Segments
		var n := sg.chips.size()
		for i in n:
			var c := sg.chip(i)
			c.focus_neighbor_left = c.get_path_to(sg.chip(i - 1) if i > 0 else chosen)
			c.focus_neighbor_right = c.get_path_to(sg.chip(i + 1) if i + 1 < n else c)
			if ri > 0:
				var up := rows[ri - 1] as BroadcastUI.Segments
				c.focus_neighbor_top = c.get_path_to(up.chip(mini(i, up.chips.size() - 1)))
			else:
				c.focus_neighbor_top = c.get_path_to(link if link != null else c)
			if ri + 1 < rows.size():
				var dn := rows[ri + 1] as BroadcastUI.Segments
				c.focus_neighbor_bottom = c.get_path_to(dn.chip(mini(i, dn.chips.size() - 1)))
			else:
				c.focus_neighbor_bottom = c.get_path_to(ctl if ctl != null else begin)
	if ctl != null:
		var lastr := rows.back() as BroadcastUI.Segments
		ctl.focus_neighbor_top = ctl.get_path_to(lastr.chip(clampi(lastr.chosen, 0, lastr.chips.size() - 1)))
		ctl.focus_neighbor_bottom = ctl.get_path_to(begin)
		ctl.focus_neighbor_left = ctl.get_path_to(chosen)
		ctl.focus_neighbor_right = ctl.get_path_to(ctl)
	begin.focus_neighbor_top = begin.get_path_to(ctl if ctl != null else (rows.back() as BroadcastUI.Segments).chip(0))
	begin.focus_neighbor_bottom = begin.get_path_to(begin)
	begin.focus_neighbor_left = begin.get_path_to(chosen)
	begin.focus_neighbor_right = begin.get_path_to(begin)


## The block under the element cards: an element's style in a line (in its colour), its passive, and its buttons with their plain
## names (KitWords under the scheme), as chips: "1  STRIKE ▲ / PUNCH / tap twice: Boulder". `el` "" the chosen element's.
func _show_keys(el: String) -> void:
	if not is_instance_valid(_keys_box):
		return
	var e := el if el != "" else MatchSetup.element
	_fill_kit(_keys_box, e, true, func() -> void:
		_lobby_dirty = true                     # (the lobby's class row says the new pick as the setup closes)
		_show_keys(e))


## Element `e`'s style, passive, guard and buttons laid into `box` (the match setup's keys block, the Practice panel's). With the
## style, its fighting style row too (`on_pick` called after a pick: the caller repaints).
static func _fill_kit(box: Control, e: String, with_style := true, on_pick := Callable()) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var pc := BroadcastUI.plate_c(e)
	var tint := pc.lerp(BroadcastUI.WHITE, 0.25) if e != "air" else Color("9fd4ee")
	if with_style:
		# (the mock-up's line: "FIRE · EMBER" in the element's colour and tracking, its style after it in white)
		var style := BroadcastUI.hbox(16)
		style.name = "StyleLine"
		var nick := BroadcastUI.caps("%s  ·  %s" % [MatchSetup.label(e), MatchSetup.competitor(e)], BroadcastUI.head(false, 4, 1), 28, tint)
		nick.name = "Nickname"
		style.add_child(nick)
		style.add_child(BroadcastUI.label(MatchSetup.style(e), 20, BroadcastUI.WHITE))
		box.add_child(style)
		box.add_child(_style_row(e, on_pick))
	# (the passive: its name on a plate, its line; the guard's own line is the Controls panel's)
	var ps := KitWords.passive(e)
	var pl := BroadcastUI.hbox(12)
	pl.add_child(BroadcastUI.tag("Passive  ·  " + String(ps.get("name", "")), 16, BroadcastUI.INK, pc if e != "air" else Color("9fd4ee"), 2))
	var pline := BroadcastUI.label(KitWords.passive_line(e), 18, BroadcastUI.DIM)
	pline.name = "PassiveLine"
	pl.add_child(pline)
	box.add_child(pl)
	var keys := HFlowContainer.new()
	keys.name = "KeyChips"
	keys.add_theme_constant_override("h_separation", 8)
	keys.add_theme_constant_override("v_separation", 8)
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if with_style:
		box.add_child(BroadcastUI.gap(0, 4))
	box.add_child(keys)
	var n := 0
	for line in KitWords.kit_lines(e, "", true):
		keys.add_child(_key_chip(String(line), n))
		n += 1


## The fighting style row under the element (the owner, 2026-10-16: "allow the ability to pick the fighting style"): the element's
## pickable styles as chips (AdvancementData: its own and the animated ones; the picked one lit, AdvancementStore.style_of), a press
## picks it for this element, for Classic and the worn loadout alike (AdvancementStore.pick_style; what plays from the next match),
## and `on_pick` repaints. After the chips the picked one's two strengths and two weaknesses ("Power+  Reach+  ·  Width-
## Mobility-": its levers, live in play, BendLoadout), the advancement window's words for them on its tooltip. One row: the keys
## under it must stay clear of the foot's hints (the styles still coming are the window's class picker's to list).
static func _style_row(e: String, on_pick: Callable) -> Control:
	var row := BroadcastUI.hbox(12)
	row.name = "StyleRow"
	var store := _script_of(ADVANCEMENT_STORE)
	var picked := String(store.call(&"style_of", e)) if store != null else ""
	var ids: Array = []
	var opts: Array = []
	for st: Dictionary in AdvancementData.styles(e):
		var id := String(st.get("id", ""))
		if bool(st.get("pickable", false)):
			ids.append(id)
			opts.append({"text": String(st.get("label", id)), "value": id, "name": "Style_" + id, "color": BroadcastUI.plate_c(e)})
	var head := BroadcastUI.caps("STYLE", BroadcastUI.head(false, 4, 1), 16, BroadcastUI.FAINT)
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(head)
	var seg := BroadcastUI.segments(opts, maxi(ids.find(picked), 0), 16, 10.0)
	seg.name = "Styles"
	row.add_child(seg)
	var up: Array = []
	var down: Array = []
	var long: Array = []
	for lv: Dictionary in AdvancementData.levers(picked):
		var plus := int(lv.get("sign", 0)) > 0
		(up if plus else down).append(String(lv.get("label", "")) + ("+" if plus else "-"))
		long.append(String(lv.get("line", "")))
	var levers := BroadcastUI.label("%s  ·  %s" % ["  ".join(PackedStringArray(up)), "  ".join(PackedStringArray(down))], 16, BroadcastUI.DIM)
	levers.name = "StyleLevers"
	levers.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	levers.mouse_filter = Control.MOUSE_FILTER_PASS
	levers.tooltip_text = "\n".join(PackedStringArray(long))
	row.add_child(levers)
	seg.picked.connect(func(i: int) -> void:
		if store == null or i < 0 or i >= ids.size():
			return
		var why := String(store.call(&"pick_style", e, String(ids[i])))
		if why != "":
			levers.text = why
		elif on_pick.is_valid():
			on_pick.call())
	return row


## One of an element's buttons as a chip: its key on a cap, its role, its move, and what a second tap readies. `line` as KitWords
## gives it ("1   STRIKE ▲   Punch  ·  tap twice: Fireball"), kept whole as the chip's `line` meta.
static func _key_chip(line: String, n: int) -> Control:
	var parts := line.split("   ", false)
	var v := BroadcastUI.vbox(0)
	if parts.size() >= 3:
		var top := BroadcastUI.hbox(6)
		top.add_child(BroadcastUI.key_cap(String(parts[0]).strip_edges(), 16))
		top.add_child(BroadcastUI.caps(String(parts[1]).strip_edges(), BroadcastUI.head(false, 2, 1), 16, BroadcastUI.FAINT))
		v.add_child(top)
		var rest := String(parts[2])
		var more := ""
		if rest.contains("  ·  "):
			more = rest.get_slice("  ·  ", 1)
			rest = rest.get_slice("  ·  ", 0)
		v.add_child(BroadcastUI.caps(rest.strip_edges(), BroadcastUI.head(false, 1), 24, BroadcastUI.WHITE))
		if more != "":
			v.add_child(BroadcastUI.lab(more, BroadcastUI.body(), 16, BroadcastUI.DIM))
	else:
		v.add_child(BroadcastUI.label(line, 16, BroadcastUI.DIM))
	var c := BroadcastUI.chip(v, Color(BroadcastUI.NAVY1, 0.9), 0.0, Vector4(10, 6, 12, 5))
	c.name = "Key_%d" % n
	c.set_meta(&"line", line)
	return c


## An element's buttons as lines: "1   STRIKE   Spike  ·  tap twice: Boulder" (KitWords.kit_lines, the keys scheme).
static func key_lines(el: String) -> Array:
	return KitWords.kit_lines(el, "keys")


## The Controls row of the match setup and the Practice panel: its panel (_open_controls), Esc back to `back`.
func _controls_row(back: Callable) -> Button:
	var b := BroadcastUI.link_row(KitWords.w("controls", "Controls"), KitWords.w("controls_line"), 446.0)
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
	box.add_child(BroadcastUI.heading(KitWords.w("controls", "Controls")))
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
		for line in [KitWords.guard_line(MatchSetup.element)] + KitWords.rule_lines():
			var l := BroadcastUI.label(String(line), 16, BroadcastUI.WHITE, true)
			l.custom_minimum_size = Vector2(520, 0)
			rules.add_child(l)
	paint.call()
	box.add_child(_gap(6))
	# (round 4 SIMPLE: Basic / Full first, kept at once; the other ways to pick moves are Full's)
	var preset := BroadcastUI.item("", 22, "-")
	preset.name = "ControlsPreset"
	var sch := BroadcastUI.item("", 22, "-")
	sch.name = "Scheme"
	var paint_sch := func() -> void:
		_set_row(preset, MatchSetup.controls_row(), MatchSetup.controls_row_line())
		_set_row(sch, KitWords.other_ways_row(), KitWords.other_ways_line())
		sch.visible = not MatchSetup.basic()
	paint_sch.call()
	preset.pressed.connect(func() -> void:
		MatchSetup.set_controls(MatchSetup.next_controls())
		paint_sch.call()
		paint.call())
	sch.pressed.connect(func() -> void:
		MatchSetup.set_scheme(MatchSetup.next_scheme())
		paint_sch.call()
		paint.call())
	box.add_child(preset)
	box.add_child(sch)
	(sch if sch.visible else preset).grab_focus.call_deferred()


## The first-launch offer and the permanent Start here row share one beginner path. Opening it changes no settings;
## either launch explicitly enables the existing Basic helpers and the easy setup described on screen.
func _offer_basics() -> void:
	_open_panel()
	var wd: Dictionary = (MatchSetup.schemes_data().get("controls", {}) as Dictionary).get("offer", {})
	var box := VBoxContainer.new()
	box.name = "BasicsOffer"
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(box)
	box.add_child(BroadcastUI.heading(String(wd.get("title", "New here?"))))
	var line := BroadcastUI.label(String(wd.get("line", "")), 18, BroadcastUI.WHITE, true)
	line.custom_minimum_size = Vector2(520, 0)
	box.add_child(line)
	InputSetup.ensure()
	for spec: String in wd.get("first_keys", []):
		var text := String(LessonCard.resolve(spec).text).replace("[LMB]", "left mouse button").replace("[RMB]", "right mouse button")
		var keys := BroadcastUI.label(text, 20, BroadcastUI.WHITE, true)
		keys.custom_minimum_size = Vector2(520, 0)
		box.add_child(keys)
	box.add_child(_gap(6))
	var go := BroadcastUI.item(String(wd.get("go", "Learn the basics")), 30, String(wd.get("go_line", "")))
	go.name = "Basics"
	go.pressed.connect(_beginner_start.bind(true))
	box.add_child(go)
	var easy := BroadcastUI.item(String(wd.get("easy", "Play an easy match")), 30, String(wd.get("easy_line", "")))
	easy.name = "EasyMatch"
	easy.pressed.connect(_beginner_start.bind(false))
	box.add_child(easy)
	var help := BroadcastUI.label(String(wd.get("help", "")), 18, BroadcastUI.DIM, true)
	help.custom_minimum_size = Vector2(520, 0)
	box.add_child(help)
	var later := BroadcastUI.item(String(wd.get("later", "Not now")), 22)
	later.name = "NotNow"
	later.pressed.connect(_close_panel)
	box.add_child(later)
	go.grab_focus.call_deferred()


func _beginner_start(lessons: bool) -> void:
	MatchSetup.set_controls("basic")
	MatchSetup.set_aim_help("light")           # (Normal, as everywhere: the owner, 2026-10-12; was Strong for a beginner)
	FirstHints.set_on(true)
	MatchSetup.difficulty = "easy"
	MatchSetup.rules_choice = "stock"
	MatchSetup.games_n = 1
	MatchSetup.rounds_to_win = 1
	MatchSetup.format = "1v1"
	MatchSetup.mates = []
	MatchSetup.spectate = false
	# A prior custom practice must not slow the lessons or keep launching a new player off the deck.
	MatchSetup.speed = 1.0
	MatchSetup.throw_me = false
	MatchSetup.foe_pct = -1.0
	MatchSetup.my_pct = -1.0
	MatchSetup.steer = "none"
	MatchSetup.fresh = false
	if lessons:
		MatchSetup.set_practice(RingLessons.dummy_for(MatchSetup.element), "stand")
		RingLessons.ask(MatchSetup.element)
	else:
		RingMode.lessons_asked = false
		MatchSetup.set_match()
		MatchSetup.foes = [MatchSetup.ANY]
		MatchSetup.quick = true              # use the existing first-match hints; keep the custom opponent choice
	_play_match()


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


## The creator (a test's stand-in through creator_hook): an object with a closed(accepted) signal.
static func _make_creator(first := false) -> Object:
	if creator_hook.is_valid():
		return creator_hook.call(first) as Object
	return _creator(first)


func _open_look() -> void:
	_close_panel()
	var before := AppearanceStore.element()
	var c := _make_creator()
	c.connect(&"closed", func(ok: bool) -> void: _after_creator.call_deferred(ok, _after_look, before))


## Back from Your look (and from the element step it may lead to): the lobby, the focus on its row.
func _after_look() -> void:
	if _panel_scroll.visible:
		_close_panel()
	var back := _items.find_child("YourLook", true, false) as Button
	if back != null:
		back.grab_focus.call_deferred()
	else:
		_first_focus()


## The creator closed (`accepted`: Accept kept a new look; `before` the character's element when it opened). The fighters are
## dressed from the new look; when the character has no element yet, the step to choose it comes next (PlayerAppearance.element_due:
## the post-Accept hook), then `then` (the match setup, the lobby).
func _after_creator(accepted: bool, then: Callable, before := "") -> void:
	if not is_inside_tree():
		return
	if accepted:
		# (a look the creator built anew, another people or a body type, carries no element: the character keeps its own)
		if before != "" and AppearanceStore.element() == "":
			AppearanceStore.set_element(before)
		_refresh_fighters()
	if PlayerAppearance.element_due(accepted):
		_open_element_step(then)
	else:
		then.call()


## The look changed (the creator accepted a new one): the lobby's lower third and its figure made anew from it, the cards' again
## as they are next shown.
func _refresh_fighters() -> void:
	_paint_lobby()
	if _fw == null:
		return
	_fw.refresh()
	if is_instance_valid(_fview):
		_fview.queue_free()
	_fview = null
	_fview_el = ""
	_fighter.texture = null
	_fighter.modulate.a = 0.0
	_build_figure.call_deferred()


# --- Choose your element -------------------------------------------------------------------------------------

## The step after the character is made: your fighter in each element's ring dress as the match setup's four cards, one pick, Enter
## to confirm. Left and Right (and the number keys) move the pick, Enter, the button or a double click on a card confirms, Esc leaves
## it for later and nothing is kept. Confirmed, the element is the character's (AppearanceStore.set_element: the default of every
## setup from then on; a match may play another) and the next screen follows: `then` (the match setup, the lobby).
func _open_element_step(then: Callable) -> void:
	_open_panel(true)
	_step_then = then
	_step_prev = MatchSetup.element
	var mine := AppearanceStore.element()
	if mine != "":
		MatchSetup.element = mine                 # (chosen already: this one first)
	_return_to = _skip_element
	var box := Control.new()
	box.name = "ElementStep"
	box.custom_minimum_size = BroadcastUI.DESIGN
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	# the head: the sport, the step's name and what it means
	var hd := BroadcastUI.group(box, Vector2(0, 0), Vector2(84, 34), Vector2(1440, 76))
	BroadcastUI.put(hd, BroadcastUI.tag(MatchSetup.sport(), 20, BroadcastUI.INK, BroadcastUI.TEAL, 4), Rect2(0, 16, 0, 0))
	var head_title := BroadcastUI.lab("CHOOSE YOUR ELEMENT", BroadcastUI.head(true, 2), 60, BroadcastUI.WHITE)
	head_title.name = "StepTitle"
	BroadcastUI.put(hd, head_title, Rect2(176, 0, 640, 66))
	var rule := BroadcastUI.para("Your fighter trains in one element, and every match starts with it. A single match can still play any of the four.",
			BroadcastUI.body(true), 18, BroadcastUI.DIM, 560.0)
	rule.name = "StepLine"
	BroadcastUI.put(hd, rule, Rect2(850, 10, 560, 60))
	# the four fighters as cards (the match setup's own)
	var cards := BroadcastUI.group(box, Vector2(0, 0), Vector2(84, 128), Vector2(930, 700))
	cards.name = "Cards"
	BroadcastUI.section(cards, Vector2(0, 0), "YOUR ELEMENT", 900.0)
	var four := Control.new()
	four.name = "Elements"
	four.mouse_filter = Control.MOUSE_FILTER_IGNORE
	BroadcastUI.put(cards, four, Rect2(0, 36, 900, 452))
	for i in Bending.ELEMENTS.size():
		var el: String = Bending.ELEMENTS[i]
		var card := _card(el, i + 1)
		card.position = Vector2(float(i) * 228.0, 0.0)
		card.focus_entered.connect(_choose_element.bind(el))          # (the pick follows the focus: Left and Right)
		card.pressed.connect(_confirm_element)                        # (Enter or the pad's accept on the focused card)
		card.gui_input.connect(_step_click.bind(card, el))            # (a mouse click picks it, a double click confirms)
		_element_rows[el] = card
		four.add_child(card)
	_keys_box = VBoxContainer.new()
	_keys_box.name = "Keys"
	(_keys_box as VBoxContainer).add_theme_constant_override("separation", 6)
	BroadcastUI.put(cards, _keys_box, Rect2(0, 502, 920, 300))    # (the style row too, 2026-10-16: the cards group is 700 tall)
	# the choice at the right: your fighter, the element picked, and the button
	var sc := BroadcastUI.group(box, Vector2(1, 0), Vector2(-574, 128), Vector2(494, 488))
	sc.name = "StepCard"
	BroadcastUI.plate(sc, Rect2(0, 0, 494, 488), Color(BroadcastUI.NAVY1, 0.94), 0.0).name = "CardBack"
	BroadcastUI.rect(sc, Rect2(0, 0, 494, 4), BroadcastUI.TEAL)
	BroadcastUI.put(sc, BroadcastUI.lab("YOUR FIGHTER", BroadcastUI.head(false, 5, 1), 19, BroadcastUI.TEAL), Rect2(24, 14, 300, 24))
	var who := BroadcastUI.lab(FighterWorld.fighter_name(), BroadcastUI.head(true, 2), 74, BroadcastUI.WHITE)
	who.name = "FighterName"
	who.uppercase = true
	who.set_meta(&"dsz", 74)
	BroadcastUI.fit_text(who, 446.0, 40)
	BroadcastUI.put(sc, who, Rect2(24, 36, 446, 84))
	var picked := Control.new()
	picked.name = "Picked"
	picked.mouse_filter = Control.MOUSE_FILTER_IGNORE
	BroadcastUI.put(sc, picked, Rect2(24, 128, 446, 58))
	var stats := BroadcastUI.hbox(8)
	stats.name = "Stats"
	BroadcastUI.put(sc, stats, Rect2(24, 204, 446, 76))
	var note := BroadcastUI.para("Your class and talents belong to the element: you can look at them from the main menu once you are in.",
			BroadcastUI.body(), 18, BroadcastUI.DIM, 446.0)
	note.name = "StepNote"
	BroadcastUI.put(sc, note, Rect2(24, 300, 446, 76))
	_cta(sc, "Choose", Rect2(16, 404, 462, 66), 330.0, _confirm_element)
	# the keys at the foot
	var kh := BroadcastUI.group(box, Vector2(0, 1), Vector2(84, -58), Vector2(900, 36))
	var hh := BroadcastUI.hbox(26)
	hh.add_child(BroadcastUI.key_hint("ENTER", "Choose"))
	hh.add_child(BroadcastUI.key_hint("ESC", "Later"))
	hh.add_child(BroadcastUI.key_hint("← →", "Pick"))
	hh.add_child(BroadcastUI.key_hint("1 - 4", "Element"))
	BroadcastUI.put(kh, hh, Rect2(0, 0, 900, 36))
	_mark_elements()
	_show_keys("")
	_paint_step()
	_attach_card_views()
	# (the focus on the card in force: Left and Right go along the four, Down to the button, the button's Up back to the card)
	var cs: Array = []
	for el: String in Bending.ELEMENTS:
		cs.append(_element_rows[el])
	var go := sc.find_child("Choose", true, false) as Control
	for i in cs.size():
		var c := cs[i] as Control
		c.focus_neighbor_left = c.get_path_to(cs[maxi(i - 1, 0)])
		c.focus_neighbor_right = c.get_path_to(cs[mini(i + 1, cs.size() - 1)])
		c.focus_neighbor_top = c.get_path_to(c)
		c.focus_neighbor_bottom = c.get_path_to(go)
	var cur := _element_rows.get(MatchSetup.element) as Control
	go.focus_neighbor_top = go.get_path_to(cur)
	go.focus_neighbor_left = go.get_path_to(cur)
	go.focus_neighbor_right = go.get_path_to(go)
	go.focus_neighbor_bottom = go.get_path_to(go)
	cur.grab_focus.call_deferred()


## A big button of the screens (the match setup's Begin): `nm` is its name (the text and plate named under it), its words in capitals,
## in the colour of your element, outlined in white while it has the focus (_paint_cta), the Enter key on it. The words and the
## key are centred on the button's height whatever size the type is raised to (a small window grows them, up and down alike).
func _cta(parent: Control, nm: String, r: Rect2, text_w: float, what: Callable) -> Button:
	var b := Button.new()
	b.name = nm
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(st, empty)
	BroadcastUI.put(parent, b, r)
	var plate := Panel.new()
	plate.name = "Plate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(plate)
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var t := BroadcastUI.lab(nm, BroadcastUI.head(true, 6), 52, BroadcastUI.INK)
	t.name = "Text"
	t.uppercase = true
	b.add_child(t)
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.offset_left = 34.0
	t.offset_right = -(r.size.x - 34.0 - text_w)
	t.grow_vertical = Control.GROW_DIRECTION_BOTH
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var kc := BroadcastUI.key_cap("ENTER", 18)
	b.add_child(kc)
	kc.anchor_left = 1.0
	kc.anchor_right = 1.0
	kc.anchor_top = 0.5
	kc.anchor_bottom = 0.5
	kc.offset_left = -40.0
	kc.offset_right = -40.0
	kc.offset_top = 0.0
	kc.offset_bottom = 0.0
	kc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	kc.grow_vertical = Control.GROW_DIRECTION_BOTH
	b.pressed.connect(what)
	b.focus_entered.connect(_paint_cta.bind(nm))
	b.focus_exited.connect(_paint_cta.bind(nm))
	return b


## The big button `nm` in the colour of your element, outlined in white while it has the focus.
func _paint_cta(nm: String) -> void:
	var b := _panel.find_child(nm, true, false) as Button
	if b == null:
		return
	var plate := b.find_child("Plate", false, false) as Panel
	plate.add_theme_stylebox_override("panel", BroadcastUI.box(BroadcastUI.plate_c(MatchSetup.element), BroadcastUI.LEAN,
			4 if b.has_focus() else 0, BroadcastUI.WHITE))


## The step as the pick has it: the element's plate and its style, the button's words and colour (called as the pick moves).
func _paint_step() -> void:
	var sc := _panel.find_child("StepCard", true, false)
	if sc == null:
		return
	var el := MatchSetup.element
	var picked := sc.find_child("Picked", false, false) as Control
	for c in picked.get_children():
		picked.remove_child(c)
		c.queue_free()
	_versus_plate(picked, Rect2(0, 0, 446, 58), el)
	# (the element's class and talent points, as the lobby's lower third has them)
	var stats := sc.find_child("Stats", false, false) as Control
	for c in stats.get_children():
		stats.remove_child(c)
		c.queue_free()
	var info := fighter_info(el)
	var tint := BroadcastUI.plate_c(el) if el != "air" else Color("7cc4e6")
	for pair: Array in [["CLASS", String(info.cls)], ["TALENTS", String(info.talents)]]:
		var v := BroadcastUI.vbox(0)
		v.add_child(BroadcastUI.lab(String(pair[0]), BroadcastUI.head(false, 3, 1), 16, BroadcastUI.FAINT, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(BroadcastUI.caps(String(pair[1]), BroadcastUI.head(false, 1), 24, tint, HORIZONTAL_ALIGNMENT_CENTER))
		stats.add_child(BroadcastUI.chip(v, Color(BroadcastUI.NAVY3, 0.9), BroadcastUI.LEAN, Vector4(12, 4, 12, 2)))
	var t := sc.find_child("Text", true, false) as Label
	t.text = "Choose %s" % MatchSetup.label(el)
	t.set_meta(&"dsz", 52)
	BroadcastUI.fit_text(t, 330.0, 36)
	_paint_cta("Choose")


## A click on a card of the step: the first picks it, a double click confirms it (the engine's own press is not used for the mouse,
## so one stray click never keeps an element).
func _step_click(ev: InputEvent, card: Button, el: String) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	card.accept_event()
	card.grab_focus()
	if MatchSetup.element != el:
		_choose_element(el)
	if mb.double_click:
		_confirm_element()


## The pick kept as the character's element, then the next screen.
func _confirm_element() -> void:
	var el := MatchSetup.element
	if not el in Bending.ELEMENTS or _panel.find_child("ElementStep", true, false) == null:
		return
	AppearanceStore.set_element(el)
	MatchSetup.element = el
	MatchSetup.save()
	_leave_step()


## Esc: not now. What the focus passed over is given back (the setup's element as it was) and the next screen follows.
func _skip_element() -> void:
	MatchSetup.element = _step_prev
	_leave_step()


func _leave_step() -> void:
	var then := _step_then
	_step_then = Callable()
	_return_to = Callable()
	_element_rows = {}
	_keys_box = null
	var step := _panel.find_child("ElementStep", true, false)
	if step != null:
		step.get_parent().remove_child(step)
		step.queue_free()
	if then.is_valid():
		then.call()
	else:
		_close_panel()



## The open world's rows (the valley of 1765), as the menu had them: Continue (a save), New game, Load game, Museum, Co-op,
## the duel test and Campaigns (coming).
func _open_world() -> void:
	_open_panel()
	_panel.add_child(BroadcastUI.heading("Open world"))
	var latest := SaveGame.latest_slot()
	if latest != "":
		var b := BroadcastUI.item("Continue", 28, _save_line(latest))
		b.pressed.connect(_play_save.bind(latest))
		_panel.add_child(b)
	var ng := BroadcastUI.item("New game", 28)
	ng.pressed.connect(_from_world.bind(_open_new_game))
	_panel.add_child(ng)
	var ld := BroadcastUI.item("Load game", 28, "", "" if latest != "" else "no saves yet")
	ld.pressed.connect(_from_world.bind(_open_load))
	_panel.add_child(ld)
	var mu := BroadcastUI.item("Museum", 28)
	mu.pressed.connect(_from_world.bind(_open_museum))
	_panel.add_child(mu)
	var co := BroadcastUI.item("Co-op", 28, "host a game or join a friend's")
	co.pressed.connect(_from_world.bind(_open_coop))
	_panel.add_child(co)
	var du := BroadcastUI.item("Duel (test): 1 v 1", 28, "the earlier test duel on the open land; first to %d" % DuelMode.TO_WIN)
	du.pressed.connect(_play_duel)
	_panel.add_child(du)
	_panel.add_child(BroadcastUI.item("Campaigns", 28, "", "coming"))
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
	_museum_room = BroadcastUI.label("", 15, BroadcastUI.FAINT)
	text.add_child(_museum_room)
	_museum_title = BroadcastUI.label("", 26, BroadcastUI.TEAL)
	text.add_child(_museum_title)
	_museum_text = BroadcastUI.label("", 18, BroadcastUI.DIM, true)
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
		var b := BroadcastUI.item(String(e[1]), 26)
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
	_open_panel()
	_panel.add_child(BroadcastUI.heading("A new life"))
	# (no background to choose: user 2026-10-01, "we shouldnt need to pick back country officers and etc"; you start as
	# the default newcomer, SurvivalBridge.BACKGROUND, and make your name in the game)
	_chosen_bg = ""
	var begin := BroadcastUI.item("Begin", 30)
	# a start with nothing: no clothes, tools, weapons or food; everything made from what lies on the ground
	var bare_row := BroadcastUI.item("Start with nothing:  off", 22, "no clothes, tools or weapons: sticks, stones and chert from the ground, then the knapping stone")
	bare_row.pressed.connect(func() -> void:
		_bare = not _bare
		var t := bare_row.find_child("Text", true, false) as Label
		if t:
			t.text = "Start with nothing:  %s" % ("on" if _bare else "off"))
	_panel.add_child(bare_row)
	# a spouse at the start (a wife or husband who follows orders), or a life alone
	var spouse_row := BroadcastUI.item("Spouse:  on", 22, "a wife or husband beside you from the start who takes orders (gather, fell, carry); off: you begin alone")
	spouse_row.pressed.connect(func() -> void:
		_spouse = not _spouse
		var t := spouse_row.find_child("Text", true, false) as Label
		if t:
			t.text = "Spouse:  %s" % ("on" if _spouse else "off"))
	_panel.add_child(spouse_row)
	if SaveGame.latest_slot() != "":
		_panel.add_child(BroadcastUI.label("Your saves stay as they are; the autosave is written over as you play.", 16, BroadcastUI.FAINT, true))
	begin.pressed.connect(_play_new)
	_panel.add_child(begin)
	begin.grab_focus.call_deferred()


## Co-op (NetSession; docs/multiplayer_readiness.md): host this machine's game, or join one by its address. The game
## starts as Continue would (the latest save, else a new game) with the session asked for.
func _open_coop() -> void:
	_open_panel()
	_panel.add_child(BroadcastUI.heading("Co-op"))
	_panel.add_child(BroadcastUI.label("Play the valley together: your squad side by side, other squads to fight or to leave be.", 18, BroadcastUI.DIM, true))
	# the squad (Arc Raiders' way): the same squad is co-op, no friendly fire; another squad can be fought
	var sq := BroadcastUI.item("Squad:  %d" % _squad, 22, "friends on the same squad fight together; other squads can fight you")
	sq.pressed.connect(func() -> void:
		_squad = _squad % NetSession.SQUADS + 1
		var t := sq.find_child("Text", true, false) as Label
		if t:
			t.text = "Squad:  %d" % _squad)
	_panel.add_child(sq)
	var hb := BroadcastUI.item("Host a game", 26, "others join with this machine's address, port %d" % NetSession.PORT)
	hb.pressed.connect(func() -> void: _play_net({"mode": "host", "squad": _squad}))
	_panel.add_child(hb)
	var addr := LineEdit.new()
	addr.placeholder_text = "the host's address, e.g. 192.168.1.20"
	addr.text = "127.0.0.1"
	addr.custom_minimum_size = Vector2(420, 44)
	addr.add_theme_font_size_override("font_size", 20)
	_panel.add_child(addr)
	var jb := BroadcastUI.item("Join", 26, "the game at the address above")
	var note := BroadcastUI.label("", 17, BroadcastUI.DIM, true)
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
		_play_new()


func _open_load() -> void:
	_open_panel()
	_panel.add_child(BroadcastUI.heading("Load game"))
	var any := false
	for slot: String in SaveGame.SLOTS:
		if SaveGame.read_slot(slot).is_empty():
			continue
		any = true
		var b := BroadcastUI.item("Autosave" if slot == "auto" else ("Quick save" if slot == "quick" else slot.capitalize()), 26,
				_save_line(slot).get_slice("  ·  ", 1) + "  ·  " + _save_line(slot).get_slice("  ·  ", 2))
		b.pressed.connect(_play_save.bind(slot))
		_panel.add_child(b)
	if not any:
		_panel.add_child(BroadcastUI.label("No saves yet.", 19, BroadcastUI.DIM))
	var first := _panel.get_child(1) if _panel.get_child_count() > 1 else null
	if first is Button:
		(first as Button).grab_focus.call_deferred()


func _open_settings() -> void:
	_open_panel()
	_panel.add_child(BroadcastUI.heading("Settings"))
	_panel.add_child(GameSettings.rows(null, true))


func _open_credits() -> void:
	_open_panel()
	_panel.add_child(BroadcastUI.heading("Credits"))
	# the copyright notice and the no-AI-training reservation first (NOTICE.txt)
	for para: String in paragraphs(text_file("res://NOTICE.txt")):
		var n := BroadcastUI.label(para, 16, BroadcastUI.DIM, true)
		n.custom_minimum_size = Vector2(560, 0)
		_panel.add_child(n)
	for block: Array in credits():
		if String(block[0]) != "":
			_panel.add_child(BroadcastUI.label(String(block[0]), 21, BroadcastUI.TEAL, true))
		for para: String in block[1]:
			var l := BroadcastUI.label(para, 16, BroadcastUI.WHITE, true)
			l.custom_minimum_size = Vector2(560, 0)
			_panel.add_child(l)
	# the licence in full (EULA.txt), its section heads in gold
	var eula := paragraphs(text_file("res://EULA.txt"))
	if not eula.is_empty():
		_panel.add_child(BroadcastUI.heading("Licence", 30))
		for para: String in eula:
			if para.begins_with("DRAFT."):
				continue                # (the owner's note to have a lawyer read it: not a line for the player)
			var head := para == para.to_upper() and para.length() < 60
			var e := BroadcastUI.label(para, 19 if head else 15, BroadcastUI.TEAL if head else BroadcastUI.WHITE, true)
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


## CREDITS.md as [heading, [paragraphs]] with the markdown taken off (headings, bold, code, links' brackets); nothing when
## the project has no CREDITS.md (the UI audit, 2026-10-09: the page said "Credits: see CREDITS.md." about a file that is
## not there): the page shows the notice and the licence it has.
static func credits() -> Array:
	var out: Array = []
	var f := FileAccess.open("res://CREDITS.md", FileAccess.READ)
	if f == null:
		return out
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

