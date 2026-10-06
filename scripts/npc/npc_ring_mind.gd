class_name NpcRingMind
extends RefCounted
## An element bot's mind in Tidebreak's % ring (round 3, smash_r3 spec §9; BOTS' file): made by NpcBending (its `mind()`)
## and run ONLY while RingRules.stock_on() (THE GATE: in the open world, the duel and the classic ring NpcBending never makes
## one, and its round-2 behaviour is exactly as before). Every number in data/npc/bend_ai.json "pct".
##   the body     the bot moves only by its pad (NpcPad: the player's own intent, MOVE's RingMoves.pre reads it), so it has
##                the player's jumps, dodges, Rise, edge options and gravity and nothing else; it never writes velocity
##   the states   NEUTRAL, PRESSURE, EDGEGUARD, LEDGETRAP, REELING, RECOVER, LEDGE, RESPAWN, picked each tick from what both
##                bodies show (_pick_state). The choices (NEUTRAL, PRESSURE, EDGEGUARD, LEDGETRAP) hold state_hold_s unless a
##                hit lands; the body's states (REELING, RECOVER, LEDGE, RESPAWN) are what the body is, taken at once.
##                Round 2's chooser (NpcBending._choose) runs only in NEUTRAL and PRESSURE, its options weighed by weight()
##   the KO read  before a cast: the rules' own launch (RingRules.class_of, launch_v) flown by RingPredict.flight from the
##                foe's place (normal: read ko_margin_m further in; hard: the foe's best steering too); a killing option x
##                ko_bonus, x far_finisher_mult from past far_finisher_m (it walks in to finish: keep_band), the build bias
##                below build_pct, hard's fresh finisher; no bonus for the up-launchers
##   strings      after its hit lands (RingRules.launched by it), a follow-up of the string table begins at once, only while
##                RingRules.hitstun_left(foe) >= its lock + its flight - 1/60 (true); at most one read ends a string; never the
##                same move twice in a row (jabs aside: the step and the Pop); the length and the chance by preset
##   the victim   its steer set once in pad.di at the launch (survive_pct and up: the yaw with the longest way to the water;
##                below: across the hitter's line), the escape pressed fresh when RingRules.can_escape says so, E pressed
##                tech_lead_s before it meets the deck tumbling, up from lying down; each by its preset's chance
##   recovery     off the deck and free: the six plans simulated on its own mover (move_sim: MOVE's RingMoves.simulate on its
##                body's RingMoves; a test's stand-in mover on the stand-in below) every recover_replan_s toward the nearest
##                open lip, the first that comes back in its preset's order run through the pad; never a 4th grab without the
##                deck. The body's states own the pad: a walk order left from before is let go (halt)
##   the edge     LEDGE: its option by preset, always before its first-grab safety and the hang's end. LEDGETRAP and
##                EDGEGUARD: keeping him off (shots from inside the lip at where he will be, hard's pre-filled lock let go as
##                his safety ends or his Rise shows, hard's safe-only chase), never a hit into a safety (allow_release)
##   the spout    leaves it by preset (hard: the full time with the foe under it, else at once); a respawn clears its lock,
##                threats and string and keeps its match memory
##   healing      Patch only by the rule (heal_ok): fresh % of min_fresh or more, on its feet, the foe min_dist_m away and
##                not winding up at it, and RingRules.heal_allowed
##   fairness     reads %, lives, positions, poses and wind-ups only, never inputs; air_scatter_mult and air_lead at a body in
##                the air; above high_pct of its own: reaction + high_react_s and centre_pull
## Counted for the tests and the soak: stats, time_in (seconds per state).
## Tests: simulate_override (a look-ahead in place of RingMoves.simulate) and predict_override (an object with flight() and
## would_ko() in place of RingPredict) stand in for MOVE's parts until they are merged.

enum S { NEUTRAL, PRESSURE, EDGEGUARD, LEDGETRAP, REELING, RECOVER, LEDGE, RESPAWN }
const STATE_NAMES := ["NEUTRAL", "PRESSURE", "EDGEGUARD", "LEDGETRAP", "REELING", "RECOVER", "LEDGE", "RESPAWN"]
## What the body is (taken at once); the rest are choices (held state_hold_s unless a hit lands).
const BODY_STATES := [S.REELING, S.RECOVER, S.LEDGE, S.RESPAWN]
## The foe's edge options counted (RingMoves.moved kinds) for hard's cover.
const EDGE_KINDS := ["climb", "ledge_jump", "ledge_roll", "ledge_attack"]
## The plans' names (spec §9.6).
const PLANS := {1: "drift", 2: "late_double", 3: "double_now", 4: "rise_edge", 5: "rise_high", 6: "dodge_first"}
## MOVE's mover script (a body with exactly it is planned on RingMoves.simulate; a test's stand-in mover on the stand-in).
const RING_MOVES := preload("res://scripts/ring/ring_moves.gd")

## Tests: a mover's look-ahead in place of RingMoves.simulate ((state, plan, dt, horizon) -> {ok, how, t, pos}).
static var simulate_override := Callable()
## Tests: an object with flight(v, hitstun_s, from, element) and would_ko(tag, target, from, dir, range_m, air) in place of
## RingPredict's statics.
static var predict_override: Object = null

var bend: NpcBending
var me: NpcFighter
var state := S.NEUTRAL
## Seconds in the state now; seconds in each state over the match (STATE_NAMES).
var state_t := 0.0
var time_in := {}
## Practice: the dummy's steering ("": its preset's; "none", "in", "out", "random").
var steer_way := ""
## Practice: off (the dummy's way runs it): no chooser of its own, no keeping off; its recovery and its steering still run.
var practice_dummy := false
## Counts (tests, soak): see _new_stats.
var stats := {}
## The string it runs on the foe now: {hits, keys: [], pct, began_at, read_done, rolled, go}.
var string := {}
## Each follow-up's margin at its start (hitstun_left - lock - flight; a true string's are >= -1/60).
var string_margins: Array[float] = []
## The plan running now ({} none): {n, name, events, t0, target, aim}.
var plan := {}
## The foe's edge options seen (EDGE_KINDS -> n): hard covers the favourite.
var foe_edge := {}

var _rules_seen: RingRules = null
var _moves_seen := {}
var _launch := {}
var _replan_t := 0.0
var _ledge := {}
var _spout_t := 0.0
var _edge_roll := {}
var _edge_ep := -1
var _finisher_far := false
var _hold_t := 0.0
var _foe_rise_t := -INF
var _own_jumps_used := 0
var _own_dodged := false
var _own_rised := false
var _grabs := 0
var _was_hanging := false
var _hit_lands_t := -INF
var _pad_local: NpcPad = null
var _arena: RingArena = null
var _last_jab_release := -INF
var _last_jab_hit := false
var _lying_seen := -INF
var _spout_left := false


func _init(b: NpcBending) -> void:
	bend = b
	me = b.me
	stats = _new_stats()
	for n: String in STATE_NAMES:
		time_in[n] = 0.0


static func _new_stats() -> Dictionary:
	return {"ko_reads": 0, "ko_kills": 0, "ko_casts": 0, "ko_cast_far": 0, "finisher_m": [], "strings": 0, "follow_ups": 0,
			"string_false": 0, "reads": 0, "longest_string": 0, "launches": 0, "di_set": 0, "di_right": 0, "break_outs": 0,
			"break_rolls": 0, "techs": 0, "tech_rolls": 0, "getups": 0, "recovers": 0, "recover_ok": 0, "recover_fail": 0,
			"plans_by": {}, "desperate": 0, "edge_opts": {}, "grabs": 0, "grabs_refused": 0, "keep_off_casts": 0,
			"safety_holds": 0, "held_out": 0, "chases": 0, "patches": 0, "spout_leaves": 0, "velocity_writes": 0, "self_falls": 0}


# ---------------------------------------------------------------- data
static func pct_data() -> Dictionary:
	return (NpcBending.ai().get("pct", {}) as Dictionary)


static func pnum(key: String, def: float) -> float:
	return float(pct_data().get(key, def))


## The preset's pct numbers (easy, normal, hard; normal for one with none).
static func pp_of(name: String) -> Dictionary:
	var ps: Dictionary = pct_data().get("presets", {})
	return ps.get(name, ps.get("normal", {}))


func pp() -> Dictionary:
	return pp_of(bend._preset_name())


static func standin_nums() -> Dictionary:
	return pct_data().get("standin", {})


# ---------------------------------------------------------------- what it reads (the rules, the bodies)
func rules() -> RingRules:
	return RingRules.current()


func target() -> Node3D:
	var t := bend.brain.target if bend.brain != null else null
	return t if t != null and is_instance_valid(t) else null


func pct_of(b: Node) -> float:
	var r := rules()
	return r.pct_of(b) if r != null and b != null else 0.0


func now() -> float:
	return BendStatus.now()


## The bot's pad (NpcBending's: NpcFighter.pad when MOVE's body has one, else its own).
func pad() -> NpcPad:
	return bend.pad()


func arena() -> RingArena:
	if _arena != null and is_instance_valid(_arena):
		return _arena
	if me.is_inside_tree():
		_arena = me.get_tree().get_first_node_in_group(RingArena.GROUP) as RingArena
	return _arena


## Element of body `b` (a bot's, the player's quick element, else "water").
static func element_of(b: Node) -> String:
	if b == null or not is_instance_valid(b):
		return "water"
	var e: Variant = b.get(&"element")
	if e is String and String(e) in Bending.ELEMENTS:
		return String(e)
	var sc := SwayCaster.of(b) if b is FrontierPlayer else null
	if sc != null and sc.quick_element() in Bending.ELEMENTS:
		return sc.quick_element()
	var bw := Bending.of(b)
	return bw.element if bw != null and bw.element in Bending.ELEMENTS else "water"


