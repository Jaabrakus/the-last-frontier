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
##   Heave             the player's Column through his own lock (RMB held: held_override), let go 0.05 s after it fills: on the
##                     Beat, the bot launched harder (base 11.3: W x 1 more than 0.4 s after, which is Classic's 10.3); its lock
##                     x1.7/1.6; the bot wearing it lets go on the Beat and launches the player harder
##   Kiln Stone        a Fire Wall (the bot's) between them: the player's Pebbles and Spike thrown through it come out heated
##                     (Classic: plain) and knock the bot with base x1.15; the bot's Parry on the beat sends heated pebbles back
##                     (plain ones it only stops); its Turn douses them; the bot wearing it heats its own Spike the same
##   Rubble Wall       the wearer's wall rises in 0.8 s (0.7); shot down it leaves two loose stones of his at its foot, broken
##                     by his third (the cap) the same (Classic none); the bot's Fissure throws them on; the bot's own walls too
##   Quarry            his Fissure through his own lock let go on the Beat into his own wall: a chunk torn off and thrown on
##                     along the crack, the wall unworn (the first); again: a chunk and one hit; let go past the Beat: no chunk,
##                     the wall worn as ever (Classic on the Beat the same); his walls rise in 0.8 s; the bot's Beat Fissure too
##   Reinforce         his wall shot once and Mended (the cast's builder): the next two shots free, the third counts (Classic:
##                     one free); Mend's lock x2.6/2.2 through his own lock time; the bot's Mend the same
##   Sulphur (set)     his Pebbles add 4% (5); his Boulder landing leaves a 2.5 m, 3 s cloud there (Classic none); a cloud on the
##                     bot ticks 1% x the pace each 0.5 s, 6 at most, no knock, no slow (one tick a 0.5 s in two clouds); his
##                     own gas never hurts him; his stone clashing with the bot's raises a cloud; fire lights it (the burst,
##                     the lighter's), water washes it, wind carries it on (the mover's); the bot steps out of his gas; the
##                     bot wearing the set leaves its own
##   Sulphur twists    (each worn with the set) Spike: a 1.5 m puff where it stops, 12%; Boulder: three puffs along its flight,
##                     13%; Fuming Column: a 2 m plume where it rose, base 9.3; Brimstone Wall: 3 hits, shot down a cloud on
##                     the shooter's side; Flint Pebbles: his pebbles light his own gas (his burst), never the bot's; his clouds
##                     2.5 s; Sulphur Heart: his clouds 2 m, his locks fill x1.15 in his own gas (the bot's too)
##   Sulphur Vent      (pass 2; worn with the set) not worn (Classic, the set alone): 4 has one move, a double tap readies the
##                     wall again; worn: 4 tapped twice (the hotbar's own taps) readies it, named on the bar, the wall's pose,
##                     lock 0.9 s (1.6); cast through his own lock: a 3 m cloud for 4 s where he aims (2 m at the nearest, 6
##                     at the farthest), on the bot 6% at most, no knock, never on him; one at a time (his other gas stays);
##                     fire lights it; his Earth Wall rises in 0.8 s (0.7); a bot wearing it has it as an option, locks it
##                     0.9 s, places it on the player in a real fight, and never while its gas stands on him (a bot wearing
##                     nothing has no vent)
##   the set's gas     (pass 2: the reactions the set's text names, Ignited Sulphur, Live Gas, Wind Carries Clouds) the burst
##                     reaches 1.5x the cloud's round, IGNITED! called out; cones by kind (Breath lights, the Wave washes, the
##                     air Palm carries 4 m); a Fire Wall on a cloud lights it, a Wind Wall carries it off its face; lightning
##                     through a cloud charges it (half the strike's % on the bot inside, no launch, the gas stays)
##   worn together     (pass 2: the tree's stacking and excludes) Rubble Wall and Quarry: the rise 0.7 x (0.8/0.7)^2; the
##                     Vent with Rubble Wall: the Vent's 0.8 (a set twist's number is final); Clean Return with Return to
##                     Sender: the return lock 0.48; Heave and Fuming Column, Thick and Brimstone Wall, Heavy and Sulphur
##                     Boulder never worn together
## Last line "TALENTS EARTH PASSED (n checks)" or "... FAILED"; exit 0 only on a pass. A user arg only=<part> (after --: thick_wall,
## juggle, ..., sulphur_twists, vent, reactions, combos) plays that part alone, for a quick look; the gate runs them all.

const NAME := "TALENTS EARTH"
const BendGas := preload("res://scripts/bending/bend_gas.gd")
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
	var parts: Array[Callable] = [_thick_wall, _juggle, _return_to_sender, _kick_up, _avalanche, _heave, _kiln_stone, _rubble, _quarry,
			_reinforce, _sulphur_set, _sulphur_twists, _vent, _reactions, _combos]
	var only := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	for part: Callable in parts:
		if only == "" or String(part.get_method()).trim_prefix("_") == only:
			await part.call()
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


# ---------------------------------------------------------------- Heave
## The speed `n` is launched at by a hit of tag `tag` within `s` seconds (RingRules.launched), -1 none.
func _launch_of(n: Node3D, tag: String, s: float) -> float:
	var got := [-1.0]
	var cb := func(b: Node3D, v: Vector3, _st: float, _by: Node, t: String) -> void:
		if b == n and t.begins_with(tag) and got[0] < 0.0:
			got[0] = v.length()
	rules.launched.connect(cb)
	await _secs(s)
	rules.launched.disconnect(cb)
	return float(got[0])


## The player's Column through his own lock (RMB held: held_override, Fissure's key at its Column), let go `after_s` after the
## lock filled, his crosshair on the bot's feet: [the bot's launch speed, a Beat cast, the lock's time (s)].
func _column_after(id: String, after_s: float) -> Array:
	_wear(player, id)
	await _stage(-3.0, 3.0)
	rules.reset_pct(bot, 0.0)
	sc.ready_spell("earth_shove")
	sc.set_mode("earth_shove", "column")
	await _aim_at(bot.global_position + Vector3.UP * 0.05)
	var beat0 := sc.beat_at
	var t0 := BendStatus.now()
	sc.held_override = true
	for i in 600:
		await _ticks(1)
		if sc.state == SwayCaster.State.FULL:
			break
	var lock_s := BendStatus.now() - t0
	await _secs(after_s)
	sc.held_override = false
	var v := await _launch_of(bot, "earth_shove/column", 1.5)
	return [v, sc.beat_at > beat0, lock_s]


func _heave() -> void:
	var id := "earth.column.heave"
	_expect(BendLoadout.why_not(id) == "" and id in BendLoadout.behaviour(), "Heave is live, its code built (%s)" % BendLoadout.why_not(id))
	_expect(BendLoadout.beat_paid(_worn_body(id)) and not BendLoadout.beat_paid(_worn_body("")), "Heave pays on the Beat; nothing worn, the Beat does nothing")
	var c := await _column_after("", 0.05)
	var hb := await _column_after(id, 0.05)
	var hl := await _column_after(id, 0.4)
	var w := RingRules.weight_of("earth")
	_expect(float(c[0]) > 0.0 and not bool(c[1]), "Classic: a Column let go 0.05 s after its lock fills launches the bot (%.2f m/s), no Beat" % c[0])
	_expect(bool(hb[1]) and float(hb[0]) - float(hl[0]) > 0.5 * w and float(hb[0]) - float(hl[0]) < 1.2 * w,
			"Heave: let go on the Beat it launches harder (%.2f m/s, %.2f 0.4 s after: base 11.3 from 10.3, W %.2f)" % [hb[0], hl[0], w])
	_expect(not bool(hl[1]) and _near(float(hl[0]), float(c[0]), 0.05), "Heave: let go 0.4 s after, past the Beat: as Classic (%.2f, %.2f)" % [hl[0], c[0]])
	_expect(_near(float(hb[2]) / float(c[2]), 1.7 / 1.6, 0.03), "Heave: its Column's lock %.2f s (Classic %.2f: x1.7/1.6)" % [hb[2], c[2]])
	sc.held_override = null
	_wear(player, "")
	# the bot wearing it: its own lock, let go when it fills, on the Beat: the player launched harder
	var nb: NpcBending = bot.brain.bending
	var vs := {}
	for wid: String in ["", id]:
		_wear(bot, wid)
		await _stage(-3.0, 3.0)
		rules.reset_pct(player, 0.0)
		var b0 := nb.beat_at
		bot.held = false
		nb.begin("earth_shove", "column")
		var v := await _launch_of(player, "earth_shove/column", 3.5)
		bot.held = true
		vs[wid] = [v, nb.beat_at > b0]
		await _secs(1.0)
	_expect(not bool(vs[""][1]) and bool(vs[id][1]) and float(vs[id][0]) - float(vs[""][0]) > 0.5 * w,
			"Heave on the bot: its Column let go on the Beat launches the player harder (%.2f m/s, Classic's %.2f)" % [vs[id][0], vs[""][0]])
	_wear(bot, "")


