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
##                                      new:air_shield.perfect_carry_s (0.4 s). A bot wearing it (a test's) holds each catch
##                                      BOT_EYE_S of its own choosing, then sends it along its aim at its foe
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
##   Dust Cloud (air.slot.dust)         a new skill, 4 tapped twice (the Wind Wall's key had one move): talent mode air_wall/dust
##                                      (moves.json air_wall.talent_bend.dust: a 3 m dust cloud placed 2-6 m off for 2.5 s, one
##                                      at a time, lock 0.9 s; it hides as smoke does). extra_modes / modes_for (SwayCaster.
##                                      my_modes, Bending.other_move), talent_spec (spec_of, FormEffects.apply, BendCast.cast),
##                                      talent_lock (SwayCaster._lock_time, NpcBending.lock_for), pose_mode (BendPoses.pick:
##                                      the Wind Wall's pose), label
##   Frostwind (air.set.frostwind)      the skill set: frosts / frost_step (BendBolt.launch, its flight): his Gust or Wind Ball
##                                      turns a puddle or a grate it crosses into crust (freeze_pool, make_crust: a snow
##                                      FormRaised ridge CRUST_W x CRUST_H for CRUST_S, CRUST_CAP of his at once; floor waves and
##                                      rolling stones stop at it, anyone can jump it: a bot running at one jumps it,
##                                      crust_ahead in NpcFighter._ring_move; never slippery); a frozen grate is out of
##                                      Bending.POOLS (no source) till its crust goes, however it goes (the round's reset frees
##                                      it: CrustWatch._exit_tree); only while the bolt is still his (frost_step: sent back or
##                                      turned, it freezes nothing); steam it crosses falls as snow and clears;
##                                      his Wind Wall drops water and ice as shards (wall_shards, BendZone.on_bolt); fire melts a
##                                      crust (melt_crust in BendBolt._hit, a Breath's BendEffects.melt, a Fire Wall or burning
##                                      ground on it: CrustWatch) back into its puddle (a grate's back into the grate); his Wind
##                                      Wall 3.5 s (the set's spec number)
##   Hail Ball (air.frost.hail_ball)    hails / hail_burst (BendBolt.launch, _finish): where his Wind Ball hits or ends, HAIL_N
##                                      hailstones fall HAIL_R round it, each 2% to a foe within HAIL_HIT_M (its class the
##                                      node's matter/hail: no knock, no flinch, no hurt); its knock base 7 (a class number)
##   Frost Gust (air.frost.frost_gust)  snuffs (BendZone.on_bolt): his Gust puts out a foe's Fire Wall or burning ground it
##                                      crosses (today air takes the flame); 1.8 m wide (a spec number)
##   Rime Wall (air.frost.rime_wall)    on_wall_end (BendZone.end): his Wind Wall ending drops a crust where it stood (RIME_S);
##                                      its push 3.2 m/s (the zone's push_mps, from its spec)
##   Blizzard (air.frost.blizzard)      a new skill, 4 tapped twice: talent mode air_wall/blizzard (moves.json talent_bend: a
##                                      2.5 m snow column 2-10 m off where he aims, 3 s, one at a time, lock 0.9 s); snow_every
##                                      (BendZone._every of kind snow): it freezes water in it, a foe inside gains 1% each 0.5 s
##                                      (the node's matter/cold, no knock, no hurt; 6% at most), fire on it melts it out in 1 s
##                                      (melt_snow; a fire bolt through it: BendZone.on_bolt; a Breath into it: breath_melt
##                                      from BendEffects.cone; a Fire Wall or burning ground on it); it hides both ways (snow in
##                                      NpcBendCaster.HIDING); his Wind Wall 15% shorter (wall_life_k, BendEffects' wind_wall)
##   Whiteout (air.frost.whiteout)      home_fill (SwayCaster._hold, NpcBending's lock): his locks fill x1.15 standing on his
##                                      own crust or in his own Blizzard; Patch 1.7 s (patch_lock)
##   Toxic Gale (air.ball.toxic_gale)   toxic_gale (BendZone.on_bolt, first): his Wind Ball through a gas cloud (a BendZone of
##                                      kind gas: earth's Sulphur set's, built in its own lane; anyone's) bursts it GALE_M on
##                                      along its way into a GALE_R cloud with the time it had left, his now (its ticks his
##                                      foes'); his Wind Ball adds 10% (a class number). Built against the gas zone's interface
##                                      (kind, owner_node, radius, t, life_s): with no Sulphur set in a match it never meets gas
## THE BEAT (skill_tree.json "beat", the owner's yes 2026-10-11): a held cast let go within BEAT_S after its lock fills (never a
## click, never a cast that goes by itself). Only a worn technique reads it (beat_worn: its move and mode), so with none worn
## the Beat does nothing: SwayCaster marks the release (its `rel`, BendR3.release) and the cast's hit info carries "beat"
## (BendR3.info_for); a flash on his own hands only (beat_flash). Key 3's moves are clicks and stay so (the Leap goes the
## moment its lock is full, held or tapped, as ever): its Beat is read from the let go instead (key3_cast, key3_let_go):
## key 3 still held as the Leap goes and let go within BEAT_S of the full lock is on the Beat; tapped (let go before full), or
## held on past the window, it is not. A bot wearing one lets a lock go on the Beat at its difficulty's beat_rate
## (bend_ai.json presets, else BOT_BEAT_RATE) within BEAT_S of its full lock.
##   Carry the Edge (air.slice.carry_edge)  keeps_carry: a Beat Slice with Carried wind charged leaves it charged (BendEffects)
##   Carrying Wind (air.gust.carrying)      on_wind_wave / carry_stones: a Beat Gust throws the loose stones it crosses on along
##                                          its way CARRY_M as pebbles (rock_jab/pebbles: 5%, set knock 3; stone: a Catch holds
##                                          them, walls stop them)
##   Peak Wind (air.leap.peak_wind)         on_dash: a Beat Leap charges his Carried wind at its top (BendZone.carry_wind);
##                                          the Leap itself is Classic's (it goes at its full lock, as high as ever)

