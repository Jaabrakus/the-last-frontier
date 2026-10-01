class_name SpouseCore
extends RefCounted
## A worker of the player's household, logic only; the wife is worker 0 (user 2026-09-28: "build a wife NPC for my char ...
## if I'm male I get a female and female a male", "they should have the same stats as us, and depending on role either home
## or outside they do the task like if I bring a carcass home or veggies"). The body is Spouse (scripts/companion).
##
## Same stats: she has a SurvivalCore of her own, built on the same data as the player's and started from the player's
## skills, so she has the same needs (hunger, warmth), conditions, skills and kit, and every action she takes is a real
## survival job run on that core with her own skill checks. It runs on the player's clock (sync()).
## The household's store (HouseholdStock: the storage chests) is what she eats from and what her work goes into, in the
## game's pack kinds; a job moves the food or materials into her core (game_items.json maps a pack unit to a core item,
## as the bridge and CampCooking do), runs the job, and moves what it made back.
##
## Her work is the JobBook (data/companion/jobs.json): each job says what it takes, makes, needs (a station), how it runs (a
## survival core action, or a timed local job) and what it keeps back for eating. This class is the generic runner for it:
## offer(id) says whether a job can run now and with what (asking the site providers, the finders the body installs, for the
## station the job needs), plan() picks the enabled job the household is most short of (JobBook targets and pull, working
## back along the chain), begin() reserves the inputs and the station and starts it, and finishing puts the outputs in the
## store, cancelling gives the inputs back. The special results (roast, the rack, the hoop, the carcass, the smokehouse)
## are the few handlers named in the data.
##
## Roles: "home" (the home jobs: cook, butcher, the fort's chores), "outside" (forage, firewood, by day), "follow" (stays
## with the player), "stay" (waits where she is). She eats when hungry and does no work at night. Workers sharing a store
## (HouseholdCrew) claim their inputs and stations in the store's reservation table, so no two take the same.

signal task_finished(task: String, text: String)
signal said(text: String)

const ROLES := ["home", "outside", "follow", "stay"]
## The job ids, their names and roles, from the book (kept under the names the earlier code used).
static var TASKS: Array = JobBook.ids()
static var TASK_NAMES: Dictionary = JobBook.names()
static var TASK_ROLE: Dictionary = JobBook.roles()
## The site a `needs` is worked at ("" : none: the woods for outside jobs, the hearth for home ones).
const SITE_OF_NEEDS := {"fire": "fire", "carcass": "carcass", "woodpile": "pile", "smokehouse": "smoke", "rack": "rack",
		"tanning_frame": "frame", "hoop": "hoop", "hearth": "home", "chest": "home", "none": "",
		"bed_to_hoe": "hoebed", "bed_to_tend": "tendbed"}   # FARM: a bed of the fields that wants the hoe / sowing or harvest
## Her drying rack is in her own core under this location (the home's).
const RACK_LOC := "home"
## Pelts on the hoops of the whole household at most.
const HOOP_MAX := 2
## Nothing is started between these game hours (she sleeps) and outside work stops at dusk.
const AWAKE := Vector2(5.5, 21.5)
## Her own sleeping hours (user 2026-09-29: "someone can sleep during the day and work the night"): the game hour she goes to
## bed and how many hours she keeps in it; by default the night AWAKE leaves. Saved with her.
var sleep_from := AWAKE.y
var sleep_h := 24.0 - AWAKE.y + AWAKE.x
const DAYLIGHT := Vector2(6.0, 19.0)
## After a task that could not start she waits this long (game minutes) before trying anything.
const RETRY_MIN := 45.0
const NAMES_F := ["Hannah", "Abigail", "Mercy", "Sarah", "Rebecca", "Ruth", "Lydia", "Eliza", "Martha", "Susannah"]
const NAMES_M := ["Thomas", "Elias", "Samuel", "Josiah", "Nathaniel", "Caleb", "Jacob", "Silas", "Amos", "Ezra"]
const HOME_CTX := {"location": "home", "near": [], "indoors": true, "fire_distance_m": 1.5, "in_shelter": true,
		"fire_id": "hearth.home"}
const WOODS_POI := "poi.fort.woods_camp"
## A job scores this much when its station wants work; a job with stock to work scores this much before any pull.
const SITE_SCORE := 1.0
const STOCK_SCORE := 0.1

var name := ""
var look := {}
## GROWTH: the look she is DRAWN with when it differs from `look` (a young worker: the child's flat body, the teen's modest one); empty: `look`.
## `look` stays the logic (her sex, her face). Saved.
var body_look := {}
var role := "home"
## Her place in the household (0: the wife), and the jobs she does: {job id: bool}, every job in the book.
var worker_id := 0
var enabled := {}
var core: SurvivalCore
## The household's store, shared by its workers (setting it joins that household: HouseholdCrew).
var stock: HouseholdStock = HouseholdStock.new():
	set(v):
		if stock != null and stock != v:
			stock.release(worker_id)
			stock.crew.remove(self)
		stock = v
		v.crew.add(self)
