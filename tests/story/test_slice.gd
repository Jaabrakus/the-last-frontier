extends SceneTree
## The vertical slice played through (docs/main_story.md 15 item 1: Two Fires, missions 1-12 and 14 on the valley's two baked
## squares, the reveal and the first Sway lock): a new game of Two Fires on the real level (survival, saves; the menu's
## way: StoryDirector.incoming), every mission's steps driven by the test (the player put at the places, a felled tree
## through the felling API, built pieces through BuildWorld, a deer down, the clock moved on, the talks answered, the Sway's
## aim held) and the real director, stages and systems doing the rest:
##   Godot --headless --fixed-fps 60 --path . -s tests/story/test_slice.gd -- survival=on save=on
##   start    the 1757 layer on (its farms built, no bison), Margaretha's contact, the Sway caster; the title card first
##   act 1    Open Land, Clearing (three trees of the homestead's own wood), the lean-to, Fire, the hunt (Neighbours next),
##            Neighbours (Margaretha's post at the fort hidden while she is at her farm), the house, the Third Warning (the
##            hidden count 3; the Rauchs stay home; a bar of lead in the cache)
##   raid     the farms alight, the warned waiting (by name); one brought to the ford and saved; a save and a load on the run
##            (the clock not moved on, the one saved not waiting again); the party at the clearing (no marker), the player
##            taken (bound), the raiders off the farms, the torch to his house; a save and a load taken (the party round him
##            at once); the taken cards
##   march    Leclerc and the marines handed on, Jost, the crust, the camp and its fire; the raid's men gone after
##   fire     the weather held clear; two ships fight over the camp (SkyBattle, seen from the raiders' camp), the sky to
##            be struck beside the wonder's giant as it stands that night; a save while they fight (the real first
##            battle) loads with the battle played again from its start (the sky shut, the camp's fire where it was); the
##            watch held while they fight (its marker on the fight; seen meanwhile, it does not fail), all eyes up (the guards' muskets, Leclerc craning,
##            not at his captive, Jost on his feet); the sky struck cracks, held small (SkyTear, the flag wonder), the camp
##            cries out; a save then plays it again too; the cutter falls (the crack still small) and the wreck comes down
##            (at the layer's bench), the break let go, the camp's eyes on the wreck and its guards running for the pines,
##            the marker on the break; the hunter gone, the sky open (tf.sky_open); a save then loads at the end of it
##            (the wreck down, the sky open, the camp's fire where it was, the guards looking at the wreck); a retry's
##            battle shuts the sky first; the bonds slipped with Jost; to the wreck; the keel's smoke under the open sky
##            (not opened again)
##   save     a save and a load mid-mission (a new level): the mission and step, the wreck where it lay, the sky open, the
##            layer not placed twice, the player where he stood
##   lock     the first lock on the spar (the crosshair put on it once, the aim held still) lifts it, sets it down clear of
##            the stranger, and frees him; the Form spells granted (the caster's granted list: with the Sway's free use every
##            spell is known anyway; its "Your hands know something new" line only without free use); the captain's Wayglass
##   rook     Rook (no shadow) walks the player to the ford by the dead stock; the stages gone in Ash (told), the cache's lead
##            given back and Vane's blanket
##   lesson   December at dusk: Rook on the ice, Gust granted; Gust put out the lantern, blew the hat off its post and caught
##            a running wolf; the wall, Vane; the slice ends waiting on Salvage
## Ends with "SLICE TEST PASSED (<n> checks)" or "SLICE TEST FAILED (<f> of <n>)".

const SLOT := "slice_test"

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var player: FrontierPlayer
var story: StoryDirector
var world: BuildWorld
var fire: FireSpread
var caster: SwayCaster
var home := Vector3.ZERO
var _t0 := 0


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	_run.call_deferred()


# --- Driving ---------------------------------------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _mission() -> String:
	return String(story.mission().get("id", ""))


func _step() -> String:
	var s := story.step()
	return String(s.get("id", s.get("kind", "")))


func _f(k: String) -> Variant:
	return story.flag(k)


## Frames until `cond` holds (up to `limit` s of game time), the cards closed and the talks answered meanwhile: at each turn
## the first answer that begins with one of `picks` (each used once, in order), else the first one shown. True when it held.
func _pump(cond: Callable, limit := 10.0, picks: Array = []) -> bool:
	var left := picks.duplicate()
	var t := 0.0
	while t < limit:
		if cond.call():
			return true
		if story.hud.cards_open() and story.hud._waiting.is_empty():
			story.hud._card_open_t = 0.0
			story.hud._next_card()
		var dl := StoryDialogue.find(self)
		if dl != null and not dl._closed:
			if dl.typing():
				dl.advance()
			elif not dl.choices.is_empty():
				var k := 0
				for p: String in left:
					var j := dl.choice_index(p)
					if j >= 0:
						k = j
						left.erase(p)
						break
				dl.choose(k)
			else:
				dl.advance()
		story._t = minf(story._t, 0.05)
		await process_frame
		t += 1.0 / 60.0
	return cond.call()


## On to the mission `id` (its cards and talks taken as they come).
func _to_mission(id: String, limit := 10.0, picks: Array = []) -> bool:
	var there := func() -> bool:
		return _mission() == id and story.phase == StoryDirector.Phase.STEPS and not story.hud.cards_open()
	return await _pump(there, limit, picks)


## On to the step `id` of the mission at hand.
func _to_step(id: String, limit := 10.0, picks: Array = []) -> bool:
	var there := func() -> bool:
		return story.phase == StoryDirector.Phase.STEPS and _step() == id and not story.hud.cards_open() \
				and not StoryDialogue.is_open(self)
	return await _pump(there, limit, picks)


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z), p.z)


func _place(name: String) -> Vector3:
	return StoryObjectives.place_point({"place": name}, story.places())


func _put(p: Vector3) -> void:
	player.global_position = _ground(p) + Vector3.UP * 0.15
	player.velocity = Vector3.ZERO


func _flat(a: Vector3, c: Vector3) -> float:
	return Vector2(a.x - c.x, a.z - c.z).length()


func _clock(day: String, hour: float) -> void:
	b.core.state.minutes = SurvivalClock.minutes_at(b.core, day, 1757, hour)
	story._t = 0.0


func _piece(type: String, at: Vector3, yaw := 0.0, lift := 0.0) -> BuiltPiece:
	return world.add_piece(type, Transform3D(Basis(Vector3.UP, yaw), _ground(at) + Vector3.UP * lift), true, -1)


## The camera turned so the crosshair's ray goes through `p` (SwayCaster's query is the camera's ray).
func _aim(p: Vector3) -> void:
	var d := p - player.camera.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = atan2(d.y, Vector2(d.x, d.z).length())


## The aim held on `pt` (a Callable giving the point) until the lock is full, then let go: whether it cast.
func _lock(pt: Callable, limit := 6.0) -> bool:
	var n0 := SwayCaster.cast_count()
	caster.held_override = true
	var t := 0.0
	var full := false
	while t < limit:
		await physics_frame
		_aim(pt.call())
		t += 1.0 / Engine.physics_ticks_per_second
		if caster.state == SwayCaster.State.FULL:
			full = true
			break
	for i in 2:
		await physics_frame
		_aim(pt.call())
	caster.held_override = false
	await _ticks(4)
	caster.held_override = null
	if not full:
		print("  (no full lock: state %s, last break %s, hint %s, readied %s, blocked %s)" % [SwayCaster.State.keys()[caster.state],
				caster.last_break, caster.hint, caster.readied, caster.blocked()])
	return SwayCaster.cast_count() > n0


