class_name StoryObjectives
extends RefCounted
## The world checks behind a mission's steps (data/story/missions/*.json, `_kinds`). Each kind is a pair: begin() notes
## what the world holds when the step starts (so a step counts only what the player does after it), and check()
## returns {done, have, need, at} from the world as it is now. The world keeps the memory (the felled trees in
## VegHarvest, the pieces in BuildWorld, the dead in the carcasses group, the date in the survival core); a step only
## reads it. `at` is the point the marker shows (Vector3, or null for none).
##
## A check can also say the step has failed ({failed, why}: the one escorted is dead, the guide lost, the player seen)
## and how it ended ({outcome}: "caught", "unseen", the talk's answer), which the mission's branches read
## (StoryDirector); `count_text` stands in for "have / need" on screen ("1:20 left"). `base` is the step's own record
## from begin(): a check keeps its running state in it (a chase's timers; the director puts the step's seconds in
## `elapsed`, and after a load the count already made, `carried`: the counting kinds, fell, kill and steal, add it, as
## begin() counts from the world as it is then).
##
## People are read by name, not by class (the NPC fighters are built alongside): a person is a node in a group
## (FIGHTERS unless the step names another) with a `tag` (NpcFighter.tag), a `state` (COMBAT, SUSPICIOUS: a name, or
## an enum value the node's script names, or its state_name()) and a dead mark (is_dead() / `is_dead` / `dead` / state
## DEAD / health 0), each read only when it is there (a method is asked; a property, else a meta, is read: a method's
## name is never taken for a property, so NpcFighter's is_dead() and surrendered() are its answers, not Callables). A
## node that has been freed counts as dead; one about to be (queued for deletion) is no longer anyone's target.
## A fighter with a mind (NpcFighter.brain, its `aware` of each foe) sees the player only when it is the player's foe
## (NpcFactions.hostile) and aware of them (NpcBrain.SPOT in COMBAT, SUSPECT when SUSPICIOUS); a stand-in without one by
## its state and `target`.

const FIGHTERS := &"npc_fighters"
## Groups of fighters that come in waves (defend "until": "waves_end" waits while one has `waves_left`).
const SQUADS := &"npc_squads"
## A fighter in one of these states toward the player has seen them (stay_unseen, steal unseen, the "seen" fail).
const SEEN_STATES := ["COMBAT", "SUSPICIOUS"]
const DEAD_STATES := ["DEAD", "DOWN", "DYING"]


## What the step's check measures from: called once when the step starts (and again after a load).
static func begin(step: Dictionary, tree: SceneTree) -> Dictionary:
	match String(step.get("kind", "")):
		"fell":
			var h := VegHarvest.find(tree)
			return {"felled": h.felled.size() if h else 0}
		"kill":
			if people_kill(step):
				var dead := []
				var alive := []
				for n in targets(step, tree):
					(dead if is_dead(n) else alive).append(n.get_instance_id())
				return {"dead": dead, "alive": alive}
			var ids := []
			for n in tree.get_nodes_in_group(&"carcasses"):
				ids.append(_animal_key(n))
			return {"dead": ids}
		"steal":
			return {"had": pack_count(tree, String(step.get("item", ""))), "got": 0, "taken": 0}
		"lock_cast":
			return StorySlice.lock_cast_begin(step, tree)
		"survive_until":
			var c := _core(tree)
			if c == null:
				return {}
			var now := c.state.minutes
			var until := -1.0
			if step.has("for_hours"):
				until = now + float(step.for_hours) * 60.0
			elif step.has("day"):
				until = SurvivalClock.minutes_at(c, String(step.day), int(step.get("year", SurvivalClock.year(c))), float(step.get("hour", 0.0)))
			elif step.has("hour"):
				until = floorf(now / SurvivalClock.MIN_PER_DAY) * SurvivalClock.MIN_PER_DAY + float(step.hour) * 60.0
				if until <= now:
					until += SurvivalClock.MIN_PER_DAY       # (the hour has gone today: tomorrow's)
			return {"until": until}
	return {}


