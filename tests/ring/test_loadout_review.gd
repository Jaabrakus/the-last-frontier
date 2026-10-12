extends SceneTree
## The independent review of the live loadouts (docs/tidebreak/loadouts_live.md "Independent review"; BendLoadout), headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_loadout_review.gd
## Each part pins one claim of the builder against something that does not come from BendLoadout:
##   1 CLASSIC    Classic's fingerprint (tools/ring/loadout_classic_print.gd: every move's player and bot locks, ranges, a hit's lock
##                cost, every element's cast pose, the cast timeline frame by frame at three lock lengths and the other hand, real
##                casts' speed, size, damage, knock and lift, the dashes, the walls) equals tests/ring/fixtures/
##                loadout_classic_golden.json, taken from the code BEFORE the loadouts (c0a631a0^) by
##                tools/ring/loadout_classic_print_run.gd (taken again 2026-10-10 when Classic itself changed, nothing worn: earth's 2
##                the Fissure, the Gust grown the Air Lance and its spear throw, fire's kicks free after the strike; every other
##                entry equal; and 2026-10-11 the High Kick's and the air kick's lock 0.55 s, the owner's "fast": their locks only; and 2026-10-12 the Boulder's lock 0.8 s (the owner's "faster") and the Ice Spear on the pistol's aim, frontier-pistol-ice (its clip only, every frame the same): ten entries): with the file as shipped, with the master switch off, with every node on and
##                nothing worn, and in the next match after one played wearing a loadout
##   2 WEARER     a worn node changes its wearer only: the bot's casts and locks are Classic's while the player wears every node of
##                an element, the player's are Classic's while the bot wears them, and the next match without the loadout is
##                Classic for both (a new bot too)
##   3 BOXING     every Boxing pick, at three lock lengths and with the other hand, strikes, ends, roots and waits on Classic's
##                frames; on the strike frame the Boxing clip shows its own strike; Quick Step worn with it changes no pose time;
##                a bot given Boxing plays the element's own clips and times
##   4 THE SAVE   user://advancement.json damaged in every way a hand or a crash can (missing, empty, garbage, wrong types, an old
##                or unknown format, a removed node id) reads as Classic or as the slot's valid part, never stops the read with a
##                script error, and is never written by a read; the test's own file only (the player's save is not touched)
##   5 SWITCHES   each switch of data/bending/loadout_apply.json (enabled, nodes.<id>, live, styles_live, classic_style) gates the
##                match through RingMode.restart; the window's green dots (AdvancementData.is_live/_style) agree with BendLoadout
##   6 HOT PATHS  a body that wears nothing reads through without a new dictionary; a styled body's per-frame style check is a
##                lookup (BendLoadout.style_ok memo)
## Ends with "LOADOUT REVIEW TEST PASSED (n checks)" or "... FAILED"; exit 0 only on a pass.

const NAME := "LOADOUT REVIEW TEST"
const LIMIT_S := 600.0
const OWN_STORE := "user://loadout_review_test.json"
const GOLDEN := "res://tests/ring/fixtures/loadout_classic_golden.json"
const PRINT := preload("res://tools/ring/loadout_classic_print.gd")
const DT := 1.0 / 60.0
## The live nodes by element, and the move/mode keys of the fingerprint's casts they touch.
const BY_EL := {
	"air": [["air.ball.dense", "air.gust.full_sail", "air.slice.keen"], ["air_blast/slice", "air_blast/ball", "air_gust/gust"]],
	"earth": [["earth.burrow.lie_low", "earth.wall.thick"], ["earth_skate/burrow", "earth_wall/wall"]],
	"fire": [["fire.step.quick"], ["footwork/step"]],
	"water": [["water.wall.thick_ice"], ["ice_wall"]],
}

var checks := 0
var fails: Array[String] = []
var golden: Dictionary = {}
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var fp: Variant
var all_on := {}
var _player_save_mtime := -1


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
	var real := ProjectSettings.globalize_path(AdvancementStore.PATH)
	_player_save_mtime = FileAccess.get_modified_time(AdvancementStore.PATH) if FileAccess.file_exists(AdvancementStore.PATH) else -1
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_STORE))
	AdvancementStore.path = OWN_STORE
	AdvancementStore.reload_file()
	_expect(ProjectSettings.globalize_path(AdvancementStore.file()) != real, "the test reads and writes its own file, never the player's save")
	var g: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	golden = g if g is Dictionary else {}
	for id: String in BendLoadout.config().get("live", []):
		all_on[id] = true
	_run.call_deferred()


