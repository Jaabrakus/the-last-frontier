extends SceneTree
## The classic HUD's frames (ClassicFrames, scripts/ui/hud_classic; the owner 2026-10-03: "can the hud be similar to world of
## warcraft vanilla?") on the real level with the real player, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/ui/test_hud_classic_frames.gd -- survival=on hud=classic
##
##   style     ClassicSkin.resolve_style: hud= wins, a test run is minimal, the settings file's choice, else classic
##   frames    the player frame top left, the target frame beside it, the action bar bottom centre with the renown bar
##             over it, the micro menu over the bag bar bottom right; the minimal HUD's vitals and slot strip hidden
##   health    the player frame's bar and its "50 / 100" follow the player's health; a blow lights the portrait's ring
##   motes     the Sway's motes bar shows once a caster is on him, a segment a mote (1 of 3)
##   status    well rested ("6h" under it), wet, cold and bleeding show as icons with tooltips, the good ones first
##   target    a French marine in the crosshair: the target frame shows him (hostile, his health, 40% when hurt); the
##             view off him, the frame goes; a shot landing on him (hit_listeners) shows him again as the last hit
##   bar       the action bar's nine buttons mirror the hotbar (each slot's kind, the one in the hands gold); a slot
##             emptied empties its button; a spell readied from slot 9 glows there and the lock fills over it
##   renown    "Renown: <tier>" for the faction whose standing moved last (Settlers of the valley +25: Friendly)
##   menus     six micro buttons (the quest log and the map "Coming later"); Skills opens the character screen on its
##             Skills tab, the pack its Gear tab, Settings the pause menu
## Ends with "HUD CLASSIC FRAMES TEST OK (<n> checks)" or "HUD CLASSIC FRAMES TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var player: FrontierPlayer
var hud: FrontierHUD
var fr: ClassicFrames


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


func secs(s: float) -> void:
	var t := Time.get_ticks_msec() + int(s * 1000.0)
	var f := 0
	while Time.get_ticks_msec() < t or f < int(s * 30.0):
		await process_frame
		f += 1


func _run() -> void:
	_test_style()
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
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	fr = hud.classic
	check(fr != null, "hud=classic: the classic frames are on the HUD")
	if fr == null:
		_end()
		return
	await _test_frames()
	await _test_health()
	await _test_motes()
	await _test_status()
	await _test_target()
	await _test_bar()
	await _test_renown()
	await _test_menus()
	_end()


func _test_style() -> void:
	var none := "user://_no_such_settings.cfg"
	check(ClassicSkin.resolve_style(PackedStringArray(["hud=minimal"]), PackedStringArray(), none) == "minimal", "hud=minimal: minimal")
	check(ClassicSkin.resolve_style(PackedStringArray(["hud=classic"]), PackedStringArray(["-s", "x.gd"]), none) == "classic",
			"hud=classic in a test run: classic")
	check(ClassicSkin.resolve_style(PackedStringArray(), PackedStringArray(["-s", "x.gd"]), none) == "minimal",
			"a test run without hud=: minimal (the minimal HUD's tests as they were)")
	check(ClassicSkin.resolve_style(PackedStringArray(), PackedStringArray(), none) == "classic", "the game with no setting: classic")
	var p := "user://_hud_style_test.cfg"
	ClassicSkin.set_style("minimal", p)
	check(ClassicSkin.resolve_style(PackedStringArray(), PackedStringArray(), p) == "minimal", "the setting minimal: minimal")
	ClassicSkin.set_style("classic", p)
	check(ClassicSkin.resolve_style(PackedStringArray(), PackedStringArray(), p) == "classic", "the setting classic: classic")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _test_frames() -> void:
	await settle(4)
	var vp := fr.get_viewport_rect().size
	var pf := fr.player_frame.get_global_rect()
	check(fr.player_frame.is_visible_in_tree() and pf.position.x < 40.0 and pf.position.y < 40.0,
			"the player frame top left (%s)" % pf)
	var tf := fr.target_frame.get_global_rect()
	check(absf(tf.position.y - pf.position.y) < 1.0 and tf.position.x >= pf.end.x, "the target frame beside it (%s)" % tf)
	var ab := fr.action_bar.get_global_rect()
	check(fr.action_bar.is_visible_in_tree() and absf(ab.get_center().x - vp.x * 0.5) < 2.0 and vp.y - ab.end.y < 12.0,
			"the action bar bottom centre (%s in %s)" % [ab, vp])
	var rb := fr.renown.get_global_rect()
	check(fr.renown.is_visible_in_tree() and rb.end.y <= ab.position.y + fr.action_bar.plate.position.y + 0.5
			and absf(rb.get_center().x - ab.get_center().x) < 2.0, "the renown bar over it (%s)" % rb)
	var mm := fr.micro.get_global_rect()
	var bb := fr.bags.get_global_rect()
	check(fr.micro.is_visible_in_tree() and fr.bags.is_visible_in_tree() and vp.x - bb.end.x < 20.0 and vp.y - bb.end.y < 12.0
			and mm.end.y <= bb.position.y and vp.x - mm.end.x < 20.0, "the micro menu over the bag bar bottom right (%s, %s)" % [mm, bb])
	var vit := hud._root.get_node(^"Vitals") as Control
	check(not vit.visible and not hud._slots_box.visible, "the minimal HUD's vitals and slot strip are hidden")


