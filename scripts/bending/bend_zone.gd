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
##               Fire, water and air pass
##   Turn        water or ice: perfect, it swings once round the guard's waist (SWING_S) and leaves along his aim x
##               perfect_mult (steered by Flowing); the Air Lance (an air bolt of shape spear, the Gust held long; the
##               owner, 2026-10-11): the same, and it turns to ice as it is caught (BendBolt.become), wraps round him and
##               leaves an ice lance along his aim; late, half gets through as every late Turn; fire: perfect, doused to
##               steam; a Wave on the beat parts round him (cone_mult). Stone and other air pass
##   parry       fire of any shape (a bolt, the Kick's floor wave, the High Kick's crescent): perfect, straight back along
##               his aim at once x perfect_mult (no dice: never a random side); ice: perfect, melted to a puddle; lightning:
##               back along his aim only on a parry in its first perfect_s when it strikes (lightning_back), else it hits.
##               Water, stone and air pass
##   Wind Guard  air: perfect, bounced straight back along his aim x perfect_mult, and his Carried wind charged; stone: perfect,
##               cushioned and dropped at his feet, a loose stone. Fire, water, ice and lightning pass. (The 2.5 s return
##               shield is gone.)
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

const GROUP := &"bend_zones"
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
## A body walking into a wind wall is pushed back at this (m/s), once each PUSH_EVERY_S.
const WIND_WALL_KNOCK := 4.0
const PUSH_EVERY_S := 0.5
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


