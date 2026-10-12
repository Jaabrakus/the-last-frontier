extends SceneTree
## Earth's talents (pass 1; the owner, 2026-10-11: "we need to make sure all the talents work and they work in game right") in a
## real % ring match (earth against an earth bot), headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_talents_earth.gd
## Each talent worn by one fighter alone, played through the game's own code (its casts, hits, zones and walls), and the same
## worn by nobody (Classic): what the node text says for the wearer, nothing for anyone else:
##   Thick Wall        an Earth Wall raised and shot down: 5 hits and 2.5 m wide (Classic 4 hits, 3 m); live in the json
##   Juggle            three stones at the wearer's Catch in one window: two held side by side, the third dropped at his feet
##                     (Classic holds all three); E throws the one caught first, E again the other; a stone at 0.85 s is late
##                     (Classic: caught); RingRules.guard_outcome's full catch 0.8 s (1.0); the bot wearing it catches two and
##                     throws both back
##   Return to Sender  a stone caught clean on E (the player's real lock: guard_override) and E again 0.05 s after the catch:
##                     thrown back on the Beat x1.15 (Classic x1, the same timing; the wearer at 0.35 s x1, no Beat); a late
##                     catch's return lock 0.4 s (0.35); the bot wearing it throws a clean catch back on the Beat
##   Kick-Up           the player's Pebbles (the cast's own path) at the deck away from the bot: one loose stone of his where the
##                     last pebble landed (Classic none); at the bot (hit): none; its spread 3.6 deg (3); his Fissure run at it
##                     throws it on
##   Avalanche         the player's Boulder (FormEffects.apply, Stone Form's cast) landing on the deck breaks into three low
##                     rolling stones fanned 15 deg, one volley of 3 (Classic: none); rolled into the bot they add the Boulder's
##                     16% between them, the first at base 5.9; the bot's Catch holds one, the others drop at its feet as the
##                     player's loose stones; the bot wearing it: its Boulder breaks the same
## Last line "TALENTS EARTH PASSED (n checks)" or "... FAILED"; exit 0 only on a pass.

const NAME := "TALENTS EARTH"
const LIMIT_S := 600.0
## A water bolt that wears an earth wall one hit (BendBolt.WEAR) and counts (FormRaised.hit_min 10).
const SHOT := {"kind": "water", "mps": 30.0, "damage": 20.0, "knock_mps": 0.0, "up_mps": 0.0, "radius_m": 0.15, "range_m": 20.0}
## A thrown stone (a spike's numbers, a bolt: a Catch takes it, BendZone._take_bolt).
const STONE := {"kind": "stone", "mps": 30.0, "damage": 20.0, "knock_mps": 4.0, "up_mps": 0.5, "radius_m": 0.15, "range_m": 20.0,
		"weight": "medium"}

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var player: FrontierPlayer
var bot: NpcFighter
var mode: RingMode
var rules: RingRules
var pc: BendCaster
var sc: SwayCaster
var pitch_sign := 1.0


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1760)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func _end() -> void:
	Engine.time_scale = 1.0
	for b: Node in [player, bot]:
		if b != null and is_instance_valid(b):
			BendLoadout.clear(b)
	BendLoadout.config_override = {}
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


## Game seconds of physics frames.
func _secs(s: float) -> void:
	await _ticks(ceili(s * float(Engine.physics_ticks_per_second)))


func _near(a: float, b: float, tol := 0.03) -> bool:
	return absf(a - b) <= tol


## The player's crosshair on world point `p` (his camera's yaw and pitch), a few frames for the camera to follow.
func _aim_at(p: Vector3) -> void:
	for i in 3:
		var d := (p - player.camera.global_position).normalized()
		player.yaw = atan2(-d.x, -d.z)
		player.pitch = asin(clampf(d.y, -1.0, 1.0)) * pitch_sign
		await _ticks(2)


## The deck `dist` m from the player, `deg` off the line to the bot (turned to his left).
func _deck_off(dist: float, deg: float) -> Vector3:
	var way := bot.global_position - player.global_position
	way.y = 0.0
	way = way.normalized().rotated(Vector3.UP, deg_to_rad(deg))
	return FormEffects.ground_at(player, player.global_position + way * dist)


