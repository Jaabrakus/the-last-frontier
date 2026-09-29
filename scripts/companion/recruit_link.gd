class_name RecruitLink
extends Node
## Recruiting, the node side (RECRUIT; the rules are Recruit, scripts/companion/recruit.gd, and data/companion/recruit.json).
## A child of the Household. It keeps the recruiting state (the candidates about, who joined, who left; saved in the
## household part as "recruit"), brings parties in along the roads (RecruitBody walking in to the camp by the east path),
## keeps each candidate's own survival core on the player's clock (a hungry trapper eats what he is given), opens the talk
## screen (RecruitScreen) on E, and carries out what is agreed there: talk, food given from the household store, the share
## offered, a promise, the ask. A candidate who joins becomes a household worker (Household.adopt) with their own core,
## likes and terms; their body walks round to the gate and home first. Every recruited worker's morale is kept here
## (Recruit.morale_tick): low for days they warn and then leave, walking away by the road, as a dismissed worker does
## (Household.remove_worker -> on_removed).

const GROUP := &"recruit_link"
## Morale and the housing count are brought up to date this often (game minutes / real seconds).
const MORALE_STEP_MIN := 10.0
const HOUSING_EVERY_S := 3.0

var house: Household
var st := {}
## Candidate id -> their SpouseCore (their own core; the worker they become).
var units := {}
## Candidate id -> RecruitBody.
var bodies := {}
## Worker (SpouseCore) -> RecruitBody walking home after joining.
var homebound := {}
var screen: RecruitScreen
var last_lines: Array = []
var _last_min := -1.0
var _morale_acc := 0.0
var _places := -1
var _housing_t := 0.0
var _rng := RandomNumberGenerator.new()


static func find(tree: SceneTree) -> RecruitLink:
	return tree.get_first_node_in_group(GROUP) as RecruitLink if tree else null


func _ready() -> void:
	add_to_group(GROUP)
	_rng.randomize()


func main() -> SurvivalCore:
	return house.bridge.core if house != null and house.bridge != null else null


func now() -> float:
	var m := main()
	return m.state.minutes if m != null else 0.0


func has_level() -> bool:
	return house != null and is_instance_valid(house.player) and house.player.is_inside_tree()


func _ensure() -> void:
	if st.is_empty() and main() != null:
		st = Recruit.new_state(int(main().state.rng_seed) ^ 0x7EC0, now())


func _process(dt: float) -> void:
	if main() == null or house.sc == null:
		return
	_ensure()
	var n := now()
	var dm := n - _last_min if _last_min >= 0.0 else 0.0
	_last_min = n
	_housing_t -= dt
	tick(maxf(dm, 0.0))


## One step: arrivals and leavings, the candidates' cores on the clock, the workers' morale, the bodies.
func tick(dm: float) -> void:
	var m := main()
	var n := now()
	for ev: Dictionary in Recruit.tick(st, m, n):
		match String(ev.ev):
			"arrive":
				var road := ""
				var first := Recruit.by_id(st, String((ev.ids as Array)[0]))
				road = String(first.get("road", ""))
				var pt := String(ev.text)
				var line := pick(["recruit", "arrive"]).replace("{party}", pt.left(1).to_lower() + pt.substr(1)).replace("{road}", road)
				toast(line.left(1).to_upper() + line.substr(1))
			"leave":
				pass   # (the body turns for the road in _sync_bodies)
	for c: Dictionary in Recruit.present(st):
		var u := unit(c)
		if u != null and dm > 0.0:
			u.sync(m)
	if dm > 0.0:
		_morale_acc += dm
		if _morale_acc >= MORALE_STEP_MIN:
			_morale(_morale_acc)
			_morale_acc = 0.0
	_sync_bodies()
	Recruit.prune(st)
	for id: String in units.keys():
		if Recruit.by_id(st, id).is_empty():
			units.erase(id)
	for id: String in bodies.keys():
		if Recruit.by_id(st, id).is_empty():
			var b: Variant = bodies[id]
			if b is Node and is_instance_valid(b) and (b as RecruitBody).mode != "leave":
				(b as Node).queue_free()
			bodies.erase(id)


