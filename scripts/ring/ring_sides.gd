class_name RingSides
extends RefCounted
## Side colours, like team jerseys (Tidebreak round 4, HUD; the owner's FEEL list: "side colours in mirror matches"; critic_r2
## backlog item 5: "in an earth mirror, at 20 m, you can't tell who is who without a cue, and cues are banned. Sports use
## jerseys"). data/ring/sides.json holds every number and every colour.
##   mirror()               an element is worn on both sides of the ring match now
##   away(team, el)         team 1 wears its element's away dress: el (or, "" given, any of its elements) is also on team 0
##                          (sides.json always: every ring match). The player's side, team 0, is ALWAYS home.
##   colour(team, el)       the plates' side colour: the element's home colour, its away colour for a side wearing away
##   home_colour(el)        the element's home colour (the strip's readied picture: the player's side is always home)
##   dress(team, el)        the ring dress (slot -> {id, colors}) a fighter of `team` in `el` wears: ring_team_a's
##                          element_dress, the away colours merged over it when away(team, el); NpcSquad.element_look takes it
## Only cloth colours change: the same garments of the catalog's set ring, nothing drawn on anyone, nothing that follows or
## points at a body (no target cues of any kind). The player's own dress (PlayerAppearance.ring_dress) never reads this.
## Outside a ring match (the duel, the open world: no RingMode) every side is home and nothing changes.
## The sides' elements: the ring match's (RingMode: the player's element and the foe's, and every competitor on the rules'
## books), or sides_override (tests and stills: [[team 0's elements], [team 1's]]).

const DATA_PATH := "res://data/ring/sides.json"
## The ring's factions by team (RingMode.FACTIONS).
const FACTIONS := ["ring_team_a", "ring_team_b"]
## The faction whose element_dress is every side's home dress (the player's: PlayerAppearance.ARENA_FACTION).
const HOME_FACTION := "ring_team_a"

static var _cfg := {}
## Tests and stills: [[team 0's elements], [team 1's]] in place of the match's; null reads the match.
static var sides_override: Variant = null
## Tests and stills: true / false in place of sides.json always; null reads it.
static var always_override: Variant = null


## sides.json (read once).
static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_cfg = d if d is Dictionary else {"elements": {}}
	return _cfg


static func _el_cfg(el: String) -> Dictionary:
	var e: Variant = (cfg().get("elements", {}) as Dictionary).get(el, {})
	return e if e is Dictionary else {}


static func always() -> bool:
	if always_override != null:
		return bool(always_override)
	return bool(cfg().get("always", false))


## The team a ring faction fights for (0 ring_team_a, 1 ring_team_b; -1 another faction: not a ring side).
static func team_of_faction(faction: String) -> int:
	return FACTIONS.find(faction)


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## The ring match now (null: the duel, the open world, a menu).
static func match_node() -> RingMode:
	var t := _tree()
	return RingMode.find(t) if t != null else null


## The elements worn on `team` now ([] outside a ring match).
static func elements(team: int) -> Array:
	if sides_override is Array and (sides_override as Array).size() >= 2:
		return ((sides_override as Array)[clampi(team, 0, 1)] as Array).duplicate()
	var m := match_node()
	if m == null or team < 0 or team > 1:
		return []
	var out: Array = []
	var own := m.element if team == 0 else m.foe_element
	if own in Bending.ELEMENTS:
		out.append(own)
	if m.rules != null:
		for b: Variant in m.rules.sides[team]:
			# (the player counts by the match's element, as the foe was dressed for it: a change of element in the middle of a
			# match neither redresses the foe nor turns its plate)
			if b is Node3D and is_instance_valid(b) and b != m.player:
				var el := _element_of(b as Node3D)
				if el in Bending.ELEMENTS and not el in out:
					out.append(el)
	return out


static func _element_of(b: Node3D) -> String:
	var bd := Bending.of(b)
	if bd != null and bd.element != "":
		return bd.element
	return String(b.get(&"element")) if &"element" in b else ""


## An element is worn on both sides of the ring match now.
static func mirror() -> bool:
	var a := elements(0)
	for el: Variant in elements(1):
		if el in a:
			return true
	return false


## Team `team` wears the away dress of `el` (of any of its elements when ""): team 1 only, in a ring match, when that element is
## also worn on team 0 (or sides.json always). The player's side is always home.
static func away(team: int, el := "") -> bool:
	if team != 1:
		return false
	if sides_override == null and match_node() == null:
		return false                         # (no ring match: the duel and the open world are untouched)
	if always():
		return true
	var mine := elements(0)
	if el != "":
		return el in mine
	for e: Variant in elements(1):
		if e in mine:
			return true
	return false


## The plates' side colour of `team` (of its fighter in `el`; "" its first element): the element's home colour, or its away
## colour when that side wears away.
static func colour(team: int, el := "") -> Color:
	var e := el
	if e == "":
		var es := elements(team)
		e = String(es[0]) if not es.is_empty() else ""
	var c := _el_cfg(e)
	var key := "away" if away(team, e) else "home"
	var a: Variant = c.get(key, c.get("home"))
	if a is Array and (a as Array).size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return Color(0.98, 0.8, 0.42) if team == 0 else Color(0.55, 0.78, 1.0)


## Element `el`'s home colour (the strip's readied picture: the player's side is always home; a plate of a home side).
static func home_colour(el: String) -> Color:
	var a: Variant = _el_cfg(el).get("home")
	if a is Array and (a as Array).size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return Color(0.93, 0.74, 0.36)


## The ring dress of a fighter of `team` in `el` (slot -> {id, colors}; {} none): ring_team_a's element_dress (every side's home
## dress), with sides.json's away colours merged over each slot's when away(team, el).
static func dress(team: int, el: String) -> Dictionary:
	var home: Variant = (NpcFactions.get_faction(HOME_FACTION).get("element_dress", {}) as Dictionary).get(el)
	if not (home is Dictionary):
		return {}
	var out: Dictionary = (home as Dictionary).duplicate(true)
	if away(team, el):
		var ad: Variant = _el_cfg(el).get("away_dress", {})
		for slot: String in (ad as Dictionary if ad is Dictionary else {}):
			var d: Variant = out.get(slot)
			if d is Dictionary and (d as Dictionary).has("id") and String((d as Dictionary).id) != "-":
				var cols: Dictionary = ((d as Dictionary).get("colors", {}) as Dictionary).duplicate()
				for k: Variant in ((ad as Dictionary)[slot] as Dictionary):
					cols[String(k)] = (ad as Dictionary)[slot][k]
				(d as Dictionary)["colors"] = cols
	return out


## The dress NpcSquad.element_look puts on a fighter of `faction` in `el` when it is a ring side wearing away ({} otherwise:
## the faction's own element_dress stands, exactly as before).
static func away_dress_for(faction: String, el: String) -> Dictionary:
	var t := team_of_faction(faction)
	if t < 0 or not away(t, el):
		return {}
	return dress(t, el)
