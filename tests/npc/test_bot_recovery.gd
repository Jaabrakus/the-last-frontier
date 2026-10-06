extends SceneTree
## Round 3 BOTS (smash_r3 spec §9.6, §15): an element bot's own recovery in the % ring (NpcRingMind's planner), in the ring
## scene. Until MOVE's RingMoves and RingMoves.simulate merge, the body is moved by the stand-in mover (tests/npc/
## r3_standins.gd FakeMoves: NpcRingMind.standin_step, the spec's §4-§5 numbers) from the bot's own pad, in a closed loop:
## each frame NpcBending.tick (the mind fills the pad) then the mover steps from the pad's intent. The gate is on by a
## stand-in RingRules (FakeRules, rule_set "stock").
##   returns      each element x preset from 12 fixed off-deck spots (both ends x 2, 5 and 8 m out x feet 0.5 and 2.5 m under
##                the lip; every other one with its double jump spent), thrown outward at 3 m/s: back on the deck or on the
##                edge in hard 100%, normal >= 95%, easy >= 75% (bot_recover_success per element x preset)
##   its moves    across them it used the double jump, the Rise and (normal, hard) the air dodge; the plans it ran counted
##   no 4th grab  after three grabs without the deck its plans only land on the deck (the mover refuses a 4th: grabs_refused 0)
##   the deck     60 s of neutral at normal and hard against a still player: never off the deck by itself (self-falls 0)
## METRIC lines: bot_recover_success_<element>_<preset>, recover_spread (the elements' widest gap per preset), plans_by.
## With mover=real (after MOVE merges) the same spots are flown by RingMoves itself (RingMoves.install, the body's own physics).
## Watchdog LIMIT_S; last line "BOT RECOVERY PASSED" / "BOT RECOVERY FAILED".
##   Godot --headless --fixed-fps 60 --path . -s tests/npc/test_bot_recovery.gd [-- only=earth] [mover=real]

const NAME := "BOT RECOVERY"
const LIMIT_S := 400.0
const OWN_CFG := "user://test_bot_recovery.cfg"
const Standins := preload("res://tests/npc/r3_standins.gd")
const FACTION := "ring_team_b"
const WANT := {"hard": 1.0, "normal": 0.95, "easy": 0.75}
const TRIAL_S := 4.0

var checks := 0
var fails: Array[String] = []
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var rules: Standins.FakeRules
var only := ""
var real := false
var _seed := 6100


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	MatchSetup._aim_help = "strong"
	GameSettings.path = OWN_CFG
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
		elif a == "mover=real":
			real = true
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.kind = "practice"
	MatchSetup.dummy = "stand"
	MatchSetup.element = "water"
	MatchSetup.foes = ["earth"]
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	Standins.uninstall(rules)
	GameSettings.path = GameSettings.PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func at_s(e: int, s: float, z := 0.0) -> Vector3:
	return ring.to_global(Vector3(RingArena.side_sign(e) * s, ring.top() + 0.05, z))


func bot(el: String, preset: String, at: Vector3) -> NpcFighter:
	_seed += 1
	var sq := NpcSquad.spawn(current_scene, FACTION, 1, at, {"element": el, "tactics": "bend", "weapon": "", "sidearm": "",
			"skill": preset, "seed": _seed, "y": ring.deck_y(), "face": player.global_position})
	var f: NpcFighter = sq.members[0] if not sq.members.is_empty() else null
	if f == null:
		return null
	f.no_death = true
	f.flees = false
	f.calm_s = INF
	var b := f.brain.bending
	b.bounds_fn = mode.rules.bounds_fn_for(f)
	b.edge_fn = mode.rules.edge_along
	b._grace_until = 0.0
	f.brain.told(player, player.global_position)
	f.brain.target = player
	f.set_physics_process(false)
	return f


func free_bot(f: NpcFighter) -> void:
	if f != null and is_instance_valid(f):
		var sq: Node = f.squad
		f.queue_free()
		if sq != null and is_instance_valid(sq):
			sq.queue_free()


## The bot's pad's intent this frame, with its aim (NpcPad.aim once MOVE's pad has one; the mind's meta until then).
func pad_intent(b: NpcBending) -> Dictionary:
	var it := b.pad().intent()
	if not it.has("aim"):
		it["aim"] = b.pad().get_meta(&"aim", Vector3.ZERO)
	return it


