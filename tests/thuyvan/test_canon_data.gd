extends SceneTree
## Thủy Vân's canon data and its loader (data/thuyvan, ThuyVanCanon; the owner, 2026-10-05: Thủy Vân replaces the 1765
## frontier). Data only, no scene. Headless:
##
##   Godot --headless --path . -s tests/thuyvan/test_canon_data.gd
##
##   files      every file parses and has rows; every row has an id unique in its collection, bible-id src and a status
##   keys       every key in every file is on the public-key list (no author-side field can slip in unseen)
##   display    every display string is {text, voice} with a known voice; proposal_fields name fields the row has
##   nfc        every string is NFC (no combining mark: Vietnamese has a precomposed letter for every one)
##   no L15     no file under res://data/thuyvan holds an L15 row or id; the atlas is L01-L14 and L16
##   peoples    P01-P08, homelands in the atlas, body kits, Vietnamese names pending the owner's pick
##   routes     every endpoint is a place; src matches the endpoints; found by id or bible id, either way round
##   travel     travel_hours is the bible's window times the calendar's 2.4 game hours a day (a 30-day month = 3 survival
##              days), the return window going back
##   arts       Current, Stone, Hearth, Wind on water, earth, fire, air; no band touches speed or aim
## The text guard (tools/thuyvan/text_guard.py) stays in Python; this test does not repeat its term lists.
## Ends with "CANON DATA TEST PASSED (<n> checks)" or "CANON DATA TEST FAILED (<f> of <n>)".

const DIR := "res://data/thuyvan/"
const STATUSES := ["canon", "proposal", "owner_pick"]
const VOICES := ["ui", "narration", "npc", "notice", "imperial"]
const BODY_KITS := ["human", "extension", "new"]
const GATES := ["pilot", "licence", "open_lock", "season", "invitation", "grove_leave"]
## Every key a shipped canon file may hold. A new field is added here on purpose, after asking whether a traveller in
## Book I could know it.
const PUBLIC_KEYS := [
	"_doc", "peoples", "places", "routes", "arts", "bands", "calendar",
	"id", "src", "status", "proposal_fields", "text", "voice", "tags",
	"name", "title", "line", "naming", "name_format", "vi_candidates", "options", "shown", "homeland", "body_kit",
	"lineage", "conditions", "playable_wave",
	"vi_name", "reveal_book", "name_book", "book1_label",
	"from", "to", "method", "ordinary_days", "disrupted_days", "return_ordinary_days", "gates", "constraint",
	"code_id", "material", "teachers", "who", "obligation", "weakens",
	"reach_scale", "knock_scale", "speed_scale", "aim_scale",
	"game_hours_per_day", "game_days_per_month", "count", "days", "numbered", "after_month", "game_hours", "seasons",
	"months", "year", "match_months", "final", "suspended", "from_month",
]
## Keys whose value is always a display string.
const DISPLAY_KEYS := ["name", "title", "line", "naming", "book1_label", "method", "constraint", "material", "who",
		"obligation", "weakens"]

var checks := 0
var fails: Array[String] = []
var _src_re := RegEx.create_from_string("^(§[0-9]{2}|[DPLRHC][0-9]{2})$")


