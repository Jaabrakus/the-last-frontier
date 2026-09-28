extends CanvasLayer
## In-game Graphics panel: the upscaling setting (scripts/world/settings/upscaling.gd), applied
## live through EnvironmentRig.apply_viewport() and saved to user://settings.cfg.
##
## Toggle: F2 (input action "graphics_panel", registered here at runtime). The game uses F3 (HUD
## debug) and F4-F12 (AnimDebugOverlay); F2 and F1 are free. If another action already owns F2,
## F1 is used instead; the title shows the key. While the panel is open the mouse is released so
## its controls can be clicked (weapons only fire with a captured mouse); closing it (F2, Close,
## or a click outside it) captures the mouse again if it was captured before.
##
## EnvironmentRig.apply_viewport() installs it (install()) on the game window. Tool and test runs
## (a SceneTree script given with -s) get no panel unless they pass the user argument
## graphics_panel=1.

const Upscaling := preload("res://scripts/world/settings/upscaling.gd")
const ACTION := &"graphics_panel"
const KEY_CANDIDATES: Array[Key] = [KEY_F2, KEY_F1]
const NODE_NAME := "GraphicsPanel"

## EnvironmentRig: `settings` (WorldSettings), apply_viewport(), upscaling_state.
var rig: Node
var key_label := "F2"

var _root: Control
var _mode: OptionButton
var _level: OptionButton
var _active: Label
var _perf: Label
var _status: Label
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _tick := 0.0


## Adds the (hidden) panel under `env_rig` once. Called by EnvironmentRig.apply_viewport() for the
## window's viewport.
static func install(env_rig: Node) -> void:
	if env_rig == null or env_rig.get_node_or_null(NODE_NAME) != null:
		return
	if DisplayServer.get_name() == "headless":
		return
	if Upscaling.is_tool_run() and not "graphics_panel=1" in OS.get_cmdline_user_args():
		return
	var panel: CanvasLayer = load("res://scripts/world/settings/graphics_panel.gd").new()
	panel.name = NODE_NAME
	panel.set("rig", env_rig)
	env_rig.add_child(panel)


## Registers the toggle action on the first free key of KEY_CANDIDATES (kept if it exists).
static func ensure_action() -> Key:
	if InputMap.has_action(ACTION):
		for e in InputMap.action_get_events(ACTION):
			if e is InputEventKey:
				var k := (e as InputEventKey).physical_keycode
				return k if k != KEY_NONE else (e as InputEventKey).keycode
		return KEY_NONE
	var taken := {}
	for action in InputMap.get_actions():
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				taken[(e as InputEventKey).physical_keycode] = true
				taken[(e as InputEventKey).keycode] = true
	var key: Key = KEY_CANDIDATES[0]
	for k: Key in KEY_CANDIDATES:
		if not taken.has(k):
			key = k
			break
	InputMap.add_action(ACTION)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(ACTION, ev)
	return key


func _ready() -> void:
	layer = 110
	visible = false
	var key := ensure_action()
	key_label = OS.get_keycode_string(key) if key != KEY_NONE else "?"
	_build()
	_sync_controls()
	print("GFX graphics panel: %s toggles it (upscaling setting, saved to %s)" % [key_label, Upscaling.config_path])


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION) and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	set_open(not visible)


func set_open(open: bool) -> void:
	if open == visible:
		return
	visible = open
	if open:
		_mouse_before = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_sync_controls()
	elif _mouse_before == Input.MOUSE_MODE_CAPTURED and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Sets the upscaler live (and saves it unless save is false).
func set_upscaling(mode: String, level: String, save := true) -> void:
	if rig == null or rig.get("settings") == null:
		return
	var s: Object = rig.get("settings")
	s.set("upscaling", Upscaling.normalize_mode(mode))
	s.set("upscaling_quality", Upscaling.normalize_level(level))
	s.set("upscaling_source", "panel")
	rig.call("apply_viewport", rig.get_viewport())
	if save:
		var err := Upscaling.save(mode, level)
		_status.text = ("Saved to %s" % Upscaling.config_path) if err == OK \
				else "Could not save %s (error %d)" % [Upscaling.config_path, err]
	_sync_controls()


func _process(delta: float) -> void:
	if not visible:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	var fps := Engine.get_frames_per_second()
	_perf.text = "%d fps  (%.1f ms per frame)" % [fps, 1000.0 / maxf(fps, 1.0)]


