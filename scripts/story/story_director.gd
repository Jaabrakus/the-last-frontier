class_name StoryDirector
extends Node
## The story (user 2026-10-01: "lets create a main story", "like the GTA of this", "all text"; docs/main_story.md):
## a storyline (data/story/storylines/<name>.json) is a run of missions (data/story/missions/<name>.json). The director
## runs the one mission at hand: its intro cards, then its steps one by one (world checks, StoryObjectives), then its
## outro cards and its effect, then the next. Everything else in the game goes on around it: the sandbox comes first, a
## mission never locks survival, building or hunting. StoryHUD shows the cards, the mission and its step, the marker
## and the mission's key hints (the first-time tutorial).
##
## Started by the main menu's New game (MainMenu.story_id) or the user arg story=<name> (tools, tests); a save keeps
## its place (SaveParts.save_story / load_story). With no storyline the director sits idle.

const GROUP := &"story_director"
const STORY_DIR := "res://data/story/"
const CHECK_S := 0.5

enum Phase { IDLE, INTRO, STEPS, OUTRO, DONE }

## The storyline a new game starts (set by the main menu, taken once by the level; "" none).
static var incoming := ""

var storyline_id := ""
var line := {}                 ## the storyline file
var missions: Array = []       ## the missions file's list
var mission_i := 0
var step_i := 0
var phase := Phase.IDLE
var base := {}                 ## the step's begin() record
var last := {}                 ## the step's last check()
var hud: StoryHUD
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


static func load_json(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


## The survival core's new-game options of the incoming storyline ({} none): its year, day and hour.
static func start_opts() -> Dictionary:
	var name := incoming_name()
	if name == "":
		return {}
	var st: Dictionary = load_json(STORY_DIR + "storylines/%s.json" % name).get("start", {})
	var o := {}
	if st.has("year"):
		o["start_year"] = int(st.year)
	if st.has("day"):
		o["start_day"] = String(st.day)
	if st.has("hour"):
		o["start_hour"] = float(st.hour)
	return o


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
	line = load_json(STORY_DIR + "storylines/%s.json" % name)
	missions = load_json(STORY_DIR + "missions/%s.json" % name).get("missions", [])
	if line.is_empty() or missions.is_empty():
		push_error("Story: no storyline %s" % name)
		return
	storyline_id = name
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


func _start_mission(i: int) -> void:
	mission_i = i
	step_i = 0
	last = {}
	if i >= missions.size():
		phase = Phase.DONE
		_refresh_hud()
		return
	var m := mission()
	var cards: Array = m.get("intro", [])
	if cards.is_empty():
		_begin_steps()
	else:
		phase = Phase.INTRO
		_refresh_hud()
		hud.show_cards(cards, _begin_steps)


func _begin_steps() -> void:
	phase = Phase.STEPS
	step_i = 0
	base = StoryObjectives.begin(step(), get_tree())
	_refresh_hud()
	var m := mission()
	if m.has("title"):
		hud.banner(String(m.title))


func _process(delta: float) -> void:
	if phase != Phase.STEPS:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = CHECK_S
	var s := step()
	if s.is_empty():
		_finish_mission()
		return
	last = StoryObjectives.check(s, base, get_tree(), places())
	if bool(last.get("done", false)):
		step_i += 1
		if step_i >= (mission().get("steps", []) as Array).size():
			_finish_mission()
			return
		base = StoryObjectives.begin(step(), get_tree())
		last = {}
	_refresh_hud()


func _finish_mission() -> void:
	var m := mission()
	phase = Phase.OUTRO
	_refresh_hud()
	var effect := String(m.get("effect", ""))
	if effect != "":
		_effect(effect)
	var cards: Array = m.get("outro", [])
	var next := func() -> void: _start_mission(mission_i + 1)
	if cards.is_empty():
		next.call()
	else:
		hud.show_cards(cards, next)


## A mission's effect on the world as it ends.
func _effect(id: String) -> void:
	match id:
		"raid_night":
			_raid_night()


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
			if last.has("need") and int(last.need) > 1:
				count = "%d / %d" % [int(last.get("have", 0)), int(last.need)]
			if String(s.get("kind", "")) == "wait_for" and not bool(last.get("window_ok", false)) and m.has("waiting"):
				text = String(m.waiting)
			hints = m.get("hints", [])
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
	hud.marker_dist = float(last.get("dist", -1.0))


# --- Save ----------------------------------------------------------------------------------------------------

func save_data() -> Dictionary:
	if storyline_id == "":
		return {}
	# a mission caught on its cards saves as its start (intro) or as done (outro): the cards play again or not at all
	var mi := mission_i
	if phase == Phase.OUTRO:
		mi += 1
	return {"storyline": storyline_id, "mission": mi, "step": step_i if phase == Phase.STEPS else 0,
			"phase": "steps" if phase == Phase.STEPS else "start"}


func load_data(d: Dictionary) -> void:
	if d.is_empty() or String(d.get("storyline", "")) == "":
		return
	hud.clear_cards()
	line = load_json(STORY_DIR + "storylines/%s.json" % String(d.storyline))
	missions = load_json(STORY_DIR + "missions/%s.json" % String(d.storyline)).get("missions", [])
	storyline_id = String(d.storyline)
	var mi := int(d.get("mission", 0))
	if String(d.get("phase", "")) == "steps" and mi < missions.size():
		mission_i = mi
		phase = Phase.STEPS
		step_i = clampi(int(d.get("step", 0)), 0, maxi(0, (mission().get("steps", []) as Array).size() - 1))
		base = StoryObjectives.begin(step(), get_tree())
		last = {}
		_refresh_hud()
	else:
		_start_mission(mi)
