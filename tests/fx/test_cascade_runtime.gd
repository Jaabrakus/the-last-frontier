extends SceneTree
## The rebuilt Spellbreak effects in the game (Spellbreak by Proletariat; provenance in assets/fx/spellbreak/SOURCE.md):
## the Cascade runtime (CascadeFx), its materials (CascadeMaterials) and the player (SpellFx), headless:
##
##   Godot --headless --fixed-fps 60 --path . -s tests/fx/test_cascade_runtime.gd [-- only=<substring>]
##
##   import   every imported effect (assets/fx/spellbreak/index.json) has its spec, textures and meshes imported, and
##            every texture the runtime asked for loaded (or the Spellbreak FX browser lacks it too)
##   spawn    every imported effect spawns through SpellFx.spawn (effects that need motion follow a node moving at
##            15 m/s, as in the browser), runs 3 s of frames, then ends: by itself (one-shot) or after stop(); its
##            node goes back to the pool; the frames it showed particles in are counted; none has a mesh the
##            library lacks (CascadeFx.warnings)
##   scalar   CascadeFx.s1 (the array-free scalar read) gives what sample()[0] gives, on every table of every spec
##   api      follow, attach, scale, tint (off by default), stop (particles play out), kill, life, restart, pooled reuse,
##            a handle used after its effect ended, a followed node freed mid-flight, an attached node freed, a spawn
##            before the player is in the tree (a child's _ready), prewarm (parks a built node that the first spawn reuses)
##   edges    a handle killed by another's finished handler ends once; an attached node taken out of the tree ends the
##            effect; a camera freed while a prewarm awaits; a stalled frame feeds an effect at most MAX_STEP_S; the MultiMesh
##            buffer outgrows its count and visible_instance_count carries it; idle_count and has_effect
##   perf     "PERF cascade ..." ms per frame of SpellFx's step with 8 effects playing at once (CPU; headless draws
##            nothing)
##   leaks    the player freed: the node count back where it started, no orphan nodes
## Ends with "CASCADE RUNTIME TEST PASSED (<n> checks)" or "CASCADE RUNTIME TEST FAILED (<f> of <n>)".
##
## The windowed capture against the browser (same scene, framing, seed and shot times as the browser's sweep) and the
## windowed perf are tools/fx/cascade_capture.gd.

const MOVE_SPEED := 15.0
## Meshes some effect names that the extraction does not hold (the Spellbreak FX browser lacks them too): the emitter draws a
## sphere in their place. EarthImpactAOE_FX_Meteor's "Straight Flares" (a developer-folder mesh, not in the pak's closure).
const MESHES_NOT_EXTRACTED := ["missing mesh:SM_Flare_Straight"]
## Effects the data files wire (a pool trim or a re-import must not break the test; one the game never plays proves less).
const PERF_SET := [
	"g3/Content/VFX/Character/Fire/Fireball_Base_Projectile01_FxP",
	"g3/Content/VFX/Character/Fire/Fire_Firefly_End01_FxP",
	"g3/Content/VFX/Character/Earth/EarthImpactAOE_FX_Meteor",
	"g3/Content/VFX/Cosmetics/CloudBurst/RiversReflection/CB_RiversReflection_FxP",
	"g3/Content/VFX/Character/Wind/WindProj_FX",
	"g3/Content/VFX/Character/Wind/WindExplode_FX",
	"g3/Content/VFX/Character/Vapor/VaporCloud_FX",
	"g3/Content/VFX/Character/Fire/FireWall_FX_TranslucentSmoke",
]

