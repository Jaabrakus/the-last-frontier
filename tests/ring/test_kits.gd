extends SceneTree
## Round 2's kits as data (KITS: skills_r2/spec.md 2, 3, 8.1 and the owner's answers of 2026-10-05; data/sway/moves.json
## elements, guards, jabs, passives, guard_rules, stones; data/bending/schemes.json; data/npc/bend_ai.json;
## data/ring/rules.json and ring.json's deck stones), headless, no level:
##   Godot --headless --path . -s tests/ring/test_kits.gd
##   keys       every element: keys 1-3 two moves each (one move of two variations, or two of one), key 4 one (fire's two:
##              Fire Wall and Breath, the owner kept Breath), key 5 Patch (and Mend for earth and water); a guard (E) and a
##              jab (the left button), neither on 1-5; every move and variation of them is in the data
##   names      every variation the kits offer is called by the plain move name the spec gives (Spike, Boulder, ... Wind
##              Guard); no label, grow label, passive line or scheme word holds a show word (bend, bender, Avatar, Korra,
##              the nations, Water Whip, air scooter, Air Ball, Air Shield, Spout, redirect lightning)
##   specs      every spec the kits offer has a "do" BendEffects.apply handles (or is an old mode BendCast casts itself);
##              none roots or slows a player or costs water (root_s, slow_s, water); every jab reaches 10 m at most; every
##              wall key's wall is placed 2-6 m where aimed, the fire and wind walls one at a time, rules.json counting the
##              wall key's pieces only; the Kick a floor wave that grows, the High Kick a crescent throw; the grows on key 2's
##              first move of every element and on fire's Punch (the Fireball)
##   blocks     passives, guard_rules (the spec's numbers), stones, no water meter (retired 2026-10-06); each guard with its window,
##              perfect_s and return (earth's catch: 1.0 s, 3.5 m, held, as before round 2)
##   schemes    first_moves and direction pairs exist, each one of the element's own
##   bots       bend_ai.json: the perfect-guard chance by preset (easy 0.1, normal 0.3, hard 0.6), a jump chance, no hint for
##              a cut move, the combos (Kick then Punch, Column then Spike, Pull then Palm, Geyser then Wave), a guard reflex
##              (guard_reaction_s) under each preset's reaction
##   deck       a deck stone shoved or lifted flies with ring.json sockets.hurl (at most 40 a strike, each kind), not the open
##              world's Gust numbers (RingArena._ring_hurls); a Stone Form boulder keeps its own (80)
## Last line "KITS TEST PASSED" or "KITS TEST FAILED"; exit 0 only on a pass; a watchdog quits with 2.

const NAME := "KITS TEST"
const LIMIT_S := 60.0
## The spec's names (8.1, owner answer 4): "move/variation" -> its label.
const NAMES := {
	"stone_form/spike": "Spike", "stone_form/cannonball": "Boulder", "earth_shove/push": "Fissure", "earth_shove/column": "Column",
	"earth_skate/burrow": "Burrow", "pillar/self": "Lift", "earth_wall/wall": "Wall", "stone_catch/catch": "Catch",
	"rock_jab/pebbles": "Pebbles",
	"water_whip/whip": "Lash", "ice/spear": "Spear", "wave/push": "Wave", "wave/spout": "Geyser", "flow/skate": "Skate",
	"flow/surf": "Surf", "water_shield/ice_wall": "Ice Wall", "water_redirect/redirect": "Turn", "water_jet/splash": "Splash",
	"fire_blast/punch": "Punch", "fire_arc/lightning": "Lightning", "fire_kick/kick": "Kick", "fire_kick/high_kick": "High Kick",
	"footwork/step": "Step", "fire_jets/jets": "Jets", "fire_wall/wall": "Fire Wall", "fire_breath/breath": "Breath",
	"fire_parry/parry": "Parry", "fire_jab/embers": "Embers",
	"air_blast/slice": "Slice", "air_blast/ball": "Wind Ball", "air_gust/gust": "Gust", "air_gust/pull": "Pull",
	"evade/slip": "Slip", "air_jump/leap": "Leap", "air_wall/wall": "Wind Wall", "air_shield/shield": "Wind Guard",
	"air_palm/palm": "Palm", "patch/patch": "Patch",
}
const SHOW := ["bend\\w*", "avatar", "korra", "aang", "fire nation", "water tribes?", "earth kingdom", "air nomads?",
		"water whip", "air scooters?", "air ball", "air shield", "spout", "redirect lightning", "nation"]
