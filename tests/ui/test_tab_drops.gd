extends SceneTree
## The Tab screen's figure as a drop target (InventoryScreen.body_verdict / body_drop, FigureDrop; the owner 2026-10-02:
## "drag cloths ... food we can drag onto the body of the char screen", "no more rigs on the char slots") on the real
## level, survival on, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/ui/test_tab_drops.gd -- survival=on
##
##   layout     no rig places on the figure (no slot cells, no kits); the hint under it: "Drag here to wear, eat or use"
##   wear       a garment carried dropped on the figure is worn in its slot (ClothesSlots); what was there comes off into
##              the pack (the Clothes rows list it)
##   eat        jerky dropped on the figure is eaten: the stomach fills by a unit's kcal, one less in the pack
##   refused    on a full stomach the drop is refused: the frame red, the reason under it (the survival code's own words),
##              nothing eaten; plantain at full health: "no wound to dress"
##   drink      rum dropped: a gill drunk (one bottle less, in the gut); tobacco dropped: a pipeful smoked
##   weapon     the pistol taken off the bar is in the pack list; dropped on the figure it goes in the first free slot and
##              can be drawn; one on the bar already is refused with its slot; a spell (the Spells list) the same
##   figure     the figure carries only what is on the bar (the bow off the bar: not on it)
## Ends with "TAB DROPS TEST PASSED (<n> checks)" or "TAB DROPS TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var hb: Hotbar
var b: SurvivalBridge


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	_run.call_deferred()


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _layout() -> String:
	var parts := PackedStringArray()
	for i in Hotbar.SLOTS:
		var e := hb.entry(i)
		parts.append("%d:%s" % [i + 1, "-" if e.is_empty() else String(e.id)])
	return " ".join(parts)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	await _physics(90)
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	b = SurvivalBridge.find(self)
	_expect(p != null and b != null and b.core != null, "the level has the player and the survival bridge")
	if p == null or b == null or b.core == null:
		_end()
		return
	p.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	hb = p.hotbar
	await _physics(int(Hotbar.KIT_S * Engine.physics_ticks_per_second) + 10)
	_expect(hb != null and hb.kit_placed, "the hotbar's start kit is placed (%s)" % (_layout() if hb else "no bar"))
	if hb == null:
		_end()
		return
	await _layout_checks()
	await _wear()
	await _eat()
	await _drink_smoke()
	await _weapon()
	await _spell()
	_end()


func _open() -> InventoryScreen:
	var scr := InventoryScreen.open_for(p)
	await _frames(4)
	return scr


func _close(scr: InventoryScreen) -> void:
	scr.close()
	await _frames(2)
	await _physics(4)


func _layout_checks() -> void:
	var scr: InventoryScreen = await _open()
	_expect(scr.figure != null and scr.fig_hint != null and scr.fig_hint.text == "Drag here to wear, eat or use",
			"the figure is a drop target, its hint under it (%s)" % (scr.fig_hint.text if scr.fig_hint else "none"))
	var cells := 0
	for c in scr.find_children("*", "", true, false):
		if c.get("point") != null:
			cells += 1
	_expect(cells == 0 and not ("_slot_cells" in scr) and not ("_kits_box" in scr), "no rig places on the figure, no kits (%d)" % cells)
	await _close(scr)


