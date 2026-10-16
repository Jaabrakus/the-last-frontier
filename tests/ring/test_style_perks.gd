extends SceneTree
## The fighting styles' perks in a real ring (the owner, 2026-10-16: "each fighting style should have different perks"): each live
## style's two + and two - levers (data/bending/fighting_styles.json; the design's six, docs/fighting_styles_design.md) on its
## wearer alone, read where the game reads the number for him, worn and not worn (BendLoadout, the section "a style's levers"):
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_style_perks.gd -- mode=ring practice=stand element=earth foe=earth
##   the levers      every live style's levers come through as the json has them (lever(body, k)); Classic, a bot and the
##                   style_levers switch off read 0
##   speed           the jab's, the guard's and the keys' first casts' locks x0.9 / x1.1 (SwayCaster._lock_time); a tap-twice cast
##                   (the Boulder, the Spear, the High Kick, the Ball) and a wall keep their own
##   power           the % ring class of a grown or tap-twice cast of key 1 or 2: base and growth x1.1 / x0.9, d and the angle kept
##                   (RingRules.on_hit through BendLoadout.hit_class); the jab's set knock and a returned stone's as they are
##   reach, width    the cast's spec (BendEffects.apply): range_m and mps x1.1 / x0.9, width_m and deg x1.1 / x0.9, the grow block
##                   too; a wall's spec untouched
##   mobility        the dash's lock and its fwd_mps every way (style_lock, style_spec), the fill on the move of a body move x1.1 /
##                   x0.9 never past 1 (SwayCaster._moving_mult); a heal's fill untouched
##   defence         the guard's perfect window 0.33 / 0.27 s (Classic 0.3): a real guard zone the player's cast made (BendZone)
##   the pick        AdvancementStore.pick_style sets Classic's class and the worn slot's (a kept slot refused), and the match start
##                   plays the pick with Classic worn (loadout_apply.json classic_style on): the player's body wears the style
##   Classic         a body with no style reads every number as the data has it; nothing worn leaves no trace in the shared data
## Last line "STYLE PERKS PASSED (n checks)" or "... FAILED"; exit 0 only on a pass.

const NAME := "STYLE PERKS TEST"
const LIMIT_S := 240.0
const OWN_STORE := "user://style_perks_test.json"
## The live styles and the element each plays as, with one quick cast, one tap-twice (big) cast and its guard of that element.
const STYLES := {
	"boxing": "fire", "taekwondo": "air", "muay_thai": "fire", "karate": "earth", "wing_chun": "water",
}
const QUICK := {"earth": ["stone_form", "spike"], "water": ["water_whip", "whip"], "fire": ["fire_blast", "punch"], "air": ["air_blast", "slice"]}
const BIG := {"earth": "stone_form/cannonball", "water": "ice/spear", "fire": "fire_kick/high_kick", "air": "air_blast/ball"}
const GROWN := {"earth": "earth_shove/push.grown", "water": "wave/push.grown", "fire": "fire_kick/kick.grown", "air": "air_gust/gust.grown"}
const PUSH := {"earth": ["earth_shove", "push"], "water": ["wave", "push"], "fire": ["fire_kick", "kick"], "air": ["air_gust", "gust"]}
const DASH := {"earth": ["earth_skate", "burrow"], "water": ["flow", "skate"], "fire": ["footwork", "step"], "air": ["evade", "slip"]}
const WALL := {"earth": ["earth_wall", "wall"], "water": ["water_shield", "ice_wall"], "fire": ["fire_wall", "wall"], "air": ["air_wall", "wall"]}

