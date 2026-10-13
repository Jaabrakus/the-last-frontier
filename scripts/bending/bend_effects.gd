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
## The key (0-based) every element keeps its dashes on (spec.md's 3 Dash: Burrow and Lift, Skate and Surf, Step and Jets, Slip
## and Leap): what a bind's held feet stop (BendStatus.bind).
const DASH_KEY := 2

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
	spec = BendLoadout.spec(bc.body, m, mode, spec)          # (a worn loadout's numbers over the spec, before the grow merge)
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
	if bc.feet_bound() and BendStatus.element_mode(p) and Bending.key_of(BendPoses.element_of(p), m) == DASH_KEY:
		# (a bind holds his feet: his dash key's moves (a dash, a Skate, a Surf, a Leap) go nowhere till it ends; the cast is
		# spent as any other; BendStatus.bind)
		_record(bc, {"do": "held", "mode": mode, "move": m})
		return
	spec["_lock_s"] = lock_of(m, mode)
	if BendR3.is_jab(m, mode) and Bending.element_of(m) == BendPoses.element_of(p) and spec.has("range_m"):
		# (the element's jab: the close poke, jab_max_m at most whatever its spec says; spec §2.1)
		spec["range_m"] = minf(float(spec.range_m), Bending.rule("jab_max_m", 10.0))
	var carried := false
	if bool(spec.get("carry", false)) and bc.carry_ready():
		# (Carried wind: a hit straight out of a dash knocks harder; spent on this cast)
		var k := BendLoadout.tune_f(p, "rules:passives.air.knock_mult", float(Bending.passive("air").get("knock_mult", 1.15)))
		spec["knock_mps"] = float(spec.get("knock_mps", 0.0)) * k
		if not AirTalents.keeps_carry(p, m, mode, spec):
			p.remove_meta(&"bend_carry_until")        # (Carry the Edge's Beat Slice keeps it; Classic always spends it)
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
	if String(spec.get("held_stone", "")) == "throw" and String(spec.get("do", "")) != "slam" and BendStatus.element_mode(p):
		var held_s := BendZone.held_stone(p)
		if held_s != null:
			# (a caught stone held: this move throws it along the aim instead of its own (the Fissure, as Shove did: "Shove
			# throws the stone you hold"); the Slam has its own, thrown down into its space)
			var a1 := aim(bc, spec)
			_record(bc, {"do": "return", "mode": mode, "move": m, "aim": a1.point, "grown": grew})
			_cur["target"] = held_s                  # (the record the Shove made of it: what it threw and how)
			_cur["how"] = "held"
			_cur["throw"] = BendZone.return_stone(bc, held_s)
			_cur["stone"] = held_s
			return
	var a := aim(bc, spec)
	_record(bc, {"do": String(spec.get("do", "")), "mode": mode, "move": m, "aim": a.point, "grown": grew, "carried": carried,
			"spec": spec})
	var kind := String(spec.get("kind", "stone"))
	BendLooks.sound(kind, "cast", p.global_position + Vector3.UP, -4.0)
	MonsoonIdentity.release(p, Bending.element_of(m), mode == "big" or grew)
	var sbk := SbFx.key_of(spec.get("_info", {}), m, mode)      # (the Spellbreak effects: visual only, SbFx)
	SbFx.fire(p, sbk, "cast", {"at": a.from, "dir": a.dir, "info": spec.get("_info", {})})
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
			var wk: float = AirTalents.wall_life_k(p)
			if wk != 1.0:
				ws["life_s"] = float(ws.get("life_s", 4.0)) * wk      # (Blizzard's wearer: his Wind Wall 15% shorter)
			ws["zone"] = "wind_wall"
			if _tracked(p, ws) != null:
				ws["at"] = "aim"                  # (the Wind Prison tracked: round the foe it followed, not 2-6 m out)
				ws.erase("place")
			elif not ws.has("at"):
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
				if NetSpells.owns(p) and bool(spec.get("cauterize", false)) and FireTalents.any(p):
					_cur["patched"] = FireTalents.cauterize(p, spec)    # (a worn Cauterize: its cost, then up to 12% back)
				elif NetSpells.owns(p):
					_cur["patched"] = rr.patch(p)     # (round 3, spec §8: the fresh pool taken back, never health; online
				                                      # his own machine's: NetSpells)
			else:
				BendStatus.heal(p, float(spec.get("amount", 15.0)))
			if bool(_cur.get("patched", false)):
				SbFx.fire(p, sbk, "heal_pop", {"dir": a.flat})
			if not SbFx.fire(p, sbk, "heal", {"node": p, "dir": a.flat}):
				if m == "patch":
					BendLooks.patch_glow(p, BendPoses.element_of(p))   # (round him in his element's matter, feet to chest)
				else:
					BendLooks.burst(p.global_position + Vector3.UP, "water" if kind == "water" else "air", 20, Vector3.UP, 60.0, 1.5)
		"cleanse":
			for k: StringName in [&"bend_root", &"bend_slow"]:
				if p.has_meta(k) and NetSpells.owns(p):
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
	if FireTalents.any(p):
		FireTalents.cast(bc, m, mode, spec, a)       # (what a worn talent adds to this cast; Classic never gets here)


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
## caster's flight_point: the player's crosshair line at the foe's depth, his eye not his hand; or its target's:
## target_point, led for a bolt of spec.mps), target (aim_target)}.
static func aim(c: Variant, spec := {}) -> Dictionary:
	var bc := BendCaster.wrap(c)
	var p := bc.body
	var chest := bc.chest()
	var point: Vector3 = bc.flight_point()
	var target: Node3D = null
	# (to_crosshair: the player's cast goes where his crosshair is, the aim's help never bending it to a body: the High Kick's
	# blast, the owner 2026-10-11: "exactly to the crosshair". A bot aims with its own pick, lead and scatter as ever)
	if not (bool(spec.get("to_crosshair", false)) and bc is PlayerBendCaster):
		target = bc.aim_target()
	var tracked := _tracked(p, spec)
	if tracked != null:
		# (a tracking meter: under the foe it tracked, where he is now; the aim help's pull toward the crosshair never moves it,
		# the meter earned the place)
		target = tracked
		point = NpcSenses.chest_of(tracked)
	elif target != null:
		point = bc.target_point(target, float(spec.get("mps", 0.0)))
	if point == Vector3.INF:
		point = chest - p.global_basis.z * 20.0
	var flat := point - p.global_position
	flat.y = 0.0
	flat = flat.normalized() if flat.length_squared() > 1e-4 else -p.global_basis.z
	var from := bc.launch_point(flat)
	return {"from": from, "dir": (point - from).normalized(), "flat": flat, "point": point, "target": target}


