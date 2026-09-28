class_name FishCatch
extends RefCounted
## A fish off the water into the pack (user 2026-09-28: "for fishing have all those options": the rod and line, the
## spear, the weir). Each species is its own pack kind, by the pound (data/survival/game_items.json: a unit is a pound
## of fresh fish, item.food.fish_raw): a landed fish gives its weight in pounds, at least one. They roast on a campfire
## into roast fish (CampCooking), a pound at a time.
##   to_pack(player, {species, name, length, lb}) -> {kind, units, text}   the pack, and a notice (the HUD's toast)

const SPECIES := ["brook_trout", "salmon", "sucker", "perch", "pike", "eel", "bullhead", "sturgeon", "pickerel"]


static func is_fish(kind: String) -> bool:
	return kind in SPECIES


## Pack units a fish of `lb` pounds gives.
static func units(lb: float) -> int:
	return maxi(1, roundi(lb))


static func to_pack(p: FrontierPlayer, info: Dictionary) -> Dictionary:
	var kind := String(info.get("species", ""))
	if not is_fish(kind) or p == null:
		return {}
	var n := units(float(info.get("lb", 1.0)))
	var inv := InventoryState.from_player(p)
	inv.add(kind, n)
	p.inventory_pack = inv.pack.duplicate(true)
	var nm := String(info.get("name", kind.replace("_", " ")))
	var text := "%s%s: %d cm, %.1f lb" % [nm.substr(0, 1).to_upper(), nm.substr(1), roundi(float(info.get("length", 0.3)) * 100.0), float(info.get("lb", 1.0))]
	var h: Variant = p.get("hud")
	if h != null and is_instance_valid(h) and (h as Node).has_method("toast"):
		(h as Node).call("toast", text, kind)
	return {"kind": kind, "units": n, "text": text}