const RULES := {"perfect_s": 0.3, "late_mult": 0.5, "whiff_lock_s": 0.5, "whiff_s": 1.5, "return_lock_s": 0.35,
		"perfect_return_lock_s": 0.1, "perfect_mult": 1.2, "rally_step": 0.1, "rally_clean_step": 0.2, "rally_max": 1.6,
		"grow_after_s": 0.45, "sputter_s": 0.7, "click_s": 0.2, "double_tap_s": 0.3, "switch_hold_s": 0.2,
		"hit_setback_min_s": 0.25, "hold_drop_s": 0.0}
## The moves the kits cut (spec 5): never an option, a key, a guard or a jab, nor a bot's hint.
const CUT := ["earth_grip", "frost", "wind_run", "air_redirect", "gust"]

var checks := 0
var fails: Array[String] = []
var _show := RegEx.create_from_string("(?i)\\b(?:%s)\\b" % "|".join(PackedStringArray(SHOW)))


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


func _end() -> void:
	print("%s: %d checks, %d failed" % [NAME, checks, fails.size()])
	print("%s %s" % [NAME, "PASSED" if fails.is_empty() and checks > 0 else "FAILED"])
	quit(0 if fails.is_empty() and checks > 0 else 1)


func _run() -> void:
	_keys()
	_names()
	_specs()
	_blocks()
	_schemes()
	_bots()
	_deck()
	_end()


## Every (move, variation) the element's kit offers: [[id, mode], ...] (its keys, its guard, its jab).
func kit(el: String) -> Array:
	var out: Array = []
	for k in Bending.keys(el):
		for id: String in k:
			var ms := SwayCaster.modes_of(id)
			if ms.is_empty():
				out.append([id, ""])
			for md: String in ms:
				out.append([id, md])
	for b: String in ["guards", "jabs"]:
		var g: Array = (SwayMoves.data().get(b, {}) as Dictionary).get(el, [])
		if g.size() >= 2:
			out.append([String(g[0]), String(g[1])])
	return out


# ---------------------------------------------------------------- keys
func _keys() -> void:
	var d := SwayMoves.data()
	for el: String in Bending.ELEMENTS:
		var ks := Bending.keys(el)
		check(ks.size() == 5, "%s: five keys (%d)" % [el, ks.size()])
		if ks.size() != 5:
			continue
		for i in 3:
			check(_moves_on(ks[i]) == 2, "%s: key %d holds two moves (%s)" % [el, i + 1, ks[i]])
		var four: int = _moves_on(ks[3])
		if el == "fire":
			check(ks[3] == ["fire_wall", "fire_breath"], "fire: key 4 Fire Wall and Breath (the owner kept Breath; %s)" % [ks[3]])
		else:
			check(four == 1, "%s: key 4 one move, its wall (%s)" % [el, ks[3]])
		var heal: Array = ["patch", "mend"] if el in ["earth", "water"] else ["patch"]
		check(ks[4] == heal, "%s: key 5 %s (%s)" % [el, heal, ks[4]])
		var g: Array = (d.get("guards", {}) as Dictionary).get(el, [])
		var j: Array = (d.get("jabs", {}) as Dictionary).get(el, [])
		check(g.size() == 2 and String(g[1]) in SwayCaster.modes_of(String(g[0])), "%s: a guard on E (%s)" % [el, g])
		check(j.size() == 2 and String(j[1]) in SwayCaster.modes_of(String(j[0])), "%s: a jab on the left button (%s)" % [el, j])
		var on_keys: Array = []
		for k in ks:
			on_keys.append_array(k)
		check(not String(g[0]) in on_keys and not String(j[0]) in on_keys, "%s: the guard and the jab on none of 1-5" % el)
		for pr: Array in kit(el):
			check(not SwayMoves.move(String(pr[0])).is_empty() and not String(pr[0]) in CUT, "%s: %s/%s is a move of the data, not a cut one" % [el, pr[0], pr[1]])


