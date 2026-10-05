extends SceneTree
## The Sway's free use (the user, 2026-10-03: "lets make the spells free use right now"; moves.json free_use, read by
## SwayCaster.free_use: see SwayCaster's header) on the level's player in a plain New game (story off: no storyline), the
## hands free, survival on:
##   Godot --headless --fixed-fps 60 --path . -s tests/sway/test_free_use.gd -- survival=on
##   new game  the level installs the caster (SwayCaster.install_free): every spell known (known_spells == spells(), none
##             granted), every spell in the Tab screen's Spells list; after the hotbar's start kit none on the bar and none
##             readied (the owner: "pickups shouldnt auto fill"), and off the bar ready_spell still refuses; the first lock
##             is still a scripted lock (not a spell, not known)
##   grant     the story's grant (Gust, then the Form art): kept for the gating, no "learned" line, nothing on the bar or
##             readied; the save keeps only what was granted
##   load      a save from before (no moves, one mote, Gust's uses, Stone Form's mode) loaded: every spell still known, the
##             uses and the mode back
##   free      every spell an expert's (tier 2, "expert": the user saw "untrained" on the free spells); Gust readied from the
##             bar and cast on a crate: the lock as an expert's (x0.8), a use counted (no "mastered"), the motes
##             unchanged; with the belt empty a cast is not refused (no "motes"); a stone (a 60 kg boulder) held and hurled:
##             the motes unchanged; another held 7 s: Gust's stone never breaks (hold.no_break: no strain), let go it is
##             hurled; Gust's easy rules: a crate 3 deg off the crosshair still locks (its 6 deg aim zone, _cone_pick), and held
##             3 s past the click it does not fizzle, let go it casts; a sail held
##             past two drains: no mote spent, still held; the HUD's spell line names no motes; Earth Wall (a Form spell)
##             cast with the belt empty: the wall up, the motes unchanged
##   far/why   Stone Form aimed 40 m down the lane, past its reach: the circle at the reach's edge on the aim's line, the stone
##             thrown (FormCast._edge_hit; the user: "i use right click and nothing happens"); Gust held on the bare ground
##             and Mend on the sky: no lock, and a line says what to aim at (SwayCaster._say_why)
##   hint      the aim held with the hands free and nothing readied: no "No spell readied" line while no spell is on the bar
##             (every player knows every spell: not a sign of wanting one); with Gust on slot 9, "press its key (9)"
##   first     the wreck's first lock with nothing readied (Gust on the bar): the crosshair first off the spar, no "No spell
##             readied" line (a scripted lock in reach); then on it, a 3 s lock, cast
##   bound     a captive (Captivity.begin, a stand-in captor): Gust on the bar readied by its key, the aim held on a crate:
##             nothing locks (blocked "bound", "Your hands are bound"), nothing cast; the bonds off (end): it locks again
##   gated     free_use false (SwayCaster.free_override): the level would install nothing, a spell is known only once
##             granted (the grant's "learned" line again), a cast spends Gust's mote, an empty belt refuses ("motes"), the
##             HUD's line names the motes; a load with no caster (a plain game saved under free use, loaded with the switch
##             off: SwayCaster.load_of keeps the Sway part for install) drops the spells that save never granted off the bar
##             (Hotbar._has_spell), and keeps one it did
## Writes none of the user's files (no saves in a script run, no story: no tutorial_seen; HowTo is off in script runs).
## Ends with "FREE USE TEST PASSED (<n> checks)" or "FREE USE TEST FAILED (<f> of <n>)".

const LANE_X := -1.25
var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var c: SwayCaster
var ev := {"started": [], "locked": [], "cast": [], "broken": [], "motes": [], "hold": [], "hurled": [], "over": [], "lifted": []}


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	SwayCaster.free_override = null            # (moves.json's own switch)
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(s * Engine.physics_ticks_per_second))


