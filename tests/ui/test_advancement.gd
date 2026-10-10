extends SceneTree
## The Character Advancement window's data and logic (scripts/ui/advancement/: AdvancementData, AdvancementLoadout,
## AdvancementStore, AdvancementLayout; data/ui/advancement.json, advancement_layout.json, data/bending/fighting_styles.json;
## artifacts/ui_audit/advancement/plan.md sections 2-5), headless, no level:
##   data       every node of data/sway/skill_tree.json loads (133 in the draft of 2026-10-09); excludes are symmetric;
##              20 classes (each element's four styles and Jeet Kune Do), one canon each, Boxing animated and pickable,
##              Capoeira parked, the rest coming; each style's rail (stance, jab string, signature, guard) and levers
##              (two up, two down); the trees' titles; search
##   starters   every starter loadout (12) is valid at exactly 10 points, and its loadout code reads back the same
##   why_not    each reason fires on a crafted case (unknown, held, excludes, requires, world only, budget, kind cap,
##              one twist per move-mode, 4 points per move-mode, the control scheme's greying, the two gates), in the web
##              mockup's order; world mode skips the ring rules; held nodes can never be worn; take_off's requires cascade;
##              valid() catches broken picks; diff and the toasts
##   store      a round trip through the test's own file (AdvancementStore.path): slots, names, classes, worn, the
##              padlock, the menu line; unknown, other-element, held and world-only ids dropped on read; a slot that
##              breaks a rule kept, marked invalid and worn as Classic; a tree_version change re-validated
##   layout     for all four elements and both trees in ring mode: every ring-visible node placed, nothing world-only,
##              no unpinned id, no two slots closer than one icon, all inside the zone, links only inside a line between
##              consecutive tiers, every choice mutually exclusive, the left tree only LMB/E/1/2, and the GDScript
##              algorithm equal to the tool's (the file's "generated" block)
##   words      every word the window shows: no show word, no 'bend' in any form, no third-party game or company name,
##              no real person's name in the styles
##   phase A    saving and wearing a loadout changes no move's numbers
##   Godot --headless --path . -s tests/ui/test_advancement.gd
## The last line "ADVANCEMENT TEST PASSED" or "ADVANCEMENT TEST FAILED"; exit 0 only on a pass; a watchdog quits with 2.

const NAME := "ADVANCEMENT TEST"
const LIMIT_S := 120.0
const OWN_FILE := "user://advancement_test_own.json"
## tests/ring/test_player_words.gd's words and round 2's, plus the names this window must never show.
const BANNED := ["avatar", "benders?", "bending", "pro-?bend\\w*", "korra", "aang", "airbend\\w*", "firebend\\w*",
		"earthbend\\w*", "waterbend\\w*", "air scooters?", "fire nation", "water tribes?", "earth kingdom", "air nomads?",
		"republic city", "ba sing se", "omashu", "water whip", "air balls?", "air shields?", "spouts?",
		"redirect lightning", "bend\\w*", "spellbreak", "azeroth", "warcraft", "blizzard", "wow", "ascension"]
## Real people the design doc names (the styles' player text must not).
const PEOPLE := ["bruce", "lee", "sokka", "piandao", "zuko", "kyoshi", "jet li", "ip man"]

var checks := 0
var fails: Array[String] = []
var _re := RegEx.create_from_string("(?i)\\b(?:%s)\\b" % "|".join(PackedStringArray(BANNED)))
var _people := RegEx.create_from_string("(?i)\\b(?:%s)\\b" % "|".join(PackedStringArray(PEOPLE)))


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		print("  ok   ", what)
	else:
		fails.append(what)
		print("  FAIL ", what)


func _run() -> void:
	AdvancementData.reload_data()
	AdvancementLayout.reload_data()
	AdvancementData.gates_override = {}
	_data()
	_styles()
	_starters()
	_why_not()
	_rules()
	_store()
	_layout()
	_words()
	_phase_a()
	AdvancementStore.path = AdvancementStore.PATH
	AdvancementStore.reload_file()
	print("%d checks, %d failed" % [checks, fails.size()])
	for f in fails:
		print("  failed: ", f)
	print("%s %s" % [NAME, "PASSED" if fails.is_empty() else "FAILED"])
	quit(0 if fails.is_empty() else 1)


# --- data --------------------------------------------------------------------------------------------------------------

func _raw_count() -> int:
	var t: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AdvancementData.TREE_PATH))
	var c := 0
	for el: String in t.elements:
		for b: Dictionary in t.elements[el].branches:
			c += (b.nodes as Array).size()
	return c


