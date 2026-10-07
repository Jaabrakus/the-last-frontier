extends SceneTree
## Round 4 LOOKS (the elements' looks polished inside their stylized look; data/bending/fx_looks.json), in Tidebreak's ring
## (scenes/ring.tscn, the foe held where he stands). The looks are built headless here (BendLooks.build_headless: what is
## drawn, counted without drawing):
##   flames      the flame shaders blend a soft alpha (no hard cut of the body: the one discard is the near fade's
##               screen-door), and every flame cluster has its glow underlay (the fireball, the fire disc, the High Kick's
##               crescent, the fire wall, the Kick); the fireball has 7-9 tongues
##   the Kick    21 or more tongues in 3 rows, 1.0 m deep or more, its visible top within 0.1 m of the height a jump clears
##               (the bolt's miss_above_m: its hitbox for a body, read from its spec)
##   smoke       Breath's smoke zone: its radius and life as Breath makes them, and it still hides a body from a bot
##   near fade   0.3 or less at 1.0 m from the camera, 1.0 at 6 m; every bend_fx shader uses it
##   Wind Guard  your own guard's bands drawn 0.6 as wide; the bot's own guard's 1.0 (everyone else's read unchanged)
##   your walls  one between the camera and your head dithers (to 0.35) and still stops a stone bolt and a bot's sight ray;
##               one in front of you stays whole
##   shadows     every bolt kind but air and lightning has a shadow-only core; air has its dust line (AirDust)
##   at range    the core's drawn scale at 25 m is 2x or more its scale at 8 m, the bolt's collision radius unchanged
##   puffs       a hit's burst on a body stays within 0.6 of the body's height (at the bolts' hit sizes); the puffs drawn at
##               half before the struck body
##   no cues     a hit's burst adds no node to the struck body; a wave's look is the bolt's own children
##   warm-up     every new material warmed (flame_glow, flame_lip, the smoke's)
## METRIC lines (flame_soft_ok, floor_wave_tongues, floor_wave_depth_m, top_vs_hitbox_m, smoke_screen_unchanged_ok,
## near_alpha_1m, own_guard_band_w, wall_fade_blocks_ok, shadow_kinds_ok, core_px_25m (analytic, 1280x720 at the player's
## fov), puff_height_ratio). Last line "R4 LOOKS PASSED" or "R4 LOOKS FAILED"; exit 0 only on a pass; a watchdog quits with 2.
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_r4_looks.gd

const NAME := "R4 LOOKS"
const WATCHDOG_S := 300.0
const OWN_CFG := "user://r4_looks_test.cfg"
const SHADERS := ["toon_flame", "toon_puff", "toon_spark", "toon_water", "toon_wind", "toon_facet", "toon_bolt", "toon_sprite",
		"toon_mark", "toon_glow", "toon_smoke"]

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var p: FrontierPlayer
var rm: RingMode
var foe: NpcFighter
var metrics := {}
var _foe_at := Vector3.INF
var _p_at := Vector3.INF


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
	var kn := BendKnock.peek(p)
	if kn != null:
		kn.reset()
	var fk := BendKnock.peek(foe)
	if fk != null:
		fk.reset()


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
	_p_at = rm.ring.center() - ax * 4.5
	_foe_at = rm.ring.center() + ax * 4.5
	RingLevel.place(p, Transform3D(Basis.looking_at(ax, Vector3.UP), _p_at))
	physics_frame.connect(_hold)
	await _secs(0.5)
	_flames()
	await _floor_wave()
	await _smoke()
	_near()
	await _guard()
	await _walls()
	_shadows()
	_range()
	_puffs()
	await _warm()
	for k in metrics:
		print("METRIC %s %s" % [k, str(metrics[k])])
	BendLooks.build_headless = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	if fails.is_empty():
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		print("%s FAILED (%d of %d): %s" % [NAME, fails.size(), checks, fails])
		quit(1)


func _holder(at: Vector3) -> Node3D:
	var h := Node3D.new()
	current_scene.add_child(h)
	h.global_position = at
	return h


## An instance uniform's value (`dflt` when never set).
func _num(g: GeometryInstance3D, nm: StringName, dflt: float) -> float:
	var v: Variant = g.get_instance_shader_parameter(nm)
	return float(v) if v is float or v is int else dflt


func _child(n: Node, nm: String) -> Node:
	for c in n.get_children():
		if c.name == nm or String(c.name).begins_with(nm):
			return c
	return null


