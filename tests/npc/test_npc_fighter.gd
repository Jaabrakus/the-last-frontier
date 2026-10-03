extends SceneTree
## The human fighters in the level (NpcFighter, NpcBrain, NpcBody, NpcSenses, NpcSquad; scripts/npc), survival on:
##   Godot --headless --fixed-fps 60 --path . -s tests/npc/test_npc_fighter.gd -- survival=on
##   notice   a French marine 30 m down the range lane notices the player standing in his view (COMBAT, the player his target);
##            one 45 m off does not notice the player crouched behind a crate, then does once he stands up in the open; at
##            night one 30 m off does not see him standing still
##   hit      the player's musket ball (the game's Projectile, Hit.deliver) in a militiaman's body hurts him, a blow through
##            the melee's Hit.deliver (no head bonus) hurts him more, a ball in the head kills him: died, killed by the player;
##            an arrow in him rides on his bones (stuck_anchor)
##   axe      the player's own felling-axe swing (GatherTools, AxeMelee's sweep: the D attack) strikes a militiaman
##   loot     he leaves a pack where he fell (his musket, powder horn, lead, food); E takes it into the player's pack
##   attack   a militia squad inside the fort told to attack a place out past the gate walks there on the walk grid (planned
##            by WalkGrid, through the gate), and a noise makes one of them suspicious
##   melee    a tough's axe lands on the player; a marine's musket butt makes a blunt wound, not a bleeding one; three toughs
##            chasing a player who keeps moving plan on the walk grid seldom (each plan a few ms on the main thread)
##   give up  a badly hurt marine, empty, the player on him, surrenders; let go, he walks off
##   heard    a patrol; the player's shot is heard 125 m off
##   E        a fighter the player has in reach freed under him (a story's retry): the interactor lets him go (no freed read)
##   dead     of fourteen men, one frozen by the budget killed still falls and lies down; settled, his body rests (its
##            skeleton never updated again) and he leaves the fighters' lists; long after, out of sight, his body is cleared
##            (the node stays: the story still reads him dead); a man run off leaves the field the same way
##   fight    seven marines and seven militia facing each other down the lane fight: both fire, men fall; each squad comes
##            in a man a frame (no hitch); at most NpcSenses.MAX_ANIMATED of the fourteen are animated, the rest frozen
##            (stepped seldom, not held)
##   cover    a crate's cover is on its far side from the threat, never in it
##   lost     a marine in a fight whose foe gets 200 m away out of his sight loses him and, CALM_S on, calms down
##   level    a level's hostility changes and kill counts go with it
## Ends with "NPC FIGHTER TEST PASSED (<n> checks)" or "NPC FIGHTER TEST FAILED (<f> of <n>)".
const LANE_X := -1.25
var checks := 0
var fails: Array[String] = []
## The sections in order; each marks itself done at its end (one stopped by a script error is a failure, not a skip).
const SECTIONS := ["notice", "hit", "axe", "attack", "melee", "chase", "heard", "E", "dead", "fight", "cover", "lost", "level"]
var done: Array[String] = []
var player: FrontierPlayer


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
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


func _place_player(at: Vector3, crouched := false) -> void:
	player.global_position = at + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	player.set_crouched(crouched)


## Waits up to `limit` s for `cond` (checked each physics tick); the seconds it took (INF: never).
func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	var dt := 1.0 / Engine.physics_ticks_per_second
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += dt
	return INF


func _clear_all() -> void:
	# (the player out of reach first: the interactor forgets them before they go)
	_place_player(_ground(12.0, 10.0))
	await _ticks(3)
	for s in get_nodes_in_group(NpcSquad.GROUP):
		s.queue_free()
	for l in get_nodes_in_group(PlacedWeapon.GROUP):
		if l is NpcLoot:
			l.queue_free()
	await _ticks(4)


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
	NpcSenses.daylight_override = 1.0
	await _notice()
	await _clear_all()
	await _hit_and_loot()
	await _clear_all()
	await _player_axe()
	await _clear_all()
	await _attack_walk()
	await _clear_all()
	await _melee_and_surrender()
	await _clear_all()
	await _chase_plans()
	await _clear_all()
	await _heard_and_patrol()
	await _clear_all()
	await _interactor_forgets()
	await _clear_all()
	await _frozen_death()
	await _clear_all()
	await _fight()
	await _clear_all()
	_cover_box()
	await _lose_contact()
	await _clear_all()
	await _level_statics()
	_end()


