class_name AdvancementWindow
extends CanvasLayer
## "Character Advancement": the in-game skill tree window (artifacts/ui_audit/advancement/plan.md), in the stone-and-gold
## look of the owner's reference clip and the menus' Barlow type. It saves loadouts (AdvancementStore); a worn loadout changes a
## match only through the picks data/bending/loadout_apply.json makes live (a green dot on the node, a line in its tip), and
## a ribbon on the window says the rest is a preview.
##
## What is on it (authored at 1600x900, scaled by min(w/1600, h/900); 1280x720 is the smallest window it is made for: the
## smallest type, 18 authored px, reads at 14.4 px there; a 4:3 window letterboxes it and its type shrinks with the scale):
##   the painted arena of the player's element between two lattices: the LEFT tree (jab, guard, strike, push) titled with the
##   class's fighting style, the RIGHT tree (dash, wall, heal, passive and the skill set) titled with the skill set, the class
##   rail at the right edge, and a bottom bar (Loadout and premade-build dropdowns, Search, Save Changes and its undo, Reset,
##   Change class); under the frame the tabs Advancement | Loadouts | Your look.
## What it does: every click is a PENDING change of a copy of the loadout slot (Save glows green, an undo arrow shows);
## Save Changes writes the slot and raises a toast for each new twist, technique, new skill and skill set; Reset makes Classic
## a pending change; Change class picks the class (element + style); the Loadouts panel wears a slot (a short gold bar, then
## the toasts). Closing with changes pending asks Save / Discard / Keep editing.
##
##   AdvancementWindow.open(parent, element := "") -> AdvancementWindow     (element "" = the character's, else earth)
##   signal closed / signal look_requested   (the "Your look" tab: the menus open the creator when they wire this)
##   close()
## PROCESS_MODE_ALWAYS (it works over a paused game), the mouse is visible while it is open, Esc closes it (a popped choice, a
## list, the class picker, the Loadouts panel first) and the Esc is consumed so a RingMenu under it does not also close.

signal closed
signal look_requested

const LAYER := 95
const AUTHORED := Vector2(1600, 900)

var element := ""
var slot_index := 0
var work: AdvancementLoadout
var saved: AdvancementLoadout
var from_id := ""
var from_name := ""
var busy := false
## Seconds the Wear bar takes (-1: advancement.json layout.wear_bar_s).
var wear_seconds := -1.0

var _root: Control
var _stage: Control
var _tree_l: AdvancementTree
var _tree_r: AdvancementTree
var _rail: AdvancementRail
var _backdrop: TextureRect           ## the painting (its shader calms the ground behind the trees)
var _tip: AdvancementTip
var _tip_for: Control
var _portrait: TextureRect
var _title_l: Label
var _title_r: Label
var _points_l: HBoxContainer
var _points_r: HBoxContainer
var _num_l: Label
var _num_r: Label
var _cap_l: Label
var _cap_r: Label
var _status: Label
var _search: LineEdit
var _loadout_drop: AdvancementDrop
var _premade_drop: AdvancementDrop
var _code_drop: AdvancementDrop
var _panel_btn: AdvancementDrop
var _save: Button
var _undo: Button
var _reset: Button
var _class_btn: Button
var _tab_adv: Button
var _tab_loadouts: Button
var _tab_look: Button
var _slots: AdvancementSlots
var _picker: AdvancementPicker
var _prompt: Control
var _wear_bar: Control
var _wear_fill: ColorRect
var _wear_label: Label
var _toasts: Array = []
var _glow_tween: Tween
var _glow_box: StyleBoxFlat
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _closing := false
var _status_tween: Tween
var _tip_timer: Timer
var _tip_shift := false           ## Shift is held (the full tip)
var _tip_dwell := false           ## the pointer or focus has stayed on the thing (the full tip)


static func open(parent: Node, el := "") -> AdvancementWindow:
	for c in parent.get_children():
		if c is AdvancementWindow and not (c as AdvancementWindow)._closing:
			return c as AdvancementWindow          # (one at a time: the one open is the one asked for)
	var w := AdvancementWindow.new()
	w.element = el
	parent.add_child(w)
	return w


static func _default_element() -> String:
	var look: Dictionary = AppearanceStore.load_current()
	var e := String(look.get("element", ""))
	return e if e in AdvancementData.ELEMENTS else "earth"


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not element in AdvancementData.ELEMENTS:
		element = _default_element()
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var w := AdvancementStore.worn_index(element)
	slot_index = w if w >= 0 else 0
	saved = AdvancementStore.slot(element, slot_index).with_live_context()
	work = saved.copy()
	_build()
	get_viewport().size_changed.connect(_fit)
	_fit()
	refresh_all()


func _exit_tree() -> void:
	if not _closing and Input.mouse_mode != _mouse_before:
		Input.mouse_mode = _mouse_before


func close() -> void:
	if _closing:
		return
	_closing = true
	Input.mouse_mode = _mouse_before
	closed.emit()
	queue_free()


# --- reading the state ---------------------------------------------------------------------------------------------------

func is_pending() -> bool:
	var d := work.diff(saved)
	return not (d.worn as Array).is_empty() or not (d.taken_off as Array).is_empty() or bool(d.style)


func tree(side: String) -> AdvancementTree:
	return _tree_l if side == "left" else _tree_r


func rail() -> AdvancementRail:
	return _rail


## The scaled 1600x900 stage every part sits on.
func stage() -> Control:
	return _stage


func prompt_node() -> Control:
	return _prompt


func picker_node() -> AdvancementPicker:
	return _picker


func status_text() -> String:
	return _status.text if _status != null else ""


func toast_texts() -> Array:
	var out: Array = []
	for t: Dictionary in _toasts:
		out.append(String(t.text))
	return out


## Every node control of both trees, in reading order (not the pop-out's).
func all_nodes() -> Array:
	var out: Array = []
	out.append_array(_tree_l.nodes)
	out.append_array(_tree_r.nodes)
	return out


func node_for_id(id: String) -> AdvancementNode:
	var n := _tree_l.node_for_id(id)
	return n if n != null else _tree_r.node_for_id(id)


func slots_open() -> bool:
	return _slots != null and _slots.visible


func picker_open() -> bool:
	return _picker != null


func prompt_open() -> bool:
	return _prompt != null


func save_button() -> Button:
	return _save


func undo_button() -> Button:
	return _undo


func reset_button() -> Button:
	return _reset


func class_button() -> Button:
	return _class_btn


func search_box() -> LineEdit:
	return _search


func loadout_drop() -> AdvancementDrop:
	return _loadout_drop


func premade_drop() -> AdvancementDrop:
	return _premade_drop


func tab_button(which: String) -> Button:
	return {"advancement": _tab_adv, "loadouts": _tab_loadouts, "look": _tab_look}.get(which)


func slots_panel() -> AdvancementSlots:
	return _slots


func tip_visible() -> bool:
	return _tip != null and _tip.visible


# --- building ----------------------------------------------------------------------------------------------------------------

func _r(part: String) -> Rect2:
	return AdvancementData.window_rect(part)


func _place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.size = AUTHORED
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage)
	_build_frame()
	_build_painting()
	_build_bevel()
	_build_titles()
	_build_trees()
	_calm_painting()
	_build_bottom()
	_build_tabs()
	_build_overlays()
	_wire_focus()
	_refresh_class()


func _build_frame() -> void:
	var fr := _r("frame")
	var frame := Panel.new()
	frame.name = "Frame"
	frame.add_theme_stylebox_override("panel", AdvancementTheme.frame_box())
	_place(frame, fr)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.add_child(frame)


