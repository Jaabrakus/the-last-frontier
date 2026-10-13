extends SceneTree
## The guard's spin with what it sends back (GuardSpin; the owner, 2026-10-12: "when put parry i want it to loop around like a
## moon", then of an arm IK or a body spin: "do and add what u can so we can see what it looks like"), in Tidebreak's ring
## (scenes/ring.tscn, the classic rules; the foe held where he stands and used as the one who shoots):
##   the turn    a perfect Parry's moon: the player's whole body (its hips' line, read off the final pose: skeleton_updated)
##               turns with the fire as it circles him, half a turn by mid-lap and a whole one by its end, the way it goes
##   the hand    his right hand reaches after it mid-lap (the shoulder-to-hand line within 35 degrees of the shoulder-to-fire
##               line); a Parry's lead hand only, a Wind Guard's both
##   after       the body back on its own facing within FOLLOW_S + BACK_S + 0.1 s of the lap's end, the spin off
##   visual      his body's facing (the CharacterBody3D's basis) and his camera untouched through it all
##   a bot       a fighter's Parry turns his body the same (his NpcBody's skeleton)
## Last line "GUARD SPIN PASSED" or "GUARD SPIN FAILED"; exit 0 only on a pass; a watchdog quits with 2.
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_guard_spin.gd

const NAME := "GUARD SPIN"
const WATCHDOG_S := 240.0
const OWN_CFG := "user://guard_spin_test.cfg"
const FIRE := {"kind": "fire", "mps": 32.0, "gravity": 0.0, "damage": 20.0, "knock_mps": 5.0, "radius_m": 0.2, "range_m": 30.0}
const AIR := {"kind": "air", "mps": 28.0, "gravity": 0.0, "damage": 6.0, "knock_mps": 11.0, "radius_m": 0.35, "range_m": 30.0}
const PARRY := {"do": "zone", "zone": "parry", "window_s": 0.8, "radius_m": 2.5}
const WIND := {"do": "zone", "zone": "air_shield", "at": "self", "window_s": 0.8, "radius_m": 2.2}

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var p: FrontierPlayer
var c: SwayCaster
var rm: RingMode
var foe: NpcFighter
var fbc: BodyBendCaster
var pbc: BendCaster
var _foe_at := Vector3.INF
## The frames recorded off the final pose (skeleton_updated): [hip yaw (rad), turn, reach_w, hand-to-thing angle (deg), on].
var _rec: Array = []
var _rec_sk: Skeleton3D
var _rec_thing: BendBolt


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
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = "fire"
	RingRules.rule_set_override = "classic"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(round(s * Engine.physics_ticks_per_second)))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _hold_foe() -> void:
	if foe == null or not is_instance_valid(foe):
		return
	foe.held = true
	if _foe_at == Vector3.INF:
		_foe_at = foe.global_position
	foe.global_position = _foe_at
	foe.velocity = Vector3.ZERO


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	p = lvl.player if lvl != null else null
	_expect(p != null and p.skeleton != null, "the ring, its player and his skeleton")
	if p == null or p.skeleton == null:
		return _end()
	p.ignore_mouse_capture = true
	c = SwayCaster.of(p)
	pbc = BendCaster.of(p)
	await _until(func() -> bool: return p.arena_element == "fire" and p.hotbar.spell != "", 6.0)
	rm = RingMode.find(self)
	if rm != null:
		await _until(func() -> bool: return rm.phase == "FIGHT", 10.0)
		foe = rm.foe
		rm.rules.soft_walls = false
	_expect(foe != null, "the foe")
	if foe == null:
		return _end()
	fbc = BendCaster.of(foe) as BodyBendCaster
	fbc.scatter_deg = 0.0
	fbc.lead = 0.0
	physics_frame.connect(_hold_foe)
	await _secs(0.4)
	await _parry_spin()
	await _wind_hands()
	await _bot_spin()
	_end()


func _end() -> void:
	if c != null:
		c.held_override = null
		c.guard_override = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	RingRules.rule_set_override = ""
	GameSettings.path = GameSettings.PATH
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


## The player whole and still 9 m before the foe facing him, as `el`, nothing bent about.
func _calm(el: String) -> void:
	c.held_override = false
	c.guard_override = false
	if p.arena_element != el:
		Bending.of(p).element = el
		await _until(func() -> bool: return p.arena_element == el, 3.0)
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormStone.GROUP, GustLift.GROUP]:
		for x in get_nodes_in_group(g):
			if is_instance_valid(x):
				x.queue_free()
	var axis := rm.ring.axis()
	var at := _foe_at - axis * signf(axis.dot(_foe_at - rm.ring.center())) * 9.0
	at.y = rm.ring.deck_y()
	var face := _foe_at - at
	face.y = 0.0
	RingLevel.place(p, Transform3D(Basis.looking_at(face.normalized(), Vector3.UP), at))
	p.velocity = Vector3.ZERO
	p.health = p.max_health
	fbc.target = p
	await _secs(0.4)


