class_name LastingChill
extends Node
## Chilled to the bone (SurvivalBridge.chill; user 2026-09-27: "make hypothermia no dead just a status effect that has
## lasting damages"; "prolonged cold exposure should effect long term user until they warmed up and well rested
## consistently long enough"; picked lower max health and slower healing, "consistent well rested will heal the player",
## two game days):
##   the cold no longer kills  the core's drain at hypothermic and freezing stops at COLD_FLOOR health (SurvivalBridge:
##             _health_sync), and a core that died of the cold wakes again at it
##   exposure  game minutes at cold or worse, weighted (WEIGHT: very cold counts in full, hypothermic twice, freezing three
##             times, cold half); it fades at FADE a minute once warm again. At EXPOSURE_MIN (two hours very cold, one
##             hypothermic) the player is chilled to the bone
##   chilled   the health heals no higher than HEALTH_CAP of its max, and every heal (the body's own, well rested's, a
##             rest's or a sleep's refill, a poultice or a remedy) at HEAL_MULT
##   recovery  game minutes spent warm (comfortable) and well rested at once (by the day's healing sleep only:
##             SurvivalBridge.is_healing_rest, a nap does not count): RECOVER_MIN (two game days) end it; the
##             well-rested boost keeps healing all the while. Going cold again (cold or worse) sets it back to nothing;
##             warm but not rested only pauses it
## Only a sleep by a heat source rests in extreme cold (chilled, or a bitter night: SurvivalBridge.extreme_cold); a sleep
## by one is a warm rest, which drink, a hangover or hunger do not cap (SurvivalBridge.grant_rest).
## Kept in the core's flags ("chill"), saved with the core. The health bar shows the cap (FrontierHUD), the Condition tab
## the rest (ConditionPanel).

signal changed(on: bool)

const WEIGHT := {"cold": 0.5, "very_cold": 1.0, "hypothermic": 2.0, "freezing": 3.0}
const EXPOSURE_MIN := 120.0
const FADE := 0.5
const HEALTH_CAP := 0.7
const HEAL_MULT := 0.5
const RECOVER_MIN := 2.0 * 24.0 * 60.0
const COLD_FLOOR := 15.0
const LETHAL := ["hypothermic", "freezing"]

var bridge: SurvivalBridge
var _last_min := -1.0


## The record in the core's flags: {on, exposure, recover}.
func state() -> Dictionary:
	var core := bridge.core if bridge else null
	if core == null:
		return {"on": false, "exposure": 0.0, "recover": 0.0}
	if not (core.state.flags.get("chill") is Dictionary):
		core.state.flags["chill"] = {"on": false, "exposure": 0.0, "recover": 0.0}
	return core.state.flags.chill


func is_on() -> bool:
	return bool(state().get("on", false))


## The most the health heals to now.
func health_cap() -> float:
	var mx := float(bridge.player.max_health) if bridge and bridge.player else 100.0
	return mx * (HEALTH_CAP if is_on() else 1.0)


## Every heal's speed now.
func heal_mult() -> float:
	return HEAL_MULT if is_on() else 1.0


## 0..1 of the way back (the vitals' ring).
func recovery() -> float:
	return clampf(float(state().get("recover", 0.0)) / RECOVER_MIN, 0.0, 1.0)


## 0..1 of the way to it while not yet chilled (tests, the HUD).
func exposure() -> float:
	return clampf(float(state().get("exposure", 0.0)) / EXPOSURE_MIN, 0.0, 1.0)


## Whether the cold is at a stage that would drain the health (it stops at COLD_FLOOR).
func cold_drains() -> bool:
	return bridge.core != null and SurvivalNeeds.warmth_stage(bridge.core) in LETHAL


## A core just set back (a new or loaded game): the minutes count from it.
func reset_clock() -> void:
	_last_min = -1.0


## The game minutes since the last call: exposure, the chill, the recovery; the health held under the cap.
func tick() -> void:
	var core := bridge.core
	var p := bridge.player
	if core == null or p == null or p.is_dead:
		_last_min = -1.0
		return
	var m := core.state.minutes + float(core.state.world.get("clock_acc", 0.0))
	var dm := m - _last_min if _last_min >= 0.0 else 0.0
	_last_min = m
	if dm < 0.0 or dm > 24.0 * 60.0:
		dm = 0.0
	var st := state()
	var stage := SurvivalNeeds.warmth_stage(core)
	if WEIGHT.has(stage):
		st["exposure"] = float(st.get("exposure", 0.0)) + dm * float(WEIGHT[stage])
		if bool(st.get("on", false)) and float(st.get("recover", 0.0)) > 0.0:
			st["recover"] = 0.0
	else:
		if not bool(st.get("on", false)):
			st["exposure"] = maxf(float(st.get("exposure", 0.0)) - dm * FADE, 0.0)
		elif stage == "comfortable" and bridge.is_healing_rest():
			st["recover"] = float(st.get("recover", 0.0)) + dm
	if not bool(st.get("on", false)) and float(st.get("exposure", 0.0)) >= EXPOSURE_MIN:
		st["on"] = true
		st["recover"] = 0.0
		bridge._notice("Chilled to the bone: you heal slowly and no higher than %d%% until you have been warm and well rested for two days" % roundi(HEALTH_CAP * 100.0))
		changed.emit(true)
	elif bool(st.get("on", false)) and float(st.get("recover", 0.0)) >= RECOVER_MIN:
		st["on"] = false
		st["exposure"] = 0.0
		st["recover"] = 0.0
		bridge._notice("The cold has left your bones: you heal whole again")
		changed.emit(false)
	# the health never above the cap while chilled (whatever healed it)
	var cap := health_cap()
	if p.health > cap:
		p.health = cap
		if not core.is_dead():
			core.state.needs["health"] = p.health
