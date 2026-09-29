extends SceneTree
## Saving, loading and death (scripts/save), headless, in the real level:
##
##   Godot --headless --path . -s tests/save/test_save_game.gd -- save=on survival=on wildlife=on survival_seed=7
##
##   change    every system is changed: a tree felled (lying, a log bucked off), a second one hauled off and left as a
##             loose bole, a bundle laid down as a log pile, a rock quarried, a wall, a door (open), a lit campfire, a
##             musket rack (a spear in it) and a drying rack (venison hung) built, a piece chopped out of the palisade, the gate shut, the musket put down, a spear lying, a torch
##             dropped burning, a deer shot and skinned, the horse moved, a forage patch picked, the player moved, hurt,
##             given things, the time and hunger moved on, a home slept at and a pack dropped
##   save      F5 writes the quick slot; it is the latest
##   load      the level is rebuilt from the save and each change is back as it was
##   layout    a save of another forest keeps the rest and says the felled trees are not restored
##   death     dying drops the pack where the player fell and wakes them at home with what they wear; E takes the
##             pack back; food left lying is scavenged after a couple of game hours

var checks := 0
var fails: Array[String] = []
var report := {}
var level: Node
var player: FrontierPlayer
var sg: SaveGame
var want := {}


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
		await physics_frame


func _grab() -> void:
	level = current_scene
	player = level.get_node_or_null("Player") as FrontierPlayer
	sg = SaveGame.find(self)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(30)
	_grab()
	check(sg != null and player != null and DeathRule.find(self) != null, "the level has its saves and its death rule (save=on)")
	if sg == null:
		_end()
		return
	player.ignore_mouse_capture = true
	SurvivalWeather.set_external(SurvivalBridge.find(self).core, "clear", 2.0, 250.0)
	await _change()
	await _save()
	await _load()
	await _layout()
	await _death()
	_end()


func _end() -> void:
	# the test's saves (in SaveGame.TEST_DIR, never the player's) go with it
	check(SaveGame.dir() == SaveGame.TEST_DIR, "a test run saves in the test folder, not over the player's saves")
	for s in SaveGame.SLOTS:
		DirAccess.remove_absolute(SaveGame.dir() + String(s) + ".json")
	print("REPORT ", JSON.stringify(report))
	if fails.is_empty():
		print("SAVE TEST PASSED %d" % checks)
	else:
		for x in fails:
			printerr("FAIL: ", x)
		print("SAVE TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


## A palisade section of the fort's north wall east of the gate.
func _section() -> BuiltPiece:
	var w := BuildWorld.of(self, false) if current_scene else null
	if w == null:
		return null
	for p in w.pieces():
		if p.type == "palisade" and absf(p.global_position.z + 16.0) < 0.1 and p.global_position.x > 5.0:
			return p
	return null


func _gate() -> BuiltPiece:
	var w := BuildWorld.of(self, false)
	for p in w.pieces():
		if p.type == "palisade_gate":
			return p
	return null


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, FrontierTerrain.height_at(x, z), z)


# --- Change everything -------------------------------------------------------------------------------------

func _fell_one(skip: Array) -> FelledTree:
	var vh := VegHarvest.find(self)
	var best := -1
	var bd := INF
	for i in vh.lay.tree_pos.size():
		if int(vh.lay.tree_kind[i]) >= VegHarvest.Assets.CANOPY_COUNT or vh.lay.tree_collider[i] == 0 or i in skip:
			continue
		var p: Vector3 = vh.lay.tree_pos[i]
		if absf(p.x) < 30.0 and absf(p.z) < 30.0:
			continue
		var d := vh.describe("tree", "tree", i)
		if d.is_empty() or float(d.radius) > 0.3:
			continue
		var dist := Vector2(p.x, p.z).length()
		if dist < bd:
			bd = dist
			best = i
	var desc := vh.describe("tree", "tree", best)
	var got := [null]
	var cb := func(ft: FelledTree) -> void: got[0] = ft
	player.gather.felled.connect(cb)
	player.global_position = desc.pos + Vector3(1.3, 0.1, 0.3)
	await frames(2)
	player.gather._fell(desc)
	player.gather.felled.disconnect(cb)
	var ft: FelledTree = got[0]
	for k in 120 * 10:
		await physics_frame
		if ft.is_down():
			break
	return ft


