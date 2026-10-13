extends SceneTree
## Round 4's HUD (Tidebreak, task HUD; the owner: "a cleaner HUD", "those big cards are terrible", no target cues of any kind):
## BendStrip's own pictures and layouts, the one help line, the centre words, the type system, headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_r4_hud.gd
## The ring scene with a stock-rules match (earth against a fire bot, held), then a classic one:
##   icons     every chip of each element under both rule sets (BendStrip.every_chip: jabs, guards, the caught stone's
##             return, each key's two moves, fire's grown Fireball, the Slams and "Dodge") resolves to its own svg (a
##             spell_<id>__<mode>.svg of the ring's set: placeholder_icons 0), no two of one element the same picture; the
##             live strip draws each element's chips from those files
##   body      the strip's rects never meet the player's body box (tests/ring/r4_hud_cam.gd: camera A, round 3's, and C,
##             READ's default; aimed at a chest 15 m ahead) at 1280x720, 1440x900 and 1920x1080 in the default layout; L2
##             and L3 measured and printed for the owner
##   labels    no two HUD texts overlap (the plates, the clock, the event line, the fall's centre line and its sub line, the
##             strip and its lines, the status words, "F1 controls") at the three sizes
##   contrast  every strip and plate letter against its own ink outline over the noon deck and the night deck: 4.5:1 or more
##             (the air's greyed "lands" chips, unavailable by design, apart)
##   help      the help line 64 characters or fewer on one line for every scheme; shown in the first match and in Practice, gone
##             after 20 casts, and never outside them
##   no cue    no Label3D or Sprite3D under any body; a bot moved 10 m moves no strip, plate or centre rect; bend_strip.gd,
##             percent_bar.gd and ring_sides.gd read no position
##   menu      the UI audit (2026-10-09): at 1280x720 every row of the Esc menu (RingMenu) and of its Match setup and Options
##             panels is in view; each panel opens from its row with the focus on its first row, and Esc gives the focus back
##             to that row; the HUD is put away while the menu is open and back after (MenuUI.cover_hud); F1's arena help
##             keeps the key hints away when an overlay over the HUD closes, and an overlay still up keeps them as F1 closes
##   class     the Esc menu's Class & talents row (its line: changes apply from the next restart) opens the Character
##             Advancement window over the open menu, for the element in play; Esc closes the window alone (the menu stays open,
##             the game paused) and the focus is back on the row; the window's Your look tab closes it and the menu's note says
##             where the look is changed
##   classic   the classic rules' MatchBar still builds, the strip over the health row
## METRIC lines: icon_count, placeholder_icons, icons_unique_ok, strip_layout, strip_body_overlap_px (cameras A and C),
## label_overlap_px, contrast_min, help_line_chars, hud_no_cue_ok. The last line "R4 HUD TEST PASSED" or "R4 HUD TEST FAILED";
## exit 0 only on a pass; a watchdog quits with 2.

const NAME := "R4 HUD TEST"
const LIMIT_S := 360.0
const OWN_CFG := "user://r4_hud_test.cfg"
const Cam := preload("res://tests/ring/r4_hud_cam.gd")
const SIZES := [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var mode: RingMode
var p: FrontierPlayer
var hud: FrontierHUD
var strip: BendStrip
var bar: PercentBar
var metrics := {}


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	MatchSetup._aim_help = "strong"
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	SwayCaster.free_override = true
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["fire"]
	MatchSetup.difficulty = "easy"
	RingRules.rule_set_override = "stock"
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(maxi(int(round(s * Engine.physics_ticks_per_second)), 1))


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _end() -> void:
	for k: String in metrics:
		print("METRIC %s %s" % [k, metrics[k]])
	RingRules.rule_set_override = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _scene() -> bool:
	for i in 2400:                           # (40 s of ticks: the ring's build and its loading hold)
		await physics_frame
		lvl = current_scene as RingLevel
		mode = RingMode.find(self)
		if i >= 10 and lvl != null and mode != null and mode.level == lvl and lvl.player != null and lvl.player.hud != null \
				and lvl.player.hud.bend_strip != null:
			break
	if lvl == null or mode == null or lvl.player == null or lvl.player.hud == null:
		print("  (the scene: level %s, mode %s)" % [lvl, mode])
		return false
	p = lvl.player
	hud = p.hud
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and mode.foe != null, 8.0)
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 3.0)
	if mode.foe != null:
		mode.foe.held = true
	await _frames(4)
	strip = hud.bend_strip if hud != null else null
	bar = hud.percent_bar if hud != null else null
	return strip != null


