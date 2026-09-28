class_name SurvivalState
extends Resource
## Every piece of mutable survival state, in one saveable resource.
##
## The survival modules (clock, weather, needs, conditions, skills, inventory, camp, trap line, jobs, economy, trade,
## learning, nodes) are stateless function libraries that read and write this resource, so saving is just this object:
## as a .tres through ResourceSaver, or as versioned JSON through to_dict()/from_dict() (SurvivalSave). Ids are stable
## strings from the data files; nothing here holds a node, a path or an object reference.
##
## Save version 2 (survival GDD v4) follows the multiplayer split for every record the redesign adds
## (multiplayer_readiness.md P0-3): WORLD records (node stocks, trade sessions and the item ledger, obligations, caches,
## drying racks, staged builds, NPC stock and want quotas, named random streams) live in `world`; PER-PLAYER records
## (knowledge, learning, trust, habits and their counters, clothing wear) live in `players[player_id]`. The older fields
## (needs, conditions, skills, inventory, camp, trap line, economy) are still the local player's and the shared world's
## in one place, as in version 1, until P0-3 moves them into the same split.

const SAVE_VERSION := 2

@export var version: int = SAVE_VERSION
@export var data_schema: int = 4
@export var background_id: String = ""
@export var preset: String = "woodsman"
## Player-facing options: thirst_enabled, service_setting ("historical" | "open"), militia_role ("men" | "women"),
## service_variant, difficulty presets. Read with SurvivalCore.setting().
@export var settings: Dictionary = {}
@export var rng_seed: int = 0
@export var rng_state: int = 0
@export var base_year: int = 1765
## Game minutes since 00:00 on Early January of base_year (the calendar has 36 game days a year).
@export var minutes: float = 0.0

## Need meters: stomach, reserve (game kcal), warmth 0-100, wetness 0-1, fatigue 0-100, hydration 0-100,
## drunk 0-100 (the cond.drunk meter), drunk_peak, health 0-100.
@export var needs: Dictionary = {}
## Last computed stage per need id (need.food -> "hungry").
@export var need_stages: Dictionary = {}
@export var activity: String = "rest"
@export var asleep: bool = false
## cond id -> {stage, t_h, zone, heal_h, dur_h, bound, heal_mult, ...}
@export var conditions: Dictionary = {}
## Short-lived flags: powder_wet, powder_dry_min, groggy_until, feet_wet, last_trap_work_day, ...
@export var flags: Dictionary = {}
## skill id -> level (float 0-100)
@export var skills: Dictionary = {}
## {day, uses: {action: n}, xp: {skill: points}}
@export var skill_log: Dictionary = {}
## Inventory stacks: [{id, qty, meta}]
@export var inventory: Array = []
## Worn clothing item ids (they stay in the inventory and count toward load).
@export var worn: Array = []
## Logical camp objects the world will mirror: {fires: {id: {...}}, shelters: {...}, beds: {...}, carcasses: {...}, next_id}
@export var camp: Dictionary = {}
## Trap line: {traps: {id: {...}}, stock: [cell dicts], signs: {cell: {species: day}}, gunfire: {cell: day}, next_id}
@export var trapline: Dictionary = {}
## Weather: {state, hours_to_tick, noise_c, wind_ms, wind_dir_deg, snow_depth_cm, snowed_tonight, ...}
@export var weather: Dictionary = {}
## Economy: {money_d, accounts, stock, standing, logs, sales, contract, obligations, ...}
@export var economy: Dictionary = {}
## Jobs: {current: {...} or {}, progress: {key: minutes}}
@export var jobs: Dictionary = {}
## Food eaten per game day by group for plain fare: [{day, grain, meat, other}]
@export var diet_log: Array = []
## Resource node instances harvested: {node_instance_id: abs_day}
@export var nodes_used: Dictionary = {}
## Role states for NPC schedules (npc id -> "sick" | "away_hunting" | ...)
@export var npc_states: Dictionary = {}
## Where the player is and what is around them (set by the game each frame or by the sim harness).
@export var context: Dictionary = {}
## Telemetry counters for playtests and the sim harness (survival_gdd.md section 18).
@export var stats: Dictionary = {}
## Recent journal lines [{t, kind, text}] (capped).
@export var journal: Array = []
## The local player's id ("pl.1"): the key into players and the party id in trades.
@export var player_id: String = "pl.1"
## World records added by the v4 redesign: {ids, nodes, trade, obligations, caches, racks, builds, npc_stock, wants,
## streams, clock_acc}.
@export var world: Dictionary = {}
## Per-player records added by the v4 redesign: {pl.1: {id, knowledge, learning, trust, habits, counters, wear}}.
@export var players: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"version": version,
		"data_schema": data_schema,
		"background_id": background_id,
		"preset": preset,
		"settings": settings.duplicate(true),
		# 64-bit integers do not survive JSON doubles: keep them as strings.
		"rng_seed": str(rng_seed),
		"rng_state": str(rng_state),
		"base_year": base_year,
		"minutes": minutes,
		"needs": needs.duplicate(true),
		"need_stages": need_stages.duplicate(true),
		"activity": activity,
		"asleep": asleep,
		"conditions": conditions.duplicate(true),
		"flags": flags.duplicate(true),
		"skills": skills.duplicate(true),
		"skill_log": skill_log.duplicate(true),
		"inventory": inventory.duplicate(true),
		"worn": worn.duplicate(true),
		"camp": camp.duplicate(true),
		"trapline": trapline.duplicate(true),
		"weather": weather.duplicate(true),
		"economy": economy.duplicate(true),
		"jobs": jobs.duplicate(true),
		"diet_log": diet_log.duplicate(true),
		"nodes_used": nodes_used.duplicate(true),
		"npc_states": npc_states.duplicate(true),
		"context": context.duplicate(true),
		"stats": stats.duplicate(true),
		"journal": journal.duplicate(true),
		"player_id": player_id,
		"world": world.duplicate(true),
		"players": players.duplicate(true),
	}


