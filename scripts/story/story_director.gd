class_name StoryDirector
extends Node
## The story (user 2026-10-01: "lets create a main story", "like the GTA of this", "all text"; docs/main_story.md):
## a storyline (data/story/storylines/<name>.json) is a run of missions (data/story/missions/<name>.json). The director
## runs the one mission at hand: its intro cards, then its steps one by one (world checks, StoryObjectives), then its
## outro cards and its effect, then the next. Everything else in the game goes on around it: the sandbox comes first, a
## mission never locks survival, building or hunting. StoryHUD shows the cards, the mission and its step, the marker
## and the mission's key hints (the first-time tutorial).
##
## The flow (the missions file's `_flow`): a mission waits until its `when` holds (flags, a date window, the hour, the
## year, standing, missions done and how they ended: StoryObjectives.holds), or goes to its `else`. As it starts the
## director keeps a checkpoint (where the player stands and the flags; the save keeps it) and does its `start_effects`.
## A step or the whole mission can fail (`fail`: death, seen, someone dies, out of time; and the kinds that fail of
## themselves: the one escorted dead, the guide lost): a card says why and the mission begins again from its checkpoint
## (no intro; what its effects put in the world goes first, with what its fighters dropped; what its deliveries took is
## given back; the player off a horse or a climb and back where it began). How a step ended (a talk's answer, "caught",
## "unseen", a fail rule's `outcome`) is the mission's outcome, and a step's or mission's `next` (a step or mission id, or
## a map of outcomes and "flag:<name>" to ids) picks where the story goes; a mission's own fail rule with an outcome ends
## the whole mission that way. A talk's answer that starts a mission (StoryDialogue) is a branch there too. Effects are
## data (StoryEffects): flags, things given and taken, standing, squads, fire, captivity, the sky; a gift, a taking or
## standing is done once a mission (a retry does not repeat it), and a save keeps how many of each squad are still alive
## (a load puts only those back). The checkpoint is saved as the mission begins (an autosave). In a shared world (co-op)
## the cards do not stop the game (the player only stands while one is up).
##
## Started by the main menu's New game (MainMenu.story_id) or the user arg story=<name> (tools, tests); a save keeps
## its place (SaveParts.save_story / load_story). With no storyline the director sits idle. As a storyline begins or loads
## StorySlice puts its world layer on and the player's Sway caster in, and puts the slice's stages back after a load.

const GROUP := &"story_director"
const STORY_DIR := "res://data/story/"
const CHECK_S := 0.5

enum Phase { IDLE, INTRO, STEPS, OUTRO, DONE, WAITING, FAILED }

## The storyline a new game starts (set by the main menu, taken once by the level; "" none).
static var incoming := ""
## Where storylines and missions are read from (tests point it at their own).
static var dir := STORY_DIR

var storyline_id := ""
var line := {}                 ## the storyline file
var missions: Array = []       ## the missions file's list
var mission_i := 0
var step_i := 0
var phase := Phase.IDLE
var base := {}                 ## the step's begin() record
var last := {}                 ## the step's last check()
var hud: StoryHUD
## What the story has done to the world for good, kept in the save (wonder: the sky has opened), and what the player
## has chosen and done (set_flag effects, dialogue answers).
var flags := {}
## The missions done (ids) and how each ended (id -> outcome), kept in the save.
var done_missions: Array = []
var outcomes := {}
## How the mission at hand has gone so far (the last step's outcome; its `next` maps read it).
var outcome := ""
## Where the mission at hand began: {mission, at [x, y, z], yaw, flags}. A retry goes back to it; the save keeps it.
var checkpoint := {}
var step_t := 0.0              ## seconds into the step (its timers: defend, stay_unseen, a time-out)
var mission_t := 0.0           ## seconds into the mission's steps
var fail_why := ""
## What the mission's effects put in the world (a squad): gone again on a retry.
var spawned: Array = []
## The same by the effect that made it ("start:0", "s2:1": StoryEffects.run's keys): {e: the effect, nodes}. A save keeps
## how many of each are alive (and its waves left), and a load spawns only those again.
var _squads := {}
var _pending := ""             ## a mission an answer of the open talk started: where the talk's close goes (_take_pending)
var _mfail := {}               ## the mission's fail rules' record (who is watched)
var _talking := false          ## the step's conversation is open
var _fail_shown := false
var _serial := 0               ## steps begun (a conversation that closes late, for a step gone by, is not heard)
var _branch := ""              ## a step's `next` naming a mission: where the story goes after this one
var _next_i := 0               ## the mission after the one whose outro is up
## Cards shown before the next mission's intro (a start effect's title card: StorySlice), taken as it shows them.
var lead_cards: Array = []
var _t := 0.0


