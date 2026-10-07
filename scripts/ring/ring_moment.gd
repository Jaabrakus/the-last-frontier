class_name RingMoment
extends Node
## The ring-out moment (round 4, IMPACT; the owner's "ring-out moment (the splash)"; numbers in data/ring/feel.json). Made by
## BendImpact on first use under a ring (a child of RingRules: it goes with the ring's scene), it listens to RingRules.ko
## (the % game) or, under the classic rules, to rang_out:
##   every fall    RingWater.ko_splash where he went in (a water column from his entry speed, the spray sheets, the ripple,
##                 the foam; ringout_splash at +3 dB over a low knock_thud), the local player's view jolted (ko_amount) when
##                 the fall is within ko_near_m of him. Play goes on: no slow beat on a fall that is not the last.
##   the last one  a game's last fall (the fallen side has no one left in: its last life; or any fall in sudden death):
##                 Engine.time_scale eases to slow_scale over ease_in_s, holds hold_real_s of REAL time, comes back over
##                 ease_out_s; the splash at final_splash_k (twice its size). busy() while it runs: the RoundScreen and the
##                 MatchScreen wait for it (RingMode's own "Over" waits over_s of game time, longer than the moment).
##   always back   the time scale is put back (to what it was: a soak's ts 4 stays 4) when the moment ends, on the scene's
##                 exit, on RingMode's restart (its COUNTDOWN), through an Esc pause (the tree paused: ended at once) and on
##                 a second fall during it (ended, no new one).
##   Practice      no moment, no jolt (feel.json moment.practice_moment / practice_jolt); the splash only.
##   classic       the same splash on a rang_out, nothing else.
## Real time is the frames' unscaled time (process delta / time_scale): the wall's in play, frames / fps in a fixed-fps test.
## Where and how fast he went in: RingRules' falls record (his place at the fall; RingMode hides him at his spout as it hears
## of it) and his velocity as last seen each physics step here (the hiding zeroes it).

## The moments run (tests), the falls seen, and the time scale's lowest in the last moment.
var moments := 0
var falls := 0
var lowest_scale := 1.0
## The moment running now, its real seconds so far, and the time scale it found (put back after).
var active := false
var real_t := 0.0
var _ts0 := 1.0
var rules: RingRules
var _match: Node
## Each competitor's velocity as last seen (instance id -> Vector3).
var _vel := {}

static var _cur: RingMoment = null


## The moment of `rr` (made under it on first call).
static func ensure(rr: RingRules) -> RingMoment:
	if rr == null or not is_instance_valid(rr):
		return null
	if _cur != null and is_instance_valid(_cur) and _cur.rules == rr and _cur.is_inside_tree():
		return _cur
	var m := rr.get_node_or_null(^"RingMoment") as RingMoment
	if m == null:
		m = RingMoment.new()
		m.name = "RingMoment"
		m.rules = rr
		rr.add_child(m)
	_cur = m
	return m


## The ring's moment now, or null.
static func current() -> RingMoment:
	return _cur if _cur != null and is_instance_valid(_cur) and _cur.is_inside_tree() else null


## A slow beat runs now (the screens wait for it).
static func busy() -> bool:
	var m := current()
	return m != null and m.active


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if rules == null:
		rules = get_parent() as RingRules
	if rules == null:
		return
	if rules.rule_set == "stock":
		rules.ko.connect(_on_ko)
	else:
		rules.rang_out.connect(_on_rang_out)
	_match = get_tree().get_first_node_in_group(&"ring_match")
	if _match != null and _match.has_signal(&"phase_changed"):
		_match.connect(&"phase_changed", _on_phase)


func _exit_tree() -> void:
	end()
	if _cur == self:
		_cur = null


## RingRules.ko (stock): the splash, the jolt, the slow beat on a game's last fall.
func _on_ko(b: Node3D, _by: Node, _pct: float, _tag: String, left: int) -> void:
	if not BendImpact.on() or b == null or not is_instance_valid(b):
		return
	falls += 1
	var second := active
	if active:
		end()                               # (a second fall during the moment: put back, no new one)
	var practice := _practice()
	var last := not practice and _final(b, left)
	var slow := last or bool(BendImpact.block("moment").get("every_fall_slow", false))
	if practice:
		slow = slow and bool(BendImpact.block("moment").get("practice_moment", false))
	var k := BendImpact.num("moment", "final_splash_k", 2.0) if last else 1.0
	_splash(b, k)
	if not practice or bool(BendImpact.block("moment").get("practice_jolt", false)):
		_jolt(b, _ko_at(b))
	if slow and not second:
		begin()


