class_name Pregnancy
extends RefCounted
## Conception, gestation and birth (user 2026-09-28: "a skill roll check where after each intimacy the spouse or the user can
## become pregnant"). LOGIC ONLY, no depiction: numbers, states and plain records. Everything tunable is in
## data/companion/pregnancy.json. The node side is PregnancyLink (it calls attempt() after a finished yoga session and advance()
## each frame); SpouseCore keeps the wife's record (`pregnancy`), the player's is in core.state.players[player_id].pregnancy.
##
## WHO: the woman of the pair (the wife when the player is a man, the player when she is a woman; the man never conceives).
## THE ROLL (the game's check model, skills.json check_model):
##   S = 100 * (w_health*health/100 + w_food*food + w_warmth*warmth + w_rest*rest)     her effective score, 0..100
##   p = SurvivalSkills.chance(core, S, D, condition mods)   base + (S - D)/slope + check_mod (ill, exhausted, ...)
##   c = clamp(base_chance * p / ref_chance, floor, cap) * repeat_mult^(attempts already made today)
##   conceived when r < c, r drawn from the named stream "w.conception" of HER core (saved with it: a reload repeats it).
## At most `daily_limit` rolls a game day (the later ones at reduced chance); none while pregnant or resting after a birth.
## The record (a Dictionary, tolerant of old saves; minutes are game minutes on the clock):
##   {conceived_at, due_at (-1: not pregnant), stage, noticed, births, rest_until, last_day, tries, ticked_to}

const KIND_SPOUSE := "spouse"
const KIND_PLAYER := "player"
const PATH := "res://data/companion/pregnancy.json"
const MIN_PER_DAY := 1440.0
const STREAM := "w.conception"
const BIRTH_STREAM := "w.birth"

static var _cfg := {}


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_cfg = d if d is Dictionary else {}
	return _cfg


## Tests: replace the configuration (an empty dictionary reloads the file).
static func set_cfg(d: Dictionary) -> void:
	_cfg = d.duplicate(true)


static func new_record() -> Dictionary:
	return {"conceived_at": -1.0, "due_at": -1.0, "stage": "", "noticed": false, "births": 0, "rest_until": -1.0,
			"last_day": -1, "tries": 0, "ticked_to": -1.0}


## A record from a save of any age (missing or odd fields take the default).
static func normalize(d: Variant) -> Dictionary:
	var r := new_record()
	if d is Dictionary:
		var s: Dictionary = d
		for k in ["conceived_at", "due_at", "rest_until", "ticked_to"]:
			r[k] = float(s.get(k, -1.0))
		r["stage"] = String(s.get("stage", ""))
		r["noticed"] = bool(s.get("noticed", false))
		r["births"] = maxi(int(s.get("births", 0)), 0)
		r["last_day"] = int(s.get("last_day", -1))
		r["tries"] = maxi(int(s.get("tries", 0)), 0)
	return r


## Who conceives: KIND_PLAYER when the player is a woman, KIND_SPOUSE (the wife) when the player is a man.
static func woman_kind(player_is_male: bool) -> String:
	return KIND_SPOUSE if player_is_male else KIND_PLAYER


## The player's own record, kept in her survival state (players[player_id]) so it is saved with it.
static func player_record(core: SurvivalCore) -> Dictionary:
	var pid := String(core.state.player_id)
	var pl: Dictionary = core.state.players.get(pid, {})
	var cur: Variant = pl.get("pregnancy")
	if not (cur is Dictionary and (cur as Dictionary).has("conceived_at")):
		pl["pregnancy"] = normalize(cur)
	core.state.players[pid] = pl
	return pl["pregnancy"]


## On in this game: the global switch and the playthrough's setting (core.state.settings[player_setting]).
static func enabled(main: SurvivalCore) -> bool:
	var c := cfg()
	if not bool(c.get("enabled", true)):
		return false
	if main == null:
		return true
	return bool(main.state.settings.get(String(c.get("player_setting", "pregnancy")), bool(c.get("player_setting_default", true))))


# ---------------------------------------------------------------- the state
static func is_pregnant(rec: Dictionary) -> bool:
	return float(rec.get("due_at", -1.0)) >= 0.0 and float(rec.get("conceived_at", -1.0)) >= 0.0


