class_name BendImpact
extends RefCounted
## Hits with weight (round 4, IMPACT; the owner chose these FEEL items: "hit-stop, camera kick, and a ring-out moment"). Only
## in a stock-rules ring (RingRules.stock_on(): the % game, Practice too); the open world, the duel and the classic ring never
## hold or jolt (their knocks never come here), and the classic ring gets only the KO splash on a rang_out (RingMoment).
## Every number in data/ring/feel.json; `enabled` false there (or enabled_override) turns all of it off.
##
##   the hold      BendKnock._stock_knock asks on_hit(n, v, by, info, hitstun_s) where a launch is applied: hold_s =
##                 lerp(hold_min, hold_max, clamp((|v| - lo_mps) / span_mps)), never more than hold_share of the hit's
##                 hitstun, none under stop_min_mps. The struck one's pose holds hold_s (pose_rate 0: PlayerAnim's tick and
##                 NpcBody's step advance by dt x pose_rate) and his launch waits it out (BendKnock keeps it pending,
##                 INSIDE his hitstun, which still counts from the hit: his first free frame, his steer, his fall's window
##                 and the 0.6 s escape stay where they were; the flight is the same flight started hold_s later, so the KO
##                 % does not move; RingPredict.flight adds the hold to its time). The hitter's pose holds too, only when he
##                 was within melee_m of the struck one (the jab string, the Pop, the Slam, kicks: a bolt landing 15 m away
##                 holds nothing on its caster). Nobody's movement, aim, camera or lock ever waits: for the player nothing
##                 but his pose (spec §3: a hit never touches the camera's turn, the aim or the lock). knock_thud plays at the
##                 hold's start, its pitch and gain from |v|. Nothing is drawn on anyone. Round 5 (CLIPWIRE): the held pose
##                 is the struck contact pose (own-bend-hit-impact-<side>, by where the hit came from: see "the struck pose"),
##                 on the player's visible ring pose too (SwayPose holds by pose_rate as PlayerAnim does).
##   the jolt      the owner's "camera kick" is CameraShake.jolt: an offset jolt of the view (h_offset, v_offset) that never
##                 turns the camera, so the aim never moves (kick() and sustain() turn it: never used for a hit). The local
##                 player's view jolts when he takes a launch of take_min_mps or more, when he lands one of deal_min_mps or
##                 more (deal_k of it), on a fall into the water within ko_near_m, and on his perfect guard; a hit's jolt
##                 starts on the hold's last frame, so it lands with the release. Off with the Esc row (GameSettings
##                 [ring] jolt, READ's row; read here only) or feel.json jolt.on; never in Practice (practice_jolt).
##   the beat      a competitor's perfect guard (BendCaster.guarded "perfect", told by BendZone.report): his pose holds
##                 perfect.hold_s, and the sender's (the nearest foe within perfect.sender_m: the signal does not name him),
##                 the guarder's view jolts if he is the player. Round 2's flash and crack stay. A late guard and a whiff get
##                 nothing new. The catch never waits: only poses hold, so a perfect Catch's stone, its E-return and the
##                 stone's flight are on the same frames as without the beat.
##   the moment    RingMoment, made here on first use under a ring (see its header): the KO splash on every fall, the slow
##                 beat on a game's last.
## tick() runs at the start of each physics step (BendStatus' clock, right after it advances): the pending launches let go,
## the pending jolts started, the ring's hooks kept.

const FEEL_PATH := "res://data/ring/feel.json"
## A body's pose held until this game time (BendStatus.now()): pose_rate 0 before it.
const HOLD_META := &"bend_pose_hold_until"
## A competitor whose BendCaster.guarded is heard here.
const HOOK_META := &"bend_impact_hooked"
## The pose time a held body still owes (s): made up after the hold (pose_rate).
const OWE_META := &"bend_pose_owed"

## Tests: true / false forces the feel on / off (null: feel.json `enabled`).
static var enabled_override: Variant = null
## Tests: true / false forces the jolt's setting (null: GameSettings [ring] jolt, default on).
static var jolt_override: Variant = null
## Counted for the tests and the review: holds given (struck, hitter, guard), jolts started, the last hold (s).
static var holds := 0
static var hitter_holds := 0
static var guard_holds := 0
static var jolts := 0
static var last_hold_s := 0.0
static var last_jolt := {}

