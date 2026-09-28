class_name FishSpecies
extends RefCounted
## The fish (data/world/fish.json; user 2026-09-27: "add a fish powerlevel with different types of fish", "we should have
## actual fish in the ponds and rivers with there own intelligence we mimic and try to catch"): each species' ways and
## looks, and the most of each a square's water holds.
##   ids()                       the species
##   spec(id)                    its row: name, lb, len, habitat, layer, activity, wary_m, school, diet, rises, leap,
##                               cruise, burst (m/s), r, die, floor, rec, runs, look
##   water_caps(kind)            {species: the most} a water of that kind holds (river, brook, spring, lake, marsh)
##   run_share(id, kind, month)  the share of its most there in that month (1 without a run; a run's in / out)
##   activity(id, hour, month)   how active it is then, 0..1 (its dawn/day/dusk/night, eased across the hour between, x
##                               the month's)
##   hatch(hour, month)          insects on the water, 0..1

const PATH := "res://data/world/fish.json"
## The day's periods: dawn from 05, day from 08, dusk from 18, night from 21 (each eased in over the hour before).
const PERIODS := [["night", 0.0], ["dawn", 5.0], ["day", 8.0], ["dusk", 18.0], ["night", 21.0]]

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_data = d
	return _data


static func ids() -> Array[String]:
	var out: Array[String] = []
	for k: String in data().get("species", {}):
		out.append(k)
	return out


static func spec(id: String) -> Dictionary:
	return (data().get("species", {}) as Dictionary).get(id, {})


static func water_caps(kind: String) -> Dictionary:
	return (data().get("waters", {}) as Dictionary).get(kind, {})


static func run_share(id: String, kind: String, month: int) -> float:
	var run: Dictionary = (spec(id).get("runs", {}) as Dictionary).get(kind, {})
	if run.is_empty():
		return 1.0
	for m in run.get("months", []):
		if int(m) == month:
			return float(run.get("in", 1.0))
	return float(run.get("out", 0.0))


## A value by the day's period (dawn, day, dusk, night) at `hour`, eased over the hour before each begins.
static func by_period(row: Dictionary, hour: float) -> float:
	hour = fposmod(hour, 24.0)
	var cur := String(PERIODS[0][0])
	var nxt := cur
	var into := 1.0
	for i in PERIODS.size():
		if hour >= float(PERIODS[i][1]):
			cur = String(PERIODS[i][0])
			nxt = String(PERIODS[(i + 1) % PERIODS.size()][0]) if i + 1 < PERIODS.size() else "night"
			var ends := float(PERIODS[i + 1][1]) if i + 1 < PERIODS.size() else 29.0
			into = clampf(ends - hour, 0.0, 1.0)
	return lerpf(float(row.get(nxt, 0.0)), float(row.get(cur, 0.0)), into)


static func activity(id: String, hour: float, month: int) -> float:
	var ma: Array = data().get("month_activity", [])
	var m := float(ma[clampi(month - 1, 0, 11)]) if ma.size() == 12 else 1.0
	return by_period(spec(id).get("activity", {}), hour) * m


static func hatch(hour: float, month: int) -> float:
	var h: Dictionary = data().get("hatch", {})
	var ms: Array = h.get("months", [])
	var m := float(ms[clampi(month - 1, 0, 11)]) if ms.size() == 12 else 0.5
	return by_period(h, hour) * m