static func stage_rows() -> Array:
	return cfg().get("stages", [])


static func stage_row(id: String) -> Dictionary:
	for s: Dictionary in stage_rows():
		if String(s.id) == id:
			return s
	return {}


## How far along, 0..1 (0 when not pregnant).
static func progress(rec: Dictionary, now: float) -> float:
	if not is_pregnant(rec):
		return 0.0
	var span := maxf(float(rec.due_at) - float(rec.conceived_at), 1.0)
	return clampf((now - float(rec.conceived_at)) / span, 0.0, 1.0)


## The stage id at `now` ("" when not pregnant).
static func stage_of(rec: Dictionary, now: float) -> String:
	if not is_pregnant(rec):
		return ""
	var f := progress(rec, now)
	var rows := stage_rows()
	for s: Dictionary in rows:
		if f < float(s.upto):
			return String(s.id)
	return String(rows[rows.size() - 1].id) if not rows.is_empty() else ""


static func gestation_days() -> float:
	return float(cfg().get("gestation_days", 27))


## Whole game days gone and the total (for "day 12 of 27").
static func day_of(rec: Dictionary, now: float) -> int:
	if not is_pregnant(rec):
		return 0
	return mini(floori((now - float(rec.conceived_at)) / MIN_PER_DAY) + 1, int(gestation_days()))


static func resting(rec: Dictionary, now: float) -> bool:
	return now < float(rec.get("rest_until", -1.0))


## No heavy work (jobs tagged "heavy") in the late stages and while she rests after a birth.
static func heavy_blocked(rec: Dictionary, now: float) -> bool:
	if resting(rec, now):
		return true
	return is_pregnant(rec) and (cfg().get("heavy_stages", []) as Array).has(stage_of(rec, now))


## Walking speed factor for her body (1.0: none).
static func speed_mult(rec: Dictionary, now: float) -> float:
	var s := stage_row(stage_of(rec, now))
	return float(s.get("speed", 1.0)) if not s.is_empty() else 1.0


# ---------------------------------------------------------------- the roll
## The check with the woman's `core` (no dice): {S, D, p (the check model's chance), chance (of conceiving, before the repeat
## factor), mult (the repeat factor), final, tries, parts}. `rec` says how many rolls she has had today.
static func check(rec: Dictionary, core: SurvivalCore, now: float) -> Dictionary:
	var c := cfg()
	var ck: Dictionary = c.get("check", {})
	var w: Dictionary = ck.get("weights", {})
	var food_v := float((ck.get("food", {}) as Dictionary).get(SurvivalNeeds.food_stage(core), 0.6))
	var warm_v := float((ck.get("warmth", {}) as Dictionary).get(SurvivalNeeds.warmth_stage(core), 0.6))
	var rest_v := float((ck.get("rest", {}) as Dictionary).get(SurvivalNeeds.rest_stage(core), 0.6))
	var health_v := clampf(core.health() / 100.0, 0.0, 1.0)
	var wsum := maxf(float(w.get("health", 0.4)) + float(w.get("food", 0.25)) + float(w.get("warmth", 0.15)) + float(w.get("rest", 0.2)), 0.001)
	var s := 100.0 * (float(w.get("health", 0.4)) * health_v + float(w.get("food", 0.25)) * food_v \
			+ float(w.get("warmth", 0.15)) * warm_v + float(w.get("rest", 0.2)) * rest_v) / wsum
	var d := float(ck.get("difficulty", 45.0))
	var cond := clampf(SurvivalUtil.num(core.get_modifiers().get("check_mod"), 0.0),
			float(ck.get("condition_mod_min", -0.4)), float(ck.get("condition_mod_max", 0.1)))
	var p := SurvivalSkills.chance(core, s, d, cond)
	var raw := float(c.get("base_chance", 0.3)) * p / maxf(float(ck.get("ref_chance", 0.55)), 0.01)
	raw = clampf(raw, float(c.get("chance_floor", 0.04)), float(c.get("chance_cap", 0.6)))
	var tries := tries_today(rec, core)
	var mult := pow(float(c.get("repeat_mult", 0.4)), float(tries))
	return {"S": s, "D": d, "p": p, "cond": cond, "chance": raw, "mult": mult, "final": raw * mult, "tries": tries,
			"parts": {"health": health_v, "food": food_v, "warmth": warm_v, "rest": rest_v}}


