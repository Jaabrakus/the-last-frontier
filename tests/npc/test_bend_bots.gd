extends SceneTree
## Element bots (NpcBending, NpcBendCaster; Tidebreak, the ring sport: the owner, 2026-10-04, the bots cast the player's own
## moves, any of the four elements). In the duel's level, on a flat slab raised SLAB_Y over the arena (a deck with open edges,
## its edge_fn and bounds_fn set as the ring sets them), against the player held still in the middle of it:
##   coverage   a hard bot of each element (NpcSquad.spawn opts element, tactics bend; Tidebreak's other side, ring_team_b)
##              casts at least MIN_DISTINCT distinct (move, mode) in COVER_S, through the one path (BendEffects / BendCast:
##              last_of its caster), with no weapon, no words over its head, in its element's dress, and never leaves the slab
##              of itself (its lowest point stays above the deck)
##   the lock   each lock it filled took its lock_s (within a tick and 1/60 s); a hard bot's lock_s for each of a sample of
##              moves equals the player's own SwayCaster lock for the same move (within 1/60 s)
##   a hit      a 2-damage pebble (a stone BendBolt from the player, no knock) during a fire bot's lightning lock breaks it
##              (lost, why "hit"), and so does a knock; the same pebble during its Fire Wall's lock pushes the lock back by
##              at least guard_rules.hit_setback_min_s and keeps it (round 2, spec 2.3: a hit sets a lock back, never wipes it)
##   catch      stones thrown at a hard earth bot are caught, and a caught one is sent back by its guard cast again (E again:
##              its return, returns, its lock guard_rules.return_lock_s or perfect_return_lock_s)
##   the floor  waves along the deck (the Kick's floor wave) sent at a normal earth bot: it jumps at least FLOOR_JUMP_MIN of them
##              (floor_jumped of floor_seen; spec 2.8)
##   the edge   an air bot 3 m from an open end, the foe before it: in EDGE_S it never goes over the end of itself
## Last line "BEND BOTS PASSED" or "BEND BOTS FAILED"; exit 0 only on a pass; the watchdog (LIMIT_S) fails it before the lock
## wrapper's GODOT_TIMEOUT.
##   Godot --headless --fixed-fps 60 --path . -s tests/npc/test_bend_bots.gd -- mode=duel [only=fire]

const NAME := "BEND BOTS"
const LIMIT_S := 400.0
const SLAB_Y := 200.0
const SLAB := Vector2(40.0, 16.0)
const COVER_S := 40.0
const EDGE_S := 25.0
## (round 2's kits are smaller: 10-12 options an element, the guard and the heals on need; every move is the soak's check)
const MIN_DISTINCT := 5
## Stones thrown at the earth bot for its answers.
const THROWS := 8
## Waves along the deck sent at a normal bot, and the share it must jump (the KITS task: at least 30%).
const FLOOR_WAVES := 10
const FLOOR_JUMP_MIN := 0.3
const FACTION := "ring_team_b"
## The player's lock checked against the bot's: [element, move, mode] (self locks: no range stretch either side).
const LOCKS := [
	["earth", "rock_jab", "pebbles"], ["earth", "stone_catch", "catch"], ["earth", "earth_shove", "column"],
	["water", "ice", "spear"], ["water", "water_whip", "whip"], ["water", "wave", "push"],
	["fire", "fire_arc", "lightning"], ["fire", "fire_kick", "high_kick"], ["fire", "fire_jab", "embers"],
	["air", "air_blast", "ball"], ["air", "evade", "slip"], ["air", "air_shield", "shield"],
]

var fails := 0
var p: FrontierPlayer
var c: SwayCaster
var duel: DuelMode
var mid := Vector3.ZERO
var only := ""
var _seed := 1750


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	MatchSetup._aim_help = "strong"             # (this test's player does not aim his camera: the full help, as before the 2026-10-05 setting)
	seed(1750)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print(NAME + " FAILED (watchdog)")
		quit(2))
	DuelMode.incoming = true
	change_scene_to_file("res://scenes/main.tscn")
	_go.call_deferred()


func _end() -> void:
	if c != null and is_instance_valid(c):
		c.held_override = null
	print(NAME + (" PASSED" if fails == 0 else " FAILED"))
	quit(0 if fails == 0 else 1)