## Over the water: RingMoves' answer, else the deck's geometry (feet outside its rectangle, or under the lip by 0.3 m).
func off_deck(b: Node3D) -> bool:
	var m := RingMoves.of(b)
	if m != null:
		return m.off_deck()
	var a := arena()
	if a == null or b == null:
		return false
	var lip := a.nearest_lip(b.global_position)
	return float(lip.out_m) > 0.0 or b.global_position.y < a.lip_y() - 0.3


func on_ledge(b: Node3D) -> bool:
	var m := RingMoves.of(b)
	return m != null and m.on_ledge()


func on_spout(b: Node3D) -> bool:
	var m := RingMoves.of(b)
	return m != null and m.on_spout()


func airborne(b: Node3D) -> bool:
	var m := RingMoves.of(b)
	if m != null:
		return m.airborne()
	return b is CharacterBody3D and not (b as CharacterBody3D).is_on_floor()


## Hits pass through `b` now: its spawn safety (RingRules.safe_until) or a dodge's or a first grab's window (RingMoves).
func safe(b: Node3D, within := 0.0) -> bool:
	var r := rules()
	if r != null and r.safe_until(b) > now() + within:
		return true
	var m := RingMoves.of(b)
	if m == null:
		return false
	if m.on_ledge() and m.ledge_safe_left() > within:
		return true
	return m.intangible() and within <= 0.05


func hitstun_left(b: Node) -> float:
	var r := rules()
	return r.hitstun_left(b) if r != null else 0.0


func stunned() -> bool:
	var r := rules()
	if r != null and (r.stunned(me) or r.hitstun_left(me) > 0.0):
		return true
	var kn := BendKnock.peek(me)
	return kn != null and kn.stun_t > 0.0


## The flat way from `a` to `b`.
static func flat_dir(a: Vector3, b: Vector3) -> Vector3:
	var v := b - a
	v.y = 0.0
	return v.normalized() if v.length_squared() > 1e-6 else Vector3.ZERO


static func flat_d(a: Vector3, b: Vector3) -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()


# ---------------------------------------------------------------- the signals it listens to
## The rules' signals (once per RingRules) and both bodies' RingMoves.moved.
func _listen() -> void:
	var r := rules()
	if r != null and r != _rules_seen:
		_rules_seen = r
		r.launched.connect(_on_launched)
		r.ko.connect(_on_ko)
		r.respawned.connect(_on_respawned)
	for b: Node3D in [me, target()]:
		if b == null:
			continue
		var m := RingMoves.of(b)
		if m == null or _moves_seen.has(m.get_instance_id()):
			continue
		_moves_seen[m.get_instance_id()] = true
		m.moved.connect(_on_moved.bind(b))


func _on_launched(b: Node3D, v: Vector3, hitstun_s: float, by: Node, tag: String) -> void:
	if b == me:
		_on_me_launched(v, hitstun_s, by)
	elif by == me and b == target():
		_on_landed(tag, hitstun_s)


func _on_ko(b: Node3D, by: Node, _pct: float, _tag: String, _left: int) -> void:
	if b == me:
		_end_string()
		plan = {}
		_grabs = 0
		_launch = {}
		pad().di = Vector3.ZERO
		if by == null or by == me:
			stats.self_falls = int(stats.get("self_falls", 0)) + 1
	elif b == target():
		_end_string()


func _on_respawned(b: Node3D) -> void:
	if b != me:
		return
	# (back on the spout: its lock, threats and string cleared, its match memory kept)
	bend._cancel()
	bend._threat_seen.clear()
	bend._floor.clear()
	_end_string()
	plan = {}
	_spout_t = 0.0
	_grabs = 0


func _on_moved(kind: String, b: Node3D) -> void:
	if b == me:
		match kind:
			"grab", "scramble":
				_grabs += 1
				stats.grabs += 1
			"jump", "double_jump":
				_own_jumps_used += 1
	elif b == target():
		if kind in EDGE_KINDS:
			foe_edge[kind] = int(foe_edge.get(kind, 0)) + 1
		elif kind == "rise":
			_foe_rise_t = now()


# ---------------------------------------------------------------- each frame
## Each physics frame before NpcBending's own (the gate is the caller's). True: this frame is the body's (REELING, RECOVER,
## LEDGE, RESPAWN): no lock begun, the lock waiting.
func tick(dt: float) -> bool:
	_listen()
	var p := pad()
	var want := _pick_state()
	if want != state:
		var body_change := want in BODY_STATES or state in BODY_STATES
		if body_change or state_t >= pnum("state_hold_s", 0.2) or now() - _hit_lands_t < dt * 1.5:
			_enter(want)
	state_t += dt
	time_in[STATE_NAMES[state]] = float(time_in.get(STATE_NAMES[state], 0.0)) + dt
	if state in BODY_STATES and me.get(&"_goal") != Vector3.INF:
		me.halt()                                  # (the body's states own the pad: no walk order left from before writes it)
	if not airborne(me) and not off_deck(me):
		_own_jumps_used = 0
		_own_dodged = false
		_own_rised = false
		_grabs = 0
	match state:
		S.REELING:
			_reel(dt)
			return true
		S.RECOVER:
			_recover(dt)
			return true
		S.LEDGE:
			_hang(dt)
			return true
		S.RESPAWN:
			_spout(dt)
			return true
	if p.di != Vector3.ZERO and not stunned():
		p.di = Vector3.ZERO
	_lying_up()
	return false


## The state from what both bodies show now.
func _pick_state() -> int:
	if on_spout(me):
		return S.RESPAWN
	if stunned():
		return S.REELING
	if on_ledge(me):
		return S.LEDGE
	if off_deck(me) and airborne(me):
		return S.RECOVER
	var t := target()
	if t != null and NpcSenses.can_fight(t) and not practice_dummy:
		if on_ledge(t):
			return S.LEDGETRAP
		if off_deck(t):
			return S.EDGEGUARD
		if not string.is_empty() and hitstun_left(t) > 0.0:
			return S.PRESSURE
	return S.NEUTRAL


func _enter(s: int) -> void:
	var was := state
	state = s
	state_t = 0.0
	match s:
		S.RECOVER:
			_replan_t = 0.0
			stats.recovers += 1
		S.LEDGE:
			_ledge = {}
		S.RESPAWN:
			_spout_t = 0.0
			_spout_left = false
		S.EDGEGUARD:
			_edge_roll = {}
	if was == S.RECOVER and s != S.RECOVER:
		var back := not off_deck(me) or on_ledge(me)
		if back:
			stats.recover_ok += 1
		plan = {}
		pad().move = Vector3.ZERO


## Round 2's chooser runs now (NEUTRAL, PRESSURE).
func chooser_on() -> bool:
	return state in [S.NEUTRAL, S.PRESSURE] and not practice_dummy


## Each think (0.25 s): true when the mind handled it (every state but NEUTRAL and PRESSURE: the chooser's).
func think(_dt: float) -> bool:
	match state:
		S.NEUTRAL, S.PRESSURE:
			return practice_dummy
		S.EDGEGUARD:
			_keep_off()
			return true
		S.LEDGETRAP:
			_ledge_trap()
			return true
	return true


# ---------------------------------------------------------------- the KO read and the chooser's weights
## The move's tag for the rules (RingRules.class_of): "id/mode", ".grown" when it will be cast grown.
static func tag_of(key: String, grown := false) -> String:
	return key + (".grown" if grown else "")


## Its stale multiplier for `tag` (rules.json stock.stale: step a copy, at most max).
func stale_mult(tag: String) -> float:
	var r := rules()
	if r == null:
		return 1.0
	var st := RingRules.stock_block("stale")
	var n := r.stale_count(me, tag)
	return 1.0 - minf(float(st.get("step", 0.08)) * n, float(st.get("max", 0.4)))


## Hitstun of a launch at `v` m/s (rules.json stock: hitstun_k, clamped).
static func hitstun_of(v: float) -> float:
	return clampf(RingRules.stock_num("hitstun_k", 0.045) * v, RingRules.stock_num("hitstun_min", 0.12),
			RingRules.stock_num("hitstun_max", 1.2))


## Where a launch at `v` from `from` lands (RingPredict.flight, or the tests' stand-in).
func flight(v: Vector3, hitstun_s: float, from: Vector3, el: String) -> Dictionary:
	if predict_override != null:
		return predict_override.call(&"flight", v, hitstun_s, from, el)
	return RingPredict.flight(v, hitstun_s, from, el)


func _would_ko(tag: String, t: Node3D, from: Vector3, dir: Vector3, range_m: float, air: bool) -> bool:
	if predict_override != null:
		return bool(predict_override.call(&"would_ko", tag, t, from, dir, range_m, air))
	return RingPredict.would_ko(tag, t, from, dir, range_m, air)