var checks := 0
var fails: Array[String] = []
var args := {}
var cam: Camera3D
var mover: Node3D
var move_t := 0.0
var moving := false


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		print("  FAIL " + what)
		fails.append(what)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "on"
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Moves `mover` as the browser does for effects that need motion (back and forth along x at 15 m/s).
func _move(dt: float) -> void:
	if not moving:
		return
	move_t += dt
	var span := 12.0
	var x := fmod(move_t * MOVE_SPEED, span * 2.0)
	var dir := 1.0 if x < span else -1.0
	var px := (x if x < span else span * 2.0 - x) - span * 0.5
	mover.position = Vector3(px, 1.2, 0)
	mover.basis = Basis() if dir > 0.0 else Basis(Vector3.UP, PI)


static func needs_motion(sp: Dictionary) -> bool:
	for e in sp.get("emitters", []):
		if not e.enabled:
			continue
		if e.type == "ribbon" or e.type == "anim_trail":
			return true
		for m in e.modules:
			if m.enabled and (m["class"] == "SpawnPerUnit" or m["class"] == "VelocityInheritParent"):
				return true
	return false


## Every effect the four element files (data/bending/sb_fx) wire: the part of the pool a trim must keep, so the checks that
## count the index count these (an unwired effect may leave the pool).
static func wired_ids() -> Array:
	var out := {}
	for el: String in SbFx.ELEMENTS:
		for roles: Variant in SbFx.table(el).values():
			if roles is Dictionary:
				for e: Variant in (roles as Dictionary).values():
					if e is Dictionary and String((e as Dictionary).get("effect", "")) != "":
						out[String((e as Dictionary)["effect"])] = true
	return out.keys()


## The Marketplace pack files found inside the Spellbreak client are a third party's (assets/fx/spellbreak/SOURCE.md): the
## shared repository keeps them out (.gitignore), so a fresh checkout lacks the folder. TB_NO_THIRD_PARTY=1 pretends it is
## absent, to run this test the way a fresh checkout does.
static func _pack_present() -> bool:
	return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://assets/fx/spellbreak/assets/MarketplaceAssets")) \
			and not OS.has_environment("TB_NO_THIRD_PARTY")


static func _needs_pack(row: Dictionary) -> bool:
	for k: String in ["textures", "meshes"]:
		for f: String in row.get(k, []):
			if f.contains("MarketplaceAssets/"):
				return true
	return false


