class_name ItemInfo
extends RefCounted
## What a pack item is and what it does, for the character screen (user 2026-09-27: "the stats should highlight what
## they do ... like walnut and strawberry"): a tag and a line of what it is (data/items/item_text.json), then stat
## rows worked out from the game's own data, each [label, value, tone]:
##   food      how much of a meal one fills and the pack's all together (the survival core's kcal through
##             data/survival/game_items.json; food shows in meals, never kcal: needs.json food.display); must be
##             cooked, too bitter, raw and risky
##   herbs     what a poultice heals (data/forage/forage.json use)
##   remedies  what the alchemy table's salve, tea and tonic do (Remedies); what a station makes of an item (the
##             tanning frame, the alchemy table, the drying rack: CampStation)
##   weapons   damage, reload, what is carried (the player's own weapons)
##   tools     the skill it trains and the player's level in it (data/gathering/gathering.json)
##   materials the build pieces it goes into (data/building/building.json); firewood's burn in a campfire, the
##             torch's (game time)
##   use       the mouse on the pack: right-click to eat, dress a wound, take a torch; double-click to wear
##
##   var info := ItemInfo.of("strawberries", player)   # {name, tag, text, rows: [[label, value, tone], ...]}
##
## Tones: GOOD (what it gives), WARN (a catch), USE (how to use it), "" (plain).

const TEXT_PATH := "res://data/items/item_text.json"
const GAME_ITEMS := "res://data/survival/game_items.json"
const CORE_ITEMS := "res://data/survival/items.json"
const NEEDS := "res://data/survival/needs.json"
const GATHERING := "res://data/gathering/gathering.json"
const GOOD := "good"
const WARN := "warn"
const USE := "use"
## The pieces an item is a cost of, most shown.
const BUILDS_SHOWN := 3
## What one pack unit of a food is called ("one handful: 1% of a meal"); the core's unit otherwise.
const UNIT := {"venison": "cut", "roast_venison": "cut", "charred_venison": "cut", "jerky": "pound", "cornmeal": "pound",
		"johnnycake": "cake", "burnt_johnnycake": "cake"}

static var _text := {}
static var _food := {}
static var _meal := 0.0
static var _tools := {}