## How many moves a key holds: two ids, or one id's variations.
func _moves_on(k: Array) -> int:
	if k.size() == 2:
		var ok := SwayCaster.modes_of(String(k[0])).size() == 1 and SwayCaster.modes_of(String(k[1])).size() <= 1
		return 2 if ok else -1
	return SwayCaster.modes_of(String(k[0])).size() if k.size() == 1 else -1


# ---------------------------------------------------------------- names
func _names() -> void:
	var seen := {}
	for el: String in Bending.ELEMENTS:
		for pr: Array in kit(el):
			var key := "%s/%s" % [pr[0], pr[1]]
			if pr[1] == "":
				continue
			seen[key] = true
			var lab := SwayCaster.mode_label(String(pr[0]), String(pr[1]))
			check(NAMES.get(key, "?") == lab, "%s: %s is called '%s' (%s)" % [el, key, NAMES.get(key, "?"), lab])
	check(seen.size() == NAMES.size(), "every named variation is offered (%d of %d)" % [seen.size(), NAMES.size()])
	var texts: Array = []
	for el: String in Bending.ELEMENTS:
		for pr: Array in kit(el):
			var m := SwayMoves.move(String(pr[0]))
			texts.append(String(m.get("label", "")))
			texts.append(SwayCaster.mode_label(String(pr[0]), String(pr[1])))
			var spec: Dictionary = (m.get("bend", {}) as Dictionary).get(String(pr[1]), {})
			texts.append(String(spec.get("grow_label", "")))
		var ps: Dictionary = (SwayMoves.data().get("passives", {}) as Dictionary).get(el, {})
		texts.append(String(ps.get("label", "")))
		texts.append(String(ps.get("line", "")))
	var sch: Dictionary = MatchSetup.schemes_data().get("schemes", {})
	for s: String in sch:
		for f: String in ["label", "line", "strip", "f1"]:
			texts.append(String((sch[s] as Dictionary).get(f, "")))
	var bad: Array = []
	for t: String in texts:
		for m in _show.search_all(t):
			bad.append("%s ('%s')" % [m.get_string(), t])
	check(bad.is_empty() and texts.size() > 100, "no show word in %d labels, lines and scheme words (%s)" % [texts.size(), ", ".join(bad)])


# ---------------------------------------------------------------- specs
## The dos BendEffects.apply handles (its match arms, read from its source).
func handled_dos() -> Array:
	var src := FileAccess.get_file_as_string("res://scripts/bending/bend_effects.gd")
	var a := src.find("match String(spec.get(\"do\", \"\")):")
	var out: Array = []
	if a < 0:
		return out
	var b := src.find("\n# ----", a)
	var body := src.substr(a, (b if b > a else src.length()) - a)
	var re := RegEx.create_from_string("(?m)^\\t\\t\"(\\w+)\"(?:, \"(\\w+)\")*:")
	for m in re.search_all(body):
		for part: String in m.get_string().strip_edges().trim_suffix(":").split(","):
			out.append(part.strip_edges().trim_prefix("\"").trim_suffix("\""))
	return out