# ---------------------------------------------------------------- flames
func _flames() -> void:
	var src := (load("res://shaders/bend_fx/toon_flame.gdshader") as Shader).code
	var ring_src := (load("res://shaders/ring/ring_flame.gdshader") as Shader).code
	var soft := src.contains("blend_mix") and src.contains("softstep(") and not src.contains("discard;") \
			and src.contains("near_fade(")
	var ring_soft := ring_src.contains("blend_mix") and not ring_src.contains("discard") and ring_src.contains("ALPHA")
	_expect(soft, "the moves' flame blends a soft alpha (no discard: no hard cut; its near fade is its alpha)")
	_expect(ring_soft, "the braziers' flame blends a soft alpha too (no discard)")
	metrics["flame_soft_ok"] = soft and ring_soft
	var at := rm.ring.center() + Vector3.UP * 3.0
	var fb := _holder(at)
	BendLooks.bolt_body(fb, "fire", 0.5)
	var tongues := _child(fb, "Tongues") as MultiMeshInstance3D
	_expect(tongues != null and tongues.multimesh.instance_count >= 7 and tongues.multimesh.instance_count <= 9,
			"the fireball has 7-9 tongues (%d)" % (tongues.multimesh.instance_count if tongues else -1))
	_expect(_child(fb, "Glow") != null, "the fireball has its glow underlay")
	var disc := _holder(at)
	BendLooks.bolt_body(disc, "fire", 0.3, false, "disc")
	_expect(_child(disc, "Glow") != null, "the fire disc has its glow underlay")
	var cr := _holder(at)
	BendLooks.bolt_body(cr, "fire", 0.4, false, "crescent")
	_expect(_child(cr, "Glow") != null, "the High Kick's crescent has its glow underlay")
	var fw := BendZone.make(p, "fire_wall", rm.ring.center() + rm.ring.global_basis.z * 8.0, {"width_m": 4.0, "height_m": 2.0,
			"thick_m": 0.6, "life_s": 0.5}, rm.ring.axis())
	var look := _child(fw, "Look")
	var fl := _child(look, "Flames") as MultiMeshInstance3D if look else null
	_expect(look != null and _child(look, "Glow") != null, "the fire wall has its glow underlay")
	_expect(fl != null and fl.multimesh.instance_count >= 2 * 2 * int(4.0 / 0.42), "the fire wall's flames are twice as many (%d)"
			% (fl.multimesh.instance_count if fl else -1))
	for h in [fb, disc, cr]:
		h.queue_free()


# ---------------------------------------------------------------- the Kick
func _floor_wave() -> void:
	var spec: Dictionary = (SwayMoves.move("fire_kick").get("bend", {}) as Dictionary).get("kick", {}).duplicate(true)
	_expect(String(spec.get("do", "")) == "floor_wave", "the Kick's spec is a floor wave")
	var side := rm.ring.global_basis.z.normalized()
	var from := rm.ring.center() + side * 5.0
	var b := BendBolt.launch(foe, from, side, spec)
	await _ticks(2)
	var wave := _child(b, "Wave") as Node3D
	var mmi := _child(wave, "Tongues") as MultiMeshInstance3D if wave else null
	var n := mmi.multimesh.instance_count if mmi else 0
	var heats := {}
	var zmin := INF
	var zmax := -INF
	var top := 0.0
	var fill := float(ToonFx.looks("floor_wave").get("fill", 0.92))
	var laid: Array = mmi.get_meta(&"tongues", []) if mmi else []
	_expect(laid.size() == n, "its MultiMesh holds what it laid out")
	for e: Dictionary in laid:
		var xf: Transform3D = e.xf
		heats[snappedf(float(e.heat), 0.01)] = true
		zmin = minf(zmin, xf.origin.z)
		zmax = maxf(zmax, xf.origin.z)
		top = maxf(top, xf.basis.y.length() * fill)
	var depth := zmax - zmin if n > 0 else 0.0
	var off := absf(top - b.miss_above_m)
	_expect(n >= 21, "the Kick builds 21 or more tongues (%d)" % n)
	_expect(heats.size() == 3, "in 3 rows (%d)" % heats.size())
	_expect(depth >= 1.0 and depth <= 1.45, "1.0-1.4 m deep (%.2f)" % depth)
	_expect(off <= 0.1, "its top within 0.1 m of its hitbox's height (top %.2f, miss_above_m %.2f)" % [top, b.miss_above_m])
	_expect(wave != null and _child(wave, "Glow") != null and _child(wave, "Lip") is ToonRibbon and _child(wave, "WaveFx") != null,
			"its glow, its lip along the deck and its scorches")
	_expect(is_equal_approx(b.miss_above_m, float(spec.get("miss_above_m", -1.0))) and is_equal_approx(b.height_m,
			float(spec.get("height_m", -1.0))), "its hitbox's numbers are the spec's")
	metrics["floor_wave_tongues"] = n
	metrics["floor_wave_depth_m"] = snappedf(depth, 0.01)
	metrics["top_vs_hitbox_m"] = snappedf(off, 0.01)
	var rows := BendLooks.wave_tongues(1.2, 0.6)
	_expect(rows.size() == n, "wave_tongues is what it builds")
	if is_instance_valid(b):
		b.end("test")
	await _ticks(2)