func _build_painting() -> void:
	var fr := _r("frame")
	var strip := _r("title_strip")
	var bar := _r("bottom_bar")
	var art := Control.new()
	art.name = "Painting"
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := strip.end.y
	art.position = Vector2(fr.position.x + 5.0, top)
	art.size = Vector2(fr.size.x - 10.0, bar.position.y - top)
	_stage.add_child(art)
	var pic := TextureRect.new()
	pic.name = "Backdrop"
	var tx := AdvancementTheme.backdrop(element)
	pic.texture = tx
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	# covers the frame, cropped more from the floor than from the sky (the focal objects rise from the floor)
	var aspect := float(tx.get_width()) / float(tx.get_height()) if tx != null else 16.0 / 9.0
	var ph := maxf(art.size.y, art.size.x / aspect)
	pic.size = Vector2(ph * aspect, ph)
	pic.position = Vector2((art.size.x - pic.size.x) * 0.5, -(ph - art.size.y) * 0.38)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(pic)
	_backdrop = pic
	# behind the trees and the rail the picture is calmed by a shader (softened, drained of colour, darkened: _calm_painting,
	# once the trees are placed); a light even shade over the sides keeps the edges quiet, the centre gap stays bright
	var calm := ShaderMaterial.new()
	calm.shader = load("res://shaders/ui/adv_backdrop.gdshader") as Shader
	pic.material = calm
	var side := TextureRect.new()
	side.texture = AdvancementTheme.shade_tex(float(AdvancementData.layout().get("side_shade", 0.32)), 0.0)
	side.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	side.stretch_mode = TextureRect.STRETCH_SCALE
	side.size = art.size
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(side)
	var up := TextureRect.new()
	up.texture = AdvancementTheme.fade_tex(0.5, 0.0)
	up.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	up.stretch_mode = TextureRect.STRETCH_SCALE
	up.size = Vector2(art.size.x, 150)
	up.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(up)
	var down := TextureRect.new()
	down.texture = AdvancementTheme.fade_tex(0.0, 0.62)
	down.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	down.stretch_mode = TextureRect.STRETCH_SCALE
	down.size = Vector2(art.size.x, 130)
	down.position = Vector2(0, art.size.y - 130)
	down.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(down)
	# the title strip and the bottom bar
	var ts := ColorRect.new()
	ts.color = Color(0.045, 0.05, 0.065)
	ts.position = Vector2(fr.position.x + 5.0, fr.position.y + 5.0)
	ts.size = Vector2(fr.size.x - 10.0, strip.size.y - 5.0)
	ts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(ts)
	var tl := ColorRect.new()
	tl.color = Color(AdvancementData.color("frame_gold"), 0.85)
	tl.position = Vector2(ts.position.x, strip.end.y - 2.0)
	tl.size = Vector2(ts.size.x, 2.0)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(tl)
	var bb := ColorRect.new()
	bb.name = "BottomBar"
	bb.color = Color(0.052, 0.058, 0.075)
	bb.position = Vector2(fr.position.x + 5.0, bar.position.y)
	bb.size = Vector2(fr.size.x - 10.0, fr.end.y - bar.position.y - 5.0)
	bb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(bb)
	var bl := ColorRect.new()
	bl.color = Color(AdvancementData.color("frame_gold"), 0.85)
	bl.position = Vector2(bb.position.x, bar.position.y - 2.0)
	bl.size = Vector2(bb.size.x, 2.0)
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(bl)
	# the knots at the four corners
	var corner := AdvancementTheme.frame_tex("frame_corner")
	if corner != null:
		for i in 4:
			var k := TextureRect.new()
			k.texture = corner
			k.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			k.stretch_mode = TextureRect.STRETCH_SCALE
			k.size = Vector2(64, 64)
			k.flip_h = i % 2 == 1
			k.flip_v = i >= 2
			k.position = Vector2(fr.position.x + (fr.size.x - 64.0 if i % 2 == 1 else 0.0) + (-1.0 if i % 2 == 1 else 1.0), fr.position.y + (fr.size.y - 64.0 if i >= 2 else 0.0) + (-1.0 if i >= 2 else 1.0))
			k.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_stage.add_child(k)


## The frame's heavy stone: a bevel round the painting, lit from the top left (the gold stays on the title strip, the knots and
## the portrait), drawn once over the painting's and the bars' outer edges.
func _build_bevel() -> void:
	var fr := _r("frame")
	var bev := Control.new()
	bev.name = "Bevel"
	_place(bev, fr)
	bev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bev.draw.connect(func() -> void: _draw_bevel(bev))
	_stage.add_child(bev)


func _draw_bevel(c: Control) -> void:
	var w := 8.0
	var W := c.size.x
	var H := c.size.y
	var lit := Color(0.23, 0.24, 0.285)
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W - w, w), Vector2(w, w)]), lit)
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, w), Vector2(w, H - w), Vector2(0, H)]), Color(0.18, 0.19, 0.23))
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, H), Vector2(w, H - w), Vector2(W - w, H - w), Vector2(W, H)]), Color(0.055, 0.06, 0.075))
	c.draw_colored_polygon(PackedVector2Array([Vector2(W, 0), Vector2(W, H), Vector2(W - w, H - w), Vector2(W - w, w)]), Color(0.085, 0.09, 0.11))
	# the stone's grain: a few hundred specks of light and dark along the four bands (the same every time)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4417
	for i in 360:
		var side := i % 4
		var along := rng.randf()
		var across := rng.randf() * (w - 1.0)
		var p := Vector2(along * W, across) if side == 0 else (Vector2(across, along * H) if side == 1 else (Vector2(along * W, H - 1.0 - across) if side == 2 else Vector2(W - 1.0 - across, along * H)))
		c.draw_rect(Rect2(p, Vector2(2.0 + rng.randf() * 3.0, 1.0)), Color(1, 1, 1, 0.07) if rng.randf() < 0.5 else Color(0, 0, 0, 0.16))
	# a lit inner edge and a dark outer one, and the gold hairline of the old frame, dim
	c.draw_rect(Rect2(Vector2(w, w), Vector2(W - 2.0 * w, H - 2.0 * w)), Color(0.02, 0.022, 0.03, 0.9), false, 1.5)
	c.draw_polyline(PackedVector2Array([Vector2(w, H - w), Vector2(w, w), Vector2(W - w, w)]), Color(0.42, 0.43, 0.5, 0.55), 1.0)
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(AdvancementData.color("frame_gold"), 0.5), false, 1.0)


