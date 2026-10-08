class_name BendEffects
extends RefCounted
## What a bending move does when cast (docs/bending_design.md; data/sway/moves.json, a move's "bend": a spec for each of its
## modes, by "do"). FormEffects.apply hands a move's mode here when the move has a spec for it; the lock is SwayCaster's as
## for every spell (the circle at the caster's feet: "self_lock"), the aim taken at the release (aim: the crosshair, or a
## fighter near it: BendCaster.assist_target).
##   bolt        BendBolt(s) from the chest along the aim: count, every_s apart, spread_deg; mps, gravity, damage, knock_mps,
##               up_mps, radius_m, range_m, long, erode (on earth walls), root_s / slow_s on whom it strikes; low: along
##               the ground
##   throw       BendThrow: a bolt thrown like the throwables (flight point_first: a spear; spinning: a disc; flick:
##               pebbles), on the arc that lands it on the aim, launched at once (the player's strike already waited for)
##   cone, ring  whoever is within range_m in deg before the caster (a ring: all round): damage, knock (up_mps), root_s,
##               slow_s, dazzle_s (a flare: a bot dazzled, bend_dazzle_until); put_out (fire walls and burning ground in it go out), melt (ice walls in it crumble)
##   dash        the caster thrown: fwd_mps along the aim (back: behind, side: to a side; side_default: the side held, else
##               that one, 1 right: Earth Skate's slide and burrow-step), up_mps; burn: the ground left
##               alight; shove: whoever is near knocked aside
##   buff        on the caster for s: anchor (no knockback), hover / glide (a slow fall), run / scooter (a fast pace),
##               redirect_lightning (lightning that strikes is sent back)
##   zone        a BendZone (kind `zone`) at "self", "front" (ahead_m) or "aim" (range_m): barriers, the ground, guards;
##               put_out (the spray): what burns in it goes out
##   status_at   at the aim's place (radius_m): root_s, slow_s, damage, up_mps (a knock-up); hollow: a hollow left
##   lightning   from the caster's hand along the aim at once; a fighter or player guarding with redirect_lightning sends
##               it back
##   heal, cleanse, draw (a splash of water drawn up), grab (pulled to the caster), kick_up (a rock up before the caster), column (a pillar
##   under the aim's place, throwing whoever stands there), shell (walls all round), ramp (a slope), ice_wall, freeze_water
##   (a wall of water turned to ice), thaw / melt (ice gone), brace (one's wall takes the next hit free), shove (earth:
##   push, pull, split a stone or a raised wall)
## Any caster (BendCaster: the player's PlayerBendCaster, a bot's or a test's BodyBendCaster; the owner, 2026-10-04: the ring's
## bots cast the same moves as the player): every helper takes a caster or its body (untyped: BendCaster.wrap) and asks it for
## the aim, its rays, its side, its water, its chances; nothing here reads the player's own camera or keys.
## last: what the local player's last cast did (the tests, the HUD); last_of(c): any caster's (by its body); record(c, d):
## BendCast's old modes (the earth wall, Stone Form's spike and boulder, the pillar, Gust's, Mend) written there as well.
## BendCast.cast is the one entry for any caster (a bot's, a test's, the player's); FormEffects.apply hands the player's here.
## ROUND 2 (skills_r2 spec §2-§3, §8; each new key read with its safe default):
##   floor_wave  the Kick: a BendBolt along the deck from the feet, along the caster's facing (the crosshair's yaw, never its
##               pitch): width_m, height_m, miss_above_m, mps, range_m (BendBolt's floor wave)
##   throw       shape "crescent": the High Kick (BendThrow, point first, its own body)
##   wind_wave   Gust and Pull: a visible wave of wind width_m wide along the aim (no aim help), `pull` toward the caster
##   wind_wall   a standing wall of wind (BendZone "wind_wall") 2-6 m where the crosshair is, one at a time
##   spout       the Geyser: low at once, its throw at rise_s; over a grate or the caster's own puddle source_mult bigger
##   column      rise_s (it starts low; the throw then), sink_s (it sinks after, never a wall)
##   lightning   flash_s: the flash and crack on the hand at the release, the strike that long after along that line
##   dash        dir "held" (none: back), by_pitch (Jets), under_s (Burrow), glide (Leap); an air dash's end charges
##               Carried wind (BendMotion)
##   shove       the held stone, else the crosshair's loose stone within shove_loose_m or a wall's chunk, else kick-and-push
##   cone        a guard's share (BendZone.cone_mult); smoke_s (Breath) leaves smoke where it burned
##   zones       `place` (2-6 m at the crosshair, facing the caster), one_at_a_time (fire and wind walls)
##   any spec    grow (merged when the lock grew: BendCaster.grown), carry (Carried wind x knock_mult), weight (stone vs
##               stone), steer (water's Flowing); root_s and slow_s never land on
##               one who casts as an element (BendStatus); the move's lock time on all it sends (`_lock_s`: a hit's cost)
## ROUND 3 (smash_r3 spec §2.1, §6, §14.3; AIR; BendR3):
##   hit info    every cast's info (BendR3.info_for: tag "id/mode" (+ ".grown"), from, air, a jab's mark, set_stun) in its spec
##               (`_info`) and in BendR3.cur while its things are made; a volley's (count > 1: Pebbles, Embers) volley_id and
##               volley_n; every hit lands through BendR3.deliver (hurt then knock, one info)
##   "as"        a hidden mode standing for another (the Pop's jab, the air High Kick: resolved)
##   slam        the Slam (key 2 in the air): a column under the caster leaning to the aim's yaw, out active_s, -70 deg,
##               bounce_once on a grounded body; held_stone, put_out and puddle, wave, self_lift_mps (Hammer, Downpour, Axe
##               Kick, Down Gust)
##   air_hit     the element's close air hit (LMB in the air): a ball reach_m along the aim, a set knock, its set_stun
##   the shield  in the % ring a guard of the one a cone, a Column or Geyser, the Slam or the air hit reaches stops it on the
##               beat and halves it late (BendZone.guard_take); Lightning only fire's Parry on the beat (lightning_guard)
##   the deck    Column and Geyser kept on the deck (never from the tank's water); Patch takes RingRules.patch; the dash's
##               up speeds x RingMoves.profile().self_up_mult and no Leap glide in the ring; one Breath smoke a caster

const FormMatter := preload("res://scripts/sway/form_matter.gd")

## What the local player's last cast did (the tests): {do, mode, ...}. Only his (is_local): a bot's casts never write it.
static var last := {}
## Every caster's last cast, by its body's instance id (last_of).
static var _lasts := {}
## The cast being done now (its helpers add to it: hit, zone, stone, ...): the same dictionary as last_of(its caster).
static var _cur := {}


## What caster `c`'s last cast did (a BendCaster, a SwayCaster or a body; {} none).
static func last_of(c: Variant) -> Dictionary:
	var bc := BendCaster.wrap(c)
	if bc == null or bc.body == null:
		return {}
	return _lasts.get(bc.body.get_instance_id(), {})


## What caster `c` (any: BendCaster.wrap) just cast, kept as its last (last_of) and, the local player's, as `last`: BendCast's
## old modes.
static func record(c: Variant, d: Dictionary) -> void:
	var bc := BendCaster.wrap(c)
	if bc != null:
		_record(bc, d)


static func _record(bc: BendCaster, d: Dictionary) -> void:
	_cur = d
	if bc.body != null:
		_lasts[bc.body.get_instance_id()] = d
	if bc.is_local():
		last = d


## The body of caster `c` (a BendCaster, a SwayCaster, a body); null none.
static func _body(c: Variant) -> CharacterBody3D:
	var bc := BendCaster.wrap(c)
	return bc.body if bc != null and bc.valid() else null


## Caster `c` (a BendCaster, a SwayCaster: FormEffects.apply's, or a body) casts move `m`'s `mode` of `spec` (_t, _at: the
## lock's target and point, kept for the old callers; the aim is the caster's own at the release).
## Round 2 (see the header): the spec's grow merged when the caster's lock grew (BendCaster.grown); Carried wind on a carry
## spec; E's catch with a stone held throws it back (BendZone.return_stone);
## its lock time written on what it sends (`_lock_s`: what a hit with it costs); the element's jab (Bending.jab) reaches
## jab_max_m at most.
static func apply(c: Variant, m: String, mode: String, spec: Dictionary, _t: Node3D = null, _at := Vector3.INF) -> void:
	var bc := BendCaster.wrap(c)
	if bc == null or not bc.valid():
		return
	spec = resolved(m, spec)
	var grew := bc.grown and spec.get("grow") is Dictionary
	if grew:
		spec.merge(spec.grow as Dictionary, true)
	# (round 3: the hit info every hit of this cast carries, and the cast's own while its things are made; BendR3)
	var info := BendR3.info_for(bc, m, mode, grew, spec)
	if int(spec.get("count", 1)) > 1 and String(spec.get("do", "")) in ["bolt", "throw"]:
		info["volley_id"] = BendR3.new_volley()
		info["volley_n"] = int(spec.count)
	spec["_info"] = info
	var keep := BendR3.cur
	BendR3.cur = info
	if bool(info.get("jab", false)) and BendR3.stock():
		BendR3.jab_cast(bc)
	_apply(bc, m, mode, spec, grew)
	BendR3.cur = keep


