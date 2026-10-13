class_name BendStatus
extends RefCounted
## What a bent element does to whom it reaches (BendEffects, BendBolt, BendZone): hurts (Hit.deliver as a blunt blow: all of
## it now, no wound to bleed), knocks back, roots, slows, and the caster's own guards (anchor: no knockback). Timed effects
## are kept as metas with their end (ends_at) and undone when they run out.
##
##   knock   the one entry for every knockback (the ring's "knockback wins": the same for the player and the bots): the anchor
##           checked here, then BendKnock (its own decaying knock velocity on the body, the launch of an up-knock, the player
##           off his feet at BendKnock.ragdoll_mps, the ring's rules and the listeners). The wild and props as before.
##   root    the feet held, nothing else: the player's bend_speed_cap at 0 (his own cap, apart from drag_speed_cap, so a
##           duel's countdown hold or a wheelbarrow's cap is never let go by a root ending); a fighter's feet_held (not
##           `held`: its brain still thinks and it still casts while rooted).
##   slow    the player's bend_speed_cap at SLOW_MPS; a fighter's limp.
## ROUND 2 (skills_r2 spec §2.3, §2.4, §8.2 "Removed paths"; the owner: "getting hit never slows the player"):
##   no roots or slows in element mode: root() and slow() leave alone anyone who casts as an element (BendPoses.element_of:
##           the ring's competitors, the duel's two), counted in `held_off`; the open world keeps them
##   the hit's cost: hurt(..., lock_s) writes on the struck body what the blow cost its caster (HIT_LOCK_META: the move's lock
##           time, -1 unknown) before the body is told (its hurt signal), so SwayCaster pushes a lock back by it (setback_s)
##   Rooted: an earth competitor standing still (Bending.passive("earth"): under still_mps) takes knock_mult of a knock
##   clear_round(b): every timed bend meta on `b` gone (ROUND_METAS; RingMode.make_whole's list and round 2's)
## BINDS (2026-10-11, the owner: "each element should have binds and finishers and how they build team comps is on them";
## his answers: the feet only, as a skill tree twist each element has, fire's a lightning shock): bind(n, s) is the one way a
## root reaches someone who casts as an element: a twist's hit in the % ring (RingRules.on_hit, the hit's bind_s). The feet
## held as root() holds them (and RingMoves keeps him from jumping, rolling, dodging and dropping off; BendEffects from his dash
## key's moves); aim, casts and the guard stay his. Weaker each time on the same body (rules.json stock.bind: x decay within
## memory_s, none under floor_s); a hit that launches him frees them (unbind, _stock_hit). bound(n) asks.
## ROUND 3 (smash_r3 spec v2 §2, §14.3; PERCENT's): take_filters (static: can_take is false when any of them says false;
## none registered outside the % ring: RingRules.take_ok while a stock ring stands, MOVE's intangible dodges and edge grabs
## theirs), and the hit info (`info`, spec §14.3's keys). On a competitor of a stock-rules ring (stock_body) a hit is %:
## hurt never touches health, it hands the hit to RingRules.on_hit (the %, the launch) and sets the launch through
## BendKnock.knock (info._launch: SET, never added); the knock that follows a hurt in the same frame from the same attacker is
## that hit's (STOCK_HIT_META), a knock alone (a wind wall, a gust, an untagged stone) is a hit of its own. Everyone else, and
## everything with the gate off: as before.

## (old name) BendKnock.ragdoll_mps's first value: a knock this hard (m/s) or more throws the player off his feet.
const KNOCK_DOWN_MPS := 9.0
## A slowed man's pace (m/s).
const SLOW_MPS := 1.6
## What the last blow on a body cost its caster (s; -1 unknown): hurt's lock_s, read by the struck one's SwayCaster.
const HIT_LOCK_META := &"bend_hit_lock_s"
## Round 3: the last stock hit on a body: [physics frame, its attacker's instance id] (the knock after its hurt is the same hit).
const STOCK_HIT_META := &"bend_stock_hit"
## Every timed bend meta a round leaves on a body (clear_round): the old ones and round 2's (a guard's whiff, Carried wind,
## the burrow under the stones, the guard's last result, the last blow's cost).
const ROUND_METAS: Array[StringName] = [&"bend_root", &"bend_slow", &"bend_anchor", &"bend_redirect_lightning",
		&"bend_brace", &"bend_dazzle_until", &"bend_whiff_until", &"bend_carry_until", &"bend_under_until",
		&"bend_last_guard", &"bend_hit_lock_s", &"bend_dash_end", &"bend_slip_until", &"bend_bind_memo", &"bend_float",
		&"bend_float_memo", &"bend_drench", &"bend_drench_memo", &"bend_cast_mult"]