## The one tagged `tag` in story_people (not on its way out), or null.
func _tagged(tag: String) -> StoryWalker:
	for n in get_nodes_in_group(&"story_people"):
		if String(StoryObjectives._prop(n, "tag")) == tag and not n.is_queued_for_deletion():
			return n as StoryWalker
	return null


## Rook (a StoryWalker tagged rook in story_people), or null.
func _rook_node() -> StoryWalker:
	for n in get_nodes_in_group(&"story_people"):
		if String(StoryObjectives._prop(n, "tag")) == "rook" and not n.is_queued_for_deletion():
			return n as StoryWalker
	return null


## The storyline contact `id` (StoryContact), or null.
func _contact(id: String) -> StoryContact:
	for c in get_nodes_in_group(StoryContact.CONTACTS):
		if (c as StoryContact).id == id:
			return c as StoryContact
	return null


## The fighters alive that are not the story's scripted ones (the raiders), by name.
func _hostile() -> Array:
	var out: Array = []
	for f: NpcFighter in NpcSenses.fighters:
		if is_instance_valid(f) and not f.is_dead() and not f.is_queued_for_deletion() and not (f is StoryActor and (f as StoryActor).scripted):
			out.append(String(f.name))
	return out


## The crosshair put on `t` once and the aim then held still (the mouse not moved) until the lock is full, then let go:
## whether it cast.
func _lock_still(t: Node3D, limit := 6.0) -> bool:
	var n0 := SwayCaster.cast_count()
	caster.held_override = false
	for i in 30:
		_aim(t.global_position)
		await physics_frame
	caster.held_override = true
	var hz := float(Engine.physics_ticks_per_second)
	var full := false
	for i in int(limit * hz):
		await physics_frame
		if caster.state == SwayCaster.State.FULL:
			full = true
			break
	await _ticks(2)
	caster.held_override = false
	await _ticks(4)
	caster.held_override = null
	if not full:
		print("  (no full lock: state %s, last break %s, hint %s, readied %s, blocked %s)" % [SwayCaster.State.keys()[caster.state],
				caster.last_break, caster.hint, caster.readied, caster.blocked()])
	return SwayCaster.cast_count() > n0


func _hands_free() -> void:
	for i in 12:
		if player.hands_free:
			return
		if not player.is_switching():
			player.toggle_hands_free()
		await _ticks(15)


## The level's own (again after a load).
func _find() -> void:
	b = SurvivalBridge.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	story = StoryDirector.find(self)
	world = BuildWorld.of(self)
	fire = FireSpread.find(self)
	caster = SwayCaster.of(player) if player else null
	if player:
		player.ignore_mouse_capture = true
		player.max_health = 100000.0
		player.health = player.max_health          # (a stray ball or bite is no part of this test)


# --- The run ---------------------------------------------------------------------------------------------------------

func _run() -> void:
	_t0 = Time.get_ticks_msec()
	StoryDirector.incoming = "two_fires"           # (the main menu's New game)
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(25)
	_find()
	_expect(b != null and player != null and story != null and world != null, "the level has the survival bridge, the player, the story and the building")
	if b == null or player == null or story == null or world == null:
		_end()
		return
	await _frames(90)                              # (the cards wait a second for a character creator; none opens in a test)
	await _start()
	if fails.is_empty():
		await _act1()
	if fails.is_empty():
		await _raid()
	if fails.is_empty():
		await _march()
	if fails.is_empty():
		await _two_fires()
	if fails.is_empty():
		await _save_and_load()
	if fails.is_empty():
		await _the_lock()
	if fails.is_empty():
		await _rook()
	if fails.is_empty():
		await _lesson()
	_end()


func _start() -> void:
	_expect(story.storyline_id == "two_fires" and _mission() == "m.tf.open_land", "a new game of Two Fires begins with Open Land")
	_expect(StoryLayer.active_id() == "1757" and StoryLayer.farm_pieces("farm_ott").size() > 5 and StoryLayer.farm_pieces("rauch_farm").size() > 20,
			"the 1757 layer is on: the Flatts farms stand (Ott %d pieces, the Rauchs %d)" % [StoryLayer.farm_pieces("farm_ott").size(), StoryLayer.farm_pieces("rauch_farm").size()])
	_expect(int(StoryLayer.animals_of("open_land", {"bison": 40, "mammoth": 4, "deer": 20}).get("bison", -1)) == 0,
			"no bison on the open land in the story's years")
	var margaretha := false
	for c in get_nodes_in_group(StoryContact.CONTACTS):
		if (c as StoryContact).id == "contact.tf.margaretha":
			margaretha = true
	_expect(margaretha, "Margaretha's contact is in the world")
	_expect(caster != null, "the player has the Sway caster (nothing granted: %s)" % str(caster.granted if caster else []))
	_expect(story.hud.cards_open() and story.hud._card_text.text.begins_with("There were two fires"),
			"the title card comes first: %s" % story.hud._card_text.text.left(60))
	home = _place("homestead")


