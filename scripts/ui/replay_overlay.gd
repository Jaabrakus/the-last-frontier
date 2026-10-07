class_name ReplayOverlay
extends CanvasLayer
## The Splash Cam's own layer (round 4 VIRAL; RingReplay makes it): while a replay plays, a small REPLAY tag in the top-right
## corner (a red dot, the word, a thin bar of the replay's progress) and a skip line under it; nothing else on the screen and
## nothing on anyone. Any key or mouse button skips once skip_grace_s (real) has passed (the press is taken: it never reaches
## the match). Words and sizes in data/ring/replay.json "tag".

var replay: Node
var _box: Control
var _dot: ColorRect
var _bar: ColorRect
var _t := 0.0


func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	replay = get_parent()
	var m := RingReplay.sub("tag", "margin", 34.0)
	_box = Control.new()
	_box.name = "Tag"
	_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_box.offset_left = -260.0 - m
	_box.offset_right = -m
	_box.offset_top = m
	_box.offset_bottom = m + 80.0
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.visible = false
	add_child(_box)
	var back := ColorRect.new()
	back.color = Color(0.0, 0.0, 0.0, 0.42)
	back.position = Vector2(60.0, 0.0)
	back.size = Vector2(200.0, 44.0)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(back)
	_dot = ColorRect.new()
	_dot.color = Color(0.95, 0.18, 0.12)
	_dot.position = Vector2(76.0, 15.0)
	_dot.size = Vector2(14.0, 14.0)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_dot)
	var word := MenuUI.label(RingReplay.word("tag", "word", "REPLAY"), int(RingReplay.sub("tag", "size", 26.0)), Color(1, 1, 1))
	word.position = Vector2(100.0, 2.0)
	word.size = Vector2(160.0, 40.0)
	word.add_theme_constant_override("outline_size", 6)
	word.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(word)
	_bar = ColorRect.new()
	_bar.color = Color(1.0, 1.0, 1.0, 0.85)
	_bar.position = Vector2(60.0, 44.0)
	_bar.size = Vector2(0.0, 3.0)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_bar)
	var skip := MenuUI.label(RingReplay.word("tag", "skip"), int(RingReplay.sub("tag", "skip_size", 15.0)), MenuUI.INK)
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip.position = Vector2(0.0, 50.0)
	skip.size = Vector2(260.0, 24.0)
	skip.add_theme_constant_override("outline_size", 4)
	skip.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(skip)


## The tag shown while a replay plays (RingReplay).
func show_tag(on: bool) -> void:
	_box.visible = on
	_t = 0.0


func is_showing() -> bool:
	return _box != null and _box.visible


func _process(delta: float) -> void:
	if not _box.visible:
		return
	_t += delta / maxf(Engine.time_scale, 0.01)
	_dot.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * cos(_t * TAU * 1.2))      # (a slow blink: the camera is rolling)
	var c: Variant = replay.call(&"clip") if replay != null and replay.has_method(&"clip") else null
	if c != null:
		var k := clampf(float(replay.call(&"clip_tick")) / maxf(float((c as RingReplay.Clip).n - 1), 1.0), 0.0, 1.0)
		_bar.size = Vector2(200.0 * k, 3.0)


func _input(e: InputEvent) -> void:
	if not _box.visible or replay == null:
		return
	var press := (e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo) \
			or (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) \
			or (e is InputEventJoypadButton and (e as InputEventJoypadButton).pressed)
	if not press:
		if e is InputEventKey or e is InputEventMouseButton or e is InputEventMouseMotion:
			get_viewport().set_input_as_handled()    # (nothing reaches the held match while it plays)
		return
	get_viewport().set_input_as_handled()
	if _t >= RingReplay.sub("tag", "skip_grace_s", 0.3):
		replay.call(&"skip")