## The foe a tracking meter (spec track; SwayCaster's lock) was locked on at its release (marked then: SwayCaster._cast;
## SwayCaster.track_locked), the strike TRACK_FRESH_S after it at most; null none: the crosshair's place.
const TRACK_FRESH_S := 1.5
static func _tracked(p: Node3D, spec: Dictionary) -> Node3D:
	if not (bool(spec.get("track", false)) or float(spec.get("prison_s", 0.0)) > 0.0) or p == null or not p.has_meta(SwayCaster.TRACK_META):
		return null
	var tm: Dictionary = p.get_meta(SwayCaster.TRACK_META)
	if BendStatus.now() - float(tm.get("at", -INF)) > TRACK_FRESH_S:
		return null
	var n := instance_from_id(int(tm.get("id", 0))) as Node3D
	return n if n != null and is_instance_valid(n) and n.is_inside_tree() else null


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
		spec["steer_dps"] = BendLoadout.tune_f(p, "rules:passives.water.steer_dps", float(pv.get("steer_dps", 45.0)))
		spec["steer_max_deg"] = BendLoadout.tune_f(p, "rules:passives.water.steer_max_deg", float(pv.get("steer_max_deg", 15.0)))
		spec["steer_s"] = BendLoadout.tune_f(p, "rules:passives.water.steer_s", float(pv.get("steer_s", 0.25)))
	var nctx := NetSpells.ctx()                   # (online: a volley's later bolts named in its cast's run, NetSpells)
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
			if every > 0.0 and i > 0:
				NetSpells.with(nctx, func() -> void: BendBolt.launch(p, from, dir, spec))
			else:
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
	var point: Vector3 = bc.flight_point()
	var from: Vector3 = a.from
	var dir: Vector3 = (point - from).normalized() if point.is_finite() and point.distance_to(from) > 0.5 else (a.dir as Vector3)
	var b := BendBolt.launch(p, from, dir, s)
	AirTalents.on_wind_wave(p, b, s)                # (Carrying Wind's Beat Gust carries loose stones; Classic none)
	return b


## A cone (or, `ring`, all round) before the caster from `from` along `flat`. A guard of the one it reaches takes its share
## (BendZone.cone_mult: a Turn on the beat parts a Wave round him; late, half). `smoke_s` (Breath): a smoke screen left where
## it burned (it hides from a bot; no slow).
static func cone(p: Node3D, from: Vector3, flat: Vector3, spec: Dictionary, ring := false) -> void:
	var r := float(spec.get("radius_m", spec.get("range_m", 5.0)))
	var deg := 360.0 if ring else float(spec.get("deg", 60.0))
	var kind := String(spec.get("kind", "air"))
	BendStatus.rescue_near(p, p.global_position + flat * r * 0.5, r * 0.6)   # (a held teammate in its reach freed)
	var info: Dictionary = spec.get("_info", {})
	var hit := 0
	var travel := 0.0 if ring else float(spec.get("travel_mps", 0.0))
	var o := p.global_position
	for e in BendCaster.near(p, p.global_position, r):
		var n: Node3D = e[0]
		var to := n.global_position - p.global_position
		to.y = 0.0
		if not ring and to.length() > 0.3 and rad_to_deg(to.normalized().angle_to(flat)) > deg * 0.5:
			continue
		if travel > 0.0:
			# (a travelling cone, the Wave: it lands as its water reaches him, BendLooks.wave_front; still in its way then, a
			# little slack for the front's width: the move review 2026-10-12, he flew before the foam got there)
			var wait := maxf(to.length() - 0.5, 0.0) / travel
			p.get_tree().create_timer(wait, false).timeout.connect(func() -> void:
				if not is_instance_valid(p) or not is_instance_valid(n) or not n.is_inside_tree():
					return
				var t2 := n.global_position - o
				t2.y = 0.0
				if t2.length() > r + 1.0 or (t2.length() > 0.3 and rad_to_deg(t2.normalized().angle_to(flat)) > deg * 0.5 + 12.0):
					return
				_cone_hit(p, n, t2, flat, spec, kind, info))
		else:
			_cone_hit(p, n, to, flat, spec, kind, info)
		hit += 1
	_cur["hit"] = hit
	if not ring and String(info.get("tag", "")).get_slice(".", 0) == "wave/push":
		_wave_talents(p, flat, r)
	if kind == "fire":
		FireTalents.fire_cone(p, flat, r, deg, String(info.get("tag", "")))   # (fire lights the gas it reaches; a worn Scald's steam)
	if bool(spec.get("put_out", false)) or bool(spec.get("melt", false)):
		for z in p.get_tree().get_nodes_in_group(BendZone.GROUP):
			var bz := z as BendZone
			if bz.kind == "snow" and bool(spec.get("melt", false)):
				AirTalents.breath_melt(p, bz, flat, r, deg)  # (a Breath into a Blizzard melts it out; a worn talent's snow only)
			var to := bz.global_position - p.global_position
			if to.length() > r + 2.0:
				continue
			if bool(spec.get("put_out", false)) and bz.kind in ["fire_wall", "burn"]:
				if not SbFx.fire(p, SbFx.key_of(info), "put_out", {"at": bz.global_position, "dir": flat}):
					BendLooks.burst(bz.global_position + Vector3.UP, "steam", 30, Vector3.UP, 90.0, 2.5, 1.0)
				bz.end()
			if bool(spec.get("melt", false)) and bz.kind == "ice_patch":
				bz.end()
		if bool(spec.get("melt", false)):
			melt(p, p.global_position + flat * r * 0.5, r * 0.7)
	if BendZone.BendGas.live_n > 0:
		BendZone.BendGas.cone(p, flat, r, deg, kind, ring)   # (Sulphur's gas it reaches: fire lights, water washes, wind carries)
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
	if travel > 0.0:
		BendLooks.wave_front(p.global_position + Vector3.UP * 1.1, flat, deg, r, travel, float(spec.get("tall_m", 1.2)))
	elif not SbFx.fire(p, SbFx.key_of(info), "cone", {"at": p.global_position + Vector3.UP * 1.1, "dir": flat, "radius": r,
			"to": p.global_position + Vector3.UP * 1.1 + flat * r, "info": info}):
		BendLooks.blast(p.global_position + Vector3.UP * 1.1, flat, deg, r, kind)
		if kind == "fire" and float(spec.get("smoke_s", 0.0)) > 0.0 and not ring:
			# (Breath breathed out a while, not one puff: the flame kept 0.35 s more before its smoke, the move review
			# 2026-10-12; looks only, the hit was the cone's above)
			for i in 2:
				p.get_tree().create_timer(0.14 * (i + 1), false).timeout.connect(func() -> void:
					if is_instance_valid(p):
						BendLooks.blast(p.global_position + Vector3.UP * 1.1, flat, deg, r, kind))