func _specs() -> void:
	var dos := handled_dos()
	check(dos.size() >= 20 and "bolt" in dos and "zone" in dos, "BendEffects' dos read from its source (%d)" % dos.size())
	var bad_do: Array = []
	var bad_root: Array = []
	for el: String in Bending.ELEMENTS:
		for pr: Array in kit(el):
			var id := String(pr[0])
			var md := String(pr[1])
			var spec: Dictionary = (SwayMoves.move(id).get("bend", {}) as Dictionary).get(md, {})
			if spec.is_empty():
				if not BendCast.is_old(id, md):
					bad_do.append("%s/%s (no spec, not an old mode)" % [id, md])
				continue
			if not String(spec.get("do", "")) in dos:
				bad_do.append("%s/%s do %s" % [id, md, spec.get("do", "")])
			for k: String in ["root_s", "slow_s", "water"]:
				if spec.has(k) or (spec.get("grow", {}) as Dictionary).has(k):
					bad_root.append("%s/%s %s" % [id, md, k])
	check(bad_do.is_empty(), "every spec the kits offer is one BendEffects handles (%s)" % ", ".join(bad_do))
	check(bad_root.is_empty(), "no spec the kits offer roots, slows or costs water (%s)" % ", ".join(bad_root))
	# the jabs: close
	for el: String in Bending.ELEMENTS:
		var j: Array = (SwayMoves.data().get("jabs", {}) as Dictionary).get(el, [])
		var js: Dictionary = (SwayMoves.move(String(j[0])).get("bend", {}) as Dictionary).get(String(j[1]), {})
		check(float(js.get("range_m", 99.0)) <= 10.0, "%s: its jab reaches %.1f m (10 at most)" % [el, float(js.get("range_m", 99.0))])
	check(is_equal_approx(float(_spec("air_palm", "palm").get("knock_mps", 0.0)), 4.5), "Palm's knock 4.5")
	# the walls
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ring/rules.json"))
	check(int(rules.get("max_walls", 0)) == 2 and rules.get("wall_moves", []) == ["earth_wall/wall", "water_shield/ice_wall"]
			and rules.get("one_at_a_time", []) == ["fire_wall/wall", "air_wall/wall"],
			"rules.json: two walls, the wall key's pieces only; fire and wind walls one at a time")
	for key: String in ["water_shield/ice_wall", "fire_wall/wall", "air_wall/wall"]:
		var s := _spec(key.get_slice("/", 0), key.get_slice("/", 1))
		var pl: Dictionary = s.get("place", {})
		check(is_equal_approx(float(pl.get("min_m", 0.0)), 2.0) and is_equal_approx(float(pl.get("max_m", 0.0)), 6.0),
				"%s placed 2-6 m where aimed" % key)
	var ew: Dictionary = ((SwayMoves.move("earth_wall").get("ring", {}) as Dictionary).get("wall", {}) as Dictionary)
	check(bool(ew.get("self_lock", false)) and (ew.get("place", {}) as Dictionary).get("max_m") == 6.0, "the earth wall: self_lock, placed 2-6 m")
	check(bool(_spec("fire_wall", "wall").get("one_at_a_time", false)) and bool(_spec("air_wall", "wall").get("one_at_a_time", false))
			and is_equal_approx(float(_spec("air_wall", "wall").get("life_s", 0.0)), 4.0), "the fire and wind walls one at a time; the wind wall 4 s")
	# the kick and its kin
	var kick := _spec("fire_kick", "kick")
	var hk := _spec("fire_kick", "high_kick")
	check(String(kick.get("do", "")) == "floor_wave" and is_equal_approx(float(kick.get("miss_above_m", 0.0)), 0.6)
			and (kick.get("grow", {}) as Dictionary).has("width_m") and is_equal_approx(float(SwayMoves.move("fire_kick").get("lock_s", 0.0)), 0.6),
			"the Kick: a floor wave along the deck, missing feet 0.6 m up, that grows; lock 0.6 s")
	check(String(hk.get("do", "")) == "throw" and String(hk.get("shape", "")) == "crescent"
			and is_equal_approx(float((SwayMoves.move("fire_kick").get("mode_lock_s", {}) as Dictionary).get("high_kick", 0.0)), 0.85),
			"the High Kick: a crescent thrown on an arc, lock 0.85 s")
	check(is_equal_approx(float(_spec("fire_arc", "lightning").get("flash_s", 0.0)), 0.25), "Lightning flashes 0.25 s before it strikes")
	for el: String in Bending.ELEMENTS:
		var k2: Array = Bending.keys(el)[1]
		var id2 := String(k2[0])
		check((_spec(id2, String(SwayCaster.modes_of(id2)[0])).get("grow", {}) as Dictionary).size() > 0,
				"%s: key 2's first move grows (%s)" % [el, id2])
	var fb := _spec("fire_blast", "punch")
	check(String(fb.get("grow_label", "")) == "Fireball" and is_equal_approx(float((fb.get("grow", {}) as Dictionary).get("damage", 0.0)), 34.0),
			"fire's Punch grows into the Fireball (today's numbers)")
	check(SwayCaster.modes_of("stone_form") == ["spike", "cannonball"] and float(SwayMoves.move("stone_form").get("raise_at_fill", 0.0)) == 0.6,
			"Stone Form: Spike and Boulder (the disc cut), raised at 0.6 of the lock")


