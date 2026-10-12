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
##   Near Miss (air.slip.near_miss)     near_m: a near miss in his Slip counts within the node's 1.44 m (BendBolt._near_miss);
##                                      his Slip 8.5 m/s is the node's spec number
##   Second Wind (air.patch.second_wind)  patch_lock: his Patch begun within SECOND_WIND_S of a dash's end locks 1.25 s, else
##                                      1.6 (SwayCaster._lock_time, NpcBending.lock_for; any worn stock:patch.lock_s too)
##   Dragon Fire (air.gust.dragon_fire)  through_ally_fire: his Gust through an ally's Fire Wall (or his Breath while its flame is
##                                      in the smoke, BREATH_HOT_S) carries the flame on FRONT_M as a fire front (a fire floor
##                                      wave of his: FRONT_TAG, 6%, set knock 6); team only (BendZone.on_bolt, before the same
##                                      team's pass); a foe's fire wall still lends his air its flame (today's rule)
## THE BEAT (skill_tree.json "beat", the owner's yes 2026-10-11): a held cast let go within BEAT_S after its lock fills (never a
## click, never a cast that goes by itself). Only a worn technique reads it (beat_worn: its move and mode), so with none worn
## the Beat does nothing: SwayCaster marks the release (its `rel`, BendR3.release) and the cast's hit info carries "beat"
## (BendR3.info_for); a flash on his own hands only (beat_flash). Key 3's moves are clicks: a Beat wearer holding 3 keeps the
## lock till he lets go (SwayCaster._key3_beat_hold); tapped, it is the click it always was. A bot wearing one lets a lock go
## on the Beat at its difficulty's beat_rate (bend_ai.json presets, else BOT_BEAT_RATE) within BEAT_S of its full lock.
##   Carry the Edge (air.slice.carry_edge)  keeps_carry: a Beat Slice with Carried wind charged leaves it charged (BendEffects)
##   Carrying Wind (air.gust.carrying)      on_wind_wave / carry_stones: a Beat Gust throws the loose stones it crosses on along
##                                          its way CARRY_M as pebbles (rock_jab/pebbles: 5%, set knock 3; stone: a Catch holds
##                                          them, walls stop them)
##   Peak Wind (air.leap.peak_wind)         on_dash: a Beat Leap charges his Carried wind at its top (BendZone.carry_wind)

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
const CARRY_EDGE := "air.slice.carry_edge"
const CARRYING := "air.gust.carrying"
const PEAK_WIND := "air.leap.peak_wind"
## The Beat's window (s; skill_tree.json beat.window_s).
const BEAT_S := 0.2
## The techniques that read the Beat, by the move/mode their Beat cast is.
const BEAT_TALENTS := {"air_blast/slice": CARRY_EDGE, "air_gust/gust": CARRYING, "air_jump/leap": PEAK_WIND}
## A bot's share of its locks let go on the Beat by difficulty (the tree's proposal; a preset's beat_rate over it).
const BOT_BEAT_RATE := {"easy": 0.0, "normal": 0.2, "hard": 0.5}
## Carrying Wind: how far a loose stone the Gust takes is thrown on (m).
const CARRY_M := 6.0
const NEAR_MISS := "air.slip.near_miss"
const DRAGON_FIRE := "air.gust.dragon_fire"
## Dragon Fire: the front's tag (its whole class the node's: class:air_gust/gust+fire_front, BendLoadout.worn_class), how far it
## runs (m), and how long an ally's Breath stays fire in its smoke (s: the flame's own warm moment, fx_looks smoke warm_s).
const FRONT_TAG := "air_gust/gust+fire_front"
const FRONT_M := 6.0
const BREATH_HOT_S := 0.5
const SECOND_WIND := "air.patch.second_wind"
## Near Miss: the near-miss search reaches this times the passive's near_m (each body then by its own: near_m).
const NEAR_QUERY_K := 1.5
## Second Wind: a Patch begun this soon after a dash ends takes the quick lock (s).
const SECOND_WIND_S := 0.8


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


# ---------------------------------------------------------------- the Beat
## Whether `body` wears a technique that reads the Beat of move `m` at `mode` (BEAT_TALENTS).
static func beat_worn(body: Node, m: String, mode: String) -> bool:
	var id := String(BEAT_TALENTS.get("%s/%s" % [m, mode], ""))
	return id != "" and BendLoadout.wears(body, id)


## The Beat's cue: a brief glow on his own hands (nothing on anyone else, nothing on the HUD).
static func beat_flash(body: Node) -> void:
	if not (body is Node3D):
		return
	var b3 := body as Node3D
	var at := b3.global_position + Vector3.UP * 1.2 - b3.global_basis.z * 0.35
	var sc := SwayCaster.of(body)
	if sc != null:
		at = sc.hand_point()
	BendLooks.burst(at, "air", 10, Vector3.UP, 180.0, 1.6, 0.14)


