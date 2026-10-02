extends SceneTree
## The story in the level (StoryDirector, StoryObjectives, StoryHUD; docs/main_story.md), survival on, the Prologue of
## Two Fires played through by hand:
##   Godot --headless --fixed-fps 60 --path . -s tests/story/test_story.gd -- survival=on story=two_fires
##   start    the storyline's year and day (autumn 1757), its intro cards up and the game waiting under them
##   steps    each mission's steps checked from the world: walking to the plot, felling, building, a lit fire,
##            the raid's night; a save of the place comes back
## Ends with "STORY TEST PASSED (<n> checks)" or "STORY TEST FAILED (<f> of <n>)".
var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var player: FrontierPlayer
var story: StoryDirector


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Close every card open (as Enter would), and let the director look at the world again.
func _through_cards() -> void:
	var guard := 20
	while story.hud.cards_open() and guard > 0:
		story.hud._card_open_t = 0.0
		story.hud._next_card()
		guard -= 1
	story._t = 0.0
	await _frames(3)


func _mission() -> String:
	return String(story.mission().get("id", ""))


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(25)
	b = SurvivalBridge.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	story = StoryDirector.find(self)
	_expect(b != null and player != null and story != null, "the level has the bridge, the player and the story")
	if story == null:
		_end()
		return
	player.ignore_mouse_capture = true
	for i in 90:                                 # (the cards wait a second for a character creator; none opens in a test)
		await process_frame
	# ---- the start
	_expect(SurvivalClock.year(b.core) == 1757 and SurvivalClock.day_id(b.core) == "oct_early", "the story starts in Early October 1757 (%s)" % SurvivalClock.date_string(b.core))
	_expect(story.storyline_id == "two_fires" and _mission() == "m.tf.open_land", "Two Fires begins with Open Land")
	_expect(story.hud.cards_open() and paused, "its intro cards are up and the game waits under them")
	await _through_cards()
	_expect(not paused and story.phase == StoryDirector.Phase.STEPS, "the cards closed, the game runs and the first step is on")
	_expect(story.hud._text.text.begins_with("Find the open ground"), "the step is on screen: %s" % story.hud._text.text)
	_expect(story.hud._hints.get_child_count() >= 5, "and the mission's key hints under it")
	_expect(story.hud.marker_at is Vector3, "the marker shows the plot")
	# ---- open land: walk there
	var home: Vector3 = StoryObjectives.place_point({"place": "homestead"}, story.places())
	player.global_position = home + Vector3(2, 0.5, 0)
	story._t = 0.0
	await _frames(3)
	_expect(story.hud.cards_open(), "at the plot the mission's outro card comes up")
	await _through_cards()
	_expect(_mission() == "m.tf.clearing", "then Clearing")
	# ---- clearing: three trees felled (the harvest's record of them)
	var h := VegHarvest.find(self)
	_expect(h != null, "the forest's harvest record is there")
	if h:
		var n := 0
		for i in h.lay.tree_pos.size():          # (keys are the trees' indices: three standing far from the plot)
			if n < 3 and not h.felled.has(i) and Vector2(h.lay.tree_pos[i].x, h.lay.tree_pos[i].z).length() > 300.0:
				h.felled[i] = true
				n += 1
	story._t = 0.0
	await _frames(3)
	_expect(story.hud.cards_open(), "three trees down: the clearing is done")
	await _through_cards()
	_expect(_mission() == "m.tf.shelter", "then the lean-to")
	# ---- the shelter, the fire: pieces on the plot
	var w := BuildWorld.of(self)
	w.add_piece("lean_to", Transform3D(Basis(), home + Vector3(4, 0, 0)), true, -1)
	story._t = 0.0
	await _frames(3)
	await _through_cards()
	_expect(_mission() == "m.tf.fire", "a lean-to on the plot: then Fire")
	var far := w.add_piece("campfire", Transform3D(Basis(), Vector3(0, FrontierTerrain.height_at(0, -40), -40)), true, -1)
	story._t = 0.0
	await _frames(3)
	_expect(story.step_i == 0, "a campfire far off the plot does not count")
	var fire := w.add_piece("campfire", Transform3D(Basis(), home + Vector3(-3, 0, 2)), true, -1)
	story._t = 0.0
	await _frames(3)
	_expect(story.step_i == 1, "one on the plot does: now light it (%s)" % story.hud._text.text)
	var cf: Campfire = null
	for c in fire.find_children("*", "Campfire", true, false):
		cf = c as Campfire
	_expect(cf != null, "the campfire piece has its fire")
	if cf:
		cf.state.lit = true
	story._t = 0.0
	await _frames(3)
	_expect(story.hud.cards_open(), "lit: Fire is done")
	await _through_cards()
	_expect(_mission() == "m.tf.meat", "then the hunt: its intro card")
	await _through_cards()
	_expect(story.phase == StoryDirector.Phase.STEPS and story.hud.marker_at == null, "the hunt has no marker (the deer are where they are)")
	# ---- a save of the place, and back
	var saved := story.save_data()
	_expect(String(saved.get("storyline", "")) == "two_fires" and int(saved.get("mission", -1)) == 4 and String(saved.get("phase", "")) == "steps", "a save keeps the storyline and the mission (%s)" % str(saved))
	story.mission_i = 0
	story.load_data(saved)
	_expect(_mission() == "m.tf.meat" and story.phase == StoryDirector.Phase.STEPS and not story.hud.cards_open(), "and loads back into the hunt, its cards not played again")
	# (no wild animals in a test run: the hunt is passed by hand)
	story.step_i = 99
	story._t = 0.0
	await _frames(3)
	await _through_cards()
	_expect(_mission() == "m.tf.house", "the house comes next, with its intro")
	await _through_cards()
	# ---- the house: a floor, four walls, a roof
	w.add_piece("floor", Transform3D(Basis(), home + Vector3(10, 0, 0)), true, -1)
	for i in 4:
		w.add_piece("wall", Transform3D(Basis(), home + Vector3(10 + i, 0, 3)), true, -1)
	story._t = 0.0
	await _frames(3)
	story._t = 0.0
	await _frames(3)
	_expect(story.step_i == 2, "floor and walls counted; the roof is the step now (%s %s)" % [story.hud._text.text, story.hud._count.text])
	w.add_piece("roof", Transform3D(Basis(), home + Vector3(10, 3, 1)), true, -1)
	story._t = 0.0
	await _frames(3)
	_expect(story.hud.cards_open(), "a roof on: the house is done")
	await _through_cards()
	_expect(_mission() == "m.tf.raid", "then the raid's night")
	# ---- the raid waits for mid-November at night
	story._t = 0.0
	await _frames(3)
	_expect(story.hud._text.text.begins_with("Ready the homestead"), "before mid-November it says to get ready: %s" % story.hud._text.text)
	b.core.state.minutes = SurvivalClock.minutes_at(b.core, "nov_mid", 1757, 12.0)
	story._t = 0.0
	await _frames(3)
	_expect(not story.hud.cards_open(), "mid-November at noon: not yet")
	b.core.state.minutes = SurvivalClock.minutes_at(b.core, "nov_mid", 1757, 22.0)
	story._t = 0.0
	await _frames(3)
	_expect(story.hud.cards_open() and story.hud._card_title.text.contains("1757"), "mid-November at night: the raid (%s)" % story.hud._card_title.text)
	await _through_cards()
	_expect(story.phase == StoryDirector.Phase.DONE and story.hud._title.text.contains("TAKEN IN"), "the Prologue is over; Part 1 is named as coming (%s)" % story.hud._title.text)
	far.queue_free()
	_end()


func _end() -> void:
	if fails.is_empty():
		print("STORY TEST PASSED (%d checks)" % checks)
	else:
		print("STORY TEST FAILED (%d of %d)" % [fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)