## One body `n` the cone reached, `to` (flat) from the caster: its guard's share taken, then the hit (the cone's at once, or
## its travelling water's as it arrives).
static func _cone_hit(p: Node3D, n: Node3D, to: Vector3, flat: Vector3, spec: Dictionary, kind: String, info: Dictionary) -> void:
	var inf := info
	var gm := 1.0
	if BendR3.stock():
		# (round 3: every guard a shield, spec §2.5: perfect nothing, late half as a slide)
		var g := BendZone.guard_take(n, kind, p, info)
		if String(g.result) == "perfect":
			return
		gm = float(g.mult)
		inf = g.info
	else:
		gm = BendZone.cone_mult(n, kind, p)
		if gm <= 0.0:
			return                                # (parted round him on the beat)
	var away := to.normalized() if to.length_squared() > 1e-4 else flat
	BendR3.deliver(n, float(spec.get("damage", 0.0)) * gm, n.global_position + Vector3.UP, away, p, float(spec.get("_lock_s", -1.0)),
			(away * float(spec.get("knock_mps", 0.0)) + Vector3.UP * float(spec.get("up_mps", 0.0))) * gm, inf)
	SbFx.fire(p, SbFx.key_of(info), "hit_body", {"at": n.global_position + Vector3.UP, "dir": away, "info": info})
	if float(spec.get("root_s", 0.0)) > 0.0:
		BendStatus.root(n, float(spec.root_s))
	if float(spec.get("slow_s", 0.0)) > 0.0:
		BendStatus.slow(n, float(spec.slow_s))
	if float(spec.get("dazzle_s", 0.0)) > 0.0:
		# (a flare's flash: a bot so dazzled aims wider and answers later, NpcBendCaster.dazzled)
		n.set_meta(&"bend_dazzle_until", BendStatus.now() + float(spec.dazzle_s))


## The Wave's skill tree talents (BendLoadout.wears: the caster's own; Classic never here), its cone `r` m along `flat` cast:
##   Pooling Wave   a puddle of his (POOLING_PUDDLE) on the deck where the cone ends: a Geyser's source
##   Mudslide       a mud pool of his (MUDSLIDE_POOL; his puddles are mud with the Mud set it needs) there
##   Ride the Wave  let go on the Beat (BendR3.release beat: SwayCaster's, a bot's NpcBending) on the deck, he is carried RIDE_M
##                  along its axis behind the water (BendMotion.ride), foam at his feet
const POOLING := "water.wave.pooling"
const POOLING_PUDDLE := {"radius_m": 1.2, "life_s": 6.0}
const MUDSLIDE := "water.mud.mudslide"
const MUDSLIDE_POOL := {"radius_m": 2.0, "life_s": 6.0}
const RIDE := "water.wave.ride"
const RIDE_M := 3.0
const RIDE_S := 0.25
static func _wave_talents(p: Node3D, flat: Vector3, r: float) -> void:
	var pool: Dictionary = POOLING_PUDDLE if BendLoadout.wears(p, POOLING) else (MUDSLIDE_POOL if BendLoadout.wears(p, MUDSLIDE) else {})
	if not pool.is_empty() and p.is_inside_tree():
		var end := p.global_position + flat * r
		if BendR3.stock():
			end = BendR3.off_lip(p.get_tree(), end, float(pool.radius_m) * 0.5)      # (on the deck, not past its lip)
		var g := FormEffects.ground_at(p, end)
		BendLooks.burst(g + Vector3.UP * 0.1, "water", 22, Vector3.UP, 70.0, 3.0, 0.35)
		_cur["puddle"] = BendZone.make(p, "puddle", g, pool, flat)
	if BendLoadout.wears(p, RIDE) and bool(BendR3.release.get("beat", false)) and p is CharacterBody3D \
			and (p as CharacterBody3D).is_on_floor():
		BendMotion.of(p as CharacterBody3D).ride(flat, RIDE_M, RIDE_S)
		BendLooks.burst(p.global_position + Vector3.UP * 0.1, "water", 18, -flat + Vector3.UP * 0.4, 60.0, 3.0, 0.3)
		# (the Beat's cue, the tree's beat.cue: a click and a brief flash on his own hands, his alone; nothing on anyone else)
		var sc := SwayCaster.of(p)
		BendLooks.beat_flash(sc if sc != null else p, "water")
		_cur["ride"] = true


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
	if bool(spec.get("by_pitch", false)) and kind == "fire":
		bm._trail("fire")                         # (Jets: flame under his feet while it carries him, the move review 2026-10-12)
	elif float(spec.get("under_s", 0.0)) > 0.0:
		bm._trail("stone")                        # (Burrow: a wake of broken earth along the line he went under)
	AirTalents.on_dash(p, spec)                     # (Peak Wind's Beat Leap: Carried wind at its top; Classic none)
	if float(spec.get("under_s", 0.0)) > 0.0:
		p.set_meta(&"bend_under_until", BendStatus.now() + float(spec.under_s))
	if kind == "air" and up < 2.0 and BendPoses.element_of(p) == "air":
		p.set_meta(&"bend_slip_until", BendStatus.now() + 0.4)       # (a Slip: a near miss in it charges Carried wind)
	var gl: Variant = spec.get("glide")
	if gl is Dictionary and rm == null:            # (round 3: Leap's glide is off in the % ring)
		bm.glide(float((gl as Dictionary).get("fall_mps", 2.5)), float((gl as Dictionary).get("s", 3.0)), bc.jump_held)
	var dinfo: Dictionary = spec.get("_info", {})
	if not SbFx.fire(p, SbFx.key_of(dinfo), "dash", {"at": p.global_position + Vector3.UP * 0.05, "dir": dir, "info": dinfo}):
		BendLooks.burst(p.global_position + Vector3.UP * 0.3, "stone" if bool(spec.get("dust", false)) else kind, 22, -dir + Vector3.UP * 0.3, 50.0, 4.0, 0.4)
	SbFx.dash_began(p, SbFx.key_of(dinfo), dir, dinfo)
	if bool(spec.get("burn", false)):
		var start := p.global_position
		BendZone.make(p, "burn", start + dir * 3.0, {"width_m": 1.4, "height_m": 0.4, "thick_m": 6.0, "life_s": 3.0, "damage_s": 10.0}, dir)
	if spec.get("puddles") is Dictionary and BendLoadout.wears(p, WET_TRAIL):
		_wet_trail(p, dir, spec.puddles as Dictionary, fwd)
	if bool(spec.get("shove", false)):
		for e in BendCaster.near(p, p.global_position + dir * 2.0, 3.0):
			var n: Node3D = e[0]
			var side := (n.global_position - p.global_position).cross(Vector3.UP).normalized()
			BendR3.deliver(n, 0.0, n.global_position, side, p, -1.0, side * 6.0 + Vector3.UP * 1.0, spec.get("_info", {}))