## Spec `spec` of move `m` with its "as" (a hidden mode standing for another: the Pop's jab, the air High Kick) resolved:
## the named mode's spec with this one's own keys over it. A copy.
static func resolved(m: String, spec: Dictionary) -> Dictionary:
	if not spec.has("as"):
		return spec.duplicate()
	var b: Variant = SwayMoves.move(m).get("bend", {})
	var base: Variant = (b as Dictionary).get(String(spec.as)) if b is Dictionary else null
	var out: Dictionary = (base as Dictionary).duplicate() if base is Dictionary else {}
	for k: String in spec:
		if k != "as":
			out[k] = spec[k]
	out.erase("air")
	return out


static func _apply(bc: BendCaster, m: String, mode: String, spec: Dictionary, grew: bool) -> void:
	var p := bc.body
	spec["_lock_s"] = lock_of(m, mode)
	if BendR3.is_jab(m, mode) and Bending.element_of(m) == BendPoses.element_of(p) and spec.has("range_m"):
		# (the element's jab: the close poke, jab_max_m at most whatever its spec says; spec §2.1)
		spec["range_m"] = minf(float(spec.range_m), Bending.rule("jab_max_m", 10.0))
	var carried := false
	if bool(spec.get("carry", false)) and BendStatus.until(p, &"bend_carry_until") > 0.0:
		# (Carried wind: a hit straight out of a dash knocks harder; spent on this cast)
		var k := float(Bending.passive("air").get("knock_mult", 1.15))
		spec["knock_mps"] = float(spec.get("knock_mps", 0.0)) * k
		p.remove_meta(&"bend_carry_until")
		carried = true
	if String(spec.get("do", "")) == "zone" and String(spec.get("zone", "")) == "catch" and BendStatus.element_mode(p):
		var held := BendZone.held_stone(p)
		if held != null:
			# (E again with a caught stone held: thrown back along the aim; spec §2.6)
			var a0 := aim(bc, spec)
			_record(bc, {"do": "return", "mode": mode, "move": m, "aim": a0.point, "grown": grew})
			_cur["throw"] = BendZone.return_stone(bc, held)
			_cur["stone"] = held
			return
	var a := aim(bc, spec)
	_record(bc, {"do": String(spec.get("do", "")), "mode": mode, "move": m, "aim": a.point, "grown": grew, "carried": carried,
			"spec": spec})
	var kind := String(spec.get("kind", "stone"))
	BendLooks.sound(kind, "cast", p.global_position + Vector3.UP, -4.0)
	MonsoonIdentity.release(p, Bending.element_of(m), mode == "big" or grew)
	match String(spec.get("do", "")):
		"bolt":
			bolts(bc, a, spec)
		"throw":
			_cur["bolt"] = BendThrow.throw(bc, a, spec)
		"floor_wave":
			_cur["bolt"] = floor_wave(bc, a, spec)
		"wind_wave":
			_cur["bolt"] = wind_wave(bc, a, spec)
		"cone":
			cone(p, a.from, a.flat, spec)
		"ring":
			cone(p, p.global_position + Vector3.UP, a.flat, spec, true)
		"dash":
			dash(bc, a.flat, spec)
		"buff":
			buff(bc, spec)
		"zone":
			zone(bc, a, spec)
		"wind_wall":
			var ws := spec.duplicate()
			ws["zone"] = "wind_wall"
			if not ws.has("at"):
				ws["at"] = "place"
			zone(bc, a, ws)
		"status_at":
			status_at(p, _ground_at(p, a, spec), spec)
		"spout":
			spout(bc, _deck_at(p, _ground_at(p, a, spec)), spec)
		"lightning":
			lightning(bc, a, spec)
		"heal":
			var rr := RingRules.current()
			if m == "patch" and BendR3.on(p) and rr != null:
				_cur["patched"] = rr.patch(p)         # (round 3, spec §8: the fresh pool taken back, never health)
			else:
				BendStatus.heal(p, float(spec.get("amount", 15.0)))
			BendLooks.burst(p.global_position + Vector3.UP, "water" if kind == "water" else "air", 20, Vector3.UP, 60.0, 1.5)
		"cleanse":
			for k: StringName in [&"bend_root", &"bend_slow"]:
				if p.has_meta(k):
					p.set_meta(k, 0.0)
					BendStatus._end_timed(p, k, 0.0 if k == &"bend_root" else BendStatus.SLOW_MPS)
			BendLooks.burst(p.global_position + Vector3.UP, "water", 18)
		"draw":
			BendLooks.burst(p.global_position + Vector3.UP * 0.5, "water", 24, Vector3.UP, 40.0, 3.0)
		"grab":
			grab(bc, a, spec)
		"kick_up":
			kick_up(bc, a.flat, spec)
		"column":
			column(bc, _deck_at(p, _ground_at(p, a, spec)), spec)
		"slam":
			_cur["slam"] = slam(bc, a, spec)
		"air_hit":
			_cur["air_hit"] = air_hit(bc, a, spec)
		"shell":
			shell(bc, spec)
		"ramp":
			ramp(bc, a.flat)
		"ice_wall":
			ice_wall(bc, a.flat, spec)
		"freeze_water":
			freeze_water(bc, _ground_at(p, a, spec), a.flat)
		"thaw":
			melt(p, _ground_at(p, a, spec), 6.0)
		"melt":
			melt(p, p.global_position, float(spec.get("radius_m", 6.0)))
		"brace":
			brace(bc, float(spec.get("range_m", 12.0)))
		"shove":
			shove(bc, a, String(spec.get("how", "push")), spec)


## Move `m`'s lock time at `mode` (s; its mode_lock_s, else its lock_s): what a hit with it costs the struck one's lock.
static func lock_of(m: String, mode: String) -> float:
	var d := SwayMoves.move(m)
	if d.is_empty():
		return -1.0
	var mlk: Variant = d.get("mode_lock_s", {})
	if mlk is Dictionary and (mlk as Dictionary).has(mode):
		return float(mlk[mode])
	return float(d.get("lock_s", -1.0))


# ---------------------------------------------------------------- the aim
## Caster `c`'s aim now: {from (where a bolt leaves: BendCaster.launch_point), dir (to the point), flat (level), point (the
## caster's aim_point, or its target's: target_point, led for a bolt of spec.mps), target (aim_target)}.
static func aim(c: Variant, spec := {}) -> Dictionary:
	var bc := BendCaster.wrap(c)
	var p := bc.body
	var chest := bc.chest()
	var point := bc.aim_point()
	var target := bc.aim_target()
	if target != null:
		point = bc.target_point(target, float(spec.get("mps", 0.0)))
	if point == Vector3.INF:
		point = chest - p.global_basis.z * 20.0
	var flat := point - p.global_position
	flat.y = 0.0
	flat = flat.normalized() if flat.length_squared() > 1e-4 else -p.global_basis.z
	var from := bc.launch_point(flat)
	return {"from": from, "dir": (point - from).normalized(), "flat": flat, "point": point, "target": target}


## The ground at the aim's place, no further than spec.range_m from the caster.
static func _ground_at(p: Node3D, a: Dictionary, spec: Dictionary) -> Vector3:
	var pt: Vector3 = a.point
	var r := float(spec.get("range_m", 20.0))
	var v := pt - p.global_position
	v.y = 0.0
	if v.length() > r:
		pt = p.global_position + v.normalized() * r
	return FormEffects.ground_at(p, pt)


# ---------------------------------------------------------------- the kinds
## Bolts from the caster along aim `a` (a stream's later ones along its aim again then: they follow the target). A water
## fighter's water bolts take Flowing's steer (Bending.passive("water"): BendBolt's steer).
static func bolts(c: Variant, a: Dictionary, spec: Dictionary) -> void:
	var bc := BendCaster.wrap(c)
	if bc == null:
		return
	var p := bc.body
	var n := int(spec.get("count", 1))
	var every := float(spec.get("every_s", 0.0))
	var spread := deg_to_rad(float(spec.get("spread_deg", 0.0)))
	var low := bool(spec.get("low", false))
	if String(spec.get("kind", "")) == "water" and BendPoses.element_of(p) == "water" and not spec.has("steer_dps"):
		var pv := Bending.passive("water")
		spec = spec.duplicate()
		spec["steer_dps"] = float(pv.get("steer_dps", 45.0))
		spec["steer_max_deg"] = float(pv.get("steer_max_deg", 15.0))
		spec["steer_s"] = float(pv.get("steer_s", 0.25))
	for i in n:
		var fire := func() -> void:
			if not bc.valid():
				return
			var a2 := a
			if every > 0.0 and i > 0:
				a2 = aim(bc, spec)
			var dir: Vector3 = a2.dir
			if low:
				dir = Vector3(a2.flat.x, -0.02, a2.flat.z).normalized()
			if spread > 0.0 and n > 1:
				var off := (float(i) - float(n - 1) * 0.5) / maxf(float(n - 1) * 0.5, 1.0)
				dir = dir.rotated(Vector3.UP, off * spread + bc.rand_range(-0.2, 0.2) * spread)
				dir = dir.rotated(dir.cross(Vector3.UP).normalized(), bc.rand_range(-0.5, 0.5) * spread)
			var from: Vector3 = a2.from
			if low:
				from = Vector3(from.x, p.global_position.y + 0.45, from.z)
			BendBolt.launch(p, from, dir, spec)
		if every > 0.0 and i > 0:
			p.get_tree().create_timer(every * i, false).timeout.connect(fire)
		else:
			fire.call()