func _act1() -> void:
	await _to_mission("m.tf.open_land")
	_put(home + Vector3(2, 0, 0))
	_expect(await _to_mission("m.tf.clearing"), "Open Land: at the homestead across the ford, then Clearing")
	# three trees down through the felling (VegHarvest.remove_tree: the felled record the step counts): the homestead's own
	# wood's (VegWoodlots), a short walk from where the house goes
	var h := VegHarvest.find(self)
	var n := 0
	var far := 0.0
	if h:
		for d: Dictionary in h.near(home, 80.0):
			if n < 3 and String(d.type) == "tree" and not h.remove_tree(int(d.i)).is_empty():
				n += 1
				far = maxf(far, _flat(d.pos, home))
	_expect(n == 3 and await _to_mission("m.tf.shelter"), "Clearing: three trees of the homestead's wood felled (within %.0f m), then A Roof of Brush" % far)
	_piece("lean_to", home + Vector3(4, 0, 0))
	_expect(await _to_mission("m.tf.fire"), "a lean-to on the ground, then Fire")
	var lit := _piece("campfire", home + Vector3(-3, 0, 2))
	await _pump(func() -> bool: return story.step_i == 1, 3.0)
	for c in lit.find_children("*", "Campfire", true, false):
		(c as Campfire).state.lit = true
	_expect(await _to_mission("m.tf.meat") and bool(_f("tf.tinderbox")), "Fire: laid and lit (the tinderbox), then the hunt")
	# a deer down (the hunt's own world record: a carcass)
	var deer := WildlifeSpecies.make("deer")
	deer.name = "SliceDeer"
	deer.setup("deer", null, null, 1757)
	current_scene.add_child(deer)
	deer.global_position = _ground(home + Vector3(30, 0, 10)) + Vector3.UP * 0.05
	await _ticks(5)
	deer._die("player", false)
	_expect(await _to_mission("m.tf.neighbours") and bool(_f("tf.deer_down")), "Meat for Winter: a deer down, then Neighbours")
	_expect(_tagged("margaretha") != null and _tagged("anna") != null and _tagged("jost") != null and _tagged("vane") != null
			and _flat(_tagged("margaretha").global_position, _place("rauch_farm")) < 4.0, "the Rauchs stand at their farm, Vane at the store")
	await _frames(120)
	var post := _contact("contact.tf.margaretha")
	_expect(post != null and not post.visible, "one Margaretha at a time: her post at the fort hidden while she stands at her farm")
	StoryEffects.give(self, "venison", 2)
	_put(_place("rauch_farm") + Vector3(3, 0, 3))
	await _pump(func() -> bool: return story.step_i >= 1, 4.0)
	_expect(StoryObjectives.pack_count(self, "venison") == 0, "the venison carried to the Rauch farm and handed over")
	await _pump(func() -> bool: return story.step_i >= 2, 20.0, ["You know that stump", "Margaretha says", "Where do they go", "I would like that"])
	_expect(bool(_f("tf.met_rauchs")) and bool(_f("tf.knows_hymn")), "sat with the Rauchs (Anna's hymn learned)")
	_put(_place("fort_store") + Vector3(1, 0, 0))
	_expect(await _to_mission("m.tf.house", 20.0, ["Margaretha Rauch says", "I'll sign"]), "Vane's credit at the fort's store, then the house")
	await _frames(120)
	_expect(post != null and post.visible and _f(StorySlice.HERE_FLAG + "margaretha") == null, "her post at the fort again once Neighbours is over")
	_piece("floor", home + Vector3(10, 0, 0))
	_piece("wall", home + Vector3(10, 0, -1.5))
	_piece("wall", home + Vector3(10, 0, 1.5))
	_piece("wall", home + Vector3(8.5, 0, 0), PI * 0.5)
	_piece("wall", home + Vector3(11.5, 0, 0), PI * 0.5)
	await _pump(func() -> bool: return story.step_i == 2, 4.0)
	_piece("roof", home + Vector3(10, 0, 0), 0.0, 2.6)
	_expect(await _to_mission("m.tf.third_warning"), "a house of floor, walls and roof; the Rauchs met: The Third Warning")
	await _frames(40)
	_expect(_tagged("vane") == null and _tagged("brenner") != null and _tagged("wendel") != null and _tagged("ott") != null
			and _tagged("margaretha") != null, "Neighbours' people gone with it; the four families at their farms")
	_clock("nov_early", 10.0)
	_put(_place("rauch_farm") + Vector3(3, 0, 3))
	await _pump(func() -> bool: return story.step_i >= 2, 20.0, ["What do you want", "You know your own house best"])
	_expect(not _f("tf.rauchs_to_fort"), "the Rauchs keep to their own house")
	_put(_place("farm_brenner") + Vector3(3, 0, 3))
	await _pump(func() -> bool: return story.step_i >= 3, 20.0, ["Sleep in your clothes"])
	_put(_place("farm_wendel") + Vector3(3, 0, 3))
	await _pump(func() -> bool: return story.step_i >= 4, 20.0, ["Let them laugh"])
	_put(_place("farm_ott") + Vector3(3, 0, 3))
	await _pump(func() -> bool: return story.step_i >= 5, 20.0, ["Konrad Brenner"])
	_expect(int(_f("tf.warned_count")) == 3 and bool(_f("tf.warned_all")), "farm to farm: the hidden count is 3 (%s)" % str(_f("tf.warned_count")))
	StoryEffects.give(self, "bar_lead", 1)
	_put(_place("cache") + Vector3(1, 0, 0))
	_expect(await _to_mission("m.tf.raid", 20.0, ["Bury a bar of lead", "That will do"]) and int(_f("tf.cache.bar_lead")) == 1,
			"a bar of lead buried in the cache by the fallen oak, then the raid's night")


