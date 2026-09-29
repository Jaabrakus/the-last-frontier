class_name SurvivalBridge
extends Node
## The one place the game talks to the survival core (SurvivalCore and its modules in scripts/survival; the contract:
## source/graph_analysis/survival/survival_core_api.md). User 2026-09-27: hunger first, "one bridge,
## one clock, the packs mapped", so fire and cold, saves and death, and the winter's goal plug in here.
##
## The core: a new game when the level starts (the backcountry hunter, Early September 1765, 08:00), driven with real
## time in _process (it stops while the tree is paused: the pack, menus).
## One clock: the core's time drives the sky. Every frame the sky's WorldClock (EnvironmentRig.clock_driver) is set to
## the core's game day (WorldClock.set_game_day: the 5th, 15th or 25th of the month) and hour; it no longer runs on its
## own. When something else moves the sky clock on (the Shift+F7 dev key), the core is advanced by as much.
## One weather: the sky's (WeatherSystem, the visible clouds, rain and storms) is the truth; the core is told it twice a
## second (SurvivalWeather.set_external: storm, rain, overcast or clear, and the wind) and no longer rolls its own, so
## the rain that soaks the player is the rain on screen. Without a sky (headless) the core keeps its own weather.
## One health: the player's health is the health. The core's own change each frame (hunger's and cold's drain, its
## hour-by-hour healing when fed) is added to it, and the core is kept at the player's value, so a wolf's bite counts
## for the core and starving or freezing to death kills the player.
## The pack: food lives in the game's pack (InventoryState); data/survival/game_items.json maps a pack unit to the
## core's item and amount; eat() moves one unit into the core and eats it (SurvivalFood.eat). The core's own inventory
## keeps the rest of the kit (the worn clothes set warmth) until the two packs are merged.
## What the world tells the core: the activity (rest, walk, crouch, run, sprint; heavy work while an axe or mattock
## swings), the place (the fort or the woods), the nearest wolf (within 60 m it wakes a sleeper, 25 m stops work).
## Back to the player: move_speed_mult and sprint_allowed (FrontierPlayer.survival_speed_mult, sprint_allowed).
## Sleep is a boost, not a need (user 2026-09-27: "sleep is an added benefit like boost"; "rested allows you to recover
## health faster from items and learn skills faster"): the core's rest need is off (settings.rest_need false: tiredness
## never builds), and sleeping earns WELL RESTED for a while (REST_H_PER_H game hours per hour slept, up to 8 hours'
## worth, longer for better sleep: shelter, bedding, warmth), during which the player heals REST_HEAL_MULT x as fast,
## healing items (a plantain poultice) give REST_ITEM_MULT x, and skills grow REST_SKILL_MULT x (GatherSkills.award_mult).
## Kept in the core's flags (well_rested_until), so it is saved with it.
## Healing once a day (user 2026-09-27: "to not cheat well rested you can be well rested multiple times in a day but only
## once a day regain or healths from effects"): a well-rested sleep heals (heal_rest_until: the faster healing, the
## stronger remedies, the faster clotting, the lasting harms' cure that wants rest, a wound's knitting) only if the last
## one that healed was HEAL_REST_GAP_H or more before (a night's sleep, night after night, even at a different hour); a
## nap in between is well rested again for the skills and the sobering, and heals nothing more.
## Fire, cold and shelter (user 2026-09-27: "the campfire and lean-to ... need to tell the bridge when you're near a lit
## fire or inside a shelter. The same connection lets them cook cornmeal and venison, and makes sleep better so the
## well-rested boost lasts longer"): CampLink (camp) keeps a core record for each built campfire and lean-to and tells
## the core the player's fire (fire_id, fire_distance_m) and shelter (in_shelter, shelter_id), so a lit fire warms and
## dries, a lean-to keeps off the wind and the rain, and the fire burns on the core's clock; CampCooking (cook) roasts
## venison and bakes cornmeal into johnnycake on a lit fire (F); a sleep's quality (rest_quality(): the core's, better
## by a fire) is averaged over the night and sets how long WELL RESTED lasts (up to REST_MULT_MAX x).
## Keys: V eats the best food in the pack; Z sleeps (SurvivalSleep); F cooks at a lit campfire (CampCooking). The pack
## eats on a right-click (InventoryScreen).
##
## For the other systems:
##   SurvivalBridge.find(tree) -> the level's bridge; .core
##   set_context({fire_id, fire_distance_m, in_shelter, shelter_id, indoors, bedding, near, ...})  merged into the core's
##       context (SurvivalCore.set_context lists the keys)
##   eat(kind, inv) -> {ok, text}; can_eat(kind); best_food(inv)
##   sleeper.start() / sleeper.wake(); sleeper.sleeping
##   camp.refresh(), camp.told (the fire and shelter context), rest_quality(); cook.start(campfire), cook.last
##   work (StationWork: the player at a station's work); pack_item(kind) / pack_kind_of(core item) (game_items.json
##       "items" and "materials": hides, brains, buckskin, rawhide for the crafting stations, CampStation)
##   save_state() -> Dictionary; load_state(doc) -> bool   (the survival half of a save: needs, conditions, the clock
##       and date, weather, the kit, skills; SurvivalSave.to_document / from_document)
##   revive(): after a respawn, the core is alive again (what death costs is for the death rule to decide)
##   signals needs_changed(), died(cause)