## The Kick (spec do "floor_wave"; skills_r2 spec §3.3): a wave of fire along the deck from the caster's feet along the
## crosshair's YAW (his facing: never its pitch; a bot's toward its pick), BendBolt's floor wave (it widens from the foot,
## jumped by feet over miss_above_m, stopped by any wall). The bolt.
static func floor_wave(c: Variant, _a: Dictionary, spec: Dictionary) -> BendBolt:
	var bc := BendCaster.wrap(c)
	if bc == null or not bc.valid():
		return null
	var p := bc.body
	var dir := bc.facing()
	var s := spec.duplicate()
	s["kind"] = String(spec.get("kind", "fire"))
	s["mps"] = float(spec.get("mps", 18.0))
	s["range_m"] = float(spec.get("range_m", 16.0))
	var b := BendBolt.launch(p, p.global_position + dir * 0.7, dir, s)
	BendSounds.play(&"fire_crackle", p.global_position, 0.0)
	return b


## Air's Gust and Pull (spec do "wind_wave"; §3.4): a visible wave of wind width_m wide (2 m) going out along the aim at
## mps (18 m/s), range_m; never locked on a man (the aim's own line, no aim help) and never at once. `pull`: whom it meets
## is knocked toward the caster. The bolt (kind air).
static func wind_wave(c: Variant, a: Dictionary, spec: Dictionary) -> BendBolt:
	var bc := BendCaster.wrap(c)
	if bc == null or not bc.valid():
		return null
	var p := bc.body
	var s := spec.duplicate()
	s["kind"] = "air"
	s["long"] = true
	s["radius_m"] = float(spec.get("width_m", 2.0)) * 0.5
	s["mps"] = float(spec.get("mps", 18.0))
	s["range_m"] = float(spec.get("range_m", 14.0))
	var point := bc.aim_point()
	var from: Vector3 = a.from
	var dir: Vector3 = (point - from).normalized() if point.is_finite() and point.distance_to(from) > 0.5 else (a.dir as Vector3)
	return BendBolt.launch(p, from, dir, s)


## A cone (or, `ring`, all round) before the caster from `from` along `flat`. A guard of the one it reaches takes its share
## (BendZone.cone_mult: a Turn on the beat parts a Wave round him; late, half). `smoke_s` (Breath): a smoke screen left where
## it burned (it hides from a bot; no slow).
static func cone(p: Node3D, from: Vector3, flat: Vector3, spec: Dictionary, ring := false) -> void:
	var r := float(spec.get("radius_m", spec.get("range_m", 5.0)))
	var deg := 360.0 if ring else float(spec.get("deg", 60.0))
	var kind := String(spec.get("kind", "air"))
	var info: Dictionary = spec.get("_info", {})
	var hit := 0
	for e in BendCaster.near(p, p.global_position, r):
		var n: Node3D = e[0]
		var to := n.global_position - p.global_position
		to.y = 0.0
		if not ring and to.length() > 0.3 and rad_to_deg(to.normalized().angle_to(flat)) > deg * 0.5:
			continue
		var inf := info
		var gm := 1.0
		if BendR3.stock():
			# (round 3: every guard a shield, spec §2.5: perfect nothing, late half as a slide)
			var g := BendZone.guard_take(n, kind, p, info)
			if String(g.result) == "perfect":
				continue
			gm = float(g.mult)
			inf = g.info
		else:
			gm = BendZone.cone_mult(n, kind)
			if gm <= 0.0:
				continue                          # (parted round him on the beat)
		var away := to.normalized() if to.length_squared() > 1e-4 else flat
		BendR3.deliver(n, float(spec.get("damage", 0.0)) * gm, n.global_position + Vector3.UP, away, p, float(spec.get("_lock_s", -1.0)),
				(away * float(spec.get("knock_mps", 0.0)) + Vector3.UP * float(spec.get("up_mps", 0.0))) * gm, inf)
		if float(spec.get("root_s", 0.0)) > 0.0:
			BendStatus.root(n, float(spec.root_s))
		if float(spec.get("slow_s", 0.0)) > 0.0:
			BendStatus.slow(n, float(spec.slow_s))
		if float(spec.get("dazzle_s", 0.0)) > 0.0:
			# (a flare's flash: a bot so dazzled aims wider and answers later, NpcBendCaster.dazzled)
			n.set_meta(&"bend_dazzle_until", BendStatus.now() + float(spec.dazzle_s))
		hit += 1
	_cur["hit"] = hit
	if bool(spec.get("put_out", false)) or bool(spec.get("melt", false)):
		for z in p.get_tree().get_nodes_in_group(BendZone.GROUP):
			var bz := z as BendZone
			var to := bz.global_position - p.global_position
			if to.length() > r + 2.0:
				continue
			if bool(spec.get("put_out", false)) and bz.kind in ["fire_wall", "burn"]:
				BendLooks.burst(bz.global_position + Vector3.UP, "steam", 30, Vector3.UP, 90.0, 2.5, 1.0)
				bz.end()
			if bool(spec.get("melt", false)) and bz.kind == "ice_patch":
				bz.end()
		if bool(spec.get("melt", false)):
			melt(p, p.global_position + flat * r * 0.5, r * 0.7)
	if float(spec.get("smoke_s", 0.0)) > 0.0 and not ring:
		# (Breath: the smoke where it burned, a screen a bot cannot see through)
		var at := FormEffects.ground_at(p, p.global_position + flat * r * 0.6)
		if BendR3.on(p):
			# (round 3: one smoke a caster at a time, the older one cleared: a fire player can't keep a bot blind forever)
			for z in p.get_tree().get_nodes_in_group(BendZone.GROUP):
				var oz := z as BendZone
				if oz != null and oz.kind == "smoke" and oz.owner_node == p and not oz.is_queued_for_deletion():
					oz.end()
		_cur["smoke"] = BendZone.make(p, "smoke", at, {"radius_m": maxf(r * 0.45, 1.5), "life_s": float(spec.smoke_s)}, flat)
	BendLooks.blast(p.global_position + Vector3.UP * 1.1, flat, deg, r, kind)


## The caster thrown along `flat` (back: behind; side: to its side_sign's side, the player's keys or a bot's own: no keys read
## for a bot). Round 2 (spec §3, the dashes):
##   dir "held"   the way the move keys hold at the release (BendCaster.held_move: the player's W/A/S/D, a bot's dash_dir):
##                forward, back or to a side; nothing held: spec.none ("back": never by chance). A spec's "fwd", "back" or
##                "side" dictionary sets that way's own fwd_mps / up_mps (Step's hop, back-flip and step-in)
##   by_pitch     Jets: aimed level or down a flat jet dash at fwd_mps; up, a jet jump whose height follows the pitch (up to
##                up_max_mps at pitch_full_deg)
##   under_s      Burrow: stones pass over the caster that long (meta bend_under_until)
##   glide        Leap: {fall_mps, s}: a slow fall while jump is held (BendMotion.glide)
## An air fighter's dash charges Carried wind at its end (BendMotion), a Slip (a low air dash) its near misses too.
static func dash(c: Variant, flat: Vector3, spec: Dictionary) -> void:
	var bc := BendCaster.wrap(c)
	if bc == null:
		return
	var p := bc.body
	var dir := flat
	var fwd := float(spec.get("fwd_mps", 10.0))
	var up := float(spec.get("up_mps", 0.0))
	var how := ""
	if String(spec.get("dir", "")) == "held":
		var hv := bc.held_move()
		var right := flat.cross(Vector3.UP).normalized()
		if hv.length() < 0.3:
			how = String(spec.get("none", "back"))
		elif absf(hv.y) >= absf(hv.x):
			how = "fwd" if hv.y > 0.0 else "back"
		else:
			how = "side"
		match how:
			"fwd":
				dir = flat
			"back":
				dir = -flat
			"side":
				dir = right * (signf(hv.x) if absf(hv.x) > 0.01 else 1.0)
		var sub: Variant = spec.get(how)
		if sub is Dictionary:
			fwd = float((sub as Dictionary).get("fwd_mps", fwd))
			up = float((sub as Dictionary).get("up_mps", up))
	elif bool(spec.get("by_pitch", false)):
		var ad: Vector3 = aim(bc, spec).dir
		var pitch := rad_to_deg(asin(clampf(ad.y, -1.0, 1.0)))
		var k := clampf(pitch / maxf(float(spec.get("pitch_full_deg", 45.0)), 1.0), 0.0, 1.0)
		up = lerpf(up, float(spec.get("up_max_mps", 10.0)), k)
		fwd *= 1.0 - 0.65 * k
		how = "up" if k > 0.0 else "flat"
	elif bool(spec.get("back", false)):
		dir = -flat
	elif bool(spec.get("side", false)):
		var right := flat.cross(Vector3.UP).normalized()
		var s := 0.0
		if not spec.has("side_default"):
			s = bc.side_sign()
		else:
			# (Earth Skate's slide and burrow-step: the side held, else this one; a bot's own pick as ever: held_side)
			s = bc.held_side()
			if absf(s) < 0.01:
				s = signf(float(spec.side_default)) if absf(float(spec.side_default)) > 0.01 else 1.0
		dir = right * s
	var kind := String(spec.get("kind", "air"))
	var rm := RingMoves.of(p)
	if rm != null:
		up *= float(rm.profile().get("self_up_mult", 1.0))      # (round 3: the ring's gravity, the same heights: MOVE's profile)
	var v := dir * fwd + Vector3.UP * up
	p.velocity = Vector3(v.x, maxf(p.velocity.y, 0.0) + v.y, v.z)
	_cur["v"] = v
	_cur["how"] = how
	var bm := BendMotion.of(p)
	bm.carry(dir * fwd, 0.25)
	bm.dash_began(up)
	if float(spec.get("under_s", 0.0)) > 0.0:
		p.set_meta(&"bend_under_until", BendStatus.now() + float(spec.under_s))
	if kind == "air" and up < 2.0 and BendPoses.element_of(p) == "air":
		p.set_meta(&"bend_slip_until", BendStatus.now() + 0.4)       # (a Slip: a near miss in it charges Carried wind)
	var gl: Variant = spec.get("glide")
	if gl is Dictionary and rm == null:            # (round 3: Leap's glide is off in the % ring)
		bm.glide(float((gl as Dictionary).get("fall_mps", 2.5)), float((gl as Dictionary).get("s", 3.0)), bc.jump_held)
	BendLooks.burst(p.global_position + Vector3.UP * 0.3, "stone" if bool(spec.get("dust", false)) else kind, 22, -dir + Vector3.UP * 0.3, 50.0, 4.0, 0.4)
	if bool(spec.get("burn", false)):
		var start := p.global_position
		BendZone.make(p, "burn", start + dir * 3.0, {"width_m": 1.4, "height_m": 0.4, "thick_m": 6.0, "life_s": 3.0, "damage_s": 10.0}, dir)
	if bool(spec.get("shove", false)):
		for e in BendCaster.near(p, p.global_position + dir * 2.0, 3.0):
			var n: Node3D = e[0]
			var side := (n.global_position - p.global_position).cross(Vector3.UP).normalized()
			BendR3.deliver(n, 0.0, n.global_position, side, p, -1.0, side * 6.0 + Vector3.UP * 1.0, spec.get("_info", {}))