## The game items she works with (data/survival/game_items.json).
var items := {}
var materials := {}
var fuel := {}
## Now: the job ("" none), what it says, and (for the timed ones) the game minutes left.
var task := ""
var task_text := ""
var minutes_left := 0.0
## A job the player asked for by name: it goes first while it can be done (cleared when it is done or cannot be).
var focus := ""
var journal: Array = []
## Finds a carcass at home: Callable(skip: Array = []) -> Object with finish_dress(step, hands) and meat_left (null: none);
## `skip` lists instance ids the other workers have claimed.
var carcass_finder := Callable()
## Finds a lit campfire at home that wants wood: Callable() -> Object with add_wood_units(n) (null: none).
var fire_finder := Callable()
## SHARPNESS: the warmth of the lit fires at her body now, 0..1 (Callable() -> float; the body sets it: Campfire.warmth_at).
var warmth_finder := Callable()
## FARM: her gathering skills (GatherSkills), her own and saved: Husbandry, the fields' (the farm jobs' skill: it sets their
## yield and pace, the work trains it; user 2026-09-29: farming and hunting are different skill gains). A new worker's
## starts where the player's is, as her survival skills do.
var gather := GatherSkills.new()
## Finders for the fort's stations: site id ("pile", "smoke", "rack", "frame", "hoop") -> Callable() -> Object or null.
## pile: wood_room(), add_wood_units(n); smoke: larder_raw(), smudge_min(), smudge_room(), add_venison(n), add_wood_units(n);
## rack, frame, hoop: only where she works (the body walks to them).
var finders := {}
## GROWTH (growth_link.gd): the teach job. lesson_source: Callable(worker) -> {child, topic, minutes, text} (or {}: nobody to teach);
## lesson_done: Callable(worker, that dictionary) -> the line she says when the lesson is given.
var lesson_source := Callable()
var lesson_done := Callable()
## Pelts drying on her hoop: [{pelt, dried, ready_at}] (game minutes on her clock). Saved.
var hoop: Array = []
## INTIMACY (scripts/companion/intimacy.gd): the gauge 0..1, the cooldown after a yoga session and after a declined offer
## (game minutes). Saved. `role_saved`: while a yoga follow borrows `role`, the role to save and to go back to ("" none).
var intimacy := 0.1
var intimacy_cd := 0.0
var intimacy_offer_cd := 0.0
var role_saved := ""
## PREGNANCY (scripts/companion/pregnancy.gd): her record {conceived_at, due_at, stage, births, ...}. Saved; old saves have none.
var pregnancy: Dictionary = Pregnancy.new_record()
## HUNT (scripts/companion/hunt_job.gd): the hunt in hand {phase, weapon, quarry, carry, ...} ({} none; not saved: a save ends it).
var hunt := {}
## RECRUIT (scripts/companion/recruit.gd): a recruited worker's record {kind, traits, trust, morale, share, place, ...} ({} for the
## others; saved), and her work speed from her morale (Recruit.work_mult: timed jobs take 1 / this as long).
var recruit := {}
var _slip_rng := RandomNumberGenerator.new()   # SHARPNESS
var work_mult := 1.0
## TOOLS (scripts/companion/tool_pool.gd): made in this session (create/_build): her background's kit is not hers; a worker loaded
## from a save before the pool has it and brings it into the pool once (ToolPool.adopt).
var tool_kit_new := false
## Her rope gear (the sheet's Gear tab): the belt and the sling in her pack ({kind: n}) and worn (kinds, InventoryState.GEAR_KINDS).
var rope_bag := {}
## Started with nothing (BareStart.strip_spouse): no plain belt of hers, her look follows what she wears.
var bare := false
var rope_worn: Array = []
## The running job's offer (what it took and where).
var _run := {}
var _moved := {}
var _cool := 0.0
var _ran := {}
var _ticks := 0


func _init() -> void:
	for id: String in JobBook.ids():
		enabled[id] = true
	join(stock)


## Joins the household whose store this is (HouseholdCrew): she claims and works from it. A worker who was in another
## drops what she had claimed there.
func join(store: HouseholdStock) -> void:
	stock = store


static func opposite_look(player_look: Dictionary, seed_v: int) -> Dictionary:
	var sex := 1.0 - clampf(roundf(float(player_look.get("sex", 1.0))), 0.0, 1.0)
	return look_for(sex, String(player_look.get("people", "")), seed_v)


