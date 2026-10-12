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
	await _thick_wall()
	await _juggle()
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