static var _data := {}
## Pending launches: BendKnocks holding one (weak refs).
static var _knocks: Array = []
## Pending jolts: [at (game s), camera (weak ref), amount, secs, dir].
static var _jolts: Array = []
static var _ring_check := 0
static var _jolt_setting := true
static var _jolt_read_ms := -100000


# ---------------------------------------------------------------- the data
static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(FEEL_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_data = d
		if _data.is_empty():
			_data = {"enabled": false}
	return _data


static func block(key: String) -> Dictionary:
	var b: Variant = data().get(key, {})
	return b if b is Dictionary else {}


static func num(blk: String, key: String, def := 0.0) -> float:
	return float(block(blk).get(key, def))


## A [lo, hi] pair of feel.json (or def).
static func pair(blk: String, key: String, def: Vector2) -> Vector2:
	var a: Variant = block(blk).get(key, null)
	if a is Array and (a as Array).size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return def


## The feel is on (feel.json `enabled`, or the tests' override).
static func on() -> bool:
	if enabled_override != null:
		return bool(enabled_override)
	return bool(data().get("enabled", true))


# ---------------------------------------------------------------- the hold
## The hold (s) for a launch of `mps` m/s with `hitstun_s` of hitstun (0: none).
static func hold_for(mps: float, hitstun_s: float) -> float:
	if not on() or mps < num("hitstop", "stop_min_mps", 4.0):
		return 0.0
	var k := clampf((mps - num("hitstop", "lo_mps", 4.0)) / maxf(num("hitstop", "span_mps", 14.0), 0.01), 0.0, 1.0)
	var s := lerpf(num("hitstop", "hold_min_s", 0.04), num("hitstop", "hold_max_s", 0.11), k)
	return maxf(minf(s, num("hitstop", "hold_share", 0.4) * maxf(hitstun_s, 0.0)), 0.0)


## A launch applied to `n` (BendKnock._stock_knock): `v` the launch, `by` the hitter, `info` the hit's, `hitstun_s` its stun.
## The poses held, the thud, the jolts set for the hold's last frame. Returns the hold (s): BendKnock keeps the launch's motion
## pending that long. 0: none (feel off, a soft hit, the gate off).
static func on_hit(n: Node, v: Vector3, by: Node, _info: Dictionary, hitstun_s: float) -> float:
	if not RingRules.stock_on() or n == null or not is_instance_valid(n):
		return 0.0
	_ensure_ring(n)
	var mps := v.length()
	var hold := hold_for(mps, hitstun_s)
	if hold <= 0.0:
		return 0.0
	var now := BendStatus.now()
	last_hold_s = hold
	holds += 1
	pose_hold(n, hold)
	_strike_pose(n, v, by, _info, hold)
	if by != null and is_instance_valid(by) and by != n and by is Node3D and n is Node3D \
			and (by as Node3D).global_position.distance_to((n as Node3D).global_position) <= num("hitstop", "melee_m", 3.0):
		pose_hold(by, hold)
		hitter_holds += 1
	# the thud at the hold's start: harder is louder and lower
	var k := clampf((mps - num("hitstop", "lo_mps", 4.0)) / maxf(num("hitstop", "span_mps", 14.0), 0.01), 0.0, 1.0)
	var at := (n as Node3D).global_position + Vector3.UP if n is Node3D else Vector3.INF
	BendSounds.play(&"knock_thud", at, lerpf(num("hitstop", "thud_db_lo", -6.0), num("hitstop", "thud_db_hi", 2.0), k),
			lerpf(num("hitstop", "thud_pitch_lo", 1.12), num("hitstop", "thud_pitch_hi", 0.82), k))
	# the jolts, on the hold's last frame (they land with the release)
	var at_t := now + maxf(hold - 1.0 / float(Engine.physics_ticks_per_second), 0.0)
	var take := mps >= num("jolt", "take_min_mps", 6.0)
	var deal := mps >= num("jolt", "deal_min_mps", 9.0)
	if take or deal:
		var jk := clampf((mps - num("jolt", "take_min_mps", 6.0)) / maxf(num("jolt", "take_full_mps", 18.0) - num("jolt", "take_min_mps", 6.0), 0.01), 0.0, 1.0)
		var amt := lerpf(pair("jolt", "take_amount", Vector2(0.12, 0.35)).x, pair("jolt", "take_amount", Vector2(0.12, 0.35)).y, jk)
		var secs := lerpf(pair("jolt", "take_secs", Vector2(0.18, 0.3)).x, pair("jolt", "take_secs", Vector2(0.18, 0.3)).y, jk)
		if take and _is_local(n):
			_queue_jolt(at_t, (n as FrontierPlayer).camera, amt, secs, v)
		if deal and by != n and _is_local(by):
			var dk := num("jolt", "deal_k", 0.5)
			_queue_jolt(at_t, (by as FrontierPlayer).camera, amt * dk, secs * lerpf(1.0, dk, 0.5), v)
	return hold


## `b`'s pose held for `s` (game s) from now (the longer of it and a hold already running).
static func pose_hold(b: Node, s: float) -> void:
	if b == null or not is_instance_valid(b) or s <= 0.0:
		return
	var until := BendStatus.now() + s
	b.set_meta(HOLD_META, maxf(until, float(b.get_meta(HOLD_META, -INF))))


## The rate `b`'s pose advances at now, for a step of `dt` (PlayerAnim's tick and NpcBody's step multiply their dt by it):
## 0 while held; then, the hold over, faster (hitstop.catchup_k) until the pose has made up the time it stood still (OWE_META,
## counted from the dt it was given), so it is back in step with the body: what is timed by the pose (the player's strike
## point a cast leaves from, a fighter's hit parts) is where it would have been without the hold (a perfect Catch's return
## leaves from the same place). Else 1. A body never held carries no meta: 1, with nothing read.
static func pose_rate(b: Node, dt := 0.0) -> float:
	if b == null or not b.has_meta(HOLD_META):
		return 1.0
	if BendStatus.now() < float(b.get_meta(HOLD_META)) - 1e-6:
		if dt > 0.0:
			b.set_meta(OWE_META, float(b.get_meta(OWE_META, 0.0)) + dt)
		return 0.0
	var owed := float(b.get_meta(OWE_META, 0.0))
	if owed <= 1e-6 or dt <= 0.0:
		b.remove_meta(HOLD_META)
		if b.has_meta(OWE_META):
			b.remove_meta(OWE_META)
		return 1.0
	var extra := minf(owed, maxf(num("hitstop", "catchup_k", 2.0) - 1.0, 0.0) * dt)
	owed -= extra
	if owed <= 1e-6:
		b.remove_meta(HOLD_META)
		b.remove_meta(OWE_META)
	else:
		b.set_meta(OWE_META, owed)
	return 1.0 + extra / dt


# ---------------------------------------------------------------- the struck pose (round 5, CLIPWIRE)
## The struck one's contact pose shown through the hold (the animation lane's own clips own-bend-hit-impact-<side>, named
## in movement.json clips struck_<side>): the side the hit came from against the way he faces (struck_side), recorded on
## him (STRUCK_META {clip, side, at, until}: the player's SwayPose lays it over every layer, at the clip's hold_s, the
## contact, while the hold stands, then plays its recoil out into the tumble or the flinch) and handed at once to a body
## that shows its own (NpcBody.show_struck: the same pose, the knock's and the flinch's clips waiting behind it). Poses
## only, as the hold: never the motion, the aim, the camera or the lock. Only where a hold is given (the gate, the feel on).
const STRUCK_META := &"bend_struck"
## Counted for the tests: struck poses given, and the last one's side.
static var struck_shown := 0
static var last_struck_side := ""


## Where a hit of launch `v` on `n` came from against the way `n` faces: "front", "back", "left" or "right" (the struck
## body recoils along the launch, so the hit came from against it; a launch near straight up or down: from the hit's origin,
## info.from, else the hitter's place; nothing known: "front").
static func struck_side(n: Node3D, v: Vector3, by: Node = null, info := {}) -> String:
	var from := -Vector3(v.x, 0.0, v.z)
	if from.length() < 0.5:
		var src := Vector3.INF
		var f: Variant = info.get("from", null)
		if f is Vector3 and (f as Vector3) != Vector3.ZERO:
			src = f
		elif by is Node3D and is_instance_valid(by) and by != n:
			src = (by as Node3D).global_position
		if src != Vector3.INF:
			from = src - n.global_position
			from.y = 0.0
	if from.length() < 1e-3:
		return "front"
	var fwd := -n.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP)
	var a := rad_to_deg(atan2(from.dot(right), from.dot(fwd)))
	if absf(a) <= 45.0:
		return "front"
	if absf(a) >= 135.0:
		return "back"
	return "right" if a > 0.0 else "left"