# ---------------------------------------------------------------- the candidates' cores
## A candidate's own worker and core (made from the record the first time; from its saved unit after a load).
func unit(c: Dictionary) -> SpouseCore:
	if c.is_empty():
		return null
	var id := String(c.id)
	if units.has(id):
		return units[id]
	var m := main()
	if m == null:
		return null
	var w: SpouseCore
	if c.get("unit") is Dictionary and not (c.unit as Dictionary).is_empty():
		w = SpouseCore.from_dict(c.unit, m)
		w.core.state.minutes = minf(w.core.state.minutes, m.state.minutes)
		if String(c.get("age", "adult")) == "teen" and w.body_look.is_empty():
			w.body_look = Recruit.teen_look(w.look, m.state.minutes)
	else:
		w = Recruit.build_worker(m, c)
	for k: Variant in c.get("stash", {}):
		w.stock.put(String(k), int(c.stash[k]))
	units[id] = w
	return w


# ---------------------------------------------------------------- housing and food
## Places to sleep near home (counted every few seconds).
func places() -> int:
	if _places < 0 or _housing_t <= 0.0:
		_places = Recruit.places_in(Recruit.pieces_near(get_tree(), house.home)) if has_level() else _places
		_places = maxi(_places, 0)
		_housing_t = HOUSING_EVERY_S
	return _places


func occupants() -> int:
	return Recruit.occupants(house.workers(), house.family)


func free_places() -> int:
	return places() - occupants()


func housed() -> bool:
	return free_places() >= 0


## The ask's context for a candidate: the places free, the store's days of food with the party fed too, trust, the share.
func ctx_for(c: Dictionary) -> Dictionary:
	var party := Recruit.joining(st, c)
	var people := house.crew().people() + party.size()
	return {"free": free_places(), "food_days": Recruit.food_days(house.stock.all(), house.sc.unit_kcal, people),
			"trust": Recruit.trust_of(main(), Recruit.leader(st, c)), "share": int(Recruit.leader(st, c).get("share", 0))}


func odds(c: Dictionary) -> Dictionary:
	var lead := Recruit.leader(st, c)
	return Recruit.odds(main(), lead, ctx_for(c), Recruit.joining(st, c), now())


func can_talk(id: String) -> bool:
	var c := Recruit.by_id(st, id)
	return not c.is_empty() and Recruit.PRESENT.has(String(c.state))


# ---------------------------------------------------------------- what the player does
func open(id: String) -> void:
	if screen != null or not can_talk(id) or get_tree().paused:
		return
	screen = RecruitScreen.open_for(self, id)
	screen.tree_exited.connect(func() -> void: screen = null)


## A line from lines.json recruit (with {name}).
func say(c: Dictionary, key: String) -> String:
	var t := pick(["recruit", key]).replace("{name}", String(c.get("name", "")))
	c["line"] = t
	return t


func greet(c: Dictionary) -> String:
	if bool(c.get("hungry", false)) and not bool(c.get("fed", false)):
		return say(c, "greet_need")
	return say(c, "greet")


func talk(c: Dictionary) -> String:
	return say(c, "talk" if Recruit.talk(c, now()) else "talk_again")


## A unit of food from the household store to them (the most filling ready-to-eat, else any food): it goes to their own
## store, and they eat when hungry.
func gift(c: Dictionary) -> String:
	var u := unit(c)
	var kind := _gift_kind()
	if kind == "" or u == null:
		return say(c, "gift_none")
	if house.stock.take(kind, 1) < 1:
		return say(c, "gift_none")
	u.stock.put(kind, 1)
	var r := Recruit.gift(c, now())
	u._eat_when_hungry()
	c["hungry"] = c.hungry and SurvivalNeeds.food_stage(u.core) in ["very_hungry", "starving", "wasting", "hungry"]
	return say(c, "gift_help" if r == "help" else "gift_cap" if r == "cap" else "gift")