func _build_titles() -> void:
	var strip := _r("title_strip")
	var t := AdvancementTheme.label(AdvancementData.word("title").to_upper(), 24, AdvancementData.color("frame_trim"), "head2", true)
	t.name = "WindowTitle"
	t.add_theme_font_override("font", AdvancementTheme.spaced("head2", 3))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 0)
	t.position = Vector2(strip.position.x + 240.0, strip.position.y + 4.0)
	t.size = Vector2(strip.size.x - 480.0, strip.size.y - 6.0)
	_stage.add_child(t)
	# the ribbon: the preview's honest word
	var rr := _r("ribbon")
	var rib := Panel.new()
	rib.name = "Ribbon"
	rib.add_theme_stylebox_override("panel", AdvancementTheme.box(Color(0.2, 0.16, 0.08), Color(0.12, 0.095, 0.05), AdvancementData.color("frame_gold"), 1.5, 4.0))
	_place(rib, rr)
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(rib)
	var rl := AdvancementTheme.label(AdvancementData.word("ribbon"), AdvancementTheme.S_SMALL, Color(0.96, 0.88, 0.62), "body2")
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rl.size = rr.size
	rib.add_child(rl)
	var xb := AdvancementTheme.GlyphButton.new("close")
	xb.name = "Close"
	_place(xb, _r("close"))
	_hint(xb, AdvancementData.word("buttons.close"))
	xb.pressed.connect(request_close)
	_stage.add_child(xb)
	# the portrait medallion over the frame's corner
	var pr := _r("portrait")
	var disc := Control.new()
	disc.name = "Portrait"
	_place(disc, pr)
	disc.mouse_filter = Control.MOUSE_FILTER_STOP
	disc.draw.connect(func() -> void:
		var ctr := disc.size * 0.5
		var r := disc.size.x * 0.5
		var gold := AdvancementData.color("frame_gold")
		disc.draw_circle(ctr + Vector2(2.0, 6.0), r + 2.0, Color(0, 0, 0, 0.5))
		disc.draw_circle(ctr, r, Color(0.04, 0.045, 0.06))
		# a stone ring (lit from the top left), then a gold line inside it
		disc.draw_arc(ctr, r - 4.5, 0, TAU, 64, Color(0.15, 0.16, 0.2), 9.0, true)
		disc.draw_arc(ctr, r - 2.0, deg_to_rad(180.0), deg_to_rad(300.0), 24, Color(0.4, 0.41, 0.47), 3.0, true)
		disc.draw_arc(ctr, r - 6.5, deg_to_rad(0.0), deg_to_rad(120.0), 24, Color(0.05, 0.055, 0.07), 3.0, true)
		disc.draw_arc(ctr, r - 9.5, 0, TAU, 64, Color(gold, 0.95), 2.5, true)
		disc.draw_arc(ctr, r - 0.8, 0, TAU, 64, Color(0.02, 0.022, 0.03, 0.9), 1.6, true))
	_stage.add_child(disc)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.position = Vector2(7, 7)
	_portrait.size = pr.size - Vector2(14, 14)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(_portrait)
	disc.mouse_entered.connect(func() -> void: _show_class_tip(disc))
	disc.mouse_exited.connect(_hide_tip)
	# the tree titles and their point readouts
	_title_l = _tree_title("TitleLeft", _r("left_title"))
	_title_r = _tree_title("TitleRight", _r("right_title"))
	# the element's own colour as the accent: a line under each title
	var ac := AdvancementData.element_color(element).lightened(0.15)
	for r: Rect2 in [_r("left_title"), _r("right_title")]:
		var line := TextureRect.new()
		line.texture = AdvancementTheme.accent_tex(ac)
		line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		line.stretch_mode = TextureRect.STRETCH_SCALE
		line.size = Vector2(300, 3)
		line.position = Vector2(r.position.x - 150.0, r.position.y + 21.0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(line)
	var pl := _points("PointsLeft", _r("left_points"))
	_points_l = pl[0]
	_num_l = pl[1]
	_cap_l = pl[2]
	var pr2 := _points("PointsRight", _r("right_points"))
	_points_r = pr2[0]
	_num_r = pr2[1]
	_cap_r = pr2[2]
	_num_l.add_theme_color_override("font_color", AdvancementData.color("points_left"))
	_num_r.add_theme_color_override("font_color", AdvancementData.color("points_spent"))
	_points_l.mouse_entered.connect(func() -> void: _show_plain(_points_l, AdvancementData.word("points.left_tip") % [work.left(), AdvancementData.budget()]))
	_points_l.mouse_exited.connect(_hide_tip)
	_points_r.mouse_entered.connect(func() -> void: _show_plain(_points_r, AdvancementData.word("points.spent_tip") % work.spent("right")))
	_points_r.mouse_exited.connect(_hide_tip)


func _tree_title(nm: String, centre: Rect2) -> Label:
	var l := AdvancementTheme.label("", AdvancementTheme.S_TITLE, AdvancementData.color("title"), "head", true)
	l.name = nm
	l.add_theme_font_override("font", AdvancementTheme.spaced("head", 4))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(520, 56)
	l.position = centre.position - Vector2(260, 28)
	_stage.add_child(l)
	return l


func _points(nm: String, at: Rect2) -> Array:
	var h := HBoxContainer.new()
	h.name = nm
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	h.size = Vector2(320, 40)
	h.position = at.position - Vector2(160, 20)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	_stage.add_child(h)
	var num := AdvancementTheme.label("0", AdvancementTheme.S_POINTS, AdvancementData.color("points_left"), "head", true)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(num)
	var cap := AdvancementTheme.label("", AdvancementTheme.S_SMALL + 1, AdvancementData.color("text_dim"), "body2", true)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mg := MarginContainer.new()
	mg.add_theme_constant_override("margin_top", 7)
	mg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg.add_child(cap)
	h.add_child(mg)
	return [h, num, cap]


func _build_trees() -> void:
	_tree_l = AdvancementTree.new()
	_tree_l.name = "TreeLeft"
	_tree_l.setup(element, "left", work, saved)
	_stage.add_child(_tree_l)
	_tree_r = AdvancementTree.new()
	_tree_r.name = "TreeRight"
	_tree_r.setup(element, "right", work, saved)
	_stage.add_child(_tree_r)
	for t: AdvancementTree in [_tree_l, _tree_r]:
		t.tip_wanted.connect(_on_tree_tip)
		t.wear_requested.connect(wear_id)
		t.take_off_requested.connect(take_off_id)
	_rail = AdvancementRail.new()
	_rail.name = "Rail"
	_place(_rail, _r("rail"))
	_rail.setup(element, work.style)
	_rail.tip_wanted.connect(_on_rail_tip)
	_stage.add_child(_rail)


## The calm ground behind each tree (its nodes and its title) and the rail: the backdrop shader's rects, in the picture's UV.
func _calm_painting() -> void:
	if _backdrop == null or not _backdrop.material is ShaderMaterial:
		return
	var mat := _backdrop.material as ShaderMaterial
	var origin := _backdrop.position + (_backdrop.get_parent() as Control).position
	var psz := _backdrop.size
	var L := AdvancementData.layout()
	var grow := float(L.get("calm_margin", 22.0))
	var rects: Array = []
	for t: AdvancementTree in [_tree_l, _tree_r]:
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		var half := float(t.plan.icon) * 0.5
		for it: Dictionary in t.plan.items:
			var p: Vector2 = t.position + (it.pos as Vector2)
			lo = lo.min(p - Vector2(half, half))
			hi = hi.max(p + Vector2(half, half))
		if lo.x == INF:
			continue
		lo.y = minf(lo.y, _r("left_title").position.y - 18.0)
		rects.append(Rect2(lo, hi - lo).grow(grow))
	rects.append(_r("rail").grow(grow * 0.5))
	var names := ["zone_a", "zone_b", "zone_c"]
	for i in names.size():
		var v := Vector4.ZERO
		if i < rects.size():
			var r: Rect2 = rects[i]
			v = Vector4((r.position.x - origin.x) / psz.x, (r.position.y - origin.y) / psz.y, r.size.x / psz.x, r.size.y / psz.y)
		mat.set_shader_parameter(names[i], v)
	mat.set_shader_parameter("aspect", psz.x / maxf(psz.y, 1.0))
	mat.set_shader_parameter("feather", float(L.get("calm_feather", 70.0)) / psz.x)
	mat.set_shader_parameter("dark", float(L.get("calm_dark", 0.52)))
	mat.set_shader_parameter("desat", float(L.get("calm_desat", 0.6)))
	mat.set_shader_parameter("blur_px", float(L.get("calm_blur_px", 3.0)))


func _build_bottom() -> void:
	var s := _stage
	# left: the loadout being edited, the premade builds
	_loadout_drop = AdvancementDrop.new()
	_loadout_drop.name = "LoadoutDrop"
	var lr := _r("loadout_dropdown")
	_place(_loadout_drop, Rect2(lr.position, lr.size - Vector2(46, 0)))
	s.add_child(_loadout_drop)
	_loadout_drop.setup(s)
	_loadout_drop.picked.connect(func(id: String) -> void: switch_slot(int(id)))
	_panel_btn = AdvancementDrop.new()
	_panel_btn.name = "PanelButton"
	_place(_panel_btn, Rect2(lr.end.x - 38.0, lr.position.y, 38, lr.size.y))
	s.add_child(_panel_btn)
	_panel_btn.setup(s, "panel")
	_panel_btn.pressed.disconnect(_panel_btn.toggle)
	_panel_btn.pressed.connect(func() -> void: set_slots_open(not slots_open()))
	_hint(_panel_btn, AdvancementData.word("buttons.loadouts_panel"))
	_premade_drop = AdvancementDrop.new()
	_premade_drop.name = "PremadeDrop"
	var pr := _r("premade_dropdown")
	_place(_premade_drop, Rect2(pr.position, pr.size - Vector2(46, 0)))
	s.add_child(_premade_drop)
	_premade_drop.setup(s)
	_premade_drop.caption = AdvancementData.word("buttons.premade")
	_premade_drop.picked.connect(apply_premade)
	_code_drop = AdvancementDrop.new()
	_code_drop.name = "CodeButton"
	_place(_code_drop, Rect2(pr.end.x - 38.0, pr.position.y, 38, pr.size.y))
	s.add_child(_code_drop)
	_code_drop.setup(s, "code")
	_hint(_code_drop, AdvancementData.word("buttons.copy_code"))
	_code_drop.set_items([
		{"id": "copy", "text": AdvancementData.word("buttons.copy_code"), "sub": ""},
		{"id": "paste", "text": AdvancementData.word("buttons.paste_code"), "sub": ""}])
	_code_drop.picked.connect(func(id: String) -> void:
		if id == "copy":
			copy_code()
		else:
			paste_code())
	# the middle: search, Save Changes and its undo arrow
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = AdvancementData.word("buttons.search")
	AdvancementTheme.style_line_edit(_search, AdvancementTheme.S_BODY)
	_place(_search, _r("search"))
	_search.text_changed.connect(set_search)
	_search.text_submitted.connect(func(_t: String) -> void: _next_match())
	s.add_child(_search)
	var mag := AdvancementTheme.GlyphButton.new("search")
	mag.position = Vector2(6, 0)
	mag.size = Vector2(30, _search.size.y)
	mag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mag.focus_mode = Control.FOCUS_NONE
	_search.add_child(mag)
	_save = AdvancementTheme.button(AdvancementData.word("buttons.save"), "plate", 24)
	_save.name = "Save"
	_place(_save, _r("save"))
	_save.pressed.connect(func() -> void: save())
	s.add_child(_save)
	_undo = AdvancementTheme.GlyphButton.new("undo")
	_undo.name = "Undo"
	var sv := _r("save")
	_place(_undo, Rect2(sv.end.x + 8.0, sv.position.y, 40, sv.size.y))
	_hint(_undo, AdvancementData.word("buttons.undo"))
	_undo.pressed.connect(undo)
	s.add_child(_undo)
	# the right: Reset and Change class
	_reset = AdvancementTheme.button(AdvancementData.word("buttons.reset"), "plate", AdvancementTheme.S_BUTTON)
	_reset.name = "Reset"
	_place(_reset, _r("reset"))
	_reset.pressed.connect(reset_classic)
	s.add_child(_reset)
	_class_btn = AdvancementTheme.button(AdvancementData.word("buttons.change_class"), "plate", AdvancementTheme.S_BUTTON)
	_class_btn.name = "ChangeClass"
	_place(_class_btn, _r("change_class"))
	_class_btn.pressed.connect(open_picker)
	s.add_child(_class_btn)
	# the status line: in the bar's free band right of Save Changes, clear of the trees
	_status = AdvancementTheme.label("", AdvancementTheme.S_BODY, AdvancementData.color("text"), "body2")
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.max_lines_visible = 3
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(_status, _r("status"))
	s.add_child(_status)


func _build_tabs() -> void:
	var tr := _r("tabs")
	var tw := tr.size.x / 3.0
	var group := ButtonGroup.new()
	var defs := [["advancement", true], ["loadouts", true], ["look", false]]
	for i in 3:
		var key := String(defs[i][0])
		var b := AdvancementTheme.button(AdvancementData.word("tabs." + key), "tab", 24)
		b.name = "Tab_" + key
		b.position = tr.position + Vector2(tw * float(i), 0)
		b.size = Vector2(tw - 6.0, tr.size.y)
		if bool(defs[i][1]):
			b.toggle_mode = true
			b.button_group = group
		s_tab_set(key, b)
		_stage.add_child(b)
	_tab_adv.button_pressed = true
	_tab_adv.pressed.connect(func() -> void: set_slots_open(false))
	_tab_loadouts.pressed.connect(func() -> void: set_slots_open(true))
	_tab_look.pressed.connect(func() -> void: look_requested.emit())


func s_tab_set(key: String, b: Button) -> void:
	match key:
		"advancement":
			_tab_adv = b
		"loadouts":
			_tab_loadouts = b
		_:
			_tab_look = b


func _build_overlays() -> void:
	var sr := _r("slots_panel")
	_slots = AdvancementSlots.new()
	_slots.name = "Slots"
	_place(_slots, sr)
	_slots.visible = false
	_stage.add_child(_slots)
	_slots.setup(element)
	_slots.edit_requested.connect(switch_slot)
	_slots.wear_requested.connect(wear_slot)
	_slots.rename_requested.connect(rename_slot)
	_slots.keep_toggled.connect(keep_slot)
	_slots.close_requested.connect(func() -> void: set_slots_open(false))
	_slots.hint.connect(func(c: Control, text: String, on: bool) -> void:
		if on:
			_show_plain(c, text)
		elif _tip_for == c:
			_hide_tip())
	# the Wear bar
	var wr := _r("wear_bar")
	_wear_bar = Control.new()
	_wear_bar.name = "WearBar"
	_place(_wear_bar, wr)
	_wear_bar.visible = false
	_wear_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_wear_bar)
	var wb := Panel.new()
	wb.add_theme_stylebox_override("panel", AdvancementTheme.stone(Color(0.06, 0.065, 0.08), Color(0.04, 0.045, 0.06)))
	wb.size = wr.size
	wb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wear_bar.add_child(wb)
	_wear_fill = ColorRect.new()
	_wear_fill.color = AdvancementData.color("worn").darkened(0.15)
	_wear_fill.position = Vector2(5, 5)
	_wear_fill.size = Vector2(0, wr.size.y - 10.0)
	_wear_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wear_bar.add_child(_wear_fill)
	_wear_label = AdvancementTheme.label("", AdvancementTheme.S_BODY, Color.WHITE, "body2", true)
	_wear_label.add_theme_constant_override("outline_size", 8)
	_wear_label.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.0, 0.96))
	_wear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wear_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wear_label.size = wr.size
	_wear_bar.add_child(_wear_label)
	_tip = AdvancementTip.new()
	_tip.name = "Tip"
	_stage.add_child(_tip)
	# the short tip grows into the full one when the pointer or focus has stayed on a node a moment
	_tip_timer = Timer.new()
	_tip_timer.name = "TipTimer"
	_tip_timer.one_shot = true
	_tip_timer.wait_time = AdvancementData.layout_num("tip_full_s", 0.6)
	_tip_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_tip_timer.timeout.connect(_expand_tip)
	add_child(_tip_timer)


