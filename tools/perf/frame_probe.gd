extends SceneTree
## Where a frame goes, on the real level in a window (user 2026-10-01: "lets check our game, i do know it is unoptimized"): after a
## warm-up, a few seconds of samples of the frame (CPU process and physics, the GPU's render time), the draw calls and primitives,
## and the nodes that run every frame by their script (or class), most first.
##   Godot --path . -s tools/perf/frame_probe.gd -- survival=on wildlife=on [warm=12] [secs=8]

var warm := 12.0
var secs := 8.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("warm="):
			warm = float(s.get_slice("=", 1))
		elif s.begins_with("secs="):
			secs = float(s.get_slice("=", 1))
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	var vp := root.get_viewport_rid()
	if "timeline" in OS.get_cmdline_user_args():
		await timeline(secs)
		quit()
		return
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var w0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - w0 < int(warm * 1000.0):
		await process_frame
	var n := 0
	var sum := {"fps": 0.0, "process_ms": 0.0, "physics_ms": 0.0, "gpu_ms": 0.0, "cpu_render_ms": 0.0, "draws": 0.0, "prims": 0.0}
	var worst := 0.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await process_frame
		n += 1
		sum.fps += Performance.get_monitor(Performance.TIME_FPS)
		var pm := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		sum.process_ms += pm
		worst = maxf(worst, pm)
		sum.physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		sum.gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		sum.cpu_render_ms += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		sum.draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		sum.prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	for k in sum:
		sum[k] = sum[k] / maxf(n, 1)
	print("PROBE frames %d over %.1f s" % [n, secs])
	print("PROBE fps %.1f  process %.2f ms (worst %.1f)  physics %.2f ms  gpu %.2f ms  render-cpu %.2f ms" % [sum.fps, sum.process_ms, worst, sum.physics_ms, sum.gpu_ms, sum.cpu_render_ms])
	print("PROBE draw calls %d  primitives %d  nodes %d  objects %d" % [int(sum.draws), int(sum.prims), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT))])
	# who runs every frame
	var proc := {}
	var phys := {}
	_count(root, proc, phys)
	print("PROBE per-frame _process nodes (top 25):")
	_top(proc, 25)
	print("PROBE per-tick _physics_process nodes (top 25):")
	_top(phys, 25)
	var lights := 0
	var shadowed := 0
	for l in root.find_children("*", "Light3D", true, false):
		if (l as Light3D).is_visible_in_tree():
			lights += 1
			if (l as Light3D).shadow_enabled:
				shadowed += 1
	print("PROBE lights visible %d (with shadows %d)  skeletons %d  animation trees %d  gpu particles %d" % [lights, shadowed,
			root.find_children("*", "Skeleton3D", true, false).size(), root.find_children("*", "AnimationTree", true, false).size(),
			root.find_children("*", "GPUParticles3D", true, false).size()])
	if "bisect" in OS.get_cmdline_user_args():
		await bisect()
	if "byscript" in OS.get_cmdline_user_args():
		await byscript()
	if "groups" in OS.get_cmdline_user_args():
		await groups()
	if "cost" in OS.get_cmdline_user_args():
		await cost()
	if "mixers" in OS.get_cmdline_user_args():
		await mixers()
	quit()


func _count(n: Node, proc: Dictionary, phys: Dictionary) -> void:
	if n.can_process():
		var key := n.get_class()
		var sc := n.get_script() as Script
		if sc != null and sc.resource_path != "":
			key = sc.resource_path.get_file()
		if n.is_processing():
			proc[key] = int(proc.get(key, 0)) + 1
		if n.is_physics_processing():
			phys[key] = int(phys.get(key, 0)) + 1
	for c in n.get_children():
		_count(c, proc, phys)


func _top(d: Dictionary, k: int) -> void:
	var keys := d.keys()
	keys.sort_custom(func(a, b) -> bool: return int(d[a]) > int(d[b]))
	var total := 0
	for key in keys:
		total += int(d[key])
	print("PROBE   total %d" % total)
	for i in mini(k, keys.size()):
		print("PROBE   %5d  %s" % [int(d[keys[i]]), keys[i]])