static func check(step: Dictionary, base: Dictionary, tree: SceneTree, places: Dictionary) -> Dictionary:
	var at: Variant = place_point(step, places)
	var el := float(base.get("elapsed", 0.0))
	match String(step.get("kind", "")):
		"go_to":
			var p := player(tree)
			if p == null or at == null:
				return {"done": false, "at": at}
			var d := _flat(p.global_position).distance_to(_flat(at))
			return {"done": d <= float(step.get("r", 10.0)), "at": at, "dist": d}
		"fell":
			var h := VegHarvest.find(tree)
			var have := (h.felled.size() if h else 0) - int(base.get("felled", 0)) + int(base.get("carried", 0))
			var need := int(step.get("count", 1))
			return {"done": have >= need, "have": mini(have, need), "need": need, "at": at}
		"build":
			var have := _pieces_near(tree, step, at).size()
			var need := int(step.get("count", 1))
			return {"done": have >= need, "have": mini(have, need), "need": need, "at": at}
		"fire_lit":
			var w := BuildWorld.of(tree, false)
			var r := float(step.get("r", 30.0))
			if w:
				for pc in w.pieces():
					if at != null and _flat(pc.global_position).distance_to(_flat(at)) > r:
						continue
					for c in pc.find_children("*", "Campfire", true, false):
						if (c as Campfire).is_lit():
							return {"done": true, "at": at}
			return {"done": false, "at": at}
		"kill":
			if people_kill(step):
				return _kill_people(step, base, tree)
			var want: Array = step.get("species", [])
			var seen: Array = base.get("dead", [])
			var have := int(base.get("carried", 0))
			var last: Variant = null
			for n in tree.get_nodes_in_group(&"carcasses"):
				var a := n as WildAnimal
				if a == null or (not want.is_empty() and not want.has(a.species)):
					continue
				if seen.has(_animal_key(a)):
					continue
				have += 1
				last = a.global_position
			var need := int(step.get("count", 1))
			return {"done": have >= need, "have": mini(have, need), "need": need, "at": last}
		"wait_for":
			var c := _core(tree)
			if c == null:
				return {"done": false, "at": null}
			var w_ok := SurvivalClock.in_window(c, step.get("window", []))
			return {"done": w_ok and _hours_ok(step.get("hours", []), c), "window_ok": w_ok, "at": null}
		"talk":
			return _talk(step, base, tree, at)
		"defend":
			return _defend(step, base, tree, at, el)
		"survive_until":
			return _survive(step, base, tree, at)
		"escort":
			return _escort(step, base, tree, at, el)
		"chase":
			return _chase(step, base, tree, el)
		"deliver":
			var need := int(step.get("count", 1))
			var have := pack_count(tree, String(step.get("item", "")))
			var d := _dist_to(player(tree), at)
			var near := at == null or d <= float(step.get("r", 6.0))
			return {"done": near and have >= need, "have": mini(have, need), "need": need, "at": at, "dist": d if at != null else -1.0}
		"steal":
			return _steal(step, base, tree, at)
		"stay_unseen":
			if StorySlice.held(step, tree):
				# (its `hold`: the seconds count from when it lets go, and it does not fail meanwhile; the marker on what
				# holds it: the fight, then the broken sky)
				base["held_s"] = el
				var wp: Variant = StorySlice.watch_point(tree)
				return {"done": false, "at": wp if wp != null else at}
			if seen_by(tree) != null:
				return {"done": false, "failed": true, "why": String(step.get("why", "You were seen.")), "at": at}
			el -= float(base.get("held_s", 0.0))
			var secs := float(step.get("seconds", 0.0 if at != null else 30.0))
			var d := _dist_to(player(tree), at)
			var done := (at != null and d <= float(step.get("r", 6.0))) or (secs > 0.0 and el >= secs)
			var out := {"done": done, "at": at, "dist": d if at != null else -1.0}
			if secs > 0.0:
				out["count_text"] = _time_left(secs - el)
			return out
		"follow":
			return _follow(step, base, tree, at, el)
		"lock_cast":
			return StorySlice.lock_cast_check(step, base, tree, at)
	return {"done": false, "at": at}


## Done as the step is passed (StoryDirector): a delivery is handed over (out of the pack, unless the step says `keep`).
## How many were handed over (the director gives them back if the mission then fails: the retry asks for them again).
static func complete(step: Dictionary, tree: SceneTree) -> int:
	if String(step.get("kind", "")) == "deliver" and not bool(step.get("keep", false)):
		return StoryEffects.take(tree, String(step.get("item", "")), int(step.get("count", 1)))
	return 0


# --- The kinds with people -------------------------------------------------------------------------------------

## A kill step about people (it names a `tag`, `tags`, a `group` or `node`, or says who: "people"), not animals.
static func people_kill(step: Dictionary) -> bool:
	return String(step.get("who", "")) == "people" or has_target(step)


## talk: the player comes within `r` of the one to talk to (`tag` / `group` / `node`) or of the place, then the director
## opens the conversation (`convo`, StoryDialogue); its close sets base.talked (and base.choice, the answer).
static func _talk(step: Dictionary, base: Dictionary, tree: SceneTree, at: Variant) -> Dictionary:
	if bool(base.get("talked", false)):
		return {"done": true, "outcome": String(base.get("choice", "")), "at": null}
	var who: Node = _first_living(targets(step, tree))
	if who == null and has_target(step):
		return {"done": false, "ready": false, "at": at}          # (the one to talk to is not here yet)
	var to: Variant = _pos(who) if who else at
	var p := player(tree)
	if to == null:
		return {"done": false, "ready": p != null, "at": null}
	var d := _dist_to(p, to)
	return {"done": false, "ready": d <= float(step.get("r", 4.0 if who else 10.0)), "at": to, "dist": d}


