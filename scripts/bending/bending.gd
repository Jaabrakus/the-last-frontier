class_name Bending
extends Node
## The bender's loadout (docs/bending_design.md; data/sway/moves.json "elements"; the user,
## 2026-10-04: "users create a char or a loadout where they are one of the four elements ... everyone gets the same 4",
## "have 1 and the user can toggle between the 1s and then roll the wheel to change that spell"):
##   the keys     each element has five keys: 1-4 hold two skills (the same key again switches: partner_of), 5 Mend / Patch;
##                the wheel steps through the readied skill's variations (its modes: SwayCaster.step_mode)
##   water near   near_water(): the river, a wall of water or a bubble, a pool (the group POOLS) within NEAR_WATER_M (the
##                water meter was retired in the 2026-10-06 cleanup, owner answer O7: lock time is the only limiter)
## Bending.ELEMENTS, keys(element) -> [[a, b], ...], bar(element) -> the first skill of each key, partner_of(id),
## element_of(id). On any body that bends (Bending.of: the player, a bot: its element).
## ROUND 2 (skills_r2 spec §2, §8, §10; the owner's answers 2026-10-05): a key is [id] (one move, or one move with two modes)
## or [id, id] (two moves, one mode each). first_of(key) is what a tap readies (the key's first move at its first mode),
## other_move(key, id, mode) what a double tap or a wheel step turns it to (the mode flipped on a one-id key, the partner
## on a two-id key; nothing on a single-mode one-id key: the wall's key, fire and air's 5). jab(el) the left button's move
## (moves.json "jabs"), guard(el) E's (moves.json "guards"), passive(el) the element's one passive ("passives"), rules() the
## shared cast and guard numbers ("guard_rules"), stones() the loose stones' ("stones"). Every block has its safe default here (JABS, GUARDS, PASSIVES, RULES, STONES), so the code runs
## on today's data and on KITS' alike; set_test_data(d) stands a block (or the key layout, "elements") in for the tests.

const ELEMENTS := ["earth", "water", "fire", "air"]
const NODE_NAME := &"Bending"
## Places that give a waterbender water (Node3D; the arena's pools).
const POOLS := &"bend_pools"
## How near water must be for near_water() (m; a pool with its own meta reach_m uses that).
const NEAR_WATER_M := 4.0
## The left button's jab by element ([move, mode]) when moves.json has no "jabs". Fire's is Embers (the owner's answer,
## 2026-10-05: "keep them all"; a spray of small bolts from the fist in place of the 3 m fist flame).
const JABS := {"earth": ["rock_jab", "pebbles"], "water": ["water_jet", "splash"], "fire": ["fire_jab", "embers"],
		"air": ["air_palm", "palm"]}
## E's guard by element ([move, mode]) when moves.json has no "guards".
const GUARDS := {"earth": ["stone_catch", "catch"], "water": ["water_redirect", "redirect"], "fire": ["fire_parry", "parry"],
		"air": ["air_shield", "shield"]}
## Each element's passive (spec §2.4) when moves.json has no "passives" (an entry there is merged over its element's):
##   earth  rooted        still_mps (under it: standing), fill_mult (the locks fill faster), knock_mult (knock taken)
##   water  flowing       steer_dps, steer_max_deg, steer_s (a water bolt bends toward the aim after it leaves)
##   fire   footwork      moving_mult (the locks fill on the move at this)
##   air    carried_wind  knock_mult on `carry` specs within after_s of a dash's end (a Slip, a Leap, a Jets landing) or of
##                        a near miss within near_m during a Slip
const PASSIVES := {
	"earth": {"id": "rooted", "label": "Rooted", "still_mps": 0.3, "fill_mult": 1.2, "knock_mult": 0.85},
	"water": {"id": "flowing", "label": "Flowing", "steer_dps": 45.0, "steer_max_deg": 15.0, "steer_s": 0.25},
	"fire": {"id": "footwork", "label": "Footwork", "moving_mult": 1.0},
	"air": {"id": "carried_wind", "label": "Carried wind", "knock_mult": 1.15, "after_s": 0.8, "near_m": 1.2},
}
## The shared cast and guard numbers (moves.json "guard_rules" over these; spec §8.1).
const RULES := {"perfect_s": 0.3, "late_mult": 0.5, "whiff_lock_s": 0.5, "whiff_s": 1.5, "return_lock_s": 0.35,
		"perfect_return_lock_s": 0.1, "perfect_mult": 1.2, "rally_step": 0.1, "rally_clean_step": 0.2, "rally_max": 1.6,
		"grow_after_s": 0.45, "sputter_s": 0.7, "click_s": 0.2, "click_queue": false, "double_tap_s": 0.3, "switch_hold_s": 0.2,
		"hit_setback_min_s": 0.25, "hold_drop_s": 0.0, "quick_reset_s": 0.5, "jab_max_m": 10.0}