## The player and the bot stood on the deck's long axis, `p_s` and `b_s` m from its centre (the bot held still there).
func _stage(p_s: float, b_s: float) -> void:
	var ar := RingArena.find(self)
	for e: Array in [[player, p_s], [bot, b_s]]:
		var n: CharacterBody3D = e[0]
		n.global_position = ar.center() + ar.axis() * float(e[1]) + Vector3.UP * 0.05
		n.velocity = Vector3.ZERO
	await _secs(0.4)


## The bot stood `dist` m from the player on the line between them (held still there), the player facing it.
func _bot_at(dist: float) -> void:
	var way := bot.global_position - player.global_position
	way.y = 0.0
	way = way.normalized()
	bot.global_position = FormEffects.ground_at(player, player.global_position + way * dist) + Vector3.UP * 0.05
	bot.velocity = Vector3.ZERO
	await _secs(0.3)


## `body` wears `id` alone as an earth caster ("" nothing: Classic).
func _wear(body: Node, id: String) -> void:
	BendLoadout.clear(body)
	if id != "":
		var ov := BendLoadout.wear(body, [id], "", "earth")
		if not (ov.ids as Array).has(id):
			_expect(false, "%s worn (refused: %s)" % [id, str(ov.refused)])


func _run() -> void:
	MatchSetup.incoming = true
	MatchSetup.element = "earth"
	MatchSetup.foes = ["earth"]
	MatchSetup.round_s = 900.0
	MatchSetup.rounds_to_win = 1
	MatchSetup.difficulty = "normal"
	InputSetup.ensure()
	SwayCaster.free_override = true
	change_scene_to_file("res://scenes/ring.tscn")
	for i in 20:
		await process_frame
	lvl = current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	_expect(mode != null and player != null and mode.foe != null and RingRules.stock_on(), "the % ring with a match and an earth bot")
	if mode == null or player == null or mode.foe == null:
		return _end()
	bot = mode.foe
	rules = RingRules.current()
	rules.stale_off = true
	pc = BendCaster.of(player)
	sc = SwayCaster.of(player)
	await _secs(4.5)                                 # (past the countdown and the start's safety)
	bot.held = true                                  # (the bot stands where it is: every hit below on a still body)
	await _secs(0.25)
	player.pitch = 0.3
	await _ticks(3)
	pitch_sign = 1.0 if (-player.camera.global_basis.z).y > 0.0 else -1.0
	player.pitch = 0.0
	await _thick_wall()
	await _juggle()
	await _return_to_sender()
	await _kick_up()
	await _avalanche()
	_end()


## A stone bolt `by` throws at `n`'s chest from `from_m` before him (within a Catch's reach: taken at once).
func _stone_at(n: Node3D, by: Node3D, from_m := 3.0) -> BendBolt:
	var way := n.global_position - by.global_position
	way.y = 0.0
	way = way.normalized()
	var chest := n.global_position + Vector3.UP * 1.1
	var spec := STONE.duplicate()
	spec["_info"] = {"tag": "stone_form/spike", "move": "stone_form", "mode": "spike", "from": chest - way * from_m}
	return BendBolt.launch(by, chest - way * from_m, way, spec)


## `body`'s Catch raised through the game's cast (BendEffects.apply, E's spec; with a stone held it throws it instead: the
## record says "return"); its zone held up `hold_s` (E held: SwayCaster's held guard) when one stands. The cast's record.
func _catch(body: Node3D, hold_s := 0.0) -> Dictionary:
	var bc := BendCaster.of(body)
	BendEffects.apply(bc, "stone_catch", "catch", SwayMoves.move("stone_catch").bend.catch)
	var rec := BendEffects.last_of(bc)
	var z: Variant = rec.get("zone")
	if hold_s > 0.0 and z is BendZone and is_instance_valid(z):
		(z as BendZone).life_s = hold_s
	return rec


## Every stone `body` holds let go and gone, and the loose ones on the deck (between the checks).
func _clear_held(body: Node3D) -> void:
	for s in BendZone.held_stones(body):
		s.remove_meta(&"bend_held_by")
		s.queue_free()
	for s in get_nodes_in_group(FormStone.GROUP):
		if (s as Node).has_meta(FormStone.LOOSE_META):
			(s as Node).queue_free()
	await _ticks(2)


