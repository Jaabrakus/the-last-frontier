class_name RingRules
extends Node
## Tidebreak's rules on the deck (the owner, 2026-10-04: the sport is Tidebreak, "knockback wins": docs/bending_design.md, "A
## hit pushes the enemy back through the three zones, and off the edge into the water wins the round. Health is the backup";
## 1v1 first, the team lists kept for 3v3). RingMode runs the rounds; this judges what happens on the deck while one is on
## (live). Every number in data/ring/rules.json.
##   sides       the competitors per team (0: the player's side, 1: the other), so 3v3 needs no rewrite; `ends` the deck end
##               (RingArena side: 0 at -X, 1 at +X) each team holds this round (RingMode swaps them each round)
##   knocks      every knock in the ring comes through here first (BendKnock.rules = this while the ring stands):
##               knock_scale x the KNOCKER's element factor, the flat part then capped so one hit moves a body at most
##               max_push_m (its slide v^2 / 2 GROUND_DECEL, and its flight first when it launches); the player thrown off
##               his feet only at ragdoll_mps or more (BendKnock.ragdoll_mps raised while the ring stands, put back after)
##   confined    a competitor knocked back across a zone line is confined to that zone for the round (it only grows): his
##               forward line is then a soft wall. Walking forward past it he is eased back (soft_wall_mps, soft_wall_k per
##               m), held at soft_wall_hard_m past it; no penalty, play flows. Walking back of his own will confines nothing
##   advancing   while a side's competitors are all confined to zone k or deeper, the other side may come into their zone
##               k-1 (k 1: the neutral strip is open to both)
##   the end     walking (not knocked) never takes anyone off his own open end (eased back inside edge_guard_m); a knock
##               carries him over
##   ring-out    a body out (RingArena.is_ring_out: in the tank's water, under the deck's edge by out_drop_m, or off a long
##               side over the ropes) is rung out at once (rang_out), credited to its last knocker within knock_credit_s
##               (BendKnock.last_knocker); a recovery (a hover, a glide, a jump) back onto the deck counts while it is not
##               below the drop. A side with every competitor out: side_out(team)
##   winded      at 0 health a competitor is winded, never killed (FrontierPlayer / NpcFighter no_death and their winded
##               signal): pushed back one zone (set winded_back_m behind its line), his health refilled to winded_refill;
##               winded while confined to the last zone is a ring-out, the winder's
##   bones       a bot's broken arm is let go in the ring (no running from the deck: NpcBrain flees on one), a bot down for
##               good counts as winded in the last zone
## TEAMS (the 3 v 3 groundwork; the plan's T14): each competitor added is marked with its side (BendCaster.TEAM_META "ring_0"
## or "ring_1": BendCaster.same_team, so BendStatus never lets a bend reach its caster's allies, an ally's bolt passes, an
## ally's guard lets it through); team_mode() once a side has more than one competitor: then a side advances only when
## every opponent still in is pushed back (min_confined; may_enter(team, zone)), a competitor rung out sits the round out
## (judged no more; RingMode holds a bot), and every one of a side out in one round is a knockout (side_out, which RingMode
## takes as the match's end in team mode: knockout()). 1 v 1 is unchanged: one out is the side out, the round's end.
## Practice (RingMode's): soft_walls off lets anyone walk anywhere on the deck (the edge guard and the ring-outs stay).
## Ring awareness for a bot (NpcBending's bounds_fn / edge_fn, the contract): bounds_fn_for(body) clamps a place to where
## that body may stand now; edge_along(pos, dir) the metres along dir to an open end. allowed_rect(body), edge_m(pos, side).
## Read by RingMode and the HUD: team_of, end_of, confined_of, s_of, forward_limit, territory(), health_frac(team), knocks.
## ROUND 3 (the % layer, smash_r3 spec §2, §3, §7, §14.3; SEAMS stubbed it, PERCENT fills it). THE GATE: stock_on() is
## true only while an installed RingRules has rule_set "stock" (rules.json rule_set; "classic" is today's zones, and with it
## every round-3 rule below is off and the stubs answer as if there were no % at all):
##   static      stock_on(), current() (the installed one or null), class_of(tag) {d, base, growth, angle, set, set_stun},
##               range_mult(tag, range_m) (1.0 to range.full_m, sliding to range.far_mult at range.far_m and beyond; exempt
##               tags 1.0), launch_v(cls, pct_after, d, w, range_m, air) (spec §2.2), weight_of(element)
##   per body    pct_of, stocks_of, safe_until, hitstun_left, stunned, can_escape, string_hits, stale_count(attacker, tag),
##               last_steer_deg, fresh_pct, heal_allowed; add_pct, reset_pct, patch (the fresh pool taken), on_hit(n, by,
##               info) -> the launch to apply (BendStatus calls it), note_lock_started(b) (a lock ends spawn safety)
##   signals     pct_changed, launched, ko, respawned, string_ended, hit_safe

