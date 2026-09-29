class_name HouseholdScreen
extends CanvasLayer
## The household screen (user 2026-09-28: "talk to the npc and delegate tasks either through talking or an npc
## management tab"): three tabs for the spouse. TALK: what she says, and what to say to her (how she is, what she has
## done; come along, wait, keep the house, go out; ask for cooking, butchering, foraging, firewood; this is home). TASKS:
## her role, the tasks she may take on, what she is doing, what the household keeps, her journal. STATS: her needs and
## skills, the same as the player's. Opened by E on her (Household.open) or J; Esc, J or Close shuts it. Pauses the
## game while open.

const HEAD := Color(0.93, 0.84, 0.62)
const TEXT := Color(0.9, 0.87, 0.8)
const DIM := Color(0.62, 0.58, 0.52)
const LIT := Color(0.98, 0.9, 0.55)
const TABS := [["talk", "Talk"], ["tasks", "Tasks"], ["stats", "Stats"]]
const ROLE_NAMES := {"follow": "Come with me", "stay": "Wait here", "home": "Keep the house", "outside": "Go out for the day"}
const ROLE_HINT := {"follow": "stays with you", "stay": "waits where she is", "home": "cooks and butchers what you bring home",
		"outside": "forages and gathers firewood by day"}

var house: Household
var tab := "talk"
var _was_mouse := Input.MOUSE_MODE_CAPTURED
var _content: VBoxContainer
var _tab_buttons := {}
var _say := ""


static func open_for(h: Household, start_tab := "talk") -> HouseholdScreen:
	var s := HouseholdScreen.new()
	s.house = h
	s.tab = start_tab
	h.get_tree().root.add_child(s)
	return s


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.05, 0.94)
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
	var outer := VBoxContainer.new()
	outer.custom_minimum_size = Vector2(620, 0)
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	outer.add_child(top)
	top.add_child(_label("%s  (%s)" % [house.sc.name.to_upper(), house.sc.title()], 26, HEAD))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	for t in TABS:
		var b := _button(String(t[1]), 110)
		var id: String = t[0]
		b.pressed.connect(func() -> void: _show(id))
		top.add_child(b)
		_tab_buttons[id] = b
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	var foot := HBoxContainer.new()
	outer.add_child(foot)
	foot.add_child(_label("Esc or J: close", 15, DIM))
	_say = house.greeting()
	_show(tab)


func _exit_tree() -> void:
	get_tree().paused = false
	Input.mouse_mode = _was_mouse


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(&"ui_cancel") or (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_J):
		get_viewport().set_input_as_handled()
		queue_free()


func _show(id: String) -> void:
	tab = id
	for k in _tab_buttons:
		(_tab_buttons[k] as Button).modulate = LIT if k == id else Color.WHITE
	for c in _content.get_children():
		c.queue_free()
	match id:
		"talk":
			_build_talk()
		"tasks":
			_build_tasks()
		"stats":
			_build_stats()


