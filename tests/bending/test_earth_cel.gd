extends SceneTree
## Earth in the show's cel style (the owner, 2026-10-16: "as close to Anime Style Avatar: The Last Airbender as possible"; the
## gather BendCharge, the casts BendLooks, FissureFx, FormStone, FormRaised): our own rock meshes, shaders and pooled crack strips.
## Looks only, so what this pins is that they are built and bounded and leave every number as it was, in Tidebreak's ring
## (scenes/ring.tscn, earth against fire, the foe held), with the looks built headless (BendLooks.build_headless):
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_earth_cel.gd
##   shaders, meshes   the crack and outline shaders load; the cel slab, boulder, spike, wall and pillar meshes have the sizes
##                     they were asked for
##   the rock          a stone bolt's body is the cel rock with its outline, both grown at range; the shadow core as ever
##   the gather        slabs are torn from the deck one by one (waiting, cracking, snapping, hanging), each with its outline, a
##                     crack made for each; a second gather makes no more nodes than the first (pooled)
##   the stones        the ring's raised Spike and Boulder wear the cel dress, their bodies and collisions as they were
##   the Fissure       its crack trail and slabs are made while it runs, bounded, and the trail is gone after it
##   the wall          the ring's Earth Wall is the cel mesh with its outline, its box and its fade as ever
##   the cracks        however many are asked, the pool holds ToonFxPool.CRACKS at most
##   round 2           the Fissure is ours (config moves_on empty, the line to restore noted), a thrown stone and a stone bolt are
##                     smeared along their way for a moment and whole again, the rocks round the hand lag it and overshoot, the
##                     outline never thinner than a few pixels, shape changes step at 12 a second
## The last line "EARTH CEL PASSED (<n> checks)" or "EARTH CEL FAILED (<f> of <n>)"; exit 0 only on a pass.

const NAME := "EARTH CEL"
const WATCHDOG_S := 240.0
const OWN_CFG := "user://earth_cel_test.cfg"

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var p: FrontierPlayer
var rm: RingMode
var foe: NpcFighter
var _foe_at := Vector3.INF


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
	MatchSetup.element = "earth"
	MatchSetup.foes = ["fire"]
	BendLooks.build_headless = true
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(round(s * Engine.physics_ticks_per_second)))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _hold() -> void:
	if foe == null or not is_instance_valid(foe) or _foe_at == Vector3.INF:
		return
	foe.held = true
	foe.global_position = _foe_at
	foe.velocity = Vector3.ZERO
	foe.health = foe.health_max
	p.health = p.max_health


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	p = lvl.player
	rm = RingMode.find(self)
	await _until(func() -> bool: return rm.phase == "FIGHT" and not LoadingScreen.covering(), 25.0)
	foe = rm.foe
	rm.rules.soft_walls = false
	var ax := rm.ring.axis()
	_foe_at = rm.ring.center() + ax * 4.5
	RingLevel.place(p, Transform3D(Basis.looking_at(ax, Vector3.UP), rm.ring.center() - ax * 4.5))
	physics_frame.connect(_hold)
	await _secs(0.5)
	_meshes()
	await _rock()
	await _gather()
	await _stones()
	await _fissure()
	await _wall()
	_cracks()
	await _round2()
	BendLooks.build_headless = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	_end()


func _end() -> void:
	if fails.is_empty():
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		print("%s FAILED (%d of %d): %s" % [NAME, fails.size(), checks, str(fails)])
		quit(1)


