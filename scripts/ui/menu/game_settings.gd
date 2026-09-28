class_name GameSettings
extends RefCounted
## The menus' settings (the main menu's and the pause menu's Settings), kept in user://settings.cfg beside the
## graphics panel's [graphics] section (read, changed and written back whole: its keys are kept):
##   [audio]     master, effects, ambience (0..1 of full volume; the buses SFX and Ambience once Sfx has made them)
##   [controls]  mouse (the look's sensitivity, FrontierPlayer.cs_sensitivity), invert_y
##   [display]   fullscreen, vsync
## The level applies them to its player and buses (FrontierLevel: apply_to(player) after its audio is set up).

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"audio": {"master": 1.0, "effects": 1.0, "ambience": 1.0},
	"controls": {"mouse": 2.0, "invert_y": false},
	"display": {"fullscreen": false, "vsync": true},
}
const BUSES := {"master": &"Master", "effects": &"SFX", "ambience": &"Ambience"}


static func get_value(section: String, key: String) -> Variant:
	var cf := ConfigFile.new()
	cf.load(PATH)
	return cf.get_value(section, key, DEFAULTS[section][key])


static func set_value(section: String, key: String, v: Variant) -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value(section, key, v)
	cf.save(PATH)


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


## The look's sensitivity and invert onto the player, and the rest (apply_global).
static func apply_to(player: Node) -> void:
	apply_global()
	if player == null:
		return
	player.set("cs_sensitivity", float(get_value("controls", "mouse")))
	player.set("invert_y", bool(get_value("controls", "invert_y")))


## The Settings rows (for a menu's sub-screen): volumes, the mouse, invert, fullscreen, vsync. `player` gets the
## controls' changes at once (the pause menu's), null from the main menu.
static func rows(player: Node = null) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	var pct := func(x: float) -> String: return "%d%%" % roundi(x * 100.0)
	for k: Array in [["master", "Volume"], ["effects", "Effects"], ["ambience", "The woods"]]:
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
	v.add_child(MenuUI.label("Graphics: F2 in the game.", 16, MenuUI.FAINT))
	return v