## Wet Trail (a skill tree enhance): the Skate's puddles (its spec's puddles: count, life_s, radius_m; the wearer's numbers) laid
## at his feet along his slide: the first where he sets off, then one each time he has slid a step (the Skate's own reach, its
## fwd_mps over the dash's WET_TRAIL_CARRY_S carry, shared over the count), the last no later than where the slide ends (slower
## than WET_TRAIL_STOP_MPS, or WET_TRAIL_MAX_S on): new ground each, never two on one spot (a slide cut short, at the lip, lays
## fewer). His water, Geyser sources (his mud with the Mud set). The Skate leaves none for anyone who does not wear it (Classic made
## none: the data's puddles were never made).
const WET_TRAIL := "water.skate.wet_trail"
const WET_TRAIL_CARRY_S := 0.25                   # (dash: BendMotion.carry's 0.25 s)
const WET_TRAIL_STOP_MPS := 1.0
const WET_TRAIL_MAX_S := 1.0
static func _wet_trail(p: CharacterBody3D, dir: Vector3, pd: Dictionary, fwd: float) -> void:
	var n := int(pd.get("count", 3))
	var spec := {"radius_m": float(pd.get("radius_m", 1.2)), "life_s": float(pd.get("life_s", 6.0))}
	var step := maxf(fwd * WET_TRAIL_CARRY_S / float(maxi(n - 1, 1)), 0.5)
	var nctx := NetSpells.ctx()                   # (online: the later puddles named in its cast's run, NetSpells)
	var st := {"n": 0, "last": p.global_position, "t": 0.0}
	var lay := func() -> void:
		if not is_instance_valid(p) or not p.is_inside_tree():
			return
		var g := FormEffects.ground_at(p, p.global_position)
		if p.global_position.y - g.y > 1.0:
			return                                # (off the deck in the air: nothing to lie on)
		BendLooks.burst(g + Vector3.UP * 0.05, "water", 8, Vector3.UP, 60.0, 1.5, 0.2)
		BendZone.make(p, "puddle", g, spec, dir)
		st["n"] = int(st.n) + 1
		st["last"] = p.global_position
	lay.call()
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var tick: Array = []
	tick.append(func() -> void:
		if int(st.n) >= n or not is_instance_valid(p) or not p.is_inside_tree():
			return
		st["t"] = float(st.t) + dt
		var last: Vector3 = st.last
		var slid := Vector2(p.global_position.x - last.x, p.global_position.z - last.z).length()
		var done := float(st.t) >= WET_TRAIL_MAX_S or (float(st.t) > 0.1 and Vector2(p.velocity.x, p.velocity.z).length() < WET_TRAIL_STOP_MPS)
		if slid >= step or (done and slid >= step * 0.5):
			NetSpells.with(nctx, lay)
		if not done and int(st.n) < n:
			p.get_tree().create_timer(dt, false, true).timeout.connect(tick[0]))
	p.get_tree().create_timer(dt, false, true).timeout.connect(tick[0])


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
			var rk := SbFx.key_of(spec.get("_info", {}))
			var rbm := BendMotion.of(p)
			var rd: Vector3 = rbm.facing.call() if rbm.facing.is_valid() else -p.global_basis.z
			SbFx.fire(p, rk, "ride_spray", {"dir": rd})
			var rode := SbFx.start(p, "ride", p, rk, "ride", {"node": p, "dir": rd, "life": s})
			rbm.run(float(spec.get("mps", 10.0)), s, kind if not rode else "")
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
	if zk == "gas":
		# (Sulphur's gas from a cast, a worn new skill's (the Sulphur Vent): BendGas makes it, one vent of his at a time, his
		# other clouds kept)
		var gz: BendZone = BendZone.BendGas.vent(p, at, spec)
		_cur["zone"] = gz
		_cur["zone_kind"] = zk
		return gz
	if bool(spec.get("one_at_a_time", false)) or (zk in ["fire_wall", "wind_wall"] and BendStatus.element_mode(p)):
		for z in p.get_tree().get_nodes_in_group(BendZone.GROUP):
			var old := z as BendZone
			if old != null and old.kind == zk and old.owner_node == p:
				old.end()
	if zk == "mud" and bool(spec.get("mire", false)):
		spec["life_s"] = BendZone.mud_life(p)    # (Mire, a skill tree new skill: his mud's life, Delta's over the set's; BendZone.make)
	var z := BendZone.make(p, zk, at, spec, way)
	_cur["zone"] = z
	_cur["zone_kind"] = z.kind
	if z.put_out:
		_cur["put_out"] = z.put_out_fires()
	return z


static func status_at(p: Node3D, at: Vector3, spec: Dictionary) -> void:
	var r := float(spec.get("radius_m", 1.5))
	var kind := String(spec.get("kind", "stone"))
	# (lift_m: the Column's pillar has carried whom it rose under up onto its top, lift_m over the deck: its reach is looked
	# for from the pillar's middle, so the man on its top is in it as well as those on the deck beside it)
	var mid := at + Vector3.UP * float(spec.get("lift_m", 0.0)) * 0.5
	BendStatus.rescue_near(p, mid, r)                # (a held teammate in its reach freed: the Column's, the Geyser's)
	var info: Dictionary = spec.get("_info", {})
	var n_hit := 0
	for e in BendCaster.near(p, mid, r):
		var n: Node3D = e[0]
		var k := 1.0
		var inf := info
		if BendR3.stock():
			var g := BendZone.guard_take(n, kind, p, info)
			if String(g.result) == "perfect":
				continue
			k = float(g.mult)
			inf = g.info
		var kd: Vector3 = spec.get("kv_dir", Vector3.UP)          # (a leaning Column's throw: its way, BendVariants)
		BendR3.deliver(n, float(spec.get("damage", 0.0)) * k, n.global_position + Vector3.UP * 0.3, kd, p,
				float(spec.get("_lock_s", -1.0)), kd * float(spec.get("up_mps", 0.0)) * k, inf)
		if float(spec.get("root_s", 0.0)) > 0.0:
			BendStatus.root(n, float(spec.root_s))
		if float(spec.get("slow_s", 0.0)) > 0.0:
			BendStatus.slow(n, float(spec.slow_s))
		n_hit += 1
	_cur["hit"] = n_hit
	if not SbFx.fire(p, SbFx.key_of(info), "throw", {"at": at, "info": info}):
		BendLooks.burst(at + Vector3.UP * 0.1, kind, 26, Vector3.UP, 50.0, 4.0 if float(spec.get("up_mps", 0.0)) > 0.0 else 2.0, 0.4)
	if bool(spec.get("hollow", false)):
		FormHollow.dig(p.get_tree().current_scene, at, Vector3.FORWARD, r * 2.0, r * 2.0, 20.0)
	BendLooks.sound(kind, "hit", at, -3.0)


