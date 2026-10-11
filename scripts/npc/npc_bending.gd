class_name NpcBending
extends RefCounted
## An element bot: a fighter that bends instead of shooting (NpcFighter.tactics "bend"; the duel's opponent and Tidebreak's,
## the ring sport's; the owner, 2026-10-04: "remove the guns in 1v1 its just spells", the bots cast the same moves as the
## player, of any of the four elements). It has no gun and no axe; its moves are the player's own, cast through the same path
## (BendCast.cast when it is there, else BendEffects with its NpcBendCaster: the same specs, lock times, interactions, catches,
## redirects and knockback as his), timed by the same lock:
##   its options   every (move, mode) of its element's kit (round 2's skills, skills_r2/spec.md 3: Bending.keys' 1-5, its
##                 guard on E and its jab on the left button: moves.json "guards", "jabs"); an old Sway spell without a bend
##                 spec (stone_form spike and cannonball, earth_wall wall, pillar self, mend) only through BendCast, except
##                 spike and wall, which it has its own way of casting until then (FALLBACK). A spec that grows (grow: key 2's
##                 first move, fire's Punch into the Fireball) is held past guard_rules.grow_after_s by its element's
##                 grow_chance, and cast grown (the spec with its grow merged over it)
##   the lock      exactly the player's (SwayCaster._try_begin): the move's lock_s, or its mode's mode_lock_s, stretched by the
##                 range as his, x the expert tier's mastery.lock_mult (free use: every spell an expert's), x its difficulty's
##                 lock_mult; a move's ai_factor only on easy and normal (lock_for). It stands while the lock fills (the pose:
##                 NpcBody.play_cast, its strike timed to the release), and SHOW_LOCK_CIRCLE: its element's circle at its own
##                 feet as his is at his (the owner allowed it; nothing is ever drawn on the player or over anyone)
##   a hit         any damage above 0 (NpcFighter.apply_hit: on_hurt) or any knock (BendKnock: on_knocked) pushes the lock
##                 back by what the hit cost its sender (his move's lock time, at least guard_rules.hit_setback_min_s; never
##                 below empty, never wiped), as a hit taken pushes back the player's (spec 2.3); a dash's or a guard's lock
##                 is never pushed back; lightning's charge breaks (lost)
##   the mind      think (every NpcBrain think, 0.25 s): the option with the best utility (data/npc/bend_ai.json: its role,
##                 the element's personality, its range band, its 'when'; a little chance from its own seeded rng; an option
##                 not cast yet a little more, a combo's follow-up much more), else it keeps its range and circles the foe,
##                 facing him; tick (each physics frame, NpcFighter._physics_process): the lock filled, the threats looked
##                 at (BendBolt, a bot's spike in flight, a hurled GustLift stone, the foe's lightning lock, a tornado coming
##                 at it, and his wind-up read: his lock on a throw or a bolt, its time to impact the lock's rest and the
##                 flight; each with its knock) and a guard of its element begun in time (catch, turn, parry, wind guard: the
##                 preset's reaction and chance; any option whose hint 'answers' the threat's kind is a guard too: a dash out
##                 of the line, a wall before a held stone; its hint's min_knock and guard_when met, a dash only with room
##                 for it), its own speed braked short of an open end
##   on the beat   a guard is timed (spec 2.5): the preset's perfect_chance rolled once a threat, the guard then begun so the
##                 hit lands in its first guard_rules.perfect_s (perfect: yours), else later in its window (late: half gets
##                 through); a guard that took nothing (a whiff) makes its next guard's lock whiff_lock_s within whiff_s,
##                 as the player's; counted per guard (perfects, lates, whiffs)
##   the floor     a wave along the deck (the Kick's floor wave, a Boulder rolling at it: kind "floor") is jumped
##                 (NpcFighter.jump, mid-lock too, as the player's Space) by the preset's jump_chance, the takeoff timed so
##                 its feet are over miss_above_m as it passes; up from under it (a Column's or a Geyser's wind-up: kind
##                 "under") is stepped off by a dash; hard bots dash on a lightning's flash (lightning_dash)
##   the ring      bounds_fn(pos) -> pos clamped to where it may stand, edge_fn(pos, dir) -> metres to the open end along dir
##                 (INF none): set by the ring (no ring import here); its goals are clamped by the first, its dashes and runs
##                 never taken toward an end closer than they carry, its steering straight on the deck (NpcFighter.on_deck)
##   what hides    the foe behind a cloud (NpcBendCaster.hidden: smoke, dust, spray, steam on the line): no aimed move begun,
##                 no guard (it cannot see him), the scatter tripled; a flare's dazzle (bend_dazzle_until) doubles its scatter
##                 and its reaction
##   the opening   its preset's grace_s from the moment it is let go (the round's "Break!", its first tick unheld; the duel:
##                 from its making): no attack and no control begun (guards, walls and footwork only), so no bot knocks a man
##                 over his line in the first second of a round (the owner's integrator saw a hard air ball land at 0.6 s)
##   catch, return a stone caught and held (its Catch) is sent back by its guard cast again (E again, as the player's: the
##                 return's lock guard_rules.return_lock_s, perfect_return_lock_s after a clean catch) as soon as its
##                 reaction allows: forced, its rest cut short (the earth-vs-earth core: catch it just before it hits and
##                 fire it back); water's, fire's and air's guards send a perfect back by themselves
##   combos        a combo's follow-up much more likely just after its lead (bend_ai.json combo: Kick then Punch, Column
##                 then Spike, Pull then Palm, Geyser then Wave); the Kick by default, the High Kick on a foe in the air or
##                 behind a wall (when foe_up_or_walled)
## Counted for the tests and the ring's HUD: casts, casts_by ("move/mode" -> n), grows_by, hits, catches, clean_catches,
## answered, perfects, lates, whiffs, returns, lost, reactions_by, floor_seen, floor_jumped, jumps, locks (each lock's planned
## and measured time); the old spikes, walls, gusts. Contract: element, casting ("" or the move), mode, grown, fill (0..1),
## lock_s, bounds_fn, edge_fn.
## ROUND 3, the % ring (smash_r3 spec §9; only while RingRules.stock_on(), THE GATE: with it off every line below is skipped
## and the bot is exactly round 2's): its mind is NpcRingMind (mind(): the states, the KO read, true strings, steering and the
## escape, recovery, the edge, keeping him off, the spout, Patch by the rule), and it moves only by its pad (pad(): NpcPad,
## NpcFighter.pad once MOVE's body has one), never by writing velocity: the floor wave jumped by a pad press, the edge brake
## off (the teeter keeps a runner on the deck). Its casts follow the player's round-3 rules: the lock waits (frozen) in
## hitstun instead of being pushed back (lightning's charge still breaks), the jab step, key 3 no sooner than key3_min_s and
## in the air the air dodge, keys 4 and 5 and key 2's first move not begun in the air, a full lock held (never let go into a
## safety). Round 2's combo bonus gives way to the string table (bend_ai.json pct.strings). Practice: set_practice_way(way).
## ROUND 4 (BOTS2, the gate on only): a lock begun in the air takes the player's air form (the jab its air close hit, key 2's
## first move the Slam: NpcRingMind.air_form); landing before the release calls a Slam off for free and turns an air hit back
## into the jab, the time kept; its hops (NpcRingMind.hop_think) before the chooser; its own guard raised early and held as a
## shield against a held Lightning or a big shot (_shield_pick, NpcRingMind.shield_tick), dropped by any other lock; a
## Lightning's threat is one a lock (its roll fresh each time it charges).

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
const LEGACY := {"spike": ["stone_form/spike"], "wall": ["earth_wall/wall"], "gust": ["air_gust/gust", "air_palm/palm"]}
## The guards' zone kinds (BendZone): what each took is counted (perfect, late), a guard that took nothing a whiff.
const GUARD_ZONES := ["catch", "redirect", "parry", "air_shield", "deflect", "cushion", "return", "spin", "absorb"]
## A floor threat: something low on the deck (its middle under this over the deck under it) coming along it.
const FLOOR_M := 0.9
## A rolling stone (a Boulder on the deck) is a floor threat at this pace (m/s) and up.
const ROLL_MPS := 3.0
## Hits within this long of a setback are the same hit (its damage and its knock come apart).
const SETBACK_SAME_S := 0.06
## On a stone: how many times it has been sent back by a catcher, either side's (BendZone.return_stone keeps it): the rally.
const RETURNS_META := &"bend_returns"
## The fallback spike's numbers (a stone raised before it as the lock fills, then hurled: Flight).
const SPIKE := {"ahead_m": 1.3, "mps": 30.0, "gravity": 3.0, "damage": 34.0}
## Its own earth wall raised this far ahead (inside round 2's 2-6 m placing, clear of its own capsule: one raised at 1.6 m
## once threw its caster through the deck, the KITS soak).
const WALL := {"ahead_m": 3.5}
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
## A dash whose landing the ring's bounds pull back across the way to the foe by more than this (m) would leave the deck
## over a long side (_dash_safe).
const SIDE_SLACK_M := 0.5
## A held stone's flight read at this pace (m/s; Gust lift's hurl at full draw is 24 to 30) and, a man's hold, his letting go
## this long from now (s): he lets go when he will.
const HELD_MPS := 26.0
const HELD_LEFT_S := 0.3
## A volley: the light bolts one foe sends within this long of the first of them seen (a stream's three, a jet's six, a
## spread of shards or embers) are one threat for the answer's roll (one roll a volley, not one a bolt: a jet's six rolls
## made an air bot's guard near certain, and its shield sent the whole jet back; R1-BALANCE soak, 2026-10-05). Stones and
## wind-ups keep a roll each (a stone's catch is earth's core: never rarer).
const VOLLEY_S := 1.0
## Round 5: a cone's "pace" as a read threat (it strikes at once on the release: shot_of), and the slack past its reach
## within which its wind-up still reads as a threat (m).
const CONE_MPS := 400.0
const CONE_SLACK_M := 1.0
## Round 5: the move that throws a held stone besides the guard's E (earth's Shove).
const HELD_SHOVE := "earth_shove/push"
## How far a move that throws a held stone (its spec's held_stone "throw": earth's 2, the Fissure) reaches while one is held
## (m): the stone's throw, not the move's own crack (the Shove's band, kept when the Shove became the Fissure, 2026-10-10).
const HELD_THROW_M := 20.0