## Whether a bot's release of `m` at `mode` now, `since_full` s after its lock filled, goes on the Beat: only a bot wearing
## the technique (a test's: bots never wear loadouts in a match), within BEAT_S, at its difficulty's rate (its own dice).
static func bot_beat(body: Node, m: String, mode: String, since_full: float, preset_name: String) -> bool:
	if not beat_worn(body, m, mode) or since_full > BEAT_S:
		return false
	var pr := NpcBending.preset_of(preset_name)
	var rate := float(pr.get("beat_rate", BOT_BEAT_RATE.get(preset_name, 0.2)))
	if rate <= 0.0:
		return false
	return rate >= 1.0 or (body is NpcFighter and (body as NpcFighter).rng.randf() < rate)


## The cast going now (BendR3.cur, its hit info) was let go on the Beat.
static func on_beat(spec: Dictionary) -> bool:
	return bool((spec.get("_info", {}) as Dictionary).get("beat", false))


# ---------------------------------------------------------------- Carry the Edge
## A carry spec's cast spends the Carried wind it used (BendEffects._apply), except a Beat Slice of a Carry the Edge wearer.
static func keeps_carry(body: Node, m: String, mode: String, spec: Dictionary) -> bool:
	return m == "air_blast" and mode == "slice" and on_beat(spec) and BendLoadout.wears(body, CARRY_EDGE)


# ---------------------------------------------------------------- Carrying Wind
## A wind wave just sent (BendEffects.wind_wave): a Beat Gust of a Carrying Wind wearer carries loose stones (BendBolt's
## carries, carry_stones each frame of its flight).
static func on_wind_wave(body: Node, b: BendBolt, spec: Dictionary) -> void:
	if b == null or bool(spec.get("pull", false)) or not on_beat(spec) or not BendLoadout.wears(body, CARRYING):
		return
	if String((spec.get("_info", {}) as Dictionary).get("move", "")) != "air_gust":
		return
	b.carries = true


## Carrying Wind (see the header): the loose stones lying in the wave's width on this step (whoever's: never one held, raised,
## in flight or sinking) thrown on along its way CARRY_M, each a pebble of the Gust's caster. Once each.
static func carry_stones(b: BendBolt, from: Vector3, step: Vector3) -> void:
	var by := b._by()
	if by == null or not b.is_inside_tree():
		return
	var flat := Vector3(step.x, 0.0, step.z)
	if flat.length_squared() < 1e-8:
		return
	var fwd := flat.normalized()
	var across := Vector3.UP.cross(fwd).normalized()
	for s: Node in b.get_tree().get_nodes_in_group(FormStone.GROUP):
		var st := s as FormStone
		if st == null or st.is_queued_for_deletion() or st.state == FormStone.State.SINKING or GustLift.busy(st) \
				or st.has_meta(&"bend_held_by") or st.has_meta(&"bend_raised_by") or st.has_meta(&"air_carried"):
			continue
		# (in the wave's reach on this step: its front included, so it takes the stone before the stone could stop it)
		var l := st.global_position - from
		var along := l.dot(fwd)
		if along < -b.radius or along > flat.length() + b.radius + st.radius + 0.1 or absf(l.dot(across)) > b.radius + st.radius:
			continue
		if st.global_position.y > from.y + b.radius or st.global_position.y < from.y - b.radius - 1.0:
			continue                                  # (not on the deck under the wave)
		st.set_meta(&"air_carried", true)
		pebble(by, st.global_position + Vector3.UP * maxf(st.radius, 0.1), fwd, st.radius)
		BendLooks.burst(st.global_position, "stone", 8, Vector3.UP, 90.0, 2.5, 0.2)
		st.queue_free()


## A loose stone thrown on by `by`'s wind from `at` along `dir`: a pebble (rock_jab/pebbles' bolt, one of its own: its whole d),
## CARRY_M far. The bolt.
static func pebble(by: Node3D, at: Vector3, dir: Vector3, r: float) -> BendBolt:
	var ps: Dictionary = (SwayMoves.move("rock_jab").get("bend", {}) as Dictionary).get("pebbles", {})
	var info := {"tag": "rock_jab/pebbles", "move": "rock_jab", "mode": "pebbles", "from": at, "air": false,
			"released_at": BendStatus.now(), "volley_n": 1, "carried_by_wind": true}
	var spec := {"kind": "stone", "mps": float(ps.get("mps", 34.0)), "gravity": 0.0, "damage": float(ps.get("damage", 7.0)),
			"knock_mps": float(ps.get("knock_mps", 2.0)), "up_mps": 1.0, "radius_m": clampf(r, 0.08, 0.2), "range_m": CARRY_M,
			"weight": "light", "_lock_s": BendEffects.lock_of("rock_jab", "pebbles"), "_info": info}
	return BendBolt.launch(by, at, dir, spec)


