class_name JobBook
extends RefCounted
## The household's jobs as data (data/companion/jobs.json) and the supply chain derived from them.
##
## A job takes pack kinds from the household store (inputs) and puts pack kinds back (outputs); a job whose input is another
## job's output is downstream of it (carcass > butcher > venison > cook / smoke / jerky; hides > tan; firewood > tend,
## woodpile). `aux` inputs (the fuel a job burns) do not make a link: they are not what the job is made from.
##   upstream(id) / downstream(id)             the jobs directly before / after it
##   upstream_all(id) / downstream_all(id)     everything before / after it
##   chain(id)                                 the whole chain it is in, in working order
##   chains()                                  every chain: [{id, name, jobs}]
##   cascade(id)                               the job and the jobs only it (transitively) feeds: what a chain toggle switches
## and the household's targets (what to hold: cooked meals per person, firewood, jerky ...), whose shortages pull the
## planner: shortages(counter, people), pull(id, shortages, active).
## Kinds in inputs and outputs may be groups ("@raw_food": any of the group; "@cooked": what the group roasts into;
## "@green_pelt" / "@dried": the pelts and what they dry into).

const PATH := "res://data/companion/jobs.json"
## How much of a downstream job's pull reaches the job that feeds it.
const PULL_DECAY := 0.7

static var _book := {}
static var _graph := {}
static var _groups := {}


## Loads another book (tests); reload() puts the shipped one back.
static func load_from(path: String) -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_book = _normalise(d as Dictionary) if d is Dictionary else _normalise({})
	_graph = {}
	_groups = {}


static func reload() -> void:
	load_from(PATH)


static func book() -> Dictionary:
	if _book.is_empty():
		reload()
	return _book


static func _normalise(d: Dictionary) -> Dictionary:
	var jobs := {}
	var order := []
	var i := 0
	for j: Dictionary in d.get("jobs", []):
		var job := j.duplicate(true)
		for k in ["inputs", "aux", "outputs", "keep", "how"]:
			if not job.has(k):
				job[k] = {}
		job["id"] = String(job.get("id", ""))
		job["name"] = String(job.get("name", job.id))
		job["stage"] = String(job.get("stage", "process"))
		job["where"] = String(job.get("where", "home"))
		job["needs"] = String(job.get("needs", "none"))
		job["priority"] = int(job.get("priority", 100 + i))
		job["demand"] = String(job.get("demand", "stock"))
		job["offer"] = String(job.get("offer", "variants"))
		job["tags"] = job.get("tags", [])
		job["tools"] = job.get("tools", {}) if job.get("tools") is Dictionary else {}   # TOOLS: what it borrows (ToolPool.needs_of)
		jobs[job.id] = job
		order.append(job.id)
		i += 1
	return {"jobs": jobs, "order": order, "stages": d.get("stages", []), "stage_names": d.get("stage_names", {}),
			"groups": d.get("groups", {}), "targets": d.get("targets", {}), "chain_names": d.get("chain_names", {})}


# ---------------------------------------------------------------- the list
static func ids() -> Array:
	return (book().order as Array).duplicate()


static func has(id: String) -> bool:
	return (book().jobs as Dictionary).has(id)


static func job(id: String) -> Dictionary:
	return (book().jobs as Dictionary).get(id, {})


static func name_of(id: String) -> String:
	return String(job(id).get("name", id))


static func role_of(id: String) -> String:
	return String(job(id).get("where", "home"))


static func stage_of(id: String) -> String:
	return String(job(id).get("stage", ""))


static func stage_name(stage: String) -> String:
	return String((book().stage_names as Dictionary).get(stage, stage.capitalize()))


static func stage_index(id: String) -> int:
	return maxi((book().stages as Array).find(stage_of(id)), 0)


static func names() -> Dictionary:
	var out := {}
	for id: String in ids():
		out[id] = name_of(id)
	return out


static func roles() -> Dictionary:
	var out := {}
	for id: String in ids():
		out[id] = role_of(id)
	return out


static func targets() -> Dictionary:
	return book().targets


## How many of `kind` the job keeps back in the store (the reserve rule: what she leaves for eating and the fires).
static func keep_of(id: String, kind: String) -> int:
	return int(job(id).keep.get(kind, 0))