# ---------------------------------------------------------------- Kiln Stone
## A Fire Wall of the bot's across the line `dist` m from the player (any fire wall heats: his, an ally's).
func _fire_wall_at(dist: float) -> BendZone:
	var way := bot.global_position - player.global_position
	way.y = 0.0
	way = way.normalized()
	return BendZone.make(bot, "fire_wall", FormEffects.ground_at(player, player.global_position + way * dist),
			{"width_m": 5.0, "height_m": 2.2, "thick_m": 0.6, "life_s": 60.0, "damage_s": 0.0}, way)


## The stone bolts `by` throws next (seen in flight `s` s): [heated ones, plain ones, sent back (now another's), their ends:
## [why, heated at its end, another's at its end, heated at some time in flight]].
func _stone_bolts(by: Node3D, s: float) -> Array:
	var seen := {}
	var was_hot := {}
	var ends := []
	for i in ceili(s * Engine.physics_ticks_per_second / 2.0):
		await _ticks(1)
		for n in get_nodes_in_group(BendBolt.GROUP):
			var b := n as BendBolt
			if b == null or b.kind != "stone":
				continue
			if seen.has(b.get_instance_id()):
				if b.heated:
					was_hot[b.get_instance_id()] = true
				continue
			if b.caster == by:
				seen[b.get_instance_id()] = b
				var bb := b
				var bid := b.get_instance_id()
				b.ended.connect(func(why: String) -> void: ends.append([why, bb.heated, bb.caster != by, bb.heated or was_hot.has(bid)]))
	await _secs(0.3)
	var hot := 0
	var plain := 0
	var back := 0
	for e: Array in ends:
		if bool(e[1]):
			hot += 1
		else:
			plain += 1
		if bool(e[2]):
			back += 1
	return [hot, plain, back, ends]


func _kiln_stone() -> void:
	var id := "earth.stone.kiln_stone"
	_expect(BendLoadout.why_not(id) == "" and id in BendLoadout.behaviour(), "Kiln Stone is live, its code built (%s)" % BendLoadout.why_not(id))
	await _stage(-4.5, 1.5)
	var fw := _fire_wall_at(3.0)
	var w := RingRules.weight_of("earth")
	# Pebbles through the fire at the bot: the first knocks (a set knock: its base, x1.15 heated)
	var peb := {}
	for wid: String in ["", id]:
		_wear(player, wid)
		rules.reset_pct(bot, 0.0)
		await _aim_at(NpcSenses.chest_of(bot))
		var got := [-1.0, false]
		var cb := func(b: Node3D, v: Vector3, _st: float, _by: Node, t: String) -> void:
			if b == bot and t == "rock_jab/pebbles" and got[0] < 0.0:
				got[0] = v.length()
		rules.launched.connect(cb)
		BendEffects.apply(pc, "rock_jab", "pebbles", SwayMoves.move("rock_jab").bend.pebbles)
		var sb: Array = await _stone_bolts(player, 0.6)
		rules.launched.disconnect(cb)
		peb[wid] = [got[0], sb[0], sb[1]]
		await _stage(-4.5, 1.5)
	_expect(int(peb[""][1]) == 0 and int(peb[id][1]) >= 2, "Kiln Stone: his Pebbles through the Fire Wall come out heated (%d of them; Classic %d)" % [peb[id][1], peb[""][1]])
	_expect(float(peb[""][0]) > 0.0 and _near(float(peb[id][0]) / float(peb[""][0]), 1.15, 0.01),
			"Kiln Stone: a heated pebble knocks with base x%.3f (%.2f m/s, Classic %.2f)" % [float(peb[id][0]) / maxf(float(peb[""][0]), 0.01), peb[id][0], peb[""][0]])
	# the Spike through the fire
	var sp := {}
	for wid: String in ["", id]:
		_wear(player, wid)
		rules.reset_pct(bot, 0.0)
		await _aim_at(NpcSenses.chest_of(bot))
		sc.set_mode("stone_form", "spike")
		var hot := [false]
		FormEffects.apply(sc, "stone_form", null, bot.global_position)
		var v := -1.0
		var got2 := [-1.0]
		var cb2 := func(b: Node3D, vv: Vector3, _st: float, _by: Node, t: String) -> void:
			if b == bot and t.begins_with("stone_form/spike") and got2[0] < 0.0:
				got2[0] = vv.length()
		rules.launched.connect(cb2)
		for i in 90:
			await _ticks(1)
			for l in get_nodes_in_group(GustLift.GROUP):
				if (l as GustLift).by() == player and (l as GustLift).heated:
					hot[0] = true
		rules.launched.disconnect(cb2)
		v = float(got2[0])
		sp[wid] = [v, hot[0]]
		await _stage(-4.5, 1.5)
	var diff := float(sp[id][0]) - float(sp[""][0])
	_expect(bool(sp[id][1]) and not bool(sp[""][1]), "Kiln Stone: his Spike flown through the Fire Wall is heated (Classic: plain)")
	_expect(float(sp[""][0]) > 0.0 and diff > 0.6 * w * 5.8 * 0.15 and diff < 1.05 * w * 5.8 * 0.15,
			"Kiln Stone: the heated Spike launches the bot harder by its base x1.15 (%.2f m/s, Classic %.2f)" % [sp[id][0], sp[""][0]])
	# the guards: a Parry on the beat sends heated pebbles back, plain ones it only stops; a Turn douses them
	var bbc := BendCaster.of(bot)
	var guard := {}
	for g: Array in [["", "fire_parry", "parry"], [id, "fire_parry", "parry"], [id, "water_redirect", "redirect"]]:
		_wear(player, String(g[0]))
		await _aim_at(NpcSenses.chest_of(bot))
		BendEffects.apply(bbc, String(g[1]), String(g[2]), (SwayMoves.move(String(g[1])).bend as Dictionary)[String(g[2])])
		BendEffects.apply(pc, "rock_jab", "pebbles", SwayMoves.move("rock_jab").bend.pebbles)
		guard["%s/%s" % [g[0], g[2]]] = await _stone_bolts(player, 0.6)
		await _secs(0.8)
		await _stage(-4.5, 1.5)
	var pp: Array = guard["%s/parry" % id]
	var cp: Array = guard["/parry"]
	var tt: Array = guard["%s/redirect" % id]
	_expect(int(pp[2]) >= 2, "Kiln Stone: the bot's Parry on the beat sends the heated pebbles back, his now (%d of %d)" % [pp[2], pp[3].size()])
	_expect(int(cp[2]) == 0, "Classic: plain pebbles at a Parry are stopped, none sent back (%s)" % [cp[3]])
	var doused := 0
	for e: Array in tt[3]:
		if bool(e[3]) and not bool(e[1]):
			doused += 1                              # (heated through the fire, plain at its end)
	_expect(int(tt[0]) == 0 and doused >= 2, "Kiln Stone: the bot's Turn douses them to plain stones (%s)" % [tt[3]])
	_wear(player, "")
	# the bot wearing it: its Spike through the fire comes out heated
	_wear(bot, id)
	await _stage(-4.5, 1.5)
	var bot_hot := false
	BendCast.cast(bbc, "stone_form", "spike", player, player.global_position)
	for i in 90:
		await _ticks(1)
		for l in get_nodes_in_group(GustLift.GROUP):
			if (l as GustLift).by() == bot and (l as GustLift).heated:
				bot_hot = true
	_expect(bot_hot, "Kiln Stone on the bot: its Spike thrown through the Fire Wall comes out heated")
	_wear(bot, "")
	if is_instance_valid(fw):
		fw.end("test")
	await _stage(-4.5, 4.5)


# ---------------------------------------------------------------- Rubble Wall
## An Earth Wall of `by`'s (the builder its cast calls) `dist` m toward the other fighter, risen.
func _wall_of(by: Node3D, dist: float) -> FormRaised:
	var other: Node3D = bot if by == player else player
	var way := other.global_position - by.global_position
	way.y = 0.0
	way = way.normalized()
	var r := FormEffects.earth_wall(BendCaster.of(by), by.global_position + way * dist, SwayMoves.move("earth_wall"), "earth")
	await _secs(1.0)
	return r


## Wall `r` shot down by water bolts from its far side (from `by`'s foe's side); the shots it took (-1: still up).
func _shoot_down(r: FormRaised, shooter: Node3D) -> int:
	var shots := 0
	if r == null:
		return -1
	var mid := r.global_position + Vector3.UP * 1.0
	var way := shooter.global_position - mid
	way.y = 0.0
	way = way.normalized()
	while is_instance_valid(r) and r.state != FormRaised.State.CRUMBLING and shots < 10:
		BendBolt.launch(shooter, mid + way * 4.0, -way, SHOT)
		shots += 1
		await _secs(0.35)
	return shots if not is_instance_valid(r) or r.state == FormRaised.State.CRUMBLING else -1


## `by`'s loose stones within `m` of `at`.
func _loose_near(by: Node3D, at: Vector3, m := 2.5) -> Array:
	return FormStone.loose_of(by).filter(func(s: Variant) -> bool: return (s as Node3D).global_position.distance_to(at) <= m)


