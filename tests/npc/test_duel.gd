extends SceneTree
## The duel (test) on the real level (DuelMode, DuelArena, DuelMenu; NpcSkirmish, NpcCover.pick, NpcFighter's aim; the user,
## 2026-10-04: "lets build a test game where it is 1v1 npc can find cover aim and etc"):
##   Godot --headless --fixed-fps 60 --path . -s tests/npc/test_duel.gd -- mode=duel
##   mode      the level is a duel: the arena on the open land (its 15 pieces, its bounds), the two spawns 40-45 m apart and
##             neither seen from the other, no survival, story or wild animals, its own Esc menu; a French marine who fights
##             from cover (tactics "cover", musket in hand, never running from his wounds), held through the countdown, the
##             player at spawn A; then the fight
##   cover     the player in the open in the marine's sight (untouchable: his body off the shots' layer, seen as ever): the
##             marine sees him and is in cover within a few seconds, hidden from him there (NpcCover.protects)
##   fire      from cover he peeks (rises over it or steps out past its end), aims and fires from the peek
##   reload    back behind it he reloads, hidden from the player
##   flank     the player round his cover where the line to him is clear: he puts the reload by and moves to cover that hides
##             him from there
##   hidden    the player crouched out of his sight: he believes him where he last saw him (no wallhack); the player's shot
##             tells him where he is (heard); his peeks see nothing and he goes after him (flank or advance)
##   hurt      badly hurt he falls back to cover further off, and fights on (no running)
##   broken    the thing he hides behind gone: he goes for other cover
##   close     the player on him with his musket empty: the butt
##   aim       the difficulty changes the aim: easy reacts and settles slower and spreads wider than normal, normal than hard
##             (the presets; the ball's scatter sampled through the shots' own code; the live marine's aim at once)
##   rounds    the marine dead: the round over, the score 1 : 0, the banner (text only) with the result and "M: inspect the
##             body", the inspect view on him holds the pause; then round 2 with the sides swapped, the arena put back, the
##             fallen man's things cleared, the player's kit full again; the player killed: 1 : 1; the time out: a draw; first
##             to 3 wins the duel
##   menu      the duel's menu restarts the duel and cycles the difficulty
## Ends with "DUEL TEST PASSED (<n> checks)" or "DUEL TEST FAILED (<f> of <n>)".

const SECTIONS := ["mode", "cover", "fire", "reload", "flank", "hidden", "heard", "hurt", "broken", "close", "aim", "rounds", "menu"]
var checks := 0
var fails: Array[String] = []
var done: Array[String] = []
var player: FrontierPlayer
var duel: DuelMode
var space: PhysicsDirectSpaceState3D


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
	DuelMode.incoming = true                    # (as the main menu's row; the user arg mode=duel does the same)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(s * Engine.physics_ticks_per_second))


## Waits up to `limit` s for `cond` (checked each physics tick; the player kept whole); the seconds it took (INF: never).
func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	var dt := 1.0 / Engine.physics_ticks_per_second
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += dt
		if player.collision_layer == 0:
			player.health = player.max_health
	return INF


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, FrontierTerrain.height_at(x, z), z)


func _place_player(at: Vector3, crouched := false) -> void:
	player.global_position = at + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	player.set_crouched(crouched)


func _clear(a: Vector3, b: Vector3, ex: Array[RID] = []) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1, ex)).is_empty()


## Nothing stands at `p` (a ray down onto it meets only the ground).
func _free(p: Vector3) -> bool:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.UP * 0.05, 1, [player.get_rid()]))
	return hit.is_empty()


## A place crouched behind one of the arena's boulders or crate stacks, on its far side from the marine and out of his sight
## (his eyes standing to a crouched man's chest, head and shoulders there all blocked); INF none.
func _hide_spot(n: NpcFighter) -> Vector3:
	var eye := n.global_position + Vector3.UP * 1.6
	var ex: Array[RID] = n.ray_exclude()
	ex.append(player.get_rid())
	var best := Vector3.INF
	var best_d := INF
	for piece in duel.arena.props.get_children():
		if not String(piece.get_meta(&"duel_piece", "")) in ["boulder", "crates"]:
			continue
		var c := (piece as Node3D).global_position
		var away := c - n.global_position
		away.y = 0.0
		away = away.normalized()
		var side := away.cross(Vector3.UP).normalized()
		for dist: float in [1.9, 2.4, 2.9]:
			var p := _ground(c.x + away.x * dist, c.z + away.z * dist)
			if not _free(p) or not duel.arena.has(p, -1.0):
				continue
			var hid := true
			for q: Vector3 in [p + Vector3.UP * 0.85, p + Vector3.UP * 1.1, p + Vector3.UP * 0.85 + side * 0.3, p + Vector3.UP * 0.85 - side * 0.3]:
				if _clear(eye, q, ex):
					hid = false
			var d := NpcBrain._flat(p, n.global_position)
			if hid and d > 12.0 and d < best_d:
				best = p
				best_d = d
	return best


