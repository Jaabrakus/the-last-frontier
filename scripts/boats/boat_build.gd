class_name BoatBuild
extends RefCounted
## A boat being built on its stand, logic only (data/boats/plans.json; user 2026-09-29: "they bring materials to it and attach to it
## and they can see it grow", "we have the pieces but we need to do puzzles to complete it", "it takes engineering work on the user
## to research"). The stages go in the craft's own order. Parts are brought to the stand (deliver), a stage is started (its parts are
## attached: taken from the store), worked (game minutes) and finished with a GRADE 0..1: from the puzzle it plays (finish with its
## score), or, where it has none or a worker does it, from skill (worker_grade). A grade is capped by what the builder knows
## (SurvivalLearning: unknown cannot be done, heard of and seen are done clumsily); a stage done out of order is spoilt (its
## grade x out_of_order_mult, and the build remembers it). The grades become the boat's stats (stats()).
##   know    Callable (knowledge id) -> state ("unknown", "heard_of", "seen", "known", "practised", "mastered")
##   has_tool Callable (Array of item ids) -> bool (any of them; [] needs none)

const STATES := ["unknown", "heard_of", "seen", "known", "practised", "mastered"]

var plan_id := ""
var plan: Dictionary = {}
## Parts brought to the stand and not yet attached: item id -> count.
var store: Dictionary = {}
## The stages finished: stage id -> {grade, ordered (done in the craft's order)}.
var done: Dictionary = {}
## The stage being worked ("" none), the minutes of work in it, whether its work is done and it waits for its puzzle,
## whether it was begun out of order.
var current := ""
var progress := 0.0
var waiting := false
var current_ordered := true
var know := Callable()
var has_tool := Callable()


static func plans() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/boats/plans.json"))
	return d if d is Dictionary else {}


static func make(id: String) -> BoatBuild:
	var b := BoatBuild.new()
	b.plan_id = id
	b.plan = (plans().get(id, {}) as Dictionary)
	return b


func stages() -> Array:
	return plan.get("stages", [])


func stage(sid: String) -> Dictionary:
	for s: Dictionary in stages():
		if String(s.id) == sid:
			return s
	return {}


## The first stage not yet done: the craft's own next step ("" all done).
func next_id() -> String:
	for s: Dictionary in stages():
		if not done.has(String(s.id)):
			return String(s.id)
	return ""


func is_complete() -> bool:
	return next_id() == "" and not stages().is_empty()


func knowledge(sid: String) -> String:
	var s := stage(sid)
	return String(know.call(String(s.get("know", "")))) if know.is_valid() and not s.is_empty() else "known"


func deliver(item: String, n: int) -> void:
	if n > 0:
		store[item] = int(store.get(item, 0)) + n


## What the stage still lacks in the store: item id -> count.
func missing(sid: String) -> Dictionary:
	var out := {}
	var needs: Dictionary = stage(sid).get("needs", {})
	for k: String in needs:
		var short := int(needs[k]) - int(store.get(k, 0))
		if short > 0:
			out[k] = short
	return out


## Whether the stage can be started now: {ok, reason ("" ok; "done", "busy", "unknown", "parts", "tool")}.
func can_start(sid: String) -> Dictionary:
	var s := stage(sid)
	if s.is_empty() or done.has(sid):
		return {"ok": false, "reason": "done"}
	if current != "":
		return {"ok": false, "reason": "busy"}
	if knowledge(sid) == "unknown":
		return {"ok": false, "reason": "unknown"}
	if not missing(sid).is_empty():
		return {"ok": false, "reason": "parts"}
	var tools: Array = s.get("tool", [])
	if not tools.is_empty() and has_tool.is_valid() and not bool(has_tool.call(tools)):
		return {"ok": false, "reason": "tool"}
	return {"ok": true, "reason": ""}


## Attaches the stage's parts (out of the store) and begins the work. Out of the craft's order it can still be done, badly.
func start(sid: String) -> bool:
	if not bool(can_start(sid).ok):
		return false
	var needs: Dictionary = stage(sid).get("needs", {})
	for k: String in needs:
		store[k] = int(store.get(k, 0)) - int(needs[k])
	current = sid
	progress = 0.0
	waiting = false
	current_ordered = (sid == next_id())
	return true