func _rubble() -> void:
	var id := "earth.wall.rubble"
	_expect(BendLoadout.why_not(id) == "" and id in BendLoadout.behaviour(), "Rubble Wall is live, its code built (%s)" % BendLoadout.why_not(id))
	var got := {}
	for wid: String in ["", id]:
		_wear(player, wid)
		await _stage(-4.5, 4.5)
		await _clear_held(player)
		var r := await _wall_of(player, 3.0)
		var rise := r.rise_s if r != null else -1.0
		var at := r.global_position if r != null else Vector3.ZERO
		var shots := await _shoot_down(r, bot)
		await _secs(1.0)
		got[wid] = [rise, shots, _loose_near(player, at).size()]
	_expect(_near(float(got[""][0]), 0.7) and _near(float(got[id][0]), 0.8), "Rubble Wall: the wearer's wall rises in %.1f s (Classic %.1f)" % [got[id][0], got[""][0]])
	_expect(int(got[""][1]) == 4 and int(got[""][2]) == 0, "Classic: a wall shot down leaves no stones (%d shots, %d)" % [got[""][1], got[""][2]])
	_expect(int(got[id][1]) == 4 and int(got[id][2]) == 2, "Rubble Wall: shot down it leaves two loose stones of his at its foot (%d shots, %d)" % [got[id][1], got[id][2]])
	# broken by his third (the cap of two standing): the oldest's two stones
	await _clear_held(player)
	var first := await _wall_of(player, 2.5)
	var at1 := first.global_position
	await _wall_of(player, 4.0)
	var third := await _wall_of(player, 5.5)
	await _secs(0.8)
	_expect(not is_instance_valid(first) or first.state == FormRaised.State.CRUMBLING, "(his third wall broke his first: the cap)")
	_expect(_loose_near(player, at1, 1.8).size() == 2, "Rubble Wall: broken by his third, his first leaves two stones (%d)" % _loose_near(player, at1, 1.8).size())
	for w in get_nodes_in_group(FormRaised.GROUP):
		if w is FormRaised and int((w as Node).get_meta(&"bend_by", 0)) == player.get_instance_id():
			(w as FormRaised).crumble("time")
	await _secs(1.6)
	# a mirror: the bot's Fissure run under them throws them on
	await _clear_held(player)
	var r2 := await _wall_of(player, 4.5)
	var at2 := r2.global_position
	await _shoot_down(r2, bot)
	await _secs(1.2)
	var mine := _loose_near(player, at2)
	BendEffects.apply(BendCaster.of(bot), "earth_shove", "push", SwayMoves.move("earth_shove").bend.push)
	var taken := 0
	for i in 60:
		await _ticks(2)
		taken = 0
		for s: Variant in mine:
			if not is_instance_valid(s) or GustLift.busy(s as Node) or not (s as Node).has_meta(FormStone.LOOSE_META):
				taken += 1
		if taken == mine.size():
			break
	_expect(mine.size() == 2 and taken == 2, "Rubble Wall: the bot's Fissure run under his rubble throws it on (%d of %d)" % [taken, mine.size()])
	_wear(player, "")
	await _secs(1.0)
	# the bot wearing it: its own wall shot down leaves its stones
	_wear(bot, id)
	await _stage(-4.5, 4.5)
	var rb := await _wall_of(bot, 3.0)
	var atb := rb.global_position if rb != null else Vector3.ZERO
	await _shoot_down(rb, player)
	await _secs(1.0)
	_expect(_loose_near(bot, atb).size() == 2, "Rubble Wall on the bot: its wall shot down leaves two stones of its own (%d)" % _loose_near(bot, atb).size())
	_wear(bot, "")
	await _clear_held(bot)
	await _clear_held(player)


# ---------------------------------------------------------------- Quarry
## The player's move `m` at `md` through his own lock (RMB held: held_override, the key's move readied), his crosshair on `at`,
## let go `after_s` after the lock filled. Whether it went on the Beat.
func _lock_release(m: String, md: String, at: Vector3, after_s: float) -> bool:
	sc.ready_spell(m)
	sc.set_mode(m, md)
	await _aim_at(at)
	var beat0 := sc.beat_at
	sc.held_override = true
	for i in 600:
		await _ticks(1)
		if sc.state == SwayCaster.State.FULL:
			break
	await _secs(after_s)
	sc.held_override = false
	await _ticks(2)
	sc.held_override = null
	return sc.beat_at > beat0


## The stones `by` throws from a wall (a GustLift whose stone starts within 2 m of `w`) over the next `s` s.
func _chunks_from(by: Node3D, w_at: Vector3, s: float) -> int:
	var seen := {}
	for i in ceili(s * Engine.physics_ticks_per_second / 2.0):
		await _ticks(2)
		for l in get_nodes_in_group(GustLift.GROUP):
			var gl := l as GustLift
			if gl.by() == by and not seen.has(gl.get_instance_id()) and gl.stone != null and is_instance_valid(gl.stone) \
					and gl.stone.global_position.distance_to(w_at + Vector3.UP) < 2.0:
				seen[gl.get_instance_id()] = true
	return seen.size()


func _quarry() -> void:
	var id := "earth.wall.quarry"
	_expect(BendLoadout.why_not(id) == "" and id in BendLoadout.behaviour(), "Quarry is live, its code built (%s)" % BendLoadout.why_not(id))
	var res := {}
	for wid: String in ["", id]:
		_wear(player, wid)
		await _stage(-4.5, 4.5)
		await _clear_held(player)
		var w := await _wall_of(player, 3.0)
		var rows: Array = []
		for after: float in ([0.05, 0.05, 0.3] if wid != "" else [0.05]):
			var h0 := w.hits if is_instance_valid(w) else -1
			var beat := await _lock_release("earth_shove", "push", NpcSenses.chest_of(bot), after)
			var n := await _chunks_from(player, w.global_position if is_instance_valid(w) else Vector3.ZERO, 1.2)
			rows.append([beat, n, (w.hits if is_instance_valid(w) else 99) - h0])
			await _secs(0.4)
		res[wid] = [rows, w.rise_s if is_instance_valid(w) else -1.0]
		if is_instance_valid(w):
			w.crumble("time")
		await _secs(1.6)
	var c: Array = res[""][0]
	var q: Array = res[id][0]
	_expect(not bool(c[0][0]) and int(c[0][1]) == 0 and int(c[0][2]) >= 1,
			"Classic: a Fissure into his own wall tears nothing off, it wears it (%d chunks, +%d hits)" % [c[0][1], c[0][2]])
	_expect(bool(q[0][0]) and int(q[0][1]) == 1 and int(q[0][2]) == 0,
			"Quarry: let go on the Beat into his own wall, a chunk torn off and thrown on, the wall unworn (%d chunk, +%d hits)" % [q[0][1], q[0][2]])
	_expect(bool(q[1][0]) and int(q[1][1]) == 1 and int(q[1][2]) == 1, "Quarry: the next chunk of the same wall costs it a hit (%d chunk, +%d hit)" % [q[1][1], q[1][2]])
	_expect(not bool(q[2][0]) and int(q[2][1]) == 0 and int(q[2][2]) >= 1,
			"Quarry: let go past the Beat, no chunk, the wall worn as ever (%d chunks, +%d hits)" % [q[2][1], q[2][2]])
	_expect(_near(float(res[id][1]), 0.8) and _near(float(res[""][1]), 0.7), "Quarry: his walls rise in %.1f s (Classic %.1f)" % [res[id][1], res[""][1]])
	_wear(player, "")
	# the bot wearing it: its Fissure, let go when its lock fills (the Beat), into its own wall
	var nb: NpcBending = bot.brain.bending
	_wear(bot, id)
	await _stage(-4.5, 4.5)
	var bw := await _wall_of(bot, 3.0)
	bot.held = false
	nb.begin("earth_shove", "push")
	var bn := await _chunks_from(bot, bw.global_position if is_instance_valid(bw) else Vector3.ZERO, 2.5)
	bot.held = true
	_expect(bn >= 1, "Quarry on the bot: its Beat Fissure into its own wall throws a chunk on (%d)" % bn)
	_wear(bot, "")
	if is_instance_valid(bw):
		bw.crumble("time")
	await _secs(1.6)
	await _clear_held(player)


# ---------------------------------------------------------------- Reinforce
## One water bolt at wall `r` from `shooter`'s side; its hits after.
func _one_shot(r: FormRaised, shooter: Node3D) -> int:
	var mid := r.global_position + Vector3.UP * 1.0
	var way := shooter.global_position - mid
	way.y = 0.0
	way = way.normalized()
	BendBolt.launch(shooter, mid + way * 4.0, -way, SHOT)
	await _secs(0.35)
	return r.hits if is_instance_valid(r) else -1