## A look of a given sex (and people, when it has presets), picked by the seed.
static func look_for(sex: float, people: String, seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var list := CharacterPeoples.presets(people, sex)
	if list.is_empty():
		list = CharacterPeoples.presets("", sex)
	if list.is_empty():
		return {"sex": sex}
	var pick: Dictionary = list[rng.randi() % list.size()]
	return CharacterPeoples.preset_look(String(pick.id))


## A new spouse for the player whose survival core is `main`: opposite sex, her own core on the same data and clock.
static func create(main: SurvivalCore, player_look: Dictionary, seed_v: int) -> SpouseCore:
	return _build(main, opposite_look(player_look, seed_v), seed_v)


## A generic unit of the household (any sex, a random look), for the workers after the wife.
static func create_unit(main: SurvivalCore, seed_v: int, sex := -1.0) -> SpouseCore:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v ^ 0x5EED
	var sx := sex if sex >= 0.0 else float(rng.randi() % 2)
	return _build(main, look_for(sx, "", rng.randi()), seed_v)


static func _build(main: SurvivalCore, the_look: Dictionary, seed_v: int) -> SpouseCore:
	var s := SpouseCore.new()
	s.look = the_look
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
	var pg := GatherSkills.new()   # FARM: the player's gathering skills, read (never saved from here)
	pg.load_saved()
	s.gather.set_points("husbandry", pg.points_of("husbandry"))
	st.weather = main.state.weather.duplicate(true)
	s._strip_provisions()
	s.tool_kit_new = true   # TOOLS
	s._wire()
	s.set_place("home")
	return s


static func from_dict(d: Dictionary, main: SurvivalCore) -> SpouseCore:
	var s := SpouseCore.new()
	s.name = String(d.get("name", "Wife"))
	s.worker_id = int(d.get("id", 0))
	s.look = (d.get("look", {}) as Dictionary).duplicate(true)
	s.body_look = (d.get("body_look", {}) as Dictionary).duplicate(true) if d.get("body_look") is Dictionary else {}   # GROWTH
	s.sleep_from = clampf(float(d.get("sleep_from", AWAKE.y)), 0.0, 24.0)
	s.sleep_h = clampf(float(d.get("sleep_h", 24.0 - AWAKE.y + AWAKE.x)), 0.0, 20.0)
	s.role = String(d.get("role", "home")) if ROLES.has(String(d.get("role", "home"))) else "home"
	# jobs the save does not know (an old save, a job added since) are on
	for k: String in JobBook.ids():
		s.enabled[k] = bool((d.get("enabled", {}) as Dictionary).get(k, true))
	s.items = SurvivalBridge.load_items()
	s.materials = SurvivalBridge.load_items("materials")
	s.fuel = SurvivalBridge.load_items("fuel")
	s.core = SurvivalCore.from_state(SurvivalState.from_dict(d.get("core", {})), {"data": main.data})
	s.hoop = (d.get("hoop", []) as Array).duplicate(true)
	s.bare = bool(d.get("bare", false))
	s.rope_bag = (d.get("rope_bag", {}) as Dictionary).duplicate() if d.get("rope_bag") is Dictionary else {}
	s.rope_worn = (d.get("rope_worn", []) as Array).duplicate() if d.get("rope_worn") is Array else []
	s._wire()
	s.journal = (d.get("journal", []) as Array).duplicate()
	# intimacy (old saves have none: the default start)
	s.intimacy = clampf(float(d.get("intimacy", 0.1)), 0.0, 1.0)
	s.intimacy_cd = maxf(float(d.get("intimacy_cd", 0.0)), 0.0)
	s.intimacy_offer_cd = maxf(float(d.get("intimacy_offer_cd", 0.0)), 0.0)
	s.pregnancy = Pregnancy.normalize(d.get("pregnancy"))
	s.recruit = (d.get("recruit") as Dictionary).duplicate(true) if d.get("recruit") is Dictionary else {}   # RECRUIT (old saves: none)
	if d.get("gather") is Dictionary:
		s.gather.from_dict(d.gather)   # FARM (old saves: none: Husbandry from nothing)
	return s


func to_dict() -> Dictionary:
	# a job in the middle of its work is given up (her food and materials go back to the store)
	cancel("saved")
	SurvivalStreams.sync(core)   # PREGNANCY: her named streams are saved with her core
	return {"id": worker_id, "name": name, "look": look.duplicate(true), "body_look": body_look.duplicate(true), "role": role if role_saved == "" else role_saved, "sleep_from": sleep_from, "sleep_h": sleep_h,
			"enabled": enabled.duplicate(), "core": core.state.to_dict(), "journal": journal.duplicate(), "hoop": hoop.duplicate(true),
			"intimacy": intimacy, "intimacy_cd": intimacy_cd, "intimacy_offer_cd": intimacy_offer_cd,
			"pregnancy": pregnancy.duplicate(true), "recruit": recruit.duplicate(true), "gather": gather.to_dict(),
			"rope_bag": rope_bag.duplicate(), "bare": bare, "rope_worn": rope_worn.duplicate()}   # RECRUIT, FARM


func _wire() -> void:
	core.job_finished.connect(_on_job_finished)
	core.job_interrupted.connect(_on_job_interrupted)


func is_male() -> bool:
	return float(look.get("sex", 0.0)) >= 0.5


func title() -> String:
	if worker_id > 0:
		return "hand"
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
	var idle := task == "" and (role == "home" or role == "stay")   # SHARPNESS: the gauge fills while she rests, any hour
	var warm := idle and dm > 0.0 and warmth_finder.is_valid() and float(warmth_finder.call()) >= Sharpness.num("warm_min", 0.5)
	Sharpness.rest_tick(self, maxf(dm, 0.0), idle and not awake(), idle and awake(), idle and not awake(), warm)
	_tonic_when_tired()
	if minutes_left > 0.0:
		minutes_left = maxf(minutes_left - maxf(dm, 0.0), 0.0)
		if minutes_left <= 0.0 and task != "":
			_timed_done()
	_eat_when_hungry()
	ToolPool.tick(self)   # TOOLS: her kit into the pool once; her borrowed things back at the end of her day


func hour() -> float:
	return SurvivalClock.hour(core)


func awake() -> bool:
	return not sleeping_hour()


## Whether the hour is in her own sleeping hours (they may run past midnight).
func sleeping_hour() -> bool:
	return fposmod(hour() - sleep_from, 24.0) < sleep_h


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
	# FARM: the fields' skill (her gathering skills)
	out.append(["Husbandry", gather.level("husbandry"), String(gather.tier("husbandry").get("id", "novice"))])
	return out


## A skill's level 0..100 by its id: a survival skill (her core's) or a gathering one (Husbandry: `gather`).
func skill_level(id: String) -> float:
	if id in GatherSkills.IDS:
		return float(gather.level(id))
	return SurvivalSkills.level(core, id)


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
	if stock.take(kind, 1, name, "to eat") < 1:
		return
	var before := SurvivalInventory.count(core, id)
	SurvivalInventory.add(core, id, float(e.get("qty", 1.0)))
	var r := SurvivalFood.eat(core, id, {"force": true})
	var left := SurvivalInventory.count(core, id) - before
	if left > 0.0001:
		SurvivalInventory.remove(core, id, left)
	if not bool(r.get("ok", false)):
		stock.put(kind, 1, name, "could not eat it")
		return
	_note("%s eats %s." % [name, InventoryState.name_of(kind).to_lower()])


## SHARPNESS: a ginseng tonic from the store when her well-rested gauge runs low (awake; one a day, as it steadies a tired
## body: Remedies.USE; the player's own rule for it).
func _tonic_when_tired() -> void:
	if core == null or not awake() or Sharpness.rested_hours(self) >= Sharpness.num("tonic_below_h", 1.0):
		return
	var f: Dictionary = core.state.flags
	var day := int(core.state.minutes / 1440.0)
	if int(f.get("tonic_day", -1)) == day or stock.take_for(worker_id, "ginseng_tonic", 1, name, "worn out") < 1:
		return
	f["tonic_day"] = day
	Sharpness.boost(self, float((Remedies.USE["ginseng_tonic"] as Dictionary).rested_h))
	_note("%s takes a ginseng tonic." % name)


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
## The next job for her role now, {task, site ("home" | "woods" | "carcass" | a station id), text, obj (the station or
## carcass she is going to)}, or {} when there is none. It is the enabled, runnable job the household is most short of
## (JobBook.pull along the chain, then the stations' own wants, then stock to work), the book's priority among equals; what
## it will take and the station are claimed until she begins or plans again.
func plan() -> Dictionary:
	if task != "" or _cool > 0.0 or core.is_dead() or not awake() or role == "follow" or role == "stay":
		return {}
	stock.release(worker_id)
	var best := _choose()
	if best.is_empty():
		ToolPool.let_go(self)   # TOOLS: no job: nothing claimed
		return {}
	_hold(best)
	ToolPool.planned(self, String(best.id))   # TOOLS: its tools claimed (her body fetches them first)
	if String(best.id) == HuntJob.JOB:   # HUNT: her own weapon claimed (the one she is best at), not the rack's first
		HuntKit.planned(self, best)
	return {"task": String(best.id), "site": String(best.site), "text": String(best.text), "obj": best.get("obj")}


## The best job to do now: its offer, or {}.
func _choose() -> Dictionary:
	var short := shortages()
	var active := func(id: String) -> bool: return stock.crew.any_enabled(id) or enabled.get(id, false)
	var cands := []
	var focus_ok := false
	for id: String in JobBook.ids():
		var job := JobBook.job(id)
		if String(job.where) != role or not bool(enabled.get(id, false)):
			continue
		if role == "outside" and not daylight():
			continue
		if not heavy_ok(job):   # PREGNANCY: no heavy jobs in the late stages or while she rests after a birth
			continue
		var o := offer(id)
		var forced := focus == id
		if o.is_empty():
			continue
		var pull := JobBook.pull(id, short, active)
		var demand := String(job.demand)
		if demand == "target" and pull <= 0.0 and not forced:
			continue
		var score := (100.0 if forced else 0.0)
		match demand:
			"site":
				score += maxf(pull, SITE_SCORE)
			_:
				score += pull + STOCK_SCORE
		focus_ok = focus_ok or forced
		cands.append({"o": o, "score": score, "prio": int(job.priority), "ran": int(_ran.get(id, 0))})
	if focus != "" and not focus_ok:
		focus = ""
	if cands.is_empty():
		return {}
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a.score) - float(b.score)) > 0.001:
			return float(a.score) > float(b.score)
		if a.prio != b.prio:
			return a.prio < b.prio
		return a.ran < b.ran)
	# SHARPNESS: tired, hungry or unwell, she sometimes does a lesser job first (never over the player's own order)
	if cands.size() > 1 and not focus_ok and _slip_rng.randf() < Sharpness.slip(Sharpness.of(self), Sharpness.num("job_slip", 0.35)):
		return cands[_slip_rng.randi_range(1, mini(2, cands.size() - 1))].o
	return cands[0].o


