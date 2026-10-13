extends RefCounted
## The one shared top-and-stills helper of the windowed capture scripts (tools/ui_audit/*.gd): the window flags, the arguments,
## the windowed-only guard, the frame waits, a frame really drawn, a still saved, the visible texts as data, the load wait of
## the ring, and the player's files a capture must give back. Other capture scripts (tools/character, tests/customizer,
## tests/companion) still carry their own always-on-top line and can switch to window() / on_top() one at a time.
##   const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
## No class_name (nothing to register); every function static, so a script's own `_frames(n)` can stay a one-liner:
##   func _frames(n: int) -> void: await CaptureKit.frames(self, n)
## The window policy is decided here once: a capture never pins itself over other apps (the owner keeps a video in front);
## TB_ON_TOP set to something but 0/false/off/no is the only way to opt in, and tools/loop/godot_run.sh unsets it.


static func headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Whether a capture may pin its window over other apps: only when TB_ON_TOP is set to something but 0/false/off/no.
## tools/loop/godot_run.sh unsets it and drops --always-on-top, so under the lock wrapper this is always false.
static func on_top() -> bool:
	var v := OS.get_environment("TB_ON_TOP").to_lower()
	return v != "" and not (v in ["0", "false", "off", "no"])


## The window flags of a capture (the one place that decides). No-op headless. `no_focus`: keys meant for another window
## cannot close this one.
static func window(no_focus := false) -> void:
	if headless():
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, on_top())
	if no_focus:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)


## "k=v", "--k=v" and a bare "k" / "--k" (= "on") of the script's user args, over `defaults` (values stay Strings).
static func args(defaults := {}) -> Dictionary:
	var out := defaults.duplicate()
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		var i := kv.find("=")
		if i < 0:
			out[kv] = "on"
		else:
			out[kv.substr(0, i)] = kv.substr(i + 1)
	return out


## The top every windowed capture repeats. false = it printed why and called tree.quit(1): `return` at once.
## Needs a window (not --headless) and, with `need_out`, a non-empty `out`; makes `out`; sets the window flags.
static func begin(tree: SceneTree, tag: String, out := "", need_out := false, no_focus := false) -> bool:
	if headless() or (need_out and out == ""):
		push_error("%s: needs %sa window" % [tag, "out=DIR and " if need_out else ""])
		tree.quit(1)
		return false
	if out != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	window(no_focus)
	return true