## Whether option `o` cast now would put `t` in the water, by the preset's read ("never" easy; "margin" normal: read the
## foe ko_margin_m further in; "worst" hard: that and his best steering, di_deg each way).
func ko_read(o: Dictionary, t: Node3D) -> bool:
	var how := String(pp().get("ko_read", "margin"))
	if how == "never" or t == null:
		return false
	var key := String(o.key)
	if key in (pct_data().get("uplaunch", []) as Array):
		return false
	stats.ko_reads += 1
	var tag := tag_of(key)
	var from := me.global_position
	var tp := t.global_position
	var dir := flat_dir(from, tp)
	var range_m := flat_d(from, tp)
	var air := airborne(me)
	var cls := RingRules.class_of(tag)
	var kill := false
	if cls.is_empty() or bool(cls.get("set", false)):
		kill = not bool(cls.get("set", false)) and _would_ko(tag, t, from, dir, range_m, air)
	else:
		var d := float(cls.get("d", 0.0)) * stale_mult(tag) * RingRules.stock_num("pct_scale", 1.0)
		var w := RingRules.weight_of(element_of(t))
		var v := RingRules.launch_v(cls, pct_of(t) + d, d, w, range_m, air)
		var ang := deg_to_rad(float(cls.get("angle", 30.0)))
		var margin := float(pp().get("ko_margin_m", 0.0)) if how in ["margin", "worst"] else 0.0
		var start := tp - dir * margin
		var yaws: Array = [0.0]
		if how == "worst":
			var di := deg_to_rad(pnum("di_deg", 15.0))
			yaws = [-di, 0.0, di]
		kill = true
		for y: float in yaws:
			var fd := dir.rotated(Vector3.UP, y)
			var vel := fd * v * cos(ang) + Vector3.UP * minf(v * sin(ang), RingRules.stock_num("vy_cap", 16.0))
			var f := flight(vel, hitstun_of(v), start, element_of(t))
			if String(f.get("lands", "deck")) != "water":
				kill = false
				break
	if kill:
		stats.ko_kills += 1
	return kill


## Whether option `o` is a launch class that can KO (not a set knock, not an up-launcher).
func is_finisher(o: Dictionary) -> bool:
	var key := String(o.key)
	if key in (pct_data().get("uplaunch", []) as Array) or bool(o.get("jab", false)) or bool(o.get("guard", false)):
		return false
	var cls := RingRules.class_of(key)
	if not cls.is_empty():
		return not bool(cls.get("set", false))
	# (no class yet: an offence move's that knocks, or an old spell's: the Spike, the Boulder)
	var role := String((o.get("hint", {}) as Dictionary).get("role", ""))
	return role == "offence" and (float(o.get("knock", 0.0)) >= 4.0 or bool(o.get("old", false)))


## % per lock second of option `o` (its class's d, else the untagged curve of its damage), for the build bias.
func pct_rate(o: Dictionary) -> float:
	var cls := RingRules.class_of(String(o.key))
	var d := float(cls.get("d", 0.0))
	if cls.is_empty():
		var dmg := float((o.spec as Dictionary).get("damage", 0.0))
		d = RingRules.stock_num("curve_k", 13.0) * (1.0 - exp(-dmg / maxf(RingRules.stock_num("curve_s", 35.0), 1.0)))
	return d / maxf(NpcBending.lock_for(String(o.id), String(o.mode), bend._preset_name(), 0.0), 0.05)


## Whether option `o` may be begun now under the % ring's rules: in the air no key 3 (3 is the air dodge), no keys 4 or 5
## (they wait for the deck) and no key-2 first move (the Slam: AIR's caster form, not wired for bots yet); Patch only by
## heal_ok; no wall near a lip while the foe is off the deck.
func allowed(o: Dictionary, t: Node3D) -> bool:
	var key := String(o.key)
	var k := Bending.key_of(bend.element, String(o.id))
	if airborne(me):
		if k in [2, 3, 4]:
			return false
		var ks := Bending.keys(bend.element)
		if k == 1 and ks.size() > 1:
			var f := Bending.first_of(ks[1])
			if String(o.id) == String(f.get("id", "")) and String(o.mode) == String(f.get("mode", "")):
				return false
	if key == String((pct_data().get("heal", {}) as Dictionary).get("move", "patch/patch")) or String(o.id) == "patch":
		return heal_ok(t)
	if k == 3 and t != null and off_deck(t):
		return false
	return true


## The multiplier on option `o`'s weight in the chooser (NEUTRAL, PRESSURE).
func weight(o: Dictionary, t: Node3D, d: float) -> float:
	var w := 1.0
	var key := String(o.key)
	var pr := pp()
	var tp := pct_of(t)
	if is_finisher(o):
		if ko_read(o, t):
			w *= float(pr.get("ko_bonus", 1.0))
			if d > pnum("far_finisher_m", 15.0):
				w *= pnum("far_finisher_mult", 0.6)
				_finisher_far = true
		if bool(pr.get("fresh_finisher", false)) and tp < pnum("fresh_below_pct", 80.0):
			var r := rules()
			if r != null and r.stale_count(me, key) >= int(pnum("fresh_stale_n", 2.0)):
				w *= pnum("fresh_mult", 0.5)
	if tp < pnum("build_pct", 60.0) and _build_top(o):
		w *= pnum("build_mult", 1.3)
	return w


## Whether `o` is among the build_top options with the best % per lock second.
func _build_top(o: Dictionary) -> bool:
	var rates: Array = []
	for q: Dictionary in bend.options:
		var role := String((q.hint as Dictionary).get("role", ""))
		if role in ["offence", "control"] and not bool(q.get("guard", false)):
			rates.append(pct_rate(q))
	rates.sort()
	rates.reverse()
	var n := mini(int(pnum("build_top", 2.0)), rates.size())
	return n > 0 and pct_rate(o) >= float(rates[n - 1]) - 1e-4


## The range band it keeps in NEUTRAL: closer than far_finisher_m while a finisher would kill from farther (it walks in), and
## centre_pull above high_pct of its own (handled in centre_goal).
func keep_band(band: Vector2) -> Vector2:
	if _finisher_far:
		var far := pnum("far_finisher_m", 15.0) - 2.0
		band = Vector2(minf(band.x, far * 0.5), minf(band.y, far))
	return band


## A goal moved centre_pull x centre_pull_m further from its nearest end above high_pct of its own %.
func centre_goal(goal: Vector3) -> Vector3:
	var cp := float(pp().get("centre_pull", 0.0))
	var a := arena()
	if cp <= 0.0 or a == null or pct_of(me) < pnum("high_pct", 120.0):
		return goal
	var lip := a.nearest_lip(goal)
	var n: Vector3 = lip.normal
	var inside := -float(lip.out_m)
	var want := cp * pnum("centre_pull_m", 6.0)
	if inside < want:
		goal -= n * (want - inside)
	return goal


## The reaction it answers with: the preset's, + high_react_s above high_pct of its own.
func reaction_add() -> float:
	return pnum("high_react_s", 0.15) if pct_of(me) >= pnum("high_pct", 120.0) else 0.0


## Patch's rule (spec §8, §9.7).
func heal_ok(t: Node3D) -> bool:
	var r := rules()
	if r == null or not r.heal_allowed(me):
		return false
	var h: Dictionary = pct_data().get("heal", {})
	if r.fresh_pct(me) < float(h.get("min_fresh", 6.0)) or airborne(me):
		return false
	var kn := BendKnock.peek(me)
	if kn != null and Vector2(kn.kv.x, kn.kv.z).length() > float(h.get("still_mps", 0.3)):
		return false
	if t != null:
		if flat_d(me.global_position, t.global_position) < float(h.get("min_dist_m", 12.0)):
			return false
		if winding_up_at_me(t):
			return false
	return true


## Whether `t` is visibly winding up at it (his lock under way: the player's SwayCaster, a bot's NpcBending).
func winding_up_at_me(t: Node3D) -> bool:
	if t is FrontierPlayer:
		var sc := SwayCaster.of(t)
		return sc != null and sc.is_locking()
	if t is NpcFighter and (t as NpcFighter).brain != null and (t as NpcFighter).brain.bending != null:
		return (t as NpcFighter).brain.bending.casting != ""
	return false


## Counted as a cast is let go (NpcBending._release): the KO casts and their range, the jab step's clock.
func on_released(o: Dictionary, t: Node3D) -> void:
	stats.casts_all = int(stats.get("casts_all", 0)) + 1
	if airborne(me):
		stats.air_casts = int(stats.get("air_casts", 0)) + 1
	if bool(o.get("jab", false)):
		_last_jab_release = now()
	if t != null and is_finisher(o) and ko_read(o, t):
		stats.ko_casts += 1
		var dd := flat_d(me.global_position, t.global_position)
		(stats.finisher_m as Array).append(dd)
		if dd > pnum("far_finisher_m", 15.0):
			stats.ko_cast_far += 1
	_finisher_far = false
	if String(o.get("id", "")) == "patch":
		stats.patches += 1


## The jab's lock under the step (spec §6.4): the next jab ready jab_step_s after the last left the hand, once it hit.
func jab_lock(base: float) -> float:
	var step := BendR3.num("jab_step_s", pnum("jab_step_s", 0.15))          # (AIR's moves.json air_rules.jab_step_s)
	if _last_jab_hit and now() - _last_jab_release < 1.5:
		return maxf(step - (now() - _last_jab_release), 1.0 / 60.0)
	return base


# ---------------------------------------------------------------- strings (PRESSURE)
## Its hit landed on the foe (RingRules.launched by it): the string counted, its follow-up begun when it is true.
func _on_landed(tag: String, _hitstun_s: float) -> void:
	_hit_lands_t = now()
	var lead := _lead_of(tag)
	_last_jab_hit = lead in ["jab", "pop"]
	if string.is_empty() or now() - float(string.get("last_at", -INF)) > 2.5:
		string = {"hits": 0, "keys": [], "began_at": now(), "read_done": false, "rolled": false, "go": false, "last_at": now()}
	string.hits = int(string.hits) + 1
	(string.keys as Array).append(lead)
	string.last_at = now()
	stats.longest_string = maxi(int(stats.longest_string), int(string.hits))
	if not bool(string.rolled):
		string.rolled = true
		string.go = me.rng.randf() < float(pp().get("string_chance", 0.5))
		if bool(string.go):
			stats.strings += 1
	if state != S.PRESSURE and not practice_dummy:
		_enter(S.PRESSURE)
	var nx := string_next()
	if not nx.is_empty():
		_begin_follow(nx)


