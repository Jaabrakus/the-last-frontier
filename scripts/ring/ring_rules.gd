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
##   tug of war  zones (rule_set "zones"; the owner, 2026-10-12: "we cant have 2 teams pushed back then they are to far is a
##               give and take like a tug of war"): one front a round, never both sides pushed back. front 0 the neutral
##               strip open to both; front f > 0 team 1 held behind its own line f and team 0 free up to it, f < 0 the same
##               the other way. A knock carrying a body back past the line one zone behind the front from its side
##               (_give_line; from the strip, its own line 1) moves the front a zone toward that body's end, whichever side
##               held the ground before; winded the same; at its last zone already, winded is out. Every competitor's confined
##               follows the front (1 + the zones its side has lost); one of the losing side caught forward of the new line
##               is eased back with it (tug_ease_mps, for tug_ease_s), not snapped. The time-out: the side the front stands
##               in the other half of, else the sum below. The classic ring keeps the rules below as they were
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
## ROUND 3, THE % LAYER (smash_r3 spec v2 §2, §3, §6.7, §7, §8, §14.3; PERCENT's; every number in rules.json stock). THE
## GATE: stock_on() is true only while an installed RingRules has rule_set "stock" or "zones" (pick_rule_set(): rule_set_override,
## the user arg rules=, else rules.json rule_set, "stock" by default; "classic" is round 2's zones, and with it every rule below
## is off: the classic code above runs untouched). ZONES (the owner, 2026-10-11: "zones is still good ... but it should have
## all the new bending movements"; picked: hits like Lives, the new deep-water deck): rule_set "zones" is the new ring in every
## move, knock and stage (stock_on() true: MOVE's RingMoves, AIR, the launches, the stock deck), only its scoring the zones':
## the ledger a damage meter (pct_on() false: no lives, spouts or clock), the launch at 0% always (it never grows), at
## zones.wind_pct winded (_zones_wind: back a zone, the meter to winded_refill's share; in the last zone out), the zone lines'
## confinement, the soft walls and advancing as classic's; a ring-out (into the water) or the last winding out of the round.
## The body's health shows the meter (_hp_sync: the zones' HUD and time-out read health). Under stock: no zones, no confinement, no soft walls, no winding, no edge
## guard (forward_limit -INF, bounds_fn_for the deck's rectangle), no knock_scale, no ragdoll (BendKnock.ragdoll_mps INF):
##   the ledger  a hit adds d % (never health: BendStatus.hurt does not touch it, and damage that reaches it anyway is turned
##               into % by the curve and put back, absorb); d is the move's class's (class_of(tag): stock.classes; a skill
##               tree node the hitter wears puts its numbers over it, BendLoadout.hit_class, the tag kept), staled
##               (each copy in the attacker's last stale.n hits -stale.step, at most -stale.max; returns never), x pct_scale;
##               a volley is one hit (its d / volley_n each; only the first knocks, stuns and counts); untagged damage by
##               curve_k (1 - e^(-dmg / curve_s)); a late guard (slide_only) half, a perfect one nothing; a return is its own
##               class (return_class: the Spike's or the caught move's if higher, x return_mult .. rally.max)
##   the launch  v = W (base + growth R A p/100 (0.5 + d/20)) (launch_v: R range_mult, A air_mult; W weight_of the struck one;
##               earth's Rooted on the base, air's Carried wind on all), set classes their set speed (Pull no faster than
##               reaches the caster), at the class's angle along the hit's way, vy capped; a tumble at tumble_mps or
##               tumble_deg, else a flinch-slide on the feet; the Slam on a body on the deck bounces him (once a string);
##               a hit on a lying body a set push. on_hit returns it, BendKnock SETS the motion to it (never adds)
##   hitstun     clamp(hitstun_k v, min, max) or the set stuns, x string_decay^(m-1) (floor string_floor; the Pop exempt), a jab
##               after the Pop after_pop_jab_s, the string_cap-th hit cap_stun_s, the breather after a string of
##               breather.min_hits; counted on the victim across attackers (string_ended on his first free frame)
##   lives       stocks (team: team.stocks); out in the water or past the curtain (RingArena.is_out), credited to the last
##               knocker within knock_credit_s, else his own; ko(b, by, pct, tag, left), his % to 0; gone at 0, his side out
##               when the last of it is (side_out). RingMode runs the respawn: respawn(b, held) (safe until safe_after_s
##               after left_spout, or the moment a lock of his starts: note_lock_started), the clock, sudden death
##               (start_sudden), best of 3. Practice (lives_on false): a fall loses nothing, both put back
##   take_ok     (BendStatus.take_filters) nobody reaches one who is away (out, respawning) or in an intangible moment
##   Patch       fresh_pct(b) (the last patch.fresh_s), heal_allowed(b) (a pool, no foe out, not sudden, not in the air),
##               patch(b) (the pool, at most patch.max_pct)
##   the tally   tally[team] for the match screen (pct_dealt, falls dealt and taken, own falls, healed, the longest string,
##               the highest % survived; note_stat(b, key) for AIR's and MOVE's: perfect_guards, clean_catches, edge_saves)
##   static      stock_on(), current(), pick_rule_set(), class_of, return_class, rally_mult, curve_d, range_mult, air_mult,
##               launch_v, weight_of, hitstun_of, guard_outcome(guard_el, tag, since_s) (AIR's BendZone may ask it)
##   per body    pct_of, stocks_of, safe_until, is_safe, is_away, is_gone, hitstun_left (the escape counted), stunned,
##               can_escape, string_hits, stale_count(attacker, tag), last_steer_deg, fresh_pct, heal_allowed; add_pct,
##               reset_pct, patch, on_hit(n, by, info), note_lock_started(b), team_stocks(team)
##   signals     pct_changed, launched, ko, respawned, string_ended, hit_safe

signal knocked_back(who: Node3D, from_zone: int, to_zone: int)
signal rang_out(who: Node3D, by: Node)
signal side_out(side: int)
signal winded(who: Node3D, by: Node, to_zone: int)
## Round 3 (stock rules only; see the header): b's % now and what this change added.
signal pct_changed(b: Node3D, pct: float, delta: float)
## `delta` % dealt to b by `by` (another's hit: what the side's pct_dealt tally counts), for a fighter's own numbers (RingMode.roster).
signal pct_dealt(by: Node, b: Node3D, delta: float)
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
## The rule sets (rules.json rule_set): "classic" round 2's zones (kept for its tests), "stock" the % layer (round 3, the
## menu's Lives), "zones" the zones on the new ring (the menu's Zones).
const RULE_SETS := ["classic", "stock", "zones"]
## The rule sets of the new ring (stock_on(): MOVE, AIR, the launches, the stock deck).
const NEW_RING := ["stock", "zones"]

static var _data := {}
## The RingRules installed now (the one BendKnock.rules points at), or null: the gate's owner.
static var _current: RingRules = null
## The rule set the next ring plays, when set ("classic" | "stock"; "": rules=, else rules.json): tests, BOTS' Rules row.
static var rule_set_override := ""

## This ring's rule set (rules.json rule_set, read as it is installed): "classic", "stock" or "zones".
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
## Zones' tug of war: the front this round (0 the neutral strip; > 0 team 1 pushed back that many zones, < 0 team 0), and
## when it last moved (BendStatus.now()).
var front := 0
var front_moved_at := -INF

## Round 3 (stock): sudden death on (one life each at sudden.pct; the next fall wins).
var sudden := false
## Round 3 (stock): lives counted (false in Practice: a fall loses nothing, the % to 0, both put back by RingPractice).
var lives_on := true
## Round 3 (stock): this game's falls in order: {who, by, pct, tag, at (BendStatus.now()), team, left}.
var falls: Array = []
## Round 3 (stock): this game's tally per team (the match screen's): pct_dealt, falls_dealt, falls_taken, self_falls, healed,
## string_hits / string_pct (the longest string), and what AIR and MOVE note (note_stat).
var tally: Array = [{}, {}]
## Round 3 (stock): every move fresh (no staling; Practice's "fresh moves" row: RingPractice and RingMenu set it).
var stale_off := false

