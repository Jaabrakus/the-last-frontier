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
const TABS := [["talk", "Talk"], ["tasks", "Tasks"], ["gear", "Gear"], ["stats", "Stats"], ["family", "Family"]]   # GROWTH: the Family tab
const ROLE_NAMES := {"follow": "Come with me", "stay": "Wait here", "home": "Keep the house", "outside": "Go out for the day"}
const ROLE_HINT := {"follow": "stays with you", "stay": "waits where she is", "home": "cooks and butchers what you bring home",
		"outside": "forages and gathers firewood by day"}

var house: Household
var tab := "talk"
## The worker the tabs are about (her worker id; 0 is the wife).
var sel := 0
## GROWTH: the child whose Teach... picker is open on the Family tab.
var family_child := ""
var _was_mouse := Input.MOUSE_MODE_CAPTURED
var _content: VBoxContainer
var _tab_buttons := {}
var _say := ""
var _title: Label


func select(worker_id: int) -> void:
	sel = worker_id
	if _content != null:
		_refresh_title()
		_show(tab)


## The worker the tabs are about.
func _sc() -> SpouseCore:
	var w := house.crew().by_id(sel)
	return w if w != null else house.sc


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
	_title = _label("", 26, HEAD)
	top.add_child(_title)
	_refresh_title()
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
	_say = house.greeting(_sc())
	_show(tab)


func _refresh_title() -> void:
	var w := _sc()
	_title.text = "%s  (%s)" % [w.name.to_upper(), w.title()]


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
	_build_workers()
	match id:
		"talk":
			_build_talk()
		"tasks":
			_build_tasks()
		"gear":
			GearTab.build(self)   # (gear_tab.gd: what she wears and carries, dragged on and off)
		"stats":
			_build_stats()
		"family":
			GrowthPanel.build(self)   # GROWTH (growth_panel.gd)


# ---------------------------------------------------------------- talk
func _build_talk() -> void:
	var sc := _sc()
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
	_intimacy_block(sc, true)   # INTIMACY: the gauge, what fills it, and the yoga button (scripts/companion/tandem_link.gd)
	if sc == house.sc:
		BabyPanel.build(self)   # BABY: the child, its mood, who holds it, ask for / give back / lay down (baby_panel.gd)
	_content.add_child(_label("Ask", 17, HEAD))
	var ask := _row()
	ask.add_child(_reply("How are you?", func() -> void: _say = _how_are_you()))
	ask.add_child(_reply("What have you been doing?", func() -> void: _say = _what_done()))
	_content.add_child(_label("Tell her to", 17, HEAD))
	var roles := _row()
	for r in ["follow", "stay", "home", "outside"]:
		var b := _reply(String(ROLE_NAMES[r]), func() -> void: _say = house.set_role(r, _sc()))
		if sc.role == r:
			b.modulate = LIT
		roles.add_child(b)
	_content.add_child(_label("Ask her to", 17, HEAD))
	var tasks := _row()
	for t in JobBook.ids():
		var id: String = t
		var b := _reply(String(JobBook.name_of(id)), func() -> void: _say = house.order(id, _sc()))
		if sc.focus == id:
			b.modulate = LIT
		tasks.add_child(b)
	_content.add_child(_label("Send her out to (then point where with L)", 17, HEAD))
	var out := _row()
	for t in JobBook.ids():
		var oid: String = t
		if JobBook.role_of(oid) != "outside":
			continue
		out.add_child(_reply(String(JobBook.name_of(oid)), func() -> void:
			var b := house.body_of(_sc())
			var wo := WorkerOrders.ensure(get_tree())
			if b != null and wo != null:
				wo.ask(b, oid)
				queue_free()))
	_content.add_child(_label("Or", 17, HEAD))
	var more := _row()
	more.add_child(_reply("This is our home", func() -> void: _say = house.set_home_here()))
	var note := _label("%s is %s." % [sc.name, sc.status_text().to_lower()], 15, DIM)
	_content.add_child(note)
	if house.pregnancy != null and sc == house.sc:
		var pl := house.pregnancy.talk_line()   # PREGNANCY
		if pl != "":
			_wrapped("\"%s\"" % pl, 15, DIM)


