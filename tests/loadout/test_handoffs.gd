extends SceneTree
## Checks the loadout handoff survey outputs (data/loadout/handoffs.json, handoffs_cases.json and
## graph_selections.json, written by tools/loadout/measure_handoffs.gd and
## tools/loadout/resolve_loadout_graph.py). Reads JSON only (no rig, no measurement): about 1 s.
##
##   Godot --headless --path . -s tests/loadout/test_handoffs.gd
##
## Exit code 0 and "LOADOUT HANDOFFS TEST OK" when every check passes; 1 and the failures otherwise.
## Run it under a hard time limit like every Godot run.
##
## What it pins (the survey's findings the loadout integration relies on):
##   - the manual pose composition matches a real AnimationTree (meta.validation <= 2 mm)
##   - all 24 graph draw / holster actions measured; holster = the draw clip reversed
##   - the source's grab clip ends where its draw starts (<= 2 cm for the grabbing hand)
##   - stow points: pistol at the right hip on the belt (backpack-off set), pistol behind the right hip
##     (default set), long gun over the left shoulder, bow at the left shoulder blade
##   - action partials are spined-relative: one stowed transform in spined space serves stand and crouch
##   - belt items drift less on the pelvis than on the root-parented holster bones
##   - multiple pistols: left hip reachable only by a mirrored clip; no source right-hand cross-draw
##   - unarmed profile and backpack-off resolution present
##   - provenance and asset IDs carried into the outputs

const SUMMARY := "res://data/loadout/handoffs.json"
const CASES := "res://data/loadout/handoffs_cases.json"
const GRAPH_SEL := "res://data/loadout/graph_selections.json"
const STOW_NAMES := ["pistol_right_hip", "pistol_back_right", "pistol_left_hip_mirrored", "pistol_back_left_mirrored",
		"pistol_small_of_back", "object_small_of_back", "long_gun_left_shoulder", "long_gun_right_shoulder_mirrored",
		"bow_left_back", "quiver_right_shoulder", "strap_left_chest", "strap_right_chest_mirrored"]

var _fails: Array[String] = []
var _checks := 0


func _initialize() -> void:
	var s := _load(SUMMARY)
	var c := _load(CASES)
	var g := _load(GRAPH_SEL)
	if not (s.is_empty() or c.is_empty() or g.is_empty()):
		_test_meta(s, c)
		_test_graph_actions(s)
		_test_sequences(s)
		_test_stow_points(s)
		_test_parent_drift(s)
		_test_multi_pistol(s)
		_test_unarmed(s, g)
		_test_cases(c)
	if _fails.is_empty():
		print("LOADOUT HANDOFFS TEST OK (%d checks)" % _checks)
		quit(0)
	else:
		for f in _fails:
			printerr("FAIL ", f)
		print("LOADOUT HANDOFFS TEST FAILED (%d of %d checks)" % [_fails.size(), _checks])
		quit(1)


func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_check(false, "%s missing (run tools/loadout/resolve_loadout_graph.py and tools/loadout/measure_handoffs.gd)" % path)
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(v is Dictionary, "%s parses" % path)
	return v if v is Dictionary else {}


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)


func _test_meta(s: Dictionary, c: Dictionary) -> void:
	var m: Dictionary = s.get("meta", {})
	var v: Dictionary = m.get("validation", {})
	_check(float(v.get("max_prop_err_mm", 99.0)) <= 2.0 and int(v.get("samples", 0)) > 100,
			"validation: manual composition within 2 mm of the AnimationTree (%s mm over %s samples)" % [v.get("max_prop_err_mm"), v.get("samples")])
	_check((m.get("case_ids", []) as Array).size() == (c.get("cases", {}) as Dictionary).size(), "case_ids list every case")


func _test_graph_actions(s: Dictionary) -> void:
	var ga: Dictionary = s.get("graph_actions", {})
	for w in ["bow", "musket", "pistol"]:
		for st in ["stand", "crouch"]:
			for key in ["grab", "equip", "holster", "holster_finish"]:
				var k := "%s/%s/%s" % [w, st, key]
				_check(ga.has(k), "graph action %s measured" % k)
				if not ga.has(k):
					continue
				_check(bool(ga[k].reverse) == (key == "holster"), "%s: reverse only for holster" % k)
			if ga.has("%s/%s/equip" % [w, st]) and ga.has("%s/%s/holster" % [w, st]):
				_check(ga["%s/%s/equip" % [w, st]].clip == ga["%s/%s/holster" % [w, st]].clip,
						"%s/%s: holster plays the draw clip" % [w, st])


func _test_sequences(s: Dictionary) -> void:
	var seq: Dictionary = s.get("sequences", {})
	var hand := {"bow": "l", "musket": "l", "pistol": "r"}
	for w in hand:
		for st in ["stand", "crouch"]:
			var k := "%s/%s" % [w, st]
			_check(seq.has(k), "sequence %s present" % k)
			if seq.has(k):
				var d := float(seq[k].grab_end_to_draw_start_m[hand[w]])
				_check(d <= 0.02, "%s: grab ends where the draw starts (%.3f m)" % [k, d])