static func buff(c: Variant, spec: Dictionary) -> void:
	var p := _body(c)
	if p == null:
		return
	var s := float(spec.get("s", 2.0))
	var kind := String(spec.get("kind", "air"))
	match String(spec.get("buff", "")):
		"anchor":
			BendStatus.anchor(p, s)
			BendLooks.burst(p.global_position, "stone", 16, Vector3.UP, 70.0, 2.0)
		"hover", "glide":
			BendMotion.of(p).fall(float(spec.get("fall_mps", 2.0)), s, kind)
		"run", "scooter":
			BendMotion.of(p).run(float(spec.get("mps", 10.0)), s, kind)
		"redirect_lightning":
			p.set_meta(&"bend_redirect_lightning", BendStatus.now() + s)
			BendLooks.burst(p.global_position + Vector3.UP * 1.2, "lightning", 10, Vector3.UP, 180.0, 1.0, 0.2)


## A BendZone of spec.zone at the caster ("self"), before it ("front", ahead_m), at the aim ("aim") or, round 2's walls,
## where the crosshair is 2-6 m off ("place", or any spec with `place`: FormEffects.place_point), facing the caster.
## put_out (the spray): the fire walls, burning ground, campfires and torches in it go out, and fire that comes into it while
## it stands. `one_at_a_time` (a fire wall, a wind wall): the caster's standing one of its kind ends first.
static func zone(c: Variant, a: Dictionary, spec: Dictionary) -> BendZone:
	var p := _body(c)
	if p == null:
		return null
	var where := String(spec.get("at", "self"))
	if spec.has("place") and where != "self":
		where = "place"
	var at := p.global_position
	var way: Vector3 = a.flat
	match where:
		"front":
			at = FormEffects.ground_at(p, p.global_position + (a.flat as Vector3) * float(spec.get("ahead_m", 2.0)))
		"aim":
			at = _ground_at(p, a, spec)
		"place":
			at = FormEffects.place_point(c, spec.get("place", {}))
			way = FormEffects.way_to(c, at)
	var zk := String(spec.get("zone", "bubble"))
	if bool(spec.get("one_at_a_time", false)) or (zk in ["fire_wall", "wind_wall"] and BendStatus.element_mode(p)):
		for z in p.get_tree().get_nodes_in_group(BendZone.GROUP):
			var old := z as BendZone
			if old != null and old.kind == zk and old.owner_node == p:
				old.end()
	var z := BendZone.make(p, zk, at, spec, way)
	_cur["zone"] = z
	_cur["zone_kind"] = z.kind
	if z.put_out:
		_cur["put_out"] = z.put_out_fires()
	return z


static func status_at(p: Node3D, at: Vector3, spec: Dictionary) -> void:
	var r := float(spec.get("radius_m", 1.5))
	var kind := String(spec.get("kind", "stone"))
	var info: Dictionary = spec.get("_info", {})
	var n_hit := 0
	for e in BendCaster.near(p, at, r):
		var n: Node3D = e[0]
		var k := 1.0
		var inf := info
		if BendR3.stock():
			var g := BendZone.guard_take(n, kind, p, info)
			if String(g.result) == "perfect":
				continue
			k = float(g.mult)
			inf = g.info
		BendR3.deliver(n, float(spec.get("damage", 0.0)) * k, n.global_position + Vector3.UP * 0.3, Vector3.UP, p,
				float(spec.get("_lock_s", -1.0)), Vector3.UP * float(spec.get("up_mps", 0.0)) * k, inf)
		if float(spec.get("root_s", 0.0)) > 0.0:
			BendStatus.root(n, float(spec.root_s))
		if float(spec.get("slow_s", 0.0)) > 0.0:
			BendStatus.slow(n, float(spec.slow_s))
		n_hit += 1
	_cur["hit"] = n_hit
	BendLooks.burst(at + Vector3.UP * 0.1, kind, 26, Vector3.UP, 50.0, 4.0 if float(spec.get("up_mps", 0.0)) > 0.0 else 2.0, 0.4)
	if bool(spec.get("hollow", false)):
		FormHollow.dig(p.get_tree().current_scene, at, Vector3.FORWARD, r * 2.0, r * 2.0, 20.0)
	BendLooks.sound(kind, "hit", at, -3.0)


## The Geyser (spec do "spout"; §3.2): a column of water rising at `at` (the aim's ground, range_m), low and weak at first
## and at its peak rise_s later, when it throws whoever stands there up (up_mps, damage; status_at). Over a grate or the
## caster's own puddle within source_m (Bending.POOLS) it is source_mult wider and a third of that higher. No mark on the
## deck: the rising water is the tell.
static func spout(c: Variant, at: Vector3, spec: Dictionary) -> void:
	var bc := BendCaster.wrap(c)
	if bc == null or not bc.valid():
		return
	var p := bc.body
	var s := spec.duplicate()
	s["kind"] = String(spec.get("kind", "water"))
	if _source_near(p, at, float(spec.get("source_m", 2.5))):
		var k := float(spec.get("source_mult", 2.0))
		s["radius_m"] = float(spec.get("radius_m", 1.8)) * k
		s["up_mps"] = float(spec.get("up_mps", 12.0)) * (1.0 + (k - 1.0) / 3.0)
		_cur["source"] = true
	var rise := float(spec.get("rise_s", 0.35))
	BendLooks.spout(at, float(s.get("radius_m", 1.8)), rise)
	var rec := _cur
	if rise <= 0.0:
		status_at(p, at, s)
		return
	p.get_tree().create_timer(rise, false).timeout.connect(func() -> void:
		if not is_instance_valid(p) or not p.is_inside_tree():
			return
		var keep := _cur
		_cur = rec
		status_at(p, at, s)
		_cur = keep)


## A source for a Geyser within `r` of `at`: a pool (Bending.POOLS: the ring's grates within their reach_m) or a puddle of
## `p`'s own.
static func _source_near(p: Node3D, at: Vector3, r: float) -> bool:
	for n in p.get_tree().get_nodes_in_group(Bending.POOLS):
		var n3 := n as Node3D
		if n3 == null:
			continue
		if n3 is BendZone:
			if (n3 as BendZone).owner_node == p and n3.global_position.distance_to(at) <= r + (n3 as BendZone).radius:
				return true
			continue
		var reach := float(n3.get_meta(&"reach_m")) if n3.has_meta(&"reach_m") else 0.0
		if Vector2(n3.global_position.x - at.x, n3.global_position.z - at.z).length() <= r + reach:
			return true
	return false


