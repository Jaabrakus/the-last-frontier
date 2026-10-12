class_name BendStrip
extends Control
## The arena's key strip (Tidebreak; FrontierHUD.set_arena; round 2 of the skills, the owner 2026-10-05: "make the skills easy
## hard to master ... think human made think avg IQ"; skills_r2 spec §2.1, §6, §9): the same seven chips for every element,
## each button one job (KitWords):
##   LMB · JAB      the element's jab (Pebbles, Splash, Embers, Palm) or the move Q put on left click; what the next Q does
##                  ("Q: put Spike on left click", "hold Q: Pebbles back")
##   E · GUARD      the element's guard (Catch, Turn, Parry, Wind Guard); holding a stone it caught: "E again: throw it back"
##                  in gold (his own strip only)
##   1 · STRIKE  2 · PUSH ▲  3 · DASH  4 · WALL  5 · HEAL
##                  the readied move's plain name (a tap: the key's first move), "tap twice: Boulder" (the key's other move;
##                  under first_moves none); fire's 1 "hold to grow it: Fireball"
## the readied chip lit (its keycap gold, its picture in its element's colour, the rest dimmed). What it shows comes from the
## player's own hotbar, caster and Bending node: nothing about anyone else (no target cues of any kind).
##   column(i) (keys 0-4) -> {key, head, sub, grow, hidden, id, mode, label, other, other_label, modes, mode_i, readied, tap,
##   icon_id, icon_mode}; chip("jab" | "guard") -> {head, id, mode, label, sub, lit, icon_id, icon_mode}; tap_alpha(i);
##   ready_line(); quick_line(); q_line(); help_line(); refresh()
## Each control scheme (MatchSetup.scheme(): keys, first_moves, direction, radial) keeps the seven chips: direction heads the
## columns W / 1, A D / 3, S / 4 and lights the held one; the wheel's scheme says so in its help line.
## ROUND 3, the % ring (RingRules.stock_on(); smash_r3 spec v2 §10.4; screens.json strip_stock): while your own RingMoves says
## you are airborne key 2 shows your Slam (Hammer, Downpour, Axe Kick, Down Gust), key 3 "Dodge", ground spells grey with
## "lands" (Breath stays available); key 3 never takes the readied highlight; move names dim at 2, 4 and 6 stale copies
## (RingRules.stale_count: your own queue); "safe" for safe_s after a hit of yours passed through a safe body. column(i)
## adds {grey, stale}; safe_shown().
## ROUND 4 (HUD; the owner's FEEL list: "a cleaner HUD"; "those big cards are terrible"): the strip OFF THE BODY and cleaner.
##   compact chips   the key in a small keycap over the move's own picture (assets/ui/icons: every chip its own, our own set,
##                   tools/ui/move_icons.py; icon_texture asks for spell_<id>__<mode>.svg, then spell_<id>.svg), the name
##                   under it. A readied chip's picture takes its element's colour (RingSides.home_colour), the others dim.
##   layouts         hud.json strip.layout (layout_override for stills): L1 the whole strip bottom-left (your side, under
##                   your plate; the default), L2 split (LMB, E, 1, 2 left of the body; 3, 4, 5 right of it), L3 a compact
##                   centre (32 px pictures, names only, near the bottom). Placed by the screen's size only (never a body's).
##   the lines       "tap twice: X" under a chip only in the first match (FirstHints up: after that key's second cast, as
##                   round 2) or while that key is held; ONE help line (KitWords.strip_help: 64 characters or fewer, one line)
##                   above the strip on its side, in the first match and in Practice, fading after help_casts casts; the
##                   caught stone's line (gold, the only gold but the readied chip) and what Q does above it.
##   type            three sizes: PercentBar's digits, 16 px for heads and names, 13 px for hints; one ink outline (ink_px).
## No card behind the strip; a soft shade along the screen's bottom edge at most (hud.json strip.shade_alpha).
## strip_rects() (the tests: never the strip's own reading), every_chip() (every chip any element can show, both rule sets).

const KEYS := 5
## The middle dot between a head's parts.
const SEP := " · "
## The jab chip's key (the left button).
const CHIP := "LMB"
## A revealed "tap twice" line's fade in (s).
const TAP_FADE_S := 0.6
## Casts of a key before its "tap twice" line shows in the first match.
const TAP_AFTER := 2
const ICON_DIR := "res://assets/ui/icons/"
const LAYOUTS := ["L1", "L2", "L3"]
## The type system's two lettering sizes (the plates' digits are PercentBar's own).
const NAME_PX := 16
const HINT_PX := 13

var player: FrontierPlayer
## Tests and stills: true / false stand for the first match (FirstHints up) or not; null reads it.
var first_match_override: Variant = null
## Tests and stills: true / false stand for Practice or not; null reads the match.
var practice_override: Variant = null
## Tests and stills: "L1" | "L2" | "L3" in place of hud.json's.
var layout_override := ""
## Tests and stills: key index -> true stands for that key held.
var held_override := {}
## Px the strip stands higher (the HUD's: the classic ring's health row under it).
var lift_px := 0.0

