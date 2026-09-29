class_name HuntJob
extends RefCounted
## The household's hunting job, logic only (data/companion/hunt.json; the job is jobs.json "hunt", its `tools` the kit): a worker
## with the Hunting skill and a weapon (the one she is best at of the household's muskets, pistols, bows and throwing spears
## that has shot for it: HuntKit, out of the household's tool pool; her body walks to the rack for it first and back with it
## after) goes out by day with a knife and a meal, reads sign with
## her survival core's own hunt.track (the Hunting check: its outcome sets how far she finds game), stalks the animal her
## body picks (HuntRun, the level), shoots (shot_odds: her weapon skill and Hunting against the distance and what the animal
## is doing; fire() spends the powder and ball from the pool, settle() an arrow or spear not found again), and brings the kill
## home (HuntHaul: a smart hunter leads the household's horse out to drag it, or brings the cart or the wheelbarrow; else it is
## dragged by hand, or field-dressed where it fell and the meat and hide carried home, a quarter a trip for a big one): whole
## for the butcher at home (the butcher job, another worker's or her own), or dressed into the store. Wolves near or dusk end
## the hunt: she comes home.
##
## The hunt in hand is SpouseCore.hunt: {phase, weapon, kit, tracks, shots, quarry, species, carry, text, ...} ({} none).
## Phases: "track" (the core's hunt.track runs: she kneels over the sign), "stalk", "aim", "after" (reloading, watching the
## animal), "follow" (a wounded animal), "to_carcass", "dress" (field-dressing: `until` game minutes), "haul" (the carcass on
## her rope), "transport" (HuntHaul's trip with the horse, the cart or the barrow, or the barrow's trip back), "dress_home",
## "carry" (the meat and hide), "back" (out again for the next quarter), "retreat" (wolves), "home" (walking home to end with
## `end_text`).
## SpouseCore hooks (HUNT): offer() "hunt" -> offer(); plan() -> HuntKit.planned(); begin() -> HuntKit.arm() and started();
## the hunt.track's finish -> tracked(); _end_task() -> ended(). The site the job asks for is "game" (SpouseCore.finders["game"],
## HuntRun installs HuntGround): an object with pick_quarry(radius, weights) -> animal or null and danger() -> bool.

const PATH := "res://data/companion/hunt.json"
const JOB := "hunt"

static var _cfg := {}


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_cfg = d if d is Dictionary else {}
	return _cfg


static func line(key: String) -> String:
	return String((cfg().get("lines", {}) as Dictionary).get(key, key))


# ---------------------------------------------------------------- weapons and ammunition
static func weapons() -> Array:
	return cfg().get("weapons", [])


static func weapon_cfg(id: String) -> Dictionary:
	for wp: Dictionary in weapons():
		if String(wp.id) == id:
			return wp
	return {}


## Shots she has with `wp` in her kit (the scarcest of its ammunition per shot; throws left for the spears).
static func kit_shots(w: SpouseCore, wp: Dictionary) -> int:
	if bool(wp.get("throwable", false)):
		return int(w.hunt.get("throws", 0))
	var n := 1 << 30
	for item: String in wp.get("ammo", {}):
		var per := maxf(float(wp.ammo[item]), 0.0001)
		n = mini(n, floori(SurvivalInventory.count(w.core, item) / per + 0.0001))
	return 0 if n == 1 << 30 else n


## The store's ammunition kind for a core item ("" none) and how much one unit is.
static func store_kind_of(item: String) -> Array:
	var sa: Dictionary = cfg().get("store_ammo", {})
	for k: String in sa:
		if String(sa[k].get("item", "")) == item:
			return [k, float(sa[k].get("qty", 1.0))]
	return ["", 1.0]


## Shots she could have: her core's, and what the household's free shot (the pool's, or the store's) would add.
static func shots_available(w: SpouseCore, wp: Dictionary) -> int:
	return HuntKit.shots_available(w, wp)


## The weapon she hunts with now (HuntKit.best_weapon: the one she is best at that has shot for it, from her kit or the
## household's pool): {id, kind, skill}; {} none.
static func pick_weapon(w: SpouseCore) -> Dictionary:
	return HuntKit.best_weapon(w)