const FormMatter := preload("res://scripts/sway/form_matter.gd")
const TAILWIND := "air.slice.tailwind"
const TOXIC_GALE := "air.ball.toxic_gale"
## Toxic Gale: how far on its Wind Ball bursts a gas cloud (m), and the cloud's radius then (the node: "radius 4").
const GALE_M := 4.0
const GALE_R := 4.0
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
## The Beat's window (s; skill_tree.json beat.window_s), and the clock's slack in it (s: a let go on the window's last frame
## counts).
const BEAT_S := 0.2
const BEAT_EPS := 1e-4
## The techniques that read the Beat, by the move/mode their Beat cast is.
const BEAT_TALENTS := {"air_blast/slice": CARRY_EDGE, "air_gust/gust": CARRYING, "air_jump/leap": PEAK_WIND}
## A bot's share of its locks let go on the Beat by difficulty (the tree's proposal; a preset's beat_rate over it).
const BOT_BEAT_RATE := {"easy": 0.0, "normal": 0.2, "hard": 0.5}
## Carrying Wind: how far a loose stone the Gust takes is thrown on (m).
const CARRY_M := 6.0
const NEAR_MISS := "air.slip.near_miss"
const DUST := "air.slot.dust"
const FROSTWIND := "air.set.frostwind"
## Frostwind's crust: a low ice ridge (m: long, high, thick), how long it lies (s), how many of a caster's stand at once, how
## near a grate's middle a bolt must pass to freeze it (m), and the metas: a crust's maker (instance id), a grate frozen.
const CRUST_W := 3.0
const CRUST_H := 0.4
const CRUST_T := 0.5
const CRUST_S := 4.0
const CRUST_CAP := 2
const GRATE_R := 1.0
const CRUST_META := &"air_crust_by"
const FROZEN_META := &"air_frozen"
const HAIL_BALL := "air.frost.hail_ball"
const FROST_GUST := "air.frost.frost_gust"
const RIME_WALL := "air.frost.rime_wall"
const BLIZZARD := "air.frost.blizzard"
const WHITEOUT := "air.frost.whiteout"
## Hail Ball: its hailstones, how far round where the ball ends they fall (m), how near one must fall to strike (m), their tag.
const HAIL_N := 3
## Frost Gust: how far under a Gust's middle its wave reaches down to the deck (m; its spec's height_m 2 from a chest-high cast).
const GUST_REACH_DOWN_M := 1.6
const HAIL_R := 1.2
const HAIL_HIT_M := 0.8
const HAIL_TAG := "matter/hail"
## Rime Wall: its crust's life (s).
const RIME_S := 3.0
## Blizzard: the cold tick's tag, its ticks from one Blizzard at most (1% each: 6%), how soon fire melts it out (s); the matter
## tick's rate a body (s; tick_contract) and its meta (when he last took one, from any matter).
const COLD_TAG := "matter/cold"
const COLD_CAP := 6
const SNOW_MELT_S := 1.0
const MATTER_EVERY_S := 0.5
const MATTER_TICK_META := &"bend_matter_tick_at"
## Whiteout: the fill on his own frost.
const HOME_FILL := 1.15
## The new skills a worn talent adds as a mode of a move on an empty double tap: id -> [move, mode] (their specs: moves.json
## <move>.talent_bend).
const TALENT_MODES := {"air.slot.dust": ["air_wall", "dust"], "air.frost.blizzard": ["air_wall", "blizzard"]}
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


## Whether a direction key pressed now by `body` (moving at `vel`) with his guard up steers his walk instead of rolling
## (RingMoves._try_ground_dodge): a Drift Guard wearer (the player's keys: a bot's roll is its own press) already walking with
## it up (DRIFT_STEER_MPS). Standing under his guard, a key pressed is the guard's Roll, as for everyone.
static func drift_steers(body: Node, vel: Vector3) -> bool:
	return body is FrontierPlayer and Vector2(vel.x, vel.z).length() > DRIFT_STEER_MPS and drifts(body)


## Drift Guard: how fast he must already walk under his guard for a key pressed to steer it (m/s).
const DRIFT_STEER_MPS := 0.5


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
## perfect_mult as the bounce. A bot wearing it (a test's: bots never wear loadouts in a match) has no E: it holds every catch
## a moment of its own choosing (bot_eye_s) and sends it along its aim at its foe. True when it took it (else the bounce goes
## straight back, today's).
static func eye_catch(z: BendZone, b: BendBolt) -> bool:
	var owner := z.owner_node
	if not BendLoadout.wears(owner, EYE) or b.floor_wave:
		return false
	var hold: Callable
	if SwayCaster.of(owner) != null:
		if not guard_held(owner):
			return false
		hold = guard_held.bind(owner)
	else:
		hold = _held_till.bind(BendStatus.now() + bot_eye_s(owner))
	var k := BendLoadout.tune_f(owner, "rules:guard_rules.perfect_mult", Bending.rule("perfect_mult", 1.2))
	b.begin_swing(owner, EYE_S, BendZone.SWING_R, k)
	b.swing_hold = hold
	b.info["ret_mult"] = k
	return true