var _prev_rules: Object = null
var _prev_ragdoll := 9.0
var _installed := false
## Round 3: each attacker's stale queue (instance id -> his last stale.n tags landed), the volleys seen (key -> {stale_k, at}).
var _stale := {}
var _volleys := {}
var _once := {}
var _filter_on := false


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
	rule_set = pick_rule_set()
	# (stock: no ragdoll in the ring, the launch is the hit; the intangible moments and the respawn's absence as a filter)
	BendKnock.ragdoll_mps = INF if rule_set in NEW_RING else num("ragdoll_mps", 16.0)
	_installed = true
	_current = self
	if rule_set in NEW_RING and not BendStatus.take_filters.has(take_ok):
		BendStatus.take_filters.append(take_ok)
		_filter_on = true
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
	if _filter_on:
		BendStatus.take_filters.erase(take_ok)
		_filter_on = false
	if _current == self:
		_current = null
	clear()


# ---------------------------------------------------------------- the competitors
## Every competitor taken off the deck's books (their winded hooks undone).
func clear() -> void:
	for id in state:
		var b: Variant = (state[id] as Dictionary).get("body")
		if not is_instance_valid(b):
			continue                            # (freed since it was added)
		if b is Node and (b as Node).has_signal(&"winded"):
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
	front = 0
	front_moved_at = -INF


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
		BendCombo.reset(st.get("body") as Node if st.get("body") is Node and is_instance_valid(st.get("body")) else null)
		st["confined"] = 1
		st["out"] = false
		st["by"] = null
		st["why"] = ""
		if not lives_on and st.has("pct"):
			st["away"] = false               # (stock Practice: back in after a fall)
	knocks = Vector2i.ZERO
	last_out = {}
	knocked_out = -1
	front = 0
	front_moved_at = -INF


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
## confined deeper than it (advancing: all of them behind the line); zones: the ground the front gives it.
func may_enter(team: int, zone: int) -> bool:
	if tug():
		return zone >= 1 and zone <= -lost(team)
	return zone >= 1 and zone <= min_confined(1 - team) - 1


# ---------------------------------------------------------------- zones' tug of war (see the header)
func tug() -> bool:
	return rule_set == "zones"


## The zones team `team` has lost to the front (< 0: the zones of the other side's it has taken).
func lost(team: int) -> int:
	return front if team == 1 else -front


## Every competitor's confined from the front.
func _sync_front() -> void:
	for id in state:
		var st := state[id] as Dictionary
		st["confined"] = 1 + maxi(lost(int(st.team)), 0)


## The front moved `n` zones toward team `team`'s end, kept short of the last zone's far side each way.
func _give(team: int, n: int) -> void:
	var m := zones() - 1
	front = clampi(front + (n if team == 1 else -n), -m, m)
	front_moved_at = BendStatus.now()
	_sync_front()


## The line (s from the centre toward team `team`'s own end) a knock must carry one of its own back past to give ground: one
## zone behind the front from its side (from the neutral strip: its own line 1).
func _give_line(team: int, extra := 0) -> float:
	var l := lost(team) + extra
	return ring.line_s(0, l + 1) if l >= 0 else -ring.line_s(0, -l - 1)


## A knock carrying `b` back past its side's give line: the front a zone toward its end (a line more, a zone more); its side
## at its last zone already: the water or the winding takes it from there.
func _tug_judge(b: Node3D, st: Dictionary) -> void:
	if not _knocked(b):
		return
	var t := int(st.team)
	var c := int(st.confined)
	var s := ring.s_of(b.global_position, end_of(b))
	var n := 0
	while lost(t) + n < zones() - 1 and s > _give_line(t, n):
		n += 1
	if n > 0:
		_give(t, n)
		knocked_back.emit(b, c, int(st.confined))


static func zones_num(key: String, def: float) -> float:
	var z: Variant = data().get("zones")
	return float((z as Dictionary).get(key, def)) if z is Dictionary else def


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
	if st.is_empty() or ring == null or rule_set == "stock":
		return -INF
	var c := int(st.confined)
	var e := end_of(body)
	if tug():
		var l := lost(int(st.team))
		return ring.line_s(e, l) if l > 0 else -ring.line_s(1 - e, -l)
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
	if rule_set in NEW_RING:
		# (stock, zones: all four sides open, no ropes: the metres to the deck's rectangle along dir)
		var tx := ((signf(d.x) * ring.half_l() - l.x) / d.x) if absf(d.x) > 1e-4 else INF
		var tz := ((signf(d.z) * ring.half_w() - l.z) / d.z) if absf(d.z) > 1e-4 else INF
		return maxf(minf(tx, tz), 0.0)
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
	if rule_set in NEW_RING:
		# (stock: the deck's rectangle only, no zones, no edge guard: MOVE's teeter keeps a walker on; zones: that, from the
		# body's forward limit back)
		var ls := ring.to_local(pos)
		ls.x = clampf(ls.x, -ring.half_l() + 0.6, ring.half_l() - 0.6)
		if rule_set == "zones":
			var sg0 := RingArena.side_sign(e)
			var s0 := clampf(ls.x * sg0, forward_limit(body) + 0.2, ring.half_l() - 0.6)
			ls.x = s0 * sg0
		ls.z = clampf(ls.z, -ring.half_w() + 0.6, ring.half_w() - 0.6)
		# (a team arena's raised pieces: a bot on the deck is sent round them, never into a wall; one up on a perch keeps its
		# place there)
		if not ring.pieces().is_empty() and ring.floor_at(body.global_position) < 0.5:
			return ring.off_pieces(ring.to_global(ls), 0.7)
		return ring.to_global(ls)
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
	if rule_set in NEW_RING:
		return v                             # (stock, zones: the launch is the class's, worked out in on_hit; knock_scale off)
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
	if rule_set == "stock":
		_stock_frame(dt)
		return
	if rule_set == "zones":
		_zones_frame(dt)
		return
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
		if (b as Node3D).has_meta(RingNet.PUPPET_META):
			continue                             # (a remote body online: judged on its owner's machine, RingNet)
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
	if kn != null and rule_set == "zones" and kn.stun_t > 0.0:
		return true                          # (zones: a launch's hitstun, its flight and its landing)
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
		if tug() and BendStatus.now() - front_moved_at < zones_num("tug_ease_s", 2.5) and depth > 0.5:
			step = minf(depth, zones_num("tug_ease_mps", 7.0) * dt)   # (the front moved under him: eased back with it)
		elif depth - step > hard:
			step = depth - hard
		moved = step
		_stop(b, back)
	elif rule_set != "zones":                # (zones: no edge guard, MOVE's teeter keeps a walker on as in Lives)
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
	if rule_set in NEW_RING:
		absorb(b, by)                        # (stock: no winding, no zones: the blow is %; zones: the meter, _zones_frame winds)
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
## The team holding more ground (zones: the side the front stands in the other half of; else, or level, the lower confined
## zones, summed over those still in), -1 when level.
func territory() -> int:
	if tug() and front != 0:
		return 0 if front > 0 else 1
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


# ---------------------------------------------------------------- round 3: the % layer (PERCENT; the gate: stock_on())
## The rule set a ring starting now plays: rule_set_override (tests), else the menu's choice (MatchSetup.rules_choice: the
## Esc menu's Rules row, a kept setting, the user arg MatchSetup took), else the user arg rules=classic|stock (or rule_set=),
## else rules.json rule_set.
static func pick_rule_set() -> String:
	if rule_set_override in RULE_SETS:
		return rule_set_override
	if MatchSetup.rules_choice in RULE_SETS:
		return MatchSetup.rules_choice
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		if kv.begins_with("rules=") or kv.begins_with("rule_set="):
			var v := kv.get_slice("=", 1).strip_edges()
			if v in RULE_SETS:
				return v
	var rs := String(data().get("rule_set", "classic"))
	return rs if rs in RULE_SETS else "classic"