## The Geyser (spec do "spout"; §3.2): a column of water rising at `at` (the aim's ground, range_m), low and weak at first
## and at its peak rise_s later, when it throws whoever stands there up (up_mps, damage; status_at). Over a grate or the
## caster's own puddle within source_m (Bending.POOLS) it is source_mult wider and a third of that higher. No mark on the
## deck: the rising water is the tell. Its way (BendVariants, _spout_way; the owner, 2026-10-12: "do the same for geyser"):
## leaning right or left it erupts tilted and throws them that way; from the water, the nearest water by the mark swells for
## rise_s and a jet shoots across the deck through the mark, throwing them away from it (no source bonus: it is the source).
static func spout(c: Variant, at: Vector3, spec: Dictionary) -> void:
	var bc := BendCaster.wrap(c)
	if bc == null or not bc.valid():
		return
	var p := bc.body
	var s := spec.duplicate()
	s["kind"] = String(spec.get("kind", "water"))
	var way := {} if float(spec.get("bind_s", 0.0)) > 0.0 else _spout_way(p, at, spec)
	if not way.is_empty():
		var inf: Dictionary = (spec.get("_info", {}) as Dictionary).duplicate()
		if inf.has("tag"):
			inf["tag"] = String(inf.tag) + String(way.suffix)        # (its own class: wave/spout.lean, .side)
		inf["dir"] = way.flat
		s["_info"] = inf
		s["kv_dir"] = way.kv_dir
	if way.has("from"):
		s["radius_m"] = float(spec.get("radius_m", 1.8)) * SPOUT_JET_R_K
	elif _source_near(p, at, float(spec.get("source_m", 2.5))):
		var k := float(spec.get("source_mult", 2.0))
		s["radius_m"] = float(spec.get("radius_m", 1.8)) * k
		s["up_mps"] = float(spec.get("up_mps", 12.0)) * (1.0 + (k - 1.0) / 3.0)
		_cur["source"] = true
	var rise := float(spec.get("rise_s", 0.35))
	_cur["spout_at"] = at
	if float(spec.get("bind_s", 0.0)) > 0.0:
		# (Frost Geyser, a bind twist: ice closes round his feet where the water would throw him up; no water column)
		BendLooks.bind_tell(at, "water", float(s.get("radius_m", 1.8)), rise)
	elif way.has("from"):
		_cur["spout_from"] = way.from
		var to := at + Vector3.UP * 0.9
		var from: Vector3 = way.from
		BendLooks.spout_jet(from, at, float(s.get("radius_m", 1.8)), rise)
		BendLooks.geyser(from, to - from, from.distance_to(to) + 0.8, SPOUT_JET_COL_R, rise, false)
	else:
		# (the column: sent from his feet along the deck (geyser_send), the deck breaking there, a column of water out of it;
		# straight up, or leaning. Its water flowed there as it charged (the charge's water look marks the body, WATER_SENT_META,
		# as it is cast): no send)
		if BendStatus.now() - float(p.get_meta(WATER_SENT_META, -INF)) > 1.0:
			BendLooks.geyser_send(p.global_position, at, rise)
		var up: Vector3 = way.get("up", Vector3.UP)
		var cr := clampf(float(s.get("radius_m", 1.8)) * 0.32, 0.45, 1.1)
		BendLooks.geyser(at, up, SPOUT_COL_M * (0.9 if way.has("up") else 1.0), cr, rise, true)
		if not SbFx.fire(p, SbFx.key_of(spec.get("_info", {})), "low", {"at": at, "radius": float(s.get("radius_m", 1.8))}):
			BendLooks.spout(at, float(s.get("radius_m", 1.8)), rise, up)
	var rec := _cur
	var mound := BendLoadout.wears(p, MOUND) and not way.has("from")      # (a jet throws no plug up where it hits)
	var wash := float(spec.get("bind_s", 0.0)) <= 0.0           # (a water column: Frost Geyser's ice throws no water up)
	if rise <= 0.0:
		status_at(p, at, s)
		if wash:
			_wash_gas(p, at, float(s.get("radius_m", 1.8)))
		if mound:
			_cur["mound"] = _mud_mound(p, at)
		return
	p.get_tree().create_timer(rise, false).timeout.connect(func() -> void:
		if not is_instance_valid(p) or not p.is_inside_tree():
			return
		var keep := _cur
		_cur = rec
		status_at(p, at, s)
		if wash:
			_wash_gas(p, at, float(s.get("radius_m", 1.8)))
		if mound:
			_cur["mound"] = _mud_mound(p, at)
		_cur = keep)


## The Geyser's way for `p`'s cast at `at` (BendVariants.of: up, right, left, water): {} up as ever; else {flat (the throw's way
## on the deck), kv_dir, suffix (its class's)} and up (right, left: the column's tilt, the caster's right or left at the cast)
## or from (water: the jet's start, at the nearest water within SPOUT_WATER_M of the mark: a grate or his own puddle
## (Bending.POOLS), or the deck's lip over the tank (RingArena.nearest_lip), the jet rising out of the water below it; none
## near, or the mark on the water itself: up).
const SPOUT_LEAN_DEG := 35.0
const SPOUT_WATER_M := 8.0
## The jet's hit at the mark, of the Geyser's radius (a jet is narrower than a column).
const SPOUT_JET_R_K := 0.8
## The charge's water look (worktree-spellcraft's BendCharge) marks the body with this as a Geyser is cast whose water
## flowed out to its place while it charged (the owner, 2026-10-12: "let it flow there"): no send from his feet then.
const WATER_SENT_META := &"bend_water_sent"
## The column's look (BendLooks.geyser): its height (m) and a jet's thickness.
const SPOUT_COL_M := 3.6
const SPOUT_JET_COL_R := 0.38
static func _spout_way(p: Node3D, at: Vector3, spec: Dictionary) -> Dictionary:
	var info: Dictionary = spec.get("_info", {})
	var way := BendVariants.of(p, String(info.get("move", "wave")), String(info.get("mode", "spout")))
	if way in ["", "up"]:
		return {}
	if way in ["right", "left"]:
		var bc := BendCaster.wrap(p)
		var fwd := bc.facing() if bc != null and bc.valid() else -p.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length_squared() > 1e-4 else Vector3.FORWARD
		var right := fwd.cross(Vector3.UP).normalized()
		var flat := right if way == "right" else -right
		var tilt := deg_to_rad(SPOUT_LEAN_DEG)
		var a := deg_to_rad(40.0)
		return {"up": (Vector3.UP * cos(tilt) + flat * sin(tilt)).normalized(), "flat": flat,
				"kv_dir": (flat * cos(a) + Vector3.UP * sin(a)).normalized(), "suffix": ".lean"}
	# water: the nearest water by the mark
	var best := Vector3.INF
	var best_d := SPOUT_WATER_M
	for n in p.get_tree().get_nodes_in_group(Bending.POOLS):
		var n3 := n as Node3D
		if n3 == null or (n3 is BendZone and (n3 as BendZone).owner_node != p):
			continue
		var d := Vector2(n3.global_position.x - at.x, n3.global_position.z - at.z).length()
		if d < best_d and d > 0.6:
			best = n3.global_position
			best_d = d
	var ra := RingArena.find(p.get_tree())
	if ra != null:
		var lip := ra.nearest_lip(at)
		var lp: Vector3 = lip.point
		var d2 := Vector2(lp.x - at.x, lp.z - at.z).length()
		if d2 < best_d and d2 > 0.6:
			best = lp + (lip.normal as Vector3) * 0.4 + Vector3.DOWN * 0.6      # (out over the water, under the lip)
			best_d = d2
	if best == Vector3.INF:
		return {}                                 # (no water near the mark: up as ever)
	var flat2 := Vector3(at.x - best.x, 0.0, at.z - best.z).normalized()
	var a2 := deg_to_rad(20.0)
	return {"from": best, "flat": flat2, "kv_dir": (flat2 * cos(a2) + Vector3.UP * sin(a2)).normalized(), "suffix": ".side"}