## kill (people): `count` of the step's people dead that were not dead as it began (the freed ones among those alive
## then count too). The marker is on a named one still standing, else on the last one down.
static func _kill_people(step: Dictionary, base: Dictionary, tree: SceneTree) -> Dictionary:
	var dead_then: Array = base.get("dead", [])
	var have := int(base.get("carried", 0))
	var last: Variant = null
	var standing: Variant = null
	for n in targets(step, tree):
		if is_dead(n):
			if not dead_then.has(n.get_instance_id()):
				have += 1
				last = _pos(n)
		elif standing == null:
			standing = _pos(n)
	for id: int in base.get("alive", []):
		if not is_instance_id_valid(id):
			have += 1
	var need := int(step.get("count", 1))
	var named := step.has("tag") or step.has("tags") or step.has("node")
	return {"done": have >= need, "have": mini(have, need), "need": need,
			"at": standing if named and standing != null else last}


## defend: keep `keep` of the step's people alive (`group` / `tag`) and the place clear of foes (`foe_group` / `foe_tag(s)`;
## by default the fighters who are the player's foes, NpcFactions.hostile) within `r` (for `breach_s` s at most), for
## `seconds` or until the waves end (`until`: "waves_end": foes came, none is left in the fight and no squad of theirs has
## `waves_left`); with neither, until the waves end. A foe run off or on its knees is out of the fight (as NpcSquad counts
## it before it sends its next wave): no breach, not one left.
static func _defend(step: Dictionary, base: Dictionary, tree: SceneTree, at: Variant, el: float) -> Dictionary:
	var out := {"done": false, "at": at}
	if has_target(step):
		var alive := _living(targets(step, tree)).size()
		if alive > 0:
			base["had_any"] = true
		if bool(base.get("had_any", false)) and alive < int(step.get("keep", 1)):
			return {"done": false, "failed": true, "why": String(step.get("why", "Too many of them were lost.")), "at": at}
	var foes := _fighting(targets(step, tree, "foe_", FIGHTERS), not has_target(step, "foe_"))
	if not foes.is_empty():
		base["foes_seen"] = true
	if at != null:
		var inside := false
		for f in foes:
			if _flat((f as Node3D).global_position).distance_to(_flat(at)) <= float(step.get("r", 15.0)):
				inside = true
				break
		if inside:
			if not base.has("breach_at"):
				base["breach_at"] = el
			if el - float(base.breach_at) >= float(step.get("breach_s", 0.0)):
				return {"done": false, "failed": true, "why": String(step.get("breach_why", "They broke through.")), "at": at}
		else:
			base.erase("breach_at")
	var secs := float(step.get("seconds", 0.0))
	var waves := String(step.get("until", "")) == "waves_end" or secs <= 0.0
	if secs > 0.0:
		out["count_text"] = _time_left(secs - el)
		if el >= secs:
			out.done = true
	if waves and bool(base.get("foes_seen", false)) and foes.is_empty() and not _waves_left(step, tree):
		out.done = true
	elif waves and secs <= 0.0 and not foes.is_empty():
		out["count_text"] = "%d left" % foes.size()
	return out


## survive_until: the player lives until a time: `for_hours` from the step's start, a `day` (and `year`, `hour`), the
## next `hour`, or (as wait_for) the date in `window` and the hour in `hours`. Dying fails it.
static func _survive(step: Dictionary, base: Dictionary, tree: SceneTree, at: Variant) -> Dictionary:
	var p := player(tree)
	if p != null and p.is_dead:
		return {"done": false, "failed": true, "why": String(step.get("why", "You did not live to see it.")), "at": at}
	var c := _core(tree)
	if c == null:
		return {"done": false, "at": at}
	var ok := true
	var out := {"done": false, "at": at}
	var until := float(base.get("until", -1.0))
	if until >= 0.0:
		var left := until - c.state.minutes
		ok = left <= 0.0
		if not ok:
			out["count_text"] = ("%d h left" % ceili(left / 60.0)) if left > 90.0 else ("%d min left" % ceili(left))
	if step.has("window"):
		ok = ok and SurvivalClock.in_window(c, step.window)
	if step.has("hours"):
		ok = ok and _hours_ok(step.hours, c)
	out.done = ok
	return out