# ---------------------------------------------------------------- Peak Wind
## A dash just begun (BendEffects.dash): a Beat Leap of a Peak Wind wearer charges his Carried wind at its top (his rise
## turned to a fall, PEAK_WATCH_S at most).
static func on_dash(body: Node, spec: Dictionary) -> void:
	var inf: Dictionary = spec.get("_info", {})
	if String(inf.get("move", "")) != "air_jump" or not on_beat(spec) or not BendLoadout.wears(body, PEAK_WIND):
		return
	if not (body is CharacterBody3D) or not body.is_inside_tree():
		return
	var w := PeakWatch.new()
	w.name = "AirPeakWatch"
	body.add_child(w)


## Peak Wind's watch on a Leap's wearer: his rise turned to a fall is the top (his Carried wind charged there), PEAK_WATCH_S at
## most; it frees itself.
class PeakWatch extends Node:
	var rose := false
	var t := 0.0

	func _physics_process(dt: float) -> void:
		t += dt
		var cb := get_parent() as CharacterBody3D
		if cb == null or t > AirTalents.PEAK_WATCH_S:
			queue_free()
			return
		if cb.velocity.y > 0.5:
			rose = true
		elif rose and cb.velocity.y <= 0.0:
			set_physics_process(false)
			BendZone.carry_wind(cb)                   # (the top: his Carried wind, its spiral and whistle on him)
			queue_free()


## Peak Wind: the longest it watches a Leap for its top (s).
const PEAK_WATCH_S := 2.0


# ---------------------------------------------------------------- Near Miss
## How near a bolt must pass `n` in his Slip to charge his Carried wind (m): the passive's `base`, or his worn Near Miss's.
static func near_m(n: Node, base: float) -> float:
	return BendLoadout.tune_f(n, "rules:passives.air.near_m", base)


# ---------------------------------------------------------------- Second Wind (and any worn Patch lock)
## `body`'s Patch lock from `base` (the ring's): a worn stock:patch.lock_s (Second Wind's any other time, Whiteout's); Second
## Wind's quick one when begun within SECOND_WIND_S of a dash's end (BendMotion's bend_dash_end). Classic: `base`.
static func patch_lock(body: Node, base: float) -> float:
	var b := BendLoadout.tune_f(body, "stock:patch.lock_s", base)
	if BendLoadout.wears(body, SECOND_WIND) and BendStatus.now() - float(body.get_meta(&"bend_dash_end", -INF)) <= SECOND_WIND_S:
		b = BendLoadout.tune_f(body, "new:patch.after_dash_lock_s", b)
	return b


# ---------------------------------------------------------------- Dragon Fire
## Bolt `b` in zone `z` (BendZone.on_bolt, before an ally's zone lets it pass): a Dragon Fire wearer's Gust through an ally's
## Fire Wall, or his Breath while its flame is in its smoke, sends a fire front on along its way (fire_front), once a zone. True
## when it did (the Gust flies on either way).
static func through_ally_fire(z: BendZone, b: BendBolt) -> bool:
	if b.spent or b.kind != "air" or b.floor_wave or String(b.info.get("tag", "")) != "air_gust/gust":
		return false
	var by := b._by()
	if by == null or z.owner_node == null or z.owner_node == by or not BendCaster.same_team(by, z.owner_node):
		return false
	var fire := z.kind == "fire_wall" or (z.kind == "smoke" and z.t <= BREATH_HOT_S and BendPoses.element_of(z.owner_node) == "fire")
	if not fire or not BendLoadout.wears(by, DRAGON_FIRE) or not z.inside(b.global_position):
		return false
	var done: Array = b.get_meta(&"air_fronts", [])
	if done.has(z.get_instance_id()):
		return false
	done.append(z.get_instance_id())
	b.set_meta(&"air_fronts", done)
	fire_front(by, b.global_position, Vector3(b.velocity.x, 0.0, b.velocity.z))
	return true


## Dragon Fire's front: a fire floor wave of `by`'s from where his Gust took the flame (`at`) along `way`, FRONT_M (BendBolt's
## floor wave: it runs on the deck, a jump clears it, walls stop it, a Parry takes it). Its hit is FRONT_TAG's class.
static func fire_front(by: Node3D, at: Vector3, way: Vector3) -> BendBolt:
	var flat := way.normalized() if way.length_squared() > 1e-6 else -by.global_basis.z
	var g := FormEffects.ground_at(by, at)
	var info := {"tag": FRONT_TAG, "move": "air_gust", "mode": "gust", "from": g, "air": false, "released_at": BendStatus.now()}
	var spec := {"do": "floor_wave", "kind": "fire", "mps": 16.0, "range_m": FRONT_M, "width_m": 2.4, "height_m": 0.9,
			"damage": 8.0, "knock_mps": 6.0, "up_mps": 2.0, "_lock_s": BendEffects.lock_of("air_gust", "gust"), "_info": info}
	BendLooks.burst(g + Vector3.UP * 0.8, "fire", 22, flat + Vector3.UP * 0.3, 70.0, 5.0, 0.3)
	BendSounds.play(&"fire_crackle", g, 0.0)
	return BendBolt.launch(by, g + flat * 0.4, flat, spec)