func _chest_of(n: Node3D) -> Vector3:
	return NpcSenses.chest_of(n) if n is NpcFighter else n.global_position + Vector3.UP * 1.3


## Shot `spec` from `from` at `to`'s chest, `d` m off.
func _shoot(by: Node3D, at: Node3D, spec: Dictionary, d: float) -> BendBolt:
	var dir := (_chest_of(at) - _chest_of(by)).normalized()
	return BendBolt.launch(by, _chest_of(at) - dir * d, dir, spec)


## The hips' line's heading on `sk`'s final pose (rad about the upright, skeleton space).
static func _hip_yaw(sk: Skeleton3D) -> float:
	var l := sk.get_bone_global_pose(sk.find_bone("l_upper_leg")).origin
	var r := sk.get_bone_global_pose(sk.find_bone("r_upper_leg")).origin
	return atan2(r.x - l.x, r.z - l.z)


func _on_updated() -> void:
	if _rec_sk == null or not is_instance_valid(_rec_sk):
		return
	var gs := _rec_sk.get_node_or_null(GuardSpin.NODE_NAME) as GuardSpin
	var ang := -1.0
	if _rec_thing != null and is_instance_valid(_rec_thing):
		var to_sk := _rec_sk.global_transform.affine_inverse()
		var sh := _rec_sk.get_bone_global_pose(_rec_sk.find_bone("r_shoulder")).origin
		var hand := _rec_sk.get_bone_global_pose(_rec_sk.find_bone("r_hand_prop_attachment")).origin
		var thing := to_sk * _rec_thing.global_position
		ang = rad_to_deg((hand - sh).angle_to(thing - sh))
	_rec.append([_hip_yaw(_rec_sk), gs.turn if gs != null else 0.0, gs.reach_w if gs != null else 0.0, ang,
			gs != null and gs.on, _rec_thing != null and is_instance_valid(_rec_thing) and _rec_thing.swinging(),
			_rec_thing.swing_u() if _rec_thing != null and is_instance_valid(_rec_thing) else -1.0])


func _record(sk: Skeleton3D, b: BendBolt) -> void:
	_rec = []
	_rec_sk = sk
	_rec_thing = b
	if not sk.skeleton_updated.is_connected(_on_updated):
		sk.skeleton_updated.connect(_on_updated)


func _stop_record() -> void:
	if _rec_sk != null and is_instance_valid(_rec_sk) and _rec_sk.skeleton_updated.is_connected(_on_updated):
		_rec_sk.skeleton_updated.disconnect(_on_updated)
	_rec_sk = null


## A wrapped angle's difference (rad, -PI..PI).
static func _wrap(a: float) -> float:
	return wrapf(a, -PI, PI)