func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := maxf(minf(view.x / AUTHORED.x, view.y / AUTHORED.y), 0.01)
	_stage.scale = Vector2.ONE * fit
	_stage.position = (view - AUTHORED * fit) * 0.5


## Keyboard and pad: left / right / up / down inside a tree (AdvancementTree), across to the other tree and the rail,
## Tab to the other tree.
func _wire_focus() -> void:
	var l: Array = _tree_l.nodes
	var r: Array = _tree_r.nodes
	if l.is_empty() or r.is_empty():
		return
	# a node with no neighbour of its own tree on a side reaches across: the left tree's right end to the right tree, the
	# right tree's left end to the left tree, its right end to the rail (re-done each time the rail's nodes are made again)
	for n: AdvancementNode in l:
		if _crosses(n, n.focus_neighbor_right):
			var m := _tree_r.end_node(false, n.position.y)
			n.focus_neighbor_right = n.get_path_to(m)
	for n: AdvancementNode in r:
		if _crosses(n, n.focus_neighbor_left):
			var m := _tree_l.end_node(true, n.position.y)
			n.focus_neighbor_left = n.get_path_to(m)
		if _crosses(n, n.focus_neighbor_right) and not _rail.nodes.is_empty():
			var best: AdvancementNode = _rail.nodes[0]
			for rn: AdvancementNode in _rail.nodes:
				if absf(rn.position.y - n.position.y) < absf(best.position.y - n.position.y):
					best = rn
			n.focus_neighbor_right = n.get_path_to(best)
	for rn: AdvancementNode in _rail.nodes:
		var near: AdvancementNode = r[0]
		for n: AdvancementNode in r:
			if absf(n.position.y - rn.position.y) < absf(near.position.y - rn.position.y):
				near = n
		rn.focus_neighbor_left = rn.get_path_to(near)
	# Tab: the last of each tree to the first of the other
	var lo: Array = l.duplicate()
	var ro: Array = r.duplicate()
	var by_read := func(p: AdvancementNode, q: AdvancementNode) -> bool:
		if absf(p.position.y - q.position.y) > 8.0:
			return p.position.y < q.position.y
		return p.position.x < q.position.x
	lo.sort_custom(by_read)
	ro.sort_custom(by_read)
	var lf: AdvancementNode = lo[0]
	var ll: AdvancementNode = lo[lo.size() - 1]
	var rf: AdvancementNode = ro[0]
	var rl: AdvancementNode = ro[ro.size() - 1]
	ll.focus_next = ll.get_path_to(rf)
	rf.focus_previous = rf.get_path_to(ll)
	rl.focus_next = rl.get_path_to(lf)
	lf.focus_previous = lf.get_path_to(rl)