# ---------------------------------------------------------------- notice
func _notice() -> void:
	var pp := _ground(LANE_X, -24.0)
	_place_player(pp)
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var m_at := _ground(LANE_X, -54.0)
	var q := PhysicsRayQueryParameters3D.create(m_at + Vector3.UP * 1.6, pp + Vector3.UP * 1.3, 1, [player.get_rid()])
	var block := space.intersect_ray(q)
	print("  (the lane from the marine to the player: %s)" % ("clear" if block.is_empty() else "blocked by %s" % (block.collider as Node).name))
	var sq := NpcSquad.spawn(current_scene, "french_marine", 1, m_at, {"face": pp, "tag": "watch", "seed": 11})
	var m: NpcFighter = sq.members[0]
	_expect(m != null and m.body != null and m.body.sk != null and m.gun != null, "a marine stands on the lane, dressed, musket in hand")
	_expect(m.is_in_group(NpcFighter.GROUP) and m.state_name() == "IDLE" and m.tag == "watch", "in the fighters' group, at ease, with his tag")
	var missing := []
	for k: String in NpcBody.CLIPS.keys() + NpcBody.OWN_CLIPS.keys():
		if not m.body.has_clip(k):
			missing.append(k)
	for k: String in NpcBody.ARMS:
		if not m.body.arms_ap.has_animation(NpcBody.LIB + "/" + k):
			missing.append(k)
	_expect(missing.is_empty(), "every clip the body plays is in its library (missing: %s)" % str(missing))
	var t := await _until(func() -> bool: return m.brain.state == NpcBrain.State.COMBAT, 6.0)
	_expect(t < 6.0 and m.target == player, "he notices the player standing in view 30 m off (%.1f s, %s)" % [t, m.state_name()])
	_expect(m.brain.spotted >= 1 and m.last_bark != "", "he saw him himself and called out (%s)" % m.last_bark)
	sq.queue_free()
	await _ticks(4)
	# crouched behind a crate 45 m off
	_place_player(pp, true)
	var crate := StaticBody3D.new()
	crate.name = "TestCrate"
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.4, 1.25, 0.5)
	cs.shape = bx
	crate.add_child(cs)
	current_scene.add_child(crate)
	crate.global_position = pp + Vector3(0.0, 0.62, -1.0)
	var m2_at := _ground(LANE_X, -69.0)
	var sq2 := NpcSquad.spawn(current_scene, "french_marine", 1, m2_at, {"face": pp, "seed": 12})
	var m2: NpcFighter = sq2.members[0]
	t = await _until(func() -> bool: return m2.brain.state == NpcBrain.State.COMBAT, 6.0)
	var a := float(m2.brain.aware.get(player.get_instance_id(), 0.0))
	_expect(t == INF and a < NpcBrain.SPOT, "45 m off he does not notice the player crouched behind a crate (%s, awareness %.2f)" % [m2.state_name(), a])
	crate.queue_free()
	_place_player(pp, false)
	t = await _until(func() -> bool: return m2.brain.state == NpcBrain.State.COMBAT, 8.0)
	_expect(t < 8.0, "then, the player up and in the open, he does (%.1f s)" % t)
	sq2.queue_free()
	await _ticks(4)
	# at night
	NpcSenses.daylight_override = NpcSenses.NIGHT
	var sq3 := NpcSquad.spawn(current_scene, "french_marine", 1, m_at, {"face": pp, "seed": 13})
	var m3: NpcFighter = sq3.members[0]
	t = await _until(func() -> bool: return m3.brain.state == NpcBrain.State.COMBAT, 5.0)
	_expect(t == INF, "at night one 30 m off does not see him standing still (%s)" % m3.state_name())
	NpcSenses.daylight_override = 1.0
	sq3.queue_free()
	await _ticks(4)
	done.append("notice")


# ---------------------------------------------------------------- the player's hits, the loot
func _shoot(from: Vector3, at: Vector3) -> void:
	# (as the player's musket launches its ball: Weapon._launch with Musket's numbers, the player its shooter)
	var dir := (at - from).normalized()
	var p := Projectile.new()
	p.kind = Projectile.Kind.BALL
	p.velocity = dir * 320.0
	p.gravity = 9.8
	p.drag = 0.25
	p.damage = 120.0
	p.exclude = [player.get_rid()]
	p.shooter = player
	current_scene.add_child(p)
	p.global_position = from
	p.look_at(from + dir, Vector3.UP)


