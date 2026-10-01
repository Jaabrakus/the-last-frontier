class_name LoadoutRules
extends RefCounted
## The carry rules of loadout_design.md 1 (ported from tools/loadout/build_loadout_data.py and extended):
##
##  - at most TWO long weapons, slung across the back in long_A / long_B (assign_long_slots);
##  - the worn belt / sash / slings decide the carry points (gear_points) and so the number of pistols
##    (pistol_capacity = the gear's maximum; effective_pistol_capacity = what is left after the other
##    items take their points);
##  - exclusive points, blocked points, needs (bow -> quiver, atlatl <-> dart bundle), counts;
##  - can_carry(): one rule set for world pickups, camp / chest and presets (1.6);
##  - validate(): every problem of a Loadout as text ([] = legal).
##
## All functions are static and read LoadoutData.get_default() unless a data object is passed.

const CARRY_POINT_NAMES := {
	"R_hip": "belt (right hip)", "L_hip": "belt (left hip)", "back_right": "sash (behind the right hip)",
	"chest_R": "pistol sling (right chest)", "chest_L": "pistol sling (left chest)", "back": "belt (back)",
	"back_2": "belt (back, stacked)", "back_left": "belt (behind the left hip)", "pouch_strap": "shot-pouch strap",
	"long_A": "back (over the left shoulder)", "long_B": "back (over the right shoulder)", "quiver": "back (quiver)",
	"tool_loop": "pack (tool loop behind the right shoulder)", "feet": "on the feet (while climbing)",
}


static func _d(data: LoadoutData) -> LoadoutData:
	return data if data else LoadoutData.get_default()


## A gear id that stops the back slings being given free (BareStart): they are worn gear then (a rope sling).
const NO_FREE_SLINGS := "no_free_slings"


## Carry points of a set of worn gear after blocks: {point: [kinds]} and the exclusive pairs.
## Returns {"points": Dictionary, "exclusive": Array, "requires": Dictionary, "blocked": Array}.
static func gear_points(gear: PackedStringArray, shoulder_ew_sash := false, data: LoadoutData = null) -> Dictionary:
	var d := _d(data)
	var pts := {}
	var blocked := {}
	var excl: Array = []
	var req := {}
	var baldric := {}
	var g_list := Array(gear)
	# (the back slings come with everyone, unless the gear says the character has none yet: a start with nothing, until a
	# rope sling is made)
	if not g_list.has("back_slings") and not g_list.has(NO_FREE_SLINGS):
		g_list.append("back_slings")
	for gid: String in g_list:
		var g := d.gear(gid)
		if g.is_empty():
			continue
		if g.has("as_waist"):
			if shoulder_ew_sash:
				# worn over the shoulder: its hanging end adds a left-hip point where the waist gear has
				# none (a sash's knot blocks the belt's L_hip, not the baldric's)
				for p: String in g.as_shoulder.points:
					baldric[p] = g.as_shoulder.points[p]
				continue
			g = d.gear(String(g.as_waist))
		for p: String in g.get("points", {}):
			if g.get("adds_only_missing", false) and pts.has(p):
				continue
			if not pts.has(p):
				pts[p] = []
			for k: String in g.points[p]:
				if not (pts[p] as Array).has(k):
					(pts[p] as Array).append(k)
		for b: String in g.get("blocks", []):
			blocked[b] = true
		for e: Array in g.get("exclusive", []):
			excl.append(e)
		for rk: String in g.get("requires", {}):
			req[rk] = String(g.requires[rk])
	for b: String in blocked:
		pts.erase(b)
	for p: String in baldric:
		if not pts.has(p):
			pts[p] = (baldric[p] as Array).duplicate()
	return {"points": pts, "exclusive": excl, "requires": req, "blocked": blocked.keys()}


## The gear's maximum number of pistols (pistol-capable points, capped) and those points in draw order.
static func pistol_capacity(gear: PackedStringArray, shoulder_ew_sash := false, data: LoadoutData = null) -> Dictionary:
	var d := _d(data)
	var gp := gear_points(gear, shoulder_ew_sash, d)
	var pts: Dictionary = gp.points
	var free: Array[String] = []
	for p: String in LoadoutData.PISTOL_ORDER:
		if pts.has(p) and (pts[p] as Array).has("pistol"):
			free.append(p)
	return {"max": mini(free.size(), d.pistol_cap()), "points": free}


