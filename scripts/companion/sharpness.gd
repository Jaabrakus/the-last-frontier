class_name Sharpness
extends RefCounted
## How sharp a worker's decisions are now, 0..1 (data/companion/sharpness.json; user 2026-09-29: "account for well rested:
## the more rest the smarter the decision, the less rested the less optimized ... mistakes can happen"). Freshly rested she
## is sharp; the longer since she rested, hungry, unwell, late in a pregnancy or unhappy, less so. Her paths (NavMover.sharp) and
## her choice of job (SpouseCore._choose) read it; a little of each mistake happens to the sharpest too.

static var _cfg := {}
## Off: no slips at all (the tests of exact planning and paths turn it off).
static var slips_on := true


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/companion/sharpness.json"))
		_cfg = d if d is Dictionary else {}
	return _cfg


static func num(key: String, dflt: float) -> float:
	return float(cfg().get(key, dflt))


## Hours of well rested a worker has left (the player's meter, on her own core: flags.well_rested_until).
static func rested_hours(w: SpouseCore) -> float:
	if w == null or w.core == null:
		return 0.0
	return maxf(float(w.core.state.flags.get("well_rested_until", -1.0)) - w.core.state.minutes, 0.0) / 60.0


## Worker `w`'s sharpness now: from the well-rested meter, less hunger, poor health, a late pregnancy and low morale.
static func of(w: SpouseCore) -> float:
	if w == null or w.core == null:
		return 1.0
	var un := num("unrested", 0.55)
	var s := lerpf(un, 1.0, clampf(rested_hours(w) / maxf(num("full_h", 8.0), 0.1), 0.0, 1.0))
	s -= float((cfg().get("hunger", {}) as Dictionary).get(SurvivalNeeds.food_stage(w.core), 0.0))
	if w.core.health() < num("health_below", 60.0):
		s -= num("health_drop", 0.15)
	if w.pregnancy is Dictionary and Pregnancy.heavy_blocked(w.pregnancy, w.core.state.minutes):
		s -= num("pregnancy_late_drop", 0.1)
	if not w.recruit.is_empty() and float(w.recruit.get("morale", 1.0)) < num("low_morale", 0.4):
		s -= num("morale_drop", 0.1)
	return clampf(s, num("floor", 0.2), 1.0)


## The well-rested gauge fills while she rests, nothing more (user 2026-09-29: "a gauge that refills when someone sleeps or
## rests ... they don't need to sleep for a prolonged time, they can optimize rest with beds and so on"). Any hour of the day,
## any length: each minute asleep adds `sleep_rate` minutes to it, sitting idle at home `rest_rate`, better in a bed
## (`bed_mult`) or warm by a fire (`warm_mult`: a lit campfire's warmth at her body at least `warm_min`, Campfire.warmth_at);
## the gauge holds at most `cap_h`. Game time runs on as it always does. A ginseng tonic adds hours to it (boost).
static func rest_tick(w: SpouseCore, dm: float, asleep: bool, resting: bool, in_bed := false, warm := false) -> void:
	if w == null or w.core == null or dm <= 0.0 or not (asleep or resting):
		return
	var rate := num("sleep_rate", 1.5) if asleep else num("rest_rate", 0.5)
	if in_bed:
		rate *= num("bed_mult", 1.25)
	if warm:
		rate *= num("warm_mult", 1.25)
	var f: Dictionary = w.core.state.flags
	var now := w.core.state.minutes
	# the clock has already moved on by dm: what she had at the start of it, plus what this rest adds (no drain while resting)
	var had := maxf(float(f.get("well_rested_until", -1.0)) - (now - dm), 0.0)
	f["well_rested_until"] = now + minf(had + dm * rate, num("cap_h", 12.0) * 60.0)


## `hours` more of the gauge (a ginseng tonic: SpouseCore._tonic_when_tired), from now if it had run out; held at `cap_h`.
static func boost(w: SpouseCore, hours: float) -> void:
	if w == null or w.core == null or hours <= 0.0:
		return
	var f: Dictionary = w.core.state.flags
	var now := w.core.state.minutes
	f["well_rested_until"] = minf(maxf(float(f.get("well_rested_until", -1.0)), now) + hours * 60.0, now + num("cap_h", 12.0) * 60.0)


## The chance of a slip for sharpness `s` at `base` (a slip's full chance when dullest): never below mistake_min.
static func slip(s: float, base: float) -> float:
	if not slips_on:
		return 0.0
	return clampf(maxf(num("mistake_min", 0.05), base * (1.0 - s)), 0.0, 1.0)
