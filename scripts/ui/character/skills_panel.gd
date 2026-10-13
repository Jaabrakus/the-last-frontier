class_name SkillsPanel
extends HBoxContainer
## The character screen's Skills tab (user 2026-09-26: "work on the hud elements and the char screen the skills tab
## and some icons"; 2026-09-27: "no those big cards are terrible"): every skill a slim row on the left (its icon,
## name, level and tier, a thin bar; the chosen one a gold rule at its left), the chosen one's ladder on the right.
##   Field skills     the three the game trains now (GatherSkills: woodcutting, mining, building): level, tier, the
##                    progress to the next level, what the tier gives (data/gathering/gathering.json skills.*.tiers)
##   Frontier skills  the ten of the survival rules (data/survival/skills.json): the levels the background gave
##                    (SurvivalCore's skills, 0-100, through SurvivalBridge; Novice 0 without it), what each covers
##                    and what each tier unlocks (tier_unlocks). Trapping and Fishing grows with the rod (PLAY_GROWS:
##                    how, and what it does for the cast and the line); nothing else in play trains them yet, so nothing
##                    here says it does.
## Icons: assets/ui/icons/skill_<id>.svg (drawn for the project, tinted here).

const ICON_DIR := "res://assets/ui/icons/"
const INK := Color(0.95, 0.88, 0.7)
const TEXT := Color(0.9, 0.85, 0.75)
const DIM := Color(0.62, 0.57, 0.48)
const GOLD := Color(0.93, 0.74, 0.36)
const ROW := Color(0, 0, 0, 0)
const ROW_SEL := Color(0.93, 0.74, 0.36, 0.1)
const TIERS := [["novice", "Novice", 0], ["apprentice", "Apprentice", 20], ["journeyman", "Journeyman", 40],
		["adept", "Adept", 60], ["master", "Master", 80]]
const SURVIVAL_SKILLS := "res://data/survival/skills.json"
## The frontier skills play trains, and what the level does (in place of "What your background taught you.").
const PLAY_GROWS := {
	"trapping": "Grows as you fish with the rod: every strike that holds, every fish landed (the bigger, the more). "
			+ "The higher it is, the truer your cast lands and the more your line takes before it breaks.",
}

var gather: GatherSkills                  ## the player's field skills (null: none)
var core: SurvivalCore                    ## the survival rules' core, for the frontier skills (null: none)
var _survival: Array = []                 ## skills.json skills
var _cards := {}                          ## id -> PanelContainer
var _selected := ""
var _detail: VBoxContainer


## `gather_skills`: the player's GatherSkills (GatherTools.skills), or null.
static func make(gather_skills: GatherSkills, survival_core: SurvivalCore = null) -> SkillsPanel:
	var p := SkillsPanel.new()
	p.gather = gather_skills
	p.core = survival_core
	return p


func _ready() -> void:
	add_theme_constant_override("separation", 18)
	var f := FileAccess.open(SURVIVAL_SKILLS, FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
	_survival = (d as Dictionary).get("skills", []) if d is Dictionary else []
	var left := _box(560)
	add_child(left)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.get_child(0).add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	list.add_child(_head("Field skills", "Trained by working: every stroke, log and piece counts."))
	for id: String in GatherSkills.IDS:
		list.add_child(_field_card(id))
	list.add_child(_head("Survival skills", "What your background taught you. Fishing trains Trapping and Fishing."))
	for s: Dictionary in _survival:
		list.add_child(_frontier_card(s))
	var right := _box(500)
	add_child(right)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 10)
	right.get_child(0).add_child(_detail)
	select(GatherSkills.IDS[0])