## How long a bot wearing Eye of the Gale holds a caught shot (s): BOT_EYE_S, by its own dice (never its foe's timing twice).
static func bot_eye_s(body: Node) -> float:
	var u := (body as NpcFighter).rng.randf() if body is NpcFighter else 0.5
	return lerpf(BOT_EYE_S.x, BOT_EYE_S.y, u)


## Eye of the Gale: a bot's hold (true till `until`).
static func _held_till(until: float) -> bool:
	return BendStatus.now() < until


## Eye of the Gale: the shortest and longest a bot holds a caught shot (s; inside EYE_S).
const BOT_EYE_S := Vector2(0.2, 0.45)


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
	b.set_meta(CARRY_BY_META, body.get_instance_id())


## Carrying Wind: the meta of the Beat Gust's own caster (instance id): sent back or turned, it is someone else's and carries
## nothing more.
const CARRY_BY_META := &"air_carry_by"


## Carrying Wind (see the header): the loose stones lying in the wave's width on this step (whoever's loose stone: FormStone's
## LOOSE_META; never one held, raised, in flight or sinking) thrown on along its way CARRY_M, each a pebble of the Gust's
## caster. Once each. Only while the Gust is still its own caster's (sent back or turned, it carries nothing more).
static func carry_stones(b: BendBolt, from: Vector3, step: Vector3) -> void:
	var by := b._by()
	if by == null or not b.is_inside_tree():
		return
	if by.get_instance_id() != int(b.get_meta(CARRY_BY_META, 0)) or bool(b.info.get("returned", false)) \
			or not BendLoadout.wears(by, CARRYING):
		b.carries = false                             # (someone else's now: a guard's return, a Turn, Eye of the Gale)
		return
	var flat := Vector3(step.x, 0.0, step.z)
	if flat.length_squared() < 1e-8:
		return
	var fwd := flat.normalized()
	var across := Vector3.UP.cross(fwd).normalized()
	for s: Node in b.get_tree().get_nodes_in_group(FormStone.GROUP):
		var st := s as FormStone
		if st == null or st.is_queued_for_deletion() or st.state == FormStone.State.SINKING or GustLift.busy(st) \
				or not st.has_meta(FormStone.LOOSE_META) \
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
## turned to a fall, PEAK_WATCH_S at most). A bot's Leap is on the Beat by its release (on_beat); the player's key 3 is a
## click, so his Leap goes at its full lock as ever and its Beat is his let go (key3_cast, key3_let_go: K3_META), known
## before the top (the Leap rises longer than BEAT_S).
static func on_dash(body: Node, spec: Dictionary) -> void:
	var inf: Dictionary = spec.get("_info", {})
	if String(inf.get("move", "")) != "air_jump" or not BendLoadout.wears(body, PEAK_WIND):
		return
	if not (body is CharacterBody3D) or not body.is_inside_tree():
		return
	var beat := 1 if on_beat(spec) else 0
	if beat == 0:
		var k3: Variant = body.get_meta(K3_META, {})
		if not (k3 is Dictionary) or BendStatus.now() - float((k3 as Dictionary).get("at", -INF)) > K3_FRESH_S:
			return                                    # (no Beat on its way: a tapped key 3, or a cast that went by itself)
	var old := body.get_node_or_null(^"AirPeakWatch")
	if old != null:
		old.name = "AirPeakWatchOld"
		old.queue_free()
	var w := PeakWatch.new()
	w.name = "AirPeakWatch"
	w.beat = beat
	body.add_child(w)


## Key 3's Beat (Peak Wind), noted on the wearer: {s: 0 his let go still to come, 1 on the Beat, -1 not; at: when the Leap
## went}. Set by key3_cast, settled by key3_let_go, read by the Leap's PeakWatch (and gone with it).
const K3_META := &"air_k3_beat"
## How old a key-3 note may be when its Leap's dash begins (s: the pose's strike between the cast and the dash).
const K3_FRESH_S := 0.6


## The player's key-3 cast of move `m` at `mode` going now at its full lock (SwayCaster._cast: a click, as ever), key 3 `held`
## still: for a wearer of a technique that reads its Beat, his let go is to be read (K3_META pending; true); else no note.
static func key3_cast(body: Node, m: String, mode: String, held: bool) -> bool:
	if body == null:
		return false
	if body.has_meta(K3_META):
		body.remove_meta(K3_META)
	if not held or not beat_worn(body, m, mode):
		return false
	body.set_meta(K3_META, {"s": 0, "at": BendStatus.now()})
	return true


## Key 3 let go (or held on past the window: `since_full` > BEAT_S) `since_full` s after the full lock of the key-3 cast it
## went with (SwayCaster): on the Beat within BEAT_S (the flash on his hands), else not.
static func key3_let_go(body: Node, since_full: float) -> void:
	var k3: Variant = body.get_meta(K3_META, {}) if body != null else {}
	if not (k3 is Dictionary) or int((k3 as Dictionary).get("s", -1)) != 0:
		return
	var on := since_full <= BEAT_S + BEAT_EPS
	(k3 as Dictionary)["s"] = 1 if on else -1
	if on:
		beat_flash(body)


