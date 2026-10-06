class_name CharacterCreator
extends CanvasLayer
## The character creator: O in game, and offered at the first launch when no look is saved
## (PlayerAppearance). The game is paused while it is open.
##
## The character stands centre stage (CreatorStage, its own lit world); the camera eases in to
## the face for the face rows and out for the people, the body type and the skin; drag (or Q /
## E, the right stick) turns the figure, the mouse wheel moves between face and body.
##   Left    the people, grouped by region, each with its emblem (PeopleEmblem), the people's
##           note, and Body type 1 (male fit) / 2 (female fit).
##   Right   one row per category, "<  Label  value  N/M  >" (CreatorOptions: skin colour,
##           face, hair style, hair colour, facial hair, eyebrows, eye colour, markings,
##           earrings, nose, neck, rings, tattoos; the rows scroll when they outgrow the panel, the
##           focused one kept in view); a click on the value opens every choice (swatches for colours); the
##           period note of the focused choice below. Fine-tune opens the detailed sliders
##           (CustomizerOverlay) on the same look. Clothing (when the build has the garments
##           tab, OutfitTab) swaps the rows for the garment rows; the camera frames the whole
##           figure with its hat on (the face and hair rows show it bare-headed).
##   Top     the character's name. Bottom: Back, Randomize (the dice), Accept.
## Keys and gamepad: up / down choose a row (the people and body type rows first), left /
## right change it, R or Y randomizes, Enter or Start accepts, Esc or B goes back, the
## shoulders change the people, X the body type. While the tattoo editor (TattooPanel) is open
## those keys wait (they reached the Tattoos row under it); Esc or B closes the editor.
## Every change dresses the stage figure at once (PlayerAppearance.dress, the game's path).
## Accept applies the look to the player and saves it (AppearanceStore); Back closes without
## changes (at the first launch it keeps the default look and saves it, so the creator is
## not offered again: O opens it any time).

signal closed(accepted: bool)

const LAYER := 50
const PANEL_BG := Color(0.04, 0.045, 0.05, 0.8)
const PANEL_EDGE := Color(0.52, 0.42, 0.28, 0.6)
const GOLD := Color(0.93, 0.8, 0.52)
const TEXT := Color(0.9, 0.88, 0.82)
const DIM := Color(0.6, 0.59, 0.55)
const ROW_BG := Color(0.07, 0.075, 0.08, 0.55)
const ROW_FOCUS := Color(0.22, 0.17, 0.1, 0.9)
## The people buttons: 36 px, so six fit on a group's row and nine rows (35 peoples) with the longest
## note fit the panel at 1280 x 720.
const ICON := 36
## Group names as shown (peoples.json groups).
const GROUP_LABELS := {"Eastern Woodlands": "Eastern\nWoodlands", "Southeast Asia": "Southeast\nAsia",
		"Mixed ancestry": "Mixed\nancestry"}

var app: PlayerAppearance
var look := {}
var first_launch := false
var stage: CreatorStage
## The focused row: "people", "body" or a CreatorOptions row.
var focus_row := "face"
var _nav: Array = []
var _rows_box: VBoxContainer
## The rows' scroll: they outgrow the panel at 720 p (the jewellery rows: twelve rows and more).
var _rows_scroll: ScrollContainer
## The frame until which the focused row is kept scrolled into view (the layout settles over a frame or two).
var _scroll_until := 0
var _row_ui := {}
var _emblems := {}
var _people_buttons := {}
var _body_buttons: Array[Button] = []
var _people_name: Label
var _people_note: Label
var _note: Label
var _title: Label
var _name_edit: LineEdit
var _picker: PopupPanel
var _root: Control
var _left_panel: PanelContainer
var _people_panel: PanelContainer
var _body_panel: PanelContainer
var _drag := false
var _rng := RandomNumberGenerator.new()
var _prev_mouse := Input.MOUSE_MODE_CAPTURED
var _prev_disable_3d := false
var _fine: CustomizerOverlay
## The Tattoos row's editor (TattooPanel, over the people panel) while it is open.
var _tattoos: TattooPanel
## The place the stage's close view shows (the editor's chosen tattoo's).
var _tattoo_place := ""
var _done := false
## The garments tab (OutfitTab) when the build has it, and whether it is showing.
var _outfit_ui: Control
var _clothing := false
var _clothing_button: Button
var _right_panel: PanelContainer
var _right_spacer: Control
## Right panel widths: the option rows, the garment rows (built for a wider column).
const RIGHT_W := 360
const RIGHT_W_CLOTHING := 470
## The Rings row's view: the figure turned until the ring's hand faces the camera (CreatorOptions.ring_hand: the
## left hand, the right), on the stage's "hands" framing; it turns back to face the camera off the row.
const RING_YAW := {"l": -0.9, "r": 0.9}
var _ring_turn := false
## The Tattoos row's value width (px) before the first layout (RIGHT_W less the panel's, the row's and the arrows'
## margins and the count): the summary is fitted to it (_fitting), then to the laid-out width.
const TATTOO_VALUE_W := 200.0


