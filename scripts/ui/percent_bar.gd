class_name PercentBar
extends Control
## The % ring's scoreboard (Tidebreak round 3, smash_r3 spec v2 §10; PERCENT's; FrontierHUD.set_arena puts it in place of
## the MatchBar while a stock-rules ring is on). Every number in data/ring/hud.json. A SCOREBOARD ON FIXED PLATES, never a
## cue on a body (the owner's rule: no target cues of any kind): the plates change only on hits, falls, heals, your own air
## moves and the clock; they read RingRules (pct_of, stocks_of, safe_until, fresh_pct and its signals pct_changed, ko,
## respawned), RingMode (round_left_s, sudden_left_s, phase, its sides) and the player's own RingMoves (the pips), and never
## any body's place in the world. Nothing is attached to, follows or points at a body; there are no numbers on bodies.
##   layout A    (the default) your plate top-left, theirs top-right mirrored; B (hud.json layout) the bottom corners. 3v3:
##               three smaller plates a side, stacked
##   a plate     a dark plate (plate.alpha) with a side-colour rule (round 4: RingSides.colour, the element's home or away
##               colour), the element's mark (round 4: the move icons' own set), the name, the %
##               in big bold digits with a smaller "%", the lives as small glyphs; YOUR plate only: the fresh-damage band
##               (the % Patch may take back) and three pips (jump, dodge, Rise: dim when spent, a soft tick as one refills)
##   the %       its colour ramps ink -> gold -> orange -> red -> deep red (an OKLab blend; an outline from outline_from),
##               throbbing over throb_from; on a hit the digits roll up, pop and shake (the plate's own, never the camera);
##               on a heal they roll down with a pale-green flash
##   a fall      a white flash, the digits rising and fading, a life glyph cracking and dropping (the row closing up), "0%"
##               fading in; the last life's glyph pulses; after a respawn a small glyph and a bar while he is safe
##   the clock   top centre (the game's time left; in sudden death its own count), the event line under it for event_s;
##               not while the match's centre line says the same fall (RingMode.ko_line: one line for a fall, not two; the UI
##               audit, 2026-10-09), so it tells a fall only where the centre says nothing (the last life, a practice)
## lines() / plate_info(team, k) / plate_rect(team, k): what it shows, for the tests.

const GROUP := &"ring_match"
const DATA_PATH := "res://data/ring/hud.json"

static var _cfg := {}
## The bottom of the plates down the screen's right while they stand at the top (global y; -1 none): the hint card (LessonCard)
## stands under them, so a team format's stacked plates are never under a hint (the owner, 2026-10-10: team modes "Triple AAA").
static var right_bottom := -1.0

var player: FrontierPlayer
## The layout shown ("A" | "B"; "" hud.json's).
var layout_override := ""

var _m: Node = null
var _rules: RingRules = null
## Per competitor (instance id): {shown, target, roll_from, roll_t, pop_t, pop_k, shake_t, shake_a, heal_t, fall_t, lives,
## lives_shown, crack_t}.
var _pl := {}
var _event := ""
var _event_t := 0.0
var _pips_had := [true, true, true]
var _t := 0.0
var _font: Font
var _bold: Font


## hud.json (read once).
static func hud_cfg() -> Dictionary:
	if _cfg.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_cfg = d if d is Dictionary else {}
	return _cfg


static func cnum(key: String, def: float) -> float:
	return float(hud_cfg().get(key, def))


static func _blk(key: String) -> Dictionary:
	var b: Variant = hud_cfg().get(key, {})
	return b if b is Dictionary else {}


static func _col(a: Variant, def := Color.WHITE) -> Color:
	if a is Array and (a as Array).size() >= 3:
		var c := Color(float(a[0]), float(a[1]), float(a[2]))
		if (a as Array).size() >= 4:
			c.a = float(a[3])
		return c
	return def


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = FrontierHUD.serif()
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 0.9
	_bold = fv
	visible = false


## The layout now ("A" or "B").
func layout() -> String:
	if layout_override in ["A", "B"]:
		return layout_override
	var l := String(hud_cfg().get("layout", "A"))
	return l if l in ["A", "B"] else "A"


## The match node (the first in group &"ring_match"; null none).
func match_node() -> Node:
	if not is_inside_tree():
		return null
	var ns := get_tree().get_nodes_in_group(GROUP)
	return ns[0] if not ns.is_empty() else null


