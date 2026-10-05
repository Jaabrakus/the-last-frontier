extends SceneTree
## The Sway v2 (SwayCaster, SwayEffects, SwayRing, SwayPose, SwayThread; scripts/sway, data/sway/moves.json; docs/main_story.md
## section 11, the owner's rules 11.9-11.10) on the level's player, the hands free, survival on:
##   Godot --headless --fixed-fps 60 --path . -s tests/sway/test_sway.gd -- survival=on
##   install  SwayCaster.install(player) once (of() finds it again), the belt full (3); Gust granted (the story's sway_grant:
##            into the Tab screen's Spells list, not onto the hotbar, not readied: off the bar ready_spell refuses it; dragged
##            onto slot 9 it is readied, as the rest of the test readies it), the ring on screen
##   no spell Gust granted but not readied: the aim on a crate locks nothing, the camera stays; the pistol drawn and aimed at
##            it (RMB) is the pistol's own aim, no Gust (v1's accidental Gust is gone)
##   lock     Gust readied, untrained: the floor cast (own-form-clap-press) and the lock at x1.4 (0.84 s); the thread from the
##            palms from half; off it 0.08 s (in the grace) the lock holds; back on it is full (locked); let go: cast, a mote
##            spent, a use counted, the crate pushed away
##   break    the aim off it more than 0.15 s breaks the lock (no cast, no mote); so do a hit taken, sprinting (practised:
##            untrained, the floor cast holds the caster still and no sprint starts) and drawing a weapon
##   fizzle   held more than 1 s after full: it fizzles, the motes kept, and no new lock until the aim is let go
##   mastery  practised (6 uses): the two-handed push at 0.6 s; untrained or practised with the pistol drawn: no lock
##            ("weapon"); expert (20): the one-handed push at 0.48 s, and with the pistol in the right hand it casts; the
##            pistol fires (LMB) with Gust still readied, the RMB Gust's and not the pistol's aim (cast and shoot in the same
##            breath); a tier reached by use is told (mastered); after many casts the body is still the skeleton's last
##            modifier (SwayPose.put_last: its helpers follow the cast's pose)
##   fighter  Gust on a militiaman 8 m off: he staggers (the hit reaction) and is thrown back; counted for his tag
##   animal   Gust on a deer: shoved, it runs from the caster
##   fire     Gust on a lit campfire puts it out
##   motes    with none left no lock starts; the free floor breathes them back one at a time up to 2
##   sail     Gust on a sail (group sway_sails): at full lock it holds, the wind in the sail (sail_wind on, its sway_wind) while
##            the aim is held, a mote every drain_s; let go: slack (sail_wind off), cast; the aim off it: slack, broken
##   first    the wreck's spar (group sway_targets, meta sway_move first_lock; not granted, costs nothing, no spell readied):
##            a 3 s lock, then cast, and it is lifted up and set aside (lifted)
##   save     the motes, the moves, the uses and the modes in the player's save part and back
## The gated rules: free use off here (SwayCaster.free_override false: a spell only once granted, the motes spent), as the
## story will want them back; free use itself (the user, 2026-10-03: "lets make the spells free use right now") is
## tests/sway/test_free_use.gd.
## Ends with "SWAY TEST PASSED (<n> checks)" or "SWAY TEST FAILED (<f> of <n>)".

const LANE_X := -1.25
var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var c: SwayCaster
var ev := {"started": [], "locked": [], "cast": [], "broken": [], "fizzled": [], "motes": [], "lifted": [], "hold": [], "wind": [], "mastered": []}


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	SwayCaster.free_override = false          # (the gated rules: see the header)
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


## The camera turned so the crosshair's ray goes through `p` (from where the camera is now; called each tick it follows
## the camera as it eases over the shoulder).
func _aim(p: Vector3) -> void:
	var d := p - player.camera.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = atan2(d.y, Vector2(d.x, d.z).length())


## Each tick the crosshair on `pt` (a Callable giving the point) for up to `limit` s, or until `cond` holds; the seconds
## it took (INF: never).
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


func _look_away(secs: float) -> void:
	var t := 0.0
	var dt := 1.0 / Engine.physics_ticks_per_second
	while t < secs:
		await physics_frame
		player.yaw = 0.7
		player.pitch = 0.25
		t += dt


func _crate(at: Vector3, size := 0.6, mass := 6.0) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.name = "SwayCrate"
	b.mass = mass
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3.ONE * size
	cs.shape = bx
	b.add_child(cs)
	current_scene.add_child(b)
	b.global_position = at + Vector3.UP * (size * 0.5 + 0.02)
	return b


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


