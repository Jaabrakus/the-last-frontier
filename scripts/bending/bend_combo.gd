class_name BendCombo
extends RefCounted
## The combo and the guard's gauge on the new ring (RingRules.stock_on: Lives and Zones; the owner, 2026-10-12: "a combo meter
## every successful parry", "successful hit adds to the combo meter", "each successfull hit they can cast faster ... with a
## limit", "the parry be power metter gauge each e press uses it and hold it drains it", "dont forget the E gauge so no one can
## spam it"; picked: 5 stacks lost when hit, guard break). Every number in rules.json stock.combo and stock.guard_gauge.
##   the combo   a gauge (the owner, later: "on the cursor like a gauge that fills up with each succefull action", "and it
##               drains"): a body's hit that lands (RingRules.on_hit: past the spawn safety and any guard, once a volley,
##               never a tick) and its perfect guard (BendStatus.parry_reward) each fill a stack's worth, up to combo.max;
##               grace_s after the last it drains drain_s stacks a second; its level fills combo.fill a stack of every lock
##               of his as it begins (head_start: SwayCaster's lock), a hit landing mid-lock that much more (gain); a hit he
##               takes empties it. Drawn round the crosshair
##               (SwayRing: the left bracket; the gauge the right one while his guard stands)
##   the gauge   0..1, full at first: a guard standing costs gauge.tap (BendZone.make), held past its own window it drains
##               drain_s a second (BendZone's frame); off the guard refill_after_s it refills refill_s a second. Empty: the
##               guard breaks (ended, the guarder in hitstun stagger_s) and no guard rises again (SwayCaster._guard_waits,
##               NpcBending.begin) until the gauge is back at back_at
## Kept on the body (COMBO_META, GAUGE_META), worked out lazily from BendStatus.now(): no tick of its own.

const COMBO_META := &"bend_combo"
const GAUGE_META := &"bend_guard_gauge"
## When `n`'s guard last broke (BendStatus.now()).
const BROKE_META := &"bend_guard_broke"


## Tests of other rules (a guard's timing, a lock's length, a talent's beat) switch both meters off: their guards come back to
## back and their locks are measured to the hundredth (tests/ring/test_combo_gauge.gd has these).
static var enabled := true


static func on() -> bool:
	return enabled and RingRules.stock_on()


static func _num(block: String, key: String, def: float) -> float:
	return float(RingRules.stock_block(block).get(key, def))


# ---------------------------------------------------------------- the combo
## `n`'s combo now, in stacks (0..combo.max, drained since its last gain; 0 off the new ring).
static func level(n: Node) -> float:
	if n == null or not is_instance_valid(n) or not n.has_meta(COMBO_META) or not on():
		return 0.0
	var c: Dictionary = n.get_meta(COMBO_META)
	var idle := BendStatus.now() - float(c.get("at", -INF)) - _num("combo", "grace_s", 1.0)
	return maxf(float(c.get("n", 0.0)) - maxf(idle, 0.0) * _num("combo", "drain_s", 0.8), 0.0)


## Its whole stacks (the level rounded up: a stack draining still counts as one).
static func stacks(n: Node) -> int:
	return int(ceil(level(n) - 1e-3))


## A stack's worth more for `n` (a hit of his landed, a perfect guard of his), up to combo.max; a lock of his running now
## fills combo.fill more at once (its ring jumps: the owner, 2026-10-13, "fill the cast time fuller"), at the max too.
static func gain(n: Node) -> void:
	if n == null or not is_instance_valid(n) or not on():
		return
	var k := minf(level(n) + 1.0, _num("combo", "max", 5.0))
	n.set_meta(COMBO_META, {"n": k, "at": BendStatus.now()})
	var bump := _num("combo", "fill", 0.0)
	var c := SwayCaster.of(n)
	if bump > 0.0 and c != null and c.state == SwayCaster.State.LOCKING:
		c.fill = minf(c.fill + bump, 1.0)