## escort: the one escorted (`group` / `tag` / `node`) comes within `r` of the place alive; its death fails it, and so
## does leaving it (further than `leash` m for `lose_s` s, when the step has a leash).
static func _escort(step: Dictionary, base: Dictionary, tree: SceneTree, at: Variant, el: float) -> Dictionary:
	var who := _tracked(step, base, tree)
	if who == null:
		if bool(base.get("gone", false)):
			return {"done": false, "failed": true, "why": String(step.get("why", "They did not make it.")), "at": at}
		return {"done": false, "at": at}
	if is_dead(who):
		return {"done": false, "failed": true, "why": String(step.get("why", "%s did not make it." % _name_of(who, "They"))), "at": at}
	var dt := _dt(base, el)
	var p := player(tree)
	if step.has("leash") and p != null:
		if _flat(p.global_position).distance_to(_flat(who.global_position)) > float(step.leash):
			base["out"] = float(base.get("out", 0.0)) + dt
			if float(base.out) >= float(step.get("lose_s", 8.0)):
				return {"done": false, "failed": true, "why": String(step.get("lose_why", "You left them behind.")), "at": at}
		else:
			base["out"] = 0.0
	var reached := at != null and _flat(who.global_position).distance_to(_flat(at)) <= float(step.get("r", 8.0))
	return {"done": reached, "at": at, "dist": _dist_to(p, at) if at != null else -1.0}


## chase: stay within `r` of the one running (`group` / `tag` / `node`) until it is caught (within `catch_r`, or its
## `caught` / `surrendered` mark), down, or stops (after running `min_run` m it keeps still for `stop_s` s while the
## player is within `r`): outcome "caught", "down" or "stopped". Further than `r` for `lose_s` s fails it.
static func _chase(step: Dictionary, base: Dictionary, tree: SceneTree, el: float) -> Dictionary:
	var who := _tracked(step, base, tree)
	if who == null:
		if bool(base.get("gone", false)):
			return {"done": true, "outcome": "down", "at": null}
		return {"done": false, "at": null}
	if is_dead(who):
		return {"done": true, "outcome": "down", "at": null}
	if _mark(who, "caught") or _mark(who, "surrendered"):
		return {"done": true, "outcome": "caught", "at": null}
	var tp := who.global_position
	var p := player(tree)
	var d := _dist_to(p, tp)
	var dt := _dt(base, el)
	if not base.has("from"):
		base["from"] = tp
		base["prev"] = tp
	var moved := _flat(tp).distance_to(_flat(base.prev as Vector3))
	base["prev"] = tp
	if _flat(tp).distance_to(_flat(base.from as Vector3)) >= float(step.get("min_run", 5.0)):
		base["ran"] = true
	if dt > 0.0 and moved / dt < 0.5:
		base["still"] = float(base.get("still", 0.0)) + dt
	elif dt > 0.0:
		base["still"] = 0.0
	var r := float(step.get("r", 40.0))
	if d <= float(step.get("catch_r", 3.0)):
		return {"done": true, "outcome": "caught", "at": tp, "dist": d}
	if bool(base.get("ran", false)) and float(base.get("still", 0.0)) >= float(step.get("stop_s", 3.0)) and d <= r:
		return {"done": true, "outcome": "stopped", "at": tp, "dist": d}
	if d > r:
		base["out"] = float(base.get("out", 0.0)) + dt
		if float(base.out) >= float(step.get("lose_s", 4.0)):
			return {"done": false, "failed": true, "why": String(step.get("why", "They got away.")), "at": tp, "dist": d}
	else:
		base["out"] = 0.0
	return {"done": false, "at": tp, "dist": d}


## steal: `count` more of `item` in the pack, taken while near the place (within `r`); outcome "unseen", or "seen" when
## a fighter had the player in sight meanwhile. With `unseen` true, being seen fails it.
static func _steal(step: Dictionary, base: Dictionary, tree: SceneTree, at: Variant) -> Dictionary:
	var gained := pack_count(tree, String(step.get("item", ""))) - int(base.get("had", 0))
	var d := _dist_to(player(tree), at)
	var near := at == null or d <= float(step.get("r", 15.0))
	var got := int(base.get("got", 0))
	if gained > got and (near or bool(base.get("was_near", false))):
		base["taken"] = int(base.get("taken", 0)) + gained - got
	base["got"] = gained
	base["was_near"] = near
	if seen_by(tree) != null:
		base["was_seen"] = true
		if bool(step.get("unseen", false)):
			return {"done": false, "failed": true, "why": String(step.get("why", "You were seen.")), "at": at}
	var need := int(step.get("count", 1))
	var have := int(base.get("taken", 0)) + int(base.get("carried", 0))
	return {"done": have >= need, "have": mini(have, need), "need": need, "at": at, "dist": d if at != null else -1.0,
			"outcome": "seen" if bool(base.get("was_seen", false)) else "unseen"}


