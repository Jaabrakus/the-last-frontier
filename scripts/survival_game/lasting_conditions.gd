class_name LastingConditions
extends Node
## What neglect leaves behind (user 2026-09-27: "i think the pressure is stunted growth and decay people have to fix their
## toon with"): no need kills, but each one neglected long enough leaves a lasting condition that wears the character
## down until it is cured by setting it right, for long enough. SurvivalBridge.lasting. Each follows LastingChill's pattern
## (the cold's, which stays there): an exposure that builds while the need is neglected and fades once it is not, the
## condition at its exposure, and a recovery that builds only while the cure holds (neglect again sets it back).
##
##   wasted     hunger: a day starving (very hungry counts a quarter, wasting half again)
##                effect  the health heals no higher than 80%; every skill grows 25% slower
##                cure    two game days fed or peckish (hungry pauses it, very hungry or worse undoes it)
##   ague       wet: three hours damp or soaked while not warm (soaked and cold or worse count double)
##                effect  restless (below); every heal at 70%
##                cure    a day dry, warm and well rested; wintergreen tea: half a day of it
##   festering  a bleeding wound (BLEED_MIN or more) left undressed for six game hours
##                effect  no healing while undressed, the health draining 2 a game hour down to half its max; then
##                        heals no higher than 60%
##                cure    dress it (a poultice or a salve: the drain stops), then half a day (well rested counts double)
##   flux       the stomach turned by raw or spoiled meat twice within a few days
##                effect  a meal nourishes half
##                cure    two game days without raw meat (raw meat undoes it); blackberries steady the gut (4 hours each)
##   sore_feet  three hours on the move with no moccasins that are any use
##                effect  restless (below)
##                cure    a night's sleep (six game hours or more) in moccasins
## Wounds (user 2026-09-27: "a pose of the char ... in the conidtions tab to should what is afficted we can see if someone
## got shot in the stomach"; each place its own cost "inline with our current game", not the movement speed): a hit of
## WOUND_MIN or more is kept where it landed (PlayerWounds.struck: the region, front or back, bleeding or a bruise) until
## it has knit: a bleeding wound once dressed (a poultice or a salve), a bruise from the start, KNIT_MIN of it (the day's
## healing sleep counts double). While a place has one open:
##   head      every skill grows 25% slower (as wasted)
##   chest     the health heals no higher than 80% (as chilled)
##   stomach   a meal nourishes half (as the flux)
##   an arm    reloading ARM_RELOAD_MULT as long (the pipe's the other way) and the climbing grip tires ARM_GRIP_DRAIN x
##   a leg     restless (below)
## Restless (a leg wound, sore feet, the ague; user 2026-09-27: "allow rested by fires to make a user well rested but
## decays faster until they are well rested multiple times and it slowly gets better"): away from a fire a sleep rests
## half as well; by one it rests in full; either way the boost wears off RESTLESS_DRAIN x as fast, less by RESTLESS_EASE
## with each day's healing sleep while restless, back to as ever after three; once nothing makes the player restless it
## starts over.
## Nothing here touches the aim or the movement speed (user: "nothing effect aim"; "i dont think i want it to effect
## movement speed"). The records are in the core's flags ("lasting"), saved
## with the core. Each is told on screen when it comes and when it goes. The Condition tab shows each, and what is
## coming on, with its cure and how far the cure has come (ConditionPanel). The health bar shows what wasted and festering
## hold it under (FrontierHUD).

signal changed(id: String, on: bool)

