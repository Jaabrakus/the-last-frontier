extends SceneTree
## Round 4 READ's shots in flight (BendSounds.flight, FLIGHTS; tools/sfx/bend/flight.py), on round 3's test deck
## (tests/ring/r3_move_rig.gd: the bare ring, an arena; voices made headless for this):
##   listener  the listener is the player's camera (the viewport's camera, no other listener)
##   kinds     every bolt kind but lightning (stone, ice, water, fire, air, and the Kick's floor wave) plays its own flight
##             voice from its launch, a loop with doppler tracked on the physics step (every other sound's voice untracked as
##             before), let go within 0.1 s of its hit (its fade FLIGHT_OUT_S); lightning has none
##   pool      20 bolts in flight at once: never more than FLIGHT_MAX voices with a shot, the nearest to the listener kept,
##             never more than FLIGHT_POOL sounding
##   catch     earth's catch: a bot's stone disc whirrs in; the player's Catch takes it: its whirr stops while it is held;
##             his Earth Shove sends it back: it whirrs again from the throw (a Gust lift in flight); the catch's timing as ever
##   own       the player's own shot plays OWN_DB (-6 dB) under a bot's at the same place
##   levels    every flight id's level at 2 m is at least 6 dB over its level at 12 m (the voice's own 3D settings)
##   gate      no arena in the scene (the open world): a bolt plays no flight voice
## METRIC flight_voices_max, voice_rise_db <id>, doppler_ok, listener_ok, open_world_silent_ok.
## Last line "RING READ PASSED" or "RING READ FAILED"; exit 0 only on a pass.
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_read.gd [-- only=kinds,pool,...]

const NAME := "RING READ"
const WATCHDOG_S := 300.0
const OWN_CFG := "user://ring_read_test.cfg"
const Rig := preload("res://tests/ring/r3_move_rig.gd")

var checks := 0
var fails: Array[String] = []
var only := ""
var rig: Rig
var p: FrontierPlayer
var shooter: Node3D
var flight_max := 0


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "strong"
	seed(1750)
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.get_slice("=", 1)
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	SwayCaster.free_override = true
	InputSetup.ensure()
	_run.call_deferred()


func _on(part: String) -> bool:
	return only == "" or part in only.split(",")


func _run() -> void:
	BendSounds.voices_headless = true
	rig = Rig.new(self)
	var ok: bool = await rig.setup("earth")
	_expect(ok, "the rig: the bare ring's player on the test deck")
	if not ok:
		_end()
		return
	p = rig.p
	rig.place(p, rig.at(8.0, 0.0), -PI * 0.5)
	shooter = Node3D.new()
	shooter.name = "TestShooter"
	current_scene.add_child(shooter)
	shooter.global_position = rig.at(23.0, 0.0, 1.2)
	_expect(BendSounds.arena_on(self), "the ring is an arena (RingArena): shots sound in flight")
	var seen := func() -> void: flight_max = maxi(flight_max, BendSounds.flight_voices())
	physics_frame.connect(seen)
	for part in ["listener", "kinds", "pool", "own", "levels", "catch", "gate"]:
		if _on(part):
			await call("_" + part)
			await _clear()
	print("METRIC flight_voices_max %d" % flight_max)
	_end()


func _end() -> void:
	BendSounds.voices_headless = false
	RingMoves.geo_override = {}
	SwayCaster.free_override = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _clear() -> void:
	for b in get_nodes_in_group(BendBolt.GROUP):
		(b as BendBolt).end("test")
	await rig.secs(0.2)


## A bolt of `kind` from `from` toward `to` by `by` (a fire punch's numbers otherwise).
func _bolt(by: Node3D, kind: String, from: Vector3, to: Vector3, extra := {}) -> BendBolt:
	var spec := {"kind": kind, "mps": 26.0, "damage": 10.0, "knock_mps": 2.0, "radius_m": 0.2, "range_m": 40.0}
	spec.merge(extra, true)
	return BendBolt.launch(by, from, (to - from).normalized(), spec)