## THE GATE: a stock-rules RingRules is installed (a % ring match). False in the open world, the duel and the classic ring.
static func stock_on() -> bool:
	return _current != null and is_instance_valid(_current) and _current.rule_set in NEW_RING


## The % and the lives count now (Lives: rule_set "stock"): the % plates, the lives, the spouts, the clock. Zones: false.
static func pct_on() -> bool:
	return _current != null and is_instance_valid(_current) and _current.rule_set == "stock"


## The zones on the new ring now (rule_set "zones").
static func zones_on() -> bool:
	return _current != null and is_instance_valid(_current) and _current.rule_set == "zones"


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


## A number of stock's block `blk`.
static func sub_num(blk: String, key: String, def := 0.0) -> float:
	return float(stock_block(blk).get(key, def))


## rules.json stock's string `key`.
static func stock_str(key: String, def := "") -> String:
	return String(stock_any(key, def))


## rules.json stock's value `key` (any kind).
static func stock_any(key: String, def: Variant = null) -> Variant:
	var s: Variant = data().get("stock", {})
	return (s as Dictionary).get(key, def) if s is Dictionary else def


## Move `tag`'s ("id/mode", "id/mode.grown") class (stock.classes): {d, base, growth, angle, set, set_stun, volley_n, dir,
## launcher, no_flinch, slam, pop, jab, pull, tag} ({}: none). growth_scale applies to every growth.
static func class_of(tag: String) -> Dictionary:
	var cs := stock_block("classes")
	var c: Variant = cs.get(tag)
	if not (c is Dictionary):
		return {}
	var out := (c as Dictionary).duplicate()
	out["tag"] = tag
	out["growth"] = float(out.get("growth", 0.0)) * stock_num("growth_scale", 1.0)
	return out


## A returned stone's class (spec §2.5): the Spike's (return_base_tag), or the caught move's (`origin_tag`) when its d is
## higher, x `mult` on d and growth (return_mult 1.2 .. rally.max 1.6). Never staled, no range falloff, no air factor.
static func return_class(origin_tag: String, mult := 0.0) -> Dictionary:
	var c := class_of(stock_str("return_base_tag", "stone_form/spike"))
	var o := class_of(origin_tag) if origin_tag != "" else {}
	if not o.is_empty() and not bool(o.get("set", false)) and float(o.get("d", 0.0)) > float(c.get("d", 0.0)):
		c = o
	var m := mult if mult > 0.0 else stock_num("return_mult", 1.2)
	m = clampf(m, 1.0, sub_num("rally", "max", 1.6))
	c = c.duplicate()
	c["d"] = float(c.get("d", 0.0)) * m
	c["growth"] = float(c.get("growth", 0.0)) * m
	c["tag"] = String(c.get("tag", "")) + ".return"
	c["returned"] = true
	c["mult"] = m
	return c


## The rally's multiplier after `returns` returns (`clean` of them off a clean catch): return_mult + step a return (clean a
## clean one), at most rally.max (AIR counts the rally; this is its number).
static func rally_mult(returns: int, clean := 0) -> float:
	var r := stock_block("rally")
	var m := stock_num("return_mult", 1.2) + float(maxi(returns - clean, 0)) * float(r.get("step", 0.1)) \
			+ float(clean) * float(r.get("clean", 0.2))
	return minf(m, float(r.get("max", 1.6)))


## Untagged damage as d (spec §2.1): curve_k (1 - e^(-dmg / curve_s)).
static func curve_d(dmg: float) -> float:
	if dmg <= 0.0:
		return 0.0
	return stock_num("curve_k", 13.0) * (1.0 - exp(-dmg / maxf(stock_num("curve_s", 35.0), 0.01)))


## The range falloff R (spec §2.2): 1.0 when the hit lands range.full_m or less from where it was cast, sliding to
## range.far_mult at range.far_m and beyond; an exempt tag (range.exempt: Lightning) or a return (".return") is always 1.0.
static func range_mult(tag: String, range_m: float) -> float:
	var r := stock_block("range")
	if tag in (r.get("exempt", []) as Array) or tag.ends_with(".return"):
		return 1.0
	var full := float(r.get("full_m", 10.0))
	var far := maxf(float(r.get("far_m", 22.0)), full + 0.01)
	var mult := float(r.get("far_mult", 0.65))
	return lerpf(1.0, mult, clampf((range_m - full) / (far - full), 0.0, 1.0))


## The air factor A (spec §2.2) for class `cls`: air_growth when released airborne; the Slam and returns exempt.
static func air_mult(cls: Dictionary, air: bool) -> float:
	if not air or bool(cls.get("slam", false)) or bool(cls.get("returned", false)):
		return 1.0
	if String(cls.get("tag", "")) in (stock_any("air_exempt", []) as Array):
		return 1.0
	return stock_num("air_growth", 0.85)


## The launch speed (m/s, spec §2.2): w x (base + growth x R x A x p/100 x (0.5 + d/20)), p the % after the hit, d the hit's
## % (after staling), w the weight, R range_mult (by the class's tag, cls.tag), A air_mult; a set knock (cls.set) its base.
## cls.base_mult (earth's Rooted) scales the base only.
static func launch_v(cls: Dictionary, pct_after: float, d: float, w: float, range_m := 0.0, air := false) -> float:
	var base := float(cls.get("base", 0.0)) * float(cls.get("base_mult", 1.0))
	if bool(cls.get("set", false)):
		return base
	var growth := float(cls.get("growth", 0.0))
	var r := range_mult(String(cls.get("tag", "")), range_m)
	var a := air_mult(cls, air)
	return w * (base + growth * r * a * pct_after / 100.0 * (0.5 + d / 20.0))


## Element `element`'s weight multiplier W = 2 / (1 + weight); raw weights come from stock.weights.
static func weight_of(element: String) -> float:
	var w := float(stock_block("weights").get(element, 1.0))
	return 2.0 / (1.0 + maxf(w, 0.01))


## Hitstun for a launch of `v` m/s (spec §3.1): clamp(hitstun_k v, hitstun_min, hitstun_max).
static func hitstun_of(v: float) -> float:
	return clampf(stock_num("hitstun_k", 0.045) * v, stock_num("hitstun_min", 0.12), stock_num("hitstun_max", 1.2))


## The guard's outcome in the % ring (spec v2 §2.5: every guard stops every attack; AIR's BendZone may ask it): a guard of
## element `guard_el` taking move `tag` `since_s` after it stood: "catch" (earth against a stone, within guard_catch_s: a full
## catch, 0%), "perfect" (within guard_perfect_s: 0%, no launch; Lightning only by fire), else "late" (half the % and half the
## launch, a slide on the feet).
static func guard_outcome(guard_el: String, tag: String, since_s: float, guard_by: Node = null) -> String:
	var stone := tag.begins_with("stone_form/") or tag.begins_with("rock_jab/") or tag.ends_with(".return")
	if guard_el == "earth" and stone:
		# (`guard_by` the guard's owner: his own full-catch time, a skill tree node's: Juggle; Classic: the stock's)
		return "catch" if since_s <= BendLoadout.tune_f(guard_by, "stock:guard_catch_s", stock_num("guard_catch_s", 1.0)) + 1e-4 else "late"
	if since_s > stock_num("guard_perfect_s", 0.3) + 1e-4:
		return "late"
	if tag == "fire_arc/lightning" and guard_el != "fire":
		return "late"
	return "perfect"


## Whether `tag` is a jab's (a class marked jab).
static func is_jab(tag: String) -> bool:
	return bool(class_of(tag).get("jab", false))


# ---------------------------------------------------------------- round 3: per competitor
func _sk(b: Node) -> Dictionary:
	var st := _st(b)
	if st.is_empty():
		return {}
	if not st.has("pct"):
		_stock_init(st)
	return st


