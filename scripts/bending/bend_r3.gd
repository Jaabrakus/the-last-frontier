class_name BendR3
extends RefCounted
## Round 3's cast layer for Tidebreak's % ring (smash_r3 spec §0, §2.1, §4.4, §6, §8, §14.3; AIR): what every caster's
## casts (the player's SwayCaster, a bot's BendCast.cast) send with their hits and do in the air, read from moves.json
## "air_rules" (each key with its safe default in DEFAULTS). Static.
##   the gate     on(body): RingRules.stock_on(), or the body has a RingMoves (installed only in a stock-rules ring); stock():
##                the first alone. With the gate off nothing here changes a number: the hit info rides along unread
##   the hit info info_for(c, m, mode, grown) {tag "id/mode" (+ ".grown"), from (the cast's origin: the caster's chest at the
##                release), air (let go airborne), move, mode, jab (the element's jab), set_stun (its spec's)}; `cur` (the
##                cast landing now: what it makes takes it along: a Throw, a zone); new_volley() (one id for a volley's
##                projectiles); deliver(n, dmg, at, dir, by, lock_s, kv, info): the one way a hit of AIR's lands
##                (BendStatus.hurt, then BendStatus.knock, with one info dictionary whose hit_id is fresh), the jab string
##                and its Pop first, the caster told after (SwayCaster.note_hit: landing lag, the jab step)
##   the jab      jab_cast(bc, info) at each jab's release (a jab that hit nothing ends the string), jab_hit at each jab that
##                lands (the step, the Pop, earth's Pop stone), jab_guarded(by) (a guard ends it); BendCaster.jab holds a
##                caster's string, BendCaster.jab_step_until its next jab's ready time
##   the air      airborne(body) (its RingMoves', else off the floor)
##   the stage    arena(tree), keep_on_deck(tree, p, inset) (a point kept inset inside the deck's lip: Column and Geyser),
##                off_lip(tree, p, clear) (a wall's place kept clear of every lip), past_lip(tree, p) (metres out past it)

## The safe defaults of moves.json "air_rules".
const DEFAULTS := {
	"key3_min_s": 0.22, "guard": {"hold_max_s": 2.5, "drop_s": 0.1}, "out_after_s": 0.15, "slam_out_after_s": 0.2,
	"strike_out_min_s": 0.35, "land_lag": {"jab": 0.1, "quick": 0.2, "big": 0.25, "lightning": 0.35, "slam": 0.3,
	"key2": 0.25, "guard": 0.0}, "land_lag_hit_mult": 0.5, "lag_class": {}, "jab_step_s": 0.15, "jab_string_gap_s": 0.6,
	"pop": {"hits": 3, "set_mps": 9.0, "angle_deg": 80.0, "set_stun": 0.6, "tag": "jab/pop", "stone_tag": "rock_jab/pop_stone",
	"stone": {"radius_m": 0.22, "mps": 34.0, "damage": 30.0, "knock_mps": 6.0, "gravity": 3.0}},
	"wall_lip_clear_m": 3.5, "floor_wave_lip_over_m": 0.3, "air_stone_reach_m": 12.0,
	"fire_wall": {"entry_every_s": 1.0, "entry_mps": 5.0, "entry_deg": 50.0}, "deck_inset_m": 0.6,
}
## The Pop's look at contact by element (BendLooks.burst kinds): earth's stone fist, water's crest, fire's flame column,
## air's updraft.
const POP_BURST := {"earth": "stone", "water": "water", "fire": "fire", "air": "air"}
## The meta on a stone earth's Pop left in the hand (E throws it: the Pop's stone, not a return).
const POP_STONE_META := &"bend_pop_stone"
## The meta on a stone a guard caught: the tag of the move it was (a return's origin_tag).
const ORIGIN_META := &"bend_origin_tag"