## From the caster's hand along the aim (its own bodies left out of the ray: BendCaster.exclude). Round 2's `flash_s`
## (§3.3): the flash and crack on the caster's hand at the release, and the strike flash_s later along the line he had
## then (a man who moves off it on the flash is missed). Its target's Parry within its first perfect_s as it strikes sends it
## back along his aim (BendZone.lightning_back); the open world's redirect_lightning buff as before.
static func lightning(c: Variant, a: Dictionary, spec: Dictionary) -> void:
	var bc := BendCaster.wrap(c)
	if bc == null:
		return
	var flash := float(spec.get("flash_s", 0.0))
	var rec := _cur
	if flash > 0.0:
		BendLooks.lightning_flash(bc.body, a.from)
		BendSounds.play(&"lightning_crack", a.from, 0.0)
		rec["flash_s"] = flash
		rec["hit"] = 0
		var from: Vector3 = a.from
		var dir: Vector3 = a.dir
		var flat: Vector3 = a.flat
		bc.body.get_tree().create_timer(flash, false).timeout.connect(func() -> void:
			if bc.valid():
				_strike(bc, from, dir, flat, spec, rec))
		return
	_strike(bc, a.from, a.dir, a.flat, spec, rec)


## The lightning's strike from `from` along `dir` (see lightning), written into `rec` (its cast's record): hit, redirected,
## struck_at.
static func _strike(bc: BendCaster, from: Vector3, dir: Vector3, flat: Vector3, spec: Dictionary, rec: Dictionary) -> void:
	var p := bc.body
	var r := float(spec.get("range_m", 45.0))
	var space := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * r, 0xFFFFFFFF, bc.exclude())
	var h := space.intersect_ray(q)
	var end: Vector3 = h.position if not h.is_empty() else from + dir * r
	BendLooks.lightning(from, end)
	BendLooks.sound("lightning", "cast", from)
	var who := BendBolt._taker(h.collider as Node) if not h.is_empty() else null
	rec["hit"] = 0
	rec["struck_at"] = BendStatus.now()
	if who == null or not BendStatus.can_take(who, p):
		return
	var info: Dictionary = spec.get("_info", {})
	var late_k := 1.0
	var back: BendZone = null
	if BendR3.stock():
		# (round 3, spec §2.5: only fire's Parry on the beat sends it back; any other guard, or a late Parry, takes it late)
		var lg := BendZone.lightning_guard(who, p, info)
		back = lg.zone if String(lg.result) == "back" else null
		if String(lg.result) == "late":
			late_k = float(lg.mult)
			info = lg.info
	else:
		back = BendZone.lightning_back(who)
	if back != null:
		# (a Parry on the beat: back along the parrier's aim, his now)
		var bfrom := NpcSenses.chest_of(who)
		var bto := BendZone.guard_aim(who as Node3D, bfrom)
		var bdir := (bto - bfrom).normalized()
		var exl: Array[RID] = []
		var wbc := BendCaster.of(who)
		if wbc != null:
			exl = wbc.exclude()
		var h2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(bfrom, bfrom + bdir * r, 0xFFFFFFFF, exl))
		var end2: Vector3 = h2.position if not h2.is_empty() else bfrom + bdir * r
		BendLooks.lightning(bfrom, end2)
		var who2 := BendBolt._taker(h2.collider as Node) if not h2.is_empty() else null
		rec["redirected"] = true
		if who2 != null and BendStatus.can_take(who2, who):
			var k := Bending.rule("perfect_mult", 1.2)
			var binfo := BendZone.return_info(info, who, bfrom, k)
			BendR3.deliver(who2, float(spec.get("damage", 50.0)) * k, end2, bdir, who, float(spec.get("_lock_s", -1.0)),
					Vector3(bdir.x, 0.0, bdir.z).normalized() * float(spec.get("knock_mps", 6.0)) + Vector3.UP * 2.0, binfo)
			rec["back_hit"] = who2
		return
	if BendStatus.until(who, &"bend_redirect_lightning") > 0.0:
		# (sent back: it strikes its caster)
		var back_at := (who as Node3D).global_position + Vector3.UP * 1.3
		BendLooks.lightning(back_at, p.global_position + Vector3.UP * 1.3)
		BendStatus.hurt(p, float(spec.get("damage", 50.0)), p.global_position + Vector3.UP, -dir, who)
		rec["redirected"] = true
		return
	BendR3.deliver(who, float(spec.get("damage", 50.0)) * late_k, end, dir, p, float(spec.get("_lock_s", -1.0)),
			(flat * float(spec.get("knock_mps", 6.0)) + Vector3.UP * 2.0) * late_k, info)
	rec["hit"] = 1


static func grab(c: Variant, a: Dictionary, spec: Dictionary) -> void:
	var p := _body(c)
	if p == null:
		return
	var t: Node3D = a.target
	if t == null:
		var near := BendCaster.near(p, _ground_at(p, a, spec), 2.0)
		t = near[0][0] if not near.is_empty() else null
	BendBolt.launch(p, a.from, a.dir, {"kind": "water", "mps": 40.0, "damage": 0.0, "knock_mps": 0.0, "radius_m": 0.12, "range_m": 3.0})
	if t == null or t.global_position.distance_to(p.global_position) > float(spec.get("range_m", 14.0)):
		return
	var to := p.global_position - t.global_position
	to.y = 0.0
	BendR3.deliver(t, float(spec.get("damage", 4.0)), t.global_position + Vector3.UP, to.normalized(), p, -1.0,
			to.normalized() * float(spec.get("pull_mps", 10.0)) + Vector3.UP * 2.0, spec.get("_info", {}))
	BendLooks.burst(t.global_position + Vector3.UP, "water", 20)
	_cur["hit"] = 1


static func kick_up(c: Variant, flat: Vector3, spec: Dictionary) -> FormStone:
	var bc := BendCaster.wrap(c)
	if bc == null or not bc.valid():
		return null
	var p := bc.body
	var foot := FormEffects.ground_at(p, p.global_position + flat * 1.2)
	var s := FormStone.ball(p.get_tree().current_scene, foot, {"radius_m": float(spec.get("radius_m", 0.32)), "mass_kg": 30.0,
			"rise_s": 0.25, "life_s": 30.0, "sink_s": 1.0}, bc.rand_i() % 97, FormMatter.of_ground(p.get_tree(), foot))
	s.set_meta(&"bend_by", p.get_instance_id())
	BendLooks.burst(foot + Vector3.UP * 0.2, "stone", 16)
	_cur["stone"] = s
	return s


static func column(c: Variant, at: Vector3, spec: Dictionary) -> FormRaised:
	var p := _body(c)
	if p == null:
		return null
	var pd: Dictionary = (SwayMoves.move("pillar").get("pillar", {}) as Dictionary)
	var matter := FormMatter.of_ground(p.get_tree(), at)
	if matter == "wood":
		matter = "earth"
	var wn := FormMatter.numbers(pd, FormMatter.entry("pillar", matter), matter)
	var rise := float(spec.get("rise_s", 0.0))
	if rise > 0.0:
		wn["rise_s"] = rise                       # (round 2: it starts low and peaks rise_s later, the throw then)
	if float(spec.get("sink_s", 0.0)) > 0.0:
		wn["life_s"] = float(spec.sink_s)         # (it sinks back sink_s after; never a wall: count_wall never sees it)
	var r := FormRaised.raise(p.get_tree().current_scene, "pillar", Transform3D(Basis.IDENTITY, at), wn, absi(hash(at)) % 97)
	r.set_meta(&"bend_by", p.get_instance_id())
	var sa := {"radius_m": float(spec.get("radius_m", 1.3)), "up_mps": float(spec.get("up_mps", 11.0)),
			"damage": float(spec.get("damage", 10.0)), "kind": "stone", "_lock_s": float(spec.get("_lock_s", -1.0)),
			"_info": spec.get("_info", {})}
	if rise <= 0.0:
		status_at(p, at, sa)
		return r
	var rec := _cur
	p.get_tree().create_timer(rise, false).timeout.connect(func() -> void:
		if not is_instance_valid(p) or not p.is_inside_tree():
			return
		var keep := _cur
		_cur = rec
		status_at(p, at, sa)
		_cur = keep)
	return r


static func _wall(p: Node3D, xf: Transform3D, matter: String, life := -1.0, w := -1.0) -> FormRaised:
	var wd: Dictionary = (SwayMoves.move("earth_wall").get("wall", {}) as Dictionary)
	var wn := FormMatter.numbers(wd, FormMatter.entry("earth_wall", matter), matter)
	if life > 0.0:
		wn["life_s"] = life
	if w > 0.0:
		wn["width_m"] = w
	var r := FormRaised.raise(p.get_tree().current_scene, "wall", xf, wn, absi(hash(xf.origin)) % 97)
	r.set_meta(&"bend_by", p.get_instance_id())
	return r


