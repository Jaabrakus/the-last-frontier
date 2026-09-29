class_name FarmJob
extends RefCounted
## FARM: the household's farming (user 2026-09-29: "we need to add farming to the task and supply chain and pathfinding";
## picked: the workers break ground too, sow by what the household is short of, the harvest goes to the store and on to
## the cook; farming is its own chain, and its own skill: Husbandry). Two jobs of the book (data/companion/jobs.json), both timed work at a bed of FarmField's round home (the
## player's own beds too):
##   "hoe"   break ground for a new bed while the household has fewer than it keeps (HouseholdCrew.beds_wanted), finish
##           breaking one, hoe the weeds out of a growing bed: a hoe or the digging stick from the tool pool;
##   "farm"  harvest a ripe bed into the store (the seed saved back with it), pull up frost-killed plants, sow a worked
##           bed with seed from the store: the sowing the household's shortages want most (the Three Sisters for the meals
##           through the cook, flax or tobacco for their stores), the Three Sisters when nothing is short.
## The body's finders hand SpouseCore a Spot (a bed and its step, a place with pos()): it walks there on the navmesh, works
## the job's minutes and the bed changes when they are up (done()). A bed another worker has claimed is passed over (the
## store's reservations: "s:bed:<key>").

const HOE := "hoe"
const FARM := "farm"
## The farm jobs' skill (a gathering skill: SpouseCore.gather): it sets the yield (FarmField.harvest_yield) and the pace
## (the jobs' skill_scale), and the work trains it.
const SKILL := "husbandry"
## The beds this far from home are the household's (m).
const FIELD_M := 40.0
## How many beds the household keeps by default.
const BEDS_WANTED := 4
## A new bed: no nearer home than this (the doorstep and the paths round it clear), and looked for this far round the
## household's beds (or home, the first); no more than NEW_TRIES places tried (FarmField.ground_ok asks the physics).
const NEW_MIN_M := 6.0
const NEW_SEARCH_M := 14.0
const NEW_TRIES := 48
## A place found for a new bed is kept this long (ms) before it is looked for again (plan() asks every frame she is idle).
const NEW_KEEP_MS := 4000

static var _new_bed := {}   ## home key -> {key, until}


## A bed that wants work: at `field`'s beds round `home`, `which` job's (HOE / FARM), not one of the beds in `claimed`;
## null when none.
class Spot:
	extends RefCounted
	var key := ""
	var step := ""   ## "break" (new ground), "till", "weed", "harvest", "clear", "sow"
	var field: FarmField
	## The store's reservation for it (SpouseCore._site_key).
	var claim := ""

	func _init(k: String, st: String, f: FarmField) -> void:
		key = k
		step = st
		field = f
		claim = "bed:" + k

	func pos() -> Vector3:
		return field.bed_center(key) if field != null and is_instance_valid(field) else Vector3.INF


static func spot(w: SpouseCore, field: FarmField, which: String, claimed: Array, home: Vector3) -> Object:
	if w == null or field == null or not is_instance_valid(field):
		return null
	if which == HOE and field.frozen():
		return null
	var mine := field.beds_near(home, FIELD_M)
	var best: Spot = null
	var best_r := INF
	for key: String in mine:
		if key in claimed:
			continue
		var step := ""
		var rank := 0
		match field.state_of(key):
			"breaking":
				if which == HOE:
					step = "till"
					rank = 1
			"growing":
				if which == HOE and field.weeds_due(key) > 0:
					step = "weed"
			"ripe":
				if which == FARM:
					step = "harvest"
			"dead":
				if which == FARM:
					step = "clear"
					rank = 1
			"tilled":
				if which == FARM and field.can_sow_now() and sowing_for(w) != "":
					step = "sow"
					rank = 2
		if step == "":
			continue
		var r := rank * 1000.0 + field.bed_center(key).distance_to(home)
		if r < best_r:
			best_r = r
			best = Spot.new(key, step, field)
	if best == null and which == HOE and mine.size() < wanted(w):
		var k := new_bed(field, home, mine, claimed)
		if k != "":
			best = Spot.new(k, "break", field)
	return best