static var _ai := {}
static var _bend_cast: Script = null
static var _bend_cast_checked := false

var brain: NpcBrain
var me: NpcFighter
var caster: NpcBendCaster
## Its element (Bending.ELEMENTS).
var element := "earth"
## Every option: {id, mode, key "id/mode", spec, do, hint, water, knock, old, grow (its spec grows), guard (its element's
## guard), jab}.
var options: Array[Dictionary] = []
## The lock: the move locking ("" none), its mode, whether it is held to grow, how full (0..1), its time and how long it has
## filled.
var casting := ""
var mode := ""
var grown := false
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
var grows_by := {}
var hits := 0
var catches := 0
var clean_catches := 0
var answered := 0
var perfects := 0
var lates := 0
var whiffs := 0
var returns := 0
var lost := 0
var lost_why := ""
var setbacks := 0
var reactions_by := {}
## Floor threats seen coming at it (once each), those it jumped, and every jump.
var floor_seen := 0
var floor_jumped := 0
var jumps := 0
## The most times a stone it sent back had been sent back (RETURNS_META).
var longest_rally := 0
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
## Per foe (its instance id): the first sight of its volley and its roll ([time, answered]).
var _volleys := {}
var _alt := false
## The opening grace: no attack begun before this (BendStatus clock); whether it was held at its last tick.
var _grace_until := 0.0
var _was_held := false
## Its catches seen so far (a new one answered by its guard again: the return).
var _catches_seen := 0
## Floor threats seen (id -> [first seen, jump rolled]); the last setback's time.
var _floor := {}
var _setback_t := -100.0
## The way each dash whose way is the keys held goes ("move/mode" -> "side", "back", "forward": _pick_way).
var _ways := {}
## The side each such dash checked for room goes to ("move/mode" -> -1 left, 1 right of the way to the foe: _pick_way), so
## the dash goes the side that was found safe.
var _sides := {}
## A guard waits for its beat until then: no other lock begun meanwhile (it would hold the guard off).
var _beat_wait_until := -1.0
## What came at it this physics frame (_threats, looked at once a frame).
var _threats_frame := -1
var _threats_last: Array = []
## No new guard begun before this (bend_ai.json guard_cool_s after any guard: one guard after another, of whatever kind,
## would turtle; the moves' own cools are per option).
var _guard_until := 0.0
## Round 3 (the % ring only): its mind (mind()), made the first time the gate is on.
var ring_mind: NpcRingMind = null
## Round 3 Practice: the dummy's way (RingPractice through set_practice_way; "" none).
var practice_way := ""
var _pad: NpcPad = null
var _held_seen := false
## Round 4: the lock under way has been in the air (its landing: the Slam called off, the air hit back into the jab).
var _air_seen := false


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
	caster.guarded.connect(_on_guarded)
	_build_options()
	if me.is_inside_tree():
		Bending.of(me).element = element
	_grace_until = _now() + float(pr.get("grace_s", 0.0))


# ---------------------------------------------------------------- round 3: the gate, the mind, the pad
## THE GATE (round 3): a stock-rules ring is installed (RingRules.stock_on()).
static func stock() -> bool:
	return RingRules.stock_on()


## Its % ring mind (made the first time it is asked for: only ever under the gate).
func mind() -> NpcRingMind:
	if ring_mind == null:
		ring_mind = NpcRingMind.new(self)
	return ring_mind


## Its pad: NpcFighter.pad when its body has one (MOVE's; one made and given to it when empty), else its own.
func pad() -> NpcPad:
	var have: Variant = me.get(&"pad")
	if have is NpcPad:
		return have
	if _pad == null:
		_pad = NpcPad.new()
	if &"pad" in me:
		me.set(&"pad", _pad)
	return _pad


## Practice's dummy way (RingPractice.set_way): "stand", "walk", "jump", "block", "guard_held", "guard_after", "recover",
## "throw", "fight" (its mind left to its preset only in "fight").
func set_practice_way(way: String) -> void:
	practice_way = way
	if ring_mind != null or stock():
		mind().practice_dummy = way != "fight" and way != ""


## The lock option `o` would take now at `t` (begin's reckoning, with no roll: a move that may grow counted ungrown).
func lock_of(o: Dictionary, t: Node3D) -> float:
	var id := String(o.id)
	var md := String(o.mode)
	var ls := lock_for(id, md, _preset_name(), _cast_dist(id, md, t), me)
	if bool(o.get("guard", false)):
		if _held_stone() != null:
			ls = BendZone.guard_lock_s(me, ls) * float(preset().get("lock_mult", 1.0))
		else:
			ls = _guard_lock(ls)
	return _stock_lock(o, ls) if stock() else ls


## Round 3's lock rules for a bot's option: the jab step (the next jab ready jab_step_s after the last left the hand once it
## hit), key 3 no sooner than key3_min_s.
func _stock_lock(o: Dictionary, ls: float) -> float:
	if bool(o.get("jab", false)):
		return mind().jab_lock(ls)
	if Bending.key_of(element, String(o.get("id", ""))) == 2:
		return maxf(ls, NpcRingMind.pnum("key3_min_s", 0.22))
	return ls


## A jump now: in the % ring a press of the pad's Space (the player's own jump), else round 2's (NpcFighter.jump).
func _jump_now() -> bool:
	if stock():
		if not me.is_on_floor():
			return false
		pad().press("jump")
		return true
	return me.jump(float(ai().get("jump_mps", 6.5)))


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


## Every (move, mode) of `el`'s kit: its keys (Bending.keys: 1-5, Patch and Mend with them), its guard and its jab.
static func pairs_of(el: String) -> Array:
	var out: Array = []
	for pair in Bending.keys(el):
		for id: String in pair:
			var ms := SwayCaster.modes_of(id)
			if ms.is_empty():
				out.append([id, ""])
			for md: String in ms:
				out.append([id, md])
	for extra: Array in [guard_of(el), jab_of(el)]:
		if extra.size() >= 2 and not extra in out:
			out.append(extra)
	return out


## Element `el`'s guard on E ([move, variation]: Bending.guard, the player's own; [] none).
static func guard_of(el: String) -> Array:
	var g := Bending.guard(el)
	return [String(g.id), String(g.mode)] if not g.is_empty() else []


## Element `el`'s jab on the left button ([move, variation]: Bending.jab, the player's own; [] none).
static func jab_of(el: String) -> Array:
	var j := Bending.jab(el)
	return [String(j.id), String(j.mode)] if not j.is_empty() else []


## A shared rule's number (Bending.rule: moves.json guard_rules over the caster's defaults, the player's own).
static func rule(k: String) -> float:
	return Bending.rule(k)