static func shell(c: Variant, spec: Dictionary) -> void:
	var p := _body(c)
	if p == null:
		return
	var matter := FormMatter.of_ground(p.get_tree(), p.global_position)
	if matter == "wood":
		matter = "earth"
	for i in 4:
		var way := Vector3.FORWARD.rotated(Vector3.UP, i * PI * 0.5)
		var foot := FormEffects.ground_at(p, p.global_position + way * 1.4)
		var x := Vector3.UP.cross(way).normalized()
		_wall(p, Transform3D(Basis(x, Vector3.UP, way), foot), matter, float(spec.get("life_s", 3.0)), 2.9)
	BendLooks.burst(p.global_position, "stone", 30, Vector3.UP, 80.0, 3.0)


static func ramp(c: Variant, flat: Vector3) -> void:
	var p := _body(c)
	if p == null:
		return
	var foot := FormEffects.ground_at(p, p.global_position + flat * 2.5)
	var x := Vector3.UP.cross(flat).normalized()
	var tilt := Basis(x, deg_to_rad(-62.0))
	var b := tilt * Basis(x, Vector3.UP, flat)
	var matter := FormMatter.of_ground(p.get_tree(), foot)
	_wall(p, Transform3D(b, foot), "earth" if matter == "wood" else matter, 20.0, 2.0)


## Water's ice wall: 1.8 m before the caster; with an element (or a spec `place`) where the crosshair is 2-6 m off, facing
## him (FormEffects.place_point).
static func ice_wall(c: Variant, flat: Vector3, spec := {}) -> FormRaised:
	var p := _body(c)
	if p == null:
		return null
	var foot := FormEffects.ground_at(p, p.global_position + flat * 1.8)
	if spec.has("place") or BendStatus.element_mode(p):
		foot = FormEffects.place_point(c, spec.get("place", {}))
		flat = FormEffects.way_to(c, foot)
	var x := Vector3.UP.cross(flat).normalized()
	var r := _wall(p, Transform3D(Basis(x, Vector3.UP, flat), foot), "snow")
	r.set_meta(&"bend_ice", true)
	FormRaised.count_wall(r)                 # (ice walls count with the earth walls: rules.json max_walls)
	BendLooks.burst(foot + Vector3.UP, "ice", 24)
	return r


static func freeze_water(c: Variant, at: Vector3, flat: Vector3) -> void:
	var p := _body(c)
	if p == null:
		return
	for z in p.get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz.kind == "water_wall" and bz.global_position.distance_to(at) < 8.0:
			var xf := bz.global_transform
			bz.end()
			var r := _wall(p, Transform3D(xf.basis.orthonormalized(), xf.origin), "snow")
			r.set_meta(&"bend_ice", true)
			FormRaised.count_wall(r)
			BendLooks.burst(xf.origin + Vector3.UP, "ice", 30)
			_cur["froze"] = r
			return
	BendZone.make(p, "ice_patch", at, {"radius_m": 3.0, "life_s": 8.0}, flat)


## Ice within `r` of `at` gone: ice walls crumble (to water), ice patches end.
static func melt(p: Node3D, at: Vector3, r: float) -> int:
	var n := 0
	for w in p.get_tree().get_nodes_in_group(FormRaised.GROUP):
		var fr := w as FormRaised
		if fr != null and fr.is_up() and (fr.has_meta(&"bend_ice") or fr.matter == "snow") and fr.global_position.distance_to(at) <= r:
			BendLooks.burst(fr.global_position + Vector3.UP, "water", 30)
			fr.crumble("melted")
			n += 1
	for z in p.get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz.kind == "ice_patch" and bz.global_position.distance_to(at) <= r + bz.radius:
			bz.end()
			n += 1
	_cur["melted"] = n
	return n


static func brace(c: Variant, r: float) -> void:
	var p := _body(c)
	if p == null:
		return
	var best: FormRaised = null
	var bd := r
	for w in p.get_tree().get_nodes_in_group(FormRaised.GROUP):
		var fr := w as FormRaised
		if fr == null or not fr.is_up() or int(fr.get_meta(&"bend_by", -1)) != p.get_instance_id():
			continue
		var d := fr.global_position.distance_to(p.global_position)
		if d < bd:
			bd = d
			best = fr
	if best != null:
		best.set_meta(&"bend_brace", true)
		BendLooks.burst(best.global_position + Vector3.UP, "stone", 14)
	_cur["braced"] = best


## Earth Shove: a stone (held by the caster first: a Catch's; else the one the aim is on, or the nearest) or a raised wall
## or pillar on the aim: push (hurled along the aim; a wall's chunk torn out and fired through it), pull (to the caster's
## feet), split (a chunk broken into three flying in a spread). Any caster's the same way (the player's, a bot's: the ring's
## bots shove as he does): FormEffects.gust_chunk, FormEffects.Throw (GustLift flies it; whom it strikes knocked through
## BendStatus.knock, by the caster), aimed by the caster (the player's crosshair, a bot's target).
static func shove(c: Variant, a: Dictionary, how: String, spec: Dictionary) -> void:
	var bc := BendCaster.wrap(c)
	if bc == null or not bc.valid():
		return
	var p := bc.body
	if BendStatus.element_mode(p) and how == "push":
		_shove_r2(bc, a, spec)
		return
	var r := float(spec.get("range_m", 20.0))
	var thing := _shove_target(bc, a, r)
	_cur["target"] = thing
	if thing == null:
		bc.notice("Nothing of stone there to shove", 1.4)
		return
	var feet := FormEffects.ground_at(p, p.global_position + (a.flat as Vector3) * 1.5) + Vector3.UP * 0.4
	if thing is FormRaised:
		var w := thing as FormRaised
		var hit_at := _face_point(w, p)
		var dir := ((a.point as Vector3) - hit_at).normalized()
		match how:
			"push":
				_cur["stone"] = FormEffects.gust_chunk(bc, w, hit_at, dir)
			"pull":
				_cur["stone"] = FormEffects.gust_chunk(bc, w, hit_at, dir, feet)
			"split":
				for i in 3:
					_cur["stone"] = FormEffects.gust_chunk(bc, w, hit_at + Vector3.UP * (i - 1) * 0.3, dir,
							(a.point as Vector3) + dir.cross(Vector3.UP).normalized() * (float(i) - 1.0) * 2.5)
		return
	var st := thing as Node3D
	if st.has_meta(&"bend_held_by"):
		st.remove_meta(&"bend_held_by")
	var td: Dictionary = (SwayMoves.move("stone_form").get("throw", {}) as Dictionary).duplicate(true)
	var gs: Dictionary = (SwayMoves.move("gust").get("stone", {}) as Dictionary).get("hurl", {})
	td["hurl"] = gs
	td["rise_s"] = 0.2
	if st is FormStone and (st as FormStone).state == FormStone.State.RISING:
		(st as FormStone).state = FormStone.State.RESTING
	var th := FormEffects.Throw.start(bc, st as FormStone, td, feet if how == "pull" else Vector3.INF) if st is FormStone else null
	_cur["throw"] = th
	if th == null:
		if st is RigidBody3D:
			(st as RigidBody3D).freeze = false
			SwayEffects.push_prop(st as RigidBody3D, (a.dir as Vector3) * 14.0, st.global_position, 400.0)


## Round 2's Shove (spec §2.6, §2.10, §3.1), with an element: it throws, in order, (1) the stone the caster holds (a catch's:
## BendZone.return_stone, its rally and clean bonus); else (2) what the crosshair is on: a loose stone within shove_loose_m
## of the caster (never one another raised or holds) or a chunk torn from any wall, out of its face (_shove_pick); else (3)
## with kick_up_when_empty (true unless the spec says false: every Shove throws) a stone kicked up at the feet and pushed
## in one cast, the push kick_s (the kick-up clip's strike) later. Grown (▲): grow's knock_mult on the throw. Nothing to throw: said so. _cur: target, stone, throw, how.
static func _shove_r2(bc: BendCaster, a: Dictionary, spec: Dictionary) -> void:
	var p := bc.body
	var km := float(spec.get("knock_mult", 1.0))
	var held := BendZone.held_stone(p)
	if held != null:
		_cur["target"] = held
		_cur["stone"] = held
		_cur["how"] = "held"
		_cur["throw"] = BendZone.return_stone(bc, held)
		return
	var thing := _shove_pick(bc, spec)
	_cur["target"] = thing
	if thing is FormRaised:
		var w := thing as FormRaised
		var hit_at := _face_point(w, p)
		_cur["how"] = "chunk"
		_cur["stone"] = FormEffects.gust_chunk(bc, w, hit_at, ((a.point as Vector3) - hit_at).normalized())
		return
	if thing != null:
		_cur["how"] = "loose"
		_cur["stone"] = thing
		_cur["throw"] = _throw_stone(bc, thing, km)
		return
	if not bool(spec.get("kick_up_when_empty", true)):
		bc.notice("Nothing of stone there to shove", 1.4)
		return
	# (none: one kicked up at the feet, pushed at the kick-up's strike)
	var s := kick_up(bc, a.flat, {"radius_m": float(spec.get("stone_r", 0.32))})
	_cur["how"] = "kick_up"
	_cur["stone"] = s
	var rec := _cur
	var info := BendR3.cur
	var go := func() -> void:
		if bc.valid() and s != null and is_instance_valid(s):
			var keep := BendR3.cur
			BendR3.cur = info                      # (the throw at the kick-up's strike carries the cast's info)
			rec["throw"] = _throw_stone(bc, s, km)
			BendR3.cur = keep
	var kick_s := float(spec.get("kick_s", 0.3))
	if kick_s <= 0.0:
		go.call()
	else:
		p.get_tree().create_timer(kick_s, false).timeout.connect(go)