func _ground(x: float, z: float) -> Vector3:
	var h := FrontierTerrain.height_at(x, z)
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, h + 3.0, z), Vector3(x, h - 3.0, z), 1, [player.get_rid()])
	var hit := (current_scene as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else Vector3(x, h, z)


func _place_player() -> void:
	player.global_position = _ground(LANE_X, -24.0) + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	player.pitch = 0.0


func _aim(p: Vector3) -> void:
	var d := p - player.camera.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = atan2(d.y, Vector2(d.x, d.z).length())


## Each tick the crosshair on `pt` for up to `limit` s, or until `cond` holds; the seconds it took (INF: never).
func _hold_on(pt: Callable, limit: float, cond := Callable()) -> float:
	var t := 0.0
	var dt := 1.0 / Engine.physics_ticks_per_second
	while t < limit:
		await physics_frame
		_aim(pt.call())
		if cond.is_valid() and cond.call():
			return t
		t += dt
	return INF if cond.is_valid() else t


func _release() -> void:
	Input.action_release("aim")
	await _ticks(3)


func _hands_free() -> void:
	for i in 16:
		if player.hands_free and not player.is_switching():
			break
		if not player.is_switching() and not player.hands_free:
			player.toggle_hands_free()
		await _secs(0.25)
	await _secs(0.4)


func _clear_ev() -> void:
	for k in ev:
		(ev[k] as Array).clear()


## Readies `id` as the player does: dragged onto slot 9 when it is not on the bar yet, then readied (its key).
func _ready_spell(id: String) -> bool:
	var hb := player.hotbar
	if id != "" and hb != null and hb.slot_of(Hotbar.SPELL, id) < 0:
		hb.assign(Hotbar.SLOTS - 1, Hotbar.make(Hotbar.SPELL, id))
	return c.ready_spell(id)


## Holds the aim on `pt` until the lock is full (or `limit`) and lets go: whether `spell` was cast.
func _cast(spell: String, pt: Callable, limit := 3.0) -> bool:
	_clear_ev()
	await _hold_on(pt, 0.12)
	Input.action_press("aim")
	var t := await _hold_on(pt, limit, func() -> bool: return c.state == SwayCaster.State.FULL)
	if t == INF:
		print("    (no full lock: state %s, move %s, hint '%s', blocked '%s')" % [SwayCaster.State.keys()[c.state], c.move, c.hint, c.blocked()])
	await _release()
	return not ev.cast.is_empty() and String(ev.cast[0][0]) == spell


func _crate(at: Vector3) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.name = "FreeUseCrate"
	b.mass = 6.0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3.ONE * 0.6
	cs.shape = bx
	b.add_child(cs)
	current_scene.add_child(b)
	b.global_position = at + Vector3.UP * 0.35
	return b


## A boulder (group sway_boulders) of `kg`: a fixed body with a rock's mesh, its weight in meta sway_mass_kg.
func _boulder(at: Vector3, kg: float, r := 0.35) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "FreeUseBoulder"
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = r
	cs.shape = sp
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = FormModels.ball_mesh(r, 17)
	b.add_child(mi)
	b.add_to_group(GustLift.BOULDERS)
	b.set_meta(&"sway_mass_kg", kg)
	current_scene.add_child(b)
	b.global_position = at + Vector3.UP * r
	return b


func _ids(entries: Array) -> Array:
	return entries.map(func(e: Dictionary) -> String: return String(e.id))


func _spells_on_bar() -> Array:
	var out := []
	for i in Hotbar.SLOTS:
		var e := player.hotbar.entry(i)
		if String(e.get("kind", "")) == Hotbar.SPELL:
			out.append("%d:%s" % [i + 1, String(e.id)])
	return out


func _notice() -> String:
	var lb: Variant = player.interactor.get(&"_notice") if player.interactor != null else null
	return (lb as Label).text if lb is Label else ""


func _run() -> void:
	for i in 25:
		await process_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	_expect(player != null, "the level has the player")
	if player == null:
		_end()
		return
	player.ignore_mouse_capture = true
	for i in 60:
		await process_frame
	_expect(SwayCaster.free_use() and bool(SwayMoves.data().get("free_use", false)), "moves.json's free_use is on")
	await _new_game()
	if c == null:
		_end()
		return
	_grant_and_load()
	_place_player()
	await _hands_free()
	_expect(player.hands_free and not player.is_switching(), "the player's hands are free (H)")
	_connect()
	await _free_casts()
	await _free_stones()
	await _free_sail()
	await _free_form()
	await _far_and_why()
	await _unreadied_hint()
	await _first_lock()
	await _bound()
	await _gated()
	await _gated_load()
	_end()


# ---------------------------------------------------------------- a new game
func _new_game() -> void:
	c = SwayCaster.of(player)
	_expect(c != null and StorySlice.find(self) == null, "a new game, story off: the level installed the caster (install_free)")
	if c == null:
		return
	var all := _ids(SwayCaster.spells())
	_expect(all.size() >= 5 and all.has("gust") and all.has("earth_wall") and all.has("stone_form") and all.has("pillar") and all.has("mend"),
			"the spells: %s" % str(all))
	_expect(_ids(c.known_spells()) == all and c.granted.is_empty(), "every spell known from the start, none granted (%s)" % str(_ids(c.known_spells())))
	_expect(not c.has("first_lock") and c.can_use("first_lock") and not SwayCaster.is_spell("first_lock"),
			"the first lock: still a scripted lock (no spell, usable on the target that names it)")
	var hb := player.hotbar
	await _secs(Hotbar.KIT_S + 0.5)
	_expect(hb != null and hb.kit_placed and _spells_on_bar().is_empty() and hb.spell == "" and c.readied_spell == "",
			"after the start kit no spell is on the hotbar (%s), none readied" % str(_spells_on_bar()))
	_expect(not c.ready_spell("gust") and c.readied_spell == "", "known is not readied: off the bar ready_spell still refuses")
	var scr := InventoryScreen.open_for(player)
	for i in 5:
		await process_frame
	var listed := []
	for r in scr._spells_list.get_children():
		if r is InventoryScreen.ListRow:
			listed.append(String((r as InventoryScreen.ListRow).payload.get("id", "")))
	_expect(listed == all and scr._spells_head.visible, "the Tab screen's Spells list has every spell (%s)" % str(listed))
	scr.close()
	for i in 3:
		await process_frame
	await _ticks(4)


# ---------------------------------------------------------------- the story's grant, a save
func _grant_and_load() -> void:
	var hb := player.hotbar
	player.interactor.notice("", 0.1)
	c.grant("gust")                          # (the story's sway_grant: First Lesson's Gust)
	_expect(c.has("gust") and c.granted.size() == 1 and c.granted[0] == "gust" and hb.slot_of(Hotbar.SPELL, "gust") < 0 and c.readied_spell == ""
			and not _notice().contains("learned"),
			"the story's grant of Gust: kept, no line ('%s'), not on the bar, not readied" % _notice())
	c.grant("form")                          # (Two Fires' grant of the Form spells)
	_expect(c.granted.size() == 5 and _spells_on_bar().is_empty() and not _notice().contains("learned"),
			"the story's grant of the Form art: kept (%s), no line" % str(c.granted))
	var sd := SwayCaster.save_of(player)
	_expect((sd.moves as Array).size() == 5 and (sd.moves as Array).has("gust"), "the save keeps only what was granted (%s)" % str(sd.moves))
	# a save from before free use: no moves, one mote, Gust's uses, Stone Form's mode
	c.granted.clear()
	SwayCaster.load_of(player, {"motes": 1, "floor_t": 0.0, "moves": [], "uses": {"gust": 7}, "modes": {"stone_form": "cannonball"}})
	_expect(_ids(c.known_spells()) == _ids(SwayCaster.spells()) and c.motes == 1 and c.uses_of("gust") == 7 and c.tier("gust") == 2
			and c.mode_of("stone_form") == "cannonball", "a loaded save: every spell still known, its mote (%d), uses (%d) and mode back, the spell an expert's" % [c.motes, c.uses_of("gust")])
	c.uses.clear()
	c.modes.clear()


func _connect() -> void:
	c.lock_started.connect(func(m: String, t: Node3D) -> void: ev.started.append([m, t]))
	c.locked.connect(func(m: String, t: Node3D) -> void: ev.locked.append([m, t]))
	c.cast.connect(func(m: String, t: Node3D) -> void: ev.cast.append([m, t]))
	c.lock_broken.connect(func(m: String, t: Node3D, why: String) -> void: ev.broken.append([m, t, why]))
	c.motes_changed.connect(func(n: int) -> void: ev.motes.append(n))
	c.hold_started.connect(func(m: String, t: Node3D) -> void: ev.hold.append([m, t]))
	c.hurled.connect(func(m: String, t: Node3D) -> void: ev.hurled.append([m, t]))
	c.overstrained.connect(func(m: String, t: Node3D) -> void: ev.over.append([m, t]))
	c.lifted.connect(func(t: Node3D) -> void: ev.lifted.append(t))


# ---------------------------------------------------------------- free: casts
func _free_casts() -> void:
	_place_player()
	await _secs(0.3)
	c.set_motes(c.belt_max)
	var crate := _crate(_ground(LANE_X, -32.0))
	await _secs(0.5)
	_expect(_ready_spell("gust") and c.readied_spell == "gust", "Gust dragged onto the bar and readied from it")
	_expect(SwayCaster.cost_of("gust") == 0 and SwayCaster.cost_of("earth_wall") == 0, "free use: nothing costs a mote (cost_of 0)")
	var all_expert := true
	for e: Dictionary in SwayCaster.spells():
		all_expert = all_expert and c.tier(String(e.id)) == 2 and c.tier_name(String(e.id)) == "expert"
	_expect(all_expert and c.uses_of("gust") == 0, "free use: every spell an expert's with no casts landed")
	var mastered: Array = []
	c.mastered.connect(func(m: String, t: int) -> void: mastered.append([m, t]))
	var m0 := c.motes
	var at := func() -> Vector3: return crate.global_position
	var ok := await _cast("gust", at)
	_expect(ok and is_equal_approx(c.lock_s, float(SwayMoves.move("gust").lock_s) * 0.8) and c.uses_of("gust") == 1 and mastered.is_empty() and not c.rooted,
			"Gust cast on a crate: the lock as an expert's (%.2f s), not rooted, a use counted (%d), no 'mastered' line" % [c.lock_s, c.uses_of("gust")])
	_expect(c.motes == m0 and ev.motes.is_empty(), "and the motes unchanged (%d of %d, %s)" % [c.motes, m0, str(ev.motes)])
	var line := String(player.hud.call(&"_spell_line", "gust")) if player.hud != null else ""
	_expect(line != "" and not line.contains("mote"), "the HUD's spell line names no motes ('%s')" % line)
	await _secs(1.0)
	crate.queue_free()
	# the belt empty: never refused
	var crate2 := _crate(_ground(LANE_X, -32.0))
	await _secs(0.5)
	c.set_motes(0)
	_clear_ev()
	var at2 := func() -> Vector3: return crate2.global_position
	ok = await _cast("gust", at2)
	_expect(ok and c.motes == 0 and c.hint != "motes" and ev.motes.is_empty(), "with the belt empty Gust is still cast (motes %d, hint '%s')" % [c.motes, c.hint])
	await _secs(1.0)
	crate2.queue_free()
	await _ticks(3)
	# Gust's easy rules: the aim zone catches a crate 3 deg off the crosshair, and full it never fizzles
	var crate3 := _crate(_ground(LANE_X, -32.0))
	await _secs(0.5)
	_clear_ev()
	var beside := func() -> Vector3:
		var cam := player.camera.global_position
		var to := crate3.global_position - cam
		return cam + to.rotated(Vector3.UP, deg_to_rad(3.0))
	await _hold_on(beside, 0.12)
	Input.action_press("aim")
	var tl := await _hold_on(beside, 1.5, func() -> bool: return c.state == SwayCaster.State.FULL)
	_expect(tl < 1.5 and c.target == crate3, "a crate 3 deg off the crosshair: Gust's aim zone locks it (%.2f s)" % tl)
	await _hold_on(beside, 3.0)
	_expect(c.state == SwayCaster.State.FULL and c.last_break != "fizzled", "held 3 s past the click: no fizzle, still full")
	await _release()
	_expect(not ev.cast.is_empty() and String(ev.cast[0][0]) == "gust", "let go then: cast")
	await _secs(1.0)
	crate3.queue_free()
	await _ticks(3)


# ---------------------------------------------------------------- free: stones
func _free_stones() -> void:
	_place_player()
	await _secs(0.3)
	c.set_motes(1)
	var light := _boulder(_ground(LANE_X + 0.8, -30.0), 60.0)
	await _ticks(3)
	var at := light.global_position
	var on_light := func() -> Vector3: return light.global_position
	_clear_ev()
	await _hold_on(on_light, 0.12)
	Input.action_press("aim")
	var t := await _hold_on(on_light, 2.5, func() -> bool: return c.state == SwayCaster.State.HOLDING)
	await _hold_on(on_light, 0.6)
	var up := light.global_position.y - at.y if is_instance_valid(light) else 0.0
	_expect(t < 2.5 and ev.hold.size() == 1 and up > 0.3 and c.motes == 1 and ev.motes.is_empty(),
			"Gust held on a 60 kg boulder: it rises (%.2f m), the motes unchanged (%d)" % [up, c.motes])
	await _release()
	await _secs(1.2)
	_expect(ev.hurled.size() == 1 and ev.cast.size() == 1 and c.motes == 1 and ev.motes.is_empty(),
			"let go: hurled (cast), the motes unchanged (%d)" % c.motes)
	if is_instance_valid(light):
		light.queue_free()
	# held long: Gust's stone never breaks (no strain), let go it is hurled
	_place_player()
	await _secs(0.3)
	var stone := _boulder(_ground(LANE_X + 0.8, -30.0), 60.0)
	await _ticks(3)
	var on_stone := func() -> Vector3: return stone.global_position
	_clear_ev()
	await _hold_on(on_stone, 0.12)
	Input.action_press("aim")
	t = await _hold_on(on_stone, 2.5, func() -> bool: return c.state == SwayCaster.State.HOLDING)
	var ahead := func() -> Vector3: return _ground(LANE_X, -40.0) + Vector3.UP * 1.5
	var strained := [0.0]
	await _hold_on(ahead, 7.0, func() -> bool:
		if c.hold != null and is_instance_valid(c.hold):
			strained[0] = maxf(float(strained[0]), c.hold.strain)
		return not ev.over.is_empty())
	_expect(t < 2.5 and ev.over.is_empty() and c.state == SwayCaster.State.HOLDING and float(strained[0]) == 0.0,
			"held 7 s: Gust's stone never breaks (no strain, still held)")
	await _release()
	await _ticks(2)
	_expect(not ev.hurled.is_empty() and c.motes == 1 and ev.motes.is_empty(), "let go: hurled, no mote spent (%d)" % c.motes)
	await _secs(0.5)
	if is_instance_valid(stone):
		stone.queue_free()
	await _ticks(3)


# ---------------------------------------------------------------- free: a sail
func _free_sail() -> void:
	_place_player()
	await _secs(0.3)
	c.set_motes(1)
	var sail := StaticBody3D.new()
	sail.name = "FreeUseSail"
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.4, 2.4, 0.1)
	cs.shape = bx
	sail.add_child(cs)
	sail.add_to_group(SwayCaster.SAIL_GROUP)
	current_scene.add_child(sail)
	sail.global_position = _ground(LANE_X, -32.0) + Vector3.UP * 2.0
	await _ticks(3)
	var at := func() -> Vector3: return sail.global_position
	var drain := float((SwayMoves.move("gust").get("sail", {}) as Dictionary).get("drain_s", 2.0))
	_clear_ev()
	Input.action_press("aim")
	var t := await _hold_on(at, 1.4, func() -> bool: return c.state == SwayCaster.State.HOLDING)
	await _hold_on(at, drain * 2.0 + 0.3)
	_expect(t < 1.4 and c.state == SwayCaster.State.HOLDING and c.motes == 1 and ev.motes.is_empty(),
			"Gust held on a sail past two drains (%.1f s each): still held, no mote spent (%d)" % [drain, c.motes])
	await _release()
	_expect(ev.cast.size() == 1 and c.state == SwayCaster.State.IDLE, "let go: slack, cast")
	sail.queue_free()
	await _ticks(3)


