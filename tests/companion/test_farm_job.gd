extends SceneTree
## FARM in the level: the household's farming (FarmJob; data/companion/jobs.json "hoe" and "farm").
##   ground   with a hoe in the store she breaks ground for a new bed round home (open ground, off the doorstep), up to
##            the beds the household keeps, and no more;
##   sow      a worked bed is sown with seed from the store: the Three Sisters when food is short, flax when flax is
##            short and there is no food wanted; the seed out of the store;
##   weeds    a bed a third grown wants the hoe: the weeds hoed out;
##   harvest  her body walks to a ripe bed on the navmesh, harvests it, and the crop and the seed saved back are in the
##            store; the cook job then has the corn to cook;
##   claims   a bed another worker has claimed is passed over;
##   memory   the bed remembers who broke it, sowed it, weeded and harvested it (FarmField.note); the chests' ledger has
##            who took the seed out and put the harvest in, for what (StoreLedger), and keeps it through a save;
##   skill    the work trains her Husbandry (her own gathering skills);
##   saved    the beds kept are saved with the household.
##   Godot --headless --fixed-fps 120 --path . -s tests/companion/test_farm_job.gd -- survival=on fort_plan=on
## (the fort plan furnishes the storage chests: the household store and its tool pool)
var fails := 0
var player: FrontierPlayer
var h: Household
var w: SpouseCore
var field: FarmField


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


## Only `id` of her jobs on (the others would take her elsewhere).
func _only(id: String) -> void:
	for j: String in JobBook.ids():
		w.enabled[j] = j == id


## Runs a timed job she has begun to its end (its minutes spent at once: the clock moved on and synced).
func _finish() -> void:
	w.minutes_left = 0.01
	h.bridge.core.state.minutes += 1.0
	w.sync(h.bridge.core)


