extends SceneTree
## Fire's cel look (2026-10-16, the owner: the elements "as close to anime style Avatar: The Last Airbender as possible"; our own
## shaders, meshes and particles; data/bending/fx_looks.json "flame"), in Tidebreak's ring as a fire player. The looks are built
## headless here (BendLooks.build_headless: what is drawn, counted without drawing):
##   the flame     the shader's cel mode on, outlined, a flat-banded teardrop field (cel_v), no discard; the slash and the flame-bit
##                 materials; the tongue_fire particle (aligned to its flight, shrinking out) on the tongue quad
##   the gather    BendCharge's fire is flame along the limbs, no coils: four sleeves (a limb each) of SLEEVE + 1 tongues, no
##                 ribbon anywhere; both forearms burn while the element is round the body; channelled, the striking limb's
##                 burns and the others go out (a kick: the shin); the cast holds the tongues back, snaps them out and they
##                 are gone; the lock's fill, the limb and the ending are the charge's as ever
##   the casts     a hit's burst throws flame tongues and a few puffs of smoke (the pool's), the High Kick's crescent is an arc of
##                 flame with CRESCENT_TONGUES tongues and its smear, the fireball's tongues are drawn stretched as they leave
##   the guards    the Parry's look is a Shield (an arc and PARRY_TONGUES tongues), the Fire Wall has few embers and a few puffs
##                 of smoke, and puffs out when it ends
##   the Step      a fire dash leaves a trail of flame behind it and burns out where it ends
##   round 2       (2026-10-17) the pale core small (core_at), fire's bolts drawn size_k bigger with the hitbox kept, an Embers pellet a
##                 small teardrop of its own, Breath's smoke flat outlined puffs, the Kick's drawn crest (and the low rows as they
##                 were), no ring on the deck at a fire hit
## Last line "FIRE CEL PASSED" or "FIRE CEL FAILED"; exit 0 only on a pass; a watchdog quits with 2.
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_fire_cel.gd

const NAME := "FIRE CEL"
const WATCHDOG_S := 240.0
const OWN_CFG := "user://fire_cel_test.cfg"

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var p: FrontierPlayer
var rm: RingMode
var foe: NpcFighter


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "strong"
	seed(1750)
	ToonFx.vis_rng.seed = 1750
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = "fire"
	MatchSetup.foes = ["earth"]
	BendLooks.build_headless = true
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _child(n: Node, nm: String) -> Node:
	return n.find_child(nm, true, false) if n != null else null


func _num(g: GeometryInstance3D, nm: StringName, dflt: float) -> float:
	var v: Variant = g.get_instance_shader_parameter(nm)
	return float(v) if v != null else dflt


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	p = lvl.player
	rm = RingMode.find(self)
	await _until(func() -> bool: return rm.phase == "FIGHT" and not LoadingScreen.covering(), 25.0)
	foe = rm.foe
	foe.held = true
	await _ticks(30)
	_flame()
	_round2()
	_gather()
	await _casts()
	await _guards()
	await _step()
	BendLooks.build_headless = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	if fails.is_empty():
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		print("%s FAILED (%d of %d): %s" % [NAME, fails.size(), checks, fails])
		quit(1)