## The loose stones' numbers (moves.json "stones" over these).
const STONES := {"loose_max": 3, "shove_loose_m": 6.0}

## Tests only: blocks of moves.json stood in (set_test_data): "elements", "jabs", "guards", "passives", "guard_rules",
## "stones". {} none.
static var _test := {}
## A block the data does not have (one dictionary, never written to: rules() can tell nothing changed).
static var _none := {}
## rules() as made from the guard_rules block `_rules_of` (read every frame by the locks and guards: made again only when
## that block is another one, a test's stand-in or a reload).
static var _rules := {}
static var _rules_of: Dictionary = {}

## The body it is on (the player, a bot; the name kept from when only the player bent).
var player: Node3D
## Its element ("earth", "water", "fire", "air"; "" not chosen): set by the mode that gives it one (the duel, the ring).
var element := ""


static func data() -> Dictionary:
	return block("elements")


## A top-level block of moves.json ({} none): the tests' stand-in first (set_test_data).
static func block(name: String) -> Dictionary:
	if _test.has(name):
		return _test[name]
	var v: Variant = SwayMoves.data().get(name)
	return v if v is Dictionary else _none


## Tests only: `d`'s blocks stand in for moves.json's ("elements" the key layout, "guard_rules", "jabs", ...); {} lets
## them all go.
static func set_test_data(d: Dictionary) -> void:
	_test = d.duplicate(true)


static func keys(element: String) -> Array:
	return data().get(element, [])


## The key (0-based) holding move `id` for `element` (-1 none).
static func key_of(element: String, id: String) -> int:
	var ks := keys(element)
	for i in ks.size():
		if id in (ks[i] as Array):
			return i
	return -1


## What a tap on `key` readies: {id, mode} (its first move at its first mode; {} none).
static func first_of(key: Array) -> Dictionary:
	if key.is_empty():
		return {}
	var id := String(key[0])
	var ms := SwayCaster.modes_of(id)
	return {"id": id, "mode": String(ms[0]) if not ms.is_empty() else ""}


## The key's other move from `id` at `mode` (a double tap, a wheel step; spec §2.2): a two-id key its partner at its first
## mode, a one-id key its other mode (the first two of its modes); {} when there is none (a single-mode one-id key).
static func other_move(key: Array, id: String, mode: String) -> Dictionary:
	if key.size() >= 2:
		var other := String(key[1]) if String(key[0]) == id else String(key[0])
		var ms := SwayCaster.modes_of(other)
		return {"id": other, "mode": String(ms[0]) if not ms.is_empty() else ""}
	if key.size() == 1:
		var ms := SwayCaster.modes_of(String(key[0]))
		if ms.size() < 2:
			return {}
		var nxt := String(ms[1]) if mode == String(ms[0]) else String(ms[0])
		return {"id": String(key[0]), "mode": nxt}
	return {}


## The left button's jab for `element`: {id, mode} (moves.json "jabs", else JABS; {} none).
static func jab(element: String) -> Dictionary:
	return _pair(block("jabs").get(element, JABS.get(element, [])))


