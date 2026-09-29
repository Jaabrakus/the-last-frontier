class_name GrowthLink
extends Node
## The node side of growing up (a child of Household; Household.growth): time passes for every child of Household.family, its care is
## sampled, its milestones checked (Growth) and the stage changed and announced; from the toddler on it has a body (ChildBody) that follows
## a parent; a teen who has done the core curriculum is taken on as a JUNIOR worker and at adulthood a full one (Growth.make_worker). It
## also runs the teaching (Teaching): watching a parent work near and awake, the teach job's lessons and the field lessons (the parent's
## real job is the lesson, the child along), the player's own lessons; and the NPC father's day (Father).
##   Household.growth.rows()                  what the Family tab shows
##   Household.growth.follow_me / stay / teach / ask_teach     the player's commands
## Every child keeps its learning SurvivalCore in `cores` (built on first use, saved into the record by flush()).

const GROUP := &"growth_link"
## A field lesson whose job has not begun after this many game minutes is given up.
const FIELD_START_MIN := 150.0

var house: Household
var cores := {}          ## child id -> its learning SurvivalCore
var bodies := {}         ## child id -> ChildBody
## {worker id: {child, topic}}: a lesson asked for (the teach job takes it first).
var lesson_request := {}
## {worker id: {child, topic, job, role_before, at}}: a field lesson: the job in hand is the lesson.
var pending_field := {}
## The player's lesson in progress: {child, topic, left (game min)}.
var session := {}
## The NPC father keeps his schedule (the player may switch it off).
var father_auto := true
var last_father := {}
var last_lines: Array = []

var _t := 0.0
var _last_min := -1.0
var _danger_until := -1.0
var _father_role := ""
var _manual_block := ""
var _hooked := {}
## {topic id: game minute until which its field lesson is not tried again}: she could not get the job started (no way out to the woods).
## The topic is taught at the hearth meanwhile (the teach job).
var _field_failed := {}


static func find(tree: SceneTree) -> GrowthLink:
	return tree.get_first_node_in_group(GROUP) as GrowthLink if tree else null


func _ready() -> void:
	add_to_group(GROUP)


func _ok() -> bool:
	return house != null and house.sc != null and house.bridge != null and house.bridge.core != null


func main() -> SurvivalCore:
	return house.bridge.core


func now() -> float:
	return main().state.minutes


func _process(dt: float) -> void:
	if not _ok() or get_tree().paused:
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.5
	var n := now()
	var dm := 0.0
	if _last_min >= 0.0:
		dm = clampf(n - _last_min, 0.0, 240.0)
	_last_min = n
	tick(dm)


# ---------------------------------------------------------------- the family
## Forgets the cores and bodies (a load: the records are new).
func reset() -> void:
	for b: Variant in bodies.values():
		if b is Node and is_instance_valid(b):
			(b as Node).queue_free()
	bodies.clear()
	cores.clear()
	pending_field.clear()
	lesson_request.clear()
	session = {}
	_hooked.clear()
	_last_min = -1.0


func child_of(id: String) -> Dictionary:
	for c: Dictionary in house.family:
		if String(c.get("id", "")) == id:
			return c
	return {}


## The child's learning core (loaded from its record, or made new), on the household's clock.
func core_of(child: Dictionary) -> SurvivalCore:
	var wk := house.crew().by_id(int(child.get("worker_id", -1))) if int(child.get("worker_id", -1)) >= 0 else null
	if wk != null:
		return wk.core   # a worker learns on her own live core
	var id := String(child.get("id", ""))
	if not cores.has(id):
		if child.get("core") is Dictionary and not (child.core as Dictionary).is_empty():
			cores[id] = SurvivalCore.from_state(SurvivalState.from_dict(child.core), {"data": main().data})
		else:
			cores[id] = Teaching.make_core(main(), int(child.get("seed", 1)))
	Teaching.sync_clock(cores[id], main())
	return cores[id]


## Writes every learning core into its record (Household.save_data calls it).
func flush() -> void:
	for c: Dictionary in house.family:
		var id := String(c.get("id", ""))
		if cores.has(id):
			c["core"] = (cores[id] as SurvivalCore).state.to_dict()