var _cols: Array = []          ## per key: {box, key (the head, kept unseen for its callers), cap, icon, name, other, grow, tex, tex_id}
var _chips := {}               ## "jab" / "guard" -> the same
var _left: HBoxContainer
var _right: HBoxContainer
var _shade: TextureRect
var _line: Label               ## (kept for the readied line's callers; not shown: the lit chip says it)
var _quick_box: Control
var _chip: Label
var _quick: Label
var _help: Label
var _hint: Label               ## the caught stone's line (gold) or what Q does, above the help line
var _sig := ""
var _dirty := true
## The full look (_signature: every column and chip in words, the keys as bound) is taken every SIG_EVERY_S; between, only
## what changes in a frame (the guard's button, the lock, the readied move: _quick_sig) marks it dirty.
const SIG_EVERY_S := 0.15
var _sig_t := 0.0
var _qsig := ""
## Casts per key this match (the first match's "tap twice" lines), and each line's fade (0..1); every cast of the player's
## (the help line's count).
var _casts := [0, 0, 0, 0, 0]
var _tap_a := [0.0, 0.0, 0.0, 0.0, 0.0]
var _all_casts := 0
var _help_a := 0.0
var _hooked: SwayCaster
## Round 3 (stock): tests and stills: true / false stand for airborne (null: the player's RingMoves says); "safe" shown for
## this long still; the rules hooked for hit_safe.
var air_override: Variant = null
var _safe_t := 0.0
var _safe: Label
var _hooked_rules: RingRules
var _laid_key := ""
var _placed := ""
static var _tex_cache := {}


## hud.json "strip" (every number of the strip's place and size).
static func scfg() -> Dictionary:
	var b: Variant = PercentBar.hud_cfg().get("strip", {})
	return b if b is Dictionary else {}


static func snum(key: String, def: float) -> float:
	return float(scfg().get(key, def))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade = TextureRect.new()
	_shade.name = "EdgeShade"
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.texture = _edge_shade()
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_shade)
	_left = _group("Keys")
	_right = _group("KeysRight")
	for kind: String in ["jab", "guard"]:
		_chips[kind] = _make_box("Chip_" + kind)
	for i in KEYS:
		_cols.append(_make_box("Key%d" % (i + 1)))
	# (the old quick row's pieces kept for their callers: the jab chip's head and name are them now)
	_chip = (_chips.jab as Dictionary).key
	_quick = (_chips.jab as Dictionary).name
	_quick_box = (_chips.jab as Dictionary).box
	_line = FrontierHUD.hud_label(NAME_PX, FrontierHUD.INK)
	_line.name = "ReadyLine"
	_line.visible = false
	add_child(_line)
	_help = FrontierHUD.hud_label(HINT_PX, FrontierHUD.TEXT)
	_help.name = "HelpLine"
	_inked(_help)
	add_child(_help)
	_hint = FrontierHUD.hud_label(NAME_PX, FrontierHUD.INK)
	_hint.name = "HintLine"
	_inked(_hint)
	_hint.visible = false
	add_child(_hint)
	_safe = FrontierHUD.hud_label(NAME_PX, Color(0.62, 0.86, 0.96))
	_safe.name = "Safe"
	_inked(_safe)
	_safe.visible = false
	add_child(_safe)
	_place_chips()
	_hook.call_deferred()


func _group(nm: String) -> HBoxContainer:
	var g := HBoxContainer.new()
	g.name = nm
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.add_theme_constant_override("separation", int(snum("gap", 3.0)))
	g.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(g)
	return g