# ---------------------------------------------------------------- Thick Wall
## An Earth Wall raised by the player (FormEffects.earth_wall, the builder the cast calls) and shot by the bot's water bolts
## until it crumbles: how many shots it takes, how wide it stood.
func _wall_shots(id: String) -> Array:
	_wear(player, id)
	var way := (bot.global_position - player.global_position)
	way.y = 0.0
	way = way.normalized()
	var at := player.global_position + way * 3.0
	var r := FormEffects.earth_wall(pc, at, SwayMoves.move("earth_wall"), "earth")
	if r == null:
		return [-1, -1.0, -1]
	await _secs(1.0)                                 # (risen)
	var hits_max := r.hits_max
	var width := r.size.x
	var shots := 0
	var mid := r.global_position + Vector3.UP * 1.0
	while is_instance_valid(r) and r.state != FormRaised.State.CRUMBLING and shots < 10:
		BendBolt.launch(bot, mid + way * 6.0, -way, SHOT)
		shots += 1
		await _secs(0.4)
	var down := not is_instance_valid(r) or r.state == FormRaised.State.CRUMBLING
	await _secs(1.6)
	return [shots if down else -1, width, hits_max]


func _thick_wall() -> void:
	_expect(BendLoadout.why_not("earth.wall.thick") == "", "Thick Wall is live in the json (%s)" % BendLoadout.why_not("earth.wall.thick"))
	var c := await _wall_shots("")
	var t := await _wall_shots("earth.wall.thick")
	_expect(int(c[0]) == 4 and int(t[0]) == 5, "Thick Wall: the wearer's wall falls to the 5th shot (Classic the 4th: %d, %d)" % [t[0], c[0]])
	_expect(_near(float(c[1]), 3.0) and _near(float(t[1]), 2.5), "Thick Wall: it stands 2.5 m wide (Classic 3 m: %.2f, %.2f)" % [t[1], c[1]])
	# the bot's walls are its own numbers while the player wears it
	_wear(player, "earth.wall.thick")
	var bw := BendLoadout.wall_numbers(bot, "wall", SwayMoves.move("earth_wall").wall, "earth")
	_expect(int(bw.hits) == 4 and _near(float(bw.width_m), 3.0), "Thick Wall: a wall the bot raises meanwhile is Classic's (%d hits, %.1f m)" % [bw.hits, bw.width_m])
	_wear(player, "")


# ---------------------------------------------------------------- Juggle
## Three stones at `body`'s Catch in one window (0.25 s apart): [held after two, the first caught, held after three, the
## loose ones at his feet after three, the two held's gap (m)].
func _three_stones(body: Node3D, by: Node3D) -> Array:
	var zr := _catch(body, 2.0)
	await _ticks(2)
	_stone_at(body, by)
	await _secs(0.25)
	var first: Node3D = BendZone.held_stone(body)
	_stone_at(body, by)
	await _secs(0.25)
	var two := BendZone.held_stones(body)
	var gap := two[0].global_position.distance_to(two[1].global_position) if two.size() == 2 else -1.0
	_stone_at(body, by)
	await _secs(0.25)
	var loose := 0
	for s in get_nodes_in_group(FormStone.GROUP):
		if int((s as Node).get_meta(FormStone.LOOSE_META, -1)) == by.get_instance_id() \
				and (s as Node3D).global_position.distance_to(body.global_position) < 1.6:
			loose += 1
	_end_zone(zr)
	return [two.size(), first, BendZone.held_stones(body).size(), loose, gap]


## The guard zone of cast record `rec` ended (a test's E let go: the next catch is a new window).
func _end_zone(rec: Dictionary) -> void:
	var z: Variant = rec.get("zone")
	if z is BendZone and is_instance_valid(z):
		(z as BendZone).end("test")


