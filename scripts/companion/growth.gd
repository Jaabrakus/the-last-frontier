class_name Growth
extends RefCounted
## How a child grows up, logic only (user 2026-09-28: "growth is by MILESTONES ONLY, not calendar age"; data/companion/growth.json;
## the node side is GrowthLink, the body ChildBody, the lessons Teaching, the NPC father Father).
##
## A child is a record of Household.family ({id, name, sex, born_at, mother, father, kind, seed, vigor, worker_id, ...}); this adds
## to it, tolerantly (normalize() fills what an old save lacks):
##   stage       "newborn" | "infant" | "toddler" | "child" | "teen" | "adult"
##   stage_at    game minute the stage began
##   care_sum, care_n, care_at   the care samples of THIS stage (an hourly sample of how it is looked after), the last sample time
##   lessons     lessons taken in all;  watched  watch credits in all;  topics {topic id: times learnt}
##   watch       {topic id: game minutes watched, not yet a credit};  last_lesson {day, count, topics {id: n}}
##   with        "mother" | "father": the parent it goes about with;  mode "follow" | "stay"
##   fed_at      game minute of its last meal;  look {}  the look mixed from its parents (GrowthLink);  core {}  its own SurvivalCore state
## A stage's `next` requirements (growth.json) must ALL be met to move on: days in the stage, the stage's average care, the lessons
## taken, the watch credits, the distinct topics learnt, the core curriculum. progress() shows them; advance() moves the child on.
##   Growth.progress(child, now) -> {stage, next, ready, missing, lines ...};  Growth.advance(child, now) -> the event or {}

const PATH := "res://data/companion/growth.json"
const MIN_PER_DAY := 1440.0
const REQS := ["min_days", "care", "lessons", "watched", "topics", "core"]

static var _cfg := {}


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_cfg = d if d is Dictionary else {"stages": []}
	return _cfg


## Tests: replace the configuration (an empty dictionary reloads the file).
static func set_cfg(d: Dictionary) -> void:
	_cfg = d


# ---------------------------------------------------------------- the stages
static func stages() -> Array:
	return cfg().get("stages", [])


static func stage_index(id: String) -> int:
	var rows := stages()
	for i in rows.size():
		if String((rows[i] as Dictionary).id) == id:
			return i
	return 0


static func stage_row(id: String) -> Dictionary:
	var rows := stages()
	return rows[stage_index(id)] if not rows.is_empty() else {"id": id}


static func next_id(id: String) -> String:
	var rows := stages()
	var i := stage_index(id)
	return String((rows[i + 1] as Dictionary).id) if i + 1 < rows.size() else ""


static func first_id() -> String:
	return String((stages()[0] as Dictionary).id) if not stages().is_empty() else "newborn"


static func at_least(child: Dictionary, stage_id: String) -> bool:
	return stage_index(stage_of(child)) >= stage_index(stage_id)


static func stage_of(child: Dictionary) -> String:
	return String(child.get("stage", first_id()))


static func stage_name(child: Dictionary) -> String:
	return String(stage_row(stage_of(child)).get("name", stage_of(child).capitalize()))


## What the stage lets it do ("walk", "follow", "watch", "lesson", "carry", "work", "chores").
static func can(child: Dictionary, what: String) -> bool:
	return bool((stage_row(stage_of(child)).get("can", {}) as Dictionary).get(what, false))


## A number of the stage row (scale, head, walk_speed, run_speed, watch_mult, lesson_mult, helper_bonus).
static func num(child: Dictionary, key: String, dflt := 0.0) -> float:
	return float(stage_row(stage_of(child)).get(key, dflt))


## Carried always (BabyLink's): a newborn or an infant.
static func carried(child: Dictionary) -> bool:
	return bool(stage_row(stage_of(child)).get("carried", false))


## Has a walking body of its own (toddler on).
static func has_body(child: Dictionary) -> bool:
	return bool(stage_row(stage_of(child)).get("body", false))