func _exit_tree() -> void:
	right_bottom = -1.0


func _process(dt: float) -> void:
	_t += dt
	var m := match_node()
	var on := m != null and player != null and is_instance_valid(player) and RingRules.pct_on()
	right_bottom = -1.0
	if not on:
		if visible:
			visible = false
		return
	if not visible and get_parent() != null and (get_parent() as CanvasItem).is_visible_in_tree():
		visible = true
	if m != _m or (RingRules.current() != _rules):
		_hook(m)
	_event_t = maxf(_event_t - dt, 0.0)
	if _event_t > 0.0 and m.has_method(&"ko_line") and String(m.call(&"ko_line")) != "":
		_event_t = 0.0                            # (the centre's fall line says it: one line, not two)
	for id in _pl:
		var s := _pl[id] as Dictionary
		for k: String in ["roll_t", "pop_t", "shake_t", "heal_t"]:
			s[k] = maxf(float(s.get(k, 0.0)) - dt, 0.0)
		if float(s.get("fall_t", -1.0)) >= 0.0:
			s["fall_t"] = float(s.fall_t) + dt
			if float(s.fall_t) > _fall_cfg("zero_s", 1.0) + 0.4:
				s["fall_t"] = -1.0
	_tick_pips()
	var theirs := team(1 - my_side()).size()
	if is_visible_in_tree() and theirs > 0 and String(((_blk("layouts")).get(layout(), {}) as Dictionary).get("corner", "top")) == "top":
		right_bottom = get_global_rect().position.y + plate_rect(1, theirs - 1).end.y
	queue_redraw()


func _hook(m: Node) -> void:
	_m = m
	_rules = RingRules.current()
	_pl.clear()
	if _rules == null:
		return
	if not _rules.pct_changed.is_connected(_on_pct):
		_rules.pct_changed.connect(_on_pct)
		_rules.ko.connect(_on_ko)


func _st(b: Node) -> Dictionary:
	var id := b.get_instance_id()
	if not _pl.has(id):
		var p := _rules.pct_of(b) if _rules != null else 0.0
		_pl[id] = {"shown": p, "target": p, "roll_from": p, "roll_t": 0.0, "pop_t": 0.0, "pop_k": 0.0, "shake_t": 0.0,
				"shake_a": 0.0, "heal_t": 0.0, "fall_t": -1.0, "crack_t": -1.0}
	return _pl[id]


# ---------------------------------------------------------------- what moves it
func _on_pct(b: Node3D, pct: float, delta: float) -> void:
	if b == null or not is_instance_valid(b):
		return
	var s := _st(b)
	if float(s.get("fall_t", -1.0)) >= 0.0 and pct <= 0.0:
		s["target"] = 0.0
		return                                # (the fall's own sequence shows the 0)
	s["roll_from"] = _shown(s)
	s["target"] = pct
	s["roll_t"] = cnum("roll_s", 0.15)
	if delta > 0.0:
		s["pop_t"] = cnum("pop_s", 0.2)
		s["pop_k"] = minf(cnum("pop_k", 0.05) * delta, cnum("pop_max", 0.45))
		s["shake_t"] = cnum("shake_s", 0.3)
		s["shake_a"] = clampf(cnum("shake_a", 1.5) + cnum("shake_k", 0.35) * delta, cnum("shake_min", 2.0), cnum("shake_max", 12.0))
	elif delta < 0.0:
		s["heal_t"] = cnum("heal_flash_s", 0.5)


func _on_ko(b: Node3D, _by: Node, pct: float, _tag: String, left: int) -> void:
	if b == null or not is_instance_valid(b):
		return
	var s := _st(b)
	s["fall_t"] = 0.0
	s["fall_pct"] = pct
	s["target"] = 0.0
	s["roll_t"] = 0.0
	s["shown"] = pct
	var wd := _blk("words")
	if b == player:
		_event = (String(wd.get("event_you", "You are in the water  ·  %d left")) % left) if left > 0 \
				else String(wd.get("event_you_last", "You are in the water"))
	else:
		var who := _name_of(b)
		_event = (String(wd.get("event", "%s is in the water  ·  %d left")) % [who, left]) if left > 0 \
				else (String(wd.get("event_last", "%s is in the water")) % who)
	_event_t = cnum("event_s", 1.5)