func _spec(id: String, md: String) -> Dictionary:
	return (SwayMoves.move(id).get("bend", {}) as Dictionary).get(md, {})


# ---------------------------------------------------------------- blocks
func _blocks() -> void:
	var d := SwayMoves.data()
	var gr: Dictionary = d.get("guard_rules", {})
	var off: Array = []
	for k: String in RULES:
		if not gr.has(k) or not is_equal_approx(float(gr[k]), float(RULES[k])):
			off.append(k)
	check(off.is_empty(), "guard_rules: the spec's numbers (%s)" % ", ".join(off))
	var st: Dictionary = d.get("stones", {})
	check(int(st.get("loose_max", 0)) == 3 and is_equal_approx(float(st.get("shove_loose_m", 0.0)), 6.0), "stones: 3 loose a player, shoved within 6 m")
	check(not d.has("water_meter"), "no water meter (retired 2026-10-06: lock time is the only limiter)")
	var ps: Dictionary = d.get("passives", {})
	check(is_equal_approx(float((ps.get("earth", {}) as Dictionary).get("fill_mult", 0.0)), 1.2)
			and is_equal_approx(float((ps.get("earth", {}) as Dictionary).get("knock_mult", 0.0)), 0.85)
			and is_equal_approx(float((ps.get("water", {}) as Dictionary).get("steer_max_deg", 0.0)), 15.0)
			and is_equal_approx(float((ps.get("fire", {}) as Dictionary).get("moving_mult", 0.0)), 1.0)
			and is_equal_approx(float((ps.get("air", {}) as Dictionary).get("knock_mult", 0.0)), 1.15),
			"the passives: Rooted, Flowing, Footwork, Carried wind (spec 2.4)")
	var catch := _spec("stone_catch", "catch")
	check(is_equal_approx(float(catch.get("window_s", 0.0)), 1.0) and is_equal_approx(float(catch.get("radius_m", 0.0)), 3.5)
			and bool(catch.get("holds", false)), "earth's Catch: 1.0 s, 3.5 m, it holds (as before round 2)")
	var want := {"water": ["water_redirect", "redirect", "swing", 0.8], "fire": ["fire_parry", "parry", "straight", 0.8],
			"air": ["air_shield", "shield", "bounce", 0.8]}
	for el: String in want:
		var w: Array = want[el]
		var g := _spec(String(w[0]), String(w[1]))
		check(String(g.get("return", "")) == w[2] and is_equal_approx(float(g.get("window_s", 0.0)), float(w[3]))
				and is_equal_approx(float(g.get("perfect_s", 0.0)), 0.3) and is_equal_approx(float(g.get("late_mult", 0.0)), 0.5),
				"%s's guard: %s back, %.1f s, perfect 0.3 s, late half" % [el, w[2], w[3]])


