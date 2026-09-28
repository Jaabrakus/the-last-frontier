class_name WildlifeEcology
extends RefCounted
## A square's wildlife as numbers: how many deer, wolves, foxes, mammoths and bison it holds, and how that changes (user
## 2026-09-27: "a global power level for animals if they keep eating without dying they populate more we take out there
## bar", "we need a max amount right? or a max amount of animals? because if we kill to many wolves then more deers grow
## if we kill to many deer the wolves begin to attack mammoth and humans more"). No bar for the player: the land shows
## it (user: "No bar, only signs"): herds seen, bushes stripped, howls nearer the fort, wolves bold by day.
##
## Each species (SPEC) has a number (pop: animals, fractional between births and deaths) that moves with the game's
## days (advance(), fed the elapsed game days by WildlifeSpawner):
##   growth     toward what its food can carry (capacity()), at its rate r per day while under it (logistic); over it,
##              it starves back at `die` of the excess a day
##   food       deer: the land's forage (`forage`, 0 stripped .. 1 standing: it regrows REGROW a day and each deer
##              grazes GRAZE of it, so a land full of deer strips it and carries fewer) times its plants (`plants`:
##              ForageField.plant_level, what people have picked and dug and the deer eaten, as it regrows: user
##              2026-09-27, too much taken "without replant or letting the plants powermeter come back then the deer
##              becamse scares"); wolves: the deer (one wolf for every PER_WOLF deer); foxes: mice and carrion (a
##              steady share); mammoths: grass (always)
##   hunting    the wolves take WOLF_KILL deer each a day across the land (fewer when deer are short); the kills seen
##              in the world count toward it (on_death by a wolf)
##   deaths     every animal that dies (shot, pulled down, starved) takes one off at once (on_death)
##   max        the most the square holds of it, whatever the food (the hard cap: bodies in the world): its type's
##              (WorldSquares: dense woods hold 40 deer and no bison, open land 40 bison and 4 mammoths; `caps` to new());
##              none of it (0), it does not live there (which is not its being gone). Bison graze the grass (forage) and
##              are the wolves' prey too (BISON_PREY of a deer to find, a kill feeding as two)
##   floor      fewer than this, a few wander in from beyond (`rec` a day, times `refill`: WildlifeLand, from the
##              squares beside it, faster when they are full): nothing is gone for good (user 2026-09-27: "we should
##              never extint a animal or a plant"; the plants: ForageField.ROOT_BACK_DAYS)
## Tuned (tools: a day-by-day run of these rules) so that, from about 24 deer and 5 wolves: the wolves shot out, the
## deer climb to about 30 over a week and the wolves come back over three; the deer shot down, the wolves go hungry,
## thin to their floor, and the deer come back in a fortnight.
## wolf_hunger(): how short the wolves are of prey (0 plenty .. 1 none): hungry wolves are bolder by day, range nearer the
## fort and howl more (WildlifeSpawner.boldness, WildPlanner).
## The spawner keeps the bodies in the world to these numbers (targets()); a save keeps them (to_dict / from_dict).

## Each species' rates; `max` its most where no square type says (the fort's dense woods), `start` the share of its
## most it starts at (wolves: as the deer keep them; mammoths: half, at least one where any live).
const SPEC := {
	"deer": {"start": 0.45, "floor": 4.0, "max": 40.0, "r": 0.4, "die": 0.25, "rec": 0.5},
	"wolf": {"start": 0.0, "floor": 2.0, "max": 10.0, "r": 0.15, "die": 0.3, "rec": 0.2},
	"fox": {"start": 0.4, "floor": 1.0, "max": 8.0, "r": 0.25, "die": 0.2, "rec": 0.3},
	"mammoth": {"start": 0.5, "floor": 1.0, "max": 1.0, "r": 0.03, "die": 0.05, "rec": 0.05},
	"bison": {"start": 0.6, "floor": 2.0, "max": 0.0, "r": 0.2, "die": 0.2, "rec": 0.3},
}
## Deer a square carries stripped (grass only), as a share of its most (the woods: 6 of 40).
const DEER_LOW := 0.15
## Deer to keep one wolf.
const PER_WOLF := 5.0
## Foxes the mice carry, as a share of their most (5 of 8).
const FOX_SHARE := 0.625
## A bison as the wolves' prey: this much of a deer to find (a herd, horns), a kill feeding as two.
const BISON_PREY := 0.5
## The forage: what grows back a day (of what is missing), what a deer grazes a day (of what stands); a bison grazes as
## two deer, a mammoth as five.
const REGROW := 0.25
const GRAZE := 0.004
## Deer a wolf takes a day across the land (when there are PER_WOLF or more each; fewer, fewer).
const WOLF_KILL := 0.5

var pop := {}
## The most of each species this square holds (its type's).
var caps := {}
## The land's forage for the deer, 0 stripped .. 1 all standing; its plants (ForageField.plant_level, the spawner
## sets it).
var forage := 1.0
var plants := 1.0
## Wolf kills seen in the world not yet counted against the land's (on_death by a wolf).
var _kills_seen := 0.0
## Game days the numbers have run (tests).
var days := 0.0
## Deaths counted (tests; the signs of a hunted land).
var deaths := {}