func _stock_init(st: Dictionary) -> void:
	st["pct"] = 0.0
	st["stocks"] = int(_stocks_each())
	st["safe_until"] = -INF
	st["away"] = false
	st["gone"] = false
	st["string"] = {"hits": 0, "pct": 0.0, "by": null, "pop": false, "bounced": false, "m": 0}
	st["breather_until"] = -INF
	st["fresh"] = []
	st["healed"] = 0.0
	st["best_pct"] = 0.0
	st["last_tag"] = ""
	st["last_by"] = null
	st["safe_hit_at"] = -INF


## The lives each competitor starts a game with (stocks; team.stocks in team mode).
func _stocks_each() -> int:
	return int(sub_num("team", "stocks", 2.0)) if team_mode() else int(stock_num("stocks", 3.0))


## b's % now.
func pct_of(b: Node) -> float:
	return float(_sk(b).get("pct", 0.0))


## b's lives left.
func stocks_of(b: Node) -> int:
	return int(_sk(b).get("stocks", 0))


## When b's spawn safety ends (BendStatus.now() s; -INF: not safe; INF: on the spout).
func safe_until(b: Node) -> float:
	return float(_sk(b).get("safe_until", -INF))


## b is safe now (after a respawn: hits pass with no %, launch or stun).
func is_safe(b: Node) -> bool:
	return BendStatus.now() < safe_until(b)


## b is out of play now (respawning, or out of lives).
func is_away(b: Node) -> bool:
	var st := _sk(b)
	return bool(st.get("away", false)) or bool(st.get("gone", false))


## b has no lives left.
func is_gone(b: Node) -> bool:
	return bool(_sk(b).get("gone", false))


## Seconds until b can act again: the end of his hitstun, or escape_s into it when the hitstun runs longer (the escape
## counted, spec §3.2).
func hitstun_left(b: Node) -> float:
	var kn := BendKnock.peek(b)
	if kn == null:
		return 0.0
	return kn.act_left()


## b in hitstun now.
func stunned(b: Node) -> bool:
	var kn := BendKnock.peek(b)
	return kn != null and kn.stun_t > 0.0


## b may escape his hitstun now (a fresh press of Space or 3: a stun over escape_s, escape_s into it).
func can_escape(b: Node) -> bool:
	var kn := BendKnock.peek(b)
	return kn != null and kn.can_escape()


## b's fresh press (made now) ends his hitstun when it may (BendKnock.escape: the hitstun and its reaction window over at
## once); MOVE's RingMoves calls it for the escape. True when it ended it.
func escape(b: Node) -> bool:
	var kn := BendKnock.peek(b)
	return kn != null and kn.escape()


## Hits in the string on b now.
func string_hits(b: Node) -> int:
	return int((_sk(b).get("string", {}) as Dictionary).get("hits", 0))


## How many of `attacker`'s last moves (his stale queue, stale.n) were `tag`.
func stale_count(attacker: Node, tag: String) -> int:
	if attacker == null or not is_instance_valid(attacker):
		return 0
	return (_stale.get(attacker.get_instance_id(), []) as Array).count(tag)


## The yaw b steered his last launch by (degrees, unsigned).
func last_steer_deg(b: Node) -> float:
	var kn := BendKnock.peek(b)
	return absf(kn.steer_deg) if kn != null else 0.0


## b's fresh % (the pool Patch may take back: what he took in the last patch.fresh_s).
func fresh_pct(b: Node) -> float:
	var st := _sk(b)
	if st.is_empty():
		return 0.0
	var now := BendStatus.now()
	var keep := sub_num("patch", "fresh_s", 6.0)
	var sum := 0.0
	for e: Array in st.fresh:
		if now - float(e[0]) <= keep:
			sum += float(e[1])
	return minf(sum, pct_of(b))


## Whether b may Patch now (spec §8): a fresh pool, no foe out (respawning), not in sudden death, not in the air.
func heal_allowed(b: Node) -> bool:
	if not stock_on() or _sk(b).is_empty():
		return true
	if fresh_pct(b) <= 0.0 or sudden or is_away(b):
		return false
	var t := team_of(b)
	for o in sides[1 - t]:
		if is_instance_valid(o) and bool(_sk(o).get("away", false)) and not is_gone(o):
			return false
	var rm := RingMoves.of(b)
	if rm != null and rm.airborne():
		return false
	if b is CharacterBody3D and not (b as CharacterBody3D).is_on_floor():
		return false
	return true


## `delta` % to b from `by`'s `tag` (a hit's d, or a test's): pct_changed; a positive delta joins the fresh pool.
func add_pct(b: Node, delta: float, by: Node, tag: String) -> void:
	var st := _sk(b)
	if st.is_empty() or delta == 0.0:
		return
	var was := float(st.pct)
	st["pct"] = maxf(was + delta, 0.0)
	if delta > 0.0:
		(st.fresh as Array).append([BendStatus.now(), delta])
		if (st.fresh as Array).size() > 64:
			(st.fresh as Array).pop_front()
		st["last_tag"] = tag
		if by != null and is_instance_valid(by) and by != b:
			st["last_by"] = by
			var t := team_of(by)
			if t >= 0:
				_tally(t, "pct_dealt", delta)
				pct_dealt.emit(by, b as Node3D, delta)
	_hp_sync(b)
	pct_changed.emit(b, float(st.pct), float(st.pct) - was)


## b's % as its owner's machine has it (online: another machine's body, NetBody's pct slot): shown, nothing else changed.
func mirror_pct(b: Node, v: float) -> void:
	var st := _sk(b)
	if st.is_empty() or is_equal_approx(float(st.pct), v):
		return
	var was := float(st.pct)
	st["pct"] = maxf(v, 0.0)
	_hp_sync(b)
	pct_changed.emit(b, float(st.pct), float(st.pct) - was)


## b's % set to `to` (a fall: 0; sudden death: sudden.pct; Practice's rows); the fresh pool emptied.
func reset_pct(b: Node, to := 0.0) -> void:
	var st := _sk(b)
	if st.is_empty():
		return
	var was := float(st.pct)
	st["pct"] = maxf(to, 0.0)
	(st.fresh as Array).clear()
	_hp_sync(b)
	if was != float(st.pct):
		pct_changed.emit(b, float(st.pct), float(st.pct) - was)


## b's % raised by `delta` outside the fresh pool: no Patch ever takes it back (a worn Cauterize's cost, FireTalents).
func add_pct_kept(b: Node, delta: float) -> void:
	var st := _sk(b)
	if st.is_empty() or delta <= 0.0:
		return
	var was := float(st.pct)
	st["pct"] = was + delta
	pct_changed.emit(b, float(st.pct), delta)


## Patch (spec §8): b's fresh pool taken back, at most patch.max_pct, never under 0; returns the % removed (0 when not
## allowed: heal_allowed).
func patch(b: Node) -> float:
	return patch_up_to(b, sub_num("patch", "max_pct", 10.0))


## Patch's taking back with its own most (`max_pct`: a worn Cauterize's 12, FireTalents; Patch's own: patch).
func patch_up_to(b: Node, max_pct: float) -> float:
	if not heal_allowed(b):
		return 0.0
	var st := _sk(b)
	var take := minf(fresh_pct(b), max_pct)
	if take <= 0.0:
		return 0.0
	# (the newest first: the pool shrinks from its young end)
	var left := take
	var fr := st.fresh as Array
	for i in range(fr.size() - 1, -1, -1):
		if left <= 0.0:
			break
		var e := fr[i] as Array
		var k := minf(float(e[1]), left)
		e[1] = float(e[1]) - k
		left -= k
	var was := float(st.pct)
	st["pct"] = maxf(was - take, 0.0)
	st["healed"] = float(st.get("healed", 0.0)) + (was - float(st.pct))
	var t := team_of(b)
	if t >= 0:
		_tally(t, "healed", was - float(st.pct))
	_hp_sync(b)
	pct_changed.emit(b, float(st.pct), float(st.pct) - was)
	return was - float(st.pct)


