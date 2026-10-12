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
##   gas_bolt, gas_cone, gas_every fire meeting a gas cloud (the Sulphur set's, earth's; BendZone kind "gas"): it burns, the
##                                 lighter's (ignite: rules.json reaction/ignited_gas); Flashfire's bigger burst. Only gas ever
##                                 reaches these, and only a worn Sulphur makes gas: Classic never does
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
	if BendLoadout.wears(body, "fire.magma.forge") and on_own_seam(body as Node):
		k *= FORGE_MULT
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
	if m == "fire_jets" and mode == "jets" and BendLoadout.wears(p, "fire.magma.landing"):
		p.set_meta(JETS_META, BendStatus.now())         # (Magma Landing: where this dash ends, a seam: dash_ended)
	if m == "fire_wall" and mode == "wall" and BendLoadout.wears(p, "fire.wall.curved"):
		curve_wall(p, BendEffects.last_of(bc).get("zone") as BendZone, spec)
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
	if tag in WAVE_TAGS and b.floor_wave and why in ["range", "wall", "world"] and BendLoadout.wears(by, "fire.set.magma"):
		# (the Magma set: where the Kick's or the Axe Kick's wave dies, a seam; Lava Kick: the Kick's last 4 m)
		var flat := Vector3(b.velocity.x, 0.0, b.velocity.z)
		var dir := flat.normalized() if flat.length_squared() > 1e-6 else Vector3.FORWARD
		var lava := tag != "fire_kick/slam_wave" and BendLoadout.wears(by, "fire.magma.lava_kick")
		var length := LAVA_M if lava else SEAM_W
		seam(by, FormEffects.ground_at(by, at - dir * (length * 0.5 + 0.1)), dir, {"width_m": SEAM_W, "thick_m": length}, lava)
	if tag == "fire_blast/punch.grown" and BendLoadout.wears(by, "fire.magma.fist"):
		# (Magma Fist: a seam where the ball of magma hits or lands)
		var g := FormEffects.ground_at(by, at + back)
		if (at + back).y - g.y <= LANDS_M:
			seam(by, g, Vector3.FORWARD, {"radius_m": FIST_R, "round": true, "width_m": FIST_R * 1.8, "thick_m": FIST_R * 1.8})


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


# ---------------------------------------------------------------- the Fire Wall
## Curved Curtain: the wall ARC_M of curtain along an ARC_DEG arc round the point aimed at.
const ARC_M := 5.0
const ARC_DEG := 120.0
const ARC_SEGS := 4


## A worn Curved Curtain's Fire Wall (cast): the straight wall the cast raised at the point aimed at (`z0`) made a curtain ARC_M
## long along an ARC_DEG arc round that point, its middle on the far side from the caster (a C open toward him): ARC_SEGS fire wall
## pieces, each the wall's own (its numbers, its burn and entry pop, water puts it out), all of them his one wall (a new one ends
## them: one_at_a_time). The pieces.
static func curve_wall(p: Node3D, z0: BendZone, spec: Dictionary) -> Array:
	var out: Array = []
	if z0 == null or not is_instance_valid(z0) or z0.kind != "fire_wall":
		return out
	var center := z0.global_position
	var away := Vector3(center.x - p.global_position.x, 0.0, center.z - p.global_position.z)
	away = away.normalized() if away.length_squared() > 1e-4 else Vector3(z0.way.x, 0.0, z0.way.z).normalized()
	var arc := deg_to_rad(ARC_DEG)
	var r := ARC_M / arc
	var seg := arc / float(ARC_SEGS)
	var s := spec.duplicate()
	s["width_m"] = 2.0 * r * sin(seg * 0.5) + 0.15          # (each piece the chord of its share, a hand's overlap)
	s.erase("place")
	z0.end("curved")
	for i in ARC_SEGS:
		var radial := away.rotated(Vector3.UP, -arc * 0.5 + seg * (float(i) + 0.5))
		var at := FormEffects.ground_at(p, center + radial * r)
		var z := BendZone.make(p, "fire_wall", at, s, radial)
		if z != null:
			z.set_meta(&"talent_curtain", true)
			out.append(z)
	return out