signal needs_changed
signal died(cause: String)

const GROUP := &"survival_bridge"
const ITEMS_PATH := "res://data/survival/game_items.json"
const BACKGROUND := "bg.backcountry_hunter"
const START_DAY := "sep_early"
const START_HOUR := 8.0
## A wolf this near is reported to the core (it wakes a sleeper; 25 m stops work).
const THREAT_M := 60.0
## Within the palisade the core is told the player is at the fort, outside in the woods.
const FORT_HALF := 16.0
## Well rested (the sleep boost): game hours of it per hour slept (up to REST_MAX_SLEPT_H), x the sleep's quality
## over REST_Q_REF (0.5-REST_MULT_MAX); at least REST_MIN_SLEPT_H slept to earn it. Eight hours: rough on the bare
## ground 9 h, by a fire 11, in a lean-to 15, in a lean-to by a fire 17 (CampLink.rest_quality).
const REST_H_PER_H := 1.5
const REST_MAX_SLEPT_H := 8.0
const REST_MIN_SLEPT_H := 1.0
const REST_Q_REF := 0.8
const REST_MULT_MAX := 1.5
## Air colder than this (C), out of doors: a bitter night, extreme cold (only a sleep by a heat source rests).
const EXTREME_AIR_C := -10.0
## Well rested, the body throws off drink this much faster (the meter's decay and a hangover's hours; user 2026-09-27:
## "heal addiction faster").
const REST_SOBER_MULT := 2.0
## While well rested: healing (the core's 1 an hour) this many times as fast, healing items this much stronger and
## faster, skills this much faster.
const REST_HEAL_MULT := 3.0
const REST_ITEM_MULT := 1.5
const REST_SKILL_MULT := 1.25
## Hunger and the boost (user 2026-09-27: "it should cap the well rested", "full stomachs drains the well rested
## slower"; no starving to death: hunger works on the boost instead). The most boost a stage allows (game hours; the
## stages not named: no cap), and how fast it runs down (game hours of it per game hour).
const REST_CAP_H := {"hungry": 8.0, "very_hungry": 4.0, "starving": 0.0, "wasting": 0.0}
## Game hours from one healing sleep to the next (healing once a day).
const HEAL_REST_GAP_H := 16.0
const REST_DRAIN := {"fed": 0.6, "peckish": 1.0, "hungry": 1.5, "very_hungry": 2.5, "starving": 4.0, "wasting": 4.0}

var core: SurvivalCore
var player: FrontierPlayer
var rig: EnvironmentRig
var sleeper: SurvivalSleep
## Drink and tobacco: the kit, the use, the habit (Vices).
var vices: Vices
var camp: CampLink
## Whether the last sleep (grant_rest) was the day's healing one.
var last_rest_healed := false
## Chilled to the bone (LastingChill): the cold's lasting damage, and why it no longer kills.
var chill: LastingChill
## What the other needs leave when neglected (LastingConditions: wasted, the ague, a festering wound, the flux, sore
## feet): the decay the player fixes (user 2026-09-27: "the pressure is stunted growth and decay").
var lasting: LastingConditions
var cook: CampCooking
var work: StationWork
## Game kind -> {item, qty} for what is not food (game_items.json "materials").
var materials := {}
## Game kind -> {item, qty, note} (game_items.json).
var items := {}
## 0: a new seed each game (tests set one).
var run_seed := 0
## Why the character died, when the core killed them ("starvation", "cold", ...).
var death_cause := ""

var _clock: WorldClock
var _sky_doy := -1.0
var _sky_hour := -1.0
var _sky_day := -1
var _health := 100.0
var _activity := ""
var _place := ""
var _threat_t := 0.0
var _threat_on := false
var _player_was_dead := false
var _weather_t := 0.0
var _last_min := -1.0


## On unless the user arg survival=off; tool and test scripts (-s) run without it unless they pass survival=on (they set
## the sky's hour themselves, which the bridge would take over).
static func enabled() -> bool:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("survival="):
			var v := s.get_slice("=", 1)
			return v != "off" and v != "0"
	var args := OS.get_cmdline_args()
	return not ("-s" in args or "--script" in args)


static func find(tree: SceneTree) -> SurvivalBridge:
	return tree.get_first_node_in_group(GROUP) as SurvivalBridge if tree else null


static func load_items(section := "items") -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	return (d as Dictionary).get(section, {}) if d is Dictionary else {}


## The core item and amount of one pack unit of `kind` ({item, qty}; {} when the core has no such thing).
func pack_item(kind: String) -> Dictionary:
	if materials.has(kind):
		return materials[kind]
	return items.get(kind, {})


## The pack kind a core item comes back as ("" when it stays with the core's kit): the materials first, then food
## (the first kind listed for it: roast venison before charred).
func pack_kind_of(item: String) -> String:
	for table: Dictionary in [materials, items]:
		for k: String in table:
			if String(table[k].get("item", "")) == item:
				return k
	return ""


func setup(p: FrontierPlayer, environment: EnvironmentRig) -> void:
	player = p
	rig = environment