# ---------------------------------------------------------------- Breath's smoke
func _smoke() -> void:
	var br: Dictionary = (SwayMoves.move("fire_breath").get("bend", {}) as Dictionary).get("breath", {})
	var r := maxf(float(br.get("range_m", 4.5)) * 0.45, 1.5)
	var life := float(br.get("smoke_s", 5.0))
	var mid := _p_at.lerp(_foe_at, 0.5)
	var z := BendZone.make(foe, "smoke", FormEffects.ground_at(foe, mid), {"radius_m": r, "life_s": life}, rm.ring.axis())
	await _ticks(3)
	var hid := NpcBendCaster.hidden(foe, p)
	var em: GPUParticles3D = null
	for c in z.get_children():
		if c is GPUParticles3D:
			em = c
	var ok := is_equal_approx(z.radius, 2.025) and is_equal_approx(z.life_s, 5.0) and hid
	_expect(is_equal_approx(z.radius, 2.025), "Breath's smoke radius as the base's (%.3f)" % z.radius)
	_expect(is_equal_approx(z.life_s, 5.0), "its life as the base's (%.1f)" % z.life_s)
	_expect(hid, "it still hides the player from the bot")
	_expect(em != null and em.draw_order == GPUParticles3D.DRAW_ORDER_VIEW_DEPTH and em.material_override is ShaderMaterial
			and (em.material_override as ShaderMaterial).shader == ToonFx.SHADERS.smoke, "drawn as a lit volume, its puffs sorted")
	metrics["smoke_screen_unchanged_ok"] = ok
	z.end()
	await _ticks(2)


# ---------------------------------------------------------------- the near fade
func _near() -> void:
	var a1 := ToonFx.near_alpha(1.0)
	var a6 := ToonFx.near_alpha(6.0)
	_expect(a1 <= 0.3, "0.3 or less at 1.0 m from the camera (%.2f)" % a1)
	_expect(is_equal_approx(a6, 1.0), "1.0 at 6 m (%.2f)" % a6)
	var all := true
	for s: String in SHADERS:
		var code := (load("res://shaders/bend_fx/%s.gdshader" % s) as Shader).code
		if not (code.contains("near_cut(") or code.contains("near_fade(")):
			all = false
			print("    %s has no near fade" % s)
	_expect(all, "every bend_fx shader fades near the camera")
	metrics["near_alpha_1m"] = snappedf(a1, 0.01)


# ---------------------------------------------------------------- your own Wind Guard
func _band_w(z: BendZone) -> Array:
	var out := []
	var look := _child(z, "Look")
	if look == null:
		return out
	for c in look.get_children():
		if c is MeshInstance3D:
			out.append(_num(c as MeshInstance3D, &"band_w", -1.0))
	return out


func _guard() -> void:
	_expect(ToonFx.is_own(p) and not ToonFx.is_own(foe), "the player is this machine's own; the bot is not")
	var mine := BendZone.make(p, "air_shield", p.global_position, {"radius_m": 1.8, "window_s": 0.8}, rm.ring.axis())
	var his := BendZone.make(foe, "air_shield", foe.global_position, {"radius_m": 1.8, "window_s": 0.8}, -rm.ring.axis())
	var wm := _band_w(mine)
	var wh := _band_w(his)
	_expect(wm.size() == 3 and wm.all(func(v: float) -> bool: return is_equal_approx(v, 0.6)), "your own guard's bands x0.6 %s" % [wm])
	_expect(wh.size() == 3 and wh.all(func(v: float) -> bool: return is_equal_approx(v, 1.0)), "the bot's guard's bands as now %s" % [wh])
	metrics["own_guard_band_w"] = wm[0] if wm.size() > 0 else -1.0
	mine.end()
	his.end()
	await _ticks(2)