func _gift_kind() -> String:
	var best := ""
	var bs := -INF
	for k: Variant in house.stock.all():
		var kind := String(k)
		var kcal := house.sc.unit_kcal(kind)
		if kcal <= 0.0:
			continue
		var it := house.sc.core.data.item(String(house.sc.items[kind].item))
		var s := kcal - (100000.0 if bool(it.get("needs_cooking", false)) else 0.0) - (10000.0 if it.has("raw_risk") else 0.0)
		if s > bs:
			bs = s
			best = kind
	return best


func set_share(c: Dictionary, rank: int) -> String:
	Recruit.leader(st, c)["share"] = clampi(rank, 0, Recruit.max_share())
	return say(c, "share")


func promise(c: Dictionary) -> String:
	Recruit.promise(c)
	return say(c, "promise")


## Asks them to join: {outcome, joined, ids, p, why, line}; on a yes the party joins. (`roll`: a fixed roll, look-checks.)
func ask(c: Dictionary, roll := -1.0) -> Dictionary:
	var r := Recruit.ask(main(), st, c, ctx_for(c), now(), roll)
	match String(r.outcome):
		"blocked":
			r["line"] = say(c, "blocked") if String(r.why).begins_with("A place") else "\"%s.\"" % String(r.why)
		"excellent", "success":
			r["line"] = say(c, "yes")
			join(r.ids)
		"partial":
			r["line"] = say(c, "partial")
		_:
			r["line"] = say(c, "no")
	return r


## The candidates `ids` join the household: their own cores become workers, with their likes, role and terms; what they
## carried goes into the store; their bodies walk home (or they are placed at home without a level).
func join(ids: Array) -> void:
	var names := []
	var couple_placed := {}
	var lead: Dictionary = Recruit.by_id(st, String(ids[0])) if not ids.is_empty() else {}
	if not lead.is_empty():
		lead = Recruit.leader(st, lead)
	for id: Variant in ids:
		var c := Recruit.by_id(st, String(id))
		var w := unit(c)
		if w == null:
			continue
		var place := 1
		if bool(c.get("couple", false)):
			place = 0 if couple_placed.has(String(c.party)) else 1
			couple_placed[String(c.party)] = true
		for k: Variant in w.stock.all():
			house.stock.put(String(k), w.stock.take(String(k), int(w.stock.count(String(k)))))
		w.recruit = Recruit.recruit_record(c, now(), place)
		# a party that joins together has the terms its first member agreed, and trusts you as far as they do
		var ld: Dictionary = lead if not lead.is_empty() and bool(c.get("together", false)) else c
		w.recruit["share"] = int(ld.get("share", c.share))
		w.recruit["trust"] = maxf(Recruit.trust_of(main(), c), Recruit.trust_of(main(), ld))
		w.core.state.minutes = main().state.minutes
		w.join(house.stock)
		var jobs := Recruit.job_prefs(c)
		house.stock.crew.set_jobs(w, jobs)
		w.role = Recruit.preferred_role(jobs)
		_watch(w)
		c["state"] = "joined"
		(st.joined as Array).append({"name": String(c.name), "kind": String(c.kind), "at": now(), "npc": String(c.get("npc", ""))})
		if String(c.get("npc", "")) != "":
			(st.joined_npcs as Array).append(String(c.npc))
		names.append(String(c.name))
		units.erase(String(c.id))
		var b: Variant = bodies.get(String(c.id))
		bodies.erase(String(c.id))
		if b is RecruitBody and is_instance_valid(b) and has_level():
			var rb := b as RecruitBody
			rb.rec_id = ""
			_clear_arrived(rb)
			homebound[w] = rb
			rb.speed = Recruit.num("arrivals", "walk_speed", 1.25)
			rb.walk(_route_home(rb.global_position), "walk")
			rb.arrived.connect(func(_x: RecruitBody) -> void: _arrive_home(w, rb))
		else:
			if b is Node and is_instance_valid(b):
				(b as Node).queue_free()
			_place_home(w, house.home + Vector3(_rng.randf_range(-2.0, 2.0), 0.0, _rng.randf_range(-2.0, 2.0)))
	if names.size() == 1:
		toast(pick(["recruit", "joined"]).replace("{name}", String(names[0])).replace("{names}", String(names[0])))
	elif names.size() > 1:
		toast("%s have joined the household." % " and ".join(names))


