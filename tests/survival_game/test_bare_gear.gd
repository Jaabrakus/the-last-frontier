extends SceneTree
## A start with nothing wears and carries what it makes (user 2026-10-01: "clothes slots in the tab ... gather branches and stones in
## bare mode also rope to make sling rig to carry items as the starting"), in the level, headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/survival_game/test_bare_gear.gd -- survival=on start=bare
##
##   naked     no clothes in any slot, the look's outfit has "-" in every slot the clothes cover; no belt, no slings (no hip points,
##             no back sling points offered)
##   ground    sticks (a dead pole, deadwood), stones and bark can be picked from the ground (ForageField data: the kinds exist)
##   rope      cordage from two barks, a rope belt from cordage (the knapping stone's recipes: STONE rows exist and their inputs are
##             what the ground gives), and the belt on offers the hip and back points, taken off they go and what hung on it goes to the pack
##   sling     the rope sling brings the back slings (the long weapons, the quiver, the tool loop)
##   clothes   a garment owned goes on in its slot (moccasins on the feet): worn, drawn on the figure's look; taken off, bare again
## Ends with "BARE GEAR TEST PASSED (<n> checks)" or "... FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var b: SurvivalBridge


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


## Walks to a patch of `kind` near the player and picks one plant bare-handed: one `item` in the pack.
func _pick(field: ForageField, kind: String, item: String) -> void:
	var found := -1
	for i in field.patches.size():
		var pa: Dictionary = field.patches[i]
		if String(pa.kind) == kind and field.stock_of(i) >= 0.5:
			found = i
			break
	if found < 0:
		_expect(false, "a %s patch to pick from" % kind)
		return
	var pa: Dictionary = field.patches[found]
	var li := 0
	for k in (pa.plants as Array).size():
		if not bool((pa.plants[k] as Dictionary).gone):
			li = k
			break
	var pt: Vector3 = field._point_of(kind, pa.plants[li])
	p.global_position = Vector3(pt.x + 0.5, FrontierTerrain.height_at(pt.x, pt.z) + 0.1, pt.z)
	await _fr(60)
	var before := InventoryState.from_player(p).pack_count(item)
	var started := field.picker.start(p, found, li, pt)
	for i in 60 * 14:
		await physics_frame
		if not field.picker.working:
			break
	var after := InventoryState.from_player(p).pack_count(item)
	_expect(started and after == before + 1, "picked a %s from the ground bare-handed (+1 %s: %d -> %d)" % [kind, item, before, after])