signal knocked_back(who: Node3D, from_zone: int, to_zone: int)
signal rang_out(who: Node3D, by: Node)
signal side_out(side: int)
signal winded(who: Node3D, by: Node, to_zone: int)
## Round 3 (stock rules only; see the header): b's % now and what this change added.
signal pct_changed(b: Node3D, pct: float, delta: float)
## b launched at `v` (m/s) with `hitstun_s` of hitstun by `by`'s move `tag`.
signal launched(b: Node3D, v: Vector3, hitstun_s: float, by: Node, tag: String)
## b lost a life (`stocks_left` left) at `pct`, credited to `by`'s `tag` (by null: his own fall).
signal ko(b: Node3D, by: Node, pct: float, tag: String, stocks_left: int)
## b back on the deck from the spout.
signal respawned(b: Node3D)
## `by`'s string on `victim` over: `hits` hits, `pct` % dealt.
signal string_ended(by: Node, victim: Node3D, hits: int, pct: float)
## `by`'s hit passed through b while b was safe (the hiss and splash at `point`; the attacker's strip says so).
signal hit_safe(b: Node3D, by: Node, point: Vector3)

const DATA_PATH := "res://data/ring/rules.json"
const NODE_NAME := "RingRules"
## The rule sets (rules.json rule_set): "classic" today's zones, "stock" the % layer (round 3).
const RULE_SETS := ["classic", "stock"]

static var _data := {}
## The RingRules installed now (the one BendKnock.rules points at), or null: the gate's owner.
static var _current: RingRules = null

## This ring's rule set (rules.json rule_set, read as it is installed): "classic" or "stock".
var rule_set := "classic"

var ring: RingArena
## [team 0's competitors, team 1's] (Node3D: the player, NpcFighters).
var sides: Array = [[], []]
## The deck end each team holds this round (RingArena side).
var ends: Array[int] = [0, 1]
## The round is on: walls, zones and ring-outs judged (RingMode's FIGHT).
var live := false
## Per competitor (instance id): {body, team, confined, out, by, why}.
var state := {}
## Knocks landed this round by each team (x team 0's, y team 1's).
var knocks := Vector2i.ZERO
## The last ring-out: {who, by, why ("ringout" | "winded")}.
var last_out := {}
## The soft wall at each competitor's forward limit (off in practice: walk anywhere).
var soft_walls := true
## The last side to go out whole in team mode (-1 none this round): a knockout.
var knocked_out := -1

var _prev_rules: Object = null
var _prev_ragdoll := 9.0
var _installed := false


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = d if d is Dictionary else {}
	return _data


static func num(key: String, def := 0.0) -> float:
	return float(data().get(key, def))


static func make(parent: Node, arena: RingArena) -> RingRules:
	var r := RingRules.new()
	r.name = NODE_NAME
	r.ring = arena
	parent.add_child(r)
	return r


func _ready() -> void:
	process_physics_priority = 15            # (after the bodies have moved: their place this frame is judged)
	add_to_group(BendKnock.LISTENERS)
	_prev_rules = BendKnock.rules
	_prev_ragdoll = BendKnock.ragdoll_mps
	BendKnock.rules = self
	BendKnock.ragdoll_mps = num("ragdoll_mps", 16.0)
	_installed = true
	var rs := String(data().get("rule_set", "classic"))
	rule_set = rs if rs in RULE_SETS else "classic"
	_current = self
	# (the grates' reach: a waterbender draws water within grate_reach_m of one: Bending.near_water reads reach_m)
	if ring != null:
		for g in ring.pools():
			g.set_meta(&"reach_m", num("grate_reach_m", 1.5))