## bisect: each node that processes switched off in turn for a second; what the frame's process time drops by.
func bisect() -> void:
	var nodes: Array = []
	_gather(root, nodes)
	var base := await _avg_process(60)
	print("PROBE bisect base %.2f ms" % base)
	var rows := []
	for n: Node in nodes:
		if not is_instance_valid(n):
			continue
		var p := n.is_processing()
		var pp := n.is_physics_processing()
		n.set_process(false)
		n.set_physics_process(false)
		await process_frame
		var t := await _avg_process(45)
		if is_instance_valid(n):
			n.set_process(p)
			n.set_physics_process(pp)
		var sc := n.get_script() as Script
		rows.append([base - t, "%s (%s)" % [n.name, sc.resource_path.get_file() if sc else n.get_class()]])
	rows.sort_custom(func(a, b) -> bool: return float(a[0]) > float(b[0]))
	for r in rows.slice(0, 15):
		print("PROBE   saves %6.2f ms  %s" % [float(r[0]), String(r[1])])


func _gather(n: Node, out: Array) -> void:
	if n.can_process() and (n.is_processing() or n.is_physics_processing()):
		out.append(n)
	for c in n.get_children():
		_gather(c, out)


func _avg_process(frames: int) -> float:
	var s := 0.0
	for i in frames:
		await process_frame
		s += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	return s / frames


