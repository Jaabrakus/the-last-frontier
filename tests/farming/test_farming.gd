extends SceneTree
## Farming end to end in the real level (scripts/farming, FarmField): hoe open ground into a bed, sow the Three Sisters
## (E), weeds, hoe them out, ripen, harvest (E), frost, frozen ground, the digging stick, the recipes, the food.
##
##   Godot --path . -s tests/farming/test_farming.gd -- --no-creator survival=on [shots=<dir>]
##
## Windowed (the hoe's strokes are the real swings); shots=<dir> also saves pictures of the bed as it grows.
var failures := PackedStringArray()
var player: FrontierPlayer
var farm: FarmField
var g: GatherTools

func _ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c: failures.append(what)

func _frames(n: int) -> void:
	for i in n: await process_frame

func _secs(s: float) -> void:
	await create_timer(s).timeout

func _shot(name: String) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--").begins_with("shots="):
			dir = a.get_slice("=", 1)
	if dir == "" or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir.path_join(name + ".png"))

func _count(kind: String) -> int:
	return InventoryState.from_player(player).pack_count(kind)

func _give(kind: String, n: int) -> void:
	var inv := InventoryState.from_player(player)
	inv.add(kind, n)
	player.inventory_pack = inv.pack.duplicate(true)

func _take_all(kind: String) -> void:
	var inv := InventoryState.from_player(player)
	inv.take(kind, inv.pack_count(kind))
	player.inventory_pack = inv.pack.duplicate(true)

## Stands the player 1.3 m south of the bed's middle, facing it.
func _face_bed(i: int, j: int) -> void:
	var c := farm.center_of(i, j)
	var at := c + Vector3(0, 0, 1.45)
	player.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.05, at.z)
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	player.rotation.y = 0.0
	player.pitch = -0.35

func _swing_until(cond: Callable, max_s: float) -> float:
	var t0 := Time.get_ticks_msec()
	Input.action_press(&"fire")
	while not bool(cond.call()) and (Time.get_ticks_msec() - t0) / 1000.0 < max_s:
		await process_frame
	Input.action_release(&"fire")
	return (Time.get_ticks_msec() - t0) / 1000.0