## A soft dark band along the screen's bottom edge (no card: the owner, "those big cards are terrible").
static func _edge_shade() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.015, 0.01, 0.0))
	g.set_color(1, Color(0.02, 0.015, 0.01, 1.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 4
	t.height = 64
	return t


## A chip's box: the head (kept unseen: its callers read it), the keycap, the move's picture, its name, the dim line under it,
## the grow line.
func _make_box(nm: String) -> Dictionary:
	var w := snum("chip_w", 64.0)
	var box := VBoxContainer.new()
	box.name = nm
	box.custom_minimum_size = Vector2(w, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 1)
	var k := FrontierHUD.hud_label(NAME_PX, FrontierHUD.TEXT)
	k.name = "Head"
	k.visible = false
	box.add_child(k)
	var cap := FrontierHUD.hud_label(HINT_PX, FrontierHUD.TEXT)
	cap.name = "Cap"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.025, 0.02, float(scfg().get("cap_alpha", 0.62)))
	sb.border_color = Color(FrontierHUD.TEXT, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	cap.add_theme_stylebox_override("normal", sb)
	box.add_child(cap)
	var icon := Control.new()
	icon.name = "Icon"
	var ip := snum("icon_px", 40.0)
	icon.custom_minimum_size = Vector2(ip, ip)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var n := FrontierHUD.hud_label(NAME_PX, FrontierHUD.INK)
	n.name = "Name"
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(n)
	var ot := FrontierHUD.hud_label(HINT_PX, FrontierHUD.TEXT)
	ot.name = "Sub"
	ot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ot.custom_minimum_size = Vector2(w, 0)
	box.add_child(ot)
	var gr := FrontierHUD.hud_label(HINT_PX, FrontierHUD.TEXT)
	gr.name = "Grow"
	gr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gr.custom_minimum_size = Vector2(w, 0)
	gr.visible = false
	box.add_child(gr)
	for l: Label in [k, cap, n, ot, gr]:
		_inked(l)
	var ui := {"box": box, "key": k, "cap": cap, "icon": icon, "name": n, "other": ot, "grow": gr, "tex": null, "tex_id": "",
			"tint": Color.WHITE}
	icon.draw.connect(_draw_icon.bind(ui))
	return ui


## The ONE ink outline (hud.json strip.ink_px) round a label's letters: the strip reads over a bright deck with no card behind it
## (the owner: "those big cards are terrible").
static func _inked(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.01, 0.88))
	l.add_theme_constant_override("outline_size", int(snum("ink_px", 5.0)))


# ---------------------------------------------------------------- the layout (the screen's size only)
## The layout now ("L1" | "L2" | "L3").
func layout() -> String:
	if layout_override in LAYOUTS:
		return layout_override
	var l := String(PercentBar.hud_cfg().get("strip_layout", scfg().get("layout", "L1")))
	return l if l in LAYOUTS else "L1"


## The chips into their groups for the layout: L2 LMB, E, 1 and 2 left, 3, 4 and 5 right; L1 and L3 all in one.
func _place_chips() -> void:
	var lay := layout()
	var order: Array = [_chips.jab, _chips.guard] + _cols
	for i in order.size():
		var box := (order[i] as Dictionary).box as Control
		var want := _right if lay == "L2" and i >= 4 else _left
		if box.get_parent() != want:
			if box.get_parent() != null:
				box.get_parent().remove_child(box)
			want.add_child(box)
	var ip := snum("icon_px_l3", 32.0) if lay == "L3" else snum("icon_px", 40.0)
	for ui: Dictionary in order:
		(ui.icon as Control).custom_minimum_size = Vector2(ip, ip)
	_right.visible = lay == "L2"
	_placed = lay
	_dirty = true


## Lays the groups, the lines and the shade out on the screen (by its size, the layout and lift_px).
func _lay() -> void:
	var vp := get_viewport_rect().size
	var lay := layout()
	var key := "%s|%s|%s|%s|%s" % [lay, vp, lift_px, _left.get_combined_minimum_size(), _right.get_combined_minimum_size()]
	if key == _laid_key:
		return
	_laid_key = key
	if lay != _placed:
		_place_chips()
	var k := vp.y / maxf(snum("ref_h", 720.0), 1.0)
	var mx := snum("margin_x", 16.0)
	var bottom := (snum("bottom_l3", 18.0) if lay == "L3" else snum("bottom", 10.0)) + lift_px
	var ls := _left.get_combined_minimum_size()
	var rs := _right.get_combined_minimum_size()
	_left.size = ls
	_right.size = rs
	match lay:
		"L2":
			var split := snum("split_px", 118.0) * k
			_left.position = Vector2(vp.x * 0.5 - split - ls.x, vp.y - bottom - ls.y)
			_right.position = Vector2(vp.x * 0.5 + split, vp.y - bottom - rs.y)
		"L3":
			_left.position = Vector2(vp.x * 0.5 - ls.x * 0.5, vp.y - bottom - ls.y)
		_:
			_left.position = Vector2(mx, vp.y - bottom - ls.y)
	# the lines over the strip on its side (L3: centred over it)
	var y := _left.position.y - snum("line_gap", 4.0)
	for l: Label in [_help, _hint, _safe]:
		l.size = l.get_combined_minimum_size()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if lay == "L3" else HORIZONTAL_ALIGNMENT_LEFT
		y -= l.size.y
		l.position = Vector2(_left.position.x + (ls.x - l.size.x) * 0.5 if lay == "L3" else _left.position.x, y)
	# the soft shade along the bottom edge
	var sh := snum("shade_h", 150.0) * k
	_shade.position = Vector2(0, vp.y - sh)
	_shade.size = Vector2(vp.x, sh)
	_shade.modulate.a = snum("shade_alpha", 0.3)


## The screen rects the strip takes now (its groups, the lines shown): the tests' overlap check (the strip never reads a body).
func strip_rects() -> Array:
	_lay()
	var out: Array = []
	for g: Control in [_left, _right]:
		if g.is_visible_in_tree() and g.get_child_count() > 0:
			out.append(g.get_global_rect())
	for l: Label in [_help, _hint, _safe]:
		if l.is_visible_in_tree() and l.text != "" and l.modulate.a > 0.01:
			out.append(l.get_global_rect())
	return out


# ---------------------------------------------------------------- the signals
## The signals that change what it shows (it also looks each frame, so nothing is missed: a key, the wheel, a new bar).
func _hook() -> void:
	if player == null or not is_instance_valid(player):
		return
	var hb: Hotbar = player.hotbar
	if hb != null:
		hb.changed.connect(func() -> void: _dirty = true)
		hb.spell_selected.connect(func(_id: String) -> void: _dirty = true)
	_hook_caster()


func _hook_caster() -> void:
	var c := SwayCaster.of(player) if player != null else null
	if c == null or c == _hooked:
		return
	_hooked = c
	c.mode_changed.connect(func(_id: String, _m: String) -> void: _dirty = true)
	c.spell_readied.connect(func(_id: String) -> void: _dirty = true)
	c.cast.connect(_on_cast)


## A cast of the player's: its key's count (the first match's "tap twice" lines; the jab and the guard are no key's) and the
## help line's.
func _on_cast(m: String, _t: Node3D) -> void:
	_all_casts += 1
	var c := SwayCaster.of(player) if player != null else null
	var md := c.mode_of(m) if c != null else ""
	if c != null and c.get(&"lock_src") == SwayCaster.SRC_QUICK:
		return
	var k := KitWords.key_of(_element(), m, md)
	if int(k.key) >= 0 and int(k.key) < KEYS:
		_casts[int(k.key)] = int(_casts[int(k.key)]) + 1
		_dirty = true


## Counts a cast of key `i` (0-based) as the player's (tests and stills: the same as one of his casts).
func count_cast(i: int) -> void:
	_all_casts += 1
	if i >= 0 and i < KEYS:
		_casts[i] = int(_casts[i]) + 1
		_dirty = true


## The casts counted for key `i` this match.
func casts_of(i: int) -> int:
	return int(_casts[i]) if i >= 0 and i < KEYS else 0


## Every cast counted this match (the help line's).
func casts_all() -> int:
	return _all_casts


func _process(dt: float) -> void:
	if _safe_t > 0.0:
		# ("safe" runs out on time, shown or not)
		_safe_t = maxf(_safe_t - dt, 0.0)
		_safe.visible = _safe_t > 0.0
		_safe.modulate.a = clampf(_safe_t / 0.15, 0.0, 1.0)
	if player == null or not is_instance_valid(player) or not is_visible_in_tree():
		return
	_hook_caster()
	_hook_rules()
	var fm := first_match()
	var l3 := layout() == "L3"
	for i in KEYS:
		var want := 1.0 if ((fm and int(_casts[i]) >= TAP_AFTER) or held(i)) and not l3 else 0.0
		var a := move_toward(float(_tap_a[i]), want, dt / TAP_FADE_S)
		if a != float(_tap_a[i]):
			_tap_a[i] = a
		var ui: Dictionary = _cols[i]
		if bool(ui.get("grey", false)):
			# ("lands" under a grey chip in the air: always)
			(ui.other as Label).modulate.a = 1.0
			(ui.other as Label).visible = not l3
		else:
			(ui.other as Label).modulate.a = float(_tap_a[i])
			(ui.other as Label).visible = float(_tap_a[i]) > 0.001 and (ui.other as Label).text != ""
		(ui.grow as Label).modulate.a = float(_tap_a[i])
		(ui.grow as Label).visible = float(_tap_a[i]) > 0.001 and (ui.grow as Label).text != ""
	_help_a = move_toward(_help_a, 1.0 if help_on() else 0.0, dt / maxf(snum("help_fade_s", 1.0), 0.01))
	_help.modulate.a = _help_a
	_help.visible = _help_a > 0.001 and _help.text != ""
	_paint_hint()
	var q := _quick_sig()
	if q != _qsig:
		_qsig = q
		_dirty = true
	_lay()
	_sig_t -= dt
	if not _dirty and _sig_t > 0.0:
		return
	_sig_t = SIG_EVERY_S
	var sig := _signature()
	if _dirty or sig != _sig:
		_sig = sig
		_dirty = false
		refresh()


# ---------------------------------------------------------------- what it shows
## The control scheme the strip shows (the player's caster's; "keys" without one), "simple" read as "first_moves".
func scheme() -> String:
	var c := SwayCaster.of(player) if player != null else null
	return KitWords.scheme_id(c.scheme()) if c != null else "keys"


## Whether this is the player's first match (FirstHints up: a first Quick match), or what a test set.
func first_match() -> bool:
	if first_match_override != null:
		return bool(first_match_override)
	return is_inside_tree() and FirstHints.find(get_tree()) != null


## Whether the match is Practice (or what a test set).
func practice() -> bool:
	if practice_override != null:
		return bool(practice_override)
	var m := RingMode.find(get_tree()) if is_inside_tree() else null
	return m != null and m.practice


## Whether key `i` (0-based) is held now (its "tap twice" line shows while it is).
func held(i: int) -> bool:
	if held_override.has(i):
		return bool(held_override[i])
	var a := StringName("weapon_%d" % (i + 1))
	return InputMap.has_action(a) and Input.is_action_pressed(a)


## The help line shows: in the first match and in Practice, until help_casts casts (then it fades).
func help_on() -> bool:
	return (first_match() or practice()) and _all_casts < int(snum("help_casts", 20.0))


## How much of key `i`'s "tap twice" line shows (0 hidden .. 1).
func tap_alpha(i: int) -> float:
	return float(_tap_a[i]) if i >= 0 and i < KEYS else 0.0


## The readied move: {id, mode} ({} none).
func readied() -> Dictionary:
	var c := SwayCaster.of(player) if player != null else null
	if c == null or c.readied_spell == "":
		return {}
	return {"id": c.readied_spell, "mode": c.base_mode_of(c.readied_spell)}


## Key i (0-based) as the strip shows it under the scheme now: {key (1-5), head ("1 · STRIKE", "W / 1 · STRIKE"), id, mode,
## label (the move shown: the readied one when it is this key's, else its first), sub ("tap twice: Boulder", "tap: Spike"
## when the second is the readied one; "" none), tap (the tap twice line, shown or not), grow ("hold to grow it: Fireball"),
## other, other_label (the key's other move), hidden, readied (lit), modes, mode_i (none: no forms in round 2), icon_id,
## icon_mode (its picture: the move's, the Slam's or Dodge's in the air, the Fireball's while it has grown)}.
func column(i: int) -> Dictionary:
	var el := _element()
	var s := scheme()
	# (round 4 SIMPLE: under the Basic controls 4 and 5 hidden until the first win, RingAssist.key_locked)
	var out := {"key": i + 1, "head": "", "sub": "", "tap": "", "grow": "", "hidden": i >= KEYS or RingAssist.key_locked(player, i + 1),
			"id": "", "mode": "", "label": "",
			"other": "", "other_label": "", "modes": [], "mode_i": -1, "readied": false, "icon_id": "", "icon_mode": ""}
	var ms := KitWords.key_moves(el, i, player)        # (his worn talent's mode on an empty double tap too: the Sulphur Vent)
	var heads := {0: "W / 1", 2: "A D / 3", 3: "S / 4"}
	var k := String(heads.get(i, str(i + 1))) if s == "direction" else str(i + 1)
	if i == 2 and s != "direction" and RingRules.stock_on():
		k = KitWords.key(&"sprint")          # (the new ring: Shift + a direction is key 3's, Hotbar._shift_dir; the owner, 2026-10-11)
	out.head = "%s%s%s" % [k, SEP, KitWords.role(el, i)] if i < KEYS else ""
	if ms.is_empty():
		return out
	var r := readied()
	var at := -1
	for j in ms.size():
		if not r.is_empty() and String(ms[j].id) == String(r.id) and (String(ms[0].id) != String(ms[ms.size() - 1].id)
				or ms.size() == 1 or String(ms[j].mode) == String(r.mode)):
			at = j
	var shown: Dictionary = ms[maxi(at, 0)]
	out.id = String(shown.id)
	out.mode = String(shown.mode)
	out.label = KitWords.move_name(out.id, out.mode)
	out.icon_id = out.id
	out.icon_mode = out.mode
	if ms.size() > 1 and s != "first_moves":
		var oth: Dictionary = ms[1] if at <= 0 else ms[0]
		out.other = String(oth.id)
		out.other_label = KitWords.move_name(String(oth.id), String(oth.mode))
		out.tap = (KitWords.w("tap_twice", "tap twice: %s") if at <= 0 else KitWords.w("tap_once", "tap: %s")) % out.other_label
		out.sub = out.tap
	var gn := KitWords.grown_name(el, i)
	if gn != "" and at <= 0:
		out.grow = KitWords.w("grow_into", "hold to grow it: %s") % gn
	var held_dir := ""
	if s == "direction":
		var c := SwayCaster.of(player)
		held_dir = c.held_dir() if c != null else ""
	var dir_of := {"forward": 0, "side": 2, "back": 3}
	out.readied = at >= 0 if held_dir == "" else int(dir_of.get(held_dir, -1)) == i
	if gn != "" and at >= 0:
		# (the move held past its grow: its own picture, the Fireball's)
		var c2 := SwayCaster.of(player) if player != null else null
		if c2 != null and c2.grown:
			out.icon_mode = grown_mode(gn)
	if stock_strip():
		_stock_column(out, i, el)
	return out


## The icon mode of a grown move's picture ("Fireball" -> "fireball").
static func grown_mode(grown_name: String) -> String:
	return grown_name.to_lower().replace(" ", "_")


# ---------------------------------------------------------------- round 3: the % ring's strip (stock only)
## The % ring's strip is on (a stock-rules ring: RingRules.stock_on()).
func stock_strip() -> bool:
	return RingRules.stock_on() and player != null and is_instance_valid(player)


## The player in the air now (his own RingMoves; air_override for tests and stills).
func airborne() -> bool:
	if air_override != null:
		return bool(air_override)
	var rm := RingMoves.of(player) if player != null else null
	return rm != null and rm.airborne()


static func sw(key: String, def: Variant = null) -> Variant:
	return (MatchSetup.screens().get("strip_stock", {}) as Dictionary).get(key, def)


## Key i's column in the % ring: key 3 never lit as readied; in the air key 2 the Slam, key 3 "Dodge", ground-dependent
## spells grey with "lands". Share the caster's predicate: Breath stays usable even though it shares the wall key.
func _stock_column(out: Dictionary, i: int, el: String) -> void:
	out["grey"] = false
	if i == 2:
		out.readied = false
	if airborne():
		match i:
			1:
				out.label = String((sw("slam", {}) as Dictionary).get(el, out.label))
				out.sub = ""
				out.tap = ""
				out.grow = ""
				out.icon_id = "slam"
				out.icon_mode = el
			2:
				if basic_strip():
					# (round 4 SIMPLE: under Basic 3 in the air does nothing: grey until he lands, as 4 and 5)
					out.grey = true
					out.sub = String(sw("lands", "lands"))
					out.tap = ""
					out.readied = false
				else:
					out.label = String(sw("dodge", "Dodge"))
					out.sub = ""
					out.tap = ""
				out.icon_id = "dodge"
				out.icon_mode = el
			3, 4:
				if SwayCaster.needs_ground(String(out.id), String(out.mode)):
					out.grey = true
					out.sub = String(sw("lands", "lands"))
					out.tap = ""
					out.readied = false
	out["stale"] = stale_copies(String(out.id), String(out.mode))


## Copies of move id/mode (and its grown form) in the player's own stale queue (RingRules.stale_count).
func stale_copies(id: String, mode: String) -> int:
	var rr := RingRules.current()
	if rr == null or id == "" or player == null:
		return 0
	var tag := "%s/%s" % [id, mode]
	return rr.stale_count(player, tag) + rr.stale_count(player, tag + ".grown")


## The name's shade for `copies` stale copies (screens.json strip_stock.stale_alpha: dimmer at 2, 4, 6).
static func stale_alpha(copies: int) -> float:
	var a := 1.0
	for e: Variant in sw("stale_alpha", []):
		if e is Array and copies >= int(e[0]):
			a = float(e[1])
	return a


## "safe" is shown on the strip now (after a hit of the player's passed through a safe body).
func safe_shown() -> bool:
	return _safe_t > 0.0


func _hook_rules() -> void:
	var rr := RingRules.current()
	if rr == null or rr == _hooked_rules:
		return
	_hooked_rules = rr
	rr.hit_safe.connect(func(_b: Node3D, by: Node, _p: Vector3) -> void:
		if by == player:
			show_safe())


## "safe" on the strip for safe_s.
func show_safe() -> void:
	_safe_t = float(sw("safe_s", 0.5))
	_safe.text = String(sw("safe", "safe"))
	_safe.visible = true
	_safe.modulate.a = 1.0
	_laid_key = ""


## The JAB or the GUARD chip: {head ("LMB · JAB"), id, mode, label, sub (the next Q; "E again: throw it back"), lit, icon_id,
## icon_mode (holding a caught stone: the return's picture)}.
func chip(kind: String) -> Dictionary:
	var el := _element()
	var c := SwayCaster.of(player) if player != null else null
	if kind == "guard":
		var g := KitWords.guard(el)
		var holding := KitWords.holds_stone(player)
		var lit := InputMap.has_action(KitWords.GUARD_ACTION) and Input.is_action_pressed(KitWords.GUARD_ACTION)
		return {"head": "%s%s%s" % [KitWords.key(KitWords.GUARD_ACTION), SEP, KitWords.w("role_guard", KitWords.ROLE_GUARD)],
				"id": String(g.get("id", "")), "mode": String(g.get("mode", "")),
				"label": KitWords.move_name(String(g.get("id", "")), String(g.get("mode", ""))),
				"sub": KitWords.keyed(KitWords.w("throw_back", "{guard} again: throw it back")) if holding else "",
				"holding": holding, "lit": lit or holding,
				"icon_id": String(g.get("id", "")), "icon_mode": "return" if holding else String(g.get("mode", ""))}
	var q := c.quick_spell() if c != null else {}
	if q.is_empty():
		q = KitWords.jab(el)
	var on := c != null and c.lock_src == SwayCaster.SRC_QUICK and c.state != SwayCaster.State.IDLE
	return {"head": "%s%s%s" % [CHIP, SEP, KitWords.w("role_jab", KitWords.ROLE_JAB)], "id": String(q.get("id", "")),
			"mode": String(q.get("mode", "")), "label": KitWords.move_name(String(q.get("id", "")), String(q.get("mode", ""))),
			"sub": q_line(), "lit": on, "icon_id": String(q.get("id", "")), "icon_mode": String(q.get("mode", ""))}


## What the next Q does, as the jab chip says it: "Q: put Spike on left click" (the readied move is not on it), "hold Q: Pebbles
## back" (another move is on it), both when both hold; "" with nothing to say. The Q as bound (KitWords.key).
func q_line() -> String:
	if basic_strip():
		return ""                            # (round 4 SIMPLE: Q is not a Basic key)
	return q_text(SwayCaster.of(player) if player != null else null)


## q_line for caster `c` (the strip's; the duel's world HUD under its quick row).
static func q_text(c: SwayCaster) -> String:
	var el := c.quick_element() if c != null else ""
	if el == "":
		return ""
	var jb := KitWords.jab(el)
	var q := c.quick_spell()
	var r := {"id": c.readied_spell, "mode": c.base_mode_of(c.readied_spell)} if c.readied_spell != "" else {}
	var lines := PackedStringArray()
	if not r.is_empty() and (String(r.id) != String(q.get("id", "")) or String(r.mode) != String(q.get("mode", ""))):
		lines.append(KitWords.keyed(KitWords.w("q_put", "{quick}: put %s on left click")) % KitWords.move_name(String(r.id), String(r.mode)))
	if not q.is_empty() and (String(q.get("id", "")) != String(jb.get("id", "")) or String(q.get("mode", "")) != String(jb.get("mode", ""))):
		lines.append(KitWords.keyed(KitWords.w("q_hold_back", "hold {quick}: %s back"))
				% KitWords.move_name(String(jb.get("id", "")), String(jb.get("mode", ""))))
	return "\n".join(lines)


## The readied move as a line: "1 · Spike" ("" none; kept for its callers: the strip itself shows the lit chip).
func ready_line() -> String:
	for i in KEYS:
		var col := column(i)
		if bool(col.readied) and String(col.id) != "":
			return "%d%s%s" % [i + 1, SEP, String(col.label)]
	return ""


## The move on left click as the jab chip names it ("Pebbles"; "" none).
func quick_line() -> String:
	return String(chip("jab").label)


## The strip's one help line (the scheme's, the keys as bound: KitWords.strip_help, one line of 64 characters or fewer;
## round 4 SIMPLE: under the Basic controls Basic's own).
func help_line() -> String:
	if basic_strip():
		# (round 4's merge: Basic's line held to HUD's rule, one line of help_max_chars or fewer, its first letter a capital)
		var t := KitWords.keyed(MatchSetup.scheme_text("strip", "basic"))
		return t.substr(0, 1).to_upper() + t.substr(1)
	return KitWords.strip_help(scheme())


## Round 4 SIMPLE: the Basic controls' strip (the player's RingAssist active: Basic, the % ring).
func basic_strip() -> bool:
	var a: RingAssist = RingAssist.of(player) if player != null and is_instance_valid(player) else null
	return a != null and a.active()


## The help line of the scheme now (the duel's world HUD under its quick row: round 2's longer line, as ever).
static func help_text() -> String:
	return KitWords.help_line()


## The "LMB" chip: a gold Label in a thin gold frame (the Label's own stylebox: no box container on the HUD, the user:
## "those big cards are terrible"; tests/ui/test_hud_skills.gd): the world HUD's quick spell row (the duel).
static func make_chip() -> Label:
	var chip_l := FrontierHUD.hud_label(14, FrontierHUD.GOLD)
	chip_l.name = "Chip"
	chip_l.text = CHIP
	chip_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.border_color = FrontierHUD.GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	chip_l.add_theme_stylebox_override("normal", sb)
	return chip_l


func _bending() -> Bending:
	return player.get_node_or_null(NodePath(String(Bending.NODE_NAME))) as Bending if player != null else null


func _element() -> String:
	var b := _bending()
	return b.element if b != null else ""


## What changes it within a frame, cheaply (no words made): the guard's button, the lock and its button, the readied move
## and its variation, the left button's, the scheme, the element, the first match, a caught stone held, grown, the layout.
func _quick_sig() -> String:
	var c := SwayCaster.of(player) if player != null else null
	if c == null:
		return ""
	var g := InputMap.has_action(KitWords.GUARD_ACTION) and Input.is_action_pressed(KitWords.GUARD_ACTION)
	return "%s|%s|%d|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [g, c.lock_src, c.state, c.readied_spell, c.base_mode_of(c.readied_spell),
			c.quick_id(), c.quick_mode(), c.scheme(), _element(), first_match(), BendZone.held_stone(player) != null,
			airborne() if stock_strip() else false, c.grown, layout()]


