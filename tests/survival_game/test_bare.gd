extends SceneTree
## A start with nothing (user 2026-09-28: "can the game start with the user bare and naked no tools can they obtain or
## make all the tools and weapons now"), on the level with the real player and the survival bridge, headless:
##
##   Godot --headless --path . -s tests/survival_game/test_bare.gd -- survival=on wildlife=on start=bare survival_seed=7
##
##   nothing    the new character owns nothing: an empty pack, no clothes, no coin, no torches; every weapon put down; the
##              survival kit empty; no axe, mattock, knife, flint or steel handed out, and none re-given a moment later
##   by hand    E at a patch of fieldstones, chert nodules, dead saplings, dry sticks, elm bark: stone, flint, a pole,
##              branches and bark into the pack, with no tool
##   stone      a knapping stone placed (free); its menu: cordage from bark, a flint knife, a stone axe, a bow drill,
##              a throwing spear; each made from the pack's things, taking them
##   knife      the flint knife in the pack is the field dressing's knife and the survival rules' knife (the core's kit
##              carries it: SurvivalBridge.sync_carried_tools); dropping it out of the pack takes it out of the kit
##   axe        the stone axe stands in for the felling axe (GatherTools.owns), with its own model and a stroke worth
##              under half a steel axe's; a steel felling axe out-does it
##   fire       a laid fire with only flint in the pack does not light (no steel); the bow drill lights it, in a few tries
##   spear      the throwing spear made from nothing is carried and usable
##   arms       at the stone: a self bow (a pole, a cord, the flint knife) is the player's, empty; fletched arrows (shoots,
##              a flint, feathers) fill its quiver; an atlatl and its darts the same; pine-knot torches (a branch and
##              pitch); a bone awl (an antler tine) that the survival rules take for their awl
##   clothes    at a workbench: a buckskin hunting frock, breechcloth and leggings, a fur cap of a raccoon pelt and
##              moccasins, sewn with the bone awl and the flint knife only, each put on (warmth on)
##   metal      bog iron ore and clay dug by hand; a charcoal mound fired with the bow drill chars a game day and breaks
##              open for charcoal; a forge smelts bar iron and forges a felling axe, a mattock, a belt knife, a tomahawk
##              (thrown, carried), flint and steel, a steel trap, a bullet mould, hooks and line, gun barrels and a lock;
##              a gunstock at the workbench; a musket and a pistol assembled there, the player's, empty (no powder); the
##              forged knife and axe are the rules' knife and axe (a start with nothing keeps them in step)
##   bare flag  kept in the core's flags (a save keeps it), so a new session does not hand the tools out again
## Ends with "BARE TEST OK (<n> checks)" or "BARE TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var player: FrontierPlayer
var f: ForageField
var mode: BuildMode
var spot := Vector3(-24.0, 0.0, 12.0)


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)
	else:
		print("  ok   ", what)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func count(kind: String) -> int:
	return Campfire._pack_count(player, kind)


func set_count(kind: String, n: int) -> void:
	var inv := InventoryState.from_player(player)
	var have := inv.pack_count(kind)
	if have > n:
		inv.take(kind, have - n)
	elif have < n:
		inv.add(kind, n - have)
	player.inventory_pack = inv.pack.duplicate(true)


func stand(p: Vector3) -> void:
	p.y = FrontierTerrain.height_at(p.x, p.z) + 0.05
	player.global_position = p
	player.velocity = Vector3.ZERO
	await frames(6)
	b.camp.refresh()


func place(type: String, at: Vector3) -> BuiltPiece:
	at.y = FrontierTerrain.height_at(at.x, at.z)
	await stand(at + Vector3(0, 0, 3.0))
	mode.set_active(true)
	mode.select_type(type)
	mode.aim_at = at
	for i in 6:
		await physics_frame
	mode.refresh_placement()
	var p := mode.place()
	if p == null:
		print("    place %s: %s" % [type, mode.verdict.get("reason", "-")])
	mode.set_active(false)
	mode.aim_at = Vector3.INF
	return p


func wait_work(limit := 60.0) -> void:
	var t0 := Time.get_ticks_msec()
	while (b.work.working or player.kneeling != null) and Time.get_ticks_msec() - t0 < limit * 1000.0:
		await process_frame
	await frames(4)


func tap_e() -> void:
	Input.action_press(&"interact")
	await frames(4)
	Input.action_release(&"interact")
	await frames(3)