## Rolls made so far in the woman's game day.
static func tries_today(rec: Dictionary, core: SurvivalCore) -> int:
	return int(rec.get("tries", 0)) if int(rec.get("last_day", -1)) == SurvivalClock.abs_day(core) else 0


## After a finished session. `core`: the woman's own survival core (she rolls on its named stream). `on`: the playthrough's
## setting (Pregnancy.enabled(main)). Returns {status, ...}: "off", "pregnant", "resting", "limit" (no roll made), else a
## roll: "conceived" or "no", with the check's numbers and `r`. A conception writes the record.
static func attempt(rec: Dictionary, core: SurvivalCore, now: float, on := true) -> Dictionary:
	if not on or not bool(cfg().get("enabled", true)):
		return {"status": "off"}
	if is_pregnant(rec):
		return {"status": "pregnant"}
	if resting(rec, now):
		return {"status": "resting"}
	var day := SurvivalClock.abs_day(core)
	if int(rec.get("last_day", -1)) != day:
		rec["last_day"] = day
		rec["tries"] = 0
	if int(rec.tries) >= int(cfg().get("daily_limit", 2)):
		return {"status": "limit"}
	var ck := check(rec, core, now)
	rec["tries"] = int(rec.tries) + 1
	var r := SurvivalStreams.rng(core, STREAM).randf()
	var hit := r < float(ck.final)
	ck["r"] = r
	ck["status"] = "no"
	if hit:
		rec["conceived_at"] = now
		rec["due_at"] = now + gestation_days() * MIN_PER_DAY
		rec["stage"] = ""
		rec["noticed"] = false
		rec["ticked_to"] = now
		ck["status"] = "conceived"
	SurvivalStreams.sync(core)
	return ck


# ---------------------------------------------------------------- gestation
## Time passing (call each frame with the woman's core after it has caught up to `now`): the extra hunger and tiredness of
## her stage, and the events: {"do": "notice"} (she knows), {"do": "stage", "stage": id} and {"do": "birth", "child": {...}}.
## `parents`: {mother: name, father: name, kind, next_id: int} for the child record.
static func advance(rec: Dictionary, core: SurvivalCore, now: float, parents := {}) -> Array:
	var out := []
	if not is_pregnant(rec):
		rec["ticked_to"] = now
		return out
	var from := float(rec.get("ticked_to", -1.0))
	rec["ticked_to"] = now
	var dm := maxf(now - from, 0.0) if from >= 0.0 else 0.0
	var st := stage_of(rec, now)
	if now >= float(rec.due_at):
		# the burden up to the birth
		_burden(core, dm, stage_row("near_term"))
		out.append({"do": "birth", "child": _deliver(rec, core, now, parents)})
		return out
	_burden(core, dm, stage_row(st))
	if not bool(rec.noticed) and now - float(rec.conceived_at) >= float(cfg().get("notice_days", 3)) * MIN_PER_DAY:
		rec["noticed"] = true
		rec["stage"] = st
		out.append({"do": "notice", "stage": st})
	elif bool(rec.noticed) and st != String(rec.stage):
		rec["stage"] = st
		out.append({"do": "stage", "stage": st})
	return out


## The stage's extra food (a share of the hourly burn, taken from the stomach then the reserve as any burn is, never below
## zero) and tiredness (up to a cap, never to collapse).
static func _burden(core: SurvivalCore, dm: float, row: Dictionary) -> void:
	if dm <= 0.0 or row.is_empty() or core.is_dead():
		return
	var hours := dm / 60.0
	var n := core.state.needs
	var burn_h := SurvivalUtil.num(SurvivalNeeds.need_row(core, "need.food").get("burn_kcal_per_game_h"), 100.0)
	var extra := burn_h * float(row.get("extra_kcal", 0.0)) * hours * SurvivalNeeds.difficulty_mult(core, "food")
	if extra > 0.0:
		var stomach := SurvivalUtil.num(n.get("stomach"), 0.0)
		var reserve := SurvivalUtil.num(n.get("reserve"), 0.0)
		var from_stomach := minf(stomach, extra)
		n["stomach"] = stomach - from_stomach
		n["reserve"] = maxf(0.0, reserve - (extra - from_stomach))
	var fat := float(row.get("extra_fatigue_per_h", 0.0)) * hours
	if fat > 0.0:
		var cur := SurvivalUtil.num(n.get("fatigue"), 0.0)
		var cap := float(cfg().get("fatigue_cap", 90.0))
		if cur < cap:
			n["fatigue"] = minf(cur + fat, cap)