static func make(by: Node3D, p_kind: String, at: Vector3, spec: Dictionary, p_way := Vector3.FORWARD) -> BendZone:
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
	if p_kind == "puddle":
		z.add_to_group(Bending.POOLS)
		z.set_meta(&"reach_m", z.radius + 1.0)
	NetSpells.tag(z)                             # (online: its name in its cast's run)
	by.get_tree().current_scene.add_child(z)
	var x := Vector3.UP.cross(z.way).normalized()
	z.global_transform = Transform3D(Basis(x, Vector3.UP, z.way), at)
	z._look()
	NetSpells.spawned(z, "zone", [by, p_kind, at, spec, p_way])     # (the host's own decision: made on the others too)
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
			mi.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 5.0)
			_fx.append(BendLooks.emitter(self, "water", Vector3(radius * 0.7, 0.05, radius * 0.7), 14, 0.6, 1.6, 0.12))
			_grow(look, Vector3.ONE * 0.05)
		"air_shield":
			for i in 3:
				var b := _part(look, ToonFx.band_mesh(1.0, 0.9, 0.45), ToonFx.mat(["wind_band", "wind_band_slow", "wind_band_fast"][i]))
				b.scale = Vector3.ONE * radius * (1.0 - i * 0.07)
				b.position = Vector3.UP * (0.3 + i * 0.62)
				b.rotation = Vector3(0.24 * (1.0 if i % 2 == 0 else -1.0), i * 1.1, 0.12 * i)
				b.set_instance_shader_parameter(&"seed", i * 0.37)
				b.set_instance_shader_parameter(&"band_w", own_band_w())
			_fx.append(BendLooks.emitter(self, "dust", Vector3(radius * 0.9, 0.05, radius * 0.9), 14, 0.7, 0.6, 0.35))
			_grow(look, Vector3.ONE * 0.2)
		"water_wall":
			var bm := BoxMesh.new()
			bm.size = Vector3(size.x, size.y, size.z * 0.7)
			bm.subdivide_width = 16
			bm.subdivide_height = 10
			var mi := _part(look, bm, ToonFx.mat("water_wall"))
			mi.position = Vector3.UP * size.y * 0.5
			mi.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 5.0)
			var crest := BendLooks.emitter(self, "water", Vector3(size.x * 0.48, 0.05, size.z * 0.3), 40, 0.6, 2.4, 0.12)
			var foam := BendLooks.emitter(self, "foam", Vector3(size.x * 0.48, 0.05, size.z * 0.35), 22, 0.45, 0.8, 0.32)
			var foot := BendLooks.emitter(self, "foam", Vector3(size.x * 0.5, 0.05, size.z * 0.5), 18, 0.6, 0.4, 0.4)
			for e: GPUParticles3D in [crest, foam]:
				e.position = Vector3.UP * size.y
			_fx.append_array([crest, foam, foot])
			_grow(look, Vector3(1.0, 0.02, 1.0))
			_own_fade(look)
		"fire_wall", "burn":
			_flames(look)
			var h := size.y if kind == "fire_wall" else 0.5
			var em := BendLooks.emitter(self, "embers", Vector3(size.x * 0.5, 0.1, size.z * 0.5), int(10 * maxf(size.x, size.z)),
					1.0, h * 1.6, 0.05)
			em.position = Vector3.UP * h * 0.4
			_fx.append(em)
			var sc := _part(look, ToonFx.plane(), ToonFx.mat("mark_scorch"))
			sc.scale = Vector3(size.x * 0.62, 1.0, size.z * 0.5 + 0.5)
			sc.position = Vector3.UP * 0.02
			sc.set_instance_shader_parameter(&"t", 0.25)
			sc.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 5.0)
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
			fr.set_instance_shader_parameter(&"t", 0.2)
			fr.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 5.0)
			_fx.append(BendLooks.emitter(self, "sparkle", Vector3(radius * 0.7, 0.05, radius * 0.7), 10, 0.8, 0.3, 0.12))
			_grow(look, Vector3(0.1, 1.0, 0.1))
		"smoke", "dust", "spray", "snow":
			var cl := BendLooks.emitter(self, "smoke" if kind == "smoke" else ("dust" if kind == "dust" else "foam"),
					Vector3(radius, 0.8, radius), 40, 2.2, 0.6, 1.6)
			_fx.append(cl)
			if kind == "smoke" and cl != null:
				# (round 4: lit warm from under by the flame that made it, for its first warm_s)
				cl.set_instance_shader_parameter(&"warm", 1.0)
				var tw := cl.create_tween()
				tw.tween_method(func(v: float) -> void: cl.set_instance_shader_parameter(&"warm", v), 1.0, 0.0,
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
				b.set_instance_shader_parameter(&"seed", i * 0.29)
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
				b.set_instance_shader_parameter(&"seed", i * 0.5)
			_fx.append(BendLooks.emitter(self, "air", Vector3(radius, 0.6, radius), 24, 0.6, -1.0, 0.35))
		"redirect":
			# (the Turn: a ring of water spinning up round the guard's waist, drops flung off it; on the guarder only)
			if r2:
				var ring := _part(look, ToonFx.band_mesh(1.0, 0.86, 0.22), ToonFx.mat("water_strip"))
				ring.scale = Vector3(SWING_R, 1.0, SWING_R)
				ring.position = Vector3.UP * 1.0
				ring.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 5.0)
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
			# (a standing wall of moving wind: bands streaming across its face, dust whipped up along its foot)
			for i in 4:
				var b := _part(look, ToonFx.band_mesh(1.0, 0.9, 0.5), ToonFx.mat(["wind_band", "wind_band_fast", "wind_band_slow", "wind_band"][i]))
				b.scale = Vector3(size.x * 0.5, size.y * 0.24, maxf(size.z, 0.3))
				b.position = Vector3(0.0, size.y * (0.14 + 0.24 * i), 0.0)
				b.rotation = Vector3(0.0, 0.0, 0.08 * (1.0 if i % 2 == 0 else -1.0))
				b.set_instance_shader_parameter(&"seed", i * 0.41)
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
			wet.set_instance_shader_parameter(&"t", 0.15)
			wet.set_instance_shader_parameter(&"seed", ToonFx.vis_rng.randf() * 5.0)
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
	mmi.set_instance_shader_parameter(&"seed", rng.randf() * 10.0)
	mmi.set_instance_shader_parameter(&"grow", 0.0)
	look.add_child(mmi)
	var gl := MeshInstance3D.new()
	gl.name = "Glow"
	gl.mesh = ToonFx.quad()
	gl.material_override = ToonFx.mat("flame_glow")
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gh := size.y if kind == "fire_wall" else 0.6
	gl.scale = Vector3(size.x * 1.25, gh * 1.5, 1.0)
	gl.position = Vector3.UP * gh * 0.45
	gl.set_instance_shader_parameter(&"seed", rng.randf() * 10.0)
	look.add_child(gl)
	var tw := mmi.create_tween()
	tw.tween_method(func(v: float) -> void: mmi.set_instance_shader_parameter(&"grow", v), 0.0, 1.0, 0.3) \
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
	var decides := NetSpells.decides()           # (online a ghost's zone decides nothing: the host's words)
	_tick -= dt
	if _tick <= 0.0:
		_tick = 0.25
		if decides:
			_every(0.25)
	if decides and (kind in ["catch", "deflect", "cushion"] or (r2 and kind in ["air_shield", "wind_guard"]) \
			or (r2 and BendR3.stock() and kind in ["redirect", "parry"])):
		_stones()
	if kind == "wind_wall" and decides:
		_wind_push()
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
	if kind in ["bubble", "air_shield", "ice_patch", "smoke", "dust", "spray", "steam", "tornado", "vacuum", "puddle", "snow"] \
			or kind in GUARDS:
		return Vector2(l.x, l.z).length() <= radius and l.y > -1.0 and l.y < 3.5
	return absf(l.x) <= size.x * 0.5 and absf(l.z) <= size.z * 0.5 + 0.3 and l.y > -0.5 and l.y < size.y + 0.3