## A lock of b's started (SwayCaster.lock_started, a bot's own lock): his spawn safety ends at once (spec §7.2).
func note_lock_started(b: Node) -> void:
	var st := _sk(b)
	if st.is_empty() or not stock_on():
		return
	if float(st.safe_until) > BendStatus.now():
		st["safe_until"] = BendStatus.now()


## A body's tally number `key` raised by `n` for its side (AIR, MOVE: "perfect_guards", "clean_catches", "edge_saves"; the
## match screen's).
func note_stat(b: Node, key: String, n := 1.0) -> void:
	var t := team_of(b)
	if t >= 0:
		_tally(t, key, n)


func _tally(t: int, key: String, n: float) -> void:
	var d := tally[t] as Dictionary
	d[key] = float(d.get(key, 0.0)) + n


## The game's start (stock): every competitor's lives full, his % 0, his string, his stale queue and his safety cleared.
func reset_game() -> void:
	for id in state:
		var st := state[id] as Dictionary
		_stock_init(st)
		st.erase("hp_set")
		if is_instance_valid(st.get("body")):
			_hp_sync(st.body)                # (zones: health full with the meter at 0)
	_stale.clear()
	_volleys.clear()
	_once.clear()
	tally = [{}, {}]
	falls = []
	sudden = false


## Every competitor's lives back to the game's start count (stocks, or team.stocks in team mode: RingMode.join grows a side).
func reset_lives() -> void:
	for id in state:
		var st := _sk((state[id] as Dictionary).body)
		if not st.is_empty() and not bool(st.gone):
			st["stocks"] = _stocks_each()


## Sudden death (spec §7.3): everyone still in at sudden.pct with one life; the next fall wins.
func start_sudden() -> void:
	sudden = true
	for id in state:
		var st := _sk((state[id] as Dictionary).body)
		if st.is_empty() or bool(st.gone):
			continue
		st["stocks"] = 1
		reset_pct(st.body, sub_num("sudden", "pct", 300.0))


## b back in play on the spout: safe until 1.5 s after he leaves it (left_spout; at once when nothing holds him there), or
## the moment any lock of his starts. respawned.
func respawn(b: Node3D, held_on_spout: bool) -> void:
	var st := _sk(b)
	if st.is_empty():
		return
	st["away"] = false
	st["string"] = {"hits": 0, "pct": 0.0, "by": null, "pop": false, "bounced": false, "m": 0}
	var after := sub_num("respawn", "safe_after_s", 1.5)
	st["safe_until"] = INF if held_on_spout else BendStatus.now() + after
	var kn := BendKnock.peek(b)
	if kn != null:
		kn.reset()
		kn.last_knocker = null
		kn.last_knock_at = -INF
	respawned.emit(b)


## b left the spout (RingMoves.left_spout): safe for respawn.safe_after_s more (unless a lock already ended it).
func left_spout(b: Node3D) -> void:
	var st := _sk(b)
	if st.is_empty():
		return
	if float(st.safe_until) > BendStatus.now():
		st["safe_until"] = BendStatus.now() + sub_num("respawn", "safe_after_s", 1.5)