# ---------------------------------------------------------------- the offer
## Enough of the day left to go out (DAYLIGHT's end less daylight_left_h).
static func day_left(w: SpouseCore) -> bool:
	var h := w.hour()
	return h >= SpouseCore.DAYLIGHT.x and h < SpouseCore.DAYLIGHT.y - float(cfg().get("daylight_left_h", 1.5))


## Why she cannot hunt now ("" she can): the skill, the day, the ground (game to find, no wolves about), a weapon and a shot.
static func refusal(w: SpouseCore) -> String:
	HuntKit.blocked(w, "")
	if SurvivalSkills.level(w.core, "hunting") < float(cfg().get("min_skill", 10.0)):
		return "no hunter"
	if not day_left(w):
		return "too late in the day"
	var g := w.find_site("game")
	if g == null:
		return "no game about"
	if bool(g.call("danger")):
		return "wolves about"
	if pick_weapon(w).is_empty():
		HuntKit.blocked(w, line("no_kit"))      # (the Tasks tab shows what she waits for, as for the other jobs' tools)
		return line("no_kit")
	return ""


## The hunt job's offer (SpouseCore.offer, HUNT): {inputs {}, weapon, weapon_from, text} or {}.
static func offer(w: SpouseCore) -> Dictionary:
	if refusal(w) != "":
		return {}
	var p := pick_weapon(w)
	return {"inputs": {}, "weapon": String(p.id), "weapon_from": String(p.kind),
			"text": "Out hunting with the %s" % String(weapon_cfg(String(p.id)).get("name", p.id))}


## The hunt has begun (SpouseCore.begin, HUNT; the core's hunt.track is running): her kit out of the household's things
## (HuntKit.check_out: the weapon, its shot, a knife, a meal for the trip).
static func started(w: SpouseCore, o: Dictionary) -> void:
	var wp := weapon_cfg(String(o.get("weapon", "")))
	w.hunt = {"phase": "track", "weapon": String(wp.get("id", "")), "tracks": 1, "shots": 0, "quarry": null, "species": "",
			"carry": [], "kills": 0, "end_text": "", "until": 0.0}
	HuntKit.check_out(w, String(wp.get("id", "")), String(o.get("weapon_from", "")))
	w.task_text = "Reading sign"


## The hunt ends however it ends (SpouseCore._end_task, HUNT): what she still carries (a hunt called off on the way home) is
## put by, and her kit goes back where it came from (HuntKit.check_in: the weapon to its rack, the rest to the store).
static func ended(w: SpouseCore) -> void:
	if w.hunt.is_empty():
		return
	deposit(w)
	HuntKit.check_in(w)
	w.hunt = {}


static func phase(w: SpouseCore) -> String:
	return String(w.hunt.get("phase", "")) if w.task == JOB else ""


static func set_phase(w: SpouseCore, p: String, text := "") -> void:
	w.hunt["phase"] = p
	if text != "":
		w.task_text = text


# ---------------------------------------------------------------- the sign
## The hunt.track's check is over (the core's job_finished; SpouseCore HUNT hook): its outcome sets how far she finds game
## (reveal_m). Sign found: the quarry (the ground's pick) is stalked; none: she reads sign again (max_tracks), else she
## comes home with nothing.
static func tracked(w: SpouseCore, res: Dictionary) -> void:
	var r := float((cfg().get("reveal_m", {}) as Dictionary).get(String(res.get("outcome", "failure")), 0.0))
	var g := w.find_site("game")
	var q: Object = null
	if g != null and r > 0.0:
		q = g.call("pick_quarry", r, quarry_weights(w))
	if q != null:
		var sp := String(q.get("species")) if q.get("species") != null else "game"
		w.hunt["quarry"] = q
		w.hunt["species"] = sp
		w.hunt["stalk_t"] = 0.0
		set_phase(w, "stalk", "Stalking a %s" % sp)
		w._note(line("sign") % [w.name, "a " + sp])
		return
	track_again(w, line("no_sign") % w.name)


## The game she looks for with her weapon: the weapon's own quarry (the spears: small game first) or the hunt's.
static func quarry_weights(w: SpouseCore) -> Dictionary:
	var wp := weapon_cfg(String(w.hunt.get("weapon", "")))
	return wp.get("quarry", cfg().get("quarry", {}))