func _raid() -> void:
	NpcSenses.daylight_override = NpcSenses.NIGHT     # (headless has no sky clock: the fighters' night set by hand)
	_clock("nov_mid", 22.0)
	_expect(await _to_step("alarm", 5.0) or StoryDialogue.is_open(self), "mid-November at night: the raid (the alarm)")
	var raid := RaidStage.find(self)
	_expect(raid != null and raid.farms.size() == 4 and raid.neighbours.size() == 3,
			"the raid staged: four farms, the three families warned waiting in the fields (%d)" % (raid.neighbours.size() if raid else -1))
	if raid == null:
		return
	await _pump(func() -> bool: return _step() == "run", 10.0, ["Go and get them"])
	var burning := 0
	for id in ["farm_brenner", "farm_wendel", "farm_ott", "rauch_farm"]:
		for p in StoryLayer.farm_pieces(id):
			if fire.is_burning(p):
				burning += 1
				break
	_expect(burning == 4 and raid.stand_ins.is_empty(), "the four farms alight, their own pieces (no stand-ins: %d)" % burning)
	var hour := SurvivalClock.hour(b.core)
	_expect(hour >= 2.9 and hour < 4.0, "the clock on to 3 a.m. (%.2f)" % hour)
	# one of them brought to the ford: the Brenners' (the warned families' farms first)
	var e: Dictionary = raid.neighbours[0]
	var w := e.w as StoryWalker
	_expect(_flat(w.global_position, raid.farms[0]) < 45.0 and _flat(raid.farms[0], _place("farm_brenner")) < 1.0,
			"the first waits by the Brenners' farm (%.0f m)" % _flat(w.global_position, raid.farms[0]))
	var names: Array = []
	for ne: Dictionary in raid.neighbours:
		names.append((ne.w as StoryWalker).label)
	_expect(names == ["Konrad Brenner", "Barbara Wendel", "Hans Ott"], "the ones waiting are the families warned, by name: %s" % str(names))
	_put(w.global_position + Vector3(2.0, 0.0, 0.0))
	await _pump(func() -> bool: return String(e.state) == "following", 3.0)
	_expect(String(e.state) == "following", "near him, he gets up and follows")
	var ford := _place("ford")
	_put(ford + Vector3(16.0, 0.0, 0.0))
	w.global_position = _ground(ford + Vector3(9.0, 0.0, 1.0)) + Vector3.UP * 0.1
	await _pump(func() -> bool: return String(e.state) in ["crossing", "safe", "gone"] and _step() == "home", 20.0, ["Go back for Jost"])
	_expect(String(e.state) in ["crossing", "safe", "gone"] and bool(_f("tf.jost_taken")), "at the ford he wades over; Jost went back for the dog (%s)" % String(e.state))
	await _pump(func() -> bool: return raid.saved >= 1, 25.0)
	_expect(raid.saved == 1 and int(_f("tf.raid_saved")) == 1, "one saved over the ford (tf.raid_saved %s)" % str(_f("tf.raid_saved")))
	# a save and a load on the run (the autosave, F5): the raid goes on as it was
	var m0 := b.core.state.minutes
	var si := story.step_i
	_expect(await _reload(), "saved on the run and loaded")
	await _pump(func() -> bool: return RaidStage.find(self) != null, 3.0)
	raid = RaidStage.find(self)
	_expect(raid != null and story.step_i == si and absf(b.core.state.minutes - m0) < 30.0 and raid.saved == 1 and int(_f("tf.raid_saved")) == 1
			and raid.neighbours_in("waiting") == 2,
			"loaded on the run: the clock not moved on (%.0f min), the one saved over the ford not waiting again (%d waiting, %d saved)"
			% [b.core.state.minutes - m0, raid.neighbours_in("waiting") if raid else -1, raid.saved if raid else -1])
	if raid == null:
		return
	_put(home + Vector3(-3, 0, -2))
	_expect(await _pump(func() -> bool: return _step() == "taken", 5.0), "back up the bank to the clearing")
	await _pump(func() -> bool: return raid.phase in ["party", "capture", "torch", "done"], 5.0)
	_expect(raid.phase != "run" and story.hud.marker_at == null, "the party comes up from behind; no marker shows where it waited (%s)" % raid.phase)
	await _pump(func() -> bool:
		var c := Captivity.find(self)
		return c != null and c.is_active() and _step() == "bound", 30.0)
	var cap := Captivity.find(self)
	_expect(cap != null and cap.is_active() and cap.captor == raid.leclerc and raid.leclerc.last_bark == RaidStage.LINE,
			"taken at the clearing: bound, Leclerc the captor, his line in French (step %s, raid %s, captive %s, %.1f m from Leclerc, talk open %s)"
			% [_step(), raid.phase, str(cap.is_active() if cap else null), _flat(player.global_position, raid.leclerc.global_position),
			str(StoryDialogue.is_open(self))])
	_expect(raid.squads.is_empty() and _hostile().is_empty(), "taken, the raiders leave the farms: nobody left to shoot the bound man (%s)" % str(_hostile()))
	await _pump(func() -> bool: return raid.house_lit > 0, 30.0)
	var roof_burns := false
	for p in world.near(home, 18.0):
		if p.type == "roof" and fire.is_burning(p):
			roof_burns = true
	_expect(raid.house_lit > 0 and roof_burns, "a marine's torch to the roof the player raised: it burns (%d pieces)" % raid.house_lit)
	# a save and a load taken: the party round him at once, Leclerc his captor again (no 240 s at home, no bonds coming off)
	_expect(await _reload(), "saved taken and loaded")
	await _pump(func() -> bool: return RaidStage.find(self) != null and RaidStage.find(self).phase in ["torch", "done"], 3.0)
	raid = RaidStage.find(self)
	cap = Captivity.find(self)
	await _ticks(Engine.physics_ticks_per_second * 4)     # (past Captivity's grace for a captor)
	_expect(raid != null and cap != null and cap.is_active() and cap.bound and cap.captor == raid.leclerc and _step() == "bound"
			and _flat(raid.leclerc.global_position, player.global_position) < 4.0 and raid.squads.is_empty(),
			"loaded taken: still bound, the party round him at once, Leclerc his captor, no raiders (%s, captor %s)"
			% [raid.phase if raid else "?", str(cap.captor if cap else null)])
	if raid == null:
		return
	story.step_t = 30.0                             # (the 20 s after it)
	var seen := {}                                  # (a lambda's locals are its own: the record in a dictionary)
	await _pump(func() -> bool:
		if story.hud.cards_open() and story.hud._card_title.text == "12 November 1757":
			seen["cards"] = true
		return _mission() == "m.tf.march" and story.phase == StoryDirector.Phase.STEPS and not story.hud.cards_open(), 10.0)
	_expect(seen.has("cards") and _mission() == "m.tf.march" and story.outcomes.get("m.tf.raid") == "taken",
			"the raid ends taken, its own cards, then The March (%s %s, outcome %s)" % [_mission(), _step(), str(story.outcomes.get("m.tf.raid"))])


func _march() -> void:
	var m := MarchStage.find(self)
	var raid := RaidStage.find(self)
	_expect(m != null and raid != null and m.leclerc == raid.leclerc and m.guards.size() == 2 and m.jost != null,
			"the march: Leclerc and the two marines handed on from the raid, Jost beside the player")
	if m == null:
		return
	var cap := Captivity.find(self)
	await _pump(func() -> bool: return cap.marching, 5.0)
	_expect(cap.is_active() and cap.marching and cap.captor == m.leclerc, "the forced march begins behind Leclerc")
	_expect(_hostile().is_empty(), "no raider left on the farms the column passes (%s)" % str(_hostile()))
	cap.march_m = m._route_length() * 0.6
	await _pump(func() -> bool: return m.crust_given, 3.0)
	var crusts := StoryObjectives.pack_count(self, "item.food.biscuit")
	_expect(m.crust_given and crusts >= 1, "half way Leclerc shares a crust (the biscuit in the kit)")
	# a save and a load on the march: the stage made again round the player, the march going on, no second crust
	var mi := story.mission_i
	var si := story.step_i
	_expect(await _reload(), "saved on the march and loaded")
	m = MarchStage.find(self)
	cap = Captivity.find(self)
	await _pump(func() -> bool: return MarchStage.find(self) != null and Captivity.find(self).marching, 5.0)
	m = MarchStage.find(self)
	_expect(story.mission_i == mi and story.step_i == si and m != null and m.leclerc != null and cap.is_active() and cap.marching
			and cap.captor == m.leclerc and m.jost != null and _flat(m.leclerc.global_position, player.global_position) < 5.0,
			"loaded on the march: Leclerc, the guards and Jost made again by the player, still bound and marching")
	if m == null:
		return
	await _ticks(60)
	_expect(m.crust_given and StoryObjectives.pack_count(self, "item.food.biscuit") == crusts, "no second crust after the load (%d)"
			% StoryObjectives.pack_count(self, "item.food.biscuit"))
	cap.route_i = cap.route.size() - 1
	var last: Vector3 = cap.route.back()
	m.leclerc.global_position = _ground(last + Vector3(0.0, 0.0, 1.5)) + Vector3.UP * 0.1
	_put(last + Vector3(0.0, 0.0, 4.0))
	await _pump(func() -> bool: return m.phase == "camp", 8.0)
	_expect(m.phase == "camp" and m.camp_fire != null and m.camp_fire.is_lit(), "at the raiders' camp a fire is lit")
	await _pump(func() -> bool: return _step() == "survive_until", 15.0, ["Keep it for later", "Touch your chest"])
	_expect(_step() == "survive_until" and bool(_f("tf.knows_toussaint")), "at the camp, his name: Toussaint")
	b.core.state.minutes = float(story.base.get("until", b.core.state.minutes)) + 5.0
	_expect(await _to_mission("m.tf.two_fires", 10.0) or StoryDialogue.is_open(self), "the day lasted out: Two Fires")
	_expect(RaidStage.find(self) == null, "the raid's men are off the farms (end_stages raid)")


