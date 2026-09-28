class_name ConditionPanel
extends HBoxContainer
## The character screen's Condition tab (user 2026-09-27: "we need to add these stats when we hit tab"): the body and the
## vices at a glance, in the Skills tab's slim rows.
##   Body             health (and the blood still to lose while a wound bleeds), well rested (the hours left, or why
##                    not: hunger, drink, the morning after, a relapse), hunger (and the meals in the pack), warmth,
##                    wetness
##   Lasting harm     what neglect has left (user 2026-09-27: "the pressure is stunted growth and decay people have to fix
##                    their toon with"): chilled to the bone (LastingChill) and each LastingConditions one while it
##                    holds, what it does, its cure and how far the cure has come; then what is coming on (a need
##                    neglected most of the way to one), so it can be put right in time. The right column, over
##                    drink and tobacco.
##   Drink & tobacco  merry while merry and nothing past it (the player never learns tipsy, drunk or senseless); the
##                    pipe while it steadies the hands; a quid, hemp's calm, laudanum, jimsonweed's madness, the cider
##                    working; each habit in words ("a habit forming", "a hold on you") and a relapse's hours
##   The body       under the Body rows, the body front and back (BodyChart; user 2026-09-27: "a pose of the char somewhere
##                  or in the conidtions tab to should what is afficted"): each wound where it landed and the lasting
##                  harms where they sit; the mouse over a place tells what is there, beside it
## It reads the survival bridge each time it is shown (refresh()).

const INK := Color(0.95, 0.88, 0.7)
const TEXT := Color(0.9, 0.85, 0.75)
const DIM := Color(0.62, 0.57, 0.48)
const GOLD := Color(0.93, 0.74, 0.36)
const GOOD := Color(0.66, 0.84, 0.48)
const WARN := Color(0.94, 0.63, 0.31)
const BAD := Color(0.9, 0.36, 0.3)
const HABIT_FORMING := 25.0
const STAGE_WORDS := {"fed": "Fed", "peckish": "Peckish", "hungry": "Hungry", "very_hungry": "Very hungry",
		"starving": "Starving", "wasting": "Wasting away", "comfortable": "Comfortable", "chilled": "Chilled",
		"cold": "Cold", "very_cold": "Very cold", "hypothermic": "Freezing", "freezing": "Freezing",
		"dry": "Dry", "damp": "Damp", "wet": "Wet", "soaked": "Soaked through"}

var player: Node
var _body: VBoxContainer
var _vices: VBoxContainer
var _chart: BodyChart
var _caption: RichTextLabel      ## beside the outline: what is on the place under the mouse, else the colours' key


static func make(p: Node) -> ConditionPanel:
	var c := ConditionPanel.new()
	c.player = p
	return c


func _ready() -> void:
	add_theme_constant_override("separation", 18)
	var l := _box(520)
	add_child(l)
	var lv := l.get_child(0) as VBoxContainer
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	lv.add_child(_body)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	lv.add_child(hb)
	_chart = BodyChart.new()
	_chart.name = "BodyChart"
	_chart.custom_minimum_size = Vector2(250, 270)
	hb.add_child(_chart)
	_caption = RichTextLabel.new()
	_caption.bbcode_enabled = true
	_caption.fit_content = true
	_caption.scroll_active = false
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_font_size_override("normal_font_size", 17)
	_caption.add_theme_color_override("default_color", TEXT)
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_caption.custom_minimum_size = Vector2(190, 0)
	hb.add_child(_caption)
	_chart.hovered.connect(_on_hover)
	var r := _box(460)
	add_child(r)
	_vices = r.get_child(0) as VBoxContainer
	refresh()


