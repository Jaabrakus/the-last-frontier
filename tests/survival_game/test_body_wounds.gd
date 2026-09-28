extends SceneTree
## Wounds where they land, each place's cost, restless rest and healing once a day (LastingConditions, PlayerWounds,
## SurvivalBridge; user 2026-09-27: "we can see if someone got shot in the stomach", each place its own cost "inline with
## our current game" and not the movement speed, "allow rested by fires to make a user well rested but decays faster
## until they are well rested multiple times", "only once a day regain or healths"), on the level, headless:
##
##   Godot --headless --path . -s tests/survival_game/test_body_wounds.gd -- survival=on survival_seed=7
##
##   where     a point on each region's bones is that region; the trunk keeps a hit on its surface; front or back
##   kept      a hit of WOUND_MIN or more is kept where it landed (a scratch is not); bleeding open, a bruise knitting
##   places    head learns slower, chest heals to 80%, stomach half a meal, an arm a slower reload and a tiring grip, a
##             leg restless; never the speed or the sprint
##   knit      dressed, a wound knits in a day (the day's healing sleep counts double) and goes; a bruise without dressing
##   restless  away from a fire a sleep rests half; by one in full; the boost wears off twice as fast, eased a third by
##             each day's healing sleep (not a nap), starting over once whole
##   once      the day's first well-rested sleep heals; a second that day rests (skills) but does not heal
##   bites     a wolf bites low: legs mostly, never the head
##   shown     the outline's marks (front / back, festering), the Condition tab's rows and caption; saved with the core
## Ends with "BODY WOUNDS TEST OK (<n> checks)" or "BODY WOUNDS TEST FAILED <failures>/<n>".

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var lc: LastingConditions
var player: FrontierPlayer
var spot := Vector3(24.0, 0.0, 10.0)
var bleeder: Node
var club: Node

const FED := {"stomach": 2500.0, "warmth": 90.0, "wetness": 0.0}


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL ", what)
	else:
		print("  ok   ", what)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func settle(n := 3) -> void:
	for i in n:
		await process_frame
		await physics_frame


func pass_time(minutes: float, needs := {}) -> void:
	var left := minutes
	while left > 0.0:
		var m := minf(20.0, left)
		for k in needs:
			b.core.state.needs[k] = needs[k]
		b.core.invalidate_modifiers()
		b.core.advance(m)
		await settle(1)
		left -= m


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await frames(20)
	b = SurvivalBridge.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	lc = b.lasting if b else null
	check(b != null and player != null and lc != null, "the bridge has its lasting conditions (survival=on)")
	if lc == null:
		_end()
		return
	player.ignore_mouse_capture = true
	SurvivalWeather.set_external(b.core, "clear", 12.0, 300.0)
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	player.global_position = spot + Vector3.UP * 0.05
	bleeder = Node.new()
	bleeder.set_meta(&"damage_kind", "bleed")
	root.add_child(bleeder)
	club = Node.new()
	club.set_meta(&"damage_kind", "blunt")
	root.add_child(club)
	await frames(10)
	await _test_where()
	await _test_kept()
	await _test_places()
	await _test_knit()
	await _test_restless()
	await _test_once_a_day()
	_test_bites()
	await _test_shown()
	_end()


func _bone(name: String) -> Vector3:
	var sk := player.skeleton
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(name)).origin


func _mid(a: String, c: String) -> Vector3:
	return (_bone(a) + _bone(c)) * 0.5


## The player's forward (as the hit reactions have it: -Z of the body).
func _fwd() -> Vector3:
	return -player.global_basis.z


func _clear() -> void:
	lc.wounds().clear()
	player.wounds.clear()
	for id: String in LastingConditions.IDS:
		lc.state(id)["on"] = false
		lc.state(id)["exposure"] = 0.0
	lc.state("festering")["wound_min"] = -1.0
	b.core.state.flags.erase("restless_eased")
	player.health = player.max_health
	b.core.state.needs["health"] = player.health