static func _json(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return d if d is Dictionary else {}


static func _load() -> void:
	if not _text.is_empty():
		return
	_text = _json(TEXT_PATH).get("items", {})
	# food: the pack kind -> {kcal of one pack unit, needs_cooking, edible, raw_risk, unit}
	var core := {}
	for it: Dictionary in _json(CORE_ITEMS).get("items", []):
		core[String(it.get("id", ""))] = it
	var gi: Dictionary = _json(GAME_ITEMS).get("items", {})
	for k: String in gi:
		var row: Dictionary = core.get(String(gi[k].item), {})
		var qty := float(gi[k].get("qty", 1.0))
		_food[k] = {"kcal": float(row.get("kcal", 0.0)) * qty, "cook": bool(row.get("needs_cooking", false)),
				"edible": bool(row.get("edible", true)), "raw_risk": row.get("raw_risk", {}),
				"unit": String(UNIT.get(k, row.get("unit", "piece")))}
	_meal = float((_json(NEEDS).get("food", {}) as Dictionary).get("meal_game_kcal", 800.0))
	_tools = _json(GATHERING).get("tools", {})


static func tag_of(kind: String) -> String:
	_load()
	return String((_text.get(kind, {}) as Dictionary).get("tag", ""))


## Everything the screen shows about `kind` (the pack's `count` of it; `player` for the live figures: the weapons,
## skills, the survival bridge; may be null).
static func of(kind: String, player: Node, count := 0) -> Dictionary:
	_load()
	var t: Dictionary = _text.get(kind, {})
	var rows: Array = []
	var tree: SceneTree = player.get_tree() if player and player.is_inside_tree() else null
	_food_rows(kind, count, tree, rows)
	_herb_rows(kind, tree, rows)
	_remedy_rows(kind, tree, rows)
	_station_rows(kind, rows)
	_weapon_rows(kind, player, rows)
	_tool_rows(kind, player, rows)
	_material_rows(kind, tree, rows)
	_vice_rows(kind, rows)
	_use_rows(kind, tree, rows)
	_climb_rows(kind, rows)
	return {"name": InventoryState.name_of(kind), "tag": String(t.get("tag", "")), "text": String(t.get("text", "")),
			"history": String(t.get("history", "")), "rows": rows}


# --- the rows -----------------------------------------------------------------------------------------

## Climbing gear (loadout_items.json climbing_stakes_* / climbing_claws_*: climb.drain_mult, climb.hang_drain_mult).
static func _climb_rows(kind: String, rows: Array) -> void:
	var climb: Dictionary = LoadoutData.get_default().kind(kind).get("climb", {})
	if climb.has("drain_mult"):
		rows.append(["Climb", "the grip tires at x%s the rate while you hold on (stakes in the fists)" % str(climb.drain_mult), GOOD])
	if climb.has("hang_drain_mult"):
		rows.append(["Climb", "hanging still costs x%s of the grip (claws under the feet)" % str(climb.hang_drain_mult), GOOD])
	if kind.begins_with("climbing_stakes_"):
		rows.append(["Carried", "on the belt or sash, behind the left hip", ""])


static func _food_rows(kind: String, count: int, tree: SceneTree, rows: Array) -> void:
	if not _food.has(kind):
		return
	var f: Dictionary = _food[kind]
	var br := SurvivalBridge.find(tree) if tree else null
	var kcal := br.unit_kcal(kind) if br and br.can_eat(kind) else float(f.kcal)
	var share := kcal / maxf(_meal, 1.0)
	var each := "one %s: %s of a meal" % [String(f.unit), _meal_part(share)]
	rows.append(["Food", each + ("   ·   all %d: %s" % [count, _meal_part(share * count)] if count > 1 else ""),
			GOOD if f.edible and not f.cook else ""])
	if kind in CampCooking.RAW:
		var cooked := InventoryState.name_of(String(CampCooking.COOKED[kind].cooked)).to_lower()
		rows.append(["Cook", ("must be cooked first: " if f.cook else "") + "F at a lit campfire makes it %s" % cooked,
				WARN if f.cook else USE])
	elif f.cook:
		rows.append(["Cook", "must be cooked before it can be eaten", WARN])
	if kind.begins_with("burnt_") or kind.begins_with("charred_"):
		rows.append(["Burnt", "half the food it would have been", WARN])
	if not f.edible:
		rows.append(["Bitter", "cannot be eaten until leached", WARN])
	var risk: Dictionary = f.raw_risk
	if not risk.is_empty():
		var p := 0.0
		for v: Variant in risk.values():
			p = maxf(p, float(v))
		rows.append(["Raw", "1 in %d turns the stomach" % roundi(1.0 / maxf(p, 0.001)), WARN])


## A share of a meal in words a player reads at a glance: "1%", "35%", "a whole meal", "2 meals".
static func _meal_part(share: float) -> String:
	if share >= 1.75:
		return "%s meals" % (str(roundi(share)) if share >= 3.0 else "%.1f" % share)
	if share >= 0.9:
		return "a whole meal"
	if share < 0.01:
		return "under 1%"
	return "%d%%" % roundi(share * 100.0)


static func _herb_rows(kind: String, tree: SceneTree, rows: Array) -> void:
	var u := ForageUse._use_of(kind)
	if u.is_empty():
		return
	var k := SurvivalBridge.heal_item_mult_in(tree) if tree else 1.0
	rows.append(["Heals", "%d health over %d s, laid on a wound%s" % [roundi(float(u.get("heal", 15.0)) * k),
			int(u.get("over_s", 20.0)), "  (more when well rested)" if k <= 1.0 else "  (well rested: more)"], GOOD])


static func _remedy_rows(kind: String, tree: SceneTree, rows: Array) -> void:
	var u: Dictionary = Remedies.USE.get(kind, {})
	if u.is_empty():
		return
	var k := SurvivalBridge.heal_item_mult_in(tree) if tree else 1.0
	if u.has("warmth"):
		rows.append(["Warms", "hot: the cold goes out of you", GOOD])
	if u.has("heal"):
		rows.append(["Heals", "%d health over %d s%s" % [roundi(float(u.heal) * k), int(u.over_s), "  (well rested: more)" if k > 1.0 else ""], GOOD])
	if u.has("rested_h"):
		rows.append(["Rested", "%d hours more of well rested (heal and learn faster)" % int(u.rested_h), GOOD])


## What a station makes of it (CampStation).
static func _station_rows(kind: String, rows: Array) -> void:
	for id: String in Remedies.RECIPES:
		var ins: Dictionary = Remedies.RECIPES[id].inputs
		if ins.has(kind):
			rows.append(["Alchemy table", "%d make a %s" % [int(ins[kind]), InventoryState.name_of(id).to_lower()], ""])
	match kind:
		"deer_hide":
			rows.append(["Tanning frame", "buckskin (with brains or cornmeal, by a fire) or 2 rawhide", ""])
		"brains":
			rows.append(["Tanning frame", "dresses a deer hide into buckskin", ""])
		"venison":
			rows.append(["Drying rack", "hung over a fire: jerky in a day or two", ""])
		"wolf_pelt", "fox_pelt":
			rows.append(["Stretching hoop", "laced and fleshed, dried in two or three days: graded better", ""])
			rows.append(["Workbench", "fur mitts, with a sinew", ""])
		"dried_wolf_pelt", "dried_fox_pelt":
			rows.append(["Workbench", "fur mitts, with a sinew", ""])
		"elm_bark", "dogwood_bark":
			rows.append(["Knapping stone", "twisted into cordage, two barks for two lengths", ""])
		"marten_pelt", "mink_pelt", "fisher_pelt", "raccoon_pelt":
			rows.append(["Stretching hoop", "laced and fleshed, dried in two or three days: graded better", ""])
		"small_game":
			rows.append(["Campfire", "roasted: safe to eat", ""])
		"buckskin":
			rows.append(["Workbench", "a third of one and a sinew: a pair of moccasins", ""])
		"sinew":
			rows.append(["Workbench", "the thread of moccasins and mitts; mends worn moccasins", ""])
		"branches":
			rows.append(["Workbench", "2 and a flint: 6 arrows, or 2 atlatl darts", ""])
		"flint":
			rows.append(["Workbench", "points for arrows, darts and a throwing spear", ""])
			rows.append(["Knapping stone", "a flint knife (with a branch and a cord); two make a stone axe", ""])
		"pole":
			rows.append(["Workbench", "with a flint: a throwing spear", ""])
			rows.append(["Knapping stone", "a stone axe (with two flints and a cord), or a spear with a chert point", ""])


static func _weapon_of(kind: String, player: Node) -> Weapon:
	var ws: Variant = player.get("weapons") if player else null
	if not (ws is Dictionary):
		return null
	var key := "atlatl" if kind == "dart_bundle" else ""
	for k: String in InventoryState.KIND_OF_KEY:
		if InventoryState.KIND_OF_KEY[k] == kind:
			key = k
	return (ws as Dictionary).get(key) as Weapon


static func _weapon_rows(kind: String, player: Node, rows: Array) -> void:
	var w := _weapon_of(kind, player)
	if w == null:
		return
	if w is Firearm:
		var f := w as Firearm
		rows.append(["Damage", "%d a ball" % roundi(f.damage), GOOD])
		var s := 0.0
		for st: Variant in f.reload_stages:
			if st is Array and (st as Array).size() >= 2:
				s += float(st[1])
		if s > 0.0:
			rows.append(["Reload", "%d s, standing or crouched" % roundi(s), ""])
		rows.append(["Carried", "%d cartridges" % f.reserve, ""])
	elif w is Bow:
		var b := w as Bow
		rows.append(["Damage", "%d to %d, by how far it is drawn" % [roundi(b.min_damage), roundi(b.max_damage)], GOOD])
		rows.append(["Draw", "%.1f s to full draw; it tires after %d s held" % [b.draw_time, roundi(b.fatigue_start)], ""])
	elif w is Throwable:
		var t := w as Throwable
		rows.append(["Damage", "%d to %d, by how hard it is thrown" % [roundi(t.min_damage), roundi(t.max_damage)], GOOD])


static func _tool_rows(kind: String, player: Node, rows: Array) -> void:
	var does := {"felling_axe": "fells trees and saplings, limbs and bucks them; cuts openings in log walls",
			"mattock": "breaks stone from outcrops and boulders; digs flint",
			"hoe": "breaks open ground for a bed and hoes out the weeds (farming)",
			"digging_stick": "breaks ground for a bed and weeds it, at half a hoe's bite",
			"skinning_knife": "skins and butchers game you have killed",
			"fire_steel": "lights a campfire or a torch, struck on flint"}
	if does.has(kind):
		rows.append(["Does", String(does[kind]), GOOD])
	if not _tools.has(kind):
		return
	var sk := String((_tools[kind] as Dictionary).get("skill", ""))
	var g: Variant = player.get("gather") if player else null
	if sk != "" and g is GatherTools and (g as GatherTools).skills:
		var nm := String((g as GatherTools).data.skill(sk).get("name", sk.capitalize()))
		rows.append(["Skill", "%s, level %d" % [nm, (g as GatherTools).skills.level(sk)], ""])
	rows.append(["Take out", "7 (again for the next tool)", USE])


static func _material_rows(kind: String, tree: SceneTree, rows: Array) -> void:
	var hour_s := float(ForageField.load_data().get("game_day_s", 3456.0)) / 24.0
	if kind == "firewood":
		# on the survival core's clock (CampLink) a stick burns FUEL_MIN_PER_WOOD game minutes; without it, real seconds
		var linked := tree != null and SurvivalBridge.find(tree) != null
		var h := Campfire.FUEL_MIN_PER_WOOD / 60.0 if linked else Campfire.FUEL_PER_WOOD / hour_s
		rows.append(["Fuel", "a stick burns %s in a campfire" % _game_time(h), GOOD])
	elif kind == "torch":
		rows.append(["Burns", "%s, lit" % _game_time(TorchState.BURN_S / hour_s), GOOD])
	elif kind == "flint":
		rows.append(["Fire", "lights a campfire, struck with steel", GOOD])
	var bd := BuildData.get_default()
	var names := PackedStringArray()
	for id: String in bd.order:
		var pc: Dictionary = bd.pieces.get(id, {})
		var cost: Dictionary = pc.get("cost", {})
		if cost.has(kind) and not id.begins_with("opening_"):
			names.append("%s (%d)" % [String(pc.get("name", id)), int(cost[kind])])
	if names.is_empty():
		return
	var more := names.size() - BUILDS_SHOWN
	rows.append(["Builds", ", ".join(names.slice(0, BUILDS_SHOWN)) + (" and %d more" % more if more > 0 else ""), GOOD])


## Game hours and minutes: "2 h 30 min", "1 h 40 min", "45 min".
static func _game_time(h: float) -> String:
	var m := roundi(h * 60.0 / 5.0) * 5
	if m < 60:
		return "%d min" % m
	return "%d h%s" % [m / 60, (" %d min" % (m % 60)) if m % 60 != 0 else ""]


## Drink and tobacco (Vices): what a little does, the catch, the habit.
static func _vice_rows(kind: String, rows: Array) -> void:
	match kind:
		"rum":
			rows.append(["A little", "merry: " + Vices.merry_words(), GOOD])
			rows.append(["Catch", "no well-rested boost while it is in you; too much and your aim goes", WARN])
			rows.append(["Habit", "a dram a day is safe; more, and it takes hold", WARN])
		"tobacco":
			rows.append(["A pipe", "steady hands: %s, for a couple of hours" % Vices.steady_words(), GOOD])
			rows.append(["Needs", "a clay pipe", ""])
			rows.append(["Catch", "too many close together turn your stomach", WARN])
			rows.append(["Habit", "a pipe a day is safe; more, and it takes hold", WARN])
		"clay_pipe":
			rows.append(["Smokes", "tobacco, kinnikinnick, hemp tops, jimsonweed (hold Y)", USE])
		"whiskey":
			rows.append(["A little", "merry quickly (%s), and it warms you" % Vices.merry_words(), GOOD])
			rows.append(["Catch", "twice rum's strength: drunk comes fast, and your aim goes", WARN])
			rows.append(["Habit", "takes hold quicker than rum", WARN])
		"cider":
			rows.append(["A little", "slow to make you merry (%s); a little food" % Vices.merry_words(), GOOD])
			rows.append(["Catch", "enough of it and you are drunk all the same", WARN])
			rows.append(["Habit", "the drink's, slowly", WARN])
		"sweet_cider":
			rows.append(["Now", "pressed crabapples: a little food, no drink", GOOD])
			rows.append(["In time", "hard cider two days after pressing, in the pack", ""])
		"laudanum":
			rows.append(["A few drops", "%s, for %d hours" % [Vices.laudanum_words(), roundi(Vices.LAUD_H)], GOOD])
			rows.append(["Catch", "you learn slower while it is in you; a second dose within %d hours knocks you out" % roundi(Vices.LAUD_OVERDOSE_H), WARN])
			rows.append(["Habit", "the strongest there is", WARN])
		"snuff":
			rows.append(["A pinch", "steady hands at once (%s), for about an hour; no pipe, no fire" % Vices.steady_words(), GOOD])
			rows.append(["Habit", "the tobacco's", WARN])
		"chew":
			rows.append(["A quid", "steady hands (%s) for %d hours" % [Vices.steady_words(), roundi(Vices.CHEW_H)], GOOD])
			rows.append(["Catch", "food nourishes less while you chew", WARN])
			rows.append(["Habit", "the tobacco's", WARN])
		"kinnikinnick":
			rows.append(["A pipe", "steady hands (%s) for half as long as tobacco, and no habit" % Vices.steady_words(), GOOD])
		"kinnikinnick_mix":
			rows.append(["A pipe", "steady hands (%s), most of tobacco's while, for a light habit" % Vices.steady_words(), GOOD])
		"hemp_tops":
			rows.append(["A pipe", "calm: " + Vices.calm_words(), GOOD])
			rows.append(["Catch", "hungry sooner; you learn slower while calm", WARN])
			rows.append(["Habit", "a mild one of its own", WARN])
		"jimsonweed":
			rows.append(["A leaf", "smoked, it eases the ague's fever: half a day nearer mended", GOOD])
			rows.append(["Catch", "any more is hours of madness; a lot and you collapse", WARN])


static func _use_rows(kind: String, tree: SceneTree, rows: Array) -> void:
	var br := SurvivalBridge.find(tree) if tree else null
	if br and br.can_eat(kind):
		var why := br.why_not(kind)
		rows.append(["Right-click", "eat one" if why == "" else why.substr(0, 1).to_lower() + why.substr(1), USE if why == "" else WARN])
	elif not ForageUse._use_of(kind).is_empty():
		rows.append(["Right-click", "dress a wound", USE])
	elif Remedies.can_use(kind):
		rows.append(["Right-click", "dress a wound" if kind == "plantain_salve" else "drink it", USE])
	elif kind == InventoryState.TORCH:
		rows.append(["Right-click", "take one in hand when you close the pack (T in play)", USE])
	elif Vices.can_use(kind):
		rows.append(["Right-click", {"laudanum": "take a few drops", "snuff": "take a pinch", "chew": "put a quid in"}[kind], USE])
	elif Vices.DRINKS.has(kind):
		rows.append(["Right-click", "take it in hand; hold U to drink, as long or as short a pull as you like", USE])
	elif Vices.FILLS.has(kind):
		rows.append(["Right-click", "pack your pipe with it; hold Y to smoke", USE])