func _two_fires() -> void:
	var m := MarchStage.find(self)
	var rig := current_scene.get_node_or_null("EnvironmentRig") as EnvironmentRig
	var dn: DayNight = rig.clock_driver if rig != null else null
	# (headless the rig has no sky and no clock of its own, DayNight: the weather and the giant are the windowed runs')
	_expect(dn == null or (dn.weather.kind == WeatherSystem.Kind.CLEAR and not dn.weather.front_active
			and _f(StorySlice.CLEAR_FLAG) is Array), "Two Fires: the weather held clear for the reveal (clear_sky: %s)"
			% (str(_f(StorySlice.CLEAR_FLAG)) if dn != null else "headless: no sky clock"))
	await _pump(func() -> bool: return SkyBattle.find(self) != null, 15.0)
	var sb := SkyBattle.find(self)
	_expect(sb != null and WreckFall.find(self) == null and _step() == "watch",
			"at the fire Leclerc's words again, then two ships fight in the sky (SkyBattle; no wreck yet)")
	if sb == null:
		return
	_expect(sb._people.size() == WreckFall.PEOPLE.size() and sb.clock < SkyBattle.PEOPLE_AT[0]
			and current_scene.get_node_or_null(SkyBattle.PEOPLE_NODE) == null,
			"the wreck's two people made ready during the fire talk (SkyBattle.prepare), the battle took them as it began (%s)"
			% str(sb._people.keys()))
	var giant := WonderLook.giant_dir(rig)
	var aim := (sb.tear_aim() - sb.camp).normalized()
	if giant != Vector3.ZERO:
		_expect(sb.sky_mark.angle_to(giant) < 0.01 and rad_to_deg(aim.angle_to(giant)) < 20.0,
				"the sky to be struck beside the wonder's giant as it stands tonight (%.0f deg off it)" % rad_to_deg(aim.angle_to(giant)))
	else:
		_expect(sb.sky_mark == Vector3.ZERO and aim.y > 0.3,
				"headless (no sky clock, no giant to mark): the sky to be struck high over the fight (%.0f deg up)" % rad_to_deg(asin(aim.y)))
	var bench := StoryLayer.place("wreck_site")
	var camp := _place("raiders_camp")
	_expect(_flat(sb.crash_at, bench) < 0.5 and absf(sb.heading - deg_to_rad(150.0)) < 0.01 and _flat(sb.camp, camp) < 0.5,
			"seen from the raiders' camp, the cutter to come down on the layer's bench (wreck_site), turned along it")
	var looked := true
	for g in m.guards:
		looked = looked and not g.watch
	_expect(looked, "the camp's guards stop watching the captives")
	# a save while the ships fight (the real first battle, before the sky is struck): loaded, it plays again from its start
	await _pump(func() -> bool: return sb.clock > 3.0, 8.0)
	var fire0 := m.camp_fire.global_position if m.camp_fire != null else Vector3.INF
	_expect(await _reload(), "saved at the camp while the ships fight, and loaded")
	await _pump(func() -> bool: return SkyBattle.find(self) != null and MarchStage.find(self) != null, 5.0)
	sb = SkyBattle.find(self)
	m = MarchStage.find(self)
	rig = current_scene.get_node_or_null("EnvironmentRig") as EnvironmentRig
	_expect(sb != null and sb.clock < 3.0 and WreckFall.find(self) == null and rig != null and rig.wonder < 0.01
			and not StoryObjectives.truthy(_f("wonder")) and _step() == "watch" and Captivity.find(self).is_active(),
			"loaded: the battle plays again from its start (no wreck, the sky shut, still bound, the watch)")
	await _pump(func() -> bool: return MarchStage.find(self) != null and MarchStage.find(self).camp_fire != null, 5.0)
	m = MarchStage.find(self)
	_expect(m != null and m.camp_fire != null and _flat(m.camp_fire.global_position, fire0) < 1.0,
			"loaded at the camp: its fire where it was (%.1f m)" % (_flat(m.camp_fire.global_position, fire0) if m != null and m.camp_fire != null else -1.0))
	dn = rig.clock_driver if rig != null else null
	_expect(dn == null or dn.weather.kind == WeatherSystem.Kind.CLEAR, "loaded: the weather held clear again%s"
			% ("" if dn != null else " (headless: no sky clock)"))
	if sb == null or m == null:
		return
	sb.speed = 6.0
	story.step_t = 30.0
	await _pump(func() -> bool: return false, 1.0)
	_expect(_step() == "watch" and StorySlice.battle_on(self), "the watch goes on while the ships fight (held past its seconds)")
	# seen while the battle holds the watch (a guard turned on the player): no fail meanwhile, the hold comes first
	m.guards[0].alert(player)
	await _pump(func() -> bool: return false, 0.6)
	_expect(_step() == "watch" and story.phase == StoryDirector.Phase.STEPS and StoryObjectives.seen_by(self) != null,
			"seen while the battle holds the watch: it does not fail meanwhile")
	m.guards[0].calm()
	m.look_at_point(m.look_to)
	var mk: Variant = story.hud.marker_at
	_expect(mk is Vector3 and (mk as Vector3).distance_to(sb.focus()) < 120.0,
			"its marker on the fight (%.0f m off it)" % ((mk as Vector3).distance_to(sb.focus()) if mk is Vector3 else -1.0))
	_expect(m.look_to != Vector3.INF and m.look_to.y > FrontierTerrain.height_at(camp.x, camp.z) + 100.0,
			"the camp looks up at the fight (%.0f m up)" % (m.look_to.y - FrontierTerrain.height_at(camp.x, camp.z)))
	var up := m.leclerc.look_over == m.look_to and m.leclerc.gaze_at == m.look_to and not m.leclerc.gaze_gun
	for g in m.guards:
		up = up and g.gaze_at != Vector3.INF and g.gaze_gun
	var to_fight := Vector3(m.look_to.x - m.leclerc.global_position.x, 0.0, m.look_to.z - m.leclerc.global_position.z).normalized()
	var lec_off := rad_to_deg(m.leclerc.forward().angle_to(to_fight))
	_expect(up and lec_off < 35.0, "all eyes up on it: the guards' muskets levelled at it, Leclerc craning (facing it, %.0f deg off), not the captive"
			% lec_off)
	_expect(m.jost == null or not m.jost.is_crouching, "Jost on his feet")
	var marks := {}
	sb.tear_point.connect(func(d: Vector3) -> void: marks["tear"] = d)
	sb.cutter_falling.connect(func(w: WreckFall) -> void: marks["fall"] = w)
	await _pump(func() -> bool: return marks.has("tear"), 20.0)
	var tear := SkyTear.of(rig) if rig != null else null
	_expect(marks.has("tear") and tear != null and tear.running and tear.held and tear.dir.angle_to(marks["tear"]) < 0.01
			and absf(tear.seconds - StorySlice.TEAR_S / sb.speed) < 0.01 and bool(_f("wonder")),
			"the great shot strikes the sky: it cracks there, held small (SkyTear), the sky opened for good (the flag wonder)")
	var cried := false
	for g in m.guards:
		cried = cried or StoryBark.line_over(g) != ""
	_expect(cried, "the camp cries out (%s)" % (StoryBark.line_over(m.guards[1]) if m.guards.size() > 1 else ""))
	# a save after the sky was struck, before the cutter is down: it plays again too (the sky shut again)
	_expect(await _reload(), "saved after the sky was struck, the cutter not down yet, and loaded")
	await _pump(func() -> bool: return SkyBattle.find(self) != null and MarchStage.find(self) != null, 5.0)
	sb = SkyBattle.find(self)
	m = MarchStage.find(self)
	rig = current_scene.get_node_or_null("EnvironmentRig") as EnvironmentRig
	tear = rig.get_node_or_null(SkyTear.NODE_NAME) as SkyTear if rig != null else null
	_expect(sb != null and sb.clock < 3.0 and WreckFall.find(self) == null and rig != null and rig.wonder < 0.01
			and not StoryObjectives.truthy(_f("wonder")) and (tear == null or not tear.running) and _step() == "watch",
			"loaded: the battle again from its start, the sky shut (wonder %.2f)" % (rig.wonder if rig else -1.0))
	if sb == null or m == null:
		return
	sb.speed = 6.0
	marks = {}
	sb.tear_point.connect(func(d: Vector3) -> void: marks["tear"] = d)
	sb.cutter_falling.connect(func(w: WreckFall) -> void: marks["fall"] = w)
	await _pump(func() -> bool: return marks.has("fall"), 25.0)
	var wf := WreckFall.find(self)
	_expect(wf != null and marks.get("fall") == wf and wf.phase == WreckFall.Phase.FALLING and _flat(wf.at, bench) < 0.5
			and absf(wf.heading - deg_to_rad(150.0)) < 0.01, "the cutter struck, it falls burning toward the bench (WreckFall from the battle)")
	if wf == null:
		return
	tear = SkyTear.of(rig)
	var most := 0.0
	while not wf.is_landed() and most < 15.0:
		await process_frame
		most += 1.0 / 60.0
		if not wf.is_landed():
			_expect_quiet_small(tear)
	_expect(_small_ok, "while it falls the crack stays small (at most %.3f, held)" % _small_max)
	_expect(wf.is_landed() and wf.spar() != null and wf.ithel() != null and wf.contact != null and wf.spar().has_meta(&"sway_lift_to"),
			"it lands: the wreck, the spar (to be set down clear of him), the captain and his contact")
	await _frames(2)
	_expect(not tear.held and tear.running, "as it lands the break is let go: it runs on (%.3f)" % tear.amount)
	_expect(m.look_to != Vector3.INF and _flat(m.look_to, wf.at) < 1.0, "the camp's eyes on the wreck")
	_expect(m.running.size() == 2 and StoryBark.line_over(m.guards[0]) != "",
			"the camp scatters: the guards break for the pines, shouting (%s)" % StoryBark.line_over(m.guards[0]))
	var to_wreck0: Array[float] = []
	for g in m.guards:
		to_wreck0.append(_flat(g.global_position, wf.at))
	await _pump(func() -> bool: return story.hud.marker_at is Vector3, 1.0)
	mk = story.hud.marker_at
	var sky_at := sb.tear_aim() if is_instance_valid(sb) else Vector3.INF
	_expect(mk is Vector3 and sky_at != Vector3.INF and (mk as Vector3).distance_to(sky_at) < 5.0, "the marker on the break in the sky")
	await _pump(func() -> bool: return StoryObjectives.truthy(_f(StorySlice.SKY_OPEN_FLAG)), 20.0)
	var ran := 0
	var outs: Array[String] = []
	for i in m.guards.size():
		var g := m.guards[i]
		var gain := to_wreck0[i] - _flat(g.global_position, wf.at)
		outs.append("%.1f m on" % gain)
		if gain > 6.0:
			ran += 1
	_expect(ran == 2, "the guards running for the pines, toward the wreck (%s since it landed)" % ", ".join(outs))
	var over := SkyBattle.find(self) == null or SkyBattle.find(self).phase == SkyBattle.Phase.DONE
	_expect(over and not tear.running and rig.wonder >= 0.99 and _step() == "watch"
			and StoryObjectives.truthy(_f(StorySlice.SKY_OPEN_FLAG)),
			"the hunter gone into the break, the sky open (wonder %.2f, tf.sky_open); then the watch's own seconds (battle over %s, tear %s, step %s, flag %s)"
			% [rig.wonder, str(over), str(tear.running), _step(), str(_f(StorySlice.SKY_OPEN_FLAG))])
	# saved in the watch's last seconds, the sky open: loaded at the end of the battle (not played again)
	var at := wf.at
	_expect(await _reload(), "saved at the camp once the sky is open, and loaded")
	for i in 480:                                    # (frames, no talk answered: the watch's own seconds may run out meanwhile)
		if MarchStage.find(self) != null and MarchStage.find(self).phase == "camp" and MarchStage.find(self).camp_fire != null:
			break
		await process_frame
	m = MarchStage.find(self)
	wf = WreckFall.find(self)
	rig = current_scene.get_node_or_null("EnvironmentRig") as EnvironmentRig
	_expect(SkyBattle.find(self) == null and wf != null and wf.is_landed() and _flat(wf.at, at) < 0.1 and rig != null
			and rig.wonder >= 0.99 and bool(_f("wonder")) and _step() in ["watch", "slip"],
			"loaded at the end of the battle: the wreck down where it fell, the sky open (%.2f), the watch or its talk (battle %s, wreck %s, %.1f m, step %s)"
			% [rig.wonder if rig else -1.0, str(SkyBattle.find(self) != null), str(wf != null and wf.is_landed()),
			_flat(wf.at, at) if wf != null else -1.0, _step()])
	var still := m != null and wf != null and m.look_to != Vector3.INF and _flat(m.look_to, wf.at) < 1.0
	if m != null:
		for g in m.guards:
			still = still and not g.watch
	if _step() == "slip" and StoryDialogue.is_open(self) and (m == null or m.camp_fire == null):
		# (the watch's own seconds, counted again from the load, ran out while the camp came back: its talk opened over it,
		# the game waiting under it)
		_expect(Captivity.find(self) != null and Captivity.find(self).is_active() and still,
				"loaded in the watch's last seconds: the camp's talk opens as it comes back, bound still, the guards looking at the wreck")
	else:
		_expect(m != null and m.camp_fire != null and _flat(m.camp_fire.global_position, fire0) < 1.0 and still and Captivity.find(self).is_active(),
				"loaded at the camp: bound still, its fire where it was (%.1f m), the guards looking at the wreck"
				% (_flat(m.camp_fire.global_position, fire0) if m != null and m.camp_fire != null else -1.0))
	if m == null or wf == null:
		return
	# a retry's battle (the checkpoint's flags have no `wonder`, the sky the last one opened still open) shuts the sky
	# before it plays; skipped, it opens it again
	story.set_flag("wonder", null)
	StorySlice.effect(story, {"do": "wreck_fall", "place": "wreck"})
	sb = SkyBattle.find(self)
	_expect(sb != null and rig.wonder < 0.01 and not SkyTear.of(rig).running,
			"a battle played again without the flag wonder (a retry) shuts the sky first (%.2f)" % rig.wonder)
	if sb != null:
		sb.speed = 50.0
		sb.skip()
	await _pump(func() -> bool: return rig.wonder >= 0.99 and not SkyTear.of(rig).running, 6.0)
	wf = WreckFall.find(self)
	_expect(rig.wonder >= 0.99 and wf != null and wf.is_landed() and _flat(wf.at, at) < 0.1 and bool(_f("wonder")),
			"... and opens it again (skipped: the wreck down where it fell, the sky open %.2f)" % rig.wonder)
	story.step_t = 13.0
	await _pump(func() -> bool: return _step() == "sneak", 15.0, ["Take Jost's hand"])
	var cap := Captivity.find(self)
	_expect(_step() == "sneak" and not cap.is_active() and bool(_f("tf.jost_free")) and m.jost.leader == player,
			"the camp scatters: the bonds slipped, Jost's hand taken (he keeps by the player) (step %s, bound %s, jost_free %s)"
			% [_step(), str(cap.is_active()), str(_f("tf.jost_free"))])
	var wp := _place("wreck")
	_put(wp + (camp - wp).normalized() * 55.0)
	_expect(await _pump(func() -> bool: return _step() == "to_wreck", 5.0), "into the pines unseen")
	_put(wp + (camp - wp).normalized() * 12.0)
	await _pump(func() -> bool: return _step() == "look", 15.0, ["Breathe"])
	rig = current_scene.get_node_or_null("EnvironmentRig") as EnvironmentRig
	await _ticks(90)
	_expect(rig != null and rig.wonder >= 0.99 and rig._wonder_rate == 0.0 and bool(_f("wonder")),
			"the keel's smoke breathed under the open sky (opened by the battle, not again: wonder %.2f, rate %.3f, flag %s, step %s)"
			% [rig.wonder if rig else -1.0, rig._wonder_rate if rig else -1.0, str(_f("wonder")), _step()])
	story.step_t = 23.0
	_expect(await _to_step("lock", 15.0, ["I see it"]), "someone calling under a spar: the lock")


