extends SceneTree
## A worn Advancement loadout in a real match (BendLoadout; B1 and B2 of artifacts/ui_audit/advancement/plan.md section 7;
## docs/tidebreak/loadouts_live.md), headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_loadout_apply.gd
##   the switches    data/bending/loadout_apply.json: the seven live nodes and Boxing, the master switch and a node's own switch,
##                   the live list; Skate's Wet Trail refused (its puddles are made by nothing)
##   the numbers     each live node's every change, read from data/sway/skill_tree.json, on its wearer exactly as the node says
##                   and on a body that wears nothing as today's data (spec, lock, Earth Wall and Ice Wall numbers); Classic reads
##                   the same dictionaries it always did and no wear leaves a trace in the shared data (a snapshot of moves.json
##                   and poses.json is taken first and last); a node that changes a number nothing reads per wearer, or whose
##                   data drifted, is refused whole; a held, world-only, unknown or another element's id applies nothing
##   the styles      Boxing gives the wearer its clips and a bot (or the same fire body without the meta) the element's own;
##                   Capoeira (parked) and styles that are not animated never apply; every Boxing pick has the element's own
##                   hold_s, strike_s, back_s, root and end (a cast takes the Classic time) and a warp that puts the clip's own
##                   hold, strike and back on them; the Boxing library is loaded only when a style clip is first asked for
##   the match       (the ring scene) RingMode.restart reads the Advancement save: the worn slot's live nodes and class go on the
##                   player's body and on nobody else's; Classic (or a class picked with Classic worn) puts nothing on it; a
##                   script run ignores the save unless asked (so every other test plays Classic); the save file is never
##                   written; real casts (bolts, dashes, the walls, the locks) of the wearer and of a bot side by side
## Ends with "LOADOUT APPLY TEST PASSED (n checks)" or "... FAILED"; exit 0 only on a pass.

const NAME := "LOADOUT APPLY TEST"
const LIMIT_S := 300.0
const OWN_STORE := "user://loadout_apply_test.json"
const BOXING_LIB := "res://animations_extra/Frontier_Style_Boxing.res"
## The nodes whose numbers can be applied (resolve ok: the plan's eight less Skate's Wet Trail) and, of them, those the soak left
## live in loadout_apply.json (the two walls are switched off: the soak's bots never raise a wall; flip them in the json, not here).
const LIVE := ["air.ball.dense", "air.gust.full_sail", "air.slice.keen", "earth.burrow.lie_low", "fire.step.quick",
		"earth.wall.thick", "water.wall.thick_ice"]
const ON_NOW := ["air.ball.dense", "air.gust.full_sail", "air.slice.keen", "earth.burrow.lie_low", "fire.step.quick"]

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var _tree: Dictionary = {}


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_STORE))
	AdvancementStore.path = OWN_STORE
	AdvancementStore.reload_file()
	_run.call_deferred()


func _end() -> void:
	Engine.time_scale = 1.0
	BendLoadout.config_override = {}
	BendLoadout.read_store_in_scripts = false
	AdvancementStore.path = AdvancementStore.PATH
	AdvancementStore.reload_file()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_STORE))
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _body() -> Node3D:
	var n := Node3D.new()
	root.add_child(n)
	return n


## Every node of the skill tree by id (read here on its own, not through BendLoadout).
func _node(id: String) -> Dictionary:
	if _tree.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/sway/skill_tree.json"))
		_walk(d)
	return _tree.get(id, {})


func _walk(o: Variant) -> void:
	if o is Dictionary:
		if (o as Dictionary).get("id") is String and (o as Dictionary).get("kind") is String and (o as Dictionary).has("ring_legal"):
			_tree[String((o as Dictionary).id)] = o
		for k: Variant in (o as Dictionary):
			_walk((o as Dictionary)[k])
	elif o is Array:
		for v: Variant in (o as Array):
			_walk(v)


func _dig(d: Variant, keys: Array) -> Variant:
	var cur: Variant = d
	for k: Variant in keys:
		if not (cur is Dictionary) or not (cur as Dictionary).has(String(k)):
			return null
		cur = (cur as Dictionary)[String(k)]
	return cur


func _near(a: Variant, b: Variant) -> bool:
	return a != null and b != null and is_equal_approx(float(a), float(b))


