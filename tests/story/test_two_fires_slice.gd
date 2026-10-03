extends SceneTree
## The vertical slice's story as data (docs/main_story.md 10.1-10.2, 15 item 1: missions 1-12 and 14 of Two Fires), with
## no level: data/story/{storylines,missions,dialogue}/two_fires.json read as the game reads them.
##   Godot --headless --path . -s tests/story/test_two_fires_slice.gd
##   data     every talk step's conversation is there; every place a step or an effect names is one; every `next` and
##            `else` goes to a mission or a step there is; the built Prologue's seven keep their places (0-6)
##   flow     the director's own branch reading (StoryDirector._pick_next): the hunt goes on to Neighbours only with its
##            kill passed, the house to the Third Warning only after Neighbours, the raid's night to the played raid only
##            then (else the built Prologue's ending); Neighbours is passed over by a save that finished the Prologue
##   ground   the places on the ground: in their squares, the east bank's dry and east of the river, the ford in it, the
##            ice lesson at the water's edge; the march's route on the dry east bank
##   talk     the conversations played by the real StoryDialogue on flags of their own (StoryDialogue.flags_alone): the
##            hidden count kept 1, 2, 3 by the three farms, each family's flag; old Ott only after Brenner; the widow's
##            Rauch answer only once the Rauchs go to the fort; Jost taken at the ford when they stayed; the alarm's two
##            ways; the captain's three; the register by who was warned; every conversation playable to an end
##   rules    no nation's name in any line (the warnings are a consultation slot)
## Ends with "TWO FIRES SLICE TEST PASSED (<n> checks)" or "TWO FIRES SLICE TEST FAILED (<f> of <n>)".

const DIR := "res://data/story/"
const PROLOGUE := ["m.tf.open_land", "m.tf.clearing", "m.tf.shelter", "m.tf.fire", "m.tf.meat", "m.tf.house", "m.tf.raid"]
## In the water by design (the ford's rapid); at its edge, dry (the ice lesson: where the ice bears first); the rest dry
## and more than 20 m east of the river's centre.
const WET := ["ford"]
const EDGE := ["lesson_ice"]
## In the fort's square; the rest are in the open land's, on the east bank.
const FORT := ["flatts_fort", "fort_store", "fort_wall", "fort_church"]
## Words no line may hold (docs/main_story.md rule 4: no Native nation's name or people on screen without its office).
const NOT_SAID := ["Oneida", "Iroquois", "Haudenosaunee", "Abenaki", "Odanak", "Kahnawake", "Oswegatchie", "Mohawks"]

var checks := 0
var fails: Array[String] = []
var line := {}
var missions: Array = []
var talk := {}
var _got := ""
var _heard := false
var _last_line := ""             ## the last line the talk showed (_play)


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


func _run() -> void:
	line = StoryDirector.load_json(DIR + "storylines/two_fires.json")
	missions = StoryDirector.load_json(DIR + "missions/two_fires.json").get("missions", [])
	talk = StoryDialogue.load_file("two_fires")
	_expect(not line.is_empty() and not missions.is_empty() and not talk.is_empty(), "the storyline, its missions and its talk read")
	_data()
	_flow()
	_ground()
	await _talk()
	_rules()
	_end()


# --- data -----------------------------------------------------------------------------------------------------

func _ids() -> Array:
	return missions.map(func(m: Dictionary) -> String: return String(m.get("id", "")))