func _exit_tree() -> void:
	if _installed:
		if BendKnock.rules == self:
			BendKnock.rules = _prev_rules
		BendKnock.ragdoll_mps = _prev_ragdoll
		_installed = false
	if _current == self:
		_current = null
	clear()


# ---------------------------------------------------------------- the competitors
## Every competitor taken off the deck's books (their winded hooks undone).
func clear() -> void:
	for id in state:
		var b: Variant = (state[id] as Dictionary).get("body")
		if b is Node and is_instance_valid(b) and (b as Node).has_signal(&"winded"):
			for c: Dictionary in (b as Node).get_signal_connection_list(&"winded"):
				if (c.callable as Callable).get_object() == self:
					(b as Node).disconnect(&"winded", c.callable)
		if b is Node and is_instance_valid(b) and (b as Node).has_meta(BendCaster.TEAM_META):
			(b as Node).remove_meta(BendCaster.TEAM_META)
	state.clear()
	sides = [[], []]
	knocks = Vector2i.ZERO
	last_out = {}
	knocked_out = -1


## `body` a competitor of `team` (0 the player's side, 1 the other): never killed in the ring (no_death; winded instead).
func add(body: Node3D, team: int) -> void:
	if body == null or not is_instance_valid(body) or state.has(body.get_instance_id()):
		return
	state[body.get_instance_id()] = {"body": body, "team": team, "confined": 1, "out": false, "by": null, "why": ""}
	(sides[team] as Array).append(body)
	body.set_meta(BendCaster.TEAM_META, team_id(team))
	if &"no_death" in body:
		body.set(&"no_death", true)
	if body.has_signal(&"winded") and not body.is_connected(&"winded", _on_winded.bind(body)):
		body.connect(&"winded", _on_winded.bind(body))     # (once: a body kept from last round, RingMode's bot, may hold it)


## Team 0 holds deck end `e0` this round, team 1 the other.
func set_ends(e0: int) -> void:
	ends = [e0 % 2, 1 - e0 % 2]


## The round's start: everyone back to zone 1, in.
func reset_round() -> void:
	for id in state:
		var st := state[id] as Dictionary
		st["confined"] = 1
		st["out"] = false
		st["by"] = null
		st["why"] = ""
	knocks = Vector2i.ZERO
	last_out = {}
	knocked_out = -1


## Team `team`'s side for the team filter (BendCaster.TEAM_META): "ring_0", "ring_1".
static func team_id(team: int) -> StringName:
	return StringName("ring_%d" % team)


## More than one competitor on a side: the team rules (advance on all, sit out when out, the knockout).
func team_mode() -> bool:
	return (sides[0] as Array).size() > 1 or (sides[1] as Array).size() > 1


## The competitors of `team` still in this round.
func still_in(team: int) -> Array:
	var out: Array = []
	for b in sides[team]:
		if is_instance_valid(b) and not is_out(b):
			out.append(b)
	return out


## Whether team `team` may stand in the other side's zone `zone` (1..zones) now: only once every opponent still in is
## confined deeper than it (advancing: all of them behind the line).
func may_enter(team: int, zone: int) -> bool:
	return zone >= 1 and zone <= min_confined(1 - team) - 1


func _st(body: Node) -> Dictionary:
	if body == null or not is_instance_valid(body):
		return {}
	return state.get(body.get_instance_id(), {})


func team_of(body: Node) -> int:
	return int(_st(body).get("team", -1))


## The deck end (RingArena side) `body` holds this round (-1: not a competitor).
func end_of(body: Node) -> int:
	var t := team_of(body)
	return ends[t] if t >= 0 else -1


## The zone `body` is confined to this round (1..zones; 0: not a competitor).
func confined_of(body: Node) -> int:
	return int(_st(body).get("confined", 0))


func is_out(body: Node) -> bool:
	return bool(_st(body).get("out", false))


