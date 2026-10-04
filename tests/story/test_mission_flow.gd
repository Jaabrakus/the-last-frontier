extends SceneTree
## The story's mission flow and its objective kinds (StoryDirector, StoryObjectives, StoryEffects) in the level with the
## survival rules, on a storyline of the test's own (written under user://, StoryDirector.dir) with stand-in people
## (nodes in npc_fighters with a tag, a state and a dead mark as properties; and fighters whose marks are methods, as
## NpcFighter's are: is_dead(), surrendered(), state_name(), a brain with `aware`), stand-ins for the systems built
## alongside (StoryDialogue, NpcSquad, Captivity's node; FireSpread as missing), then the real NpcSquad and NpcFighter:
##   Godot --headless --fixed-fps 60 --path . -s tests/story/test_mission_flow.gd -- survival=on
##   talk      opens only near the one to talk to; its answer sets a flag and branches past a mission
##   kill      people by tag (a fighter alive by its methods is not taken for dead); effects as data (give, standing,
##             captivity begun and ended, a missing system only warns, take, set_flag)
##   co-op     a card in a shared world does not stop the game; the player stands under it (controls let go)
##   when      a mission waits on its flags; as it begins an autosave is on its way
##   unseen    a fighter in COMBAT toward the player fails it, one after someone else does not; the fail card, the retry
##             from the checkpoint (the player back, the flags back, the squad made again, the gift not given again);
##             a death fails it too, the card after the respawn; the save keeps the checkpoint and the squad's living
##             (a load makes as many again as were alive)
##   defend    a breach fails it; timed with people kept alive; until the waves end
##   survive   until two hours have passed
##   escort    the wagon reaches the ford
##   chase     stopped, caught (not at once by its surrendered() method); one that gets away is a branch (fail_outcome)
##   deliver   things handed over at the fort, a gift for them; the mission fails later: the things come back, the
##             retry asks for them again and does not give the gift twice
##   steal     taken far off does not count; taken at the camp unseen: the mission's next map
##   follow    the guide to the ford
##   late      a mission's own fail rule with an outcome ends the whole mission that way (no later step's effects)
##   real      NpcSquad.spawn by name (faction, count, tag): two militiamen, alive; one killed (his loot), the mission
##             failed: the retry has them out of the world at once (the kill not passed by them), the loot gone; one
##             killed again, a save and a load: one made again, the count carried, the kill done
##   answer    a talk's answer that starts a mission (StoryDialogue's order: the mission, then the answer) is a branch:
##             the talk's mission done with the answer, its flag set
##   sight     a friendly fighter suspicious, or a foe aware of nothing, has not seen the player; a foe aware of them has;
##             foes in a defence leave out allies, the surrendered and the routed; who: people; a captivity with no
##             player is left out; a survival-kit item given and taken
## Ends with "MISSION FLOW TEST PASSED (<n> checks)" or "MISSION FLOW TEST FAILED (<f> of <n>)".
const DIR := "user://story_flow_test/"
const TOBACCO := "item.trade.tobacco"
const PLACES := {"fort": [0.0, 0.0], "camp": [40.0, 40.0], "ford": [120.0, 30.0]}
const PERSON_SRC := """extends Node3D
enum State { IDLE, PATROL, SUSPICIOUS, COMBAT }
var tag := ""
var state = State.IDLE
var is_dead := false
var target: Node = null
var waves_left := 0
"""
## As NpcFighter: its marks are methods, its mind a brain with `aware` (instance id -> 0..1.3) and routed().
const FIGHTER_SRC := """extends Node3D
class Mind:
	var aware := {}
	var out := false
	func routed() -> bool:
		return out
var tag := ""
var faction := "french_marine"
var down := false
var gave_up := false
var st := "IDLE"
var target: Node3D = null
var brain := Mind.new()
func is_dead() -> bool:
	return down
func surrendered() -> bool:
	return gave_up and not down
func state_name() -> String:
	return st
"""
const TALK_SRC := """extends RefCounted
static func open(tree: SceneTree, convo_id: String, on_done: Callable) -> void:
	Engine.set_meta(&"story_test_talk", [convo_id, on_done])
"""
const SQUAD_SRC := """extends RefCounted
static func spawn(tree: SceneTree, d: Dictionary) -> Array:
	var n := Node3D.new()
	n.name = "SquadStandIn"
	n.add_to_group(&"test_squad")
	tree.current_scene.add_child(n)
	n.global_position = d.at
	Engine.set_meta(&"story_test_spawns", int(Engine.get_meta(&"story_test_spawns", 0)) + 1)
	Engine.set_meta(&"story_test_squad", d)
	return [n]
"""
const CAPTIVITY_SRC := """extends Node
static func find(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group(&"test_captivity")
func begin(p: FrontierPlayer, p_captor: Node3D = null, opts := {}) -> bool:
	Engine.set_meta(&"story_test_captive", [p, p_captor, opts])
	return true
func end(return_gear := true, parts: Array = []) -> Dictionary:
	Engine.set_meta(&"story_test_freed", [return_gear, parts])
	return {}
"""