func _data() -> void:
	var ids := _ids()
	_expect(ids.slice(0, 7) == PROLOGUE, "the built Prologue's seven keep their places 0-6 (a save keeps the mission by its place): %s" % str(ids.slice(0, 7)))
	for want in ["m.tf.neighbours", "m.tf.third_warning", "m.tf.march", "m.tf.two_fires", "m.tf.man_no_shadow", "m.tf.ash", "m.tf.first_lesson"]:
		_expect(ids.has(want), "the slice has %s" % want)
	var places: Dictionary = line.get("places", {})
	var bad := []
	for m: Dictionary in missions:
		var sids := []
		for st: Dictionary in m.get("steps", []):
			if st.has("id"):
				sids.append(String(st.id))
		for key in ["next", "else"]:
			for t in _names_in(m.get(key)):
				if not ids.has(t):
					bad.append("%s.%s -> %s" % [m.id, key, t])
		for e: Dictionary in m.get("start_effects", []) + m.get("effects", []):
			bad.append_array(_bad_places(e, places, String(m.id)))
		var i := 0
		for st: Dictionary in m.get("steps", []):
			var at := "%s step %d" % [m.id, i]
			if st.has("place") and not (places.get(String(st.place)) is Array):
				bad.append("%s: place %s" % [at, st.place])
			if String(st.get("kind", "")) == "talk" and StoryDialogue.conversation("two_fires/" + String(st.get("convo", ""))).is_empty():
				bad.append("%s: no conversation %s" % [at, st.get("convo")])
			for t in _names_in(st.get("next")):
				if not sids.has(t) and not ids.has(t):
					bad.append("%s: next %s" % [at, t])
			for key in ["start_effects", "effects", "fail_effects"]:
				for e: Dictionary in st.get(key, []):
					bad.append_array(_bad_places(e, places, at))
			i += 1
	_expect(bad.is_empty(), "every conversation, place, `next` and `else` the missions name is there%s" % ("" if bad.is_empty() else ": " + str(bad)))
	var part_ids := []
	for p: Dictionary in line.get("parts", []):
		part_ids.append_array(p.get("missions", []))
	var missing := ids.filter(func(id: String) -> bool: return not part_ids.has(id) and id != "m.tf.prologue_end")
	_expect(missing.is_empty(), "every mission is in a part of the storyline (%s)" % str(missing))
	_expect(not StoryDialogue.conversation("two_fires/ithel").is_empty(), "the captain's conversation is there for the wreck's contact (WreckFall.ITHEL_CONVO two_fires/ithel)")


func _names_in(v: Variant) -> Array:
	if v is String:
		return [v] if String(v) != "" else []
	if v is Dictionary:
		return (v as Dictionary).values().filter(func(x: Variant) -> bool: return x is String and String(x) != "")
	return []


func _bad_places(e: Dictionary, places: Dictionary, at: String) -> Array:
	var out := []
	for key in ["place", "home", "ford", "to", "camp"]:
		if e.get(key) is String and not (places.get(String(e[key])) is Array):
			out.append("%s %s: %s %s" % [at, e.get("do"), key, e[key]])
	for key in ["farms", "via"]:
		for t in e.get(key, []):
			if not (places.get(String(t)) is Array):
				out.append("%s %s: %s %s" % [at, e.get("do"), key, t])
	return out


# --- flow -----------------------------------------------------------------------------------------------------

func _mission(id: String) -> Dictionary:
	for m: Dictionary in missions:
		if String(m.get("id", "")) == id:
			return m
	return {}


func _next(sd: StoryDirector, v: Variant, fl: Dictionary, out := "") -> String:
	sd.flags = fl
	sd.outcome = out
	return sd._pick_next(v)