func _change() -> void:
	var tree := self
	var c := SurvivalBridge.find(tree).core
	# vegetation: a tree down with a log off it; a second hauled and left loose; a rock half quarried
	var ft := await _fell_one([])
	ft.buck(ft.cut_work)
	want["felled_i"] = int(ft.info.i)
	want["logs_left"] = ft.logs_left
	var hs := level.find_children("*", "Horse", true, false)
	var h := hs[0] as Horse
	var haul := h.get_node("Haul") as HorseHaul
	var ft2 := await _fell_one([int(ft.info.i)])
	want["felled_2"] = int(ft2.info.i)
	var s := haul.hitch_tree(ft2, 0, player)
	await frames(3)
	haul.unhitch()
	player.gather.give("log", 3)
	var b := haul.hitch_pack(player)
	await frames(3)
	haul.unhitch()
	var vh := VegHarvest.find(tree)
	for i in vh.lay.prop_pos.size():
		if vh.has_method("rock_collider") and vh.rock_collider(i) != null:
			vh.shrink_rock(i, 0.5)
			want["rock"] = i
			break
	# building: a wall, a door (open), a lit campfire
	var w := BuildWorld.of(tree)
	var base := _ground(20, 40)
	w.add_piece("wall", Transform3D(Basis(), base), true, -1)
	var door := w.add_piece("wall_door", Transform3D(Basis(), base + Vector3(3.0, 0, 0)), true, -1)
	if door.door:
		door.door.set_open(true, true)
	var fire := w.add_piece("campfire", Transform3D(Basis(), _ground(24, 44)), true, -1)
	await frames(3)
	var cf := fire.find_children("*", "Campfire", true, false)[0] as Campfire
	cf.light()
	# the furniture: a spear standing in a built musket rack; a drying rack over the fire with venison hung on it (the
	# fire's fuel and the batch are the core's records, tagged by the pieces' ids)
	var mr := w.add_piece("musket_rack", Transform3D(Basis(), _ground(28, 40)), true, -1)
	var dry := w.add_piece("drying_rack", Transform3D(Basis(), _ground(24, 44)), true, -1)
	await frames(3)
	var sw: Weapon = player.weapons["spear"]
	var spw := PlacedWeapon.from_weapon(sw, "spear")
	spw.state = WeaponState.capture(sw)
	level.add_child(spw)
	(mr.get_node("Rack") as WeaponRack).place(spw, 2)
	want["rack_piece"] = mr.piece_id
	var br := SurvivalBridge.find(tree)
	player.gather.give("firewood", 6)
	while cf.wood_left() < Campfire.MAX_WOOD and Campfire._pack_count(player, "firewood") > 0:
		cf.add_wood(player)
	player.gather.give("venison", 2)
	var st := dry.get_node("Station") as CampStation
	player.global_position = st.global_position + Vector3(0, 0.1, 1.6)
	await frames(6)
	br.camp.refresh()
	st.interact(player)
	for i in 60 * 45:
		await process_frame
		if not br.work.working and player.kneeling == null:
			break
	await frames(4)
	want["hanging_lb"] = st.hanging_lb()
	want["dry_piece"] = dry.piece_id
	check(st.hanging_lb() >= 1.9, "venison hangs on the drying rack (%.1f lb; %s)" % [st.hanging_lb(), st.last.get("text", "")])
	want["pieces"] = w.pieces().size()
	# the fort (built from pieces, FortPlan): two pieces cut out of a palisade section (one covered), the gate shut
	var sec := _section()
	check(sec != null and w.fort_built, "the fort stands as pieces (the palisade section, FortPlan)")
	want["section"] = sec.piece_id if sec else -1
	PalisadeCuts.cut(w, sec.piece_id, 1, 1.0, 2.0)
	PalisadeCuts.cut(w, sec.piece_id, 1, 2.0, 3.0)
	PalisadeCuts.cut(w, sec.piece_id, 2, 3.0, 4.45)
	PalisadeCuts.cover(w, {"piece": sec.piece_id, "k": 2, "h0": 3.0, "h1": 4.45})
	want["windows"] = sec.cuts.size()
	want["gate_piece"] = _gate().piece_id
	_gate().door.set_open(false, true)
	# items: the musket down, a spear lying, a torch dropped burning
	var mw: Weapon = player.weapons["musket"]
	var pw := PlacedWeapon.from_weapon(mw, "musket")
	level.add_child(pw)
	pw.global_transform = Transform3D(Basis(), _ground(6, 8) + Vector3.UP * 0.05)
	pw.state["loaded"] = false
	player.set_carried("musket", false)
	var tp := ThrownProjectile.new()
	tp.kind = "spear"
	tp.model_kind = "spear"
	tp.whoosh = false
	tp.phase = ThrownProjectile.Phase.LYING
	level.add_child(tp)
	tp.global_transform = Transform3D(Basis(), _ground(8, 10) + Vector3.UP * 0.05)
	tp._make_pickup()
	var ts := TorchState.new()
	ts.light()
	var dt := DroppedTorch.spawn(level, Transform3D(Basis(), _ground(9, 9) + Vector3.UP * 0.2), Vector3.ZERO, Vector3.ZERO, ts)
	dt.freeze = true
	# wildlife: a deer shot and skinned, meat taken off
	var sp := level.get_node("Wildlife") as WildlifeSpawner
	var deer: WildAnimal = null
	for a in sp.animals():
		if a.species == "deer" and not a.is_dead():
			deer = a
			break
	deer.global_position = _ground(12, 30)
	deer.apply_hit(9999.0, deer.global_position + Vector3.UP * 0.6, Vector3.RIGHT, player, "vitals")
	await frames(3)
	deer.dress_step = 1
	deer.meat_left = 0.6
	want["deer_at"] = deer.global_position
	want["animals"] = sp.animals().size()
	# the horse moved; a forage patch picked
	h.global_position = _ground(-10, 20)
	want["horse_at"] = h.global_position
	var fo := ForageField.find(tree)
	var pi := 0
	for i in fo.patches.size():
		if fo.patches[i].kind == "blackberry":
			pi = i
			break
	fo.take(pi, 0)
	want["forage_patch"] = pi
	want["forage_stock"] = fo.stock_of(pi)
	# the player: moved, hurt, given things; the torches; a skill; the time and hunger moved on
	player.global_position = _ground(5, 12) + Vector3.UP * 0.1
	player.yaw = 1.2
	player.health = 70.0
	player.gather.give("stone", 5)
	player.torch.add_torches(2)
	player.gather.skills.points["woodcutting"] = 7.5
	c.advance(5.0 * 60.0)
	c.state.needs["stomach"] = 1234.0
	await frames(5)
	want["minutes"] = c.state.minutes
	want["fire_fuel"] = cf.fuel_min()
	want["pack_stone"] = InventoryState.from_player(player).pack_count("stone")
	want["torches"] = player.torch.count()
	want["player_at"] = player.global_position
	want["health"] = player.health
	# death: a home slept at, a pack dropped (with jerky in it)
	var dr := DeathRule.find(tree)
	dr.home = _ground(-4, 18)
	dr.has_home = true
	var pd := PackDrop.new()
	pd.items = [{"kind": "jerky", "count": 3, "state": {}}]
	level.add_child(pd)
	pd.global_position = _ground(14, 14)
	pd.dropped_min = c.state.minutes
	pd.scavenged_to = c.state.minutes
	report["changed"] = {"felled": want.felled_i, "pieces": want.pieces, "windows": want.windows, "animals": want.animals}