func _end_string() -> void:
	string = {}


## The string table's lead for a landed tag: "pop" (the jab string's third hit), "jab" (the element's jab), else its key.
func _lead_of(tag: String) -> String:
	var base := tag.get_slice(".", 0)
	if base == "jab/pop" or base.ends_with("/pop"):
		return "pop"
	var jb := NpcBending.jab_of(bend.element)
	if jb.size() >= 2 and base == "%s/%s" % [jb[0], jb[1]]:
		return "jab"
	return base


## The follow-up now ({option, key, lock, flight, read} or {}): the string table's for the lead, in its % band, castable,
## not the last move again (jabs aside), true (hitstun_left >= lock + flight - 1/60), or the one read that ends a string.
func string_next() -> Dictionary:
	var t := target()
	if t == null or string.is_empty() or not bool(string.go) or practice_dummy:
		return {}
	var hits := int(string.hits)
	if hits >= int(pp().get("string_max", 3)):
		return {}
	var keys: Array = string.keys
	var lead := String(keys[keys.size() - 1])
	var tp := pct_of(t)
	var cands: Array = []
	# (the jab string itself: jab, jab, the Pop: the step makes the next jab true)
	var jab_hits := 0
	for k: String in keys:
		if k in ["jab", "pop"]:
			jab_hits += 1
	if lead == "jab" and jab_hits < 3:
		cands.append({"next": "jab", "pct": [0, 999]})
	for e: Dictionary in (pct_data().get("strings", {}) as Dictionary).get(bend.element, []):
		if String(e.get("lead", "")) == lead:
			cands.append(e)
	var hl := hitstun_left(t)
	var d := flat_d(me.global_position, t.global_position)
	var reads: Array = []
	for e: Dictionary in cands:
		var band: Array = e.get("pct", [0, 999])
		if tp < float(band[0]) or tp > float(band[1]):
			continue
		if bool(e.get("holding", false)) and bend._held_stone() == null:
			continue
		var o := _option_of(String(e.next))
		if o.is_empty() or not bend.castable(o) or not allowed(o, t):
			continue
		var key := String(o.key)
		if key == _last_key_of(keys) and not bool(o.get("jab", false)):
			continue
		var lock := bend.lock_of(o, t)
		var fl := flight_s(o, d)
		if bool(e.get("read", false)):
			reads.append({"option": o, "key": key, "lock": lock, "flight": fl, "read": true})
			continue
		if hl >= lock + fl - 1.0 / 60.0:
			return {"option": o, "key": key, "lock": lock, "flight": fl, "read": false, "margin": hl - lock - fl}
	if hits >= 2 and not reads.is_empty() and not bool(string.read_done) \
			and me.rng.randf() < float(pp().get("read_end", 0.0)):
		string.read_done = true
		return reads[me.rng.randi_range(0, reads.size() - 1)]
	return {}


func _last_key_of(keys: Array) -> String:
	var last := String(keys[keys.size() - 1]) if not keys.is_empty() else ""
	if last in ["jab", "pop"]:
		var jb := NpcBending.jab_of(bend.element)
		return "%s/%s" % [jb[0], jb[1]] if jb.size() >= 2 else last
	return last


## Option for a string table's `next` ("jab", "guard" or "id/mode").
func _option_of(next: String) -> Dictionary:
	if next == "jab":
		for o: Dictionary in bend.options:
			if bool(o.get("jab", false)):
				return o
		return {}
	if next == "guard":
		for o: Dictionary in bend.options:
			if bool(o.get("guard", false)):
				return o
		return {}
	return bend._option(next)


## Seconds from a release of option `o` to its strike at `d` m (a shot's flight at its pace, else the strike's own moment).
static func flight_s(o: Dictionary, d: float) -> float:
	var strike := NpcBending.READ_STRIKE_S
	if bool(o.get("guard", false)):
		return strike + d / NpcBending.HELD_MPS
	var sh := NpcBending.shot_of(String(o.id), String(o.mode))
	if sh.has("mps") and String(sh.get("kind", "")) != "under":
		return strike + d / maxf(float(sh.mps), 1.0)
	if sh.has("rise_s"):
		return float(sh.rise_s)
	return strike


func _begin_follow(nx: Dictionary) -> void:
	var o: Dictionary = nx.option
	if bool(nx.get("read", false)):
		stats.reads += 1
	else:
		stats.follow_ups += 1
		var m := float(nx.get("margin", 0.0))
		string_margins.append(m)
		if m < -1.0 / 60.0:
			stats.string_false += 1
	bend.begin(String(o.id), String(o.mode))
	bend._rest_until = 0.0


# ---------------------------------------------------------------- as the victim (REELING)
func _on_me_launched(v: Vector3, hitstun_s: float, by: Node) -> void:
	_hit_lands_t = now()
	stats.launches += 1
	var pr := pp()
	var di: Array = pr.get("di", [0.0, 0.0])
	_launch = {"at": now(), "v": v, "s": hitstun_s, "by": by, "broke": false, "teched": false,
			"break_ok": me.rng.randf() < float(pr.get("break_out", 0.0)),
			"tech_ok": me.rng.randf() < float(pr.get("tech", 0.0))}
	stats.break_rolls += 1 if bool(_launch.break_ok) else 0
	stats.tech_rolls += 1 if bool(_launch.tech_ok) else 0
	pad().di = steer_for(v, hitstun_s, by, float(di[0]), float(di[1]))
	if state != S.REELING:
		_enter(S.REELING)


## The steer held for a launch at `v` (pad.di: a flat world direction across the flight; ZERO none): by the dummy's way in
## Practice, else by chance (di[0]) and the right way's chance (di[1]): at its own % of survive_pct or more the yaw of
## -di_deg, 0, +di_deg whose landing is furthest in (RingPredict.flight); below it across the hitter's line, to the side with
## more room.
func steer_for(v: Vector3, hitstun_s: float, by: Node, chance: float, right: float) -> Vector3:
	var fd := Vector3(v.x, 0.0, v.z).normalized() if Vector2(v.x, v.z).length() > 0.1 else Vector3.ZERO
	if fd == Vector3.ZERO:
		return Vector3.ZERO
	var left := fd.rotated(Vector3.UP, PI * 0.5)        # (held this way the flight turns +yaw)
	var a := arena()
	var toward_mid := 0.0
	if a != null:
		toward_mid = signf(left.dot(flat_dir(me.global_position, a.global_position)))
	match steer_way:
		"none":
			return Vector3.ZERO
		"in":
			return left * (toward_mid if toward_mid != 0.0 else 1.0)
		"out":
			return -left * (toward_mid if toward_mid != 0.0 else 1.0)
		"random":
			return left * (1.0 if me.rng.randf() < 0.5 else -1.0)
	if me.rng.randf() >= chance:
		return Vector3.ZERO
	stats.di_set += 1
	var best := 0.0
	if pct_of(me) >= pnum("survive_pct", 90.0):
		var di := deg_to_rad(pnum("di_deg", 15.0))
		var best_in := -INF
		for s: float in [-1.0, 0.0, 1.0]:
			var vv := v.rotated(Vector3.UP, s * di)
			var f := flight(vv, hitstun_s, me.global_position, bend.element)
			var land := me.global_position + Vector3(vv.x, 0.0, vv.z).normalized() * float(f.get("travel_m", 0.0))
			var inside := -float(a.nearest_lip(land).out_m) if a != null else 0.0
			var score := inside + (100.0 if String(f.get("lands", "deck")) == "deck" else 50.0 if String(f.get("lands", "")) == "edge" else 0.0)
			if score > best_in + 0.01:
				best_in = score
				best = s
		if best == 0.0:
			best = toward_mid if toward_mid != 0.0 else 1.0
	else:
		# (across the hitter's line, to the side with more room: away from his follow-up)
		best = toward_mid if toward_mid != 0.0 else (1.0 if me.rng.randf() < 0.5 else -1.0)
		if by is Node3D:
			var hit_line := flat_dir((by as Node3D).global_position, me.global_position)
			if hit_line != Vector3.ZERO and absf(left.dot(hit_line)) > 0.9:
				best = toward_mid if toward_mid != 0.0 else 1.0
	if me.rng.randf() < right:
		stats.di_right += 1
	else:
		best = -best
	return left * best


func _reel(_dt: float) -> void:
	var p := pad()
	var r := rules()
	if _launch.is_empty():
		return
	# (the 0.6 s escape: a fresh press the frame the rules allow it, never a buffered one)
	if bool(_launch.break_ok) and not bool(_launch.broke) and r != null and r.can_escape(me):
		_launch.broke = true
		stats.break_outs += 1
		if RingMoves.of(me) != null and RingMoves.of(me).jumps_left <= 0 and RingMoves.of(me).dodge_ready:
			p.dodge_dir = _toward_deck()
			p.press("dodge")
		else:
			p.press("jump")
	# (breaking the fall: E pressed tech_lead_s before it meets the deck, tumbling)
	var kn := BendKnock.peek(me)
	if bool(_launch.tech_ok) and not bool(_launch.teched) and kn != null and kn.tumble and _meets_deck_in(pnum("tech_lead_s", 0.12)):
		_launch.teched = true
		stats.techs += 1
		if me.rng.randf() < 0.5:
			p.move = _toward_deck()
		p.press("guard")


