class_name BendStrip
extends VBoxContainer
## The arena's key strip (Tidebreak; FrontierHUD.set_arena; docs/bending_design.md "Controls": the owner, 2026-10-04, "have 1
## and the user can toggle between the 1s and then roll the wheel to change that spell to make it easy"; "The HUD says what
## is ready: `2 · Earth Wall · column (2/3)`"): five columns for the keys 1-5, each
##   the key's number      gold when its move is the one readied
##   the move's picture    its own icon (FrontierHUD.spell_texture), else the HUD's drawn circle
##   the move's name       the skill on the key now (16 px), and under it the key's other skill: "again: Rock Jab" (13 px, dim)
##   the variation pips    one per variation in the element's colour (MatchSetup.color), the one the wheel is on filled
## the readied column at full strength, the others at 0.62, and under them the ready line: "2 · Earth Wall · column (2/3)"
## (" · water 64" after it for a water fighter). Under it the quick spell (SwayCaster's, the owner 2026-10-05): an "LMB" chip
## and its move at its frozen variation ("LMB  Rock Jab (pebbles)"), and the help line "Q: set left click · hold LMB: cast
## it" (the set key as bound). What it shows comes from the player's own hotbar (slots 1-5), its caster (the variation, the
## quick spell) and its Bending node (the element, the water): nothing about anyone else.
## Each control scheme (MatchSetup.scheme(), the player's caster's: SwayCaster.scheme) has its own strip:
##   keys       as above
##   direction  four columns: W the attack, S the defence, A D the dodge (each at its own variation, under it), then the
##              key's move (the readied, its number and its other skill under it); the column of the direction held lit
##   radial     no key columns: the ready line, and the wheel's line under it ("hold Tab: the wheel ...")
##   simple     four columns (keys 1-4, the four moves), under each its two forms ("boulder / spike", near / far); no pips: the
##              form is picked as the right button is let go (nothing on the strip follows the opponent: no target cue)
## and the scheme's help line (schemes.json "strip") after the quick spell's help line (help_text: the duel's world HUD too).
##   column(i) -> {key, head, sub, hidden, id, label, other, other_label, modes, mode_i, readied}; ready_line(); quick_line();
##   help_line(); refresh()

const KEYS := 5
const COL_W := 112.0
const ICON_PX := 40.0
const DIM_A := 0.62
const PIP_R := 3.5
## The middle dot between the ready line's parts (as docs/bending_design.md writes it).
const SEP := " · "
## The quick spell's chip.
const CHIP := "LMB"

var player: FrontierPlayer

var _cols: Array = []          ## per key: {box, key, icon, name, other, pips}
var _line: Label
var _quick_box: Control
var _chip: Label
var _quick: Label
var _help: Label
var _sig := ""
var _dirty := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.name = "Keys"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	for i in KEYS:
		var box := VBoxContainer.new()
		box.name = "Key%d" % (i + 1)
		box.custom_minimum_size = Vector2(COL_W, 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 0)
		var k := FrontierHUD.hud_label(18, FrontierHUD.TEXT)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		k.text = str(i + 1)
		box.add_child(k)
		var icon := Control.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.draw.connect(_draw_icon.bind(i))
		box.add_child(icon)
		var nm := FrontierHUD.hud_label(16, FrontierHUD.INK)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		nm.custom_minimum_size = Vector2(COL_W, 0)
		box.add_child(nm)
		var ot := FrontierHUD.hud_label(13, FrontierHUD.DIM)
		ot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ot.clip_text = true
		ot.custom_minimum_size = Vector2(COL_W, 0)
		box.add_child(ot)
		var pips := Control.new()
		pips.name = "Pips"
		pips.custom_minimum_size = Vector2(COL_W, 12)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.draw.connect(_draw_pips.bind(i))
		box.add_child(pips)
		row.add_child(box)
		_cols.append({"box": box, "key": k, "icon": icon, "name": nm, "other": ot, "pips": pips, "tex": null, "tex_id": ""})
	_line = FrontierHUD.hud_label(17, FrontierHUD.INK)
	_line.name = "ReadyLine"
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_line)
	# the quick spell: an "LMB" chip and its move (variation), then the help line
	var q := HBoxContainer.new()
	q.name = "Quick"
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q.alignment = BoxContainer.ALIGNMENT_CENTER
	q.add_theme_constant_override("separation", 6)
	var chip := make_chip()
	_chip = chip
	q.add_child(chip)
	_quick = FrontierHUD.hud_label(16, FrontierHUD.INK)
	_quick.name = "QuickName"
	q.add_child(_quick)
	_quick_box = q
	add_child(q)
	_help = FrontierHUD.hud_label(13, FrontierHUD.DIM)
	_help.name = "HelpLine"
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_help)
	_hook.call_deferred()


