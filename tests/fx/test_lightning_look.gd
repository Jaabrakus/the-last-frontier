extends SceneTree
## Lightning's Spellbreak shading (BendLooks.SB_BOLT: our own forked bolt drawn with shaders/cascade/lightning_bolt.gdshader on
## Spellbreak's lightning textures; the owner, 2026-10-09: "for lightning i like our lightning but maybe make it look like
## spellbreaks or use its shaders"). Headless (BendLooks.build_headless: built and stepped, nothing drawn):
##   material    the shader and Spellbreak's two textures (T_f_GenericLighting_F, T_f_SmokeHeight_Greyscale_Uncompressed) load;
##               the shader keeps the effects' near-camera fade and the pool bolt's instance fade
##   strike      BendLooks.lightning builds our forks (a main stroke and its branches: 3 strips or more) on a Spellbreak-shaded
##               bolt from the hand to where it struck, plus SB_HIT_FORKS short forks at the strike; the pool's old bolt is
##               not used
##   timing      the bolt keeps the pool's own timing: rebuilt 3 times, its fade held at 1 to 55 % of its life, gone at 0.26 s
##               (the same frame as ToonFxPool.lightning's), its strips cleared
##   flash       the hand's flash at the release adds SB_HAND_FORKS thin forks off the hand (lightning_flash)
##   charge      the lock's charge (BendLooks.Charge) crackles arcs off the hands instead of its spark shards; end() frees it
##   switch      sb_bolt false draws the old cel bolt (ToonFxPool.lightning) and no Spellbreak-shaded one
##   dice        the restyled bolt, its forks, rebuilds and crackles never roll the game's own random numbers
##   cap         a burst of 40 strikes keeps at most SB_BOLTS bolt nodes; the warm-up draws the bolt once
##   lifecycle   everything ends: no bolt left on, the stage's node count back to where it stood after the first strike, no
##               orphan nodes; freeing the stage leaves the node count where it was before the stage
## Last line "LIGHTNING LOOK PASSED" or "LIGHTNING LOOK FAILED"; exit 0 only on a pass; a watchdog quits with 2.
##   Godot --headless --fixed-fps 60 --path . -s tests/fx/test_lightning_look.gd
##
## The owner's windowed comparison (old bolt against the restyled one, side and over the shoulder) is
## tools/fx/lightning_shots.gd.

const NAME := "LIGHTNING LOOK"
const WATCHDOG_S := 240.0
const A := Vector3(0.0, 1.4, 0.0)
const B := Vector3(0.0, 1.4, -11.0)

