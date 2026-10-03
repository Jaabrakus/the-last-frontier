extends SceneTree
## The text dialogue in the level (StoryDialogue, StoryContact, StoryBark; data/story/dialogue/two_fires.json, its
## contact in data/story/storylines/two_fires.json), survival on:
##   Godot --headless --fixed-fps 60 --path . -s tests/story/test_dialogue.gd -- survival=on
##   talk     the neighbour's rumours opened: her name, her line typed out (the box not growing as it types), a key
##            shows it whole and the next goes on; the game waits under it, the mouse free; answers taken by key (by
##            where the key sits: AZERTY's 1) and by call; the flags they set; the outcome handed back; the box shut,
##            the game running again and the mouse given back as it was
##   if       the venison answer hidden with none in the pack and offered with some (taken: one venison less, standing
##            with the valley's settlers up, and the answer gone after); a "once" question gone once asked; the opening
##            branching on a flag; a mission `when`'s keys straight in; a key that is no condition (a typo) not holding
##   contact  a post with a lantern and a name tag before the player: "Talk to Margaretha Rauch", E's target; E opens the
##            talk, not again straight after it; the storyline's contacts placed at the Flatts, once; contacts and
##            talk read from a story of the test's own (StoryDirector.dir); the director places them as the storyline
##            begins and as a save comes back
##   keys     the E that ends a talk does nothing in the world (the game waits for it to come up: a neighbour in E's
##            reach is not tapped); a line whose next answers are all hidden waits for a key
##   menus    Esc opens the pause menu over the talk, and shut, the talk is there again
##   shared   in a shared world nothing pauses, the player's controls and E interactor rest, and come back after
##   queue    a second talk opened under the first waits its turn
##   bark     a line over a person, gone after its seconds; a fighter's own "Bark" label left alone
## Ends with "DIALOGUE TEST PASSED (<n> checks)" or "DIALOGUE TEST FAILED (<f> of <n>)".
var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var got: Array[String] = []
const FLAGS := ["tf.heard_rumour", "tf.gave_venison", "tf.will_speak", "tf.neighbour_watch", "tf.test"]
const TEST_DIR := "user://dialogue_test/"


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


## A key pressed and let go, as the keyboard would (`phys`: where it sits, when that is another key than its letter).
func _key(code: Key, phys := KEY_NONE) -> void:
	_press(code, true, phys)
	await _frames(1)
	_press(code, false, phys)
	await _frames(1)


func _press(code: Key, down: bool, phys := KEY_NONE) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = phys if phys != KEY_NONE else code
	e.pressed = down
	Input.parse_input_event(e)


func _heard(o: String) -> void:
	got.append(o)


## The contacts in the level with `id`.
func _contacts(id: String) -> Array:
	return get_nodes_in_group(StoryContact.CONTACTS).filter(func(n: Node) -> bool: return (n as StoryContact).id == id and not n.is_queued_for_deletion())


## A contact taken out of the world: out of E's reach first (the interactor lets go of it), then freed.
func _drop(c: StoryContact) -> void:
	if c == null or not is_instance_valid(c):
		return
	c.convo = ""
	c.remove_from_group(StoryContact.CONTACTS)
	await _frames(3)
	c.queue_free()
	await _frames(2)


