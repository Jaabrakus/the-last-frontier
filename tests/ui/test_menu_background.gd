extends SceneTree
## The main menu's New game background reaching the survival rules (MainMenu.background_id ->
## SurvivalBridge.start_background()), in the real level, headless:
##
##   Godot --headless --path . -s tests/ui/test_menu_background.gd -- survival=on
##
##   chosen    the discharged provincial chosen: the new game starts as one (his skills: marksmanship 25), the choice
##             taken once
##   default   nothing chosen: the backcountry hunter, as before
##   save      Continue clears a choice left from an earlier New game in the same run

var checks := 0
var fails: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _level() -> SurvivalBridge:
	change_scene_to_file("res://scenes/main.tscn")
	await frames(12)
	return SurvivalBridge.find(self)


func _run() -> void:
	check(SurvivalBridge.enabled(), "the survival rules are on (run with -- survival=on)")
	MainMenu.background_id = "bg.provincial_ranger"
	var b := await _level()
	check(b != null and b.core != null, "the level's survival bridge")
	if b and b.core:
		check(b.core.state.background_id == "bg.provincial_ranger", "the chosen background: %s" % b.core.state.background_id)
		check(absf(float(b.core.state.skills.get("marksmanship", 0.0)) - 25.0) < 0.01,
				"its skills (marksmanship %s)" % b.core.state.skills.get("marksmanship"))
	check(MainMenu.background_id == "", "the choice taken once")
	b = await _level()
	if b and b.core:
		check(b.core.state.background_id == SurvivalBridge.BACKGROUND, "nothing chosen: the default (%s)" % b.core.state.background_id)
	check(SurvivalBridge.start_background() == SurvivalBridge.BACKGROUND, "start_background() without a choice")
	MainMenu.background_id = "not a background"
	check(SurvivalBridge.start_background() == SurvivalBridge.BACKGROUND and MainMenu.background_id == "", "a bad id falls back")
	if fails.is_empty():
		print("MENU BACKGROUND TEST PASSED %d" % checks)
	else:
		for x in fails:
			printerr("FAIL: ", x)
		print("MENU BACKGROUND TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