var checks := 0
var fails: Array[String] = []
var stage: Node3D
var body: Node3D


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	ToonFx.vis_rng.seed = 1750
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _end() -> void:
	BendLooks.build_headless = false
	BendLooks.sb_bolt = BendLooks.SB_BOLT
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _count(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += _count(k)
	return c


func _pool() -> ToonFxPool:
	return ToonFxPool.of(stage)


## The stage's Spellbreak-shaded bolts (SbBolt under its pool).
func _sb() -> Array:
	var out: Array = []
	var pool := _pool()
	if pool == null:
		return out
	for c in pool.get_children():
		if c is BendLooks.SbBolt:
			out.append(c)
	return out


func _on() -> Array:
	return _sb().filter(func(b: BendLooks.SbBolt) -> bool: return b.on)


func _main_bolt() -> BendLooks.SbBolt:
	for b: BendLooks.SbBolt in _on():
		if b.a.is_equal_approx(A) and b.b.is_equal_approx(B):
			return b
	return null


func _pool_bolts_on() -> int:
	var pool := _pool()
	var n := 0
	for e: Dictionary in (pool.get(&"_bolts") as Array):
		if bool(e.get("on", false)):
			n += 1
	return n


func _quiet() -> void:
	var t := 0
	while (not _on().is_empty() or _pool_bolts_on() > 0) and t < 120:
		await process_frame
		t += 1


func _run() -> void:
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	BendLooks.build_headless = true
	BendLooks.sb_bolt = true
	stage = Node3D.new()
	stage.name = "LightningStage"
	root.add_child(stage)
	current_scene = stage
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(60, 1, 60)
	cs.shape = bx
	ground.add_child(cs)
	stage.add_child(ground)
	ground.global_position = Vector3(0, -0.5, 0)
	body = Node3D.new()
	body.name = "Caster"
	stage.add_child(body)
	await _frames(3)
	_material()
	await _strike()
	await _flash()
	await _charge()
	await _switch()
	await _dice()
	await _cap()
	await _quiet()
	await _frames(3)
	_expect(_on().is_empty() and _pool_bolts_on() == 0, "every bolt ends (%d Spellbreak-shaded, %d old still on)" % [_on().size(),
			_pool_bolts_on()])
	# (a round of everything first, so the pool holds every emitter and bolt it keeps (each to its cap); three more rounds add
	# nothing)
	await _again()
	var n0 := _count(stage)
	var orphans0 := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for r in 3:
		await _again()
	var n := _count(stage)
	_expect(n == n0, "three more rounds of every lightning look add no node (%d, %d before them)" % [n, n0])
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_expect(orphans <= orphans0, "no orphan nodes left (%d, %d before)" % [orphans, orphans0])
	stage.queue_free()
	await _frames(3)
	var nodes_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_expect(nodes_after <= nodes_before, "freeing the stage frees every bolt (nodes %d, %d before the stage)" % [nodes_after,
			nodes_before])
	_end()


# ---------------------------------------------------------------- material
func _material() -> void:
	var m := BendLooks.sb_bolt_material()
	_expect(m != null and m.shader != null and m.shader.resource_path == BendLooks.SB_BOLT_SHADER,
			"the bolt's material uses %s" % BendLooks.SB_BOLT_SHADER)
	var bt: Variant = m.get_shader_parameter(&"bolt_tex")
	var nt: Variant = m.get_shader_parameter(&"noise_tex")
	_expect(bt is Texture2D and (bt as Texture2D).resource_path == BendLooks.SB_BOLT_TEX and nt is Texture2D
			and (nt as Texture2D).resource_path == BendLooks.SB_BOLT_NOISE, "Spellbreak's bolt and noise textures load")
	var code := m.shader.code if m.shader != null else ""
	_expect(code.contains("near_cut(") and code.contains("instance uniform float fade"),
			"the shader keeps the near-camera fade and the pool bolt's instance fade")
	_expect(BendLooks.sb_bolt_material() == m, "the material is shared (made once)")


# ---------------------------------------------------------------- strike and timing
func _strike() -> void:
	BendLooks.lightning(A, B)
	var main := _main_bolt()
	_expect(main != null, "a strike draws a Spellbreak-shaded bolt from the hand to where it struck")
	if main == null:
		return
	var im := main.mesh as ImmediateMesh
	_expect(im != null and im.get_surface_count() >= 3, "our forks: a main stroke and its branches (%d strips)" % [
			im.get_surface_count() if im != null else 0])
	_expect(main.visible and main.material_override == BendLooks.sb_bolt_material(), "drawn with the shared Spellbreak shading")
	_expect(is_equal_approx(float(main.get_instance_shader_parameter(&"len_m")), A.distance_to(B)),
			"the shader knows the stroke's length (%.2f m)" % float(main.get_instance_shader_parameter(&"len_m")))
	var forks := _on().filter(func(b: BendLooks.SbBolt) -> bool: return b != main and b.a.is_equal_approx(B))
	_expect(forks.size() == BendLooks.SB_HIT_FORKS, "%d short forks at the strike (%d)" % [BendLooks.SB_HIT_FORKS, forks.size()])
	_expect(_pool_bolts_on() == 0, "the pool's old bolt is not drawn as well")
	# (its life on the pool's timing: 0.26 s, 3 builds, fade 1 to 55 %)
	var frames := 0
	var fade_early := 1.0
	var fade_late := 1.0
	while main.on and frames < 60:
		await process_frame
		frames += 1
		if main.t < main.life * 0.5:
			fade_early = minf(fade_early, float(main.get_instance_shader_parameter(&"fade")))
		elif main.on:
			fade_late = minf(fade_late, float(main.get_instance_shader_parameter(&"fade")))
	var dt := root.get_process_delta_time()
	var want := int(ceil(0.26 / maxf(dt, 1e-4) - 1e-4))
	_expect(absi(frames - want) <= 1, "gone after 0.26 s, as the pool's bolt (%d frames, %d expected)" % [frames, want])
	_expect(main.builds == 3, "rebuilt over its life as the pool's bolt flickers (%d builds, 3 expected)" % main.builds)
	_expect(is_equal_approx(fade_early, 1.0) and fade_late < 0.9, "whole to half its life, then eroded (%.2f, %.2f)" % [fade_early,
			fade_late])
	_expect(not main.visible and im.get_surface_count() == 0, "then hidden and its strips cleared")
	await _quiet()


# ---------------------------------------------------------------- the hand's flash and the charge
func _flash() -> void:
	var at := Vector3(0.3, 1.5, -0.4)
	BendLooks.lightning_flash(body, at)
	var hand := _on().filter(func(b: BendLooks.SbBolt) -> bool: return b.a.is_equal_approx(at))
	_expect(hand.size() == BendLooks.SB_HAND_FORKS, "the release's flash crackles %d forks off the hand (%d)" % [
			BendLooks.SB_HAND_FORKS, hand.size()])
	var thin := not hand.is_empty()
	for b: BendLooks.SbBolt in hand:
		var wk := float(b.get_instance_shader_parameter(&"width_k"))
		thin = thin and is_equal_approx(wk, BendLooks.SB_FORK_WIDTH) and b.a.distance_to(b.b) <= BendLooks.SB_FORK_M.y + 0.01
	_expect(thin, "short and thin (%.2f of a strike's width, %.2f m at most)" % [BendLooks.SB_FORK_WIDTH, BendLooks.SB_FORK_M.y])
	await _quiet()


func _charge() -> void:
	var builds0 := 0
	for b: BendLooks.SbBolt in _sb():
		builds0 += b.builds
	var ch := BendLooks.charge(body, null)
	ch.level = 1.0
	await _frames(30)
	var builds := 0
	for b: BendLooks.SbBolt in _sb():
		builds += b.builds
	var shards := ch.find_children("*", "GPUParticles3D", true, false).size()
	_expect(builds > builds0 and shards == 0, "the charge crackles arcs off the hands (%d builds in 0.5 s), no spark shards (%d)" % [
			builds - builds0, shards])
	var wr: WeakRef = weakref(ch)
	ch.end()
	await _frames(2)
	_expect(wr.get_ref() == null, "the charge's node is freed at its end")
	await _quiet()


# ---------------------------------------------------------------- the switch and the dice
func _switch() -> void:
	BendLooks.sb_bolt = false
	BendLooks.lightning(A, B)
	_expect(_on().is_empty() and _pool_bolts_on() == 1, "switched off: the old cel bolt and no Spellbreak-shaded one (%d, %d)" % [
			_pool_bolts_on(), _on().size()])
	var ch := BendLooks.charge(body, null)
	await _frames(1)
	var shards := ch.find_children("*", "GPUParticles3D", true, false).size()
	_expect(shards >= 1, "switched off: the charge's spark shards as before (%d)" % shards)
	ch.end()
	BendLooks.sb_bolt = true
	await _quiet()


## (the restyle's own draws (the bolt nodes, their forks and rebuilds, the crackles) roll ToonFx.vis_rng only; the flashes and
## sparks round it are the old look's own, the same calls in both looks)
func _dice() -> void:
	await _quiet()
	seed(99)
	var base := [randi(), randi()]
	seed(99)
	BendLooks.sb_strike(_pool(), A, B, 0.26, 3)
	BendLooks._sb_crackle(_pool(), B, Vector3.UP, 3, 0.26)
	await _frames(20)
	var got := [randi(), randi()]
	_expect(got == base, "the restyled bolt never rolls the game's own random numbers (%s, %s)" % [got, base])


## One round of every lightning look (on and off), then quiet.
func _again() -> void:
	for sw in [true, false]:
		BendLooks.sb_bolt = sw
		BendLooks.lightning_flash(body, A)
		BendLooks.lightning(A, B)
		var ch := BendLooks.charge(body, null)
		ch.level = 1.0
		await _frames(12)
		ch.end()
		for i in 12:
			BendLooks.lightning(A + Vector3(i * 0.1, 0, 0), B)
		BendLooks._warm_lightning(_pool(), A)
		await _quiet()
	BendLooks.sb_bolt = true
	await _frames(3)


# ---------------------------------------------------------------- cap and warm-up
func _cap() -> void:
	await _quiet()
	for i in 40:
		BendLooks.lightning(A + Vector3(i * 0.1, 0, 0), B)
	_expect(_sb().size() <= BendLooks.SB_BOLTS, "40 strikes at once keep at most %d bolt nodes (%d)" % [BendLooks.SB_BOLTS,
			_sb().size()])
	await _quiet()
	BendLooks._warm_lightning(_pool(), A)
	var warm := _on().filter(func(b: BendLooks.SbBolt) -> bool: return is_equal_approx(b.life, 0.15))
	_expect(warm.size() == 1 and _pool_bolts_on() == 1, "the warm-up draws the restyled bolt once (and the old one)")