func _wear() -> void:
	var core := b.core
	var id := "item.cloth.hunting_frock"
	var zone := ClothesSlots.zone_of(core, id)
	if ClothesSlots.worn_in(core, zone) == id:
		id = "item.cloth.linen_shirt"
		zone = ClothesSlots.zone_of(core, id)
	SurvivalInventory.add(core, id, 1.0)
	core._on_inventory_changed()
	var there := ClothesSlots.worn_in(core, zone)
	var scr: InventoryScreen = await _open()
	var listed := false
	for r in scr._cloth_list.get_children():
		if r is InventoryScreen.ListRow and String((r as InventoryScreen.ListRow).payload.get("id", "")) == id:
			listed = true
	_expect(listed, "the garment is in the Gear tab's clothes list (%s, the %s)" % [id, zone])
	var d := {"from": "cloth", "id": id}
	_expect(scr.figure._can_drop_data(Vector2.ZERO, d) and scr.figure.state == "ok", "the figure takes it (%s)" % scr.fig_hint.text)
	scr.figure._drop_data(Vector2.ZERO, d)
	_expect(ClothesSlots.worn_in(core, zone) == id, "dropped: worn in the %s slot (%s)" % [zone, ClothesSlots.worn_in(core, zone)])
	if there != "" and there != id:
		_expect(ClothesSlots.owned(core, zone).has(there), "what was there (%s) came off into the pack" % there)
		var back := false
		for r in scr._cloth_list.get_children():
			if r is InventoryScreen.ListRow and String((r as InventoryScreen.ListRow).payload.get("id", "")) == there:
				back = true
		_expect(back, "and the clothes list shows it")
	_expect(not scr.figure._can_drop_data(Vector2.ZERO, d) and scr.figure.state == "no", "worn already: refused (%s)" % scr.fig_hint.text)
	await _close(scr)


func _eat() -> void:
	var core := b.core
	var scr: InventoryScreen = await _open()
	scr.inv.add("jerky", 3)
	core.state.needs["stomach"] = 200.0
	var n0 := scr.inv.pack_count("jerky")
	var s0 := float(core.state.needs.get("stomach", 0.0))
	var d := {"from": "pack", "kind": "jerky"}
	_expect(scr.figure._can_drop_data(Vector2.ZERO, d), "hungry: the figure takes the jerky (%s)" % scr.fig_hint.text)
	scr.figure._drop_data(Vector2.ZERO, d)
	var s1 := float(core.state.needs.get("stomach", 0.0))
	_expect(scr.inv.pack_count("jerky") == n0 - 1 and s1 > s0 + 100.0, "dropped: eaten, the stomach %.0f -> %.0f, jerky %d -> %d (%s)"
			% [s0, s1, n0, scr.inv.pack_count("jerky"), scr._msg.text])
	# refused: a full stomach
	core.state.needs["stomach"] = 2990.0
	var why := b.why_not("jerky")
	var ok := scr.figure._can_drop_data(Vector2.ZERO, d)
	var red := scr.fig_hint.get_theme_color("font_color")
	_expect(not ok and scr.figure.state == "no" and why != "" and scr.fig_hint.text == why and red.r > 0.9 and red.g < 0.6,
			"full: refused, the frame red, the reason under it (%s)" % scr.fig_hint.text)
	var n1 := scr.inv.pack_count("jerky")
	_expect(not scr.body_drop(d) and scr.inv.pack_count("jerky") == n1, "and nothing is eaten (%s)" % scr._msg.text)
	scr.figure._notification(Control.NOTIFICATION_DRAG_END)
	_expect(scr.figure.state == "" and scr.fig_hint.text == "Drag here to wear, eat or use", "the drag over: the frame and the hint back")
	# refused: a herb with no wound
	p.health = p.max_health
	scr.inv.add("plantain", 1)
	var v := scr.body_verdict({"from": "pack", "kind": "plantain"})
	_expect(not bool(v.ok) and String(v.reason).contains("no wound"), "plantain at full health: refused (%s)" % v.reason)
	core.state.needs["stomach"] = 800.0
	await _close(scr)


func _drink_smoke() -> void:
	var vc := b.vices
	if vc == null:
		print("  (no vices: drink and smoke skipped)")
		return
	var scr: InventoryScreen = await _open()
	if scr.inv.pack_count("rum") <= 0:
		scr.inv.add("rum", 1)
	var r0 := scr.inv.pack_count("rum")
	var gut0 := float(vc._st().get("gut", 0.0))
	var flask0 := float(vc._st().get("flask", 0.0))
	var d := {"from": "pack", "kind": "rum"}
	_expect(scr.figure._can_drop_data(Vector2.ZERO, d), "the figure takes the rum (%s)" % scr.fig_hint.text)
	scr.figure._drop_data(Vector2.ZERO, d)
	_expect(float(vc._st().get("gut", 0.0)) > gut0 and (scr.inv.pack_count("rum") < r0 or flask0 > 0.0),
			"dropped: a gill drunk (%s)" % scr._msg.text)
	if scr.inv.pack_count("clay_pipe") <= 0:
		scr.inv.add("clay_pipe", 1)
	if scr.inv.pack_count("tobacco") <= 0:
		scr.inv.add("tobacco", 1)
	var smoke0 := float(vc._st().get("smoke_in", 0.0))
	var t := {"from": "pack", "kind": "tobacco"}
	_expect(scr.figure._can_drop_data(Vector2.ZERO, t), "the figure takes the tobacco (%s)" % scr.fig_hint.text)
	scr.figure._drop_data(Vector2.ZERO, t)
	_expect(float(vc._st().get("smoke_in", 0.0)) > smoke0, "dropped: a pipeful smoked (%s)" % scr._msg.text)
	await _close(scr)


