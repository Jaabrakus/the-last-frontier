extends SceneTree
## The gun-style casts (2026-10-11, the owner: Embers the pistol, the Ice Spear with the water spear forming in the hands;
## 2026-10-12: "the lightning pistol... we dont have that skill and use that animation for the ice or water rifle spear for
## water? and we keep the orignal lightning animation"), headless, in the ring:
##   the picks       Embers' gun clips (each hand) timed as the sweep they replaced; the Ice Spear on our own overhand spear
##                   throw with the floating spear (held "ice_spear"), launched from it (float_from), charged held past full
##                   (its grow: ice/spear.grown); Lightning the original; the Lightning Pistol twist gone (not in the tree)
##   the spear       (the owner, later 2026-10-12: "use the spear from the frontiers game but make it icy blue", "float above
##                   the user offset pararell with the arm") the Ice Spear's lock holds BendLooks.FloatSpear: drawn out as the
##                   lock fills, floating over the throwing arm, its point on the aim; charged, longer and glowing; cast, it
##                   stays to the strike and goes; the lance thrown from where it floated; a broken lock shatters it
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_gun_casts.gd
## Ends with "GUN CASTS TEST PASSED (n checks)" or "... FAILED"; exit 0 only on a pass.

const NAME := "GUN CASTS TEST"
const LIMIT_S := 240.0
const PISTOL := "fire.lightning.pistol"
const ICE_CLIP := "own-bend-throw-overhand"

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var sc: SwayCaster
var pose: SwayPose
var _struck_frame := -1
var _frame := 0


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(2026)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func _end() -> void:
	BendLooks.build_headless = false
	if player != null and is_instance_valid(player):
		BendLoadout.clear(player)
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _near(a: Variant, b: Variant) -> bool:
	return a != null and b != null and is_equal_approx(float(a), float(b))


func _pin(m: String, md: String) -> void:
	sc._pin_id = m
	sc._pin_mode = md
	sc._pinning = true


func _on_struck(_m: String) -> void:
	if _struck_frame < 0:
		_struck_frame = _frame