# ---------------------------------------------------------------- talk
func _build_talk() -> void:
	var sc := house.sc
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.11, 0.09, 0.9)
	sb.set_corner_radius_all(4)
	for m in ["content_margin_left", "content_margin_right", "content_margin_top", "content_margin_bottom"]:
		sb.set(m, 12)
	box.add_theme_stylebox_override("panel", sb)
	var l := _label("\"%s\"" % _say if _say != "" else "%s waits for you to speak." % sc.name, 20, TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(580, 0)
	box.add_child(l)
	_content.add_child(box)
	_content.add_child(_label("Ask", 17, HEAD))
	var ask := _row()
	ask.add_child(_reply("How are you?", func() -> void: _say = _how_are_you()))
	ask.add_child(_reply("What have you been doing?", func() -> void: _say = _what_done()))
	_content.add_child(_label("Tell her to", 17, HEAD))
	var roles := _row()
	for r in ["follow", "stay", "home", "outside"]:
		var b := _reply(String(ROLE_NAMES[r]), func() -> void: _say = house.set_role(r))
		if sc.role == r:
			b.modulate = LIT
		roles.add_child(b)
	_content.add_child(_label("Ask her to", 17, HEAD))
	var tasks := _row()
	for t in SpouseCore.TASKS:
		var id: String = t
		var b := _reply(String(SpouseCore.TASK_NAMES[id]), func() -> void: _say = house.order(id))
		if sc.focus == id:
			b.modulate = LIT
		tasks.add_child(b)
	_content.add_child(_label("Or", 17, HEAD))
	var more := _row()
	more.add_child(_reply("This is our home", func() -> void: _say = house.set_home_here()))
	var note := _label("%s is %s." % [sc.name, sc.status_text().to_lower()], 15, DIM)
	_content.add_child(note)


func _how_are_you() -> String:
	var sc := house.sc
	var parts := []
	for nl: Array in sc.need_lines():
		parts.append("%s %s" % [String(nl[0]).to_lower(), String(nl[1])])
	return "%s. (%s)" % [house.greeting(), ", ".join(parts)]


func _what_done() -> String:
	var j := house.sc.journal
	if j.is_empty():
		return "Nothing yet worth telling."
	return " ".join(j.slice(maxi(j.size() - 3, 0)))


func _reply(text: String, fn: Callable) -> Button:
	var b := _button(text, 0)
	b.pressed.connect(func() -> void:
		fn.call()
		_show(tab))
	return b


# ---------------------------------------------------------------- tasks
func _build_tasks() -> void:
	var sc := house.sc
	_content.add_child(_label("Right now", 17, HEAD))
	_content.add_child(_label("%s: %s" % [sc.name, sc.status_text()], 18, TEXT))
	_content.add_child(_label("Role", 17, HEAD))
	var roles := _row()
	for r in ["follow", "stay", "home", "outside"]:
		var b := _button(String(ROLE_NAMES[r]), 0)
		if sc.role == r:
			b.modulate = LIT
		b.pressed.connect(func() -> void:
			house.set_role(r)
			_show(tab))
		roles.add_child(b)
	_content.add_child(_label("%s %s." % [sc.name, ROLE_HINT[sc.role]], 15, DIM))
	_content.add_child(_label("Tasks she may take on", 17, HEAD))
	for t in SpouseCore.TASKS:
		var id: String = t
		var c := CheckBox.new()
		c.text = "%s   (%s)" % [SpouseCore.TASK_NAMES[id], "at home" if SpouseCore.TASK_ROLE[id] == "home" else "outside"]
		c.button_pressed = bool(sc.enabled[id])
		c.focus_mode = Control.FOCUS_NONE
		c.add_theme_font_size_override("font_size", 18)
		c.toggled.connect(func(on: bool) -> void:
			sc.enabled[id] = on
			if not on and sc.task == id:
				sc.cancel("told to stop"))
		_content.add_child(c)
	_content.add_child(_label("Bring meat and roots home to a storage chest: she cooks them and butchers a carcass left near the fire.", 14, DIM))
	_content.add_child(_label("The household keeps", 17, HEAD))
	var all := house.stock.all()
	if all.is_empty():
		_content.add_child(_label("Nothing yet. Put food in a storage chest at home.", 16, DIM))
	else:
		var keys := all.keys()
		keys.sort()
		var parts := []
		for k in keys:
			parts.append("%d %s" % [int(all[k]), InventoryState.name_of(String(k)).to_lower()])
		var l := _label(", ".join(parts), 16, TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(580, 0)
		_content.add_child(l)
	_content.add_child(_label("Lately", 17, HEAD))
	var j := sc.journal
	if j.is_empty():
		_content.add_child(_label("Nothing yet.", 16, DIM))
	for line in j.slice(maxi(j.size() - 8, 0)):
		var l := _label(String(line), 15, DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(580, 0)
		_content.add_child(l)


# ---------------------------------------------------------------- stats
func _build_stats() -> void:
	var sc := house.sc
	_content.add_child(_label("Needs", 17, HEAD))
	for nl: Array in sc.need_lines():
		_content.add_child(_pair(String(nl[0]), String(nl[1])))
	_content.add_child(_label("Skills (the same as yours to begin with)", 17, HEAD))
	for sl: Array in sc.skill_lines():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var n := _label(String(sl[0]), 17, TEXT)
		n.custom_minimum_size = Vector2(190, 0)
		row.add_child(n)
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = float(sl[1])
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(240, 16)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		row.add_child(_label("%s  %d" % [String(sl[2]).capitalize(), roundi(float(sl[1]))], 15, DIM))
		_content.add_child(row)


# ---------------------------------------------------------------- bits
func _row() -> HFlowContainer:
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 8)
	r.add_theme_constant_override("v_separation", 8)
	_content.add_child(r)
	return r


func _pair(a: String, b: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	var l := _label(a, 17, TEXT)
	l.custom_minimum_size = Vector2(190, 0)
	r.add_child(l)
	r.add_child(_label(b.capitalize(), 17, DIM))
	return r


func _button(text: String, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(w, 34)
	return b


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
