class_name BoatStand
extends Node3D
## The boat stand by the water (a built piece, "boat_stand"; user 2026-09-29: "a boat stand by the river ... they bring materials to
## it and attach to it and they can see it grow into something real"). E opens its list of stages (StationMenu): the craft's own steps
## in order, each with what it needs (in the kit and at the stand), whether the builder knows how, and its state. Picking one brings the
## parts it needs from the kit, then starts it and works it (SurvivalBridge.work: kneeling at it, a bar, moving stops it and the work
## done so far stays), and a stage with a puzzle then waits to be played. The hull (HullMesh) grows as the stages go, and the finished
## boat is launched onto the water (Boat, with the grades' stats). The logic is BoatBuild's; this is the piece, the menu and the world.
## Parts come out of the core's inventory (SurvivalInventory, the survival items' ids); knowledge is SurvivalLearning's.

const GROUP := &"interactables"
const STANDS := &"boat_stands"
const SKILL := "woodcraft"
const LAUNCH_SEARCH_M := 30.0

var boat_id := "birchbark"
var build: BoatBuild
var hull: HullMesh
var interact_reach := 2.8
## The last thing said at the stand (the menu's first line; tests).
var last := ""
## Tests: the work is done at once (no kneeling, no bar).
var instant_work := false
var _bridge: SurvivalBridge
var _player: Node
var _t0 := 0
var _secs := 0.0
var _min_left := 0.0


static func attach(piece: Node3D, id := "birchbark") -> BoatStand:
	var s := BoatStand.new()
	s.name = "BoatStand"
	s.boat_id = id
	piece.add_child(s)
	return s


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(STANDS)
	build = BoatBuild.make(boat_id)
	build.know = _know
	build.has_tool = _has_tool
	hull = HullMesh.new()
	hull.name = "Hull"
	add_child(hull)
	hull.setup(build.plan.get("hull", {}))
	refresh()


func bridge() -> SurvivalBridge:
	if _bridge == null or not is_instance_valid(_bridge):
		_bridge = SurvivalBridge.find(get_tree())
	return _bridge


func _core() -> SurvivalCore:
	var b := bridge()
	return b.core if b != null else null


func _know(kid: String) -> String:
	var c := _core()
	return SurvivalLearning.state_of(c, kid) if c != null else "known"


func _has_tool(ids: Array) -> bool:
	var pl := _pl()
	return TreeHarvest.has_any(pl, (pl.get("gather") as GatherTools) if pl != null else null, ids)


## The player at the stand (the last one to open it, else the level's).
func _pl(p: Node = null) -> Node:
	if p != null and is_instance_valid(p):
		_player = p
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	return _player


## The builder's skill 0..1 (woodcraft).
func skill01() -> float:
	var c := _core()
	return clampf(SurvivalSkills.level(c, SKILL) / 100.0, 0.0, 1.0) if c != null else 0.5


# ---------------------------------------------------------------- the hull grows
## The parts of the hull shown for what is done and what is being worked.
func refresh() -> void:
	var show := {"stakes": 0.0, "skin": 0.0, "gunwales": 0.0, "ribs": 0.0, "pitch": 0.0}
	for s: Dictionary in build.stages():
		var sid := String(s.id)
		var f := 0.0
		if build.done.has(sid):
			f = 1.0
		elif build.current == sid:
			f = clampf(build.progress / maxf(build.work_min(sid), 1.0), 0.0, 1.0)
			if build.waiting:
				f = 1.0
		if f > 0.0:
			for part: String in s.get("shows", []):
				show[part] = maxf(float(show[part]), f)
	if build.is_complete():
		show["stakes"] = 0.0   # the boat is lifted off its bed
	for id: String in show:
		hull.set_part(id, float(show[id]))


# ---------------------------------------------------------------- E
func _build_mode_on() -> bool:
	return is_instance_valid(BuildMode.current) and BuildMode.current.active


func interact_point() -> Vector3:
	return global_transform * Vector3(0.0, 0.6, 0.0)


func distance_from(p: Vector3) -> float:
	return p.distance_to(interact_point())


func highlight_targets() -> Array:
	var p := get_parent() as BuiltPiece
	return p.highlight_targets() if p else []