## A hit of `dmg` at `point` from the front (or the back), by `src`.
func _hit(dmg: float, point: Vector3, src: Node, from_back := false) -> void:
	var dir := _fwd() if from_back else -_fwd()
	player.apply_hit(dmg, point, dir, src, "body")


func _test_where() -> void:
	for pair: Array in [["head", ["heada", "headb"]], ["chest", ["spinec", "spined"]], ["stomach", ["spinea", "spineb"]],
			["l_arm", ["l_shoulder", "l_elbow"]], ["r_arm", ["r_elbow", "r_wrist"]], ["l_hand", ["l_wrist", "l_palm"]],
			["l_leg", ["l_upper_leg", "l_knee"]], ["r_leg", ["r_knee", "r_ankle"]], ["r_foot", ["r_heel", "r_ball"]]]:
		var at := _mid(String(pair[1][0]), String(pair[1][1]))
		var got := PlayerWounds.region_at(player, at)
		check(got == pair[0], "a point on the %s's bones is the %s (%s)" % [pair[0], pair[0], got])
	var belly := _mid("spinea", "spineb") + _fwd() * 0.13
	check(PlayerWounds.region_at(player, belly) == "stomach", "a ball on the belly's surface is the stomach (%s)" % PlayerWounds.region_at(player, belly))
	check(PlayerWounds.side_of(player, -_fwd()) == "front" and PlayerWounds.side_of(player, _fwd()) == "back",
			"coming at the face: the front; at the back: the back")
	check(PlayerWounds.place_of("l_foot") == "l_leg" and PlayerWounds.place_of("r_hand") == "r_arm" and PlayerWounds.place_of("chest") == "chest",
			"a foot counts as its leg, a hand as its arm")


func _test_kept() -> void:
	_clear()
	_hit(5.0, _bone("l_knee"), bleeder)
	check(lc.wounds().is_empty(), "a scratch (5) is not kept")
	_hit(20.0, _bone("l_knee"), bleeder)
	var ws := lc.wounds()
	check(ws.size() == 1 and String(ws[0].region) == "l_leg" and String(ws[0].side) == "front" and String(ws[0].kind) == "bleed"
			and not bool(ws[0].dressed), "shot in the left knee from the front: an open wound kept there (%s)" % [ws])
	_hit(15.0, _mid("spineb", "spinec"), club, true)
	ws = lc.wounds()
	check(ws.size() == 2 and String(ws[1].region) == "stomach" and String(ws[1].side) == "back" and String(ws[1].kind) == "blunt"
			and bool(ws[1].dressed), "a blow in the back of the belly: a bruise, knitting from the start")
	player.wounds.clear()


func _test_places() -> void:
	_clear()
	await settle(2)
	var base_food := lc.food_mult()
	var base_skill := b.skill_mult()
	_hit(12.0, _mid("spinea", "spineb"), bleeder)
	_hit(12.0, _mid("heada", "headb"), bleeder)
	_hit(12.0, _mid("spinec", "spined"), bleeder)
	_hit(12.0, _mid("r_elbow", "r_wrist"), bleeder)
	_hit(12.0, _mid("l_knee", "l_ankle"), bleeder)
	player.wounds.clear()
	await pass_time(20.0, FED)
	check(absf(lc.food_mult() - LastingConditions.STOMACH_FOOD_MULT) < 0.001 and base_food == 1.0, "stomach: a meal nourishes half")
	check(absf(b.skill_mult() - base_skill * LastingConditions.HEAD_SKILL_MULT) < 0.001, "head: skills grow 25%% slower (%.2f)" % b.skill_mult())
	check(absf(b.health_cap() - player.max_health * LastingConditions.CHEST_CAP) < 0.01 and player.health <= b.health_cap() + 0.01,
			"chest: the health no higher than 80%% (%.0f)" % player.health)
	check(absf(player.reload_time_mult - LastingConditions.ARM_RELOAD_MULT) < 0.01, "an arm: the reload 15%% longer (x%.2f)" % player.reload_time_mult)
	check(player.grip == null or absf(player.grip.drain_mult - LastingConditions.ARM_GRIP_DRAIN) < 0.01, "an arm: the grip tires half again as fast")
	check(lc.restless(), "a leg: restless")
	check(player.sprint_allowed and player.survival_speed_mult > 0.99, "none of it touches the speed or the sprint (%.2f)" % player.survival_speed_mult)
	check(absf(player.aim_spread_mult - 1.0) < 0.001 and player.aim_sway < 0.001, "nor the aim")
	_clear()
	await pass_time(20.0, FED)
	check(absf(player.reload_time_mult - 1.0) < 0.01 and not lc.restless() and lc.food_mult() == 1.0, "gone: all as ever")