# ---------------------------------------------------------------- your own walls
func _walls() -> void:
	var cam := root.get_viewport().get_camera_3d()
	_expect(cam != null, "the player's camera")
	if cam == null:
		return
	var fwd := _foe_at - _p_at
	fwd.y = 0.0
	fwd = fwd.normalized()
	var spec := SwayMoves.move("earth_wall")
	var back := FormEffects.earth_wall(p, _p_at - fwd * 1.1, spec)
	var front := FormEffects.earth_wall(p, _p_at + fwd * 2.2, spec)
	await _secs(1.4)
	var bf := _num(back.mesh_instance, &"fade", 1.0) if is_instance_valid(back) else -1.0
	var ff := _num(front.mesh_instance, &"fade", 1.0) if is_instance_valid(front) else -1.0
	var cam_d := cam.global_position.distance_to(NpcSenses.head_of(p))
	print("    camera %.2f m from the head; back wall fade %.2f, front %.2f" % [cam_d, bf, ff])
	_expect(bf >= 0.0 and bf <= 0.36, "your wall between the camera and your head dithers (%.2f)" % bf)
	_expect(ff >= 0.99, "your wall in front of you stays whole (%.2f)" % ff)
	# it still stops a stone and a bot's sight
	var behind := back.global_position - fwd * 1.5 + Vector3.UP * 1.2
	var why := []
	var sb := BendBolt.launch(foe, behind, (NpcSenses.chest_of(p) - behind).normalized(), {"kind": "stone", "mps": 30.0,
			"radius_m": 0.2, "damage": 1.0, "knock_mps": 0.0, "range_m": 20.0, "gravity": 0.0})
	sb.ended.connect(func(w: String) -> void: why.append(w))
	await _until(func() -> bool: return not why.is_empty(), 1.5)
	var q := PhysicsRayQueryParameters3D.create(behind, NpcSenses.head_of(p), 0xFFFFFFFF)
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	var sight_blocked: bool = not hit.is_empty() and hit.collider == back
	_expect(why.size() > 0 and why[0] == "wall", "the faded wall still stops a stone bolt (%s)" % [why])
	_expect(sight_blocked, "and a bot's sight ray")
	metrics["wall_fade_blocks_ok"] = bf <= 0.36 and why.size() > 0 and why[0] == "wall" and sight_blocked and ff >= 0.99
	for w in [back, front]:
		if is_instance_valid(w):
			w.queue_free()
	await _ticks(2)