## A perfect guard's cast reward or penalty on a body: {mult (of his next cast's lock time), until} (parry_reward).
const CAST_MULT_META := &"bend_cast_mult"
## A bind's memory on the bound body: {at: the game time of the last bind tried on him, k: what that one held, as a share}.
const BIND_MEMO_META := &"bend_bind_memo"
## A knock-up's float on the floating body: {from, until (game s: the hold near the top), fall (m/s while held)}; and its
## memory as a bind's (FLOAT_MEMO_META).
const FLOAT_META := &"bend_float"
const FLOAT_MEMO_META := &"bend_float_memo"

## Roots and slows left alone because their body casts as an element (the tests).
static var held_off := 0
## Round 3: Callables (n: Node, caster: Node) -> bool; can_take is false when any returns false (none registered: as today).
static var take_filters: Array[Callable] = []


## The bend's clock (s): GAME time, not the wall's, so a timed effect's end (its meta) and its timer agree however fast the
## frames run (a slow frame, a headless test at a fixed fps).
## ROUND 4 (IMPACT; why it changed): it was the physics frame count over physics_ticks_per_second. Under Engine.time_scale
## Godot scales each physics step but still ticks at the wall's rate, so every bend timer (hitstun, the guards' windows, the
## catch, the bots' rests) drifted from the game it timed: the round-2 critic's earth-mirror soak caught 0 stones at ts 4
## against 87 at ts 1, and the timers ran on through an Esc pause. A slow beat (RingMoment) needs game time. Now a static
## total of game ticks advances by Engine.time_scale for each physics step (Godot's step is 1 / physics_ticks_per_second x
## time_scale), counted by a tiny clock node (BendClock, PROCESS_MODE_PAUSABLE, made on first use under the tree's root):
## a step of a paused tree adds nothing. It counts on SceneTree.physics_frame, which Godot emits at the start of each step
## before any node's physics and before the coroutines awaiting that signal (a node's lowest process_physics_priority would
## still run after those coroutines); a step's frame not yet counted (the physics server's area signals come before
## physics_frame) is read ahead at the time scale now. So every reader of a step sees that step's time, and at time_scale 1
## the value is the old frame clock's exactly (seeded with the frame count; tests/bending/test_bend_clock.gd pins it): no
## round-3 timer moves. With no SceneTree (pure unit tests) it is the frame count, as before. BendImpact.tick runs right
## after each count (its held launches let go at the start of the step that ends their hold).
static func now() -> float:
	var tps := float(Engine.physics_ticks_per_second)
	var t := Engine.get_main_loop() as SceneTree
	if t == null or t.root == null or no_tree:
		return float(Engine.get_physics_frames()) / tps
	if _clock == null or not is_instance_valid(_clock):
		_make_clock(t)
	var f := Engine.get_physics_frames()
	if f > _counted_f and not t.paused:
		return (_ticks + float(f - _counted_f) * maxf(Engine.time_scale, 0.0)) / tps
	return _ticks / tps


## The game ticks counted (seeded with the physics frame count when the clock is made), the physics frame they count up to,
## and the clock node.
static var _ticks := 0.0
static var _counted_f := 0
static var _clock: Node = null
static var _seeded := false
## Tests: read the clock as with no SceneTree (the frame fallback).
static var no_tree := false


static func _make_clock(t: SceneTree) -> void:
	var c := BendClock.new()
	c.name = "BendClock"
	c.process_mode = Node.PROCESS_MODE_PAUSABLE
	c.process_physics_priority = -1000000000
	c.tree = t
	_clock = c
	if not _seeded:
		_ticks = float(Engine.get_physics_frames())
		_counted_f = Engine.get_physics_frames()
		_seeded = true
	t.physics_frame.connect(c.tick)
	t.root.add_child.call_deferred(c)


## The game ticks counted so far (tests: at time_scale 1 equal to the physics frame count).
static func clock_ticks() -> float:
	return _ticks