## `n`'s stacks gone (a hit taken; a round's start).
static func lose(n: Node) -> void:
	if n != null and is_instance_valid(n) and n.has_meta(COMBO_META):
		n.remove_meta(COMBO_META)


## The share of its lock time `n`'s casts take for its combo (1 none): combo.per a stack, the level as it drains (0 since
## 2026-10-13: the combo fills his locks instead, head_start).
static func cast_share(n: Node) -> float:
	return 1.0 - _num("combo", "per", 0.0) * level(n)


## How full `n`'s locks begin for his combo (SwayCaster's lock: a head start, its ring begun fuller): combo.fill a stack, the
## level as it drains, never past HEAD_MAX.
const HEAD_MAX := 0.9
static func head_start(n: Node) -> float:
	return clampf(_num("combo", "fill", 0.0) * level(n), 0.0, HEAD_MAX)


## A hit of `by` on `n` landed (RingRules.on_hit; its own judgement of what counts): his stack, `n`'s all gone.
static func landed(by: Node, n: Node) -> void:
	lose(n)
	if by != null and is_instance_valid(by) and by != n and not BendCaster.same_team(by, n):
		gain(by)


# ---------------------------------------------------------------- the guard's gauge
## `n`'s gauge state brought up to now: {g (0..1), at, up (guards standing), down_at, broken}.
static func _gauge(n: Node) -> Dictionary:
	var now := BendStatus.now()
	var st: Dictionary = n.get_meta(GAUGE_META) if n.has_meta(GAUGE_META) else {"g": 1.0, "at": now, "up": 0, "down_at": -INF, "broken": false}
	var t0 := float(st.at)
	# (a guard counts as up while its frames still tick: one freed without its end() never stops the refill)
	var up := int(st.up) > 0 and now - float(st.get("tick_at", -INF)) < 0.25
	if not up and int(st.up) > 0:
		st["up"] = 0
		st["down_at"] = maxf(float(st.down_at), float(st.get("tick_at", -INF)))
	if not up and now > t0:
		var from := maxf(t0, float(st.down_at) + _num("guard_gauge", "refill_after_s", 1.0))
		if now > from:
			st["g"] = minf(float(st.g) + (now - from) * _num("guard_gauge", "refill_s", 0.25), 1.0)
	st["at"] = now
	if bool(st.broken) and float(st.g) >= _num("guard_gauge", "back_at", 0.4):
		st["broken"] = false
	n.set_meta(GAUGE_META, st)
	return st


## `n`'s gauge now (0..1; 1 off the new ring).
static func gauge(n: Node) -> float:
	if n == null or not is_instance_valid(n) or not on():
		return 1.0
	return float(_gauge(n).g)


## Whether `n`'s gauge was broken and is not yet back at back_at.
static func broken(n: Node) -> bool:
	if n == null or not is_instance_valid(n) or not on():
		return false
	return bool(_gauge(n).broken)


## Whether a guard of `n`'s may rise now: not broken, something in the gauge.
static func can_guard(n: Node) -> bool:
	if n == null or not is_instance_valid(n) or not on():
		return true
	var st := _gauge(n)
	return not bool(st.broken) and float(st.g) > 0.0


## A guard of `n`'s rose (`z`, its zone): gauge.tap spent; nothing left: broken at once.
static func guard_stood(n: Node, z: BendZone) -> void:
	if n == null or not is_instance_valid(n) or not on():
		return
	var st := _gauge(n)
	st["up"] = int(st.up) + 1
	st["tick_at"] = BendStatus.now()
	st["g"] = maxf(float(st.g) - _num("guard_gauge", "tap", 0.2), 0.0)
	n.set_meta(GAUGE_META, st)
	if float(st.g) <= 0.0:
		_break(n, z)