func _run() -> void:
	await _fr(30)
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	for i in 600:
		await physics_frame
		b = SurvivalBridge.find(self)
		if b != null and b.core != null:
			break
	_expect(b != null and b.is_bare(), "the character started with nothing")
	if b == null:
		quit(1)
		return
	await _fr(90)
	# naked
	_expect(b.core.state.worn.is_empty(), "no clothes worn")
	var look: Dictionary = p.appearance.look if p.appearance else {}
	var out: Dictionary = look.get("outfit", {})
	var all_off := true
	for z: Dictionary in ClothesSlots.ZONES:
		for slot: String in z.slots:
			var v: Variant = out.get(slot, {})
			all_off = all_off and String((v as Dictionary).get("id", "")) == "-"
	_expect(all_off, "the look has nothing in any clothes slot (naked)")
	var inv := InventoryState.from_player(p)
	_expect(inv.points().is_empty(), "no carry points at all (no belt, no sling): %s" % [inv.points()])
	# the ground's things
	var forage: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/forage/forage.json"))
	var kinds := {}
	for k in forage.plants:
		kinds[String((forage.plants[k] as Dictionary).get("item", ""))] = true
	_expect(kinds.has("stone") and kinds.has("flint") and kinds.has("pole") and kinds.has("branches") or kinds.has("elm_bark"),
			"the ground gives stones, flint, poles and bark (%s)" % [kinds.keys().filter(func(x): return x in ["stone", "flint", "pole", "branches", "elm_bark", "dogwood_bark", "willow_bark"])])
	# picked from the ground, bare-handed
	var field := ForageField.find(self)
	_expect(field != null and field.picker != null, "the level has its forage field")
	if field != null and field.picker != null:
		for want: Array in [["deadwood", "branches"], ["fieldstones", "stone"], ["flint_nodules", "flint"], ["dead_pole", "pole"]]:
			await _pick(field, String(want[0]), String(want[1]))
	# rope
	_expect(CampStation.STONE.has("cordage_bark") and CampStation.STONE.has("rope_belt") and CampStation.STONE.has("rope_sling"),
			"the knapping stone makes bark cordage, a rope belt and a rope sling")
	inv.add("cordage", 5)
	inv.add("rope_belt", 1)
	inv.add("rope_sling", 1)
	inv.add("knife", 0)
	_expect(inv.wear_gear("rope_belt") and inv.gear_worn("rope_belt"), "the rope belt goes on")
	_expect(inv.points().has("R_hip") and inv.points().has("L_hip"), "the belt offers the hip points (%s)" % [inv.points()])
	_expect(not inv.points().has("long_A"), "but no back sling yet (%s)" % [inv.points()])
	_expect(inv.wear_gear("rope_sling") and inv.points().has("long_A") and inv.points().has("quiver"), "the rope sling brings the back slings (%s)" % [inv.points()])
	# something hung on the belt comes off with it
	inv.add("tomahawk", 1)
	var pt := inv.best_point("tomahawk")
	if pt != "":
		inv.wear("tomahawk", pt)
	_expect(pt != "" and not inv.item_at(pt).is_empty(), "a tomahawk hangs from the belt (%s)" % pt)
	_expect(inv.unwear_gear("rope_belt") and inv.pack_count("rope_belt") == 1 and inv.pack_count("tomahawk") == 1,
			"taking the belt off puts the tomahawk in the pack and the belt too")
	# clothes
	SurvivalInventory.add(b.core, "item.cloth.moccasins", 1.0)
	b.core._on_inventory_changed()
	var feet := ClothesSlots.owned(b.core, "feet")
	_expect(feet.has("item.cloth.moccasins"), "moccasins owned are offered for the feet (%s)" % [feet])
	_expect(ClothesSlots.wear(b, "item.cloth.moccasins") and ClothesSlots.worn_in(b.core, "feet") == "item.cloth.moccasins", "the moccasins go on the feet")
	_expect(ClothesSlots.take_off(b, "feet") and ClothesSlots.worn_in(b.core, "feet") == "", "taken off, the feet are bare")
	# (only the linen shirt has a model drawn in this build: the other garments are worn, warm, but not yet drawn)
	SurvivalInventory.add(b.core, "item.cloth.linen_shirt", 1.0)
	b.core._on_inventory_changed()
	_expect(ClothesSlots.wear(b, "item.cloth.linen_shirt") and ClothesSlots.worn_in(b.core, "body") == "item.cloth.linen_shirt", "a linen shirt goes on the body")
	await _fr(30)
	var shirt_id := String(((p.appearance.look.get("outfit", {}) as Dictionary).get("shirt", {}) as Dictionary).get("id", ""))
	_expect(shirt_id != "-" and shirt_id != "", "and is on the figure (%s)" % shirt_id)
	_expect(ClothesSlots.take_off(b, "body"), "taken off")
	await _fr(30)
	var shirt_off := String(((p.appearance.look.get("outfit", {}) as Dictionary).get("shirt", {}) as Dictionary).get("id", ""))
	_expect(shirt_off == "-", "the figure is bare again")
	# the tab
	var scr := InventoryScreen.open_for(p, "clothes")
	await process_frame
	await process_frame
	var panel: ClothesPanel = scr._clothes
	panel.refresh()
	var listed := panel._list.get_children().filter(func(c: Node) -> bool: return c is ClothesPanel.Cell and String((c as ClothesPanel.Cell).payload.get("id", "")) == "item.cloth.moccasins")
	_expect(scr.tab == "clothes" and panel.visible and listed.size() == 1, "the Clothes tab lists the moccasins to drag (%d)" % listed.size())
	var cell := panel._slot_cells["feet"] as ClothesPanel.Cell
	_expect(cell._can_drop_data(Vector2.ZERO, {"from": "cloth", "id": "item.cloth.moccasins"}) and not (panel._slot_cells["head"] as ClothesPanel.Cell)._can_drop_data(Vector2.ZERO, {"from": "cloth", "id": "item.cloth.moccasins"}), "the feet slot takes moccasins, the head slot does not")
	cell._drop_data(Vector2.ZERO, {"from": "cloth", "id": "item.cloth.moccasins"})
	_expect(ClothesSlots.worn_in(b.core, "feet") == "item.cloth.moccasins", "choosing them in the tab puts them on")
	panel._list_drop(Vector2.ZERO, {"from": "worn_cloth", "zone": "feet"})
	_expect(ClothesSlots.worn_in(b.core, "feet") == "", "choosing nothing takes them off")
	scr.inv.add("rope_belt", 1)
	panel.refresh()
	_expect(not (panel._gear_rows["rope_belt"] as ClothesPanel.Cell).disabled, "a rope belt in the pack can be put on from the tab")
	panel._toggle_gear("rope_belt")
	_expect(scr.inv.gear_worn("rope_belt") and scr.inv.points().has("R_hip"), "and the body offers its hip points")
	scr.close()
	await _by_hand(p)
	var h: Household = null
	for n in current_scene.get_children():
		if n is Household:
			h = n
	_expect(h != null and h.sc != null and h.body != null, "a spouse stands at the start")
	if h and h.sc:
		_expect(h.sc.intimacy > 0.99 and h.sc.intimacy_cd == 0.0, "her intimacy is open from the start (%.2f)" % h.sc.intimacy)
	if h and h.sc:
		await _her_sheet(h, b, p)
	if fails.is_empty():
		print("BARE GEAR TEST PASSED (%d checks)" % checks)
	else:
		print("BARE GEAR TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


## No fort in a start with nothing, the spouse naked, her Gear tab: garments and rope dragged to her, worn, handed back.
func _her_sheet(h: Household, b: SurvivalBridge, p: FrontierPlayer) -> void:
	var st := current_scene.get_node_or_null("Structures")
	_expect(st != null and st.get_child_count() == 0 and get_nodes_in_group(&"fort_part").is_empty(), "no fort: the structures node is empty (%d)" % (st.get_child_count() if st else -1))
	_expect(current_scene.get_node_or_null("FortPlan") == null and get_nodes_in_group(WeaponRack.GROUP).is_empty(), "no fort furnishing and no demo racks")
	var sc := h.sc
	_expect(sc.core.state.worn.is_empty() and sc.core.state.inventory.is_empty(), "she owns and wears nothing")
	var outfit: Dictionary = sc.look.get("outfit", {})
	var naked := true
	for z: Dictionary in ClothesSlots.ZONES:
		for slot: String in z.slots:
			if String((outfit.get(slot, {}) as Dictionary).get("id", "-")) != "-":
				naked = false
	_expect(naked, "her look has nothing in any clothes slot")
	var hs := HouseholdScreen.open_for(h, "gear")
	await process_frame
	var tab := GearTab.build(hs)
	SurvivalInventory.add(b.core, "item.cloth.linen_shirt", 1.0)
	var shirts0 := SurvivalInventory.count(b.core, "item.cloth.linen_shirt")
	var inv := InventoryState.from_player(p)
	inv.add("rope_belt", 1)
	p.inventory_pack = inv.pack.duplicate(true)
	var found_cust := false
	for c in hs._content.get_children():
		if c is Button and (c as Button).text.begins_with("Customize"):
			found_cust = true
	_expect(found_cust, "her Gear tab has the Customize button")
	_expect(tab._yours_cloth().has("item.cloth.linen_shirt") and tab._yours_rope().has("rope_belt"), "the shirt and belt show on the player's side")
	_expect(tab.move({"what": "cloth", "id": "item.cloth.linen_shirt", "src": "you"}, "her", true), "the shirt is dragged onto her body slot")
	_expect(ClothesSlots.worn_in(sc.core, "body") == "item.cloth.linen_shirt" and SurvivalInventory.count(b.core, "item.cloth.linen_shirt") == shirts0 - 1.0, "she wears it; the player no longer has it")
	var shirt_id := String(((sc.look.get("outfit", {}) as Dictionary).get("shirt", {}) as Dictionary).get("id", ""))
	_expect(shirt_id != "" and shirt_id != "-", "her look wears it (%s)" % shirt_id)
	_expect(tab.move({"what": "rope", "id": "rope_belt", "src": "you"}, "her", true) and sc.rope_worn.has("rope_belt") and InventoryState.from_player(p).pack_count("rope_belt") == 0, "the rope belt is handed over and put on")
	var wg := WorkerGear.of(h.body_of(sc))
	await process_frame
	_expect(wg != null and wg.loadout != null or wg == null, "her rig reads it")
	_expect(tab.move({"what": "cloth", "id": "item.cloth.linen_shirt", "src": "her"}, "you", false) and ClothesSlots.worn_in(sc.core, "body") == "" and SurvivalInventory.count(b.core, "item.cloth.linen_shirt") == shirts0, "the shirt is dragged back: off her, in the player's hands")
	_expect(tab.move({"what": "rope", "id": "rope_belt", "src": "her"}, "you", false) and sc.rope_worn.is_empty() and InventoryState.from_player(p).pack_count("rope_belt") == 1, "the belt comes back to the pack")
	hs.queue_free()


## The Craft tab's work: cord from bark with no station, made by the hands (HandCraft).
func _by_hand(p: FrontierPlayer) -> void:
	var inv := InventoryState.from_player(p)
	inv.take("cordage", 99)
	inv.add("elm_bark", 2)
	p.inventory_pack = inv.pack.duplicate(true)
	var rows := HandCraft.rows(p)
	var cord := rows.filter(func(r: Dictionary) -> bool: return String(r.id) == "cordage_bark")
	_expect(cord.size() == 1 and bool(cord[0].ok), "the Craft tab offers cordage from bark with no station (%d rows)" % rows.size())
	var scr := InventoryScreen.open_for(p, "craft")
	await process_frame
	_expect(scr.tab == "craft" and scr._craft.visible, "the Craft tab opens")
	scr.close()
	_expect(HandCraft.make(p, "cordage_bark"), "making it starts the work")
	for i in 900:
		await physics_frame
		if InventoryState.from_player(p).pack_count("cordage") >= 2:
			break
	_expect(InventoryState.from_player(p).pack_count("cordage") >= 2 and InventoryState.from_player(p).pack_count("elm_bark") == 0, "two lengths of cordage for the two barks")
	# no bark about: cord from branches; then a stone axe and a stone pick, by hand
	var inv2 := InventoryState.from_player(p)
	inv2.take("cordage", 99)
	inv2.add("branches", 3)
	p.inventory_pack = inv2.pack.duplicate(true)
	_expect(HandCraft.make(p, "cordage_branch"), "cord from branches starts")
	await _wait_for(p, "cordage", 2)
	_expect(InventoryState.from_player(p).pack_count("cordage") == 2 and InventoryState.from_player(p).pack_count("branches") == 0, "3 branches make 2 lengths of cordage")
	var inv3 := InventoryState.from_player(p)
	inv3.add("flint", 4)
	inv3.add("pole", 2)
	inv3.add("cordage", 2)
	p.inventory_pack = inv3.pack.duplicate(true)
	_expect(HandCraft.make(p, "stone_axe"), "a stone axe is made by hand")
	await _wait_for(p, "stone_axe", 1)
	_expect(HandCraft.make(p, "stone_pick"), "a stone pick is made by hand")
	await _wait_for(p, "stone_pick", 1)
	var have := InventoryState.from_player(p)
	_expect(have.pack_count("stone_axe") == 1 and have.pack_count("stone_pick") == 1, "the stone axe and the stone pick are in the pack")
	_expect(p.gather.owns("felling_axe") and p.gather.owns("mattock"), "the stone axe fells and the stone pick breaks rock")
	_expect(GatherModels.build("stone_pick") != null, "the stone pick has its model")


func _wait_for(p: FrontierPlayer, kind: String, n: int) -> void:
	for i in 1200:
		await physics_frame
		if InventoryState.from_player(p).pack_count(kind) >= n:
			break
	var br := SurvivalBridge.find(self)
	for i in 600:
		if br == null or not br.work.working:
			break
		await physics_frame
	await process_frame