# ---------------------------------------------------------------- Lightning
## Forked Lightning: the fork's reach from the strike's line, and how long the water it reaches is live.
const FORK_M := 6.0
const LIVE_S := 0.5
const WATER_BOLT_R := 1.0


## A Lightning strike of caster `bc`'s from `from` to `to` (BendEffects._strike, the host's): a worn Forked Lightning's fork to
## the nearest water within FORK_M of its line (a puddle, steam, a water bolt in flight) made live for LIVE_S: anyone in it
## takes half the strike's % (rules.json reaction/live: no launch, no stun, no lock set-back; everyone, its caster too). The
## live zone, or null.
static func struck(bc: BendCaster, from: Vector3, to: Vector3) -> BendZone:
	var p := bc.body
	if not BendLoadout.wears(p, "fire.lightning.forked") or not NetSpells.decides():
		return null
	var tree := p.get_tree()
	var best_d := FORK_M
	var best_at := Vector3.INF
	var best_on := from
	var best_r := WATER_BOLT_R
	for z in tree.get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz == null or bz.is_queued_for_deletion() or not bz.kind in ["puddle", "steam"]:
			continue
		var q := bz.global_position + Vector3.UP * (0.1 if bz.kind == "puddle" else 1.0)
		var on := Geometry3D.get_closest_point_to_segment(q, from, to)
		if on.distance_to(q) < best_d:
			best_d = on.distance_to(q)
			best_at = bz.global_position
			best_on = on
			best_r = bz.radius
	for b in tree.get_nodes_in_group(BendBolt.GROUP):
		var bb := b as BendBolt
		if bb == null or bb.spent or bb.kind != "water":
			continue
		var on2 := Geometry3D.get_closest_point_to_segment(bb.global_position, from, to)
		if on2.distance_to(bb.global_position) < best_d:
			best_d = on2.distance_to(bb.global_position)
			best_at = bb.global_position
			best_on = on2
			best_r = WATER_BOLT_R
	if best_at == Vector3.INF:
		return null
	BendLooks.lightning(best_on, best_at + Vector3.UP * 0.3)          # (the fork)
	var strike_d := float(BendLoadout.hit_class(p, RingRules.class_of("fire_arc/lightning")).get("d", 25.0))
	var live := BendZone.make(p, "live", best_at, {"radius_m": best_r, "round": true, "life_s": LIVE_S, "tick_tag": "reaction/live",
			"tick_cap": 1, "tick_floor": false, "tick_shared": false, "tick_all": true, "tick_info": {"strike_d": strike_d}}, Vector3.FORWARD)
	if live != null:
		live.info = {"move": "fire_arc", "tag": "reaction/live"}
		for i in 3:
			var a := best_at + Vector3(randf_range(-best_r, best_r) * 0.7, 0.2, randf_range(-best_r, best_r) * 0.7)
			BendLooks.lightning(a, a + Vector3(randf_range(-0.6, 0.6), randf_range(0.3, 0.9), randf_range(-0.6, 0.6)))
	return live


# ---------------------------------------------------------------- the Magma set (skill_tree.json skill_sets.magma)
const JETS_META := &"talent_jets_at"
const SEAM_W := 1.5
const SEAM_S := 3.0                       ## (the set's seam_life_s; Forge's own: BendLoadout.tune "set:magma.seam_life_s")
const SEAM_CAP := 4                       ## (the tick contract: one magma seam 4%)
const SEAMS_EACH := 2
const LAVA_M := 4.0
const FIST_R := 0.75
const LANDING_R := 1.0
const FORGE_MULT := 1.15
const WAVE_TAGS := ["fire_kick/kick", "fire_kick/kick.grown", "fire_kick/slam_wave"]