## Opens the creator on the player's look (the tree pauses).
static func open(appearance: PlayerAppearance, first := false) -> CharacterCreator:
	var c := CharacterCreator.new()
	c.app = appearance
	c.first_launch = first
	c.look = appearance.look.duplicate(true) if appearance else AppearanceStore.default_look()
	(appearance.get_tree() if appearance else Engine.get_main_loop() as SceneTree).root.add_child(c)
	return c


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_prev_mouse = Input.mouse_mode
	if _prev_mouse == Input.MOUSE_MODE_HIDDEN:
		_prev_mouse = Input.MOUSE_MODE_CAPTURED   # opened under the loading screen (its hidden cursor): the game's mouse is captured
	for a in InputMap.get_actions():
		Input.action_release(a)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# the paused game world is hidden behind the creator: do not render it
	_prev_disable_3d = get_tree().root.disable_3d
	get_tree().root.disable_3d = true
	if look.is_empty():
		look = AppearanceStore.default_look()
	# a look of a people not listed shows as the listed default people (its face and colours kept); a first launch starts
	# as that people's first individual
	if not CharacterPeoples.is_listed(String(look.get("people", ""))):
		if first_launch:
			look = CreatorOptions.with_people(look, CharacterPeoples.default_people())
		else:
			look["people"] = CharacterPeoples.default_people()
	_build_ui()
	_refresh_all()
	_set_focus("face" if not first_launch else "people")


func _exit_tree() -> void:
	if not _done and is_instance_valid(get_tree().root):
		get_tree().root.disable_3d = _prev_disable_3d


## Closes the creator: `accept` applies and saves the look.
func close(accept: bool) -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(_fine):
		_fine.queue_free()
	if is_instance_valid(app):
		if accept:
			app.apply(look)
			AppearanceStore.save_current(app.look)
		elif first_launch:
			AppearanceStore.save_current(app.look)
	elif accept:
		AppearanceStore.save_current(AppearanceStore.validate(look))
	get_tree().root.disable_3d = _prev_disable_3d
	get_tree().paused = false
	for a in InputMap.get_actions():
		Input.action_release(a)
	if not "--no-capture" in OS.get_cmdline_user_args():
		Input.mouse_mode = _prev_mouse
	closed.emit(accept)
	queue_free()


# ---------------------------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------------------------

static func _panel_style(bg := PANEL_BG, edge := PANEL_EDGE, pad := 12.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


static func _label(text: String, size := 14, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, min_size: Vector2, cb: Callable, size := 16) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", GOLD)
	var n := _panel_style(Color(0.1, 0.1, 0.1, 0.85), PANEL_EDGE, 6.0)
	var h := _panel_style(Color(0.18, 0.15, 0.1, 0.9), GOLD, 6.0)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.pressed.connect(cb)
	return b


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	# the stage fills the screen behind the panels
	var svc := SubViewportContainer.new()
	svc.name = "Stage"
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.gui_input.connect(_on_stage_input)
	_root.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	# temporal AA as in the game: the beard shells' dithered coverage needs it
	sv.use_taa = true
	sv.process_mode = Node.PROCESS_MODE_ALWAYS
	svc.add_child(sv)
	stage = CreatorStage.new()
	sv.add_child(stage)
	_build_left()
	_build_right()
	_build_top()
	_build_bottom()
	_picker = PopupPanel.new()
	_picker.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.055, 0.06, 0.96), GOLD, 10.0))
	_root.add_child(_picker)


