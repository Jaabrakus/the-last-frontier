class_name Household
extends Node
## The player's household (user 2026-09-28: "a wife NPC for my char ... talk to the npc and delegate tasks either through
## talking or an npc management tab"): the spouse (SpouseCore: her own survival core and her work; Spouse: her body) and
## what she works from, the storage chests (ChestStock). The level installs it once the survival bridge exists; every
## frame it keeps her core on the player's clock. E on her, or J anywhere, opens the household screen (HouseholdScreen:
## Talk, Tasks, Stats). Saved as the "household" part.
##   Household.install(level, player) -> the household (null without survival: no clock to keep)

const GROUP := &"household"
const LINES_PATH := "res://data/companion/lines.json"
const ACTION := &"household"

var player: FrontierPlayer
var bridge: SurvivalBridge
## The wife (worker 0) and her body; the other workers are in crew().workers, their bodies in `bodies` (worker id -> Spouse).
var sc: SpouseCore
var body: Spouse
var bodies := {}
var stock: ChestStock
var home := Vector3.ZERO
var screen: HouseholdScreen
var lines := {}
## The intimacy gauge and yoga together (scripts/companion/tandem_link.gd).
var link: TandemLink
## PREGNANCY (pregnancy_link.gd): conception after yoga, gestation, birth; and the family, the children born to the household as
## records: [{id, name, sex, born_at, mother, father, kind, seed, vigor, worker_id (-1: not a worker yet)}]. Saved as "family".
var pregnancy: PregnancyLink
var family: Array = []
## BABY (scripts/companion/baby_link.gd): the newest child's body, its needs and who holds it. Saved as "baby".
var baby: BabyLink
## GROWTH (scripts/companion/growth_link.gd): the children's stages, bodies, lessons and the NPC father's day. State lives in the family records.
var growth: GrowthLink
## RECRUIT (scripts/companion/recruit_link.gd): travellers and neighbours who can be asked to join, and the joined workers' morale.
## Saved as "recruit".
var recruits: RecruitLink
var _rng := RandomNumberGenerator.new()


static func find(tree: SceneTree) -> Household:
	return tree.get_first_node_in_group(GROUP) as Household if tree else null


static func install(level: Node, p: FrontierPlayer) -> Household:
	var b := SurvivalBridge.find(level.get_tree())
	if b == null or b.core == null:
		return null
	var h := Household.new()
	h.name = "Household"
	h.player = p
	h.bridge = b
	level.add_child(h)
	return h


func _ready() -> void:
	add_to_group(GROUP)
	InputSetup.ensure()
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(LINES_PATH))
	lines = d if d is Dictionary else {}
	_rng.randomize()
	stock = ChestStock.new()
	stock.tree = get_tree()
	ToolPool.install(stock)   # TOOLS: the household's tools, weapons and consumables the workers borrow
	if SurvivalBridge.spouse_wanted():
		_new_spouse.call_deferred()
	link = TandemLink.new()
	link.name = "TandemLink"
	link.house = self
	add_child(link)
	pregnancy = PregnancyLink.new()
	pregnancy.name = "PregnancyLink"
	pregnancy.house = self
	add_child(pregnancy)
	baby = BabyLink.new()   # BABY
	baby.name = "BabyLink"
	baby.house = self
	add_child(baby)
	growth = GrowthLink.new()   # GROWTH
	growth.name = "GrowthLink"
	growth.house = self
	add_child(growth)
	recruits = RecruitLink.new()   # RECRUIT
	recruits.name = "RecruitLink"
	recruits.house = self
	add_child(recruits)


## The household's workers: the wife first.
func crew() -> HouseholdCrew:
	return stock.crew


func workers() -> Array:
	return stock.crew.workers


## A spouse of the opposite sex to the player's character, standing near them.
func _new_spouse() -> void:
	if sc != null or not is_instance_valid(player):
		return
	var look: Dictionary = player.appearance.look if player.appearance != null else AppearanceStore.load_current()
	var seed_v := int(bridge.core.state.rng_seed) ^ 0xA11CE
	sc = SpouseCore.create(bridge.core, look, seed_v)
	sc.role = "home"
	sc.worker_id = 0
	open_intimacy(sc)
	if bridge.is_bare():
		BareStart.strip_spouse(sc)
	sc.join(stock)
	_spawn(sc, _start_point())


## A start with nothing opens the intimacy at once (user 2026-10-01: "open the intimacy option at start"): the gauge full.
func open_intimacy(w: SpouseCore) -> void:
	if bridge != null and bridge.is_bare():
		w.intimacy = 1.0
		w.intimacy_cd = 0.0
		w.intimacy_offer_cd = 0.0


func _start_point() -> Vector3:
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	var p := player.global_position + fwd.normalized() * 2.2 + player.global_basis.x * -1.2
	p.y = maxf(FrontierTerrain.height_at(p.x, p.z), player.global_position.y - 0.5)
	return p