func toast(text: String) -> void:
	if text == "":
		return
	last_lines.append(text)
	if last_lines.size() > 20:
		last_lines.pop_front()
	if house.pregnancy != null:
		house.pregnancy.toast(text)


func awake_now() -> bool:
	var h := fposmod(now(), Growth.MIN_PER_DAY) / 60.0
	return h >= SpouseCore.AWAKE.x and h < SpouseCore.AWAKE.y


# ---------------------------------------------------------------- the parents
## Which parent the player is of this child: "mother" (the child was borne by the player) or "father".
func player_role(child: Dictionary) -> String:
	return "mother" if String(child.get("kind", "")) == Pregnancy.KIND_PLAYER else "father"


## The NPC parent's role for this child.
func npc_role(child: Dictionary) -> String:
	return "father" if player_role(child) == "mother" else "mother"


## The body of one parent ("mother" / "father"): the player, or the NPC's body.
func parent_body(child: Dictionary, which: String) -> Node3D:
	if which == player_role(child):
		return house.player if is_instance_valid(house.player) else null
	return house.body if house.body != null and is_instance_valid(house.body) else null


## The one the child goes about with: its `with` parent, or the other when that one is not there.
func guardian(child: Dictionary) -> Node3D:
	var w := String(child.get("with", "mother"))
	var g := parent_body(child, w)
	if g == null:
		g = parent_body(child, "father" if w == "mother" else "mother")
	return g


## A parent is at work the child can watch (the NPC with a job in hand, the player in a job).
func guardian_busy(child: Dictionary) -> bool:
	var w := String(child.get("with", "mother"))
	if w == player_role(child):
		return SurvivalJobs.is_running(main())
	return house.sc != null and house.sc.busy()


## The child stands still (the player is giving it a lesson).
func frozen(child: Dictionary) -> bool:
	return not session.is_empty() and String(session.get("child", "")) == String(child.get("id", ""))


func _near(a: Node3D, b: Node3D, r: float) -> bool:
	return a != null and b != null and is_instance_valid(a) and is_instance_valid(b) and a.global_position.distance_to(b.global_position) <= r


## Whether the child's body is within `r` metres of a Node3D (a child with no body counts as near its mother's arms).
func child_near(child: Dictionary, n: Node3D, r: float) -> bool:
	var b := child_node(child)
	return b != null and _near(b, n, r)


## The child's body in the world: its ChildBody, or a worker's Spouse body (null: none).
func child_node(child: Dictionary) -> Node3D:
	var b: Variant = bodies.get(String(child.get("id", "")))
	if b is ChildBody and is_instance_valid(b):
		return b as ChildBody
	if int(child.get("worker_id", -1)) >= 0:
		var wk := house.crew().by_id(int(child.worker_id))
		return house.body_of(wk) if wk != null else null
	return null


# ---------------------------------------------------------------- one tick
## Lets `dm` game minutes pass for every child. (Also callable headless: no bodies are made without a level.)
func tick(dm: float) -> void:
	if not _ok():
		return
	var n := now()
	Growth.normalize_all(house.family, n)
	for w: SpouseCore in house.workers():
		_hook(w)
	for c: Dictionary in house.family:
		_care(c, n)
		var ev := Growth.advance(c, n)
		if not ev.is_empty():
			_on_stage(c, ev)
		_promote_if_ready(c)
		_cap(c)
	_sync_bodies()
	_watch(dm)
	_field(n)
	_session_step(dm)
	_helpers(dm)
	_father(n)


func _care(c: Dictionary, n: float) -> void:
	var ctx := {}
	if Growth.carried(c):
		var st: Dictionary = house.baby.care.state(String(c.id)) if house.baby != null else {}
		ctx["content"] = (1.0 - BabyCare.distress(st)) if not st.is_empty() else 0.8
	else:
		if int(c.get("worker_id", -1)) >= 0:
			return   # a worker feeds and rests on its own core
		if Growth.meal_due(c, n):
			Growth.feed(c, n, func(kinds: Array) -> String: return _take_meal(kinds))
		ctx["fed"] = Growth.fed(c, n)
		var g := guardian(c)
		var b: Variant = bodies.get(String(c.id))
		var att := false
		if g != null and b is ChildBody and is_instance_valid(b):
			att = _near(b as ChildBody, g, float(Growth.cfg().get("care", {}).get("attend_m", 14.0)))
		elif g == null or not has_level():
			att = true
		ctx["attended"] = att and awake_now()
	Growth.note_care(c, n, ctx)


