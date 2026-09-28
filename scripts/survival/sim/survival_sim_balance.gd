extends SurvivalSim
## Balance harness: SurvivalSim (survival_sim.gd) with the careful player's cooking habit. Used by
## tests/survival/run_balance_matrix.gd and tests/survival/test_survival_balance.gd.
##
## The base harness eats the best meal it carries, and when that is raw meat (a woodcutter lodging at the store with
## only venison and uncooked cornmeal) it eats the meat raw, which inflates queasiness. A careful player roasts raw
## meat at the camp fire or a building's hearth first; a careless one (policy "careless") still cannot, having no fire.
## Everything else is the base harness, so results stay comparable with tests/survival/test_survival_sim.gd.
##
##   var sim = preload("res://scripts/survival/sim/survival_sim_balance.gd").new()
##   sim.setup({"background": "bg.backcountry_hunter", "policy": "trapper", "days": 36, "seed": 1})
##   sim.simulate(36)
##   var report: Dictionary = sim.report()


## Is the best meal carried raw meat (or is there none), so that a careful player would cook first?
func _meal_needs_cooking() -> bool:
	var m := SurvivalFood.choose_meal(core)
	return m == "" or core.data.item_cat(m) == "meat_raw"


func _eat_something() -> void:
	if policy != "careless" and _meal_needs_cooking() and SurvivalFood.choose_to_cook(core) != "":
		_cook_something()
	super._eat_something()


func _eat_until_fed() -> void:
	for i in 3:
		if SurvivalNeeds.food_stage(core) == "fed" and SurvivalUtil.num(core.state.needs.get("stomach"), 0.0) > 2000.0:
			return
		if policy != "careless" and _meal_needs_cooking() and SurvivalFood.choose_to_cook(core) != "":
			_cook_something()
		if SurvivalFood.choose_meal(core) == "" and not _cook_something():
			return
		var r := core.run_job("eat")
		if not bool(r.get("ok", false)):
			return
