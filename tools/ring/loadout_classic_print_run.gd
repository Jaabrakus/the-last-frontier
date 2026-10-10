extends SceneTree
## Writes Classic's fingerprint (tools/ring/loadout_classic_print.gd) of the code checked out now, headless, in the ring scene:
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/ring/loadout_classic_print_run.gd -- out=<file.json>
## It names nothing the loadouts added, so it runs on the code before them (c0a631a0^) as well: that is how
## tests/ring/fixtures/loadout_classic_golden.json was made (see tests/ring/test_loadout_classic.gd). Ends "CLASSIC PRINT WRITTEN".

const PRINT := preload("res://tools/ring/loadout_classic_print.gd")


func _initialize() -> void:
	seed(1750)
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("CLASSIC PRINT FAILED (watchdog)")
		quit(2))
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = "fire"
	MatchSetup.foes = ["fire"]
	MatchSetup.round_s = 60.0
	MatchSetup.rounds_to_win = 1
	MatchSetup.difficulty = "normal"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _run() -> void:
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			path = a.trim_prefix("out=")
	for i in 20:
		await process_frame
	var lvl := current_scene as RingLevel
	var mode := RingMode.find(self)
	if lvl == null or lvl.player == null or mode == null or mode.foe == null:
		print("CLASSIC PRINT FAILED (no ring)")
		quit(1)
		return
	mode.foe.held = true
	mode.foe.global_position = Vector3(0.0, 60.0, -400.0)
	await physics_frame
	var fp: Variant = PRINT.new()
	var d: Dictionary = await fp.collect(self, lvl.player)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("CLASSIC PRINT FAILED (cannot write %s)" % path)
		quit(1)
		return
	f.store_string(JSON.stringify(d, "\t", true))
	f.close()
	print("CLASSIC PRINT locks=%d picks=%d timeline=%d effects=%d" % [(d.locks as Dictionary).size(), (d.picks as Dictionary).size(),
			(d.timeline as Dictionary).size(), (d.effects as Dictionary).size()])
	print("CLASSIC PRINT WRITTEN %s" % path)
	quit(0)