func has_level() -> bool:
	return house.body != null and is_instance_valid(house.body)


func _take_meal(kinds: Array) -> String:
	for k: String in kinds:
		if house.stock.take(k, 1) >= 1:
			return k
	return ""


func _on_stage(c: Dictionary, ev: Dictionary) -> void:
	var to := String(ev.to)
	var line := Growth.stage_line(c, to)
	c["note"] = line
	toast(line)
	if to == "adult":
		_promote(c)   # (already a junior worker: the caps come off)
		_sync_worker(c)


# ---------------------------------------------------------------- bodies
func _sync_bodies() -> void:
	if not has_level():
		return
	var keep := {}
	for c: Dictionary in house.family:
		var id := String(c.get("id", ""))
		if int(c.get("worker_id", -1)) >= 0:
			continue   # a worker has the Spouse body
		if Growth.has_body(c):
			keep[id] = true
			var b: Variant = bodies.get(id)
			if not (b is ChildBody and is_instance_valid(b)):
				_make_look(c)
				var g := guardian(c)
				# beside the guardian, each child at its own angle (bodies made on top of each other push one another about)
				var ang := float(hash(id) % 628) / 100.0
				var at: Vector3 = g.global_position + Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, ang) if g != null else house.home
				at.y = maxf(FrontierTerrain.height_at(at.x, at.z), at.y)
				bodies[id] = ChildBody.spawn(self, c, at)
			else:
				var cb := b as ChildBody
				if cb.child != c:
					cb.child = c
				if not is_equal_approx(cb.scale_now(), float((cb._model as Node3D).scale.x)):
					cb.refresh()
	for id: String in bodies.keys():
		if not keep.has(id):
			var b: Variant = bodies[id]
			if b is Node and is_instance_valid(b):
				(b as Node).queue_free()
			bodies.erase(id)


## The look of a child, mixed from its parents' peoples (the same seed, the same look) and kept in its record.
func _make_look(c: Dictionary) -> void:
	if c.get("look") is Dictionary and not (c.look as Dictionary).is_empty():
		return
	c["look"] = Growth.mix_look(c, _look_of(c, "mother"), _look_of(c, "father"))


func _look_of(c: Dictionary, which: String) -> Dictionary:
	if which == player_role(c):
		var p: Variant = house.player
		if p != null and is_instance_valid(p) and p.get("appearance") != null:
			return p.appearance.look
		return AppearanceStore.load_current()
	return house.sc.look


# ---------------------------------------------------------------- watching
func _watch(dm: float) -> void:
	if dm <= 0.0:
		return
	var radius := float(Teaching.curriculum().get("watch", {}).get("radius_m", 12.0))
	var awake := awake_now()
	for c: Dictionary in house.family:
		if int(c.get("worker_id", -1)) >= 0 or not Growth.can(c, "watch") or not Growth.has_body(c):
			continue
		# the NPC parent at a job
		var w := house.sc
		if w != null and w.busy() and house.body != null:
			var topic := Teaching.by_job(w.task)
			if topic != "" and child_near(c, house.body, radius):
				for i in Teaching.watch_step(c, topic, dm, true, awake):
					_credit(c, topic, w.core, w.name)
		# the player at a job
		if SurvivalJobs.is_running(main()) and is_instance_valid(house.player):
			var topic2 := Teaching.by_action(String(SurvivalJobs.current(main()).get("action", "")))
			if topic2 != "" and child_near(c, house.player, radius):
				for i in Teaching.watch_step(c, topic2, dm, true, awake):
					_credit(c, topic2, main(), "you")


func _credit(c: Dictionary, topic: String, teacher: SurvivalCore, teacher_name: String) -> void:
	var r := Teaching.give_watch(c, topic, teacher, teacher_name, core_of(c))
	if bool(r.ok):
		toast(String((Growth.cfg().get("lines", {}) as Dictionary).get("watch_done", "")).replace("{name}", String(c.name)).replace("{teacher}", teacher_name))


