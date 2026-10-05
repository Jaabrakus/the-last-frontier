class_name NpcBending
extends RefCounted
## An element bot: a fighter that bends instead of shooting (NpcFighter.tactics "bend"; the duel's opponent and Tidebreak's,
## the ring sport's; the owner, 2026-10-04: "remove the guns in 1v1 its just spells", the bots cast the same moves as the
## player, of any of the four elements). It has no gun and no axe; its moves are the player's own, cast through the same path
## (BendCast.cast when it is there, else BendEffects with its NpcBendCaster: the same specs, lock times, interactions, catches,
## redirects and knockback as his), timed by the same lock:
##   its options   every (move, mode) of its element's keys (Bending.keys: four keys of two skills of three variations) plus
##                 Mend and Patch; an old Sway spell without a bend spec (stone_form spike and cannonball, earth_wall wall, pillar
##                 self and free, gust's, mend) only through BendCast, except spike, wall and gust push, which it has its own
##                 way of casting until then (FALLBACK)
##   the lock      exactly the player's (SwayCaster._try_begin): the move's lock_s, or its mode's mode_lock_s, stretched by the
##                 range as his, x the expert tier's mastery.lock_mult (free use: every spell an expert's), x its difficulty's
##                 lock_mult; a move's ai_factor only on easy and normal (lock_for). It stands while the lock fills (the pose:
##                 NpcBody.play_cast, its strike timed to the release), and SHOW_LOCK_CIRCLE: its element's circle at its own
##                 feet as his is at his (the owner allowed it; nothing is ever drawn on the player or over anyone)
##   a hit breaks  any damage above 0 (NpcFighter.apply_hit: on_hurt) or any knock (BendKnock: on_knocked) loses the lock (lost),
##                 as a hit taken breaks the player's
##   the mind      think (every NpcBrain think, 0.25 s): the option with the best utility (data/npc/bend_ai.json: its role,
##                 the element's personality, its range band, its 'when'; a little chance from its own seeded rng; an option
##                 not cast yet a little more, a combo's follow-up much more), else it keeps its range and circles the foe,
##                 facing him; tick (each physics frame, NpcFighter._physics_process): the lock filled, the threats looked
##                 at (BendBolt, a bot's spike in flight, a hurled GustLift stone, the foe's lightning lock, and his wind-up
##                 read: his lock on a throw or a bolt, its time to impact the lock's rest and the flight) and a guard of its
##                 element begun in time (catch, deflect, parry, redirect, bubble, shield, spin...: the preset's reaction and
##                 chance), its own speed braked short of an open end
##   its water     its own meter (Bending.of(it)): a water move it cannot pay for is not chosen; under water_low it goes to a
##                 pool (Bending.POOLS) and draws
##   the ring      bounds_fn(pos) -> pos clamped to where it may stand, edge_fn(pos, dir) -> metres to the open end along dir
##                 (INF none): set by the ring (no ring import here); its goals are clamped by the first, its dashes and runs
##                 never taken toward an end closer than they carry, its steering straight on the deck (NpcFighter.on_deck)
##   what hides    the foe behind a cloud (NpcBendCaster.hidden: smoke, dust, spray, steam on the line): no aimed move begun,
##                 no guard (it cannot see him), the scatter tripled; a flare's dazzle (bend_dazzle_until) doubles its scatter
##                 and its reaction
##   the opening   its preset's grace_s from the moment it is let go (the round's "Break!", its first tick unheld; the duel:
##                 from its making): no attack and no control begun (guards, walls and footwork only), so no bot knocks a man
##                 over his line in the first second of a round (the owner's integrator saw a hard air ball land at 0.6 s)
##   catch, return a stone caught and held (its Catch) is shoved back (Earth Shove push) as soon as its reaction allows:
##                 forced, its rest cut short (the earth-vs-earth core: catch it just before it hits and fire it back)
## Counted for the tests and the ring's HUD: casts, casts_by ("move/mode" -> n), hits, catches, answered, lost, reactions_by,
## locks (each lock's planned and measured time); the old spikes, walls, gusts. Contract: element, casting ("" or the move),
## mode, fill (0..1), lock_s, bounds_fn, edge_fn.

const FormMatter := preload("res://scripts/sway/form_matter.gd")
## Its spikes in flight (Flight): a guard can catch, deflect or cushion them (BendZone).
const FLIGHT_GROUP := &"bend_stone_flights"
const AI_PATH := "res://data/npc/bend_ai.json"
## The one cast entry for any caster (BendCast, bend_cast.gd beside BendEffects' script): used when it exists and has its
## static cast().
const BEND_CAST_FILE := "bend_cast.gd"
## Its element's circle at its own feet while it locks (the owner allowed it: own side, own colour; never on anyone else).
const SHOW_LOCK_CIRCLE := true
const CIRCLE_R := 0.9
## The old spells it casts its own way while BendCast is not there.
const FALLBACK := ["stone_form/spike", "earth_wall/wall", "gust/push"]
## The old names a test or a mode may force (_next[name] = a clock time: cast first once it is reached).
const LEGACY := {"spike": ["stone_form/spike", "stone_form/disc"], "wall": ["earth_wall/wall", "earth_wall/shell"], "gust": ["gust/push", "air_palm/palm"]}
## The fallback spike's numbers (a stone raised before it as the lock fills, then hurled: Flight).
const SPIKE := {"ahead_m": 1.3, "mps": 30.0, "gravity": 3.0, "damage": 34.0}
const WALL := {"ahead_m": 1.6}
const GUST := {"reach_m": 7.0, "push_mps": 9.0, "up_mps": 3.0}
const STRAFE_S := Vector2(1.4, 3.0)
## After a release the cast clip plays on this long (busy: it does not walk off mid-swing).
const FOLLOW_S := 0.3
## A dash's own speed fades at the fighter's DECEL; its first part carried (BendMotion: CARRY_S).
const CARRY_S := 0.25
## Threats: a thing passing nearer than this to its chest is coming at it.
const THREAT_MISS_M := 1.6
## A lock filled less than this is let go for a guard (a reaction) against what comes at it.
const SWITCH_FILL := 0.35
## A man's wind-up read (his lock on a throw or a bolt, _threats): his strike comes this long after his lock is full (s).
const READ_STRIKE_S := 0.1

static var _ai := {}
static var _bend_cast: Script = null
static var _bend_cast_checked := false