func face(at: Vector3) -> void:
	var d := at - player.global_position
	d.y = 0.0
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw
	player.pitch = deg_to_rad(-20.0)


func nearest_patch(kind: String) -> int:
	var best := -1
	var bd := INF
	for i in f.patches.size():
		if f.patches[i].kind == kind:
			var d := Vector2(f.patches[i].pos.x, f.patches[i].pos.z).length()
			if d < bd:
				bd = d
				best = i
	return best


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(40)
	b = SurvivalBridge.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	f = ForageField.find(self)
	check(b != null and player != null and f != null, "the level has the survival bridge and the forage field (start=bare)")
	if b == null or player == null:
		_end()
		return
	player.ignore_mouse_capture = true
	mode = player.get_node_or_null("BuildMode") as BuildMode
	SurvivalWeather.set_external(b.core, "clear", 2.0, 250.0)
	await _nothing()
	check(current_scene.get_node_or_null("Wheelbarrow") == null and current_scene.find_children("*", "Horse", false, false).is_empty(), "no demo horse, cart or barrow stands by in a start with nothing")
	await process_frame
	await _by_hand()
	await _stone()
	await _knife()
	await _axe()
	await _fire()
	await _spear()
	await _arms()
	await _clothes()
	await _metal()
	_end()


func _end() -> void:
	if fails.is_empty():
		print("BARE TEST OK (%d checks)" % checks)
	else:
		print("BARE TEST FAILED %d/%d: %s" % [fails.size(), checks, str(fails)])
	quit(0 if fails.is_empty() else 1)


func _nothing() -> void:
	check(b.is_bare(), "the core says it is a start with nothing")
	var inv := InventoryState.from_player(player)
	var kinds: Array = inv.pack.map(func(e: Dictionary) -> String: return String(e.kind))
	check(inv.pack.is_empty(), "an empty pack (%s)" % str(kinds))
	check(b.core.state.inventory.is_empty() and b.core.state.worn.is_empty(), "the survival kit empty and no clothes worn")
	check(SurvivalEconomy.money(b.core) == 0 and player.torch.count() == 0, "no coin, no torches")
	var usable := player.weapons.keys().filter(func(k: String) -> bool: return player.is_usable(k))
	check(usable.is_empty(), "no weapon to draw (%s)" % str(usable))
	check(player.loadout.items.is_empty(), "nothing worn on the body's loadout")
	var kit: Array = Array(player.loadout.gear).filter(func(g: String) -> bool: return g in BareStart.KIT_GEAR)
	var horn: bool = player.gear != null and player.gear.entries.any(func(e) -> bool: return String(e.kind) == "powder_horn")
	check(kit.is_empty() and not horn, "no powder horn, shot pouch or pistol sling on the body (gear %s)" % str(player.loadout.gear))
	check(player.hands_free, "the hands are free")
	await frames(60)
	inv = InventoryState.from_player(player)
	check(inv.pack.is_empty() and not player.gather.owns("felling_axe") and not player.gather.owns("mattock"),
			"a moment later nothing has been handed out again (no axe, no mattock)")
	var fd := FieldDressing.new()
	check(count("skinning_knife") == 0 and count("fire_steel") == 0 and count("flint") == 0, "no knife, no flint and steel")
	fd.free()


## E at a patch, the real way: the player bends to it, a handful goes into the pack.
func _pick(kind: String, item: String) -> void:
	var pi := nearest_patch(kind)
	if pi < 0:
		check(false, "a patch of %s in the level" % kind)
		return
	var pl: Dictionary = f.patches[pi].plants[0]
	for q in f.patches[pi].plants:
		if float(q.stock) > 0.0:
			pl = q
			break
	var p: Vector3 = pl.pos
	var out := Vector3(-p.x, 0.0, -p.z).normalized()
	var at := p + out * 1.1
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO
	face(p)
	await frames(12)
	var have0 := count(item)
	await tap_e()
	await frames(10)
	var t := 0
	while f.picker.working and t < 120 * 14:
		await physics_frame
		t += 1
	await frames(6)
	check(count(item) > have0, "by hand: %s -> %d %s in the pack, no tool (%s)" % [kind, count(item), item, player.interactor._label.text if player.interactor else ""])