func _run() -> void:
	BendLooks.build_headless = true
	# ---------------------------------------------------------------- the picks (no scene)
	var em := BendPoses.pick("fire_jab", "embers", "fire")
	var sweep := BendPoses._filled({"clip": "own-bend-fire-sweep"}, BendPoses.data())
	var alt := BendPoses._filled(BendPoses._as_pose(em.get("alt", "")), BendPoses.data())
	var sweep_l := BendPoses._filled({"clip": "own-bend-fire-sweep-l"}, BendPoses.data())
	_expect(String(em.clip) == "own-bend-fire-embers-gun" and String(alt.clip) == "own-bend-fire-embers-gun-l"
			and String(em.hand) == "r_palm" and String(alt.hand) == "l_palm",
			"Embers: the pistol clip, each hand in turn (%s, %s)" % [em.clip, alt.clip])
	var same := true
	for k: String in ["hold_s", "strike_s", "back_s"]:
		same = same and _near(em.get(k), sweep.get(k)) and _near(alt.get(k), sweep_l.get(k))
	_expect(same and _near(em.get("end_s"), BendPoses.animation("own-bend-fire-sweep").length) and em.has("warp") and alt.has("warp"),
			"Embers: timed as the sweep it replaced (hold %.2f, strike %.2f, back %.2f, end %.2f s), both hands" % [float(em.hold_s),
			float(em.strike_s), float(em.back_s), float(em.get("end_s", -1.0))])
	var sp := BendPoses.pick("ice", "spear", "water")
	var ss: Dictionary = (SwayMoves.move("ice").get("bend", {}) as Dictionary).get("spear", {})
	_expect(String(sp.clip) == ICE_CLIP and String(BendPoses._as_pose(sp.get("alt", "")).get("clip", "")) == "own-bend-throw-overhand-l"
			and String(sp.get("held", "")) == "ice_spear" and bool(ss.get("float_from", false)) and ss.get("grow") is Dictionary
			and not RingRules.class_of("ice/spear.grown").is_empty(),
			"Ice Spear: our own overhand spear throw (each hand), the floating spear held and thrown from, charged when grown (%s)" % sp.clip)
	_expect(BendPoses.body_strike_s(em) == float(BendPoses.animation("own-bend-fire-embers-gun").get_meta(&"strike_s")),
			"a bot plays the gun clip straight through: its strike is the clip's own (%.3f s)" % BendPoses.body_strike_s(em))
	_expect(String(BendPoses.pick("fire_arc", "lightning", "fire").clip) == "own-bend-fire-lightning",
			"Lightning is the original two-handed charge")
	_expect(AdvancementData.node(PISTOL).is_empty() and not PISTOL in BendLoadout.live_ids(),
			"the Lightning Pistol twist is gone: not in the tree, not live")

	# ---------------------------------------------------------------- the ring
	MatchSetup.incoming = true
	MatchSetup.element = "fire"
	MatchSetup.foes = ["fire"]
	MatchSetup.round_s = 120.0
	MatchSetup.rounds_to_win = 1
	MatchSetup.difficulty = "normal"
	InputSetup.ensure()
	SwayCaster.free_override = true
	change_scene_to_file("res://scenes/ring.tscn")
	await _frames(20)
	lvl = current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	sc = SwayCaster.of(player) if player != null else null
	pose = sc.pose if sc != null else null
	_expect(mode != null and player != null and sc != null and pose != null and player.skeleton != null, "the ring, the player, his caster and pose")
	if pose == null or player.skeleton == null:
		return _end()
	if mode.foe != null and is_instance_valid(mode.foe):
		mode.foe.held = true
		mode.foe.global_position = Vector3(0.0, 60.0, -400.0)
	await _frames(30)
	await _spear_checks()
	_end()