var brain: NpcBrain
var me: NpcFighter
var caster: NpcBendCaster
## Its element (Bending.ELEMENTS).
var element := "earth"
## Every option: {id, mode, key "id/mode", spec, do, hint, water, knock, old}.
var options: Array[Dictionary] = []
## The lock: the move locking ("" none), its mode, how full (0..1), its time and how long it has filled.
var casting := ""
var mode := ""
var fill := 0.0
var lock_s := 0.0
var lock_t := 0.0
var circle: FormCircle
## The ring's: where it may stand (pos -> pos), and metres to the open end (pos, dir -> m); invalid: no ring.
var bounds_fn: Callable
var edge_fn: Callable
## Counts.
var casts := 0
var casts_by := {}
var hits := 0
var catches := 0
var answered := 0
var lost := 0
var lost_why := ""
var reactions_by := {}
var spikes := 0
var walls := 0
var gusts := 0
var last_wall: FormRaised
## The last release ({move, mode, lock_s, took_s, ok, at}) and the last locks (the tests' lock check).
var last_cast := {}
var locks: Array[Dictionary] = []
## Forcing: an option key or a LEGACY name -> the clock time from which it is cast first (tests; the duel's old use).
var _next := {}
var _cool := {}
var _rest_until := 0.0
var _hurt_t := -100.0
var _lock_at := 0.0
var _follow := 0.0
var _stone: FormStone
var _strafe := 1.0
var _strafe_t := 0.0
var _last_key := ""
var _last_t := -100.0
var _guards: Array = []
var _watched := {}
var _watch_until := -1.0
var _threat_seen := {}
var _alt := false
## The opening grace: no attack begun before this (BendStatus clock); whether it was held at its last tick.
var _grace_until := 0.0
var _was_held := false
## Its catches seen so far (a new one answered with a shove).
var _catches_seen := 0
## No new guard begun before this (bend_ai.json guard_cool_s after any guard: one guard after another, of whatever kind,
## would turtle; the moves' own cools are per option).
var _guard_until := 0.0


func _init(b: NpcBrain) -> void:
	brain = b
	me = b.me
	var el := String(me.get(&"element")) if me.get(&"element") != null else ""
	element = el if el in Bending.ELEMENTS else "earth"
	if me.get(&"element") != null:
		me.set(&"element", element)
	var pr := preset()
	caster = NpcBendCaster.new(me, float(pr.get("lead", 0.8)), float(pr.get("scatter_deg", 1.8)))
	caster.bind()
	_build_options()
	if me.is_inside_tree():
		Bending.of(me).element = element
	_grace_until = _now() + float(pr.get("grace_s", 0.0))


# ---------------------------------------------------------------- data
static func ai() -> Dictionary:
	if _ai.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(AI_PATH)) if FileAccess.file_exists(AI_PATH) else null
		_ai = d if d is Dictionary else {"presets": {}, "defaults": {}}
	return _ai


## The difficulty's numbers (bend_ai.json presets: easy, normal, hard; normal for a fighter with none).
static func preset_of(name: String) -> Dictionary:
	var ps: Dictionary = ai().get("presets", {})
	return ps.get(name, ps.get("normal", {}))


func preset() -> Dictionary:
	return preset_of(_preset_name())


func _preset_name() -> String:
	var p := String(me.skill_preset) if me != null else ""
	return p if (ai().get("presets", {}) as Dictionary).has(p) else "normal"


## BendCast's script when it is there (its static cast(c, id, mode, t, at)); null else.
static func bend_cast() -> Script:
	if not _bend_cast_checked:
		_bend_cast_checked = true
		var path := (BendEffects as Script).resource_path.get_base_dir().path_join(BEND_CAST_FILE)
		if ResourceLoader.exists(path):
			var s := load(path) as Script
			if s != null:
				for m: Dictionary in s.get_script_method_list():
					if String(m.get("name", "")) == "cast":
						_bend_cast = s
						break
	return _bend_cast


static func spec_of(id: String, md: String) -> Dictionary:
	var b: Variant = SwayMoves.move(id).get("bend", {})
	return ((b as Dictionary).get(md, {}) as Dictionary) if b is Dictionary else {}


## Every (move, mode) of `el`'s keys (Bending.keys), Mend and Patch with them.
static func pairs_of(el: String) -> Array:
	var out: Array = []
	for pair in Bending.keys(el):
		for id: String in pair:
			var ms := SwayCaster.modes_of(id)
			if ms.is_empty():
				out.append([id, ""])
			for md: String in ms:
				out.append([id, md])
	return out


func _build_options() -> void:
	options.clear()
	for pr: Array in pairs_of(element):
		var id := String(pr[0])
		var md := String(pr[1])
		var spec := spec_of(id, md)
		var o := {"id": id, "mode": md, "key": id + "/" + md, "spec": spec, "old": spec.is_empty(),
				"do": String(spec.get("do", "old")), "water": float(spec.get("water", 0.0)),
				"knock": float(spec.get("knock_mps", 0.0))}
		o["hint"] = hint_of(id, md, spec)
		options.append(o)


## What bend_ai.json says of (id, md): its do's defaults (a zone's by its kind; an unknown do or 'throw' as 'bolt'), the old
## spells' own, then the move's.
static func hint_of(id: String, md: String, spec: Dictionary) -> Dictionary:
	var d := ai()
	var h := {}
	if spec.is_empty():
		var old: Dictionary = (d.get("old", {}) as Dictionary).get(id, {})
		h = (old.get(md, {"role": "defence"}) as Dictionary).duplicate(true)
	else:
		var dn := String(spec.get("do", "bolt"))
		var defs: Dictionary = d.get("defaults", {})
		if not defs.has(dn):
			dn = "bolt"
		h = (defs.get(dn, {}) as Dictionary).duplicate(true)
		if dn == "zone":
			var zk := String(spec.get("zone", ""))
			var zh: Dictionary = (d.get("zones", {}) as Dictionary).get(zk, {})
			for k: String in zh:
				h[k] = zh[k]
		if dn == "buff":
			match String(spec.get("buff", "")):
				"anchor":
					h["role"] = "defence"
				"redirect_lightning":
					h["role"] = "reaction"
					h["answers"] = ["lightning"]
	var mv: Dictionary = ((d.get("moves", {}) as Dictionary).get(id, {}) as Dictionary).get(md, {})
	for k: String in mv:
		h[k] = mv[k]
	if not h.has("role"):
		h["role"] = "offence"
	return h


# ---------------------------------------------------------------- the lock (the player's rule)
## Whether (id, md) locks at the caster (no range stretch): the pillar's self, Stone Form, a self_lock move (SwayCaster._self_cast).
static func self_cast(id: String, md: String) -> bool:
	return (id == "pillar" and md == "self") or id == "stone_form" or bool(SwayMoves.move(id).get("self_lock", false))


## Move `id`'s reach in mode `md` (SwayCaster.range_of: mode_range_m, else range_m).
static func range_of(id: String, md: String) -> float:
	var d := SwayMoves.move(id)
	var mr: Dictionary = d.get("mode_range_m", {})
	if md != "" and mr.has(md):
		return float(mr[md])
	return float(d.get("range_m", 20.0))


## The lock time (s) of (id, md) for a bot of difficulty `preset_name` casting `dist` m off: exactly the player's
## (SwayCaster._try_begin: base x stretch x lock_mult x tier_mult) with the expert tier (free use) and the preset's lock_mult
## for his lock_mult; the move's ai_factor only where the preset says (easy, normal).
static func lock_for(id: String, md: String, preset_name := "hard", dist := 0.0) -> float:
	var d := SwayMoves.move(id)
	var base := float(d.get("lock_s", 1.0))
	var mlk: Dictionary = d.get("mode_lock_s", {})
	if id == "gust" and md == "lift":
		base = float((d.get("stone", {}) as Dictionary).get("lock_s", base))
	elif mlk.has(md):
		base = float(mlk[md])
	var stretch := 1.0
	if not self_cast(id, md):
		var r := range_of(id, md)
		stretch = lerpf(1.0, float(d.get("far_stretch", 1.0)), smoothstep(r * 0.5, r, dist))
	var lm: Array = (SwayMoves.data().get("mastery", {}) as Dictionary).get("lock_mult", [1.4, 1.0, 0.8])
	var tier := 2 if SwayCaster.free_use() else 1
	var tm := float(lm[clampi(tier, 0, lm.size() - 1)]) if not lm.is_empty() else 1.0
	var pr := preset_of(preset_name)
	var mult := float(pr.get("lock_mult", 1.0))
	if bool(pr.get("ai_factor", false)):
		mult *= float(d.get("ai_factor", 1.0))
	return maxf(base * stretch * tm * mult, 0.05)


