extends SceneTree
## Round 3 MOVE (smash_r3 spec §14.3, §15): RingPredict, the GDScript mirror of lead_model.py v2, and RingMoves.simulate, the
## engine's own mover on a body of numbers. Headless, no level (a deck box: ring.json's 34 x 14 m rectangle, the water 6 m
## under the lip, the curtain 10 m out):
##   KO speeds   RingPredict.ko_speed at 25/30/35 degrees from 17, 7 and 2 m inside the lip within 5% of the model's
##               (lead_model.py v2: smash_r3 spec §2.2's figures, rebuilt as scratchpad move_r3/lead_model_v2.py)
##   reach       RingPredict.reach per element within 1 m of the spec's 11.3 / 14.7 (water's Stream) / 15.8 / 17.4 m (the model's own deck
##               test, which counts any touch of the deck's face as a landing), and the engine's own (RingMoves.simulate with
##               the model's order of moves, plan "lead") within 1 m of the model with an honest face (only the deck's top,
##               the grab box and the scramble save: air 14.7 m, the others as the spec)
##   the read    a water body at the deck's middle: the Boulder (its class, classes_override until PERCENT's table) at 100%
##               no KO, at 125% a KO; ko_pct between them; recovery counts (2 m inside the lip, 30 degrees: no recovery
##               about 8 m/s, with it about 20)
##   the stub    a flight of (10, 5, 0) from the middle lands on the deck (SEAMS' own check)
## METRIC lines: recover_reach_m per element (model / engine), ko_speed table. Last line "RING PREDICT PASSED" or "... FAILED".
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_predict.gd

const NAME := "RING PREDICT"
const WATCHDOG_S := 240.0
const OWN_CFG := "user://ring_predict_test.cfg"
## lead_model.py v2's KO speeds (m/s, water body): angle -> [from 17, 7, 2 m inside the lip].
const MODEL_KO := {25: [29.42, 23.71, 20.18], 30: [29.53, 23.90, 20.06], 35: [30.68, 24.20, 20.31]}
## The spec's recovery reach (m past the lip) and the model's own. Water's since its Rise became the Stream (the owner,
## 2026-10-12: "like the fire but with water ... like a dragon", "it should still rise em up"; 7.5 m along the aim, never
## under +35, modelled as a Jet at the model's aim): 14.7 m, the spec's 11.8 the straight-up Fountain's.
const SPEC_REACH := {"earth": 11.3, "water": 14.7, "fire": 15.8, "air": 17.4}
const MODEL_REACH := {"earth": 11.16, "water": 14.74, "fire": 15.61, "air": 17.30}
## The Boulder's class (spec §2.3) for the KO read until RingRules.class_of has it.
const BOULDER := {"d": 22.0, "base": 8.0, "growth": 12.1, "angle": 35.0, "set": false}

var checks := 0
var fails: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "strong"
	seed(1750)
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	GameSettings.path = OWN_CFG
	_run.call_deferred()


func _run() -> void:
	var stub := RingPredict.flight(Vector3(10.0, 5.0, 0.0), 0.5, Vector3.ZERO, "earth")
	_expect(String(stub.lands) == "deck", "a flight of (10, 5, 0) from the middle lands on the deck (%s)" % stub)
	var geo := RingMoves.box_geo(Vector3.ZERO, 6.0, 10.0)
	RingPredict.geo_override = geo
	_ko_speeds()
	_reach(geo)
	_read()
	RingPredict.geo_override = {}
	_end()