func _end() -> void:
	Engine.time_scale = 1.0
	BendLoadout.config_override = {}
	BendLoadout.read_store_in_scripts = false
	AdvancementStore.path = AdvancementStore.PATH
	AdvancementStore.reload_file()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_STORE))
	var now_mtime := FileAccess.get_modified_time(AdvancementStore.PATH) if FileAccess.file_exists(AdvancementStore.PATH) else -1
	_expect(now_mtime == _player_save_mtime, "the player's own save (user://advancement.json) was not touched (%d, %d)" % [_player_save_mtime, now_mtime])
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


## The keys of `a` and `b` (a section of the fingerprint) whose values differ, at most `n`.
func _diff(a0: Dictionary, b0: Dictionary, n := 6) -> Array:
	var out: Array = []
	var a: Dictionary = JSON.parse_string(JSON.stringify(a0))          # (as the golden was read: every number a float)
	var b: Dictionary = JSON.parse_string(JSON.stringify(b0))
	for k: String in a:
		if not b.has(k) or JSON.stringify(a[k], "", true) != JSON.stringify(b[k], "", true):
			out.append("%s: %s vs %s" % [k, JSON.stringify(a.get(k)), JSON.stringify(b.get(k))])
			if out.size() >= n:
				return out
	for k: String in b:
		if not a.has(k):
			out.append("%s: missing" % k)
			if out.size() >= n:
				return out
	return out


func _same_print(d: Dictionary, what: String) -> void:
	for sec: String in ["locks", "picks", "timeline", "effects"]:
		var df := _diff(d.get(sec, {}), golden.get(sec, {}))
		_expect(not (d.get(sec, {}) as Dictionary).is_empty() and df.is_empty(), "%s: Classic's %s equal the code before the loadouts (%d entries) %s"
				% [what, sec, (golden.get(sec, {}) as Dictionary).size(), "" if df.is_empty() else str(df)])


func _hold_foe() -> void:
	if mode.foe != null and is_instance_valid(mode.foe):
		mode.foe.held = true
		mode.foe.global_position = Vector3(0.0, 60.0, -400.0)
		mode.foe.velocity = Vector3.ZERO


func _restart() -> void:
	mode.restart()
	for i in 4:
		await physics_frame
	_hold_foe()
	await physics_frame


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	_expect(golden.has("locks") and golden.has("timeline"), "the golden fingerprint of the code before the loadouts is read")
	_save_checks()
	_switch_agreement()

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
	_hold_foe()
	await physics_frame
	fp = PRINT.new()

	# ---------------------------------------------------------------- 1 CLASSIC
	_same_print(await fp.collect(self, player), "as shipped, nothing worn")
	BendLoadout.config_override = {"enabled": false}
	_same_print(await fp.collect(self, player), "the master switch off")
	BendLoadout.config_override = {"nodes": all_on, "classic_style": true}
	_same_print(await fp.collect(self, player), "every node and Boxing switched on, nothing worn")
	BendLoadout.config_override = {"nodes": all_on}

	# ---------------------------------------------------------------- 2 WEARER
	await _wearer_checks()

	# ---------------------------------------------------------------- 3 BOXING
	await _boxing_checks()
	await _launch_checks()

	# ---------------------------------------------------------------- 5 SWITCHES (through the match start) and the next match
	await _switch_checks()

	# ---------------------------------------------------------------- 6 HOT PATHS
	_hot_checks()
	_end()


# ---------------------------------------------------------------- 2 WEARER
func _bot_locks(who: Node) -> Dictionary:
	var out := {}
	for key: String in golden.locks:
		var m := key.get_slice("/", 0)
		var md := key.get_slice("/", 1)
		var nr := NpcBending.range_of(m, md)
		var nl: Array = []
		for pr: String in ["easy", "normal", "hard"]:
			nl.append(snappedf(NpcBending.lock_for(m, md, pr, 0.0, who), 0.0001))
			nl.append(snappedf(NpcBending.lock_for(m, md, pr, nr, who), 0.0001))
		out[key] = nl
	return out