## `by`'s wall shot once, Mended by `by` (FormEffects.mend, the cast's builder), then shot three times: [mended's stage,
## hits after each of the three].
func _mend_and_shoot(by: Node3D, shooter: Node3D) -> Array:
	var r := await _wall_of(by, 3.0)
	await _one_shot(r, shooter)
	var stage := FormEffects.mend(BendCaster.of(by), r, SwayMoves.move("mend"))
	var hs: Array = []
	for i in 3:
		hs.append(await _one_shot(r, shooter))
	if is_instance_valid(r):
		r.crumble("time")
	await _secs(1.6)
	return [stage, hs]


func _reinforce() -> void:
	var id := "earth.mend.reinforce"
	_expect(BendLoadout.why_not(id) == "" and id in BendLoadout.behaviour(), "Reinforce is live, its code built (%s)" % BendLoadout.why_not(id))
	await _stage(-4.5, 4.5)
	var got := {}
	for wid: String in ["", id]:
		_wear(player, wid)
		got[wid] = await _mend_and_shoot(player, bot)
	_expect(String(got[""][0]) == "worn" and got[""][1] == [0, 1, 2], "Classic: a mended wall takes its next shot free, then counts (%s)" % [got[""][1]])
	_expect(String(got[id][0]) == "worn" and got[id][1] == [0, 0, 1], "Reinforce: his mended wall takes its next two shots free, the third counts (%s)" % [got[id][1]])
	# Mend's lock, his own lock time for it
	var lk := {}
	for wid: String in ["", id]:
		_wear(player, wid)
		lk[wid] = sc._lock_time("mend", null, 1.0, 3.0)
	_expect(_near(float(lk[id]) / float(lk[""]), 2.6 / 2.2, 0.01), "Reinforce: Mend locks %.2f s (Classic %.2f: x2.6/2.2)" % [lk[id], lk[""]])
	_wear(player, "")
	# the bot's own Mend
	_wear(bot, id)
	var b: Array = await _mend_and_shoot(bot, player)
	_expect(String(b[0]) == "worn" and b[1] == [0, 0, 1], "Reinforce on the bot: its mended wall takes two shots free (%s)" % [b[1]])
	_wear(bot, "")


# ---------------------------------------------------------------- the Sulphur set
## `body` wears `ids` together as an earth caster.
func _wear_all(body: Node, ids: Array) -> void:
	BendLoadout.clear(body)
	var ov := BendLoadout.wear(body, ids, "", "earth")
	if (ov.ids as Array).size() != ids.size():
		_expect(false, "%s worn (refused: %s)" % [ids, str(ov.refused)])


## Every gas cloud gone (between the checks).
func _no_gas() -> void:
	for z in BendGas.gas_of():
		(z as BendZone).end("test")
	await _ticks(2)


## `n`'s % gained over `s` seconds, and whether he was launched meanwhile (tag `tag`, any when "").
func _pct_over(n: Node3D, s: float, tag := "") -> Array:
	var p0 := rules.pct_of(n)
	var got := [false]
	var cb := func(b: Node3D, _v: Vector3, _st: float, _by: Node, t: String) -> void:
		if b == n and (tag == "" or t == tag):
			got[0] = true
	rules.launched.connect(cb)
	await _secs(s)
	rules.launched.disconnect(cb)
	return [rules.pct_of(n) - p0, got[0]]


## A bolt of `kind` `by` sends across point `at` from `from_m` m to its side (it passes through `at`).
func _bolt_across(by: Node3D, kind: String, at: Vector3, side: Vector3, from_m := 4.0) -> BendBolt:
	var from := at + side.normalized() * from_m + Vector3.UP * 1.0
	return BendBolt.launch(by, from, (at + Vector3.UP * 1.0 - from).normalized(), {"kind": kind, "mps": 25.0, "damage": 4.0,
			"knock_mps": 0.0, "up_mps": 0.0, "radius_m": 0.15, "range_m": from_m * 2.0})


func _sulphur_set() -> void:
	var id := BendGas.SET
	_expect(BendLoadout.why_not(id) == "" and id in BendLoadout.behaviour(), "the Sulphur set is live, its code built (%s)" % BendLoadout.why_not(id))
	await _stage(-4.5, 4.5)
	await _no_gas()
	_wear_all(player, [id])
	var pc_cls := BendLoadout.hit_class(player, RingRules.class_of("rock_jab/pebbles"))
	_expect(_near(float(pc_cls.d), 4.0, 0.001) and _near(float(BendLoadout.hit_class(bot, RingRules.class_of("rock_jab/pebbles")).d), 5.0, 0.001),
			"Sulphur: his Pebbles add 4% (the bot's 5)")
	# his Boulder's end: a cloud where it lands
	var deck := _deck_off(5.0, 60.0)
	var clouds := {}
	for wid: Array in [[], [id]]:
		_wear_all(player, wid)
		await _no_gas()
		await _boulder_at(deck)
		await _secs(1.4)
		clouds[wid.size()] = BendGas.gas_of(player).duplicate()
	var c0: Array = clouds[0]
	var c1: Array = clouds[1]
	var z1: BendZone = c1[0] if c1.size() == 1 else null
	_expect(c0.is_empty(), "Classic: the Boulder leaves no gas")
	_expect(z1 != null and _near(z1.radius, 2.5, 0.01) and _near(z1.life_s, 3.0, 0.01) and Vector2(z1.global_position.x - deck.x, z1.global_position.z - deck.z).length() < 2.0,
			"Sulphur: his Boulder leaves a 2.5 m cloud for 3 s where it lands (%s)" % [str([z1.radius, z1.life_s]) if z1 != null else str(c1.size())])
	await _no_gas()
	# the ticks: on the bot 1% x the pace each 0.5 s, 6 at most, no knock, no slow; his own never hurts him
	await _stage(-4.5, 1.5)
	BendGas.make(player, bot.global_position, "cloud")
	BendGas.make(player, player.global_position, "cloud")
	var pb: Array = await _pct_over(bot, 4.0)
	var pp0 := rules.pct_of(player)
	_expect(_near(float(pb[0]), 6.0 * RingRules.stock_num("pct_scale", 1.0), 0.02) and not bool(pb[1]) and BendStatus.until(bot, &"bend_slow") <= 0.0,
			"Sulphur: his cloud on the bot adds %.2f%% over its life (6 ticks of 1%% x the pace), no knock, no slow" % pb[0])
	_expect(_near(rules.pct_of(player), pp0, 0.001), "Sulphur: his own gas never hurts him")
	await _no_gas()
	BendGas.make(player, bot.global_position, "cloud")
	BendGas.make(player, bot.global_position + Vector3(0.5, 0.0, 0.0), "cloud")
	var p2: Array = await _pct_over(bot, 1.6)
	_expect(float(p2[0]) <= 4.0 * RingRules.stock_num("pct_scale", 1.0) + 0.01, "Sulphur: in two clouds the bot still takes one tick each 0.5 s (%.2f%% in 1.6 s)" % p2[0])
	await _no_gas()
	# a clash: his stone and the bot's meet, a cloud rises there
	await _stage(-4.5, 1.5)
	var mid := (player.global_position + bot.global_position) * 0.5
	var way := (bot.global_position - player.global_position).normalized()
	BendBolt.launch(player, mid - way * 2.0 + Vector3.UP * 1.2, way, STONE)
	BendBolt.launch(bot, mid + way * 2.0 + Vector3.UP * 1.2, -way, STONE)
	await _secs(0.5)
	_expect(BendGas.gas_of(player).size() == 1 and BendGas.gas_of(bot).is_empty(), "Sulphur: his stone clashing with the bot's raises his cloud there (%d)" % BendGas.gas_of(player).size())
	await _no_gas()
	# the reactions: fire lights it (the burst, the lighter's), water washes it, wind carries it on (the mover's)
	await _stage(-4.5, 4.5)
	var side := way.cross(Vector3.UP)
	var zc := BendGas.make(player, player.global_position + side * 1.0, "cloud")
	_bolt_across(bot, "fire", zc.global_position, way)
	var ig: Array = await _pct_over(player, 0.6, BendGas.IGNITE_TAG)
	_expect(not is_instance_valid(zc) and bool(ig[1]) and _near(float(ig[0]), 6.0 * RingRules.stock_num("pct_scale", 1.0), 0.05),
			"Sulphur: a fire bolt through his cloud lights it: the burst launches him (%.2f%%, the bot's), the cloud gone" % ig[0])
	await _stage(-4.5, 4.5)
	var zw := BendGas.make(player, player.global_position + side * 3.0, "cloud")
	_bolt_across(bot, "water", zw.global_position, way)
	await _secs(0.6)
	_expect(not is_instance_valid(zw), "Sulphur: a water bolt through it washes it away")
	var za := BendGas.make(player, player.global_position + side * 3.0, "cloud")
	var at0 := za.global_position
	_bolt_across(bot, "air", za.global_position, way)
	await _secs(0.8)
	_expect(is_instance_valid(za) and za.owner_node == bot and _near(at0.distance_to(za.global_position), BendGas.CARRY_M, 0.4),
			"Sulphur: wind through it carries it %.1f m on, the mover's now" % (at0.distance_to(za.global_position) if is_instance_valid(za) else -1.0))
	await _no_gas()
	# the bot steps out of his gas
	await _stage(-4.5, 4.5)
	BendGas.make(player, bot.global_position, "cloud")
	var zb: BendZone = BendGas.gas_of(player)[0]
	bot.held = false
	var out := false
	for i in 30:
		await _secs(0.1)
		if not zb.inside(bot.global_position):
			out = true
			break
	bot.held = true
	_expect(out, "Sulphur: the bot steps out of his gas")
	await _no_gas()
	_wear(player, "")
	# the bot wearing the set: its Boulder leaves its own cloud
	_wear_all(bot, [id])
	await _stage(2.0, 9.0)
	player.set_meta(&"bend_under_until", BendStatus.now() + 3.0)
	BendCast.cast(BendCaster.of(bot), "stone_form", "cannonball", player, player.global_position)
	await _secs(2.0)
	player.remove_meta(&"bend_under_until")
	_expect(BendGas.gas_of(bot).size() >= 1, "Sulphur on the bot: its Boulder leaves its own cloud (%d)" % BendGas.gas_of(bot).size())
	_wear(bot, "")
	await _no_gas()