## Peak Wind's watch on a Leap's wearer: his rise turned to a fall is the top (his Carried wind charged there, once the Leap is
## known to be on the Beat: `beat` 1, or his key-3 note's), PEAK_WATCH_S at most; it frees itself (and the note).
class PeakWatch extends Node:
	var rose := false
	var top := false
	var t := 0.0
	## 1 on the Beat (a bot's release), 0 read from his key-3 note (K3_META).
	var beat := 0

	func _physics_process(dt: float) -> void:
		t += dt
		var cb := get_parent() as CharacterBody3D
		var b := beat
		if beat == 0 and cb != null:
			var k3: Variant = cb.get_meta(AirTalents.K3_META, {})
			b = int((k3 as Dictionary).get("s", -1)) if k3 is Dictionary else -1
		if cb == null or t > AirTalents.PEAK_WATCH_S or b < 0:
			_done()
			return
		if cb.velocity.y > 0.5:
			rose = true
		elif rose and cb.velocity.y <= 0.0:
			top = true
		if top and b > 0:
			BendZone.carry_wind(cb)                   # (the top: his Carried wind, its spiral and whistle on him)
			_done()

	func _done() -> void:
		set_physics_process(false)
		var cb := get_parent()
		if beat == 0 and cb != null and cb.has_meta(AirTalents.K3_META):
			cb.remove_meta(AirTalents.K3_META)
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


# ---------------------------------------------------------------- new skills (a worn talent's own mode of a move)
## The modes of move `id` only `body`'s worn talents add (TALENT_MODES; [] for Classic, one meta lookup).
static func extra_modes(body: Object, id: String) -> Array:
	if body == null or not is_instance_valid(body) or not (body is Node) or not (body as Node).has_meta(BendLoadout.PICKS_META):
		return []
	var out: Array = []
	for tid: String in TALENT_MODES:
		var tm: Array = TALENT_MODES[tid]
		if String(tm[0]) == id and BendLoadout.wears(body, tid):
			out.append(String(tm[1]))
	return out


## Move `id`'s ring modes for `body` (SwayCaster.modes_of and his worn talents' own; a null body: the move's).
static func modes_for(body: Object, id: String) -> Array:
	var ex: Array = extra_modes(body, id)
	return SwayCaster.modes_of(id) if ex.is_empty() else SwayCaster.modes_of(id) + ex


## The spec of move `m`'s talent mode `mode` when `body` wears its talent (moves.json <m>.talent_bend; {} else).
static func talent_spec(body: Object, m: String, mode: String) -> Dictionary:
	if body == null or not is_instance_valid(body) or not (body is Node) or not (body as Node).has_meta(BendLoadout.PICKS_META):
		return {}
	var tb: Variant = SwayMoves.move(m).get("talent_bend")
	if not (tb is Dictionary) or not ((tb as Dictionary).get(mode) is Dictionary):
		return {}
	var s: Dictionary = (tb as Dictionary)[mode]
	return s if BendLoadout.wears(body, String(s.get("talent", ""))) else {}


## A worn talent mode's own lock (its spec's lock_s), else `base`.
static func talent_lock(body: Object, m: String, mode: String, base: float) -> float:
	var s := talent_spec(body, m, mode)
	return float(s.get("lock_s", base)) if not s.is_empty() else base


## The mode whose pose a worn talent mode is cast with (its spec's pose_as: the move's own), else `mode`.
static func pose_mode(body: Object, m: String, mode: String) -> String:
	var s := talent_spec(body, m, mode)
	return String(s.get("pose_as", mode)) if not s.is_empty() else mode


## A talent mode's name (its spec's label), else `mode` (SwayCaster.mode_label's fallback).
static func label(m: String, mode: String) -> String:
	var tb: Variant = SwayMoves.move(m).get("talent_bend")
	if tb is Dictionary and (tb as Dictionary).get(mode) is Dictionary:
		return String(((tb as Dictionary)[mode] as Dictionary).get("label", mode))
	return mode


# ---------------------------------------------------------------- Frostwind (the skill set) and its crust
## Whether bolt info `info` of `by`'s is one Frostwind freezes with (a Gust or a Wind Ball of a Frostwind wearer; BendBolt.launch
## sets its frosts).
static func frosts(by: Node, info: Dictionary) -> bool:
	var tag := String(info.get("tag", ""))
	return tag in ["air_gust/gust", "air_blast/ball"] and BendLoadout.wears(by, FROSTWIND)


## Frostwind (see the header) on the step a bolt of its takes (BendBolt's flight, `frosts`): a puddle or a grate it crosses
## turned to crust, steam it crosses fallen as snow and cleared. Once each.
static func frost_step(b: BendBolt, from: Vector3, step: Vector3) -> void:
	var by := b._by()
	if by == null or not b.is_inside_tree():
		return
	if bool(b.info.get("returned", false)) or not BendLoadout.wears(by, FROSTWIND):
		b.frosts = false                              # (someone else's now: a guard's return, a Turn, Eye of the Gale)
		return
	var to := from + step
	var flat := Vector3(step.x, 0.0, step.z)
	var way := flat.normalized() if flat.length_squared() > 1e-8 else -by.global_basis.z
	for n in b.get_tree().get_nodes_in_group(Bending.POOLS):
		var p3 := n as Node3D
		if p3 == null or p3.is_queued_for_deletion() or p3.has_meta(FROZEN_META):
			continue
		var reach := (p3 as BendZone).radius if p3 is BendZone else GRATE_R
		if p3 is BendZone and (p3 as BendZone).kind != "puddle":
			continue                                   # (only water freezes: a mud pool never does)
		if _flat_dist(p3.global_position, from, to) > b.radius + reach or b.global_position.y - p3.global_position.y > 3.0:
			continue
		freeze_pool(by, p3, way)
	for z in b.get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz == null or bz.kind != "steam" or bz.is_queued_for_deletion() or not bz.inside(b.global_position):
			continue
		snow_fall(bz.global_position, bz.radius)
		bz.end("snow")