## Pistol points still usable once the other carried items take theirs: a pistol point held by a
## non-pistol item, or exclusive with a point that holds anything, is lost. Capped at the pistol cap.
## `occupied` is point -> kind (Loadout.point_kinds()).
static func effective_pistol_capacity(gear: PackedStringArray, occupied: Dictionary, shoulder_ew_sash := false,
		data: LoadoutData = null) -> Dictionary:
	var d := _d(data)
	var gp := gear_points(gear, shoulder_ew_sash, d)
	var pts: Dictionary = gp.points
	var free: Array[String] = []
	for p: String in LoadoutData.PISTOL_ORDER:
		if not (pts.has(p) and (pts[p] as Array).has("pistol")):
			continue
		if occupied.has(p) and String(occupied[p]) != "pistol":
			continue
		var lost := false
		for e: Array in gp.exclusive:
			if (String(e[0]) == p and occupied.has(String(e[1]))) or (String(e[1]) == p and occupied.has(String(e[0]))):
				lost = true
		if not lost:
			free.append(p)
	return {"max": mini(free.size(), d.pistol_cap()), "points": free}


## Long slot per long kind: long guns first, then the bow, the spear pair, the dart bundle; each takes
## the first free slot of its preference list. `blocked` lists unavailable slots (a back load blocks
## long_B). Returns {"slots": {kind_index_key: slot}, "ok": bool, "reason": String}; the keys are
## "<kind>#<n>" so two long guns stay apart.
static func assign_long_slots(kinds: Array, blocked: Array = [], data: LoadoutData = null) -> Dictionary:
	var d := _d(data)
	var ordered: Array = kinds.duplicate()
	ordered.sort_custom(func(a, b) -> bool:
		return _long_rank(String(a)) < _long_rank(String(b)))
	var taken := {}
	var out := {}
	var seen := {}
	if ordered.size() > LoadoutData.LONG_SLOTS.size():
		return {"slots": {}, "ok": false, "reason": "at most two long weapons (%d given)" % ordered.size()}
	for k: String in ordered:
		var n := int(seen.get(k, 0)) + 1
		seen[k] = n
		var got := ""
		for s: String in d.long_slots_of(k):
			if not taken.has(s) and not blocked.has(s):
				got = s
				break
		if got == "":
			return {"slots": out, "ok": false, "reason": "no free back slot for %s" % k}
		taken[got] = true
		out["%s#%d" % [k, n]] = got
	return {"slots": out, "ok": true, "reason": ""}


static func _long_rank(k: String) -> int:
	var i := LoadoutData.LONG_ORDER.find(k)
	return i if i >= 0 else 99


## Every problem of a loadout as text; [] when it is legal.
static func validate(lo: Loadout, data: LoadoutData = null) -> Array[String]:
	var d := _d(data)
	var errs: Array[String] = []
	var gp := gear_points(lo.gear, lo.shoulder_ew_sash, d)
	var pts: Dictionary = gp.points
	var occ := {}
	var longs: Array = []
	for it: Dictionary in lo.items:
		var k := String(it.kind)
		var ip: Array = it.points
		if ip.is_empty():
			errs.append("%s has no point" % it.id)
			continue
		if d.kind(k).is_empty():
			errs.append("%s: unknown kind %s" % [it.id, k])
			continue
		if d.kind(k).get("later", false):
			errs.append("%s: %s has no model yet (later)" % [it.id, k])
		for p: String in ip:
			if occ.has(p):
				errs.append("%s and %s both at %s" % [occ[p], it.id, p])
			occ[p] = String(it.id)
			if not pts.has(p):
				errs.append("%s: point %s is not provided by the worn gear %s" % [it.id, p, Array(lo.gear)])
			elif not (pts[p] as Array).has(k):
				errs.append("%s: %s is not allowed at %s" % [it.id, k, p])
		if int(it.get("count", 1)) > d.count_max(k) or int(it.get("count", 1)) < 0:
			errs.append("%s: count %d outside 0..%d" % [it.id, int(it.count), d.count_max(k)])
		if k == "tomahawk" and ip.size() > int(it.get("count", 1)):
			errs.append("%s: %d points for %d tomahawks" % [it.id, ip.size(), int(it.count)])
		for need: String in d.needs(k):
			if not lo.has_kind(need):
				errs.append("%s needs %s" % [k, need])
		if d.is_long(k):
			longs.append(k)
			if not LoadoutData.LONG_SLOTS.has(String(ip[0])):
				errs.append("%s: long item not on the back (%s)" % [it.id, ip[0]])
	if longs.size() > 2:
		errs.append("%d long weapons: at most two on the back" % longs.size())
	for e: Array in gp.exclusive:
		if occ.has(String(e[0])) and occ.has(String(e[1])):
			errs.append("%s and %s exclude each other" % [e[0], e[1]])
	var kinds := lo.point_kinds()
	for rk: String in gp.requires:
		if occ.has(rk) and String(gp.requires[rk]).begins_with("back holds a tomahawk") and String(kinds.get("back", "")) != "tomahawk":
			errs.append("%s requires a tomahawk at back" % rk)
	var cap := pistol_capacity(lo.gear, lo.shoulder_ew_sash, d)
	var np := lo.ids_of_kind("pistol").size()
	if np > int(cap.max):
		errs.append("%d pistols > the gear's capacity %d" % [np, int(cap.max)])
	if lo.in_hand != "" and not lo.has_item(lo.in_hand):
		errs.append("in_hand %s is not carried" % lo.in_hand)
	return errs