var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var pc: BendCaster
var sc: SwayCaster
var mode: RingMode
var _styles: Dictionary = {}


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _near(a: float, b: float, eps := 1e-4) -> bool:
	return absf(a - b) <= eps


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_STORE))
	AdvancementStore.path = OWN_STORE
	AdvancementStore.reload_file()
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	if player != null and is_instance_valid(player):
		BendLoadout.clear(player)
	BendLoadout.config_override = {}
	BendLoadout.read_store_in_scripts = false
	AdvancementStore.path = AdvancementStore.PATH
	AdvancementStore.reload_file()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_STORE))
	if fails.is_empty() and checks > 0:
		print("STYLE PERKS PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("STYLE PERKS FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	for i in 12:
		await process_frame
	var lvl := current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	_expect(player != null and mode != null, "a practice ring")
	if player == null or mode == null:
		return _end()
	await _ticks(240)
	pc = BendCaster.of(player)
	sc = SwayCaster.of(player)
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bending/fighting_styles.json"))
	_styles = (d as Dictionary).get("styles", {})
	var snap_moves := JSON.stringify(SwayMoves.data())
	_expect(bool(BendLoadout.config().get("style_levers", false)) and bool(BendLoadout.config().get("classic_style", false)),
			"loadout_apply.json: the levers and the Classic class are switched on")
	for st: String in STYLES:
		_expect(st in BendLoadout.live_styles(), "%s is live" % st)
	for st: String in STYLES:
		await _style(st, String(STYLES[st]))
	await _switch_off()
	await _pick()
	_expect(JSON.stringify(SwayMoves.data()) == snap_moves, "nothing worn left a trace in moves.json's data")
	_end()


## Style `st` worn by the player as an `el` caster, or nothing ("").
func _wear(st: String, el: String) -> void:
	Bending.of(player).element = el
	BendLoadout.clear(player)
	if st != "":
		BendLoadout.wear(player, [], st, el)
		_expect(BendLoadout.style_meta(player) == st and BendLoadout.lever_style(player) == st, "%s worn as %s" % [st, el])


func _sign(st: String, k: String) -> int:
	return int(((_styles.get(st, {}) as Dictionary).get("levers", {}) as Dictionary).get(k, 0))


## The newest guard zone the player's cast of `m` at `md` made.
func _zone_after(m: String, md: String) -> BendZone:
	var known := {}
	for z in get_nodes_in_group(BendZone.GROUP):
		known[z.get_instance_id()] = true
	BendEffects.apply(pc, m, md, (SwayMoves.move(m).bend as Dictionary)[md])
	await _ticks(2)
	for z in get_nodes_in_group(BendZone.GROUP):
		if not known.has(z.get_instance_id()) and z is BendZone:
			return z as BendZone
	var kinds: Array = []
	for z in get_nodes_in_group(BendZone.GROUP):
		kinds.append("%s(%s, %.2f)" % [(z as BendZone).kind, "his" if (z as BendZone).owner_node == player else "other", (z as BendZone).t])
	print("  (no new zone after %s/%s; standing: %s; the cast's record %s; caster valid %s)" % [m, md, kinds, BendEffects.last, pc != null and pc.valid()])
	return null


## The player's standing guard zones ended (a Wind Guard cast straight through BendEffects.apply is nobody's to let go) and his
## guard gauge full again (every guard raised drains it; empty, the next guard breaks at once: BendCombo.guard_tick).
func _end_guards() -> void:
	for z in get_nodes_in_group(BendZone.GROUP):
		if z is BendZone and (z as BendZone).owner_node == player:
			(z as BendZone).end()
	await _ticks(3)
	BendCombo.reset(player)


func _style(st: String, el: String) -> void:
	print("--- %s (%s)" % [st, el])
	var up := 1.0 + BendLoadout.LEVER_STEP
	var down := 1.0 - BendLoadout.LEVER_STEP
	# Classic first: the numbers as the data has them
	_wear("", el)
	_expect(BendLoadout.lever_style(player) == "" and BendLoadout.lever(player, "speed") == 0, "%s: no style, no lever" % el)
	var quick: Array = QUICK[el]
	var jab := Bending.jab(el)
	var guard := Bending.guard(el)
	var dash: Array = DASH[el]
	var push: Array = PUSH[el]
	var wall: Array = WALL[el]
	var lock0 := {}
	for pair: Array in [[String(jab.id), String(jab.mode)], quick, [String(guard.id), String(guard.mode)], dash, [wall[0], wall[1]],
			[quick[0], String(BIG[el]).get_slice("/", 1)]]:
		lock0["%s/%s" % pair] = sc._lock_time(String(pair[0]), null, 0.0, 0.0)
	var mv0 := {}
	for m: String in [String(jab.id), quick[0], push[0], dash[0], wall[0], "patch"]:
		mv0[m] = sc._moving_mult(m)
	await _end_guards()
	var g0 := await _zone_after(String(guard.id), String(guard.mode))
	var p0 := g0.perfect_s if g0 != null else -1.0       # (read now: the zone is ended before the style's own is raised)
	await _ticks(30)
	await _end_guards()
	var c0 := RingRules.class_of(String(BIG[el]))
	var cg0 := RingRules.class_of(String(GROWN[el]))
	var cj0 := RingRules.class_of("%s/%s" % [jab.id, jab.mode])
	_expect(BendLoadout.hit_class(player, c0) == c0 and BendLoadout.hit_class(player, cj0) == cj0, "%s: Classic's classes as they are" % el)
	var s0: Dictionary = (SwayMoves.move(push[0]).bend as Dictionary)[push[1]]
	_expect(BendLoadout.style_spec(player, push[0], push[1], s0) == s0, "%s: Classic's push spec as it is (the same dictionary)" % el)

	# the style worn: its four levers
	_wear(st, el)
	for k: String in BendLoadout.LEVERS:
		_expect(BendLoadout.lever(player, k) == _sign(st, k), "%s: lever %s %+d as the json" % [st, k, _sign(st, k)])
	var sp := 1.0 - BendLoadout.LEVER_STEP * _sign(st, "speed")
	var mb := 1.0 + BendLoadout.LEVER_STEP * _sign(st, "mobility")
	var pw := 1.0 + BendLoadout.LEVER_STEP * _sign(st, "power")
	var rc := 1.0 + BendLoadout.LEVER_STEP * _sign(st, "reach")
	var wd := 1.0 + BendLoadout.LEVER_STEP * _sign(st, "width")
	var df := BendLoadout.DEFENCE_STEP_S * _sign(st, "defence")
	# speed: the quick casts' locks; a tap-twice cast and a wall keep theirs
	for pair: Array in [[String(jab.id), String(jab.mode)], quick, [String(guard.id), String(guard.mode)]]:
		var key := "%s/%s" % pair
		var want := float(lock0[key]) * sp
		var got := sc._lock_time(String(pair[0]), null, 0.0, 0.0)
		_expect(_near(got, want), "%s: %s lock %.3f s (Classic %.3f, speed %+d)" % [st, key, got, float(lock0[key]), _sign(st, "speed")])
	var big_move := String(BIG[el]).get_slice("/", 0)
	var big_mode := String(BIG[el]).get_slice("/", 1)
	_expect(_near(BendLoadout.style_lock(player, big_move, big_mode, 1.0), 1.0) and _near(BendLoadout.style_lock(player, wall[0], wall[1], 1.0), 1.0),
			"%s: the tap-twice %s and the wall keep their own lock" % [st, BIG[el]])
	var wall_got := sc._lock_time(wall[0], null, 0.0, 0.0)
	_expect(_near(wall_got, float(lock0["%s/%s" % wall])), "%s: the wall's lock %.3f s as Classic's" % [st, wall_got])
	# mobility: the dash's lock and speed, the fill on the move of the body moves (never past 1); a heal's fill untouched
	var dash_key := "%s/%s" % dash
	var dash_got := sc._lock_time(dash[0], null, 0.0, 0.0)
	_expect(_near(dash_got, float(lock0[dash_key]) * (2.0 - mb)), "%s: the dash's lock %.3f s (Classic %.3f, mobility %+d)" % [st, dash_got,
			float(lock0[dash_key]), _sign(st, "mobility")])
	var ds: Dictionary = (SwayMoves.move(dash[0]).bend as Dictionary)[dash[1]]
	var ds1 := BendLoadout.style_spec(player, dash[0], dash[1], ds)
	var ways_ok := _near(float(ds1.get("fwd_mps", 0.0)), float(ds.get("fwd_mps", 0.0)) * mb)
	for way: String in ["fwd", "back", "side"]:
		if ds.get(way) is Dictionary:
			ways_ok = ways_ok and _near(float((ds1[way] as Dictionary).get("fwd_mps", 0.0)), float((ds[way] as Dictionary).get("fwd_mps", 0.0)) * mb)
	_expect(ways_ok and (_sign(st, "mobility") != 0 or ds1 == ds), "%s: the dash's fwd_mps %.2f every way (Classic %.2f)" % [st,
			float(ds1.get("fwd_mps", 0.0)), float(ds.get("fwd_mps", 0.0))])
	for m: String in [String(jab.id), quick[0], push[0], dash[0]]:
		var want := minf(float(mv0[m]) * mb, 1.0)
		var got := sc._moving_mult(m)
		_expect(_near(got, want), "%s: %s fills %.3f on the move (Classic %.3f)" % [st, m, got, float(mv0[m])])
	_expect(_near(sc._moving_mult(wall[0]), float(mv0[wall[0]])) and _near(sc._moving_mult("patch"), float(mv0["patch"])),
			"%s: the wall's and the heal's fill on the move as Classic's" % st)
	# power: the % ring class of a grown or tap-twice cast of key 1 or 2; the jab's and a return's as they are
	for pair: Array in [[String(BIG[el]), c0], [String(GROWN[el]), cg0]]:
		var c1 := BendLoadout.hit_class(player, pair[1] as Dictionary)
		var c: Dictionary = pair[1]
		_expect(_near(float(c1.get("base", 0.0)), float(c.get("base", 0.0)) * pw) and _near(float(c1.get("growth", 0.0)), float(c.get("growth", 0.0)) * pw)
				and _near(float(c1.get("d", 0.0)), float(c.get("d", 0.0))) and c1.get("angle") == c.get("angle") and String(c1.get("tag", "")) == String(pair[0]),
				"%s: %s knocks base %.2f growth %.2f (Classic %.2f, %.2f; power %+d), its %% and tag kept" % [st, pair[0], float(c1.get("base", 0.0)),
				float(c1.get("growth", 0.0)), float(c.get("base", 0.0)), float(c.get("growth", 0.0)), _sign(st, "power")])
	_expect(BendLoadout.hit_class(player, cj0) == cj0, "%s: the jab's set knock as it is" % st)
	var ret := RingRules.return_class(String(BIG[el]))
	_expect(BendLoadout.hit_class(player, ret) == ret, "%s: a returned stone's class as it is" % st)
	# reach and width: the push's spec and its grow block; the wall's spec untouched
	var s1 := BendLoadout.style_spec(player, push[0], push[1], s0)
	var ok_rw := true
	for k: String in BendLoadout.REACH_KEYS:
		if s0.has(k):
			ok_rw = ok_rw and _near(float(s1[k]), float(s0[k]) * rc)
	for k: String in BendLoadout.WIDTH_KEYS:
		if s0.has(k):
			ok_rw = ok_rw and _near(float(s1[k]), float(s0[k]) * wd)
	if s0.get("grow") is Dictionary:
		for k: String in BendLoadout.REACH_KEYS:
			if (s0.grow as Dictionary).has(k):
				ok_rw = ok_rw and _near(float((s1.grow as Dictionary)[k]), float((s0.grow as Dictionary)[k]) * rc)
		for k: String in BendLoadout.WIDTH_KEYS:
			if (s0.grow as Dictionary).has(k):
				ok_rw = ok_rw and _near(float((s1.grow as Dictionary)[k]), float((s0.grow as Dictionary)[k]) * wd)
	_expect(ok_rw and s1.size() == s0.size() and s0 == (SwayMoves.move(push[0]).bend as Dictionary)[push[1]],
			"%s: %s/%s range %.2f (Classic %.2f, reach %+d), width %.2f (Classic %.2f, width %+d); the data untouched" % [st, push[0], push[1],
			float(s1.get("range_m", 0.0)), float(s0.get("range_m", 0.0)), _sign(st, "reach"), float(s1.get("width_m", s1.get("deg", 0.0))),
			float(s0.get("width_m", s0.get("deg", 0.0))), _sign(st, "width")])
	var ws: Dictionary = (SwayMoves.move(wall[0]).bend as Dictionary).get(wall[1], {})
	_expect(BendLoadout.style_spec(player, wall[0], wall[1], ws) == ws, "%s: the wall's spec untouched" % st)
	# defence: a real guard zone's perfect window
	await _end_guards()
	var g1 := await _zone_after(String(guard.id), String(guard.mode))
	var p1 := g1.perfect_s if g1 != null else -1.0
	_expect(p0 >= 0.0 and p1 >= 0.0 and _near(p0, Bending.rule("perfect_s", 0.3)) and _near(p1, p0 + df),
			"%s: the guard's perfect %.2f s (Classic %.2f, defence %+d)" % [st, p1, p0, _sign(st, "defence")])
	await _end_guards()
	await _ticks(60)
	# a bot (the foe) reads nothing of it
	if mode.foe != null:
		_expect(BendLoadout.lever_style(mode.foe) == "" and BendLoadout.hit_class(mode.foe, c0) == c0, "%s: the bot plays no lever" % st)
	_wear("", el)


## The style_levers switch off: the clips still play, no lever does.
func _switch_off() -> void:
	_wear("karate", "earth")
	var push: Array = PUSH["earth"]
	var s0: Dictionary = (SwayMoves.move(push[0]).bend as Dictionary)[push[1]]
	BendLoadout.config_override = {"style_levers": false}
	_expect(BendLoadout.style_meta(player) == "karate" and BendPoses.style_of(player, "earth") == "karate" and BendLoadout.lever_style(player) == ""
			and BendLoadout.lever(player, "power") == 0 and BendLoadout.style_spec(player, push[0], push[1], s0) == s0
			and _near(BendLoadout.style_lock(player, "rock_jab", "pebbles", 1.0), 1.0),
			"style_levers off: Karate's clips play, no lever does")
	BendLoadout.config_override = {}
	_wear("", "earth")


## The pick in the menus (AdvancementStore.pick_style) and the match start reading it with Classic worn.
func _pick() -> void:
	AdvancementStore.reload_file()
	_expect(AdvancementStore.style_of("earth") == AdvancementData.canon_style("earth"), "a fresh save: earth's own style")
	_expect(AdvancementStore.pick_style("earth", "karate") == "" and AdvancementStore.style_of("earth") == "karate", "Karate picked for earth with Classic worn")
	_expect(AdvancementStore.pick_style("earth", "wrestling") != "" and AdvancementStore.style_of("earth") == "karate", "a parked style is refused, the pick kept")
	_expect(AdvancementStore.pick_style("earth", "boxing") != "" and AdvancementStore.style_of("earth") == "karate", "another element's style is refused")
	# a worn slot takes the pick too, a kept one refuses it
	var lo := AdvancementLoadout.new("earth", "hung_gar", [])
	_expect(AdvancementStore.save_slot("earth", 0, lo) == "" and AdvancementStore.wear("earth", 0), "a Hung Gar slot saved and worn")
	_expect(AdvancementStore.style_of("earth") == "hung_gar", "the worn slot's class is what plays")
	_expect(AdvancementStore.pick_style("earth", "karate") == "" and AdvancementStore.style_of("earth") == "karate"
			and AdvancementStore.slot("earth", 0).style == "karate", "the pick goes on the worn slot too")
	AdvancementStore.set_keep("earth", 0, true)
	_expect(AdvancementStore.pick_style("earth", "hung_gar") != "" and AdvancementStore.style_of("earth") == "karate", "a kept slot's padlock refuses the pick")
	AdvancementStore.set_keep("earth", 0, false)
	AdvancementStore.wear("earth", -1)
	# the match start: the pick plays with Classic worn (classic_style on), and its levers with it
	BendLoadout.read_store_in_scripts = true
	var w := BendLoadout.worn("earth")
	_expect((w.picks as Array).is_empty() and String(w.style) == "karate" and int(w.slot) == -1, "the match reads Karate for Classic: %s" % [w])
	MatchSetup.element = "earth"
	mode.restart()
	await _ticks(10)
	_expect(BendLoadout.style_meta(player) == "karate" and BendLoadout.overlay_of(player).is_empty() and BendLoadout.lever(player, "power") == 1
			and BendLoadout.lever(player, "mobility") == -1, "RingMode.restart put Karate and its levers on the player, no numbers else")
	_expect(mode.foe == null or BendLoadout.lever_style(mode.foe) == "", "the bot plays no style")
	BendLoadout.read_store_in_scripts = false
	BendLoadout.clear(player)