## The clock node, or null before the first now() under a tree (tests).
static func clock() -> Node:
	return _clock if _clock != null and is_instance_valid(_clock) else null


## The clock node (see now()): one under the root; each physics step of a running tree adds Engine.time_scale ticks.
class BendClock extends Node:
	var tree: SceneTree
	## Physics steps the tree was paused through (tests).
	var paused_steps := 0

	func tick() -> void:
		if tree == null:
			return
		var f := Engine.get_physics_frames()
		if tree.paused:
			paused_steps += f - BendStatus._counted_f
			BendStatus._counted_f = f
			return
		# (at time_scale 1 exactly one tick a step: the frame clock's value to the bit)
		BendStatus._ticks += float(f - BendStatus._counted_f) * maxf(Engine.time_scale, 0.0)
		BendStatus._counted_f = f
		BendImpact.tick()

	func _exit_tree() -> void:
		if tree != null and tree.physics_frame.is_connected(tick):
			tree.physics_frame.disconnect(tick)
		if BendStatus._clock == self:
			BendStatus._clock = null


## Whom the bend can reach: the player and fighters (not dead), the wild, props; not `caster`, nor anyone on its side
## (BendCaster.same_team: the ring's teams; a body with no side, the open world's and the duel's, is everyone's to reach).
static func can_take(n: Node, caster: Node) -> bool:
	if n == null or not is_instance_valid(n) or n == caster:
		return false
	if caster != null and is_instance_valid(caster) and BendCaster.same_team(n, caster):
		return false
	for f in take_filters:
		if f.is_valid() and not bool(f.call(n, caster)):
			return false
	if n is FrontierPlayer:
		return not (n as FrontierPlayer).is_dead
	if n is NpcFighter:
		return not (n as NpcFighter).is_dead()
	if n is WildAnimal:
		return not (n as WildAnimal).is_dead()
	return n is RigidBody3D and not (n is FormStone)


## Everyone within `r` of `at` (flat, and within 3 m up or down) the bend can reach: [node, flat distance]. Never the
## caster's own side (can_take).
static func near(caster: Node, at: Vector3, r: float) -> Array:
	var out: Array = []
	var tree := caster.get_tree() if caster != null and caster.is_inside_tree() else null
	if tree == null:
		return out
	var pool: Array = []
	pool.append_array(tree.get_nodes_in_group(NpcFighter.GROUP))
	for q in tree.get_nodes_in_group(&"player"):             # (FrontierPlayer's group: every player, not only "Player")
		if not pool.has(q):
			pool.append(q)
	for n in pool:
		if not can_take(n, caster):
			continue
		var q := (n as Node3D).global_position
		var d := Vector2(q.x - at.x, q.z - at.z).length()
		if d <= r and absf(q.y - at.y) < 3.0:
			out.append([n, d])
	return out


## `dmg` to `n` from `by` at `at` going `dir`: a blunt blow (no anatomy wound; the striker's damage_kind meta for the hit).
## `lock_s`: what the blow cost its caster (its move's lock time; -1 unknown), written on `n` first (HIT_LOCK_META).
## `info`: round 3's hit info (spec §14.3; unread until PERCENT).
static func hurt(n: Node, dmg: float, at: Vector3, dir: Vector3, by: Node, lock_s := -1.0, info := {}) -> void:
	if by != null and not is_instance_valid(by):
		by = null                                # (its caster freed since: the blow is no one's)
	if dmg <= 0.0 or not can_take(n, by):
		return
	if not NetSpells.here(n, "hurt", [dmg, at, dir, by, lock_s, info]):
		return                                   # (online: the host's to decide, his owner's to take: NetSpells)
	n.set_meta(HIT_LOCK_META, lock_s)
	if stock_body(n):
		# (the % ring: the hit is %, never health; its launch set at once, the knock that follows it this frame taken as done)
		var i := info.duplicate()
		i["dmg"] = dmg
		i["at"] = at
		i["dir"] = dir
		var res := _stock_hit(n, by, i)
		var landed := float(res.get("d", 0.0)) > 0.0 or not bool(res.get("none", true))
		if landed and n is FrontierPlayer and is_instance_valid(n) and not bool(info.get("no_hurt", false)):
			# (his own reactions to a blow still hear of it, health untouched: SwayCaster's lock and Lightning's charge, the
			# HUD's edge; AIR moves them onto the hitstun)
			var p := n as FrontierPlayer
			var from := -dir if dir.length_squared() > 1e-8 else at - p.global_position
			var local := Vector2(from.dot(p.global_basis.x), from.dot(-p.global_basis.z))
			p.hurt.emit(local.normalized() if local.length_squared() > 1e-8 else Vector2.ZERO, dmg, false)
		return
	var had: Variant = by.get_meta(&"damage_kind") if by != null and by.has_meta(&"damage_kind") else null
	if by != null:
		by.set_meta(&"damage_kind", "blunt")
	if n.has_method(&"apply_hit"):
		n.apply_hit(dmg, at, dir, by, "body")
	if by != null and is_instance_valid(by):
		if had == null:
			by.remove_meta(&"damage_kind")
		else:
			by.set_meta(&"damage_kind", had)