func lock_fill() -> float:
	return fill


## (id, md)'s cast point: the ground ahead for a raised thing, else the foe's chest (INF: none).
func _cast_point(id: String, md: String, t: Node3D) -> Vector3:
	var way := _way(t)
	match id + "/" + md:
		"earth_wall/wall":
			return FormEffects.ground_at(me, me.global_position + way * float(WALL.ahead_m))
		"pillar/self":
			return FormEffects.ground_at(me, me.global_position)
		"pillar/free", "pillar/ramp":
			var r := minf(range_of(id, md) * 0.6, _flat_d(t) * 0.5 if t != null else 4.0)
			return FormEffects.ground_at(me, me.global_position + way * maxf(r, 2.0))
		"mend/":
			var w := _own_wall(true, 6.0)
			return w.global_position + Vector3.UP if w != null else Vector3.INF
	return NpcSenses.chest_of(t) if t != null and is_instance_valid(t) else Vector3.INF


func _cast_dist(id: String, md: String, t: Node3D) -> float:
	if self_cast(id, md):
		return 0.0
	var at := _cast_point(id, md, t)
	if at == Vector3.INF:
		return 0.0
	if id in ["earth_wall", "pillar", "mend"]:
		return Vector2(at.x - me.global_position.x, at.z - me.global_position.z).length()
	return NpcSenses.chest_of(me).distance_to(at)


# ---------------------------------------------------------------- each think (NpcBrain, COMBAT)
## The old name (NpcBrain calls it each think).
func step(dt: float) -> void:
	think(dt)


func reset() -> void:
	_cancel()
	_rest_until = 0.0
	_grace_until = _now() + float(preset().get("grace_s", 0.0))


## Whether its opening grace still runs (no attack, no control begun).
func in_grace() -> bool:
	return _now() < _grace_until


func think(dt: float) -> void:
	if me.held or me.is_dead():
		return
	var t := brain.target
	if not NpcSenses.can_fight(t):
		return
	if casting != "" or _follow > 0.0 or me.busy():
		return
	var d := _flat_d(t)
	if _now() >= _rest_until or _forced_any():
		var pick := _choose(t, d)
		if not pick.is_empty():
			begin(String(pick.id), String(pick.mode))
			return
	_move(dt, t, d)


## Each physics frame (NpcFighter._physics_process, not while held): the lock filled and released, the threats answered, its
## own speed braked short of an open end.
func tick(dt: float) -> void:
	if me.is_dead():
		return
	if me.held:
		_was_held = true
		if casting != "":
			_cancel()
		return
	if _was_held:
		# (let go: the round's start; its opening grace from now)
		_was_held = false
		_grace_until = _now() + float(preset().get("grace_s", 0.0))
	if edge_fn.is_valid() and not me.on_deck:
		me.on_deck = true
	_watch()
	_edge_brake()
	if casting != "":
		if me.action != "cast":
			_lose("flinch")
			return
		if fill < SWITCH_FILL and String((_option(casting + "/" + mode).get("hint", {}) as Dictionary).get("role", "")) != "reaction":
			# (a lock barely begun let go for a guard against what comes at it now)
			var g := _reaction()
			if not g.is_empty():
				reactions_by[String(g.kind)] = int(reactions_by.get(String(g.kind), 0)) + 1
				begin(String(g.id), String(g.mode))
				return
		lock_t += dt
		fill = clampf(lock_t / maxf(lock_s, 0.001), 0.0, 1.0)
		if circle != null and is_instance_valid(circle):
			circle.fill = fill
			if fill >= 1.0 and not circle.full:
				circle.full = true
		var t := brain.target
		if t != null and is_instance_valid(t):
			me.face_point(t.global_position)
		if lock_t >= lock_s - 1e-5:
			_release()
		return
	if _follow > 0.0:
		_follow -= dt
		if _follow <= 0.0 and me.action == "cast":
			me.action = ""
	if brain.state == NpcBrain.State.COMBAT and (me.action in ["", "knocked"] or _follow > 0.0):
		var r := _reaction()
		if not r.is_empty():
			reactions_by[String(r.kind)] = int(reactions_by.get(String(r.kind), 0)) + 1
			begin(String(r.id), String(r.mode))


# ---------------------------------------------------------------- choosing
func _now() -> float:
	return BendStatus.now()


func _forced_any() -> bool:
	for k: String in _next:
		if float(_next[k]) <= _now():
			return true
	return false


func _option(key: String) -> Dictionary:
	for o: Dictionary in options:
		if String(o.key) == key:
			return o
	return {}


## Whether option `o` can be cast now: off its cool, its water paid for, an old spell only through BendCast (or its own way).
func castable(o: Dictionary) -> bool:
	if _now() < float(_cool.get(String(o.key), 0.0)):
		return false
	if float(o.water) > 0.0:
		var bw := Bending.of(me)
		if bw == null or bw.water < float(o.water):
			return false
	if bool(o.old):
		return bend_cast() != null or String(o.key) in FALLBACK
	return true


## The forced option now (a LEGACY name's first castable, or a key), {} none.
func _forced() -> Dictionary:
	for k: String in _next.keys():
		if float(_next[k]) > _now():
			continue
		var keys: Array = LEGACY.get(k, [k])
		for key: String in keys:
			var o := _option(key)
			if not o.is_empty() and castable(o):
				return o
	return {}


func _choose(t: Node3D, d: float) -> Dictionary:
	var f := _forced()
	if not f.is_empty():
		return f
	var d_ai := ai()
	var roles: Dictionary = d_ai.get("roles", {})
	var el: Dictionary = (d_ai.get("elements", {}) as Dictionary).get(element, {})
	var el_roles: Dictionary = el.get("roles", {})
	var hidden := NpcBendCaster.hidden(me, t)
	var seen := brain.seen_now and not hidden
	var grace := in_grace()
	var best: Dictionary = {}
	var best_w := 0.05
	for o: Dictionary in options:
		if not castable(o):
			continue
		var h: Dictionary = o.hint
		var role := String(h.get("role", "offence"))
		if role == "reaction":
			continue
		if role in ["offence", "control"] and (not seen or grace):
			continue
		if grace and float(o.knock) > 0.0:
			continue
		var band := _band(h, o.spec)
		if band.y > 0.0 and (d < band.x or d > band.y):
			continue
		var ok := true
		for c: String in h.get("when", []):
			if not _when(c, t, d):
				ok = false
				break
		if not ok:
			continue
		if String(o.do) in ["dash"] or (String(o.do) == "old" and String(o.key) == "pillar/self"):
			if not _dash_safe(o, t):
				continue
		if String(o.do) == "buff" and String(o.spec.get("buff", "")) in ["run", "scooter"] and not _run_safe(o, t):
			continue
		if String(o.key) == "gust/lift" and _lift_stone(t) == null:
			continue
		var w := float(roles.get(role, 0.5)) * float(el_roles.get(role, 1.0)) * float(h.get("weight", 1.0))
		if float(o.knock) >= 8.0:
			w *= float(el.get("knock", 1.0))
		var n_cast := int(casts_by.get(String(o.key), 0))
		if n_cast == 0:
			w *= float(d_ai.get("novel_bonus", 1.3))
		else:
			w /= 1.0 + float(d_ai.get("repeat_k", 0.3)) * n_cast         # (the same move again and again: less likely)
		var cb: Dictionary = h.get("combo", {})
		if not cb.is_empty() and String(cb.get("after", "")) == _last_key and _now() - _last_t < 2.5:
			w *= float(cb.get("bonus", 2.0))
		w *= me.rng.randf_range(0.7, 1.3)
		if w > best_w:
			best_w = w
			best = o
	return best


