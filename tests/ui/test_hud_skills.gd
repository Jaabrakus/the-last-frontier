extends SceneTree
## The HUD and the character screen's Skills tab (user 2026-09-26: "work on the hud elements and the char screen the
## skills tab and some icons"), on the real level with the real player:
##   HUD     health bar follows health; the slot strip outlines what is in the hands, one small line gives the
##           weapon's ammo (no item card: the user did not want it); gathering shows toasts with the item (and not the centre notice too); a level up shows a toast;
##           the compass follows the camera; the clock shows the date; F1 shows the controls; F3 the debug lines
##   Skills  K opens the character screen on Skills: 3 field and 10 frontier skill cards, each with its icon; a card
##           click shows its ladder; the developers' notes are kept out of the text; K again closes it; Tab opens Gear
##
##   Godot --headless --path . -s tests/ui/test_hud_skills.gd
## "HUD SKILLS TEST OK" and exit 0 when every check passes. Run it under a hard time limit.

var _fails: Array[String] = []
var _checks := 0
var p: FrontierPlayer


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails.append(what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		await process_frame


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	root.push_input(e)
	var r := e.duplicate() as InputEventKey
	r.pressed = false
	root.push_input(r)


## The kind of the strip's slot marked as in the hands (the gold rule under it; "" none).
func _outlined(hud: FrontierHUD) -> String:
	for box: Array in hud._slot_boxes:
		var ov: Control = box[0]
		if ov.visible and bool(ov.get_meta(&"active", false)):
			return str((box[1] as TextureRect).get_meta(&"kind", ""))
	return ""


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	for i in 150:
		await physics_frame
	p = current_scene.get_node("Player")
	p.set("ignore_mouse_capture", true)
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	await _frames(10)
	var hud: FrontierHUD = p.hud
	_check(hud != null, "the player has the HUD")

	p.health = p.max_health * 0.5
	await _frames(2)
	_check(absf(hud._health_bar.value - 0.5) < 0.01 and hud._health_text.text == str(int(ceil(p.health))), "the health bar follows health (%.2f)" % hud._health_bar.value)
	if p.weapon and p.weapon.active and not p.hands_free:
		_check(_outlined(hud) == p.weapon_key, "the slot strip outlines the weapon in the hands (%s)" % _outlined(hud))
		_check(hud._ammo.visible and hud._ammo.text.begins_with(p.weapon.ammo_text()), "one small line with its ammo (%s)" % hud._ammo.text)
	_check(hud.find_child("WeaponCard", true, false) == null, "no item card (the user: not needed)")
	_check(hud.find_children("*", "PanelContainer", true, false).is_empty(), "nothing boxed on the HUD (the user: \"those big cards are terrible\")")
	var flash := hud._edge.visible
	await _seconds(1.0)
	_check(flash and not hud._edge.visible, "a flash at the edges when hurt; no red at half health once it fades (%s, %s, hurt %.2f)" % [flash, hud._edge.visible, hud._hurt])
	p.health = p.max_health * 0.12
	await _frames(40)
	var beat := hud._edge.visible
	p.health = p.max_health * 0.5
	await _seconds(1.0)
	_check(beat and not hud._edge.visible, "low health: the red heartbeat at the edges, gone when healed")

	var g: GatherTools = p.gather
	g.take_out("felling_axe")
	var t := 0.0
	while t < 4.0 and g.in_hand() != "felling_axe":
		await physics_frame
		t += 1.0 / 60.0
	await _frames(3)
	_check(_outlined(hud) == "felling_axe" and not hud._ammo.visible, "a tool out: its slot outlined, no ammo line (%s)" % _outlined(hud))

	var n0 := hud._toasts.get_child_count()
	g.give("firewood", 2)
	await _frames(3)
	var texts := []
	for c in hud._toasts.get_children():
		texts.append(((c as Node).find_children("*", "Label", true, false)[0] as Label).text)
	_check(hud._toasts.get_child_count() == n0 + 1 and "+2 Firewood" in texts, "gathering shows a toast (%s)" % str(texts))
	for i in 10:
		await physics_frame
	var notice := ""
	if p.interactor and p.interactor.get("_notice") != null:
		notice = (p.interactor.get("_notice") as Label).text
	_check(not notice.contains("+2 Firewood"), "and not the centre notice too (%s)" % notice)
	var lv0 := g.skills.level("woodcutting")
	g.skills.set_points("woodcutting", float(lv0) + 0.999)
	g.skills.award("woodcutting", 5.0)
	await _frames(3)
	var lv1 := g.skills.level("woodcutting")
	var lvl_toasts := []
	for c in hud._toasts.get_children():
		var tx := ((c as Node).find_children("*", "Label", true, false)[0] as Label).text
		if tx.begins_with("Woodcutting"):
			lvl_toasts.append(tx)
	_check(lvl_toasts.size() == 1 and (lvl_toasts[0] as String).begins_with("Woodcutting %d" % lv1),
			"levels crossed at once show one toast, the last level (%s)" % str(lvl_toasts))

	p.yaw = 0.0
	await _frames(3)
	var h0 := hud._heading
	p.yaw = -PI * 0.5
	await _frames(3)
	var turned := absf(wrapf(hud._heading - h0, -180.0, 180.0))
	_check(absf(turned - 90.0) < 5.0, "the compass turns with the camera (%.1f deg for a quarter turn)" % turned)
	var rig: Variant = current_scene.get("environment_rig")
	if rig is EnvironmentRig and (rig as EnvironmentRig).clock_driver != null:
		_check(hud._clock.text.contains("1765"), "the clock shows the date (%s)" % hud._clock.text)
	else:
		_check(hud._clock.text == "" and not hud._clock_icon.visible, "no clock without the day and night (headless)")
	var help := hud._help_box
	_key(KEY_F1)
	await _frames(2)
	var on := help.visible
	_key(KEY_F1)
	await _frames(2)
	_check(on and not help.visible, "F1 shows and hides the controls")

	# Skills tab
	g.put_away()
	await _frames(20)
	_key(KEY_K)
	await _frames(6)
	var scr: InventoryScreen = null
	for s in root.find_children("*", "InventoryScreen", true, false):
		scr = s
	_check(scr != null and scr.tab == "skills", "K opens the character screen on Skills")
	if scr:
		var sp := scr._skills
		var field := 0
		var frontier := 0
		var icons := 0
		for k: String in sp._cards:
			if k.begins_with("s:"):
				frontier += 1
			else:
				field += 1
			for tr in (sp._cards[k] as Node).find_children("*", "TextureRect", true, false):
				if (tr as TextureRect).texture != null:
					icons += 1
		_check(field == 3 and frontier == 10, "3 field and 10 frontier skill cards (%d, %d)" % [field, frontier])
		_check(icons == 13, "each card has its icon (%d)" % icons)
		sp.select("s:hunting")
		await _frames(2)
		var dtext := ""
		for l in sp._detail.find_children("*", "Label", true, false):
			dtext += (l as Label).text + "|"
		_check(sp.selected() == "s:hunting" and dtext.contains("Hunting") and dtext.contains("Master"), "a card shows its ladder")
		var all_text := ""
		for l in sp.find_children("*", "Label", true, false):
			all_text += (l as Label).text + "\n"
		_check(not all_text.contains("scripts/") and not all_text.contains(".json") and not all_text.contains("xp."), "no developers' notes in the skills text")
		_check(SkillsPanel.player_text("Raising walls (build mode, B: scripts/building/). Each piece counts.", 1) == "Raising walls.",
				"player_text keeps the first sentence without the notes")
		_key(KEY_K)
		await _frames(6)
		_check(not is_instance_valid(scr) or scr.is_queued_for_deletion(), "K again closes it")
	await _frames(6)
	_key(KEY_TAB)
	await _frames(6)
	var gear: InventoryScreen = null
	for s in root.find_children("*", "InventoryScreen", true, false):
		gear = s
	_check(gear != null and gear.tab == "gear" and gear._gear.visible and not gear._skills.visible, "Tab opens it on Gear")
	if gear:
		gear.pick("hazelnuts")
		await _frames(2)
		_check(gear._d_name.text == "Hazelnuts" and gear._d_rows.text.contains("of a meal"), "a picked item shows what it does (%s)" % gear._d_name.text)
		gear.close()

	# what the items say (ItemInfo), each from the game's own data
	var rows_of := func(kind: String, n: int) -> String:
		var acc := ""
		for r: Array in ItemInfo.of(kind, p, n).rows:
			acc += "%s: %s [%s]\n" % r
		return acc
	var sr: String = rows_of.call("strawberries", 9)
	_check(sr.contains("Food: one handful: 1% of a meal") and sr.contains("all 9: 9%"), "strawberries: a share of a meal, one and all (%s)" % sr.strip_edges())
	var pr: String = rows_of.call("plantain", 1)
	_check(pr.contains("Heals: 15 health over 20 s"), "plantain: what the poultice heals (%s)" % pr.strip_edges())
	var ar: String = rows_of.call("acorns", 3)
	_check(ar.contains("Bitter:") and ar.contains("[warn]"), "acorns: too bitter, marked as a catch (%s)" % ar.strip_edges())
	var vr: String = rows_of.call("venison", 1)
	_check(vr.contains("Raw: 1 in 10"), "venison: the raw meat's risk (%s)" % vr.strip_edges())
	var fr: String = rows_of.call("firewood", 6)
	var burn := "2 h" if SurvivalBridge.find(self) else "1 h 40 min"     # on the survival core's clock, or real time
	_check(fr.contains("Fuel: a stick burns %s" % burn) and fr.contains("Campfire (4)"), "firewood: its burn and what it builds (%s)" % fr.strip_edges())
	var cr: String = rows_of.call("cornmeal", 2)
	_check(cr.contains("must be cooked first: F at a lit campfire makes it johnnycake"), "cornmeal: cook it at a fire (%s)" % cr.strip_edges())
	var mr: String = rows_of.call("musket", 1)
	_check(mr.contains("Damage: 120 a ball") and mr.contains("Reload:"), "the musket: damage and reload (%s)" % mr.strip_edges())
	var no_text := []
	for k: String in InventoryState.NAMES:
		var inf := ItemInfo.of(k, p, 1)
		if String(inf.tag) == "" or String(inf.text) == "":
			no_text.append(k)
	_check(no_text.is_empty(), "every pack item has a tag and a line (%s)" % str(no_text))
	var scans := []
	for k: String in ItemIcons.SCANNED:
		var sc := ItemIcons.scanned(k)
		if sc:
			scans.append(k)
			sc.free()
	_check(scans.size() == ItemIcons.SCANNED.size(), "the photoscanned icon models load (%s)" % str(scans))

	if _fails.is_empty():
		print("HUD SKILLS TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		print("HUD SKILLS TEST FAILED (%d of %d): %s" % [_fails.size(), _checks, _fails])
		quit(1)