func _arrive_home(w: SpouseCore, rb: RecruitBody) -> void:
	homebound.erase(w)
	var at := rb.global_position if is_instance_valid(rb) else house.home
	if is_instance_valid(rb):
		rb.queue_free()
	if house.crew().workers.has(w):
		_place_home(w, at)


## The worker's Spouse body (a teen at the teen's proportions).
func _place_home(w: SpouseCore, at: Vector3) -> void:
	if not has_level():
		w.join(house.stock)
		return
	at.y = maxf(FrontierTerrain.height_at(at.x, at.z), at.y)
	var b := house.adopt(w, at)
	_shape(w, b)


func _shape(w: SpouseCore, b: Spouse) -> void:
	if b != null and String(w.recruit.get("age", "adult")) == "teen":
		var row := Growth.stage_row("teen")
		b.set_proportions(float(row.get("scale", 0.93)), float(row.get("head", 1.11)))


# ---------------------------------------------------------------- morale and leaving
func _morale(dm: float) -> void:
	var hs := housed()
	var n := now()
	for w: SpouseCore in house.workers().duplicate():
		if w.recruit.is_empty():
			continue
		for ev: Dictionary in Recruit.morale_tick(w, dm, hs, n):
			match String(ev.ev):
				"warn":
					var t := pick(["recruit", "warn", str(int(ev.days))]).replace("{name}", w.name)
					w._note(t)
					toast(t)
				"leave":
					leave_worker(w, "morale")
					break


## A recruited worker leaves (their morale; `reason` is kept): they walk away by the road.
func leave_worker(w: SpouseCore, reason := "morale") -> void:
	w.recruit["leaving"] = reason
	house.remove_worker(w)


## Household.remove_worker's hook (RECRUIT): before the body goes, a walker takes their place and walks off by the road;
## the departure is kept. `b` the Spouse body (null: none).
func on_removed(w: SpouseCore, b: Node3D) -> void:
	var reason := String(w.recruit.get("leaving", "dismissed"))
	(st.departures as Array).append({"name": w.name, "kind": String(w.recruit.get("kind", "")), "reason": reason, "at": now()})
	var npc := String(w.recruit.get("npc", ""))
	if npc != "":
		(st.joined_npcs as Array).erase(npc)   # the old hunter may come by again another day
	toast(pick(["recruit", "left" if reason == "morale" else "dismissed"]).replace("{name}", w.name))
	var at := Vector3.INF
	var rb: Variant = homebound.get(w)
	homebound.erase(w)
	if rb is RecruitBody and is_instance_valid(rb):
		at = (rb as RecruitBody).global_position
		(rb as RecruitBody).queue_free()
	elif b != null and is_instance_valid(b):
		at = b.global_position
	if at == Vector3.INF or not has_level():
		return
	var walker := RecruitBody.spawn(house.get_parent(), at, w.look, w.body_look, String(w.recruit.get("age", "adult")) == "teen")
	walker.link = self
	walker.person_name = w.name
	walker.speed = Recruit.num("arrivals", "walk_speed", 1.25)
	walker.walk(_route_out(at, _nearest_road(at)), "leave")
	walker.arrived.connect(func(x: RecruitBody) -> void: x.queue_free())


# ---------------------------------------------------------------- bodies and routes
func _v3(p: Variant) -> Vector3:
	var a: Array = p
	var x := float(a[0])
	var z := float(a[1])
	return Vector3(x, FrontierTerrain.height_at(x, z), z)


func _road(id: String) -> Array:
	for r: Dictionary in Recruit.sec("places").get("roads", []):
		if String(r.id) == id:
			var out := []
			for p: Variant in r.points:
				out.append(_v3(p))
			return out
	return []