## The Ice Spear's floating spear: drawn out as the lock fills, over the throwing arm, its point on the aim; charged, longer and
## glowing; cast, it stays to the strike and goes; the lance thrown from where it floated; a broken lock shatters it.
func _spear_checks() -> void:
	Bending.of(player).element = "water"
	_pin("ice", "spear")
	pose._clock += 10.0
	pose._last_key = ""
	pose._stop()
	sc._lock_looks("ice")
	var spear: Node3D = sc.charge as Node3D
	_expect(spear != null and spear.name.begins_with("BendFloatSpear"), "the Ice Spear's lock floats the spear (%s)" % (spear.name if spear != null else "none"))
	if spear == null:
		return
	pose._on_started("ice", null)
	_expect(String(pose.anim_name).begins_with(ICE_CLIP), "the lock plays the overhand spear throw (%s)" % pose.anim_name)
	var shown_at := -1.0
	for i in 36:                            # (0.6 s: the lock's fill rising to full)
		spear.set(&"level", clampf(float(i + 1) / 36.0, 0.0, 1.0))
		await process_frame
		if shown_at < 0.0 and spear.visible:
			shown_at = float(i + 1) / 36.0
	_expect(shown_at > 0.0 and shown_at < 0.3, "it is drawn out of the air as the lock fills (seen at %.2f of the fill)" % shown_at)
	await _frames(20)                       # (settled over the arm)
	# (the arm read in the skeleton's update, after the cast's pose: where it is drawn, as the spear reads it)
	var sk := player.skeleton
	var seen := {}
	var cb := func() -> void:
		var hb := String(pose.pick.get("hand", "r_palm"))
		seen["hand"] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(hb)).origin
		seen["sh"] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(hb.substr(0, 2) + "shoulder")).origin
	sk.skeleton_updated.connect(cb)
	await _frames(2)
	sk.skeleton_updated.disconnect(cb)
	var over := Vector3(seen.get("hand", Vector3.ZERO)).lerp(Vector3(seen.get("sh", Vector3.ZERO)), 0.5)
	var up := spear.global_position.y - over.y
	var flat := Vector2(spear.global_position.x - over.x, spear.global_position.z - over.z).length()
	var aim := BendCaster.of(player).aim_point()
	var to_aim := (aim - spear.global_position).normalized() if aim.is_finite() else -player.global_basis.z
	var off_deg := rad_to_deg((-spear.global_basis.z).angle_to(to_aim))
	_expect(up > 0.15 and up < 0.5 and flat < 0.25, "it floats over the arm, %.2f m above the shoulder-to-hand middle (%.2f m aside)" % [up, flat])
	_expect(off_deg < 12.0, "its point is on the aim (%.1f deg off)" % off_deg)
	var fm: Variant = player.get_meta(BendLooks.FLOAT_META, null)
	_expect(fm is Dictionary and (Vector3((fm as Dictionary).at)).distance_to(spear.global_position) < 0.05,
			"where it floats is kept for the throw")
	# charged: held past full
	var len0 := float((spear.get(&"_spear") as Node3D).scale.z) if spear.get(&"_spear") != null else 1.0
	sc.grown = true
	await _frames(30)
	var len1 := float((spear.get(&"_spear") as Node3D).scale.z) if spear.get(&"_spear") != null else 1.0
	var lt: OmniLight3D = spear.get(&"_light")
	_expect(len1 > len0 * 1.15 and (lt == null or lt.light_energy > 0.5),
			"charged: it grows longer (%.2f -> %.2f) and glows (%.2f)" % [len0, len1, lt.light_energy if lt != null else -1.0])
	sc.grown = false
	# the lance thrown from where it floated
	var bc := BendCaster.of(player)
	var at: Vector3 = spear.global_position
	player.set_meta(BendLooks.FLOAT_META, {"at": at, "t": BendStatus.now()})
	var spec: Dictionary = ((SwayMoves.move("ice").get("bend", {}) as Dictionary).get("spear", {}) as Dictionary).duplicate(true)
	var lance := BendThrow.one(bc, BendEffects.aim(bc, spec), spec)
	_expect(lance != null and lance.global_position.distance_to(at) < 0.2, "the lance leaves from where the spear floated (%.2f m off)"
			% (lance.global_position.distance_to(at) if lance != null else -1.0))
	if lance != null:
		lance.end("world")
	# cast: over the arm to the strike, then gone
	_struck_frame = -1
	_frame = 0
	pose.struck.connect(_on_struck, CONNECT_ONE_SHOT)
	sc._end_charge()                        # (the lock over, as at a cast: SwayCaster._end_lock before the cast signal)
	pose._on_cast("ice", null)
	var seen_before := false
	var guard := 0
	while _struck_frame < 0 and guard < 120:
		await process_frame
		_frame += 1
		guard += 1
		if _struck_frame < 0:
			seen_before = seen_before or (is_instance_valid(spear) and spear.visible and not bool(spear.get(&"_gone")))
	await _frames(2)
	_expect(seen_before and _struck_frame > 0, "cast: it stays over the arm to the strike (frame %d)" % _struck_frame)
	_expect(not is_instance_valid(spear) or bool(spear.get(&"_gone")), "after the strike it is gone (the lance flies)")
	await _frames(60)
	# broken: it shatters
	pose._stop()
	sc._lock_looks("ice")
	var s2: Node3D = sc.charge as Node3D
	pose._on_started("ice", null)
	if s2 != null:
		for i in 20:
			s2.set(&"level", 0.5)
			await process_frame
	sc._end_charge()
	pose._on_end()                          # (the lock broken: the stand)
	await _frames(3)
	_expect(s2 != null and (not is_instance_valid(s2) or bool(s2.get(&"_gone"))), "a broken lock shatters it")
	sc._pinning = false