## `n` knocked along `v` (m/s; its up part lifts, LAUNCH_UP_MPS or more launches) by `by`. An anchored one (anchor) is not
## moved. The player and the fighters through BendKnock (the same model for both). `info`: round 3's hit info, passed on to
## BendKnock.knock.
static func knock(n: Node, v: Vector3, by: Node, info := {}) -> void:
	if by != null and not is_instance_valid(by):
		by = null
	if v.length_squared() < 1e-4 or not can_take(n, by):
		return
	if not NetSpells.here(n, "knock", [v, by, info]):
		return                                   # (online: NetSpells)
	if until(n, &"bend_anchor") > 0.0:
		return
	if stock_body(n):
		if _hit_this_frame(n, by, info):
			return                               # (its hurt already set the launch: the same hit)
		var i := info.duplicate()
		i["v_given"] = v
		i["at"] = (n as Node3D).global_position + Vector3.UP
		if String(i.get("tag", "")) == "":
			i["dmg"] = RingRules.current().take_deficit(n as Node3D)
		_stock_hit(n, by, i)
		return
	v *= rooted_mult(n)
	if n is FrontierPlayer or n is NpcFighter:
		BendKnock.of(n).knock(v, by, info)
	elif n is WildAnimal:
		SwayEffects.shove_animal(n as WildAnimal, Vector3(v.x, 0.0, v.z), (by as Node3D).global_position if by is Node3D else Vector3.ZERO)
	elif n is RigidBody3D:
		SwayEffects.push_prop(n as RigidBody3D, v, (n as Node3D).global_position, 400.0)


## Round 3: `n` is a competitor of a stock-rules ring (the % ring: its hits are %, its knocks set its motion).
static func stock_body(n: Node) -> bool:
	if not RingRules.stock_on() or not (n is FrontierPlayer or n is NpcFighter):
		return false
	return RingRules.current().team_of(n) >= 0


## Round 3: a hit on a stock competitor (RingRules.on_hit: the %, the launch), the launch set through BendKnock (info._launch),
## the frame, the attacker and the hit's id marked (STOCK_HIT_META: the knock that follows its hurt is the same hit).
static func _stock_hit(n: Node, by: Node, info: Dictionary) -> Dictionary:
	n.set_meta(STOCK_HIT_META, [Engine.get_physics_frames(), by.get_instance_id() if by != null else 0, int(info.get("hit_id", 0))])
	var res := RingRules.current().on_hit(n, by, info)
	if res.is_empty() or bool(res.get("none", true)) or until(n, &"bend_anchor") > 0.0:
		return res
	var i := info.duplicate()
	i["_launch"] = res
	unbind(n)                                   # (a launch frees bound feet)
	BendKnock.of(n).knock(res.get("v", Vector3.ZERO), by, i)
	return res


## Whether a knock is the hit its hurt already took: the same hit_id (AIR's BendR3.deliver gives one hurt and knock the same id),
## else (no id) the same physics frame and attacker.
static func _hit_this_frame(n: Node, by: Node, info := {}) -> bool:
	if not n.has_meta(STOCK_HIT_META):
		return false
	var m: Array = n.get_meta(STOCK_HIT_META)
	var hid := int(info.get("hit_id", 0))
	if hid != 0 and m.size() > 2 and int(m[2]) != 0:
		return int(m[2]) == hid
	return int(m[0]) == Engine.get_physics_frames() and int(m[1]) == (by.get_instance_id() if by != null else 0)