func _npc() -> NpcFighter:
	return duel.npc if duel != null and duel.npc != null and is_instance_valid(duel.npc) else null


func _sk() -> NpcSkirmish:
	var n := _npc()
	return n.brain.skirmish if n != null and n.brain != null else null


func _run() -> void:
	for i in 20:
		await process_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	duel = DuelMode.find(self)
	_expect(player != null and duel != null, "the level is a duel (DuelMode under it)")
	if player == null or duel == null:
		_end()
		return
	player.ignore_mouse_capture = true
	space = (current_scene as Node3D).get_world_3d().direct_space_state
	await _mode()
	await _cover_fire_reload()
	await _flank()
	await _hidden()
	await _hurt()
	await _broken()
	await _close()
	_aim()
	await _rounds()
	await _menu()
	_end()


# ---------------------------------------------------------------- the mode, the arena, the spawns
func _mode() -> void:
	await _until(func() -> bool: return _npc() != null, 5.0)
	var a := duel.arena
	_expect(a != null and a.piece_count() >= 12 and a.piece_count() <= 16,
			"the arena on the open land at (%.0f, %.0f): %d pieces of cover" % [DuelArena.CENTER.x, DuelArena.CENTER.y, a.piece_count() if a else 0])
	var kinds := {}
	for c in a.props.get_children():
		kinds[String(c.get_meta(&"duel_piece", "?"))] = true
	_expect(kinds.size() >= 7, "of every kind: %s" % ", ".join(kinds.keys()))
	var b := a.bounds()
	_expect(is_equal_approx(b.size.x, 50.0) and is_equal_approx(b.size.y, 40.0), "50 x 40 m (%s)" % str(b))
	var s0 := a.spawn(0).origin
	var s1 := a.spawn(1).origin
	var apart := Vector2(s0.x - s1.x, s0.z - s1.z).length()
	_expect(apart >= 40.0 and apart <= 45.0 and a.has(s0) and a.has(s1), "two spawns %.1f m apart, both in the arena" % apart)
	var ex: Array[RID] = [player.get_rid()]
	if _npc() != null:
		ex.append_array(_npc().ray_exclude())
	var sees := false
	for pair: Array in [[s0, s1], [s1, s0]]:
		var from: Vector3 = pair[0]
		var to: Vector3 = pair[1]
		for h: float in [1.3, 1.6]:
			for off: float in [-0.3, 0.0, 0.3]:
				if _clear(from + Vector3.UP * 1.6, to + Vector3.UP * h + Vector3(0, 0, off), ex):
					sees = true
	_expect(not sees, "neither spawn sees the other (eye to chest and head, a man's breadth either side)")
	_expect(SurvivalBridge.find(self) == null and current_scene.get_node_or_null("Wildlife") == null
			and current_scene.get_node_or_null("StoryDirector") == null and current_scene.get_node_or_null("PauseMenu") == null
			and current_scene.get_node_or_null("DuelMenu") != null,
			"no survival needs, no wild animals, no story; the duel's own Esc menu in the pause menu's place")
	var n := _npc()
	_expect(n != null and n.faction == "french_marine" and n.tactics == "cover" and n.gun != null and n.gun.visible and not n.flees
			and n.calm_s == INF and n.brain.skirmish != null and n.skill_preset == DuelMode.difficulty,
			"the foe: a %s fighting from cover, musket in hand, aiming as '%s', who does not run from his wounds" % [
			n.label if n else "?", n.skill_preset if n else "?"])
	_expect(duel.phase == DuelMode.Phase.COUNTDOWN and n.held and duel.banner.text != ""
			and player.global_position.distance_to(s0) < 1.0,
			"the countdown: both at their spawns (the player on side A), the marine held, the banner '%s'" % duel.banner.text)
	var t := await _until(func() -> bool: return duel.phase == DuelMode.Phase.FIGHT, DuelMode.COUNTDOWN_S + 1.0)
	_expect(t < DuelMode.COUNTDOWN_S + 1.0 and not n.held and n.brain.state == NpcBrain.State.COMBAT and n.brain.target == player,
			"then the fight (%.1f s): he knows where the player began and goes about it (%s)" % [t, n.state_name()])
	done.append("mode")