func _juggle() -> void:
	var id := "earth.catch.juggle"
	_expect(BendLoadout.why_not(id) == "" and id in BendLoadout.behaviour(), "Juggle is live, its code built (%s)" % BendLoadout.why_not(id))
	# Classic: every stone of the window held
	_wear(player, "")
	var c := await _three_stones(player, bot)
	await _clear_held(player)
	await _secs(1.0)
	_wear(player, id)
	var j := await _three_stones(player, bot)
	_expect(int(j[0]) == 2 and float(j[4]) > 0.45, "Juggle: two stones held from one window, side by side (%d held, %.2f m apart)" % [j[0], j[4]])
	_expect(int(j[2]) == 2 and int(j[3]) == 1, "Juggle: a third is stopped and dropped at his feet, the thrower's loose stone (%d held, %d loose)" % [j[2], j[3]])
	_expect(int(c[2]) == 3 and int(c[3]) == 0, "Classic: the same three are all held as ever (%d held, %d loose)" % [c[2], c[3]])
	# E throws the one caught first, E again the other
	var first: Node3D = j[1]
	var second: Node3D = null
	for s in BendZone.held_stones(player):
		if s != first:
			second = s
	var r1 := _catch(player)
	var after1 := BendZone.held_stones(player)
	var r2 := _catch(player)
	var after2 := BendZone.held_stones(player)
	_expect(String(r1.get("do", "")) == "return" and r1.get("stone") == first and after1.size() == 1 and after1[0] == second,
			"Juggle: E throws the stone caught first, the other still held (%s, %d left)" % [r1.get("do", "-"), after1.size()])
	_expect(String(r2.get("do", "")) == "return" and r2.get("stone") == second and after2.is_empty(),
			"Juggle: E again throws the other (%s, %d left)" % [r2.get("do", "-"), after2.size()])
	await _secs(1.5)
	await _clear_held(player)
	# the window: a stone at 0.85 s is late for the wearer, a full catch for Classic
	var late := {}
	for w: String in ["", id]:
		_wear(player, w)
		var rec := _catch(player, 2.0)
		var z := rec.get("zone") as BendZone
		await _secs(0.85)
		_stone_at(player, bot)
		await _secs(0.2)
		late[w] = [BendZone.held_stones(player).size(), Array(z.results) if is_instance_valid(z) else [], z.window_s if is_instance_valid(z) else -1.0]
		_end_zone(rec)
		await _clear_held(player)
		await _secs(0.5)
	_expect(int(late[""][0]) == 1 and _near(float(late[""][2]), 1.0), "Classic: a stone at 0.85 s is a full catch, held (window %.2f s)" % late[""][2])
	_expect(int(late[id][0]) == 0 and "late" in (late[id][1] as Array) and _near(float(late[id][2]), 0.8),
			"Juggle: a stone at 0.85 s is late, dropped (window %.2f s, %s)" % [late[id][2], late[id][1]])
	_expect(RingRules.guard_outcome("earth", "stone_form/spike", 0.9, player) == "late"
			and RingRules.guard_outcome("earth", "stone_form/spike", 0.9, bot) == "catch"
			and RingRules.guard_outcome("earth", "stone_form/spike", 0.75, player) == "catch",
			"Juggle: the % ring's full catch is 0.8 s for the wearer, 1.0 s for the bot")
	_wear(player, "")
	# a bot wearing it catches two and throws both back
	_wear(bot, id)
	var b := await _three_stones(bot, player)
	_expect(int(b[0]) == 2 and int(b[2]) == 2, "Juggle on the bot: its Catch holds two (%d, then %d)" % [b[0], b[2]])
	var two := BendZone.held_stones(bot)
	bot.held = false                                 # (its own mind: E again or its Fissure throws what it holds)
	for i in 60:
		await _secs(0.1)
		if BendZone.held_stones(bot).is_empty():
			break
	bot.held = true
	var thrown := 0
	for s in two:
		if not is_instance_valid(s) or (not s.has_meta(&"bend_held_by") and not s.has_meta(FormStone.LOOSE_META)):
			thrown += 1
	_expect(BendZone.held_stones(bot).is_empty() and thrown == 2, "Juggle on the bot: it throws both back, one after the other (%d of 2)" % thrown)
	_wear(bot, "")
	await _secs(1.5)
	await _clear_held(bot)
	await _clear_held(player)