var checks := 0
var fails: Array[String] = []
var b: SurvivalBridge
var player: FrontierPlayer
var story: StoryDirector
var person: GDScript
var fighter: GDScript
var made: Array = []


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


## One look of the director at the world (and a frame after it, for what it does next: a fail card).
func _tick() -> void:
	story._t = 0.0
	await _frames(3)


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


## Where the story is (for a failed check's line).
func _state() -> String:
	return "%s step %d %s cards %s last %s" % [_mission(), story.step_i, StoryDirector.Phase.keys()[story.phase],
			story.hud.cards_open(), str(story.last)]


func _place(name: String) -> Vector3:
	return StoryObjectives.place_point({"place": name}, PLACES)


## A stand-in person (an NPC fighter's fields) at `at`; `methods`: one whose marks are methods (as NpcFighter).
func _person(tag: String, at: Vector3, group := "npc_fighters", methods := false) -> Node3D:
	var n: Node3D = (fighter if methods else person).new()
	n.set("tag", tag)
	n.add_to_group(StringName(group))
	current_scene.add_child(n)
	n.global_position = at
	made.append(n)
	return n


func _put_player(at: Vector3) -> void:
	player.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.2, at.z)
	player.velocity = Vector3.ZERO


func _flat(a: Vector3, c: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(c.x, c.z))


func _write(path: String, d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "  "))
	f.close()