var _small_ok := true
var _small_max := 0.0


## While the cutter falls: the tear held and small (at most SkyTear.HOLD_TO).
func _expect_quiet_small(tear: SkyTear) -> void:
	if tear == null or not tear.running:
		return
	_small_max = maxf(_small_max, tear.amount)
	_small_ok = _small_ok and tear.held and tear.amount <= SkyTear.HOLD_TO + 0.001


## A save of the game now and a load of it (SaveGame: the level built again, the save applied); the level's own found
## again. False when the save did not write.
func _reload() -> bool:
	var sg := SaveGame.find(self)
	if sg == null or sg.save_game(SLOT) != OK:
		return false
	sg.load_slot(SLOT)
	var t := 0
	while t < 2400:
		await process_frame
		t += 1
		var nsg := SaveGame.find(self)
		var nd := StoryDirector.find(self)
		if nsg != null and nsg != sg and not nsg.loading and nd != null and nd.storyline_id == "two_fires":
			break
	await _frames(10)
	_find()
	return story != null


func _save_and_load() -> void:
	var sg := SaveGame.find(self)
	_expect(sg != null, "the level saves (save=on)")
	if sg == null:
		return
	var wf := WreckFall.find(self)
	var at := wf.at
	var pos := player.global_position
	var mi := story.mission_i
	var si := story.step_i
	var pieces := StoryLayer.layer_pieces("1757").size()
	var burnt0 := fire.burned_count() if fire != null else 0
	_expect(await _reload(), "saved mid-mission (%s, step %s) and loaded" % [_mission(), _step()])
	_expect(story != null and story.storyline_id == "two_fires" and story.mission_i == mi and story.step_i == si,
			"loaded into a new level: the same mission and step (%s %s)" % [_mission() if story else "?", _step() if story else "?"])
	if story == null:
		return
	var nwf := WreckFall.find(self)
	_expect(nwf != null and nwf.is_landed() and _flat(nwf.at, at) < 0.1 and nwf.spar() != null, "the wreck lies where it fell")
	var rig := current_scene.get_node_or_null("EnvironmentRig") as EnvironmentRig
	_expect(rig != null and rig.wonder >= 0.99, "the sky stays open (%.2f)" % (rig.wonder if rig else -1.0))
	# (the raid's fires may still be burning a farm down meanwhile: a piece fewer only for each burnt to its ruin)
	var now := StoryLayer.layer_pieces("1757").size()
	var burnt := (fire.burned_count() if fire != null else 0) - burnt0
	_expect(now <= pieces and pieces - now <= burnt, "the layer's farms not placed twice (%d pieces, %d before, %d burnt meanwhile)"
			% [now, pieces, burnt])
	var cap := Captivity.find(self)
	_expect(_flat(player.global_position, pos) < 1.0 and (cap == null or not cap.is_active()),
			"the player where he stood, free (%.1f m off)" % _flat(player.global_position, pos))
	_expect(caster != null and caster.motes == 3, "the Sway caster again (%d motes)" % (caster.motes if caster else -1))