func _how_are_you() -> String:
	var sc := _sc()
	var parts := []
	for nl: Array in sc.need_lines():
		parts.append("%s %s" % [String(nl[0]).to_lower(), String(nl[1])])
	return "%s. (%s)" % [house.greeting(_sc()), ", ".join(parts)]


func _what_done() -> String:
	var j := _sc().journal
	if j.is_empty():
		return "Nothing yet worth telling."
	return " ".join(j.slice(maxi(j.size() - 3, 0)))


func _reply(text: String, fn: Callable) -> Button:
	var b := _button(text, 0)
	b.pressed.connect(func() -> void:
		fn.call()
		if house.link != null and _sc() == house.sc:
			house.link.talked()   # INTIMACY: a reply counts as talk (once an hour)
		_show(tab))
	return b


# ---------------------------------------------------------------- intimacy (the wife's gauge; scripts/companion/intimacy.gd)
## A slim bar labelled with the level's word, the line telling what fills it, and (`with_yoga`) the yoga button with the
## reason it is off. Only for the spouse (worker 0).
func _intimacy_block(sc: SpouseCore, with_yoga: bool) -> void:
	var link := house.link
	if link == null or link.intim == null or sc != house.sc:
		return
	var it := link.intim
	link.prewarm()
	if it.anytime():
		_yoga_row(sc, link, it, with_yoga)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var n := _label("Closeness", 17, TEXT)
	n.custom_minimum_size = Vector2(190, 0)
	row.add_child(n)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = sc.intimacy
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(240, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	row.add_child(_label(it.level_word(), 15, LIT if it.full() else DIM))
	_content.add_child(row)
	if not with_yoga:
		return
	var fl := _label(it.fills_line(), 14, DIM)
	fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fl.custom_minimum_size = Vector2(580, 0)
	_content.add_child(fl)
	var why := link.yoga_gate()
	var yb := _reply("Start yoga together" if sc.is_male() else "Ask about yoga together", func() -> void: _say = link.ask())
	yb.disabled = why != ""
	if link.following():
		# she follows for yoga: the button asks for the pose (the menu opens as she comes beside you)
		yb = _reply("Choose a yoga pose", func() -> void: link.request_pose())
		why = ""
	var yrow := _row()
	yrow.add_child(yb)
	if link.following():
		yrow.add_child(_label("%s follows you until you choose." % sc.name, 15, DIM))
	elif why != "":
		yrow.add_child(_label(it.reason_text(why), 15, DIM))
	elif sc.busy():
		yrow.add_child(_label("%s will put down the work." % sc.name, 15, DIM))
	else:
		yrow.add_child(_label("Then choose the pose; the woman leads.", 15, DIM))
	var how := _reply("How are we, you and I?", func() -> void: _say = house.pick(["intimacy", "level", str(it.level_index())]))
	yrow.add_child(how)


## Yoga together at any time: one button, no gauge (Intimacy.anytime): only what is happening round you says not now.
func _yoga_row(sc: SpouseCore, link: TandemLink, it: Intimacy, with_yoga: bool) -> void:
	if not with_yoga:
		return
	var why := link.yoga_gate()
	var yb := _reply("Yoga together", func() -> void: _say = link.ask())
	yb.disabled = why != ""
	if link.following():
		yb = _reply("Choose a yoga pose", func() -> void: link.request_pose())
		why = ""
	var yrow := _row()
	yrow.add_child(yb)
	if link.following():
		yrow.add_child(_label("%s follows you until you choose." % sc.name, 15, DIM))
	elif why != "":
		yrow.add_child(_label(it.reason_text(why), 15, DIM))
	elif sc.busy():
		yrow.add_child(_label("%s will put down the work." % sc.name, 15, DIM))


# ---------------------------------------------------------------- tasks
func _build_tasks() -> void:
	var sc := _sc()
	_content.add_child(_label("Right now", 17, HEAD))
	_content.add_child(_label("%s: %s" % [sc.name, sc.status_text()], 18, TEXT))
	RecruitPanel.build(self)   # RECRUIT: a recruit's morale, terms and Send away; the places to sleep; who is camped by the fort
	_content.add_child(_label("Role", 17, HEAD))
	var roles := _row()
	for r in ["follow", "stay", "home", "outside"]:
		var b := _button(String(ROLE_NAMES[r]), 0)
		if sc.role == r:
			b.modulate = LIT
		b.pressed.connect(func() -> void:
			house.set_role(r, _sc())
			_show(tab))
		roles.add_child(b)
	_content.add_child(_label("%s %s." % [sc.name, ROLE_HINT[sc.role]], 15, DIM))
	_build_sleep(sc)
	var short := sc.shortages()
	if not short.is_empty():
		var parts := []
		for tid: String in short:
			parts.append("%s (%d of %d)" % [String(short[tid].name).to_lower(), int(short[tid].have), int(short[tid].size)])
		_wrapped("The household is short of: %s." % ", ".join(parts), 15, DIM)
	_content.add_child(_label("The chain", 17, HEAD))
	_wrapped("Each link is a job; a job takes what the one before it makes. Switch a link on for the ones who should do it: %s can do all of it, or hand parts to the others." % sc.name, 14, DIM)
	for c: Dictionary in house.crew().chain_view():
		_build_chain(c, sc)
	var nobody := house.crew().uncovered()
	if not nobody.is_empty():
		var names := []
		for id: String in nobody:
			names.append(JobBook.name_of(id))
		_wrapped("Nobody does: %s." % ", ".join(names), 14, Color(0.9, 0.6, 0.45))
	_build_fields()
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
			parts.append(StoreLedger.count_words(String(k), int(all[k])))
		var l := _label(", ".join(parts), 16, TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(580, 0)
		_content.add_child(l)
	# LEDGER: who took what out of the store, and put what in, lately (the chests' own ledgers)
	var led: Array = house.stock.recent(60) if house.stock.has_method("recent") else []
	if not led.is_empty():
		_wrapped("Lately in the store: %s." % "; ".join(StoreLedger.lines(led, StoreLedger.now(house.get_tree()), 5)), 14, DIM)
	ToolPanel.build(self)   # TOOLS: the pool: owned, out and with whom, worn, broken, jobs waiting for a tool
	_content.add_child(_label("Lately", 17, HEAD))
	var j := sc.journal
	if j.is_empty():
		_content.add_child(_label("Nothing yet.", 16, DIM))
	for line in j.slice(maxi(j.size() - 8, 0)):
		var l := _label(String(line), 15, DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(580, 0)
		_content.add_child(l)


## Her sleeping hours (user 2026-09-29: "we should be able to manage that in the task menu"): when she goes to bed and for how
## long, by the half hour, with the night, the day and the evening as one press. She rests then (the well-rested gauge fills
## whenever she sleeps) and is not given work.
func _build_sleep(sc: SpouseCore) -> void:
	_content.add_child(_label("Sleep", 17, HEAD))
	var presets := _row()
	for pr: Array in [["Night", 21.5, 8.0], ["Day", 8.0, 8.0], ["Evening", 14.0, 8.0], ["Short night", 23.0, 5.0]]:
		var b := _button(String(pr[0]), 0)
		if is_equal_approx(sc.sleep_from, float(pr[1])) and is_equal_approx(sc.sleep_h, float(pr[2])):
			b.modulate = LIT
		b.pressed.connect(func() -> void:
			var w := _sc()
			w.sleep_from = float(pr[1])
			w.sleep_h = float(pr[2])
			_show(tab))
		presets.add_child(b)
	var row := _row()
	row.add_child(_label("Goes to bed", 16, TEXT))
	row.add_child(_step(-0.5, func() -> void: _sc().sleep_from = fposmod(_sc().sleep_from - 0.5, 24.0)))
	row.add_child(_label(_clock(sc.sleep_from), 16, TEXT))
	row.add_child(_step(0.5, func() -> void: _sc().sleep_from = fposmod(_sc().sleep_from + 0.5, 24.0)))
	row.add_child(_label("for", 16, TEXT))
	row.add_child(_step(-0.5, func() -> void: _sc().sleep_h = clampf(_sc().sleep_h - 0.5, 0.0, 12.0)))
	row.add_child(_label("%s h" % String.num(sc.sleep_h, 1), 16, TEXT))
	row.add_child(_step(0.5, func() -> void: _sc().sleep_h = clampf(_sc().sleep_h + 0.5, 0.0, 12.0)))
	_content.add_child(_label("%s sleeps %s to %s. A short nap, or a sleep by day, rests just the same: bed and fire rest her faster." % [sc.name, _clock(sc.sleep_from), _clock(fposmod(sc.sleep_from + sc.sleep_h, 24.0))], 15, DIM))


## FARM: the fields round home: how many beds the household keeps (the hoe job breaks ground up to it: FarmJob), what
## the beds round home are doing, and the seed in the store.
func _build_fields() -> void:
	_content.add_child(_label("The fields", 17, HEAD))
	var crew := house.crew()
	var row := _row()
	row.add_child(_label("Beds kept round home", 16, TEXT))
	row.add_child(_step(-1.0, func() -> void: house.crew().beds_wanted = maxi(house.crew().beds_wanted - 1, 0)))
	row.add_child(_label(str(crew.beds_wanted), 16, TEXT))
	row.add_child(_step(1.0, func() -> void: house.crew().beds_wanted = mini(house.crew().beds_wanted + 1, 24)))
	var field := FarmField.find(house.get_tree())
	var line := "No fields in this place."
	if field != null:
		var n := {}
		var mine := field.beds_near(house.home, FarmJob.FIELD_M)
		for key: String in mine:
			var st := field.state_of(key)
			n[st] = int(n.get(st, 0)) + 1
		var parts := []
		for st: Array in [["breaking", "being broken"], ["tilled", "ready to sow"], ["growing", "growing"], ["ripe", "ripe"], ["dead", "killed by frost"]]:
			if int(n.get(st[0], 0)) > 0:
				parts.append("%d %s" % [int(n[st[0]]), st[1]])
		line = "%d bed%s round home%s." % [mine.size(), "" if mine.size() == 1 else "s", (": " + ", ".join(parts)) if not parts.is_empty() else ""]
		if field.frozen():
			line += " The ground is frozen."
		elif not field.can_sow_now():
			line += " Too late in the year to sow."
	var seeds := []
	for k: String in JobBook.group("seed"):
		if house.stock.count(k) > 0:
			seeds.append("%d %s" % [house.stock.count(k), InventoryState.name_of(k).to_lower()])
	line += " Seed in the store: %s." % (", ".join(seeds) if not seeds.is_empty() else "none (put seed in a storage chest)")
	_wrapped(line + " A hoe or a digging stick in a chest lets them break ground and weed.", 14, DIM)
	if field != null:
		# FARM: the beds' own memory, read out (FarmField.note)
		var lines := []
		for e: Dictionary in field.recent(field.beds_near(house.home, FarmJob.FIELD_M), 4):
			lines.append("%s %s, %s" % [String(e.who).left(1).to_upper() + String(e.who).substr(1), String(e.what), StoreLedger.ago(field.now_min() - float(e.t))])
		if not lines.is_empty():
			_wrapped("Lately in the fields: %s." % "; ".join(lines), 14, DIM)


func _step(d: float, fn: Callable) -> Button:
	var b := _button("+" if d > 0.0 else "-", 38)
	b.pressed.connect(func() -> void:
		fn.call()
		_show(tab))
	return b


static func _clock(h: float) -> String:
	var m := int(roundf(fposmod(h, 24.0) * 2.0)) * 30
	return "%02d:%02d" % [floori(m / 60.0) % 24, m % 60]


## One chain: its name, all on / all off for the worker, and each link in working order with its toggle and who does it.
func _build_chain(c: Dictionary, sc: SpouseCore) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var t := _label(String(c.name), 17, TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	for on in [true, false]:
		var b := _button("All on" if on else "All off", 84)
		var chain_id := String(c.id)
		var flag: bool = on
		b.pressed.connect(func() -> void:
			house.set_chain(sc, chain_id, flag)
			_show(tab))
		head.add_child(b)
	_content.add_child(head)
	var links: Array = c.links
	for i in links.size():
		var l: Dictionary = links[i]
		var id := String(l.job)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var arrow := _label("   " if i == 0 else " > ", 15, DIM)
		row.add_child(arrow)
		var cb := CheckBox.new()
		cb.text = "%s   (%s, %s)" % [l.name, JobBook.stage_name(String(l.stage)).to_lower(), "at home" if l.where == "home" else "outside"]
		cb.button_pressed = bool(sc.enabled.get(id, false))
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_font_size_override("font_size", 17)
		cb.custom_minimum_size = Vector2(330, 0)
		cb.toggled.connect(func(on: bool) -> void: house.set_job(sc, id, on))
		row.add_child(cb)
		var who := ", ".join(l.workers) if not (l.workers as Array).is_empty() else "nobody"
		row.add_child(_label(who, 14, DIM if l.covered else Color(0.9, 0.6, 0.45)))
		if i < links.size() - 1:
			var cut := _button("off with what it feeds", 0)
			cut.add_theme_font_size_override("font_size", 13)
			cut.custom_minimum_size = Vector2(0, 24)
			cut.pressed.connect(func() -> void:
				house.set_job(sc, id, false, true)
				_show(tab))
			row.add_child(cut)
		_content.add_child(row)


## The selector row when the household has more than one worker.
func _build_workers() -> void:
	var ws := house.workers()
	if ws.size() <= 1:
		return
	var r := _row()
	for w: SpouseCore in ws:
		var b := _button("%s (%s)" % [w.name, "wife" if w.worker_id == 0 and not w.is_male() else "husband" if w.worker_id == 0 else "hand"], 0)
		if w.worker_id == sel:
			b.modulate = LIT
		var wid := w.worker_id
		b.pressed.connect(func() -> void: select(wid))
		r.add_child(b)


func _wrapped(text: String, size: int, col: Color) -> void:
	var l := _label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(580, 0)
	_content.add_child(l)


# ---------------------------------------------------------------- stats
func _build_stats() -> void:
	var sc := _sc()
	_content.add_child(_label("Needs", 17, HEAD))
	for nl: Array in sc.need_lines():
		_content.add_child(_pair(String(nl[0]), String(nl[1])))
	_intimacy_block(sc, false)   # INTIMACY
	if house.pregnancy != null and sc == house.sc:   # PREGNANCY: her state, and the family
		for row: Array in house.pregnancy.status_lines():
			var pr := _pair(String(row[0]), "")
			(pr.get_child(1) as Label).text = String(row[1])   # _pair capitalises every word
			_content.add_child(pr)
		_build_family(sc)
		BabyPanel.build(self, false)   # BABY: the child's state (the buttons are on the Talk tab)
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


## The Family section: each child's name and age (records only; a child may become a worker later).
func _build_family(sc: SpouseCore) -> void:
	if house.family.is_empty():
		return
	_content.add_child(_label("Family", 17, HEAD))
	for c: Dictionary in house.family:
		var fr := _pair(String(c.name), "")
		(fr.get_child(1) as Label).text = Pregnancy.age_text(c, sc.core.state.minutes) + (", a girl" if float(c.sex) < 0.5 else ", a boy") \
				+ (", " + Growth.stage_name(c).to_lower() if c.has("stage") else "")   # GROWTH
		_content.add_child(fr)


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
