class_name FireTalents
extends RefCounted
## Fire's behaviour talents (data/sway/skill_tree.json nodes whose effect is new code; the owner, 2026-10-11: "we need to make
## sure all the talents work and they work in game right"). Each applies only to the body that wears it live (BendLoadout.wears:
## loadout_apply.json `behaviour`, `live`, `nodes`); Classic (nothing worn) never gets past the first meta lookup of each seam,
## so its numbers are exactly the game's. The seams (one call each where the game does the thing, for the player and a bot):
##   head_start(body, m)           a lock of move `m` begun now: the share of it already full (SwayCaster._try_begin,
##                                 NpcBending.begin); a technique's head start is given by:
##     beat(body, m, mode, late)   a held cast let go `late` s after its lock filled (SwayCaster's release, NpcBending._release):
##                                 within BEAT_S it is on the Beat (the tree's `beat`: a click or a cast that goes by itself
##                                 never is); Two-Hand Rhythm (a Punch: the next Punch 30% full within 1 s), Chain Kicks (a Kick:
##                                 the next Kick 40% full within 0.6 s). Only a worn technique pays; then a flash on his own hands.
##     guarded(body, result, what) a guard's result (BendZone.report): Hot Hands (a perfect Parry: the next Punch half full within 1 s)
##     charge_broken(body, m)      a hit broke his Lightning charge (SwayCaster.took_hit, NpcBending.tick): Grounded Charge (the
##                                 next Lightning half full within 1 s)
##   fill_mult(body, moving)       the fill's rate from a worn passive (SwayCaster._hold, NpcBending.tick): Hot Feet (standing
##                                 still x0.9; its on-the-move x1.1 is the tune path rules:passives.fire.moving_mult, read in
##                                 SwayCaster._moving_mult), Dancing Feet (x1.15 for 0.6 s after a Step ends; its x0.9 the same
##                                 tune path)
##   cast(bc, m, mode, spec, a)    a cast made (BendEffects._apply, after its effect): Ignite Step's burn line, the Step's mark
## A lock's head start is never a whole lock (the tree's lock contract: "never a zero lock"): at most HEAD_MAX.

const HEAD_META := &"talent_head_start"          ## {move: {fill, until}}: the next lock of that move starts that full
const STEP_META := &"talent_step_at"             ## when his last Step was cast (Dancing Feet: its end is BendMotion's bend_dash_end)
## The Beat (skill_tree.json `beat`, the owner's answer "yes"): a held cast let go within this many seconds after its lock filled.
const BEAT_S := 0.2
const HEAD_MAX := 0.95
## The nodes' own numbers (their effect text; none of them is a number of today's data).
const RHYTHM := {"move": "fire_blast", "fill": 0.3, "within_s": 1.0}
const CHAIN := {"move": "fire_kick", "fill": 0.4, "within_s": 0.6}
const HOT_HANDS := {"move": "fire_blast", "fill": 0.5, "within_s": 1.0}
const GROUNDED := {"move": "fire_arc", "fill": 0.5, "within_s": 1.0}
const DANCING_S := 0.6
const DANCING_MULT := 1.15
const HOT_FEET_STILL := 0.9


## Whether `body` wears anything live (Classic: one meta lookup, false).
static func any(body: Object) -> bool:
	return body != null and is_instance_valid(body) and body is Node and (body as Node).has_meta(BendLoadout.PICKS_META)


static func wears(body: Object, id: String) -> bool:
	return any(body) and BendLoadout.wears(body, id)