## True when `path` (a focus neighbour of `n`) is not set or leads out of n's own tree (or to a node going away).
func _crosses(n: Control, path: NodePath) -> bool:
	if path.is_empty():
		return true
	var t := n.get_node_or_null(path)
	return t == null or t.is_queued_for_deletion() or t.get_parent() != n.get_parent()


# --- refresh --------------------------------------------------------------------------------------------------------------------

func _bind_trees() -> void:
	for t: AdvancementTree in [_tree_l, _tree_r]:
		t.work = work
		t.saved = saved


func refresh_all() -> void:
	_tree_l.refresh()
	_tree_r.refresh()
	_update_points()
	_update_bar()
	_update_drops()
	if _slots != null and _slots.visible:
		_slots.refresh(slot_index)


func _refresh_class() -> void:
	var st := AdvancementData.style(work.style)
	_title_l.text = AdvancementData.title(element, "left", work.style)
	_title_r.text = AdvancementData.title(element, "right")
	_portrait.texture = AdvancementTheme.emblem(element, work.style)
	_portrait.modulate = AdvancementData.element_color(element).lightened(0.25)
	if _rail.style_id != work.style:
		_rail.set_style(work.style)
	_wire_focus()


func _update_points() -> void:
	_num_l.text = str(work.left())
	_cap_l.text = AdvancementData.word("points.left_cap")
	_num_r.text = str(work.spent("right"))
	_cap_r.text = AdvancementData.word("points.spent_cap")


func _update_bar() -> void:
	var pending := is_pending()
	_save.disabled = not pending
	_undo.visible = pending
	_reset.visible = not pending
	_reset.disabled = work.is_empty()
	_set_glow(pending)


func _set_glow(on: bool) -> void:
	if _glow_tween != null:
		_glow_tween.kill()
		_glow_tween = null
	if not on:
		AdvancementTheme.style_button(_save, "plate", 24)
		return
	_glow_box = StyleBoxFlat.new()
	_glow_box.bg_color = AdvancementData.color("button").lightened(0.08)
	_glow_box.set_corner_radius_all(5)
	_glow_box.set_border_width_all(3)
	_glow_box.border_color = AdvancementData.color("worn")
	_glow_box.shadow_color = Color(AdvancementData.color("worn"), 0.55)
	_glow_box.shadow_size = 12
	AdvancementTheme.with_margins(_glow_box, 14, 4, 14, 4)
	for s in ["normal", "hover", "pressed", "hover_pressed"]:
		_save.add_theme_stylebox_override(s, _glow_box)
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(_glow_box, "shadow_size", 18, 0.8)
	_glow_tween.tween_property(_glow_box, "shadow_size", 8, 0.8)


func _update_drops() -> void:
	var items: Array = []
	for i in AdvancementData.slot_count():
		var info: Dictionary = AdvancementStore.slot_info(element, i)
		var nm := String(info.get("name", ""))
		var text := AdvancementData.word("loadout.slot_named") % [i + 1, nm] if nm != "" else AdvancementData.word("loadout.slot") % (i + 1)
		var lo := AdvancementStore.slot(element, i)
		var sw := AdvancementData.word("slot_state." + AdvancementStore.slot_state(element, i))
		items.append({"id": str(i), "text": text, "sub": "%s · %s · %s" % [String(AdvancementData.style(lo.style).get("label", "")), AdvancementData.word("loadout.points") % [lo.cost(), AdvancementData.budget()], sw]})
	_loadout_drop.caption = String((items[slot_index] as Dictionary).text)
	_loadout_drop.set_items(items, str(slot_index))
	_premade_drop.set_items(_premade_items(), "")


func _premade_items() -> Array:
	var gs := AdvancementData.gate_state(element)
	var locked := bool(gs.get("first_win", false)) and not bool(gs.get("won", true))
	var out: Array = []
	for s: Dictionary in AdvancementData.starters(element):
		out.append({"id": String(s.id), "text": String(s.name), "sub": AdvancementData.word("reasons.gate_first_win") if locked else String(s.line), "disabled": locked})
	out.append({"id": "classic", "text": AdvancementData.word("loadout.classic_premade"), "sub": AdvancementData.word("loadout.classic_line")})
	return out


func _after_change() -> void:
	refresh_all()
	_retip()


# --- picks ----------------------------------------------------------------------------------------------------------------------

func _diff_text(d: Dictionary) -> String:
	var parts: Array = []
	var sep := AdvancementData.word("status.list_sep", ", ")
	if not (d.worn as Array).is_empty():
		parts.append(AdvancementData.word("status.worn") % _names(d.worn, sep))
	if not (d.taken_off as Array).is_empty():
		parts.append(AdvancementData.word("status.taken_off") % _names(d.taken_off, sep))
	if bool(d.style):
		parts.append(AdvancementData.word("status.class_changed") % String(AdvancementData.style(work.style).get("label", "")))
	return AdvancementData.word("status.sep", " · ").join(PackedStringArray(parts)) if not parts.is_empty() else AdvancementData.word("status.no_changes")


func _names(ids: Array, sep: String) -> String:
	var ns: Array = []
	for id: String in ids:
		ns.append(AdvancementData.name_of(id))
	return sep.join(PackedStringArray(ns))