func s_of(body: Node3D) -> float:
	return ring.s_of(body.global_position, end_of(body))


func zones() -> int:
	return int(RingArena.num("zones", 3.0))


## The lowest zone the team's competitors still in are confined to (1 when none: nothing holds the other side back).
func min_confined(team: int) -> int:
	var m := 99
	for b in sides[team]:
		if is_instance_valid(b) and not is_out(b):
			m = mini(m, confined_of(b))
	return 1 if m == 99 else m


## The furthest forward `body` may stand (its s, metres back from the centre into its own end; negative: into the other
## half): its own line when confined past zone 1, else the other side's line before their zone (advancing).
func forward_limit(body: Node3D) -> float:
	var st := _st(body)
	if st.is_empty() or ring == null:
		return -INF
	var c := int(st.confined)
	var e := end_of(body)
	if c > 1:
		return ring.line_s(e, c - 1)
	var k := min_confined(1 - int(st.team))
	return -ring.line_s(1 - e, k - 1)


## The deck `body` may stand on now: from its forward limit back to its open end, rope to rope (an AABB, up to 3 m over).
func allowed_rect(body: Node3D) -> AABB:
	var e := end_of(body)
	if e < 0 or ring == null:
		return AABB()
	var sg := RingArena.side_sign(e)
	var box := AABB()
	var first := true
	for s: float in [forward_limit(body), ring.half_l()]:
		for z: float in [-ring.half_w(), ring.half_w()]:
			for y: float in [ring.top(), ring.top() + 3.0]:
				var p := ring.to_global(Vector3(sg * s, y, z))
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				else:
					box = box.expand(p)
	return box


## Metres from `pos` back to deck end `side`'s open edge (along the long axis).
func edge_m(pos: Vector3, side: int) -> float:
	return ring.half_l() - ring.s_of(pos, side)


## The metres along `dir` (flat) from `pos` to an open end (INF: it runs into a rope first, or never reaches one).
func edge_along(pos: Vector3, dir: Vector3) -> float:
	if ring == null:
		return INF
	var l := ring.to_local(pos)
	var d := ring.global_basis.inverse() * Vector3(dir.x, 0.0, dir.z)
	d.y = 0.0
	if d.length() < 1e-4:
		return INF
	d = d.normalized()
	if absf(d.x) < 1e-4:
		return INF
	var t := (signf(d.x) * ring.half_l() - l.x) / d.x
	if t < 0.0:
		return 0.0
	if absf(l.z + d.z * t) > ring.half_w():
		return INF
	return t


## A place for `body` kept where it may stand now (its forward limit to inside its end's edge guard, inside the ropes).
func clamp_for(pos: Vector3, body: Node3D) -> Vector3:
	var e := end_of(body)
	if e < 0 or ring == null:
		return pos
	var sg := RingArena.side_sign(e)
	var l := ring.to_local(pos)
	var s := clampf(l.x * sg, forward_limit(body) + 0.2, ring.half_l() - num("edge_guard_m", 0.35) - 0.4)
	l.x = s * sg
	l.z = clampf(l.z, -ring.half_w() + 0.6, ring.half_w() - 0.6)
	return ring.to_global(l)


## A bot's bounds_fn (pos -> the place clamped for it).
func bounds_fn_for(body: Node3D) -> Callable:
	return clamp_for.bind(body)


# ---------------------------------------------------------------- knocks (BendKnock.rules)
## Every knock in the ring: scaled by knock_scale and the knocker's element, its flat part capped to max_push_m of travel.
func knock_scale(_n: Node, v: Vector3, by: Node) -> Vector3:
	var el := BendPoses.element_of(by) if by != null and is_instance_valid(by) else ""
	var f := float((data().get("element_factor", {}) as Dictionary).get(el, 1.0))
	v *= num("knock_scale", 0.6) * f
	var flat := Vector3(v.x, 0.0, v.z)
	var vh := flat.length()
	var cap := num("max_push_m", 3.5)
	if vh > 1e-3 and push_m(vh, v.y) > cap:
		var lo := 0.0
		var hi := vh
		for i in 24:
			var mid := (lo + hi) * 0.5
			if push_m(mid, v.y) > cap:
				hi = mid
			else:
				lo = mid
		flat = flat / vh * lo
		v = Vector3(flat.x, v.y, flat.z)
	return v