# ---------------------------------------------------------------- cover, a peek and a shot, the reload behind it
func _cover_fire_reload() -> void:
	player.collision_layer = 0                  # (untouchable: no ball meets him; seen as ever)
	var n := _npc()
	var sk := _sk()
	# out in the open, toward the marine: in his sight once he is out from behind his spawn's crates
	var c := duel.arena.center()
	_place_player(_ground(c.x - 4.0, c.z + 1.0))
	var t_seen := await _until(func() -> bool: return n.brain.seen_now, 12.0)
	_expect(t_seen < 12.0, "the marine sees the player in the open (%.1f s)" % t_seen)
	var in_cover := func() -> bool:
		return not sk.cov.is_empty() and sk.mode in [NpcSkirmish.Mode.HIDE, NpcSkirmish.Mode.PEEK] \
				and NpcBrain._flat(n.global_position, sk.spot()) < 0.7
	var t := await _until(in_cover, 8.0)
	_expect(t < 6.0, "and is in cover %.1f s after (%s cover %.0f m from him, %s)" % [t, "low" if bool(sk.cov.get("low", false)) else "tall",
			float(sk.cov.get("d_threat", 0.0)), sk.last_why])
	_expect(NpcCover.protects(n, sk.cov, player.global_position, player),
			"hidden from him there (the lines from his eyes to a man's chest, head and shoulders there blocked)")
	done.append("cover")
	# the peek and the shot
	var shots0 := n.shots
	var at_shot := [Vector3.INF, -1, false, Vector3.INF]
	var watch := func() -> bool:
		if n.shots > shots0:
			return true
		if n.action == "aim" and n.aim_clock().x >= 0.0:
			at_shot[0] = n.global_position
			at_shot[1] = sk.mode
			at_shot[2] = n.is_crouching
			at_shot[3] = sk.spot()
		return false
	t = await _until(watch, 25.0)
	var stepped := at_shot[0] is Vector3 and at_shot[3] is Vector3 and (at_shot[0] as Vector3) != Vector3.INF \
			and NpcBrain._flat(at_shot[0], at_shot[3]) > 0.3
	var rose := bool(sk.cov.get("low", false)) and not bool(at_shot[2])
	_expect(t < 25.0 and int(at_shot[1]) == NpcSkirmish.Mode.PEEK and (stepped or rose) and sk.peeks >= 1,
			"from cover he peeks (%s), aims and fires from the peek (%.1f s; %d peeks)" % [
			("steps out %.1f m" % NpcBrain._flat(at_shot[0], at_shot[3])) if stepped else ("rises over it" if rose else "?"), t, sk.peeks])
	_expect(not n.last_shot.is_empty() and float(n.last_shot.err_deg) < 6.0 and is_equal_approx(float(n.last_shot.react), float(n.aim_cfg.reaction_s)),
			"his ball %.2f deg off the player's %s at %.0f m (spread %.2f deg, reaction %.2f s)" % [float(n.last_shot.get("err_deg", -1.0)),
			String(n.last_shot.get("part", "?")), float(n.last_shot.get("d", 0.0)), float(n.last_shot.get("spread_deg", 0.0)),
			float(n.last_shot.get("react", 0.0))])
	done.append("fire")
	t = await _until(func() -> bool: return n.action == "reload", 6.0)
	_expect(t < 6.0 and NpcBrain._flat(n.global_position, sk.spot()) < 0.7 and sk.mode == NpcSkirmish.Mode.HIDE
			and NpcCover.protects(n, sk.cov, player.global_position, player) and (n.is_crouching or not bool(sk.cov.low)),
			"back behind his cover he reloads, hidden from the player (%.1f s; %s)" % [t, "crouched" if n.is_crouching else "standing"])
	done.append("reload")


