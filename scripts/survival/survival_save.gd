class_name SurvivalSave
extends RefCounted
## Saving and loading the survival state (the GDD's SaveService, survival_gdd.md section 17).
##
## Versioned JSON in user://saves/<slot>/<name>.json: {meta, state}. meta says what the save is (date, background,
## preset, save and data-schema versions); state is SurvivalState.to_dict(), which holds every mutable value: needs,
## conditions, skills, inventory, camp records, the trap line and its cells' stock, weather, books and standing, the
## running job with its pre-rolled outcome, the random-number streams, and (save version 2) the world records (node
## stocks, obligations, the item ledger, caches, racks, builds, NPC stock) and the player's records (knowledge, learning,
## trust, habits, clothing wear), so a loaded game continues exactly as the saved one would have. Ids are stable
## strings. Three rotating autosaves (autosave_0..2) on sleep and quit; version 1 saves are migrated (_migrate).
##
## Exactness (fix round 1): Godot's JSON text round trip is not bit-exact for every float even with full precision (a
## probe found stats.food_stage_h off by one ulp), and a threshold on a computed float can then send a loaded game down
## another branch. So the document also carries the state as Godot's binary variant encoding, base64 (`state_bin`),
## which is bit-exact; loading prefers it. The readable `state` stays for reading and diffing; delete `state_bin` to
## load an edited `state`. A binary .res (save_resource) is exact too; a text .tres is for reading and diffing only.
## Open trade windows are cancelled before any save (their escrow returned), except a persistent-world save
## (keep_trades), which keeps the sessions and their escrow as they are.

const ROOT := "user://saves/"
const AUTOSAVES := 3
## The actions live in version 3 (save version 1). Version 3 had no knowledge gates, so a v3 character could do all of
## these: a migrated save knows every one that v4 gates (redesign_skills.md 12.6).
const V3_LIVE_ACTIONS := ["fire.gather", "fire.strike_flint_steel", "fire.nurse", "fire.tend", "fire.bank", "cook.roast",
		"eat", "drink.item", "shelter.brush_leanto", "shelter.bough_bed", "rest.sleep", "physick.bind_wound",
		"wood.split_firewood", "craft.stakes", "trap.deadfall_set", "trap.steel_land_set", "trap.check", "hunt.track",
		"butcher.field_dress", "fur.skin", "fur.stretch", "fur.dry", "trade.take_credit"]
const V3_LIVE_RECIPES := ["rcp.stake_set"]


static func slot_dir(slot: String) -> String:
	return ROOT + slot.validate_filename() + "/"


## The save document for a core: {meta, state, state_bin}. Open trade sessions are cancelled first (their escrow
## returned): a trade is committed by the authority or not at all (redesign_economy.md 6.8). opts.keep_trades (the
## persistent world's periodic saves): open sessions are saved with their escrow instead, so a save never breaks a
## player-to-player window. opts.exact (default true): add the bit-exact binary copy of the state.
static func to_document(core: SurvivalCore, opts: Dictionary = {}) -> Dictionary:
	if not bool(opts.get("keep_trades", false)):
		SurvivalTrade.cancel_all(core)
	var st := core.snapshot_state()
	var sd := st.to_dict()
	var doc := {"meta": {"save_version": SurvivalState.SAVE_VERSION, "data_schema": SurvivalData.SCHEMA_VERSION,
			"date": SurvivalClock.date_string(core), "time": SurvivalClock.time_string(core), "background": st.background_id,
			# Seconds with the fraction kept: two autosaves in the same second (sleep, then quit) still order correctly.
			"preset": st.preset, "saved_unix": Time.get_unix_time_from_system(),
			"backlog_milestones": SurvivalUtil.arr(st.settings.get("backlog_milestones", []))}, "state": sd}
	if bool(opts.get("exact", true)):
		doc["state_bin"] = Marshalls.raw_to_base64(var_to_bytes(sd))
	return doc


## Floats keep every bit (full_precision) and keys keep their order (no sort_keys). Godot's defaults (14 digits, sorted
## keys) drift the needs and the clock in their last bits, and the drift grows through later checks and rolls.
static func to_json(core: SurvivalCore, opts: Dictionary = {}) -> String:
	return JSON.stringify(to_document(core, opts), "\t", false, true)