## Rows `[label, value, colour]` for the body and the vices now.
func rows() -> Dictionary:
	var body: Array = []
	var vices: Array = []
	var p := player
	var b := SurvivalBridge.find(p.get_tree()) if p and p.is_inside_tree() else null
	var mh := maxf(float(p.get("max_health")), 1.0) if p else 100.0
	var hp := float(p.get("health")) if p else 0.0
	body.append(["Health", "%d of %d" % [ceili(hp), roundi(mh)], GOOD if hp >= mh * 0.6 else (WARN if hp >= mh * 0.3 else BAD)])
	var w: Variant = p.get("wounds") if p else null
	if w is PlayerWounds and (w as PlayerWounds).bleeding():
		var pool := (w as PlayerWounds).pool
		body.append(["Bleeding", "%s: rest (Z) or dress the wound" % ("heavily" if pool > 20.0 else "a little"), BAD if pool > 20.0 else WARN])
	if b == null or b.core == null:
		body.append(["", "The survival rules are off", DIM])
		return {"body": body, "vices": vices, "lasting": []}
	var core := b.core
	var st := core.need_stages()
	# well rested, or why not
	if b.is_well_rested():
		body.append(["Well rested", _rested_text(b), GOOD])
	else:
		body.append(["Well rested", _why_not_rested(b), DIM])
	var food := String(st.get("need.food", "fed"))
	var meals := b.pack_meals()
	body.append(["Hunger", "%s  ·  %s in the pack" % [STAGE_WORDS.get(food, food.capitalize()), _meals(meals)], GOOD if food == "fed" else (TEXT if food == "peckish" else WARN)])
	var warm := String(st.get("need.warmth", "comfortable"))
	body.append(["Warmth", STAGE_WORDS.get(warm, warm.capitalize()), GOOD if warm == "comfortable" else (TEXT if warm == "chilled" else BAD)])
	var wet := String(st.get("need.wetness", "dry"))
	if wet != "dry":
		body.append(["Wetness", STAGE_WORDS.get(wet, wet.capitalize()), WARN])
	# drink and tobacco
	var v: Vices = b.vices
	if v:
		# what each does for you now, and its cost (user 2026-09-27: "let them now the postivtve effect each one gives")
		if v.shown_drink_stage() == "merry":
			vices.append(["Drink", "Merry: %s; no well-rested boost" % Vices.merry_words(), GOLD])
		if v.tobacco_stage() != "":
			var h := maxf(0.0, (v.pipe_meter() - Vices.TOBACCO_STEADY) / Vices.TOBACCO_DECAY_H)
			vices.append(["Pipe", "Steady hands: %s, about %s more" % [Vices.steady_words(), _hours(h)], GOOD])
		if v.chewing():
			vices.append(["Quid", "In your cheek: steady hands, food nourishes %d%% less" % roundi((1.0 - Vices.CHEW_FOOD_MULT) * 100.0), TEXT])
		if v.calm():
			vices.append(["Hemp", "Calm: %s; hungry sooner, learning %d%% slower" % [Vices.calm_words(), roundi((1.0 - Vices.HEMP_SKILL_MULT) * 100.0)], GOLD])
		if v.laudanum_on():
			vices.append(["Laudanum", "%s, %s more; learning %d%% slower" % [Vices.laudanum_words().substr(0, 1).to_upper() + Vices.laudanum_words().substr(1),
					_hours(v.laudanum_h()), roundi((1.0 - Vices.LAUD_SKILL_MULT) * 100.0)], GOLD])
		if v.delirious():
			vices.append(["Jimsonweed", "Out of your wits: your work goes wrong, no well-rested boost", BAD])
		var working := 0
		for c: Array in (v._st().ciders as Array):
			working += int(c[1])
		if working > 0:
			vices.append(["Cider", "%d jug%s of sweet cider working in the pack" % [working, "" if working == 1 else "s"], TEXT])
		for what: String in ["drink", "tobacco", "hemp", "laudanum"]:
			var nm := String({"drink": "Drink", "tobacco": "Tobacco", "hemp": "Hemp", "laudanum": "Laudanum"}[what])
			if v.addicted(what):
				vices.append([nm, "It has a hold on you", WARN])
			elif v.dependence(what) >= HABIT_FORMING:
				vices.append([nm, "A habit forming", TEXT])
		var rl := v.relapse_h_left()
		if rl > 0.0:
			vices.append(["Relapse", "no well-rested boost for %s more" % _hours(rl), BAD])
	if vices.is_empty():
		vices.append(["", "Nothing to tell", DIM])
	return {"body": body, "vices": vices, "lasting": lasting_rows(b)}


## The Lasting harm rows: chilled to the bone, the other lasting conditions (LastingConditions.rows), what is coming on.
func lasting_rows(b: SurvivalBridge) -> Array:
	var out: Array = []
	if b.chill and b.chill.is_on():
		var rc := b.chill.recovery()
		out.append(["Chilled", "Heal slowly, no higher than %d%%. Cure: warm and well rested for two days%s" % [roundi(LastingChill.HEALTH_CAP * 100.0),
				" · %d%% mended" % roundi(rc * 100.0) if rc > 0.0 else ""], BAD])
	elif b.chill and b.chill.exposure() >= LastingConditions.WARN_AT:
		out.append(["Chilled", "Cold too long: the chill is getting into your bones (%d%%)" % roundi(b.chill.exposure() * 100.0), WARN])
	if b.lasting:
		for r: Array in b.lasting.rows():
			out.append([String(r[0]), String(r[1]), {"bad": BAD, "good": GOOD}.get(String(r[2]), WARN)])
	return out


## Well rested: the hours left, what it does (the healing once a day: SurvivalBridge.is_healing_rest), and how fast it
## wears off while restless (LastingConditions.rest_drain_mult).
func _rested_text(b: SurvivalBridge) -> String:
	var txt := "%d hours left (%s)" % [ceili(b.rested_hours_left()),
			"you heal and learn faster" if b.is_healing_rest() else "you learn faster; you have had today's healing sleep"]
	var dm := b.lasting.rest_drain_mult() if b.lasting else 1.0
	if dm > 1.001:
		txt += ", wearing off %s as fast (restless)" % ("twice" if dm > 1.95 else "%.1f×" % dm)
	return txt


