class_name GameSettings
extends RefCounted
## The menus' settings (the main menu's and the pause menu's Settings), kept in user://settings.cfg beside the
## graphics panel's [graphics] section (read, changed and written back whole: its keys are kept):
##   [audio]     master, effects, ambience, music (0..1 of full volume; the buses SFX and Ambience once Sfx has made
##               them, Music once MusicDirector has)
##   [controls]  mouse (the look's sensitivity, FrontierPlayer.cs_sensitivity), invert_y
##   [display]   fullscreen, vsync
##   [game]      iron_man (Iron Man: injuries stay; see iron_man())
##   [look]      character: the Look (characters and world), "soft" (the default) or "classic" (SoftLook, SoftWorld)
##   [match]     the last Tidebreak setup (MatchSetup.save / load: element, foe, difficulty, rounds), for the main menu's
##               panel and its Quick match
##   [quick]     each element's quick spell on the left button ("move/variation"; MatchSetup.quick_of / set_quick)
## The level applies them to its player and buses (FrontierLevel: apply_to(player) after its audio is set up).

const PATH := "user://settings.cfg"
## The file get_value / set_value read and write: PATH (a test points it at a file of its own, never the player's).
static var path := PATH
## Where a tool or test run (-s) reads and writes while `path` is still PATH: never the player's own file (as
## AppearanceStore keeps a test's look apart; the main menu's match panel saves its setup on Begin).
const TEST_PATH := "user://settings_test_runs.cfg"
const DEFAULTS := {
	"audio": {"master": 1.0, "effects": 1.0, "ambience": 1.0, "music": 1.0},
	"controls": {"mouse": 2.0, "invert_y": false},
	"display": {"fullscreen": false, "vsync": true, "cap_60": true},
	"game": {"iron_man": false},
	# (the Character look: SoftLook's "soft" (the owner's choice, 2026-10-10) or "classic", the look as it was)
	"look": {"character": "soft"},
	"match": {"element": "earth", "foe": "earth", "difficulty": "normal", "rounds": 2, "light": "noon"},
	# (each element's quick spell on the left button, "move/variation": MatchSetup.quick_of / set_quick)
	"quick": {"earth": "rock_jab/pebbles", "water": "water_jet/splash", "fire": "fire_jab/jab", "air": "air_palm/palm"},
}
const BUSES := {"master": &"Master", "effects": &"SFX", "ambience": &"Ambience", "music": &"Music"}


## The file read and written now: `path`, except PATH in a tool or test run (-s), which is TEST_PATH.
static func file() -> String:
	if path == PATH:
		var args := OS.get_cmdline_args()
		if "-s" in args or "--script" in args:
			return TEST_PATH
	return path


static func get_value(section: String, key: String) -> Variant:
	var cf := ConfigFile.new()
	cf.load(file())
	return cf.get_value(section, key, DEFAULTS[section][key])


## Whether the file holds `key` of `section` (a value chosen, not the default).
static func is_set(section: String, key: String) -> bool:
	var cf := ConfigFile.new()
	cf.load(file())
	return cf.has_section_key(section, key)


static func set_value(section: String, key: String, v: Variant) -> void:
	set_section(section, {key: v})


## Several keys of one section written at once (one read and one write of the file).
static func set_section(section: String, values: Dictionary) -> void:
	var cf := ConfigFile.new()
	var f := file()
	cf.load(f)
	for k: String in values:
		cf.set_value(section, k, values[k])
	cf.save(f)
	writes += 1


## Writes made through set_value / set_section this run (round 4's merge: a reader that caches a value of the file, such as
## RingAssist.won_once read by the HUD's strip each frame, reads it again only when this or file() changed).
static var writes := 0


## Iron Man (user 2026-09-30: "this should be a iron man mode", "do it" to permadeath and to saving the injury): what a wound
## breaks stays broken (a cut cord keeps the legs gone for good, a broken leg slows until its wound has knit, a mortal wound
## staggers: FrontierPlayer._maim), a death ends the character (DeathRule: the saves are erased, back to the main menu), and
## there is no quick save or quick load (SaveGame: the autosave only). Off (the default) nothing a wound does touches the
## movement speed (the lasting wounds' own rules, LastingConditions) and a death costs the pack.
## The mode belongs to the run, and its save: a new game takes the Settings toggle (the main menu's, not changed in a game), a
## save carries its own (SaveGame meta "iron"), so turning the toggle off does not free an Iron Man save. The argument
## ironman=on sets it for a run (tests).
static var _run_set := false
static var _run_iron := false


static func iron_man() -> bool:
	for a in OS.get_cmdline_user_args():
		if a == "ironman=on":
			return true
	return _run_iron if _run_set else bool(get_value("game", "iron_man"))


## The run is Iron Man or not whatever the toggle says (a save loaded).
static func set_run(iron: bool) -> void:
	_run_set = true
	_run_iron = iron


## The run follows the toggle again (a new game, the main menu).
static func clear_run() -> void:
	_run_set = false
	_run_iron = false