func _data() -> void:
	print("data")
	var total := 0
	for el: String in AdvancementData.ELEMENTS:
		total += AdvancementData.nodes(el).size()
	check(total == _raw_count() and total > 0, "every node of skill_tree.json loads (%d)" % total)
	check(total == 133, "the draft's 133 nodes (%d)" % total)
	var asym: Array = []
	for el: String in AdvancementData.ELEMENTS:
		for n: Dictionary in AdvancementData.nodes(el):
			for x: String in n.excludes:
				var o := AdvancementData.node(x)
				if o.is_empty() or not String(n.id) in (o.excludes as Array):
					asym.append("%s -> %s" % [n.id, x])
	check(asym.is_empty(), "excludes are symmetric %s" % str(asym))
	var held := 0
	for el: String in AdvancementData.ELEMENTS:
		for n: Dictionary in AdvancementData.nodes(el):
			held += 1 if bool(n.held) else 0
	check(held == 14, "14 held nodes (%d)" % held)
	var n := AdvancementData.node("air.frost.blizzard")
	check(String(n.name) == "Snowstorm" and not "visual" in n and not "fx" in n, "player text overrides apply; no effect references leave the data (%s)" % n.name)
	check(String(AdvancementData.node("earth.boulder.heavy").move_label) == "Boulder", "move labels from the modes (Boulder)")
	check(bool(AdvancementData.node("earth.boulder.heavy").tap_twice) and not bool(AdvancementData.node("earth.spike.steady_point").tap_twice)
			and bool(AdvancementData.node("earth.mend.reinforce").tap_twice) and bool(AdvancementData.node("fire.slot.cauterize").tap_twice)
			and not bool(AdvancementData.node("earth.passive.deep_roots").tap_twice), "tap-twice nodes: Boulder, Mend, the new skills; not Spike, not the passives")
	check(AdvancementData.kind_word("variation") == "Twist" and AdvancementData.kind_word("mastery") == "Technique", "kind words from kind_labels")
	check(AdvancementData.word("title") == "Character Advancement", "the title")
	var tabs := AdvancementData.words("tabs")
	check(tabs.get("advancement") == "Advancement" and tabs.get("loadouts") == "Loadouts" and tabs.get("look") == "Your look", "the tabs")
	check(AdvancementData.budget() == 10 and AdvancementData.cost("earth.slot.shell") == 3, "budget 10, costs")
	check(AdvancementData.zone("left") == Rect2(150, 140, 456, 580) and AdvancementData.zone("right") == Rect2(900, 140, 450, 580), "the tree zones")
	check(AdvancementData.color("worn") == Color.html("#ffd100"), "colours")
	var hits := AdvancementData.search("earth", "boulder")
	check("earth.boulder.heavy" in hits and "earth.boulder.avalanche" in hits and "earth.sulphur.boulder" in hits
			and AdvancementData.search("earth", "zzqq").is_empty(), "search finds by name and move (%d)" % hits.size())
	var gs := AdvancementData.gate_state("earth")
	check(gs.has("won") and gs.has("full_left") and bool(gs.first_win) and bool(gs.full_lessons) and int(gs.full_left) >= 0,
			"gate_state reads the game: %s" % str(gs))


func _styles() -> void:
	print("styles")
	var classes := 0
	for el: String in AdvancementData.ELEMENTS:
		var ss := AdvancementData.styles(el)
		classes += ss.size()
		var canon := 0
		for s: Dictionary in ss:
			canon += 1 if bool(s.canon) else 0
			check((s.rail as Array).size() == 4, "%s %s: 4 traits on the rail" % [el, s.id])
			var ids: Array = []
			for r: Dictionary in AdvancementData.rail(String(s.id), el):
				ids.append(r.id)
				if String(r.id) in ["jab", "signature", "guard"]:
					check(String(r.move_label) != "" and String(r.line) != "", "%s %s: %s has a move (%s)" % [el, s.id, r.id, r.move_label])
			check(ids == ["stance", "jab", "signature", "guard"], "%s %s: stance, jab string, signature, guard" % [el, s.id])
			var up := 0
			var down := 0
			for lv: Dictionary in AdvancementData.levers(String(s.id)):
				up += 1 if int(lv.sign) > 0 else 0
				down += 1 if int(lv.sign) < 0 else 0
			check(up == 2 and down == 2, "%s %s: two levers up, two down" % [el, s.id])
		check(ss.size() == 5 and canon == 1, "%s: 5 classes, one canon (%d, %d)" % [el, ss.size(), canon])
		check(String(ss[4].id) == "jeet_kune_do", "%s: Jeet Kune Do last" % el)
		check(AdvancementData.pickable(AdvancementData.canon_style(el)), "%s: its canon style can be picked" % el)
	check(classes == 20, "20 classes (%d)" % classes)
	var bx := AdvancementData.style("boxing")
	check(String(bx.state) == "animated" and bool(bx.pickable) and String(bx.library) == "res://animations_extra/Frontier_Style_Boxing.res", "Boxing: animated, pickable, its library")
	check(String(AdvancementData.style("capoeira").state) == "parked" and not AdvancementData.pickable("capoeira"), "Capoeira: parked, not pickable")
	check(String(AdvancementData.style("karate").state) == "coming" and not AdvancementData.pickable("karate"), "Karate: coming, not pickable")
	check(AdvancementData.title("fire", "left", "boxing") == "BOXING" and AdvancementData.title("earth", "left") == "HUNG GAR", "left titles: the style")
	check(AdvancementData.title("earth", "right") == "SULPHUR" and AdvancementData.title("water", "right") == "MUD"
			and AdvancementData.title("fire", "right") == "MAGMA" and AdvancementData.title("air", "right") == "FROSTWIND", "right titles: the skill set")