func _run() -> void:
	# ---------------------------------------------------------------- before anything is worn: the library is not loaded
	var snap_moves := JSON.stringify(SwayMoves.data())
	var snap_poses := JSON.stringify(BendPoses.data())
	_expect(BendLoadout.enabled(), "the master switch is on in loadout_apply.json")
	var live := BendLoadout.live_ids()
	var every_on := true
	for id0: String in ON_NOW:
		every_on = every_on and id0 in live
	var only_known := true
	for id0: String in live:
		only_known = only_known and id0 in LIVE
	_expect(every_on and only_known, "the nodes live now are the five the soak passed, within the seven resolvable ones of the plan's eight (%s)" % [live])
	_expect(not "earth.wall.thick" in live and not "water.wall.thick_ice" in live and BendLoadout.why_not("earth.wall.thick") == "switched off",
			"the two walls the soak could not exercise are switched off in the json (%s)" % BendLoadout.why_not("earth.wall.thick"))
	# the rest of this test wants every resolvable node on, whatever the switches say
	var all_on := {}
	for id1: String in LIVE:
		all_on[id1] = true
	_expect(not "water.skate.wet_trail" in live and not bool(BendLoadout.resolve("water.skate.wet_trail").ok)
			and String(BendLoadout.resolve("water.skate.wet_trail").why).contains("puddles"),
			"Skate's Wet Trail is refused: its puddles are in the data and nothing makes them (%s)" % BendLoadout.resolve("water.skate.wet_trail").why)
	_expect(not "earth.spike.steady_point" in live and BendLoadout.why_not("earth.spike.steady_point") != "", "Earth's Steady Point is not in the set")
	_expect(BendLoadout.live_styles() == ["boxing"], "the live styles are Boxing only (%s)" % [BendLoadout.live_styles()])
	_expect(not BendPoses._libs.has(BOXING_LIB), "the Boxing library is not loaded before a style clip is asked for")

	# ---------------------------------------------------------------- the switches
	BendLoadout.config_override = {"enabled": false}
	_expect(BendLoadout.live_ids().is_empty() and BendLoadout.live_styles().is_empty() and not BendLoadout.style_ok("boxing", "fire"),
			"the master switch off: no node and no style is live")
	var b0 := _body()
	var ov0 := BendLoadout.wear(b0, ["air.slice.keen"], "boxing", "air")
	_expect((ov0.ids as Array).is_empty() and BendLoadout.overlay_of(b0).is_empty() and not b0.has_meta(BendLoadout.STYLE_META),
			"the master switch off: wearing applies nothing")
	BendLoadout.config_override = {"nodes": {"air.slice.keen": false}}
	_expect(not "air.slice.keen" in BendLoadout.live_ids() and BendLoadout.live_ids().size() == live.size() - 1,
			"a node's own switch off takes only that node out")
	_expect(BendLoadout.why_not("air.slice.keen") == "switched off", "...and says why (%s)" % BendLoadout.why_not("air.slice.keen"))
	BendLoadout.config_override = {"live": ["air.slice.keen"]}
	_expect(BendLoadout.live_ids() == ["air.slice.keen"], "the live list restricts which nodes may apply")
	BendLoadout.config_override = {"styles_live": []}
	_expect(BendLoadout.live_styles().is_empty() and not BendLoadout.style_ok("boxing", "fire"), "styles_live empty: no style plays")
	BendLoadout.config_override = {"nodes": all_on}
	_expect(BendLoadout.live_ids() == LIVE, "every node's switch on: the seven resolvable ones")

	# ---------------------------------------------------------------- each live node's numbers, wearer and bot
	for id: String in LIVE:
		var n := _node(id)
		var el := id.get_slice(".", 0)
		var w := _body()
		var bot := _body()
		var ov := BendLoadout.wear(w, [id], "", el)
		_expect((ov.ids as Array) == [id] and BendLoadout.picks_of(w) == [id] and BendLoadout.overlay_of(bot).is_empty(), "%s: worn by one body, not the other" % id)
		for c: Dictionary in n.changes:
			var path := String(c.path)
			var to := float(c.to)
			var from := float(c.from)
			var rest := path.get_slice(":", 1)
			if path.begins_with("spec:"):
				var mv := rest.get_slice("/", 0)
				var keys: Array = Array(rest.substr(mv.length() + 1).split("."))
				var md := String(keys[0])
				var base: Dictionary = SwayMoves.move(mv).bend[md]
				var ws := BendLoadout.spec(w, mv, md, base)
				var bs := BendLoadout.spec(bot, mv, md, base)
				_expect(_near(_dig(ws, keys.slice(1)), to), "%s: the wearer's %s is %s" % [id, path, to])
				_expect(_near(_dig(bs, keys.slice(1)), from) and bs == base, "%s: a body that wears nothing reads %s (%s)" % [id, path, from])
				# every key the node does not name is today's
				var named := {}
				for c2: Dictionary in n.changes:
					if String(c2.path).begins_with("spec:%s/%s." % [mv, md]):
						named[String(c2.path).get_slice(".", 1)] = true
				var rest_same := true
				for k: String in base:
					if not named.has(k) and ws.get(k) != base[k]:
						rest_same = false
				_expect(rest_same, "%s: %s changes no key of the spec the node does not name" % [id, path])
			elif rest.contains(".mode_lock_s."):
				var mv2 := rest.get_slice(".", 0)
				var md2 := rest.get_slice(".", 2)
				_expect(_near(BendLoadout.lock(w, mv2, md2, from), to) and _near(BendLoadout.lock(bot, mv2, md2, from), from),
						"%s: %s %s for the wearer, %s for the other" % [id, path, to, from])
			elif rest.ends_with(".lock_s"):
				var mv3 := rest.get_slice(".", 0)
				var md3 := String(n.mode)
				_expect(_near(BendLoadout.lock(w, mv3, md3, from), to) and _near(BendLoadout.lock(bot, mv3, md3, from), from),
						"%s: %s is the %s mode's alone" % [id, path, md3])
				_expect(_near(BendLoadout.lock(w, mv3, "hop", from), from), "%s: the move's other modes keep the move's lock" % id)
			elif rest.begins_with("earth_wall.wall."):
				var sub := Array(rest.split(".")).slice(2)
				var wd: Dictionary = SwayMoves.move("earth_wall").wall
				var kind := "wall" if el == "earth" else "ice"
				var mat := "earth" if el == "earth" else "snow"
				var ww := BendLoadout.wall_numbers(w, kind, wd, mat)
				var bw := BendLoadout.wall_numbers(bot, kind, wd, mat)
				var key := String(sub[sub.size() - 1])
				_expect(_near(ww.get(key), to), "%s: the wearer's %s is %s (%s)" % [id, path, to, ww.get(key)])
				_expect(_near(bw.get(key), from), "%s: a body that wears nothing reads %s (%s)" % [id, from, bw.get(key)])
				# the other builder does not see it (Earth Wall's numbers are not Ice Wall's)
				var other := BendLoadout.wall_numbers(w, "ice" if kind == "wall" else "wall", wd, mat)
				_expect(_near(other.get(key), from), "%s: the other wall builder reads %s as today (%s)" % [id, key, other.get(key)])
		BendLoadout.clear(w)
		_expect(BendLoadout.overlay_of(w).is_empty(), "%s: cleared, the body reads today's again" % id)

	# ---------------------------------------------------------------- Classic: the dictionaries it always read
	var cl := _body()
	var base_slice: Dictionary = SwayMoves.move("air_blast").bend.slice
	_expect(BendLoadout.spec(cl, "air_blast", "slice", base_slice) == base_slice, "Classic: the spec is the move's own dictionary")
	_expect(is_same(BendLoadout.spec(cl, "air_blast", "slice", base_slice), base_slice), "Classic: not even a copy")
	_expect(_near(BendLoadout.lock(cl, "air_blast", "ball", 0.75), 0.75), "Classic: the lock is the data's")
	var fm := preload("res://scripts/sway/form_matter.gd")
	var wd0: Dictionary = SwayMoves.move("earth_wall").wall
	for matter: String in ["earth", "stone", "snow", "mud", "wood"]:
		_expect(BendLoadout.wall_numbers(cl, "wall", wd0, matter) == fm.numbers(wd0, fm.entry("earth_wall", matter), matter)
				and BendLoadout.wall_numbers(cl, "ice", wd0, matter) == fm.numbers(wd0, fm.entry("earth_wall", matter), matter),
				"Classic: Earth Wall's and Ice Wall's numbers on %s are FormMatter's own" % matter)
	_expect(NpcBending.lock_for("air_blast", "ball", "hard", 0.0, cl) == NpcBending.lock_for("air_blast", "ball", "hard", 0.0)
			and NpcBending.lock_for("footwork", "step", "hard", 0.0, cl) == NpcBending.lock_for("footwork", "step", "hard", 0.0),
			"Classic: a bot's lock reads the data")
	# the thickness of a worn node does not leak into the others' reads, and the stone/mud walls keep their own strength
	var ww2 := _body()
	BendLoadout.wear(ww2, ["earth.wall.thick"], "", "earth")
	_expect(int(BendLoadout.wall_numbers(ww2, "wall", wd0, "earth").hits) == 5 and int(BendLoadout.wall_numbers(ww2, "wall", wd0, "stone").hits) == 7
			and int(BendLoadout.wall_numbers(ww2, "wall", wd0, "mud").hits) == 2 and _near(BendLoadout.wall_numbers(ww2, "wall", wd0, "stone").width_m, 2.5),
			"Thick Wall: 5 hits and 2.5 m on earth; stone and mud keep their own hits, the width is the wall's")
	var wi := _body()
	BendLoadout.wear(wi, ["water.wall.thick_ice"], "", "water")
	var iw := BendLoadout.wall_numbers(wi, "ice", wd0, "snow")
	_expect(int(iw.hits) == 4 and _near(iw.rise_s, 0.8) and _near(iw.width_m, 3.0), "Thick Ice: 4 hits, rises in 0.8 s, as wide as ever (%s, %s, %s)" % [iw.hits, iw.rise_s, iw.width_m])

	# ---------------------------------------------------------------- what applies nothing
	var bad := BendLoadout.overlay_for(["earth.shove.split", "earth.world.disc", "nope.nothing", "", "water.wall.thick_ice", "earth.wall.thick", "earth.wall.thick"], "earth")
	_expect((bad.ids as Array) == ["earth.wall.thick"], "held, world-only, unknown, empty, another element's and repeated ids apply nothing (%s)" % [bad.refused])
	var both := BendLoadout.overlay_for(["air.ball.dense", "air.slice.keen", "air.gust.full_sail"], "air")
	_expect((both.ids as Array).size() == 3 and (both.spec as Dictionary).size() == 3, "an element's live nodes together fold into one overlay")
	# a node that cannot be applied whole is refused whole
	BendLoadout.reload_data()
	BendLoadout._node("air.slice.keen")                       # (reads the tree)
	var t: Dictionary = BendLoadout._tree
	t["test.unread"] = {"id": "test.unread", "kind": "enhance", "ring_legal": true, "mode": "slice",
			"changes": [{"path": "spec:air_blast/slice.mps", "from": 45.0, "to": 50.0}, {"path": "move:earth_wall.wall.height_m", "from": 2.0, "to": 2.5}]}
	t["test.drift"] = {"id": "test.drift", "kind": "enhance", "ring_legal": true, "mode": "slice",
			"changes": [{"path": "spec:air_blast/slice.mps", "from": 40.0, "to": 50.0}]}
	t["test.nochange"] = {"id": "test.nochange", "kind": "enhance", "ring_legal": true, "mode": "slice", "changes": []}
	t["test.rule"] = {"id": "test.rule", "kind": "enhance", "ring_legal": true, "mode": "slice", "changes": [{"path": "rules:guard_rules.perfect_mult", "from": 1.2, "to": 1.3}]}
	t["test.clash"] = {"id": "test.clash", "kind": "enhance", "ring_legal": true, "mode": "slice", "changes": [{"path": "spec:air_blast/slice.mps", "from": 45.0, "to": 51.0}]}
	BendLoadout.config_override = {"live": ["test.unread", "test.drift", "test.nochange", "test.rule", "test.clash", "air.slice.keen"], "nodes": all_on}
	for id2: String in ["test.unread", "test.drift", "test.nochange", "test.rule"]:
		_expect(not bool(BendLoadout.resolve(id2).ok), "%s is refused (%s)" % [id2, BendLoadout.resolve(id2).why])
	var wx := _body()
	var ovx := BendLoadout.wear(wx, ["test.unread", "test.drift", "air.slice.keen", "test.clash"], "", "")
	_expect((ovx.ids as Array) == ["air.slice.keen"] and _near(BendLoadout.spec(wx, "air_blast", "slice", base_slice).mps, 54.0)
			and (ovx.refused as Dictionary).has("test.clash") and String(ovx.refused["test.clash"]).contains("mps"),
			"a refused node leaves no half of itself, and a number two nodes both set is set by the first only (%s)" % [ovx.refused])
	BendLoadout.config_override = {"nodes": all_on}
	BendLoadout.reload_data()

	# ---------------------------------------------------------------- the styles
	_expect(BendLoadout.style_ok("boxing", "fire") and not BendLoadout.style_ok("boxing", "earth") and not BendLoadout.style_ok("boxing", ""),
			"Boxing plays for fire only")
	BendLoadout.config_override = {"styles_live": ["boxing", "capoeira", "muay_thai", "hung_gar", "northern_shaolin"], "nodes": all_on}
	_expect(not BendLoadout.style_ok("capoeira", "air") and not BendLoadout.style_ok("muay_thai", "fire") and not BendLoadout.style_ok("hung_gar", "earth")
			and not BendLoadout.style_ok("northern_shaolin", "fire") and BendLoadout.live_styles() == ["boxing"],
			"Capoeira (parked), a style still coming and a canon style never play, even listed as live")
	var cap := _body()
	cap.set_meta(BendLoadout.STYLE_META, "capoeira")
	_expect(BendPoses.style_of(cap, "air") == "" and BendPoses.pick("air_gust", "gust", "air", cap) == BendPoses.pick("air_gust", "gust", "air"),
			"a body set to Capoeira by hand is picked from the element's own")
	BendLoadout.wear(cap, [], "capoeira", "air")
	_expect(not cap.has_meta(BendLoadout.STYLE_META), "wearing Capoeira sets no style")
	BendLoadout.config_override = {"nodes": all_on}

	var fighter := _body()
	var foe_bot := _body()
	BendLoadout.wear(fighter, [], "boxing", "fire")
	_expect(BendLoadout.style_meta(fighter) == "boxing" and BendPoses.style_of(fighter, "fire") == "boxing" and BendPoses.style_of(fighter, "earth") == ""
			and BendPoses.style_of(foe_bot, "fire") == "", "Boxing is the wearer's alone, and only as fire")
	var style_poses: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bending/style_poses.json")).styles.boxing
	var n_picks := 0
	var alts := 0
	var timing_bad: Array[String] = []
	for mv: String in style_poses.modes:
		for md: String in style_poses.modes[mv]:
			var want := BendPoses._as_pose(style_poses.modes[mv][md])
			var e := BendPoses.pick(mv, md, "fire")
			var sp := BendPoses.pick(mv, md, "fire", fighter)
			var bp := BendPoses.pick(mv, md, "fire", foe_bot)
			var tag := "%s/%s" % [mv, md]
			if e.is_empty():
				_expect(sp.is_empty(), "%s: the element has no pose for it, so the style has none" % tag)
				continue
			n_picks += 1
			_expect(String(sp.get("clip", "")) == String(want.clip) and String(sp.get("from", "")) == "style", "%s: Boxing's %s for the wearer" % [tag, want.clip])
			_expect(bp == e and String(bp.clip).begins_with("own-bend-") and String(e.clip) != String(sp.clip), "%s: the element's own %s for a bot" % [tag, e.clip])
			var ea := BendPoses.animation(String(e.clip))
			var ok_t := true
			for k: String in ["hold_s", "strike_s", "back_s"]:
				ok_t = ok_t and _near(sp.get(k), e.get(k))
			ok_t = ok_t and bool(sp.get("root", false)) == bool(e.get("root", false)) and _near(sp.get("end_s"), ea.length)
			if not ok_t:
				timing_bad.append(tag)
			var wp: Array = sp.get("warp", [])
			var mono := wp.size() >= 3 and _near((wp[0] as Array)[0], 0.0) and _near((wp[0] as Array)[1], 0.0)
			for i in range(1, wp.size()):
				mono = mono and float((wp[i] as Array)[0]) > float((wp[i - 1] as Array)[0]) and float((wp[i] as Array)[1]) >= float((wp[i - 1] as Array)[1])
			var sa := BendPoses.animation(String(sp.clip))
			var own_h := float(sa.get_meta(&"hold_s")) if not want.has("hold_s") else float(want.hold_s)
			var has_pair := false
			for pr: Array in wp:
				if _near(pr[0], e.hold_s) and _near(pr[1], own_h):
					has_pair = true
			_expect(mono and has_pair and _near((wp[wp.size() - 1] as Array)[0], ea.length) and _near((wp[wp.size() - 1] as Array)[1], sa.length),
					"%s: the clip's own hold %.3f s is on the element's %.3f s and its end on the element's end (%.3f s)" % [tag, own_h, float(e.hold_s), ea.length])
			if e.has("alt") and sp.has("alt"):
				var ealt := BendPoses._filled(BendPoses._as_pose(e.alt), BendPoses.data())
				var salt := BendPoses._as_pose(sp.alt)
				var ok_a := not salt.is_empty() and String(salt.clip) != String(ealt.clip)
				for k: String in ["hold_s", "strike_s", "back_s"]:
					ok_a = ok_a and _near(salt.get(k), ealt.get(k))
				ok_a = ok_a and _near(salt.get("end_s"), BendPoses.animation(String(ealt.clip)).length)
				_expect(ok_a, "%s: the other hand (%s) is timed as the element's %s" % [tag, salt.get("clip", "-"), ealt.clip])
				alts += 1
			elif sp.has("alt"):
				_expect(false, "%s: the style has an other hand where the element has none" % tag)
	_expect(n_picks >= 10 and alts >= 1, "%d Boxing picks (%d with the other hand) checked against the element's" % [n_picks, alts])
	_expect(timing_bad.is_empty(), "every Boxing pick has the element's hold, strike, back, root and end (%s)" % [timing_bad])
	_expect(BendPoses._libs.has(BOXING_LIB) and BendPoses._libs[BOXING_LIB] != null and BendPoses.library_of("own-style-boxing-jab") == BOXING_LIB,
			"the Boxing library loaded when its first clip was asked for")
	_expect(BendPoses.pick("fire_jab", "air_hit", "fire", fighter) == BendPoses.pick("fire_jab", "air_hit", "fire") and BendPoses.pick("fire_wall", "wall", "fire", fighter) == BendPoses.pick("fire_wall", "wall", "fire"),
			"a mode or a move the style leaves out is the element's own")
	_expect(String(BendPoses._as_pose(BendPoses.stance_pose("fire", fighter)).clip) == "own-style-boxing-stance"
			and String(BendPoses._as_pose(BendPoses.stance_pose("fire", foe_bot)).clip) == "own-bend-stance-fire"
			and String(BendPoses._as_pose(BendPoses.guard_hold_pose("fire", fighter)).clip) == "own-style-boxing-stance"
			and String(BendPoses._as_pose(BendPoses.guard_hold_pose("fire", foe_bot)).clip) == "own-bend-guard-hold-fire"
			and SwayPose.stance_name("fire", fighter) == "own-style-boxing-stance" and SwayPose.stance_name("fire") == "own-bend-stance-fire",
			"the stance and the held guard: Boxing's for the wearer, the element's for the rest")
	# SwayPose shows the clip on the element's timeline
	var sw := SwayPose.new()
	var jp := BendPoses.pick("fire_jab", "embers", "fire", fighter)
	sw.pick = jp
	sw._anim = BendPoses.animation(String(jp.clip))
	var ej := BendPoses.pick("fire_jab", "embers", "fire")
	_expect(_near(sw._sample_t(0.0), 0.0) and _near(sw._sample_t(float(ej.hold_s)), float(sw._anim.get_meta(&"hold_s")))
			and _near(sw._sample_t(float(ej.strike_s)), float(sw._anim.get_meta(&"strike_s"))) and _near(sw._sample_t(float(ej.back_s)), float(sw._anim.get_meta(&"back_s")))
			and _near(sw._sample_t(float(jp.end_s)), sw._anim.length) and _near(sw._end(), BendPoses.animation(String(ej.clip)).length),
			"SwayPose: the Boxing jab's own wind-up, strike and recovery fall on the element's hold %.2f, strike %.2f and back %.2f s" % [float(ej.hold_s), float(ej.strike_s), float(ej.back_s)])
	sw.pick = ej
	sw._anim = BendPoses.animation(String(ej.clip))
	_expect(_near(sw._sample_t(0.37), 0.37) and _near(sw._end(), sw._anim.length), "SwayPose: an element's pick is sampled as it always was")
	sw.free()

	# ---------------------------------------------------------------- the match: the ring scene
	var fixture_ok := _fixture()
	_expect(fixture_ok, "the test save: a fire slot with Boxing and Quick Step worn, an earth slot with Thick Wall")
	if not fixture_ok:
		return _end()
	var before := FileAccess.get_file_as_string(OWN_STORE)
	var mtime := FileAccess.get_modified_time(OWN_STORE)
	_expect(not BendLoadout.store_readable() and BendLoadout.worn("fire").picks.is_empty(),
			"a script run does not read the save unless asked (every other test plays Classic)")
	BendLoadout.read_store_in_scripts = true
	var wf := BendLoadout.worn("fire")
	_expect((wf.picks as Array) == ["fire.step.quick"] and String(wf.style) == "boxing" and int(wf.slot) == 0, "the worn slot is read: %s" % [wf])
	MatchSetup.incoming = true
	MatchSetup.element = "fire"
	MatchSetup.foes = ["fire"]
	MatchSetup.round_s = 60.0
	MatchSetup.rounds_to_win = 1
	MatchSetup.difficulty = "normal"
	InputSetup.ensure()
	SwayCaster.free_override = true
	change_scene_to_file("res://scenes/ring.tscn")
	for i in 20:
		await process_frame
	lvl = current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	_expect(mode != null and player != null and mode.foe != null, "the ring with a match and a bot")
	if mode == null or player == null or mode.foe == null:
		return _end()
	await _ticks(30)
	_expect(BendLoadout.picks_of(player) == ["fire.step.quick"] and BendLoadout.style_meta(player) == "boxing",
			"RingMode.restart put the worn slot's live node and class on the player (%s, %s)" % [BendLoadout.picks_of(player), BendLoadout.style_meta(player)])
	_expect(BendLoadout.overlay_of(mode.foe).is_empty() and BendLoadout.style_meta(mode.foe) == "" and BendPoses.style_of(mode.foe, "fire") == "",
			"the bot wears nothing and plays no style")
	_expect(String(BendPoses.pick("fire_jab", "embers", "fire", player).clip) == "own-style-boxing-jab"
			and String(BendPoses.pick("fire_jab", "embers", "fire", mode.foe).clip) == "own-bend-fire-sweep",
			"Boxing gives the player boxing clips and the fire bot the element's own")
	var sc := SwayCaster.of(player)
	await _ticks(150)
	_expect(sc != null and sc.pose != null and sc.pose.stance_clip() == &"own-style-boxing-stance" and sc.guard_hold_clip() == "own-style-boxing-stance",
			"the player's stance and held guard are Boxing's (%s, %s)" % [sc.pose.stance_clip() if sc != null and sc.pose != null else "-", sc.guard_hold_clip() if sc != null else "-"])
	# the locks, through the caster's own seam and the bot's
	if sc != null:
		sc.set_mode("footwork", "step")
		var step_lock := sc._lock_time("footwork", null, 0.0, 0.0)
		BendLoadout.clear_numbers(player)
		var classic_lock := sc._lock_time("footwork", null, 0.0, 0.0)
		BendLoadout.wear_player(player, "fire")
		_expect(classic_lock > 0.0 and absf(step_lock / classic_lock - 0.8) < 0.001, "the player's Step locks 0.16 s for the 0.20 it was (%.3f vs %.3f)" % [step_lock, classic_lock])
		_expect(BendLoadout.picks_of(player) == ["fire.step.quick"], "...and the overlay is back on the player")
	if sc != null:
		for rec: Array in [["air_blast", "ball", "air.ball.dense", 0.66 / 0.75], ["air_gust", "gust", "air.gust.full_sail", 0.5 / 0.45]]:
			sc.set_mode(String(rec[0]), String(rec[1]))
			BendLoadout.wear(player, [String(rec[2])], "", "air")
			var worn_lock := sc._lock_time(String(rec[0]), null, 0.0, 0.0)
			BendLoadout.clear_numbers(player)
			var plain_lock := sc._lock_time(String(rec[0]), null, 0.0, 0.0)
			_expect(plain_lock > 0.0 and absf(worn_lock / plain_lock - float(rec[3])) < 0.001, "the player's %s/%s lock with %s is %.3f of what it was (%.3f vs %.3f)" % [rec[0], rec[1], rec[2], float(rec[3]), worn_lock, plain_lock])
		BendLoadout.wear_player(player, "fire")
	_expect(NpcBending.lock_for("footwork", "step", "normal", 0.0, mode.foe) > 0.0
			and absf(NpcBending.lock_for("footwork", "step", "normal", 0.0, player) / NpcBending.lock_for("footwork", "step", "normal", 0.0, mode.foe) - 0.8) < 0.001,
			"a bot's lock for the same Step is 0.16 s for the wearer and 0.20 for the bot")

	# the bot's own begin: the lock it would take (NpcBending.lock_of), unworn, then wearing Dense Ball
	var bend: NpcBending = mode.foe.brain.bending if mode.foe.brain != null else null
	if bend != null:
		var opt := {"id": "air_blast", "mode": "ball", "key": "air_blast/ball"}
		var l0 := bend.lock_of(opt, player)
		BendLoadout.wear(mode.foe, ["air.ball.dense"], "", "air")
		var l1 := bend.lock_of(opt, player)
		BendLoadout.clear(mode.foe)
		var l2 := bend.lock_of(opt, player)
		_expect(l0 > 0.0 and absf(l1 / l0 - 0.88) < 0.001 and absf(l2 - l0) < 0.0001,
				"a bot wearing Dense Ball takes a 0.66 s Wind Ball lock for the 0.75 s (%.3f, %.3f, then %.3f again)" % [l1, l0, l2])
	else:
		_expect(false, "the foe has a bending mind")

	# real casts side by side: the wearer (the player) and the bot
	await _casts()

	# the save was only read
	_expect(FileAccess.get_file_as_string(OWN_STORE) == before and FileAccess.get_modified_time(OWN_STORE) == mtime,
			"the match never wrote the save")

	# Classic worn, with a class picked: nothing, unless the switch says
	AdvancementStore.wear("fire", -1)
	before = FileAccess.get_file_as_string(OWN_STORE)
	mtime = FileAccess.get_modified_time(OWN_STORE)
	mode.restart()
	await _ticks(10)
	_expect(BendLoadout.overlay_of(player).is_empty() and BendLoadout.style_meta(player) == "" and BendPoses.pick("fire_jab", "embers", "fire", player).get("from") != "style",
			"Classic worn: nothing on the player (the class picked with it is not played)")
	AdvancementStore.set_style("fire", "boxing")
	BendLoadout.config_override = {"classic_style": true, "nodes": all_on}
	mode.restart()
	await _ticks(10)
	_expect(BendLoadout.style_meta(player) == "boxing" and BendLoadout.overlay_of(player).is_empty(),
			"classic_style on: the class picked with Classic plays its clips and changes no number")
	BendLoadout.config_override = {"nodes": all_on}
	# another element's slot, a broken slot, the master switch
	AdvancementStore.wear("fire", 0)
	BendLoadout.config_override = {"enabled": false}
	mode.restart()
	await _ticks(10)
	_expect(BendLoadout.overlay_of(player).is_empty() and BendLoadout.style_meta(player) == "", "the master switch off: nothing on the player")
	BendLoadout.config_override = {"nodes": all_on}
	BendLoadout.read_store_in_scripts = false
	mode.restart()
	await _ticks(10)
	_expect(BendLoadout.overlay_of(player).is_empty() and BendLoadout.style_meta(player) == "", "a script run that does not ask: the worn slot is ignored")
	BendLoadout.read_store_in_scripts = true
	mode.restart()
	await _ticks(10)
	_expect(BendLoadout.picks_of(player) == ["fire.step.quick"] and BendLoadout.style_meta(player) == "boxing", "...and read again when asked")
	_expect(FileAccess.get_file_as_string(OWN_STORE).contains("\"worn\": 0") and not FileAccess.get_file_as_string(OWN_STORE).is_empty(), "the save holds what the test wrote")

	_raw_store_checks()

	# the world's SwayMoves and poses are as they were
	_expect(JSON.stringify(SwayMoves.data()) == snap_moves, "moves.json as the process read it: nothing worn left a trace")
	_expect(JSON.stringify(BendPoses.data()) == snap_poses, "poses.json as the process read it: nothing worn left a trace")
	_end()