func _flow() -> void:
	var sd := StoryDirector.new()
	sd.missions = missions
	var meat := _mission("m.tf.meat")
	_expect(_next(sd, meat.get("next"), {}) == "m.tf.house", "a hunt passed without its kill (or a save from before the slice) goes on to the house")
	_expect(_next(sd, meat.get("next"), {"tf.deer_down": true}) == "m.tf.neighbours", "the deer down: Neighbours next")
	var house := _mission("m.tf.house")
	_expect(_next(sd, house.get("next"), {}) == "m.tf.raid", "a house with no neighbours met: the raid next, as built")
	_expect(_next(sd, house.get("next"), {"tf.met_rauchs": true}) == "m.tf.third_warning", "after Neighbours: the Third Warning")
	var raid := _mission("m.tf.raid")
	var night: Dictionary = (raid.get("steps", []) as Array)[0]
	_expect(_next(sd, night.get("next"), {}) == "m.tf.prologue_end" and _mission("m.tf.prologue_end") == missions.back(),
			"the raid's night with no neighbours met ends the built Prologue (the last in the list: the storyline done)")
	_expect(_next(sd, night.get("next"), {"tf.met_rauchs": true}) == "alarm", "after Neighbours the raid is played: its alarm next")
	_expect(raid.get("outro_by") is Dictionary and (raid.outro_by as Dictionary).has("taken") and String(raid.get("next", "")) == "m.tf.march",
			"the played raid ends 'taken' with its own cards and goes on to The March")
	var steps: Array = raid.get("steps", [])
	var last: Dictionary = steps.back()
	_expect(String(last.get("fail_outcome", "")) == "taken", "its last step ends 'taken' even when seen (the cards stay the slice's)")
	var neigh := _mission("m.tf.neighbours")
	var ctx_before := {"flags": {}, "done": PROLOGUE.slice(0, 5), "outcomes": {}}
	var ctx_after := {"flags": {}, "done": PROLOGUE, "outcomes": {}}
	_expect(StoryObjectives.holds(neigh.get("when"), self, ctx_before) and not StoryObjectives.holds(neigh.get("when"), self, ctx_after)
			and String(neigh.get("else", "")) == "m.tf.prologue_end", "Neighbours plays before the raid; a save that finished the built Prologue passes it by")
	var ash := _mission("m.tf.ash")
	_expect(not StoryObjectives.holds(ash.get("when"), self, {"flags": {}}) and String(ash.get("else", "")) == "m.tf.ash_told"
			and StoryObjectives.holds(ash.get("when"), self, {"flags": {"tf.burned_layer": true}}),
			"Ash waits for the burned layer and is told meanwhile")
	var fl := _mission("m.tf.first_lesson")
	var kinds := (fl.get("steps", []) as Array).map(func(s: Dictionary) -> String: return String(s.get("kind", "")))
	_expect(kinds.count("lock_cast") == 3 and String(_mission("m.tf.salvage").get("waiting", "")) != "", "First Lesson's three locks, then the slice waits on Salvage")
	var tf := _mission("m.tf.two_fires")
	var sneak: Dictionary = {}
	for s: Dictionary in tf.get("steps", []):
		if String(s.get("id", "")) == "sneak":
			sneak = s
	sd.mission_i = missions.find(tf)
	_expect(_next(sd, sneak.get("next"), {}, "seen") == "let_go" and _next(sd, sneak.get("next"), {}, "alone") == "to_wreck"
			and sd._step_index("let_go") >= 0 and sd._step_index("to_wreck") >= 0, "seen slipping away, Leclerc turns his back; unseen, straight to the wreck")
	sd.free()


# --- ground ---------------------------------------------------------------------------------------------------

func _ground() -> void:
	var places: Dictionary = line.get("places", {})
	var bad := []
	for k: String in places:
		if not (places[k] is Array):
			continue
		var x := float(places[k][0])
		var z := float(places[k][1])
		var sq := WorldSquares.type_id(WorldSquares.square_at(Vector3(x, 0, z)))
		var wet := not is_inf(WorldRiver.surface_at(x, z))
		if FORT.has(k):
			if sq != "fort_woods" or wet:
				bad.append("%s: %s %s" % [k, sq, "wet" if wet else "dry"])
		elif EDGE.has(k):
			if sq != "open_land" or wet or absf(x - WorldRiver.x_at(z)) > 20.0:
				bad.append("%s: %s %s, %.0f m from the river's centre" % [k, sq, "wet" if wet else "dry", x - WorldRiver.x_at(z)])
		elif sq != "open_land" or wet != WET.has(k) or (not WET.has(k) and x - WorldRiver.x_at(z) < 20.0):
			bad.append("%s: %s %s, %.0f m east of the river" % [k, sq, "wet" if wet else "dry", x - WorldRiver.x_at(z)])
	_expect(bad.is_empty(), "the places on the ground: the fort's in its square, the rest in the open land on the dry east bank, the ford in the river, the ice lesson at its edge%s" % ("" if bad.is_empty() else ": " + str(bad)))
	var ford: Array = places.get("ford", [0, 0])
	_expect(WorldRiver.rapid_at(float(ford[1])) > 0.9, "the ford is on the rapid at z 60")
	var route: Array = []
	for e: Dictionary in _mission("m.tf.march").get("start_effects", []):
		if String(e.get("do", "")) == "march":
			route = e.get("route", [])
	var off := route.filter(func(p: Array) -> bool: return float(p[0]) - WorldRiver.x_at(float(p[1])) < 20.0 or not is_inf(WorldRiver.surface_at(float(p[0]), float(p[1]))))
	_expect(route.size() >= 3 and off.is_empty(), "the march's route keeps to the dry east bank (%d points)" % route.size())