## The signals that change what it shows (it also looks each frame, so nothing is missed: a key, the wheel, a new bar).
func _hook() -> void:
	if player == null or not is_instance_valid(player):
		return
	var hb: Hotbar = player.hotbar
	if hb != null:
		hb.changed.connect(func() -> void: _dirty = true)
		hb.spell_selected.connect(func(_id: String) -> void: _dirty = true)
	var c := SwayCaster.of(player)
	if c != null:
		c.mode_changed.connect(func(_id: String, _m: String) -> void: _dirty = true)
		c.spell_readied.connect(func(_id: String) -> void: _dirty = true)


func _process(_dt: float) -> void:
	if player == null or not is_instance_valid(player) or not is_visible_in_tree():
		return
	var sig := _signature()
	if _dirty or sig != _sig:
		_sig = sig
		_dirty = false
		refresh()


# ---------------------------------------------------------------- what it shows
## The control scheme the strip shows (the player's caster's; "keys" without one).
func scheme() -> String:
	var c := SwayCaster.of(player) if player != null else null
	return c.scheme() if c != null else "keys"


## The strip's column i (0-based) under the scheme now: {key (1-5), head (the line over it: "1", "W"), sub (the dim line
## under the name), hidden (no column there in this scheme), id ("" empty), label, other (the key's other skill, "" none),
## other_label, modes (the variations), mode_i (the one shown filled, -1 none), readied (lit)}.
func column(i: int) -> Dictionary:
	match scheme():
		"direction":
			return _dir_column(i)
		"radial":
			var r := key_column(i)
			r.hidden = true
			return r
		"simple":
			return _simple_column(i)
	return key_column(i)


## Key i as the keys scheme shows it: its skill, "again: <its other skill>" under it, the wheel's variation filled.
func key_column(i: int) -> Dictionary:
	var out := {"key": i + 1, "head": str(i + 1), "sub": "", "hidden": false, "id": "", "label": "", "other": "", "other_label": "",
			"modes": [], "mode_i": -1, "readied": false}
	var hb: Hotbar = player.hotbar if player != null else null
	if hb == null:
		return out
	var e := hb.entry(i)
	if e.is_empty() or String(e.get("kind", "")) != Hotbar.SPELL:
		return out
	var id := String(e.id)
	out.id = id
	out.label = Hotbar.spell_label(id)
	var other := Bending.partner_of(id)
	out.other = other
	out.other_label = Hotbar.spell_label(other) if other != "" else ""
	out.sub = ("again: " + String(out.other_label)) if String(out.other_label) != "" else ""
	var ms: Array = SwayCaster.modes_of(id)
	out.modes = ms
	if not ms.is_empty():
		var c := SwayCaster.of(player)
		var m := c.base_mode_of(id) if c != null else String(ms[0])     # (the key's own: never the quick spell's frozen one)
		out.mode_i = maxi(ms.find(m), 0)
	out.readied = hb.spell == id and hb.selected() == i
	return out


