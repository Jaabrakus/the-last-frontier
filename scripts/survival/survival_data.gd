class_name SurvivalData
extends RefCounted
## Loads and indexes the survival design data (data/survival/*.json, schema version 4).
##
## By default only the LIVE files are read: the vertical slice, milestones M1, M2a and M2b. load_dir() can also merge rows of
## chosen later milestones from data/survival/backlog/*.json (for example ["M3"] for fishing, frogs, foraging and the
## remaining camp crafts) so systems can be exercised before a milestone officially goes live. Live rows always win:
## an id is defined in exactly one place (id_rules in every file), so a merge never replaces a live row.
##
## The data is read-only after load. Every number used by the survival modules comes from here; the few design values
## the code adds itself are named constants tagged [D] where they are defined.
## Design: source/graph_analysis/survival/survival_gdd.md

const DEFAULT_DIR := "res://data/survival/"
const BACKLOG_SUBDIR := "backlog/"
const SCHEMA_VERSION := 4
const FILES := ["skills", "backgrounds", "needs", "conditions", "items", "recipes", "actions",
		"seasons", "economy", "livelihoods", "npcs", "map_regions"]
## Row lists merged from the backlog, per file. Goods are keyed by "item"; forage and fish runs have no id.
const MERGE_LISTS := {
	"actions": ["actions", "anim_hooks"],
	"items": ["items", "clothing_classes"],
	"conditions": ["conditions"],
	"backgrounds": ["backgrounds", "long_term_goals"],
	"needs": ["needs"],
	"skills": ["skills", "modifiers", "knowledge"],
	"recipes": ["recipes"],
	"economy": ["markets", "goods", "wages", "services"],
	"seasons": ["events", "eras", "forage", "fish_runs"],
	"livelihoods": ["livelihoods", "jobs"],
	"npcs": ["factions", "archetypes", "individuals", "dialogue_topics"],
	"map_regions": ["regions", "resource_nodes"],
}

var dir := DEFAULT_DIR
var raw := {}                       ## file name -> parsed live dictionary (with merged backlog rows)
var errors := PackedStringArray()
var merged_milestones := PackedStringArray()
var merged_rows := 0

var actions := {}
var anim_hooks := {}
var items := {}
var clothing := {}
var conditions := {}
var needs := {}
var skills := {}
var check_mods := {}
var knowledge := {}
var backgrounds := {}
var recipes := {}
var recipes_by_action := {}
var goods := {}
var markets := {}
var wages := {}
var services := {}
var jobs := {}
var livelihoods := {}
var events := {}
var eras := {}
var months := {}
var month_ids: Array = []
var day_ids: Array = []
var weather_states := {}
var modifier_keys := {}
var archetypes := {}
var individuals := {}
var factions := {}
var regions := {}
var resource_nodes := {}
var forage: Array = []
var fish_runs: Array = []
var habits := {}
var start_variants := {}
var trade_behaviours := {}
## Recipes by the item they make (for examining a finished thing and the recipe book).
var recipes_by_output := {}
## Every knowledge id a recipe or technique action is kept under (skills.json knowledge_model.id_rule).
var knowledge_ids := {}


## Load a data directory. opts:
##   backlog_milestones: Array of milestone tags to merge from the backlog (e.g. ["M3"]); default none.
static func load_dir(path: String = DEFAULT_DIR, opts: Dictionary = {}) -> SurvivalData:
	var d := SurvivalData.new()
	d.dir = path if path.ends_with("/") else path + "/"
	d._load(opts)
	return d


func is_ok() -> bool:
	return errors.is_empty()


func _load(opts: Dictionary) -> void:
	for f in FILES:
		var parsed = _read_json(dir + f + ".json")
		if parsed == null:
			continue
		if int(SurvivalUtil.num(parsed.get("version"), 0.0)) != SCHEMA_VERSION:
			errors.append("%s.json: schema version must be %d" % [f, SCHEMA_VERSION])
		raw[f] = parsed
	if not errors.is_empty():
		return
	var ms: Array = SurvivalUtil.arr(opts.get("backlog_milestones", []))
	if not ms.is_empty():
		_merge_backlog(ms)
	_index()


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		errors.append("missing " + path)
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("cannot parse " + path)
		return null
	return parsed