## Through the rumours' opening to its questions (heard before: her short line, then the answers).
func _to_questions(d: StoryDialogue) -> void:
	d.advance()
	d.advance()
	d.advance()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(25)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	var sd := StoryDirector.find(self)
	_expect(player != null and sd != null, "the level has the player and the story director")
	if player == null or sd == null:
		_end()
		return
	player.ignore_mouse_capture = true
	await _frames(90)
	var flags := StoryDialogue.flags_of(self)
	_expect(flags == sd.get("flags"), "the talk's flags are the story director's")
	for k: String in FLAGS:
		flags.erase(k)
	TreeHarvest.pack_take(player, "venison", 999)
	_expect(not StoryDialogue.is_open(self) and not paused, "nothing open at the start, the game running")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# ---- the talk: her line, a key, the rumour
	StoryDialogue.open(self, "two_fires/rumours", _heard)
	await _frames(2)
	var d := StoryDialogue.find(self)
	_expect(d != null and StoryDialogue.is_open(self), "the talk is open")
	if d == null:
		_end()
		return
	d._was_mouse = Input.MOUSE_MODE_CAPTURED              # (the game's caught mouse: a headless run reads it free)
	_expect(paused, "alone, the game waits under it")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "the mouse is free")
	_expect(d.speaker_text() == "MARGARETHA RAUCH", "the speaker's name over the line: %s" % d.speaker_text())
	_expect(d.line_text().begins_with("You are the newcomer"), "her first line: %s" % d.line_text().left(40))
	_expect(d.typing() and d._line.visible_characters < d._line.get_total_character_count(), "it types itself out")
	await _frames(25)                                    # (past the guard against the key that opened it)
	await _key(KEY_SPACE)
	_expect(not d.typing() and d._line.visible_characters == -1, "a key shows it whole")
	await _key(KEY_SPACE)
	_expect(d.line_text().begins_with("Have you heard"), "the next key goes on: the rumour (%s)" % d.line_text().left(40))
	_expect(bool(flags.get("tf.heard_rumour", false)), "hearing it sets its flag")
	await _frames(2)
	var lines0 := d._line.get_line_count()
	var h0 := d._line.size.y
	var shown0 := d._line.visible_characters
	await _frames(110)                                   # (left alone it types out within MAX_TYPE_S)
	_expect(not d.typing() and d.choices.size() == 3, "typed out by itself, then three answers: %s" % str(d.choice_texts()))
	_expect(shown0 >= 0 and shown0 < d._line.get_total_character_count() and lines0 > 1 and d._line.get_line_count() == lines0
			and is_equal_approx(d._line.size.y, h0), "laid out whole as it typed: %d lines from the first letters, the box not growing (%d letters shown then)" % [lines0, shown0])
	_expect(d.choice_index("I shot a deer") == -1, "no venison in the pack: the venison answer is not offered")
	_expect(d._more.text == "1-3  answer", "the keys to answer under them: %s" % d._more.text)

	# ---- answers: by key (where it sits), then by call
	await _frames(25)
	await _key(KEY_AMPERSAND, KEY_1)                     # (AZERTY: the 1 key's letter is "&")
	_expect(d.line_text().begins_with("They laughed"), "the 1 key asks what the men said, on any layout: %s" % d.line_text().left(30))
	d.advance()
	d.advance()
	_expect(d.choice_index("What did the men") == -1 and d.choices.size() == 2, "back at the questions, the one asked is gone: %s" % str(d.choice_texts()))
	d.choose(d.choice_index("Do you believe"))
	d.advance()
	_expect(d.line_text().begins_with("I do not know") and d.choices.size() == 3, "do you believe it: her doubt, three answers")
	d.choose(d.choice_index("I will speak"))
	_expect(bool(flags.get("tf.will_speak", false)), "an answer's effect: the flag tf.will_speak set")
	d.advance()
	_expect(d.line_text().begins_with("Speak, then") and d._more.text == "Enter  close", "her last word, and the box says it closes")
	d.advance()
	await _frames(2)
	_expect(got == ["will_speak"], "the outcome is handed back: %s" % str(got))
	_expect(not StoryDialogue.is_open(self) and not paused, "the box is shut and the game runs again")
	_expect(StoryDialogue.mouse_given_back == Input.MOUSE_MODE_CAPTURED, "the mouse caught again, as it was")

	# ---- again, with venison in the pack
	TreeHarvest.pack_add(player, "venison", 2)
	var st0 := StoryDialogue.standing_of(self, "faction.settlers_valley")
	StoryDialogue.open(self, "two_fires/rumours", _heard)
	await _frames(2)
	d = StoryDialogue.find(self)
	d.advance()
	d.advance()
	_expect(d.line_text().begins_with("No more word"), "heard it before: the talk branches (%s)" % d.line_text().left(30))
	d.advance()
	_expect(d.choice_index("I shot a deer") >= 0 and d.choices.size() == 4, "venison in the pack: its answer offered, four in all: %s" % str(d.choice_texts()))
	d.choose(d.choice_index("I shot a deer"))
	_expect(d.line_text().begins_with("Danke"), "she thanks you")
	_expect(TreeHarvest.pack_count(player, "venison") == 1, "one venison taken from the pack (%d left)" % TreeHarvest.pack_count(player, "venison"))
	if SurvivalBridge.find(self) != null:
		var st1 := StoryDialogue.standing_of(self, "faction.settlers_valley")
		_expect(is_equal_approx(st1 - st0, 3.0), "standing with the valley's settlers up by 3 (%.1f -> %.1f)" % [st0, st1])
	d.advance()
	d.advance()
	_expect(d.choice_index("I shot a deer") == -1 and d.choices.size() == 3, "given once, the venison answer is gone: %s" % str(d.choice_texts()))
	d.choose(d.choice_index("I have work"))
	await _frames(2)
	_expect(got.back() == "left" and not StoryDialogue.is_open(self), "leaving ends it: %s" % got.back())

	# ---- conditions and effects as data
	var r := StoryDialogue.apply(self, [{"set": {"tf.test": 2}}, {"mission": "m.tf.fire"}, {"outcome": "x"}])
	_expect(int(flags.get("tf.test", 0)) == 2 and r.missions == ["m.tf.fire"] and String(r.get("outcome", "")) == "x", "effects: a flag to a value, a mission, an outcome (%s)" % str(r))
	_expect(StoryDialogue.holds(self, {"flag_is": {"tf.test": 2}}) and not StoryDialogue.holds(self, "!tf.test")
			and StoryDialogue.holds(self, [{"any": ["tf.nothing", "tf.test"]}, {"not": "tf.nothing"}]), "conditions: a flag's value, not, any")
	_expect(StoryDialogue.holds(self, {"item": "venison"}) and not StoryDialogue.holds(self, {"item": "venison", "n": 2})
			and StoryDialogue.holds(self, {"no_item": "bison_robe"}), "conditions: things in the pack")
	if SurvivalBridge.find(self) != null:
		var st := StoryDialogue.standing_of(self, "faction.settlers_valley")
		_expect(StoryDialogue.holds(self, {"standing": "faction.settlers_valley", "min": st - 0.5}) and not StoryDialogue.holds(self, {"standing": "faction.settlers_valley", "min": st + 0.5}), "conditions: standing (%.1f)" % st)
	_expect(StoryDialogue.holds(self, {"when": {"flags": ["tf.test"]}}) and not StoryDialogue.holds(self, {"when": {"flags": ["!tf.test"]}}),
			"conditions: the director's own `when` form")
	_expect(StoryDialogue.holds(self, {"flags": ["tf.test"]}) and not StoryDialogue.holds(self, {"flags": ["!tf.test"]})
			and not StoryDialogue.holds(self, {"done": ["m.tf.never"]}), "conditions: a mission `when`'s keys written straight in")
	_expect(not StoryDialogue.holds(self, {"flagg": "tf.test"}) and not StoryDialogue.holds(self, {"flag": "tf.test", "itme": "venison"}),
			"conditions: a key that is no condition (a typo) does not hold (warned)")
	StoryDialogue.apply(self, {"clear": "tf.test"})
	_expect(not flags.has("tf.test"), "a flag cleared")
	var v0 := TreeHarvest.pack_count(player, "venison")
	StoryDialogue.apply(self, {"give": "venison", "n": 2})
	var v1 := TreeHarvest.pack_count(player, "venison")
	StoryDialogue.apply(self, {"take": "venison", "n": 2})
	_expect(v1 == v0 + 2 and TreeHarvest.pack_count(player, "venison") == v0, "effects: things given and taken (%d -> %d -> %d)" % [v0, v1, TreeHarvest.pack_count(player, "venison")])

	# ---- a contact before the player
	var cam := root.get_viewport().get_camera_3d()
	var fwd := -cam.global_transform.basis.z if cam else -player.global_transform.basis.z
	var fwd_h := Vector3(fwd.x, 0, fwd.z).normalized()
	var spot := player.global_position + fwd_h * 1.6
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	var c := StoryContact.at_post(current_scene, spot, "two_fires/rumours", "Margaretha Rauch", "contact.test")
	await _frames(4)
	_expect(c.interact_prompt(player) == "Talk to Margaretha Rauch", "the contact's prompt: %s" % c.interact_prompt(player))
	_expect(player.interactor != null and player.interactor.target == c, "it is E's target in front of the player (%s)" % str(player.interactor.target if player.interactor else null))
	_expect(c._tag.visible and c._tag.text == "Margaretha Rauch", "its name tag shows close by")
	_expect(c.get_node_or_null("Lantern/Light") is OmniLight3D and not (c.get_node("Lantern/Light") as OmniLight3D).shadow_enabled, "a lantern with a small light, no shadow")
	c.interact(player)
	await _frames(2)
	d = StoryDialogue.find(self)
	_expect(d != null and paused and c.interact_prompt(player) == "", "E opens her talk; no prompt while it is up")
	if d:
		_to_questions(d)
		d.choose(d.choice_index("I have work"))
	await _frames(2)
	_expect(c.last_outcome == "left" and c.talks == 1, "the contact keeps the outcome (%s)" % c.last_outcome)
	_expect(c.interact_prompt(player) == "", "straight after, E does not open it again")
	await _frames(40)
	_expect(c.interact_prompt(player) == "Talk to Margaretha Rauch", "a moment later it does")
	await _drop(c)

	# ---- the E that ends a talk does nothing in the world: a neighbour in E's reach is not tapped by it
	var nb := StoryContact.at_post(current_scene, spot, "two_fires/rumours", "A neighbour", "contact.bystander")
	await _frames(4)
	_expect(player.interactor.target == nb, "a neighbour in E's reach, its target")
	var before_e := got.size()
	StoryDialogue.open(self, "two_fires/rumours", _heard)    # (as the story opens a talk: not at her post)
	await _frames(2)
	d = StoryDialogue.find(self)
	_to_questions(d)
	d._select(d.choice_index("I have work"))
	await _frames(25)                                    # (past the guard against an answer taken the moment it shows)
	_press(KEY_E, true)
	await _frames(3)
	_expect(not StoryDialogue.is_open(self) and d.waiting_for_key() and paused and got.size() == before_e,
			"E takes the answer: the box gone, the game waiting for E to come up")
	_press(KEY_E, false)
	await _frames(3)
	_expect(got.size() == before_e + 1 and got.back() == "left" and not paused, "E up: the outcome heard, the game running")
	await _frames(20)
	_expect(not StoryDialogue.is_open(self) and nb.talks == 0 and not nb._talking and player.interactor._press_t < 0.0,
			"and the neighbour in reach was not tapped by it (no press seen: %.2f)" % player.interactor._press_t)
	await _drop(nb)

	# ---- the storyline's contacts
	var pre := _contacts("contact.tf.margaretha")              # (none: the run has no storyline; a director's would count)
	var made := StoryContact.spawn_for(self, "two_fires")
	var all: Array = pre.duplicate()
	all.append_array(made)
	_expect(all.size() == 1 and (all[0] as StoryContact).who == "Margaretha Rauch" and (all[0] as StoryContact).convo == "two_fires/rumours",
			"the storyline's contact placed: %s" % str(all.map(func(x: StoryContact) -> String: return x.who)))
	if not all.is_empty():
		var at: Vector3 = (all[0] as StoryContact).global_position
		_expect(Vector2(at.x, at.z).distance_to(Vector2(5.4, 9.6)) < 0.01 and absf(at.y - FrontierTerrain.height_at(5.4, 9.6)) < 0.01, "in the Flatts' stockade by the fire, on the ground (%s)" % str(at))
	_expect(StoryContact.spawn_for(self, "two_fires").is_empty() and _contacts("contact.tf.margaretha").size() == 1, "and only once")

	# ---- a story of the test's own (StoryDirector.dir): its contacts and its talk
	_write_test_story()
	var dir0 := StoryDirector.dir
	StoryDirector.dir = TEST_DIR
	var mine := StoryContact.spawn_for(self, "t_test")
	_expect(mine.size() == 2 and mine[0].who == "Tester" and mine[0].convo == "t_test/dead_end"
			and Vector2(mine[0].global_position.x, mine[0].global_position.z).distance_to(Vector2(13.0, 28.0)) < 0.01,
			"contacts read from the story's own folder: %s" % str(mine.map(func(x: StoryContact) -> String: return x.who)))
	await _frames(2)
	if mine.size() == 2:
		_expect(mine[0].visible and not mine[1].visible and mine[1].interact_prompt(player) == "" and mine[1].when == "tf.never",
				"a contact whose `if` does not hold is not there (no post, no prompt)")
	StoryDialogue.open(self, "t_test/dead_end", _heard)
	await _frames(2)
	d = StoryDialogue.find(self)
	_expect(d != null and d.line_text() == "Only this.", "its talk read from there too")
	if d:
		await _frames(40)
		_expect(StoryDialogue.is_open(self) and d.line_text() == "Only this." and d._more.text == "Enter  continue",
				"a line whose next answers are all hidden waits for a key (%s / %s)" % [d.line_text(), d._more.text])
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		d._on_click(click)                               # (a click on the box: as any key)
		_expect(d.line_text() == "And then this.", "and a click goes on past them: %s" % d.line_text())
		d.advance()
		d.advance()
	await _frames(2)
	_expect(got.back() == "fine" and not StoryDialogue.is_open(self), "its end: %s" % got.back())
	StoryDirector.dir = dir0
	for x in mine:
		await _drop(x)

	# ---- a second talk waits its turn; one opened with the mouse free gives it back free (the command view)
	var before := got.size()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StoryDialogue.open(self, "two_fires/rumours", _heard)
	StoryDialogue.open(self, "rumours", _heard)           # (the name alone: found in the files)
	await _frames(2)
	var first := StoryDialogue.find(self)
	_expect(first != null and first._queue.size() == 1, "a second talk opened under the first waits")
	if first:
		first._was_mouse = Input.MOUSE_MODE_VISIBLE
		_to_questions(first)
		first.choose(first.choice_index("I have work"))
	await _frames(2)
	_expect(StoryDialogue.mouse_given_back == Input.MOUSE_MODE_VISIBLE, "a talk begun with the mouse free leaves it free")
	var second := StoryDialogue.find(self)
	_expect(second != null and second != first and paused, "the first shut, the second opens")
	if second:
		_to_questions(second)
		second.choose(second.choice_index("It is only talk") if second.choice_index("It is only talk") >= 0 else second.choice_index("I have work"))
	await _frames(2)
	_expect(got.size() == before + 2 and not StoryDialogue.is_open(self) and not paused, "both heard back, the game runs (%s)" % str(got.slice(before)))

	# ---- Esc: the pause menu over the talk, and back
	var pm := PauseMenu.install(current_scene, player)     # (the level has none in a script run)
	await _frames(2)
	StoryDialogue.open(self, "two_fires/rumours", _heard)
	await _frames(25)
	d = StoryDialogue.find(self)
	await _key(KEY_ESCAPE)
	await _frames(1)
	_expect(pm.is_open() and StoryDialogue.is_open(self) and d != null and not d.visible and paused,
			"Esc opens the pause menu over the talk (the box put away under it)")
	await _key(KEY_ESCAPE)
	await _frames(2)
	_expect(not pm.is_open() and StoryDialogue.is_open(self) and d.visible and paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
			"Esc again: the menu shut, the talk there again, the game waiting under it, the mouse free")
	if d:
		_to_questions(d)
		d.choose(d.choice_index("I have work"))
	await _frames(2)
	_expect(not StoryDialogue.is_open(self) and not paused, "then the talk ends as ever")
	pm.queue_free()
	await _frames(2)

	# ---- a shared world: nothing pauses, the player rests, E's interactor too
	StoryDialogue.force_shared = true
	var it := player.interactor
	var mode0 := it.process_mode
	StoryDialogue.open(self, "two_fires/rumours", _heard)
	await _frames(2)
	d = StoryDialogue.find(self)
	_expect(d != null and not paused and not player.controls.from_input and it.process_mode == Node.PROCESS_MODE_DISABLED,
			"shared: the game runs on, the player's keys rest, E's interactor stopped")
	if d:
		_to_questions(d)
		d.choose(d.choice_index("I have work"))
	await _frames(2)
	_expect(got.back() == "left" and player.controls.from_input and it.process_mode == mode0, "after it, the keys and E come back")
	StoryDialogue.force_shared = false

	# ---- a bark
	var fighter_bark := Label3D.new()                    # (NpcFighter's own bark label, under the same speaker)
	fighter_bark.name = "Bark"
	fighter_bark.text = "fighter"
	player.add_child(fighter_bark)
	StoryDialogue.bark(player, "Halloo the house!", 0.5)
	await _frames(3)
	_expect(StoryBark.line_over(player) == "Halloo the house!", "a bark over the player: %s" % StoryBark.line_over(player))
	var bk := player.get_node_or_null(StoryBark.NODE_NAME) as StoryBark
	_expect(bk != null and bk.position.y > 2.0 and bk.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "over the head, facing the camera")
	_expect(is_instance_valid(fighter_bark) and fighter_bark.is_inside_tree() and not fighter_bark.is_queued_for_deletion(), "a fighter's own bark label left alone")
	await _frames(45)
	_expect(StoryBark.line_over(player) == "", "gone after its half second")
	fighter_bark.queue_free()

	# ---- the director places the storyline's contacts as it begins and as a save comes back
	for k: String in FLAGS:
		flags.erase(k)
	for x in _contacts("contact.tf.margaretha"):
		await _drop(x)
	if sd.storyline_id == "":
		sd.begin_storyline("two_fires")
		await _frames(2)
		_expect(_contacts("contact.tf.margaretha").size() == 1, "the storyline begun: Margaretha at her place")
	for x in _contacts("contact.tf.margaretha"):
		await _drop(x)
	sd.load_data(sd.save_data())
	await _frames(2)
	_expect(_contacts("contact.tf.margaretha").size() == 1, "a save come back: Margaretha there again, once")
	_end()