# ---------------------------------------------------------------- the record
## Fills what a record lacks (a save from before growth, or a birth just made) IN PLACE and returns it. A record without a stage is
## placed by its age against the stages' minimum days once (never past the last but one: adulthood is earned by the milestones).
static func normalize(child: Dictionary, now: float) -> Dictionary:
	if not child.has("stage") or not stages().any(func(r: Dictionary) -> bool: return String(r.id) == String(child.stage)):
		var born := float(child.get("born_at", now))
		var age := maxf((now - born) / MIN_PER_DAY, 0.0)
		var rows := stages()
		var start := 0.0
		var idx := 0
		while idx < rows.size() - 2:   # the last stage but one at most: adulthood is earned
			var need := float((rows[idx].get("next", {}) as Dictionary).get("min_days", 0.0))
			if age < start + need:
				break
			start += need
			idx += 1
		var pick := String((rows[idx] as Dictionary).id) if not rows.is_empty() else first_id()
		var picked_at := born + start * MIN_PER_DAY
		child["stage"] = pick
		child["stage_at"] = minf(picked_at, now)
	child["stage_at"] = float(child.get("stage_at", child.get("born_at", now)))
	child["care_sum"] = float(child.get("care_sum", 0.0))
	child["care_n"] = int(child.get("care_n", 0))
	child["care_at"] = float(child.get("care_at", child.stage_at))
	child["lessons"] = int(child.get("lessons", 0))
	child["watched"] = int(child.get("watched", 0))
	child["topics"] = child.get("topics", {}) if child.get("topics") is Dictionary else {}
	child["watch"] = child.get("watch", {}) if child.get("watch") is Dictionary else {}
	child["last_lesson"] = child.get("last_lesson", {}) if child.get("last_lesson") is Dictionary else {}
	child["with"] = String(child.get("with", "mother")) if String(child.get("with", "mother")) in ["mother", "father"] else "mother"
	child["mode"] = String(child.get("mode", "follow")) if String(child.get("mode", "follow")) in ["follow", "stay"] else "follow"
	child["fed_at"] = float(child.get("fed_at", now))
	return child


static func normalize_all(family: Array, now: float) -> void:
	for c: Dictionary in family:
		normalize(c, now)


# ---------------------------------------------------------------- care
static func _care_cfg(key: String, dflt: float) -> float:
	return float((cfg().get("care", {}) as Dictionary).get(key, dflt))


## The average care this stage (the prior before any sample).
static func care_avg(child: Dictionary) -> float:
	var n := int(child.get("care_n", 0))
	return float(child.get("care_sum", 0.0)) / float(n) if n > 0 else _care_cfg("prior", 0.6)


## One sample, 0..1. ctx: {content (0..1: a baby's contentment; when present it is the sample), fed (bool), attended (bool)}.
static func care_sample(ctx: Dictionary) -> float:
	if ctx.has("content"):
		return clampf(float(ctx.content), 0.0, 1.0)
	var fw := _care_cfg("fed_weight", 0.6)
	var aw := _care_cfg("attended_weight", 0.4)
	return clampf((fw if bool(ctx.get("fed", true)) else 0.0) + (aw if bool(ctx.get("attended", true)) else 0.0), 0.0, 1.0)


## Takes the care samples due up to `now` (one per sample_min game minutes, at most max_catch_up at once) with `ctx`. Returns how many.
static func note_care(child: Dictionary, now: float, ctx: Dictionary) -> int:
	var step := maxf(_care_cfg("sample_min", 60.0), 1.0)
	var at := float(child.get("care_at", now))
	if now - at > step * _care_cfg("max_catch_up", 48.0):
		at = now - step * _care_cfg("max_catch_up", 48.0)
	var n := 0
	while now - at >= step:
		at += step
		child["care_sum"] = float(child.get("care_sum", 0.0)) + care_sample(ctx)
		child["care_n"] = int(child.get("care_n", 0)) + 1
		n += 1
	child["care_at"] = at
	return n


# ---------------------------------------------------------------- milestones
static func days_in_stage(child: Dictionary, now: float) -> float:
	return maxf((now - float(child.get("stage_at", now))) / MIN_PER_DAY, 0.0)


## How many topics of the core curriculum the child has learnt, and how many there are (Teaching owns the list).
static func core_progress(child: Dictionary) -> Vector2i:
	var have := 0
	var all := 0
	for t: Dictionary in Teaching.topics():
		if bool(t.get("core", false)):
			all += 1
			if int((child.get("topics", {}) as Dictionary).get(String(t.id), 0)) > 0:
				have += 1
	return Vector2i(have, all)