func camp_spot(c: Dictionary) -> Vector3:
	var cp: Array = Recruit.sec("places").get("camp", [22.5, -3.0])
	var spread := float(Recruit.sec("places").get("camp_spread", 2.5))
	var h := absi(hash(String(c.get("id", ""))))
	var ang := float(h % 628) / 100.0
	var p := Vector3(float(cp[0]), 0.0, float(cp[1])) + Vector3(cos(ang), 0.0, sin(ang)) * spread * (0.5 + float((h >> 10) % 100) / 200.0)
	p.y = FrontierTerrain.height_at(p.x, p.z)
	return p


func _inside_fort(p: Vector3) -> bool:
	var fh := float(Recruit.sec("places").get("fort_half", 16.5))
	return absf(p.x) < fh and absf(p.z) < fh


## From the camp round to the gate and in, then home.
func _route_home(from: Vector3) -> Array:
	var out := []
	if not _inside_fort(from):
		for p: Variant in Recruit.sec("places").get("to_home", []):
			out.append(_v3(p))
		# start at the point of the way in nearest to where they stand
		var best := 0
		var bd := INF
		for i in out.size():
			var d := (out[i] as Vector3).distance_to(from)
			if d < bd:
				bd = d
				best = i
		out = out.slice(best)
	out.append(house.home + Vector3(_rng.randf_range(-1.5, 1.5), 0.0, _rng.randf_range(-1.5, 1.5)))
	return out


func _nearest_road(at: Vector3) -> String:
	var best := "east"
	var bd := INF
	for r: Dictionary in Recruit.sec("places").get("roads", []):
		var pts := _road(String(r.id))
		if pts.is_empty():
			continue
		var d := (pts.back() as Vector3).distance_to(at)
		if d < bd:
			bd = d
			best = String(r.id)
	return best


## Out by the gate when inside the fort, to the camp's end of the road, and along it the other way.
func _route_out(from: Vector3, road: String) -> Array:
	var out := []
	if _inside_fort(from):
		for p: Variant in Recruit.sec("places").get("gate_out", []):
			out.append(_v3(p))
	var pts := _road(road)
	pts.reverse()
	out.append_array(pts)
	return out


func _sync_bodies() -> void:
	if not has_level():
		# no world: arrivals are at the camp at once, leavers gone at once
		for c: Dictionary in st.candidates:
			if String(c.state) == "coming":
				c["state"] = "camped"
			elif String(c.state) == "leaving":
				c["state"] = "gone"
		return
	for c: Dictionary in st.candidates:
		var id := String(c.id)
		var b: Variant = bodies.get(id)
		var alive := b is RecruitBody and is_instance_valid(b)
		match String(c.state):
			"coming", "camped":
				if not alive:
					bodies[id] = _spawn_body(c)
			"leaving":
				if not alive:
					c["state"] = "gone"
				elif (b as RecruitBody).mode != "leave":
					_clear_arrived(b as RecruitBody)
					(b as RecruitBody).walk(_route_out((b as RecruitBody).global_position, String(c.road)), "leave")
					(b as RecruitBody).arrived.connect(func(x: RecruitBody) -> void:
						c["state"] = "gone"
						toast(pick(["recruit", "leave_road"]).replace("{name}", String(c.name)))
						x.queue_free())