# ---------------------------------------------------------------- free: a Form spell
func _free_form() -> void:
	_place_player()
	await _secs(0.3)
	c.set_motes(0)                           # (Earth Wall's two motes: refused here were it not free)
	var g := _ground(LANE_X, -26.6)          # (within its 3.2 m; the wall freed after, so the lane ahead stays clear)
	var at := func() -> Vector3: return g
	var walls0 := get_nodes_in_group(FormRaised.GROUP).size()
	_expect(_ready_spell("earth_wall") and c.readied_spell == "earth_wall", "Earth Wall dragged onto the bar and readied from it")
	var ok := await _cast("earth_wall", at, 5.0)
	await _secs(0.3)
	var walls := get_nodes_in_group(FormRaised.GROUP)
	_expect(ok and c.uses_of("earth_wall") == 1 and walls.size() == walls0 + 1,
			"Earth Wall cast with the belt empty: the wall up (%d), a use counted" % (walls.size() - walls0))
	_expect(c.motes == 0 and ev.motes.is_empty() and c.hint != "motes", "and the motes unchanged (%d, %s)" % [c.motes, str(ev.motes)])
	for w in walls:
		w.queue_free()
	c.ready_spell("")
	var hb := player.hotbar
	var es := hb.slot_of(Hotbar.SPELL, "earth_wall")
	if es >= 0:
		hb.clear(es)
	await _secs(1.5)                         # (the stand after the floor cast)


