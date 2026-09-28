class_name Loadout
extends Resource
## What the player carries and where: the worn carry gear, one entry per carried item with its home
## point(s) on the body, counts, per-instance state (each pistol's loaded state), and the item in hand.
## Pure data; the rules are LoadoutRules, the visuals SlingRig. Saved with the character next to the
## customizer's appearance (to_dict / from_dict).
##
##   var lo := Loadout.from_preset("musket_bow")          # data/loadout/loadout_presets.json
##   lo.pistols()                                          # ["pistol_1"] (draw order)
##   lo.item("pistol_1")                                   # {"id", "kind", "points": ["R_hip"], "count", "state"}
##   LoadoutRules.validate(lo)                             # [] when legal
##
## Item ids: the kind for single items ("musket", "bow", "quiver", "spear_pair", "dart_bundle", "atlatl",
## "tomahawk", "over_under"); pistols are separate instances "pistol_1".."pistol_4", numbered in draw order
## (R_hip, back_right, chest_R, L_hip, chest_L). Tomahawks are one item with count <= 2 whose points are
## ["back"] or ["back", "back_2"] (the second stacks on the first). The item in hand still has its home
## point ("the item in hand counts as carried at its home point", loadout_design.md 1.6).
##
## Gear ids are the loadout gear of carry_gear.json ("legacy_baked_belt", "sash_fingerwoven",
## "pistol_sling", "horn_strap", "back_slings", ...); LoadoutRules.gear_from_appearance() maps the
## customizer's accessories to them.

@export var preset_id := ""
@export var display_name := ""
@export var gear: PackedStringArray = PackedStringArray()
## ew_sash worn over the shoulder as a baldric (adds L_hip) instead of as a waist sash.
@export var shoulder_ew_sash := false
## [{id, kind, points: Array[String], count: int, state: Dictionary}]
@export var items: Array[Dictionary] = []
## Item id in the hands, "" = hands free.
@export var in_hand := ""
## body_fit.json outfit key of the outermost garment ("" = the legacy coat the placements were measured on).
@export var outfit_bulk := ""


static func from_preset(id: String, data: LoadoutData = null) -> Loadout:
	var d := data if data else LoadoutData.get_default()
	var pr := d.preset(id)
	var lo := Loadout.new()
	if pr.is_empty():
		push_warning("Loadout: unknown preset " + id)
		return lo
	lo.preset_id = id
	lo.display_name = String(pr.get("name", id))
	lo.gear = PackedStringArray(pr.get("gear", []))
	if not lo.gear.has("back_slings"):
		lo.gear.append("back_slings")
	var its: Dictionary = pr.get("items", {})
	# pistols in draw order so their ids follow it
	var pts: Array = its.keys()
	pts.sort_custom(func(a, b) -> bool: return _order(String(a)) < _order(String(b)))
	for p: String in pts:
		var v: Variant = its[p]
		var k := kind_of(v)
		var extra := {}
		if v is Dictionary:
			extra = (v as Dictionary).duplicate()
			extra.erase("kind")
		if k == "tomahawk" and lo.has_kind("tomahawk"):
			var t := lo.first_of_kind("tomahawk")
			(t.points as Array).append(p)
			t.count = int(t.count) + 1
			continue
		lo.add_item(k, [p], int(extra.get("count", 1 if k != "quiver" else 1)), _state_for(k, extra))
	var ih := String(pr.get("in_hand", ""))
	lo.in_hand = lo.resolve_hand(ih)
	return lo


static func _order(p: String) -> int:
	var i := LoadoutData.PISTOL_ORDER.find(p)
	return i if i >= 0 else 100


static func _state_for(k: String, extra: Dictionary) -> Dictionary:
	match k:
		"pistol", "musket", "over_under":
			return {"loaded": bool(extra.get("loaded", true)), "stage": int(extra.get("stage", 0))}
		"quiver":
			return {"arrows": int(extra.get("arrows", 24))}
	return {}


## Kind name of a preset value ("pistol", {"kind": "spear_pair", ...}, "pistol@R_hip").
static func kind_of(v: Variant) -> String:
	if v is Dictionary:
		return String((v as Dictionary).get("kind", ""))
	return String(v).get_slice("@", 0)


## Item id for a preset's in_hand value: "musket", "bow", "pistol@R_hip", "pistol" (first in draw order).
func resolve_hand(v: String) -> String:
	if v == "":
		return ""
	var k := v.get_slice("@", 0)
	var p := v.get_slice("@", 1) if "@" in v else ""
	for it: Dictionary in items:
		if String(it.kind) == k and (p == "" or (it.points as Array).has(p)):
			return String(it.id)
	return ""


# --- queries ----------------------------------------------------------------------------------

func item(id: String) -> Dictionary:
	for it: Dictionary in items:
		if String(it.id) == id:
			return it
	return {}


func has_item(id: String) -> bool:
	return not item(id).is_empty()


