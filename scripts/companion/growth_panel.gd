class_name GrowthPanel
extends RefCounted
## The Family tab of the household screen (user 2026-09-28): per child a row (name, stage, age in days, what it still needs for the next
## milestone, who it is with) and its buttons: Follow me / Stay, and Teach... which opens the topic picker: every topic of the curriculum
## with what can be taught now and what the teacher lacks, for you and for the NPC parent (her lesson is the teach job, or her real job
## with the child along). Called from HouseholdScreen (`screen`); the logic is GrowthLink's.

const HEAD := Color(0.93, 0.84, 0.62)
const TEXT := Color(0.9, 0.87, 0.8)
const DIM := Color(0.62, 0.58, 0.52)
const GOOD := Color(0.62, 0.85, 0.6)
const LACK := Color(0.9, 0.6, 0.45)


static func build(screen: HouseholdScreen) -> void:
	var link := screen.house.growth
	var c: VBoxContainer = screen._content
	if link == null or screen.house.family.is_empty():
		c.add_child(screen._label("No children yet.", 16, DIM))
		return
	c.add_child(screen._label("Family", 17, HEAD))
	screen._wrapped("Children grow by milestones, not by the calendar: days in each stage, being looked after, what they are taught and what they watch you do.", 14, DIM)
	for r: Dictionary in link.rows():
		_child(screen, link, r)
	if screen.house.sc.is_male():
		var cb := CheckBox.new()
		cb.text = "%s keeps his day: teaches in the morning, works, home in the evening, takes the children along" % screen.house.sc.name
		cb.button_pressed = link.father_auto
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_font_size_override("font_size", 15)
		cb.toggled.connect(func(on: bool) -> void: link.father_auto = on)
		c.add_child(cb)
		var f := link.last_father
		if not f.is_empty() and link.father_auto:
			screen._wrapped("%s now: %s (%s)." % [screen.house.sc.name, String(f.get("act", "")), String(f.get("role", ""))], 14, DIM)


static func _child(screen: HouseholdScreen, link: GrowthLink, r: Dictionary) -> void:
	var c: VBoxContainer = screen._content
	var id := String(r.id)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var nm: Label = screen._label(String(r.name), 19, TEXT)
	nm.custom_minimum_size = Vector2(150, 0)
	head.add_child(nm)
	head.add_child(screen._label("%s, %s, %s" % [String(r.stage_name), String(r.age), "a girl" if bool(r.girl) else "a boy"], 16, HEAD))
	c.add_child(head)
	c.add_child(screen._label("   %s" % String(r["with"]), 14, DIM))
	if bool(r.adult):
		screen._wrapped("   Grown up: a full worker of the household (see the worker buttons above).", 14, GOOD)
	else:
		screen._wrapped("   %s" % String(r.hint), 14, GOOD if bool(r.ready) else DIM)
		var lines: Array = r.lines
		var parts := []
		for l: Dictionary in lines:
			parts.append(("[x] " if bool(l.ok) else "[ ] ") + String(l.text))
		if not parts.is_empty():
			screen._wrapped("   " + "   ".join(parts), 13, DIM)
	if String(r.note) != "":
		screen._wrapped("   \"%s\"" % String(r.note), 14, DIM)
	if bool(r.carried) or bool(r.worker):
		return
	var row: HFlowContainer = screen._row()
	var go: Button = screen._button("Follow me", 0)
	go.pressed.connect(func() -> void:
		screen._say = link.follow_me(id)
		screen._show(screen.tab))
	row.add_child(go)
	var st: Button = screen._button("Stay here", 0)
	st.pressed.connect(func() -> void:
		screen._say = link.stay(id)
		screen._show(screen.tab))
	row.add_child(st)
	if bool(r.can_teach):
		var tb: Button = screen._button("Teach...", 0)
		tb.pressed.connect(func() -> void:
			screen.family_child = "" if screen.family_child == id else id
			screen._show(screen.tab))
		row.add_child(tb)
	if screen.family_child == id and bool(r.can_teach):
		_picker(screen, link, id)


## The topic picker for one child.
static func _picker(screen: HouseholdScreen, link: GrowthLink, id: String) -> void:
	var c: VBoxContainer = screen._content
	var npc := screen.house.sc
	var you := link.offers(id, "you")
	var she := link.offers(id, "npc")
	c.add_child(screen._label("   Teach what?", 16, HEAD))
	for i in you.size():
		var a: Dictionary = you[i]
		var b: Dictionary = she[i]
		if bool(a.learned):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var nm: Label = screen._label("   %s%s" % [String(a.name), " (core)" if bool(a.core) else ""], 15, TEXT)
		nm.custom_minimum_size = Vector2(250, 0)
		row.add_child(nm)
		var topic := String(a.topic)
		var yb: Button = screen._button("You", 60)
		yb.disabled = not bool(a.ok)
		yb.tooltip_text = String(a.text)
		yb.pressed.connect(func() -> void:
			var line := link.teach(id, topic)
			screen.queue_free()
			if line != "":
				link.toast(line))
		row.add_child(yb)
		var sb: Button = screen._button("Ask %s" % npc.name, 0)
		sb.disabled = not bool(b.ok)
		sb.pressed.connect(func() -> void:
			screen._say = link.ask_teach(id, topic)
			screen._show(screen.tab))
		row.add_child(sb)
		var why := ""
		if not bool(a.ok):
			why = "you: %s" % String(a.text).replace("the teacher", "you")
		if not bool(b.ok):
			why += ("   " if why != "" else "") + "%s: %s" % [npc.name, String(b.text).replace("the teacher", npc.name)]
		if why == "":
			why = "%d minutes, %s" % [roundi(float(a.minutes)), "at the hearth" if String(a.where) == "home" else "out with the job"]
		row.add_child(screen._label(why, 13, DIM if (bool(a.ok) or bool(b.ok)) else LACK))
		c.add_child(row)