# ---------------------------------------------------------------- an aim past the reach, and the reason said
func _far_and_why() -> void:
	_place_player()
	await _secs(0.3)
	var hb := player.hotbar
	# Stone Form aimed 40 m down the lane: raised before the caster and thrown on along the aim
	_expect(_ready_spell("stone_form") and c.readied_spell == "stone_form", "Stone Form readied")
	var far := _ground(LANE_X, -64.0)
	var at := func() -> Vector3: return far
	var before := get_nodes_in_group(FormStone.GROUP)
	var ok := await _cast("stone_form", at, 4.0)
	# (the lock's circle at the edge of the reach; the stone then throws itself on along the aim: the user, 2026-10-03,
	# "Stone Form throws itself", FormEffects.stone_form)
	var pk: Dictionary = c.form.last_pick
	var cp: Vector3 = pk.get("point", Vector3.INF)
	var reach := c.range_of("stone_form")
	var d := Vector2(cp.x - player.global_position.x, cp.z - player.global_position.z).length() if cp != Vector3.INF else INF
	await _secs(0.4)
	var fresh := get_nodes_in_group(FormStone.GROUP).filter(func(n: Node) -> bool: return not before.has(n))
	# (its circle is at the caster now, where the stone rises, aimed once at the release: the user, 2026-10-04, "its hard to
	# aim the stone spike"; it was at the reach's edge on the line of the aim)
	_expect(ok and fresh.size() == 1 and bool(pk.get("self", false)) and d < 2.5,
			"Stone Form aimed 40 m off: locked at the caster's feet (%.1f m away, its old reach %d m no matter), and thrown" % [d, roundi(reach)])
	for n in fresh:
		n.queue_free()
	c.ready_spell("")
	var ss := hb.slot_of(Hotbar.SPELL, "stone_form")
	if ss >= 0:
		hb.clear(ss)
	await _secs(0.6)
	# Gust held on the bare ground: nothing to lock on, and it says what to aim at
	_expect(_ready_spell("gust"), "Gust readied")
	player.interactor.notice("", 0.1)
	var ground := _ground(LANE_X, -29.0)
	await _hold_on(func() -> Vector3: return ground, 0.12)
	Input.action_press("aim")
	await _hold_on(func() -> Vector3: return ground, 0.6)
	_expect(c.state == SwayCaster.State.IDLE and c.hint == "none" and _notice().contains("aim at someone"),
			"Gust on the bare ground: no lock, a line says what to aim at ('%s')" % _notice())
	await _release()
	c.ready_spell("")
	var gs := hb.slot_of(Hotbar.SPELL, "gust")
	if gs >= 0:
		hb.clear(gs)
	# Mend held on the sky: nothing in reach, and it says what to aim at
	_expect(_ready_spell("mend"), "Mend readied")
	player.interactor.notice("", 0.1)
	var sky := player.global_position + Vector3(0.0, 40.0, -15.0)
	await _hold_on(func() -> Vector3: return sky, 0.12)
	Input.action_press("aim")
	await _hold_on(func() -> Vector3: return sky, 0.6)
	_expect(c.state == SwayCaster.State.IDLE and _notice().contains("Mend: aim at something built"),
			"Mend on the sky: no lock, a line says what to aim at ('%s')" % _notice())
	await _release()
	c.ready_spell("")
	var ms := hb.slot_of(Hotbar.SPELL, "mend")
	if ms >= 0:
		hb.clear(ms)
	await _secs(0.5)