func _initialize() -> void:
	ThuyVanCanon.reload()
	_files()
	_keys_display_nfc()
	_no_l15()
	_peoples()
	_routes()
	_travel()
	_arts()
	if fails.is_empty():
		print("CANON DATA TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("CANON DATA TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _json_files() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(DIR)
	if d:
		for f in d.get_files():
			if f.ends_with(".json"):
				out.append(f)
	out.sort()
	return out


func _files() -> void:
	var names := _json_files()
	_expect(names == ["arts.json", "atlas.json", "calendar.json", "peoples.json", "routes.json"],
			"files: the five canon files and no others (%s)" % str(names))
	for c: String in ThuyVanCanon.FILES:
		var rows := ThuyVanCanon.rows(c)
		var ids := {}
		var bad: Array[String] = []
		for r: Variant in rows:
			if not r is Dictionary:
				bad.append("a row that is not an object")
				continue
			var id := String(r.get("id", ""))
			if id == "" or ids.has(id):
				bad.append("id '%s' empty or repeated" % id)
			ids[id] = true
			if not String(r.get("status", "")) in STATUSES:
				bad.append("%s: status '%s'" % [id, r.get("status")])
			var src: Variant = r.get("src")
			if not src is Array:
				bad.append("%s: src is not a list" % id)
			else:
				for s: Variant in src:
					if not (s is String and _src_re.search(s) != null):
						bad.append("%s: src '%s' is not a bible id" % [id, s])
				if String(r.get("status", "")) == "canon" and (src as Array).is_empty():
					bad.append("%s: a canon row with no source" % id)
		_expect(not rows.is_empty() and bad.is_empty(), "files: %s has %d rows, unique ids, bible-id src, known status %s"
				% [c, rows.size(), str(bad)])


## Every key on the public list, every display string {text, voice}, every string NFC: over every file, whole.
func _keys_display_nfc() -> void:
	for name in _json_files():
		var data := ThuyVanCanon.file(name)
		var bad_keys: Array[String] = []
		var bad_display: Array[String] = []
		var not_nfc: Array[String] = []
		_walk(data, name, bad_keys, bad_display, not_nfc)
		_expect(not data.is_empty() and bad_keys.is_empty(), "keys: %s holds only public keys %s" % [name, str(bad_keys)])
		_expect(bad_display.is_empty(), "display: %s's display strings are {text, voice} %s" % [name, str(bad_display)])
		_expect(not_nfc.is_empty(), "nfc: %s's strings are all NFC %s" % [name, str(not_nfc)])


func _walk(v: Variant, where: String, bad_keys: Array[String], bad_display: Array[String], not_nfc: Array[String]) -> void:
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("text") or d.has("voice"):
			if not (d.get("text") is String and String(d.get("voice", "")) in VOICES):
				bad_display.append(where)
		for k: Variant in d:
			var key := String(k)
			if not key in PUBLIC_KEYS:
				bad_keys.append("%s.%s" % [where, key])
			if not _nfc(key):
				not_nfc.append("%s.%s" % [where, key])
			if key in DISPLAY_KEYS and not (d[k] is Dictionary and (d[k] as Dictionary).has("text")):
				bad_display.append("%s.%s" % [where, key])
			_walk(d[k], "%s.%s" % [where, key], bad_keys, bad_display, not_nfc)
		if d.has("proposal_fields"):
			for f: Variant in d.proposal_fields:
				if not d.has(String(f)):
					bad_display.append("%s: proposal_fields names '%s', which the row lacks" % [where, f])
	elif v is Array:
		for i in (v as Array).size():
			_walk(v[i], "%s[%d]" % [where, i], bad_keys, bad_display, not_nfc)
	elif v is String:
		if not _nfc(v):
			not_nfc.append(where)


## NFC for this data: no combining diacritic (U+0300-U+036F). Every Vietnamese letter has a precomposed form, so an
## NFC string never holds one; a decomposed string always does.
func _nfc(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if c >= 0x0300 and c <= 0x036F:
			return false
	return true


func _no_l15() -> void:
	var hits: Array[String] = []
	for name in _json_files():
		var f := FileAccess.open(DIR + name, FileAccess.READ)
		var raw := f.get_as_text() if f else ""
		if raw == "" or raw.to_lower().contains("l15"):
			hits.append(name)
	_expect(hits.is_empty(), "no L15: no file under data/thuyvan holds an L15 row or id %s" % str(hits))
	var srcs: Array[String] = []
	for p: Variant in ThuyVanCanon.rows("places"):
		srcs.append(String((p.get("src", [""]) as Array)[0]))
	srcs.sort()
	var want: Array[String] = []
	for i in range(1, 17):
		if i != 15:
			want.append("L%02d" % i)
	_expect(srcs == want, "no L15: the atlas is L01-L14 and L16 (%s)" % ", ".join(srcs))
	var l14 := ThuyVanCanon.place("L14")
	_expect(int(l14.get("reveal_book", 0)) == 2, "no L15: L14 is first shown in Book II")
	_expect(ThuyVanCanon.place_label("L13", 1) != ThuyVanCanon.place_label("L13", 2)
			and "book1_label" in (ThuyVanCanon.place("L13").get("proposal_fields", []) as Array),
			"no L15: L13's later-book name gives way to its Book I label (a proposal) in Book I ('%s' / '%s')"
			% [ThuyVanCanon.place_label("L13", 1), ThuyVanCanon.place_label("L13", 2)])


func _peoples() -> void:
	var srcs: Array[String] = []
	var bad: Array[String] = []
	for p: Variant in ThuyVanCanon.rows("peoples"):
		var id := String(p.get("id", ""))
		srcs.append(String((p.get("src", [""]) as Array)[0]))
		for h: Variant in p.get("homeland", []):
			if ThuyVanCanon.place(String(h)).is_empty():
				bad.append("%s: homeland %s" % [id, h])
		if not String(p.get("body_kit", "")) in BODY_KITS:
			bad.append("%s: body kit" % id)
		var vi: Dictionary = p.get("vi_candidates", {})
		if String(vi.get("status", "")) != "owner_pick" or String(vi.get("shown", "")) != "pending" \
				or (vi.get("options", []) as Array).is_empty():
			bad.append("%s: Vietnamese names not waiting on the owner" % id)
		if int(p.get("playable_wave", 0)) < 1:
			bad.append("%s: playable wave" % id)
		if ThuyVanCanon.text(p.get("name")) == "" or ThuyVanCanon.text(p.get("title")) == "":
			bad.append("%s: name or title" % id)
	srcs.sort()
	_expect(srcs == ["P01", "P02", "P03", "P04", "P05", "P06", "P07", "P08"] and bad.is_empty(),
			"peoples: P01-P08, homelands in the atlas, body kits, names pending the owner's pick %s" % str(bad))
	var mf := ThuyVanCanon.people("P02")
	_expect(String(mf.get("id", "")) == "mountain_folk" and int(mf.get("playable_wave", 0)) == 1,
			"peoples: Mountain Folk (found by P02) are playable first")
	_expect(ThuyVanCanon.text(ThuyVanCanon.people("stone_children").get("title")) == "Stone Children, of the Stone Valleys"
			and ThuyVanCanon.text(ThuyVanCanon.people("floodborn").get("title")) == "Floodborn, of the Reed Marches",
			"peoples: the Stone Children's and the Floodborn's English titles as the plan corrects them")
	var ab := ThuyVanCanon.people("ancestor_bound")
	_expect(String(ab.get("body_kit", "")) == "human" and ab.get("lineage", false) == true
			and ab.get("conditions", []) == ["bound", "unbound"],
			"peoples: Ancestor-Bound are a human lineage, Bound or Unbound, not a body")


func _routes() -> void:
	var bad: Array[String] = []
	var rows := ThuyVanCanon.rows("routes")
	for r: Variant in rows:
		var id := String(r.get("id", ""))
		var a := ThuyVanCanon.place(String(r.get("from", "")))
		var b := ThuyVanCanon.place(String(r.get("to", "")))
		if a.is_empty() or b.is_empty():
			bad.append("%s: an endpoint is not a place" % id)
			continue
		if r.get("src", []) != [(a.src as Array)[0], (b.src as Array)[0]]:
			bad.append("%s: src does not match its endpoints" % id)
		for g: Variant in r.get("gates", []):
			if not String(g) in GATES:
				bad.append("%s: gate %s" % [id, g])
		var o := ThuyVanCanon._window(r.get("ordinary_days"))
		var d := ThuyVanCanon._window(r.get("disrupted_days"))
		if o.x <= 0.0 or o.x > o.y or d.x < o.x or d.y < o.y:
			bad.append("%s: windows %s / %s" % [id, o, d])
	_expect(rows.size() == 11 and bad.is_empty(), "routes: the bible's 11 routes (no L14 to L15), every endpoint a place %s"
			% str(bad))
	var r1 := ThuyVanCanon.route("da_trang", "two_heights")
	_expect(not r1.is_empty() and ThuyVanCanon.route("L16", "L03") == r1 and ThuyVanCanon.route("L03", "L16") == r1,
			"routes: found by id or bible id, either way round")
	_expect(ThuyVanCanon.route("da_trang", "van_thuy").get("gates", []) == ["open_lock"]
			and ThuyVanCanon.route("van_thuy", "ao_thanh").get("gates", []) == ["invitation"],
			"routes: the capital's river needs open locks; Ảo Thành an invitation")
	_expect(ThuyVanCanon.route("da_trang", "lam_uyen").is_empty()
			and ThuyVanCanon.travel_hours("da_trang", "lam_uyen") == Vector2.ZERO,
			"routes: no route, no journey (Đá Trắng to Lâm Uyên goes through two others)")


func _travel() -> void:
	var h := ThuyVanCanon.game_hours_per_day()
	var months := ThuyVanCanon.calendar("months")
	var scale := ThuyVanCanon.calendar("day_scale")
	_expect(is_equal_approx(h, 2.4) and is_equal_approx(h * float(months.get("days", 0)),
			24.0 * float(scale.get("game_days_per_month", 0))) and int(months.get("count", 0)) == 12,
			"travel: a bible day is %.1f game hours, so a 30-day month is 3 survival days and the 12 months 36" % h)
	_expect(int(ThuyVanCanon.calendar("flood_rite_days").get("count", 0)) == 5
			and ThuyVanCanon.calendar("flood_rite_days").get("numbered", true) == false,
			"travel: five unnumbered flood-rite days")
	var bad: Array[String] = []
	for r: Variant in ThuyVanCanon.rows("routes"):
		var a := String(r.from)
		var b := String(r.to)
		var o := ThuyVanCanon._window(r.ordinary_days) * h
		var d := ThuyVanCanon._window(r.disrupted_days) * h
		if not (ThuyVanCanon.travel_hours(a, b).is_equal_approx(o) and ThuyVanCanon.travel_hours(a, b, true).is_equal_approx(d)):
			bad.append(String(r.id))
		var back := ThuyVanCanon._window(r.get("return_ordinary_days", r.ordinary_days)) * h
		if not ThuyVanCanon.travel_hours(b, a).is_equal_approx(back):
			bad.append(String(r.id) + " back")
	_expect(bad.is_empty(), "travel: every route's hours are its bible window times %.1f, both ways %s" % [h, str(bad)])
	var up := ThuyVanCanon.travel_hours("van_thuy", "da_trang")
	_expect(up.is_equal_approx(Vector2(14.4, 21.6)), "travel: the capital to Đá Trắng by cutter, 6-9 days, is 14.4-21.6 game hours (%s)" % up)
	var down := ThuyVanCanon.travel_hours("van_thuy", "reed_marches")
	var ret := ThuyVanCanon.travel_hours("L06", "L02")
	var ret_bad := ThuyVanCanon.travel_hours("reed_marches", "van_thuy", true)
	_expect(down.is_equal_approx(Vector2(9.6, 14.4)) and ret.is_equal_approx(Vector2(16.8, 24.0))
			and ret_bad.x >= ret.x and ret_bad.y >= ret.y,
			"travel: down to the Reed Marches 4-6 days, back against the current 7-10, a disrupted return no quicker (%s, %s, %s)"
			% [down, ret, ret_bad])


func _arts() -> void:
	var codes := {}
	for a: Variant in ThuyVanCanon.rows("arts"):
		codes[String(a.id)] = String(a.code_id)
	_expect(codes == {"current": "water", "stone": "earth", "hearth": "fire", "wind": "air"},
			"arts: Current, Stone, Hearth, Wind on water, earth, fire, air (%s)" % str(codes))
	_expect(String(ThuyVanCanon.art("water").get("id", "")) == "current" and ThuyVanCanon.art("fire") == ThuyVanCanon.art("hearth"),
			"arts: found by their code id too")
	var bad: Array[String] = []
	for a: Variant in ThuyVanCanon.rows("arts"):
		for t: Variant in a.get("teachers", []):
			for p: Variant in t.get("peoples", []):
				if ThuyVanCanon.people(String(p)).is_empty():
					bad.append("%s: %s" % [a.id, p])
			if not String(t.get("status", "")) in STATUSES:
				bad.append("%s: teacher status" % a.id)
	_expect(bad.is_empty(), "arts: every teacher's people exist and carry a status %s" % str(bad))
	var homes_proposed := true
	for id in ["hearth", "wind"]:
		for t: Variant in ThuyVanCanon.art(id).get("teachers", []):
			homes_proposed = homes_proposed and String(t.get("status", "")) == "proposal"
	_expect(homes_proposed, "arts: Hearth's and Wind's homes are proposals")
	var bands := ThuyVanCanon.rows("bands")
	var untouched := bands.size() == 3
	for b: Variant in bands:
		untouched = untouched and is_equal_approx(float(b.get("speed_scale", 0.0)), 1.0) \
				and is_equal_approx(float(b.get("aim_scale", 0.0)), 1.0)
	_expect(untouched, "arts: three bands, and none touches speed or aim")
	_expect(is_zero_approx(float(ThuyVanCanon.band("no_material").get("reach_scale", 1.0)))
			and float(ThuyVanCanon.band("away").get("reach_scale", 1.0)) < 1.0
			and is_equal_approx(float(ThuyVanCanon.band("home").get("reach_scale", 0.0)), 1.0),
			"arts: no material no art; away less reach; home full")