## Can `kind` be added (a world pickup, the camp chest)? Returns
## {ok, action: "count" | "stow" | "swap" | "none", point, points, swap: [item ids], reason, message}.
static func can_carry(lo: Loadout, kind: String, data: LoadoutData = null) -> Dictionary:
	var d := _d(data)
	var res := {"ok": false, "action": "none", "point": "", "points": [], "swap": [], "reason": "", "message": ""}
	if d.kind(kind).is_empty():
		res.reason = "unknown item " + kind
		return res
	# 1. same kind with room (thrown spears, tomahawks, darts; arrows go to the quiver)
	if kind in ["spear_pair", "dart_bundle", "tomahawk"] and lo.has_kind(kind):
		var it := lo.first_of_kind(kind)
		if int(it.count) < d.count_max(kind):
			if kind != "tomahawk":
				res.ok = true
				res.action = "count"
				res.point = String(it.points[0])
				res.message = "%s: %d" % [kind, int(it.count) + 1]
				return res
			# a second tomahawk needs back_2 (and no quiver)
			var probe := lo.copy()
			var t := probe.first_of_kind("tomahawk")
			(t.points as Array).append("back_2")
			t.count = int(t.count) + 1
			if validate(probe, d).is_empty():
				res.ok = true
				res.action = "count"
				res.point = "back_2"
				res.message = "Second tomahawk stacked on the first"
				return res
			res.reason = "no room for a second tomahawk (the quiver takes its place)"
			res.action = "none"
			return res
	for need: String in d.needs(kind):
		if not lo.has_kind(need) and not (kind == "bow" and need == "quiver"):
			res.reason = "needs " + need
	# 2. a free compatible point or slot
	var gp := gear_points(lo.gear, lo.shoulder_ew_sash, d)
	var pts: Dictionary = gp.points
	if d.is_long(kind):
		var kinds: Array = []
		for id in lo.long_items():
			kinds.append(String(lo.item(id).kind))
		var blocked: Array = []
		for s: String in LoadoutData.LONG_SLOTS:
			if not pts.has(s):
				blocked.append(s)
		var with_new := kinds.duplicate()
		with_new.append(kind)
		var a := assign_long_slots(with_new, blocked if kind != "bow" else _bow_blocked(gp, blocked), d)
		if a.ok:
			# the new item's slot: the one not used by the existing long items after reassignment
			var slot := ""
			for key: String in a.slots:
				if key.begins_with(kind + "#"):
					slot = a.slots[key]
			var probe := lo.copy()
			_apply_long_assignment(probe, a.slots, kind, slot, d)
			if kind == "bow" and not probe.has_kind("quiver"):
				if not pts.has("quiver"):
					res.reason = "the quiver has no place (a back load)"
					return _swap_for(lo, kind, res, d)
				probe.add_item("quiver", ["quiver"], 1, {"arrows": 0})
			if validate(probe, d).is_empty() or _only_need_errors(validate(probe, d)):
				res.ok = true
				res.action = "stow"
				res.point = slot
				res.message = "%s slung on the %s" % [kind.capitalize(), CARRY_POINT_NAMES.get(slot, slot)]
				return res
		res.reason = String(a.reason) if not a.ok else "no room on the back"
		return _swap_for(lo, kind, res, d)
	if kind == "pistol":
		var eff := effective_pistol_capacity(lo.gear, lo.point_kinds(), lo.shoulder_ew_sash, d)
		var used := lo.ids_of_kind("pistol").size()
		if used < int(eff.max):
			for p: String in eff.points:
				if not lo.occupancy().has(p):
					res.ok = true
					res.action = "stow"
					res.point = p
					res.message = "Pistol hooked on the %s" % CARRY_POINT_NAMES.get(p, p)
					return res
		res.reason = "no free pistol point (%d of %d used)" % [used, int(eff.max)]
		return _swap_for(lo, kind, res, d)
	# belt items
	for p: String in d.points_of(kind):
		if not pts.has(p) or not (pts[p] as Array).has(kind) or lo.occupancy().has(p):
			continue
		var probe := lo.copy()
		probe.add_item(kind, [p], 1, {})
		var errs := validate(probe, d)
		if errs.is_empty() or _only_need_errors(errs):
			res.ok = true
			res.action = "stow"
			res.point = p
			res.message = "%s on the %s" % [kind.capitalize(), CARRY_POINT_NAMES.get(p, p)]
			if not errs.is_empty():
				res.reason = errs[0]
			return res
	res.reason = "no free point for " + kind
	return _swap_for(lo, kind, res, d)


