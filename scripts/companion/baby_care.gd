class_name BabyCare
extends RefCounted
## The baby's needs and who holds it, logic only (data/companion/baby.json; the node side is BabyLink, the poses BabyHold,
## the look BabyModel). One state per child record of Household.family ({id, name, sex, born_at, mother, father, kind, ...}):
##   {hunger, tired, soiled, upset (0..1), asleep, fed (count)}
## Hunger, tiredness and a wet wrapping fill with time; a hungry, tired or fretful baby cries, louder the worse it is;
## being held soothes it; it sleeps when tired and content. Nothing here can hurt it: neglect only makes it cry louder and
## the mother come. Who holds it: exactly one of "spouse" (the NPC), "player", "cradle" or "bed" (laid down); the handover
## rules are here (one holder, hands free, near enough), the arms and the walking are BabyLink's.
##   BabyCare.new(); care.sync(family, now); care.tick(dm, ctx); care.feed(id) ...; care.to_dict() / care.load_dict(d, family)
##   BabyCare.plan(state, ctx) -> the mother's next steps (pure; see plan()).

const PATH := "res://data/companion/baby.json"
const MIN_PER_DAY := 1440.0
const PEOPLE := ["spouse", "player"]
const PLACES := ["cradle", "bed"]

static var _cfg := {}

## child id -> state
var states := {}
## child id -> holder ("spouse", "player", "cradle", "bed")
var holders := {}
## What BabyLink animates: [{do: "handover"|"lay"|"take", id, from, to}], drained by pop_events().
var events: Array = []


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_cfg = d if d is Dictionary else {"needs": {}, "nursing": {}, "stages": [], "care": {}, "lines": {}}
	return _cfg


static func set_cfg(d: Dictionary) -> void:
	_cfg = d


static func needs_cfg() -> Dictionary:
	return cfg().get("needs", {})


static func _n(key: String, dflt: float) -> float:
	return float(needs_cfg().get(key, dflt))


# ---------------------------------------------------------------- the child
static func new_state() -> Dictionary:
	return {"hunger": 0.25, "tired": 0.1, "soiled": 0.0, "upset": 0.0, "asleep": false, "fed": 0}


static func normalize(d: Variant) -> Dictionary:
	var s := new_state()
	if d is Dictionary:
		for k: String in ["hunger", "tired", "soiled", "upset"]:
			s[k] = clampf(float((d as Dictionary).get(k, s[k])), 0.0, 1.0)
		s["asleep"] = bool((d as Dictionary).get("asleep", false))
		s["fed"] = maxi(int((d as Dictionary).get("fed", 0)), 0)
	return s


## The stage row for an age in days (the last one past the end).
static func stage_row(age_days: float) -> Dictionary:
	var rows: Array = cfg().get("stages", [])
	for r: Dictionary in rows:
		if age_days < float(r.get("upto_days", 0)):
			return r
	return rows[rows.size() - 1] if not rows.is_empty() else {"id": "newborn", "carried": true, "hunger_mult": 1.0, "size": 1.0}


static func age_days(child: Dictionary, now: float) -> float:
	return maxf((now - float(child.get("born_at", now))) / MIN_PER_DAY, 0.0)


## Whether the child is carried always (a newborn or infant: never left on the ground).
static func carried(child: Dictionary, now: float) -> bool:
	if child.has("stage"):   # GROWTH (growth.gd): a child with a growth stage is carried while newborn or infant, by milestones not by age
		return Growth.carried(child)
	return bool(stage_row(age_days(child, now)).get("carried", true))


## How bad it is, 0..1: the worst of what is wrong.
static func distress(s: Dictionary) -> float:
	var w: Dictionary = needs_cfg().get("weights", {})
	var v := maxf(float(s.hunger) * float(w.get("hunger", 1.0)), float(s.soiled) * float(w.get("soiled", 0.7)))
	v = maxf(v, float(s.upset) * float(w.get("upset", 1.0)))
	if float(s.tired) > 0.8:
		v = maxf(v, float(s.tired) * float(w.get("tired", 0.8)))
	return clampf(v, 0.0, 1.0)


static func crying(s: Dictionary) -> bool:
	return not bool(s.asleep) and distress(s) >= _n("cry_at", 0.62)


static func fussing(s: Dictionary) -> bool:
	return not bool(s.asleep) and distress(s) >= _n("fuss_at", 0.4)


## 0 quiet .. 1 wailing.
static func cry_level(s: Dictionary) -> float:
	if bool(s.asleep):
		return 0.0
	var at := _n("cry_at", 0.62)
	return clampf((distress(s) - at) / maxf(1.0 - at, 0.01), 0.0, 1.0) if distress(s) >= at else 0.0


