class_name RtsHud
extends CanvasLayer
## The command mode's screen (RtsMode): the drag box, who is picked and what each is doing, and the command card (Stop; more
## as the household can do them).

var mode: RtsMode
var _overlay: Control
var _title: Label
var _list: Label
var _panel: PanelContainer


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_box)
	add_child(_overlay)
	_title = Label.new()
	_title.position = Vector2(18, 14)
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_title.add_theme_constant_override("shadow_offset_x", 1)
	_title.add_theme_constant_override("shadow_offset_y", 1)
	_overlay.add_child(_title)
	_list = Label.new()
	_list.position = Vector2(18, 46)
	_list.add_theme_font_size_override("font_size", 16)
	_list.add_theme_color_override("font_color", Color(0.9, 0.93, 0.98))
	_list.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_list.add_theme_constant_override("shadow_offset_x", 1)
	_list.add_theme_constant_override("shadow_offset_y", 1)
	_overlay.add_child(_list)
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -180.0
	_panel.offset_right = 180.0
	_panel.offset_top = -74.0
	_panel.offset_bottom = -14.0
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	var stop := Button.new()
	stop.text = "Stop (X)"
	stop.pressed.connect(func() -> void: mode.stop())
	box.add_child(stop)
	var hint := Label.new()
	hint.text = "Right click: go   Shift: queue   Ctrl+1-9: group   F1: leave"
	hint.add_theme_font_size_override("font_size", 13)
	box.add_child(hint)
	_overlay.add_child(_panel)
	set_process(true)


func over_panel(p: Vector2) -> bool:
	return _panel != null and _panel.visible and _panel.get_global_rect().has_point(p)


func queue_redraw() -> void:
	if _overlay:
		_overlay.queue_redraw()


func _draw_box() -> void:
	if mode == null or mode._drag_from == Vector2.INF:
		return
	if mode._drag_from.distance_to(mode._drag_to) < RtsMode.DRAG_PX:
		return
	var r := Rect2(mode._drag_from, mode._drag_to - mode._drag_from).abs()
	_overlay.draw_rect(r, Color(0.4, 0.8, 0.5, 0.12), true)
	_overlay.draw_rect(r, Color(0.4, 0.9, 0.5, 0.9), false, 1.5)


func _process(_dt: float) -> void:
	if mode == null or not visible:
		return
	var n := mode.selected.size()
	_title.text = "COMMAND  ·  %d selected" % n if n > 0 else "COMMAND  ·  nothing selected"
	var lines: Array[String] = []
	for u in mode.selected.slice(0, 12):
		if is_instance_valid(u):
			var what: String = String(u.sc.task) if u.sc != null and String(u.sc.task) != "" else ("on the way" if not u.orders.is_empty() else "idle")
			lines.append("%s  —  %s" % [u.sc.name if u.sc != null else u.name, what])
	_list.text = "\n".join(lines)
