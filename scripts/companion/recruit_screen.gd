class_name RecruitScreen
extends CanvasLayer
## The talk screen for a visitor (RECRUIT; the household screen's look): who they are and where they come from, what they
## can do (their best skills, the jobs they like), their ways (traits), what they want and whether it is met now, their
## trust in you, and what you can do: talk a while, give food from the household store, offer terms (the share), give your
## word when they ask it, and ask them to join, with the honest odds and the three largest reasons. A party that joins
## together is asked through its first member. Pauses the game while open; Esc or Close shuts it.

const HEAD := Color(0.93, 0.84, 0.62)
const TEXT := Color(0.9, 0.87, 0.8)
const DIM := Color(0.62, 0.58, 0.52)
const LIT := Color(0.98, 0.9, 0.55)
const GOOD := Color(0.62, 0.82, 0.55)
const BAD := Color(0.9, 0.6, 0.45)

var link: RecruitLink
var rec_id := ""
var _was_mouse := Input.MOUSE_MODE_CAPTURED
var _content: VBoxContainer
var _title: Label
var _say := ""
var _result := ""
## The line shown is narration (what passes between you), not their words.
var _narrated := false
var _name := ""


static func open_for(l: RecruitLink, id: String) -> RecruitScreen:
	var s := RecruitScreen.new()
	s.link = l
	s.rec_id = id
	l.get_tree().root.add_child(s)
	return s


func rec() -> Dictionary:
	return Recruit.by_id(link.st, rec_id)


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
	outer.custom_minimum_size = Vector2(640, 0)
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	_title = _label("", 26, HEAD)
	outer.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 7)
	scroll.add_child(_content)
	var foot := HBoxContainer.new()
	outer.add_child(foot)
	foot.add_child(_label("Esc: close", 15, DIM))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap)
	var close := _button("Close", 100)
	close.pressed.connect(queue_free)
	foot.add_child(close)
	var c := rec()
	if not c.is_empty():
		_say = link.greet(c)
	rebuild()


func _exit_tree() -> void:
	get_tree().paused = false
	Input.mouse_mode = _was_mouse


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


