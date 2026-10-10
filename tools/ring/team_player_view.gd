extends SceneTree
## A team format's match as its player sees it (the owner, 2026-10-10: "we need it Triple AAA quality"; the audit's shots): the
## window itself with the HUD, at the countdown, into the fight, after the player's first fall, and the match screen at the end.
## The player stands idle (no input): the bots of both sides play round him; after his last life, the spectator camera. Windowed (a normal window, never on top):
##   Godot --path . --resolution 1600x900 -s tools/ring/team_player_view.gd -- format=4v4 out=<dir> [round_s=45]
## Writes <dir>/view_<format>_<moment>.png. Ends with TEAM VIEW DONE.

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const OWN_CFG := "user://team_player_view.cfg"

var out := "user://team_player_view"
var fmt := "4v4"


func _initialize() -> void:
	var a := CaptureKit.args({"format": "4v4", "out": out})
	fmt = String(a["format"]) if String(a["format"]) in MatchSetup.FORMATS else "4v4"
	out = String(a["out"])
	CaptureKit.window()
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.set_match()
	MatchSetup.format = fmt
	MatchSetup.element = "earth"
	MatchSetup.foes = ["fire"]
	MatchSetup.mates = []
	MatchSetup.light = "noon"
	MatchSetup.games_n = 1
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 4:
		await process_frame
	var lvl := current_scene as RingLevel
	var loaded: bool = lvl != null and await CaptureKit.wait_loaded(self, lvl)
	var mode := RingMode.find(self)
	if not loaded or mode == null:
		print("TEAM VIEW FAILED: no match")
		return _quit(1)
	await CaptureKit.until(self, func() -> bool: return mode.phase == "COUNTDOWN" and mode.phase_t > 1.2, 20.0)
	await _shot("countdown")
	await CaptureKit.until(self, func() -> bool: return mode.phase == "FIGHT" and mode.phase_t > 6.0, 30.0)
	await _shot("fight")
	var fell := [false]
	mode.rules.ko.connect(func(b: Node3D, _by: Node, _p: float, _t: String, _l: int) -> void:
		if b == lvl.player:
			fell[0] = true)
	await CaptureKit.until(self, func() -> bool: return fell[0], 60.0)
	await CaptureKit.secs(self, 1.0)
	await _shot("player_fell")
	await CaptureKit.until(self, func() -> bool: return mode.phase == "FIGHT" and mode.phase_t > 30.0, 60.0)
	await _shot("fight_later")
	# (out of lives: the team format's spectator camera, RingSpectate)
	await CaptureKit.until(self, func() -> bool: return mode.rules.is_gone(lvl.player) or mode.phase == "DONE", 150.0)
	if mode.phase != "DONE":
		await CaptureKit.secs(self, 2.5)
		await _shot("spectating")
	await CaptureKit.until(self, func() -> bool: return mode.phase == "DONE", 120.0)
	await CaptureKit.secs(self, 2.5)
	await _shot("done")
	print("TEAM VIEW DONE")
	_quit(0)


func _shot(moment: String) -> void:
	await CaptureKit.drawn(self)
	var img := root.get_texture().get_image()
	print("  shot ", CaptureKit.save(img, out, "view_%s_%s" % [fmt, moment]))


func _quit(code: int) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	quit(code)
