extends SceneTree
## Critic's stills and frame cost of the Character Advancement window (read-only on game files): what a new player sees (no picks, the
## first-win gates up), the other window sizes (1280x720 for every element, 1024x768, 2560x1080), a plain tip, the keyboard
## focus ring, a long tip at 1280x720, the Loadouts panel and the class picker at 1280x720, and a frame-cost sample.
## Windowed (the lock wrapper): out=<abs dir> [only=a,b] ; never opens the character creator.
##   GODOT_TIMEOUT=300 zsh tools/loop/godot_run.sh --path . --resolution 1600x900 --max-fps 0 -s tools/ui_audit/critique_shots.gd -- out=<dir>

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const SAVE := "user://advancement_critique_shots.json"
var out := ""
var only: Array = []
var _bg: ColorRect
var _w: AdvancementWindow


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		if kv.begins_with("out="):
			out = kv.get_slice("=", 1)
		elif kv.begins_with("only="):
			only = kv.get_slice("=", 1).split(",")
	if not CaptureKit.begin(self, "critique_shots", out, true, true):
		return
	_run.call_deferred()


func _frames(n: int) -> void:
	await CaptureKit.frames(self, n)


func _want(name: String) -> bool:
	return only.is_empty() or name in only


func _shot(name: String, keep_tip := false) -> void:
	await _frames(8)
	if not keep_tip and _w != null and is_instance_valid(_w):
		_w._hide_tip()
		await process_frame
	RenderingServer.force_draw()
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("  shot ", name, " ", img.get_size())


func _size(v: Vector2i) -> void:
	DisplayServer.window_set_size(v)
	await _frames(14)


func _open(el: String) -> AdvancementWindow:
	if _w != null and is_instance_valid(_w):
		_w.free()
	_w = AdvancementWindow.open(root, el)
	return _w


func _fill(el: String) -> void:
	var w := _open(el)
	var starters := AdvancementData.starters(el)
	if el == "fire":
		w.pick_class("boxing")
	w.apply_premade(String(starters[0].id))
	w.save()
	w.wear_seconds = 0.0
	w.wear_slot(0)
	await _frames(2)


func _first(w: AdvancementWindow, st: String, kind := "") -> AdvancementNode:
	for n: AdvancementNode in w.all_nodes():
		if n.state == st and String(n.item.type) == "node" and not n.is_choice() and (kind == "" or n.kind == kind):
			return n
	return null