## The outline's marks: the wounds and the lasting harms (LastingConditions.body_marks), chilled to the bone on the hands
## and feet.
func body_marks(b: SurvivalBridge) -> Array:
	var out: Array = b.lasting.body_marks() if b and b.lasting else []
	if b and b.chill and b.chill.is_on():
		for r: String in ["l_hand", "r_hand", "l_foot", "r_foot"]:
			out.append({"region": r, "side": "both", "mark": "chill",
					"text": "Chilled to the bone: heal slowly, no higher than %d%%" % roundi(LastingChill.HEALTH_CAP * 100.0)})
	return out


func _on_hover(region: String, _side: String, lines: PackedStringArray) -> void:
	if region == "":
		_caption_idle()
		return
	var name := String(LastingConditions.REGION_NAMES.get(region, region.capitalize()))
	var body := "\n".join(lines) if not lines.is_empty() else "[color=#%s]Nothing wrong here[/color]" % DIM.to_html(false)
	_caption.text = "[color=#%s]%s[/color]\n%s" % [GOLD.to_html(false), name, body]


## The caption with the mouse off the body: what the colours mean, or that nothing ails it.
func _caption_idle() -> void:
	var ks := _chart.kinds() if _chart else []
	var dim := DIM.to_html(false)
	if ks.is_empty():
		_caption.text = "[color=#%s]Nothing ails you[/color]" % dim
		return
	var words := PackedStringArray()
	for k: String in ks:
		var c: Color = BodyChart.COLORS[k]
		words.append("[color=#%s]■[/color]  %s" % [Color(c, 1.0).to_html(false), _cap1(String(BodyChart.WORDS[k]))])
	_caption.text = "[color=#%s]Point at the body to see what is wrong[/color]\n\n%s" % [dim, "\n".join(words)]


func _why_not_rested(b: SurvivalBridge) -> String:
	var core := b.core
	# a warm sleep by a fire lifts these (SurvivalBridge.rest_cap_h, LastingChill's warm rest)
	var warm := "; a warm sleep by a fire still rests you"
	if b.vices and b.vices.blocks_rest():
		return "Not while the relapse lasts" + warm
	if SurvivalConditions.stage_of(core, "cond.drunk") in PlayerWounds.DRUNK_STAGES:
		return "Not with drink in you" + warm
	var q: Dictionary = core.state.conditions.get("cond.queasy", {})
	if String(q.get("cause", "")) == "hangover":
		return "Not with the morning after on you" + warm
	var cap := b.rest_cap_h()
	if cap <= 0.0:
		return "Too hungry to rest well" + warm
	if cap < INF:
		return "Sleep well (hungry: at most %d hours)" % roundi(cap)
	return "Sleep well to earn it (a lean-to and a fire help)"


static func _cap1(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)


static func _meals(m: float) -> String:
	if m < 0.1:
		return "no meals"
	if m < 0.95:
		return "part of a meal"
	return "%s meals" % (str(roundi(m)) if m >= 1.5 else "one")


static func _hours(h: float) -> String:
	if h < 1.0:
		return "%d minutes" % maxi(5, roundi(h * 60.0 / 5.0) * 5)
	return "%d hours" % roundi(h) if h >= 1.5 else "an hour"


## Rebuilds the rows (the screen calls it when the tab is shown).
func refresh() -> void:
	if _body == null:
		return
	var r := rows()
	_fill(_body, "Body", r.body)
	if _chart:
		var p := player
		_chart.marks = body_marks(SurvivalBridge.find(p.get_tree()) if p and p.is_inside_tree() else null)
		_chart.queue_redraw()
		_caption_idle()
	var lasting: Array = r.get("lasting", [])
	_fill(_vices, "Lasting harm", lasting if not lasting.is_empty() else [["", "None: you are whole", DIM]])
	_add_section(_vices, "Drink and tobacco", r.vices)


func _fill(col: VBoxContainer, title: String, rs: Array) -> void:
	for c in col.get_children():
		col.remove_child(c)
		c.queue_free()
	_add_section(col, title, rs)


## A heading and its rows, after what the column has.
func _add_section(col: VBoxContainer, title: String, rs: Array) -> void:
	if col.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 10)
		col.add_child(gap)
	col.add_child(_label(title, 22, Color(0.93, 0.8, 0.52)))
	for rw: Array in rs:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		var k := _label(String(rw[0]), 16, DIM)
		k.custom_minimum_size = Vector2(110, 0)
		h.add_child(k)
		var val := _label(String(rw[1]), 18, rw[2])
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(val)
		col.add_child(h)


func _box(w: float) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(w, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.11, 0.08, 0.7)
	sb.border_color = Color(0.5, 0.4, 0.26, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(16)
	pc.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	return pc


static func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