## False for a job tagged "heavy" while her pregnancy or her rest after a birth rules out heavy work.
func heavy_ok(job: Dictionary) -> bool:
	if not (job.get("tags", []) as Array).has(String(Pregnancy.cfg().get("heavy_tag", "heavy"))):
		return true
	return not Pregnancy.heavy_blocked(pregnancy, core.state.minutes)


## What the household is short of now (JobBook.shortages on the store, for everyone it feeds).
func shortages() -> Dictionary:
	return JobBook.shortages(func(k: String) -> int: return stock.count(k), stock.crew.people())


## The site the job works at, as the body knows it.
static func site_of(id: String) -> String:
	var job := JobBook.job(id)
	var s := String(SITE_OF_NEEDS.get(String(job.get("needs", "none")), ""))
	if s == "":
		return "woods" if String(job.get("where", "home")) == "outside" else "home"
	return s


## The station object a site id is: a station (finders), the carcass or the fire (their finders). A carcass another worker
## has claimed is passed over.
func find_site(site: String) -> Object:
	var o: Object = null
	match site:
		"carcass":
			if carcass_finder.is_valid():
				o = carcass_finder.call(_claimed_carcasses()) if carcass_finder.get_argument_count() >= 1 else carcass_finder.call()
		"fire":
			if fire_finder.is_valid():
				o = fire_finder.call()
		_:
			var c: Variant = finders.get(site)
			if c is Callable and (c as Callable).is_valid():
				# (a finder that takes the others' claims: the beds, FARM)
				o = (c as Callable).call(_claimed_beds()) if (c as Callable).get_argument_count() >= 1 else (c as Callable).call()
	return o if o != null and is_instance_valid(o) else null


## The object held by the job in hand or just planned (the body walks to it).
func site_object() -> Object:
	var o: Variant = _run.get("obj")
	if o is Object and is_instance_valid(o):
		return o
	return find_site(site_of(task)) if task != "" else null


func _claimed_carcasses() -> Array:
	var out := []
	for key: String in stock.reserved:
		if key.begins_with("s:carcass:") and stock.held_by_others(worker_id, key) > 0:
			out.append(int(key.get_slice(":", 2)))
	return out


## FARM: the beds the other workers have claimed (their keys).
func _claimed_beds() -> Array:
	var out := []
	for key: String in stock.reserved:
		if key.begins_with("s:bed:") and stock.held_by_others(worker_id, key) > 0:
			out.append(key.substr(6))
	return out


static func _site_key(site: String, o: Object) -> String:
	var claim: Variant = o.get("claim")   # FARM: a place of its own naming (a bed: "bed:<key>")
	if claim is String and String(claim) != "":
		return "s:" + String(claim)
	var n: Variant = o.get("node")
	return "s:%s:%d" % [site, (n as Object).get_instance_id() if n is Object else o.get_instance_id()]


# ---------------------------------------------------------------- offers
func _free(kind: String) -> int:
	return stock.free_count(kind, worker_id)


## What of `kind` the job may use: the store's free units less what the job keeps back.
func _spare(job_id: String, kind: String) -> int:
	return maxi(_free(kind) - JobBook.keep_of(job_id, kind), 0)