## A core from a save document (or null when the document is not a survival save or needs a newer game).
static func from_document(doc: Dictionary, opts: Dictionary = {}) -> SurvivalCore:
	var meta := SurvivalUtil.dict(doc.get("meta"))
	var sd := SurvivalUtil.dict(doc.get("state"))
	if sd.is_empty():
		return null
	var ver := int(SurvivalUtil.num(meta.get("save_version", sd.get("version")), 1.0))
	if ver > SurvivalState.SAVE_VERSION:
		push_warning("survival save version %d is newer than this game (%d)" % [ver, SurvivalState.SAVE_VERSION])
		return null
	# The bit-exact binary copy wins when it is there and reads back as a state of the same version.
	var bin := str(doc.get("state_bin", ""))
	if bin != "":
		var dec = bytes_to_var(Marshalls.base64_to_raw(bin))
		if typeof(dec) == TYPE_DICTIONARY and int(SurvivalUtil.num(dec.get("version"), -1.0)) == ver:
			sd = dec
	var st := SurvivalState.from_dict(_migrate(sd, ver))
	var core := SurvivalCore.from_state(st, opts)
	if ver < 2:
		_after_migrate_1_to_2(core)
	return core


static func from_json(text: String, opts: Dictionary = {}) -> SurvivalCore:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return from_document(parsed, opts)


## Older save versions are upgraded here, one version at a time.
##   1 -> 2 (survival GDD v4): the world and player records of the redesign (world, players, player_id); the old
##   flags.knowledge list becomes known recipes and techniques; the skill split of the working roster
##   (redesign_skills.md 12.6): Trapping and Fishing = Survival; Provisions = the background's start + half of what
##   Survival grew since; Hide and Needle = the start + half of what Hunting grew; the perk becomes the background's
##   habit. The data the save was written against is the v3 roster, so the starts are v4's (backgrounds.json).
static func _migrate(sd: Dictionary, from_version: int) -> Dictionary:
	var d := sd.duplicate(true)
	if from_version < 2:
		d = _migrate_1_to_2(d)
	d["version"] = SurvivalState.SAVE_VERSION
	return d


static func _migrate_1_to_2(d: Dictionary) -> Dictionary:
	var pid := "pl.1"
	d["player_id"] = pid
	var world := SurvivalUtil.dict(d.get("world"))
	for k in ["ids", "nodes", "trade", "obligations", "caches", "racks", "builds", "streams"]:
		if not world.has(k):
			world[k] = {}
	world["clock_acc"] = 0.0
	d["world"] = world
	var flags := SurvivalUtil.dict(d.get("flags"))
	var knowledge := {}
	var data0 := SurvivalCore.load_data()
	if data0 != null and data0.is_ok():
		# The v4 head start of the background (known, seen, heard of), as a new v4 character of it would have.
		var bg0 := data0.background(str(d.get("background_id", "")))
		for pair in [["heard_of", "heard_of"], ["seen", "seen"], ["known", "known"]]:
			for kid in SurvivalUtil.arr(bg0.get(pair[0])):
				knowledge[str(kid)] = _krec(str(pair[1]), "background")
		# Everything v3 let a character do: v3 had no knowledge gates.
		for aid in V3_LIVE_ACTIONS:
			var a := data0.action(str(aid))
			if not a.is_empty() and SurvivalLearning.gates_action_row(data0, a):
				knowledge[data0.action_knowledge_id(str(aid))] = _krec("known", "save v1")
		for rid in V3_LIVE_RECIPES:
			if not data0.recipe(str(rid)).is_empty():
				knowledge[data0.recipe_knowledge_id(str(rid))] = _krec("known", "save v1")
	for kid in SurvivalUtil.arr(flags.get("knowledge")):
		knowledge[str(kid)] = _krec("known", "save v1")
	flags.erase("knowledge")
	var learning := {"pools": {}, "recently_taught": {}, "lessons_month": {}, "second_try": {},
			"first_success": SurvivalUtil.arr(flags.get("actions_done")).duplicate()}
	flags.erase("actions_done")
	d["flags"] = flags
	var skills := SurvivalUtil.dict(d.get("skills"))
	var bg_id := str(d.get("background_id", ""))
	var start := {}
	var habit := ""
	var data := SurvivalCore.load_data()
	if data != null and data.is_ok():
		start = SurvivalUtil.dict(data.background(bg_id).get("skills"))
		habit = str(data.background(bg_id).get("habit", ""))
	var surv := SurvivalUtil.num(skills.get("survival"), 0.0)
	var hunt := SurvivalUtil.num(skills.get("hunting"), 0.0)
	var v3_surv := {"bg.backcountry_hunter": 32.0, "bg.provincial_ranger": 25.0}
	var v3_hunt := {"bg.backcountry_hunter": 30.0, "bg.provincial_ranger": 20.0}
	if not skills.has("trapping"):
		skills["trapping"] = surv
	if not skills.has("provisions"):
		skills["provisions"] = SurvivalUtil.num(start.get("provisions"), 0.0) + maxf(0.0, surv - SurvivalUtil.num(v3_surv.get(bg_id), surv)) / 2.0
	if not skills.has("hidecraft"):
		skills["hidecraft"] = SurvivalUtil.num(start.get("hidecraft"), 0.0) + maxf(0.0, hunt - SurvivalUtil.num(v3_hunt.get(bg_id), hunt)) / 2.0
	d["skills"] = skills
	# Stack uids (multiplayer_readiness.md P0-4): v3 stacks had none; trade lines and ammunition name stacks by uid.
	var ids := SurvivalUtil.dict(world.get("ids"))
	var nst := int(SurvivalUtil.num(ids.get("st"), 1.0))
	for st in SurvivalUtil.arr(d.get("inventory")):
		if typeof(st) == TYPE_DICTIONARY and str(st.get("uid", "")) == "":
			st["uid"] = "st.%d" % nst
			nst += 1
	ids["st"] = nst
	world["ids"] = ids
	var players := SurvivalUtil.dict(d.get("players"))
	if not players.has(pid):
		players[pid] = {"id": pid, "knowledge": knowledge, "learning": learning, "trust": {}, "habits": [habit] if habit != "" else [],
				"counters": {}, "wear": {}}
	d["players"] = players
	d["data_schema"] = SurvivalData.SCHEMA_VERSION
	return d