func _ready() -> void:
	add_to_group(GROUP)
	InputSetup.ensure()
	items = load_items()
	materials = load_items("materials")
	# a fixed seed for a run (user arg survival_seed=N: tests, replays)
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--").begins_with("survival_seed=") and run_seed == 0:
			run_seed = int(a.get_slice("=", 1))
	# Vices first: a new game gives its kit (the flask, the twist, the pipe)
	vices = Vices.new()
	vices.name = "Vices"
	vices.bridge = self
	add_child(vices)
	if core == null:
		new_game(start_background(), {"bare": start_bare()})
	sleeper = SurvivalSleep.new()
	sleeper.name = "Sleep"
	sleeper.bridge = self
	add_child(sleeper)
	chill = LastingChill.new()
	chill.name = "Chill"
	chill.bridge = self
	add_child(chill)
	lasting = LastingConditions.new()
	lasting.name = "Lasting"
	lasting.bridge = self
	add_child(lasting)
	camp = CampLink.new()
	camp.name = "Camp"
	camp.bridge = self
	add_child(camp)
	cook = CampCooking.new()
	cook.name = "Cooking"
	cook.bridge = self
	add_child(cook)
	work = StationWork.new()
	work.name = "Work"
	work.bridge = self
	add_child(work)


## The background a new game starts from: the one chosen in the main menu's New game (MainMenu.background_id, taken
## once), else BACKGROUND.
static func start_background() -> String:
	var id := MainMenu.background_id
	MainMenu.background_id = ""
	return id if id.begins_with("bg.") else BACKGROUND


## Whether this new game starts with nothing (the main menu's "Start with nothing", taken once; or the user arg
## start=bare for tests and tools).
static func start_bare() -> bool:
	var v := MainMenu.bare_start
	MainMenu.bare_start = false
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--") == "start=bare":
			v = true
	return v


## Whether this character started with nothing (kept in the core's flags, so a save keeps it): no tool, weapon,
## clothes or food is handed out again (GatherTools, FieldDressing, Campfire.ensure_striker).
func is_bare() -> bool:
	return core != null and bool(core.state.flags.get("bare_start", false))


## Whether the level's character started with nothing (false without the survival rules).
static func bare_of(tree: SceneTree) -> bool:
	var b := find(tree)
	return b != null and b.is_bare()


## The pack's tools the survival rules ask the kit for (a knife, an axe) stand in the core's kit while they are carried:
## pack kind -> the core's item (game_items.json materials). Called every SYNC_S and by the makers.
const TOOL_KINDS := ["flint_knife", "stone_axe", "bone_awl"]
const SYNC_S := 0.3
var _sync_t := 0.0


## A start with nothing's steel tools, forged: while carried, the rules' knife and axe (a normal start's kit has its own,
## so these are kept in step only in a start with nothing).
const BARE_TOOL_ITEMS := {"skinning_knife": "item.tool.knife", "felling_axe": "item.tool.axe", "fire_steel": "item.tool.fire_steel"}


func sync_carried_tools() -> void:
	if core == null or player == null or not is_instance_valid(player):
		return
	var changed := false
	var kinds: Array = TOOL_KINDS.duplicate()
	if is_bare():
		kinds.append_array(BARE_TOOL_ITEMS.keys())
	for k: String in kinds:
		var item := String(BARE_TOOL_ITEMS.get(k, materials.get(k, {}).get("item", "")))
		if item == "":
			continue
		var have := SurvivalInventory.count(core, item)
		var carry := 0
		for e: Dictionary in player.inventory_pack:
			if String(e.get("kind", "")) == k:
				carry += int(e.get("count", 0))
		if player.loadout and player.loadout.has_kind(k):
			carry += 1
		if carry > 0 and have < 1.0 - 0.0001:
			SurvivalInventory.add(core, item, 1.0)
			changed = true
		elif carry <= 0 and have > 0.0001:
			SurvivalInventory.remove(core, item, have)
			changed = true
	if changed:
		core._on_inventory_changed()


## A new character: the core's new game, and the kit's food and gear into the pack (a start with nothing: nothing).
func new_game(bg := BACKGROUND, opts := {}) -> void:
	var o := {"seed": run_seed, "start_day": START_DAY, "start_hour": START_HOUR, "settings": {"rest_need": false}}
	for k in opts:
		if k != "bare":
			o[k] = opts[k]
	_attach(SurvivalCore.new_game(bg, o))
	if bool(opts.get("bare", false)):
		BareStart.apply(self)
		return
	_move_start_food()
	_move_start_gear()
	if vices:
		vices.give_kit()


func _attach(c: SurvivalCore) -> void:
	if core != null:
		for s in [[core.need_stage_changed, _on_stage], [core.died, _on_core_died], [core.passed_out, _on_passed_out]]:
			if (s[0] as Signal).is_connected(s[1]):
				(s[0] as Signal).disconnect(s[1])
	core = c
	core.need_stage_changed.connect(_on_stage)
	core.died.connect(_on_core_died)
	core.passed_out.connect(_on_passed_out)
	_activity = ""
	_place = ""
	_sky_day = -1
	if player:
		core.state.needs["health"] = player.health
	_health = core.health()
	if sleeper:
		sleeper.hook(core)
	if chill:
		chill.reset_clock()
	if lasting:
		lasting.reset_clock()
	if cook:
		cook.hook(core)
	if camp:
		camp.told = {}