func _hit_and_loot() -> void:
	var pp := _ground(LANE_X, -24.0)
	_place_player(pp)
	var sq := NpcSquad.spawn(current_scene, "militia", 1, _ground(LANE_X, -34.0), {"face": pp, "tag": "neighbour", "seed": 21})
	var f: NpcFighter = sq.members[0]
	var died := [false, null]
	f.died.connect(func(_f: NpcFighter, k: Node) -> void:
		died[0] = true
		died[1] = k)
	await _secs(0.6)
	_expect(f.interact_prompt(player).begins_with("Talk to the militiaman"), "a militiaman (the player's side) can be talked to: %s" % f.interact_prompt(player))
	f.interact(player)
	_expect(f.last_bark != "", "and answers (%s)" % f.last_bark)
	var h0 := f.health
	var muzzle := pp + Vector3.UP * 1.45
	_shoot(muzzle, NpcSenses.chest_of(f))
	await _secs(0.25)
	_expect(f.health < h0 and f.hits_taken == 1 and not f.is_dead(), "the player's ball in his body hurts him (%.0f -> %.0f)" % [h0, f.health])
	var anchor := ThrownProjectile.stuck_parent(f.body.torso, NpcSenses.chest_of(f))
	_expect(anchor is BoneAttachment3D and anchor.get_parent() == f.body.sk,
			"an arrow in his body rides on his bone (%s), not on the hit part he loses when he dies" % (anchor.name if anchor else "none"))
	var h1 := f.health
	var torso := f.body.torso
	var took := Hit.deliver(torso, 10.0, NpcSenses.chest_of(f), Vector3.FORWARD, player, false)
	_expect(took and f.health < h1, "an axe blow through the melee's hit path hurts him more (%.0f -> %.0f)" % [h1, f.health])
	if not f.is_dead():
		# (at his head where it is: on its bone, NpcBody's head part)
		_shoot(muzzle, f.body.head.global_position if f.body.head != null else NpcSenses.head_of(f))
		await _secs(0.3)
	_expect(f.is_dead() and died[0] and died[1] == player and f.killed_by == player, "a ball in the head kills him: died, killed by the player")
	_expect(f.state_name() == "DEAD" and StoryObjectives.is_dead(f), "dead as the story reads it")
	await _secs(2.6)
	_expect(f.settled() and not f.body.animate, "his death played out, he lies still (no more animation)")
	var loot := f.loot
	_expect(loot != null and is_instance_valid(loot) and loot.count() >= 3, "he leaves a pack where he fell (%d things)" % (loot.count() if loot else 0))
	if loot == null or not is_instance_valid(loot):
		return
	_expect(loot.interact_prompt(player).begins_with("Search the militiaman"), "E: %s" % loot.interact_prompt(player))
	var kinds := []
	for e in loot.items:
		kinds.append(String(e.kind))
	_expect("musket" in kinds and "powder_horn" in kinds, "his musket and powder horn are in it (%s)" % str(kinds))
	var before := InventoryState.from_player(player).pack_count("powder_horn")
	loot.interact(player)
	var after := InventoryState.from_player(player).pack_count("powder_horn")
	_expect(after == before + 1, "taken, it is in the player's pack (powder horns %d -> %d)" % [before, after])
	done.append("hit")


# ---------------------------------------------------------------- an order walked on the walk grid
func _attack_walk() -> void:
	_place_player(_ground(12.0, 10.0))
	var start := _ground(-2.0, 6.0)
	var goal := _ground(LANE_X, -40.0)
	var sq := NpcSquad.spawn(current_scene, "militia", 2, start, {"face": goal, "seed": 31})
	sq.attack(goal)
	await _until(func() -> bool: return not sq.spawning(), 1.0)       # (a squad comes in a man a frame)
	var a: NpcFighter = sq.members[0]
	var b: NpcFighter = sq.members[1]
	var gate := [false, false]
	var prev := [a.global_position.z, b.global_position.z]
	var t := 0.0
	var dt := 1.0 / Engine.physics_ticks_per_second
	var there := false
	while t < 50.0:
		await physics_frame
		t += dt
		var both := true
		var i := 0
		for f: NpcFighter in [a, b]:
			var z := f.global_position.z
			if (float(prev[i]) + 16.0) * (z + 16.0) < 0.0 and absf(f.global_position.x) < 4.0:
				gate[i] = true
			prev[i] = z
			var slot: Vector3 = f.get_meta(&"slot", Vector3.ZERO)
			if Vector2(f.global_position.x - goal.x - slot.x, f.global_position.z - goal.z - slot.z).length() > 3.5:
				both = false
			i += 1
		if both:
			there = true
			break
	var plans := 0
	for f: NpcFighter in [a, b]:
		plans += f.nav.walk.plans if f.nav.walk != null else 0
	_expect(there, "a squad told to attack a place past the gate gets there (%.1f s; at %s and %s)" % [t, a.global_position, b.global_position])
	_expect(plans >= 2 and gate[0] and gate[1], "on the walk grid (%d plans), out through the gate" % plans)
	await _secs(1.0)
	var heard := false
	var noise_at := a.global_position + Vector3(25.0, 0.0, -10.0)
	NpcSenses.noise(noise_at, 100.0, null)
	await _secs(0.6)
	heard = a.brain.state == NpcBrain.State.SUSPICIOUS and a.brain.suspect_at.distance_to(noise_at) < 1.0
	_expect(heard, "a noise 27 m off makes him suspicious (%s)" % a.state_name())
	done.append("attack")