func _draw_pistol() -> void:
	player.switch_weapon("pistol")
	for i in 40:
		if player.weapon_key == "pistol" and not player.is_switching() and player.weapon != null and player.weapon.active:
			break
		await _secs(0.1)
	await _secs(0.2)


## Readies `id` as the player does (spells only from the bar): dragged onto slot 9 when it is not on the bar yet (what was
## there to the pack), then readied (as its key would: the bar follows the caster).
func _ready_spell(id: String) -> bool:
	var hb := player.hotbar
	if id != "" and hb != null and hb.slot_of(Hotbar.SPELL, id) < 0:
		hb.assign(Hotbar.SLOTS - 1, Hotbar.make(Hotbar.SPELL, id))
	return c.ready_spell(id)


## The skeleton's modifiers end with SwayCastPose and then the body (CharacterBodyMesh): "" when they do, else the order.
func _body_last() -> String:
	var mods: Array[Node] = []
	for n in player.skeleton.get_children():
		if n is SkeletonModifier3D:
			mods.append(n)
	if mods.size() >= 2 and mods[mods.size() - 1] is CharacterBodyMesh and String(mods[mods.size() - 2].name) == "SwayCastPose":
		return ""
	return ", ".join(mods.slice(maxi(mods.size() - 4, 0)).map(func(n: Node) -> String: return String(n.name)))


func _run() -> void:
	for i in 25:
		await process_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	_expect(player != null, "the level has the player")
	if player == null:
		_end()
		return
	player.ignore_mouse_capture = true
	_strict_gust()
	for i in 60:
		await process_frame
	_place_player()
	await _hands_free()
	_expect(player.hands_free and not player.is_switching(), "the player's hands are free (H)")
	await _install()
	var crate := _crate(_ground(LANE_X, -32.0))
	await _secs(0.5)
	await _no_spell(crate)
	await _lock(crate)
	await _breaks(crate)
	await _fizzle(crate)
	await _mastery(crate)
	crate.queue_free()
	await _fighter()
	await _animal()
	await _motes()
	await _campfire()
	await _sail()
	await _first_lock()
	_save()
	_end()


func _install() -> void:
	c = SwayCaster.install(player)
	_expect(c != null and SwayCaster.of(player) == c and SwayCaster.install(player) == c, "SwayCaster.install(player) once, of() finds it")
	_expect(not c.has("gust") and c.motes == 3 and c.belt_max == 3 and c.floor_max == 2 and is_equal_approx(c.floor_s, 90.0),
			"the belt full (%d of %d), the free floor %d every %.0f s, no move yet" % [c.motes, c.belt_max, c.floor_max, c.floor_s])
	Input.action_press("aim")
	await _secs(0.25)
	_expect(not c.readied and float(player.get(&"_aim_cam_w")) < 0.05, "before any move is granted the aim with the hands free does nothing")
	await _release()
	c.grant("gust")
	var hb := player.get_node_or_null(^"Hotbar")
	var on_bar := int(hb.call(&"slot_of", "spell", "gust")) if hb != null else -1
	var sp := c.known_spells()
	_expect(c.has("gust") and not c.has("first_lock") and on_bar < 0 and sp.size() == 1 and String(sp[0].label) == "Gust" and String(sp[0].icon) == "spell_gust"
			and SwayCaster.spell_icon("gust") != null, "Gust granted: a spell like the Form ones (its label and icon), in the Spells list, not put on the hotbar")
	_expect(c.readied_spell == "" and not c.ready_spell("gust") and c.readied_spell == "",
			"and not readied: spells only from the bar (off it ready_spell refuses; the grant's line says to drag it on)")
	_expect(_ready_spell("gust") and c.readied_spell == "gust" and int(hb.call(&"slot_of", "spell", "gust")) == 8,
			"dragged onto slot 9 it is readied")
	await _ticks(20)
	_expect(c.ring != null and c.ring.is_inside_tree() and c.thread != null and c.pose != null,
			"the ring on screen, the thread in the world, the body's clips (SwayPose)")
	c.lock_started.connect(func(m: String, t: Node3D) -> void: ev.started.append([m, t]))
	c.locked.connect(func(m: String, t: Node3D) -> void: ev.locked.append([m, t]))
	c.cast.connect(func(m: String, t: Node3D) -> void: ev.cast.append([m, t]))
	c.lock_broken.connect(func(m: String, t: Node3D, why: String) -> void: ev.broken.append([m, t, why]))
	c.fizzled.connect(func(m: String, t: Node3D) -> void: ev.fizzled.append([m, t]))
	c.motes_changed.connect(func(n: int) -> void: ev.motes.append(n))
	c.lifted.connect(func(t: Node3D) -> void: ev.lifted.append(t))
	c.hold_started.connect(func(m: String, t: Node3D) -> void: ev.hold.append([m, t]))
	c.sail_wind.connect(func(s: Node3D, on: bool) -> void: ev.wind.append([s, on]))
	c.mastered.connect(func(m: String, tier: int) -> void: ev.mastered.append([m, tier]))
	SwayCaster.reset_counts()