const IDS := ["wasted", "ague", "festering", "flux", "sore_feet"]
const DEFS := {
	"wasted": {"name": "Wasted", "exposure": 24.0 * 60.0, "recover": 2.0 * 24.0 * 60.0,
			"effect": "heal no higher than 80%, learn 25% slower", "cure": "eat well (fed or peckish) for two days",
			"coming": "Starving: you are wasting away",
			"onset": "Wasted by hunger: you heal no higher than 80% and learn slower until you have eaten well for two days",
			"gone": "You have your strength back"},
	"ague": {"name": "The ague", "exposure": 3.0 * 60.0, "recover": 24.0 * 60.0,
			"effect": RESTLESS_TEXT + ", heal at 70%", "cure": "a day dry, warm and well rested (wintergreen tea helps)",
			"coming": "Wet and cold: the ague is coming on",
			"onset": "The ague: fever chills. You sleep badly away from a fire and heal slowly until you are dry, warm and well rested a day (wintergreen tea helps)",
			"gone": "The ague has left you"},
	"festering": {"name": "Festering wound", "exposure": 6.0 * 60.0, "recover": 12.0 * 60.0,
			"effect": "drains you to half health, heal no higher than 60%", "cure": "dress it (a poultice or a salve), then rest half a day",
			"coming": "An undressed wound: dress it before it festers",
			"onset": "The wound is festering: it drains you until you dress it with a poultice or a salve",
			"gone": "The wound is clean and closing"},
	"flux": {"name": "The flux", "exposure": 2.0, "recover": 2.0 * 24.0 * 60.0,
			"effect": "a meal nourishes half", "cure": "two days without raw meat (blackberries steady the gut)",
			"coming": "Raw meat has turned your stomach",
			"onset": "The flux: food runs through you and a meal nourishes half, until two days without raw meat (blackberries help)",
			"gone": "Your gut has settled"},
	"sore_feet": {"name": "Sore feet", "exposure": 3.0 * 60.0, "recover": 1.0,
			"effect": RESTLESS_TEXT, "cure": "a night's sleep in moccasins",
			"coming": "Barefoot: your feet are getting sore",
			"onset": "Sore feet: you sleep badly away from a fire until you sleep a night in moccasins",
			"gone": "Your feet have mended"},
}
## Wasted: the weight of each hunger stage on the exposure (game minutes a minute).
const HUNGER_WEIGHT := {"very_hungry": 0.25, "starving": 1.0, "wasting": 1.5}
const WASTED_CAP := 0.8
const SKILL_MULT := 0.75
## The ague.
const AGUE_HEAL_MULT := 0.7
const TEA_RECOVER_MIN := 12.0 * 60.0
## Festering: a bleeding wound this big (health) starts the clock; the drain (health a game hour) and its floor (of max).
const BLEED_MIN := 8.0
const FESTER_CAP := 0.6
const FESTER_DRAIN_H := 2.0
const FESTER_FLOOR := 0.5
## The flux: a stomach turned counts 1; the count fades this much a game day; a meal nourishes FLUX_FOOD_MULT.
const FLUX_FADE_DAY := 0.5
const FLUX_FOOD_MULT := 0.5
const BERRY_RECOVER_MIN := 4.0 * 60.0
## Sore feet: moving this fast is on the move (m/s); a sleep this long (game hours) in moccasins cures them.
const SORE_SPEED := 0.6
const SORE_SLEEP_H := 6.0
## Wounds: the places (PlayerWounds.place_of), the least hit kept, how long one takes to knit (game minutes), the most
## kept, and each place's cost.
const PLACES := ["head", "chest", "stomach", "l_arm", "r_arm", "l_leg", "r_leg"]
const WOUND_MIN := 8.0
const KNIT_MIN := 24.0 * 60.0
const WOUNDS_MAX := 12
const HEAD_SKILL_MULT := 0.75
const CHEST_CAP := 0.8
const STOMACH_FOOD_MULT := 0.5
const ARM_RELOAD_MULT := 1.15
const ARM_GRIP_DRAIN := 1.5
## Restless: a sleep away from a fire earns this much; the boost's drain at first, and how much of it each day's healing
## sleep eases.
const RESTLESS_REST_MULT := 0.5
const RESTLESS_DRAIN := 2.0
const RESTLESS_EASE := 1.0 / 3.0
const REGION_NAMES := {"head": "Head", "chest": "Chest", "stomach": "Stomach", "l_arm": "Left arm", "r_arm": "Right arm",
		"l_hand": "Left hand", "r_hand": "Right hand", "l_leg": "Left leg", "r_leg": "Right leg", "l_foot": "Left foot",
		"r_foot": "Right foot"}