## E's guard for `element`: {id, mode} (moves.json "guards", else GUARDS; {} none).
static func guard(element: String) -> Dictionary:
	return _pair(block("guards").get(element, GUARDS.get(element, [])))


## Whether move `id` is some element's guard (E's).
static func is_guard(id: String) -> bool:
	for e: String in ELEMENTS:
		if String(guard(e).get("id", "")) == id:
			return true
	return false


## `element`'s passive (PASSIVES' entry, moves.json "passives" merged over it; {} none).
static func passive(element: String) -> Dictionary:
	var out: Dictionary = (PASSIVES.get(element, {}) as Dictionary).duplicate()
	var have: Variant = block("passives").get(element)
	if have is Dictionary:
		out.merge(have as Dictionary, true)
	return out


## The shared cast and guard numbers (RULES, moves.json "guard_rules" over them).
static func rules() -> Dictionary:
	var have := block("guard_rules")
	if _rules.is_empty() or not is_same(have, _rules_of):
		_rules = RULES.duplicate()
		_rules.merge(have, true)
		_rules_of = have
	return _rules


## One of rules() (`def` when neither has it).
static func rule(key: String, def := 0.0) -> float:
	return float(rules().get(key, def))


## The loose stones' numbers (STONES, moves.json "stones" over them).
static func stones() -> Dictionary:
	var out := STONES.duplicate()
	out.merge(block("stones"), true)
	return out


static func _pair(v: Variant) -> Dictionary:
	if v is Array and (v as Array).size() >= 1:
		var a := v as Array
		var id := String(a[0])
		var ms := SwayCaster.modes_of(id)
		var md := String(a[1]) if a.size() >= 2 else (String(ms[0]) if not ms.is_empty() else "")
		return {"id": id, "mode": md}
	if v is Dictionary and (v as Dictionary).has("id"):
		return {"id": String(v.id), "mode": String((v as Dictionary).get("mode", ""))}
	return {}


## The first skill of each key: the bar an element starts with.
static func bar(element: String) -> Array:
	var out: Array = []
	for k in keys(element):
		out.append(String((k as Array)[0]))
	return out


## The other skill on `id`'s key ("" none).
static func partner_of(id: String) -> String:
	for e: String in ELEMENTS:
		for k in keys(e):
			var pair := k as Array
			if pair.size() == 2 and String(pair[0]) == id:
				return String(pair[1])
			if pair.size() == 2 and String(pair[1]) == id:
				return String(pair[0])
	return ""


static func element_of(id: String) -> String:
	return String(SwayMoves.move(id).get("element", ""))


static func of(p: Node3D) -> Bending:
	if p == null or not is_instance_valid(p):
		return null
	var b := p.get_node_or_null(NodePath(NODE_NAME)) as Bending
	if b == null:
		b = Bending.new()
		b.name = NODE_NAME
		b.player = p
		p.add_child(b)
	return b


## Water within reach of the body it is on: the river, a wall of water or a bubble, a pool (within its meta reach_m when it
## has one, else NEAR_WATER_M + 2).
func near_water() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var r := NEAR_WATER_M
	var p := player.global_position
	if WorldRiver.has_water():
		for o: Vector3 in [Vector3.ZERO, Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]:
			if WorldRiver.depth_at(p + o) > 0.0:
				return true
	for n in get_tree().get_nodes_in_group(POOLS):
		# (a pool with its own reach, meta reach_m: the ring's grates, Tidebreak's rules.json grate_reach_m)
		var reach := float(n.get_meta(&"reach_m")) if n.has_meta(&"reach_m") else r + 2.0
		if (n as Node3D).global_position.distance_to(p) <= reach:
			return true
	for z in get_tree().get_nodes_in_group(BendZone.GROUP):
		if (z as BendZone).kind in ["water_wall", "bubble"] and (z as BendZone).global_position.distance_to(p) <= r + 2.0:
			return true
	return false