func _player_locks() -> Dictionary:
	var sc := SwayCaster.of(player)
	for i in 60:                                # (on the deck: an airborne caster reads the air locks)
		if player.is_on_floor() and not sc.airborne():
			break
		await physics_frame
	var out := {}
	for key: String in golden.locks:
		var m := key.get_slice("/", 0)
		var md := key.get_slice("/", 1)
		sc._pin_id = m
		sc._pin_mode = md
		sc._pinning = true
		var r := sc.range_of(m, null)
		out[key] = [snappedf(sc._lock_time(m, null, 0.0, r), 0.0001), snappedf(sc._lock_time(m, null, r * 0.75, r), 0.0001),
				snappedf(sc._lock_time(m, null, r, r), 0.0001)]
		sc._pinning = false
		sc._pin_id = ""
		sc._pin_mode = ""
	return out


func _golden_part(sec: String, field: String) -> Dictionary:
	var out := {}
	for k: String in golden[sec]:
		out[k] = golden[sec][k][field] if field != "" else golden[sec][k]
	return out


## The golden effects whose key is one of `keys` (or starts with one, then " held" / "+grown"), or is a wall of them.
func _golden_effects(keys: Array, bot := false) -> Dictionary:
	var out := {}
	for k: String in golden.effects:
		for want: String in keys:
			var hit := k == want or k.begins_with(want + "+") or k.begins_with(want + " held")
			if want == "earth_wall/wall" and k.begins_with("earth_wall/"):
				hit = true
			if bot and k.contains(" held"):
				hit = false
			if hit:
				out[k] = golden.effects[k]
	return out


func _wearer_checks() -> void:
	var foe := mode.foe
	var g_npc := _golden_part("locks", "npc")
	var g_player := _golden_part("locks", "player")
	for el: String in BY_EL:
		var ids: Array = BY_EL[el][0]
		var keys: Array = BY_EL[el][1]
		# the player wears every node of the element; the bot is Classic
		BendLoadout.wear(player, ids, "boxing" if el == "fire" else "", el)
		_expect(BendLoadout.picks_of(player).size() == ids.size(), "%s: the player wears %s" % [el, ids])
		var bot_fx: Dictionary = _known(await fp.effects_for(self, foe, keys))
		var df := _diff(bot_fx, _golden_effects(keys, true))
		_expect((not bot_fx.is_empty() or el == "fire") and df.is_empty(), "%s: the bot's own casts are Classic's while the player wears the nodes (%d casts) %s" % [el, bot_fx.size(), df])
		if el == "fire":
			var how_v := _bot_step(foe)
			_expect(is_equal_approx(float(how_v[1]), float({"fwd": 10.0, "back": 9.0, "side": 7.0}.get(String(how_v[0]), 9.0))),
					"fire: the bot's own Step is Classic's while the player wears Quick Step (%s %.2f m/s)" % how_v)
		var dl := _diff(_bot_locks(foe), g_npc)
		_expect(dl.is_empty(), "%s: every lock of the bot is Classic's while the player wears the nodes %s" % [el, dl])
		var pl_fx: Dictionary = await fp.effects_for(self, player, keys)
		var changed := _diff(pl_fx, _golden_effects(keys), 20)
		_expect(not changed.is_empty(), "%s: ...and the wearer's own casts do change (%d)" % [el, changed.size()])
		_expect(BendLoadout.overlay_of(foe).is_empty() and BendLoadout.style_meta(foe) == "", "%s: nothing was put on the bot" % el)
		BendLoadout.clear(player)
		# the bot wears them (and Boxing); the player is Classic
		BendLoadout.wear(foe, ids, "boxing" if el == "fire" else "", el)
		var p_fx: Dictionary = await fp.effects_for(self, player, keys)
		var dp := _diff(p_fx, _golden_effects(keys))
		_expect(not p_fx.is_empty() and dp.is_empty(), "%s: the player's casts are Classic's while the bot wears the nodes (%d casts) %s" % [el, p_fx.size(), dp])
		var dpl := _diff(await _player_locks(), g_player)
		_expect(dpl.is_empty(), "%s: every lock of the player is Classic's while the bot wears the nodes %s" % [el, dpl])
		var b_fx: Dictionary = _known(await fp.effects_for(self, foe, keys))
		if el == "fire":
			var hv2 := _bot_step(foe)
			_expect(is_equal_approx(float(hv2[1]), float({"fwd": 9.0, "back": 8.1, "side": 6.3}.get(String(hv2[0]), 9.0))),
					"fire: ...and the bot's own Step is Quick Step's when it wears it (%s %.2f m/s)" % hv2)
		else:
			_expect(not _diff(b_fx, _golden_effects(keys, true), 20).is_empty(), "%s: ...and the bot's own casts do change when it wears them" % el)
		BendLoadout.clear(foe)
		_hold_foe()
	# the bot's Step (its own way, not the player's keys): the Quick Step on it, then not
	BendLoadout.wear(foe, ["fire.step.quick"], "", "fire")
	var ls_w := NpcBending.lock_for("footwork", "step", "normal", 0.0, foe)
	BendLoadout.clear(foe)
	var ls_c := NpcBending.lock_for("footwork", "step", "normal", 0.0, foe)
	_expect(absf(ls_w / ls_c - 0.8) < 0.001 and is_equal_approx(ls_c, float(g_npc["footwork/step"][2])), "fire: the bot's Step lock is 0.8 of Classic's worn, Classic's after (%.3f, %.3f)" % [ls_w, ls_c])