# ---------------------------------------------------------------- schemes
func _schemes() -> void:
	var sd := MatchSetup.schemes_data()
	check(sd.get("order", []) == ["keys", "direction", "radial", "first_moves"] and not (sd.get("schemes", {}) as Dictionary).has("simple")
			and (sd.get("schemes", {}) as Dictionary).has("first_moves"), "schemes.json: first_moves replaces simple")
	for el: String in Bending.ELEMENTS:
		var fm: Array = (sd.get("first_moves", {}) as Dictionary).get(el, [])
		var ok := fm.size() == 4
		for e: Array in fm:
			ok = ok and MatchSetup.quick_ok(el, String(e[0]), String(e[1]))
		check(ok, "%s: four first moves, each its own (%s)" % [el, fm])
		var dr: Dictionary = (sd.get("direction", {}) as Dictionary).get(el, {})
		var ok2 := dr.size() == 3
		for k: String in dr:
			ok2 = ok2 and not MatchSetup.direction_move(el, k).is_empty()
		check(ok2, "%s: the direction moves exist (%s)" % [el, dr])


# ---------------------------------------------------------------- bots
func _bots() -> void:
	var ai := NpcBending.ai()
	var ps: Dictionary = ai.get("presets", {})
	check(is_equal_approx(float((ps.get("easy", {}) as Dictionary).get("perfect_chance", -1.0)), 0.1)
			and is_equal_approx(float((ps.get("normal", {}) as Dictionary).get("perfect_chance", -1.0)), 0.3)
			and is_equal_approx(float((ps.get("hard", {}) as Dictionary).get("perfect_chance", -1.0)), 0.6),
			"the perfect-guard chance: easy 0.1, normal 0.3, hard 0.6")
	check(float((ps.get("normal", {}) as Dictionary).get("jump_chance", 0.0)) >= 0.3 and bool((ps.get("hard", {}) as Dictionary).get("lightning_dash", false)),
			"normal bots jump waves along the deck; hard bots dash on lightning's flash")
	var mv: Dictionary = ai.get("moves", {})
	var cut: Array = []
	for id: String in mv:
		if id in CUT or SwayMoves.move(id).is_empty():
			cut.append(id)
		for md: String in mv[id]:
			if md != "" and not md in SwayCaster.modes_of(id):
				cut.append("%s/%s" % [id, md])
	check(cut.is_empty(), "no bot hint for a cut move or variation (%s)" % ", ".join(cut))
	var combos := {"fire_blast/punch": "fire_kick/kick", "stone_form/spike": "earth_shove/column", "air_palm/palm": "air_gust/pull",
			"wave/push": "wave/spout"}
	for k: String in combos:
		var h := NpcBending.hint_of(k.get_slice("/", 0), k.get_slice("/", 1), _spec(k.get_slice("/", 0), k.get_slice("/", 1)))
		check(String((h.get("combo", {}) as Dictionary).get("after", "")) == combos[k], "the combo: %s, then %s" % [combos[k], k])
	for el: String in Bending.ELEMENTS:
		var opts := NpcBending.pairs_of(el)
		var g := NpcBending.guard_of(el)
		var j := NpcBending.jab_of(el)
		check(g in opts and j in opts and opts.size() == kit(el).size(), "%s: a bot's options are its kit, with its guard and its jab (%d)" % [el, opts.size()])
	check(NpcBending.is_guard(NpcBending.hint_of("stone_catch", "catch", _spec("stone_catch", "catch")))
			and "stone" in (NpcBending.hint_of("stone_catch", "catch", _spec("stone_catch", "catch")).get("answers", []) as Array)
			and "fire" in (NpcBending.hint_of("water_redirect", "redirect", _spec("water_redirect", "redirect")).get("answers", []) as Array)
			and "lightning" in (NpcBending.hint_of("fire_parry", "parry", _spec("fire_parry", "parry")).get("answers", []) as Array)
			and "stone" in (NpcBending.hint_of("air_shield", "shield", _spec("air_shield", "shield")).get("answers", []) as Array),
			"the bots' guards answer what each guard takes (catch stone; turn water, ice, fire; parry fire, lightning; wind guard air, stone)")
	check(NpcBending.shot_of("fire_kick", "kick").get("floor", false) == true and String(NpcBending.shot_of("earth_shove", "column").get("kind", "")) == "under",
			"a bot reads the Kick's wind-up as a wave along the deck, a Column's as rising under it")
	# the Air Lance (the Gust held long): water's Turn answers it (it turns it back as ice, the owner's 2026-10-11), and a bot
	# reads a grown Gust as the Lance, a spear of air; every other grow is read as the move itself, as before
	var lance := NpcBending.shot_of("air_gust", "gust", true)
	var gust := NpcBending.shot_of("air_gust", "gust")
	check("air_spear" in (NpcBending.hint_of("water_redirect", "redirect", _spec("water_redirect", "redirect")).get("answers", []) as Array)
			and not "air" in (NpcBending.hint_of("water_redirect", "redirect", _spec("water_redirect", "redirect")).get("answers", []) as Array),
			"water's Turn answers the Air Lance (air_spear), not every air shot")
	check(String(lance.get("kind", "")) == "air" and String(lance.get("shape", "")) == "spear" and is_equal_approx(float(lance.get("mps", 0.0)), 40.0)
			and is_equal_approx(float(lance.get("knock", 0.0)), 15.0) and is_equal_approx(float(gust.get("mps", 0.0)), 18.0)
			and is_equal_approx(float(gust.get("knock", 0.0)), 11.0) and NpcBending._as_of("air", "spear") == "air_spear"
			and NpcBending._as_of("air", "ball") == "",
			"a bot reads the grown Gust as the Air Lance (air, a spear, 40 m/s, knock 15) and the Gust as the Gust (%s; %s)" % [lance, gust])
	check(NpcBending.shot_of("fire_blast", "punch", true) == NpcBending.shot_of("fire_blast", "punch")
			and NpcBending.shot_of("earth_shove", "push", true) == NpcBending.shot_of("earth_shove", "push"),
			"every other grow is read as the move itself (the Fireball, the Fissure)")


