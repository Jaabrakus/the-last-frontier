extends SceneTree
## The quality when nothing asks for one (WorldSettings.default_quality; user 2026-09-28: "make run smmothely"):
##   Godot --headless --path . -s tests/world/test_quality_default.gd
##   game     a game run with no saved choice: medium (a steady 60 on the M4 Mac mini)
##   saved    the player's saved choice ([display] quality) is kept
##   tools    tool and test runs (-s): high, the look-dev spec's
## Ends with "QUALITY TEST PASSED (<n> checks)" or "QUALITY TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []


func _initialize() -> void:
	var none := "user://_quality_none.cfg"
	var saved := "user://_quality_saved.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("display", "quality", "high")
	cfg.save(saved)
	var game := PackedStringArray(["--path", "."])
	var tool := PackedStringArray(["--path", ".", "-s", "tools/x.gd"])
	_expect(WorldSettings.default_quality(game, none) == "medium", "game: no saved choice, medium")
	_expect(WorldSettings.default_quality(game, saved) == "high", "saved: the player's choice kept (high)")
	_expect(WorldSettings.default_quality(tool, saved) == "high" and WorldSettings.default_quality(tool, none) == "high",
			"tools: high whatever is saved")
	var medium := WorldSettings.preset("medium")
	_expect(not medium.sdfgi and not medium.volumetric_fog and medium.antialiasing == "metalfx",
			"medium: no global illumination or volumetric fog, MetalFX upscaling")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved))
	if fails.is_empty():
		print("QUALITY TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("QUALITY TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)
