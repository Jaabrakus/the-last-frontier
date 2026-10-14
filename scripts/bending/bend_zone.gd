class_name BendZone
extends Node3D
## A bent thing that lasts a while in the world (BendEffects; docs/bending_design.md), by `kind`:
##   barriers    bubble (a sphere of water round its owner: fire dies in it as steam, air and water are stopped, stone and
##               ice pass), air_shield (round its owner: fire, water, ice and air sent back at who sent them; stone passes),
##               water_wall (a wall of water: fire dies in it, water is drunk in; fire walls it stands in go out),
##               fire_wall (burns whoever stands in it; ice melts going through, air takes its flame, water puts it out)
##   the ground  burn (the ground alight: as a fire wall, low), ice_patch (slows whoever is on it), smoke / dust / spray /
##               steam (a cloud that hides: a man behind it, from a bot, NpcBendCaster.hidden; steam: where water and fire
##               met, BendBolt.steam, a moment only)
##   moving      tornado (goes on along its way, lifting and carrying whoever it meets), vacuum (the air pulled out round a
##               place: whoever is in it slowed)
##   guards      on its owner for a moment (window_s): catch (a stone flying at him caught and held before him: Earth Shove
##               sends it back), deflect (a stone knocked aside), cushion (a stone slowed to a stop and dropped): a GustLift
##               throw, a bot's spike (NpcBending.Flight) or a stone bolt (BendBolt kind "stone": the disc, the pebbles, a
##               shoved chunk; caught or cushioned it is a FormStone again); redirect (water, ice and the Air Lance sent
##               back, the Lance as ice), return (Air
##               Redirect: light bolts, fire, water, ice and air, sent back at who sent them), parry (fire knocked aside),
##               spin (light bolts knocked aside), absorb (water drunk in: a little health)
## put_out (spec.put_out: the spray): what burns in it goes out as it is made and while it stands (fire walls, burning ground,
## campfires, torches not in its owner's hand).
## The tornado keeps to the ground under it (FormEffects.ground_at: a deck, a raised floor; the terrain where there is none).
## Whom it reaches: BendCaster.near (the player found through his group). Its owner any Node3D (the player, a bot).
## on_bolt(b): what it does to bolt `b` passing (true: it acted). Group GROUP.
## ROUND 2 (skills_r2 spec §2.5, §2.6, §3; the owner's answers 2026-10-05: "one is good but dont forget the other elements"):
## an element's guard on E (catch, redirect "Turn", parry, air_shield "Wind Guard"; `r2`: its owner casts as an element)
## times what it meets from its making: within perfect_s (0.3 s) PERFECT, after it until its window ends LATE (late_mult
## of the damage and the knock get through: the bolt goes on halved), nothing taken by its end a WHIFF (the owner's next
## guard's lock is whiff_lock_s within whiff_s: guard_lock_s). The guard matrix:
##   catch       stone, ALWAYS caught and held as before (perfect or late; no slide, no root), the stone's own numbers kept
##               (meta bend_stone_d) and a clean catch marked (bend_clean). E again (or Shove) throws it back: return_stone
##               (the lock return_lock_s, perfect_return_lock_s off a clean catch; x perfect_mult when clean, x the rally:
##               +rally_step a return, +rally_clean_step off a clean catch, at most rally_max; never under gust.stone.hurl).
##               Only earth is caught and held for E, straight into his hands, no swing round him (the owner, 2026-10-12:
##               "for earth the only catch and press e is when its a earth on earth everything else is flow", then "for the
##               earth on earth E dont spin"): air, fire, water and ice bolts, perfect, circle him once like
##               a moon and leave along his aim x perfect_mult made of both (_earth_flow: EARTH_FLOWS): air a fist of pebbles
##               (one tight shot), fire a magma ball (it burns: heated, fire to the guards), water and ice turned to mud as
##               they circle and slapped down at the swing's end as a wave of mud along the deck, the Fissure's in mud, that
##               drenches whom it hits ("earth catching water should be the fissure mud": BendBolt.to_floor_wave, MUD_WAVE,
##               MUD_S); late, half through. Fire's wave along the deck (the Kick's) swirls round him as magma and goes back down
##               the deck as the Fissure in magma, burning (MAGMA_WAVE, 2026-10-13); any other wave along the deck and lightning pass. A held stone
##               packed by another's guard (a Boulder a Turn sent back as mud: _lift_swing) is thrown as it is; mud thrown
##               with E is a mud wave along the deck (_mud_wave)
##   Turn        water or ice: perfect, it swings once round the guard's waist (SWING_S) and leaves along his aim x
##               perfect_mult (steered by Flowing); the Air Lance (an air bolt of shape spear, the Gust held long; the
##               owner, 2026-10-11): the same, and it turns to ice as it is caught (BendBolt.become), wraps round him and
##               leaves an ice lance along his aim; any other air (the owner, 2026-10-12): the same, leaving as mini ice
##               spears; stone (a bolt, a Spike, a Boulder): the same, swung round in water, leaving as mud that drenches
##               whom it hits (a mud spear: _turn_back, _lift_swing); late, half gets through as every late Turn; fire:
##               perfect, doused to steam; a Wave on the beat parts round him (cone_mult)
##   parry       fire of any shape (a bolt, the Kick's floor wave, the High Kick's crescent) and air (the owner, 2026-10-12,
##               "Counter it": turned to fire as it is caught): perfect, it circles him once like a moon and leaves along his
##               aim x perfect_mult (_moon_back; no dice: never a random side; a floor wave straight back along the floor at
##               once); stone (a bolt, a Spike, a Boulder): the same, melted to a magma ball, burning; water: perfect,
##               boiled to steam; ice: perfect, melted to a puddle; lightning: back along his aim only on a parry in its
##               first perfect_s when it strikes (lightning_back), else it hits
##   Wind Guard  everything but lightning (the owner, 2026-10-12: "the wind can parry a rock and send back most attacks
##               back"): perfect, it circles him once like a moon and leaves along his aim x perfect_mult, still what it was
##               (_moon_back; a Spike or a Boulder: _lift_swing), and air charges his Carried wind. Lightning passes. (The
##               2.5 s return shield is gone.)
##   Where two elements meet the return is made of both (fire and water never send each other back): earth and fire magma,
##   earth and water mud, air taken by earth pebbles, by water ice, by fire fire. Whoever swings a return round him turns with
##   it, his lead hand after it (GuardSpin: visual only).
## Each result is told: the owner's BendCaster.guarded(result, what), his meta bend_last_guard, the counts (counts), and
## its look and sound on the guarder only (BendLooks.guard_result; no cue on whoever sent it).
## Round 2's zones too: wind_wall (a standing wall of wind: light shots blown up and aside, stone and lightning pass, a body
## walking into it pushed back; one at a time), puddle (water left on the deck: a Geyser's source, Bending.POOLS).
## ROUND 3 (smash_r3 spec §2.5, §4.4; AIR), only with BendR3.stock(): every guard a shield. A cell the matrix lets pass is
## stopped on the beat (no reward) and halved late as a slide (_shield_bolt; flying stones in _stones; guard_take for a cone,
## a Column, the Slam, the air hit; lightning_guard: only a Parry on the beat sends it back). Earth's catch is whole within its
## window_s of standing (its life may be held longer: SwayCaster's held guard) and late after, the stone dropped loose at his
## feet (_late_drop). A spike is met by its point. What a late guard lets through carries slide_only; what a guard sends back
## is a return (return_info: "<origin>.return", returned, ret_mult, origin_tag); a caught stone keeps its origin tag, and
## earth's Pop stone is thrown as itself (rock_jab/pop_stone, not a return). A jab a guard takes ends its sender's string.
## The fire wall's entry pop (once a body each entry_every_s) and its burn with no knock; walls' hits carry the cast's info.
## ONLINE (NetSpells, docs/tidebreak/ring_netcode.md "Ghost mode"): named by its cast's run (NetSpells.tag); one the host makes
## by a decision outside a cast (steam where water met fire, a parry's puddle) named in a run of its own and made on the
## others by its word (NetSpells.spawned). Only the host decides what it does to bodies, bolts and stones (_every, _stones,
## _wind_push, on_bolt, guard_take, cone_mult, lightning_back); a guard's result is told on every machine (the "guard" word:
## report there), a body's share of it (a parry's cast reward, a whiff, Carried wind, a Wind Prison's catch) on its owner's
## machine (NetSpells.here). An end that is not its own (its life, its owner gone) is the host's word on the others.
## SKILL TREE (water's talents, 2026-10-11; BendLoadout.wears: the wearer's own, Classic never here): mud (the Mud set: its
## wearer's puddles made mud pools, mud_life long, pools_per_caster; floor fire dies in it, a fire wall over it burns 2 s and dries
## it, a seam over it is quenched, a rolling stone stops; nobody slowed), gas (the Sulphur set's cloud, earth's: Washout's bolts and
## Cleanse's Turn wash it out: wash), a Turn's Whirl (a held swing: whirl_held) and Eddy (report, eddy_fill), Steamcraft's drifting
## steam, Wellspring's own water (in_own_water), Delta's home ground (in_own_mud, home_fill), Mire's placed mud pool (one of his
## at a time, never one of the set's pools_per_caster: MIRE_META).

const GROUP := &"bend_zones"
## Earth's Sulphur set: its gas (kind "gas": the ticks, the look, the reactions), loaded by its path.
const BendGas := preload("res://scripts/bending/bend_gas.gd")
const LIGHT := ["fire", "water", "ice", "air"]
const GUARDS := ["catch", "deflect", "cushion", "redirect", "return", "parry", "spin", "absorb", "wind_guard"]
## The earth guards: they take stones.
const STONE_GUARDS := ["catch", "deflect", "cushion"]
## Round 2's timed guards (with an element) and the element each is.
const R2_GUARDS := {"catch": "earth", "redirect": "water", "parry": "fire", "air_shield": "air", "wind_guard": "air"}
## The Wind Guard's window when its spec gives none (s; spec §2.5).
const WIND_GUARD_S := 0.8
## A Turn's swing round the guard's waist (s) and its radius (m).
const SWING_S := 0.3
const SWING_R := 1.0
## A Parry's and a Wind Guard's moon (_moon_back): one lap round the guard in this long (s), this far out (m).
const MOON_S := 0.35
const MOON_R := 1.25
## Earth's Catch on the beat of another element (the owner, 2026-10-12): the shape each flows back as (_earth_flow; "mud_wave":
## swung round as mud, then slapped down as a wave of mud along the deck, "earth catching water should be the fissure mud").
const EARTH_FLOWS := {"air": "pebbles", "fire": "magma", "water": "mud_wave", "ice": "mud_wave"}
## Mud's drench (s: BendStatus.drench, as Drenching Wave's, its look mud's; RingRules mud_s): a water Turn's mud spear, earth's
## mud wave (the owner, 2026-10-12: "a mud spear or blast that slows", "either mud spear or a mud wave").
const MUD_S := 1.5
## Earth's mud wave (a mud stone thrown back with E: _mud_wave): a wave of mud along the deck, as the Kick's floor wave (jumped
## over, stopped by walls), at least these numbers.
const MUD_WAVE := {"do": "floor_wave", "kind": "stone", "shape": "mud", "mps": 16.0, "range_m": 16.0, "width_m": 2.4,
		"height_m": 0.8, "miss_above_m": 0.6, "damage": 16.0, "knock_mps": 7.0, "up_mps": 1.2}
## Earth's magma wave (its Catch on the beat of fire's floor wave, the Kick's: _earth_flow; the owner, 2026-10-13: "a perfect
## parry on fire fissure should result in a spin fire ... fissure"): the mud wave's numbers, in magma, burning.
const MAGMA_WAVE := {"do": "floor_wave", "kind": "stone", "shape": "magma", "mps": 16.0, "range_m": 16.0, "width_m": 2.4,
		"height_m": 0.8, "miss_above_m": 0.6, "damage": 16.0, "knock_mps": 7.0, "up_mps": 1.2, "heat": true}
## A body walking into a wind wall is pushed back at this (m/s), once each PUSH_EVERY_S.
const WIND_WALL_KNOCK := 4.0
const PUSH_EVERY_S := 0.5
## Round zones the skill tree's sets add (inside: within radius): gas (the Sulphur set's cloud), mud (the Mud set's pool).
const ROUND_NEW := ["gas", "mud"]
## The bolts Washout washes gas with (their info's tag): the Splash and the Lash.
const WASH_TAGS := ["water_jet/splash", "water_whip/whip"]
## Water's Turn talents (skill tree): Whirl Turn (a held swing), Eddy (a head start after a perfect Turn: the meta's time, how
## long it waits, how full the lock starts, the moves it helps: the Lash and the Spear).
const WHIRL := "water.turn.whirl"
const EDDY := "water.turn.eddy"
const EDDY_META := &"bend_eddy_until"
const EDDY_S := 1.2
const EDDY_FILL := 0.4
const EDDY_MOVES := ["water_whip", "ice"]
## Water's Mud set (a skill tree skill set): its wearer's puddles are mud pools (make, _mud_every, on_bolt); Delta, its home
## ground passive: his locks fill DELTA_FILL faster standing in his own mud (in_own_mud: SwayCaster.passive_fill, a bot's tick).
const MUD_SET := "water.set.mud"
## Mire (a skill tree new skill on 4 tapped twice; its spec's mire): a mud pool of his he places, one at a time (a second dries the
## first; his other mud pools stay), not counted among the set's pools_per_caster.
const MIRE_META := &"bend_mire"
const DELTA := "water.mud.delta"
const DELTA_FILL := 1.15
## Guard results by element, for the soak and the HUD: {element: {perfect, late, whiff}}.
static var counts := {}

var kind := "bubble"
var owner_node: Node3D
var follow := false
## Round: radius; a wall or a patch: size (x across, y up, z through), standing on its origin.
var radius := 2.0
var size := Vector3(4.0, 2.0, 0.5)
var life_s := 3.0
var damage_s := 0.0
var way := Vector3.FORWARD
var speed := 0.0
var t := 0.0
## What a guard took (stones caught, bolts sent back), for the tests.
var took := 0
## What burns in it goes out (the spray); how many it has put out.
var put_out := false
## A Wind Prison (a skill tree twist on the Wind Wall, spec prison_s; the owner 2026-10-11: "air should have air prisons where they
## can catch someone mid flight"): whoever it touches in the air is held inside it for this long, helpless (BendStatus.float_up);
## it turns no shot aside. 0: a plain Wind Wall.
var prison_s := 0.0
## A Turn's longest swing held on (spec swing_s: read only for a wearer of Whirl Turn, a skill tree twist; a tap swings SWING_S).
var swing_hold_s := 0.0
var put_out_n := 0
## A wind wall's push (m/s): its spec's push_mps (Rime Wall's 3.2 for its wearer), else WIND_WALL_KNOCK.
var push_mps := WIND_WALL_KNOCK
## The stones a guard caught or dropped from stone bolts (FormStone), for the tests.
var stones: Array[FormStone] = []
## Round 2's timed guard (see the header): on, its perfect window (s), the share a late one lets through, its element, and
## what it made of each thing it met ("perfect", "late"; "whiff" at its end when it took nothing).
var r2 := false
var perfect_s := 0.3
var late_mult := 0.5
var element := ""
var results: Array[String] = []
## Its maker's move id (one_at_a_time: a second of the same ends the first).
var move_id := ""
## Round 3 (the % ring; see the header's ROUND 3): a guard's own window as it was made (its life may be held longer: the
## held guard), the cast's hit info (BendR3.cur as it was made: a wall's hits carry it), the bodies inside at its last
## tick and when each last had a fire wall's entry pop.
var window_s := 0.8
var info := {}
var _inside_was := {}
var _popped := {}