func _test_knit() -> void:
	_clear()
	_hit(20.0, _bone("l_elbow"), bleeder)
	player.wounds.clear()
	await pass_time(3.0 * 60.0, FED)
	check(lc.wounds().size() == 1 and float(lc.wounds()[0].knit) == 0.0, "not dressed: it does not knit")
	player.wounds.dress(1.0)
	check(bool(lc.wounds()[0].dressed), "a poultice dresses it")
	await pass_time(12.0 * 60.0, FED)
	check(lc.wounds().size() == 1, "half a day dressed: still knitting (%.0f%%)" % (float(lc.wounds()[0].knit) / LastingConditions.KNIT_MIN * 100.0))
	await pass_time(12.5 * 60.0, FED)
	check(lc.wounds().is_empty() and player.interactor._notice.text.contains("has knit"), "a day: knit and gone (%s)" % player.interactor._notice.text)
	# the day's healing sleep counts double
	_hit(20.0, _bone("r_knee"), club)
	b.core.state.flags["well_rested_until"] = b.core.state.minutes + 20.0 * 60.0
	b.core.state.flags["heal_rest_until"] = b.core.state.minutes + 20.0 * 60.0
	await pass_time(12.5 * 60.0, FED)
	check(lc.wounds().is_empty(), "a bruise, well rested by the day's sleep: knit in half a day")
	b.core.state.flags.erase("well_rested_until")


func _test_restless() -> void:
	_clear()
	_hit(20.0, _bone("r_knee"), bleeder)
	player.wounds.clear()
	var full := SurvivalBridge.rest_earned_h(8.0, 0.8)
	check(absf(lc.rest_mult() - 0.5) < 0.001 and lc.rest_mult(true) == 1.0, "away from a fire a sleep rests half; by one in full")
	check(absf(lc.rest_drain_mult() - 2.0) < 0.001, "the boost wears off twice as fast")
	lc.slept(8.0, true)
	check(absf(lc.rest_drain_mult() - (1.0 + 2.0 / 3.0)) < 0.01, "a day's healing sleep eases it a third (x%.2f)" % lc.rest_drain_mult())
	lc.slept(3.0, false)
	check(absf(lc.rest_drain_mult() - (1.0 + 2.0 / 3.0)) < 0.01, "a nap does not")
	lc.slept(8.0, true)
	lc.slept(8.0, true)
	check(absf(lc.rest_drain_mult() - 1.0) < 0.001, "three days' sleep: as ever")
	# the drain on the clock
	b.core.state.flags.erase("restless_eased")
	b.core.state.flags["well_rested_until"] = b.core.state.minutes + 600.0
	var left0 := b.rested_hours_left()
	await pass_time(60.0, FED)
	var used := (left0 - b.rested_hours_left()) * 60.0
	var fed_drain := float(SurvivalBridge.REST_DRAIN.fed)
	check(absf(used - 60.0 * fed_drain * 2.0) < 6.0, "an hour restless and fed: %.0f minutes of boost gone (not %.0f)" % [used, 60.0 * fed_drain])
	var h_away := b.grant_rest(8.0, 0.8, false)
	b.core.state.flags.erase("well_rested_until")
	var h_fire := b.grant_rest(8.0, 0.8, true)
	check(absf(h_away - full * 0.5) < 0.01 and absf(h_fire - full) < 0.01, "a night away from a fire earns %.1f h, by one %.1f h" % [h_away, h_fire])
	player.wounds.dress(1.0)
	lc.wounds().clear()
	await pass_time(20.0, FED)
	check(not lc.restless() and not b.core.state.flags.has("restless_eased"), "whole again: the easing starts over")
	b.core.state.flags.erase("well_rested_until")
	b.core.state.flags.erase("warm_rest_until")


