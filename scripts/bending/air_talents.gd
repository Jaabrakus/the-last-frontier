class_name AirTalents
extends RefCounted
## Air's behaviour talents (the skill tree's air nodes whose effect is new code; the owner, 2026-10-11: "we need to make sure all
## the talents work and they work in game right"; BendLoadout's BEHAVIOUR HOOK: data/bending/loadout_apply.json "behaviour"). Each
## seam in the game code asks here with one line, and each answer is the wearer's alone: a body that wears nothing (Classic, every
## bot of a normal match) gets the game's own answer, decided by one meta lookup (BendLoadout.wears). Static.
##   Tailwind (air.slice.tailwind)      on_hit: a Slice of his that lands charges his Carried wind (BendZone.carry_wind), as a
##                                      dash does (BendR3._noted, the hitter's side of a hit)
##   Drift Guard (air.guard.drift)      guard_walk: he walks at DRIFT_MPS with his Wind Guard up (RingMoves' deck run; SwayCaster's
##                                      guard root and a bot's halt let him); its beat 0.25 s is the node's spec number
##   Eye of the Gale (air.guard.eye)    eye_catch: a perfect Wind Guard bounce with E still held circles him (BendBolt's swing,
##                                      held by swing_hold) up to EYE_S and leaves along his aim when E is let go (x perfect_mult
##                                      as the bounce); guard_carry_s: the Carried wind a perfect Wind Guard gives lasts the node's
##                                      new:air_shield.perfect_carry_s (0.4 s)
##   Rebound (air.guard.rebound)        start_fill: his next Slice or Wind Ball begun within REBOUND_S of a perfect Wind Guard
##                                      starts its lock REBOUND_FILL full (once); his held guard's longest stand is the node's
##                                      rules:air_rules.guard.hold_max_s (BendLoadout.tune at SwayCaster._hold_guard and the bot's
##                                      shield_tick)

const TAILWIND := "air.slice.tailwind"
const DRIFT := "air.guard.drift"
const EYE := "air.guard.eye"
const REBOUND := "air.guard.rebound"
## Drift Guard: his walk with the Wind Guard up (m/s; the node: "walk at 1.5 m/s").
const DRIFT_MPS := 1.5
## Eye of the Gale: the longest the bounced air circles him (s).
const EYE_S := 0.6
## Rebound: how soon after a perfect Wind Guard the next air_blast lock must begin (s), and the fill it starts at.
const REBOUND_S := 1.0
const REBOUND_FILL := 0.4
## Rebound: the meta of the perfect Wind Guard his next lock may still take the head start from (its time; spent by that lock).
const REBOUND_META := &"air_rebound_at"


# ---------------------------------------------------------------- Tailwind
## The hitter's side of a hit of his that landed (BendR3._noted): a Slice of a Tailwind wearer charges his Carried wind. A Slice
## sent back by a guard is the guarder's return (".return"), not this.
static func on_hit(by: Node, _n: Node, inf: Dictionary) -> void:
	if by == null or String(inf.get("tag", "")) != "air_blast/slice" or bool(inf.get("returned", false)):
		return
	if BendLoadout.wears(by, TAILWIND):
		BendZone.carry_wind(by)


# ---------------------------------------------------------------- Drift Guard
## Whether `body` walks with his Wind Guard up (Drift Guard worn, his guard standing an air one).
static func drifts(body: Node) -> bool:
	return BendLoadout.wears(body, DRIFT) and BendPoses.element_of(body) == "air"


## The deck run's target with his guard up (RingMoves._ground_physics): ZERO (no walking while it is up), or for a Drift Guard
## wearer `target` at DRIFT_MPS at most.
static func guard_walk(body: Node, target: Vector3) -> Vector3:
	if not drifts(body):
		return Vector3.ZERO
	return target.limit_length(DRIFT_MPS)


# ---------------------------------------------------------------- Eye of the Gale
## Whether `body` holds his guard now: the player's E (SwayCaster._guard_down; a puppet's by its owner's keys), a bot's held
## shield (NpcRingMind.shield: up while what it guards against still comes).
static func guard_held(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	var sc := SwayCaster.of(body)
	if sc != null:
		return sc._guard_down()
	if body is NpcFighter:
		var br := (body as NpcFighter).brain
		var rm: NpcRingMind = br.bending.ring_mind if br != null and br.bending != null else null
		return rm != null and not rm.shield.is_empty()
	return false


## A perfect Wind Guard bounce of air bolt `b` by guard `z` (BendZone._guard_bolt): for an Eye of the Gale wearer still holding
## his guard, it circles him (BendBolt.begin_swing, held by swing_hold) and leaves along his aim as E is let go or at EYE_S, x
## perfect_mult as the bounce. True when it took it (else the bounce goes straight back, today's).
static func eye_catch(z: BendZone, b: BendBolt) -> bool:
	var owner := z.owner_node
	if not BendLoadout.wears(owner, EYE) or not guard_held(owner) or b.floor_wave:
		return false
	var k := BendLoadout.tune_f(owner, "rules:guard_rules.perfect_mult", Bending.rule("perfect_mult", 1.2))
	b.begin_swing(owner, EYE_S, BendZone.SWING_R, k)
	b.swing_hold = guard_held.bind(owner)
	b.info["ret_mult"] = k
	return true


## How long the Carried wind a perfect Wind Guard of `body`'s gives lasts (s; -1 the passive's own: BendZone.carry_wind).
static func guard_carry_s(body: Node) -> float:
	if not BendLoadout.wears(body, EYE):
		return -1.0
	return BendLoadout.tune_f(body, "new:air_shield.perfect_carry_s", -1.0)


# ---------------------------------------------------------------- Rebound
## A perfect Wind Guard of `body`'s (BendZone.report): a Rebound wearer's next air_blast lock may start part full.
static func on_guard(body: Node, result: String, el: String) -> void:
	if result == "perfect" and el == "air" and BendLoadout.wears(body, REBOUND):
		body.set_meta(REBOUND_META, BendStatus.now())


## The fill a lock of `m` begun now by `body` starts at (SwayCaster._try_begin, NpcBending.begin): REBOUND_FILL for a Rebound
## wearer's Slice or Wind Ball within REBOUND_S of his perfect Wind Guard (spent by it), else 0.
static func start_fill(body: Node, m: String) -> float:
	if m != "air_blast" or body == null or not body.has_meta(REBOUND_META):
		return 0.0
	var at := float(body.get_meta(REBOUND_META))
	body.remove_meta(REBOUND_META)
	if not BendLoadout.wears(body, REBOUND) or BendStatus.now() - at > REBOUND_S:
		return 0.0
	return REBOUND_FILL