# ---------------------------------------------------------------- round 3: a hit (BendStatus calls it)
## A hit on n by `by` (BendStatus.hurt / knock, stock only): the % added, the launch worked out (spec §2, §3) and returned:
## {v: Vector3 (the motion to SET), hitstun_s, tumble, refresh, d, tag, none (nothing to apply), safe}. Info keys: spec
## §14.3's hit info (tag, from, air, volley_id, volley_n, set_stun, slide_only, bounce_once, returned, ret_mult, origin_tag)
## and BendStatus's own: dmg (untagged damage), at (the hit point), dir (the hit's travel), v_given (the caller's knock).
## {} when the gate is off or n is no competitor: as today.
func on_hit(n: Node, by: Node, info: Dictionary) -> Dictionary:
	if not stock_on() or not (rule_set in NEW_RING):
		return {}
	var st := _sk(n)
	if st.is_empty():
		return {}
	if by != null and not is_instance_valid(by):
		by = null
	var none := {"none": true, "d": 0.0}
	if bool(st.get("away", false)) or bool(st.get("gone", false)):
		return none
	var at: Vector3 = info.get("at", (n as Node3D).global_position + Vector3.UP if n is Node3D else Vector3.ZERO)
	var now := BendStatus.now()
	if now < float(st.safe_until):
		if by != null and now - float(st.get("safe_hit_at", -INF)) > 0.25:
			st["safe_hit_at"] = now
			hit_safe.emit(n, by, at)
		var out := none.duplicate()
		out["safe"] = true
		return out
	var guard := String(info.get("guard", ""))
	if guard == "perfect":
		return none
	var late := bool(info.get("slide_only", false)) or guard == "late"
	var tag := String(info.get("tag", ""))
	if bool(info.get("wall_tick", false)) and tag.begins_with("fire_wall/"):
		tag = "fire_wall/tick"                   # (inside a Fire Wall after its entry pop: the burn, % only, no flinch)
	var returned := bool(info.get("returned", false))
	var cls: Dictionary
	if returned:
		cls = return_class(String(info.get("origin_tag", "")), float(info.get("ret_mult", 0.0)))
		# (the returner's worn numbers: only a Kiln Stone's heat reaches a return, a stone of his thrown back through fire,
		# info.heated; its ".return" tag is no class a node changes. Classic: as is)
		cls = BendLoadout.hit_class(by, cls, info)
	elif tag != "":
		cls = class_of(tag)
		if cls.is_empty():
			# (a worn behaviour talent's whole new class, a "+" variant's or its own tag's: Blazing Fireball's burst, Dragon Fire's
			# front, Hail Ball's hail, Blizzard's cold; Classic: none)
			cls = BendLoadout.new_hit_class(by, tag)
		cls = BendLoadout.hit_class(by, cls, info)    # (the hitter's worn numbers for this tag, a skill tree node's; Classic: as is)
	var untagged := cls.is_empty()
	if untagged:
		cls = _untagged_class(info)
	if cls.has("d_of_strike"):
		cls["d"] = float(cls.d_of_strike) * float(info.get("strike_d", 0.0))   # (a live reaction: its share of the strike's %)
	# (a class with once_s lands on the same body from the same attacker at most once a while: Fire Wall's entry pop)
	var once := float(cls.get("once_s", 0.0))
	if once > 0.0:
		var okey := "%s|%d|%d" % [String(cls.tag), by.get_instance_id() if by != null else 0, n.get_instance_id()]
		if now - float(_once.get(okey, -INF)) < once:
			return none
		_once[okey] = now
	if info.has("growth_mult"):
		cls["growth"] = float(cls.get("growth", 0.0)) * float(info.growth_mult)     # (the Geyser from a grate or a puddle)
	if String(info.get("wall_boost", "")) != "":
		# (a spell through its caster's own wall, BendBolt.wall_boost / GustLift.wall_boost: harder; the owner 2026-10-12)
		var wb := stock_block("wall_boost")
		cls["d"] = float(cls.get("d", 0.0)) * float(wb.get("d", 1.25))
		cls["growth"] = float(cls.get("growth", 0.0)) * float(wb.get("growth", 1.15))
	# a volley: one hit (its d spread over its n projectiles; only the first knocks, stuns and counts)
	var vn := maxi(int(info.get("volley_n", cls.get("volley_n", 1))), 1)
	var vid: Variant = info.get("volley_id", null)
	var first := true
	var vkey := ""
	var stale_k := 1.0
	if vid != null and vn > 1:
		vkey = "%s|%d" % [str(vid), n.get_instance_id()]
		if _volleys.has(vkey):
			first = false
			stale_k = float((_volleys[vkey] as Dictionary).get("stale_k", 1.0))
	# d after staling (returns never; a late guard's halves it), then pct_scale
	var d := float(cls.get("d", 0.0))
	if untagged:
		d = curve_d(float(info.get("dmg", 0.0)))
	# (a reaction stales as the move that set it off, info stale_as: the skill tree's reaction rules; Classic sends none)
	var stale_tag := String(info.get("stale_as", cls.tag))
	if first and not returned and not untagged and by != null and not stale_off:
		var copies := stale_count(by, stale_tag)
		stale_k = 1.0 - minf(sub_num("stale", "step", 0.08) * float(copies), sub_num("stale", "max", 0.4))
	d *= stale_k * stock_num("pct_scale", 1.0)
	# (a late guard's half; an untagged hit's damage and knock came already halved by the guard that let it through)
	if late and not untagged:
		d *= BendLoadout.tune_f(n, "stock:late_mult", stock_num("late_mult", 0.5))
	if first and vkey != "":
		_volleys[vkey] = {"stale_k": stale_k, "at": now}
		if _volleys.size() > 64:
			_prune_volleys(now)
	var d_add := d / float(vn)
	add_pct(n, d_add, by, String(cls.tag))
	if first and not late and d_add > 0.0 and not bool(info.get("no_hurt", false)) and not bool(info.get("wall_tick", false)):
		BendCombo.landed(by, n)                  # (the combo: a stack of the hitter's, all of the struck one's; the owner 2026-10-12)
	var res := {"none": true, "d": d_add, "tag": String(cls.tag)}
	if not first or bool(cls.get("no_flinch", false)):
		return res
	# drenched (a skill tree twist's hit, info.drench_s: BendStatus.drench): he runs slower a while, the hit's launch as ever; a
	# late guard halves it
	var drench_s := float(info.get("drench_s", 0.0))
	if drench_s > 0.0 and not returned:
		res["drench_s"] = BendStatus.drench(n, drench_s * (BendLoadout.tune_f(n, "stock:late_mult", stock_num("late_mult", 0.5)) if late else 1.0))
	# mud (where earth and water met in a guard, info.mud_s: a water Turn's mud spear, earth's mud wave; the owner, 2026-10-12:
	# "a mud spear or blast that slows"): drenched as Drenching Wave drenches, in mud; a return's own (mud is always one)
	var mud_s := float(info.get("mud_s", 0.0))
	if mud_s > 0.0:
		res["drench_s"] = maxf(float(res.get("drench_s", 0.0)), BendStatus.drench(n, mud_s * (BendLoadout.tune_f(n, "stock:late_mult",
				stock_num("late_mult", 0.5)) if late else 1.0), "mud"))
	# a bind (a skill tree twist's hit, info.bind_s: BendStatus.bind): his feet held, no launch, no hitstun, no string hit; a
	# late guard halves it
	var bind_s := float(info.get("bind_s", 0.0))
	if bind_s > 0.0 and not returned:
		# (its look in its own move's matter: Stone Grip's stone, Frost Geyser's ice, Static Shock's sparks, Tripwind's wind)
		res["bind_s"] = BendStatus.bind(n, bind_s * (BendLoadout.tune_f(n, "stock:late_mult", stock_num("late_mult", 0.5)) if late else 1.0),
				Bending.element_of(String(info.get("move", ""))))
		return res
	# the launch
	var lying := BendKnock.peek(n) != null and BendKnock.peek(n).lying_t > 0.0
	var w := weight_of(BendPoses.element_of(n))
	if BendStatus.rooted_mult(n) < 1.0:
		cls["base_mult"] = BendLoadout.tune_f(n, "stock:rooted_base", stock_num("rooted_base", 0.85))
	var range_m := 0.0
	var from: Variant = info.get("from", null)
	if from is Vector3:
		range_m = Vector2(at.x - (from as Vector3).x, at.z - (from as Vector3).z).length()
	var air := bool(info.get("air", false))
	var p := pct_of(n) if rule_set == "stock" else 0.0     # (zones: the meter never grows a launch)
	var v := launch_v(cls, p, d, w, range_m, air)
	if by != null and BendStatus.until(by, &"bend_carry_until") > 0.0:
		v *= BendLoadout.tune_f(by, "stock:carried_mult", stock_num("carried_mult", 1.15))
	if bool(cls.get("pull", false)) and by is Node3D and n is Node3D:
		var gap := Vector2((by as Node3D).global_position.x - (n as Node3D).global_position.x,
				(by as Node3D).global_position.z - (n as Node3D).global_position.z).length()
		v = minf(v, sqrt(2.0 * stock_num("pull_decel", 6.0) * maxf(gap - 0.6, 0.0)))
	if late and not untagged:
		v *= BendLoadout.tune_f(n, "stock:late_mult", stock_num("late_mult", 0.5))
	var ang := float(cls.get("angle", 30.0))
	var flat := _flat_way(n, by, info, String(cls.get("dir", "travel")))
	var stun := float(info.get("set_stun", cls.get("set_stun", -1.0)))
	if stun < 0.0:
		stun = hitstun_of(v)
	var on_floor := n is CharacterBody3D and (n as CharacterBody3D).is_on_floor()
	var sv := Vector3.ZERO
	# a new string unless he has had no free frame since the last hit (the old one closed first: its breather counts)
	if not stunned(n):
		if int((st.string as Dictionary).get("hits", 0)) > 0:
			_end_string(n as Node3D, st, now)
		st["string"] = {"hits": 0, "pct": 0.0, "by": null, "pop": false, "bounced": false, "m": 0}
	var str_d := st.string as Dictionary
	if lying:
		# (a hit on a lying body: a set push, a short stun, and he stands)
		var lh := stock_block("lying_hit")
		var a := deg_to_rad(float(lh.get("deg", 20.0)))
		sv = flat * cos(a) * float(lh.get("mps", 5.0)) + Vector3.UP * sin(a) * float(lh.get("mps", 5.0))
		stun = float(lh.get("stun_s", 0.2))
		BendKnock.of(n).getup("hit")
	elif bool(cls.get("slam", false)) and (on_floor or bool(info.get("bounce_once", false))):
		var sb := stock_block("slam_bounce")
		var down := v * sin(deg_to_rad(absf(ang)))
		if not bool(str_d.get("bounced", false)):
			var k := float(sb.get("k_earth" if BendPoses.element_of(n) == "earth" else "k", 0.45))
			sv = Vector3.UP * (k * down + float(sb.get("add_mps", 2.0)))
			stun = float(stock_block("set_stun").get("bounce", 0.45))
			str_d["bounced"] = true
		else:
			sv = flat * v * float(sb.get("flat_mult", 0.5))
	else:
		var a := deg_to_rad(ang)
		sv = flat * cos(a) * v + Vector3.UP * sin(a) * v
	var cap := stock_num("vy_cap", 16.0)
	sv.y = clampf(sv.y, -cap, cap)
	# the string (counted on the victim, any attacker): decay on every hit, the Pop exempt, the caps
	var m := int(str_d.get("hits", 0)) + 1
	var pop := bool(cls.get("pop", false))
	if not pop:
		stun *= maxf(pow(stock_num("string_decay", 0.8), float(m - 1)), stock_num("string_floor", 0.4))
	if bool(str_d.get("pop", false)) and bool(cls.get("jab", false)):
		stun = minf(stun, stock_num("after_pop_jab_s", 0.1))
	if m >= int(stock_num("string_cap", 6.0)):
		stun = minf(stun, stock_num("cap_stun_s", 0.1))
	if now < float(st.get("breather_until", -INF)):
		stun = minf(stun, sub_num("breather", "stun_s", 0.1))
	str_d["hits"] = m
	str_d["pct"] = float(str_d.get("pct", 0.0)) + d
	str_d["by"] = by
	str_d["m"] = m
	if pop:
		str_d["pop"] = true
	# the stale queue (landed, unguarded, never a return; a volley once)
	if by != null and not returned and not late and not untagged:
		var q: Array = _stale.get(by.get_instance_id(), [])
		q.append(stale_tag)
		while q.size() > int(sub_num("stale", "n", 6.0)):
			q.pop_front()
		_stale[by.get_instance_id()] = q
	# tumble or a flinch-slide on the feet
	var speed := sv.length()
	var tumble := (speed >= stock_num("tumble_mps", 9.0) or absf(ang) >= stock_num("tumble_deg", 60.0)) and not lying
	if late and on_floor:
		tumble = false
	if bool(cls.get("slam", false)) and on_floor:
		tumble = sv.y > 0.0
	if not tumble and on_floor and not lying:
		sv.y = 0.0
	var refresh := tumble and not bool(cls.get("set", false)) and not bool(cls.get("slam", false)) and not late
	# a knock-up's float (the class's float_s: the Column, the Geyser, the tapped Fissure and Kick; the owner 2026-10-11:
	# "knockups ... where they float for a time period", a helpless float): held near the top for it, his hitstun running
	# through the rise and the float with no escape (BendStatus.float_up); any launch ends a float he was in
	BendStatus.unfloat(n)
	var fl := float(cls.get("float_s", 0.0))
	if fl > 0.0 and tumble and sv.y > 0.0 and not late and not lying:
		var rise := sv.y / maxf(BendKnock.launch_gravity(), 1.0)
		var held_f := BendStatus.float_up(n, rise, fl)
		if held_f > 0.0:
			stun = maxf(stun, rise + held_f)
			if by != null and is_instance_valid(by) and not BendCaster.same_team(by, n):
				BendCombo.knocked_up(by, rise + held_f)   # (the follow-up: his other moves fill faster while it floats)
	if by != null:
		st["last_by"] = by
	launched.emit(n, sv, stun, by, String(cls.tag))
	return {"none": false, "v": sv, "hitstun_s": stun, "tumble": tumble, "refresh": refresh, "d": d_add, "tag": String(cls.tag),
			"lying": lying, "drench_s": float(res.get("drench_s", 0.0))}