## Option range band [near, far] (m; far 0: none): its hint's range_m, "spec" read from the spec (range_m, else radius_m).
func _band(h: Dictionary, spec: Dictionary) -> Vector2:
	var r: Variant = h.get("range_m", null)
	if not (r is Array) or (r as Array).size() < 2:
		return Vector2(0.0, 0.0)
	var lo := float(r[0])
	var hi_v: Variant = r[1]
	var hi := 0.0
	if hi_v is String:
		hi = float(spec.get("range_m", spec.get("radius_m", 20.0)))
		if String(spec.get("do", "")) == "ring":
			hi = float(spec.get("radius_m", 4.0)) * 0.85
		elif String(spec.get("do", "")) == "cone":
			hi = float(spec.get("range_m", spec.get("radius_m", 5.0))) * 0.9
		hi = minf(hi, 26.0)
	else:
		hi = float(hi_v)
	return Vector2(lo, hi)


## Whether need `c` holds now (bend_ai.json's when).
func _when(c: String, t: Node3D, d: float) -> bool:
	var d_ai := ai()
	match c:
		"hurt":
			return _now() - _hurt_t < float(d_ai.get("hurt_s", 2.5)) or me.health < me.health_max * 0.5
		"close":
			return d < float(d_ai.get("close_m", 5.0))
		"far", "foe_far":
			return d > float(d_ai.get("far_m", 14.0))
		"stone_near":
			return _stone_near(t)
		"own_wall":
			return _own_wall(false, 12.0) != null
		"own_damaged_wall":
			return _own_wall(true, 3.0) != null
		"water_low":
			var bw := Bending.of(me)
			return bw != null and bw.water < float(d_ai.get("water_low", 40.0))
		"near_pool":
			var bw2 := Bending.of(me)
			return bw2 != null and bw2.near_water()
		"rooted":
			return BendStatus.until(me, &"bend_root") > 0.0 or BendStatus.until(me, &"bend_slow") > 0.0
		"slowed":
			return BendStatus.until(me, &"bend_slow") > 0.0
		"foe_rooted":
			return BendStatus.until(t, &"bend_root") > 0.0
		"foe_airborne":
			return t is CharacterBody3D and not (t as CharacterBody3D).is_on_floor()
		"airborne":
			return not me.is_on_floor()
		"room_back":
			return _room(-_way(t)) > 6.0
		"edge_behind":
			return edge_fn.is_valid() and _room(-_way(t)) < 4.0
		"ice_near":
			return _ice_near(8.0)
	return false


# ---------------------------------------------------------------- the threats and the guards
## The guard to begin now against what comes at it ({id, mode, kind} or {}): a threat seen for the preset's reaction (x2
## dazzled), its time to impact long enough for the guard's lock, answered at the preset's chance (one roll a threat).
func _reaction() -> Dictionary:
	if _now() < _guard_until:
		return {}
	var t := brain.target
	if t != null and NpcBendCaster.hidden(me, t):
		return {}
	var threats := _threats()
	if threats.is_empty():
		return {}
	var pr := preset()
	var react := float(pr.get("reaction_s", 0.45)) * (2.0 if NpcBendCaster.dazzled(me) else 1.0)
	var now := _now()
	var best: Dictionary = {}
	for th: Dictionary in threats:
		var id := int(th.id)
		if not _threat_seen.has(id):
			var el_react := float(((ai().get("elements", {}) as Dictionary).get(element, {}) as Dictionary).get("react", 1.0))
			_threat_seen[id] = [now, me.rng.randf() < float(pr.get("react_chance", 0.5)) * el_react]
		var seen: Array = _threat_seen[id]
		if not bool(seen[1]) or now - float(seen[0]) < react:
			continue
		var tti := float(th.tti)
		for o: Dictionary in options:
			var h: Dictionary = o.hint
			if String(h.get("role", "")) != "reaction" or not String(th.kind) in (h.get("answers", []) as Array) or not castable(o):
				continue
			var ls := lock_for(String(o.id), String(o.mode), _preset_name(), 0.0)
			var window := float(o.spec.get("window_s", o.spec.get("life_s", o.spec.get("s", 1.0))))
			if ls > tti or ls + window * 0.8 < tti:
				continue
			if best.is_empty() or ls < float(best.ls):
				best = {"id": o.id, "mode": o.mode, "kind": th.kind, "ls": ls}
	if _threat_seen.size() > 64:
		_threat_seen.clear()
	return best


## What comes at it now: [{id, kind, tti}] (BendBolt and a bot's spike by their flight; a hurled GustLift stone; the foe's
## lightning by his lock's fill).
func _threats() -> Array:
	var out: Array = []
	var tree := me.get_tree()
	var c := NpcSenses.chest_of(me)
	for b in tree.get_nodes_in_group(BendBolt.GROUP):
		var bb := b as BendBolt
		if bb == null or bb.spent or bb.caster == me:
			continue
		var tti := _closing(bb.global_position, bb.velocity, c)
		if tti >= 0.0:
			out.append({"id": bb.get_instance_id(), "kind": bb.kind, "tti": tti})
	for f in tree.get_nodes_in_group(FLIGHT_GROUP):
		var fl := f as Flight
		if fl == null or fl.shooter == me or fl.stone == null or not is_instance_valid(fl.stone):
			continue
		var tti2 := _closing(fl.stone.global_position, fl.velocity, c)
		if tti2 >= 0.0:
			out.append({"id": fl.get_instance_id(), "kind": "stone", "tti": tti2})
	for g in tree.get_nodes_in_group(GustLift.GROUP):
		var st: Variant = g.get(&"stone")
		var v: Variant = g.get(&"velocity")
		if not (st is Node3D) or not is_instance_valid(st) or not (v is Vector3) or (v as Vector3).length() < 3.0:
			continue
		if _caster_body(g.get(&"caster")) == me:
			continue
		var tti3 := _closing((st as Node3D).global_position, v as Vector3, c)
		if tti3 >= 0.0:
			out.append({"id": (g as Object).get_instance_id(), "kind": "stone", "tti": tti3})
	var t := brain.target
	if t != null and is_instance_valid(t):
		var sc := SwayCaster.of(t) if t is FrontierPlayer else null
		if sc != null and sc.state != SwayCaster.State.IDLE and sc.move == "fire_arc" and sc.mode_of("fire_arc") == "lightning":
			out.append({"id": sc.get_instance_id(), "kind": "lightning", "tti": maxf((1.0 - sc.fill) * sc.lock_s, 0.0) + 0.05})
		elif sc != null and sc.state != SwayCaster.State.IDLE and sc.move != "":
			# (his wind-up read: a throw or a bolt he is locking, its stone or its element on its way when he lets go)
			var md := sc.mode_of(sc.move)
			var shot := shot_of(sc.move, md)
			if not shot.is_empty():
				var left := maxf((1.0 - sc.fill) * sc.lock_s, 0.0)
				var began := int((_now() - sc.fill * sc.lock_s) * 10.0)
				out.append({"id": hash([sc.get_instance_id(), sc.move, md, began]), "kind": shot.kind,
						"tti": left + READ_STRIKE_S + c.distance_to(NpcSenses.chest_of(t)) / float(shot.mps)})
		elif t is NpcFighter and (t as NpcFighter).brain != null and (t as NpcFighter).brain.bending != null:
			var ob := (t as NpcFighter).brain.bending
			if ob.casting == "fire_arc" and ob.mode == "lightning":
				out.append({"id": ob.get_instance_id(), "kind": "lightning", "tti": maxf(ob.lock_s - ob.lock_t, 0.0) + 0.05})
			elif ob.casting != "":
				var shot2 := shot_of(ob.casting, ob.mode)
				if not shot2.is_empty():
					out.append({"id": hash([ob.get_instance_id(), ob.casting, ob.mode, int(ob._lock_at * 100.0)]), "kind": shot2.kind,
							"tti": maxf(ob.lock_s - ob.lock_t, 0.0) + c.distance_to(NpcSenses.chest_of(t)) / float(shot2.mps)})
	return out