## How long `by`'s seams last (s): the set's, or a worn Forge's.
static func seam_life(by: Node) -> float:
	return BendLoadout.tune_f(by, "set:magma.seam_life_s", SEAM_S)


## `by`'s seams standing, the oldest first.
static func seams_of(by: Node) -> Array:
	var out: Array = []
	if by == null or not is_instance_valid(by) or not by.is_inside_tree():
		return out
	for z in by.get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.kind == "seam" and bz.owner_node == by and not bz.is_queued_for_deletion():
			out.append(bz)
	out.sort_custom(func(a: BendZone, b: BendZone) -> bool: return a.t > b.t)
	return out


## A molten seam of `by`'s (the Magma set's matter: BendZone "seam", matter/magma, 1% each 0.5 s, 4% at most, never its owner;
## jump it or step off; no slow): at `at`, its strip `way` along (spec width_m across, thick_m along; or round), seam_life s.
## His oldest past SEAMS_EACH cools at once. Water on it leaves a loose obsidian stone (seam_water), mud quenches it.
static func seam(by: Node3D, at: Vector3, way: Vector3, spec: Dictionary, lava := false) -> BendZone:
	if by == null or not is_instance_valid(by) or not NetSpells.decides():
		return null
	var mine := seams_of(by)
	while mine.size() >= SEAMS_EACH:
		(mine.pop_front() as BendZone).end("seams")
	var s := spec.duplicate()
	s["life_s"] = seam_life(by)
	s["tick_tag"] = "matter/magma"
	s["tick_cap"] = SEAM_CAP
	s["height_m"] = 0.3
	var z := matter(by, "seam", at, way, s, "fire_kick")
	if z != null:
		z.set_meta(&"talent_lava", lava)
		BendLooks.burst(at + Vector3.UP * 0.15, "fire", 22, Vector3.UP, 55.0, 3.2, 0.35)
	return z


## Seam `z` (its _every): water on it (a puddle, a spray or a water wall in it; a water bolt low over it: seam_bolt) cools it to a
## loose obsidian stone of its owner's (FormStone.make_loose: his three loose stones; any earth player's Fissure throws it on); a
## zone of mud (kind "mud", the Mud set's when it is built) quenches it, no stone.
static func seam_water(z: BendZone) -> void:
	if z.is_queued_for_deletion() or not NetSpells.decides():
		return
	var tree := z.get_tree()
	var reach := maxf(z.radius, maxf(z.size.x, z.size.z) * 0.5) + 0.3
	for o in tree.get_nodes_in_group(BendZone.GROUP):
		var oz := o as BendZone
		if oz == null or oz == z or oz.is_queued_for_deletion() or not oz.kind in ["puddle", "spray", "water_wall", "mud"]:
			continue
		if Vector2(oz.global_position.x - z.global_position.x, oz.global_position.z - z.global_position.z).length() <= reach + oz.radius * 0.5:
			_cool(z, oz.kind != "mud")
			return


## A water bolt `b` passing seam `z` (BendZone.on_bolt, each frame): low over it (WATER_ON_M: a shot onto the floor, not one
## flying over at a man's chest), it cools it to a loose obsidian stone.
const WATER_ON_M := 1.0
static func seam_bolt(z: BendZone, b: BendBolt) -> void:
	if z.is_queued_for_deletion() or not NetSpells.decides():
		return
	if b.global_position.y - z.global_position.y < WATER_ON_M and _over(z, b.global_position, 0.3):
		_cool(z, true)


## Whether `q` is over seam `z`'s ground (its strip or its round, `slack` m more), flat.
static func _over(z: BendZone, q: Vector3, slack: float) -> bool:
	var l := z.global_transform.affine_inverse() * q
	if z.round_zone:
		return Vector2(l.x, l.z).length() <= z.radius + slack
	return absf(l.x) <= z.size.x * 0.5 + slack and absf(l.z) <= z.size.z * 0.5 + slack