## The job as it can run now: {id, text, site, inputs {pack kind: units}, how, obj (its station), site_key, mode, params,
## meta, done, minutes ...} or {} when it cannot (no station, nothing to work, another worker on it). This is what plan()
## chooses among and begin() runs.
func offer(id: String) -> Dictionary:
	var job := JobBook.job(id)
	if job.is_empty():
		return {}
	var sid := String(SITE_OF_NEEDS.get(String(job.needs), ""))
	var obj: Object = null
	var key := ""
	if sid != "" and sid != "home":
		obj = find_site(sid)
		if obj == null:
			return {}
		key = _site_key(sid, obj)
		if not stock.site_free(worker_id, key):
			return {}
	var o := {}
	match String(job.offer):
		"gather":
			o = {"inputs": {}}
		"carcass":
			o = _offer_carcass(obj)
		"feed":
			o = _offer_feed(job, obj)
		"smokehouse":
			o = _offer_smoke(job, obj)
		"lesson":   # GROWTH
			o = _offer_lesson()
		"hunt":   # HUNT
			o = HuntJob.offer(self)
		"farm":   # FARM
			o = FarmJob.offer(self, obj)
		_:
			o = _offer_variants(job, obj)
	if o.is_empty():
		return {}
	if not ToolPool.offer_ok(self, id, o):   # TOOLS: not without its tools free
		return {}
	o["id"] = id
	o["site"] = site_of(id)
	if not o.has("text"):
		o["text"] = String(job.text)
	if not o.has("how"):
		o["how"] = job.how
	o["obj"] = obj
	o["site_key"] = key
	return o


func _guard_ok(job: Dictionary) -> bool:
	return String(job.get("guard", "")) != "fed" or _preserving_ok()


## She may spare the store's raw meat for preserving: not when she is hungry with nothing to eat (cooking comes first).
func _preserving_ok() -> bool:
	var stage := SurvivalNeeds.food_stage(core)
	return stage in ["fed", "full", "satisfied"] or _best_food() != ""


func _offer_carcass(obj: Object) -> Dictionary:
	var skin: bool = obj.get("dress_step") == 0
	return {"inputs": {}, "step": "skin" if skin else "butcher", "text": "Skinning the carcass" if skin else "Butchering the carcass"}


## Wood (or the like) to lay on a fire or a pile: the job's kind, up to a trip, what the job keeps back left.
func _offer_feed(job: Dictionary, obj: Object) -> Dictionary:
	var cfg: Dictionary = job.feed
	var kind := String(cfg.kind)
	var n := mini(_spare(String(job.id), kind), int(cfg.trip))
	if String(cfg.get("room", "")) != "":
		n = mini(n, int(obj.call(String(cfg.room))))
	if n <= 0:
		return {}
	return {"inputs": {kind: n}}


## GROWTH: a lesson to give a child (the teach job): the source names the child and the topic; it takes the topic's minutes.
func _offer_lesson() -> Dictionary:
	if not lesson_source.is_valid():
		return {}
	var d: Dictionary = lesson_source.call(self)
	if d.is_empty():
		return {}
	return {"inputs": {}, "text": String(d.text), "minutes": float(d.minutes), "lesson": d}


## What the smokehouse wants now: raw venison to hang (the larder holds so many), sticks for the smudge when it is low.
func _offer_smoke(job: Dictionary, obj: Object) -> Dictionary:
	if not _guard_ok(job):
		return {}
	var cfg: Dictionary = job.smokehouse
	var id := String(job.id)
	var raw := int(obj.larder_raw())
	var lmax := int(cfg.larder_max)
	var add := clampi(mini(_spare(id, "venison"), lmax - raw), 0, lmax)
	var sticks := 0
	if raw + add > 0 and float(obj.smudge_min()) < float(cfg.smudge_low):
		var trip := int(cfg.sticks_trip)
		sticks = clampi(mini(mini(_spare(id, "firewood"), int(obj.smudge_room())), trip), 0, trip)
	if add + sticks <= 0:
		return {}
	var inputs := {}
	if add > 0:
		inputs["venison"] = add
	if sticks > 0:
		inputs["firewood"] = sticks
	return {"inputs": inputs, "add": add, "sticks": sticks}


## Jobs with variants (cook by what is in the store, tan by hide and brains ...) and the take-down of a rack or hoop.
func _offer_variants(job: Dictionary, obj: Object) -> Dictionary:
	var id := String(job.id)
	var td: Dictionary = job.get("takedown", {})
	if not td.is_empty() and _ready_down(td) and obj != null:
		return {"inputs": {}, "mode": "down", "text": String(td.text), "minutes": float(td.minutes),
				"how": {"type": "timed", "done": "takedown", "record": String(td.record)}}
	if not _guard_ok(job):
		return {}
	match String(job.get("station", "")):
		"rack":
			for w: SpouseCore in stock.crew.workers:
				if w._rack_lb(false) > 0.0:
					return {}
		"hoop":
			var n := 0
			for w: SpouseCore in stock.crew.workers:
				n += w.hoop.size()
			if n >= HOOP_MAX:
				return {}
	for v: Dictionary in job.get("variants", []):
		var o := _variant_offer(job, v)
		if not o.is_empty():
			return o
	return {}


func _variant_offer(job: Dictionary, v: Dictionary) -> Dictionary:
	var id := String(job.id)
	var inputs := {}
	var first := ""
	for tok: String in v.get("inputs", {}):
		var qty: Variant = v.inputs[tok]
		var pick := ""
		for k: String in JobBook.expand(tok):
			if pack_item(k).is_empty() or _spare(id, k) < 1:
				continue
			if _free(k) < int((v.get("min_have", {}) as Dictionary).get(k, 1)):
				continue
			var n := _batch(job, k, qty)
			if n < 0 or _spare(id, k) < n:
				continue
			pick = k
			inputs[k] = n
			break
		if pick == "":
			return {}
		if first == "":
			first = pick
	var text := String(v.get("text", job.text))
	var by_kind: Dictionary = v.get("text_by_kind", {})
	if by_kind.has(first):
		text = String(by_kind[first])
	elif text.contains("%s"):
		text = text % InventoryState.name_of(first).to_lower()
	var params: Dictionary = (v.get("params", {}) as Dictionary).duplicate(true)
	for pk: String in v.get("input_params", []):
		var e := pack_item(first)
		match pk:
			"item":
				params["item"] = String(e.item)
			"qty":
				params["qty"] = float(inputs[first]) * float(e.get("qty", 1.0))
	return {"inputs": inputs, "params": params, "meta": v.get("meta", {}), "text": text, "mode": "work",
			"variant": String(v.get("id", "")), "done": String(v.get("done", "")), "first": first}