func _spawn(w: SpouseCore, at: Vector3) -> Spouse:
	var old: Variant = bodies.get(w.worker_id)
	if old is Node and is_instance_valid(old):
		(old as Node).queue_free()
	w.join(stock)
	var b := Spouse.spawn(get_parent(), w, player, at)
	bodies[w.worker_id] = b
	ToolCarry.attach(b)   # TOOLS: she walks to the chest for her tools and carries one in her hand
	b.talk_requested.connect(func(who: Spouse, tab: String) -> void: open(who, tab))
	if w.worker_id == 0:
		home = at
		stock.home = home
		body = b
		sc = w
	else:
		b.home = home
	_set_hearth()
	return b


## GROWTH: takes a ready-made worker (a grown child, Growth.make_worker) into the household and spawns her body.
func adopt(w: SpouseCore, at: Vector3) -> Spouse:
	w.join(stock)   # (her own id first: _spawn looks the body up by it)
	return _spawn(w, at)


func body_of(w: SpouseCore) -> Spouse:
	var b: Variant = bodies.get(w.worker_id)
	return b as Spouse if b is Spouse and is_instance_valid(b) else null


## The hearth is the campfire nearest home (home itself when there is none).
func _set_hearth() -> void:
	var best := home
	var bd := 40.0
	for n in get_tree().get_nodes_in_group(Campfire.GROUP):
		var c := n as Node3D
		if c == null:
			continue
		var d := c.global_position.distance_to(home)
		if d < bd:
			bd = d
			best = c.global_position
	for b: Variant in bodies.values():
		if b is Spouse and is_instance_valid(b):
			(b as Spouse).home = home
			(b as Spouse).hearth = best


# ---------------------------------------------------------------- the workers
## Takes on another worker (the household's supply chain grows by the jobs she does): a generic unit, any sex and a random
## look unless `sex` (0 female, 1 male) says. `jobs` (job ids) limits what she does; empty: everything. Returns her.
## (Recruiting, RecruitLink, takes on a prepared worker through adopt(); this is the way in for tests and the console.)
func add_worker(seed_v := -1, sex := -1.0, jobs := []) -> SpouseCore:
	if bridge == null or bridge.core == null:
		return null
	if seed_v < 0:
		seed_v = _rng.randi()
	var w := SpouseCore.create_unit(bridge.core, seed_v, sex)
	w.role = "home"
	w.join(stock)
	if not jobs.is_empty():
		stock.crew.set_jobs(w, jobs)
	var at := home + Vector3(_rng.randf_range(-2.0, 2.0), 0.0, _rng.randf_range(-2.0, 2.0))
	if is_instance_valid(player):
		at.y = maxf(FrontierTerrain.height_at(at.x, at.z), player.global_position.y - 0.5)
	_spawn(w, at)
	return w


## Sends a worker away for good (never the wife): what she had taken goes back to the store.
func remove_worker(w: SpouseCore) -> bool:
	if w == null or w.worker_id == 0 or not stock.crew.workers.has(w):
		return false
	w.cancel("left")
	ToolPool.leave(w)   # TOOLS: what she borrowed goes back
	stock.release(w.worker_id)
	var b := body_of(w)
	if recruits != null:
		recruits.on_removed(w, b)   # RECRUIT: they walk away by the road; the departure is kept
	if b:
		b.queue_free()
	bodies.erase(w.worker_id)
	stock.crew.remove(w)
	if screen != null and is_instance_valid(screen):
		screen.sel = 0
	return true


func _process(_dt: float) -> void:
	if sc == null or bridge == null or bridge.core == null:
		return
	for w: SpouseCore in stock.crew.workers:
		w.sync(bridge.core)
	if stock.pool != null:
		stock.pool.tick_house(_dt)   # TOOLS: the start pool once the fort is furnished
	if Input.is_action_just_pressed(ACTION) and screen == null and not get_tree().paused and is_instance_valid(player) \
			and not player.is_dead:
		open(body, "tasks")


## The household screen, on the worker whose body is `who` (the wife by default).
func open(who: Spouse = null, tab := "talk") -> void:
	if screen != null or sc == null:
		return
	screen = HouseholdScreen.open_for(self, tab)
	if who != null and who.sc != null:
		screen.select(who.sc.worker_id)
	screen.tree_exited.connect(func() -> void: screen = null)


# ---------------------------------------------------------------- what the player can ask
## (Each takes the worker it is for; the wife when none.)
func set_role(role: String, w: SpouseCore = null) -> String:
	if not SpouseCore.ROLES.has(role):
		return ""
	w = w if w != null else sc
	w.cancel("new orders")
	w.role = role
	w.focus = ""
	var b := body_of(w)
	if b:
		b._plan = {}
		b.work_at = Vector3.INF
	return pick(["role", role])