## The food of the core's starting kit goes into the game's pack (whole units), the rest stays with the core.
func _move_start_food() -> void:
	if player == null:
		return
	var inv := InventoryState.from_player(player)
	for kind: String in items:
		var id := String(items[kind].item)
		var per := float(items[kind].get("qty", 1.0))
		var have := SurvivalInventory.count(core, id)
		var units := floori(have / per + 0.0001)
		if units <= 0:
			continue
		SurvivalInventory.remove(core, id, float(units) * per)
		inv.add(kind, units)
	player.inventory_pack = inv.pack.duplicate(true)


## The kit's trapping, shot-making and fishing gear goes into the pack (game_items.json "start_gear": steel traps, bar
## lead, the bullet mould, hooks and line, sinew; user 2026-09-28, "making your gear", "trapping lines"): whole units of
## each, as the food; what the pack has no kind for stays with the core's kit (the powder, by the pound).
func _move_start_gear() -> void:
	if player == null:
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	var kinds: Array = (d as Dictionary).get("start_gear", []) if d is Dictionary else []
	var inv := InventoryState.from_player(player)
	for kind: String in kinds:
		if not materials.has(kind):
			continue
		var id := String(materials[kind].item)
		var per := float(materials[kind].get("qty", 1.0))
		var units := floori(SurvivalInventory.count(core, id) / per + 0.0001)
		if units <= 0:
			continue
		SurvivalInventory.remove(core, id, float(units) * per)
		inv.add(kind, units)
	player.inventory_pack = inv.pack.duplicate(true)


# --- The frame ---------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if core == null or player == null or not is_instance_valid(player):
		return
	# back from the dead (a respawn): the core lives again. (A core that has just died with the player still up is
	# the other way round: _health_sync kills the player.)
	if core.is_dead() and not player.is_dead and _player_was_dead:
		revive()
	_player_was_dead = player.is_dead
	_sky_in()
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = SYNC_S
		sync_carried_tools()
	_tell_core(delta)
	_weather_from_sky(delta)
	core.update(delta)
	_health_sync()
	_rested_tick()
	if chill:
		chill.tick()
		_health = core.health()
	if lasting:
		lasting.tick()
		_health = core.health()
	_to_player()
	_sky_out()
	_player_was_dead = player.is_dead


func _physics_process(_delta: float) -> void:
	if core == null or player == null or player.is_dead or get_tree().paused:
		return
	if Input.is_action_just_pressed(&"eat") and not (sleeper and sleeper.sleeping):
		var k := best_food()
		var r := eat(k) if k != "" else {"ok": false, "text": "Nothing to eat in the pack that you can eat now"}
		_notice(String(r.text))


## The activity, the place and the nearest wolf.
func _tell_core(delta: float) -> void:
	var a := "rest"
	if player.is_dead:
		a = "rest"
	elif player.riding != null:
		a = "walk"
	elif player.kneeling != null:
		a = "rest"
	elif player.gather != null and not (player.gather.get("_swing") as Dictionary).is_empty():
		a = "heavy_work"
	else:
		var v := Vector2(player.velocity.x, player.velocity.z).length()
		if v < 0.3:
			a = "rest"
		elif player.is_crouching:
			a = "crouch"
		elif player.is_sprinting:
			a = "sprint"
		elif v > 2.5:
			a = "run"
		else:
			a = "walk"
	if a != _activity:
		_activity = a
		core.set_activity(a)
	var p := player.global_position
	var place := "poi.fort" if absf(p.x) < FORT_HALF and absf(p.z) < FORT_HALF else "poi.fort.woods"
	if place != _place:
		_place = place
		core.set_context({"location": place})
	_threat_t -= delta
	if _threat_t <= 0.0:
		_threat_t = 0.5
		var d := _nearest_wolf()
		if d < THREAT_M:
			core.report_threat(d)
			_threat_on = true
		elif _threat_on:
			core.clear_threat()
			_threat_on = false


func _nearest_wolf() -> float:
	var sp := get_tree().current_scene.get_node_or_null("Wildlife") if get_tree().current_scene else null
	if sp == null:
		return INF
	var best := INF
	for w in (sp.call("wolves_now") if sp.has_method("wolves_now") else []):
		if is_instance_valid(w):
			best = minf(best, (w as Node3D).global_position.distance_to(player.global_position))
	return best


## One health (the player's): the core's own change this frame is added to the player; the core follows the player.
func _health_sync() -> void:
	if player.is_dead:
		_health = core.health()
		return
	var d := core.health() - _health
	var cold := chill != null and chill.cold_drains()
	if core.is_dead() and not player.is_dead and cold:
		# the cold no longer kills (LastingChill): the core that died of it wakes again at the floor
		core.state.flags.erase("dead")
		core.state.flags.erase("death_cause")
		core.state.needs["health"] = LastingChill.COLD_FLOOR
		player.health = minf(player.health, LastingChill.COLD_FLOOR) if player.health > LastingChill.COLD_FLOOR else player.health
		core.invalidate_modifiers()
		_health = core.health()
		return
	if d < -0.0001:
		if cold:
			# the cold's drain stops at the floor
			d = maxf(d, minf(LastingChill.COLD_FLOOR - player.health, 0.0))
		if player.health + d <= 0.0:
			_kill(core.state.flags.get("death_cause", "hunger and cold"))
			return
		player.health += d
	elif d > 0.0001:
		# the body's own healing: slower, and no higher than the cap, while chilled to the bone or another lasting
		# condition holds it (LastingConditions)
		var k := heal_mult()
		var cap := health_cap()
		player.health = minf(player.health + d * k, maxf(cap, player.health))
	if not core.is_dead():
		core.state.needs["health"] = player.health
	_health = core.health()
	if core.is_dead() and not player.is_dead:
		_kill(String(core.state.flags.get("death_cause", "")))


