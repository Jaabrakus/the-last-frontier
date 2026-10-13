extends SceneTree
## Critic's frame-cost compare (read-only on game files): the same dark stand-in alone, then the Character Advancement window over
## it, uncapped (--max-fps 0), so the window's own cost is the difference. Windowed, under the lock wrapper:
##   GODOT_TIMEOUT=200 zsh tools/loop/godot_run.sh --path . --resolution 1600x900 --max-fps 0 -s tools/ui_audit/critique_perf.gd

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const SAVE := "user://advancement_critique_perf.json"


func _initialize() -> void:
	if not CaptureKit.begin(self, "critique_perf", "", false, true):
		return
	_run.call_deferred()


func _sample(label: String, n := 240) -> void:
	for i in 40:
		await process_frame
	var s: Array = []
	var draw := 0
	for i in n:
		var t := Time.get_ticks_usec()
		await process_frame
		s.append((Time.get_ticks_usec() - t) / 1000.0)
		draw = maxi(draw, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	s.sort()
	print("  %-34s median %.2f ms  p95 %.2f ms  max %.2f ms  draw calls %d  window %s" % [label, s[n / 2], s[int(n * 0.95)], s[n - 1], draw, str(DisplayServer.window_get_size())])


func _run() -> void:
	AdvancementStore.path = SAVE
	AdvancementStore.reload_file()
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.1, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	await _sample("stand-in only")
	AdvancementData.gates_override = {"won": true, "full_left": 0, "first_win": true, "full_lessons": true}
	for el: String in ["earth", "water", "fire", "air"]:
		var w := AdvancementWindow.open(root, el)
		await _sample("window open: " + el)
		w.free()
		await process_frame
	var w2 := AdvancementWindow.open(root, "earth")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _sample("window open: earth at 1280x720")
	w2.free()
	await process_frame
	await _sample("stand-in only again")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("CRITIQUE PERF DONE")
	quit(0)