## `s` seconds of physics, the player kept: held where he stands (no pace, no knock), whole; the duel's round kept going.
func _secs(s: float, each: Callable = Callable()) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		_keep()
		if each.is_valid():
			each.call()
		await physics_frame


func _keep() -> void:
	if p == null or not is_instance_valid(p):
		return
	p.drag_speed_cap = 0.0
	p.health = p.max_health
	BendStatus.anchor(p, 0.5)
	if duel != null and duel.phase == DuelMode.Phase.FIGHT:
		duel.phase_t = minf(duel.phase_t, 10.0)
	if duel != null and duel.npc != null and is_instance_valid(duel.npc):
		duel.npc.held = true


func _go() -> void:
	for i in 20:
		await process_frame
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	duel = DuelMode.find(self)
	c = SwayCaster.of(p) if p != null else null
	_expect(p != null and duel != null and c != null, "the duel, its player and his caster")
	if p == null or duel == null:
		return _end()
	p.ignore_mouse_capture = true
	p.no_death = true
	for i in int((Hotbar.KIT_S + DuelMode.COUNTDOWN_S + 1.0) * Engine.physics_ticks_per_second):
		await physics_frame
	_expect(duel.phase == DuelMode.Phase.FIGHT, "the fight on (%s)" % DuelMode.PHASES[duel.phase])
	# the duel's own bot off out of the way, held
	if duel.npc != null:
		duel.npc.held = true
		duel.npc.global_position = duel.arena.center() + Vector3(0.0, 0.0, 60.0)
	mid = duel.arena.center()
	mid.y = SLAB_Y
	_slab()
	await _player_locks()
	for el: String in Bending.ELEMENTS:
		if only != "" and el != only:
			continue
		await _coverage(el)
	if only == "" or only == "air":
		await _edge()
	_end()


# ---------------------------------------------------------------- the slab and the ring's callables
func _slab() -> void:
	var sb := StaticBody3D.new()
	sb.name = "BotSlab"
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SLAB.x, 1.0, SLAB.y)
	cs.shape = box
	sb.add_child(cs)
	current_scene.add_child(sb)
	sb.global_position = Vector3(mid.x, SLAB_Y - 0.5, mid.z)


## Metres from `pos` along `dir` (flat) to the slab's edge (the ring's edge_fn: here every edge is open).
func edge_m(pos: Vector3, dir: Vector3) -> float:
	var hx := SLAB.x * 0.5
	var hz := SLAB.y * 0.5
	var lx := pos.x - mid.x
	var lz := pos.z - mid.z
	var t := INF
	if absf(dir.x) > 1e-5:
		t = minf(t, ((hx if dir.x > 0.0 else -hx) - lx) / dir.x)
	if absf(dir.z) > 1e-5:
		t = minf(t, ((hz if dir.z > 0.0 else -hz) - lz) / dir.z)
	return maxf(t, 0.0)


## `pos` kept a metre inside the slab (the ring's bounds_fn).
func bound(pos: Vector3) -> Vector3:
	var hx := SLAB.x * 0.5 - 1.0
	var hz := SLAB.y * 0.5 - 1.0
	return Vector3(clampf(pos.x, mid.x - hx, mid.x + hx), pos.y, clampf(pos.z, mid.z - hz, mid.z + hz))


func _place_player(at: Vector3) -> void:
	p.global_position = at + Vector3.UP * 0.05
	p.velocity = Vector3.ZERO
	var k := BendKnock.peek(p)
	if k != null:
		k.reset()


func _clear() -> void:
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormRaised.GROUP, FormStone.GROUP, NpcBending.FLIGHT_GROUP, GustLift.GROUP]:
		for x in get_nodes_in_group(g):
			if is_instance_valid(x):
				x.queue_free()


## A hard bot of `el` at `at` facing the player, its ring callables set; its fighter.
func _bot(el: String, at: Vector3, preset := "hard") -> NpcFighter:
	_seed += 1
	var sq := NpcSquad.spawn(current_scene, FACTION, 1, at, {"element": el, "tactics": "bend", "weapon": "", "sidearm": "",
			"skill": preset, "seed": _seed, "y": SLAB_Y, "face": p.global_position})
	var f: NpcFighter = sq.members[0] if not sq.members.is_empty() else null
	if f == null:
		return null
	var b := f.brain.bending
	if b != null:
		b.bounds_fn = bound
		b.edge_fn = edge_m
	f.brain.told(p, p.global_position)
	return f