## The gas (a BendZone of kind gas: earth's Sulphur set's cloud) that a Geyser's water rising at `at` `r` m round reaches, whoever's,
## washed away (the skill tree's Washed Ground: "a Wave or a Geyser washes out the gas it passes", for everyone; the Wave's cone is
## the Sulphur set's own, BendGas.cone; Washout adds the Splash and Lash, Cleanse the Turn). No gas in a match (Classic, nobody
## wearing the set): nothing.
static func _wash_gas(p: Node3D, at: Vector3, r: float) -> void:
	if not NetSpells.decides():
		return                                    # (online the host's: its zone's end is told on)
	for z in p.get_tree().get_nodes_in_group(BendZone.GROUP):
		var g := z as BendZone
		if g != null and g.kind == "gas" and not g.is_queued_for_deletion() and absf(g.global_position.y - at.y) < 3.0 \
				and Vector2(g.global_position.x - at.x, g.global_position.z - at.z).length() <= r + g.radius:
			g.wash()


## Mud Mound (a Mud set twist on the Geyser): the plug its water throws up settles where it rose as a low mound of mud
## (MOUND_D: 1.5 m across, 0.7 m high, 3 s): floor fire and rolling stones stop at it, anyone may jump onto it. Low terrain,
## never a wall (never counted in max_walls); MOUNDS_PER_CASTER of his at once, the oldest slumping first.
const MOUND := "water.mud.mound"
const MOUND_D := {"width_m": 1.5, "height_m": 0.7, "thick_m": 1.5, "life_s": 3.0, "rise_s": 0.2}
const MOUNDS_PER_CASTER := 2
## A mound's caster (instance id): its only mark (no bend_by: not his wall).
const MOUND_META := &"bend_mound_by"
## Whether `n` is a Mud Mound (a FormRaised of kind wall for its box, but low terrain: the tree's mound counts_as_wall false).
## The readers that take any raised wall for one (a bot's wall on its line, the Shove's chunk) ask this first.
static func is_mound(n: Object) -> bool:
	return n != null and n.has_meta(MOUND_META)


static func _mud_mound(p: Node3D, at: Vector3) -> FormRaised:
	var wd: Dictionary = SwayMoves.move("earth_wall").get("wall", {})
	var wn := FormMatter.numbers(wd, FormMatter.entry("earth_wall", "mud"), "mud")
	for k: String in MOUND_D:
		wn[k] = MOUND_D[k]
	var way := at - p.global_position
	way.y = 0.0
	way = way.normalized() if way.length_squared() > 1e-4 else -p.global_basis.z
	var x := Vector3.UP.cross(way).normalized()
	var r := FormRaised.raise(p.get_tree().current_scene, "wall", Transform3D(Basis(x, Vector3.UP, way), at), wn, absi(hash(at)) % 97)
	# (its owner under its own meta, never bend_by: every reader of "his raised wall" keys on bend_by (Mend's target, a bot's
	# own wall and stone, Brace, the lessons' wall count, max_walls, the camera's own-wall fade), and a mound is none of them)
	r.set_meta(MOUND_META, p.get_instance_id())
	BendLooks.burst(at + Vector3.UP * 0.4, "stone", 14, Vector3.UP, 70.0, 2.5, 0.3)
	var mine: Array[FormRaised] = []
	for n in p.get_tree().get_nodes_in_group(FormRaised.GROUP):
		var w := n as FormRaised
		if w != null and int(w.get_meta(MOUND_META, 0)) == p.get_instance_id() \
				and w.state != FormRaised.State.CRUMBLING and not w.is_queued_for_deletion():
			mine.append(w)
	mine.sort_custom(func(a: FormRaised, b: FormRaised) -> bool: return a.get_instance_id() < b.get_instance_id())
	while mine.size() > MOUNDS_PER_CASTER:
		mine.pop_front().crumble("capped")
	return r


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
## A BEAM (a spec whose kind is not lightning: air's, the Air Lance since 2026-10-12; the owner: "it will be light lightning but
## straight", "instant cant be sent back only block"): the same flash and strike, drawn as a straight shaft of its kind
## (BendLooks.beam_flash, beam); any guard of the struck one's on the beat stops it whole, a late one lets half through as a
## slide (BendZone.guard_take), nothing sends it back; Lightning's talents and gas are lightning's only.
static func lightning(c: Variant, a: Dictionary, spec: Dictionary) -> void:
	var bc := BendCaster.wrap(c)
	if bc == null:
		return
	var flash := float(spec.get("flash_s", 0.0))
	var rec := _cur
	if flash > 0.0:
		var flashed := SbFx.fire(bc.body, SbFx.key_of(spec.get("_info", {})), "flash", {"at": a.from, "dir": a.dir})
		if is_beam(spec):
			BendLooks.beam_flash(bc.body, a.from, String(spec.kind))
			BendLooks.sound(String(spec.kind), "cast", a.from, -2.0)
		else:
			BendLooks.lightning_flash(bc.body, a.from, not flashed)
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


## Whether lightning's `spec` is a beam (its kind not lightning: the air beam; see lightning).
static func is_beam(spec: Dictionary) -> bool:
	return String(spec.get("kind", "lightning")) != "lightning"