## The fingerprint's casts that have a Classic key (a bot's Step goes its own way: no held keys).
func _known(fx: Dictionary) -> Dictionary:
	var out := {}
	for k: String in fx:
		if (golden.effects as Dictionary).has(k):
			out[k] = fx[k]
	return out


## The bot casts its Step: [the way it went, its flat speed].
func _bot_step(foe: NpcFighter) -> Array:
	var bc := BendCaster.of(foe)
	Bending.of(foe).element = "fire"
	foe.velocity = Vector3.ZERO
	BendEffects.apply(bc, "footwork", "step", SwayMoves.move("footwork").bend.step)
	var rec := BendEffects.last_of(bc)
	var v: Vector3 = rec.get("v", Vector3.ZERO)
	_hold_foe()
	return [String(rec.get("how", "")), Vector2(v.x, v.z).length()]


# ---------------------------------------------------------------- 3 BOXING
func _boxing_checks() -> void:
	var sty: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/bending/style_poses.json")) as Dictionary).styles.boxing
	var keep_el := BendPoses.element_of(player)
	Bending.of(player).element = "fire"
	var n := 0
	var bad: Array = []
	var off_strike: Array = []
	for m: String in sty.modes:
		for md: String in sty.modes[m]:
			var ep := BendPoses.pick(m, md, "fire")
			if ep.is_empty():
				continue
			var hold := float(ep.get("hold_s", 0.3))
			var runs: Array = [[0.03, 0], [hold + 0.15, 0], [hold + 0.7, 0]]
			if ep.has("alt"):
				runs.append([hold + 0.15, 1])
			for r: Array in runs:
				BendLoadout.clear(player)
				var c: Dictionary = fp._drive(m, md, float(r[0]), int(r[1]))
				var gk := "fire:%s/%s@%s" % [m, md, "alt" if int(r[1]) == 1 else "%.3f" % float(r[0])]
				if (golden.timeline as Dictionary).has(gk) and not _diff({gk: golden.timeline[gk]}, {gk: c}).is_empty():
					bad.append("%s Classic drifted from the golden: %s vs %s" % [gk, c, golden.timeline[gk]])
				BendLoadout.wear(player, ["fire.step.quick"], "boxing", "fire")
				var b: Dictionary = fp._drive(m, md, float(r[0]), int(r[1]), true)
				n += 1
				if not String(b.clip).begins_with("own-style-boxing-"):
					bad.append("%s plays %s" % [gk, b.clip])
				for k: String in ["struck", "end", "root", "wait"]:
					if JSON.stringify(b[k]) != JSON.stringify(c[k]):
						bad.append("%s %s: Boxing %s, Classic %s" % [gk, k, b[k], c[k]])
				var a := BendPoses.animation(String(b.clip))
				var own := float(a.get_meta(&"strike_s", -1.0)) if a != null else -1.0
				if own >= 0.0 and absf(float(b.t_at_strike) - own) > DT + 0.0005:
					off_strike.append("%s shows %.3f s on the strike frame, its own strike %.3f s" % [gk, b.t_at_strike, own])
	BendLoadout.clear(player)
	Bending.of(player).element = keep_el
	_expect(n >= 40 and bad.is_empty(), "Boxing: %d casts (3 lock lengths and the other hand) strike, end, root and wait on Classic's frames %s" % [n, bad.slice(0, 6)])
	_expect(off_strike.is_empty(), "Boxing: on every strike frame the clip shows its own strike (within a frame) %s" % [off_strike.slice(0, 6)])
	# a bot given Boxing: its body plays the element's own clip and strike time
	var foe := mode.foe
	foe.set_meta(BendLoadout.STYLE_META, "boxing")
	var same := true
	for m: String in sty.modes:
		for md: String in sty.modes[m]:
			var ep2 := BendPoses.pick(m, md, "fire")
			if ep2.is_empty():
				continue
			var bp: Dictionary = foe.body._pick_turn(m, md, "fire")
			same = same and String(bp.get("clip", "")).begins_with("own-bend-") \
					and (ep2.has("alt") or is_equal_approx(BendPoses.body_strike_s(bp), BendPoses.body_strike_s(ep2)))
	foe.remove_meta(BendLoadout.STYLE_META)
	_expect(same, "a bot given Boxing by hand plays the element's own clips and strike times (NpcBody._pick_turn)")