func _by_hand() -> void:
	await _pick("fieldstones", "stone")
	await _pick("flint_nodules", "flint")
	await _pick("dead_pole", "pole")
	await _pick("deadwood", "branches")
	await _pick("slippery_elm", "elm_bark")


func _stone() -> void:
	var p := await place("work_stone", spot)
	check(p != null, "a knapping stone placed with nothing (it is free)")
	var st := p.get_node_or_null("Station") as CampStation if p else null
	check(st != null and st.kind == "work_stone" and st.interact_prompt(player) == "Knap and work at the stone", "E at the stone: '%s'" % (st.interact_prompt(player) if st else "-"))
	if st == null:
		return
	await stand(st.global_position + Vector3(0, 0, 1.3))
	# what it offers with the pack's things: enough for the cord, nothing more
	set_count("elm_bark", 2)
	set_count("flint", 3)
	set_count("branches", 4)
	set_count("pole", 1)
	var rows := st.menu_rows(player)
	var ids: Array = rows.map(func(r: Dictionary) -> String: return String(r.id))
	# (the rows it has always had, and the rope belt and sling; later work (climbing gear, spears) adds more)
	var core_rows := ["cordage_bark", "rope_belt", "rope_sling", "flint_knife", "stone_axe", "bow_drill", "bone_awl", "torch", "digging_stick",
			"cornmeal", "bow", "atlatl", "arrows", "spear", "darts"]
	check(core_rows.all(func(x: String) -> bool: return ids.has(x)), "the stone's menu has its rows and the rope belt and sling: %s" % str(ids))
	var ok: Dictionary = {}
	for r: Dictionary in rows:
		ok[String(r.id)] = bool(r.ok)
	check(ok.cordage_bark and ok.spear and not ok.flint_knife and not ok.stone_axe and not ok.bow_drill and not ok.bone_awl
			and not ok.torch and not ok.bow and not ok.atlatl and not ok.arrows and not ok.darts,
			"with bark, flint, branches and a pole: cord and a spear can be made, the rest need cord, a knife, pitch or a bow (%s)" % str(ok))
	check(st.make(player, "cordage_bark") and b.work.working, "cordage from bark: twisting")
	await wait_work()
	check(count("cordage") == 2 and count("elm_bark") == 0, "2 lengths of cordage from 2 bark (%d cordage)" % count("cordage"))
	check(st.make(player, "flint_knife"), "a flint knife")
	await wait_work()
	check(count("flint_knife") == 1 and count("flint") == 2 and count("branches") == 3 and count("cordage") == 1,
			"the knife made: a flint, a branch and a cord taken (%s)" % st.last.get("text", ""))
	set_count("cordage", 2)
	check(st.make(player, "stone_axe"), "a stone axe")
	await wait_work()
	check(count("stone_axe") == 1 and count("flint") == 0 and count("pole") == 0 and count("cordage") == 1,
			"the axe made: 2 flints, a pole and a cord taken (%s)" % st.last.get("text", ""))
	set_count("branches", 3)
	check(st.make(player, "bow_drill"), "a bow drill")
	await wait_work()
	check(count("bow_drill") == 1 and count("branches") == 1 and count("cordage") == 0, "the drill made: 2 branches and a cord taken")
	var stopped := false
	set_count("elm_bark", 2)
	st.make(player, "cordage_bark")
	await frames(10)
	b.work.stop()
	await wait_work()
	stopped = count("elm_bark") == 2 and count("cordage") == 0
	check(stopped, "stopped part way: the bark comes back, no cord")
	set_count("elm_bark", 0)


func _knife() -> void:
	b.sync_carried_tools()
	check(SurvivalInventory.count(b.core, "item.tool.flint_knife") >= 1.0, "the flint knife is in the survival kit while carried")
	var fd: FieldDressing = null
	for n in get_nodes_in_group(&"field_dressing"):
		fd = n
	if fd == null:
		for n in current_scene.find_children("*", "FieldDressing", true, false):
			fd = n
	check(fd != null and fd.has_knife(), "the field dressing has a knife")
	# a rules job that asks for a knife: skin a carcass
	var cid := SurvivalCamp.add_carcass(b.core, "marten", {"source": "trap", "location": "test"})
	b.set_context({"location": "test"})
	var r := b.core.start_job("fur.skin", {"carcass_id": cid})
	check(bool(r.get("ok", false)), "the rules let a marten be skinned with it (%s)" % str(r.get("reasons", "")))
	if bool(r.get("ok", false)):
		b.core.cancel_job("test")
	# out of the pack, out of the kit
	var was := count("flint_knife")
	set_count("flint_knife", 0)
	b.sync_carried_tools()
	check(SurvivalInventory.count(b.core, "item.tool.flint_knife") == 0.0, "put out of the pack: out of the kit too")
	var r2 := b.core.start_job("fur.skin", {"carcass_id": cid})
	check(not bool(r2.get("ok", false)), "and no knife: no skinning")
	if bool(r2.get("ok", false)):
		b.core.cancel_job("test")
	set_count("flint_knife", was)
	b.sync_carried_tools()