# ---------------------------------------------------------------- the hint with nothing readied
func _unreadied_hint() -> void:
	_place_player()
	await _secs(0.3)
	var hb := player.hotbar
	c.ready_spell("")
	for i in Hotbar.SLOTS:
		if String(hb.entry(i).get("kind", "")) == Hotbar.SPELL:
			hb.clear(i)
	await _ticks(3)
	var ahead := func() -> Vector3: return _ground(LANE_X, -34.0)
	player.interactor.notice("", 0.1)
	await _ticks(2)
	await _hold_on(ahead, 0.12)
	Input.action_press("aim")
	await _hold_on(ahead, 0.4)
	_expect(_spells_on_bar().is_empty() and c.hint == "unreadied" and c.state == SwayCaster.State.IDLE and not _notice().contains("No spell readied"),
			"no spell on the bar, the aim held with the hands free: no 'No spell readied' line ('%s', hint '%s')" % [_notice(), c.hint])
	await _release()
	_expect(hb.assign(Hotbar.SLOTS - 1, Hotbar.make(Hotbar.SPELL, "gust")) and c.readied_spell == "", "Gust dragged onto slot 9, not readied")
	player.interactor.notice("", 0.1)
	await _ticks(2)
	Input.action_press("aim")
	await _hold_on(ahead, 0.4)
	_expect(_notice().begins_with("No spell readied: press its key (9)"), "with Gust on the bar: 'No spell readied: press its key (9)' ('%s')" % _notice())
	await _release()
	player.interactor.notice("", 0.1)
	await _ticks(2)