# ---------------------------------------------------------------- the Sulphur twists
## `by`'s gas zones of kind `kind` ("cloud", "puff", "plume").
func _gas_kind(by: Node3D, kind: String) -> Array:
	return BendGas.gas_of(by).filter(func(z: Variant) -> bool: return String((z as Node).get_meta(&"gas_kind", "")) == kind)


## The bot's real lock of the Fissure (its own begin, its fill each frame), timed from begin to release (s).
func _bot_lock_time() -> float:
	var nb: NpcBending = bot.brain.bending
	bot.held = false
	var t0 := BendStatus.now()
	nb.begin("earth_shove", "push")
	var t1 := -1.0
	for i in 400:
		await _ticks(1)
		if nb.casting == "":
			t1 = BendStatus.now()
			break
	bot.held = true
	return t1 - t0


func _sulphur_twists() -> void:
	var S := BendGas.SET
	for tw: String in [BendGas.SPIKE, BendGas.BOULDER, BendGas.COLUMN, BendGas.WALL, BendGas.FLINT, BendGas.HEART]:
		_expect(BendLoadout.why_not(tw) == "" and tw in BendLoadout.behaviour(), "%s is live with the set, its code built (%s)" % [tw, BendLoadout.why_not(tw)])
	# Sulphur Spike: a puff where it stops, 12%
	await _stage(-4.5, 1.5)
	var spk := {}
	for wid: Array in [[S], [S, BendGas.SPIKE]]:
		_wear_all(player, wid)
		await _no_gas()
		await _aim_at(NpcSenses.chest_of(bot))
		sc.set_mode("stone_form", "spike")
		FormEffects.apply(sc, "stone_form", null, bot.global_position)
		await _secs(1.2)
		var pf := _gas_kind(player, "puff")
		spk[wid.size()] = [pf.size(), (pf[0] as BendZone) if pf.size() == 1 else null, BendLoadout.hit_class(player, RingRules.class_of("stone_form/spike")).d]
		await _stage(-4.5, 1.5)
	var sz: BendZone = spk[2][1]
	_expect(int(spk[1][0]) == 0 and _near(float(spk[1][2]), 14.0, 0.001), "the set alone: his Spike leaves no gas, 14%")
	_expect(sz != null and _near(sz.radius, 1.5, 0.01) and _near(sz.life_s, 2.5, 0.01) and _near(float(spk[2][2]), 12.0, 0.001),
			"Sulphur Spike: where it stops a 1.5 m puff for 2.5 s; it adds 12%% (%s)" % [str([sz.radius, sz.life_s]) if sz != null else str(spk[2][0])])
	await _no_gas()
	# Sulphur Boulder: three puffs along its flight, 13%
	await _stage(-4.5, 4.5)
	_wear_all(player, [S, BendGas.BOULDER])
	var deck := _deck_off(5.0, 60.0)
	await _boulder_at(deck)
	await _secs(1.4)
	var bp := _gas_kind(player, "puff")
	var bc := _gas_kind(player, "cloud")
	var behind := bc.size() == 1
	for z: Variant in bp:
		behind = behind and (z as Node3D).global_position.distance_to(player.global_position) < (bc[0] as Node3D).global_position.distance_to(player.global_position)
	_expect(bp.size() == 3 and behind and _near(float(BendLoadout.hit_class(player, RingRules.class_of("stone_form/cannonball")).d), 13.0, 0.001),
			"Sulphur Boulder: three puffs along its flight before its landing cloud; it adds 13%% (%d puffs, %d cloud)" % [bp.size(), bc.size()])
	await _no_gas()
	# Fuming Column: a 2 m plume where it rose, base 9.3
	await _stage(-3.0, 3.0)
	var fum := {}
	for wid: Array in [[S], [S, BendGas.COLUMN]]:
		_wear_all(player, wid)
		await _no_gas()
		await _aim_at(bot.global_position + Vector3.UP * 0.05)
		BendEffects.apply(pc, "earth_shove", "column", SwayMoves.move("earth_shove").bend.column)
		await _secs(0.3)
		var pl := _gas_kind(player, "plume")
		fum[wid.size()] = (pl[0] as BendZone) if pl.size() == 1 else null
		await _secs(1.0)
		await _stage(-3.0, 3.0)
	var fz: BendZone = fum[2]
	_expect(fum[1] == null, "the set alone: his Column leaves no plume")
	_expect(fz != null and _near(fz.radius, 2.0, 0.01) and _near(fz.life_s, 3.0, 0.01)
			and _near(float(BendLoadout.hit_class(player, RingRules.class_of("earth_shove/column")).base), 9.3, 0.001),
			"Fuming Column: a 2 m plume for 3 s where it rose; it launches with base 9.3")
	await _no_gas()
	# Brimstone Wall: 3 hits; shot down, a cloud 1 m out on the shooter's side
	await _stage(-4.5, 4.5)
	var brim := {}
	for wid: Array in [[S], [S, BendGas.WALL]]:
		_wear_all(player, wid)
		await _no_gas()
		var r := await _wall_of(player, 3.0)
		var at := r.global_position
		var face := r.global_basis.z
		var shots := await _shoot_down(r, bot)
		await _secs(0.3)
		var cl := _gas_kind(player, "cloud")
		var toward := (bot.global_position - at)
		toward.y = 0.0
		var off := ((cl[0] as Node3D).global_position - at).dot(face.normalized() * signf(toward.dot(face))) if cl.size() == 1 else -1.0
		brim[wid.size()] = [shots, cl.size(), off]
		await _secs(1.4)
	_expect(int(brim[1][0]) == 4 and int(brim[1][1]) == 0, "the set alone: his wall takes 4 shots and leaves no gas")
	_expect(int(brim[2][0]) == 3 and int(brim[2][1]) == 1 and float(brim[2][2]) > 1.0 and float(brim[2][2]) < 1.8,
			"Brimstone Wall: shot down by the 3rd, a cloud %.2f m out on the shooter's side" % brim[2][2])
	await _no_gas()
	# Flint Pebbles: his pebbles light his own gas (his burst); the bot's gas they leave alone; his clouds last 2.5 s
	await _stage(-4.5, 1.5)
	_wear_all(player, [S])
	var life_set := BendGas.make(player, player.global_position + Vector3(0, 0, 4), "cloud").life_s
	_wear_all(player, [S, BendGas.FLINT])
	var life_fl := BendGas.make(player, player.global_position + Vector3(0, 0, 4), "cloud").life_s
	_expect(_near(life_set, 3.0) and _near(life_fl, 2.5), "Flint Pebbles: his clouds last %.1f s (the set's %.1f)" % [life_fl, life_set])
	await _no_gas()
	var zf := BendGas.make(player, bot.global_position, "cloud")
	await _aim_at(NpcSenses.chest_of(bot))
	BendEffects.apply(pc, "rock_jab", "pebbles", SwayMoves.move("rock_jab").bend.pebbles)
	var fl: Array = await _pct_over(bot, 0.8, BendGas.IGNITE_TAG)
	_expect(not is_instance_valid(zf) and bool(fl[1]), "Flint Pebbles: his pebbles light his own cloud on the bot: his burst launches it")
	await _stage(-4.5, 1.5)
	_wear_all(bot, [S])
	var zb := BendGas.make(bot, bot.global_position, "cloud")
	await _aim_at(NpcSenses.chest_of(bot))
	BendEffects.apply(pc, "rock_jab", "pebbles", SwayMoves.move("rock_jab").bend.pebbles)
	var fb: Array = await _pct_over(bot, 0.8, BendGas.IGNITE_TAG)
	_expect(is_instance_valid(zb) and not bool(fb[1]), "Flint Pebbles: the bot's gas his pebbles leave alone")
	_wear_all(player, [S])
	var zs := BendGas.make(player, bot.global_position + Vector3(0, 0, 0.1), "cloud")
	await _aim_at(NpcSenses.chest_of(bot))
	BendEffects.apply(pc, "rock_jab", "pebbles", SwayMoves.move("rock_jab").bend.pebbles)
	await _secs(0.6)
	_expect(is_instance_valid(zs), "the set alone: his pebbles do not light his gas")
	_wear(bot, "")
	await _no_gas()
	# Sulphur Heart: his clouds 2 m; his locks fill x1.15 in his own gas (the higher with Rooted); the bot's too
	await _stage(-4.5, 4.5)
	_wear_all(player, [S, BendGas.HEART])
	var hz := BendGas.make(player, player.global_position, "cloud")
	var hr := hz.radius
	player.velocity = Vector3(2.0, 0.0, 0.0)
	var in_moving := sc.passive_fill()
	player.velocity = Vector3.ZERO
	var in_still := sc.passive_fill()
	hz.end("test")
	await _ticks(2)
	player.velocity = Vector3(2.0, 0.0, 0.0)
	var out_moving := sc.passive_fill()
	player.velocity = Vector3.ZERO
	_expect(_near(hr, 2.0, 0.01), "Sulphur Heart: his clouds are 2 m (%.1f)" % hr)
	_expect(_near(in_moving, 1.15, 0.001) and _near(in_still, 1.2, 0.001) and _near(out_moving, 1.0, 0.001),
			"Sulphur Heart: in his own gas his locks fill x%.2f (standing still Rooted's x%.2f, the higher; out of it x%.2f)" % [in_moving, in_still, out_moving])
	_wear(player, "")
	_wear_all(bot, [S, BendGas.HEART])
	await _stage(-4.5, 4.5)
	var t_out := await _bot_lock_time()
	await _secs(0.6)
	BendGas.make(bot, bot.global_position, "cloud")
	var t_in := await _bot_lock_time()
	_expect(t_out > 0.0 and t_in > 0.0 and _near(t_out / t_in, 1.15, 0.06), "Sulphur Heart on the bot: its lock fills x%.2f in its own gas (%.2f s, out %.2f s)" % [t_out / maxf(t_in, 0.01), t_in, t_out])
	_wear(bot, "")
	await _no_gas()