func _clear_ev() -> void:
	for k in ev:
		(ev[k] as Array).clear()


# ---------------------------------------------------------------- no spell readied
func _no_spell(crate: RigidBody3D) -> void:
	var at := func() -> Vector3: return crate.global_position
	c.ready_spell("")
	_clear_ev()
	await _hold_on(at, 0.1)
	Input.action_press("aim")
	await _hold_on(at, 0.6)
	_expect(c.state == SwayCaster.State.IDLE and ev.started.is_empty() and not c.readied and float(player.get(&"_aim_cam_w")) < 0.05,
			"no spell readied: the aim on the crate locks nothing, no ring, the camera stays")
	await _release()
	await _draw_pistol()
	var pistol := player.weapon
	_expect(player.weapon_key == "pistol" and pistol.active, "the pistol drawn")
	Input.action_press("aim")
	await _hold_on(at, 0.6)
	_expect(c.state == SwayCaster.State.IDLE and ev.started.is_empty() and pistol._fire_input_enabled() and pistol.is_steady_aiming(),
			"the pistol aimed at it (RMB): its own aim, no Gust")
	await _release()
	await _hands_free()


# ---------------------------------------------------------------- lock, cast
func _lock(crate: RigidBody3D) -> void:
	_clear_ev()
	_ready_spell("gust")
	var at := func() -> Vector3: return crate.global_position
	await _hold_on(at, 0.1)
	Input.action_press("aim")
	await _secs(0.02)
	_expect(c.readied, "Gust readied: the aim readies the hands (the ring's track, the belt)")
	await _hold_on(at, 0.3)
	_expect(c.state == SwayCaster.State.LOCKING and c.move == "gust" and c.target == crate and ev.started.size() == 1,
			"lock: the aim held on the crate locks Gust on it (%s, %s)" % [SwayCaster.State.keys()[c.state], c.move])
	_expect(float(player.get(&"_aim_cam_w")) < 0.05,
			"lock: the camera stays where it is, no zoom over the shoulder (the user, 2026-10-04) (%.2f)" % float(player.get(&"_aim_cam_w")))
	_expect(c.tier("gust") == 0 and is_equal_approx(c.lock_s, 0.6 * 1.4) and c.pose.anim_name == "own-form-clap-press" and c.arm.weight < 0.01,
			"lock: untrained, the floor cast (%s), the lock x1.4 (%.2f s), no pointing arm" % [c.pose.anim_name, c.lock_s])
	_expect(c.fill > 0.25 and c.fill < 0.6, "lock: the ring fills over 0.84 s (%.2f after 0.3 s)" % c.fill)
	await _hold_on(at, 0.2)
	await process_frame
	_expect(c.thread.visible and c.thread.strength > 0.03 and c.thread.from.distance_to(c.pose.palms) < 0.05,
			"lock: past half the thread runs from the palms to it (%.2f at %.2f)" % [c.thread.strength, c.fill])
	var f0 := c.fill
	await _look_away(0.08)
	_expect(c.state == SwayCaster.State.LOCKING and c.off_t > 0.0 and absf(c.fill - f0) < 0.01, "lock: 0.08 s off it the lock holds in the grace, not filling (%.2f)" % c.fill)
	var t := await _hold_on(at, 0.6, func() -> bool: return c.state == SwayCaster.State.FULL)
	_expect(t < 0.6 and ev.locked.size() == 1 and ev.locked[0][1] == crate, "lock: back on it, it fills and closes (locked, %.2f s)" % t)
	var z0 := crate.global_position.z
	var d0 := Vector2(crate.global_position.x - player.global_position.x, crate.global_position.z - player.global_position.z).length()
	await _release()
	_expect(ev.cast.size() == 1 and ev.cast[0][0] == "gust" and ev.cast[0][1] == crate and c.state == SwayCaster.State.IDLE,
			"lock: let go within the second, Gust is cast on it")
	_expect(c.motes == 2 and ev.motes == [2] and c.uses_of("gust") == 1, "lock: a mote spent (%d left), a use counted (%d)" % [c.motes, c.uses_of("gust")])
	await _secs(0.6)
	var d1 := Vector2(crate.global_position.x - player.global_position.x, crate.global_position.z - player.global_position.z).length()
	_expect(d1 > d0 + 0.5 and crate.global_position.z < z0, "lock: the crate is pushed away (%.1f -> %.1f m off)" % [d0, d1])
	await _secs(1.0)