## The direction scheme's columns: 0 W the attack, 1 S the defence, 2 A D the dodge (each its move at its own variation,
## lit while its direction is held), 3 the key's move (the readied: its number, lit with no direction held); 4 none.
const DIR_HEADS := ["W", "S", "A D"]
func _dir_column(i: int) -> Dictionary:
	var c := SwayCaster.of(player)
	var held := c.held_dir() if c != null else ""
	if i == 3:
		var hb: Hotbar = player.hotbar if player != null else null
		var at := hb.selected() if hb != null else -1
		var k := key_column(at) if at >= 0 else key_column(0)
		k.head = "%d · none" % int(k.key) if at >= 0 else "1-5"
		k.readied = at >= 0 and held == ""
		return k
	var out := {"key": i + 1, "head": "", "sub": "", "hidden": i > 3, "id": "", "label": "", "other": "", "other_label": "",
			"modes": [], "mode_i": -1, "readied": false}
	if i > 2:
		return out
	var dir := String(MatchSetup.DIRS[i])
	out.head = String(DIR_HEADS[i])
	var dm := MatchSetup.direction_move(_element(), dir)
	if dm.is_empty():
		return out
	var id := String(dm.id)
	out.id = id
	out.label = Hotbar.spell_label(id)
	out.sub = SwayCaster.mode_label(id, String(dm.mode))
	var ms: Array = SwayCaster.modes_of(id)
	out.modes = ms
	out.mode_i = ms.find(String(dm.mode))
	out.readied = held == dir
	return out


## The simple scheme's columns: keys 1-4 (the four moves), each with its two forms under it ("boulder / spike": near / far);
## no pips (the form is picked at the release); 5 none.
func _simple_column(i: int) -> Dictionary:
	var k := key_column(i)
	k.other = ""
	k.other_label = ""
	k.modes = []
	k.mode_i = -1
	var e := MatchSetup.simple_entry(_element(), String(k.id))
	if i > 3 or e.is_empty():
		k.hidden = true
		k.readied = false
		k.sub = ""
		return k
	# (near / far, short enough for the column; the ready line spells it out)
	k.sub = "%s / %s" % [SwayCaster.mode_label(String(k.id), String(e.near)), SwayCaster.mode_label(String(k.id), String(e.far))]
	return k


## The readied move as the HUD says it: "2 · Earth Wall · column (2/3)" (" · water 64" for a water fighter); "" none.
func ready_line() -> String:
	if player == null or player.hotbar == null:
		return ""
	var simple := scheme() == "simple"
	for i in KEYS:
		var col := key_column(i)              # (the readied key, whatever the scheme shows round it)
		if not bool(col.readied):
			continue
		var line := "%d%s%s" % [i + 1, SEP, String(col.label)]
		var ms: Array = col.modes
		var e := MatchSetup.simple_entry(_element(), String(col.id)) if simple else {}
		if not e.is_empty():
			line += "%snear %s · far %s" % [SEP, SwayCaster.mode_label(String(col.id), String(e.near)),
					SwayCaster.mode_label(String(col.id), String(e.far))]
		elif not ms.is_empty():
			line += "%s%s (%d/%d)" % [SEP, SwayCaster.mode_label(String(col.id), String(ms[int(col.mode_i)])), int(col.mode_i) + 1,
					ms.size()]
		var b := _bending()
		if b != null and b.element == "water":
			line += "%swater %d" % [SEP, roundi(b.water)]
		return line
	return ""


## The quick spell on LMB as the chip's line says it: "Rock Jab (pebbles)" ("" none).
func quick_line() -> String:
	var c := SwayCaster.of(player) if player != null else null
	return c.quick_label() if c != null else ""


## The strip's help line: how the quick spell is set and cast ("Q: set left click · hold LMB: cast it"; the set key as bound).
func help_line() -> String:
	return help_text()


## The quick spell's help line (the strip's, the world HUD's in a duel): "Q: set left click · hold LMB: cast it", the set
## key as bound ("set left click: no key bound" when the player unbound it); under it, with a control scheme other than the
## keys, the scheme's own line (schemes.json "strip": "let go of RMB holding  W attack · S defence ...").
static func help_text() -> String:
	var k := SwayCaster.quick_bind_key()
	var set_l := ("%s: set left click" % k) if k != "" else "set left click: no key bound"
	var line := "%s%shold %s: cast it" % [set_l, SEP, CHIP]
	var sl := MatchSetup.scheme_text("strip")
	return line + "\n" + sl if sl != "" else line