## The struck pose for the hit on `n` (see above): recorded, and shown at once by a body with its own (a bot's NpcBody).
static func _strike_pose(n: Node, v: Vector3, by: Node, info: Dictionary, hold: float) -> void:
	if not (n is Node3D):
		return
	var side := struck_side(n as Node3D, v, by, info)
	var nm := String(RingMoves.clip_for("struck_" + side)[0])
	if nm == "":
		return
	var now := BendStatus.now()
	n.set_meta(STRUCK_META, {"clip": nm, "side": side, "at": now, "until": now + hold})
	struck_shown += 1
	last_struck_side = side
	var body: Variant = n.get(&"body")
	if body is Object and is_instance_valid(body) and (body as Object).has_method(&"show_struck"):
		(body as Object).call(&"show_struck", nm)


## The struck pose recorded on `b` ({} none): {clip, side, at, until} (game s).
static func struck_of(b: Node) -> Dictionary:
	if b == null or not is_instance_valid(b) or not b.has_meta(STRUCK_META):
		return {}
	var d: Variant = b.get_meta(STRUCK_META)
	return d if d is Dictionary else {}


## Round 4 (VIRAL's clash beat, BendClash): `body`'s pose held `secs` (game s), only in the % ring with the feel on. Poses
## only: never the camera, the aim, the lock or the motion.
static func hold(body: Node, secs: float) -> void:
	if not on() or not RingRules.stock_on():
		return
	pose_hold(body, secs)