func _starters() -> void:
	print("starters")
	var n := 0
	for el: String in AdvancementData.ELEMENTS:
		for s: Dictionary in AdvancementData.starters(el):
			n += 1
			var lo := AdvancementLoadout.from_starter(el, String(s.id))
			check(lo != null and lo.cost() == 10 and lo.valid() == "", "%s %s: valid at 10 points (%d, '%s')" % [el, s.name, lo.cost() if lo else -1, lo.valid() if lo else "null"])
			var back := AdvancementLoadout.from_code(lo.code())
			check(back != null and back.same_as(lo), "%s %s: code %s reads back" % [el, s.name, lo.code()])
			var bx := AdvancementLoadout.from_starter(el, String(s.id), "boxing")
			if el == "fire":
				var b2 := AdvancementLoadout.from_code(bx.code())
				check(b2 != null and b2.style == "boxing" and b2.same_as(bx), "fire %s as Boxing: the code keeps the class" % s.name)
	check(n == 12, "12 starter loadouts (%d)" % n)
	check(AdvancementLoadout.from_code("nonsense") == null and AdvancementLoadout.from_code("TB1-x-0-1") == null
			and AdvancementLoadout.from_code("TB1-e-9-1") == null and AdvancementLoadout.from_code("TB1-e-0-zzzzzzzzzzzzz") == null,
			"bad codes read as null")
	check(AdvancementLoadout.from_starter("earth", "water.preset.pools") == null, "a premade of another element is refused")


# --- why_not -------------------------------------------------------------------------------------------------------------

func _lo(el: String, ids: Array = []) -> AdvancementLoadout:
	var lo := AdvancementLoadout.new(el)
	for id: String in ids:
		var w := lo.wear(id)
		if w != "":
			print("    (fixture: %s not worn: %s)" % [id, w])
	return lo


func _case(lo: AdvancementLoadout, id: String, code: String, what: String) -> void:
	var got := lo.why_not_code(id)
	check(got == code, "why_not %s: %s -> %s ('%s')" % [what, id, got, lo.why_not(id)])