func _merge_backlog(ms: Array) -> void:
	for m in ms:
		merged_milestones.append(str(m))
	for f in FILES:
		var path: String = dir + BACKLOG_SUBDIR + f + ".json"
		if not FileAccess.file_exists(path):
			continue
		var back = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(back) != TYPE_DICTIONARY:
			errors.append("cannot parse " + path)
			continue
		var live: Dictionary = raw[f]
		for list_name in MERGE_LISTS.get(f, []):
			if not back.has(list_name) or typeof(back[list_name]) != TYPE_ARRAY:
				continue
			if not live.has(list_name) or typeof(live[list_name]) != TYPE_ARRAY:
				live[list_name] = []
			var have := {}
			for r in live[list_name]:
				if typeof(r) == TYPE_DICTIONARY:
					have[_row_key(r)] = true
			for r in back[list_name]:
				if typeof(r) != TYPE_DICTIONARY:
					continue
				if not ms.has(str(r.get("milestone", ""))):
					continue
				var k := _row_key(r)
				if k != "" and have.has(k):
					continue
				if f == "actions" and list_name == "actions":
					r = _remap_backlog_action(r)
				live[list_name].append(r)
				have[k] = true
				merged_rows += 1
		# Dictionary sections later rows depend on: add missing keys only (live values win).
		match f:
			"items":
				_merge_missing(live, back, ["spoilage_classes", "classes"])
			"actions":
				_merge_missing(live, back, ["world_objects"])
				_merge_missing(live, back, ["carcass_yields"])
			"economy":
				_merge_missing(live, back, ["price_profiles"])
			"map_regions":
				_merge_missing(live, back, ["fauna", "trap_species"])


## A backlog action merged for testing takes its skill from the working roster (skills.json skill_of_prefix): v4 maps
## every id, live and backlog, and the backlog rows were written for the v3 roster. Weapon skills never roll from crafts.
func _remap_backlog_action(r: Dictionary) -> Dictionary:
	var out := r.duplicate(true)
	out.erase("specialties")
	var aid := str(out.get("id", ""))
	for pair in SurvivalUtil.arr(SurvivalUtil.dict(SurvivalUtil.dict(raw.get("skills", {})).get("skill_of_prefix")).get("map")):
		if aid.begins_with(str(pair[0])):
			if str(pair[1]) != "":
				out["skill"] = str(pair[1])
			break
	return out


func _row_key(r: Dictionary) -> String:
	if r.has("id"):
		return str(r.id)
	if r.has("item") and not r.has("window"):
		return "goods:" + str(r.item)
	return ""


func _merge_missing(live: Dictionary, back: Dictionary, path: Array) -> void:
	var a = live
	var b = back
	for key in path:
		if typeof(b) != TYPE_DICTIONARY or not b.has(key):
			return
		if typeof(a) != TYPE_DICTIONARY:
			return
		if not a.has(key):
			a[key] = {}
		a = a[key]
		b = b[key]
	if typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY:
		return
	for k in b.keys():
		if not a.has(k):
			a[k] = b[k]


func _index_list(target: Dictionary, list, key: String = "id") -> void:
	for r in SurvivalUtil.arr(list):
		if typeof(r) == TYPE_DICTIONARY and r.has(key):
			target[str(r[key])] = r


func _index() -> void:
	_index_list(actions, raw.actions.get("actions"))
	_index_list(anim_hooks, raw.actions.get("anim_hooks"))
	_index_list(items, raw.items.get("items"))
	_index_list(clothing, raw.items.get("clothing_classes"))
	_index_list(conditions, raw.conditions.get("conditions"))
	_index_list(needs, raw.needs.get("needs"))
	_index_list(skills, raw.skills.get("skills"))
	_index_list(check_mods, raw.skills.get("modifiers"))
	_index_list(knowledge, raw.skills.get("knowledge"))
	_index_list(backgrounds, raw.backgrounds.get("backgrounds"))
	_index_list(recipes, raw.recipes.get("recipes"))
	for r in recipes.values():
		var a := str(r.get("action", ""))
		if not recipes_by_action.has(a):
			recipes_by_action[a] = []
		recipes_by_action[a].append(str(r.id))
	_index_list(goods, raw.economy.get("goods"), "item")
	_index_list(markets, raw.economy.get("markets"))
	_index_list(wages, raw.economy.get("wages"))
	_index_list(services, raw.economy.get("services"))
	_index_list(jobs, raw.livelihoods.get("jobs"))
	_index_list(livelihoods, raw.livelihoods.get("livelihoods"))
	_index_list(events, raw.seasons.get("events"))
	_index_list(eras, raw.seasons.get("eras"))
	_index_list(months, raw.seasons.get("months"))
	month_ids = SurvivalUtil.arr(raw.seasons.calendar.get("months")).duplicate()
	day_ids = SurvivalUtil.arr(raw.seasons.calendar.get("day_ids")).duplicate()
	_index_list(weather_states, SurvivalUtil.dict(raw.seasons.get("weather")).get("states"))
	for k in SurvivalUtil.arr(SurvivalUtil.dict(raw.conditions.get("modifier_contract")).get("keys")):
		modifier_keys[str(k.key)] = k
	_index_list(archetypes, raw.npcs.get("archetypes"))
	_index_list(individuals, raw.npcs.get("individuals"))
	_index_list(factions, raw.npcs.get("factions"))
	_index_list(regions, raw.map_regions.get("regions"))
	_index_list(resource_nodes, raw.map_regions.get("resource_nodes"))
	forage = SurvivalUtil.arr(raw.seasons.get("forage"))
	fish_runs = SurvivalUtil.arr(raw.seasons.get("fish_runs"))
	_index_list(habits, raw.backgrounds.get("habits"))
	_index_list(start_variants, raw.backgrounds.get("start_variants"))
	trade_behaviours = SurvivalUtil.dict(raw.npcs.get("trade_behaviours"))
	for r in recipes.values():
		for out in SurvivalUtil.dict(r.get("outputs")).keys():
			if not recipes_by_output.has(str(out)):
				recipes_by_output[str(out)] = []
			recipes_by_output[str(out)].append(str(r.id))
		knowledge_ids[recipe_knowledge_id(str(r.id))] = true
	for a in actions.values():
		if bool(a.get("technique", false)):
			knowledge_ids[action_knowledge_id(str(a.id))] = true
	if actions.is_empty() or items.is_empty() or month_ids.size() != 12:
		errors.append("survival data is incomplete (actions, items or calendar missing)")