## The "LMB" chip: a gold Label in a thin gold frame (the Label's own stylebox: no box container on the HUD, the user:
## "those big cards are terrible"; tests/ui/test_hud_skills.gd): the strip's and the world HUD's quick spell row.
static func make_chip() -> Label:
	var chip := FrontierHUD.hud_label(14, FrontierHUD.GOLD)
	chip.name = "Chip"
	chip.text = CHIP
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.border_color = FrontierHUD.GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	chip.add_theme_stylebox_override("normal", sb)
	return chip


func _bending() -> Bending:
	return player.get_node_or_null(NodePath(String(Bending.NODE_NAME))) as Bending if player != null else null


func _element() -> String:
	var b := _bending()
	return b.element if b != null else ""


## What it shows, as one string (a change redraws it).
func _signature() -> String:
	var parts := PackedStringArray()
	for i in KEYS:
		var col := column(i)
		parts.append("%s/%d/%s/%s/%s/%s" % [col.id, int(col.mode_i), col.readied, col.head, col.sub, col.hidden])
	parts.append(ready_line())
	parts.append(_element())
	parts.append(quick_line())
	parts.append(help_line())                # (the set key rebound or unbound: the help line follows at once)
	return "|".join(parts)


func refresh() -> void:
	var tint := MatchSetup.color(_element()) if _element() != "" else FrontierHUD.GOLD
	for i in _cols.size():
		var col := column(i)
		var ui: Dictionary = _cols[i]
		var on := bool(col.readied)
		(ui.key as Label).add_theme_color_override("font_color", FrontierHUD.GOLD if on else FrontierHUD.TEXT)
		(ui.key as Label).text = String(col.head)
		(ui.name as Label).text = String(col.label) if String(col.id) != "" else "-"
		(ui.other as Label).text = String(col.sub)
		(ui.box as Control).modulate.a = 1.0 if on else DIM_A
		(ui.box as Control).visible = not bool(col.hidden)
		var id := String(col.id)
		if String(ui.tex_id) != id:
			ui["tex_id"] = id
			ui["tex"] = FrontierHUD.spell_texture(id, get_tree()) if id != "" else null
		ui["tint"] = tint
		(ui.icon as Control).queue_redraw()
		(ui.pips as Control).queue_redraw()
	_line.text = ready_line()
	_line.visible = _line.text != ""
	var ql := quick_line()
	_quick.text = ql
	_quick_box.visible = ql != ""
	_help.text = help_line()
	_help.visible = ql != ""


# ---------------------------------------------------------------- drawing
func _draw_icon(i: int) -> void:
	var ui: Dictionary = _cols[i]
	var icon := ui.icon as Control
	var r := Rect2(Vector2.ZERO, icon.size)
	if String(ui.tex_id) == "":
		return
	var tex: Texture2D = ui.tex
	if tex == null:
		FrontierHUD.draw_spell_circle(icon, r)
		return
	var ts := tex.get_size()
	var k := minf(r.size.x / ts.x, r.size.y / ts.y)
	var fit := Rect2(r.position + (r.size - ts * k) * 0.5, ts * k)
	icon.draw_texture_rect(tex, Rect2(fit.position + Vector2(1.5, 1.5), fit.size), false, Color(0, 0, 0, 0.45))
	icon.draw_texture_rect(tex, fit, false, FrontierHUD.GOLD if tex.resource_path.ends_with(".svg") else Color.WHITE)


func _draw_pips(i: int) -> void:
	var ui: Dictionary = _cols[i]
	var pips := ui.pips as Control
	var col := column(i)
	var ms: Array = col.modes
	if ms.size() < 2:
		return
	var tint: Color = ui.get("tint", FrontierHUD.GOLD)
	var gap := 12.0
	var x0 := pips.size.x * 0.5 - gap * float(ms.size() - 1) * 0.5
	var y := pips.size.y * 0.5
	for j in ms.size():
		var at := Vector2(x0 + gap * j, y)
		pips.draw_circle(at + Vector2(1, 1), PIP_R + 0.8, Color(0, 0, 0, 0.45))
		if j == int(col.mode_i):
			pips.draw_circle(at, PIP_R, tint)
		else:
			pips.draw_arc(at, PIP_R - 0.4, 0.0, TAU, 16, Color(tint.r, tint.g, tint.b, 0.8), 1.2, true)