static func _cool(z: BendZone, stone: bool) -> void:
	var at := z.global_position
	BendLooks.burst(at + Vector3.UP * 0.4, "steam", 26, Vector3.UP, 90.0, 2.2, 0.9)
	if stone and z.is_inside_tree():
		var s := FormStone.ball(z.get_tree().current_scene, at, {"radius_m": 0.24, "mass_kg": 20.0, "rise_s": 0.01, "life_s": 30.0,
				"sink_s": 1.0}, absi(hash(Vector3i(at * 10.0))) % 97, "stone")
		s.state = FormStone.State.RESTING
		s.freeze = false
		s.set_meta(&"talent_obsidian", true)
		FormStone.make_loose(s, z.owner_node)
	z.end("cooled")


## `body`'s dash ended (BendMotion._dash_end): Magma Landing's seam where his Jets land.
static func dash_ended(body: Node) -> void:
	if not body.has_meta(JETS_META):
		return
	body.remove_meta(JETS_META)
	if body is Node3D and BendLoadout.wears(body, "fire.magma.landing"):
		seam(body as Node3D, FormEffects.ground_at(body, (body as Node3D).global_position), Vector3.FORWARD,
				{"radius_m": LANDING_R, "round": true, "width_m": LANDING_R * 1.8, "thick_m": LANDING_R * 1.8})


## Whether `body` stands on a seam of his own now (Forge's home ground: his feet on it).
static func on_own_seam(body: Node) -> bool:
	if not (body is Node3D):
		return false
	var q := (body as Node3D).global_position
	for z: BendZone in seams_of(body):
		if q.y - z.global_position.y <= BendZone.MATTER_FEET_M and _over(z, q, 0.0):
			return true
	return false


# ---------------------------------------------------------------- Cauterize (a new skill)
## The modes `body` may ready of move `id` (`ms`: the move's own): a worn Cauterize adds its mode to Patch's key (a double tap).
static func modes_for(body: Object, id: String, ms: Array) -> Array:
	if id != "patch" or not wears(body, "fire.slot.cauterize") or "cauterize" in ms:
		return ms
	return ms + ["cauterize"]


## Cauterize's own spec and ring lock (the node's numbers; kept out of moves.json: Classic's moves and their fingerprint stay
## as they are, and only a wearer readies the mode). cost_pct is never in the fresh pool; max_pct of the fresh pool comes back;
## gas within gas_m of him ends.
const CAUTERIZE := {"do": "heal", "kind": "fire", "amount": 15.0, "cauterize": true, "cost_pct": 2.0, "max_pct": 12.0, "gas_m": 1.5}
const CAUTERIZE_LOCK_S := 1.2


## A worn new skill's own spec for move `m` at `mode` ({} none): Cauterize's (FormEffects.apply, where moves.json has none).
static func own_spec(body: Object, m: String, mode: String) -> Dictionary:
	if m == "patch" and mode == "cauterize" and wears(body, "fire.slot.cauterize"):
		return CAUTERIZE.duplicate()
	return {}


## The mode a bot wearing a new skill casts a lock of (`id`, `md`) as ("" its own): a bot about to Patch with at least
## Cauterize's max_pct fresh casts Cauterize (the same % back for its cost, a shorter lock, the gas round it gone); less, Patch.
static func bot_mode(body: Node, id: String, md: String) -> String:
	if id != "patch" or md != "patch" or not wears(body, "fire.slot.cauterize"):
		return ""
	var rr := RingRules.current()
	return "cauterize" if rr != null and rr.fresh_pct(body) >= float(CAUTERIZE.max_pct) - 1e-4 else ""


## Patch's ring lock for `body` at `mode` (`base`: the move's ring_lock_s): Cauterize's own, and a worn Cauterize's trade on the
## Patch (stock:patch.lock_s 1.7 from 1.5).
static func patch_lock(body: Object, mode: String, base: float) -> float:
	if not wears(body, "fire.slot.cauterize"):
		return base
	if mode == "cauterize":
		return CAUTERIZE_LOCK_S
	return BendLoadout.tune_f(body, "stock:patch.lock_s", base)


