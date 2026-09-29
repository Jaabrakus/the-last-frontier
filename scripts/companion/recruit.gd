class_name Recruit
extends RefCounted
## Recruiting, logic only (user 2026-09-29: "start a family and/or village": a way to gain a villager besides raising a child).
## The rules are data/companion/recruit.json; RecruitLink (recruit_link.gd) is the node side (arrivals walking in, their
## bodies, the talk screen, the morale of the workers who joined), RecruitScreen the talk screen, RecruitBody a visitor's body.
##
## CANDIDATES come in PARTIES (recruit.json parties): travellers and settlers who walk in along a road now and then, camp by
## the fort a few days and go on if nobody takes them in; people in need among them; and RESIDENTS of the slice's cast (the
## farm family's son, the old hunter), who come by once the player's trust with them (SurvivalTrade.trust) is high. A
## candidate is a record (a Dictionary, saved as it is): a generated person (make_person: a look from the region's peoples,
## sex, age stage, name, a background's skills with the kind's changes, traits, likes, wants) and where they are with the
## player (trust, the share offered, a promise given, fed, cooldowns). Their own survival core is built from the record
## (build_worker) and becomes the worker when they join.
##
## ASKING (odds / ask): a Trade check through the survival skill model (SurvivalSkills.chance) with modifiers for trust,
## the wants met or not, the share, standing and traits; a hard want (a place to sleep for the whole party) blocks the ask
## with its reason. HOUSING (places_in / occupants): beds and roofed cabin bays against the people who need a place.
## MORALE (morale_tick): a joined worker's morale moves toward fed + housed + rested + trust; it sets her work speed and,
## low for days, makes her warn and then leave.
## All times are game minutes; everything here is deterministic for a seed (tests/companion/test_recruit.gd).

const PATH := "res://data/companion/recruit.json"
const BACKGROUNDS_PATH := "res://data/survival/backgrounds.json"
const MIN_PER_DAY := 1440.0
## The states of a candidate: on the road in, at the camp, on the road out; joined and gone are dropped from the list.
const PRESENT := ["coming", "camped"]

static var _cfg := {}
static var _bg_skills := {}


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_cfg = d if d is Dictionary else {}
	return _cfg


## Tests: replace the configuration (an empty dictionary reloads the file).
static func set_cfg(d: Dictionary) -> void:
	_cfg = d


static func sec(key: String) -> Dictionary:
	var v: Variant = cfg().get(key, {})
	return v if v is Dictionary else {}


static func num(section: String, key: String, dflt := 0.0) -> float:
	return float(sec(section).get(key, dflt))


static func kind_row(kind: String) -> Dictionary:
	var v: Variant = sec("kinds").get(kind, {})
	return v if v is Dictionary else {}


static func party_row(id: String) -> Dictionary:
	for p: Dictionary in cfg().get("parties", []):
		if String(p.get("id", "")) == id:
			return p
	return {}


static func share_name(rank: int) -> String:
	for s: Dictionary in cfg().get("shares", []):
		if int(s.get("rank", -1)) == rank:
			return String(s.get("name", ""))
	return "Rank %d" % rank


static func max_share() -> int:
	var m := 0
	for s: Dictionary in cfg().get("shares", []):
		m = maxi(m, int(s.get("rank", 0)))
	return m


## A background's starting skills (backgrounds.json), without a core.
static func background_skills(bg: String) -> Dictionary:
	if _bg_skills.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(BACKGROUNDS_PATH)) if FileAccess.file_exists(BACKGROUNDS_PATH) else null
		if d is Dictionary:
			for b: Dictionary in (d as Dictionary).get("backgrounds", []):
				_bg_skills[String(b.get("id", ""))] = (b.get("skills", {}) as Dictionary).duplicate()
	return (_bg_skills.get(bg, {}) as Dictionary)


static func pick_weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var keys := weights.keys()
	keys.sort()
	var total := 0.0
	for k: Variant in keys:
		total += maxf(float(weights[k]), 0.0)
	var r := rng.randf() * total
	for k: Variant in keys:
		r -= maxf(float(weights[k]), 0.0)
		if r <= 0.0:
			return String(k)
	return String(keys.back()) if not keys.is_empty() else ""