## How many beds the household keeps (the Tasks tab).
static func wanted(w: SpouseCore) -> int:
	return w.stock.crew.beds_wanted if w != null and w.stock != null and w.stock.crew != null else BEDS_WANTED


## A place for a new bed ("i,j"; "" none): by the household's beds (their middle), else round home; open ground
## (FarmField.ground_ok), not a bed, not claimed, NEW_MIN_M from home at least and within FIELD_M. Kept NEW_KEEP_MS.
static func new_bed(field: FarmField, home: Vector3, mine: Array, claimed: Array) -> String:
	var hk := "%d,%d" % [roundi(home.x), roundi(home.z)]
	var kept: Dictionary = _new_bed.get(hk, {})
	var now := Time.get_ticks_msec()
	if not kept.is_empty() and now < int(kept.until) and not field.beds.has(String(kept.key)) and not (String(kept.key) in claimed):
		return String(kept.key)
	var anchor := home
	if not mine.is_empty():
		anchor = Vector3.ZERO
		for key: String in mine:
			anchor += field.bed_center(key)
		anchor /= float(mine.size())
	var c0 := field.cell_of(anchor)
	var reach := ceili(NEW_SEARCH_M / field.bed_m)
	var cells := []
	for dj in range(-reach, reach + 1):
		for di in range(-reach, reach + 1):
			var ij := Vector2i(c0.x + di, c0.y + dj)
			var c := field.center_of(ij.x, ij.y)
			var from_home := Vector2(c.x - home.x, c.z - home.z).length()
			if from_home < NEW_MIN_M or from_home > FIELD_M:
				continue
			var key := FarmField.key_of(ij.x, ij.y)
			if field.beds.has(key) or key in claimed:
				continue
			cells.append([Vector2(c.x - anchor.x, c.z - anchor.z).length(), key, ij])
	cells.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var found := ""
	for i in mini(cells.size(), NEW_TRIES):
		var ij: Vector2i = cells[i][2]
		if field.ground_ok(ij.x, ij.y):
			found = String(cells[i][1])
			break
	_new_bed[hk] = {"key": found, "until": now + NEW_KEEP_MS}
	return found


## The sowing to put in a worked bed now: of those the store has the seed for (free for her), the one the household's
## shortages want most (a crop fills a target that holds it, the food ones the meals through the cook), the Three Sisters
## first when nothing is short; "" without seed.
static func sowing_for(w: SpouseCore) -> String:
	var data := FarmField.load_data()
	var short := w.shortages()
	var food := JobBook.group("raw_food")
	var targets := JobBook.targets()
	var best := ""
	var best_v := -1.0
	for id: String in data.get("order", []):
		var sw: Dictionary = data.sowings.get(id, {})
		var ok := true
		for seed: String in sw.get("seeds", {}):
			if w._free(seed) < int(sw.seeds[seed]):
				ok = false
		if not ok:
			continue
		var v := 0.0
		for c: String in sw.get("crops", []):
			var item := String((data.crops[c] as Dictionary).item)
			for tid: String in short:
				var t: Dictionary = targets.get(tid, {})
				if item in (t.get("kinds", []) as Array) or (tid == "meals" and item in food):
					v += float(short[tid].get("frac", 1.0))
		v *= float(sw.get("bonus", 1.0))
		if v > best_v + 1e-6:
			best_v = v
			best = id
	return best


## FARM's offer for the Spot the finder gave (SpouseCore.offer): {inputs (the seed for a sowing), step, bed, text,
## sowing}, or {} when it cannot run.
static func offer(w: SpouseCore, obj: Object) -> Dictionary:
	var s := obj as Spot
	if s == null or s.field == null or not is_instance_valid(s.field):
		return {}
	var f := s.field
	var o := {"inputs": {}, "step": s.step, "bed": s.key}
	var crops := _crops_words(f, s.key)
	match s.step:
		"break":
			o.text = "Breaking ground for a new bed"
		"till":
			o.text = "Breaking ground for a bed"
		"weed":
			o.text = "Hoeing the weeds out of the %s" % crops
		"harvest":
			o.text = "Harvesting the %s" % crops
		"clear":
			o.text = "Pulling up the frost-killed %s" % crops
		"sow":
			var id := sowing_for(w)
			if id == "":
				return {}
			o.sowing = id
			o.inputs = (f.data.sowings[id].seeds as Dictionary).duplicate()
			o.text = "Sowing %s" % f.sowing_name(id)
	return o