## A worn Cauterize cast by `p` (BendEffects' heal, his own machine's): cost_pct first, outside the fresh pool (no Patch takes it
## back), then up to max_pct of the fresh pool taken back (RingRules.patch); the gas within gas_m of him ends. The % taken back.
static func cauterize(p: Node3D, spec: Dictionary) -> float:
	var rr := RingRules.current()
	if rr == null or not wears(p, "fire.slot.cauterize") or not rr.heal_allowed(p):
		return rr.patch(p) if rr != null else 0.0
	rr.add_pct_kept(p, float(spec.get("cost_pct", 2.0)))
	var took := rr.patch_up_to(p, float(spec.get("max_pct", 12.0)))
	for z in p.get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.kind == "gas" and not bz.is_queued_for_deletion() \
				and Vector2(bz.global_position.x - p.global_position.x, bz.global_position.z - p.global_position.z).length() <= float(spec.get("gas_m", 1.5)) + bz.radius:
			bz.end("cauterized")
	BendLooks.burst(p.global_position + Vector3.UP * 1.0, "fire", 26, Vector3.UP, 70.0, 1.6, 0.3)
	BendLooks.sound("fire", "cast", p.global_position + Vector3.UP, -4.0)
	return took


## Everyone (the players and the fighters, whatever their side) within `r` m of `at`, flat, as BendStatus.near lists them: a
## reaction's (it hurts everyone in it).
static func everyone_near(from: Node, at: Vector3, r: float) -> Array:
	var out: Array = []
	if from == null or not from.is_inside_tree():
		return out
	var pool: Array = from.get_tree().get_nodes_in_group(NpcFighter.GROUP).duplicate()
	for q in from.get_tree().get_nodes_in_group(&"player"):
		if not pool.has(q):
			pool.append(q)
	for n in pool:
		if not (n is Node3D) or not is_instance_valid(n):
			continue
		var q := (n as Node3D).global_position
		var d := Vector2(q.x - at.x, q.z - at.z).length()
		if d <= r and absf(q.y - at.y) < 3.0:
			out.append([n, d])
	return out


## Hold the Storm: a perfect Parry of Lightning by `who` (BendEffects._strike, the host's) with E held keeps the strike in his
## arms (the Lightning's charge on his hands) until he lets go of E or his redirect_lightning spec's s runs out; then it leaves
## along his aim at x1.2 (Lightning keeps the old factor: lightning_back_k). True: held; false: it goes back at once, as ever (E
## already let go, a bot, not worn).
static func hold_storm(who: Node, spec: Dictionary, info: Dictionary, r: float) -> bool:
	if not wears(who, "fire.parry.hold_storm") or not NetSpells.decides() or not (who is Node3D):
		return false
	var sc := SwayCaster.of(who)
	if sc == null or not sc._guard_down():
		return false
	var base: Variant = (SwayMoves.move("fire_parry").get("bend", {}) as Dictionary).get("redirect_lightning", {})
	var hs := BendLoadout.spec(who, "fire_parry", "redirect_lightning", base as Dictionary if base is Dictionary else {})
	var hold_s := float(hs.get("s", 1.0))
	var t0 := BendStatus.now()
	var ch: Node = BendLooks.charge(who as Node3D, sc)
	if ch != null:
		ch.set(&"level", 1.0)
	who.set_meta(&"talent_storm_held", t0)
	var tree := who.get_tree()
	var st := {"cb": Callable()}
	st.cb = func() -> void:
		var gone := not is_instance_valid(who)
		if not gone and sc != null and is_instance_valid(sc) and sc._guard_down() and BendStatus.now() - t0 < hold_s - 1e-4:
			return
		tree.physics_frame.disconnect(st.cb)
		if ch != null and is_instance_valid(ch):
			ch.call(&"end")
		if gone:
			return
		who.remove_meta(&"talent_storm_held")
		storm_back(who, spec, info, r)
	tree.physics_frame.connect(st.cb)
	return true