## What (id, md) sends flying at whom it is cast at: {kind, mps} (a bolt's or a throw's spec; Stone Form's spike and boulder
## and Earth Shove a stone; Gust lift a stone), {} for anything else (the wind-up a bot reads: _threats).
static func shot_of(id: String, md: String) -> Dictionary:
	var spec := spec_of(id, md)
	var dn := String(spec.get("do", ""))
	if dn in ["bolt", "throw"]:
		return {"kind": String(spec.get("kind", "stone")), "mps": maxf(float(spec.get("mps", 30.0)), 5.0)}
	if dn == "shove":
		return {"kind": "stone", "mps": float((SwayMoves.move("gust").get("raised", {}) as Dictionary).get("mps", 26.0))}
	if spec.is_empty() and id == "stone_form":
		var hurl: Dictionary = ((SwayMoves.move("stone_form").get("throw", {}) as Dictionary).get("hurl", {}) as Dictionary).get(md if md != "" else "spike", {})
		var mps: Variant = hurl.get("mps", [30.0])
		return {"kind": "stone", "mps": maxf(float(mps[mps.size() - 1]) if mps is Array else float(mps), 5.0)}
	if spec.is_empty() and id == "gust" and md == "lift":
		return {"kind": "stone", "mps": 24.0}
	return {}


## Seconds until something at `p` going `v` passes nearest `c`, when that is nearer than THREAT_MISS_M (else -1).
static func _closing(p: Vector3, v: Vector3, c: Vector3) -> float:
	var vv := v.length_squared()
	if vv < 1.0:
		return -1.0
	var rel := p - c
	var ts := -rel.dot(v) / vv
	if ts <= 0.0 or ts > 3.0:
		return -1.0
	return ts if (rel + v * ts).length() <= THREAT_MISS_M else -1.0


static func _caster_body(c: Variant) -> Node:
	if c == null or not (c is Object) or not is_instance_valid(c):
		return null
	for k: StringName in [&"body", &"player"]:
		var b: Variant = (c as Object).get(k)
		if b is Node:
			return b
	return c as Node if c is Node else null


# ---------------------------------------------------------------- the lock and the release
## The lock of (id, md) begun (its time: lock_for; its pose; its circle).
func begin(id: String, md: String) -> void:
	if casting != "":
		_cancel()
	var t := brain.target
	casting = id
	mode = md
	lock_t = 0.0
	fill = 0.0
	lock_s = lock_for(id, md, _preset_name(), _cast_dist(id, md, t))
	_lock_at = _now()
	if String((_option(id + "/" + md).get("hint", {}) as Dictionary).get("role", "")) == "reaction":
		_guard_until = _lock_at + lock_s + float(ai().get("guard_cool_s", 0.0))
	_follow = 0.0
	for k: String in _next.keys():
		var keys: Array = LEGACY.get(k, [k])
		if (id + "/" + md) in keys:
			_next.erase(k)
	me.halt()
	me.face_lock = Vector3.INF
	if t != null and is_instance_valid(t):
		me.face_point(t.global_position)
	me.action = "cast"
	if me.body != null:
		me.body.play_cast(id, md, lock_s, element)
	if bend_cast() == null and id == "stone_form" and md == "spike":
		_raise_spike(t)
	if SHOW_LOCK_CIRCLE and me.is_inside_tree():
		var scn := me.get_tree().current_scene
		if scn != null:
			var col := MatchSetup.color(element)
			circle = FormCircle.make(scn, FormEffects.ground_at(me, me.global_position), Vector3.UP, CIRCLE_R, col)


func _release() -> void:
	var id := casting
	var md := mode
	var key := id + "/" + md
	var took := lock_t                             # (the physics time it filled over: its frames' dt)
	casting = ""
	fill = 0.0
	if circle != null and is_instance_valid(circle):
		circle.end("cast")
	circle = null
	_follow = FOLLOW_S
	var t := brain.target
	var pr := preset()
	caster.lead = float(pr.get("lead", 0.8))
	caster.scatter_deg = float(pr.get("scatter_deg", 1.8))
	caster.modes[id] = md
	caster.side = _pick_side(t)
	var before := BendEffects.last_of(caster)
	var ok := _cast(id, md, t)
	locks.append({"move": id, "mode": md, "lock_s": lock_s, "took_s": took, "clip": me.body.cast_clip if me.body != null else ""})
	if locks.size() > 64:
		locks.pop_front()
	last_cast = {"move": id, "mode": md, "lock_s": lock_s, "took_s": took, "ok": ok, "at": _now()}
	if ok:
		casts += 1
		casts_by[key] = int(casts_by.get(key, 0)) + 1
		match key:
			"stone_form/spike":
				spikes += 1
			"earth_wall/wall":
				walls += 1
		if id == "gust":
			gusts += 1
	var o := _option(key)
	_cool[key] = _now() + float((o.get("hint", {}) as Dictionary).get("cool_s", 2.5)) if not o.is_empty() else _now() + 2.5
	var rs: Variant = pr.get("rest_s", [0.5, 1.0])
	_rest_until = _now() + (me.rng.randf_range(float(rs[0]), float(rs[1])) if rs is Array else float(rs))
	_last_key = key
	_last_t = _now()
	_after_cast(o, before)