# ---------------------------------------------------------------- the flame
func _flame() -> void:
	var fm := ToonFx.mat("flame")
	_expect(float(fm.get_shader_parameter(&"cel")) > 0.5, "the flame's cel mode is on")
	_expect(float(fm.get_shader_parameter(&"ink")) > 0.5, "the flame is outlined whatever the style")
	var src := (load("res://shaders/bend_fx/toon_flame.gdshader") as Shader).code
	var field := FileAccess.get_file_as_string("res://shaders/bend_fx/flame_field.gdshaderinc")
	_expect(src.contains("cel_v(") and src.contains("cel_slash(") and not src.contains("discard;") and field.contains("float cel_v("),
			"the flame shader's cel field (a teardrop, a slash), no discard")
	_expect(float(ToonFx.mat("flame_slash").get_shader_parameter(&"slash")) > 0.5 and int(ToonFx.mat("flame_slash").get_shader_parameter(&"mode")) == 1,
			"the slash material is a strip with its slash field on")
	var rec := ToonFx.recipe("tongue_fire")
	var pm := rec.proc as ParticleProcessMaterial
	var sc := pm.scale_curve as CurveTexture
	_expect(rec.mat == ToonFx.mat("flame_bit") and rec.mesh == ToonFx.tongue_base() and pm.particle_flag_align_y,
			"tongue_fire is the flame-bit material on the tongue quad, aligned to its flight")
	_expect(sc != null and sc.curve.sample(1.0) < 0.05 and sc.curve.sample(0.18) > 0.9, "a tongue flares then shrinks away")
	_expect(ToonFx.recipe("puff_soot").mat == ToonFx.mat("puff_soot"), "the puff a flame goes out in has its recipe")


# ---------------------------------------------------------------- the gather
func _gather() -> void:
	var c := BendCharge.make(p, "fire")
	_expect(c.element == "fire" and c._sleeves.size() == 4, "fire's charge has a sleeve of flame for each limb (%d)" % c._sleeves.size())
	var counts_ok := true
	for k: String in c._sleeves:
		counts_ok = counts_ok and ((c._sleeves[k] as MultiMeshInstance3D).multimesh.instance_count == BendCharge.SLEEVE + 1)
	_expect(counts_ok, "each is SLEEVE + 1 tongues (the last the fist's or the foot's flame)")
	_expect(c.find_children("*", "ToonRibbon", true, false).is_empty() and c._runs.is_empty(), "no coils, no ribbon: the charge has no wandering strands")
	# the element round the body: both forearms burn, low; the legs not
	c.limb_fn = func() -> String: return "r_palm"
	c.fill = 0.15
	for i in 14:
		c._process(0.05)
	var ms := c._sleeves
	_expect((ms.l_arm as Node3D).visible and (ms.r_arm as Node3D).visible and not (ms.l_leg as Node3D).visible and not (ms.r_leg as Node3D).visible,
			"early in the lock both forearms burn, the legs not")
	# channelled to the right hand: it burns whole, the other goes out
	c.fill = 1.0
	c.full = true
	for i in 30:
		c._process(0.05)
	_expect((ms.r_arm as Node3D).visible and not (ms.l_arm as Node3D).visible, "channelled to the right hand: it burns, the left goes out")
	# a kick: the shin
	c.limb_fn = func() -> String: return "l_foot"
	for i in 30:
		c._process(0.05)
	_expect((ms.l_leg as Node3D).visible and not (ms.l_arm as Node3D).visible and not (ms.r_arm as Node3D).visible and not (ms.r_leg as Node3D).visible,
			"channelled to the left foot: the shin burns, both arms go out")
	# the cast: held back on the limb, then gone
	c.end("cast")
	c._process(0.05)
	_expect(c.ending == "cast" and (ms.l_leg as Node3D).visible, "the cast: the flame stays on the limb for the wind-up")
	for i in 14:
		c._process(0.05)
	var gone := true
	for k: String in ms:
		gone = gone and not (ms[k] as Node3D).visible
	_expect(gone, "then it is thrown out and gone (HOLD_S %.2f + SNAP_S %.2f)" % [BendCharge.HOLD_S, BendCharge.SNAP_S])
	c.queue_free()