## Seconds left of timed effect `key` on `n` (0: none).
static func until(n: Node, key: StringName) -> float:
	if n == null or not is_instance_valid(n) or not n.has_meta(key):
		return 0.0
	return maxf(float(n.get_meta(key)) - now(), 0.0)


## `n`'s feet held where it stands for `s` (the player's bend_speed_cap 0; a fighter's feet_held: it still thinks and casts).
## Never on one who casts as an element (held_off).
static func root(n: Node, s: float) -> void:
	if not NetSpells.here(n, "root", [s]):
		return
	if element_mode(n):
		held_off += 1
		return
	_timed(n, &"bend_root", s, 0.0)


## A bind (see BINDS in the header): `n`'s feet held for `s` x what his last binds have left (rules.json stock.bind), on the deck
## only, its look at his feet in element `el`'s matter (BendLooks.bind_feet). Returns the seconds held (0: none: off the deck,
## worn down under floor_s, or he cannot be hit now).
static func bind(n: Node, s: float, el := "") -> float:
	if n == null or not is_instance_valid(n) or s <= 0.0 or not can_take(n, null):
		return 0.0
	if n is CharacterBody3D and not (n as CharacterBody3D).is_on_floor():
		return 0.0
	var b := RingRules.stock_block("bind")
	var t := now()
	var memo: Variant = n.get_meta(BIND_MEMO_META, {})
	var k := 1.0
	if memo is Dictionary and t - float((memo as Dictionary).get("at", -INF)) < float(b.get("memory_s", 6.0)):
		k = float((memo as Dictionary).get("k", 1.0)) * float(b.get("decay", 0.6))
	n.set_meta(BIND_MEMO_META, {"at": t, "k": k})
	var held := s * k
	if held < float(b.get("floor_s", 0.2)):
		return 0.0
	_timed(n, &"bend_root", held, 0.0)
	if n is Node3D:
		BendLooks.bind_feet(n as Node3D, el, held)
	return held


## `n`'s feet let go now (a bind's: a hit that launches him).
static func unbind(n: Node) -> void:
	if n == null or not is_instance_valid(n) or until(n, &"bend_root") <= 0.0:
		return
	n.set_meta(&"bend_root", now())
	_end_timed(n, &"bend_root", 0.0)
	if n is Node3D:
		BendLooks.bind_end(n as Node3D)


## Whether `n`'s feet are held now (a bind, or a root in the open world).
static func bound(n: Node) -> bool:
	return until(n, &"bend_root") > 0.0


## A knock-up's float (RingRules.on_hit, a class's float_s; the owner 2026-10-11: a helpless float, his teammates may free him):
## `n` held near the top of his launch, from `rise` s from now, for `s` x what his last floats have left (rules.json stock.float:
## x decay within memory_s of the last, none under floor_s), falling only fall_mps meanwhile (RingMoves). Helpless: on_hit
## runs his hitstun through it and BendKnock.can_escape says no while it lasts. A Wind Prison catches with a rise of 0 (held
## where he is). Returns the seconds held (0 none).
static func float_up(n: Node, rise: float, s: float) -> float:
	if n == null or not is_instance_valid(n) or s <= 0.0:
		return 0.0
	var b := RingRules.stock_block("float")
	var t := now()
	var memo: Variant = n.get_meta(FLOAT_MEMO_META, {})
	var k := 1.0
	if memo is Dictionary and t - float((memo as Dictionary).get("at", -INF)) < float(b.get("memory_s", 6.0)):
		k = float((memo as Dictionary).get("k", 1.0)) * float(b.get("decay", 0.6))
	n.set_meta(FLOAT_MEMO_META, {"at": t, "k": k})
	var held := s * k
	if held < float(b.get("floor_s", 0.2)):
		return 0.0
	var from := t + maxf(rise, 0.0)
	n.set_meta(FLOAT_META, {"from": from, "until": from + held, "fall": float(b.get("fall_mps", 0.5))})
	return held


## Whether `n` is in a knock-up's float now: from the hit through its hold near the top.
static func floating(n: Node) -> bool:
	if n == null or not is_instance_valid(n) or not n.has_meta(FLOAT_META):
		return false
	return now() < float((n.get_meta(FLOAT_META) as Dictionary).get("until", -INF))