func _build_left() -> void:
	_left_panel = PanelContainer.new()
	_left_panel.name = "PeoplePanel"
	_left_panel.add_theme_stylebox_override("panel", _panel_style())
	_left_panel.anchor_top = 0.0
	_left_panel.anchor_bottom = 1.0
	_left_panel.offset_left = 16
	_left_panel.offset_top = 16
	_left_panel.offset_right = 16 + 372
	_left_panel.offset_bottom = -92
	_root.add_child(_left_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_left_panel.add_child(vb)
	_title = _label("Character", 22, GOLD)
	vb.add_child(_title)
	_people_panel = PanelContainer.new()
	_people_panel.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4.0))
	vb.add_child(_people_panel)
	var groups := VBoxContainer.new()
	groups.add_theme_constant_override("separation", 2)
	_people_panel.add_child(groups)
	for g: String in CharacterPeoples.listed_groups():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		groups.add_child(row)
		var gl := _label(String(GROUP_LABELS.get(g, g)), 12, DIM)
		gl.custom_minimum_size = Vector2(92, 0)
		gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(gl)
		for p: Dictionary in CharacterPeoples.listed_peoples(g):
			var pid := String(p.id)
			var b := Button.new()
			b.custom_minimum_size = Vector2(ICON, ICON)
			b.flat = true
			b.focus_mode = Control.FOCUS_NONE
			b.tooltip_text = "%s\n%s" % [p.label, CreatorOptions.emblem_name(pid)]
			var em := PeopleEmblem.new(pid)
			em.set_anchors_preset(Control.PRESET_FULL_RECT)
			b.add_child(em)
			b.mouse_entered.connect(func() -> void: em.hovered = true)
			b.mouse_exited.connect(func() -> void: em.hovered = false)
			b.pressed.connect(func() -> void:
				_set_focus("people")
				_choose_people(pid))
			row.add_child(b)
			_emblems[pid] = em
			_people_buttons[pid] = b
	_people_name = _label("", 20, GOLD)
	vb.add_child(_people_name)
	_people_note = _label("", 12, DIM)
	_people_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_people_note.custom_minimum_size = Vector2(340, 0)
	vb.add_child(_people_note)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sp)
	_body_panel = PanelContainer.new()
	_body_panel.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4.0))
	vb.add_child(_body_panel)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 8)
	_body_panel.add_child(bh)
	var bl := _label("Body type", 14, TEXT)
	bl.custom_minimum_size = Vector2(104, 0)
	bh.add_child(bl)
	for bt in [1, 2]:
		var b := _button(str(bt), Vector2(64, 40), func() -> void:
			_set_focus("body")
			_choose_body(bt), 18)
		b.tooltip_text = "Body type %d: the %s fit" % [bt, "male" if bt == 1 else "female"]
		bh.add_child(b)
		_body_buttons.append(b)


func _build_right() -> void:
	var panel := PanelContainer.new()
	panel.name = "OptionsPanel"
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -16 - RIGHT_W
	panel.offset_right = -16
	panel.offset_top = 16
	panel.offset_bottom = -92
	_root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	vb.add_child(_label("Appearance", 22, GOLD))
	_rows_scroll = ScrollContainer.new()
	_rows_scroll.name = "RowsScroll"
	_rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_rows_scroll)
	_rows_scroll.sort_children.connect(func() -> void: _scroll_to_focus.call_deferred())
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 3)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_scroll.add_child(_rows_box)
	_right_panel = panel
	# (the rows' scroll fills the height now; the spacer stays hidden)
	_right_spacer = Control.new()
	_right_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_spacer.visible = false
	vb.add_child(_right_spacer)
	_note = _label("", 12, DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(330, 0)
	_note.max_lines_visible = 3
	vb.add_child(_note)
	# clothing: the garments tab of the outfit build (OutfitTab), when this build has it
	var outfit_script := _global_script("OutfitTab")
	if outfit_script and outfit_script.has_method("create") and PlayerOutfit.enabled():
		_outfit_ui = outfit_script.call("create", func() -> Dictionary: return look, func() -> void: stage.show_look(look, false))
		_outfit_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_outfit_ui.visible = false
		vb.add_child(_outfit_ui)
		vb.move_child(_outfit_ui, _rows_scroll.get_index() + 1)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)
	var fine := _button("Fine-tune...", Vector2(0, 32), _open_fine_tune, 14)
	fine.tooltip_text = "Every face feature, skin, eye and hair value on sliders"
	fine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(fine)
	if _outfit_ui:
		_clothing_button = _button("Clothing", Vector2(0, 32), func() -> void: _show_clothing(not _clothing), 14)
		_clothing_button.name = "Clothing"
		_clothing_button.tooltip_text = "Garments over the frontier clothes"
		_clothing_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(_clothing_button)


static func _global_script(cls: String) -> Script:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == cls:
			return load(String(c.path)) as Script
	return null


## Clothing on: the garment rows replace the option rows and the camera frames the whole
## figure, hat and all; off: back to the option rows.
func _show_clothing(on: bool) -> void:
	if _outfit_ui == null:
		return
	_clothing = on
	_outfit_ui.visible = on
	_rows_box.visible = not on
	_rows_scroll.visible = not on
	_right_panel.offset_left = -16 - (RIGHT_W_CLOTHING if on else RIGHT_W)
	_clothing_button.text = "Appearance" if on else "Clothing"
	if on:
		if _outfit_ui.has_method("refresh"):
			_outfit_ui.call("refresh")
		_set_focus("clothing")
	else:
		_set_focus("face")
	stage.show_look(look, not on)