# ---------------------------------------------------------------- round 2
func _round2() -> void:
	var fm := ToonFx.mat("flame")
	_expect(float(fm.get_shader_parameter(&"core_at")) >= 1.0 and float(fm.get_shader_parameter(&"orb_core")) >= 0.6,
			"the pale core is a small centre (core_at %.2f, orb_core %.2f)" % [float(fm.get_shader_parameter(&"core_at")), float(fm.get_shader_parameter(&"orb_core"))])
	var k := BendLooks.fire_k()
	_expect(k >= 1.3 and k <= 1.6, "fire's bolts are drawn %.2f times bigger (1.3 to 1.6)" % k)
	var f := Node3D.new()
	current_scene.add_child(f)
	BendLooks.bolt_body(f, "fire", 0.5)
	var orb: MeshInstance3D = null
	for c in f.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override == ToonFx.mat("flame_orb"):
			orb = c
	_expect(orb != null and is_equal_approx(orb.scale.x, 0.5 * 2.5 * k), "the fireball's drawn orb is its radius x2.5 x size_k (%.2f)" % (orb.scale.x if orb else -1.0))
	f.queue_free()
	var e := Node3D.new()
	current_scene.add_child(e)
	BendLooks.bolt_body(e, "fire", 0.08)
	var et := _child(e, "Tongues") as MultiMeshInstance3D
	_expect(et != null and et.multimesh.instance_count <= 4 and _num(et, &"grow", 1.0) < BendLooks.SMEAR_K,
			"an Embers pellet is a small teardrop of its own (%d tongues, a shorter smear)" % (et.multimesh.instance_count if et else -1))
	e.queue_free()
	var sm := ToonFx.mat("puff_smoke")
	_expect(sm.shader == ToonFx.SHADERS.puff and float(sm.get_shader_parameter(&"ink")) > 0.5, "Breath's smoke is flat puffs with a rim (not the lit volume)")
	# the Kick's drawn crest, the low rows as they were
	var h := Node3D.new()
	current_scene.add_child(h)
	var wave := BendLooks.floor_wave_body(h, 1.2, 0.9)
	var crest := _child(wave, "Crest") as Node3D
	var rows := _child(wave, "Tongues") as MultiMeshInstance3D
	_expect(crest != null and crest.find_child("CrestTongues", true, false) != null, "the Kick has its drawn crest of tongues")
	var top := 0.0
	if rows != null:
		for t: Dictionary in (rows.get_meta(&"tongues", []) as Array):
			top = maxf(top, (t.xf as Transform3D).basis.y.length() * float(ToonFx.looks("floor_wave").get("fill", 0.92)))
	_expect(rows != null and absf(top - 0.9) <= 0.1, "its low rows still stand at the height they were given (0.9; %.2f), the crest is drawn over them" % top)
	h.queue_free()
	# no ring on the deck at a fire hit (it read as a target marker)
	var pool := ToonFxPool.of(current_scene)
	pool.set_process(false)
	var at := rm.ring.center() + Vector3.UP * 0.15
	var rings_before := 0
	for pl: Array in pool._playing:
		if (pl[0] as MeshInstance3D).material_override == ToonFx.mat("ring"):
			rings_before += 1
	BendLooks.burst(at, "fire", 16, Vector3.UP, 120.0, 3.5, 0.3, false)
	BendLooks.blast(at, Vector3.FORWARD, 360.0, 3.0, "fire")
	var rings_after := 0
	for pl: Array in pool._playing:
		if (pl[0] as MeshInstance3D).material_override == ToonFx.mat("ring"):
			rings_after += 1
	pool.set_process(true)
	_expect(rings_after == rings_before, "no flat ring on the deck at a fire hit or a fire ring (%d)" % (rings_after - rings_before))


# ---------------------------------------------------------------- the casts
func _pool_has(mat_key: String) -> bool:
	var pool := ToonFxPool.of(current_scene)
	for g in pool.get_children():
		if g is GPUParticles3D and (g as GPUParticles3D).material_override == ToonFx.mat(mat_key) and (g as GPUParticles3D).emitting:
			return true
	return false