## ---------------------------------------------------------------- shaders, meshes
func _meshes() -> void:
	for sh in ["toon_crack", "toon_outline", "toon_facet"]:
		_expect(ResourceLoader.load("res://shaders/bend_fx/%s.gdshader" % sh) is Shader, "the %s shader loads" % sh)
	var slab := ToonFx.slab_mesh(0).get_aabb()
	_expect(slab.size.x > 0.5 and slab.size.x < 1.4 and slab.size.y < 0.6 and slab.size.z > 0.4, "a slab is a plate about a metre across (%s)" % [slab.size])
	var boulder := ToonFx.boulder_mesh(0.3, 0).get_aabb()
	_expect(absf(boulder.size.x - 0.6) < 0.2 and absf(boulder.size.y - 0.6) < 0.2, "a boulder of 0.3 is about 0.6 m across (%s)" % [boulder.size])
	var spike := ToonFx.spike_cel_mesh(0.26, 1.75, 1, 0.45).get_aabb()
	_expect(absf(spike.size.y - (1.75 + 0.45)) < 0.2 and spike.size.x < 1.0, "the cel spike is as tall as the move's (%s)" % [spike.size])
	var wall := ToonFx.wall_cel_mesh(3.0, 2.0, 0.6, 1, 0.45).get_aabb()
	_expect(absf(wall.size.x - 3.0) < 0.3 and wall.size.y > 2.0 and wall.size.y < 2.7 and wall.size.z < 0.9, "the cel wall is as wide as the move's (%s)" % [wall.size])
	var pillar := ToonFx.pillar_cel_mesh(0.55, 3.0, 1, 0.45).get_aabb()
	_expect(absf(pillar.size.y - 3.45) < 0.2 and pillar.size.x < 1.6, "the cel pillar is as tall as the move's (%s)" % [pillar.size])