static func _bow_blocked(gp: Dictionary, blocked: Array) -> Array:
	var b := blocked.duplicate()
	if not gp.points.has("quiver") and not b.has("long_B"):
		b.append("long_B")
	return b


static func _only_need_errors(errs: Array[String]) -> bool:
	for e in errs:
		if not " needs " in e:
			return false
	return true


static func _apply_long_assignment(lo: Loadout, slots: Dictionary, kind: String, slot: String, d: LoadoutData) -> void:
	# existing long items keep their slots when possible; the simple case is the new item taking `slot`
	var seen := {}
	for it: Dictionary in lo.items:
		var k := String(it.kind)
		if not d.is_long(k):
			continue
		var n := int(seen.get(k, 0)) + 1
		seen[k] = n
		var key := "%s#%d" % [k, n]
		if slots.has(key):
			var pa: Array[String] = [String(slots[key])]
			it.points = pa
	lo.add_item(kind, [slot], d.count_max(kind) if kind in ["spear_pair", "dart_bundle"] else 1, {})


## What to offer for a swap (1.6.3): for a long item the occupant of its preferred slot; for a pistol the
## first EMPTY pistol, else the last in draw order; for a belt item the occupant of its point.
static func _swap_for(lo: Loadout, kind: String, res: Dictionary, d: LoadoutData) -> Dictionary:
	var occ := lo.occupancy()
	var swap: Array = []
	if d.is_long(kind):
		for s: String in d.long_slots_of(kind):
			if occ.has(s):
				swap.append(occ[s])
				break
	elif kind == "pistol":
		var ps := lo.pistols()
		for id in ps:
			if not bool(lo.state_of(id).get("loaded", true)):
				swap.append(id)
				break
		if swap.is_empty() and not ps.is_empty():
			swap.append(ps[ps.size() - 1])
	else:
		for p: String in d.points_of(kind):
			if occ.has(p):
				swap.append(occ[p])
				break
	res.swap = swap
	res.action = "swap" if not swap.is_empty() else "none"
	if not swap.is_empty():
		res.message = "E  Swap for %s" % String(swap[0])
	return res


## Loadout gear ids from the customizer's worn accessories: {"accessories.waist": id, "accessories.shoulder":
## id or [ids]}. The legacy baked belt is the waist gear when no waist accessory is worn and `legacy_body`.
static func gear_from_appearance(slots: Dictionary, legacy_body := true, data: LoadoutData = null) -> Dictionary:
	var d := _d(data)
	var out := PackedStringArray()
	var shoulder_sash := false
	var by_cid := {}
	for gid: String in d.carry.get("gear", {}):
		for cid in d.gear(gid).get("customizer_ids", []):
			by_cid[String(cid)] = gid
	var extra: Dictionary = d.rt("customizer_gear", {})
	for cid: String in extra:
		by_cid[cid] = extra[cid]
	var waist: Variant = slots.get("accessories.waist", "")
	var sh: Variant = slots.get("accessories.shoulder", [])
	var sh_list: Array = sh if sh is Array else ([sh] if String(sh) != "" else [])
	if String(waist) != "" and by_cid.has(String(waist)):
		out.append(by_cid[String(waist)])
	elif legacy_body:
		out.append("legacy_baked_belt")
	for s in sh_list:
		var cid := String(s)
		if cid == "ew_sash":
			shoulder_sash = true
			out.append("ew_sash")
			continue
		var g: Variant = by_cid.get(cid, "")
		if g is Array:
			for x in g:
				if not out.has(String(x)):
					out.append(String(x))
		elif String(g) != "" and not out.has(String(g)):
			out.append(String(g))
	out.append("back_slings")
	return {"gear": out, "shoulder_ew_sash": shoulder_sash}