func _axe() -> void:
	var g := player.gather
	check(count("stone_axe") == 1 and g.owns("felling_axe") and g.stone_only(), "the stone axe stands in for the felling axe")
	check(absf(g.stroke_mult("felling_axe") - 0.45) < 0.001 and g.stroke_mult("mattock") == 1.0,
			"a stone stroke is worth %.2f of a steel axe's" % g.stroke_mult("felling_axe"))
	g.take_out("felling_axe")
	await frames(30)
	check(g.tool == "felling_axe" and g._model_hand_kind == "stone_axe" and g._model_hand != null and g._model_hand.name == "StoneAxe",
			"drawn: the stone axe's own model (%s)" % g._model_hand_kind)
	g.put_away()
	await frames(60)
	# a steel one out-does it
	set_count("felling_axe", 1)
	check(not g.stone_only() and g.stroke_mult("felling_axe") == 1.0, "with a steel felling axe too: the steel one's bite")
	set_count("felling_axe", 0)
	check(g.stone_only(), "and without it again: the stone one")
	# the rules' axe for a deadfall
	check(SurvivalInventory.count(b.core, "item.tool.stone_axe") >= 1.0, "the rules' kit carries it (a deadfall wants an axe)")


func _fire() -> void:
	var p := await place("campfire", spot + Vector3(-3.0, 0, 0))
	check(p == null, "a campfire needs 6 stone and 4 firewood: none in the pack, none placed")
	set_count("stone", 6)
	set_count("firewood", 8)
	p = await place("campfire", spot + Vector3(-3.0, 0, 0))
	check(p != null, "a campfire ring laid from the fieldstones and the fallen limbs")
	var fire := p.get_node_or_null("Campfire") as Campfire if p else null
	if fire == null:
		return
	await stand(fire.global_position + Vector3(0, 0, 1.4))
	fire.interact(player)
	fire.interact(player)
	fire.interact(player)
	fire.interact(player)
	await frames(6)
	check(not fire.is_lit() and fire.fuel_min() > 0.0, "the fire laid, cold")
	# flint alone is no striker without steel
	set_count("flint", 2)
	set_count("bow_drill", 0)
	check(fire.interact_prompt(player).begins_with("Light the fire (needs"), "flint alone does not light it: '%s'" % fire.interact_prompt(player))
	fire.interact(player)
	await frames(6)
	check(not fire.is_lit(), "and E does nothing with flint alone")
	# the bow drill
	set_count("flint", 0)
	set_count("bow_drill", 1)
	check(fire.interact_prompt(player) == "Light the fire with the bow drill", "with the drill: '%s'" % fire.interact_prompt(player))
	var lvl := SurvivalSkills.level(b.core, "survival")
	var p0 := fire.drill_chance(b)
	check(p0 > 0.3 and p0 < 0.95, "the chance to catch is %.0f%% at Survival %.0f" % [p0 * 100.0, lvl])
	var tries := 0
	while not fire.is_lit() and tries < 14:
		tries += 1
		await stand(fire.global_position + Vector3(0, 0, 1.4))
		fire.interact(player)
		await frames(6)
		check(b.work.working if tries == 1 else true, "twirling the drill (try %d)" % tries)
		await wait_work(30.0)
	check(fire.is_lit(), "the coal caught and the fire is lit after %d tries" % tries)
	check(count("bow_drill") == 1, "the drill is not used up")
	check(SurvivalSkills.level(b.core, "survival") > lvl, "each try is practice: Survival %.2f -> %.2f" % [lvl, SurvivalSkills.level(b.core, "survival")])
	# steel and flint still light it at once
	fire.smother()
	await frames(6)
	set_count("fire_steel", 1)
	check(fire.interact_prompt(player) == "Light the fire" or fire.interact_prompt(player).begins_with("Lay firewood") or fire.interact_prompt(player).begins_with("Add"),
			"with steel: '%s'" % fire.interact_prompt(player))
	set_count("fire_steel", 0)