## A frame of `n`'s guard `z` standing: past its own window (held) the gauge drains; empty, it breaks.
static func guard_tick(n: Node, z: BendZone, dt: float) -> void:
	if n == null or not is_instance_valid(n) or not on() or z == null:
		return
	var st := _gauge(n)
	st["tick_at"] = BendStatus.now()
	if z.t <= z.window_s:
		n.set_meta(GAUGE_META, st)
		return
	st["g"] = maxf(float(st.g) - dt * _num("guard_gauge", "drain_s", 0.35), 0.0)
	n.set_meta(GAUGE_META, st)
	if float(st.g) <= 0.0:
		_break(n, z)


## A guard of `n`'s fell (its zone ended): the refill waits refill_after_s from now.
static func guard_fell(n: Node) -> void:
	if n == null or not is_instance_valid(n) or not on():
		return
	var st := _gauge(n)
	st["up"] = maxi(int(st.up) - 1, 0)
	st["down_at"] = BendStatus.now()
	n.set_meta(GAUGE_META, st)


## The gauge empty: the guard ended, `n` staggered (hitstun stagger_s), no guard until back_at.
static func _break(n: Node, z: BendZone) -> void:
	var st := _gauge(n)
	st["broken"] = true
	st["g"] = 0.0
	n.set_meta(GAUGE_META, st)
	var at := (n as Node3D).global_position + Vector3.UP * 1.2 if n is Node3D else Vector3.ZERO
	BendLooks.burst(at, "stone", 14, Vector3.UP, 160.0, 4.0, 0.25, false)
	BendSounds.play(&"earth_crumble", at, -2.0)
	var kn := BendKnock.of(n as Node3D) if n is Node3D else null
	if kn != null:
		kn.stun_t = maxf(kn.stun_t, _num("guard_gauge", "stagger_s", 0.5))
	n.set_meta(BROKE_META, BendStatus.now())     # (the HUD's "Guard broken": BendStrip reads when)
	if z != null and is_instance_valid(z) and not z.is_queued_for_deletion():
		z.end("broken")


# ---------------------------------------------------------------- the follow-up (the owner, 2026-10-12: "if a user scores a
# sucessfull knock up any skill besides a knock up should cast faster so they can utilize the knock up")
const FOLLOW_META := &"bend_follow_up"


## A knock-up of `by`'s landed (RingRules.on_hit: its float begun on another side's body), `s` its rise and float: for that and
## follow_up.extra_s more his locks of any move but a knock-up fill follow_up.k faster.
static func knocked_up(by: Node, s: float) -> void:
	if by == null or not is_instance_valid(by) or not on():
		return
	var until := BendStatus.now() + s + _num("follow_up", "extra_s", 0.4)
	by.set_meta(FOLLOW_META, maxf(until, float(by.get_meta(FOLLOW_META, -INF))))


## Whether `n`'s follow-up window is open now.
static func follow_on(n: Node) -> bool:
	return n != null and is_instance_valid(n) and on() and BendStatus.now() < float(n.get_meta(FOLLOW_META, -INF))


## The share of its lock time `n`'s lock of m/md takes for the follow-up (1: none, or a knock-up of his own: no chain of them).
static func follow_share(n: Node, m: String, md: String) -> float:
	if not follow_on(n) or knockup(m, md):
		return 1.0
	return 1.0 - _num("follow_up", "k", 0.4)


## Whether m/md knocks up (its ring class a launcher or with a float: the Column, the Geyser, the tapped Fissure, the Kicks).
static func knockup(m: String, md: String) -> bool:
	var cls := RingRules.class_of(BendR3.tag_of(m, md, false))
	return bool(cls.get("launcher", false)) or float(cls.get("float_s", 0.0)) > 0.0


## Both meters back to their start for `n` (a round's start).
static func reset(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	lose(n)
	if n.has_meta(GAUGE_META):
		n.remove_meta(GAUGE_META)
	if n.has_meta(FOLLOW_META):
		n.remove_meta(FOLLOW_META)