const RESTLESS_TEXT := "restless (sleep by a fire; the rest wears off faster)"
## Remedies (Remedies): willow bark tea dulls the pain of wounds this many game hours (the head, arm and leg costs set
## aside; the chest's and the stomach's are the body's, not the pain's) and is half a day of the ague's cure; slippery
## elm gruel soothes the gut this many (a meal nourishes in full through the flux or a stomach wound) and is half a day
## of the flux's cure.
const WILLOW_NUMB_H := 6.0
const WILLOW_RECOVER_MIN := 12.0 * 60.0
const GRUEL_GUT_H := 12.0
const GRUEL_RECOVER_MIN := 12.0 * 60.0
const PLACE_COST := {"head": "you learn slower", "chest": "you heal no higher than 80%", "stomach": "a meal nourishes half",
		"l_arm": "you reload slower and your grip tires sooner", "r_arm": "you reload slower and your grip tires sooner",
		"l_leg": RESTLESS_TEXT, "r_leg": RESTLESS_TEXT}
## Exposure fades at this rate (a minute a minute) once the need is set right, while not yet on.
const FADE := 0.5
## What is coming on is shown from this share of its exposure.
const WARN_AT := 0.3
const MOCCASINS := "item.cloth.moccasins"

var bridge: SurvivalBridge
var _last_min := -1.0
var _wounds: PlayerWounds


# --- The records ---------------------------------------------------------------------------------------------

## The record of `id` in the core's flags: {on, exposure, recover} (festering also wound_min, dressed).
func state(id: String) -> Dictionary:
	var core := bridge.core if bridge else null
	if core == null:
		return {"on": false, "exposure": 0.0, "recover": 0.0}
	if not (core.state.flags.get("lasting") is Dictionary):
		core.state.flags["lasting"] = {}
	var all: Dictionary = core.state.flags.lasting
	if not (all.get(id) is Dictionary):
		all[id] = {"on": false, "exposure": 0.0, "recover": 0.0}
	return all[id]


func is_on(id: String) -> bool:
	return bool(state(id).get("on", false))


## The conditions on now, in IDS order.
func active() -> Array[String]:
	var out: Array[String] = []
	for id: String in IDS:
		if is_on(id):
			out.append(id)
	return out


## 0..1 of the way back from `id` (the vitals' ring, the Condition tab).
func recovery(id: String) -> float:
	var st := state(id)
	if id == "festering" and not bool(st.get("dressed", false)):
		return 0.0
	if id == "sore_feet":
		return 0.0
	return clampf(float(st.get("recover", 0.0)) / float(DEFS[id].recover), 0.0, 1.0)


## 0..1 of the way to `id` while it is not on (tests, the Condition tab's warnings).
func exposure(id: String) -> float:
	var st := state(id)
	if id == "festering":
		var wm := float(st.get("wound_min", -1.0))
		return clampf(wm / float(DEFS[id].exposure), 0.0, 1.0) if wm >= 0.0 else 0.0
	return clampf(float(st.get("exposure", 0.0)) / float(DEFS[id].exposure), 0.0, 1.0)


## The core's flags (the lasting records, the wounds, the restlessness's easing).
func _flags() -> Dictionary:
	return bridge.core.state.flags if bridge and bridge.core else {}


## The wounds kept, oldest first: {region (PlayerWounds.REGIONS), place (PLACES), side ("front" / "back"), kind ("bleed"
## / "blunt"), amount, dressed, knit (game minutes of it)}.
func wounds() -> Array:
	var f := _flags()
	if not (f.get("wounds") is Array):
		f["wounds"] = []
	return f.wounds