## How many units of `kind` a variant takes: the number in the data, or a batch by the job's rule (-1: none).
func _batch(job: Dictionary, kind: String, qty: Variant) -> int:
	if not (qty is String):
		return int(qty)
	var rule: Dictionary = job.get("batch", {})
	var spare := _spare(String(job.id), kind)
	match String(rule.get("rule", "")):
		"kcal":
			var kcal := maxf(unit_kcal(kind), 1.0)
			return clampi(floori(SurvivalJobs.COOK_MAX_GAME_KCAL / kcal + 0.0001), 1, maxi(spare, 1))
		"lb":
			var e := pack_item(kind)
			var per := maxf(float(e.get("qty", 1.0)), 0.0001)
			var has := SurvivalInventory.count(core, String(e.get("item", "")))
			return maxi(ceili((float(rule.lb) - has) / per - 0.0001), 0)
	return 1


## Claims what the offer will take and the station it works at (until she begins, plans again or the job ends).
func _hold(o: Dictionary) -> void:
	stock.release(worker_id)
	for k: String in o.get("inputs", {}):
		stock.reserve_kind(worker_id, k, int(o.inputs[k]))
	if String(o.get("site_key", "")) != "":
		stock.reserve(worker_id, String(o.site_key), 1)


## Lets go of a plan she will not carry out (the body could not reach the place).
func abandon_plan() -> void:
	if task == "":
		stock.release(worker_id)
		ToolPool.let_go(self)   # TOOLS: her claims on the chest go too


func _needs_name(id: String) -> String:
	return JobBook.name_of(id).to_lower()


## Begins `id` (she is at its work). False when it cannot start (a line says why; she waits before trying again).
func begin(id: String) -> bool:
	if task != "" or not JobBook.has(id):
		return false
	var job := JobBook.job(id)
	var o := offer(id)
	if o.is_empty():
		return _cannot(id, {"reason": ToolPool.blocked_why(self, id, String(job.get("idle", "not now")))})   # TOOLS: or the tool not free
	_hold(o)
	if String(job.offer) == "hunt" and not HuntKit.arm(self, o):   # HUNT: her weapon and knife in hand first
		return _cannot(id, {"reason": HuntJob.line("no_kit")})
	if not ToolPool.ready(self, id):   # TOOLS: she has the tools it takes (fetched now if her body did not)
		return _cannot(id, {"reason": ToolPool.why(self)})
	var how: Dictionary = o.how
	if String(how.get("type", "")) == "timed":
		# a timed job always takes some time: one of 0 minutes would never finish (sync ends a job as it runs out)
		minutes_left = maxf(_minutes(job, o), 1.0)
		_start(id, o)
		return true
	set_place("woods" if String(job.where) == "outside" else "home")
	if how.has("near"):
		core.state.context["near"] = how.near
	_moved = {}
	if not _load_inputs(o.inputs, o.get("meta", {})):
		return _cannot(id, {"reason": "not enough to work with"})
	ToolPool.load_core(self)   # TOOLS: the borrowed tools in her core, where the rules look for them
	var r := core.start_job(String(how.action), o.get("params", {}))
	if not bool(r.get("ok", false)):
		_return_inputs()
		return _cannot(id, r)
	# what she took is out of the store: only the station stays claimed
	stock.release(worker_id)
	if String(o.site_key) != "":
		stock.reserve(worker_id, String(o.site_key), 1)
	_start(id, o)
	if String(job.offer) == "hunt":   # HUNT: the weapon and shot for the hunt
		HuntJob.started(self, o)
	return true


func _start(id: String, o: Dictionary) -> void:
	task = id
	task_text = String(o.text)
	_run = o
	ToolPool.started(self, id)   # TOOLS


## Game minutes a timed job takes (by its step, less with skill when the data says so).
func _minutes(job: Dictionary, o: Dictionary) -> float:
	var m: Variant = o.get("minutes", o.how.get("minutes", 0.0))
	var base := float((m as Dictionary).get(String(o.get("step", "")), 0.0)) if m is Dictionary else float(m)
	var sc: Variant = o.how.get("skill_scale")
	if sc is Array and String(job.get("skill", "")) != "":
		var skill := skill_level(String(job.skill))
		base *= lerpf(float(sc[0]), float(sc[1]), clampf(skill / 100.0, 0.0, 1.0))
	base *= ToolPool.speed_of(self, String(job.get("id", "")))   # TOOLS: an optional tool she has makes it quicker
	return base / clampf(work_mult, 0.25, 2.0)   # RECRUIT: a recruit's morale sets her pace


func _cannot(id: String, r: Dictionary) -> bool:
	var rs: Array = r.get("reasons", [])
	var why := String(rs[0]) if not rs.is_empty() else String(r.get("reason", "not now"))
	_note("%s cannot %s: %s." % [name, _needs_name(id), why])
	_cool = RETRY_MIN
	stock.release(worker_id)
	ToolPool.cannot(self)   # TOOLS
	return false


## Stops the work in hand: what she took from the store goes back.
func cancel(reason := "stopped") -> void:
	if task == "":
		return
	if SurvivalJobs.is_running(core):
		core.cancel_job(reason)
	ToolPool.run_ended(self, false)   # TOOLS: the borrowed things out of her core (no wear)
	_return_inputs()
	_end_task()


