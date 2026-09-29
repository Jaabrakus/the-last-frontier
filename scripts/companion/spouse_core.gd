class_name SpouseCore
extends RefCounted
## The player's spouse, logic only (user 2026-09-28: "build a wife NPC for my char ... if I'm male I get a female and
## female a male", "they should have the same stats as us, and depending on role either home or outside they do the
## task like if I bring a carcass home or veggies"). The body is Spouse (scripts/companion).
##
## Same stats: she has a SurvivalCore of her own, built on the same data as the player's and started from the player's
## skills, so she has the same needs (hunger, warmth), conditions, skills and kit, and every action she takes is a real
## survival job run on that core with her own skill checks. It runs on the player's clock (sync()).
## The household's store (HouseholdStock: the storage chests) is what she eats from and what her work goes into, in the
## game's pack kinds; a task moves the food or materials into her core (game_items.json maps a pack unit to a core item,
## as the bridge and CampCooking do), runs the job, and moves what it made back.
##
## Roles: "home" (cooks what is brought in, butchers a carcass brought home), "outside" (forages, gathers firewood, by
## day), "follow" (stays with the player), "stay" (waits where she is). She eats when hungry and does no work at night.
## A task is planned (plan()), begun where its work is (begin(): the body walks her there first), finished by its job
## or by a timer, and reported (task_finished).

signal task_finished(task: String, text: String)
signal said(text: String)

const ROLES := ["home", "outside", "follow", "stay"]
const TASKS := ["tend", "cook", "butcher", "forage", "firewood"]
const TASK_NAMES := {"tend": "Tend the fire", "cook": "Cook", "butcher": "Butcher", "forage": "Forage", "firewood": "Gather firewood"}
const TASK_ROLE := {"tend": "home", "cook": "home", "butcher": "home", "forage": "outside", "firewood": "outside"}
const JOB_OF := {"cook": "cook.roast", "forage": "forage.search", "firewood": "wood.split_firewood"}
## Game minutes a butchering takes (a skin, then the meat), less with hidecraft.
## Game minutes laying wood on the fire takes.
const TEND_MIN := 8.0
const BUTCHER_MIN := {"skin": 25.0, "butcher": 40.0}
## Nothing is started between these game hours (she sleeps) and outside work stops at dusk.
const AWAKE := Vector2(5.5, 21.5)
const DAYLIGHT := Vector2(6.0, 19.0)
## After a task that could not start she waits this long (game minutes) before trying anything.
const RETRY_MIN := 45.0
const NAMES_F := ["Hannah", "Abigail", "Mercy", "Sarah", "Rebecca", "Ruth", "Lydia", "Eliza", "Martha", "Susannah"]
const NAMES_M := ["Thomas", "Elias", "Samuel", "Josiah", "Nathaniel", "Caleb", "Jacob", "Silas", "Amos", "Ezra"]
const HOME_CTX := {"location": "home", "near": [], "indoors": true, "fire_distance_m": 1.5, "in_shelter": true,
		"fire_id": "hearth.home"}
const WOODS_POI := "poi.fort.woods_camp"

var name := ""
var look := {}
var role := "home"
var enabled := {"tend": true, "cook": true, "butcher": true, "forage": true, "firewood": true}
var core: SurvivalCore
var stock: HouseholdStock = HouseholdStock.new()
## The game items she works with (data/survival/game_items.json).
var items := {}
var materials := {}
var fuel := {}
## Now: the task ("" none), what it says, and (for the timed ones) the game minutes left.
var task := ""
var task_text := ""
var minutes_left := 0.0
## A task the player asked for by name: it goes first while it can be done (cleared when it is done or cannot be).
var focus := ""
var journal: Array = []
## Finds a carcass at home: Callable() -> Object with finish_dress(step, hands) and meat_left (null: none).
var carcass_finder := Callable()
## Finds a lit campfire at home that wants wood: Callable() -> Object with add_wood_units(n) (null: none).
var fire_finder := Callable()
var _fire: Object