func _build_top() -> void:
	_name_edit = LineEdit.new()
	_name_edit.name = "Name"
	_name_edit.placeholder_text = "Name"
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.max_length = CreatorOptions.NAME_MAX
	_name_edit.add_theme_font_size_override("font_size", 20)
	_name_edit.add_theme_color_override("font_color", GOLD)
	_name_edit.add_theme_stylebox_override("normal", _panel_style(Color(0.04, 0.045, 0.05, 0.7), PANEL_EDGE, 8.0))
	_name_edit.add_theme_stylebox_override("focus", _panel_style(Color(0.08, 0.07, 0.05, 0.85), GOLD, 8.0))
	_name_edit.anchor_left = 0.5
	_name_edit.anchor_right = 0.5
	_name_edit.offset_left = -150
	_name_edit.offset_right = 150
	_name_edit.offset_top = 18
	_name_edit.offset_bottom = 58
	_name_edit.text_changed.connect(func(t: String) -> void: look["name"] = CreatorOptions.clean_name(t))
	_name_edit.text_submitted.connect(func(_t: String) -> void: _name_edit.release_focus())
	_root.add_child(_name_edit)


func _build_bottom() -> void:
	var back := _button("Back", Vector2(150, 46), func() -> void: close(false), 18)
	back.name = "Back"
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.offset_left = 16
	back.offset_right = 166
	back.offset_top = -70
	back.offset_bottom = -24
	_root.add_child(back)
	var accept := _button("Accept", Vector2(170, 46), func() -> void: close(true), 18)
	accept.name = "Accept"
	accept.anchor_left = 1.0
	accept.anchor_right = 1.0
	accept.anchor_top = 1.0
	accept.anchor_bottom = 1.0
	accept.offset_left = -186
	accept.offset_right = -16
	accept.offset_top = -70
	accept.offset_bottom = -24
	_root.add_child(accept)
	var dice := _button("", Vector2(56, 56), _randomize)
	dice.name = "Randomize"
	dice.tooltip_text = "Randomize (R): a new individual of this people"
	var icon := DiceIcon.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dice.add_child(icon)
	dice.anchor_left = 0.5
	dice.anchor_right = 0.5
	dice.anchor_top = 1.0
	dice.anchor_bottom = 1.0
	dice.offset_left = -28
	dice.offset_right = 28
	dice.offset_top = -86
	dice.offset_bottom = -30
	_root.add_child(dice)
	var hint := _label("Drag to turn   Wheel: face / body   Arrows: choose and change   R: random", 12, DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -260
	hint.offset_right = 260
	hint.offset_top = -24
	hint.offset_bottom = -6
	_root.add_child(hint)


## A die face, drawn (the Randomize button).
class DiceIcon:
	extends Control

	func _draw() -> void:
		var s := minf(size.x, size.y) * 0.62
		var r := Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.9, 0.86, 0.76)
		sb.set_corner_radius_all(int(s * 0.2))
		draw_style_box(sb, r)
		var pip := Color(0.12, 0.1, 0.08)
		var c := r.get_center()
		var d := s * 0.26
		for o: Vector2 in [Vector2.ZERO, Vector2(-d, -d), Vector2(d, d), Vector2(-d, d), Vector2(d, -d)]:
			draw_circle(c + o, s * 0.085, pip)


func _make_row(row: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Row_" + row
	panel.custom_minimum_size = Vector2(0, 46)
	panel.add_theme_stylebox_override("panel", _panel_style(ROW_BG, Color(0, 0, 0, 0), 4.0))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	panel.add_child(hb)
	var left := _button("<", Vector2(34, 38), func() -> void:
		_set_focus(row)
		_step(row, -1), 18)
	left.name = "Prev"
	hb.add_child(left)
	var mid := Button.new()
	mid.name = "Value"
	mid.flat = true
	mid.focus_mode = Control.FOCUS_NONE
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.pressed.connect(func() -> void:
		_set_focus(row)
		_open_picker(row))
	hb.add_child(mid)
	var inner := HBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 8)
	mid.add_child(inner)
	var chip := ColorRect.new()
	chip.custom_minimum_size = Vector2(16, 16)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(chip)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", -2)
	inner.add_child(texts)
	var title := _label(String(CreatorOptions.ROW_LABELS.get(row, row)), 12, DIM)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(title)
	var value := _label("", 15, TEXT)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(value)
	if row == Tattoos.ROW:
		# (the summary that fits, again once the layout has given the value its width)
		value.resized.connect(func() -> void: value.text = _fitting(value, Tattoos.summaries(look)))
	var count := _label("", 13, DIM)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(count)
	var right := _button(">", Vector2(34, 38), func() -> void:
		_set_focus(row)
		_step(row, 1), 18)
	right.name = "Next"
	hb.add_child(right)
	_row_ui[row] = {"panel": panel, "value": value, "count": count, "chip": chip, "title": title}
	return panel