## Where the child stands against its next milestone: {stage, name, next, next_name, days, lines: [{req, name, have, need, ok, text}],
## missing: [req ids], ready, hint}. Nothing for an adult (next "").
static func progress(child: Dictionary, now: float) -> Dictionary:
	var st := stage_of(child)
	var row := stage_row(st)
	var nid := next_id(st)
	var out := {"stage": st, "name": String(row.get("name", st)), "next": nid, "next_name": "", "days": days_in_stage(child, now),
			"lines": [], "missing": [], "ready": false, "hint": ""}
	if nid == "":
		out.hint = "Grown up."
		return out
	out.next_name = String(stage_row(nid).get("name", nid))
	var req: Dictionary = row.get("next", {})
	var names: Dictionary = cfg().get("requirement_names", {})
	var lines := []
	var missing := []
	for k: String in REQS:
		if not req.has(k):
			continue
		var have := 0.0
		var need := 0.0
		var ok := true
		var text := ""
		match k:
			"min_days":
				have = days_in_stage(child, now)
				need = float(req[k])
				ok = have >= need
				text = "%d of %d days" % [floori(have), ceili(need)]
			"care":
				have = care_avg(child)
				need = float(req[k])
				ok = have >= need - 0.0001
				text = "care %d%% (needs %d%%)" % [roundi(have * 100.0), roundi(need * 100.0)]
			"lessons", "watched", "topics":
				have = float(int(child.get(k, 0))) if k != "topics" else float((child.get("topics", {}) as Dictionary).size())
				need = float(req[k])
				ok = have >= need
				text = "%d of %d %s" % [int(have), int(need), String(names.get(k, k))]
			"core":
				var cp := core_progress(child)
				have = float(cp.x)
				need = float(cp.y)
				ok = not bool(req[k]) or cp.x >= cp.y
				text = "%d of %d %s" % [cp.x, cp.y, String(names.get(k, k))]
		lines.append({"req": k, "name": String(names.get(k, k)), "have": have, "need": need, "ok": ok, "text": text})
		if not ok:
			missing.append(k)
	out.lines = lines
	out.missing = missing
	out.ready = missing.is_empty()
	var parts := []
	for l: Dictionary in lines:
		if not bool(l.ok):
			parts.append(String(l.text))
	out.hint = ("Ready to grow: %s next." % out.next_name) if missing.is_empty() else "Towards %s: %s." % [String(out.next_name).to_lower(), ", ".join(parts)]
	return out


## Moves the child to its next stage if it has earned it. {} when not, else {do: "stage", id, name, from, to}. The care samples start
## over in the new stage; the record is changed in place.
static func advance(child: Dictionary, now: float) -> Dictionary:
	var p := progress(child, now)
	if not bool(p.ready):
		return {}
	return to_stage(child, String(p.next), now)


static func to_stage(child: Dictionary, id: String, now: float) -> Dictionary:
	var from := stage_of(child)
	child["stage"] = id
	child["stage_at"] = now
	child["care_sum"] = 0.0
	child["care_n"] = 0
	child["care_at"] = now
	return {"do": "stage", "id": String(child.get("id", "")), "name": String(child.get("name", "")), "from": from, "to": id}


## The line for a stage change ({name} filled in), "" when there is none.
static func stage_line(child: Dictionary, id: String) -> String:
	return String((cfg().get("lines", {}).get("stage", {}) as Dictionary).get(id, "")).replace("{name}", String(child.get("name", "")))


# ---------------------------------------------------------------- feeding (the store side is GrowthLink's)
## Whether it is due a meal, and whether it has gone hungry (past the grace).
static func meal_due(child: Dictionary, now: float) -> bool:
	return (now - float(child.get("fed_at", now))) >= float((cfg().get("meal", {}) as Dictionary).get("hours", 7.0)) * 60.0


static func fed(child: Dictionary, now: float) -> bool:
	var m: Dictionary = cfg().get("meal", {})
	return (now - float(child.get("fed_at", now))) <= float(m.get("hours", 7.0)) * float(m.get("grace", 1.6)) * 60.0


## Gives it a meal from a store: `take` is Callable(kinds: Array) -> String (the kind taken, "" none). Returns the kind or "".
static func feed(child: Dictionary, now: float, take: Callable) -> String:
	var kinds: Array = (cfg().get("meal", {}) as Dictionary).get("kinds", [])
	var got := String(take.call(kinds)) if take.is_valid() else ""
	if got != "":
		child["fed_at"] = now
	return got


# ---------------------------------------------------------------- the adult
## Junior worker rules of the teen stage: {skill_cap, jobs, needs_core} or {} when the stage has none.
static func junior_rules() -> Dictionary:
	return (stage_row("teen").get("junior", {}) as Dictionary).duplicate(true)


## Whether the child may be taken on as a worker now: a teen (or adult) that has done the core curriculum.
static func worker_ready(child: Dictionary) -> bool:
	if not at_least(child, "teen"):
		return false
	var jr := junior_rules()
	if bool(jr.get("needs_core", true)):
		var cp := core_progress(child)
		return cp.x >= cp.y
	return true


## The skill cap of a child worker now (junior: the cap; adult: none = 100).
static func skill_cap(child: Dictionary) -> float:
	return 100.0 if stage_of(child) == "adult" else float(junior_rules().get("skill_cap", 35.0))


## The job ids a child worker may do (junior: the list; adult: every job).
static func allowed_jobs(child: Dictionary) -> Array:
	if stage_of(child) == "adult":
		return JobBook.ids()
	return (junior_rules().get("jobs", []) as Array).filter(func(id: Variant) -> bool: return JobBook.has(String(id)))