## Whether it meets the deck within `s` seconds (falling over the deck's rectangle).
func _meets_deck_in(s: float) -> bool:
	var a := arena()
	if a == null:
		return false
	var pos := me.global_position
	var vy := me.velocity.y
	if vy > 0.0 or float(a.nearest_lip(pos).out_m) > 0.0:
		return false
	var g := BendKnock.launch_gravity()
	var h := pos.y - a.lip_y()
	return h - (-vy * s + 0.5 * g * s * s) <= 0.05


## Lying down after a missed fall: up again (W/Space) after its reaction.
func _lying_up() -> void:
	var kn := BendKnock.peek(me)
	if kn == null or kn.lying_t <= 0.0:
		_lying_seen = -INF
		return
	if _lying_seen == -INF:
		_lying_seen = now()
	if now() - _lying_seen >= float(bend.preset().get("reaction_s", 0.35)):
		pad().press("jump")
		stats.getups += 1
		_lying_seen = INF


func _toward_deck() -> Vector3:
	var a := arena()
	if a == null:
		return Vector3.ZERO
	return flat_dir(me.global_position, a.global_position)


# ---------------------------------------------------------------- recovery (RECOVER)
## The body's state for the look-ahead (world): {pos, vel, carry, element, jumps_left, dodge_ready, rise_ready, helpless,
## grabs_left}.
func body_state() -> Dictionary:
	var kn := BendKnock.peek(me)
	var carry := Vector3(kn.kv.x, 0.0, kn.kv.z) if kn != null else Vector3.ZERO
	var vel := kn.base_of(me.velocity) if kn != null else me.velocity
	var m := RingMoves.of(me)
	var st := {"pos": me.global_position, "vel": vel, "carry": carry, "element": bend.element,
			"grabs_left": maxi(int(pnum("grab_limit", 3.0)) - _grabs, 0)}
	if m != null:
		st.jumps_left = m.jumps_left
		st.dodge_ready = m.dodge_ready
		st.rise_ready = m.rise_ready
		st.helpless = m.helpless()
		if m.has_method(&"sim_state"):
			st.merge(m.call(&"sim_state"), true)
	else:
		st.jumps_left = 1 - mini(_own_jumps_used, 1)
		st.dodge_ready = not _own_dodged
		st.rise_ready = not _own_rised
		st.helpless = _own_rised
	return st


## The nearest open lip's point and its outward normal (world).
func target_lip() -> Dictionary:
	var a := arena()
	if a == null:
		return {}
	return a.nearest_lip(me.global_position)


## Plan `n` (PLANS) toward lip `lip` from `st` (world): {move, events: [{t, key, dir, at}]}, {} when its state can't make
## it. The time of 2's late double jump (the latest that still comes back, less the preset's late_s) and of 4-6's Rise (the
## earliest that comes back) are searched.
func plan_n(n: int, st: Dictionary, lip: Dictionary) -> Dictionary:
	var point: Vector3 = lip.point
	var nrm: Vector3 = lip.normal
	var mv := flat_dir(Vector3(st.pos), point - nrm * 0.5)
	if mv == Vector3.ZERO:
		mv = -nrm
	var jumps := int(st.get("jumps_left", 0))
	var free := not bool(st.get("helpless", false))
	var rise := bool(st.get("rise_ready", false)) and free
	var dodge := bool(st.get("dodge_ready", false)) and free
	var hz := pnum("recover_horizon_s", 2.5)
	var first: Array = [{"t": 0.0, "key": "jump", "dir": mv}] if jumps > 0 else []
	var rise_from := pnum("rise_repress_s", 0.2) if jumps > 0 else 0.0
	var grab_at := point - nrm * 0.1
	var high_at := point - nrm * 1.0 + Vector3.UP * pnum("aim_high_m", 1.0)
	match n:
		1:
			return {"move": mv, "events": []}
		2:
			if jumps <= 0:
				return {}
			var tl := _search(st, mv, [], "jump", 0.0, hz, Vector3.ZERO, true)
			if tl < 0.0:
				return {}
			var late := float((pp().get("recover", {}) as Dictionary).get("late_s", 0.0))
			return {"move": mv, "events": [{"t": maxf(tl - late, 0.0), "key": "jump", "dir": mv}]}
		3:
			return {"move": mv, "events": first} if jumps > 0 else {}
		4, 5:
			if not rise:
				return {"move": mv, "events": first} if jumps > 0 else {}
			var aim_at := grab_at if n == 4 else high_at
			var tr := _search(st, mv, first, "rise", rise_from, hz, aim_at, false)
			if tr < 0.0:
				return {}
			var evs: Array = first.duplicate(true)
			evs.append({"t": tr, "key": "rise", "at": aim_at})
			return {"move": mv, "events": evs}
		6:
			if not dodge:
				return {}
			var pre: Array = [{"t": 0.0, "key": "dodge", "dir": mv}]
			var dj := float(standin_nums().get("dodge_s", 0.22)) + 0.05
			if jumps > 0:
				pre.append({"t": dj, "key": "jump", "dir": mv})
			if rise:
				var tr6 := _search(st, mv, pre, "rise", dj + rise_from, hz, grab_at, false)
				if tr6 >= 0.0:
					pre.append({"t": tr6, "key": "rise", "at": grab_at})
			return {"move": mv, "events": pre}
	return {}


## Every plan that its state can make ({n: plan}; the tests, the chase's check).
func plans(st: Dictionary, lip: Dictionary) -> Dictionary:
	var out := {}
	for n: int in PLANS:
		var p := plan_n(n, st, lip)
		if not p.is_empty():
			out[n] = p
	return out


## The time (from `from_t` to `to_t` by recover_replan_s) to press `key` after `events` that brings it back: the earliest,
## or with `latest` the last of the first run of times that come back (a later press only falls further); -1 none.
func _search(st: Dictionary, mv: Vector3, events: Array, key: String, from_t: float, to_t: float, aim_at: Vector3,
		latest: bool) -> float:
	var step := pnum("recover_replan_s", 0.1)
	var t := from_t
	var found := -1.0
	while t <= to_t + 1e-4:
		var evs: Array = events.duplicate(true)
		evs.append({"t": t, "key": key, "dir": mv, "at": aim_at})
		var ok := bool(simulate(st, {"move": mv, "events": evs}).get("ok", false))
		if ok:
			found = t
			if not latest:
				return t
		elif found >= 0.0:
			return found
		t += step
	return found


## The look-ahead: RingMoves.simulate (MOVE's) when it answers, else the tests' override, else the stand-in mover.
func simulate(st: Dictionary, pl: Dictionary) -> Dictionary:
	var dt := pnum("recover_dt", 1.0 / 30.0)
	var hz := pnum("recover_horizon_s", 2.5)
	if simulate_override.is_valid():
		return simulate_override.call(st, pl, dt, hz)
	var rm := RingMoves.of(me)
	if rm != null and rm.get_script() == RING_MOVES:
		return move_sim(st, pl, dt, hz)            # (MOVE's own mover on its body: its own look-ahead)
	return standin_sim(st, pl, dt, hz, geo_of(arena()))


## The look-ahead on MOVE's own mover (RingMoves.simulate: the player's physics, the edge and the Rises exactly): this mind's
## state and plan ({move, events: [{t, key: jump | dodge | rise, dir, at}]}, world) handed over as MOVE's (kv the carry,
## grabs used; a Callable plan: the move held, each event pressed once at its time, the Rise aimed at its point from where
## the body is then), its answer as this mind's {ok (the deck or the edge reached), how ("grab", "deck", "water", ""), t,
## pos}.
static func move_sim(st: Dictionary, pl: Dictionary, dt: float, hz: float) -> Dictionary:
	var ms := {"pos": st.get("pos", Vector3.ZERO), "vel": st.get("vel", Vector3.ZERO), "kv": st.get("carry", Vector3.ZERO),
			"element": String(st.get("element", "water")), "jumps_left": int(st.get("jumps_left", 0)),
			"dodge_ready": bool(st.get("dodge_ready", false)), "rise_ready": bool(st.get("rise_ready", false)),
			"helpless": bool(st.get("helpless", false)),
			"grabs": maxi(int(RingMoves.num("edge", "grab_limit", 3.0)) - int(st.get("grabs_left", 3)), 0)}
	if st.has("stun_s"):
		ms["stun_s"] = float(st.stun_s)
	var mv: Vector3 = pl.get("move", Vector3.ZERO)
	var evs: Array = pl.get("events", [])
	var fired := {}
	var cb := func(s: Dictionary) -> Dictionary:
		var it := {"move": mv}
		for i in evs.size():
			var ev: Dictionary = evs[i]
			if fired.has(i) or float(ev.get("t", 0.0)) > float(s.t) + 1e-4:
				continue
			fired[i] = true
			match String(ev.get("key", "")):
				"jump":
					it["jump"] = true
				"dodge":
					it["dodge"] = true
					it["dodge_dir"] = Vector3(ev.get("dir", Vector3.ZERO))
				"rise":
					it["jump"] = true
					var at: Vector3 = ev.get("at", Vector3(s.pos))
					it["aim"] = (at - (Vector3(s.pos) + Vector3.UP * 1.2)).normalized()
		return it
	var r := RingMoves.simulate(ms, cb, dt, hz)
	var res := String(r.get("result", ""))
	return {"ok": res in ["deck", "edge"], "how": "grab" if res == "edge" else ("" if res == "air" else res),
			"t": float(r.get("t", 0.0)), "pos": r.get("pos", Vector3.ZERO)}