## How far a knock of flat speed `vh` and up speed `vy` carries a body over flat deck (m): its flight first when it launches
## (AIR_DECEL over the airtime), then its slide (GROUND_DECEL).
static func push_m(vh: float, vy: float) -> float:
	var t_air := 2.0 * vy / BendKnock.launch_gravity() if vy >= BendKnock.LAUNCH_UP_MPS else 0.0
	var vh1 := maxf(vh - BendKnock.AIR_DECEL * t_air, 0.0)
	return (vh + vh1) * 0.5 * t_air + vh1 * vh1 / (2.0 * BendKnock.GROUND_DECEL)


## BendKnock's listeners: a knock landed (counted for the knocker's team).
func on_knocked(n: Node, _v: Vector3, by: Node) -> void:
	var t := team_of(by)
	if t < 0 or team_of(n) < 0 or t == team_of(n):
		return
	if t == 0:
		knocks.x += 1
	else:
		knocks.y += 1


# ---------------------------------------------------------------- each frame
func _physics_process(dt: float) -> void:
	if not live or ring == null:
		return
	for id in state.keys():
		if not live:
			return
		var st := state.get(id, {}) as Dictionary
		if st.is_empty():
			continue
		var b: Variant = st.get("body")
		if not (b is Node3D) or not is_instance_valid(b) or bool(st.out):
			continue
		_judge(b as Node3D, st, dt)


func _judge(b: Node3D, st: Dictionary, dt: float) -> void:
	if ring.is_ring_out(b):
		_out(b, credit(b), "ringout")
		return
	if b is NpcFighter:
		var f := b as NpcFighter
		if f.arm_broken != "":
			f.arm_broken = ""                 # (no running from the deck on a broken arm: the ring's no maims)
		if f.down or f.is_dead():
			_out(b, credit(b), "winded")
			return
	var e := end_of(b)
	var z := ring.zone_of(b.global_position, e)
	var c := int(st.confined)
	if z > c and z <= zones() and _knocked(b):
		st["confined"] = z
		knocked_back.emit(b, c, z)
	_walls(b, e, dt)


## Under a knock still: its reaction window, in the air from it, or still sliding.
func _knocked(b: Node3D) -> bool:
	var kn := BendKnock.peek(b)
	if kn != null and (kn.knock_t > 0.0 or kn.is_launched() or kn.kv.length() > 0.1):
		return true
	var rag := b.get_node_or_null(^"Ragdoll") as PlayerRagdoll
	return rag != null and rag.is_down()


## The soft wall at the forward limit, and the edge guard at the body's own open end.
func _walls(b: Node3D, e: int, dt: float) -> void:
	var back := ring.axis() * RingArena.side_sign(e)       # (toward its own end: +s)
	back.y = 0.0
	back = back.normalized()
	var s := ring.s_of(b.global_position, e)
	var lim := forward_limit(b) if soft_walls else -INF
	var moved := 0.0
	if s < lim:
		var depth := lim - s
		var step := minf(depth, (num("soft_wall_mps", 2.5) + num("soft_wall_k", 8.0) * depth) * dt)
		var hard := num("soft_wall_hard_m", 0.12)
		if depth - step > hard:
			step = depth - hard
		moved = step
		_stop(b, back)
	else:
		var edge := ring.half_l() - num("edge_guard_m", 0.35)
		if s > edge and not _knocked(b) and ring.on_deck(b.global_position):
			var over := s - edge
			var step := minf(over, num("soft_wall_mps", 2.5) * dt)
			var hard := num("soft_wall_hard_m", 0.12)
			if over - step > hard:
				step = over - hard
			moved = -step
			_stop(b, -back)
	if moved != 0.0:
		b.global_position += back * moved