## The fall speed `n` is held at now (m/s, RingMoves' air step), or -1 when his float is not holding him now (not floating, or
## still rising to its top).
static func float_fall(n: Node) -> float:
	if n == null or not is_instance_valid(n) or not n.has_meta(FLOAT_META):
		return -1.0
	var f: Dictionary = n.get_meta(FLOAT_META)
	var t := now()
	if t >= float(f.get("until", -INF)):
		n.remove_meta(FLOAT_META)
		return -1.0
	return float(f.get("fall", 0.5)) if t >= float(f.get("from", INF)) else -1.0


## `n`'s float over now (a launch replaces it: RingRules.on_hit); `free`: his hitstun ends with it too (a teammate freed him:
## rescue).
static func unfloat(n: Node, free := false) -> void:
	if n == null or not is_instance_valid(n) or not n.has_meta(FLOAT_META):
		return
	n.remove_meta(FLOAT_META)
	if free:
		var kn := BendKnock.peek(n)
		if kn != null:
			kn.end_stun()


## A teammate's bend reaching `n` (the owner 2026-10-11: "we should allow other players to send walls or break binds to protect
## them"): a bind on him broken, a float he is held in ended and his hitstun with it (he falls, free). True when it freed him.
## BendBolt (a bolt passing through him), the cones, the Column and the Geyser (their reach). Never a wall: walls are raised
## before him to shield him (float_cover), the owner: "no walls can be placed in front of them".
static func rescue(n: Node, by: Node) -> bool:
	if n == null or not is_instance_valid(n) or by == null or not is_instance_valid(by) or n == by:
		return false
	if not BendCaster.same_team(n, by):
		return false
	if not NetSpells.here(n, "rescue", [by]):
		return false                             # (online: the host's to decide, his owner's to free: NetSpells)
	var freed := false
	if bound(n):
		unbind(n)
		freed = true
	if floating(n):
		unfloat(n, true)
		freed = true
	if freed and n is Node3D:
		BendLooks.burst((n as Node3D).global_position + Vector3.UP * 0.8, BendPoses.element_of(by), 14)
	return freed


## Drenched (a skill tree twist's hit, the hit's drench_s: Drenching Wave; the owner 2026-10-11: "water should be able slowdown
## maybe implement slows", his answer: as a twist, about 30% slower for 1.5 s, aim untouched, weaker each time): `n`'s run and
## his drift in the air at rules.json stock.drench.k of their speed for `s` x what his last soakings left (x decay within
## memory_s, none under floor_s); his dashes, aim, casts and guard as ever. Returns the seconds it lasts (0 none). `look`: what
## drips off him ("mud": a guard's mud, BendZone.MUD_S).
static func drench(n: Node, s: float, look := "water") -> float:
	if n == null or not is_instance_valid(n) or s <= 0.0 or not can_take(n, null):
		return 0.0
	var b := RingRules.stock_block("drench")
	var t := now()
	var memo: Variant = n.get_meta(&"bend_drench_memo", {})
	var k := 1.0
	if memo is Dictionary and t - float((memo as Dictionary).get("at", -INF)) < float(b.get("memory_s", 6.0)):
		k = float((memo as Dictionary).get("k", 1.0)) * float(b.get("decay", 0.6))
	n.set_meta(&"bend_drench_memo", {"at": t, "k": k})
	var held := s * k
	if held < float(b.get("floor_s", 0.3)):
		return 0.0
	n.set_meta(&"bend_drench", {"until": maxf(t + held, float(drench_left(n)) + t), "mult": float(b.get("k", 0.7))})
	if n is Node3D:
		BendLooks.drench(n as Node3D, held, look)
	return held


## Seconds `n` stays drenched (0 none).
static func drench_left(n: Node) -> float:
	if n == null or not is_instance_valid(n) or not n.has_meta(&"bend_drench"):
		return 0.0
	return maxf(float((n.get_meta(&"bend_drench") as Dictionary).get("until", -INF)) - now(), 0.0)


## The share of his speed `n` runs at now (1: not drenched).
static func drench_mult(n: Node) -> float:
	if drench_left(n) <= 0.0:
		return 1.0
	return float((n.get_meta(&"bend_drench") as Dictionary).get("mult", 0.7))


