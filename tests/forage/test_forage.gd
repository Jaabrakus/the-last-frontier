extends SceneTree
## Wild food and herb plants (scripts/forage; data/forage/forage.json), headless:
##
##   Godot --headless --path . -s tests/forage/test_forage.gd
##
##   data      every plant's item has a name, its windows and height, its models and the items' icons build; our own grab
##             clips (both arms, the grab's moment) are there
##   calendar  day ids, the survival calendar's thirds of a month, windows that wrap the new year
##   place     in the level: enough patches of each plant (no hazel headless: the vegetation places its shrubs only
##             with a window), on the ground, off the dirt and out of the fort, clear of trunks and rocks, apart,
##             each in its habitat (wintergreen under conifers, ginseng among maples, acorns under oaks, brambles at
##             the edges, plantain where people walk); the woods' materials (user 2026-09-28): dry sticks and fallen
##             limbs in the woods, pine pitch on white pines' trunks at chest height, turkey feathers under the oaks;
##             the same every time
##   season    25 August: blackberries, plantain, ginseng and the first acorns (a quarter crop) are in, strawberries
##             out, wintergreen's berries not yet; a field built for mid June has the strawberries
##   pick      with the real E: the prompt at a bramble (handfuls left), E is one grab of an arm (the legs the game's: the
##             player is not held), a handful in the pack and one less on the plant, the bar up by the share; a grab
##             walking still yields; out of season E says when it bears; picked clean it grows back in season; a ginseng
##             root dug is gone
##   deer      feeding spots near a patch, one drawn by weight, a deer feeding eats the ripe food first and leaves its
##             sign on the prompt
##   wild      with a wildlife spawner in the level: a deer herd's feeding places (WildlifeSpawner.find_place "open")
##             go to the food plants near its range, and a deer grazing on a patch eats from it
##   use       a plantain poultice from the pack heals a wound over time (through the inventory screen), not at full
##             health, one at a time
##
## The plants are the project's own models.

## Patches placed by their own tree (under an oak, on a pine's trunk), not kept apart from the rest.
const UNDER_TREES := ["acorns", "turkey_scratch", "pine_pitch"]

var checks := 0
var fails: Array[String] = []
var report := {}
var f: ForageField
var player: FrontierPlayer
var it: PlayerInteractor


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func seconds(t: float) -> void:
	await frames(int(t * Engine.physics_ticks_per_second))


func _run() -> void:
	_test_data()
	_test_calendar()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(20)
	f = ForageField.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	check(f != null and player != null, "the level has its forage field and a player")
	if f == null or player == null:
		_end()
		return
	player.ignore_mouse_capture = true
	it = player.interactor
	_test_place()
	_test_season()
	await _test_pick()
	await _test_deer()
	await _test_use()
	await _test_wild()
	_end()