func _kill(cause: String) -> void:
	death_cause = cause
	if sleeper and sleeper.sleeping:
		sleeper.stop_now()
	player.apply_hit(player.health + 1.0, player.global_position + Vector3.UP, Vector3.DOWN, self, "body")
	_notice({"starvation": "You starved to death", "cold": "You froze to death", "bleeding": "You bled to death"}.get(cause, "You died"))
	died.emit(cause)


## The core passed the player out (drink past its limit): they go down where they stand (SurvivalSleep).
func _on_passed_out(_reason: String, _hours: float) -> void:
	if sleeper and player and not player.is_dead:
		sleeper.pass_out_now()


func _on_core_died(cause: String) -> void:
	# the player died first and said of what (PlayerWounds: bled to death); the core only follows their health to 0
	if player and player.is_dead and death_cause != "":
		return
	death_cause = cause


## The core alive again after a respawn, with the player's health, and not dying of what killed them on the spot (the
## death rule, later, decides what death costs).
func revive() -> void:
	core.state.flags.erase("dead")
	core.state.flags.erase("death_cause")
	core.state.needs["health"] = player.health
	if float(core.state.needs.get("stomach", 0.0)) <= 0.0 and float(core.state.needs.get("reserve", 0.0)) <= 0.0:
		core.state.needs["reserve"] = 800.0
	core.state.needs["warmth"] = maxf(float(core.state.needs.get("warmth", 100.0)), 60.0)
	core.invalidate_modifiers()
	_health = core.health()
	death_cause = ""
	needs_changed.emit()


## Modifiers back to the player (the lasting harms never touch the speed or the aim: user 2026-09-27); an arm wound tires
## the climbing grip sooner (the reload: Vices._apply_player).
func _to_player() -> void:
	var m := core.get_modifiers()
	player.survival_speed_mult = float(m.get("move_speed_mult", 1.0))
	player.sprint_allowed = bool(m.get("sprint_allowed", true))
	if player.grip:
		player.grip.drain_mult = lasting.grip_drain_mult() if lasting else 1.0


# --- Well rested (the sleep boost) -------------------------------------------------------------------------

func is_well_rested() -> bool:
	return core != null and core.state.minutes < float(core.state.flags.get("well_rested_until", -1.0))


## Well rested by the day's healing sleep: the boost that heals (see the header). A boost from before this rule (no
## heal_rest_until yet) heals.
func is_healing_rest() -> bool:
	if not is_well_rested():
		return false
	var f := core.state.flags
	return not f.has("heal_rest_until") or core.state.minutes < float(f.heal_rest_until)


## Whether a sleep ending now would be a healing one (HEAL_REST_GAP_H since the last).
func heal_rest_due() -> bool:
	var at := float(core.state.flags.get("heal_rest_at", -INF)) if core else -INF
	return core != null and core.state.minutes - at >= HEAL_REST_GAP_H * 60.0


## Game hours of the boost left (0 when none).
func rested_hours_left() -> float:
	if core == null:
		return 0.0
	return maxf(float(core.state.flags.get("well_rested_until", -1.0)) - core.state.minutes, 0.0) / 60.0


## What `slept_h` hours of sleep at `quality` (SurvivalNeeds.sleep_quality: 0.2-1.1) earn: game hours of the boost.
static func rest_earned_h(slept_h: float, quality: float) -> float:
	if slept_h < REST_MIN_SLEPT_H:
		return 0.0
	return minf(slept_h, REST_MAX_SLEPT_H) * REST_H_PER_H * clampf(quality / REST_Q_REF, 0.5, REST_MULT_MAX)


## Extreme cold, when only a sleep by a heat source rests (SurvivalSleep): chilled to the bone (LastingChill), or a bitter
## night (the air under EXTREME_AIR_C) out of doors.
func extreme_cold() -> bool:
	if chill and chill.is_on():
		return true
	return core != null and not bool(core.state.context.get("indoors", false)) and SurvivalClock.air_temp_c(core) < EXTREME_AIR_C


## A heat source by the player: a lit (or banked) fire within CampLink.FIRE_SLEEP_M, or indoors by a lit hearth.
func by_heat() -> bool:
	if core != null and bool(core.state.context.get("indoors", false)):
		return true
	return camp != null and camp.by_fire(CampLink.FIRE_SLEEP_M)


## How well the player would sleep here now (CampLink: the core's quality, better by a lit fire).
func rest_quality() -> float:
	return camp.rest_quality() if camp else SurvivalNeeds.sleep_quality(core)