## Asks for a job by name: she takes it on its role's ground (cooking and butchering at home, forage and firewood out).
func order(task: String, w: SpouseCore = null) -> String:
	if not JobBook.has(task):
		return ""
	w = w if w != null else sc
	w.cancel("new orders")
	w.enabled[task] = true
	w.role = JobBook.role_of(task)
	w.focus = task
	w._cool = 0.0
	var b := body_of(w)
	if b:
		b._plan = {}
		b.work_at = Vector3.INF
	return pick(["task", task])


## A job (or, with `cascade`, it and what only it feeds) on or off for a worker; her work in hand of it stops.
func set_job(w: SpouseCore, job: String, on: bool, cascade := false) -> void:
	stock.crew.set_enabled(w, job, on, cascade)


## A whole chain on or off for a worker.
func set_chain(w: SpouseCore, chain_id: String, on: bool) -> void:
	stock.crew.set_chain(w, chain_id, on)


func set_home_here() -> String:
	var at := player.global_position
	home = at
	stock.home = home
	_set_hearth()
	return pick(["home_set"])


func pick(path: Array) -> String:
	var v: Variant = lines
	for k in path:
		v = (v as Dictionary).get(k, {}) if v is Dictionary else {}
	if v is Array and not (v as Array).is_empty():
		return String((v as Array)[_rng.randi() % (v as Array).size()])
	return ""


## What she says on meeting the player: by the hour and how she is.
func greeting(w: SpouseCore = null) -> String:
	w = w if w != null else sc
	var stage := SurvivalNeeds.food_stage(w.core)
	if w.core.health() < 60.0:
		return pick(["greet", "hurt"])
	if stage in ["hungry", "very_hungry", "starving", "wasting"]:
		return pick(["greet", "hungry"])
	var h := w.hour()
	var part := "night" if h < 5.0 or h >= 21.5 else "morning" if h < 10.0 else "day" if h < 18.0 else "evening"
	return pick(["greet", part])


# ---------------------------------------------------------------- saving
## {"workers": [{unit, at}], "home"}: the wife first. (An older save has "spouse" and "at" for her alone: load_data reads it.)
func save_data() -> Dictionary:
	if sc == null:
		return {"no_spouse": true}      # (a life alone: a load must not make one)
	var ats := []
	for w: SpouseCore in stock.crew.workers:
		var b := body_of(w)
		if b:
			var p := b.global_position
			ats.append([p.x, p.y, p.z])
		else:
			ats.append([home.x, home.y, home.z])
	var d := stock.crew.to_dict(ats)
	d["home"] = [home.x, home.y, home.z]
	if growth != null:
		growth.flush()   # GROWTH: each child's learning core goes into its record
	d["family"] = family.duplicate(true)
	if stock.pool != null:
		d["tools"] = stock.pool.save_data()   # TOOLS: who holds what, the wear, the broken
	if baby != null:
		d["baby"] = baby.save_data()   # BABY: the needs and the holder
	if recruits != null:
		d["recruit"] = recruits.save_data()   # RECRUIT: the candidates, who joined, who left
	return d


## A life alone: the spouse made at the start is taken away again (a load of a save with none).
func remove_spouse() -> void:
	for b: Variant in bodies.values():
		if b is Node and is_instance_valid(b):
			(b as Node).queue_free()
	bodies.clear()
	stock.crew.workers.clear()
	sc = null
	body = null


func load_data(d: Dictionary) -> void:
	if bool(d.get("no_spouse", false)):
		remove_spouse()
		return
	family = Pregnancy.family_from(d.get("family"))   # old saves have none
	if growth != null:
		growth.reset()   # GROWTH: the records carry the stages; cores and bodies are made again from them
	if baby != null:
		baby.load_data(d.get("baby"))   # BABY: an old save has none: the defaults, the wife holding
	if recruits != null:
		recruits.load_data(d.get("recruit"))   # RECRUIT: an old save has none: a new state
	if not (d.has("workers") or d.has("spouse")) or bridge == null or bridge.core == null:
		return
	for b: Variant in bodies.values():
		if b is Node and is_instance_valid(b):
			(b as Node).queue_free()
	bodies.clear()
	var ats := stock.crew.load_dict(d, bridge.core, stock)
	if stock.pool != null:
		stock.pool.load_data(d.get("tools"))   # TOOLS: an old save has none: the workers' kits come into the pool
	if stock.crew.workers.is_empty():
		return
	var first: Array = ats[0] if not ats.is_empty() and ats[0] is Array else d.get("home", [0, 0, 0])
	var hm: Array = d.get("home", first)
	var i := 0
	for w: SpouseCore in stock.crew.workers:
		var a: Variant = ats[i] if i < ats.size() else null
		var at := Vector3(float(a[0]), float(a[1]), float(a[2])) if a is Array else Vector3(float(hm[0]), float(hm[1]), float(hm[2]))
		_spawn(w, at)
		i += 1
	home = Vector3(float(hm[0]), float(hm[1]), float(hm[2]))
	stock.home = home
	_set_hearth()
