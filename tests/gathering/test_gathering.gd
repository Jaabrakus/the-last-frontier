extends SceneTree
## Headless tests of gathering (scripts/gathering/, data/gathering/gathering.json):
##   skills     levels, tiers, the level curve, effects, save round trip, pacing to Apprentice
##   data       tool kinds in the loadout data and rules (tool_loop), names, the pack helpers
##   yields     strokes to fell by diameter and species, logs per tree, stones per rock
##   level      on the real level with the real input path: the axe drawn (7), a tree felled with LMB held
##              (its instances, dappled crown shadow and collider gone, its crown off the canopy map, a stump,
##              the fall away from the player, a hit on someone in its path), the trunk bucked into logs, a
##              sapling cut with E, a rock broken into stone with the mattock (8) until it is gone (collider,
##              ledges), the tool put away, a weapon drawn over it, the torch (a tool taken out tosses it down burning; a torch taken into the hand sends the tool back)
##
##   Godot --headless --fixed-fps 120 --path . -s tests/gathering/test_gathering.gd -- --no-capture [only=skills,data,yields,level]
##
## Animation data the level part plays: animations_extra/Actor_B_from_A.res.

var failures := PackedStringArray()
var checks := 0
var player: FrontierPlayer
var gt: GatherTools
var only := ""
var report := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.get_slice("=", 1)
	if _on("skills"):
		_test_skills()
	if _on("data"):
		_test_data()
	if _on("yields"):
		_test_yields()
	if _on("level"):
		await _test_level()
	print("REPORT ", JSON.stringify(report))
	if failures.is_empty():
		print("GATHERING TEST PASSED (%d checks)" % checks)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("GATHERING TEST FAILED (%d of %d checks)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _on(part: String) -> bool:
	return only == "" or part in only.split(",")


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


# --- Skills ---------------------------------------------------------------------------------------

func _test_skills() -> void:
	var s := GatherSkills.new()
	var ups: Array = []
	s.leveled.connect(func(id: String, lvl: int, tier: Dictionary) -> void: ups.append([id, lvl, String(tier.get("id", ""))]))
	_check(s.level("woodcutting") == 0 and String(s.tier("woodcutting").id) == "novice", "fresh skills at 0, Novice")
	var g := s.award("woodcutting", 1.0)
	_check(absf(g - 1.0) < 1e-4 and s.level("woodcutting") == 1, "a 1-point award at level 0 gives a level (gain %.4f)" % g)
	_check(ups.size() == 1 and ups[0] == ["woodcutting", 1, ""], "level 1 announced without a tier: %s" % [ups])
	s.set_points("woodcutting", 19.6)
	ups.clear()
	s.award("woodcutting", 1.0)
	_check(ups.size() == 1 and int(ups[0][1]) == 20 and ups[0][2] == "apprentice", "crossing 20 announces Apprentice: %s" % [ups])
	s.set_points("mining", 45.0)
	var g45 := s.award("mining", 1.0)
	_check(absf(g45 - 0.5) < 0.01, "the level curve halves a gain at 45 (%.3f)" % g45)
	s.set_points("mining", 0.0)
	_check(is_equal_approx(s.power("mining"), 1.0) and is_equal_approx(s.speed("mining"), 1.0), "level 0 works at x1")
	s.set_points("mining", 100.0)
	_check(is_equal_approx(s.power("mining"), 1.8) and is_equal_approx(s.speed("mining"), 1.25)
			and is_equal_approx(s.yield_bonus("mining"), 1.0), "level 100 works at the data's at_100")
	var ups2: Array = []
	s.leveled.connect(func(id: String, lvl: int, _t: Dictionary) -> void: ups2.append(lvl))
	s.set_points("building", 99.9)
	s.award("building", 5.0)
	_check(s.points_of("building") <= 100.0 and s.level("building") == 100, "skills cap at 100")
	var s2 := GatherSkills.new()
	s2.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	_check(is_equal_approx(s2.points_of("mining"), 100.0) and is_equal_approx(s2.points_of("woodcutting"), s.points_of("woodcutting")),
			"save round trip")
	_check(s.describe("woodcutting").begins_with("Woodcutting 20"), "describe(): %s" % s.describe("woodcutting"))
	_check(s.tier_text("woodcutting", "apprentice") != "", "tier lines in the data")
	# pacing: trees of 0.6 m at level 0 on, with the strokes they take, to Apprentice (20) and Journeyman (40)
	var p := GatherSkills.new()
	var data := GatherData.get_default()
	var trees := 0
	var trees_20 := -1
	while p.level("woodcutting") < 40 and trees < 500:
		var need := 5.0 * pow(0.6 / 0.3, 1.3) * 1.0
		var strokes := ceili(need / p.power("woodcutting"))
		for k in strokes:
			p.award("woodcutting", p.xp("woodcutting", "stroke"))
		p.award("woodcutting", maxf(p.xp("woodcutting", "felled_per_m") * 0.6, p.xp("woodcutting", "felled_min")))
		for k in 4:
			p.award("woodcutting", p.xp("woodcutting", "log"))
		p.award("woodcutting", p.xp("woodcutting", "limbed"))
		trees += 1
		if trees_20 < 0 and p.level("woodcutting") >= 20:
			trees_20 = trees
	report["trees_to_apprentice"] = trees_20
	report["trees_to_journeyman"] = trees
	_check(trees_20 >= 6 and trees_20 <= 40, "Apprentice after %d trees of 0.6 m (want 6-40)" % trees_20)
	_check(trees > trees_20 * 1.3, "Journeyman takes longer than Apprentice (%d vs %d trees)" % [trees, trees_20])
	_check(data.tiers.size() == 5, "the survival tiers are read (%d)" % data.tiers.size())


# --- Data -------------------------------------------------------------------------------------------

func _test_data() -> void:
	var d := GatherData.get_default()
	var ld := LoadoutData.get_default()
	for kind: String in d.tools:
		# (retired 2026-10-02, the owner: "no more rigs on the char slots": which rig place a tool's loadout class lets it hang
		# on was the Tab screen's rig placement, gone; what a tool rides on the body now follows the hotbar, Hotbar. Was:
		# ld.kind_class(kind) == "tool", or "belt" for a blade that works nothing, in loadout_items.json)
		_check(InventoryState.name_of(kind) == d.name_of(kind), "%s: inventory name %s" % [kind, InventoryState.name_of(kind)])
		var tm := GatherModels.build(kind)
		_check(tm != null and tm.has_node("Edge") and tm.has_node("Grip"), "%s has a model with its markers" % kind)
		if tm:
			tm.free()
	for item: String in d.items:
		_check(InventoryState.NAMES.has(item), "%s has an inventory name" % item)
		var m := GatherModels.build(item)
		_check(m != null, "%s has a model" % item)
		if m:
			m.free()
	var lo := Loadout.from_preset(ld.default_preset())
	var r := LoadoutRules.can_carry(lo, "felling_axe", ld)
	_check(bool(r.ok) and String(r.point) == "tool_loop", "the axe can ride the pack's tool loop: %s" % [r])
	lo.add_item("felling_axe", ["tool_loop"], 1)
	var errs := LoadoutRules.validate(lo, ld)
	_check(errs.is_empty(), "a loadout with the axe on the loop is legal: %s" % [errs])
	var r2 := LoadoutRules.can_carry(lo, "mattock", ld)
	_check(not bool(r2.ok) or String(r2.action) == "swap", "only one tool on the loop: %s" % [r2])
	var inv := InventoryState.new()
	inv.data = ld
	inv.worn = lo
	inv.add("log", 2)
	inv.add("log", 3)
	_check(inv.pack_count("log") == 5 and inv.pack.size() == 1, "logs stack in the pack")
	_check(inv.take("log", 7) == 5 and inv.pack_count("log") == 0, "take() takes what is there")
	_check("tool_loop" in inv.points(), "the inventory lists the tool loop")
	# a quarried rock's ledges and beams go (VegHarvest -> TravLedgeGraph.remove_source)
	var g := TravLedgeGraph.new()
	g.add_ledge(PackedVector3Array([Vector3(0, 1, 0), Vector3(1, 1, 0)]), Vector3.FORWARD, {"source": "/root/a"})
	g.add_ledge(PackedVector3Array([Vector3(0, 1, 2), Vector3(1, 1, 2)]), Vector3.FORWARD, {"source": "/root/b"})
	g.add_beam(Vector3(0, 0.5, 5), Vector3(2, 0.5, 5), 0.3, {"source": "/root/a"})
	var n := g.remove_source("/root/a")
	_check(n == 2 and g.ledges.size() == 1 and g.beams.is_empty(), "remove_source drops a shape's ledges and beams (%d)" % n)
	_check(g.query_near(Vector3(0.5, 1, 0), 0.5).is_empty() and not g.query_near(Vector3(0.5, 1, 2), 0.5).is_empty(),
			"and its spatial hash entries")
	_check(inv.kinds_at("tool_loop").has("mattock"), "the tool loop takes the mattock")


# --- Yields -----------------------------------------------------------------------------------------

func _test_yields() -> void:
	var g := GatherTools.new()
	g.data = GatherData.get_default()
	g.skills = GatherSkills.new()
	var pine := g.strokes_to_fell({"radius": 0.15, "species": "white_pine"})
	var oak := g.strokes_to_fell({"radius": 0.15, "species": "oak"})
	var big := g.strokes_to_fell({"radius": 0.35, "species": "white_pine"})
	report["strokes_pine_30cm"] = pine
	report["strokes_oak_30cm"] = oak
	report["strokes_pine_70cm"] = big
	_check(absf(pine - 4.0) < 0.01, "a 30 cm white pine takes 4 strokes at level 0 (%.2f)" % pine)
	_check(oak > pine * 1.6, "oak is harder than pine (%.1f vs %.1f)" % [oak, pine])
	_check(big > 11.0 and big < 18.0, "a 70 cm white pine takes 11-18 strokes (%.1f)" % big)
	g.skills.set_points("woodcutting", 100.0)
	_check(ceili(big / g.skills.power("woodcutting")) < ceili(big), "a Master fells it in fewer strokes")
	_check(g.sapling_strokes() == 1, "a skilled hand cuts a sapling in one stroke")
	g.skills.set_points("woodcutting", 0.0)
	_check(g.sapling_strokes() == 2, "a Novice takes two")
	_check(is_equal_approx(g.log_quality(), 0.7), "a Novice gets 70 % good logs")
	var ft := FelledTree.create({"i": 1, "pos": Vector3.ZERO, "height": 22.0, "radius": 0.3, "crown_radius": 4.5,
			"crown_bottom": 8.0}, Vector3.FORWARD, g.data.felling, false)
	_check(ft.logs_total == 5, "a 22 m tree gives 5 logs (%d)" % ft.logs_total)
	var cy := ft.crown_yield()
	_check(int(cy.firewood) >= 2 and int(cy.branches) >= 3, "the crown gives firewood and branches: %s" % [cy])
	ft.free()
	g.free()


# --- The level --------------------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


## Puts the player `gap` m from the surface of something round at `pos` (radius r), facing it, from `from`.
func _stand_at(pos: Vector3, r: float, gap: float, from: Vector3) -> void:
	var d := Vector3(pos.x - from.x, 0.0, pos.z - from.z)
	d = d.normalized() if d.length() > 1e-3 else Vector3.FORWARD
	var at := pos - d * (r + gap)
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw
	player.pitch = deg_to_rad(-10.0)


func _tap(action: StringName, frames := 3) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	await _frames(2)


func _test_level() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node_or_null("Player") if current_scene else null
	_check(player != null, "level loads with a player")
	if player == null:
		return
	player.ignore_mouse_capture = true
	await _frames(40)
	gt = player.gather
	_check(gt != null and gt.pose != null, "the player has GatherTools and its ToolPose")
	if gt == null:
		return
	_check(gt.on_loop == "felling_axe", "the axe rides the pack's tool loop (%s)" % gt.on_loop)
	_check(gt.owns("mattock") and gt.owns("felling_axe"), "both tools are the player's")
	var h := VegHarvest.find(self)
	_check(h != null, "VegHarvest finds the level's vegetation")
	if h == null:
		return
	await _level_fell(h)
	await _level_sapling(h)
	await _level_rock(h)
	await _level_weapon_over_tool()
	await _level_torch()


func _level_fell(h: VegHarvest) -> void:
	# the smallest canopy tree with a collider within 60 m of the spawn, off the fort
	var spawn := player.global_position
	var best := -1
	var best_r := INF
	for i in h.lay.tree_pos.size():
		if int(h.lay.tree_kind[i]) >= VegHarvest.Assets.CANOPY_COUNT or h.lay.tree_collider[i] == 0:
			continue
		var p: Vector3 = h.lay.tree_pos[i]
		if p.distance_to(spawn) > 60.0 or absf(p.x) < 22.0 and absf(p.z) < 22.0:
			continue
		var d := h.describe("tree", "tree", i)
		if float(d.radius) < best_r and float(d.height) > 8.0:
			best_r = float(d.radius)
			best = i
	_check(best >= 0, "a tree near the spawn to fell")
	if best < 0:
		return
	var tree := h.describe("tree", "tree", best)
	_check(h.has_trunk_collider(best), "the tree has its trunk collider before")
	# the forest light's parts of it (built with the visuals: windowed runs only)
	var lit := VegHarvest.CanopyMap.image != null and _dapple_scale(h, best) >= 0.0
	var cover0 := VegHarvest.CanopyMap.cover_at(tree.pos.x, tree.pos.z)
	if lit:
		_check(_dapple_scale(h, best) > 0.05, "the tree casts its dappled crown shadow before (scale %.2f)" % _dapple_scale(h, best))
	_stand_at(tree.pos, float(tree.radius), 1.0, tree.pos + Vector3(3, 0, 1))
	await _frames(12)
	_check(String(gt.target.get("type", "")) == "tree" and int(gt.target.get("i", -1)) == best,
			"the tree in front is the target: %s" % [gt.target.get("type", ""), ])
	_check(gt.prompt().begins_with("Fell the"), "prompt: %s" % gt.prompt())
	await _tap(&"tool_axe")
	var drawn := await _until(func() -> bool: return gt.phase == GatherTools.Phase.READY, 400)
	_check(drawn and gt.tool == "felling_axe" and player.hands_free, "7 draws the axe (weapon put away, hands free)")
	var strokes := [0]
	gt.stroke_landed.connect(func(kind: String, _i: Dictionary) -> void:
		if kind == "tree":
			strokes[0] += 1)
	var felled := [null]
	gt.felled.connect(func(ft: FelledTree) -> void: felled[0] = ft)
	var need := gt.strokes_to_fell(tree)
	# the crosshair low on the trunk: the cut goes in there (GatherTools._aim_height; user 2026-10-01 "it cuts where the axe is")
	player.pitch = -0.6
	await _frames(4)
	Input.action_press(&"fire")
	var ok := await _until(func() -> bool: return felled[0] != null, 120 * 60)
	Input.action_release(&"fire")
	report["fell_strokes"] = strokes[0]
	report["fell_need"] = need
	_check(ok, "holding LMB fells the tree (%d strokes landed, %.1f needed)" % [strokes[0], need])
	if not ok:
		return
	_check(strokes[0] == ceili(need - 1e-4), "strokes = ceil(needed) at level 0 (%d vs %.2f)" % [strokes[0], need])
	_check(h.felled.has(best) and not h.has_trunk_collider(best), "the felled tree's collider is gone")
	# the forest light: its dappled crown shadow gone, its crown off the canopy map (the sky opens over the stump)
	var cover1 := VegHarvest.CanopyMap.cover_at(tree.pos.x, tree.pos.z)
	report["canopy_cover_felled"] = [cover0, cover1] if lit else "skipped: no visuals headless"
	if lit:
		_check(_dapple_scale(h, best) < 0.01, "the felled tree's dappled crown shadow is gone")
		_check(cover1 < cover0 - 0.02 or cover0 > 0.97, "its crown is off the canopy map (cover %.2f -> %.2f)" % [cover0, cover1])
	_check(h.describe("tree", "tree", best).is_empty(), "the felled tree is no longer a target")
	var stumps := current_scene.find_children("Stump_*", "StaticBody3D", false, false)
	_check(stumps.size() == 1 and (stumps[0] as Node).is_in_group(FrontierVegetation.LOW_GROUP), "a stump stays (low: a horse steps over)")
	_check(ft_cut_ok(stumps), "cut low, where the axe went in: the stump is under 0.7 m (%.2f m; pitch %.2f, cam y %.2f, feet %.2f)" % [((stumps[0] as Node).get_child(0).shape as CylinderShape3D).height - 0.3 if not stumps.is_empty() else -1.0, player.pitch, player.camera.global_position.y, player.global_position.y])
	var ft: FelledTree = felled[0]
	_check(ft.state == FelledTree.State.FALLING, "the tree is falling")
	var away := Vector3(tree.pos.x - player.global_position.x, 0, tree.pos.z - player.global_position.z).normalized()
	_check(ft.fall_dir.dot(away) > cos(deg_to_rad(31.0)), "it falls away from the player (within the Novice's 30 deg: %.0f deg)"
			% rad_to_deg(acos(clampf(ft.fall_dir.dot(away), -1, 1))))
	# someone standing in its path is hit: the player steps in under the falling crown
	var hp0 := player.health
	var hits := [0.0]
	ft.struck.connect(func(_n: Node, dmg: float) -> void: hits[0] += dmg)
	await _until(func() -> bool: return ft.theta > deg_to_rad(25.0), 120 * 8)
	var path_pt := ft.hinge + ft.fall_dir * ft.length * 0.55
	path_pt.y = FrontierTerrain.height_at(path_pt.x, path_pt.z) + 0.05
	player.global_position = path_pt
	player.velocity = Vector3.ZERO
	var down := await _until(func() -> bool: return ft.is_down(), 120 * 12)
	report["fall_hit_damage"] = hits[0]
	_check(hits[0] > 0.0 and player.health < hp0, "the falling tree hurts the player in its path (%.0f damage)" % hits[0])
	_check(down, "the tree comes to rest")
	report["fall_rest_deg"] = rad_to_deg(ft.theta)
	_check(ft.theta > deg_to_rad(60.0) and ft.theta < deg_to_rad(110.0), "it lies on the ground (%.0f deg from upright)" % rad_to_deg(ft.theta))
	_check(ft.trunk_body != null, "the fallen trunk has a collider")
	if player.is_dead:
		player.respawn()
		await _frames(30)
	player.health = player.max_health
	# buck it: stand beside the bole's middle
	var mid := ft.hinge + ft.axis() * minf(float(ft.info.crown_bottom), ft.length) * 0.5
	var side := ft.fall_dir.cross(Vector3.UP).normalized()
	_stand_at(Vector3(mid.x, 0, mid.z), float(ft.info.radius), 0.9, mid + side * 3.0)
	await _frames(12)
	_check(String(gt.target.get("type", "")) == "trunk", "the fallen trunk is the target: %s" % [gt.target.get("type", "")])
	_check(gt.prompt().begins_with("Buck the"), "prompt: %s" % gt.prompt())
	var inv0 := InventoryState.from_player(player)
	var logs0 := inv0.pack_count("log") + inv0.pack_count("firewood")
	var total := ft.logs_total
	Input.action_press(&"fire")
	var bucked := await _until(func() -> bool: return not is_instance_valid(ft) or ft.state == FelledTree.State.GONE, 120 * 90)
	Input.action_release(&"fire")
	_check(bucked, "holding LMB bucks the trunk into logs and limbs it")
	var inv := InventoryState.from_player(player)
	report["logs"] = inv.pack_count("log")
	report["firewood"] = inv.pack_count("firewood")
	report["branches"] = inv.pack_count("branches")
	_check(inv.pack_count("log") >= 1 and inv.pack_count("log") <= total, "logs in the pack (%d of %d lengths)" % [inv.pack_count("log"), total])
	_check(inv.pack_count("firewood") >= 1 and inv.pack_count("branches") >= 1, "firewood and branches from the crown")
	report["woodcutting"] = gt.skills.points_of("woodcutting")
	_check(gt.skills.points_of("woodcutting") > 0.5, "Woodcutting grew (%.2f)" % gt.skills.points_of("woodcutting"))
	await _frames(200)
	_check(not is_instance_valid(ft), "the bucked tree is gone")


## Scale of tree i's instance in its cell's dappled crown casters (TreeDapple_*: forest light), -1 when none.
func _dapple_scale(h: VegHarvest, i: int) -> float:
	var p: Vector3 = h.lay.tree_pos[i]
	var c := FrontierVegetation.tree_cell(p)
	var mmi := h.veg.get_node_or_null("Visuals/TreeDapple_%d_%d" % [c.x, c.y]) as MultiMeshInstance3D
	if mmi == null:
		return -1.0
	for j in mmi.multimesh.instance_count:
		var t := mmi.multimesh.get_instance_transform(j)
		if t.origin.distance_to(p) < 0.01:
			return t.basis.get_scale().y
	return -1.0


func _level_sapling(h: VegHarvest) -> void:
	var p := player.global_position
	var near := h.near(p, 120.0).filter(func(d: Dictionary) -> bool: return String(d.type) == "sapling")
	if near.is_empty():
		# headless levels have no undergrowth (FrontierVegetation lays out clutter only with visuals) and the tree
		# arrays hold no saplings on this level: the sapling cut is checked by tests/gathering/felling_shots.gd
		report["sapling"] = "skipped: no saplings headless"
		return
	var sp: Dictionary = near[0]
	_stand_at(sp.pos, float(sp.radius), 0.7, sp.pos + Vector3(-2, 0, 1))
	await _frames(12)
	_check(String(gt.target.get("type", "")) == "sapling", "the sapling is the target (%s)" % gt.target.get("type", ""))
	var poles0 := InventoryState.from_player(player).pack_count("pole")
	var need := gt.sapling_strokes()
	for k in need:
		# E at the sapling: the interactor's target is the gathering target
		await _until(func() -> bool: return player.interactor.target == gt.gather_target, 60)
		await _tap(ThrownPickup.INTERACT)
		await _until(func() -> bool: return gt.phase == GatherTools.Phase.READY, 240)
	await _frames(60)
	var poles := InventoryState.from_player(player).pack_count("pole")
	_check(poles == poles0 + 1, "E cuts the sapling in %d strokes: a pole (%d -> %d)" % [need, poles0, poles])
	_check(h.cut.has("%s:%d" % [sp.src, int(sp.i)]), "the sapling is gone")


func _level_rock(h: VegHarvest) -> void:
	var p := player.global_position
	var best := {}
	var bd := INF
	for i in h.lay.prop_pos.size():
		var k: int = h.lay.prop_kind[i]
		if k < VegHarvest.Assets.ROCK_FIRST or k > VegHarvest.Assets.ROCK_LAST:
			continue
		var d := h.describe("rock", "prop", i)
		var dist := (d.pos as Vector3).distance_to(p)
		if dist < bd and String(d.name) in ["rock_d", "rock_e", "rock_a", "rock_b", "rock_c"]:
			bd = dist
			best = d
	_check(not best.is_empty(), "a rock on the level")
	if best.is_empty():
		return
	var i := int(best.i)
	var cs := h.rock_collider(i)
	_check(cs != null, "the rock has its collider")
	var src := str(cs.get_path()) if cs else ""
	var ctl: Variant = player.traversal.controller if player.traversal and player.traversal.world_ready else null
	var ledges_before := 0
	if ctl:
		for id: int in ctl.ledges.ledges:
			if str(ctl.ledges.ledges[id].get("source", "")) == src:
				ledges_before += 1
	report["rock_ledges_before"] = ledges_before
	_stand_at(best.pos, float(best.radius), 0.55, best.pos + Vector3(2, 0, -2))
	await _frames(12)
	_check(String(gt.target.get("type", "")) == "rock", "the rock is the target (%s, %s)" % [gt.target.get("type", ""), best.name])
	if String(gt.target.get("type", "")) != "rock":
		# try the other sides
		for off in [Vector3(-2, 0, 2), Vector3(2, 0, 2), Vector3(-2, 0, -2)]:
			_stand_at(best.pos, float(best.radius), 0.4, best.pos + off)
			await _frames(12)
			if String(gt.target.get("type", "")) == "rock":
				break
	await _tap(&"tool_mattock")
	var out := await _until(func() -> bool: return gt.tool == "mattock" and gt.phase == GatherTools.Phase.READY, 600)
	_check(out, "8 swaps the axe for the mattock (%s, phase %d)" % [gt.tool, gt.phase])
	var st := gt.rock_state(i)
	var total := int(st.total)
	var stones0 := InventoryState.from_player(player).pack_count("stone")
	Input.action_press(&"fire")
	var some := await _until(func() -> bool: return int(gt.rock_state(i).left) <= total - 2, 120 * 40)
	_check(some, "the mattock breaks stone from the %s" % best.name)
	_check(float(h.rock_size.get(i, 1.0)) < 1.0, "the rock is smaller (%.2f)" % float(h.rock_size.get(i, 1.0)))
	if int(gt.rock_state(i).left) > 0:
		var cs2 := h.rock_collider(i)
		_check(cs2 != null and cs2.shape is ConvexPolygonShape3D and cs2.shape != h.get("_rock_shape").get(i),
				"a partly quarried rock keeps a smaller hull of its own")
	if ctl:
		var after := 0
		for id: int in ctl.ledges.ledges:
			if str(ctl.ledges.ledges[id].get("source", "")) == src:
				after += 1
		_check(after == 0, "its traversal ledges are dropped (%d -> %d)" % [ledges_before, after])
	var gone := await _until(func() -> bool: return int(gt.rock_state(i).left) <= 0, 120 * 150)
	Input.action_release(&"fire")
	report["rock_total_stones"] = total
	_check(gone, "the rock is broken up (%d stones)" % total)
	_check(h.rock_collider(i) == null and float(h.rock_size.get(i, 1.0)) <= 0.0, "its collider is gone")
	var inv := InventoryState.from_player(player)
	report["stones"] = inv.pack_count("stone") - stones0
	report["flint"] = inv.pack_count("flint")
	_check(inv.pack_count("stone") - stones0 >= total, "all its stone is in the pack (%d of %d)" % [inv.pack_count("stone") - stones0, total])
	report["mining"] = gt.skills.points_of("mining")
	_check(gt.skills.points_of("mining") > 0.5, "Mining grew (%.2f)" % gt.skills.points_of("mining"))
	await _tap(&"tool_mattock")
	var away := await _until(func() -> bool: return gt.tool == "" and gt.phase == GatherTools.Phase.IDLE, 400)
	_check(away, "8 again puts the mattock away")
	# a rock the traversal baked ledges on loses them when it is first quarried
	if ctl:
		var by_src := {}
		for id: int in ctl.ledges.ledges:
			by_src[str(ctl.ledges.ledges[id].get("source", ""))] = true
		var with_ledges := -1
		for j in h.lay.prop_pos.size():
			var kk: int = h.lay.prop_kind[j]
			if kk < VegHarvest.Assets.ROCK_FIRST or kk > VegHarvest.Assets.ROCK_LAST or h.rock_size.has(j):
				continue
			var c := h.rock_collider(j)
			if c and by_src.has(str(c.get_path())):
				with_ledges = j
				break
		# (the traversal bake finds no ledges on this level's rocks today; TravLedgeGraph.remove_source is
		# checked on its own in _test_data)
		report["rock_with_ledges"] = with_ledges
		if with_ledges >= 0:
			var sp := str(h.rock_collider(with_ledges).get_path())
			h.shrink_rock(with_ledges, 0.9)
			var left := 0
			for id: int in ctl.ledges.ledges:
				if str(ctl.ledges.ledges[id].get("source", "")) == sp:
					left += 1
			_check(left == 0, "a quarried rock's ledges are dropped (%d left)" % left)
			var hull := h.rock_collider(with_ledges)
			_check(hull != null and hull.shape is ConvexPolygonShape3D, "a quarried rock keeps a (smaller) hull")


func _level_weapon_over_tool() -> void:
	await _tap(&"tool_axe")
	await _until(func() -> bool: return gt.phase == GatherTools.Phase.READY, 400)
	player.switch_weapon("musket")
	await _frames(30)
	_check(gt.tool == "" and not player.hands_free, "drawing a weapon puts the tool back (tool '%s')" % gt.tool)
	_check(gt.on_loop == "felling_axe", "the axe is back on the loop")


## The torch (PlayerTorch) and the tools, which take both hands.
func _level_torch() -> void:
	var tr: PlayerTorch = player.torch
	_check(tr != null, "the player has PlayerTorch")
	if tr == null:
		return
	if not player.hands_free:
		player.toggle_hands_free()
		await _until(func() -> bool: return player.hands_free and not player.is_switching(), 200)
	_check(tr.take_out() and tr.holding(), "a torch into the left hand")
	await _frames(10)
	await _tap(&"tool_axe")
	var out := await _until(func() -> bool: return gt.phase == GatherTools.Phase.READY, 500)
	_check(out and not tr.holding(), "taking out the axe with a torch in the hand: the axe out (%s), the torch left the hand (%s)"
			% [out, not tr.holding()])
	var d := tr.last_dropped
	_check(d != null and is_instance_valid(d) and d.state != null and d.state.lit, "the torch lies on the ground, still burning")
	_check(tr.take_out() and tr.holding(), "another torch into the hand with the axe out (T)")
	var back := await _until(func() -> bool: return gt.tool == "" and gt.phase == GatherTools.Phase.IDLE, 400)
	_check(back and gt.on_loop == "felling_axe", "the torch sends the axe back to the loop (tool '%s')" % gt.tool)
	tr.put_away()


func ft_cut_ok(stumps: Array) -> bool:
	if stumps.is_empty():
		return false
	var cs := (stumps[0] as Node).get_child(0) as CollisionShape3D
	return cs != null and (cs.shape as CylinderShape3D).height - 0.3 < 0.7