## The flat distance (m) from `p` to the segment `a`-`b`.
static func _flat_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var q := Geometry3D.get_closest_point_to_segment(Vector3(p.x, 0.0, p.z), Vector3(a.x, 0.0, a.z), Vector3(b.x, 0.0, b.z))
	return q.distance_to(Vector3(p.x, 0.0, p.z))


## Pool `pool` (a puddle zone, or a grate: Bending.POOLS) frozen by `by`'s wind into a crust across `way`: a puddle is gone
## into it (fire melts it back), a grate is no water source while it stands (out of POOLS, its FROZEN_META the crust's
## instance id; back however the crust goes: crumbled, melted, capped, or freed by the round's reset: CrustWatch).
static func freeze_pool(by: Node3D, pool: Node3D, way: Vector3) -> FormRaised:
	var at := FormEffects.ground_at(by, pool.global_position)
	var src := {"kind": "grate", "node": pool}
	if pool is BendZone:
		var pz := pool as BendZone
		src = {"kind": "puddle", "owner": pz.owner_node, "radius": pz.radius, "life": maxf(pz.life_s - pz.t, 2.0)}
		pz.end("frozen")
	else:
		pool.set_meta(FROZEN_META, 0)
		pool.remove_from_group(Bending.POOLS)
	var r := make_crust(by, at, way, CRUST_S, src)
	if not (pool is BendZone):
		pool.set_meta(FROZEN_META, r.get_instance_id())
	return r


## A frost crust of `by`'s at `at` (its foot) lying across `way`: a low ice ridge CRUST_W long, CRUST_H high, `life` s (a snow
## FormRaised: floor waves and rolling stones stop at it, anyone can jump it, shots wear it as ice; never slippery), with its
## CrustWatch. Two of his at once (his oldest crumbles: "capped").
static func make_crust(by: Node3D, at: Vector3, way: Vector3, life: float, src := {}) -> FormRaised:
	var flat := Vector3(way.x, 0.0, way.z)
	flat = flat.normalized() if flat.length_squared() > 1e-6 else Vector3.FORWARD
	var mine: Array = []
	for w in by.get_tree().get_nodes_in_group(FormRaised.GROUP):
		var fr := w as FormRaised
		if fr != null and fr.state != FormRaised.State.CRUMBLING and int(fr.get_meta(CRUST_META, 0)) == by.get_instance_id():
			mine.append(fr)
	mine.sort_custom(func(a: FormRaised, b: FormRaised) -> bool: return int(a.get_meta(&"air_crust_n", 0)) < int(b.get_meta(&"air_crust_n", 0)))
	while mine.size() >= CRUST_CAP:
		(mine.pop_front() as FormRaised).crumble("capped")
	var wd: Dictionary = SwayMoves.move("earth_wall").get("wall", {})
	var wn: Dictionary = FormMatter.numbers(wd, FormMatter.entry("earth_wall", "snow"), "snow")
	wn["width_m"] = CRUST_W
	wn["height_m"] = CRUST_H
	wn["thick_m"] = CRUST_T
	wn["life_s"] = life
	wn["rise_s"] = 0.15
	wn["crumble_s"] = 0.8
	var xf := Transform3D(Basis(Vector3.UP.cross(flat).normalized(), Vector3.UP, flat), at)
	var r := FormRaised.raise(by.get_tree().current_scene, "wall", xf, wn, absi(hash(at)) % 97)
	_crust_n += 1
	r.set_meta(CRUST_META, by.get_instance_id())
	r.set_meta(&"air_crust_n", _crust_n)
	r.set_meta(&"bend_ice", true)
	r.set_meta(&"bend_by", by.get_instance_id())
	var w := CrustWatch.new()
	w.name = "CrustWatch"
	w.src = src
	w.by = by
	r.add_child(w)
	BendLooks.burst(at + Vector3.UP * 0.3, "ice", 18, Vector3.UP, 120.0, 2.0, 0.2)
	return r


static var _crust_n := 0


## Whether `r` is a frost crust (anyone's).
static func is_crust(r: Node) -> bool:
	return r is FormRaised and r.has_meta(CRUST_META)


## How many crusts stand in the scene now (their CrustWatch counts them; 0 in every Classic match: crust_ahead's early out).
static var _crusts_up := 0


## Whether a bot `body` on the deck going along `move` (its pad's move) is about to run into a crust lying across its way
## (CRUST_AHEAD_M from its near side): it jumps it (NpcFighter._ring_move), as the node says anyone can. False at once while
## no crust stands.
static func crust_ahead(body: Node3D, move: Vector3) -> bool:
	if _crusts_up <= 0 or body == null or not body.is_inside_tree():
		return false
	var flat := Vector3(move.x, 0.0, move.z)
	if flat.length() < 0.3:
		return false
	flat = flat.normalized()
	for w in body.get_tree().get_nodes_in_group(FormRaised.GROUP):
		var fr := w as FormRaised
		if fr == null or not fr.has_meta(CRUST_META) or fr.state == FormRaised.State.CRUMBLING:
			continue
		var l := fr.global_transform.affine_inverse() * body.global_position
		if absf(l.x) > fr.size.x * 0.5 + 0.3 or l.y > fr.size.y or l.y < -0.6:
			continue
		var gap := absf(l.z) - fr.size.z * 0.5                    # (from its near side)
		var toward := -signf(l.z) * flat.dot(fr.global_basis.z.normalized())
		if gap >= -0.1 and gap <= CRUST_AHEAD_M and toward > 0.3:
			return true
	return false