## What it shows, as one string (a change redraws it).
func _signature() -> String:
	var parts := PackedStringArray()
	for i in KEYS:
		var col := column(i)
		parts.append("%s/%s/%s/%s/%s/%s/%s/%s/%s/%s" % [col.id, col.mode, col.readied, col.head, col.sub, col.grow, col.label,
				col.get("stale", 0), col.get("grey", false), col.icon_mode])
	for kind: String in ["jab", "guard"]:
		var ch := chip(kind)
		parts.append("%s/%s/%s/%s/%s" % [ch.label, ch.sub, ch.lit, ch.head, ch.icon_mode])
	parts.append(_element())
	parts.append(help_line())                # (a key rebound or unbound: the help line follows at once)
	return "|".join(parts)


func refresh() -> void:
	var el := _element()
	for i in _cols.size():
		var col := column(i)
		_paint(_cols[i], String(col.head), String(col.id), String(col.label), String(col.sub), String(col.grow), bool(col.readied),
				not bool(col.hidden), String(col.icon_id), String(col.icon_mode), el)
		var ui: Dictionary = _cols[i]
		if col.has("stale"):
			# (the % ring: the name dims by stale copies; ground-dependent spells have a grey chip in the air)
			(ui.name as Label).modulate.a = stale_alpha(int(col.stale))
			ui["grey"] = bool(col.get("grey", false))
			if bool(col.get("grey", false)):
				(ui.box as Control).modulate = Color(0.6, 0.6, 0.6, 0.55)
			else:
				(ui.box as Control).modulate = Color(1, 1, 1, (ui.box as Control).modulate.a)
	for kind: String in ["jab", "guard"]:
		var ch := chip(kind)
		var ui: Dictionary = _chips[kind]
		_paint(ui, String(ch.head), String(ch.id), String(ch.label), String(ch.sub), "", bool(ch.lit), true, String(ch.icon_id),
				String(ch.icon_mode), el)
		(ui.other as Label).visible = false      # (their lines stand over the strip: _paint_hint)
		if bool(ch.get("holding", false)):
			ui["tint"] = FrontierHUD.GOLD
			(ui.icon as Control).queue_redraw()
	_line.text = ready_line()
	_help.text = help_line()
	_paint_hint()
	_laid_key = ""