## RingRules.rang_out (classic rules): the same splash, nothing else.
func _on_rang_out(who: Node3D, _by: Node) -> void:
	if not BendImpact.on() or who == null or not is_instance_valid(who):
		return
	falls += 1
	_splash(who, 1.0)


## A game's last fall: the fallen one's side has no one left in (his last life), or sudden death.
func _final(b: Node3D, left: int) -> bool:
	if rules.sudden:
		return true
	if left > 0:
		return false
	var t := rules.team_of(b)
	if t < 0 or t >= rules.sides.size():
		return true
	for o: Variant in rules.sides[t]:
		if o is Node and is_instance_valid(o) and o != b and not rules.is_gone(o as Node):
			return false
	return true


func _practice() -> bool:
	if _match != null and is_instance_valid(_match):
		return bool(_match.get(&"practice"))
	return not rules.lives_on


func _splash(b: Node3D, k: float) -> void:
	var ring := rules.ring
	if ring == null or not is_instance_valid(ring) or ring.water == null:
		return
	var at := _ko_at(b)
	var v: Vector3 = _vel.get(b.get_instance_id(), (b as CharacterBody3D).velocity if b is CharacterBody3D else Vector3.ZERO)
	var sp := v.length() if v.length() > 0.5 else 10.0
	ring.water.ko_splash(at, sp, k)


func _physics_process(_dt: float) -> void:
	if rules == null or not is_instance_valid(rules):
		return
	for side: Array in rules.sides:
		for b: Variant in side:
			if b is CharacterBody3D and is_instance_valid(b) and (b as Node3D).visible:
				_vel[(b as Node).get_instance_id()] = (b as CharacterBody3D).velocity


## Where `b` went in: RingRules' record of the fall (RingMode has already hidden him at his spout), else where he is.
func _ko_at(b: Node3D) -> Vector3:
	if not rules.falls.is_empty() and (rules.falls.back() as Dictionary).get("who") == b:
		return (rules.falls.back() as Dictionary).get("pos", b.global_position)
	return b.global_position


## The local player's view jolted by a fall at `at` within ko_near_m of him (his own fall: always).
func _jolt(b: Node3D, at: Vector3) -> void:
	var t := get_tree()
	for n in t.get_nodes_in_group(&"player"):
		var p := n as FrontierPlayer
		if p == null or not p.is_local or p.camera == null:
			continue
		if p == b or p.global_position.distance_to(at) <= BendImpact.num("jolt", "ko_near_m", 30.0):
			BendImpact.jolt_player(p, BendImpact.num("jolt", "ko_amount", 0.3), BendImpact.num("jolt", "ko_secs", 0.35))


# ---------------------------------------------------------------- the slow beat
## The slow beat begun now (see the header).
func begin() -> void:
	if active:
		return
	active = true
	real_t = 0.0
	_ts0 = Engine.time_scale
	lowest_scale = _ts0
	moments += 1


## The slow beat over: the time scale put back.
func end() -> void:
	if not active:
		return
	active = false
	Engine.time_scale = _ts0


## The time scale's share of what it was, `rt` real seconds into the moment (1 at its end).
static func scale_at(rt: float) -> float:
	var lo := BendImpact.num("moment", "slow_scale", 0.35)
	var a := BendImpact.num("moment", "ease_in_s", 0.08)
	var h := BendImpact.num("moment", "hold_real_s", 0.6)
	var b := BendImpact.num("moment", "ease_out_s", 0.25)
	if rt < a:
		return lerpf(1.0, lo, smoothstep(0.0, 1.0, rt / maxf(a, 1e-4)))
	if rt < a + h:
		return lo
	if rt < a + h + b:
		return lerpf(lo, 1.0, smoothstep(0.0, 1.0, (rt - a - h) / maxf(b, 1e-4)))
	return 1.0


## The moment's whole length (real s).
static func length_s() -> float:
	return BendImpact.num("moment", "ease_in_s", 0.08) + BendImpact.num("moment", "hold_real_s", 0.6) \
			+ BendImpact.num("moment", "ease_out_s", 0.25)


func _process(dt: float) -> void:
	if not active:
		return
	if get_tree().paused:
		end()                               # (the Esc pause: the menus at the game's pace, the beat given up)
		return
	var ts := Engine.time_scale
	real_t += dt / ts if ts > 1e-4 else dt
	if real_t >= length_s():
		end()
		return
	Engine.time_scale = _ts0 * scale_at(real_t)
	lowest_scale = minf(lowest_scale, Engine.time_scale)


## RingMode's phases: a new countdown (a restart, the next game) puts the time back at once.
func _on_phase(ph: String) -> void:
	if ph == "COUNTDOWN":
		end()