## `b`'s velocity (and its knock's) going against `into` (unit, flat) taken out.
func _stop(b: Node3D, into: Vector3) -> void:
	if b is CharacterBody3D:
		var cb := b as CharacterBody3D
		var a := cb.velocity.dot(into)
		if a < 0.0:
			cb.velocity -= into * a
	var kn := BendKnock.peek(b)
	if kn != null:
		var k := kn.kv.dot(into)
		if k < 0.0:
			kn.kv -= into * k
			kn.applied = kn.kv


## Who gets the credit for `b` going out: its last knocker within knock_credit_s, else whoever winded it last.
func credit(b: Node3D) -> Node:
	var kn := BendKnock.peek(b)
	if kn != null and kn.knocked_within(num("knock_credit_s", 6.0)):
		return kn.last_knocker
	var by: Variant = _st(b).get("by")
	return by as Node if by is Node and is_instance_valid(by) else null


func _out(b: Node3D, by: Node, why: String) -> void:
	var st := _st(b)
	if st.is_empty() or bool(st.out):
		return
	st["out"] = true
	st["by"] = by
	st["why"] = why
	last_out = {"who": b, "by": by, "why": why}
	rang_out.emit(b, by)
	var t := int(st.team)
	for o in sides[t]:
		if is_instance_valid(o) and not is_out(o):
			return
	if team_mode():
		knocked_out = t
	side_out.emit(t)


## 0 health in the ring (the body's winded signal): pushed back a zone, its health to winded_refill; in the last zone, out.
func _on_winded(by: Node, b: Node3D) -> void:
	var st := _st(b)
	if st.is_empty():
		return
	_refill(b)
	if by != null and is_instance_valid(by) and by != b:
		st["by"] = by
	if not live or bool(st.out):
		return
	var c := int(st.confined)
	if c >= zones():
		_out(b, by if by != null and is_instance_valid(by) and by != b else credit(b), "winded")
		return
	var to := c + 1
	st["confined"] = to
	var e := end_of(b)
	var want := ring.line_s(e, to - 1) + num("winded_back_m", 0.6)
	var s := ring.s_of(b.global_position, e)
	if s < want:
		var back := ring.axis() * RingArena.side_sign(e)
		back.y = 0.0
		b.global_position += back.normalized() * (want - s)
		if b is CharacterBody3D:
			(b as CharacterBody3D).velocity = Vector3.ZERO
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
	knocked_back.emit(b, c, to)
	winded.emit(b, by, to)


func _refill(b: Node3D) -> void:
	var k := num("winded_refill", 0.4)
	if b is FrontierPlayer:
		var p := b as FrontierPlayer
		p.health = maxf(p.health, p.max_health * k)
	elif b is NpcFighter:
		var f := b as NpcFighter
		f.health = maxf(f.health, f.health_max * k)


# ---------------------------------------------------------------- the time-out
## The team holding more ground (the lower confined zones, summed over those still in), -1 when level.
func territory() -> int:
	var g := [0, 0]
	for t in 2:
		for b in sides[t]:
			if is_instance_valid(b):
				g[t] += zones() + 1 if is_out(b) else confined_of(b)
	if g[0] == g[1]:
		return -1
	return 0 if g[0] < g[1] else 1


## The team's health as a fraction of its most (averaged over its competitors).
func health_frac(team: int) -> float:
	var sum := 0.0
	var n := 0
	for b in sides[team]:
		if not is_instance_valid(b):
			continue
		n += 1
		if b is FrontierPlayer:
			sum += (b as FrontierPlayer).health / maxf((b as FrontierPlayer).max_health, 1.0)
		elif b is NpcFighter:
			sum += (b as NpcFighter).health / maxf((b as NpcFighter).health_max, 1.0)
	return sum / float(n) if n > 0 else 0.0


# ---------------------------------------------------------------- round 3: the % layer (SEAMS' stubs; PERCENT fills them)
## THE GATE: a stock-rules RingRules is installed (a % ring match). False in the open world, the duel and the classic ring.
static func stock_on() -> bool:
	return _current != null and is_instance_valid(_current) and _current.rule_set == "stock"


## The RingRules installed now (null: no ring).
static func current() -> RingRules:
	return _current if _current != null and is_instance_valid(_current) else null