# ---------------------------------------------------------------- listener
func _listener() -> void:
	var vp := p.get_viewport()
	var ok := vp.get_camera_3d() == p.camera and vp.get_audio_listener_3d() == null \
			and BendSounds.listener_pos(vp).is_equal_approx(p.camera.global_position)
	print("METRIC listener_ok %s" % ok)
	_expect(ok, "the listener is the player's camera (the viewport's camera, no other listener)")


# ---------------------------------------------------------------- kinds
func _kinds() -> void:
	var doppler_ok := true
	var deck := rig.at(15.0, 0.0)
	for kind: String in ["stone", "ice", "water", "fire", "air", "floor"]:
		var b: BendBolt
		if kind == "floor":
			b = _bolt(shooter, "fire", rig.at(20.0, 0.0), rig.at(12.0, 0.0), {"do": "floor_wave", "mps": 18.0, "range_m": 4.0})
		else:
			# (down onto the deck 8 m out: it lands there)
			b = _bolt(shooter, kind, shooter.global_position, deck)
		var v := BendSounds.flight_voice_of(b)
		var want: StringName = BendSounds.FLIGHTS[kind]
		var looped := v != null and v.stream is AudioStreamWAV and (v.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD
		_expect(v != null and StringName(v.get_meta(&"id", &"")) == want and v.playing and looped,
				"a %s bolt plays its flight voice from its launch (%s, looping)" % [kind, want])
		var ended := [-1.0]
		b.ended.connect(func(_why: String) -> void: ended[0] = BendStatus.now())
		var t := await rig.until(func() -> bool: return float(ended[0]) >= 0.0, 2.0)
		var tracked := v != null and v.doppler_tracking == AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
		doppler_ok = doppler_ok and tracked
		var gone := INF
		for i in 30:
			if v == null or not v.playing:
				gone = float(i) / Engine.physics_ticks_per_second
				break
			await physics_frame
		_expect(t < INF and gone <= 0.1 + 1e-4, "%s: doppler tracked (%s), let go %.3f s after its end (%.2f s in flight)" % [
				kind, tracked, gone, t])
	var other := BendSounds.play(&"fire_hit", p.global_position + Vector3(0, 0, 5)) as AudioStreamPlayer3D
	var others_ok := other != null and other.doppler_tracking == AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	_expect(others_ok, "every other sound's voice as before: no doppler")
	doppler_ok = doppler_ok and others_ok
	var n0 := BendSounds.flights_started
	var none := BendSounds.flight("lightning", shooter)
	_expect(none == null and BendSounds.flights_started == n0 and not BendSounds.FLIGHTS.has("lightning"),
			"lightning has no flight voice (it is instant)")
	print("METRIC doppler_ok %s" % doppler_ok)


# ---------------------------------------------------------------- pool
func _pool() -> void:
	var bolts: Array[BendBolt] = []
	for i in 20:
		# (high over the deck, slow, flying across it: nothing met; 4 to 42 m from the camera)
		var at := rig.at(8.0 + 2.0 * float(i), -6.0 + 0.5 * float(i % 5), 6.0)
		bolts.append(_bolt(shooter, ["stone", "ice", "water", "fire", "air"][i % 5], at, at + Vector3(0, 0, 10), {"mps": 1.5}))
	var worst_cap := 0
	var worst_sound := 0
	var nearest_ok := true
	var lp := BendSounds.listener_pos(p.get_viewport())
	for f in 40:
		await physics_frame
		worst_cap = maxi(worst_cap, BendSounds.flight_voices())
		worst_sound = maxi(worst_sound, BendSounds.flight_sounding())
		var voiced: Array[float] = []
		var waiting: Array[float] = []
		for b in bolts:
			if not is_instance_valid(b) or b.spent:
				continue
			var d := b.global_position.distance_to(lp)
			if BendSounds.flight_voice_of(b) != null:
				voiced.append(d)
			else:
				waiting.append(d)
		if not voiced.is_empty() and not waiting.is_empty():
			nearest_ok = nearest_ok and voiced.max() <= waiting.min() + 0.05
		nearest_ok = nearest_ok and voiced.size() == mini(BendSounds.FLIGHT_MAX, voiced.size() + waiting.size())
	_expect(worst_cap <= BendSounds.FLIGHT_MAX and worst_cap == BendSounds.FLIGHT_MAX,
			"20 bolts in flight: %d voices with a shot at most (FLIGHT_MAX %d)" % [worst_cap, BendSounds.FLIGHT_MAX])
	_expect(worst_sound <= BendSounds.FLIGHT_POOL, "never more than %d sounding (fades included: %d)" % [BendSounds.FLIGHT_POOL, worst_sound])
	_expect(nearest_ok, "the voices are the nearest shots' every step")
	# the nearest ones gone: the waiting ones nearest now take their voices
	var by_d := bolts.duplicate()
	by_d.sort_custom(func(a: BendBolt, b: BendBolt) -> bool: return a.global_position.distance_to(lp) < b.global_position.distance_to(lp))
	for i in 3:
		(by_d[i] as BendBolt).end("test")
	await physics_frame
	var next_ok := true
	for i in range(3, 9):
		next_ok = next_ok and BendSounds.flight_voice_of(by_d[i]) != null
	_expect(next_ok, "three nearest shots end: the next three nearest take voices at once")
	for b in bolts:
		if is_instance_valid(b):
			b.end("test")


# ---------------------------------------------------------------- own
func _own() -> void:
	var at := p.global_position + Vector3(4.0, 3.0, 2.0)
	var mine := _bolt(p, "fire", at, at + Vector3(0, 0, 10), {"mps": 1.0})
	# (4 m apart: two fires that meet cancel each other)
	var theirs := _bolt(shooter, "fire", at + Vector3(0, 4.0, 0), at + Vector3(0, 4.0, 10), {"mps": 1.0})
	await rig.secs(0.2)
	var live := is_instance_valid(mine) and is_instance_valid(theirs)
	var vm := BendSounds.flight_voice_of(mine) if live else null
	var vt := BendSounds.flight_voice_of(theirs) if live else null
	var ok := vm != null and vt != null
	var diff := 0.0
	if ok:
		var lm := vm.volume_db - float(vm.get_meta(&"base_db", 0.0))
		var lt := vt.volume_db - float(vt.get_meta(&"base_db", 0.0))
		diff = lm - lt
		ok = bool(vm.get_meta(&"own", false)) and not bool(vt.get_meta(&"own", true)) and absf(diff - BendSounds.OWN_DB) < 0.01
	_expect(ok, "the player's own shot plays %.1f dB under a bot's (%.2f dB)" % [-BendSounds.OWN_DB, diff])
	if live:
		mine.end("test")
		theirs.end("test")


# ---------------------------------------------------------------- levels
func _levels() -> void:
	var all_ok := true
	for kind: String in BendSounds.FLIGHTS:
		var id: StringName = BendSounds.FLIGHTS[kind]
		var rise := BendSounds.level_db(id, 2.0) - BendSounds.level_db(id, 12.0)
		print("METRIC voice_rise_db %s %.1f (2 m %.1f dB, 6 m %.1f, 12 m %.1f, 22 m %.1f)" % [id, rise, BendSounds.level_db(id, 2.0),
				BendSounds.level_db(id, 6.0), BendSounds.level_db(id, 12.0), BendSounds.level_db(id, 22.0)])
		all_ok = all_ok and rise >= 6.0
	_expect(all_ok, "every flight id's level at 2 m is at least 6 dB over its level at 12 m")
	# the voices play by those numbers (the level curve is the voice's own: Godot's inverse distance from unit_size)
	var b := _bolt(shooter, "stone", shooter.global_position + Vector3(0, 4, 0), shooter.global_position + Vector3(0, 4, 10), {"mps": 1.0})
	var v := BendSounds.flight_voice_of(b)
	var c: Dictionary = BendSounds.TABLE[&"stone_whirr"]
	_expect(v != null and v.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			and is_equal_approx(v.unit_size, float(c.unit)) and is_equal_approx(v.max_distance, float(c.maxd))
			and is_equal_approx(v.max_db, BendSounds.FLIGHT_MAX_DB), "a flight voice's 3D settings are its row's (unit %s m, maxd %s m, cap %s dB)" % [
			c.unit, c.maxd, BendSounds.FLIGHT_MAX_DB])
	b.end("test")


# ---------------------------------------------------------------- catch
func _catch() -> void:
	var c := SwayCaster.of(p)
	var foe: NpcFighter = await rig.bot("earth", rig.at(17.0, 0.0), PI * 0.5)
	_expect(c != null and foe != null, "the player's caster and an earth bot 9 m before him")
	if c == null or foe == null:
		return
	p.no_death = true
	var bc := BodyBendCaster.new(foe, p, 0.0, 0.0)
	bc.bind()
	rig.place(p, rig.at(8.0, 0.0), -PI * 0.5)
	await rig.secs(0.3)
	c.set_mode("stone_catch", "catch")
	var caught := BendCast.cast(c, "stone_catch", "catch")
	var bolts0 := get_nodes_in_group(BendBolt.GROUP)
	var thrown := BendCast.cast(bc, "stone_form", "disc")
	var disc: BendBolt = null
	for b in get_nodes_in_group(BendBolt.GROUP):
		if not bolts0.has(b) and (b as BendBolt).kind == "stone":
			disc = b as BendBolt
	_expect(caught and thrown and disc != null, "the player's Catch stands; the bot throws a stone disc")
	if disc == null:
		return
	var v := BendSounds.flight_voice_of(disc)
	_expect(v != null and StringName(v.get_meta(&"id", &"")) == &"stone_whirr", "the disc whirrs in flight")
	var held: FormStone = null
	var t := 0.0
	while t < 1.5 and held == null:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		p.health = p.max_health
		for st in get_nodes_in_group(FormStone.GROUP):
			if int((st as Node).get_meta(&"bend_held_by", -1)) == p.get_instance_id():
				held = st as FormStone
	_expect(held != null, "the Catch takes the stone and holds it (%.2f s)" % t)
	if held == null:
		return
	await rig.secs(0.1)
	var quiet := true
	for i in 18:
		quiet = quiet and BendSounds.flight_voices() == 0 and (v == null or not v.playing or int(v.get_meta(&"fade", 0)) < 0)
		await physics_frame
	_expect(quiet, "while it is held it does not whirr")
	c.set_mode("earth_shove", "push")
	var shoved := BendCast.cast(c, "earth_shove", "push")
	var th := BendEffects.last.get("throw") as FormEffects.Throw
	_expect(shoved and th != null, "Earth Shove takes the held stone")
	if th == null:
		return
	var back := false
	for i in 90:
		await physics_frame
		if is_instance_valid(th) and th.lift != null and is_instance_valid(th.lift) and th.lift.phase == GustLift.Phase.FLIGHT:
			await physics_frame
			var lv := BendSounds.flight_voice_of(th.lift)
			back = lv != null and StringName(lv.get_meta(&"id", &"")) == &"stone_whirr" and lv.playing \
					and lv.global_position.distance_to(th.lift.stone.global_position) < 1.0
			break
	_expect(back, "sent back, it whirrs again in flight")
	await rig.secs(1.0)


# ---------------------------------------------------------------- gate
func _gate() -> void:
	var ar := RingArena.find(self)
	ar.remove_from_group(RingArena.GROUP)
	var n0 := BendSounds.flights_started
	var b := _bolt(shooter, "fire", shooter.global_position, shooter.global_position + Vector3(0, 0, 10), {"mps": 2.0})
	await rig.secs(0.2)
	var silent := not BendSounds.arena_on(self) and BendSounds.flights_started == n0 and BendSounds.flight_voice_of(b) == null
	ar.add_to_group(RingArena.GROUP)
	b.end("test")
	print("METRIC open_world_silent_ok %s (no arena in the scene; the open world itself: tests/player/test_player_gate.gd)" % silent)
	_expect(silent, "no arena in the scene (the open world): a bolt plays no flight voice")
