class_name BuildHud
extends CanvasLayer
## Build mode's screen (BuildMode): the pieces down the left side under their groups (Cabin, Fort, Camp, Furniture,
## Crafting; the list scrolls with the choice, at most LINES lines) with their costs (the chosen one marked, the ones
## the pack cannot pay for dimmed), the logs and stone in the pack and the Building skill, the keys, and under the
## crosshair what E does or why the piece cannot go there.

const FONT := 15
const OK_COL := Color(0.8, 1.0, 0.78)
const BAD_COL := Color(1.0, 0.55, 0.45)
const TEXT_COL := Color(1.0, 0.95, 0.85)
const DIM_COL := Color(0.72, 0.68, 0.6)
const HEAD_COL := Color(0.86, 0.74, 0.5)
const LINES := 18

var _panel: PanelContainer
var _title: Label
var _rows: Array[Label] = []
var _keys: Label
var _status: Label
var _built := false


func _ready() -> void:
	layer = 5
	_build()


func _build() -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.055, 0.05, 0.5)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_panel.position = Vector2(18, -150)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_panel.add_child(box)
	_title = _label(FONT + 1, TEXT_COL)
	box.add_child(_title)
	for i in LINES:
		var l := _label(FONT, TEXT_COL)
		box.add_child(l)
		_rows.append(l)
	_keys = _label(FONT - 3, DIM_COL)
	_keys.text = "Wheel  piece     R  turn     Hold E  build     B  done"
	box.add_child(_keys)
	_status = _label(FONT + 3, OK_COL)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_status.position = Vector2(-340, -162)
	_status.size = Vector2(680, 36)
	add_child(_status)
	_built = true


## The menu's lines: [group, -1] where a group starts, [name, index] for each piece, and Take down last.
static func menu_lines(data: BuildData) -> Array:
	var out: Array = []
	var last := "?"
	for i in data.order.size():
		var g := data.group_of(data.order[i])
		if g != last and g != "":
			out.append([g, -1])
		last = g
		out.append([data.order[i], i])
	out.append([BuildData.TAKE_DOWN, data.order.size()])
	return out


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	return l


func refresh(mode: BuildMode) -> void:
	if not _built:
		return
	var data := mode.data
	var logs := mode.pack_count("log")
	var stone := mode.pack_count("stone")
	var sk := mode.skills()
	_title.text = "BUILDING     Logs %d   Stone %d%s" % [logs, stone, ("     " + sk.describe("building")) if sk else ""]
	var lines := menu_lines(data)
	var sel := 0
	for r in lines.size():
		if int(lines[r][1]) == mode.index:
			sel = r
	var start := clampi(sel - LINES / 2, 0, maxi(lines.size() - LINES, 0))
	for li in _rows.size():
		var l := _rows[li]
		var r := start + li
		l.visible = r < lines.size()
		if not l.visible:
			continue
		var i := int(lines[r][1])
		var chosen := i == mode.index
		l.add_theme_font_size_override("font_size", FONT)
		if i < 0:
			l.text = String(lines[r][0]).to_upper()
			l.add_theme_font_size_override("font_size", FONT - 3)
			l.add_theme_color_override("font_color", HEAD_COL)
		elif i < data.order.size():
			var id := data.order[i]
			var c := data.cost(id)
			var afford := true
			for k: String in c:
				if int(c[k]) > mode.pack_count(k):
					afford = false
			l.text = "%s %s   %s" % ["> " if chosen else "   ", data.name_of(id), BuildData.cost_text(c)]
			l.add_theme_color_override("font_color", OK_COL if chosen and afford else (BAD_COL if chosen else (TEXT_COL if afford else DIM_COL)))
		else:
			l.text = "%s %s" % ["> " if chosen else "   ", data.name_of(BuildData.TAKE_DOWN)]
			l.add_theme_color_override("font_color", OK_COL if chosen else TEXT_COL)
	var key := OS.get_keycode_string(ThrownPickup.INTERACT_KEY)
	if mode.taking_down():
		_status.text = "" if mode.aimed_piece else "Look at a piece to take it down"
		_status.add_theme_color_override("font_color", TEXT_COL)
	elif bool(mode.verdict.get("ok", false)) and data.opening(mode.piece_type()) != "":
		_status.text = "%s %s  %s" % ["Release" if mode.armed else "Hold", key, data.name_of(mode.piece_type())]
		_status.add_theme_color_override("font_color", OK_COL)
	elif bool(mode.verdict.get("ok", false)):
		_status.text = "%s %s  Build the %s" % ["Release" if mode.armed else "Hold", key, data.name_of(mode.piece_type()).to_lower()]
		_status.add_theme_color_override("font_color", OK_COL)
	else:
		_status.text = String(mode.verdict.get("reason", ""))
		_status.add_theme_color_override("font_color", BAD_COL)