## "asleep", "content", "fretful", "crying", "wailing".
static func mood(s: Dictionary) -> String:
	if bool(s.asleep):
		return "asleep"
	if cry_level(s) > 0.6:
		return "wailing"
	if crying(s):
		return "crying"
	if fussing(s):
		return "fretful"
	return "content"


## What is wrong, in a word: "hungry", "wet", "tired", "upset", or "" when nothing.
static func wants(s: Dictionary) -> String:
	if bool(s.asleep):
		return ""
	var best := ""
	var bv := _n("fuss_at", 0.4)
	for pair: Array in [["hungry", float(s.hunger)], ["wet", float(s.soiled) * 0.9], ["upset", float(s.upset)], ["tired", float(s.tired) * 0.7]]:
		if float(pair[1]) > bv:
			bv = float(pair[1])
			best = String(pair[0])
	return best


## Lets `dm` game minutes pass for one state. ctx: {held (in someone's arms), settled (held, or in a cradle or bed), stage
## (a stage row)}. Rocking counts as held.
static func advance(s: Dictionary, dm: float, ctx := {}) -> void:
	if dm <= 0.0:
		return
	var h := dm / 60.0
	var mult := float((ctx.get("stage", {}) as Dictionary).get("hunger_mult", 1.0))
	var asleep := bool(s.asleep)
	s["hunger"] = clampf(float(s.hunger) + _n("hunger_per_h", 0.3) * mult * h * (0.6 if asleep else 1.0), 0.0, 1.0)
	s["soiled"] = clampf(float(s.soiled) + _n("soiled_per_h", 0.1) * h, 0.0, 1.0)
	if asleep:
		s["tired"] = clampf(float(s.tired) - _n("sleep_recover_per_h", 0.5) * h, 0.0, 1.0)
	else:
		s["tired"] = clampf(float(s.tired) + _n("tired_per_h", 0.12) * h, 0.0, 1.0)
	# fretfulness: rises toward what is wrong, falls when it is put right (faster in arms)
	var fuss := _n("fuss_at", 0.4)
	var worst := maxf(float(s.hunger), float(s.soiled))
	var target := clampf((worst - fuss) / maxf(1.0 - fuss, 0.01), 0.0, 1.0)
	var held := bool(ctx.get("held", false))
	if target > float(s.upset):
		s["upset"] = minf(float(s.upset) + _n("upset_up_per_h", 0.5) * h, target)
	else:
		s["upset"] = maxf(float(s.upset) - _n("upset_down_per_h", 1.6) * h * (1.0 if held else 0.35), target)
	if held and not asleep:
		s["upset"] = maxf(float(s.upset) - _n("hold_comfort", 0.35) * h, 0.0)
	# sleep
	if asleep:
		if float(s.hunger) > _n("wake_hunger", 0.75) or float(s.tired) < _n("sleep_below", 0.12) or float(s.soiled) > 0.85:
			s["asleep"] = false
			if float(s.hunger) > _n("wake_hunger", 0.75):
				s["upset"] = clampf(float(s.upset) + 0.2, 0.0, 1.0)
	elif float(s.tired) > _n("sleep_above", 0.55) and float(s.hunger) < _n("wake_hunger", 0.75) and float(s.soiled) < 0.85 \
			and bool(ctx.get("settled", true)):
		s["asleep"] = true


static func feed(s: Dictionary, amount := 1.0) -> void:
	s["hunger"] = maxf(float(s.hunger) - amount * _n("feed_fill", 1.0), 0.0)
	s["upset"] = maxf(float(s.upset) - 0.3, 0.0)
	s["fed"] = int(s.get("fed", 0)) + 1


static func change(s: Dictionary) -> void:
	s["soiled"] = 0.0
	s["upset"] = maxf(float(s.upset) - 0.2, 0.0)


static func soothe(s: Dictionary, strength := 1.0) -> void:
	s["upset"] = maxf(float(s.upset) - _n("soothe_relief", 0.7) * strength, 0.0)
	if float(s.tired) > 0.3:
		s["tired"] = minf(float(s.tired) + _n("rock_sleep_boost", 0.2) * strength, 1.0)


# ---------------------------------------------------------------- nursing (the mother's food)
## Takes `kcal` from a core's stomach, then its reserve (as any burn is; never below zero). Returns what was taken.
static func take_kcal(core: SurvivalCore, kcal: float) -> float:
	if core == null or kcal <= 0.0 or core.is_dead():
		return 0.0
	var n := core.state.needs
	var stomach := SurvivalUtil.num(n.get("stomach"), 0.0)
	var reserve := SurvivalUtil.num(n.get("reserve"), 0.0)
	var from_stomach := minf(stomach, kcal)
	var from_reserve := minf(reserve, kcal - from_stomach)
	n["stomach"] = stomach - from_stomach
	n["reserve"] = reserve - from_reserve
	return from_stomach + from_reserve