## The Lightning factor of a perfect Parry's return by `who`: x1.2 (the rule's) for a Hold the Storm wearer, whose own perfect_mult
## (x1.1) is for fire only; else `k`, the game's.
static func lightning_back_k(who: Node, k: float) -> float:
	return Bending.rule("perfect_mult", 1.2) if wears(who, "fire.parry.hold_storm") else k


## A held Lightning let go by `who`: along his aim now (BendEffects._strike's return, from his chest), x1.2.
static func storm_back(who: Node, spec: Dictionary, info: Dictionary, r: float) -> void:
	var w3 := who as Node3D
	var space := w3.get_world_3d().direct_space_state
	var bfrom := NpcSenses.chest_of(w3)
	var bto := BendZone.guard_aim(w3, bfrom)
	var bdir := (bto - bfrom).normalized()
	var wbc := BendCaster.of(who)
	var exl: Array[RID] = wbc.exclude() if wbc != null else []
	var h2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(bfrom, bfrom + bdir * r, 0xFFFFFFFF, exl))
	var end2: Vector3 = h2.position if not h2.is_empty() else bfrom + bdir * r
	SbFx.fire(who, SbFx.key_of({}, "fire_parry", "parry"), "lightning_back", {"at": bfrom, "dir": bdir})
	if not SbFx.fire(who, SbFx.key_of(spec.get("_info", {})), "strike", {"at": bfrom, "to": end2, "dir": bdir, "el": "fire"}):
		BendLooks.lightning(bfrom, end2)
	BendLooks.sound("lightning", "cast", bfrom)
	var who2 := BendBolt._taker(h2.collider as Node) if not h2.is_empty() else null
	if who2 != null and BendStatus.can_take(who2, who):
		var k := lightning_back_k(who, Bending.rule("perfect_mult", 1.2))
		var binfo := BendZone.return_info(info, who, bfrom, k)
		BendR3.deliver(who2, float(spec.get("damage", 50.0)) * k, end2, bdir, who, float(spec.get("_lock_s", -1.0)),
				Vector3(bdir.x, 0.0, bdir.z).normalized() * float(spec.get("knock_mps", 6.0)) + Vector3.UP * 2.0, binfo)


# ---------------------------------------------------------------- gas lit by fire (the Ignited Sulphur burst; Flashfire)
## Gas is the Sulphur set's matter (earth's skill set, skill_tree.json skill_sets.sulphur, built in earth's lane): a BendZone of kind
## "gas", round, its radius the cloud's. The set's "fire lights it" is built here, from fire's side, so Flashfire has its burst
## to change and earth's clouds need nothing more than to be that zone: fire meeting a cloud (a fire bolt, or an air bolt that
## took a fire wall's flame, inside it: BendZone.on_bolt; a fire cone reaching it: BendEffects.cone; a fire wall, floor fire, a
## scald or a seam touching it: the cloud's BendZone._every) burns it at once (ignite). Classic never meets gas: only a worn
## Sulphur makes it.
const GAS_KIND := "gas"
const IGNITE_TAG := "reaction/ignited_gas"
## Flashfire (fire.embers.flashfire): the burst of gas its wearer lights reaches this much farther (its class 8 and 8 is the node's
## class change, BendLoadout.hit_class; its Embers' 6 the same).
const FLASH_M := 1.0
const LIT_META := &"talent_gas_lit"
## The fire zones that light a cloud they touch.
const LIGHTING_ZONES := ["fire_wall", "burn", "seam", "scald"]


## Whether `q` is inside gas cloud `gas` (round: its radius flat, from a metre under its floor to 3.5 m over it).
static func in_gas(gas: BendZone, q: Vector3) -> bool:
	var l := gas.global_position
	return Vector2(q.x - l.x, q.z - l.z).length() <= gas.radius and q.y - l.y > -1.0 and q.y - l.y < 3.5