func _test_once_a_day() -> void:
	_clear()
	var f := b.core.state.flags
	f.erase("well_rested_until")
	f["heal_rest_at"] = b.core.state.minutes - SurvivalBridge.HEAL_REST_GAP_H * 60.0 - 1.0
	var h := b.grant_rest(8.0, 0.8, true)
	check(h > 0.0 and b.last_rest_healed and b.is_healing_rest(), "the day's first sleep: well rested, and it heals")
	var until0 := float(f.heal_rest_until)
	var heal_on := b.heal_item_mult()
	check(heal_on > b.heal_mult() + 0.01, "remedies stronger (x%.2f)" % heal_on)
	# the boost spent, a nap the same day
	f["well_rested_until"] = b.core.state.minutes - 1.0
	f["heal_rest_until"] = b.core.state.minutes - 1.0
	var h2 := b.grant_rest(3.0, 0.8, true)
	check(h2 > 0.0 and not b.last_rest_healed and b.is_well_rested() and not b.is_healing_rest(),
			"a nap later that day: well rested again, but no healing")
	check(not b.heal_rest_due(), "the next healing sleep not due for %d hours" % roundi(SurvivalBridge.HEAL_REST_GAP_H))
	check(absf(b.heal_item_mult() - b.heal_mult()) < 0.001 and absf(b.skill_mult() - SurvivalBridge.REST_SKILL_MULT) < 0.001,
			"remedies as ever; skills still faster")
	b.sleeper.resting = true
	var fill_nap := b.sleeper.fill_rate()
	f["heal_rest_until"] = f.well_rested_until
	var fill_heal := b.sleeper.fill_rate()
	b.sleeper.resting = false
	check(fill_heal > fill_nap * 1.2, "sitting down refills faster only by the healing sleep (%.4f / %.4f)" % [fill_heal, fill_nap])
	# health: an hour of the nap's boost heals no faster than none
	player.health = 50.0
	b.core.state.needs["health"] = 50.0
	b._health = b.core.health()
	f["heal_rest_until"] = b.core.state.minutes - 1.0
	f["well_rested_until"] = b.core.state.minutes + 600.0
	await pass_time(60.0, FED)
	var gained := player.health - 50.0
	check(gained >= 0.0 and gained < SurvivalNeeds.HEALTH_REGEN_PER_H * 1.5, "an hour well rested by a nap: the body's own healing only (+%.2f)" % gained)
	# and by the day's sleep, three times that
	player.health = 50.0
	b.core.state.needs["health"] = 50.0
	b._health = b.core.health()
	f["heal_rest_until"] = f.well_rested_until
	await pass_time(60.0, FED)
	check(player.health - 50.0 > gained + SurvivalNeeds.HEALTH_REGEN_PER_H, "by the day's sleep it heals faster (+%.2f)" % (player.health - 50.0))
	# a nap cut short by hunger: its healing ends with it (a later nap does not take up the rest)
	f["heal_rest_at"] = b.core.state.minutes - SurvivalBridge.HEAL_REST_GAP_H * 60.0 - 1.0
	b.grant_rest(8.0, 0.8, true)
	b.core.state.needs["stomach"] = 0.0
	b.core.state.needs["reserve"] = 0.0
	await pass_time(40.0)
	var hr := float(f.heal_rest_until)
	check(hr <= float(f.well_rested_until) + 0.01, "the healing ends with its boost (%.0f / %.0f)" % [hr, float(f.well_rested_until)])
	b.core.state.needs["reserve"] = 2000.0
	# the next day's sleep (16 hours on) heals again
	f["heal_rest_at"] = b.core.state.minutes - SurvivalBridge.HEAL_REST_GAP_H * 60.0 - 1.0
	b.grant_rest(8.0, 0.8, true)
	check(b.last_rest_healed and b.is_healing_rest() and until0 > 0.0, "the next day's sleep heals again")
	f.erase("well_rested_until")
	f.erase("warm_rest_until")