## A bot jumps a crust this near its near side (m).
const CRUST_AHEAD_M := 0.9


## A fire bolt meeting `r` (BendBolt._hit): a crust melts back (its puddle again, a grate's grate). True when it did.
static func melt_crust(r: FormRaised) -> bool:
	if not is_crust(r) or not r.is_up():
		return false
	r.crumble("melted")
	return true


## Steam fallen as snow (its look; the cloud cleared by whoever calls).
static func snow_fall(at: Vector3, r: float) -> void:
	BendLooks.burst(at + Vector3.UP * 1.6, "ice", 26, Vector3.DOWN, 70.0, 1.5, 0.12)
	BendLooks.burst(at + Vector3.UP * 0.8 + Vector3(r * 0.4, 0.0, 0.0), "ice", 14, Vector3.DOWN, 90.0, 1.0, 0.1)


## A Frostwind wearer's Wind Wall (BendZone.on_bolt's wind_wall): water and ice it blows aside fall as shards instead (the bolt
## spent at the wall, ice shards dropping). True when it did.
static func wall_shards(z: BendZone, b: BendBolt) -> bool:
	if not b.kind in ["water", "ice"] or b.guarded_by.has(z.get_instance_id()) or not BendLoadout.wears(z.owner_node, FROSTWIND):
		return false
	z.took += 1
	BendLooks.burst(b.global_position, "ice", 16, Vector3.DOWN, 80.0, 3.0, 0.16)
	b.end("shards")
	return true


## A crust's own watch (a child of its FormRaised): fire standing on it (a Fire Wall, burning ground) melts it; as it goes,
## a grate it froze is a water source again (also when the crust is freed without crumbling: the round's reset,
## RingArena.clear_dropped, frees every raised piece; _exit_tree), and a puddle it froze comes back when fire melted it.
class CrustWatch extends Node:
	var src := {}
	var by: Node3D
	var _t := 0.0
	var _crust_id := 0
	var _thawed := false

	func _ready() -> void:
		_crust_id = get_parent().get_instance_id()
		(get_parent() as FormRaised).crumbled.connect(_gone)
		AirTalents._crusts_up += 1

	func _exit_tree() -> void:
		AirTalents._crusts_up = maxi(AirTalents._crusts_up - 1, 0)
		_thaw()

	## The grate it froze a water source again (once; only while the grate is still this crust's).
	func _thaw() -> void:
		if _thawed:
			return
		_thawed = true
		var g: Variant = src.get("node")
		if String(src.get("kind", "")) != "grate" or not (g is Node) or not is_instance_valid(g):
			return
		var gn := g as Node
		if not gn.has_meta(AirTalents.FROZEN_META) or int(gn.get_meta(AirTalents.FROZEN_META)) not in [0, _crust_id]:
			return
		gn.remove_meta(AirTalents.FROZEN_META)
		gn.add_to_group(Bending.POOLS)                   # (its water a source again)

	func _physics_process(dt: float) -> void:
		_t -= dt
		if _t > 0.0:
			return
		_t = 0.25
		var r := get_parent() as FormRaised
		if r == null or not r.is_up() or not NetSpells.decides():
			return
		for z in get_tree().get_nodes_in_group(BendZone.GROUP):
			var bz := z as BendZone
			if bz != null and bz.kind in ["fire_wall", "burn"] and not bz.is_queued_for_deletion() \
					and (bz.inside(r.global_position) or bz.inside(r.global_position + r.global_basis.x * 1.2)
					or bz.inside(r.global_position - r.global_basis.x * 1.2)):
				r.crumble("melted")
				return

	func _gone(r: FormRaised, why: String) -> void:
		_thaw()
		if why == "melted":
			BendLooks.burst(r.global_position + Vector3.UP * 0.2, "water", 22)
			var own: Variant = src.get("owner")
			if String(src.get("kind", "")) == "puddle" and own is Node3D and is_instance_valid(own):
				BendZone.make(own as Node3D, "puddle", r.global_position, {"radius_m": float(src.get("radius", 0.9)),
						"life_s": float(src.get("life", 4.0))}, r.global_basis.z)


# ---------------------------------------------------------------- Hail Ball
## Whether a bolt of `by`'s with `info` carries a hail core (his Wind Ball, Hail Ball worn; BendBolt.launch sets its hails).
static func hails(by: Node, info: Dictionary) -> bool:
	return String(info.get("tag", "")) == "air_blast/ball" and BendLoadout.wears(by, HAIL_BALL)