## The extra burn of nursing for `dm` game minutes: a share of her hourly burn (difficulty as her food).
static func nursing_burn(core: SurvivalCore, dm: float) -> float:
	if core == null or dm <= 0.0:
		return 0.0
	var share := float((cfg().get("nursing", {}) as Dictionary).get("extra_burn_share", 0.12))
	var burn_h := SurvivalUtil.num(SurvivalNeeds.need_row(core, "need.food").get("burn_kcal_per_game_h"), 100.0)
	return take_kcal(core, burn_h * share * (dm / 60.0) * SurvivalNeeds.difficulty_mult(core, "food"))


static func per_feed_kcal() -> float:
	return float((cfg().get("nursing", {}) as Dictionary).get("per_feed_kcal", 35.0))


static func nursing_now(child: Dictionary, now: float) -> bool:
	return age_days(child, now) < float((cfg().get("nursing", {}) as Dictionary).get("wean_days", 200))


# ---------------------------------------------------------------- the family
## Makes a state and a holder for every child of the family, drops those of children gone. New children start in the wife's
## arms (a newborn is carried always).
func sync(family: Array) -> void:
	var ids := {}
	for c: Dictionary in family:
		var id := String(c.get("id", ""))
		if id == "":
			continue
		ids[id] = true
		if not states.has(id):
			states[id] = new_state()
		if not holders.has(id):
			holders[id] = "spouse"
	for id: String in states.keys():
		if not ids.has(id):
			states.erase(id)
	for id: String in holders.keys():
		if not ids.has(id):
			holders.erase(id)


func state(id: String) -> Dictionary:
	return states.get(id, {})


func holder_of(id: String) -> String:
	return String(holders.get(id, "spouse"))


func first_id() -> String:
	return String(states.keys()[0]) if not states.is_empty() else ""


func ids_held_by(who: String) -> Array:
	var out := []
	for id: String in holders:
		if String(holders[id]) == who:
			out.append(id)
	return out


## Lets `dm` game minutes pass for every child.
func tick(dm: float, family: Array, now: float) -> void:
	for c: Dictionary in family:
		var id := String(c.get("id", ""))
		if not states.has(id):
			continue
		var who := holder_of(id)
		var held := PEOPLE.has(who)
		advance(states[id], dm, {"held": held, "settled": true, "stage": stage_row(age_days(c, now))})


func pop_events() -> Array:
	var out := events
	events = []
	return out


# ---------------------------------------------------------------- who holds it
## Whether `who` may take the baby from where it is now. ctx: {near: bool (close enough to the baby or the holder),
## hands: bool (for the player: both hands free), dead: bool}. {ok, reason} with reason one of "", "dead", "held", "far",
## "hands", "nobody".
func can_take(id: String, who: String, ctx := {}) -> Dictionary:
	if not states.has(id) or not PEOPLE.has(who):
		return {"ok": false, "reason": "nobody"}
	if bool(ctx.get("dead", false)):
		return {"ok": false, "reason": "dead"}
	var cur := holder_of(id)
	if cur == who:
		return {"ok": false, "reason": "held"}
	if PEOPLE.has(cur) and cur != who:
		pass   # a handover from the other person: allowed with the same rules
	if not bool(ctx.get("near", true)):
		return {"ok": false, "reason": "far"}
	if who == "player" and not bool(ctx.get("hands", true)):
		return {"ok": false, "reason": "hands"}
	return {"ok": true, "reason": ""}


## `who` takes the baby (from a cradle or bed, or by a handover from the other person). {ok, reason, event}.
func take(id: String, who: String, ctx := {}) -> Dictionary:
	var r := can_take(id, who, ctx)
	if not bool(r.ok):
		return r
	var from := holder_of(id)
	holders[id] = who
	var ev := {"do": "handover" if PEOPLE.has(from) else "take", "id": id, "from": from, "to": who}
	events.append(ev)
	r["event"] = ev
	return r


## The holder lays the baby in a cradle or bed. ctx: {places: ["cradle", "bed"] what exists}. {ok, reason}.
func lay_down(id: String, place: String, ctx := {}) -> Dictionary:
	if not states.has(id) or not PLACES.has(place):
		return {"ok": false, "reason": "nobody"}
	var cur := holder_of(id)
	if not PEOPLE.has(cur):
		return {"ok": false, "reason": "nobody"}
	if not (ctx.get("places", PLACES) as Array).has(place):
		return {"ok": false, "reason": "no_place"}
	holders[id] = place
	var ev := {"do": "lay", "id": id, "from": cur, "to": place}
	events.append(ev)
	return {"ok": true, "reason": "", "event": ev}