func _the_lock() -> void:
	var wf := WreckFall.find(self)
	var spar := wf.spar()
	var freed := [false]
	wf.stranger_freed.connect(func() -> void: freed[0] = true)
	var out := wf.frame.basis.x
	out.y = 0.0
	out = out.normalized()
	_put(spar.global_position + out * 6.0)
	await _hands_free()
	await _ticks(20)
	var y0 := spar.global_position.y
	var top := [y0]
	var watch := func() -> void: top[0] = maxf(top[0], spar.global_position.y)
	physics_frame.connect(watch)
	# (the lock step's Form grant, its line at the top of the screen: the step's sway_grant effect's `say`)
	var said := [false]
	var hear := func() -> void:
		var lb: Variant = player.interactor.get("_notice") if player.interactor != null else null
		if lb is Label and (lb as Label).text.begins_with("Your hands know something new"):
			said[0] = true
	physics_frame.connect(hear)
	var pelvis := wf.rook().bone_pos("pelvis")
	var cast := await _lock_still(spar)
	_expect(cast and SwayCaster.cast_count("Spar", "first_lock") >= 1, "the first lock on the spar, the aim held still: the ring full (3 s), let go: cast")
	await _pump(func() -> bool: return freed[0] and _step() == "glass", 6.0)
	physics_frame.disconnect(watch)
	physics_frame.disconnect(hear)
	_expect(top[0] > y0 + 1.0 and freed[0] and bool(_f("tf.spar_lifted")), "the spar lifted (%.2f m up), the stranger crawls free" % (top[0] - y0))
	# (the grant as recorded, granted: has() is every spell with the Sway's free use, the user's 2026-10-03 "lets make the
	# spells free use right now", so it would pass with the story's sway_grant doing nothing; its line said only without it,
	# StoryEffects.say_line)
	var sc := SwayCaster.of(player)
	var form_ok := sc != null
	for id in ["earth_wall", "stone_form", "pillar", "mend"]:
		form_ok = form_ok and sc.granted.has(id)
	_expect(form_ok and not sc.has("levitate") and not sc.granted.has("gust") and said[0] != SwayCaster.free_use()
			and (sc.known_spells() as Array).size() >= 4,
			"the lock done, the Form spells granted (Earth Wall, Stone Form, Pillar, Mend: into the Tab screen's Spells list; granted %s), the line said %s (free use %s)"
			% [str(sc.granted if sc else []), said[0], SwayCaster.free_use()])
	await _ticks(Engine.physics_ticks_per_second * 2)
	var ends := [spar.global_position - spar.global_basis.x * WreckFall.SPAR_LEN * 0.5, spar.global_position + spar.global_basis.x * WreckFall.SPAR_LEN * 0.5]
	var off := Geometry3D.get_closest_point_to_segment(pelvis, ends[0], ends[1])
	_expect(Vector2(off.x - pelvis.x, off.z - pelvis.z).length() > 0.6, "set down clear of him (%.2f m from where his hips lay)"
			% Vector2(off.x - pelvis.x, off.z - pelvis.z).length())
	_expect(await _to_mission("m.tf.man_no_shadow", 20.0, ["I will"]) and bool(_f("tf.wayglass")) and bool(_f("tf.keel_coal")),
			"the captain's Wayglass and the keel's coal; then The Man with No Shadow")