# ---------------------------------------------------------------- the player's Parry
func _parry_spin() -> void:
	await _calm("fire")
	var sk := p.skeleton
	var base := _hip_yaw(sk)
	var body0 := p.global_basis
	var cam0: Transform3D = p.camera.global_transform if p.camera != null else Transform3D.IDENTITY
	var z := BendZone.make(p, "parry", p.global_position, PARRY, pbc.facing())
	await _secs(0.2)
	var b := _shoot(foe, p, FIRE, 3.1)
	_record(sk, b)
	var swung := await _until(func() -> bool: return is_instance_valid(b) and b.swinging(), 0.6)
	var gs := GuardSpin.of(p)
	_expect(swung < INF and z.results == ["perfect"] and gs != null and gs.on and gs.hands == "r",
			"a perfect Parry's moon: the GuardSpin on the player's skeleton, on, the lead hand only (%s %s)" % [z.results, gs.hands if gs != null else "-"])
	await _until(func() -> bool: return not is_instance_valid(b) or not b.swinging(), 1.0)
	var lap := _rec.filter(func(r: Array) -> bool: return bool(r[5]))
	await _secs(GuardSpin.FOLLOW_S + GuardSpin.BACK_S + 0.1)
	var after: Array = _rec.back() if not _rec.is_empty() else []
	_stop_record()
	# the turn: mid-lap about half a turn, the hips' heading off its own by the spin's turn; a whole turn over the lap
	var mid: Array = []
	for r: Array in lap:
		if float(r[6]) >= 0.45 and mid.is_empty():
			mid = r
	# (the hips off their own by the spin's turn give or take the Parry clip's own twist of the trunk: its yaw keys reach 24 deg)
	var mid_ok := not mid.is_empty() and absf(float(mid[1])) > deg_to_rad(120.0) \
			and absf(_wrap(float(mid[0]) - base - float(mid[1]))) < deg_to_rad(25.0)
	_expect(mid_ok, "mid-lap the body has turned with it (turn %.0f deg, the hips %.0f deg off their own)" % [
			rad_to_deg(float(mid[1])) if not mid.is_empty() else 0.0, rad_to_deg(_wrap(float(mid[0]) - base)) if not mid.is_empty() else 0.0])
	var swept := 0.0
	for i in range(1, lap.size()):
		swept += _wrap(float(lap[i][0]) - float(lap[i - 1][0]))
	var way := _wrap(float(lap.back()[0]) - float(lap.front()[0])) if lap.size() > 1 else 0.0
	_expect(absf(swept) > deg_to_rad(300.0) and swept < 0.0, "over the lap a whole turn, the fire's way round (%.0f deg)" % rad_to_deg(swept))
	# the hand after it mid-lap
	var reach_ok := not mid.is_empty() and float(mid[2]) > 0.9 and float(mid[3]) >= 0.0 and float(mid[3]) < 35.0
	_expect(reach_ok, "mid-lap his right hand reaches after it (weight %.2f, %.0f deg off the line to it)" % [
			float(mid[2]) if not mid.is_empty() else 0.0, float(mid[3]) if not mid.is_empty() else -1.0])
	# after: the spin off, nothing of it left on the body (the hips within the Parry clip's own recovery twist of their facing)
	var back_ok := not after.is_empty() and not bool(after[4]) and is_zero_approx(float(after[1])) and is_zero_approx(float(after[2])) \
			and absf(_wrap(float(after[0]) - base)) < deg_to_rad(25.0)
	_expect(back_ok, "after it leaves, the spin off and his body back on its own facing (%.1f deg, the clip's recovery)" % (
			rad_to_deg(_wrap(float(after[0]) - base)) if not after.is_empty() else 999.0))
	# visual only
	var cam_now: Transform3D = p.camera.global_transform if p.camera != null else Transform3D.IDENTITY
	_expect(p.global_basis.is_equal_approx(body0) and cam_now.is_equal_approx(cam0),
			"visual only: his body's facing and his camera untouched (%s)" % way)


# ---------------------------------------------------------------- the Wind Guard: both hands
func _wind_hands() -> void:
	await _calm("air")
	var z := BendZone.make(p, "air_shield", p.global_position, WIND, pbc.facing())
	await _secs(0.2)
	var b := _shoot(foe, p, AIR, 2.8)
	var swung := await _until(func() -> bool: return is_instance_valid(b) and b.swinging(), 0.6)
	var gs := GuardSpin.of(p)
	_expect(swung < INF and z.results == ["perfect"] and gs != null and gs.on and gs.hands == "both",
			"a perfect Wind Guard's moon: both hands after it (%s %s)" % [z.results, gs.hands if gs != null else "-"])
	await _secs(BendZone.MOON_S + GuardSpin.FOLLOW_S + GuardSpin.BACK_S + 0.2)
	_expect(gs != null and not gs.on and is_zero_approx(gs.turn), "and off again after (turn %.2f)" % (gs.turn if gs != null else 9.0))


# ---------------------------------------------------------------- a bot's Parry
func _bot_spin() -> void:
	await _calm("fire")
	var nb := foe.body
	_expect(nb != null and nb.sk != null, "the foe's body and skeleton")
	if nb == null or nb.sk == null:
		return
	var z := BendZone.make(foe, "parry", foe.global_position, PARRY, -foe.global_basis.z)
	await _secs(0.2)
	var b := _shoot(p, foe, FIRE, 3.1)
	var swung := await _until(func() -> bool: return is_instance_valid(b) and b.swinging(), 0.6)
	await _secs(BendZone.MOON_S * 0.5)
	var gs := GuardSpin.of(foe)
	var turning := gs != null and gs.on and absf(gs.turn) > deg_to_rad(90.0)
	_expect(swung < INF and z.results == ["perfect"] and turning,
			"a bot's perfect Parry turns his body with it too (%s, turn %.0f deg)" % [z.results, rad_to_deg(gs.turn) if gs != null else 0.0])
	await _secs(BendZone.MOON_S + GuardSpin.FOLLOW_S + GuardSpin.BACK_S + 0.2)