# ---------------------------------------------------------------------------------------------
# State -> UI
# ---------------------------------------------------------------------------------------------

func _refresh_all() -> void:
	var rows := CreatorOptions.rows(look)
	if rows != _row_ui.keys():
		for c in _rows_box.get_children():
			# (out of the box at once: the new rows take their names, Row_<row>, while the old wait to be freed)
			_rows_box.remove_child(c)
			c.queue_free()
		_row_ui.clear()
		for r: String in rows:
			_rows_box.add_child(_make_row(r))
	_nav = ["people", "body"] + rows
	if not focus_row in _nav and focus_row != "clothing":
		focus_row = "face"
	var pid := String(look.get("people", ""))
	for id: String in _emblems:
		(_emblems[id] as PeopleEmblem).selected = id == pid
	var p := CharacterPeoples.people(pid)
	_people_name.text = String(p.get("label", "Custom"))
	var em := CreatorOptions.emblem_name(pid)
	_people_note.text = String(p.get("note", "")) + ("\nEmblem: %s." % em if not em.is_empty() else "") \
			+ ("\nArtistic licence: %s" % p.licence_note if p.get("licence_note") is String else "")
	var bt := CreatorOptions.body_type(look)
	for i in _body_buttons.size():
		var sel := i + 1 == bt
		_body_buttons[i].add_theme_stylebox_override("normal", _panel_style(Color(0.22, 0.17, 0.1, 0.95) if sel else Color(0.1, 0.1, 0.1, 0.85),
				GOLD if sel else PANEL_EDGE, 6.0))
		_body_buttons[i].add_theme_color_override("font_color", GOLD if sel else TEXT)
	_name_edit.text = String(look.get("name", ""))
	_title.text = "New character" if first_launch else "Character"
	# the tattoo editor, when open, on the new look (the dice and Fine-tune replace it; the tattoos are kept)
	if is_instance_valid(_tattoos):
		_tattoos.refresh()
		_tattoo_reveal(_tattoos.selected_place())
	for r: String in rows:
		_refresh_row(r)
	if _clothing and _outfit_ui.has_method("refresh"):
		_outfit_ui.call("refresh")
	_refresh_focus()
	stage.show_look(look, not _clothing)


func _refresh_row(row: String) -> void:
	var ui: Dictionary = _row_ui.get(row, {})
	if ui.is_empty():
		return
	var opts := CreatorOptions.options(row, look)
	var i := CreatorOptions.current(row, look, opts)
	(ui.value as Label).text = CreatorOptions.label(row, look, i, opts)
	(ui.count as Label).text = "%s/%d" % [str(i + 1) if i >= 0 else "-", opts.size()]
	if row == Tattoos.ROW:
		# the tattoos worn, not the newest one's design: the longest summary that fits the row (the count says how many)
		(ui.value as Label).text = _fitting(ui.value as Label, Tattoos.summaries(look))
		(ui.count as Label).text = "%d/%d" % [Tattoos.list(look).size(), Tattoos.max_count()]
	var chip := ui.chip as ColorRect
	var has_color := i >= 0 and (opts[i] as Dictionary).has("color")
	chip.visible = has_color or row in ["skin", "hair_color", "eyes"]
	if has_color:
		chip.color = opts[i].color
	elif row == "skin":
		chip.color = BodyMaterials.tone_color(float(look.get("melanin", 0.3)), look.get("undertone", "neutral"))
	if row == focus_row:
		_refresh_note()


