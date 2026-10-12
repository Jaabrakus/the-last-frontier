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
static func cast(bc: BendCaster, m: String, mode: String, spec: Dictionary, _a: Dictionary) -> void:
	var p := bc.body
	if not any(p):
		return
	if m == "footwork" and mode == "step":
		p.set_meta(STEP_META, BendStatus.now())
	if m == "footwork" and mode == "step" and BendLoadout.wears(p, "fire.step.ignite"):
		# (Ignite Step: a 2 m line of fire along the Step from where it left, 1.5 s; floor fire: jump it)
		var v: Variant = BendEffects.last_of(bc).get("v")
		var flat := Vector3((v as Vector3).x, 0.0, (v as Vector3).z) if v is Vector3 else Vector3.ZERO
		if flat.length_squared() > 1e-4:
			var dir := flat.normalized()
			var at := FormEffects.ground_at(p, p.global_position)
			matter(p, "burn", at + dir * IGNITE_M * 0.5, dir, {"width_m": IGNITE_W, "thick_m": IGNITE_M, "life_s": IGNITE_S,
					"tick_tag": "matter/burn", "tick_cap": BURN_CAP}, m)
	if m == "fire_breath" and mode == "breath" and BendLoadout.wears(p, "fire.breath.scald"):
		# (Scald: the Breath through steam: each steam cloud its cone reaches scalds)
		for z in p.get_tree().get_nodes_in_group(BendZone.GROUP):
			var sz := z as BendZone
			if sz != null and sz.kind == "steam" and not sz.is_queued_for_deletion() \
					and _in_cone(p, sz.global_position, float(spec.get("range_m", 4.5)) + sz.radius, float(spec.get("deg", 45.0))):
				through_steam(sz, p)


## Whether `at` is within `reach` m and half of `deg` degrees (and a little) of `p`'s facing, flat (a cone's reach).
static func _in_cone(p: Node3D, at: Vector3, reach: float, deg: float) -> bool:
	var to := Vector3(at.x - p.global_position.x, 0.0, at.z - p.global_position.z)
	if to.length() > reach:
		return false
	var fwd := -p.global_basis.z
	fwd.y = 0.0
	return to.length() < 0.5 or rad_to_deg(fwd.normalized().angle_to(to.normalized())) <= deg * 0.5 + 15.0


## The numbers of fire's floor fire and its bursts (the nodes' effect texts).
const IGNITE_M := 2.0
const IGNITE_W := 1.2
const IGNITE_S := 1.5
const BURN_CAP := 3                      ## (the tick contract: one burn line or patch 3%, a tick 1%)
const CRESCENT_R := 2.0
const CRESCENT_S := 1.5
const SCALD_S := 1.5
const BLAZE_R := 2.0
const LANDS_M := 3.0                     ## (a bolt ending this high over the deck or lower "lands": its patch or seam below)


## A matter zone (BendZone MATTER) of `by`'s: kind "burn" (fire's floor fire), "scald" or "seam"; `spec` its BendZone numbers.
static func matter(by: Node3D, kind: String, at: Vector3, way: Vector3, spec: Dictionary, m := "") -> BendZone:
	if by == null or not is_instance_valid(by) or not by.is_inside_tree():
		return null
	var s := spec.duplicate()
	if not s.has("radius_m"):
		s["radius_m"] = maxf(float(s.get("width_m", 1.0)), float(s.get("thick_m", 1.0))) * 0.5 + 0.3
	var z := BendZone.make(by, kind, at, s, way)
	if z != null:
		z.info = {"move": m, "tag": String(s.get("tick_tag", ""))}
		BendLooks.burst(at + Vector3.UP * 0.2, "fire", 14, Vector3.UP, 70.0, 2.5, 0.3)
	return z


## A round patch of floor fire of `by`'s on the deck under `at` (none when `at` is more than LANDS_M over it).
static func patch(by: Node3D, at: Vector3, r: float, life: float, kind: String, tag: String, cap: int, m := "") -> BendZone:
	var g := FormEffects.ground_at(by, at)
	if at.y - g.y > LANDS_M or g.y - at.y > 1.0:
		return null
	return matter(by, kind, g, Vector3.FORWARD, {"radius_m": r, "round": true, "width_m": r * 1.6, "thick_m": r * 1.6,
			"height_m": 0.4, "life_s": life, "tick_tag": tag, "tick_cap": cap}, m)