# ---------------------------------------------------------------- lessons
## The teach job's next lesson for a worker (SpouseCore.lesson_source): {child, topic, minutes, text} or {}. It brings the child along.
func lesson_source(w: SpouseCore) -> Dictionary:
	if not _ok() or w != house.sc or not awake_now() or not w.awake():
		return {}
	var req: Dictionary = lesson_request.get(w.worker_id, {})
	var picks := []
	if not req.is_empty():
		var rc := child_of(String(req.child))
		if not rc.is_empty() and String(Teaching.topic(String(req.topic)).get("where", "home")) == "home":
			picks.append([rc, String(req.topic)])
	for c: Dictionary in house.family:
		if picks.is_empty() and _teachable(c):
			var t := Teaching.due(c, w.core, now(), "home")
			if t == "":
				t = _due_failed_field(c, w)
			if t != "":
				picks.append([c, t])
	if picks.is_empty():
		return {}
	var c: Dictionary = picks[0][0]
	var t: String = picks[0][1]
	if not bool(Teaching.check(c, t, w.core, now()).ok):
		lesson_request.erase(w.worker_id)
		return {}
	c["with"] = npc_role(c)
	return {"child": String(c.id), "topic": t, "minutes": Teaching.minutes(t),
			"text": "Teaching %s %s" % [String(c.name), Teaching.name_of(t).to_lower()]}


## A child a parent can teach now: old enough, follows (or is a junior worker, still learning), not grown up.
func _teachable(c: Dictionary) -> bool:
	if not Growth.can(c, "lesson") or not Growth.has_body(c) or Growth.stage_of(c) == "adult":
		return false
	return int(c.get("worker_id", -1)) >= 0 or String(c.get("mode", "follow")) == "follow"   # (a junior worker still learns)


## The teach job ends (SpouseCore.lesson_done): the lesson is given when the child is still close by. Returns her line.
func lesson_done(w: SpouseCore, d: Dictionary) -> String:
	var c := child_of(String(d.get("child", "")))
	if c.is_empty():
		return "%s finds nobody to teach." % w.name
	var reach := float(Teaching.curriculum().get("watch", {}).get("radius_m", 12.0)) * 0.7
	if has_level() and not child_near(c, house.body, reach):
		return "%s waits for %s, who has wandered off." % [w.name, String(c.name)]
	var r := Teaching.give(c, String(d.topic), w.core, w.name, core_of(c), now())
	lesson_request.erase(w.worker_id)
	if not bool(r.ok):
		return "%s cannot teach %s that now." % [w.name, String(c.name)]
	var text := _lesson_line(c, String(d.topic), w.name)
	toast(text)
	return text


func _lesson_line(c: Dictionary, topic: String, teacher: String) -> String:
	var opts: Array = (Growth.cfg().get("lines", {}) as Dictionary).get("lesson_done", ["{teacher} has shown {name} {topic}."])
	return String(opts[hash(String(c.id) + topic) % opts.size()]).replace("{name}", String(c.name)).replace("{teacher}", teacher) \
			.replace("{topic}", Teaching.name_of(topic).to_lower())


## The body of the child a worker is giving a lesson to now (null: none): she turns to it.
func lesson_child(w: SpouseCore) -> Node3D:
	var d: Dictionary = w._run.get("lesson", {})
	return child_node(child_of(String(d.get("child", "")))) if not d.is_empty() else null


## A field topic whose field lesson would not start, taught at the hearth instead ("" none).
func _due_failed_field(c: Dictionary, w: SpouseCore) -> String:
	for o: Dictionary in Teaching.offers(c, w.core, now()):
		if bool(o.ok) and String(o.where) == "field" and float(_field_failed.get(String(o.topic), -1.0)) > now():
			return String(o.topic)
	return ""


func _hook(w: SpouseCore) -> void:
	if _hooked.has(w.worker_id) and _hooked[w.worker_id] == w:
		return
	_hooked[w.worker_id] = w
	w.task_finished.connect(func(task: String, _text: String) -> void: _on_task_finished(w, task))
	if w == house.sc:
		w.lesson_source = lesson_source
		w.lesson_done = lesson_done


