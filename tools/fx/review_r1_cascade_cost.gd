extends SceneTree
## Review round 1 probe (read-only): where the Cascade runtime's CPU time goes (the test's PERF set: 8 effects at once).
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/fx/review_r1_cascade_cost.gd
## Splits a frame into tick (spawn + update), consume_events and render by stepping the effects by hand, then times the
## per-particle update and the allocation-heavy helpers it calls (Emitter.all / one / CascadeFx.sample).

const PERF_SET := [
	"g3/Content/VFX/Character/Fire/Fireball_Base_Projectile01_FxP",
	"g3/Content/VFX/Character/Fire/Fireball_Base_Impact01_FxP",
	"g3/Content/VFX/Character/Earth/EarthImpactAOE_FX_Meteor",
	"g3/Content/VFX/Cosmetics/CloudBurst/RiversReflection/CB_RiversReflection_FxP",
	"g3/Content/VFX/Character/Wind/WindProj_FX",
	"g3/Content/Blueprints/Weapons/v3/FX/P_Frozen_Explosion",
	"g3/Content/VFX/Character/Wind/TornadoNewSimple",
	"g3/Content/VFX/Character/Fire/FireWall_FX_TranslucentSmoke",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(0, 3, 9)
	cam.look_at(Vector3(0, 1.2, 0), Vector3.UP)
	cam.current = true
	var mover := Node3D.new()
	root.add_child(mover)
	await process_frame
	var player := SpellFx.of(root)
	player.set_process(false)                       # stepped by hand below
	var fxs: Array[CascadeFx] = []
	for i in PERF_SET.size():
		var h := SpellFx.spawn(PERF_SET[i], Transform3D(Basis(), Vector3(-7.0 + 2.0 * i, 1.2, -3.0)), {"one_shot": false})
		fxs.append(h.fx)
	var t_tick := 0.0
	var t_cons := 0.0
	var t_rend := 0.0
	var frames := 0
	var parts := 0
	for f in 300:
		await process_frame
		var dt := 1.0 / 60.0
		for fx in fxs:
			fx.camera = cam
			var t0 := Time.get_ticks_usec()
			var ev := {}
			var here := fx.global_position
			for e in fx.emitters:
				e.tick(dt, ev)
			var t1 := Time.get_ticks_usec()
			for e in fx.emitters:
				e.consume_events(ev)
			var t2 := Time.get_ticks_usec()
			for e in fx.emitters:
				e.render()
			var t3 := Time.get_ticks_usec()
			if f >= 60:
				t_tick += t1 - t0
				t_cons += t2 - t1
				t_rend += t3 - t2
		if f >= 60:
			frames += 1
			for fx in fxs:
				parts += fx.particle_count()
		# keep one-shots alive: replay finished ones
		for fx in fxs:
			if fx.is_finished():
				fx.activate()
	print("REVIEW cascade cost, 8 effects, %d frames, %d particles avg" % [frames, parts / maxi(frames, 1)])
	print("  per frame: tick (spawn+update) %.2f ms, consume_events %.2f ms, render %.2f ms; total %.2f ms" % [
			t_tick / frames / 1000.0, t_cons / frames / 1000.0, t_rend / frames / 1000.0, (t_tick + t_cons + t_rend) / frames / 1000.0])

	# one emitter with live particles: per-particle update, and the helpers it leans on
	var em = null
	var pp = null
	for fx in fxs:
		for e in fx.emitters:
			if e.particles.size() > 3 and e.s.type == "sprite":
				em = e
				pp = e.particles[0]
				break
		if em != null:
			break
	if em == null:
		print("  (no sprite emitter with particles)")
		quit(0)
		return
	var N := 200000
	var t0 := Time.get_ticks_usec()
	for i in N:
		em._update_one(pp, 0.0, {})
	var us_upd := float(Time.get_ticks_usec() - t0) / N
	t0 = Time.get_ticks_usec()
	for i in N:
		em.all("ColorOverLife")
	var us_all_absent := float(Time.get_ticks_usec() - t0) / N
	var present := ""
	for cls in em.mods:
		present = cls
		break
	t0 = Time.get_ticks_usec()
	for i in N:
		em.all(present)
	var us_all_present := float(Time.get_ticks_usec() - t0) / N
	t0 = Time.get_ticks_usec()
	for i in N:
		var a: Array = []
		a = a
	var us_lit := float(Time.get_ticks_usec() - t0) / N
	var tab := {"v": [0.0, 1.0], "n": 2, "stride": 1, "sub": 1, "op": 1, "tb": 0.0, "ts": 1.0}
	t0 = Time.get_ticks_usec()
	for i in N:
		CascadeFx.sample(tab, 0.5, 0.5)
	var us_sample := float(Time.get_ticks_usec() - t0) / N
	print("  emitter '%s' (%d mods: %s...)" % [em.s.get("name", "?"), em.mods.size(), ", ".join(PackedStringArray(em.mods.keys()).slice(0, 6))])
	print("  _update_one per particle: %.2f us" % us_upd)
	print("  Emitter.all(absent class): %.3f us ; all(present class '%s'): %.3f us ; an empty [] literal: %.3f us" % [us_all_absent, present, us_all_present, us_lit])
	print("  CascadeFx.sample(): %.3f us" % us_sample)
	print("  _update_one calls all()/one() 18 times: %.2f us of its %.2f us (%.0f %%)" % [18.0 * us_all_absent, us_upd, 100.0 * 18.0 * us_all_absent / maxf(us_upd, 1e-6)])
	quit(0)