## A bolt of a wearer's ended (BendBolt._finish, the host's: hit, wall, world, range): Blazing Fireball's burst, Crescent Burn's
## patch.
static func bolt_ended(b: BendBolt, why: String) -> void:
	var by := b.caster
	if not any(by) or not why in ["hit", "wall", "world", "range"] or bool(b.info.get("returned", false)):
		return
	var tag := String(b.info.get("tag", ""))
	var at := b.global_position
	var back := -b.velocity.normalized() * 0.35 if b.velocity.length_squared() > 1e-6 else Vector3.ZERO
	if tag == "fire_blast/punch.grown" and BendLoadout.wears(by, "fire.fireball.blazing"):
		burst(by, at + back, BLAZE_R, "fire_blast/punch.grown+burst", b.struck_who)
	if tag == "fire_kick/high_kick" and BendLoadout.wears(by, "fire.highkick.crescent_burn"):
		patch(by, at + back, CRESCENT_R, CRESCENT_S, "burn", "matter/burn", BURN_CAP, "fire_kick")


## A burst of `by`'s at `at`, `r` m round (its hit class `key`: the wearer's whole new class, BendLoadout.new_class, read by
## RingRules.on_hit): whoever is in it and in its sight (a wall between covers him: it stays on the side it hit), but `spare`
## (the one the bolt itself struck), knocked away from it. How many it hit.
static func burst(by: Node3D, at: Vector3, r: float, key: String, spare: Node = null) -> int:
	if not is_instance_valid(by) or not by.is_inside_tree():
		return 0
	BendLooks.burst(at, "fire", 34, Vector3.UP, 180.0, 6.0, 0.45)
	BendLooks.sound("fire", "hit", at, 0.0)
	var n_hit := 0
	var space := by.get_world_3d().direct_space_state
	var wb := BendCaster.wrap(by)
	var ex: Array[RID] = wb.exclude() if wb != null else []
	var cls := BendLoadout.new_class(by, key)
	for e in BendCaster.near(by, at, r + 0.6):
		var n: Node3D = e[0]
		if n == spare or not BendStatus.can_take(n, by):
			continue
		var chest := n.global_position + Vector3.UP * 0.9
		if Vector2(chest.x - at.x, chest.z - at.z).length() > r + 0.35:
			continue
		var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, chest, 0xFFFFFFFF, ex))
		if not h.is_empty() and BendBolt._taker(h.collider as Node) != n and not (h.collider is CharacterBody3D):
			continue                              # (a wall between: the burst stays on its side)
		var out := Vector3(chest.x - at.x, 0.0, chest.z - at.z)
		out = out.normalized() if out.length_squared() > 1e-4 else Vector3.FORWARD
		BendR3.deliver(n, float(cls.get("d", 6.0)), chest, out, by, -1.0, out * float(cls.get("base", 5.0)) + Vector3.UP * 2.0,
				{"tag": key, "move": key.get_slice("/", 0), "from": at, "dir": out, "burst": true})
		n_hit += 1
	return n_hit


## `by`'s fire passed through steam cloud `z` (a bolt of his: BendZone.on_bolt; his Breath: cast): a worn Scald makes it burn
## for SCALD_S (once a cloud), his matter: a foe inside gains 1% each 0.5 s, at most 3% (not floor fire: a jump does not clear it).
static func through_steam(z: BendZone, by: Node3D) -> void:
	if z == null or not is_instance_valid(z) or z.has_meta(&"talent_scalded") or not BendLoadout.wears(by, "fire.breath.scald"):
		return
	if not NetSpells.decides():
		return
	z.set_meta(&"talent_scalded", true)
	if matter(by, "scald", z.global_position, Vector3.FORWARD, {"radius_m": z.radius, "round": true, "life_s": SCALD_S,
			"tick_tag": "matter/burn", "tick_cap": BURN_CAP, "tick_floor": false}, "fire_breath") != null:
		BendLooks.burst(z.global_position + Vector3.UP, "fire", 20, Vector3.UP, 120.0, 1.5, 0.6)
