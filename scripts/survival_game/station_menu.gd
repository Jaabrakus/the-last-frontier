class_name StationMenu
extends CanvasLayer
## A crafting station's short list of what it makes (CampStation: the tanning frame, the alchemy table): each row its
## name, what it takes and whether that is at hand. The game is paused while it is open (as the pack screen). A click or
## the row's number makes it; Esc, Tab or E closes. A choice is taken when the key or the button is let go, and the game
## goes on a frame later, so the key does not also reach the player (1-6 draw weapons, LMB fires).
##
##   var m := StationMenu.open(tree, "Tanning frame", [{"text": "...", "detail": "...", "ok": true}, ...])
##   var i: int = await m.picked       # -1: closed

signal picked(index: int)

const INK := Color(1.0, 0.95, 0.85)
const DIM := Color(0.66, 0.62, 0.56)
const WARN := Color(1.0, 0.62, 0.5)

var title := ""
var rows: Array = []
## Tests: the rows' buttons.
var buttons: Array[Button] = []
var _was_mouse := Input.MOUSE_MODE_CAPTURED
var _done := false


static func open(tree: SceneTree, p_title: String, p_rows: Array) -> StationMenu:
	var m := StationMenu.new()
	m.title = p_title
	m.rows = p_rows
	tree.root.add_child(m)
	return m


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.05, 0.9)
	sb.border_color = Color(0.55, 0.45, 0.3, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(560, 0)
	panel.add_child(box)
	var head := _label(title.to_upper(), 20, Color(0.9, 0.78, 0.52))
	box.add_child(head)
	for i in rows.size():
		var r: Dictionary = rows[i]
		var b := Button.new()
		b.text = "%d   %s" % [i + 1, String(r.get("text", ""))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 18)
		b.disabled = not bool(r.get("ok", false))
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_pick.bind(i))
		box.add_child(b)
		buttons.append(b)
		var d := _label("      " + String(r.get("detail", "")), 14, DIM if bool(r.get("ok", false)) else WARN)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(d)
	box.add_child(_label("Click or press the number     Esc  close", 13, DIM))
	# centred once its size is known
	panel.resized.connect(func() -> void: panel.position = -panel.size * 0.5)


func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey) or event.echo:
		return
	var k := (event as InputEventKey).physical_keycode
	get_viewport().set_input_as_handled()
	if event.pressed:
		return
	# let go
	if k in [KEY_ESCAPE, KEY_TAB, KEY_E]:
		_close(-1)
	elif k >= KEY_1 and k <= KEY_9:
		var i := int(k - KEY_1)
		if i < rows.size() and bool((rows[i] as Dictionary).get("ok", false)):
			_close(i)


## Chooses row `i` (a click, or a test).
func _pick(i: int) -> void:
	_close(i)


func _close(i: int) -> void:
	if _done:
		return
	_done = true
	visible = false
	Input.mouse_mode = _was_mouse if _was_mouse != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	get_tree().paused = false
	picked.emit(i)
	queue_free()
