extends SceneTree
## Review round 2 probe (read-only on the game): what is left of the Cascade step's CPU after round 1, and what a typed table
## would save. Times, per call, on real tables of the fireball projectile and a smoke effect:
##   CascadeFx.s1 (Dictionary table, Array of boxed floats)   vs   the same arithmetic on a PackedFloat32Array table
##   Emitter.comp() (sys.global_transform each call)           vs   a Transform3D held in a local
##   Emitter.one(cls) / all(cls) as _spawn_one calls them     vs   a member read
##   MultiMesh per-particle writes: 3 calls per instance      vs   one set_buffer for the whole list
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/fx/review_r2_lut.gd

const N := 200000
const IDS := ["g3/Content/VFX/Character/Fire/Fireball_Base_Projectile01_FxP",
	"g3/Content/VFX/Character/Fire/FireWall_FX_TranslucentSmoke"]


class Lut:
	var v := PackedFloat32Array()
	var n := 0
	var stride := 0
	var sub := 0
	var op := 0
	var tb := 0.0
	var ts := 0.0


static func lut_of(t: Dictionary) -> Lut:
	var l := Lut.new()
	l.v = PackedFloat32Array(t.v)
	l.n = int(t.n)
	l.stride = int(t.stride)
	l.sub = int(t.sub)
	l.op = int(t.op)
	l.tb = float(t.tb)
	l.ts = float(t.ts)
	return l


static func s1p(l: Lut, time: float, rnd: float) -> float:
	if l == null or l.sub < 1:
		return 0.0
	var i0 := 0
	var i1 := 0
	var f := 0.0
	if l.n > 1:
		var x := clampf((time - l.tb) * l.ts, 0.0, float(l.n - 1))
		i0 = int(floor(x))
		i1 = mini(i0 + 1, l.n - 1)
		f = x - float(i0)
	if i1 * l.stride >= l.v.size():
		return 0.0
	var a0: float = lerpf(l.v[i0 * l.stride], l.v[i1 * l.stride], f)
	if (l.op == 2 or l.op == 3) and i1 * l.stride + l.sub < l.v.size():
		var b0: float = lerpf(l.v[i0 * l.stride + l.sub], l.v[i1 * l.stride + l.sub], f)
		a0 = lerpf(a0, b0, rnd) if l.op == 2 else (b0 if rnd > 0.5 else a0)
	return a0