# --- talk -----------------------------------------------------------------------------------------------------

func _done(outcome: String) -> void:
	_got = outcome
	_heard = true


## Plays `convo` with the real StoryDialogue: at each turn the first answer whose words begin with one of `picks` (in
## order, each used once), else the first answer shown. Returns the outcome ("<stuck>" when it did not end).
func _play(convo: String, picks: Array = []) -> String:
	_heard = false
	_got = ""
	StoryDialogue.open(self, "two_fires/" + convo, _done)
	await _frames(2)
	var left := picks.duplicate()
	for i in 200:
		var d := StoryDialogue.find(self)
		if _heard or d == null or d._closed:
			break
		_last_line = d.line_text()
		if d.typing():
			d.advance()
		elif not d.choices.is_empty():
			var k := 0
			for p: String in left:
				var j := d.choice_index(p)
				if j >= 0:
					k = j
					left.erase(p)
					break
			d.choose(k)
		else:
			d.advance()
		await process_frame
	for i in 30:
		if _heard:
			break
		await process_frame
	return _got if _heard else "<stuck>"


func _flags(fl: Dictionary) -> void:
	StoryDialogue.flags_alone.clear()
	StoryDialogue.flags_alone.merge(fl, true)


func _f(k: String) -> Variant:
	return StoryDialogue.flags_alone.get(k)