func _build_options() -> void:
	options.clear()
	var gd := guard_of(element)
	var jb := jab_of(element)
	for pr: Array in pairs_of(element):
		var id := String(pr[0])
		var md := String(pr[1])
		var spec := spec_of(id, md)
		var o := {"id": id, "mode": md, "key": id + "/" + md, "spec": spec, "old": spec.is_empty(),
				"do": String(spec.get("do", "old")),
				"knock": float(spec.get("knock_mps", 0.0)), "grow": spec.get("grow") is Dictionary \
						or (stock() and (SwayMoves.move(id).get("grow", {}) as Dictionary).get(md) is Dictionary),
				"guard": pr == gd, "jab": pr == jb}
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
static func lock_for(id: String, md: String, preset_name := "hard", dist := 0.0, who: Node = null) -> float:
	var d := SwayMoves.move(id)
	var base := float(d.get("lock_s", 1.0))
	var mlk: Dictionary = d.get("mode_lock_s", {})
	if id == "gust" and md == "lift":
		base = float((d.get("stone", {}) as Dictionary).get("lock_s", base))
	else:
		if mlk.has(md):
			base = float(mlk[md])
		base = BendLoadout.lock(who, id, md, base)         # (`who` wears a loadout live: its own lock for this mode; else base)
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
	if ring_mind != null:
		ring_mind._end_string()
		ring_mind.plan = {}


## Whether its opening grace still runs (no attack, no control begun).
func in_grace() -> bool:
	return _now() < _grace_until


func think(dt: float) -> void:
	if me.held or me.is_dead():
		return
	var t := brain.target
	if not NpcSenses.can_fight(t):
		return
	if stock() and mind().think(dt):
		return                                     # (round 3: every state but NEUTRAL and PRESSURE is the mind's)
	if casting != "" or _follow > 0.0 or me.busy():
		return
	if stock() and (not mind().hop.is_empty() or not mind().shield.is_empty()):
		return                                     # (round 4: a hop under way is its mind's (air_tick); a shield held stands)
	var d := _flat_d(t)
	if _now() < _beat_wait_until and not _forced_any():
		# (a guard waits for its beat: it stands its ground, facing him, and begins nothing else)
		me.halt()
		me.face_point(t.global_position)
		return
	if _now() >= _rest_until or _forced_any():
		if stock() and not _forced_any() and mind().hop_think(t, d):
			return                                 # (round 4: a hop at him, its air form begun in the air)
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
	var owned := false
	if stock():
		owned = mind().tick(dt)                    # (round 3: the state, the pad; REELING, RECOVER, LEDGE, RESPAWN its own)
		_stone_from_pop()
	if edge_fn.is_valid() and not me.on_deck:
		me.on_deck = true
	_watch()
	_edge_brake()
	if brain.state == NpcBrain.State.COMBAT and not owned:
		_jump_floor()                              # (mid-lock too: the jump never gates a lock, the player's Space)
	if casting != "" and stock():
		if mind().stunned() and casting == "fire_arc" and mode == "lightning":
			_lose("hit")                           # (lightning's charge breaks in hitstun)
			return
		if (owned and not mind().lock_runs()) or mind().stunned():
			return                                 # (the lock waits, frozen, and goes on from the same fill)
		if not me.is_on_floor():
			_air_seen = true
		elif mode in ["slam", "air_hit"] and (_air_seen or lock_t > 0.15):
			_landed_form()                         # (round 4: landed before the release, the player's rule)
			if casting == "":
				return
	if casting != "":
		if me.action == "flinch":
			return                                 # (staggered: the lock waits; a hit pushes it back, never wipes it)
		if me.action != "cast":
			if me.action in ["", "knocked"]:
				# (back from a stagger: the cast pose again for what is left of the lock)
				me.action = "cast"
				if me.body != null:
					me.body.play_cast(casting, mode, maxf(lock_s - lock_t, 0.1), element, grown)
			else:
				_lose("flinch")
				return
		if fill < SWITCH_FILL and not is_guard(_option(casting + "/" + mode).get("hint", {})):
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
			if stock():
				# (round 3: never a hit into a safety; a lock held full for its moment, called off past hold_max_s)
				var go := mind().allow_release(_option(casting + "/" + mode), dt)
				if go < 0:
					_cancel()
					return
				if go == 0:
					return
			_release()
		return
	if _follow > 0.0:
		_follow -= dt
		if _follow <= 0.0 and me.action == "cast":
			me.action = ""
	if brain.state == NpcBrain.State.COMBAT and (me.action in ["", "knocked"] or _follow > 0.0) and not owned:
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
	if ring_mind != null and stock():
		return ring_mind.form_option(key)          # (round 4: the air forms: the air close hit, the Slam)
	return {}


## Whether option `o` can be cast now: off its cool, an old spell only through BendCast (or its own way).
func castable(o: Dictionary) -> bool:
	if _now() < float(_cool.get(String(o.key), 0.0)):
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
		if String(o.spec.get("held_stone", "")) == "throw" and _held_stone() != null:
			band = Vector2(0.0, HELD_THROW_M)      # (a caught stone in its hands: this key throws it, as far as a throw goes)
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
		if stock() and not mind().allowed(o, t):
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
		if not cb.is_empty() and String(cb.get("after", "")) == _last_key and _now() - _last_t < 2.5 and not stock():
			w *= float(cb.get("bonus", 2.0))        # (round 3: the string table's true strings instead, NpcRingMind)
		if stock():
			w *= mind().weight(o, t, d)
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
			return _own_wall(true, 6.0) != null          # (within Mend's reach of its cast point, _cast_point)
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
		"foe_grounded":
			return not (t is CharacterBody3D) or (t as CharacterBody3D).is_on_floor()
		"foe_up_or_walled":
			return (t is CharacterBody3D and not (t as CharacterBody3D).is_on_floor()) or _wall_on_line(t)
		"holding":
			return _held_stone() != null
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
## The guard to begin now against what comes at it ({id, mode, kind} or {}): a threat seen for the preset's reaction (its
## own guard on E for its guard_reaction_s: a reflex; x2 dazzled), answered at the preset's chance (one roll a volley: VOLLEY_S), its guard begun when its lock leaves the hit
## where the roll put it in the guard's window (on_beat): in its first perfect_s at the preset's perfect_chance, else later
## in it; an answer that is no guard of its own (a dash out of the line) as soon as its lock fits. Kind "floor" is jumped
## instead (_jump_floor), kind "lightning" dashed from on the flash by a preset with lightning_dash.
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
	var dz := 2.0 if NpcBendCaster.dazzled(me) else 1.0
	var react := float(pr.get("reaction_s", 0.45)) * dz
	# (its own guard on E is a reflex on his wind-up: guard_reaction_s, quicker than a dash's reaction_s)
	var react_g := float(pr.get("guard_reaction_s", pr.get("reaction_s", 0.45))) * dz
	if stock():
		# (round 3: high on its own %, a little slower to answer: high_react_s)
		react += mind().reaction_add()
		react_g += mind().reaction_add()
	var now := _now()
	if stock():
		if not mind().shield.is_empty():
			return {}                              # (the shield up: held, nothing else begun)
		var sh := _shield_pick(threats, pr, now, react_g)
		if not sh.is_empty():
			return sh                              # (round 4: its guard raised early, to be held as a shield)
	var best: Dictionary = {}
	# (round 5, the % ring: every guard stops every attack (spec v2 §2.5), so its own guard on E answers each kind of
	# bend_ai.json pct.guard_kinds, not only its element's round-2 answers: a guard that took only its own kinds left earth
	# open to every fire, water and air shot and fire to every Lash and Wave, as no player is)
	var guard_kinds: Array = (ai().get("pct", {}) as Dictionary).get("guard_kinds", []) if stock() else []
	for th: Dictionary in threats:
		var seen := _seen(th, pr, now)
		if not bool(seen[1]) or now - float(seen[0]) < minf(react, react_g):
			continue
		var tti := float(th.tti)
		var kind := String(th.kind)
		for o: Dictionary in options:
			var h: Dictionary = o.hint
			var answers: Array = h.get("answers", [])
			var ok := is_guard(h) and (kind in answers or String(th.get("as", "")) in answers)
			if not ok and bool(o.guard) and stock() and kind in guard_kinds:
				ok = true                            # (round 5: the % ring's guard stops every attack, its own kinds or not)
			if not ok and kind == "lightning" and String(o.do) == "dash" and bool(pr.get("lightning_dash", false)):
				ok = true                            # (a hard bot dashes on the flash: spec 2.3, lightning's flash_s)
			if not ok or not castable(o) or (kind == "lightning" and bool(o.guard) and not bool(seen[2])):
				continue                             # (lightning goes back only off a parry on the beat: else it hits)
			if now - float(seen[0]) < (react_g if bool(o.guard) else react):
				continue
			if bool(th.get("floor", false)) and not bool(o.guard) and not "floor" in answers:
				continue                             # (along the deck: jumped (_jump_floor), or a guard; a side step is no answer)
			if float(th.get("knock", INF)) < float(h.get("min_knock", 0.0)) or not _guard_fits(o, t):
				continue
			var ls := lock_for(String(o.id), String(o.mode), _preset_name(), 0.0, me)
			if bool(o.guard):
				ls = _guard_lock(ls)
			if ls > tti:
				continue
			var window := float(o.spec.get("window_s", o.spec.get("life_s", o.spec.get("s", 1.0))))
			if String(h.get("role", "")) == "reaction" or bool(o.guard):
				# (a guard: begun so the hit lands at its beat: early in the window on a perfect roll, later on a late one)
				var at := on_beat(window, bool(seen[2]))
				if tti - ls > at + 0.05 or tti - ls > window * 0.9:
					# (too soon: it waits for the beat, and begins nothing else meanwhile: _choose holds off)
					_beat_wait_until = maxf(_beat_wait_until, now + minf(tti - ls - at, 1.0))
					continue
			elif kind == "under" and th.has("rise") and stock():
				# (round 5: what rises under it rises where he aims as he lets go, so a step off begun early is followed
				# by his aim: it begins only as his lock ends, its step taken in the rise)
				if tti - float(th.rise) > ls * 0.8:
					continue
			elif ls + window * 0.8 < tti:
				continue
			if best.is_empty() or ls < float(best.ls):
				best = {"id": o.id, "mode": o.mode, "kind": kind, "ls": ls}
	if _threat_seen.size() > 64:
		_threat_seen.clear()
		_volleys.clear()
	return best