func _run() -> void:
	if not await _scene():
		_expect(false, "a stock-rules ring match with the HUD's strip")
		return _end()
	_icons()
	await _live_icons()
	await _body()
	await _labels()
	await _contrast()
	await _help()
	await _no_cue()
	await _menu()
	await _classic()
	_end()


# ---------------------------------------------------------------- the pictures
func _icons() -> void:
	var chips := BendStrip.every_chip()
	var placeholder := 0
	var missing: Array = []
	var seen := {}
	var dupes: Array = []
	for ch: Dictionary in chips:
		var path := BendStrip.icon_path(String(ch.id), String(ch.mode))
		if path == "" or not path.contains("__"):
			placeholder += 1
			missing.append("%s %s/%s" % [ch.element, ch.id, ch.mode])
			continue
		var key := "%s|%s" % [ch.element, FileAccess.get_file_as_string(path).md5_text()]
		if seen.has(key) and String(seen[key]) != "%s/%s" % [ch.id, ch.mode]:
			dupes.append("%s: %s = %s" % [ch.element, seen[key], "%s/%s" % [ch.id, ch.mode]])
		seen[key] = "%s/%s" % [ch.id, ch.mode]
	var by_el := {}
	for ch: Dictionary in chips:
		by_el[ch.element] = int(by_el.get(ch.element, 0)) + 1
	metrics["icon_count"] = "%d (%s)" % [chips.size(), by_el]
	metrics["placeholder_icons"] = placeholder
	metrics["icons_unique_ok"] = str(dupes.is_empty()).to_lower()
	_expect(chips.size() >= 50 and placeholder == 0, "every chip of each element under both rule sets has its own svg: %d chips %s, %d placeholders %s"
			% [chips.size(), by_el, placeholder, missing])
	_expect(dupes.is_empty(), "no two chips of one element share a picture %s" % [dupes])
	var marks := true
	for el: String in Bending.ELEMENTS:
		marks = marks and BendStrip.icon_path("mark", el).ends_with("spell_mark__%s.svg" % el)
	_expect(marks, "the plates' element marks are the new set's own")
	# the open world's five stay as they were (the gate): their files untouched by this task
	var five := true
	for id: String in ["earth_wall", "gust", "mend", "pillar", "stone_form"]:
		five = five and FileAccess.file_exists("res://assets/ui/icons/spell_%s.svg" % id) \
				and FrontierHUD.spell_texture(id, self) != null and FrontierHUD.spell_texture(id, self).resource_path.ends_with("spell_%s.svg" % id)
	_expect(five, "the open world's five spell icons stand as before (FrontierHUD.spell_texture reads them)")


## The live strip: each element's seven chips drawn from the ring's own files, a readied chip in its element's colour.
func _live_icons() -> void:
	var ok := true
	var bad: Array = []
	for el: String in Bending.ELEMENTS:
		MatchSetup.element = el
		await _until(func() -> bool: return p.arena_element == el and p.hotbar.spell != "", 4.0)
		await _frames(4)
		strip.refresh()
		var uis: Array = [strip._chips.jab, strip._chips.guard] + strip._cols
		for ui: Dictionary in uis:
			var tex: Texture2D = ui.tex
			if tex == null or not tex.resource_path.contains("__"):
				ok = false
				bad.append("%s %s" % [el, ui.tex_id])
		var lit: Dictionary = strip._cols[0]
		ok = ok and (lit.tint as Color).is_equal_approx(BendStrip.element_colour(el)) == bool(strip.column(0).readied)
	MatchSetup.element = "earth"
	await _until(func() -> bool: return p.arena_element == "earth" and p.hotbar.spell != "", 4.0)
	await _frames(4)
	_expect(ok, "the live strip draws every element's chips from the ring's own pictures, the readied one in its colour %s" % [bad])


