class_name GatherSkills
extends RefCounted
## The gathering skills: Woodcutting, Mining and Building (data/gathering/gathering.json), each a level from
## 0 to 100 like the survival skills (data/survival/skills.json), with the same tiers (Novice 0, Apprentice 20,
## Journeyman 40, Adept 60, Master 80) and the same diminishing growth (growth model v4's level curve: a gain
## is scaled by L(S) = 1 / (1 + (S / 45)^3), so the first levels come in a few trees and Master takes hundreds).
##
## A level speeds up the work and raises the yield, linearly from level 0 (x1) to 100 (the skill's at_100):
##   power(id)   work done per stroke (fewer strokes to fell a tree or break a stone)
##   speed(id)   the swing's play rate
##   yield_bonus(id)   0..1: how much of the extra yield the skill has earned (log quality, extra stone, flint)
##
##   var s := GatherSkills.new()
##   s.leveled.connect(func(id, lvl, tier): ...)   # every whole level; tier = {} or the tier just reached
##   s.award("woodcutting", 0.5)                   # the gain actually added (after L(S))
##   s.level("woodcutting")                        # 0..100 (whole levels)
##
## The player's skills are saved in user://frontier_gathering.json (`persist`); tests use a fresh instance.

signal leveled(id: String, level: int, tier: Dictionary)

const SAVE_PATH := "user://frontier_gathering.json"
const IDS: Array[String] = ["woodcutting", "mining", "building"]
const MAX_LEVEL := 100.0

var data: GatherData
## Skill points 0..100 per skill id (the level is the whole part).
var points := {}
## Save to SAVE_PATH on every whole level (the player's own skills).
var persist := false
## Skill gain times this (a boost: SurvivalBridge sets it while the player is well rested).
var award_mult := 1.0


func _init(p_data: GatherData = null) -> void:
	data = p_data if p_data else GatherData.get_default()
	for id in IDS:
		points[id] = 0.0


## The player's skills, loaded from SAVE_PATH (and saved there as they grow).
static func for_player() -> GatherSkills:
	var s := GatherSkills.new()
	s.load_saved()
	s.persist = true
	return s


func level(id: String) -> int:
	return int(floorf(float(points.get(id, 0.0))))


func points_of(id: String) -> float:
	return float(points.get(id, 0.0))


func tier(id: String) -> Dictionary:
	return data.tier_of(points_of(id))


## Adds `base` skill points scaled by the level curve; emits `leveled` for every whole level crossed (with
## the tier when a tier boundary is one of them). Returns the gain.
func award(id: String, base: float) -> float:
	if not points.has(id) or base <= 0.0:
		return 0.0
	var before := points_of(id)
	var gain := base * data.level_factor(before) * award_mult
	var after := minf(before + gain, MAX_LEVEL)
	points[id] = after
	var l0 := int(floorf(before))
	var l1 := int(floorf(after))
	if l1 > l0:
		for lvl in range(l0 + 1, l1 + 1):
			var t := data.tier_of(float(lvl))
			leveled.emit(id, lvl, t if float(t.min) == float(lvl) else {})
		if persist:
			save()
	return after - before


## Sets a skill's points directly (tests, a debug key); no signal.
func set_points(id: String, p: float) -> void:
	if points.has(id):
		points[id] = clampf(p, 0.0, MAX_LEVEL)


func _at(id: String, key: String, def: float) -> float:
	var s := data.skill(id)
	var at: float = float(s.get("at_100", {}).get(key, def))
	return lerpf(1.0, at, points_of(id) / MAX_LEVEL)


## Work per stroke, x1 at level 0.
func power(id: String) -> float:
	return _at(id, "power", 1.0)


## Swing play rate, x1 at level 0.
func speed(id: String) -> float:
	return _at(id, "speed", 1.0)


## 0 at level 0 to 1 at level 100 (skill's at_100.yield): the share of the extra yield earned.
func yield_bonus(id: String) -> float:
	var s := data.skill(id)
	return clampf(float(s.get("at_100", {}).get("yield", 1.0)) * points_of(id) / MAX_LEVEL, 0.0, 1.0)


## The experience a skill's event gives (gathering.json skills.<id>.xp), before the level curve.
func xp(id: String, event: String) -> float:
	return float(data.skill(id).get("xp", {}).get(event, 0.0))


## The tier line of a skill (gathering.json skills.<id>.tiers), "" when none.
func tier_text(id: String, tier_id: String) -> String:
	return String(data.skill(id).get("tiers", {}).get(tier_id, ""))


## "Woodcutting 23 (Apprentice)".
func describe(id: String) -> String:
	return "%s %d (%s)" % [data.skill(id).get("name", id.capitalize()), level(id), tier(id).name]


func to_dict() -> Dictionary:
	return {"version": 1, "points": points.duplicate()}


func from_dict(d: Dictionary) -> void:
	var p: Dictionary = d.get("points", {})
	for id in IDS:
		points[id] = clampf(float(p.get(id, 0.0)), 0.0, MAX_LEVEL)


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict(), " "))


func load_saved() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
	if d is Dictionary:
		from_dict(d)