## Game hours left of willow bark's dulling of the pain (0 none).
func numb_h() -> float:
	return maxf(float(_flags().get("numb_until", -1.0)) - _now(), 0.0) / 60.0


## Game hours left of slippery elm's soothing of the gut (0 none).
func gut_h() -> float:
	return maxf(float(_flags().get("gut_until", -1.0)) - _now(), 0.0) / 60.0


func _now() -> float:
	return bridge.core.state.minutes if bridge and bridge.core else 0.0


## A wound at `place` whose pain costs something now (not dulled by willow bark, nor gone on laudanum).
func _pains(place: String) -> bool:
	return has_wound(place) and numb_h() <= 0.0 and not _laudanum()


## Laudanum in the player (Vices): every wound's cost set aside, the chest's and the stomach's too, and the flux stayed.
func _laudanum() -> bool:
	return bridge != null and bridge.vices != null and bridge.vices.laudanum_on()


## A wound open at `place` (PLACES).
func has_wound(place: String) -> bool:
	for w: Dictionary in wounds():
		if String(w.get("place", "")) == place:
			return true
	return false


# --- What they do (SurvivalBridge asks) ----------------------------------------------------------------------

## The most the health heals to now.
func health_cap() -> float:
	var mx := float(bridge.player.max_health) if bridge and bridge.player else 100.0
	var f := 1.0
	if is_on("wasted"):
		f = minf(f, WASTED_CAP)
	if is_on("festering"):
		f = minf(f, FESTER_CAP)
	if has_wound("chest") and not _laudanum():
		f = minf(f, CHEST_CAP)
	return mx * f


## Every heal's speed now: the ague slows it; a festering wound not yet dressed stops it (it only drains).
func heal_mult() -> float:
	var st := state("festering")
	if bool(st.get("on", false)) and not bool(st.get("dressed", false)):
		return 0.0
	return AGUE_HEAL_MULT if is_on("ague") else 1.0


## Every skill's growth (GatherSkills and the core's).
func skill_mult() -> float:
	return (SKILL_MULT if is_on("wasted") else 1.0) * (HEAD_SKILL_MULT if _pains("head") else 1.0)


## Restless: a leg wound, sore feet or the ague.
func restless() -> bool:
	return is_on("ague") or is_on("sore_feet") or _pains("l_leg") or _pains("r_leg")


## The well-rested boost a sleep earns: restless, half away from a fire (`warm`: a sleep by a heat source).
func rest_mult(warm := false) -> float:
	return RESTLESS_REST_MULT if restless() and not warm else 1.0


## How much faster the boost wears off: restless, RESTLESS_DRAIN x at first, eased by each day's healing sleep.
func rest_drain_mult() -> float:
	if not restless():
		return 1.0
	return 1.0 + (RESTLESS_DRAIN - 1.0) * (1.0 - clampf(float(_flags().get("restless_eased", 0.0)), 0.0, 1.0))


## What a meal nourishes: the flux or a stomach wound, half (the worst of them); in full while slippery elm soothes the
## gut.
func food_mult() -> float:
	if gut_h() > 0.0 or _laudanum():
		return 1.0
	return minf(FLUX_FOOD_MULT if is_on("flux") else 1.0, STOMACH_FOOD_MULT if has_wound("stomach") else 1.0)


## A reload's length (Vices._apply_player with the pipe's): an arm wound, longer.
func reload_mult() -> float:
	return ARM_RELOAD_MULT if _pains("l_arm") or _pains("r_arm") else 1.0


## The climbing grip's stamina drain (PlayerGrip.drain_mult): an arm wound, faster.
func grip_drain_mult() -> float:
	return ARM_GRIP_DRAIN if _pains("l_arm") or _pains("r_arm") else 1.0


# --- What happens to the player (hooks) ----------------------------------------------------------------------