# ---------------------------------------------------------------- breaks
func _breaks(crate: RigidBody3D) -> void:
	var at := func() -> Vector3: return crate.global_position
	_clear_ev()
	Input.action_press("aim")
	await _hold_on(at, 0.25)
	_expect(c.state == SwayCaster.State.LOCKING, "break: locked on the crate again")
	await _look_away(0.3)
	_expect(c.state == SwayCaster.State.IDLE and ev.broken.size() == 1 and ev.broken[0][2] == "off" and ev.cast.is_empty() and c.motes == 2,
			"break: the aim off it more than 0.15 s breaks it (%s), no cast, no mote" % (ev.broken[0][2] if not ev.broken.is_empty() else "-"))
	await _release()
	# a hit taken
	_clear_ev()
	Input.action_press("aim")
	await _hold_on(at, 0.25)
	player.apply_hit(2.0, player.global_position + Vector3.UP * 1.1, Vector3.ZERO, null)
	await _ticks(1)
	_expect(not ev.broken.is_empty() and ev.broken[0][2] == "hit", "break: a hit taken breaks it (%s)" % (ev.broken[0][2] if not ev.broken.is_empty() else "-"))
	await _release()
	player.health = player.max_health
	# sprinting: untrained the floor cast holds the caster still (no sprint, the lock holds); practised, a sprint breaks it
	_clear_ev()
	Input.action_press("aim")
	await _hold_on(at, 0.25)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _hold_on(at, 0.3)
	_expect(ev.broken.is_empty() and c.state == SwayCaster.State.LOCKING and c.rooted and not player.is_sprinting and player.horizontal_speed() < 0.3,
			"untrained: held still while the floor cast plays, sprint held (%.2f m/s), the lock holds" % player.horizontal_speed())
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _release()
	await _secs(1.2)
	var u_was := c.uses_of("gust")
	c.set_uses("gust", 6)
	_clear_ev()
	Input.action_press("aim")
	await _hold_on(at, 0.25)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _hold_on(at, 0.3, func() -> bool: return not ev.broken.is_empty())
	Input.action_release("sprint")
	Input.action_release("move_forward")
	_expect(not ev.broken.is_empty() and ev.broken[0][2] == "sprint", "break: practised, sprinting breaks it (%s)" % (ev.broken[0][2] if not ev.broken.is_empty() else "-"))
	await _release()
	c.set_uses("gust", u_was)
	_place_player()
	await _secs(0.5)
	# drawing a weapon
	_clear_ev()
	Input.action_press("aim")
	await _hold_on(at, 0.25)
	player.toggle_hands_free()
	await _ticks(2)
	_expect(not ev.broken.is_empty() and ev.broken[0][2] == "weapon" and c.readied_spell == "",
			"break: drawing a weapon breaks it (%s) and puts Gust down" % (ev.broken[0][2] if not ev.broken.is_empty() else "-"))
	await _release()
	await _hands_free()
	_ready_spell("gust")
	_expect(player.hands_free and c.motes == 2 and ev.cast.is_empty(), "break: hands free again, no cast, the motes kept (%d)" % c.motes)


# ---------------------------------------------------------------- fizzle
func _fizzle(crate: RigidBody3D) -> void:
	var at := func() -> Vector3: return crate.global_position
	_clear_ev()
	Input.action_press("aim")
	var t := await _hold_on(at, 1.4, func() -> bool: return c.state == SwayCaster.State.FULL)
	_expect(t < 1.4, "fizzle: locked full (%.2f s)" % t)
	t = await _hold_on(at, 1.4, func() -> bool: return not ev.fizzled.is_empty())
	_expect(t > 0.9 and t < 1.2 and c.state == SwayCaster.State.IDLE and c.motes == 2 and ev.cast.is_empty(),
			"fizzle: held on past the second it fizzles (%.2f s), the motes kept (%d)" % [t, c.motes])
	await _hold_on(at, 0.4)
	_expect(c.state == SwayCaster.State.IDLE and ev.started.size() == 1, "fizzle: no new lock while the aim is still held")
	await _release()
	_expect(ev.cast.is_empty(), "fizzle: letting go after casts nothing")