func has_kind(k: String) -> bool:
	return not first_of_kind(k).is_empty()


func first_of_kind(k: String) -> Dictionary:
	for it: Dictionary in items:
		if String(it.kind) == k:
			return it
	return {}


func ids_of_kind(k: String) -> Array[String]:
	var out: Array[String] = []
	for it: Dictionary in items:
		if String(it.kind) == k:
			out.append(String(it.id))
	return out


## Pistol ids in draw order.
func pistols() -> Array[String]:
	var ps: Array = []
	for it: Dictionary in items:
		if String(it.kind) == "pistol":
			ps.append(it)
	ps.sort_custom(func(a, b) -> bool: return _order(String(a.points[0])) < _order(String(b.points[0])))
	var out: Array[String] = []
	for it: Dictionary in ps:
		out.append(String(it.id))
	return out


## The item's home point (its first point).
func point_of(id: String) -> String:
	var it := item(id)
	if it.is_empty() or (it.points as Array).is_empty():
		return ""
	return String(it.points[0])


## point -> item id for every occupied point.
func occupancy() -> Dictionary:
	var occ := {}
	for it: Dictionary in items:
		for p: String in it.points:
			occ[p] = String(it.id)
	return occ


## point -> kind for every occupied point (the form the gear rules use).
func point_kinds() -> Dictionary:
	var occ := {}
	for it: Dictionary in items:
		for p: String in it.points:
			occ[p] = String(it.kind)
	return occ


func long_items() -> Array[String]:
	var out: Array[String] = []
	for it: Dictionary in items:
		if LoadoutData.LONG_SLOTS.has(String(it.points[0])):
			out.append(String(it.id))
	return out


func count_of(id: String) -> int:
	return int(item(id).get("count", 0))


func state_of(id: String) -> Dictionary:
	return item(id).get("state", {})


# --- edits (LoadoutRules decides whether an edit is legal) ------------------------------------

## Adds an item and returns its id. Pistols are renumbered in draw order afterwards.
func add_item(k: String, points: Array, count := 1, state := {}) -> String:
	var id := k
	if k == "pistol":
		id = "pistol_%d" % (ids_of_kind("pistol").size() + 1)
	elif has_kind(k):
		var n := 2
		while has_item("%s_%d" % [k, n]):
			n += 1
		id = "%s_%d" % [k, n]
	var pts: Array[String] = []
	for p in points:
		pts.append(String(p))
	items.append({"id": id, "kind": k, "points": pts, "count": count, "state": state.duplicate(true)})
	if k == "pistol":
		id = _renumber_pistols(id)
	emit_changed()
	return id


func remove_item(id: String) -> Dictionary:
	for i in items.size():
		if String(items[i].id) == id:
			var it: Dictionary = items[i]
			items.remove_at(i)
			if in_hand == id:
				in_hand = ""
			if String(it.kind) == "pistol":
				_renumber_pistols("")
			emit_changed()
			return it
	return {}


func set_count(id: String, n: int) -> void:
	var it := item(id)
	if not it.is_empty():
		it.count = n
		emit_changed()


func set_state(id: String, key: String, value: Variant) -> void:
	var it := item(id)
	if not it.is_empty():
		(it.state as Dictionary)[key] = value
		emit_changed()


## Pistols renumbered pistol_1.. in draw order; returns the new id of `track` ("" when not needed).
func _renumber_pistols(track: String) -> String:
	var order := pistols()
	var ren := {}
	for i in order.size():
		ren[order[i]] = "pistol_%d" % (i + 1)
	var out: String = ren.get(track, track)
	if ren.has(in_hand):
		in_hand = ren[in_hand]
	for it: Dictionary in items:
		if ren.has(String(it.id)):
			it.id = ren[String(it.id)]
	return out


# --- save -------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"format": "frontier-loadout", "version": 1, "preset_id": preset_id, "display_name": display_name,
			"gear": Array(gear), "shoulder_ew_sash": shoulder_ew_sash, "items": items.duplicate(true),
			"in_hand": in_hand, "outfit_bulk": outfit_bulk}


static func from_dict(d: Dictionary) -> Loadout:
	var lo := Loadout.new()
	lo.preset_id = String(d.get("preset_id", ""))
	lo.display_name = String(d.get("display_name", ""))
	lo.gear = PackedStringArray(d.get("gear", []))
	lo.shoulder_ew_sash = bool(d.get("shoulder_ew_sash", false))
	for it: Dictionary in d.get("items", []):
		var pts: Array[String] = []
		for p in it.get("points", []):
			pts.append(String(p))
		lo.items.append({"id": String(it.id), "kind": String(it.kind), "points": pts, "count": int(it.get("count", 1)),
				"state": (it.get("state", {}) as Dictionary).duplicate(true)})
	lo.in_hand = String(d.get("in_hand", ""))
	lo.outfit_bulk = String(d.get("outfit_bulk", ""))
	return lo


func copy() -> Loadout:
	return Loadout.from_dict(to_dict())
