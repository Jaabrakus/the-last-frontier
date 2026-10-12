extends SceneTree
## A worn Advancement loadout in a real match (BendLoadout; B1 and B2 of artifacts/ui_audit/advancement/plan.md section 7;
## docs/tidebreak/loadouts_live.md), headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_loadout_apply.gd
##   the switches    data/bending/loadout_apply.json: the live nodes and Boxing, the master switch and a node's own switch,
##                   the live list; Skate's Wet Trail refused (its puddles are made by nothing), Mud Lash (its Mud set is not
##                   live), a pick worn without the node it requires
##   the numbers     each live node's every change, read from data/sway/skill_tree.json, on its wearer exactly as the node says
##                   and on a body that wears nothing as today's data (spec, lock, Earth Wall and Ice Wall numbers, the % ring
##                   class of his hits: d, base, growth, angle, the tag kept, and one real hit's %); Classic reads
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
## live in loadout_apply.json (the two walls are switched off: the soak's bots never raise a wall; Full Sail since 2026-10-10: it
## widens the plain Gust now that the grown one is the Air Lance, not yet soaked; flip them in the json, not here).
## Since 2026-10-11 also fire's Storm twist Lightning Pistol (the owner's "have this or that": its own pose, a quicker charge and
## a longer flash), live on the owner's word for him to try, and the nine nodes the class numbers made whole (a change
## class:<tag>+<variant>.<key>: the % ring class of the wearer's own hits; the owner on the tree: "fix it"), live unsoaked,
## and the four binds the same day (a spec key Classic lacks, bind_s, from none; tests/ring/test_binds.gd plays them), with Wind
## Prison and Drenching Wave (prison_s, drench_s; tests/ring/test_knockups.gd plays them).
const CLASS_NODES := ["earth.fissure.deep", "water.spear.cold_hands", "water.spear.heavy", "water.downpour.pooling", "fire.punch.snap",
		"fire.lightning.short_fuse", "fire.embers.tight", "air.palm.shoving", "air.gust.rising"]
const BIND_NODES := ["earth.column.grip", "water.geyser.frost", "fire.lightning.shock", "air.pull.trip", "air.wall.prison",
		"water.wave.drench"]
## The tuning talents (2026-10-11): a guard rule, a passive, a % ring rule or Stone Form's own number per wearer (BendLoadout's tune
## part; tests/ring/test_talents_tune.gd plays them in a ring).
const TUNE_NODES := ["earth.catch.clean_return", "earth.catch.open_hands", "earth.spike.steady_point", "earth.spike.swift_lance",
		"earth.boulder.heavy", "earth.passive.deep_roots", "earth.passive.swift_roots", "water.turn.patient",
		"water.passive.lazy_river", "water.passive.rapids", "fire.parry.reaching", "air.passive.long_carry", "air.passive.gale_force"]
const LIVE := ["air.ball.dense", "air.gust.full_sail", "air.slice.keen", "earth.burrow.lie_low", "fire.step.quick",
		"earth.wall.thick", "water.wall.thick_ice", "fire.lightning.pistol"] + CLASS_NODES + BIND_NODES + TUNE_NODES
const ON_NOW := ["air.ball.dense", "air.slice.keen", "earth.burrow.lie_low", "fire.step.quick", "fire.lightning.pistol"] + CLASS_NODES \
		+ BIND_NODES + TUNE_NODES

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