# ---------------------------------------------------------------- mastery
## The crate back 8 m down the lane, at rest (a lock's time is stretched at the far end of the range).
func _crate_back(crate: RigidBody3D) -> void:
	crate.linear_velocity = Vector3.ZERO
	crate.angular_velocity = Vector3.ZERO
	crate.global_transform = Transform3D(Basis.IDENTITY, _ground(LANE_X, -32.0) + Vector3.UP * 0.32)
	await _ticks(3)


func _mastery(crate: RigidBody3D) -> void:
	_place_player()
	await _crate_back(crate)
	await _secs(0.3)
	var at := func() -> Vector3: return crate.global_position
	# a use short of practised, then the cast that reaches it
	c.set_motes(c.belt_max)
	c.set_uses("gust", 5)
	_clear_ev()
	_ready_spell("gust")
	Input.action_press("aim")
	var t := await _hold_on(at, 1.4, func() -> bool: return c.state == SwayCaster.State.FULL)
	await _release()
	_expect(t < 1.4 and ev.cast.size() == 1 and c.tier("gust") == 1 and ev.mastered == [["gust", 1]],
			"mastery: the sixth Gust makes it practised (mastered)")
	await _secs(0.8)
	await _crate_back(crate)
	c.set_motes(c.belt_max)
	_clear_ev()
	Input.action_press("aim")
	await _hold_on(at, 0.2)
	_expect(c.state == SwayCaster.State.LOCKING and is_equal_approx(c.lock_s, 0.6) and c.pose.anim_name == "own-sway-push-two",
			"practised: the two-handed standing push (%s), the lock x1.0 (%.2f s)" % [c.pose.anim_name, c.lock_s])
	var order := _body_last()
	_expect(order == "", "after many casts the body is still the skeleton's last modifier, the cast's pose before it (%s)" % order)
	await _release()
	await _secs(0.6)
	# practised with the pistol drawn: no lock
	await _draw_pistol()
	var pistol := player.weapon
	_clear_ev()
	Input.action_press("aim")
	await _hold_on(at, 0.5)
	_expect(c.readied_spell == "" and c.state == SwayCaster.State.IDLE and ev.started.is_empty() and pistol._fire_input_enabled(),
			"practised: the pistol drawn puts Gust down (both hands must be empty), the pistol its own")
	await _release()
	_expect(_ready_spell("gust") and c.blocked() == "weapon", "readied again with the pistol in hand: no lock (%s)" % c.blocked())
	# expert: the pistol may stay in the right hand
	c.set_uses("gust", 20)
	_expect(c.tier("gust") == 2 and c.keeps_weapon("gust") and c.blocked() == "", "expert: one palm, the pistol allowed in the right hand")
	_expect(pistol._fire_input_enabled() and not pistol._aim_input_enabled() and not pistol.is_steady_aiming(),
			"the pistol still fires (LMB) while Gust is readied, its aim (RMB) is Gust's")
	await _crate_back(crate)
	_clear_ev()
	Input.action_press("aim")
	await _hold_on(at, 0.2)
	var pose := player.skeleton.get_node_or_null(^"SwayCastPose") as ToolPose
	var masks := (pose.layers as Array).map(func(l: Dictionary) -> String: return String(l.mask)) if pose != null else []
	_expect(c.state == SwayCaster.State.LOCKING and is_equal_approx(c.lock_s, 0.6 * 0.8) and c.pose.anim_name == "own-sway-push-one" and masks == ["reach_l"],
			"expert: the one-handed push (%s, %s), the lock x0.8 (%.2f s)" % [c.pose.anim_name, str(masks), c.lock_s])
	t = await _hold_on(at, 1.0, func() -> bool: return c.state == SwayCaster.State.FULL)
	await _release()
	_expect(t < 1.0 and ev.cast.size() == 1 and player.weapon_key == "pistol" and pistol.active and not player.hands_free,
			"expert: cast with the pistol still in the right hand")
	# cast and shoot in the same breath: the LMB fires the pistol, Gust still readied; the RMB stays Gust's
	await _secs(0.5)
	var fp := pistol as Firearm
	if fp != null and not fp.loaded:
		fp.loaded = true
		fp.state = Firearm.State.READY
	var shots := [0]
	var on_shot := func() -> void: shots[0] += 1
	pistol.fired.connect(on_shot)
	Input.action_press("fire")
	await _secs(0.05)
	Input.action_release("fire")
	for i in 150:
		await physics_frame
		if int(shots[0]) > 0:
			break
	pistol.fired.disconnect(on_shot)
	_expect(int(shots[0]) == 1 and c.readied_spell == "gust" and player.weapon_key == "pistol" and not player.hands_free,
			"expert: the pistol fires (LMB) with Gust still readied: no key to put the spell down first")
	await _look_away(0.1)
	Input.action_press("aim")
	await _look_away(0.25)
	_expect(c.readied and not pistol.is_steady_aiming(), "expert: the RMB is Gust's (its ring's track), not the pistol's aim")
	await _release()
	c.ready_spell("")
	_expect(pistol._fire_input_enabled() and pistol._aim_input_enabled(), "Gust put down: the pistol its own again")
	c.set_uses("gust", 2)
	await _hands_free()
	_ready_spell("gust")
	await _secs(0.8)