func _casts() -> void:
	var at := rm.ring.center() + Vector3.UP * 1.2
	BendLooks.burst(at, "fire", 16, Vector3.UP, 120.0, 3.5, 0.3, false)
	_expect(_pool_has("flame_bit"), "a hit's burst throws flame tongues")
	_expect(_pool_has("puff_soot"), "and leaves a few puffs of smoke")
	# the High Kick's crescent
	var h := Node3D.new()
	current_scene.add_child(h)
	BendLooks.bolt_body(h, "fire", 0.4, false, "crescent")
	var arc: MeshInstance3D = null
	for c in h.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override == ToonFx.mat("flame_slash"):
			arc = c
	var tg := _child(h, "Tongues") as MultiMeshInstance3D
	_expect(arc != null and tg != null and tg.multimesh.instance_count == BendLooks.CRESCENT_TONGUES,
			"the High Kick's crescent: an arc of flame and %d tongues" % BendLooks.CRESCENT_TONGUES)
	_expect(tg != null and _num(tg, &"grow", 1.0) > 1.5, "its tongues are drawn stretched as it leaves (the smear: %.1f)" % (_num(tg, &"grow", 1.0) if tg else -1.0))
	h.queue_free()
	# the fireball's
	var f := Node3D.new()
	current_scene.add_child(f)
	BendLooks.bolt_body(f, "fire", 0.5)
	var ft := _child(f, "Tongues") as MultiMeshInstance3D
	_expect(ft != null and _num(ft, &"grow", 1.0) > 1.5, "the fireball's tongues leave stretched too")
	f.queue_free()
	# nothing to hold the gather's puff: the pool's, no node per call once warm
	var pool := ToonFxPool.of(current_scene)
	for i in 14:                                    # (the pool's emitters, shapes and marks are made up to their caps)
		BendLooks.burst(at, "fire", 16, Vector3.UP, 120.0, 3.5, 0.3, false)
		BendLooks.fire_out(at, 1.0, 2)
	var before := pool.get_child_count()
	for i in 14:
		BendLooks.burst(at, "fire", 16, Vector3.UP, 120.0, 3.5, 0.3, false)
		BendLooks.fire_out(at, 1.0, 2)
	_expect(pool.get_child_count() == before, "no node made per hit once warm (%d -> %d)" % [before, pool.get_child_count()])


# ---------------------------------------------------------------- the guards
func _guards() -> void:
	var parry := BendZone.make(p, "parry", p.global_position, {"radius_m": 2.5, "window_s": 0.8, "perfect_s": 0.3}, rm.ring.axis())
	var look := _child(parry, "Look")
	var sh := _child(look, "Shield")
	var tg := _child(sh, "Tongues") as MultiMeshInstance3D
	_expect(sh != null and tg != null and tg.multimesh.instance_count == BendZone.PARRY_TONGUES,
			"the Parry's look is a shield of flame: an arc and %d tongues" % BendZone.PARRY_TONGUES)
	parry.end()
	var fw := BendZone.make(p, "fire_wall", rm.ring.center() + rm.ring.global_basis.z * 8.0, {"width_m": 4.0, "height_m": 2.0,
			"thick_m": 0.6, "life_s": 0.4}, rm.ring.axis())
	var embers := 0
	var soot := 0
	for c in fw.get_children():
		if c is GPUParticles3D:
			if (c as GPUParticles3D).material_override == ToonFx.mat("spark_fire"):
				embers = (c as GPUParticles3D).amount
			elif (c as GPUParticles3D).material_override == ToonFx.mat("puff_soot"):
				soot = (c as GPUParticles3D).amount
	_expect(embers > 0 and embers <= 20 and soot > 0 and soot <= 8, "the Fire Wall: few embers (%d) and a few puffs of smoke (%d)" % [embers, soot])
	fw.end()
	await _ticks(2)


# ---------------------------------------------------------------- the Step
func _step() -> void:
	var bm := BendMotion.of(p)
	var bc := BendCaster.of(p)
	BendCast.cast(bc, "footwork", "step")
	await _ticks(3)
	_expect(bm._dash_fire and bm._fx != null and is_instance_valid(bm._fx), "a Step leaves a trail of flame behind it")
	var ended := await _until(func() -> bool: return not bm._dash_fire, 4.0)
	_expect(ended != INF, "and burns out where it ends")
	await _until(func() -> bool: return bm._fx == null, 4.0)
	_expect(bm._fx == null, "its trail let go when the dash is over")