## A meal eaten (SurvivalBridge.eat): raw meat and what it did; blackberries for the flux.
func ate(kind: String, raw: bool, turned: bool) -> void:
	if turned and raw:
		var st := state("flux")
		if not bool(st.get("on", false)):
			st["exposure"] = float(st.get("exposure", 0.0)) + 1.0
			_check("flux")
	if raw and is_on("flux"):
		state("flux")["recover"] = 0.0
	if kind == "blackberries" and is_on("flux"):
		var st := state("flux")
		st["recover"] = float(st.get("recover", 0.0)) + BERRY_RECOVER_MIN
		_check("flux")


## A remedy taken (Remedies.use).
func remedy(kind: String) -> void:
	if kind == "wintergreen_tea" and is_on("ague"):
		var st := state("ague")
		st["recover"] = float(st.get("recover", 0.0)) + TEA_RECOVER_MIN
		_check("ague")
	if kind == "willow_bark_tea":
		_flags()["numb_until"] = _now() + WILLOW_NUMB_H * 60.0
		if is_on("ague"):
			var st := state("ague")
			st["recover"] = float(st.get("recover", 0.0)) + WILLOW_RECOVER_MIN
			_check("ague")
	if kind == "jimsonweed" and is_on("ague"):
		# a leaf smoked: the old remedy for a fever (Vices; more is madness)
		var sa := state("ague")
		sa["recover"] = float(sa.get("recover", 0.0)) + Vices.JIMSON_AGUE_MIN
		_check("ague")
	if kind == "slippery_elm_gruel":
		_flags()["gut_until"] = _now() + GRUEL_GUT_H * 60.0
		if is_on("flux"):
			var st := state("flux")
			st["recover"] = float(st.get("recover", 0.0)) + GRUEL_RECOVER_MIN
			_check("flux")
	bridge.needs_changed.emit()


## A sleep ended (SurvivalSleep), `slept_h` game hours of it; `healed`: it was the day's healing sleep (it eases the
## restlessness a step).
func slept(slept_h: float, healed := false) -> void:
	if healed and restless():
		var f := _flags()
		f["restless_eased"] = minf(float(f.get("restless_eased", 0.0)) + RESTLESS_EASE, 1.0)
	if is_on("sore_feet") and slept_h >= SORE_SLEEP_H and _shod():
		state("sore_feet")["recover"] = 1.0
		_check("sore_feet")


## A hit that hurt (PlayerWounds.struck): kept where it landed if it is WOUND_MIN or more; a bruise knits from the start,
## a bleeding wound once dressed.
func hit(region: String, side: String, kind: String, amount: float) -> void:
	if amount < WOUND_MIN or bridge == null or bridge.core == null or not (kind in ["bleed", "blunt"]):
		return
	var ws := wounds()
	ws.append({"region": region, "place": PlayerWounds.place_of(region), "side": side, "kind": kind, "amount": amount,
			"dressed": kind == "blunt", "knit": 0.0})
	while ws.size() > WOUNDS_MAX:
		ws.remove_at(0)
	bridge.needs_changed.emit()


func _on_wounded(amount: float) -> void:
	if amount < BLEED_MIN:
		return
	var st := state("festering")
	if bool(st.get("on", false)):
		st["dressed"] = false                 # a new wound on it: dress it again
		st["recover"] = 0.0
	elif float(st.get("wound_min", -1.0)) < 0.0:
		st["wound_min"] = 0.0


func _on_dressed() -> void:
	for w: Dictionary in wounds():
		if String(w.kind) == "bleed" and not bool(w.get("dressed", false)):
			w["dressed"] = true
	var st := state("festering")
	st["wound_min"] = -1.0
	if bool(st.get("on", false)) and not bool(st.get("dressed", false)):
		st["dressed"] = true
		bridge._notice("The wound is dressed: the festering stops; rest and it will close")


func _shod() -> bool:
	var core := bridge.core
	return core != null and SurvivalInventory.count_usable(core, MOCCASINS) >= 1.0 - 0.001


# --- The clock -----------------------------------------------------------------------------------------------