## The lightning's strike from `from` along `dir` (see lightning), written into `rec` (its cast's record): hit, redirected,
## blocked (a beam a guard stopped), struck_at.
static func _strike(bc: BendCaster, from: Vector3, dir: Vector3, flat: Vector3, spec: Dictionary, rec: Dictionary) -> void:
	var p := bc.body
	var beam := is_beam(spec)
	var r := float(spec.get("range_m", 45.0))
	var space := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * r, 0xFFFFFFFF, bc.exclude())
	var h := space.intersect_ray(q)
	var end: Vector3 = h.position if not h.is_empty() else from + dir * r
	var lk := SbFx.key_of(spec.get("_info", {}))
	if not SbFx.fire(p, lk, "strike", {"at": from, "to": end, "dir": dir}):
		if beam:
			BendLooks.beam(from, end, String(spec.kind))
		else:
			BendLooks.lightning(from, end)
	BendLooks.sound(String(spec.kind) if beam else "lightning", "cast", from)
	if not beam and BendZone.BendGas.live_n > 0:
		BendZone.BendGas.live(p, from, end, spec.get("_info", {}))   # (Live Gas: the strike charges the gas it crosses)
	if not beam and FireTalents.any(p):
		rec["live"] = FireTalents.struck(bc, from, end)      # (a worn Forked Lightning's fork to the nearest water)
	var who := BendBolt._taker(h.collider as Node) if not h.is_empty() else null
	rec["hit"] = 0
	rec["struck_at"] = BendStatus.now()
	if who == null or not BendStatus.can_take(who, p):
		return
	var info: Dictionary = spec.get("_info", {})
	var late_k := 1.0
	var back: BendZone = null
	if beam:
		# (a beam: any guard of his on the beat stops it whole, a late one lets half through as a slide; never sent back)
		var g := BendZone.guard_take(who, String(spec.kind), p, info)
		if String(g.result) == "perfect":
			BendLooks.burst(end, String(spec.kind), 18, -dir, 90.0, 3.5, 0.3)
			rec["blocked"] = true
			return
		if String(g.result) == "late":
			late_k = float(g.mult)
			info = g.info
	elif BendR3.stock():
		# (round 3, spec §2.5: only fire's Parry on the beat sends it back; any other guard, or a late Parry, takes it late)
		var lg := BendZone.lightning_guard(who, p, info)
		back = lg.zone if String(lg.result) == "back" else null
		if String(lg.result) == "late":
			late_k = float(lg.mult)
			info = lg.info
	else:
		back = BendZone.lightning_back(who, p)
	if back != null and FireTalents.any(who) and FireTalents.hold_storm(who, spec, info, r):
		rec["redirected"] = true                  # (a worn Hold the Storm with E held: it waits in his arms, FireTalents)
		rec["held"] = true
		return
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
		SbFx.fire(who, SbFx.key_of({}, "fire_parry", "parry"), "lightning_back", {"at": bfrom, "dir": bdir})
		if not SbFx.fire(who, lk, "strike", {"at": bfrom, "to": end2, "dir": bdir, "el": "fire"}):
			BendLooks.lightning(bfrom, end2)
		var who2 := BendBolt._taker(h2.collider as Node) if not h2.is_empty() else null
		rec["redirected"] = true
		if who2 != null and BendStatus.can_take(who2, who):
			var k := BendLoadout.tune_f(who, "rules:guard_rules.perfect_mult", Bending.rule("perfect_mult", 1.2))
			if FireTalents.any(who):
				k = FireTalents.lightning_back_k(who, k)     # (Hold the Storm's x1.1 is fire's only: Lightning keeps x1.2)
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
	SbFx.fire(p, lk, "hit", {"at": end, "dir": dir})
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
	if not SbFx.fire(p, SbFx.key_of(BendR3.cur), "kick_up", {"at": foot, "dir": flat}):
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
	var r: FormRaised = null
	# (its way, BendVariants: up as ever; leaning right or left, it rises tilted and throws them that way; out of the nearest
	# Earth Wall by the mark, a piston from its face. The owner, 2026-10-12: "the column ramp left to shoot them right")
	var lean := _column_way(p, at, spec)
	var xf := Transform3D(Basis.IDENTITY, at)
	if not lean.is_empty():
		xf = lean.xf
		if lean.has("len_m"):
			wn["height_m"] = float(lean.len_m)    # (the wall's piston: out to just short of the mark, never through him)
		else:
			wn["height_m"] = float(wn.get("height_m", 3.0)) * float(lean.get("h_k", 1.0))
	if float(spec.get("bind_s", 0.0)) > 0.0:
		# (Stone Grip, a bind twist: stone closes round his feet where the Column would throw him up; no pillar to stand on)
		BendLooks.bind_tell(at, "earth", float(spec.get("radius_m", 1.3)), rise)
	else:
		r = FormRaised.raise(p.get_tree().current_scene, "pillar", xf, wn, absi(hash(at)) % 97)
		r.set_meta(&"bend_by", p.get_instance_id())
	# (lift_m: the pillar carries whom it rises under up onto its top, where its throw must find him; the owner 2026-10-11, "i
	# dont think the knock column knocks someone up right?": it was looked for within 3 m of the deck, the pillar 3 m tall)
	var sa := {"radius_m": float(spec.get("radius_m", 1.3)), "up_mps": float(spec.get("up_mps", 11.0)),
			"damage": float(spec.get("damage", 10.0)), "kind": "stone", "_lock_s": float(spec.get("_lock_s", -1.0)),
			"_info": spec.get("_info", {}), "lift_m": float(wn.get("height_m", 3.0)) if r != null else 0.0}
	if not lean.is_empty():
		var inf: Dictionary = (spec.get("_info", {}) as Dictionary).duplicate()
		if inf.has("tag"):
			inf["tag"] = String(inf.tag) + String(lean.suffix)       # (its own class: earth_shove/column.lean, .wall)
		inf["dir"] = lean.flat
		sa["_info"] = inf
		sa["kv_dir"] = lean.kv_dir
		sa["lift_m"] = 0.0                       # (it carries no one up: he is thrown where he stands)
	if BendLoadout.wears(p, BendZone.BendGas.COLUMN):
		# (Fuming Column: a gas plume where the pillar rose, its rise and tell the Column's: BendGas)
		BendZone.BendGas.make(p, at, "plume", BendZone.BendGas.PLUME_R, BendZone.BendGas.PLUME_S)
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


## The Column's way for `p`'s cast at `at` (BendVariants.of: up, right, left, wall): {} up as ever; else {xf (the pillar's place,
## tilted), flat (the throw's way on the deck), kv_dir, suffix (its class's), h_k}. Right and left are the caster's at the cast
## (his facing's); wall finds the nearest Earth Wall (anyone's, not ice) within COLUMN_WALL_M of the mark, the piston from its
## face toward the mark, else up.
const COLUMN_LEAN_DEG := 35.0
const COLUMN_WALL_M := 3.5
## The wall's piston stops this short of the mark (m): it strikes and throws him, never pins him against itself.
const COLUMN_PISTON_SHORT_M := 0.5
static func _column_way(p: Node3D, at: Vector3, spec: Dictionary) -> Dictionary:
	var info: Dictionary = spec.get("_info", {})
	var m := String(info.get("move", "earth_shove"))
	var md := String(info.get("mode", "column"))
	var way := BendVariants.of(p, m, md)
	if way in ["", "up"]:
		return {}
	var bc := BendCaster.wrap(p)
	var fwd := bc.facing() if bc != null and bc.valid() else -p.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 1e-4 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP).normalized()
	if way in ["right", "left"]:
		var flat := right if way == "right" else -right
		var tilt := deg_to_rad(COLUMN_LEAN_DEG)
		var up := (Vector3.UP * cos(tilt) + flat * sin(tilt)).normalized()
		var base := at - flat * 0.75
		var z := flat.cross(up).normalized()
		var b := Basis(up.cross(z).normalized(), up, z)
		var a := deg_to_rad(40.0)
		return {"xf": Transform3D(b, base), "flat": flat, "kv_dir": (flat * cos(a) + Vector3.UP * sin(a)).normalized(),
				"suffix": ".lean", "h_k": 0.8}
	# wall: the nearest Earth Wall by the mark
	var best: FormRaised = null
	var best_d := INF
	for n in p.get_tree().get_nodes_in_group(FormRaised.GROUP):
		var w := n as FormRaised
		if w == null or not is_instance_valid(w) or w.kind != "wall" or not w.is_up() or bool(w.get_meta(&"bend_ice", false)):
			continue
		var d := Vector2(w.global_position.x - at.x, w.global_position.z - at.z).length()
		if d < best_d and d <= COLUMN_WALL_M:
			best = w
			best_d = d
	if best == null:
		return {}                                 # (no wall near the mark: up as ever)
	var face := best.global_basis.z
	face.y = 0.0
	face = face.normalized() if face.length_squared() > 1e-4 else Vector3.FORWARD
	if (at - best.global_position).dot(face) < 0.0:
		face = -face                              # (out of the face the mark is on)
	var side := best.global_basis.x.normalized()
	var off := clampf((at - best.global_position).dot(side), -best.size.x * 0.4, best.size.x * 0.4)
	var base2 := best.global_position + side * off + face * (best.size.z * 0.5) + Vector3.UP * 0.9
	var up2 := (face * cos(deg_to_rad(10.0)) + Vector3.UP * sin(deg_to_rad(10.0))).normalized()
	var z2 := side.cross(up2).normalized()
	var b2 := Basis(up2.cross(z2).normalized(), up2, z2)
	var a2 := deg_to_rad(25.0)
	return {"xf": Transform3D(b2, base2), "flat": face, "kv_dir": (face * cos(a2) + Vector3.UP * sin(a2)).normalized(),
			"suffix": ".wall", "len_m": clampf(Vector2(at.x - base2.x, at.z - base2.z).length() - COLUMN_PISTON_SHORT_M, 0.5, 3.5)}


