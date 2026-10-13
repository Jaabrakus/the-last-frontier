extends SceneTree
## Review round 2 probe (read-only): what SpellFx's step costs as the number of effects playing at once climbs to
## config.json's max_playing (40), CPU only (headless is right: the step is GDScript). Prints ms per frame (avg / p95) and the
## live particle count per level; also the share of one frame at 60 fps.
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/fx/review_r2_load.gd

const SET := [
	"g3/Content/VFX/Character/Fire/Fireball_Base_Projectile01_FxP",
	"g3/Content/VFX/Character/Fire/Fire_Firefly_End01_FxP",
	"g3/Content/VFX/Character/Earth/EarthImpactAOE_FX_Meteor",
	"g3/Content/VFX/Cosmetics/CloudBurst/RiversReflection/CB_RiversReflection_FxP",
	"g3/Content/VFX/Character/Wind/WindProj_FX",
	"g3/Content/Quests/Shared/SmkObscureM_FxP",
	"g3/Content/VFX/Character/Vapor/VaporCloud_FX",
	"g3/Content/VFX/Character/Wind/WindExplode_FX",
]

var stage: Node3D
var cam: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	cam = Camera3D.new()
	stage.add_child(cam)
	cam.global_position = Vector3(0, 3, 10)
	cam.current = true
	for i in 3:
		await process_frame
	var ids: Array = []
	for id in SET:
		if SpellFx.has_effect(id):
			ids.append(id)
		else:
			print("  (not imported: %s)" % id)
	await SpellFx.prewarm(ids, cam, Callable(), 8)
	var player := SpellFx.of(stage)
	print("REVIEW load: %d distinct effects" % ids.size())
	for n in [1, 8, 16, 24, 40]:
		player.kill_all()
		for i in 3:
			await process_frame
		for i in n:
			SpellFx.spawn(ids[i % ids.size()], Vector3(float(i % 8) - 4.0, 1.0, -float(i / 8)), {"scene": stage, "one_shot": false})
		for i in 20:
			await process_frame
		var us: Array = []
		var parts := 0
		for i in 120:
			await process_frame
			us.append(player.last_step_usec)
			var pc := 0
			for h in player._active:
				pc += h.particle_count()
			parts += pc
		us.sort()
		var avg := 0.0
		for u in us:
			avg += float(u)
		avg /= float(us.size())
		print("  %2d playing: step %.2f ms avg, p95 %.2f ms, %d particles avg  (%.0f %% of a 60 fps frame; %.2f ms per effect)" % [
				n, avg / 1000.0, float(us[int(us.size() * 0.95)]) / 1000.0, parts / 120, avg / 16667.0 * 100.0, avg / 1000.0 / float(n)])
	# where the step goes at 40 playing: the same calls CascadeFx.step makes, each timed (tick = update + spawn, render)
	player.kill_all()
	for i in 3:
		await process_frame
	for i in 40:
		SpellFx.spawn(ids[i % ids.size()], Vector3(float(i % 8) - 4.0, 1.0, -float(i / 8)), {"scene": stage, "one_shot": false})
	for i in 30:
		await process_frame
	player.set_process(false)
	var t_tick := 0
	var t_cons := 0
	var t_rend := 0
	var n_part := 0
	var frames := 100
	for f in frames:
		await process_frame
		for h in player._active:
			var fx: CascadeFx = h.fx
			var here := fx.global_position
			var ne := {}
			var t0 := Time.get_ticks_usec()
			for e in fx.emitters:
				if not e.hidden:
					e.tick(1.0 / 60.0, ne)
			var t1 := Time.get_ticks_usec()
			for e in fx.emitters:
				if not e.hidden:
					e.consume_events(ne)
			var t2 := Time.get_ticks_usec()
			for e in fx.emitters:
				if not e.hidden:
					e.render()
			var t3 := Time.get_ticks_usec()
			t_tick += t1 - t0
			t_cons += t2 - t1
			t_rend += t3 - t2
			n_part += fx.particle_count()
	print("  split at 40 playing, per frame: tick %.2f ms, consume %.2f ms, render %.2f ms; %d particles avg -> tick %.1f us, render %.1f us per particle" % [
			t_tick / 1000.0 / frames, t_cons / 1000.0 / frames, t_rend / 1000.0 / frames, n_part / frames,
			float(t_tick) / float(n_part), float(t_rend) / float(n_part)])
	player.set_process(true)
	player.kill_all()
	for i in 3:
		await process_frame
	# FX_LightningCharge held (the lightning's lock holds it): particles and step cost as the hold goes on
	var hc := SpellFx.spawn("g3/Content/VFX/Character/FX_LightningCharge", Vector3(0, 1, -2), {"scene": stage, "one_shot": false})
	var secs := 0
	for f in 60 * 10:
		await process_frame
		if (f + 1) % 120 == 0:
			secs = (f + 1) / 60
			print("  FX_LightningCharge held %2d s: %4d particles, step %.2f ms" % [secs, hc.particle_count(), player.last_step_usec / 1000.0])
	hc.stop()
	await process_frame
	print("  after stop(): %d particles" % hc.particle_count())
	hc.kill()
	quit(0)