# ---------------------------------------------------------------- the deck's stones
func _deck() -> void:
	var ring: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ring/ring.json"))
	var rh: Dictionary = (ring.get("sockets", {}) as Dictionary).get("hurl", {})
	var over: Array = []
	for k: String in ["stone", "spike", "cannonball"]:
		var dm: Array = (rh.get(k, {}) as Dictionary).get("damage", [999.0])
		if float(dm[dm.size() - 1]) > 40.0:
			over.append("%s %s" % [k, dm])
	check(rh.size() >= 3 and over.is_empty(), "a deck stone shoved or lifted: at most 40 a strike, each kind (%s)" % ", ".join(over))
	var boulder: Dictionary = (((SwayMoves.move("stone_form").get("throw", {}) as Dictionary).get("hurl", {}) as Dictionary).get("cannonball", {}))
	check((boulder.get("damage", []) as Array) == [80.0, 80.0], "a Stone Form boulder keeps its own (80)")
	var fns: Array = (RingArena as Script).get_script_method_list().map(func(m: Dictionary) -> String: return String(m.name))
	check("_ring_hurls" in fns, "the arena gives its deck stones' flights the ring's numbers (RingArena._ring_hurls)")
	var ps: Dictionary = NpcBending.ai().get("presets", {})
	var ok := true
	for p: String in ["easy", "normal", "hard"]:
		var pr: Dictionary = ps.get(p, {})
		ok = ok and float(pr.get("guard_reaction_s", 9.0)) <= float(pr.get("reaction_s", 0.0))
	check(ok, "each preset's guard reflex (guard_reaction_s) no slower than its reaction_s")