func _end() -> void:
	print("REPORT ", JSON.stringify(report))
	if fails.is_empty():
		print("FORAGE TEST PASSED %d" % checks)
	else:
		for x in fails:
			printerr("FAIL: ", x)
		print("FORAGE TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


# --- Data --------------------------------------------------------------------------------------------------

func _test_data() -> void:
	var d := ForageField.load_data()
	var plants: Dictionary = d.get("plants", {})
	# the seven food plants, the nine for the remedies and the vices (tests/forage/test_plants_herbs.gd), and the five
	# of the woods' materials (dry sticks, fallen limbs, arrowwood, pine pitch, turkey feathers), and the three for a start
	# with nothing (fieldstones, chert nodules, dead saplings), and the forge's two (bog iron ore, clay)
	check(plants.size() == 26, "forage.json reads: 26 plants (%d)" % plants.size())
	var grab := load(ForagePick.CLIPS) as AnimationLibrary
	for side in ["r", "l"]:
		var a: Animation = grab.get_animation(StringName("own-forage-grab-" + side)) if grab else null
		check(a != null and a.has_meta(&"grab_s") and float(a.get_meta(&"grab_s")) < a.length, "our own grab for the %s arm, its grab inside it" % side)
	for kind: String in plants:
		var p: Dictionary = plants[kind]
		var item := String(p.get("item", ""))
		check(InventoryState.NAMES.has(item), "%s gives a named item (%s)" % [kind, item])
		check(ForageField.day_id_index(String(p.ripe[0])) >= 0 and ForageField.day_id_index(String(p.ripe[1])) >= 0, "%s: its window is two day ids" % kind)
		check(String(p.get("clip", "")) in ["ground", "low", "waist", "high"], "%s: its height is one of the four (%s)" % [kind, p.get("clip", "")])
		# (the sticks and the fallen limb are all "fruit": they go when gathered)
		if not (kind in ["hazelnuts", "deadwood", "windfall", "fieldstones", "flint_nodules", "dead_pole", "clay_bank", "bog_ore"]):
			check(ForageModels.plant_mesh(kind, 0) != null, "%s: its plant model builds" % kind)
		# (plantain's leaves and the barks and hemp's tops and arrowwood's shoots are the plant itself: no fruit)
		if not (kind in ["plantain", "willow", "slippery_elm", "hemp", "arrowwood"]):
			check(ForageModels.fruit_mesh(kind, 1) != null, "%s: its fruit model builds" % kind)
		if not ForageModels.has(item):
			continue            # (branches and firewood: the gathering's own icons, GatherModels)
		var icon := ForageModels.build(item)
		var tris := 0
		for mi in icon.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh
			for s in m.get_surface_count():
				tris += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		check(tris > 10, "the %s icon model builds (%d tris)" % [item, tris])
		icon.free()


func _test_calendar() -> void:
	check(ForageField.day_index_of(237.0) == 23, "25 August is aug_late (%d)" % ForageField.day_index_of(237.0))
	check(ForageField.day_index_of(213.0) == 21 and ForageField.day_index_of(224.0) == 22, "1 August early, 12 August mid")
	check(ForageField.day_index_of(1.0) == 0 and ForageField.day_index_of(365.0) == 35, "the year's first and last day")
	var w := ["sep_mid", "apr_late"]
	check(ForageField.in_window(0, w) and ForageField.in_window(25, w) and not ForageField.in_window(20, w), "a window across the new year")


# --- Placement ---------------------------------------------------------------------------------------------

func _test_place() -> void:
	var lay = (current_scene.get("vegetation") as FrontierVegetation).layout
	var by := {}
	var plants := 0
	for pa in f.patches:
		by[pa.kind] = int(by.get(pa.kind, 0)) + 1
		plants += (pa.plants as Array).size()
	report["patches"] = by
	report["plants"] = plants
	report["build_ms"] = snappedf(f.build_usec / 1000.0, 0.1)
	for kind: String in f.data.plants:
		if kind == "hazelnuts":
			continue
		var want := int(f.data.plants[kind].patches)
		check(int(by.get(kind, 0)) >= int(want * (0.5 if kind == "blackberry" else 0.8)), "%s: %d patches of %d wanted" % [kind, int(by.get(kind, 0)), want])
	check(f.build_usec < 400000, "placing them takes %.0f ms" % (f.build_usec / 1000.0))
	# every plant on the ground, off the dirt, out of the fort, clear of trunks
	var off_ground := 0
	var on_dirt := 0
	var in_fort := 0
	var in_trunk := 0
	var tp: PackedVector3Array = lay.tree_pos
	var trunks := {}
	for i in tp.size():
		if lay.tree_kind[i] > 4:
			continue
		var c := Vector2i(floori(tp[i].x / 4.0), floori(tp[i].z / 4.0))
		if not trunks.has(c):
			trunks[c] = []
		trunks[c].append(Vector3(tp[i].x, tp[i].z, float(lay.tree_kind[i])))
	var pitch_bad := 0
	for pa in f.patches:
		if pa.kind == "pine_pitch":
			# on a white pine's bark at chest height
			for pl in pa.plants:
				var p: Vector3 = pl.pos
				var h := p.y - FrontierTerrain.height_at(p.x, p.z)
				var on := false
				for e in ForageField._near(f._tree_grid(lay), p.x, p.z, 0.3):
					on = on or (int(e[1]) == 0 and float(e[0]) < 0.1)
				if not on or h < 0.8 or h > 1.5:
					pitch_bad += 1
			continue
		for pl in pa.plants:
			var p: Vector3 = pl.pos
			if pa.kind != "hazelnuts" and absf(p.y - FrontierTerrain.height_at(p.x, p.z)) > 0.02:
				off_ground += 1
			if Sfx.is_dirt(p):
				on_dirt += 1
			if absf(p.x) < 18.0 and absf(p.z) < 18.0:
				in_fort += 1
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					for t in trunks.get(Vector2i(floori(p.x / 4.0) + dx, floori(p.z / 4.0) + dz), []):
						if Vector2(t.x - p.x, t.y - p.z).length() < 0.45:
							in_trunk += 1
	check(off_ground == 0, "every plant on the ground (%d off)" % off_ground)
	check(on_dirt == 0 and in_fort == 0, "none on the dirt or in the fort (%d, %d)" % [on_dirt, in_fort])
	check(in_trunk == 0, "none in a trunk (%d)" % in_trunk)
	check(pitch_bad == 0 and int(by.get("pine_pitch", 0)) > 0, "pine pitch on white pines' bark at chest height (%d of %d off)" % [pitch_bad, int(by.get("pine_pitch", 0))])
	# apart
	var close := 0
	for i in f.patches.size():
		for j in range(i + 1, f.patches.size()):
			# (what is under the oaks, and the pitch on the pines' trunks, go by their trees)
			var ki := String(f.patches[i].kind)
			var kj := String(f.patches[j].kind)
			if not (ki in UNDER_TREES) and not (kj in UNDER_TREES) and \
					Vector2(f.patches[i].pos.x - f.patches[j].pos.x, f.patches[i].pos.z - f.patches[j].pos.z).length() < ForageField.PATCH_GAP:
				close += 1
	check(close == 0, "patches keep apart (%d too close)" % close)
	# habitats
	var bad := {}
	for pa in f.patches:
		var c: Vector3 = pa.pos
		var near := ForageField._near(f._tree_grid(lay), c.x, c.z, 10.0)
		var conifers := near.filter(func(e: Array) -> bool: return e[0] < 8.0 and e[1] in [0, 1]).size()
		var maples := near.filter(func(e: Array) -> bool: return e[1] == 3).size()
		var oaks := near.filter(func(e: Array) -> bool: return e[0] < 1.0 and e[1] == 2).size()
		var fd := FrontierTerrain.forest_density(c.x, c.z)
		var ok := true
		match String(pa.kind):
			"wintergreen":
				ok = conifers >= 2
			"ginseng":
				ok = maples >= 2 and fd >= 0.55
			"acorns":
				ok = oaks >= 1
			"turkey_scratch":
				ok = oaks >= 1
			"deadwood":
				ok = fd >= 0.3
			"windfall":
				ok = fd >= 0.35
			"blackberry":
				ok = fd >= 0.3 and fd <= 0.62
			"strawberry":
				ok = fd <= 0.3
			"plantain":
				ok = fd <= 0.25
		if not ok:
			bad[pa.kind] = int(bad.get(pa.kind, 0)) + 1
	check(bad.is_empty(), "every patch in its habitat (%s)" % [bad])
	var by_fort := f.patches.filter(func(pa: Dictionary) -> bool:
		return pa.kind == "plantain" and (Vector2(pa.pos.x, pa.pos.z).length() < 75.0 or (absf(pa.pos.x) < 22.0 and pa.pos.z < -20.0 and pa.pos.z > -180.0))).size()
	check(by_fort >= int(by.get("plantain", 0) * 0.6), "plantain grows where people walk (%d of %d by the fort or the lane)" % [by_fort, by.get("plantain", 0)])
	# the same every time
	var g := ForageField.new()
	g.day_override = f.doy()
	current_scene.add_child(g)
	g.build(current_scene.get("vegetation"))
	var same := g.patches.size() == f.patches.size()
	for i in mini(g.patches.size(), f.patches.size()):
		same = same and (g.patches[i].pos as Vector3).is_equal_approx(f.patches[i].pos)
	check(same, "the same patches every time (%d vs %d)" % [g.patches.size(), f.patches.size()])
	g.queue_free()


# --- Season ------------------------------------------------------------------------------------------------

func _test_season() -> void:
	check(f.day_index == 23, "the level is on 25 August (day %d)" % f.day_index)
	for k in ["blackberry", "plantain", "ginseng", "acorns"]:
		check(f.in_season(k), "%s is in season in late August" % k)
	check(not f.in_season("strawberry"), "strawberries are not (they fruit in June)")
	check(f.in_season("wintergreen") and not f.fruit_shown("wintergreen"), "wintergreen's leaves are, its berries not yet")
	var n := 0
	var down := 0
	var stock := 0.0
	for pi in f.patches.size():
		if f.patches[pi].kind != "acorns":
			continue
		stock += f.stock_of(pi)
		for pl in f.patches[pi].plants:
			n += 1
			down += 1 if float(pl.stock) > 0.0 else 0
	report["acorns_down"] = "%d of %d" % [down, n]
	check(down > n * 0.18 and down < n * 0.32, "the first acorns: about a quarter of them down (%d of %d)" % [down, n])
	check(absf(stock - down * 0.25) < 0.01, "each a whole acorn's worth (%.2f handfuls)" % stock)
	var june := ForageField.new()
	june.day_override = 166.0
	current_scene.add_child(june)
	june.build(current_scene.get("vegetation"))
	check(june.in_season("strawberry") and not june.in_season("blackberry"), "in mid June the strawberries, not the blackberries")
	var sp: Dictionary = june.patches.filter(func(p: Dictionary) -> bool: return p.kind == "strawberry")[0]
	check(june.stock_of(june.patches.find(sp)) > 1.0, "a June strawberry patch has some to pick (%.1f)" % june.stock_of(june.patches.find(sp)))
	june.queue_free()


# --- Picking -----------------------------------------------------------------------------------------------

func _face(at: Vector3) -> void:
	var d := at - player.global_position
	d.y = 0.0
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw
	player.pitch = deg_to_rad(-20.0)


## The player 1.3 m off plant `li` of patch `pi` (on the side toward the fort), facing it.
func _stand_at(pi: int, li: int) -> Vector3:
	var pl: Dictionary = f.patches[pi].plants[li]
	var p: Vector3 = pl.pos
	var out := Vector3(-p.x, 0.0, -p.z).normalized()
	var at := p + out * 1.3
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO
	_face(p)
	return p


func _nearest_patch(kind: String) -> int:
	var best := -1
	var bd := INF
	for i in f.patches.size():
		if f.patches[i].kind == kind:
			var d := Vector2(f.patches[i].pos.x, f.patches[i].pos.z).length()
			if d < bd:
				bd = d
				best = i
	return best


func _tap_e() -> void:
	Input.action_press(&"interact")
	await frames(4)
	Input.action_release(&"interact")
	await frames(3)


func _test_pick() -> void:
	var pi := _nearest_patch("blackberry")
	check(pi >= 0, "a bramble to pick")
	if pi < 0:
		return
	var pl0: Dictionary = f.patches[pi].plants[0]
	_stand_at(pi, 0)
	await frames(10)
	check(it.target == f and it._label.text.contains("Pick blackberries"), "at a bramble: %s" % it._label.text)
	var stock0 := f.stock_of(pi)
	var have0 := InventoryState.from_player(player).pack_count("blackberries")
	check(it._label.text.contains("left)"), "the prompt says how many handfuls are left: %s" % it._label.text)
	await _tap_e()
	await frames(10)
	check(f.picker.working and player.kneeling == null and ForagePick.grabbing == player, "E: an arm grabs, the player not held")
	var t := 0
	while f.picker.working and t < 120 * 3:
		await physics_frame
		t += 1
	report["grab_s"] = snappedf(float(t + 17) / 120.0, 0.01)
	check(not f.picker.working and float(t + 17) / 120.0 < 1.0, "the grab is over in under a second (%.2f s)" % (float(t + 17) / 120.0))
	check(InventoryState.from_player(player).pack_count("blackberries") == have0 + 1, "a handful of blackberries in the pack")
	check(absf(f.stock_of(pi) - (stock0 - 1.0)) < 0.01, "one less on the bramble (%.2f -> %.2f)" % [stock0, f.stock_of(pi)])
	check(f.picker._bar.value > 0.0 and absf(f.picker._bar.value - f.picked_share(pi)) < 0.01, "the bar is the patch picked (%.2f)" % f.picker._bar.value)
	# a grab walking past still yields
	await frames(20)
	_stand_at(pi, 0)
	await frames(10)
	var stock1 := f.stock_of(pi)
	var have1 := InventoryState.from_player(player).pack_count("blackberries")
	Input.action_press(&"move_left")
	await frames(2)
	await _tap_e()
	await frames(100)
	Input.action_release(&"move_left")
	check(InventoryState.from_player(player).pack_count("blackberries") == have1 + 1 and absf(f.stock_of(pi) - (stock1 - 1.0)) < 0.01,
			"a grab while walking yields a handful too")
	# picked clean: the prompt names it, E says it bears again; three game days later it has
	for k in 30:
		if f.stock_of(pi) < 0.5:
			break
		f.take(pi, 0)
	_stand_at(pi, 0)
	await frames(10)
	check(it._label.text.ends_with("Blackberry Bramble"), "picked clean, the prompt names it: %s" % it._label.text)
	await _tap_e()
	await frames(3)
	check(not f.picker.working and it._notice.text.contains("bears again"), "E: it bears again in a few days (%s)" % it._notice.text)
	f.now += 3.0 * float(f.data.game_day_s)
	check(f.stock_of(pi) > float((f.patches[pi].plants as Array).size()) * 2.0 - 0.01, "three game days later it is full again (%.1f)" % f.stock_of(pi))
	# out of season
	var si := _nearest_patch("strawberry")
	_stand_at(si, 0)
	await frames(10)
	check(it.target == f and it._label.text.ends_with("Wild Strawberry"), "a strawberry plant in August: %s" % it._label.text)
	await _tap_e()
	await frames(3)
	check(not f.picker.working and it._notice.text.contains("June"), "E: it bears in June (%s)" % it._notice.text)
	# a ginseng root dug is gone
	var gi := _nearest_patch("ginseng")
	var n0 := (f.patches[gi].plants as Array).filter(func(p: Dictionary) -> bool: return not p.gone).size()
	check(f.take(gi, 0) >= 0.99 and f.patches[gi].plants[0].gone, "a ginseng root dug")
	check((f.patches[gi].plants as Array).filter(func(p: Dictionary) -> bool: return not p.gone).size() == n0 - 1, "and that plant is gone")
	f.now += 30.0 * float(f.data.game_day_s)
	check(f.patches[gi].plants[0].gone, "it does not grow back this season")


# --- Deer --------------------------------------------------------------------------------------------------

func _test_deer() -> void:
	var pi := _nearest_patch("blackberry")
	var c: Vector3 = f.patches[pi].pos
	var spots := f.deer_spots(c, 30.0)
	check(not spots.is_empty() and spots.any(func(s: Dictionary) -> bool: return int(s.patch) == pi), "deer_spots finds the bramble near it")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var spot := f.deer_feed_spot(c, 30.0, rng)
	check(spot != Vector3.INF and f.patches.any(func(p: Dictionary) -> bool: return (p.pos as Vector3).is_equal_approx(spot)), "deer_feed_spot picks a patch")
	check(f.deer_feed_spot(Vector3(5000, 0, 5000), 20.0) == Vector3.INF, "none where nothing grows")
	var s0 := f.stock_of(pi)
	var ate := 0.0
	for k in 60:
		ate += f.deer_eat(c, 0.5)
	check(absf((s0 - f.stock_of(pi)) - 1.0) < 0.05, "a deer feeding 30 s eats a handful of the fruit (%.2f)" % (s0 - f.stock_of(pi)))
	check(float(f.patches[pi].browse) < 1.0 and ate > 1.0, "and some browse")
	_stand_at(pi, 0)
	await frames(10)
	check(it._label.text.contains("deer have been feeding here"), "the player sees the sign: %s" % it._label.text)


# --- Use ---------------------------------------------------------------------------------------------------

func _test_use() -> void:
	var inv := InventoryState.from_player(player)
	inv.add("plantain", 2)
	player.inventory_pack = inv.pack.duplicate(true)
	player.health = player.max_health
	var scr := InventoryScreen.open_for(player)
	await process_frame
	scr.use_item("plantain")
	check(scr._msg.text.contains("no wound"), "at full health: %s" % scr._msg.text)
	scr.close()
	await process_frame
	player.health = 60.0
	scr = InventoryScreen.open_for(player)
	await process_frame
	scr.use_item("plantain")
	check(scr._msg.text.contains("poultice"), "wounded, right-click plantain: %s" % scr._msg.text)
	scr.use_item("plantain")
	check(scr._msg.text.contains("already"), "one poultice at a time: %s" % scr._msg.text)
	scr.close()
	await process_frame
	check(InventoryState.from_player(player).pack_count("plantain") == 1, "one plantain used")
	await seconds(21.0)
	report["poultice_health"] = snappedf(player.health, 0.1)
	check(absf(player.health - 75.0) < 0.5 and player.get_node_or_null("Poultice") == null, "it heals 15 over 20 s (%.1f)" % player.health)


# --- Wildlife ----------------------------------------------------------------------------------------------

func _test_wild() -> void:
	var w := WildlifeSpawner.new()
	w.name = "WildlifeT"
	w.setup(player, current_scene.get("vegetation"), current_scene.get("environment_rig"))
	current_scene.add_child(w)
	await frames(10)
	var herd: WildGroup = null
	for e in w.groups:
		if (e.group as WildGroup).species == "deer" and not (e.group as WildGroup).alive().is_empty():
			herd = e.group
			break
	check(herd != null, "a deer herd")
	if herd == null:
		w.queue_free()
		return
	var pi := _nearest_patch("blackberry")
	herd.home = f.patches[pi].pos + Vector3(25.0, 0.0, 0.0)
	herd.home.y = FrontierTerrain.height_at(herd.home.x, herd.home.z)
	var at_food := 0
	for k in 20:
		var p := w.find_place(herd, "open")
		if f.patches_near(p, 2.5).any(func(i: int) -> bool: return f.deer_food(i) > 0.3):
			at_food += 1
	report["herd_feeds_at_plants"] = "%d of 20" % at_food
	check(at_food >= 12, "a herd's feeding places are at its food plants (%d of 20)" % at_food)
	var fox_at := 0
	for e in w.groups:
		if (e.group as WildGroup).species == "fox":
			(e.group as WildGroup).home = herd.home
			for k in 10:
				if f.patches_near(w.find_place(e.group, "open"), 2.5).size() > 0:
					fox_at += 1
			break
	check(fox_at <= 5, "foxes mouse in the open as before (%d of 10 at a patch)" % fox_at)
	var deer: WildAnimal = herd.alive()[0]
	var bi := _nearest_patch("blackberry")
	deer.global_position = f.patches[bi].pos + Vector3.UP * 0.05
	var s0 := f.stock_of(bi)
	var t := 0.0
	while t < 20.0:
		deer.set_active(true)
		deer.state = WildAnimal.State.GRAZE
		deer._needs(0.25)
		t += 0.25
	check(f.stock_of(bi) < s0 - 0.5 and f.now - float(f.patches[bi].deer_t) < 1.0, "a deer grazing at a bramble eats its berries (%.1f -> %.1f)" % [s0, f.stock_of(bi)])
	w.queue_free()