## The burst of gas cloud `gas` lit by `lighter`'s fire (`lit_by`: the tag of the move whose fire lit it, "" none): the cloud is
## gone, and everyone within its radius (FLASH_M more when the lighter wears Flashfire) whom the lighter may hit takes
## rules.json reaction/ignited_gas (6%, a set 6 m/s at 45 deg; Flashfire's 8 and 8 for its wearer), knocked away from its middle.
## Whoever lights it owns it, whoever made the gas: the hit is his (never on him or his side), and it stales as the move that lit
## it (info stale_as, RingRules.on_hit). It never stacks: two clouds are two bursts. The host's (NetSpells.decides). How many it
## hit, or -1 when nothing burned (no lighter, a cloud already lit).
static func ignite(gas: BendZone, lighter: Node3D, lit_by := "") -> int:
	if gas == null or not is_instance_valid(gas) or gas.kind != GAS_KIND or gas.is_queued_for_deletion() or gas.has_meta(LIT_META):
		return -1
	if lighter == null or not is_instance_valid(lighter) or not lighter.is_inside_tree() or not NetSpells.decides():
		return -1
	gas.set_meta(LIT_META, true)
	var at := gas.global_position
	var r := gas.radius + (FLASH_M if wears(lighter, "fire.embers.flashfire") else 0.0)
	gas.end("ignited")
	# (its look: the cloud bursting into flame out to its reach, a flash at its heart; its sound; nothing drawn on anyone)
	BendLooks.burst(at + Vector3.UP * 1.0, "fire", 44, Vector3.UP, 180.0, r * 2.6, 0.55, false)
	for i in 6:
		var rim := at + Vector3.FORWARD.rotated(Vector3.UP, TAU * float(i) / 6.0) * r * 0.75 + Vector3.UP * 0.4
		BendLooks.burst(rim, "fire", 10, Vector3.UP, 70.0, 3.0, 0.4, false)
	if BendLooks.live():
		var pool := BendLooks._pool()
		if pool != null:
			pool.play("flash", Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.0), 0.2, 0.5, r * 0.8, Color(1.0, 0.62, 0.22),
					Color(1.0, 0.95, 0.7))
	BendLooks.sound("fire", "hit", at + Vector3.UP, 3.0)
	var cls := BendLoadout.hit_class(lighter, RingRules.class_of(IGNITE_TAG))
	var d := float(cls.get("d", 6.0))
	var mps := float(cls.get("base", 6.0))
	var deg := float(cls.get("angle", 45.0))
	var n_hit := 0
	for e in BendCaster.near(lighter, at, r + 0.6):
		var n: Node3D = e[0]
		var q := n.global_position
		if Vector2(q.x - at.x, q.z - at.z).length() > r + 0.3 or absf(q.y - at.y) > 3.0:
			continue
		var out := Vector3(q.x - at.x, 0.0, q.z - at.z)
		if out.length_squared() < 1e-4:
			out = Vector3(q.x - lighter.global_position.x, 0.0, q.z - lighter.global_position.z)
		out = out.normalized() if out.length_squared() > 1e-4 else Vector3.FORWARD
		var info := {"tag": IGNITE_TAG, "move": lit_by.get_slice("/", 0), "from": at, "dir": out, "burst": true, "reaction": "ignited"}
		if lit_by != "":
			info["stale_as"] = lit_by
		BendR3.deliver(n, d, q + Vector3.UP * 0.9, out, lighter, -1.0, BendR3.set_v(out, mps, deg), info)
		n_hit += 1
	# (the reaction called out at the callout spot: IGNITED!, data/ring/callouts.json)
	var hl := RingHighlights.find(lighter.get_tree())
	if hl != null:
		hl.moment.emit("ignited", lighter, {"at": at, "hit": n_hit})
	return n_hit


