extends SceneTree
## The gun-style casts (2026-10-11, the owner: Embers the pistol, the Ice Spear with the water spear forming in the hands;
## 2026-10-12: "the lightning pistol... we dont have that skill and use that animation for the ice or water rifle spear for
## water? and we keep the orignal lightning animation"), headless, in the ring:
##   the picks       Embers' gun clips (each hand) timed as the sweep they replaced; the Ice Spear on the game's own standing
##                   pistol aim (frontier-pistol-ice, aim "pistol", the water spear held) timed as the overhand throw; Lightning
##                   the original; the Lightning Pistol twist gone (not in the tree, not live)
##   the aim         an Ice Spear lock: BendAimArm right after the cast pose (before the body's helpers), the two fingers on the
##                   crosshair's point and the head turned toward it while it is held; the kick after the strike; off once the
##                   cast is over
##   the water spear the Ice Spear's lock holds the water spear (BendLooks.HeldSpear) out from the pointing hand along its
##                   forearm, drawn out as the lock fills; cast, it stays in the hand to the strike and is gone after it; a
##                   broken lock drops it
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_gun_casts.gd
## Ends with "GUN CASTS TEST PASSED (n checks)" or "... FAILED"; exit 0 only on a pass.

const NAME := "GUN CASTS TEST"
const LIMIT_S := 240.0
const PISTOL := "fire.lightning.pistol"
const ICE_CLIP := "frontier-pistol-ice"
## The two fingers point within this of the crosshair's point; the head's face within HEAD_DEG of it.
const AIM_DEG := 6.0
const HEAD_DEG := 12.0

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var sc: SwayCaster
var pose: SwayPose
var _struck_frame := -1
var _frame := 0
## Sampled in the skeleton's update (after every modifier): the fingers' and the face's angles to the aim (deg).
var _finger_deg := -1.0
var _face_deg := -1.0
var _spear_seen := {}


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
	var over := BendPoses._filled({"clip": "own-bend-throw-overhand"}, BendPoses.data())
	_expect(String(sp.clip) == ICE_CLIP and String(sp.hand) == "r_palm" and String(sp.get("aim", "")) == "pistol"
			and String(sp.get("held", "")) == "water_spear"
			and _near(sp.hold_s, over.hold_s) and _near(sp.strike_s, over.strike_s) and _near(sp.back_s, over.back_s)
			and _near(sp.get("end_s"), BendPoses.animation("own-bend-throw-overhand").length),
			"Ice Spear: the pistol's aim, the water spear held, timed as the overhand throw (strike %.2f s), the bolt from the pointing hand" % float(sp.strike_s))
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
	await _aim_checks()
	await _spear_checks()
	_end()


## An Ice Spear lock on the pistol's aim: the arm and the head on the crosshair, the kick, off after.
func _aim_checks() -> void:
	Bending.of(player).element = "water"
	_expect(String(BendPoses.pick("ice", "spear", "water", player).clip) == ICE_CLIP
			and String(BendPoses.pick("ice", "spear", "water", mode.foe).clip) == ICE_CLIP,
			"the player's Ice Spear and the bot's are both the pistol's aim")
	_pin("ice", "spear")
	var sk := player.skeleton
	sk.skeleton_updated.connect(_sample_aim)
	pose._on_started("ice", null)
	_expect(String(pose.anim_name) == ICE_CLIP and String(pose.pick.get("aim", "")) == "pistol",
			"the lock plays the pistol's aim (%s)" % pose.anim_name)
	await _frames(30)                      # (0.5 s: raised, held on the aim)
	var arm: Node = pose._aim_arm
	_expect(arm != null and is_instance_valid(arm) and arm.get_parent() == sk and arm.get_index() == pose._pose.get_index() + 1,
			"BendAimArm sits right after the cast pose")
	var after_ok := true
	if arm != null and is_instance_valid(arm):
		for i in range(arm.get_index() + 1, sk.get_child_count()):
			after_ok = after_ok and sk.get_child(i) is CharacterBodyMesh
	_expect(after_ok, "only the body's helpers come after it")
	_expect(arm != null and float(arm.get(&"weight")) > 0.95, "held on the aim: its weight %.2f" % (float(arm.get(&"weight")) if arm != null else -1.0))
	_expect(_finger_deg >= 0.0 and _finger_deg <= AIM_DEG, "the two fingers point at the crosshair's point (%.1f deg off)" % _finger_deg)
	_expect(_face_deg >= 0.0 and _face_deg <= HEAD_DEG, "the head looks at the crosshair's point (%.1f deg off)" % _face_deg)
	_expect(is_zero_approx(pose.aim_lean), "no spine lean on the pistol's aim (%.3f)" % pose.aim_lean)
	# the release: the strike, the kick, the end
	_struck_frame = -1
	_frame = 0
	pose.struck.connect(_on_struck, CONNECT_ONE_SHOT)
	pose._on_cast("ice", null)
	var kick_max := 0.0
	var guard := 0
	while pose.phase != "" and guard < 400:
		await process_frame
		_frame += 1
		guard += 1
		if arm != null and is_instance_valid(arm):
			kick_max = maxf(kick_max, float(arm.get(&"kick_deg")))
	_expect(_struck_frame > 0, "the strike was told (frame %d after the release)" % _struck_frame)
	_expect(kick_max > 5.0, "the kick after the strike (up to %.1f deg)" % kick_max)
	await _frames(2)
	_expect(arm != null and is_instance_valid(arm) and float(arm.get(&"weight")) == 0.0, "the cast over: the arm's aim is off")
	sk.skeleton_updated.disconnect(_sample_aim)
	sc._pinning = false