func _storyline() -> void:
	_write(DIR + "storylines/flow_test.json", {"format": "frontier-storyline", "id": "story.flow_test", "name": "Flow Test",
		"places": PLACES, "parts": []})
	var missions := [
		{"id": "m.ft.talk", "title": "Talk", "start_effects": [{"do": "set_flag", "flag": "began"}],
			"steps": [{"kind": "talk", "convo": "flow/host", "tag": "host", "r": 4.0, "text": "Talk to the host",
				"choices": {"agree": {"flags": {"agreed": true}, "outcome": "agreed"}},
				"next": {"agreed": "m.ft.kill", "_": "m.ft.alone"}}]},
		{"id": "m.ft.alone", "title": "Alone", "steps": [{"kind": "go_to", "place": "ford"}]},
		{"id": "m.ft.kill", "title": "Vane", "start_effects": [{"do": "give", "item": "jerky", "count": 2},
				{"do": "standing", "faction": "garrison", "amount": 5.0}, {"do": "burn_at", "place": "camp", "r": 8.0},
				{"do": "begin_captivity", "captor": "host", "march_hours": 10.0}, {"do": "set_flag", "flag": "after_missing", "value": 3}],
			"steps": [{"kind": "kill", "tag": "vane", "count": 1, "text": "Deal with Vane"}],
			"effects": [{"do": "take", "item": "jerky", "count": 1}, {"do": "set_flag", "flag": "vane_dead"}, {"do": "end_captivity", "return_gear": false}],
			"outro": [{"title": "Vane", "text": "He is down."}]},
		{"id": "m.ft.unseen", "title": "Unseen", "when": {"flags": ["gate_open", "vane_dead", "!never"], "done": ["m.ft.kill"]},
			"waiting": "Wait for the gate", "fail": ["death"],
			"start_effects": [{"do": "spawn_squad", "place": "camp", "faction": "militia", "count": 1}, {"do": "give", "item": "flint", "count": 1}],
			"steps": [{"kind": "stay_unseen", "seconds": 5.0, "text": "Keep out of sight"}]},
		{"id": "m.ft.defend", "title": "Hold",
			"steps": [{"kind": "defend", "place": "camp", "r": 10.0, "foe_tag": "raider2", "seconds": 5.0, "text": "Hold the camp"},
				{"kind": "defend", "group": "settlers", "keep": 1, "seconds": 5.0, "text": "Keep them alive"},
				{"kind": "defend", "foe_tag": "raider", "until": "waves_end", "text": "Beat them off"}]},
		{"id": "m.ft.survive", "title": "Night", "steps": [{"kind": "survive_until", "for_hours": 2.0, "text": "Live till dawn"}]},
		{"id": "m.ft.escort", "title": "Wagon", "steps": [{"kind": "escort", "group": "escorted", "tag": "wagon", "place": "ford", "r": 8.0}]},
		{"id": "m.ft.chase", "title": "Chase",
			"steps": [{"kind": "chase", "tag": "runner_a", "r": 30.0, "catch_r": 3.0, "stop_s": 1.0, "min_run": 5.0, "lose_s": 2.0},
				{"kind": "chase", "tag": "runner_b", "r": 30.0, "catch_r": 3.0},
				{"kind": "chase", "tag": "runner_c", "r": 30.0, "lose_s": 2.0, "fail_outcome": "lost",
					"next": {"lost": "m.ft.deliver", "_": "m.ft.never"}}]},
		{"id": "m.ft.never", "title": "Never", "steps": [{"kind": "go_to", "place": "ford"}]},
		{"id": "m.ft.deliver", "title": "Hides", "fail": [{"on": "time", "s": 100.0}],
			"steps": [{"kind": "deliver", "item": "deer_hide", "count": 2, "place": "fort", "r": 8.0,
					"effects": [{"do": "give", "item": TOBACCO, "count": 1}]},
				{"kind": "go_to", "place": "camp", "r": 8.0}]},
		{"id": "m.ft.steal", "title": "Ledger", "next": {"unseen": "m.ft.follow", "seen": "m.ft.never2"},
			"steps": [{"kind": "steal", "item": "ledger", "place": "camp", "r": 10.0, "unseen": true}]},
		{"id": "m.ft.never2", "title": "Never again", "steps": [{"kind": "go_to", "place": "ford"}]},
		{"id": "m.ft.follow", "title": "Guide", "steps": [{"kind": "follow", "group": "guides", "tag": "guide", "place": "ford", "arrive_r": 6.0, "r": 12.0, "lose_s": 4.0}]},
		{"id": "m.ft.late", "title": "Late", "fail": [{"on": "time", "s": 5.0, "outcome": "late"}],
			"steps": [{"kind": "go_to", "place": "camp", "r": 3.0, "effects": [{"do": "set_flag", "flag": "late_s0"}]},
				{"kind": "go_to", "place": "fort", "r": 3.0, "effects": [{"do": "set_flag", "flag": "late_s1"}]}],
			"next": {"late": "m.ft.real", "_": "m.ft.never"}},
		{"id": "m.ft.real", "title": "Militia", "fail": [{"on": "time", "s": 600.0}],
			"start_effects": [{"do": "spawn_squad", "place": "camp", "faction": "militia", "count": 2, "tag": "real", "seed": 7}],
			"steps": [{"kind": "kill", "tag": "real", "count": 2, "text": "Deal with the militia"}]},
		{"id": "m.ft.talk2", "title": "Word", "steps": [{"kind": "talk", "convo": "flow/word", "tag": "host", "r": 4.0,
				"choices": {"go": {"flags": {"went": true}}}}, {"kind": "go_to", "place": "ford", "r": 1.0}]},
		{"id": "m.ft.never4", "title": "Never at all", "steps": [{"kind": "go_to", "place": "ford", "r": 1.0}]},
		{"id": "m.ft.after", "title": "After", "steps": [{"kind": "go_to", "place": "fort", "r": 10.0}]},
	]
	_write(DIR + "missions/flow_test.json", {"format": "frontier-missions", "version": 1, "missions": missions})


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(25)
	b = SurvivalBridge.find(self)
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	story = StoryDirector.find(self)
	_expect(b != null and player != null and story != null, "the level has the bridge, the player and the story")
	if story == null or b == null or player == null:
		_end()
		return
	player.ignore_mouse_capture = true
	await _frames(60)
	person = GDScript.new()
	person.source_code = PERSON_SRC
	person.reload()
	fighter = GDScript.new()
	fighter.source_code = FIGHTER_SRC
	fighter.reload()
	var talk := GDScript.new()
	talk.source_code = TALK_SRC
	talk.reload()
	var squad := GDScript.new()
	squad.source_code = SQUAD_SRC
	squad.reload()
	var cap_script := GDScript.new()
	cap_script.source_code = CAPTIVITY_SRC
	cap_script.reload()
	var cap: Node = cap_script.new()
	cap.add_to_group(&"test_captivity")
	current_scene.add_child(cap)
	made.append(cap)
	StoryEffects.stand_ins = {"StoryDialogue": talk, "NpcSquad": squad, "Captivity": cap_script, "FireSpread": null}
	Engine.set_meta(&"story_test_spawns", 0)
	_storyline()
	StoryDirector.dir = DIR
	story.storyline_id = ""
	story.hud.clear_cards()
	var jerky0 := StoryObjectives.pack_count(self, "jerky")
	var stand0 := SurvivalEconomy.standing(b.core, "garrison")
	_put_player(_place("fort") + Vector3(0, 0, 6))
	await _frames(5)
	# ---- talk: near the one to talk to, an answer, a flag, a branch
	var host := _person("host", _place("fort") + Vector3(20, 0, 6))
	story.begin_storyline("flow_test")
	_expect(_mission() == "m.ft.talk" and story.phase == StoryDirector.Phase.STEPS, "the test storyline begins with its talk")
	_expect(story.flags.get("began") == true, "its start effect set a flag")
	await _tick()
	_expect(not Engine.has_meta(&"story_test_talk") and story.hud.marker_at is Vector3, "20 m off the talk does not open; the marker is on the host")
	_put_player(host.global_position + Vector3(2, 0, 0))
	await _frames(3)
	await _tick()
	var t: Array = Engine.get_meta(&"story_test_talk", [])
	_expect(t.size() == 2 and String(t[0]) == "flow/host" and story._talking, "beside the host the conversation opens (%s)" % str(t))
	if t.size() == 2:
		(t[1] as Callable).call("agree")
	await _tick()
	_expect(story.flags.get("agreed") == true, "the answer set its flag")
	_expect(story.outcomes.get("m.ft.talk") == "agreed" and _mission() == "m.ft.kill", "and its outcome branched past Alone to the kill (%s)" % _mission())
	_expect(not story.done_missions.has("m.ft.alone"), "Alone was never played")
	# ---- kill people; effects as data
	_expect(StoryObjectives.pack_count(self, "jerky") == jerky0 + 2, "the kill's start gave 2 jerky (%d -> %d)" % [jerky0, StoryObjectives.pack_count(self, "jerky")])
	_expect(is_equal_approx(SurvivalEconomy.standing(b.core, "garrison"), stand0 + 5.0), "and 5 standing with the garrison")
	var cv: Array = Engine.get_meta(&"story_test_captive", [])
	_expect(cv.size() == 3 and cv[0] == player and cv[1] == host and is_equal_approx(float((cv[2] as Dictionary).get("march_hours", 0.0)), 10.0),
			"captivity begun by name on its node: the player, the captor by tag, the effect's fields as its opts (%s)" % str(cv))
	_expect(story.flags.get("after_missing") == 3, "a system not in the game (fire) only warned: the effect after it ran")
	var vane := _person("vane", _place("fort") + Vector3(30, 0, 0), "npc_fighters", true)
	var other := _person("other", _place("fort") + Vector3(32, 0, 0))
	await _tick()
	_expect(story.step_i == 0 and _mission() == "m.ft.kill" and story.hud.marker_at is Vector3, "Vane standing: not done, marked")
	other.set("is_dead", true)
	await _tick()
	_expect(_mission() == "m.ft.kill" and story.phase == StoryDirector.Phase.STEPS, "someone else down does not count")
	# ---- co-op: a shared world does not stop for a card
	var net := NetSession.ensure(self)
	var hosted := net.host(24611) == OK
	_expect(hosted and StoryDirector.shared_world(self), "a co-op session is on (hosting)")
	vane.set("down", true)
	await _tick()
	_expect(story.hud.cards_open() and not paused, "Vane down: the outro card is up and, in a shared world, the game runs on")
	_expect(not player.controls.from_input, "and the player stands under it (its controls let go)")
	await _through_cards()
	_expect(player.controls.from_input, "given back as the card closes")
	net.leave()
	await _frames(2)
	_expect(not StoryDirector.shared_world(self), "the session is over")
	_expect(StoryObjectives.pack_count(self, "jerky") == jerky0 + 1 and story.flags.get("vane_dead") == true, "its end effects took a jerky and set a flag")
	var fr: Array = Engine.get_meta(&"story_test_freed", [])
	_expect(fr.size() == 2 and fr[0] == false and fr[1] == [], "and ended the captivity, keeping the gear (its own default for the rest: %s)" % str(fr))
	# ---- when: the next mission waits on a flag
	_expect(_mission() == "m.ft.unseen" and story.phase == StoryDirector.Phase.WAITING, "Unseen waits for its when")
	_expect(story.hud._text.text == "Wait for the gate", "and says so (%s)" % story.hud._text.text)
	_expect(not StoryDirector.condition(self, {"flags": ["gate_open"]}) and StoryDirector.condition(self, {"done": ["m.ft.kill"], "outcome": {"m.ft.talk": "agreed"}}), "conditions read the flags, the missions done and how they ended")
	var flint0 := StoryObjectives.pack_count(self, "flint")
	_put_player(_place("fort") + Vector3(-10, 0, 0))
	await _frames(3)
	var p0 := player.global_position
	var sg := SaveGame.new()                       # (saves are off in script runs: one for this look, gone before it saves)
	sg.name = "SaveGameProbe"
	sg.setup(current_scene, null)
	current_scene.add_child(sg)
	story.set_flag("gate_open")
	await _tick()
	_expect(story.phase == StoryDirector.Phase.STEPS and _mission() == "m.ft.unseen", "the flag set: Unseen begins")
	_expect(SaveGame.find(self) == sg and sg._soon == "auto", "an autosave on its way as it begins (the checkpoint on disk)")
	current_scene.remove_child(sg)
	sg.free()
	_expect(int(Engine.get_meta(&"story_test_spawns", 0)) == 1 and get_nodes_in_group(&"test_squad").size() == 1, "its squad was spawned (NpcSquad by name)")
	var sq: Dictionary = Engine.get_meta(&"story_test_squad", {})
	_expect(sq.get("at") is Vector3 and _flat(sq.at, _place("camp")) < 0.5 and String(sq.get("faction", "")) == "militia", "at the camp, with its fields (%s)" % str(sq))
	_expect(StoryObjectives.pack_count(self, "flint") == flint0 + 1, "its gift came")
	# ---- unseen: seen fails it; the retry
	var watcher := _person("watch", _place("camp"))
	var elsewhere := Node3D.new()
	current_scene.add_child(elsewhere)
	made.append(elsewhere)
	watcher.set("state", 2)                      # SUSPICIOUS (an enum value its script names)
	watcher.set("target", elsewhere)
	await _tick()
	_expect(story.phase == StoryDirector.Phase.STEPS, "a suspicious fighter after someone else has not seen the player")
	story.set_flag("temp", true)
	_put_player(p0 + Vector3(30, 0, 0))
	await _frames(3)
	var first_squad: Node = get_nodes_in_group(&"test_squad")[0]
	watcher.set("target", null)
	watcher.set("state", 3)                      # COMBAT
	await _tick()
	_expect(story.phase == StoryDirector.Phase.FAILED and story.hud.cards_open() and story.hud._card_title.text == "Mission failed", "a fighter in combat toward the player: the mission fails, its card up (%s)" % story.hud._card_text.text)
	_expect(paused, "alone, the fail card stops the game")
	watcher.set("state", "IDLE")
	await _through_cards()
	await _frames(2)
	_expect(story.phase == StoryDirector.Phase.STEPS and story.step_i == 0 and _mission() == "m.ft.unseen", "after the card it begins again")
	_expect(_flat(player.global_position, p0) < 1.0, "the player back where it began (%.1f m off)" % _flat(player.global_position, p0))
	_expect(not story.flags.has("temp") and story.flags.get("gate_open") == true, "the flags as they were when it began")
	_expect(not is_instance_valid(first_squad) and int(Engine.get_meta(&"story_test_spawns", 0)) == 2 and get_nodes_in_group(&"test_squad").size() == 1, "its squad gone and made again")
	_expect(StoryObjectives.pack_count(self, "flint") == flint0 + 1, "its gift not given twice")
	# the save keeps the checkpoint, the missions done and their outcomes
	var saved := story.save_data()
	var cp: Dictionary = saved.get("checkpoint", {})
	_expect(int(cp.get("mission", -1)) == 3 and (cp.get("at", []) as Array).size() == 3 and (saved.get("done", []) as Array).has("m.ft.kill") \
			and (saved.get("outcomes", {}) as Dictionary).get("m.ft.talk") == "agreed", "a save keeps the checkpoint, the missions done and their outcomes")
	var ssq: Dictionary = (saved.get("squads", {}) as Dictionary).get("start:0", {})
	_expect(int(ssq.get("alive", 0)) == 1 and (cp.get("once", {}) as Dictionary).has("start:1"), "and its squad's living, and the gift as done (%s)" % str(saved.get("squads")))
	story.mission_i = 0
	story.checkpoint = {}
	story.load_data(saved)
	_expect(_mission() == "m.ft.unseen" and story.phase == StoryDirector.Phase.STEPS and int(story.checkpoint.get("mission", -1)) == 3, "and loads back into Unseen with its checkpoint")
	_expect(int(Engine.get_meta(&"story_test_spawns", 0)) == 3 and int((Engine.get_meta(&"story_test_squad", {}) as Dictionary).get("count", 0)) == 1,
			"a load makes its squad again, as many as were alive (the world does not keep it)")
	for n in get_nodes_in_group(&"test_squad"):
		n.queue_free()
	# a death fails it too: the card after the respawn
	player.is_dead = true
	await _tick()
	_expect(story.phase == StoryDirector.Phase.FAILED and not story.hud.cards_open(), "dead: failed, no card while the player is down")
	player.is_dead = false
	await _tick()
	_expect(story.hud.cards_open() and story.hud._card_text.text.begins_with("You died."), "up again: the card (%s)" % story.hud._card_text.text)
	await _through_cards()
	story.step_t = 6.0
	await _tick()
	_expect(_mission() == "m.ft.defend", "five seconds unseen: Unseen done, then Hold (%s)" % _mission())
	# ---- defend: a breach fails it; then kept alive for a time; then until the waves end
	var raider2 := _person("raider2", _place("camp") + Vector3(30, 0, 0))
	await _tick()
	_expect(story.phase == StoryDirector.Phase.STEPS and story.step_i == 0 and story.hud._count.text.ends_with("left"), "a raider outside: holding (%s)" % story.hud._count.text)
	raider2.global_position = _place("camp") + Vector3(2, 0, 0)
	await _tick()
	_expect(story.phase == StoryDirector.Phase.FAILED and story.hud._card_text.text.begins_with("They broke through."), "a raider in the camp: failed (%s)" % story.hud._card_text.text)
	raider2.set("is_dead", true)                 # (before the retry: else it is in the camp still)
	await _through_cards()
	story.step_t = 6.0
	await _tick()
	_expect(story.step_i == 1, "retried and held five seconds: the next defence (%s)" % _state())
	var s_a := _person("a", _place("camp"), "settlers")
	var s_b := _person("b", _place("camp"), "settlers")
	await _tick()
	s_a.set("is_dead", true)
	await _tick()
	_expect(story.step_i == 1 and story.phase == StoryDirector.Phase.STEPS, "one settler of two down: still held (keep 1)")
	story.step_t = 6.0
	await _tick()
	_expect(story.step_i == 2, "five seconds: the waves")
	await _tick()
	_expect(story.step_i == 2, "no raider yet: not over")
	var raider := _person("raider", _place("camp") + Vector3(20, 0, 0))
	var wave := _person("raider", _place("camp"), "npc_squads")
	wave.set("waves_left", 1)
	await _tick()
	_expect(story.step_i == 2 and story.hud._count.text == "1 left", "a raider: one left (%s)" % story.hud._count.text)
	raider.set("is_dead", true)
	await _tick()
	_expect(story.step_i == 2 and _mission() == "m.ft.defend", "down, but its squad has a wave left")
	wave.set("waves_left", 0)
	await _tick()
	_expect(_mission() == "m.ft.survive" and is_instance_valid(s_b), "the waves over: Hold done, then Night")
	# ---- survive_until
	await _tick()
	_expect(story.hud._count.text == "2 h left", "two hours to live through (%s)" % story.hud._count.text)
	b.core.state.minutes += 121.0
	await _tick()
	_expect(_mission() == "m.ft.escort", "two hours on: Night done, then the wagon")
	# ---- escort
	var wagon := _person("wagon", _place("fort") + Vector3(5, 0, 0), "escorted", true)
	await _tick()
	_expect(_mission() == "m.ft.escort", "the wagon at the fort: not there yet")
	wagon.global_position = _place("ford") + Vector3(3, 0, 0)
	await _tick()
	_expect(_mission() == "m.ft.chase", "the wagon at the ford: then the chase")
	# ---- chase: stopped, caught, lost (a branch)
	var pp := player.global_position
	var ra := _person("runner_a", pp + Vector3(10, 0, 0))
	await _tick()
	ra.global_position = pp + Vector3(18, 0, 0)
	story.step_t += 0.5
	await _tick()
	story.step_t += 0.6
	await _tick()
	_expect(story.step_i == 0, "running: still on")
	story.step_t += 0.6
	await _tick()
	_expect(story.step_i == 1 and story.outcome == "stopped", "it ran and stopped: done (%s)" % story.outcome)
	var rb := _person("runner_b", pp + Vector3(8, 0, 0), "npc_fighters", true)
	await _tick()
	_expect(story.step_i == 1, "one with a surrendered() method that says no is not caught at once")
	rb.global_position = pp + Vector3(2, 0, 0)
	await _tick()
	_expect(story.step_i == 2 and story.outcome == "caught", "caught up with: done (%s)" % story.outcome)
	_person("runner_c", pp + Vector3(50, 0, 0))
	await _tick()
	story.step_t += 1.0
	await _tick()
	_expect(story.step_i == 2, "too far: a second")
	story.step_t += 1.5
	await _tick()
	_expect(_mission() == "m.ft.deliver" and story.outcomes.get("m.ft.chase") == "lost", "it got away: lost is a branch to the delivery, past Never (%s)" % _mission())
	# ---- deliver; the mission failed after it: the hides back, asked for again, the gift not twice
	_put_player(_place("fort") + Vector3(2, 0, 0))
	await _frames(3)
	var hides0 := StoryObjectives.pack_count(self, "deer_hide")
	var tob0 := StoryObjectives.pack_count(self, TOBACCO)
	await _tick()
	_expect(_mission() == "m.ft.deliver" and story.step_i == 0, "at the fort without the hides: not done")
	StoryEffects.give(self, "deer_hide", 2)
	await _tick()
	_expect(story.step_i == 1 and StoryObjectives.pack_count(self, "deer_hide") == hides0, "two hides at the fort: handed over (out of the pack)")
	_expect(StoryObjectives.pack_count(self, TOBACCO) == tob0 + 1, "and tobacco for them, a survival-kit item (%d -> %d)" % [tob0, StoryObjectives.pack_count(self, TOBACCO)])
	story.mission_t = 101.0
	await _tick()
	_expect(story.phase == StoryDirector.Phase.FAILED and StoryObjectives.pack_count(self, "deer_hide") == hides0 + 2, "out of time: failed, the hides given back")
	await _through_cards()
	_expect(story.phase == StoryDirector.Phase.STEPS and story.step_i == 0 and _mission() == "m.ft.deliver", "the retry asks for them again")
	_put_player(_place("fort") + Vector3(2, 0, 0))
	await _frames(3)
	await _tick()
	_expect(story.step_i == 1 and StoryObjectives.pack_count(self, "deer_hide") == hides0 and StoryObjectives.pack_count(self, TOBACCO) == tob0 + 1,
			"handed over again; the tobacco not given twice (%d)" % StoryObjectives.pack_count(self, TOBACCO))
	_put_player(_place("camp") + Vector3(2, 0, 0))
	await _frames(3)
	await _tick()
	_expect(_mission() == "m.ft.steal", "at the camp: then the ledger (%s)" % _mission())
	# ---- steal
	_put_player(_place("fort"))
	await _frames(3)
	await _tick()
	StoryEffects.give(self, "ledger", 1)
	await _tick()
	_expect(_mission() == "m.ft.steal", "a ledger come by far from the camp does not count")
	_put_player(_place("camp") + Vector3(3, 0, 0))
	await _frames(3)
	await _tick()
	StoryEffects.give(self, "ledger", 1)
	await _tick()
	_expect(story.outcomes.get("m.ft.steal") == "unseen" and _mission() == "m.ft.follow", "taken at the camp unseen: the mission's next map picks the guide (%s)" % _mission())
	# ---- follow
	var guide := _person("guide", _place("ford") + Vector3(2, 0, 0), "guides", true)
	_put_player(_place("fort"))
	await _frames(3)
	await _tick()
	_expect(_mission() == "m.ft.follow" and story.phase == StoryDirector.Phase.STEPS, "far from the guide: not done")
	_put_player(guide.global_position + Vector3(3, 0, 0))
	await _frames(3)
	await _tick()
	_expect(_mission() == "m.ft.late" and story.done_missions.has("m.ft.follow"), "beside the guide at the ford: Guide done, then Late (%s)" % _mission())
	# ---- late: the mission's own fail rule with an outcome ends the whole mission that way
	StoryEffects.stand_ins.erase("NpcSquad")                # (the real one from here: the militia)
	await _tick()
	_expect(_mission() == "m.ft.late" and story.step_i == 0, "Late: not at the camp")
	story.mission_t = 6.0
	await _tick()
	_expect(story.outcomes.get("m.ft.late") == "late" and not story.flags.has("late_s0") and not story.flags.has("late_s1"),
			"five seconds: Late ended late, no step passed by it (%s, %s)" % [str(story.outcomes.get("m.ft.late")), str(story.flags.keys())])
	_expect(_mission() == "m.ft.real", "and its next map went on to the militia (%s)" % _mission())
	await _real_squad()
	await _answer_starts_mission()
	await _sight_and_calls()
	_expect(not story.done_missions.has("m.ft.never") and not story.done_missions.has("m.ft.never2") and not story.done_missions.has("m.ft.never4"),
			"no mission off the branches taken was played")
	_end()