## A core just set back (a new or loaded game): the minutes count from it.
func reset_clock() -> void:
	_last_min = -1.0


func _hook_wounds() -> void:
	var p := bridge.player
	if p == null or _wounds != null:
		return
	var w := PlayerWounds.of(p)
	if w == null:
		return
	_wounds = w
	w.wounded.connect(_on_wounded)
	w.dressed.connect(_on_dressed)
	w.struck.connect(hit)


## The game minutes since the last call: each exposure, each condition, each recovery; the health under the cap; the
## festering's drain.
func tick() -> void:
	var core := bridge.core
	var p := bridge.player
	if core == null or p == null or p.is_dead:
		_last_min = -1.0
		return
	_hook_wounds()
	var m := core.state.minutes + float(core.state.world.get("clock_acc", 0.0))
	var dm := m - _last_min if _last_min >= 0.0 else 0.0
	_last_min = m
	if dm < 0.0 or dm > 24.0 * 60.0:
		dm = 0.0
	if dm <= 0.0:
		return
	var stages := core.need_stages()
	var rested := bridge.is_healing_rest()
	_tick_wasted(dm, String(stages.get("need.food", "fed")))
	_tick_ague(dm, SurvivalNeeds.wet_stage(core), SurvivalNeeds.warmth_stage(core), rested)
	_tick_festering(dm, rested, p)
	_tick_flux(dm)
	_tick_sore_feet(dm, p)
	_tick_wounds(dm, rested)
	# restless no more: the easing starts over
	if not restless():
		_flags().erase("restless_eased")
	# the health never above the cap while one holds it (whatever healed it)
	var cap := health_cap()
	if p.health > cap:
		p.health = cap
		if not core.is_dead():
			core.state.needs["health"] = p.health


func _tick_wasted(dm: float, food: String) -> void:
	var st := state("wasted")
	if HUNGER_WEIGHT.has(food):
		if not bool(st.get("on", false)):
			st["exposure"] = float(st.get("exposure", 0.0)) + dm * float(HUNGER_WEIGHT[food])
		else:
			st["recover"] = 0.0
	elif food in ["fed", "peckish"]:
		if bool(st.get("on", false)):
			st["recover"] = float(st.get("recover", 0.0)) + dm
		else:
			st["exposure"] = maxf(float(st.get("exposure", 0.0)) - dm * FADE, 0.0)
	_check("wasted")


func _tick_ague(dm: float, wet: String, warm: String, rested: bool) -> void:
	var st := state("ague")
	var wet_now := wet in ["damp", "soaked"]
	if wet_now and warm != "comfortable":
		var w := 0.5 if wet == "damp" else 1.0
		if wet == "soaked" and warm in ["cold", "very_cold", "hypothermic", "freezing"]:
			w = 2.0
		if not bool(st.get("on", false)):
			st["exposure"] = float(st.get("exposure", 0.0)) + dm * w
		else:
			st["recover"] = 0.0
	elif not wet_now:
		if bool(st.get("on", false)):
			if warm == "comfortable" and rested:
				st["recover"] = float(st.get("recover", 0.0)) + dm
		else:
			st["exposure"] = maxf(float(st.get("exposure", 0.0)) - dm * FADE, 0.0)
	_check("ague")


func _tick_festering(dm: float, rested: bool, p: FrontierPlayer) -> void:
	var st := state("festering")
	if not bool(st.get("on", false)):
		var wm := float(st.get("wound_min", -1.0))
		if wm >= 0.0:
			st["wound_min"] = wm + dm
			if wm + dm >= float(DEFS.festering.exposure):
				st["wound_min"] = -1.0
				st["exposure"] = float(DEFS.festering.exposure)
				st["dressed"] = false
		_check("festering")
		return
	if bool(st.get("dressed", false)):
		st["recover"] = float(st.get("recover", 0.0)) + dm * (2.0 if rested else 1.0)
	else:
		# undressed: it drains the health, down to the floor
		var floor_h := float(p.max_health) * FESTER_FLOOR
		if p.health > floor_h:
			p.health = maxf(p.health - FESTER_DRAIN_H * dm / 60.0, floor_h)
			if not bridge.core.is_dead():
				bridge.core.state.needs["health"] = p.health
	_check("festering")