## Where a Boxing cast leaves from (FINDING, not a timing: SwayPose.strike_point is the pose's limb on the strike frame, and a bolt,
## a cone, a throw or a floor wave leaves from it, PlayerBendCaster.launch_point). Measured on the player's skeleton in his own
## frame, Classic and Boxing. The timing is Classic's; the point is Boxing's fist. Most points are within a few tenths of a metre;
## the Pop (the hook, 0.5 m lower than the rising hand) and the High Kick (the uppercut's fist, about 0.9 m above the kicking foot)
## are not. Pinned so a change either way is seen: KNOWN_LAUNCH are the two the owner is asked about (docs/tidebreak/loadouts_live.md).
const KNOWN_LAUNCH := ["fire_jab/pop", "fire_kick/high_kick"]
var _ls_struck := -1
var _ls_f := 0


func _ls_on_struck(_m: String) -> void:
	if _ls_struck < 0:
		_ls_struck = _ls_f


func _launch_of(m: String, md: String) -> Vector3:
	var sc := SwayCaster.of(player)
	var pose: SwayPose = sc.pose
	sc._pin_id = m
	sc._pin_mode = md
	sc._pinning = true
	pose._clock += 10.0
	pose._last_key = ""
	pose._stop()
	pose.set_process(false)
	_ls_struck = -1
	_ls_f = 0
	pose._on_started(m, null)
	for i in int(ceil((float(pose.pick.get("hold_s", 0.3)) + 0.15) / DT)):
		pose._process(DT)
	pose.struck.connect(_ls_on_struck, CONNECT_ONE_SHOT)
	pose._on_cast(m, null)
	var at := Vector3.INF
	while pose.phase != "" and _ls_f < 300:
		_ls_f += 1
		pose._process(DT)
		if _ls_f == _ls_struck:
			pose._apply()
			await process_frame
			await process_frame
			var sp := pose.strike_point()
			if sp != Vector3.INF:
				at = player.global_transform.affine_inverse() * sp
			break
	if pose.struck.is_connected(_ls_on_struck):
		pose.struck.disconnect(_ls_on_struck)
	pose._stop()
	sc._pinning = false
	sc._pin_id = ""
	sc._pin_mode = ""
	return at