# ---------------------------------------------------------------- a fighter
func _fighter() -> void:
	_place_player()
	await _secs(0.3)
	c.set_motes(2)
	var pp := player.global_position
	var sq := NpcSquad.spawn(current_scene, "militia", 1, _ground(LANE_X, -32.0), {"face": pp, "tag": "sway_dummy", "seed": 7})
	var f: NpcFighter = sq.members[0]
	await _secs(0.8)
	_expect(f != null and not f.is_dead() and f.body != null, "fighter: a militiaman stands 8 m down the lane")
	var had := SwayCaster.lock_cast_begin({"move": "gust", "target": "sway_dummy"})
	_clear_ev()
	var at := func() -> Vector3: return NpcSenses.chest_of(f)
	Input.action_press("aim")
	var t := await _hold_on(at, 1.2, func() -> bool: return c.state == SwayCaster.State.FULL)
	_expect(t < 1.2 and c.target == f, "fighter: Gust locks on him (%.2f s)" % t)
	var d0 := Vector2(f.global_position.x - pp.x, f.global_position.z - pp.z).length()
	await _release()
	_expect(ev.cast.size() == 1 and ev.cast[0][1] == f and c.motes == 1, "fighter: cast on him, a mote spent (%d left)" % c.motes)
	var flinched := f.action == "flinch"
	var most := d0
	for i in 40:
		await physics_frame
		flinched = flinched or f.action == "flinch"
		most = maxf(most, Vector2(f.global_position.x - pp.x, f.global_position.z - pp.z).length())
	_expect(flinched, "fighter: he staggers (the hit reaction)")
	_expect(most > d0 + 0.5, "fighter: and is thrown back (%.1f -> %.1f m off)" % [d0, most])
	_expect(SwayCaster.cast_count("sway_dummy", "gust") == 1 and SwayCaster.cast_count("sway_dummy") == 1 and SwayCaster.cast_count() >= 2,
			"fighter: the cast counted for his tag (%d)" % SwayCaster.cast_count("sway_dummy"))
	var chk := SwayCaster.lock_cast_check({"move": "gust", "target": "sway_dummy", "count": 1}, had, self)
	_expect(bool(chk.done) and int(chk.have) == 1, "fighter: a lock_cast step on his tag is done (%d of %d)" % [chk.have, chk.need])
	sq.queue_free()
	await _secs(0.3)


# ---------------------------------------------------------------- an animal
func _animal() -> void:
	_place_player()
	await _secs(0.3)
	c.set_motes(1)
	var a := WildlifeSpecies.make("deer")
	a.name = "SwayTestDeer"
	a.setup("deer", null, null, 4242)
	current_scene.add_child(a)
	a.global_position = _ground(LANE_X, -33.0) + Vector3.UP * 0.02
	a.rotation.y = PI * 0.5
	await _secs(0.6)
	var pp := player.global_position
	_expect(a.state != WildAnimal.State.FLEE and not a.is_dead(), "animal: a deer stands 9 m down the lane (%s)" % WildAnimal.State.keys()[a.state])
	_clear_ev()
	var at := func() -> Vector3: return a.global_position + Vector3.UP * 0.8
	Input.action_press("aim")
	var t := await _hold_on(at, 1.2, func() -> bool: return c.state == SwayCaster.State.FULL)
	_expect(t < 1.2 and c.target == a, "animal: Gust locks on it (%.2f s)" % t)
	var d0 := Vector2(a.global_position.x - pp.x, a.global_position.z - pp.z).length()
	await _release()
	_expect(ev.cast.size() == 1 and a.state == WildAnimal.State.FLEE and c.motes == 0,
			"animal: cast, it runs (%s; %d motes left)" % [WildAnimal.State.keys()[a.state], c.motes])
	await _secs(1.5)
	var d1 := Vector2(a.global_position.x - pp.x, a.global_position.z - pp.z).length()
	_expect(d1 > d0 + 3.0, "animal: away from the caster (%.1f -> %.1f m off)" % [d0, d1])
	_expect(SwayCaster.cast_count("deer", "gust") == 1, "animal: counted under its species")
	a.queue_free()
	await _secs(0.3)