# ---------------------------------------------------------------- kinds
## The pack kinds a token stands for: a kind is itself; "@name" a group.
static func expand(token: String, side := "in") -> Array:
	if not token.begins_with("@"):
		return [token]
	var name := token.substr(1)
	if name == "cooked":
		var out := []
		var seen := {}
		for k: String in group("raw_food"):
			for v: String in [String(CampCooking.COOKED.get(k, {}).get("cooked", "")), String(CampCooking.COOKED.get(k, {}).get("burnt", ""))]:
				if v != "" and not seen.has(v):
					seen[v] = true
					out.append(v)
		return out
	if name == "dried":
		var out := []
		for k: String in group("green_pelt"):
			out.append("dried_" + k)
		return out
	return group(name)


static func group(name: String) -> Array:
	if not _groups.has(name):
		_groups[name] = _group(name)
	return _groups[name]


static func _group(name: String) -> Array:
	var g: Variant = (book().groups as Dictionary).get(name, [])
	if g is Array:
		return g
	if g is Dictionary and String(g.get("from", "")) == "materials":
		var out := []
		var mats := SurvivalBridge.load_items("materials")
		var suffix := String(g.get("suffix", ""))
		var twin := String(g.get("twin_prefix", ""))
		for k: String in mats:
			if k.ends_with(suffix) and not k.begins_with(twin) and mats.has(twin + k):
				out.append(k)
		return out
	return []


static func inputs_of(id: String, aux := false) -> Array:
	return _kinds(job(id).get("aux" if aux else "inputs", {}), "in")


static func outputs_of(id: String) -> Array:
	return _kinds(job(id).outputs, "out")


static func _kinds(d: Dictionary, side: String) -> Array:
	var out := []
	for t: String in d:
		for k: String in expand(t, side):
			if not out.has(k):
				out.append(k)
	return out


# ---------------------------------------------------------------- the chain
static func _g() -> Dictionary:
	if not _graph.is_empty():
		return _graph
	var ids_: Array = ids()
	var up := {}
	var down := {}
	var aux_up := {}
	for id: String in ids_:
		up[id] = []
		down[id] = []
		aux_up[id] = []
	for a: String in ids_:
		var outs := outputs_of(a)
		for b: String in ids_:
			if a == b:
				continue
			if _shares(outs, inputs_of(b)):
				(up[b] as Array).append(a)
				(down[a] as Array).append(b)
			if _shares(outs, inputs_of(b, true)):
				(aux_up[b] as Array).append(a)
	# a link the pack kinds do not make: `feeds` (the hoe's worked beds are the sowing's ground, FARM)
	for a: String in ids_:
		for b: Variant in job(a).get("feeds", []):
			if up.has(String(b)) and not (up[String(b)] as Array).has(a):
				(up[String(b)] as Array).append(a)
				(down[a] as Array).append(String(b))
	_graph = {"up": up, "down": down, "aux_up": aux_up, "chains": _build_chains(up, down)}
	return _graph


static func _shares(a: Array, b: Array) -> bool:
	for k in a:
		if b.has(k):
			return true
	return false


## The jobs directly before `id` (their outputs are its inputs; aux: its fuel).
static func upstream(id: String, aux := false) -> Array:
	return ((_g().aux_up if aux else _g().up) as Dictionary).get(id, []).duplicate()


static func downstream(id: String) -> Array:
	return (_g().down as Dictionary).get(id, []).duplicate()


static func upstream_all(id: String) -> Array:
	return _reach(id, _g().up)


static func downstream_all(id: String) -> Array:
	return _reach(id, _g().down)


static func _reach(id: String, edges: Dictionary) -> Array:
	var seen := {}
	var todo := [id]
	while not todo.is_empty():
		var c: String = todo.pop_back()
		for n: String in edges.get(c, []):
			if not seen.has(n) and n != id:
				seen[n] = true
				todo.append(n)
	var out := []
	for k: String in ids():
		if seen.has(k):
			out.append(k)
	return out