## A body made to wear `id` (a stand-in for the checks of what a wearer's overlay says).
func _worn_body(id: String) -> Node3D:
	var n := Node3D.new()
	root.add_child(n)
	n.queue_free()
	if id != "":
		BendLoadout.wear(n, [id], "", "earth")
	return n


# ---------------------------------------------------------------- Sulphur Vent (pass 2)
## The player's key 4 tapped twice on the hotbar (its own taps, two frames apart): Earth Wall's mode after ("readied ..." when
## another move is readied, "no hotbar").
func _tap4_twice() -> String:
	var hb := Hotbar.find(player)
	if hb == null:
		return "no hotbar"
	hb._key_tap(3)
	await _ticks(2)
	hb._key_tap(3)
	await _ticks(2)
	return sc.base_mode_of("earth_wall") if sc.readied_spell == "earth_wall" else "readied " + sc.readied_spell


## The player's readied Earth Wall at its mode now, cast through his own lock (RMB held: held_override) with his crosshair on
## deck point `p`, let go 0.05 s after it fills: [the lock's time (s; -1 it never filled), his vents after, the place his
## crosshair gave as he let go (FormEffects.place_point: 2-6 m)].
func _vent_cast(p: Vector3) -> Array:
	await _aim_at(p + Vector3.UP * 0.05)
	sc.held_override = true
	var ls := -1.0
	for i in 600:
		await _ticks(1)
		if sc.state == SwayCaster.State.FULL:
			ls = sc.lock_s
			break
	await _secs(0.05)
	var at := FormEffects.place_point(pc, {"min_m": 2.0, "max_m": 6.0})
	sc.held_override = false
	await _ticks(2)
	sc.held_override = null
	await _secs(0.3)
	return [ls, _gas_kind(player, "vent"), at]


## Flat metres between `a` and `b`.
func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _vent() -> void:
	var S := BendGas.SET
	var V := BendGas.VENT
	var key4: Array = Bending.keys("earth")[3]
	var scale := RingRules.stock_num("pct_scale", 1.0)
	_expect(BendLoadout.why_not(V) == "" and V in BendLoadout.behaviour(), "Sulphur Vent is live with the set, its code built (%s)" % BendLoadout.why_not(V))
	await _stage(-4.5, 4.5)
	await _no_gas()
	# not worn (Classic, the set alone): 4 has one move; a double tap readies the wall again; no vent mode to set
	for wid: Array in [[], [S]]:
		_wear_all(player, wid)
		var md := await _tap4_twice()
		_expect(sc.my_modes("earth_wall") == ["wall"] and Bending.other_move(key4, "earth_wall", "wall", player).is_empty() and md == "wall"
				and not sc.set_mode("earth_wall", "vent") and BendLoadout.talent_spec(player, "earth_wall", "vent").is_empty(),
				"%s: 4 has one move, tapped twice the wall again, no vent (%s, %s)" % ["the set alone" if wid.size() == 1 else "Classic", sc.my_modes("earth_wall"), md])
	var w0 := await _wall_of(player, 3.0)
	var rise0 := w0.rise_s if w0 != null else -1.0
	if w0 != null:
		w0.crumble("time")
	await _secs(1.6)
	# worn: 4 tapped twice readies it, named, the wall's pose, its own lock
	_wear_all(player, [S, V])
	var other := Bending.other_move(key4, "earth_wall", "wall", player)
	var tapped := await _tap4_twice()
	_expect(String(other.get("mode", "")) == "vent" and tapped == "vent" and sc.my_modes("earth_wall") == ["wall", "vent"],
			"Sulphur Vent: 4 tapped twice readies it (the hotbar's own taps: %s)" % tapped)
	_expect(SwayCaster.mode_label("earth_wall", "vent") == "Sulphur Vent" and sc.spell_label("earth_wall").contains("Sulphur Vent"),
			"Sulphur Vent: named on the bar (%s)" % sc.spell_label("earth_wall"))
	var pv := BendPoses.pick("earth_wall", "vent", "earth", player)
	_expect(not pv.is_empty() and pv == BendPoses.pick("earth_wall", "wall", "earth", player), "Sulphur Vent: cast with the Earth Wall's own pose (%s)" % pv.get("clip", "-"))
	var lv := sc._lock_time("earth_wall", null, 0.0, 0.0)
	sc.set_mode("earth_wall", "wall")
	var lw := sc._lock_time("earth_wall", null, 0.0, 0.0)
	_expect(_near(lv / lw, 0.9 / 1.6, 0.002), "Sulphur Vent: its lock 0.9 s against the wall's 1.6 (%.3f, %.3f)" % [lv, lw])
	# cast through his own lock: a 3 m cloud for 4 s where he aims, 2-6 m off (on the deck's long axis: a place near a side is
	# kept wall_lip_clear_m inside its lip, as a wall's is)
	await _tap4_twice()
	var aim1 := _deck_off(4.0, 0.0)
	var r1: Array = await _vent_cast(aim1)
	var v1: BendZone = (r1[1] as Array)[0] if (r1[1] as Array).size() == 1 else null
	var d1 := _flat(v1.global_position, r1[2]) if v1 != null else -1.0
	var a1 := _flat(v1.global_position, aim1) if v1 != null else -1.0
	_expect(v1 != null and _near(v1.radius, 3.0, 0.01) and _near(v1.life_s, 4.0, 0.01) and d1 < 0.2 and a1 < 1.5 and _near(float(r1[0]), lv, 0.02),
			"Sulphur Vent: cast through his own lock (%.2f s), a 3 m cloud for 4 s where his crosshair is as he lets go (%.2f m; %.2f m from the point aimed at)" % [r1[0], d1, a1])
	# one at a time: a second vent ends the first; his other gas stays; aimed 10 m off it opens 6 m off
	var cloud := BendGas.make(player, _deck_off(5.0, -70.0), "cloud")
	sc.set_mode("earth_wall", "vent")
	var r2: Array = await _vent_cast(_deck_off(10.0, -25.0))
	var v2: BendZone = (r2[1] as Array)[0] if (r2[1] as Array).size() == 1 else null
	_expect(v2 != null and v2 != v1 and (v1 == null or not is_instance_valid(v1) or v1.is_queued_for_deletion()) and is_instance_valid(cloud),
			"Sulphur Vent: one at a time (a new one ends the old, %d standing); his other cloud stays" % (r2[1] as Array).size())
	var d2 := _flat(v2.global_position, player.global_position) if v2 != null else -1.0
	_expect(_near(d2, 6.0, 0.35), "Sulphur Vent: aimed 10 m off it opens 6 m off at the farthest (%.2f)" % d2)
	await _no_gas()
	# nearest 2 m: the cloud over him; his own gas never hurts him
	rules.reset_pct(player, 0.0)
	sc.set_mode("earth_wall", "vent")
	var r3: Array = await _vent_cast(_deck_off(1.0, 0.0))
	var v3: BendZone = (r3[1] as Array)[0] if (r3[1] as Array).size() == 1 else null
	var p_self: Array = await _pct_over(player, 2.0)
	var d3 := _flat(v3.global_position, player.global_position) if v3 != null else -1.0
	_expect(v3 != null and _near(d3, 2.0, 0.35) and v3.inside(player.global_position) and _near(float(p_self[0]), 0.0, 0.001),
			"Sulphur Vent: aimed 1 m off it opens 2 m off at the nearest, over him, and never hurts him (%.2f m, %.2f%%)" % [d3, p_self[0]])
	await _no_gas()
	# on the bot: 1% x the pace each 0.5 s, 6% at most (its 4 s would give 8), no knock, no slow
	await _stage(-2.0, 2.0)
	rules.reset_pct(bot, 0.0)
	var launched := [false]
	var cb := func(b: Node3D, _v: Vector3, _st: float, _by: Node, _t: String) -> void:
		if b == bot:
			launched[0] = true
	rules.launched.connect(cb)
	sc.set_mode("earth_wall", "vent")
	var r4: Array = await _vent_cast(bot.global_position)
	await _secs(4.4)
	rules.launched.disconnect(cb)
	_expect((r4[1] as Array).size() == 1 and _near(rules.pct_of(bot), 6.0 * scale, 0.02) and not bool(launched[0]) and BendStatus.until(bot, &"bend_slow") <= 0.0,
			"Sulphur Vent: on the bot %.2f%% over its life (6 x the pace at most), no knock, no slow" % rules.pct_of(bot))
	await _no_gas()
	# fire lights it (it is the set's gas): the burst launches the bot in it
	await _stage(-2.0, 2.0)
	sc.set_mode("earth_wall", "vent")
	var r5: Array = await _vent_cast(bot.global_position)
	var v5: BendZone = (r5[1] as Array)[0] if (r5[1] as Array).size() == 1 else null
	var way := bot.global_position - player.global_position
	way.y = 0.0
	if v5 != null:
		# (across the cloud 1.5 m short of the bot: through the gas, never into him)
		_bolt_across(player, "fire", v5.global_position - way.normalized() * 1.5, way.normalized().cross(Vector3.UP))
	var ig: Array = await _pct_over(bot, 0.6, BendGas.IGNITE_TAG)
	_expect((r5[1] as Array).size() == 1 and not is_instance_valid(v5) and bool(ig[1]), "Sulphur Vent: fire through it lights it, the burst launches the bot")
	await _no_gas()
	# his Earth Wall rises in 0.8 s (Classic 0.7)
	await _stage(-4.5, 4.5)
	var w1 := await _wall_of(player, 3.0)
	var rise1 := w1.rise_s if w1 != null else -1.0
	_expect(_near(rise1, 0.8) and _near(rise0, 0.7), "Sulphur Vent: his Earth Wall rises in %.1f s (Classic %.1f)" % [rise1, rise0])
	if w1 != null:
		w1.crumble("time")
	await _secs(1.6)
	sc.set_mode("earth_wall", "wall")
	_wear(player, "")
	_expect(sc.my_modes("earth_wall") == ["wall"] and sc.base_mode_of("earth_wall") == "wall", "Sulphur Vent taken off: 4 has its one move again")
	rules.reset_pct(bot, 0.0)
	await _vent_bot()