## `type_caps`: the most of each species the square holds (WorldSquares' type animals); {}: the fort's dense woods.
func _init(type_caps := {}) -> void:
	for s: String in SPEC:
		caps[s] = float(type_caps.get(s, SPEC[s].max)) if not type_caps.is_empty() else float(SPEC[s].max)
		deaths[s] = 0
	for s: String in SPEC:
		var c := float(caps[s])
		match s:
			"wolf":
				pop[s] = minf(float(pop.deer) / PER_WOLF, c)
			"mammoth":
				pop[s] = minf(maxf(ceilf(c * float(SPEC[s].start)), 1.0), c)
			_:
				pop[s] = c * float(SPEC[s].start)


## The most of `s` this square holds.
func cap_of(s: String) -> float:
	return float(caps.get(s, 0.0))


## Fewer than this of `s`, wanderers come in (never more than it can hold: none where it does not live).
func floor_of(s: String) -> float:
	return minf(float(SPEC[s].floor), cap_of(s))


## The species of an animal in the numbers: a stag is a deer (WildlifeSpecies "eco").
static func kind_of(species: String) -> String:
	return WildlifeSpecies.eco_of(species)


## What the land can carry of `s` now.
func capacity(s: String) -> float:
	var c := cap_of(s)
	var food := clampf(forage * plants, 0.0, 1.0)
	var k := 0.0
	match s:
		"deer":
			k = lerpf(c * DEER_LOW, c, food)
		"wolf":
			k = prey() / PER_WOLF
		"fox":
			k = c * FOX_SHARE
		"mammoth":
			k = c * lerpf(0.5, 1.0, food)
		"bison":
			k = lerpf(c * 0.3, c, clampf(forage, 0.0, 1.0))
	return clampf(k, 0.0, c)


## The wolves' prey, in deer: the deer and the bison (BISON_PREY each).
func prey() -> float:
	return float(pop.deer) + BISON_PREY * float(pop.bison)


## `d` game days pass. `refill`: how fast wanderers come in, by species (WildlifeLand: from the squares beside it).
func advance(d: float, refill := {}) -> void:
	if d <= 0.0:
		return
	# in steps of a day at most (a long sleep runs as days, not one leap)
	while d > 0.0:
		var step := minf(d, 1.0)
		d -= step
		days += step
		var grazers := float(pop.deer) + 2.0 * float(pop.bison) + 5.0 * float(pop.mammoth)
		forage = clampf(forage + (REGROW * (1.0 - forage) - GRAZE * grazers * forage) * step, 0.0, 1.0)
		# the wolves' hunting across the square (less the kills already seen), deer and bison as they are found
		var w := float(pop.wolf)
		var pr := prey()
		var take := WOLF_KILL * w * minf(1.0, pr / maxf(w * PER_WOLF, 0.01)) * step
		var seen := minf(_kills_seen, take)
		_kills_seen -= seen
		take -= seen
		var deer_share := float(pop.deer) / pr if pr > 0.0 else 1.0
		var next := {}
		for s: String in SPEC:
			var p := float(pop[s])
			var k := capacity(s)
			var sp: Dictionary = SPEC[s]
			if p < k:
				p += float(sp.r) * p * (1.0 - p / maxf(k, 0.001)) * step
			else:
				p -= float(sp.die) * (p - k) * step
			if s == "deer":
				p -= take * deer_share
			elif s == "bison":
				p -= take * (1.0 - deer_share) * 0.5              # (a bison feeds as two deer)
			var fl := floor_of(s)
			if p < fl:
				p = minf(p + float(sp.rec) * float(refill.get(s, 1.0)) * step, fl)
			next[s] = clampf(p, 0.0, cap_of(s))
		pop = next


## An animal of `species` died (shot, pulled down, starved): one fewer at once. `by` a wolf: a kill of the wolves'
## hunting (counted against theirs across the land, not twice).
func on_death(species: String, by := "") -> void:
	var s := kind_of(species)
	if not pop.has(s):
		return
	pop[s] = maxf(float(pop[s]) - 1.0, 0.0)
	deaths[s] = int(deaths.get(s, 0)) + 1
	if s == "deer" and by == "wolf":
		_kills_seen += 1.0


## How short the wolves are of prey: 0 plenty (PER_WOLF deer or more each) .. 1 none.
func wolf_hunger() -> float:
	var w := maxf(float(pop.wolf), 0.5)
	return clampf(1.0 - prey() / (w * PER_WOLF), 0.0, 1.0)


## The bodies to keep in the world: {species: count} (whole animals; the spawner fills or thins to it).
func targets() -> Dictionary:
	var out := {}
	for s: String in SPEC:
		out[s] = int(round(float(pop[s])))
	return out


## The numbers in a line (tests, the debug log).
func summary() -> String:
	var parts: Array[String] = []
	for s: String in SPEC:
		parts.append("%s %.1f/%.0f" % [s, float(pop[s]), capacity(s)])
	return "day %.1f  %s  forage %.2f  plants %.2f  wolf hunger %.2f" % [days, "  ".join(parts), forage, plants, wolf_hunger()]


func to_dict() -> Dictionary:
	return {"pop": pop.duplicate(), "forage": forage, "plants": plants, "days": days, "deaths": deaths.duplicate(),
			"kills_seen": _kills_seen}


func from_dict(d: Dictionary) -> void:
	var p: Dictionary = d.get("pop", {})
	for s: String in SPEC:
		if p.has(s):
			pop[s] = clampf(float(p[s]), 0.0, cap_of(s))
	forage = float(d.get("forage", forage))
	plants = float(d.get("plants", plants))
	_kills_seen = float(d.get("kills_seen", 0.0))
	days = float(d.get("days", days))
	var dd: Dictionary = d.get("deaths", {})
	for s: String in dd:
		deaths[s] = int(dd[s])