func _launch_checks() -> void:
	var sty: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/bending/style_poses.json")) as Dictionary).styles.boxing
	var keep_el := BendPoses.element_of(player)
	Bending.of(player).element = "fire"
	var far: Array = []
	var known: Dictionary = {}
	var n := 0
	for m: String in sty.modes:
		for md: String in sty.modes[m]:
			if BendPoses.pick(m, md, "fire").is_empty():
				continue
			BendLoadout.clear(player)
			var c: Vector3 = await _launch_of(m, md)
			BendLoadout.wear(player, [], "boxing", "fire")
			var b: Vector3 = await _launch_of(m, md)
			BendLoadout.clear(player)
			if c == Vector3.INF or b == Vector3.INF:
				continue
			n += 1
			var k := "%s/%s" % [m, md]
			var dl := (b - c).length()
			print("  (launch %s: Classic %s, Boxing %s, %.2f m apart, %+.2f m in height)" % [k, str(c), str(b), dl, b.y - c.y])
			if k in KNOWN_LAUNCH:
				known[k] = dl
			elif dl > 0.35:
				far.append("%s %.2f m" % [k, dl])
	Bending.of(player).element = keep_el
	_expect(n >= 12 and far.is_empty(), "Boxing: %d casts leave within 0.35 m of where Classic's do, but for the two known ones %s" % [n, far])
	_expect(known.size() == 2 and float(known.get("fire_kick/high_kick", 0.0)) > 0.6 and float(known.get("fire_jab/pop", 0.0)) > 0.35,
			"FINDING (owner's call, not a timing): Boxing's High Kick leaves %.2f m from the Classic kick's foot and its Pop %.2f m from the rising hand" % [float(known.get("fire_kick/high_kick", -1.0)), float(known.get("fire_jab/pop", -1.0))])


# ---------------------------------------------------------------- 4 THE SAVE
func _write(text: String) -> void:
	var f := FileAccess.open(OWN_STORE, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	AdvancementStore.reload_file()


func _save_checks() -> void:
	BendLoadout.read_store_in_scripts = true
	BendLoadout.config_override = {"nodes": all_on}
	var ok_slot := '{"name":"A","style":"boxing","nodes":["fire.step.quick"]}'
	var head := '{"format":"tidebreak-advancement","version":1,"elements":{"fire":'
	var classic := {"picks": [], "style": "", "slot": -1}
	var worn_ok := {"picks": ["fire.step.quick"], "style": "boxing", "slot": 0}
	var cases: Array = [
		["no file", null, classic],
		["an empty file", "", classic],
		["garbage", "\u0001 not json {{{", classic],
		["a list, not a save", "[1, 2, 3]", classic],
		["an old file without the format", '{"version": 0, "fire": {"worn": 0, "slots": [%s]}}' % ok_slot, classic],
		["worn: null", head + '{"worn": null, "slots": [%s]}}}' % ok_slot, classic],
		["worn: a dictionary", head + '{"worn": {}, "slots": [%s]}}}' % ok_slot, classic],
		["worn: a string", head + '{"worn": "x", "slots": [%s]}}}' % ok_slot, classic],
		["worn: not a whole number", head + '{"worn": 0.7, "slots": [%s]}}}' % ok_slot, classic],
		["worn: out of range", head + '{"worn": 1e30, "slots": [%s]}}}' % ok_slot, classic],
		["a slot's name, style, time, padlock of the wrong type", head + '{"worn": 0, "slots": [{"name": null, "style": 5, "nodes": ["fire.step.quick"], "saved_unix": null, "keep": "yes", "from": {}}]}}}',
				{"picks": ["fire.step.quick"], "style": "", "slot": 0}],
		["ids that are not strings", head + '{"worn": 0, "slots": [{"style": "boxing", "nodes": [null, 5, {}, [], "fire.step.quick"]}]}}}', worn_ok],
		["the nodes not a list", head + '{"worn": 0, "slots": [{"style": "boxing", "nodes": "fire.step.quick"}]}}}', {"picks": [], "style": "boxing", "slot": 0}],
		["a removed node id", head + '{"worn": 0, "slots": [{"style": "boxing", "nodes": ["fire.step.gone_in_a_later_tree", "fire.step.quick"]}]}}}', worn_ok],
		["elements a list", '{"format":"tidebreak-advancement","version":1,"elements":[1]}', classic],
		["as saved", head + '{"worn": 0, "slots": [%s]}}}' % ok_slot, worn_ok],
	]
	for c: Array in cases:
		if c[1] == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_STORE))
			AdvancementStore.reload_file()
		else:
			_write(String(c[1]))
		var before := FileAccess.get_file_as_string(OWN_STORE) if FileAccess.file_exists(OWN_STORE) else "<none>"
		var w := BendLoadout.worn("fire")
		var got := {"picks": w.picks, "style": w.style, "slot": w.slot}
		var want: Dictionary = c[2]
		if String(c[0]).begins_with("a slot's name"):
			want = {"picks": ["fire.step.quick"], "style": AdvancementStore.element_doc("fire").get("style", ""), "slot": 0}
		_expect(JSON.stringify(got) == JSON.stringify(want), "the save, %s: %s (want %s)" % [c[0], JSON.stringify(got), JSON.stringify(want)])
		var after := FileAccess.get_file_as_string(OWN_STORE) if FileAccess.file_exists(OWN_STORE) else "<none>"
		_expect(after == before, "the save, %s: reading wrote nothing" % c[0])
	_write(head + '{"worn": 0, "slots": [{"style": "boxing", "nodes": ["fire.step.gone_in_a_later_tree", "fire.step.quick"]}]}}}')
	BendLoadout.worn("fire")
	_expect(str(AdvancementStore.dropped).contains("gone_in_a_later_tree"), "a removed node id is dropped on read and named (%s)" % [AdvancementStore.dropped])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_STORE))
	AdvancementStore.reload_file()
	BendLoadout.read_store_in_scripts = false
	_expect(BendLoadout.worn("fire").slot == -1, "a script run that does not ask reads no save at all")
	BendLoadout.config_override = {}