## The player gives the baby back (to the NPC parent).
func give_back(id: String, ctx := {}) -> Dictionary:
	if holder_of(id) != "player":
		return {"ok": false, "reason": "nobody"}
	return take(id, "spouse", ctx)


# ---------------------------------------------------------------- what the mother does
## The steps she takes next for one child, in order (pure): []
##   ctx: {holder, can_feed (the mother is the NPC), free (awake, at home or following, no work in hand),
##         busy (she is heading for or at work, or asleep), has_place (a cradle or bed exists), night}
##   steps: {"do": "walk", "to": "cradle"} {"do": "take"} {"do": "lay"} {"do": "sit", "kind": "sit"|"kneel"}
##          {"do": "care", "what": "feed"|"change", "minutes"} {"do": "stand"} {"do": "rock", "minutes"} {"do": "burp", "minutes"}
static func plan(s: Dictionary, ctx: Dictionary) -> Array:
	var who := String(ctx.get("holder", "spouse"))
	var steps := []
	var has_place := bool(ctx.get("has_place", false))
	var nc := needs_cfg()
	var care: Dictionary = cfg().get("care", {})
	if who == "player":
		return steps   # the player has it: she waits
	var laid := PLACES.has(who)
	if bool(ctx.get("busy", false)) or not bool(ctx.get("free", true)):
		# at work or asleep: the baby goes down (where there is a place); she never picks it up now
		if who == "spouse" and has_place:
			steps.append({"do": "walk", "to": "cradle"})
			steps.append({"do": "lay"})
		return steps
	var hungry := float(s.hunger) >= float(care.get("feed_at", 0.55)) and not bool(s.asleep)
	var wet := float(s.soiled) >= float(care.get("change_at", 0.6)) and not bool(s.asleep)
	var fret := float(s.upset) >= float(care.get("soothe_at", 0.62)) and not bool(s.asleep)
	if bool(s.asleep):
		if who == "spouse" and has_place:
			steps.append({"do": "walk", "to": "cradle"})
			steps.append({"do": "lay"})
		return steps
	if not (hungry or wet or fret):
		# content and awake: she carries it when free (out of the cradle)
		if laid and (float(s.hunger) > 0.3 or float(s.upset) > 0.2):
			steps.append({"do": "walk", "to": "cradle"})
			steps.append({"do": "take"})
		return steps
	if laid:
		steps.append({"do": "walk", "to": "cradle"})
		steps.append({"do": "take"})
	if hungry and bool(ctx.get("can_feed", true)):
		steps.append({"do": "sit", "kind": "sit"})
		steps.append({"do": "care", "what": "feed", "minutes": float(nc.get("feed_minutes", 14.0))})
		steps.append({"do": "stand"})
		steps.append({"do": "burp", "minutes": float(nc.get("burp_minutes", 2.0))})
	elif wet:
		steps.append({"do": "sit", "kind": "kneel"})
		steps.append({"do": "care", "what": "change", "minutes": float(nc.get("change_minutes", 6.0))})
		steps.append({"do": "stand"})
	else:
		steps.append({"do": "rock", "minutes": float(nc.get("soothe_minutes", 8.0))})
	return steps


# ---------------------------------------------------------------- words
static func line(path: Array) -> String:
	var v: Variant = cfg().get("lines", {})
	for k: Variant in path:
		v = (v as Dictionary).get(k, null) if v is Dictionary else null
	if v is Array and not (v as Array).is_empty():
		return String((v as Array)[randi() % (v as Array).size()])
	return String(v) if v is String else ""


## "Fed", "Wet wrappings" ... : one line of how the baby is, for the screen.
static func status_text(s: Dictionary) -> String:
	if bool(s.asleep):
		return "asleep"
	var w := wants(s)
	match w:
		"hungry":
			return "%s, hungry" % mood(s)
		"wet":
			return "%s, wants changing" % mood(s)
		"tired":
			return "%s, sleepy" % mood(s)
		"upset":
			return "%s, wants comforting" % mood(s)
	return mood(s)


func to_dict() -> Dictionary:
	return {"states": states.duplicate(true), "holders": holders.duplicate()}


## Loads a saved dict tolerantly (an old save has none: everything at its defaults, the wife holding).
func load_dict(d: Variant, family: Array) -> void:
	states = {}
	holders = {}
	events = []
	if d is Dictionary:
		var st: Variant = (d as Dictionary).get("states", {})
		var ho: Variant = (d as Dictionary).get("holders", {})
		for k: Variant in (st as Dictionary if st is Dictionary else {}):
			states[String(k)] = normalize(st[k])
		for k: Variant in (ho as Dictionary if ho is Dictionary else {}):
			var w := String(ho[k])
			holders[String(k)] = w if PEOPLE.has(w) or PLACES.has(w) else "spouse"
	sync(family)