## A save with ids the loadout may not wear (held, world-only, unknown, another element's, repeated) and a slot that breaks the
## rules: the store drops the first and reads the second as Classic, so nothing of them applies; reading writes nothing.
func _raw_store_checks() -> void:
	var raw := {"format": "tidebreak-advancement", "version": 1, "elements": {"fire": {"style": "boxing", "worn": 2, "slots": [{},
			{"name": "Bad", "style": "boxing", "nodes": ["fire.magma.fist"]},
			{"name": "Raw", "style": "boxing", "nodes": ["fire.step.quick", "fire.kick.twin", "fire.world.hover", "fire.nope", "air.slice.keen", "fire.step.quick"]}]}}, "world": {}}
	var f := FileAccess.open(OWN_STORE, FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	var before := FileAccess.get_file_as_string(OWN_STORE)
	AdvancementStore.reload_file()
	var w := BendLoadout.worn("fire")
	_expect((w.picks as Array) == ["fire.step.quick"] and String(w.style) == "boxing" and int(w.slot) == 2 and AdvancementStore.dropped.size() >= 4,
			"a saved slot with held, world-only, unknown, another element's and repeated ids: only the one live node is worn (%s; dropped %s)" % [w, AdvancementStore.dropped])
	var ov := BendLoadout.overlay_for(w.picks, "fire")
	_expect((ov.ids as Array) == ["fire.step.quick"], "...and it is the live Quick Step")
	AdvancementStore.element_doc("fire")["worn"] = 1           # (in memory: the store is not written)
	var w1 := BendLoadout.worn("fire")
	_expect((w1.picks as Array).is_empty() and String(w1.style) == "" and int(w1.slot) == -1, "a slot that breaks a rule is read as Classic: nothing worn (%s)" % [w1])
	_expect(FileAccess.get_file_as_string(OWN_STORE) == before, "reading the save wrote nothing")


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


## The test save (AdvancementStore on OWN_STORE): fire wears slot 0 (Boxing, Quick Step), earth has Thick Wall in slot 1 (not worn).
func _fixture() -> bool:
	var lo := AdvancementLoadout.new("fire", "boxing", ["fire.step.quick"])
	if lo.valid() != "":
		print("  (fixture: fire loadout invalid: %s)" % lo.valid())
		return false
	if AdvancementStore.save_slot("fire", 0, lo, "Test fire") != "":
		return false
	var le := AdvancementLoadout.new("earth", AdvancementData.canon_style("earth"), ["earth.wall.thick", "earth.world.disc", "earth.shove.split"])
	AdvancementStore.save_slot("earth", 1, AdvancementLoadout.new("earth", AdvancementData.canon_style("earth"), ["earth.wall.thick"]), "Test earth")
	AdvancementStore.wear("fire", 0)
	AdvancementStore.set_style("earth", AdvancementData.canon_style("earth"))
	return le != null and AdvancementStore.worn_index("fire") == 0


## Real casts of the wearer (the player) and the bot, side by side.
func _casts() -> void:
	var bot := mode.foe
	var pc := BendCaster.of(player)
	var bc := BendCaster.of(bot)
	_expect(pc != null and bc != null, "both have a caster")
	if pc == null or bc == null:
		return
	# Air: the Slice, the Ball and the grown Gust
	BendLoadout.wear(player, ["air.slice.keen", "air.ball.dense", "air.gust.full_sail"], "", "air")
	for who: Array in [[player, pc, "wearer"], [bot, bc, "bot"]]:
		var body: Node3D = who[0]
		var caster: BendCaster = who[1]
		var worn := String(who[2]) == "wearer"
		for rec: Array in [["air_blast", "slice", 54.0, 45.0, 0.10, 0.12], ["air_blast", "ball", 28.0, 28.0, 0.29, 0.35]]:
			var bolts_before := get_nodes_in_group(BendBolt.GROUP).size()
			BendEffects.apply(caster, String(rec[0]), String(rec[1]), SwayMoves.move(String(rec[0])).bend[String(rec[1])])
			var b := _newest_bolt(body)
			_expect(b != null and absf(b.velocity.length() - float(rec[2] if worn else rec[3])) < 0.01 and absf(b.radius - float(rec[4] if worn else rec[5])) < 0.001,
					"%s's %s flies %.0f m/s, %.2f m (%s)" % [who[2], rec[1], float(rec[2] if worn else rec[3]), float(rec[4] if worn else rec[5]),
					"%.1f, %.2f" % [b.velocity.length(), b.radius] if b != null else "no bolt"])
			_expect(b != null and absf(b.lock_s - SwayMoves.move("air_blast").mode_lock_s.get(rec[1], SwayMoves.move("air_blast").lock_s)) < 0.001,
					"%s's %s costs whom it hits the move's own lock (%.2f s), a talent never changes a blow's cost" % [who[2], rec[1],
					b.lock_s if b != null else -1.0])
			if b != null:
				b.queue_free()
			bolts_before += 0
		for grown: bool in [false, true]:
			caster.grown = grown
			BendEffects.apply(caster, "air_gust", "gust", SwayMoves.move("air_gust").bend.gust)
			var g := _newest_bolt(body)
			var want_w: float = 2.0 if not grown else (3.6 if worn else 3.0)
			_expect(g != null and absf(g.radius - want_w * 0.5) < 0.001, "%s's %s Gust is %.1f m wide (%s)" % [who[2], "grown" if grown else "plain", want_w,
					"%.2f" % (g.radius * 2.0) if g != null else "no bolt"])
			if g != null:
				g.queue_free()
		caster.grown = false
	BendLoadout.clear(player)
	# Earth: the Burrow, the Wall
	BendLoadout.wear(player, ["earth.burrow.lie_low", "earth.wall.thick"], "", "earth")
	for who: Array in [[player, pc, "wearer"], [bot, bc, "bot"]]:
		var body: Node3D = who[0]
		var worn := String(who[2]) == "wearer"
		BendEffects.apply(who[1], "earth_skate", "burrow", SwayMoves.move("earth_skate").bend.burrow)
		var v: Vector3 = BendEffects.last_of(who[1]).get("v", Vector3.ZERO)
		var under := BendStatus.until(body, &"bend_under_until")
		_expect(absf(Vector2(v.x, v.z).length() - (12.6 if worn else 14.0)) < 0.01, "%s's Burrow travels %.1f m/s (%.2f)" % [who[2], 12.6 if worn else 14.0, Vector2(v.x, v.z).length()])
		_expect(absf(under - (0.36 if worn else 0.3)) < 0.05, "%s's Burrow passes stones over for %.2f s (%.2f)" % [who[2], 0.36 if worn else 0.3, under])
		var at := body.global_position + Vector3(0, 0, 4.0)
		var wall := FormEffects.earth_wall(who[1], at, SwayMoves.move("earth_wall"), "earth")
		_expect(wall != null and wall.hits_max == (5 if worn else 4) and absf(wall.size.x - (2.5 if worn else 3.0)) < 0.001,
				"%s's Earth Wall takes %d hits and is %.1f m wide (%s)" % [who[2], 5 if worn else 4, 2.5 if worn else 3.0,
				"%d, %.1f" % [wall.hits_max, wall.size.x] if wall != null else "no wall"])
		if wall != null:
			wall.queue_free()
	BendLoadout.clear(player)
	# Water: the Ice Wall
	BendLoadout.wear(player, ["water.wall.thick_ice"], "", "water")
	for who: Array in [[player, pc, "wearer"], [bot, bc, "bot"]]:
		var body: Node3D = who[0]
		var worn := String(who[2]) == "wearer"
		var ice := BendEffects._wall(body, Transform3D(Basis.IDENTITY, body.global_position + Vector3(0, 0, 5.0)), "snow", -1.0, -1.0, true)
		_expect(ice != null and ice.hits_max == (4 if worn else 3) and absf(ice.rise_s - (0.8 if worn else 0.7)) < 0.001,
				"%s's Ice Wall takes %d hits and rises in %.1f s (%s)" % [who[2], 4 if worn else 3, 0.8 if worn else 0.7,
				"%d, %.1f" % [ice.hits_max, ice.rise_s] if ice != null else "no wall"])
		if ice != null:
			ice.queue_free()
		var shell_like := BendEffects._wall(body, Transform3D(Basis.IDENTITY, body.global_position + Vector3(0, 0, 6.0)), "snow", 3.0, 2.9)
		_expect(shell_like != null and shell_like.hits_max == 3 and absf(shell_like.rise_s - 0.7) < 0.001, "%s's other snow walls (shell, ramp) keep the move's numbers" % who[2])
		if shell_like != null:
			shell_like.queue_free()
	BendLoadout.clear(player)
	# Fire: the Step
	BendLoadout.wear(player, ["fire.step.quick"], "", "fire")
	for who: Array in [[player, pc, "wearer"], [bot, bc, "bot"]]:
		var worn := String(who[2]) == "wearer"
		BendEffects.apply(who[1], "footwork", "step", SwayMoves.move("footwork").bend.step)
		var v2: Vector3 = BendEffects.last_of(who[1]).get("v", Vector3.ZERO)
		_expect(absf(Vector2(v2.x, v2.z).length() - (8.1 if worn else 9.0)) < 0.01, "%s's Step carries %.1f m/s (%.2f)" % [who[2], 8.1 if worn else 9.0, Vector2(v2.x, v2.z).length()])
	# the wearer's profile back to what the match set
	BendLoadout.wear_player(player, "fire")


## The newest BendBolt of `body` in the scene (null none).
func _newest_bolt(body: Node) -> BendBolt:
	var found: BendBolt = null
	for n in get_nodes_in_group(BendBolt.GROUP):
		var b := n as BendBolt
		if b != null and is_instance_valid(b) and b.caster == body and not b.is_queued_for_deletion():
			found = b
	return found