# ---------------------------------------------------------------- 5 SWITCHES
func _switch_agreement() -> void:
	var tree: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/sway/skill_tree.json"))
	var ids: Array = []
	_ids(tree, ids)
	var disagree: Array = []
	for id: String in ids:
		if AdvancementData.is_live(id) != (BendLoadout.why_not(id) == ""):
			disagree.append(id)
	_expect(ids.size() > 100 and disagree.is_empty(), "the window's green dot (AdvancementData.is_live) agrees with BendLoadout for all %d nodes %s" % [ids.size(), disagree])
	var sd: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bending/fighting_styles.json"))
	var bad_st: Array = []
	for st: String in (sd as Dictionary).get("styles", {}):
		if AdvancementData.is_live_style(st) != (st in BendLoadout.live_styles()):
			bad_st.append(st)
	_expect(bad_st.is_empty(), "the window's live class agrees with BendLoadout for every style %s" % [bad_st])


func _ids(o: Variant, out: Array) -> void:
	if o is Dictionary:
		var d := o as Dictionary
		if d.get("id") is String and d.get("kind") is String and d.has("ring_legal") and not String(d.id) in out:
			out.append(String(d.id))
		for k: Variant in d:
			_ids(d[k], out)
	elif o is Array:
		for v: Variant in (o as Array):
			_ids(v, out)


func _fixture() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_STORE))
	AdvancementStore.reload_file()
	AdvancementStore.save_slot("fire", 0, AdvancementLoadout.new("fire", "boxing", ["fire.step.quick"]), "Review")
	AdvancementStore.wear("fire", 0)


func _on_player() -> Array:
	return [BendLoadout.picks_of(player), BendLoadout.style_meta(player), BendLoadout.overlay_of(mode.foe).is_empty() and BendLoadout.style_meta(mode.foe) == ""]


