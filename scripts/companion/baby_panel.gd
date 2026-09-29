class_name BabyPanel
extends RefCounted
## The Baby section of the household screen (Talk and Stats tabs): the child's name, age, mood, a contentment and a hunger bar, who
## holds it, and the buttons: Ask her for the baby / Give the baby back / Lay the baby down (the player must have hands free: the
## weapon is put away for the baby) / Feed (when the player is the mother). The actions close the screen (the game runs on while the
## baby changes hands). Called from HouseholdScreen; `screen` is it.

const HEAD := Color(0.93, 0.84, 0.62)
const TEXT := Color(0.9, 0.87, 0.8)
const DIM := Color(0.62, 0.58, 0.52)


static func build(screen: HouseholdScreen, with_buttons := true) -> void:
	var link := screen.house.baby
	if link == null:
		return
	var inf := link.info()
	if inf.is_empty():
		return
	var c: VBoxContainer = screen._content
	c.add_child(screen._label("Baby", 17, HEAD))
	var head := screen._pair(String(inf.name), "")
	(head.get_child(1) as Label).text = "%s, a %s" % [inf.age, "girl" if inf.girl else "boy"]
	c.add_child(head)
	var st := screen._pair("Mood", "")
	(st.get_child(1) as Label).text = String(inf.status)
	c.add_child(st)
	c.add_child(_bar(screen, "Contented", float(inf.content)))
	c.add_child(_bar(screen, "Hunger", float(inf.hunger)))
	var hold := screen._pair("In the arms of", "")
	(hold.get_child(1) as Label).text = String(inf.holder_name)
	c.add_child(hold)
	if not with_buttons:
		return
	var row: HFlowContainer = screen._row()
	var who := String(inf.holder)
	if who == "spouse":
		row.add_child(_act(screen, "Ask her for the baby", func() -> String: return link.ask_for_baby()))
	elif who == "player":
		row.add_child(_act(screen, "Give the baby back", func() -> String: return link.give_back()))
		if bool(inf.has_place):
			row.add_child(_act(screen, "Lay the baby down", func() -> String: return link.lay_down()))
		if bool(inf.player_mother):
			row.add_child(_act(screen, "Feed the baby", func() -> String: return link.player_care("feed")))
	else:
		row.add_child(_act(screen, "Pick the baby up", func() -> String: return link.take_up()))
	if not bool(inf.has_place):
		c.add_child(screen._label("No cradle or bed to lay the baby in yet: build a cradle (Furniture).", 15, DIM))


static func _bar(screen: HouseholdScreen, label: String, v: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var n: Label = screen._label(label, 17, TEXT)
	n.custom_minimum_size = Vector2(190, 0)
	row.add_child(n)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(v, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(240, 16)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	return row


## A button that does `fn` (it returns the line); when the action went ahead the screen closes so the game runs on.
static func _act(screen: HouseholdScreen, text: String, fn: Callable) -> Button:
	var b: Button = screen._button(text, 0)
	b.pressed.connect(func() -> void:
		var link := screen.house.baby
		var line := String(fn.call())
		if link != null and link.last_ok or text == "Feed the baby":
			screen.queue_free()
			if line != "" and screen.house.player != null and screen.house.player.hud != null:
				screen.house.player.hud.toast(line)
		else:
			screen._say = line
			screen._show(screen.tab))
	return b