# --- Save ---------------------------------------------------------------------------------------------------

func _save() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F5
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(3)
	var ev2 := InputEventKey.new()
	ev2.physical_keycode = KEY_F5
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await frames(2)
	check(sg.last_saved_slot == "quick" and FileAccess.file_exists(SaveGame.dir() + "quick.json"), "F5 writes the quick save")
	check(SaveGame.latest_slot() == "quick", "and it is the latest")
	var doc := SaveGame.read_slot("quick")
	report["save_kb"] = snappedf(FileAccess.get_file_as_bytes(SaveGame.dir() + "quick.json").size() / 1024.0, 0.1)
	check(doc.has("parts") and (doc.parts as Dictionary).size() == SaveGame.PARTS.size(), "with every part (%d)" % (doc.get("parts", {}) as Dictionary).size())


# --- Load ---------------------------------------------------------------------------------------------------

func _load() -> void:
	var loaded := [false]
	check(sg.load_slot("quick"), "load_slot starts the load")
	for i in 60 * 10:
		await process_frame
		var s2 := SaveGame.find(self)
		if s2 != null and s2 != sg and not s2.loading and s2.level != null and s2.level.is_inside_tree():
			if not loaded[0]:
				loaded[0] = true
				s2.loaded.connect(func(_s: String) -> void: pass)
			await frames(12)
			break
	_grab()
	await frames(5)
	check(sg != null and not sg.loading, "a new level with the save applied")
	var tree := self
	var c := SurvivalBridge.find(tree).core
	check(absf(c.state.minutes - float(want.minutes)) < 1.0 and absf(float(c.state.needs.stomach) - 1234.0) < 1.0, "the time and hunger are back (%.0f, %.0f)" % [c.state.minutes, float(c.state.needs.stomach)])
	var vh := VegHarvest.find(tree)
	check(vh.felled.has(int(want.felled_i)) and vh.felled.has(int(want.felled_2)), "the felled trees are gone from the forest")
	check(level.find_child("Stump_%d" % int(want.felled_i), true, false) != null, "their stumps stand")
	var lying := get_nodes_in_group(FelledTree.GROUP).filter(func(n: Node) -> bool: return n is FelledTree and not (n is SkidLoad))
	check(lying.size() == 1 and (lying[0] as FelledTree).state == FelledTree.State.DOWN and (lying[0] as FelledTree).logs_left == int(want.logs_left), "the tree lies down with its logs left (%d)" % (lying[0].logs_left if lying.size() > 0 else -1))
	var loose := get_nodes_in_group(FelledTree.GROUP).filter(func(n: Node) -> bool: return n is SkidLoad)
	check(loose.size() == 1, "the loose bole lies there (%d)" % loose.size())
	check(level.find_children("*", "LogPile", true, false).size() == 1, "the log pile too")
	check(absf(float(vh.rock_size.get(int(want.rock), 1.0)) - 0.5) < 0.01, "the rock is half quarried")
	var w := BuildWorld.of(tree, false)
	check(w != null and w.pieces().size() == int(want.pieces), "the buildings stand (%d)" % (w.pieces().size() if w else 0))
	var doors := w.pieces().filter(func(p: BuiltPiece) -> bool: return p.type == "wall_door")
	check(doors.size() == 1 and doors[0].door.is_open, "the door is open")
	await frames(3)
	var fires := level.find_children("*", "Campfire", true, false)
	check(fires.size() == 1 and (fires[0] as Campfire).state.lit, "the campfire burns")
	var cf := fires[0] as Campfire if fires.size() == 1 else null
	check(cf != null and cf.fire_id != "" and absf(cf.fuel_min() - float(want.fire_fuel)) < 10.0,
			"on its own record in the core, its wood as it was (%.0f of %.0f game min)" % [cf.fuel_min() if cf else -1.0, float(want.fire_fuel)])
	var dry := w.by_id(int(want.dry_piece))
	var st := dry.get_node_or_null("Station") as CampStation if dry else null
	check(st != null and absf(st.hanging_lb() - float(want.hanging_lb)) < 0.05, "the venison still hangs drying (%.1f lb)" % (st.hanging_lb() if st else -1.0))
	var mr := w.by_id(int(want.rack_piece))
	var rack := mr.get_node_or_null("Rack") as WeaponRack if mr else null
	var held := rack.held() if rack else []
	check(held.size() == 1 and (held[0] as PlacedWeapon).key == "spear" and (held[0] as PlacedWeapon).rack_slot == 2, "the built rack holds its spear, in its slot")
	var sec2 := w.by_id(int(want.section))
	check(sec2 != null and sec2.cuts.size() == int(want.windows) and sec2.cuts.size() == 3, "the palisade has its pieces out (%d)" % (sec2.cuts.size() if sec2 else -1))
	check(sec2 != null and PalisadeCuts.removed(sec2.cuts, 2, false).is_empty() and not PalisadeCuts.removed(sec2.cuts, 2, true).is_empty(),
			"the cover is still on the opening (the collider is closed there)")
	check(sec2 != null and PalisadeCuts.removed(sec2.cuts, 1, false).size() == 1 and absf(float(PalisadeCuts.removed(sec2.cuts, 1, false)[0][1]) - 3.0) < 0.01,
			"the two stacked pieces are one opening (1 m to 3 m)")
	var gate2 := w.by_id(int(want.gate_piece))
	check(gate2 != null and gate2.door != null and not gate2.door.is_open, "the gate is shut")
	var placed := get_nodes_in_group(PlacedWeapon.GROUP).filter(func(n: Node) -> bool: return n is PlacedWeapon and (n as PlacedWeapon).rack == null)
	check(placed.size() == 1 and placed[0].key == "musket" and not bool(placed[0].state.get("loaded", true)), "the musket lies where it was put, unloaded")
	check(not player.is_carried("musket"), "and is not carried")
	var racked := get_nodes_in_group(PlacedWeapon.GROUP).filter(func(n: Node) -> bool: return n is PlacedWeapon and (n as PlacedWeapon).rack != null)
	check(racked.size() == 7, "the racks hold what they held (%d)" % racked.size())
	var thrown := level.find_children("*", "ThrownProjectile", true, false)
	check(thrown.size() == 1 and (thrown[0] as ThrownProjectile).pickup != null, "the spear lies there, to pick up")
	var torches := level.find_children("*", "DroppedTorch", true, false)
	check(torches.size() == 1 and (torches[0] as DroppedTorch).state.lit, "the dropped torch burns")
	var sp := level.get_node("Wildlife") as WildlifeSpawner
	var dead := sp.animals().filter(func(a: WildAnimal) -> bool: return a.is_dead())
	check(sp.animals().size() == int(want.animals), "the animals are back (%d of %d)" % [sp.animals().size(), int(want.animals)])
	check(dead.size() == 1 and absf(dead[0].meat_left - 0.6) < 0.01 and dead[0].dress_step == 1 and dead[0].global_position.distance_to(want.deer_at) < 0.5, "the deer lies skinned with its meat left")
	var dap: AnimationPlayer = dead[0]._ap if dead.size() == 1 else null
	check(dap != null and (not dap.is_playing() or dap.current_animation_position >= dap.current_animation_length - 0.05),
			"lying as it fell, not falling again (%s at %.2f s)" % [dap.current_animation if dap else "", dap.current_animation_position if dap and dap.is_playing() else -1.0])
	var h := level.find_children("*", "Horse", true, false)[0] as Horse
	check(h.global_position.distance_to(want.horse_at) < 0.3, "the horse stands where it was")
	var fo := ForageField.find(tree)
	check(absf(fo.stock_of(int(want.forage_patch)) - float(want.forage_stock)) < 0.05, "the berries picked stay picked")
	check(player.global_position.distance_to(want.player_at) < 0.3 and absf(player.yaw - 1.2) < 0.01, "the player stands where they stood")
	check(absf(player.health - float(want.health)) < 0.5, "as hurt (%.0f)" % player.health)
	check(InventoryState.from_player(player).pack_count("stone") == int(want.pack_stone), "with their pack")
	check(player.torch.count() == int(want.torches), "their torches (%d)" % player.torch.count())
	check(absf(player.gather.skills.points_of("woodcutting") - 7.5) < 0.01, "and their skill")
	var dr := DeathRule.find(tree)
	check(dr.has_home and dr.home.distance_to(_ground(-4, 18)) < 0.1, "the home is remembered")
	var drops := get_nodes_in_group(PackDrop.GROUP)
	check(drops.size() == 1 and (drops[0] as PackDrop).count() == 3, "the dropped pack lies there (3 jerky)")


