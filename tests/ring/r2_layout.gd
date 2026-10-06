extends RefCounted
## Round 2's key layout for the HUD and lessons tests and stills (skills_r2 spec §8.1 with the owner's answers of 2026-10-05:
## fire's Jab Embers, Breath on fire's 4 tap twice), put into SwayMoves' data when the data does not have it yet (no "guards"
## block: the kits' data task, KITS, not merged under this branch). With round 2's data in place it changes nothing.
##   const R2Layout := preload("res://tests/ring/r2_layout.gd"); R2Layout.apply() -> true when it put the layout in
## The moves the old data lacks (fire_kick, air_gust, air_wall) are stood in by copies of fire_arc, gust and air_shield under
## their round 2 names, for the words and the strip only (a test never casts them).

const ELEMENTS := {
	"earth": [["stone_form"], ["earth_shove"], ["earth_skate", "pillar"], ["earth_wall"], ["patch", "mend"]],
	"water": [["water_whip", "ice"], ["wave"], ["flow"], ["water_shield"], ["patch", "mend"]],
	"fire": [["fire_blast", "fire_arc"], ["fire_kick"], ["footwork", "fire_jets"], ["fire_wall", "fire_breath"], ["patch"]],
	"air": [["air_blast"], ["air_gust"], ["evade", "air_jump"], ["air_wall"], ["patch"]],
}
const GUARDS := {"earth": ["stone_catch", "catch"], "water": ["water_redirect", "redirect"], "fire": ["fire_parry", "parry"],
		"air": ["air_shield", "shield"]}
const JABS := {"earth": ["rock_jab", "pebbles"], "water": ["water_jet", "splash"], "fire": ["fire_jab", "embers"],
		"air": ["air_palm", "palm"]}
## id -> [label, [modes], {mode: label}] (spec §8.1's table).
const MOVES := {
	"stone_form": ["Stone", ["spike", "cannonball"], {"spike": "Spike", "cannonball": "Boulder"}],
	"earth_shove": ["Shove", ["push", "column"], {"push": "Shove", "column": "Column"}],
	"earth_skate": ["Burrow", ["burrow"], {"burrow": "Burrow"}],
	"pillar": ["Lift", ["self"], {"self": "Lift"}],
	"earth_wall": ["Wall", ["wall"], {"wall": "Wall"}],
	"stone_catch": ["Catch", ["catch"], {"catch": "Catch"}],
	"rock_jab": ["Pebbles", ["pebbles"], {"pebbles": "Pebbles"}],
	"water_whip": ["Lash", ["whip"], {"whip": "Lash"}],
	"ice": ["Spear", ["spear"], {"spear": "Spear"}],
	"wave": ["Wave", ["push", "spout"], {"push": "Wave", "spout": "Geyser"}],
	"flow": ["Skate", ["skate", "surf"], {"skate": "Skate", "surf": "Surf"}],
	"water_shield": ["Ice Wall", ["ice_wall"], {"ice_wall": "Ice Wall"}],
	"water_redirect": ["Turn", ["redirect"], {"redirect": "Turn"}],
	"water_jet": ["Splash", ["splash"], {"splash": "Splash"}],
	"fire_blast": ["Punch", ["punch"], {"punch": "Punch"}],
	"fire_arc": ["Lightning", ["lightning"], {"lightning": "Lightning"}],
	"fire_kick": ["Kick", ["kick", "high_kick"], {"kick": "Kick", "high_kick": "High Kick"}],
	"footwork": ["Step", ["step"], {"step": "Step"}],
	"fire_jets": ["Jets", ["jets"], {"jets": "Jets"}],
	"fire_wall": ["Fire Wall", ["wall"], {"wall": "Fire Wall"}],
	"fire_breath": ["Breath", ["breath"], {"breath": "Breath"}],
	"fire_parry": ["Parry", ["parry"], {"parry": "Parry"}],
	"fire_jab": ["Embers", ["embers"], {"embers": "Embers"}],
	"air_blast": ["Slice", ["slice", "ball"], {"slice": "Slice", "ball": "Wind Ball"}],
	"air_gust": ["Gust", ["gust", "pull"], {"gust": "Gust", "pull": "Pull"}],
	"evade": ["Slip", ["slip"], {"slip": "Slip"}],
	"air_jump": ["Leap", ["leap"], {"leap": "Leap"}],
	"air_wall": ["Wind Wall", ["wall"], {"wall": "Wind Wall"}],
	"air_shield": ["Wind Guard", ["shield"], {"shield": "Wind Guard"}],
	"air_palm": ["Palm", ["palm"], {"palm": "Palm"}],
	"patch": ["Patch", ["patch"], {"patch": "Patch"}],
}
## The stand-ins for the moves the old data lacks: new id -> the move copied.
const STAND_INS := {"fire_kick": "fire_arc", "air_gust": "gust", "air_wall": "air_shield"}


## Round 2's layout put into SwayMoves' data (true), or nothing done: the data has it already (false).
static func apply() -> bool:
	var d := SwayMoves.data()
	if d.has("guards"):
		return false
	var moves: Dictionary = d.get("moves", {})
	for id: String in STAND_INS:
		if not moves.has(id):
			moves[id] = (moves.get(STAND_INS[id], {}) as Dictionary).duplicate(true)
	for id: String in MOVES:
		var mv: Dictionary = moves.get(id, {})
		if mv.is_empty():
			continue
		var spec: Array = MOVES[id]
		var bend: Dictionary = mv.get("bend", {})
		var old_modes: Array = mv.get("modes", [])
		mv["label"] = spec[0]
		mv["modes"] = (spec[1] as Array).duplicate()
		mv["mode_labels"] = (spec[2] as Dictionary).duplicate()
		# (a mode the old move lacks borrows its first mode's numbers: the words and the strip only)
		for m: String in spec[1]:
			if not bend.has(m) and not old_modes.is_empty() and bend.has(String(old_modes[0])):
				bend[m] = (bend[String(old_modes[0])] as Dictionary).duplicate(true)
	d["elements"] = ELEMENTS.duplicate(true)
	d["guards"] = GUARDS.duplicate(true)
	d["jabs"] = JABS.duplicate(true)
	return true
