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
##   2026-10-15  the owner, after playing the jab string ("to easy to spam", "people can just get close to the user", "chains
##               are good if you land and attack"), picked four rules: a hit fills its worth (worth: the jab combo.jab_worth,
##               a skill its cast time over stack_s within worth_min..worth_max); a skill counts in full once a chain (the
##               same one again fills repeat_k of what it did the time before: the owner, after two Spikes, "doesnt stack",
##               picked "repeats add half"; only a skill new to the chain is a link, in_chain; the chain is every skill
##               since the combo was last empty); a full
##               combo makes the next hit that lands the finisher (take_finisher: the Pop's launch, the combo spent; the
##               jab's is its Pop, BendR3.pop_armed); a jab taken on the beat by a guard within rush_m knocks the jabber
##               back and opens the guarder's window (rush_answer). The jab string (three jabs, the Pop) is gone with them
##               (BendR3.deliver: finishers()), its click with it
## Kept on the body (COMBO_META, CHAIN_META, GAUGE_META), worked out lazily from BendStatus.now(): no tick of its own.

const COMBO_META := &"bend_combo"
## The skills in `n`'s chain ("id/mode" -> the times each landed): read only while his combo is above 0 (chain()).
const CHAIN_META := &"bend_chain"
## The volley id of the finisher `n` last landed (the rest of its projectiles the same finisher).
const FINISH_META := &"bend_finish"
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


## `amount` stacks more for `n` (a hit of his landed: its worth; a perfect guard of his: one), up to combo.max; a lock of his
## running now fills combo.fill a stack more at once (its ring jumps: the owner, 2026-10-13, "fill the cast time fuller").
static func gain(n: Node, amount := 1.0) -> void:
	if n == null or not is_instance_valid(n) or not on() or amount <= 0.0:
		return
	var k := minf(level(n) + amount, _num("combo", "max", 5.0))
	n.set_meta(COMBO_META, {"n": k, "at": BendStatus.now()})
	var bump := _num("combo", "fill", 0.0) * amount
	var c := SwayCaster.of(n)
	if bump > 0.0 and c != null and c.state == SwayCaster.State.LOCKING:
		c.fill = minf(c.fill + bump, 1.0)


## `n`'s stacks gone (a hit taken; a round's start).
static func lose(n: Node) -> void:
	if n != null and is_instance_valid(n):
		for k: StringName in [COMBO_META, CHAIN_META]:
			if n.has_meta(k):
				n.remove_meta(k)


## The share of its lock time `n`'s casts take for its combo (1 none): combo.per a stack, the level as it drains (0 since
## 2026-10-13: the combo fills his locks instead, head_start).
static func cast_share(n: Node) -> float:
	return 1.0 - _num("combo", "per", 0.0) * level(n)


## How full `n`'s locks begin for his combo (SwayCaster's lock: a head start, its ring begun fuller): combo.fill a stack, the
## level as it drains, never past HEAD_MAX.
const HEAD_MAX := 0.9
static func head_start(n: Node) -> float:
	return clampf(_num("combo", "fill", 0.0) * level(n), 0.0, HEAD_MAX)


## A hit of `by` on `n` landed (RingRules.on_hit; its own judgement of what counts; `info` the hit's): `n`'s combo all gone;
## `by`'s filled by its worth (a skill already in his chain repeat_k of it a time it landed before) and his window open
## (link_on); nothing for his finisher (it spent the combo: take_finisher).
static func landed(by: Node, n: Node, info := {}) -> void:
	lose(n)
	if by == null or not is_instance_valid(by) or by == n or BendCaster.same_team(by, n) or bool(info.get("finisher", false)):
		return
	var ch := chain(by)
	var key := key_of(info)
	var times := int(ch.get(key, 0)) if key != "" else 0
	if key != "":
		ch[key] = times + 1
	gain(by, worth(info) * pow(_num("combo", "repeat_k", 0.5), float(times)))
	if on():
		by.set_meta(CHAIN_META, ch)
		by.set_meta(LINK_META, BendStatus.now() + _num("combo", "link_s", 1.0))


## What a hit fills of its hitter's combo, in stacks: the jab combo.jab_worth; a skill its cast time (BendEffects.lock_of)
## over combo.stack_s, kept within worth_min..worth_max; a hit of no skill (a return, a reaction) worth_min.
static func worth(info: Dictionary) -> float:
	if bool(info.get("jab", false)):
		return _num("combo", "jab_worth", 0.25)
	var lo := _num("combo", "worth_min", 1.0)
	var m := String(info.get("move", ""))
	var cast := BendEffects.lock_of(m, String(info.get("mode", ""))) if m != "" and not bool(info.get("returned", false)) else -1.0
	if cast <= 0.0:
		return lo
	return clampf(cast / maxf(_num("combo", "stack_s", 0.6), 0.05), lo, maxf(_num("combo", "worth_max", 2.0), lo))