# ---------------------------------------------------------------- the first lock, unchanged
func _first_lock() -> void:
	_place_player()
	await _secs(0.3)
	c.ready_spell("")
	var spar := RigidBody3D.new()
	spar.name = "Spar"
	spar.mass = 40.0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(3.0, 0.3, 0.3)
	cs.shape = bx
	spar.add_child(cs)
	spar.add_to_group(SwayCaster.TARGET_GROUP)
	spar.set_meta(&"sway_move", "first_lock")
	spar.set_meta(&"sway_tag", "free_use_spar")
	spar.freeze = true
	current_scene.add_child(spar)
	spar.global_position = _ground(LANE_X, -30.0) + Vector3.UP * 0.2
	await _ticks(3)
	_clear_ev()
	var at := func() -> Vector3: return spar.global_position
	var beside := func() -> Vector3: return _ground(LANE_X + 4.0, -30.0)
	player.interactor.notice("", 0.1)
	await _hold_on(beside, 0.12)
	Input.action_press("aim")
	await _hold_on(beside, 0.4)
	_expect(_spells_on_bar().size() == 1 and c.state == SwayCaster.State.IDLE and c.hint == "unreadied" and not _notice().contains("No spell readied"),
			"at the spar with Gust on the bar, nothing readied, the crosshair beside it: no 'No spell readied' line ('%s', hint '%s')" % [_notice(), c.hint])
	await _hold_on(at, 1.5)
	_expect(c.state == SwayCaster.State.LOCKING and c.move == "first_lock" and c.fill > 0.4 and c.fill < 0.6 and c.readied_spell == "",
			"the wreck's first lock with nothing readied: a 3 s lock as before (%.2f after 1.5 s)" % c.fill)
	var t := await _hold_on(at, 2.0, func() -> bool: return c.state == SwayCaster.State.FULL)
	await _release()
	_expect(t < 2.0 and ev.cast.size() == 1 and ev.cast[0][0] == "first_lock", "and cast")
	await _secs(2.5)
	spar.queue_free()
	await _ticks(3)