## The most boost the stomach allows now (game hours; INF: no cap). None while drunk (tipsy or worse) or hungover
## (the queasy morning after: user 2026-09-27, "you are not well rested, hence the hangover").
func rest_cap_h() -> float:
	if core == null:
		return INF
	# a warm rest (a sleep by a heat source) is not capped: the drinker, the hungover and the hungry are well rested by a
	# fire (user 2026-09-27: "the well rest meter allows addicted people with capped rest meters to become well rested")
	if core.state.minutes < float(core.state.flags.get("warm_rest_until", -1.0)):
		return INF
	if SurvivalConditions.stage_of(core, "cond.drunk") in PlayerWounds.DRUNK_STAGES:
		return 0.0
	# a relapse while addicted (Vices): no boost for a while, sober or not
	if vices and vices.blocks_rest():
		return 0.0
	var q: Dictionary = core.state.conditions.get("cond.queasy", {})
	if String(q.get("cause", "")) == "hangover":
		return 0.0
	var st := String(core.need_stages().get("need.food", "fed"))
	return float(REST_CAP_H.get(st, INF))


## How fast the boost runs down now (x its hours): slower on a full stomach, faster the hungrier.
func rest_drain() -> float:
	var st := String(core.need_stages().get("need.food", "fed")) if core else "fed"
	return float(REST_DRAIN.get(st, 1.0))


## A sleep ended (SurvivalSleep): the boost from now, the longer of what is left and what this sleep earned, no more
## than the stomach allows (rest_cap_h).
func grant_rest(slept_h: float, quality: float, warm := false) -> float:
	var h := rest_earned_h(slept_h, quality)
	# restless (a leg wound, sore feet, the ague: LastingConditions): away from a fire a sleep rests half as well
	if lasting:
		h *= lasting.rest_mult(warm)
	# calm on hemp or on laudanum, a sleep rests deep (Vices)
	if vices:
		h *= vices.rest_mult()
	if not warm:
		h = minf(h, rest_cap_h())
	last_rest_healed = false
	if h <= 0.0:
		return 0.0
	var until := maxf(float(core.state.flags.get("well_rested_until", -1.0)), core.state.minutes + h * 60.0)
	core.state.flags["well_rested_until"] = until
	if warm:
		core.state.flags["warm_rest_until"] = until
	# the day's healing sleep; a nap before the next is due only rests
	if heal_rest_due():
		core.state.flags["heal_rest_at"] = core.state.minutes
		core.state.flags["heal_rest_until"] = until
		last_rest_healed = true
	needs_changed.emit()
	return h


## Healing items' strength and speed now (ForageUse).
func heal_item_mult() -> float:
	return (REST_ITEM_MULT if is_healing_rest() else 1.0) * heal_mult()


## The most the health heals to now: the lowest of what chilled to the bone (LastingChill) and the other lasting
## conditions (LastingConditions: wasted, festering) allow.
func health_cap() -> float:
	var mx := float(player.max_health) if player else 100.0
	var cap := chill.health_cap() if chill else mx
	if lasting:
		cap = minf(cap, lasting.health_cap())
	return cap


## Every heal's speed now (chilled to the bone, the ague).
func heal_mult() -> float:
	return (chill.heal_mult() if chill else 1.0) * (lasting.heal_mult() if lasting else 1.0)


## Every skill's growth now: well rested faster, wasted slower (GatherSkills.award_mult and the core's own skills).
func skill_mult() -> float:
	return (REST_SKILL_MULT if is_well_rested() else 1.0) * (lasting.skill_mult() if lasting else 1.0) \
			* (vices.skill_mult() if vices else 1.0)


static func heal_item_mult_in(tree: SceneTree) -> float:
	var b := find(tree)
	return b.heal_item_mult() if b else 1.0


## The boost's healing and skills.
func _rested_tick() -> void:
	var m := core.state.minutes + float(core.state.world.get("clock_acc", 0.0))
	var dm := m - _last_min if _last_min >= 0.0 else 0.0
	_last_min = m
	# the boost runs down faster or slower with the stomach, and never past what hunger allows
	if is_well_rested() and dm > 0.0 and dm < 600.0:
		var left := float(core.state.flags.get("well_rested_until", -1.0)) - core.state.minutes
		left -= dm * (rest_drain() * (lasting.rest_drain_mult() if lasting else 1.0) - 1.0)
		left = minf(left, rest_cap_h() * 60.0)
		core.state.flags["well_rested_until"] = core.state.minutes + left if left > 0.0 else core.state.minutes - 1.0
		# the healing ends with the boost it came with (a nap later does not take up what hunger cut short)
		if core.state.flags.has("heal_rest_until"):
			core.state.flags["heal_rest_until"] = minf(float(core.state.flags.heal_rest_until), float(core.state.flags.well_rested_until))
	var on := is_well_rested()
	if on and dm > 0.0 and dm < 600.0:
		_sober(dm)
	if is_healing_rest() and not player.is_dead and dm > 0.0 and dm < 600.0 and player.health < player.max_health:
		# the core heals 1 an hour on its own (SurvivalNeeds.HEALTH_REGEN_PER_H); well rested, (mult - 1) more
		var extra := SurvivalNeeds.HEALTH_REGEN_PER_H * (REST_HEAL_MULT - 1.0) * dm / 60.0
		extra *= heal_mult()
		if float(core.get_modifiers().get("health_regen_mult", 1.0)) > 0.0:
			var cap := health_cap()
			player.health = minf(player.health + extra, maxf(cap, player.health))
			core.state.needs["health"] = player.health
			_health = core.health()
	var sm := skill_mult()
	var g: Variant = player.gather.get("skills") if player.gather else null
	if g is GatherSkills:
		(g as GatherSkills).award_mult = sm
	# the core's own skills too (SurvivalSkills.practice)
	core.state.flags["skill_growth_mult"] = sm