func _sample_aim() -> void:
	var arm: Node = pose._aim_arm if pose != null else null
	if arm == null or not is_instance_valid(arm) or float(arm.get(&"weight")) < 0.95:
		return
	var sk := player.skeleton
	var g := func(bn: String) -> Vector3: return sk.get_bone_global_pose(sk.find_bone(bn)).origin
	var base: Vector3 = (g.call("r_indexa") + g.call("r_middlea")) * 0.5
	var tip: Vector3 = (g.call("r_indexc") + g.call("r_middlec")) * 0.5
	var target: Vector3 = arm.get(&"target")
	_finger_deg = rad_to_deg((tip - base).angle_to(target - tip))
	var hb := sk.find_bone("headb")
	var face_local := (sk.get_bone_global_rest(hb).basis.orthonormalized().inverse() * Vector3(0, 0, 1)).normalized()
	var hg := sk.get_bone_global_pose(hb)
	_face_deg = rad_to_deg((hg.basis.orthonormalized() * face_local).angle_to(target - hg.origin))


## The Ice Spear's water spear: out from the pointing hand while the lock fills, kept to the strike, gone after; a broken lock
## drops it.
func _spear_checks() -> void:
	Bending.of(player).element = "water"
	_pin("ice", "spear")
	pose._clock += 10.0
	pose._last_key = ""
	pose._stop()
	sc._lock_looks("ice")
	var spear: Node3D = sc.charge as Node3D
	_expect(spear != null and spear.name.begins_with("BendHeldSpear"), "the Ice Spear's lock holds the water spear (%s)" % (spear.name if spear != null else "none"))
	if spear == null:
		return
	pose._on_started("ice", null)
	_expect(String(pose.anim_name) == ICE_CLIP, "the lock plays the pistol's aim (%s)" % pose.anim_name)
	var shown_at := -1.0
	for i in 36:                            # (0.6 s: the lock's fill rising to full)
		spear.set(&"level", clampf(float(i + 1) / 36.0, 0.0, 1.0))
		await process_frame
		if shown_at < 0.0 and spear.visible:
			shown_at = float(i + 1) / 36.0
	_expect(shown_at > 0.0 and shown_at < 0.3, "it is drawn out of the hands as the lock fills (seen at %.2f of the fill)" % shown_at)
	# (the hands and the spear read in the skeleton's update, after the cast's pose: where they are drawn)
	var sk := player.skeleton
	_spear_seen = {}
	var cb := func() -> void:
		if is_instance_valid(spear):
			_spear_seen = {"rp": sk.global_transform * sk.get_bone_global_pose(sk.find_bone("r_palm")).origin,
					"re": sk.global_transform * sk.get_bone_global_pose(sk.find_bone("r_elbow")).origin,
					"at": spear.global_position, "way": -spear.global_basis.z}
	sk.skeleton_updated.connect(cb)
	await _frames(2)
	sk.skeleton_updated.disconnect(cb)
	var rp: Vector3 = _spear_seen.get("rp", Vector3.ZERO)
	var re: Vector3 = _spear_seen.get("re", Vector3.ZERO)
	var way: Vector3 = _spear_seen.get("way", Vector3.FORWARD)
	var fore := (rp - re).normalized()
	var off := (Vector3(_spear_seen.get("at", Vector3.ZERO)) - rp).length()
	var ang := rad_to_deg(way.angle_to(fore))
	print("  (spear: palm %s, %.2f m up; its way %s; the forearm's %s; the body's ahead %s)" % [rp, rp.y - player.global_position.y,
			way, fore, -player.global_basis.z])
	_expect(off < 0.4 and ang < 20.0, "it runs out from the pointing hand along its forearm (its middle %.2f m from the palm, %.0f deg off the forearm)" % [off, ang])
	# cast: in the hands to the strike, then gone
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
	_expect(seen_before and _struck_frame > 0, "cast: it stays in the hands to the strike (frame %d)" % _struck_frame)
	_expect(not is_instance_valid(spear) or bool(spear.get(&"_gone")), "after the strike it is gone (the ice lance flies)")
	await _frames(60)
	# broken: it falls
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
	_expect(s2 != null and (not is_instance_valid(s2) or bool(s2.get(&"_gone"))), "a broken lock drops it")
	sc._pinning = false