# ---------------------------------------------------------------- a bound captive
func _bound() -> void:
	_place_player()
	await _secs(0.3)
	var hb := player.hotbar
	var captor := Node3D.new()
	captor.name = "FreeUseCaptor"
	current_scene.add_child(captor)
	captor.global_position = player.global_position + Vector3(1.5, 0.0, 0.0)
	var cap := Captivity.install(current_scene)
	var begun := cap.begin(player, captor, {"notice": ""})
	await _secs(1.0)
	_expect(begun and cap.bound and player.hands_free, "bound: a captive (Captivity.begin), the hands tied and free of anything")
	var gs := hb.slot_of(Hotbar.SPELL, "gust")
	if gs < 0:
		gs = Hotbar.SLOTS - 1
		hb.assign(gs, Hotbar.make(Hotbar.SPELL, "gust"))
	hb.select(gs)                            # (its key, as the player presses it)
	await _ticks(4)
	var crate := _crate(_ground(LANE_X, -30.0))
	await _secs(0.5)
	var at := func() -> Vector3: return crate.global_position
	_clear_ev()
	player.interactor.notice("", 0.1)
	await _hold_on(at, 0.12)
	Input.action_press("aim")
	await _hold_on(at, 1.5)
	_expect(c.blocked() == "bound" and c.state == SwayCaster.State.IDLE and ev.started.is_empty() and not c.readied
			and _notice().begins_with("Your hands are bound"),
			"bound, Gust readied from the bar ('%s'), the aim held on a crate: nothing locks (blocked '%s', '%s')" % [c.readied_spell, c.blocked(), _notice()])
	await _release()
	_expect(ev.cast.is_empty(), "nothing cast while bound")
	cap.end(true)
	await _ticks(4)
	await _hands_free()
	_expect(not cap.bound and c.blocked() == "", "the bonds off (end): nothing blocks a lock ('%s')" % c.blocked())
	if c.readied_spell != "gust":
		hb.select(gs)
		await _ticks(4)
	var ok := await _cast("gust", at)
	_expect(ok, "and Gust casts on the crate again")
	await _secs(1.0)
	crate.queue_free()
	captor.queue_free()
	cap.queue_free()
	c.ready_spell("")
	await _ticks(3)