func _switch_checks() -> void:
	_fixture()
	BendLoadout.read_store_in_scripts = true
	var cases: Array = [
		["as shipped", {}, [["fire.step.quick"], "boxing"]],
		["enabled false", {"enabled": false}, [[], ""]],
		["the node's own switch off", {"nodes": {"fire.step.quick": false}}, [[], "boxing"]],
		["the node not in live", {"live": ["air.slice.keen"]}, [[], "boxing"]],
		["styles_live empty", {"styles_live": []}, [["fire.step.quick"], ""]],
	]
	for c: Array in cases:
		BendLoadout.config_override = c[1]
		await _restart()
		var on := _on_player()
		_expect(JSON.stringify(on[0]) == JSON.stringify(c[2][0]) and String(on[1]) == String(c[2][1]) and bool(on[2]),
				"switch %s: the match start puts %s and %s on the player, nothing on the bot (%s)" % [c[0], c[2][0], c[2][1], on])
	# classic_style: Classic worn, a class picked
	AdvancementStore.wear("fire", -1)
	AdvancementStore.set_style("fire", "boxing")
	BendLoadout.config_override = {}
	await _restart()
	_expect(BendLoadout.picks_of(player).is_empty() and BendLoadout.style_meta(player) == "", "classic_style false: Classic worn plays nothing")
	BendLoadout.config_override = {"classic_style": true}
	await _restart()
	_expect(BendLoadout.picks_of(player).is_empty() and BendLoadout.style_meta(player) == "boxing", "classic_style true: the class picked with Classic plays its clips, no number")
	# a match wearing the loadout, then the next match without it: Classic for the player and a fresh bot
	BendLoadout.config_override = {}
	AdvancementStore.wear("fire", 0)
	await _restart()
	_expect(BendLoadout.picks_of(player) == ["fire.step.quick"], "a match wearing Boxing and Quick Step")
	mode.next_round()
	await _ticks(4)
	_hold_foe()
	_expect(BendLoadout.picks_of(player) == ["fire.step.quick"] and BendLoadout.style_meta(player) == "boxing" and BendLoadout.overlay_of(mode.foe).is_empty(),
			"...still worn in the next round (the body is made whole, not cleared), and still not on the bot")
	AdvancementStore.wear("fire", -1)
	AdvancementStore.set_style("fire", AdvancementData.canon_style("fire"))
	mode._drop_foe()
	await _restart()
	_expect(BendLoadout.overlay_of(player).is_empty() and BendLoadout.style_meta(player) == "" and BendLoadout.overlay_of(mode.foe).is_empty(),
			"the next match with Classic worn: nothing on the player or the new bot")
	BendLoadout.read_store_in_scripts = false
	_same_print(await fp.collect(self, player), "the next match after one played wearing a loadout")


# ---------------------------------------------------------------- 6 HOT PATHS
func _hot_checks() -> void:
	var cl := Node3D.new()
	root.add_child(cl)
	var base: Dictionary = SwayMoves.move("air_blast").bend.slice
	var o1 := BendLoadout.overlay_of(cl)
	var o2 := BendLoadout.overlay_of(mode.foe)
	_expect(is_same(o1, o2) and o1.is_empty() and o1.is_read_only(),
			"a body that wears nothing reads the one shared, read-only empty overlay (no dictionary made per read)")
	_expect(is_same(BendLoadout.spec(cl, "air_blast", "slice", base), base), "Classic's spec is the data's own dictionary (no copy per cast)")
	var t0 := Time.get_ticks_usec()
	var acc := 0.0
	for i in 100000:
		acc += BendLoadout.lock(cl, "air_blast", "ball", 0.75)
	var us_lock := float(Time.get_ticks_usec() - t0) / 100000.0
	var sb := Node3D.new()
	root.add_child(sb)
	BendLoadout.wear(sb, [], "boxing", "fire")
	BendPoses.style_of(sb, "fire")
	_expect(BendLoadout._ok_memo.has("boxing") and (BendLoadout._ok_memo.boxing as Dictionary).has("fire"), "a styled body's style check is kept after the first ask (BendLoadout.style_ok memo)")
	t0 = Time.get_ticks_usec()
	var n_ok := 0
	for i in 100000:
		if BendPoses.style_of(sb, "fire") == "boxing":
			n_ok += 1
	var us_style := float(Time.get_ticks_usec() - t0) / 100000.0
	print("  (cost: Classic BendLoadout.lock %.3f us a call; a Boxing body's style_of %.3f us a call)" % [us_lock, us_style])
	_expect(n_ok == 100000 and us_lock < 5.0 and us_style < 5.0, "the per-frame reads stay cheap (%.2f us, %.2f us a call)" % [us_lock, us_style])
	BendLoadout.config_override = {"styles_live": []}
	_expect(BendPoses.style_of(sb, "fire") == "", "...and a new config is asked again (the memo follows config_override)")
	BendLoadout.config_override = {}
	_expect(BendPoses.style_of(sb, "fire") == "boxing", "...and back")
	cl.queue_free()
	sb.queue_free()