var _cool := 0.0
var _flip := false
var _animal: Object
var _step := ""
var _cook := {}


static func opposite_look(player_look: Dictionary, seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var sex := 1.0 - clampf(roundf(float(player_look.get("sex", 1.0))), 0.0, 1.0)
	var people := String(player_look.get("people", ""))
	var list := CharacterPeoples.presets(people, sex)
	if list.is_empty():
		list = CharacterPeoples.presets("", sex)
	if list.is_empty():
		return {"sex": sex}
	var pick: Dictionary = list[rng.randi() % list.size()]
	return CharacterPeoples.preset_look(String(pick.id))


## A new spouse for the player whose survival core is `main`: opposite sex, her own core on the same data and clock.
static func create(main: SurvivalCore, player_look: Dictionary, seed_v: int) -> SpouseCore:
	var s := SpouseCore.new()
	s.look = opposite_look(player_look, seed_v)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pool: Array = NAMES_M if float(s.look.get("sex", 0.0)) >= 0.5 else NAMES_F
	s.name = String(pool[rng.randi() % pool.size()])
	s.items = SurvivalBridge.load_items()
	s.materials = SurvivalBridge.load_items("materials")
	s.fuel = SurvivalBridge.load_items("fuel")
	var opts := {"data": main.data, "seed": seed_v, "preset": main.state.preset,
			"backlog_milestones": SurvivalUtil.arr(main.state.settings.get("backlog_milestones", []))}
	s.core = SurvivalCore.new_game(main.state.background_id, opts)
	var st := s.core.state
	var keep_variant = st.settings.get("start_variant")
	st.settings = main.state.settings.duplicate(true)
	st.settings["start_variant"] = keep_variant
	st.minutes = main.state.minutes
	st.base_year = main.state.base_year
	st.flags["last_abs_day"] = SurvivalClock.abs_day(s.core)
	st.flags["last_dawn_day"] = SurvivalClock.abs_day(s.core) - (0 if SurvivalClock.hour(s.core) >= SurvivalCore.DAWN_HOUR else 1)
	for k in main.state.skills.keys():
		st.skills[k] = main.state.skills[k]
	st.weather = main.state.weather.duplicate(true)
	s._strip_provisions()
	s._wire()
	s.set_place("home")
	return s


static func from_dict(d: Dictionary, main: SurvivalCore) -> SpouseCore:
	var s := SpouseCore.new()
	s.name = String(d.get("name", "Wife"))
	s.look = (d.get("look", {}) as Dictionary).duplicate(true)
	s.role = String(d.get("role", "home")) if ROLES.has(String(d.get("role", "home"))) else "home"
	for k in TASKS:
		s.enabled[k] = bool((d.get("enabled", {}) as Dictionary).get(k, true))
	s.items = SurvivalBridge.load_items()
	s.materials = SurvivalBridge.load_items("materials")
	s.fuel = SurvivalBridge.load_items("fuel")
	s.core = SurvivalCore.from_state(SurvivalState.from_dict(d.get("core", {})), {"data": main.data})
	s._wire()
	s.journal = (d.get("journal", []) as Array).duplicate()
	return s


func to_dict() -> Dictionary:
	# a task in the middle of its work is given up (her food and materials go back to the store)
	cancel("saved")
	return {"name": name, "look": look.duplicate(true), "role": role, "enabled": enabled.duplicate(),
			"core": core.state.to_dict(), "journal": journal.duplicate()}


func _wire() -> void:
	core.job_finished.connect(_on_job_finished)
	core.job_interrupted.connect(_on_job_interrupted)


func is_male() -> bool:
	return float(look.get("sex", 0.0)) >= 0.5


func title() -> String:
	return "husband" if is_male() else "wife"


## Keeps to the player's clock: her core runs the game minutes the player's has run since, and takes its weather.
func sync(main: SurvivalCore) -> void:
	if core.is_dead():
		return
	var dm := main.state.minutes - core.state.minutes
	core.state.weather = main.state.weather.duplicate(true)
	if dm > 0.0001:
		core.advance(dm)
	elif dm < -0.0001:
		core.state.minutes = main.state.minutes
	_cool = maxf(_cool - maxf(dm, 0.0), 0.0)
	if minutes_left > 0.0:
		minutes_left = maxf(minutes_left - maxf(dm, 0.0), 0.0)
		if minutes_left <= 0.0 and task == "butcher":
			_butcher_done()
		elif minutes_left <= 0.0 and task == "tend":
			_tend_done()
	_eat_when_hungry()


func hour() -> float:
	return SurvivalClock.hour(core)


func awake() -> bool:
	var h := hour()
	return h >= AWAKE.x and h < AWAKE.y


func daylight() -> bool:
	var h := hour()
	return h >= DAYLIGHT.x and h < DAYLIGHT.y


func busy() -> bool:
	return task != ""


## Where she is for the survival core: "home" (the hearth, indoors) or "woods" (the line camp's nodes).
func set_place(place: String) -> void:
	if place == "woods":
		core.go_to(WOODS_POI)
	else:
		SurvivalCamp.ensure_hearth(core, "home")
		core.set_context(HOME_CTX.duplicate(true), true)


# ---------------------------------------------------------------- what she is
func need_lines() -> Array:
	var out := []
	var st := core.need_stages()
	out.append(["Hunger", String(st.get("need.food", "")).replace("_", " ")])
	out.append(["Warmth", String(st.get("need.warmth", "")).replace("_", " ")])
	out.append(["Health", "%d" % roundi(core.health())])
	return out


func skill_lines() -> Array:
	var out := []
	for id in core.data.skills.keys():
		var lv := SurvivalSkills.level(core, str(id))
		out.append([str(core.data.skills[id].get("name", id)), lv, SurvivalSkills.tier(core, str(id))])
	return out


func status_text() -> String:
	if task != "":
		return task_text
	match role:
		"follow":
			return "Following you"
		"stay":
			return "Waiting here"
		"home":
			return "Keeping house" if awake() else "Asleep"
	return "Out and about" if daylight() else "Resting"


# ---------------------------------------------------------------- eating
func _eat_when_hungry() -> void:
	if task != "":
		return
	var stage := SurvivalNeeds.food_stage(core)
	if stage in ["fed", "full", "satisfied"]:
		return
	var kind := _best_food()
	if kind == "":
		return
	var e: Dictionary = items[kind]
	var id := String(e.item)
	if stock.take(kind, 1) < 1:
		return
	var before := SurvivalInventory.count(core, id)
	SurvivalInventory.add(core, id, float(e.get("qty", 1.0)))
	var r := SurvivalFood.eat(core, id, {"force": true})
	var left := SurvivalInventory.count(core, id) - before
	if left > 0.0001:
		SurvivalInventory.remove(core, id, left)
	if not bool(r.get("ok", false)):
		stock.put(kind, 1)
		return
	_note("%s eats %s." % [name, InventoryState.name_of(kind).to_lower()])


## The food she would eat now from the store: edible as it is, safe before raw, the most filling first.
func _best_food() -> String:
	var room := float(SurvivalNeeds.need_row(core, "need.food").get("stomach_capacity_kcal", 3000.0)) \
			- float(core.state.needs.get("stomach", 0.0))
	var best := ""
	var bs := -INF
	for kind: String in items:
		if stock.count(kind) <= 0:
			continue
		var id := String(items[kind].item)
		var it := core.data.item(id)
		if bool(it.get("needs_cooking", false)) or not SurvivalFood.edible(core, id):
			continue
		var kcal := unit_kcal(kind)
		if kcal > room * 1.5 + 50.0:
			continue
		var s := kcal - (10000.0 if it.has("raw_risk") else 0.0)
		if s > bs:
			bs = s
			best = kind
	return best


func unit_kcal(kind: String) -> float:
	var e: Dictionary = items.get(kind, {})
	if e.is_empty():
		return 0.0
	return SurvivalInventory.stack_kcal(core, {"id": String(e.item), "qty": float(e.get("qty", 1.0)), "meta": {}})


# ---------------------------------------------------------------- planning
## The next task for her role now, {task, site ("home" | "woods" | "carcass"), text}, or {} when there is none.
func plan() -> Dictionary:
	if task != "" or _cool > 0.0 or core.is_dead() or not awake() or role == "follow" or role == "stay":
		return {}
	if focus != "" and TASK_ROLE.get(focus, "") == role and enabled.get(focus, false):
		var f := _plan_for(focus)
		if not f.is_empty():
			return f
		focus = ""
	if role == "home":
		if enabled.tend and _fire_wanting() != null:
			return {"task": "tend", "site": "fire", "text": "Tending the fire"}
		if enabled.cook and cook_kind() != "":
			return {"task": "cook", "site": "home", "text": "Cooking"}
		if enabled.butcher and _find_carcass() != null:
			return {"task": "butcher", "site": "carcass", "text": "Butchering the carcass"}
	elif role == "outside" and daylight():
		var order := ["forage", "firewood"] if _flip else ["firewood", "forage"]
		for t in order:
			if enabled[t]:
				return {"task": t, "site": "woods", "text": "Gathering firewood" if t == "firewood" else "Foraging"}
	return {}


func _plan_for(id: String) -> Dictionary:
	match id:
		"tend":
			return {"task": "tend", "site": "fire", "text": "Tending the fire"} if _fire_wanting() != null else {}
		"cook":
			return {"task": "cook", "site": "home", "text": "Cooking"} if cook_kind() != "" else {}
		"butcher":
			return {"task": "butcher", "site": "carcass", "text": "Butchering the carcass"} if _find_carcass() != null else {}
		"forage", "firewood":
			if daylight():
				return {"task": id, "site": "woods", "text": "Gathering firewood" if id == "firewood" else "Foraging"}
	return {}


## The raw food in the store she would cook ("" none), as CampCooking's order: fish, venison, small game, cornmeal.
func cook_kind() -> String:
	for k: String in CampCooking.RAW:
		if items.has(k) and stock.count(k) > 0:
			return k
	return ""


## A lit fire at home low on wood, when the store has firewood for it.
func _fire_wanting() -> Object:
	if stock.count("firewood") <= 0 or not fire_finder.is_valid():
		return null
	var f: Object = fire_finder.call()
	return f if f != null and is_instance_valid(f) else null


func _find_carcass() -> Object:
	if not carcass_finder.is_valid():
		return null
	var a: Object = carcass_finder.call()
	return a if a != null and is_instance_valid(a) else null


## Begins `id` (she is at its work). False when it cannot start (a line says why; she waits before trying again).
func begin(id: String) -> bool:
	if task != "" or not TASKS.has(id):
		return false
	match id:
		"tend":
			return _begin_tend()
		"cook":
			return _begin_cook()
		"butcher":
			return _begin_butcher()
	return _begin_gather(id)


func _begin_gather(id: String) -> bool:
	set_place("woods")
	var r := core.start_job(String(JOB_OF[id]), {})
	if not bool(r.get("ok", false)):
		return _cannot(id, r)
	task = id
	task_text = "Gathering firewood" if id == "firewood" else "Foraging"
	return true


func _begin_cook() -> bool:
	var k := cook_kind()
	if k == "":
		return _cannot("cook", {"reason": "nothing to cook"})
	set_place("home")
	var e: Dictionary = items[k]
	var per := maxf(float(e.get("qty", 1.0)), 0.0001)
	var kcal := maxf(unit_kcal(k), 1.0)
	var n := clampi(floori(SurvivalJobs.COOK_MAX_GAME_KCAL / kcal + 0.0001), 1, stock.count(k))
	n = stock.take(k, n)
	SurvivalInventory.add(core, String(e.item), n * per)
	var r := core.start_job(String(JOB_OF.cook), {"item": String(e.item), "qty": n * per})
	if not bool(r.get("ok", false)):
		SurvivalInventory.remove(core, String(e.item), n * per)
		stock.put(k, n)
		return _cannot("cook", r)
	_cook = {"kind": k, "units": n, "item": String(e.item), "per": per}
	task = "cook"
	task_text = "Baking johnnycake" if k == "cornmeal" else "Roasting %s" % InventoryState.name_of(k).to_lower()
	return true


func _begin_tend() -> bool:
	_fire = _fire_wanting()
	if _fire == null:
		return _cannot("tend", {"reason": "the fire needs nothing"})
	minutes_left = TEND_MIN
	task = "tend"
	task_text = "Tending the fire"
	return true


func _tend_done() -> void:
	var f := _fire
	var id := task
	var n := 0
	if f != null and is_instance_valid(f):
		var want := mini(stock.count("firewood"), 3)
		var taken := stock.take("firewood", want)
		n = int(f.add_wood_units(taken))
		if n < taken:
			stock.put("firewood", taken - n)
	_end_task()
	var text := "%s lays %d %s on the fire." % [name, n, "stick" if n == 1 else "sticks"] if n > 0 else "%s finds the fire well fed." % name
	_note(text)
	task_finished.emit(id, text)


func _begin_butcher() -> bool:
	_animal = _find_carcass()
	if _animal == null:
		return _cannot("butcher", {"reason": "no carcass"})
	_step = "skin" if _animal.get("dress_step") == 0 else "butcher"
	var skill := SurvivalSkills.level(core, "hidecraft")
	minutes_left = float(BUTCHER_MIN[_step]) * lerpf(1.4, 0.7, clampf(skill / 100.0, 0.0, 1.0))
	task = "butcher"
	task_text = "Skinning the carcass" if _step == "skin" else "Butchering the carcass"
	return true


func _cannot(id: String, r: Dictionary) -> bool:
	var rs: Array = r.get("reasons", [])
	var why := String(rs[0]) if not rs.is_empty() else String(r.get("reason", "not now"))
	_note("%s cannot %s: %s." % [name, String(TASK_NAMES.get(id, id)).to_lower(), why])
	_cool = RETRY_MIN
	return false


## Stops the work in hand: what she took from the store goes back.
func cancel(reason := "stopped") -> void:
	if task == "":
		return
	if task == "cook":
		if SurvivalJobs.is_running(core):
			core.cancel_job(reason)
		_return_cook()
	elif SurvivalJobs.is_running(core):
		core.cancel_job(reason)
	_end_task()


func _return_cook() -> void:
	if _cook.is_empty():
		return
	var left := SurvivalInventory.count(core, String(_cook.item))
	if left > 0.0001:
		SurvivalInventory.remove(core, String(_cook.item), left)
		var n := floori(left / float(_cook.per) + 0.0001)
		if n > 0:
			stock.put(String(_cook.kind), n)
	_cook = {}


func _end_task() -> void:
	task = ""
	task_text = ""
	minutes_left = 0.0
	_animal = null
	_fire = null
	_step = ""
	_cook = {}
	_flip = not _flip


# ---------------------------------------------------------------- finishing
func _on_job_finished(res: Dictionary) -> void:
	var action := String(res.get("action", ""))
	if task == "" or String(JOB_OF.get(task, "")) != action:
		return
	var id := task
	if focus == id:
		focus = ""
	var text := ""
	if id == "cook":
		text = _cook_done(res)
	else:
		text = _deposit("brings back")
		if text == "":
			text = "%s finds nothing." % name
		else:
			text = "%s %s." % [name, text]
	_end_task()
	_note(text)
	task_finished.emit(id, text)


func _on_job_interrupted(job: Dictionary, reason: String) -> void:
	if task == "" or String(JOB_OF.get(task, "")) != String(job.get("action", "")):
		return
	var id := task
	if id == "cook":
		_return_cook()
	var got := _deposit("brings back")
	_end_task()
	_cool = RETRY_MIN * 0.5
	var text := "%s stops (%s)%s." % [name, reason, ": " + got if got != "" else ""]
	_note(text)
	task_finished.emit(id, text)


func _cook_done(res: Dictionary) -> String:
	var c: Dictionary = res.get("cooked", {})
	if not bool(c.get("ok", false)):
		_return_cook()
		return "%s could not get the food to cook." % name
	SurvivalInventory.remove(core, String(c.item), float(c.qty_out))
	var k := String(_cook.kind)
	var n := int(_cook.units)
	_return_cook()
	var cooked: Dictionary = CampCooking.COOKED[k]
	var st := String(c.get("state", "cooked"))
	var got := String(cooked.burnt if st == "burnt" else cooked.cooked)
	stock.put(got, n)
	var nm := InventoryState.name_of(got).to_lower()
	if st == "burnt":
		return "%s burns the food: %d %s." % [name, n, nm]
	return "%s cooks %d %s%s." % [name, n, nm, ", a little underdone" if st == "undercooked" else ""]


func _butcher_done() -> void:
	var a := _animal
	var step := _step
	var id := task
	if a == null or not is_instance_valid(a) or a.get("meat_left") == null:
		_end_task()
		return
	var hands := SpouseHands.new()
	a.finish_dress(step, hands)
	var parts := []
	for e: Dictionary in hands.inventory_pack:
		stock.put(String(e.kind), int(e.count))
		parts.append("%d %s" % [int(e.count), InventoryState.name_of(String(e.kind)).to_lower()])
	hands.free()
	_end_task()
	var text := "%s %s the carcass%s." % [name, "skins" if step == "skin" else "butchers", ": " + ", ".join(parts) if not parts.is_empty() else ""]
	_note(text)
	task_finished.emit(id, text)


## What her core holds of the game's food and materials goes to the store (whole pack units; the rest stays with her).
func _deposit(verb: String) -> String:
	var parts := []
	for st: Dictionary in core.state.inventory.duplicate():
		var kind := pack_kind_of(String(st.id))
		if kind == "":
			continue
		var per := maxf(float(pack_item(kind).get("qty", 1.0)), 0.0001)
		var n := floori(float(st.qty) / per + 0.0001)
		if n <= 0:
			continue
		SurvivalInventory.remove(core, String(st.id), n * per)
		stock.put(kind, n)
		parts.append("%d %s" % [n, InventoryState.name_of(kind).to_lower()])
	return "" if parts.is_empty() else "%s %s" % [verb, ", ".join(parts)]


func pack_item(kind: String) -> Dictionary:
	for table: Dictionary in [materials, fuel]:
		if table.has(kind):
			return table[kind]
	return items.get(kind, {})


func pack_kind_of(item: String) -> String:
	for table: Dictionary in [materials, fuel, items]:
		for k: String in table:
			if String(table[k].get("item", "")) == item:
				return k
	return ""


## She starts with tools and clothes, not the player's provisions: the household's food is what is brought in.
func _strip_provisions() -> void:
	for st: Dictionary in core.state.inventory.duplicate():
		if pack_kind_of(String(st.id)) != "":
			SurvivalInventory.remove(core, String(st.id), float(st.qty))


func _note(text: String) -> void:
	journal.append(text)
	if journal.size() > 40:
		journal.pop_front()
	said.emit(text)


## A stand-in for the player's hands for WildAnimal.finish_dress: the yields land in inventory_pack.
class SpouseHands extends Node:
	var inventory_pack: Array = []
	var weapons := {}
	var loadout = null
