class_name BendStrip
extends VBoxContainer
## The arena's key strip (Tidebreak; FrontierHUD.set_arena; round 2 of the skills, the owner 2026-10-05: "make the skills easy
## hard to master ... think human made think avg IQ"; skills_r2 spec §2.1, §6, §9): the same seven chips for every element,
## each button one job (KitWords):
##   LMB · JAB      the element's jab (Pebbles, Splash, Embers, Palm) or the move Q put on left click; under it what the
##                  next Q does ("Q: put Spike on left click", "hold Q: Pebbles back")
##   E · GUARD      the element's guard (Catch, Turn, Parry, Wind Guard); holding a stone it caught: "E again: throw it back"
##                  in gold (his own strip only)
##   1 · STRIKE  2 · PUSH ▲  3 · DASH  4 · WALL  5 · HEAL
##                  under each the readied move's plain name (a tap: the key's first move), under it "tap twice: Boulder"
##                  (the key's other move; under first_moves none); fire's 1 "hold to grow it: Fireball". In the player's
##                  first match (FirstHints up) each "tap twice" line fades in only once he has cast that key twice
##                  (display only: every move is usable from the start)
## the readied chip lit (its head gold, the rest at 0.62), and ONE help line under the row (the scheme's: KitWords.help_line).
## Each control scheme (MatchSetup.scheme(): keys, first_moves, direction, radial) keeps the seven chips: direction heads the
## columns W / 1, A D / 3, S / 4 (the direction held as RMB is pressed picks key 1's, 3's first move or the wall) and lights
## the held one; the wheel's scheme says so in its help line. What it shows comes from the player's own hotbar, caster and
## Bending node: nothing about anyone else (no target cues of any kind).
##   column(i) (keys 0-4) -> {key, head, sub, grow, hidden, id, mode, label, other, other_label, modes, mode_i, readied, tap};
##   chip("jab" | "guard") -> {head, id, mode, label, sub, lit}; tap_alpha(i); ready_line(); quick_line(); q_line();
##   help_line(); refresh()
## ROUND 3, the % ring (RingRules.stock_on(); smash_r3 spec v2 §10.4; PERCENT's; screens.json strip_stock): while your own
## RingMoves says you are airborne key 2 shows your Slam's name (Hammer, Downpour, Axe Kick, Down Gust), key 3 "Dodge", keys
## 4 and 5 grey with "lands"; key 3 never takes the readied highlight (it acts at once); your move names dim a shade at 2, 4
## and 6 stale copies (RingRules.stale_count: your own queue); "safe" for safe_s after a hit of yours passed through a safe
## body (RingRules.hit_safe by you). column(i) adds {grey, stale}; safe_shown().

const KEYS := 5
const COL_W := 114.0
const CHIP_W := 140.0
const ICON_PX := 40.0
const DIM_A := 0.78
## The middle dot between a head's parts.
const SEP := " · "
## The jab chip's key (the left button).
const CHIP := "LMB"
## A revealed "tap twice" line's fade in (s).
const TAP_FADE_S := 0.6
## Casts of a key before its "tap twice" line shows in the first match.
const TAP_AFTER := 2

var player: FrontierPlayer
## Tests and stills: true / false stand for the first match (FirstHints up) or not; null reads it.
var first_match_override: Variant = null

var _cols: Array = []          ## per key: {box, key, icon, name, other, grow, tex, tex_id}
var _chips := {}               ## "jab" / "guard" -> {box, key, icon, name, other, tex, tex_id}
var _line: Label               ## (kept for the readied line's callers; not shown: one help line)
var _quick_box: Control
var _chip: Label
var _quick: Label
var _help: Label
var _sig := ""
var _dirty := true
## The full look (_signature: every column and chip in words, the keys as bound) is taken every SIG_EVERY_S; between, only
## what changes in a frame (the guard's button, the lock, the readied move: _quick_sig) marks it dirty.
const SIG_EVERY_S := 0.15
var _sig_t := 0.0
var _qsig := ""
## Casts per key this match (the first match's "tap twice" lines), and each line's fade (0..1).
var _casts := [0, 0, 0, 0, 0]
var _tap_a := [0.0, 0.0, 0.0, 0.0, 0.0]
var _hooked: SwayCaster
## Round 3 (stock): tests and stills: true / false stand for airborne (null: the player's RingMoves says); "safe" shown for
## this long still; the rules hooked for hit_safe.
var air_override: Variant = null
var _safe_t := 0.0
var _safe: Label
var _hooked_rules: RingRules


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.name = "Keys"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	for kind: String in ["jab", "guard"]:
		var ui := _make_box(row, "Chip_" + kind, CHIP_W)
		_chips[kind] = ui
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	for i in KEYS:
		_cols.append(_make_box(row, "Key%d" % (i + 1), COL_W))
	# (the old quick row's pieces kept for their callers: the jab chip's head and name are them now)
	_chip = (_chips.jab as Dictionary).key
	_quick = (_chips.jab as Dictionary).name
	_quick_box = (_chips.jab as Dictionary).box
	_line = FrontierHUD.hud_label(17, FrontierHUD.INK)
	_line.name = "ReadyLine"
	_line.visible = false
	add_child(_line)
	_help = FrontierHUD.hud_label(13, FrontierHUD.DIM)
	_help.name = "HelpLine"
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inked(_help)
	add_child(_help)
	_safe = FrontierHUD.hud_label(18, Color(0.62, 0.86, 0.96))
	_safe.name = "Safe"
	_safe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inked(_safe)
	_safe.visible = false
	add_child(_safe)
	move_child(_safe, 0)
	_hook.call_deferred()