## The 12 spots: [end, metres out, feet under the lip, double jump spent].
func spots() -> Array:
	var out: Array = []
	var i := 0
	for e: int in [0, 1]:
		for m: float in [2.0, 5.0, 8.0]:
			for h: float in [0.5, 2.5]:
				out.append([e, m, h, i % 2 == 1])
				i += 1
	return out


func _run() -> void:
	for i in 10:
		await process_frame
	var lvl := current_scene as RingLevel
	mode = RingMode.find(self)
	_expect(lvl != null and mode != null, "the ring with a practice")
	if mode == null:
		return _end()
	ring = lvl.ring
	player = lvl.player
	player.no_death = true
	await _until(func() -> bool: return mode.phase == "FIGHT", 10.0)
	mode.rules.live = false
	if mode.foe != null:
		mode.foe.held = true
		mode.foe.global_position = ring.global_position + Vector3(0.0, 40.0, 60.0)
	player.global_position = at_s(mode.player_end, 6.0)
	player.set_physics_process(false)
	rules = Standins.install_rules()
	_expect(RingRules.stock_on(), "the gate on (a stand-in stock RingRules)")
	if real:
		print("  (mover=real: RingMoves' own physics; MOVE's part)")
	var used := {"jump": 0, "rise": 0, "dodge": 0}
	var plans := {}
	for preset: String in ["hard", "normal", "easy"]:
		var widest := [INF, -INF]
		for el: String in Bending.ELEMENTS:
			if only != "" and el != only:
				continue
			var ok := 0
			var n := 0
			var f := bot(el, preset, at_s(1 - mode.player_end, 3.0))
			for sp: Array in spots():
				n += 1
				var res := await _trial(f, sp, used)
				if res == "back":
					ok += 1
			var m := f.brain.bending.mind()
			for k: String in m.stats.plans_by:
				plans[k] = int(plans.get(k, 0)) + int(m.stats.plans_by[k])
			var rate := float(ok) / float(n)
			widest = [minf(widest[0], rate), maxf(widest[1], rate)]
			print("METRIC bot_recover_success_%s_%s=%.2f (%d of %d)" % [el, preset, rate, ok, n])
			_expect(rate >= float(WANT[preset]) - 1e-4, "%s %s comes back from %d of %d spots (%.0f%%; >= %.0f%%)" % [preset, el, ok, n,
					100.0 * rate, 100.0 * float(WANT[preset])])
			free_bot(f)
			await process_frame
		print("METRIC recover_spread_%s=%.2f" % [preset, float(widest[1]) - float(widest[0])])
	print("METRIC plans_by=%s used=%s" % [plans, used])
	_expect(int(used.jump) > 0 and int(used.rise) > 0, "it used the double jump (%d) and the Rise (%d)" % [used.jump, used.rise])
	await _fourth_grab()
	await _neutral()
	_end()


## One trial: the bot put off the deck at spot `sp`, thrown outward at 3 m/s; "back" (the deck or the edge) or "water".
func _trial(f: NpcFighter, sp: Array, used: Dictionary) -> String:
	var b := f.brain.bending
	var m := b.mind()
	var e := int(sp[0])
	var dir := (ring.axis() * RingArena.side_sign(e)).normalized()
	var p := ring.global_position + dir * (ring.half_l() + float(sp[1]))
	p.y = ring.lip_y() - float(sp[2])
	var spent := bool(sp[3])
	var st := {"pos": p, "vel": dir * 1.0, "carry": dir * 3.0, "element": b.element, "jumps_left": 0 if spent else 1,
			"dodge_ready": true, "rise_ready": true, "helpless": false, "grabs_left": 3}
	var fm := Standins.FakeMoves.put(f, ring, st)
	m.plan = {}
	m._grabs = 0
	m.state = NpcRingMind.S.NEUTRAL
	b._cancel()
	var dt := 1.0 / 60.0
	var t := 0.0
	var res := "water"
	while t < TRIAL_S:
		b.tick(dt)
		var it := pad_intent(b)
		var had := [int(fm.s.jumps), bool(fm.s.rise), bool(fm.s.dodge)]
		fm.drive(it, dt)
		# (each move counted as the mover takes it)
		if int(fm.s.jumps) < int(had[0]):
			used.jump = int(used.jump) + 1
		if bool(had[1]) and not bool(fm.s.rise):
			used.rise = int(used.rise) + 1
		if bool(had[2]) and not bool(fm.s.dodge):
			used.dodge = int(used.dodge) + 1
		t += dt
		if fm.on_deck or fm.hanging:
			res = "back"
			break
		if fm.out:
			break
	if res != "back":
		print("    (%s %s lost from %s: at %s, its last plan %s, the desperate line %d times)" % [b._preset_name(), b.element, sp,
				fm.s.p, m.plan.get("name", "-"), int(m.stats.desperate)])
	await process_frame
	return res