func _tick_flux(dm: float) -> void:
	var st := state("flux")
	if bool(st.get("on", false)):
		st["recover"] = float(st.get("recover", 0.0)) + dm
	else:
		st["exposure"] = maxf(float(st.get("exposure", 0.0)) - FLUX_FADE_DAY * dm / (24.0 * 60.0), 0.0)
	_check("flux")


func _tick_sore_feet(dm: float, p: FrontierPlayer) -> void:
	var st := state("sore_feet")
	if bool(st.get("on", false)):
		return
	var moving := p.horizontal_speed() > SORE_SPEED and p.riding == null
	if moving and not _shod():
		st["exposure"] = float(st.get("exposure", 0.0)) + dm * (1.5 if p.is_sprinting else 1.0)
	elif _shod():
		st["exposure"] = maxf(float(st.get("exposure", 0.0)) - dm * FADE, 0.0)
	_check("sore_feet")


## Each dressed wound and each bruise knits (the day's healing sleep counts double); knit, it is gone.
func _tick_wounds(dm: float, rested: bool) -> void:
	var ws := wounds()
	var i := 0
	var gone := false
	while i < ws.size():
		var w: Dictionary = ws[i]
		if bool(w.get("dressed", false)):
			w["knit"] = float(w.get("knit", 0.0)) + dm * (2.0 if rested else 1.0)
			if float(w.knit) >= KNIT_MIN:
				ws.remove_at(i)
				bridge._notice("The %s in your %s has knit" % ["bruise" if String(w.kind) == "blunt" else "wound",
						String(REGION_NAMES.get(String(w.region), "body")).to_lower()])
				gone = true
				continue
		i += 1
	if gone:
		bridge.needs_changed.emit()


## `id` comes on at its exposure, and goes at its recovery (told on screen, changed emitted).
func _check(id: String) -> void:
	var st := state(id)
	var d: Dictionary = DEFS[id]
	if not bool(st.get("on", false)):
		if float(st.get("exposure", 0.0)) >= float(d.exposure):
			st["on"] = true
			st["recover"] = 0.0
			if id == "festering":
				st["dressed"] = false
			bridge._notice(String(d.onset))
			bridge.needs_changed.emit()
			changed.emit(id, true)
	elif float(st.get("recover", 0.0)) >= float(d.recover):
		st["on"] = false
		st["exposure"] = 0.0
		st["recover"] = 0.0
		st.erase("dressed")
		bridge._notice(String(d.gone))
		bridge.needs_changed.emit()
		changed.emit(id, false)


# --- The Condition tab ---------------------------------------------------------------------------------------

## Rows for the Condition tab: [name, text, severity] for each on (with its cure and how far it has come), then each
## coming on (WARN_AT of its exposure or more). severity: "bad" on, "warn" coming.
func rows() -> Array:
	var out: Array = []
	for id: String in IDS:
		var d: Dictionary = DEFS[id]
		if is_on(id):
			var eff := String(d.effect)
			var txt := "%s. Cure: %s" % [eff.substr(0, 1).to_upper() + eff.substr(1), d.cure]
			if id == "festering" and not bool(state(id).get("dressed", false)):
				txt += " (not yet dressed)"
			elif recovery(id) > 0.0:
				txt += " · %d%% mended" % roundi(recovery(id) * 100.0)
			out.append([String(d.name), txt, "bad"])
	out.append_array(wound_rows())
	# the remedies at work
	if numb_h() > 0.0 and PLACES.any(func(pl: String) -> bool: return has_wound(pl)):
		out.append(["Willow bark", "The pain of your wounds dulled, %d hours more" % ceili(numb_h()), "good"])
	if gut_h() > 0.0:
		out.append(["Slippery elm", "Your gut keeps its food, %d hours more" % ceili(gut_h()), "good"])
	for id: String in IDS:
		if not is_on(id) and exposure(id) >= WARN_AT:
			out.append([String(DEFS[id].name), "%s (%d%%)" % [DEFS[id].coming, roundi(exposure(id) * 100.0)], "warn"])
	return out