## The info of the cast landing now ({} none): BendEffects.apply and FormEffects.apply set it while the cast's things are
## made, and what they make (a Throw, a zone) takes a copy.
static var cur := {}
## The release of the cast landing now ({air, at}; {} none: now's): SwayCaster sets it while a cast that waited on its
## strike lands, so its air and its release time are the release's.
static var release := {}
static var _hit_n := 0
static var _volley_n := 0
## Tests only: the hits delivered ({n, by, tag, info, kv}), newest last, at most 64 (cleared by the tests).
static var hits_log: Array = []


# ---------------------------------------------------------------- the data
static func rules() -> Dictionary:
	var have: Variant = SwayMoves.data().get("air_rules", {})
	return have if have is Dictionary else {}


static func num(key: String, def := 0.0) -> float:
	return float(rules().get(key, DEFAULTS.get(key, def)))


static func block(key: String) -> Dictionary:
	var out: Dictionary = (DEFAULTS.get(key, {}) as Dictionary).duplicate(true) if DEFAULTS.get(key) is Dictionary else {}
	var have: Variant = rules().get(key)
	if have is Dictionary:
		out.merge(have as Dictionary, true)
	return out


# ---------------------------------------------------------------- the gate
static func stock() -> bool:
	return RingRules.stock_on()


static func on(body: Node) -> bool:
	return RingRules.stock_on() or (body != null and is_instance_valid(body) and RingMoves.of(body) != null)