## Reads sign again (another hunt.track) while she has tries left; else the hunt ends with `why` (she walks home first
## when the body is out: phase "home").
static func track_again(w: SpouseCore, why: String) -> bool:
	if int(w.hunt.get("tracks", 0)) < int(cfg().get("max_tracks", 3)) and day_left(w) \
			and int(w.hunt.get("shots", 0)) < int(cfg().get("max_shots", 3)) and kit_shots(w, weapon_cfg(String(w.hunt.weapon))) > 0:
		var r := w.core.start_job("hunt.track")
		if bool(r.get("ok", false)):
			w.hunt["tracks"] = int(w.hunt.get("tracks", 0)) + 1
			w.hunt["quarry"] = null
			set_phase(w, "track", "Reading sign")
			return true
	go_home(w, why)
	return false


## She walks home and the hunt ends there with `text` (HuntRun ends it on arrival; without a body, at once).
static func go_home(w: SpouseCore, text: String, retreat := false) -> void:
	w.hunt["end_text"] = text
	set_phase(w, "retreat" if retreat else "home", "Coming home" if not retreat else "Hurrying home")


## Ends the hunt now: what she carries goes into the store (deposit) and `text` is told.
static func finish(w: SpouseCore, text := "") -> void:
	if w.task != JOB:
		return
	deposit(w)
	w._finish_timed(text if text != "" else String(w.hunt.get("end_text", line("nothing") % w.name)))
	# (a reading of sign still under way stops too: the task is over, so its interruption ends nothing more)
	if SurvivalJobs.is_running(w.core):
		w.core.cancel_job("home")


# ---------------------------------------------------------------- the shot
## What the animal is doing, for the shot: "unaware", "alert", "moving" or "running".
static func animal_state(a: Object) -> String:
	var st: Variant = a.get("state") if a != null else null
	if st == null:
		return "unaware"
	match int(st):
		WildAnimal.State.ALERT, WildAnimal.State.SENTRY:
			return "alert"
		WildAnimal.State.WANDER, WildAnimal.State.TRAVEL, WildAnimal.State.STALK:
			return "moving"
		WildAnimal.State.FLEE, WildAnimal.State.CHASE, WildAnimal.State.ATTACK, WildAnimal.State.HOLD_OFF:
			return "running"
	return "unaware"


## The skill the shot is made with (0..100): her weapon skill and her Hunting (shot.weapon_skill_share of the weapon's).
static func shot_skill(w: SpouseCore, wp: Dictionary) -> float:
	var share := float((cfg().get("shot", {}) as Dictionary).get("weapon_skill_share", 0.7))
	return share * SurvivalSkills.level(w.core, String(wp.get("skill", "marksmanship"))) + (1.0 - share) * SurvivalSkills.level(w.core, "hunting")


## The odds of a shot: {hit (the ball or arrow in the body), vital (of the hits, in the heart and lungs), clean (both)}, by
## the skill (0..100), the distance against the weapon's range (range_m: its sure range; nothing past max_m) and what the
## animal is doing (animal_state). hit = lerp(hit) by skill x (1 - falloff (d / range - 0.35)^1.5) + the state's.
static func shot_odds(skill: float, dist: float, wp: Dictionary, state := "unaware") -> Dictionary:
	var sc: Dictionary = cfg().get("shot", {})
	if dist > float(wp.get("max_m", 100.0)):
		return {"hit": 0.0, "vital": 0.0, "clean": 0.0}
	var s := clampf(skill / 100.0, 0.0, 1.0)
	var r := dist / maxf(float(wp.get("range_m", 50.0)), 1.0)
	var hr: Array = wp.get("hit", [0.5, 0.9])
	var vr: Array = wp.get("vital", [0.35, 0.8])
	var far := clampf(1.0 - float(sc.get("falloff", 0.35)) * pow(maxf(r - 0.35, 0.0), 1.5), 0.05, 1.0)
	var hit := lerpf(float(hr[0]), float(hr[1]), s) * far + float((sc.get("state", {}) as Dictionary).get(state, 0.0))
	var vital := lerpf(float(vr[0]), float(vr[1]), s) - float(sc.get("vital_dist", 0.3)) * r \
			+ float((sc.get("vital_state", {}) as Dictionary).get(state, 0.0))
	hit = clampf(hit, float(sc.get("min", 0.02)), float(sc.get("max", 0.97)))
	vital = clampf(vital, 0.05, 0.95)
	return {"hit": hit, "vital": vital, "clean": hit * vital}


