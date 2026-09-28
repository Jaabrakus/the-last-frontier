class_name FishStock
extends RefCounted
## A square's fish as numbers: its fish power level (user 2026-09-27: "add a fish powerlevel with different types of
## fish"; like the animals' WildlifeEcology: "No bar, only signs", "we should never extint a animal or a plant"). How
## many of each species its water holds (`kind`: river, brook, spring, lake, marsh; FishSpecies.water_caps), moving
## with the game's days (advance(), the month given):
##   runs      the most of a species there in a month (cap_now: its most x FishSpecies.run_share): salmon come up the
##             rivers in the fall, suckers in the spring, sturgeon to the rapids in May and June; arriving they climb
##             toward it at r a day (even into empty water), past their run they leave at `die` of the excess a day
##   growth    under its most for the month, a species grows at r a day (logistic); over it, it falls back
##   floor     fewer than `floor` of its most, fish come in from the water up and down stream (`rec` a day x refill):
##             never fished out for good; a species out of its run (none there, cap_now 0) is not gone, only away
##   caught    every fish taken off the water takes one off at once (take()), and a pike's kill (eaten())
##   wary      0..1, how warily the fish there take anything: WARY_CATCH a catch, WARY_SPOOK a fish put down (spooked),
##             fading WARY_FADE a day. Fished hard, a water's fish are fewer and shyer (FishLife: they see farther and
##             take less), which is its sign, along with the rises, the leaping salmon, the fish seen in the shallows
## Kept in a save with the animals' numbers (WildlifeLand.to_dict).

const WARY_CATCH := 0.04
const WARY_SPOOK := 0.004
const WARY_FADE := 0.08

var kind := ""
## The most of each species this water holds, whatever the month.
var caps := {}
var pop := {}
var wary := 0.0
var caught := {}
var days := 0.0


## `water`: the square's water; `month` (1-12): the month it starts in.
func _init(water := "", month := 9) -> void:
	kind = water
	var wc := FishSpecies.water_caps(water)
	for s: String in wc:
		caps[s] = float(wc[s])
		pop[s] = cap_now(s, month) * 0.9
		caught[s] = 0


func has_fish() -> bool:
	return not caps.is_empty()


func cap_of(s: String) -> float:
	return float(caps.get(s, 0.0))


## The most of `s` the water holds in `month` (its run's share of its most).
func cap_now(s: String, month: int) -> float:
	return cap_of(s) * FishSpecies.run_share(s, kind, month)


## Fewer than this of `s` in `month`, fish come in from beyond (at least one where it lives then).
func floor_of(s: String, month: int) -> float:
	var k := cap_now(s, month)
	if k <= 0.0:
		return 0.0
	return minf(maxf(float(FishSpecies.spec(s).get("floor", 0.2)) * cap_of(s), 1.0), k)


## `d` game days pass in `month`. `refill`: how fast fish come in, by species (1: as fast as ever).
func advance(d: float, month: int, refill := {}) -> void:
	while d > 0.0:
		var step := minf(d, 1.0)
		d -= step
		days += step
		for s: String in caps:
			var sp := FishSpecies.spec(s)
			var p := float(pop[s])
			var k := cap_now(s, month)
			if p < k:
				p += float(sp.get("r", 0.05)) * maxf(p, 1.0) * (1.0 - p / maxf(k, 0.001)) * step
			else:
				p -= float(sp.get("die", 0.1)) * (p - k) * step
			var fl := floor_of(s, month)
			if p < fl:
				p = minf(p + float(sp.get("rec", 0.3)) * float(refill.get(s, 1.0)) * step, fl)
			pop[s] = clampf(p, 0.0, cap_of(s))
		wary = maxf(wary - WARY_FADE * step, 0.0)


## A fish of `s` taken off the water (caught): one fewer; the rest warier.
func take(s: String) -> void:
	if not pop.has(s):
		return
	pop[s] = maxf(float(pop[s]) - 1.0, 0.0)
	caught[s] = int(caught.get(s, 0)) + 1
	wary = minf(wary + WARY_CATCH, 1.0)


## A fish of `s` eaten (a pike's kill): one fewer.
func eaten(s: String) -> void:
	if pop.has(s):
		pop[s] = maxf(float(pop[s]) - 1.0, 0.0)


## A fish put down (spooked): the water a little warier.
func spooked() -> void:
	wary = minf(wary + WARY_SPOOK, 1.0)


func summary() -> String:
	var parts: Array[String] = []
	for s: String in caps:
		parts.append("%s %.1f" % [s, float(pop[s])])
	return "%s: %s  wary %.2f" % [kind, " ".join(parts), wary]


func to_dict() -> Dictionary:
	return {"pop": pop.duplicate(), "wary": wary, "caught": caught.duplicate(), "days": days}


func from_dict(d: Dictionary) -> void:
	var p: Dictionary = d.get("pop", {})
	for s: String in caps:
		if p.has(s):
			pop[s] = clampf(float(p[s]), 0.0, cap_of(s))
	wary = clampf(float(d.get("wary", 0.0)), 0.0, 1.0)
	days = float(d.get("days", days))
	var c: Dictionary = d.get("caught", {})
	for s: String in c:
		caught[s] = int(c[s])