## Well rested: the drink meter runs down and a hangover passes REST_SOBER_MULT times as fast.
func _sober(dm: float) -> void:
	var n := core.state.needs
	var extra := REST_SOBER_MULT - 1.0
	if float(n.get("drunk", 0.0)) > 0.0:
		var dec := SurvivalUtil.num(SurvivalUtil.dict(core.data.condition("cond.drunk").get("meter")).get("decay_per_game_h"), 10.0)
		n["drunk"] = maxf(0.0, float(n.drunk) - dec * extra * dm / 60.0)
	var q: Dictionary = core.state.conditions.get("cond.queasy", {})
	if String(q.get("cause", "")) == "hangover" and q.has("dur_h"):
		q["dur_h"] = float(q.dur_h) - extra * dm / 60.0


# --- One clock ---------------------------------------------------------------------------------------------

func sky_clock() -> WorldClock:
	if _clock == null and rig != null and rig.clock_driver != null:
		_clock = rig.clock_driver.clock
		if _clock:
			_clock.running = false
	return _clock


## The sky clock moved on by someone else since the bridge set it (a dev key): the core goes on by as much.
func _sky_in() -> void:
	var c := sky_clock()
	if c == null or _sky_hour < 0.0:
		return
	var dh := (c.day_of_year - _sky_doy) * 24.0 + (c.hour - _sky_hour)
	if dh > 0.01 and dh < 24.0 * 40.0:
		core.advance(dh * 60.0)
	elif dh < -0.01:
		_sky_day = -1       # moved back: the core cannot go back; the sky is set to the core again below


## The core's time as the sky shows it: its minutes plus the real time it has banked toward its next 10-minute step
## (the core steps in whole quanta, about every 24 real seconds by day; the sun must not jump).
func sky_minutes() -> float:
	return core.state.minutes + float(core.state.world.get("clock_acc", 0.0))


## {game_day (0..35), year, hour} of the sky's time.
func sky_time() -> Dictionary:
	var m := sky_minutes()
	var ad := floori(m / SurvivalClock.MIN_PER_DAY)
	var dpy := SurvivalClock.days_per_year(core)
	return {"game_day": posmod(ad, dpy), "year": core.state.base_year + floori(float(ad) / float(dpy)),
			"hour": fposmod(m, SurvivalClock.MIN_PER_DAY) / 60.0}


func sky_weather() -> WeatherSystem:
	return rig.clock_driver.weather if rig != null and rig.clock_driver != null else null


## The sky's weather as a core weather state: a storm with its rain, rain, a grey sky, or clear.
static func weather_state_of(ws: WeatherSystem) -> String:
	if ws.kind == WeatherSystem.Kind.STORM and ws.rain > 0.4:
		return "storm"
	if ws.rain > 0.08:
		return "rain"
	if ws.overcast > 0.6:
		return "overcast"
	return "clear"


func _weather_from_sky(delta: float) -> void:
	_weather_t -= delta
	if _weather_t > 0.0:
		return
	_weather_t = 0.5
	var ws := sky_weather()
	if ws == null:
		return
	# the ground wind is about half the wind aloft the clouds ride
	SurvivalWeather.set_external(core, weather_state_of(ws), ws.wind_ms * 0.5, ws.wind_from_deg)


func _sky_out() -> void:
	var c := sky_clock()
	if c == null:
		return
	c.running = false               # the core's time is the sky's (DayNight starts it running)
	var t := sky_time()
	if int(t.game_day) != _sky_day:
		_sky_day = int(t.game_day)
		c.set_game_day(int(t.game_day), int(t.year))
	c.set_time(float(t.hour))
	_sky_doy = c.day_of_year
	_sky_hour = c.hour


# --- The core's inputs from other systems ------------------------------------------------------------------

## Merge keys into the core's context (fire, shelter, indoors, bedding, near...: SurvivalCore.set_context).
func set_context(ctx: Dictionary) -> void:
	core.set_context(ctx)


# --- Eating ------------------------------------------------------------------------------------------------

func can_eat(kind: String) -> bool:
	return items.has(kind)


## Why `kind` cannot be eaten now ("" when it can).
func why_not(kind: String) -> String:
	var e: Dictionary = items.get(kind, {})
	if e.is_empty():
		return "You cannot eat that"
	var id := String(e.item)
	var it := core.data.item(id)
	if bool(it.get("needs_cooking", false)):
		return "%s must be cooked first: bake it on a lit campfire (%s)" % [InventoryState.name_of(kind), CampCooking._key_name()]
	if not SurvivalFood.edible(core, id):
		return "%s are too bitter to eat: they must be leached first" % InventoryState.name_of(kind) if kind == "acorns" \
				else "%s cannot be eaten as it is" % InventoryState.name_of(kind)
	var room := _room()
	if room < 50.0:
		return "You are too full to eat"
	if unit_kcal(kind) > room * 1.5 + 50.0:
		return "You are too full to eat a whole %s now" % InventoryState.name_of(kind).to_lower()
	return ""


## Game kcal in one pack unit of `kind`.
func unit_kcal(kind: String) -> float:
	var e: Dictionary = items.get(kind, {})
	if e.is_empty():
		return 0.0
	return SurvivalInventory.stack_kcal(core, {"id": String(e.item), "qty": float(e.get("qty", 1.0)), "meta": {}})