## The % a plate shows now (rolling toward its target).
func _shown(s: Dictionary) -> float:
	var rs := cnum("roll_s", 0.15)
	if float(s.get("roll_t", 0.0)) <= 0.0 or rs <= 0.0:
		return float(s.target)
	return lerpf(float(s.target), float(s.roll_from), float(s.roll_t) / rs)


func _fall_cfg(key: String, def: float) -> float:
	return float(_blk("fall").get(key, def))


# ---------------------------------------------------------------- the player's own pips
## [jump, dodge, Rise] for the player now (his own RingMoves; all lit without one). The Rise's is the one a press would give:
## off the deck the way back's, over it the in-ring Rise's (dim while its cooldown runs, the soft tick as it is back).
func pips() -> Array:
	var rm := RingMoves.of(player) if player != null else null
	if rm == null:
		return [true, true, true]
	return [rm.jumps_left > 0, rm.dodge_ready, rm.rise_ready and (rm.off_deck() or rm.ring_rise_ready())]


func _tick_pips() -> void:
	var now := pips()
	for i in 3:
		if bool(now[i]) and not bool(_pips_had[i]):
			var tk: Variant = (_blk("pips")).get("tick", [])
			if tk is Array and (tk as Array).size() >= 3 and BendSounds.has(StringName(String(tk[0]))):
				BendSounds.play(StringName(String(tk[0])), Vector3.INF, float(tk[1]), float(tk[2]))
	_pips_had = now


# ---------------------------------------------------------------- the words and numbers
## The colour of the % digits at `pct` (hud.json ramp, blended in OKLab).
static func ramp(pct: float) -> Color:
	var stops: Array = hud_cfg().get("ramp", [[0, [1, 1, 1]]])
	if stops.is_empty():
		return Color.WHITE
	if pct <= float(stops[0][0]):
		return _col(stops[0][1])
	for i in range(1, stops.size()):
		var a: Array = stops[i - 1]
		var b: Array = stops[i]
		if pct <= float(b[0]):
			var f := (pct - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			return oklab_mix(_col(a[1]), _col(b[1]), f)
	return _col(stops.back()[1])


## Colours `a` to `b` by `f` through OKLab (a perceptual blend).
static func oklab_mix(a: Color, b: Color, f: float) -> Color:
	var la := _to_oklab(a)
	var lb := _to_oklab(b)
	return _from_oklab(la.lerp(lb, clampf(f, 0.0, 1.0)))


static func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


static func _srgb(c: float) -> float:
	c = clampf(c, 0.0, 1.0)
	return c * 12.92 if c <= 0.0031308 else 1.055 * pow(c, 1.0 / 2.4) - 0.055


static func _to_oklab(c: Color) -> Vector3:
	var r := _lin(c.r)
	var g := _lin(c.g)
	var b := _lin(c.b)
	var l := pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m := pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s := pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
			0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


static func _from_oklab(v: Vector3) -> Color:
	var l := v.x + 0.3963377774 * v.y + 0.2158037573 * v.z
	var m := v.x - 0.1055613458 * v.y - 0.0638541728 * v.z
	var s := v.x - 0.0894841775 * v.y - 1.2914855480 * v.z
	l = l * l * l
	m = m * m * m
	s = s * s * s
	return Color(_srgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s), _srgb(-1.2684380046 * l + 2.6097574011 * m
			- 0.3413193965 * s), _srgb(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s))


## The competitors of team `t` (the match's books: RingRules.sides; the player first on his side).
func team(t: int) -> Array:
	var out: Array = []
	if _rules == null:
		return out
	for b in _rules.sides[t]:
		if is_instance_valid(b):
			out.append(b)
	if t == 0 and out.has(player):
		out.erase(player)
		out.push_front(player)
	return out


## The player's side (0 or 1).
func my_side() -> int:
	return clampi(_rules.team_of(player), 0, 1) if _rules != null and player != null else 0


func _name_of(b: Node) -> String:
	if b == player:
		return "You"
	if RingMode.name_of(b) != "":
		return RingMode.name_of(b)             # (a team format's own name: two of one element told apart)
	return MatchSetup.competitor(_element_of(b))