## The bot and the Vent: a bot wearing nothing has none; one wearing it has it as an option, locks it 0.9 s, places it on the
## player in a real fight, and its gate keeps it from venting where its gas already stands on him.
func _vent_bot() -> void:
	var S := BendGas.SET
	var V := BendGas.VENT
	var nb: NpcBending = bot.brain.bending
	_wear(bot, "")
	nb._talent_options()
	var none := nb._option("earth_wall/vent").is_empty()
	_wear_all(bot, [S, V])
	nb._talent_options()
	var o := nb._option("earth_wall/vent")
	_expect(none and not o.is_empty() and String((o.get("hint", {}) as Dictionary).get("role", "")) == "control" and String(o.get("do", "")) == "zone"
			and not bool(o.get("old", true)),
			"Sulphur Vent on the bot: worn, it is one of its options (control, a zone); a bot wearing nothing has none")
	var bl := NpcBending.lock_for("earth_wall", "vent", "normal", 0.0, bot) / NpcBending.lock_for("earth_wall", "wall", "normal", 0.0, bot)
	_expect(_near(bl, 0.9 / 1.6, 0.002), "Sulphur Vent on the bot: its lock 0.9 s against its wall's 1.6 (x%.3f)" % bl)
	# its gate: not while its gas stands on him
	await _stage(-3.0, 3.0)
	var free_ok := nb._when("foe_not_gassed", player, 6.0)
	var g := BendGas.make(bot, player.global_position, "cloud")
	var gassed_ok := nb._when("foe_not_gassed", player, 6.0)
	if g != null:
		g.end("test")
	await _no_gas()
	_expect(free_ok and not gassed_ok, "Sulphur Vent on the bot: not while its gas already stands on him")
	# a real fight: let go, it vents him (the player stands still, his % kept low)
	await _stage(-3.5, 3.5)
	var n0 := int(nb.casts_by.get("earth_wall/vent", 0))
	var on_him := -1.0
	bot.held = false
	for i in 200:
		await _secs(0.1)
		if i % 10 == 0:
			rules.reset_pct(player, 0.0)
		var vs := _gas_kind(bot, "vent")
		if not vs.is_empty():
			on_him = _flat((vs[0] as Node3D).global_position, player.global_position)
			break
	bot.held = true
	await _secs(0.3)
	var nv := int(nb.casts_by.get("earth_wall/vent", 0)) - n0
	_expect(nv >= 1 and on_him >= 0.0 and on_him <= 3.0, "Sulphur Vent on the bot: in a fight it places its vent on the player (%.1f m from him, %d cast)" % [on_him, nv])
	_wear(bot, "")
	nb._talent_options()
	_expect(nb._option("earth_wall/vent").is_empty(), "Sulphur Vent off the bot: its options are its kit's again")
	await _no_gas()
	rules.reset_pct(player, 0.0)
	rules.reset_pct(bot, 0.0)


# ---------------------------------------------------------------- the Sulphur set's reactions (pass 2)
## The player's cast of `m` at `md` through BendEffects (the cast's own path), his crosshair on `p`.
func _cast_at(m: String, md: String, p: Vector3) -> void:
	await _aim_at(p)
	BendEffects.apply(pc, m, md, (SwayMoves.move(m).bend as Dictionary)[md])