func _spear() -> void:
	# the throwing spear made from nothing at the stone: a pole and a chert point
	var st: CampStation = null
	for n in get_nodes_in_group(&"camp_stations"):
		if n is CampStation and (n as CampStation).kind == "work_stone":
			st = n
	if st == null:
		check(false, "the knapping stone stands")
		return
	await stand(st.global_position + Vector3(0, 0, 1.3))
	set_count("pole", 1)
	set_count("flint", 1)
	check(not player.is_usable("spear") and not player.is_carried("spear"), "no spear yet")
	check(st.make(player, "spear"), "a throwing spear made at the stone")
	await wait_work()
	check(player.is_carried("spear") and player.is_usable("spear"), "the spear is the player's and can be thrown (%s)" % st.last.get("text", ""))
	check(count("pole") == 0 and count("flint") == 0, "the pole and the chert point taken")
	# arrows want a bow: none made from nothing yet
	set_count("branches", 2)
	set_count("flint", 1)
	var rows := st.menu_rows(player)
	check(rows.size() >= 15, "the stone's menu still has its rows (farming: the digging stick, cornmeal; rope: a belt, a sling): %d" % rows.size())
	# the bare flag stays in the core's flags (the survival save)
	var doc := SurvivalSave.to_document(b.core)
	var core2 := SurvivalSave.from_document(doc)
	check(core2 != null and bool(core2.state.flags.get("bare_start", false)), "the start-with-nothing flag is in the survival save")


func _arms() -> void:
	var st: CampStation = null
	for n in get_nodes_in_group(&"camp_stations"):
		if n is CampStation and (n as CampStation).kind == "work_stone":
			st = n
	if st == null:
		return
	await stand(st.global_position + Vector3(0, 0, 1.3))
	var bow := player.weapons.get("bow") as Bow
	check(not player.is_carried("bow"), "no bow yet")
	set_count("pole", 1)
	set_count("sinew", 0)
	set_count("cordage", 1)
	check(st.make(player, "bow"), "a self bow: a sapling pole and a cord for its string")
	await wait_work()
	check(player.is_carried("bow") and bow.quiver == 0 and count("pole") == 0 and count("cordage") == 0,
			"the bow is the player's, its quiver empty (%s)" % st.last.get("text", ""))
	set_count("shoots", 2)
	set_count("flint", 1)
	set_count("feathers", 1)
	check(st.make(player, "arrows"), "fletched arrows")
	await wait_work()
	check(bow.quiver == 6 and player.is_usable("bow") and count("shoots") == 0 and count("feathers") == 0,
			"6 arrows in the quiver: the bow can be drawn (%d)" % bow.quiver)
	var atl := player.weapons.get("atlatl") as Throwable
	set_count("branches", 1)
	set_count("antler", 0)
	set_count("cordage", 1)
	check(st.make(player, "atlatl"), "an atlatl: a branch and a cord-lashed spur")
	await wait_work()
	check(player.is_carried("atlatl") and atl.count == 0 and not player.is_usable("atlatl"), "the atlatl is the player's, no darts yet")
	set_count("shoots", 2)
	set_count("flint", 1)
	set_count("feathers", 1)
	check(st.make(player, "darts"), "darts for it")
	await wait_work()
	check(atl.count == 2 and player.is_usable("atlatl"), "2 darts: it can be thrown (%d)" % atl.count)
	set_count("branches", 1)
	set_count("pine_pitch", 1)
	var t0 := player.torch.count()
	check(st.make(player, "torch"), "pine-knot torches")
	await wait_work()
	check(player.torch.count() == t0 + 2 and count("pine_pitch") == 0, "2 torches in the pack (%d)" % player.torch.count())
	set_count("antler", 1)
	check(st.make(player, "bone_awl"), "a bone awl from an antler tine")
	await wait_work()
	b.sync_carried_tools()
	check(count("bone_awl") == 1 and SurvivalInventory.count(b.core, "item.tool.bone_awl") >= 1.0, "the awl in the pack and the rules' kit")