## Its preset's order of plans: the first that comes back ({n, plan} or {}); 45: 4 or 5 by high_share; 6 only by its
## dodge rule. None in its order: any that comes back; then the desperate line (everything toward the lip).
func pick_plan(st: Dictionary, lip: Dictionary) -> Dictionary:
	var rc: Dictionary = pp().get("recover", {})
	var order: Array = rc.get("order", [2, 4, 6])
	var dodge_rule := String(rc.get("dodge", "never"))
	var made := {}
	var tried := {}
	var get_plan := func(n: int) -> Dictionary:
		if not made.has(n):
			made[n] = plan_n(n, st, lip)
		return made[n]
	for o: Variant in order:
		var cands: Array = []
		if int(o) == 45:
			var high := me.rng.randf() < float(rc.get("high_share", 0.4))
			cands = [5, 4] if high else [4, 5]
		else:
			cands = [int(o)]
		for n: int in cands:
			if n == 6 and not _dodge_wanted(dodge_rule):
				continue
			var pl: Dictionary = get_plan.call(n)
			tried[n] = true
			if not pl.is_empty() and bool(simulate(st, pl).get("ok", false)):
				return {"n": n, "plan": pl}
	for n: int in [1, 2, 3, 4, 5, 6]:
		if tried.has(n) or (n == 6 and dodge_rule == "never"):
			continue
		var pl2: Dictionary = get_plan.call(n)
		if not pl2.is_empty() and bool(simulate(st, pl2).get("ok", false)):
			return {"n": n, "plan": pl2}
	stats.desperate += 1
	for n: int in [4, 6, 3, 1]:
		if n == 6 and dodge_rule == "never":
			continue
		var pl3: Dictionary = get_plan.call(n)
		if not pl3.is_empty():
			return {"n": n, "plan": pl3, "desperate": true}
	return {}


func _dodge_wanted(rule: String) -> bool:
	var t := target()
	match rule:
		"never":
			return false
		"near":
			return t != null and t.global_position.distance_to(me.global_position) < pnum("dodge_near_m", 4.0)
		"threat":
			return not bend._threats().is_empty() or (t != null and t.global_position.distance_to(me.global_position) < pnum("dodge_near_m", 4.0))
	return false


func _recover(dt: float) -> void:
	var p := pad()
	_replan_t -= dt
	if _replan_t <= 0.0 or plan.is_empty():
		_replan_t = pnum("recover_replan_s", 0.1)
		var lip := target_lip()
		if lip.is_empty():
			return
		var st := body_state()
		if not plan.is_empty() and not bool(plan.get("desperate", false)):
			# (the plan under way kept while the rest of it still comes back from here: one look a replan)
			var el0 := now() - float(plan.t0)
			var rest: Array = []
			for ev: Dictionary in plan.events:
				if not bool(ev.get("done", false)):
					var e2 := ev.duplicate()
					e2.t = maxf(float(ev.t) - el0, 0.0)
					rest.append(e2)
			if bool(simulate(st, {"move": plan.move, "events": rest}).get("ok", false)):
				plan.events = rest
				plan.t0 = now()
				p.move = Vector3(plan.move)
				_fire_due()
				return
		var pk := pick_plan(st, lip)
		if pk.is_empty():
			plan = {}
			return
		var pl: Dictionary = pk.plan
		plan = {"n": int(pk.n), "name": String(PLANS.get(int(pk.n), "")), "move": pl.move, "events": (pl.events as Array).duplicate(true),
				"t0": now(), "desperate": bool(pk.get("desperate", false))}
		var by: Dictionary = stats.plans_by
		by[plan.name] = int(by.get(plan.name, 0)) + 1
	p.move = Vector3(plan.move)
	_fire_due()


## The plan's events whose time has come, pressed.
func _fire_due() -> void:
	var el := now() - float(plan.t0)
	for ev: Dictionary in plan.events:
		if bool(ev.get("done", false)) or float(ev.t) > el + 1e-3:
			continue
		ev.done = true
		_press_event(ev)


## A plan's event pressed on the pad: jump, the air dodge (toward its dir), the Rise (Space again, aimed with the preset's
## error at its point).
func _press_event(ev: Dictionary) -> void:
	var p := pad()
	match String(ev.key):
		"jump":
			p.press("jump")
			_own_jumps_used += 1
		"dodge":
			p.dodge_dir = Vector3(ev.get("dir", Vector3.ZERO))
			p.press("dodge")
			_own_dodged = true
		"rise":
			var at: Vector3 = ev.get("at", me.global_position)
			var aim := (at - (me.global_position + Vector3.UP * 1.2)).normalized()
			var err := deg_to_rad(float((pp().get("recover", {}) as Dictionary).get("err_deg", 0.0)))
			if err > 0.0:
				aim = aim.rotated(Vector3.UP, me.rng.randf_range(-err, err))
				var side := aim.cross(Vector3.UP)
				if side.length_squared() > 1e-6:
					aim = aim.rotated(side.normalized(), me.rng.randf_range(-err, err))
			# (the Rise's aim, the Jet's way: NpcPad.aim once MOVE's pad has it; the meta until then, the stand-in's)
			p.set(&"aim", aim)
			p.set_meta(&"aim", aim)
			me.face_point(at)
			p.press("jump")
			_own_rised = true


# ---------------------------------------------------------------- on the edge (LEDGE)
func _hang(_dt: float) -> void:
	var p := pad()
	var m := RingMoves.of(me)
	if _ledge.is_empty():
		_ledge = _ledge_choice()
		_ledge.t0 = now()
		var safe_left := m.ledge_safe_left() if m != null else 0.0
		var margin := pnum("act_margin_s", 0.1)
		var at := float(_ledge.wait)
		if safe_left > 0.0:
			at = minf(at, maxf(safe_left - margin, 0.0))
		_ledge.wait = minf(at, pnum("hang_s", 4.0) - margin)
	if now() - float(_ledge.t0) < float(_ledge.wait):
		return
	if bool(_ledge.get("done", false)):
		return
	_ledge.done = true
	var how := String(_ledge.how)
	var inward := _toward_deck()
	var lip := target_lip()
	if not lip.is_empty():
		inward = -Vector3(lip.normal)
	var eo: Dictionary = stats.edge_opts
	eo[how] = int(eo.get(how, 0)) + 1
	match how:
		"climb":
			p.move = inward
		"jump":
			p.move = inward
			p.press("jump")
		"roll":
			p.press("guard")
		"attack":
			p.ledge_option("attack")              # (MOVE's pad: the edge option by name; a bare "ledge" press is the climb)
		"drop":
			p.press("fast_fall")


## Its option on the edge by preset: {how, wait}.
func _ledge_choice() -> Dictionary:
	var lg: Dictionary = pp().get("ledge", {})
	match String(lg.get("how", "climb")):
		"climb":
			return {"how": "climb", "wait": float(lg.get("after_s", 0.6))}
		"weighted":
			var ws: Dictionary = lg.get("weights", {"climb": 1.0})
			var total := 0.0
			for k: String in ws:
				total += float(ws[k])
			var roll := me.rng.randf() * total
			var pick := "climb"
			for k: String in ws:
				roll -= float(ws[k])
				if roll <= 0.0:
					pick = k
					break
			var w: Array = lg.get("wait_s", [0.2, 1.0])
			return {"how": pick, "wait": me.rng.randf_range(float(w[0]), float(w[1]))}
	# (hard reads the foe: close, a roll behind him or the attack; mid, a jump; far, a climb at once)
	var t := target()
	var lip := target_lip()
	var d := INF
	if t != null and not lip.is_empty():
		d = flat_d(Vector3(lip.point), t.global_position)
	if d < pnum("ledge_near_m", 2.0):
		return {"how": "roll" if d < pnum("roll_in_m", 3.0) - 0.5 else "attack", "wait": 0.0}
	if d < pnum("ledge_mid_m", 5.0):
		return {"how": "jump", "wait": 0.0}
	return {"how": "climb", "wait": 0.0}


# ---------------------------------------------------------------- the spout (RESPAWN)
func _spout(dt: float) -> void:
	_spout_t += dt
	var leave := float(pp().get("spout_leave_s", 1.0))
	if leave < 0.0:
		# (hard: the full time with the foe under it, else at once)
		var t := target()
		var under := t != null and flat_d(t.global_position, me.global_position) < float(RingRules.stock_block("respawn").get("clear_m", 2.0)) + 0.5
		if under:
			return
		leave = 0.0
	if _spout_t >= leave and not _spout_left:
		_spout_left = true
		stats.spout_leaves += 1
		pad().move = _toward_deck()
		pad().press("jump")


# ---------------------------------------------------------------- keeping him off (EDGEGUARD, LEDGETRAP)
## Once per time he is off the deck: whether it keeps him off at all (the preset's edgeguard chance).
func _keeping() -> bool:
	if not _edge_roll.has("on"):
		_edge_roll.on = me.rng.randf() < float(pp().get("edgeguard", 0.0))
	return bool(_edge_roll.on)


