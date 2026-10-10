extends RefCounted
## Menu style B, "Arena broadcast": the four screens, each built into a Control laid out at 1600 x 900 (the caller scales
## it to the window, its parts anchored to their corners and edges). The words are the game's own, read at run time:
## MainMenu's rows and lines, MatchSetup (elements.json, practice.json), KitWords (the buttons), rules.json and
## screens.json (the Esc menu, the match screen), highlights.json, the Esc menu's option rows; the new Fighter area's
## words follow docs/skill_tree_design.md (class = element + fighting style, 10 points in the ring). The match screen's
## numbers are a made-up match in the game's own formats (it is a mock).

const Kit := preload("res://tools/ui_audit/menu_variants/b_broadcast/kit.gd")
const W := 1600.0
const H := 900.0
const ELS := ["earth", "water", "fire", "air"]
## A fighting style per element for the Fighter area (each from that element's roster in docs/fighting_styles_design.md;
## Boxing and Capoeira are the two built so far).
const STYLE := {"earth": "Sumo", "water": "Aikido", "fire": "Boxing", "air": "Capoeira"}

var renders := ""


func _init(dir: String) -> void:
	renders = dir


func _r(name: String) -> String:
	return renders.path_join(name)


## A filled polygon (a slab, a sweep) with a colour per point.
static func poly(p: Control, pts: Array, cols: Array) -> Polygon2D:
	var g := Polygon2D.new()
	g.polygon = PackedVector2Array(pts)
	g.vertex_colors = PackedColorArray(cols)
	g.antialiased = true
	p.add_child(g)
	return g


## A leaning slab from the top of the screen to `h`, `x0`..`x1` at its foot, fading from `top` to `foot` alpha.
static func slab(p: Control, x0: float, x1: float, h: float, c: Color, top: float, foot: float, lean := Kit.LEAN) -> Polygon2D:
	var d := h * lean
	return poly(p, [Vector2(x0 + d, 0), Vector2(x1 + d, 0), Vector2(x1, h), Vector2(x0, h)],
			[Color(c, top), Color(c, top), Color(c, foot), Color(c, foot)])


