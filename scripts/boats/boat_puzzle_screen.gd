class_name BoatPuzzleScreen
extends CanvasLayer
## The frame of a boat-building puzzle (BarkFitScreen, PitchScreen; user 2026-09-29: "building it is a puzzle"): a panel over the
## game, paused while it is open (as StationMenu), a title, what to do, the puzzle's board, and Done / Give up. It ends with
## `finished(score)`: the puzzle's score 0..1, or -1 for giving up (Esc): the stage then waits as it was.
## The subclasses make the board (_board_size, _draw_board, _input_board) and step the puzzle (_tick).

signal finished(score: float)

const INK := Color(1.0, 0.95, 0.85)
const DIM := Color(0.66, 0.62, 0.56)
const PANEL := Color(0.09, 0.075, 0.06, 0.96)

var title := ""
var hint := ""
var guided := true
var board: Control
var _was_mouse := Input.MOUSE_MODE_CAPTURED
var _done := false
var _time_bar: ProgressBar
var _info: Label


## A puzzle screen of `kind` ("bed_stakes", "bark_fit", "lashing", "rib_steam", "pitch") opened over the game. `extra`: the plan's
## "hull" numbers for the bed, the "lumps" of pitch for the seams.
static func open(tree: SceneTree, kind: String, p_guided: bool, extra := {}) -> BoatPuzzleScreen:
	var s: BoatPuzzleScreen
	match kind:
		"bed_stakes":
			var st := StakeBedScreen.new()
			st.hull = extra.get("hull", {})
			s = st
		"bark_fit":
			s = BarkFitScreen.new()
		"lashing":
			s = LashingScreen.new()
		"rib_steam":
			s = RibSteamScreen.new()
		_:
			var ps := PitchScreen.new()
			ps.lumps = float(extra.get("lumps", 3.0))
			s = ps
	s.guided = p_guided
	tree.root.add_child(s)
	return s


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(20)
	sb.border_color = Color(0.5, 0.42, 0.3)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(_label(title, 24, Color(0.93, 0.84, 0.62)))
	var h := _label(hint, 15, DIM)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.custom_minimum_size = Vector2(_board_size().x, 0)
	col.add_child(h)
	board = Control.new()
	board.custom_minimum_size = _board_size()
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(func() -> void: _draw_board(board))
	board.gui_input.connect(_input_board)
	col.add_child(board)
	_time_bar = ProgressBar.new()
	_time_bar.show_percentage = false
	_time_bar.custom_minimum_size = Vector2(0, 10)
	col.add_child(_time_bar)
	_info = _label("", 15, INK)
	col.add_child(_info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var ok := _button("Done")
	ok.pressed.connect(func() -> void: _end(_score()))
	row.add_child(ok)
	var no := _button("Give up  (Esc)")
	no.pressed.connect(func() -> void: _end(-1.0))
	row.add_child(no)


func _label(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l


func _button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(150, 34)
	return b


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_end(-1.0)


func _process(dt: float) -> void:
	if _done:
		return
	_tick(dt)
	if _time_bar != null:
		_time_bar.value = _progress() * 100.0
	if _info != null:
		_info.text = _status()
	if board != null:
		board.queue_redraw()
	if _finished():
		_end(_score())


func _end(score: float) -> void:
	if _done:
		return
	_done = true
	get_tree().paused = false
	Input.mouse_mode = _was_mouse
	finished.emit(score)
	queue_free()


# --- for the subclasses
func _board_size() -> Vector2:
	return Vector2(720, 260)


func _draw_board(_c: Control) -> void:
	pass


func _input_board(_e: InputEvent) -> void:
	pass


func _tick(_dt: float) -> void:
	pass


func _progress() -> float:
	return 0.0


func _status() -> String:
	return ""


func _finished() -> bool:
	return false


func _score() -> float:
	return 0.0