## Whether `b`'s pose is held now (tests, the review).
static func held(b: Node) -> bool:
	return b != null and is_instance_valid(b) and b.has_meta(HOLD_META) and BendStatus.now() < float(b.get_meta(HOLD_META)) - 1e-6


## A BendKnock holding a launch: let go by tick() when its hold ends.
static func track(k: Node) -> void:
	for w: WeakRef in _knocks:
		if w.get_ref() == k:
			return
	_knocks.append(weakref(k))


# ---------------------------------------------------------------- the jolt
## The jolt's switches: feel on, feel.json jolt.on, the Esc row (GameSettings [ring] jolt: READ's; read at most once a
## second), never in Practice.
static func jolt_allowed() -> bool:
	if not on() or not bool(block("jolt").get("on", true)):
		return false
	if _practice() and not bool(block("moment").get("practice_jolt", false)):
		return false
	if jolt_override != null:
		return bool(jolt_override)
	var ms := Time.get_ticks_msec()
	if ms - _jolt_read_ms > 1000:
		_jolt_read_ms = ms
		var cf := ConfigFile.new()
		cf.load(GameSettings.file())
		_jolt_setting = bool(cf.get_value("ring", "jolt", true))
	return _jolt_setting


## The local player's view jolted by `amount` m over `secs` along `world_dir` (seen on his screen; ZERO: down).
static func jolt_player(p: Node, amount: float, secs: float, world_dir := Vector3.ZERO) -> void:
	if not _is_local(p):
		return
	_queue_jolt(BendStatus.now(), (p as FrontierPlayer).camera, amount, secs, world_dir)


static func _queue_jolt(at: float, cam: Camera3D, amount: float, secs: float, world_dir: Vector3) -> void:
	if cam == null or not is_instance_valid(cam) or amount <= 0.0 or not jolt_allowed():
		return
	_jolts.append([at, weakref(cam), amount, secs, world_dir])
	if at <= BendStatus.now() + 1e-6:
		_fire_jolts(BendStatus.now())