func _test_health() -> void:
	player.health = player.max_health
	await secs(0.3)
	player.health = player.max_health * 0.5
	await secs(0.3)
	var pf := fr.player_frame
	check(absf(pf.health_frac - 0.5) < 0.01 and pf.health_text == "50 / 100", "the health bar follows health (%.2f, \"%s\")" % [pf.health_frac, pf.health_text])
	check(pf.portrait.hurt > 0.0, "the blow lights the portrait's ring (%.2f)" % pf.portrait.hurt)
	check(pf.portrait.texture == null or DisplayServer.get_name() != "headless", "headless: the portrait's stand-in")
	player.health = player.max_health
	await secs(0.2)
	check(pf.health_text == "100 / 100", "healed: \"100 / 100\"")


func _test_motes() -> void:
	var c := SwayCaster.install(player)
	c.set_motes(1)
	await secs(0.3)
	var pf := fr.player_frame
	check(pf.motes_shown and pf.motes == 1 and pf.belt_max == c.belt_max, "the motes bar: 1 of %d (%s %d/%d)" % [c.belt_max, pf.motes_shown, pf.motes, pf.belt_max])
	c.set_motes(c.belt_max)
	await secs(0.2)
	check(pf.motes == c.belt_max, "a full belt: %d" % pf.motes)


func _test_status() -> void:
	var core := b.core
	core.state.flags["well_rested_until"] = core.state.minutes + 6.0 * 60.0
	core.state.needs["wetness"] = 100.0
	core.state.needs["warmth"] = 12.0
	player.wounds.pool = 25.0
	await secs(0.7)
	var pf := fr.player_frame
	var ids := pf.status_ids()
	check("rested" in ids and pf.status("rested").duration == "6h", "well rested: its icon, \"6h\" under it (%s, %s)" % [ids, pf.status("rested").duration])
	check("wet" in ids and pf.status("wet").sev == 2, "soaked: the wet icon, red (%s)" % str(ids))
	check("cold" in ids and pf.status("cold").sev >= 1, "cold: its icon (%s)" % str(ids))
	check("bleeding" in ids, "bleeding: its icon (%s)" % str(ids))
	var tips := true
	for id: String in ids:
		tips = tips and pf.status(id).tooltip_text.length() > 4
	check(tips, "every icon has its tooltip (%s)" % pf.status("bleeding").tooltip_text.replace("\n", " / "))
	check(ids.find("rested") < ids.find("bleeding"), "the good ones first (%s)" % str(ids))
	core.state.flags.erase("well_rested_until")
	core.state.needs["wetness"] = 0.0
	core.state.needs["warmth"] = 100.0
	player.wounds.pool = 0.0
	player.health = player.max_health
	await secs(0.7)
	ids = pf.status_ids()
	check(not "rested" in ids and not "wet" in ids and not "bleeding" in ids, "all well again: those go (%s)" % str(ids))