## A parent's job that is a field lesson ends: given if the child is still near.
func _on_task_finished(w: SpouseCore, task: String) -> void:
	var p: Dictionary = pending_field.get(w.worker_id, {})
	if p.is_empty() or String(p.job) != task:
		return
	pending_field.erase(w.worker_id)
	var c := child_of(String(p.child))
	if not c.is_empty() and (not has_level() or child_near(c, house.body, Teaching.curriculum().get("watch", {}).get("radius_m", 12.0))):
		var r := Teaching.give(c, String(p.topic), w.core, w.name, core_of(c), now())
		if bool(r.ok):
			toast(_lesson_line(c, String(p.topic), w.name))
	if String(p.get("role_before", "")) != "" and w.role != "follow":
		house.set_role(String(p.role_before), w)


## The field lessons: an idle NPC parent by day with a child due a 'field' topic does the real job with the child along.
func _field(n: float) -> void:
	var w := house.sc
	for wid: int in pending_field.keys():
		var p: Dictionary = pending_field[wid]
		var never_began := not w.busy() and n - float(p.at) > FIELD_START_MIN
		if n - float(p.at) > 480.0 or never_began:
			pending_field.erase(wid)
			if never_began:
				_field_failed[String(p.topic)] = n + 3.0 * Growth.MIN_PER_DAY   # (no way out to the woods: the hearth teaches it)
			if String(p.get("role_before", "")) != "":
				house.set_role(String(p.role_before), w)
	if w == null or not pending_field.is_empty() or w.busy() or w.role not in ["home", "outside"] or not w.awake() or not w.daylight() \
			or is_danger(n) or w._cool > 0.0:
		return
	for c: Dictionary in house.family:
		if not _teachable(c):
			continue
		var req: Dictionary = lesson_request.get(w.worker_id, {})
		var t := ""
		if not req.is_empty() and String(req.child) == String(c.id) and String(Teaching.topic(String(req.topic)).get("where", "")) == "field":
			t = String(req.topic)
		elif req.is_empty():
			t = Teaching.due(c, w.core, n, "field")
		if t == "" or not bool(Teaching.check(c, t, w.core, n).ok) or float(_field_failed.get(t, -1.0)) > n:
			continue
		var job := String(Teaching.topic(t).get("job", ""))
		if job == "" or not bool(w.enabled.get(job, false)) or w.offer(job).is_empty():
			continue
		start_field(w, c, t)
		return


## Starts a field lesson: the worker takes the topic's job, the child comes along.
func start_field(w: SpouseCore, c: Dictionary, topic: String) -> void:
	var job := String(Teaching.topic(topic).get("job", ""))
	var before := w.role
	house.order(job, w)
	c["with"] = npc_role(c)
	pending_field[w.worker_id] = {"child": String(c.id), "topic": topic, "job": job, "role_before": before if before in ["home", "outside"] else "home", "at": now()}
	lesson_request.erase(w.worker_id)


# ---------------------------------------------------------------- the player teaches, asks, commands
## What each of you can teach a child now: [{topic, name, ok, text, minutes, ...}]. `who`: "you" or "npc".
func offers(child_id: String, who := "you") -> Array:
	var c := child_of(child_id)
	if c.is_empty() or not _ok():
		return []
	var core: SurvivalCore = main() if who == "you" else house.sc.core
	return Teaching.offers(c, core, now())


func teacher_name(who: String) -> String:
	return "You" if who == "you" else house.sc.name


## The player gives the lesson: it takes the topic's minutes with the child beside them. Returns a line.
func teach(child_id: String, topic: String) -> String:
	var c := child_of(child_id)
	if c.is_empty() or not _ok():
		return ""
	var chk := Teaching.check(c, topic, main(), now())
	if not bool(chk.ok):
		return refusal(c, chk, "You")
	if has_level() and not child_near(c, house.player, 8.0):
		return refusal(c, {"reason": "far"}, "You")
	c["with"] = player_role(c)
	session = {"child": child_id, "topic": topic, "left": Teaching.minutes(topic)}
	return "You sit with %s: %s (%d minutes)." % [String(c.name), Teaching.name_of(topic).to_lower(), roundi(Teaching.minutes(topic))]