# ---------------------------------------------------------------- shadows, range
func _shadows() -> void:
	var at := rm.ring.center() + Vector3.UP * 3.0
	var ok := true
	var cases := [["stone", "ball", false], ["stone", "ball", true], ["stone", "disc", false], ["stone", "spear", false],
			["ice", "ball", false], ["ice", "spear", false], ["water", "ball", false], ["water", "ball", true],
			["fire", "ball", false], ["fire", "disc", false], ["fire", "crescent", false]]
	for c: Array in cases:
		var h := _holder(at)
		BendLooks.bolt_body(h, String(c[0]), 0.25, bool(c[2]), String(c[1]))
		var sh := _child(h, "Shadow") as GeometryInstance3D
		var good := sh != null and sh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		for g in h.get_children():
			if g is GeometryInstance3D and g != sh and (g as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				good = false
		if not good:
			ok = false
			print("    no shadow core (or a second shadow): %s" % [c])
		h.queue_free()
	var air := _holder(at)
	BendLooks.bolt_body(air, "air", 0.3)
	var lt := _holder(at)
	BendLooks.bolt_body(lt, "lightning", 0.12)
	var air_ok := _child(air, "AirDust") != null and _child(air, "Shadow") == null
	var lt_ok := _child(lt, "Shadow") == null
	_expect(ok, "every bolt kind but air and lightning has its shadow-only core")
	_expect(air_ok, "air has its dust line instead")
	_expect(lt_ok, "lightning none")
	metrics["shadow_kinds_ok"] = ok and air_ok and lt_ok
	air.queue_free()
	lt.queue_free()


func _range() -> void:
	var k8 := ToonFx.range_scale(8.0)
	var k25 := ToonFx.range_scale(25.0)
	_expect(k25 >= 2.0 * k8, "the core's scale at 25 m (%.2f) is 2x or more its scale at 8 m (%.2f)" % [k25, k8])
	var same := true
	for k in ["stone", "fire", "water", "ice", "air"]:
		var b := BendBolt.launch(foe, rm.ring.center() + Vector3.UP * 6.0, Vector3.UP, {"kind": k, "mps": 1.0, "radius_m": 0.22,
				"range_m": 5.0, "gravity": 0.0, "damage": 0.0})
		var core_on := false
		for c in b.find_children("*", "GeometryInstance3D", true, false):
			if _num(c as GeometryInstance3D, &"range_on", 0.0) > 0.5:
				core_on = true
		if not is_equal_approx(b.radius, 0.22) or not core_on:
			same = false
			print("    %s: radius %.3f, core grows %s" % [k, b.radius, core_on])
		b.end("test")
	_expect(same, "the bolts' collision radius unchanged, their drawn cores grown at range")
	# the drawn core at 25 m, 1280x720 at the player's fov (analytic): its smallest kind's pixels across
	var fov := deg_to_rad(p.fov if p.fov > 1.0 else 52.5)
	var cores := {"stone": 0.28, "ice": 0.15 * 1.4, "water": 0.25 * 1.3, "fire": 0.2 * 1.0, "air": 0.3 * 1.25, "embers": 0.08 * 1.0}
	var least := INF
	for k in cores:
		var px := 2.0 * float(cores[k]) * k25 / (2.0 * 25.0 * tan(fov * 0.5)) * 720.0
		least = minf(least, px)
	metrics["core_px_25m"] = snappedf(least, 0.1)
	_expect(least >= 6.0, "the smallest core covers about 6 px or more at 25 m (%.1f)" % least)


# ---------------------------------------------------------------- puffs, no cues
func _count(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += _count(k)
	return c


func _puffs() -> void:
	var at := foe.global_position + Vector3.UP * 1.2
	_expect(BendLooks.struck_body(at) == foe, "a burst at his chest is on him")
	var worst := 0.0
	var h := BendLooks.body_h(foe)
	for k in ["fire", "water", "steam", "ice", "air", "stone", "lightning"]:
		for sz in [0.25, 0.45, 0.9]:
			for sp in [3.0, 3.5]:
				var f := BendLooks.burst_cap(k, sp, sz, h)
				worst = maxf(worst, BendLooks.burst_span(k, sp, sz, f) / h)
	_expect(worst <= 0.6 + 1e-3, "a hit's burst on a body stays within 0.6 of its height (%.2f)" % worst)
	metrics["puff_height_ratio"] = snappedf(worst, 0.01)
	var before := _count(foe)
	BendLooks.burst(at, "fire", 16, Vector3.BACK, 80.0, 3.5)
	BendLooks.burst(at, "stone", 16, Vector3.BACK, 80.0, 3.5)
	var after := _count(foe)
	_expect(before == after, "no node is added to the struck body (%d -> %d)" % [before, after])
	var pool := ToonFxPool.of(current_scene)
	var half := false
	for c in pool.get_children():
		if c is GPUParticles3D and (c as GPUParticles3D).material_override == ToonFx.mat("puff_fire"):
			var o: Variant = (c as GPUParticles3D).get_instance_shader_parameter(&"occl")
			if o is Vector4 and (o as Vector4).w > 0.0:
				half = true
	_expect(half, "the puffs before the struck body are drawn at half (their occl set)")


# ---------------------------------------------------------------- warm-up
func _warm() -> void:
	var cam := root.get_viewport().get_camera_3d()
	if cam == null:
		_expect(false, "a camera to warm up from")
		return
	await BendLooks.warm_up(cam)
	var has := ToonFx._mats.has("flame_glow") and ToonFx._mats.has("flame_lip") and ToonFx._mats.has("flame_orb") \
			and ToonFx._mats.has("flame_wave") and ToonFx._mats.has("puff_smoke") \
			and (ToonFx._mats["puff_smoke"] as ShaderMaterial).shader == ToonFx.SHADERS.smoke
	_expect(has, "the warm-up covers every new material (flame_glow, flame_lip, flame_orb, flame_wave, the smoke's)")
