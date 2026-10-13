extends SceneTree
## The High Kick at close range (the owner, 2026-10-11: "we need to make where it is fast and aims at the cursor because the
## opponent is really close and it hits the ground its like useless"), in a practice ring, fire against a standing earth dummy:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_high_kick_close.gd -- mode=ring practice=stand element=fire foe=earth
##   the case      the dummy 2.5 m off, the crosshair on the deck between them (the camera over the shoulder looks down there):
##                 the line from the kick to that point dives more than 6 degrees into the deck
##   the blast     meets the deck's level no nearer than min_reach_m (6 m) and strikes him (his % goes up within 0.6 s)
##   before        the same kick without min_reach_m (as it was) goes into the deck: his % stays where it was
##   fast          the High Kick's lock 0.55 s (moves.json fire_kick mode_lock_s)
## Last line "HIGH KICK CLOSE PASSED" or "... FAILED".

var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var mode: RingMode
var pitch_sign := 1.0


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	if fails.is_empty() and checks > 0:
		print("HIGH KICK CLOSE PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("HIGH KICK CLOSE FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	for i in 12:
		await process_frame
	var lvl := current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	_expect(player != null and mode != null and mode.foe != null, "a practice ring, fire against a standing dummy")
	if player == null or mode == null or mode.foe == null:
		return _end()
	await _ticks(240)
	var foe := mode.foe
	Bending.of(player).element = "fire"
	_expect(is_equal_approx(float((SwayMoves.move("fire_kick").get("mode_lock_s", {}) as Dictionary).get("high_kick", 0.0)), 0.55),
			"the High Kick is fast: its lock 0.55 s")
	# the player 2.5 m from the dummy, facing him
	var away := (player.global_position - foe.global_position) * Vector3(1, 0, 1)
	away = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
	var at := foe.global_position + away * 2.5
	at.y = player.global_position.y
	RingLevel.place(player, Transform3D(Basis.looking_at(-away, Vector3.UP), at))
	player.pitch = 0.3
	await _ticks(3)
	pitch_sign = 1.0 if (-player.camera.global_basis.z).y > 0.0 else -1.0
	# the crosshair on the deck between them, within 1.6 m before the player (the camera over his shoulder looks down there):
	# his view turned to the dummy and tipped down a step at a time till it is
	var d := (foe.global_position - player.camera.global_position).normalized()
	player.yaw = atan2(-d.x, -d.z)
	var pcc := BendCaster.of(player)
	var pitch_at := 0.0
	for k in 60:
		pitch_at = -0.03 * float(k)
		player.pitch = pitch_at * pitch_sign
		await _ticks(2)
		var ap := pcc.aim_point()
		if ap.is_finite() and Vector2(ap.x - player.global_position.x, ap.z - player.global_position.z).length() < 1.6:
			break
	await _ticks(2)
	var pc := BendCaster.of(player)
	var cross := pc.aim_point()
	var rules := mode.rules
	var pct0 := rules.pct_of(foe)
	var known := {}
	for n in get_nodes_in_group(BendBolt.GROUP):
		known[n.get_instance_id()] = true
	BendEffects.apply(pc, "fire_kick", "high_kick", SwayMoves.move("fire_kick").bend.high_kick)
	var blast: BendBolt = null
	for n in get_nodes_in_group(BendBolt.GROUP):
		if n is BendBolt and not known.has(n.get_instance_id()) and (n as BendBolt).caster == player:
			blast = n
	if blast == null:
		_expect(false, "a High Kick blast")
		return _end()
	var b0 := blast.global_position - blast.velocity.normalized() * blast.travelled
	var dive := rad_to_deg(asin(clampf((cross - b0).normalized().y, -1.0, 1.0)))
	var pitch := rad_to_deg(asin(clampf(blast.velocity.normalized().y, -1.0, 1.0)))
	_expect(cross.is_finite() and absf(cross.y - mode.ring.deck_y()) < 0.3 and dive < -6.0,
			"the case: the crosshair on the deck before him (%.2f m over it), the line to it %.0f degrees into the deck" % [cross.y - mode.ring.deck_y(), dive])
	var h0 := b0.y - player.global_position.y
	var meets := h0 / tan(deg_to_rad(-pitch)) if pitch < -0.01 else INF
	_expect(meets >= 5.95, "the blast meets the deck's level no nearer than 6 m (%.1f m; %.1f degrees down)" % [meets, -pitch])
	var hit := false
	for i in 36:
		await physics_frame
		if rules.pct_of(foe) > pct0:
			hit = true
			break
	_expect(hit, "it strikes the dummy 2.5 m off (his %% %.0f -> %.0f)" % [pct0, rules.pct_of(foe)])
	# before: the same aim without the floor dives into the deck and misses him
	for i in 60:
		await physics_frame
	rules.reset_pct(foe, 0.0)
	var old: Dictionary = (SwayMoves.move("fire_kick").bend.high_kick as Dictionary).duplicate()
	old.erase("min_reach_m")
	await _ticks(2)
	BendEffects.apply(pc, "fire_kick", "high_kick", old)
	var hit2 := false
	for i in 36:
		await physics_frame
		if rules.pct_of(foe) > 0.0:
			hit2 = true
			break
	_expect(not hit2, "before the fix the same kick went into the deck (his %% stays %.0f)" % rules.pct_of(foe))
	_end()