# ---------------------------------------------------------------- off the body
func _fwd() -> Vector3:
	var f := mode.foe.global_position - p.global_position if mode.foe != null else -p.global_basis.z
	f.y = 0.0
	return f.normalized()


func _overlap_px(rects: Array, bx: Rect2) -> int:
	var worst := 0
	for r: Rect2 in rects:
		var i := r.intersection(bx)
		if i.has_area():
			worst = maxi(worst, int(ceil(minf(i.size.x, i.size.y))))
	return worst


func _body() -> void:
	var fov := p.camera.fov if p.camera != null else 60.0
	var pts := Cam.body_points(p)
	_expect(pts.size() >= 8, "the player's body has meshes to measure (%d corners)" % pts.size())
	var lines := PackedStringArray()
	var def_layout := strip.layout()
	metrics["strip_layout"] = def_layout
	for lay: String in BendStrip.LAYOUTS:
		strip.layout_override = lay
		for cam: String in ["A", "C"]:
			var worst := 0
			var at := ""
			for sz: Vector2i in SIZES:
				root.size = sz
				await _frames(3)
				var bx := Cam.box(pts, Cam.xf(p.global_position, _fwd(), cam), fov, Vector2(sz))
				var ov := _overlap_px(strip.strip_rects(), bx)
				if sz == SIZES[0]:
					at = "body %d-%d x %d-%d" % [bx.position.x, bx.end.x, bx.position.y, bx.end.y]
				worst = maxi(worst, ov)
			lines.append("%s cam %s: %d px (1280: %s)" % [lay, cam, worst, at])
			print("METRIC strip_body_overlap_px layout=%s cam=%s %d  (%s)" % [lay, cam, worst, at])
			if lay == def_layout:
				metrics["strip_body_overlap_px_cam_%s" % cam] = worst
				_expect(worst == 0, "the default strip (%s) never meets the body under camera %s at 1280, 1440 and 1920 (%d px; %s)"
						% [lay, cam, worst, at])
	strip.layout_override = ""
	root.size = SIZES[0]
	await _frames(3)
	print("  the layouts: %s" % "; ".join(lines))