## The worker of a child, from its own core: a SpouseCore with the child's name and look, its skills held to what it learned (never below
## the baseline * vigor), the child's knowledge and learning records, its jobs limited by the stage. `main` is the household's main core.
static func make_worker(main: SurvivalCore, child: Dictionary, child_core: SurvivalCore) -> SpouseCore:
	var w := SpouseCore.create_unit(main, int(child.get("seed", 1)), float(child.get("sex", 0.0)))
	w.name = String(child.get("name", w.name))
	var lk: Variant = child.get("look")
	if lk is Dictionary and not (lk as Dictionary).is_empty():
		w.look = (lk as Dictionary).duplicate(true)
		w.body_look = body_look(child, main.state.minutes)   # drawn at its stage's body (never an adult's before adulthood)
	w.role = "home"
	var floor_v := float((cfg().get("growing_up", {}) as Dictionary).get("baseline_skill", 4.0)) * float(child.get("vigor", 1.0))
	for k in w.core.state.skills.keys():
		var learnt := SurvivalSkills.level(child_core, String(k)) if child_core != null else 0.0
		w.core.state.skills[k] = maxf(learnt, floor_v)
	if child_core != null:
		var src := child_core.player()
		var dst := w.core.player()
		dst["knowledge"] = (src.get("knowledge", {}) as Dictionary).duplicate(true)
		dst["learning"] = (src.get("learning", {}) as Dictionary).duplicate(true)
	return w


## Holds a child worker's skills at the stage's cap (a junior does not out-learn what the stage allows).
static func enforce_cap(w: SpouseCore, child: Dictionary) -> int:
	var cap := skill_cap(child)
	var n := 0
	for k in w.core.state.skills.keys():
		if float(w.core.state.skills[k]) > cap:
			w.core.state.skills[k] = cap
			n += 1
	return n


# ---------------------------------------------------------------- the look
## A child's ADULT look, from its parents' looks through the face engine (ChildLook.from_parents: face features, skin, eyes and hair from
## the two, seeded from the child's seed: the same child, the same face at every stage and on the baby). The bust and the genital shape
## of the adult body are inherited (a girl's from her mother's, a boy's from his father's); what is SHOWN at each stage is body_look().
static func mix_look(child: Dictionary, mother: Dictionary, father: Dictionary) -> Dictionary:
	var seed_v := int(child.get("seed", 1)) ^ 0xC41D
	var lk: Dictionary = ChildLook.from_parents(mother, father, float(child.get("sex", 0.0)), seed_v)
	if String((lk.get("hair", {}) as Dictionary).get("style", "")) == "":
		lk["hair"] = {"style": "hair_cropped_1758", "color": (lk.get("hair", {}) as Dictionary).get("color", "dark_brown")}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v ^ 0x51DE
	if float(child.get("sex", 0.0)) < 0.5:
		lk["bust"] = snappedf(float(mother.get("bust", 0.0)) * rng.randf_range(0.7, 1.0), 0.001)
		lk["genital"] = 0.0
		lk["stubble"] = 0.0
	else:
		lk["bust"] = 0.0
		lk["genital"] = snappedf(float(father.get("genital", 0.0)), 0.001)
		lk["stubble"] = float((cfg().get("shapes", {}) as Dictionary).get("adult_stubble_boy", 0.2))
	lk["weathering"] = 0.1
	return lk


## "neutral" (the flat child body), "teen" (the modest change) or "adult" for the child's stage now.
static func shape_of(child: Dictionary, now: float) -> String:
	var sh: Variant = stage_row(stage_of(child)).get("shape", "neutral")
	if sh is Dictionary:
		return "teen" if days_in_stage(child, now) >= float((sh as Dictionary).get("neutral_days", 40.0)) else "neutral"
	return String(sh)


## The look the child is DRAWN with at its stage: the neutral child body (ChildLook.body_for_stage) up to the child, the modest teen
## change (growth.json shapes) after the teen's neutral days, the adult body at adulthood. The face never changes.
static func body_look(child: Dictionary, now: float) -> Dictionary:
	var look: Dictionary = (child.get("look", {}) as Dictionary) if child.get("look") is Dictionary else {}
	var neutral := ChildLook.body_for_stage(look, "child")
	neutral["stage"] = stage_of(child)   # (the body's form, clothes and skin of the stage: ChildBody.shape_body, Spouse._build_model)
	match shape_of(child, now):
		"neutral":
			return neutral
		"teen":
			var sh: Dictionary = stage_row("teen").get("shape", {})
			var out := look.duplicate(true)
			out["sex"] = lerpf(float(neutral.get("sex", 1.0)), float(look.get("sex", 0.0)), float(sh.get("sex_fit", 0.35)))
			out["bust"] = minf(float(look.get("bust", 0.0)), float(sh.get("bust_max", 0.05))) if float(look.get("sex", 0.0)) < 0.5 else -1.0
			out["genital"] = 0.0
			out["body_hair"] = 0.0
			out["stubble"] = 0.0
			out["stature"] = 1.0
			out["stage"] = "teen"
			return out
	return look.duplicate(true)