# ---------------------------------------------------------------- flanked while he reloads
func _flank() -> void:
	var n := _npc()
	var sk := _sk()
	if n.action != "reload":
		n.loaded = false
		await _until(func() -> bool: return n.action == "reload", 4.0)
	var old := sk.spot()
	var reloc0 := sk.relocations
	# round his cover from where the player is: a place 12-18 m off with a clear line to his chest, inside the arena
	var me := n.global_position
	var from := player.global_position - me
	from.y = 0.0
	var pick := Vector3.INF
	for deg: float in [80.0, -80.0, 100.0, -100.0, 60.0, -60.0, 120.0, -120.0, 140.0, -140.0]:
		for r: float in [14.0, 17.0, 11.0]:
			var p := me + from.normalized().rotated(Vector3.UP, deg_to_rad(deg)) * r
			p = _ground(p.x, p.z)
			if duel.arena.has(p, -1.0) and _free(p) and NpcCover.exposed(n, p, player):
				pick = p
				break
		if pick != Vector3.INF:
			break
	_expect(pick != Vector3.INF, "a place round his cover where the line to him is clear (%s)" % str(pick))
	if pick == Vector3.INF:
		done.append("flank")
		return
	_place_player(pick)
	var t := await _until(func() -> bool: return sk.relocations > reloc0 and sk.last_why == "flanked", 5.0)
	_expect(t < 5.0, "flanked, he puts the reload by and goes for other cover (%.1f s after; %s)" % [t, str(sk.why_count)])
	t = await _until(func() -> bool: return sk.mode == NpcSkirmish.Mode.HIDE and NpcBrain._flat(n.global_position, sk.spot()) < 0.7, 12.0)
	_expect(t < 12.0 and NpcBrain._flat(sk.spot(), old) > 1.0 and NpcCover.protects(n, sk.cov, player.global_position, player),
			"there, %.1f m from the cover he left, hidden from where the player is now (%.1f s)" % [NpcBrain._flat(sk.spot(), old), t])
	if t >= 12.0:
		print("    (notes: %s)" % str(sk.notes.slice(-8)))
	done.append("flank")


# ---------------------------------------------------------------- the player out of his sight
func _hidden() -> void:
	var n := _npc()
	var sk := _sk()
	# crouched behind a boulder or a crate stack on its far side from him: out of his sight
	var spot := _hide_spot(n)
	_expect(spot != Vector3.INF, "a place out of his sight behind the far cover (%s)" % str(spot))
	if spot == Vector3.INF:
		done.append("hidden")
		return
	_place_player(spot, true)
	await _secs(1.0)
	var believed := sk.threat()
	_expect(not n.brain.seen_now and NpcBrain._flat(believed, player.global_position) > 3.0,
			"out of his sight he believes the player where he last saw him (%.0f m from where he is: no wallhack)" % NpcBrain._flat(believed, player.global_position))
	n.loaded = true
	if n.action == "reload":
		n.cancel_reload()
	var seek0 := int(sk.why_count.get("seek", 0))
	var t := await _until(func() -> bool: return int(sk.why_count.get("seek", 0)) > seek0, 45.0)
	var cov := sk.cov
	_expect(t < 45.0, "the player hidden, his peeks see nothing and he goes after him: %s (%.1f s; %d peeks)" % [
			String(cov.get("mode", "?")), t, sk.peeks])
	if t >= 45.0:
		print("    (notes: %s; seen %.1f s ago)" % [str(sk.notes.slice(-8)), n.brain._clock - n.brain.seen_t])
	done.append("hidden")
	# the player's shot from where he hides: heard, he knows where it came from (unseen)
	await _ticks(2)
	if n.brain.seen_now:
		print("    (he has the player in sight again from where he went: the shot is heard all the same)")
	var gun: Weapon = player.weapons.get("musket")
	if gun != null:
		gun.fired.emit()
	await _ticks(3)
	_expect(NpcBrain._flat(n.brain.heard_at, player.global_position) < 1.0 and n.brain.heard_t >= n.brain._clock - 0.3
			and (n.brain.seen_now or NpcBrain._flat(sk.threat(), player.global_position) < 1.0),
			"the player's shot heard: he believes him where it came from (%.1f m off)" % NpcBrain._flat(sk.threat(), player.global_position))
	done.append("heard")