# ---------------------------------------------------------------- Return to Sender
## A stone thrown at the player and caught by his Catch on E (the real lock: guard_override), E let go, and E again `after_s`
## after the catch: {clean, ret (the stone's bend_return: mps, beat), pressed (the second E's lock start after the catch)}.
func _return_after(id: String, after_s: float) -> Dictionary:
	_wear(player, id)
	sc.guard_override = true
	await _secs(0.3)                                 # (the guard's lock filled: the Catch stands)
	_stone_at(player, bot)
	await _ticks(3)
	var s := BendZone.held_stone(player)
	sc.guard_override = false
	if s == null:
		return {"clean": false, "ret": {}, "pressed": -1.0}
	var caught := float(s.get_meta(&"bend_caught_at", -1.0))
	var clean := bool(s.get_meta(&"bend_clean", false))
	while BendStatus.now() < caught + after_s:
		await _ticks(1)
	sc.guard_override = true
	await _secs(0.3)
	sc.guard_override = false
	var ret: Dictionary = s.get_meta(&"bend_return", {}) if is_instance_valid(s) else {}
	var out := {"clean": clean, "ret": ret, "pressed": sc.lock_began_at - caught}
	await _secs(1.2)
	await _clear_held(player)
	return out


func _return_to_sender() -> void:
	var id := "earth.catch.return_to_sender"
	_expect(BendLoadout.why_not(id) == "" and id in BendLoadout.behaviour(), "Return to Sender is live, its code built (%s)" % BendLoadout.why_not(id))
	var c := await _return_after("", 0.05)
	var w := await _return_after(id, 0.05)
	var w_late := await _return_after(id, 0.35)
	var cm := float((c.ret as Dictionary).get("mps", 0.0))
	var wm := float((w.ret as Dictionary).get("mps", 0.0))
	var lm := float((w_late.ret as Dictionary).get("mps", 0.0))
	_expect(bool(c.clean) and bool(w.clean) and bool(w_late.clean) and cm > 0.0, "three clean catches on E, each thrown back with E again (%.1f m/s)" % cm)
	_expect(bool((w.ret as Dictionary).get("beat", false)) and _near(wm / maxf(cm, 0.01), 1.15, 0.005) and float(w.pressed) <= 0.2,
			"Return to Sender: E again %.2f s after the clean catch, on the Beat: it flies x%.3f (%.1f m/s)" % [w.pressed, wm / maxf(cm, 0.01), wm])
	_expect(not bool((c.ret as Dictionary).get("beat", false)), "Classic: the same E at the same time throws it as ever (x1, no Beat)")
	_expect(not bool((w_late.ret as Dictionary).get("beat", false)) and _near(lm, cm, 0.01),
			"Return to Sender: E again %.2f s after the catch is past the Beat: as ever (%.1f m/s)" % [w_late.pressed, lm])
	# its minus: a late catch's throw-back readies in 0.4 s (Classic 0.35)
	var locks := {}
	for wid: String in ["", id]:
		_wear(player, wid)
		var at := player.global_position + Vector3.UP * 1.25 - player.global_basis.z * 0.6
		var st := FormStone.ball(current_scene, at, {"radius_m": 0.2, "rise_s": 0.01, "life_s": 30.0}, 3, "stone")
		st.state = FormStone.State.RESTING
		st.freeze = true
		st.set_meta(&"bend_held_by", player.get_instance_id())
		st.set_meta(&"bend_caught_at", BendStatus.now())
		locks[wid] = BendZone.guard_lock_s(player, 0.2)
		st.remove_meta(&"bend_held_by")
		st.queue_free()
		await _ticks(2)
	_expect(_near(float(locks[""]), 0.35, 0.001) and _near(float(locks[id]), 0.4, 0.001),
			"Return to Sender: a late catch's return locks %.2f s (Classic %.2f)" % [locks[id], locks[""]])
	_wear(player, "")
	# the bot wearing it: its clean catch thrown back on the Beat (its own E, its own timing)
	_wear(bot, id)
	var rec := _catch(bot, 1.0)
	await _ticks(2)
	_stone_at(bot, player)
	await _ticks(3)
	var held := BendZone.held_stone(bot)
	var clean_b := held != null and bool(held.get_meta(&"bend_clean", false))
	_end_zone(rec)
	bot.held = false
	for i in 30:
		await _secs(0.05)
		if held == null or not is_instance_valid(held) or not held.has_meta(&"bend_held_by"):
			break
	bot.held = true
	var bret: Dictionary = held.get_meta(&"bend_return", {}) if held != null and is_instance_valid(held) else {}
	_expect(clean_b and bool(bret.get("beat", false)), "Return to Sender on the bot: its clean catch thrown back on the Beat (%s)" % [bret])
	_wear(bot, "")
	await _secs(1.2)
	await _clear_held(bot)