func _rook() -> void:
	await _pump(func() -> bool: return _rook_node() != null, 3.0)
	var rook := _rook_node()
	var wf := WreckFall.find(self)
	_expect(rook != null and not rook.casts_shadow() and (wf == null or not wf.rook().visible), "Rook walks with you, from where the spar pinned him: no shadow")
	if rook == null:
		return
	await _pump(func() -> bool: return _step() == "follow", 15.0, ["Say a prayer"])
	var j: Node = null
	for c in current_scene.get_children():
		if c is StorySlice.RookJourney:
			j = c
	_expect(_step() == "follow" and j != null, "his walk toward the ford by the dead stock")
	if j == null:
		return
	var stock := _place("dead_stock")
	var wild := current_scene.get_node_or_null("Wildlife") as WildlifeSpawner
	rook.global_position = _ground(stock + Vector3(1.5, 0, 0)) + Vector3.UP * 0.1
	_put(stock + Vector3(4, 0, 0))
	await _pump(func() -> bool: return int(j.get("leg")) == 1, 60.0 if wild != null else 8.0)
	if wild != null:
		_expect(int(j.get("leg")) == 1 and bool(_f("tf.rook_gusted")), "at the dead stock the wolves come and Rook's Gust drives them off (tf.rook_gusted), on to the ford")
	else:
		_expect(int(j.get("leg")) == 1, "past the dead stock (no wildlife in this run: no wolves), on to the ford")
	var ford := _place("ford")
	rook.global_position = _ground(ford + Vector3(12, 0, 0)) + Vector3.UP * 0.1
	_put(ford + Vector3(16, 0, 0))
	_expect(await _to_mission("m.tf.ash_told", 20.0, ["When they took me", "We should cross"]) and bool(_f("tf.knows_house_words")),
			"at the ford Rook glosses the captor's words; Ash (told until the burned layer)")
	await _frames(3)
	_expect(MarchStage.find(self) == null and _rook_node() == null, "the camp gone west and Rook in the cellar (end_stages)")
	_expect(StoryObjectives.pack_count(self, "bar_lead") == 1 and SurvivalInventory.count(b.core, "item.trade.blanket") >= 1.0,
			"Ash: the cache's lead back in the pack, and Vane's blanket for a coat")
	_expect(await _pump(func() -> bool: return _mission() == "m.tf.first_lesson" and story.phase == StoryDirector.Phase.WAITING, 15.0),
			"the register read; First Lesson waits for December")


func _lesson() -> void:
	_clock("dec_early", 16.0)
	_expect(await _to_mission("m.tf.first_lesson", 10.0), "December at dusk: First Lesson")
	var ice := _place("lesson_ice")
	var rook := _rook_node()
	_expect(rook != null and _flat(rook.global_position, ice) < 2.0, "Rook waits on the ice")
	_put(ice + Vector3(4, 0, 0))
	await _pump(func() -> bool: return _step() == "lock_cast", 15.0, ["Show me"])
	_expect(caster.granted.has("gust"), "his lesson: Gust is the player's (granted: %s)" % str(caster.granted))     # (granted: has() is every spell with free use)
	await _hands_free()
	# (spells only from the bar: the player drags Gust from the Tab screen's Spells list onto a slot and presses its key)
	var hb := Hotbar.find(player)
	var gs := hb.add(Hotbar.make(Hotbar.SPELL, "gust")) if hb != null else -1
	if hb != null and gs < 0:
		gs = Hotbar.SLOTS - 1
		hb.assign(gs, Hotbar.make(Hotbar.SPELL, "gust"))
	if hb != null and hb.selected() != gs:
		hb.select(gs)
	await _ticks(4)
	_expect(caster.readied_spell == "gust", "Gust dragged onto the bar (slot %d) and its key: readied" % (gs + 1))
	var lantern: Node3D = null
	for n in get_nodes_in_group(SwayCaster.TARGET_GROUP):
		if SwayCaster.tag_of(n) == "lesson_lantern":
			lantern = n
	_expect(lantern != null, "a lantern lit on the ice")
	if lantern == null:
		return
	var c1 := await _lock(func() -> Vector3: return lantern.global_position)
	await _pump(func() -> bool: return story.step_i >= 3, 3.0)
	_expect(c1 and not bool(lantern.get("lit")) and story.step_i == 3, "Gust: the lantern put out (%d motes left)" % caster.motes)
	var hat: RigidBody3D = null
	for n in get_nodes_in_group(SwayCaster.TARGET_GROUP):
		if SwayCaster.tag_of(n) == "lesson_hat":
			hat = n
	_expect(hat != null, "a hat on a post")
	if hat == null:
		return
	var h0 := hat.global_position
	var c2 := await _lock(func() -> Vector3: return hat.global_position)
	await _pump(func() -> bool: return story.step_i >= 4, 3.0)
	await _ticks(30)
	_expect(c2 and not hat.freeze and hat.global_position.distance_to(h0) > 0.5 and story.step_i == 4,
			"Gust: the hat blown off its post (%.1f m)" % hat.global_position.distance_to(h0))
	var sl := StorySlice.find(self)
	await _pump(func() -> bool: return sl._wolf != null and is_instance_valid(sl._wolf), 3.0)
	var wolf := sl._wolf
	_expect(wolf != null and wolf.species == "wolf", "a wolf runs across the ice")
	if wolf == null:
		return
	_put(ice + Vector3(4, 0, 0))
	await _ticks(10)
	var c3 := await _lock(func() -> Vector3: return wolf.global_position + Vector3.UP * 0.5, 8.0)
	await _pump(func() -> bool: return story.step_i >= 5, 3.0)
	_expect(c3 and story.step_i >= 5, "Gust: the running wolf caught and sent off (%d motes left)" % caster.motes)
	await _pump(func() -> bool: return _step() == "go_to", 10.0)
	await _frames(3)
	_expect(_rook_node() == null and StorySlice.find(self)._wolf == null, "the coal breathes motes; Rook off to the cellar, the lesson's things cleared")
	_put(_place("fort_wall"))
	await _pump(func() -> bool: return _step() == "survive_until", 5.0)
	b.core.state.minutes = SurvivalClock.minutes_at(b.core, SurvivalClock.day_id(b.core), SurvivalClock.year(b.core), 19.5)
	var done := await _pump(func() -> bool: return _mission() == "m.tf.salvage" and story.phase == StoryDirector.Phase.WAITING, 20.0, ["You can see it"])
	_expect(done and story.done_missions.has("m.tf.first_lesson"),
			"full dark on the wall, Vane; the slice ends waiting on Salvage (%s)" % story.hud._text.text.left(60))


func _end() -> void:
	NpcSenses.daylight_override = -1.0
	print("  (%.0f s)" % ((Time.get_ticks_msec() - _t0) / 1000.0))
	if fails.is_empty():
		print("SLICE TEST PASSED (%d checks)" % checks)
	else:
		print("SLICE TEST FAILED (%d of %d)" % [fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)