func _end_task() -> void:
	HuntJob.ended(self)   # HUNT: a borrowed weapon back to the store
	ToolPool.run_ended(self)   # TOOLS: a timed run wears its tools
	if task != "":
		_ticks += 1
		_ran[task] = _ticks
	task = ""
	task_text = ""
	minutes_left = 0.0
	_run = {}
	_moved = {}
	stock.release(worker_id)


# ---------------------------------------------------------------- finishing
func _on_job_finished(res: Dictionary) -> void:
	if task == "" or _run.is_empty() or String(_run.how.get("action", "")) != String(res.get("action", "")):
		return
	if String(_run.how.get("result", "")) == "hunt":   # HUNT: the sign read, the hunt goes on (HuntJob)
		HuntJob.tracked(self, res)
		return
	ToolPool.run_ended(self)   # TOOLS: the borrowed things out of her core before she deposits what she made
	var id := task
	if focus == id:
		focus = ""
	var how: Dictionary = _run.how
	var text := ""
	match String(how.get("result", "deposit")):
		"cook":
			text = _result_cook(res)
		"rack":
			text = _result_rack(res)
		"hoop":
			text = _result_hoop()
		_:
			_return_inputs()
			var got := _deposit(String(how.get("verb", "brings back")))
			if got == "":
				text = "%s %s." % [name, String(how.get("none", "finds nothing"))]
			else:
				var done := String(_run.get("done", ""))
				text = "%s %s." % [name, got.replace(String(how.get("verb", "")), done) if done != "" else got]
	_end_task()
	_note(text)
	task_finished.emit(id, text)


func _on_job_interrupted(job: Dictionary, reason: String) -> void:
	if task == "" or _run.is_empty() or String(_run.how.get("action", "")) != String(job.get("action", "")):
		return
	var id := task
	ToolPool.run_ended(self)   # TOOLS
	_return_inputs()
	var got := _deposit("brings back")
	_end_task()
	_cool = RETRY_MIN * 0.5
	var text := "%s stops (%s)%s." % [name, reason, ": " + got if got != "" else ""]
	_note(text)
	task_finished.emit(id, text)


## A timed job is over: the task ends and it is told.
func _finish_timed(text: String) -> void:
	var id := task
	if focus == id:
		focus = ""
	_end_task()
	_note(text)
	task_finished.emit(id, text)


func _timed_done() -> void:
	match String(_run.get("how", {}).get("done", "")):
		"carcass":
			_done_carcass()
		"feed":
			_done_feed()
		"smoke":
			_done_smoke()
		"takedown":
			_done_takedown()
		"teach":   # GROWTH
			_done_teach()
		"farm":   # FARM
			FarmJob.done(self)
		_:
			_end_task()


func _result_cook(res: Dictionary) -> String:
	var c: Dictionary = res.get("cooked", {})
	var k := String(_run.first)
	var n := int(_run.inputs[k])
	if not bool(c.get("ok", false)):
		_return_inputs()
		return "%s could not get the food to cook." % name
	SurvivalInventory.remove(core, String(c.item), float(c.qty_out))
	_return_inputs()
	var cooked: Dictionary = CampCooking.COOKED[k]
	var st := String(c.get("state", "cooked"))
	var got := String(cooked.burnt if st == "burnt" else cooked.cooked)
	stock.put(got, n, name, _why())
	var nm := InventoryState.name_of(got).to_lower()
	if st == "burnt":
		return "%s burns the food: %d %s." % [name, n, nm]
	return "%s cooks %d %s%s." % [name, n, nm, ", a little underdone" if st == "undercooked" else ""]


func _result_rack(res: Dictionary) -> String:
	_return_inputs()
	var cr: Dictionary = res.get("recipe", {})
	if not cr.has("rack"):
		return "%s spoils the meat on the rack." % name
	var lb := 0.0
	for v: Variant in SurvivalUtil.dict(cr.get("made")).values():
		lb += float(v)
	return "%s hangs %d lb of jerky to dry (a day or two)." % [name, roundi(lb)]


## The pelt fleshed and laced goes on her hoop to dry for the time the core gave it.
func _result_hoop() -> String:
	var k := String(_run.first)
	var item := String(materials.get(k, {}).get("item", ""))
	var meta := {}
	for st: Dictionary in core.state.inventory:
		var m := SurvivalUtil.dict(st.get("meta"))
		if String(st.id) == item and bool(m.get("stretched", false)):
			meta = m.duplicate(true)
			SurvivalInventory.remove_stack_qty(core, st, 1.0)
			break
	_return_inputs()
	if meta.is_empty():
		return "%s tears the pelt in the lacing." % name
	var need_min := float(meta.get("dry_need_h", 60.0)) * 60.0
	hoop.append({"pelt": k, "dried": "dried_" + k, "ready_at": core.state.minutes + need_min})
	return "%s laces the %s onto the hoop to dry (%d hours)." % [name, InventoryState.name_of(k).to_lower(), roundi(need_min / 60.0)]


func _done_carcass() -> void:
	var a: Object = _run.get("obj")
	var step := String(_run.get("step", "butcher"))
	if a == null or not is_instance_valid(a) or a.get("meat_left") == null:
		_end_task()
		return
	var hands := SpouseHands.new()
	a.finish_dress(step, hands)
	var parts := []
	for e: Dictionary in hands.inventory_pack:
		stock.put(String(e.kind), int(e.count), name, _why())
		parts.append("%d %s" % [int(e.count), InventoryState.name_of(String(e.kind)).to_lower()])
	hands.free()
	_finish_timed("%s %s the carcass%s." % [name, "skins" if step == "skin" else "butchers", ": " + ", ".join(parts) if not parts.is_empty() else ""])