func _ko_speeds() -> void:
	var bad: Array = []
	for ang: int in MODEL_KO:
		var row: Array = MODEL_KO[ang]
		var got: Array = []
		for i in 3:
			var d: float = [17.0, 7.0, 2.0][i]
			var v := RingPredict.ko_speed(float(ang), d, "water")
			got.append(snappedf(v, 0.01))
			if absf(v - float(row[i])) > float(row[i]) * 0.05:
				bad.append("%d deg %.0f m: %.2f vs %.2f" % [ang, d, v, float(row[i])])
		print("METRIC ko_speed_%d_deg %s (model %s)" % [ang, str(got), str(row)])
	_expect(bad.is_empty(), "KO speeds at 25/30/35 deg from 17, 7, 2 m within 5%% of lead_model v2%s" % ("" if bad.is_empty() else " " + str(bad)))
	var none := RingPredict.ko_speed(30.0, 2.0, "water", false)
	var with := RingPredict.ko_speed(30.0, 2.0, "water", true)
	print("METRIC ko_speed_2m_30deg no_recovery %.1f with_recovery %.1f" % [none, with])
	_expect(none < 10.0 and with > 18.0, "recovery matters: 2 m inside, 30 deg: %.1f m/s with none, %.1f with it (spec: about 8, about 20)" % [none, with])


func _reach(geo: Dictionary) -> void:
	for el: String in SPEC_REACH:
		var m := RingPredict.reach(el)
		var mh := RingPredict.reach(el, true)
		var e := _engine_reach(el, RingMoves.box_geo(Vector3.ZERO, 6.0, 100.0))
		print("METRIC recover_reach_m %s model %.2f model_honest_face %.2f engine %.2f spec %.1f" % [el, m, mh, e,
				float(SPEC_REACH[el])])
		_expect(absf(m - float(SPEC_REACH[el])) <= 1.0 and absf(m - float(MODEL_REACH[el])) <= 0.3,
				"%s: RingPredict's reach %.2f m (spec %.1f, the model %.2f)" % [el, m, float(SPEC_REACH[el]), float(MODEL_REACH[el])])
		_expect(absf(e - mh) <= 1.0, "%s: the engine's reach (RingMoves.simulate, the model's order) %.2f m within 1 m of the model's with an honest face %.2f" % [el, e, mh])


## How far past the -X lip, at rest at the deck's height, a body of `el` comes back from with the model's order of moves.
func _engine_reach(el: String, geo: Dictionary) -> float:
	var lo := 0.0
	var hi := 30.0
	var hl := float(geo.hl)
	for i in 22:
		var mid := (lo + hi) * 0.5
		var st := {"pos": Vector3(-hl - mid, 0.0, 0.0), "vel": Vector3.ZERO, "element": el, "air": true, "geo": geo}
		var r := RingMoves.simulate(st, "lead", 1.0 / 120.0, 5.0)
		if String(r.result) in ["deck", "edge"]:
			lo = mid
		else:
			hi = mid
	return lo


func _read() -> void:
	RingPredict.classes_override["stone_form/cannonball"] = BOULDER
	var cls: Dictionary = BOULDER.duplicate()
	cls["tag"] = "stone_form/cannonball"
	var out := func(p: float) -> String:
		var v := RingRules.launch_v(cls, p, 22.0, 1.0)
		var a := deg_to_rad(35.0)
		var vel := Vector3(v * cos(a), minf(v * sin(a), 16.0), 0.0)
		return String(RingPredict.flight(vel, RingPredict.hitstun(vel.length()), Vector3.ZERO, "water").lands)
	var at100: String = out.call(100.0)
	var at125: String = out.call(125.0)
	_expect(at100 != "water" and at125 == "water", "a water body at the middle, the Boulder at 100%%: %s, at 125%%: %s" % [at100, at125])
	var kp := RingPredict.ko_pct_el("stone_form/cannonball", "water", Vector3.ZERO, Vector3.RIGHT)
	print("METRIC boulder_ko_pct_middle_to_end %.1f (spec 115)" % kp)
	_expect(kp > 100.0 and kp < 125.0 and absf(kp - 115.0) < 10.0, "ko_pct of the Boulder from the middle toward an end: %.1f%% (spec 115%%)" % kp)
	var node := Node3D.new()
	_expect(not RingPredict.would_ko("stone_form/cannonball", node, Vector3.ZERO, Vector3.RIGHT) \
			and is_inf(RingPredict.ko_pct("no/such", node, Vector3.ZERO, Vector3.RIGHT)),
			"would_ko at 0% (no ring: his % 0) no; a tag with no class never KOs")
	node.free()
	RingPredict.classes_override.clear()


func _end() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)