static func find(tree: SceneTree) -> StoryDirector:
	return tree.get_first_node_in_group(GROUP) as StoryDirector if tree else null


## The storyline a new game of this launch starts ("" none): the menu's choice, else the user arg story=<name>.
static func incoming_name() -> String:
	if incoming != "":
		return incoming
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("story="):
			var v := s.get_slice("=", 1)
			return "" if v == "off" else v
	return ""


## A test jump (user 2026-10-03: "let me play it"): the user arg story_at=<mission id or its short name, e.g. two_fires> starts
## a new game's storyline at that mission, on its date and hour, with the world set as it would be (StorySlice.JUMPS,
## StorySlice.jump_setup). "" without it.
static func jump_at() -> String:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("story_at="):
			var v := s.get_slice("=", 1)
			return v if v.begins_with("m.") else "m.tf." + v
	return ""


static func load_json(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


## The survival core's new-game options of the incoming storyline ({} none): its year, day and hour.
static func start_opts() -> Dictionary:
	var name := incoming_name()
	if name == "":
		return {}
	var st: Dictionary = load_json(dir + "storylines/%s.json" % name).get("start", {})
	if jump_at() != "" and StorySlice.JUMPS.has(jump_at()):
		st = (StorySlice.JUMPS[jump_at()] as Dictionary).merged(st)     # (a test jump: that mission's date and hour)
	var o := {}
	if st.has("year"):
		o["start_year"] = int(st.year)
	if st.has("day"):
		o["start_day"] = String(st.day)
	if st.has("hour"):
		o["start_hour"] = float(st.hour)
	return o


## A shared world (co-op: NetSession at /root/Net in a session): the story's cards do not stop the game.
static func shared_world(tree: SceneTree) -> bool:
	var n := tree.root.get_node_or_null("Net") as NetSession if tree else null
	return n != null and n.in_session()


## Whether `when` (a mission's `when` form: StoryObjectives.holds) holds for the story at hand (dialogue answers ask).
static func condition(tree: SceneTree, when: Variant) -> bool:
	var d := find(tree)
	return d.holds(when) if d else StoryObjectives.holds(when, tree, {})


## The level adds the director (and its HUD) once the player and the survival rules are in.
static func install(level: Node, _player: FrontierPlayer) -> StoryDirector:
	var d := StoryDirector.new()
	d.name = "Story"
	level.add_child(d)
	var name := incoming_name()
	incoming = ""
	if name != "":
		d.hud._creator_grace = 1.0                 # (a new game's character creator opens a few frames in: the cards wait for it)
		d.begin_storyline.call_deferred(name)      # (a save loading over it puts its own place back: load_data)
	return d


func _ready() -> void:
	add_to_group(GROUP)
	hud = StoryHUD.new()
	hud.name = "StoryHUD"
	add_child(hud)


func begin_storyline(name: String, at_mission := 0) -> void:
	if storyline_id != "":
		return                                     # (a save's storyline came in first)
	line = load_json(dir + "storylines/%s.json" % name)
	missions = load_json(dir + "missions/%s.json" % name).get("missions", [])
	if line.is_empty() or missions.is_empty():
		push_error("Story: no storyline %s" % name)
		return
	storyline_id = name
	StorySlice.storyline_began(self)               # (the storyline's world layer, the Sway caster)
	_place_contacts()
	var jump := jump_at()
	if jump != "" and _mission_index(jump) >= 0:
		at_mission = _mission_index(jump)
		StorySlice.jump_setup.call_deferred(self, jump)   # (the world as that mission finds it: the camp, the bonds)
	_start_mission(at_mission)


func active() -> bool:
	return storyline_id != "" and phase != Phase.IDLE


func mission() -> Dictionary:
	return missions[mission_i] if mission_i >= 0 and mission_i < missions.size() else {}


func step() -> Dictionary:
	var steps: Array = mission().get("steps", [])
	return steps[step_i] if step_i >= 0 and step_i < steps.size() else {}


func places() -> Dictionary:
	return line.get("places", {})


func set_flag(key: String, value: Variant = true) -> void:
	if key == "":
		return
	if value == null:
		flags.erase(key)
	else:
		flags[key] = value


func flag(key: String) -> Variant:
	return flags.get(key)


## Whether a condition of the `when` form holds now (flags, missions done, the date, standing).
func holds(when: Variant) -> bool:
	return StoryObjectives.holds(when, get_tree(), {"flags": flags, "done": done_missions, "outcomes": outcomes})


## Does a list of effects ({do: ...}: StoryEffects) now; `scope` is where the list is in the mission ("start", "s2",
## "e2", ...: the once-only ones are kept by it).
func run_effects(list: Variant, mode := "", scope := "") -> void:
	StoryEffects.run(self, list, mode, scope)


## Whether the once-only effect at `key` ("e2:0") was done in this mission already (StoryEffects.ONCE: a retry, or a
## step played again, does not do it twice). Kept in the checkpoint, so the save keeps it.
func once_done(key: String) -> bool:
	return _cp_part("once").has(key)


func mark_once(key: String) -> void:
	_cp_part("once")[key] = true


## A record of the mission at hand kept in its checkpoint (`name`'s dictionary, made when missing).
func _cp_part(name: String) -> Dictionary:
	if int(checkpoint.get("mission", -1)) != mission_i:
		checkpoint = {"mission": mission_i, "flags": flags.duplicate(true)}      # (no place: a retry leaves the player be)
	if not (checkpoint.get(name) is Dictionary):
		checkpoint[name] = {}
	return checkpoint[name]


## What an effect made (a node, or a list of them) is the mission's: gone again on a retry. `key` and `e` (the effect)
## let a save keep it (_squads).
func keep_spawned(v: Variant, key := "", e := {}) -> void:
	var nodes := []
	if v is Node:
		nodes.append(v)
	elif v is Array:
		for n in v:
			if n is Node:
				nodes.append(n)
	spawned.append_array(nodes)
	if key != "" and not nodes.is_empty():
		_squads[key] = {"e": e.duplicate(true), "nodes": nodes}


## Starts the mission `id` now (a dialogue's answer; StoryDialogue.start_mission). During a talk step's conversation
## (StoryDialogue starts an answer's missions just before it hands the answer back) it is a branch: the talk's close
## ends the mission at hand with the answer as its outcome and goes there (_take_pending). Otherwise the one at hand is
## left as it is, and what its effects made stays in the world (the fight goes on).
func start_mission_id(id: String) -> void:
	var i := _mission_index(id)
	if i < 0:
		push_warning("Story: no mission %s" % id)
		return
	if _talking and phase == Phase.STEPS:
		_pending = id
		_take_pending_later.call_deferred(_serial)    # (should the talk's close not come)
		return
	if hud.cards_open():
		hud.clear_cards()
	_start_mission(i)


func _start_mission(i: int, hops := 0) -> void:
	mission_i = i
	step_i = 0
	last = {}
	outcome = ""
	_branch = ""
	_pending = ""
	_talking = false
	spawned = []
	_squads = {}
	if i < 0 or i >= missions.size():
		phase = Phase.DONE
		_refresh_hud()
		return
	var m := mission()
	if not _when_ok(m):
		var alt := _mission_index(String(m.get("else", "")))
		if alt >= 0 and hops < missions.size():
			_start_mission(alt, hops + 1)
			return
		phase = Phase.WAITING                      # (the sandbox goes on; the check looks again)
		_refresh_hud()
		return
	_keep_checkpoint()
	run_effects(m.get("start_effects", []), "", "start")
	var sg := SaveGame.find(get_tree())
	if sg != null and not sg.loading:
		sg.save_soon("auto")                       # (the checkpoint on disk as the mission begins, as the death rule saves)
	var cards: Array = lead_cards + (m.get("intro", []) as Array)
	lead_cards = []
	if cards.is_empty():
		_begin_steps()
	else:
		phase = Phase.INTRO
		_refresh_hud()
		hud.show_cards(cards, _begin_steps)


func _when_ok(m: Dictionary) -> bool:
	return holds(m.get("when", {}))


func _begin_steps(mode := "") -> void:
	phase = Phase.STEPS
	step_i = 0
	mission_t = 0.0
	_mfail = {}
	_begin_step(mode)
	var m := mission()
	if m.has("title"):
		hud.banner(String(m.title))


## The step at step_i begins: its record of the world, its start effects (not on a load: load_data puts back what
## they made).
func _begin_step(mode := "") -> void:
	_serial += 1
	_talking = false
	step_t = 0.0
	last = {}
	base = StoryObjectives.begin(step(), get_tree())
	if mode != "load":
		run_effects(step().get("start_effects", []), mode, "s%d" % step_i)
	_refresh_hud()


func _process(delta: float) -> void:
	match phase:
		Phase.STEPS:
			step_t += delta
			mission_t += delta
		Phase.WAITING, Phase.FAILED:
			pass
		_:
			return
	_t -= delta
	if _t > 0.0:
		return
	_t = CHECK_S
	if phase == Phase.WAITING:
		if _when_ok(mission()):
			_start_mission(mission_i)
		return
	if phase == Phase.FAILED:
		_show_fail()
		return
	var s := step()
	if s.is_empty():
		_finish_mission()
		return
	if _talking:
		return                                     # (the conversation is open: its close goes on)
	base["elapsed"] = step_t
	last = StoryObjectives.check(s, base, get_tree(), places())
	var f := _fail_check(s)
	if not f.is_empty():
		var fo := String(f.get("outcome", ""))
		if fo == "":
			_fail(String(f.get("why", "")))
		elif bool(f.get("mission", false)):
			outcome = fo                           # (the mission's own rule, a branch: the whole mission ends that way)
			_finish_mission()
		else:
			_step_done(fo, false)                  # (the step's, a branch: the step ends that way, not passed)
		return
	if bool(last.get("done", false)):
		_step_done(String(last.get("outcome", "")))
		return
	if String(s.get("kind", "")) == "talk" and bool(last.get("ready", false)):
		_talk(s)
	_refresh_hud()


## {why, outcome, mission} of the step's failing now ({} none): its own check's, then its fail rules, then the
## mission's (`mission` true: a rule of the whole mission's).
func _fail_check(s: Dictionary) -> Dictionary:
	if bool(last.get("failed", false)):
		return {"why": String(last.get("why", "")), "outcome": String(s.get("fail_outcome", ""))}
	var f := StoryObjectives.failed(s.get("fail", []), base, step_t, get_tree())
	if f.is_empty():
		f = StoryObjectives.failed(mission().get("fail", []), _mfail, mission_t, get_tree())
		if not f.is_empty():
			f["mission"] = true
	return f


## The step is over (`out`: how): passed, its delivery handed over and its `effects`; ended by a fail that is a branch
## (`passed` false), its `fail_effects`. Then its `next` (a step or a mission), else the step after it.
func _step_done(out: String, passed := true) -> void:
	var s := step()
	if out != "":
		outcome = out
	if passed:
		var n := StoryObjectives.complete(s, get_tree())
		if n > 0:
			var handed := _cp_part("handed")       # (given back if the mission fails: its retry asks for them again)
			var kind := String(s.get("item", ""))
			handed[kind] = int(handed.get(kind, 0)) + n
		run_effects(s.get("effects", []), "", "e%d" % step_i)
	else:
		run_effects(s.get("fail_effects", []), "", "f%d" % step_i)
	var nx := _pick_next(s.get("next"))
	if nx != "":
		var si := _step_index(nx)
		if si >= 0:
			step_i = si
			_begin_step()
			return
		if _mission_index(nx) >= 0:
			_branch = nx
			_finish_mission()
			return
		push_warning("Story: no step or mission %s" % nx)
	step_i += 1
	if step_i >= (mission().get("steps", []) as Array).size():
		_finish_mission()
		return
	_begin_step()


func _finish_mission() -> void:
	var m := mission()
	phase = Phase.OUTRO
	var id := String(m.get("id", ""))
	if id != "":
		if not done_missions.has(id):
			done_missions.append(id)
		outcomes[id] = outcome
	_refresh_hud()
	var effect := String(m.get("effect", ""))
	if effect != "":
		_effect(effect)
	run_effects(m.get("effects", []), "", "end")
	if m.get("effects_by") is Dictionary and outcome != "":
		run_effects((m.effects_by as Dictionary).get(outcome, []), "", "end_" + outcome)     # (as it ended: outro_by's kin)
	_next_i = mission_i + 1
	var nx := _branch if _branch != "" else _pick_next(m.get("next"))
	_branch = ""
	if nx != "":
		var j := _mission_index(nx)
		if j >= 0:
			_next_i = j
		else:
			push_warning("Story: no mission %s" % nx)
	spawned = []                                   # (the mission is done: what it made stays in the world)
	_squads = {}
	var by: Variant = (m.get("outro_by", {}) as Dictionary).get(outcome) if m.get("outro_by") is Dictionary else null
	var cards: Array = by if by is Array else m.get("outro", [])
	var to := _next_i
	var next := func() -> void: _start_mission(to)
	if cards.is_empty():
		next.call()
	else:
		hud.show_cards(cards, next)


## `next` as data: a step or mission id, or a map whose first key that holds wins (an outcome of the mission at hand,
## or "flag:<name>" for a flag set), "_" or "default" when none does; "" for none.
func _pick_next(nx: Variant) -> String:
	if nx is String or nx is StringName:
		return String(nx)
	if nx is Dictionary:
		for k in nx:
			var key := String(k)
			if key.begins_with("flag:"):
				if StoryObjectives.truthy(flags.get(key.substr(5))):
					return String(nx[k])
			elif outcome != "" and key == outcome:
				return String(nx[k])
		return String(nx.get("_", nx.get("default", "")))
	return ""


func _mission_index(id: String) -> int:
	if id == "":
		return -1
	for i in missions.size():
		if String((missions[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


func _step_index(id: String) -> int:
	var steps: Array = mission().get("steps", [])
	for i in steps.size():
		if String((steps[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


# --- Talk ----------------------------------------------------------------------------------------------------

## The storyline's people to talk to (its file's "contacts": StoryContact.spawn_for, called by name as StoryDialogue
## is; each once, those already there left), put in the world as the storyline begins or a save brings it back.
func _place_contacts() -> void:
	var sc := StoryEffects.global_script("StoryContact")
	if sc != null and sc.has_method("spawn_for"):
		sc.call("spawn_for", get_tree(), storyline_id)


## The talk step's conversation opens (StoryDialogue.open, called by name: it is built alongside); its close passes
## the step, its answer the step's outcome, its flags the story's.
func _talk(s: Dictionary) -> void:
	_talking = true
	var serial := _serial
	var convo := String(s.get("convo", ""))
	var done := func(result: Variant = null) -> void: _talk_done(serial, result)
	var sd := StoryEffects.global_script("StoryDialogue")
	if sd != null and sd.has_method("open"):
		sd.call("open", get_tree(), convo, done)
	else:
		push_warning("Story: no StoryDialogue for %s; the talk is passed" % convo)
		done.call({})


func _talk_done(serial: int, result: Variant) -> void:
	if serial != _serial or phase != Phase.STEPS:
		return
	_talking = false
	var choice := ""
	if result is Dictionary:
		var r: Dictionary = result
		var fl: Variant = r.get("flags")
		if fl is Dictionary:
			for k in fl:
				set_flag(String(k), fl[k])
		choice = String(r.get("choice", r.get("outcome", "")))
		run_effects(r.get("effects", []), "", "t%d" % step_i)
	elif result != null:
		choice = str(result)
	# the step's own answers as data: {"<answer>": {flags, effects, outcome}}
	var by: Variant = (step().get("choices", {}) as Dictionary).get(choice) if step().get("choices") is Dictionary else null
	if by is Dictionary:
		var fl: Variant = by.get("flags")
		if fl is Dictionary:
			for k in fl:
				set_flag(String(k), fl[k])
		run_effects(by.get("effects", []), "", "c%d:%s" % [step_i, choice])
		choice = String(by.get("outcome", choice))
	base["talked"] = true
	base["choice"] = choice
	_t = 0.0
	if _pending != "":
		_take_pending()


## The mission an answer of the talk started (start_mission_id while it was open): the mission at hand ends with the
## answer as its outcome (kept with the missions done) and the story goes there, as a `next` naming it would.
func _take_pending() -> void:
	var to := _pending
	_pending = ""
	if to == "" or phase != Phase.STEPS:
		return
	_talking = false
	if String(base.get("choice", "")) != "":
		outcome = String(base.choice)
	_branch = to
	_finish_mission()


func _take_pending_later(serial: int) -> void:
	if serial == _serial and _pending != "":
		_take_pending()


# --- Fail and retry --------------------------------------------------------------------------------------------

func _fail(why: String) -> void:
	phase = Phase.FAILED
	fail_why = why
	_fail_shown = false
	_talking = false
	_pending = ""
	_t = 0.0
	_hand_back()
	_refresh_hud()


## What the mission's deliveries took, given back as it fails (its retry asks for them again; a save made meanwhile
## keeps them in the pack, as the retry it loads into wants).
func _hand_back() -> void:
	if int(checkpoint.get("mission", -1)) != mission_i:
		return
	var handed: Variant = checkpoint.get("handed")
	checkpoint.erase("handed")
	if handed is Dictionary:
		for kind in handed:
			StoryEffects.give(get_tree(), String(kind), int(handed[kind]))


## The fail card, once the player is up again (a death: the death rule brings them back first).
func _show_fail() -> void:
	if _fail_shown:
		return
	var p := StoryObjectives.player(get_tree())
	if p != null and p.is_dead:
		return
	_fail_shown = true
	var title := String(mission().get("title", "The mission"))
	var text := (fail_why + "\n\n" if fail_why != "" else "") + "%s begins again from where it began." % title
	hud.show_cards([{"title": "Mission failed", "text": text}], _retry)


## Back to the mission's checkpoint: the flags as they were, what its effects made gone (out of the world at once, so
## the steps begun below do not count them; with what its fighters dropped), the player where it began, its start
## effects again (not the once-only ones done already), its first step.
func _retry() -> void:
	if phase != Phase.FAILED:
		return
	if int(checkpoint.get("mission", -1)) == mission_i:
		flags = (checkpoint.get("flags", flags) as Dictionary).duplicate(true)
	_free_loot_of(spawned)
	for n in spawned:
		if is_instance_valid(n) and not (n as Node).is_queued_for_deletion():
			var par := (n as Node).get_parent()
			if par != null:
				par.remove_child(n)            # (out of its groups now: a kill begun below must not hold it alive)
			(n as Node).queue_free()
	spawned = []
	_squads = {}
	var p := StoryObjectives.player(get_tree())
	var at: Variant = _checkpoint_point()
	if p != null and at != null and not p.is_dead:
		_free_player(p)
		p.global_position = at
		p.velocity = Vector3.ZERO
		if checkpoint.has("yaw"):
			p.yaw = float(checkpoint.yaw)
			p.rotation.y = p.yaw
	outcome = ""
	_branch = ""
	run_effects(mission().get("start_effects", []), "", "start")
	lead_cards = []                                # (a retry has no cards: its title card is not shown again)
	_begin_steps()


## The player's own body again before a retry moves it: off the horse (the saddle would take them back), off a grip,
## off a boat.
func _free_player(p: FrontierPlayer) -> void:
	if p.riding != null:
		p.dismount()
	if p.climbing != null:
		if p.grip != null and p.grip.has_method("_let_go"):
			p.grip.call("_let_go", 0.0, "story")
		else:
			p.end_climb()
	if p.aboard != null and is_instance_valid(p.aboard) and p.aboard.has_method("leave"):
		p.aboard.call("leave")


## What the mission's fighters left (NpcLoot, read by name): the pack where one fell (its `loot`) and the weapon one laid
## at its feet, gone with them on a retry (the squad made again carries its own: no muskets to be had by failing).
func _free_loot_of(nodes: Array) -> void:
	var people: Array[Node3D] = []
	for n in nodes:
		if not is_instance_valid(n):
			continue
		var them: Array = [n]
		them.append_array((n as Node).get_children())      # (a squad: its fighters are its children)
		for m in them:
			if m is Node3D:
				people.append(m)
				var l: Variant = StoryObjectives._prop(m, "loot")
				if l is Node and is_instance_valid(l):
					(l as Node).queue_free()
	var scene := get_tree().current_scene
	if people.is_empty() or scene == null:
		return
	for c in scene.get_children():
		if not (c is Node3D) or not StoryEffects._is_a(c, "NpcLoot"):
			continue
		for m in people:
			if (c as Node3D).global_position.distance_to(m.global_position) < 1.5:
				c.queue_free()
				break


func _keep_checkpoint() -> void:
	checkpoint = {"mission": mission_i, "flags": flags.duplicate(true)}
	var p := StoryObjectives.player(get_tree())
	if p != null:
		checkpoint["at"] = [p.global_position.x, p.global_position.y, p.global_position.z]
		checkpoint["yaw"] = p.yaw


## Where a retry puts the player: the mission's `checkpoint` place, else where they stood as it began (null: unmoved).
func _checkpoint_point() -> Variant:
	var at: Variant = StoryObjectives.place_point({"place": String(mission().get("checkpoint", ""))}, places())
	if at != null:
		return (at as Vector3) + Vector3(0, 0.1, 0)
	var a: Array = checkpoint.get("at", [])
	if a.size() == 3 and int(checkpoint.get("mission", -1)) == mission_i:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return null


# --- Effects -------------------------------------------------------------------------------------------------

## A mission's effect on the world as it ends.
func _effect(id: String) -> void:
	match id:
		"raid_night":
			_raid_night()
		"wonder_reveal":
			# the turn of the story: the wonder breaks into the frontier and the sky opens (the giant, its moons, the
			# etherium: WonderLook), for good
			flags["wonder"] = true
			var rig := _rig()
			if rig:
				rig.reveal_wonder(20.0)


func _rig() -> EnvironmentRig:
	var scene := get_tree().current_scene if get_tree() else null
	return scene.get_node_or_null("EnvironmentRig") as EnvironmentRig if scene else null


## The raid on German Flatts heard from the homestead: shots far off toward the fort, then many (the cards tell the
## rest; the raid as a played night comes with the raiders' bodies and Part 1).
func _raid_night() -> void:
	var xz: Array = places().get("flatts_fort", [0.0, 0.0])
	var at := Vector3(float(xz[0]), FrontierTerrain.height_at(float(xz[0]), float(xz[1])) + 2.0, float(xz[1]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1757
	var t := 0.4
	for i in 26:
		var off := Vector3(rng.randf_range(-60.0, 60.0), 0.0, rng.randf_range(-60.0, 60.0))
		Sfx.play_3d(&"musket_shot", at + off, rng.randf_range(-6.0, 0.0), rng.randf_range(0.92, 1.05), {"delay": t})
		t += rng.randf_range(0.15, 1.6) if i > 3 else rng.randf_range(1.5, 3.0)


func _refresh_hud() -> void:
	if hud == null:
		return
	var m := mission()
	var title := ""
	var text := ""
	var count := ""
	var hints: Array = []
	match phase:
		Phase.STEPS:
			title = String(m.get("title", ""))
			var s := step()
			text = String(s.get("text", ""))
			if last.has("count_text"):
				count = String(last.count_text)
			elif last.has("need") and int(last.need) > 1:
				count = "%d / %d" % [int(last.get("have", 0)), int(last.need)]
			if String(s.get("kind", "")) == "wait_for" and not bool(last.get("window_ok", false)) and m.has("waiting"):
				text = String(m.waiting)
			hints = m.get("hints", [])
		Phase.WAITING:
			if m.has("waiting"):                   # (a mission waiting on its `when` shows only what it says)
				title = String(m.get("title", ""))
				text = String(m.waiting)
		Phase.FAILED:
			title = String(m.get("title", ""))
			text = "Failed: %s" % fail_why if fail_why != "" else "Failed"
		Phase.DONE:
			var parts: Array = line.get("parts", [])
			for p: Dictionary in parts:
				if (p.get("missions", []) as Array).is_empty():
					title = String(p.get("name", ""))
					text = "Coming: %s" % String(p.get("status", "not written yet"))
					break
	hud.set_mission(title, text, count, hints)
	hud.marker_at = last.get("at") if phase == Phase.STEPS else null
	if hud.marker_at == null and phase == Phase.STEPS:
		hud.marker_at = StoryObjectives.place_point(step(), places())
	if phase == Phase.STEPS and step().get("marker", true) == false:
		hud.marker_at = null                       # (a step that keeps its place to itself: an ambush)
	hud.marker_dist = float(last.get("dist", -1.0))
	if is_inf(hud.marker_dist):
		hud.marker_dist = -1.0


# --- Save ----------------------------------------------------------------------------------------------------

func save_data() -> Dictionary:
	if storyline_id == "":
		return {}
	# a mission caught on its cards saves as its start (intro) or as done (outro): the cards play again or not at all;
	# one failed saves as its first step, with the flags it began with
	var mi := mission_i
	var ph := "start"
	var si := 0
	var fl := flags
	match phase:
		Phase.OUTRO:
			mi = _next_i
		Phase.STEPS:
			ph = "steps"
			si = step_i
		Phase.FAILED:
			ph = "steps"
			fl = checkpoint.get("flags", flags) if int(checkpoint.get("mission", -1)) == mission_i else flags
	var out := {"storyline": storyline_id, "mission": mi, "step": si, "phase": ph, "flags": fl.duplicate(true),
			"done": done_missions.duplicate(), "outcomes": outcomes.duplicate(),
			"outcome": outcome if phase == Phase.STEPS else "", "checkpoint": checkpoint.duplicate(true)}
	if phase == Phase.STEPS:
		out["squads"] = _squads_left()     # (a failed one has none: it loads as its retry, its squads made new)
		out["have"] = int(last.get("have", 0))    # (the step's count so far: begin() after the load counts from then)
	return out


## The mission's squads as a save keeps them: {key: {e: the effect, alive, waves}} for each with someone still alive
## (NpcSquad.alive_count(), else a node not dead) or a wave still to come.
func _squads_left() -> Dictionary:
	var out := {}
	for key: String in _squads:
		var alive := 0
		var waves := -1
		for n in (_squads[key] as Dictionary).get("nodes", []):
			if not is_instance_valid(n) or (n as Node).is_queued_for_deletion():
				continue
			if (n as Node).has_method("alive_count"):
				alive += int((n as Node).call("alive_count"))
			elif not StoryObjectives.is_dead(n):
				alive += 1
			var w: Variant = StoryObjectives._prop(n, "waves_left")
			if w is int or w is float:
				waves = maxi(waves, 0) + int(w)
		if alive > 0 or waves > 0:
			var r := {"e": ((_squads[key] as Dictionary).get("e", {}) as Dictionary).duplicate(true), "alive": alive}
			if waves >= 0:
				r["waves"] = waves
			out[key] = r
	return out


## The squads a save kept, made again as they were: as many as were alive (with the waves they had left), the next
## wave for one between waves; none for one all dead.
func _respawn(saved: Dictionary) -> void:
	for key in saved:
		var r: Variant = saved[key]
		if not (r is Dictionary) or not ((r as Dictionary).get("e") is Dictionary):
			continue
		var e: Dictionary = ((r as Dictionary).e as Dictionary).duplicate(true)
		var alive := int((r as Dictionary).get("alive", 0))
		var waves := int((r as Dictionary).get("waves", 0))
		if alive > 0:
			e["count"] = alive
			if (r as Dictionary).has("waves"):
				e["waves"] = waves
		elif waves > 0:
			e["waves"] = waves - 1
		else:
			continue
		StoryEffects.do_one(self, e, String(key))


func load_data(d: Dictionary) -> void:
	if d.is_empty() or String(d.get("storyline", "")) == "":
		return
	hud.clear_cards()
	line = load_json(dir + "storylines/%s.json" % String(d.storyline))
	missions = load_json(dir + "missions/%s.json" % String(d.storyline)).get("missions", [])
	storyline_id = String(d.storyline)
	StorySlice.storyline_began(self)               # (the world layer: its pieces came back with the building)
	flags = (d.get("flags", {}) as Dictionary).duplicate()
	done_missions = (d.get("done", []) as Array).duplicate()
	outcomes = (d.get("outcomes", {}) as Dictionary).duplicate()
	checkpoint = (d.get("checkpoint", {}) as Dictionary).duplicate(true)
	_place_contacts()
	if bool(flags.get("wonder", false)) and _rig():
		_rig().set_wonder(1.0)
	var mi := int(d.get("mission", 0))
	if String(d.get("phase", "")) == "steps" and mi < missions.size():
		mission_i = mi
		phase = Phase.STEPS
		step_i = clampi(int(d.get("step", 0)), 0, maxi(0, (mission().get("steps", []) as Array).size() - 1))
		outcome = String(d.get("outcome", ""))
		_branch = ""
		mission_t = 0.0
		_mfail = {}
		_pending = ""
		spawned = []
		_squads = {}
		# what the world does not keep (a squad): those the save says are alive, else (an older save, or one failed: its
		# retry) what the mission's and the step's start effects make
		if d.get("squads") is Dictionary:
			_respawn(d.squads)
		else:
			run_effects(mission().get("start_effects", []), "load", "start")
			run_effects(step().get("start_effects", []), "load", "s%d" % step_i)
		_begin_step("load")
		if int(d.get("have", 0)) > 0:
			base["carried"] = int(d.have)
	else:
		_start_mission(mi)
	(func() -> void: StorySlice.restore(self)).call_deferred()     # (once the whole save is in: the wreck, the camp)