# ---------------------------------------------------------------- head starts (the techniques)
## The next lock of move `m` by `body` begun within `within_s` starts `fill` full (the higher of two given).
static func give_head_start(body: Node, m: String, fill: float, within_s: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var now := BendStatus.now()
	var hs: Dictionary = (body.get_meta(HEAD_META) as Dictionary).duplicate() if body.has_meta(HEAD_META) else {}
	var cur: Variant = hs.get(m)
	if cur is Dictionary and float((cur as Dictionary).until) >= now and float((cur as Dictionary).fill) >= fill:
		return
	hs[m] = {"fill": clampf(fill, 0.0, HEAD_MAX), "until": now + within_s}
	body.set_meta(HEAD_META, hs)


## The share of a lock of move `m` by `body` begun now that is already full (0: none, Classic), the head start spent.
static func head_start(body: Object, m: String) -> float:
	if body == null or not is_instance_valid(body) or not (body is Node) or not (body as Node).has_meta(HEAD_META):
		return 0.0
	var n := body as Node
	var hs: Dictionary = (n.get_meta(HEAD_META) as Dictionary).duplicate()
	var e: Variant = hs.get(m)
	if e == null:
		return 0.0
	hs.erase(m)
	if hs.is_empty():
		n.remove_meta(HEAD_META)
	else:
		n.set_meta(HEAD_META, hs)
	if e is Dictionary and BendStatus.now() <= float((e as Dictionary).until) + 1e-4:
		return float((e as Dictionary).fill)
	return 0.0


## A held cast of `m` at `mode` let go `late` s after its lock filled: on the Beat (within BEAT_S) a worn technique pays (true).
static func beat(body: Node, m: String, mode: String, late: float) -> bool:
	if not any(body) or late > BEAT_S + 1e-4 or late < 0.0:
		return false
	var paid := false
	if m == "fire_blast" and mode == "punch" and BendLoadout.wears(body, "fire.punch.rhythm"):
		give_head_start(body, String(RHYTHM.move), float(RHYTHM.fill), float(RHYTHM.within_s))
		paid = true
	if m == "fire_kick" and mode == "kick" and BendLoadout.wears(body, "fire.kick.chain"):
		give_head_start(body, String(CHAIN.move), float(CHAIN.fill), float(CHAIN.within_s))
		paid = true
	if paid:
		body.set_meta(&"talent_beat_at", BendStatus.now())
		_hands_flash(body, true)
	return paid


## A brief flash on `body`'s own hands only, nothing on anyone else: the Beat's cue (skill_tree.json beat.cue: with its click) or
## Hot Hands' flare.
static func _hands_flash(body: Node, click: bool) -> void:
	var sc := SwayCaster.of(body)
	var at: Vector3 = sc.hand_point() if sc != null else ((body as Node3D).global_position + Vector3.UP * 1.3 if body is Node3D else Vector3.ZERO)
	if click:
		BendSounds.play(&"lock_grow", at, -6.0)
	if not BendLooks.live():
		return
	var pool := BendLooks._pool()
	if pool != null:
		pool.play("flash", Transform3D(Basis.IDENTITY, at), 0.12, 0.18, 0.5, Color(1.0, 0.62, 0.22), Color(1.0, 0.92, 0.6))


## A guard of `body`'s ended `result` on `what` (BendZone.report, every guard): Hot Hands' head start after a perfect Parry.
static func guarded(body: Node, result: String, what: String, el: String) -> void:
	if result != "perfect" or el != "fire" or what == "" or not any(body):
		return
	if BendLoadout.wears(body, "fire.parry.hot_hands"):
		give_head_start(body, String(HOT_HANDS.move), float(HOT_HANDS.fill), float(HOT_HANDS.within_s))
		_hands_flash(body, false)                    # (the fists flare: visual only)


## A hit broke `body`'s charge of `m` (Lightning): Grounded Charge keeps half of it for a lock begun within 1 s.
static func charge_broken(body: Node, m: String) -> void:
	if m != "fire_arc" or not any(body):
		return
	if BendLoadout.wears(body, "fire.lightning.grounded"):
		give_head_start(body, String(GROUNDED.move), float(GROUNDED.fill), float(GROUNDED.within_s))


# ---------------------------------------------------------------- the fill (the passives)
## The fill's rate from `body`'s worn passives now (1.0: none, Classic): `moving` as SwayCaster's fill reads it (over moving_mps).
static func fill_mult(body: Object, moving: bool) -> float:
	if not any(body):
		return 1.0
	var k := 1.0
	if not moving and BendLoadout.wears(body, "fire.passive.hot_feet"):
		k *= HOT_FEET_STILL
	if BendLoadout.wears(body, "fire.passive.dancing_feet") and stepped_within(body as Node, DANCING_S):
		k *= DANCING_MULT
	return k


## Whether `body`'s last Step ended within `s` (a Step's end: BendMotion's bend_dash_end of the dash it began).
static func stepped_within(body: Node, s: float) -> bool:
	if not body.has_meta(STEP_META) or not body.has_meta(&"bend_dash_end"):
		return false
	var end := float(body.get_meta(&"bend_dash_end"))
	return end >= float(body.get_meta(STEP_META)) - 1e-4 and BendStatus.now() - end <= s + 1e-4


# ---------------------------------------------------------------- casts
## Caster `bc` cast move `m`'s `mode` (spec as cast, aim `a`): what a worn talent adds to it.
static func cast(bc: BendCaster, m: String, mode: String, _spec: Dictionary, _a: Dictionary) -> void:
	var p := bc.body
	if not any(p):
		return
	if m == "footwork" and mode == "step":
		p.set_meta(STEP_META, BendStatus.now())