## An untagged hit's class (no tag, or a tag with no class): its d by the curve, a launch from the caller's own knock speed
## (untagged.base_k of it) growing by untagged.growth, at the caller's own angle.
func _untagged_class(info: Dictionary) -> Dictionary:
	var u := stock_block("untagged")
	var vg: Vector3 = info.get("v_given", Vector3.ZERO)
	var flat := Vector2(vg.x, vg.z).length()
	var ang := rad_to_deg(atan2(vg.y, maxf(flat, 0.001))) if vg.length() > 0.01 else 20.0
	return {"tag": String(info.get("tag", "")), "d": 0.0, "base": vg.length() * float(u.get("base_k", 0.6)),
			"growth": float(u.get("growth", 8.0)), "angle": clampf(ang, -70.0, 65.0), "untagged": true}


## The hit's flat way (unit): the caller's knock or the hit's travel, else caster to target; toward the caster for a Pull.
func _flat_way(n: Node, by: Node, info: Dictionary, how: String) -> Vector3:
	var np := (n as Node3D).global_position if n is Node3D else Vector3.ZERO
	var bp := (by as Node3D).global_position if by is Node3D else np - Vector3.FORWARD
	var away := Vector3(np.x - bp.x, 0.0, np.z - bp.z)
	if how == "to_caster":
		return -away.normalized() if away.length() > 0.05 else Vector3.FORWARD
	for key: String in ["dir", "v_given"]:
		var v: Variant = info.get(key, null)
		if v is Vector3:
			var f := Vector3((v as Vector3).x, 0.0, (v as Vector3).z)
			if f.length() > 0.2 * maxf((v as Vector3).length(), 0.001) and f.length() > 1e-3:
				return f.normalized()
	return away.normalized() if away.length() > 0.05 else Vector3.FORWARD


func _prune_volleys(now: float) -> void:
	for k in _volleys.keys():
		if now - float((_volleys[k] as Dictionary).get("at", 0.0)) > 3.0:
			_volleys.erase(k)


## The health b has lost (raw damage), his health put back full (stock: health is never touched; zones: put back to what the
## meter shows, _hp_sync's).
func take_deficit(b: Node3D) -> float:
	var deficit := 0.0
	if rule_set == "zones":
		var shown: Variant = _st(b).get("hp_set", _hp_max(b))     # (none shown yet: the meter at 0, health full)
		var now_hp := _hp(b)
		if now_hp < 0.0:
			return 0.0
		deficit = float(shown) - now_hp
		if deficit > 0.01:
			_set_hp(b, float(shown))
		return deficit if deficit > 0.01 else 0.0
	if b is FrontierPlayer:
		var p := b as FrontierPlayer
		deficit = p.max_health - p.health
		if deficit > 0.01:
			p.health = p.max_health
	elif b is NpcFighter:
		var f := b as NpcFighter
		deficit = f.health_max - f.health
		if deficit > 0.01:
			f.health = f.health_max
	return deficit if deficit > 0.01 else 0.0


## Damage that reached b's health anyway (Hit.deliver, an untagged blow: spec §2.1): turned into % by the curve and his health
## put back full (health is never touched in the stock ring).
func absorb(b: Node3D, by: Node = null) -> float:
	var deficit := take_deficit(b)
	if deficit <= 0.01:
		return 0.0
	var d := curve_d(deficit) * stock_num("pct_scale", 1.0)
	if by == null:
		var kn := BendKnock.peek(b)
		by = kn.last_knocker if kn != null and kn.knocked_within(0.2) else null
	add_pct(b, d, by, "")
	return d


# ---------------------------------------------------------------- round 3: each frame (stock)
func _stock_frame(_dt: float) -> void:
	var now := BendStatus.now()
	for id in state.keys():
		var st := _sk((state.get(id, {}) as Dictionary).get("body"))
		if st.is_empty():
			continue
		var b: Variant = st.get("body")
		if not (b is Node3D) or not is_instance_valid(b):
			continue
		var body := b as Node3D
		if bool(st.away) or bool(st.gone) or not body.is_inside_tree():
			continue
		if body.has_meta(RingNet.PUPPET_META):
			continue                             # (a remote body online: judged on its owner's machine, RingNet)
		if live:
			absorb(body)
		# the string over on his first free frame
		if int((st.string as Dictionary).get("hits", 0)) > 0 and not stunned(body):
			_end_string(body, st, now)
		if not live:
			continue
		if ring != null and ring.is_ring_out(body):
			_ko(body)


## The string on `body` over (his first free frame): string_ended(by, victim, hits, pct), the breather after breather.min_hits
## or more, the attacker side's longest string kept for the match screen.
func _end_string(body: Node3D, st: Dictionary, now: float) -> void:
	var sd := st.string as Dictionary
	var hits := int(sd.get("hits", 0))
	var by_v: Variant = sd.get("by")
	var sby: Node = by_v as Node if by_v is Node and is_instance_valid(by_v) else null
	if hits >= int(sub_num("breather", "min_hits", 4.0)):
		st["breather_until"] = now + sub_num("breather", "s", 0.4)
	st["string"] = {"hits": 0, "pct": 0.0, "by": null, "pop": false, "bounced": false, "m": 0}
	# (the string is over and he is still in: the % he survived)
	st["best_pct"] = maxf(float(st.get("best_pct", 0.0)), pct_of(body))
	var vt := team_of(body)
	if vt >= 0:
		(tally[vt] as Dictionary)["best_pct"] = maxf(float((tally[vt] as Dictionary).get("best_pct", 0.0)), pct_of(body))
	string_ended.emit(sby, body, hits, float(sd.get("pct", 0.0)))
	if sby != null:
		var t := team_of(sby)
		if t >= 0:
			var best := tally[t] as Dictionary
			if hits > int(best.get("string_hits", 0)) or (hits == int(best.get("string_hits", 0))
					and float(sd.get("pct", 0.0)) > float(best.get("string_pct", 0.0))):
				best["string_hits"] = hits
				best["string_pct"] = float(sd.get("pct", 0.0))


# ---------------------------------------------------------------- zones on the new ring: each frame (rule_set "zones")
## The meter at which a body is winded (zones.wind_pct).
static func wind_pct() -> float:
	return float((data().get("zones", {}) as Dictionary).get("wind_pct", 100.0)) if data().get("zones") is Dictionary else 100.0