func _test_bites() -> void:
	var wa := WildAnimal.new()
	wa.species = "wolf"
	wa.rng.seed = 11
	var dir := -_fwd()
	var counts := {}
	for i in 60:
		var r := PlayerWounds.region_at(player, wa._strike_point(player, dir))
		counts[r] = int(counts.get(r, 0)) + 1
	var legs := int(counts.get("l_leg", 0)) + int(counts.get("r_leg", 0)) + int(counts.get("l_foot", 0)) + int(counts.get("r_foot", 0))
	check(legs >= 25 and not counts.has("head"), "a wolf bites low: %d of 60 on the legs, none on the head %s" % [legs, counts])
	wa.free()


func _test_shown() -> void:
	_clear()
	_hit(20.0, _bone("l_knee"), bleeder)
	_hit(20.0, _mid("spinea", "spineb"), club, true)
	player.wounds.clear()
	lc.state("flux")["on"] = true
	var ms := lc.body_marks()
	check(ms.any(func(m: Dictionary) -> bool: return m.region == "l_leg" and m.side == "front" and m.mark == "bleed"),
			"the outline: the left leg's open wound, on the front")
	check(ms.any(func(m: Dictionary) -> bool: return m.region == "stomach" and m.side == "back" and m.mark == "bruise")
			and ms.any(func(m: Dictionary) -> bool: return m.region == "stomach" and m.side == "both" and m.mark == "sick"),
			"the bruise on the back of the belly, the flux on the stomach")
	lc.state("festering")["on"] = true
	check(lc.body_marks().any(func(m: Dictionary) -> bool: return m.region == "l_leg" and m.mark == "festering"), "festering: the undressed wound")
	lc.state("festering")["on"] = false
	check(BodyChart.region_of("a_leg", "front") == "r_leg" and BodyChart.region_of("a_leg", "back") == "l_leg",
			"the front view has the body's right on the viewer's left, the back its left")
	var panel := ConditionPanel.make(player)
	root.add_child(panel)
	await settle(2)
	var chart := panel.find_child("BodyChart", true, false) as BodyChart
	check(chart != null and chart.worst_at("l_leg", "front") == "bleed" and chart.worst_at("l_leg", "back") == ""
			and chart.worst_at("stomach", "back") == "bruise" and chart.worst_at("stomach", "front") == "sick",
			"the tab's outline: the leg's wound in front only, the bruise over the sickness behind")
	chart._set_hover("l_leg", "front")
	check(panel._caption.text.contains("Left leg") and panel._caption.text.contains("open wound"), "the mouse on the leg: what it is (%s)" % panel._caption.text)
	var names := panel.lasting_rows(b).map(func(r: Array) -> String: return String(r[0]))
	check("Left leg" in names and "Stomach" in names, "the Lasting harm rows: %s" % [names])
	panel.queue_free()
	var doc := b.save_state()
	lc.wounds().clear()
	b.load_state(doc)
	await settle(3)
	check(lc.wounds().size() == 2 and lc.has_wound("l_leg"), "saved with the core, back on a load")
	lc.state("flux")["on"] = false
	_clear()


func _end() -> void:
	if is_instance_valid(bleeder):
		bleeder.queue_free()
	if is_instance_valid(club):
		club.queue_free()
	if fails.is_empty():
		print("BODY WOUNDS TEST OK (%d checks)" % checks)
	else:
		print("BODY WOUNDS TEST FAILED (%d of %d): %s" % [fails.size(), checks, fails])
	quit(0 if fails.is_empty() else 1)