func _talk() -> void:
	# the hidden count: the three farms in Margaretha's order, each persuaded by its own answer
	_flags({"tf.rauchs_to_fort": true})
	var o1 := await _play("warn_brenner", ["Sleep in your clothes"])
	var c1: Variant = _f("tf.warned_count")
	var o2 := await _play("warn_wendel", ["Then it is women's talk"])
	var c2: Variant = _f("tf.warned_count")
	var o3 := await _play("warn_ott", ["Konrad Brenner"])
	_expect(o1 == "persuaded" and o2 == "persuaded" and o3 == "persuaded" and int(c1) == 1 and int(c2) == 2 and int(_f("tf.warned_count")) == 3
			and bool(_f("tf.warned_all")), "the hidden count: 1, 2, 3 as the three families are persuaded (%s %s %s)" % [str(c1), str(c2), str(_f("tf.warned_count"))])
	_expect(bool(_f("tf.warned.brenner")) and bool(_f("tf.warned.wendel")) and bool(_f("tf.warned.ott")), "each family's own flag")
	# the wrong word does not move them, and Ott only follows Brenner
	_flags({})
	var b := await _play("warn_brenner", ["The French are coming"])
	var w := await _play("warn_wendel", ["Let them laugh"])
	var ott := await _play("warn_ott", ["Konrad Brenner", "If it is only"])
	_expect(b == "laughed" and w == "persuaded" and ott == "laughed" and int(_f("tf.warned_count")) == 1 and _f("tf.warned.ott") == null,
			"fear does not move Brenner; the widow comes round; old Ott will not, with Brenner laughing (count %s)" % str(_f("tf.warned_count")))
	_flags({})
	StoryDialogue.open(self, "two_fires/warn_wendel", _done)
	await _frames(2)
	var dw := StoryDialogue.find(self)
	if dw:
		dw.advance()
		_expect(dw.choice_index("Then it is women's talk") == -1 and dw.choices.size() == 2, "the widow's Rauch answer only once the Rauchs go to the fort: %s" % str(dw.choice_texts()))
		dw.choose(dw.choice_index("Your sons"))
		for i in 6:
			dw.advance()
	await _frames(4)
	# the Rauchs' choice, and Jost at the ford
	_flags({})
	var tw := await _play("third_warning", ["Who brought", "What does", "What do you want", "Take Jost and Anna"])
	_expect(tw == "to_fort" and bool(_f("tf.rauchs_to_fort")), "the Third Warning: the Rauchs to the fort (%s)" % tw)
	var ford1 := await _play("raid_ford")
	var safe: bool = not _f("tf.jost_taken")
	_flags({})
	var ford2 := await _play("raid_ford")
	_expect(ford1 == "back" and ford2 == "back" and safe and bool(_f("tf.jost_taken")), "at the ford: Jost safe at the fort, or taken when they stayed home")
	# the alarm's two ways
	_flags({})
	var a0 := await _play("raid_alarm")
	var a0_line := _last_line
	_flags({"tf.warned.wendel": true, "tf.warned_count": 1})
	var a1 := await _play("raid_alarm")
	_expect(a0 == "run" and a1 == "run" and a0_line != _last_line, "the alarm: nobody listened, or the warned are waiting in the fields")
	# Jost at the wreck night
	_flags({"tf.jost_taken": true})
	var j1 := await _play("camp_scatters", ["Take Jost's hand"])
	var free := bool(_f("tf.jost_free"))
	_flags({"tf.jost_taken": true})
	var j2 := await _play("camp_scatters", ["Tell Jost to stay"])
	var held: bool = bool(_f("tf.jost_held")) and not _f("tf.jost_free")
	_flags({})
	var j3 := await _play("camp_scatters")
	_expect(j1 == "with_jost" and free and j2 == "alone" and held and j3 == "alone", "slip away with Jost or without him; alone when he was not taken")
	# the captain: before the lock, after it, after the death
	_flags({})
	var i0 := await _play("ithel")
	_flags({"tf.spar_lifted": true, "tf.tinderbox": true})
	var i1 := await _play("ithel", ["I will"])
	var glass := bool(_f("tf.wayglass")) and bool(_f("tf.keel_coal")) and bool(_f("tf.promised_ithel"))
	var i2 := await _play("ithel")
	_expect(i0 == "not_yet" and i1 == "glass" and glass and i2 == "after", "the captain's conversation: the spar first, then the Wayglass and the coal, then gone (%s %s %s)" % [i0, i1, i2])
	# the register reads who was warned
	_flags({"tf.warned.brenner": true, "tf.rauchs_to_fort": true})
	var r1 := await _play("register_told")
	_expect(r1 == "read", "the register read to its end")
	# every conversation plays to an end by its first answers
	var stuck := []
	for name: String in (talk.get("conversations", {}) as Dictionary):
		_flags({})
		var out := await _play(name)
		if out == "<stuck>":
			stuck.append(name)
	_expect(stuck.is_empty(), "every conversation (%d) plays to an end%s" % [(talk.get("conversations", {}) as Dictionary).size(), "" if stuck.is_empty() else ": stuck in " + str(stuck)])
	_flags({})



# --- rules ----------------------------------------------------------------------------------------------------

func _rules() -> void:
	var said := []
	for name: String in (talk.get("conversations", {}) as Dictionary):
		var nodes: Dictionary = (talk.conversations[name] as Dictionary).get("nodes", {})
		for id: String in nodes:
			var n: Dictionary = nodes[id]
			var words := String(n.get("text", ""))
			for c: Dictionary in n.get("choices", []):
				words += " " + String(c.get("text", ""))
			for w: String in NOT_SAID:
				if words.contains(w):
					said.append("%s.%s: %s" % [name, id, w])
	for m: Dictionary in missions:
		for c: Dictionary in m.get("intro", []) + m.get("outro", []):
			for w: String in NOT_SAID:
				if String(c.get("text", "")).contains(w):
					said.append("%s: %s" % [m.id, w])
	_expect(said.is_empty(), "no nation's name in any line or card (the warnings' slot is empty)%s" % ("" if said.is_empty() else ": " + str(said)))


func _end() -> void:
	StoryDialogue.flags_alone.clear()
	if fails.is_empty():
		print("TWO FIRES SLICE TEST PASSED (%d checks)" % checks)
	else:
		print("TWO FIRES SLICE TEST FAILED (%d of %d)" % [fails.size(), checks])
		for f in fails:
			print("  - " + f)
	quit(0 if fails.is_empty() else 1)
