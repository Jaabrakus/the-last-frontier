class_name MenuPaintings
extends RefCounted
## The pictures of the main menu, the loading screens and the museum.
##   all()     Tidebreak arena screenshots for the public demo menu and fallback loading screens.
##   legacy()  retained pictures of the earlier game (user 2026-09-28: "have our game pictures instead of the paintings"; "use this
##             video for the stills": stills of the river and its fish, with no player in them), behind the menu and
##             on the loading screens (assets/ui/pictures/SOURCE.md); each with a title and captions from the history
##             of the place and the time
##   museum()  the period's paintings (user 2026-09-28: "those paintings we put in a museum about the history around
##             that day and age"; "no portraits of the people"): public-domain paintings of the place and the time,
##             each download approved (assets/ui/paintings/world/SOURCE.md), for the menu's Museum
## The folklore in the captions keeps to what people of the time believed and wrote.

const PICTURES_DIR := "res://assets/ui/tidebreak/"
const PICTURES := [
	{"file": "deck.png", "title": "Four elements. One arena.",
		"captions": ["Choose Earth, Water, Fire or Air. Build pressure, earn your opening and send your opponent into the water."]},
	{"file": "behind.png", "title": "Find your rhythm",
		"captions": ["Tap to attack, move to make space, and watch for an opening. Start here offers an easy match or lessons at your own pace."]},
	{"file": "sky.png", "title": "Make waves",
		"captions": ["Jump, dodge and recover above the water. Practice has no countdown, so there is time to find what works for you."]},
]

## Archived open-world presentation. Kept with its source record; not in the demo rotation.
const LEGACY_PICTURES_DIR := "res://assets/ui/pictures/"
const LEGACY_PICTURES := [
	{"file": "shallows.jpg", "title": "The shallows",
		"captions": ["The rivers were full of fish. The Six Nations took them with weirs, nets and spears at the places and seasons they had always known, and the settlers learned the same places from them."]},
	{"file": "deep_water.jpg", "title": "Deep water",
		"captions": ["In spring the shad ran up the Hudson in such numbers that farmers took them by the cartload and salted them down by the barrel for the winter."]},
	{"file": "river_from_above.jpg", "title": "The river",
		"captions": ["Every river was a road. Boats were poled up it against the current, and at the rapids they were unloaded and carried round."]},
	{"file": "white_water.jpg", "title": "White water",
		"captions": ["West of the Mohawk's head a short carry leads to Wood Creek and the waters that run to Lake Ontario. Fort Stanwix was built there in 1758: whoever held the carry held the way west."]},
]

## The museum: the period's paintings.
const DIR := "res://assets/ui/paintings/"
const LIST := [
	{"file": "world/cole_hunters_return_1845.jpg", "title": "The Hunter's Return", "by": "Thomas Cole, 1845",
		"captions": ["A cabin in a clearing, the stumps still standing, and the hunters home with a deer: the life of the backcountry, painted eighty years on."]},
	{"file": "world/davies_oswego_1760.jpg", "title": "Oswego and Fort Ontario", "by": "Thomas Davies, 1760", "sheet": true,
		"captions": ["Drawn on the spot by a young artillery officer: General Amherst's army camped at Oswego in 1760, before it went down the St. Lawrence to Montreal and the war in the north was won."]},
	{"file": "world/davies_crown_point_1760.jpg", "title": "Crown Point", "by": "Thomas Davies, 1760", "sheet": true,
		"captions": ["The great new fort at Crown Point on Lake Champlain, drawn in 1760. Five years on, forts like it keep a few men each, and the traders and hunters come and go."]},
	{"file": "world/cole_sunrise_catskills_1826.jpg", "title": "Sunrise in the Catskills", "by": "Thomas Cole, 1826",
		"captions": ["The Catskills rise west of the Hudson, a few days from the manor woods: mist in the valleys, and not a road in them."]},
	{"file": "world/cole_tornado_1831.jpg", "title": "Tornado in an American Forest", "by": "Thomas Cole, 1831",
		"captions": ["A windfall can lay the old trees down for a mile, and the trails around it are lost for a generation."]},
	{"file": "world/cole_schroon_mountain_1838.jpg", "title": "Schroon Mountain, after a storm", "by": "Thomas Cole, 1838",
		"captions": ["North of the Mohawk the mountains go on unmapped by any settler; the hunters of the Six Nations know them."]},
	{"file": "world/durand_first_harvest_1855.jpg", "title": "The First Harvest in the Wilderness", "by": "Asher B. Durand, 1855",
		"captions": ["The first crop comes up among the stumps. Every farm on the Mohawk was begun this way, with an axe and a year of waiting."]},
]

static var _order: Array = []
static var _i := 0


## The game's pictures present (their files), each {file, title, captions, path}: behind the menu and on the
## loading screens.
static func all() -> Array:
	return _present(PICTURES, PICTURES_DIR)


static func legacy() -> Array:
	return _present(LEGACY_PICTURES, LEGACY_PICTURES_DIR)


## The museum's paintings present, in its order, each {file, title, by, captions, path; `sheet`: a drawing, shown
## whole}.
static func museum() -> Array:
	return _present(LIST, DIR)


static func _present(list: Array, dir: String) -> Array:
	var out: Array = []
	for e: Dictionary in list:
		var path := dir + String(e.file)
		if ResourceLoader.exists(path):
			var d := e.duplicate()
			d["path"] = path
			out.append(d)
	return out


## The next game picture in a shuffled round (no repeats until each has shown), with one of its captions as `caption`.
static func next() -> Dictionary:
	var a := all()
	if a.is_empty():
		return {}
	if _order.size() != a.size() or _i >= _order.size():
		_order = range(a.size())
		_order.shuffle()
		_i = 0
	var e: Dictionary = a[int(_order[_i])]
	_i += 1
	var caps: Array = e.captions
	e["caption"] = String(caps[randi() % caps.size()])
	return e


## The title as shown: "The Hunter's Return  ·  Thomas Cole, 1845" (the game's own: the title alone).
static func title_line(e: Dictionary) -> String:
	return String(e.get("title", "")) + (("  ·  " + String(e.by)) if e.has("by") else "")


## How a picture fills the screen: covering it, or a sheet shown whole.
static func stretch(e: Dictionary) -> TextureRect.StretchMode:
	return TextureRect.STRETCH_KEEP_ASPECT_CENTERED if bool(e.get("sheet", false)) or bool(e.get("whole", false)) \
			else TextureRect.STRETCH_KEEP_ASPECT_COVERED


static func texture(e: Dictionary) -> Texture2D:
	return load(String(e.path)) as Texture2D if not e.is_empty() else null