## Round 4 (the % ring): its own guard on E begun as a shield ({id, mode, kind "shield", ls} or {}) against a threat its mind
## holds one against (NpcRingMind.shield_wanted: a held Lightning, a big shot), seen for its guard reaction and rolled once
## (shield_roll), unless its guard meets it on the beat anyway (rolled perfect, an answer of its own; lightning only fire's):
## begun so it stands shield_lead_s before the strike, standing its ground until then; no stone in hand (E would throw it).
func _shield_pick(threats: Array, pr: Dictionary, now: float, react_g: float) -> Dictionary:
	var m := mind()
	var g := guard_of(element)
	if not m.shield.is_empty() or g.is_empty() or _held_stone() != null or m.state in [NpcRingMind.S.RESPAWN, NpcRingMind.S.LEDGE]:
		return {}
	var o := _option("%s/%s" % g)
	if o.is_empty() or not castable(o):
		return {}
	var answers: Array = (o.hint as Dictionary).get("answers", [])
	for th: Dictionary in threats:
		if not m.shield_wanted(th):
			continue
		var seen := _seen(th, pr, now)
		if now - float(seen[0]) < react_g:
			continue
		var kind := String(th.kind)
		if bool(seen[1]) and bool(seen[2]) and (kind in answers or String(th.get("as", "")) in answers) \
				and (kind != "lightning" or element == "fire"):
			continue                               # (on the beat its own guard's round-2 timing is the better answer)
		if not m.shield_roll(int(th.id)):
			continue
		var ls := _guard_lock(lock_for(String(g[0]), String(g[1]), _preset_name(), 0.0, me))
		var tti := float(th.tti)
		if ls > tti:
			continue
		var lead := m.shield_lead()
		if tti - ls > lead:
			if tti - ls - lead < 0.6:
				_beat_wait_until = maxf(_beat_wait_until, now + tti - ls - lead)
			continue
		m.raise_shield(th)
		return {"id": g[0], "mode": g[1], "kind": "shield", "ls": ls}
	return {}


## Threat `th`'s roll ([first seen, answered at all, on the beat]): one a volley of light bolts (VOLLEY_S), else its own.
func _seen(th: Dictionary, pr: Dictionary, now: float) -> Array:
	var id := int(th.id)
	if not _threat_seen.has(id):
		var src := int(th.get("src", 0))
		var vl: Array = _volleys.get(src, [])
		if src != 0 and not vl.is_empty() and now - float(vl[0]) < VOLLEY_S:
			_threat_seen[id] = vl.duplicate()
		else:
			var el_react := float(((ai().get("elements", {}) as Dictionary).get(element, {}) as Dictionary).get("react", 1.0))
			_threat_seen[id] = [now, me.rng.randf() < float(pr.get("react_chance", 0.5)) * el_react,
					me.rng.randf() < float(pr.get("perfect_chance", 0.3))]
			if src != 0:
				_volleys[src] = _threat_seen[id]
	return _threat_seen[id]


## Where in a guard's window (s from its standing) a bot aims the hit: a perfect one in the middle of the first
## guard_rules.perfect_s, a late one past it (a third of the way through the rest).
static func on_beat(window: float, perfect: bool) -> float:
	var ps := rule("perfect_s")
	if perfect:
		return ps * 0.5
	return ps + maxf(window - ps, 0.0) * 0.35


## Each frame: a wave along the deck coming at it (a threat with "floor": the Kick's, a rolling Boulder) jumped, once seen
## for the preset's reaction and rolled at its jump_chance once a wave: the takeoff when the wave is jump_lead_s from its
## feet (bend_ai.json; at jump_mps its feet are over the wave's miss_above_m from about 0.1 s to 0.6 s after it).
func _jump_floor() -> void:
	var d_ai := ai()
	var pr := preset()
	var now := _now()
	var lead := float(d_ai.get("jump_lead_s", 0.3))
	for th: Dictionary in _threats():
		if not bool(th.get("floor", false)):
			continue
		var id := int(th.id)
		if not _floor.has(id):
			floor_seen += 1
			_floor[id] = [now, me.rng.randf() < float(pr.get("jump_chance", 0.5)), false]
		var e: Array = _floor[id]
		if not bool(e[1]) or bool(e[2]) or now - float(e[0]) < float(pr.get("reaction_s", 0.4)):
			continue
		var tti := float(th.tti)
		if tti <= lead and tti > 0.08 and _jump_now():
			e[2] = true
			floor_jumped += 1
			jumps += 1
	if _floor.size() > 64:
		_floor.clear()


## Round 3: a stone in hand that no catch gave (earth's Pop leaves one: spec §6.4) thrown with E as a catch's would be
## (_answer_catch), once each time one is held.
func _stone_from_pop() -> void:
	var held := element == "earth" and _held_stone() != null
	if held and not _held_seen:
		_answer_catch()
	_held_seen = held


## The stone it holds (caught: BendZone.held_stone, the player's own reckoning), null none.
func _held_stone() -> Node3D:
	return BendZone.held_stone(me)


## Whether a wall stands between it and `t` (anyone's raised earth or ice, or a fire or wind wall, within 1.2 m of the line
## between their chests): the High Kick's arc clears it.
func _wall_on_line(t: Node3D) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	var a := me.global_position + Vector3.UP
	var b := t.global_position + Vector3.UP
	for w in me.get_tree().get_nodes_in_group(FormRaised.GROUP):
		var fr := w as FormRaised
		if fr != null and fr.is_up() and fr.kind == "wall":
			var q := fr.global_position + Vector3.UP
			if q.distance_to(Geometry3D.get_closest_point_to_segment(q, a, b)) < 1.2 + fr.size.x * 0.5:
				return true
	for z in me.get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.kind in ["fire_wall", "wind_wall", "water_wall"]:
			var q2 := bz.global_position + Vector3.UP
			if q2.distance_to(Geometry3D.get_closest_point_to_segment(q2, a, b)) < 1.2 + bz.size.x * 0.5:
				return true
	return false


## A guard's lock `ls` with the whiff rule: within whiff_s of a guard that took nothing, whiff_lock_s at least (BendZone's
## own reckoning, the player's: meta bend_whiff_until).
func _guard_lock(ls: float) -> float:
	if BendStatus.until(me, &"bend_whiff_until") > 0.0:
		return maxf(ls, rule("whiff_lock_s"))
	return ls


## Whether hint `h` is a guard's: a reaction's, or any option's that answers something (Earth Grip's anchor; a dodge). Only a
## reaction's starts the guard cool (guard_cool_s).
static func is_guard(h: Variant) -> bool:
	return h is Dictionary and (String((h as Dictionary).get("role", "")) == "reaction" or (h as Dictionary).has("answers"))