## The line over the help line: the caught stone's (gold: E again throws it back) while one is held, else what Q does while the
## help shows or Q is held; "" none.
func _paint_hint() -> void:
	var t := ""
	var gold := false
	if KitWords.holds_stone(player):
		t = KitWords.keyed(KitWords.w("throw_back", "{guard} again: throw it back"))
		gold = true
	elif help_on() or (InputMap.has_action(SwayCaster.QUICK_BIND) and Input.is_action_pressed(SwayCaster.QUICK_BIND)):
		t = q_line().replace("\n", "  ·  ")
	if _hint.text != t:
		_hint.text = t
		_laid_key = ""
	_hint.add_theme_color_override("font_color", FrontierHUD.GOLD if gold else FrontierHUD.INK)
	_hint.add_theme_font_size_override("font_size", NAME_PX if gold else HINT_PX)
	_hint.visible = t != "" and layout() != "L3" or gold


func _paint(ui: Dictionary, head: String, id: String, label: String, sub: String, grow: String, on: bool, shown: bool,
		icon_id: String, icon_mode: String, el: String) -> void:
	(ui.key as Label).add_theme_color_override("font_color", FrontierHUD.GOLD if on else FrontierHUD.TEXT)
	(ui.key as Label).text = head
	var cap := ui.cap as Label
	var keypart := head.get_slice(SEP, 0)
	cap.text = keypart + (" " + KitWords.GROW if head.ends_with(KitWords.GROW) else "")
	cap.add_theme_color_override("font_color", FrontierHUD.GOLD if on else FrontierHUD.TEXT)
	var sb := cap.get_theme_stylebox("normal") as StyleBoxFlat
	if sb != null:
		sb.border_color = FrontierHUD.GOLD if on else Color(FrontierHUD.TEXT, 0.55)
	(ui.name as Label).text = label if id != "" else "-"
	(ui.other as Label).text = sub
	(ui.grow as Label).text = grow
	(ui.box as Control).modulate.a = 1.0 if on else snum("dim_a", 0.78)
	(ui.box as Control).visible = shown
	ui["tint"] = element_colour(el) if on else Color(FrontierHUD.TEXT, snum("icon_dim_a", 0.9))
	var tid := "%s__%s" % [icon_id, icon_mode]
	if String(ui.tex_id) != tid:
		ui["tex_id"] = tid
		ui["tex"] = icon_texture(icon_id, icon_mode) if icon_id != "" else null
	(ui.icon as Control).queue_redraw()