## Its lasting effects on whom it holds, each `dt` s.
func _every(dt: float) -> void:
	if kind == "snow":
		AirTalents.snow_every(self)              # (Blizzard: its cold, the water it freezes, fire melting it)
	var r := maxf(radius, size.x * 0.6)
	if put_out:
		put_out_fires()
	var now_in := {}
	for e in BendCaster.near(owner_node, global_position, r + 1.0):
		var n: Node3D = e[0]
		if not inside(n.global_position):
			continue
		now_in[n.get_instance_id()] = true
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
	_inside_was = now_in
	if kind == "water_wall":
		# (a fire wall it stands in goes out)
		for z in get_tree().get_nodes_in_group(GROUP):
			var o := z as BendZone
			if o != self and o.kind in ["fire_wall", "burn"] and inside(o.global_position):
				if not SbFx.fire(o.owner_node, SbFx.key_of(o.info), "put_out", {"at": o.global_position, "dir": o.way}):
					BendLooks.burst(o.global_position + Vector3.UP, "steam", 30, Vector3.UP, 90.0, 2.5, 1.0)
				o.end()


## Bolt `b` passing it (see the header); true when it acted on it. An ally's bolt (BendCaster.same_team: the ring's sides)
## passes as its owner's own does: a guard never sends a teammate's bolt back or eats it.
func on_bolt(b: BendBolt) -> bool:
	if not b.spent and kind in ["fire_wall", "smoke"] and AirTalents.through_ally_fire(self, b):
		return false                                 # (Dragon Fire: his Gust through an ally's fire carries a front on; it flies on)
	if kind in ["fire_wall", "burn"] and AirTalents.snuffs(self, b):
		return true                                  # (Frost Gust: his Gust puts a foe's fire out)
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
	return false


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
				return _shield_bolt(b, perfect, what)
			if stock and t > window_s:
				_late_drop(b.damage, b.knock_mps, b.up_mps, b.velocity, b.global_position, b._by(), b.lock_s, b.info, b.weight)
				b.end("dropped")
				took += 1
				_result("late", what)
				return true
			_take_bolt(b, perfect)
			_result("perfect" if perfect else "late", what, shooter)
			return true
		"redirect":
			# (the Air Lance, the only air spear: the Turn takes it as water and ice, and it leaves as ice)
			var lance := what == "air" and b.shape == "spear"
			if what in ["water", "ice"] or lance:
				if perfect:
					b.begin_swing(owner_node, SWING_S, SWING_R, BendLoadout.tune_f(owner_node, "rules:guard_rules.perfect_mult",
							Bending.rule("perfect_mult", 1.2)), "ice" if lance else "")
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
					_straight_back(b)
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
						_straight_back(b)                 # (Eye of the Gale's wearer, E held: it circles him first)
					carry_wind(owner_node, AirTalents.guard_carry_s(owner_node))
				else:
					_late(b)
			elif what == "stone":
				if perfect:
					_cushion(b)
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


## Sent straight back along the guard's aim at once (the Parry's, the Wind Guard's bounce): his now, perfect_mult of its
## speed, damage and knock. A floor wave stays on the floor (its line the aim's yaw).
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