## The skill a hit is in its hitter's chain: "id/mode" (its hidden modes as what they stand for, BendR3.alias_of; a grown one
## the same skill), "return" for a return, else its tag's own ("" none: never in a chain).
static func key_of(info: Dictionary) -> String:
	if bool(info.get("returned", false)):
		return "return"
	var m := String(info.get("move", ""))
	if m != "":
		return skill_key(m, String(info.get("mode", "")))
	return String(info.get("tag", "")).get_slice(".", 0)


## Skill m at md as a chain names it.
static func skill_key(m: String, md: String) -> String:
	return "%s/%s" % [m, BendR3.alias_of(m, md)]


## The skills in `n`'s chain now, each with the times it landed ({} while his combo is empty: a chain ends as it drains away,
## is lost or spent).
static func chain(n: Node) -> Dictionary:
	if n == null or not is_instance_valid(n) or level(n) <= 0.0:
		return {}
	var ch: Variant = n.get_meta(CHAIN_META, {})
	return (ch as Dictionary).duplicate() if ch is Dictionary else {}


## Whether skill m at md is already in `n`'s chain (cast again it is no link, and fills repeat_k of what it did before).
static func in_chain(n: Node, m: String, md: String) -> bool:
	return chain(n).has(skill_key(m, md))


# ---------------------------------------------------------------- the finisher (the owner, 2026-10-15: "a full meter gives a
# finisher")
## Whether finishers are the ring's (combo.finisher, the combo on): a full combo's next hit launches, and no jab string.
static func finishers() -> bool:
	return on() and bool(RingRules.stock_block("combo").get("finisher", true))


## Whether `n`'s next hit that lands is his finisher: his combo full (its top stack not yet drained away, as the bracket shows).
static func finisher_ready(n: Node) -> bool:
	return finishers() and n != null and is_instance_valid(n) and level(n) > _num("combo", "max", 5.0) - 1.0 + 1e-3


## `by`'s hit `inf` on `n` (deliver's own copy) as his finisher: "first" (finisher_ready: his combo spent at once, the chain
## with it, the volley kept), "rest" (another projectile of the volley that was), "" none (a guarded hit, a spawn-safe body: it
## waits for one that lands whole).
static func take_finisher(by: Node, n: Node, inf: Dictionary) -> String:
	if by == null or not is_instance_valid(by) or not finishers():
		return ""
	if String(inf.get("guard", "")) != "" or bool(inf.get("slide_only", false)) or bool(inf.get("no_hurt", false)) \
			or bool(inf.get("wall_tick", false)) or (RingRules.current() != null and RingRules.current().is_safe(n)):
		return ""
	var vol := int(inf.get("volley_id", 0))
	if vol != 0 and int(by.get_meta(FINISH_META, 0)) == vol:
		return "rest"
	if not finisher_ready(by):
		return ""
	lose(by)
	by.set_meta(FINISH_META, vol)
	return "first"


# ---------------------------------------------------------------- the rusher answered (the owner, 2026-10-15: "people can just
# get close to the user")
## A jab of `by`'s taken on the beat by a guard of `n`'s (BendZone): `n`'s window opens, and `by` within combo.rush_m of him is
## knocked back rush_mps (the guard/rush class: no %, a short stun).
static func rush_answer(n: Node, by: Node) -> void:
	if not on() or n == null or by == null or not is_instance_valid(n) or not is_instance_valid(by) or n == by \
			or BendCaster.same_team(n, by) or not (n is Node3D) or not (by is Node3D):
		return
	n.set_meta(LINK_META, BendStatus.now() + _num("combo", "link_s", 1.0))
	var a := (n as Node3D).global_position
	var b := (by as Node3D).global_position
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if flat.length() > _num("combo", "rush_m", 6.0):
		return
	flat = flat.normalized() if flat.length_squared() > 1e-6 else -(n as Node3D).global_basis.z
	BendStatus.knock(by, flat * _num("combo", "rush_mps", 7.0), n, {"tag": "guard/rush"})


# ---------------------------------------------------------------- the combo window (the owner, 2026-10-15: "we can click a
# button and trigger combos faster"; rules.json stock._link)
const LINK_META := &"bend_link"


## Whether `n`'s combo window is open: a hit of his landed within combo.link_s, not yet spent on a skill.
static func link_on(n: Node) -> bool:
	return n != null and is_instance_valid(n) and on() and BendStatus.now() < float(n.get_meta(LINK_META, -INF))


## The share of its cast time a skill begun in the window takes (combo.link_share).
static func link_share() -> float:
	return _num("combo", "link_share", 0.34)


## `n`'s window spent (a skill begun in it): the next hit opens another.
static func spend_link(n: Node) -> void:
	if n != null and is_instance_valid(n) and n.has_meta(LINK_META):
		n.remove_meta(LINK_META)


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
	for k: StringName in [LINK_META, FINISH_META]:
		if n.has_meta(k):
			n.remove_meta(k)