# ---------------------------------------------------------------- accessors
func action(id: String) -> Dictionary:
	return actions.get(id, {})


func item(id: String) -> Dictionary:
	return items.get(id, {})


func condition(id: String) -> Dictionary:
	return conditions.get(id, {})


func need(id: String) -> Dictionary:
	return needs.get(id, {})


func skill(id: String) -> Dictionary:
	return skills.get(id, {})


func background(id: String) -> Dictionary:
	return backgrounds.get(id, {})


func good(item_id: String) -> Dictionary:
	return goods.get(item_id, {})


func market(id: String) -> Dictionary:
	return markets.get(id, {})


func month(id: String) -> Dictionary:
	return months.get(id, {})


func section(file: String, key: String) -> Dictionary:
	return SurvivalUtil.dict(SurvivalUtil.dict(raw.get(file, {})).get(key, {}))


func check_model() -> Dictionary:
	return section("skills", "check_model")


func growth_model() -> Dictionary:
	return section("skills", "growth_model")


func trap_model() -> Dictionary:
	return section("actions", "trap_model")


func knowledge_model() -> Dictionary:
	return section("skills", "knowledge_model")


func recipe(id: String) -> Dictionary:
	return recipes.get(id, {})


## The knowledge id a recipe is kept under: its covering technique (know.*) when it names one, else the recipe itself.
func recipe_knowledge_id(recipe_id: String) -> String:
	var k := str(recipe(recipe_id).get("knowledge", ""))
	return k if k != "" else recipe_id


## The knowledge id a technique action is kept under: its knowledge field (a know.* id) or the action id.
func action_knowledge_id(action_id: String) -> String:
	var a := action(action_id)
	var k := str(a.get("knowledge", SurvivalUtil.dict(a.get("requires")).get("knowledge", "")))
	return k if k != "" else action_id


## The skill an action id rolls against under the working roster (skills.json skill_of_prefix), or its row's skill.
func skill_of(action_id: String) -> String:
	var a := action(action_id)
	if a.has("skill"):
		return str(a.skill)
	for pair in SurvivalUtil.arr(SurvivalUtil.dict(section("skills", "skill_of_prefix")).get("map")):
		if action_id.begins_with(str(pair[0])):
			return str(pair[1])
	return "survival"


## The working skills (the daily total and callings count these; weapon handling skills are outside them).
func working_skills() -> Array:
	var ws := SurvivalUtil.arr(section("skills", "skill_of_prefix").get("working_skills"))
	if ws.is_empty():
		for k in skills.keys():
			if not ["marksmanship", "archery", "close_combat"].has(str(k)):
				ws.append(str(k))
	return ws


func flow_factor() -> float:
	return SurvivalUtil.num(section("seasons", "time").get("flow_factor"), 5.0)


func item_name(id: String) -> String:
	return str(item(id).get("name", id))


func item_cat(id: String) -> String:
	return str(item(id).get("cat", ""))


## Items that count as one another for tool checks: the throwing tomahawk also serves as a hatchet (items.json "also").
func tool_aliases(id: String) -> Array:
	var out := [id]
	var also = item(id).get("also", null)
	if also != null:
		out.append(str(also))
	return out


## The anim hook an action should request, falling back when the preferred hook is not ready (actions.json anim_hooks).
func anim_hook_for(action_id: String) -> String:
	var hook := str(action(action_id).get("anim", "anim.none"))
	var seen := {}
	while hook != "" and not seen.has(hook):
		seen[hook] = true
		var h: Dictionary = anim_hooks.get(hook, {})
		if h.is_empty() or bool(h.get("ready_now", true)):
			return hook
		var fb := str(h.get("fallback_hook", ""))
		if fb == "":
			return hook
		hook = fb
	return hook