# --- UI -------------------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A click outside the panel closes it (instead of reaching the game and capturing the mouse).
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_backdrop_input)
	add_child(_root)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.075, 0.9)
	sb.border_color = Color(1, 1, 1, 0.14)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(380, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -16.0 - 380.0
	panel.offset_right = -16.0
	panel.offset_top = 16.0
	_root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var title := Label.new()
	title.text = "Graphics  (%s)" % key_label
	title.add_theme_font_size_override("font_size", 18)
	col.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)

	grid.add_child(_label("Upscaling"))
	_mode = OptionButton.new()
	_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in Upscaling.MODES.size():
		var m: String = Upscaling.MODES[i]
		_mode.add_item(Upscaling.MODE_NAMES[m], i)
		var why := Upscaling.unavailable_reason(m) if m in ["metalfx", "fsr2", "fsr1"] else ""
		if why != "":
			_mode.set_item_text(i, "%s (not available)" % Upscaling.MODE_NAMES[m])
			_mode.set_item_disabled(i, true)
			_mode.set_item_tooltip(i, why)
	_mode.item_selected.connect(func(_i: int) -> void: _on_changed())
	grid.add_child(_mode)

	grid.add_child(_label("Quality"))
	_level = OptionButton.new()
	_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in Upscaling.LEVELS.size():
		_level.add_item(Upscaling.LEVEL_NAMES[Upscaling.LEVELS[i]], i)
	_level.item_selected.connect(func(_i: int) -> void: _on_changed())
	grid.add_child(_level)

	_active = _label("")
	_active.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_active.custom_minimum_size = Vector2(350, 0)
	col.add_child(_active)

	_perf = _label("")
	col.add_child(_perf)

	var hint := _label("Off is the default: native resolution with TAA, the chosen look. Upscalers render the 3D view at a lower resolution and rebuild it (more fps, slightly softer; foliage can shimmer).")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(350, 0)
	hint.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	hint.add_theme_font_size_override("font_size", 13)
	col.add_child(hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var reset := _button("Default (Off)")
	reset.pressed.connect(func() -> void: set_upscaling(Upscaling.DEFAULT_MODE, Upscaling.DEFAULT_LEVEL))
	row.add_child(reset)
	var close := _button("Close (%s)" % key_label)
	close.pressed.connect(func() -> void: set_open(false))
	row.add_child(close)

	_status = _label("")
	_status.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	_status.add_theme_font_size_override("font_size", 13)
	col.add_child(_status)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(1, 1, 1, 0.08), "hover": Color(1, 1, 1, 0.16),
				"pressed": Color(1, 1, 1, 0.24), "focus": Color(1, 1, 1, 0.08)}[state]
		sb.border_color = Color(1, 1, 1, 0.3 if state == "focus" else 0.12)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		sb.content_margin_top = 4.0
		sb.content_margin_bottom = 4.0
		b.add_theme_stylebox_override(state, sb)
	return b


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		set_open(false)
		_root.accept_event()


func _on_changed() -> void:
	set_upscaling(Upscaling.MODES[_mode.get_selected_id()], Upscaling.LEVELS[_level.get_selected_id()])


## Controls and the "Active" line from the rig's current settings and resolved state.
func _sync_controls() -> void:
	if rig == null or rig.get("settings") == null:
		return
	var s: Object = rig.get("settings")
	var mode := Upscaling.normalize_mode(str(s.get("upscaling")))
	var level := Upscaling.normalize_level(str(s.get("upscaling_quality")))
	_mode.select(Upscaling.MODES.find(mode))
	_level.select(Upscaling.LEVELS.find(level))
	_level.disabled = mode == "off"
	var st: Dictionary = rig.get("upscaling_state") if rig.get("upscaling_state") is Dictionary else {}
	var vp := rig.get_viewport()
	var out := Vector2i(vp.get_visible_rect().size) if vp else Vector2i.ZERO
	var m: String = st.get("mode", "off")
	var text := ""
	if m == "off":
		text = "Active: native %dx%d, %s" % [out.x, out.y, _preset_aa_text(s)]
	else:
		var sc: float = st.get("scale", 1.0)
		text = "Active: %s, 3D at %dx%d (%d%%) -> %dx%d" % [Upscaling.MODE_NAMES[m], roundi(out.x * sc),
				roundi(out.y * sc), roundi(sc * 100.0), out.x, out.y]
	if String(st.get("note", "")) != "":
		text += "\n" + String(st.note)
	if str(s.get("upscaling_source")) == "arg":
		text += "\nThis run was started with upscale=...; changes here still apply and are saved."
	_active.text = text


func _preset_aa_text(s: Object) -> String:
	var aa := str(s.get("antialiasing"))
	var sc := float(s.get("render_scale"))
	match aa:
		"taa":
			return "TAA"
		"metalfx":
			if Upscaling.unavailable_reason("metalfx", sc) != "":
				return "TAA"
			return "the quality preset's own MetalFX at %d%%" % roundi(sc * 100.0)
		"fxaa":
			return "FXAA"
		"msaa2x":
			return "MSAA 2x"
	return aa
