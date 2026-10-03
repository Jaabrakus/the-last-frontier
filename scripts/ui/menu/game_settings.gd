class_name GameSettings
extends RefCounted
## The menus' settings (the main menu's and the pause menu's Settings), kept in user://settings.cfg beside the
## graphics panel's [graphics] section (read, changed and written back whole: its keys are kept):
##   [audio]     master, effects, ambience, music (0..1 of full volume; the buses SFX and Ambience once Sfx has made
##               them, Music once MusicDirector has)
##   [controls]  mouse (the look's sensitivity, FrontierPlayer.cs_sensitivity), invert_y
##   [display]   fullscreen, vsync
##   [game]      iron_man (Iron Man: injuries stay; see iron_man())
##   [hud]       style: "classic" (the framed MMO layout: ClassicFrames, HudClassicMap) or "minimal" (lettering over the
##               world), read by ClassicSkin.style() when the HUD is built; the row switches a game's HUD at once
## The level applies them to its player and buses (FrontierLevel: apply_to(player) after its audio is set up).

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"audio": {"master": 1.0, "effects": 1.0, "ambience": 1.0, "music": 1.0},
	"controls": {"mouse": 2.0, "invert_y": false},
	"display": {"fullscreen": false, "vsync": true, "cap_60": true},
	"game": {"iron_man": false},
	"hud": {"style": "classic"},
}
const BUSES := {"master": &"Master", "effects": &"SFX", "ambience": &"Ambience", "music": &"Music"}


static func get_value(section: String, key: String) -> Variant:
	var cf := ConfigFile.new()
	cf.load(PATH)
	return cf.get_value(section, key, DEFAULTS[section][key])


static func set_value(section: String, key: String, v: Variant) -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value(section, key, v)
	cf.save(PATH)


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


## Names of the HUD styles on the Settings row (ClassicSkin.STYLES).
const HUD_STYLE_NAMES := {"classic": "Classic", "minimal": "Minimal"}


## "HUD style  Classic / Minimal": the word is a button that turns to the other; the choice is kept ([hud] style) and a
## game's HUD (`player`'s, the pause menu's) changes at once (FrontierHUD.apply_style).
static func hud_style_row(player: Node = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.name = "HudStyle"
	h.add_theme_constant_override("separation", 18)
	var l := MenuUI.label("HUD style", 20, MenuUI.INK)
	l.custom_minimum_size = Vector2(230, 0)
	h.add_child(l)
	var b := Button.new()
	b.name = "Style"
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", FrontierHUD.serif())
	b.add_theme_font_size_override("font_size", 20)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, MenuUI.GOLD)
	var hint := MenuUI.label("", 16, MenuUI.FAINT)
	var paint := func(s: String) -> void:
		b.text = String(HUD_STYLE_NAMES.get(s, s.capitalize()))
		b.set_meta(&"style", s)
		hint.text = "frames, a minimap, a chat log" if s == ClassicSkin.CLASSIC else "lettering over the world"
	var cur := String(get_value("hud", "style"))
	paint.call(cur if cur in ClassicSkin.STYLES else ClassicSkin.CLASSIC)
	b.pressed.connect(func() -> void:
		var s := ClassicSkin.MINIMAL if String(b.get_meta(&"style")) == ClassicSkin.CLASSIC else ClassicSkin.CLASSIC
		set_value("hud", "style", s)
		paint.call(s)
		var hud: Variant = player.get("hud") if player != null else null
		if hud is FrontierHUD:
			(hud as FrontierHUD).apply_style(s))
	h.add_child(b)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(hint)
	return h


## The Settings rows (for a menu's sub-screen): volumes, the mouse, invert, fullscreen, vsync. `player` gets the
## controls' changes at once (the pause menu's), null from the main menu.
static func rows(player: Node = null) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	var pct := func(x: float) -> String: return "%d%%" % roundi(x * 100.0)
	for k: Array in [["master", "Volume"], ["effects", "Effects"], ["ambience", "The woods"], ["music", "Music"]]:
		var key := String(k[0])
		v.add_child(MenuUI.slider(String(k[1]), 0.0, 1.0, 0.05, float(get_value("audio", key)), pct, func(x: float) -> void:
			set_value("audio", key, x)
			apply_global()))
	v.add_child(MenuUI.slider("Mouse", 0.5, 6.0, 0.1, float(get_value("controls", "mouse")),
			func(x: float) -> String: return "%.1f" % x, func(x: float) -> void:
				set_value("controls", "mouse", x)
				if player:
					player.set("cs_sensitivity", x)))
	v.add_child(MenuUI.toggle("Invert the look", bool(get_value("controls", "invert_y")), func(on: bool) -> void:
		set_value("controls", "invert_y", on)
		if player:
			player.set("invert_y", on)))
	v.add_child(MenuUI.toggle("Full screen", bool(get_value("display", "fullscreen")), func(on: bool) -> void:
		set_value("display", "fullscreen", on)
		apply_global()))
	v.add_child(MenuUI.toggle("Vertical sync", bool(get_value("display", "vsync")), func(on: bool) -> void:
		set_value("display", "vsync", on)
		apply_global()))
	v.add_child(MenuUI.toggle("Cap at 60 frames a second (cooler, quieter)", bool(get_value("display", "cap_60")), func(on: bool) -> void:
		set_value("display", "cap_60", on)
		apply_global()))
	v.add_child(hud_style_row(player))
	if player == null:
		# (chosen before a game, not in the middle of one)
		v.add_child(MenuUI.toggle("Iron Man: injuries stay", bool(get_value("game", "iron_man")), func(on: bool) -> void:
			set_value("game", "iron_man", on)))
	v.add_child(MenuUI.label("Graphics: F2 in the game.", 16, MenuUI.FAINT))
	return v