var _tick := 0.0
var _fx: Array[Node] = []
var _pushed := {}                  ## a wind wall: body id -> when it last pushed it back (BendStatus.now())
var _caught := {}                  ## a Wind Prison: body id -> true once it has caught him (_imprison)
## MATTER (the skill tree's tick contract; a worn fire talent's floor fire, FireTalents): a zone with a tick class (spec tick_tag,
## matter/burn or matter/magma in rules.json stock.classes) adds % only (no_flinch, no_hurt) to whoever stands in it with his feet
## on its floor, one tick each MATTER_EVERY_S from all the matter he stands in, at most tick_cap ticks from one zone; never to its
## owner or his side; a jump clears it. Classic makes none (no spec has a tick_tag).
var tick_tag := ""
var tick_cap := 0
var round_zone := false            ## (a patch: inside() reads its radius, not its box)
var tick_floor := true             ## (floor fire: only feet on its floor take its tick; false: anyone in it, a scald's steam)
var tick_shared := true            ## (its ticks count in the one-each-0.5-s from all matter; false: a reaction's own)
var tick_all := false              ## (a reaction: everyone in it, its owner and his side too, no one's hit for those)
var tick_info := {}                ## (merged into each tick's hit info: a live reaction's strike_d)
var _ticks_to := {}                ## body id -> the ticks it gave him
const MATTER_META := &"bend_matter_tick_at"
const MATTER_EVERY_S := 0.5
const MATTER_FEET_M := 0.45


static func make(by: Node3D, p_kind: String, at: Vector3, spec: Dictionary, p_way := Vector3.FORWARD) -> BendZone:
	if p_kind == "puddle" and BendLoadout.wears(by, MUD_SET):
		# (the Mud set, a skill tree skill set: his puddles are mud pools, mud_life long; what mud does: _mud_every, on_bolt)
		p_kind = "mud"
		spec = spec.duplicate()
		spec["life_s"] = mud_life(by)
	var mire := p_kind == "mud" and bool(spec.get("mire", false))
	if mire:
		_end_mire(by)                            # (Mire: one of his at a time; BendEffects.zone gave it his mud's life)
	var z := BendZone.new()
	z.name = "BendZone_" + p_kind
	z.kind = p_kind
	z.owner_node = by
	z.follow = p_kind in ["bubble", "air_shield"] or p_kind in GUARDS
	z.radius = float(spec.get("radius_m", 2.0))
	z.size = Vector3(float(spec.get("width_m", 4.0)), float(spec.get("height_m", 2.0)), float(spec.get("thick_m", 0.6)))
	z.life_s = float(spec.get("life_s", spec.get("window_s", 3.0)))
	z.damage_s = float(spec.get("damage_s", 0.0))
	z.speed = float(spec.get("mps", 0.0))
	z.put_out = bool(spec.get("put_out", false))
	z.prison_s = float(spec.get("prison_s", 0.0))
	z.swing_hold_s = float(spec.get("swing_s", SWING_S))
	z.tick_tag = String(spec.get("tick_tag", ""))
	z.tick_cap = int(spec.get("tick_cap", 0))
	z.round_zone = bool(spec.get("round", false))
	z.tick_floor = bool(spec.get("tick_floor", true))
	z.tick_shared = bool(spec.get("tick_shared", true))
	z.tick_all = bool(spec.get("tick_all", false))
	z.tick_info = (spec.get("tick_info", {}) as Dictionary).duplicate() if spec.get("tick_info") is Dictionary else {}
	z.push_mps = float(spec.get("push_mps", WIND_WALL_KNOCK))
	if not BendR3.cur.is_empty():
		z.info = BendR3.cur.duplicate()
	if R2_GUARDS.has(p_kind) and BendStatus.element_mode(by):
		z.r2 = true
		z.element = String(R2_GUARDS[p_kind])
		z.follow = true
		z.perfect_s = float(spec.get("perfect_s", Bending.rule("perfect_s", 0.3)))
		z.late_mult = float(spec.get("late_mult", Bending.rule("late_mult", 0.5)))
		if p_kind in ["air_shield", "wind_guard"]:
			# (the Wind Guard's window, never the old shield's 2.5 s life: today's data has none, spec §2.5's then)
			z.life_s = float(spec.get("window_s", WIND_GUARD_S))
		z.window_s = z.life_s
	var w := Vector3(p_way.x, 0.0, p_way.z)
	z.way = w.normalized() if w.length_squared() > 1e-6 else Vector3.FORWARD
	z.add_to_group(GROUP)
	if p_kind == "gas":
		BendGas.live_n += 1                      # (Sulphur's gas, counted where it is made: the host's BendGas.make, a joiner's net word)
	if p_kind in ["puddle", "mud"]:
		z.add_to_group(Bending.POOLS)
		z.set_meta(&"reach_m", z.radius + 1.0)
	if mire:
		z.set_meta(MIRE_META, true)
	if p_kind == FireTalents.GAS_KIND:
		z.add_to_group(FireTalents.GAS_GROUP)    # (a gas cloud: fire's quick "none" for Classic's cones, FireTalents.gas_near)
	NetSpells.tag(z)                             # (online: its name in its cast's run)
	by.get_tree().current_scene.add_child(z)
	var x := Vector3.UP.cross(z.way).normalized()
	z.global_transform = Transform3D(Basis(x, Vector3.UP, z.way), at)
	if p_kind == "mud":
		_cap_mud(by)
	z._look()
	NetSpells.spawned(z, "zone", [by, p_kind, at, spec, p_way])     # (the host's own decision: made on the others too)
	if z.r2 and BendR3.stock():
		BendCombo.guard_stood(by, z)             # (the guard's gauge: its tap spent; empty, broken at once)
	return z


## Its look (BendLooks' cel style, ToonFx): the meshes under a "Look" node that grows in, the lasting emitters in _fx.
##   bubble       a wobbling sphere of water, a pale rim and foam streaks flowing round it, drops at its foot
##   air_shield   three translucent wind bands turning round its owner at different tilts and speeds, dust at his feet
##   water_wall   a standing sheet of water flowing up, foam and spray along its crest and its foot
##   fire_wall    standing flame sheets (one MultiMesh of tongues facing the camera) on a scorch, embers, a warm light;
##   burn         the same low over its strip of ground
##   ice_patch    a frost sheet on the ground, sparkles
##   tornado      stacked wind rings widening upward, each turning, rock debris and dust whirled up round it
##   vacuum       wind bands drawing in, air
##   smoke/dust/spray/steam  cel puffs (round 4: Breath's smoke a lit volume, warm from the flame for its first warm_s)
## Round 4 (LOOKS; data/bending/fx_looks.json): the fire wall's flames twice as many at 0.6 as wide over a soft glow; your own
## Wind Guard's bands drawn 0.6 as wide (band_w; everyone else's read of it unchanged); your own fire, wind and water walls
## faded by your camera as your earth walls are (OwnFade). Its look only: what it does, its timing and its size stay.
func _look() -> void:
	if not BendLooks.live():
		return
	if _sb_look():
		return                                 # (the move's Spellbreak effect replaces this look: SbFx)
	var look := Node3D.new()
	look.name = "Look"
	add_child(look)
	match kind:
		"bubble":
			var mi := _part(look, ToonFx.sphere(24), ToonFx.mat("bubble"))
			mi.scale = Vector3.ONE * radius
			mi.position = Vector3.UP * 1.0
			FxParams.put(mi, &"seed", ToonFx.vis_rng.randf() * 5.0)
			_fx.append(BendLooks.emitter(self, "water", Vector3(radius * 0.7, 0.05, radius * 0.7), 14, 0.6, 1.6, 0.12))
			_grow(look, Vector3.ONE * 0.05)
		"air_shield":
			# (bands thinner than they were, 0.26 of its round high: the dome of wind hid the guard almost whole, the move review
			# 2026-10-12)
			for i in 3:
				var b := _part(look, ToonFx.band_mesh(1.0, 0.95, 0.26), ToonFx.mat(["wind_band", "wind_band_slow", "wind_band_fast"][i]))
				b.scale = Vector3.ONE * radius * (1.0 - i * 0.07)
				b.position = Vector3.UP * (0.3 + i * 0.62)
				b.rotation = Vector3(0.24 * (1.0 if i % 2 == 0 else -1.0), i * 1.1, 0.12 * i)
				FxParams.put(b, &"seed", i * 0.37)
				FxParams.put(b, &"band_w", own_band_w())
			_fx.append(BendLooks.emitter(self, "dust", Vector3(radius * 0.9, 0.05, radius * 0.9), 14, 0.7, 0.6, 0.35))
			_grow(look, Vector3.ONE * 0.2)
		"water_wall":
			var bm := BoxMesh.new()
			bm.size = Vector3(size.x, size.y, size.z * 0.7)
			bm.subdivide_width = 16
			bm.subdivide_height = 10
			var mi := _part(look, bm, ToonFx.mat("water_wall"))
			mi.position = Vector3.UP * size.y * 0.5
			FxParams.put(mi, &"seed", ToonFx.vis_rng.randf() * 5.0)
			var crest := BendLooks.emitter(self, "water", Vector3(size.x * 0.48, 0.05, size.z * 0.3), 40, 0.6, 2.4, 0.12)
			var foam := BendLooks.emitter(self, "foam", Vector3(size.x * 0.48, 0.05, size.z * 0.35), 22, 0.45, 0.8, 0.32)
			var foot := BendLooks.emitter(self, "foam", Vector3(size.x * 0.5, 0.05, size.z * 0.5), 18, 0.6, 0.4, 0.4)
			for e: GPUParticles3D in [crest, foam]:
				e.position = Vector3.UP * size.y
			_fx.append_array([crest, foam, foot])
			_grow(look, Vector3(1.0, 0.02, 1.0))
			_own_fade(look)
		"fire_wall", "burn", "seam":
			_flames(look)
			var h := size.y if kind == "fire_wall" else 0.5
			var em := BendLooks.emitter(self, "embers", Vector3(size.x * 0.5, 0.1, size.z * 0.5), int(10 * maxf(size.x, size.z)),
					1.0, h * 1.6, 0.05)
			em.position = Vector3.UP * h * 0.4
			_fx.append(em)
			var sc := _part(look, ToonFx.plane(), ToonFx.mat("mark_scorch"))
			sc.scale = Vector3(size.x * 0.62, 1.0, size.z * 0.5 + 0.5)
			sc.position = Vector3.UP * 0.02
			FxParams.put(sc, &"t", 0.25)
			FxParams.put(sc, &"seed", ToonFx.vis_rng.randf() * 5.0)
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.55, 0.2)
			l.light_energy = 2.0
			l.omni_range = maxf(size.x, size.z)
			l.position = Vector3.UP * 1.0
			l.shadow_enabled = false
			add_child(l)
			if kind == "fire_wall":
				_own_fade(look)
		"ice_patch":
			var fr := _part(look, ToonFx.plane(), ToonFx.mat("mark_frost"))
			fr.scale = Vector3(radius, 1.0, radius)
			fr.position = Vector3.UP * 0.03
			FxParams.put(fr, &"t", 0.2)
			FxParams.put(fr, &"seed", ToonFx.vis_rng.randf() * 5.0)
			_fx.append(BendLooks.emitter(self, "sparkle", Vector3(radius * 0.7, 0.05, radius * 0.7), 10, 0.8, 0.3, 0.12))
			_grow(look, Vector3(0.1, 1.0, 0.1))
		"gas":
			var gl := BendGas.look(self)             # (Sulphur's gas: a yellow-green haze over its round)
			if gl != null:
				_fx.append(gl)
		"smoke", "dust", "spray", "snow":
			# (smoke: more and smaller puffs, a haze over the same round rather than a few grey lumps; the move review 2026-10-12)
			var sm := kind == "smoke"
			var cl := BendLooks.emitter(self, "smoke" if sm else ("dust" if kind == "dust" else "foam"),
					Vector3(radius, 0.8, radius), 84 if sm else 40, 1.6 if sm else 2.2, 0.6, 0.8 if sm else 1.6)
			_fx.append(cl)
			if kind == "smoke" and cl != null:
				# (round 4: lit warm from under by the flame that made it, for its first warm_s)
				FxParams.put(cl, &"warm", 1.0)
				var tw := cl.create_tween()
				tw.tween_method(func(v: float) -> void: FxParams.put(cl, &"warm", v), 1.0, 0.0,
						maxf(float(ToonFx.looks("smoke").get("warm_s", 0.5)), 0.05))
		"steam":
			var st := BendLooks.emitter(self, "steam", Vector3(radius * 0.7, 0.6, radius * 0.7), 30, minf(life_s, 1.4), 1.2, 1.3)
			st.position = Vector3.UP * 0.6
			_fx.append(st)
		"tornado":
			var rings := 6
			for i in rings:
				var f := float(i) / (rings - 1)
				var b := _part(look, ToonFx.band_mesh(1.0, 1.12, 0.55), ToonFx.mat("wind_funnel" if i % 2 == 0 else "wind_band_fast"))
				b.scale = Vector3.ONE * radius * (0.32 + 0.55 * f)
				b.position = Vector3(sin(i * 1.7) * 0.1 * f, 0.05 + i * 0.38, cos(i * 1.3) * 0.1 * f)
				b.rotation = Vector3(0.08 * sin(i * 2.1), i * 0.9, 0.08 * cos(i * 1.4))
				FxParams.put(b, &"seed", i * 0.29)
			var pivot := Node3D.new()
			pivot.name = "Whirl"
			add_child(pivot)
			var tw := pivot.create_tween().set_loops()
			tw.tween_property(pivot, "rotation:y", TAU, 0.75).from(0.0)
			var debris := BendLooks.emitter(pivot, "debris", Vector3.ONE * 0.1, 18, 1.5, 3.5, 0.18)
			var dust := BendLooks.emitter(pivot, "dust", Vector3.ONE * 0.1, 22, 1.1, 1.2, 0.6)
			for e: GPUParticles3D in [debris, dust]:
				var pm := e.process_material as ParticleProcessMaterial
				pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
				pm.emission_ring_axis = Vector3.UP
				pm.emission_ring_height = 0.3
				pm.emission_ring_radius = radius * (0.85 if e == debris else 0.7)
				pm.emission_ring_inner_radius = radius * 0.4
				pm.gravity = Vector3(0, -1.5, 0) if e == debris else Vector3.ZERO
			_fx.append_array([debris, dust])
			_grow(look, Vector3(0.3, 0.05, 0.3))
		"vacuum":
			for i in 2:
				var b := _part(look, ToonFx.band_mesh(1.0, 0.7, 0.4), ToonFx.mat("wind_band_fast"))
				b.scale = Vector3.ONE * radius * (1.0 - i * 0.35)
				b.position = Vector3.UP * (0.3 + i * 0.5)
				FxParams.put(b, &"seed", i * 0.5)
			_fx.append(BendLooks.emitter(self, "air", Vector3(radius, 0.6, radius), 24, 0.6, -1.0, 0.35))
		"redirect":
			# (the Turn: a ring of water spinning up round the guard's waist, drops flung off it; on the guarder only)
			if r2:
				var ring := _part(look, ToonFx.band_mesh(1.0, 0.86, 0.22), ToonFx.mat("water_strip"))
				ring.scale = Vector3(SWING_R, 1.0, SWING_R)
				ring.position = Vector3.UP * 1.0
				FxParams.put(ring, &"seed", ToonFx.vis_rng.randf() * 5.0)
				var tw := ring.create_tween().set_loops()
				tw.tween_property(ring, "rotation:y", -TAU, 0.45).from(0.0)
				_fx.append(BendLooks.emitter(self, "water", Vector3(SWING_R, 0.1, SWING_R), 12, 0.5, 1.2, 0.1))
				_grow(look, Vector3(0.2, 1.0, 0.2))
		"parry":
			# (the Parry: a hot ring snapping out before the guard's hands, embers off it)
			if r2:
				var ring := _part(look, ToonFx.band_mesh(1.0, 0.8, 0.12), ToonFx.mat("flame_strip"))
				ring.scale = Vector3(0.55, 1.0, 0.55)
				ring.position = Vector3(0.0, 1.2, 0.0) + way * 0.6
				ring.rotation = Vector3(PI / 2.0, 0.0, 0.0)
				ring.look_at_from_position(global_position + Vector3.UP * 1.2 + way * 0.6, global_position + Vector3.UP * 1.2 + way * 2.0, Vector3.UP)
				ring.rotate_object_local(Vector3.RIGHT, PI / 2.0)
				_fx.append(BendLooks.emitter(self, "embers", Vector3(0.4, 0.4, 0.2), 10, 0.5, 1.0, 0.05))
				_grow(look, Vector3.ONE * 0.3)
		"wind_wall":
			# (a standing wall of moving wind: bands streaming across its face, dust whipped up along its foot; each band a flat
			# ellipse its full width across and a hand deep, so it reads as a sheet from any side: deep as the wall, from aside it
			# was a twisted column, a tornado, the move review 2026-10-12)
			for i in 5:
				var b := _part(look, ToonFx.band_mesh(1.0, 0.9, 0.5), ToonFx.mat(["wind_band", "wind_band_fast", "wind_band_slow", "wind_band", "wind_band_fast"][i]))
				b.scale = Vector3(size.x * 0.5, size.y * 0.21, 0.14)
				b.position = Vector3(0.0, size.y * (0.1 + 0.19 * i), 0.0)
				b.rotation = Vector3(0.0, 0.0, 0.08 * (1.0 if i % 2 == 0 else -1.0))
				FxParams.put(b, &"seed", i * 0.41)
			var foot := BendLooks.emitter(self, "dust", Vector3(size.x * 0.5, 0.1, size.z * 0.6), 22, 0.7, 1.4, 0.4)
			var air := BendLooks.emitter(self, "air", Vector3(size.x * 0.5, size.y * 0.45, size.z * 0.4), 20, 0.5, 2.0, 0.35)
			if air != null:
				air.position = Vector3.UP * size.y * 0.5
			_fx.append_array([foot, air])
			_grow(look, Vector3(1.0, 0.05, 1.0))
			_own_fade(look)
		"puddle":
			var wet := _part(look, ToonFx.plane(), ToonFx.mat("mark_wet"))
			wet.scale = Vector3(radius, 1.0, radius)
			wet.position = Vector3.UP * 0.03
			FxParams.put(wet, &"t", 0.15)
			FxParams.put(wet, &"seed", ToonFx.vis_rng.randf() * 5.0)
			_grow(look, Vector3(0.2, 1.0, 0.2))
		"mud":
			# (the Mud set's pool: the scorch mark's browns with no embers, a wet sheen over them, slow bubbles rising)
			var mud := _part(look, ToonFx.plane(), ToonFx.mat("mark_scorch"))
			mud.scale = Vector3(radius, 1.0, radius)
			mud.position = Vector3.UP * 0.03
			FxParams.put(mud, &"t", 0.4)
			FxParams.put(mud, &"seed", ToonFx.vis_rng.randf() * 5.0)
			var sheen := _part(look, ToonFx.plane(), ToonFx.mat("mark_wet"))
			sheen.scale = Vector3(radius * 0.85, 1.0, radius * 0.85)
			sheen.position = Vector3.UP * 0.035
			FxParams.put(sheen, &"t", 0.15)
			FxParams.put(sheen, &"seed", ToonFx.vis_rng.randf() * 5.0)
			_fx.append(BendLooks.emitter(self, "foam", Vector3(radius * 0.6, 0.02, radius * 0.6), 6, 1.2, 0.25, 0.12))
			_grow(look, Vector3(0.2, 1.0, 0.2))