## A chip's box: its head (the key and the role), the move's picture, its name, the dim line under it, the grow line.
func _make_box(row: HBoxContainer, nm: String, w: float) -> Dictionary:
	var box := VBoxContainer.new()
	box.name = nm
	box.custom_minimum_size = Vector2(w, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	var k := FrontierHUD.hud_label(15, FrontierHUD.TEXT)
	k.name = "Head"
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(k)
	var icon := Control.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var n := FrontierHUD.hud_label(16, FrontierHUD.INK)
	n.name = "Name"
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.custom_minimum_size = Vector2(w, 0)
	box.add_child(n)
	var ot := FrontierHUD.hud_label(13, FrontierHUD.DIM)
	ot.name = "Sub"
	ot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ot.custom_minimum_size = Vector2(w, 0)
	box.add_child(ot)
	var gr := FrontierHUD.hud_label(12, FrontierHUD.GOLD.lerp(FrontierHUD.DIM, 0.4))
	gr.name = "Grow"
	gr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gr.custom_minimum_size = Vector2(w, 0)
	gr.visible = false
	box.add_child(gr)
	for l: Label in [k, n, ot, gr]:
		_inked(l)
	row.add_child(box)
	var ui := {"box": box, "key": k, "icon": icon, "name": n, "other": ot, "grow": gr, "tex": null, "tex_id": ""}
	icon.draw.connect(_draw_icon.bind(ui))
	return ui


## A dark outline round a label's letters: the strip reads over a bright deck with no card behind it (the owner: "those big
## cards are terrible").
static func _inked(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.01, 0.85))
	l.add_theme_constant_override("outline_size", 5)


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


## A cast of the player's: its key's count (the first match's "tap twice" lines; the jab and the guard are no key's).
func _on_cast(m: String, _t: Node3D) -> void:
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
	if i >= 0 and i < KEYS:
		_casts[i] = int(_casts[i]) + 1
		_dirty = true


## The casts counted for key `i` this match.
func casts_of(i: int) -> int:
	return int(_casts[i]) if i >= 0 and i < KEYS else 0


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
	for i in KEYS:
		var want := 1.0 if (not fm or int(_casts[i]) >= TAP_AFTER) else 0.0
		var a := move_toward(float(_tap_a[i]), want, dt / TAP_FADE_S) if fm else want
		if a != float(_tap_a[i]):
			_tap_a[i] = a
			var ui: Dictionary = _cols[i]
			(ui.other as Label).modulate.a = a
	var q := _quick_sig()
	if q != _qsig:
		_qsig = q
		_dirty = true
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


## How much of key `i`'s "tap twice" line shows (0 hidden .. 1; always 1 after the first match).
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
## other, other_label (the key's other move), hidden, readied (lit), modes, mode_i (none: no forms in round 2)}.
func column(i: int) -> Dictionary:
	var el := _element()
	var s := scheme()
	var out := {"key": i + 1, "head": "", "sub": "", "tap": "", "grow": "", "hidden": i >= KEYS, "id": "", "mode": "", "label": "",
			"other": "", "other_label": "", "modes": [], "mode_i": -1, "readied": false}
	var ms := KitWords.key_moves(el, i)
	var heads := {0: "W / 1", 2: "A D / 3", 3: "S / 4"}
	var k := String(heads.get(i, str(i + 1))) if s == "direction" else str(i + 1)
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
	if ms.size() > 1 and s != "first_moves":
		var oth: Dictionary = ms[1] if at <= 0 else ms[0]
		out.other = String(oth.id)
		out.other_label = KitWords.move_name(String(oth.id), String(oth.mode))
		out.tap = (KitWords.w("tap_twice", "tap twice: %s") if at <= 0 else KitWords.w("tap_once", "tap: %s")) % out.other_label
		out.sub = out.tap
	var gn := KitWords.grown_name(el, i)
	if gn != "" and at <= 0:
		out.grow = KitWords.w("grow_into", "hold to grow it: %s") % gn
	var held := ""
	if s == "direction":
		var c := SwayCaster.of(player)
		held = c.held_dir() if c != null else ""
	var dir_of := {"forward": 0, "side": 2, "back": 3}
	out.readied = at >= 0 if held == "" else int(dir_of.get(held, -1)) == i
	if stock_strip():
		_stock_column(out, i, el)
	return out


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