## The distance she shoots from: shot_frac[0] of the weapon's sure range for a novice (seen sooner, she shoots from further
## off) down to shot_frac[1] of it for the best stalker.
static func shot_distance(w: SpouseCore) -> float:
	var wp := weapon_cfg(String(w.hunt.get("weapon", "musket")))
	var f: Array = wp.get("shot_frac", (cfg().get("stalk", {}) as Dictionary).get("shot_frac", [0.95, 0.6]))
	var s := clampf(SurvivalSkills.level(w.core, "hunting") / 100.0, 0.0, 1.0)
	return float(wp.get("range_m", 50.0)) * lerpf(float(f[0]), float(f[1]), s)


## She fires at an animal `dist` m off doing `state`: one shot's ammunition out of her kit, the check rolled.
## {ok (she had a shot), hit, vital, odds, loud, damage}. The body turns it into the real shot (HuntRun). The powder and ball
## are spent from the household's pool at once (HuntKit.used); an arrow or a spear only when it is not found again (settle).
static func fire(w: SpouseCore, dist: float, state: String, rng: RandomNumberGenerator) -> Dictionary:
	var wp := weapon_cfg(String(w.hunt.get("weapon", "")))
	if wp.is_empty() or kit_shots(w, wp) < 1:
		return {"ok": false}
	var found_again := float(wp.get("recover", 0.0)) > 0.0
	for item: String in wp.get("ammo", {}):
		SurvivalInventory.remove(w.core, item, float(wp.ammo[item]))
		if not found_again:
			HuntKit.used(w, item, float(wp.ammo[item]))
	if found_again:
		w.hunt["loose"] = int(w.hunt.get("loose", 0)) + 1
	if bool(wp.get("throwable", false)):
		w.hunt["throws"] = int(w.hunt.get("throws", 0)) - 1
	w.hunt["shots"] = int(w.hunt.get("shots", 0)) + 1
	var odds := shot_odds(shot_skill(w, wp), dist, wp, state)
	var hit := rng.randf() < float(odds.hit)
	var vital := hit and rng.randf() < float(odds.vital)
	var sk := String(wp.get("skill", ""))
	if sk == "archery":
		SurvivalSkills.record_weapon_event(w.core, sk, "full_draw_release")
	if hit and dist > (30.0 if sk == "marksmanship" else 20.0):
		SurvivalSkills.record_weapon_event(w.core, sk, "hit_beyond_30m" if sk == "marksmanship" else "hit_beyond_20m")
	return {"ok": true, "hit": hit, "vital": vital, "odds": odds, "loud": bool(wp.get("loud", false)),
			"damage": float(wp.get("damage", 100.0)), "weapon": String(wp.id)}


## A clean kill of an unaware animal teaches Hunting (and the weapon skill).
static func clean_kill(w: SpouseCore) -> void:
	SurvivalSkills.record_clean_kill(w.core)
	var wp := weapon_cfg(String(w.hunt.get("weapon", "")))
	SurvivalSkills.record_weapon_event(w.core, String(wp.get("skill", "")), "clean_kill")


## The arrow or spear of the last shot is looked for (`how` the shot went: "kill" it is in the animal, "miss" somewhere in
## the leaves past it, "wounded" gone with the animal): found again (the weapon's `recover`, less for a miss and a wounded
## animal: settle_find) it is back in her kit; lost, it is spent from the pool (HuntKit.used, HuntKit.spear_lost).
static func settle(w: SpouseCore, rng: RandomNumberGenerator, how := "kill") -> bool:
	var wp := weapon_cfg(String(w.hunt.get("weapon", "")))
	if int(w.hunt.get("loose", 0)) <= 0:
		return false
	w.hunt["loose"] = int(w.hunt.loose) - 1
	var f := float((cfg().get("settle_find", {}) as Dictionary).get(how, 1.0))
	if rng.randf() < float(wp.get("recover", 0.0)) * f:
		for item: String in wp.get("ammo", {}):
			SurvivalInventory.add(w.core, item, float(wp.ammo[item]))
		if bool(wp.get("throwable", false)):
			w.hunt["throws"] = int(w.hunt.get("throws", 0)) + 1
		return true
	for item: String in wp.get("ammo", {}):
		HuntKit.used(w, item, float(wp.ammo[item]))
	if bool(wp.get("throwable", false)):
		HuntKit.spear_lost(w)
	return false


