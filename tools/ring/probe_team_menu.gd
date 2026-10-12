extends SceneTree
## Probe (2026-10-11, the owner: "how come i cant play the 2v2 or 4v4 matches"): the main menu as a player meets it, headless:
## the match setup opened, the 4 v 4 chip pressed, Begin pressed; then what the ring loads (its format, a side's count).
##   Godot --headless --path . -s tools/ring/probe_team_menu.gd -- [format=4v4]
## Ends "PROBE ..." lines. Its own settings file; the player's own is never read or written.

const OWN_CFG := "user://probe_team_menu.cfg"
var fmt := "4v4"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("format="):
			fmt = a.substr(7)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	InputSetup.ensure()
	MainMenu._look_offered = true
	MainMenu.creator_hook = func(_first: bool) -> Object: return null
	change_scene_to_file("res://scenes/main_menu.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 30:
		await process_frame
	var m := current_scene as MainMenu
	if m == null:
		print("PROBE no main menu")
		return _quit()
	m._open_match()
	for i in 20:
		await process_frame
	var frm := m.find_child("Format", true, false) as BroadcastUI.Segments
	print("PROBE format chips: %s, visible %s, chips %d, rect %s" % [frm != null, frm.is_visible_in_tree() if frm else false,
			frm.chips.size() if frm else 0, frm.get_global_rect() if frm else Rect2()])
	if frm == null:
		return _quit()
	var i := MatchSetup.FORMATS.find(fmt)
	frm.picked.emit(i)
	await process_frame
	print("PROBE after the chip: MatchSetup.format %s" % MatchSetup.format)
	var begin := m.find_child("Begin", true, false) as Control
	print("PROBE begin: %s" % begin)
	if begin is BaseButton:
		(begin as BaseButton).pressed.emit()
	for k in 600:
		await process_frame
		var lvl := current_scene as RingLevel
		if lvl != null and RingMode.find(self) != null and RingMode.find(self).rules != null and RingMode.find(self).phase == "COUNTDOWN":
			for j in 30:
				await process_frame
			var mo := RingMode.find(self)
			print("PROBE ring: RingArena.format %s, MatchSetup.format %s, sides %d v %d, deck %.0f x %.0f, practice %s, quick %s" % [
					RingArena.format, MatchSetup.format, (mo.rules.sides[0] as Array).size(), (mo.rules.sides[1] as Array).size(),
					mo.ring.half_w() * 2.0, mo.ring.half_l() * 2.0, MatchSetup.practice(), MatchSetup.quick])
			return _quit()
	print("PROBE no ring match within 600 frames (scene %s)" % current_scene)
	_quit()


func _quit() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	quit(0)