## How tall a wall `by` raises at `at` must stand to shield a teammate floating within `r` of it (m over `at`: his feet's height
## and 2 m more; 0 when none floats there). The owner 2026-10-11: walls are "placed in front of them", and "a earth wall can fly
## up there": a wall raised before a floating teammate rises to cover him (FormEffects.earth_wall, BendEffects._wall).
static func float_cover(by: Node, at: Vector3, r := 3.0) -> float:
	if by == null or not is_instance_valid(by) or not by.is_inside_tree():
		return 0.0
	var tree := by.get_tree()
	var h := 0.0
	for b in tree.get_nodes_in_group(NpcFighter.GROUP) + tree.get_nodes_in_group(&"player"):
		if b == by or not (b is Node3D) or not floating(b) or not BendCaster.same_team(b, by):
			continue
		var q := (b as Node3D).global_position
		if Vector2(q.x - at.x, q.z - at.z).length() <= r:
			h = maxf(h, q.y - at.y + 2.0)
	return h


## A perfect guard of a spell (BendZone._result, the % ring; the owner 2026-10-11: "if the user E a spell the it has to have that
## perfect thing they get one faster move cast buff", and "the person that got parried ... has a slightly slower cast time",
## 15% for 3 s): `n`'s next cast locks in 1 - rules.json stock.parry.k of its time, `by`'s (the caster he parried) in 1 + k;
## each for one cast within window_s, spent by it (spend_cast_mult; SwayCaster._lock_time, NpcBending.begin). A guard's own
## lock never takes it.
static func parry_reward(n: Node, by: Node) -> void:
	var k := float(RingRules.stock_block("parry").get("k", 0.15))
	if n != null and is_instance_valid(n):
		give_cast_mult(n, 1.0 - k)
		BendCombo.gain(n)                        # (a perfect guard: a stack of his combo, the owner 2026-10-12)
	if by != null and is_instance_valid(by) and by != n and not BendCaster.same_team(n, by):
		give_cast_mult(by, 1.0 + k)


## `n`'s next cast within rules.json stock.parry.window_s locks in `mult` of its time (parry_reward's each side). Online the
## body's owner keeps it (NetSpells: the host's word to him).
static func give_cast_mult(n: Node, mult: float) -> void:
	if n == null or not is_instance_valid(n) or not NetSpells.here(n, "cast_mult", [mult]):
		return
	var until := now() + float(RingRules.stock_block("parry").get("window_s", 3.0))
	n.set_meta(CAST_MULT_META, {"mult": mult, "until": until})


## The share of its lock time `n`'s next cast takes now (1: none; parry_reward), and his combo's (BendCombo.cast_share: its
## stacks, the new ring's; never spent by a cast).
static func cast_mult(n: Node) -> float:
	if n == null or not is_instance_valid(n):
		return 1.0
	var combo := BendCombo.cast_share(n)
	if not n.has_meta(CAST_MULT_META):
		return combo
	var c: Dictionary = n.get_meta(CAST_MULT_META)
	return (float(c.get("mult", 1.0)) if now() < float(c.get("until", -INF)) else 1.0) * combo


## `n`'s cast reward or penalty spent (a cast went with it).
static func spend_cast_mult(n: Node) -> void:
	if n != null and is_instance_valid(n) and n.has_meta(CAST_MULT_META):
		n.remove_meta(CAST_MULT_META)


## Every teammate of `by` within `r` of `at` freed (rescue): an area cast's reach.
static func rescue_near(by: Node, at: Vector3, r: float) -> void:
	if by == null or not is_instance_valid(by) or not by.is_inside_tree():
		return
	var tree := by.get_tree()
	for b in tree.get_nodes_in_group(NpcFighter.GROUP) + tree.get_nodes_in_group(&"player"):
		if b is Node3D and (bound(b) or floating(b)) and (b as Node3D).global_position.distance_to(at) <= r + 0.5:
			rescue(b, by)


## `n` slowed to SLOW_MPS for `s`. Never on one who casts as an element (held_off).
static func slow(n: Node, s: float) -> void:
	if not NetSpells.here(n, "slow", [s]):
		return
	if element_mode(n):
		held_off += 1
		return
	_timed(n, &"bend_slow", s, SLOW_MPS)


## Whether `n` casts as an element now (the ring, the duel: BendPoses.element_of).
static func element_mode(n: Node) -> bool:
	return n != null and is_instance_valid(n) and BendPoses.element_of(n) != ""