## The job's time is up (SpouseCore._timed_done, how.done "farm"): the bed changes, what it gave goes to the store.
static func done(w: SpouseCore) -> void:
	var o: Dictionary = w._run
	var s := o.get("obj") as Spot
	var text := ""
	if s == null or s.field == null or not is_instance_valid(s.field):
		text = "%s leaves the bed: it is gone." % w.name
	else:
		var f := s.field
		var key := s.key
		match s.step:
			"break", "till":
				var r := f.strike(key, float(f.data.get("till_work", 5.0)), w.name)
				match String(r.get("event", "")):
					"tilled":
						_train(w, "tilled")
						text = "%s breaks ground for a bed: it is ready to sow." % w.name
					"frozen":
						text = "%s cannot break the ground: it is frozen." % w.name
					"blocked":
						text = "%s cannot break ground there: something is in the way." % w.name
					_:
						text = "%s works at the ground." % w.name
			"weed":
				var crops := _crops_words(f, key)
				var r := f.strike(key, float(f.data.get("weed_work", 2.0)), w.name)
				if String(r.get("event", "")) == "weeded":
					_train(w, "weeded")
					text = "%s hoes the weeds out of the %s." % [w.name, crops]
				else:
					text = "%s finds no weeds to hoe." % w.name
			"sow":
				var id := String(o.get("sowing", ""))
				var took := {}
				var ok := id != "" and f.state_of(key) == "tilled" and f.can_sow_now()
				for seed: String in (o.inputs as Dictionary):
					if not ok:
						break
					var n := int(o.inputs[seed])
					var got := w.stock.take_for(w.worker_id, seed, n, w.name, "Sowing %s" % f.sowing_name(id))
					took[seed] = got
					ok = got >= n
				if ok and f.sow_bed(key, id, w.name):
					_train(w, "sown")
					text = "%s sows %s: ripe in about %d days." % [w.name, f.sowing_name(id), int(f.data.sowings[id].get("grow_days", 4.0))]
				else:
					for seed: String in took:
						w.stock.put(seed, int(took[seed]), w.name, "could not sow")
					text = "%s cannot sow the bed now." % w.name
			"harvest":
				var crops := _crops_words(f, key)
				var got := f.take_harvest(key, float(w.gather.level(SKILL)), w.name)
				if got.is_empty():
					text = "%s finds nothing ripe." % w.name
				else:
					_train(w, "harvest")
					var parts := []
					var seed := 0
					for k: String in got:
						w.stock.put(k, int(got[k]), w.name, "the %s harvest" % crops)
						if k.begins_with("seed_"):
							seed += int(got[k])
							continue
						parts.append(StoreLedger.count_words(k, int(got[k])))
					text = "%s harvests the %s: %s into the store%s." % [w.name, crops, ", ".join(parts),
							", and %d seed saved" % seed if seed > 0 else ""]
			"clear":
				text = "%s pulls up the frost-killed plants." % w.name if f.clear_bed(key, w.name) else "%s finds the bed clear." % w.name
	w._finish_timed(text)


## Her Husbandry trained by a step of the work (gathering.json husbandry xp: tilled, weeded, sown, harvest).
static func _train(w: SpouseCore, event: String) -> void:
	w.gather.award(SKILL, w.gather.xp(SKILL, event))


static func _crops_words(f: FarmField, key: String) -> String:
	var r: Dictionary = f.beds.get(key, {})
	return f._crops_words(String(r.get("sow", ""))) if String(r.get("sow", "")) != "" else "bed"
