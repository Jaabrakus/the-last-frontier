class_name LoadoutKeys
extends RefCounted
## The weapon key binding table of loadout_design.md 3.1 (data/loadout/loadout_items.json keys), as a
## pure decision: what a key press does given the loadout, the item in hand and each weapon's state.
## The later LoadoutController executes the result (holster -> junction -> draw, SlingRig handoffs).
##
##   var r := LoadoutKeys.resolve(&"weapon_3", loadout, "pistol_1", {"pistol_1": {"loaded": false}})
##   # {"do": "switch", "target": "pistol_2", "reason": "..."}
##
## `states`: item id -> {loaded: bool, stage: int (reload stages done), stages: int}. Missing = loaded.
## Results: do = "none" | "draw" (hands free -> target) | "switch" (holster the item in hand, draw target)
## | "sling_all" (hands free).

const CATEGORIES := {
	"weapon_1": ["bow"],
	"weapon_2": ["musket", "over_under"],
	"weapon_3": ["pistol"],
	"weapon_4": ["spear_pair"],
	"weapon_5": ["tomahawk"],
	"weapon_6": ["atlatl"],
}
const ORDER: Array[String] = ["weapon_1", "weapon_2", "weapon_3", "weapon_4", "weapon_5", "weapon_6"]


static func category_of_kind(kind: String) -> String:
	for c: String in CATEGORIES:
		if (CATEGORIES[c] as Array).has(kind):
			return c
	return ""


## Item ids carried in a category, in draw order.
static func carried(category: String, lo: Loadout) -> Array[String]:
	var out: Array[String] = []
	if category == "weapon_3":
		return lo.pistols()
	for k: String in CATEGORIES.get(category, []):
		for id in lo.ids_of_kind(k):
			out.append(id)
	return out


static func _loaded(id: String, states: Dictionary) -> bool:
	return bool(states.get(id, {}).get("loaded", true))


## The pistol drawn by key 3: the next LOADED pistol in draw order (cyclic after `after`); none loaded:
## the one with the most reload progress; "" when there is no other pistol to take.
static func next_pistol(lo: Loadout, states: Dictionary, after := "") -> String:
	var ps := lo.pistols()
	if ps.is_empty():
		return ""
	var start := ps.find(after) + 1 if after != "" else 0
	for i in ps.size():
		var id: String = ps[(start + i) % ps.size()]
		if id != after and _loaded(id, states):
			return id
	if after != "":
		return ""
	var best := ""
	var best_stage := -1
	for id in ps:
		var st := int(states.get(id, {}).get("stage", 0))
		if st > best_stage:
			best_stage = st
			best = id
	return best


static func resolve(action: StringName, lo: Loadout, in_hand: String, states := {}) -> Dictionary:
	var a := String(action)
	var hand_kind := String(lo.item(in_hand).get("kind", "")) if in_hand != "" else ""
	if a == "sling_all":
		if in_hand == "":
			return {"do": "none", "target": "", "reason": "hands already free"}
		return {"do": "sling_all", "target": "", "reason": "put every weapon on the body"}
	if a == "weapon_next" or a == "weapon_prev":
		var cats: Array[String] = []
		for c in ORDER:
			if not carried(c, lo).is_empty():
				cats.append(c)
		if cats.is_empty():
			return {"do": "none", "target": "", "reason": "nothing carried"}
		var cur := cats.find(category_of_kind(hand_kind))
		var step := 1 if a == "weapon_next" else -1
		var nxt: String = cats[(cur + step + cats.size()) % cats.size()] if cur >= 0 else cats[0 if step > 0 else cats.size() - 1]
		return resolve(StringName(nxt), lo, in_hand, states)
	if not CATEGORIES.has(a):
		return {"do": "none", "target": "", "reason": "not a weapon key"}
	var ids := carried(a, lo)
	if ids.is_empty():
		return {"do": "none", "target": "", "reason": "not carried"}
	var in_cat := category_of_kind(hand_kind) == a
	var target := ""
	if a == "weapon_3":
		if in_cat:
			if _loaded(in_hand, states):
				return {"do": "none", "target": "", "reason": "a loaded pistol is in hand"}
			target = next_pistol(lo, states, in_hand)
			if target == "":
				return {"do": "none", "target": "", "reason": "no other loaded pistol (R reloads this one)"}
			return {"do": "switch", "target": target, "reason": "holster the empty pistol, draw the next loaded one"}
		target = next_pistol(lo, states)
	elif a == "weapon_2" and in_cat:
		for id in ids:
			if id != in_hand:
				return {"do": "switch", "target": id, "reason": "the other long gun"}
		return {"do": "none", "target": "", "reason": "only one long gun carried"}
	elif in_cat:
		return {"do": "none", "target": "", "reason": "already in hand"}
	else:
		target = ids[0]
	if target == "":
		return {"do": "none", "target": "", "reason": "not carried"}
	return {"do": "draw" if in_hand == "" else "switch", "target": target,
			"reason": "draw %s" % target if in_hand == "" else "holster %s, draw %s" % [in_hand, target]}