func _weapon() -> void:
	var pistol := hb.slot_of("weapon", "pistol")
	var bow := hb.slot_of("weapon", "bow")
	_expect(pistol >= 0 and bow >= 0, "the pistol and the bow on the bar (%s)" % _layout())
	if pistol < 0 or bow < 0:
		return
	hb.clear(pistol)
	hb.clear(bow)
	await _physics(4)
	var scr: InventoryScreen = await _open()
	var rows := scr.pack_rows().map(func(e: Dictionary) -> String: return String(e.kind))
	_expect(rows.has("pistol") and rows.has("bow"), "off the bar: the pistol and the bow are in the pack list (%s)" % str(rows))
	_expect(scr.figure_loadout().first_of_kind("bow").is_empty() and scr.figure_loadout().first_of_kind("pistol").is_empty(),
			"and the figure carries neither")
	var free := hb.first_free()
	var d := {"from": "pack", "kind": "pistol"}
	_expect(scr.figure._can_drop_data(Vector2.ZERO, d) and scr.fig_hint.text.contains("%d" % (free + 1)),
			"the figure takes the pistol: onto slot %d (%s)" % [free + 1, scr.fig_hint.text])
	scr.figure._drop_data(Vector2.ZERO, d)
	_expect(hb.slot_of("weapon", "pistol") == free and p.is_usable("pistol"), "dropped: in the first free slot, %d, drawable (%s)" % [free + 1, _layout()])
	var again := scr.body_verdict(d)
	_expect(not bool(again.ok) and String(again.reason).contains("already"), "on the bar already: refused (%s)" % again.reason)
	_expect(not scr.figure_loadout().first_of_kind("pistol").is_empty() or p.loadout.first_of_kind("pistol").is_empty(),
			"the figure carries the pistol again")
	var free2 := hb.first_free()
	scr.body_drop({"from": "pack", "kind": "bow"})
	_expect(hb.slot_of("weapon", "bow") == free2, "the bow too, in the next free slot, %d (%s)" % [free2 + 1, _layout()])
	await _close(scr)


func _spell() -> void:
	var c := SwayCaster.install(p)
	c.grant("gust")
	await _physics(4)
	_expect(hb.slot_of("spell", "gust") < 0, "a spell granted is not put on the bar (%s)" % _layout())
	var free := hb.first_free()
	if free < 0:
		hb.clear(Hotbar.SLOTS - 1)
		free = Hotbar.SLOTS - 1
	var scr: InventoryScreen = await _open()
	var listed := false
	for r in scr._spells_list.get_children():
		if r is InventoryScreen.ListRow and String((r as InventoryScreen.ListRow).payload.get("id", "")) == "gust":
			listed = true
	_expect(listed and scr._spells_head.visible, "the Spells list has gust")
	var d := {"from": "spell", "id": "gust"}
	_expect(scr.figure._can_drop_data(Vector2.ZERO, d), "the figure takes the spell (%s)" % scr.fig_hint.text)
	scr.figure._drop_data(Vector2.ZERO, d)
	_expect(hb.slot_of("spell", "gust") == free, "dropped: in the first free slot, %d (%s)" % [free + 1, _layout()])
	await _close(scr)


func _end() -> void:
	if fails.is_empty():
		print("TAB DROPS TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		print("TAB DROPS TEST FAILED (%d of %d)" % [fails.size(), checks])
		for f in fails:
			print("   - ", f)
		quit(1)