## The supply chains: one for each source (a job nothing feeds), with every job it feeds after it, in working order. A job
## that feeds on two sources is in both chains (the cook: the hunt's venison and the fields' crops; user 2026-09-29: "hunt is
## a different supply chain and farming is a different supply chain"); a job no source reaches has a chain of its own.
static func _build_chains(up: Dictionary, down: Dictionary) -> Array:
	var cn: Dictionary = book().chain_names
	var out := []
	var placed := {}
	for id: String in ids():
		if not (up.get(id, []) as Array).is_empty():
			continue
		var members: Array = [id] + _reach(id, down)
		out.append({"id": id, "name": String(cn.get(id, "%s chain" % name_of(id))), "jobs": _in_order(members, up)})
		for m: String in members:
			placed[m] = true
	for id: String in ids():
		if not placed.has(id):
			out.append({"id": id, "name": String(cn.get(id, "%s chain" % name_of(id))), "jobs": [id]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return ids().find(a.id) < ids().find(b.id))
	return out


## `members` in working order: after what feeds them (within the set), then by stage, then priority.
static func _in_order(members: Array, up: Dictionary) -> Array:
	var depth := {}
	for m: String in members:
		depth[m] = 0
	for _pass in members.size():
		for m: String in members:
			for u: String in up.get(m, []):
				if depth.has(u):
					depth[m] = maxi(int(depth[m]), int(depth[u]) + 1)
	var sorted := members.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool:
		if depth[a] != depth[b]:
			return depth[a] < depth[b]
		if stage_index(a) != stage_index(b):
			return stage_index(a) < stage_index(b)
		return int(job(a).priority) < int(job(b).priority))
	return sorted


## The jobs of chain `chain_id` that no other chain has (switching the chain off leaves the shared ones: the cook).
static func own_jobs(chain_id: String) -> Array:
	var mine := []
	var others := {}
	for c: Dictionary in _g().chains:
		for j: String in c.jobs:
			if c.id == chain_id:
				mine.append(j)
			else:
				others[j] = true
	return mine.filter(func(j: String) -> bool: return not others.has(j))


static func chains() -> Array:
	return (_g().chains as Array).duplicate(true)


## The chain `id` is in, in working order (the source first).
static func chain(id: String) -> Array:
	for c: Dictionary in _g().chains:
		if (c.jobs as Array).has(id):
			return (c.jobs as Array).duplicate()
	return []


static func chain_of(id: String) -> Dictionary:
	for c: Dictionary in _g().chains:
		if (c.jobs as Array).has(id):
			return c.duplicate(true)
	return {}


## `id` and the jobs downstream of it that only it (through the others in the set) feeds: switching `id` off leaves them
## nothing to work from.
static func cascade(id: String) -> Array:
	var off := {id: true}
	var grew := true
	while grew:
		grew = false
		for d: String in downstream_all(id):
			if off.has(d) or bool(job(d).get("fed_from_outside", false)):   # HUNT: the butcher has the player's kills too
				continue
			var ups: Array = (_g().up as Dictionary).get(d, [])
			var only := not ups.is_empty()
			for u: String in ups:
				if not off.has(u):
					only = false
					break
			if only:
				off[d] = true
				grew = true
	var out := []
	for k: String in ids():
		if off.has(k):
			out.append(k)
	return out


# ---------------------------------------------------------------- targets and pull
## What the household is short of: {target id: {name, have, size, short, frac}} (only the shortfalls). `counter` is
## Callable(kind) -> units held; `people` is everyone the store feeds (the player, her, the other workers).
static func shortages(counter: Callable, people: int) -> Dictionary:
	var out := {}
	for tid: String in targets():
		var t: Dictionary = targets()[tid]
		var size := int(t.get("min", 0)) + int(t.get("per_person", 0)) * maxi(people, 1)
		if size <= 0:
			continue
		var have := 0
		for k: String in t.get("kinds", []):
			have += int(counter.call(k))
		if have < size:
			out[tid] = {"name": String(t.get("name", tid)), "have": have, "size": size, "short": size - have,
					"frac": float(size - have) / float(size)}
	return out


## How much the household's shortages want `id` run: what its outputs fill of them, and (through the chain) a share of
## what the jobs it feeds are wanted for. `active` is Callable(job id) -> bool (a job nobody does pulls nothing).
static func pull(id: String, short: Dictionary, active := Callable(), _seen := {}) -> float:
	if _seen.has(id):
		return 0.0
	var seen := _seen.duplicate()
	seen[id] = true
	var own := 0.0
	var outs := outputs_of(id)
	for tid: String in short:
		var kinds: Array = targets()[tid].get("kinds", [])
		if _shares(outs, kinds):
			own = maxf(own, float(short[tid].frac))
	var far := 0.0
	for d: String in downstream(id):
		if active.is_valid() and not bool(active.call(d)):
			continue
		far = maxf(far, pull(d, short, active, seen))
	return maxf(own, far * PULL_DECAY)