static func _krec(state: String, how: String) -> Dictionary:
	return {"state": state, "successes": 0, "excellent_good": 0, "clues": 0, "seen_from": [], "taught_by": [], "how": how}


## After a version-1 save is loaded: every open book becomes a credit obligation on the ledger (sync_credit), as a new
## game's start variant makes one.
static func _after_migrate_1_to_2(core: SurvivalCore) -> void:
	for cred in SurvivalUtil.sorted_ids(SurvivalUtil.dict(core.state.economy.get("accounts"))):
		var a := SurvivalEconomy.account(core, str(cred))
		SurvivalTrade.sync_credit(core, str(cred), SurvivalUtil.num(a.get("balance_d"), 0.0), str(a.get("due_event", "event.spring_trade")))


## Write user://saves/<slot>/<name>.json. Returns OK or an Error.
static func save(core: SurvivalCore, slot: String = "default", name: String = "manual") -> Error:
	var dir := slot_dir(slot)
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK and not DirAccess.dir_exists_absolute(dir):
		return err
	var path := dir + name.validate_filename() + ".json"
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(to_json(core))
	f.close()
	# Replace the old file only once the new one is fully written.
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path)


static func load_file(path: String, opts: Dictionary = {}) -> SurvivalCore:
	if not FileAccess.file_exists(path):
		return null
	return from_json(FileAccess.get_file_as_string(path), opts)


static func load_slot(slot: String = "default", name: String = "manual", opts: Dictionary = {}) -> SurvivalCore:
	return load_file(slot_dir(slot) + name.validate_filename() + ".json", opts)


## The next of three rotating autosaves (autosave_0, _1, _2). Returns the name written, or "" on failure.
static func autosave(core: SurvivalCore, slot: String = "default") -> String:
	var i := int(SurvivalUtil.num(core.state.flags.get("autosave_next"), 0.0)) % AUTOSAVES
	core.state.flags["autosave_next"] = (i + 1) % AUTOSAVES
	var name := "autosave_%d" % i
	return name if save(core, slot, name) == OK else ""


## The newest autosave in a slot, or null.
static func load_latest_autosave(slot: String = "default", opts: Dictionary = {}) -> SurvivalCore:
	var best := {}
	var best_t := -1.0
	for i in AUTOSAVES:
		var p := slot_dir(slot) + "autosave_%d.json" % i
		if not FileAccess.file_exists(p):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var t := SurvivalUtil.num(SurvivalUtil.dict(parsed.get("meta")).get("saved_unix"), float(FileAccess.get_modified_time(p)))
		if t > best_t:
			best_t = t
			best = parsed
	return from_document(best, opts) if not best.is_empty() else null


## Save slots and what each holds: [{slot, name, path, date, background}].
static func list_saves() -> Array:
	var out := []
	var root := DirAccess.open(ROOT)
	if root == null:
		return out
	for slot in root.get_directories():
		var d := DirAccess.open(ROOT + slot)
		if d == null:
			continue
		for fn in d.get_files():
			if not fn.ends_with(".json"):
				continue
			var p := ROOT + slot + "/" + fn
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
			var meta := SurvivalUtil.dict(SurvivalUtil.dict(parsed).get("meta")) if typeof(parsed) == TYPE_DICTIONARY else {}
			out.append({"slot": slot, "name": fn.get_basename(), "path": p, "date": str(meta.get("date", "")),
					"background": str(meta.get("background", ""))})
	return out


## The SurvivalState as a Godot resource (.tres or .res). Open trade windows are cancelled first, as for the JSON.
static func save_resource(core: SurvivalCore, path: String) -> Error:
	SurvivalTrade.cancel_all(core)
	return ResourceSaver.save(core.snapshot_state().duplicate_state(), path)


static func load_resource(path: String, opts: Dictionary = {}) -> SurvivalCore:
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not res is SurvivalState:
		return null
	return SurvivalCore.from_state((res as SurvivalState).duplicate_state(), opts)