func _element_of(b: Node) -> String:
	var el := BendPoses.element_of(b)
	if el == "" and b is NpcFighter:
		el = String((b as NpcFighter).get(&"element"))
	return el if el in Bending.ELEMENTS else "earth"


## What plate k of team `t` shows: {name, element, pct (the digits' number), pct_text, color, lives, last, pips ([] not
## yours), fresh (-1 not yours), safe (the safe bar's share 0..1; -1 not safe), mine}.
func plate_info(t: int, k: int) -> Dictionary:
	var bs := team(t)
	if k < 0 or k >= bs.size():
		return {}
	var b: Node3D = bs[k]
	var s := _st(b)
	var mine := b == player
	var p := _shown(s)
	if float(s.get("fall_t", -1.0)) >= 0.0:
		p = float(s.get("fall_pct", 0.0)) if float(s.fall_t) < _fall_cfg("fade_s", 0.35) else 0.0
	var lives := _rules.stocks_of(b) if _rules != null else 0
	var safe := -1.0
	if _rules != null:
		var su := _rules.safe_until(b)
		if su > BendStatus.now():
			safe = 1.0 if is_inf(su) else clampf((su - BendStatus.now()) / RingRules.sub_num("respawn", "safe_after_s", 1.5), 0.0, 1.0)
	var fresh := -1.0
	if mine and _rules != null:
		fresh = _rules.fresh_pct(b)
	return {"name": _name_of(b), "element": _element_of(b), "side": side_colour(t, _element_of(b)), "pct": p,
			"pct_text": "%d" % roundi(p), "color": ramp(p),
			"lives": lives, "last": lives == 1, "pips": pips() if mine else [], "fresh": fresh, "safe": safe, "mine": mine,
			"throb": p > cnum("throb_from", 200.0), "outline": p >= cnum("outline_from", 180.0)}


## The clock's line: "7:59", or sudden death's count.
func clock_text() -> String:
	var m := _m
	if m == null:
		return ""
	if m.has_method(&"sudden_left_s") and float(m.call(&"sudden_left_s")) > 0.0:
		return String((_blk("words")).get("sudden", "Sudden  %d")) % ceili(float(m.call(&"sudden_left_s")))
	if bool(m.get(&"practice")):
		return String((_blk("words")).get("practice", "Practice"))
	var left := float(m.call(&"round_left_s")) if m.has_method(&"round_left_s") else 0.0
	var s := maxi(ceili(left), 0)
	return "%d:%02d" % [s / 60, s % 60]


## {clock, event, plates: [[team 0's plate_info...], [team 1's...]]}.
func lines() -> Dictionary:
	var out := {"clock": clock_text(), "event": _event if _event_t > 0.0 else "", "plates": [[], []]}
	for t in 2:
		for k in team(t).size():
			(out.plates[t] as Array).append(plate_info(t, k))
	return out


# ---------------------------------------------------------------- the layout
func _scale() -> float:
	var h := get_viewport_rect().size.y if is_inside_tree() else 720.0
	return maxf(h / cnum("ref_h", 720.0), 0.5)


func _team_layout() -> bool:
	return team(0).size() > 1 or team(1).size() > 1


## The rect of plate k on screen side `screen` (0 left: yours, 1 right: theirs), in this Control's own space.
func plate_rect(screen: int, k: int) -> Rect2:
	var sc := _scale()
	var pc := _blk("team_plate") if _team_layout() else _blk("plate")
	var w := float(pc.get("w", 270.0)) * sc
	var h := float(pc.get("h", 84.0)) * sc
	var gap := float(_blk("team_plate").get("gap", 6.0)) * sc
	var lay := (_blk("layouts")).get(layout(), {}) as Dictionary
	var at: Array = lay.get("at", [24, 16])
	var ax := float(at[0]) * sc
	var ay := float(at[1]) * sc
	var vw := get_viewport_rect().size.x if is_inside_tree() else 1280.0
	var vh := get_viewport_rect().size.y if is_inside_tree() else 720.0
	var x := ax if screen == 0 else vw - ax - w
	var y := ay + float(k) * (h + gap)
	if String(lay.get("corner", "top")) == "bottom":
		y = vh - ay - h - float(k) * (h + gap)
	return Rect2(x, y, w, h)