## Whether guard `o` may be begun now: its hint's guard_when (bend_ai.json's when) held, a dash with room for it.
func _guard_fits(o: Dictionary, t: Node3D) -> bool:
	var h: Dictionary = o.hint
	for c: String in h.get("guard_when", []):
		if not _when(c, t, _flat_d(t)):
			return false
	if String(o.do) == "dash" and not _dash_safe(o, t):
		return false
	return true


## Whether its last look at what comes at it (this frame's or the frame before's _threats) saw anything: read from that look,
## never a new one (a new look reads wind-ups with its dice).
func _recent_threats() -> bool:
	return Engine.get_physics_frames() - _threats_frame <= 2 and not _threats_last.is_empty()


## What comes at it now: [{id, kind, tti, knock, src}] (BendBolt and a bot's spike by their flight; a hurled GustLift stone; a
## tornado coming at it, kind "vortex"; a stone held up and aimed at it, kind "held"; the foe's lightning by his lock's fill;
## his wind-up). knock: the move's knock_mps; src: a light bolt's sender (its instance id: its volley, VOLLEY_S), else none.
func _threats() -> Array:
	var frame := Engine.get_physics_frames()
	if frame == _threats_frame:
		return _threats_last                       # (the guard's look and the jump's in one frame: one look)
	var out: Array = []
	_threats_frame = frame
	_threats_last = out
	var tree := me.get_tree()
	var c := NpcSenses.chest_of(me)
	for b in tree.get_nodes_in_group(BendBolt.GROUP):
		var bb := b as BendBolt
		if bb == null or bb.spent or bb.caster == me:
			continue
		if is_floor_bolt(bb):
			# (a wave along the deck: wide, low; it comes at its feet, whatever its height to the chest)
			var wide := maxf(float(bb.get(&"width_m")) if bb.get(&"width_m") != null else bb.radius * 2.0, 0.6)
			var ttf := _closing_flat(bb.global_position, bb.velocity, me.global_position, wide * 0.5 + 0.45)
			if ttf >= 0.0:
				out.append({"id": bb.get_instance_id(), "kind": bb.kind, "tti": ttf, "knock": bb.knock_mps, "floor": true})
			continue
		var tti := _closing(bb.global_position, bb.velocity, c)
		if tti >= 0.0:
			out.append({"id": bb.get_instance_id(), "kind": bb.kind, "tti": tti, "knock": bb.knock_mps,
					"src": _src(bb.caster) if bb.kind != "stone" else 0, "as": _as_of(bb.kind, bb.shape)})
	for s in tree.get_nodes_in_group(FormStone.GROUP):
		# (a boulder rolling along the deck at it: kind "floor", jumped)
		var rb := s as RigidBody3D
		if rb == null or rb.freeze or rb.linear_velocity.length() < ROLL_MPS or rb.global_position.y - me.global_position.y > FLOOR_M:
			continue
		var ttr := _closing_flat(rb.global_position, rb.linear_velocity, me.global_position, 0.75)
		if ttr >= 0.0:
			out.append({"id": rb.get_instance_id(), "kind": "floor", "tti": ttr, "knock": 6.0, "floor": true})
	for f in tree.get_nodes_in_group(FLIGHT_GROUP):
		var fl := f as Flight
		if fl == null or fl.shooter == me or fl.stone == null or not is_instance_valid(fl.stone):
			continue
		var tti2 := _closing(fl.stone.global_position, fl.velocity, c)
		if tti2 >= 0.0:
			out.append({"id": fl.get_instance_id(), "kind": "stone", "tti": tti2, "knock": 4.0})
	for g in tree.get_nodes_in_group(GustLift.GROUP):
		var st: Variant = g.get(&"stone")
		var v: Variant = g.get(&"velocity")
		if not (st is Node3D) or not is_instance_valid(st) or not (v is Vector3) or _caster_body(g.get(&"caster")) == me:
			continue
		if (g as GustLift).phase == GustLift.Phase.HELD:
			# (a stone held up and aimed at it, kind "held": its hurl is the hold's rest away (a bot's Hurl), then the flight)
			var ga := (g as GustLift).aim
			if ga != Vector3.INF and ga.distance_to(c) < THREAT_MISS_M + 0.6:
				out.append({"id": (g as Object).get_instance_id() + 1, "kind": "held",
						"knock": 8.0 if g.get(&"kind") == "cannonball" else 5.0,
						"tti": _hold_left(g as GustLift) + (st as Node3D).global_position.distance_to(c) / HELD_MPS})
			continue
		if (v as Vector3).length() < 3.0:
			continue
		var tti3 := _closing((st as Node3D).global_position, v as Vector3, c)
		if tti3 >= 0.0:
			var hk: Variant = g.get(&"kind")
			out.append({"id": (g as Object).get_instance_id(), "kind": "stone", "tti": tti3, "knock": 8.0 if hk == "cannonball" else 5.0})
	for z in tree.get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz == null or bz.kind != "tornado" or bz.owner_node == me or bz.speed < 0.5 or bz.is_queued_for_deletion():
			continue
		# (a tornado's knock is its pace's, each beat it holds a man: BendZone._every)
		var tti4 := _closing(bz.global_position + Vector3.UP, bz.way * bz.speed, c)
		if tti4 >= 0.0:
			out.append({"id": bz.get_instance_id(), "kind": "vortex", "tti": tti4, "knock": bz.speed * 1.2})
	var t := brain.target
	if t != null and is_instance_valid(t):
		var sc := SwayCaster.of(t) if t is FrontierPlayer else null
		if sc != null and sc.state != SwayCaster.State.IDLE and sc.move == "fire_arc" and sc.mode_of("fire_arc") == "lightning":
			# (round 4, the % ring: one threat a charge, so each Lightning is rolled afresh; else round 2's one id)
			var lid := hash([sc.get_instance_id(), int(sc.lock_began_at * 10.0)]) if stock() else sc.get_instance_id()
			out.append({"id": lid, "kind": "lightning", "tti": maxf((1.0 - sc.fill) * sc.lock_s, 0.0) + flash_s(),
					"knock": 6.0})
		elif sc != null and sc.state != SwayCaster.State.IDLE and sc.move != "":
			# (his wind-up read: a throw or a bolt he is locking, its stone or its element on its way when he lets go)
			var md := sc.mode_of(sc.move)
			var shot := shot_of(sc.move, md, sc.grown)
			if not shot.is_empty() and _in_reach(shot, t):
				var left := maxf((1.0 - sc.fill) * sc.lock_s, 0.0)
				# (one read a lock: a grown lock held full keeps its id, so a bot can watch it long enough to answer it)
				var began := int(sc.lock_began_at * 10.0) if sc.grown else int((_now() - sc.fill * sc.lock_s) * 10.0)
				out.append(_read(shot, hash([sc.get_instance_id(), sc.move, md, began]), left + READ_STRIKE_S, c, t))
		elif t is NpcFighter and (t as NpcFighter).brain != null and (t as NpcFighter).brain.bending != null:
			var ob := (t as NpcFighter).brain.bending
			if ob.casting == "fire_arc" and ob.mode == "lightning":
				var lid2 := hash([ob.get_instance_id(), int(ob._lock_at * 100.0)]) if stock() else ob.get_instance_id()
				out.append({"id": lid2, "kind": "lightning", "tti": maxf(ob.lock_s - ob.lock_t, 0.0) + flash_s(),
						"knock": 6.0})
			elif ob.casting != "":
				var shot2 := shot_of(ob.casting, ob.mode, ob.grown)
				if not shot2.is_empty() and _in_reach(shot2, t):
					out.append(_read(shot2, hash([ob.get_instance_id(), ob.casting, ob.mode, int(ob._lock_at * 100.0)]),
							maxf(ob.lock_s - ob.lock_t, 0.0), c, t))
	return out


## Whether a read shot reaches it from `t` (a cone's reach + CONE_SLACK_M; any other shot always).
func _in_reach(shot: Dictionary, t: Node3D) -> bool:
	if not shot.has("reach") or t == null or not is_instance_valid(t):
		return true
	return _flat_d(t) <= float(shot.reach) + CONE_SLACK_M


## Lightning's strike after its release (s): its flash (spec flash_s, round 2: a dash on the flash dodges it), a frame's
## more.
static func flash_s() -> float:
	return float(spec_of("fire_arc", "lightning").get("flash_s", 0.0)) + 0.05