func _spawn_body(c: Dictionary) -> RecruitBody:
	var u := unit(c)
	var at := camp_spot(c)
	var walking := String(c.state) == "coming"
	var road := _road(String(c.road))
	var from := 0
	if walking and not road.is_empty():
		# in from the road's far end (a few metres apart for a party)
		var i := int(String(c.id).get_slice("_", 1))
		at = (road[0] as Vector3) + Vector3(0.0, 0.0, 1.4 * i)
	if c.get("pos") is Array and (c.pos as Array).size() == 3:
		# a save put them part way: on from the road point nearest them
		at = Vector3(float(c.pos[0]), float(c.pos[1]), float(c.pos[2]))
		from = _nearest_index(road, at) if not road.is_empty() else 0
	var b := RecruitBody.spawn(house.get_parent(), at, u.look if u else c.look, u.body_look if u else {}, String(c.age) == "teen")
	b.link = self
	b.rec_id = String(c.id)
	b.person_name = String(c.name)
	b.desc = String(Recruit.kind_row(String(c.kind)).get("name", c.kind))
	b.speed = Recruit.num("arrivals", "walk_speed", 1.25)
	if walking:
		var pts := road.slice(from)
		pts.append(camp_spot(c))
		b.walk(pts, "walk")
		b.arrived.connect(func(x: RecruitBody) -> void:
			if String(c.state) == "coming":
				c["state"] = "camped"
			x.settle(camp_spot(c)))
	else:
		b.settle(camp_spot(c))
	return b


func _clear_arrived(rb: RecruitBody) -> void:
	for con: Dictionary in rb.arrived.get_connections():
		rb.arrived.disconnect(con.callable)


func _nearest_index(pts: Array, at: Vector3) -> int:
	var best := 0
	var bd := INF
	for i in pts.size():
		var d := (pts[i] as Vector3).distance_to(at)
		if d < bd:
			bd = d
			best = i
	return best


# ---------------------------------------------------------------- lines
func pick(path: Array) -> String:
	return house.pick(path) if house != null else ""


func toast(text: String) -> void:
	if text == "":
		return
	last_lines.append(text)
	if last_lines.size() > 20:
		last_lines.pop_front()
	if house != null and house.pregnancy != null:
		house.pregnancy.toast(text)
	else:
		print(text)


# ---------------------------------------------------------------- saving
## The recruiting state: the candidates (with their own cores and where their bodies stand), who joined, who left.
func save_data() -> Dictionary:
	_ensure()
	if st.is_empty():
		return {}
	for c: Dictionary in st.candidates:
		var u: Variant = units.get(String(c.id))
		if u is SpouseCore:
			c["stash"] = (u as SpouseCore).stock.all()
			c["unit"] = (u as SpouseCore).to_dict()
		var b: Variant = bodies.get(String(c.id))
		if b is RecruitBody and is_instance_valid(b):
			var p := (b as RecruitBody).global_position
			c["pos"] = [p.x, p.y, p.z]
	return st.duplicate(true)


## A save's recruiting (an old save has none: a new state). Visitors on their way out are gone.
func load_data(d: Variant) -> void:
	for b: Variant in bodies.values():
		if b is Node and is_instance_valid(b):
			(b as Node).queue_free()
	bodies.clear()
	units.clear()
	homebound.clear()
	var m := main()
	var seed_v := int(m.state.rng_seed) ^ 0x7EC0 if m != null else 1
	st = Recruit.normalize_state((d as Dictionary).duplicate(true) if d is Dictionary else d, seed_v, now())
	for c: Dictionary in st.candidates:
		if String(c.state) == "leaving":
			c["state"] = "gone"
	Recruit.prune(st)
	_last_min = -1.0
	_places = -1
	_after_load.call_deferred()


## After the household's bodies are made again: a recruited teen at the teen's proportions, every worker's pace.
func _after_load() -> void:
	for w: SpouseCore in house.workers():
		if not w.recruit.is_empty():
			w.work_mult = Recruit.work_mult(float(w.recruit.get("morale", 0.7)))
			_shape(w, house.body_of(w))
			_watch(w)


## After each job a worker in low spirits rests a while (recruit.json morale.rest_min x (1 - her pace)).
func _watch(w: SpouseCore) -> void:
	var fn := _on_worker_task.bind(w)
	if not w.task_finished.is_connected(fn):
		w.task_finished.connect(fn)


func _on_worker_task(_task: String, _text: String, w: SpouseCore) -> void:
	if not w.recruit.is_empty():
		w._cool = maxf(w._cool, Recruit.num("morale", "rest_min", 90.0) * maxf(1.0 - w.work_mult, 0.0))