## Casts (id, md) now through the one path: BendCast.cast when it is there; a bend spec through BendEffects with its caster;
## else its own way for spike, wall and gust push (FALLBACK). False: nothing came of it (no water, nothing to work on).
func _cast(id: String, md: String, t: Node3D) -> bool:
	var spec := spec_of(id, md)
	var at := _cast_point(id, md, t)
	if id == "gust" and md == "lift":
		# (Gust lift is a stone held and hurled at him: cast on the stone, never on the man himself)
		var st := _lift_stone(t)
		if st == null:
			return false
		t = st
		at = st.global_position
	var bc := bend_cast()
	if bc != null:
		var r: Variant = bc.call(&"cast", caster, id, md, t, at)
		if r is bool:
			return bool(r)
		return String(BendEffects.last_of(caster).get("do", "")) != "dry"
	if not spec.is_empty():
		BendEffects.apply(caster, id, md, spec, t, at)
		return String(BendEffects.last_of(caster).get("do", "")) != "dry"
	match id + "/" + md:
		"stone_form/spike":
			return _throw(t)
		"earth_wall/wall":
			return _wall(t)
		"gust/push":
			return _gust(t)
	return false


## What the cast left to watch: its bolts and hurled stones (hits), its guard (catches). `before`: last_of its caster before
## the cast (the same: the cast went another way, nothing of it there).
func _after_cast(o: Dictionary, before: Dictionary) -> void:
	_watch_until = _now() + 1.2
	var last := BendEffects.last_of(caster)
	if is_same(last, before):
		return
	if not o.is_empty() and String(o.do) in ["cone", "ring", "status_at", "lightning", "grab", "column"]:
		hits += int(last.get("hit", 0))
	var z: Variant = last.get("zone")
	if z != null and is_instance_valid(z) and z is BendZone and (z as BendZone).kind in BendZone.GUARDS:
		_guards.append([z, (z as BendZone).took])


## Each frame: new bolts and hurled stones of its own connected (their strikes counted), its guards' takings counted.
func _watch() -> void:
	if _now() <= _watch_until:
		var tree := me.get_tree()
		for b in tree.get_nodes_in_group(BendBolt.GROUP):
			var bb := b as BendBolt
			if bb == null or bb.caster != me or _watched.has(bb.get_instance_id()):
				continue
			_watched[bb.get_instance_id()] = true
			bb.struck.connect(_on_struck)
		for g in tree.get_nodes_in_group(GustLift.GROUP):
			if _watched.has((g as Object).get_instance_id()) or _caster_body(g.get(&"caster")) != me:
				continue
			_watched[(g as Object).get_instance_id()] = true
			if g.has_signal(&"struck"):
				g.connect(&"struck", _on_struck)
		if _watched.size() > 256:
			_watched.clear()
	for i in range(_guards.size() - 1, -1, -1):
		var e: Array = _guards[i]
		var z: Variant = e[0]
		if not is_instance_valid(z):
			_guards.remove_at(i)
			continue
		var bz := z as BendZone
		if bz.took > int(e[1]):
			var n := bz.took - int(e[1])
			answered += n
			if bz.kind in ["catch", "cushion"]:
				catches += n
			e[1] = bz.took
	if catches > _catches_seen:
		_catches_seen = catches
		_answer_catch()


## A stone it caught and holds sent back: Earth Shove (push) forced as soon as its reaction allows, its rest cut short
## (the shove's own cool waived: the catch is the moment).
func _answer_catch() -> void:
	if element != "earth" or _option("earth_shove/push").is_empty():
		return
	var held := false
	for st in me.get_tree().get_nodes_in_group(FormStone.GROUP):
		if int((st as Node).get_meta(&"bend_held_by", -1)) == me.get_instance_id():
			held = true
			break
	if not held:
		return
	var at := _now() + float(preset().get("reaction_s", 0.4)) * 0.5
	_next["earth_shove/push"] = at
	_cool.erase("earth_shove/push")
	_rest_until = minf(_rest_until, at)


func _on_struck(who: Node, _dmg: float) -> void:
	if who != null and who != me:
		hits += 1


## A hit taken (NpcFighter.apply_hit, any damage above 0): the lock lost (as a hit breaks the player's); its "hurt" need.
func on_hurt(dmg: float, _source: Node = null) -> void:
	if dmg <= 0.0:
		return
	_hurt_t = _now()
	if casting != "":
		_lose("hit")


## A knock taken (BendKnock, through NpcFighter.on_bend_knock): the lock lost.
func on_knocked(_v: Vector3, _by: Node = null) -> void:
	if casting != "":
		_lose("knock")


## Its fighter leaving the world (freed between rounds, cleared): its lock let go, the zones it holds round itself (guards,
## bubbles, shields: they follow it) ended, so none is left reading a body that is gone.
func on_exit() -> void:
	_cancel()
	if not me.is_inside_tree():
		return
	for z in me.get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.owner_node == me and bz.follow:
			bz.set_physics_process(false)
			bz.end()
	_guards.clear()


func _lose(why: String) -> void:
	if casting == "":
		return
	lost += 1
	lost_why = why
	_cool[casting + "/" + mode] = _now() + 0.8
	_drop_lock("break")


## The lock dropped without a count (held by a mode, a reset).
func _cancel() -> void:
	if casting == "":
		return
	_drop_lock("break")


func _drop_lock(how: String) -> void:
	casting = ""
	fill = 0.0
	_follow = 0.0
	if me.action == "cast":
		me.action = ""
	if circle != null and is_instance_valid(circle):
		circle.end(how)
	circle = null
	_stone = null                                  # (a spike raised and not thrown stands where it rose)


# ---------------------------------------------------------------- the ring: room, dashes, the brake
## Metres of room along `dir` before an open end (edge_fn; INF with no ring).
func _room(dir: Vector3) -> float:
	if not edge_fn.is_valid() or dir.length_squared() < 1e-6:
		return INF
	var r: Variant = edge_fn.call(me.global_position, Vector3(dir.x, 0.0, dir.z).normalized())
	return float(r) if r is float or r is int else INF


## How far a dash of `spec` carries it (m): its carried part, then its own speed fading at the fighter's DECEL, and its time in
## the air.
static func dash_carry(spec: Dictionary) -> float:
	var f := float(spec.get("fwd_mps", 10.0))
	var up := float(spec.get("up_mps", 0.0))
	var air := 2.0 * up / NpcFighter.GRAVITY
	return f * CARRY_S + f * f / (2.0 * NpcFighter.DECEL) + f * air * 0.5


## A dash's way: back (away from the foe), to a side (the side with room), else at the foe.
func _dash_dir(o: Dictionary, t: Node3D) -> Vector3:
	var way := _way(t)
	var spec: Dictionary = o.spec
	if bool(spec.get("back", false)):
		return -way
	if bool(spec.get("side", false)):
		return way.cross(Vector3.UP).normalized() * _pick_side(t)
	return way


## Whether a dash (or the pillar's launch) leaves it on the deck: the room along its way past what it carries (edge_margin_m).
func _dash_safe(o: Dictionary, t: Node3D) -> bool:
	if not edge_fn.is_valid():
		return true
	var spec: Dictionary = o.spec if not bool(o.old) else {"fwd_mps": 6.0, "up_mps": 8.0}
	var margin := float(ai().get("edge_margin_m", 1.5))
	return _room(_dash_dir(o, t)) > dash_carry(spec) + margin


## A run (wind run, the scooter) only with room at the foe (the brake stops it short of an end).
func _run_safe(_o: Dictionary, t: Node3D) -> bool:
	return not edge_fn.is_valid() or _room(_way(t)) > 8.0