## What a Shove's crosshair is on (§2.10): a raised wall or pillar at any range (its chunk), or a stone within
## shove_loose_m of the caster that no one else raised or holds and that is not flying; null none (no search round the aim:
## only the line of it).
static func _shove_pick(bc: BendCaster, spec: Dictionary) -> Node3D:
	var p := bc.body
	var ray := bc.aim_ray()
	var from: Vector3 = ray[0]
	var rdir: Vector3 = ray[1]
	if rdir.length_squared() < 1e-6:
		return null
	var reach := float(spec.get("range_m", 20.0)) + from.distance_to(bc.chest()) + 6.0
	var loose_m := float(Bending.stones().get("shove_loose_m", 6.0))
	var exl: Array[RID] = bc.exclude()
	for i in 4:
		var h := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + rdir.normalized() * reach, 0xFFFFFFFF, exl))
		if h.is_empty():
			return null
		var n := h.collider as Node
		for k in 4:
			if n == null:
				break
			if n is FormRaised:
				return n as Node3D if (n as FormRaised).is_up() else null
			if GustLift.is_stone(n):
				var mine := p.get_instance_id()
				var other := int(n.get_meta(&"bend_held_by", mine)) != mine or int(n.get_meta(&"bend_raised_by", mine)) != mine
				var near := (n as Node3D).global_position.distance_to(p.global_position) <= loose_m
				return n as Node3D if not other and near and not GustLift.busy(n) else null
			n = n.get_parent()
		if h.collider is CharacterBody3D or h.collider is PhysicalBone3D:
			exl.append(h.rid)                    # (past a body in the way: the line behind him)
			continue
		return null
	return null


## Stone `st` thrown along the caster's aim as a Shove throws (stone_form.throw, gust.stone.hurl's numbers; FormEffects
## Throw), its knock times `km` (a grown Shove). Its loose and held marks gone. The Throw (null: not a FormStone, pushed).
static func _throw_stone(bc: BendCaster, st: Node3D, km := 1.0) -> FormEffects.Throw:
	for k: StringName in [&"bend_held_by", FormStone.LOOSE_META]:
		if st.has_meta(k):
			st.remove_meta(k)
	if not (st is FormStone):
		if st is RigidBody3D:
			(st as RigidBody3D).freeze = false
			SwayEffects.push_prop(st as RigidBody3D, bc.facing() * 14.0, st.global_position, 400.0)
		return null
	var td: Dictionary = (SwayMoves.move("stone_form").get("throw", {}) as Dictionary).duplicate(true)
	var gs: Dictionary = ((SwayMoves.move("gust").get("stone", {}) as Dictionary).get("hurl", {}) as Dictionary).duplicate(true)
	if km != 1.0:
		for key in gs:
			if gs[key] is Dictionary:
				(gs[key] as Dictionary)["knock_mps"] = float((gs[key] as Dictionary).get("knock_mps", GustLift.KNOCK_MPS)) * km
		var kn: Dictionary = (td.get("knock_mps", {}) as Dictionary).duplicate()
		for key in kn:
			kn[key] = float(kn[key]) * km
		td["knock_mps"] = kn
	td["hurl"] = gs
	td["rise_s"] = 0.2
	if (st as FormStone).state == FormStone.State.RISING:
		(st as FormStone).state = FormStone.State.RESTING
	return FormEffects.Throw.start(bc, st as FormStone, td)


## A stone bolt from `from` at `to` with gust.raised's chunk numbers (mps, gravity, damage, knock_mps): what a shoved stone
## was for a bot before the Throw took any caster; kept for whoever flings a loose chunk.
static func shove_bolt(bc: BendCaster, from: Vector3, to: Vector3, radius := 0.3) -> BendBolt:
	var gd: Dictionary = SwayMoves.move("gust").get("raised", {})
	var mps := float(gd.get("mps", 26.0))
	var spec := {"kind": "stone", "mps": mps, "gravity": float(gd.get("gravity", 4.0)), "damage": float(gd.get("damage", 45.0)) * 0.5,
			"knock_mps": float(gd.get("knock_mps", 5.0)) + 3.0, "up_mps": 1.5, "radius_m": clampf(radius, 0.12, 0.45), "range_m": 40.0}
	var tf := from.distance_to(to) / maxf(mps, 0.1)
	var aim_at := to + Vector3.UP * 0.5 * float(spec.gravity) * tf * tf
	var b := BendBolt.launch(bc.body, from, (aim_at - from).normalized(), spec)
	FormEffects.sfx("hurl", from, 0.0, 1.0)
	return b


## The thing to shove: a stone the caster holds; else what the aim's ray meets (a stone, a raised wall or pillar) within
## `r` (the caster's aim_ray: the player's camera, a bot's line to its target); else the nearest stone to the aim's line within
## 3 m.
static func _shove_target(c: Variant, a: Dictionary, r: float) -> Node3D:
	var bc := BendCaster.wrap(c)
	if bc == null:
		return null
	var p := bc.body
	for s in p.get_tree().get_nodes_in_group(FormStone.GROUP):
		if int((s as Node).get_meta(&"bend_held_by", -1)) == p.get_instance_id():
			return s
	var ray := bc.aim_ray()
	var from: Vector3 = ray[0]
	var rdir: Vector3 = ray[1]
	if rdir.length_squared() > 1e-6:
		var h := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + rdir.normalized() * (r + 6.0), 0xFFFFFFFF, bc.exclude()))
		if not h.is_empty():
			var n := h.collider as Node
			for i in 4:
				if n == null:
					break
				if n is FormRaised or GustLift.is_stone(n):
					return n as Node3D
				n = n.get_parent()
	var best: Node3D = null
	var bd := 3.0
	for s in p.get_tree().get_nodes_in_group(FormStone.GROUP):
		var q := (s as Node3D).global_position
		if q.distance_to(p.global_position) > r:
			continue
		var line := Geometry3D.get_closest_point_to_segment(q, a.from, (a.from as Vector3) + (a.dir as Vector3) * r)
		var d := q.distance_to(line)
		if d < bd:
			bd = d
			best = s
	return best


static func _face_point(w: FormRaised, p: Node3D) -> Vector3:
	var to := p.global_position - w.global_position
	to.y = 0.0
	var c := w.global_position + Vector3.UP * minf(1.0, w.size.y * 0.5)
	return c + to.normalized() * (w.size.z * 0.5 if w.kind == "wall" else w.size.x * 0.5)


# ---------------------------------------------------------------- round 3: the deck, the Slam, the air hit (AIR)
## Point `pt` of caster body `p` kept on the deck in the % ring (BendR3.keep_on_deck, air_rules.deck_inset_m: Column and
## Geyser never rise from the tank's water); as it is elsewhere.
static func _deck_at(p: Node3D, pt: Vector3) -> Vector3:
	if not BendR3.stock() or p == null or not p.is_inside_tree():
		return pt
	return BendR3.keep_on_deck(p.get_tree(), pt, BendR3.num("deck_inset_m", 0.6))