# ---------------------------------------------------------------- badly hurt
func _hurt() -> void:
	var n := _npc()
	var sk := _sk()
	# (the player back in the open in his sight, 18 m off toward the middle, so there is a 'further off' from him)
	var c := duel.arena.center()
	var toward := c - n.global_position
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 1.0 else Vector3(-signf(n.global_position.x - c.x), 0.0, 0.0)
	var pp := n.global_position + toward * 18.0
	for k in 12:
		if _free(_ground(pp.x, pp.z)):
			break
		pp += toward.cross(Vector3.UP) * 1.0
	_place_player(_ground(pp.x, pp.z))
	await _until(func() -> bool: return n.brain.seen_now, 6.0)
	await _until(func() -> bool: return not n.busy(), 10.0)
	var d0 := NpcBrain._flat(n.global_position, player.global_position)
	var fb0 := int(sk.why_count.get("fallback", 0))
	n.health = n.health_max * 0.4
	var t := await _until(func() -> bool: return int(sk.why_count.get("fallback", 0)) > fb0, 12.0)
	var d1 := float(sk.cov.get("d_threat", 0.0))
	_expect(t < 12.0 and d1 > d0, "badly hurt (40 of %.0f) he falls back to cover further off (%.0f m from the player, was %.0f m; %.1f s)" % [
			n.health_max, d1, d0, t])
	await _secs(2.0)
	_expect(n.brain.state == NpcBrain.State.COMBAT and not n.surrendered(), "and fights on: no running (%s)" % n.state_name())
	n.health = n.health_max
	done.append("hurt")


# ---------------------------------------------------------------- what he hides behind, gone
func _broken() -> void:
	var n := _npc()
	var sk := _sk()
	await _until(func() -> bool: return sk.mode == NpcSkirmish.Mode.HIDE and not sk.cov.is_empty() and NpcBrain._flat(n.global_position, sk.spot()) < 0.7, 15.0)
	var id := int(sk.cov.get("body", 0))
	var body := instance_from_id(id) as Node if id != 0 and is_instance_id_valid(id) else null
	_expect(body != null, "he hides behind %s" % (str(body.name) if body else "nothing"))
	if body == null:
		done.append("broken")
		return
	var old := sk.spot()
	var b0 := int(sk.why_count.get("broken", 0))
	body.queue_free()                            # (as an earth wall crumbles: FormRaised; NpcCover.broken)
	var t := await _until(func() -> bool: return int(sk.why_count.get("broken", 0)) > b0, 3.0)
	_expect(t < 3.0 and NpcBrain._flat(sk.spot(), old) > 1.0, "it gone, he goes for other cover (%.1f s, %.0f m off)" % [t, NpcBrain._flat(sk.spot(), old)])
	if t >= 3.0:
		print("    (notes: %s; action %s, mode %s)" % [str(sk.notes.slice(-8)), n.action, sk.mode_name()])
	done.append("broken")


# ---------------------------------------------------------------- the player on him
func _close() -> void:
	var n := _npc()
	await _until(func() -> bool: return not n.busy(), 10.0)
	n.loaded = false
	# (2.6 m from him, clear of his cover, in his sight)
	var at := Vector3.INF
	var ex: Array[RID] = n.ray_exclude()
	ex.append(player.get_rid())
	for k in 12:
		var dir := n.forward().rotated(Vector3.UP, TAU * float(k) / 12.0)
		var p := _ground(n.global_position.x + dir.x * 2.6, n.global_position.z + dir.z * 2.6)
		if _free(p) and _clear(n.eye(), p + Vector3.UP * 1.3, ex):
			at = p
			break
	_expect(at != Vector3.INF, "a place by him in the open (%s)" % str(at))
	if at == Vector3.INF:
		done.append("close")
		return
	_place_player(at)
	var blows0 := n.blows
	var t := await _until(func() -> bool: return n.blows > blows0, 6.0)
	_expect(t < 6.0, "the player on him with his musket empty: the butt (%.1f s, %d blows)" % [t, n.blows])
	player.wounds.clear()
	player.health = player.max_health
	done.append("close")


