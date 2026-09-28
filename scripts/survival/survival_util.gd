class_name SurvivalUtil
extends RefCounted
## Small helpers shared by the survival modules. JSON numbers arrive as floats, lists as untyped Arrays and missing
## keys as null, so every read goes through these to stay safe and readable.


static func num(v, def: float = 0.0) -> float:
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	if typeof(v) == TYPE_BOOL:
		return 1.0 if v else 0.0
	if typeof(v) == TYPE_STRING and String(v).is_valid_float():
		return String(v).to_float()
	return def


static func dict(v) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func arr(v) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


static func s(v, def: String = "") -> String:
	if v == null:
		return def
	return str(v)


## A [min, max] pair from data, or [v, v] for a single number.
static func pair(v, def: float = 0.0) -> Vector2:
	if typeof(v) == TYPE_ARRAY and v.size() >= 2:
		return Vector2(num(v[0], def), num(v[1], def))
	if typeof(v) == TYPE_ARRAY and v.size() == 1:
		return Vector2(num(v[0], def), num(v[0], def))
	var x := num(v, def)
	return Vector2(x, x)


static func rand_in(rng: RandomNumberGenerator, v, def: float = 0.0) -> float:
	var p := pair(v, def)
	if is_equal_approx(p.x, p.y):
		return p.x
	return rng.randf_range(minf(p.x, p.y), maxf(p.x, p.y))


## Piecewise-linear lookup in a table of [x, y] pairs sorted by x (clamped at both ends).
static func table_lerp(table: Array, x: float) -> float:
	if table.is_empty():
		return 0.0
	var prev: Array = table[0]
	if x <= num(prev[0]):
		return num(prev[1])
	for i in range(1, table.size()):
		var cur: Array = table[i]
		if x <= num(cur[0]):
			var span := num(cur[0]) - num(prev[0])
			var t := (x - num(prev[0])) / span if span > 0.0 else 1.0
			return lerpf(num(prev[1]), num(cur[1]), t)
		prev = cur
	return num(prev[1])


## Weighted pick from {key: weight}. Returns "" when every weight is zero.
static func weighted_pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights.keys():
		total += maxf(0.0, num(weights[k]))
	if total <= 0.0:
		return ""
	var r := rng.randf() * total
	var last := ""
	for k in weights.keys():
		var w := maxf(0.0, num(weights[k]))
		if w <= 0.0:
			continue
		last = str(k)
		if r < w:
			return last
		r -= w
	return last


## Record ids in creation order: "trap.2" before "trap.10" (the prefix, then the number after the last dot).
## Loops that roll dice or pick "the first match" go by this order, never by a dictionary's key order, which a save
## format may change (Godot's .tres writer sorts keys, so trap.10 would come before trap.2).
static func id_less(a: String, b: String) -> bool:
	var pa := a.rsplit(".", true, 1)
	var pb := b.rsplit(".", true, 1)
	if pa.size() == 2 and pb.size() == 2 and pa[0] == pb[0] and pa[1].is_valid_int() and pb[1].is_valid_int():
		return pa[1].to_int() < pb[1].to_int()
	return a < b


## The keys of a dictionary of records, in creation order (see id_less).
static func sorted_ids(d: Dictionary) -> Array:
	var ids: Array = []
	for k in d.keys():
		ids.append(str(k))
	ids.sort_custom(id_less)
	return ids


## Stable string for comparing dictionaries of plain data (sorted keys, rounded floats).
static func stable_key(v) -> String:
	match typeof(v):
		TYPE_DICTIONARY:
			var keys: Array = v.keys()
			keys.sort()
			var parts := PackedStringArray()
			for k in keys:
				parts.append("%s:%s" % [str(k), stable_key(v[k])])
			return "{" + ",".join(parts) + "}"
		TYPE_ARRAY:
			var parts2 := PackedStringArray()
			for e in v:
				parts2.append(stable_key(e))
			return "[" + ",".join(parts2) + "]"
		TYPE_FLOAT:
			return "%.4f" % float(v)
		_:
			return str(v)


## Pence as pounds, shillings and pence: 1 pound = 20 s, 1 s = 12 d (economy.json currency).
static func lsd(pence: float) -> String:
	var neg := pence < 0.0
	var d := int(round(absf(pence)))
	var l := floori(d / 240.0)
	var sh := floori((d % 240) / 12.0)
	var p := d % 12
	var out := ""
	if l > 0:
		out = "%d l %d s %d d" % [l, sh, p]
	elif sh > 0:
		out = "%d s %d d" % [sh, p]
	else:
		out = "%d d" % p
	return ("-" if neg else "") + out