## rules.json stock's block `key` ({} none).
static func stock_block(key: String) -> Dictionary:
	var s: Variant = data().get("stock", {})
	var b: Variant = (s as Dictionary).get(key, {}) if s is Dictionary else {}
	return b if b is Dictionary else {}


## rules.json stock's number `key`.
static func stock_num(key: String, def := 0.0) -> float:
	var s: Variant = data().get("stock", {})
	return float((s as Dictionary).get(key, def)) if s is Dictionary else def


## Move `tag`'s ("id/mode", "id/mode.grown") class: {d, base, growth, angle, set, set_stun, tag} ({}: none yet).
static func class_of(_tag: String) -> Dictionary:
	return {}


## The range falloff R (spec §2.2): 1.0 when the hit lands range.full_m or less from where it was cast, sliding to
## range.far_mult at range.far_m and beyond; an exempt tag (range.exempt: the returns, Lightning) is always 1.0.
static func range_mult(tag: String, range_m: float) -> float:
	var r := stock_block("range")
	if tag in (r.get("exempt", []) as Array):
		return 1.0
	var full := float(r.get("full_m", 10.0))
	var far := maxf(float(r.get("far_m", 22.0)), full + 0.01)
	var mult := float(r.get("far_mult", 0.65))
	return lerpf(1.0, mult, clampf((range_m - full) / (far - full), 0.0, 1.0))


## The launch speed (m/s, spec §2.2): w x (base + growth x R x A x p/100 x (0.5 + d/20)), p the % after the hit, d the hit's
## %, w the weight, R range_mult (by the class's tag, cls.tag), A stock.air_growth when released airborne; a set knock
## (cls.set) its base.
static func launch_v(cls: Dictionary, pct_after: float, d: float, w: float, range_m := 0.0, air := false) -> float:
	var base := float(cls.get("base", 0.0))
	if bool(cls.get("set", false)):
		return base
	var growth := float(cls.get("growth", 0.0))
	var r := range_mult(String(cls.get("tag", "")), range_m)
	var a := stock_num("air_growth", 0.85) if air else 1.0
	return w * (base + growth * r * a * pct_after / 100.0 * (0.5 + d / 20.0))


## Element `element`'s weight multiplier W (spec §2.4; 1.0 until PERCENT fills stock.weights).
static func weight_of(_element: String) -> float:
	return 1.0


## b's % now.
func pct_of(_b: Node) -> float:
	return 0.0


## b's lives left.
func stocks_of(_b: Node) -> int:
	return 0


## When b's spawn safety ends (BendStatus.now() s; -INF: not safe).
func safe_until(_b: Node) -> float:
	return -INF


## Seconds until b can act again (the escape counted).
func hitstun_left(_b: Node) -> float:
	return 0.0


## b in hitstun now.
func stunned(_b: Node) -> bool:
	return false


## b may escape his hitstun now (a fresh press at escape_s or later).
func can_escape(_b: Node) -> bool:
	return false


## Hits in the string on b now.
func string_hits(_b: Node) -> int:
	return 0


## How many of `attacker`'s last moves (the stale queue) were `tag`.
func stale_count(_attacker: Node, _tag: String) -> int:
	return 0


## The yaw b steered his last launch by (degrees).
func last_steer_deg(_b: Node) -> float:
	return 0.0


## b's fresh % (the pool Patch may take back).
func fresh_pct(_b: Node) -> float:
	return 0.0


## Whether b may heal now.
func heal_allowed(_b: Node) -> bool:
	return true


## `delta` % to b from `by`'s `tag`.
func add_pct(_b: Node, _delta: float, _by: Node, _tag: String) -> void:
	pass


## b's % set to `to`.
func reset_pct(_b: Node, _to := 0.0) -> void:
	pass


## Patch: b's fresh pool taken (at most patch.max_pct); returns the % removed.
func patch(_b: Node) -> float:
	return 0.0


## A lock of b's started (SwayCaster.lock_started): his spawn safety ends.
func note_lock_started(_b: Node) -> void:
	pass


## A hit on n by `by` (BendStatus): the launch to apply ({}: as today). Info keys: spec §14.3's hit info.
func on_hit(_n: Node, _by: Node, _info: Dictionary) -> Dictionary:
	return {}