static func _fire_jolts(now: float) -> void:
	var i := 0
	while i < _jolts.size():
		var j: Array = _jolts[i]
		if float(j[0]) > now + 1e-6:
			i += 1
			continue
		_jolts.remove_at(i)
		var cam := (j[1] as WeakRef).get_ref() as Camera3D
		if cam == null or not cam.is_inside_tree():
			continue
		var wd: Vector3 = j[4]
		var d := Vector2(0.0, -1.0)
		if wd.length_squared() > 1e-6:
			# (the launch's way as the screen sees it: the view knocked along it)
			var sd := Vector2(wd.dot(cam.global_basis.x), wd.dot(cam.global_basis.y))
			if sd.length() > 0.05:
				d = sd.normalized()
		CameraShake.of(cam).jolt(float(j[2]), float(j[3]), d)
		jolts += 1
		last_jolt = {"amount": float(j[2]), "secs": float(j[3]), "at": now}


# ---------------------------------------------------------------- each step
## The start of each physics step (BendStatus' clock): the held launches let go, the jolts due started, the ring's hooks.
static func tick() -> void:
	var now := BendStatus.now()
	if not _knocks.is_empty():
		var i := 0
		while i < _knocks.size():
			var k := (_knocks[i] as WeakRef).get_ref() as BendKnock
			if k == null or not is_instance_valid(k) or k.release_due(now):
				_knocks.remove_at(i)
				continue
			i += 1
	if not _jolts.is_empty():
		_fire_jolts(now)
	_ring_check -= 1
	if _ring_check <= 0:
		_ring_check = 20
		var rr := RingRules.current()
		if rr != null and is_instance_valid(rr) and rr.is_inside_tree():
			_ensure_ring(rr)


## The ring's hooks: RingMoment (the KO splash; the slow beat under stock rules), every competitor's guard heard.
static func _ensure_ring(_from: Node) -> void:
	var rr := RingRules.current()
	if rr == null or not is_instance_valid(rr) or not rr.is_inside_tree():
		return
	RingMoment.ensure(rr)
	if not RingRules.stock_on():
		return
	for side: Array in rr.sides:
		for b: Variant in side:
			if not (b is Node) or not is_instance_valid(b):
				continue
			if (b as Node).has_meta(HOOK_META):
				continue
			var bc := BendCaster.of(b as Node)
			if bc == null:
				continue
			(b as Node).set_meta(HOOK_META, true)
			bc.guarded.connect(_on_guarded.bind(weakref(b)))


## A competitor's guard told its result (BendZone.report): the perfect one's beat (see the header).
static func _on_guarded(result: String, _what: String, who: WeakRef) -> void:
	if result != "perfect" or not on() or not RingRules.stock_on():
		return
	var g := who.get_ref() as Node3D
	if g == null or not is_instance_valid(g):
		return
	var rr := RingRules.current()
	if rr == null or rr.team_of(g) < 0:
		return
	var hs := num("perfect", "hold_s", 0.07)
	pose_hold(g, hs)
	guard_holds += 1
	# the sender: the nearest foe within sender_m (the signal does not name him; in a 1 v 1 it is the other one)
	var best: Node3D = null
	var bd := num("perfect", "sender_m", 6.0)
	for side: Array in rr.sides:
		for b: Variant in side:
			if not (b is Node3D) or not is_instance_valid(b) or b == g or rr.team_of(b as Node) == rr.team_of(g):
				continue
			var d := (b as Node3D).global_position.distance_to(g.global_position)
			if d <= bd:
				bd = d
				best = b as Node3D
	if best != null:
		pose_hold(best, hs)
	if _is_local(g):
		jolt_player(g, num("jolt", "perfect_amount", 0.12), num("jolt", "perfect_secs", 0.18))


# ---------------------------------------------------------------- helpers
static func _is_local(n: Variant) -> bool:
	return n != null and is_instance_valid(n) and n is FrontierPlayer and (n as FrontierPlayer).is_local \
			and (n as FrontierPlayer).camera != null


## The ring plays Practice (RingMode's `practice`, else RingRules' lives off).
static func _practice() -> bool:
	var t := Engine.get_main_loop() as SceneTree
	var m: Node = t.get_first_node_in_group(&"ring_match") if t != null else null
	if m != null:
		return bool(m.get(&"practice"))
	var rr := RingRules.current()
	return rr != null and not rr.lives_on


## Everything pending dropped and the counts nil (tests).
static func reset() -> void:
	_knocks.clear()
	_jolts.clear()
	holds = 0
	hitter_holds = 0
	guard_holds = 0
	jolts = 0
	last_hold_s = 0.0
	last_jolt = {}
	_jolt_read_ms = -100000
	struck_shown = 0
	last_struck_side = ""