func _why_not() -> void:
	print("why_not")
	_case(_lo("earth"), "earth.nothing.here", "unknown", "an unknown id")
	_case(_lo("earth"), "water.turn.patient", "unknown", "another element's node")
	_case(_lo("earth"), "earth.slot.shell", "held", "a held node")
	_case(_lo("water", ["water.spear.cold_hands"]), "water.spear.heavy", "excludes", "an excludes pair")
	_case(_lo("water", ["water.spear.heavy"]), "water.spear.cold_hands", "excludes", "the same pair the other way")
	_case(_lo("earth"), "earth.sulphur.vent", "requires", "a missing requires")
	_case(_lo("earth"), "earth.column.broad", "world_only", "a ring-illegal number swap")
	_case(_lo("earth"), "earth.world.disc", "world_only", "a world-only node")
	var rally := AdvancementLoadout.from_starter("earth", "earth.preset.rally")
	_case(rally, "earth.catch.clean_return", "budget", "over the 10 points")
	_case(_lo("earth", ["earth.catch.return_to_sender"]), "earth.wall.quarry", "kind_cap", "a second technique")
	_case(_lo("earth", ["earth.set.sulphur", "earth.passive.deep_roots"]), "earth.sulphur.heart", "kind_cap", "a second passive")
	_case(_lo("air", ["air.set.frostwind", "air.slot.dust"]), "air.frost.blizzard", "kind_cap", "a second new skill")
	_case(_lo("earth", ["earth.set.sulphur", "earth.boulder.avalanche"]), "earth.sulphur.boulder", "twist", "a second twist on Boulder")
	_case(_lo("earth", ["earth.catch.clean_return", "earth.catch.open_hands", "earth.catch.juggle"]), "earth.catch.return_to_sender", "move_points", "a fifth point on the Catch")
	var fm := _lo("earth")
	fm.scheme = "first_moves"
	_case(fm, "earth.boulder.heavy", "scheme", "a tap-twice node under First moves only")
	_case(fm, "earth.spike.steady_point", "", "a first-move node under First moves only")
	var dr := _lo("earth")
	dr.scheme = "direction"
	_case(dr, "earth.mend.reinforce", "scheme", "Mend under Direction")
	var ks := _lo("earth")
	ks.scheme = "keys"
	_case(ks, "earth.boulder.heavy", "", "a tap-twice node under the keys")
	var g1 := _lo("earth")
	g1.gates = {"won": false, "full_left": 4, "first_win": true, "full_lessons": true}
	_case(g1, "earth.spike.steady_point", "gate_first_win", "before the first win")
	var g2 := _lo("earth")
	g2.gates = {"won": true, "full_left": 4, "first_win": true, "full_lessons": true}
	_case(g2, "earth.boulder.avalanche", "gate_full", "a twist before the Full lessons")
	_case(g2, "earth.set.sulphur", "gate_full", "a skill set before the Full lessons")
	_case(g2, "earth.spike.steady_point", "", "an enhance after the first win")
	var g3 := _lo("earth")
	g3.gates = {"won": true, "full_left": 0, "first_win": true, "full_lessons": true}
	_case(g3, "earth.boulder.avalanche", "", "a twist after the Full lessons")
	var g4 := _lo("earth")
	g4.gates = {"won": false, "full_left": 4, "first_win": false, "full_lessons": false}
	_case(g4, "earth.boulder.avalanche", "", "both gates switched off")
	check(g1.why_not("earth.spike.steady_point") == AdvancementData.word("reasons.gate_first_win")
			and g2.why_not("earth.boulder.avalanche") == AdvancementData.word("reasons.gate_full") % 4, "the gates' reasons read from the words")
	# the order: held before everything, excludes before requires, requires before world only, world only before budget
	_case(rally, "earth.slot.shell", "held", "held comes first, over budget too")
	_case(_lo("earth", ["earth.boulder.heavy"]), "earth.sulphur.boulder", "excludes", "excludes before requires")
	_case(rally, "earth.column.broad", "world_only", "world only before the budget")
	var wd := _lo("earth")
	wd.mode = "world"
	_case(wd, "earth.column.broad", "", "world mode: an open-world swap")
	_case(wd, "earth.slot.shell", "held", "world mode: held still blocks")
	_case(wd, "earth.sulphur.vent", "requires", "world mode: requires still holds")
	check(rally.why_not("earth.catch.juggle") == "" and rally.why_not_code("earth.catch.juggle") == "", "a worn node: nothing blocks it")
	check(_lo("earth").why_not("earth.catch.clean_return") == "" and _lo("earth").can_wear("earth.catch.clean_return"), "a free node can be worn")
	var bud := rally.why_not("earth.catch.clean_return")
	check(bud == AdvancementData.word("reasons.budget") % [1, 0], "the budget reason names cost and points left ('%s')" % bud)
	# held nodes can never be worn, in either mode
	var held_ok := true
	for el: String in AdvancementData.ELEMENTS:
		for n: Dictionary in AdvancementData.nodes(el):
			if not bool(n.held):
				continue
			for m: String in ["ring", "world"]:
				var lo := AdvancementLoadout.new(el)
				lo.mode = m
				for r: String in n.requires:
					lo.wear(r)
				if lo.wear(String(n.id)) == "" or lo.has(String(n.id)):
					held_ok = false
					print("    held worn: ", n.id, " ", m)
	check(held_ok, "no held node can be worn (ring or world)")