# ---------------------------------------------------------------- blows, running and giving up
func _melee_and_surrender() -> void:
	var pp := _ground(LANE_X, -24.0)
	_place_player(pp)
	player.health = 100.0
	var sq := NpcSquad.spawn(current_scene, "toughs", 1, _ground(LANE_X, -32.0), {"attack": "player", "tag": "vane", "seed": 51})
	var tough: NpcFighter = sq.members[0]
	_expect(tough.axe != null and tough.gun == null, "a tough carries an axe, no musket")
	var t := await _until(func() -> bool: return player.health < 100.0, 12.0)
	_expect(t < 12.0 and tough.blows >= 1, "sent after the player, he runs in and his axe lands (%.1f s, health %.0f)" % [t, player.health])
	sq.queue_free()
	await _ticks(4)
	player.wounds.clear()
	player.health = 100.0
	# a marine empty of shot with the player on him clubs him with the butt: a bruise, not a cut
	var kinds := []
	var on_struck := func(_r: String, _s: String, kind: String, _a: float) -> void: kinds.append(kind)
	player.wounds.struck.connect(on_struck)
	var sqc := NpcSquad.spawn(current_scene, "french_marine", 1, _ground(LANE_X, -28.0), {"face": pp, "seed": 53})
	var mc: NpcFighter = sqc.members[0]
	mc.loaded = false
	t = await _until(func() -> bool: return mc.blows >= 1, 10.0)
	player.wounds.struck.disconnect(on_struck)
	_expect(t < 10.0 and mc.axe == null and "blunt" in kinds and not "bleed" in kinds,
			"an empty marine on him clubs the player with the butt: a blunt wound (%.1f s, %s)" % [t, str(kinds)])
	sqc.queue_free()
	await _ticks(4)
	player.wounds.clear()
	player.health = 100.0
	# a marine badly hurt, empty, with the player on him: he gives up
	var sq2 := NpcSquad.spawn(current_scene, "french_marine", 1, _ground(LANE_X, -27.0), {"face": pp, "seed": 52})
	var m: NpcFighter = sq2.members[0]
	m.loaded = false
	m.health = 20.0
	t = await _until(func() -> bool: return m.brain.state == NpcBrain.State.SURRENDER, 5.0)
	_expect(t < 5.0 and m.surrendered() and m.is_crouching, "badly hurt, his musket empty and the player on him, a marine surrenders (%s)" % m.state_name())
	var laid := false
	for n in get_nodes_in_group(PlacedWeapon.GROUP):
		if n is NpcLoot and (n as NpcLoot).items.any(func(e: Dictionary) -> bool: return String(e.kind) == "musket"):
			laid = true
	_expect(laid and not m.gun.visible, "his musket laid down at his feet, to be taken")
	_expect(NpcSenses.foes_of(m, 50.0).size() == 1 and not NpcSenses.can_fight(m), "out of the fight: no one's foe now")
	_expect(m.interact_prompt(player).begins_with("Let the french marine go"), "E: %s" % m.interact_prompt(player))
	m.interact(player)
	await _secs(3.0)
	_expect(m.brain.state == NpcBrain.State.FLEE and m.global_position.distance_to(pp) > 6.0, "let go, he walks off (%.1f m away)" % m.global_position.distance_to(pp))
	player.wounds.clear()
	player.health = 100.0
	done.append("melee")


# ---------------------------------------------------------------- the player's shot heard; a patrol
func _heard_and_patrol() -> void:
	_place_player(_ground(LANE_X, -24.0))
	var a := _ground(-6.0, 4.0)
	var b := _ground(6.0, 4.0)
	var sq := NpcSquad.spawn(current_scene, "militia", 1, a, {"patrol": [a, b], "seed": 61})
	var f: NpcFighter = sq.members[0]
	var t := await _until(func() -> bool: return f.global_position.distance_to(b) < 1.6, 20.0)
	_expect(t < 20.0 and f.state_name() == "PATROL", "a militiaman walks his patrol across the yard (%.1f s)" % t)
	t = await _until(func() -> bool: return f.global_position.distance_to(a) < 1.6, 25.0)
	_expect(t < 25.0, "and back again (%.1f s)" % t)
	var far := NpcSquad.spawn(current_scene, "french_marine", 1, _ground(LANE_X, -150.0), {"face": Vector3(LANE_X, 0.0, -300.0), "seed": 62})
	var m: NpcFighter = far.members[0]
	await _secs(2.5)                                       # (NpcSenses hooks the player's weapons)
	var gun: Weapon = player.weapons.get("musket")
	_expect(gun != null, "the player has his musket")
	if gun != null:
		gun.fired.emit()
		await _secs(0.5)
		_expect(m.brain.state == NpcBrain.State.SUSPICIOUS and m.brain.suspect_at.distance_to(player.global_position) < 2.0,
				"the player's shot is heard by a marine 125 m off, his back turned: he turns to look (%s)" % m.state_name())
	done.append("heard")