## Wear `id` as a pending change (an option of a choice swaps with the worn one). Returns "" or the reason it cannot be.
func wear_id(id: String) -> String:
	if busy:
		return ""
	var t := _tree_l if AdvancementData.node(id).get("side", "") == "left" else _tree_r
	var snap := work.picks.duplicate()
	for rv: String in t.rivals(id):
		if work.has(rv):
			work.take_off(rv)
	var why := work.wear(id)
	if why != "":
		work.picks = snap
		t.deny(id)
		_set_status(why, AdvancementData.color("reason"))
		return why
	_set_status(_diff_text(work.diff(saved)), AdvancementData.color("pending_on"))
	_after_change()
	return ""


## Take `id` off as a pending change (and what needs it). Returns the ids taken off.
func take_off_id(id: String) -> Array:
	if busy:
		return []
	var dropped := work.take_off(id)
	if dropped.is_empty():
		return dropped
	if dropped.size() > 1:
		var rest: Array = dropped.slice(1)
		_set_status(AdvancementData.word("status.cascade") % [AdvancementData.name_of(id), _names(rest, AdvancementData.word("status.list_sep", ", "))], AdvancementData.color("text"))
	else:
		_set_status(_diff_text(work.diff(saved)), AdvancementData.color("text"))
	_after_change()
	return dropped


func apply_premade(id: String) -> void:
	if busy:
		return
	if id == "classic":
		reset_classic()
		return
	var lo := AdvancementLoadout.from_starter(element, id, work.style)
	if lo == null:
		return
	var s := AdvancementData.starter(id)
	var got := _through_the_gates(lo)
	if got.error != "":
		_set_status(String(got.error), AdvancementData.color("reason"))
		return
	work.picks = (got.kept as Array).duplicate()
	from_id = id
	from_name = String(s.get("name", ""))
	# (a build with picks held back says so in place of its line: the status is three lines)
	var back := _held_back_text(got)
	_set_status(from_name + back if back != "" else AdvancementData.word("status.premade") % [from_name, String(s.get("line", ""))], AdvancementData.color("text"))
	_after_change()


## What of `lo` the newcomer gates let through ({kept, held_back, reason, error}: AdvancementLoadout.through_gates with this
## window's gates and control scheme). A build with nothing the gates allow comes back as an error with the gate's words, so
## a premade build or a pasted code never carries what the player may not wear yet.
func _through_the_gates(lo: AdvancementLoadout) -> Dictionary:
	var t := lo.copy()
	t.gates = work.gates.duplicate()
	t.scheme = work.scheme
	t.mode = work.mode
	var got := t.through_gates(lo.picks)
	if String(got.error) == "" and (got.kept as Array).is_empty() and not (got.held_back as Array).is_empty():
		got["error"] = String(got.reason) if String(got.reason) != "" else AdvancementData.word("reasons.gate_first_win")
	return got


## " (3 held back: Opens after the Full lessons: 4 left)" for a build some of whose picks a gate keeps out; "" when none.
func _held_back_text(got: Dictionary) -> String:
	var back: Array = got.held_back
	if back.is_empty():
		return ""
	return AdvancementData.word("status.held_back") % [back.size(), String(got.reason)]


func reset_classic() -> void:
	if busy:
		return
	work.clear()
	from_id = ""
	from_name = ""
	_set_status(AdvancementData.word("status.reset"), AdvancementData.color("text"))
	_after_change()


func undo() -> void:
	if busy:
		return
	work.picks = saved.picks.duplicate()
	work.style = saved.style
	from_id = ""
	from_name = ""
	_set_status(AdvancementData.word("status.undo"), AdvancementData.color("text"))
	_refresh_class()
	_after_change()


## Write the slot being edited. Returns "" when saved (or nothing to save), else why not.
func save() -> String:
	if busy:
		return ""
	if not is_pending():
		_set_status(AdvancementData.word("status.no_changes"), AdvancementData.color("text_dim"))
		return ""
	# the gates keep out what is new (a build pasted or chosen with a gate shut, or a pick set by code): never what is saved
	var gate_why := work.valid(true, saved.picks)
	if gate_why != "":
		_set_status(gate_why, AdvancementData.color("reason"))
		return gate_why
	var nm: Variant = null
	var info: Dictionary = AdvancementStore.slot_info(element, slot_index)
	if String(info.get("name", "")) == "" and from_name != "":
		nm = from_name
	var why := AdvancementStore.save_slot(element, slot_index, work, nm, from_id)
	if why != "":
		_set_status(why, AdvancementData.color("reason"))
		return why
	var d := work.diff(saved)
	var ts: Array = work.toasts(saved)
	saved.picks = work.picks.duplicate()
	saved.style = work.style
	from_id = ""
	from_name = ""
	var line := AdvancementData.word("status.saved")
	if not (d.worn as Array).is_empty() or not (d.taken_off as Array).is_empty():
		line += AdvancementData.word("status.sep", " · ") + _diff_text(d)
	_set_status(line, AdvancementData.color("available"))
	for t: Dictionary in ts:
		_toast(String(t.text), String(t.kind))
	_after_change()
	return ""


func set_search(text: String) -> void:
	var q := text.strip_edges()
	if _search != null and _search.text != text:
		_search.text = text
	if q == "":
		_tree_l.apply_search(null)
		_tree_r.apply_search(null)
		return
	var ids := AdvancementData.search(element, q)
	_tree_l.apply_search(ids)
	_tree_r.apply_search(ids)
	_set_status(AdvancementData.word("search.count") % ids.size() if not ids.is_empty() else AdvancementData.word("search.none"), AdvancementData.color("text"))


## Search matches (non-root nodes with a lit match), in reading order.
func search_matches() -> Array:
	var out: Array = []
	for n: AdvancementNode in all_nodes():
		if n.match_glow and String(n.item.type) != "root":
			out.append(n)
	return out


func _next_match() -> void:
	var ms := search_matches()
	if ms.is_empty():
		return
	var fo := get_viewport().gui_get_focus_owner()
	var at := ms.find(fo)
	(ms[(at + 1) % ms.size()] as AdvancementNode).grab_focus()


# --- loadouts -----------------------------------------------------------------------------------------------------------------

func set_slots_open(on: bool) -> void:
	if on == slots_open():
		return
	_hide_tip()
	_slots.visible = on
	if on:
		_slots.refresh(slot_index)
		_slots.modulate.a = 0.0
		var base := _r("slots_panel").position
		_slots.position = base + Vector2(-40, 0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_slots, "position", base, 0.16).set_ease(Tween.EASE_OUT)
		tw.tween_property(_slots, "modulate:a", 1.0, 0.16)
	(_tab_loadouts if on else _tab_adv).button_pressed = true


## Edit another loadout slot (asks first when changes are pending).
func switch_slot(i: int) -> void:
	if busy or i == slot_index or i < 0 or i >= AdvancementData.slot_count():
		return
	_guard(func() -> void:
		slot_index = i
		var s := AdvancementStore.slot(element, i).with_live_context()
		saved.picks = s.picks.duplicate()
		saved.style = s.style
		work.picks = s.picks.duplicate()
		work.style = s.style
		from_id = ""
		from_name = ""
		_refresh_class()
		_after_change())


func rename_slot(i: int, text: String) -> void:
	var old := String(AdvancementStore.slot_info(element, i).get("name", ""))
	if text.strip_edges() == old:
		return
	AdvancementStore.rename(element, i, text)
	_update_drops()


func keep_slot(i: int, on: bool) -> void:
	AdvancementStore.set_keep(element, i, on)
	_update_drops()
	_slots.refresh(slot_index)


## Wear slot `i` (-1: Classic): the gold bar, then the toasts. In the paused ring it reads "Worn from the next restart".
func wear_slot(i: int) -> void:
	if busy:
		return
	_guard(func() -> void: _do_wear(i))