func _rules() -> void:
	print("rules")
	var pit := AdvancementLoadout.from_starter("earth", "earth.preset.sulphur_pit")
	var off := pit.take_off("earth.set.sulphur")
	off.sort()
	var want := ["earth.set.sulphur", "earth.sulphur.boulder", "earth.sulphur.flint_pebbles", "earth.sulphur.vent"]
	check(off == want, "taking off Sulphur takes off its twists and Vent %s" % str(off))
	check(pit.picks.size() == 2 and pit.has("earth.wall.thick") and pit.has("earth.spike.steady_point"), "the rest stays")
	check(pit.take_off("earth.set.sulphur").is_empty(), "taking off what is not worn takes nothing")
	var two := AdvancementLoadout.new("earth", "", ["earth.passive.deep_roots", "earth.passive.swift_roots"])
	check(two.valid() != "", "valid: two passives that exclude each other ('%s')" % two.valid())
	var over := AdvancementLoadout.new("earth", "", ["earth.catch.juggle", "earth.catch.return_to_sender", "earth.boulder.avalanche",
			"earth.wall.rubble", "earth.wall.thick", "earth.burrow.lie_low", "earth.spike.steady_point"])
	check(over.valid() != "", "valid: over the budget ('%s')" % over.valid())
	var orphan := AdvancementLoadout.new("earth", "", ["earth.sulphur.vent"])
	check(orphan.valid() != "", "valid: a set twist without its set ('%s')" % orphan.valid())
	var order := AdvancementLoadout.new("earth", "", ["earth.sulphur.vent", "earth.set.sulphur"])
	check(order.valid() == "", "valid: requires counted whatever the pick order ('%s')" % order.valid())
	var shell := AdvancementLoadout.new("earth", "", ["earth.slot.shell"])
	check(shell.valid() != "", "valid: a held node ('%s')" % shell.valid())
	var st := AdvancementLoadout.new("earth", "karate", [])
	check(st.valid() == AdvancementData.word("reasons.style"), "valid: a class not ready yet")
	check(AdvancementLoadout.new("fire", "boxing", []).valid() == "" and AdvancementLoadout.new("fire", "capoeira", []).valid() != "",
			"valid: Boxing on fire; not Capoeira (air's, parked)")
	var gated := AdvancementLoadout.from_starter("earth", "earth.preset.quake")
	gated.gates = {"won": true, "full_left": 2, "first_win": true, "full_lessons": true}
	check(gated.valid() == "" and gated.valid(true) != "", "valid: the gates count only when asked")
	var saved := AdvancementLoadout.from_starter("earth", "earth.preset.quake")
	var pend := saved.copy()
	pend.take_off("earth.column.heave")
	pend.wear("earth.catch.return_to_sender")
	var d := pend.diff(saved)
	check(d.worn == ["earth.catch.return_to_sender"] and d.taken_off == ["earth.column.heave"] and not bool(d.style), "diff: worn and taken off %s" % str(d))
	var t := pend.toasts(saved)
	check(t.size() == 1 and String(t[0].text) == "New technique worn: Return to Sender", "toasts: %s" % str(t))
	var t2 := AdvancementLoadout.from_starter("earth", "earth.preset.sulphur_pit").toasts(AdvancementLoadout.classic("earth"))
	var kinds: Array = []
	for x: Dictionary in t2:
		kinds.append(x.kind)
	check(kinds == ["skill_set", "new_skill", "variation"], "toasts for sets, new skills and twists only, in worn order %s" % str(kinds))
	check(pend.spent("left") + pend.spent("right") == pend.cost(), "points by tree add up")
	check(not saved.same_as(pend) and saved.same_as(saved.copy()), "same_as")


# --- the store -----------------------------------------------------------------------------------------------------------