# ---------------------------------------------------------------- two squads fight
func _frame_ms(secs: float) -> float:
	var n := int(secs * 60.0)
	var t0 := Time.get_ticks_usec()
	for i in n:
		await process_frame
	return float(Time.get_ticks_usec() - t0) / 1000.0 / float(n)


func _fight() -> void:
	_place_player(_ground(12.0, 10.0))
	var base_ms := await _frame_ms(2.0)
	var fr_at := _ground(LANE_X, -88.0)
	var mi_at := _ground(LANE_X, -52.0)
	var t_sp := Time.get_ticks_usec()
	var fr := NpcSquad.spawn(current_scene, "french_marine", 7, fr_at, {"face": mi_at, "tag": "raid", "seed": 41})
	var mi := NpcSquad.spawn(current_scene, "militia", 7, mi_at, {"face": fr_at, "tag": "flatts", "seed": 42})
	var first_ms := float(Time.get_ticks_usec() - t_sp) / 1000.0
	var first := [fr.members.size(), mi.members.size(), fr.alive_count(), mi.alive_count()]
	var worst := 0.0
	var spawn_frames := 0
	while (fr.spawning() or mi.spawning()) and spawn_frames < 30:
		var t_f := Time.get_ticks_usec()
		await process_frame
		worst = maxf(worst, float(Time.get_ticks_usec() - t_f) / 1000.0)
		spawn_frames += 1
	_expect(first[0] == 1 and first[1] == 1 and first[2] == 7 and first[3] == 7 and not fr.spawning() and not mi.spawning()
			and fr.members.size() == 7 and mi.members.size() == 7,
			"each squad came in a man a frame (one each at once, all seven counted alive; all in after %d frames)" % spawn_frames)
	_expect(worst < 50.0, "no hitch while they come in: %.1f ms for the first two, %.1f ms the worst frame after (headless)" % [first_ms, worst])
	var fought := {}
	for f in fr.members + mi.members:
		f.state_changed.connect(func(who: NpcFighter, s: String) -> void:
			if s == "COMBAT":
				fought[who.get_instance_id()] = true)
	await _secs(1.2)
	var senses := NpcSenses.of(self)
	var frozen: Array[NpcFighter] = []
	for f in fr.members + mi.members:
		if f.frozen:
			frozen.append(f)
	_expect(senses.animated_count() <= NpcSenses.MAX_ANIMATED and frozen.size() >= 2, "fourteen fighters: %d animated, %d frozen (budget %d)" % [senses.animated_count(), frozen.size(), NpcSenses.MAX_ANIMATED])
	var fsteps := []
	for f in frozen:
		fsteps.append(f.body.steps)
	await _secs(1.2)
	var stepped := 0
	for i in frozen.size():
		if frozen[i].frozen and frozen[i].body != null and frozen[i].body.steps > int(fsteps[i]) and frozen[i].body.anim_step >= NpcSenses.FROZEN_STEP_S:
			stepped += 1
	_expect(stepped >= 1, "the frozen are stepped seldom, not held still (%d of %d stepped in 1.2 s)" % [stepped, frozen.size()])
	var deaths: Array[String] = []
	for f in fr.members + mi.members:
		f.died.connect(func(who: NpcFighter, k: Node) -> void:
			deaths.append("%s (%d hits, by %s)" % [who.name, who.hits_taken, k.name if k else "?"]))
	var t := 0.0
	var dt := 1.0 / Engine.physics_ticks_per_second
	var next_print := 5.0
	var covered := {}
	var twice := false
	var aim_err := [INF, 0.0, 0]
	var t0 := Time.get_ticks_usec()
	var frames := Engine.get_process_frames()
	while t < 45.0:
		await physics_frame
		t += dt
		for f in fr.members + mi.members:
			if f.brain.cover != Vector3.INF:
				covered[f.get_instance_id()] = true
			if f.shots >= 2:
				twice = true
			if f.body != null and f.action == "aim" and f.body.aim_weight() >= 0.99 and not f.frozen:
				aim_err[0] = minf(aim_err[0], f.body.aim.error_deg)
				aim_err[1] = maxf(aim_err[1], f.body.aim.error_deg)
				aim_err[2] += 1
		if t >= next_print:
			next_print += 5.0
			print("    t %.0f s: marines %d alive (%d fighting), militia %d alive (%d fighting)" % [t, fr.alive_count(), fr.fighting_count(), mi.alive_count(), mi.fighting_count()])
		if twice and t > 15.0 and fr.fighting_count() < 7 and mi.fighting_count() < 7:
			break
	var fight_ms := float(Time.get_ticks_usec() - t0) / 1000.0 / maxf(float(Engine.get_process_frames() - frames), 1.0)
	print("    the dead: %s" % ", ".join(deaths))
	print("    a frame (headless, no drawing): %.2f ms with no fighters, %.2f ms with the fourteen" % [base_ms, fight_ms])
	_expect(aim_err[2] > 0 and aim_err[1] < 12.0, "a musket at the shoulder lies on its foe (HuntAim: %.1f..%.1f deg off over %d samples)" % [aim_err[0], aim_err[1], aim_err[2]])
	var shots := [0, 0]
	var steps := 0
	for f in fr.members:
		shots[0] += f.shots
	for f in mi.members:
		shots[1] += f.shots
	for f in fr.members + mi.members:
		steps += f.body.steps if f.body != null else 0
	var dead := 14 - fr.alive_count() - mi.alive_count()
	var out := 14 - fr.fighting_count() - mi.fighting_count()
	print("    after %.0f s: shots %d / %d, dead %d, out of the fight %d, %d of 14 went to fight" % [t, shots[0], shots[1], dead, out, fought.size()])
	_expect(shots[0] > 0 and shots[1] > 0, "both sides fire (marines %d shots, militia %d)" % [shots[0], shots[1]])
	_expect(dead >= 1 and out >= 3, "men fall: %d dead, %d out of the fight" % [dead, out])
	_expect(fr.fighting_count() < 7 and mi.fighting_count() < 7, "losses on both sides (marines %d of 7 fighting, militia %d of 7)" % [fr.fighting_count(), mi.fighting_count()])
	_expect(fought.size() >= 12, "the alarm went through both squads (%d of 14 fought)" % fought.size())
	_expect(twice, "a musket loaded again after its shot and fired once more (the long reload)")
	_expect(covered.size() >= 2, "men empty of shot went for cover to reload (%d)" % covered.size())
	_expect(steps > 0, "their bodies were animated (%d pose steps)" % steps)
	done.append("fight")