## A kill of hers: counted (her experience as a hunter: HuntHaul.smart).
static func killed(w: SpouseCore) -> void:
	w.hunt["kills"] = int(w.hunt.get("kills", 0)) + 1
	w.core.state.flags["hunt_kills"] = int(w.core.state.flags.get("hunt_kills", 0)) + 1


# ---------------------------------------------------------------- the kill
## How the kill comes home: "haul" (dragged whole to be butchered at home: near enough and light enough) or "dress" (field-
## dressed where it lies and carried home).
## (A hunter with no transport: HuntHaul.choose decides for one with some.)
static func after_kill(dist_home: float, kg: float) -> String:
	return "haul" if HuntHaul.choose(0.0, kg, dist_home, {}) == "drag" else "dress"


## Whether a worker at home will butcher a carcass left there (the butcher job on, at home, someone other than the hunter).
static func home_butcher(w: SpouseCore) -> bool:
	for o: SpouseCore in w.stock.crew.workers:
		if o != w and o.role == "home" and bool(o.enabled.get("butcher", false)) and not o.core.is_dead():
			return true
	return false


## Game minutes to skin and butcher a carcass (dress: skin_min + butcher_min, less with Hunting: skill_scale).
static func dress_minutes(w: SpouseCore) -> float:
	var d: Dictionary = cfg().get("dress", {})
	var sc: Array = d.get("skill_scale", [1.4, 0.7])
	var k := lerpf(float(sc[0]), float(sc[1]), clampf(SurvivalSkills.level(w.core, "hunting") / 100.0, 0.0, 1.0))
	return (float(d.get("skin_min", 25.0)) + float(d.get("butcher_min", 40.0))) * k


## Skins and butchers `carcass` (its finish_dress, as the player's knife and the butcher job do): the yields go into what she
## carries (hunt.carry). Returns them ([{kind, count}]).
static func dress(w: SpouseCore, carcass: Object) -> Array:
	var got := []
	if carcass == null or not is_instance_valid(carcass) or carcass.get("meat_left") == null:
		return got
	for step: String in ["skin", "butcher"]:
		var ds := int(carcass.get("dress_step"))
		if (step == "skin" and ds != 0) or (step == "butcher" and ds != 1):
			continue
		var hands := SpouseCore.SpouseHands.new()
		carcass.call("finish_dress", step, hands)
		for e: Dictionary in hands.inventory_pack:
			got.append({"kind": String(e.kind), "count": int(e.count)})
		hands.free()
	var carry: Array = w.hunt.get("carry", [])
	carry.append_array(got)
	w.hunt["carry"] = carry
	return got


## What she carries goes into the store. Returns "3 venison, 1 deer hide" ("" nothing).
static func deposit(w: SpouseCore) -> String:
	var parts := []
	for e: Dictionary in w.hunt.get("carry", []):
		var n := w.stock.put(String(e.kind), int(e.count))
		if n > 0:
			parts.append("%d %s" % [n, InventoryState.name_of(String(e.kind)).to_lower()])
	w.hunt["carry"] = []
	return ", ".join(parts)


static func carry_text(w: SpouseCore) -> String:
	var parts := []
	for e: Dictionary in w.hunt.get("carry", []):
		parts.append("%d %s" % [int(e.count), InventoryState.name_of(String(e.kind)).to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "nothing"


# ---------------------------------------------------------------- safety
## Whether the hunt must end now: "dusk" (the day is ending), "wolves" (the ground's danger), "" (go on).
static func must_stop(w: SpouseCore) -> String:
	var h := w.hour()
	if h < SpouseCore.DAYLIGHT.x or h >= SpouseCore.DAYLIGHT.y - 0.25:
		return "dusk"
	var g := w.find_site("game")
	if g != null and bool(g.call("danger")):
		return "wolves"
	return ""