## The tagged ones of the real squad (NpcFighter) still standing.
func _real_living() -> Array:
	return StoryObjectives._living(StoryObjectives.targets({"tag": "real"}, self))


## m.ft.real: the real NpcSquad.spawn and NpcFighter, by name; a kill, a fail and its retry, a save and a load.
func _real_squad() -> void:
	await _frames(5)
	var real := StoryObjectives.targets({"tag": "real"}, self)
	var ok := real.size() == 2
	for f in real:
		ok = ok and StoryEffects._is_a(f, "NpcFighter") and String(f.get("faction")) == "militia" and not StoryObjectives.is_dead(f) \
				and _flat((f as Node3D).global_position, _place("camp")) < 12.0
	_expect(ok, "NpcSquad.spawn by name: two militiamen tagged real at the camp, alive as the story reads them (%d)" % real.size())
	if real.size() != 2:
		return
	await _tick()
	_expect(_mission() == "m.ft.real" and story.step_i == 0 and int(story.last.get("have", -1)) == 0, "both standing: the kill not done (%s)" % _state())
	var first: Node = real[0]
	var old_squad: Node = first.get_parent()
	first.call("die")
	await _frames(2)
	var loot: Variant = first.get("loot")
	await _tick()
	_expect(story.hud._count.text == "1 / 2" and loot is Node, "one killed: 1 / 2, his loot where he fell (%s)" % story.hud._count.text)
	var saved := story.save_data()
	_expect(int(((saved.get("squads", {}) as Dictionary).get("start:0", {}) as Dictionary).get("alive", 0)) == 1 and int(saved.get("have", 0)) == 1,
			"a save keeps one of the squad alive and the count made (%s)" % str(saved.get("squads")))
	story.mission_t = 601.0
	await _tick()
	_expect(story.phase == StoryDirector.Phase.FAILED, "out of time: failed")
	await _through_cards()
	_expect(not is_instance_valid(old_squad) and not is_instance_valid(loot), "the retry: the first squad gone, and the loot its man left")
	_expect(_real_living().size() == 2 and _mission() == "m.ft.real" and story.step_i == 0 and int(story.last.get("have", -1)) == 0,
			"a new squad of two, the kill begun again and not passed by the men taken away (%s)" % _state())
	(_real_living()[0] as Node).call("die")
	await _tick()
	_expect(story.hud._count.text == "1 / 2", "one of them killed: 1 / 2 (%s)" % story.hud._count.text)
	var saved2 := story.save_data()
	for n in story.spawned:                                # (a load comes into a level without them)
		if is_instance_valid(n):
			(n as Node).get_parent().remove_child(n)
			(n as Node).free()
	story.load_data(saved2)
	await _frames(5)
	_expect(_real_living().size() == 1 and int(story.base.get("carried", 0)) == 1, "loaded: the one alive made again, the count carried (%d alive)" % _real_living().size())
	if _real_living().size() == 1:
		(_real_living()[0] as Node).call("die")
	await _tick()
	_expect(_mission() == "m.ft.talk2", "the second down: the militia dealt with (%s)" % _state())