func work_min(sid := "") -> float:
	return float(stage(sid if sid != "" else current).get("work_min", 60.0))


## `minutes` of work on the current stage (x `pace`, a worker's skill or a helper's hands). Returns "" while it goes on, "puzzle" when the
## work is done and the stage waits for its puzzle, "done" when it finished on its own (no puzzle: the grade from `skill`).
func work(minutes: float, pace := 1.0, skill := 0.5) -> String:
	if current == "" or waiting or minutes <= 0.0:
		return ""
	progress = minf(progress + minutes * maxf(pace, 0.0), work_min())
	if progress < work_min():
		return ""
	if String(stage(current).get("puzzle", "")) != "":
		waiting = true
		return "puzzle"
	finish(-1.0, skill)
	return "done"


func puzzle_id() -> String:
	return String(stage(current).get("puzzle", "")) if current != "" else ""


## The stage is finished with the puzzle's `score` 0..1 (-1: none played: a plain job from `skill` 0..1). Returns the grade.
func finish(score: float, skill := 0.5) -> float:
	if current == "":
		return 0.0
	var sid := current
	var base := clampf(score, 0.0, 1.0) if score >= 0.0 else 0.35 + 0.55 * clampf(skill, 0.0, 1.0)
	var cap := float((plan.get("knowledge_cap", {}) as Dictionary).get(knowledge(sid), 1.0))
	var g := minf(base, cap)
	if knowledge(sid) == "mastered":
		g = minf(g + 0.05, 1.0)
	if not current_ordered:
		g *= float(plan.get("out_of_order_mult", 0.4))
	done[sid] = {"grade": g, "ordered": current_ordered}
	current = ""
	progress = 0.0
	waiting = false
	return g


## A household worker's grade for the stage waiting on its puzzle: a middling job by skill 0..1 (never the best a careful player gets).
func worker_grade(skill: float) -> float:
	return clampf(0.3 + 0.35 * skill, 0.0, 0.7)


func grade_of(sid: String) -> float:
	return float((done.get(sid, {}) as Dictionary).get("grade", 0.0))


func grade_word(g: float) -> String:
	return "rough" if g < 0.4 else "plain" if g < 0.65 else "good" if g < 0.85 else "fine"


## The finished boat's numbers from the grades: how true its shape is (speed), how watertight (leaks an hour), how strong (wear).
## quality is the weighted mean of the grades.
func stats() -> Dictionary:
	var by := {}
	var wsum := {}
	var q := 0.0
	var wt := 0.0
	for s: Dictionary in stages():
		var g := grade_of(String(s.id))
		var w := float(s.get("weight", 0.0))
		var what := String(s.get("what", ""))
		by[what] = float(by.get(what, 0.0)) + g * w
		wsum[what] = float(wsum.get(what, 0.0)) + w
		q += g * w
		wt += w
	for k: String in by:
		by[k] = float(by[k]) / maxf(float(wsum[k]), 0.001)
	var watertight := float(by.get("watertight", 0.5))
	var out_of_order := false
	for k: String in done:
		if not bool((done[k] as Dictionary).ordered):
			out_of_order = true
	return {"quality": q / maxf(wt, 0.001), "shape": float(by.get("shape", 0.5)), "watertight": watertight, "strong": float(by.get("strong", 0.5)),
			"speed_mult": 0.88 + 0.16 * float(by.get("shape", 0.5)), "leak_l_per_h": (1.0 - watertight) * 24.0,
			"wear_mult": 1.6 - 0.8 * float(by.get("strong", 0.5)), "out_of_order": out_of_order,
			"word": grade_word(q / maxf(wt, 0.001))}


func to_dict() -> Dictionary:
	return {"plan": plan_id, "store": store.duplicate(), "done": done.duplicate(true), "current": current, "progress": progress,
			"waiting": waiting, "ordered": current_ordered}


static func from_dict(d: Dictionary) -> BoatBuild:
	var b := BoatBuild.make(String(d.get("plan", "birchbark")))
	b.store = (d.get("store", {}) as Dictionary).duplicate()
	b.done = (d.get("done", {}) as Dictionary).duplicate(true)
	b.current = String(d.get("current", ""))
	b.progress = float(d.get("progress", 0.0))
	b.waiting = bool(d.get("waiting", false))
	b.current_ordered = bool(d.get("ordered", true))
	return b