static func from_dict(d: Dictionary) -> SurvivalState:
	var st := SurvivalState.new()
	st.version = int(SurvivalUtil.num(d.get("version"), SAVE_VERSION))
	st.data_schema = int(SurvivalUtil.num(d.get("data_schema"), 4))
	st.background_id = str(d.get("background_id", ""))
	st.preset = str(d.get("preset", "woodsman"))
	st.settings = SurvivalUtil.dict(d.get("settings")).duplicate(true)
	st.rng_seed = str(d.get("rng_seed", "0")).to_int()
	st.rng_state = str(d.get("rng_state", "0")).to_int()
	st.base_year = int(SurvivalUtil.num(d.get("base_year"), 1765))
	st.minutes = SurvivalUtil.num(d.get("minutes"), 0.0)
	st.needs = SurvivalUtil.dict(d.get("needs")).duplicate(true)
	st.need_stages = SurvivalUtil.dict(d.get("need_stages")).duplicate(true)
	st.activity = str(d.get("activity", "rest"))
	st.asleep = bool(d.get("asleep", false))
	st.conditions = SurvivalUtil.dict(d.get("conditions")).duplicate(true)
	st.flags = SurvivalUtil.dict(d.get("flags")).duplicate(true)
	st.skills = SurvivalUtil.dict(d.get("skills")).duplicate(true)
	st.skill_log = SurvivalUtil.dict(d.get("skill_log")).duplicate(true)
	st.inventory = SurvivalUtil.arr(d.get("inventory")).duplicate(true)
	st.worn = SurvivalUtil.arr(d.get("worn")).duplicate(true)
	st.camp = SurvivalUtil.dict(d.get("camp")).duplicate(true)
	st.trapline = SurvivalUtil.dict(d.get("trapline")).duplicate(true)
	st.weather = SurvivalUtil.dict(d.get("weather")).duplicate(true)
	st.economy = SurvivalUtil.dict(d.get("economy")).duplicate(true)
	st.jobs = SurvivalUtil.dict(d.get("jobs")).duplicate(true)
	st.diet_log = SurvivalUtil.arr(d.get("diet_log")).duplicate(true)
	st.nodes_used = SurvivalUtil.dict(d.get("nodes_used")).duplicate(true)
	st.npc_states = SurvivalUtil.dict(d.get("npc_states")).duplicate(true)
	st.context = SurvivalUtil.dict(d.get("context")).duplicate(true)
	st.stats = SurvivalUtil.dict(d.get("stats")).duplicate(true)
	st.journal = SurvivalUtil.arr(d.get("journal")).duplicate(true)
	st.player_id = str(d.get("player_id", "pl.1"))
	st.world = SurvivalUtil.dict(d.get("world")).duplicate(true)
	st.players = SurvivalUtil.dict(d.get("players")).duplicate(true)
	return st


func duplicate_state() -> SurvivalState:
	return SurvivalState.from_dict(to_dict())