## Bolt `b` inside gas cloud `gas` (BendZone.on_bolt, each frame): fire (or an air bolt carrying a fire wall's flame) lights it,
## the bolt's caster the lighter; it flies on.
static func gas_bolt(gas: BendZone, b: BendBolt) -> void:
	if b.spent or not (b.kind == "fire" or b.burning) or not in_gas(gas, b.global_position):
		return
	ignite(gas, b._by(), String(b.info.get("tag", "")))


## A fire cone of `p`'s (BendEffects.cone: the Breath, a jab's flame) along `flat`, `r` m and `deg` wide: each gas cloud it reaches
## burns, his.
static func gas_cone(p: Node3D, flat: Vector3, r: float, deg: float, lit_by: String) -> void:
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		return
	for z in p.get_tree().get_nodes_in_group(BendZone.GROUP):
		var g := z as BendZone
		if g == null or g.kind != GAS_KIND or g.is_queued_for_deletion():
			continue
		var to := Vector3(g.global_position.x - p.global_position.x, 0.0, g.global_position.z - p.global_position.z)
		if to.length() > r + g.radius:
			continue
		if to.length() > g.radius and deg < 360.0 and rad_to_deg(Vector3(flat.x, 0.0, flat.z).normalized().angle_to(to.normalized())) \
				> deg * 0.5 + rad_to_deg(asin(clampf(g.radius / to.length(), 0.0, 1.0))):
			continue                                  # (beside the cone: the cloud's edge outside its angle)
		ignite(g, p, lit_by)


## Gas cloud `gas`'s own look round (its _every, the host's): a fire wall, floor fire, a scald or a seam touching it lights it,
## that fire's owner the lighter.
static func gas_every(gas: BendZone) -> void:
	if gas.is_queued_for_deletion() or not NetSpells.decides():
		return
	for o in gas.get_tree().get_nodes_in_group(BendZone.GROUP):
		var oz := o as BendZone
		if oz == null or oz == gas or oz.is_queued_for_deletion() or not oz.kind in LIGHTING_ZONES:
			continue
		if _touches(gas, oz):
			# (a fire wall's cast tag; a talent's floor fire carries its tick class, no move's: it stales as itself)
			var lit_by := String(oz.info.get("tag", "")) if oz.tick_tag == "" and oz.info.get("tag") is String else ""
			ignite(gas, oz.owner_node, lit_by)
			return


## Whether fire zone `z` (a box, or round) reaches into gas cloud `gas`, flat.
static func _touches(gas: BendZone, z: BendZone) -> bool:
	var c := gas.global_position
	if z.round_zone:
		return Vector2(z.global_position.x - c.x, z.global_position.z - c.z).length() <= gas.radius + z.radius
	var l := z.global_transform.affine_inverse() * c
	var nearest := Vector2(clampf(l.x, -z.size.x * 0.5, z.size.x * 0.5), clampf(l.z, -z.size.z * 0.5, z.size.z * 0.5))
	return Vector2(l.x, l.z).distance_to(nearest) <= gas.radius and absf(l.y) < 3.5


## A bot's own reason to want option `o` more (NpcBending._choose; 1.0 none): a worn Flashfire throws its Embers at a foe `t`
## standing in gas (any cloud: whoever lights it owns it), x FLASH_BOT.
const FLASH_BOT := 2.0


static func bot_weight(me: Node, o: Dictionary, t: Node3D) -> float:
	if String(o.get("key", "")) != "fire_jab/embers" or t == null or not is_instance_valid(t) or not t.is_inside_tree() \
			or not wears(me, "fire.embers.flashfire"):
		return 1.0
	for z in t.get_tree().get_nodes_in_group(BendZone.GROUP):
		var g := z as BendZone
		if g != null and g.kind == GAS_KIND and not g.is_queued_for_deletion() and in_gas(g, t.global_position):
			return FLASH_BOT
	return 1.0