func _session_step(dm: float) -> void:
	if session.is_empty() or dm <= 0.0:
		return
	var c := child_of(String(session.child))
	if c.is_empty():
		session = {}
		return
	if has_level() and not child_near(c, house.player, 9.0):
		toast("%s wandered off: the lesson is lost." % String(c.name))
		session = {}
		return
	session["left"] = float(session.left) - dm
	if float(session.left) > 0.0:
		return
	var topic := String(session.topic)
	session = {}
	var r := Teaching.give(c, topic, main(), "you", core_of(c), now())
	if bool(r.ok):
		toast(_lesson_line(c, topic, "You"))


## Asks the NPC parent to teach a topic: a 'home' topic is the teach job (she takes it first), a 'field' topic is her real job with the child
## along. Returns a line.
func ask_teach(child_id: String, topic: String, w: SpouseCore = null) -> String:
	w = w if w != null else house.sc
	var c := child_of(child_id)
	if c.is_empty() or not _ok():
		return ""
	var chk := Teaching.check(c, topic, w.core, now())
	if not bool(chk.ok):
		return refusal(c, chk, w.name)
	lesson_request[w.worker_id] = {"child": child_id, "topic": topic}
	c["with"] = npc_role(c)
	c["mode"] = "follow"
	if String(Teaching.topic(topic).get("where", "home")) == "field":
		var job := String(Teaching.topic(topic).get("job", ""))
		if job == "" or not bool(w.enabled.get(job, false)):
			lesson_request.erase(w.worker_id)
			return "%s does not do that job." % w.name
		start_field(w, c, topic)
		return "%s takes %s along to show %s." % [w.name, String(c.name), Teaching.name_of(topic).to_lower()]
	house.order("teach", w)
	return "%s will teach %s %s." % [w.name, String(c.name), Teaching.name_of(topic).to_lower()]


## A refusal in words (growth.json lines.refuse).
func refusal(c: Dictionary, chk: Dictionary, teacher: String) -> String:
	var t: String = String(((Growth.cfg().get("lines", {}) as Dictionary).get("refuse", {}) as Dictionary).get(String(chk.get("reason", "")), "Not now."))
	return t.replace("{name}", String(c.name)).replace("{teacher}", teacher).replace("{need}", String(chk.get("need", "")))


func follow_me(child_id: String) -> String:
	var c := child_of(child_id)
	if c.is_empty():
		return ""
	c["with"] = player_role(c)
	c["mode"] = "follow"
	return _say(c, "come", player_role(c))


func stay(child_id: String) -> String:
	var c := child_of(child_id)
	if c.is_empty():
		return ""
	c["mode"] = "stay"
	return _say(c, "stay", "")


func _say(c: Dictionary, key: String, parent: String) -> String:
	var opts: Array = (Growth.cfg().get("lines", {}) as Dictionary).get(key, [])
	if opts.is_empty():
		return ""
	return "%s: \"%s\"" % [String(c.name), String(opts[hash(String(c.id) + key) % opts.size()]).replace("{parent}", "Mama" if parent == "mother" else "Papa")]


## E on a child: [{id, text}], the first the tap's.
func actions_for(c: Dictionary) -> Array:
	var name := String(c.get("name", ""))
	var going := String(c.get("mode", "follow")) == "follow" and String(c.get("with", "")) == player_role(c)
	var out := []
	if Growth.can(c, "follow"):
		out.append({"id": "stay" if going else "follow", "text": String((Growth.cfg().get("player_commands", {}) as Dictionary).get("stay_text" if going else "follow_text", "%s")) % name})
	if Growth.can(c, "lesson") or Growth.can(c, "watch"):
		out.append({"id": "teach", "text": String((Growth.cfg().get("player_commands", {}) as Dictionary).get("teach_text", "Teach %s...")) % name})
	out.append({"id": "family", "text": "Household"})
	return out


func do_action(child_id: String, id: String) -> void:
	var line := ""
	match id:
		"follow":
			line = follow_me(child_id)
		"stay":
			line = stay(child_id)
		_:
			open_family(child_id)
			return
	toast(line)


func open_family(child_id: String) -> void:
	if house != null and house.screen == null:
		house.open(house.body, "family")
		if house.screen != null:
			house.screen.family_child = child_id