## The sidestep's side (-1 left, 1 right of the way to the foe): the one with more room on a deck, else by chance.
func _pick_side(t: Node3D) -> float:
	var right := _way(t).cross(Vector3.UP).normalized()
	if edge_fn.is_valid():
		var r := _room(right)
		var l := _room(-right)
		if absf(r - l) > 0.5:
			return 1.0 if r > l else -1.0
	return 1.0 if me.rng.randf() < 0.5 else -1.0


## Its own speed toward an open end braked short of it (a dash's carry and a run stopped; never a knock: that is the foe's).
func _edge_brake() -> void:
	if not edge_fn.is_valid():
		return
	var kn := BendKnock.peek(me)
	var base := kn.base_of(me.velocity) if kn != null else me.velocity
	var flat := Vector3(base.x, 0.0, base.z)
	var sp := flat.length()
	if sp < 0.5:
		return
	var dir := flat / sp
	var room := _room(dir)
	var stop := sp * sp / (2.0 * NpcFighter.DECEL) + float(ai().get("edge_margin_m", 1.5)) * 0.5
	if room > stop:
		return
	var bm := me.get_node_or_null(^"BendMotion")
	if bm != null:
		bm.set(&"_carry_t", 0.0)
		bm.set(&"_run_t", 0.0)
	me.velocity -= dir * sp


# ---------------------------------------------------------------- moving between casts
func _move(dt: float, t: Node3D, d: float) -> void:
	var tp := t.global_position
	me.crouch(false)
	var straight := me.on_deck or edge_fn.is_valid()
	var keep: Variant = ((ai().get("elements", {}) as Dictionary).get(element, {}) as Dictionary).get("keep_m", [8.0, 15.0])
	var band := Vector2(float(keep[0]), float(keep[1])) if keep is Array else Vector2(8.0, 15.0)
	var bw := Bending.of(me)
	if element == "water" and bw != null and bw.water < float(ai().get("water_low", 40.0)) and not bw.near_water():
		var pool := _pool_near(30.0)
		if pool != Vector3.INF:
			me.face_lock = Vector3.INF
			me.go(_clamp(pool), NpcFighter.RUN_SPEED, 0.6, straight)
			return
	if not brain.seen_now or d > band.y:
		me.face_lock = Vector3.INF
		var goal := brain.last_seen if brain.last_seen != Vector3.INF else tp
		var to := goal - me.global_position
		to.y = 0.0
		if to.length() > band.x:
			goal = me.global_position + to.normalized() * (to.length() - band.x * 0.8)
		me.go(_clamp(goal), NpcFighter.RUN_SPEED, 1.0, straight)
		return
	var away := me.global_position - tp
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 1e-6 else -me.forward()
	_strafe_t -= dt
	if _strafe_t <= 0.0:
		_strafe = -_strafe if me.rng.randf() < 0.6 else _strafe
		_strafe_t = me.rng.randf_range(STRAFE_S.x, STRAFE_S.y)
	var side := away.cross(Vector3.UP) * _strafe
	if _room(side) < 3.0:
		_strafe = -_strafe
		side = -side
	var want := side * 3.0
	if d < band.x and _room(away) > 4.0:
		want += away * 3.0
	me.face_lock = tp
	me.go(_clamp(me.global_position + want), NpcFighter.RUN_SPEED * 0.75, 0.4, true)


func _clamp(p: Vector3) -> Vector3:
	if bounds_fn.is_valid():
		var r: Variant = bounds_fn.call(p)
		if r is Vector3:
			return r
	return p


func _pool_near(r: float) -> Vector3:
	var best := Vector3.INF
	var bd := r
	for n in me.get_tree().get_nodes_in_group(Bending.POOLS):
		var q := (n as Node3D).global_position
		var dd := q.distance_to(me.global_position)
		if dd < bd:
			bd = dd
			best = q
	return best


# ---------------------------------------------------------------- what is about it
func _way(t: Node3D) -> Vector3:
	if t == null or not is_instance_valid(t):
		return me.forward()
	var v := t.global_position - me.global_position
	v.y = 0.0
	return v.normalized() if v.length_squared() > 1e-6 else me.forward()


func _flat_d(t: Node3D) -> float:
	return NpcBrain._flat(me.global_position, t.global_position) if t != null and is_instance_valid(t) else INF


## A stone Earth Shove would find (BendEffects._shove_target's rule): one it holds, else a stone or one of its raised walls
## within 3 m of the line from its chest to the foe's (within 20 m).
func _stone_near(t: Node3D) -> bool:
	var tree := me.get_tree()
	for s in tree.get_nodes_in_group(FormStone.GROUP):
		if int((s as Node).get_meta(&"bend_held_by", -1)) == me.get_instance_id():
			return true
	if t == null or not is_instance_valid(t):
		return false
	var a := NpcSenses.chest_of(me)
	var b := NpcSenses.chest_of(t)
	var pool: Array = tree.get_nodes_in_group(FormStone.GROUP)
	for w in tree.get_nodes_in_group(FormRaised.GROUP):
		if int((w as Node).get_meta(&"bend_by", -1)) == me.get_instance_id():
			pool.append(w)
	for s in pool:
		var q := (s as Node3D).global_position
		if q.distance_to(me.global_position) > 20.0:
			continue
		if q.distance_to(Geometry3D.get_closest_point_to_segment(q, a, b)) < 3.0:
			return true
	return false


## A stone Gust lift can take for a throw at `t`: one it can lift alone (GustLift.liftable, one caster's weight) within the
## lift's reach (gust.stone.range_m) of it, the nearest to its line to him first; null none.
func _lift_stone(t: Node3D) -> Node3D:
	var sd: Dictionary = SwayMoves.move("gust").get("stone", {})
	var reach := float(sd.get("range_m", 14.0))
	var a := NpcSenses.chest_of(me)
	var b := NpcSenses.chest_of(t) if t != null and is_instance_valid(t) else a + me.forward() * 10.0
	var best: Node3D = null
	var bd := INF
	for s in me.get_tree().get_nodes_in_group(FormStone.GROUP):
		var st := s as Node3D
		if st == null or not GustLift.is_stone(st) or not GustLift.liftable(st) or GustLift.casters_needed(st, sd) > 1:
			continue
		var d := st.global_position.distance_to(a)
		if d > reach:
			continue
		var off := st.global_position.distance_to(Geometry3D.get_closest_point_to_segment(st.global_position, a, b)) + d * 0.2
		if off < bd:
			bd = off
			best = st
	return best


## One of its raised walls up within `r` (damaged: one that has taken hits).
func _own_wall(damaged: bool, r: float) -> FormRaised:
	for w in me.get_tree().get_nodes_in_group(FormRaised.GROUP):
		var fr := w as FormRaised
		if fr == null or not fr.is_up() or int(fr.get_meta(&"bend_by", -1)) != me.get_instance_id():
			continue
		if fr.global_position.distance_to(me.global_position) > r:
			continue
		if damaged and fr.hits <= 0:
			continue
		return fr
	return null


func _ice_near(r: float) -> bool:
	for w in me.get_tree().get_nodes_in_group(FormRaised.GROUP):
		var fr := w as FormRaised
		if fr != null and fr.is_up() and (fr.has_meta(&"bend_ice") or fr.matter == "snow") and fr.global_position.distance_to(me.global_position) <= r:
			return true
	for z in me.get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.kind == "ice_patch" and bz.global_position.distance_to(me.global_position) <= r:
			return true
	return false