static func _wall(p: Node3D, xf: Transform3D, matter: String, life := -1.0, w := -1.0, ice := false) -> FormRaised:
	var wd: Dictionary = (SwayMoves.move("earth_wall").get("wall", {}) as Dictionary)
	var wn := BendLoadout.wall_numbers(p, "ice", wd, matter) if ice else FormMatter.numbers(wd, FormMatter.entry("earth_wall", matter), matter)
	if life > 0.0:
		wn["life_s"] = life
	if w > 0.0:
		wn["width_m"] = w
	# (raised before a floating teammate it rises to cover him: BendStatus.float_cover)
	wn["height_m"] = maxf(float(wn.get("height_m", 2.0)), BendStatus.float_cover(p, xf.origin))
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
	var r := _wall(p, Transform3D(Basis(x, Vector3.UP, flat), foot), "snow", -1.0, -1.0, true)     # (true: the wearer's Ice Wall numbers)
	r.set_meta(&"bend_ice", true)
	_ice_look(r)
	FormRaised.count_wall(r)                 # (ice walls count with the earth walls: rules.json max_walls)
	if not bool(r.get_meta(&"sbfx_rise", false)):
		BendLooks.burst(foot + Vector3.UP, "ice", 24)
	return r


## An ice wall drawn as ice (earth_wall.wall.materials.ice's shape: smooth, sharp-edged; ToonFx's ice crystal), its rules the
## snow wall's.
static func _ice_look(r: FormRaised) -> void:
	if r == null or r.mesh_instance == null or r.kind != "wall":
		return
	r.mesh_instance.mesh = FormModels.wall_mesh(r.size.x, r.size.y, r.size.z, absi(hash(r.base.origin)) % 97, FormModels.BURY_M, "ice")
	# (the Ice Spear's crystal: flat facets in three blues and a light rim, still ice on its shaded side, where the matter's
	# look went slate)
	r.mesh_instance.material_override = ToonFx.mat("ice")


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
			_ice_look(r)
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
			if not SbFx.fire(p, SbFx.key_of(BendR3.cur), "melt", {"at": fr.global_position, "dir": fr.global_basis.z}):
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
				# (a Mud Mound is low terrain, no wall to tear a chunk from: as the deck, nothing to shove)
				return n as Node3D if (n as FormRaised).is_up() and not is_mound(n) else null
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


## A loose stone earth's Fissure ran under (BendBolt._heave_loose), heaved up where it lies and thrown on at the caster's aim
## as the Shove threw a loose stone (_throw_stone: stone_form.throw and gust.stone.hurl's numbers), carrying the wave's hit
## info `info` (its tag, the Fissure's, grown or not). The Throw (null: no caster).
static func crack_heave(by: Node, st: FormStone, info: Dictionary) -> FormEffects.Throw:
	var bc := BendCaster.of(by)
	if bc == null or not bc.valid() or st == null or not is_instance_valid(st):
		return null
	var keep := BendR3.cur
	BendR3.cur = info
	var th := _throw_stone(bc, st, 1.0)
	BendR3.cur = keep
	return th


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
				if (n is FormRaised and not is_mound(n)) or GustLift.is_stone(n):
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
	var slk := SbFx.key_of(spec.get("_info", {}))
	var floor_at := _floor_under(bc, box)
	if not SbFx.fire(p, slk, "slam", {"dir": box.fwd}):
		if kind == "water":
			# (the Downpour as the water's charge: wisps spiralling down to where it lands, mist and drops there)
			BendLooks.downpour(p.global_position + Vector3.UP * 0.9, floor_at if floor_at != Vector3.INF else box.foot as Vector3)
		else:
			BendLooks.burst(p.global_position + Vector3.UP * 0.4, kind, 30, ((box.foot as Vector3) - p.global_position).normalized(), 25.0, 10.0, 0.4)
	BendLooks.sound(kind, "hit", p.global_position, -2.0)
	_cur["deck"] = floor_at != Vector3.INF
	if floor_at != Vector3.INF:
		if kind != "water" and not SbFx.fire(p, slk, "slam_deck", {"at": floor_at, "dir": box.fwd}):
			BendLooks.burst(floor_at + Vector3.UP * 0.1, kind, 26, Vector3.UP, 70.0, 4.0, 0.4)
		if bool(spec.get("put_out", false)):
			for z in p.get_tree().get_nodes_in_group(BendZone.GROUP):
				var bz := z as BendZone
				if bz != null and bz.kind in ["fire_wall", "burn"] and bz.global_position.distance_to(floor_at) <= float(spec.get("width_m", 2.5)) + 1.5:
					if not SbFx.fire(p, slk, "put_out", {"at": bz.global_position, "dir": box.fwd}):
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
	if not SbFx.fire(bc.body, SbFx.key_of(spec.get("_info", {})), "air_hit", {"at": at, "dir": (a.dir as Vector3) if a.has("dir") else bc.facing()}):
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
		if not SbFx.fire(p, SbFx.key_of(spec.get("_info", {})), "hit_body", {"at": n.global_position + Vector3.UP, "dir": kv, "info": info}):
			BendLooks.burst(n.global_position + Vector3.UP, String(spec.get("kind", "stone")), 18, Vector3.UP, 120.0, 4.0, 0.3)