func _clothes() -> void:
	set_count("log", 2)
	set_count("pole", 2)
	var p := await place("workbench", spot + Vector3(5.0, 0, 3.0))
	check(p != null, "a workbench built (2 logs, 2 poles)")
	var st := p.get_node_or_null("Station") as CampStation if p else null
	if st == null:
		return
	await stand(st.global_position + Vector3(0, 0, 1.3))
	b.core.state.needs["stomach"] = 2000.0
	var ins0 := float(SurvivalNeeds.env(b.core).ins_eff)
	for pair: Array in [["rcp.hunting_frock", "item.cloth.hunting_frock"], ["rcp.leggings_skin", "item.cloth.leggings_buckskin"], ["rcp.fur_cap", "item.cloth.fur_cap"],
			["rcp.moccasins", "item.cloth.moccasins"]]:
		var got := false
		for i in 6:
			set_count("buckskin", 1)
			set_count("sinew", 1)
			set_count("raccoon_pelt", 1)
			if not st.make(player, String(pair[0])):
				check(false, "%s starts (%s)" % [pair[0], str(st.menu_rows(player).filter(func(r: Dictionary) -> bool: return String(r.id) == String(pair[0])))])
				break
			await wait_work()
			if SurvivalInventory.count(b.core, String(pair[1])) >= 1.0:
				got = true
				break
			print("    (try %d: %s)" % [i + 1, st.last.get("text", "")])
		check(got and b.core.state.worn.has(String(pair[1])), "%s sewn and worn: '%s'" % [pair[1], st.last.get("text", "")])
	var ins1 := float(SurvivalNeeds.env(b.core).ins_eff)
	check(ins1 >= ins0 + 5.0, "dressed from nothing: insulation %.1f -> %.1f" % [ins0, ins1])
	check(SurvivalInventory.count(b.core, "item.tool.awl") == 0.0, "(with no trade awl in the kit: the bone awl did it)")


func _station_of(p: BuiltPiece) -> CampStation:
	return p.get_node_or_null("Station") as CampStation if p else null


func _make(st: CampStation, id: String, what: String) -> bool:
	await stand(st.global_position + Vector3(0, 0, 1.4))
	var ok := st.make(player, id)
	check(ok, "%s: started" % what)
	await wait_work()
	return ok