func _reactions() -> void:
	var S := BendGas.SET
	var scale := RingRules.stock_num("pct_scale", 1.0)
	_wear_all(player, [S])
	_wear_all(bot, [S])
	# the burst reaches 1.5x the cloud's round: the bot 3.2 m from a 2.5 m cloud's middle is launched; IGNITED! called out
	await _stage(-4.5, 4.5)
	await _no_gas()
	var way := bot.global_position - player.global_position
	way.y = 0.0
	way = way.normalized()
	var side := way.cross(Vector3.UP)
	var zc := BendGas.make(bot, bot.global_position - way * 3.2, "cloud")
	var n_said := Callouts.shown.count("IGNITED!")
	_bolt_across(player, "fire", zc.global_position, side)
	var ig: Array = await _pct_over(bot, 0.6, BendGas.IGNITE_TAG)
	_expect(not is_instance_valid(zc) and bool(ig[1]), "Ignited Sulphur: the burst reaches 1.5x the cloud's round (the bot 3.2 m from a 2.5 m cloud's middle launched)")
	_expect(Callouts.shown.count("IGNITED!") == n_said + 1, "Ignited Sulphur: IGNITED! called out at the callouts' own spot (%d)" % (Callouts.shown.count("IGNITED!") - n_said))
	# cones: Breath lights it, the Wave washes it, the air Palm carries it on away from him
	await _stage(-4.5, 4.5)
	await _no_gas()
	var zb := BendGas.make(bot, player.global_position + way * 2.5, "cloud")
	rules.reset_pct(bot, 0.0)
	await _cast_at("fire_breath", "breath", zb.global_position + Vector3.UP * 0.8)
	await _ticks(3)
	_expect(not is_instance_valid(zb), "the set's gas: his Breath (a cone) lights the bot's cloud before him")
	await _stage(-4.5, 4.5)
	await _no_gas()
	var zw := BendGas.make(bot, player.global_position + way * 4.0, "cloud")
	await _cast_at("wave", "push", zw.global_position + Vector3.UP * 0.8)
	await _ticks(3)
	_expect(not is_instance_valid(zw), "the set's gas: his Wave (a cone) washes it away")
	var za := BendGas.make(bot, player.global_position + way * 2.5, "cloud")
	var a0 := za.global_position
	await _cast_at("air_palm", "palm", za.global_position + Vector3.UP * 0.8)
	await _secs(0.7)
	var moved := (za.global_position - a0).dot(way) if is_instance_valid(za) else -1.0
	_expect(is_instance_valid(za) and _near(moved, BendGas.CARRY_M, 0.5) and za.owner_node == player,
			"the set's gas: his air Palm (a cone) carries it %.1f m on away from him (4), his now" % moved)
	await _no_gas()
	# a Fire Wall raised on a cloud lights it (the wall's owner the lighter); a Wind Wall standing on one carries it off its face
	await _stage(-4.5, 4.5)
	rules.reset_pct(player, 0.0)
	var zf := BendGas.make(player, player.global_position + way * 1.0, "cloud")
	var fw := BendZone.make(bot, "fire_wall", zf.global_position + side * 1.0, {"width_m": 3.0, "height_m": 2.0, "thick_m": 0.6, "life_s": 2.0}, way)
	var fl: Array = await _pct_over(player, 0.8, BendGas.IGNITE_TAG)
	_expect(not is_instance_valid(zf) and bool(fl[1]), "the set's gas: a Fire Wall raised on his cloud lights it, the burst the wall's owner's (it launches him)")
	if is_instance_valid(fw):
		fw.end("test")
	await _stage(-4.5, 4.5)
	await _no_gas()
	var zn := BendGas.make(player, player.global_position + way * 3.0, "cloud")
	var n0 := zn.global_position
	var ww := BendZone.make(bot, "wind_wall", zn.global_position - way * 1.0, {"width_m": 3.0, "height_m": 2.5, "thick_m": 0.6, "life_s": 2.0}, -way)
	await _secs(1.0)
	var blown := _flat(zn.global_position, n0) if is_instance_valid(zn) else -1.0
	_expect(is_instance_valid(zn) and _near(blown, BendGas.CARRY_M, 0.5) and zn.owner_node == bot,
			"the set's gas: a Wind Wall standing on his cloud carries it %.1f m off its face, once, the wall's owner's now" % blown)
	if is_instance_valid(ww):
		ww.end("test")
	await _no_gas()
	# Live Gas: his lightning through the bot's own cloud (past the bot, 2 m to its side) charges it: the bot inside takes
	# half the strike's % and is not launched; the gas stays
	await _stage(-4.5, 4.5)
	rules.reset_pct(bot, 0.0)
	var zl := BendGas.make(bot, bot.global_position, "cloud")          # (the bot's own: its ticks never touch it)
	var d_strike := float(RingRules.class_of("fire_arc/lightning").get("d", 0.0))
	await _cast_at("fire_arc", "lightning", FormEffects.ground_at(bot, bot.global_position + side * 2.0))
	var lv: Array = await _pct_over(bot, 0.8)
	var lp := rules.pct_of(bot)
	_expect(is_instance_valid(zl) and int(zl.get_meta(&"gas_live", 0)) == 1 and not bool(lv[1]) and d_strike > 0.0
			and _near(lp, d_strike * BendGas.LIVE_K * scale, 0.05),
			"Live Gas: lightning through the cloud charges it: the bot inside takes %.2f%% (half the strike's %.1f x the pace), no launch, the gas stays" % [lp, d_strike])
	# Classic: none of it (no gas is ever made: a wall, a cone and a strike change nothing)
	_wear(player, "")
	_wear(bot, "")
	await _no_gas()
	_expect(BendGas.make(player, bot.global_position, "cloud") == null and BendGas.gas_of().is_empty(), "Classic: no gas, nothing for a reaction to touch")
	rules.reset_pct(player, 0.0)
	rules.reset_pct(bot, 0.0)
	await _seams()


## Magma seams (the fire lane's Magma set: a BendZone of kind "seam", low on the deck; wired here by its kind alone, a stand-in
## seam made as its maker makes one): a stone of a Kiln Stone wearer's skimming over one comes out heated (not worn: plain); a
## gas cloud over one is lit, the seam's owner the lighter.
func _seams() -> void:
	await _stage(-4.5, 4.5)
	var way := bot.global_position - player.global_position
	way.y = 0.0
	way = way.normalized()
	var seam_spec := {"radius_m": 1.05, "width_m": 1.5, "thick_m": 1.5, "height_m": 0.3, "life_s": 3.0}
	var heat := {}
	for wid: String in ["", BendZone.KILN_STONE]:
		_wear(player, wid)
		var sm := BendZone.make(bot, "seam", FormEffects.ground_at(player, player.global_position + way * 3.0), seam_spec, way)
		var from := FormEffects.ground_at(player, player.global_position + way * 1.0) + Vector3.UP * 0.25
		var b := BendBolt.launch(player, from, way, {"kind": "stone", "mps": 20.0, "damage": 5.0, "knock_mps": 0.0, "up_mps": 0.0,
				"radius_m": 0.12, "range_m": 5.0})
		var hot := false
		for i in 20:
			await _ticks(1)
			if is_instance_valid(b) and b.heated:
				hot = true
		heat[wid] = hot
		if is_instance_valid(sm):
			sm.end("test")
		await _secs(0.3)
	_expect(bool(heat[BendZone.KILN_STONE]) and not bool(heat[""]), "Kiln Stone: his stone skimming over a magma seam comes out heated (not worn: plain)")
	_wear(player, "")
	_wear_all(player, [BendGas.SET])
	await _no_gas()
	var zg := BendGas.make(player, player.global_position + way * 3.0, "cloud")
	var sm2 := BendZone.make(bot, "seam", zg.global_position + way.cross(Vector3.UP) * 1.5, seam_spec, way)
	var lit: Array = await _pct_over(player, 0.8, BendGas.IGNITE_TAG)
	_expect(not is_instance_valid(zg) and bool(lit[1]), "the set's gas: a magma seam under his cloud lights it (the seam's owner's burst launches him)")
	if is_instance_valid(sm2):
		sm2.end("test")
	_wear(player, "")
	await _no_gas()
	rules.reset_pct(player, 0.0)


# ---------------------------------------------------------------- earth's talents worn together (pass 2)
## `ids` worn together by the player as an earth caster: the overlay (its ids and refusals).
func _wear_ov(ids: Array) -> Dictionary:
	BendLoadout.clear(player)
	return BendLoadout.wear(player, ids, "", "earth")


func _combos() -> void:
	var S := BendGas.SET
	await _stage(-4.5, 4.5)
	# the tree's stacking: Rubble Wall and Quarry both slow the wall's rise the same way, their ratios multiply
	var ov := _wear_ov(["earth.wall.rubble", "earth.wall.quarry"])
	var w := await _wall_of(player, 3.0)
	var rise := w.rise_s if w != null else -1.0
	if w != null:
		w.crumble("time")
	await _secs(1.6)
	_expect((ov.ids as Array).size() == 2 and _near(rise, 0.7 * (0.8 / 0.7) * (0.8 / 0.7), 0.005),
			"Rubble Wall and Quarry worn together: both apply, the wall rises in %.3f s (0.7 x 0.8/0.7 x 0.8/0.7; %s)" % [rise, ov.refused])
	# a set twist's number is final: the Sulphur Vent's 0.8 s with Rubble Wall
	ov = _wear_ov([S, BendGas.VENT, "earth.wall.rubble"])
	var nw := BendLoadout.wall_numbers(player, "wall", SwayMoves.move("earth_wall").wall, "earth")
	_expect((ov.ids as Array).size() == 3 and _near(float(nw.rise_s), 0.8, 0.001),
			"the Sulphur Vent and Rubble Wall worn together: both apply, the Vent's rise (a set twist's) stands, %.2f s (%s)" % [float(nw.rise_s), ov.refused])
	# Clean Return and Return to Sender: a late catch's return lock, both the same way
	ov = _wear_ov(["earth.catch.clean_return", "earth.catch.return_to_sender"])
	var rl := float(BendLoadout.tune(player, "rules:guard_rules.return_lock_s", Bending.rule("return_lock_s", 0.35)))
	_expect((ov.ids as Array).size() == 2 and _near(rl, 0.35 * (0.42 / 0.35) * (0.4 / 0.35), 0.002),
			"Clean Return and Return to Sender worn together: both apply, the return lock %.3f s (0.35 x 0.42/0.35 x 0.4/0.35)" % rl)
	# the tree's excludes: Heave with Fuming Column, Thick Wall with Brimstone Wall, Heavy Boulder with Sulphur Boulder
	for pr: Array in [[[S, "earth.column.heave", BendGas.COLUMN], BendGas.COLUMN], [[S, "earth.wall.thick", BendGas.WALL], BendGas.WALL],
			[[S, "earth.boulder.heavy", BendGas.BOULDER], BendGas.BOULDER]]:
		ov = _wear_ov(pr[0])
		var why := String((ov.refused as Dictionary).get(pr[1], ""))
		_expect(not (ov.ids as Array).has(pr[1]) and (ov.ids as Array).size() == 2 and why.contains("exclude"),
				"the tree's excludes: %s is not worn beside %s (%s)" % [pr[1], (pr[0] as Array)[1], why])
	_wear(player, "")