static func tables(v: Variant, out: Array) -> Array:
	if v is Dictionary:
		var d := v as Dictionary
		if d.has("v") and d.has("n") and d.has("stride") and d.has("sub") and d.has("op"):
			out.append(d)
		else:
			for k in d:
				tables(d[k], out)
	elif v is Array:
		for x in v:
			tables(x, out)
	return out


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(0, 3, 9)
	cam.current = true
	await process_frame
	var player := SpellFx.of(root)
	player.set_process(false)
	for id: String in IDS:
		var tabs := tables(SpellFx.spec(id), [])
		# the multi-sample tables (the ones with real data), up to 12
		var picked: Array = []
		for t: Dictionary in tabs:
			if int(t.n) > 1 and picked.size() < 12:
				picked.append(t)
		var luts: Array = picked.map(func(t: Dictionary) -> Lut: return lut_of(t))
		var t0 := Time.get_ticks_usec()
		var acc := 0.0
		for i in N:
			acc += CascadeFx.s1(picked[i % picked.size()], float(i % 100) * 0.01, 0.37)
		var us_dict := float(Time.get_ticks_usec() - t0) / N
		t0 = Time.get_ticks_usec()
		var acc2 := 0.0
		for i in N:
			acc2 += s1p(luts[i % luts.size()], float(i % 100) * 0.01, 0.37)
		var us_pack := float(Time.get_ticks_usec() - t0) / N
		t0 = Time.get_ticks_usec()
		for i in N:
			acc += CascadeFx.sample(picked[i % picked.size()], float(i % 100) * 0.01, 0.37)[0]
		var us_sample := float(Time.get_ticks_usec() - t0) / N
		print("REVIEW r2 %s: %d tables (%d multi-sample)  s1 dict %.3f us   s1 packed %.3f us (%.0f %% of it)   sample() %.3f us   [sums %.3f %.3f]" % [
				id.get_file(), tabs.size(), picked.size(), us_dict, us_pack, 100.0 * us_pack / us_dict, us_sample, acc, acc2])

	# comp() and the member reads on a real emitter
	var h := SpellFx.spawn(IDS[0], Transform3D(Basis(), Vector3(0, 1.2, 0)), {"one_shot": false})
	var fx: CascadeFx = h.fx
	fx.camera = cam
	for i in 40:
		await process_frame
		fx.step(1.0 / 60.0)
	var em = null
	for e in fx.emitters:
		if not e.particles.is_empty():
			em = e
			break
	if em == null:
		print("REVIEW r2: no emitter with particles")
		quit(1)
		return
	var p = em.particles[0]
	var t0 := Time.get_ticks_usec()
	for i in N:
		em.comp()
	var us_comp := float(Time.get_ticks_usec() - t0) / N
	t0 = Time.get_ticks_usec()
	var held: Transform3D = em.comp()
	for i in N:
		var x := held
		x = x
	var us_held := float(Time.get_ticks_usec() - t0) / N
	t0 = Time.get_ticks_usec()
	for i in N:
		em.world_pos(p)
	var us_wp := float(Time.get_ticks_usec() - t0) / N
	t0 = Time.get_ticks_usec()
	for i in N:
		em.world_vel(p)
	var us_wv := float(Time.get_ticks_usec() - t0) / N
	t0 = Time.get_ticks_usec()
	for i in N:
		em.one("Lifetime")
	var us_one := float(Time.get_ticks_usec() - t0) / N
	t0 = Time.get_ticks_usec()
	for i in N:
		em.all("LocationEmitter") + em.all("LocationEmitterDirect")
	var us_two := float(Time.get_ticks_usec() - t0) / N
	t0 = Time.get_ticks_usec()
	for i in N:
		em._rate_or_bursts()
	var us_rb := float(Time.get_ticks_usec() - t0) / N
	print("REVIEW r2 emitter '%s' (%s): comp() %.3f us (a held Transform3D copy %.3f)  world_pos %.3f  world_vel %.3f  one() %.3f  all()+all() %.3f  _rate_or_bursts() %.3f us" % [
			em.s.get("name", "?"), em.s.type, us_comp, us_held, us_wp, us_wv, us_one, us_two, us_rb])

	# the whole of one spawn, on the busiest sprite emitter of the smoke effect
	var h2 := SpellFx.spawn(IDS[1], Transform3D(Basis(), Vector3(0, 1.2, 0)), {"one_shot": false})
	h2.fx.camera = cam
	for i in 60:
		await process_frame
		h2.fx.step(1.0 / 60.0)
	var best = null
	for e in h2.fx.emitters:
		if e.s.type == "sprite" and (best == null or e.particles.size() > best.particles.size()):
			best = e
	if best != null:
		var M := 20000
		t0 = Time.get_ticks_usec()
		for i in M:
			best._spawn_one(Vector3(0, 1, 0), 0.0, {})
			if best.particles.size() > 64:
				best.particles.clear()
		var us_spawn := float(Time.get_ticks_usec() - t0) / M
		print("REVIEW r2 _spawn_one on '%s' (%d mods): %.2f us a spawn (17 one()/all() lookups at ~%.2f us = %.1f us of it)" % [
				best.s.get("name", "?"), best.mods.size(), us_spawn, us_one, 17.0 * us_one])
	h2.kill()
	# MultiMesh writes: 3 calls an instance against one buffer
	var n := 200
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = QuadMesh.new()
	mm.instance_count = 256
	mm.visible_instance_count = n
	var xf := Transform3D(Basis(), Vector3(1, 2, 3))
	var reps := 400
	t0 = Time.get_ticks_usec()
	for r in reps:
		for i in n:
			mm.set_instance_transform(i, xf)
			mm.set_instance_color(i, Color(1, 0.5, 0.2, 0.8))
			mm.set_instance_custom_data(i, Color(1, 1, 1, 1))
	var us_three := float(Time.get_ticks_usec() - t0) / reps
	var buf := PackedFloat32Array()
	buf.resize(256 * 20)
	t0 = Time.get_ticks_usec()
	for r in reps:
		for i in n:
			var o := i * 20
			buf[o] = xf.basis.x.x
			buf[o + 1] = xf.basis.y.x
			buf[o + 2] = xf.basis.z.x
			buf[o + 3] = xf.origin.x
			buf[o + 4] = xf.basis.x.y
			buf[o + 5] = xf.basis.y.y
			buf[o + 6] = xf.basis.z.y
			buf[o + 7] = xf.origin.y
			buf[o + 8] = xf.basis.x.z
			buf[o + 9] = xf.basis.y.z
			buf[o + 10] = xf.basis.z.z
			buf[o + 11] = xf.origin.z
			buf[o + 12] = 1.0
			buf[o + 13] = 0.5
			buf[o + 14] = 0.2
			buf[o + 15] = 0.8
			buf[o + 16] = 1.0
			buf[o + 17] = 1.0
			buf[o + 18] = 1.0
			buf[o + 19] = 1.0
		mm.buffer = buf
	var us_buf := float(Time.get_ticks_usec() - t0) / reps
	print("REVIEW r2 MultiMesh, %d instances: set_instance_transform/color/custom_data %.1f us  vs  20 float stores + buffer = %.1f us (%.0f %%)" % [
			n, us_three, us_buf, 100.0 * us_buf / us_three])
	h.kill()
	quit(0)