## follow: stay within `r` of the guide (`group` / `tag` / `node`) until it comes within `arrive_r` of the place (or for
## `seconds`); further off for `lose_s` s, or the guide dead, fails it.
static func _follow(step: Dictionary, base: Dictionary, tree: SceneTree, at: Variant, el: float) -> Dictionary:
	var who := _tracked(step, base, tree)
	if who == null:
		if bool(base.get("gone", false)):
			return {"done": false, "failed": true, "why": String(step.get("why", "Your guide is gone.")), "at": at}
		return {"done": false, "at": at}
	if is_dead(who):
		return {"done": false, "failed": true, "why": String(step.get("why", "%s is dead." % _name_of(who, "Your guide"))), "at": at}
	var p := player(tree)
	var d := _dist_to(p, who.global_position)
	var dt := _dt(base, el)
	var r := float(step.get("r", 12.0))
	if d > r:
		base["out"] = float(base.get("out", 0.0)) + dt
		if float(base.out) >= float(step.get("lose_s", 8.0)):
			return {"done": false, "failed": true, "why": String(step.get("lose_why", "You lost them.")), "at": who.global_position, "dist": d}
	else:
		base["out"] = 0.0
	var arrived := at != null and _flat(who.global_position).distance_to(_flat(at)) <= float(step.get("arrive_r", 8.0))
	var secs := float(step.get("seconds", 0.0))
	return {"done": d <= r and (arrived or (secs > 0.0 and el >= secs)), "at": who.global_position, "dist": d}


# --- Fail rules and conditions -------------------------------------------------------------------------------

## The step's or the mission's fail rules against the world now: {} while none holds, else {why, outcome}. A rule is
## "death" (the player dies), "seen" (a fighter has them in sight), or {on: "death" | "seen" | "dies" (one of
## `group` / `tag` / `node`, alive once, is dead or gone) | "time" (`s` seconds of `el`)}, with an optional `text` (the
## why) and `outcome` (the step ends that way instead of failing: the branch takes it). `st` keeps who is watched.
static func failed(rules: Variant, st: Dictionary, el: float, tree: SceneTree) -> Dictionary:
	var list: Array = rules if rules is Array else ([rules] if rules is String or rules is Dictionary else [])
	for i in list.size():
		var r: Dictionary = list[i] if list[i] is Dictionary else {"on": String(list[i])}
		var why := ""
		match String(r.get("on", "")):
			"death":
				var p := player(tree)
				if p != null and p.is_dead:
					why = "You died."
			"seen":
				if seen_by(tree) != null:
					why = "You were seen."
			"dies":
				var key := "fail_watch_%d" % i
				var watch: Array = st.get(key, [])
				for n in targets(r, tree):
					var id: int = (n as Object).get_instance_id()
					if not is_dead(n):
						if not watch.has(id):
							watch.append(id)
					elif watch.has(id):
						why = "%s died." % _name_of(n, "Someone you needed")
				for id: int in watch:
					if not is_instance_id_valid(id):
						why = "Someone you needed is gone."
				st[key] = watch
			"time":
				var s := float(r.get("s", r.get("seconds", 0.0)))
				if s > 0.0 and el >= s:
					why = "Out of time."
		if why != "":
			return {"why": String(r.get("text", why)), "outcome": String(r.get("outcome", ""))}
	return {}