func _do_wear(i: int) -> void:
	busy = true
	_hide_tip()
	var secs := wear_seconds if wear_seconds >= 0.0 else AdvancementData.layout_num("wear_bar_s", 1.0)
	_wear_label.text = AdvancementData.word("wear_bar") % (i + 1) if i >= 0 else AdvancementData.word("loadout.classic")
	_wear_bar.visible = true
	_status.visible = false
	_wear_fill.size.x = 0.0
	var full := _wear_bar.size.x - 10.0
	if secs <= 0.0:
		_finish_wear(i)
		return
	var tw := create_tween()
	tw.tween_property(_wear_fill, "size:x", full, secs)
	tw.finished.connect(func() -> void: _finish_wear(i))


func _finish_wear(i: int) -> void:
	var prev := AdvancementStore.worn_loadout(element)
	AdvancementStore.wear(element, i)
	var now := AdvancementStore.worn_loadout(element)
	busy = false
	if _wear_bar != null:
		_wear_bar.visible = false
	if _status != null:
		_status.visible = true
	var line := AdvancementData.word("status.ring_restart") if get_tree() != null and get_tree().paused else AdvancementData.word("status.worn_now")
	_set_status(line, AdvancementData.color("available"))
	for t: Dictionary in now.toasts(prev):
		_toast(String(t.text), String(t.kind))
	_update_drops()
	if _slots != null and _slots.visible:
		_slots.refresh(slot_index)


# --- codes ------------------------------------------------------------------------------------------------------------------------

func copy_code() -> void:
	DisplayServer.clipboard_set(work.code())
	_set_status(AdvancementData.word("status.code_copied"), AdvancementData.color("text"))


func paste_code() -> void:
	apply_code(DisplayServer.clipboard_get())


## Read a loadout code as a pending change; "" when read, else the reason.
func apply_code(text: String) -> String:
	var lo := AdvancementLoadout.from_code(text.strip_edges())
	if lo == null or lo.element != element:
		_set_status(AdvancementData.word("status.code_bad"), AdvancementData.color("reason"))
		return AdvancementData.word("status.code_bad")
	var why := lo.valid()
	if why != "":
		_set_status(why, AdvancementData.color("reason"))
		return why
	var got := _through_the_gates(lo)
	if got.error != "":
		_set_status(String(got.error), AdvancementData.color("reason"))
		return String(got.error)
	work.picks = (got.kept as Array).duplicate()
	work.style = lo.style
	from_id = ""
	from_name = ""
	_set_status(AdvancementData.word("status.code_read") + _held_back_text(got), AdvancementData.color("text"))
	_refresh_class()
	_after_change()
	return ""


# --- the class picker -----------------------------------------------------------------------------------------------------------

func open_picker() -> void:
	if _picker != null or busy:
		return
	_hide_tip()
	_picker = AdvancementPicker.new()
	_picker.name = "Picker"
	_picker.setup(element, work.style, AUTHORED)
	_picker.picked.connect(pick_class)
	_picker.close_requested.connect(close_picker)
	_stage.add_child(_picker)
	var b := _picker.first_button()
	if b != null:
		b.grab_focus()


func close_picker() -> void:
	if _picker == null:
		return
	_picker.queue_free()
	_picker = null
	_class_btn.grab_focus()


func pick_class(style_id: String) -> void:
	var st := AdvancementData.style(style_id)
	if st.is_empty() or not AdvancementData.pickable(style_id) or not AdvancementData.style_fits(element, style_id):
		return
	work.style = style_id
	close_picker()
	_refresh_class()
	_set_status(_diff_text(work.diff(saved)), AdvancementData.color("pending_on") if is_pending() else AdvancementData.color("text"))
	_after_change()


# --- asking before leaving --------------------------------------------------------------------------------------------------------

func request_close() -> void:
	_guard(close)


## Run `next` now, or after the player has chosen Save / Discard when changes are pending.
func _guard(next: Callable) -> void:
	if not is_pending():
		next.call()
		return
	_ask(next)


func _ask(next: Callable) -> void:
	if _prompt != null:
		return
	_hide_tip()
	var words := AdvancementData.words("close_ask")
	_prompt = Control.new()
	_prompt.name = "Prompt"
	_prompt.size = AUTHORED
	_stage.add_child(_prompt)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = AUTHORED
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_prompt.add_child(dim)
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", AdvancementTheme.frame_box())
	p.size = Vector2(620, 220)
	p.position = (AUTHORED - p.size) * 0.5
	_prompt.add_child(p)
	var t := AdvancementTheme.label(String(words.get("title", "")), 36, AdvancementTheme.INK, "head")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size = Vector2(p.size.x, 48)
	t.position = Vector2(0, 30)
	p.add_child(t)
	var sub := AdvancementTheme.label(_diff_text(work.diff(saved)), AdvancementTheme.S_BODY, AdvancementData.color("text_dim"), "body")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(p.size.x - 60.0, 28)
	sub.position = Vector2(30, 80)
	sub.clip_text = true
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	p.add_child(sub)
	var keys := ["save", "discard", "keep"]
	var kinds := ["plate", "ghost", "ghost"]
	for i in 3:
		var b := AdvancementTheme.button(String(words.get(keys[i], "")), kinds[i], AdvancementTheme.S_BUTTON)
		b.name = "Ask_" + String(keys[i])
		b.size = Vector2(176, 46)
		b.position = Vector2(26.0 + float(i) * 188.0, 140)
		p.add_child(b)
		var k := String(keys[i])
		b.pressed.connect(func() -> void: _ask_choice(k, next))
		if i == 0:
			b.grab_focus()


func _ask_choice(k: String, next: Callable) -> void:
	if k == "save":
		var why := save()
		_close_prompt()
		if why == "":
			next.call()
	elif k == "discard":
		_discard()
		_close_prompt()
		next.call()
	else:
		_close_prompt()


func _close_prompt() -> void:
	if _prompt != null:
		_prompt.queue_free()
		_prompt = null


func _discard() -> void:
	work.picks = saved.picks.duplicate()
	work.style = saved.style
	_refresh_class()
	refresh_all()


# --- tooltips -------------------------------------------------------------------------------------------------------------------

func _tree_of(n: Node) -> AdvancementTree:
	var p := n
	while p != null and not p is AdvancementTree:
		p = p.get_parent()
	return p as AdvancementTree


func _stage_rect(c: Control) -> Rect2:
	var sc := _stage.get_global_transform().get_scale().x
	var tl := (c.global_position - _stage.global_position) / sc
	return Rect2(tl, c.size * (c.get_global_transform().get_scale().x / sc))


## Where a tip may stand: the painting, never the bottom bar (Search and Save Changes stay in view).
func _tip_bounds() -> Rect2:
	var fr := _r("frame")
	var top := _r("title_strip").end.y + 6.0
	return Rect2(fr.position.x + 8.0, top, fr.size.x - 16.0, _r("bottom_bar").position.y - top - 6.0)


## Whether the tip now shown is the long one (Shift held, or the stay was long enough).
func tip_is_full() -> bool:
	return _tip_shift or _tip_dwell


func _on_tree_tip(n: AdvancementNode, on: bool) -> void:
	if not on:
		if _tip_for == n:
			_hide_tip()
		return
	_tip_for = n
	_tip_dwell = false
	_tip_timer.start()
	_tip_node(n)


func _expand_tip() -> void:
	if _tip == null or not _tip.visible or not _tip_for is AdvancementNode:
		return
	_tip_dwell = true
	_retip()