static func _words(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


## KitWords' lines for `el` as [{key, role, move, more}] ("1   STRIKE ▲   Punch  ·  hold to grow it: Fireball").
static func kit(el: String) -> Array:
	var out: Array = []
	for line: String in KitWords.kit_lines(el, "keys"):
		var parts := line.split("   ", false)
		if parts.size() < 3:
			continue
		var rest := String(parts[2])
		var more := ""
		if rest.contains("  ·  "):
			more = rest.get_slice("  ·  ", 1)
			rest = rest.get_slice("  ·  ", 0)
		out.append({"key": String(parts[0]).strip_edges(), "role": String(parts[1]).strip_edges(), "move": rest.strip_edges(),
				"more": more})
	return out


## "Aim help:  strong" -> ["Aim help", "strong"].
static func split_row(t: String) -> Array:
	var i := t.find(":")
	if i < 0:
		return [t, ""]
	return [t.substr(0, i).strip_edges(), t.substr(i + 1).strip_edges()]


# ================================================================ shared parts
## A rundown row. The focused one sits on a plate, its number on the element's colour, its line under it; the others
## are a number and a title. Returns the row's height.
func row(p: Control, y: float, num: String, title: String, sub: String, focus: bool, el: String, w := 560.0,
		badge := "", value := "", value_el := "") -> float:
	var pc := Kit.plate_c(el)
	if focus:
		var h := 90.0
		Kit.plate(p, Rect2(-14, y, w, h), Color(Kit.NAVY2, 0.95))
		Kit.plate(p, Rect2(-14, y, 70, h), pc)
		Kit.put(p, Kit.lab(num, Kit.head(), 46, Kit.INK, HORIZONTAL_ALIGNMENT_CENTER), Rect2(-12, y + 4, 70, h - 4))
		var t := Kit.lab(title.to_upper(), Kit.head(true, 1), 46, Kit.WHITE)
		Kit.put(p, t, Rect2(78, y + 6, w - 120, 50))
		if value != "":
			_value_tag(p, Vector2(78 + t.get_minimum_size().x + 14, y + 13), value, value_el)
		if sub != "":
			Kit.put(p, Kit.lab(sub, Kit.body(500), 18, Kit.DIM), Rect2(80, y + 54, w - 110, 26))
		var ch := Kit.glyph("next", pc, 26)
		Kit.put(p, ch, Rect2(w - 56, y + 32, 26, 26))
		# the accent's hairline under the plate (the broadcast's underline)
		Kit.plate(p, Rect2(56 + 6, y + h - 4, w - 76, 4), Kit.TEAL)
		return h + 8
	var hh := 52.0
	Kit.put(p, Kit.lab(num, Kit.head(), 28, Kit.FAINT, HORIZONTAL_ALIGNMENT_CENTER), Rect2(-12, y + 4, 70, hh - 6))
	var tt := Kit.lab(title.to_upper(), Kit.head(true, 1), 38, Kit.WHITE)
	Kit.put(p, tt, Rect2(78, y + 4, w - 100, hh - 6))
	var tx := 78 + tt.get_minimum_size().x + 14
	if badge != "":
		var b := Kit.tag(badge, 17, Kit.INK, Kit.TEAL, 2)
		Kit.put(p, b, Rect2(tx, y + 13, 0, 0))
	if value != "":
		_value_tag(p, Vector2(tx, y + 11), value, value_el)
	return hh


func _value_tag(p: Control, at: Vector2, value: String, value_el: String) -> void:
	var bg := Kit.plate_c(value_el) if value_el != "" else Kit.NAVY3
	var fg := Kit.INK if value_el != "" else Kit.WHITE
	var h := Kit.hbox(8)
	if value_el != "" and value_el in ELS:
		h.add_child(Kit.glyph(value_el, Kit.INK, 20, bg))
	h.add_child(Kit.lab(value.to_upper(), Kit.head(false, 2), 24, fg))
	Kit.put(p, Kit.chip(h, bg, Kit.LEAN, Vector4(12, 3, 14, 0)), Rect2(at, Vector2.ZERO))


## The thin bar of key hints at the foot of a screen (anchored to its bottom edge).
func hints(L: Control, items: Array, right := true) -> void:
	var g := Kit.group(L, Vector2(1, 1) if right else Vector2(0, 1), Vector2(-760, -58) if right else Vector2(84, -58), Vector2(700, 36))
	var h := Kit.hbox(26)
	h.alignment = BoxContainer.ALIGNMENT_END if right else BoxContainer.ALIGNMENT_BEGIN
	for it: Array in items:
		h.add_child(Kit.key_hint(String(it[0]), String(it[1])))
	Kit.put(g, h, Rect2(0, 0, 700, 36))


## The element block: its colour, its mark and its name.
func element_plate(p: Control, r: Rect2, el: String, name_px := 34, show_name := true, lean := Kit.LEAN) -> void:
	var pc := Kit.plate_c(el)
	Kit.plate(p, r, pc, lean)
	var g := Kit.glyph(el, Kit.INK, r.size.y * 0.52, pc)
	Kit.put(p, g, Rect2(r.position + Vector2(16 + r.size.y * 0.12, r.size.y * 0.24), Vector2(r.size.y * 0.52, r.size.y * 0.52)))
	if show_name:
		Kit.put(p, Kit.lab(MatchSetup.label(el).to_upper(), Kit.head(false, 2), name_px, Kit.INK),
				Rect2(r.position + Vector2(r.size.y * 0.78 + 14, 2), Vector2(r.size.x - r.size.y * 0.78 - 18, r.size.y)))


## A segmented choice: its options as leaning chips, the chosen one filled (`fill`, ink on it).
func segments(p: Control, at: Vector2, opts: Array, chosen: int, fill := Kit.TEAL, px := 20, off := -1) -> HBoxContainer:
	var h := Kit.hbox(6)
	for i in opts.size():
		var on := i == chosen
		var o: Variant = opts[i]
		var text := String(o) if not (o is Dictionary) else String((o as Dictionary).text)
		var col: Color = fill if not (o is Dictionary) else (o as Dictionary).get("color", fill)
		var bg := col if on else Color(Kit.NAVY3, 0.95)
		var fg := Kit.INK if on else (Kit.FAINT if i == off else Kit.DIM)
		var inner := Kit.hbox(6)
		if o is Dictionary and (o as Dictionary).has("glyph"):
			inner.add_child(Kit.glyph(String((o as Dictionary).glyph), Kit.INK if on else col, px * 0.8, bg))
		inner.add_child(Kit.lab(text.to_upper(), Kit.head(false, 2), px, fg))
		var c := Kit.chip(inner, bg, Kit.LEAN, Vector4(12, 3, 12, 0))
		if not on and o is Dictionary and (o as Dictionary).has("color"):
			(c.get_theme_stylebox("panel") as StyleBoxFlat).border_width_top = 3
			(c.get_theme_stylebox("panel") as StyleBoxFlat).border_color = col
		h.add_child(c)
	Kit.put(p, h, Rect2(at, Vector2.ZERO))
	return h


# ================================================================ 1. the main menu: the lobby
func main_menu(L: Control, el: String, poster := true) -> void:
	var pc := Kit.plate_c(el)
	var comp := MatchSetup.competitor(el)
	Kit.picture(L, Kit.tex(_r("lobby_%s.png" % el), 1, 1.0, Vector2i(1600, 900)))
	# the shade at the left for the rundown, the foot for the ticker and the lower third, a touch at the top
	Kit.grad(L, [[0.0, Color(Kit.NAVY0, 0.94)], [0.36, Color(Kit.NAVY0, 0.80)], [0.62, Color(Kit.NAVY0, 0.0)]],
			Vector2(0, 0.5), Vector2(1, 0.5))
	Kit.grad(L, [[0.0, Color(Kit.NAVY0, 0.0)], [0.70, Color(Kit.NAVY0, 0.0)], [1.0, Color(Kit.NAVY0, 0.75)]],
			Vector2(0.5, 0), Vector2(0.5, 1))
	if poster:
		# the slab of your colour behind your fighter, a teal sweep beside it, the name its competitors go by in
		# outline across it; then the fighter cut out of the same frame over them
		var back := Kit.group(L, Vector2(0.5, 0), Vector2(0, 0), Vector2(W * 0.5, H))
		slab(back, 1035 - 800, 1215 - 800, H, pc, 0.88, 0.0)
		slab(back, 1000 - 800, 1016 - 800, H, Kit.TEAL, 0.95, 0.0)
		slab(back, 1234 - 800, 1242 - 800, H, Kit.WHITE, 0.55, 0.0)
		var big := Kit.outline(comp.to_upper(), 330, Color(Kit.WHITE, 0.42), 3)
		Kit.put(back, big, Rect2(0, 40, 0, 0))
		var bw := big.get_combined_minimum_size().x
		if bw > 660.0:
			big.add_theme_font_size_override("font_size", int(330.0 * 660.0 / bw))
			bw = big.get_combined_minimum_size().x
		big.size = Vector2.ZERO
		big.position = Vector2(1215 - 800 - bw * 0.5, 40)
		Kit.stripes(back, Rect2(1050 - 800, 0, 300, 420), Color(Kit.INK, 0.10), 12, 3, 1.0)
		var cut := TextureRect.new()
		cut.texture = Kit.tex(_r("lobby_%s_cut.png" % el))
		cut.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cut.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
		L.add_child(cut)
		cut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# --- the top left: the lobby's tag and the title
	var tl := Kit.group(L, Vector2(0, 0), Vector2(84, 40), Vector2(700, 260))
	var top := Kit.hbox(12)
	top.add_child(Kit.tag("LOBBY", 18, Kit.INK, Kit.TEAL, 3))
	top.add_child(Kit.lab("EARLY PLAYABLE DEMO  ·  IN DEVELOPMENT", Kit.head(false, 3), 18, Kit.DIM))
	Kit.put(tl, top, Rect2(0, 0, 600, 28))
	Kit.put(tl, Kit.lab(MainMenu.TITLE, Kit.head(true, 3), 138, Kit.WHITE), Rect2(-6, 26, 700, 140))
	var st := Kit.tag(MainMenu.SUBTITLE, 22, Kit.INK, Kit.WHITE, 4, Vector4(14, 3, 16, 0))
	Kit.put(tl, st, Rect2(4, 160, 0, 0))
	# --- the rundown
	var rd := Kit.group(L, Vector2(0, 0), Vector2(84, 248), Vector2(600, 560))
	var y := 0.0
	Kit.section(rd, Vector2(0, y), "PLAY", 540)
	y += 32
	y += row(rd, y, "01", MatchSetup.sport(), MatchSetup.menu_line(), true, el)
	y += row(rd, y, "02", "Start here", "learn at your own pace, or play an easy match", false, el)
	y += row(rd, y, "03", "Quick match", MatchSetup.quick_line(), false, el)
	y += row(rd, y, "04", "Practice", MainMenu._practice_line(), false, el)
	y += 14
	Kit.section(rd, Vector2(0, y), "FIGHTER", 540)
	y += 32
	y += row(rd, y, "05", "Class & talents", "", false, el, 560.0, "NEW")
	y += row(rd, y, "06", "Your look", "", false, el)
	y += 16
	var util := Kit.hbox(30)
	for e: Array in [["07", "Settings"], ["08", "Credits"], ["09", "Quit"]]:
		var u := Kit.hbox(8)
		u.add_child(Kit.lab(String(e[0]), Kit.head(), 22, Kit.FAINT))
		u.add_child(Kit.lab(String(e[1]).to_upper(), Kit.head(false, 2), 26, Kit.DIM))
		util.add_child(u)
	Kit.put(rd, util, Rect2(6, y, 540, 34))
	# --- the top right: the next match as the kept setup has it
	var tr := Kit.group(L, Vector2(1, 0), Vector2(-640, 40), Vector2(560, 80))
	var nm := Kit.hbox(0)
	nm.alignment = BoxContainer.ALIGNMENT_END
	nm.add_child(Kit.tag("NEXT MATCH", 18, Kit.INK, Kit.TEAL, 3))
	var setup := "%s  ·  %s  ·  %s  ·  %s" % [String((MatchSetup.data().get("formats", {}) as Dictionary).get("1v1", {}).get("label", "1 v 1")),
			MatchSetup.rule_label(), MatchSetup.games_label(), MatchSetup.difficulty]
	nm.add_child(Kit.tag(setup.to_upper(), 18, Kit.WHITE, Color(Kit.NAVY1, 0.92), 3))
	Kit.put(tr, nm, Rect2(0, 0, 556, 30))
	# --- the lower third: your fighter
	var lt := Kit.group(L, Vector2(1, 1), Vector2(-748, -262), Vector2(690, 190))
	var tab := Kit.hbox(0)
	tab.add_child(Kit.tag("YOUR FIGHTER", 17, Kit.INK, Kit.TEAL, 3))
	tab.add_child(Kit.tag("%s  ·  %s" % [MatchSetup.label(el).to_upper(), String(STYLE[el]).to_upper()], 17, Kit.WHITE, Kit.NAVY0, 3))
	Kit.put(lt, tab, Rect2(10, 0, 0, 0))
	Kit.plate(lt, Rect2(0, 30, 690, 96), Color(Kit.NAVY1, 0.95))
	element_plate(lt, Rect2(0, 30, 120, 96), el, 0, false)
	Kit.put(lt, Kit.lab(comp.to_upper(), Kit.head(true, 2), 74, Kit.WHITE), Rect2(140, 36, 300, 86))
	var stats := Kit.hbox(10)
	stats.alignment = BoxContainer.ALIGNMENT_END
	for s: Array in [["CLASS", String(STYLE[el])], ["TALENTS", "10 pts"], ["PASSIVE", String(KitWords.passive(el).get("name", ""))]]:
		var v := Kit.vbox(0)
		v.add_child(Kit.lab(String(s[0]), Kit.head(false, 3), 15, Kit.FAINT, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(Kit.lab(String(s[1]).to_upper(), Kit.head(false, 1), 26, pc, HORIZONTAL_ALIGNMENT_CENTER))
		stats.add_child(Kit.chip(v, Color(Kit.NAVY3, 0.9), Kit.LEAN, Vector4(14, 4, 14, 2)))
	Kit.put(lt, stats, Rect2(330, 44, 340, 70))
	Kit.plate(lt, Rect2(-14, 126, 650, 38), Color(Kit.NAVY0, 0.92))
	Kit.put(lt, Kit.lab(MatchSetup.style(el), Kit.body(500), 19, Kit.DIM), Rect2(20, 128, 610, 34))
	# --- the ticker
	ticker(L, el)


## The foot of the lobby: a ticker of the game's own captions (MenuPaintings), the keys at its right.
func ticker(L: Control, el: String) -> void:
	var g := Kit.group(L, Vector2(0, 1), Vector2(0, -50), Vector2(W, 50))
	g.anchor_right = 1.0
	g.offset_right = 0
	Kit.rect(g, Rect2(0, 0, W * 2, 50), Color(Kit.NAVY0, 0.96))
	Kit.rect(g, Rect2(0, 0, W * 2, 2), Kit.TEAL)
	var row_h := Kit.hbox(16)
	var first := true
	for e: Dictionary in MenuPaintings.PICTURES:
		if not first:
			var d := Kit.hbox(4)
			for x: String in ELS:
				d.add_child(Kit.glyph(x, Kit.ec(x), 14, Kit.NAVY0))
			row_h.add_child(d)
		first = false
		row_h.add_child(Kit.lab(String(e.title).to_upper(), Kit.head(false, 2), 22, Kit.WHITE))
		row_h.add_child(Kit.lab(String((e.captions as Array)[0]), Kit.body(500), 18, Kit.DIM))
	Kit.put(g, row_h, Rect2(250, 3, 3000, 46))
	var lt := Kit.tag("ON THE DECK", 22, Kit.INK, Kit.TEAL, 3, Vector4(54, 9, 22, 7))
	Kit.put(g, lt, Rect2(-40, 2, 0, 0))
	var kr := Kit.group(L, Vector2(1, 1), Vector2(-430, -50), Vector2(430, 50))
	Kit.plate(kr, Rect2(0, 2, 470, 48), Kit.NAVY0)
	var h := Kit.hbox(22)
	h.add_child(Kit.key_hint("ENTER", "Select", 18))
	h.add_child(Kit.key_hint("ESC", "Back", 18))
	h.add_child(Kit.key_hint("↑ ↓", "Move", 18))
	Kit.put(kr, h, Rect2(34, 9, 400, 34))


# ================================================================ 2. the match's setup
func match_setup(L: Control, el: String, foe_el: String) -> void:
	Kit.picture(L, Kit.tex(_r("frame_setup.png"), 4, 0.9))
	Kit.rect(L, Rect2(0, 0, W, H), Color(Kit.NAVY0, 0.78)).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Kit.stripes(L, Rect2(0, 0, W, 300), Color(Kit.WHITE, 0.025), 16, 3, 1.0)
	# --- the head
	var hd := Kit.group(L, Vector2(0, 0), Vector2(84, 36), Vector2(1440, 70))
	Kit.put(hd, Kit.tag(MatchSetup.sport().to_upper(), 20, Kit.INK, Kit.TEAL, 4), Rect2(0, 14, 0, 0))
	Kit.put(hd, Kit.lab("MATCH SETUP", Kit.head(true, 2), 60, Kit.WHITE), Rect2(170, 0, 600, 64))
	Kit.put(hd, Kit.para(MatchSetup.sport_line(), Kit.body(500), 17, Kit.DIM, 520), Rect2(560, 10, 520, 50))
	# --- your element: the four fighters as cards
	var cards := Kit.group(L, Vector2(0, 0), Vector2(84, 128), Vector2(920, 680))
	Kit.section(cards, Vector2(0, 0), "YOUR ELEMENT", 900)
	var cw := 214.0
	var chh := 452.0
	for i in ELS.size():
		var e: String = ELS[i]
		card(cards, Rect2(i * (cw + 14), 36, cw, chh), e, i + 1, e == el)
	# the chosen one's style, passive and buttons
	var info := Kit.group(cards, Vector2(0, 0), Vector2(0, 504), Vector2(900, 180))
	var ln := Kit.hbox(14)
	ln.add_child(Kit.lab("%s  ·  %s" % [MatchSetup.label(el).to_upper(), MatchSetup.competitor(el).to_upper()], Kit.head(false, 3), 26, Kit.ec(el)))
	ln.add_child(Kit.lab(MatchSetup.style(el), Kit.body(500), 19, Kit.WHITE))
	Kit.put(info, ln, Rect2(0, 0, 900, 30))
	var ps := KitWords.passive(el)
	var pl := Kit.hbox(12)
	pl.add_child(Kit.tag("PASSIVE  ·  " + String(ps.get("name", "")).to_upper(), 16, Kit.INK, Kit.plate_c(el), 2))
	pl.add_child(Kit.lab(String(ps.get("line", "")), Kit.body(500), 18, Kit.DIM))
	Kit.put(info, pl, Rect2(0, 38, 900, 30))
	var keys := Kit.hbox(8)
	for k: Dictionary in kit(el):
		var v := Kit.vbox(0)
		var top := Kit.hbox(6)
		var cap := Kit.lab(String(k.key), Kit.head(false, 1), 16, Kit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		var cc := Kit.chip(cap, Kit.NAVY3, 0.0, Vector4(6, 2, 6, 0), 1, Color(Kit.DIM, 0.5))
		(cc.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(3)
		top.add_child(cc)
		top.add_child(Kit.lab(String(k.role), Kit.head(false, 2), 15, Kit.FAINT))
		v.add_child(top)
		v.add_child(Kit.lab(String(k.move).to_upper(), Kit.head(false, 1), 25, Kit.WHITE))
		keys.add_child(Kit.chip(v, Color(Kit.NAVY1, 0.9), 0.0, Vector4(10, 6, 12, 4)))
	Kit.put(info, keys, Rect2(0, 80, 900, 70))
	# --- the match card at the right
	var mc := Kit.group(L, Vector2(1, 0), Vector2(-574, 128), Vector2(494, 716))
	Kit.plate(mc, Rect2(0, 0, 494, 716), Color(Kit.NAVY1, 0.94), 0.0)
	Kit.rect(mc, Rect2(0, 0, 494, 4), Kit.TEAL)
	Kit.put(mc, Kit.lab("THE MATCH", Kit.head(false, 5), 19, Kit.TEAL), Rect2(24, 14, 300, 24))
	var fm: Dictionary = (MatchSetup.data().get("formats", {}) as Dictionary).get("1v1", {})
	var fmt := Kit.hbox(8)
	fmt.add_child(Kit.tag(String(fm.get("label", "1 v 1")).to_upper(), 16, Kit.INK, Kit.TEAL, 2))
	fmt.add_child(Kit.lab(String(fm.get("line", "")).to_upper(), Kit.head(false, 2), 16, Kit.FAINT))
	fmt.alignment = BoxContainer.ALIGNMENT_END
	Kit.put(mc, fmt, Rect2(190, 12, 284, 26))
	# you against them
	element_plate(mc, Rect2(24, 46, 196, 58), el, 30)
	Kit.put(mc, Kit.lab("VS", Kit.head(true, 2), 40, Kit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), Rect2(222, 48, 52, 58))
	element_plate(mc, Rect2(276, 46, 196, 58), foe_el, 30)
	var y := 124.0
	var foes: Array = []
	for e: String in ELS:
		foes.append({"text": MatchSetup.label(e), "color": Kit.plate_c(e), "glyph": e})
	foes.append({"text": MatchSetup.label(MatchSetup.ANY), "color": Kit.ec(MatchSetup.ANY), "glyph": "any"})
	y = _setting(mc, y, "OPPONENT", foes, ELS.find(foe_el), "%s  ·  %s" % [MatchSetup.competitor(foe_el), MatchSetup.style(foe_el)], 19)
	y = _setting(mc, y, "DIFFICULTY", MatchSetup.DIFFICULTIES, MatchSetup.DIFFICULTIES.find(MatchSetup.difficulty),
			MatchSetup.difficulty_line(MatchSetup.difficulty))
	var rl := MatchSetup.menu_word("rules_line")
	y = _setting(mc, y, "RULES", [MatchSetup.rule_label("stock"), MatchSetup.rule_label("classic")], 0, rl.get_slice("  ·  ", 0))
	y = _setting(mc, y, "GAMES", [MatchSetup.games_label(1), MatchSetup.games_label(3)], 1, MatchSetup.menu_word("games_line"))
	y = _setting(mc, y, "LIGHT", MatchSetup.LIGHTS, MatchSetup.LIGHTS.find(MatchSetup.light), MatchSetup.light_line(MatchSetup.light))
	# controls
	Kit.rect(mc, Rect2(24, y, 446, 1), Color(Kit.LINE, 0.9))
	var cr := Kit.hbox(10)
	cr.add_child(Kit.lab(KitWords.w("controls", "Controls").to_upper(), Kit.head(false, 2), 24, Kit.WHITE))
	cr.add_child(Kit.glyph("next", Kit.DIM, 16))
	Kit.put(mc, cr, Rect2(24, y + 8, 446, 30))
	Kit.put(mc, Kit.lab(KitWords.w("controls_line"), Kit.body(500), 15, Kit.FAINT), Rect2(24, y + 36, 446, 22))
	# begin
	var by := y + 72
	var bg := Kit.plate(mc, Rect2(16, by, 462, 66), Kit.plate_c(el), Kit.LEAN, 3, Kit.WHITE)
	bg.name = "Begin"
	Kit.put(mc, Kit.lab("BEGIN", Kit.head(true, 6), 52, Kit.INK), Rect2(48, by + 4, 260, 62))
	var kh := Kit.key_hint("ENTER", "", 18)
	Kit.put(mc, kh, Rect2(392, by + 18, 80, 30))
	hints(L, [["ENTER", "Begin"], ["ESC", "Back"], ["1 - 4", "Element"], ["TAB", "Controls"]], false)
	print("BROADCAST match card ends at y=", by + 66, " of 716")


## One setting of the match card: its name, its choices, its line under them. Returns the next y.
func _setting(p: Control, y: float, title: String, opts: Array, chosen: int, line: String, px := 23, off := -1) -> float:
	Kit.rect(p, Rect2(24, y, 446, 1), Color(Kit.LINE, 0.9))
	Kit.put(p, Kit.lab(title, Kit.head(false, 4), 16, Kit.FAINT), Rect2(24, y + 9, 200, 20))
	var fill := Kit.TEAL
	segments(p, Vector2(26, y + 32), opts, chosen, fill, px, off)
	Kit.put(p, Kit.lab(line, Kit.body(500), 16, Kit.DIM), Rect2(26, y + 66, 446, 20))
	return y + 90


## A fighter's card: the fighter in the element's ring dress cut out over its colour, its name and its competitors'
## name; the chosen one lit and outlined in the accent, the others dimmed.
func card(p: Control, r: Rect2, el: String, n: int, chosen: bool) -> void:
	var pc := Kit.plate_c(el)
	var g := Kit.group(p, Vector2.ZERO, r.position, r.size)
	g.clip_contents = true
	if chosen:
		Kit.grad(g, [[0.0, pc.lightened(0.1)], [1.0, pc.darkened(0.55)]], Vector2(0.5, 0), Vector2(0.5, 1))
		Kit.stripes(g, Rect2(0, 0, r.size.x, r.size.y * 0.6), Color(Kit.WHITE, 0.12), 12, 3, 1.0)
	else:
		Kit.rect(g, Rect2(Vector2.ZERO, r.size), Color(Kit.NAVY2, 0.92))
		Kit.grad(g, [[0.0, Color(pc, 0.30)], [0.6, Color(pc, 0.0)]], Vector2(0.5, 0), Vector2(0.5, 1))
		Kit.rect(g, Rect2(0, 0, r.size.x, 5), pc)
	Kit.put(g, Kit.lab(str(n), Kit.head(true), 210, Color(Kit.INK, 0.16) if chosen else Color(pc, 0.10), HORIZONTAL_ALIGNMENT_RIGHT),
			Rect2(0, -36, r.size.x - 8, 220))
	var t := Kit.tex(_r("card_%s_cut.png" % el))
	if t != null:
		var tr := TextureRect.new()
		tr.texture = Kit.crop(t, Rect2(130, 190, 460, 870))
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not chosen:
			tr.modulate = Color(0.62, 0.66, 0.76)
		Kit.put(g, tr, Rect2(-6, 18, r.size.x + 12, r.size.y - 48))
	# the name plate at its foot
	Kit.grad(g, [[0.0, Color(Kit.NAVY0, 0.0)], [0.55, Color(Kit.NAVY0, 0.85)], [1.0, Color(Kit.NAVY0, 0.96)]],
			Vector2(0.5, 0), Vector2(0.5, 1), Rect2(0, 0.62, 1, 0.38))
	var nm := Kit.hbox(8)
	nm.add_child(Kit.glyph(el, pc, 26, Kit.NAVY0))
	nm.add_child(Kit.lab(MatchSetup.label(el).to_upper(), Kit.head(true, 2), 44, Kit.WHITE))
	Kit.put(g, nm, Rect2(14, r.size.y - 92, r.size.x - 20, 50))
	Kit.put(g, Kit.lab(MatchSetup.competitor(el).to_upper(), Kit.head(false, 5), 19, pc), Rect2(16, r.size.y - 44, 160, 26))
	var kc := Kit.lab(str(n), Kit.head(), 16, Kit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var kcc := Kit.chip(kc, Kit.NAVY3, 0.0, Vector4(7, 2, 7, 0), 1, Color(Kit.DIM, 0.5))
	(kcc.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(3)
	Kit.put(g, kcc, Rect2(r.size.x - 38, r.size.y - 42, 0, 0))
	if chosen:
		var b := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.set_border_width_all(4)
		sb.border_color = Kit.TEAL
		b.add_theme_stylebox_override("panel", sb)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Kit.put(g, b, Rect2(Vector2.ZERO, r.size))
		Kit.put(g, Kit.tag("YOU", 18, Kit.INK, Kit.TEAL, 3), Rect2(10, 14, 0, 0))


# ================================================================ 3. the Esc menu in the ring
func pause(L: Control, el: String, foe_el: String) -> void:
	Kit.picture(L, Kit.tex(_r("frame_pause.png"), 3, 0.95))
	Kit.rect(L, Rect2(0, 0, W, H), Color(Kit.NAVY0, 0.42)).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Kit.grad(L, [[0.0, Color(Kit.NAVY0, 0.95)], [0.40, Color(Kit.NAVY0, 0.82)], [0.62, Color(Kit.NAVY0, 0.30)]],
			Vector2(0, 0.5), Vector2(1, 0.5))
	var rw: Dictionary = _words("res://data/ring/rules.json").get("words", {})
	var foe_c := MatchSetup.competitor(foe_el)
	# --- the score bug at the top, as the broadcast has it (the menu's note: round, time left, score)
	scorebug(L, el, foe_el, 1, 0, [2, 1], "GAME 2  ·  1:42 LEFT")
	# --- the rows at the left
	var lf := Kit.group(L, Vector2(0, 0), Vector2(84, 40), Vector2(640, 820))
	Kit.put(lf, Kit.tag(String(rw.get("menu_title", "Tidebreak")).to_upper(), 18, Kit.INK, Kit.TEAL, 3), Rect2(0, 0, 0, 0))
	Kit.put(lf, Kit.lab("PAUSED", Kit.head(true, 3), 112, Kit.WHITE), Rect2(-4, 22, 600, 116))
	var y := 160.0
	y += row(lf, y, "01", String(rw.get("resume", "Resume")), "", false, el)
	y += row(lf, y, "02", String(rw.get("restart", "Restart match")), "", false, el)
	y += row(lf, y, "03", split_row(String(rw.get("element", "Element:  %s")))[0], "", false, el, 560.0, "", MatchSetup.label(el), el)
	y += row(lf, y, "04", split_row(String(rw.get("opponent", "Opponent:  %s")))[0], "", false, el, 560.0, "", MatchSetup.label(foe_el), foe_el)
	y += row(lf, y, "05", "Options", "aim help, key hints, the camera, the jolt, replays and callouts", true, el)
	y += row(lf, y, "06", KitWords.w("controls", "Controls"), "", false, el)
	y += row(lf, y, "07", String(rw.get("main_menu", "Main menu")), "", false, el)
	y += row(lf, y, "08", String(rw.get("quit", "Quit")), "", false, el)
	# --- the Options panel at the right
	var op := Kit.group(L, Vector2(1, 0), Vector2(-780, 176), Vector2(700, 610))
	Kit.plate(op, Rect2(0, 0, 700, 610), Color(Kit.NAVY1, 0.95), 0.0)
	Kit.rect(op, Rect2(0, 0, 700, 4), Kit.TEAL)
	Kit.put(op, Kit.lab("OPTIONS", Kit.head(true, 3), 44, Kit.WHITE), Rect2(26, 12, 300, 50))
	Kit.put(op, Kit.lab("each one at once, and kept", Kit.body(500), 17, Kit.DIM), Rect2(200, 24, 300, 30))
	var oy := 72.0
	var cam: Dictionary = RingCamera.data().get("variants", {})
	var cam_opts: Array = []
	for k: String in ["close", "shoulder", "high", "high_shoulder"]:
		cam_opts.append(String((cam.get(k, {}) as Dictionary).get("label", k)))
	var aims: Array = ["off", "light", "strong"]
	oy = _opt(op, oy, split_row(MatchSetup.aim_row())[0], aims, aims.find(MatchSetup.aim_help()), MatchSetup.aim_row_line())
	oy = _opt(op, oy, split_row(FirstHints.row_text())[0], ["on", "off"], 0 if FirstHints.on() else 1, FirstHints.row_line())
	oy = _opt(op, oy, split_row(RingCamera.row_text())[0], cam_opts, cam_opts.find(RingCamera.label()), RingCamera.row_line())
	oy = _opt(op, oy, split_row(RingCamera.jolt_row_text())[0], [RingCamera.word("jolt_on"), RingCamera.word("jolt_off")],
			0 if RingCamera.jolt_on() else 1, RingCamera.word("jolt_line"))
	var reps: Array = []
	for s: String in ["every", "last", "off"]:
		reps.append(RingReplay.word("row", s, s))
	oy = _opt(op, oy, split_row(RingReplay.row_text())[0], reps, ["every", "last", "off"].find(RingReplay.setting()), RingReplay.row_line())
	oy = _opt(op, oy, split_row(Callouts.row_text())[0], ["On", "Off"], 0 if Callouts.on() else 1, Callouts.row_line())
	Kit.rect(op, Rect2(26, oy, 648, 1), Color(Kit.LINE, 0.9))
	var ph := Kit.hbox(10)
	ph.add_child(Kit.lab(PhotoMode.row_text().to_upper(), Kit.head(false, 2), 26, Kit.WHITE))
	ph.add_child(Kit.glyph("next", Kit.DIM, 16))
	Kit.put(op, ph, Rect2(26, oy + 10, 300, 32))
	Kit.put(op, Kit.lab(PhotoMode.row_line(), Kit.body(500), 16, Kit.DIM), Rect2(26, oy + 44, 648, 22))
	hints(L, [["ESC", "Resume"], ["ENTER", "Select"], ["← →", "Change"]])
	print("BROADCAST pause foe=", foe_c)


func _opt(p: Control, y: float, title: String, opts: Array, chosen: int, line: String) -> float:
	Kit.rect(p, Rect2(26, y, 648, 1), Color(Kit.LINE, 0.9))
	Kit.put(p, Kit.lab(title.to_upper(), Kit.head(false, 2), 26, Kit.WHITE), Rect2(26, y + 10, 230, 32))
	var seg := segments(p, Vector2(0, y + 12), opts, maxi(chosen, 0), Kit.TEAL, 18)
	seg.position.x = 674 - seg.get_combined_minimum_size().x
	Kit.put(p, Kit.lab(line, Kit.body(500), 16, Kit.DIM), Rect2(26, y + 44, 648, 22))
	return y + 74


## The broadcast's score bug: your side, the games, theirs, the lives left as diamonds, the note under it.
func scorebug(L: Control, el: String, foe_el: String, a: int, b: int, lives: Array, note: String, top := 34.0) -> void:
	var g := Kit.group(L, Vector2(0.5, 0), Vector2(-338, top), Vector2(676, 110))
	_side(g, Rect2(0, 0, 250, 66), el, "YOU", int(lives[0]), false)
	Kit.plate(g, Rect2(246, 0, 184, 66), Color(Kit.NAVY0, 0.97))
	Kit.put(g, Kit.lab("%d" % a, Kit.head(), 62, Kit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), Rect2(262, 2, 60, 66))
	Kit.put(g, Kit.lab("%d" % b, Kit.head(), 62, Kit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), Rect2(354, 2, 60, 66))
	Kit.rect(g, Rect2(337, 18, 2, 30), Color(Kit.FAINT, 0.7))
	_side(g, Rect2(426, 0, 250, 66), foe_el, MatchSetup.competitor(foe_el).to_upper(), int(lives[1]), true)
	var n := Kit.hbox(0)
	n.alignment = BoxContainer.ALIGNMENT_CENTER
	n.add_child(Kit.tag(MatchSetup.rule_label().to_upper(), 17, Kit.INK, Kit.TEAL, 3))
	n.add_child(Kit.tag(note, 17, Kit.WHITE, Color(Kit.NAVY1, 0.96), 3))
	Kit.put(g, n, Rect2(0, 72, 676, 30))


func _side(g: Control, r: Rect2, el: String, who: String, lives: int, right: bool) -> void:
	var pc := Kit.plate_c(el)
	Kit.plate(g, r, pc)
	var gl := Kit.glyph(el, Kit.INK, 34, pc)
	var name := Kit.lab(who, Kit.head(true, 2), 42, Kit.INK)
	var pips := Kit.hbox(5)
	for i in 3:
		pips.add_child(Kit.glyph("diamond", Kit.INK if i < lives else Color(Kit.INK, 0.22), 14))
	if not right:
		Kit.put(g, gl, Rect2(r.position + Vector2(22, 16), Vector2(34, 34)))
		Kit.put(g, name, Rect2(r.position + Vector2(66, 6), Vector2(120, 60)))
		Kit.put(g, pips, Rect2(r.position + Vector2(r.size.x - 78, 26), Vector2(60, 14)))
	else:
		Kit.put(g, pips, Rect2(r.position + Vector2(34, 26), Vector2(60, 14)))
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		Kit.put(g, name, Rect2(r.position + Vector2(r.size.x - 200, 6), Vector2(130, 60)))
		Kit.put(g, gl, Rect2(r.position + Vector2(r.size.x - 58, 16), Vector2(34, 34)))


# ================================================================ 4. the match's end
func end_screen(L: Control, el: String, foe_el: String) -> void:
	Kit.picture(L, Kit.tex(_r("frame_end.png"), 3, 0.9))
	Kit.rect(L, Rect2(0, 0, W, H), Color(Kit.NAVY0, 0.70)).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Kit.stripes(L, Rect2(0, 0, W, 280), Color(Kit.WHITE, 0.025), 16, 3, 1.0)
	var mw: Dictionary = MatchSetup.screens().get("match", {})
	var hl: Dictionary = RingHighlights.data()
	var them := MatchSetup.competitor(foe_el)
	var pc := Kit.plate_c(el)
	var fc := Kit.plate_c(foe_el)
	# --- the head: the result and its line
	var hd := Kit.group(L, Vector2(0, 0), Vector2(84, 40), Vector2(720, 240))
	var t := Kit.hbox(0)
	t.add_child(Kit.tag("FINAL", 18, Kit.INK, Kit.TEAL, 4))
	t.add_child(Kit.tag("%s  ·  %s  ·  %s" % [MatchSetup.sport().to_upper(), MatchSetup.rule_label().to_upper(),
			MatchSetup.games_label().to_upper()], 18, Kit.WHITE, Color(Kit.NAVY1, 0.95), 3))
	Kit.put(hd, t, Rect2(0, 0, 0, 0))
	Kit.put(hd, Kit.lab(String(mw.get("head_win", "Victory")).to_upper(), Kit.head(true, 4), 150, Kit.WHITE), Rect2(-6, 34, 720, 150))
	Kit.plate(hd, Rect2(0, 182, 380, 6), pc)
	Kit.put(hd, Kit.lab(String(mw.get("line_win", "You take the match")), Kit.body(600), 28, Kit.DIM), Rect2(2, 192, 600, 40))
	# --- the scoreboard: the two sides with their fighters, the games between them
	var sb := Kit.group(L, Vector2(1, 0), Vector2(-820, 48), Vector2(740, 200))
	_team(sb, Rect2(0, 0, 280, 150), el, "YOU", false)
	Kit.plate(sb, Rect2(276, 0, 188, 150), Color(Kit.NAVY0, 0.96))
	Kit.put(sb, Kit.lab("2", Kit.head(), 150, Kit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), Rect2(282, 6, 80, 150))
	Kit.put(sb, Kit.lab("1", Kit.head(), 150, Kit.FAINT, HORIZONTAL_ALIGNMENT_CENTER), Rect2(380, 6, 80, 150))
	Kit.rect(sb, Rect2(369, 50, 3, 52), Color(Kit.FAINT, 0.8))
	_team(sb, Rect2(460, 0, 280, 150), foe_el, them.to_upper(), true)
	var ll := Kit.hbox(0)
	ll.alignment = BoxContainer.ALIGNMENT_CENTER
	ll.add_child(Kit.tag("GAMES", 17, Kit.INK, Kit.TEAL, 3))
	ll.add_child(Kit.tag((String(mw.get("lives_line", "Lives left  ·  you %d  ·  the %s %d")) % [2, them, 0]).to_upper(), 17,
			Kit.WHITE, Color(Kit.NAVY1, 0.96), 3))
	Kit.put(sb, ll, Rect2(0, 158, 740, 30))
	# --- the game log
	var gl := Kit.group(L, Vector2(0, 0), Vector2(84, 290), Vector2(470, 460))
	Kit.section(gl, Vector2(0, 0), "GAME BY GAME", 470)
	var yours := String(mw.get("who_win", "yours"))
	var theirs := String(mw.get("who_loss", "the %s's")) % them
	var games := [[1, yours, "2 : 0", true], [2, theirs, "0 : 1", false], [3, yours, "2 : 0", true]]
	var y := 36.0
	for gm: Array in games:
		var won: bool = gm[3]
		Kit.plate(gl, Rect2(0, y, 470, 44), Color(Kit.NAVY1, 0.92))
		Kit.plate(gl, Rect2(0, y, 8, 44), pc if won else fc)
		Kit.put(gl, Kit.lab((String(mw.get("fall_game", "Game %d")) % int(gm[0])).to_upper(), Kit.head(false, 2), 24, Kit.WHITE), Rect2(22, y, 120, 44))
		Kit.put(gl, Kit.lab(String(gm[1]).to_upper(), Kit.head(false, 2), 24, pc if won else fc), Rect2(130, y, 200, 44))
		Kit.put(gl, Kit.lab("LIVES  " + String(gm[2]), Kit.head(false, 2), 22, Kit.DIM, HORIZONTAL_ALIGNMENT_RIGHT), Rect2(270, y, 180, 44))
		y += 50
	y += 12
	Kit.put(gl, Kit.lab("GAME 3  ·  EVERY FALL", Kit.head(false, 4), 16, Kit.FAINT), Rect2(0, y, 470, 20))
	y += 26
	var fk := kit(el)
	var tk := kit(foe_el)
	var falls := [["0:41", them, 104, String(fk[2].move) if fk.size() > 2 else "-", false],
			["1:18", "you", 92, String(tk[3].move) if tk.size() > 3 else "-", true],
			["1:52", them, 131, String(fk[4].move) if fk.size() > 4 else "-", false],
			["2:37", them, 118, "Fireball", false]]
	for f: Array in falls:
		var mine: bool = f[4]
		Kit.put(gl, Kit.lab(String(f[0]), Kit.head(), 26, Kit.WHITE), Rect2(0, y, 60, 34))
		var who := String(mw.get("fall_you", "you")) if mine else String(mw.get("fall_them", "the %s")) % String(f[1])
		var dot := ColorRect.new()
		dot.color = pc if mine else fc
		Kit.put(gl, dot, Rect2(66, y + 12, 10, 10))
		Kit.put(gl, Kit.lab("%s into the water at %d%%" % [who, int(f[2])], Kit.body(500), 18, Kit.DIM), Rect2(86, y, 270, 34))
		Kit.put(gl, Kit.lab(String(f[3]).to_upper(), Kit.head(false, 1), 22, fc if mine else pc, HORIZONTAL_ALIGNMENT_RIGHT), Rect2(330, y, 140, 34))
		y += 36
	# --- the match's numbers, you against them
	var ms := Kit.group(L, Vector2(0.5, 0), Vector2(-212, 290), Vector2(460, 460))
	Kit.section(ms, Vector2(0, 0), "THE NUMBERS", 460)
	var lh := Kit.hbox(8)
	lh.add_child(Kit.glyph(el, pc, 20))
	lh.add_child(Kit.lab("YOU", Kit.head(false, 3), 20, pc))
	Kit.put(ms, lh, Rect2(0, 32, 200, 26))
	var rh := Kit.hbox(8)
	rh.alignment = BoxContainer.ALIGNMENT_END
	rh.add_child(Kit.lab(them.to_upper(), Kit.head(false, 3), 20, fc))
	rh.add_child(Kit.glyph(foe_el, fc, 20))
	Kit.put(ms, rh, Rect2(260, 32, 200, 26))
	var rows := [["FALLS DEALT", 8, 5, ""], ["% DEALT", 742, 516, ""], ["HIGHEST % SURVIVED", 138, 121, ""],
			["LONGEST STRING", 6, 4, " hits"], ["CATCHES", 11, 7, ""], ["PERFECT GUARDS", 4, 2, ""], ["EDGE SAVES", 3, 1, ""]]
	var sy := 66.0
	for r: Array in rows:
		var a := float(r[1])
		var b := float(r[2])
		var m := maxf(a, b)
		Kit.put(ms, Kit.lab(str(int(a)), Kit.head(), 34, Kit.WHITE), Rect2(0, sy, 80, 36))
		Kit.put(ms, Kit.lab(str(int(b)), Kit.head(), 34, Kit.DIM, HORIZONTAL_ALIGNMENT_RIGHT), Rect2(380, sy, 80, 36))
		Kit.put(ms, Kit.lab(String(r[0]), Kit.head(false, 3), 17, Kit.FAINT, HORIZONTAL_ALIGNMENT_CENTER), Rect2(80, sy + 2, 300, 24))
		var bw := 170.0
		Kit.rect(ms, Rect2(60, sy + 32, bw, 6), Color(Kit.NAVY3, 0.9))
		Kit.rect(ms, Rect2(230, sy + 32, bw, 6), Color(Kit.NAVY3, 0.9))
		Kit.rect(ms, Rect2(60 + bw * (1.0 - a / m), sy + 32, bw * a / m, 6), pc)
		Kit.rect(ms, Rect2(230, sy + 32, bw * b / m, 6), fc)
		sy += 54
	# --- the highlights
	var hc := Kit.group(L, Vector2(1, 0), Vector2(-500, 290), Vector2(420, 460))
	Kit.section(hc, Vector2(0, 0), String(hl.get("head", "Highlights")).to_upper(), 420)
	var plays: Dictionary = hl.get("plays", {})
	var who_you := String((hl.get("who", {}) as Dictionary).get("you", "You"))
	var whom_them := String((hl.get("whom", {}) as Dictionary).get("them", "the %s")) % them
	var cards := [["launch", 31.0], ["catch", 0.08], ["fast_ko", 6.4]]
	var hy := 36.0
	for c: Array in cards:
		var pl: Dictionary = plays.get(String(c[0]), {})
		Kit.plate(hc, Rect2(0, hy, 420, 120), Color(Kit.NAVY1, 0.94), 0.0)
		Kit.rect(hc, Rect2(0, hy, 6, 120), pc)
		Kit.put(hc, Kit.lab(String(pl.get("title", "")).to_upper(), Kit.head(false, 2), 28, Kit.WHITE), Rect2(24, hy + 10, 300, 34))
		var line := String(pl.get("line", "")).replace("{who}", who_you).replace("{whom}", whom_them)
		Kit.put(hc, Kit.lab(line, Kit.body(500), 17, Kit.DIM), Rect2(24, hy + 44, 380, 24))
		var num := String(pl.get("num", "%s"))
		var ns := num % (int(c[1]) if num.contains("%d") else float(c[1]))
		Kit.put(hc, Kit.lab(ns.to_upper(), Kit.head(true, 1), 46, pc), Rect2(24, hy + 66, 240, 50))
		var wt := Kit.hbox(8)
		wt.add_child(Kit.glyph("play", Kit.INK, 16))
		wt.add_child(Kit.lab(String(hl.get("watch", "Watch")).to_upper(), Kit.head(false, 3), 18, Kit.INK))
		Kit.put(hc, Kit.chip(wt, Kit.TEAL, Kit.LEAN, Vector4(14, 4, 16, 1)), Rect2(292, hy + 76, 0, 0))
		hy += 130
	# --- the rows along the foot
	var ab := Kit.group(L, Vector2(0, 1), Vector2(84, -142), Vector2(1440, 70))
	ab.anchor_right = 1.0
	ab.offset_right = -84
	var x := 0.0
	x += _action(ab, x, String(mw.get("rematch", "Rematch")), String(mw.get("rematch_line", "")), true, el, "", 330)
	x += _action(ab, x, split_row(String(mw.get("element", "Your element:  %s")))[0], String(mw.get("element_line", "")), false, el, el, 380)
	x += _action(ab, x, split_row(String(mw.get("opponent", "Opponent:  %s")))[0], String(mw.get("opponent_line", "")), false, el, foe_el, 360)
	x += _action(ab, x, String(mw.get("main_menu", "Main menu")), String(mw.get("main_menu_line", "")), false, el, "", 300)
	hints(L, [["ENTER", "Select"], ["ESC", "Ring menu"]])


func _team(p: Control, r: Rect2, el: String, who: String, right: bool) -> void:
	var pc := Kit.plate_c(el)
	var g := Kit.group(p, Vector2.ZERO, r.position, r.size)
	g.clip_contents = true
	Kit.grad(g, [[0.0, pc], [1.0, pc.darkened(0.35)]], Vector2(0.5, 0), Vector2(0.5, 1))
	Kit.stripes(g, Rect2(Vector2.ZERO, r.size), Color(Kit.WHITE, 0.10), 12, 3, 1.0)
	var t := Kit.tex(_r("card_%s_cut.png" % el))
	if t != null:
		var tr := TextureRect.new()
		tr.texture = Kit.crop(t, Rect2(200, 200, 340, 340))
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.flip_h = right
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Kit.put(g, tr, Rect2(Vector2(r.size.x - 150, 0) if right else Vector2(-8, 0), Vector2(160, 160)))
	var name := Kit.lab(who, Kit.head(true, 2), 54, Kit.INK, HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT)
	var sub := Kit.lab(MatchSetup.label(el).to_upper(), Kit.head(false, 4), 18, Color(Kit.INK, 0.7),
			HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT)
	if right:
		Kit.put(g, name, Rect2(12, 34, 140, 60))
		Kit.put(g, sub, Rect2(12, 92, 140, 24))
	else:
		Kit.put(g, name, Rect2(140, 34, 130, 60))
		Kit.put(g, sub, Rect2(140, 92, 130, 24))


## One of the match screen's rows along the foot: a leaning plate, its title and its line; `val_el` a value tag after it.
func _action(p: Control, x: float, title: String, line: String, focus: bool, el: String, val_el: String, w: float) -> float:
	var pc := Kit.plate_c(el)
	Kit.plate(p, Rect2(x, 0, w - 14, 66), pc if focus else Color(Kit.NAVY1, 0.94), Kit.LEAN, 3 if focus else 0, Kit.WHITE)
	var fg := Kit.INK if focus else Kit.WHITE
	var t := Kit.lab(title.to_upper(), Kit.head(true, 2), 32, fg)
	Kit.put(p, t, Rect2(x + 22, 4, w - 40, 38))
	if val_el != "":
		var h := Kit.hbox(6)
		h.add_child(Kit.glyph("prev", Kit.DIM, 12))
		h.add_child(Kit.glyph(val_el, Kit.plate_c(val_el), 18))
		h.add_child(Kit.lab(MatchSetup.label(val_el).to_upper(), Kit.head(false, 2), 24, Kit.plate_c(val_el)))
		h.add_child(Kit.glyph("next", Kit.DIM, 12))
		Kit.put(p, h, Rect2(x + 30 + t.get_minimum_size().x, 10, 0, 0))
	Kit.put(p, Kit.lab(line, Kit.body(500), 16, Color(Kit.INK, 0.8) if focus else Kit.DIM), Rect2(x + 24, 38, w - 50, 24))
	return w