## The birth: the record is cleared (a rest after it), one child record comes back.
static func _deliver(rec: Dictionary, core: SurvivalCore, now: float, parents: Dictionary) -> Dictionary:
	var born := int(rec.get("births", 0)) + 1
	rec["births"] = born
	rec["conceived_at"] = -1.0
	rec["due_at"] = -1.0
	rec["stage"] = ""
	rec["noticed"] = false
	rec["rest_until"] = now + float(cfg().get("rest_days_after_birth", 4)) * MIN_PER_DAY
	var child := make_child(SurvivalStreams.rng(core, BIRTH_STREAM), now, parents)
	SurvivalStreams.sync(core)
	return child


# ---------------------------------------------------------------- the child (a record only; a worker later)
## {id, name, sex (0 girl, 1 boy), born_at, mother, father, kind (which parent bore it), seed (its stats seed), worker_id (-1: not
## yet a worker)}. The sex, name and seed come from the stream.
static func make_child(rng: RandomNumberGenerator, now: float, parents: Dictionary) -> Dictionary:
	var sex := float(rng.randi() % 2)
	var pool: Array = SpouseCore.NAMES_M if sex >= 0.5 else SpouseCore.NAMES_F
	var span: Array = (cfg().get("child", {}) as Dictionary).get("stats_span", [0.85, 1.15])
	return {"id": "child.%d" % int(parents.get("next_id", 1)), "name": String(pool[rng.randi() % pool.size()]), "sex": sex,
			"born_at": now, "mother": String(parents.get("mother", "")), "father": String(parents.get("father", "")),
			"kind": String(parents.get("kind", KIND_SPOUSE)), "seed": rng.randi() & 0x7FFFFFFF,
			"vigor": snappedf(rng.randf_range(float(span[0]), float(span[1])), 0.01), "worker_id": -1}


## A family list from a save (a save without one: empty; odd entries dropped).
static func family_from(d: Variant) -> Array:
	var out := []
	if d is Array:
		for c: Variant in d:
			if c is Dictionary and (c as Dictionary).has("name"):
				var e: Dictionary = (c as Dictionary).duplicate(true)
				e["sex"] = float(e.get("sex", 0.0))
				e["born_at"] = float(e.get("born_at", 0.0))
				e["seed"] = int(e.get("seed", 0))
				e["worker_id"] = int(e.get("worker_id", -1))
				e["id"] = String(e.get("id", "child.%d" % (out.size() + 1)))
				out.append(e)
	return out


static func age_days(child: Dictionary, now: float) -> float:
	return maxf((now - float(child.get("born_at", now))) / MIN_PER_DAY, 0.0)


## "newborn", "5 days", "1 year, 3 days" (a game year is 36 days).
static func age_text(child: Dictionary, now: float) -> String:
	var d := floori(age_days(child, now))
	if d < 1:
		return "newborn"
	var y := d / 36
	var rest := d % 36
	if y <= 0:
		return "%d day%s" % [d, "" if d == 1 else "s"]
	return "%d year%s%s" % [y, "" if y == 1 else "s", ", %d day%s" % [rest, "" if rest == 1 else "s"] if rest > 0 else ""]


# ---------------------------------------------------------------- what the screens say
## Her state in one plain line ("" when nothing to say: not pregnant and not resting; a pregnancy not yet noticed is silent).
static func status_line(rec: Dictionary, now: float) -> String:
	if is_pregnant(rec):
		if not bool(rec.get("noticed", false)):
			return ""
		var row := stage_row(stage_of(rec, now))
		return "Expecting: %s stage, day %d of %d" % [String(row.get("name", "")).to_lower(), day_of(rec, now), int(gestation_days())]
	if resting(rec, now):
		return "Resting after the birth"
	return ""