## The volumes onto the buses there are, the window's mode and vsync.
static func apply_global() -> void:
	for k: String in BUSES:
		var i := AudioServer.get_bus_index(BUSES[k])
		if i >= 0:
			var v := float(get_value("audio", k))
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(i, v <= 0.001)
	var fs := bool(get_value("display", "fullscreen"))
	var mode := DisplayServer.window_get_mode()
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED
	if fs != (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN):
		DisplayServer.window_set_mode(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(get_value("display", "vsync")) else DisplayServer.VSYNC_DISABLED)
	# at most 60 frames a second (user 2026-10-01: "the game is burning hot"): a 120 Hz display ran it at 120 with vsync alone
	Engine.max_fps = 60 if bool(get_value("display", "cap_60")) else 0


## The look's sensitivity and invert onto the player, and the rest (apply_global).
static func apply_to(player: Node) -> void:
	apply_global()
	if player == null:
		return
	player.set("cs_sensitivity", float(get_value("controls", "mouse")))
	player.set("invert_y", bool(get_value("controls", "invert_y")))


## A row of one choice among a few words (the Look): the label and the words; `changed` gets the index picked. The
## broadcast look: a segmented choice (BroadcastUI.segments); the serif menus: the word in force, a press steps to the next.
static func choice(text: String, options: Array, chosen: int, changed: Callable, broadcast := false) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	h.name = text.replace(" ", "")
	if broadcast:
		var l := BroadcastUI.lab(text, BroadcastUI.body(true), 22, BroadcastUI.WHITE)
		l.custom_minimum_size = Vector2(240, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var sg := BroadcastUI.segments(options, maxi(chosen, 0), 18)
		sg.picked.connect(func(i: int) -> void: changed.call(i))
		h.add_child(sg)
		return h
	var ml := MenuUI.label(text, 20, MenuUI.INK)
	ml.custom_minimum_size = Vector2(230, 0)
	h.add_child(ml)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", FrontierHUD.serif())
	b.add_theme_font_size_override("font_size", 20)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, MenuUI.GOLD)
	var at := [maxi(chosen, 0)]
	b.text = String(options[at[0]]) if not options.is_empty() else ""
	b.pressed.connect(func() -> void:
		at[0] = (at[0] + 1) % maxi(options.size(), 1)
		b.text = String(options[at[0]])
		changed.call(at[0]))
	h.add_child(b)
	return h


## The Settings rows (for a menu's sub-screen): volumes, the mouse, invert, fullscreen, vsync, the Look. `player` gets the
## controls' changes at once (the pause menu's), null from the main menu. `broadcast`: the broadcast menus' look (BroadcastUI:
## the main menu's and the ring's Esc menu's); the open world's pause menu keeps the serif.
static func rows(player: Node = null, broadcast := false) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	var pct := func(x: float) -> String: return "%d%%" % roundi(x * 100.0)
	var slider: Callable = BroadcastUI.slider if broadcast else MenuUI.slider
	var toggle: Callable = BroadcastUI.toggle if broadcast else MenuUI.toggle
	for k: Array in [["master", "Volume"], ["effects", "Effects"], ["ambience", "The woods"], ["music", "Music"]]:
		var key := String(k[0])
		v.add_child(slider.call(String(k[1]), 0.0, 1.0, 0.05, float(get_value("audio", key)), pct, func(x: float) -> void:
			set_value("audio", key, x)
			apply_global()))
	v.add_child(slider.call("Mouse", 0.5, 6.0, 0.1, float(get_value("controls", "mouse")),
			func(x: float) -> String: return "%.1f" % x, func(x: float) -> void:
				set_value("controls", "mouse", x)
				if player:
					player.set("cs_sensitivity", x)))
	v.add_child(toggle.call("Invert the look", bool(get_value("controls", "invert_y")), func(on: bool) -> void:
		set_value("controls", "invert_y", on)
		if player:
			player.set("invert_y", on)))
	v.add_child(toggle.call("Full screen", bool(get_value("display", "fullscreen")), func(on: bool) -> void:
		set_value("display", "fullscreen", on)
		apply_global()))
	v.add_child(toggle.call("Vertical sync", bool(get_value("display", "vsync")), func(on: bool) -> void:
		set_value("display", "vsync", on)
		apply_global()))
	v.add_child(toggle.call("Cap at 60 frames a second (cooler, quieter)", bool(get_value("display", "cap_60")), func(on: bool) -> void:
		set_value("display", "cap_60", on)
		apply_global()))
	# the Look (SoftLook, SoftWorld): at once on every character and the world shown, kept
	v.add_child(choice("Look", ["Classic", "Soft"], SoftLook.MODES.find(SoftLook.mode()), func(i: int) -> void:
		SoftLook.set_mode(String(SoftLook.MODES[i])), broadcast))
	if player == null:
		# (chosen before a game, not in the middle of one)
		v.add_child(toggle.call("Iron Man: injuries stay", bool(get_value("game", "iron_man")), func(on: bool) -> void:
			set_value("game", "iron_man", on)))
	v.add_child(BroadcastUI.label("Graphics: F2 in the game.", 16, BroadcastUI.FAINT) if broadcast else MenuUI.label("Graphics: F2 in the game.", 16, MenuUI.FAINT))
	return v