func interact_prompt(_player: Node) -> String:
	if _build_mode_on():
		return ""
	var b := bridge()
	if b == null or (b.work and b.work.working):
		return ""
	return "Build the %s" % String(build.plan.get("name", "boat")).to_lower() if not build.is_complete() else "The %s is ready" % String(build.plan.get("name", "boat")).to_lower()


func interact(player: Node) -> void:
	if _build_mode_on() or bridge() == null:
		return
	_pl(player)
	open_menu(player)


## The stages' rows: [{text, detail, ok}], for the menu (and tests).
func rows() -> Array:
	var out: Array = []
	for s: Dictionary in build.stages():
		var sid := String(s.id)
		var row := {"text": String(s.name), "detail": "", "ok": true}
		if build.done.has(sid):
			var g := build.grade_of(sid)
			row.text = "Done: %s" % String(s.name)
			row.detail = "%s work%s" % [build.grade_word(g), " (out of order)" if not bool((build.done[sid] as Dictionary).ordered) else ""]
		elif build.current == sid:
			if build.waiting:
				row.text = "%s: play the puzzle" % String(s.name)
				row.detail = "the work is done; how well it is fitted is up to you"
			else:
				row.text = "%s: carry on" % String(s.name)
				row.detail = "%d%% done" % roundi(100.0 * build.progress / maxf(build.work_min(sid), 1.0))
		else:
			var parts: Array[String] = []
			for k: String in (s.get("needs", {}) as Dictionary):
				var need := int((s.needs as Dictionary)[k])
				var at := int(build.store.get(k, 0))
				var kit := TreeHarvest.pack_count(_pl(), k)
				parts.append("%d %s (%d here, %d in your pack)" % [need, InventoryState.name_of(k).to_lower(), at, kit])
			var why := build.can_start(sid)
			var know_state := build.knowledge(sid)
			var note := ""
			if know_state == "unknown":
				note = "you do not know how yet: ask someone who does"
				row.ok = false
			elif know_state == "heard_of" or know_state == "seen":
				note = "you only %s how: it will go clumsily" % ("have heard" if know_state == "heard_of" else "have seen")
			if String(why.reason) == "tool":
				note = "needs a tool: %s" % _tool_names(s)
				row.ok = false
			if build.current != "":
				note = "finish the current stage first"
				row.ok = false
			elif sid != build.next_id():
				note = (note + "; " if note != "" else "") + "this is not the next step"
			row.detail = "; ".join(parts) + ("" if note == "" else "  |  " + note)
		out.append(row)
	return out


func _tool_names(s: Dictionary) -> String:
	var names: Array[String] = []
	for id: String in s.get("tool", []):
		var n := id.get_slice(":", 1) if id.begins_with("gather:") else id.get_slice(".", 2) if id.begins_with("item.") else id
		names.append(n.replace("_", " "))
	return " or ".join(names)


func open_menu(player: Node) -> void:
	_pl(player)
	var title := String(build.plan.get("name", "Boat")) + (" (%s)" % build.stats().word if build.is_complete() else "")
	var r := rows()
	r.append_array(make_rows())
	if build.is_complete():
		r.append({"text": "Launch it onto the water", "detail": "a %s canoe; %s" % [build.stats().word, _stats_line()], "ok": true})
	if last != "":
		r.push_front({"text": last, "detail": "", "ok": true})
	var m := StationMenu.open(get_tree(), title, r)
	var i: int = await m.picked
	if i < 0:
		return
	if last != "":
		i -= 1
		last = ""
		if i < 0:
			open_menu(player)
			return
	choose(i, player)


## The parts made at the stand from poles (data/boats/parts.json "make"): rows for the menu.
func make_rows() -> Array:
	var out: Array = []
	if build.is_complete():
		return out
	var make: Dictionary = TreeHarvest.cfg().get("make", {})
	for k: String in make:
		var m: Dictionary = make[k]
		var have := TreeHarvest.pack_count(_pl(), String(m.from))
		out.append({"text": "%s  (%d %s makes %d)" % [String(m.text), int(m.takes), String(m.from), int(m.makes)],
				"detail": "%d %s in your pack" % [have, String(m.from)] + ("" if have >= int(m.takes) else "  |  cut a sapling for a pole"), "ok": have >= int(m.takes)})
	return out


func _stats_line() -> String:
	var st := build.stats()
	return "speed x%.2f, %.0f l/h leaks, wear x%.2f" % [float(st.speed_mult), float(st.leak_l_per_h), float(st.wear_mult)]