## Whether a mission's `when` (or any condition of the same form) holds: every one of its parts must.
##   flags      ["name", "!name"] (set / not set) or {name: value} (true: set; else that value)
##   done       ["mission id", ...] all done;  not_done  none of them done
##   outcome    {mission id: outcome or [outcomes]}: how a mission done ended
##   window     [from day id, to day id] (SurvivalClock.in_window);  hours  [from, to] (wrapping midnight)
##   year       a year, or [first, last]
##   standing   {faction: least, or {min, max}} (SurvivalEconomy.standing)
## `ctx` is the story's record: {flags, done, outcomes}.
static func holds(when: Variant, tree: SceneTree, ctx: Dictionary) -> bool:
	if not (when is Dictionary) or (when as Dictionary).is_empty():
		return true
	var w: Dictionary = when
	var fl: Dictionary = ctx.get("flags", {})
	var f: Variant = w.get("flags")
	if f is Array:
		for k in f:
			var s := String(k)
			if s.begins_with("!"):
				if truthy(fl.get(s.substr(1))):
					return false
			elif not truthy(fl.get(s)):
				return false
	elif f is Dictionary:
		for k in f:
			var want: Variant = f[k]
			if want is bool:
				if truthy(fl.get(k)) != want:
					return false
			elif not _same(fl.get(k), want):
				return false
	var done: Array = ctx.get("done", [])
	for id in w.get("done", []):
		if not done.has(String(id)):
			return false
	for id in w.get("not_done", []):
		if done.has(String(id)):
			return false
	var outs: Dictionary = ctx.get("outcomes", {})
	var wo: Variant = w.get("outcome")
	if wo is Dictionary:
		for id in wo:
			var got := String(outs.get(id, ""))
			var ok: Variant = wo[id]
			if (ok is Array and not (ok as Array).has(got)) or (not (ok is Array) and got != String(ok)):
				return false
	if w.has("window") or w.has("hours") or w.has("year") or w.has("standing"):
		var c := _core(tree)
		if c == null:
			return false
		if w.has("window") and not SurvivalClock.in_window(c, w.window):
			return false
		if w.has("hours") and not _hours_ok(w.hours, c):
			return false
		if w.has("year"):
			var y := SurvivalClock.year(c)
			var yr: Variant = w.year
			if yr is Array and (yr as Array).size() == 2:
				if y < int(yr[0]) or y > int(yr[1]):
					return false
			elif not (yr is Array) and y != int(yr):
				return false
		var st: Variant = w.get("standing")
		if st is Dictionary:
			for fac in st:
				var v := SurvivalEconomy.standing(c, String(fac))
				var lim: Variant = st[fac]
				if lim is Dictionary:
					if v < float(lim.get("min", -INF)) or v > float(lim.get("max", INF)):
						return false
				elif v < float(lim):
					return false
	return true


static func truthy(v: Variant) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	if v is String or v is StringName:
		return String(v) != ""
	return true


static func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	if (a is String or a is StringName) and (b is String or b is StringName):
		return String(a) == String(b)
	return typeof(a) == typeof(b) and a == b


static func _hours_ok(hrs: Variant, c: SurvivalCore) -> bool:
	if not (hrs is Array) or (hrs as Array).size() != 2:
		return true
	var h := SurvivalClock.hour(c)
	var a := float(hrs[0])
	var z := float(hrs[1])
	return (h >= a and h < z) if a <= z else (h >= a or h < z)


# --- People, read by name ------------------------------------------------------------------------------------

## Whether the step (or a rule) names someone: a `tag`, `tags`, a `group` or a `node`.
static func has_target(d: Dictionary, key := "") -> bool:
	return d.has(key + "tag") or d.has(key + "tags") or d.has(key + "group") or d.has(key + "node")


## The nodes a step (or a rule) names, alive or dead: its `node` (a path under the level), else the nodes of its `group`
## (`fallback` when it names none but has tags, or says who: "people": FIGHTERS) whose `tag` is one of `tag` / `tags`.
## `key` prefixes the fields ("foe_": foe_group, foe_tag, foe_tags). A node queued for deletion (a squad freed by a
## retry) is not among them.
static func targets(d: Dictionary, tree: SceneTree, key := "", fallback: StringName = FIGHTERS) -> Array:
	var out := []
	if tree == null:
		return out
	if d.has(key + "node"):
		var scene := tree.current_scene
		var n := scene.get_node_or_null(NodePath(String(d[key + "node"]))) if scene else null
		if n != null and not n.is_queued_for_deletion():
			out.append(n)
		return out
	var tags := []
	if d.has(key + "tag"):
		tags.append(String(d[key + "tag"]))
	for t in d.get(key + "tags", []):
		tags.append(String(t))
	var group := StringName(String(d.get(key + "group", "")))
	if group == &"":
		if tags.is_empty() and key == "" and String(d.get("who", "")) != "people":
			return out
		group = fallback
	for n in tree.get_nodes_in_group(group):
		if n.is_queued_for_deletion():
			continue
		if not tags.is_empty():
			var t: Variant = _prop(n, "tag")
			if t == null or not tags.has(String(t)):
				continue
		out.append(n)
	return out


## The fighter that has the player in sight (state COMBAT or SUSPICIOUS, toward the player), or null. One with a mind
## (its brain's `aware`: NpcFighter) is the player's foe and aware of a player as much as its state needs (SPOT in COMBAT,
## SUSPECT when SUSPICIOUS: a friendly militiaman turned by a shot, or one only told of a place, has not seen anyone); a
## stand-in without one goes by its `target` (when it has one, a player).
static func seen_by(tree: SceneTree) -> Node:
	if tree == null:
		return null
	var players := tree.get_nodes_in_group("player")
	for n in tree.get_nodes_in_group(FIGHTERS):
		if n.is_queued_for_deletion() or is_dead(n):
			continue
		var st := state_name(n)
		if not SEEN_STATES.has(st):
			continue
		var brain: Variant = _prop(n, "brain")
		var aware: Variant = _prop(brain as Object, "aware") if brain is Object else null
		if aware is Dictionary:
			if not hostile_to_player(n):
				continue
			var after: Variant = _prop(n, "target")
			if st == "COMBAT" and is_instance_valid(after) and after is FrontierPlayer:
				return n
			var need := _brain_const("SPOT", 1.0) if st == "COMBAT" else _brain_const("SUSPECT", 0.35)
			for p in players:
				if float((aware as Dictionary).get(p.get_instance_id(), 0.0)) >= need:
					return n
			continue
		var t: Variant = _prop(n, "target")
		if t != null and is_instance_valid(t) and t is Node and not (t is FrontierPlayer):
			continue                                   # (it is after someone else)
		return n
	return null