## The zone's Spellbreak effect (SbFx, data/bending/sb_fx; visual only), keyed by the cast that made it (info's tag): its
## start one-shot and its held look, stopped at end(). True when the held look replaces today's (keep_old false).
func _sb_look() -> bool:
	var key := SbFx.key_of(info)
	if key == "":
		return false
	var ctx := {"node": self, "dir": way, "size": size, "radius": radius, "info": info}
	SbFx.fire(owner_node, key, "zone_start", ctx)
	return SbFx.start(self, "zone", owner_node, key, "zone", ctx)


func _part(under: Node3D, m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	under.add_child(mi)
	return mi


## Your own Wind Guard's bands' width (round 4): ToonFx.looks own_guard.band_w seen from your own camera (its owner is this
## machine's player), else 1 (everyone else's read of his guard).
func own_band_w() -> float:
	return float(ToonFx.looks("own_guard").get("band_w", 0.6)) if ToonFx.is_own(owner_node) else 1.0


## A wall's look faded by its owner's camera (round 4, OwnFade: between his camera and his head, or by the camera): every
## mesh under `look` and its emitters.
func _own_fade(look: Node3D) -> void:
	var gs: Array = []
	for c in look.get_children():
		if c is GeometryInstance3D:
			gs.append(c)
	for e in _fx:
		if e is GeometryInstance3D:
			gs.append(e)
	OwnFade.attach(self, gs, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5 - 0.2), Vector3(size.x, size.y, size.z + 0.4)),
			&"own_fade", owner_node)