## LIVE and the behaviour talents built since (loadout_apply.json `behaviour`, in the live list's order): a builder of a behaviour
## talent adds it to the json's live list (at its end), nodes and behaviour, and its own tests/ring/test_talents_<element>.gd plays it;
## this test then checks its numbers like any live node's.
func _live_all() -> Array:
	var out: Array = LIVE.duplicate()
	for v: Variant in (BendLoadout.config().get("live", []) as Array):
		if String(v) in BendLoadout.behaviour() and not String(v) in out:
			out.append(String(v))
	return out


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
		only_known = only_known and id0 in _live_all()
	_expect(every_on and only_known, "the nodes live now are the four the soak passed, the Lightning Pistol, the nine class nodes and the four binds, within the resolvable ones (%s)" % [live])
	_expect(not "earth.wall.thick" in live and not "water.wall.thick_ice" in live and BendLoadout.why_not("earth.wall.thick") == "switched off",
			"the two walls the soak could not exercise are switched off in the json (%s)" % BendLoadout.why_not("earth.wall.thick"))
	_expect("air.gust.full_sail" in live and BendLoadout.why_not("air.gust.full_sail") == "",
			"Full Sail is switched on (2026-10-11: its wide Gust, its lock and a hit only the wide one makes, tests/ring/test_talents_air.gd)")
	# the rest of this test wants every resolvable node on, whatever the switches say
	var all_on := {}
	for id1: String in _live_all():
		all_on[id1] = true
	_expect(not "water.skate.wet_trail" in live and not bool(BendLoadout.resolve("water.skate.wet_trail").ok)
			and String(BendLoadout.resolve("water.skate.wet_trail").why).contains("puddles"),
			"Skate's Wet Trail is refused: its puddles are in the data and nothing makes them (%s)" % BendLoadout.resolve("water.skate.wet_trail").why)
	_expect("earth.spike.steady_point" in live and BendLoadout.why_not("earth.spike.steady_point") == "",
			"Earth's Steady Point is live (2026-10-11: its release and sputter read per wearer, its own Spike lock)")
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
	_expect(BendLoadout.live_ids() == _live_all(), "every node's switch on: the %d resolvable ones" % _live_all().size())

	# ---------------------------------------------------------------- each live node's numbers, wearer and bot
	for id: String in _live_all():
		var n := _node(id)
		var el := id.get_slice(".", 0)
		var w := _body()
		var bot := _body()
		var ov := BendLoadout.wear(w, [id], "", el)
		_expect((ov.ids as Array) == [id] and BendLoadout.picks_of(w) == [id] and BendLoadout.overlay_of(bot).is_empty(), "%s: worn by one body, not the other" % id)
		for c: Dictionary in n.changes:
			var path := String(c.path)
			var rest := path.get_slice(":", 1)
			if path.begins_with("pose:"):
				# (a twist's own cast pose: the wearer's pick, the other's the element's own)
				var mvp := rest.get_slice("/", 0)
				var mdp := rest.substr(mvp.length() + 1)
				var wp := BendPoses.pick(mvp, mdp, el, w)
				_expect(String(wp.get("clip", "")) == String(c.to) and String(wp.get("from", "")) == "node"
						and String(BendPoses.pick(mvp, mdp, el, bot).get("clip", "")) == String(c.from),
						"%s: the wearer casts %s with %s, the other with %s" % [id, rest, c.to, c.from])
				continue
			if path == "new":
				continue                                 # (a behaviour talent's own code: its own test plays it, tests/ring/test_talents_<el>.gd)
			if path.begins_with("new:") or (path.begins_with("class:") and c.to is Dictionary and c.from == null):
				# (a behaviour talent's own number or whole new class: the wearer's, nothing for the other)
				var key_n := path.substr(6) if path.begins_with("class:") else path
				var got_n: Variant = BendLoadout.new_class(w, key_n) if path.begins_with("class:") else BendLoadout.tune(w, path, null)
				var none_n: Variant = BendLoadout.new_class(bot, key_n) if path.begins_with("class:") else BendLoadout.tune(bot, path, null)
				_expect(str(got_n) == str(c.to) and (none_n == null or (none_n is Dictionary and (none_n as Dictionary).is_empty())),
						"%s: %s is the wearer's (%s), nobody else's" % [id, path, str(c.to)])
				continue
			if path in BendLoadout.TUNE_PATHS:
				# (a guard rule, a passive, a % ring rule or a move's own number: the wearer's at its seam, the other's the game's)
				_expect(str(BendLoadout.tune(w, path, null)) == str(c.to) and str(BendLoadout.tune(bot, path, "classic")) == "classic"
						and str(BendLoadout.tune_base(path)) == str(c.from) or (_near(BendLoadout.tune(w, path, null), c.to)
						and _near(BendLoadout.tune_base(path), c.from) and str(BendLoadout.tune(bot, path, "classic")) == "classic"),
						"%s: %s is %s for the wearer, the game's %s for the other" % [id, path, str(c.to), str(c.from)])
				continue
			var to := float(c.to)
			var none := c.from == null                  # (a spec key Classic does not have: a bind's bind_s)
			var from := 0.0 if none else float(c.from)
			if path.begins_with("class:"):
				# (the % ring class of his hits with that tag: the node's number for the wearer, the data's for the other, and the
				# tag is the move's)
				var tag0 := rest.get_slice("+", 0)
				var key0 := rest.get_slice("+", 1).get_slice(".", 1)
				var base_c := RingRules.class_of(tag0)
				var gs := RingRules.stock_num("growth_scale", 1.0) if key0 == "growth" else 1.0
				var wc := BendLoadout.hit_class(w, base_c)
				var bc0 := BendLoadout.hit_class(bot, base_c)
				_expect(_near(wc.get(key0), to * gs) and String(wc.get("tag", "")) == tag0,
						"%s: the wearer's %s hits have %s %s, the tag kept (%s)" % [id, tag0, key0, to, wc.get(key0)])
				_expect(is_same(bc0, base_c) and _near(bc0.get(key0), from * gs),
						"%s: a body that wears nothing hits with the class as it is (%s %s)" % [id, key0, from])
				var named_keys := {}
				for c3: Dictionary in n.changes:
					if String(c3.path).begins_with("class:%s+" % tag0):
						named_keys[String(c3.path).get_slice("+", 1).get_slice(".", 1)] = true
				var others_same := true
				for k: String in base_c:
					if not named_keys.has(k) and wc.get(k) != base_c[k]:
						others_same = false
				_expect(others_same, "%s: %s changes no number of the %s class the node does not name" % [id, path, tag0])
				continue
			if path.begins_with("spec:"):
				var mv := rest.get_slice("/", 0)
				var keys: Array = Array(rest.substr(mv.length() + 1).split("."))
				var md := String(keys[0])
				var base: Dictionary = SwayMoves.move(mv).bend[md]
				var ws := BendLoadout.spec(w, mv, md, base)
				var bs := BendLoadout.spec(bot, mv, md, base)
				_expect(_near(_dig(ws, keys.slice(1)), to), "%s: the wearer's %s is %s" % [id, path, to])
				if none:
					_expect(_dig(bs, keys.slice(1)) == null and bs == base, "%s: a body that wears nothing has no %s" % [id, path])
				else:
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
	t["test.rule"] = {"id": "test.rule", "kind": "enhance", "ring_legal": true, "mode": "slice", "changes": [{"path": "rules:guard_rules.whiff_lock_s", "from": 0.5, "to": 0.6}]}
	t["test.clash"] = {"id": "test.clash", "kind": "enhance", "ring_legal": true, "mode": "slice", "changes": [{"path": "spec:air_blast/slice.mps", "from": 45.0, "to": 51.0}]}
	t["test.volley"] = {"id": "test.volley", "kind": "enhance", "ring_legal": true, "mode": "embers",
			"changes": [{"path": "class:fire_jab/embers+x.volley_n", "from": 7, "to": 6}]}
	t["test.newhit"] = {"id": "test.newhit", "kind": "enhance", "ring_legal": true, "mode": "whip",
			"changes": [{"path": "class:water_whip/whip+reel", "from": null, "to": {"d": 7.0, "base": 6.0, "growth": 0.0, "angle": 15}}]}
	t["test.what"] = {"id": "test.what", "kind": "enhance", "ring_legal": true, "mode": "whip",
			"changes": [{"path": "class:water_whip/whip+x.dir", "from": 1, "to": 2}]}
	t["test.cdrift"] = {"id": "test.cdrift", "kind": "enhance", "ring_legal": true, "mode": "whip",
			"changes": [{"path": "class:water_whip/whip+x.d", "from": 8.0, "to": 10.0}]}
	BendLoadout.config_override = {"live": ["test.unread", "test.drift", "test.nochange", "test.rule", "test.clash", "air.slice.keen",
			"test.volley", "test.newhit", "test.what", "test.cdrift"], "nodes": all_on}
	# (a volley's count without the node's own spec count; a whole new class, a hit the node adds; a key that says what the hit
	# is; a class number that drifted from the node's from)
	for id2: String in ["test.unread", "test.drift", "test.nochange", "test.rule", "test.volley", "test.newhit", "test.what", "test.cdrift"]:
		_expect(not bool(BendLoadout.resolve(id2).ok), "%s is refused (%s)" % [id2, BendLoadout.resolve(id2).why])
	var wx := _body()
	var ovx := BendLoadout.wear(wx, ["test.unread", "test.drift", "air.slice.keen", "test.clash"], "", "")
	_expect((ovx.ids as Array) == ["air.slice.keen"] and _near(BendLoadout.spec(wx, "air_blast", "slice", base_slice).mps, 54.0)
			and (ovx.refused as Dictionary).has("test.clash") and String(ovx.refused["test.clash"]).contains("mps"),
			"a refused node leaves no half of itself, and a number two nodes both set is set by the first only (%s)" % [ovx.refused])
	BendLoadout.config_override = {"nodes": all_on}
	BendLoadout.reload_data()
	# a node that requires one that is not live (Mud Lash: the Mud set makes mud, not numbers) is not live itself, and a pick worn
	# without the node it requires applies nothing
	BendLoadout.config_override = {"live": LIVE + ["water.mud.lash", "water.set.mud"], "nodes": all_on}
	_expect(bool(BendLoadout.resolve("water.mud.lash").ok) and not bool(BendLoadout.resolve("water.set.mud").ok)
			and BendLoadout.why_not("water.mud.lash").begins_with("needs water.set.mud"),
			"Mud Lash's numbers resolve, but it needs the Mud set, which is not live (%s)" % BendLoadout.why_not("water.mud.lash"))
	BendLoadout._node("air.slice.keen")
	t = BendLoadout._tree
	t["air.test_needs"] = {"id": "air.test_needs", "kind": "enhance", "ring_legal": true, "mode": "slice", "requires": ["air.ball.dense"],
			"changes": [{"path": "spec:air_blast/slice.range_m", "from": 35.0, "to": 36.0}]}
	BendLoadout.config_override = {"live": LIVE + ["air.test_needs"], "nodes": all_on}
	var nalone := BendLoadout.overlay_for(["air.test_needs"], "air")
	var nboth := BendLoadout.overlay_for(["air.test_needs", "air.ball.dense"], "air")
	_expect(BendLoadout.why_not("air.test_needs") == "" and (nalone.ids as Array).is_empty()
			and String((nalone.refused as Dictionary).get("air.test_needs", "")).contains("air.ball.dense") and (nboth.ids as Array).has("air.test_needs"),
			"a pick worn without the node it requires applies nothing; with it, it applies (%s, %s)" % [nalone.refused, nboth.ids])
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
			# (the element's end: its pick's own end_s when it is itself timed as another clip, the gun-style Embers)
			var e_end := float(e.get("end_s", ea.length))
			var ok_t := true
			for k: String in ["hold_s", "strike_s", "back_s"]:
				ok_t = ok_t and _near(sp.get(k), e.get(k))
			# (a root is true, false or "strike": held up to the strike only, fire's kicks since 2026-10-10)
			ok_t = ok_t and str(sp.get("root", false)) == str(e.get("root", false)) and _near(sp.get("end_s"), e_end)
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
			_expect(mono and has_pair and _near((wp[wp.size() - 1] as Array)[0], e_end) and _near((wp[wp.size() - 1] as Array)[1], sa.length),
					"%s: the clip's own hold %.3f s is on the element's %.3f s and its end on the element's end (%.3f s)" % [tag, own_h, float(e.hold_s), e_end])
			if e.has("alt") and sp.has("alt"):
				var ealt := BendPoses._filled(BendPoses._as_pose(e.alt), BendPoses.data())
				var salt := BendPoses._as_pose(sp.alt)
				var ok_a := not salt.is_empty() and String(salt.clip) != String(ealt.clip)
				for k: String in ["hold_s", "strike_s", "back_s"]:
					ok_a = ok_a and _near(salt.get(k), ealt.get(k))
				ok_a = ok_a and _near(salt.get("end_s"), float(ealt.get("end_s", BendPoses.animation(String(ealt.clip)).length)))
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
			and _near(sw._sample_t(float(jp.end_s)), sw._anim.length) and _near(sw._end(), float(ej.get("end_s", BendPoses.animation(String(ej.clip)).length))),
			"SwayPose: the Boxing jab's own wind-up, strike and recovery fall on the element's hold %.2f, strike %.2f and back %.2f s" % [float(ej.hold_s), float(ej.strike_s), float(ej.back_s)])
	# (an element pick of its own clip's timing: the jab's punch; Embers' gun clip is itself timed as the sweep it replaced, below)
	var ejab := BendPoses.pick("fire_jab", "jab", "fire")
	sw.pick = ejab
	sw._anim = BendPoses.animation(String(ejab.clip))
	_expect(not ejab.has("warp") and _near(sw._sample_t(0.37), 0.37) and _near(sw._end(), sw._anim.length), "SwayPose: an element's pick is sampled as it always was")
	# Embers' gun clip on the sweep's timeline (poses.json timed_as): the sweep's hold, strike, back and end; the gun's own
	# moments on them
	var sweep := BendPoses._filled({"clip": "own-bend-fire-sweep"}, BendPoses.data())
	sw.pick = ej
	sw._anim = BendPoses.animation(String(ej.clip))
	_expect(String(ej.clip) == "own-bend-fire-embers-gun" and _near(ej.hold_s, sweep.hold_s) and _near(ej.strike_s, sweep.strike_s)
			and _near(ej.back_s, sweep.back_s) and _near(ej.get("end_s"), BendPoses.animation("own-bend-fire-sweep").length)
			and _near(sw._sample_t(float(ej.strike_s)), float(sw._anim.get_meta(&"strike_s"))) and _near(sw._end(), BendPoses.animation("own-bend-fire-sweep").length),
			"SwayPose: Embers' gun clip strikes on the sweep's strike %.2f s and ends with it" % float(ej.get("strike_s", -1.0)))
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
			and String(BendPoses.pick("fire_jab", "embers", "fire", mode.foe).clip) == "own-bend-fire-embers-gun",
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
			if grown:
				# (grown, the Gust is the Air Lance since 2026-10-10: a spear thrown point first, Full Sail or not)
				_expect(g != null and g.kind == "air" and g.shape == "spear", "%s's grown Gust is the Air Lance, a spear (%s)" % [who[2],
						"%s %s" % [g.kind, g.shape] if g != null else "no bolt"])
			else:
				var want_w: float = 2.4 if worn else 2.0
				_expect(g != null and absf(g.radius - want_w * 0.5) < 0.001, "%s's Gust is %.1f m wide (%s)" % [who[2], want_w,
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
	# Fire: a real hit's % (RingRules.on_hit): Short Fuse's Lightning adds 22 for the 25 it was, its tag the move's
	var rules := RingRules.current()
	if rules != null and RingRules.stock_on():
		BendLoadout.wear(player, ["fire.lightning.short_fuse"], "", "fire")
		var keep_stale := rules.stale_off
		rules.stale_off = true
		var hw := rules.on_hit(bot, player, {"tag": "fire_arc/lightning", "at": bot.global_position + Vector3.UP})
		var hb := rules.on_hit(player, bot, {"tag": "fire_arc/lightning", "at": player.global_position + Vector3.UP})
		rules.stale_off = keep_stale
		_expect(float(hb.get("d", 0.0)) > 0.0 and absf(float(hw.get("d", 0.0)) / float(hb.get("d", 1.0)) - 22.0 / 25.0) < 0.001
				and String(hw.get("tag", "")) == "fire_arc/lightning",
				"a real hit: the wearer's Lightning adds %.2f %%, the bot's %.2f (22 for 25), the tag the move's (%s)" % [float(hw.get("d", 0.0)),
				float(hb.get("d", 0.0)), hw.get("tag", "-")])
		BendLoadout.clear(player)
	else:
		_expect(false, "the ring plays the % rules")
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