# ---------------------------------------------------------------- the player's own axe swing
func _player_axe() -> void:
	var at := _ground(6.0, 8.0)
	_place_player(at)
	player.yaw = 0.0
	player.pitch = 0.0
	player.rotation.y = 0.0
	var g := player.gather
	if not g.owns("felling_axe"):
		var inv := InventoryState.from_player(player)
		inv.add("felling_axe", 1)
		player.set("inventory_pack", inv.pack.duplicate(true))
	g.take_out("felling_axe")
	for i in 240:
		await physics_frame
		if g.phase == GatherTools.Phase.READY:
			break
	# (where the swing's edge passes: an axe's length and an arm's in front, as the axe melee test's dummy)
	var sq := NpcSquad.spawn(current_scene, "militia", 1, _ground(at.x, at.z - 1.05), {"face": at, "seed": 71})
	var f: NpcFighter = sq.members[0]
	_place_player(at)
	await _ticks(20)
	var h0 := f.health
	var n0 := f.hits_taken
	player.grip.stamina = player.grip.stamina_max
	Input.action_press("move_right")
	Input.action_press("fire")
	await _ticks(2)
	Input.action_release("move_right")
	Input.action_release("fire")
	for i in 200:
		await physics_frame
		if g.phase == GatherTools.Phase.READY:
			break
	var hits: Array = g.melee.last_hits.filter(func(h: Dictionary) -> bool:
		return h.target is Node and is_instance_valid(h.target) and (h.target == f or f.is_ancestor_of(h.target)))
	_expect(g.tool == "felling_axe" and f.health < h0 and f.hits_taken > n0 and hits.size() >= 1,
			"the player's own felling-axe swing (AxeMelee's sweep, the D attack) strikes a militiaman (%.0f -> %.0f, %d hits, part %s)" % [
			h0, f.health, hits.size(), str(hits[0].part) if not hits.is_empty() else "-"])
	g.put_away()
	for i in 240:
		await physics_frame
		if g.phase == GatherTools.Phase.IDLE:
			break
	done.append("axe")