# ---------------------------------------------------------------- a campfire
func _campfire() -> void:
	_place_player()
	await _secs(0.3)
	var cf := Campfire.new()
	cf.name = "SwayTestFire"
	current_scene.add_child(cf)
	cf.global_position = _ground(LANE_X, -31.0)
	await _ticks(2)
	cf.light()
	await _secs(0.3)
	_expect(cf.is_lit(), "fire: a campfire burns 7 m down the lane")
	_clear_ev()
	var at := func() -> Vector3: return cf.global_position + Vector3.UP * 0.05
	Input.action_press("aim")
	var t := await _hold_on(at, 1.2, func() -> bool: return c.state == SwayCaster.State.FULL)
	_expect(t < 1.2 and c.target == cf, "fire: Gust locks on the fire where the crosshair meets the ground (%.2f s)" % t)
	await _release()
	_expect(ev.cast.size() == 1 and not cf.is_lit() and c.motes == 1, "fire: cast, the fire is blown out (%d motes left)" % c.motes)
	cf.queue_free()
	await _secs(0.3)


# ---------------------------------------------------------------- motes and the floor
func _motes() -> void:
	var crate := _crate(_ground(LANE_X, -32.0))
	await _secs(0.5)
	_clear_ev()
	var at := func() -> Vector3: return crate.global_position
	Input.action_press("aim")
	await _hold_on(at, 0.5)
	_expect(c.state == SwayCaster.State.IDLE and ev.started.is_empty() and c.hint == "motes", "motes: none left, no lock starts (%s)" % c.hint)
	await _release()
	c.floor_s = 1.0
	c._floor_t = 0.0                  # (the coal's breath begun now: it ran on 90 s since the belt fell under the floor)
	_clear_ev()
	await _secs(1.1)
	_expect(c.motes == 1, "motes: the free floor breathes one back (%d)" % c.motes)
	await _secs(1.0)
	_expect(c.motes == 2, "motes: then another (%d)" % c.motes)
	await _secs(1.5)
	_expect(c.motes == 2 and ev.motes == [1, 2], "motes: and no more than the floor (%d; %s)" % [c.motes, str(ev.motes)])
	c.floor_s = 90.0
	crate.queue_free()
	await _ticks(3)


# ---------------------------------------------------------------- a sail held
func _sail() -> void:
	_place_player()
	await _secs(0.3)
	c.set_motes(3)
	var sail := StaticBody3D.new()
	var gs := GDScript.new()
	gs.source_code = "extends StaticBody3D\nvar winds: Array = []\nfunc sway_wind(on: bool, _caster: Node) -> void:\n\twinds.append(on)\n"
	gs.reload()
	sail.set_script(gs)
	sail.name = "TestSail"
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.4, 2.4, 0.1)
	cs.shape = bx
	sail.add_child(cs)
	sail.add_to_group(SwayCaster.SAIL_GROUP)
	current_scene.add_child(sail)
	sail.global_position = _ground(LANE_X, -32.0) + Vector3.UP * 2.0
	await _ticks(3)
	_expect(SwayCaster.kind_of(sail) == "sail" and c.move_for(sail) == "gust", "sail: a node in group sway_sails takes Gust")
	_clear_ev()
	var at := func() -> Vector3: return sail.global_position
	Input.action_press("aim")
	var t := await _hold_on(at, 1.4, func() -> bool: return c.state == SwayCaster.State.HOLDING)
	_expect(t < 1.4 and ev.hold.size() == 1 and ev.wind.size() == 1 and ev.wind[0][1] == true and (sail.get(&"winds") as Array) == [true]
			and c.motes == 2, "sail: at full lock it holds, the wind in the sail (sail_wind, its sway_wind), a mote spent (%d)" % c.motes)
	var drain := float((SwayMoves.move("gust").get("sail", {}) as Dictionary).get("drain_s", 2.0))
	await _hold_on(at, drain + 0.15)
	_expect(c.state == SwayCaster.State.HOLDING and c.motes == 1 and ev.cast.is_empty(), "sail: held on, a mote every %.1f s (%d left)" % [drain, c.motes])
	await _release()
	_expect(ev.wind.size() == 2 and ev.wind[1][1] == false and (sail.get(&"winds") as Array) == [true, false] and ev.cast.size() == 1
			and c.state == SwayCaster.State.IDLE, "sail: let go, the sail goes slack (sail_wind off), cast")
	# the aim off it: slack, broken
	c.set_motes(3)
	_clear_ev()
	Input.action_press("aim")
	t = await _hold_on(at, 1.4, func() -> bool: return c.state == SwayCaster.State.HOLDING)
	await _look_away(0.3)
	_expect(t < 1.4 and ev.broken.size() == 1 and ev.broken[0][2] == "off" and ev.wind.size() == 2 and ev.wind[1][1] == false,
			"sail: the aim off it, the sail goes slack and the hold breaks (%s)" % (ev.broken[0][2] if not ev.broken.is_empty() else "-"))
	await _release()
	sail.queue_free()
	await _ticks(3)