func _ground(x: float, z: float) -> Vector3:
	var h := FrontierTerrain.height_at(x, z)
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, h + 3.0, z), Vector3(x, h - 3.0, z), 1, [player.get_rid()])
	var hit := (current_scene as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else Vector3(x, h, z)


## The view on a point (the yaw and pitch toward it from the camera).
func _look_at(p: Vector3) -> void:
	await settle(1)
	for i in 3:
		var cam := player.get_viewport().get_camera_3d()
		var d := p - cam.global_position
		player.yaw = atan2(-d.x, -d.z)
		player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		await settle(2)


func _test_target() -> void:
	var pp := player.global_position
	var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var at := _ground(pp.x + fwd.x * 9.0, pp.z + fwd.z * 9.0)
	var sq := NpcSquad.spawn(current_scene, "french_marine", 1, at, {"face": pp, "seed": 5})
	var f: NpcFighter = null
	for i in 60:
		await process_frame
		for n in get_nodes_in_group(NpcFighter.GROUP):
			if n is NpcFighter and (n as NpcFighter).squad == sq:
				f = n
		if f != null:
			break
	check(f != null, "a French marine 9 m off")
	if f == null:
		return
	await settle(4)
	f.set_physics_process(false)          # (he stands: no notice, no shot; his body still in the world)
	f.set_process(false)
	await _look_at(f.global_position + Vector3(0, 1.2, 0))
	await secs(0.4)
	var tf := fr.target_frame
	check(fr.target == f and fr.target_why == "aim" and tf.visible, "in the crosshair: the target frame shows him (%s, %s)" % [fr.target, fr.target_why])
	check(String(tf.info.get("name", "")) == "French marine" and String(tf.info.get("stance", "")) == "hostile",
			"his name, hostile (%s)" % str(tf.info))
	check(absf(tf.health_frac - 1.0) < 0.01, "his health: full (%.2f)" % tf.health_frac)
	f.health = f.health_max * 0.4
	await secs(0.3)
	check(absf(tf.health_frac - 0.4) < 0.01, "hurt: 40%% (%.2f)" % tf.health_frac)
	# the view off him, up into the sky: the frame goes (after the hold)
	player.pitch = deg_to_rad(70.0)
	await secs(ClassicFrames.RAY_KEEP_S + 0.6)
	check(fr.target != f and (fr.target == null or fr.target_why != "aim"), "the view off him: not the target (%s %s)" % [fr.target, fr.target_why])
	# a shot lands on him: the last hit
	var body := f.find_children("*", "CollisionObject3D", true, false)
	call_group("hit_listeners", "on_projectile_hit", body[0] if not body.is_empty() else f, f.global_position)
	await secs(0.2)
	check(fr.target == f and fr.target_why == "hit" and tf.visible, "a shot on him: the last hit shows (%s)" % fr.target_why)
	check(ClassicTargetFrame.describe(f).caption == "French marine" or String(ClassicTargetFrame.describe(f).caption) == "Hostile",
			"his caption (%s)" % ClassicTargetFrame.describe(f).caption)
	var horse: Node = null
	for n in current_scene.find_children("*", "Horse", true, false):
		horse = n
		break
	if horse != null:
		var d := ClassicTargetFrame.describe(horse)
		check(String(d.kind) == "horse" and String(d.stance) == "friendly", "a horse: friendly, its horseshoe (%s)" % str(d))
	fr._hit = null
	f.queue_free()
	player.pitch = 0.0
	await secs(0.5)


func _bar_kinds() -> Array:
	var out := []
	for btn: ClassicActionBar.ActionButton in fr.action_bar.buttons:
		out.append(btn.kind)
	return out


func _on_index() -> int:
	for btn: ClassicActionBar.ActionButton in fr.action_bar.buttons:
		if btn.on:
			return btn.index
	return -1


func _test_bar() -> void:
	var hb := player.hotbar
	check(fr.action_bar.buttons.size() == 9, "nine buttons")
	await secs(0.3)
	var want := []
	for i in Hotbar.SLOTS:
		want.append(hb.icon_kind(i))
	check(_bar_kinds() == want, "each button the hotbar's slot (%s)" % str(_bar_kinds()))
	check(_on_index() == hb.selected(), "the one in the hands gold (%d / %d)" % [_on_index(), hb.selected()])
	# another slot taken in hand
	var other := -1
	for i in Hotbar.SLOTS:
		if hb.filled(i) and i != hb.selected() and String(hb.entry(i).kind) == Hotbar.WEAPON:
			other = i
			break
	if other >= 0:
		hb.select(other)
		var t := 0.0
		while t < 4.0 and hb.selected() != other:
			await secs(0.1)
			t += 0.1
		await secs(0.3)
		check(_on_index() == other and hb.selected() == other, "slot %d taken in hand: its button gold (%d)" % [other + 1, _on_index()])
	# a slot emptied
	var last := -1
	for i in range(Hotbar.SLOTS - 1, -1, -1):
		if hb.filled(i) and i != hb.selected():
			last = i
			break
	if last >= 0:
		var e := hb.entry(last).duplicate()
		hb.clear(last)
		await secs(0.3)
		check(fr.action_bar.buttons[last].kind == "", "slot %d emptied: an empty socket" % (last + 1))
		hb.assign(last, e)
		await secs(0.3)
		check(fr.action_bar.buttons[last].kind == hb.icon_kind(last), "put back: its button again")
	# a spell from slot 9: it glows; the lock fills over it
	var c := SwayCaster.install(player)
	c.grant("gust", false)
	hb.assign(8, Hotbar.make(Hotbar.SPELL, "gust"))
	hb.select(8)
	await secs(0.4)
	var btn := fr.action_bar.buttons[8]
	check(btn.kind == "spell:gust" and btn.glow and hb.spell == "gust", "Gust readied from slot 9: its button glows (%s %s)" % [btn.kind, btn.glow])
	c.set_physics_process(false)
	c.state = SwayCaster.State.LOCKING
	c.move = "gust"
	c.fill = 0.5
	await secs(0.3)
	check(absf(btn.lock - 0.5) < 0.01, "the lock half full: half its sweep over the button (%.2f)" % btn.lock)
	c.fill = 0.8
	await settle(2)
	check(absf(btn.lock - 0.8) < 0.01, "and it fills every frame (%.2f)" % btn.lock)
	c.state = SwayCaster.State.IDLE
	c.fill = 0.0
	c.set_physics_process(true)
	await secs(0.3)
	check(btn.lock < 0.0, "the lock over: no sweep")
	hb.select(8)
	await secs(0.3)
	check(not btn.glow, "put down: no glow")


func _test_renown() -> void:
	await secs(1.2)
	var r := fr.renown
	check(r.label.begins_with("Renown: "), "the renown bar: \"%s\"" % r.label)
	SurvivalEconomy.add_standing(b.core, "faction.settlers_valley", 25.0)
	await secs(1.3)
	check(r.faction == "faction.settlers_valley" and r.label.begins_with("Renown: Friendly") and r.label.contains("Settlers of the valley"),
			"the settlers +25: \"%s\"" % r.label)
	check(r.tooltip_text.contains("Settlers of the valley"), "its tooltip lists the factions (%s)" % r.tooltip_text.replace("\n", " / "))


func _test_menus() -> void:
	var m := fr.micro
	var ids := []
	for btn in m.buttons:
		ids.append(btn.id)
	check(ids == ["character", "spells", "skills", "quests", "map", "settings"], "six micro buttons (%s)" % str(ids))
	check(m.button("quests").later and m.button("quests").tooltip_text.contains("later") and m.button("map").later,
			"the quest log and the map: coming later (%s)" % m.button("quests").tooltip_text.replace("\n", " / "))
	check(m.button("skills").tooltip_text.begins_with("Skills  (K)"), "Skills  (K)")
	m.button("skills").press()
	await settle(3)
	var s: Variant = player.get("_inv_screen")
	check(is_instance_valid(s) and s is InventoryScreen and (s as InventoryScreen).tab == "skills", "Skills opens the character screen on Skills")
	if is_instance_valid(s) and s is InventoryScreen:
		(s as InventoryScreen).close()
	await settle(4)
	fr.bags.pack.press()
	await settle(3)
	s = player.get("_inv_screen")
	check(is_instance_valid(s) and s is InventoryScreen and (s as InventoryScreen).tab == "gear", "the pack opens the Gear tab")
	if is_instance_valid(s) and s is InventoryScreen:
		(s as InventoryScreen).close()
	await settle(4)
	check(fr.bags.buttons.size() == 5 and fr.bags.pack.tooltip_text.begins_with("Pack  (Tab)"), "four bags and the pack (%s)" % fr.bags.pack.tooltip_text.replace("\n", " / "))
	var pm := current_scene.find_child("PauseMenu", false, false) as PauseMenu
	if pm != null:
		paused = false
		m.button("settings").press()
		await settle(2)
		check(pm.is_open(), "Settings opens the pause menu's settings")
		pm.close()
		await settle(2)


func _end() -> void:
	if fails.is_empty():
		print("HUD CLASSIC FRAMES TEST OK (%d checks)" % checks)
	else:
		print("HUD CLASSIC FRAMES TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