## Key i's column in the % ring: key 3 never lit as readied; in the air key 2 the Slam, key 3 "Dodge", 4 and 5 grey with
## "lands"; its stale copies (your own queue).
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
			2:
				out.label = String(sw("dodge", "Dodge"))
				out.sub = ""
				out.tap = ""
			3, 4:
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


## The JAB or the GUARD chip: {head ("LMB · JAB"), id, mode, label, sub (the next Q; "E again: throw it back"), lit}.
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
				"holding": holding, "lit": lit or holding}
	var q := c.quick_spell() if c != null else {}
	if q.is_empty():
		q = KitWords.jab(el)
	var on := c != null and c.lock_src == SwayCaster.SRC_QUICK and c.state != SwayCaster.State.IDLE
	return {"head": "%s%s%s" % [CHIP, SEP, KitWords.w("role_jab", KitWords.ROLE_JAB)], "id": String(q.get("id", "")),
			"mode": String(q.get("mode", "")), "label": KitWords.move_name(String(q.get("id", "")), String(q.get("mode", ""))),
			"sub": q_line(), "lit": on}


## What the next Q does, as the jab chip says it: "Q: put Spike on left click" (the readied move is not on it), "hold Q: Pebbles
## back" (another move is on it), both when both hold; "" with nothing to say. The Q as bound (KitWords.key).
func q_line() -> String:
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


## The strip's one help line (the scheme's, the keys as bound).
func help_line() -> String:
	return KitWords.help_line(scheme())


## The help line of the scheme now (the strip's; the duel's world HUD under its quick row).
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
## and its variation, the left button's, the scheme, the element, the first match, a caught stone held.
func _quick_sig() -> String:
	var c := SwayCaster.of(player) if player != null else null
	if c == null:
		return ""
	var g := InputMap.has_action(KitWords.GUARD_ACTION) and Input.is_action_pressed(KitWords.GUARD_ACTION)
	return "%s|%s|%d|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [g, c.lock_src, c.state, c.readied_spell, c.base_mode_of(c.readied_spell),
			c.quick_id(), c.quick_mode(), c.scheme(), _element(), first_match(), BendZone.held_stone(player) != null,
			airborne() if stock_strip() else false]


## What it shows, as one string (a change redraws it).
func _signature() -> String:
	var parts := PackedStringArray()
	for i in KEYS:
		var col := column(i)
		parts.append("%s/%s/%s/%s/%s/%s/%s/%s/%s" % [col.id, col.mode, col.readied, col.head, col.sub, col.grow, col.label,
				col.get("stale", 0), col.get("grey", false)])
	for kind: String in ["jab", "guard"]:
		var ch := chip(kind)
		parts.append("%s/%s/%s/%s" % [ch.label, ch.sub, ch.lit, ch.head])
	parts.append(_element())
	parts.append(help_line())                # (a key rebound or unbound: the help line follows at once)
	return "|".join(parts)


func refresh() -> void:
	for i in _cols.size():
		var col := column(i)
		_paint(_cols[i], String(col.head), String(col.id), String(col.label), String(col.sub), String(col.grow), bool(col.readied),
				not bool(col.hidden))
		if col.has("stale"):
			# (the % ring: the name a shade dimmer by its stale copies; a grey chip in the air for keys 4 and 5)
			var ui: Dictionary = _cols[i]
			(ui.name as Label).modulate.a = stale_alpha(int(col.stale))
			if bool(col.get("grey", false)):
				(ui.box as Control).modulate = Color(0.6, 0.6, 0.6, 0.55)
			else:
				(ui.box as Control).modulate = Color(1, 1, 1, (ui.box as Control).modulate.a)
	for kind: String in ["jab", "guard"]:
		var ch := chip(kind)
		var ui: Dictionary = _chips[kind]
		_paint(ui, String(ch.head), String(ch.id), String(ch.label), String(ch.sub), "", bool(ch.lit), true)
		(ui.other as Label).add_theme_color_override("font_color", FrontierHUD.GOLD if bool(ch.get("holding", false)) else FrontierHUD.DIM)
	_line.text = ready_line()
	_help.text = help_line()
	_help.visible = _help.text != ""


func _paint(ui: Dictionary, head: String, id: String, label: String, sub: String, grow: String, on: bool, shown: bool) -> void:
	(ui.key as Label).add_theme_color_override("font_color", FrontierHUD.GOLD if on else FrontierHUD.TEXT)
	(ui.key as Label).text = head
	(ui.name as Label).text = label if id != "" else "-"
	(ui.other as Label).text = sub
	(ui.grow as Label).text = grow
	(ui.grow as Label).visible = grow != ""
	(ui.box as Control).modulate.a = 1.0 if on else DIM_A
	(ui.box as Control).visible = shown
	if String(ui.tex_id) != id:
		ui["tex_id"] = id
		ui["tex"] = FrontierHUD.spell_texture(id, get_tree()) if id != "" else null
	(ui.icon as Control).queue_redraw()


# ---------------------------------------------------------------- drawing
func _draw_icon(ui: Dictionary) -> void:
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