## Whether `body` is in the air now: its RingMoves' answer, else off the floor.
static func airborne(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	var rm := RingMoves.of(body)
	if rm != null:
		return rm.airborne()
	var cb := body as CharacterBody3D
	return cb != null and not cb.is_on_floor()


# ---------------------------------------------------------------- the hit info (spec §14.3)
## "id/mode", "id/mode.grown" when it grew.
static func tag_of(m: String, mode: String, grown := false) -> String:
	return "%s/%s%s" % [m, mode, ".grown" if grown else ""]


## Whether move `m` at `mode` is its element's jab (Bending.jab), or its Pop.
static func is_jab(m: String, mode: String) -> bool:
	var el := Bending.element_of(m)
	var jb := Bending.jab(el)
	return not jb.is_empty() and String(jb.id) == m and (String(jb.mode) == mode or mode == "pop")


## The info a cast of `m` at `mode` by caster `c` sends with its hits (see the header). `spec`: its bend spec (set_stun).
static func info_for(c: Variant, m: String, mode: String, grown := false, spec := {}) -> Dictionary:
	var bc := BendCaster.wrap(c)
	var out := {"tag": tag_of(m, alias_of(m, mode), grown), "move": m, "mode": mode,
			"from": bc.chest() if bc != null and bc.valid() else Vector3.ZERO,
			"air": bool(release.get("air", airborne(bc.body) if bc != null and bc.valid() else false)),
			"released_at": float(release.get("at", BendStatus.now()))}
	if is_jab(m, mode):
		out["jab"] = true
	if spec.has("set_stun"):
		out["set_stun"] = float(spec.set_stun)
	if float(spec.get("bind_s", 0.0)) > 0.0:
		out["bind_s"] = float(spec.bind_s)            # (a bind twist's hit: the feet held, no launch; RingRules.on_hit)
	if float(spec.get("drench_s", 0.0)) > 0.0:
		out["drench_s"] = float(spec.drench_s)        # (Drenching Wave's hit: he runs slower a while; RingRules.on_hit)
	if bool(release.get("beat", false)):
		out["beat"] = true                            # (let go on the Beat by a wearer it pays: BendLoadout.beat_paid; Heave's class)
	return out


## The mode a hidden mode of `m` stands for (its spec's "as": the Pop's jab, the air High Kick's), else `mode` itself.
static func alias_of(m: String, mode: String) -> String:
	var b: Variant = SwayMoves.move(m).get("bend", {})
	var s: Variant = (b as Dictionary).get(mode) if b is Dictionary else null
	if s is Dictionary and (s as Dictionary).has("as"):
		return String((s as Dictionary).get("as", mode))
	return mode


## A fresh volley id (Pebbles' three, Embers' seven: one hit for the rules, PERCENT splitting its d).
static func new_volley() -> int:
	_volley_n += 1
	return _volley_n


## The one way a hit lands (see the header): `n` hurt by `dmg` and knocked along `kv` by `by`, the same info on both (its
## own copy, a fresh hit_id). With the gate on the jab string's turn first (a Pop changes the knock, the tag and the stun).
## Online (NetSpells, docs/tidebreak/ring_netcode.md "Hits"): decided by the host only (a ghost's hit is nothing); on a
## puppet the hit itself goes to its owner, who takes it on his own body (take), and the hitter's side of it (his jab
## string, his note of the hit) to the hitter's owner (hit_by).
static func deliver(n: Node, dmg: float, at: Vector3, dir: Vector3, by: Node, lock_s: float, kv: Vector3, info: Dictionary) -> void:
	if n == null or not is_instance_valid(n):
		return
	if by != null and not is_instance_valid(by):
		by = null
	if not BendStatus.can_take(n, by):
		return
	var gate := NetSpells.on_body(n)
	if gate == NetSpells.SKIP:
		return
	var inf := info.duplicate()
	_hit_n += 1
	inf["hit_id"] = _hit_n
	if stock() and by != null:
		if BendCombo.finishers():
			# (the combo rules, the owner 2026-10-15: no jab string; a full combo's next hit is the finisher)
			var fin := BendCombo.take_finisher(by, n, inf)
			if fin != "":
				kv = finish(by, n, inf, at, fin == "first")
		elif bool(inf.get("jab", false)):
			kv = jab_hit(by, n, inf, kv, at)
	if gate == NetSpells.FORWARD:
		NetSpells.forward("hit", n, [dmg, at, dir, by, lock_s, kv, inf])
	else:
		take(n, dmg, at, dir, by, lock_s, kv, inf)
	if by != null:
		if NetSpells.owns(by):
			_noted(by, n, inf)
		else:
			var bc0 := BendCaster.of(by)
			NetSpells.to_attacker("hit_by", by, [n, inf, bc0.jab if bc0 != null else {}])


## A hit on `n` taken on his own body (deliver's, or the host's word to his owner: NetSpells.apply_hit): hurt, knocked, his
## lock told; logged.
static func take(n: Node, dmg: float, at: Vector3, dir: Vector3, by: Node, lock_s: float, kv: Vector3, inf: Dictionary) -> void:
	if n == null or not is_instance_valid(n):
		return
	if by != null and not is_instance_valid(by):
		by = null
	BendStatus.hurt(n, dmg, at, dir, by, lock_s, inf)
	BendStatus.knock(n, kv, by, inf)
	if hits_log.size() >= 64:
		hits_log.pop_front()
	hits_log.append({"n": n, "by": by, "tag": String(inf.get("tag", "")), "info": inf, "kv": kv, "at": BendStatus.now()})
	var vs := SwayCaster.of(n)
	if vs != null and not bool(inf.get("no_hurt", false)):
		vs.took_hit()                              # (the struck one's lock: Lightning's charge breaks, nothing else; a matter
		                                           # tick's no_hurt hit never: the tree's tick contract)


## The hitter's side of a hit (deliver): his SwayCaster's note of it (landing lag, the jab step), his last hit's time.
static func _noted(by: Node, n: Node, inf: Dictionary) -> void:
	var sc := SwayCaster.of(by)
	if sc != null:
		sc.note_hit(n, inf)
	var bc := BendCaster.of(by)
	if bc != null:
		bc.last_hit_at = BendStatus.now()
	AirTalents.on_hit(by, n, inf)                  # (a worn air talent's side of his hit: Tailwind; Classic none)


## The host's word to hitter `by`'s owner that his hit on `n` (`inf`) landed (NetSpells.apply_hit): his jab string as the
## host keeps it (`jab`: its count, its Pop; its times this machine's now), then his note of the hit (_noted).
static func hit_by(by: Node, n: Node, inf: Dictionary, jab: Dictionary) -> void:
	if by == null or not is_instance_valid(by):
		return
	var bc := BendCaster.of(by)
	if bc != null and not jab.is_empty():
		var st := bc.jab.duplicate()
		for k: String in ["hits", "popped", "volley", "volleys", "pop_volley"]:
			if jab.has(k):
				st[k] = jab[k]
		st["hit_last"] = true
		st["at"] = BendStatus.now()
		st["victim"] = n.get_instance_id() if n != null and is_instance_valid(n) else 0
		bc.jab = st
		if not bool(st.get("popped", false)) and int(st.get("hits", 0)) > 0:
			bc.jab_step_until = float(inf.get("released_at", BendStatus.now())) + num("jab_step_s")   # (the step: as the host's)
	_noted(by, n, inf)


## A knock along the class's set speed `mps` at `deg` up from the flat `flat` (a set launch's vector).
static func set_v(flat: Vector3, mps: float, deg: float) -> Vector3:
	var f := Vector3(flat.x, 0.0, flat.z)
	f = f.normalized() if f.length_squared() > 1e-6 else Vector3.FORWARD
	var a := deg_to_rad(deg)
	return f * mps * cos(a) + Vector3.UP * mps * sin(a)


# ---------------------------------------------------------------- the jab string (spec §6.4)
## A jab of caster `c` let go now (BendEffects.apply): the one before it that hit nothing ends the string (a miss: step 1
## again); the step it was owed is spent.
static func jab_cast(c: Variant) -> void:
	var bc := BendCaster.wrap(c)
	if bc == null:
		return
	var st := bc.jab
	if int(st.get("casts", 0)) > 0 and not bool(st.get("hit_last", true)):
		_reset(bc)
		st = bc.jab
	st["casts"] = int(st.get("casts", 0)) + 1
	st["hit_last"] = false
	st["released_at"] = BendStatus.now()
	bc.jab_step_until = -INF
	bc.jab = st


## The jab string of `bc` back to step 1.
static func _reset(bc: BendCaster) -> void:
	bc.jab = {"hits": 0, "popped": false, "victim": 0, "at": -INF, "volley": 0, "casts": 0, "hit_last": true}
	bc.jab_step_until = -INF


## PERCENT's string on `victim` ended (RingRules.string_ended): `by`'s jab string on him starts over (one Pop a string).
static func _on_string_ended(by: Node, victim: Node3D, _hits: int, _pct: float) -> void:
	NetSpells.string_ended(by, victim)          # (online: the hitter's string is kept on the host and on his own machine)
	var bc := BendCaster.of(by) if by != null and is_instance_valid(by) else null
	if bc != null and victim != null and int(bc.jab.get("victim", 0)) == victim.get_instance_id():
		_reset(bc)


## The current RingRules' string_ended heard (once a RingRules).
static func _hear_strings() -> void:
	var rr := RingRules.current()
	if rr == null:
		return
	var cb := Callable(BendR3, "_on_string_ended")
	if not rr.string_ended.is_connected(cb):
		rr.string_ended.connect(cb)


## A guard took `by`'s jab: the string back to step 1 (online the host's word to his owner too: NetSpells).
static func jab_guarded(by: Node) -> void:
	if by != null and is_instance_valid(by) and not NetSpells.owns(by) and NetSpells.decides():
		NetSpells.to_attacker("jab_guarded", by, [])
	var bc := BendCaster.of(by)
	if bc != null:
		_reset(bc)


## Whether `by`'s jab string on `victim` has its Pop armed (the next jab that hits is it): two hits, no Pop yet, the last
## within jab_string_gap_s. Under the combo's finishers (BendCombo.finishers) his combo full instead: the jab is the Pop.
static func pop_armed(by: Node, victim: Node = null) -> bool:
	if BendCombo.finishers():
		return BendCombo.finisher_ready(by)
	var bc := BendCaster.of(by)
	if bc == null:
		return false
	var st := bc.jab
	if victim != null and int(st.get("victim", 0)) != victim.get_instance_id():
		return false
	return int(st.get("hits", 0)) == int(block("pop").get("hits", 3)) - 1 and not bool(st.get("popped", false)) \
			and BendStatus.now() - float(st.get("at", -INF)) <= num("jab_string_gap_s")


## A jab of `by` landing on `victim` (deliver, the gate on): the string counted (one count a volley), the step owed, and
## the third that hits the Pop: its tag, set stun and set knock (straight up from `by` toward him) written into `inf`, its
## burst at `at`, earth's stone left in `by`'s hand. The knock to apply.
static func jab_hit(by: Node, victim: Node, inf: Dictionary, kv: Vector3, at: Vector3) -> Vector3:
	var bc := BendCaster.of(by)
	if bc == null:
		return kv
	_hear_strings()
	var st := bc.jab
	var now := BendStatus.now()
	var vol := int(inf.get("volley_id", 0))
	var pop := block("pop")
	var counted: Array = st.get("volleys", [])
	if vol != 0 and vol in counted:
		# (another projectile of a volley already counted: the same hit for the rules, the Pop's tag on it too)
		if vol == int(st.get("pop_volley", 0)):
			_pop_info(inf, pop)
			return _pop_v(by, victim, pop)
		return kv
	if int(st.get("victim", 0)) != victim.get_instance_id() or now - float(st.get("at", -INF)) > num("jab_string_gap_s"):
		_reset(bc)
		st = bc.jab
		st["casts"] = 1
	st["victim"] = victim.get_instance_id()
	st["at"] = now
	st["volley"] = vol
	st["hit_last"] = true
	if vol != 0:
		var vs: Array = st.get("volleys", [])
		vs.append(vol)
		if vs.size() > 8:
			vs.pop_front()
		st["volleys"] = vs
	var hits := int(st.get("hits", 0)) + 1
	st["hits"] = hits
	var kv_out := kv
	if hits == int(pop.get("hits", 3)) and not bool(st.get("popped", false)):
		st["popped"] = true
		st["pop_volley"] = vol
		_pop_info(inf, pop)
		kv_out = _pop_v(by, victim, pop)
		_pop_look(by, at)
		if BendPoses.element_of(by) == "earth":
			pop_stone(bc)
	elif not bool(st.get("popped", false)):
		bc.jab_step_until = float(inf.get("released_at", now)) + num("jab_step_s")    # (the step: decided at the hit)
	bc.jab = st
	return kv_out


## `by`'s finisher landing on `n` (BendCombo.take_finisher: his full combo's next hit; the owner, 2026-10-15, "your next skill
## launches them the way the Pop does now, and the meter empties"; `first`: not the rest of its volley): the jab's is its Pop
## (its tag; earth's stone left in his hand), any other skill keeps its own % and launches as the Pop does (info.finisher:
## RingRules.finisher_class); the Pop's burst at the point. The knock: the Pop's.
static func finish(by: Node, n: Node, inf: Dictionary, at: Vector3, first: bool) -> Vector3:
	var pop := block("pop")
	inf["finisher"] = true
	if bool(inf.get("jab", false)):
		_pop_info(inf, pop)
	else:
		inf["set_stun"] = float(pop.get("set_stun", 0.6))
	if first:
		_pop_look(by, at)
		if bool(inf.get("jab", false)) and BendPoses.element_of(by) == "earth":
			pop_stone(BendCaster.of(by))
	return _pop_v(by, n, pop)


static func _pop_info(inf: Dictionary, pop: Dictionary) -> void:
	inf["tag"] = String(pop.get("tag", "jab/pop"))
	inf["set_stun"] = float(pop.get("set_stun", 0.6))
	inf["pop"] = true


static func _pop_v(by: Node, victim: Node, pop: Dictionary) -> Vector3:
	var flat := (victim as Node3D).global_position - (by as Node3D).global_position
	return set_v(flat, float(pop.get("set_mps", 9.0)), float(pop.get("angle_deg", 80.0)))


## The Pop's element burst at contact (on the hit, not on the one struck: a puff at the point).
static func _pop_look(by: Node, at: Vector3) -> void:
	var el := BendPoses.element_of(by)
	if SbFx.fire(by, "%s/pop" % String(Bending.jab(el).get("id", "")), "pop", {"at": at}):
		return                                   # (the Pop's Spellbreak burst played instead: SbFx)
	var kind := String(POP_BURST.get(el, "air"))
	BendLooks.burst(at, kind, 34, Vector3.UP, 30.0, 7.0, 0.35)
	BendLooks.burst(at + Vector3.UP * 0.8, kind, 20, Vector3.UP, 15.0, 9.0, 0.3)


## Earth's Pop: the stone fist's stone stays in the caster's hand, held as a caught stone is (none when he holds one): E
## throws it (BendZone.return_stone: the Pop's stone, its own tag, not a return). The stone (null none).
static func pop_stone(bc: BendCaster) -> FormStone:
	if bc == null or not bc.valid() or BendZone.held_stone(bc.body) != null:
		return null
	var p := bc.body
	var sd := block("pop").get("stone", {}) as Dictionary
	var out := bc.facing()
	var front := p.global_position + out * 0.55 + out.cross(Vector3.UP).normalized() * 0.45 + Vector3.UP * 1.25    # (in the right hand, off the line of fire)
	var s := FormStone.ball(p.get_tree().current_scene, front, {"radius_m": float(sd.get("radius_m", 0.22)), "mass_kg": 20.0,
			"rise_s": 0.01, "life_s": 30.0, "sink_s": 1.0}, absi(hash(Vector3i(front * 10.0))) % 97, "stone")
	s.state = FormStone.State.RESTING
	s.base = Transform3D(Basis.IDENTITY, front)
	s.global_transform = s.base
	s.freeze = true
	s.set_meta(&"bend_held_by", p.get_instance_id())
	s.set_meta(POP_STONE_META, true)
	s.set_meta(&"bend_stone_d", {"mps": float(sd.get("mps", 34.0)), "damage": float(sd.get("damage", 30.0)),
			"knock_mps": float(sd.get("knock_mps", 6.0)), "gravity": float(sd.get("gravity", 3.0)), "pierce": false})
	if not SbFx.start(s, "held", p, "rock_jab/pop", "held", {"node": s, "dir": out}):
		BendLooks.burst(front, "stone", 12)
	return s


# ---------------------------------------------------------------- the stage
static func arena(tree: SceneTree) -> RingArena:
	return RingArena.find(tree) if tree != null else null


## Metres point `p` is out past the deck's nearest lip (negative inside; 0 with no arena).
static func past_lip(tree: SceneTree, p: Vector3) -> float:
	var ar := arena(tree)
	if ar == null:
		return -INF
	return float(ar.nearest_lip(p).get("out_m", 0.0))


## Point `p` kept at least `inset` m inside every lip of the deck (on its top): Column and Geyser never rise from the tank.
static func keep_on_deck(tree: SceneTree, p: Vector3, inset: float) -> Vector3:
	var ar := arena(tree)
	if ar == null:
		return p
	var l := ar.to_local(p)
	var hl := maxf(ar.half_l() - inset, 0.0)
	var hw := maxf(ar.half_w() - inset, 0.0)
	if absf(l.x) <= hl and absf(l.z) <= hw and absf(l.y - ar.top()) < 1.0:
		return p
	l.x = clampf(l.x, -hl, hl)
	l.z = clampf(l.z, -hw, hw)
	l.y = ar.top()
	return ar.to_global(l)


## A wall's place `p` kept `clear` m inside every lip (RingArena.wall_place_ok first, then the corners too): no wall seals a
## grab spot. As given with no arena.
static func off_lip(tree: SceneTree, p: Vector3, clear: float) -> Vector3:
	var ar := arena(tree)
	if ar == null:
		return p
	p = ar.wall_place_ok(p)
	var l := ar.to_local(p)
	var hl := maxf(ar.half_l() - clear, 0.0)
	var hw := maxf(ar.half_w() - clear, 0.0)
	if absf(l.x) <= hl and absf(l.z) <= hw:
		return p
	l.x = clampf(l.x, -hl, hl)
	l.z = clampf(l.z, -hw, hw)
	return ar.to_global(l)