## How many distinct (move, mode) it has cast.
func distinct() -> int:
	return casts_by.size()


# ---------------------------------------------------------------- its own way, until BendCast (FALLBACK)
## The spike's stone up before it as the lock begins (the foe reads it rising), thrown at the release (_throw).
func _raise_spike(t: Node3D) -> void:
	var way := _way(t)
	var foot := FormEffects.ground_at(me, me.global_position + way * float(SPIKE.ahead_m))
	var matter := FormMatter.of_ground(me.get_tree(), foot)
	var sd: Dictionary = SwayMoves.move("stone_form").get("spike", {})
	_stone = FormStone.spike(me.get_tree().current_scene, foot, way, sd, me.rng.randi() % 97, matter)
	FormEffects.sfx("rise", foot, -2.0, 0.9)
	GatherFx.stone_chips(me.get_tree().current_scene, foot + Vector3.UP * 0.2, Vector3.UP, 10)


func _throw(t: Node3D) -> bool:
	if _stone == null or not is_instance_valid(_stone) or t == null or not is_instance_valid(t):
		return false
	var from := _stone.global_position + Vector3.UP * _stone.height * 0.5
	var mps := float(SPIKE.mps)
	var aim := caster.target_point(t, mps)
	var tf := from.distance_to(aim) / mps
	aim += Vector3.UP * 0.5 * float(SPIKE.gravity) * tf * tf
	var f := Flight.new()
	f.add_to_group(FLIGHT_GROUP)
	f.stone = _stone
	f.velocity = (aim - from).normalized() * mps
	f.gravity = float(SPIKE.gravity)
	f.damage = float(SPIKE.damage)
	f.shooter = me
	f.owner_ex = me.ray_exclude()
	_stone.take()
	_stone.global_position = from
	me.get_tree().current_scene.add_child(f)
	f.hit.connect(func(_who: Node, _dmg: float) -> void: hits += 1)
	FormEffects.sfx("hurl", from, 0.0, 1.0)
	NpcSenses.noise(from, 30.0, me)
	_stone = null
	return true


func _wall(t: Node3D) -> bool:
	var way := _way(t)
	var foot := FormEffects.ground_at(me, me.global_position + way * float(WALL.ahead_m))
	var matter := FormMatter.of_ground(me.get_tree(), foot)
	if matter == "wood":
		matter = "earth"
	var w: Dictionary = (SwayMoves.move("earth_wall") as Dictionary).get("wall", {})
	var wn := FormMatter.numbers(w, FormMatter.entry("earth_wall", matter), matter)
	var across := Vector3.UP.cross(way).normalized()
	var scn := me.get_tree().current_scene
	last_wall = FormRaised.raise(scn, "wall", Transform3D(Basis(across, Vector3.UP, way), foot), wn, absi(hash(foot)) % 97)
	last_wall.set_meta(&"bend_by", me.get_instance_id())
	FormHollow.dig(scn, FormEffects.ground_at(me, me.global_position + way * 0.4), way, 3.0, 1.5, 600.0)
	FormEffects.sfx("rise", foot, 0.0, 0.55)
	FormEffects.sfx("rumble", foot, -2.0, 0.7)
	GatherFx.fall_dust(scn, foot, 1.5)
	var wg := WalkGrid.of(me.get_tree())
	if wg != null:
		wg.dirty(foot, 4.0)
	return true


## A blast of air at the foe within GUST.reach_m: the one knock (BendStatus.knock: BendKnock, the same as the player's).
func _gust(t: Node3D) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	var scn := me.get_tree().current_scene
	var way := _way(t)
	GatherFx._dust(scn, me.global_position + way * 1.5 + Vector3.UP * 1.0, way, 22, Vector2(0.2, 0.6), 1.4, Color(0.85, 0.85, 0.82, 0.35))
	FormEffects.sfx("hurl", me.global_position, 0.0, 1.4)
	if NpcBrain._flat(me.global_position, t.global_position) > float(GUST.reach_m):
		return true
	BendStatus.knock(t, way * float(GUST.push_mps) + Vector3.UP * float(GUST.up_mps), me)
	return true


## A bent stone in flight (the bot's spike): its point leads (struck as the point reaches a man; a wall met at the point),
## gravity on it; a man met is struck (Hit.deliver, from its bender) and it drops; the world met, it sticks there (its own
## time begins again: FormStone.rest_again). Kept for BendZone's guards (FLIGHT_GROUP) and the ring's clear.
class Flight:
	extends Node

	signal hit(who: Node, damage: float)

	var stone: FormStone
	var velocity := Vector3.ZERO
	var gravity := 3.0
	var damage := 30.0
	var shooter: Node
	var owner_ex: Array[RID] = []
	var _t := 0.0
	var _q: PhysicsShapeQueryParameters3D

	func _physics_process(dt: float) -> void:
		if stone == null or not is_instance_valid(stone):
			queue_free()
			return
		_t += dt
		velocity.y -= gravity * dt
		var dir := velocity.normalized()
		var lead := dir * stone.height * 0.85
		var from := stone.global_position
		var to := from + velocity * dt
		if _q == null:
			_q = PhysicsShapeQueryParameters3D.new()
			var sph := SphereShape3D.new()
			sph.radius = stone.radius * 0.7
			_q.shape = sph
			var ex: Array[RID] = owner_ex.duplicate()
			ex.append(stone.get_rid())
			_q.exclude = ex
		_q.transform = Transform3D(Basis.IDENTITY, from + lead)
		_q.motion = to - from
		var space := stone.get_world_3d().direct_space_state
		var frac := space.cast_motion(_q)
		if frac.size() == 2 and frac[1] < 1.0:
			var at := from + lead + (to - from) * frac[1]
			_q.transform = Transform3D(Basis.IDENTITY, at)
			_q.motion = Vector3.ZERO
			var info := space.get_rest_info(_q)
			var col := instance_from_id(int(info.get("collider_id", 0))) as Node if not info.is_empty() else null
			var who := FormSpikes.taker(col, null) if col != null else null
			if who != null:
				# (a stone's blow is blunt force: all of it now, no wound to bleed: PlayerWounds.kind_of reads the striker's meta)
				var had: Variant = shooter.get_meta(&"damage_kind") if shooter != null and shooter.has_meta(&"damage_kind") else null
				if shooter != null:
					shooter.set_meta(&"damage_kind", "blunt")
				Hit.deliver(col, damage, at, dir, shooter)
				if shooter != null and is_instance_valid(shooter):
					if had == null:
						shooter.remove_meta(&"damage_kind")
					else:
						shooter.set_meta(&"damage_kind", had)
				hit.emit(who, damage)
			_place(from + (to - from) * frac[0], dir)
			if who is CharacterBody3D:
				# (a man struck: it drops by him)
				stone.freeze = false
				stone.sleeping = false
				stone.linear_velocity = velocity * 0.15
			stone.rest_again()
			queue_free()
			return
		_place(to, dir)
		if _t > 4.0:
			stone.freeze = false
			stone.rest_again()
			queue_free()

	func _place(p: Vector3, dir: Vector3) -> void:
		var b := Basis(Quaternion(Vector3.UP, dir)) if dir.length_squared() > 1e-6 else Basis.IDENTITY
		stone.global_transform = Transform3D(b, p)