func _tip_node(n: AdvancementNode) -> void:
	var t := _tree_of(n)
	var lines: Array
	var full := tip_is_full()
	var wide := false
	if String(n.item.type) == "root":
		lines = AdvancementTip.root_lines(n.item, element)
	elif n.is_choice():
		var states := {}
		for id: String in n.ids:
			states[id] = t.state_of(id)
		lines = AdvancementTip.choice_lines(n.ids, states, work)
	else:
		lines = AdvancementTip.node_lines(n.first_id(), t.state_of(n.first_id()), work, full)
		wide = full
	# a pop-out's option shows its tip beside the whole pop-out, so the other options stay in view
	var anchor: Control = n if n.get_parent() is AdvancementTree else (n.get_parent() as Control)
	_tip.show_lines(lines, _stage_rect(anchor), _tip_bounds(), AdvancementTip.WIDTH if wide else AdvancementTip.WIDTH_SHORT)


func _on_rail_tip(n: AdvancementNode, tr: Dictionary, on: bool) -> void:
	if not on:
		if _tip_for == n:
			_hide_tip()
		return
	_tip_for = n
	_tip.show_lines(AdvancementTip.trait_lines(tr), _stage_rect(n), _tip_bounds(), AdvancementTip.WIDTH_SHORT)


## A plain tip while the pointer is over `c`.
func _hint(c: Control, text: String) -> void:
	c.mouse_entered.connect(func() -> void: _show_plain(c, text))
	c.mouse_exited.connect(func() -> void:
		if _tip_for == c:
			_hide_tip())


func _show_plain(c: Control, text: String) -> void:
	_tip_for = c
	_tip.show_lines(AdvancementTip.plain_lines(text), _stage_rect(c), _tip_bounds(), AdvancementTip.WIDTH_SHORT)


func _show_class_tip(c: Control) -> void:
	var st := AdvancementData.style(work.style)
	var lines: Array = [AdvancementTip.line(String(st.get("label", "")), AdvancementTheme.INK, "head", AdvancementTheme.S_TIP_TITLE, 0.0)]
	lines.append(AdvancementTip.line(AdvancementData.word("loadout.class_line") % String(st.get("label", "")), AdvancementData.color("text_dim"), "body", AdvancementTheme.S_BODY, 2.0))
	for lv: Dictionary in AdvancementData.levers(work.style):
		lines.append(AdvancementTip.line(String(lv.line), AdvancementData.color("plus") if int(lv.sign) > 0 else AdvancementData.color("minus"), "body", AdvancementTheme.S_BODY, 4.0))
	if AdvancementData.is_live_style(work.style):
		lines.append(AdvancementTip.line(AdvancementData.word("tip.live_class"), AdvancementData.color("live"), "body2", AdvancementTheme.S_BODY, 6.0))
	_tip_for = c
	_tip.show_lines(lines, _stage_rect(c), _tip_bounds(), AdvancementTip.WIDTH)


func _hide_tip() -> void:
	_tip_for = null
	_tip_dwell = false
	if _tip_timer != null:
		_tip_timer.stop()
	if _tip != null:
		_tip.hide_tip()


## After a change, the tip under the pointer shows the new state.
func _retip() -> void:
	if _tip_for is AdvancementNode and is_instance_valid(_tip_for) and _tip.visible:
		_tip_node(_tip_for as AdvancementNode)


# --- status and toasts -------------------------------------------------------------------------------------------------------------

func _set_status(text: String, col: Color) -> void:
	if _status == null:
		return
	_status.text = text
	_status.add_theme_color_override("font_color", col)
	_status.modulate.a = 1.0
	if _status_tween != null:
		_status_tween.kill()
	_status_tween = create_tween()
	_status_tween.tween_interval(9.0)
	_status_tween.tween_property(_status, "modulate:a", 0.0, 1.0)


func _toast(text: String, kind: String) -> void:
	var sz := Vector2(340, 58)
	var arr: Variant = AdvancementData.layout().get("toast_size")
	if arr is Array and (arr as Array).size() >= 2:
		sz = Vector2(float(arr[0]), float(arr[1]))
	var base := _r("toasts").position
	var p := Panel.new()
	p.name = "Toast"
	p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := AdvancementTheme.box(Color(0.16, 0.13, 0.07, 0.97), Color(0.08, 0.065, 0.035, 0.97), AdvancementData.color("frame_trim"), 2.5, 7.0, Color(AdvancementData.color("worn"), 0.35), 3.0)
	p.add_theme_stylebox_override("panel", sb)
	var km := AdvancementTheme.kind_mark(kind)
	if km != null:
		var ic := TextureRect.new()
		ic.texture = km
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(12, 11)
		ic.size = Vector2(36, 36)
		ic.modulate = AdvancementData.color("worn")
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(ic)
	var parts := text.split(": ", true, 1)
	var cap := AdvancementTheme.label(String(parts[0]) if parts.size() > 1 else "", AdvancementTheme.S_SMALL, AdvancementData.color("worn"), "body2")
	cap.position = Vector2(58, 3)
	cap.size = Vector2(sz.x - 68.0, 22)
	p.add_child(cap)
	var nm := AdvancementTheme.label(String(parts[1]) if parts.size() > 1 else text, 25, AdvancementTheme.INK, "head2")
	nm.position = Vector2(58, 22 if parts.size() > 1 else 14)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.size = Vector2(sz.x - 68.0, 32)
	p.add_child(nm)
	p.position = Vector2(base.x - sz.x * 0.5, base.y)
	p.modulate.a = 0.0
	_stage.add_child(p)
	var rec := {"node": p, "text": text}
	_toasts.append(rec)
	var maxn := int(AdvancementData.layout().get("toast_max", 3))
	while _toasts.size() > maxn:
		var old: Dictionary = _toasts.pop_front()
		if is_instance_valid(old.node):
			(old.node as Node).queue_free()
	_layout_toasts(sz, base)
	var life := AdvancementData.layout_num("toast_s", 3.0)
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.tween_interval(life)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
	p.tree_exiting.connect(_toast_gone.bind(rec))


func _toast_gone(rec: Dictionary) -> void:
	_toasts.erase(rec)


func _layout_toasts(sz: Vector2, base: Vector2) -> void:
	var n := _toasts.size()
	for i in n:
		var rec: Dictionary = _toasts[i]
		var p: Control = rec.node
		if not is_instance_valid(p):
			continue
		var y := base.y - sz.y - float(n - 1 - i) * (sz.y + 8.0)
		var tw := p.create_tween()
		tw.tween_property(p, "position:y", y, 0.2).set_ease(Tween.EASE_OUT)


# --- input ----------------------------------------------------------------------------------------------------------------------

func _input(e: InputEvent) -> void:
	if _closing:
		return
	if e is InputEventKey and ((e as InputEventKey).keycode == KEY_SHIFT or (e as InputEventKey).physical_keycode == KEY_SHIFT) and not (e as InputEventKey).echo:
		var was := tip_is_full()
		_tip_shift = (e as InputEventKey).pressed
		if was != tip_is_full():
			_retip()
	if e.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		escape()
		return
	if e is InputEventKey or e is InputEventJoypadButton or e is InputEventJoypadMotion:
		if get_viewport().gui_get_focus_owner() == null and not _tree_l.nodes.is_empty():
			for a in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept"]:
				if e.is_action_pressed(a):
					(_tree_l.nodes[0] as AdvancementNode).grab_focus()
					get_viewport().set_input_as_handled()
					return


## One step of Esc: a list, the search text, a popped choice, the picker, the prompt, the Loadouts panel, then the window.
func escape() -> void:
	if busy:
		return
	for d: AdvancementDrop in [_loadout_drop, _premade_drop, _code_drop]:
		if d.is_open():
			d.close()
			return
	if _prompt != null:
		_close_prompt()
		return
	if _picker != null:
		close_picker()
		return
	if _search.has_focus() and _search.text != "":
		_search.text = ""
		set_search("")
		_search.release_focus()
		return
	for t: AdvancementTree in [_tree_l, _tree_r]:
		if t.close_pop(true):
			return
	if slots_open():
		set_slots_open(false)
		return
	request_close()