# ---------------------------------------------------------------- chasing a moving player: the walk grid planned seldom
func _chase_plans() -> void:
	var centre := _ground(LANE_X, -40.0)
	_place_player(centre + Vector3(6.0, 0.0, 0.0))
	var sq := NpcSquad.spawn(current_scene, "toughs", 3, _ground(LANE_X, -55.0), {"attack": "player", "seed": 9})
	await _until(func() -> bool: return not sq.spawning(), 1.0)
	var g := WalkGrid.of(self)
	var plans0 := g.plans if g else 0
	var t := 0.0
	var n := 0
	var worst := 0.0
	var t0 := Time.get_ticks_usec()
	var last := t0
	var closest := INF
	while t < 10.0:
		var a := t * 0.6
		var x := centre.x + cos(a) * 7.0
		var z := centre.z + sin(a) * 7.0
		player.global_position = Vector3(x, FrontierTerrain.height_at(x, z) + 0.05, z)
		player.velocity = Vector3(-sin(a), 0.0, cos(a)) * 4.2
		player.health = 100.0
		player.wounds.clear()
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
		n += 1
		t += 1.0 / 60.0
		for f in sq.members:
			closest = minf(closest, Vector2(f.global_position.x - x, f.global_position.z - z).length())
	var per_s := float((g.plans if g else 0) - plans0) / 10.0
	# (he is faster than they are, 4.2 m/s against 3.4: they get to him, and he runs on)
	_expect(g != null and per_s <= 2.0 and closest <= NpcFighter.REACH + 0.6,
			"three toughs chasing a player who keeps moving plan %.1f times a second on the walk grid (was 5.2), and get to him (%.1f m at the closest): frame %.2f ms mean, %.1f ms worst" % [
			per_s, closest, float(last - t0) / 1000.0 / maxf(float(n), 1.0), worst])
	player.wounds.clear()
	player.health = 100.0
	done.append("chase")


# ---------------------------------------------------------------- E: a fighter in reach freed under the player
func _interactor_forgets() -> void:
	var at := _ground(6.0, 8.0)
	_place_player(at)
	player.yaw = 0.0
	player.rotation.y = 0.0
	await _ticks(5)
	var cam := player.get_viewport().get_camera_3d()
	var fwd := -cam.global_basis.z if cam else -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var sq := NpcSquad.spawn(current_scene, "militia", 1, _ground(at.x + fwd.x * 1.4, at.z + fwd.z * 1.4), {"face": at, "seed": 81})
	var f: NpcFighter = sq.members[0]
	var it := player.interactor
	var t := await _until(func() -> bool: return it.target == f, 3.0)
	_expect(t < 3.0, "the player has a militiaman in reach (E: %s)" % (f.interact_prompt(player) if t < 3.0 else str(it.target)))
	# the story's retry: out of the level at once, then freed
	print("    (a fighter freed under the player's interactor: no 'previously freed' error may follow)")
	sq.get_parent().remove_child(sq)
	var gone_at_once := it.target == null
	sq.queue_free()
	await _ticks(5)
	var tv: Variant = it.target
	_expect(gone_at_once and (typeof(tv) == TYPE_NIL or is_instance_valid(tv)),
			"taken out of the level under him, the interactor lets him go at once (its next frames read nothing freed)")
	done.append("E")


# ---------------------------------------------------------------- a frozen man killed; the dead at rest; the field cleared
func _frozen_death() -> void:
	_place_player(_ground(12.0, 10.0))
	var a := NpcSquad.spawn(current_scene, "militia", 7, _ground(LANE_X, -30.0), {"seed": 91})
	var b := NpcSquad.spawn(current_scene, "militia", 7, _ground(LANE_X, -110.0), {"seed": 92})
	await _until(func() -> bool: return not a.spawning() and not b.spawning(), 1.0)
	await _secs(1.2)
	var f: NpcFighter = null
	for m in b.members:
		if m.frozen and not m.is_dead():
			f = m
	_expect(f != null, "of fourteen men the far ones are frozen by the budget")
	if f == null:
		return
	var head0 := f.body.bone_pos("heada").y - f.global_position.y
	f.die(null, Vector3.FORWARD)
	var t := await _until(func() -> bool: return f.settled(), 6.0)
	await _ticks(2)
	var head1 := f.body.bone_pos("heada").y - f.global_position.y if f.body != null else head0
	_expect(t < 6.0 and head1 < head0 - 0.6, "a frozen man killed falls all the same and lies down (his head %.2f m -> %.2f m over his feet)" % [head0, head1])
	var ups := [0]
	var count_up := func() -> void: ups[0] += 1
	f.body.sk.skeleton_updated.connect(count_up)
	await _ticks(30)
	f.body.sk.skeleton_updated.disconnect(count_up)
	_expect(ups[0] == 0 and not f.body.animate and not NpcSenses.fighters.has(f) and NpcSenses.corpses.has(f),
			"settled, his body rests (%d skeleton updates in 30 frames) and he is with the dead, out of the fighters' lists" % ups[0])
	var senses := NpcSenses.of(self)
	var far_eye := f.global_position + Vector3(400.0, 0.0, 0.0)
	senses._clear_field(NpcSenses.LOOT_S + 1.0, null, far_eye)
	var pack := f.loot
	_expect(f.body == null and is_instance_valid(f) and StoryObjectives.is_dead(f) and is_instance_valid(pack),
			"long after, out of sight, his body is cleared; the story still reads him dead; his pack stays while the player is near")
	# a man run off: far off a while, he leaves the field (the story still has him, alive and out of the fight)
	var r: NpcFighter = a.members[0]
	r.brain._routed = true
	r.global_position += Vector3(0.0, 0.0, -400.0)
	senses.budget(NpcSenses.LEAVE_S + 1.0)
	_expect(r.left_field and r.body == null and not NpcSenses.fighters.has(r) and is_instance_valid(r) and not r.is_dead()
			and r.brain.routed() and a.alive_count() == 7 and a.fighting_count() == 6,
			"a man run off and far away leaves the field: no body, out of the lists, still alive and routed to the story (%d alive, %d fighting)" % [a.alive_count(), a.fighting_count()])
	done.append("dead")