static func _rng(seed_v: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r


# ---------------------------------------------------------------- the state
## A new game's recruiting: no one yet; the first party comes `first_after_days` from now.
static func new_state(seed_v: int, now: float) -> Dictionary:
	return {"seed": seed_v, "seq": 0, "next_at": now + num("arrivals", "first_after_days", 0.5) * MIN_PER_DAY,
			"candidates": [], "departures": [], "joined": [], "joined_npcs": []}


## A saved state made whole (a save from before recruiting has none: a new one), IN PLACE when it is a dictionary.
static func normalize_state(d: Variant, seed_v: int, now: float) -> Dictionary:
	if not (d is Dictionary) or (d as Dictionary).is_empty():
		return new_state(seed_v, now)
	var s: Dictionary = d
	var fresh := new_state(seed_v, now)
	for k: String in fresh:
		var num_ok: bool = s.has(k) and (s[k] is float or s[k] is int) and (fresh[k] is float or fresh[k] is int)
		if not s.has(k) or (typeof(s[k]) != typeof(fresh[k]) and not num_ok):
			s[k] = fresh[k]
	s["seq"] = int(s.seq)
	s["seed"] = int(s.seed)
	var keep := []
	for c: Variant in s.candidates:
		if c is Dictionary and String((c as Dictionary).get("id", "")) != "":
			keep.append(normalize_candidate(c))
	s["candidates"] = keep
	return s


## A candidate record's defaults (fields an older record lacks).
static func normalize_candidate(c: Dictionary) -> Dictionary:
	var defaults := {"party": "", "party_kind": "", "kind": "hand", "npc": "", "name": "Stranger", "sex": 1.0, "age": "adult",
			"people": "", "look": {}, "seed": 1, "background": "bg.provincial_ranger", "skills": {}, "traits": [], "likes": [],
			"wants": [], "trust": 0.0, "difficulty": 25.0, "state": "camped", "road": "east", "arrived_at": 0.0, "leave_at": 0.0,
			"share": 0, "promised": false, "fed": false, "talk_day": -1, "gift_day": -1, "gift_n": 0, "cd_until": 0.0,
			"couple": false, "together": false, "hungry": false, "stash": {}, "line": ""}
	for k: String in defaults:
		var num_ok: bool = c.has(k) and (c[k] is float or c[k] is int) and (defaults[k] is float or defaults[k] is int)
		if not c.has(k) or (typeof(c[k]) != typeof(defaults[k]) and not num_ok):
			c[k] = defaults[k] if not (defaults[k] is Dictionary or defaults[k] is Array) else defaults[k].duplicate()
	for k: String in ["share", "talk_day", "gift_day", "gift_n", "seed"]:
		c[k] = int(c[k])
	return c


static func by_id(st: Dictionary, id: String) -> Dictionary:
	for c: Dictionary in st.get("candidates", []):
		if String(c.id) == id:
			return c
	return {}


## The candidates about now (on the road in or at the camp).
static func present(st: Dictionary) -> Array:
	return (st.get("candidates", []) as Array).filter(func(c: Dictionary) -> bool: return PRESENT.has(String(c.state)))


## The members of a candidate's party still about (the candidate first when `lead_first` is false: in party order).
static func party_of(st: Dictionary, rec: Dictionary) -> Array:
	var out := []
	for c: Dictionary in st.get("candidates", []):
		if String(c.party) == String(rec.party) and PRESENT.has(String(c.state)):
			out.append(c)
	return out


## Who answers for a party that joins together: its first member about (the widow for her child, the husband's party ...).
static func leader(st: Dictionary, rec: Dictionary) -> Dictionary:
	if not bool(rec.get("together", false)):
		return rec
	var p := party_of(st, rec)
	return p[0] if not p.is_empty() else rec


## The people who would join if `rec` says yes: the whole party when it joins together, or the one.
static func joining(st: Dictionary, rec: Dictionary) -> Array:
	return party_of(st, rec) if bool(rec.get("together", false)) else [rec]


# ---------------------------------------------------------------- a person
## A generated person of `kind` (recruit.json kinds), deterministic for `seed_v`. opts: {sex: "m" | "f"}.
static func make_person(kind: String, seed_v: int, opts := {}) -> Dictionary:
	var row := kind_row(kind)
	var rng := _rng(seed_v)
	var sx_rule := String(opts.get("sex", row.get("sex", "any")))
	var sex := 1.0 if sx_rule == "m" else 0.0 if sx_rule == "f" else float(rng.randi() % 2)
	var people := String(row.get("people", ""))
	if people == "":
		var w: Variant = row.get("peoples", cfg().get("region_peoples", {}))
		people = pick_weighted(rng, w if w is Dictionary else {"english": 1.0})
	var look := CharacterPeoples.random_look(people, sex, rng)
	if look.is_empty():
		look = SpouseCore.look_for(sex, "", rng.randi())
	look["weathering"] = snappedf(rng.randf_range(0.15, 0.45), 0.01)
	var name := String(row.get("fixed_name", ""))
	if name == "":
		var pools: Dictionary = sec("names")
		var pool: Dictionary = pools.get(people, pools.get("english", {}))
		var list: Array = pool.get("m" if sex >= 0.5 else "f", [])
		name = String(list[rng.randi() % list.size()]) if not list.is_empty() else ("John" if sex >= 0.5 else "Mary")
	var age := String(row.get("age", "adult"))
	# skills: the background's, scaled (a teen has half a life of learning), the kind's changes, a little of their own
	var bg := String(row.get("background", "bg.provincial_ranger"))
	var base := background_skills(bg)
	var skills := {}
	var scale := float(row.get("skills_scale", 1.0))
	var cap := float(Growth.junior_rules().get("skill_cap", 35.0)) if age == "teen" else 80.0
	var adds: Dictionary = row.get("skills", {})
	var keys := base.keys()
	for k: Variant in adds:
		if not keys.has(k):
			keys.append(k)
	keys.sort()
	for k: Variant in keys:
		var v := float(base.get(k, 0.0)) * scale + float(adds.get(k, 0.0)) + rng.randf_range(-4.0, 4.0)
		skills[String(k)] = snappedf(clampf(v, 0.0, cap), 0.1)
	# two traits of the kind's
	var pool_t: Array = (row.get("traits", []) as Array).duplicate()
	var traits := []
	for i in 2:
		if pool_t.is_empty():
			break
		var t: String = pool_t[rng.randi() % pool_t.size()]
		pool_t.erase(t)
		traits.append(t)
	var likes: Array = (row.get("likes", []) as Array).duplicate()
	for t: String in traits:
		for j: Variant in (sec("traits").get(t, {}) as Dictionary).get("likes", []):
			if not likes.has(j):
				likes.append(j)
	# the wants, their numbers drawn
	var wants := []
	var share_add := 0
	for t: String in traits:
		share_add += int((sec("traits").get(t, {}) as Dictionary).get("share_add", 0))
	for w0: Dictionary in row.get("wants", []):
		var w := w0.duplicate(true)
		if w.get("days") is Array:
			w["days"] = rng.randi_range(int(w.days[0]), int(w.days[1]))
		if String(w.kind) == "share":
			w["rank"] = clampi(int(w.get("rank", 0)) + share_add, 0, max_share())
		wants.append(w)
	var stories: Array = row.get("story", [])
	return {"kind": kind, "name": name, "sex": sex, "age": age, "people": people, "look": look, "seed": seed_v,
			"background": bg, "skills": skills, "traits": traits, "likes": likes, "wants": wants,
			"trust": float(row.get("trust_start", 1.0)), "difficulty": float(row.get("difficulty", 25.0)),
			"hungry": bool(row.get("hungry", false)), "stash": (row.get("stash", {}) as Dictionary).duplicate(),
			"story": String(stories[rng.randi() % stories.size()]) if not stories.is_empty() else "",
			"share": 0, "promised": false, "fed": false, "talk_day": -1, "gift_day": -1, "gift_n": 0, "cd_until": 0.0, "line": ""}


# ---------------------------------------------------------------- arrivals
## The party templates that may come now: a resident only while the player's trust with that NPC is at its
## `appear_trust`, it has not joined and it is not already about.
static func eligible(st: Dictionary, main: SurvivalCore) -> Array:
	var out := []
	for p: Dictionary in cfg().get("parties", []):
		var npc := String(p.get("resident", ""))
		if npc != "":
			if (st.joined_npcs as Array).has(npc) or main == null:
				continue
			if SurvivalTrade.trust(main, npc) < float(p.get("appear_trust", 3.0)) - 0.0001:
				continue
			var about := false
			for c: Dictionary in present(st):
				about = about or String(c.npc) == npc
			if about:
				continue
		out.append(p)
	return out


## A party arrives (`template` a party id; "" picks one of the eligible by weight): its members are added to the state as
## "coming" and returned.
static func make_party(st: Dictionary, now: float, template := "", main: SurvivalCore = null) -> Array:
	st["seq"] = int(st.seq) + 1
	var seq := int(st.seq)
	var pseed := hash([int(st.seed), seq])
	var rng := _rng(pseed)
	var row := party_row(template)
	if row.is_empty():
		var opts := eligible(st, main)
		var w := {}
		for p: Dictionary in opts:
			w[String(p.id)] = float(p.get("weight", 1.0))
		row = party_row(pick_weighted(rng, w)) if not w.is_empty() else {}
	if row.is_empty():
		return []
	var roads := []
	for r: Dictionary in sec("places").get("roads", []):
		roads.append(String(r.id))
	var road := String(row.get("road", roads[rng.randi() % roads.size()] if not roads.is_empty() else ""))
	var sd: Array = sec("arrivals").get("stay_days", [2.0, 4.0])
	var leave_at := now + rng.randf_range(float(sd[0]), float(sd[1])) * MIN_PER_DAY
	var out := []
	var members: Array = row.get("members", [])
	for i in members.size():
		var m: Dictionary = members[i]
		var rec := make_person(String(m.kind), hash([pseed, i]), m)
		rec["id"] = "rc%d_%d" % [seq, i]
		rec["party"] = "p%d" % seq
		rec["party_kind"] = String(row.id)
		rec["npc"] = String(row.get("resident", ""))
		rec["road"] = road
		rec["state"] = "coming"
		rec["arrived_at"] = now
		rec["leave_at"] = leave_at
		rec["couple"] = bool(row.get("couple", false))
		rec["together"] = bool(row.get("together", false))
		out.append(normalize_candidate(rec))
	(st.candidates as Array).append_array(out)
	return out


## The day's hour of game minutes `now`.
static func hour_of(now: float) -> float:
	return fposmod(now, MIN_PER_DAY) / 60.0


## Moves the state on to `now`: a party arrives when one is due (by daylight, while there is room), visitors whose time
## is up turn for the road. Returns what happened: [{ev: "arrive", ids, party, text} | {ev: "leave", id}].
static func tick(st: Dictionary, main: SurvivalCore, now: float) -> Array:
	var evs := []
	var ar := sec("arrivals")
	if now >= float(st.next_at):
		var hrs: Array = ar.get("hours", [7.0, 15.0])
		var h := hour_of(now)
		if h >= float(hrs[0]) and h < float(hrs[1]):
			var rng := _rng(hash([int(st.seed), int(st.seq), "next"]))
			if present(st).size() < int(ar.get("max_present", 3)):
				var got := make_party(st, now, "", main)
				if not got.is_empty():
					var ids := []
					for c: Dictionary in got:
						ids.append(String(c.id))
					evs.append({"ev": "arrive", "ids": ids, "party": String(got[0].party),
							"text": String(party_row(String(got[0].party_kind)).get("text", "Travellers"))})
				var every: Array = ar.get("every_days", [2.0, 5.0])
				st["next_at"] = now + rng.randf_range(float(every[0]), float(every[1])) * MIN_PER_DAY
			else:
				st["next_at"] = now + 0.5 * MIN_PER_DAY
	for c: Dictionary in st.candidates:
		if PRESENT.has(String(c.state)) and now >= float(c.leave_at):
			c["state"] = "leaving"
			evs.append({"ev": "leave", "id": String(c.id)})
	return evs


## Drops the records that are done with (joined or gone), keeping a short history of who left.
static func prune(st: Dictionary) -> void:
	var keep := []
	for c: Dictionary in st.candidates:
		if String(c.state) == "gone":
			(st.departures as Array).append({"name": String(c.name), "kind": String(c.kind), "reason": "moved on"})
		elif String(c.state) != "joined":
			keep.append(c)
	st["candidates"] = keep
	while (st.departures as Array).size() > 30:
		(st.departures as Array).pop_front()


# ---------------------------------------------------------------- trust
## The product of the traits' `key` (trust_mult, morale_mult) for a record with `traits`.
static func trait_mult(traits: Array, key: String) -> float:
	var m := 1.0
	for t: Variant in traits:
		m *= float((sec("traits").get(String(t), {}) as Dictionary).get(key, 1.0))
	return m


static func trait_names(traits: Array) -> Array:
	var out := []
	for t: Variant in traits:
		out.append(String((sec("traits").get(String(t), {}) as Dictionary).get("name", String(t).capitalize())))
	return out


## The trust a candidate has in the player, 0..10: their own, plus the player's trust with the NPC a resident is.
static func trust_of(main: SurvivalCore, rec: Dictionary) -> float:
	var t := float(rec.get("trust", 0.0))
	if String(rec.get("npc", "")) != "" and main != null:
		t += SurvivalTrade.trust(main, String(rec.npc))
	return clampf(t, 0.0, num("trust", "max", 10.0))


## Trust gained (x their traits' trust_mult) or lost (as it is).
static func add_trust(rec: Dictionary, amount: float) -> void:
	var a := amount * trait_mult(rec.get("traits", []), "trust_mult") if amount > 0.0 else amount
	rec["trust"] = clampf(float(rec.get("trust", 0.0)) + a, 0.0, num("trust", "max", 10.0))


static func talk_would_count(rec: Dictionary, now: float) -> bool:
	return int(rec.get("talk_day", -1)) != floori(now / MIN_PER_DAY)


## A while spent talking: trust once a game day. False when already talked today.
static func talk(rec: Dictionary, now: float) -> bool:
	var day := floori(now / MIN_PER_DAY)
	if int(rec.talk_day) == day:
		return false
	rec["talk_day"] = day
	add_trust(rec, num("trust", "talk", 0.5))
	return true


## A unit of food given: trust up to the daily cap; the first to one in need is help ("help"). Returns "help", "ok" or
## "cap" (they thank you, no more trust today).
static func gift(rec: Dictionary, now: float) -> String:
	var day := floori(now / MIN_PER_DAY)
	if int(rec.gift_day) != day:
		rec["gift_day"] = day
		rec["gift_n"] = 0
	var out := "ok"
	if not bool(rec.fed) and needs_help(rec):
		rec["fed"] = true
		add_trust(rec, num("trust", "help", 1.5))
		out = "help"
	if int(rec.gift_n) >= int(num("trust", "gift_day_cap", 3)):
		return "cap" if out != "help" else out
	rec["gift_n"] = int(rec.gift_n) + 1
	add_trust(rec, num("trust", "gift", 0.6))
	rec["fed"] = true
	return out


static func needs_help(rec: Dictionary) -> bool:
	for w: Dictionary in rec.get("wants", []):
		if String(w.kind) == "help":
			return true
	return false


static func promise(rec: Dictionary) -> void:
	if not bool(rec.promised):
		rec["promised"] = true
		add_trust(rec, num("trust", "promise", 0.5))


# ---------------------------------------------------------------- housing
## Places to sleep among `pieces` ([{type, roofed (floors)}]): the beds and lean-tos by recruit.json housing.places, a
## roofed floor bay by roofed_floor.
static func places_in(pieces: Array) -> int:
	var hs := sec("housing")
	var per: Dictionary = hs.get("places", {})
	var n := 0
	for p: Dictionary in pieces:
		var t := String(p.get("type", ""))
		if per.has(t):
			n += int(per[t])
		elif t == "floor" and bool(p.get("roofed", false)):
			n += int(hs.get("roofed_floor", 1))
	return n


## The built pieces within range of `home` as places_in wants them (a floor is roofed when a roof piece is over it).
static func pieces_near(tree: SceneTree, home: Vector3) -> Array:
	var r := float(sec("housing").get("range_m", 60.0))
	var roofs := []
	var all := []
	for n in tree.get_nodes_in_group(BuiltPiece.GROUP):
		var bp := n as BuiltPiece
		if bp == null or not is_instance_valid(bp) or bp.is_queued_for_deletion():
			continue
		if bp.type == "roof":
			roofs.append(bp.global_position)
		if bp.global_position.distance_to(home) <= r:
			all.append(bp)
	var out := []
	for bp: BuiltPiece in all:
		var e := {"type": bp.type}
		if bp.type == "floor":
			var roofed := false
			for rp: Vector3 in roofs:
				roofed = roofed or (Vector2(rp.x - bp.global_position.x, rp.z - bp.global_position.z).length() < 2.2 and rp.y > bp.global_position.y + 1.0)
			e["roofed"] = roofed
		out.append(e)
	return out


## The people who need a place: the player and the spouse (one), each other worker (a recruited couple's second member
## shares: recruit.place 0), each child of the household at housing.children_from or older who is not a worker.
static func occupants(workers: Array, family: Array) -> int:
	var n := 1
	for w: SpouseCore in workers:
		if w.worker_id == 0:
			continue
		n += int(w.recruit.get("place", 1)) if not w.recruit.is_empty() else 1
	var from := String(sec("housing").get("children_from", "teen"))
	for c: Variant in family:
		if c is Dictionary and int((c as Dictionary).get("worker_id", -1)) < 0 and Growth.at_least(c, from):
			n += 1
	return n


## The places a party that joins needs (a couple shares one).
static func places_needed(people: Array) -> int:
	var n := 0
	var couple_seen := {}
	for c: Dictionary in people:
		if bool(c.get("couple", false)):
			if couple_seen.has(String(c.party)):
				continue
			couple_seen[String(c.party)] = true
		n += 1
	return n


# ---------------------------------------------------------------- food
## Game days the store feeds `people` (recruit.json food.kcal_per_day each): the kcal of every food kind in it
## (`kcal_of`: Callable(kind) -> kcal of one unit, SpouseCore.unit_kcal).
static func food_days(store: Dictionary, kcal_of: Callable, people: int) -> float:
	var kcal := 0.0
	for k: Variant in store:
		kcal += maxf(float(kcal_of.call(String(k))), 0.0) * int(store[k])
	return kcal / (maxf(float(people), 1.0) * num("food", "kcal_per_day", 2400.0))


# ---------------------------------------------------------------- the wants and the ask
## What a candidate wants and whether it is met now, [{kind, text, detail, met, hard}]. ctx: {free (places free now),
## food_days (the store's days for everyone with them), trust, share (the rank offered)}; `party` the people who would join.
static func wants_view(rec: Dictionary, ctx: Dictionary, party: Array) -> Array:
	var out := []
	for w: Dictionary in rec.get("wants", []):
		var k := String(w.kind)
		var e := {"kind": k, "met": true, "hard": false, "text": String(w.get("text", "")), "detail": ""}
		match k:
			"bed":
				var need := places_needed(party)
				e.hard = true
				e.met = int(ctx.get("free", 0)) >= need
				e.text = "A place to sleep" + (" for the %d of us" % need if need > 1 else "")
				e.detail = "%d free in the settlement" % maxi(int(ctx.get("free", 0)), 0)
			"food_days":
				var days := int(w.get("days", 7))
				e.met = float(ctx.get("food_days", 0.0)) >= float(days) - 0.001
				e.text = "Food in store for %d days" % days
				e.detail = "the store holds %.1f days for everyone" % float(ctx.get("food_days", 0.0))
			"share":
				var rank := int(w.get("rank", 0))
				e.met = int(ctx.get("share", 0)) >= rank
				e.text = "A fair share: %s" % share_name(rank).to_lower()
				e.detail = "you offer: %s" % share_name(int(ctx.get("share", 0))).to_lower()
			"trust":
				e.met = float(ctx.get("trust", 0.0)) >= float(w.get("min", 0.0)) - 0.001
				e.text = "To know you better"
				e.detail = "trust %.1f of %.1f" % [float(ctx.get("trust", 0.0)), float(w.get("min", 0.0))]
			"help":
				e.met = bool(rec.fed)
				e.detail = "given food" if e.met else "they have not eaten"
			"promise":
				e.met = bool(rec.promised)
				e.detail = "you gave your word" if e.met else ""
			"together":
				var names := []
				for c: Dictionary in party:
					if String(c.id) != String(rec.get("id", "")):
						names.append(String(c.name))
				e.hard = true
				e.met = party.size() > 1 or not bool(rec.get("together", false))
				e.detail = ("with " + ", ".join(names)) if not names.is_empty() else "the rest of the party is gone"
		out.append(e)
	return out


## The trust a candidate holds out for (their "trust" want; 0 without one).
static func trust_want(rec: Dictionary) -> float:
	for w: Dictionary in rec.get("wants", []):
		if String(w.kind) == "trust":
			return float(w.get("min", 0.0))
	return 0.0


## The ask's odds: {p, pct, S, D, mods [[name, add]], blocked ("" or why they cannot be asked), wants (wants_view)}.
## `rec` should be the party's leader when it joins together (leader()); `party` the people who would join.
static func odds(main: SurvivalCore, rec: Dictionary, ctx: Dictionary, party: Array, now: float) -> Dictionary:
	var ps := sec("persuade")
	var wants := wants_view(rec, ctx, party)
	var mods := []
	var blocked := ""
	var trust := float(ctx.get("trust", 0.0))
	var dt := clampf((trust - trust_want(rec)) * float(ps.get("per_trust", 0.04)), -float(ps.get("trust_cap", 0.2)), float(ps.get("trust_cap", 0.2)))
	if absf(dt) > 0.0001:
		mods.append(["trust" if dt > 0.0 else "little trust", dt])
	var by_kind: Dictionary = ps.get("unmet_by_kind", {})
	for e: Dictionary in wants:
		if bool(e.met):
			continue
		if bool(e.hard):
			if blocked == "":
				blocked = String(e.text) + (" (%s)" % e.detail if String(e.detail) != "" else "")
			continue
		var add := float(by_kind.get(String(e.kind), ps.get("unmet", -0.2)))
		if absf(add) > 0.0001:
			mods.append([String(e.text).to_lower(), add])
	if wants.all(func(e: Dictionary) -> bool: return bool(e.met)) and not wants.is_empty():
		mods.append(["all they asked for", float(ps.get("all_met", 0.15))])
	for w: Dictionary in rec.get("wants", []):
		if String(w.kind) == "share":
			var over := int(ctx.get("share", 0)) - int(w.get("rank", 0))
			if over > 0:
				mods.append(["a generous share", over * float(ps.get("share_step", 0.05))])
	if bool(rec.get("fed", false)) and needs_help(rec):
		mods.append(["you helped", float(ps.get("helped", 0.08))])
	if main != null:
		var fac := String(ps.get("standing_faction", ""))
		if fac != "":
			var tier := SurvivalEconomy.standing_tier(main, fac)
			var sa := float((ps.get("standing", {}) as Dictionary).get(tier, 0.0))
			if absf(sa) > 0.0001:
				mods.append(["standing (%s)" % tier, sa])
	for t: Variant in rec.get("traits", []):
		var ta := float((sec("traits").get(String(t), {}) as Dictionary).get("persuade", 0.0))
		if absf(ta) > 0.0001:
			mods.append([String((sec("traits").get(String(t), {}) as Dictionary).get("name", t)).to_lower(), ta])
	if blocked == "" and now < float(rec.get("cd_until", 0.0)):
		blocked = "They want time to think it over (%d hours)" % ceili((float(rec.cd_until) - now) / 60.0)
	var sum := 0.0
	for m: Array in mods:
		sum += float(m[1])
	var S := SurvivalSkills.level(main, String(ps.get("skill", "trade"))) if main != null else 0.0
	var D := float(rec.get("difficulty", 25.0))
	var p := SurvivalSkills.chance(main, S, D, sum) if main != null else clampf(0.55 + (S - D) / 60.0 + sum, 0.05, 0.97)
	mods.sort_custom(func(a: Array, b: Array) -> bool: return absf(float(a[1])) > absf(float(b[1])))
	return {"p": p, "pct": roundi(p * 100.0), "S": S, "D": D, "mods": mods, "blocked": blocked, "wants": wants}


## The factors line of an ask: the three largest modifiers, "trust +8%, food in store for 10 days -20%".
static func factors_text(o: Dictionary, n := 3) -> String:
	var parts := []
	for m: Array in (o.get("mods", []) as Array).slice(0, n):
		parts.append("%s %s%d%%" % [String(m[0]), "+" if float(m[1]) >= 0.0 else "-", absi(roundi(float(m[1]) * 100.0))])
	return ", ".join(parts)


## An outcome for chance p and a roll r in 0..1 (skills.json outcome_roll, without mishaps).
static func outcome(main: SurvivalCore, p: float, r: float) -> String:
	var orl: Dictionary = SurvivalUtil.dict(main.data.check_model().get("outcome_roll")) if main != null else {}
	if r < float(orl.get("excellent_frac", 0.1)) * p:
		return "excellent"
	if r < p:
		return "success"
	if r < p + float(orl.get("partial_band", 0.2)):
		return "partial"
	return "failure"


## Asks `rec` to join: {outcome ("blocked" | "excellent" | "success" | "partial" | "failure"), joined, ids (who joins),
## p, why}. The roll is `r` when given (tests), else the main core's survival RNG. Practises Trade; partial and failure
## put the asking off (failure costs trust).
static func ask(main: SurvivalCore, st: Dictionary, rec: Dictionary, ctx: Dictionary, now: float, r := -1.0) -> Dictionary:
	var lead := leader(st, rec)
	var party := joining(st, rec)
	var o := odds(main, lead, ctx, party, now)
	if String(o.blocked) != "":
		return {"outcome": "blocked", "joined": false, "ids": [], "p": float(o.p), "why": String(o.blocked)}
	if r < 0.0:
		r = main.rng.randf() if main != null else randf()
	var oc := outcome(main, float(o.p), r)
	var ps := sec("persuade")
	if main != null:
		SurvivalSkills.practice(main, String(ps.get("skill", "trade")), float(ps.get("practice", 0.6)))
	var ids := []
	match oc:
		"excellent", "success":
			for c: Dictionary in party:
				ids.append(String(c.id))
		"partial":
			lead["cd_until"] = now + float(ps.get("partial_cd_h", 6.0)) * 60.0
		_:
			lead["cd_until"] = now + float(ps.get("fail_cd_h", 24.0)) * 60.0
			add_trust(lead, num("trust", "refused", -0.5))
	return {"outcome": oc, "joined": not ids.is_empty(), "ids": ids, "p": float(o.p), "why": ""}


# ---------------------------------------------------------------- the worker
## The jobs a candidate would take on: what they like (their kind's and their traits'), in the job book; a teen only the
## junior jobs (growth.json teen junior). None liked: every job they may do.
static func job_prefs(rec: Dictionary) -> Array:
	var allowed: Array = JobBook.ids()
	if String(rec.get("age", "adult")) == "teen":
		allowed = (Growth.junior_rules().get("jobs", []) as Array).filter(func(id: Variant) -> bool: return JobBook.has(String(id)))
	var out := []
	for j: Variant in rec.get("likes", []):
		if allowed.has(String(j)) and not out.has(String(j)):
			out.append(String(j))
	return out if not out.is_empty() else allowed.duplicate()


## "outside" when most of the jobs are out in the woods, else "home".
static func preferred_role(jobs: Array) -> String:
	var home := 0
	var out := 0
	for j: String in jobs:
		if JobBook.role_of(j) == "outside":
			out += 1
		else:
			home += 1
	return "outside" if out > home else "home"


## The candidate's own survival core and worker (SpouseCore), on the main core's data and clock: the kind's background,
## their skills, look and name; a teen is drawn with the teen's body (Growth.body_look). Not yet in the household.
static func build_worker(main: SurvivalCore, rec: Dictionary) -> SpouseCore:
	var s := SpouseCore.new()
	s.look = (rec.get("look", {}) as Dictionary).duplicate(true)
	s.name = String(rec.get("name", "Stranger"))
	s.items = SurvivalBridge.load_items()
	s.materials = SurvivalBridge.load_items("materials")
	s.fuel = SurvivalBridge.load_items("fuel")
	var bg := String(rec.get("background", ""))
	if not main.data.backgrounds.has(bg):
		bg = main.state.background_id
	var seed_v := int(rec.get("seed", 1))
	var opts := {"data": main.data, "seed": seed_v if seed_v != 0 else 1, "preset": main.state.preset,
			"backlog_milestones": SurvivalUtil.arr(main.state.settings.get("backlog_milestones", []))}
	s.core = SurvivalCore.new_game(bg, opts)
	var st := s.core.state
	var keep_variant = st.settings.get("start_variant")
	st.settings = main.state.settings.duplicate(true)
	st.settings["start_variant"] = keep_variant
	st.minutes = main.state.minutes
	st.base_year = main.state.base_year
	st.flags["last_abs_day"] = SurvivalClock.abs_day(s.core)
	st.flags["last_dawn_day"] = SurvivalClock.abs_day(s.core) - (0 if SurvivalClock.hour(s.core) >= SurvivalCore.DAWN_HOUR else 1)
	st.weather = main.state.weather.duplicate(true)
	var sk: Dictionary = rec.get("skills", {})
	for k: Variant in sk:
		st.skills[String(k)] = float(sk[k])
	s._strip_provisions()
	s._wire()
	s.set_place("home")
	if bool(rec.get("hungry", false)):
		# on the road without food: the stomach nearly empty
		var cap := float(SurvivalNeeds.need_row(s.core, "need.food").get("stomach_capacity_kcal", 3000.0))
		st.needs["stomach"] = cap * 0.08
	if String(rec.get("age", "adult")) == "teen":
		s.body_look = teen_look(s.look, main.state.minutes)
	var jobs := job_prefs(rec)
	for id: String in JobBook.ids():
		s.enabled[id] = jobs.has(id)
	s.role = preferred_role(jobs)
	return s


## A teen's drawn body (the modest teen change of growth.json shapes, never an adult's).
static func teen_look(look: Dictionary, now: float) -> Dictionary:
	var days := float((Growth.stage_row("teen").get("shape", {}) as Dictionary).get("neutral_days", 40.0)) + 30.0
	return Growth.body_look({"look": look, "stage": "teen", "stage_at": now - days * MIN_PER_DAY}, now)


## The worker's recruit record (SpouseCore.recruit): who they are and their terms, trust and morale. `place` 0 for the
## second of a couple (they share a place).
static func recruit_record(rec: Dictionary, now: float, place := 1) -> Dictionary:
	return {"kind": String(rec.kind), "party": String(rec.party), "npc": String(rec.get("npc", "")), "age": String(rec.get("age", "adult")),
			"people": String(rec.get("people", "")), "traits": (rec.get("traits", []) as Array).duplicate(), "trust": float(rec.get("trust", 0.0)),
			"morale": num("morale", "start", 0.7), "share": int(rec.get("share", 0)), "place": place, "joined_at": now,
			"day": floori(now / MIN_PER_DAY), "low_days": 0, "busy_min": 0.0, "busy_h_prev": 0.0, "couple": bool(rec.get("couple", false))}


# ---------------------------------------------------------------- morale
static func morale_word(m: float) -> String:
	for row: Array in sec("morale").get("words", []):
		if m < float(row[0]):
			return String(row[1])
	return "content"


## The work speed of a morale: timed jobs take 1 / this as long.
static func work_mult(m: float) -> float:
	var sp: Array = sec("morale").get("speed", [0.6, 1.1])
	return lerpf(float(sp[0]), float(sp[1]), clampf(m, 0.0, 1.0))


## Where a worker's morale is heading: {target, parts {fed, housed, rested, trust}}.
static func morale_target(w: SpouseCore, housed: bool) -> Dictionary:
	var mc := sec("morale")
	var r := w.recruit
	var fed := float((mc.get("fed_by_stage", {}) as Dictionary).get(SurvivalNeeds.food_stage(w.core), 0.5))
	var hrs := float(r.get("busy_h_prev", 0.0))
	var ok := float(mc.get("work_hours_ok", 9.0))
	var mx := float(mc.get("work_hours_max", 14.0))
	var rested := 1.0 if hrs <= ok else clampf(1.0 - (hrs - ok) / maxf(mx - ok, 0.01), 0.0, 1.0)
	var parts := {"fed": fed, "housed": 1.0 if housed else 0.0, "rested": rested, "trust": clampf(float(r.get("trust", 0.0)) / 10.0, 0.0, 1.0)}
	var wts: Dictionary = mc.get("weights", {})
	var sum := 0.0
	var tw := 0.0
	for k: String in parts:
		sum += float(parts[k]) * float(wts.get(k, 0.0))
		tw += float(wts.get(k, 0.0))
	return {"target": sum / maxf(tw, 0.0001), "parts": parts}


## Moves a recruited worker's morale on by `dm` game minutes (to `now`): toward the target, the work speed with it, and at
## each day's turn the hours worked, the trust drift and the low-day count. Returns [{ev: "warn" | "leave", days}].
static func morale_tick(w: SpouseCore, dm: float, housed: bool, now: float) -> Array:
	var r := w.recruit
	if r.is_empty():
		return []
	var mc := sec("morale")
	if w.busy() and dm > 0.0:
		r["busy_min"] = float(r.get("busy_min", 0.0)) + dm
	var t := morale_target(w, housed)
	var rate := float(mc.get("rate_per_day", 0.35)) * trait_mult(r.get("traits", []), "morale_mult")
	var m := float(r.get("morale", 0.7))
	m += (float(t.target) - m) * clampf(rate * maxf(dm, 0.0) / MIN_PER_DAY, 0.0, 1.0)
	r["morale"] = clampf(m, 0.0, 1.0)
	w.work_mult = work_mult(float(r.morale))
	var evs := []
	var day := floori(now / MIN_PER_DAY)
	var turns := mini(day - int(r.get("day", day)), 10)
	for i in maxi(turns, 0):
		r["busy_h_prev"] = float(r.get("busy_min", 0.0)) / 60.0
		r["busy_min"] = 0.0
		var parts: Dictionary = t.parts
		if float(parts.fed) >= 0.7 and float(parts.housed) >= 1.0:
			r["trust"] = clampf(float(r.get("trust", 0.0)) + num("trust", "joined_day", 0.1), 0.0, num("trust", "max", 10.0))
		if float(r.morale) < float(mc.get("low", 0.3)):
			r["low_days"] = int(r.get("low_days", 0)) + 1
			if int(r.low_days) >= int(mc.get("leave_days", 3)):
				evs.append({"ev": "leave", "days": int(r.low_days)})
				break
			if (mc.get("warn_days", [1, 2]) as Array).has(int(r.low_days)) or (mc.get("warn_days", [1, 2]) as Array).has(float(r.low_days)):
				evs.append({"ev": "warn", "days": int(r.low_days)})
		else:
			r["low_days"] = 0
	r["day"] = day
	return evs