func _free_bot(f: NpcFighter) -> void:
	if f != null and is_instance_valid(f) and f.squad != null and is_instance_valid(f.squad):
		f.squad.get_parent().remove_child(f.squad)
		f.squad.queue_free()


# ---------------------------------------------------------------- the player's lock against the bot's
func _ready_spell(id: String, mode: String) -> bool:
	var hb := p.hotbar
	if hb != null and hb.slot_of(Hotbar.SPELL, id) < 0:
		hb.assign(Hotbar.SLOTS - 1, Hotbar.make(Hotbar.SPELL, id))
	var ok := c.ready_spell(id)
	c.set_mode(id, mode)
	return ok and c.readied_spell == id and c.mode_of(id) == mode


func _player_locks() -> void:
	_place_player(mid + Vector3(-6.0, 0.0, 0.0))
	var bad: Array[String] = []
	var n := 0
	for row: Array in LOCKS:
		var el := String(row[0])
		if only != "" and el != only:
			continue
		DuelMode.element = el
		var id := String(row[1])
		var mode := String(row[2])
		await _secs(0.3)
		if not _ready_spell(id, mode):
			bad.append("%s %s: not readied" % [id, mode])
			continue
		c.held_override = true
		var t := 0.0
		while t < 2.0 and c.state == SwayCaster.State.IDLE:
			_keep()
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
		var theirs := c.lock_s if c.state != SwayCaster.State.IDLE else -1.0
		c.held_override = false
		var ours := NpcBending.lock_for(id, mode, "hard", 0.0)
		n += 1
		if theirs < 0.0 or absf(theirs - ours) > 1.0 / 60.0:
			bad.append("%s %s: player %.3f, bot %.3f" % [id, mode, theirs, ours])
		await _secs(0.5)
		_clear()
	_expect(n > 0 and bad.is_empty(), "a hard bot's lock equals the player's for %d moves%s" % [n, "" if bad.is_empty() else ": " + "; ".join(bad)])
	c.held_override = null
	await _secs(0.3)