# --- Another forest ----------------------------------------------------------------------------------------

func _layout() -> void:
	var doc := SaveGame.read_slot("quick")
	doc.parts.vegetation.sig = "another-forest"
	var f := FileAccess.open(SaveGame.dir() + "auto.json", FileAccess.WRITE)
	doc.meta.saved_unix = Time.get_unix_time_from_system() + 10.0
	f.store_string(JSON.stringify(doc))
	f.close()
	sg.load_slot("auto")
	for i in 60 * 10:
		await process_frame
		var s2 := SaveGame.find(self)
		if s2 != null and s2 != sg and not s2.loading and s2.level != null and s2.level.is_inside_tree():
			await frames(12)
			break
	_grab()
	await frames(5)
	check(sg.notes.size() == 1 and String(sg.notes[0]).contains("forest has changed"), "a save of another forest says so (%s)" % [sg.notes])
	check(VegHarvest.find(self).felled.is_empty(), "and fells nothing")
	check(BuildWorld.of(self, false) != null and BuildWorld.of(self, false).pieces().size() == int(want.pieces), "the rest is back (the buildings)")


# --- Death --------------------------------------------------------------------------------------------------

func _death() -> void:
	var dr := DeathRule.find(self)
	var c := SurvivalBridge.find(self).core
	player.global_position = _ground(30, 30) + Vector3.UP * 0.1
	await frames(5)
	var at := player.global_position
	var n_pack := InventoryState.from_player(player).pack_count("stone")
	var drops0 := get_nodes_in_group(PackDrop.GROUP).size()
	player.apply_hit(player.health + 10.0, player.global_position + Vector3.UP, Vector3.FORWARD, null, "body")
	await frames(3)
	check(player.is_dead, "the player dies")
	for i in 100:
		await create_timer(0.1).timeout
		if not player.is_dead:
			break
	await frames(3)
	check(not player.is_dead and player.global_position.distance_to(dr.home) < 1.0, "and wakes at home (%.1f m off)" % player.global_position.distance_to(dr.home))
	var ls := String(player.anim.loco.state) if player.anim and player.anim.loco else "?"
	check(ls != String(LocoBrain.DEATH), "standing, not falling dead again (the animation: %s)" % ls)
	check(InventoryState.from_player(player).pack_count("stone") == 0, "the pack is empty")
	check(player.loadout != null and player.loadout.has_kind("bow"), "what they wear stays on")
	var drops := get_nodes_in_group(PackDrop.GROUP)
	check(drops.size() == drops0 + 1, "a pack lies where they fell")
	var pd: PackDrop = null
	for n in drops:
		if (n as PackDrop).global_position.distance_to(at) < 1.5:
			pd = n
	check(pd != null and pd.count() >= n_pack, "holding what was in the pack (%d)" % (pd.count() if pd else -1))
	check(not c.is_dead(), "the survival side lives again")
	# scavengers: food left lying goes after a couple of game hours
	pd.items.append({"kind": "jerky", "count": 4, "state": {}})
	var j0 := _jerky(pd)
	c.advance(1.5 * 60.0)
	await frames(3)
	check(_jerky(pd) == j0, "an hour and a half on, the food is untouched (%d)" % _jerky(pd))
	c.advance(3.5 * 60.0)
	await frames(3)
	report["jerky_5h"] = "%d of %d" % [_jerky(pd), j0]
	check(_jerky(pd) == j0 - 3, "five game hours on, scavengers had three of it (%d of %d left)" % [_jerky(pd), j0])
	# E takes the pack back
	var n0 := pd.count()
	pd.interact(player)
	await frames(2)
	check(InventoryState.from_player(player).pack_count("stone") == n_pack, "E takes the pack back (%d things)" % n0)


func _jerky(pd: PackDrop) -> int:
	var n := 0
	for e in pd.items:
		if String(e.kind) == "jerky":
			n += int(e.count)
	return n