## Whether a fighter is the player's foe (NpcFactions.hostile of its `faction` and "player", by name); one with no
## faction (a stand-in), or with no factions in the game, is taken for one.
static func hostile_to_player(n: Node) -> bool:
	var fac: Variant = _prop(n, "faction")
	if not (fac is String or fac is StringName):
		return true
	var nf := StoryEffects.global_script("NpcFactions")
	if nf == null or not nf.has_method("hostile"):
		return true
	return truthy(nf.call("hostile", String(fac), "player"))


## A constant of the fighters' mind (NpcBrain: SPOT, SUSPECT), read by name; `fallback` while it is not in the game.
static func _brain_const(name: String, fallback: float) -> float:
	var s := StoryEffects.global_script("NpcBrain")
	var v: Variant = s.get_script_constant_map().get(name) if s != null else null
	return float(v) if v is float or v is int else fallback


## Still in the fight: alive and not run off, routed or on its knees (state FLEE / SURRENDER, surrendered(), its brain's
## routed()); with `foes_only`, also the player's foe (hostile_to_player).
static func _fighting(list: Array, foes_only: bool) -> Array:
	var out := []
	for n in _living(list):
		var st := state_name(n)
		if st == "FLEE" or st == "SURRENDER" or _mark(n, "surrendered"):
			continue
		var brain: Variant = _prop(n, "brain")
		if brain is Object and _mark(brain as Object, "routed"):
			continue
		if foes_only and not hostile_to_player(n):
			continue
		out.append(n)
	return out


## A person's state by name ("COMBAT"; "" none): a state_name() it has, else its `state` as a name, or as an enum value
## its script names (a named enum holding COMBAT or SUSPICIOUS, else the script's own state constants).
static func state_name(n: Node) -> String:
	if n == null or not is_instance_valid(n):
		return ""
	if n.has_method("state_name"):
		return String(n.call("state_name")).to_upper()
	var v: Variant = _prop(n, "state")
	if v is String or v is StringName:
		return String(v).to_upper()
	if v is int:
		var sc := n.get_script() as Script
		while sc != null:
			var cm := sc.get_script_constant_map()
			for k in cm:
				var e: Variant = cm[k]
				if e is Dictionary and ((e as Dictionary).has("COMBAT") or (e as Dictionary).has("SUSPICIOUS")):
					for nm in e:
						if int(e[nm]) == int(v):
							return String(nm)
			for k in cm:
				if cm[k] is int and int(cm[k]) == int(v) and (SEEN_STATES.has(String(k)) or DEAD_STATES.has(String(k))):
					return String(k)
			sc = sc.get_base_script()
	return ""


## Dead: freed, or any of its dead marks (is_dead() / `is_dead` / `dead` / state DEAD / `health` 0).
static func is_dead(n: Variant) -> bool:
	if n == null or not is_instance_valid(n):
		return true
	var o := n as Object
	if _mark(o, "is_dead") or _mark(o, "dead"):
		return true
	if o is Node and DEAD_STATES.has(state_name(o as Node)):
		return true
	var hp: Variant = _prop(o, "health")
	return (hp is float or hp is int) and float(hp) <= 0.0


## A property of a node someone else's system made, or its meta of that name (stand-ins); null when neither. A method of
## that name is not a property (`name in o` holds for a method too, and get() hands back a Callable, which is truthy):
## null; _mark asks it.
static func _prop(o: Object, name: String) -> Variant:
	if o == null or not is_instance_valid(o):
		return null
	if o.has_method(name):
		return null
	if name in o:
		var v: Variant = o.get(name)
		return null if v is Callable or v is Signal else v
	if o.has_meta(name):
		return o.get_meta(name)
	return null


## A yes-or-no mark: the answer of its method of that name when it takes no arguments (NpcFighter.is_dead(),
## surrendered(), NpcBrain.routed()), else its property's or meta's (truthy).
static func _mark(o: Object, name: String) -> bool:
	if o == null or not is_instance_valid(o):
		return false
	if o.has_method(name):
		return o.get_method_argument_count(name) == 0 and truthy(o.call(name))
	return truthy(_prop(o, name))