## m.ft.talk2: StoryDialogue starts an answer's mission, then hands the answer back: a branch from the talk's mission.
func _answer_starts_mission() -> void:
	Engine.remove_meta(&"story_test_talk")
	var host: Node3D = StoryObjectives.targets({"tag": "host"}, self)[0]
	_put_player(host.global_position + Vector3(2, 0, 0))
	await _frames(3)
	await _tick()
	var t: Array = Engine.get_meta(&"story_test_talk", [])
	_expect(t.size() == 2 and String(t[0]) == "flow/word", "the second talk opens beside the host (%s)" % str(t))
	if t.size() == 2:
		story.start_mission_id("m.ft.after")
		(t[1] as Callable).call("go")
	await _tick()
	_expect(story.outcomes.get("m.ft.talk2") == "go" and story.flags.get("went") == true and _mission() == "m.ft.after",
			"an answer that starts a mission: the talk's mission done with the answer, its flag set, then that one (%s)" % _mission())
	_put_player(_place("fort"))
	await _frames(3)
	await _tick()
	_expect(story.phase == StoryDirector.Phase.DONE, "at the fort: the storyline is done")


## Sight as the fighters' minds have it, foes in a defence, who: people, a call left out, the survival kit.
func _sight_and_calls() -> void:
	var sf := _person("watch2", _place("camp") + Vector3(6, 0, 0), "npc_fighters", true)
	var aware: Dictionary = (sf.get("brain") as Object).get("aware")
	var me := player.get_instance_id()
	sf.set("faction", "militia")
	sf.set("st", "SUSPICIOUS")
	aware[me] = 1.0
	_expect(StoryObjectives.seen_by(self) == null, "a friendly militiaman suspicious of the player has not seen a foe")
	sf.set("faction", "french_marine")
	aware[me] = 0.0
	_expect(StoryObjectives.seen_by(self) == null, "a foe suspicious of a noise, aware of nothing, has not seen them")
	aware[me] = 0.5
	_expect(StoryObjectives.seen_by(self) == sf, "aware of the player: seen")
	sf.set("st", "COMBAT")
	_expect(StoryObjectives.seen_by(self) == null, "in combat only half aware of them, after no one: not seen")
	sf.set("target", player)
	_expect(StoryObjectives.seen_by(self) == sf, "in combat after the player: seen")
	sf.set("st", "IDLE")
	var a := _person("f_a", _place("camp"), "npc_fighters", true)
	var ally := _person("f_b", _place("camp"), "npc_fighters", true)
	ally.set("faction", "militia")
	var knelt := _person("f_c", _place("camp"), "npc_fighters", true)
	knelt.set("gave_up", true)
	var ran := _person("f_d", _place("camp"), "npc_fighters", true)
	(ran.get("brain") as Object).set("out", true)
	var foes := StoryObjectives._fighting([a, ally, knelt, ran], true)
	_expect(foes == [a], "a defence's foes: not an ally, not one on its knees, not one routed (%d)" % foes.size())
	var all_people := 0
	for n in get_nodes_in_group(&"npc_fighters"):
		if not n.is_queued_for_deletion():
			all_people += 1
	_expect(StoryObjectives.targets({"who": "people"}, self).size() == all_people and all_people > 0, "who: people names every fighter")
	var args := {"tree": self, "level": current_scene, "player": null, "d": {}, "opts": {}, "at": Vector3.ZERO}
	var miss := []
	StoryEffects.fit_args(StoryEffects.global_script("Captivity"), "begin", args, miss)
	Engine.set_meta(&"story_test_captive", [])
	StoryEffects.call_by_name("Captivity", "begin", args)
	_expect(miss == ["p"] and (Engine.get_meta(&"story_test_captive") as Array).is_empty(),
			"no player for Captivity.begin(p: FrontierPlayer): the call is left out, not handed the level (%s)" % str(miss))
	var tob := StoryObjectives.pack_count(self, TOBACCO)
	_expect(StoryEffects.take(self, TOBACCO, 1) == 1 and StoryObjectives.pack_count(self, TOBACCO) == tob - 1, "a survival-kit item taken back")


func _end() -> void:
	StoryDirector.dir = StoryDirector.STORY_DIR
	StoryEffects.stand_ins = {}
	# the stand-ins' marks off the Engine: story_test_talk holds the director's answer callback (a lambda), and kept there it
	# was freed only with the Engine, after GDScript was gone: "recursive_mutex lock failed" at the quit, exit 134
	for k: StringName in Engine.get_meta_list():
		if String(k).begins_with("story_test_"):
			Engine.remove_meta(k)
	for n in made:
		if is_instance_valid(n):
			n.queue_free()
	if fails.is_empty():
		print("MISSION FLOW TEST PASSED (%d checks)" % checks)
	else:
		print("MISSION FLOW TEST FAILED (%d of %d)" % [fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)