## A stone bolt cushioned on the beat (the Wind Guard): it stops and drops at the guard's feet, a loose stone of whoever
## threw it (FormStone.make_loose).
func _cushion(b: BendBolt) -> void:
	var at := b.global_position
	var rad := clampf(b.radius, 0.12, 0.45)
	var by: Node = b.caster if b.caster != null and is_instance_valid(b.caster) else null
	b.end("cushioned")
	var foot := FormEffects.ground_at(owner_node, owner_node.global_position + way * 0.9)
	var s := FormStone.ball(get_tree().current_scene, foot, {"radius_m": rad, "mass_kg": 20.0, "rise_s": 0.01, "life_s": 30.0,
			"sink_s": 1.0}, absi(hash(Vector3i(at * 10.0))) % 97, "stone")
	s.state = FormStone.State.RESTING
	s.freeze = false
	s.set_meta(&"bend_weight", b.weight)
	stones.append(s)
	FormStone.make_loose(s, by)
	if not SbFx.fire(owner_node, SbFx.key_of(info), "cushion", {"at": foot, "dir": way}):
		BendLooks.burst(at, "air", 18)


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
	var bc := BendCaster.of(owner)
	if bc != null:
		bc.guarded.emit(result, what)


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


## The stone `body` caught and holds (a catch's: meta bend_held_by; not one flying or lifted), null none.
static func held_stone(body: Node) -> Node3D:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return null
	var id := body.get_instance_id()
	for s in body.get_tree().get_nodes_in_group(FormStone.GROUP):
		if int((s as Node).get_meta(&"bend_held_by", -1)) == id and not GustLift.busy(s) and not (s as Node).is_queued_for_deletion():
			return s as Node3D
	return null


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
	var kind := GustLift.kind_of(fs)
	var floor_d: Dictionary = ((SwayMoves.move("gust").get("stone", {}) as Dictionary).get("hurl", {}) as Dictionary).get(kind,
			((SwayMoves.move("gust").get("stone", {}) as Dictionary).get("hurl", {}) as Dictionary).get("stone", {}))
	var mult := return_mult(fs, bc.body)
	var own: Dictionary = fs.get_meta(&"bend_stone_d", {})
	var fm: Array = floor_d.get("mps", [24.0, 24.0])
	var fd: Array = floor_d.get("damage", [60.0, 60.0])
	var mps := maxf(float(own.get("mps", 0.0)) * mult, float(fm[fm.size() - 1]))
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
	fs.set_meta(&"bend_return", {"mps": mps, "damage": dmg, "knock_mps": knock, "mult": mult, "clean": clean})
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
	BendLooks.burst(fs.global_position, "stone", 12)
	BendSounds.play(&"earth_cast_crack", fs.global_position, 1.0 if clean else -1.0)
	return th


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
	_take_stone(s, v, perfect)


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
		if r2 and BendR3.stock() and kind in ["redirect", "parry"]:
			# (round 3, every guard a shield: a stone met on the beat drops where it is, nothing through, no reward; late,
			# half as a slide)
			var thrower0 := _body_of(lift.caster)
			if perfect:
				var st0 := lift.stone as Node3D
				var by0 := _body_of(lift.caster)
				lift.drop(false)
				FormStone.make_loose(st0, by0)
			else:
				_late_lift(lift)
			took += 1
			_result("perfect" if perfect else "late", "stone", thrower0)
			continue
		if r2 and kind in ["air_shield", "wind_guard"]:
			# (the Wind Guard on a flying stone: on the beat cushioned and dropped at his feet, a loose stone; late, half)
			var thrower1 := _body_of(lift.caster)
			if perfect:
				var st := lift.stone as Node3D
				var by := _body_of(lift.caster)
				lift.drop(false)
				var rb0 := st as RigidBody3D
				if rb0 != null:
					rb0.freeze = false
					rb0.linear_velocity = lift.velocity * 0.05
				FormStone.make_loose(st, by)
				if not SbFx.fire(owner_node, SbFx.key_of(info), "cushion", {"at": st.global_position, "dir": way}):
					BendLooks.burst(st.global_position, "air", 18)
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
		_take_stone(s, v, perfect)
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


func _take_stone(s: Node3D, v: Vector3, perfect := false) -> void:
	took += 1
	var rb := s as RigidBody3D
	match kind:
		"catch":
			# held before its owner: E again (or Earth Shove) sends it back (round 2: return_stone); always a full catch
			var out := Vector3(-v.x, 0.0, -v.z)
			out = out.normalized() if out.length_squared() > 1e-6 else -owner_node.global_basis.z
			var front := owner_node.global_position + out * 1.3 + Vector3.UP * 1.1
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