## The foe off the deck: shots from inside the lip at where he will be (normal, hard), hard's wait with a lock filled, and
## its safe-only chase; easy waits mid-deck.
func _keep_off() -> void:
	var t := target()
	var a := arena()
	if t == null or a == null:
		return
	if not _keeping():
		me.go(bend._clamp(a.global_position), NpcFighter.RUN_SPEED * 0.6, 1.5, true)
		return
	var lip := a.nearest_lip(t.global_position)
	var n: Vector3 = lip.normal
	var back := pnum("inside_m", 1.0)
	if bool(pp().get("guard_edge", false)):
		var wb: Array = pnum_arr("wait_back_m", [1.5, 2.5])
		back = lerpf(float(wb[0]), float(wb[1]), 0.5)
	var spot := Vector3(lip.point) - n * back
	spot.y = me.global_position.y
	me.go(bend._clamp(spot), NpcFighter.RUN_SPEED, 0.4, true)
	me.face_point(t.global_position)
	if _chase_ok(t, lip):
		stats.chases += 1
		_edge_roll.chased = true
		pad().move = n
		pad().press("jump")
		return
	if bend.casting != "" or now() < bend._rest_until:
		return
	var d := flat_d(me.global_position, t.global_position)
	var best := {}
	var best_w := 0.0
	for o: Dictionary in bend.options:
		var h: Dictionary = o.hint
		if String(h.get("role", "")) != "offence" or not bend.castable(o) or not allowed(o, t):
			continue
		if String(o.do) in ["column", "spout", "ring", "dash", "zone", "heal", "buff"]:
			continue
		var band := bend._band(h, o.spec)
		if band.y > 0.0 and (d < band.x or d > band.y):
			continue
		var w := maxf(float(o.knock), 1.0) * me.rng.randf_range(0.8, 1.2)
		if is_finisher(o) and ko_read(o, t):
			w *= float(pp().get("ko_bonus", 1.0))
		if w > best_w:
			best_w = w
			best = o
	if not best.is_empty():
		stats.keep_off_casts += 1
		bend.begin(String(best.id), String(best.mode))


static func pnum_arr(key: String, def: Array) -> Array:
	var v: Variant = pct_data().get(key, def)
	return v if v is Array and (v as Array).size() >= 2 else def


## Hard's chase off the deck: only at chase_min_pct and up, and only if its own way back from the intercept (1.5 m past the
## lip at its height) succeeds with a jump fewer.
func _chase_ok(t: Node3D, lip: Dictionary) -> bool:
	if not bool(pp().get("chase", false)) or bool(_edge_roll.get("chased", false)) or pct_of(t) < pnum("chase_min_pct", 60.0):
		return false
	if flat_d(me.global_position, Vector3(lip.point)) > 2.0:
		return false
	var st := body_state()
	st.pos = Vector3(lip.point) + Vector3(lip.normal) * 1.5 + Vector3.UP * 0.5
	st.vel = Vector3.ZERO
	st.carry = Vector3.ZERO
	st.jumps_left = maxi(int(st.get("jumps_left", 1)) - 1, 0)
	for k: int in [4, 2, 3]:
		var pl := plan_n(k, st, lip)
		if not pl.is_empty() and bool(simulate(st, pl).get("ok", false)):
			return true
	return false


## The foe hanging: it waits out his safe time 1.5-2.5 m back with a lock filled and covers his favourite option (hard: the
## options counted; else the climb).
func _ledge_trap() -> void:
	var t := target()
	var a := arena()
	if t == null or a == null:
		return
	if not _keeping():
		me.go(bend._clamp(a.global_position), NpcFighter.RUN_SPEED * 0.6, 1.5, true)
		return
	var lip := a.nearest_lip(t.global_position)
	var fav := "climb"
	if String(bend._preset_name()) == "hard" and not foe_edge.is_empty():
		var most := 0
		for k: String in foe_edge:
			if int(foe_edge[k]) > most:
				most = int(foe_edge[k])
				fav = k
	var back := {"climb": 1.2, "ledge_jump": 2.0, "ledge_roll": 3.6, "ledge_attack": 2.6}
	var spot := Vector3(lip.point) - Vector3(lip.normal) * float(back.get(fav, 2.0))
	spot.y = me.global_position.y
	me.go(bend._clamp(spot), NpcFighter.RUN_SPEED, 0.3, true)
	me.face_point(t.global_position)
	if bend.casting != "":
		return
	var d := flat_d(me.global_position, t.global_position)
	for o: Dictionary in bend.options:
		var h: Dictionary = o.hint
		if not (bool(o.get("jab", false)) or Bending.key_of(bend.element, String(o.id)) == 0):
			continue
		if not bend.castable(o):
			continue
		var band := bend._band(h, o.spec)
		if band.y > 0.0 and d > band.y + 2.0:
			continue
		stats.keep_off_casts += 1
		bend.begin(String(o.id), String(o.mode))
		return


## Whether its full lock may be let go now: never into a safety (his spawn safety, a dodge's or a first grab's window, by
## the time it reaches him); in LEDGETRAP and hard's EDGEGUARD wait, held until his safety runs out (or his Rise shows). A
## lock held past hold_max_s is called off (cancel), never thrown into the safety.
func allow_release(o: Dictionary, dt: float) -> int:
	var t := target()
	if t == null or bool(o.get("guard", false)) or String((o.hint as Dictionary).get("role", "")) in ["reaction", "mobility", "sustain", "defence"]:
		_hold_t = 0.0
		return 1
	var fl := flight_s(o, flat_d(me.global_position, t.global_position))
	var hold := safe(t, fl)
	if state == S.EDGEGUARD and bool(pp().get("guard_edge", false)) and not hold:
		# (hard's wait: the Rise's tell heard, or he is in its reach)
		var seen_rise := now() - _foe_rise_t < 1.0 and now() - _foe_rise_t >= float(bend.preset().get("reaction_s", 0.22))
		var band := bend._band(o.hint, o.spec)
		var d := flat_d(me.global_position, t.global_position)
		hold = not seen_rise and band.y > 0.0 and d > band.y
	if not hold:
		_hold_t = 0.0
		return 1
	if _hold_t == 0.0:
		stats.safety_holds += 1
	_hold_t += dt
	if _hold_t > pnum("hold_max_s", 2.5):
		_hold_t = 0.0
		stats.held_out += 1
		return -1
	return 0


# ---------------------------------------------------------------- the stand-in mover (the tests' FakeMoves; MOVE's is move_sim)
## The deck's geometry for the stand-in (arena-local, y from the lip): {xf (the arena's), hl, hw, water_y, curtain_m}.
static func geo_of(a: RingArena) -> Dictionary:
	var n := standin_nums()
	var g := {"hl": 17.0, "hw": 7.0, "water_y": float(n.get("water_y", -6.0)), "curtain_m": float(n.get("curtain_m", 10.0)),
			"xf": Transform3D.IDENTITY, "top": 0.0}
	if a != null:
		g.hl = a.half_l()
		g.hw = a.half_w()
		g.xf = a.global_transform
		g.top = a.lip_y()
	return g


## A stand-in body (arena-local) from world state `st`.
static func standin_state(st: Dictionary, geo: Dictionary) -> Dictionary:
	var xf: Transform3D = geo.xf
	var inv := xf.affine_inverse()
	var p: Vector3 = inv * Vector3(st.get("pos", Vector3.ZERO))
	p.y -= float(geo.top) - xf.origin.y
	return {"p": p, "v": inv.basis * Vector3(st.get("vel", Vector3.ZERO)), "c": inv.basis * Vector3(st.get("carry", Vector3.ZERO)),
			"el": String(st.get("element", "water")), "jumps": int(st.get("jumps_left", 0)),
			"dodge": bool(st.get("dodge_ready", false)), "rise": bool(st.get("rise_ready", false)),
			"helpless": bool(st.get("helpless", false)), "grabs_left": int(st.get("grabs_left", 3)), "phase": "", "phase_t": 0.0,
			"t": 0.0, "last_jump_t": -INF, "how": "", "rise_dir": Vector3.UP, "dodge_dir": Vector3.ZERO, "rise_end_t": -INF,
			"refused": 0, "on_deck": false}


## World `w` (a direction) in the arena's frame.
static func local_dir(w: Vector3, geo: Dictionary) -> Vector3:
	return (geo.xf as Transform3D).basis.inverse() * w


## The stand-in's look-ahead: plan `pl` ({move, events: [{t, key, dir, at}]}, world) from world state `st` for `horizon` s
## in steps of `dt`: {ok (the grab box or the deck reached), how ("grab", "deck", "water", ""), t, pos (world)}.
static func standin_sim(st: Dictionary, pl: Dictionary, dt: float, horizon: float, geo: Dictionary) -> Dictionary:
	var s := standin_state(st, geo)
	var mv := local_dir(Vector3(pl.get("move", Vector3.ZERO)), geo)
	var evs: Array = pl.get("events", [])
	var done := {}
	var t := 0.0
	while t < horizon and String(s.how) == "":
		var intent := {"move": mv, "jump": false, "dodge": false, "dodge_dir": Vector3.ZERO, "aim": Vector3.ZERO, "down_held": false}
		for i in evs.size():
			var ev: Dictionary = evs[i]
			if done.has(i) or float(ev.t) > t + 1e-4:
				continue
			done[i] = true
			match String(ev.key):
				"jump", "rise":
					intent.jump = true
					if ev.has("at"):
						var xf: Transform3D = geo.xf
						var at_l: Vector3 = xf.affine_inverse() * Vector3(ev.at)
						at_l.y -= float(geo.top) - xf.origin.y
						intent.aim = (at_l - (Vector3(s.p) + Vector3.UP * 1.2)).normalized()
				"dodge":
					intent.dodge = true
					intent.dodge_dir = local_dir(Vector3(ev.get("dir", Vector3.ZERO)), geo)
		standin_step(s, intent, dt, geo)
		t += dt
	var xf2: Transform3D = geo.xf
	var pw: Vector3 = Vector3(s.p) + Vector3.UP * (float(geo.top) - xf2.origin.y)
	return {"ok": String(s.how) in ["grab", "deck"], "how": String(s.how), "t": t, "pos": xf2 * pw}