# ---------------------------------------------------------------- the difficulty: the aim's numbers and its scatter
func _aim() -> void:
	var e: Dictionary = NpcFighter.SKILLS.easy
	var m: Dictionary = NpcFighter.SKILLS.normal
	var h: Dictionary = NpcFighter.SKILLS.hard
	_expect(float(e.reaction_s) > float(m.reaction_s) and float(m.reaction_s) > float(h.reaction_s)
			and float(e.settle_s) > float(m.settle_s) and float(m.settle_s) > float(h.settle_s)
			and float(e.spread_deg) > float(m.spread_deg) and float(m.spread_deg) > float(h.spread_deg)
			and float(e.lead) < float(m.lead) and float(m.lead) < float(h.lead),
			"easy reacts (%.2f s), settles (%.2f s) and spreads (%.2f deg) more than normal (%.2f, %.2f, %.2f), normal than hard (%.2f, %.2f, %.2f)" % [
			e.reaction_s, e.settle_s, e.spread_deg, m.reaction_s, m.settle_s, m.spread_deg, h.reaction_s, h.settle_s, h.spread_deg])
	var n := _npc()
	var origin := n.eye()
	var mark := origin + Vector3(30.0, -0.2, 0.0)
	var means := {}
	for d: String in ["easy", "normal", "hard"]:
		duel.set_difficulty(d)
		var sum := 0.0
		var sigma := n.shot_spread_deg()
		for i in 400:
			var p := n.scatter(origin, mark, sigma)
			sum += rad_to_deg((p - origin).angle_to(mark - origin))
		means[d] = sum / 400.0
	_expect(float(means.easy) > float(means.normal) and float(means.normal) > float(means.hard),
			"the ball's line sampled through the shots' own scatter, 400 a difficulty at 30 m: easy %.2f deg off on average, normal %.2f, hard %.2f" % [
			means.easy, means.normal, means.hard])
	_expect(DuelMode.difficulty == "hard" and n.skill_preset == "hard" and is_equal_approx(float(n.aim_cfg.spread_deg), float(h.spread_deg)),
			"the difficulty set in the duel is the live marine's aim at once (%s: %.2f deg)" % [n.skill_preset, float(n.aim_cfg.spread_deg)])
	duel.set_difficulty("normal")
	done.append("aim")