func _metal() -> void:
	await _pick("bog_ore", "bog_iron")
	await _pick("clay_bank", "clay")
	# the charcoal mound: 8 firewood, a clay; fired with the drill; a game day; broken open
	set_count("firewood", 8)
	set_count("clay", 1)
	var mp := await place("charcoal_mound", spot + Vector3(-6.0, 0, 6.0))
	var mound := _station_of(mp)
	check(mound != null and mound.kind == "charcoal_mound", "a charcoal mound laid (8 firewood, a clay)")
	if mound == null:
		return
	await stand(mound.global_position + Vector3(0, 0, 1.8))
	set_count("bow_drill", 1)
	set_count("fire_steel", 0)
	set_count("flint", 0)
	check(mound.interact_prompt(player) == "Fire the charcoal mound with the bow drill", "E at the mound: '%s'" % mound.interact_prompt(player))
	var tries := 0
	while mound.mound_state() == "" and tries < 14:
		tries += 1
		await stand(mound.global_position + Vector3(0, 0, 1.8))
		mound.interact(player)
		await frames(6)
		await wait_work(30.0)
	check(mound.mound_state() == "burning", "fired with the drill after %d tries" % tries)
	await frames(40)
	check(mound.get_node_or_null("Charring") != null, "its smoke rises from the chimney")
	check(mound.interact_prompt(player).begins_with("The mound is charring: ready in"), "charring: '%s'" % mound.interact_prompt(player))
	b.core.advance(CampStation.CHAR_MIN + 5.0)
	await frames(6)
	check(mound.mound_state() == "done" and mound.interact_prompt(player).begins_with("Break open the mound"), "a game day on: '%s'" % mound.interact_prompt(player))
	mound.interact(player)
	await frames(6)
	check(count("charcoal") == CampStation.CHAR_YIELD and not is_instance_valid(mp) or mp.is_queued_for_deletion() or not mp.is_inside_tree(),
			"broken open: %d charcoal, the mound gone" % count("charcoal"))
	# the forge
	set_count("stone", 10)
	set_count("clay", 3)
	set_count("log", 1)
	set_count("rawhide", 1)
	var fp := await place("forge", spot + Vector3(8.0, 0, -4.0))
	var forge := _station_of(fp)
	check(forge != null and forge.kind == "forge", "a forge built (10 stone, 3 clay, a log, a rawhide for the bellows)")
	if forge == null:
		return
	var rows := forge.menu_rows(player)
	check(rows.map(func(r: Dictionary) -> String: return String(r.id)) == CampStation.FORGE.keys(), "the forge's menu: %s" % str(rows.map(func(r: Dictionary) -> String: return String(r.text))))
	set_count("bog_iron", 3)
	set_count("charcoal", 4)
	if await _make(forge, "bar_iron", "smelting"):
		check(count("bar_iron") == 1 and count("bog_iron") == 0 and count("charcoal") == 0, "3 bog ore and 4 charcoal: a bar of iron")
	var wants := {"felling_axe": "felling_axe", "mattock": "mattock", "skinning_knife": "skinning_knife", "fire_steel": "fire_steel",
			"steel_trap": "steel_trap", "bullet_mould": "bullet_mould", "hooks_line": "hooks_line", "gun_barrel": "gun_barrel",
			"pistol_barrel": "pistol_barrel", "gunlock": "gunlock"}
	for id: String in wants:
		var g: Dictionary = CampStation.FORGE[id]
		for k: String in g.inputs:
			set_count(k, int(g.inputs[k]) + count(k) * 0)
		for k: String in g.inputs:
			set_count(k, int(g.inputs[k]))
		var have := count(String(wants[id]))
		if await _make(forge, id, String(g.text)):
			check(count(String(wants[id])) == have + 1, "forged: %s (%s)" % [g.text, forge.last.get("text", "")])
	# a second lock for the pistol
	set_count("bar_iron", 2)
	set_count("charcoal", 2)
	await _make(forge, "gunlock", "a second lock")
	var tom := player.weapons.get("tomahawk") as Throwable
	check(not player.is_carried("tomahawk"), "no tomahawk yet")
	set_count("bar_iron", 1)
	set_count("charcoal", 1)
	set_count("branches", 1)
	await _make(forge, "tomahawk", "a tomahawk")
	check(player.is_carried("tomahawk") and tom.count == 1 and player.is_usable("tomahawk"), "the tomahawk is the player's, to throw (%d)" % tom.count)
	# the steel tools are the rules' and the gathering's
	b.sync_carried_tools()
	check(SurvivalInventory.count(b.core, "item.tool.knife") >= 1.0 and SurvivalInventory.count(b.core, "item.tool.axe") >= 1.0,
			"the forged knife and axe are the rules' knife and axe")
	check(player.gather.owns("felling_axe") and not player.gather.stone_only() and player.gather.stroke_mult("felling_axe") == 1.0,
			"the steel felling axe bites full (the stone one stays behind)")
	check(player.gather.owns("mattock"), "the mattock breaks stone")
	var fd: FieldDressing = null
	for n in current_scene.find_children("*", "FieldDressing", true, false):
		fd = n
	check(fd != null and fd.has_knife(), "the belt knife skins")
	# guns: a stock at the workbench, then a musket and a pistol assembled there
	var bench: CampStation = null
	for n in get_nodes_in_group(&"camp_stations"):
		if n is CampStation and (n as CampStation).kind == "workbench":
			bench = n
	if bench == null:
		check(false, "the workbench stands")
		return
	set_count("log", 2)
	await _make(bench, "gunstock", "a gunstock")
	await _make(bench, "gunstock", "a second gunstock")
	check(count("gunstock") == 2, "2 gunstocks carved (%d)" % count("gunstock"))
	check(not player.is_carried("musket") and not player.is_carried("pistol"), "no gun yet")
	var ids: Array = bench.menu_rows(player).map(func(r: Dictionary) -> String: return String(r.id))
	check(ids.has("musket") and ids.has("pistol"), "the bench offers a musket and a pistol")
	await _make(bench, "musket", "a musket")
	var musket := player.weapons.get("musket") as Firearm
	check(player.is_carried("musket") and musket.reserve == 0 and not musket.loaded, "the musket is the player's, empty (%s)" % bench.last.get("text", ""))
	await _make(bench, "pistol", "a pistol")
	check(player.is_carried("pistol"), "the pistol is the player's")
	check(count("gun_barrel") == 0 and count("pistol_barrel") == 0 and count("gunlock") == 0 and count("gunstock") == 0, "the parts used")
