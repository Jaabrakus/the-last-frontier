extends SceneTree
## Throwing spears by their heads (user 2026-09-29, after Ben Kilner's "I Made Mankind's Oldest Weapons": "wood spear
## designs stone spear and etc"), on the level with the real player and the survival bridge, headless:
##
##   Godot --headless --path . -s tests/survival_game/test_spear_heads.gd -- survival=on survival_seed=7
##
##   models     every head builds (spear_wood, _bone, _antler, _flint): spear.glb's shaft with its iron head cut away,
##              the markers where the iron spear has them
##   making     the knapping stone makes a fire-hardened spear and a bone-tipped one (the pair full after: the next row
##              says so); the hand shows the next spear's head
##   throwing   the next spear flies with its head's model, grade and damage (wood 0.55 of iron) and comes back as the
##              same spear when picked up
##   saving     WeaponState keeps the heads
## Ends with "SPEAR HEADS TEST OK (<n> checks)" or "SPEAR HEADS TEST FAILED <failures>/<n>".

func _initialize() -> void:
	_run.call_deferred()


var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var player: FrontierPlayer
var mode: BuildMode
var spot := Vector3(24.0, 0.0, 10.0)


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


func place(type: String, at: Vector3) -> BuiltPiece:
	await stand(at + Vector3(0, 0, 4.0))
	mode.set_active(true)
	mode.select_type(type)
	mode.aim_at = at
	for i in 6:
		await physics_frame
	mode.refresh_placement()
	var p := mode.place()
	mode.set_active(false)
	mode.aim_at = Vector3.INF
	return p


func wait_work(limit := 45.0) -> void:
	var t0 := Time.get_ticks_msec()
	while (b.work.working or player.kneeling != null) and Time.get_ticks_msec() - t0 < limit * 1000.0:
		await process_frame
	await frames(4)


func row(st: CampStation, id: String) -> Dictionary:
	for r: Dictionary in st.menu_rows(player):
		if String(r.get("id", "")) == id:
			return r
	return {}


func pack_state(kind: String) -> Dictionary:
	for e: Dictionary in InventoryState.from_player(player).pack:
		if String(e.kind) == kind:
			return e.get("state", {})
	return {}


func _run() -> void:
	# models
	for head in ["wood", "bone", "antler", "flint"]:
		var m := ThrowableModels.build("spear_" + head)
		var tip := ThrowableModels.marker_pos(m, "Tip")
		var shaft := m.get_node_or_null("Spear") as MeshInstance3D
		var cut_ok := shaft == null or shaft.get_aabb().position.z > ThrowableModels.SPEAR_SOCKET_Z - 0.01
		check(absf(tip.z + ThrowableModels.SPEAR_TIP) < 0.001 and m.get_node_or_null("COM") != null and cut_ok,
				"the %s spear builds: point at %.3f, the iron head cut away (%s)" % [head, tip.z, str(shaft.get_aabb().position.z) if shaft else "primitive shaft"])
		m.free()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(20)
	b = SurvivalBridge.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	check(b != null and player != null, "the level has the bridge (survival=on)")
	if b == null:
		_end()
		return
	player.ignore_mouse_capture = true
	mode = player.get_node_or_null("BuildMode") as BuildMode
	SurvivalWeather.set_external(b.core, "clear", 2.0, 250.0)
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	var w := (player.weapons as Dictionary).get("spear") as ThrowableSpear
	check(w != null, "the player has the throwing spear")
	if w == null:
		_end()
		return
	w.count = 0
	w.set_heads([])
	var p := await place("work_stone", spot)
	var st := p.get_node_or_null("Station") as CampStation if p else null
	check(st != null, "a knapping stone built")
	if st == null:
		_end()
		return
	await stand(st.global_position + Vector3(1.2, 0, 0))
	for k in [["pole", 6], ["bone", 2], ["sinew", 2], ["antler", 1], ["flint", 2], ["skinning_knife", 1]]:
		set_count(k[0], k[1])
	check(bool(row(st, "spear_wood").get("ok", false)) and bool(row(st, "spear_bone").get("ok", false)) and bool(row(st, "spear_antler").get("ok", false)),
			"the knapping stone offers the wood, bone and antler spears")
	check(st.make(player, "spear_wood"), "a fire-hardened spear started")
	await wait_work()
	check(st.make(player, "spear_bone"), "a bone-tipped spear started")
	await wait_work()
	check(w.count == 2 and w.heads.map(func(h): return h.head) == ["wood", "bone"], "two carried: %s" % str(w.heads))
	check(not bool(row(st, "spear_antler").get("ok", true)) and String(row(st, "spear_antler").get("detail", "")).contains("carry all"),
			"the pair is full: '%s'" % String(row(st, "spear_antler").get("detail", "")))
	check(w._shown == "spear_wood", "the hand shows the next spear's head (%s)" % w._shown)
	# throwing: the next spear flies as itself
	var tp := ThrownProjectile.new()
	tp.damage = 100.0
	w._configure_projectile(tp, Vector3.ZERO, Vector3.FORWARD, 15.0)
	check(tp.model_kind == "spear_wood" and is_equal_approx(tp.damage, 55.0) and tp.grade == "plain",
			"the wooden one flies: %s, damage %.1f, grade %s" % [tp.model_kind, tp.damage, tp.grade])
	w.count -= 1
	w.show_next()
	check(w.heads.size() == 1 and String(w.heads[0].head) == "bone" and w._shown == "spear_bone", "the bone one is next, in the hand")
	check(w.add_items_from(1, tp.model_kind, tp.grade) == 1 and String(w.heads[1].head) == "wood", "picked up, it comes back as the wooden one")
	tp.free()
	# saving
	var s := WeaponState.capture(w)
	w.set_heads([])
	WeaponState.apply(w, s)
	check(w.heads.map(func(h): return h.head) == ["bone", "wood"], "WeaponState keeps the heads: %s" % str(w.heads))
	_end()


func _end() -> void:
	if fails.is_empty():
		print("SPEAR HEADS TEST OK (%d checks)" % checks)
	else:
		print("SPEAR HEADS TEST FAILED %d/%d" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