# ---------------------------------------------------------------- what the family tab shows
## One row per child: {id, name, girl, stage, stage_name, age, hint, with, mode, worker, progress, lines, note, can_teach, topics}.
func rows() -> Array:
	var out := []
	if not _ok():
		return out
	var n := now()
	for c: Dictionary in house.family:
		Growth.normalize(c, n)
		var p := Growth.progress(c, n)
		var wid := int(c.get("worker_id", -1))
		var with_text := "carried" if Growth.carried(c) else "on its own"
		if not Growth.carried(c):
			var mode := String(c.get("mode", "follow"))
			var w := String(c.get("with", "mother"))
			with_text = "stays put" if mode == "stay" else "with %s" % (house.sc.name if w == npc_role(c) else "you")
		if wid >= 0:
			var wk := house.crew().by_id(wid)
			with_text = "works with the household" if wk != null else "left the household"
		out.append({"id": String(c.id), "name": String(c.name), "girl": float(c.sex) < 0.5, "stage": String(p.stage), "stage_name": String(p.name),
				"age": Pregnancy.age_text(c, n), "hint": String(p.hint), "with": with_text, "mode": String(c.get("mode", "follow")),
				"worker": wid >= 0, "ready": bool(p.ready), "lines": p.lines, "note": String(c.get("note", "")),
				"lessons": int(c.get("lessons", 0)), "can_teach": Growth.can(c, "lesson"), "carried": Growth.carried(c),
				"adult": String(p.stage) == "adult", "topics": (c.get("topics", {}) as Dictionary).keys()})
	return out


# ---------------------------------------------------------------- growing up
## A teen (or adult) with the core curriculum done is taken on as a worker of the household (junior at teen, full at adult).
func _promote_if_ready(c: Dictionary) -> void:
	if int(c.get("worker_id", -1)) < 0 and Growth.worker_ready(c):
		_promote(c)


func _promote(c: Dictionary) -> void:
	if int(c.get("worker_id", -1)) >= 0 or not _ok() or house.stock == null:
		return
	var w := Growth.make_worker(main(), c, core_of(c))
	var jobs := Growth.allowed_jobs(c)
	var b: Variant = bodies.get(String(c.id))
	var at := house.home
	if b is ChildBody and is_instance_valid(b):
		at = (b as ChildBody).global_position
	house.adopt(w, at)
	house.stock.crew.set_jobs(w, jobs)
	c["worker_id"] = w.worker_id
	_sync_worker(c)
	if String(c.stage) != "adult":
		toast(String((Growth.cfg().get("lines", {}) as Dictionary).get("junior", "")).replace("{name}", String(c.name)))


## The worker's body proportions and job set follow the stage (the caps come off at adulthood).
func _sync_worker(c: Dictionary) -> void:
	var w := house.crew().by_id(int(c.get("worker_id", -1)))
	if w == null:
		return
	house.stock.crew.set_jobs(w, Growth.allowed_jobs(c))
	_shape_worker(c, w)
	var b := house.body_of(w)
	if b != null:
		b.set_proportions(Growth.num(c, "scale", 1.0), Growth.num(c, "head", 1.0))


## The worker's body shape follows the stage (neutral, the modest teen change, the adult's): a body made again when it changes.
func _shape_worker(c: Dictionary, w: SpouseCore) -> void:
	var shape := Growth.shape_of(c, now())
	if String(c.get("shape", "")) == shape:
		return
	var first := String(c.get("shape", "")) == ""
	c["shape"] = shape
	if c.get("look") is Dictionary and not (c.look as Dictionary).is_empty():
		w.body_look = Growth.body_look(c, now())   # (her `look`, the logic, stays: her sex and face)
	if not first and has_level():
		var b := house.body_of(w)
		if b != null:
			w.cancel("growing")
			house.adopt(w, b.global_position)
			var nb := house.body_of(w)
			if nb != null:
				nb.set_proportions(Growth.num(c, "scale", 1.0), Growth.num(c, "head", 1.0))


func _cap(c: Dictionary) -> void:
	var w := house.crew().by_id(int(c.get("worker_id", -1)))
	if w != null:
		Growth.enforce_cap(w, c)
		_shape_worker(c, w)
		var b := house.body_of(w)   # (also after a load: the body is made at full size)
		if b != null and b._model != null and absf(b._model.scale.x - Growth.num(c, "scale", 1.0)) > 0.001:
			b.set_proportions(Growth.num(c, "scale", 1.0), Growth.num(c, "head", 1.0))


