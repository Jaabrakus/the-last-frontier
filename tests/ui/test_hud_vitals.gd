extends SceneTree
## The HUD's vitals, bottom left (FrontierHUD; user 2026-09-27: "i like the right more actually and a blue bar under it
## for rested the other badges users can look in the tab to find"), on the level with the survival bridge, headless:
##
##   Godot --headless --path . -s tests/ui/test_hud_vitals.gd -- survival=on survival_seed=7
##
##   one        the health bar is the only vitals: no row of round badges, the old panel shown
##   rested     a blue bar under the health bar, lined up with it: the boost's hours left, full at eight hours slept; an
##              empty dim track when not rested
##   cap        what a lasting harm holds the health under is shaded at the bar's end (chilled 70%, festering 60%)
##   layout     the rows in order (health, rested, torch), the F1 hint clear above them
##   no rules   without the survival bridge the rested bar and the shade go
## Ends with "HUD VITALS TEST OK (<n> checks)" or "HUD VITALS TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var player: FrontierPlayer
var hud: FrontierHUD


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)
	else:
		print("  ok   ", what)


func settle(n := 3) -> void:
	for i in n:
		await process_frame
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await settle(20)
	b = SurvivalBridge.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	hud = player.hud if player else null
	check(b != null and hud != null, "the level has the bridge (survival=on) and the HUD")
	if b == null or hud == null:
		_end()
		return
	player.ignore_mouse_capture = true
	await _test_one()
	await _test_rested()
	await _test_cap()
	await _test_layout()
	await _test_no_rules()
	_end()


func _test_one() -> void:
	check(root.find_children("*", "SurvivalHud", true, false).is_empty() and b.get_node_or_null("SurvivalHud") == null,
			"no row of round badges")
	var vit := hud.find_child("Vitals", true, false) as Control
	check(vit != null and vit.is_visible_in_tree(), "the health bar panel is shown")


func _test_rested() -> void:
	b.core.state.flags.erase("well_rested_until")
	await settle(2)
	check(hud._rest_row.visible and hud._rest_bar.value == 0.0 and hud._rest_text.text == "" and hud._rest_row.modulate.a < 0.6,
			"not rested: the empty track, dimmed (%.2f, \"%s\")" % [hud._rest_bar.value, hud._rest_text.text])
	b.core.state.flags["well_rested_until"] = b.core.state.minutes + 6.0 * 60.0
	await settle(2)
	check(absf(hud._rest_bar.value - 0.5) < 0.02 and hud._rest_text.text == "6 h" and hud._rest_row.modulate.a == 1.0,
			"six hours of the boost: half the bar, \"6 h\" (%.2f, \"%s\")" % [hud._rest_bar.value, hud._rest_text.text])
	var fill := hud._rest_bar.get_theme_stylebox("fill") as StyleBoxFlat
	check(fill.bg_color.b > fill.bg_color.r + 0.3, "the rested bar is blue")
	b.core.state.flags["well_rested_until"] = b.core.state.minutes + 20.0 * 60.0
	await settle(2)
	check(hud._rest_bar.value == 1.0, "a long good sleep: full")
	var hb := hud._health_bar.get_global_rect()
	var rb := hud._rest_bar.get_global_rect()
	check(absf(hb.position.x - rb.position.x) < 1.0 and absf(hb.size.x - rb.size.x) < 1.0 and rb.position.y > hb.end.y,
			"under the health bar, lined up with it (%s / %s)" % [hb, rb])


func _test_cap() -> void:
	b.chill.state()["on"] = false
	for id in LastingConditions.IDS:
		b.lasting.state(id)["on"] = false
	await settle(2)
	check(not hud._cap_bar.visible, "nothing lasting: no shade")
	b.chill.state()["on"] = true
	await settle(2)
	check(hud._cap_bar.visible and absf(hud._cap_bar.value - (1.0 - LastingChill.HEALTH_CAP)) < 0.01,
			"chilled to the bone: the last 30%% shaded (%.2f)" % hud._cap_bar.value)
	b.lasting.state("festering")["on"] = true
	await settle(2)
	check(absf(hud._cap_bar.value - (1.0 - LastingConditions.FESTER_CAP)) < 0.01,
			"festering as well: the lower cap, 40%% shaded (%.2f)" % hud._cap_bar.value)
	b.chill.state()["on"] = false
	b.lasting.state("festering")["on"] = false
	await settle(2)
	check(not hud._cap_bar.visible, "both mended: the shade goes")


func _test_layout() -> void:
	var vit := hud.find_child("Vitals", true, false) as Control
	var order := []
	for c in vit.get_children():
		order.append(c)
	check(order.size() == 3 and order[1] == hud._rest_row and order[2] == hud._torch_row, "health, rested, the torch, in that order")
	var hint := hud._help_hint.get_global_rect()
	check(hint.end.y <= vit.get_global_rect().position.y + 0.5,
			"the F1 hint clear above them (%.0f / %.0f)" % [hint.end.y, vit.get_global_rect().position.y])


func _test_no_rules() -> void:
	b.core.state.flags["well_rested_until"] = b.core.state.minutes + 6.0 * 60.0
	b.chill.state()["on"] = true
	await settle(2)
	b.remove_from_group(SurvivalBridge.GROUP)      # (as the game with survival=off: no bridge to find)
	await settle(2)
	check(not hud._rest_row.visible and not hud._cap_bar.visible, "no survival rules: no rested bar, no shade")
	var vit := hud.find_child("Vitals", true, false) as Control
	check(vit.is_visible_in_tree() and hud._health_bar.is_visible_in_tree(), "the health bar stays")


func _end() -> void:
	if fails.is_empty():
		print("HUD VITALS TEST OK (%d checks)" % checks)
	else:
		print("HUD VITALS TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