## ---------------------------------------------------------------- the rock
func _rock() -> void:
	var holder := Node3D.new()
	current_scene.add_child(holder)
	holder.global_position = rm.ring.center() + Vector3.UP * 3.0
	BendLooks.bolt_body(holder, "stone", 0.25)
	var body: MeshInstance3D = null
	for c in holder.get_children():
		if c is MeshInstance3D and String(c.name) == "Body":
			body = c
	var ol: MeshInstance3D = null
	if body != null:
		for c in body.get_children():
			if c is MeshInstance3D and String(c.name) == "Outline":
				ol = c
	_expect(body != null and ol != null, "a stone bolt's body is the cel rock with its outline")
	if body != null and ol != null:
		_expect(body.material_override == ToonFx.mat("rock") and ol.material_override == ToonFx.mat("rock_outline"),
				"in the cel rock and outline materials")
		_expect(float(body.get_instance_shader_parameter(&"range_on")) > 0.5 and float(ol.get_instance_shader_parameter(&"range_on")) > 0.5,
				"both grown at range")
		_expect(ol.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the outline casts no shadow")
	holder.queue_free()
	await _ticks(2)


## ---------------------------------------------------------------- the gather
func _nodes(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += _nodes(k)
	return c


func _gather() -> void:
	var pool := ToonFxPool.of(current_scene)
	var counts: Array[int] = []
	for round in 2:
		var ch := BendCharge.make(p, "earth")
		ch.limb_fn = func() -> String: return "r_palm"
		await _ticks(2)
		var slabs := ch._rocks.filter(func(r: Dictionary) -> bool: return bool(r.slab))
		_expect(slabs.size() == BendCharge.SLAB_AT.size() and ch._rocks.size() == BendCharge.ROCKS,
				"%d slabs among %d rocks are made (%d, %d)" % [BendCharge.SLAB_AT.size(), BendCharge.ROCKS, slabs.size(), ch._rocks.size()])
		var outlined := true
		for rk: Dictionary in ch._rocks:
			var m := rk.mesh as Node3D
			if m.get_node_or_null(^"Outline") == null:
				outlined = false
		_expect(outlined, "every rock has its outline")
		var t := 0.0
		while t < 1.4:
			ch.fill = clampf(t / 1.2, 0.0, 1.0)
			ch.full = ch.fill >= 1.0
			await physics_frame
			t += 1.0 / 60.0
		var hanging := slabs.filter(func(r: Dictionary) -> bool: return int(r.state) == 3).size()
		_expect(hanging == slabs.size(), "by the full lock every slab has been torn out and hangs (%d of %d)" % [hanging, slabs.size()])
		var shown := pool._cracks.filter(func(e: Dictionary) -> bool: return is_instance_valid(e.mi) and (e.mi as MeshInstance3D).visible).size()
		_expect(shown > 0 and pool._cracks.size() <= ToonFxPool.CRACKS,
				"cracks are showing for the slabs, within the pool's cap (%d showing, %d held)" % [shown, pool._cracks.size()])
		ch.end("cast")
		await _secs(1.4)
		counts.append(_nodes(pool))
	_expect(counts.size() == 2 and counts[1] <= counts[0] + 4, "the second gather makes no more nodes in the pool than the first (%s)" % [counts])


## ---------------------------------------------------------------- the stones
func _stones() -> void:
	var s := FormStone.spike(current_scene, rm.ring.center() + Vector3(0, 0, 3.0), Vector3.FORWARD, {"height_m": 1.75, "radius_m": 0.26}, 3, "stone")
	var b := FormStone.ball(current_scene, rm.ring.center() + Vector3(2.0, 0, 3.0), {"radius_m": 0.26, "mass_kg": 45.0}, 3, "stone")
	await _ticks(2)
	for st: FormStone in [s, b]:
		_expect(st.has_meta(&"cel_rock") and st.mesh_instance.get_node_or_null(^"Outline") != null,
				"the ring's %s wears the cel dress" % st.kind)
	var cs := s.get_node("Shape") as CollisionShape3D
	_expect(absf((cs.shape as CylinderShape3D).radius - 0.26 * 0.6) < 1e-4 and absf((cs.shape as CylinderShape3D).height - (1.75 * 0.85 + FormModels.BURY_M)) < 1e-4,
			"the Spike's collision is as it was")
	_expect(absf(((b.get_node("Shape") as CollisionShape3D).shape as SphereShape3D).radius - 0.26) < 1e-4, "the Boulder's collision is as it was")
	s.queue_free()
	b.queue_free()


## ---------------------------------------------------------------- the Fissure
func _fissure() -> void:
	var spec: Dictionary = ((SwayMoves.move("earth_shove").bend as Dictionary).push as Dictionary).duplicate(true)
	spec["kind"] = "stone"
	var wave := BendEffects.floor_wave(p, {}, spec)
	_expect(wave != null and wave.floor_wave, "the Fissure runs")
	await _secs(0.8)
	var trail := _find(current_scene, "CrackTrail")
	_expect(trail != null, "its crack trail is laid as it runs")
	var slab_nodes := 0
	for n in current_scene.get_children():
		if String(n.name).begins_with("FissureSlab"):
			slab_nodes += 1
	_expect(slab_nodes > 0 and slab_nodes <= FissureFx.SLAB_POOL, "slabs are heaved beside it, within the pool (%d)" % slab_nodes)
	if wave != null and is_instance_valid(wave):
		wave.end("test")
	await _secs(FissureFx.CRACK_LIFE_S + 1.0)
	_expect(_find(current_scene, "CrackTrail") == null, "its crack has faded and is gone after it")
	await _secs(1.0)


## The first crack trail (FissureFx.CrackTrail: a mesh with fork() and release()) under `n`, else null.
func _find(n: Node, _cls: String) -> Node:
	if n is MeshInstance3D and n.has_method(&"fork") and n.has_method(&"release"):
		return n
	for k in n.get_children():
		var f := _find(k, _cls)
		if f != null:
			return f
	return null


## ---------------------------------------------------------------- the wall
func _wall() -> void:
	var spec := SwayMoves.move("earth_wall")
	var fwd := -p.global_basis.z
	var w := FormEffects.earth_wall(p, p.global_position + fwd * 3.0, spec, "earth")
	await _ticks(2)
	_expect(w != null and w.cel and w.mesh_instance.get_node_or_null(^"Outline") != null, "the ring's Earth Wall is the cel rock with its outline")
	if w != null:
		var bx := (w.get_node("Shape") as CollisionShape3D).shape as BoxShape3D
		_expect(absf(bx.size.x - w.size.x) < 1e-4 and absf(bx.size.y - (w.size.y + FormModels.BURY_M)) < 1e-4, "its collision box is as it was")
		w.queue_free()
	await _ticks(2)


## ---------------------------------------------------------------- the cracks
func _cracks() -> void:
	var pool := ToonFxPool.of(current_scene)
	for i in 80:
		BendLooks.crack(rm.ring.center(), rm.ring.center() + Vector3(1.0 + float(i % 5) * 0.2, 0, 1.0), 0.5, 0.1, 5.0)
	_expect(pool._cracks.size() <= ToonFxPool.CRACKS, "80 cracks asked, the pool holds %d (cap %d)" % [pool._cracks.size(), ToonFxPool.CRACKS])


## ---------------------------------------------------------------- round 2
func _round2() -> void:
	# the Fissure is ours: the Spellbreak wave is off, the way back written down
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bending/sb_fx/config.json"))
	_expect((cfg.get("moves_on", {"x": 1}) as Dictionary).is_empty(), "no single move is switched on in the Spellbreak bridge (the Fissure is ours)")
	_expect("earth_shove/push" in String(cfg.get("_round2_earth", "")), "the line to restore is written down beside it")
	# the outline's pixel floor and its colour
	var ol := ToonFx.mat("rock_outline")
	var rx := RegEx.create_from_string("uniform float min_px\\s*=\\s*([0-9.]+)")
	var hit := rx.search(ol.shader.code)
	var min_px := float(hit.get_string(1)) if hit != null else 0.0
	_expect(min_px >= 2.0, "the outline is never thinner than 2 px (%s)" % [min_px])
	var ink: Color = ol.get_shader_parameter(&"c_ink")
	_expect(ink.get_luminance() > 0.05 and ink.get_luminance() < 0.3 and ink.r > ink.b, "its colour is a dark grey-brown, not black (%s)" % [ink])
	# the cel stone: smeared along its way and whole again
	var b := FormStone.ball(current_scene, rm.ring.center() + Vector3(0, 0, 3.0), {"radius_m": 0.26, "mass_kg": 45.0}, 3, "stone")
	await _ticks(2)
	var before := b.mesh_instance.basis
	b.smear(Vector3.FORWARD, FormStone.SMEAR_K)
	var stretched := (b.mesh_instance.basis * Vector3.FORWARD).length()
	b.smear(Vector3.FORWARD, 1.0)
	_expect(stretched > 1.5 and b.mesh_instance.basis.is_equal_approx(before), "a stone's drawn body is stretched along its way and given back whole (%.2f)" % stretched)
	b.queue_free()
	# a stone bolt: stretched for a moment after it leaves, then whole; its radius its own
	var bolt := BendBolt.launch(foe, rm.ring.center() + Vector3.UP * 4.0, Vector3.FORWARD, {"kind": "stone", "mps": 20.0, "radius_m": 0.2,
			"range_m": 30.0, "gravity": 0.0, "damage": 0.0})
	await _ticks(2)
	var z0 := bolt.scale.z
	await _secs(0.3)
	_expect(z0 > 1.3 and is_equal_approx(bolt.scale.z, 1.0) and is_equal_approx(bolt.radius, 0.2),
			"a stone bolt leaves stretched (%.2f) and is whole after, its radius the same" % z0)
	bolt.end("test")
	# the rocks round the hand lag it and overshoot
	var ch := BendCharge.make(p, "earth")
	await _ticks(2)
	var at := Vector3.ZERO
	ch._tip_s = Vector3.INF
	ch._tip_spring(at, 1.0 / 60.0)
	var peak := 0.0
	var lag_t := -1.0
	var pos := Vector3.ZERO
	for i in 120:
		pos = ch._tip_spring(Vector3(1.0, 0.0, 0.0), 1.0 / 60.0)
		peak = maxf(peak, pos.x)
		if lag_t < 0.0 and pos.x >= 0.5:
			lag_t = float(i) / 60.0
	_expect(lag_t > 0.05 and lag_t < 0.2, "the rocks reach half the hand's move in about a tenth of a second (%.2f s)" % lag_t)
	_expect(peak > 1.05 and peak < 1.4 and absf(pos.x - 1.0) < 0.05, "they overshoot a little and settle on it (peak %.2f, end %.2f)" % [peak, pos.x])
	ch.end("break")
	await _secs(1.2)
	# shape on twos: a slab's drawn size changes at most 12 times a second
	var ch2 := BendCharge.make(p, "earth")
	await _ticks(2)
	var slab: Dictionary = ch2._rocks.filter(func(r: Dictionary) -> bool: return bool(r.slab))[0]
	var sizes := {}
	var t := 0.0
	while t < 0.5:
		ch2.fill = clampf(t / 0.5, 0.0, 1.0)
		await physics_frame
		t += 1.0 / 60.0
		sizes[snappedf((slab.mesh as Node3D).scale.x, 0.0001)] = true
	_expect(sizes.size() <= 8, "its size changes in steps, not every frame (%d sizes in half a second)" % sizes.size())
	ch2.end("break")
	await _secs(1.2)