func rebuild() -> void:
	for ch in _content.get_children():
		ch.queue_free()
	var c := rec()
	if c.is_empty() or not Recruit.PRESENT.has(String(c.state)):
		_title.text = _name.to_upper()
		if _say != "":
			_quote()
		_wrapped(_result if _result != "" else "They are not here any more.", 18, LIT if _result != "" else TEXT)
		return
	var row := Recruit.kind_row(String(c.kind))
	_name = String(c.name)
	_title.text = "%s  (%s)" % [String(c.name).to_upper(), String(row.get("name", c.kind))]
	_quote()
	if _result != "":
		_wrapped(_result, 16, LIT)
	# who they are
	var who := "%s, %s." % [_age_sex(c), String(row.get("desc", ""))]
	if String(c.get("story", "")) != "":
		who += " " + String(c.story)
	_wrapped(who.left(1).to_upper() + who.substr(1), 15, TEXT)
	var party := Recruit.party_of(link.st, c)
	if party.size() > 1:
		var others := []
		for p: Dictionary in party:
			if String(p.id) != rec_id:
				others.append("%s (%s)" % [String(p.name), String(Recruit.kind_row(String(p.kind)).get("name", p.kind))])
		_wrapped("Travelling with %s%s." % [", ".join(others), "; they will only stay together" if bool(c.together) else ""], 15, DIM)
	# what they want, trust, and the ask
	var lead := Recruit.leader(link.st, c)
	var o := link.odds(c)
	_content.add_child(_label("What they want", 17, HEAD))
	for e: Dictionary in o.wants:
		var t := "%s  %s%s" % ["[x]" if bool(e.met) else "[  ]", String(e.text), ("  (%s)" % e.detail) if String(e.detail) != "" else ""]
		_wrapped(t, 15, GOOD if bool(e.met) else BAD)
	var trust := Recruit.trust_of(link.main(), lead)
	var trow2 := HBoxContainer.new()
	trow2.add_theme_constant_override("separation", 10)
	var tn := _label("Trust" + ("" if lead == c else " (%s's)" % String(lead.name)), 16, TEXT)
	tn.custom_minimum_size = Vector2(150, 0)
	trow2.add_child(tn)
	var bar := ProgressBar.new()
	bar.max_value = 10.0
	bar.value = trust
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(240, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow2.add_child(bar)
	trow2.add_child(_label("%.1f of 10" % trust, 15, DIM))
	_content.add_child(trow2)
	var ask_row := _row()
	var ab := _button("Ask %s to join the household  (%d%%)" % ["them" if party.size() > 1 and bool(c.together) else String(c.name), int(o.pct)], 0)
	ab.disabled = String(o.blocked) != ""
	ab.pressed.connect(func() -> void: ask_now())
	ask_row.add_child(ab)
	if String(o.blocked) != "":
		_wrapped("Cannot ask yet: %s." % String(o.blocked), 15, BAD)
	else:
		_wrapped("%d%% with your Trade %d against %d%s." % [int(o.pct), roundi(float(o.S)), roundi(float(o.D)),
				(": " + Recruit.factors_text(o)) if not (o.mods as Array).is_empty() else ""], 15, DIM)
	# what you can do
	_content.add_child(_label("You can", 17, HEAD))
	var acts := _row()
	acts.add_child(_act("Talk a while", func() -> String: return link.talk(c), Recruit.talk_would_count(c, link.now())))
	var gk := link._gift_kind()
	var gb := _act("Give food from the store" + (" (%s)" % InventoryState.name_of(gk).to_lower() if gk != "" else ""), func() -> String: return link.gift(c))
	gb.disabled = gk == ""
	acts.add_child(gb)
	for w: Dictionary in c.wants:
		if String(w.kind) == "promise" and not bool(c.promised):
			acts.add_child(_act(String(w.get("button", "Give your word")), func() -> String: return link.promise(c)))
	_content.add_child(_label("Terms you offer", 17, HEAD))
	var terms := _row()
	for s: Dictionary in Recruit.cfg().get("shares", []):
		var rank := int(s.rank)
		var b := _act(String(s.name), func() -> String: return link.set_share(c, rank))
		if int(lead.get("share", 0)) == rank:
			b.modulate = LIT
		terms.add_child(b)
	# what they can do
	_content.add_child(_label("What they can do", 17, HEAD))
	_wrapped(_skills_text(c), 15, TEXT)
	var likes := []
	for j: String in Recruit.job_prefs(c):
		likes.append(JobBook.name_of(j).to_lower())
	_wrapped("Would take on: %s." % ", ".join(likes), 15, DIM)
	var tr := []
	for t: Variant in c.traits:
		var trow: Dictionary = Recruit.sec("traits").get(String(t), {})
		tr.append("%s (%s)" % [String(trow.get("name", t)), String(trow.get("text", ""))])
	if not tr.is_empty():
		_wrapped("Their ways: %s." % "; ".join(tr), 15, DIM)
	_wrapped("Places to sleep in the settlement: %d, %d taken." % [link.places(), link.occupants()], 14, DIM)


## The ask (the button; `r` a fixed roll for look-checks).
func ask_now(r := -1.0) -> Dictionary:
	var c := rec()
	if c.is_empty():
		return {}
	var res := link.ask(c, r)
	_say = String(res.get("line", ""))
	_narrated = false
	match String(res.outcome):
		"excellent", "success":
			_result = "They agree. %s walk round to the gate and home." % ("They" if (res.ids as Array).size() > 1 else String(c.name))
		"partial":
			_result = "Not decided. Ask again later."
		"failure":
			_result = "They refuse, for now; they think a little less of you for asking."
		"blocked":
			_result = String(res.why)
	rebuild()
	return res


func _quote() -> void:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.11, 0.09, 0.9)
	sb.set_corner_radius_all(4)
	for m in ["content_margin_left", "content_margin_right", "content_margin_top", "content_margin_bottom"]:
		sb.set(m, 10)
	box.add_theme_stylebox_override("panel", sb)
	var l := _label(_say if _narrated or _say.begins_with("\"") else "\"%s\"" % _say, 19, TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(600, 0)
	box.add_child(l)
	_content.add_child(box)


func _age_sex(c: Dictionary) -> String:
	var male := float(c.sex) >= 0.5
	if String(c.age) == "teen":
		return "a youth" if male else "a girl in her teens"
	return "a man" if male else "a woman"


func _skills_text(c: Dictionary) -> String:
	var sk: Dictionary = c.skills
	var keys := sk.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return float(sk[a]) > float(sk[b]))
	var parts := []
	var core := link.main()
	for k: Variant in keys.slice(0, 4):
		var nm := String(k).capitalize()
		var tier := ""
		if core != null:
			nm = String((core.data.skills.get(String(k), {}) as Dictionary).get("name", nm))
			tier = SurvivalSkills.tier_of_level(core, float(sk[k]))
		parts.append("%s %d%s" % [nm, roundi(float(sk[k])), (" (%s)" % tier) if tier != "" else ""])
	return ", ".join(parts)


func _act(text: String, fn: Callable, narrated := false) -> Button:
	var b := _button(text, 0)
	b.pressed.connect(func() -> void:
		_say = String(fn.call())
		_narrated = narrated
		_result = ""
		rebuild())
	return b


func _row() -> HFlowContainer:
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 8)
	r.add_theme_constant_override("v_separation", 8)
	_content.add_child(r)
	return r


func _wrapped(text: String, size: int, col: Color) -> void:
	var l := _label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(600, 0)
	_content.add_child(l)


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