# ---------------------------------------------------------------- rounds, the score, the sides, the reset
func _rounds() -> void:
	player.collision_layer = 1
	player.health = player.max_health
	var n := _npc()
	# a pack of his and a ball left lying about: the reset takes them away
	n.die(player, Vector3.FORWARD)
	var t := await _until(func() -> bool: return duel.phase == DuelMode.Phase.OVER, 1.0)
	_expect(t < 1.0 and duel.score == Vector2i(1, 0) and duel.last_result == "player", "the marine dead: the round is the player's, 1 : 0")
	await _ticks(4)
	var line := duel.banner.text + " / " + duel.sub.text
	_expect(duel.banner.text.contains("your round") and duel.sub.text.contains("1  :  0") and duel.sub.text.contains("M: inspect the body"),
			"the banner says so, with the score and the inspect (%s)" % line)
	var only_text := true
	for c in duel.ui.get_children():
		if not (c is Label):
			only_text = false
	_expect(only_text, "text only on the screen (%d labels; nothing marks where he is)" % duel.ui.get_child_count())
	var packs := get_nodes_in_group(PlacedWeapon.GROUP).filter(func(x: Node) -> bool: return x is NpcLoot and duel.arena.has((x as Node3D).global_position, 5.0))
	_expect(packs.size() >= 1, "his pack lies where he fell (%d)" % packs.size())
	_expect(duel.can_inspect(), "the body can be looked into in the pause")
	var v := InspectView.open_on(n)
	await process_frame
	var pt := duel.phase_t
	await _secs(1.0)
	_expect(v != null and paused and is_equal_approx(duel.phase_t, pt), "the inspect view open: the game paused under it, the pause waits (%.2f s)" % duel.phase_t)
	if v != null:
		v.close()
	await _ticks(3)
	# the player's musket fired: the next round gives it back loaded
	var musket: Firearm = player.weapons.get("musket")
	musket.loaded = false
	musket.reserve = 3
	t = await _until(func() -> bool: return duel.phase == DuelMode.Phase.COUNTDOWN, DuelMode.PAUSE_S + 2.0)
	await _ticks(2)
	var n2 := _npc()
	var a := duel.arena
	_expect(t < DuelMode.PAUSE_S + 2.0 and duel.round == 2 and duel.player_side == 1
			and player.global_position.distance_to(a.spawn(1).origin) < 1.0
			and n2 != null and n2 != n and n2.global_position.distance_to(a.spawn(0).origin) < 1.5,
			"round 2: the sides swapped (the player at spawn B, a fresh marine at spawn A)")
	packs = get_nodes_in_group(PlacedWeapon.GROUP).filter(func(x: Node) -> bool: return x is NpcLoot and is_instance_valid(x) and not x.is_queued_for_deletion() \
			and a.has((x as Node3D).global_position, 5.0))
	var kit_reserve := int((duel._kit.get("musket", {}) as Dictionary).get("reserve", -1))
	_expect(a.piece_count() == 15 and packs.is_empty() and musket.loaded and musket.reserve == kit_reserve and player.health >= player.max_health,
			"the arena put back (%d pieces), the fallen man's things cleared (%d left), the player whole with his musket loaded (%d spare)" % [
			a.piece_count(), packs.size(), musket.reserve])
	await _until(func() -> bool: return duel.phase == DuelMode.Phase.FIGHT, DuelMode.COUNTDOWN_S + 1.0)
	# the player killed
	player.apply_hit(900.0, player.global_position + Vector3.UP * 1.3, Vector3.FORWARD, n2, "body")
	t = await _until(func() -> bool: return duel.phase == DuelMode.Phase.OVER, 1.0)
	_expect(t < 1.0 and player.is_dead and duel.score == Vector2i(1, 1) and duel.last_result == "npc" and duel.banner.text.contains("You fell"),
			"the player killed: the marine's round, 1 : 1 (%s)" % duel.banner.text)
	t = await _until(func() -> bool: return duel.phase == DuelMode.Phase.COUNTDOWN, DuelMode.PAUSE_S + 2.0)
	_expect(t < DuelMode.PAUSE_S + 2.0 and not player.is_dead and duel.player_side == 0 and duel.round == 3,
			"round 3: the player up again at spawn A")
	await _until(func() -> bool: return duel.phase == DuelMode.Phase.FIGHT, DuelMode.COUNTDOWN_S + 1.0)
	duel.phase_t = DuelMode.ROUND_S
	await _ticks(2)
	_expect(duel.phase == DuelMode.Phase.OVER and duel.last_result == "draw" and duel.score == Vector2i(1, 1) and duel.banner.text.contains("draw"),
			"the time out: a draw, the score as it was (%s)" % duel.banner.text)
	# to the end: the player wins two more
	var over := [""]
	duel.duel_over.connect(func(r: String) -> void: over[0] = r)
	for k in 2:
		await _until(func() -> bool: return duel.phase == DuelMode.Phase.FIGHT, DuelMode.PAUSE_S + DuelMode.COUNTDOWN_S + 3.0)
		_npc().die(player, Vector3.FORWARD)
		await _until(func() -> bool: return duel.phase == DuelMode.Phase.OVER, 1.0)
	t = await _until(func() -> bool: return duel.phase == DuelMode.Phase.DONE, DuelMode.PAUSE_S + 2.0)
	_expect(t < DuelMode.PAUSE_S + 2.0 and duel.score == Vector2i(3, 1) and over[0] == "player" and duel.banner.text.contains("win the duel"),
			"first to 3: the player wins the duel 3 : 1 (%s)" % duel.banner.text)
	done.append("rounds")


# ---------------------------------------------------------------- the menu
func _menu() -> void:
	var m := duel.menu
	var d0 := DuelMode.difficulty
	m.cycle_difficulty()
	var d1 := DuelMode.difficulty
	m.cycle_difficulty()
	m.cycle_difficulty()
	_expect(d1 != d0 and DuelMode.difficulty == d0 and d1 in DuelMode.DIFFICULTIES, "the menu cycles the difficulty (%s -> %s -> ... -> %s)" % [d0, d1, DuelMode.difficulty])
	m.open()
	_expect(paused and m.is_open(), "Esc's menu pauses the duel")
	m.restart()
	await _ticks(3)
	_expect(not paused and duel.score == Vector2i.ZERO and duel.round == 1 and duel.phase == DuelMode.Phase.COUNTDOWN and _npc() != null,
			"Restart the duel: the score nil, round 1, the countdown")
	done.append("menu")


func _end() -> void:
	paused = false
	var missing := SECTIONS.filter(func(x: String) -> bool: return not done.has(x))
	_expect(missing.is_empty(), "every section ran to its end (stopped: %s)" % str(missing))
	if fails.is_empty():
		print("DUEL TEST PASSED (%d checks)" % checks)
	else:
		print("DUEL TEST FAILED (%d of %d)" % [fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)