func _write(text: String) -> void:
	var f := FileAccess.open(OWN_FILE, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	AdvancementStore.reload_file()


func _store() -> void:
	print("store")
	check(AdvancementStore.file() == AdvancementStore.TEST_PATH, "a test run (-s) reads the test path, never the player's")
	AdvancementStore.path = OWN_FILE
	_write("{}")
	check(AdvancementStore.file() == OWN_FILE, "a test may point the store at its own file")
	for el: String in AdvancementData.ELEMENTS:
		check(AdvancementStore.worn_index(el) == -1 and AdvancementStore.slots(el).size() == 3 and AdvancementStore.worn_loadout(el).is_empty(),
				"%s: a new file wears Classic, 3 empty slots" % el)
		check(AdvancementStore.style_of(el) == AdvancementData.canon_style(el), "%s: the canon class at first" % el)
	var rally := AdvancementLoadout.from_starter("earth", "earth.preset.rally")
	check(AdvancementStore.save_slot("earth", 0, rally, "Rally", "earth.preset.rally") == "", "earth slot 1 saved")
	check(AdvancementStore.wear("earth", 0), "earth slot 1 worn")
	var blaze := AdvancementLoadout.from_starter("fire", "fire.preset.blaze", "boxing")
	check(AdvancementStore.save_slot("fire", 1, blaze, "Blaze") == "" and AdvancementStore.wear("fire", 1), "fire slot 2 saved as Boxing and worn")
	var bad := AdvancementLoadout.new("earth", "", ["earth.catch.return_to_sender", "earth.wall.quarry"])
	check(AdvancementStore.save_slot("earth", 2, bad) != "", "a loadout that breaks a rule is not saved")
	check(AdvancementStore.save_slot("earth", 2, AdvancementLoadout.new("earth", "karate")) != "", "a class not ready yet is not saved")
	check(AdvancementStore.set_keep("earth", 2, true) and AdvancementStore.save_slot("earth", 2, AdvancementLoadout.classic("earth")) != "", "a kept slot is not changed")
	AdvancementStore.set_keep("earth", 2, false)
	check(AdvancementStore.rename("earth", 2, "  A name far too long for the little slot  ") and AdvancementStore.slot_name("earth", 2).length() <= 24, "names trimmed to name_max")
	AdvancementStore.reload_file()
	var back := AdvancementStore.slot("earth", 0)
	check(back.same_as(rally) and AdvancementStore.worn_index("earth") == 0 and AdvancementStore.worn_loadout("earth").same_as(rally), "earth round trip: the slot and the worn one")
	var info := AdvancementStore.slot_info("earth", 0)
	check(String(info.name) == "Rally" and String(info.from) == "earth.preset.rally" and int(info.saved_unix) > 0 and not info.has("invalid"), "earth slot record %s" % str(info))
	check(AdvancementStore.style_of("fire") == "boxing" and AdvancementStore.worn_loadout("fire").same_as(blaze), "fire round trip: the class (Boxing) and picks")
	check(AdvancementStore.slot_state("earth", 0) == "worn" and AdvancementStore.slot_state("fire", 0) == "empty", "slot states")
	var ml := AdvancementStore.menu_line("fire")
	check(ml == "Ember · Boxing · Loadout 2: Blaze, 10 of 10", "the menu line ('%s')" % ml)
	check(AdvancementStore.menu_line("water") == "Tide · Tai Chi · Classic", "Classic's menu line ('%s')" % AdvancementStore.menu_line("water"))
	check(AdvancementStore.set_style("water", "karate") != "" and AdvancementStore.set_style("water", "tai_chi") == "", "set_style takes only the element's pickable styles")
	check(AdvancementStore.wear("earth", -1) and AdvancementStore.worn_loadout("earth").is_empty(), "Classic worn again")
	# unknown, other-element, held and world-only ids dropped; a broken slot kept, marked, worn as Classic; tree_version
	var raw := {"format": "tidebreak-advancement", "version": 1, "tree_version": 0, "elements": {
		"earth": {"style": "hung_gar", "worn": 1, "slots": [
			{"name": "Mixed", "style": "hung_gar", "nodes": ["earth.catch.juggle", "earth.gone.away", "water.turn.patient", "earth.slot.shell",
					"earth.world.disc", "earth.column.broad", "earth.catch.juggle"], "saved_unix": 5, "keep": false},
			{"name": "Broken", "style": "hung_gar", "nodes": ["earth.catch.return_to_sender", "earth.wall.quarry"], "saved_unix": 5, "keep": false}]},
		"water": {"style": "no_such_style", "worn": 7, "slots": "junk"}}, "world": {"kept": 1}}
	_write(JSON.stringify(raw))
	var s0 := AdvancementStore.slot_info("earth", 0)
	check(s0.nodes == ["earth.catch.juggle"], "unknown, other-element, held, world-only and repeated ids dropped %s" % str(s0.nodes))
	check(AdvancementStore.dropped.size() == 6, "the dropped ids are listed (%d: %s)" % [AdvancementStore.dropped.size(), str(AdvancementStore.dropped)])
	var s1 := AdvancementStore.slot_info("earth", 1)
	check(s1.has("invalid") and AdvancementStore.slot_state("earth", 1) == "invalid", "a slot that breaks a rule is kept, marked invalid ('%s')" % s1.get("invalid", ""))
	check(AdvancementStore.worn_index("earth") == 1 and AdvancementStore.worn_loadout("earth").is_empty() and AdvancementStore.slot("earth", 1).picks.size() == 2,
			"the invalid slot is worn as Classic, and still opens with its picks to fix")
	check(AdvancementStore.style_of("water") == "tai_chi" and AdvancementStore.worn_index("water") == -1 and AdvancementStore.slots("water").size() == 3,
			"junk element records read as the canon class and Classic")
	check(AdvancementStore.save_slot("earth", 1, AdvancementLoadout.from_starter("earth", "earth.preset.quake")) == "" and not AdvancementStore.slot_info("earth", 1).has("invalid"),
			"saving the slot again clears its mark")
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OWN_FILE))
	check(int(f.tree_version) == AdvancementData.tree_version() and String(f.format) == "tidebreak-advancement" and (f.world as Dictionary).get("kept") == 1.0,
			"a save writes the tree's version and keeps the world block")
	_write("{}")


# --- the layout ----------------------------------------------------------------------------------------------------------

func _layout() -> void:
	print("layout")
	for el: String in AdvancementData.ELEMENTS:
		for side: String in AdvancementData.SIDES:
			_layout_one(el, side)
			_layout_world(el, side)


