class_name YogaPrompt
extends CanvasLayer
## The small prompts of a yoga together (paused game, as the household screen): the OFFER (her line, Accept / Decline)
## and the POSE MENU (the tandem feature's poses, Not now). Esc declines or cancels.
##   YogaPrompt.offer(tree, "her line", name)   -> emits answered(accept)
##   YogaPrompt.poses(tree, poses, "her line")  -> emits chosen(pose_id) or cancelled

signal answered(accept: bool)
signal chosen(pose_id: String)
signal cancelled

const HEAD := Color(0.93, 0.84, 0.62)
const TEXT := Color(0.9, 0.87, 0.8)

var _mode := "offer"
var _line := ""
var _title := ""
var _poses: Array = []
var _was_mouse := Input.MOUSE_MODE_CAPTURED
var _done := false


static func offer(tree: SceneTree, line: String, who: String) -> YogaPrompt:
	var s := YogaPrompt.new()
	s._mode = "offer"
	s._line = line
	s._title = who
	tree.root.add_child(s)
	return s


static func poses(tree: SceneTree, list: Array, line: String, who: String) -> YogaPrompt:
	var s := YogaPrompt.new()
	s._mode = "poses"
	s._poses = list
	s._line = line
	s._title = who
	tree.root.add_child(s)
	return s


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.05, 0.95)
	sb.border_color = Color(0.55, 0.45, 0.3, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	for m in ["content_margin_left", "content_margin_right", "content_margin_top", "content_margin_bottom"]:
		sb.set(m, 18)
	panel.add_theme_stylebox_override("panel", sb)
	var th := Theme.new()
	th.default_font = FrontierHUD.serif()
	panel.theme = th
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_label(_title.to_upper(), 22, HEAD))
	var l := _label("\"%s\"" % _line, 19, TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	box.add_child(l)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	box.add_child(row)
	if _mode == "offer":
		row.add_child(_button("Accept", func() -> void: _finish(func() -> void: answered.emit(true))))
		row.add_child(_button("Decline", func() -> void: _finish(func() -> void: answered.emit(false))))
	else:
		for p: Dictionary in _poses:
			var id := String(p.id)
			row.add_child(_button(String(p.name), func() -> void: _finish(func() -> void: chosen.emit(id))))
		row.add_child(_button("Not now", func() -> void: _finish(func() -> void: cancelled.emit())))
	box.add_child(_label("Esc: %s" % ("decline" if _mode == "offer" else "not now"), 14, Color(0.62, 0.58, 0.52)))


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if _mode == "offer":
			_finish(func() -> void: answered.emit(false))
		else:
			_finish(func() -> void: cancelled.emit())


## Closes the prompt first (the game runs again), then tells the answer.
func _finish(then: Callable) -> void:
	if _done:
		return
	_done = true
	get_tree().paused = false
	Input.mouse_mode = _was_mouse
	then.call()
	queue_free()


func _exit_tree() -> void:
	if not _done:
		get_tree().paused = false
		Input.mouse_mode = _was_mouse


func _button(text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(120, 34)
	b.pressed.connect(fn)
	return b


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