static func frames(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.process_frame


## Waits `s` seconds of wall time (frames go on).
static func secs(tree: SceneTree, s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await tree.process_frame


## Waits until `cond` is true, at most `limit` seconds: the seconds it took, INF when it never was.
static func until(tree: SceneTree, cond: Callable, limit: float) -> float:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		if cond.call():
			return (Time.get_ticks_msec() - t0) / 1000.0
		await tree.process_frame
	return INF


## A frame really drawn: the next frame_post_draw within `wait_s`, else (a covered or sleeping window is not drawn by the system)
## `forced` hand draws. true = the system drew it.
static func drawn(tree: SceneTree, wait_s := 1.5, forced := 8) -> bool:
	var done := [false]
	var cb := func() -> void: done[0] = true
	RenderingServer.frame_post_draw.connect(cb, CONNECT_ONE_SHOT)
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < int(wait_s * 1000.0):
		await tree.process_frame
	if done[0]:
		return true
	if RenderingServer.frame_post_draw.is_connected(cb):
		RenderingServer.frame_post_draw.disconnect(cb)
	for i in forced:
		RenderingServer.force_draw(false, 1.0 / 60.0)
	return false


## `img` as <dir>/<name>.png (dir made; RGB8 unless keep_alpha), "SHOT <name> <size>" printed. The path written.
static func save(img: Image, dir: String, name: String, keep_alpha := false) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	if not keep_alpha and img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	var path := dir.path_join(name + ".png")
	var err := img.save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", name, " ", img.get_size(), "" if err == OK else " (save failed: %d)" % err)
	return path


## Every visible Label / Button / RichTextLabel / LineEdit with text under `from`: path, class, text, rect (px), the theme's
## size, the size on screen (the theme size times its transform's scale), alpha (its own and every ancestor's, < 0.05 left
## out) and, with `fonts`, the font's name; "offscreen" when the rect is not inside `view`.
static func text_dump(from: Node, view: Rect2, fonts := false) -> Array:
	var res: Array = []
	for c in from.find_children("*", "Control", true, false):
		var ct := c as Control
		if not ct.is_visible_in_tree():
			continue
		var text := ""
		if ct is Label:
			text = (ct as Label).text
		elif ct is Button:
			text = (ct as Button).text
		elif ct is RichTextLabel:
			text = (ct as RichTextLabel).get_parsed_text()
		elif ct is LineEdit:
			text = (ct as LineEdit).text
		if text.strip_edges() == "":
			continue
		var xf := ct.get_global_transform_with_canvas()
		var r := xf * Rect2(Vector2.ZERO, ct.size)
		var a := ct.modulate.a * ct.self_modulate.a
		var p := ct.get_parent()
		while p != null:
			if p is CanvasItem:
				a *= (p as CanvasItem).modulate.a
			p = p.get_parent()
		if a < 0.05:
			continue
		var sz := ct.get_theme_font_size("font_size")
		var row := {"path": str(ct.get_path()), "cls": ct.get_class(), "text": text.left(160),
				"x": snappedf(r.position.x, 1), "y": snappedf(r.position.y, 1), "w": snappedf(r.size.x, 1),
				"h": snappedf(r.size.y, 1), "size": sz, "screen_px": snappedf(float(sz) * xf.get_scale().y, 0.1),
				"alpha": snappedf(a, 0.01), "offscreen": not view.encloses(r)}
		if fonts:
			row["font"] = _font_name(ct.get_theme_font("font"))
		res.append(row)
	return res


static func _font_name(f: Font) -> String:
	if f is SystemFont:
		return "System:" + ",".join((f as SystemFont).font_names).left(40)
	if f is FontVariation:
		var bf := (f as FontVariation).base_font
		return "Var:" + (("System:" + ",".join((bf as SystemFont).font_names).left(30)) if bf is SystemFont
				else (bf.resource_path if bf != null else "?"))
	if f != null:
		return f.resource_path if f.resource_path != "" else f.get_class()
	return ""


## Waits until the ring level `lvl` has finished loading (its loading_progress meta at 1 and no loading_hold), at most `limit`
## frames (1500). true when it did.
static func wait_loaded(tree: SceneTree, lvl: Node, limit := 1500) -> bool:
	var t := 0
	while t < limit and (float(lvl.get_meta(&"loading_progress", 1.0)) < 1.0 or bool(lvl.get_meta(&"loading_hold", false))):
		await tree.process_frame
		t += 1
	return t < limit


# ---------------------------------------------------------------- the player's own files a run may change
const BAK := ".audit_bak"
const NONE := ".audit_none"


## Keeps each file (user://how_to.cfg: FirstHints marks its topics seen) as <file>.audit_bak ON DISK, not in memory: a run that
## GODOT_TIMEOUT or a crash killed leaves its bak (or "none" marker) and the next keep() or restore() puts that original back
## first, so the player's real file never stays changed. Pair with restore(files) in the script's _end(). (Two captures running
## at once share the one bak: the first to finish puts the original back; the other's own marks, made after that, stay until
## the next run's keep() or restore() puts the original back again.)
static func keep(files: Array) -> void:
	for p: String in files:
		restore([p])                                    # (a killed earlier run's original, put back first)
		if FileAccess.file_exists(p):
			var f := FileAccess.open(p + BAK, FileAccess.WRITE)
			f.store_buffer(FileAccess.get_file_as_bytes(p))
			f.close()
		else:
			FileAccess.open(p + NONE, FileAccess.WRITE).close()


## Each kept file put back byte for byte (or removed when it did not exist), its bak / marker deleted.
static func restore(files: Array) -> void:
	for p: String in files:
		if FileAccess.file_exists(p + BAK):
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_buffer(FileAccess.get_file_as_bytes(p + BAK))
			f.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p + BAK))
		elif FileAccess.file_exists(p + NONE):
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p + NONE))