## World mode (Phase C: the algorithm alone, no pins): every node it shows placed, apart and inside the zone.
func _layout_world(el: String, side: String) -> void:
	var p := AdvancementLayout.place(el, side, "world")
	var items: Array = p.items
	var icon := float(p.icon)
	var zone: Rect2 = p.zone
	var missing: Array = []
	for n: Dictionary in AdvancementData.tree_nodes(el, side, "world"):
		if not (p.by_id as Dictionary).has(n.id):
			missing.append(n.id)
	var bad: Array = []
	for i in items.size():
		var a: Vector2 = items[i].pos
		if a.x - icon / 2.0 < -0.01 or a.y - icon / 2.0 < -0.01 or a.x + icon / 2.0 > zone.size.x + 0.01 or a.y + icon / 2.0 > zone.size.y + 0.01:
			bad.append(items[i].key)
		for j in range(i + 1, items.size()):
			var b: Vector2 = items[j].pos
			if absf(a.x - b.x) < icon - 0.01 and absf(a.y - b.y) < icon - 0.01:
				bad.append("%s ~ %s" % [items[i].key, items[j].key])
	check(missing.is_empty() and bad.is_empty() and (p.unpinned as Array).is_empty(),
			"%s %s world mode: %d slots, all placed apart inside the zone %s %s" % [el, side, items.size(), str(missing), str(bad)])


func _layout_one(el: String, side: String) -> void:
	var tag := "%s %s" % [el, side]
	var p := AdvancementLayout.place(el, side, "ring")
	var items: Array = p.items
	var icon := float(p.icon)
	var zone: Rect2 = p.zone
	check(not items.is_empty(), "%s: laid out (%d slots)" % [tag, items.size()])
	check((p.unpinned as Array).is_empty(), "%s: every id pinned %s" % [tag, str(p.unpinned)])
	var missing: Array = []
	for n: Dictionary in AdvancementData.tree_nodes(el, side, "ring"):
		if not (p.by_id as Dictionary).has(n.id):
			missing.append(n.id)
	check(missing.is_empty(), "%s: every ring-visible node placed %s" % [tag, str(missing)])
	var wrong: Array = []
	for it: Dictionary in items:
		for id: String in it.ids:
			var n := AdvancementData.node(id)
			if String(n.kind) == "world_only" or (not bool(n.legal) and not bool(n.held)) or String(n.side) != side:
				wrong.append(id)
			if side == "left" and not String(n.slot_chip) in AdvancementData.left_chips():
				wrong.append(id)
	check(wrong.is_empty(), "%s: no world-only node, no ring-illegal swap, the split kept %s" % [tag, str(wrong)])
	var overlaps: Array = []
	var outside: Array = []
	for i in items.size():
		var a: Vector2 = items[i].pos
		if a.x - icon / 2.0 < -0.01 or a.y - icon / 2.0 < -0.01 or a.x + icon / 2.0 > zone.size.x + 0.01 or a.y + icon / 2.0 > zone.size.y + 0.01:
			outside.append(items[i].key)
		for j in range(i + 1, items.size()):
			var b: Vector2 = items[j].pos
			if absf(a.x - b.x) < icon - 0.01 and absf(a.y - b.y) < icon - 0.01:
				overlaps.append("%s ~ %s" % [items[i].key, items[j].key])
	check(overlaps.is_empty(), "%s: no two slots closer than one icon %s" % [tag, str(overlaps)])
	check(outside.is_empty(), "%s: all inside the zone %s" % [tag, str(outside)])
	var bad_links: Array = []
	for l: Dictionary in p.links:
		if not (p.by_key as Dictionary).has(l.from) or not (p.by_key as Dictionary).has(l.to):
			bad_links.append("%s>%s" % [l.from, l.to])
			continue
		var a: Dictionary = items[p.by_key[l.from]]
		var b: Dictionary = items[p.by_key[l.to]]
		if int(a.line) != int(b.line) or int(a.tier) >= int(b.tier):
			bad_links.append("%s>%s" % [l.from, l.to])
	check(bad_links.is_empty() and not (p.links as Array).is_empty(), "%s: links only down a line, between placed slots %s" % [tag, str(bad_links)])
	var not_excl: Array = []
	for it: Dictionary in items:
		if String(it.type) != "choice":
			continue
		var ids: Array = it.ids
		for i in ids.size():
			for j in ids.size():
				if i == j:
					continue
				var lo := AdvancementLoadout.new(el)
				for r: String in AdvancementData.node(ids[i]).requires:
					lo.wear(r)
				for r: String in AdvancementData.node(ids[j]).requires:
					lo.wear(r)
				if lo.wear(String(ids[i])) != "":
					continue
				var code := lo.why_not_code(String(ids[j]))
				if not code in ["excludes", "twist", "kind_cap", "held"]:
					not_excl.append("%s + %s (%s)" % [ids[i], ids[j], code])
	check(not_excl.is_empty(), "%s: every choice is one-of %s" % [tag, str(not_excl)])
	var gen := AdvancementLayout.generated(el, side)
	var alg := AdvancementLayout.algorithm(el, side, "ring")
	var diffs: Array = []
	var alg_keys := {}
	for it: Dictionary in alg.items:
		var keys: Array = [it.key] if String(it.type) == "root" else it.ids
		for k: String in keys:
			alg_keys[k] = true
			var got := Vector2(float(it.col), float(it.row))
			if not gen.has(k):
				diffs.append("%s missing/%s" % [k, str(got)])
				continue
			var want: Vector2 = gen[k]
			if want.distance_to(got) > 0.002:
				diffs.append("%s %s/%s" % [k, str(want), str(got)])
	for k: String in gen:
		if not alg_keys.has(k):
			diffs.append("%s only in the file" % k)
	check(diffs.is_empty(), "%s: the GDScript algorithm equals tools/ui/advancement_layout.py %s" % [tag, str(diffs)])
	var gates: Array = p.gates
	var types: Array = []
	for g: Dictionary in gates:
		types.append(g.type)
	check("first_win" in types and "full" in types, "%s: gate lines placed %s" % [tag, str(types)])