# ---------------------------------------------------------------- cover behind a crate
func _cover_box() -> void:
	var xf := Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.0, 0.6, 0.0))
	var half := Vector3(1.0, 0.6, 0.6)
	var threat := Vector3(2.0, 0.0, -20.0)
	var at := Vector3(0.3, 0.0, -1.0)                      # (on the threat's side of it, against it)
	var spot := NpcCover._spot(PhysicsServer3D.SHAPE_BOX, half, xf, at, threat)
	var ok := spot != Vector3.INF
	var local := xf.affine_inverse() * Vector3(spot.x, 0.6, spot.z) if ok else Vector3.ZERO
	var inside := absf(local.x) < half.x and absf(local.z) < half.z
	var behind := ok and Vector2(spot.x - threat.x, spot.z - threat.z).length() > Vector2(xf.origin.x - threat.x, xf.origin.z - threat.z).length() + 0.5
	_expect(ok and not inside and behind, "a man on the near side of a crate takes cover on its far side, not in it (%s)" % str(spot))
	done.append("cover")


# ---------------------------------------------------------------- a foe lost
func _lose_contact() -> void:
	var pp := _ground(LANE_X, -24.0)
	_place_player(pp)
	player.wounds.clear()
	player.health = 100.0
	var sq := NpcSquad.spawn(current_scene, "french_marine", 1, _ground(LANE_X, -54.0), {"face": pp, "seed": 14})
	var m: NpcFighter = sq.members[0]
	m.loaded = false                                       # (no shot at the player as he goes)
	var t := await _until(func() -> bool: return m.brain.state == NpcBrain.State.COMBAT and m.target == player, 6.0)
	_expect(t < 6.0, "a marine has the player in a fight (%.1f s)" % t)
	_place_player(_ground(140.0, 150.0))
	await _secs(3.0)
	_expect(not m.brain.seen_now and m.brain.state == NpcBrain.State.COMBAT,
			"the player 200 m off: out of his sight (seen %.1f s ago), still sought" % (m.brain._clock - m.brain.seen_t))
	t = await _until(func() -> bool: return m.brain.state != NpcBrain.State.COMBAT, NpcBrain.CALM_S + 6.0)
	_expect(t < NpcBrain.CALM_S + 6.0 and m.target == null and StoryObjectives.seen_by(self) == null,
			"CALM_S out of sight, he gives him up and calms down (%.0f s more, %s): the story no longer has the player seen" % [t, m.state_name()])
	player.wounds.clear()
	player.health = 100.0
	done.append("lost")


# ---------------------------------------------------------------- what a level changes goes with it
func _level_statics() -> void:
	var before := NpcFactions.hostile("toughs", "french_marine")
	NpcFactions.set_hostile("toughs", "french", true)
	NpcFighter.kills["test"] = 3
	var on := NpcFactions.hostile("toughs", "french_marine")
	var kept := NpcFactions.saved()
	var s := current_scene.get_node_or_null(NpcSenses.NODE_NAME)
	if s != null:
		current_scene.remove_child(s)
		s.queue_free()
	await _ticks(2)
	var gone := not NpcFactions.hostile("toughs", "french_marine") and NpcFighter.kills.is_empty() and NpcFactions.saved().is_empty()
	NpcFactions.restore(kept)
	var back := NpcFactions.hostile("toughs", "french_marine")
	NpcFactions.clear_overrides()
	_expect(not before and on and gone and back,
			"a story's hostility turn and the kills counted go with the level (and a save's restore() gives the turn back)")
	done.append("level")


func _end() -> void:
	NpcSenses.daylight_override = -1.0
	var missing := SECTIONS.filter(func(x: String) -> bool: return not done.has(x))
	_expect(missing.is_empty(), "every section ran to its end (stopped: %s)" % str(missing))
	if fails.is_empty():
		print("NPC FIGHTER TEST PASSED (%d checks)" % checks)
	else:
		print("NPC FIGHTER TEST FAILED (%d of %d)" % [fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)