# ---------------------------------------------------------------- the wreck's first lock
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
	spar.set_meta(&"sway_tag", "spar")
	spar.freeze = true
	current_scene.add_child(spar)
	spar.global_position = _ground(LANE_X, -30.0) + Vector3.UP * 0.2
	var start := spar.global_position
	await _ticks(3)
	_expect(not c.has("first_lock") and c.move_for(spar) == "first_lock" and c.readied_spell == "",
			"first: the spar names the first lock, usable without a grant and with no spell readied")
	_clear_ev()
	var at := func() -> Vector3: return spar.global_position
	var m0 := c.motes
	Input.action_press("aim")
	await _hold_on(at, 1.5)
	_expect(c.state == SwayCaster.State.LOCKING and c.move == "first_lock" and c.fill > 0.4 and c.fill < 0.6,
			"first: a 3 s lock on it (%.2f after 1.5 s)" % c.fill)
	var t := await _hold_on(at, 2.0, func() -> bool: return c.state == SwayCaster.State.FULL)
	_expect(t < 2.0 and ev.locked.size() == 1, "first: full after 3 s (locked)")
	await _release()
	_expect(ev.cast.size() == 1 and ev.cast[0][0] == "first_lock" and ev.cast[0][1] == spar and c.motes == m0,
			"first: cast, costing nothing (%d motes)" % c.motes)
	var top := start.y
	for i in 150:
		await physics_frame
		top = maxf(top, spar.global_position.y)
	await _secs(1.0)
	var aside := Vector2(spar.global_position.x - start.x, spar.global_position.z - start.z).length()
	_expect(top > start.y + 1.0, "first: the spar is lifted (%.2f m up)" % (top - start.y))
	_expect(aside > 1.2 and ev.lifted.size() == 1 and ev.lifted[0] == spar and not spar.freeze,
			"first: and set aside, let fall (%.2f m aside, lifted)" % aside)
	_expect(SwayCaster.cast_count("spar", "first_lock") == 1, "first: counted for the spar")
	spar.queue_free()


# ---------------------------------------------------------------- saves
func _save() -> void:
	c.set_mode("pillar", "free")
	var d := c.save_data()
	_expect(int(d.motes) == c.motes and (d.moves as Array).has("gust") and int((d.uses as Dictionary).get("gust", -1)) == c.uses_of("gust"),
			"save: the motes, the moves and the uses (%s)" % str(d))
	var part := SaveParts.save_player(current_scene)
	_expect(part.has("sway") and int(part.sway.motes) == c.motes and part.sway.has("uses"), "save: in the player's save part")
	var keep := c.motes
	var uses := c.uses_of("gust")
	c.set_motes(0)
	c.revoke("gust")
	c.uses.clear()
	c.modes.clear()
	SwayCaster.load_of(player, part.sway)
	_expect(c.motes == keep and c.has("gust") and c.uses_of("gust") == uses and c.mode_of("pillar") == "free",
			"save: and back (%d motes, gust %s, %d uses, the pillar %s)" % [c.motes, c.has("gust"), c.uses_of("gust"), c.mode_of("pillar")])
	var bare := Node.new()
	SwayCaster.load_of(bare, {"motes": 1, "moves": ["gust"]})
	_expect(bare.has_meta(&"sway_save"), "save: kept for install() when the player has no caster yet")
	bare.free()


func _end() -> void:
	Input.action_release("aim")
	if fails.is_empty():
		print("SWAY TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			printerr("FAIL: ", f)
		print("SWAY TEST FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)

## Gust under the strict rules these checks were written for: the art's cone, grace and release window, the 0.6 s and 0.8 s
## locks, the stone's strain and break. Its own easier rules (lock_rules, the stone's no_break, the quicker locks: the
## user's 2026-10-03 choice "easier Gust everywhere") are checked in tests/sway/test_free_use.gd. Set in memory only.
func _strict_gust() -> void:
	var g := SwayMoves.move("gust")
	g.erase("lock_rules")
	g["lock_s"] = 0.6
	var st: Dictionary = g.get("stone", {})
	st["lock_s"] = 0.8
	(st.get("hold", {}) as Dictionary)["no_break"] = false