## The step's one (the first named), remembered: once seen, its going (freed) sets base.gone.
static func _tracked(step: Dictionary, base: Dictionary, tree: SceneTree) -> Node3D:
	if base.has("who"):
		var id := int(base.who)
		if not is_instance_id_valid(id):
			base["gone"] = true
			return null
		return instance_from_id(id) as Node3D
	for n in targets(step, tree):
		if n is Node3D:
			base["who"] = n.get_instance_id()
			return n
	return null


static func _first_living(list: Array) -> Node:
	for n in list:
		if not is_dead(n) and n is Node3D and not (n as Node).is_queued_for_deletion():
			return n
	return null


static func _living(list: Array) -> Array:
	var out := []
	for n in list:
		if not is_dead(n) and n is Node3D and not (n as Node).is_queued_for_deletion():
			out.append(n)
	return out


## Whether any squad of the step's foes still has waves to send (`waves_left` > 0): of its `foe_tag(s)`, else any squad
## of the player's foes.
static func _waves_left(step: Dictionary, tree: SceneTree) -> bool:
	var tags := []
	if step.has("foe_tag"):
		tags.append(String(step.foe_tag))
	for t in step.get("foe_tags", []):
		tags.append(String(t))
	for n in tree.get_nodes_in_group(SQUADS):
		if n.is_queued_for_deletion():
			continue
		var t: Variant = _prop(n, "tag")
		if not tags.is_empty() and (t == null or not tags.has(String(t))):
			continue
		if tags.is_empty() and not hostile_to_player(n):
			continue
		var w: Variant = _prop(n, "waves_left")
		if (w is int or w is float) and float(w) > 0.0:
			return true
	return false


static func _name_of(n: Node, fallback: String) -> String:
	var v: Variant = _prop(n, "display_name")
	return String(v) if v != null and String(v) != "" else fallback


static func _pos(n: Node) -> Variant:
	return (n as Node3D).global_position if n is Node3D else null


## Seconds since the last check (the step's `elapsed` then; 0 the first time).
static func _dt(base: Dictionary, el: float) -> float:
	var dt := maxf(0.0, el - float(base.get("_e", el)))
	base["_e"] = el
	return dt


static func _time_left(s: float) -> String:
	var t := maxi(0, ceili(s))
	return "%d:%02d left" % [t / 60, t % 60]


static func _dist_to(p: Node3D, at: Variant) -> float:
	if p == null or at == null:
		return INF
	return _flat(p.global_position).distance_to(_flat(at))


# --- The world ----------------------------------------------------------------------------------------------

## The step's place as a point on the ground (null when it names none).
static func place_point(step: Dictionary, places: Dictionary) -> Variant:
	var name := String(step.get("place", ""))
	if name == "" or not places.has(name):
		return null
	var xz: Array = places[name]
	var x := float(xz[0])
	var z := float(xz[1])
	return Vector3(x, FrontierTerrain.height_at(x, z), z)


## How many of `kind` the player has: an "item." id in the survival kit (SurvivalInventory), else in the pack (as
## StoryDialogue counts them, so a mission and a talk agree about the same thing).
static func pack_count(tree: SceneTree, kind: String) -> int:
	if kind.begins_with("item."):
		var c := _core(tree)
		return int(SurvivalInventory.count(c, kind)) if c != null else 0
	var p := player(tree)
	if p == null or kind == "":
		return 0
	return InventoryState.from_player(p).pack_count(kind)


static func _pieces_near(tree: SceneTree, step: Dictionary, at: Variant) -> Array:
	var out := []
	var w := BuildWorld.of(tree, false)
	if w == null:
		return out
	var types: Array = step.get("types", [])
	var r := float(step.get("r", 30.0))
	for pc in w.pieces():
		if not types.is_empty() and not types.has(pc.type):
			continue
		if at != null and _flat(pc.global_position).distance_to(_flat(at)) > r:
			continue
		out.append(pc)
	return out


## A dead animal's key (its instance: a dragged carcass stays the same one; a load begins the step again).
static func _animal_key(n: Node) -> int:
	return n.get_instance_id()


## This machine's player (in a shared world the others are in the "player" group too).
static func player(tree: SceneTree) -> FrontierPlayer:
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("player"):
		var p := n as FrontierPlayer
		if p != null and p.is_local:
			return p
	return tree.get_first_node_in_group("player") as FrontierPlayer


static func _core(tree: SceneTree) -> SurvivalCore:
	var b := SurvivalBridge.find(tree)
	return b.core if b else null


static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)
