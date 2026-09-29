class_name HouseholdCrew
extends RefCounted
## The household's workers (user 2026-09-28: "we can make the wife do the full supply chain or part of it like a toggle,
## and then if we have more units in our camp we can make the supply chain longer or shorter"). The wife is worker 0; a
## worker is a SpouseCore with a `worker_id`. Each has her own core, role and set of jobs she does (`enabled`); the
## workers share one store (HouseholdStock, which also holds their reservations).
##
## The chain is as long as the jobs somebody does: who_does(job) says who, coverage(chain) which links nobody does.
## One worker can do every job; with more, each takes a part (set_enabled / set_chain).
##   Household.add_worker() / remove_worker() are the way in for the node; this class is the logic, headless.

var workers: Array = []
## FARM: how many beds round home the household keeps (the hoe job breaks ground up to it; the Tasks tab sets it). Saved.
var beds_wanted := FarmJob.BEDS_WANTED


func size() -> int:
	return workers.size()


## Everyone the store feeds: the player and the workers.
func people() -> int:
	return workers.size() + 1


func add(w: SpouseCore) -> void:
	if workers.has(w):
		return
	var taken := {}
	for o: SpouseCore in workers:
		taken[o.worker_id] = true
	if taken.has(w.worker_id):
		w.worker_id = 0
		while taken.has(w.worker_id):
			w.worker_id += 1
	workers.append(w)


func remove(w: SpouseCore) -> void:
	workers.erase(w)


func by_id(id: int) -> SpouseCore:
	for w: SpouseCore in workers:
		if w.worker_id == id:
			return w
	return null


## The workers who have `job` switched on.
func who_does(job: String) -> Array:
	var out := []
	for w: SpouseCore in workers:
		if bool(w.enabled.get(job, false)):
			out.append(w)
	return out


func any_enabled(job: String) -> bool:
	for w: SpouseCore in workers:
		if bool(w.enabled.get(job, false)):
			return true
	return false


## A job on or off for a worker; with `cascade`, off also switches off the jobs only it feeds (JobBook.cascade), and on
## switches on the jobs that feed it (their work is what it needs).
func set_enabled(w: SpouseCore, job: String, on: bool, cascade := false) -> void:
	if not JobBook.has(job):
		return
	var ids: Array = [job]
	if cascade:
		ids = JobBook.cascade(job) if not on else [job] + JobBook.upstream_all(job)
	for id: String in ids:
		w.enabled[id] = on
		if not on and w.task == id:
			w.cancel("told to stop")


## A whole chain on or off for a worker (`chain_id` is JobBook.chains()[i].id); off leaves the jobs another chain shares
## (the cook works the hunt's venison and the fields' crops).
func set_chain(w: SpouseCore, chain_id: String, on: bool) -> void:
	for c: Dictionary in JobBook.chains():
		if c.id == chain_id:
			for id: String in (c.jobs if on else JobBook.own_jobs(chain_id)):
				set_enabled(w, id, on)


## Gives a worker exactly these jobs.
func set_jobs(w: SpouseCore, jobs: Array) -> void:
	for id: String in JobBook.ids():
		set_enabled(w, id, jobs.has(id))


## The chain as the household works it: [{id, name, links: [{job, name, stage, where, workers: [names], covered}]}].
func chain_view() -> Array:
	var out := []
	for c: Dictionary in JobBook.chains():
		var links := []
		for id: String in c.jobs:
			var names := []
			for w: SpouseCore in who_does(id):
				names.append(w.name)
			links.append({"job": id, "name": JobBook.name_of(id), "stage": JobBook.stage_of(id), "where": JobBook.role_of(id),
					"workers": names, "covered": not names.is_empty()})
		out.append({"id": c.id, "name": c.name, "links": links})
	return out


## The jobs nobody does.
func uncovered() -> Array:
	var out := []
	for id: String in JobBook.ids():
		if not any_enabled(id):
			out.append(id)
	return out


# ---------------------------------------------------------------- saving
## {"workers": [worker dicts]}; `ats` (optional, one [x, y, z] per worker) is kept with each.
func to_dict(ats := []) -> Dictionary:
	var out := []
	for i in workers.size():
		var w: SpouseCore = workers[i]
		var e := {"unit": w.to_dict()}
		if i < ats.size():
			e["at"] = ats[i]
		out.append(e)
	return {"workers": out, "beds_wanted": beds_wanted}


## Builds the workers from a save: the new format, or the old one (a single "spouse": she becomes worker 0). The workers
## share `store` and join this crew. Returns the "at" positions found ([] entries where there were none).
func load_dict(d: Dictionary, main: SurvivalCore, store: HouseholdStock) -> Array:
	workers.clear()
	beds_wanted = int(d.get("beds_wanted", FarmJob.BEDS_WANTED))   # FARM: an older save keeps the default
	store.crew = self
	var ats := []
	var entries: Array = d.get("workers", [])
	if entries.is_empty() and d.has("spouse"):
		entries = [{"unit": d.spouse, "at": d.get("at", d.get("home", null))}]
	for e: Dictionary in entries:
		var w := SpouseCore.from_dict(e.get("unit", {}), main)
		if workers.is_empty():
			w.worker_id = 0
		w.join(store)
		ats.append(e.get("at", null))
	return ats