## Menu row `i` was picked: a stage, a part to make, or the launch row after them.
func choose(i: int, player: Node = null) -> void:
	var st := build.stages()
	var kinds: Array = (TreeHarvest.cfg().get("make", {}) as Dictionary).keys() if not build.is_complete() else []
	if i >= st.size() + kinds.size():
		var boat := launch()
		last = "It slides into the water." if boat != null else "There is no water within reach to launch it."
		refresh()
		if boat == null:
			open_menu(player)
		return
	if i >= st.size():
		last = make_part(String(kinds[i - st.size()]))
		if last != "" and not _working():
			open_menu(player)
		return
	var sid := String((st[i] as Dictionary).id)
	last = pick(sid, player)
	if last != "" and not _working():
		open_menu(player)


## Makes a part from poles: the tool, the poles, a little work; the parts go to the pack. Returns what to tell ("" while the work goes on).
func make_part(kind: String) -> String:
	var make: Dictionary = TreeHarvest.cfg().get("make", {})
	if not make.has(kind):
		return ""
	var m: Dictionary = make[kind]
	var pl := _pl()
	var tools := (pl.get("gather") as GatherTools) if pl != null else null
	if not TreeHarvest.has_any(pl, tools, m.get("tool", [])):
		return "You need a knife, a hatchet or an axe for that."
	if TreeHarvest.pack_count(pl, String(m.from)) < int(m.takes):
		return "You need a %s for that: cut a sapling." % String(m.from)
	var finish := func() -> String:
		if TreeHarvest.pack_take(pl, String(m.from), int(m.takes)) < int(m.takes):
			return "You need a %s for that." % String(m.from)
		TreeHarvest.pack_add(pl, kind, int(m.makes))
		return "%d %s made." % [int(m.makes), InventoryState.name_of(kind).to_lower()]
	var b := bridge()
	if instant_work or b == null or b.work == null:
		return String(finish.call())
	if not b.work.begin(global_position, "low", String(m.verb), float(m.seconds), "", func(done: bool) -> void:
			last = String(finish.call()) if done else "You stop before it is done."
			open_menu(_pl())):
		return "You cannot work at it now."
	return ""


func _working() -> bool:
	var b := bridge()
	return b != null and b.work != null and b.work.working


## What picking a stage does: bring its parts, begin it, work it, or play its puzzle. Returns what to tell ("" when work began).
func pick(sid: String, p: Node = null) -> String:
	_pl(p)
	var s := build.stage(sid)
	if s.is_empty():
		return ""
	if build.done.has(sid):
		return "%s is done: %s work." % [String(s.name), build.grade_word(build.grade_of(sid))]
	if build.current != "" and build.current != sid:
		return "Finish %s first." % String(build.stage(build.current).name).to_lower()
	if build.current == sid:
		if build.waiting:
			return play_puzzle()
		return _work(sid)
	var miss := build.missing(sid)
	if not miss.is_empty():
		var got := bring(sid)
		miss = build.missing(sid)
		if not miss.is_empty():
			return ("Brought some of the parts; still needed: %s." if got > 0 else "Not all the parts are here; needed: %s.") % _short(miss)
		return "All the parts for this are here. Pick it again to begin."
	var why := build.can_start(sid)
	match String(why.reason):
		"unknown":
			return "You do not know how to do this yet. Ask someone who does."
		"tool":
			return "You need a tool for it: %s." % _tool_names(s)
		"busy":
			return "Finish the stage you are on first."
	if not build.start(sid):
		return "It cannot be started."
	refresh()
	return _work(sid)


func _short(miss: Dictionary) -> String:
	var bits: Array[String] = []
	for k: String in miss:
		bits.append("%d more %s" % [int(miss[k]), InventoryState.name_of(k).to_lower()])
	return ", ".join(bits)


## Brings the parts a stage needs from the pack to the stand: how many were brought.
func bring(sid: String) -> int:
	var pl := _pl()
	if pl == null:
		return 0
	var n := 0
	var miss := build.missing(sid)
	for k: String in miss:
		var take := TreeHarvest.pack_take(pl, k, int(miss[k]))
		if take > 0:
			build.deliver(k, take)
			n += take
	return n


