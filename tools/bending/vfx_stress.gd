extends SceneTree
## The bent elements' effects under load (BendLooks, ToonFxPool): on the Tidebreak deck, two casters 12 m apart fire a bolt
## of a random kind at each other every 0.1 s each (they meet, land on the deck, burst), a zone goes up every 1.5 s, a
## lightning stroke every 2 s, a blast every 1 s, for `secs` s; before that the same view with nothing cast. Frame times
## (avg, p95, max) of both, the pool's node count and the scene's at the end. Round 4 (LOOKS): at the load's worst moment
## too, its draw calls and its live GPU particles (every emitting GPUParticles3D's amount x amount_ratio), and the most of
## each over the load ("VFX STRESS worst ..."). Windowed (it draws), vsync off:
##   Godot --path . -s tools/bending/vfx_stress.gd [-- secs=10]

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const KINDS := ["fire", "water", "ice", "air", "stone"]
const ZONES := ["fire_wall", "tornado", "bubble", "water_wall", "air_shield", "burn"]

var _ms: Array[float] = []
## The load's worst frame: [ms, draw calls, GPU particles], and the most draws and particles seen.
var _worst := [0.0, 0, 0]
var _most := [0, 0]


func _initialize() -> void:
	var secs := 10.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("secs="):
			secs = float(a.substr(5))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	await process_frame
	await process_frame
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(1600, 900))
	root.disable_3d = true
	view.camera.fov = 60.0
	view.camera.global_transform = Transform3D(Basis.looking_at(Vector3(0, 1, 0) - Vector3(0, 5, 14), Vector3.UP), Vector3(0, 5, 14))
	for i in 120:
		await process_frame
	var bl = BendLooks.new()
	if bl.has_method(&"warm_up") and not "warm=0" in OS.get_cmdline_user_args():
		var t0 := Time.get_ticks_msec()
		bl.call(&"warm_up", view.camera)
		for i in 12:
			await process_frame
		print("VFX STRESS warm_up %d ms (12 frames)" % (Time.get_ticks_msec() - t0))
		for i in 120:
			await process_frame
	var base := await _measure(4.0, false)
	var load := await _measure(secs, true)
	var pool := current_scene.get_node_or_null("ToonFxPool")
	print("VFX STRESS idle avg=%.2f p95=%.2f max=%.2f ms" % base)
	print("VFX STRESS load avg=%.2f p95=%.2f max=%.2f ms" % load)
	print("VFX STRESS worst frame_ms=%.2f draws=%d particles=%d | most draws=%d particles=%d" % [_worst[0], _worst[1],
			_worst[2], _most[0], _most[1]])
	print("VFX STRESS pool_nodes=%d scene_nodes=%d bolts_live=%d" % [pool.get_child_count() if pool else -1,
			_count(current_scene), get_nodes_in_group(BendBolt.GROUP).size()])
	quit()


## Pipelines compiled so far (mesh, surface, draw, specialization: RenderingServer's counters).
func _pipelines() -> Vector4i:
	return Vector4i(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION))


## The GPU particles live now under `n`: every emitting GPUParticles3D's amount x amount_ratio.
func _particles(n: Node) -> int:
	var c := 0
	if n is GPUParticles3D and (n as GPUParticles3D).emitting and (n as GPUParticles3D).is_visible_in_tree():
		c += int((n as GPUParticles3D).amount * (n as GPUParticles3D).amount_ratio)
	for k in n.get_children():
		c += _particles(k)
	return c


func _count(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += _count(k)
	return c


func _measure(secs: float, cast: bool) -> Array:
	var a := Node3D.new()
	var b := Node3D.new()
	current_scene.add_child(a)
	current_scene.add_child(b)
	a.global_position = Vector3(-6, 1.3, -1)
	b.global_position = Vector3(6, 1.3, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var times: Array[float] = []
	var t := 0.0
	var nb := 0.0
	var nz := 0.0
	var nl := 0.0
	var nx := 0.0
	var last := Time.get_ticks_usec()
	var ev := ""
	var pipes := _pipelines()
	while t < secs:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000.0
		last = now
		times.append(dt)
		if cast and t > secs * 0.2:
			var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			var np := _particles(current_scene)
			_most = [maxi(_most[0], dc), maxi(_most[1], np)]
			if dt > float(_worst[0]):
				_worst = [dt, dc, np]
		var pc := _pipelines()
		if dt > 100.0:
			print("VFX STRESS slow %.0f ms after: %s  pipelines +%s" % [dt, ev, str(pc - pipes)])
		pipes = pc
		ev = ""
		t += dt / 1000.0
		if not cast:
			continue
		if t >= nb:
			nb += 0.1
			for pair in [[a, b], [b, a]]:
				var from: Node3D = pair[0]
				var to: Node3D = pair[1]
				var k: String = KINDS[rng.randi() % KINDS.size()]
				var dir := (to.global_position - from.global_position).normalized()
				dir = dir.rotated(Vector3.UP, rng.randf_range(-0.15, 0.15)) + Vector3.DOWN * rng.randf_range(0.0, 0.12)
				BendBolt.launch(from, from.global_position, dir, {"kind": k, "mps": 30.0, "radius_m": rng.randf_range(0.1, 0.5),
						"range_m": 20.0, "long": rng.randf() < 0.2})
		if t >= nz:
			nz += 1.5
			var z: String = ZONES[rng.randi() % ZONES.size()]
			ev += " zone:" + z
			var at := Vector3(rng.randf_range(-4, 4), 0.0, rng.randf_range(-3, 3))
			var o := a if rng.randf() < 0.5 else b
			BendZone.make(o, z, at if z not in ["bubble", "air_shield"] else o.global_position - Vector3.UP * 1.3,
					{"width_m": 4.0, "height_m": 2.0, "thick_m": 0.6, "radius_m": 1.8, "life_s": 3.0, "mps": 0.0}, Vector3.FORWARD)
		if t >= nl:
			nl += 2.0
			ev += " lightning"
			BendLooks.lightning(a.global_position, b.global_position + Vector3(0, -1.2, 0))
		if t >= nx:
			nx += 1.0
			ev += " blast"
			BendLooks.blast(a.global_position, Vector3.RIGHT, 360.0 if rng.randf() < 0.5 else 70.0, 5.0,
					KINDS[rng.randi() % KINDS.size()])
	a.queue_free()
	b.queue_free()
	var slow := []
	var acc := 0.0
	for i in times.size():
		acc += times[i]
		if times[i] > 100.0:
			slow.append("%.0fms@%.1fs" % [times[i], acc / 1000.0])
	print("VFX STRESS frames=%d slow=%s" % [times.size(), str(slow.slice(0, 12))])
	if times.size() > 60:
		times = times.slice(times.size() / 5)        # (the first fifth left out: what compiles once)
	times.sort()
	var avg := 0.0
	for x in times:
		avg += x
	avg /= maxf(times.size(), 1)
	return [avg, times[int(times.size() * 0.95)], times[times.size() - 1]]
