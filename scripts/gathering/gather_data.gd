class_name GatherData
extends RefCounted
## Read-only access to the gathering design data (loaded once, cached):
##
##   data/gathering/gathering.json   skills (effects, experience, tier lines), tools, items, the carry point,
##                                   the stroke clips, felling / sapling / rock numbers
##   data/survival/skills.json       the survival tiers (Novice 0 ... Master 80) and growth model v4's level
##                                   curve L(S) = 1 / (1 + (S / s50)^b), reused so the two skill systems read alike
##
##   var d := GatherData.get_default()
##   d.skill("woodcutting").name            # "Woodcutting"
##   d.felling.strokes_ref                  # 5.0
##   d.tier_of(23.0)                        # {"id": "apprentice", "name": "Apprentice", "min": 20}

const PATH := "res://data/gathering/gathering.json"
const SURVIVAL_SKILLS_PATH := "res://data/survival/skills.json"

static var _default: GatherData

var raw := {}
var skills := {}
var tools := {}
## Stone tools that stand in for a steel one (the start with nothing): {stone_axe: {power, stands_for, ...}}.
var stone_tools := {}
var items := {}
var carry := {}
var clips := {}
var felling := {}
var species := {}
var saplings := {}
var rocks := {}
## Survival tiers, ascending by min: [{id, name, min}].
var tiers: Array = []
## Survival growth model v4 level curve.
var s50 := 45.0
var curve_b := 3.0


static func get_default() -> GatherData:
	if _default == null:
		_default = GatherData.new()
		_default.load_all()
	return _default


func load_all() -> void:
	raw = _read(PATH)
	skills = raw.get("skills", {})
	tools = raw.get("tools", {})
	stone_tools = raw.get("stone_tools", {})
	items = raw.get("items", {})
	carry = raw.get("carry", {})
	clips = raw.get("clips", {})
	felling = raw.get("felling", {})
	species = raw.get("species", {})
	saplings = raw.get("saplings", {})
	rocks = raw.get("rocks", {})
	var sv := _read(SURVIVAL_SKILLS_PATH)
	tiers = sv.get("tiers", [{"id": "novice", "name": "Novice", "min": 0}])
	tiers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.min) < float(b.min))
	var lc: Dictionary = sv.get("growth_model", {}).get("level_curve", {})
	s50 = float(lc.get("s50", s50))
	curve_b = float(lc.get("b", curve_b))


func skill(id: String) -> Dictionary:
	return skills.get(id, {})


func tool(kind: String) -> Dictionary:
	return tools.get(kind, {})


func is_tool(kind: String) -> bool:
	return tools.has(kind)


## Display name of a tool or gathered item kind ("" when neither).
func name_of(kind: String) -> String:
	if tools.has(kind):
		return String(tools[kind].get("name", kind))
	if items.has(kind):
		return String(items[kind].get("name", kind))
	if stone_tools.has(kind):
		return String(stone_tools[kind].get("name", kind))
	return ""


## The survival tier a skill level is in: {id, name, min}.
func tier_of(level: float) -> Dictionary:
	var best: Dictionary = tiers[0]
	for t: Dictionary in tiers:
		if level >= float(t.min):
			best = t
	return best


## Growth model v4's level curve: the share of a gain a skill at `level` still takes (1 at 0, 0.5 at s50).
func level_factor(level: float) -> float:
	return 1.0 / (1.0 + pow(maxf(level, 0.0) / s50, curve_b))


static func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GatherData: cannot read %s" % path)
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}