# ---------------------------------------------------------------- Kick-Up
## The player's Pebbles cast at world point `p` (the cast's own path: BendEffects.apply with his crosshair on it): [his loose
## stones after it lands, the cast's spread (deg), the newest loose stone].
func _pebbles_at(id: String, p: Vector3) -> Array:
	_wear(player, id)
	await _clear_held(player)
	await _aim_at(p)
	BendEffects.apply(pc, "rock_jab", "pebbles", SwayMoves.move("rock_jab").bend.pebbles)
	var spread := float((BendEffects.last_of(pc).get("spec", {}) as Dictionary).get("spread_deg", -1.0))
	await _secs(1.2)
	var loose := FormStone.loose_of(player)
	return [loose.size(), spread, loose[loose.size() - 1] if not loose.is_empty() else null]


func _kick_up() -> void:
	var id := "earth.pebbles.kick_up"
	_expect(BendLoadout.why_not(id) == "" and id in BendLoadout.behaviour(), "Kick-Up is live, its code built (%s)" % BendLoadout.why_not(id))
	var deck := _deck_off(5.0, 70.0)
	var c := await _pebbles_at("", deck)
	var w := await _pebbles_at(id, deck)
	_expect(int(c[0]) == 0 and _near(float(c[1]), 3.0), "Classic: Pebbles that hit nobody leave nothing (%d), spread %.1f deg" % [c[0], c[1]])
	var st: Node3D = w[2]
	_expect(int(w[0]) == 1 and _near(float(w[1]), 3.6) and st != null and st.global_position.distance_to(deck) < 2.5,
			"Kick-Up: a volley that hits nobody leaves one loose stone of his where it landed (%d, %.2f m from the aim), spread %.1f deg"
			% [w[0], st.global_position.distance_to(deck) if st != null else -1.0, w[1]])
	await _bot_at(6.0)
	var hit := await _pebbles_at(id, NpcSenses.chest_of(bot))
	_expect(int(hit[0]) == 0, "Kick-Up: a volley that hits the bot leaves none (%d)" % hit[0])
	# a stone left, then his Fissure run under it throws it on
	var w2 := await _pebbles_at(id, deck)
	var s2: Node3D = w2[2]
	await _secs(0.4)
	var thrown := false
	if s2 != null:
		await _aim_at(s2.global_position)
		BendEffects.apply(pc, "earth_shove", "push", SwayMoves.move("earth_shove").bend.push)
		for i in 40:
			await _ticks(2)
			if not is_instance_valid(s2) or GustLift.busy(s2) or not s2.has_meta(FormStone.LOOSE_META):
				thrown = true
				break
	_expect(s2 != null and thrown, "Kick-Up: his Fissure run under the stone throws it on")
	_wear(player, "")
	await _secs(1.0)
	await _clear_held(player)


# ---------------------------------------------------------------- Avalanche
## The Avalanche stones `by` let roll in the next `s` seconds (their bolts, met as they fly): [{dir, low_m, info}], and how
## many struck someone.
func _rolling(by: Node3D, s: float) -> Array:
	var seen := {}
	var struck := [0]
	for i in ceili(s * Engine.physics_ticks_per_second / 2.0):
		await _ticks(2)
		for n in get_nodes_in_group(BendBolt.GROUP):
			var b := n as BendBolt
			if b == null or seen.has(b.get_instance_id()) or b.caster != by or not bool(b.info.get("avalanche", false)):
				continue
			var flat := Vector3(b.velocity.x, 0.0, b.velocity.z).normalized()
			seen[b.get_instance_id()] = {"dir": flat, "low_m": b.global_position.y - FormEffects.ground_at(b, b.global_position).y,
					"info": b.info.duplicate()}
			b.struck.connect(func(_who: Node, _d: float) -> void: struck[0] += 1)
	return [seen.values(), struck[0]]


## The player's Boulder cast (Stone Form at the Boulder, the cast's own path) with his crosshair on deck point `p`.
func _boulder_at(p: Vector3) -> void:
	await _aim_at(p + Vector3.UP * 0.1)
	sc.set_mode("stone_form", "cannonball")
	FormEffects.apply(sc, "stone_form", null, p)