func _run() -> void:
	var t_start := Time.get_ticks_msec()
	cam = Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(0, 3, 9)
	cam.look_at(Vector3(0, 1.2, 0), Vector3.UP)
	cam.current = true
	mover = Node3D.new()
	root.add_child(mover)
	mover.position = Vector3(0, 1.2, 0)
	await _frames(2)
	var base_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var base_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var only := String(args.get("only", ""))

	# ---- import
	var cat := SpellFx.catalogue()
	var ids: Array = []
	var no_pack: Array[String] = []   # effects whose files are in the Marketplace pack folder, which the shared repository leaves out
	for id: String in cat:
		if only != "" and not id.contains(only):
			continue
		if not _pack_present() and _needs_pack(cat[id]):
			no_pack.append(id)
			continue
		ids.append(id)
	if not no_pack.is_empty():
		print("  skipped (their files are in assets/fx/spellbreak/assets/MarketplaceAssets, not in the repository): ", ", ".join(no_pack))
	var wired := wired_ids().filter(func(x: Variant) -> bool: return not (x in no_pack))
	_expect(only != "" or (not wired.is_empty() and ids.size() >= wired.size() and wired.all(func(x: Variant) -> bool: return cat.has(x))),
			"index.json lists every effect the element files wire (%d of %d)" % [ids.size(), wired.size()])
	for id: String in ids:
		var row: Dictionary = cat[id]
		_expect(SpellFx.has_effect(id) and not SpellFx.spec(id).is_empty(), "%s: spec imported" % id)
		for t: String in row.get("textures", []):
			_expect(ResourceLoader.exists("res://assets/fx/spellbreak/" + t), "%s: texture %s imported" % [id, t])
		for m: String in row.get("meshes", []):
			_expect(ResourceLoader.exists("res://assets/fx/spellbreak/" + m), "%s: mesh %s imported" % [id, m])

	# ---- spawn every effect, 3 s, end
	var player := SpellFx.of(root)
	_expect(player != null and player.get_parent() == root, "SpellFx.of(root) makes the player under root")
	var quiet: Array[String] = []
	var looped: Array[String] = []
	var total_frames := 0
	for id: String in ids:
		moving = needs_motion(SpellFx.spec(id))
		move_t = 0.0
		mover.position = Vector3(0, 1.2, 0)
		mover.basis = Basis()
		var h: SpellFx.Handle = SpellFx.spawn(id, mover if moving else Transform3D(Basis(), Vector3(0, 1.2, 0)))
		_expect(h != null and h.is_playing(), "%s: spawns" % id)
		if h == null:
			continue
		var ended := [false]
		h.finished.connect(func() -> void: ended[0] = true)
		var shown := 0
		var by_itself := false
		for f in 180:
			_move(1.0 / 60.0)
			await process_frame
			total_frames += 1
			if f == 1 and h.is_playing():
				var lacking: Array = h.fx.warnings.keys().filter(func(w: String) -> bool:
					return w.begins_with("missing mesh:") and not w in MESHES_NOT_EXTRACTED)
				_expect(lacking.is_empty(), "%s: every mesh is in the library %s" % [id, lacking])
			if h.particle_count() > 0:
				shown += 1
			if not h.is_playing():
				by_itself = true
				break
		if shown == 0:
			quiet.append(id.get_file())
		if h.is_playing():
			looped.append(id.get_file())
			h.stop()
		var tail := 0
		while h.is_playing() and tail < 60 * 12:
			_move(1.0 / 60.0)
			await process_frame
			tail += 1
		_expect(not h.is_playing() and ended[0], "%s: ends (by itself %s, %d frames after stop)" % [id, by_itself, tail])
		_expect(player.playing_count() == 0, "%s: nothing left playing" % id)
	moving = false
	print("  effects %d, frames %d; ended by themselves %d; looping or immortal (stopped) %d: %s" % [ids.size(),
			total_frames, ids.size() - looped.size(), looped.size(), ", ".join(looped)])
	print("  no particle within 3 s (%d): %s" % [quiet.size(), ", ".join(quiet)])

	# ---- every emitter's material takes the same textures as in the browser (a library answering from the browser's
	# exported files, with placeholders, against the game's imported subset)
	var shared_lib := CascadeMaterials.shared()
	var probe := CascadeMaterials.new()
	probe.probe_root = "res://artifacts/spellbreak_fx/assets/"
	var compared := 0
	var with_tex := 0
	if DirAccess.dir_exists_absolute(probe.probe_root):
		for id: String in ids:
			for es: Dictionary in SpellFx.spec(id).emitters:
				if not es.enabled:
					continue
				var want := _textures_of(probe.material_for_emitter(es))
				var got := _textures_of(shared_lib.material_for_emitter(es))
				compared += 1
				with_tex += 1 if not want.is_empty() else 0
				_expect(want == got, "%s / %s: the browser's textures %s, here %s" % [id.get_file(), es.name, want, got])
	else:
		print("  (the browser's exports are not on this disk: texture comparison skipped)")
	print("  materials compared with the browser's %d (%d with textures); library: family %d, uber %d, no record %d" % [
			compared, with_tex, shared_lib.stats.family, shared_lib.stats.uber, shared_lib.stats.missing])

	_scalar(ids)

	if only == "":
		await _api(player)
		await _edges(player)
		await _perf(player)

	# ---- leaks
	player.kill_all()
	player.queue_free()
	await _frames(3)
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_expect(nodes == base_nodes, "node count back to the start once the player is freed (%d, was %d)" % [nodes, base_nodes])
	_expect(orphans == base_orphans, "no orphan nodes (%d, was %d)" % [orphans, base_orphans])
	print("  wall %.1f s" % ((Time.get_ticks_msec() - t_start) / 1000.0))
	if fails.is_empty():
		print("CASCADE RUNTIME TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		print("CASCADE RUNTIME TEST FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


func _api(player: SpellFx) -> void:
	const BALL := "g3/Content/VFX/Character/Fire/Fireball_Base_Projectile01_FxP"
	const HIT := "g3/Content/VFX/Character/Fire/Fire_Firefly_End01_FxP"
	# follow: the effect takes the node's place each frame (its scale stripped)
	var n := Node3D.new()
	root.add_child(n)
	n.global_transform = Transform3D(Basis().scaled(Vector3.ONE * 3.0), Vector3(1, 1, 1))
	var h: SpellFx.Handle = SpellFx.spawn(BALL, n)
	await _frames(2)
	n.global_position = Vector3(4, 1, -2)
	await _frames(1)
	_expect(h.fx.global_position.is_equal_approx(Vector3(4, 1, -2)), "follow: the effect is where its node is")
	_expect(is_equal_approx(h.fx.global_basis.get_scale().x, 1.0), "follow: the node's own scale is not taken")
	_expect(h.fx.get_parent() == player, "follow: the effect lives under the player, not the node")
	# offset + scale
	var h2: SpellFx.Handle = SpellFx.spawn(BALL, n, {"offset": Transform3D(Basis(), Vector3(0, 0.5, 0)), "scale": 2.0})
	await _frames(1)
	_expect(h2.fx.global_position.is_equal_approx(Vector3(4, 1.5, -2)), "offset: placed relative to the node")
	_expect(is_equal_approx(h2.fx.global_basis.get_scale().x, 2.0) and h2.fx.fx_scale == 2.0, "scale: basis and sizes x2")
	var e0 = h2.fx.emitters[1]
	if not e0.particles.is_empty():
		var p = e0.particles[0]
		var b2: Basis = e0._sprite_basis(p, Vector3.ZERO, cam)
		h2.fx.fx_scale = 1.0
		var b1: Basis = e0._sprite_basis(p, Vector3.ZERO, cam)
		h2.fx.fx_scale = 2.0
		_expect(is_equal_approx(b2.x.length(), 2.0 * b1.x.length()), "scale: a sprite twice as big")
	# tint: off by default, multiplies when given
	_expect(not h.fx.use_tint and h.fx.tinted(Color(0.5, 0.2, 0.1, 0.7)) == Color(0.5, 0.2, 0.1, 0.7), "tint: off by default")
	var h3: SpellFx.Handle = SpellFx.spawn(HIT, Vector3(0, 1, 0), {"tint": Color(0, 1, 0.5, 0.5)})
	_expect(h3.fx.use_tint and h3.fx.tinted(Color(1, 1, 1, 1)) == Color(0, 1, 0.5, 0.5), "tint: multiplies the colours")
	# kill: gone now; the handle after its end does nothing
	var killed := [false]
	h3.finished.connect(func() -> void: killed[0] = true)
	var hit_node := h3.fx
	h3.kill()
	_expect(not h3.is_playing() and killed[0] and h3.particle_count() == 0, "kill: gone at once, finished emitted")
	h3.stop()
	h3.kill()
	h3.restart()
	h3.set_transform(Transform3D())
	_expect(not h3.is_playing(), "a handle after its effect ended is inert")
	_expect(not hit_node.visible and hit_node.get_parent() == player, "kill: the node is parked in the pool, hidden")
	# pooled reuse: the next spawn of that effect takes the parked node
	var h4: SpellFx.Handle = SpellFx.spawn(HIT, Vector3(0, 1, 0))
	_expect(h4.fx == hit_node and hit_node.visible, "pool: the next spawn reuses the parked node")
	h4.kill()
	# stop: the looping projectile's trail plays out (kill-on-deactivate emitters clear at once, as in UE)
	await _frames(30)
	var before := h.particle_count()
	h.stop()
	await _frames(1)
	var after := h.particle_count()
	_expect(before > 0 and h.is_playing(), "stop: still playing the frame after (%d -> %d particles)" % [before, after])
	var waited := await _wait_ended(h)
	_expect(not h.is_playing(), "stop: the particles die out, then it ends (%d frames)" % waited)
	# a followed node freed mid-flight: the effect stops and plays out (not cut)
	var h5: SpellFx.Handle = SpellFx.spawn(BALL, n, {"offset": Transform3D(Basis(), Vector3(0, 0, 0))})
	h2.kill()
	await _frames(20)
	n.queue_free()
	await _frames(2)
	_expect(h5.stopping and (h5.is_playing() or h5.particle_count() == 0), "followed node freed: the effect stops")
	waited = await _wait_ended(h5)
	_expect(not h5.is_playing(), "followed node freed: it plays out and ends (%d frames)" % waited)
	# attach: a child of the node (local space)
	var holder := Node3D.new()
	root.add_child(holder)
	holder.global_position = Vector3(-2, 1, 0)
	var h6: SpellFx.Handle = SpellFx.spawn(BALL, holder, {"attach": true})
	await _frames(3)
	_expect(h6.fx.get_parent() == holder and h6.fx.global_position.is_equal_approx(Vector3(-2, 1, 0)), "attach: a child of the node")
	var att := h6.fx
	h6.kill()
	_expect(att.get_parent() == player, "attach: killed, the node goes back under the player")
	holder.queue_free()
	# life: a looping effect stopped after `life` seconds, then ends
	var h7: SpellFx.Handle = SpellFx.spawn(BALL, Vector3(0, 1, 0), {"life": 0.5})
	await _frames(32)
	_expect(h7.stopping or not h7.is_playing(), "life: stopped after 0.5 s")
	await _wait_ended(h7)
	_expect(not h7.is_playing(), "life: then it ends")
	# restart
	var h8: SpellFx.Handle = SpellFx.spawn(HIT, Vector3(0, 1, 0), {"one_shot": false})
	await _frames(240)
	_expect(h8.is_playing() and h8.particle_count() == 0, "one_shot off: kept after it finished")
	h8.restart()
	await _frames(5)
	_expect(h8.particle_count() > 0, "restart: plays again")
	h8.kill()
	# prewarm: builds, draws and parks one node per effect not pooled yet; the first spawn reuses it
	const WARM := ["g3/Content/VFX/Character/Wind/WindExplode_FX", "g3/Content/VFX/Character/Ice/Ice_Lance_Squib"]
	for id: String in WARM:
		for fx in player._idle.get(id, []):
			if is_instance_valid(fx):
				fx.free()
		player._idle.erase(id)
	var idle0 := player.idle_count()
	var seen: Array = []
	await SpellFx.prewarm(WARM, cam, func(f: float) -> void: seen.append(f))
	_expect(player.idle_count() == idle0 + WARM.size(), "prewarm: one parked node per effect (%d -> %d)" % [idle0, player.idle_count()])
	_expect(not seen.is_empty() and is_equal_approx(seen[seen.size() - 1], 1.0), "prewarm: progress reaches 1")
	var children := player.get_child_count()
	var h9: SpellFx.Handle = SpellFx.spawn(WARM[0], Vector3(0, 1, 0))
	_expect(player.get_child_count() == children and h9.fx.visible and not h9.fx.use_tint and h9.fx.fx_scale == 1.0,
			"prewarm: the first spawn reuses the warmed node, untinted, full size")
	h9.kill()
	_expect(SpellFx.spawn("g3/Content/NotAnEffect", Vector3.ZERO) == null, "an effect not imported: null")
	# attach, then the node freed while it plays: the effect goes with it, the handle ends, no error
	var carrier := Node3D.new()
	root.add_child(carrier)
	var h10: SpellFx.Handle = SpellFx.spawn(BALL, carrier, {"attach": true})
	var ended10 := [false]
	h10.finished.connect(func() -> void: ended10[0] = true)
	await _frames(5)
	carrier.queue_free()
	await _frames(3)
	_expect(not h10.is_playing() and ended10[0] and player.playing_count() == 0, "attach: node freed, the handle ends")
	h10.stop()
	h10.kill()
	# a spawn while the scene is still building (a child's _ready): the player joins at the end of the frame and the
	# effect starts as it enters the tree
	var building := Node3D.new()
	_expect(not building.is_node_ready(), "a scene not ready yet")
	var h11: SpellFx.Handle = SpellFx.spawn(HIT, Vector3(0, 1, 0), {"scene": building})
	var p11 := SpellFx.of(building)
	_expect(h11 != null and p11 != player and p11.playing_count() == 0, "spawn before the player is in the tree: pending")
	await _frames(1)
	root.add_child(building)
	await _frames(3)
	_expect(p11.is_inside_tree() and p11.playing_count() == 1 and h11.particle_count() > 0,
			"pending spawn: starts when the player enters the tree (%d particles)" % h11.particle_count())
	h11.kill()
	building.queue_free()
	await _frames(2)
	_expect(SpellFx.of(root) == player, "the scene's own player again after the other scene is gone")


## CascadeFx.s1 (no array) gives what sample()[0] gives, on every table of every spec, at the edges and between, with
## each random mode: the array stores a float32, so s1's double is rounded the same way before the comparison.
func _scalar(ids: Array) -> void:
	var tables := 0
	var bad: Array[String] = []
	for id: String in ids:
		for t: Dictionary in _tables(SpellFx.spec(id), []):
			tables += 1
			for time in [-1.0, 0.0, 0.13, 0.5, 0.97, 1.0, 3.5]:
				for rnd in [0.0, 0.3, 0.5, 0.7, 1.0]:
					var want := CascadeFx.sample(t, time, rnd)[0]
					var got := PackedFloat32Array([CascadeFx.s1(t, time, rnd)])[0]
					if want != got and not (is_nan(want) and is_nan(got)):
						bad.append("%s op %s n %s t %s r %s: %s vs %s" % [id.get_file(), t.op, t.n, time, rnd, want, got])
	for b in bad.slice(0, 5):
		print("    " + b)
	_expect(tables > 100 and bad.is_empty(), "s1 reads what sample()[0] reads: %d tables, %d differences" % [tables, bad.size()])
	_expect(CascadeFx.s1(null, 0.5, 0.5) == 0.0 and CascadeFx.s1({}, 0.5, 0.5) == 0.0 and CascadeFx.s1(3.0, 0.5, 0.5) == 0.0,
			"s1 of no table is 0")


## Every distribution table (FRawDistribution: v, n, stride, sub, op) found under `v`.
static func _tables(v: Variant, out: Array) -> Array:
	if v is Dictionary:
		var d := v as Dictionary
		if d.has("v") and d.has("n") and d.has("stride") and d.has("sub") and d.has("op"):
			out.append(d)
		else:
			for k in d:
				_tables(d[k], out)
	elif v is Array:
		for x in v:
			_tables(x, out)
	return out


## What the earlier reviews found on paths the other sections do not run.
func _edges(player: SpellFx) -> void:
	const BALL := "g3/Content/VFX/Character/Fire/Fireball_Base_Projectile01_FxP"
	const HIT := "g3/Content/VFX/Character/Fire/Fire_Firefly_End01_FxP"
	const WALL := "g3/Content/VFX/Character/Fire/FireWall_FX_TranslucentSmoke"
	var n0 := player.playing_count()
	# a handle killed by another's finished handler (the same pass) ends once
	var a: SpellFx.Handle = SpellFx.spawn(HIT, Vector3(0, 1, 0))
	var b: SpellFx.Handle = SpellFx.spawn(BALL, Vector3(2, 1, 0))
	var a_fin := [0]
	var b_fin := [0]
	a.finished.connect(func() -> void:
		a_fin[0] += 1
		b.kill())
	b.finished.connect(func() -> void: b_fin[0] += 1)
	await _wait_ended(a)
	await _frames(2)
	_expect(a_fin[0] == 1 and b_fin[0] == 1 and not b.is_playing(),
			"a handle killed by another's finished handler says finished once (%d, %d)" % [a_fin[0], b_fin[0]])
	# an attached effect whose node is taken out of the tree (not freed) ends, without stepping out of the tree
	var holder := Node3D.new()
	root.add_child(holder)
	var h: SpellFx.Handle = SpellFx.spawn(BALL, holder, {"attach": true})
	await _frames(2)
	_expect(h.is_playing() and h.fx.get_parent() == holder, "attach: playing under its node")
	var fx_node := h.fx
	root.remove_child(holder)
	await _frames(2)
	_expect(not h.is_playing() and player.playing_count() == n0 and fx_node.get_parent() == player and not fx_node.visible,
			"attach: the node taken out of the tree ends the effect (parked under the player)")
	holder.free()
	# the camera freed while a prewarm awaits: it finishes and every effect is parked
	var ids2: Array = ["g3/Content/VFX/Character/Fire/Fire_Firefly_End01_FxP", "g3/Content/VFX/Character/Ice/Ice_Lance_Squib",
			"g3/Content/VFX/Character/Wind/WindProj_FX", "g3/Content/VFX/Character/Vapor/VaporCloud_FX"]
	for id: String in ids2:
		for fx in player._idle.get(id, []):
			if is_instance_valid(fx):
				fx.free()
		player._idle.erase(id)
	var cam2 := Camera3D.new()
	root.add_child(cam2)
	await process_frame
	var idle0 := player.idle_count()
	var warm_done := [false]
	var runner := func() -> void:
		await SpellFx.prewarm(ids2, cam2, Callable(), 1)
		warm_done[0] = true
	runner.call()
	await process_frame
	cam2.free()
	var guard := 0
	while not warm_done[0] and guard < 600:
		await process_frame
		guard += 1
	_expect(warm_done[0] and player.idle_count() == idle0 + ids2.size(),
			"prewarm: the camera freed meanwhile, it finishes and parks every effect (%d -> %d)" % [idle0, player.idle_count()])
	# a stalled frame: one huge step feeds an effect at most MAX_STEP_S
	var hs: SpellFx.Handle = SpellFx.spawn(WALL, Vector3(0, 1, 0))
	await _frames(90)
	var before := hs.particle_count()
	var age0 := hs.age
	player._tick(hs, 30.0, cam)
	var after := hs.particle_count()
	_expect(hs.age - age0 <= SpellFx.MAX_STEP_S + 1e-6 and before > 0 and after < before * 3 + 30,
			"a 30 s stall steps an effect %.2f s at most (%d -> %d particles)" % [SpellFx.MAX_STEP_S, before, after])
	# the MultiMesh: allocated ahead (a power of two, 16 at least) and only grown; visible_instance_count is what is drawn
	var drawn_emitters := 0
	var buffers_ok := true
	for e in hs.fx.emitters:
		if e.mm_inst == null or e.s.render_mode == "ERM_None" or e.s.render_mode == "ERM_LightsOnly" or int(e.s.max_draw) > 0:
			continue
		var mm: MultiMesh = e.mm_inst.multimesh
		drawn_emitters += 1
		var cap := mm.instance_count
		if mm.visible_instance_count != e.particles.size() or cap < mm.visible_instance_count \
				or (cap > 0 and (cap < 16 or cap != CascadeFx.Emitter.nextpow2(cap))):
			buffers_ok = false
			print("    emitter %s: %d particles, visible %d of %d" % [e.s.name, e.particles.size(), mm.visible_instance_count, cap])
	_expect(drawn_emitters > 0 and buffers_ok, "MultiMesh: visible_instance_count is the particle count, the buffer a power of two (%d emitters)" % drawn_emitters)
	hs.kill()
	# the pool's counts and the existence cache
	var parked: Array = player._idle.get(HIT, [])
	_expect(not parked.is_empty(), "an effect is parked for the idle count")
	if not parked.is_empty():
		var c0 := player.idle_count()
		(parked[0] as Node).free()
		_expect(player.idle_count() == c0 - 1, "idle_count leaves out a freed node (%d -> %d)" % [c0, player.idle_count()])
	_expect(SpellFx.has_effect(BALL) and not SpellFx.has_effect("g3/Content/NotAnEffect") and SpellFx._present.has("g3/Content/NotAnEffect")
			and not SpellFx.has_effect("g3/Content/NotAnEffect"), "has_effect answers from its cache the second time")
	SpellFx.forget_cache()
	_expect(SpellFx._present.is_empty() and not SpellFx.spec(BALL).is_empty() and SpellFx.catalogue().size() >= wired_ids().size(),
			"forget_cache empties what was read; the next ask reads it again")


func _perf(player: SpellFx) -> void:
	var handles: Array = []
	moving = true
	move_t = 0.0
	for i in PERF_SET.size():
		handles.append(SpellFx.spawn(PERF_SET[i], _perf_at(i)))
	var times: Array[float] = []
	var parts := 0
	for f in 300:
		_move(1.0 / 60.0)
		await process_frame
		if f >= 30:
			times.append(player.last_step_usec / 1000.0)
			parts += _particles(player)
		for i in handles.size():
			if not (handles[i] as SpellFx.Handle).is_playing():   # one-shots: replay so 8 always play
				handles[i] = SpellFx.spawn(PERF_SET[i], _perf_at(i))
	moving = false
	var st := _stats(times)
	print("PERF cascade 8 effects at once: %.2f ms/frame avg, p95 %.2f, max %.2f (SpellFx step, CPU, headless), %d particles avg" % [
			st.avg, st.p95, st.max, parts / maxi(times.size(), 1)])
	_expect(st.avg < 16.0, "perf: 8 effects step in under a 60 fps frame on average (%.2f ms)" % st.avg)
	for h: SpellFx.Handle in handles:
		h.kill()


## Where PERF_SET[i] plays: the first follows the mover, the rest stand along a row.
func _perf_at(i: int) -> Variant:
	return mover if i == 0 else Transform3D(Basis(), Vector3(-7.0 + 2.0 * i, 1.2, -3.0))


## Frames until `h` is no longer playing (at most `max_frames`).
func _wait_ended(h: SpellFx.Handle, max_frames := 600) -> int:
	var n := 0
	while h.is_playing() and n < max_frames:
		await process_frame
		n += 1
	return n


## avg, p95 and max of the samples (sorted in place).
static func _stats(a: Array[float]) -> Dictionary:
	a.sort()
	var sum := 0.0
	for t in a:
		sum += t
	return {"avg": sum / maxf(a.size(), 1), "p95": a[int(a.size() * 0.95)] if not a.is_empty() else 0.0,
			"max": a[a.size() - 1] if not a.is_empty() else 0.0}


## A material's texture uniforms (sampler2D in its code) -> the source package each holds ("" = none).
static func _textures_of(m: ShaderMaterial) -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string("uniform\\s+sampler2D\\s+(\\w+)")
	for r in re.search_all(m.shader.code):
		var u := r.get_string(1)
		var t = m.get_shader_parameter(u)
		if t is Texture2D:
			out[u] = String((t as Texture2D).get_meta(&"cascade_pkg", "?"))
	return out


func _particles(player: SpellFx) -> int:
	var n := 0
	for h: SpellFx.Handle in player._active:
		n += h.particle_count()
	return n