## One step of the stand-in mover on arena-local state `s` (mutated) from `intent` (local: move, jump, dodge, dodge_dir, aim,
## down_held). The spec's §4-§5 numbers (bend_ai.json pct.standin).
static func standin_step(s: Dictionary, intent: Dictionary, dt: float, geo: Dictionary) -> void:
	if String(s.how) != "":
		return
	var n := standin_nums()
	var el := String(s.el)
	var g := float(n.get("gravity", 20.0))
	var hl := float(geo.hl)
	var hw := float(geo.hw)
	s.t = float(s.t) + dt
	var p: Vector3 = s.p
	var v: Vector3 = s.v
	var c: Vector3 = s.c
	var mv: Vector3 = intent.get("move", Vector3.ZERO)
	mv.y = 0.0
	if mv.length() > 1.0:
		mv = mv.normalized()
	var drift: Array = (n.get("drift", {}) as Dictionary).get(el, [4.0, 16.0])
	var dsp := float(drift[0]) * (float(n.get("helpless_drift", 0.6)) if bool(s.helpless) else 1.0)
	var dacc := float(drift[1])
	var rs: Dictionary = (n.get("rise", {}) as Dictionary).get(el, {})
	var off := _standin_off(p, hl, hw)
	var phase := String(s.phase)
	# (the presses: a double jump, else the Rise off the deck at least rise_repress_s after it; the air dodge)
	if bool(intent.get("jump", false)) and not phase in ["dodge", "rise_start", "rise"] and not bool(s.helpless):
		if int(s.jumps) > 0:
			v.y = float((n.get("double_v", {}) as Dictionary).get(el, 8.0))
			c *= 0.5
			var flat := mv * dsp
			v.x = flat.x
			v.z = flat.z
			s.jumps = int(s.jumps) - 1
			s.last_jump_t = s.t
			phase = ""
		elif bool(s.rise) and off and float(s.t) - float(s.last_jump_t) >= float(n.get("rise_repress_s", 0.2)):
			s.rise = false
			phase = "rise_start"
			s.phase_t = 0.0
			var dir := Vector3.UP
			var lean := deg_to_rad(float(rs.get("lean_deg", 0.0)))
			if bool(rs.get("aim", false)):
				var aim: Vector3 = intent.get("aim", Vector3.ZERO)
				if aim.length_squared() < 1e-4:
					aim = (mv + Vector3.UP).normalized()
				var pmin := deg_to_rad(float(rs.get("pitch_min_deg", 20.0)))
				var fl := Vector3(aim.x, 0.0, aim.z)
				var pitch := atan2(aim.y, fl.length())
				if pitch < pmin:
					pitch = pmin
				var fd := fl.normalized() if fl.length_squared() > 1e-6 else mv
				dir = (fd * cos(pitch) + Vector3.UP * sin(pitch)).normalized()
			elif lean > 0.0:
				var to_lip := _standin_inward(p, hl, hw)
				dir = (Vector3.UP * cos(lean) + to_lip * sin(lean)).normalized()
			s.rise_dir = dir
	if bool(intent.get("dodge", false)) and bool(s.dodge) and not phase in ["dodge", "rise_start", "rise"] and not bool(s.helpless):
		s.dodge = false
		phase = "dodge"
		s.phase_t = 0.0
		var dd: Vector3 = intent.get("dodge_dir", Vector3.ZERO)
		dd.y = 0.0
		s.dodge_dir = dd.normalized() if dd.length_squared() > 1e-4 else Vector3.ZERO
		if s.dodge_dir == Vector3.ZERO:
			v *= 0.3
	s.phase_t = float(s.phase_t) + dt
	var travel := Vector3.ZERO
	match phase:
		"dodge":
			if s.dodge_dir != Vector3.ZERO:
				travel = Vector3(s.dodge_dir) * float(n.get("dodge_m", 3.2)) / maxf(float(n.get("dodge_s", 0.22)), 0.01) * dt
				v = Vector3.ZERO
			else:
				v.y -= g * dt
			if float(s.phase_t) >= float(n.get("dodge_s", 0.22)):
				phase = ""
		"rise_start":
			if bool(rs.get("hover", false)):
				v = Vector3.ZERO
			else:
				v.y = maxf(v.y - g * dt, -float(n.get("max_fall", 11.0)))
				v = _standin_drift(v, mv, dsp, dacc, dt)
			if float(s.phase_t) >= float(rs.get("startup_s", 0.1)):
				phase = "rise"
				s.phase_t = 0.0
				c = Vector3.ZERO if bool(rs.get("hover", false)) else c
		"rise":
			travel = Vector3(s.rise_dir) * float(rs.get("m", 4.0)) / maxf(float(rs.get("s", 0.5)), 0.01) * dt
			var rd := float(rs.get("drift", 1.0))
			if rd > 0.0:
				var dv := _standin_drift(Vector3(v.x, 0.0, v.z), mv, dsp * rd, dacc, dt)
				v = Vector3(dv.x, 0.0, dv.z)
			else:
				v = Vector3.ZERO
			if float(s.phase_t) >= float(rs.get("s", 0.5)):
				phase = "glide" if rs.has("glide_mps") else ""
				# (lead_model v2: the Pillar pushes off its top at end_vy, the others keep a little of the lift)
				v.y = float(rs.get("end_vy", 0.0)) if rs.has("end_vy") and float(rs.get("end_vy", 0.0)) > 0.0 \
						else minf(float(rs.get("m", 4.0)) / maxf(float(rs.get("s", 0.5)), 0.01), 2.0)
				s.helpless = true
				s.rise_end_t = s.t
		"glide":
			v.y = maxf(v.y - g * dt, -float(rs.get("glide_mps", 3.0)))
			v = _standin_drift(v, mv, dsp, dacc, dt)
			if bool(intent.get("fast_fall", false)):
				phase = ""
		_:
			var mf := float(n.get("max_fall_air", 8.0)) if el == "air" else float(n.get("max_fall", 11.0))
			v.y = maxf(v.y - g * dt, -mf)
			v = _standin_drift(v, mv, dsp, dacc, dt)
	var cl := c.length()
	if cl > 0.0:
		c = c * maxf(cl - float(n.get("carry_decay", 8.0)) * dt, 0.0) / cl
	var prev := p
	p += (v + c) * dt + travel
	s.phase = phase
	# (the deck: landed on its top from above; through its face from the side: back out, that way's speed gone)
	var inside := absf(p.x) <= hl and absf(p.z) <= hw
	if inside and p.y <= 0.0 and prev.y >= -0.05:
		p.y = 0.0
		s.how = "deck"
	elif inside and p.y < 0.0:
		var ex := hl - absf(prev.x)
		var ez := hw - absf(prev.z)
		var push_x := absf(prev.x) > hl or (absf(prev.z) <= hw and ex < ez)
		if push_x:
			p.x = signf(prev.x) * (hl + 0.35)
			v.x = 0.0
			c.x = 0.0
		else:
			p.z = signf(prev.z) * (hw + 0.35)
			v.z = 0.0
			c.z = 0.0
		# (the scramble: a Rise meeting the face with the head within scramble_m under the grab box slides up to the hang)
		var gb: Dictionary = n.get("grab", {})
		var rising := phase in ["rise_start", "rise"] or float(s.t) - float(s.rise_end_t) <= 0.1
		if rising and p.y + float(gb.get("head_m", 1.6)) >= float(gb.get("lo_m", -0.5)) - float(gb.get("scramble_m", 2.0)) \
				and int(s.grabs_left) > 0:
			s.grabs_left = int(s.grabs_left) - 1
			s.how = "grab"
	s.p = p
	s.v = v
	s.c = c
	if String(s.how) != "":
		return
	# (the grab: the head in the box, not rising fast, not in a dodge's travel, down not held; three, then the deck)
	var gb2: Dictionary = n.get("grab", {})
	var head := p.y + float(gb2.get("head_m", 1.6))
	var out := _standin_out(p, hl, hw)
	if out >= -float(gb2.get("in_m", 0.3)) and out <= float(gb2.get("out_m", 0.9)) and head >= float(gb2.get("lo_m", -0.5)) \
			and head <= float(gb2.get("hi_m", 0.6)) and v.y <= float(gb2.get("vy_max", 1.0)) and phase != "dodge" \
			and not bool(intent.get("down_held", false)) and p.y < 0.0:
		if int(s.grabs_left) > 0:
			s.grabs_left = int(s.grabs_left) - 1
			s.how = "grab"
			return
		s.refused = int(s.refused) + 1
	if p.y <= float(geo.water_y) or absf(p.x) > hl + float(geo.curtain_m) or absf(p.z) > hw + float(geo.curtain_m):
		s.how = "water"


static func _standin_drift(v: Vector3, mv: Vector3, sp: float, acc: float, dt: float) -> Vector3:
	var want := mv * sp
	var flat := Vector3(v.x, 0.0, v.z)
	var d := want - flat
	var step := acc * dt
	if d.length() > step:
		d = d.normalized() * step
	flat += d
	return Vector3(flat.x, v.y, flat.z)


## Metres out past the deck's lip line (negative inside), arena-local.
static func _standin_out(p: Vector3, hl: float, hw: float) -> float:
	var ex := absf(p.x) - hl
	var ez := absf(p.z) - hw
	if ex <= 0.0 and ez <= 0.0:
		return maxf(ex, ez)
	return Vector2(maxf(ex, 0.0), maxf(ez, 0.0)).length()


static func _standin_off(p: Vector3, hl: float, hw: float) -> bool:
	return absf(p.x) > hl or absf(p.z) > hw or p.y < -0.3


## The flat way from `p` to the nearest lip, inward (arena-local).
static func _standin_inward(p: Vector3, hl: float, hw: float) -> Vector3:
	var ex := absf(p.x) - hl
	var ez := absf(p.z) - hw
	if ex >= ez:
		return Vector3(-signf(p.x), 0.0, 0.0)
	return Vector3(0.0, 0.0, -signf(p.z))