## Shows skill `id`'s ladder on the right (a field skill id, or a frontier skill's id prefixed "s:").
func select(id: String) -> void:
	_selected = id
	for k: String in _cards:
		var sb := (_cards[k] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
		sb.bg_color = ROW_SEL if k == id else ROW
		sb.border_color = GOLD if k == id else Color(0, 0, 0, 0)
	for ch in _detail.get_children():
		ch.queue_free()
	if id.begins_with("s:"):
		_frontier_detail(id.substr(2))
	else:
		_field_detail(id)


func selected() -> String:
	return _selected


# --- cards ----------------------------------------------------------------------------------------

func _field_card(id: String) -> PanelContainer:
	var info := _gather_info(id)
	var lvl := gather.level(id) if gather else 0
	var pts := gather.points_of(id) if gather else 0.0
	var tier: Dictionary = gather.tier(id) if gather else {"name": "Novice"}
	var c := _card(id, id, str(info.get("name", id.capitalize())), "%d  ·  %s" % [lvl, tier.name],
			pts - floorf(pts) if lvl < int(GatherSkills.MAX_LEVEL) else 1.0)
	return c


func _frontier_card(s: Dictionary) -> PanelContainer:
	var id := str(s.get("id", ""))
	var lv := frontier_level(id)
	return _card("s:" + id, id, str(s.get("name", id.capitalize())), "%d  ·  %s" % [int(lv), tier_name(lv)], lv / 100.0)


## A frontier skill's level (0-100) from the survival core; 0 without it.
func frontier_level(id: String) -> float:
	return SurvivalSkills.level(core, id) if core else 0.0


static func tier_name(lvl: float) -> String:
	var nm := "Novice"
	for t: Array in TIERS:
		if lvl >= float(t[2]):
			nm = String(t[1])
	return nm


## One slim row: no box; the chosen one gets a faint gold wash and a gold rule at its left.
func _card(key: String, icon_id: String, title: String, line: String, frac: float) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = ROW
	sb.border_color = Color(0, 0, 0, 0)
	sb.border_width_left = 3
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 10
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			select(key))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(row)
	row.add_child(_icon(icon_id, 34))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var t := _label(title, 19, INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(_label(line, 16, GOLD))
	var b := _bar(frac, 300)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(b)
	_cards[key] = pc
	return pc


# --- the ladder on the right --------------------------------------------------------------------------

func _field_detail(id: String) -> void:
	var info := _gather_info(id)
	var lvl := gather.level(id) if gather else 0
	var pts := gather.points_of(id) if gather else 0.0
	_title_row(id, str(info.get("name", id.capitalize())), "Level %d" % lvl)
	var p := _label(player_text(str(info.get("summary", "")), 3), 15, TEXT)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.custom_minimum_size = Vector2(460, 0)
	_detail.add_child(p)
	if lvl < int(GatherSkills.MAX_LEVEL):
		_detail.add_child(_label("%d%% of the way to level %d" % [int((pts - floorf(pts)) * 100.0), lvl + 1], 14, DIM))
	var tiers: Dictionary = info.get("tiers", {})
	_ladder(lvl, func(tid: String) -> String:
		return "Where every woodsman starts." if tid == "novice" else str(tiers.get(tid, "")))


func _frontier_detail(id: String) -> void:
	var s := _survival_skill(id)
	var lv := frontier_level(id)
	_title_row(id, str(s.get("name", id.capitalize())), "Level %d  ·  %s" % [int(lv), tier_name(lv)])
	var p := _label(player_text(str(s.get("summary", "")), 3), 15, TEXT)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.custom_minimum_size = Vector2(460, 0)
	_detail.add_child(p)
	var un: Dictionary = s.get("tier_unlocks", {}) if s.get("tier_unlocks") is Dictionary else {}
	_ladder(int(lv), func(tid: String) -> String:
		if tid == "novice":
			return "Where every woodsman starts."
		var e: Variant = un.get(tid)
		return str((e as Dictionary).get("text", "")) if e is Dictionary else "")
	var foot := _label(String(PLAY_GROWS.get(id, "What your background taught you.")), 14, DIM)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.custom_minimum_size = Vector2(460, 0)
	_detail.add_child(foot)


func _title_row(icon_id: String, title: String, lvl: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_detail.add_child(row)
	row.add_child(_icon(icon_id, 64))
	var col := VBoxContainer.new()
	row.add_child(col)
	col.add_child(_label(title, 26, INK))
	col.add_child(_label(lvl, 17, GOLD))


## The five tiers, reached ones bright, the next one marked.
func _ladder(lvl: int, text_of: Callable) -> void:
	_detail.add_child(_label("Ranks", 18, INK))
	var next_done := false
	for t: Array in TIERS:
		var reached := lvl >= int(t[2])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_detail.add_child(row)
		var mark := _label("●" if reached else ("◐" if not next_done else "○"), 16, GOLD if reached else (TEXT if not next_done else DIM))
		mark.custom_minimum_size = Vector2(18, 0)
		row.add_child(mark)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		row.add_child(col)
		col.add_child(_label("%s  (%d)" % [t[1], t[2]], 16, GOLD if reached else (TEXT if not next_done else DIM)))
		var tx := _label(str(text_of.call(str(t[0]))), 13, TEXT if reached else DIM)
		tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tx.custom_minimum_size = Vector2(430, 0)
		col.add_child(tx)
		if not reached:
			next_done = true


# --- helpers -----------------------------------------------------------------------------------------

## A data summary as the player reads it: the first `sentences` sentences, without the notes for the developers in
## brackets (file paths, xp keys: "(build mode, B: scripts/building/)").
static func player_text(t: String, sentences: int) -> String:
	var rx := RegEx.create_from_string("\\s*\\([^()]*(/|\\.json|xp\\.|_)[^()]*\\)")
	t = rx.sub(t, "", true).strip_edges()
	var out := ""
	var n := 0
	var i := 0
	while i < t.length() and n < sentences:
		var j := t.find(". ", i)
		if j < 0:
			out += t.substr(i)
			break
		out += t.substr(i, j - i + 1) + " "
		i = j + 2
		n += 1
	return out.strip_edges()

func _gather_info(id: String) -> Dictionary:
	if gather and gather.data:
		return gather.data.skill(id)
	return {}


func _survival_skill(id: String) -> Dictionary:
	for s: Dictionary in _survival:
		if str(s.get("id", "")) == id:
			return s
	return {}


func _survival_name(id: String) -> String:
	return str(_survival_skill(id).get("name", id.capitalize()))


static func icon_texture(id: String) -> Texture2D:
	var path := ICON_DIR + "skill_%s.svg" % id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _icon(id: String, px: int) -> Control:
	var tr := TextureRect.new()
	tr.texture = icon_texture(id)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.modulate = GOLD
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _bar(frac: float, w: float) -> Control:
	var pb := ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.value = clampf(frac, 0.0, 1.0)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(w, 3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	bg.set_corner_radius_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = GOLD
	fg.set_corner_radius_all(1)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb


func _head(title: String, note: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(_label(title, 22, Color(0.93, 0.8, 0.52)))
	v.add_child(_label(note, 14, DIM))
	return v


func _box(w: float) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(w, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.11, 0.08, 0.7)
	sb.border_color = Color(0.5, 0.4, 0.26, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(14)
	pc.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pc.add_child(v)
	return pc


static func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