## The look grows from `from` (its scale) to whole in a quarter second.
func _grow(look: Node3D, from: Vector3) -> void:
	look.scale = from
	var tw := look.create_tween()
	tw.tween_property(look, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The flames of a fire wall (tall sheets in two staggered rows along it) or burning ground (low, scattered over its strip):
## one MultiMesh of flame quads facing the camera, raised from nothing. Round 4: the fire wall's twice as many at 0.6 as wide
## (ToonFx.looks flame.wall), a soft glow under each.
func _flames(look: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(Vector3i(global_position * 10.0)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ToonFx.quad_base()
	var xs: Array[Transform3D] = []
	if kind == "fire_wall":
		var fwl: Dictionary = ToonFx.looks("flame").get("wall", {})
		var n := maxi(int(size.x / 0.42 * float(fwl.get("count_mult", 2.0))), 3)
		var wk := float(fwl.get("width_mult", 0.6))
		for row in 2:
			for i in n:
				var x := (float(i) + 0.5 + (0.5 if row == 1 else 0.0) * 0.9) / n - 0.5
				var h := size.y * rng.randf_range(0.7, 1.15) * (1.0 if row == 0 else 0.8)
				var w := rng.randf_range(0.75, 1.05) * wk
				var z := (row - 0.5) * size.z * 0.5
				xs.append(Transform3D(Basis(Vector3.RIGHT * w, Vector3.UP * h, Vector3.BACK), Vector3(x * size.x, 0.0, z)))
	else:
		var n := maxi(int(size.x * size.z * 2.2), 4)
		for i in n:
			var p := Vector3(rng.randf_range(-0.5, 0.5) * size.x, 0.0, rng.randf_range(-0.5, 0.5) * size.z)
			var h := rng.randf_range(0.35, 0.75)
			xs.append(Transform3D(Basis(Vector3.RIGHT * rng.randf_range(0.45, 0.7), Vector3.UP * h, Vector3.BACK), p))
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Flames"
	mmi.multimesh = mm
	mmi.material_override = ToonFx.mat("flame" if kind == "fire_wall" else "flame_low")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 1.0
	FxParams.put(mmi, &"seed", rng.randf() * 10.0)
	FxParams.put(mmi, &"grow", 0.0)
	look.add_child(mmi)
	var gl := MeshInstance3D.new()
	gl.name = "Glow"
	gl.mesh = ToonFx.quad()
	gl.material_override = ToonFx.mat("flame_glow")
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gh := size.y if kind == "fire_wall" else 0.6
	gl.scale = Vector3(size.x * 1.25, gh * 1.5, 1.0)
	gl.position = Vector3.UP * gh * 0.45
	FxParams.put(gl, &"seed", rng.randf() * 10.0)
	look.add_child(gl)
	# (its crackle while it burns, lower on burning ground; gone with its look: the sound audit, 2026-10-13, a Fire Wall and
	# burning ground stood silent)
	var cr := BendSounds.loop_player(&"fire_crackle", look, rng.randi() % 4)
	if cr != null:
		cr.volume_db += -5.0 if kind == "fire_wall" else -10.0
		cr.play()
	var tw := mmi.create_tween()
	tw.tween_method(func(v: float) -> void: FxParams.put(mmi, &"grow", v), 0.0, 1.0, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(dt: float) -> void:
	t += dt
	if owner_node == null or not is_instance_valid(owner_node):
		end("owner")                           # (its caster gone: a bot freed between rounds takes its tornado, its fire wall with it)
		return
	if follow and owner_node != null and is_instance_valid(owner_node):
		global_position = owner_node.global_position
	if kind == "tornado":
		global_position += way * speed * dt
		global_position.y = FormEffects.ground_at(self, global_position).y      # (a deck's, not the terrain's under it)
	elif kind == "steam" and speed > 0.0:
		global_position += way * speed * dt       # (Steamcraft, a skill tree synergy: its steam drifts toward his aim)
	var decides := NetSpells.decides()           # (online a ghost's zone decides nothing: the host's words)
	_tick -= dt
	if _tick <= 0.0:
		_tick = 0.25
		if decides:
			_every(0.25)
	if decides and (kind in ["catch", "deflect", "cushion"] or (r2 and kind in ["air_shield", "wind_guard", "redirect", "parry"])):
		_stones()
	if kind == "wind_wall" and decides:
		_wind_push()
	if r2 and BendR3.stock() and not is_queued_for_deletion():
		BendCombo.guard_tick(owner_node, self, dt)   # (held past its window the gauge drains; empty, the guard breaks)
		if is_queued_for_deletion():
			return
	if t >= life_s:
		end("life")


## A wind wall's push: whoever walks into it is pushed back the way he came (off its near face, WIND_WALL_KNOCK), once a
## PUSH_EVERY_S each (every frame looked at: a man running through crosses it in a few).
func _wind_push() -> void:
	# (a Wind Prison's tall wall looked over from its middle: whoever floats near its top is within near()'s 3 m of it)
	var at := global_position + (Vector3.UP * size.y * 0.5 if prison_s > 0.0 else Vector3.ZERO)
	for e in BendCaster.near(owner_node, at, size.x * 0.6 + 1.0):
		var n: Node3D = e[0]
		if not inside(n.global_position):
			continue
		var id := n.get_instance_id()
		if prison_s > 0.0 and n is CharacterBody3D and _in_air(n as CharacterBody3D):
			_imprison(n)
			continue
		if BendStatus.now() - float(_pushed.get(id, -INF)) < PUSH_EVERY_S:
			continue
		_pushed[id] = BendStatus.now()
		var side := signf((global_transform.affine_inverse() * n.global_position).z)
		var out := global_basis.z.normalized() * (side if absf(side) > 0.0 else 1.0)
		BendR3.deliver(n, 0.0, n.global_position, out, owner_node, -1.0,
				Vector3(out.x, 0.0, out.z).normalized() * push_mps + Vector3.UP * 0.5, info)


## Who it holds now: everyone within it (round) or in its box.
func inside(p: Vector3) -> bool:
	var l := global_transform.affine_inverse() * p
	if kind in ["bubble", "air_shield", "ice_patch", "smoke", "dust", "spray", "steam", "tornado", "vacuum", "puddle", "gas", "snow"] \
			or kind in GUARDS or kind in ROUND_NEW or round_zone:
		return Vector2(l.x, l.z).length() <= radius and l.y > -1.0 and l.y < 3.5
	return absf(l.x) <= size.x * 0.5 and absf(l.z) <= size.z * 0.5 + 0.3 and l.y > -0.5 and l.y < size.y + 0.3


## Its lasting effects on whom it holds, each `dt` s.
func _every(dt: float) -> void:
	if kind == FireTalents.GAS_KIND and FireTalents.gas_every(self):
		return                                   # (fire touching the cloud lit it first: gone; FireTalents, before its own rules)
	if kind == "snow":
		AirTalents.snow_every(self)              # (Blizzard: its cold, the water it freezes, fire melting it)
	var r := maxf(radius, size.x * 0.6)
	if put_out:
		put_out_fires()
	var now_in := {}
	for e in (BendCaster.near(owner_node, global_position, r + 1.0) if not tick_all else FireTalents.everyone_near(self, global_position, r + 1.0)):
		var n: Node3D = e[0]
		if not inside(n.global_position):
			continue
		now_in[n.get_instance_id()] = true
		if tick_tag != "":
			_matter_tick(n)
			continue
		match kind:
			"fire_wall", "burn":
				if BendR3.stock() and kind == "fire_wall":
					_fire_wall_hit(n, dt)
				else:
					BendR3.deliver(n, damage_s * dt, n.global_position + Vector3.UP, way, owner_node, -1.0, Vector3.ZERO, info)
			"ice_patch", "vacuum":
				BendStatus.slow(n, 0.6)
			"tornado":
				BendR3.deliver(n, damage_s * dt, n.global_position + Vector3.UP, way, owner_node, -1.0,
						way * speed * 1.2 + Vector3.UP * 3.0, info)
			"gas":
				BendGas.tick(self, n)                # (Sulphur's gas: % ticks only, BendGas)
	_inside_was = now_in
	if kind == "gas":
		BendGas.every(self)                      # (Sulphur's gas: a fire wall on it lights it, a wind wall carries it)
	if kind == "redirect" and r2 and BendLoadout.wears(owner_node, "water.turn.cleanse"):
		# (Cleanse, a skill tree enhance: "Your Turn, perfect or late, clears gas within 2.2 m of you": while his Turn stands, its
		# perfect part and its late part alike (the change's "a standing Turn ends gas zones within its radius"), a cloud with
		# gas inside its radius (2.2 m) of him is washed out, a cloud being one zone; an ally's is left)
		var me := owner_node.global_position if is_instance_valid(owner_node) else global_position
		for z in get_tree().get_nodes_in_group(GROUP):
			var g := z as BendZone
			if g != null and g.kind == "gas" and not g.is_queued_for_deletion() and not (g.owner_node != null
					and is_instance_valid(g.owner_node) and BendCaster.same_team(g.owner_node, owner_node)) \
					and absf(g.global_position.y - me.y) < 3.0 \
					and Vector2(g.global_position.x - me.x, g.global_position.z - me.z).length() < radius + g.radius:
				g.wash()
	if kind == "mud":
		_mud_every()
	if kind == "water_wall":
		# (a fire wall it stands in goes out)
		for z in get_tree().get_nodes_in_group(GROUP):
			var o := z as BendZone
			if o != self and o.kind in ["fire_wall", "burn"] and inside(o.global_position):
				if not SbFx.fire(o.owner_node, SbFx.key_of(o.info), "put_out", {"at": o.global_position, "dir": o.way}):
					BendLooks.burst(o.global_position + Vector3.UP, "steam", 30, Vector3.UP, 90.0, 2.5, 1.0)
				o.end()
	if kind == "seam":
		FireTalents.seam_water(self)               # (water on a seam cools it to obsidian; mud quenches it)
	if kind in FireTalents.LIGHTING_ZONES and FireTalents.any(owner_node):
		FireTalents.zone_every(self)               # (a worn talent's fire zone: Scald's steam it touches scalds)


## Bolt `b` passing it (see the header); true when it acted on it. An ally's bolt (BendCaster.same_team: the ring's sides)
## passes as its owner's own does: a guard never sends a teammate's bolt back or eats it.
func on_bolt(b: BendBolt) -> bool:
	if kind in KILN_FIRES and b.kind == "stone" and not b.heated and not b.spent and inside(b.global_position) \
			and BendLoadout.wears(b._by(), KILN_STONE):
		b.heat()                                 # (Kiln Stone: a stone of the wearer's through any fire comes out heated)
	if kind == "gas" and AirTalents.toxic_gale(self, b):
		return true                                  # (Toxic Gale: his Wind Ball bursts the gas on, his now; before its own rules)
	if not b.spent and kind in ["fire_wall", "smoke"] and AirTalents.through_ally_fire(self, b):
		return false                                 # (Dragon Fire: his Gust through an ally's fire carries a front on; it flies on)
	if kind in ["fire_wall", "burn"] and AirTalents.snuffs(self, b):
		return true                                  # (Frost Gust: his Gust puts a foe's fire out)
	if kind == "gas":
		# (Sulphur's gas: fire lights it, a Washout wearer's water washes it, wind carries it, his own Pebbles with Flint light it:
		# BendGas)
		return not b.spent and inside(b.global_position) and BendGas.react(self, b)
	if kind == "steam" and b.kind == "fire" and not b.spent and FireTalents.any(b.caster) and inside(b.global_position):
		FireTalents.through_steam(self, b.caster)    # (a worn Scald: his fire through steam; it passes on as ever)
	if kind == "seam" and b.kind == "water" and not b.spent:
		FireTalents.seam_bolt(self, b)               # (water on a Magma seam cools it to obsidian)
	if kind == "fire_wall" and b.kind == "fire" and not b.spent and not b.wall_boosted and BendR3.stock() \
			and (b.caster == owner_node or BendCaster.same_team(b.caster, owner_node)) and inside(b.global_position):
		b.wall_boost("fire")                         # (his fire through his own Fire Wall: bigger, faster; the owner 2026-10-12)
		return false
	if b.spent or b.caster == owner_node or not inside(b.global_position) or BendCaster.same_team(b.caster, owner_node) \
			or b.swinging():
		return false
	if r2:
		return _guard_bolt(b)
	match kind:
		"bubble":
			if b.kind == "fire":
				BendLooks.burst(b.global_position, "steam", 22, Vector3.UP, 120.0, 2.0, 0.7)
				BendBolt.steam(owner_node, b.global_position)
				b.end("steam")
				return true
			if b.kind in ["air", "water"]:
				BendLooks.burst(b.global_position, "water", 12)
				b.end("bubble")
				return true
		"water_wall":
			if b.kind == "fire":
				BendLooks.burst(b.global_position, "steam", 22, Vector3.UP, 120.0, 2.0, 0.7)
				BendBolt.steam(owner_node, b.global_position)
				b.end("steam")
				return true
			if b.kind == "water":
				b.zone_wall = true                # (stopped at a wall: Splashdown's puddle, BendBolt.end)
				b.end("drunk")
				return true
		"air_shield":
			if b.kind in LIGHT:
				_send_back(b)
				return true
		"fire_wall", "burn":
			if b.kind == "ice":
				BendLooks.burst(b.global_position, "water", 12)
				b.end("melted")
				return true
			if b.kind == "water":
				if not SbFx.fire(owner_node, SbFx.key_of(info), "put_out", {"at": global_position, "dir": way}):
					BendLooks.burst(global_position + Vector3.UP, "steam", 30, Vector3.UP, 90.0, 2.5, 1.0)
				b.zone_wall = true                # (stopped at the fire it put out: Splashdown's puddle, BendBolt.end)
				b.end("steam")
				end()
				return true
			if b.kind == "air" and not b.burning:
				b.burning = true
				SbFx.fire(owner_node, SbFx.key_of(info), "blown", {"at": b.global_position, "dir": b.velocity})
				return true
		"snow":
			if b.kind == "fire":
				AirTalents.melt_snow(self)           # (Blizzard: fire melts it out in a second)
		"wind_wall":
			if BendR3.stock() and b.kind == "ice" and b.shape == "spear":
				# (the Ice Spear slices through a wind wall, the owner 2026-10-12: its cut in the wind, flying on as it was)
				if not b.guarded_by.has(get_instance_id()):
					b.guarded_by.append(get_instance_id())
					BendLooks.burst(b.global_position, "air", 14, b.velocity.normalized().cross(Vector3.UP), 90.0, 4.0, 0.2, false)
					BendLooks.burst(b.global_position, "ice", 8, b.velocity.normalized(), 40.0, 3.0, 0.2, false)
				return false
			if AirTalents.wall_shards(self, b):
				return true                          # (Frostwind: his Wind Wall drops water and ice as shards)
			if b.kind in LIGHT and not b.guarded_by.has(get_instance_id()) and prison_s <= 0.0:
				# (blown up and aside, not sent back: up over the wall and off to the side it was nearer)
				b.guarded_by.append(get_instance_id())
				var across := global_basis.x.normalized()
				var off := signf((global_transform.affine_inverse() * b.global_position).x)
				var v := b.velocity
				var sp := v.length() * 0.6
				b.velocity = (Vector3.UP * 1.1 + across * (off if absf(off) > 0.0 else 1.0) + v.normalized() * 0.35).normalized() * sp
				b.travelled = maxf(b.travelled, b.range_m - 6.0)          # (it dies out a few metres on)
				if not SbFx.fire(owner_node, SbFx.key_of(info), "deflect", {"at": b.global_position, "dir": b.velocity}):
					BendLooks.burst(b.global_position, "air", 10, Vector3.UP, 60.0, 3.0)
				took += 1
				return true
		"redirect":
			if b.kind in ["water", "ice"]:
				_send_back(b)
				return true
		"return":
			if b.kind in LIGHT:
				_send_back(b)
				return true
		"catch", "deflect", "cushion":
			if b.kind == "stone":
				_take_bolt(b)
				return true
		"parry":
			if b.kind == "fire":
				_aside(b)
				return true
		"spin":
			if b.kind in LIGHT:
				_aside(b)
				return true
		"absorb":
			if b.kind == "water":
				BendStatus.heal(owner_node, 6.0)
				b.end("absorbed")
				took += 1
				return true
		"gas":
			# (Washout, a skill tree synergy: the wearer's Splash and Lash wash out a gas cloud they pass through, and fly on)
			if b.kind == "water" and washes(b):
				wash()
				return true
		"mud":
			# (the Mud set: a floor wave of fire dies in the mud; shots through the air pass over it)
			if b.floor_wave and b.kind == "fire":
				BendLooks.burst(b.global_position + Vector3.UP * 0.3, "steam", 14, Vector3.UP, 80.0, 2.0, 0.5)
				BendLooks.sound("steam", "hit", b.global_position, -6.0)
				b.end("quenched")
				return true
			if b.low and b.kind == "stone" and not b.floor_wave:
				# (a stone rolling along the deck, a low stone bolt: earth's Avalanche, built in its lane; Classic has none)
				# stops in the mud; a stone in the air passes over it
				BendLooks.burst(b.global_position, "stone", 10, Vector3.UP, 60.0, 1.5, 0.2)
				b.end("dropped")
				return true
	return false


# ---------------------------------------------------------------- the Mud set (skill_tree.json skill_sets.mud; water's)
## How long `by`'s mud pools last: the set's pool_life_s (8 s), Delta's own over it (set:mud.pool_life_s).
static func mud_life(by: Node) -> float:
	return BendLoadout.tune_f(by, "set:mud.pool_life_s", _mud_rule("pool_life_s", 8.0))


## A number of the Mud set's zone rules (skill_tree.json skill_sets.mud.zone), `def` when it has none.
static func _mud_rule(key: String, def: float) -> float:
	var v: Variant = BendLoadout.set_rule("mud", key)
	return float(v) if v is float or v is int else def


## At most pools_per_caster mud pools of `by`'s at once: the oldest dry up.
static func _cap_mud(by: Node) -> void:
	var mine: Array[BendZone] = []
	for z in by.get_tree().get_nodes_in_group(GROUP):
		var m := z as BendZone
		if m != null and m.kind == "mud" and m.owner_node == by and not m.is_queued_for_deletion() and not m.has_meta(MIRE_META):
			mine.append(m)
	mine.sort_custom(func(a: BendZone, b: BendZone) -> bool: return a.get_instance_id() < b.get_instance_id())
	var cap := int(_mud_rule("pools_per_caster", 4.0))
	while mine.size() > cap:
		mine.pop_front().end("dried")


## `by`'s Mire dried up (a new one placed: one at a time).
static func _end_mire(by: Node) -> void:
	for z in by.get_tree().get_nodes_in_group(GROUP):
		var m := z as BendZone
		if m != null and m.kind == "mud" and m.owner_node == by and m.has_meta(MIRE_META) and not m.is_queued_for_deletion():
			m.end("dried")


## A mud pool each tick (see the set): a fire wall or burning ground over it burns fire_wall_life_on_mud_s from its making at
## most, and dries the pool within dries_under_fire_s; a magma seam over it is quenched, no stone left (the fire set's seam,
## built elsewhere: a BendZone of kind seam ended "quenched"); a stone rolling into it stops. Nobody is slowed, slid or rooted.
var _drying := false
func _mud_every() -> void:
	for z in get_tree().get_nodes_in_group(GROUP):
		var o := z as BendZone
		if o == null or o == self or o.is_queued_for_deletion() or not _reaches(o):
			continue
		if o.kind in ["fire_wall", "burn"]:
			o.life_s = minf(o.life_s, _mud_rule("fire_wall_life_on_mud_s", 2.0))
			if not _drying:
				_drying = true
				life_s = minf(life_s, t + _mud_rule("dries_under_fire_s", 1.0))
				BendLooks.burst(global_position + Vector3.UP * 0.3, "steam", 16, Vector3.UP, 70.0, 1.5, 0.6)
		elif o.kind == "seam":
			BendLooks.burst(o.global_position + Vector3.UP * 0.3, "steam", 18, Vector3.UP, 80.0, 2.0, 0.6)
			o.end("quenched")
	for s in get_tree().get_nodes_in_group(FormStone.GROUP):
		var st := s as FormStone
		if st == null or st.freeze or not inside(st.global_position):
			continue
		var v := st.linear_velocity
		if Vector2(v.x, v.z).length() > 0.5:
			st.linear_velocity = Vector3(0.0, minf(v.y, 0.0), 0.0)
			st.angular_velocity = Vector3.ZERO
			BendLooks.burst(st.global_position, "stone", 8, Vector3.UP, 60.0, 1.5, 0.2)


## Whether zone `o` reaches over this one's ground: round ones by their radii, a wall or a strip by the nearest point of its
## footprint.
func _reaches(o: BendZone) -> bool:
	var c := global_position
	if o.kind in ["bubble", "air_shield", "ice_patch", "smoke", "dust", "spray", "steam", "tornado", "vacuum", "puddle"] \
			or o.kind in ROUND_NEW:
		return Vector2(o.global_position.x - c.x, o.global_position.z - c.z).length() <= radius + o.radius
	var l := o.global_transform.affine_inverse() * c
	var near := Vector2(clampf(l.x, -o.size.x * 0.5, o.size.x * 0.5), clampf(l.z, -o.size.z * 0.5, o.size.z * 0.5))
	return Vector2(l.x, l.z).distance_to(near) <= radius


## Whether bolt `b` washes out gas: a Splash or a Lash (not sent back) of a fighter who wears Washout.
static func washes(b: BendBolt) -> bool:
	return BendLoadout.wears(b._by(), "water.splash.washout") and not bool(b.info.get("returned", false)) \
			and String(b.info.get("tag", "")).get_slice(".", 0) in WASH_TAGS


## This gas cloud washed out by water (Washout, Cleanse): a ring of spray where it hung, gone.
func wash() -> void:
	if is_queued_for_deletion():
		return
	BendLooks.burst(global_position + Vector3.UP * 0.8, "water", 26, Vector3.UP, 170.0, 3.0, 0.5)
	BendLooks.sound("water", "hit", global_position + Vector3.UP, -6.0)
	end("washed")


## A Wind Prison's catch (prison_s): `n`, in the air inside it, held where he is for prison_s x what his last floats left
## (BendStatus.float_up with no rise: it shares a knock-up float's memory), helpless (his hitstun covers it), still, once a
## wall (a push of it on the ground before does not count). Its look round him: BendLooks.prison, wind bands round his middle.
func _imprison(n: Node3D) -> void:
	var id := n.get_instance_id()
	if _caught.has(id):
		return
	_caught[id] = true
	imprison(n, prison_s)


## Whether `n` is in the air for a Wind Prison (a puppet online: its owner's word, RingMoves' puppet state).
static func _in_air(n: CharacterBody3D) -> bool:
	return not n.is_on_floor() if NetSpells.owns(n) else BendR3.airborne(n)


## `n` caught in a Wind Prison for `s` (see _imprison): his float, his hitstun over it, his motion stopped, the bands round him.
## Online his own machine's (NetSpells.here: the host's word to his owner).
static func imprison(n: Node3D, s: float) -> void:
	if n == null or not is_instance_valid(n) or not NetSpells.here(n, "imprison", [s]):
		return
	var held := BendStatus.float_up(n, 0.0, s)
	if held <= 0.0:
		return
	var kn := BendKnock.of(n)
	if kn != null:
		kn.stun_t = maxf(kn.stun_t, held)
		kn.scale_carry(0.0)                      # (held where he is: the knock's carry stopped)
	if n is CharacterBody3D:
		(n as CharacterBody3D).velocity = Vector3.ZERO
	BendLooks.prison(n, held)


func _send_back(b: BendBolt) -> void:
	var to := (b.caster as Node3D).global_position + Vector3.UP * 1.2 if b.caster != null and is_instance_valid(b.caster) \
			else b.global_position - b.velocity
	b.redirect(to - b.global_position, owner_node)
	BendLooks.burst(b.global_position, b.kind, 10)
	took += 1


## Knocked aside (the open world's parry, spin, deflect): off to the side of its line the bolt already is on (no dice: round
## 2 took the random side out).
func _aside(b: BendBolt) -> void:
	var right := b.velocity.cross(Vector3.UP).normalized()
	var off := (b.global_position - owner_node.global_position).dot(right)
	var side := right * (1.0 if off >= 0.0 else -1.0)
	b.redirect(side + b.velocity.normalized() * 0.3, owner_node)
	took += 1


# ---------------------------------------------------------------- round 2: the timed guards (see the header)
## Bolt `b` met by this element's guard (r2): perfect or late by the guard's age (perfect_s), the guard matrix's answer.
## True when it acted (a bolt it lets pass, or one it halved already: false). Round 3, the % ring (BendR3.stock): every
## guard a shield (spec §2.5): a cell the matrix lets pass is stopped on the beat (nothing through, no reward) and halved
## late as a slide (_shield_bolt); earth's catch is a full catch within its window_s of standing and late after it, the
## stone dropped loose at his feet (_late_drop); a jab it took ends its sender's string (BendR3.jab_guarded).
func _guard_bolt(b: BendBolt) -> bool:
	if b.guarded_by.has(get_instance_id()):
		return false
	var what := b.kind
	var perfect := t <= perfect_s
	var stock := BendR3.stock()
	var shooter := b._by()                       # (before a send-back makes it the guarder's: the cast reward's other side)
	if stock and bool(b.info.get("jab", false)):
		BendR3.jab_guarded(b.caster)
	match kind:
		"catch":
			if what != "stone":
				# (the owner, 2026-10-12: earth answers the other elements too, but "the only catch and press e is when its a
				# earth on earth everything else is flow": round him and back on its own, made of both; _earth_flow)
				if not EARTH_FLOWS.has(what) or (b.floor_wave and what != "fire"):
					return _shield_bolt(b, perfect, what)     # (fire's floor wave flows: a magma wave, _earth_flow)
				if perfect:
					_earth_flow(b, what)
				else:
					_late(b)
				took += 1
				_result("perfect" if perfect else "late", what, shooter)
				return true
			if stock and t > window_s:
				_late_drop(b.damage, b.knock_mps, b.up_mps, b.velocity, b.global_position, b._by(), b.lock_s, b.info, b.weight)
				b.end("dropped")
				took += 1
				_result("late", what)
				return true
			if bool(b.info.get("avalanche", false)):
				# (an Avalanche's rolling stones, GustLift.AVALANCHE: a Catch holds one of its three, the rest drop at the catcher's
				# feet, the thrower's loose stones)
				var vid := int(b.info.get("volley_id", 0))
				if _avalanche_took.has(vid):
					_avalanche_drop(b)
					took += 1
					_result("perfect" if perfect else "late", what, shooter)
					return true
				_avalanche_took[vid] = true
			_take_bolt(b, perfect)
			_result("perfect" if perfect else "late", what, shooter)
			return true
		"redirect":
			if what == "stone" and b.heated:
				b.douse()                           # (Kiln Stone: a Turn douses a heated stone to a plain one, then takes it as stone)
			# (the Air Lance, the only air spear: the Turn takes it as water and ice, and it leaves as ice)
			var lance := what == "air" and b.shape == "spear"
			if what in ["water", "ice"] or lance:
				if perfect:
					# (Whirl Turn, a skill tree twist: held on, the swing goes on round him up to swing_hold_s; whirl_held)
					b.begin_swing(owner_node, SWING_S, SWING_R, BendLoadout.tune_f(owner_node, "rules:guard_rules.perfect_mult",
							Bending.rule("perfect_mult", 1.2)), "ice" if lance else "",
							swing_hold_s if BendLoadout.wears(owner_node, WHIRL) else 0.0)
				else:
					_late(b)
			elif what in ["air", "stone"]:
				# (the owner, 2026-10-12: "if water parries wind then it shoots mini spears", and "water catch earth ... creates a
				# mud spear": the Turn's swing, leaving as mini ice spears or as a spear of mud that slows; _turn_back)
				if perfect:
					_turn_back(b, what)
				else:
					_late(b)
			elif what == "fire":
				if perfect:
					if not SbFx.fire(owner_node, SbFx.key_of(info, move_id, "redirect"), "doused", {"at": b.global_position, "dir": b.velocity}):
						BendLooks.burst(b.global_position, "steam", 22, Vector3.UP, 120.0, 2.0, 0.7)
					BendBolt.steam(owner_node, b.global_position)
					b.end("steam")
				else:
					_late(b)
			else:
				return _shield_bolt(b, perfect, what)
		"parry":
			if what == "fire":
				if perfect:
					_moon_back(b)
				else:
					_late(b)
			elif what == "stone":
				# (the owner, 2026-10-12: "if fire catches earth then magma ball": melted as it circles him, a magma ball back along
				# his aim, burning (heated: a Turn douses it); a stone wave along the deck back along the floor, heated)
				if perfect:
					_moon_back(b, "stone", "magma")
					b.heat()
				else:
					_late(b)
			elif what == "water":
				# (the owner, 2026-10-12: fire and water never send each other back: boiled to steam where it meets him)
				if perfect:
					if not SbFx.fire(owner_node, SbFx.key_of(info, move_id, "parry"), "doused", {"at": b.global_position, "dir": b.velocity}):
						BendLooks.burst(b.global_position, "steam", 22, Vector3.UP, 120.0, 2.0, 0.7)
					BendBolt.steam(owner_node, b.global_position)
					b.end("steam")
				else:
					_late(b)
			elif what == "air":
				# (the owner, 2026-10-12: a Parry counters air too, turned to fire as it circles him)
				if perfect:
					_moon_back(b, "fire")
				else:
					_late(b)
			elif what == "ice":
				if perfect:
					if not SbFx.fire(owner_node, SbFx.key_of(info, move_id, "parry"), "melted", {"at": b.global_position, "dir": b.velocity}):
						BendLooks.burst(b.global_position, "water", 14)
					BendZone.make(owner_node, "puddle", FormEffects.ground_at(owner_node, b.global_position),
							{"radius_m": 0.9, "life_s": 6.0}, way)
					b.end("melted")
				else:
					_late(b)
			else:
				return _shield_bolt(b, perfect, what)
		"air_shield", "wind_guard":
			if what == "air":
				if perfect:
					if not AirTalents.eye_catch(self, b):
						_moon_back(b)                     # (Eye of the Gale's wearer, E held: it circles him while held)
					carry_wind(owner_node, AirTalents.guard_carry_s(owner_node))
				else:
					_late(b)
			elif what in ["fire", "stone", "water", "ice"]:
				# (the owner, 2026-10-12: a Wind Guard counters fire too, sent back as fire; then "the wind can parry a rock and
				# send back most attacks back": stone, water and ice as well, each still what it was. Lightning passes)
				if perfect:
					_moon_back(b)
				else:
					_late(b)
			else:
				return _shield_bolt(b, perfect, what)
		_:
			return false
	took += 1
	_result("perfect" if perfect else "late", what, shooter)
	return true


## A bolt in a cell the matrix lets pass: nothing (false) outside the % ring; in it (round 3, every guard a shield) stopped
## on the beat with no reward, halved late as a slide (true).
func _shield_bolt(b: BendBolt, perfect: bool, what: String) -> bool:
	if not BendR3.stock():
		return false
	var shooter := b._by()
	if perfect:
		BendLooks.burst(b.global_position, b.kind, 12)
		b.end("blocked")
	else:
		_late(b)
	took += 1
	_result("perfect" if perfect else "late", what, shooter)
	return true


## Earth's guard held past its window_s (round 3, spec §2.5): a stone is late: late_mult of its blow gets through to him as a
## slide (BendR3.deliver, slide_only), and it drops at his feet, a loose stone of whoever threw it.
func _late_drop(dmg: float, knock: float, up: float, v: Vector3, at: Vector3, by: Node, lock: float, inf: Dictionary, weight := "medium") -> void:
	var i2 := inf.duplicate()
	i2["slide_only"] = true
	var flat := Vector3(v.x, 0.0, v.z)
	flat = flat.normalized() if flat.length_squared() > 1e-6 else -owner_node.global_basis.z
	BendR3.deliver(owner_node, dmg * late_mult, at, flat, by, lock, (flat * knock + Vector3.UP * up) * late_mult, i2)
	var foot := FormEffects.ground_at(owner_node, owner_node.global_position + flat.cross(Vector3.UP).normalized() * 0.7)
	var s := FormStone.ball(get_tree().current_scene, foot, {"radius_m": 0.2, "mass_kg": 20.0, "rise_s": 0.01, "life_s": 30.0,
			"sink_s": 1.0}, absi(hash(Vector3i(at * 10.0))) % 97, "stone")
	s.state = FormStone.State.RESTING
	s.base = Transform3D(Basis.IDENTITY, foot + Vector3.UP * 0.22)
	s.global_transform = s.base
	s.freeze = false
	s.set_meta(&"bend_weight", weight)
	stones.append(s)
	FormStone.make_loose(s, by)
	BendLooks.burst(at, "stone", 12)


## A late guard: late_mult of its damage and knock go on through (the bolt flies on, halved; this guard is done with it).
func _late(b: BendBolt) -> void:
	b.guarded_by.append(get_instance_id())
	b.info["slide_only"] = true                  # (round 3: what a late guard lets through is a slide on the feet)
	b.damage *= late_mult
	b.knock_mps *= late_mult
	b.up_mps *= late_mult
	# (the glance where it met the guard, before the half that gets through: a late Parry read as no guard at all, its
	# fireball bursting on his head, the move review 2026-10-12)
	BendLooks.burst(b.global_position, b.kind, 10, -b.velocity, 70.0, 2.5, 0.22, false)


## Sent straight back along the guard's aim at once (the Parry's, the Wind Guard's bounce): his now, perfect_mult of its
## speed, damage and knock. A floor wave stays on the floor (its line the aim's yaw).
## A perfect Parry's or Wind Guard's return (the owner, 2026-10-12: "when put parry i want it to loop around like a moon
## before it fires back"; "Counter it"): it circles its guard once at the waist (BendBolt.begin_swing: MOON_S, MOON_R, as a
## Turn's swing but wider) and leaves along his aim x perfect_mult, made `to_kind` as it is caught (a Parry's air: fire).
## A wave along the deck cannot circle him: it goes back along the floor at once (_straight_back), made `to_kind` too.
func _moon_back(b: BendBolt, to_kind := "", p_shape := "") -> void:
	if b.floor_wave or b.low:
		if to_kind != "":
			b.become(to_kind)
		_straight_back(b)
		return
	var k := BendLoadout.tune_f(owner_node, "rules:guard_rules.perfect_mult", Bending.rule("perfect_mult", 1.2))
	b.begin_swing(owner_node, MOON_S, MOON_R, k, to_kind, 0.0, p_shape)


## A water Turn on the beat of air or stone (the owner, 2026-10-12: "if water parries wind then it shoots mini spears"; "water
## catch earth ... creates a mud spear or blast that slows", "either mud spear or a mud wave"): the Turn's swing (Whirl Turn's
## hold as ever), leaving along his aim as mini ice spears (air) or a spear of mud (stone: wrapped in water as it circles, it
## drenches whom it hits for MUD_S, RingRules mud_s). A wave along the deck goes straight back along the floor (a stone one in
## mud).
func _turn_back(b: BendBolt, what: String) -> void:
	var k := BendLoadout.tune_f(owner_node, "rules:guard_rules.perfect_mult", Bending.rule("perfect_mult", 1.2))
	var hold := swing_hold_s if BendLoadout.wears(owner_node, WHIRL) else 0.0
	if what == "stone":
		# (the water round it turns muddy as it takes the stone; the owner, 2026-10-12: "for the water parry channel i also want
		# it to turn muddy")
		b.info["mud_s"] = MUD_S
		b.sheath("mud")                                  # (its splat of mud, the ring muddy: sheath)
		if b.floor_wave or b.low:
			b.become("stone", "mud")
			_straight_back(b)
			return
		b.begin_swing(owner_node, SWING_S, SWING_R, k, "stone", hold, "mud_spear")
		return
	if b.floor_wave or b.low:
		_straight_back(b)
		return
	b.begin_swing(owner_node, SWING_S, SWING_R, k, "ice", hold, "shards")


## Earth's Catch on the beat of a bolt not of stone (the owner, 2026-10-12: "if a earth parries wind they can shoot the pebbels
## instead of a spread it will be a more centered", "if earth parries fire then magma ball", of earth and water "a mud spear or
## a mud wave", then "for earth the only catch and press e is when its a earth on earth everything else is flow"): never held,
## no E; it circles him once like a moon (his body turning with it, GuardSpin) and leaves along his aim x perfect_mult made of
## both (EARTH_FLOWS): air a fist of pebbles (one tight shot), fire a magma ball (burning: heated, fire to the guards); water and
## ice turn to mud as they circle and are slapped down at the swing's end as a wave of mud along the deck toward his aim, the
## Fissure's in mud, that drenches whom it hits (the owner: "earth catching water should be the fissure mud"; MUD_WAVE, MUD_S;
## BendBolt.to_floor_wave). One along the ground goes straight back along it, already what it becomes.
func _earth_flow(b: BendBolt, what: String) -> void:
	var shape := String(EARTH_FLOWS[what])
	if b.floor_wave and what == "fire":
		# (fire's floor wave, the Kick's, on the beat: lifted off the deck, swirled once round his feet as magma (his body
		# turning with it, GuardSpin), then slapped back down along the deck toward his aim as the Fissure in magma, burning:
		# MAGMA_WAVE; the owner, 2026-10-13, "a perfect parry on fire fissure should result in a spin fire ... fissure")
		var km := BendLoadout.tune_f(owner_node, "rules:guard_rules.perfect_mult", Bending.rule("perfect_mult", 1.2))
		b.off_floor()
		b.begin_swing(owner_node, MOON_S, MOON_R, km, "stone", 0.0, "magma", "magma_wave")
		b.heat()
		return
	if shape == "mud_wave":
		b.info["mud_s"] = MUD_S
		b.sheath("mud")
		var k := BendLoadout.tune_f(owner_node, "rules:guard_rules.perfect_mult", Bending.rule("perfect_mult", 1.2))
		b.begin_swing(owner_node, MOON_S, MOON_R, k, "stone", 0.0, "mud", "mud_wave")
		return
	if b.low:
		b.become("stone", shape)
		_straight_back(b)
	else:
		_moon_back(b, "stone", shape)
	if shape == "magma":
		b.heat()


## Every water Turn's ring within reach of `at` made muddy (a stone it swings round turned to mud: BendBolt.sheath and GustLift.
## sheath "mud", on every machine, so whoever plays the guard sees his own; the owner, 2026-10-12: "for the water parry channel
## i also want it to turn muddy"): its strip mud's, its drops mud.
static func muddy_near(from: Node, at: Vector3) -> void:
	if from == null or not from.is_inside_tree():
		return
	for n in from.get_tree().get_nodes_in_group(GROUP):
		var z := n as BendZone
		if z == null or z.kind != "redirect" or not z.r2 or z._muddied:
			continue
		var d := z.global_position - at
		d.y = 0.0
		if d.length() <= SWING_R + 1.5:
			z._muddy()


## This Turn's ring muddy (muddy_near).
var _muddied := false


func _muddy() -> void:
	_muddied = true
	var look := get_node_or_null(^"Look")
	if look == null:
		return
	for c in look.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = ToonFx.mat("mud_strip")
	for e in _fx:
		if is_instance_valid(e) and e is GPUParticles3D:
			(e as GPUParticles3D).emitting = false
	var drops := BendLooks.emitter(self, "mud", Vector3(SWING_R, 0.1, SWING_R), 12, 0.5, 1.2, 0.1)
	if drops != null:
		_fx.append(drops)


## A flying stone (a GustLift's: a Spike, a Boulder, a stone thrown back) met on the beat by a guard but earth's (the owner,
## 2026-10-12: "the wind can parry a rock and send back"): it swings round him and leaves along his aim, his (GustLift.
## begin_swing): the Wind Guard's moon as it is; the Turn's swing in water, a heated one doused, leaving as mud that drenches
## whom it hits (MUD_S); the Parry's moon, melted to a magma ball, burning.
func _lift_swing(lift: GustLift) -> void:
	lift.set_meta("bend_guarded_%d" % get_instance_id(), true)
	var k := BendLoadout.tune_f(owner_node, "rules:guard_rules.perfect_mult", Bending.rule("perfect_mult", 1.2))
	match kind:
		"redirect":
			lift.douse()
			lift.sheath("mud")                    # (the water round it muddy as it swings: a stone turned to mud)
			BendLooks.burst(lift.stone.global_position, "mud", 18, Vector3.UP, 150.0, 3.0, 0.35)
			lift.stone.set_meta(FormStone.PACK_META, "mud")
			FormStone.pack_look(lift.stone as FormStone)
			var li: Dictionary = (lift.get_meta(&"bend_info", {}) as Dictionary).duplicate()
			li["mud_s"] = MUD_S
			lift.set_meta(&"bend_info", li)
			lift.begin_swing(owner_node, SWING_S, SWING_R, k)
		"parry":
			lift.heat()
			lift.stone.set_meta(FormStone.PACK_META, "magma")
			FormStone.pack_look(lift.stone as FormStone)
			lift.begin_swing(owner_node, MOON_S, MOON_R, k)
		_:
			lift.begin_swing(owner_node, MOON_S, MOON_R, k)


func _straight_back(b: BendBolt) -> void:
	var to := guard_aim(owner_node, b.global_position)
	var k := BendLoadout.tune_f(owner_node, "rules:guard_rules.perfect_mult", Bending.rule("perfect_mult", 1.2))
	b.redirect(to - b.global_position, owner_node)
	b.info["ret_mult"] = k
	b.velocity *= k
	b.damage *= k
	b.knock_mps *= k
	b.up_mps *= k
	BendLooks.burst(b.global_position, b.kind, 12)


## The Avalanche volleys this Catch held a stone of (volley id -> true).
var _avalanche_took := {}


## An Avalanche stone past the one this Catch holds: stopped and dropped at the catcher's feet, a loose stone of its thrower's.
func _avalanche_drop(b: BendBolt) -> void:
	var by: Node = b._by()
	var side := Vector3.UP.cross(b.velocity).normalized() if Vector3.UP.cross(b.velocity).length_squared() > 1e-6 else Vector3.RIGHT
	var off := side * (0.6 if stones.size() % 2 == 0 else -0.6)
	b.end("dropped")
	var foot := FormEffects.ground_at(owner_node, owner_node.global_position + off)
	var s := FormStone.ball(get_tree().current_scene, foot, {"radius_m": clampf(b.radius, 0.12, 0.45), "mass_kg": 20.0, "rise_s": 0.01,
			"life_s": 30.0, "sink_s": 1.0}, absi(hash(Vector3i(foot * 10.0))) % 97, "stone")
	s.state = FormStone.State.RESTING
	s.freeze = false
	s.set_meta(&"bend_weight", b.weight)
	stones.append(s)
	FormStone.make_loose(s, by)
	BendLooks.burst(foot + Vector3.UP * 0.2, "stone", 10)


## Where guard `owner` (a body) aims now (its caster's aim point: the player's crosshair, a bot's target), from `from`; along
## its facing 20 m on when it has none.
static func guard_aim(owner: Node3D, from: Vector3) -> Vector3:
	var bc := BendCaster.of(owner)
	if bc != null and bc.valid():
		var a := BendEffects.aim(bc)
		var p: Vector3 = a.point
		if p.is_finite() and p.distance_to(from) > 0.5:
			return p
		return from + (a.dir as Vector3) * 20.0
	return from + owner.global_basis.z * -20.0


## This guard's result (perfect, late, whiff) told: report(). A perfect one on a spell in the % ring (`by` its caster): the
## cast reward (BendStatus.parry_reward: his next cast quicker, the caster's slower).
func _result(result: String, what: String, by: Node = null) -> void:
	if result != "whiff":
		results.append(result)
	report(owner_node, result, what, element)
	NetSpells.word(["guard", owner_node, result, what, element])     # (online: told on every machine, report there)
	if result == "perfect" and what != "" and BendR3.stock():
		BendStatus.parry_reward(owner_node, by)


## A guard's result told (see the header): the owner's meta bend_last_guard {result, what, at}, his caster's guarded
## signal, the counts, its look and sound on him.
static func report(owner: Node, result: String, what: String, el: String) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	owner.set_meta(&"bend_last_guard", {"result": result, "what": what, "at": BendStatus.now(), "element": el})
	AirTalents.on_guard(owner, result, el)        # (Rebound's head start after a perfect Wind Guard; Classic none)
	var c: Dictionary = counts.get(el, {})
	c[result] = int(c.get(result, 0)) + 1
	counts[el] = c
	if owner is Node3D:
		BendLooks.guard_result(owner as Node3D, el, result)
	if result == "perfect" and el == "water" and BendLoadout.wears(owner, EDDY):
		# (Eddy, a skill tree technique: after a perfect Turn his next Lash or Spear begun within EDDY_S starts EDDY_FILL full;
		# eddy_fill. Its tell the water charged on his own hands)
		owner.set_meta(EDDY_META, BendStatus.now() + EDDY_S)
		if owner is Node3D:
			BendLooks.burst((owner as Node3D).global_position + Vector3.UP * 1.3, "water", 10, Vector3.UP, 70.0, 1.2, 0.12)
	var bc := BendCaster.of(owner)
	if bc != null:
		bc.guarded.emit(result, what)
	FireTalents.guarded(owner, result, what, el)        # (a worn talent's answer to a guard: Hot Hands)


## Eddy (a skill tree technique, BendZone.report): the fill a lock of move `m` begun now by `body` starts at, EDDY_FILL for his
## Lash or Spear within EDDY_S of a perfect Turn (spent by it), else 0 (never a zero lock: the rest still fills).
static func eddy_fill(body: Node, m: String) -> float:
	if not m in EDDY_MOVES or body == null or not is_instance_valid(body) or not body.has_meta(EDDY_META):
		return 0.0
	var until := float(body.get_meta(EDDY_META))
	body.remove_meta(EDDY_META)
	return EDDY_FILL if BendStatus.now() <= until else 0.0


## Whirl Turn (a skill tree twist): whether `body` holds a swing on now: the player's E held (SwayCaster); a bot holds it while
## the foe it aims at stands guarding (it sends it on when he cannot guard it).
static func whirl_held(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	var sc := SwayCaster.of(body) if body is FrontierPlayer else null
	if sc != null:
		return sc._guard_down()
	var bc := BendCaster.of(body)
	var t: Node3D = bc.aim_target() if bc != null and bc.valid() else null
	return t != null and guarding(t)


## Whether `body` stands in water of his own now (Wellspring, a skill tree enhance): a puddle (or mud pool) of his he is in, or
## a grate within its reach (Bending.POOLS: the ring's, reach_m).
static func in_own_water(body: Node3D) -> bool:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return false
	for n in body.get_tree().get_nodes_in_group(Bending.POOLS):
		var n3 := n as Node3D
		if n3 is BendZone:
			if (n3 as BendZone).owner_node == body and not n3.is_queued_for_deletion() and (n3 as BendZone).inside(body.global_position):
				return true
		elif n3 != null and n3.has_meta(&"reach_m") \
				and Vector2(n3.global_position.x - body.global_position.x, n3.global_position.z - body.global_position.z).length() <= float(n3.get_meta(&"reach_m")):
			return true
	return false


## Whether `body` stands in a mud pool of his own now (Delta's home ground), on the deck.
static func in_own_mud(body: Node3D) -> bool:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return false
	if body is CharacterBody3D and not (body as CharacterBody3D).is_on_floor():
		return false
	for z in body.get_tree().get_nodes_in_group(GROUP):
		var m := z as BendZone
		if m != null and m.kind == "mud" and m.owner_node == body and not m.is_queued_for_deletion() and m.inside(body.global_position):
			return true
	return false


## The fill rate a lock of `body`'s takes from where he stands: Delta's in his own mud, else 1 (a bot's tick; the player's is
## SwayCaster.passive_fill).
static func home_fill(body: Node3D) -> float:
	return DELTA_FILL if BendLoadout.wears(body, DELTA) and in_own_mud(body) else 1.0


## Whether `body` has a round-2 guard standing now (a catch, a Turn, a parry, a Wind Guard).
static func guarding(body: Node) -> bool:
	for z in body.get_tree().get_nodes_in_group(GROUP):
		var g := z as BendZone
		if g != null and g.r2 and g.owner_node == body and not g.is_queued_for_deletion():
			return true
	return false


## Carried wind on `body` (air's passive: a hit straight out of a dash, a near miss or a bounced guard knocks harder for
## Bending.passive("air").after_s): its meta bend_carry_until; its spiral and whistle on him.
static func carry_wind(body: Node, s := -1.0) -> void:
	if body == null or not is_instance_valid(body) or BendPoses.element_of(body) != "air":
		return
	if not NetSpells.here(body, "carry", [s] if s >= 0.0 else []):
		return                                   # (online: his owner's, NetSpells)
	# (`s` >= 0: its own length, a worn talent's: Eye of the Gale's perfect guard; else the passive's)
	body.set_meta(&"bend_carry_until", BendStatus.now() + (s if s >= 0.0 else BendLoadout.tune_f(body, "rules:passives.air.after_s",
			float(Bending.passive("air").get("after_s", 0.8)))))
	if body is Node3D:
		BendLooks.carried(body as Node3D)


## The lock (s) of `body`'s next guard: with a caught stone held the throw back's (return_lock_s, perfect_return_lock_s off
## a clean catch); within whiff_s of a whiffed guard whiff_lock_s; else `base` (the guard's own).
static func guard_lock_s(body: Node, base: float) -> float:
	var held := held_stone(body)
	if held != null:
		return Bending.rule("perfect_return_lock_s", 0.1) if bool(held.get_meta(&"bend_clean", false)) \
				else BendLoadout.tune_f(body, "rules:guard_rules.return_lock_s", Bending.rule("return_lock_s", 0.35))
	if BendStatus.until(body, &"bend_whiff_until") > 0.0:
		return maxf(base, Bending.rule("whiff_lock_s", 0.5))
	return base


## The stone `body` caught and holds (a catch's: meta bend_held_by; not one flying or lifted), null none. Juggle's wearer (a
## skill tree twist: two held from one window) gets the one he caught first: E throws the oldest, E again the other.
static func held_stone(body: Node) -> Node3D:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return null
	var id := body.get_instance_id()
	var juggle := BendLoadout.wears(body, JUGGLE)
	var best: Node3D = null
	for s in body.get_tree().get_nodes_in_group(FormStone.GROUP):
		if int((s as Node).get_meta(&"bend_held_by", -1)) == id and not GustLift.busy(s) and not (s as Node).is_queued_for_deletion():
			if not juggle:
				return s as Node3D
			if best == null or float((s as Node).get_meta(&"bend_caught_at", 0.0)) < float(best.get_meta(&"bend_caught_at", 0.0)):
				best = s as Node3D
	return best


## Earth's Juggle (data/sway/skill_tree.json earth.catch.juggle; the owner, 2026-10-11: "make sure all the talents work"): its
## wearer's Catch holds up to JUGGLE_MAX stones from one window, side by side before him (the second JUGGLE_SIDE_M beside the
## first); E throws the one caught first (held_stone), E again the other; one more reaching it then is stopped and dropped at
## his feet, a loose stone of its thrower's. Its full-catch time is the node's own (spec window_s, stock guard_catch_s).
const JUGGLE := "earth.catch.juggle"
const JUGGLE_MAX := 2
const JUGGLE_SIDE_M := 0.6


## Every stone `body` holds from a catch (oldest first).
static func held_stones(body: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return out
	var id := body.get_instance_id()
	for s in body.get_tree().get_nodes_in_group(FormStone.GROUP):
		if int((s as Node).get_meta(&"bend_held_by", -1)) == id and not GustLift.busy(s) and not (s as Node).is_queued_for_deletion():
			out.append(s as Node3D)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return float(a.get_meta(&"bend_caught_at", 0.0)) < float(b.get_meta(&"bend_caught_at", 0.0)))
	return out


## A caught stone `s` held by caster `c` thrown back along its aim (E again, or Shove: spec §2.6): its own weight, speed,
## damage and pierce (meta bend_stone_d) x perfect_mult off a clean catch x the rally (1 + the steps of its earlier returns,
## at most rally_max), never under today's Shove return (gust.stone.hurl); a Throw at once (FormEffects.Throw: the
## player's crosshair, a bot's target). The Throw, or null.
static func return_stone(c: Variant, s: Node3D, toward := Vector3.INF) -> FormEffects.Throw:
	var bc := BendCaster.wrap(c)
	if bc == null or not bc.valid() or s == null or not is_instance_valid(s) or not (s is FormStone):
		return null
	var fs := s as FormStone
	SbFx.stop(fs, "held")                        # (its held look let go: the throw's own flight follows)
	if fs.has_meta(BendR3.POP_STONE_META):
		return _throw_pop_stone(bc, fs, toward)
	var pack := String(fs.get_meta(FormStone.PACK_META, ""))
	if pack == "mud":
		_mud_wave(bc, fs, toward)
		return null
	var kind := GustLift.kind_of(fs)
	var floor_d: Dictionary = ((SwayMoves.move("gust").get("stone", {}) as Dictionary).get("hurl", {}) as Dictionary).get(kind,
			((SwayMoves.move("gust").get("stone", {}) as Dictionary).get("hurl", {}) as Dictionary).get("stone", {}))
	var mult := return_mult(fs, bc.body)
	var own: Dictionary = fs.get_meta(&"bend_stone_d", {})
	var fm: Array = floor_d.get("mps", [24.0, 24.0])
	var fd: Array = floor_d.get("damage", [60.0, 60.0])
	var mps := maxf(float(own.get("mps", 0.0)) * mult, float(fm[fm.size() - 1]))
	var on_beat := bool(fs.get_meta(&"bend_clean", false)) and BendLoadout.wears(bc.body, RETURN_TO_SENDER) and beat_return(bc.body, fs)
	if on_beat:
		mps *= RTS_MULT                          # (Return to Sender: a clean catch thrown back on the Beat flies faster)
		BendLooks.beat_flash(_hands_of(bc.body), "earth")
	var dmg := maxf(float(own.get("damage", 0.0)) * mult, float(fd[fd.size() - 1]))
	var knock := maxf(float(own.get("knock_mps", 0.0)) * mult, float(floor_d.get("knock_mps", GustLift.KNOCK_MPS)))
	var hd := floor_d.duplicate()
	hd["mps"] = [mps, mps]
	hd["damage"] = [dmg, dmg]
	hd["knock_mps"] = knock
	hd["pierce"] = bool(own.get("pierce", floor_d.get("pierce", false)))
	if own.has("gravity"):
		hd["gravity"] = minf(float(own.gravity), float(floor_d.get("gravity", 6.0)))
	var clean := bool(fs.get_meta(&"bend_clean", false))
	var rally := float(fs.get_meta(&"bend_rally", 0.0)) + (BendLoadout.tune_f(bc.body, "rules:guard_rules.rally_clean_step",
			Bending.rule("rally_clean_step", 0.2)) if clean else BendLoadout.tune_f(bc.body, "rules:guard_rules.rally_step",
			Bending.rule("rally_step", 0.1)))
	fs.set_meta(&"bend_rally", rally)
	fs.set_meta(&"bend_returns", int(fs.get_meta(&"bend_returns", 0)) + 1)
	fs.set_meta(&"bend_return", {"mps": mps, "damage": dmg, "knock_mps": knock, "mult": mult, "clean": clean, "beat": on_beat})
	for k: StringName in [&"bend_held_by", &"bend_clean", FormStone.LOOSE_META]:
		if fs.has_meta(k):
			fs.remove_meta(k)
	if fs.state == FormStone.State.RISING:
		fs.state = FormStone.State.RESTING
	var td: Dictionary = (SwayMoves.move("stone_form").get("throw", {}) as Dictionary).duplicate(true)
	td["hurl"] = {kind: hd}
	td["rise_s"] = 0.05
	td["chest_m"] = fs.global_position.y - bc.body.global_position.y
	var kn: Dictionary = (td.get("knock_mps", {}) as Dictionary).duplicate()
	kn[kind] = knock
	td["knock_mps"] = kn
	var origin := String(fs.get_meta(BendR3.ORIGIN_META, "stone_form/spike"))
	var th := FormEffects.Throw.start(bc, fs, td, toward)
	if th != null:
		# (round 3: a return, its own class owned by the returner: never staled, no range falloff; spec §2.5)
		var inf := BendR3.info_for(bc, "stone_catch", "catch")
		inf["tag"] = origin + ".return"
		inf["returned"] = true
		inf["ret_mult"] = mult
		inf["origin_tag"] = origin
		inf.erase("jab")
		th.info = inf
		if pack == "magma" and th.lift != null:
			th.lift.heat()                          # (a magma ball burns as it flies: fire to the guards, a Turn douses it)
	BendLooks.burst(fs.global_position, "stone", 12)
	BendSounds.play(&"earth_cast_crack", fs.global_position, 1.0 if clean else -1.0)
	return th


## A mud stone of `bc`'s held (a Spike or a Boulder a water Turn sent back as mud, then caught by earth: _lift_swing) thrown back
## with E (the owner, 2026-10-12: "either mud spear or a mud wave"): it is slapped down before him and runs on along the deck as
## a wave of mud toward `toward` (INF: his aim), MUD_WAVE's, its own numbers x return_mult when they are more (as any return;
## the rally grows), drenching whom it hits for MUD_S (RingRules mud_s; a jump clears it, a wall stops it). A return: the
## returner's class, his. The stone is spent.
static func _mud_wave(bc: BendCaster, fs: FormStone, toward := Vector3.INF) -> BendBolt:
	var p := bc.body
	var own: Dictionary = fs.get_meta(&"bend_stone_d", {})
	var mult := return_mult(fs, p)
	var a := BendEffects.aim(bc)
	var to: Vector3 = toward if toward.is_finite() else (a.point as Vector3)
	var flat := Vector3(to.x - p.global_position.x, 0.0, to.z - p.global_position.z)
	if flat.length_squared() < 1e-4:
		var d0: Vector3 = a.dir
		flat = Vector3(d0.x, 0.0, d0.z)
	flat = flat.normalized() if flat.length_squared() > 1e-6 else -p.global_basis.z
	var spec := MUD_WAVE.duplicate()
	spec["damage"] = maxf(float(own.get("damage", 0.0)) * mult, float(MUD_WAVE.damage))
	spec["knock_mps"] = maxf(float(own.get("knock_mps", 0.0)) * mult, float(MUD_WAVE.knock_mps))
	var origin := String(fs.get_meta(BendR3.ORIGIN_META, "water_jet/splash"))
	var inf := BendR3.info_for(bc, "stone_catch", "catch")
	inf["tag"] = origin + ".return"
	inf["returned"] = true
	inf["ret_mult"] = mult
	inf["origin_tag"] = origin
	inf["mud_s"] = MUD_S
	inf.erase("jab")
	spec["_info"] = inf
	var from := FormEffects.ground_at(p, p.global_position + flat * 0.9)
	var b := BendBolt.launch(p, from, flat, spec)
	BendLooks.burst(fs.global_position, "stone", 16, Vector3.DOWN, 120.0, 3.0, 0.3)
	BendLooks.burst(from + Vector3.UP * 0.2, "mud", 18, Vector3.UP, 120.0, 3.0, 0.3)
	BendSounds.play(&"earth_cast_crack", from, 0.0)
	for k: StringName in [&"bend_held_by", &"bend_clean"]:
		if fs.has_meta(k):
			fs.remove_meta(k)
	fs.queue_free()
	return b


## Earth's Return to Sender (data/sway/skill_tree.json earth.catch.return_to_sender; the owner, 2026-10-11: "make sure all the
## talents work"): a cleanly caught stone its wearer throws back on the Beat (the E that throws it pressed within
## BendLoadout.beat_s of the clean catch: beat_return) flies RTS_MULT faster, a flash on his own hands. Its late return's lock is
## the node's own number (rules:guard_rules.return_lock_s, guard_lock_s).
const RETURN_TO_SENDER := "earth.catch.return_to_sender"
const RTS_MULT := 1.15


## Whether the lock that throws held stone `s` back began within the Beat of its catch (its press at or after the catch, at
## most BendLoadout.beat_s after it): the player's E (SwayCaster.lock_began_at), a bot's (NpcBending's lock start).
static func beat_return(body: Node, s: Node) -> bool:
	var caught := float(s.get_meta(&"bend_caught_at", -INF))
	var pressed := lock_began(body)
	return pressed >= caught - 0.02 and pressed - caught <= BendLoadout.beat_s() + 1e-3


## When `body`'s lock now began (BendStatus.now() when it has none: a cast with no lock).
static func lock_began(body: Node) -> float:
	var sc := SwayCaster.of(body)
	if sc != null:
		return sc.lock_began_at
	if body is NpcFighter and (body as NpcFighter).brain != null and (body as NpcFighter).brain.bending != null:
		return float((body as NpcFighter).brain.bending.get(&"_lock_at"))
	return BendStatus.now()


## What a Beat flash on `body` is drawn at: the player's SwayCaster (his hands), else the body (its chest).
static func _hands_of(body: Node) -> Node:
	var sc := SwayCaster.of(body)
	return sc if sc != null else body


## Earth's Pop stone held in the hand (BendR3.pop_stone) thrown along the aim (E, or Shove; `toward` INF: the aim): its own
## numbers (air_rules.pop.stone), tag air_rules.pop.stone_tag (rock_jab/pop_stone: the Spike's class, staled), not a return.
## The Throw.
static func _throw_pop_stone(bc: BendCaster, fs: FormStone, toward := Vector3.INF) -> FormEffects.Throw:
	var own: Dictionary = fs.get_meta(&"bend_stone_d", {})
	var kind := GustLift.kind_of(fs)
	var mps := float(own.get("mps", 34.0))
	var hd := {"mps": [mps, mps], "damage": [float(own.get("damage", 30.0)), float(own.get("damage", 30.0))],
			"knock_mps": float(own.get("knock_mps", 6.0)), "gravity": float(own.get("gravity", 3.0)), "pierce": false}
	for k: StringName in [&"bend_held_by", &"bend_clean", FormStone.LOOSE_META, BendR3.POP_STONE_META]:
		if fs.has_meta(k):
			fs.remove_meta(k)
	if fs.state == FormStone.State.RISING:
		fs.state = FormStone.State.RESTING
	var td: Dictionary = (SwayMoves.move("stone_form").get("throw", {}) as Dictionary).duplicate(true)
	td["hurl"] = {kind: hd}
	td["rise_s"] = 0.05
	td["chest_m"] = fs.global_position.y - bc.body.global_position.y
	var kn: Dictionary = (td.get("knock_mps", {}) as Dictionary).duplicate()
	kn[kind] = float(hd.knock_mps)
	td["knock_mps"] = kn
	var th := FormEffects.Throw.start(bc, fs, td, toward)
	if th != null:
		var inf := BendR3.info_for(bc, "rock_jab", "pop")
		inf["tag"] = String(BendR3.block("pop").get("stone_tag", "rock_jab/pop_stone"))
		inf.erase("jab")
		th.info = inf
	BendLooks.burst(fs.global_position, "stone", 12)
	BendSounds.play(&"earth_cast_crack", fs.global_position, 0.0)
	return th


## A held stone's throw-back factor now: perfect_mult off a clean catch, times the rally (1 + its earlier returns' steps),
## the whole at most rally_max (spec §2.6: "up to x1.6").
static func return_mult(s: Node, by: Node = null) -> float:
	var clean := bool(s.get_meta(&"bend_clean", false))
	var rally := 1.0 + float(s.get_meta(&"bend_rally", 0.0))
	var who: Node = by if by != null else (instance_from_id(int(s.get_meta(&"bend_held_by", 0))) as Node if s.has_meta(&"bend_held_by") else null)
	var pm := BendLoadout.tune_f(who, "rules:guard_rules.perfect_mult", Bending.rule("perfect_mult", 1.2))
	return minf(rally * (pm if clean else 1.0), Bending.rule("rally_max", 1.6))


## What a guard of `body`'s does to a cone of `cone_kind` reaching him (BendEffects.cone): the share of its damage and knock
## that gets through. A round-2 guard that handles it: perfect 0 (a Turn parts a Wave round him, a Parry eats a fire cone,
## a Wind Guard an air one: charging his Carried wind), late late_mult; else 1. `by`: the cone's caster.
static func cone_mult(body: Node, cone_kind: String, by: Node = null) -> float:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree() or not NetSpells.decides():
		return 1.0
	for z in body.get_tree().get_nodes_in_group(GROUP):
		var bz := z as BendZone
		if bz == null or not bz.r2 or bz.owner_node != body or bz.is_queued_for_deletion():
			continue
		var handles := (bz.kind == "redirect" and cone_kind == "water") or (bz.kind == "parry" and cone_kind == "fire") \
				or (bz.kind in ["air_shield", "wind_guard"] and cone_kind == "air")
		if not handles:
			continue
		var perfect := bz.t <= bz.perfect_s
		bz.took += 1
		bz._result("perfect" if perfect else "late", cone_kind, by)
		if perfect and cone_kind == "air":
			carry_wind(body, AirTalents.guard_carry_s(body))
		return 0.0 if perfect else bz.late_mult
	return 1.0


## Lightning striking `body`: his Parry within its first perfect_s sends it back (the only answer to lightning; spec §2.5).
## The parry zone that does, or null (it hits). `by`: the lightning's caster.
static func lightning_back(body: Node, by: Node = null) -> BendZone:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree() or not NetSpells.decides():
		return null
	for z in body.get_tree().get_nodes_in_group(GROUP):
		var bz := z as BendZone
		if bz == null or not bz.r2 or bz.kind != "parry" or bz.owner_node != body or bz.is_queued_for_deletion():
			continue
		if bz.t <= bz.perfect_s:
			bz.took += 1
			bz._result("perfect", "lightning", by)
			return bz
		return null                              # (late on lightning: it hits; the parry ends a whiff)
	return null


## A stone bolt met by an earth guard: deflect knocks it aside; catch and cushion end it, a FormStone of its size left in its
## place (caught: held before the owner for Earth Shove; cushioned: dropped where it was).
func _take_bolt(b: BendBolt, perfect := false) -> void:
	if kind == "deflect":
		_aside(b)
		BendLooks.burst(b.global_position, "stone", 10)
		return
	var at := b.global_position
	var v := b.velocity
	var rad := clampf(b.radius, 0.12, 0.45)
	var own: Dictionary = b.stone_d if not b.stone_d.is_empty() else {"mps": v.length(), "damage": b.damage,
			"knock_mps": b.knock_mps, "gravity": b.gravity, "pierce": false, "weight": b.weight}
	var thrower := b._by()
	b.end("caught" if kind == "catch" else "cushioned")
	var s := FormStone.ball(get_tree().current_scene, at - Vector3.UP * rad, {"radius_m": rad, "mass_kg": 20.0, "rise_s": 0.01,
			"life_s": 30.0, "sink_s": 1.0}, absi(hash(Vector3i(at * 10.0))) % 97, "stone")
	s.state = FormStone.State.RESTING
	s.base = Transform3D(Basis.IDENTITY, at)
	s.global_transform = s.base
	s.set_meta(&"bend_shape", b.shape)
	s.set_meta(&"bend_weight", b.weight)
	if r2:
		s.set_meta(&"bend_stone_d", own)
		s.set_meta(&"bend_rally", b.rally)
		s.set_meta(BendR3.ORIGIN_META, String(b.info.get("origin_tag", b.info.get("tag", "stone_form/spike"))))
	stones.append(s)
	_take_stone(s, v, perfect, thrower)


## What burns in it goes out: fire walls and burning ground (steam), campfires, torches not in its owner's hand. How many.
func put_out_fires() -> int:
	var n := 0
	for z in get_tree().get_nodes_in_group(GROUP):
		var o := z as BendZone
		if o != null and o != self and o.kind in ["fire_wall", "burn"] and not o.is_queued_for_deletion() \
				and (inside(o.global_position) or o.global_position.distance_to(global_position) <= radius + 1.0):
			if not SbFx.fire(o.owner_node, SbFx.key_of(o.info), "put_out", {"at": o.global_position, "dir": o.way}):
				BendLooks.burst(o.global_position + Vector3.UP, "steam", 30, Vector3.UP, 90.0, 2.5, 1.0)
			o.end()
			n += 1
	var r := maxf(radius, size.x * 0.5) + 0.5
	for f in get_tree().get_nodes_in_group(Campfire.GROUP):
		if f is Campfire and (f as Campfire).is_lit() and (f as Node3D).global_position.distance_to(global_position) <= r:
			(f as Campfire).smother()
			n += 1
	for f in get_tree().get_nodes_in_group(TorchFire.GROUP):
		var tf := f as TorchFire
		if tf == null or tf.state == null or not tf.state.lit or tf.global_position.distance_to(global_position) > r:
			continue
		if owner_node != null and is_instance_valid(owner_node) and owner_node.is_ancestor_of(tf):
			continue                              # (its owner's own torch)
		SwayEffects.snuff(tf)
		n += 1
	put_out_n += n
	return n


## The body of a stone's caster (a GustLift's: a SwayCaster's player, a BendCaster's body).
static func _body_of(c: Object) -> Node:
	if c == null or not is_instance_valid(c):
		return null
	var b: Variant = c.get(&"body")
	if b is Node:
		return b as Node
	b = c.get(&"player")
	return b as Node if b is Node else null


## Stones flying at its owner (a guard: catch, deflect, cushion): a Stone Form or Gust throw (GustLift), a bender's spike
## (NpcBending.Flight). (Stone bolts: on_bolt.)
func _stones() -> void:
	var me := owner_node.global_position + Vector3.UP * 1.0
	var mine := get_instance_id()
	var perfect := t <= perfect_s
	for l in get_tree().get_nodes_in_group(GustLift.GROUP):
		var lift := l as GustLift
		if lift == null or lift.phase != GustLift.Phase.FLIGHT or lift.stone == null or not is_instance_valid(lift.stone):
			continue
		if _body_of(lift.caster) == owner_node or BendCaster.same_team(_body_of(lift.caster), owner_node):
			continue
		# (round 3: a spike met by its point, which leads it: GustLift._lead)
		var lead := lift._lead() if BendR3.stock() else Vector3.ZERO
		if (lift.stone.global_position + lead).distance_to(me) > radius or lift.has_meta("bend_guarded_%d" % mine):
			continue
		if r2 and kind in ["air_shield", "wind_guard", "redirect", "parry"]:
			# (the owner, 2026-10-12: "the wind can parry a rock and send back", water's Turn makes it mud and fire's Parry
			# magma: on the beat it swings round him and leaves along his aim, his (_lift_swing); late, half through)
			var thrower1 := _body_of(lift.caster)
			if perfect:
				_lift_swing(lift)
			else:
				_late_lift(lift)
			took += 1
			_result("perfect" if perfect else "late", "stone", thrower1)
			continue
		var s := lift.stone as Node3D
		var v := lift.velocity
		if r2 and kind == "catch" and BendR3.stock() and t > window_s:
			# (round 3: held past its window a stone is late: half through as a slide, the stone dropped at his feet)
			var hd0 := lift._hurl_d()
			var li: Dictionary = lift.get_meta(&"bend_info", {})
			var by1 := _body_of(lift.caster)
			lift.drop(false)
			if is_instance_valid(s):
				s.queue_free()
			_late_drop(lift.damage_now(), float(hd0.get("knock_mps", GustLift.KNOCK_MPS)), float(hd0.get("knock_up_mps", GustLift.KNOCK_UP_MPS)),
					v, me, by1, -1.0, li)
			took += 1
			_result("late", "stone")
			continue
		if r2 and kind == "catch":
			s.set_meta(BendR3.ORIGIN_META, String((lift.get_meta(&"bend_info", {}) as Dictionary).get("tag", "stone_form/spike")))
		if r2 and kind == "catch" and not s.has_meta(&"bend_stone_d"):
			var hd := lift._hurl_d()
			s.set_meta(&"bend_stone_d", {"mps": v.length(), "damage": lift.damage_now(), "kind": lift.kind,
					"knock_mps": float(hd.get("knock_mps", GustLift.KNOCK_MPS)), "gravity": float(hd.get("gravity", 6.0)),
					"pierce": bool(hd.get("pierce", false))})
		var thrower2 := _body_of(lift.caster)
		lift.drop(false)
		_take_stone(s, v, perfect, thrower2)
		if r2 and kind == "catch":
			_result("perfect" if perfect else "late", "stone", thrower2)
	for f in get_tree().get_nodes_in_group(NpcBending.FLIGHT_GROUP):
		var fl := f as NpcBending.Flight
		if fl == null or fl.stone == null or not is_instance_valid(fl.stone) or fl.shooter == owner_node:
			continue
		if r2 and kind != "catch":
			continue
		if fl.stone.global_position.distance_to(me) <= radius:
			var s := fl.stone as Node3D
			var v := fl.velocity
			var shooter := fl.shooter as Node
			fl.queue_free()
			_take_stone(s, v, perfect)
			if r2:
				_result("perfect" if perfect else "late", "stone", shooter)


## Earth's Kiln Stone (data/sway/skill_tree.json earth.stone.kiln_stone; the owner, 2026-10-11: "make sure all the talents work"):
## a stone of its wearer's (a bolt: Pebbles, the Fissure's crack; a hurled Spike, Boulder or caught stone: GustLift) that passes
## through fire (KILN_FIRES: any Fire Wall, burning ground or magma seam, whoever's) comes out heated until it lands: a fire
## trail, its launch base x KILN_MULT for him (BendLoadout.hit_class, info.heated). A heated stone counts as fire for the guards:
## a Parry on the beat sends it back, a Turn douses it to a plain stone. A magma seam is the fire lane's Magma set's zone kind
## "seam" (FireTalents, another branch: wired here by its kind alone; a seam is low on the deck, so a stone rolling or skimming
## over it is heated, one flying at chest height is not). The same fires light Sulphur's gas (BendGas.every).
const KILN_STONE := "earth.stone.kiln_stone"
const KILN_MULT := 1.15
const KILN_FIRES := ["fire_wall", "burn", "seam"]


## A flying stone met late by a guard that halves (the Wind Guard): late_mult of its damage and its knock go on (its hurl's
## numbers, this lift's own copy); this guard is done with it.
func _late_lift(lift: GustLift) -> void:
	lift.set_meta("bend_guarded_%d" % get_instance_id(), true)
	var li: Dictionary = (lift.get_meta(&"bend_info", {}) as Dictionary).duplicate()
	li["slide_only"] = true                      # (round 3: a late guard's half is a slide on the feet)
	lift.set_meta(&"bend_info", li)
	var d := lift.d.duplicate(true)
	var hurl: Dictionary = d.get("hurl", {})
	var hd: Dictionary = (hurl.get(lift.kind, hurl.get("stone", {})) as Dictionary).duplicate()
	var dm: Array = hd.get("damage", [20.0, 60.0])
	hd["damage"] = [float(dm[0]) * late_mult, float(dm[dm.size() - 1]) * late_mult]
	hd["knock_mps"] = float(hd.get("knock_mps", GustLift.KNOCK_MPS)) * late_mult
	hurl[lift.kind] = hd
	d["hurl"] = hurl
	lift.d = d


func _take_stone(s: Node3D, v: Vector3, perfect := false, thrower: Node = null) -> void:
	took += 1
	var rb := s as RigidBody3D
	match kind:
		"catch":
			# held before its owner: E again (or Earth Shove) sends it back (round 2: return_stone); always a full catch
			var out := Vector3(-v.x, 0.0, -v.z)
			out = out.normalized() if out.length_squared() > 1e-6 else -owner_node.global_basis.z
			var front := owner_node.global_position + out * 1.3 + Vector3.UP * 1.1
			if r2 and BendLoadout.wears(owner_node, JUGGLE):
				# (Juggle: two held side by side; one more is stopped and dropped at his feet, its thrower's loose stone)
				var have := held_stones(owner_node)
				have.erase(s)
				if have.size() >= JUGGLE_MAX:
					_juggle_drop(s, v, thrower)
					return
				if have.size() == 1:
					front = have[0].global_position + Vector3.UP.cross(out).normalized() * JUGGLE_SIDE_M
			if rb != null:
				rb.freeze = true
			if s is FormStone and (s as FormStone).kind == "spike":
				# (a spike held point out, its foot at the front: its length never through its catcher, who is not moved an
				# inch by a catch; round 2)
				var x := Vector3.UP.cross(out).normalized()
				s.global_transform = Transform3D(Basis(x, out, x.cross(out)), front)
			else:
				s.global_position = front
			s.set_meta(&"bend_held_by", owner_node.get_instance_id())
			if s.has_meta(FormStone.LOOSE_META):
				s.remove_meta(FormStone.LOOSE_META)
			if r2:
				s.set_meta(&"bend_clean", perfect)
				s.set_meta(&"bend_caught_at", BendStatus.now())
			if s is FormStone:
				(s as FormStone).rest_again()
			if not SbFx.start(s, "held", owner_node, SbFx.key_of(info, "stone_catch", "catch"), "held", {"node": s, "dir": out}):
				BendLooks.burst(front, "stone", 14)
			if not r2:
				BendLooks.sound("stone", "hit", front, -2.0)
		"deflect":
			if rb != null:
				rb.freeze = false
				rb.linear_velocity = v.cross(Vector3.UP).normalized() * v.length() * 0.5 + Vector3.UP * 2.0
			if s is FormStone:
				(s as FormStone).rest_again()
			BendLooks.burst(s.global_position, "stone", 10)
		"cushion":
			if rb != null:
				rb.freeze = false
				rb.linear_velocity = v * 0.05
			if s is FormStone:
				(s as FormStone).rest_again()
			BendLooks.burst(s.global_position, "air", 18)


## Juggle's wearer holding two already (see JUGGLE): stone `s` stopped and dropped at his feet, lying loose (whoever's it was).
func _juggle_drop(s: Node3D, v: Vector3, by: Node = null) -> void:
	var flat := Vector3(v.x, 0.0, v.z)
	flat = flat.normalized() if flat.length_squared() > 1e-6 else -owner_node.global_basis.z
	s.global_position = FormEffects.ground_at(owner_node, owner_node.global_position - flat * 0.8) + Vector3.UP * 0.25
	var rb := s as RigidBody3D
	if rb != null:
		rb.freeze = false
		rb.linear_velocity = Vector3.DOWN * 0.5
	if s is FormStone:
		(s as FormStone).rest_again()
	FormStone.make_loose(s, by)
	BendLooks.burst(s.global_position, "stone", 10)


func end(why := "ended") -> void:
	if is_queued_for_deletion():
		return
	if not why in NetSpells.OWN_ENDS and not NetSpells.decide(self, "end", [why, global_position]):
		return                                   # (a ghost's: the host's word ends it)
	if r2 and took == 0 and owner_node != null and is_instance_valid(owner_node) and NetSpells.decides():
		# (a guard that took nothing: the owner's next guard locks slower for a while; spec §2.5)
		whiffed(owner_node)
		_result("whiff", "")
	remove_from_group(GROUP)
	if r2 and owner_node != null and is_instance_valid(owner_node):
		BendCombo.guard_fell(owner_node)         # (the gauge's refill waits from now)
	if kind == "gas":
		BendGas.ended(self)
	if kind == "wind_wall":
		AirTalents.on_wall_end(self, why)          # (Rime Wall: a crust where it stood; Classic none)
	for e in _fx:
		if e is GPUParticles3D and is_instance_valid(e):
			BendLooks.stop_trail(e as GPUParticles3D)
	SbFx.stop(self, "zone")
	if is_inside_tree():
		SbFx.fire(owner_node, SbFx.key_of(info), "zone_end", {"node": self, "dir": way, "size": size, "radius": radius})
	queue_free()


## A guard of `owner`'s took nothing (end): his next guard locks slower for a while (guard_lock_s). Online his own machine's.
static func whiffed(owner: Node) -> void:
	if owner != null and is_instance_valid(owner) and NetSpells.here(owner, "whiff", []):
		owner.set_meta(&"bend_whiff_until", BendStatus.now() + Bending.rule("whiff_s", 1.5))


# ---------------------------------------------------------------- round 3: every guard a shield (the % ring; AIR)
## What a round-2 guard of `body`'s does to a hit of kind `what` that is not a bolt or a flying stone (a cone, a Column or a
## Geyser, the Slam, the air hit, lightning: BendEffects) in the % ring (spec §2.5): {result ("perfect", "late", "" none),
## mult (0 perfect, late_mult late, 1 none), info (`info`, a copy with slide_only when late), zone}. Every guard stops it:
## on the beat nothing through (the reward only in its own cell: a Wind Guard on air charges Carried wind), late half as a
## slide; lightning only a Parry on the beat stops (lightning_guard). Told as every guard's result is; a jab it took ends
## its sender's string. Read only with BendR3.stock() (the callers ask).
static func guard_take(body: Node, what: String, by: Node, info: Dictionary) -> Dictionary:
	var out := {"result": "", "mult": 1.0, "info": info, "zone": null}
	if body == null or not is_instance_valid(body) or not body.is_inside_tree() or not NetSpells.decides():
		return out                               # (online a ghost judges no guard: the host's words)
	for z in body.get_tree().get_nodes_in_group(GROUP):
		var bz := z as BendZone
		if bz == null or not bz.r2 or bz.owner_node != body or bz.is_queued_for_deletion():
			continue
		var perfect := bz.t <= bz.perfect_s and (what != "lightning" or bz.kind == "parry")
		bz.took += 1
		bz._result("perfect" if perfect else "late", what, by)
		if bool(info.get("jab", false)):
			BendR3.jab_guarded(by)
		if perfect:
			if what == "air" and bz.kind in ["air_shield", "wind_guard"]:
				carry_wind(body, AirTalents.guard_carry_s(body))
			return {"result": "perfect", "mult": 0.0, "info": info, "zone": bz}
		var inf := info.duplicate()
		inf["slide_only"] = true
		return {"result": "late", "mult": bz.late_mult, "info": inf, "zone": bz}
	return out


## Lightning striking `body` in the % ring (spec §2.5: "the only answer to lightning" stays fire's): {result "back" (his
## Parry within its perfect_s: sent back), "late" (any other guard of his, or a Parry past the beat: half through as a
## slide), "" (no guard: it hits), mult, info, zone}.
static func lightning_guard(body: Node, by: Node, info: Dictionary) -> Dictionary:
	var g := guard_take(body, "lightning", by, info)
	if String(g.result) == "perfect":
		g["result"] = "back"
	return g


## The hit info of something sent back by `by` (a Parry's, a Wind Guard's bounce, a Turn's swing, lightning's): its own
## class, owned by the returner (spec §2.5): tag "<origin>.return", returned, ret_mult `mult`, origin_tag, from `at`, air
## (`by` airborne); a volley's id, a jab's mark and a set stun dropped.
static func return_info(info: Dictionary, by: Node, at: Vector3, mult: float) -> Dictionary:
	var origin := String(info.get("origin_tag", info.get("tag", "")))
	var out := info.duplicate()
	for k: String in ["volley_id", "volley_n", "jab", "pop", "set_stun", "slide_only", "hit_id"]:
		out.erase(k)
	out["tag"] = origin + ".return" if origin != "" else ".return"
	out["returned"] = true
	out["ret_mult"] = mult
	out["origin_tag"] = origin
	out["from"] = at
	out["air"] = BendR3.airborne(by)
	return out


## A matter zone's tick on `n` (see MATTER): % only, the hit no_hurt (no lock set-back, no Lightning-charge break, no string).
func _matter_tick(n: Node3D) -> void:
	var by: Node = owner_node
	if not BendStatus.can_take(n, owner_node):
		if not tick_all or n == null or not is_instance_valid(n):
			return                                # (his own and his side's never: matter's rule)
		by = null                                 # (a reaction hurts everyone in it: its owner and his side too, no one's hit)
	if tick_floor and n.global_position.y - global_position.y > MATTER_FEET_M:
		return                                    # (floor fire: jumped, his feet over it)
	var id := n.get_instance_id()
	var k := int(_ticks_to.get(id, 0))
	if tick_cap > 0 and k >= tick_cap:
		return
	var now := BendStatus.now()
	if tick_shared:
		if now - float(n.get_meta(MATTER_META, -INF)) < MATTER_EVERY_S - 1e-3:
			return                                # (one tick each 0.5 s from all the matter he stands in)
		n.set_meta(MATTER_META, now)
	_ticks_to[id] = k + 1
	var inf := {"tag": tick_tag, "no_hurt": true, "matter": kind, "move": String(info.get("move", "")), "from": global_position}
	inf.merge(tick_info, true)
	BendR3.deliver(n, 1.0, n.global_position + Vector3.UP * 0.3, way, by, -1.0, Vector3.ZERO, inf)


## A body inside a fire wall at a tick, in the % ring (spec §2.3): on its entry (not inside at the last tick, and its last
## entry pop fire_wall.entry_every_s ago or more) a set pop of entry_mps at entry_deg out of the wall's face; inside after,
## the burn with no flinch (no knock). The hit info: the wall's, wall_entry or wall_tick.
func _fire_wall_hit(n: Node3D, dt: float) -> void:
	var id := n.get_instance_id()
	var fw := BendR3.block("fire_wall")
	var inf := info.duplicate()
	var entry := not _inside_was.has(id) and BendStatus.now() - float(_popped.get(id, -INF)) >= float(fw.get("entry_every_s", 1.0))
	if entry:
		_popped[id] = BendStatus.now()
		var side := signf((global_transform.affine_inverse() * n.global_position).z)
		var out := global_basis.z.normalized() * (side if absf(side) > 0.0 else 1.0)
		inf["wall_entry"] = true
		BendR3.deliver(n, damage_s * dt, n.global_position + Vector3.UP, out, owner_node, -1.0,
				BendR3.set_v(out, float(fw.get("entry_mps", 5.0)), float(fw.get("entry_deg", 50.0))), inf)
		SbFx.fire(owner_node, SbFx.key_of(info), "entry", {"at": n.global_position + Vector3.UP * 0.9, "dir": out})
	else:
		inf["wall_tick"] = true
		BendR3.deliver(n, damage_s * dt, n.global_position + Vector3.UP, way, owner_node, -1.0, Vector3.ZERO, inf)