## A wind-up read as a threat: shot `shot` (shot_of) leaving `left` s from now from `t` at chest `c`: {id, kind, knock, tti},
## for a wave along the deck its time to its feet ("read": the jump waits for the wave), "under" (kind) for what rises under
## it (its rise_s on).
func _read(shot: Dictionary, id: int, left: float, c: Vector3, t: Node3D) -> Dictionary:
	var th := {"id": id, "kind": shot.kind, "knock": shot.knock, "as": _as_of(String(shot.kind), String(shot.get("shape", "")))}
	if String(shot.kind) == "under":
		th["tti"] = left + float(shot.get("rise_s", 0.35))
		th["rise"] = float(shot.get("rise_s", 0.35))
	elif bool(shot.get("floor", false)):
		th["tti"] = left + me.global_position.distance_to(t.global_position) / float(shot.mps)
		th["read"] = true                          # (a guard may answer it; the jump waits for the wave itself)
	else:
		th["tti"] = left + c.distance_to(NpcSenses.chest_of(t)) / float(shot.mps)
	return th


## A threat's "as" (its own name past its kind; "" none): an air bolt of shape spear is the Air Lance ("air_spear"), which
## water's Turn answers (bend_ai.json zones.redirect answers); its kind stays "air" for every other reader.
static func _as_of(kind: String, shape: String) -> String:
	return "air_spear" if kind == "air" and shape == "spear" else ""


## What (id, md) sends flying at whom it is cast at: {kind, mps, knock, shape} (a bolt's or a throw's spec; Stone Form's spike
## and boulder and Earth Shove a stone; Gust lift a stone), {} for anything else (the wind-up a bot reads: _threats).
## `grown`: the lock grows (held past its second click); only the Air Lance's grow is read (the Gust held long is a spear of
## air, another thing to answer), every other grow read as the move itself as before.
static func shot_of(id: String, md: String, grown := false) -> Dictionary:
	var spec := spec_of(id, md)
	if grown:
		var g: Variant = spec.get("grow")
		if g is Dictionary and _as_of(String((g as Dictionary).get("kind", "")), String((g as Dictionary).get("shape", ""))) != "":
			spec = spec.duplicate()
			spec.merge(g as Dictionary, true)
	var dn := String(spec.get("do", ""))
	if dn in ["bolt", "throw", "wind_wave"]:
		return {"kind": String(spec.get("kind", "stone")), "mps": maxf(float(spec.get("mps", 30.0)), 5.0),
				"knock": float(spec.get("knock_mps", 0.0)), "shape": String(spec.get("shape", ""))}
	if dn == "floor_wave":
		return {"kind": String(spec.get("kind", "fire")), "mps": maxf(float(spec.get("mps", 18.0)), 5.0),
				"knock": float(spec.get("knock_mps", 0.0)), "floor": true}
	if dn in ["column", "spout"]:
		return {"kind": "under", "mps": 1.0, "knock": float(spec.get("up_mps", 10.0)), "rise_s": float(spec.get("rise_s", 0.35))}
	if dn == "cone" and stock():
		# (round 5: a cone (the Wave, Breath, Palm) strikes as he lets go, all of it within its reach: his wind-up is read as
		# a threat only within reach, so it is guarded as the player guards it; round 4's bots never saw a Wave coming)
		return {"kind": String(spec.get("kind", "air")), "mps": CONE_MPS, "knock": float(spec.get("knock_mps", 0.0)),
				"reach": float(spec.get("range_m", 4.0))}
	if dn == "shove":
		var rd: Dictionary = SwayMoves.move("gust").get("raised", {})
		return {"kind": "stone", "mps": float(rd.get("mps", 26.0)), "knock": float(rd.get("knock_mps", 5.0))}
	if spec.is_empty() and id == "stone_form":
		var hurl: Dictionary = ((SwayMoves.move("stone_form").get("throw", {}) as Dictionary).get("hurl", {}) as Dictionary).get(md if md != "" else "spike", {})
		var mps: Variant = hurl.get("mps", [30.0])
		var kn: Dictionary = (SwayMoves.move("stone_form").get("throw", {}) as Dictionary).get("knock_mps", {})
		return {"kind": "stone", "mps": maxf(float(mps[mps.size() - 1]) if mps is Array else float(mps), 5.0),
				"knock": float(kn.get(md if md != "" else "spike", 4.0))}
	if spec.is_empty() and id == "gust" and md == "lift":
		return {"kind": "stone", "mps": 24.0, "knock": 5.0}
	return {}


## Whether bolt `bb` runs along the deck (a floor wave, the Kick's: its own floor or floor_wave flag, a low bolt).
static func is_floor_bolt(bb: BendBolt) -> bool:
	return bb.low or bb.get(&"floor") == true or bb.get(&"floor_wave") == true


## Seconds until something at `p` going `v` (flat) passes over `at` (flat) within `r`, within 3 s (else -1).
static func _closing_flat(p: Vector3, v: Vector3, at: Vector3, r: float) -> float:
	var vf := Vector3(v.x, 0.0, v.z)
	var rel := Vector3(p.x - at.x, 0.0, p.z - at.z)
	var vv := vf.length_squared()
	if vv < 1.0:
		return -1.0
	var ts := -rel.dot(vf) / vv
	if ts <= 0.0 or ts > 3.0:
		return -1.0
	return ts if (rel + vf * ts).length() <= r else -1.0


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


## How long until held stone `g` is hurled (s): a bot's Hurl (BendCast's, group bend_hurls) its hold's rest, else HELD_LEFT_S.
func _hold_left(g: GustLift) -> float:
	for h in me.get_tree().get_nodes_in_group(&"bend_hurls"):
		if h.get(&"lift") == g:
			return maxf(float(h.get(&"hold_s")) - float(h.get(&"t")), 0.0)
	return HELD_LEFT_S


## `n`'s instance id (0: none, or gone).
static func _src(n: Variant) -> int:
	return (n as Object).get_instance_id() if is_instance_valid(n) and n is Object else 0


static func _caster_body(c: Variant) -> Node:
	if c == null or not (c is Object) or not is_instance_valid(c):
		return null
	for k: StringName in [&"body", &"player"]:
		var b: Variant = (c as Object).get(k)
		if is_instance_valid(b) and b is Node:     # (a body freed under its caster: none)
			return b
	return c as Node if c is Node else null