# ---------------------------------------------------------------- each element
func _coverage(el: String) -> void:
	_clear()
	await _secs(0.2)
	_place_player(mid + Vector3(-6.0, 0.0, 0.0))
	var f := await _bot_ready(el, mid + Vector3(6.0, 0.0, 0.0))
	if f == null:
		_expect(false, "%s: a bot spawned" % el)
		return
	var b := f.brain.bending
	var low := [INF]
	var bw := Bending.of(f)
	_expect(b != null and b.element == el and f.element == el and bw.element == el and f.gun == null and f.axe == null and f.weapon == "",
			"%s: an element bot of %s, no gun, no axe, its element on its Bending (%s)" % [el, b.element if b else "-", bw.element])
	await _secs(COVER_S, func() -> void:
		if is_instance_valid(f):
			low[0] = minf(low[0], f.global_position.y))
	var labels := f.find_children("*", "Label3D", true, false)
	var shirt: Dictionary = ((f.look.get("outfit", {}) as Dictionary).get("shirt", {}) as Dictionary).get("colors", {})
	var bad_locks: Array[String] = []
	for lk: Dictionary in b.locks:
		if absf(float(lk.took_s) - float(lk.lock_s)) > 1.0 / Engine.physics_ticks_per_second + 1.0 / 60.0:
			bad_locks.append("%s/%s %.3f of %.3f" % [lk.move, lk.mode, lk.took_s, lk.lock_s])
	print("  %s: %d casts, %d distinct, %d hits, %d lost, %d answered; %s" % [el, b.casts, b.distinct(), b.hits, b.lost, b.answered, str(b.casts_by)])
	_expect(b.distinct() >= MIN_DISTINCT, "%s: %d distinct (move, mode) cast in %d s (%d wanted)" % [el, b.distinct(), int(COVER_S), MIN_DISTINCT])
	_expect(b.hits >= 1, "%s: its moves strike the player (%d)" % [el, b.hits])
	_expect(not b.locks.is_empty() and bad_locks.is_empty(), "%s: each of its %d locks took its lock_s%s" % [el, b.locks.size(), "" if bad_locks.is_empty() else ": " + ", ".join(bad_locks)])
	_expect(low[0] > SLAB_Y - 0.6, "%s: never off the slab of itself (lowest %.2f m over the deck)" % [el, low[0] - SLAB_Y])
	_expect(labels.is_empty() and f.last_bark == "", "%s: no words over its head (%d Label3D, bark '%s')" % [el, labels.size(), f.last_bark])
	# (its element's dress: the ring dress of the faction's element_dress, 2026-10-05, each garment in its element's preset)
	var want: Dictionary = (NpcFactions.get_faction(FACTION).get("element_dress", {}) as Dictionary).get(el, {})
	var worn := not want.is_empty()
	for s: String in want:
		var w: Dictionary = want[s]
		var got: Dictionary = (f.look.get("outfit", {}) as Dictionary).get(s, {})
		worn = worn and String(got.get("id", "-")) == String(w.get("id", "-")) and \
				(got.get("colors", {}) as Dictionary) == (w.get("colors", {}) as Dictionary)
	_expect(worn, "%s: dressed in its element's ring dress (shirt %s)" % [el, str(shirt)])
	var clips := {}
	for lk: Dictionary in b.locks:
		clips[String(lk.get("clip", ""))] = true
	var own_ok := true
	for k: String in clips:
		own_ok = own_ok and (k == "cast_push" or k.begins_with("own-"))
	_expect(own_ok and not clips.is_empty(), "%s: every cast pose one of our own clips (%s)" % [el, ", ".join(clips.keys())])
	if el == "earth":
		var bend_clip := false
		for k: String in clips:
			bend_clip = bend_clip or k.begins_with("own-bend-")
		_expect(bend_clip, "earth: the own ring-sport clips cast with (own-bend-*)")
	if el == "fire":
		await _breaks(f)
	if el == "earth":
		await _answers(f)
	_free_bot(f)
	await _secs(0.2)
	if el == "earth":
		await _floor()


func _bot_ready(el: String, at: Vector3) -> NpcFighter:
	var f := _bot(el, at)
	for i in 3:
		await physics_frame
	return f


## Stones thrown at a hard earth bot (stone BendBolts from the player): it begins a guard against some (the reaction layer's
## first cut: its catch, deflect; the rates are printed, at least one answer begun is asked).
func _answers(f: NpcFighter) -> void:
	var b := f.brain.bending
	# (the slab cleared of what the fight raised: a wall left standing between them hides him, and a hidden foe's stones
	# are not answered; whether one stands there is down to the fight's rolls)
	var walls := get_nodes_in_group(FormRaised.GROUP).size()
	for w in get_nodes_in_group(FormRaised.GROUP):
		w.queue_free()
	await physics_frame
	print("  earth answers: %d raised cleared first; hidden %s, casting '%s', held %s, busy %s, target %s" % [walls,
			NpcBendCaster.hidden(f, p), b.casting, f.held, f.busy(), f.brain.target])
	var r0 := int(b.reactions_by.get("stone", 0))
	var a0 := b.answered
	# (its opening grace held on: no attack of its own begun over the throws, so its guard is what is tried, not its lock's
	# luck; the guard's own rolls stay: react_chance, perfect_chance)
	b._grace_until = INF
	for i in THROWS:
		await _secs(1.2)
		if not is_instance_valid(f):
			break
		# (12 m off, as the duel's start: time to see the stone come)
		f.global_position = p.global_position + Vector3(12.0, 0.05, 0.0)
		f.velocity = Vector3.ZERO
		await _secs(0.4)
		var from := NpcSenses.chest_of(p)
		var to := NpcSenses.chest_of(f)
		var dir := (to - from).normalized()
		BendBolt.launch(p, from + dir * 0.8, dir, {"kind": "stone", "mps": 18.0, "gravity": 0.0, "damage": 4.0, "knock_mps": 2.0,
				"radius_m": 0.2, "range_m": 40.0})
	await _secs(1.5)
	var begun := int(b.reactions_by.get("stone", 0)) - r0
	var ret_locks: Array[String] = []
	var ret_ok := true
	for lk: Dictionary in b.locks:
		if bool(lk.get("return", false)):
			ret_locks.append("%s/%s %.2f s" % [lk.move, lk.mode, float(lk.lock_s)])
			# (the return's lock: guard_rules' return_lock_s, or perfect_return_lock_s after a clean catch, x the preset's)
			ret_ok = ret_ok and String(lk.move) == "stone_catch" and float(lk.lock_s) <= NpcBending.rule("return_lock_s") + 0.01
	print("  earth answers: %d guards begun, %d stones taken (catches %d, clean %d; perfect %d, late %d, whiffs %d), %d returned: %s"
			% [begun, b.answered - a0, b.catches, b.clean_catches, b.perfects, b.lates, b.whiffs, b.returns, ", ".join(ret_locks)])
	_expect(begun >= 1, "earth: a stone thrown at it is answered with a guard (%d of %d)" % [begun, THROWS])
	_expect(b.catches >= 1, "earth: it catches the stones thrown at it (%d of %d)" % [b.catches, THROWS])
	_expect(b.returns >= 1 and ret_ok, "earth: a caught stone is sent back by its guard cast again (returns %d: %s)" % [b.returns, ", ".join(ret_locks)])