func _room() -> float:
	var cap := float(SurvivalNeeds.need_row(core, "need.food").get("stomach_capacity_kcal", 3000.0))
	return cap - float(core.state.needs.get("stomach", 0.0))


## Eats one unit of `kind` from `inv` (the screen's copy of the pack; null: the player's pack). {ok, text, queasy,
## vomited}.
func eat(kind: String, inv: InventoryState = null) -> Dictionary:
	var own := inv == null
	if own:
		inv = InventoryState.from_player(player)
	if inv.pack_count(kind) <= 0:
		return {"ok": false, "text": "No %s in the pack" % InventoryState.name_of(kind).to_lower()}
	var why := why_not(kind)
	if why != "":
		return {"ok": false, "text": why}
	var e: Dictionary = items[kind]
	var id := String(e.item)
	var before := SurvivalInventory.count(core, id)
	var stomach0 := float(core.state.needs.get("stomach", 0.0))
	SurvivalInventory.add(core, id, float(e.get("qty", 1.0)))
	var r := SurvivalFood.eat(core, id, {"force": true})
	# whatever of the unit the meal left goes too: the pack unit is eaten whole
	var left := SurvivalInventory.count(core, id) - before
	if left > 0.0001:
		SurvivalInventory.remove(core, id, left)
	if not bool(r.get("ok", false)):
		var reason := String(r.get("reason", "you cannot eat that now"))
		return {"ok": false, "text": reason.substr(0, 1).to_upper() + reason.substr(1)}
	inv.take(kind, 1)
	if own:
		player.inventory_pack = inv.pack.duplicate(true)
	# the flux: a meal nourishes half (LastingConditions); raw meat and what it did, blackberries, told to it
	if lasting:
		# (a quid in the cheek: food sits poorly, Vices)
		var fm := lasting.food_mult() * (vices.food_mult() if vices else 1.0)
		var gained := float(core.state.needs.get("stomach", 0.0)) - stomach0
		if fm < 1.0 and gained > 0.0:
			core.state.needs["stomach"] = float(core.state.needs.stomach) - gained * (1.0 - fm)
		lasting.ate(kind, core.data.item(id).has("raw_risk"), bool(r.get("queasy", false)) or bool(r.get("vomited", false)))
	core.invalidate_modifiers()
	needs_changed.emit()
	var t := "You eat the %s" % InventoryState.name_of(kind).to_lower()
	if bool(r.get("vomited", false)):
		t += ", and it comes back up"
	elif bool(r.get("queasy", false)):
		t += ": it turns your stomach"
	return {"ok": true, "text": t, "queasy": bool(r.get("queasy", false)), "vomited": bool(r.get("vomited", false))}


## The food to eat now from `inv` (null: the player's pack): what can be eaten, safe before raw meat, the most filling
## first; "" when there is none.
func best_food(inv: InventoryState = null) -> String:
	if inv == null:
		inv = InventoryState.from_player(player)
	var best := ""
	var bs := -INF
	for kind: String in items:
		if inv.pack_count(kind) <= 0 or why_not(kind) != "":
			continue
		var s := unit_kcal(kind)
		if core.data.item(String(items[kind].item)).has("raw_risk"):
			s -= 10000.0
		if s > bs:
			bs = s
			best = kind
	return best


## Meals the pack holds that can be eaten now (the only food figure the player sees).
func pack_meals() -> float:
	if player == null:
		return 0.0
	var inv := InventoryState.from_player(player)
	var kcal := 0.0
	for kind: String in items:
		var n := inv.pack_count(kind)
		if n <= 0:
			continue
		var id := String(items[kind].item)
		if bool(core.data.item(id).get("needs_cooking", false)) or not SurvivalFood.edible(core, id):
			continue
		kcal += unit_kcal(kind) * n
	return kcal / SurvivalFood.meal_kcal(core)


# --- Saves -------------------------------------------------------------------------------------------------

## The survival half of a save (needs, conditions, the clock and date, weather, the kit, skills, knowledge).
func save_state() -> Dictionary:
	return SurvivalSave.to_document(core)


func load_state(doc: Dictionary) -> bool:
	var c := SurvivalSave.from_document(doc)
	if c == null:
		return false
	_attach(c)
	needs_changed.emit()
	return true


# --- Notices -----------------------------------------------------------------------------------------------

const STAGE_LINES := {
	"need.food": {"hungry": "You are hungry", "very_hungry": "You are very hungry", "starving": "You are starving",
			"wasting": "You are wasting away: eat, or die"},
	"need.warmth": {"cold": "You are cold", "very_cold": "You are very cold", "hypothermic": "You are freezing: get warm"},
	"need.wetness": {"soaked": "You are soaked through"},
}


func _on_stage(need: String, old_stage: String, new_stage: String) -> void:
	needs_changed.emit()
	if SurvivalNeeds.stage_severity(core, need, new_stage) > SurvivalNeeds.stage_severity(core, need, old_stage):
		var line := String((STAGE_LINES.get(need, {}) as Dictionary).get(new_stage, ""))
		if line != "":
			_notice(line)


func _notice(text: String) -> void:
	var it: Node = player.get("interactor") if player else null
	if it and it.has_method(&"notice"):
		it.call(&"notice", text, 3.0)