# ---------------------------------------------------------------- the lock and the release
## The lock of (id, md) begun (its time: lock_for; its pose; its circle).
func begin(id: String, md: String) -> void:
	if casting != "":
		_cancel()
	var t := brain.target
	if stock() and Bending.key_of(element, id) == 2 and not me.is_on_floor():
		# (round 3: 3 in the air is the air dodge, at once, out of the threat's line)
		pad().dodge_dir = -_way(t).cross(Vector3.UP) * _pick_side(t)
		pad().press("dodge")
		return
	_air_seen = false
	if stock():
		if not me.is_on_floor():
			md = mind().air_form(id, md)           # (round 4: the player's air forms, decided as the lock starts)
			_air_seen = true
		var gd := guard_of(element)
		if ring_mind != null and not (gd.size() >= 2 and id == String(gd[0])):
			ring_mind.drop_shield()                # (any other lock drops the held guard)
	casting = id
	mode = md
	lock_t = 0.0
	fill = 0.0
	lock_s = lock_for(id, md, _preset_name(), _cast_dist(id, md, t), me)
	_lock_at = _now()
	var o := _option(id + "/" + md)
	grown = false
	if bool(o.get("grow", false)) and not me.held and not (id == "stone_form" and (_recent_threats() or _held_stone() != null)):
		# (held past the second click: it grows; its element's grow_chance, a move's own "grow" over it. Never a held one's:
		# Practice's dummy throws the same plain move every time, for its guards to be learnt. A Spike or a Boulder grows only
		# with nothing coming at it and no caught stone in its hands: a grown stone's longer lock is no time to be caught out)
		var el_ai: Dictionary = (ai().get("elements", {}) as Dictionary).get(element, {})
		var gc := float((o.hint as Dictionary).get("grow", el_ai.get("grow", 0.35)))
		if id == "stone_form":
			# (the Spike's and Boulder's grow, 2026-10-10: its own roll from its dice's seed and its casts so far, the bot's
			# dice left untouched: every other choice it makes the same as before stones grew)
			grown = float(absi(hash(Vector2i(me.rng_seed, casts + 7))) % 10000) / 10000.0 < gc
		else:
			grown = me.rng.randf() < gc
		if grown:
			lock_s += rule("grow_after_s")
	if bool(o.get("guard", false)):
		if _held_stone() != null:
			# (E again with a stone held: the return's lock, shorter after a clean catch: the player's, BendZone.guard_lock_s)
			lock_s = BendZone.guard_lock_s(me, lock_s) * float(preset().get("lock_mult", 1.0))
		else:
			lock_s = _guard_lock(lock_s)
	if stock():
		lock_s = _stock_lock(o, lock_s)
		var rr := RingRules.current()
		if rr != null:
			rr.note_lock_started(me)               # (round 3: a lock of its own ends its spawn safety, as the player's does)
	if String((o.get("hint", {}) as Dictionary).get("role", "")) == "reaction":
		# (a reaction's only: a guard of another role (the anchor, a hop) never holds back the next catch)
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
		me.body.play_cast(id, md, lock_s, element, grown)   # (grown: a pose's own grown clip, the Air Lance's spear throw)
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
	if stock() and t != null and is_instance_valid(t) and mind().airborne(t):
		# (round 3, fairness: at a body in the air no better than a player with the light aim help)
		var ppr := mind().pp()
		caster.lead = float(ppr.get("air_lead", caster.lead))
		caster.scatter_deg *= float(ppr.get("air_scatter_mult", 1.0))
	caster.modes[id] = md
	caster.side = _pick_side(t)
	var before := BendEffects.last_of(caster)
	var o0 := _option(key)
	var held := _held_stone() if bool(o0.get("guard", false)) else null
	var returning := held != null
	# (the player's own hooks: a grow move held past its second click casts grown, a dash by the keys held goes the way
	# its picked keys say; both cleared after)
	caster.grown = grown and bool(o0.get("grow", false))
	caster.dash_dir = _held_dir(o0, t)
	var ok := _cast(id, md, t)
	caster.grown = false
	caster.dash_dir = Vector2.ZERO
	if returning:
		# (E again with the stone held: BendZone.return_stone threw it back; the rally its returns, either side's)
		ok = not is_instance_valid(held) or int(held.get_meta(&"bend_held_by", -1)) != me.get_instance_id()
		if ok and is_instance_valid(held):
			longest_rally = maxi(longest_rally, int(held.get_meta(RETURNS_META, 0)))
	locks.append({"move": id, "mode": md, "lock_s": lock_s, "took_s": took, "clip": me.body.cast_clip if me.body != null else "",
			"grown": grown, "return": returning})
	if locks.size() > 64:
		locks.pop_front()
	last_cast = {"move": id, "mode": md, "lock_s": lock_s, "took_s": took, "ok": ok, "at": _now(), "grown": grown,
			"return": returning}
	if ok:
		casts += 1
		casts_by[key] = int(casts_by.get(key, 0)) + 1
		if grown:
			grows_by[key] = int(grows_by.get(key, 0)) + 1
		if returning:
			returns += 1
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
	if stock() and not o.is_empty():
		mind().on_released(o, t if t != null and is_instance_valid(t) else null)
	_after_cast(o, before)


## Casts (id, md) now through the one path: BendCast.cast when it is there; a bend spec through BendEffects with its caster;
## else its own way for spike, wall and gust push (FALLBACK). False: nothing came of it (no water, nothing to work on).
func _cast(id: String, md: String, t: Node3D) -> bool:
	var spec := spec_of(id, md)
	var at := _cast_point(id, md, t)
	if id == "mend":
		t = _own_wall(true, 6.0)                    # (Mend works on its own worn piece, never on the man it fights)
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


## The keys a bot "holds" for a dash of option `o` whose way is the keys held (spec dir "held"; BodyBendCaster.dash_dir:
## x right of the way to the foe, y toward him): the way it picked (_dash_way), a side the one found safe (_sides, else the
## caster's side at the release); ZERO for any other cast (the spec's none: back).
func _held_dir(o: Dictionary, _t: Node3D) -> Vector2:
	if o.is_empty() or bool(o.get("old", false)) or String((o.spec as Dictionary).get("dir", "")) != "held":
		return Vector2.ZERO
	match _dash_way(o):
		"side":
			var sd := float(_sides.get(String(o.get("key", "")), caster.side))
			return Vector2(signf(sd) if absf(sd) > 0.01 else 1.0, 0.0)
		"forward":
			return Vector2(0.0, 1.0)
	return Vector2(0.0, -1.0)


## The way a dash of option `o` goes for a bot: one whose way is the keys held (dir "held": a bot has none) its pick of this
## think (_ways: its hint's way first, else another with room), else its spec's (back, side), else at the foe.
func _dash_way(o: Dictionary) -> String:
	var spec: Dictionary = o.get("spec", {})
	if String(spec.get("dir", "")) == "held":
		var w := String(_ways.get(String(o.get("key", "")), ""))
		if w != "":
			return w
		w = String((o.get("hint", {}) as Dictionary).get("way", ""))
		return w if w != "" else "side"
	return "back" if bool(spec.get("back", false)) else "side" if bool(spec.get("side", false)) else "forward"


## Whether a dash of `o` whose way is the keys held may go a way with room (_dash_safe): its hint's way first, then side, back
## (at the foe only when its hint says so: a dodge never runs into what comes); the one found kept as its pick (_ways), false
## none.
func _pick_way(o: Dictionary, t: Node3D) -> bool:
	var key := String(o.get("key", ""))
	var first := String((o.get("hint", {}) as Dictionary).get("way", "side"))
	var side := _pick_side(t)
	for w: String in [first, "side", "back"]:
		_ways[key] = w
		for sd: float in ([side, -side] if w == "side" else [side]):
			_sides[key] = sd
			if _way_safe(o, t):
				return true
	_ways.erase(key)
	_sides.erase(key)
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
	if z != null and is_instance_valid(z) and z is BendZone and (z as BendZone).kind in GUARD_ZONES:
		_guards.append([z, (z as BendZone).took])   # ([zone, what it took so far]: answered, catches)
		if ring_mind != null and stock() and bool(o.get("guard", false)):
			ring_mind.shield_stood(z as BendZone)   # (round 4: the shield is up)


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
		if not is_instance_valid(z) or (z as BendZone).is_queued_for_deletion():
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


## A stone it caught and holds sent back: its guard cast again (E again, as the player's: the return; spec 2.6), forced as
## soon as its reaction allows, its rest cut short (the guard's own cool and the guard cool waived: the catch is the moment).
## Only earth holds: water's, fire's and air's guards send a perfect back by themselves.
func _answer_catch() -> void:
	var g := guard_of(element)
	if element != "earth" or g.is_empty() or _held_stone() == null:
		return
	var key := "%s/%s" % [g[0], g[1]]
	if stock():
		# (round 5, the % ring: the player throws a held stone with E or with Shove (2, right-click: "Shove throws the stone
		# you hold"); the bot too, by bend_ai.json pct.held_shove, so the mirror's play is not all E)
		var sh := float((ai().get("pct", {}) as Dictionary).get("held_shove", 0.0))
		if sh > 0.0 and not _option(HELD_SHOVE).is_empty() and me.rng.randf() < sh:
			key = HELD_SHOVE
	var at := _now() + float(preset().get("reaction_s", 0.4)) * 0.5
	_next[key] = at
	_cool.erase(key)
	_guard_until = minf(_guard_until, at)
	_rest_until = minf(_rest_until, at)


## A guard of its own told its result (BendCaster.guarded, from BendZone: the same as the player's): perfect (on the beat:
## a clean catch for earth's stone), late (half through; earth's stone still caught), whiff (nothing taken: its next guard's
## lock whiff_lock_s within whiff_s, BendZone.guard_lock_s).
func _on_guarded(result: String, what: String) -> void:
	match result:
		"perfect":
			perfects += 1
			if element == "earth" and what == "stone":
				clean_catches += 1
		"late":
			lates += 1
		"whiff":
			whiffs += 1


func _on_struck(who: Node, _dmg: float) -> void:
	if who != null and who != me:
		hits += 1


## A hit taken (NpcFighter.apply_hit, any damage above 0): the lock pushed back (_set_back); its "hurt" need.
func on_hurt(dmg: float, source: Node = null) -> void:
	if dmg <= 0.0:
		return
	_hurt_t = _now()
	if stock():
		if me.has_meta(BendStatus.HIT_LOCK_META):
			me.remove_meta(BendStatus.HIT_LOCK_META)
		return                                     # (round 3: the lock waits in hitstun, never pushed back: tick)
	if casting != "":
		_set_back(source, "hit")
	elif me.has_meta(BendStatus.HIT_LOCK_META):
		me.remove_meta(BendStatus.HIT_LOCK_META)   # (read once, lock or none: the blow's cost is not left for a later one)


