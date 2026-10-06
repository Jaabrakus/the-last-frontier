class_name ThuyVanCanon
extends RefCounted
## Thủy Vân's canon data (data/thuyvan; the owner, 2026-10-05: Thủy Vân replaces the 1765 frontier, English text with
## the names kept and English titles). The eight peoples, the atlas, the bible's routes and travel windows, the calendar
## and the four arts, each file read once and kept. Public fields only: what a traveller in Book I could know (the text
## guard, tools/thuyvan/text_guard.py, keeps it that way). Rows are found by id ("mountain_folk", "da_trang") or by
## their bible id ("P02", "L03"); display strings are {text, voice}, and text() gives the words.

const DIR := "res://data/thuyvan/"
## Each collection: its file and the key holding its rows.
const FILES := {
	"peoples": ["peoples.json", "peoples"],
	"places": ["atlas.json", "places"],
	"routes": ["routes.json", "routes"],
	"arts": ["arts.json", "arts"],
	"bands": ["arts.json", "bands"],
	"calendar": ["calendar.json", "calendar"],
}
## The collections whose rows can also be found by their first bible id.
const BY_SRC := ["peoples", "places"]
## One bible day in game hours when calendar.json says nothing (1 bible month = 3 survival days).
const HOURS_PER_DAY := 2.4

static var _files := {}
static var _index := {}


## A data file parsed ({} if missing or broken).
static func file(name: String) -> Dictionary:
	if not _files.has(name):
		var d: Variant = null
		var f := FileAccess.open(DIR + name, FileAccess.READ)
		if f:
			d = JSON.parse_string(f.get_as_text())
		_files[name] = d if d is Dictionary else {}
	return _files[name]


## Drop the cached files (a test, or data changed on disk).
static func reload() -> void:
	_files.clear()
	_index.clear()


## Every row of a collection (peoples, places, routes, arts, bands, calendar).
static func rows(collection: String) -> Array:
	var spec: Array = FILES.get(collection, [])
	if spec.is_empty():
		return []
	var r: Variant = file(String(spec[0])).get(String(spec[1]), [])
	return r if r is Array else []


## A collection's row by id (or first bible id where BY_SRC; an art also by its code id: "water" is Current).
static func row(collection: String, id: String) -> Dictionary:
	if not _index.has(collection):
		var index := {}
		for r: Variant in rows(collection):
			if not r is Dictionary:
				continue
			index[String(r.get("id", ""))] = r
			var src: Array = r.get("src", [])
			if collection in BY_SRC and not src.is_empty() and not index.has(String(src[0])):
				index[String(src[0])] = r
			if r.has("code_id") and not index.has(String(r.code_id)):
				index[String(r.code_id)] = r
		_index[collection] = index
	return (_index[collection] as Dictionary).get(id, {})


static func people(id: String) -> Dictionary:
	return row("peoples", id)


static func place(id: String) -> Dictionary:
	return row("places", id)


static func art(id: String) -> Dictionary:
	return row("arts", id)


static func band(id: String) -> Dictionary:
	return row("bands", id)


static func calendar(id: String) -> Dictionary:
	return row("calendar", id)


## The words of a display string ({text, voice}); a plain string as it is.
static func text(display: Variant) -> String:
	if display is Dictionary:
		return String(display.get("text", ""))
	if display is String:
		return display
	return ""


## A place's name as the given book may say it: a name that belongs to a later book (name_book) gives way to its
## book1_label before then.
static func place_label(id: String, book := 1) -> String:
	var p := place(id)
	if p.is_empty():
		return ""
	if int(p.get("name_book", 1)) > book and p.has("book1_label"):
		return text(p.book1_label)
	return text(p.get("name", ""))


## The route between two places (ids or bible ids), whichever way it is written; {} if none.
static func route(from: String, to: String) -> Dictionary:
	var a := String(place(from).get("id", from))
	var b := String(place(to).get("id", to))
	for r: Variant in rows("routes"):
		if r is Dictionary:
			var rf := String(r.get("from", ""))
			var rt := String(r.get("to", ""))
			if (rf == a and rt == b) or (rf == b and rt == a):
				return r
	return {}


## One bible day in game hours (calendar.json's day_scale: 2.4, so a 30-day month is 3 survival days).
static func game_hours_per_day() -> float:
	return float(calendar("day_scale").get("game_hours_per_day", HOURS_PER_DAY))


## The journey's window in game hours (x the least, y the most), ordinary or disrupted. Going against the route's
## direction uses its return window where the bible gives one; a disrupted return is never quicker than an ordinary
## one. Vector2.ZERO when no route joins them.
static func travel_hours(from: String, to: String, disrupted := false) -> Vector2:
	var r := route(from, to)
	if r.is_empty():
		return Vector2.ZERO
	var days := _window(r.get("disrupted_days" if disrupted else "ordinary_days", []))
	var back := String(r.get("from", "")) != String(place(from).get("id", from))
	if back and r.has("return_ordinary_days"):
		var ret := _window(r.return_ordinary_days)
		days = Vector2(maxf(days.x, ret.x), maxf(days.y, ret.y)) if disrupted else ret
	return days * game_hours_per_day()


static func _window(days: Variant) -> Vector2:
	if days is Array and (days as Array).size() >= 2:
		return Vector2(float(days[0]), float(days[1]))
	return Vector2.ZERO