func _avalanche() -> void:
	var id := "earth.boulder.avalanche"
	_expect(BendLoadout.why_not(id) == "" and id in BendLoadout.behaviour(), "Avalanche is live, its code built (%s)" % BendLoadout.why_not(id))
	await _stage(-4.5, 4.5)
	var deck := _deck_off(5.0, 60.0)
	var got := {}
	for w: String in ["", id]:
		_wear(player, w)
		await _boulder_at(deck)
		got[w] = await _rolling(player, 1.6)
		await _secs(1.0)
	var c: Array = got[""][0]
	var a: Array = got[id][0]
	_expect(c.is_empty(), "Classic: the Boulder bursts where it lands, nothing rolls on (%d)" % c.size())
	var fan := -1.0
	var low := true
	var one := a.size() == 3
	if a.size() == 3:
		var dirs: Array = a.map(func(e: Dictionary) -> Vector3: return e.dir)
		for e: Dictionary in a:
			low = low and absf(float(e.low_m) - BendBolt.LOW_M) < 0.2
			one = one and int(e.info.get("volley_n", 0)) == 3 and int(e.info.volley_id) == int(a[0].info.volley_id) \
					and String(e.info.get("tag", "")) == "stone_form/cannonball"
		for i in 3:
			for j in 3:
				fan = maxf(fan, rad_to_deg((dirs[i] as Vector3).angle_to(dirs[j])))
	_expect(a.size() == 3 and _near(fan, 30.0, 1.5) and low, "Avalanche: where it lands, three stones roll on along the deck, fanned 15 deg (%d, %.1f deg across, low %s)" % [a.size(), fan, low])
	_expect(one, "Avalanche: the three are one volley of 3 with the Boulder's tag")
	# rolled into the bot: the Boulder's 16% between them; the first knocks at the node's base
	var wc := BendLoadout.hit_class(player, RingRules.class_of("stone_form/cannonball"))
	_expect(_near(float(wc.base), 5.9, 0.001) and _near(float(RingRules.class_of("stone_form/cannonball").base), 7.4, 0.001),
			"Avalanche: the wearer's Boulder knocks at base 5.9 (the class's 7.4)")
	await _stage(-4.5, 1.5)
	var p0 := rules.pct_of(bot)
	BendStatus.anchor(bot, 3.0)                      # (his feet kept where they are: the first's knock does not carry him off the rest)
	await _boulder_at(_deck_on_line(4.7))
	var r: Array = await _rolling(player, 1.6)
	bot.remove_meta(&"bend_anchor")
	var k := int(r[1])
	var d := rules.pct_of(bot) - p0
	_expect(k >= 1 and _near(d, 16.0 / 3.0 * float(k) * RingRules.stock_num("pct_scale", 1.0), 0.05),
			"Avalanche: rolled into the bot, each of the %d stones that reach him adds a third of the Boulder's 16%% (%.2f%%)" % [k, d])
	await _secs(1.5)
	# the bot's Catch holds one, the others drop at its feet as the player's loose stones
	await _stage(-4.5, 4.5)
	await _clear_held(bot)
	var rec := _catch(bot, 3.0)
	var loose0 := FormStone.loose_of(player).size()
	await _boulder_at(_deck_on_line(4.5))
	await _secs(1.4)
	var held_b := BendZone.held_stones(bot).size()
	var loose1 := FormStone.loose_of(player).size()
	_end_zone(rec)
	_expect(held_b == 1 and loose1 - loose0 == 2, "Avalanche: the bot's Catch holds one, two drop at its feet as the player's loose stones (%d held, %d loose)" % [held_b, loose1 - loose0])
	await _clear_held(bot)
	await _clear_held(player)
	_wear(player, "")
	# the bot wearing it: its own Boulder, flown over the burrowed player, breaks on the deck the same
	_wear(bot, id)
	await _stage(2.0, 9.0)
	player.set_meta(&"bend_under_until", BendStatus.now() + 3.0)
	BendCast.cast(BendCaster.of(bot), "stone_form", "cannonball", player, player.global_position)
	var rb: Array = await _rolling(bot, 2.0)
	player.remove_meta(&"bend_under_until")
	_expect((rb[0] as Array).size() == 3, "Avalanche on the bot: its Boulder breaks into three where it lands (%d)" % (rb[0] as Array).size())
	_wear(bot, "")
	await _secs(1.0)
	await _clear_held(player)


## The deck `dist` m from the player on the line to the bot.
func _deck_on_line(dist: float) -> Vector3:
	return _deck_off(dist, 0.0)