## Hail Ball (see the header): where its Wind Ball hits or ends its flight (BendBolt._finish), HAIL_N hailstones fall HAIL_R
## round it (the first along its way), each striking whoever stands within HAIL_HIT_M of where it falls, his foes only:
## HAIL_TAG's class (2%, no knock, no flinch, no hurt).
static func hail_burst(b: BendBolt, why: String) -> void:
	if not why in ["hit", "world", "range", "wall", "lip"] or not NetSpells.decides():
		return
	var by := b._by()
	if by == null or not b.is_inside_tree() or not BendLoadout.wears(by, HAIL_BALL):
		return
	var at := FormEffects.ground_at(b, b.global_position)
	var fwd := Vector3(b.velocity.x, 0.0, b.velocity.z)
	fwd = fwd.normalized() if fwd.length_squared() > 1e-6 else Vector3.FORWARD
	var info := {"tag": HAIL_TAG, "move": "air_blast", "mode": "ball", "from": at, "air": false, "released_at": BendStatus.now(),
			"no_hurt": true}
	for i in HAIL_N:
		var spot := at + fwd.rotated(Vector3.UP, TAU * float(i) / float(HAIL_N)) * HAIL_R
		spot.y = FormEffects.ground_at(b, spot).y
		BendLooks.burst(spot + Vector3.UP * 1.8, "ice", 8, Vector3.DOWN, 20.0, 6.0, 0.08)
		for e in BendCaster.near(by, spot, HAIL_HIT_M):
			var n: Node3D = e[0]
			if n == by or BendCaster.same_team(n, by):
				continue
			BendR3.deliver(n, 2.0, n.global_position + Vector3.UP * 1.6, Vector3.DOWN, by, -1.0, Vector3.ZERO, info)


# ---------------------------------------------------------------- Frost Gust
## A fire wall or burning ground of his foe's his Gust crosses (BendZone.on_bolt, before its own inside test: the wave's
## width over the low burning ground counts): a Frost Gust wearer's puts it out. True when it did (the Gust flies on).
static func snuffs(z: BendZone, b: BendBolt) -> bool:
	if b.spent or b.kind != "air" or String(b.info.get("tag", "")) != "air_gust/gust" or not BendLoadout.wears(b._by(), FROST_GUST):
		return false
	var by := b._by()
	if z.owner_node == by or BendCaster.same_team(by, z.owner_node):
		return false                                 # (his side's fire is left burning)
	# (crossing it: the wave's own width over its box; a Gust is a wave from the deck up (its spec's height_m 2), so the low
	# burning ground under a chest-high Gust is crossed too)
	var l := z.global_transform.affine_inverse() * b.global_position
	if absf(l.x) > z.size.x * 0.5 + b.radius or absf(l.z) > z.size.z * 0.5 + b.radius or l.y < -b.radius \
			or l.y > z.size.y + maxf(b.radius, GUST_REACH_DOWN_M):
		return false
	BendLooks.burst(z.global_position + Vector3.UP, "steam", 26, Vector3.UP, 100.0, 2.0, 0.6)
	BendLooks.burst(z.global_position + Vector3.UP * 0.5, "ice", 14, Vector3.UP, 120.0, 2.0, 0.12)
	z.end("snuffed")
	return true


# ---------------------------------------------------------------- Rime Wall
## His Wind Wall ending (BendZone.end): a Rime Wall wearer's drops a crust ridge where it stood (RIME_S), lying along it.
static func on_wall_end(z: BendZone, why: String) -> void:
	if why == "owner" or z.owner_node == null or not is_instance_valid(z.owner_node) or not z.is_inside_tree():
		return
	if not BendLoadout.wears(z.owner_node, RIME_WALL) or not NetSpells.decides():
		return
	make_crust(z.owner_node, FormEffects.ground_at(z, z.global_position), z.way, RIME_S, {})


# ---------------------------------------------------------------- Blizzard
## The cold of his Blizzard (BendZone._every of a snow zone, each 0.25 s): a foe inside gains 1% each MATTER_EVERY_S (one tick
## a body each MATTER_EVERY_S from any matter), COLD_CAP ticks at most from one Blizzard; the water in it frozen to crust; fire
## on it (a Fire Wall, burning ground) melts it out in SNOW_MELT_S.
static func snow_every(z: BendZone) -> void:
	var by := z.owner_node
	if by == null or not is_instance_valid(by) or not NetSpells.decides():
		return
	for n in z.get_tree().get_nodes_in_group(Bending.POOLS):
		var p3 := n as Node3D
		if p3 != null and not p3.is_queued_for_deletion() and not p3.has_meta(FROZEN_META) and (not (p3 is BendZone) or (p3 as BendZone).kind == "puddle") \
				and Vector2(p3.global_position.x - z.global_position.x, p3.global_position.z - z.global_position.z).length() <= z.radius:
			var w := p3.global_position - by.global_position
			freeze_pool(by, p3, Vector3(w.x, 0.0, w.z))
	for f in z.get_tree().get_nodes_in_group(BendZone.GROUP):
		var fz := f as BendZone
		if fz != null and fz.kind in ["fire_wall", "burn"] and not fz.is_queued_for_deletion() \
				and fz.global_position.distance_to(z.global_position) <= z.radius + maxf(fz.size.x * 0.5, fz.radius):
			melt_snow(z)
	var ticks: Dictionary = z.get_meta(&"air_cold", {})
	var now := BendStatus.now()
	var info := {"tag": COLD_TAG, "move": "air_wall", "mode": "blizzard", "air": false, "released_at": now, "no_hurt": true}
	for e in BendCaster.near(by, z.global_position, z.radius + 0.5):
		var n: Node3D = e[0]
		if n == by or BendCaster.same_team(n, by) or not z.inside(n.global_position):
			continue
		var id := n.get_instance_id()
		if int(ticks.get(id, 0)) >= COLD_CAP or now - float(n.get_meta(MATTER_TICK_META, -INF)) < MATTER_EVERY_S - 1e-3:
			continue
		ticks[id] = int(ticks.get(id, 0)) + 1
		n.set_meta(MATTER_TICK_META, now)
		var inf := info.duplicate()
		inf["from"] = n.global_position
		BendR3.deliver(n, 1.0, n.global_position + Vector3.UP, Vector3.DOWN, by, -1.0, Vector3.ZERO, inf)
	z.set_meta(&"air_cold", ticks)