## The first of `forms` (longest first) that fits `label`'s width in its font (the last when none does); before the
## first layout, TATTOO_VALUE_W.
static func _fitting(label: Label, forms: Array) -> String:
	if forms.is_empty():
		return ""
	var font := label.get_theme_font("font")
	var fs := label.get_theme_font_size("font_size")
	var w := label.size.x if label.size.x > 1.0 else TATTOO_VALUE_W
	for f: String in forms:
		if font == null or font.get_string_size(f, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
			return f
	return String(forms[-1])


func _refresh_note() -> void:
	var t := ""
	if focus_row in _row_ui:
		var opts := CreatorOptions.options(focus_row, look)
		var i := CreatorOptions.current(focus_row, look, opts)
		if i >= 0:
			t = String((opts[i] as Dictionary).get("note", ""))
		# the Tattoos row while its editor is open: the note of the tattoo the editor has chosen (not the newest's)
		if focus_row == Tattoos.ROW and is_instance_valid(_tattoos) and _tattoos.selected >= 0 \
				and _tattoos.selected < Tattoos.list(look).size():
			t = String(Tattoos.design(String(Tattoos.list(look)[_tattoos.selected].get("design", ""))).get("note", t))
		# an earring or nose piece without a note of its own: the people's jewellery note
		if focus_row in ["jewellery", "jewel_ears", "jewel_nose"] and t.is_empty():
			t = String(((CreatorOptions.data().get("peoples", {}) as Dictionary).get(String(look.get("people", "")), {}) as Dictionary).get("note_jewellery", t))
	elif focus_row == "people":
		t = "Choose a people: each has its own faces, skin, eye and hair colours and period styles."
	elif focus_row == "body":
		t = "Body type 1 is the male fit, 2 the female fit."
	elif focus_row == "clothing":
		t = "Garments worn over the frontier clothes."
	_note.text = t


func _refresh_focus() -> void:
	for r: String in _row_ui:
		var sel := r == focus_row
		(_row_ui[r].panel as PanelContainer).add_theme_stylebox_override("panel",
				_panel_style(ROW_FOCUS if sel else ROW_BG, GOLD if sel else Color(0, 0, 0, 0), 4.0))
		(_row_ui[r].title as Label).add_theme_color_override("font_color", GOLD if sel else DIM)
	_people_panel.add_theme_stylebox_override("panel", _panel_style(ROW_FOCUS if focus_row == "people" else Color(0, 0, 0, 0),
			GOLD if focus_row == "people" else Color(0, 0, 0, 0), 4.0))
	_body_panel.add_theme_stylebox_override("panel", _panel_style(ROW_FOCUS if focus_row == "body" else Color(0, 0, 0, 0),
			GOLD if focus_row == "body" else Color(0, 0, 0, 0), 4.0))
	_refresh_note()
	# the focused row scrolled into view after the layout, and again after the scroll's sorts of the next frames (the
	# note below the rows grows with a longer text a frame later and shortens the scroll)
	_scroll_until = Engine.get_process_frames() + 3
	_scroll_to_focus.call_deferred()


func _scroll_to_focus() -> void:
	if Engine.get_process_frames() > _scroll_until or not focus_row in _row_ui or not is_instance_valid(_rows_scroll) \
			or not _rows_scroll.is_visible_in_tree():
		return
	var rp: Control = _row_ui[focus_row].panel
	if is_instance_valid(rp) and rp.is_inside_tree():
		_rows_scroll.ensure_control_visible(rp)


## Focuses a row and frames the camera for it (a row of the option list leaves the clothing
## view).
func _set_focus(row: String) -> void:
	if _clothing and row != "clothing":
		_show_clothing(false)
		if row == "face":
			return
	focus_row = row
	if row in CreatorOptions.FACE_ROWS:
		stage.frame("face")
	elif row in CreatorOptions.BUST_ROWS:
		stage.frame("bust")
	elif row in CreatorOptions.HANDS_ROWS and CreatorStage.FRAMES.has("hands"):
		stage.frame("hands")
	else:
		stage.frame("body")
	_ring_view(row)
	_refresh_focus()
	_tattoo_view()


## On the Rings row: the ring's hand turned to the camera (again after a change of piece); off it: facing the camera again.
func _ring_view(row: String) -> void:
	if row in CreatorOptions.HANDS_ROWS and stage.frame_name == "hands":
		stage.set_yaw(float(RING_YAW.get(CreatorOptions.ring_hand(look), 0.0)))
		_ring_turn = true
	elif _ring_turn:
		_ring_turn = false
		stage.set_yaw(0.0)


# ---------------------------------------------------------------------------------------------
# Changes
# ---------------------------------------------------------------------------------------------

func _step(row: String, d: int) -> void:
	match row:
		"clothing":
			return
		"people":
			var ids := []
			for p: Dictionary in CharacterPeoples.listed_peoples():
				ids.append(String(p.id))
			var i := ids.find(String(look.get("people", "")))
			_choose_people(String(ids[posmod(i + d, ids.size())]))
		"body":
			_choose_body(2 if CreatorOptions.body_type(look) == 1 else 1)
		_:
			CreatorOptions.step(row, look, d)
			_after_change(row)
			stage.show_look(look, not _clothing)


## The rows after a change of `row`: the face style changes the row list (Complexion) and the
## Face row's faces, so every row is refreshed; any other row refreshes itself.
func _after_change(row: String) -> void:
	if row == Tattoos.ROW:
		# (the editor, when open, shows what the row changed: the newest tattoo's design, maybe its place)
		if is_instance_valid(_tattoos):
			_tattoos.refresh()
		_tattoo_reveal(_tattoos.selected_place() if is_instance_valid(_tattoos) else "")
	if row in CreatorOptions.HANDS_ROWS and row == focus_row:
		_ring_view(row)
	if row == "face_style":
		_refresh_all()
	else:
		_refresh_row(row)


func _choose_people(pid: String) -> void:
	look = CreatorOptions.with_people(look, pid)
	_refresh_all()


func _choose_body(bt: int) -> void:
	if CreatorOptions.body_type(look) == bt:
		return
	look = CreatorOptions.with_body_type(look, bt)
	_refresh_all()


func _randomize() -> void:
	look = CreatorOptions.randomized(look, _rng)
	_refresh_all()


func _open_picker(row: String) -> void:
	if row == Tattoos.ROW:
		_open_tattoos()
		return
	for c in _picker.get_children():
		c.queue_free()
	var opts := CreatorOptions.options(row, look)
	var cur := CreatorOptions.current(row, look, opts)
	var colors := not opts.is_empty() and (opts[0] as Dictionary).has("color")
	var grid := GridContainer.new()
	grid.columns = (8 if opts.size() > 16 else 6) if colors else 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_picker.add_child(grid)
	for i in opts.size():
		var o: Dictionary = opts[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = String(o.get("label", "")) + ("\n" + String(o.note) if o.has("note") and not String(o.note).is_empty() else "")
		if colors:
			b.custom_minimum_size = Vector2(34, 30)
			b.add_theme_stylebox_override("normal", _panel_style(o.color, GOLD if i == cur else Color(0, 0, 0, 0.6), 2.0))
			b.add_theme_stylebox_override("hover", _panel_style((o.color as Color).lightened(0.1), GOLD, 2.0))
		else:
			b.text = String(o.get("label", ""))
			b.custom_minimum_size = Vector2(170, 30)
			b.add_theme_color_override("font_color", GOLD if i == cur else TEXT)
		var idx := i
		b.pressed.connect(func() -> void:
			CreatorOptions.select(row, look, idx)
			_after_change(row)
			stage.show_look(look)
			_picker.hide())
		grid.add_child(b)
	var ui: Dictionary = _row_ui.get(row, {})
	var at := Vector2i(get_viewport().get_visible_rect().size.x - 16 - 360 - 16, 80)
	if not ui.is_empty():
		var r := (ui.panel as Control).get_global_rect()
		at = Vector2i(int(r.position.x) - 8, int(r.position.y))
	_picker.reset_size()
	var sz := _picker.get_contents_minimum_size()
	_picker.popup(Rect2i(Vector2i(at.x - int(sz.x), at.y), Vector2i(sz)))


# ---------------------------------------------------------------------------------------------
# Tattoos (the Tattoos row and its editor, TattooPanel)
# ---------------------------------------------------------------------------------------------

## The stage shows the tattooed skin through the clothes (CreatorStage.reveal / bare_top) while the Tattoos row is
## focused: the places of the look's tattoos and `place`; the upper garments off for a chest or back tattoo.
func _tattoo_reveal(place := "") -> void:
	if focus_row != Tattoos.ROW or _clothing:
		stage.reveal = []
		stage.bare_top = false
		return
	var ps := Tattoos.list(look).map(func(t: Dictionary) -> String: return String(t.get("place", "")))
	if not place.is_empty():
		ps.append(place)
	stage.bare_top = Tattoos.on_torso(ps)
	stage.reveal = Tattoos.regions_of(look, place)


## After a focus change: the stage's tattoo view on or off (re-dressed when it changes), the editor closed off the row.
func _tattoo_view() -> void:
	var before := [stage.reveal.duplicate(), stage.bare_top]
	_tattoo_reveal(_tattoos.selected_place() if is_instance_valid(_tattoos) else "")
	if focus_row != Tattoos.ROW and is_instance_valid(_tattoos):
		_close_tattoos()
	if before != [stage.reveal, stage.bare_top]:
		stage.show_look(look, not _clothing)


func _open_tattoos() -> void:
	if is_instance_valid(_tattoos):
		return
	if focus_row != Tattoos.ROW:
		_set_focus(Tattoos.ROW)
	_tattoos = TattooPanel.create(func() -> Dictionary: return look)
	_tattoos.anchor_top = 0.0
	_tattoos.anchor_bottom = 1.0
	_tattoos.offset_left = 16
	_tattoos.offset_top = 16
	_tattoos.offset_right = 16 + TattooPanel.W
	_tattoos.offset_bottom = -92
	_tattoos.changed.connect(_on_tattoo_changed)
	_tattoos.closed.connect(_close_tattoos)
	_root.add_child(_tattoos)
	_left_panel.visible = false
	_on_tattoo_changed(_tattoos.selected_place())


func _close_tattoos() -> void:
	if is_instance_valid(_tattoos):
		_tattoos.queue_free()
	_tattoos = null
	_tattoo_place = ""
	_left_panel.visible = true
	stage.set_yaw(0.0)
	if focus_row == Tattoos.ROW:
		stage.frame("bust")
	_tattoo_reveal()
	stage.show_look(look, not _clothing)


## An edit in the panel: the row's text, the stage dressed to show the place, the camera on it (a close view of the
## place's skin turned to the camera, CreatorStage.focus_skin; once per place, so a turn by hand stays while editing).
func _on_tattoo_changed(place: String) -> void:
	_refresh_row(Tattoos.ROW)
	var before := [stage.reveal.duplicate(), stage.bare_top]
	_tattoo_reveal(place)
	# the same skin shown (a move, a size, a turn, the ink, the fade, another design at the place): only the skin's tattoo
	# uniforms change (CreatorStage.update_tattoos); a new place, an added or removed tattoo dresses the figure again
	if before != [stage.reveal, stage.bare_top] or not stage.update_tattoos(look):
		stage.show_look(look, not _clothing)
	if place == _tattoo_place:
		return
	_tattoo_place = place
	var view := Tattoos.view_of(place)
	if view.is_empty():
		return
	if view.has("bone") and view.has("at") and stage.focus_skin(String(view.bone), view.at, view.normal, float(view.get("dist", 0.8))):
		return
	stage.frame(String(view.get("frame", "bust")))
	stage.set_yaw(float(view.get("yaw", 0.0)))


func _open_fine_tune() -> void:
	if is_instance_valid(_fine):
		return
	visible = false
	_fine = CustomizerOverlay.edit(look, func(result: Dictionary) -> void:
		if not result.is_empty():
			look = result
		visible = true
		_refresh_all(), get_tree())


# ---------------------------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------------------------

func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
			if mb.pressed:
				_name_edit.release_focus()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			stage.frame("face" if stage.frame_name != "body" else "bust")
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			stage.frame("body" if stage.frame_name != "face" else "bust")
	elif event is InputEventMouseMotion and _drag:
		stage.turn((event as InputEventMouseMotion).relative.x * 0.012)


func _process(delta: float) -> void:
	if not visible or _done:
		return
	var turn := 0.0
	if Input.is_physical_key_pressed(KEY_Q) and not _name_edit.has_focus():
		turn -= 1.0
	if Input.is_physical_key_pressed(KEY_E) and not _name_edit.has_focus():
		turn += 1.0
	var ax := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(ax) > 0.2:
		turn += ax
	if turn != 0.0:
		stage.turn(turn * 2.2 * delta)


func _input(event: InputEvent) -> void:
	if not visible or _done or is_instance_valid(_fine):
		return
	if _picker.visible:
		if event.is_action_pressed("ui_cancel"):
			_picker.hide()
			get_viewport().set_input_as_handled()
		return
	if _name_edit.has_focus():
		if event is InputEventKey and event.pressed and (event as InputEventKey).keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB]:
			_name_edit.release_focus()
			get_viewport().set_input_as_handled()
		return
	# the tattoo editor open: Esc (B) closes it; the creator's own keys wait (the arrows and A / D stepped the Tattoos row
	# under the editor, R the dice, Enter accepted, the page keys changed the people), the editor is worked by its buttons
	if is_instance_valid(_tattoos):
		if event.is_action_pressed("ui_cancel"):
			_close_tattoos()
			get_viewport().set_input_as_handled()
		elif (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	var handled := true
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		match k.physical_keycode:
			KEY_UP, KEY_W:
				_move_focus(-1)
			KEY_DOWN, KEY_S:
				_move_focus(1)
			KEY_LEFT, KEY_A:
				_step(focus_row, -1)
			KEY_RIGHT, KEY_D:
				_step(focus_row, 1)
			KEY_R:
				if not k.echo:
					_randomize()
			KEY_ENTER, KEY_KP_ENTER:
				if not k.echo:
					close(true)
			KEY_ESCAPE:
				if not k.echo:
					close(false)
			KEY_PAGEUP:
				_step("people", -1)
			KEY_PAGEDOWN:
				_step("people", 1)
			_:
				handled = false
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_UP:
				_move_focus(-1)
			JOY_BUTTON_DPAD_DOWN:
				_move_focus(1)
			JOY_BUTTON_DPAD_LEFT:
				_step(focus_row, -1)
			JOY_BUTTON_DPAD_RIGHT:
				_step(focus_row, 1)
			JOY_BUTTON_Y:
				_randomize()
			JOY_BUTTON_X:
				_step("body", 1)
			JOY_BUTTON_LEFT_SHOULDER:
				_step("people", -1)
			JOY_BUTTON_RIGHT_SHOULDER:
				_step("people", 1)
			JOY_BUTTON_START:
				close(true)
			JOY_BUTTON_B:
				close(false)
			_:
				handled = false
	else:
		handled = false
	if handled and is_inside_tree():
		get_viewport().set_input_as_handled()


func _move_focus(d: int) -> void:
	if focus_row == "clothing":
		return
	var i := _nav.find(focus_row)
	_set_focus(String(_nav[clampi(i + d, 0, _nav.size() - 1)]))