## Waves along the deck (the Kick's floor wave from the player's feet) at a normal earth bot fighting him: it jumps at least
## FLOOR_JUMP_MIN of those it sees come (NpcBending: floor_seen, floor_jumped; the preset's jump_chance).
func _floor() -> void:
	_clear()
	await _secs(0.2)
	_place_player(mid + Vector3(-7.0, 0.0, 0.0))
	var f := _bot("earth", mid + Vector3(7.0, 0.0, 0.0), "normal")
	for i in 3:
		await physics_frame
	if f == null:
		_expect(false, "the floor: a bot spawned")
		return
	var b := f.brain.bending
	var air := [0.0]
	await _secs(2.5)
	b._grace_until = INF                         # (no attack of its own: the waves' jumps are what is counted)
	for i in FLOOR_WAVES:
		f.global_position = Vector3(p.global_position.x + 12.0, f.global_position.y, p.global_position.z)
		f.velocity = Vector3.ZERO
		await _secs(0.3)
		var from := p.global_position
		var dir := Vector3(f.global_position.x - from.x, 0.0, f.global_position.z - from.z).normalized()
		# (the Kick's own wave: moves.json fire_kick kick, along the deck from his feet; a light one, so it is the jump that
		# is counted, not the knock)
		var ks := NpcBending.spec_of("fire_kick", "kick").duplicate()
		ks["damage"] = 2.0
		ks["knock_mps"] = 1.0
		ks["up_mps"] = 0.0
		BendBolt.launch(p, from + dir * 1.0, dir, ks)
		await _secs(1.4, func() -> void:
			if is_instance_valid(f) and not f.is_on_floor():
				air[0] += 1.0 / Engine.physics_ticks_per_second)
	var share := float(b.floor_jumped) / maxf(float(b.floor_seen), 1.0)
	print("  the floor: %d waves sent, %d seen, %d jumped (%.2f), %.1f s in the air" % [FLOOR_WAVES, b.floor_seen, b.floor_jumped, share, air[0]])
	_expect(b.floor_seen >= FLOOR_WAVES / 2 and share >= FLOOR_JUMP_MIN and air[0] > 0.2,
			"the floor: a normal bot jumps %d of %d waves along the deck (%.2f; %.2f wanted)" % [b.floor_jumped, b.floor_seen, share, FLOOR_JUMP_MIN])
	_free_bot(f)
	await _secs(0.2)