## A story of the test's own under TEST_DIR: a storyline with a place and two contacts (one there only while a flag
## never set is set), and its talk: a line whose next
## turn has only answers that cannot be given (one hidden by a flag, one by a typo'd condition), then a last line.
func _write_test_story() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR + "storylines")
	DirAccess.make_dir_recursive_absolute(TEST_DIR + "dialogue")
	var line := {"places": {"spot": [12.0, 30.0]},
			"contacts": [{"id": "contact.t.tester", "speaker": "tester", "convo": "dead_end", "place": "spot", "offset": [1.0, -2.0]},
				{"id": "contact.t.hidden", "name": "Nobody", "convo": "dead_end", "at": [16.0, 28.0], "if": "tf.never"}]}
	var talk := {"speakers": {"tester": {"name": "Tester"}}, "conversations": {"dead_end": {"nodes": {
		"start": {"speaker": "tester", "text": "Only this.", "goto": "menu"},
		"menu": {"text": "", "choices": [{"text": "Hidden", "if": "tf.never", "end": "x"}, {"text": "Typo", "if": {"flagg": "tf.x"}, "end": "y"}], "goto": "after"},
		"after": {"speaker": "tester", "text": "And then this.", "end": "fine"}}}}}
	for e: Array in [["storylines/t_test.json", line], ["dialogue/t_test.json", talk]]:
		var f := FileAccess.open(TEST_DIR + String(e[0]), FileAccess.WRITE)
		f.store_string(JSON.stringify(e[1]))
		f.close()


func _end() -> void:
	StoryDialogue.force_shared = false
	if fails.is_empty():
		print("DIALOGUE TEST PASSED (%d checks)" % checks)
	else:
		print("DIALOGUE TEST FAILED (%d of %d)" % [fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)