# ---------------------------------------------------------------- the pictures
## A chip's picture: assets/ui/icons/spell_<id>__<mode>.svg (a move with no mode: spell_<id>__<id>.svg), else the id's own
## (FrontierHUD.spell_texture: the open world's spell_<id>.svg, or its painting); null none (the placeholder circle).
static func icon_texture(id: String, mode: String) -> Texture2D:
	var key := "%s__%s" % [id, mode]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var t: Texture2D = null
	var path := icon_path(id, mode)
	if path != "":
		t = load(path) as Texture2D
	elif id != "":
		t = FrontierHUD.spell_texture(id, Engine.get_main_loop() as SceneTree)
	_tex_cache[key] = t
	return t


## The ring's own picture of id/mode (the mode's file, else the id's), "" none.
static func icon_path(id: String, mode: String) -> String:
	if id == "":
		return ""
	var p := ICON_DIR + "spell_%s__%s.svg" % [id, mode if mode != "" else id]
	if ResourceLoader.exists(p):
		return p
	p = ICON_DIR + "spell_%s.svg" % id
	return p if ResourceLoader.exists(p) else ""


## An element's colour (a readied chip's picture): its side's home colour (RingSides; the player's side is always home).
static func element_colour(el: String) -> Color:
	return RingSides.home_colour(el) if el in Bending.ELEMENTS else FrontierHUD.GOLD