func _run() -> void:
	Sharpness.slips_on = false
	await _frames(20)
	player = current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	for i in 600:
		await physics_frame
		h = Household.find(self)
		if h != null and h.body != null:
			break
	_expect(h != null and h.body != null, "the household and the wife's body are in (survival=on)")
	if h == null or h.body == null:
		quit(1)
		return
	w = h.sc
	field = FarmField.find(self)
	_expect(field != null, "the level has its fields")
	if field == null:
		quit(1)
		return
	h.set_role("stay")
	await _frames(30)
	# (a month to sow in, the beds round home none, a hoe and seed in the store)
	var core := h.bridge.core
	var day := floorf(core.state.minutes / 1440.0) * 1440.0
	core.state.minutes = day + 10.0 * 60.0
	w.sync(core)
	for key: String in field.beds_near(h.home, FarmJob.FIELD_M):
		field.beds.erase(key)
	var put_n := h.stock.put("farm_hoe", 1)   # (the household's hoe: the pool's kind; the player's own stays in the loadout)
	print("  store %s, chests %d, put %d, count %d, can_store %s, stamped %s" % [h.stock.get_script().get_global_name(),
			get_nodes_in_group(StorageChest.GROUP).size(), put_n, h.stock.count("farm_hoe"), StorageChest.can_store("farm_hoe"),
			BuildWorld.of(self, false).stamped if BuildWorld.of(self, false) else "no build world"])
	for k: String in ["seed_corn", "seed_beans", "seed_squash", "seed_flax"]:
		h.stock.put(k, 4)
	h.crew().beds_wanted = 1
	w.role = "home"
	_expect(field.can_sow_now() and not field.frozen(), "the season lets them sow")

	# ---- ground: a new bed, up to the beds kept
	_only(FarmJob.HOE)
	var o := w.offer(FarmJob.HOE)
	_expect(not o.is_empty() and String(o.get("step", "")) == "break", "with a hoe in the store she would break ground for a new bed (%s)" % o.get("text", o))
	var key := String(o.get("bed", ""))
	if key == "":
		var sp: Object = FarmJob.spot(w, field, FarmJob.HOE, [], h.home)
		print("  why: spot %s, new bed '%s', household hoes in the store %d (pool kind %s), tool pool says '%s', home %s" % [
				sp, FarmJob.new_bed(field, h.home, [], []), h.stock.count("farm_hoe"), ToolPool.is_pool("farm_hoe"),
				ToolPool.blocked_why(w, FarmJob.HOE, "-"), h.home])
		print("FARM JOB TEST FAILED (%d)" % fails)
		quit(1)
		return
	var c := field.bed_center(key)
	var from_home := Vector2(c.x - h.home.x, c.z - h.home.z).length()
	_expect(key != "" and from_home >= FarmJob.NEW_MIN_M and from_home <= FarmJob.FIELD_M, "the new bed is on open ground round home, off the doorstep (%.1f m out)" % from_home)
	_expect(w.begin(FarmJob.HOE), "she begins breaking ground (%s)" % w.task_text)
	_finish()
	_expect(field.state_of(key) == "tilled", "the bed is broken and ready to sow (%s)" % field.state_of(key))
	_expect(w.offer(FarmJob.HOE).is_empty(), "with the beds the household keeps, no more ground is broken")
	h.crew().beds_wanted = 2
	_expect(not w.offer(FarmJob.HOE).is_empty(), "keep one more and she would break ground again")
	h.crew().beds_wanted = 1

	# ---- sow: by what is short
	_only(FarmJob.FARM)
	o = w.offer(FarmJob.FARM)
	_expect(String(o.get("step", "")) == "sow" and String(o.get("sowing", "")) == "three_sisters",
			"the store short of meals: she would sow the Three Sisters (%s)" % o.get("sowing", o))
	# with the meals put by and the flax short, flax
	h.stock.put("roast_corn", 40)
	var o2 := w.offer(FarmJob.FARM)
	_expect(String(o2.get("sowing", "")) == "flax", "the meals put by and flax short: flax instead (%s)" % o2.get("sowing", o2))
	h.stock.take("roast_corn", 40)
	var corn0 := h.stock.count("seed_corn")
	var hus0 := w.gather.points_of(FarmJob.SKILL)
	_expect(w.begin(FarmJob.FARM), "she begins sowing (%s)" % w.task_text)
	_finish()
	_expect(field.state_of(key) == "growing" and String(field.beds[key].sow) == "three_sisters", "the bed is sown with the Three Sisters (%s)" % field.beds[key].get("sow", ""))
	_expect(h.stock.count("seed_corn") == corn0 - 1 and h.stock.count("seed_beans") == 3 and h.stock.count("seed_squash") == 3,
			"the seed came out of the store (corn %d, beans %d, squash %d)" % [h.stock.count("seed_corn"), h.stock.count("seed_beans"), h.stock.count("seed_squash")])
	# the store's ledger: who took the seed, for what
	var took := (h.stock.recent(12) as Array).filter(func(e: Dictionary) -> bool:
		return String(e.who) == w.name and String(e.kind) == "seed_corn" and int(e.n) == -1 and String(e.why).begins_with("Sowing"))
	_expect(not took.is_empty(), "the chest's ledger: %s" % (StoreLedger.line(took[0]) if not took.is_empty() else str(h.stock.recent(6))))
	_expect(w.gather.points_of(FarmJob.SKILL) > hus0, "sowing trained her Husbandry (%.2f -> %.2f)" % [hus0, w.gather.points_of(FarmJob.SKILL)])

	# ---- weeds: a third of the way
	var grow := float(field.data.sowings.three_sisters.grow_days) * SurvivalClock.MIN_PER_DAY
	field.beds[key]["sown"] = field.now_min() - grow * 0.4
	_only(FarmJob.HOE)
	o = w.offer(FarmJob.HOE)
	_expect(String(o.get("step", "")) == "weed", "a third grown, the bed wants weeding (%s)" % o.get("text", o))
	_expect(w.begin(FarmJob.HOE), "she begins hoeing the weeds")
	_finish()
	_expect(field.weeds_due(key) == 0 and int(field.beds[key].hoed) == 1, "the weeds are hoed out (hoed %d)" % int(field.beds[key].get("hoed", 0)))

	# ---- claims: a bed another worker holds is passed over
	field.beds[key]["sown"] = field.now_min() - grow * 1.01
	_only(FarmJob.FARM)
	h.stock.reserve(99, "s:bed:" + key, 1)
	_expect(w.offer(FarmJob.FARM).is_empty(), "the ripe bed another worker claimed is passed over")
	h.stock.release(99)

	# ---- harvest: her body walks to it and works it
	var corn_before := h.stock.count("corn")
	var body := h.body
	var t0 := Time.get_ticks_msec()
	var worked := false
	var at_bed := INF
	for i in 120 * 90:
		await physics_frame
		if w.task == FarmJob.FARM:
			at_bed = Vector2(body.global_position.x - c.x, body.global_position.z - c.z).length()
			worked = true
			break
	_expect(worked and at_bed < 2.5, "her body walked to the ripe bed and began the harvest there (%.1f m from its middle, %.1f s)" % [at_bed, (Time.get_ticks_msec() - t0) / 1000.0])
	if worked:
		_finish()
	var got := h.stock.count("corn") - corn_before
	_expect(field.state_of(key) == "tilled" and got > 0 and h.stock.count("beans") > 0 and h.stock.count("squash") > 0,
			"the harvest is in the store (corn +%d, beans %d, squash %d) and the bed is ready to sow again" % [got, h.stock.count("beans"), h.stock.count("squash")])
	_expect(h.stock.count("seed_corn") > corn0 - 1, "seed saved back with it (seed corn %d)" % h.stock.count("seed_corn"))
	# the bed's own memory, and the harvest in the ledger
	var hist := field.history(key)
	var whats := hist.map(func(e: Array) -> String: return "%s %s" % [e[1], e[2]])
	var mine := hist.filter(func(e: Array) -> bool: return String(e[1]) == w.name)
	_expect(mine.size() >= 4 and whats.any(func(x: String) -> bool: return x.contains("sowed the Three Sisters")) \
			and whats.any(func(x: String) -> bool: return x.contains("harvested")), "the bed remembers the work on it: %s" % "; ".join(whats))
	var put_in := (h.stock.recent(20) as Array).filter(func(e: Dictionary) -> bool: return String(e.who) == w.name and String(e.kind) == "corn" and int(e.n) > 0)
	_expect(not put_in.is_empty(), "the ledger has the harvest put in: %s" % (StoreLedger.line(put_in[0]) if not put_in.is_empty() else "-"))
	var chests := get_nodes_in_group(StorageChest.GROUP)
	var with_led: StorageChest = null
	for ch: Node in chests:
		if not (ch as StorageChest).ledger.is_empty():
			with_led = ch
			break
	if with_led:
		var saved := with_led.ledger_save()
		var fresh := StorageChest.new()
		fresh.ledger_load(saved)
		_expect(fresh.ledger.size() == with_led.ledger.size() and String(fresh.ledger[0].who) == String(with_led.ledger[0].who),
				"a chest's ledger comes back from its save (%d entries)" % fresh.ledger.size())
		fresh.free()
	var journal := "\n".join(w.journal.slice(maxi(w.journal.size() - 4, 0)))
	print(journal)

	# ---- the cook takes it on
	_only("cook")
	var co := w.offer("cook")
	_expect(not co.is_empty() and JobBook.expand("@raw_food").has("corn") and JobBook.expand("@cooked").has("roast_corn"),
			"the cook job has food to cook, the crops among what it cooks (%s)" % str(co.get("inputs", {})))
	var chain := JobBook.chain("farm")
	_expect(chain.has("farm") and chain.has("cook"), "the supply chain runs from the beds to the cook (%s)" % str(chain))

	# ---- saved
	h.crew().beds_wanted = 3
	var d := h.crew().to_dict()
	var back := HouseholdCrew.new()
	back.load_dict(d, core, HouseholdStock.new())
	_expect(back.beds_wanted == 3, "the beds kept are saved (%d)" % back.beds_wanted)
	print("FARM JOB TEST %s" % ("PASSED" if fails == 0 else "FAILED (%d)" % fails))
	quit(1 if fails else 0)