## Lays wood on a fire or a pile: what the job may take now, up to what the station has room for.
func _done_feed() -> void:
	var job := JobBook.job(task)
	var cfg: Dictionary = job.feed
	var o := offer(task)
	var kind := String(cfg.kind)
	var n := 0
	if not o.is_empty():
		var taken := stock.take_for(worker_id, kind, int(o.inputs.get(kind, 0)), name, _why())
		n = int((o.obj as Object).call(String(cfg.add), taken))
		if n < taken:
			stock.put(kind, taken - n, name, _why())
	_finish_timed("%s %s %d %s %s." % [name, cfg.verb, n, "stick" if n == 1 else "sticks", cfg.noun] if n > 0 \
			else "%s %s." % [name, cfg.full])


## GROWTH: the lesson is over: the child learns (if it is still near), and she says so.
func _done_teach() -> void:
	var d: Dictionary = _run.get("lesson", {})
	var text := "%s finds nobody to teach." % name
	if lesson_done.is_valid() and not d.is_empty():
		text = String(lesson_done.call(self, d))
	_finish_timed(text)


func _done_smoke() -> void:
	var o := offer(task)
	var hung := 0
	var laid := 0
	if not o.is_empty():
		var s: Object = o.obj
		var v := stock.take_for(worker_id, "venison", int(o.get("add", 0)), name, _why())
		hung = int(s.add_venison(v, name, _why()))
		if hung < v:
			stock.put("venison", v - hung, name, _why())
		var f := stock.take_for(worker_id, "firewood", int(o.get("sticks", 0)), name, _why())
		laid = int(s.add_wood_units(f))
		if laid < f:
			stock.put("firewood", f - laid, name, _why())
	var parts := []
	if hung > 0:
		parts.append("hangs %d venison" % hung)
	if laid > 0:
		parts.append("feeds the smudge %d %s" % [laid, "stick" if laid == 1 else "sticks"])
	_finish_timed("%s %s in the smokehouse." % [name, " and ".join(parts)] if not parts.is_empty() else "%s finds the smokehouse in order." % name)


## The dry jerky off the rack into the store (a part pound stays with her), or the dried pelts off the hoop.
func _done_takedown() -> void:
	var text := ""
	if String(_run.how.get("record", "")) == "rack":
		var r := _rack()
		var keep := []
		var lb := 0.0
		for h in SurvivalUtil.arr(r.get("hanging")):
			if core.state.minutes >= float(h.get("ready_at", 0.0)):
				lb += float(h.get("qty", 0.0))
			else:
				keep.append(h)
		if not r.is_empty():
			r["hanging"] = keep
		var units := floori(lb + 0.0001)
		if lb - units > 0.0001:
			SurvivalInventory.add(core, "item.food.jerky", lb - units)
		if units > 0:
			stock.put("jerky", units, name, _why())
		text = "%s takes down %d jerky." % [name, units] if units > 0 else "%s finds the strips not yet dry." % name
	else:
		var got := []
		var rest := []
		for e: Dictionary in hoop:
			if core.state.minutes >= float(e.get("ready_at", 0.0)):
				stock.put(String(e.dried), 1, name, _why())
				got.append(InventoryState.name_of(String(e.dried)).to_lower())
			else:
				rest.append(e)
		hoop = rest
		text = "%s takes down the %s." % [name, ", ".join(got)] if not got.is_empty() else "%s finds the pelt still damp." % name
	_finish_timed(text)


# ---------------------------------------------------------------- the rack and the hoop
## The jerky on her rack (her own core's rack record at home): pounds hanging and pounds dry.
func _rack() -> Dictionary:
	return SurvivalCamp.rack_at(core, RACK_LOC)


func _rack_lb(ready_only: bool) -> float:
	var n := 0.0
	for h in SurvivalUtil.arr(_rack().get("hanging")):
		if not ready_only or core.state.minutes >= float(h.get("ready_at", 0.0)):
			n += float(h.get("qty", 0.0))
	return n


## Whether something on her rack or hoop (by the take-down's record) is done.
func _ready_down(td: Dictionary) -> bool:
	if String(td.record) == "rack":
		return _rack_lb(true) >= float(td.get("min_lb", 1.0))
	for e: Dictionary in hoop:
		if core.state.minutes >= float(e.get("ready_at", 0.0)):
			return true
	return false


## "down" (dry jerky to take off the rack), "work" (a batch to hang), or "" (nothing).
func _jerky_mode() -> String:
	return String(offer("jerky").get("mode", ""))


func _stretch_mode() -> String:
	return String(offer("stretch").get("mode", ""))


# ---------------------------------------------------------------- the store and her core
## Takes `inputs` ({pack kind: units}, all or nothing) from the store into her core, with `meta` on them. False when the
## store is short (nothing kept). The units the other workers have claimed are not taken.
func _load_inputs(inputs: Dictionary, meta := {}) -> bool:
	var taken := {}
	for k: String in inputs:
		var n := stock.take_for(worker_id, k, int(inputs[k]), name, _why())
		taken[k] = n
		if n < int(inputs[k]):
			for k2: String in taken:
				stock.put(k2, int(taken[k2]), name, _why())
			return false
	_moved = {}
	for k: String in taken:
		var m := pack_item(k)
		var item := String(m.item)
		var per := float(m.get("qty", 1.0))
		_moved[item] = [k, int(taken[k]), per, SurvivalInventory.count(core, item)]
		if int(taken[k]) > 0:
			SurvivalInventory.add(core, item, int(taken[k]) * per, meta)
	return true


## What of the loaded inputs is still in her core goes back to the store (whole units; a part stays with her).
func _return_inputs() -> void:
	for item: String in _moved:
		var m: Array = _moved[item]
		var left := SurvivalInventory.count(core, item) - float(m[3])
		var units := mini(floori(left / float(m[2]) + 0.0001), int(m[1]))
		if units > 0:
			SurvivalInventory.remove(core, item, units * float(m[2]))
			stock.put(String(m[0]), units, name, _why())
	_moved = {}


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
		stock.put(kind, n, name, _why())
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


## LEDGER: why she takes or puts back what she does (the store's chests note it by her name): the work in hand.
func _why() -> String:
	return task_text


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