## timeline: the frame's process time, physics time and fps every 2 s for `secs` s from the level's start.
func timeline(total: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(total * 1000.0):
		var s := 0.0
		var ph := 0.0
		var n := 0
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 2000:
			await process_frame
			s += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			ph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			n += 1
		print("PROBE t %4.0f s  fps %5.1f  process %6.2f ms  physics %5.2f ms" % [(Time.get_ticks_msec() - t0) / 1000.0, n / 2.0, s / maxf(n, 1), ph / maxf(n, 1)])


## groups: whole kinds switched off for 3 s each, a fresh baseline before each; what the frame's process time drops by.
func groups() -> void:
	var kinds := {
		"wild animals (process off)": func(on: bool) -> void:
			for n in root.get_tree().get_nodes_in_group(&"wildlife"):
				n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED,
		"animation mixers (players + trees)": func(on: bool) -> void:
			for m in root.find_children("*", "AnimationMixer", true, false):
				if on and m.has_meta(&"_probe_was"):
					(m as AnimationMixer).active = bool(m.get_meta(&"_probe_was"))
				elif not on:
					m.set_meta(&"_probe_was", (m as AnimationMixer).active)
					(m as AnimationMixer).active = false,
		"skeleton modifiers": func(on: bool) -> void:
			for m in root.find_children("*", "SkeletonModifier3D", true, false):
				if on and m.has_meta(&"_probe_was"):
					(m as SkeletonModifier3D).active = bool(m.get_meta(&"_probe_was"))
				elif not on:
					m.set_meta(&"_probe_was", (m as SkeletonModifier3D).active)
					(m as SkeletonModifier3D).active = false,
		"terrain + grass + vegetation": func(on: bool) -> void:
			for nm in ["Terrain", "Vegetation"]:
				var n := root.get_tree().current_scene.get_node_or_null(nm)
				if n:
					n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED,
		"the player": func(on: bool) -> void:
			var n := root.get_tree().current_scene.get_node_or_null("Player")
			if n:
				n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED,
		"household + spouse": func(on: bool) -> void:
			for n in root.get_tree().current_scene.get_children():
				if n is Spouse or n is Household:
					n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED,
		"environment (sky, day/night, weather, snow)": func(on: bool) -> void:
			for nm in ["EnvironmentRig", "Snow"]:
				var n := root.get_tree().current_scene.get_node_or_null(nm)
				if n:
					n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED,
	}
	for k: String in kinds:
		var base := await _avg_process(150)
		(kinds[k] as Callable).call(false)
		await process_frame
		var off := await _avg_process(150)
		(kinds[k] as Callable).call(true)
		print("PROBE group %-44s base %6.2f ms  off %6.2f ms  saves %6.2f ms" % [k, base, off, base - off])


## byscript: every node of a script (or class) switched off together, measured on / off / on (40 frames each) so the drift cancels.
func byscript() -> void:
	print("PROBE byscript start")
	var by := {}
	var nodes: Array = []
	_gather(root, nodes)
	for n: Node in nodes:
		var sc := n.get_script() as Script
		var key: String = sc.resource_path.get_file() if sc != null and sc.resource_path != "" else n.get_class()
		if not by.has(key):
			by[key] = []
		(by[key] as Array).append(n)
	var rows := []
	for key: String in by:
		var a := await _avg_process(40)
		var states := []
		for n: Node in by[key]:
			if is_instance_valid(n):
				states.append([n, n.is_processing(), n.is_physics_processing()])
				n.set_process(false)
				n.set_physics_process(false)
		await process_frame
		var off := await _avg_process(40)
		for s: Array in states:
			if is_instance_valid(s[0]):
				(s[0] as Node).set_process(bool(s[1]))
				(s[0] as Node).set_physics_process(bool(s[2]))
		await process_frame
		var b := await _avg_process(40)
		rows.append([(a + b) * 0.5 - off, key, (by[key] as Array).size()])
		print("PROBE row %6.2f ms  x%d %s" % [(a + b) * 0.5 - off, (by[key] as Array).size(), key])
	rows.sort_custom(func(x, y) -> bool: return float(x[0]) > float(y[0]))
	for r in rows.slice(0, 20):
		print("PROBE script saves %6.2f ms  x%-3d %s" % [float(r[0]), int(r[2]), String(r[1])])


## cost: byscript with the hitches taken out: each script's nodes off and on 3 times, 12 frames each, compared by the median frame
## (the level's frame swings 35-115 ms, so byscript's means are mostly noise).
func cost() -> void:
	print("PROBE cost start")
	var by := {}
	var nodes: Array = []
	_gather(root, nodes)
	for n: Node in nodes:
		var sc := n.get_script() as Script
		var key: String = sc.resource_path.get_file() if sc != null and sc.resource_path != "" else n.get_class()
		if not by.has(key):
			by[key] = []
		(by[key] as Array).append(n)
	var rows := []
	for key: String in by:
		var on: Array[float] = []
		var off: Array[float] = []
		for round in 3:
			on.append_array(await _frames(12))
			var states := []
			for n: Node in by[key]:
				if is_instance_valid(n):
					states.append([n, n.is_processing(), n.is_physics_processing()])
					n.set_process(false)
					n.set_physics_process(false)
			await process_frame
			off.append_array(await _frames(12))
			for s: Array in states:
				if is_instance_valid(s[0]):
					(s[0] as Node).set_process(bool(s[1]))
					(s[0] as Node).set_physics_process(bool(s[2]))
			await process_frame
		rows.append([_median(on) - _median(off), key, (by[key] as Array).size()])
	rows.sort_custom(func(x, y) -> bool: return float(x[0]) > float(y[0]))
	for r in rows.slice(0, 25):
		print("PROBE cost %6.2f ms  x%-3d %s" % [float(r[0]), int(r[2]), String(r[1])])


## Each frame's process + physics time in ms.
func _frames(count: int) -> Array[float]:
	var out: Array[float] = []
	for i in count:
		await process_frame
		out.append((Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
	return out


func _median(a: Array[float]) -> float:
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2] if not b.is_empty() else 0.0


## mixers: each active AnimationMixer (player or tree) off and on 3 times, 12 frames each, by the median frame; its owner and track count.
func mixers() -> void:
	var all := root.find_children("*", "AnimationMixer", true, false)
	var act := all.filter(func(m: Node) -> bool: return (m as AnimationMixer).active and m.is_inside_tree() and m.can_process())
	print("PROBE mixers %d (active %d)" % [all.size(), act.size()])
	var rows := []
	for m: AnimationMixer in act:
		var on: Array[float] = []
		var off: Array[float] = []
		for round in 3:
			on.append_array(await _frames(12))
			if not is_instance_valid(m):
				break
			m.active = false
			await process_frame
			off.append_array(await _frames(12))
			if is_instance_valid(m):
				m.active = true
			await process_frame
		var owner_path := "?"
		if is_instance_valid(m):
			owner_path = str(m.get_path()).trim_prefix("/root/")
		rows.append([_median(on) - _median(off), owner_path, m.get_class() if is_instance_valid(m) else ""])
	rows.sort_custom(func(x, y) -> bool: return float(x[0]) > float(y[0]))
	for r in rows.slice(0, 25):
		print("PROBE mixer %6.2f ms  %-16s %s" % [float(r[0]), String(r[2]), String(r[1])])