# ---------------------------------------------------------------- gated: free_use false
func _gated() -> void:
	SwayCaster.free_override = false
	c.ready_spell("")
	c.granted.clear()
	c.uses.clear()
	player.hotbar.sync()                     # (the hotbar drops a spell the caster no longer has)
	await _ticks(4)
	_expect(not SwayCaster.free_use() and SwayCaster.install_free(player) == null, "free_use false: the level would install nothing")
	_expect(c.known_spells().is_empty() and not c.has("gust") and not c.ready_spell("gust") and _spells_on_bar().is_empty(),
			"no spell known until granted, none on the bar (%s)" % str(_spells_on_bar()))
	player.interactor.notice("", 0.1)
	c.grant("gust")
	_expect(c.has("gust") and _ids(c.known_spells()) == ["gust"] and _notice().contains("learned"),
			"the story's grant again: Gust known, its line ('%s')" % _notice())
	_expect(SwayCaster.cost_of("gust") == 1 and SwayCaster.cost_of("earth_wall") == 2, "the costs back (gust 1, earth wall 2)")
	_place_player()
	await _secs(0.3)
	c.set_motes(c.belt_max)
	var crate := _crate(_ground(LANE_X, -32.0))
	await _secs(0.5)
	_ready_spell("gust")
	var at := func() -> Vector3: return crate.global_position
	var ok := await _cast("gust", at)
	_expect(ok and c.motes == c.belt_max - 1, "a cast spends Gust's mote (%d left)" % c.motes)
	var line := String(player.hud.call(&"_spell_line", "gust")) if player.hud != null else ""
	_expect(line.contains("motes %d/%d" % [c.motes, c.belt_max]), "the HUD's spell line names the motes ('%s')" % line)
	await _secs(1.0)
	crate.queue_free()
	var crate2 := _crate(_ground(LANE_X, -32.0))
	await _secs(0.5)
	c.set_motes(0)
	_clear_ev()
	var at2 := func() -> Vector3: return crate2.global_position
	await _hold_on(at2, 0.12)
	Input.action_press("aim")
	await _hold_on(at2, 1.2)
	_expect(c.state == SwayCaster.State.IDLE and ev.started.is_empty() and c.hint == "motes",
			"an empty belt refuses the lock (hint '%s')" % c.hint)
	await _release()
	crate2.queue_free()
	SwayCaster.free_override = null


# ---------------------------------------------------------------- gated: a free-use save loaded with no caster
## A plain game saved under free use (Gust dragged onto slot 9, nothing granted) and loaded with the switch off: the level
## installs no caster, SwayCaster.load_of keeps the Sway part on the player for an install (meta sway_save), and the
## hotbar's slots come in as saved (SaveParts: the Sway part, then the bar's). The bar drops the spell that save never
## granted; one it granted stays.
func _gated_load() -> void:
	SwayCaster.free_override = false
	c.ready_spell("")
	var hb := player.hotbar
	var bar := Hotbar.save_of(player)
	var slots: Array = (bar.slots as Array).duplicate(true)
	slots[Hotbar.SLOTS - 1] = Hotbar.make(Hotbar.SPELL, "gust")
	bar["slots"] = slots
	player.remove_child(c)                   # (no caster: a plain game with the switch off)
	SwayCaster.load_of(player, {"motes": 3, "floor_t": 0.0, "moves": [], "uses": {}, "modes": {}})
	Hotbar.load_of(player, bar)
	hb.sync()
	await _ticks(3)
	_expect(SwayCaster.of(player) == null and player.has_meta(&"sway_save") and hb.slot_of(Hotbar.SPELL, "gust") < 0,
			"switch off, a free-use save with no caster: Gust (never granted) comes off the bar (%s)" % str(_spells_on_bar()))
	SwayCaster.load_of(player, {"motes": 3, "floor_t": 0.0, "moves": ["gust"], "uses": {}, "modes": {}})
	Hotbar.load_of(player, bar)
	hb.sync()
	await _ticks(3)
	_expect(hb.slot_of(Hotbar.SPELL, "gust") == Hotbar.SLOTS - 1, "and a save that granted it keeps it on slot 9 (%s)" % str(_spells_on_bar()))
	player.remove_meta(&"sway_save")
	player.add_child(c)
	SwayCaster.free_override = null
	await _ticks(3)


func _end() -> void:
	Input.action_release("aim")
	SwayCaster.free_override = null
	if fails.is_empty():
		print("FREE USE TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			printerr("FAIL: ", f)
		print("FREE USE TEST FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)