## The Slam (round 3, spec §6.2; spec do "slam"; key 2's lock started in the air): a column width_m wide from the caster's
## feet to depth_m below him, its foot leaning lean_m toward the aim's yaw, out for active_s from the strike (it follows him
## down). Whom it meets is hit once: tag "<id>/slam", the spec's set_stun, a knock at angle_deg (-70: down) of knock_mps along
## the caster's way to him; on a grounded body bounce_once (bounce_k x the down speed + bounce_add: PERCENT bounces him once
## a string). A guard of his is a shield (BendZone.guard_take). Each element's touch: held_stone "throw" (the Hammer: a stone
## held is thrown down into its space instead), put_out and puddle (Downpour: fire in it goes out, a puddle left on the deck,
## a Geyser source), wave (the Axe Kick: reaching the deck it runs on as a short floor wave), self_lift_mps (Down Gust: the
## caster lifted once an airtime). The Strike, or null (the Hammer threw its stone).
static func slam(c: Variant, a: Dictionary, spec: Dictionary) -> Strike:
	var bc := BendCaster.wrap(c)
	if bc == null or not bc.valid():
		return null
	var p := bc.body
	var kind := String(spec.get("kind", "stone"))
	if String(spec.get("held_stone", "")) == "throw":
		var held := BendZone.held_stone(p)
		if held != null:
			_cur["how"] = "held"
			_cur["stone"] = held
			_cur["throw"] = BendZone.return_stone(bc, held, slam_box(bc, a, spec).foot)
			return null
	var lift := float(spec.get("self_lift_mps", 0.0))
	if lift > 0.0:
		BendMotion.of(p)                           # (its frame clears the lift's mark on landing)
		if not p.has_meta(&"bend_slam_lift"):
			p.velocity.y = maxf(p.velocity.y, 0.0) + lift
			p.set_meta(&"bend_slam_lift", BendStatus.now())
			_cur["lifted"] = true
	var st := Strike.start(bc, "slam", a, spec)
	var box := slam_box(bc, a, spec)
	BendLooks.burst(p.global_position + Vector3.UP * 0.4, kind, 30, ((box.foot as Vector3) - p.global_position).normalized(), 25.0, 10.0, 0.4)
	BendLooks.sound(kind, "hit", p.global_position, -2.0)
	var floor_at := _floor_under(bc, box)
	_cur["deck"] = floor_at != Vector3.INF
	if floor_at != Vector3.INF:
		BendLooks.burst(floor_at + Vector3.UP * 0.1, kind, 26, Vector3.UP, 70.0, 4.0, 0.4)
		if bool(spec.get("put_out", false)):
			for z in p.get_tree().get_nodes_in_group(BendZone.GROUP):
				var bz := z as BendZone
				if bz != null and bz.kind in ["fire_wall", "burn"] and bz.global_position.distance_to(floor_at) <= float(spec.get("width_m", 2.5)) + 1.5:
					BendLooks.burst(bz.global_position + Vector3.UP, "steam", 30, Vector3.UP, 90.0, 2.5, 1.0)
					bz.end()
		var pd: Variant = spec.get("puddle")
		if pd is Dictionary:
			_cur["puddle"] = BendZone.make(p, "puddle", floor_at, {"radius_m": float((pd as Dictionary).get("radius_m", 1.6)),
					"life_s": float((pd as Dictionary).get("life_s", 6.0))}, bc.facing())
		var wv: Variant = spec.get("wave")
		if wv is Dictionary:
			var ws := (wv as Dictionary).duplicate()
			var winfo: Dictionary = (spec.get("_info", {}) as Dictionary).duplicate()
			winfo["tag"] = String(winfo.get("tag", "fire_kick/slam")) + "_wave"
			winfo.erase("set_stun")
			ws["_info"] = winfo
			ws["_lock_s"] = float(spec.get("_lock_s", -1.0))
			var dir := bc.facing()
			_cur["wave"] = BendBolt.launch(p, floor_at + dir * 0.5, dir, ws)
	return st


## The Slam's space now for caster `bc` (spec: width_m, depth_m, lean_m): {top (his feet), foot (its bottom's middle),
## axis (top to foot, unit), length, across (unit, flat), fwd, width}.
static func slam_box(bc: BendCaster, a: Dictionary, spec: Dictionary) -> Dictionary:
	var p := bc.body
	var fwd: Vector3 = a.get("flat", bc.facing())
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 1e-6 else bc.facing()
	var top := p.global_position
	var foot := top + Vector3.DOWN * float(spec.get("depth_m", 3.0)) + fwd * float(spec.get("lean_m", 1.5))
	var ax := foot - top
	return {"top": top, "foot": foot, "axis": ax.normalized(), "length": ax.length(), "across": Vector3.UP.cross(fwd).normalized(),
			"fwd": fwd, "width": float(spec.get("width_m", 2.5))}


## Whether `q` is inside slam_box `b` (its column's length, its width across and through).
static func in_slam(b: Dictionary, q: Vector3) -> bool:
	var ax: Vector3 = b.axis
	var rel := q - (b.top as Vector3)
	var along := rel.dot(ax)
	if along < -0.3 or along > float(b.length) + 0.2:
		return false
	var off := rel - ax * along
	var across: Vector3 = b.across
	var thru := ax.cross(across).normalized()
	var hw := float(b.width) * 0.5
	return absf(off.dot(across)) <= hw and absf(off.dot(thru)) <= hw


## The deck under the Slam's space (its first solid ground down the column; INF: none within it, over the water).
static func _floor_under(bc: BendCaster, b: Dictionary) -> Vector3:
	var p := bc.body
	var exl: Array[RID] = bc.exclude()
	var space := p.get_world_3d().direct_space_state
	for i in 4:
		var h := space.intersect_ray(PhysicsRayQueryParameters3D.create((b.top as Vector3) + Vector3.UP * 0.1, (b.foot as Vector3), 1, exl))
		if h.is_empty():
			return Vector3.INF
		var col := h.collider as Object
		if col is CharacterBody3D or col is RigidBody3D or col is PhysicalBone3D:
			exl.append(h.rid)
			continue
		return h.position
	return Vector3.INF


## The element's air hit (round 3, the owner's answer 4: LMB in the air; spec do "air_hit"): a ball radius_m round a point
## reach_m along the aim from the chest, out for active_s; whom it meets hit once: its set_stun, a set knock of knock_mps at
## angle_deg along the caster's way to him. Short, for strings. The Strike.
static func air_hit(c: Variant, a: Dictionary, spec: Dictionary) -> Strike:
	var bc := BendCaster.wrap(c)
	if bc == null or not bc.valid():
		return null
	var kind := String(spec.get("kind", "air"))
	var st := Strike.start(bc, "air_hit", a, spec)
	var at := st.centre()
	BendLooks.burst(at, kind, 22, (a.dir as Vector3) if a.has("dir") else bc.facing(), 70.0, 5.0, 0.3)
	BendLooks.sound(kind, "cast", at, -3.0)
	return st


## A strike that stays out a moment (the Slam's column, the air hit's ball): it looks for whom it meets each physics frame
## for active_s, following its caster, and hits each once (BendR3.deliver; a guard a shield). Group GROUP.
class Strike:
	extends Node

	const GROUP := &"bend_strikes"

	var caster: BendCaster
	var shape := "slam"
	var a := {}
	var spec := {}
	var t := 0.0
	var active_s := 0.12
	## Whom it hit (the tests).
	var hit: Array = []
	var rec := {}

	static func start(bc: BendCaster, p_shape: String, p_a: Dictionary, p_spec: Dictionary) -> Strike:
		var s := Strike.new()
		s.name = "BendStrike_" + p_shape
		s.caster = bc
		s.shape = p_shape
		s.a = p_a
		s.spec = p_spec
		s.active_s = maxf(float(p_spec.get("active_s", 0.12)), 0.0)
		s.rec = BendEffects._cur
		s.rec["hit"] = 0
		s.add_to_group(GROUP)
		bc.body.get_tree().current_scene.add_child(s)
		s._look()
		return s

	## The air hit's ball's middle now (world).
	func centre() -> Vector3:
		var dir: Vector3 = a.get("dir", caster.facing())
		if caster.valid():
			var ray := caster.aim_ray()
			if (ray[1] as Vector3).length_squared() > 1e-6:
				dir = (ray[1] as Vector3).normalized()
		return caster.chest() + dir * float(spec.get("reach_m", 1.5))

	func _physics_process(dt: float) -> void:
		if caster == null or not caster.valid():
			queue_free()
			return
		t += dt
		if t > active_s:
			queue_free()
			return
		_look()

	## Who is in it now, each hit once.
	func _look() -> void:
		var p := caster.body
		var box := BendEffects.slam_box(caster, a, spec) if shape == "slam" else {}
		var c := centre() if shape == "air_hit" else p.global_position
		var r := float(spec.get("radius_m", 1.0))
		var reach := (float(spec.get("depth_m", 3.0)) + float(spec.get("lean_m", 1.5)) + float(spec.get("width_m", 2.5))) \
				if shape == "slam" else r + 1.5
		for e in BendCaster.near(p, c if shape == "air_hit" else p.global_position + Vector3.DOWN * 1.5, reach):
			var n: Node3D = e[0]
			if n == p or hit.has(n):
				continue
			var inside := false
			for h: float in [0.15, 0.9, 1.5]:
				var q := n.global_position + Vector3.UP * h
				inside = BendEffects.in_slam(box, q) if shape == "slam" else q.distance_to(c) <= r
				if inside:
					break
			if not inside:
				continue
			hit.append(n)
			_strike(n)

	func _strike(n: Node3D) -> void:
		var p := caster.body
		var info: Dictionary = (spec.get("_info", {}) as Dictionary).duplicate()
		var flat := n.global_position - p.global_position
		flat.y = 0.0
		if flat.length_squared() < 0.04:
			flat = a.get("flat", caster.facing())
		var kv := BendR3.set_v(flat, float(spec.get("knock_mps", 6.0)), float(spec.get("angle_deg", -70.0 if shape == "slam" else 40.0)))
		if spec.has("set_stun"):
			info["set_stun"] = float(spec.set_stun)
		if shape == "slam" and n is CharacterBody3D and (n as CharacterBody3D).is_on_floor():
			info["bounce_once"] = true
			info["bounce_k"] = float(spec.get("bounce_k", 0.45))
			info["bounce_add"] = float(spec.get("bounce_add", 2.0))
		var k := 1.0
		if BendR3.stock():
			var g := BendZone.guard_take(n, String(spec.get("kind", "stone")), p, info)
			if String(g.result) == "perfect":
				return
			k = float(g.mult)
			info = g.info
		BendR3.deliver(n, float(spec.get("damage", 10.0)) * k, n.global_position + Vector3.UP, kv.normalized(), p,
				float(spec.get("_lock_s", -1.0)), kv * k, info)
		rec["hit"] = int(rec.get("hit", 0)) + 1
		BendLooks.burst(n.global_position + Vector3.UP, String(spec.get("kind", "stone")), 18, Vector3.UP, 120.0, 4.0, 0.3)