## The bottom of the top plates on a screen `vh` px high (layout A: the plates at the top; -1 when they stand at the bottom):
## FirstHints' panel stands under it (round 4: nothing over the plates). A 1v1's plate (3v3's stacked plates go lower).
static func top_plates_bottom(vh: float) -> float:
	var lay := String(hud_cfg().get("layout", "A"))
	var l := (_blk("layouts")).get(lay, {}) as Dictionary
	if String(l.get("corner", "top")) != "top":
		return -1.0
	var sc := maxf(vh / cnum("ref_h", 720.0), 0.5)
	var at: Array = l.get("at", [24, 16])
	return (float(at[1]) + float(_blk("plate").get("h", 84.0))) * sc


## The clock's box and the event line's (shown or not) on the screen now, and each plate's (the tests' overlap check).
func text_rects() -> Dictionary:
	var sc := _scale()
	var vw := get_viewport_rect().size.x if is_inside_tree() else 1280.0
	var cy := float(((_blk("layouts")).get(layout(), {}) as Dictionary).get("clock_y", 14)) * sc
	var fs := int(26 * sc)
	var ct := clock_text() if _m != null else "0:00"
	var tw := _font.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var es := int(17 * sc)
	var ev := _event if _event != "" else "-"
	var ew := _font.get_string_size(ev, HORIZONTAL_ALIGNMENT_LEFT, -1, es).x
	var ey := cy + fs + 34 * sc
	var out := {"clock": Rect2(vw * 0.5 - tw * 0.5 - 12 * sc, cy, tw + 24 * sc, fs + 12 * sc),
			"event": Rect2(vw * 0.5 - ew * 0.5, ey - es, ew, es * 1.3), "plates": []}
	for screen in 2:
		var t := my_side() if screen == 0 else 1 - my_side()
		for k in team(t).size():
			(out.plates as Array).append(plate_rect(screen, k))
	return out


# ---------------------------------------------------------------- the drawing
func _draw() -> void:
	if _rules == null or _m == null:
		return
	var sc := _scale()
	var mine := my_side()
	for screen in 2:
		var t := mine if screen == 0 else 1 - mine
		var bs := team(t)
		for k in bs.size():
			_draw_plate(screen, k, plate_info(t, k), t, sc)
	# the clock top centre, the event line under it
	var vw := get_viewport_rect().size.x
	var cy := float(((_blk("layouts")).get(layout(), {}) as Dictionary).get("clock_y", 14)) * sc
	var ct := clock_text()
	var fs := int(26 * sc)
	var tw := _font.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_rect(Rect2(vw * 0.5 - tw * 0.5 - 12 * sc, cy, tw + 24 * sc, fs + 12 * sc), Color(0.02, 0.015, 0.01, 0.45))
	draw_string_outline(_font, Vector2(vw * 0.5 - tw * 0.5, cy + fs + 2 * sc), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(4 * sc), Color(0, 0, 0, 0.7))
	draw_string(_font, Vector2(vw * 0.5 - tw * 0.5, cy + fs + 2 * sc), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, FrontierHUD.GOLD)
	if _event_t > 0.0:
		var es := int(17 * sc)
		var ew := _font.get_string_size(_event, HORIZONTAL_ALIGNMENT_LEFT, -1, es).x
		var a := clampf(_event_t / 0.4, 0.0, 1.0)
		var ey := cy + fs + 34 * sc
		draw_string_outline(_font, Vector2(vw * 0.5 - ew * 0.5, ey), _event, HORIZONTAL_ALIGNMENT_LEFT, -1, es, int(4 * sc), Color(0, 0, 0, 0.7 * a))
		draw_string(_font, Vector2(vw * 0.5 - ew * 0.5, ey), _event, HORIZONTAL_ALIGNMENT_LEFT, -1, es, Color(FrontierHUD.INK, a))