## Each frame (zones): stray damage onto the meter, a string over on its first free frame (as stock); then, live, the water
## (out of the round), the meter full (winded), a launch carrying him back over a zone line (confined to it), the soft walls.
func _zones_frame(dt: float) -> void:
	var now := BendStatus.now()
	for id in state.keys():
		var st := _sk((state.get(id, {}) as Dictionary).get("body"))
		if st.is_empty():
			continue
		var b: Variant = st.get("body")
		if not (b is Node3D) or not is_instance_valid(b):
			continue
		var body := b as Node3D
		if bool(st.out) or not body.is_inside_tree():
			continue
		if body.has_meta(RingNet.PUPPET_META):
			continue                             # (a remote body online: judged on its owner's machine, RingNet)
		if live:
			absorb(body)
		if int((st.string as Dictionary).get("hits", 0)) > 0 and not stunned(body):
			_end_string(body, st, now)
		if not live or ring == null:
			continue
		if ring.is_ring_out(body):
			_out(body, credit(body), "ringout")
			if not live:
				return
			continue
		if body is NpcFighter and (body as NpcFighter).arm_broken != "":
			(body as NpcFighter).arm_broken = ""   # (no running from the deck on a broken arm: the ring's no maims)
		if pct_of(body) >= wind_pct():
			var lb: Variant = st.get("last_by")
			_zones_wind(body, lb as Node if lb is Node and is_instance_valid(lb) else null)
			if not live:
				return
			if bool(st.out):
				continue
		_tug_judge(body, st)
		_walls(body, end_of(body), dt)


## The meter full (zones): pushed back a zone (set winded_back_m behind its line, his launch ended), the meter down to
## winded_refill's share of it; winded in the last zone: out of the round, the winder's.
func _zones_wind(b: Node3D, by: Node) -> void:
	var st := _st(b)
	if st.is_empty() or bool(st.out):
		return
	var who: Node = by if by != null and is_instance_valid(by) and by != b else credit(b)
	if who != null:
		st["by"] = who
	reset_pct(b, wind_pct() * (1.0 - clampf(num("winded_refill", 0.4), 0.0, 1.0)))
	var c := int(st.confined)
	var t := int(st.team)
	if lost(t) >= zones() - 1:
		_out(b, who, "winded")
		return
	_give(t, 1)                              # (the tug of war: the front a zone toward his end)
	var to := int(st.confined)
	var e := end_of(b)
	var l := lost(t)
	var want := (ring.line_s(e, l) if l > 0 else -ring.line_s(e, -l)) + num("winded_back_m", 0.6)
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
	BendStatus.unfloat(b)
	knocked_back.emit(b, c, to)
	winded.emit(b, who, to)


## Zones: the body's health shows the meter (full at 0, empty at wind_pct): the zones' HUD, health_frac and the time-out read
## it; hp_set keeps what was shown (take_deficit: damage that reached health past it goes onto the meter).
func _hp_sync(b: Node) -> void:
	if rule_set != "zones" or not (b is Node3D) or not is_instance_valid(b):
		return
	var st := _st(b)
	if st.is_empty():
		return
	var most := _hp_max(b)
	if most <= 0.0:
		return
	var v := most * clampf(1.0 - pct_of(b) / maxf(wind_pct(), 1.0), 0.0, 1.0)
	v = maxf(v, 0.5)                         # (never 0 from the meter: the body's own winding is the meter's, not its)
	_set_hp(b, v)
	st["hp_set"] = v


func _hp(b: Node) -> float:
	if b is FrontierPlayer:
		return (b as FrontierPlayer).health
	if b is NpcFighter:
		return (b as NpcFighter).health
	return -1.0


func _hp_max(b: Node) -> float:
	if b is FrontierPlayer:
		return (b as FrontierPlayer).max_health
	if b is NpcFighter:
		return (b as NpcFighter).health_max
	return 0.0


func _set_hp(b: Node, v: float) -> void:
	if b is FrontierPlayer:
		(b as FrontierPlayer).health = v
	elif b is NpcFighter:
		(b as NpcFighter).health = v


## b into the water (spec §7.1, §5.2): a life gone, credited to the last knocker within knock_credit_s (else his own fall),
## his % to 0, ko(b, by, pct, tag, stocks_left); out of lives: gone, and his side out when it was the last of them. Online
## (NetMatch) a machine that is not the referee tells the host instead, whose word takes it on every machine (take_ko).
func _ko(b: Node3D) -> void:
	var st := _sk(b)
	if st.is_empty() or bool(st.away) or bool(st.gone):
		return
	var by: Node = null
	var kn := BendKnock.peek(b)
	if kn != null and kn.knocked_within(stock_num("knock_credit_s", 6.0)) and kn.last_knocker != b:
		by = kn.last_knocker
	var pct := pct_of(b)
	var tag := String(st.get("last_tag", "")) if by != null else ""
	if not NetSpells.decides():
		NetMatch.report_fall(b, by, pct, tag)
		return
	take_ko(b, by, pct, tag)


## A fall of b's taken on these books (_ko's; online the host's word, NetMatch: `left` the lives the host left him, -1 these
## books' own count): see _ko. The referee's word to the others.
func take_ko(b: Node3D, by: Node, pct: float, tag: String, left := -1) -> void:
	var st := _sk(b)
	if st.is_empty() or bool(st.away) or bool(st.gone):
		return
	if b.has_meta(&"net_fell"):
		b.remove_meta(&"net_fell")
	var kn := BendKnock.peek(b)
	st["away"] = true
	if not lives_on:
		# (Practice: no lives; the % to 0, both put back: RingMode -> RingPractice.on_out through side_out; out until then)
		st["out"] = true
		falls.append({"who": b, "by": by, "pct": pct, "tag": tag, "at": BendStatus.now(), "team": team_of(b), "left": int(st.stocks), "pos": b.global_position})
		reset_pct(b, 0.0)
		if kn != null:
			kn.reset()
		ko.emit(b, by, pct, tag, int(st.stocks))
		rang_out.emit(b, by)
		side_out.emit(team_of(b))
		return
	st["stocks"] = maxi(int(st.stocks) - 1, 0) if left < 0 else left
	left = int(st.stocks)
	st["safe_until"] = -INF
	st["string"] = {"hits": 0, "pct": 0.0, "by": null, "pop": false, "bounced": false, "m": 0}
	var t := team_of(b)
	if by != null and team_of(by) >= 0:
		_tally(team_of(by), "falls_dealt", 1.0)
	if t >= 0:
		_tally(t, "falls_taken", 1.0)
		if by == null:
			_tally(t, "self_falls", 1.0)
	falls.append({"who": b, "by": by, "pct": pct, "tag": tag, "at": BendStatus.now(), "team": t, "left": left, "pos": b.global_position})
	last_out = {"who": b, "by": by, "why": "falls"}
	reset_pct(b, 0.0)
	if kn != null:
		kn.reset()
	if left <= 0:
		st["gone"] = true
		st["out"] = true
		st["by"] = by
		st["why"] = "falls"
	if NetSpells.online() and NetSpells.decides():
		NetSpells.word(["m_ko", b, by, pct, tag, left])     # (online: the referee's word, every machine's books alike)
	ko.emit(b, by, pct, tag, left)
	rang_out.emit(b, by)
	if left <= 0:
		for o in sides[t]:
			if is_instance_valid(o) and not is_gone(o):
				return
		if team_mode():
			knocked_out = t
		side_out.emit(t)


## Lives left on team `team` (summed over its competitors).
func team_stocks(team: int) -> int:
	var n := 0
	for b in sides[team]:
		if is_instance_valid(b):
			n += stocks_of(b)
	return n


## Whether `n` may be taken now (BendStatus.take_filters, stock only): not while away (respawning) and not in a body's own
## intangible moment (a fall broken, the first of lying down, standing up).
func take_ok(n: Node, _caster: Node) -> bool:
	if not stock_on():
		return true
	var st := _st(n)
	if st.is_empty():
		return true
	if bool(st.get("away", false)) or bool(st.get("gone", false)):
		return false
	var kn := BendKnock.peek(n)
	return kn == null or not kn.intangible()