## A Breath (BendEffects.cone with melt) of `p`'s along `flat`, `r` m and `deg` wide, reaching Blizzard `z` (its column within
## the cone): fire on it, it melts out in SNOW_MELT_S (melt_snow). True when it reached it.
static func breath_melt(p: Node3D, z: BendZone, flat: Vector3, r: float, deg: float) -> bool:
	if z == null or z.kind != "snow" or z.is_queued_for_deletion() or not NetSpells.decides():
		return false
	var to := z.global_position - p.global_position
	to.y = 0.0
	var d := to.length()
	if d > r + z.radius:
		return false
	var fl := Vector3(flat.x, 0.0, flat.z)
	if d > z.radius and fl.length_squared() > 1e-6:
		# (outside the column: its near side within the cone's half angle)
		var half := deg_to_rad(deg * 0.5) + asin(clampf(z.radius / d, 0.0, 1.0))
		if to.normalized().angle_to(fl.normalized()) > half:
			return false
	melt_snow(z)
	return true


## Fire on a Blizzard: it melts out in SNOW_MELT_S (once).
static func melt_snow(z: BendZone) -> void:
	if z.has_meta(&"air_melting"):
		return
	z.set_meta(&"air_melting", true)
	z.life_s = minf(z.life_s, z.t + SNOW_MELT_S)
	BendLooks.burst(z.global_position + Vector3.UP, "steam", 20, Vector3.UP, 90.0, 2.0, 0.6)


## His Wind Wall's life factor (Blizzard's new:air_wall.wall_life_k; 1 Classic).
static func wall_life_k(body: Node) -> float:
	if not BendLoadout.wears(body, BLIZZARD):
		return 1.0
	return BendLoadout.tune_f(body, "new:air_wall.wall_life_k", 1.0)


# ---------------------------------------------------------------- Whiteout
## His locks' fill factor now (SwayCaster._hold, NpcBending's lock): Whiteout's HOME_FILL standing on his own crust or in his
## own Blizzard, else 1.
static func home_fill(body: Node) -> float:
	if body == null or not (body is Node3D) or not BendLoadout.wears(body, WHITEOUT) or not body.is_inside_tree():
		return 1.0
	var at := (body as Node3D).global_position
	for w in body.get_tree().get_nodes_in_group(FormRaised.GROUP):
		var fr := w as FormRaised
		if fr == null or fr.state == FormRaised.State.CRUMBLING or int(fr.get_meta(CRUST_META, 0)) != body.get_instance_id():
			continue
		var l := fr.global_transform.affine_inverse() * at
		if absf(l.x) <= fr.size.x * 0.5 + 0.25 and absf(l.z) <= fr.size.z * 0.5 + 0.25 and l.y >= fr.size.y - 0.3 and l.y <= fr.size.y + 0.6:
			return HOME_FILL
	for z in body.get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.kind == "snow" and bz.owner_node == body and not bz.is_queued_for_deletion() and bz.inside(at):
			return HOME_FILL
	return 1.0


# ---------------------------------------------------------------- Toxic Gale
## Bolt `b` in a gas cloud `z` (BendZone.on_bolt, before the gas's own reactions): a Toxic Gale wearer's Wind Ball bursts it on
## (see the header). True when it did (the ball flies on).
static func toxic_gale(z: BendZone, b: BendBolt) -> bool:
	if z.kind != "gas" or b.spent or b.kind != "air" or String(b.info.get("tag", "")) != "air_blast/ball" or z.is_queued_for_deletion():
		return false
	var by := b._by()
	if by == null or not BendLoadout.wears(by, TOXIC_GALE) or not NetSpells.decides():
		return false
	var off := b.global_position - z.global_position
	if Vector2(off.x, off.z).length() > z.radius + b.radius or off.y < -1.0 or off.y > 3.5:
		return false
	var key := StringName("air_gale_%d" % b.get_instance_id())
	if z.has_meta(key):
		return false
	z.set_meta(key, true)
	var flat := Vector3(b.velocity.x, 0.0, b.velocity.z)
	flat = flat.normalized() if flat.length_squared() > 1e-6 else -by.global_basis.z
	var to := FormEffects.ground_at(z, z.global_position + flat * GALE_M)
	BendLooks.burst(z.global_position + Vector3.UP, "air", 26, flat, 70.0, 6.0, 0.3)
	BendLooks.burst(to + Vector3.UP, "smoke", 30, Vector3.UP, 180.0, 3.0, 0.5)
	var k := GALE_R / maxf(z.radius, 0.1)
	z.owner_node = by                                    # (the cloud is his now: its ticks his foes')
	z.radius = GALE_R
	z.global_position = to
	z.set_meta(&"gas_carried", true)
	var look := z.get_node_or_null(^"Look") as Node3D
	if look != null:
		look.scale = Vector3(look.scale.x * k, look.scale.y, look.scale.z * k)
	return true