## Three grabs used without the deck: the planner's plans land on the deck (or fall), never a 4th grab.
func _fourth_grab() -> void:
	var f := bot("air", "hard", at_s(1 - mode.player_end, 3.0))
	var b := f.brain.bending
	var m := b.mind()
	var e := 1 - mode.player_end
	var dir := (ring.axis() * RingArena.side_sign(e)).normalized()
	var p := ring.global_position + dir * (ring.half_l() + 2.0)
	p.y = ring.lip_y() - 1.0
	var fm := Standins.FakeMoves.put(f, ring, {"pos": p, "vel": Vector3.ZERO, "carry": dir * 1.0, "element": "air",
			"jumps_left": 1, "dodge_ready": true, "rise_ready": true, "grabs_left": 0})
	fm.s.grabs_left = 0
	m._grabs = 3
	m.plan = {}
	var t := 0.0
	while t < TRIAL_S and not fm.on_deck and not fm.hanging and not fm.out:
		b.tick(1.0 / 60.0)
		fm.drive(pad_intent(b), 1.0 / 60.0)
		t += 1.0 / 60.0
	print("METRIC grabs_refused=%d (the 4th grab the mover refused)" % fm.refused)
	_expect(not fm.hanging and fm.grabs == 0, "after three grabs without the deck no 4th grab (%s; refused %d)" % [
			"on the deck" if fm.on_deck else "in the water" if fm.out else "in the air", fm.refused])
	free_bot(f)
	await process_frame


## 60 s of neutral on the deck at normal and hard (the mover walks it where its mind goes, as MOVE's go() would): it never
## leaves the deck by itself.
func _neutral() -> void:
	for preset: String in ["normal", "hard"]:
		var f := bot("fire", preset, at_s(1 - mode.player_end, 4.0))
		var b := f.brain.bending
		var fm := Standins.FakeMoves.put(f, ring, {"pos": f.global_position, "element": "fire"})
		fm.on_deck = true
		var falls := 0
		var think_t := 0.0
		var t := 0.0
		while t < 60.0:
			think_t -= 1.0 / 60.0
			if think_t <= 0.0:
				think_t = 0.25
				f.brain.think(0.25)
			b.tick(1.0 / 60.0)
			var it := pad_intent(b)
			var goal: Vector3 = f.get(&"_goal")
			if goal != Vector3.INF and it.move == Vector3.ZERO:
				it.move = NpcRingMind.flat_dir(f.global_position, goal) if NpcRingMind.flat_d(f.global_position, goal) > 0.4 else Vector3.ZERO
			fm.drive(it, 1.0 / 60.0)
			if fm.hanging:
				fm.hanging = false
				fm.on_deck = true
				fm.s.p = Vector3(signf(fm.s.p.x) * (float(fm.geo.hl) - 0.6), 0.0, fm.s.p.z)
			if fm.out:
				falls += 1
				fm.out = false
				fm.on_deck = true
				fm.s.how = ""
				fm.s.p = Vector3.ZERO
			t += 1.0 / 60.0
			if int(t * 60.0) % 60 == 0:
				await process_frame
		print("METRIC self_falls_neutral_%s=%d" % [preset, falls])
		_expect(falls == 0, "%s: 60 s of neutral, never in the water by itself (%d)" % [preset, falls])
		free_bot(f)
		await process_frame