## A knock taken (BendKnock, through NpcFighter.on_bend_knock): the lock pushed back (_set_back).
func on_knocked(_v: Vector3, by: Node = null) -> void:
	if casting != "" and not stock():
		_set_back(by, "knock")


## The lock pushed back by a hit from `by` (spec 2.3, as the player's): by what the hit cost its sender (his last cast's
## lock: NpcBending.lock_s for a bot, the move's lock_s for anyone else), at least hit_setback_min_s; never below empty and
## never wiped. A dash's or a guard's lock is never pushed back; lightning's charge breaks (lost). The hit's damage and its
## knock come apart: one setback for both (SETBACK_SAME_S).
func _set_back(by: Node, why: String) -> void:
	# (what the blow cost its sender, written on it by BendStatus.hurt: read once whatever comes of it, the player's own
	# reckoning, BendStatus.setback_s)
	var blow := BendStatus.setback_s(me) if me.has_meta(BendStatus.HIT_LOCK_META) else -1.0
	var o := _option(casting + "/" + mode)
	if casting == "fire_arc" and mode == "lightning":
		_lose(why)
		return
	var role := String((o.get("hint", {}) as Dictionary).get("role", ""))
	if String(o.get("do", "")) == "dash" or bool(o.get("guard", false)) or role == "reaction":
		return
	if _now() - _setback_t < SETBACK_SAME_S:
		return
	_setback_t = _now()
	var cost := rule("hit_setback_min_s")
	if blow >= 0.0:
		cost = blow
	elif by is NpcFighter and (by as NpcFighter).brain != null and (by as NpcFighter).brain.bending != null:
		var lc: Dictionary = (by as NpcFighter).brain.bending.last_cast
		cost = maxf(cost, float(lc.get("lock_s", 0.0)))
	elif by != null:
		var last := BendEffects.last_of(by)
		if not last.is_empty():
			var mv := SwayMoves.move(String(last.get("move", "")))
			var ml: Dictionary = mv.get("mode_lock_s", {})
			cost = maxf(cost, float(ml.get(String(last.get("mode", "")), mv.get("lock_s", 0.0))))
	lock_t = maxf(lock_t - cost, 0.0)
	fill = clampf(lock_t / maxf(lock_s, 0.001), 0.0, 1.0)
	setbacks += 1
	lost_why = why


## Its fighter leaving the world (freed between rounds, cleared): its lock let go, the zones it holds round itself (guards,
## bubbles, shields: they follow it) and its bolts in flight ended, so none is left reading a body that is gone.
func on_exit() -> void:
	_cancel()
	if not me.is_inside_tree():
		return
	for z in me.get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.owner_node == me and bz.follow:
			bz.set_physics_process(false)
			bz.end()
	for b in me.get_tree().get_nodes_in_group(BendBolt.GROUP):
		# (its bolts in flight, a stone its guard turned aside among them: a strike would read a caster that is gone)
		var bb := b as BendBolt
		if bb != null and bb.caster == me and not bb.spent:
			bb.end("gone")
	_guards.clear()


func _lose(why: String) -> void:
	if casting == "":
		return
	lost += 1
	lost_why = why
	_cool[casting + "/" + mode] = _now() + 0.8
	_drop_lock("break")


## Round 4: landed with an air form's lock under way (the player's rule, SwayCaster._landed): a Slam called off for free
## (no cool), an air close hit turned back into the jab with the time it has filled kept.
func _landed_form() -> void:
	_air_seen = false
	if mode == "slam":
		_cancel()
		return
	var jb := jab_of(element)
	if jb.size() < 2 or casting != String(jb[0]):
		return
	var spent := lock_t
	mode = String(jb[1])
	var t := brain.target
	lock_s = _stock_lock(_option(casting + "/" + mode), lock_for(casting, mode, _preset_name(), _cast_dist(casting, mode, t), me))
	lock_t = minf(spent, lock_s)
	fill = clampf(lock_t / maxf(lock_s, 0.001), 0.0, 1.0)
	if me.body != null:
		me.body.play_cast(casting, mode, maxf(lock_s - lock_t, 0.1), element)


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
	var gl: Variant = spec.get("glide")
	if gl is Dictionary:
		air += float((gl as Dictionary).get("s", 3.0))   # (Leap's glide: a bot holds it the whole while, drifting on)
	return f * CARRY_S + f * f / (2.0 * NpcFighter.DECEL) + f * air * 0.5


## A dash's way (_dash_way): back (away from the foe), to a side (the side with room), else at the foe.
func _dash_dir(o: Dictionary, t: Node3D) -> Vector3:
	var way := _way(t)
	match _dash_way(o) if not bool(o.get("old", false)) else "forward":
		"back":
			return -way
		"side":
			return way.cross(Vector3.UP).normalized() * float(_sides.get(String(o.get("key", "")), _pick_side(t)))
	return way


## Whether a dash (or the pillar's launch) leaves it on the deck: the room along its way past what it carries (edge_margin_m),
## and its landing inside the ropes (bounds_fn's place for it no more than SIDE_SLACK_M across the way to the foe from where
## it would land: edge_fn reads only the open ends, and side dashes went over a long side; R1-BALANCE soak, 2026-10-05).
func _dash_safe(o: Dictionary, t: Node3D) -> bool:
	if not bool(o.get("old", false)) and String((o.spec as Dictionary).get("dir", "")) == "held":
		return _pick_way(o, t)
	return _way_safe(o, t)


## _dash_safe for the way the dash of `o` goes now (_dash_way; a dir "held" spec's own numbers for that way: its fwd, back
## or side, as BendEffects.dash reads them).
func _way_safe(o: Dictionary, t: Node3D) -> bool:
	if not edge_fn.is_valid():
		return true
	var spec: Dictionary = o.spec if not bool(o.old) else {"fwd_mps": 6.0, "up_mps": 8.0}
	var sub: Variant = spec.get({"forward": "fwd"}.get(_dash_way(o), _dash_way(o)))
	if String(spec.get("dir", "")) == "held" and sub is Dictionary:
		spec = spec.duplicate()
		spec.merge(sub as Dictionary, true)
	var margin := float(ai().get("edge_margin_m", 1.5))
	var dir := _dash_dir(o, t)
	var reach := dash_carry(spec) + margin
	if _room(dir) <= reach:
		return false
	if bounds_fn.is_valid():
		var land := me.global_position + Vector3(dir.x, 0.0, dir.z).normalized() * reach
		var off := _clamp(land) - land
		var across := _way(t).cross(Vector3.UP).normalized()
		if absf(off.dot(across)) > SIDE_SLACK_M:
			return false
	return true


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
	if not edge_fn.is_valid() or stock():
		return                                     # (round 3: no velocity written; the teeter keeps a runner on the deck)
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
	if stock():
		band = mind().keep_band(band)              # (round 3: a finisher that kills from farther walks in first)
	var blind := not brain.seen_now or NpcBendCaster.hidden(me, t)     # (a smoke or a steam on the line: blind as well)
	if blind or d > band.y:
		me.face_lock = Vector3.INF
		var goal := brain.last_seen if brain.last_seen != Vector3.INF else tp
		var to := goal - me.global_position
		to.y = 0.0
		if to.length() > band.x:
			goal = me.global_position + to.normalized() * (to.length() - band.x * 0.8)
		if blind and to.length_squared() > 1e-6:
			# (sight cut off, by its own wall, a smoke or a steam: it goes on toward where it saw him last, out to its strafe
			# side, so the line clears it; never stands behind it. The merge gate's earth bot stood 70 s behind the wall it
			# raised 3.5 m before itself, an air bot 60 s confined behind a fire player's smoke; capped at 2 m on, the earth
			# bot never came into its jab's reach again: gate R2's bend_bots)
			var on := maxf(to.length() - band.x * 0.8, 0.0)
			goal = me.global_position + to.normalized() * on + to.normalized().cross(Vector3.UP) * _strafe * 4.0
			if _room(to.normalized().cross(Vector3.UP) * _strafe) < 3.0:
				_strafe = -_strafe
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
	var goal2 := me.global_position + want
	if stock():
		goal2 = mind().centre_goal(goal2)          # (round 3: high on its own %, it keeps further from its end)
	me.face_lock = tp
	me.go(_clamp(goal2), NpcFighter.RUN_SPEED * 0.75, 0.4, true)


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
	var wn := BendLoadout.wall_numbers(me, "wall", w, matter)           # (a worn loadout's Earth Wall numbers: the soak's wearer)
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