## Every chip the strip can show for each element under both rule sets: [{element, id, mode, what}] (the jab, the guard, the
## caught stone's return, each key's moves, a grown move, the Slam and "Dodge" in the air).
static func every_chip() -> Array:
	var out: Array = []
	for el: String in Bending.ELEMENTS:
		var j := KitWords.jab(el)
		out.append({"element": el, "id": String(j.get("id", "")), "mode": String(j.get("mode", "")), "what": "jab"})
		var g := KitWords.guard(el)
		out.append({"element": el, "id": String(g.get("id", "")), "mode": String(g.get("mode", "")), "what": "guard"})
		if String(g.get("id", "")) == "stone_catch":
			out.append({"element": el, "id": "stone_catch", "mode": "return", "what": "return"})
		for i in KEYS:
			var ms := KitWords.key_moves(el, i)
			for m: Dictionary in ms:
				out.append({"element": el, "id": String(m.id), "mode": String(m.mode), "what": "key %d" % (i + 1)})
			var gn := KitWords.grown_name(el, i)
			if gn != "" and not ms.is_empty():
				out.append({"element": el, "id": String(ms[0].id), "mode": grown_mode(gn), "what": "key %d grown" % (i + 1)})
		out.append({"element": el, "id": "slam", "mode": el, "what": "air key 2"})
		out.append({"element": el, "id": "dodge", "mode": el, "what": "air key 3"})
	return out


# ---------------------------------------------------------------- drawing
func _draw_icon(ui: Dictionary) -> void:
	var icon := ui.icon as Control
	var r := Rect2(Vector2.ZERO, icon.size)
	if String(ui.tex_id).begins_with("__") or String(ui.tex_id) == "":
		return
	var tex: Texture2D = ui.tex
	if tex == null:
		FrontierHUD.draw_spell_circle(icon, r)
		return
	var ts := tex.get_size()
	var k := minf(r.size.x / ts.x, r.size.y / ts.y)
	var fit := Rect2(r.position + (r.size - ts * k) * 0.5, ts * k)
	# (the ink round the picture, as round the letters: it reads on the bright deck at noon)
	var ink := snum("icon_ink_px", 1.5)
	var ink_c := Color(0.02, 0.015, 0.01, snum("icon_ink_a", 0.5))
	for d: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1.4, 1.4)]:
		icon.draw_texture_rect(tex, Rect2(fit.position + d * ink, fit.size), false, ink_c)
	icon.draw_texture_rect(tex, fit, false, ui.get("tint", Color.WHITE) if tex.resource_path.ends_with(".svg") else Color.WHITE)