## A fire bot's lightning lock broken by a 2-damage pebble (no knock), then by a knock.
func _breaks(f: NpcFighter) -> void:
	var b := f.brain.bending
	f.held = false
	await _secs(1.5)
	var l0 := b.lost
	b.begin("fire_arc", "lightning")
	await _secs(0.25)
	var locking := b.casting == "fire_arc" and b.mode == "lightning"
	var circ := b.circle
	var circ_ok := circ != null and is_instance_valid(circ) and circ.color.is_equal_approx(MatchSetup.color("fire")) \
			and Vector2(circ.global_position.x - f.global_position.x, circ.global_position.z - f.global_position.z).length() < 0.3
	_expect(circ_ok, "fire: its own element's circle at its own feet while it locks (SHOW_LOCK_CIRCLE)")
	var from := NpcSenses.chest_of(p)
	var to := NpcSenses.chest_of(f)
	BendBolt.launch(p, from + (to - from).normalized() * 0.8, (to - from).normalized(),
			{"kind": "stone", "mps": 34.0, "gravity": 0.0, "damage": 2.0, "knock_mps": 0.0, "up_mps": 0.0, "radius_m": 0.09, "range_m": 30.0})
	var t := 0.0
	while t < 1.2 and b.lost == l0:
		_keep()
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	_expect(locking and b.lost == l0 + 1 and b.casting == "" and b.lost_why == "hit",
			"fire: a 2-damage pebble breaks its lightning lock (%s; lost %d to %d, why '%s', %.2f s)" % ["it locked" if locking else "no lock", l0, b.lost, b.lost_why, t])
	await _secs(0.5)
	var l1 := b.lost
	b.begin("fire_arc", "lightning")
	await _secs(0.2)
	BendStatus.knock(f, Vector3(3.0, 0.0, 0.0), p)
	await _secs(0.1)
	_expect(b.lost == l1 + 1 and b.lost_why == "knock", "fire: a knock breaks its lock too (why '%s')" % b.lost_why)
	_expect(f.body != null and f.body.clip == NpcBody.KNOCK_SLIDE, "fire: knocked, it plays our own knock slide (%s)" % (f.body.clip if f.body else "-"))
	# (any other lock: pushed back, kept)
	await _secs(1.0)
	var l2 := b.lost
	var s2 := b.setbacks
	b.begin("fire_wall", "wall")
	await _secs(0.3)
	var before := b.lock_t
	var from2 := NpcSenses.chest_of(p)
	var to2 := NpcSenses.chest_of(f)
	BendBolt.launch(p, from2 + (to2 - from2).normalized() * 0.8, (to2 - from2).normalized(),
			{"kind": "stone", "mps": 34.0, "gravity": 0.0, "damage": 2.0, "knock_mps": 0.0, "up_mps": 0.0, "radius_m": 0.09, "range_m": 30.0})
	var t2 := 0.0
	var at_hit := -1.0
	while t2 < 1.0 and b.casting == "fire_wall" and at_hit < 0.0:
		_keep()
		await physics_frame
		t2 += 1.0 / Engine.physics_ticks_per_second
		if b.setbacks > s2:
			at_hit = b.lock_t
	var back := before + t2 - at_hit
	_expect(b.lost == l2 and b.setbacks == s2 + 1 and at_hit >= 0.0 and back >= NpcBending.rule("hit_setback_min_s") - 0.02,
			"fire: a pebble pushes its Fire Wall's lock back %.2f s and keeps it (lost %d to %d, setbacks %d to %d)" % [back, l2, b.lost, s2, b.setbacks])


# ---------------------------------------------------------------- the edge
func _edge() -> void:
	_clear()
	await _secs(0.2)
	var end_x := mid.x + SLAB.x * 0.5
	_place_player(Vector3(end_x - 15.0, SLAB_Y, mid.z))
	var f := await _bot_ready("air", Vector3(end_x - 3.0, SLAB_Y, mid.z))
	if f == null:
		_expect(false, "the edge: an air bot spawned")
		return
	var b := f.brain.bending
	var low := [INF]
	await _secs(EDGE_S, func() -> void:
		if is_instance_valid(f):
			low[0] = minf(low[0], f.global_position.y))
	print("  edge: air bot %d casts %s" % [b.casts, str(b.casts_by)])
	_expect(low[0] > SLAB_Y - 0.6 and b.casts >= 3, "the edge: an air bot 3 m from an open end never goes over it of itself in %d s (%d casts, lowest %.2f m)"
			% [int(EDGE_S), b.casts, low[0] - SLAB_Y])
	_free_bot(f)