func _draw_plate(screen: int, k: int, info: Dictionary, t: int, sc: float) -> void:
	if info.is_empty():
		return
	var small := _team_layout()
	var pc := _blk("team_plate") if small else _blk("plate")
	var r := plate_rect(screen, k)
	var flip := screen == 1
	var s := _st(team(t)[k])
	# the plate and its side's rule
	draw_rect(r, Color(0.02, 0.015, 0.01, float(_blk("plate").get("alpha", 0.45))))
	var side_col: Color = info.get("side", side_colour(t, String(info.element)))
	var rw := float(_blk("plate").get("rule_px", 2.0)) * sc
	draw_rect(Rect2(r.end.x - rw if flip else r.position.x, r.position.y, rw, r.size.y), side_col)
	var pad := 8.0 * sc
	var gp := float(pc.get("glyph_px", 40.0)) * sc
	var gx := r.end.x - pad - gp if flip else r.position.x + pad + rw
	var glyph_r := Rect2(gx, r.position.y + (r.size.y - gp) * 0.5 - 6.0 * sc, gp, gp)
	_draw_glyph(String(info.element), glyph_r, side_col)
	# the name
	var ns := int(float(pc.get("name_px", 16.0)) * sc)
	var name_s := String(info.name)
	var nw := _font.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
	var tx0 := glyph_r.end.x + pad if not flip else glyph_r.position.x - pad
	var ny := r.position.y + ns + 4.0 * sc
	draw_string_outline(_font, Vector2(tx0 - (nw if flip else 0.0), ny), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, int(ink_px() * sc),
			Color(0.02, 0.015, 0.01, 0.88))
	draw_string(_font, Vector2(tx0 - (nw if flip else 0.0), ny), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, FrontierHUD.TEXT)
	# the lives (small glyphs after the name; the last one pulses; a cracked one drops during a fall)
	var lp := float(pc.get("life_px", 14.0)) * sc
	var lives := int(info.lives)
	var fall_t := float(s.get("fall_t", -1.0))
	var crack := fall_t >= 0.0 and fall_t < _fall_cfg("crack_s", 0.5) + 0.3
	var shown_lives := lives + (1 if crack else 0)
	var lx := tx0 + (nw + 8.0 * sc) * (-1.0 if flip else 1.0)
	for i in shown_lives:
		var cx := lx + (float(i) * (lp + 4.0 * sc) + lp * 0.5) * (-1.0 if flip else 1.0)
		var cy := ny - lp * 0.45
		var col := side_col
		var rad := lp * 0.42
		if crack and i == shown_lives - 1:
			var f := clampf(fall_t / _fall_cfg("crack_s", 0.5), 0.0, 1.0)
			cy += f * float(_blk("fall").get("drop_px", 18.0)) * sc
			col.a = 1.0 - f
			draw_line(Vector2(cx - rad, cy - rad), Vector2(cx + rad * 0.3, cy + rad * 0.2), Color(0, 0, 0, col.a), 1.5)
		elif bool(info.last) and lives == 1:
			var pulse := 0.5 + 0.5 * sin(_t * TAU * cnum("last_life_hz", 1.4))
			rad *= 1.0 + 0.25 * pulse
			col = col.lerp(Color.WHITE, 0.4 * pulse)
		draw_circle(Vector2(cx, cy), rad, col)
	# the % digits: rolled, popped, shaken, ramped, throbbing; a heal's green flash; the fall's flash, rise and fade
	var big := int(float(pc.get("pct_px", 46.0)) * sc)
	var sign_px := int(float(pc.get("pct_sign_px", 24.0)) * sc)
	var txt := String(info.pct_text)
	var col_d: Color = info.color
	if bool(info.throb):
		col_d = col_d * lerpf(cnum("throb_lo", 0.8), 1.0, 0.5 + 0.5 * sin(_t * TAU * cnum("throb_hz", 1.2)))
		col_d.a = 1.0
	if float(s.get("heal_t", 0.0)) > 0.0:
		col_d = col_d.lerp(_col(hud_cfg().get("heal_color"), Color(0.72, 1, 0.72)), float(s.heal_t) / cnum("heal_flash_s", 0.5))
	var pop := 1.0
	if float(s.get("pop_t", 0.0)) > 0.0:
		var f := float(s.pop_t) / cnum("pop_s", 0.2)
		pop = 1.0 + float(s.get("pop_k", 0.0)) * sin(f * PI)
	var shake := Vector2.ZERO
	if float(s.get("shake_t", 0.0)) > 0.0:
		var f := float(s.shake_t) / cnum("shake_s", 0.3)
		var a := float(s.get("shake_a", 0.0)) * f * sc
		var hz := cnum("shake_hz", 30.0)
		shake = Vector2(sin(_t * TAU * hz) * a, cos(_t * TAU * hz * 0.83) * a * 0.5)
	var dy := 0.0
	var alpha := 1.0
	if fall_t >= 0.0:
		var fade := _fall_cfg("fade_s", 0.35)
		var zero := _fall_cfg("zero_s", 1.0)
		if fall_t < _fall_cfg("flash_s", 0.1) + 0.08:
			col_d = Color.WHITE
		if fall_t < fade:
			var f := fall_t / fade
			dy = -float(_blk("fall").get("rise_px", 20.0)) * sc * f
			alpha = 1.0 - f
		elif fall_t < zero:
			alpha = 0.0
		else:
			alpha = clampf((fall_t - zero) / 0.3, 0.0, 1.0)
	var ds := int(big * pop)
	var dw := _bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, ds).x
	var sw := _bold.get_string_size("%", HORIZONTAL_ALIGNMENT_LEFT, -1, sign_px).x
	var base_y := r.end.y - 10.0 * sc + dy
	var dx := (tx0 - dw - sw - 2.0 * sc) if flip else tx0
	var at := Vector2(dx, base_y) + shake
	col_d.a = alpha
	if bool(info.outline):
		draw_string_outline(_bold, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, ds, int(2 * sc), Color(1, 1, 1, 0.55 * alpha))
	draw_string_outline(_bold, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, ds, int(5 * sc), Color(0, 0, 0, 0.6 * alpha))
	draw_string(_bold, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, ds, col_d)
	draw_string(_bold, at + Vector2(dw + 2.0 * sc, 0.0), "%", HORIZONTAL_ALIGNMENT_LEFT, -1, sign_px, Color(col_d, alpha * 0.85))
	# safe: a small glyph and the bar
	if float(info.safe) >= 0.0:
		var sd := _blk("safe")
		var sg := float(sd.get("glyph_px", 14.0)) * sc
		var scol := _col(sd.get("color"), Color(0.62, 0.86, 0.96))
		var sx := (r.position.x + 10.0 * sc) if flip else (r.end.x - 10.0 * sc - float(sd.get("bar_w", 60.0)) * sc)
		var sy := r.position.y + 8.0 * sc
		draw_arc(Vector2(sx + sg * 0.5, sy + sg * 0.5), sg * 0.45, PI * 0.15, PI * 0.85, 10, scol, 2.0 * sc)
		draw_line(Vector2(sx + sg * 0.5, sy + sg * 0.1), Vector2(sx + sg * 0.5, sy + sg * 0.95), scol, 2.0 * sc)
		var bw := float(sd.get("bar_w", 60.0)) * sc - sg - 4.0 * sc
		var bh := float(sd.get("bar_h", 4.0)) * sc
		draw_rect(Rect2(sx + sg + 4.0 * sc, sy + sg * 0.5 - bh * 0.5, bw, bh), Color(scol, 0.25))
		draw_rect(Rect2(sx + sg + 4.0 * sc, sy + sg * 0.5 - bh * 0.5, bw * float(info.safe), bh), scol)
	if not bool(info.mine):
		return
	# YOUR plate: the fresh band (a thin bar under the digits, its fresh end lighter) and the pips (jump, dodge, Rise)
	var fr := _blk("fresh")
	var full := float(fr.get("bar_full_pct", 200.0))
	var bar_w := r.size.x - (tx0 - r.position.x) - pad
	var bar_h := float(fr.get("bar_h", 3.0)) * sc
	var by := r.end.y - 6.0 * sc
	var p := clampf(float(info.pct) / full, 0.0, 1.0)
	var fp := clampf(maxf(float(info.fresh), 0.0) / full, 0.0, p)
	draw_rect(Rect2(tx0, by, bar_w * (p - fp), bar_h), _col(fr.get("base"), Color(1, 1, 1, 0.22)))
	draw_rect(Rect2(tx0 + bar_w * (p - fp), by, bar_w * fp, bar_h), _col(fr.get("color"), Color(1, 1, 1, 0.75)))
	var pd := _blk("pips")
	var pp := float(pd.get("px", 12.0)) * sc
	var gap := float(pd.get("gap", 8.0)) * sc
	var px0 := r.end.x - pad - 3.0 * (pp + gap) + gap
	var py := r.end.y - pp - 12.0 * sc
	var ps: Array = info.pips
	for i in 3:
		var on := bool(ps[i]) if i < ps.size() else true
		var c := Color(FrontierHUD.INK, 1.0 if on else float(pd.get("dim", 0.25)))
		var o := Vector2(px0 + float(i) * (pp + gap), py)
		_draw_pip(i, Rect2(o, Vector2(pp, pp)), c)


