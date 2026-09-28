class_name SurvivalStreams
extends RefCounted
## Named random streams (multiplayer_readiness.md refactor P0-2), used by every draw the v4 redesign added: cache
## pilferage, curing times and the like. Each stream is seeded from the world seed and its name (so it never depends on
## how many draws another system made) and saved in SurvivalState.world.streams, so a loaded game continues each stream
## exactly. World streams are named "w.<system>"; a player's are "p.<player id>.<system>".
##
## The v3 systems (weather, the trap line's dawn roll, skill checks, conditions) still draw from the one shared stream
## (SurvivalCore.rng) until P0-2 moves them: a single extra check still reshuffles the weather (check_mp_readiness.gd
## check 3). New code must not add draws to the shared stream.

## A 64-bit mixing constant for deriving stream seeds (the PCG multiplier) [D].
const MIX := 6364136223846793005


static func _saved(core: SurvivalCore) -> Dictionary:
	var w := core.state.world
	if not w.has("streams"):
		w["streams"] = {}
	return w.streams


## The named stream (created on first use from the world seed and the name).
static func rng(core: SurvivalCore, name: String) -> RandomNumberGenerator:
	if core._streams.has(name):
		return core._streams[name]
	var r := RandomNumberGenerator.new()
	var rec := SurvivalUtil.dict(_saved(core).get(name))
	if rec.is_empty():
		r.seed = seed_for(core.state.rng_seed, name)
	else:
		r.seed = str(rec.get("seed", "0")).to_int()
		r.state = str(rec.get("state", "0")).to_int()
	core._streams[name] = r
	return r


## A world stream ("w.caches") and a player stream ("p.pl.1.craft").
static func world(core: SurvivalCore, system: String) -> RandomNumberGenerator:
	return rng(core, "w." + system)


static func player(core: SurvivalCore, system: String, pid: String = "") -> RandomNumberGenerator:
	return rng(core, "p.%s.%s" % [pid if pid != "" else core.state.player_id, system])


## The stream's seed: the world seed mixed with the name's hash, never zero.
static func seed_for(world_seed: int, name: String) -> int:
	var h := hash(name)
	var s := (world_seed ^ (h * MIX)) & 0x7FFFFFFFFFFFFFFF
	return s if s != 0 else 0x5eed


## Write every stream in use back into the state (before saving or comparing). 64-bit values are kept as strings.
static func sync(core: SurvivalCore) -> void:
	var saved := _saved(core)
	for name in core._streams.keys():
		var r: RandomNumberGenerator = core._streams[name]
		saved[name] = {"seed": str(r.seed), "state": str(r.state)}