# ---------------------------------------------------------------- the labels
## The text box of a Label (its letters, not its whole rect: the centre words span the screen's width).
func _text_rect(l: Label) -> Rect2:
	var f := l.get_theme_font(&"font")
	var fs := l.get_theme_font_size(&"font_size")
	var r := l.get_global_rect()
	var w := 0.0
	var lines := l.text.split("\n")
	for ln in lines:
		w = maxf(w, f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var h := f.get_height(fs) * lines.size()
	var x := r.position.x
	if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x = r.get_center().x - w * 0.5
	elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x = r.end.x - w
	var y := r.position.y
	if l.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		y = r.get_center().y - h * 0.5
	return Rect2(x, y, w, h)


func _shows(l: Label) -> bool:
	return l != null and l.is_visible_in_tree() and l.text.strip_edges() != "" and l.modulate.a > 0.01


func _labels() -> void:
	var worst := 0
	var hits: Array = []
	for sz: Vector2i in SIZES:
		root.size = sz
		# a fall's line up (the centre words), the event line under the clock, the first match's help line shown
		mode._ko_line = RingMode.words("ko_line") % [MatchSetup.competitor("fire"), RingMode.words("ko_left") % 2]
		mode._ko_t = 5.0
		bar._event = String((PercentBar.hud_cfg().words as Dictionary).event) % [MatchSetup.competitor("fire"), 2]
		bar._event_t = 5.0
		strip.first_match_override = true
		await _frames(4)
		var boxes: Array = []           # [name, rect]
		var tr := bar.text_rects()
		boxes.append(["clock", tr.clock])
		boxes.append(["event", tr.event])
		for i in (tr.plates as Array).size():
			boxes.append(["plate %d" % i, tr.plates[i]])
		for l: Label in [mode.banner, mode.sub, mode.top]:
			if _shows(l):
				boxes.append([l.name if l.name != "" else "centre", _text_rect(l)])
		var sr := strip.strip_rects()
		for i in sr.size():
			boxes.append(["strip %d" % i, sr[i]])
		for l: Label in [hud._status, hud._help_hint]:
			if _shows(l):
				boxes.append([l.name, l.get_global_rect()])
		for i in boxes.size():
			for j in range(i + 1, boxes.size()):
				if String(boxes[i][0]).begins_with("strip") and String(boxes[j][0]).begins_with("strip"):
					continue                       # (the strip's own parts stack by its own layout)
				if String(boxes[i][0]).begins_with("plate") and String(boxes[j][0]).begins_with("plate"):
					continue
				var a: Rect2 = boxes[i][1]
				var b: Rect2 = boxes[j][1]
				var x := a.intersection(b)
				if x.has_area():
					var px := int(ceil(minf(x.size.x, x.size.y)))
					worst = maxi(worst, px)
					hits.append("%s: %s x %s %d px" % [sz, boxes[i][0], boxes[j][0], px])
		var banner_ok := _shows(mode.banner) and absf(_text_rect(mode.banner).get_center().y - sz.y * 0.3) < 4.0 \
				and mode.banner.get_theme_font_size(&"font_size") == 44
		_expect(banner_ok, "%s: the fall's line in the 44 px banner at 30%% of the height (%s)" % [sz, mode.banner.text])
	metrics["label_overlap_px"] = worst
	_expect(worst == 0, "no two HUD texts overlap at 1280, 1440 and 1920 (%d px%s)" % [worst, "" if hits.is_empty() else ": %s" % [hits]])
	mode._ko_t = 0.0
	bar._event_t = 0.0
	strip.first_match_override = false
	root.size = SIZES[0]
	await _frames(3)


# ---------------------------------------------------------------- contrast
static func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * float(f.call(c.r)) + 0.7152 * float(f.call(c.g)) + 0.0722 * float(f.call(c.b))


static func contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## The letters of `l` against its ink outline, both over `deck` (their own and their box's fade applied).
func _label_contrast(l: Label, deck: Color) -> float:
	var m := l.modulate.a
	var n: Node = l.get_parent()
	while n is Control:
		m *= (n as Control).modulate.a
		n = n.get_parent()
	var fc := l.get_theme_color(&"font_color")
	var oc := l.get_theme_color(&"font_outline_color")
	var osz := l.get_theme_constant(&"outline_size")
	var fg := deck.lerp(Color(fc.r, fc.g, fc.b), fc.a * m)
	var bg := deck.lerp(Color(oc.r, oc.g, oc.b), oc.a * m) if osz > 0 else deck
	return contrast(fg, bg)


func _contrast() -> void:
	strip.first_match_override = true
	strip._all_casts = 0
	strip.refresh()
	await _secs(1.3)                         # (the help line faded fully in)
	var worst := 99.0
	var at := ""
	var c := PercentBar.hud_cfg()
	for deck_key: String in ["deck_noon", "deck_night"]:
		var d: Array = c.get(deck_key, [0.76, 0.68, 0.58])
		var deck := Color(float(d[0]), float(d[1]), float(d[2]))
		var labels: Array = [strip._help, strip._hint, strip._safe, hud._status, hud._help_hint]
		for ui: Dictionary in [strip._chips.jab, strip._chips.guard] + strip._cols:
			if bool(ui.get("grey", false)):
				continue
			labels.append_array([ui.cap, ui.name, ui.other])
		for l: Label in labels:
			if not _shows(l):
				continue
			var k := _label_contrast(l, deck)
			if k < worst:
				worst = k
				at = "%s on %s" % [l.name, deck_key]
	# the plates' names: TEXT with the ink outline over the plate (45% dark) on the noon sky
	var sky_a: Array = c.get("sky_noon", [0.86, 0.9, 0.95])
	var sky := Color(float(sky_a[0]), float(sky_a[1]), float(sky_a[2]))
	var plate := sky.lerp(Color(0.02, 0.015, 0.01), float((c.plate as Dictionary).alpha))
	var kp := contrast(FrontierHUD.TEXT, plate.lerp(Color(0.02, 0.015, 0.01), 0.88))
	if kp < worst:
		worst = kp
		at = "plate name on the noon sky"
	metrics["contrast_min"] = "%.2f (%s)" % [worst, at]
	_expect(worst >= 4.5, "every strip and plate letter 4.5:1 or more against its ink on the noon and night decks (least %.2f: %s)"
			% [worst, at])
	strip.first_match_override = false


# ---------------------------------------------------------------- the help line
func _help() -> void:
	var longest := 0
	var one_line := true
	for s: String in ["keys", "first_moves", "direction", "radial"]:
		var t := KitWords.strip_help(s)
		longest = maxi(longest, t.length())
		one_line = one_line and not t.contains("\n") and t != ""
	metrics["help_line_chars"] = longest
	_expect(longest <= int(BendStrip.snum("help_max_chars", 64.0)) and one_line,
			"the help line is one line of 64 characters or fewer under every scheme (longest %d)" % longest)
	var f := strip._help.get_theme_font(&"font")
	var w := f.get_string_size(strip.help_line(), HORIZONTAL_ALIGNMENT_LEFT, -1, strip._help.get_theme_font_size(&"font_size")).x
	_expect(w < 1280.0 * 0.5 - BendStrip.snum("margin_x", 16.0), "the help line fits on one line beside the body (%d px)" % w)
	# outside the first match and Practice: never
	strip.first_match_override = false
	strip.practice_override = false
	await _secs(1.4)
	var off := not strip._help.visible
	# the first match: shown, gone after 20 casts
	strip.first_match_override = true
	strip._all_casts = 0
	await _secs(1.4)
	var on := strip._help.visible and strip._help.modulate.a > 0.95 and strip._help.text == strip.help_line()
	for i in int(BendStrip.snum("help_casts", 20.0)):
		strip.count_cast(i % 5)
	await _secs(1.4)
	var gone := not strip._help.visible
	# Practice: shown again from no casts
	strip.first_match_override = false
	strip.practice_override = true
	strip._all_casts = 0
	await _secs(1.4)
	var prac := strip._help.visible
	strip.practice_override = null
	strip.first_match_override = null
	strip._all_casts = 99
	_expect(off and on and gone and prac, "the help line: hidden outside the first match and Practice (%s), shown in the first match (%s), gone after 20 casts (%s), shown in Practice (%s)"
			% [off, on, gone, prac])
	# "tap twice" lines: in the first match after two casts of the key, or while the key is held; else not
	strip._casts = [0, 0, 0, 0, 0]
	strip.first_match_override = false
	await _secs(0.8)
	var hidden := strip.tap_alpha(0) < 0.01
	strip.held_override = {0: true}
	await _secs(0.8)
	var held := strip.tap_alpha(0) > 0.99 and strip.tap_alpha(1) < 0.01
	strip.held_override = {}
	await _secs(0.8)
	_expect(hidden and held and strip.tap_alpha(0) < 0.01, "\"tap twice\" shows outside the first match only while its key is held")


# ---------------------------------------------------------------- no cue
func _rects_now() -> Array:
	var out: Array = strip.strip_rects()
	var tr := bar.text_rects()
	out.append(tr.clock)
	out.append_array(tr.plates)
	out.append(mode.banner.get_global_rect())
	return out


func _no_cue() -> void:
	var on_bodies: Array = []
	for b: Node3D in [p, mode.foe]:
		if b == null:
			continue
		for n in b.find_children("*", "Label3D", true, false) + b.find_children("*", "Sprite3D", true, false):
			on_bodies.append(String(n.get_path()))
	var foe := mode.foe
	var before := _rects_now()
	var start := foe.global_position
	for i in 60:
		foe.global_position = start + _fwd().cross(Vector3.UP) * (10.0 * float(i + 1) / 60.0)
		await physics_frame
	await _frames(3)
	var after := _rects_now()
	foe.global_position = start
	var still := true
	for i in mini(before.size(), after.size()):
		still = still and (before[i] as Rect2).is_equal_approx(after[i])
	still = still and before.size() == after.size()
	var src_ok := true
	for path: String in ["res://scripts/ui/bend_strip.gd", "res://scripts/ui/percent_bar.gd", "res://scripts/ring/ring_sides.gd"]:
		var src := FileAccess.get_file_as_string(path)
		var code := "\n".join(Array(src.split("\n")).filter(func(ln: String) -> bool: return not ln.strip_edges().begins_with("#")))
		src_ok = src_ok and not code.contains("unproject_position") and not code.contains("global_position") \
				and not code.contains("global_transform") and not code.contains("NpcSenses")
	var ok := on_bodies.is_empty() and still and src_ok
	metrics["hud_no_cue_ok"] = str(ok).to_lower()
	_expect(ok, "nothing on or following a body: no Label3D or Sprite3D on one %s, a bot moved 10 m moves no HUD rect (%s), the strip, plates and sides read no position (%s)"
			% [on_bodies, still, src_ok])


# ---------------------------------------------------------------- the Esc menu
## The visible rows of `rows` (each with its sub-line) not wholly inside `vr`, by name.
func _rows_out(rows: Node, vr: Rect2) -> Array:
	var out: Array = []
	for n in rows.get_children():
		var c := n as Control
		if c == null or not c.is_visible_in_tree():
			continue
		var r := c.get_global_rect()
		var sub := c.find_child("Sub", true, false) as Control
		if sub != null:
			r = r.merge(sub.get_global_rect())
		if not vr.grow(0.5).encloses(r):
			out.append("%s %s" % [c.name, r])
	return out


## Esc as the player presses it (through the viewport: the menu's _unhandled_input).
func _esc() -> void:
	await _ui(&"ui_cancel")


## A UI action as the keys or the pad send it.
func _ui(a: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = a
	ev.pressed = true
	root.push_input(ev)
	await _frames(2)


## The Aim help row of the Options panel: its chips in the order of the help (Off, Normal, Strong), Enter and Right and Left all going
## round the same way (the last value's Right is the first, the first's Left the last).
func _aim_row(m: RingMenu) -> void:
	var kept := MatchSetup.aim_help()
	m.option_rows()
	await _frames(3)
	var row := m._aim as BroadcastUI.OptionRow
	var words: Array = row.chips.chips.map(func(c: BroadcastUI.Chip) -> String: return (c.find_child("Text", true, false) as Label).text)
	_expect(words == ["Off", "Normal", "Strong"] and MatchSetup.AIM_ORDER == ["off", "light", "strong"],
			"the Aim help chips run from the least help to the most (%s)" % [words])
	MatchSetup.set_aim_help("strong")
	m._paint()
	row.grab_focus()
	await _frames(2)
	await _ui(&"ui_right")
	var wrapped_right := MatchSetup.aim_help() == "off"
	await _ui(&"ui_left")
	var wrapped_left := MatchSetup.aim_help() == "strong"
	MatchSetup.set_aim_help("light")
	var next := MatchSetup.next_aim_help()                # (Enter's turn: light, then strong, then off)
	MatchSetup.set_aim_help("strong")
	var after := MatchSetup.next_aim_help()
	_expect(wrapped_right and wrapped_left and next == "strong" and after == "off",
			"Aim help: Right from Strong is Off (%s), Left from Off is Strong (%s), Enter's turn Normal > Strong > Off (%s, %s)"
			% [wrapped_right, wrapped_left, next, after])
	MatchSetup.set_aim_help(kept)
	m._paint()
	await _esc()


## One panel of the Esc menu opened from its row (`row`): shown with the focus on its first row, its rows in view, and Esc
## back to the row with the panel shut.
func _panel_check(m: RingMenu, row: Button, panel: VBoxContainer, vr: Rect2, what: String) -> void:
	row.grab_focus()
	row.pressed.emit()
	await _frames(3)
	var rows := panel.get_node(^"Rows")
	var first: Control = null
	for n in rows.get_children():
		if (n as Control).visible:
			first = n as Control
			break
	var open := panel.is_visible_in_tree() and root.gui_get_focus_owner() == first
	var out := _rows_out(rows, vr)
	# (the broadcast look: the row that opened the panel stays drawn open beside it, and lets go as Esc closes the panel)
	var held := row is BroadcastUI.Row and (row as BroadcastUI.Row).held
	await _esc()
	var back := m.is_open() and not panel.visible and root.gui_get_focus_owner() == row
	var let_go := row is BroadcastUI.Row and not (row as BroadcastUI.Row).held
	_expect(open and out.is_empty() and back and held and let_go, "the Esc menu's %s panel: opens with the focus on its first row (%s), every row in view (out: %s), its row held open beside it (%s) and let go (%s), Esc gives the focus back to its row (%s)"
			% [what, open, out, held, let_go, back])


## The Esc menu's Class & talents row: the real window over the open menu, Esc closing it alone, the focus back on the row.
func _class_row(m: RingMenu) -> void:
	var row := m._class_row
	var sub := row.find_child("Sub", true, false) as Label if row != null else null
	_expect(row != null and row.is_visible_in_tree() and sub != null and sub.text.contains("next restart"),
			"the Esc menu's Class & talents row says the changes apply from the next restart ('%s')" % [sub.text if sub else "none"])
	if row == null:
		return
	row.grab_focus()
	row.pressed.emit()
	await _frames(3)
	var wins := m.find_children("*", "AdvancementWindow", false, false).filter(func(w: Node) -> bool: return not w.is_queued_for_deletion())
	var win := wins[0] as AdvancementWindow if not wins.is_empty() else null
	_expect(win != null and win.element == mode.element and win.layer > m.layer and win.process_mode == Node.PROCESS_MODE_ALWAYS and paused and m.is_open(),
			"the row opens the Character Advancement window over the open menu, for the element in play (%s), above it, over the paused game" % [win.element if win else "none"])
	if win == null:
		return
	await _esc()
	var gone := m.find_children("*", "AdvancementWindow", false, false).filter(func(w: Node) -> bool: return not w.is_queued_for_deletion()).is_empty()
	_expect(gone and m.is_open() and paused and root.gui_get_focus_owner() == row,
			"Esc closes the window alone: the menu still open (%s) and the game still paused (%s), the focus back on the row (%s)"
			% [m.is_open(), paused, root.gui_get_focus_owner() == row])
	# its Your look tab: the window closes and the menu says where the look is changed (the creator is the main menu's)
	row.pressed.emit()
	await _frames(3)
	var w2 := m.find_children("*", "AdvancementWindow", false, false).filter(func(w: Node) -> bool: return not w.is_queued_for_deletion())
	if w2.is_empty():
		_expect(false, "the window opens again for its Your look tab")
		return
	(w2[0] as AdvancementWindow).look_requested.emit()
	await _frames(3)
	var gone2 := m.find_children("*", "AdvancementWindow", false, false).filter(func(w: Node) -> bool: return not w.is_queued_for_deletion()).is_empty()
	_expect(gone2 and m.is_open() and m._note.text.contains("main menu") and root.find_children("*", "CharacterCreator", true, false).is_empty(),
			"the window's Your look tab: it closes, the note says where the look is changed ('%s'), no creator over a match" % m._note.text)


## The smallest type under `n` on screen: its theme size times the scale it is drawn at (the visible labels with text).
func _smallest_text(n: Node) -> float:
	var small := 9999.0
	for c in n.find_children("*", "Label", true, false):
		var l := c as Label
		if l.is_visible_in_tree() and l.text.strip_edges() != "":
			small = minf(small, float(l.get_theme_font_size("font_size")) * l.get_global_transform_with_canvas().get_scale().y)
	return small


func _menu() -> void:
	root.size = Vector2i(1280, 720)
	await _frames(3)
	var m := mode.menu as RingMenu
	if m == null:
		_expect(false, "the Esc menu installed")
		return
	var vr := root.get_visible_rect()
	m.open()
	await _frames(3)
	var rows := 0
	for n in m._items.get_children():
		rows += 1 if (n as Control).visible else 0
	var out := _rows_out(m._items, vr)
	var covered := not hud.visible
	_expect(m.is_open() and rows >= 8 and out.is_empty(), "at 1280x720 every row of the Esc menu is in view (%d rows; out: %s)" % [rows, out])
	var small := _smallest_text(m)
	_expect(small >= 14.0, "at 1280x720 the Esc menu's smallest type is %.1f px on screen (the audit's floor: 14)" % small)
	await _panel_check(m, m._setup_row, m._setup, vr, "Match setup")
	await _panel_check(m, m._options_row, m._options, vr, "Options")
	await _aim_row(m)
	await _class_row(m)
	m.close()
	await _frames(2)
	_expect(covered and hud.visible and not paused, "the HUD put away while the Esc menu is open (%s) and back after it closes (%s)" % [covered, hud.visible])
	# F1's arena help and an overlay over the HUD (the round and match screens' way, MenuUI.cover_hud): one help at a time
	var was := FirstHints.force
	FirstHints.force = true
	var fh := FirstHints.install(mode, true)
	FirstHints.force = was
	var over := CanvasLayer.new()
	over.layer = 85
	root.add_child(over)
	await _frames(2)
	var shown := fh != null and fh.visible
	MenuUI.cover_hud(over, true)                 # the overlay first, then F1, then the overlay gone: the hints stay away
	hud._help_box.visible = true
	await _frames(2)
	MenuUI.cover_hud(over, false)
	await _frames(2)
	var stays := fh != null and not fh.visible and hud.visible
	hud._help_box.visible = false
	await _frames(2)
	var back := fh != null and fh.visible
	hud._help_box.visible = true                 # F1 first, then the overlay, then F1 shut under it: the hints wait for it
	await _frames(2)
	MenuUI.cover_hud(over, true)
	hud._help_box.visible = false
	await _frames(2)
	var waits := fh != null and not fh.visible
	MenuUI.cover_hud(over, false)
	await _frames(2)
	var after := fh != null and fh.visible
	over.queue_free()
	if fh != null:
		fh.queue_free()
	_expect(shown and stays and back and waits and after,
			"F1 and an overlay over the HUD: the key hints (%s) stay away when the overlay goes under F1 (%s) and come back with F1 shut (%s); F1 shut under the overlay leaves them away (%s) until it goes (%s)"
			% [shown, stays, back, waits, after])


# ---------------------------------------------------------------- the classic rules
func _classic() -> void:
	RingRules.rule_set_override = "classic"
	MatchSetup.incoming = true                # (MatchSetup.take used it up at the first match)
	var old := current_scene
	change_scene_to_file("res://scenes/ring.tscn")
	for i in 600:
		await process_frame
		if current_scene != null and current_scene != old:
			break
	if not await _scene():
		_expect(false, "a classic ring match")
		return
	await _frames(10)
	var health := hud._health_bar.get_parent().get_parent() as Control if hud._health_bar != null else null
	var sr := strip.strip_rects()
	var top := INF
	for r: Rect2 in sr:
		top = minf(top, r.position.y)
	var low := -INF
	for r: Rect2 in sr:
		low = maxf(low, r.end.y)
	var clear := health == null or not health.is_visible_in_tree() or low <= health.get_global_rect().position.y + 1.0
	_expect(not RingRules.stock_on() and hud.match_bar != null and hud.match_bar.is_visible_in_tree() and not bar.visible
			and not sr.is_empty() and clear,
			"the classic rules: the MatchBar builds and shows, the strip over the health row (strip bottom %d, health top %s)"
			% [low, health.get_global_rect().position.y if health != null else -1])