## Pip `i`'s own small glyph: 0 the jump (a short rising bar over a dot), 1 the dodge (a slanted dash), 2 the Rise (a
## column over a wave).
func _draw_pip(i: int, r: Rect2, c: Color) -> void:
	var cx := r.get_center().x
	match i:
		0:
			draw_circle(Vector2(cx, r.end.y - r.size.y * 0.15), r.size.x * 0.14, c)
			draw_line(Vector2(cx, r.end.y - r.size.y * 0.4), Vector2(cx, r.position.y), c, maxf(r.size.x * 0.16, 1.5))
		1:
			draw_line(Vector2(r.position.x, r.end.y - r.size.y * 0.25), Vector2(r.end.x, r.position.y + r.size.y * 0.25), c,
					maxf(r.size.x * 0.18, 1.5))
		_:
			draw_rect(Rect2(cx - r.size.x * 0.12, r.position.y, r.size.x * 0.24, r.size.y * 0.7), c)
			draw_line(Vector2(r.position.x, r.end.y - r.size.y * 0.1), Vector2(r.end.x, r.end.y - r.size.y * 0.1), c,
					maxf(r.size.x * 0.12, 1.2))


## A plate's 2 px side rule and life glyphs (round 4, HUD: RingSides.colour: the element's home colour, its away colour for a
## side in the away dress of a mirror match; like team jerseys). A colour on a fixed plate: never on or near a body.
static func side_colour(t: int, el: String) -> Color:
	return RingSides.colour(t, el)