## A row a place with a wound open: [place name, what it is and its cost, severity] ("bad" while one is not dressed).
func wound_rows() -> Array:
	var out: Array = []
	for place: String in PLACES:
		var ws := wounds().filter(func(w: Dictionary) -> bool: return String(w.get("place", "")) == place)
		if ws.is_empty():
			continue
		var open := ws.filter(func(w: Dictionary) -> bool: return not bool(w.get("dressed", false)))
		var cost := String(PLACE_COST[place])
		if numb_h() > 0.0 and place in ["head", "l_arm", "r_arm", "l_leg", "r_leg"]:
			cost = "its pain dulled by willow bark"
		var txt := ""
		if not open.is_empty():
			txt = "%s: %s until it knits. Cure: dress it (a poultice or a salve), then a day" % [
					"Festering" if is_on("festering") else "Open wound, not dressed", cost]
		else:
			var knit := 1.0
			for w: Dictionary in ws:
				knit = minf(knit, float(w.get("knit", 0.0)) / KNIT_MIN)
			var bruise := ws.all(func(w: Dictionary) -> bool: return String(w.kind) == "blunt")
			txt = "%s: %s until it knits · %d%% knit" % ["Bruised" if bruise else "Dressed", cost, roundi(knit * 100.0)]
		out.append([String(REGION_NAMES[place]), txt, "bad" if not open.is_empty() else "warn"])
	return out


## What the Condition tab's outline marks (BodyChart): [{region (PlayerWounds.REGIONS), side ("front", "back" or "both"),
## mark, text}]. A wound: "bleed" open, "festering", "dressed" or "bruise"; the lasting harms where they sit: "sick" the
## stomach (the flux, wasted), "fever" the chest (the ague), "sore" the feet. Chilled to the bone (LastingChill's) the tab
## adds.
func body_marks() -> Array:
	var out: Array = []
	var fester := is_on("festering")
	for w: Dictionary in wounds():
		var place := String(w.get("place", "chest"))
		var mark := "bruise" if String(w.kind) == "blunt" else ("dressed" if bool(w.get("dressed", false)) else
				("festering" if fester else "bleed"))
		var what: String = {"bruise": "Bruised", "dressed": "A dressed wound", "festering": "A festering wound",
				"bleed": "An open wound"}[mark]
		var txt := "%s, %s: %s" % [what, String(w.side), PLACE_COST.get(place, "")]
		if mark in ["dressed", "bruise"]:
			txt += " (%d%% knit)" % roundi(clampf(float(w.get("knit", 0.0)) / KNIT_MIN, 0.0, 1.0) * 100.0)
		else:
			txt += ". Dress it with a poultice or a salve"
		out.append({"region": String(w.region), "side": String(w.side), "mark": mark, "text": txt})
	if is_on("flux"):
		out.append({"region": "stomach", "side": "both", "mark": "sick", "text": "The flux: a meal nourishes half"})
	if is_on("wasted"):
		out.append({"region": "stomach", "side": "both", "mark": "sick", "text": "Wasted: heal no higher than 80%, learn slower"})
	if is_on("ague"):
		out.append({"region": "chest", "side": "both", "mark": "fever", "text": "The ague: " + RESTLESS_TEXT + ", heal at 70%"})
	if is_on("sore_feet"):
		for r: String in ["l_foot", "r_foot"]:
			out.append({"region": r, "side": "both", "mark": "sore", "text": "Sore feet: " + RESTLESS_TEXT})
	return out
