class_name StationPractice
extends RefCounted
## Quality from practice at the camp stations (user 2026-09-29: "most items can be obtained from npcs via the knowledge
## journal or self made but will take continued makes to make better quality"). Every make of a station recipe is
## counted in the survival core's learning record "make.<id>" (per player, saved with the core: SurvivalLearning), and
## what comes out is made at the standard the makes before it earned: plain, good after 3 makes, fine after 8,
## masterwork after 20. The standard rides on the pack stack's state ({"standard": ...}; a stack keeps its best) and on
## the worn loadout item's state, and scales what the thing does (mult(); PlayerGrip: the climbing gear).
##
##   var st := StationPractice.note_make(core, "stone_axe")     # "plain" the first time
##   StationPractice.stamp(inv.pack, "stone_axe", st)

const STANDARDS := ["plain", "good", "fine", "masterwork"]
## Makes before a standard is reached (the same order).
const AFTER := [0, 3, 8, 20]
## What a standard does to the thing's effect (a tool's bite, the climbing gear's easing of the grip).
const MULT := {"plain": 1.0, "good": 1.1, "fine": 1.2, "masterwork": 1.35}


static func kid(id: String) -> String:
	return "make." + id


## How many times `id` has been made.
static func makes(core: SurvivalCore, id: String) -> int:
	if core == null:
		return 0
	var rec: Dictionary = SurvivalLearning.record(core, kid(id))
	return int(SurvivalUtil.num(rec.get("successes"), 0.0))


static func standard_at(n: int) -> String:
	var st := "plain"
	for i in STANDARDS.size():
		if n >= int(AFTER[i]):
			st = String(STANDARDS[i])
	return st


## Counts one make of `id` and returns the standard it came out at (earned by the makes before it). No core: "plain".
static func note_make(core: SurvivalCore, id: String) -> String:
	if core == null:
		return "plain"
	var st := standard_at(makes(core, id))
	var k := kid(id)
	if SurvivalLearning.state_of(core, k) == "unknown":
		SurvivalLearning.set_state(core, k, "known", "practice", "", true)
	SurvivalLearning.record_result(core, k, "success", st)
	return st


static func rank(st: String) -> int:
	return STANDARDS.find(st)


static func mult(st: String) -> float:
	return float(MULT.get(st, 1.0))


## The standard in an item's state ("plain" when it has none).
static func of_state(state: Variant) -> String:
	return String((state as Dictionary).get("standard", "plain")) if state is Dictionary else "plain"


## Stamps `st` on the pack's `kind` stack (a stack keeps its best standard).
static func stamp(pack: Array, kind: String, st: String) -> void:
	for e: Dictionary in pack:
		if String(e.get("kind", "")) == kind:
			var s: Dictionary = e.get("state", {})
			if rank(st) > rank(of_state(s)):
				s["standard"] = st
			e["state"] = s
			return


## A multiplier-less effect scaled by a standard: `base` (< 1, e.g. a drain factor 0.85) moved further from 1 by the
## standard (masterwork: the easing 1.35 times as large).
static func eased(base: float, st: String) -> float:
	return clampf(1.0 - (1.0 - base) * mult(st), 0.05, 1.0)


## The article and adjective for a made thing: "a fine stone axe", "a stone axe" (plain).
static func named(st: String, nm: String) -> String:
	var t := nm if st == "plain" else "%s %s" % [st, nm]
	return ("an " if t.substr(0, 1) in ["a", "e", "i", "o", "u"] else "a ") + t