## The ONE ink outline's width (hud.json strip.ink_px): the plate's name wears it as the strip's letters do.
static func ink_px() -> float:
	return BendStrip.snum("ink_px", 5.0) * 0.6


## The element's mark (round 4: the new set's own, assets/ui/icons/spell_mark__<element>.svg: three stacked slabs, one curling
## crest, three tongues, streaks with a curl), tinted the side's colour on a dark disc; without the file round 3's shapes.
func _draw_glyph(el: String, r: Rect2, c: Color) -> void:
	var o := r.get_center()
	var s := r.size.x * 0.5
	draw_circle(o, s, Color(0.0, 0.0, 0.0, 0.35))
	var tex := BendStrip.icon_texture("mark", el)
	if tex != null:
		var inner := r.grow(-s * 0.22)
		draw_texture_rect(tex, Rect2(inner.position + Vector2(1, 1), inner.size), false, Color(0, 0, 0, 0.5))
		draw_texture_rect(tex, inner, false, c)
		return
	match el:
		"earth":
			draw_colored_polygon(PackedVector2Array([o + Vector2(-0.55, 0.45) * s, o + Vector2(0.55, 0.45) * s,
					o + Vector2(0.4, -0.15) * s, o + Vector2(0.0, -0.55) * s, o + Vector2(-0.4, -0.15) * s]), c)
		"water":
			for k in 3:
				var y := (-0.35 + 0.35 * float(k)) * s
				var pts := PackedVector2Array()
				for j in 9:
					var x := (-0.6 + 1.2 * float(j) / 8.0) * s
					pts.append(o + Vector2(x, y + sin(float(j) / 8.0 * TAU) * 0.1 * s))
				draw_polyline(pts, c, maxf(s * 0.12, 1.5))
		"fire":
			draw_colored_polygon(PackedVector2Array([o + Vector2(0.0, -0.7) * s, o + Vector2(0.35, -0.05) * s,
					o + Vector2(0.45, 0.35) * s, o + Vector2(0.0, 0.6) * s, o + Vector2(-0.45, 0.35) * s,
					o + Vector2(-0.3, -0.1) * s]), c)
		_:
			draw_arc(o, s * 0.55, 0.0, PI * 1.5, 18, c, maxf(s * 0.12, 1.5))
			draw_arc(o + Vector2(s * 0.1, 0.0), s * 0.28, PI, PI * 2.4, 12, c, maxf(s * 0.1, 1.2))