## Works the current stage: kneels at the stand while the bar fills; moving stops it and what was done stays.
func _work(sid: String) -> String:
	var left := maxf(build.work_min(sid) - build.progress, 0.0)
	_min_left = left
	_secs = clampf(build.work_min(sid) / 10.0, 5.0, 20.0) * left / maxf(build.work_min(sid), 1.0)
	_secs = maxf(_secs, 2.0)
	_t0 = Time.get_ticks_msec()
	var b := bridge()
	if instant_work or b == null or b.work == null:
		return _worked(left)
	var text := "%s" % String(build.stage(sid).name)
	if not b.work.begin(global_position, "low", text, _secs, "", _on_work_end):
		return "You cannot work at it now."
	return ""


func _on_work_end(done: bool) -> void:
	var mins := _min_left
	if not done:
		var el := float(Time.get_ticks_msec() - _t0) / 1000.0
		mins = _min_left * clampf(el / maxf(_secs, 0.1), 0.0, 1.0)
	last = _worked(mins)
	refresh()
	var p := get_tree().get_first_node_in_group(&"player")
	if last != "":
		open_menu(p)


## `mins` of work done on the current stage: what to say.
func _worked(mins: float) -> String:
	var name := String(build.stage(build.current).name)
	var r := build.work(mins, 1.0, skill01())
	refresh()
	match r:
		"done":
			return "%s: done, %s work." % [name, build.grade_word(build.grade_of(_last_done()))]
		"puzzle":
			return "%s: the work is done, it wants fitting well." % name
	return "%s: %d%% done." % [name, roundi(100.0 * build.progress / maxf(build.work_min(), 1.0))]


func _last_done() -> String:
	var best := ""
	for s: Dictionary in build.stages():
		if build.done.has(String(s.id)):
			best = String(s.id)
	return best


## The puzzle of the current stage (BarkFit, PitchSpread on their screens; a builder who knows the technique is shown the band). The
## screen ends with the score; giving up leaves the stage waiting. Where there is no screen (tests, headless) it is played for the
## builder: a score from their skill, a little luck either way. Returns what to tell ("" while the screen is up).
func play_puzzle() -> String:
	var pid := build.puzzle_id()
	if pid == "":
		return ""
	if instant_work or DisplayServer.get_name() == "headless":
		var score := clampf(0.5 + 0.4 * skill01() + randf_range(-0.12, 0.12), 0.0, 1.0)
		return _puzzle_done(score)
	var guided := build.knowledge(build.current) in ["known", "practised", "mastered"]
	var lumps := float((build.stage(build.current).get("needs", {}) as Dictionary).get("pine_pitch", 3))
	var scr := BoatPuzzleScreen.open(get_tree(), pid, guided, {"lumps": lumps, "hull": build.plan.get("hull", {})})
	scr.finished.connect(func(score: float) -> void:
		last = _puzzle_done(score)
		refresh()
		open_menu(_pl()))
	return ""


func _puzzle_done(score: float) -> String:
	if build.current == "":
		return ""
	var name := String(build.stage(build.current).name)
	if score < 0.0:
		return "You leave %s for now: the work is done and waits to be fitted." % name.to_lower()
	var g := build.finish(score, skill01())
	refresh()
	return "%s: %s work." % [name, build.grade_word(g)]


# ---------------------------------------------------------------- launch
## The finished boat put on the water nearest the stand: the Boat with the grades' numbers. Null when there is no water in reach.
func launch() -> Boat:
	if not build.is_complete():
		return null
	var here := global_position
	var best := Vector3.INF
	var bd := INF
	var r := 2.0
	while r <= LAUNCH_SEARCH_M:
		for k in 24:
			var a := TAU * float(k) / 24.0
			var q := here + Vector3(sin(a), 0.0, cos(a)) * r
			if WaterSurface.depth_at(q.x, q.z) >= 0.6 and r < bd:
				best = q
				bd = r
		if best != Vector3.INF:
			break
		r += 2.0
	if best == Vector3.INF:
		return null
	var b := Boat.make(boat_id, best, atan2(here.x - best.x, here.z - best.z) + PI * 0.5)
	b.grade = build.stats()
	get_tree().current_scene.add_child(b)
	# the stand is bare again for the next
	build = BoatBuild.make(boat_id)
	build.know = _know
	build.has_tool = _has_tool
	refresh()
	return b


func to_dict() -> Dictionary:
	return build.to_dict()


func load_dict(d: Dictionary) -> void:
	build = BoatBuild.from_dict(d)
	build.know = _know
	build.has_tool = _has_tool
	refresh()