# ---------------------------------------------------------------- helpers: a child at a parent's timed job
## A child that can do chores, near a parent at a timed job, speeds it up by the stage's helper_bonus.
func _helpers(dm: float) -> void:
	var w := house.sc
	if dm <= 0.0 or w == null or not w.busy() or w.minutes_left <= 0.0 or house.body == null:
		return
	var bonus := 0.0
	for c: Dictionary in house.family:
		if Growth.can(c, "chores") and int(c.get("worker_id", -1)) < 0 and child_near(c, house.body, 6.0) and awake_now():
			bonus += Teaching.helper_bonus(c)
	if bonus > 0.0:
		w.minutes_left = maxf(w.minutes_left - dm * bonus, 0.0)


# ---------------------------------------------------------------- the NPC father
func is_danger(n: float) -> bool:
	return n < _danger_until


func _scan_danger(n: float) -> void:
	if not has_level():
		return
	var r := float(Father.cfg().get("danger_m", 55.0))
	for a: Node in get_tree().get_nodes_in_group(&"wildlife"):
		if not (a is Node3D) or not a.has_method("is_prey") or a.is_prey() or (a.has_method("is_dead") and a.is_dead()):
			continue
		if (a as Node3D).global_position.distance_to(house.home) < r or _near(a as Node3D, house.body, r):
			_danger_until = n + float(Father.cfg().get("danger_hold_min", 45.0))
			return


func _father(n: float) -> void:
	var w := house.sc
	if w == null or not w.is_male() or house.family.is_empty():
		return   # the player is the father (or nobody is): his own commands
	_scan_danger(n)
	var kids := []
	var awake := awake_now()
	var any_baby := house.baby != null and house.baby.focus != ""
	for c: Dictionary in house.family:
		if int(c.get("worker_id", -1)) >= 0:
			continue
		kids.append({"id": String(c.id), "stage": Growth.stage_of(c), "with": String(c.get("with", "mother")), "mode": String(c.get("mode", "follow")),
				"due": awake and _teachable(c) and Teaching.due(c, w.core, n) != ""})
	var mother_busy := SurvivalJobs.is_running(main()) or (is_instance_valid(house.player) and house.player.is_dead)
	var d := Father.decide({"hour": w.hour(), "danger": is_danger(n), "children": kids, "mother_busy": mother_busy,
			"baby": {"present": any_baby, "holder": house.baby.care.holder_of(house.baby.focus) if any_baby else ""}})
	last_father = d
	if not father_auto:
		return
	# the player's own orders to him stand until the block changes
	if _father_role != "" and w.role != _father_role and (w.role in ["follow", "stay"] or w.role in ["home", "outside"]) and _manual_block == "":
		_manual_block = String(d.block)
	elif _manual_block != "" and _manual_block != String(d.block):
		_manual_block = ""
	if _manual_block == "":
		if w.role in ["home", "outside"] and w.role != String(d.sc_role) and not w.busy():
			house.set_role(String(d.sc_role), w)
			_father_role = String(d.sc_role)
		elif w.role == String(d.sc_role):
			_father_role = w.role
		for id: String in d.take:
			var c := child_of(id)
			if not c.is_empty() and String(c.get("mode", "follow")) == "follow":
				c["with"] = "father" if npc_role(c) == "father" else npc_role(c)
		for id: String in d.release:
			var c2 := child_of(id)
			if not c2.is_empty():
				c2["with"] = "mother" if npc_role(c2) == "father" else npc_role(c2)
		if String(d.teach) != "" and not w.busy() and pending_field.is_empty():
			var tc := child_of(String(d.teach))
			var t := Teaching.due(tc, w.core, n)
			if not tc.is_empty() and t != "":
				lesson_request[w.worker_id] = {"child": String(tc.id), "topic": t}
				if String(Teaching.topic(t).get("where", "home")) == "field":
					if bool(w.enabled.get(String(Teaching.topic(t).get("job", "")), false)):
						start_field(w, tc, t)
				elif w.role == "home":
					house.order("teach", w)
					_father_role = "home"
	if bool(d.carry_baby) and house.baby != null and house.baby.care.holder_of(house.baby.focus) == "player":
		house.baby.give_back()   # BabyLink's own hand-over: the father comes and takes the baby