# --- words ---------------------------------------------------------------------------------------------------------------

func _strings(v: Variant, out: Array, skip_doc := true) -> void:
	if v is String:
		out.append(v)
	elif v is Array:
		for x: Variant in v:
			_strings(x, out, skip_doc)
	elif v is Dictionary:
		for k: Variant in v:
			if skip_doc and String(k).begins_with("_"):
				continue
			_strings(v[k], out, skip_doc)


func _words() -> void:
	print("words")
	var shown: Array = []
	_strings(AdvancementData.ui().get("words", {}), shown)
	for el: String in AdvancementData.ELEMENTS:
		for n: Dictionary in AdvancementData.nodes(el):
			for f: String in AdvancementData.PLAYER_FIELDS:
				shown.append(String(n[f]))
			shown.append(String(n.kind_word))
			shown.append(String(n.move_label))
		for s: Dictionary in AdvancementData.starters(el):
			shown.append(String(s.name))
			shown.append(String(s.line))
		for side: String in AdvancementData.SIDES:
			shown.append(AdvancementData.title(el, side))
		shown.append(AdvancementData.passive_of(el).get("label", ""))
	var style_text: Array = []
	for el: String in AdvancementData.ELEMENTS:
		for s: Dictionary in AdvancementData.styles(el):
			style_text.append(String(s.label))
			style_text.append(String(s.known))
			for r: Dictionary in AdvancementData.rail(String(s.id), el):
				style_text.append(String(r.label))
				style_text.append(String(r.line))
				style_text.append(String(r.perfect))
			for lv: Dictionary in AdvancementData.levers(String(s.id)):
				style_text.append(String(lv.line))
			shown.append(AdvancementData.title(el, "left", String(s.id)))
	shown.append_array(style_text)
	var hits: Array = []
	for t: String in shown:
		for m in _re.search_all(t):
			hits.append("'%s' in '%s'" % [m.get_string(), t.substr(0, 60)])
	check(hits.is_empty(), "no banned word in %d lines the window shows %s" % [shown.size(), str(hits)])
	var people: Array = []
	for t: String in style_text:
		for m in _people.search_all(t):
			people.append("'%s' in '%s'" % [m.get_string(), t.substr(0, 60)])
	check(people.is_empty(), "no real person named in the styles %s" % str(people))
	var quotes: Array = []
	for t: String in style_text:
		if t.contains("\"") or t.contains("“"):
			quotes.append(t.substr(0, 60))
	check(quotes.is_empty(), "no quotes in the styles' text %s" % str(quotes))


# --- phase A -------------------------------------------------------------------------------------------------------------

func _phase_a() -> void:
	print("phase A")
	var before := {}
	for id: String in ["earth_wall", "stone_form", "fire_blast", "air_gust", "water_shield", "patch"]:
		before[id] = JSON.stringify(SwayMoves.move(id))
	AdvancementStore.path = OWN_FILE
	_write("{}")
	AdvancementStore.save_slot("earth", 0, AdvancementLoadout.from_starter("earth", "earth.preset.quake"), "Quake")
	AdvancementStore.wear("earth", 0)
	AdvancementStore.save_slot("fire", 0, AdvancementLoadout.from_starter("fire", "fire.preset.forge", "boxing"), "Forge")
	AdvancementStore.wear("fire", 0)
	var same := true
	for id: String in before:
		if JSON.stringify(SwayMoves.move(id)) != before[id]:
			same = false
			print("    changed: ", id)
	check(same, "saving and wearing loadouts changes no move's numbers (Phase A: every match plays Classic)")
	_write("{}")