func _test_stow_points(s: Dictionary) -> void:
	var pts: Dictionary = s.get("stow_points", {}).get("points", {})
	for n in STOW_NAMES:
		_check(pts.has(n) and (pts[n].stances as Dictionary).has("stand"), "stow point %s has a stand record" % n)
	if not pts.has("pistol_right_hip"):
		return
	var rh: Dictionary = pts.pistol_right_hip.stances.stand[0]
	_check(rh.has("parked"), "pistol_right_hip: the grab clip parks the pistol (source stowed pose)")
	if rh.has("parked"):
		_check(String(rh.parked.region).contains("right hip"), "pistol_right_hip parked on the right hip (%s)" % rh.parked.region)
		_check(float(rh.parked.belt_az_deg) < -55.0 and float(rh.parked.belt_az_deg) > -110.0, "pistol_right_hip azimuth %s" % rh.parked.belt_az_deg)
		_check(absf(float(rh.parked.above_belt_mid_m)) < 0.06, "pistol_right_hip at belt height (%s m)" % rh.parked.above_belt_mid_m)
		_check(float(rh.jump_parked_to_in_hand.pos_m) < 0.02, "pistol_right_hip: parked == in hand at the grab (%s m)" % rh.jump_parked_to_in_hand.pos_m)
	var br: Dictionary = pts.pistol_back_right.stances.stand[0]
	_check(String(br.hand_region).contains("back") or String(br.hand_region).contains("right lower back"), "pistol_back_right region (%s)" % br.hand_region)
	_check(float(br.belt_az_deg) < -110.0, "pistol_back_right azimuth behind the hip (%s)" % br.belt_az_deg)
	var lg: Dictionary = pts.long_gun_left_shoulder.stances.stand[0]
	_check(String(lg.hand_region).contains("shoulder"), "long gun grabbed over the shoulder (%s)" % lg.hand_region)
	_check(lg.grab_hand == "l", "long gun grabbed by the left hand")
	var bw: Dictionary = pts.bow_left_back.stances.stand[0]
	_check(String(bw.hand_region).begins_with("left"), "bow grabbed on the left of the back (%s)" % bw.hand_region)
	var q: Dictionary = pts.quiver_right_shoulder.stances.stand[0]
	_check(float(q.belt_az_deg) < -90.0 and float(q.above_belt_mid_m) > 0.15, "quiver reach behind the right shoulder (az %s, up %s)" % [q.belt_az_deg, q.above_belt_mid_m])
	# arm partials are spined-relative: stand and crouch agree in spined space
	for n in pts:
		if (pts[n] as Dictionary).has("stand_vs_crouch") and n != "quiver_right_shoulder":
			var sp: Dictionary = pts[n].stand_vs_crouch.spaces.spined
			_check(float(sp.pos_m) < 0.002, "%s: one stowed transform in spined space serves stand and crouch (%s m)" % [n, sp.pos_m])


func _test_parent_drift(s: Dictionary) -> void:
	var p: Dictionary = s.get("parent_drift", {}).get("points", {})
	_check(p.has("belt_right_hip"), "parent drift of the right-hip belt point measured")
	if p.has("belt_right_hip"):
		var r: Dictionary = p.belt_right_hip.parents
		_check(float(r.pelvis.max_m) == 0.0, "pelvis is the belt reference")
		_check(float(r.holster_pistol.max_m) > 0.03, "root-parented holster_pistol slides against the belt (%s m)" % r.holster_pistol.max_m)


func _test_multi_pistol(s: Dictionary) -> void:
	var t: Dictionary = s.get("multi_pistol", {}).get("targets", {})
	for k in ["right_hip", "back_right", "left_hip_same_side", "left_hip_cross", "chest_left_same_side", "chest_left_cross", "front"]:
		_check(t.has(k), "multi_pistol target %s" % k)
	if t.has("left_hip_same_side"):
		_check(String(t.left_hip_same_side.best[0].case).begins_with("M:"), "left hip: best reach is a mirrored clip")
		_check(t.left_hip_same_side.verdict in ["direct", "close"], "left hip reachable by the mirrored draw (%s)" % t.left_hip_same_side.verdict)
	if t.has("left_hip_cross"):
		_check(t.left_hip_cross.verdict in ["no", "approximation"], "no source right-hand cross-draw to the left hip (%s)" % t.left_hip_cross.verdict)
	if t.has("chest_left_same_side"):
		_check(String(t.chest_left_same_side.best[0].case).contains("flashlight"), "left chest reached by the flashlight (strap) clip")


func _test_unarmed(s: Dictionary, g: Dictionary) -> void:
	_check(g.get("profile", {}).get("weapon-base", "") == "anim-overlay-player-weapon-base-no-weapon", "unarmed profile uses weapon-base-no-weapon")
	_check(g.get("hand_states", {}).get("stand", {}).get("idle_hands", {}).get("clip", "") == "actor_b-fist-ambi-hands", "unarmed idle hands = fist-ambi-hands")
	_check(g.get("roles", {}).get("run/idle", {}).get("clip", "") == "actor_b-p-relax-idle", "unarmed idle = p-relax-idle")
	var bo: Dictionary = g.get("backpack_off", {})
	_check((bo.get("changed", []) as Array).has("pistol/stand/equip"), "backpack-off changes the pistol draw")
	var eq: Dictionary = bo.get("actions", {}).get("pistol/crouch/equip", {})
	_check(String(eq.get("backpack_off", {}).get("partial", "")).ends_with("--no-pack"), "backpack-off pistol draw is the --no-pack clip in crouch too")
	_check(not (bo.get("changed", []) as Array).has("musket/stand/equip"), "backpack-off leaves the musket draw alone")
	_check(s.get("unarmed", {}).has("backpack_off"), "summary carries the backpack-off selection")


func _test_cases(c: Dictionary) -> void:
	var cases: Dictionary = c.get("cases", {})
	_check(cases.size() >= 100, "at least 100 cases measured (%d)" % cases.size())
	var missing := 0
	for id in cases:
		var e: Dictionary = cases[id]
		if String(e.get("native_asset_id", {}).get("partial", "")) == "":
			missing += 1
		if String(id).begins_with("M:"):
			_check(bool(e.get("mirrored", false)), "%s flagged mirrored" % id)
	_check(missing == 0, "every case carries the clip's native_asset_id (%d missing)" % missing)