func _run() -> void:
	AdvancementStore.path = SAVE
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	AdvancementStore.reload_file()
	_bg = ColorRect.new()
	_bg.color = Color(0.09, 0.1, 0.13)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_bg)
	await _frames(4)

	# a new player: nothing worn, the first-win gate up (the real default)
	if _want("crit_newcomer"):
		AdvancementData.gates_override = {"won": false, "full_left": 4, "first_win": true, "full_lessons": true}
		var w := _open("fire")
		await _frames(8)
		await _shot("crit_newcomer")
		var n := _first(w, "blocked")
		if n != null:
			n.tip.emit(n, true)
			await _shot("crit_newcomer_tip", true)
			n.tip.emit(n, false)
	AdvancementData.gates_override = {"won": true, "full_left": 0, "first_win": true, "full_lessons": true}

	# the empty Classic slot with the gates open: what the first picking looks like
	if _want("crit_empty"):
		var w := _open("water")
		await _frames(8)
		await _shot("crit_empty")
		var n := _first(w, "available", "variation")
		if n != null:
			n.tip.emit(n, true)
			await _shot("crit_tip_available", true)
			n.tip.emit(n, false)
		# the keyboard focus ring
		if n != null:
			n.grab_focus()
			await _frames(4)
			w._hide_tip()
			await _shot("crit_focus")
		# the rail's tip
		var r := w.rail()
		if r != null:
			for c in r.get_children():
				if c is AdvancementNode:
					(c as AdvancementNode).tip.emit(c, true)
					await _shot("crit_tip_rail", true)
					(c as AdvancementNode).tip.emit(c, false)
					break

	# every element at 1280x720
	if _want("crit_720"):
		for el: String in AdvancementData.ELEMENTS:
			await _fill(el)
			var w := _open(el)
			await _size(Vector2i(1280, 720))
			await _shot("crit_720_" + el)
			await _size(Vector2i(1600, 900))

	# other sizes
	if _want("crit_sizes"):
		await _fill("earth")
		_open("earth")
		await _size(Vector2i(1024, 768))
		await _shot("crit_1024x768")
		await _size(Vector2i(2560, 1080))
		await _shot("crit_2560x1080")
		await _size(Vector2i(1600, 900))

	# the longest tip, the Loadouts panel and the class picker at 1280x720
	if _want("crit_720_panels"):
		await _fill("air")
		var w := _open("air")
		await _size(Vector2i(1280, 720))
		for n: AdvancementNode in w.all_nodes():
			if String(n.item.type) == "node" and not n.is_choice() and n.kind == "skill_set":
				n.tip.emit(n, true)
				await _shot("crit_720_longtip", true)
				n.tip.emit(n, false)
				break
		w.set_slots_open(true)
		await _frames(10)
		await _shot("crit_720_slots")
		w.set_slots_open(false)
		w.open_picker()
		await _frames(6)
		await _shot("crit_720_class")
		w.close_picker()
		await _size(Vector2i(1600, 900))

	# the air class picker (Capoeira's long state word) and the status line at its longest, at 1600x900
	if _want("crit_extra"):
		AdvancementData.gates_override = {"won": true, "full_left": 0, "first_win": true, "full_lessons": true}
		var w := _open("air")
		await _frames(6)
		w.open_picker()
		await _frames(8)
		await _shot("crit_class_air")
		w.close_picker()
		w.apply_premade(String(AdvancementData.starters("air")[1].id))
		w.save()
		await _frames(4)
		await _shot("crit_status_air")
		var e := _open("earth")
		e.apply_premade(String(AdvancementData.starters("earth")[1].id))
		e.save()
		await _frames(4)
		await _shot("crit_status_earth")

	# frame cost with the window open
	if _want("crit_perf"):
		await _fill("earth")
		var t0 := Time.get_ticks_usec()
		var w := _open("earth")
		await _frames(2)
		print("  open + 2 frames: %.1f ms" % [(Time.get_ticks_usec() - t0) / 1000.0])
		await _frames(30)
		var samples: Array = []
		var draw := 0
		var prims := 0
		for i in 150:
			var f0 := Time.get_ticks_usec()
			await process_frame
			samples.append((Time.get_ticks_usec() - f0) / 1000.0)
			draw = maxi(draw, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
			prims = maxi(prims, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)))
		samples.sort()
		print("  idle frames (150): median %.2f ms, p95 %.2f ms, max %.2f ms; draw calls max %d, primitives max %d" % [
			samples[75], samples[142], samples[149], draw, prims])
		print("  Performance: process %.2f ms, physics %.2f ms, nodes %d, objects %d, texture mem %.1f MB, video mem %.1f MB, static mem %.1f MB" % [
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
		var ctl := 0
		var stack: Array = [w]
		while not stack.is_empty():
			var c: Node = stack.pop_back()
			if c is Control:
				ctl += 1
			stack.append_array(c.get_children())
		print("  controls under the window: ", ctl)
		# hovering a node while the tip is up
		var n := _first(w, "available")
		var h: Array = []
		for i in 90:
			if n != null and i == 10:
				n.tip.emit(n, true)
			var f1 := Time.get_ticks_usec()
			await process_frame
			h.append((Time.get_ticks_usec() - f1) / 1000.0)
		h.sort()
		print("  frames with a tip up (90): median %.2f ms, max %.2f ms" % [h[45], h[89]])
		# open and close cost, ten times
		var oc: Array = []
		for i in 10:
			var o0 := Time.get_ticks_usec()
			var ww := AdvancementWindow.open(root, "earth" if i % 2 == 0 else "air")
			await process_frame
			ww.free()
			await process_frame
			oc.append((Time.get_ticks_usec() - o0) / 1000.0)
		oc.sort()
		print("  open+close x10 (2 frames each): median %.1f ms, max %.1f ms" % [oc[5], oc[9]])
		print("  nodes after the churn: %d, orphans: %d" % [int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])

	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("CRITIQUE SHOTS DONE")
	quit(0)