func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	await _frames(120)
	farm = FarmField.find(self)
	g = player.gather
	_ok(farm != null and g != null, "the farm and the tools are in the level")
	var b := SurvivalBridge.find(self)
	var core: SurvivalCore = b.core if b else null
	_ok(core != null, "the survival core runs (the clock)")
	if core == null:
		print("FARM FAILED (no core: run with the user arg survival=on)")
		quit(1)
		return
	print("   date: ", SurvivalClock.date_string(core), "  day id ", SurvivalClock.day_id(core))
	# the seed pouch of a new character
	await _secs(1.0)
	_ok(_count("seed_corn") == 6 and _count("seed_beans") == 6 and _count("seed_squash") == 4 and _count("seed_tobacco") == 3 and _count("seed_flax") == 4,
			"a new character has the seed pouch (corn 6, beans 6, squash 4, tobacco 3, flax 4)")
	_ok(not g.owns("hoe"), "no hoe at the start (it is crafted)")
	_ok(CampStation.FORGE.has("hoe") and CampStation.STONE.has("digging_stick") and "digging_stick" in CampStation.STONE_AT_BENCH, "the hoe is forged, the digging stick made at the stone or the bench")
	_ok(CampStation.STONE.has("cornmeal") and CampStation.GEAR.has("cordage_flax") and CampStation.GEAR.has("tobacco"), "corn pounds into meal, flax into cord, leaves into tobacco")
	_give("hoe", 1)
	await _frames(5)
	_ok(g.owns("hoe") and g.stroke_mult("hoe") == 1.0, "with a hoe in the pack the player owns it")
	# find open ground near the fort's gate, outside
	var spot := Vector2i(999, 999)
	for r in range(6, 40):
		for di in range(-r, r + 1):
			for dj: int in [-r, r]:
				var ci := di
				var cj := -12 + dj
				if spot.x == 999 and farm.ground_ok(ci, cj):
					spot = Vector2i(ci, cj)
		if spot.x != 999:
			break
	_ok(spot.x != 999, "open ground found for a bed at cell %s" % spot)
	var key := FarmField.key_of(spot.x, spot.y)
	_face_bed(spot.x, spot.y)
	await _frames(10)
	g.take_out("hoe")
	var t0 := Time.get_ticks_msec()
	while g.in_hand() != "hoe" and Time.get_ticks_msec() - t0 < 6000:
		await process_frame
	await _secs(0.8)
	_ok(g.in_hand() == "hoe", "the hoe is drawn (key 7's cycle includes it)")
	print("   target: ", g.target.get("type", "-"), " key ", g.target.get("key", "-"), "  prompt: ", g.prompt())
	_ok(String(g.target.get("type", "")) == "ground" and String(g.target.get("key", "")) == key, "the ground in front is the hoe's target")
	var took := await _swing_until(func() -> bool: return farm.state_of(key) == "tilled", 25.0)
	print("   broke ground in ", snappedf(took, 0.1), " s")
	_ok(farm.state_of(key) == "tilled", "hoe strokes break the ground into a worked bed")
	_ok(g.skills.points_of("husbandry") > 0.0, "Husbandry grows from the hoe (%.2f points)" % g.skills.points_of("husbandry"))
	await _shot("farm_tilled")
	# sow with E
	g.put_away()
	await _secs(1.5)
	await _frames(5)
	print("   E offer: ", farm.interact_prompt(player))
	var acts := farm.interact_actions(player)
	print("   hold-E list: ", acts.map(func(a): return a.text))
	_ok(farm.interact_prompt(player).begins_with("Sow corn, beans and squash"), "E on the worked bed offers the Three Sisters first")
	_ok(acts.size() == 6, "hold E lists every sowing the pack has seed for")
	farm.interact(player)
	await _secs(6.0)
	_ok(String(farm.beds[key].sow) == "three_sisters", "E sows the Three Sisters (the work bar, then sown)")
	_ok(_count("seed_corn") == 5 and _count("seed_beans") == 5 and _count("seed_squash") == 3, "a seed of each came out of the pack")
	# growth on the core's clock
	var grow := float(farm.data.sowings.three_sisters.grow_days) * 1440.0
	farm.beds[key]["sown"] = farm.now_min() - grow * 0.4
	await _secs(1.2)
	_ok(farm.state_of(key) == "growing" and farm.stage_of(key) == 1 and farm.weeds_due(key) == 1, "40% grown: young plants, and the first weeds are up")
	print("   growing line: ", farm.interact_prompt(player))
	await _shot("farm_young")
	g.take_out("hoe")
	t0 = Time.get_ticks_msec()
	while g.in_hand() != "hoe" and Time.get_ticks_msec() - t0 < 6000:
		await process_frame
	await _secs(0.6)
	print("   weeding prompt: ", g.prompt())
	await _swing_until(func() -> bool: return int(farm.beds[key].get("hoed", 0)) >= 1, 20.0)
	_ok(int(farm.beds[key].hoed) == 1 and farm.weeds_due(key) == 0, "the hoe takes the weeds out")
	g.put_away()
	await _secs(1.5)
	farm.beds[key]["sown"] = farm.now_min() - grow * 0.8
	await _secs(1.2)
	_ok(farm.stage_of(key) == 2 and farm.weeds_due(key) == 1, "80%: grown, the second weeds up")
	await _shot("farm_grown")
	farm.beds[key]["sown"] = farm.now_min() - grow * 1.01
	await _secs(1.2)
	_ok(farm.state_of(key) == "ripe", "ripe after its grow days")
	await _shot("farm_ripe")
	var before := {"corn": _count("corn"), "beans": _count("beans"), "squash": _count("squash"), "seed_corn": _count("seed_corn")}
	await _frames(5)
	print("   ripe offer: ", farm.interact_prompt(player))
	farm.interact(player)
	await _secs(7.0)
	var got := {"corn": _count("corn") - int(before.corn), "beans": _count("beans") - int(before.beans), "squash": _count("squash") - int(before.squash),
			"seed_corn": _count("seed_corn") - int(before.seed_corn)}
	print("   harvest: ", got)
	_ok(int(got.corn) >= 3 and int(got.beans) >= 1 and int(got.squash) >= 1 and int(got.seed_corn) >= 1, "the harvest: corn, beans and squash into the pack, and seed saved back")
	_ok(farm.state_of(key) == "tilled", "the bed is worked ground again, ready to sow")
	print("   husbandry level ", g.skills.level("husbandry"), " (", snappedf(g.skills.points_of("husbandry"), 0.01), " points)")
	# frost
	# a late sowing: late October, and the frost comes before it is ripe
	core.state.minutes = SurvivalClock.minutes_at(core, "oct_late", SurvivalClock.year(core), 20.0)
	await _secs(1.2)
	print("   late sowing line: ", farm.interact_prompt(player))
	_ok(farm.interact_prompt(player).ends_with("(late: the frost may take it)"), "a late sowing warns of the frost")
	farm.sow(key, "corn", player)
	_ok(farm.state_of(key) == "growing", "corn sown alone")
	var nov := SurvivalClock.minutes_at(core, "nov_early", SurvivalClock.year(core), 9.0)
	core.state.minutes = nov
	farm.beds[key]["sown"] = nov - 1440.0     # (sown a day before: not ripe)
	await _secs(1.5)
	_ok(farm.state_of(key) == "dead", "November's frost kills the corn that is not ripe")
	print("   dead line: ", farm.interact_prompt(player))
	_ok(not farm.can_sow_now(), "no sowing in the frost")
	farm._clear(key)
	_ok(farm.state_of(key) == "tilled", "the dead plants pulled, the bed is worked ground")
	# the records live in the core's world (saved with it)
	_ok(is_same(farm.beds, core.state.world.farm.beds) and core.state.world.farm.beds.has(key), "the beds are records in the core's world (saved with the survival part)")
	var dec := SurvivalClock.minutes_at(core, "dec_mid", SurvivalClock.year(core), 9.0)
	core.state.minutes = dec
	await _secs(0.6)
	_ok(farm.frozen() and farm.strike(FarmField.key_of(spot.x + 1, spot.y), 1.0).event == "frozen", "in December the ground is frozen: no new bed")
	# the digging stick stands in for the hoe
	_take_all("hoe")
	g.put_away()
	await _secs(1.2)
	_give("digging_stick", 1)
	await _frames(3)
	_ok(g.owns("hoe") and is_equal_approx(g.stroke_mult("hoe"), 0.5) and g._model_kind("hoe") == "digging_stick", "the digging stick works as a hoe at half the bite, drawn as a stick")
	# food and items
	_ok(b.items.has("corn") and b.items.has("bean_pot") and b.items.has("roast_squash"), "the crops are pack foods the core knows")
	_ok(String(core.data.item("item.food.corn_ear").get("cook_to", "")) == "item.food.roast_corn", "corn cooks to roasted corn (the core's cook_to)")
	_ok(CampCooking.COOKED.has("corn") and CampCooking.COOKED.has("beans") and CampCooking.COOKED.has("squash"), "corn, beans and squash go on the campfire (F)")
	var models_ok := true
	for k: String in FarmModels.ITEMS:
		if FarmModels.build(k) == null: models_ok = false
	for c: String in FarmModels.CROPS:
		for s in 4:
			if FarmModels.crop_mesh(c, s, 0) == null: models_ok = false
	_ok(models_ok and GatherModels.build("hoe") != null and GatherModels.build("digging_stick") != null, "every farm item, crop stage and the two tools build a model")
	_ok(InventoryState.name_of("seed_tobacco") == "Tobacco Seed" and InventoryState.name_of("hoe") == "Hoe", "the items have names")
	print("FARM ", "PASSED" if failures.is_empty() else "FAILED")
	quit(0 if failures.is_empty() else 1)