## The Rooted passive's share of a knock on `n` (1 unless an earth competitor stands still: Bending.passive("earth")).
static func rooted_mult(n: Node) -> float:
	if not (n is CharacterBody3D) or BendPoses.element_of(n) != "earth":
		return 1.0
	var pv := Bending.passive("earth")
	var v := (n as CharacterBody3D).velocity
	if Vector2(v.x, v.z).length() >= float(pv.get("still_mps", 0.3)) or not (n as CharacterBody3D).is_on_floor():
		return 1.0
	return BendLoadout.tune_f(n, "rules:passives.earth.knock_mult", float(pv.get("knock_mult", 0.85)))


## How far a lock of the struck `n` is pushed back by its last blow (spec §2.3: what the blow cost its caster, at least
## hit_setback_min_s). Read once: the blow's cost is taken off `n` (a later blow that is not a bend's, a melee hit, costs
## the least).
static func setback_s(n: Node) -> float:
	var cost := -1.0
	if n != null and is_instance_valid(n) and n.has_meta(HIT_LOCK_META):
		cost = float(n.get_meta(HIT_LOCK_META))
		n.remove_meta(HIT_LOCK_META)
	return maxf(cost, Bending.rule("hit_setback_min_s", 0.25))


## Every timed bend meta on `b` gone (a new round: RingMode.make_whole).
static func clear_round(b: Node) -> void:
	if b == null or not is_instance_valid(b):
		return
	for k in ROUND_METAS:
		if b.has_meta(k):
			b.remove_meta(k)


## The caster can't be knocked back for `s`. Online his own machine's (a puppet's is his owner's: NetSpells.owns).
static func anchor(n: Node, s: float) -> void:
	if n != null and NetSpells.owns(n):
		n.set_meta(&"bend_anchor", now() + s)


## A little health back (the player's, a fighter's), up to its most. Online his own machine's (NetSpells.owns).
static func heal(n: Node, amount: float) -> void:
	if not NetSpells.owns(n):
		return
	if n is FrontierPlayer:
		var p := n as FrontierPlayer
		p.health = minf(p.health + amount, p.max_health)
	elif n is NpcFighter:
		var f := n as NpcFighter
		f.health = minf(f.health + amount, f.health_max)


static func _timed(n: Node, key: StringName, s: float, cap: float) -> void:
	if not can_take(n, null) or s <= 0.0:
		return
	var end := now() + s
	n.set_meta(key, maxf(end, float(n.get_meta(key, 0.0))))
	if n is FrontierPlayer:
		var p := n as FrontierPlayer
		p.bend_speed_cap = minf(p.bend_speed_cap, cap)
	elif n is NpcFighter:
		var f := n as NpcFighter
		if key == &"bend_root":
			f.feet_held = true
		else:
			if not f.has_meta(&"bend_limp"):
				f.set_meta(&"bend_limp", f.limp)        # (his own limp, a broken leg's, back after)
			f.limp = minf(f.limp, 0.6)
	n.get_tree().create_timer(s + 0.02, false, true).timeout.connect(_end_timed.bind(n, key, cap))


static func _end_timed(n: Node, key: StringName, cap: float) -> void:
	if n == null or not is_instance_valid(n):
		return
	var left := until(n, key)
	if left > 0.0:
		# (not over yet: made longer since, or the timer ran ahead of the physics clock; looked at again when it is)
		if n.is_inside_tree():
			n.get_tree().create_timer(left + 0.02, false, true).timeout.connect(_end_timed.bind(n, key, cap))
		return
	if n.has_meta(key):
		n.remove_meta(key)
	if n is FrontierPlayer:
		# (only the bend's own cap: whatever else holds drag_speed_cap, a countdown, a load, is never touched)
		var p := n as FrontierPlayer
		p.bend_speed_cap = 0.0 if until(n, &"bend_root") > 0.0 else (SLOW_MPS if until(n, &"bend_slow") > 0.0 else INF)
	elif n is NpcFighter:
		var f := n as NpcFighter
		if key == &"bend_root":
			f.feet_held = false
		elif key == &"bend_slow" and f.has_meta(&"bend_limp"):
			f.limp = float(f.get_meta(&"bend_limp"))
			f.remove_meta(&"bend_limp")
